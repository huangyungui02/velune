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
        
        guard let accessToken = supabase.auth.currentSession?.accessToken else {
            throw AppError.unauthenticated
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
        
        struct StreamRequest: Encodable {
            let inspirationId: UUID
        }
        
        let url = supabaseURL.appendingPathComponent("functions/v1/echo")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONEncoder().encode(StreamRequest(inspirationId: inspiration.id))
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw NSError(domain: "EchoStream", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Echo stream failed with status \(http.statusCode)"
            ])
        }
        
        let decoder = JSONDecoder()
        for try await line in bytes.lines {
            if Task.isCancelled { break }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            
            let event = try decoder.decode(StreamEvent.self, from: Data(trimmed.utf8))
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
}
