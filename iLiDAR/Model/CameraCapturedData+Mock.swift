import Foundation
import UIKit
import CoreVideo
import simd
import AVFoundation
import Metal

extension CameraCapturedData {
    static func mock(with image: UIImage) -> CameraCapturedData {
        // Create a Metal device and texture cache
        let device = MTLCreateSystemDefaultDevice()!
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        let cache = textureCache!

        // Create a dummy CVPixelBuffer for depth (e.g., 640x480, float16)
        let width = 640
        let height = 480
        var depthBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_DepthFloat16, attrs, &depthBuffer)
        if let buffer = depthBuffer {
            CVPixelBufferLockBaseAddress(buffer, [])
            let ptr = unsafeBitCast(CVPixelBufferGetBaseAddress(buffer), to: UnsafeMutablePointer<Float16>.self)
            let count = width * height
            for i in 0..<count {
                ptr[i] = Float16(1.0) // constant depth value
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
        }

        // Convert UIImage to CVPixelBuffer (BGRA)
        let colorBuffer = image.pixelBuffer(width: width, height: height)

        // Create dummy calibration data (identity matrix, etc.)
        let matrix = matrix_float3x3(diagonal: SIMD3<Float>(repeating: 1.0))
        let refDims = CGSize(width: width, height: height)

        // Use BGRA for colorY and colorCbCr if multi-plane is not available
        let colorY = colorBuffer?.texture(withFormat: .bgra8Unorm, planeIndex: 0, addToCache: cache)
        let colorCbCr = colorY // For mock, use same texture for both

        return CameraCapturedData(
            depth: depthBuffer?.texture(withFormat: .r16Float, planeIndex: 0, addToCache: cache),
            colorY: colorY,
            colorCbCr: colorCbCr,
            cameraIntrinsics: matrix,
            cameraReferenceDimensions: refDims
        )
    }
}

extension UIImage {
    func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                         kCVPixelFormatType_32BGRA, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                width: width,
                                height: height,
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        if let cgImage = self.cgImage {
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
} 