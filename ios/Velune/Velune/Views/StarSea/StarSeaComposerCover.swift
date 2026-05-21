import SwiftUI

struct StarSeaComposerCover: View {
    @Binding var text: String
    let onDismiss: () -> Void
    let onDone: () -> Void
    @FocusState private var isEditorFocused: Bool

    private var canFinish: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var placeholderText: String {
        String(localized: "starsea.prompt.glimmerWithin")
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                StarryBackgroundView()
                    .ignoresSafeArea()

                editor
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 18)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leadingButton
                }

                ToolbarItem(placement: .topBarTrailing) {
                    sendButton
                }
            }
            .toolbar(.hidden, for: .tabBar)
        }
        .presentationBackground(.clear)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                isEditorFocused = true
            }
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                GlimmerCardText(placeholderText, foregroundStyle: UITheme.primaryText.opacity(0.42))
                    .padding(.top, 8)
                    .padding(.horizontal, 5)
                    .transition(.opacity)
            }

            TextEditor(text: $text)
                .focused($isEditorFocused)
                .font(.body)
                .fontDesign(.serif)
                .lineSpacing(8)
                .tracking(0.5)
                .foregroundStyle(UITheme.primaryText)
                .tint(UITheme.primaryText)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .contentMargins(0, for: .scrollContent)
                .background(.clear)
                .submitLabel(.done)
                .onSubmit {
                    if canFinish {
                        onDone()
                    }
                }
                .accessibilityLabel(Text("starsea.prompt.glimmerWithin"))
        }
    }

    private var leadingButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "chevron.down")
                .font(.body.weight(.medium))
        }
        .accessibilityLabel(Text("common.cancel"))
    }

    private var sendButton: some View {
        Button(action: onDone) {
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
        }
        .disabled(!canFinish)
        .accessibilityLabel(Text("common.done"))
    }
}
