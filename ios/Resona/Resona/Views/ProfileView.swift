import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Glimmer.createdAt, order: .reverse) private var glimmers: [Glimmer]
    @State private var isRefreshing: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()

                Group {
                    if isRefreshing {
                        ProgressView()
                    }
                    if glimmers.isEmpty {
                        EmptyView(title: "No glimmers yet")
                    } else {
                        glimmerListView
                    }
                }
            }
            .navigationTitle("Glimmers")
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
    }

    private var glimmerListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(glimmers) { glimmer in
                    NavigationLink {
                        GlimmerDetailView(glimmer: glimmer)
                    } label: {
                        GlimmerListCard(glimmer: glimmer)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
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

// MARK: - Glimmer Card

private struct GlimmerListCard: View {
    let glimmer: Glimmer

    var body: some View {
        CardView {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(UITheme.tertiaryText)
                Text(glimmer.createdAt, format: .relative(presentation: .named))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(UITheme.tertiaryText)
                Spacer()
            }

            Text(glimmer.content)
                .font(.system(size: 18, weight: .regular, design: .serif))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .foregroundStyle(UITheme.primaryText)
        }
    }
}

#Preview {
    ProfileView()
        .sampleDataContainer()
}
