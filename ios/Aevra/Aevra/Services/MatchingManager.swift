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
            try await composeAndStreamEchoes(context: context)
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                billingErrorContext = error.billingErrorContext
                currentGlimmer?.status = "failed"
            }
            print("Matching error: \(error)")
        }
        
        await MainActor.run {
            isMatching = false
        }
    }
    
    private func composeAndStreamEchoes(context: ModelContext) async throws {
        let userId = try AuthManager.shared.getUserId()
        let newGlimmer = Glimmer(userId: userId.uuidString, content: text)
        await MainActor.run {
            context.insert(newGlimmer)
            currentGlimmer = newGlimmer
            currentGlimmer?.status = "processing"
        }

        let glimmer = newGlimmer
        var receivedDone = false

        for try await event in EchoStreamService.stream(
            glimmerId: glimmer.id,
            content: glimmer.content,
            path: "\(AppLanguage.current.apiLanguageCode)/glimmers/compose"
        ) {
            if Task.isCancelled { break }

            switch event {
            case .ready:
                break
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
                    userId: glimmer.userId,
                    content: payload.content,
                    soulerId: payload.soulerId,
                    soulerName: displayName
                )
                await MainActor.run {
                    if currentGlimmer?.echoes.contains(where: { $0.id == echo.id }) == false {
                        currentGlimmer?.echoes.append(echo)
                    }
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
