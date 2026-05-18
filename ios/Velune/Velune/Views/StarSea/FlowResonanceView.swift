import SwiftUI

struct FlowResonanceView: View {
    let manager: FlowManager
    let onClose: () -> Void

    @State private var visibleFigureCount = 0
    @State private var figureRevealTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            StarryBackgroundView()

            VStack(spacing: 0) {
                Spacer(minLength: 28)

                VStack(spacing: 22) {
                    keywordTrace

                    if manager.figures.isEmpty {
                        listeningState
                    } else {
                        figureField
                    }
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: 560)

                Spacer(minLength: 20)

                enterButton
                    .padding(.bottom, 44)
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
            revealFigures(manager.figures)
        }
        .onChange(of: manager.runID) { _, _ in
            figureRevealTask?.cancel()
            visibleFigureCount = 0
        }
        .onChange(of: manager.figures) { _, newValue in
            revealFigures(newValue)
        }
        .onDisappear {
            figureRevealTask?.cancel()
        }
    }

    private var keywordTrace: some View {
        StarSeaFlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(manager.keywords, id: \.self) { keyword in
                Text(keyword)
                    .font(.caption)
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.tertiaryText)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .glassEffect(.regular.tint(.white.opacity(0.05)), in: .capsule)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .frame(maxWidth: .infinity)
        .opacity(0.78)
    }

    private var listeningState: some View {
        VStack(spacing: 16) {
            MatchingWaveIcon(ringSize: 12, containerSize: 24)

            Text("flow.resonance.status")
                .font(.footnote)
                .tracking(1.6)
                .foregroundStyle(UITheme.tertiaryText)
        }
        .opacity(manager.isMatchingResonances ? 1 : 0.72)
        .animation(.easeInOut(duration: 0.24), value: manager.isMatchingResonances)
    }

    private var figureField: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 14) {
                ForEach(Array(manager.figures.prefix(visibleFigureCount))) { figure in
                    ResonanceFigureCard(
                        figure: figure,
                        isSelected: manager.selectedFigureID == figure.id
                    ) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        manager.selectFigure(figure)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .animation(.easeInOut(duration: 0.46), value: visibleFigureCount)
        .animation(.easeInOut(duration: 0.22), value: manager.selectedFigureID)
    }

    private var enterButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text("flow.resonance.enter")
                .font(.footnote.weight(.medium))
                .tracking(1.4)
                .foregroundStyle(UITheme.secondaryText)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .glassEffect(.regular.tint(.white.opacity(0.08)), in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(manager.selectedFigureID == nil || visibleFigureCount == 0)
        .opacity(visibleFigureCount > 0 ? 1 : 0)
        .animation(.easeInOut(duration: 0.4), value: visibleFigureCount)
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

    private func revealFigures(_ figures: [ResonanceFigure]) {
        figureRevealTask?.cancel()
        visibleFigureCount = 0

        guard !figures.isEmpty else { return }

        figureRevealTask = Task {
            for index in 1 ... figures.count {
                if Task.isCancelled { return }
                try? await Task.sleep(for: .milliseconds(index == 1 ? 180 : 420))
                if Task.isCancelled { return }
                visibleFigureCount = index
            }
        }
    }
}

private struct ResonanceFigureCard: View {
    let figure: ResonanceFigure
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 16) {
                portrait

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(figure.name)
                            .font(.headline)
                            .fontDesign(.serif)
                            .foregroundStyle(UITheme.primaryText.opacity(0.9))

                        Spacer(minLength: 12)

                        if isSelected {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(UITheme.accent.opacity(0.72))
                                .transition(.opacity.combined(with: .scale(scale: 0.72)))
                        }
                    }

                    Text(figure.reason)
                        .font(.subheadline)
                        .fontDesign(.serif)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(UITheme.secondaryText.opacity(0.86))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                .regular.tint(isSelected ? UITheme.accent.opacity(0.16) : .white.opacity(0.07)),
                in: .rect(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isSelected ? UITheme.accent.opacity(0.34) : .white.opacity(0.08),
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var portrait: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.07))

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)

            Text(initials(for: figure.name))
                .font(.title3)
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText.opacity(0.66))
        }
        .aspectRatio(0.75, contentMode: .fit)
        .frame(width: 58)
        .accessibilityHidden(true)
    }

    private func initials(for name: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return "?" }

        let words = trimmedName.split(separator: " ")
        if words.count >= 2 {
            return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        }

        return String(trimmedName.prefix(1)).uppercased()
    }
}
