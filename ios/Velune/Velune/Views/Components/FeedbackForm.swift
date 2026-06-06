import SwiftUI

struct FeedbackForm: View {
    let title: LocalizedStringKey
    let prompt: LocalizedStringKey
    let placeholder: LocalizedStringKey
    
    // Optional Souler details for Souler-specific feedback
    var headerName: String? = nil
    var headerImageURL: URL? = nil
    
    // Async action to submit content
    let onSubmit: (String) async throws -> Void
    // Success callback
    let onSubmitted: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isEditorFocused: Bool
    
    @State private var content = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    private let maxCharCount = 1000
    
    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isSubmitDisabled: Bool {
        trimmedContent.isEmpty || content.count > maxCharCount || isSubmitting
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()
                
                VStack(alignment: .leading, spacing: 24) {
                    // Seamless, Borderless Header
                    headerView
                    
                    // Transparent Editor Area
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $content)
                            .font(.system(.body, design: .serif))
                            .lineSpacing(6)
                            .scrollContentBackground(.hidden)
                            .focused($isEditorFocused)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        if content.isEmpty {
                            Text(placeholder)
                                .font(.system(.body, design: .serif))
                                .foregroundStyle(UITheme.tertiaryText)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    
                    // Error message
                    if let errorMessage {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.red.opacity(0.8))
                                .padding(.top, 2)
                            
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red.opacity(0.8))
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                    }
                    
                    // Footer: Divider & Character Count
                    VStack(spacing: 12) {
                        Divider()
                            .background(Color.white.opacity(0.06))
                        
                        HStack {
                            if !content.isEmpty {
                                Button(action: { content = "" }) {
                                    Text("common.clear")
                                        .font(.system(.footnote, design: .serif))
                                        .foregroundStyle(UITheme.tertiaryText)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                            
                            Text("\(content.count) / \(maxCharCount)")
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundStyle(content.count > maxCharCount ? Color.red.opacity(0.8) : UITheme.tertiaryText)
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("common.cancel")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(UITheme.secondaryText)
                    }
                    .disabled(isSubmitting)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("common.submit")
                                .font(.system(.body, design: .serif))
                                .fontWeight(.medium)
                                .foregroundStyle(isSubmitDisabled ? UITheme.tertiaryText : UITheme.primaryText)
                        }
                    }
                    .disabled(isSubmitDisabled)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let headerName {
                Text(headerName)
                    .font(.system(.footnote, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(UITheme.tertiaryText)
                    .textCase(.uppercase)
            }
            
            Text(prompt)
                .font(.system(.body, design: .serif))
                .italic()
                .foregroundStyle(UITheme.secondaryText)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Actions
    
    private func submit() {
        Task {
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }
            
            do {
                try await onSubmit(trimmedContent)
                onSubmitted()
                dismiss()
            } catch {
                withAnimation(.easeOut(duration: 0.25)) {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
