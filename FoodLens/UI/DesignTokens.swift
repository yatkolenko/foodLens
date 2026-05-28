import SwiftUI
import UIKit

enum DesignTokens {
    static let background = Color(
        uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.08, blue: 0.07, alpha: 1)
                : UIColor(red: 0.96, green: 0.97, blue: 0.96, alpha: 1)
        }
    )
    static let card = Color(
        uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.14, blue: 0.13, alpha: 1)
                : .white
        }
    )
    static let cardElevated = Color(
        uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.14, green: 0.18, blue: 0.16, alpha: 1)
                : .white
        }
    )
    static let surfaceMuted = Color(
        uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.16, green: 0.20, blue: 0.19, alpha: 1)
                : UIColor(red: 0.95, green: 0.96, blue: 0.95, alpha: 1)
        }
    )
    static let surfaceSoftGreen = Color(
        uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.10, green: 0.22, blue: 0.18, alpha: 1)
                : UIColor(red: 0.93, green: 0.97, blue: 0.94, alpha: 1)
        }
    )
    static let accentGreen = Color(red: 0.25, green: 0.72, blue: 0.45)
    static let accentYellow = Color(red: 0.98, green: 0.82, blue: 0.22)
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let inputBackground = Color(
        uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.10, blue: 0.10, alpha: 1)
                : UIColor(red: 0.98, green: 0.99, blue: 0.98, alpha: 1)
        }
    )
    static let inputStroke = Color(
        uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.10)
                : UIColor.black.withAlphaComponent(0.08)
        }
    )
    static let inputStrokeFocused = accentGreen.opacity(0.9)
    static let inputLabel = Color(
        uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.secondaryLabel.withAlphaComponent(0.95)
                : UIColor.secondaryLabel
        }
    )
    static let inputLabelFocused = accentGreen
    static let cardStroke = Color(
        uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.08)
                : UIColor.black.withAlphaComponent(0.04)
        }
    )
    static let cardShadow = Color(
        uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.28)
                : UIColor.black.withAlphaComponent(0.06)
        }
    )
    static let floatingActionBackground = Color(
        uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.20, green: 0.76, blue: 0.49, alpha: 1)
                : UIColor.label
        }
    )

    static let primaryGradient = LinearGradient(
        colors: [accentGreen, Color(red: 0.15, green: 0.55, blue: 0.38)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
