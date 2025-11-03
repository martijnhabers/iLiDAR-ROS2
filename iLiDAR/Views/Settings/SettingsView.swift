import SwiftUI
import AVFoundation
import CoreMotion

struct FormatKey: Hashable {
    let width: Int32
    let height: Int32
    let fps: Double

    func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(Int(fps * 1000)) // Avoid floating point issues
    }

    static func == (lhs: FormatKey, rhs: FormatKey) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height && abs(lhs.fps - rhs.fps) < 0.001
    }
}

struct SettingsView: View {
    @ObservedObject var imuManager: IMUManager
    @ObservedObject var manager: CameraManager
    @Binding var hostIP: String
    @Binding var hostPort: String
    @Binding var connectionState: ConnectionState
    @Binding var isConnecting: Bool
    var connectAction: () -> Void
    var disconnectAction: () -> Void
    var statusText: String
    var statusColor: Color
    @Binding var isFilteringDepth: Bool
    @Binding var maxDepth: Float
    @Binding var minDepth: Float
    let maxRangeDepth: Float
    let minRangeDepth: Float
    @Binding var imuFrequency: Double
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Sensor Settings")) {
                    NavigationLink(destination: IMUSettingsView(imuFrequency: $imuFrequency, imuManager: imuManager)) {
                        Label("IMU", systemImage: "gyroscope")
                    }
                    NavigationLink(destination: CameraSettingsView()) {
                        Label("Camera", systemImage: "camera")
                    }
                    NavigationLink(
                        destination: DepthSettingsView(
                            isFilteringDepth: $isFilteringDepth,
                            maxDepth: $maxDepth,
                            minDepth: $minDepth,
                            maxRangeDepth: maxRangeDepth,
                            minRangeDepth: minRangeDepth
                        )
                    ) {
                        Label("Depth", systemImage: "cube.transparent")
                    }
                }
                Section(header: Text("App Settings")) {
                    NavigationLink(
                        destination: NetworkSettingsView(
                            hostIP: $hostIP,
                            hostPort: $hostPort,
                            connectionState: $connectionState,
                            isConnecting: $isConnecting,
                            connectAction: connectAction,
                            disconnectAction: disconnectAction,
                            statusText: statusText,
                            statusColor: statusColor
                        )
                    ) {
                        Label("Network", systemImage: "network")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}


class CameraPreviewSessionManager: ObservableObject {
    @Published var session: AVCaptureSession? = nil
    private var input: AVCaptureDeviceInput?
    private var output: AVCaptureVideoDataOutput?
    private var isRunning = false

    func configureSession(for device: AVCaptureDevice) {
        stopSession()
        let newSession = AVCaptureSession()
        newSession.beginConfiguration()
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if newSession.canAddInput(input) {
                newSession.addInput(input)
                self.input = input
            }
            let output = AVCaptureVideoDataOutput()
            if newSession.canAddOutput(output) {
                newSession.addOutput(output)
                self.output = output
            }
            newSession.commitConfiguration()
            self.session = newSession
        } catch {
            print("Failed to configure camera session: \(error)")
            self.session = nil
        }
    }

    func startSession() {
        guard let session = session, !isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    func stopSession() {
        guard let session = session, isRunning else { return }
        session.stopRunning()
        self.isRunning = false
        self.session = nil
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.session = session
        context.coordinator.previewLayer?.frame = uiView.bounds
    }
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}