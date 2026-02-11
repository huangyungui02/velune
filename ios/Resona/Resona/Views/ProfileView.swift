import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Inspiration.createdAt, order: .reverse) private var inspirations: [Inspiration]
    @State private var isRefreshing: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()

                Group {
                    if isRefreshing {
                        ProgressView()
                    }
                    if inspirations.isEmpty {
                        EmptyView(title: "No glimmers yet")
                    } else {
                        inspirationListView
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
                await refreshInspirations()
            }
        }
    }

    private var inspirationListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(inspirations) { inspiration in
                    NavigationLink {
                        InspirationDetailView(inspiration: inspiration)
                    } label: {
                        InspirationCard(inspiration: inspiration)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    @MainActor
    func refreshInspirations() async {
        if !inspirations.isEmpty { return }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let inspirationsData = try await Inspiration.getAll()
            for (idx, inspiration) in inspirationsData.enumerated() {
                context.insert(inspiration)
                if idx > 0, idx % 200 == 0 {
                    await Task.yield()
                }
            }
            try context.save()
        } catch {
            let errorMessage = error.localizedDescription
            print("error refreshing inspirations: \(errorMessage)")
        }
    }
}

// MARK: - Inspiration Card

private struct InspirationCard: View {
    let inspiration: Inspiration

    var body: some View {
        CardView {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(UITheme.labelFont)
                    .foregroundStyle(UITheme.tertiaryText)
                Text(inspiration.createdAt, format: .relative(presentation: .named))
                    .font(UITheme.labelFont)
                    .foregroundStyle(UITheme.tertiaryText)
                Spacer()
            }

            Text(inspiration.content)
                .font(UITheme.bodyFont)
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
