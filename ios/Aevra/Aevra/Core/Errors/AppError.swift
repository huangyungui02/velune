import Foundation

enum AppError: LocalizedError {
    case unauthenticated

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return String(localized: "app.error.unauthenticated")
        }
    }
}
