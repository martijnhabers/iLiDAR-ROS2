
import SwiftUI

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