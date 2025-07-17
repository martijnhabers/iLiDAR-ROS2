/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The app's main user interface.
*/

import SwiftUI
import MetalKit
import Metal
import CoreMotion

struct ContentView: View {
    @Binding var imuFrequency: Double
    @ObservedObject var manager: CameraManager
    @StateObject private var imuManager = IMUManager()
    @State private var maxDepth = Float(5.0)
    @State private var minDepth = Float(0.0)
    @State private var scaleMovement = Float(1.0)
    let maxRangeDepth = Float(15)
    let minRangeDepth = Float(0)
    @State private var imuEnabled = false
    @State private var cameraEnabled = true
    @State private var depthEnabled = true
    @State private var isRunning = false
    private var connectionIndicatorColor: Color {
        DataStorage.shared.readyToSend ? .green : .red
    }
    var body: some View {
        VStack(spacing: 10) {
            ScrollView {
                VStack {
                    /*
                    if manager.dataAvailable {
                        ZoomOnTap {
                            DepthOverlay(manager: manager,
                                         maxDepth: $maxDepth,
                                         minDepth: $minDepth
                            )
                            .aspectRatio(calcAspect(orientation: viewOrientation, texture: manager.capturedData.depth), contentMode: .fit)
                        }
                        .scaleEffect(0.9)
                    }
                    */
                }
                .padding()
            }
            VStack(spacing: 16) {
                Toggle(isOn: $imuEnabled) {
                    HStack {
                        Image(systemName: "gyroscope")
                        Text("Enable IMU")
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .disabled(isRunning)
                Toggle(isOn: $cameraEnabled) {
                    HStack {
                        Image(systemName: "camera")
                        Text("Enable Camera")
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .disabled(isRunning)
                Toggle(isOn: $depthEnabled) {
                    HStack {
                        Image(systemName: "cube.transparent")
                        Text("Enable Depth")
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .disabled(isRunning)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            Spacer()
            Button(action: {
                if isRunning {
                    // Stop all streaming
                    manager.controller.stopStream()
                    manager.controller.enableNetworkTransfer = false
                    imuManager.stopStreaming()
                } else {
                    // Start streaming only selected sensors
                    if cameraEnabled || depthEnabled {
                        manager.controller.enableNetworkTransfer = true
                        manager.controller.startStream()
                    }
                    if imuEnabled {
                        imuManager.startDummyStreaming(frequency: imuFrequency)
                        print("start dummy stream from button side")
                    }
                }
                isRunning.toggle()
            }) {
                HStack {
                    Image(systemName: isRunning ? "stop.fill" : "play.fill")
                    Text(isRunning ? "Stop Streaming" : "Start Streaming")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isRunning ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .padding()
        .onTapGesture {
            focusedField = nil
        }
    }
    @FocusState private var focusedField: Field?
}

// struct ContentView_Previews: PreviewProvider {
//     static var previews: some View {
//         ContentView(imuFrequency: .constant(50))
//             .previewDevice("iPhone 12 Pro Max")
//     }
// }


