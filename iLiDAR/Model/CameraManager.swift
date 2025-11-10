import AVFoundation
import Foundation
import CoreImage
import UIKit

class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate {
    @Published var resolution: CGSize = .zero
    @Published var frameRate: Int = 0
    @Published var isRunning: Bool = false
    @Published var isStreaming: Bool = false

    @Published var depthEnabled: Bool = false
    @Published var cameraEnabled: Bool = false

    private var frame_counter: Int = 0

    private var captureSession: AVCaptureSession?
    private let context = CIContext()
    // Store the selected AVCaptureDevice so other setup methods can access it
    private var videoDevice: AVCaptureDevice?

    override init() {
        super.init()
        setupCaptureSession()
    }

private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }

        captureSession.beginConfiguration()

        setupCaptureInputs()
        setupCaptureoutputs()

        captureSession.commitConfiguration()
    }

    private func setupCaptureInputs() {
        // Setup input device
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Error: Unable to find a video device.")
            return
        }

        // Save to property so other methods (like setupCaptureSession) can read its format/frame rate
        self.videoDevice = device

        guard let videoInput = try? AVCaptureDeviceInput(device: device), captureSession?.canAddInput(videoInput) == true else {
            print("Error: Unable to add video input.")
            return
        }

        captureSession?.addInput(videoInput)
    }

    private func setupCaptureoutputs() {
        // Ensure captureSession is available
        guard let captureSession = captureSession else {
            print("Error: captureSession is not initialized.")
            return
        }
         // Setup video output
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        guard captureSession.canAddOutput(videoDataOutput) else {
            print("Error: Unable to add video output.")
            return
        }
         captureSession.addOutput(videoDataOutput)

         // Send camera intrinsics, if possible
         let connection = videoDataOutput.connection(with: .video)
         if connection?.isCameraIntrinsicMatrixDeliverySupported == true {
             connection?.isCameraIntrinsicMatrixDeliveryEnabled = true
         }

         // Setup depth output
         let depthDataOutput = AVCaptureDepthDataOutput()
         depthDataOutput.setDelegate(self, callbackQueue: DispatchQueue(label: "depthQueue"))
         if captureSession.canAddOutput(depthDataOutput) {
             captureSession.addOutput(depthDataOutput)
         }

     }

    func startSession() {
        print("Starting camera session with these settings - Depth Enabled: \(depthEnabled), Camera Enabled: \(cameraEnabled) and this camera: \(String(describing: captureSession))")
        captureSession?.startRunning()
        isRunning = true
    }

    func stopSession() {
        print("Stopping camera session")
        captureSession?.stopRunning()
        isRunning = false
    }

    func startStreaming() {
        // Implement streaming logic here
        startSession()
        isStreaming = true
    }

    func stopStreaming() {
        if !isStreaming{
            return
        }

        // Implement stop streaming logic here
        isStreaming = false
    }

    // MARK: - AVCapture Output Delegates
    // Video sample buffer delegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Minimal handling: update resolution from first video frame

        if frame_counter % 2 != 0 {
            // Skip every other frame to reduce bandwidth
            return
        }

        // Convert the sample buffer to an image
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to get image buffer")
            return
        }
        
        // Convert to UIImage then to JPEG data
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Failed to create CGImage")
            return
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert to JPEG")
            return
        }
        
        // Get timestamp (nanoseconds since epoch)
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
        
        // Get image dimensions
        let width = UInt32(cgImage.width)
        let height = UInt32(cgImage.height)
        
        // Create the protobuf message
        var cameraData = Sensor_CameraData()
        cameraData.timestamp = timestamp
        cameraData.width = width
        cameraData.height = height
        cameraData.encoding = "jpeg"
        cameraData.imageData = jpegData
        cameraData.frameID = "camera_link"
        
        // Wrap it in the sensor message envelope
        var sensorMessage = Sensor_SensorMessage()
        sensorMessage.camera = cameraData

        // Serialize and send the data over the socket, similar to IMUManager
        do {
            let serializedData = try sensorMessage.serializedData()
            let fileName = "camera_" + DataStorage.shared.eventName()
            DataStorage.shared.socketManager.sendBIN(fileName: fileName, data: serializedData)
            print("Serialized and sent \(serializedData.count) bytes as \(fileName)")
        } catch {
            print("Failed to serialize: \(error)")
        }

        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let width = CVPixelBufferGetWidth(imageBuffer)
            let height = CVPixelBufferGetHeight(imageBuffer)
            DispatchQueue.main.async {
                self.resolution = CGSize(width: width, height: height)
            }
        }

        frame_counter += 1
    }

    // Depth data delegate
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // No-op placeholder for depth data handling; implement as needed
    }
}