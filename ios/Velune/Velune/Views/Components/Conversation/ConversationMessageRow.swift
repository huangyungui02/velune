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
                Spacer(minLength: 48)
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
                containerSize: 24,
                color: UITheme.primaryText.opacity(0.62)
            )
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        } else if isUser {
            Markdown(content)
                .veluneMarkdownBodyStyle()
                .font(.system(size: 14, weight: .regular))
                .tracking(0.3)
                .foregroundStyle(UITheme.primaryText.opacity(0.88))
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color(white: 0.12).opacity(0.52), in: .rect(cornerRadius: 17))
                .shadow(color: .black.opacity(0.36), radius: 18, y: 8)
        } else {
            Markdown(content)
                .veluneMarkdownBodyStyle()
                .font(.system(size: 15, weight: .regular))
                .tracking(0.4)
                .lineSpacing(7)
                .foregroundStyle(UITheme.primaryText.opacity(0.80))
                .padding(.horizontal, 8)
                .padding(.vertical, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
        }
    }
}
