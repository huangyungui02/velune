import SwiftUI

struct ResonanceView: View {
    private let pageSize: Int = 20

    @State private var resonances: [Resonance] = []
    @State private var isLoadingInitial = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var errorMessage: String?
    @State private var sortOption: ResonanceSort = .updatedAt

    var body: some View {
        ZStack {
            BackgroundView()

            Group {
                if isLoadingInitial, resonances.isEmpty {
                    ProgressView(L10n.string("common.loading"))
                        .tint(UITheme.accent)
                } else if resonances.isEmpty {
                    if let errorMessage {
                        loadFailedView(message: errorMessage)
                    } else {
                        EmptyView(title: L10n.string("resonance.empty"))
                    }
                } else {
                    resonanceListView
                }
            }
        }
        .navigationTitle(L10n.string("resonance.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(L10n.string("resonance.sort.title"), selection: $sortOption) {
                        ForEach(ResonanceSort.allCases) { option in
                            Text(localizedLabel(for: option)).tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
        .task {
            await reloadResonances()
        }
        .onChange(of: sortOption) { _, _ in
            Task {
                await reloadResonances()
            }
        }
    }

    private var resonanceListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(resonances) { resonance in
                    NavigationLink {
                        ChatView(
                            soulerId: resonance.soulerId,
                            soulerName: resonance.soulerName
                        )
                    } label: {
                        ResonanceListCard(resonance: resonance)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        Task {
                            await loadMoreIfNeeded(current: resonance)
                        }
                    }
                }

                if isLoadingMore {
                    ProgressView(L10n.string("common.loading"))
                        .tint(UITheme.accent)
                        .padding(.vertical, 12)
                }
            }
            .padding()
        }
        .refreshable {
            await reloadResonances()
        }
    }

    private func loadFailedView(message: String) -> some View {
        VStack(spacing: 12) {
            Text(L10n.string("resonance.load.failed"))
                .font(.system(size: 21, weight: .medium, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(UITheme.primaryText)

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(UITheme.secondaryText)
                .multilineTextAlignment(.center)

            Button(L10n.string("common.retry")) {
                Task {
                    await reloadResonances()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @MainActor
    private func reloadResonances() async {
        if isLoadingInitial { return }

        isLoadingInitial = true
        errorMessage = nil
        hasMore = true
        defer { isLoadingInitial = false }

        do {
            let page = try await Resonance.getPage(limit: pageSize, offset: 0, sort: sortOption)
            resonances = page
            hasMore = page.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
            resonances = []
            hasMore = false
        }
    }

    @MainActor
    private func loadMoreIfNeeded(current: Resonance) async {
        guard hasMore else { return }
        guard !isLoadingInitial, !isLoadingMore else { return }
        guard current.id == resonances.last?.id else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await Resonance.getPage(limit: pageSize, offset: resonances.count, sort: sortOption)
            resonances.append(contentsOf: page)
            hasMore = page.count == pageSize
        } catch {
            hasMore = false
        }
    }

    private func localizedLabel(for option: ResonanceSort) -> String {
        switch option {
        case .updatedAt:
            return L10n.string("resonance.sort.updatedAt")
        case .resonanceCount:
            return L10n.string("resonance.sort.count")
        }
    }
}

private struct ResonanceListCard: View {
    let resonance: Resonance

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(resonance.soulerName)
                        .font(UITheme.literary(size: 20, weight: .semibold))
                        .foregroundStyle(UITheme.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text("\(resonance.count)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(UITheme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.10), in: .capsule)
                }

                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(UITheme.tertiaryText)

                    Text(resonance.updatedAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(UITheme.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(.rect)
    }
}
