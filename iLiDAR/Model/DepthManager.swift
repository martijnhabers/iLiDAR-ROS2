// Created by Martijn Habers on 09/08/2025

// 

import Foundation
import AVFoundation


class DepthManager: ObservableObject {
    @Published var isStreaming = false
    @Published var isPreviewing = false
    @Published var fps: Double = 10.0
    var depthData: [Float] = []
    
    
    init() {}
    
    func startStreaming(frequency: Double) {
        guard !isStreaming else { return }
        self.frequency = frequency
        isStreaming = true
        controller.startDepthUpdates(frequency: frequency)
    }
    
    func stopStreaming() {
        isStreaming = false
        controller.stopDepthUpdates()
    }
    
    func startPreview(frequency: Double) {
        guard !isPreviewing else { return }
        self.frequency = frequency
        isPreviewing = true
        controller.startDepthUpdates(frequency: frequency)
    }
    
    func stopPreview() {
        isPreviewing = false
        controller.stopDepthUpdates()
    }

}
