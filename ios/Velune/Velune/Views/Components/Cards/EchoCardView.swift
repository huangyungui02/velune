import MarkdownUI
import SwiftUI

struct EchoChatRoute: Identifiable, Hashable {
    let soulerId: UUID
    let soulerName: String
    let echoId: UUID
    let sessionId: UUID?
    let draftPrelude: ChatView.DraftPrelude?
    var id: UUID {
        sessionId ?? echoId
    }

    init(echo: Echo, stirringContent: String? = nil) {
        soulerId = echo.soulerId
        soulerName = echo.soulerName
        echoId = echo.id
        sessionId = echo.sessionId
        if sessionId == nil {
            draftPrelude = .init(
                stirringContent: stirringContent ?? echo.stirring?.content ?? "",
                echoContent: echo.content
            )
        } else {
            draftPrelude = nil
        }
    }
}

struct EchoCardView: View {
    let echo: Echo

    init(echo: Echo) {
        self.echo = echo
    }

    var body: some View {
        PremiumCardView {
            VStack(alignment: .leading, spacing: 24) {
                Markdown(echo.content)
                    .veluneMarkdownBodyStyle()
                    .tracking(0.5)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.08), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                soulerSignature
            }
        }
    }

    private var soulerSignature: some View {
        NavigationLink {
            SoulerView(soulerId: echo.soulerId)
        } label: {
            HStack(spacing: 4) {
                Spacer()
                Text(echo.soulerName)
                    .font(.body.weight(.medium))
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.primaryText.opacity(0.85))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
