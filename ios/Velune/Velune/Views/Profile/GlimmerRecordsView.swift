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
                                NavigationLink {
                                    GlimmerDetailView(glimmer: glimmer) {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            glimmers.removeAll { $0.id == glimmer.id }
                                        }
                                    }
                                } label: {
                                    GlimmerTimelineRow(glimmer: glimmer, isFeatured: isFeatured)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 108)
                }
                .refreshable {
                    await loadGlimmers()
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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

    private func loadGlimmers() async {
        isLoading = true
        defer { isLoading = false }

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
