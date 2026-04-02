import Foundation

enum SyncStateStore {
    struct ResonancesSyncState: Equatable {
        var lastSyncedAt: Date?
        var hasMore: Bool

        static let `default` = ResonancesSyncState(lastSyncedAt: nil, hasMore: true)
    }

    struct GlimmersSyncState: Equatable {
        var hasMore: Bool

        static let `default` = GlimmersSyncState(hasMore: true)
    }

    struct SyncState: Equatable {
        var resonances: ResonancesSyncState
        var glimmers: GlimmersSyncState

        static let `default` = SyncState(
            resonances: .default,
            glimmers: .default
        )
    }

    private static let lastResonancesSyncedAtPrefix = "sync.resonances.lastSyncedAt"
    private static let hasMoreResonancesPrefix = "sync.resonances.hasMore"
    private static let hasMoreGlimmersPrefix = "sync.glimmers.hasMore"

    static func state(userId: String?) -> SyncState {
        guard let userId, !userId.isEmpty else { return .default }
        return SyncState(
            resonances: ResonancesSyncState(
                lastSyncedAt: lastResonancesSyncedAt(userId: userId),
                hasMore: hasMoreResonances(userId: userId)
            ),
            glimmers: GlimmersSyncState(
                hasMore: hasMoreGlimmers(userId: userId)
            )
        )
    }

    static func set(_ state: SyncState, userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        setLastResonancesSyncedAt(state.resonances.lastSyncedAt, userId: userId)
        setHasMoreResonances(state.resonances.hasMore, userId: userId)
        setHasMoreGlimmers(state.glimmers.hasMore, userId: userId)
    }

    static func clear(userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        guard let lastResonancesSyncedAtKey = lastResonancesSyncedAtKey(userId: userId),
              let hasMoreResonancesKey = hasMoreResonancesKey(userId: userId),
              let hasMoreGlimmersKey = hasMoreGlimmersKey(userId: userId)
        else {
            return
        }

        UserDefaults.standard.removeObject(forKey: lastResonancesSyncedAtKey)
        UserDefaults.standard.removeObject(forKey: hasMoreResonancesKey)
        UserDefaults.standard.removeObject(forKey: hasMoreGlimmersKey)
    }

    private static func lastResonancesSyncedAt(userId: String) -> Date? {
        guard let key = lastResonancesSyncedAtKey(userId: userId) else { return nil }
        let interval = UserDefaults.standard.object(forKey: key) as? TimeInterval
        guard let interval else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    private static func setLastResonancesSyncedAt(_ date: Date?, userId: String) {
        guard let key = lastResonancesSyncedAtKey(userId: userId) else { return }
        guard let date else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
    }

    private static func hasMoreResonances(userId: String) -> Bool {
        guard let key = hasMoreResonancesKey(userId: userId) else { return true }
        if UserDefaults.standard.object(forKey: key) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private static func setHasMoreResonances(_ hasMoreResonances: Bool, userId: String) {
        guard let key = hasMoreResonancesKey(userId: userId) else { return }
        UserDefaults.standard.set(hasMoreResonances, forKey: key)
    }

    private static func hasMoreGlimmers(userId: String) -> Bool {
        guard let key = hasMoreGlimmersKey(userId: userId) else { return true }
        if UserDefaults.standard.object(forKey: key) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private static func setHasMoreGlimmers(_ hasMoreGlimmers: Bool, userId: String) {
        guard let key = hasMoreGlimmersKey(userId: userId) else { return }
        UserDefaults.standard.set(hasMoreGlimmers, forKey: key)
    }

    private static func lastResonancesSyncedAtKey(userId: String) -> String? {
        key(prefix: lastResonancesSyncedAtPrefix, userId: userId)
    }

    private static func hasMoreResonancesKey(userId: String) -> String? {
        key(prefix: hasMoreResonancesPrefix, userId: userId)
    }

    private static func hasMoreGlimmersKey(userId: String) -> String? {
        key(prefix: hasMoreGlimmersPrefix, userId: userId)
    }

    private static func key(prefix: String, userId: String) -> String? {
        guard !userId.isEmpty else { return nil }
        return "\(prefix).\(userId)"
    }
}
