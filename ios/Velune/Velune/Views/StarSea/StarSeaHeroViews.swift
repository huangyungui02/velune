import SwiftUI

struct HeroVerse: View {
    var body: some View {
        Text("starsea.hero.verse")
            .font(.title3)
            .fontDesign(.serif)
            .tracking(2.0)
            .multilineTextAlignment(.center)
            .foregroundStyle(UITheme.primaryText.opacity(0.65))
            .lineSpacing(12)
            .accessibilityAddTraits(.isStaticText)
    }
}

struct FloatingWriteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil")
                .font(.title3.weight(.medium))
                .foregroundStyle(.black)
                .frame(width: 56, height: 56)
                .contentShape(Circle())
                .background(UITheme.accent, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.28), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("starsea.prompt.glimmerWithin"))
    }
}
