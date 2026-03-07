import SwiftUI

struct StarSeaSidebarView: View {
    let resonances: [Resonance]
    let isLoadingResonances: Bool
    let hasMoreResonances: Bool
    let resonanceMenuError: String?
    let selectedSoulerId: UUID?
    let locale: Locale
    let sidebarWidth: CGFloat
    @Binding var resonanceSearchText: String
    let onRetry: () async -> Void
    let onLoadMore: () async -> Void
    let onSelectResonance: (Resonance) async -> Void
    let onTapStarSea: () -> Void
    let onOpenGlimmerComposer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let resonanceMenuError {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(resonanceMenuError)
                            .font(.footnote)
                            .foregroundStyle(UITheme.secondaryText)

                        Button("common.retry") {
                            Task {
                                await onRetry()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 8)
                } else if isLoadingResonances, resonances.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("common.loading")
                            .font(.footnote)
                            .foregroundStyle(UITheme.secondaryText)
                    }
                    .padding(.top, 8)
                } else if displayedResonances.isEmpty {
                    if resonances.isEmpty, !hasActiveResonanceSearch {
                        resonanceEmptyStateView
                            .padding(.top, 6)
                    } else {
                        if hasActiveResonanceSearch {
                            ContentUnavailableView.search(text: resonanceSearchText)
                                .padding(.top, 6)
                        } else {
                            ContentUnavailableView {
                                Label("resonance.empty", systemImage: "magnifyingglass")
                            }
                            .padding(.top, 6)
                        }
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(displayedResonances) { resonance in
                                Button {
                                    Task {
                                        await onSelectResonance(resonance)
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        HStack(spacing: 8) {
                                            Image(systemName: selectedSoulerId == resonance.soulerId ? "checkmark" : "message")
                                                .font(.caption.weight(.semibold))
                                            Text(resonance.soulerName)
                                                .lineLimit(1)
                                                .font(.body.weight(.medium))
                                                .fontDesign(.serif)
                                        }
                                        .foregroundStyle(UITheme.primaryText)

                                        Spacer(minLength: 8)

                                        Text(resonance.updatedAt, format: .relative(presentation: .named).locale(locale))
                                            .font(.caption)
                                            .foregroundStyle(UITheme.secondaryText)
                                            .lineLimit(1)
                                            .monospacedDigit()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                    .background(
                                        selectedSoulerId == resonance.soulerId ? .white.opacity(0.15) : .clear,
                                        in: .rect(cornerRadius: 12)
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            if isLoadingResonances {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text("common.loading")
                                        .font(.footnote)
                                        .foregroundStyle(UITheme.secondaryText)
                                }
                                .padding(.top, 8)
                            } else if hasMoreResonances, !hasActiveResonanceSearch {
                                Color.clear
                                    .frame(height: 1)
                                    .onAppear {
                                        Task {
                                            await onLoadMore()
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)

            if !resonances.isEmpty {
                sidebarFloatingToolbar
            }
        }
        .padding(12)
        .frame(width: sidebarWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
    }

    private var hasActiveResonanceSearch: Bool {
        !resonanceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayedResonances: [Resonance] {
        let keyword = resonanceSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return resonances }
        return resonances.filter { $0.soulerName.localizedCaseInsensitiveContains(keyword) }
    }

    private var resonanceEmptyStateView: some View {
        ContentUnavailableView {
            Label("starsea.empty.resonanceTitle", systemImage: "sparkles")
                .fontDesign(.serif)
                .padding(.bottom, 6)
        } description: {
            Text("starsea.empty.resonanceSubtitle")
                .fontDesign(.serif)
                .foregroundStyle(UITheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 4)
        } actions: {
            Button(action: onOpenGlimmerComposer) {
                Label("starsea.action.writeGlimmer", systemImage: "pencil.and.scribble")
                    .font(.footnote.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Color.clear, in: .capsule)
            .glassEffect(in: .capsule)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var sidebarFloatingToolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(UITheme.secondaryText)

                TextField("common.search", text: $resonanceSearchText)
                    .textFieldStyle(.plain)
                    .font(.footnote)
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.primaryText)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.clear, in: .capsule)
            .glassEffect(in: .capsule)

            Button(action: onTapStarSea) {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.semibold))
                    .frame(width: 46, height: 46)
                    .background(Color.clear, in: .circle)
                    .glassEffect(in: .circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(UITheme.primaryText)
            .accessibilityLabel(Text("starsea.title"))
        }
        .padding(.horizontal, 2)
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }
}
