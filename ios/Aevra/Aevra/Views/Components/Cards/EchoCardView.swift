import MarkdownUI
import SwiftUI

struct EchoChatRoute: Identifiable, Hashable {
    let sessionId: UUID
    let soulerId: UUID
    let soulerName: String
    var id: UUID { sessionId }

    init(sessionId: UUID, echo: Echo) {
        self.sessionId = sessionId
        soulerId = echo.soulerId
        soulerName = echo.soulerName
    }
}

struct EchoCardView: View {
    let echo: Echo
    let maxCardHeight: CGFloat?

    init(
        echo: Echo,
        maxCardHeight: CGFloat? = nil
    ) {
        self.echo = echo
        self.maxCardHeight = maxCardHeight
    }

    var body: some View {
        PremiumCardView(
            iconName: "circle.circle",
            maxCardHeight: maxCardHeight
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Markdown(echo.content)
                    .markdownTextStyle {
                        ForegroundColor(UITheme.primaryText)
                    }
                    .fontDesign(.serif)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(8)

                Divider()
                    .background(.white.opacity(0.01))
                    .padding(.top, 2)
                    .padding(.bottom, 2)

                soulerSignature
            }
        }
    }

    private var soulerSignature: some View {
        NavigationLink {
            SoulerView(soulerId: echo.soulerId)
        } label: {
            HStack(spacing: 8) {
                Spacer()
                Text(echo.soulerName)
                    .font(.body.weight(.medium))
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.accent)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(UITheme.secondaryText)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EchoCardView(echo: Echo.sampleData[0])
}
