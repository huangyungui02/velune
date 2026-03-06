import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Query(sort: \Glimmer.createdAt, order: .reverse) private var glimmers: [Glimmer]
    @State private var isRefreshing: Bool = false

    var body: some View {
        ZStack {
            BackgroundView()

            Group {
                if isRefreshing {
                    ProgressView()
                } else if glimmers.isEmpty {
                    EmptyView(title: "profile.empty.noGlimmers")
                } else {
                    glimmerListView
                }
            }
        }
        .navigationTitle("profile.title.glimmers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .task {
            await refreshGlimmers()
        }
    }

    private var glimmerListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(timelineSections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(title(for: section.bucket))
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
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

    private func title(for bucket: TimelineBucket) -> String {
        switch bucket {
        case .today:
            return String(localized: "profile.section.today")
        case .yesterday:
            return String(localized: "profile.section.yesterday")
        case .lastWeek:
            return String(localized: "profile.section.pastWeek")
        case .lastMonth:
            return String(localized: "profile.section.pastMonth")
        case let .month(year, month):
            return monthTitle(year: year, month: month)
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
    func refreshGlimmers() async {
        if !glimmers.isEmpty { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let glimmersData = try await Glimmer.getAll()
            for (idx, glimmer) in glimmersData.enumerated() {
                context.insert(glimmer)
                if idx > 0, idx % 200 == 0 {
                    await Task.yield()
                }
            }
            try context.save()
        } catch {
            let errorMessage = error.localizedDescription
            print("error refreshing glimmers: \(errorMessage)")
        }
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
                Text(glimmer.createdAt, format: .relative(presentation: .named))
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

#Preview {
    ProfileView()
        .sampleDataContainer()
}
