import Supabase
import SwiftData
import SwiftUI
import UIKit

struct SeaStarView: View {
    @Environment(\.modelContext) private var context
    @State private var text = ""
    @State private var isNavigatingToMatching = false
    @State private var isPresented = false
    @State private var manager = MatchingManager.shared
    @State private var draftPreviewWidth: CGFloat = 0

    private let draftPreviewMaxLines: Int = 5
    private let draftLineSpacing: CGFloat = 6
    private let draftPreviewPadding: CGFloat = 16

    private static let draftUIFont: UIFont = {
        let base = UIFont.systemFont(ofSize: 18, weight: .regular)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: 18)
    }()

    private var draftTextHeight: CGFloat {
        let availableWidth = max(0, draftPreviewWidth - draftPreviewPadding * 2)
        guard availableWidth > 0 else {
            return (Self.draftUIFont.lineHeight + draftLineSpacing) + draftPreviewPadding * 2
        }
        let measuredTextHeight = text.measuredHeight(
            constrainedTo: availableWidth,
            font: Self.draftUIFont,
            lineSpacing: draftLineSpacing
        )
        return measuredTextHeight + draftPreviewPadding * 2
    }

    private var shouldScrollDraftPreview: Bool {
        draftTextHeight > draftPreviewMaxHeight
    }

    private var draftPreviewMaxHeight: CGFloat {
        let lineCount = CGFloat(draftPreviewMaxLines)
        let textHeight = (Self.draftUIFont.lineHeight * lineCount)
            + (draftLineSpacing * CGFloat(max(0, draftPreviewMaxLines - 1)))
        return ceil(textHeight + draftPreviewPadding * 2)
    }

    private var draftPreviewHeight: CGFloat {
        min(draftTextHeight, draftPreviewMaxHeight)
    }

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

                    Text("Listening for echoes")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(UITheme.secondaryText)
                        .tracking(2)
                }
                .padding(16)
                .glassEffect(in: .capsule)
            } else if text.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")

                    Text("What glimmers within you")
                        .foregroundStyle(UITheme.primaryText)
                        .font(.system(size: 18, weight: .regular, design: .serif))
                }
                .padding(16)
                .glassEffect(in: .capsule)
            } else {
                Group {
                    if shouldScrollDraftPreview {
                        ScrollView {
                            draftPreviewText
                                .padding(draftPreviewPadding)
                        }
                        .scrollIndicators(.hidden)
                    } else {
                        draftPreviewText
                            .padding(draftPreviewPadding)
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                draftPreviewWidth = proxy.size.width
                            }
                            .onChange(of: proxy.size.width) { _, newWidth in
                                draftPreviewWidth = newWidth
                            }
                    }
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: draftPreviewHeight, alignment: .topLeading)
                .glassEffect(in: .rect(cornerRadius: 20))
                .contentShape(.rect)
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

    private var draftPreviewText: some View {
        Text(text)
            .font(.system(size: 18, weight: .regular, design: .serif))
            .lineSpacing(draftLineSpacing)
            .foregroundStyle(UITheme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
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

private extension String {
    func measuredHeight(constrainedTo width: CGFloat, font: UIFont, lineSpacing: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = lineSpacing
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle,
        ]
        let rect = (self as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(rect.height)
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
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(UITheme.primaryText)

                Text(description)
                    .font(.system(size: 18, weight: .regular, design: .serif))
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
                    .font(.system(size: 18, weight: .regular, design: .serif))
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
            .navigationTitle("Glimmer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 21, weight: .medium, design: .rounded))
                            .foregroundStyle(UITheme.secondaryText)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        onSend()
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 21, weight: .medium, design: .rounded))
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
