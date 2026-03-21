import Supabase
import SwiftData
import SwiftUI

@Observable
class MatchingManager {
    static let shared = MatchingManager()
    
    var text = ""
    var isMatching = false
    var currentGlimmer: Glimmer?
    var errorMessage: String?
    var billingErrorContext: BillingErrorContext?
    private var matchingTask: Task<Void, Never>?
    
    private init() {}
    
    func startMatching(text: String, context: ModelContext) {
        matchingTask?.cancel()
        self.text = text
        currentGlimmer = nil
        isMatching = true
        errorMessage = nil
        billingErrorContext = nil
                
        matchingTask = Task { [weak self] in
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
                currentGlimmer = nil
                errorMessage = nil
                billingErrorContext = nil
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func performMatching(context: ModelContext) async {
        do {
            try await createGlimmer(context: context)
            try await streamEchoes(context: context)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                billingErrorContext = error.billingErrorContext
            }
            print("Matching error: \(error)")
        }
        
        await MainActor.run {
            isMatching = false
        }
    }
    
    private func createGlimmer(context: ModelContext) async throws {
        let newGlimmer = Glimmer(content: text)
        try await Glimmer.create(newGlimmer)
        
        await MainActor.run {
            context.insert(newGlimmer)
            currentGlimmer = newGlimmer
        }
    }
    
    private func streamEchoes(context: ModelContext) async throws {
        guard let glimmer = currentGlimmer else {
            return
        }
        var receivedDone = false

        for try await event in EchoStreamService.stream(
            glimmerId: glimmer.id,
            path: "\(AppLanguage.current.apiLanguageCode)/echo"
        ) {
            if Task.isCancelled { break }

            switch event {
            case let .echo(payload):
                let displayName: String
                if let inlineName = payload.soulerName?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !inlineName.isEmpty
                {
                    displayName = inlineName
                } else if let souler = try? await Souler.get(payload.soulerId) {
                    displayName = souler.name
                } else {
                    displayName = String(localized: "resonance.unknownSouler")
                }

                let echo = Echo(
                    id: payload.id,
                    content: payload.content,
                    soulerId: payload.soulerId,
                    soulerName: displayName
                )
                await MainActor.run {
                    currentGlimmer?.echoes.append(echo)
                }
            case let .done(payload):
                receivedDone = true
                await MainActor.run {
                    SubscriptionManager.shared.applyServerCreditSnapshot(
                        plan: payload.plan,
                        monthlyLimit: payload.monthlyLimit,
                        creditsRemaining: payload.creditsRemaining
                    )
                }
            }
        }

        if !Task.isCancelled && receivedDone {
            await MainActor.run {
                currentGlimmer?.status = "complete"
            }
        }
    }
}
