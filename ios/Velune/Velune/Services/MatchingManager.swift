import OSLog
import Supabase
import SwiftData
import SwiftUI

@Observable
class MatchingManager {
    static let shared = MatchingManager()
    private let logger = AppLogger.matching
    
    var text = ""
    var isMatching = false
    var currentStirring: Stirring?
    var errorMessage: String?
    var billingErrorContext: BillingErrorContext?
    private var matchingTask: Task<Void, Never>?
    
    private init() {}
    
    func startMatching(text: String, context: ModelContext) {
        matchingTask?.cancel()
        self.text = text
        currentStirring = nil
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
                currentStirring = nil
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
                currentStirring?.status = "failed"
                persistChangesIfNeeded(context: context)
            }
            logger.error("matching failed: \(error.localizedDescription, privacy: .public)")
        }
        
        await MainActor.run {
            isMatching = false
        }
    }
    
    private func composeAndStreamEchoes(context: ModelContext) async throws {
        let userId = try AuthManager.shared.getUserId()
        let newStirring = Stirring(userId: userId.uuidString, content: text)
        await MainActor.run {
            context.insert(newStirring)
            currentStirring = newStirring
        }

        let stirring = newStirring
        var receivedDone = false

        for try await event in EchoStreamService.stream(
            stirringId: stirring.id,
            content: stirring.content,
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
                    userId: stirring.userId,
                    content: payload.content,
                    soulerId: payload.soulerId,
                    soulerName: displayName
                )
                await MainActor.run {
                    if currentStirring?.echoes.contains(where: { $0.id == echo.id }) == false {
                        currentStirring?.echoes.append(echo)
                    }
                }
            case .done:
                receivedDone = true
            }
        }

        if !Task.isCancelled && receivedDone {
            await MainActor.run {
                currentStirring?.status = "complete"
                persistChangesIfNeeded(context: context)
            }
        }
    }

    @MainActor
    private func persistChangesIfNeeded(context: ModelContext) {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
