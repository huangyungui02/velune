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

                    VerseView(textKey: "seastar.hero.verse")

                    Spacer()

                    magicButtonView
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ResonanceView()
                    } label: {
                        Image(systemName: "waveform.path.ecg")
                    }
                    .accessibilityLabel(Text("seastar.action.resonances"))
                }

                ToolbarItem(placement: .topBarLeading) {
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

                    Text("matching.status.listening")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(UITheme.secondaryText)
                        .tracking(2)
                }
                .padding()
                .glassEffect(in: .capsule)
            } else if text.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")

                    Text("seastar.prompt.glimmerWithin")
                        .foregroundStyle(UITheme.primaryText)
                        .font(.body)
                        .fontDesign(.serif)
                }
                .padding()
                .glassEffect(in: .capsule)
            } else {
                draftPreviewField
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 20))
                    .contentShape(.rect)
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            isPresented = true
                        }
                    )
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

    private var draftPreviewField: some View {
        TextField("", text: .constant(text), axis: .vertical)
            .font(.body)
            .fontDesign(.serif)
            .lineLimit(1 ... 5)
            .foregroundStyle(UITheme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textFieldStyle(.plain)
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

// MARK: - Verse View

private struct VerseView: View {
    let textKey: LocalizedStringKey

    var body: some View {
        VStack {
            Spacer()

            Text(textKey)
                .font(.title2)
                .fontDesign(.serif)
                .multilineTextAlignment(.center)
                .lineSpacing(14)
                .tracking(2)
                .foregroundStyle(UITheme.primaryText.opacity(0.85))
                .shadow(color: .white.opacity(0.12), radius: 16)
                .shadow(color: .white.opacity(0.06), radius: 32)

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
                TextField("seastar.prompt.glimmerWithin", text: $text, axis: .vertical)
                    .focused($isFocused)
                    .font(.body)
                    .fontDesign(.serif)
                    .lineSpacing(6)
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
            .navigationTitle("glimmer.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(UITheme.secondaryText)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        onSend()
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.semibold))
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
