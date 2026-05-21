import Foundation

enum ChatStreamService {
    private static let domain = "ResonanceChat"

    struct DonePayload {
        var sessionId: UUID?
        var title: String?
    }

    enum Event {
        case delta(String)
        case options([String])
        case done(DonePayload)
    }

    private struct SendRequest: Encodable {
        var sessionId: String?
        var soulerId: String
        var soulerName: String
        var replyLength: String
        var content: String
    }

    private struct StreamEvent: Decodable {
        let type: String
        let delta: String?
        let sessionId: UUID?
        let title: String?
        let options: [String]?
        let code: String?
        let message: String?
    }

    static func streamReply(
        sessionId: UUID?,
        soulerId: UUID,
        soulerName: String,
        path: String,
        content: String
    ) -> AsyncThrowingStream<Event, Error> {
        let request = SendRequest(
            sessionId: sessionId?.uuidString,
            soulerId: soulerId.uuidString,
            soulerName: soulerName,
            replyLength: UserDefaults.standard.string(forKey: AIReplyLength.storageKey) ?? AIReplyLength.standard.rawValue,
            content: content
        )
        let payloadDataStream = APISSEClient.stream(path: path, body: request)

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
        case "delta":
            guard let delta = payload.delta, !delta.isEmpty else { return nil }
            return .delta(delta)
        case "options":
            guard let options = payload.options else { return nil }
            let normalized = normalizeOptions(options)
            guard !normalized.isEmpty else { return nil }
            return .options(normalized)
        case "done":
            return .done(
                DonePayload(
                    sessionId: payload.sessionId,
                    title: payload.title
                )
            )
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
        var userInfo: [String: Any] = [
            NSLocalizedDescriptionKey: errorMessage(for: payload)
        ]
        if let code = payload.code, !code.isEmpty {
            userInfo[AppErrorUserInfoKey.billingCode] = code
        }

        return NSError(domain: domain, code: -1, userInfo: userInfo)
    }

    private static func errorMessage(for payload: StreamEvent) -> String {
        if payload.code == "INSUFFICIENT_CREDITS" {
            return NSLocalizedString("billing.error.insufficientStardust.free", comment: "")
        }
        return payload.message ?? String(localized: "matching.error.unknown")
    }
}
