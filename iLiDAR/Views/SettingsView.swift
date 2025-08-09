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

struct IMUSettingsView: View {
    @Binding var imuFrequency: Double
    @FocusState private var isFrequencyFieldFocused: Bool
    @ObservedObject var imuManager: IMUManager
    @State private var previewEnabled: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("IMU Frequency")) {
                HStack {
                    Text("Frequency")
                    Spacer()
                    TextField("Hz", value: $imuFrequency, format: .number)
                        .keyboardType(.numberPad)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                        .focused($isFrequencyFieldFocused)
                        .onChange(of: imuFrequency) { newValue in
                            if imuFrequency < 1 { imuFrequency = 1 }
                            if imuFrequency > 500 { imuFrequency = 500 }
                        }
                    Text("Hz")
                        .foregroundColor(.secondary)
                }
            }
            Section(header: Text("Preview")) {
                Toggle(isOn: $previewEnabled) {
                    Text("Live IMU Preview")
                }
                .onChange(of: previewEnabled) { enabled in
                    if enabled {
                        imuManager.startPreview(frequency: imuFrequency)
                    } else {
                        imuManager.stopPreview()
                    }
                }
                if previewEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quaternion Orientation:")
                        Text(String(format: "x: %.3f, y: %.3f, z: %.3f, w: %.3f", imuManager.quaternion.x, imuManager.quaternion.y, imuManager.quaternion.z, imuManager.quaternion.w))
                            .font(.caption)
                        Divider()
                        Text("Angular Velocity (rad/s):")
                        Text(String(format: "x: %.3f, y: %.3f, z: %.3f", imuManager.angularVelocity.x, imuManager.angularVelocity.y, imuManager.angularVelocity.z))
                            .font(.caption)
                        Divider()
                        Text("Linear Acceleration (g):")
                        Text(String(format: "x: %.3f, y: %.3f, z: %.3f", imuManager.linearAcceleration.x, imuManager.linearAcceleration.y, imuManager.linearAcceleration.z))
                            .font(.caption)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationTitle("IMU Settings")
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

struct DepthSettingsView: View {
    @Binding var isFilteringDepth: Bool
    @Binding var maxDepth: Float
    @Binding var minDepth: Float
    let maxRangeDepth: Float
    let minRangeDepth: Float

    var body: some View {
        Form {
            Section(header: Text("Depth Filtering")) {
                Toggle(isOn: $isFilteringDepth) {
                    Text("Depth Filtering")
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .padding(.horizontal)
                SliderDepthBoundaryView(val: $maxDepth, label: "Max Depth", minVal: minRangeDepth, maxVal: maxRangeDepth)
                SliderDepthBoundaryView(val: $minDepth, label: "Min Depth", minVal: minRangeDepth, maxVal: maxRangeDepth)
            }
        }
        .navigationTitle("Depth Settings")
    }
}

struct NetworkSettingsView: View {
    @Binding var hostIP: String
    @Binding var hostPort: String
    @Binding var connectionState: ConnectionState
    @Binding var isConnecting: Bool
    var connectAction: () -> Void
    var disconnectAction: () -> Void
    var statusText: String
    var statusColor: Color
    @FocusState private var focusedField: Field?

    var body: some View {
        Form {
            Section(header: Text("Network Settings")) {
                TextField("IP Address", text: $hostIP)
                    .keyboardType(.numbersAndPunctuation)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .hostIP)
                TextField("Port", text: $hostPort)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .hostPort)
            }
            Section {
                Button(action: {
                    focusedField = nil
                    if connectionState == .connected {
                        disconnectAction()
                    } else {
                        connectAction()
                    }
                }) {
                    HStack {
                        Image(systemName: connectionState == .connected ? "wifi.slash" : "wifi")
                        Text(connectionState == .connected ? "Disconnect" : "Connect")
                    }
                }
                .disabled(isConnecting)
                .foregroundColor(.white)
                .listRowBackground(connectionState == .connected ? Color.red : Color.blue)
            }
            Section {
                Text("Status: \(statusText)")
                    .foregroundColor(statusColor)
            }
        }
        .navigationTitle("Network Settings")
    }
} 


