import SwiftUI

struct GlimmerCardView: View {
    @Environment(\.locale) private var locale
    let content: String
    let createdAt: Date?

    init(content: String, createdAt: Date? = nil) {
        self.content = content
        self.createdAt = createdAt
    }

    var body: some View {
        PremiumCardView {
            VStack(spacing: 16) {
                Text(content)
                    .font(.body)
                    .fontDesign(.serif)
                    .lineSpacing(12)
                    .tracking(0.5)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(UITheme.secondaryText)

                if let createdAt {
                    Divider()
                        .background(.white.opacity(0.01))
                        .padding(.top)

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
