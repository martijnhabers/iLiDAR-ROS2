enum Field: Hashable {
    case hostIP
    case hostPort
}

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case disconnecting
    case failed
} 