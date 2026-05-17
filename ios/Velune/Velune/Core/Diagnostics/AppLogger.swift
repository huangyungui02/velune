import Foundation
import OSLog

nonisolated enum AppLogger {
    private final class BundleLocator {}
    private static let subsystem = Bundle(for: BundleLocator.self).bundleIdentifier ?? "com.echoversa.velune"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let billing = Logger(subsystem: subsystem, category: "billing")
    static let matching = Logger(subsystem: subsystem, category: "matching")
    static let chat = Logger(subsystem: subsystem, category: "chat")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let glimmerHistory = Logger(subsystem: subsystem, category: "glimmer-history")
}
