import SwiftUI

struct GlimmerRecordsView: View {
    @State private var glimmers: [Glimmer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            BackgroundView()

            if isLoading && glimmers.isEmpty {
                ProgressView("common.loading")
                    .tint(UITheme.primaryText)
            } else if glimmers.isEmpty {
                ContentUnavailableView(
                    "glimmerHistory.empty.noGlimmers",
                    systemImage: "sparkles"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        ForEach(glimmerSections) { section in
                            GlimmerDaySection(section: section) { glimmer, isFeatured in
                                NavigationLink(value: ProfileRoute.glimmerDetail(id: glimmer.id)) {
                                    GlimmerTimelineRow(glimmer: glimmer, isFeatured: isFeatured)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 24)
                    .padding(.bottom, 108)
                }
                .refreshable {
                    refreshGlimmers()
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ProfileRoute.self) { route in
            switch route {
            case .settings:
                SettingsView()
            case .glimmerDetail(let id):
                if let glimmer = glimmers.first(where: { $0.id == id }) {
                    GlimmerDetailView(glimmer: glimmer) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            glimmers.removeAll { $0.id == id }
                        }
                    }
                }
            }
        }
        .alert("matching.error.title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("common.retry") {
                Task { await loadGlimmers() }
            }
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "matching.error.unknown"))
        }
        .task {
            await loadGlimmers()
        }
    }

    private var glimmerSections: [GlimmerDayGroup] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: glimmers) { glimmer in
            calendar.startOfDay(for: glimmer.createdAt)
        }

        return groups
            .map { day, glimmers in
                GlimmerDayGroup(
                    day: day,
                    glimmers: glimmers.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.day > $1.day }
    }

    private func refreshGlimmers() {
        Task {
            await loadGlimmers()
        }
    }

    private func loadGlimmers() async {
        if isLoading { return }

        isLoading = true
        defer { isLoading = false }

        errorMessage = nil
        do {
            glimmers = try await Glimmer.getAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct GlimmerDayGroup: Identifiable {
    let day: Date
    let glimmers: [Glimmer]

    var id: Date { day }
}
