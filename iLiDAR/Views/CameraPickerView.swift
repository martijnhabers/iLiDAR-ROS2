//
//  CameraPickerView.swift
//  iLiDAR
//
//  Created by Martijn Habers on 20/06/2025.
//  Copyright © 2025 Apple. All rights reserved.
//


import SwiftUI
import AVFoundation

struct CameraPickerView: View {
    @State private var selectedCameraUniqueID: String?
    private let devices: [AVCaptureDevice] = {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
    }()

    var body: some View {
        Form {
            Picker("Select Camera", selection: $selectedCameraUniqueID) {
                ForEach(devices, id: \.uniqueID) { device in
                    Text(device.localizedName).tag(device.uniqueID as String?)
                }
            }

            if let selected = devices.first(where: { $0.uniqueID == selectedCameraUniqueID }) {
                Text("Selected: \(selected.localizedName)")
                Text("Position: \(selected.position == .front ? "Front" : "Back")")
            }
        }
        .onAppear {
            selectedCameraUniqueID = devices.first?.uniqueID
        }
    }
}


#Preview("iPhone 12 Pro") {
    CameraPickerView()
        .previewDevice("iPhone 12 Pro")
}
