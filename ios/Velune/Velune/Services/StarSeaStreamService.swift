import Foundation

enum StarSeaMemoryPreference {
    static let key = "starsea.memoryEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: key)
    }
}

enum StarSeaStreamService {
    private static let domain = "StarSea"

    struct ResonanceMatch: Identifiable, Hashable, Decodable {
        var id: String { "\(name)-\(line)" }
        var name: String
        var line: String
        var soulerId: UUID?
        var resolutionRequestId: UUID?
        var resolutionStatus: String?
    }

    struct ResolutionStatus: Decodable {
        var status: String
        var requestId: UUID
        var name: String
        var soulerId: UUID?
        var error: String?
    }

    struct SettledGlimmer: Hashable, Decodable {
        var content: String
        var keywords: [String]
        var blessing: String?
    }

    enum Event {
        case ready(threadId: String)
        case delta(String, displayType: DeltaDisplayType)
        case options([String])
        case resonanceMatch([ResonanceMatch])
        case done(threadId: String?)
        case settled(SettledGlimmer)
    }

    enum DeltaDisplayType: String, Decodable {
        case starsea
        case thinking
        case thinkingSummary = "thinking_summary"
        case collect
        case unknown

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            self = Self(rawValue: value) ?? .unknown
        }
    }

    enum Content: Encodable {
        case text(String)
        case divination(DivinationContent)
        case triggerCollect

        struct DivinationContent: Encodable {
            var castedLines: [Int]
            var date: String
            var question: String

            enum CodingKeys: String, CodingKey {
                case castedLines = "casted_lines"
                case date
                case question
            }
        }

        enum CodingKeys: String, CodingKey {
            case type
            case content
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .text(content):
                try container.encode("text", forKey: .type)
                try container.encode(content, forKey: .content)
            case let .divination(content):
                try container.encode("divination", forKey: .type)
                try container.encode(content, forKey: .content)
            case .triggerCollect:
                try container.encode("trigger", forKey: .type)
                try container.encode("collect", forKey: .content)
            }
        }
    }

    private struct SendRequest: Encodable {
        var threadId: String?
        var content: Content
        var metadata: Metadata

        enum CodingKeys: String, CodingKey {
            case threadId = "thread_id"
            case content
            case metadata
        }
    }

    private struct Metadata: Encodable {
        var timezone: String
        var memoryEnabled: Bool

        enum CodingKeys: String, CodingKey {
            case timezone
            case memoryEnabled = "memory_enabled"
        }
    }

    private struct StreamEvent: Decodable {
        var type: String
        var content: StreamEventContent
    }

    private struct StreamEventContent: Decodable {
        var threadId: String?
        var delta: String?
        var displayType: DeltaDisplayType?
        var matches: [ResonanceMatch]?
        var options: [String]?
        var glimmer: SettledGlimmer?
        var content: String?
        var message: String?
    }

    static func stream(
        threadId: String?,
        content: Content
    ) -> AsyncThrowingStream<Event, Error> {
        let request = SendRequest(
            threadId: threadId,
            content: content,
            metadata: Metadata(
                timezone: UserStatusClientMetadata.current().timezone,
                memoryEnabled: StarSeaMemoryPreference.isEnabled
            )
        )
        let payloadDataStream = APISSEClient.stream(
            path: "v1/\(AppLanguage.current.apiLanguageCode)/starsea",
            body: request
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await payloadData in payloadDataStream {
                        let payload = try APISSEClient.decode(
                            StreamEvent.self,
                            from: payloadData,
                            domain: domain
                        )
                        guard let event = try mapEvent(payload) else { continue }
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    static func resolutionStatus(requestId: UUID) async throws -> ResolutionStatus {
        let accessToken = await MainActor.run { AuthManager.shared.currentAccessToken }
        guard let accessToken else {
            throw NSError(
                domain: domain,
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Missing Supabase access token"]
            )
        }

        let endpoint = try Backend.requireAPIBaseURL()
            .appending(path: "v1/\(AppLanguage.current.apiLanguageCode)/soulers/resolutions/\(requestId.uuidString)")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw NSError(
                domain: domain,
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "matching.error.unknown")]
            )
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ResolutionStatus.self, from: data)
    }

    private static func mapEvent(_ payload: StreamEvent) throws -> Event? {
        let content = payload.content
        switch payload.type {
        case "ready":
            guard let threadId = content.threadId else { return nil }
            return .ready(threadId: threadId)
        case "delta":
            guard let delta = content.delta, !delta.isEmpty else { return nil }
            return .delta(delta, displayType: content.displayType ?? .starsea)
        case "option":
            guard let options = content.options else { return nil }
            let normalized = normalizeOptions(options)
            guard !normalized.isEmpty else { return nil }
            return .options(normalized)
        case "resonance_match":
            return .resonanceMatch(content.matches ?? [])
        case "done":
            return .done(threadId: content.threadId)
        case "settled":
            guard let glimmer = content.glimmer else { return nil }
            return .settled(glimmer)
        case "error":
            throw streamError(for: payload)
        default:
            return nil
        }
    }

    private static func normalizeOptions(_ options: [String]) -> [String] {
        options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func streamError(for payload: StreamEvent) -> NSError {
        NSError(
            domain: domain,
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: payload.content.message ?? String(localized: "matching.error.unknown")
            ]
        )
    }
}
