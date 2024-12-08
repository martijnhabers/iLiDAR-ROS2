# =========================
# iLiDAR
# read_depth_data.py
# Created by Bo Liang on 2024/12/8.
# =========================

import numpy as np
import matplotlib.pyplot as plt
from PIL import Image
from scipy.ndimage import zoom

def read_raw_depth_data(file_path, width, height):
    """
    Reads raw depth data from a file.
    
    Parameters:
    - file_path: str, the path to the file containing the raw depth data
    - width: int, the width of the depth texture
    - height: int, the height of the depth texture
    
    Returns:
    - depth_data: numpy.ndarray, a 2D array of depth values
    """
    bytes_per_pixel = 2  # Each depth value is 16-bit (2 bytes), float16
    bytes_per_row = width * bytes_per_pixel

    # Calculate the expected total size of the data
    expected_size = height * bytes_per_row
    
    # Read the raw data from the file
    with open(file_path, "rb") as f:
        raw_data = f.read()

    # Ensure the file size matches the expected size
    if len(raw_data) != expected_size:
        raise ValueError(f"File size mismatch. Expected {expected_size} bytes, got {len(raw_data)} bytes.")

    # Convert the raw byte data into a numpy array of 16-bit unsigned integers
    depth_data = np.frombuffer(raw_data, dtype=np.float16)

    # Reshape the data into a 2D array with the given width and height
    depth_data = depth_data.reshape((height, width))

    return depth_data

def visualize_depth_data(depth_data):
    """
    Visualizes the depth data as a heatmap.
    
    Parameters:
    - depth_data: numpy.ndarray, the 2D array of depth values
    """
    plt.imshow(depth_data, cmap='plasma', interpolation='nearest')
    plt.colorbar(label="Depth Value (16-bit)")
    plt.title("Depth Map Visualization")
    plt.show()

def visualize_depth_and_color(depth_data, color_image):
    """
    Visualizes the depth data and color image side by side.
    
    Parameters:
    - depth_data: numpy.ndarray, the 2D array of depth values
    - color_image: numpy.ndarray, the 3D array representing the color image
    """
    fig, ax = plt.subplots(1, 2, figsize=(12, 6))

    # Plot the depth data
    im1 = ax[0].imshow(depth_data, cmap='plasma', interpolation='nearest')
    ax[0].set_title("Depth Map")
    fig.colorbar(im1, ax=ax[0], label="Depth Value (16-bit)")

    # Plot the color image
    im2 = ax[1].imshow(color_image)
    ax[1].set_title("Color Image")

    plt.show()

if __name__ == "__main__":
    # replace to your files
    depth_file_path = "./example_data/example_depth_data.bin"  # Path to the raw depth data file
    color_image_path = "./example_data/example_rgb_image.jpg"  # Path to the color image file

    depth_width = 320
    depth_height = 240
    rgb_width = 1920
    rgb_height = 1440
    scale_factor = rgb_height/depth_height
    depth_data = read_raw_depth_data(depth_file_path, depth_width, depth_height)
    scaled_depth_data = zoom(depth_data.astype(np.float32), scale_factor)

    color_image = np.array(Image.open(color_image_path))

    visualize_depth_and_color(scaled_depth_data, color_image)


