import SwiftUI
import UIKit

struct FloatingLabelTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var axis: Axis = .horizontal
    var lineLimit: Int = 1
    var minHeight: CGFloat = 60
    var textInputAutocapitalization: TextInputAutocapitalization? = .sentences
    var autocorrectionDisabled = false

    @FocusState private var isFocused: Bool

    private var isLifted: Bool {
        isFocused || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var borderColor: Color {
        isFocused ? DesignTokens.inputStrokeFocused : DesignTokens.inputStroke
    }

    private var labelColor: Color {
        isFocused ? DesignTokens.inputLabelFocused : DesignTokens.inputLabel
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DesignTokens.inputBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(borderColor, lineWidth: isFocused ? 1.5 : 1)
                )
                .shadow(
                    color: isFocused ? DesignTokens.accentGreen.opacity(0.10) : .clear,
                    radius: 12,
                    x: 0,
                    y: 4
                )

            TextField("", text: $text, axis: axis)
                .focused($isFocused)
                .keyboardType(keyboardType)
                .lineLimit(lineLimit)
                .textInputAutocapitalization(textInputAutocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .foregroundStyle(DesignTokens.textPrimary)
                .padding(.horizontal, 16)
                .padding(.top, isLifted ? 28 : 18)
                .padding(.bottom, 14)

            Text(title)
                .font(isLifted ? .caption.weight(.semibold) : .body)
                .foregroundStyle(labelColor)
                .padding(.horizontal, 16)
                .padding(.top, isLifted ? 10 : 18)
                .scaleEffect(isLifted ? 0.86 : 1, anchor: .leading)
                .animation(.spring(response: 0.26, dampingFraction: 0.86), value: isLifted)
                .allowsHitTesting(false)
        }
        .frame(minHeight: minHeight, alignment: .topLeading)
    }
}
