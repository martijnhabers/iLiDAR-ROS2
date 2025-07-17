import SwiftUI

struct UnifiedButtonStyle: ButtonStyle {
    var backgroundColor: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(8)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
} 