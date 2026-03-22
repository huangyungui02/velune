import SwiftUI

enum UITheme {
    static let accent = Color.white
    static let primaryText = Color.white.opacity(0.95)
    static let secondaryText = Color.white.opacity(0.74)
    static let tertiaryText = Color.white.opacity(0.55)

    static func primaryActionBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    static func primaryActionForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }
}
