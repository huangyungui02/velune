import MarkdownUI
import SwiftUI

struct EchoCardView: View {
    let echo: Echo

    var body: some View {
        PremiumCardView(iconName: "circle.circle") {
            VStack(alignment: .leading, spacing: 16) {
                Markdown(echo.content)
                    .font(.system(size: 18, weight: .regular, design: .serif))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(8)
                    .foregroundStyle(UITheme.primaryText)

                Divider()
                    .background(.white.opacity(0.01))
                    .padding(.top)

                NavigationLink {
                    SoulerView(soulerId: echo.soulerId)
                } label: {
                    HStack(spacing: 8) {
                        Spacer()

                        Text(echo.soulerName)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(UITheme.primaryText)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(UITheme.secondaryText)
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
