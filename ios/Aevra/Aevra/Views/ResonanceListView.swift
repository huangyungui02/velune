import SwiftUI

struct ResonanceListView: View {
    @State private var resonances: [Resonance] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            BackgroundView()

            Group {
                if isLoading, resonances.isEmpty {
                    ProgressView(String(localized: "common.loading"))
                        .tint(UITheme.accent)
                } else if resonances.isEmpty {
                    if let errorMessage {
                        loadFailedView(message: errorMessage)
                    } else {
                        EmptyView(title: String(localized: "resonance.empty"))
                    }
                } else {
                    resonanceListView
                }
            }
        }
        .navigationTitle(String(localized: "resonance.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await refreshResonances(force: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task {
            await refreshResonances(force: false)
        }
    }

    private var resonanceListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(resonances) { resonance in
                    NavigationLink {
                        SoulerView(soulerId: resonance.soulerId)
                    } label: {
                        ResonanceListCard(resonance: resonance)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private func loadFailedView(message: String) -> some View {
        VStack(spacing: 12) {
            Text(String(localized: "resonance.load.failed"))
                .font(.system(size: 21, weight: .medium, design: .rounded))
                .fontWeight(.semibold)
                .foregroundStyle(UITheme.primaryText)

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(UITheme.secondaryText)
                .multilineTextAlignment(.center)

            Button(String(localized: "common.retry")) {
                Task {
                    await refreshResonances(force: true)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @MainActor
    private func refreshResonances(force: Bool) async {
        if isLoading { return }
        if !force, !resonances.isEmpty { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            resonances = try await Resonance.getAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ResonanceListCard: View {
    let resonance: Resonance

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(resonance.soulerName)
                        .font(UITheme.literary(size: 20, weight: .semibold))
                        .foregroundStyle(UITheme.primaryText)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text("\(resonance.count)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(UITheme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.10), in: .capsule)
                }

                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(UITheme.tertiaryText)

                    Text(resonance.updatedAt.formatted(.relative(presentation: .named)))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(UITheme.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(.rect)
    }
}

#Preview {
    NavigationStack {
        ResonanceListView()
    }
}
