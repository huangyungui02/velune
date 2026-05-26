import SwiftUI

struct StarSeaSettlementSummaryCard: View {
    let text: String
    let isSaving: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onSave: () -> Void

    private var canSave: Bool {
        !isSaving && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(UITheme.primaryText.opacity(0.9))
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.08), in: .circle)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("starsea.settlement.title")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(UITheme.primaryText)

                        Text(text)
                            .font(.footnote)
                            .lineSpacing(4)
                            .foregroundStyle(UITheme.secondaryText.opacity(0.72))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Image(systemName: "chevron.up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(UITheme.primaryText.opacity(0.34))
                        .padding(.top, 9)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            actions
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.03, green: 0.035, blue: 0.055).opacity(0.64), in: .rect(cornerRadius: 22))
        .glassEffect(in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.42), radius: 24, y: 10)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: onEdit) {
                Label("starsea.settlement.edit", systemImage: "pencil")
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(UITheme.primaryText)
            .disabled(isSaving)

            Spacer()

            Button(action: onSave) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "checkmark")
                    }

                    Text("starsea.settlement.save")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(.white, in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
        }
    }
}

struct StarSeaSettlementSheet: View {
    @Binding var text: String
    @Binding var isEditing: Bool
    let isSaving: Bool
    let isEditorFocused: FocusState<Bool>.Binding
    let onExit: () -> Void
    let onEdit: () -> Void
    let onSave: () -> Void

    private var canSave: Bool {
        !isSaving && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StarryBackgroundView()
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("starsea.settlement.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("starsea.settlement.exit", action: onExit)
                        .disabled(isSaving)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onSave) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("starsea.settlement.save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var content: some View {
        ZStack {
            TextEditor(text: $text)
                .focused(isEditorFocused)
                .disabled(!isEditing || isSaving)
                .font(.body)
                .lineSpacing(7)
                .foregroundStyle(UITheme.primaryText)
                .tint(UITheme.primaryText)
                .scrollContentBackground(.hidden)
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(0.05), in: .rect(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 0.5)
                }
                .accessibilityLabel(Text("starsea.settlement.editor"))

            if !isEditing {
                Button(action: onEdit) {
                    Color.clear
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }
}
