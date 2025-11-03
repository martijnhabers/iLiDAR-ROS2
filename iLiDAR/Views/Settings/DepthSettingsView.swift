import SwiftUI

struct DepthSettingsView: View {
    @Binding var isFilteringDepth: Bool
    @Binding var maxDepth: Float
    @Binding var minDepth: Float
    let maxRangeDepth: Float
    let minRangeDepth: Float

    var body: some View {
        Form {
            Section(header: Text("Depth Filtering")) {
                Toggle(isOn: $isFilteringDepth) {
                    Text("Depth Filtering")
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .padding(.horizontal)
                SliderDepthBoundaryView(val: $maxDepth, label: "Max Depth", minVal: minRangeDepth, maxVal: maxRangeDepth)
                SliderDepthBoundaryView(val: $minDepth, label: "Min Depth", minVal: minRangeDepth, maxVal: maxRangeDepth)
            }
        }
        .navigationTitle("Depth Settings")
    }
}