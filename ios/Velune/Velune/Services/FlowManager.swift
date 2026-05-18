import OSLog
import SwiftUI

@MainActor
@Observable
final class FlowManager {
    private let logger = AppLogger.matching

    var submittedText = ""
    var keywords: [String] = []
    var figures: [ResonanceFigure] = []
    var selectedFigureID: UUID?
    var isFlowing = false
    var isMatchingResonances = false
    var errorMessage: String?
    var runID = UUID()

    private var flowTask: Task<Void, Never>?

    func start(text: String) {
        flowTask?.cancel()
        submittedText = text
        keywords = []
        figures = []
        selectedFigureID = nil
        isFlowing = true
        isMatchingResonances = false
        errorMessage = nil
        runID = UUID()

        flowTask = Task { [weak self] in
            await self?.performFlow(content: text)
        }
    }

    func selectFigure(_ figure: ResonanceFigure) {
        selectedFigureID = figure.id
    }

    func reset() {
        flowTask?.cancel()
        flowTask = nil
        submittedText = ""
        keywords = []
        figures = []
        selectedFigureID = nil
        isFlowing = false
        isMatchingResonances = false
        errorMessage = nil
        runID = UUID()
    }

    private func performFlow(content: String) async {
        do {
            var receivedThemes = false
            var receivedResonances = false

            for try await event in FlowStreamService.stream(content: content) {
                if Task.isCancelled { return }

                switch event {
                case let .themes(themes):
                    keywords = themes
                    receivedThemes = true
                    isFlowing = false
                    isMatchingResonances = true
                case let .resonances(resonanceFigures):
                    figures = resonanceFigures
                    selectedFigureID = resonanceFigures.first?.id
                    receivedResonances = true
                    isMatchingResonances = false
                case .done:
                    isFlowing = false
                    isMatchingResonances = false
                }
            }

            if !receivedThemes, !Task.isCancelled {
                throw NSError(
                    domain: "FlowManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "flow.error.empty")]
                )
            }
            if receivedThemes, !receivedResonances, !Task.isCancelled {
                throw NSError(
                    domain: "FlowManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "flow.resonance.error.empty")]
                )
            }
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
                logger.error("flow failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        isFlowing = false
        isMatchingResonances = false
    }
}
