import Foundation

extension ChatView {
    var inlineChapterOptions: [String] {
        guard let lastMessage = messages.last, lastMessage.role == .assistant else {
            return []
        }

        return ConversationOptionParser.parse(lastMessage.content).options
    }

    func visibleContent(for message: Message) -> String {
        guard message.role == .assistant else {
            return message.content
        }

        return chapterMessageBody(from: message.content)
    }

    func chapterMessageBody(from content: String) -> String {
        ConversationOptionParser.parse(content).body
    }

    func chapterMessageStorageContent(body: String, options: [String]) -> String {
        ConversationOptionParser.storageContent(body: body, options: options)
    }
}
