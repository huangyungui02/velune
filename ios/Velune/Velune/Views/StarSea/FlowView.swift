import SwiftUI

struct FlowView: View {
    let manager: FlowManager
    let onClose: () -> Void
    let onContinue: () -> Void

    @State private var visibleKeywordCount = 0
    @State private var showsCoda = false
    @State private var keywordRevealTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            StarryBackgroundView()

            VStack(spacing: 0) {
                Spacer(minLength: 36)

                VStack(spacing: 34) {
                    submittedText

                    if manager.keywords.isEmpty {
                        listeningState
                    } else {
                        keywordField
                    }
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: 560)

                Spacer(minLength: 28)

                coda
                    .padding(.bottom, 48)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                closeButton
            }
        }
        .onAppear {
            revealKeywords(manager.keywords)
        }
        .onChange(of: manager.runID) { _, _ in
            keywordRevealTask?.cancel()
            visibleKeywordCount = 0
            showsCoda = false
        }
        .onChange(of: manager.keywords) { _, newValue in
            revealKeywords(newValue)
        }
        .onDisappear {
            keywordRevealTask?.cancel()
        }
    }

    private var submittedText: some View {
        Text(manager.submittedText)
            .font(.title3)
            .fontDesign(.serif)
            .lineSpacing(8)
            .multilineTextAlignment(.center)
            .foregroundStyle(UITheme.primaryText.opacity(0.78))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .accessibilityAddTraits(.isStaticText)
    }

    private var listeningState: some View {
        VStack(spacing: 16) {
            MatchingWaveIcon(ringSize: 12, containerSize: 24)

            Text("flow.status.listening")
                .font(.footnote)
                .tracking(1.6)
                .foregroundStyle(UITheme.tertiaryText)
        }
        .opacity(manager.isFlowing ? 1 : 0)
        .animation(.easeInOut(duration: 0.24), value: manager.isFlowing)
    }

    private var keywordField: some View {
        StarSeaFlowLayout(spacing: 12, lineSpacing: 12) {
            ForEach(Array(manager.keywords.prefix(visibleKeywordCount).enumerated()), id: \.offset) { _, keyword in
                Text(keyword)
                    .font(.callout)
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.primaryText.opacity(0.86))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .glassEffect(.regular.tint(.white.opacity(0.08)), in: .capsule)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.48), value: visibleKeywordCount)
    }

    private var coda: some View {
        Button {
            continueToResonancePage()
        } label: {
            VStack(spacing: 18) {
                Text("flow.coda.line")
                    .font(.callout)
                    .fontDesign(.serif)
                    .tracking(0.8)

                Text("flow.coda.continue")
                    .font(.footnote.weight(.medium))
                    .tracking(1.4)
                    .foregroundStyle(UITheme.tertiaryText)
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(UITheme.secondaryText)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!showsCoda)
        .opacity(showsCoda ? 1 : 0)
        .animation(.easeInOut(duration: 0.7), value: showsCoda)
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    guard showsCoda, value.translation.height < -18 else { return }
                    continueToResonancePage()
                }
        )
        .accessibilityElement(children: .combine)
    }

    private var closeButton: some View {
        Button(role: .cancel, action: onClose) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.medium))
                .foregroundStyle(UITheme.secondaryText)
                .padding(8)
                .contentShape(.circle)
        }
    }

    private func continueToResonancePage() {
        guard showsCoda else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        onContinue()
    }

    private func revealKeywords(_ keywords: [String]) {
        keywordRevealTask?.cancel()
        visibleKeywordCount = 0
        showsCoda = false

        guard !keywords.isEmpty else { return }

        keywordRevealTask = Task {
            for index in 1 ... keywords.count {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(index == 1 ? 240 : 520))
                if Task.isCancelled { return }
                visibleKeywordCount = index
            }

            try? await Task.sleep(for: .milliseconds(620))
            if !Task.isCancelled {
                showsCoda = true
            }
        }
    }
}
