import Foundation
import EventSource
import OSLog

nonisolated enum APISSEClient {
    private static let logger = AppLogger.network
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static func stream<Body: Encodable>(
        path: String,
        body: Body
    ) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let encodedBody: Data
            do {
                encodedBody = try JSONEncoder().encode(body)
            } catch {
                continuation.finish(throwing: error)
                return
            }

            let task = Task(priority: .userInitiated) {
                do {
                    let request = try await makeRequest(path: path, body: encodedBody)
                    let eventSource = EventSource(mode: .default)
                    let dataTask = eventSource.dataTask(for: request)

                    for await event in dataTask.events() {
                        if Task.isCancelled { break }

                        switch event {
                        case .open:
                            continue
                        case .closed:
                            continuation.finish()
                            return
                        case let .event(message):
                            guard let raw = message.data?
                                .trimmingCharacters(in: .whitespacesAndNewlines),
                                !raw.isEmpty,
                                raw != "[DONE]"
                            else {
                                continue
                            }
                            continuation.yield(Data(raw.utf8))
                        case let .error(error):
                            throw resolveEventSourceError(error)
                        }
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

    nonisolated private static func makeRequest(path: String, body: Data) async throws -> URLRequest {
        let accessToken = await MainActor.run { AuthManager.shared.currentAccessToken }
        guard let accessToken else {
            logger.error("stream request blocked: missing Supabase access token")
            throw NSError(
                domain: "APISSEClient",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Missing Supabase access token"]
            )
        }

        let endpoint = try Backend.requireAPIBaseURL().appending(path: path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    nonisolated private static func resolveEventSourceError(_ error: Error) -> Error {
        guard case let EventSourceError.connectionError(statusCode, response) = error else {
            return error
        }

        let message = parseAPIErrorMessage(from: response)
            ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
        logger.error("stream request failed: status=\(statusCode, privacy: .public) message=\(message, privacy: .public)")
        return NSError(
            domain: "APISSEClient",
            code: statusCode,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    static func decode<Payload: Decodable>(
        _ payloadType: Payload.Type,
        from data: Data,
        domain: String
    ) throws -> Payload {
        do {
            return try decoder.decode(payloadType, from: data)
        } catch {
            throw NSError(
                domain: domain,
                code: -2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invalid stream payload format",
                    NSUnderlyingErrorKey: error,
                ]
            )
        }
    }

    nonisolated private static func parseAPIErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty
        {
            if
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let message = object["message"] as? String ?? object["error"] as? String,
                !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                return message
            }
            return text
        }
        return nil
    }
}
