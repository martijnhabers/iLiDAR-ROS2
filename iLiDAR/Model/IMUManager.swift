import Foundation
import CoreMotion
import Combine

class IMUManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private(set) var isStreaming = false
    private(set) var isPreviewing = false
    @Published var frequency: Double = 50
    @Published var quaternion = CMQuaternion(x: 0, y: 0, z: 0, w: 1)
    @Published var angularVelocity = CMRotationRate(x: 0, y: 0, z: 0)
    @Published var linearAcceleration = CMAcceleration(x: 0, y: 0, z: 0)

    // MARK: - Device Motion Updates
    private func startDeviceMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / frequency
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            self.quaternion = data.attitude.quaternion
            self.angularVelocity = data.rotationRate
            self.linearAcceleration = data.userAcceleration
            if self.isStreaming { self.sendIMUData(data) }
        }
    }

    private func stopDeviceMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: - Streaming
    func startStreaming(frequency: Double) {
        guard !isStreaming else { return }
        self.frequency = frequency
        isStreaming = true
        startDeviceMotionUpdates()
    }

    func startDummyStreaming(frequency: Double) {
        guard !isStreaming else {return}
        self.frequency = frequency
        isStreaming = true

        let quat_x = 0.1
        let quat_y = 0.2
        let quat_z = 0.3
        let quat_w = 0.4

        let rot_x = 1.1
        let rot_y = 1.2
        let rot_z = 1.3

        let acc_x = 2.1
        let acc_y = 2.2
        let acc_z = 2.3


        let timestamp = Date().timeIntervalSince1970
        let csv = String(format: "%.3f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n", timestamp, quat_x, quat_y, quat_z, quat_w, rot_x, rot_y, rot_z, acc_x, acc_y, acc_z)
        let fileName = "imu_" + DataStorage.shared.eventName()
        if let data = csv.data(using: .utf8) {
            DataStorage.shared.socketManager.sendCSV(fileName: fileName, data: data)
        }

        print("Sending dummy values now!")
    }

    func stopStreaming() {
        isStreaming = false
        if !isPreviewing { stopDeviceMotionUpdates() }
    }

    // MARK: - Preview
    func startPreview(frequency: Double) {
        guard !isPreviewing else { return }
        self.frequency = frequency
        isPreviewing = true
        startDeviceMotionUpdates()
    }

    func stopPreview() {
        isPreviewing = false
        if !isStreaming { stopDeviceMotionUpdates() }
    }

    // MARK: - Data Sending
    private func sendIMUData(_ data: CMDeviceMotion) {
        let quat = data.attitude.quaternion
        let rot = data.rotationRate
        let acc = data.userAcceleration
        let timestamp = Date().timeIntervalSince1970
        let csv = String(format: "%.3f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n", timestamp, quat.x, quat.y, quat.z, quat.w, rot.x, rot.y, rot.z, acc.x, acc.y, acc.z)
        let fileName = "imu_" + DataStorage.shared.eventName()
        if let data = csv.data(using: .utf8) {
            DataStorage.shared.socketManager.sendCSV(fileName: fileName, data: data)
        }
    }
} 
