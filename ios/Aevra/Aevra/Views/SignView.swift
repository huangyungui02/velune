import SwiftUI

struct SignView: View {
    @Environment(\.locale) private var locale
    @State private var authManager = AuthManager.shared
    @State private var errorMessage: String? = nil
    @State private var isSigningInAnonymously = false

    var body: some View {
        ZStack {
            StarryBackgroundView()

            VStack(spacing: 0) {
                Spacer(minLength: 22)

                brandBlock

                Spacer(minLength: 18)

                actionBlock

                Spacer(minLength: 14)

                termsBlock
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
        }
    }

    private var brandBlock: some View {
        VStack(spacing: 40) {
            VStack(spacing: 10) {
                AppMarkView()
                    .frame(width: 98, height: 98)
                    .foregroundStyle(UITheme.primaryText.opacity(0.92))
                
                Text("Aevra")
                    .font(.largeTitle.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.primaryText)
            }

            Text("sign.slogan")
                .font(.title3.weight(.semibold))
                .fontDesign(.serif)
                .multilineTextAlignment(.center)
                .lineSpacing(7)
                .tracking(0.9)
                .foregroundStyle(UITheme.secondaryText)
                .frame(maxWidth: 320)
        }
        .padding(.horizontal, 10)
    }

    private var actionBlock: some View {
        VStack(spacing: 8) {
            AppleSignInActionButton(
                title: "anonymous.action.signInWithApple",
                visualStyle: .capsule,
                height: 46
            )

            Button {
                Task {
                    isSigningInAnonymously = true
                    defer { isSigningInAnonymously = false }

                    do {
                        try await authManager.signInAnonymously()
                        errorMessage = nil
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                if isSigningInAnonymously {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                } else {
                    Text("sign.action.skip")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(UITheme.secondaryText)
            .disabled(isSigningInAnonymously)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(UITheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: 420)
    }

    private var termsBlock: some View {
        VStack(spacing: 12) {
            Text(termsAttributedText)
                .multilineTextAlignment(.center)
                .font(.footnote.weight(.medium))
                .foregroundStyle(UITheme.tertiaryText)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
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

private struct AppMarkView: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let outerDiameter = side * (704.0 / 1024.0)
            let innerDiameter = side * (448.0 / 1024.0)
            let outerStroke = side * (24.0 / 1024.0)
            let innerStroke = side * (20.0 / 1024.0)

            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: outerStroke))
                    .frame(width: outerDiameter, height: outerDiameter)

                Circle()
                    .stroke(style: StrokeStyle(lineWidth: innerStroke))
                    .frame(width: innerDiameter, height: innerDiameter)
                    .opacity(0.5)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

#Preview {
    SignView()
}
