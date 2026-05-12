import OSLog
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @State private var authManager = AuthManager.shared
    @State private var glimmers: [Glimmer] = []
    @State private var isRefreshing: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var hasMoreGlimmers: Bool = false
    @State private var glimmerOffset: Int = 0
    @State private var feedbackMessage: String?
    let onOpenGlimmerComposer: () -> Void

    private let glimmerPageSize = 10
    private let logger = AppLogger.profile

    init(onOpenGlimmerComposer: @escaping () -> Void = {}) {
        self.onOpenGlimmerComposer = onOpenGlimmerComposer
    }

    private var currentUserId: String {
        authManager.currentUserId?.uuidString ?? ""
    }

    var body: some View {
        ZStack {
            BackgroundView()

            profileContent
        }
        .navigationTitle("profile.title.glimmers")
        .navigationBarTitleDisplayMode(.inline)
        .id(locale.identifier)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .task(id: authManager.currentUserId) {
            guard !authManager.isAnonymous else {
                glimmers = []
                isRefreshing = false
                isLoadingMore = false
                hasMoreGlimmers = false
                glimmerOffset = 0
                return
            }
            loadLocalGlimmers()
            glimmerOffset = glimmers.count
            hasMoreGlimmers = SyncStateStore.state(userId: currentUserId).glimmers.hasMore

            if hasMoreGlimmers && glimmers.isEmpty {
                await loadMoreGlimmers()
            }
        }
        .alert("settings.error.title", isPresented: feedbackAlertBinding) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
        }
    }

    @ViewBuilder
    private var profileContent: some View {
        if authManager.isAnonymous {
            AppleSignInPromptCard(
                icon: "person.crop.circle.badge.checkmark",
                title: "anonymous.restricted.profile.title",
                description: "anonymous.restricted.profile.description"
            )
        } else if glimmers.isEmpty {
            profileEmptyStateView
        } else {
            ProfileTimelineList(
                glimmers: glimmers,
                isRefreshing: isRefreshing,
                isLoadingMore: isLoadingMore,
                hasMore: hasMoreGlimmers,
                onLoadMore: loadMoreGlimmers,
                onRefresh: refreshCurrentGlimmers
            )
        }
    }

    private var profileEmptyStateView: some View {
        SereneContentUnavailableView(
            title: "profile.empty.noGlimmers",
            symbol: "sparkles",
            subtitle: "profile.empty.noGlimmers.subtitle",
            actionTitle: "starsea.action.writeGlimmer",
            action: onOpenGlimmerComposer
        )
    }

    private var feedbackAlertBinding: Binding<Bool> {
        Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )
    }

    @MainActor
    private func loadLocalGlimmers() {
        do {
            glimmers = try fetchLocalGlimmers()
        } catch {
            let message = error.localizedDescription
            logger.error("local glimmer load failed: \(message, privacy: .public)")
            feedbackMessage = message
        }
    }

    @MainActor
    private func refreshLatestGlimmers(showLoadingIndicator: Bool) async {
        guard !isRefreshing else { return }

        isRefreshing = showLoadingIndicator

        do {
            let page = try await Glimmer.getPage(limit: glimmerPageSize, offset: 0)
            try upsertLocalGlimmers(page.items)
            glimmers = try fetchLocalGlimmers()
            glimmerOffset = glimmers.count
            hasMoreGlimmers = page.hasMore
            updateHasMoreGlimmersState(page.hasMore)
        } catch {
            let errorMessage = error.localizedDescription
            logger.error("glimmer refresh failed: \(errorMessage, privacy: .public)")
            feedbackMessage = errorMessage
        }

        isRefreshing = false
    }

    @MainActor
    private func refreshCurrentGlimmers() async {
        await refreshLatestGlimmers(showLoadingIndicator: glimmers.isEmpty)
    }

    @MainActor
    private func loadMoreGlimmers() async {
        guard !isLoadingMore, !isRefreshing else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await Glimmer.getPage(limit: glimmerPageSize, offset: glimmerOffset)
            try upsertLocalGlimmers(page.items)
            glimmers = try fetchLocalGlimmers()
            glimmerOffset += page.items.count
            hasMoreGlimmers = page.hasMore
            updateHasMoreGlimmersState(page.hasMore)
        } catch {
            let message = error.localizedDescription
            logger.error("loading more glimmers failed: \(message, privacy: .public)")
            feedbackMessage = message
        }
    }

    private func updateHasMoreGlimmersState(_ hasMore: Bool) {
        var syncState = SyncStateStore.state(userId: currentUserId)
        syncState.glimmers.hasMore = hasMore
        SyncStateStore.set(syncState, userId: currentUserId)
    }

    @MainActor
    private func fetchLocalGlimmers() throws -> [Glimmer] {
        try context.fetch(
            FetchDescriptor<Glimmer>(
                predicate: #Predicate<Glimmer> { $0.userId == currentUserId },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )
    }

    @MainActor
    private func upsertLocalGlimmers(_ remoteGlimmers: [Glimmer]) throws {
        let localGlimmers = try fetchLocalGlimmers()
        let localById = Dictionary(uniqueKeysWithValues: localGlimmers.map { ($0.id, $0) })

        for remote in remoteGlimmers {
            if let local = localById[remote.id] {
                local.status = remote.status
            } else {
                context.insert(remote)
            }
        }

        try context.save()
    }
}
