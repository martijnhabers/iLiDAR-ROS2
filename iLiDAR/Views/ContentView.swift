/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The app's main user interface.
*/

import SwiftUI
import MetalKit
import Metal

// 1. Define a custom button style for uniformity
struct UnifiedButtonStyle: ButtonStyle {
    var backgroundColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0) // Optional: add a press effect
    }
}

// Define focusable fields
enum Field: Hashable {
    case hostIP
    case hostPort
}

// Define Connection States
enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case failed
}

struct ContentView: View {
    
    @StateObject private var manager = CameraManager()
    
    @State private var maxDepth = Float(5.0)
    @State private var minDepth = Float(0.0)
    @State private var scaleMovement = Float(1.0)
    
    let maxRangeDepth = Float(15)
    let minRangeDepth = Float(0)
    
    // State variables for IP and Port
    @State private var hostIP: String = DataStorage.shared.currentHostIP
    @State private var hostPort: String = String(DataStorage.shared.currentPort)
    @State private var connectionState: ConnectionState = .disconnected
    @State private var isConnecting: Bool = false
    
    // Focus state for managing keyboard focus
    @FocusState private var focusedField: Field?
    
    var body: some View {
        VStack(spacing: 10) { // Increased spacing for better separation
            
            // Description Text at the Top (Uncomment if needed)
            /*
            Text("iLiDAR@WAIS")
                .font(.title2) // Adjust font size as needed
                .fontWeight(.semibold)
                .padding(.top)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            */
            
            // Display Only the Last Figure (DepthOverlay)
            ScrollView {
                VStack {
                    if manager.dataAvailable {
                        ZoomOnTap {
                            DepthOverlay(manager: manager,
                                         maxDepth: $maxDepth,
                                         minDepth: $minDepth
                            )
                            .aspectRatio(calcAspect(orientation: viewOrientation, texture: manager.capturedData.depth), contentMode: .fit)
                        }
                        .scaleEffect(0.9) // Reduce size by 10%
                        // Alternatively, use .frame(width: 300, height: 300) for explicit sizing
                    }
                }
                .padding()
            }
            
            // Box of Filters using GroupBox
            GroupBox(label: Label("Filters", systemImage: "slider.horizontal.3")) {
                VStack(spacing: 10) { // Added spacing between elements
                    // Depth Filtering Toggle
                    Toggle(isOn: $manager.isFilteringDepth) {
                        Text("Depth Filtering")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .padding(.horizontal)
                    
                    // Sliders for Depth Boundaries
                    SliderDepthBoundaryView(val: $maxDepth, label: "Max Depth", minVal: minRangeDepth, maxVal: maxRangeDepth)
                    SliderDepthBoundaryView(val: $minDepth, label: "Min Depth", minVal: minRangeDepth, maxVal: maxRangeDepth)
                    // Add more filter controls here if needed
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal)
            
            // Network Settings Box using GroupBox
            GroupBox(label: Label("Network Settings", systemImage: "network")) {
                VStack(alignment: .leading, spacing: 10) {
                    // IP Address Input
                    HStack {
                        Text("IP Address:")
                            .font(.body)
                        TextField("Enter IP", text: $hostIP)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numbersAndPunctuation)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .focused($focusedField, equals: .hostIP) // Bind focus
                    }
                    
                    // Port Input
                    HStack {
                        Text("Port:")
                            .font(.body)
                        TextField("Enter Port", text: $hostPort)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .onReceive(hostPort.publisher.collect()) { newValue in
                                // Allow only numbers in the port field
                                let filtered = newValue.compactMap { "0123456789".contains($0) ? String($0) : nil }.joined()
                                if filtered != hostPort {
                                    self.hostPort = filtered
                                }
                            }
                            .focused($focusedField, equals: .hostPort) // Bind focus
                    }
                    
                    // Connect/Disconnect Button
                    Button(action: {
                        // Dismiss the keyboard by removing focus
                        focusedField = nil
                        
                        switch connectionState {
                        case .connected:
                            disconnectButtonTapped()
                        case .disconnected, .failed:
                            connectButtonTapped()
                        default:
                            break
                        }
                    }) {
                        HStack {
                            Image(systemName: connectionState == .connected ? "wifi.slash" : "wifi.and.arrow.up")
                            Text(connectionState == .connected ? "Disconnect" : "Connect")
                                .font(.body)
                        }
                    }
                    .buttonStyle(UnifiedButtonStyle(backgroundColor: connectionState == .connected ? .red : .blue))
                    .disabled(isConnecting)
                    
                    // Connection Status
                    Text("Status: \(statusText)")
                        .font(.subheadline)
                        .foregroundColor(statusColor)
                }
                .padding()
            }
            .padding(.horizontal)
            
            // Network Transfer Toggle Button
            Button(action: {
                manager.toggleNetworkTransfer()
            }) {
                HStack {
                    Image(systemName: manager.enableNetworkTransfer ? "network" : "network.slash")
                    Text(manager.enableNetworkTransfer ? "Disable Network Transfer" : "Enable Network Transfer")
                        .font(.body)
                }
            }
            .buttonStyle(UnifiedButtonStyle(backgroundColor: manager.enableNetworkTransfer ? .red : .green))
            
            // Optional: Display Current Event Name
            if manager.enableNetworkTransfer {
                Text("Current Event: \(manager.eventName)")
                    .font(.subheadline)
                    .padding(.top, 5)
            }
            
            Spacer() // Push content to the top
        }
        .padding()
        // Dismiss keyboard when tapping outside input fields
        .onTapGesture {
            focusedField = nil
        }
    }
    
    // Computed properties for status text and color
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
    
    // MARK: - Connect Button Action
    private func connectButtonTapped() {
        guard let port = Int(hostPort), port > 0 && port <= 65535 else {
            connectionState = .failed
            return
        }
        
        isConnecting = true
        connectionState = .connecting
        
        // Update connection in DataStorage
        DataStorage.shared.updateConnection(host_ip: hostIP, port: port)
        
        // Simulate connection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if DataStorage.shared.readyToSend {
                connectionState = .connected
            } else {
                connectionState = .failed
            }
            isConnecting = false
        }
    }
    
    // MARK: - Disconnect Button Action
    private func disconnectButtonTapped() {
        isConnecting = true
        connectionState = .disconnecting
        
        // Perform disconnection logic here
        DataStorage.shared.disconnect() // Ensure this method exists in DataStorage
        
        // Simulate disconnection delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            connectionState = .disconnected
            isConnecting = false
        }
    }
}

struct SliderDepthBoundaryView: View {
    @Binding var val: Float
    var label: String
    var minVal: Float
    var maxVal: Float
    let stepsCount = Float(200.0)
    
    // Define labels that require smaller fonts
    private let smallerFontLabels: Set<String> = ["Max Depth", "Min Depth"]
    
    var body: some View {
        HStack {
            Text(String(format: " %@: %.2f", label, val))
                .font(smallerFontLabels.contains(label) ? .caption : .body) // Apply smaller font conditionally
                .frame(width: 120, alignment: .leading) // Fixed width for labels
            Slider(
                value: $val,
                in: minVal...maxVal,
                step: (maxVal - minVal) / stepsCount
            ) {
            } minimumValueLabel: {
                Text(String(minVal))
                    .font(.caption)
            } maximumValueLabel: {
                Text(String(maxVal))
                    .font(.caption)
            }
        }
        .padding(.horizontal)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPhone 12 Pro Max")
    }
}


