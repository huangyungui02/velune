import SwiftUI

struct GlimmerRecordsView: View {
    @State private var glimmers: [Glimmer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            BackgroundView()

            if isLoading, glimmers.isEmpty {
                ProgressView("common.loading")
                    .tint(UITheme.primaryText)
            } else if glimmers.isEmpty {
                ContentUnavailableView(
                    "glimmerHistory.empty.noGlimmers",
                    systemImage: "sparkles",
                    description: Text("glimmerHistory.empty.noGlimmers.subtitle")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(glimmers) { glimmer in
                            GlimmerRecordCard(glimmer: glimmer)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await loadGlimmers()
                }
            }
        }
        .navigationTitle(Text("glimmerHistory.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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

private struct GlimmerRecordCard: View {
    let glimmer: Glimmer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(glimmer.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .fontDesign(.serif)
                .foregroundStyle(UITheme.secondaryText)

            Text(glimmer.content)
                .font(.body)
                .fontDesign(.serif)
                .lineSpacing(6)
                .foregroundStyle(UITheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}
