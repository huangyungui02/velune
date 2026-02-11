import Supabase
import SwiftData
import SwiftUI

struct SeaStarView: View {
    @Environment(\.modelContext) private var context
    @State private var text = ""
    @State private var isNavigatingToMatching = false
    @State private var isPresented = false
    @State private var manager = MatchingManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                StarryBackgroundView()

                VStack {
                    Spacer()

                    DescriptionView(title: "Return to yourself", description: "The softest romance is becoming.")

                    Spacer()

                    magicButtonView
                        .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Image(systemName: "house.fill")
                    }
                }
            }
            .navigationDestination(isPresented: $isNavigatingToMatching) {
                MatchingView()
            }
            .fullScreenCover(isPresented: $isPresented) {
                ComposeView(text: $text, onSend: send)
            }
        }
    }

    private var magicButtonView: some View {
        Group {
            if manager.isMatching {
                HStack(spacing: 12) {
                    MatchingWaveIcon()

                    Text("Listening for echoes…")
                        .font(UITheme.labelFont)
                        .foregroundStyle(UITheme.secondaryText)
                }
                .padding(16)
                .glassEffect(in: .capsule)
            } else if text.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")

                    Text("What glimmers within you")
                        .font(UITheme.sectionFont)
                        .foregroundStyle(UITheme.primaryText)
                }
                .padding(16)
                .glassEffect(in: .capsule)
            } else {
                ScrollView {
                    Text(text)
                        .font(UITheme.bodyFont)
                        .foregroundStyle(UITheme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .fixedSize(horizontal: false, vertical: false)
                }
                .frame(maxWidth: .infinity, maxHeight: 150)
                .glassEffect(in: .rect(cornerRadius: 20))
            }
        }
        .onTapGesture {
            if manager.isMatching {
                isNavigatingToMatching = true
            } else {
                isPresented = true
            }
        }
    }

    // MARK: - Actions

    private func send() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        manager.startMatching(text: text, context: context)
        text = ""
        isNavigatingToMatching = true
    }
}

// MARK: - Description View

private struct DescriptionView: View {
    let title: String
    let description: String

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 8) {
                Text(title)
                    .font(UITheme.titleFont)
                    .foregroundStyle(UITheme.primaryText)

                Text(description)
                    .font(UITheme.bodyFont)
                    .foregroundStyle(UITheme.secondaryText)
                    .tracking(2)
            }

            Spacer()
        }
    }
}

// MARK: - Compose View

private struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                    TextField("What glimmers within you", text: $text, axis: .vertical)
                    .focused($isFocused)
                    .font(UITheme.bodyFont)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(white: 0.06),
                        Color(white: 0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Glimmer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(UITheme.sectionFont)
                            .foregroundStyle(UITheme.secondaryText)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        onSend()
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(UITheme.sectionFont)
                            .fontWeight(.semibold)
                            .foregroundStyle(UITheme.primaryText)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.3 : 1)
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    SeaStarView()
}
