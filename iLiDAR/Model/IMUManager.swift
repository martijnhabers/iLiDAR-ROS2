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
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000_000) // nanoseconds

        // Prepare IMUData
        var accel = Sensor_Vector3()
        accel.x = Float(acc.x)
        accel.y = Float(acc.y)
        accel.z = Float(acc.z)

        var gyro = Sensor_Vector3()
        gyro.x = Float(rot.x)
        gyro.y = Float(rot.y)
        gyro.z = Float(rot.z)

        var orientation = Sensor_Quaternion()
        orientation.x = Float(quat.x)
        orientation.y = Float(quat.y)
        orientation.z = Float(quat.z)
        orientation.w = Float(quat.w)

        var imuData = Sensor_IMUData()
        imuData.timestamp = timestamp
        imuData.accel = accel
        imuData.gyro = gyro
        imuData.orientation = orientation
        imuData.frameID = "imu_link"

        // Wrap in SensorMessage
        var sensorMsg = Sensor_SensorMessage()
        sensorMsg.imu = imuData

        do {
            let protoData = try sensorMsg.serializedData()
            let fileName = "imu_" + DataStorage.shared.eventName()
            DataStorage.shared.socketManager.sendBIN(fileName: fileName, data: protoData)
        } catch {
            print("Failed to serialize SensorMessage: \(error)")
        }
    }
}
