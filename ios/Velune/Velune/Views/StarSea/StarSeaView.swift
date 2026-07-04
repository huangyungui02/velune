import SwiftUI

private enum StarSeaRoute: Hashable {
    case conversation(openingText: String, divinationData: DivinationData? = nil)
    case divination
}

struct StarSeaView: View {
    private static let blessingKey = "starsea.latestBlessing"

    @State private var text = ""
    @State private var isComposerPresented = false
    @State private var path: [StarSeaRoute] = []
    @AppStorage(Self.blessingKey) private var latestBlessing = ""
    @Binding var composeRequestID: Int

    init(composeRequestID: Binding<Int> = .constant(0)) {
        _composeRequestID = composeRequestID
    }

    var body: some View {
        NavigationStack(path: $path) {
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: StarSeaRoute.self) { route in
                    switch route {
                    case let .conversation(openingText, divinationData):
                        StarSeaConversationView(
                            openingText: openingText,
                            divinationData: divinationData,
                            onBlessing: updateLatestBlessing,
                            onLeave: leaveConversation
                        )
                    case .divination:
                        StarSeaConversationView(
                            startsWithDivination: true,
                            onBlessing: updateLatestBlessing,
                            onLeave: leaveConversation
                        )
                    }
                }
        }
        .fullScreenCover(isPresented: $isComposerPresented) {
            StarSeaComposerCover(
                text: $text,
                onDismiss: dismissComposer,
                onDone: finishComposer
            )
        }
        .onChange(of: composeRequestID) { _, _ in
            presentComposer()
        }
    }

    private var mainContent: some View {
        ZStack {
            StarryBackgroundView()
                .contentShape(Rectangle())

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    HeroVerse(text: latestBlessing)
                        .padding(.horizontal, 32)
                        .transition(.opacity.combined(with: .scale(scale: 1.02)))
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.22), value: text.isEmpty)

            VStack {
                Spacer()
                HStack {
                    QuestionmarkButton {
                        path.append(.divination)
                    }

                    Spacer()

                    FloatingWriteButton {
                        presentComposer()
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Actions

    private func presentComposer() {
        isComposerPresented = true
    }

    private func dismissComposer() {
        isComposerPresented = false
    }

    private func finishComposer() {
        let openingText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        isComposerPresented = false
        guard !openingText.isEmpty else { return }

        text = ""
        path.append(.conversation(openingText: openingText))
    }

    private func updateLatestBlessing(_ blessing: String) {
        latestBlessing = blessing
    }

    private func leaveConversation() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
}
