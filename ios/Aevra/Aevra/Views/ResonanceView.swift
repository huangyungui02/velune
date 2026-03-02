import SwiftUI

struct ResonanceView: View {
    private let pageSize: Int = 20

    @State private var resonances: [Resonance] = []
    @State private var isLoadingInitial = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            BackgroundView()

            Group {
                if isLoadingInitial, resonances.isEmpty {
                    ProgressView("common.loading")
                        .tint(UITheme.accent)
                } else if resonances.isEmpty {
                    if let errorMessage {
                        loadFailedView(message: errorMessage)
                    } else {
                        EmptyView(title: "resonance.empty")
                    }
                } else {
                    resonanceListView
                }
            }
        }
        .navigationTitle("resonance.title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reloadResonances()
        }
    }

    private var resonanceListView: some View {
        List {
            ForEach(resonances) { resonance in
                NavigationLink {
                    ChatView(
                        soulerId: resonance.soulerId,
                        soulerName: resonance.soulerName
                    )
                } label: {
                    ResonanceRow(resonance: resonance)
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(.white.opacity(0.08))
                .onAppear {
                    Task {
                        await loadMoreIfNeeded(current: resonance)
                    }
                }
            }

            if isLoadingMore {
                ProgressView("common.loading")
                    .tint(UITheme.accent)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await reloadResonances()
        }
    }

    private func loadFailedView(message: String) -> some View {
        VStack(spacing: 12) {
            Text("resonance.load.failed")
                .font(.title3.weight(.semibold))
                .foregroundStyle(UITheme.primaryText)

            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(UITheme.secondaryText)
                .multilineTextAlignment(.center)

            Button("common.retry") {
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
            let page = try await Resonance.getPage(limit: pageSize, offset: 0)
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
            let page = try await Resonance.getPage(limit: pageSize, offset: resonances.count)
            resonances.append(contentsOf: page)
            hasMore = page.count == pageSize
        } catch {
            hasMore = false
        }
    }

}

private struct ResonanceRow: View {
    let resonance: Resonance

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(resonance.soulerName)
                .font(.body.weight(.medium))
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText)
                .lineLimit(1)

            Text(resonance.updatedAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(UITheme.tertiaryText)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}
