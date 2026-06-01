import Foundation

enum StarSeaTimelineEvent: Identifiable, Hashable {
    case message(StarSeaMessage)
    case resonanceMatches(id: UUID, matches: [StarSeaStreamService.ResonanceMatch])

    var id: UUID {
        switch self {
        case let .message(message):
            message.id
        case let .resonanceMatches(id, _):
            id
        }
    }

    var message: StarSeaMessage? {
        guard case let .message(message) = self else { return nil }
        return message
    }
}

extension [StarSeaTimelineEvent] {
    func firstMessageIndex(id: UUID) -> Index? {
        firstIndex { event in
            guard case let .message(message) = event else { return false }
            return message.id == id
        }
    }

    var lastAssistantMessageId: UUID? {
        reversed().compactMap(\.message).first { $0.role == .assistant }?.id
    }
}

extension StarSeaTimelineEvent {
    mutating func appendMessageContent(_ content: String) {
        guard case var .message(message) = self else { return }
        message.content += content
        self = .message(message)
    }

    mutating func replaceMessageContent(_ content: String) {
        guard case var .message(message) = self else { return }
        message.content = content
        self = .message(message)
    }
}
