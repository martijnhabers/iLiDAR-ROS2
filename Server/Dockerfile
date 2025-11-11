# Use ROS Humble desktop as base image
FROM --platform=linux/amd64 osrf/ros:humble-desktop

# Install pip (Python is already included in the ROS image)
RUN apt-get update && apt-get install -y \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install google protobuf

# Copy the contents of the Server directory into the image
COPY . /server
WORKDIR /server

# Expose port 5678
EXPOSE 5678

# Default command to run your ROS Python script
CMD ["python3", "ios_driver_ros.py"]