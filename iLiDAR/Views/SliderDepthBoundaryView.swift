import SwiftUI

struct SliderDepthBoundaryView: View {
    @Binding var val: Float
    var label: String
    var minVal: Float
    var maxVal: Float
    let stepsCount = Float(200.0)
    private let smallerFontLabels: Set<String> = ["Max Depth", "Min Depth"]
    var body: some View {
        HStack {
            Text(String(format: " %@: %.2f", label, val))
                .font(smallerFontLabels.contains(label) ? .caption : .body)
                .frame(width: 120, alignment: .leading)
            Slider(
                value: $val,
                in: minVal...maxVal,
                step: (maxVal - minVal) / stepsCount
            ) {
            } minimumValueLabel: {
                Text(String(minVal))
                    .font(.caption)
            } maximumValueLabel: {
                Text(String(maxVal))
                    .font(.caption)
            }
        }
        .padding(.horizontal)
    }
} 