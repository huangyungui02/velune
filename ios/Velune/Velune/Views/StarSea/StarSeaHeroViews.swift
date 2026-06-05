import SwiftUI

struct HeroVerse: View {
    let text: String

    var body: some View {
        Group {
            if text.isEmpty {
                Text("starsea.hero.verse")
            } else {
                Text(text)
            }
        }
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
                .foregroundStyle(UITheme.primaryText)
                .frame(width: 56, height: 56)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: .circle)
                .shadow(color: .black.opacity(0.16), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("starsea.prompt.glimmerWithin"))
    }
}
