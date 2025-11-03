import SwiftUI

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