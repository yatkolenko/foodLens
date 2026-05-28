import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DesignTokens.primaryGradient)
            )
            .opacity(configuration.isPressed ? 0.88 : 1.0)
    }
}

struct SecondaryOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(DesignTokens.accentGreen)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(DesignTokens.accentGreen, lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}
