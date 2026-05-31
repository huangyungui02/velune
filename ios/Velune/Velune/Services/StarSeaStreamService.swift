import Foundation

enum StarSeaStreamService {
    private static let domain = "StarSea"

    enum Intent: String, Encodable {
        case collect
    }

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

    struct SettledGlimmer: Identifiable, Hashable, Decodable {
        var id: UUID
        var content: String
        var createdAt: String
    }

    enum Event {
        case ready(threadId: String)
        case delta(String)
        case resonanceMatch([ResonanceMatch])
        case done(threadId: String?)
        case settled(SettledGlimmer)
    }

    private struct SendRequest: Encodable {
        var threadId: String?
        var content: String?
        var intent: Intent?
    }

    private struct StreamEvent: Decodable {
        var type: String
        var threadId: String?
        var delta: String?
        var matches: [ResonanceMatch]?
        var glimmer: SettledGlimmer?
        var content: String?
        var message: String?
    }

    static func stream(
        threadId: String?,
        content: String?,
        intent: Intent? = nil
    ) -> AsyncThrowingStream<Event, Error> {
        let request = SendRequest(
            threadId: threadId,
            content: content,
            intent: intent
        )
        let payloadDataStream = APISSEClient.stream(
            path: "api/v1/\(AppLanguage.current.apiLanguageCode)/starsea",
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
            .appending(path: "api/v1/\(AppLanguage.current.apiLanguageCode)/soulers/resolutions/\(requestId.uuidString)")
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
        switch payload.type {
        case "ready":
            guard let threadId = payload.threadId else { return nil }
            return .ready(threadId: threadId)
        case "delta":
            guard let delta = payload.delta, !delta.isEmpty else { return nil }
            return .delta(delta)
        case "resonance_match":
            return .resonanceMatch(payload.matches ?? [])
        case "done":
            return .done(threadId: payload.threadId)
        case "settled":
            guard let glimmer = payload.glimmer else { return nil }
            return .settled(glimmer)
        case "error":
            throw streamError(for: payload)
        default:
            return nil
        }
    }

    private static func streamError(for payload: StreamEvent) -> NSError {
        NSError(
            domain: domain,
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: payload.message ?? String(localized: "matching.error.unknown")
            ]
        )
    }
}
