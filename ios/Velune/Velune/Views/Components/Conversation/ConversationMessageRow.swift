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
            ZStack(alignment: .bottomTrailing) {
                Markdown(content)
                    .veluneMarkdownBodyStyle()
                    .font(.system(size: 14, weight: .regular))
                    .tracking(0.3)
                    .foregroundStyle(UITheme.primaryText.opacity(0.88))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.07, green: 0.075, blue: 0.095).opacity(0.50), in: .rect(cornerRadius: 17))
                    .glassEffect(in: .rect(cornerRadius: 17))
                    .overlay {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.36), radius: 18, y: 8)

                ConversationBubbleTail()
                    .fill(Color(red: 0.07, green: 0.075, blue: 0.095).opacity(0.52))
                    .frame(width: 10, height: 14)
                    .offset(x: 5)
            }
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

private struct ConversationBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control1: CGPoint(x: rect.midX, y: rect.midY * 0.45),
            control2: CGPoint(x: rect.maxX * 0.82, y: rect.maxY * 0.72)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
