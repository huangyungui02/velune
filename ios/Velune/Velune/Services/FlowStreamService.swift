import Foundation

struct ResonanceFigure: Identifiable, Decodable, Equatable {
    let id: UUID
    let name: String
    let reason: String

    enum CodingKeys: String, CodingKey {
        case name
        case reason
    }

    init(id: UUID = UUID(), name: String, reason: String) {
        self.id = id
        self.name = name
        self.reason = reason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.reason = try container.decode(String.self, forKey: .reason)
    }
}

enum FlowStreamService {
    private static let domain = "FlowStream"

    enum Event {
        case themes([String])
        case resonances([ResonanceFigure])
        case done
    }

    private struct ThemeRequestBody: Encodable {
        let content: String
    }

    private struct StreamEvent: Decodable {
        let type: String
        let keywords: [String]?
        let figures: [ResonanceFigure]?
        let message: String?
    }

    static func stream(content: String) -> AsyncThrowingStream<Event, Error> {
        let payloadDataStream = APISSEClient.stream(
            path: "\(AppLanguage.current.apiLanguageCode)/flow",
            body: ThemeRequestBody(content: content)
        )

        return streamEvents(from: payloadDataStream)
    }

    private static func streamEvents(
        from payloadDataStream: AsyncThrowingStream<Data, Error>
    ) -> AsyncThrowingStream<Event, Error> {
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
        case "themes":
            return .themes(payload.keywords ?? [])
        case "resonances":
            return .resonances(payload.figures ?? [])
        case "done":
            return .done
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
                NSLocalizedDescriptionKey: payload.message ?? String(localized: "flow.error.unknown")
            ]
        )
    }
}
