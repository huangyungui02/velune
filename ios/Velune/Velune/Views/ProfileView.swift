import OSLog
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.calendar) private var calendar
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

            if authManager.isAnonymous {
                AppleSignInPromptCard(
                    icon: "person.crop.circle.badge.checkmark",
                    title: "anonymous.restricted.profile.title",
                    description: "anonymous.restricted.profile.description"
                )
            } else if !glimmers.isEmpty {
                glimmerListView
            } else {
                profileEmptyStateView
            }
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

    private var profileEmptyStateView: some View {
        SereneContentUnavailableView(
            title: "profile.empty.noGlimmers",
            symbol: "sparkles",
            subtitle: "profile.empty.noGlimmers.subtitle",
            actionTitle: "starsea.action.writeGlimmer",
            action: onOpenGlimmerComposer
        )
    }

    private var glimmerListView: some View {
        ScrollView {
            if isRefreshing && glimmers.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 320)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(timelineSections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            title(for: section.bucket)
                                .font(.title3.weight(.semibold))
                                .fontDesign(.rounded)
                                .foregroundStyle(UITheme.primaryText)
                                .padding(.horizontal, 6)
                                .padding(.bottom, 2)

                            VStack(spacing: 0) {
                                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, glimmer in
                                    NavigationLink {
                                        GlimmerView(glimmer: glimmer)
                                    } label: {
                                        GlimmerListRow(glimmer: glimmer)
                                    }
                                    .buttonStyle(.plain)

                                    if index < section.items.count - 1 {
                                        VStack(spacing: 8) {
                                            Divider()
                                                .overlay(.white.opacity(0.04))
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 6)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                            .background(Color.clear, in: .rect(cornerRadius: 18))
                            .glassEffect(in: .rect(cornerRadius: 18))
                        }
                    }

                    if isLoadingMore {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("common.loading")
                                .font(.footnote)
                                .foregroundStyle(UITheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                    } else if hasMoreGlimmers {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                Task {
                                    await loadMoreGlimmers()
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .refreshable {
            await refreshLatestGlimmers(showLoadingIndicator: glimmers.isEmpty)
        }
    }

    private var feedbackAlertBinding: Binding<Bool> {
        Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )
    }

    private var timelineSections: [TimelineSection] {
        var sections: [TimelineSection] = []
        var sectionIndices: [TimelineBucket: Int] = [:]
        let now = Date()

        for glimmer in glimmers {
            let bucket = bucket(for: glimmer.createdAt, now: now)
            if let sectionIndex = sectionIndices[bucket] {
                sections[sectionIndex].items.append(glimmer)
            } else {
                sectionIndices[bucket] = sections.count
                sections.append(TimelineSection(bucket: bucket, items: [glimmer]))
            }
        }

        return sections
    }

    private func bucket(for date: Date, now: Date) -> TimelineBucket {
        if calendar.isDateInToday(date) {
            return .today
        }
        if calendar.isDateInYesterday(date) {
            return .yesterday
        }

        let startOfToday = calendar.startOfDay(for: now)
        if let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday), date >= oneWeekAgo {
            return .lastWeek
        }
        if let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: startOfToday), date >= oneMonthAgo {
            return .lastMonth
        }

        let comps = calendar.dateComponents([.year, .month], from: date)
        return .month(year: comps.year ?? 0, month: comps.month ?? 1)
    }

    private func title(for bucket: TimelineBucket) -> Text {
        switch bucket {
        case .today:
            return Text("profile.section.today")
        case .yesterday:
            return Text("profile.section.yesterday")
        case .lastWeek:
            return Text("profile.section.pastWeek")
        case .lastMonth:
            return Text("profile.section.pastMonth")
        case let .month(year, month):
            return Text(verbatim: monthTitle(year: year, month: month))
        }
    }

    private func monthTitle(year: Int, month: Int) -> String {
        let now = Date()
        let currentYear = calendar.component(.year, from: now)

        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1

        guard let date = calendar.date(from: comps) else {
            return "\(year)-\(month)"
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(year == currentYear ? "MMMM" : "yMMMM")
        return formatter.string(from: date)
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

// MARK: - Timeline

private enum TimelineBucket: Hashable {
    case today
    case yesterday
    case lastWeek
    case lastMonth
    case month(year: Int, month: Int)
}

private struct TimelineSection: Identifiable {
    let bucket: TimelineBucket
    var items: [Glimmer]

    var id: String {
        switch bucket {
        case .today:
            return "today"
        case .yesterday:
            return "yesterday"
        case .lastWeek:
            return "lastWeek"
        case .lastMonth:
            return "lastMonth"
        case let .month(year, month):
            return "\(year)-\(month)"
        }
    }
}

// MARK: - Row

private struct GlimmerListRow: View {
    let glimmer: Glimmer
    @Environment(\.locale) private var locale

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(UITheme.tertiaryText)
                Text(glimmer.createdAt, format: .relative(presentation: .named).locale(locale))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(UITheme.tertiaryText)
                Spacer()
            }

            Text(glimmer.content)
                .font(.body)
                .fontDesign(.serif)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .lineSpacing(6)
                .foregroundStyle(UITheme.primaryText)
        }
    }
}
