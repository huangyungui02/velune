import SwiftUI

enum UITheme {
    static let accent = Color.white
    static let primaryText = Color.white.opacity(0.95)
    static let secondaryText = Color.white.opacity(0.74)
    static let tertiaryText = Color.white.opacity(0.55)

    static let displayFont = Font.system(size: 44, weight: .semibold, design: .serif)
    static let titleFont = Font.system(size: 30, weight: .semibold, design: .serif)
    static let sectionFont = Font.system(size: 21, weight: .medium, design: .rounded)
    static let bodyFont = Font.system(size: 18, weight: .regular, design: .serif)
    static let labelFont = Font.system(size: 13, weight: .medium, design: .rounded)
}
