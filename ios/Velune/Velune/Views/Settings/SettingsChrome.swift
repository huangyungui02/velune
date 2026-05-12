import SwiftUI

struct SettingsListChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.white.opacity(0.05))
            .listRowSeparatorTint(.white.opacity(0.08))
    }
}

func settingsRowLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
    Label {
        Text(title)
            .foregroundStyle(UITheme.primaryText)
            .lineLimit(1)
    } icon: {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(UITheme.secondaryText)
            .frame(width: 20)
    }
}
