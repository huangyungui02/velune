import SwiftUI

struct GlimmerCardView: View {
    let content: String
    let createdAt: Date?

    init(content: String, createdAt: Date? = nil) {
        self.content = content
        self.createdAt = createdAt
    }

    var body: some View {
        PremiumCardView(iconName: "sparkles") {
            VStack(spacing: 16) {
                Text(content)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .lineSpacing(8)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(UITheme.primaryText)

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
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(UITheme.tertiaryText)
                    }
                }
            }
        }
    }
}

#Preview {
    let glimmer = Glimmer.sampleData[0]
    GlimmerCardView(content: glimmer.content, createdAt: glimmer.createdAt)
}
