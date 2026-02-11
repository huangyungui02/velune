import MarkdownUI
import SwiftUI

struct EchoCardView: View {
    let echo: Echo

    var body: some View {
        PremiumCardView(iconName: "circle.circle") {
            VStack(alignment: .leading, spacing: 16) {
                Markdown(echo.content)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(8)
                    .foregroundStyle(.white)

                Divider()
                    .background(.white.opacity(0.01))
                    .padding(.top)

                NavigationLink {
                    SoulerView(soulerId: echo.soulerId)
                } label: {
                    HStack(spacing: 8) {
                        Spacer()

                        Text(echo.soulerName)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    EchoCardView(echo: Echo.sampleData[0])
}
