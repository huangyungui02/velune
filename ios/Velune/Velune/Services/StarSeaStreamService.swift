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
        case confirmRequired(threadId: String, content: String)
        case done(threadId: String?)
        case settled(SettledGlimmer)
        case discarded
    }

    private struct SendRequest: Encodable {
        var threadId: String?
        var content: String?
        var intent: Intent?
    }

    private struct ResumeRequest: Encodable {
        var threadId: String
        var approved: Bool
        var content: String?
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
        let payloadDataStream = APISSEClient.stream(path: "/starsea", body: request)

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

    static func resume(
        threadId: String,
        approved: Bool,
        content: String?
    ) -> AsyncThrowingStream<Event, Error> {
        let request = ResumeRequest(
            threadId: threadId,
            approved: approved,
            content: content
        )
        let payloadDataStream = APISSEClient.stream(path: "/starsea/resume", body: request)

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
        case "confirm_required":
            guard let threadId = payload.threadId else { return nil }
            return .confirmRequired(threadId: threadId, content: payload.content ?? "")
        case "done":
            return .done(threadId: payload.threadId)
        case "settled":
            guard let glimmer = payload.glimmer else { return nil }
            return .settled(glimmer)
        case "discarded":
            return .discarded
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
