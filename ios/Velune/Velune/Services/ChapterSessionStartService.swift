import Foundation
import OSLog

enum ChapterSessionStartService {
    private static let logger = AppLogger.network
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    struct AssistantMessage: Decodable {
        var id: UUID
        var createdAt: String
        var content: String
    }

    struct ResponsePayload: Decodable {
        var sessionId: UUID
        var soulerId: UUID
        var chapterId: UUID
        var title: String
        var assistantMessage: AssistantMessage
        var options: [String]?
    }

    private struct RequestBody: Encodable {
        var replyLength: String
    }

    static func start(
        soulerId: UUID,
        chapterId: UUID,
        path: String
    ) async throws -> ResponsePayload {
        let accessToken = await MainActor.run { AuthManager.shared.currentAccessToken }
        guard let accessToken else {
            throw NSError(
                domain: "ChapterSessionStartService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Missing Supabase access token"]
            )
        }

        var request = URLRequest(url: try Backend.requireAPIBaseURL().appending(path: path))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                replyLength: UserDefaults.standard.string(forKey: AIReplyLength.storageKey) ?? AIReplyLength.standard.rawValue
            )
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "ChapterSessionStartService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
            )
        }

        if (200 ..< 300).contains(httpResponse.statusCode) {
            return try decoder.decode(ResponsePayload.self, from: data)
        }

        let message = parseErrorMessage(from: data)
            ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
        logger.error(
            "chapter start request failed: soulerId=\(soulerId.uuidString, privacy: .public) chapterId=\(chapterId.uuidString, privacy: .public) status=\(httpResponse.statusCode, privacy: .public) message=\(message, privacy: .public)"
        )
        throw NSError(
            domain: "ChapterSessionStartService",
            code: httpResponse.statusCode,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private static func parseErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
            if let error = object["error"] as? String, !error.isEmpty {
                return error
            }
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
