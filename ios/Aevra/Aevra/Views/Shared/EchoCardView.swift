import MarkdownUI
import SwiftUI

struct EchoCardView: View {
    let echo: Echo
    let glimmerContent: String

    @State private var replyText = ""
    @State private var navigateToChat = false
    @State private var chatInitialReply: String?

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

                replyComposer

                NavigationLink(
                    isActive: $navigateToChat,
                    destination: {
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
                            initialReply: chatInitialReply
                        )
                    },
                    label: {
                        SwiftUI.EmptyView()
                    }
                )
                .hidden()

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

    private var replyComposer: some View {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let canSend = !trimmed.isEmpty

        return HStack(alignment: .bottom, spacing: 10) {
            TextField(
                String(localized: "echo.reply.placeholder"),
                text: $replyText,
                axis: .vertical
            )
            .lineLimit(1 ... 3)
            .textFieldStyle(.plain)
            .font(UITheme.literary(size: 16))
            .foregroundStyle(UITheme.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))

            Button {
                chatInitialReply = trimmed
                replyText = ""
                navigateToChat = true
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
