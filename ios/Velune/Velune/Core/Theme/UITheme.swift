import SwiftUI

enum UITheme {
    static let accent = Color.white
    static let primaryText = Color.white.opacity(0.95)
    static let secondaryText = Color.white.opacity(0.74)
    static let tertiaryText = Color.white.opacity(0.55)
    
    // 诗意与星海的专属配色体系
    static let glimmerGlow = Color(red: 0.88, green: 0.94, blue: 1.0) // 皎洁的星芒微光

    static func primaryActionBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .white : .black
    }

    static func primaryActionForeground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? .black : .white
    }
}
