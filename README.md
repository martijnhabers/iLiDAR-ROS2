# iLiDAR

iLiDAR is a project to use iPhone as a multi-modality visual sensor, including LiDAR and RGB camera, to capture real-time data. It works as the following figure. By installing a custom app on iPhone as client and open a server on pc, you can obtain video streaming and depth image streaming from iPhone.

Another project [StrayVisualizer](https://github.com/kekeblom/StrayVisualizer) can also be used to collect depth camera data, but it does not support real-time streaming. On the contrary, our project is developed based on [official depth camera example](https://developer.apple.com/documentation/avfoundation/additional_data_capture/capturing_depth_using_the_lidar_camera) and we build data compression and network communication stack upon it. 

## IOS APP

### Check Device Support

Only limited version (pro or promax) iPhone is equipped with LiDAR. Ensure the device you used in the [supported device list](https://support.apple.com/en-us/102468#:~:text=Use%20the%20Measure%20app%20with%20a%20Pro%20device).

### Run Official Example

First, download the official example from:

```
https://developer.apple.com/documentation/avfoundation/additional_data_capture/capturing_depth_using_the_lidar_camera
```


This is a swift project but it not matters if you are not familiar with swift. Decompress the project and move it in the project folder. Then try to compiler it and run it on your iPhone. You may need to handle the wired link problem (set your device as build target, set your macos trustable on your iPhone) or development permission problems (register a development team and login in). Once building successfully, you can see your iPhone capturing depth data and RGB images and visualizing them.

### Set the Third-party Extension

You need to download a third-party extension management [cocoapods](https://cocoapods.org/) by `gem`

```bash
# one possible download method
brew gem install cocoapods
cd LiDARDepth
pod init
```

Then modify the generated Podfile to:

```ini
# Uncomment the next line to define a global platform for your project
# platform :ios, '15.6'

target 'LiDARDepth' do
  pod 'CocoaAsyncSocket'
  pod 'AFNetworking'
  pod 'ReactiveCocoa', '~> 11.0'
  source 'https://github.com/CocoaPods/Specs.git'
  
end
```

And run

```bash
pod install
```

It may take a long time to download third party tools and ensure the VPN is right. After completing, open the project file of `LiDARDepth.xcworkspace`, you will see two targets at the file list: LiDARDepth and Pods.

### (Optional) Possible Troubleshooting

By default the configuration file of this project is wrong, you will meet the error:

```bash
[Error] The sandbox is not in sync with the Podfile.lock. Run 'pod install' or update your CocoaPods installation.
```

You should go to LiDARDepth target -> Project->Configuration->Info, and change all configuration files of debug and release into the generated one. For Debug, use Pods-LiDARDepth.debug.xconfig. For release, use Pods-LiDARDepth.release.xconfig. They will make your compliering and link correctly. If you do not have a professional development account, you also need to add the code of original configuration file `LiDARDepth/Configuration/SampleCode` to both two new added configuration files to keep the right permission.

### Replace Code

Before going further, try to build the project and correct all the bugs. Then run the python script `replace_ios_files.py` to modify this project, which xxx.

### Add Network Access Permissions

Go to LiDARDepth->info->Add. Add `APP Transport Security Settings`, then add a sub-item of it `Allow Arbitrary Loads`and set it as `Yes`.

On iPhone, when the system query 'Allow APP to find local network devices?', click yes.





## Start to Stream Data

Run `ios_driver.py` on your host.

