import Foundation
import UIKit
import CoreVideo
import simd
import AVFoundation

protocol CameraControllerProtocol: AnyObject {
    var isFilteringEnabled: Bool { get set }
    var enableNetworkTransfer: Bool { get set }
    var eventName: String { get set }
    var captureSession: AVCaptureSession? { get }
    var delegate: CaptureDataReceiver? { get set }
    func startStream()
    func stopStream()
    func capturePhoto()
    func toggleNetworkTransfer()
} 