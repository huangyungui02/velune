import AuthenticationServices
import Supabase
import SwiftUI

struct SignView: View {
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            StarryBackgroundView()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 32) {
                    Image(systemName: "circle.circle")
                        .font(.system(size: 80))

                    Text("Resona")
                        .font(.system(size: 40, weight: .semibold, design: .serif))

                    Text("Glimmer.\nResonance.\nEcho.")
                        .font(.system(size: 24, weight: .light, design: .serif))
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.bottom, 40)

                appleSignInView
                    .frame(height: 50)
                    .padding(.horizontal, 50)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                Text(termsAttributedText)
                    .multilineTextAlignment(.center)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 12)
            }
        }
    }

    private var appleSignInView: some View {
        SignInWithAppleButton { request in
            request.requestedScopes = [.email, .fullName]
        } onCompletion: { result in
            Task {
                do {
                    guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential
                    else {
                        return
                    }

                    guard let idToken = credential.identityToken
                        .flatMap({ String(data: $0, encoding: .utf8) })
                    else {
                        return
                    }

                    try await supabase.auth.signInWithIdToken(
                        credentials: .init(
                            provider: .apple,
                            idToken: idToken
                        )
                    )

                    // Apple only provides the user's full name on the first sign-in
                    // Save it to user metadata if available
                    if let fullName = credential.fullName {
                        var nameParts: [String] = []
                        if let givenName = fullName.givenName {
                            nameParts.append(givenName)
                        }
                        if let middleName = fullName.middleName {
                            nameParts.append(middleName)
                        }
                        if let familyName = fullName.familyName {
                            nameParts.append(familyName)
                        }

                        let fullNameString = nameParts.joined(separator: " ")

                        try await supabase.auth.update(
                            user: UserAttributes(
                                data: [
                                    "full_name": .string(fullNameString),
                                    "given_name": .string(fullName.givenName ?? ""),
                                    "family_name": .string(fullName.familyName ?? "")
                                ]
                            )
                        )
                    }

                    // User successfully signed in
                    print("Sign in with Apple successful!")
                } catch {
                    errorMessage = error.localizedDescription
                    print("Sign in with Apple failed: \(error.localizedDescription)")
                }
            }
        }
        .signInWithAppleButtonStyle(.whiteOutline)
    }

    private var termsAttributedText: AttributedString {
        var text = AttributedString("By signing in, you agree to our Terms of Service and Privacy Policy.")
        text.foregroundColor = .secondary

        if let termsRange = text.range(of: "Terms of Service") {
            text[termsRange].link = URL(string: "https://example.com/terms")
            text[termsRange].foregroundColor = .accentColor
        }
        if let privacyRange = text.range(of: "Privacy Policy") {
            text[privacyRange].link = URL(string: "https://example.com/privacy")
            text[privacyRange].foregroundColor = .accentColor
        }

        return text
    }

}

#Preview {
    SignView()
}
