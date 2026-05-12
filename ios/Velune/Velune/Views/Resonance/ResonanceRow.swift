import SwiftUI

struct ResonanceRow: View {
    let resonance: Resonance

    private var lastSessionTitle: String {
        resonance.lastSessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 14) {
            SoulerAvatar(
                name: resonance.soulerName,
                id: resonance.soulerId
            )

            Text(resonance.soulerName)
                .lineLimit(1)
                .font(.body.weight(.medium))
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText)

            Spacer(minLength: 18)

            Text(lastSessionTitle)
                .lineLimit(1)
                .font(.footnote)
                .fontDesign(.serif)
                .foregroundStyle(UITheme.secondaryText)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 150, alignment: .trailing)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 0.5)
                .padding(.leading, 58)
        }
    }
}

private struct SoulerAvatar: View {
    let name: String
    let id: UUID

    private var initial: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "?" : String(trimmedName.prefix(1))
    }

    private var hue: Double {
        let total = id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Double(total % 360) / 360
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.26, brightness: 0.78).opacity(0.34),
                            Color(hue: hue, saturation: 0.16, brightness: 0.98).opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(initial)
                .font(.callout.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText.opacity(0.9))

            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 0.7)
        }
        .frame(width: 44, height: 44)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}
