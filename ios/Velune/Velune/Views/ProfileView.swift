import OSLog
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @State private var authManager = AuthManager.shared
    @State private var stirrings: [Stirring] = []
    @State private var isRefreshing: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var hasMoreStirrings: Bool = false
    @State private var stirringOffset: Int = 0
    @State private var feedbackMessage: String?
    let onOpenStirringComposer: () -> Void

    private let stirringPageSize = 10
    private let logger = AppLogger.profile

    init(onOpenStirringComposer: @escaping () -> Void = {}) {
        self.onOpenStirringComposer = onOpenStirringComposer
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
            } else if !stirrings.isEmpty {
                stirringListView
            } else {
                profileEmptyStateView
            }
        }
        .navigationTitle("profile.title.stirrings")
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
                stirrings = []
                isRefreshing = false
                isLoadingMore = false
                hasMoreStirrings = false
                stirringOffset = 0
                return
            }
            loadLocalStirrings()
            stirringOffset = stirrings.count
            hasMoreStirrings = SyncStateStore.state(userId: currentUserId).stirrings.hasMore

            if hasMoreStirrings && stirrings.isEmpty {
                await loadMoreStirrings()
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
            title: "profile.empty.noStirrings",
            symbol: "sparkles",
            subtitle: "profile.empty.noStirrings.subtitle",
            actionTitle: "starsea.action.writeStirring",
            action: onOpenStirringComposer
        )
    }

    private var stirringListView: some View {
        ScrollView {
            if isRefreshing && stirrings.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 320)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(timelineSections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            title(for: section.bucket)
                                .font(.title3.weight(.medium))
                                .fontDesign(.serif)
                                .foregroundStyle(UITheme.primaryText.opacity(0.85))
                                .padding(.horizontal, 6)
                                .padding(.bottom, 2)

                            VStack(spacing: 0) {
                                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, stirring in
                                    NavigationLink {
                                        StirringView(stirring: stirring)
                                    } label: {
                                        StirringListRow(stirring: stirring)
                                    }
                                    .buttonStyle(.plain)

                                    if index < section.items.count - 1 {
                                        VStack(spacing: 8) {
                                            Rectangle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.clear, .white.opacity(0.06), .clear],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(height: 1)
                                        }
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 6)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color.white.opacity(0.035))
                                    .shadow(color: .white.opacity(0.035), radius: 30, x: 0, y: 0)
                            )
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
                    } else if hasMoreStirrings {
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                Task {
                                    await loadMoreStirrings()
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
            await refreshLatestStirrings(showLoadingIndicator: stirrings.isEmpty)
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

        for stirring in stirrings {
            let bucket = bucket(for: stirring.createdAt, now: now)
            if let sectionIndex = sectionIndices[bucket] {
                sections[sectionIndex].items.append(stirring)
            } else {
                sectionIndices[bucket] = sections.count
                sections.append(TimelineSection(bucket: bucket, items: [stirring]))
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
    private func loadLocalStirrings() {
        do {
            stirrings = try fetchLocalStirrings()
        } catch {
            let message = error.localizedDescription
            logger.error("local stirring load failed: \(message, privacy: .public)")
            feedbackMessage = message
        }
    }

    @MainActor
    private func refreshLatestStirrings(showLoadingIndicator: Bool) async {
        guard !isRefreshing else { return }

        isRefreshing = showLoadingIndicator

        do {
            let page = try await Stirring.getPage(limit: stirringPageSize, offset: 0)
            try upsertLocalStirrings(page.items)
            stirrings = try fetchLocalStirrings()
            stirringOffset = stirrings.count
            hasMoreStirrings = page.hasMore
            updateHasMoreStirringsState(page.hasMore)
        } catch {
            let errorMessage = error.localizedDescription
            logger.error("stirring refresh failed: \(errorMessage, privacy: .public)")
            feedbackMessage = errorMessage
        }

        isRefreshing = false
    }

    @MainActor
    private func loadMoreStirrings() async {
        guard !isLoadingMore, !isRefreshing else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await Stirring.getPage(limit: stirringPageSize, offset: stirringOffset)
            try upsertLocalStirrings(page.items)
            stirrings = try fetchLocalStirrings()
            stirringOffset += page.items.count
            hasMoreStirrings = page.hasMore
            updateHasMoreStirringsState(page.hasMore)
        } catch {
            let message = error.localizedDescription
            logger.error("loading more stirrings failed: \(message, privacy: .public)")
            feedbackMessage = message
        }
    }

    private func updateHasMoreStirringsState(_ hasMore: Bool) {
        var syncState = SyncStateStore.state(userId: currentUserId)
        syncState.stirrings.hasMore = hasMore
        SyncStateStore.set(syncState, userId: currentUserId)
    }

    @MainActor
    private func fetchLocalStirrings() throws -> [Stirring] {
        try context.fetch(
            FetchDescriptor<Stirring>(
                predicate: #Predicate<Stirring> { $0.userId == currentUserId },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )
    }

    @MainActor
    private func upsertLocalStirrings(_ remoteStirrings: [Stirring]) throws {
        let localStirrings = try fetchLocalStirrings()
        let localById = Dictionary(uniqueKeysWithValues: localStirrings.map { ($0.id, $0) })

        for remote in remoteStirrings {
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
    var items: [Stirring]

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

private struct StirringListRow: View {
    let stirring: Stirring
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
                Text(stirring.createdAt, format: .relative(presentation: .named).locale(locale))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(UITheme.tertiaryText)
                Spacer()
            }

            Text(stirring.content)
                .font(.body)
                .fontDesign(.serif)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .lineSpacing(6)
                .foregroundStyle(UITheme.primaryText)
        }
    }
}
