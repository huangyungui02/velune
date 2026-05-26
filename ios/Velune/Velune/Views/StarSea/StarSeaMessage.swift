import Foundation

struct StarSeaMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var content: String

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}
