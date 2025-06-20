# =========================
# iLiDAR
# ios_driver.py
# Created by Bo Liang on 2024/12/8.
# =========================


import socket
import threading
import struct
import os
import cv2  # Import OpenCV
import numpy as np
import queue  # Import queue for thread-safe communication

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

# Directory where received files will be stored
SAVE_DIRECTORY = 'uploads'
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

class ClientHandler(threading.Thread):
    """
    Handles communication with a single client.
    """
    def __init__(self, client_socket, client_address):
        super().__init__(daemon=True)
        self.client_socket = client_socket
        self.client_address = client_address
        self.buffer = b''  # Buffer to store incoming data
        self.files = {}     # Maps filename to FileReceiver instances
        self.image_queue = queue.Queue()  # Queue for storing images to be displayed

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
            extension = DATA_TYPE_EXTENSION.get(file_receiver.data_type, '')

            if extension == '.jpg':
                image = cv2.imdecode(np.frombuffer(complete_data, np.uint8), cv2.IMREAD_COLOR)
                if image is not None:
                    print(f"[Debug] Image decoded successfully for {filename}")
                    self.image_queue.put(image)  # Add image to the queue
                else:
                    print(f"[!] Failed to decode image {filename}")



    def send_acknowledgment(self, message):
        """
        Sends an acknowledgment message back to the client.
        """
        try:
            self.client_socket.sendall(message.encode('utf-8'))
            print(f"[<] Sent acknowledgment to {self.client_address}: {message}")
        except Exception as e:
            print(f"[!] Failed to send acknowledgment to {self.client_address}: {e}")

# Separate thread for displaying images
class ImageDisplayThread(threading.Thread):
    def __init__(self, image_queue, max_queue_size=10):
        super().__init__(daemon=True)
        self.image_queue = image_queue
        self.max_queue_size = max_queue_size

    def run(self):
        while True:
            try:
                # Print the current queue size
                print(f"[Queue Size]: {self.image_queue.qsize()}")

                # Skip frames if the queue is too full
                while self.image_queue.qsize() > self.max_queue_size:
                    self.image_queue.get()

                image = self.image_queue.get(timeout=1)  # Get image from the queue
                print(f"[Debug] Retrieved image from queue for display")
                cv2.imshow('Incoming Video Stream', image)
                cv2.waitKey(1)  # Display the image for 1 ms
            except queue.Empty:
                continue

# =========================
# Server Setup and Execution
# =========================

def start_server():
    """
    Initializes and starts the server to listen for incoming connections.
    """
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_socket.bind((SERVER_HOST, SERVER_PORT))
    server_socket.listen(5)
    print(f"[*] Server listening on {SERVER_HOST}:{SERVER_PORT}")

    image_queue = queue.Queue()  # Create a queue for images
    image_display_thread = ImageDisplayThread(image_queue)  # Start the image display thread
    image_display_thread.start()

    try:
        while True:
            client_sock, client_addr = server_socket.accept()
            handler = ClientHandler(client_sock, client_addr)
            handler.image_queue = image_queue  # Pass the queue to the client handler
            handler.start()
    except KeyboardInterrupt:
        print("\n[!] Server shutting down.")
    except Exception as e:
        print(f"[!] Server error: {e}")
    finally:
        server_socket.close()
        cv2.destroyAllWindows()  # Ensure OpenCV windows are closed properly

if __name__ == '__main__':
    try:
        start_server()
    except Exception as e:
        print(f"[!] Error: {e}")
    finally:
        cv2.destroyAllWindows()  # Ensure OpenCV windows are closed properly