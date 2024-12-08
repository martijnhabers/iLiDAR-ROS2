## Full Tutorial

If you want to build this project from scratch or make significant modifications, follow this tutorial:

### Run Official Example

First, download the official example from:

```
https://developer.apple.com/documentation/avfoundation/additional_data_capture/capturing_depth_using_the_lidar_camera
```

This is a Swift project, but you can proceed even if you're not familiar with Swift. Extract the project and move it into your project folder. Then, try to compile and run it on your iPhone. You may need to handle connection issues (set your device as the build target, trust your macOS on the iPhone) or development permissions (register a development team and log in). Once the build succeeds, you will see your iPhone capturing depth data and RGB images, which will be visualized on the screen.

### Set the Third-party Extension

To manage third-party extensions, you need to install [cocoapods](https://cocoapods.org/) via `gem`:

```bash
# one possible download method
brew gem install cocoapods
cd LiDARDepth
pod init
```

Modify the generated `Podfile` to:

```ini
# Uncomment the next line to define a global platform for your project
# platform :ios, '15.6'

target 'LiDARDepth' do
  pod 'CocoaAsyncSocket'
  pod 'ReactiveCocoa', '~> 11.0'
  source 'https://github.com/CocoaPods/Specs.git'
  
end
```
Then, run

```bash
pod install
```

This may take some time, and you may need to ensure your VPN is set up correctly. After the installation completes, open the `LiDARDepth.xcworkspace file`, and you'll see two targets: `LiDARDepth` and `Pods`.

### (Optional) Possible Troubleshooting

By default, the configuration files might be incorrect. You may encounter the following error:

```bash
[Error] The sandbox is not in sync with the Podfile.lock. Run 'pod install' or update your CocoaPods installation.
```

To resolve this, go to `LiDARDepth` target -> Project -> Configuration -> Info, and change the configuration files for Debug and Release to the generated ones. For Debug, use `Pods-LiDARDepth.debug.xconfig`, and for Release, use `Pods-LiDARDepth.release.xconfig`. These configurations will ensure correct compiling and linking. If you don't have a professional development account, you may also need to add the original configuration file code from `LiDARDepth/Configuration/SampleCode` to both the Debug and Release configuration files to maintain the correct permissions.

### Replace Code

Once the project builds without errors, you can start writing your own depth camera app with network support.