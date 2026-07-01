import Foundation

struct StarSeaMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var displayType: StarSeaStreamService.DeltaDisplayType
    var thinkingDurationSeconds: Int?
    var content: String

    init(
        id: UUID = UUID(),
        role: Role,
        displayType: StarSeaStreamService.DeltaDisplayType = .starsea,
        thinkingDurationSeconds: Int? = nil,
        content: String
    ) {
        self.id = id
        self.role = role
        self.displayType = displayType
        self.thinkingDurationSeconds = thinkingDurationSeconds
        self.content = content
    }
}
