import MarkdownUI
import SwiftUI

struct EchoCardView: View {
    let echo: Echo

    var body: some View {
        PremiumCardView(iconName: "circle.circle") {
            VStack(alignment: .leading, spacing: 16) {
                Markdown(echo.content)
                    .markdownTextStyle {
                        FontFamily(.custom(UITheme.literaryFontName))
                        FontSize(19)
                        ForegroundColor(UITheme.primaryText)
                    }
                    .multilineTextAlignment(.leading)
                    .lineSpacing(8)

                Divider()
                    .background(.white.opacity(0.01))
                    .padding(.top)

                NavigationLink {
                    SoulerView(soulerId: echo.soulerId)
                } label: {
                    HStack(spacing: 8) {
                        Spacer()

                        Text(echo.soulerName)
                            .font(UITheme.literary(size: 19, weight: .medium))
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
