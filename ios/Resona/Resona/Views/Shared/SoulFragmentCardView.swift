import SwiftUI

struct SoulFragmentCardView: View {
    let content: String
    let createdAt: Date?

    init(content: String, createdAt: Date? = nil) {
        self.content = content
        self.createdAt = createdAt
    }

    var body: some View {
        PremiumCardView(iconName: "sparkles", title: "Soul Fragment") {
            VStack(spacing: 16) {
                Text(content)
                    .font(.body)
                    .lineSpacing(8)
                    .foregroundStyle(.white)

                if let createdAt {
                    Divider()
                        .background(.white.opacity(0.2))

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
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(1.5)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
