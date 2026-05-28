import SwiftUI

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DesignTokens.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(DesignTokens.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: DesignTokens.cardShadow, radius: 12, x: 0, y: 4)
            )
    }
}
