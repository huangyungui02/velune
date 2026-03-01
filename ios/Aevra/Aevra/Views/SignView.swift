import AuthenticationServices
import Supabase
import SwiftUI

struct SignView: View {
    @Environment(\.locale) private var locale
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            StarryBackgroundView()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 32) {
                    Image(systemName: "circle.circle")
                        .font(.largeTitle)
                        .foregroundStyle(UITheme.primaryText)

                    Text("Aevra")
                        .font(.largeTitle.weight(.semibold))
                        .fontDesign(.serif)
                        .foregroundStyle(UITheme.primaryText)

                    Text("sign.slogan")
                        .font(.title3)
                        .fontDesign(.serif)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .tracking(1.5)
                        .foregroundStyle(UITheme.secondaryText)
                }
                .padding(.bottom, 40)

                appleSignInView
                    .frame(height: 50)
                    .padding(.horizontal, 50)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(UITheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Spacer()

                Text(termsAttributedText)
                    .multilineTextAlignment(.center)
                    .font(.footnote.weight(.medium))
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
        let baseText = String(localized: "sign.terms.full", locale: locale)
        let termsLabel = String(localized: "sign.terms.label", locale: locale)
        let privacyLabel = String(localized: "sign.privacy.label", locale: locale)

        var text = AttributedString(baseText)
        text.foregroundColor = UITheme.tertiaryText

        if let termsRange = text.range(of: termsLabel) {
            text[termsRange].link = AppLinks.terms
            text[termsRange].foregroundColor = UITheme.accent
        }
        if let privacyRange = text.range(of: privacyLabel) {
            text[privacyRange].link = AppLinks.privacy
            text[privacyRange].foregroundColor = UITheme.accent
        }

        return text
    }

}

#Preview {
    SignView()
}
