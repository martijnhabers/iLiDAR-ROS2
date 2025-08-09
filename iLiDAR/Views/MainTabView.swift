import SwiftUI

struct MainTabView: View {
    @StateObject private var imuManager = IMUManager()
    @StateObject private var manager = CameraManager()
    @State private var hostIP: String = DataStorage.shared.currentHostIP
    @State private var hostPort: String = String(DataStorage.shared.currentPort)
    @State private var connectionState: ConnectionState = .disconnected
    @State private var isConnecting: Bool = false
    @State private var isFilteringDepth: Bool = false
    @State private var maxDepth = Float(5.0)
    @State private var minDepth = Float(0.0)
    let maxRangeDepth = Float(15)
    let minRangeDepth = Float(0)
    @State var imuFrequency: Double = 50

    var body: some View {
        TabView {
            ContentView(imuFrequency: $imuFrequency, manager: manager)
                .tabItem {
                    Label("Sensors", systemImage: "camera.viewfinder")
                }
            SettingsView(
                imuManager: imuManager,
                manager: manager,
                hostIP: $hostIP,
                hostPort: $hostPort,
                connectionState: $connectionState,
                isConnecting: $isConnecting,
                connectAction: connectButtonTapped,
                disconnectAction: disconnectButtonTapped,
                statusText: statusText,
                statusColor: statusColor,
                isFilteringDepth: $isFilteringDepth,
                maxDepth: $maxDepth,
                minDepth: $minDepth,
                maxRangeDepth: maxRangeDepth,
                minRangeDepth: minRangeDepth,
                imuFrequency: $imuFrequency
            )
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
    private var statusText: String {
        switch connectionState {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnecting:
            return "Disconnecting..."
        case .disconnected:
            return "Disconnected"
        case .failed:
            return "Failed to Connect"
        }
    }
    private var statusColor: Color {
        switch connectionState {
        case .connected:
            return .green
        case .failed, .disconnected, .disconnecting:
            return .red
        case .connecting:
            return .orange
        }
    }
    private func connectButtonTapped() {
        guard let port = Int(hostPort), port > 0 && port <= 65535 else {
            connectionState = .failed
            return
        }
        isConnecting = true
        connectionState = .connecting
        DataStorage.shared.updateConnection(host_ip: hostIP, port: port) { success in
            DispatchQueue.main.async {
                if success {
                    self.connectionState = .connected
                } else {
                    self.connectionState = .failed
                }
                self.isConnecting = false
            }
        }
    }
    private func disconnectButtonTapped() {
        isConnecting = true
        connectionState = .disconnecting
        DataStorage.shared.disconnect()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            connectionState = .disconnected
            isConnecting = false
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
} 