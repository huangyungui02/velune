import Supabase
import SwiftData
import SwiftUI

@Observable
class MatchingManager {
    static let shared = MatchingManager()
    
    var text = ""
    var isMatching = false
    var currentInspiration: Inspiration?
    var errorMessage: String?
    private var matchingTask: Task<Void, Never>?
    
    private init() {}
    
    func startMatching(text: String, context: ModelContext) {
        matchingTask?.cancel()
        self.text = text
        currentInspiration = nil
        isMatching = true
        errorMessage = nil
                
        matchingTask = Task.detached { [weak self] in
            await self?.performMatching(context: context)
        }
    }
    
    func reset() {
        matchingTask?.cancel()
        matchingTask = nil
        Task {
            await MainActor.run {
                isMatching = false
                text = ""
                currentInspiration = nil
                errorMessage = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performMatching(context: ModelContext) async {
        do {
            try await createInspiration(context: context)
            try await streamEchoes(context: context)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            print("Matching error: \(error)")
        }
        
        await MainActor.run {
            isMatching = false
        }
    }
    
    private func createInspiration(context: ModelContext) async throws {
        let newInspiration = Inspiration(content: text)
        try await Inspiration.create(newInspiration)
        
        await MainActor.run {
            context.insert(newInspiration)
            currentInspiration = newInspiration
        }
    }
    
    private func streamEchoes(context: ModelContext) async throws {
        guard let inspiration = currentInspiration else {
            return
        }

        struct StreamEcho: Decodable {
            let id: UUID
            let inspirationId: UUID
            let soulerId: UUID
            let content: String
        }
        
        struct StreamEvent: Decodable {
            let type: String
            let echo: StreamEcho?
            let completed: Bool?
            let message: String?
        }

        let decoder = JSONDecoder()
        var buffer = Data()
        
        func drainBuffer() async throws {
            let delimiter = Data([0x0A, 0x0A]) // "\n\n"
            while let range = buffer.range(of: delimiter) {
                let eventData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
                buffer.removeSubrange(buffer.startIndex..<range.upperBound)
                
                if eventData.isEmpty { continue }
                
                let eventText = String(decoding: eventData, as: UTF8.self)
                let dataLines = eventText
                    .split(separator: "\n")
                    .compactMap { line -> Substring? in
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("data:") {
                            return trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)[...]
                        }
                        return nil
                    }
                
                let payloadString = dataLines.joined(separator: "\n")
                if payloadString.isEmpty { continue }
                
                let event = try decoder.decode(StreamEvent.self, from: Data(payloadString.utf8))
                switch event.type {
                case "echo":
                    if let payload = event.echo {
                        let souler = try await Souler.get(payload.soulerId)
                        let echo = Echo(id: payload.id, content: payload.content, souler: souler)
                        await MainActor.run {
                            currentInspiration?.echoes.append(echo)
                        }
                    }
                case "done":
                    await MainActor.run {
                        currentInspiration?.status = (event.completed == true) ? "complete" : "incomplete"
                    }
                case "error":
                    let message = event.message ?? "Unknown error from echo stream"
                    throw NSError(domain: "EchoStream", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: message
                    ])
                default:
                    continue
                }
            }
        }
        
        let stream = supabase.functions._invokeWithStreamedResponse(
            "echo",
            options: FunctionInvokeOptions(
                body: ["inspirationId": inspiration.id]
            )
        )
        
        for try await chunk in stream {
            if Task.isCancelled { break }
            buffer.append(chunk)
            try await drainBuffer()
        }
    }
}
