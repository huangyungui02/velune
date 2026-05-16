import SwiftUI

struct SoulerBookCoverView: View {
    let name: String
    let imageURL: URL?

    private var initial: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "?" : String(trimmedName.prefix(1))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.06))

            if imageURL != nil {
                CachedRemoteImage(url: imageURL, contentMode: .fill) {
                    fallbackCover
                }
            } else {
                fallbackCover
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .center,
                endPoint: .bottom
            )

            Text(name)
                .font(.footnote.weight(.medium))
                .fontDesign(.serif)
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(12)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        }
        .contentShape(.rect(cornerRadius: 10, style: .continuous))
        .accessibilityLabel(name)
    }

    private var fallbackCover: some View {
        ZStack {
            LinearGradient(
                colors: [.white.opacity(0.14), .white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(initial)
                .font(.title2.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText.opacity(0.84))
        }
    }
}
