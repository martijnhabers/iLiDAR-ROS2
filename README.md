# iLiDAR

iLiDAR is a project that uses an iPhone as a multi-modality visual sensor, integrating LiDAR and RGB cameras to capture real-time data. The system works as follows: by installing a custom app on the iPhone as the client and opening a server on a PC, you can stream video and depth images from the iPhone.

## Quick Start

### Check Device Support

Only specific iPhone models (Pro or Pro Max) are equipped with LiDAR. Ensure your device is listed in the [supported devices list](https://support.apple.com/en-us/102468#:~:text=Use%20the%20Measure%20app%20with%20a%20Pro%20device). Generally, all iPhone Pro models from the iPhone 12 Pro and later, as well as the latest iPad Pro models, are supported.

### Build the App and Transfer it to iPhone

1. Use Xcode (on macOS) to open `iLiDAR.xcworkspace`.
2. Configure your development account (you may need to handle a series of permission and privacy requests) and build the project.
3. Connect your iPhone (Pro model) to the macOS device via USB or wirelessly and transfer the built app to your iPhone.

On the iPhone, when prompted with "Allow APP to use camera" or "Allow APP to find local network devices?", click "Yes."

### Set up the Server on PC

Set up your PC as a socket server to receive the video streams. Ensure that both your iPhone and PC are connected to the same Wi-Fi network. Then, run the following command:

```bash
cd Server
python ios_driver.py
```
This program will listen on port `5678` and create a folder named `uploads` to store incoming data. If everything works correctly, you will see:

```bash
[*] Server listening on 0.0.0.0:5678
```

On your iPhone, open the app, set the IP address to your host IP (for example, `192.168.1.10`), and click `Connect`. Then, click `Enable Network Transfer` to begin streaming. If everything works correctly, you will see logs like this:

```bash
[>] Received Packet - Filename: 20241208_223229_20241208_223232_76_frame000316.jpg, Type: .jpg, Seq: 55, IsLast: False, Size: 1024 bytes
```
**Note**: The app cannot run on the simulator because it relies on the LiDAR API, which is not implemented in the simulator.

### Analyse Received Data

You can use the scripts in `Server/read_depth_data.py` to analyse the received depth data and RGB data. There has been two example files in the `Server/example_data/` for test.

## Schedule
To make our polished code and reproduced experiments available as soon as possible, we will release finished components immediately after validation, rather than waiting for all work to be completed. The task list is as follows:

- [x] Release iLiDAR;
- [x] Update the NetWork Support;
- [x] Update the UI Supoort;
- [x] Correct the network status button;
- [ ] Support to on/off lidar temperal filter;
- [ ] Store popular local ips;
- [ ] Update more local processing script;
- [ ] Provide a full tutorial to beginning from zero;

## Custom Modification

If you want to modify more details of this project. Refer to the following or [Full Tutorial](full_tutorial.md)

### File Name Format
The file naming follows these principles:

- Each time you tap `Enable Network Transfer`, a new event is marked with a timestamp in the format `yyyyMMdd_HHmmss`.
- Each frame is timestamped with `yyyyMMdd_HHmmss_SS` and an ID counting `frame%06d` from the beginning of the event.
- RGB images have a `.jpg` format, and depth data is stored as `.bin`. The filenames follow the format:
  - `[event_timestamp]_[frame_timestamp]_frame%06d.jpg`
  - ``[event_timestamp]_[frame_timestamp]_frame%06d.bin`
- The camera parameters are also transferred to the PC and saved as `[event].csv`.

### Change the Compression Rate or Frame Rate

- To ensure a right network transmission, we compress all RGB images to 0.4. You can modify `DataStorage.compressionQuality` to change it according to your network status.
- We transfer the data with 30 fps. You can modify the fps in function of `AVCaptureDataOutputSynchronizerDelegate` in `CameraController.swift`.

## Reference

This program is built upon [Apple official depth camera example](https://developer.apple.com/documentation/avfoundation/additional_data_capture/capturing_depth_using_the_lidar_camera).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.txt) file for details.