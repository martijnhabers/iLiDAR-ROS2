import SwiftUI
import AVFoundation

struct CameraSettingsView: View {
    @State private var selectedCameraUniqueID: String?
    @State private var previewEnabled: Bool = false
    @StateObject private var previewManager = CameraPreviewSessionManager()

    private let devices: [AVCaptureDevice] = {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
    }()

    var body: some View {
        Form {
            Section(header: Text("Camera")) {
                Picker("Camera", selection: $selectedCameraUniqueID) {
                    ForEach(devices, id: \ .uniqueID) { device in
                        Text(device.localizedName).tag(device.uniqueID as String?)
                    }
                }
                .onChange(of: selectedCameraUniqueID) { _ in
                    reconfigureSession()
                }
            }
            Section(header: Text("Preview")) {
                Toggle(isOn: $previewEnabled) {
                    Text("Live Camera Preview")
                }
                .onChange(of: previewEnabled) { enabled in
                    if enabled {
                        reconfigureSession()
                    } else {
                        previewManager.stopSession()
                    }
                }
                if previewEnabled, let session = previewManager.session {
                    CameraPreviewView(session: session)
                        .frame(height: 240)
                        .cornerRadius(12)
                        .padding(.top, 8)
                        .onAppear {
                            previewManager.startSession()
                        }
                        .onDisappear {
                            previewManager.stopSession()
                        }
                }
            }
        }
        .onAppear {
            selectedCameraUniqueID = devices.first?.uniqueID
            reconfigureSession()
        }
        .onDisappear {
            previewManager.stopSession()
        }
        .navigationTitle("Camera Settings")
    }

    private func reconfigureSession() {
        guard previewEnabled,
              let uniqueID = selectedCameraUniqueID,
              let device = devices.first(where: { $0.uniqueID == uniqueID }) else { return }
        previewManager.configureSession(for: device)
    }

    private func cameraPositionString(_ position: AVCaptureDevice.Position) -> String {
        switch position {
        case .front: return "Front"
        case .back: return "Back"
        case .unspecified: return "Unspecified"
        @unknown default: return "Unknown"
        }
    }
}