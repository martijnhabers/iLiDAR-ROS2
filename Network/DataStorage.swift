//
//  DataStorage.swift
//  iLiDAR
//
//  Created by 梁博 on 2024/12/5.
//  Copyright © 2024 Apple. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class DataStorage {
    static let shared = DataStorage()
    
    let socketManager = SocketManager()
    let compressionQuality: CGFloat = 0.4
    var readyToSend: Bool = false
    
    private(set) var currentHostIP = "10.129.164.22"
    private(set) var currentPort = 5678
    
    init() {
        socketManager.connectToServer(host_ip: currentHostIP, port: currentPort)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.readyToSend = true
        }
    }
    
    func disconnect() {
        socketManager.disconnect()
        readyToSend = false
    }
    
    // Method to update IP and port
    func updateConnection(host_ip: String, port: Int) {
        // Disconnect existing connection
        socketManager.disconnect()
        
        // Update current IP and port
        currentHostIP = host_ip
        currentPort = port
        
        // Attempt to connect with new settings
        socketManager.connectToServer(host_ip: host_ip, port: port)
        
        // Reset readyToSend and set it after a delay
        readyToSend = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.readyToSend = true
            print("Ready to send data with new connection settings.")
        }
    }
    
    func convertDepthData(depthData: CVPixelBuffer) -> Data? {
        CVPixelBufferLockBaseAddress(depthData, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(depthData, .readOnly)
        }
        
        let width = CVPixelBufferGetWidth(depthData)
        let height = CVPixelBufferGetHeight(depthData)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthData)
        let float16Size = MemoryLayout<Float16>.size // expected to be 16 bits
        let rowBytes = width * float16Size
        assert(rowBytes <= bytesPerRow, "Unexpected pixel buffer layout.")
        let totalBytes = rowBytes * height
        
        var data = Data(count: totalBytes)
        // Get a pointer to the start of the data
        data.withUnsafeMutableBytes { mutableBytes in
            guard let basePointer = mutableBytes.bindMemory(to: UInt8.self).baseAddress else {
                print("Failed to bind memory to UInt8.")
                return
            }
            
            var currentOffset = 0
            guard let rowPointerBase = CVPixelBufferGetBaseAddressOfPlane(depthData, 0) else {
                print("Failed to get base address of plane 0.")
                return
            }
            
            // Iterate over each row
            for y in 0..<height {
                let rowPointer = rowPointerBase.advanced(by: y * bytesPerRow)
                let rowBytes = min(bytesPerRow, width * float16Size)
                memcpy(basePointer + currentOffset, rowPointer, rowBytes)
                currentOffset += width * float16Size
            }
        }
        return data
    }
    
    func transmitFrame(imageData: CVImageBuffer, depthData: CVPixelBuffer, fileName: String) {
        if !readyToSend {
            print("Fail to establish socket for data transmission.")
            return
        }
        
        let ciImage = CIImage(cvImageBuffer: imageData)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Error converting CVImageBuffer to JPEG data.")
            return
        }
        let uiImage = UIImage(cgImage: cgImage)
        // compress the figure for better transmission
        guard let jpegData = uiImage.jpegData(compressionQuality: compressionQuality) else {
            print("Error converting UIImage to JPEG data.")
            return
        }
        
        if let transmitDepth = convertDepthData(depthData: depthData) {
            socketManager.sendBIN(fileName: fileName + ".bin", data: transmitDepth)
            
        } else {
            print("Fail to convert depth data.")
        }
        socketManager.sendJPG(fileName: fileName + ".jpg", data: jpegData)
    }
    
    func transmitConfig(calibrationData: AVCameraCalibrationData, fileName: String) {
        if !readyToSend {
            print("Fail to establish socket for data transmission.")
            return
        }
        
        let intrinsicMatrix = calibrationData.intrinsicMatrix
        print(intrinsicMatrix)
        let fx = intrinsicMatrix.columns.0.x
        let fy = intrinsicMatrix.columns.1.y
        let cx = intrinsicMatrix.columns.2.x
        let cy = intrinsicMatrix.columns.2.y
        
        var csvContent = "fx,fy,cx,cy\n"
        csvContent += "\(fx),\(fy),\(cx),\(cy)\n"
        
        if let csvData = csvContent.data(using: .utf8) {
            socketManager.sendCSV(fileName: fileName  + ".csv", data: csvData)
        } else {
            print("Fail to convert CSV content to Data")
        }
    }
    
    func frameName(frameCounter: Int) -> String {
        // call this function to record the timestamp of each frame
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss_SS"
        let timestamp = dateFormatter.string(from: Date())
        
        return timestamp + "_" + String(format: "frame%06d", frameCounter)
    }
    
    func eventName() -> String {
        // only call this once when the camera starts
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        return timestamp
    }
    
}
