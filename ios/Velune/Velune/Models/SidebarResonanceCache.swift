import Foundation
import SwiftData

@Model
class SidebarResonanceCache {
    @Attribute(.unique) var id: UUID
    var userId: String
    var soulerId: UUID
    var soulerName: String
    var lastSessionId: UUID?
    var lastSessionTitle: String
    var count: Int
    var createdAt: Date
    var updatedAt: Date

    init(resonance: Resonance, userId: String) {
        self.id = resonance.id
        self.userId = userId
        self.soulerId = resonance.soulerId
        self.soulerName = resonance.soulerName
        self.lastSessionId = resonance.lastSessionId
        self.lastSessionTitle = resonance.lastSessionTitle
        self.count = resonance.count
        self.createdAt = resonance.createdAt
        self.updatedAt = resonance.updatedAt
    }

    func mergeIfNeeded(_ resonance: Resonance) -> Bool {
        guard resonance.updatedAt >= updatedAt else { return false }

        let hasChanged = soulerId != resonance.soulerId
            || soulerName != resonance.soulerName
            || lastSessionId != resonance.lastSessionId
            || lastSessionTitle != resonance.lastSessionTitle
            || count != resonance.count
            || createdAt != resonance.createdAt
            || updatedAt != resonance.updatedAt

        guard hasChanged else { return false }

        soulerId = resonance.soulerId
        soulerName = resonance.soulerName
        lastSessionId = resonance.lastSessionId
        lastSessionTitle = resonance.lastSessionTitle
        count = resonance.count
        createdAt = resonance.createdAt
        updatedAt = resonance.updatedAt
        return true
    }

    func asResonance() -> Resonance {
        Resonance(
            id: id,
            soulerId: soulerId,
            soulerName: soulerName,
            lastSessionId: lastSessionId,
            lastSessionTitle: lastSessionTitle,
            count: count,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
