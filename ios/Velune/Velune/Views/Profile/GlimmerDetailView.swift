import SwiftUI

struct GlimmerDetailView: View {
    let glimmer: Glimmer
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    @State private var showDeleteAlert = false
    @State private var isBreathing = false

    var body: some View {
        ZStack {
            BackgroundView()
            GlimmerBreathingGlow(isBreathing: isBreathing)
                .onAppear(perform: startBreathing)

            GlimmerDetailContent(glimmer: glimmer)
        }
        .navigationTitle(Text("glimmerHistory.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                actionMenu
            }
        }
        .alert("glimmer.delete.title", isPresented: $showDeleteAlert) {
            Button("glimmer.action.delete", role: .destructive) {
                deleteGlimmer()
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("glimmer.delete.message")
        }
    }

    private var actionMenu: some View {
        Menu {
            NavigationLink {
                GlimmerConversationHistoryView(glimmer: glimmer)
            } label: {
                Label("glimmerHistory.history.title", systemImage: "clock.arrow.circlepath")
            }

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("glimmer.action.delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18))
                .foregroundStyle(UITheme.primaryText)
        }
        .disabled(isDeleting)
    }

    private func startBreathing() {
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            isBreathing = true
        }
    }

    private func deleteGlimmer() {
        Task {
            isDeleting = true
            defer { isDeleting = false }

            do {
                try await Glimmer.delete(glimmer.id)
                onDelete()
                dismiss()
            } catch {
                // Preserve the existing silent failure behavior.
            }
        }
    }
}

private struct GlimmerBreathingGlow: View {
    let isBreathing: Bool

    var body: some View {
        RadialGradient(
            colors: [
                Color.white.opacity(isBreathing ? 0.06 : 0.03),
                Color.white.opacity(isBreathing ? 0.02 : 0.005),
                .clear
            ],
            center: .center,
            startRadius: 100,
            endRadius: 500
        )
        .ignoresSafeArea()
    }
}

private struct GlimmerDetailContent: View {
    let glimmer: Glimmer

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 28) {
                    Spacer()
                    GlimmerLetterCard(content: glimmer.content)
                    GlimmerDateBadge(date: glimmer.createdAt)
                    Spacer()
                }
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal, 22)
            }
        }
    }
}

private struct GlimmerLetterCard: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("“")
                .font(.system(size: 88, weight: .light, design: .serif))
                .foregroundStyle(Color.white.opacity(0.06))
                .frame(height: 24)
                .offset(x: -8, y: 16)

            Text(content)
                .font(.system(size: 17, weight: .light, design: .serif))
                .lineSpacing(10)
                .tracking(0.8)
                .foregroundStyle(UITheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

            HStack {
                Spacer()
                Text("”")
                    .font(.system(size: 88, weight: .light, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.06))
                    .frame(height: 24)
                    .offset(x: 8, y: -16)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .background(
            .ultraThinMaterial.opacity(0.22),
            in: .rect(cornerRadius: 24, style: .continuous)
        )
        .background {
            RadialGradient(
                colors: [Color.white.opacity(0.04), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 300
            )
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.04), .white.opacity(0.005)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(0.24), radius: 24, x: 0, y: 12)
    }
}

private struct GlimmerDateBadge: View {
    let date: Date

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 10))
            Text(date.formatted(date: .long, time: .shortened))
                .font(.system(size: 11, weight: .light, design: .serif))
                .tracking(1.0)
        }
        .foregroundStyle(UITheme.secondaryText.opacity(0.7))
        .padding(.vertical, 4)
    }
}
