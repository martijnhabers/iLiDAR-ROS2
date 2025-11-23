# =========================
# iLiDAR
# ios_driver.py
# Created by Bo Liang on 2024/12/8.
# =========================


import socket
import threading
import struct
import os
import rclpy
from rclpy.node import Node
from sensor_msgs.msg import CompressedImage, PointCloud2, PointField, Imu, Image
from rclpy.qos import QoSProfile, QoSReliabilityPolicy, QoSHistoryPolicy
import numpy as np
from read_depth_data import read_raw_depth_data
import queue
import sensor_pb2

# =========================
# Configuration Parameters
# =========================

# Define the data types as per your protocol
DATA_TYPE_JPEG = 0x01
DATA_TYPE_BIN = 0x02
DATA_TYPE_CSV = 0x03

# Mapping from data type to file extension
DATA_TYPE_EXTENSION = {
    DATA_TYPE_JPEG: '.jpg',
    DATA_TYPE_BIN: '.bin',
    DATA_TYPE_CSV: '.csv'
}

# Server details
SERVER_HOST = '0.0.0.0'  # Listen on all available interfaces
SERVER_PORT = 5678        # Port to listen on

SAVE_DIRECTORY = 'uploads'  # Directory to save uploaded files

# Create the uploads directory if it doesn't exist
os.makedirs(SAVE_DIRECTORY, exist_ok=True)

# =========================
# Helper Classes and Methods
# =========================

class FileReceiver:
    """
    Manages the reception and reconstruction of a single file.
    """
    def __init__(self, filename, data_type):
        self.filename = filename
        self.data_type = data_type
        self.chunks = {}  # Maps sequence_number to data
        self.is_last_received = False

    def add_chunk(self, sequence_number, data, is_last):
        if sequence_number in self.chunks:
            print(f"Duplicate chunk {sequence_number} for file {self.filename}. Ignoring.")
            return
        self.chunks[sequence_number] = data
        if is_last:
            self.is_last_received = True

    def is_complete(self):
        """
        Checks if all chunks have been received.
        """
        if not self.is_last_received:
            return False
        max_seq = max(self.chunks.keys())
        # Ensure all sequence numbers from 0 to max_seq are present
        for seq in range(max_seq + 1):
            if seq not in self.chunks:
                return False
        return True

    def reconstruct_file(self):
        """
        Concatenates all chunks in sequence order to reconstruct the complete file.
        """
        sorted_chunks = [self.chunks[seq] for seq in sorted(self.chunks.keys())]
        return b''.join(sorted_chunks)

class ImagePublisher(Node):

    qos_profile = QoSProfile(
        reliability=QoSReliabilityPolicy.BEST_EFFORT,
        history=QoSHistoryPolicy.KEEP_LAST,
        depth=5
        )

    def __init__(self):
        super().__init__('image_publisher')
        self.publisher_ = self.create_publisher(CompressedImage, '/color_image/compressed', self.qos_profile)

    def publish_jpeg(self, jpeg_data, frame_id='color_image'):
        msg = CompressedImage()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = frame_id
        msg.format = 'jpeg'
        msg.data = jpeg_data
        self.publisher_.publish(msg)

class PointCloudPublisher(Node):

    def __init__(self):
        super().__init__('pointcloud_publisher')
        self.publisher_ = self.create_publisher(PointCloud2, '/depth_pointcloud', 10)

    def publish_pointcloud(self, depth_data, width, height, fx, fy, cx, cy):
        """
        Converts depth data to a point cloud and publishes it.

        Parameters:
        - depth_data: numpy.ndarray, the 2D array of depth values
        - width, height: int, dimensions of the depth image
        - fx, fy: float, focal lengths of the camera
        - cx, cy: float, principal point offsets of the camera
        """
        points = []

        for v in range(height):
            for u in range(width):
                z = depth_data[v, u]
                if z == 0:  # Skip invalid depth values
                    continue
                x = (u - cx) * z / fx
                y = (v - cy) * z / fy
                points.append((x, y, z))

        # Create PointCloud2 message
        pointcloud_msg = PointCloud2()
        pointcloud_msg.header.stamp = self.get_clock().now().to_msg()
        pointcloud_msg.header.frame_id = 'camera_frame'

        # Define the fields of the point cloud
        pointcloud_msg.fields = [
            PointField(name='x', offset=0, datatype=PointField.FLOAT32, count=1),
            PointField(name='y', offset=4, datatype=PointField.FLOAT32, count=1),
            PointField(name='z', offset=8, datatype=PointField.FLOAT32, count=1),
        ]

        pointcloud_msg.is_bigendian = False
        pointcloud_msg.point_step = 12  # 3 floats per point (x, y, z)
        pointcloud_msg.row_step = pointcloud_msg.point_step * len(points)
        pointcloud_msg.height = 1
        pointcloud_msg.width = len(points)
        pointcloud_msg.is_dense = True

        # Pack the point data into a binary array
        pointcloud_msg.data = struct.pack('<' + 'fff' * len(points), *np.array(points).flatten())

        self.publisher_.publish(pointcloud_msg)
        self.get_logger().info(f"Published point cloud with {len(points)} points")

class DepthImagePublisher(Node):

    def __init__(self):
        super().__init__('depth_image_publisher')
        self.publisher_ = self.create_publisher(Image, '/depth_image', 10)

    def publish_depth_image(self, depth_data, width, height, frame_id='camera_frame'):
        """
        Publishes raw depth data as an Image message for visualization in RViz.

        Parameters:
        - depth_data: numpy.ndarray, the 2D array of depth values (float32)
        - width, height: int, dimensions of the depth image
        - frame_id: str, the frame ID for the message header
        """

        # Remove NaN values and scale depth to (0,255) aka uint8 for message
        depth_data_clean = np.nan_to_num(depth_data, nan=0.0)
    
        # Normalize depth values to 0-255 for visualization
        depth_min = np.min(depth_data_clean[depth_data_clean > 0]) if np.any(depth_data_clean > 0) else 0
        depth_max = np.max(depth_data_clean)
        if depth_max - depth_min > 0:
            depth_normalized = (depth_data_clean - depth_min) / (depth_max - depth_min) * 255.0
        else:
            depth_normalized = depth_data_clean * 0.0
        depth_normalized = depth_normalized.astype(np.uint8)


        # Create Image message without cv_bridge
        img_msg = Image()
        img_msg.header.stamp = self.get_clock().now().to_msg()
        img_msg.header.frame_id = frame_id
        img_msg.width = width
        img_msg.height = height
        img_msg.encoding = 'mono8'
        img_msg.is_bigendian = False
        img_msg.step = width * 1

        # Convert numpy array to bytes
        img_msg.data = depth_normalized.tobytes()

        self.publisher_.publish(img_msg)
        self.get_logger().info(f"Published depth image to /depth_image ({width}x{height})")

class IMUPublisher(Node):

    def __init__(self):
        super().__init__('imu_publisher')
        self.publisher_ = self.create_publisher(Imu, '/imu/data', 10)
    
    def publish_imu(self, imu_data):
        """
        Publishes IMU data to the /imu/data topic.
        Parameters:
        - imu_data: sensor_pb2.IMUData, the IMU data received from the client
        """

        imu_msg = Imu()
        imu_msg.header.stamp = self.get_clock().now().to_msg()
        imu_msg.header.frame_id = imu_data.frame_id

        # Fill in orientation
        imu_msg.orientation.x = imu_data.orientation.x
        imu_msg.orientation.y = imu_data.orientation.y
        imu_msg.orientation.z = imu_data.orientation.z
        imu_msg.orientation.w = imu_data.orientation.w

        # Fill in angular velocity
        imu_msg.angular_velocity.x = imu_data.gyro.x
        imu_msg.angular_velocity.y = imu_data.gyro.y
        imu_msg.angular_velocity.z = imu_data.gyro.z

        # Fill in linear acceleration
        imu_msg.linear_acceleration.x = imu_data.accel.x
        imu_msg.linear_acceleration.y = imu_data.accel.y
        imu_msg.linear_acceleration.z = imu_data.accel.z

        self.publisher_.publish(imu_msg)
        self.get_logger().info(f"Published IMU data (timestamp: {imu_data.timestamp})")

class ClientHandler(threading.Thread):
    """
    Handles communication with a single client.
    """
    def __init__(self, client_socket, client_address, image_publisher, pointcloud_publisher, depth_image_publisher, imu_publisher):
        super().__init__(daemon=True)
        self.client_socket = client_socket
        self.client_address = client_address
        self.buffer = b''  # Buffer to store incoming data
        self.files = {}     # Maps filename to FileReceiver instances
        self.image_publisher = image_publisher
        self.pointcloud_publisher = pointcloud_publisher
        self.depth_image_publisher = depth_image_publisher
        self.imu_publisher = imu_publisher

    def run(self):
        print(f"[+] Connection established with {self.client_address}")
        try:
            while True:
                data = self.client_socket.recv(4096)
                if not data:
                    print(f"[-] Connection closed by {self.client_address}")
                    break
                self.buffer += data
                self.process_buffer()
        except Exception as e:
            print(f"[!] Error with client {self.client_address}: {e}")
        finally:
            self.client_socket.close()

    def process_buffer(self):
        """
        Processes the buffer to extract and handle complete data packets.
        """
        while True:
            if len(self.buffer) < 1:
                # Not enough data to determine filename length
                return

            # Read the first byte to get filename length
            filename_length = self.buffer[0]

            # Total header size: 1 (filename_length) + filename_length + 1 (data_type) + 4 (data_size) + 4 (sequence_number) + 1 (is_last)
            total_header_size = 1 + filename_length + 1 + 4 + 4 + 1

            if len(self.buffer) < total_header_size:
                # Wait for more data
                return

            # Extract header components
            try:
                # Filename
                filename_start = 1
                filename_end = filename_start + filename_length
                filename_bytes = self.buffer[filename_start:filename_end]
                filename = filename_bytes.decode('utf-8')

                # Data Type
                data_type = self.buffer[filename_end]

                # Data Size
                data_size_bytes = self.buffer[filename_end + 1:filename_end + 5]
                data_size = struct.unpack('>I', data_size_bytes)[0]

                # Sequence Number
                sequence_number_bytes = self.buffer[filename_end + 5:filename_end + 9]
                sequence_number = struct.unpack('>I', sequence_number_bytes)[0]

                # Is Last Chunk
                is_last_byte = self.buffer[filename_end + 9]
                is_last = bool(is_last_byte)

            except Exception as e:
                print(f"[!] Failed to parse header from {self.client_address}: {e}")
                # Optionally, send an error message back to the client
                return

            # Check if the entire payload has been received
            total_packet_size = total_header_size + data_size
            if len(self.buffer) < total_packet_size:
                # Wait for more data
                return

            # Extract payload
            payload_start = total_header_size
            payload_end = payload_start + data_size
            payload = self.buffer[payload_start:payload_end]

            # Remove the processed packet from the buffer
            self.buffer = self.buffer[payload_end:]

            # Handle the extracted packet
            self.handle_packet(filename, data_type, data_size, sequence_number, is_last, payload)

    def handle_packet(self, filename, data_type, data_size, sequence_number, is_last, payload):
        """
        Processes a single data packet.
        """
        # Map data type to string for logging
        data_type_str = DATA_TYPE_EXTENSION.get(data_type, f'Unknown({data_type})')

        # print(f"[>] Received Packet - Filename: {filename}, Type: {data_type_str}, "
        #       f"Seq: {sequence_number}, IsLast: {is_last}, Size: {data_size} bytes")

        # Initialize FileReceiver if it's the first chunk of the file
        if filename not in self.files:
            if data_type not in DATA_TYPE_EXTENSION:
                print(f"[!] Unknown data type {data_type} for file {filename}. Skipping.")
                return
            self.files[filename] = FileReceiver(filename, data_type)

        file_receiver = self.files[filename]
        file_receiver.add_chunk(sequence_number, payload, is_last)

        # Check if the file is fully received
        if file_receiver.is_complete():
            complete_data = file_receiver.reconstruct_file()

            if file_receiver.data_type == DATA_TYPE_BIN:
                # Decode Protobuf binary data
                try:
                    sensor_msg = sensor_pb2.SensorMessage()
                    sensor_msg.ParseFromString(complete_data)
                    
                    # Check which type of message was received
                    if sensor_msg.HasField('camera'):
                        # Extract and publish camera image from protobuf
                        camera_data = sensor_msg.camera
                        self.image_publisher.publish_jpeg(camera_data.image_data)
                        print(f"[+] Camera image from protobuf published to /color_image "
                              f"(timestamp: {camera_data.timestamp}, frame_id: {camera_data.frame_id})")
                    elif sensor_msg.HasField('imu'):
                        # Extract and publish IMU data from protobuf
                        imu_data = sensor_msg.imu
                        self.imu_publisher.publish_imu(imu_data)
                        print(f"[+] IMU data from protobuf received "
                              f"(timestamp: {imu_data.timestamp}, frame_id: {imu_data.frame_id})")
                    elif sensor_msg.HasField('depth'):
                        # Extract and publish depth image from protobuf
                        depth_img = sensor_msg.depth

                        try:
                            # Try float32 first (iOS should send this)
                            depth_array = np.frombuffer(depth_img.depth_data, dtype=np.float16)
                            depth_data = depth_array.reshape((depth_img.height, depth_img.width))
                        except Exception as e:
                            print(f"[!] Failed to parse depth data as float16: {e}")

                        # Publish as depth image for visualization
                        self.depth_image_publisher.publish_depth_image(depth_data, depth_data.shape[1], depth_data.shape[0], depth_img.frame_id)
                        # Also publish as pointcloud for 3D reconstruction
                        self.pointcloud_publisher.publish_pointcloud(depth_data, depth_data.shape[1], depth_data.shape[0], 498.72195, 498.72195, 317.22327, 239.91258)
                        print(f"[+] Depth image published to /depth_image and /depth_pointcloud "
                              f"(timestamp: {depth_img.timestamp}, size: {depth_data.shape[1]}x{depth_data.shape[0]})")
                    else:
                        print(f"[!] Unknown protobuf message type in {filename}")
                except Exception as e:
                    print(f"[PROTOBUF] Failed to decode protobuf message: {e}")

            ack_message = f"File '{filename}' received and processed successfully."
            self.send_acknowledgment(ack_message)

            # Remove the FileReceiver instance as it's no longer needed
            del self.files[filename]

    def send_acknowledgment(self, message):
        """
        Sends an acknowledgment message back to the client.
        """
        try:
            self.client_socket.sendall(message.encode('utf-8'))
            print(f"[<] Sent acknowledgment to {self.client_address}: {message}")
        except Exception as e:
            print(f"[!] Failed to send acknowledgment to {self.client_address}: {e}")

# =========================
# Server Setup and Execution
# =========================

def start_server(image_publisher, pointcloud_publisher, depth_image_publisher, imu_publisher):

    """
    Initializes and starts the server to listen for incoming connections.
    """
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.bind((SERVER_HOST, SERVER_PORT))
    server_socket.listen(5)
    print(f"[*] Server listening on {SERVER_HOST}:{SERVER_PORT}")

    try:
        while True:
            client_sock, client_addr = server_socket.accept()
            handler = ClientHandler(client_sock, client_addr, image_publisher, pointcloud_publisher, depth_image_publisher, imu_publisher)
            handler.start()
    except KeyboardInterrupt:
        print("\n[!] Server shutting down.")
    except Exception as e:
        print(f"[!] Server error: {e}")
    finally:
        server_socket.close()

def main():
    rclpy.init()
    image_publisher = ImagePublisher()
    pointcloud_publisher = PointCloudPublisher()
    depth_image_publisher = DepthImagePublisher()
    imu_publisher = IMUPublisher()

    server_thread = threading.Thread(target=start_server, args=(image_publisher, pointcloud_publisher, depth_image_publisher, imu_publisher), daemon=True)
    server_thread.start()

    try:
        rclpy.spin(depth_image_publisher)
    except KeyboardInterrupt:
        pass
    finally:
        image_publisher.destroy_node()
        pointcloud_publisher.destroy_node()
        depth_image_publisher.destroy_node()
        imu_publisher.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
