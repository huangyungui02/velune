import MarkdownUI
import SwiftUI

enum ConversationMessageRole {
    case user
    case assistant
}

struct ConversationMessageRow: View {
    let role: ConversationMessageRole
    let content: String

    private var isUser: Bool {
        role == .user
    }

    var body: some View {
        HStack(alignment: .top) {
            if isUser {
                Spacer(minLength: 32)
            }

            messageContent
                .frame(maxWidth: isUser ? 320 : .infinity, alignment: isUser ? .trailing : .leading)

            if isUser == false {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder
    private var messageContent: some View {
        if !isUser && content.isEmpty {
            MatchingWaveIcon(
                ringSize: 10,
                containerSize: 22,
                color: UITheme.primaryText.opacity(0.6)
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        } else if isUser {
            Markdown(content)
                .veluneMarkdownBodyStyle()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.white.opacity(0.12), in: .rect(cornerRadius: 16))
        } else {
            Markdown(content)
                .veluneMarkdownBodyStyle()
                .padding(.horizontal, 2)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
