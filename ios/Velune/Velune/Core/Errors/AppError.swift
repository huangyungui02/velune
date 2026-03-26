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

    var errorDescription: String? {
        switch self {
        case .unauthenticated:
            return String(localized: "app.error.unauthenticated")
        }
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
