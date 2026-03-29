import SwiftUI

struct SereneContentUnavailableView: View {
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
        ContentUnavailableView {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(UITheme.secondaryText)
                    .padding(10)
                    .background(.white.opacity(0.04), in: Circle())

                Text(title)
                    .font(.title3.weight(.semibold))
                    .fontDesign(.serif)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(UITheme.primaryText)
            }
        } description: {
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top)
            }
        } actions: {
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.footnote.weight(.semibold))
                        .fontDesign(.serif)
                        .foregroundStyle(UITheme.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Color.clear, in: .capsule)
                .glassEffect(in: .capsule)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
