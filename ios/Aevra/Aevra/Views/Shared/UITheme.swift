import CoreText
import SwiftUI

enum UITheme {
    static let accent = Color.white
    static let primaryText = Color.white.opacity(0.95)
    static let secondaryText = Color.white.opacity(0.74)
    static let tertiaryText = Color.white.opacity(0.55)

    private static let literaryFontName = "LXGWWenKaiLite-Regular"

    /// Register bundled custom fonts at app launch
    static func registerFonts() {
        guard let url = Bundle.main.url(forResource: literaryFontName, withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    /// Literary Chinese font (LXGW WenKai Lite) for content text
    static func literary(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(literaryFontName, size: size).weight(weight)
    }
}
