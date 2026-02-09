import SwiftData
import SwiftUI

struct InspirationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showingDeleteAlert = false
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var inspiration: Inspiration
    @State private var currentPage: CardID? = .soulFragment

    init(inspiration: Inspiration) {
        self.inspiration = inspiration
    }

    private var echoes: [Echo] {
        inspiration.echoes
    }

    private var hasEchoes: Bool { !echoes.isEmpty }

    var body: some View {
        ZStack {
            BackgroundView()

            VStack {
                cardPagerView

                if isLoading {
                    ProgressView()
                }

                Spacer()

                indicatorView
            }
        }
        .navigationTitle("Soul Fragment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .disabled(isDeleting)
            }
        }
        .alert("Delete", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    let success = await deleteInspiration()
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this? This action can’t be undone.")
        }
        .overlay {
            if isDeleting {
                ProgressView("Deleting…")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
        .task {
            await refreshInspiration()
        }
    }

    func deleteInspiration() async -> Bool {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await Inspiration.delete(inspiration.id)
            context.delete(inspiration)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshInspiration() async {
        if inspiration.status == "complete" {
            if !inspiration.echoes.isEmpty { return }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let newInspiration = try await Inspiration.get(inspiration.id)
            let echoes = try await Echo.getAll(newInspiration.id)
            newInspiration.echoes = echoes
            inspiration.update(from: newInspiration)
        } catch {
            print("Failed to refresh inspiration \(inspiration.id): \(error)")
            return
        }
    }

    @ViewBuilder
    private var cardPagerView: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                soulFragmentCard
                    .containerRelativeFrame(.horizontal)
                    .id(CardID.soulFragment)

                ForEach(echoes) { echo in
                    InspirationEchoCardView(echo: echo)
                        .containerRelativeFrame(.horizontal)
                        .id(CardID.echo(echo.id))
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentPage)
        .scrollIndicators(.hidden)
    }

    private var soulFragmentCard: some View {
        PremiumCardView(iconName: "sparkles", title: "Soul Fragment") {
            VStack(spacing: 16) {
                Text(inspiration.content)
                    .font(.body)
                    .lineSpacing(6)
                    .foregroundStyle(.white)

                Divider()
                    .background(.white.opacity(0.2))

                HStack {
                    Spacer()

                    Text(
                        inspiration.createdAt.formatted(
                            .dateTime
                                .year()
                                .month()
                                .day()
                                .hour()
                                .minute()
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(1.5)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var indicatorView: some View {
        HStack(spacing: 8) {
            if hasEchoes {
                HStack(spacing: 8) {
                    Button {
                        withAnimation {
                            currentPage = .soulFragment
                        }
                    } label: {
                        Image(systemName: "sparkle")
                            .font(.caption2)
                            .foregroundStyle(currentPage == .soulFragment ? .white : .white.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .scaleEffect(currentPage == .soulFragment ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                    .buttonStyle(.plain)

                    ForEach(echoes) { echo in
                        Circle()
                            .fill(currentPage == .echo(echo.id) ? .white : .white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == .echo(echo.id) ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding()
                .glassEffect()
            }
        }
    }
}

private enum CardID: Hashable {
    case soulFragment
    case echo(UUID)
}

private struct InspirationEchoCardView: View {
    let echo: Echo

    var body: some View {
        PremiumCardView(iconName: "circle.circle", title: "Echo") {
            VStack(alignment: .leading, spacing: 16) {
                Text(echo.content)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(6)
                    .foregroundStyle(.white)

                Divider()
                    .background(.white.opacity(0.3))

                NavigationLink {
                    SoulerView(soulerId: echo.soulerId)
                } label: {
                    HStack(spacing: 8) {
                        Spacer()

                        Text(echo.soulerName)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    let inspiration = Inspiration.sampleData[0]
    NavigationStack {
        InspirationDetailView(inspiration: inspiration)
            .sampleDataContainer()
    }
}
