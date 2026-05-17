import SwiftUI

private enum TimelineBucket: Hashable {
    case today
    case yesterday
    case lastWeek
    case lastMonth
    case month(year: Int, month: Int)

    func title(calendar: Calendar, locale: Locale, now: Date = Date()) -> Text {
        switch self {
        case .today:
            return Text("glimmerHistory.section.today")
        case .yesterday:
            return Text("glimmerHistory.section.yesterday")
        case .lastWeek:
            return Text("glimmerHistory.section.pastWeek")
        case .lastMonth:
            return Text("glimmerHistory.section.pastMonth")
        case let .month(year, month):
            return Text(verbatim: Self.monthTitle(year: year, month: month, calendar: calendar, locale: locale, now: now))
        }
    }

    private static func monthTitle(year: Int, month: Int, calendar: Calendar, locale: Locale, now: Date) -> String {
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

    static func group(_ glimmers: [Glimmer], calendar: Calendar, now: Date = Date()) -> [TimelineSection] {
        var sections: [TimelineSection] = []
        var sectionIndices: [TimelineBucket: Int] = [:]

        for glimmer in glimmers {
            let bucket = TimelineBucket(date: glimmer.createdAt, calendar: calendar, now: now)
            if let sectionIndex = sectionIndices[bucket] {
                sections[sectionIndex].items.append(glimmer)
            } else {
                sectionIndices[bucket] = sections.count
                sections.append(TimelineSection(bucket: bucket, items: [glimmer]))
            }
        }

        return sections
    }
}

private extension TimelineBucket {
    init(date: Date, calendar: Calendar, now: Date) {
        if calendar.isDateInToday(date) {
            self = .today
            return
        }

        if calendar.isDateInYesterday(date) {
            self = .yesterday
            return
        }

        let startOfToday = calendar.startOfDay(for: now)
        if let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday), date >= oneWeekAgo {
            self = .lastWeek
            return
        }

        if let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: startOfToday), date >= oneMonthAgo {
            self = .lastMonth
            return
        }

        let comps = calendar.dateComponents([.year, .month], from: date)
        self = .month(year: comps.year ?? 0, month: comps.month ?? 1)
    }
}

struct GlimmerHistoryTimelineList: View {
    let glimmers: [Glimmer]
    let isRefreshing: Bool
    let isLoadingMore: Bool
    let hasMore: Bool
    let onLoadMore: () async -> Void
    let onRefresh: () async -> Void

    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale

    private var sections: [TimelineSection] {
        TimelineSection.group(glimmers, calendar: calendar)
    }

    var body: some View {
        ScrollView {
            if isRefreshing && sections.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 320)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            } else {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(sections) { section in
                        GlimmerHistoryTimelineSectionView(section: section, calendar: calendar, locale: locale)
                    }

                    loadMoreFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .refreshable {
            await onRefresh()
        }
    }

    @ViewBuilder
    private var loadMoreFooter: some View {
        if isLoadingMore {
            HStack(spacing: 8) {
                ProgressView()
                Text("common.loading")
                    .font(.footnote)
                    .foregroundStyle(UITheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
        } else if hasMore {
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

private struct GlimmerHistoryTimelineSectionView: View {
    let section: TimelineSection
    let calendar: Calendar
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            section.bucket.title(calendar: calendar, locale: locale)
                .font(.title3.weight(.medium))
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText.opacity(0.85))
                .padding(.horizontal, 6)
                .padding(.bottom, 2)

            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, glimmer in
                    NavigationLink(value: GlimmerHistoryRoute.glimmer(glimmer.id)) {
                        GlimmerListRow(glimmer: glimmer)
                    }
                    .buttonStyle(.plain)

                    if index < section.items.count - 1 {
                        GlimmerTimelineDivider()
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
}

private struct GlimmerTimelineDivider: View {
    var body: some View {
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
