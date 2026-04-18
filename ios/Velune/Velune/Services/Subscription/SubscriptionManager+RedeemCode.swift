import Foundation
import Supabase

extension SubscriptionManager {
    func redeemCode(_ code: String) async throws -> RedeemCodeSuccess {
        guard !AuthManager.shared.isAnonymous else {
            throw AppError.unauthenticated
        }

        let normalizedCode = normalizedRedeemCode(from: code)
        guard !normalizedCode.isEmpty else {
            throw redeemCodeNSError(
                code: -1,
                message: String(localized: "settings.billing.redeem.error.empty")
            )
        }

        let rows: [RedeemCodeResponse] = try await fetchRedeemCodeResponse(code: normalizedCode)
        guard let response = rows.first else {
            throw redeemCodeNSError(
                code: -2,
                message: String(localized: "matching.error.unknown")
            )
        }

        guard response.ok else {
            throw redeemCodeError(code: response.code, fallbackMessage: response.message)
        }

        guard let rewardCredits = response.rewardCredits,
              rewardCredits > 0,
              let latestCredits = response.credits,
              latestCredits >= 0
        else {
            throw redeemCodeNSError(
                code: -3,
                message: String(localized: "matching.error.unknown")
            )
        }

        credits = latestCredits
        return RedeemCodeSuccess(rewardCredits: rewardCredits, credits: latestCredits)
    }

    private func fetchRedeemCodeResponse(code: String) async throws -> [RedeemCodeResponse] {
        let params: [String: AnyJSON] = ["p_code": .string(code)]
        let supabase = try Backend.requireSupabase()
        return try await supabase
            .rpc("redeem_code_for_current_user", params: params)
            .execute()
            .value
    }

    private func normalizedRedeemCode(from raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
    }

    private func redeemCodeNSError(code: Int, message: String, billingCode: String? = nil) -> NSError {
        var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]
        if let billingCode {
            userInfo[AppErrorUserInfoKey.billingCode] = billingCode
        }

        return NSError(domain: "RedeemCode", code: code, userInfo: userInfo)
    }

    private func redeemCodeError(
        code: String?,
        fallbackMessage: String?
    ) -> NSError {
        let normalizedCode = code?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? "UNKNOWN"

        let localizedMessage: String
        switch normalizedCode {
        case "UNAUTHORIZED":
            localizedMessage = String(localized: "settings.billing.redeem.error.unauthorized")
        case "CODE_NOT_FOUND":
            localizedMessage = String(localized: "settings.billing.redeem.error.notFound")
        case "CODE_INACTIVE":
            localizedMessage = String(localized: "settings.billing.redeem.error.inactive")
        case "CODE_NOT_STARTED":
            localizedMessage = String(localized: "settings.billing.redeem.error.notStarted")
        case "CODE_EXPIRED":
            localizedMessage = String(localized: "settings.billing.redeem.error.expired")
        case "CODE_LIMIT_REACHED":
            localizedMessage = String(localized: "settings.billing.redeem.error.limitReached")
        case "ALREADY_REDEEMED":
            localizedMessage = String(localized: "settings.billing.redeem.error.alreadyRedeemed")
        default:
            let fallback = fallbackMessage?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            localizedMessage = (fallback?.isEmpty == false)
                ? fallback!
                : String(localized: "matching.error.unknown")
        }

        return redeemCodeNSError(
            code: -4,
            message: localizedMessage,
            billingCode: normalizedCode
        )
    }
}
