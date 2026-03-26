import Foundation

enum PaginationStateStore {
    private static let glimmerBottomPrefix = "pagination.glimmer.hasReachedBottom"

    static func hasReachedGlimmerBottom(userId: String?) -> Bool {
        guard let key = glimmerBottomKey(userId: userId) else { return false }
        return UserDefaults.standard.bool(forKey: key)
    }

    static func setHasReachedGlimmerBottom(_ reached: Bool, userId: String?) {
        guard let key = glimmerBottomKey(userId: userId) else { return }
        UserDefaults.standard.set(reached, forKey: key)
    }

    static func markGlimmerBottomReached(userId: String?) {
        guard let key = glimmerBottomKey(userId: userId) else { return }
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
    }

    static func clearGlimmerBottom(userId: String?) {
        guard let key = glimmerBottomKey(userId: userId) else { return }
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func glimmerBottomKey(userId: String?) -> String? {
        guard let userId, !userId.isEmpty else { return nil }
        return "\(glimmerBottomPrefix).\(userId)"
    }
}
