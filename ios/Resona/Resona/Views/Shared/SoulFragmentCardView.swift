import MarkdownUI
import SwiftUI

struct SoulFragmentCardView: View {
    let content: String
    let createdAt: Date?

    init(content: String, createdAt: Date? = nil) {
        self.content = content
        self.createdAt = createdAt
    }

    var body: some View {
        PremiumCardView(iconName: "sparkles") {
            VStack(spacing: 16) {
                Markdown(content)
                    .font(.body)
                    .lineSpacing(8)
                    .foregroundStyle(.white)

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

#Preview {
    let inspiration = Inspiration.sampleData[0]
    SoulFragmentCardView(content: inspiration.content, createdAt: inspiration.createdAt)
}
