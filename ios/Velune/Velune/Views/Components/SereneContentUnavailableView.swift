import SwiftUI

struct SereneContentUnavailableView: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: LocalizedStringKey
    let symbol: String
    let subtitle: LocalizedStringKey?
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    init(
        title: LocalizedStringKey,
        symbol: String,
        subtitle: LocalizedStringKey? = nil,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.symbol = symbol
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                    }

                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(UITheme.primaryText)
            }

            Text(title)
                .font(.title3.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(UITheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    Label {
                        Text(actionTitle)
                            .fontDesign(.serif)
                    } icon: {
                        Image(systemName: "pencil")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(UITheme.primaryActionForeground(for: colorScheme))
                    .labelStyle(.titleAndIcon)
                    .imageScale(.small)
                    .padding(.horizontal, 18)
                    .frame(height: 46)
                }
                .buttonStyle(.plain)
                .fixedSize()
                .background(UITheme.accent, in: .capsule)
                .overlay {
                    Capsule()
                        .strokeBorder(.black.opacity(0.08), lineWidth: 0.6)
                }
                .shadow(color: .black.opacity(0.16), radius: 10, y: 5)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: 360)
        .background(Color.clear, in: .rect(cornerRadius: 24))
        .glassEffect(in: .rect(cornerRadius: 24))
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
