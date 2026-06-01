import Foundation

enum SyncStateStore {
    struct GlimmersSyncState: Equatable {
        var hasMore: Bool

        static let `default` = GlimmersSyncState(hasMore: true)
    }

    struct SyncState: Equatable {
        var glimmers: GlimmersSyncState

        static let `default` = SyncState(
            glimmers: .default
        )
    }

    private static let hasMoreGlimmersPrefix = "sync.glimmers.hasMore"

    static func state(userId: String?) -> SyncState {
        guard let userId, !userId.isEmpty else { return .default }
        return SyncState(
            glimmers: GlimmersSyncState(
                hasMore: hasMoreGlimmers(userId: userId)
            )
        )
    }

    static func set(_ state: SyncState, userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        setHasMoreGlimmers(state.glimmers.hasMore, userId: userId)
    }

    static func clear(userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        guard let hasMoreGlimmersKey = hasMoreGlimmersKey(userId: userId)
        else {
            return
        }

        UserDefaults.standard.removeObject(forKey: hasMoreGlimmersKey)
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

    private static func hasMoreGlimmersKey(userId: String) -> String? {
        key(prefix: hasMoreGlimmersPrefix, userId: userId)
    }

    private static func key(prefix: String, userId: String) -> String? {
        guard !userId.isEmpty else { return nil }
        return "\(prefix).\(userId)"
    }
}
