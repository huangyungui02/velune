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
    
    private var realtimeChannel: RealtimeChannelV2?
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
            await cleanupChannel()
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
            try await listenToEchoes(context: context)
            try await invokeEchoFunction()
                        
            await MainActor.run {
                currentInspiration?.status = "complete"
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
            print("Matching error: \(error)")
        }
        
        await MainActor.run {
            isMatching = false
        }
        
        await cleanupChannel()
    }
    
    private func createInspiration(context: ModelContext) async throws {
        let newInspiration = Inspiration(content: text)
        try await Inspiration.create(newInspiration)
        
        await MainActor.run {
            context.insert(newInspiration)
            currentInspiration = newInspiration
        }
    }
    
    private func listenToEchoes(context: ModelContext) async throws {
        await cleanupChannel()
        
        guard let inspiration = currentInspiration else {
            return
        }
        
        let channel = supabase.channel("echoes-\(inspiration.id)")
        
        await MainActor.run {
            realtimeChannel = channel
        }
        
        struct Insertion: Codable {
            let id: UUID
            let content: String
            let soulerId: UUID
            
            enum CodingKeys: String, CodingKey {
                case id, content
                case soulerId = "souler_id"
            }
        }
        
        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "echoes",
            filter: .eq("inspiration_id", value: inspiration.id)
        )
        
        try await channel.subscribeWithError()
        
        Task {
            for await insert in insertions {
                do {
                    let insertion = try insert.decodeRecord(as: Insertion.self, decoder: JSONDecoder())
                    let souler = try await Souler.get(insertion.soulerId)
                    let echo = Echo(id: insertion.id, content: insertion.content, souler: souler)
                    
                    await MainActor.run {
                        currentInspiration?.echoes.append(echo)
                    }
                } catch {
                    print("Error processing echo: \(error)")
                }
            }
        }
    }
    
    private func invokeEchoFunction() async throws {
        guard let inspiration = currentInspiration else { return }
        
        try await supabase.functions.invoke(
            "echo",
            options: FunctionInvokeOptions(
                body: ["inspirationId": inspiration.id]
            )
        )
    }
    
    private func cleanupChannel() async {
        guard let channel = realtimeChannel else { return }
        
        await channel.unsubscribe()
        await supabase.removeChannel(channel)
        
        await MainActor.run {
            realtimeChannel = nil
        }
    }
}
