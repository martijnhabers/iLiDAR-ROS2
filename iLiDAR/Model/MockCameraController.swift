import UIKit
import CoreVideo
import Combine
import AVFoundation

class MockCameraController: ObservableObject, CameraControllerProtocol {
    @Published var enableNetworkTransfer: Bool = false
    @Published var eventName: String = ""
    var isFilteringEnabled: Bool = false
    var captureSession: AVCaptureSession? { nil }
    weak var delegate: CaptureDataReceiver?
    private var timer: Timer?
    private var isStreaming = false
    
    func startStream() {
        isStreaming = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.sendMockData()
        }
    }
    
    func stopStream() {
        isStreaming = false
        timer?.invalidate()
        timer = nil
    }
    
    func capturePhoto() {
        sendMockData(isPhoto: true)
    }
    
    func toggleNetworkTransfer() {
        enableNetworkTransfer.toggle()
    }
    
    private func sendMockData(isPhoto: Bool = false) {
        guard let image = UIImage(named: "Rear Camera") else { return }
        let fakeData = CameraCapturedData.mock(with: image)
        if isPhoto {
            delegate?.onNewPhotoData(capturedData: fakeData)
        } else {
            delegate?.onNewData(capturedData: fakeData)
        }
    }
} 