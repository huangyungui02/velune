import MarkdownUI
import SwiftUI

struct EchoChatDestination: Identifiable, Hashable {
    let id = UUID()
    let echo: Echo
    let glimmerContent: String
    let initialReply: String?

    static func == (lhs: EchoChatDestination, rhs: EchoChatDestination) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    @ViewBuilder
    func makeChatView() -> some View {
        ChatView(
            soulerId: echo.soulerId,
            soulerName: echo.soulerName,
            initialSeedMessages: [
                .init(role: .user, content: glimmerContent),
                .init(role: .assistant, content: echo.content),
            ],
            initialDisplayMessages: [
                Message(
                    id: UUID(),
                    soulerId: echo.soulerId,
                    role: .user,
                    content: glimmerContent,
                    createdAt: .now.addingTimeInterval(-2)
                ),
                Message(
                    id: UUID(),
                    soulerId: echo.soulerId,
                    role: .assistant,
                    content: echo.content,
                    createdAt: .now.addingTimeInterval(-1)
                ),
            ],
            initialReply: initialReply
        )
    }
}

struct EchoCardView: View {
    let echo: Echo
    let glimmerContent: String
    let maxCardHeight: CGFloat?
    let onOpenChat: (EchoChatDestination) -> Void

    init(
        echo: Echo,
        glimmerContent: String,
        maxCardHeight: CGFloat? = nil,
        onOpenChat: @escaping (EchoChatDestination) -> Void = { _ in }
    ) {
        self.echo = echo
        self.glimmerContent = glimmerContent
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
                        FontFamily(.custom(UITheme.literaryFontName))
                        FontSize(18)
                        ForegroundColor(UITheme.primaryText)
                    }
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
                    .font(UITheme.literary(size: 18, weight: .medium))
                    .foregroundStyle(UITheme.accent)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
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
            .font(UITheme.literary(size: 16))
            .foregroundStyle(UITheme.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))

            Button {
                replyText = ""
                onOpenChat(
                    EchoChatDestination(
                        echo: echo,
                        glimmerContent: glimmerContent,
                        initialReply: trimmed
                    )
                )
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(canSend ? UITheme.primaryText : UITheme.tertiaryText)
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.10), in: .circle)
            }
            .disabled(!canSend)
        }
    }
}

#Preview {
    EchoCardView(echo: Echo.sampleData[0], glimmerContent: Glimmer.sampleData[0].content)
}
