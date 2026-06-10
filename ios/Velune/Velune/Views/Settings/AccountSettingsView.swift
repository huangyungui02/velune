import SwiftData
import SwiftUI

struct AccountSettingsView: View {
    @State private var authManager = AuthManager.shared
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isUpdatingName = false
    @State private var feedbackMessage: String?
    @State private var editingName: String = ""
    @AppStorage(StarSeaMemoryPreference.key) private var isStarSeaMemoryEnabled = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            BackgroundView()

            List {
                Section {
                    LabeledContent {
                        HStack(spacing: 8) {
                            TextField("settings.account.defaultName", text: $editingName)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.primary)
                                .onSubmit {
                                    Task { await updateName() }
                                }
                                .submitLabel(.done)
                                .disabled(isUpdatingName)

                            if isUpdatingName {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.tertiary)
                                    .font(.subheadline)
                            }
                        }
                    } label: {
                        settingsRowLabel("settings.account.name", systemImage: "person")
                    }

                    LabeledContent {
                        Text(authManager.userEmail ?? "--")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } label: {
                        settingsRowLabel("settings.account.email", systemImage: "envelope")
                    }
                } header: {
                    sectionHeader("settings.section.profile")
                }

                Section {
                    Toggle(isOn: $isStarSeaMemoryEnabled) {
                        settingsRowLabel("settings.preference.memory", systemImage: "brain")
                    }
                    .toggleStyle(.switch)
                    .tint(.white.opacity(0.45))
                    .padding(.vertical, 3)
                } header: {
                    sectionHeader("settings.section.preferences")
                }

                Section {
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 10) {
                            settingsRowLabel("settings.action.deleteAccount", systemImage: "trash")
                            Spacer(minLength: 0)
                            if isDeleting {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .disabled(isDeleting)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .environment(\.defaultMinListRowHeight, 50)
            .modifier(SettingsListChrome())
        }
        .navigationTitle("settings.account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            editingName = authManager.userName ?? String(
                localized: "settings.account.defaultName",
                defaultValue: "Soul Traveler"
            )
        }
        .alert("settings.delete.confirm.title", isPresented: $showDeleteConfirmation) {
            Button("settings.action.deleteAccount", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.delete.confirm.message")
        }
        .alert("settings.error.title", isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
        }
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .textCase(nil)
            .foregroundStyle(UITheme.tertiaryText)
    }

    private func updateName() async {
        guard !editingName.isEmpty, editingName != authManager.userName else { return }
        isUpdatingName = true
        defer { isUpdatingName = false }

        do {
            try await authManager.updateUserName(editingName)
        } catch {
            feedbackMessage = error.localizedDescription
            editingName = authManager.userName ?? String(
                localized: "settings.account.defaultName",
                defaultValue: "Soul Traveler"
            )
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            let userId = AuthManager.shared.currentUserId?.uuidString
            try await AuthManager.shared.deleteAccount()
            SyncStateStore.clear(userId: userId)
            if let userId {
                try Resonance.clearCached(userId: userId, context: modelContext)
                try ChatSession.clearCached(userId: userId, context: modelContext)
                try Message.clearCached(userId: userId, context: modelContext)
            }
            try modelContext.delete(model: Glimmer.self)
            dismiss()
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }
}
