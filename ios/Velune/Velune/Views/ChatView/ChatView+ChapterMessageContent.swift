import Foundation

extension ChatView {
    var inlineConversationOptions: [String] {
        guard let lastMessage = messages.last, lastMessage.role == .assistant else {
            return []
        }

        return ConversationOptionParser.parse(lastMessage.content).options
    }

    func visibleContent(for message: Message) -> String {
        guard message.role == .assistant else {
            return message.content
        }

        return conversationMessageBody(from: message.content)
    }

    func conversationMessageBody(from content: String) -> String {
        ConversationOptionParser.parse(content).body
    }

    func conversationMessageStorageContent(body: String, options: [String]) -> String {
        ConversationOptionParser.storageContent(body: body, options: options)
    }
}
