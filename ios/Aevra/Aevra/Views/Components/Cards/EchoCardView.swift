import MarkdownUI
import SwiftUI

struct EchoChatRoute: Identifiable, Hashable {
    let soulerId: UUID
    let soulerName: String
    let draftEchoId: UUID
    let draftPrelude: ChatView.DraftPrelude
    var id: UUID { draftEchoId }

    init(echo: Echo, glimmerContent: String? = nil) {
        soulerId = echo.soulerId
        soulerName = echo.soulerName
        draftEchoId = echo.id
        draftPrelude = .init(
            glimmerContent: glimmerContent ?? echo.glimmer?.content ?? "",
            echoContent: echo.content
        )
    }
}

struct EchoCardView: View {
    let echo: Echo

    init(echo: Echo) {
        self.echo = echo
    }

    var body: some View {
        PremiumCardView(
            iconName: "circle.circle"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Markdown(echo.content)
                    .markdownTextStyle {
                        ForegroundColor(UITheme.primaryText)
                    }
                    .fontDesign(.serif)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(12)
                    .tracking(0.5)

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
