import Foundation

enum AppErrorUserInfoKey {
    static let billingCode = "billingCode"
    static let billingPlan = "billingPlan"
}

struct BillingErrorContext: Equatable {
    let code: String
    let plan: String?

    var shouldOfferUpgrade: Bool {
        code == "INSUFFICIENT_CREDITS" && plan == "free"
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

        let plan = nsError.userInfo[AppErrorUserInfoKey.billingPlan] as? String
        return BillingErrorContext(code: code, plan: plan)
    }
}
