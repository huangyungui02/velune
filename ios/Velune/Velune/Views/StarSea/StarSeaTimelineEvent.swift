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
