import SwiftUI

struct StarSeaResonanceMatchesView: View {
    let matches: [StarSeaStreamService.ResonanceMatch]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("starsea.resonance.title")
                .font(.system(size: 11, weight: .light))
                .tracking(2.0)
                .foregroundStyle(UITheme.tertiaryText.opacity(0.6))
                .padding(.leading, 6)

            ForEach(matches) { match in
                StarSeaResonanceMatchRow(match: match)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StarSeaResonanceMatchRow: View {
    let match: StarSeaStreamService.ResonanceMatch

    var body: some View {
        HStack(spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 6) {
                Text(match.name)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(UITheme.primaryText.opacity(0.9))
                    .lineLimit(1)

                Text(match.line)
                    .font(.system(size: 12, weight: .light))
                    .tracking(0.8)
                    .foregroundStyle(UITheme.secondaryText.opacity(0.62))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(UITheme.primaryText.opacity(0.24))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.07, green: 0.075, blue: 0.095).opacity(0.30), in: .rect(cornerRadius: 18))
        .glassEffect(in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 48, height: 48)

            Text(String(match.name.prefix(1)))
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(UITheme.primaryText.opacity(0.86))
        }
        .overlay {
            Circle()
                .stroke(.white.opacity(0.09), lineWidth: 0.5)
        }
    }
}
