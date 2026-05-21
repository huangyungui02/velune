import SwiftUI

struct StarSeaView: View {
    @State private var text = ""
    @State private var isComposerPresented = false
    @Binding var composeRequestID: Int

    init(composeRequestID: Binding<Int> = .constant(0)) {
        _composeRequestID = composeRequestID
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    draftToolbarContent
                }
        }
        .fullScreenCover(isPresented: $isComposerPresented) {
            StarSeaComposerCover(
                text: $text,
                onDismiss: dismissComposer,
                onDone: dismissComposer
            )
        }
        .onChange(of: composeRequestID) { _, _ in
            presentComposer()
        }
    }

    private var mainContent: some View {
        ZStack {
            StarryBackgroundView()
                .contentShape(Rectangle())

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    if hasDraft {
                        Button {
                            presentComposer()
                        } label: {
                            GlimmerCardView(content: text)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("starsea.prompt.glimmerWithin"))
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        HeroVerse()
                            .padding(.horizontal, 32)
                            .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.22), value: text.isEmpty)

            if !hasDraft {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingWriteButton {
                            presentComposer()
                        }
                        .padding(.trailing, 28)
                        .padding(.bottom, 40)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var hasDraft: Bool {
        !text.isEmpty
    }

    @ToolbarContentBuilder
    private var draftToolbarContent: some ToolbarContent {
        if hasDraft {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive, action: clearComposer) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                }
                .accessibilityLabel(Text("common.clear"))
            }

        }
    }

    // MARK: - Actions

    private func presentComposer() {
        isComposerPresented = true
    }

    private func dismissComposer() {
        isComposerPresented = false
    }

    private func clearComposer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.easeInOut(duration: 0.24)) {
            text = ""
        }
    }
}
