import AuthenticationServices
import SwiftUI

struct AppleSignInActionButton: View {
    enum VisualStyle {
        case plain
        case capsule
    }

    var title: LocalizedStringKey = "anonymous.action.signInWithApple"
    var visualStyle: VisualStyle = .plain
    var height: CGFloat = 50
    var showInlineError = true
    var onSuccess: (() -> Void)?
    var onError: ((String) -> Void)?

    @State private var errorMessage: String?
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 8) {
            SignInWithAppleButton(.signIn, onRequest: { request in
                request.requestedScopes = [.email, .fullName]
            }, onCompletion: { result in
                Task {
                    isProcessing = true
                    defer { isProcessing = false }

                    do {
                        try await AppleSignInFlow.handle(result: result)
                        errorMessage = nil
                        onSuccess?()
                    } catch {
                        let message = error.localizedDescription
                        errorMessage = message
                        onError?(message)
                    }
                }
            })
            .signInWithAppleButtonStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: visualStyle == .capsule ? 46 : height)
            .modifier(AppleSignInButtonChrome(style: visualStyle))
            .accessibilityLabel(title)
            .overlay {
                if isProcessing {
                    ProgressView()
                }
            }
            .disabled(isProcessing)

            if showInlineError, let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(UITheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct AppleSignInButtonChrome: ViewModifier {
    let style: AppleSignInActionButton.VisualStyle

    func body(content: Content) -> some View {
        switch style {
        case .plain:
            content
        case .capsule:
            content
                .clipShape(.capsule)
                .padding(2)
                .background(.ultraThinMaterial, in: .capsule)
                .overlay {
                    Capsule()
                        .strokeBorder(.white.opacity(0.18), lineWidth: 0.6)
                }
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
    }
}

struct AppleSignInPromptCard: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 54, height: 54)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.8)
                    }

                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(UITheme.primaryText)
            }

            Text(title)
                .font(.title3.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(UITheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            AppleSignInActionButton(
                visualStyle: .capsule,
                height: 46
            )
            .frame(maxWidth: 280)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: 360)
        .background(Color.clear, in: .rect(cornerRadius: 24))
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}

struct AppleSignInSettingsRow: View {
    let onError: (String) -> Void

    var body: some View {
        AppleSignInActionButton(
            visualStyle: .capsule,
            height: 44,
            showInlineError: false,
            onError: onError
        )
        .padding(.vertical, 2)
    }
}

enum AppleSignInFlow {
    static func handle(result: Result<ASAuthorization, Error>) async throws {
        let authorization = try result.get()
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AppError.unauthenticated
        }
        try await AuthManager.shared.signInWithAppleCredential(credential)
    }
}

#Preview {
    VStack(spacing: 20) {
        AppleSignInActionButton(visualStyle: .capsule)
        AppleSignInPromptCard(
            icon: "person.crop.circle.badge.exclamationmark",
            title: "anonymous.restricted.profile.title",
            description: "anonymous.restricted.profile.description"
        )
        AppleSignInSettingsRow { _ in
            // Preview only
        }
    }
    .padding()
    .background(BackgroundView())
}
