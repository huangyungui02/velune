import Foundation

struct SidebarSyncState: Equatable {
    var lastSyncedAt: Date?
    var hasMore: Bool
}

enum SidebarSyncStateStore {
    private static let lastSyncedAtPrefix = "sidebar.sync.lastSyncedAt"
    private static let hasMorePrefix = "sidebar.sync.hasMore"

    static func state(userId: String) -> SidebarSyncState {
        SidebarSyncState(
            lastSyncedAt: lastSyncedAt(userId: userId),
            hasMore: hasMore(userId: userId)
        )
    }

    static func set(_ state: SidebarSyncState, userId: String) {
        setLastSyncedAt(state.lastSyncedAt, userId: userId)
        setHasMore(state.hasMore, userId: userId)
    }

    static func lastSyncedAt(userId: String) -> Date? {
        guard let key = key(prefix: lastSyncedAtPrefix, userId: userId) else { return nil }
        let interval = UserDefaults.standard.object(forKey: key) as? TimeInterval
        guard let interval else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    static func setLastSyncedAt(_ date: Date?, userId: String) {
        guard let key = key(prefix: lastSyncedAtPrefix, userId: userId) else { return }
        guard let date else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
    }

    static func hasMore(userId: String) -> Bool {
        guard let key = key(prefix: hasMorePrefix, userId: userId) else { return true }
        if UserDefaults.standard.object(forKey: key) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func setHasMore(_ hasMore: Bool, userId: String) {
        guard let key = key(prefix: hasMorePrefix, userId: userId) else { return }
        UserDefaults.standard.set(hasMore, forKey: key)
    }

    static func clear(userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        guard let lastSyncedKey = key(prefix: lastSyncedAtPrefix, userId: userId),
              let hasMoreKey = key(prefix: hasMorePrefix, userId: userId)
        else {
            return
        }
        UserDefaults.standard.removeObject(forKey: lastSyncedKey)
        UserDefaults.standard.removeObject(forKey: hasMoreKey)
    }

    private static func key(prefix: String, userId: String) -> String? {
        guard !userId.isEmpty else { return nil }
        return "\(prefix).\(userId)"
    }
}
