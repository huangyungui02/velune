import MarkdownUI
import SwiftUI

struct EchoChatRoute: Identifiable, Hashable {
    let id = UUID()
    let sessionId: UUID
    let soulerId: UUID
    let soulerName: String
    let initialReply: String?

    init(sessionId: UUID, echo: Echo, initialReply: String?) {
        self.sessionId = sessionId
        soulerId = echo.soulerId
        soulerName = echo.soulerName
        self.initialReply = initialReply
    }

    static func == (lhs: EchoChatRoute, rhs: EchoChatRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

}

struct EchoCardView: View {
    let echo: Echo
    let maxCardHeight: CGFloat?
    let onOpenChat: (EchoChatRoute) -> Void

    init(
        echo: Echo,
        maxCardHeight: CGFloat? = nil,
        onOpenChat: @escaping (EchoChatRoute) -> Void = { _ in }
    ) {
        self.echo = echo
        self.maxCardHeight = maxCardHeight
        self.onOpenChat = onOpenChat
    }

    @State private var replyText = ""
    @FocusState private var isReplyFieldFocused: Bool

    var body: some View {
        PremiumCardView(
            iconName: "circle.circle",
            maxCardHeight: maxCardHeight,
            followBottomOnContentGrowth: isReplyFieldFocused
        ) {
            VStack(alignment: .leading, spacing: 16) {
                Markdown(echo.content)
                    .markdownTextStyle {
                        ForegroundColor(UITheme.primaryText)
                    }
                    .fontDesign(.serif)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(8)

                soulerSignature
                    .padding(.top, 16)

                Divider()
                    .background(.white.opacity(0.01))
                    .padding(.top, 2)
                    .padding(.bottom, 2)

                replyComposer
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

    private var replyComposer: some View {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let canSend = !trimmed.isEmpty

        return HStack(alignment: .bottom, spacing: 10) {
            TextField(
                "echo.reply.placeholder",
                text: $replyText,
                axis: .vertical
            )
            .lineLimit(1 ... 5)
            .focused($isReplyFieldFocused)
            .textFieldStyle(.plain)
            .font(.body)
            .fontDesign(.serif)
            .foregroundStyle(UITheme.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))

            Button {
                guard let sessionId = echo.sessionId else { return }
                replyText = ""
                onOpenChat(
                    EchoChatRoute(
                        sessionId: sessionId,
                        echo: echo,
                        initialReply: trimmed
                    )
                )
            } label: {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canSend ? UITheme.primaryText : UITheme.tertiaryText)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.10), in: .circle)
            }
            .disabled(!canSend || echo.sessionId == nil)
        }
    }
}

#Preview {
    EchoCardView(echo: Echo.sampleData[0])
}
