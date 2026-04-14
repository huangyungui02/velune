import SwiftUI

struct StirringCardView: View {
    @Environment(\.locale) private var locale
    let content: String
    let createdAt: Date?

    init(content: String, createdAt: Date? = nil) {
        self.content = content
        self.createdAt = createdAt
    }

    var body: some View {
        PremiumCardView {
            VStack(spacing: 24) {
                Text(content)
                    .font(.body)
                    .fontDesign(.serif)
                    .lineSpacing(8)
                    .tracking(0.5)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(UITheme.primaryText)

                if let createdAt {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.08), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)

                    HStack {
                        Spacer()

                        Text(
                            createdAt.formatted(
                                .dateTime
                                    .year()
                                    .month()
                                    .day()
                                    .hour()
                                    .minute()
                                    .locale(locale)
                            )
                        )
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(UITheme.tertiaryText)
                    }
                }
            }
        }
    }
}
