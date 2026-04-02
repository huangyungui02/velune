import Foundation
import SwiftData

enum SidebarResonanceStore {
    @MainActor
    static func fetch(userId: String, context: ModelContext) throws -> [Resonance] {
        let records = try context.fetch(fetchDescriptor(userId: userId))
        return records.map { $0.asResonance() }
    }

    @MainActor
    static func merge(_ remoteResonances: [Resonance], userId: String, context: ModelContext) throws -> Bool {
        guard !remoteResonances.isEmpty else { return false }

        let localRecords = try context.fetch(fetchDescriptor(userId: userId))
        var localById = Dictionary(uniqueKeysWithValues: localRecords.map { ($0.id, $0) })
        var hasChanges = false

        for remote in remoteResonances {
            if let local = localById[remote.id] {
                if local.mergeIfNeeded(remote) {
                    hasChanges = true
                }
            } else {
                let record = SidebarResonanceCache(resonance: remote, userId: userId)
                context.insert(record)
                localById[record.id] = record
                hasChanges = true
            }
        }

        if hasChanges {
            try context.save()
        }

        return hasChanges
    }

    @MainActor
    static func clear(userId: String, context: ModelContext) throws {
        let records = try context.fetch(fetchDescriptor(userId: userId))
        guard !records.isEmpty else { return }
        for record in records {
            context.delete(record)
        }
        try context.save()
    }

    private static func fetchDescriptor(userId: String) -> FetchDescriptor<SidebarResonanceCache> {
        let targetUserId = userId
        return FetchDescriptor<SidebarResonanceCache>(
            predicate: #Predicate<SidebarResonanceCache> { $0.userId == targetUserId },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
    }
}
