import SwiftData
import SwiftUI

struct StarSeaView: View {
    @Environment(\.modelContext) private var context
    @State private var text = ""
    @State private var isMatchingPresented = false
    @State private var manager = MatchingManager.shared
    @State private var showError = false
    @State private var showPaywall = false
    @State private var shouldRecoverToVerseAfterError = false
    @State private var currentPage: CardID? = .glimmer
    @State private var chatRoute: EchoChatRoute?
    @State private var isComposerPresented = false
    @Binding var composeRequestID: Int

    init(composeRequestID: Binding<Int> = .constant(0)) {
        _composeRequestID = composeRequestID
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    draftToolbarContent
                }
                .navigationDestination(isPresented: $isMatchingPresented) {
                    MatchingView(
                        manager: manager,
                        currentPage: $currentPage,
                        chatRoute: $chatRoute,
                        onClose: closeCurrentGlimmer
                    )
                    .toolbar(.hidden, for: .tabBar)
                }
                .navigationDestination(item: $chatRoute) { route in
                    ChatView(
                        sessionId: route.sessionId,
                        echoId: route.sessionId == nil ? route.echoId : nil,
                        draftPrelude: route.draftPrelude,
                        soulerId: route.soulerId,
                        soulerName: route.soulerName,
                        focusComposerOnAppear: true
                    )
                    .toolbar(.hidden, for: .tabBar)
                }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $isComposerPresented) {
            StarSeaComposerCover(
                text: $text,
                onDismiss: dismissComposer,
                onSend: send
            )
        }
        .onChange(of: manager.errorMessage) { _, newValue in
            if isMatchingPresented, newValue != nil {
                shouldRecoverToVerseAfterError = true
            }
            showError = newValue != nil
        }
        .onChange(of: showError) { _, isShowing in
            if !isShowing, shouldRecoverToVerseAfterError {
                recoverToVerseAfterError()
            }
        }
        .onChange(of: composeRequestID) { _, _ in
            if manager.isMatching {
                isMatchingPresented = true
            } else {
                isMatchingPresented = false
                presentComposer()
            }
        }
        .alert("matching.error.title", isPresented: $showError) {
            if manager.billingErrorContext?.shouldOfferUpgrade == true {
                Button("billing.action.openPaywall") {
                    showPaywall = true
                }
            }
            Button("common.ok", role: .cancel) {
                recoverToVerseAfterError()
            }
        } message: {
            if let errorMessage = manager.errorMessage {
                Text(errorMessage)
            } else {
                Text("matching.error.unknown")
            }
        }
    }

    private var mainContent: some View {
        ZStack {
            StarryBackgroundView()
                .contentShape(Rectangle())

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    if hasDraft {
                        Button {
                            presentComposer()
                        } label: {
                            GlimmerCardView(content: text)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("starsea.prompt.glimmerWithin"))
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        HeroVerse()
                            .padding(.horizontal, 32)
                            .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.22), value: text.isEmpty)

            if !hasDraft {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingWriteButton {
                            presentComposer()
                        }
                        .padding(.trailing, 28)
                        .padding(.bottom, 40)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var hasDraft: Bool {
        !text.isEmpty
    }

    private var canSendDraft: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ToolbarContentBuilder
    private var draftToolbarContent: some ToolbarContent {
        if hasDraft {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive, action: clearComposer) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                }
                .accessibilityLabel(Text("common.clear"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                }
                .disabled(!canSendDraft)
                .accessibilityLabel(Text("common.submit"))
            }
        }
    }

    // MARK: - Actions

    private func send() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isComposerPresented = false

        manager.startMatching(text: input, context: context)
        text = ""
        currentPage = .glimmer

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isMatchingPresented = true
        }
    }

    private func closeCurrentGlimmer() {
        resetToVerse()
    }

    private func recoverToVerseAfterError() {
        resetToVerse()
        shouldRecoverToVerseAfterError = false
    }

    private func resetToVerse() {
        manager.reset()
        isMatchingPresented = false
        currentPage = .glimmer
        isComposerPresented = false
    }

    private func presentComposer() {
        isComposerPresented = true
    }

    private func dismissComposer() {
        isComposerPresented = false
    }

    private func clearComposer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.easeInOut(duration: 0.24)) {
            text = ""
        }
    }
}
