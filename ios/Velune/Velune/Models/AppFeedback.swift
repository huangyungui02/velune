import Foundation
import Supabase

enum AppFeedback {
    private struct Payload: Encodable {
        var userId: UUID
        var installationId: String
        var lang: String
        var content: String
        var appVersion: String
        var osVersion: String
        var deviceModel: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case installationId = "installation_id"
            case lang
            case content
            case appVersion = "app_version"
            case osVersion = "os_version"
            case deviceModel = "device_model"
        }
    }

    static func submit(content: String) async throws {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        let userId = try AuthManager.shared.getUserId()
        let metadata = InstallationClientMetadata.current()
        let payload = Payload(
            userId: userId,
            installationId: InstallationIDStore.getOrCreateInstallationID(),
            lang: AppLanguage.current.apiLanguageCode,
            content: trimmedContent,
            appVersion: metadata.appVersion,
            osVersion: metadata.osVersion,
            deviceModel: metadata.deviceModel
        )

        let supabase = try Backend.requireSupabase()
        try await supabase
            .from("feedback")
            .insert(payload)
            .execute()
    }
}
