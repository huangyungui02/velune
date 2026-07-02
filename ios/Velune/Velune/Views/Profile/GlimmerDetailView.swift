import SwiftUI

struct GlimmerDetailView: View {
    let glimmer: Glimmer
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            BackgroundView()

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

private struct GlimmerDetailContent: View {
    let glimmer: Glimmer

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 28) {
                    GlimmerCardView(content: glimmer.content)
                    GlimmerDateBadge(date: glimmer.createdAt)
                }
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal, 22)
                .padding(.vertical, 32)
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
