import Foundation

enum AppErrorUserInfoKey {
    static let billingCode = "billingCode"
}

struct BillingErrorContext: Equatable {
    let code: String

    var shouldOfferUpgrade: Bool {
        code == "INSUFFICIENT_CREDITS"
    }
}

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

extension Error {
    var billingErrorContext: BillingErrorContext? {
        let nsError = self as NSError
        guard let code = nsError.userInfo[AppErrorUserInfoKey.billingCode] as? String,
              !code.isEmpty
        else {
            return nil
        }

        return BillingErrorContext(code: code)
    }
}
