import Foundation

enum AIReplyLength: String, CaseIterable, Identifiable {
    case standard
    case concise

    static let storageKey = "velune:ai-reply-length"

    var id: String { rawValue }

    var localizedTitleKey: String {
        switch self {
        case .standard:
            return "settings.aiReplyLength.standard"
        case .concise:
            return "settings.aiReplyLength.concise"
        }
    }

    static func normalized(_ rawValue: String) -> AIReplyLength {
        rawValue == AIReplyLength.concise.rawValue ? .concise : .standard
    }
}
