import AuthenticationServices
import Supabase
import SwiftUI

struct SignView: View {
    @State private var errorMessage: String? = nil
    @State private var hasAgreedToTerms: Bool = false

    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 32) {
                    Image(systemName: "circle.circle")
                        .font(.system(size: 80))
                        .symbolEffect(
                            .pulse
                        )

                    Text("Resona")
                        .font(.system(size: 42, weight: .bold, design: .rounded))

                    Text("Set down a glimmer, await its echo")
                        .font(.title)
                }
                .padding(.bottom, 40)

                appleSignInView
                    .frame(height: 50)
                    .padding(.horizontal, 50)
                    .disabled(!hasAgreedToTerms)
                    .opacity(hasAgreedToTerms ? 1.0 : 0.5)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        hasAgreedToTerms.toggle()
                    } label: {
                        Image(systemName: hasAgreedToTerms ? "checkmark.square.fill" : "square")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(hasAgreedToTerms ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)

                    Text(termsAttributedText)
                        .multilineTextAlignment(.leading)
                }.font(.footnote).padding()
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
        var text = AttributedString("I have read and agree to the Terms of Service and Privacy Policy")
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
