import Foundation

enum AppError: LocalizedError {
    case unauthenticated
    case missingConfiguration(String)
    case invalidConfiguration(String)
    case persistenceUnavailable

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return String(localized: "app.error.unauthenticated")
        case let .missingConfiguration(key):
            return "Missing required app configuration: \(key)"
        case let .invalidConfiguration(key):
            return "Invalid app configuration: \(key)"
        case .persistenceUnavailable:
            return "The app could not open local storage."
        }
    }
}

struct AppLaunchFailure: Equatable {
    let title: String
    let message: String

    init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    init(error: Error) {
        self.title = "Velune could not open"
        self.message = error.localizedDescription
    }
}
