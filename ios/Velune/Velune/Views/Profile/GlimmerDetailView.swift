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
                    GlimmerCardView(content: glimmer.content)
                    GlimmerDateBadge(date: glimmer.createdAt)
                    Spacer()
                }
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal, 22)
            }
        }
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
