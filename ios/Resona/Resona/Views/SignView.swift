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
                        .font(.system(size: 72, weight: .regular, design: .rounded))
                        .foregroundStyle(UITheme.primaryText)

                    Text("Resona")
                        .font(.system(size: 44, weight: .semibold, design: .serif))
                        .foregroundStyle(UITheme.primaryText)

                    Text("Glimmer.\nResonance.\nEcho.")
                        .font(.system(size: 21, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .tracking(1.8)
                        .foregroundStyle(UITheme.secondaryText)
                }
                .padding(.bottom, 40)

                appleSignInView
                    .frame(height: 50)
                    .padding(.horizontal, 50)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(UITheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                Text(termsAttributedText)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(UITheme.tertiaryText)
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
        text.foregroundColor = UITheme.tertiaryText

        if let termsRange = text.range(of: "Terms of Service") {
            text[termsRange].link = URL(string: "https://example.com/terms")
            text[termsRange].foregroundColor = UITheme.accent
        }
        if let privacyRange = text.range(of: "Privacy Policy") {
            text[privacyRange].link = URL(string: "https://example.com/privacy")
            text[privacyRange].foregroundColor = UITheme.accent
        }

        return text
    }

}

#Preview {
    SignView()
}
