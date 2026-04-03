import SwiftUI

struct SignView: View {
    @Environment(\.locale) private var locale
    @State private var authManager = AuthManager.shared
    @State private var errorMessage: String? = nil
    @State private var isSigningInAnonymously = false

    var body: some View {
        GeometryReader { proxy in
            let metrics = SignLayoutMetrics(size: proxy.size)

            ZStack {
                StarryBackgroundView()

                VStack(spacing: 0) {
                    Spacer(minLength: metrics.topSpacer)

                    brandBlock(metrics: metrics)

                    Spacer(minLength: metrics.middleSpacer)

                    actionBlock(metrics: metrics)

                    Spacer(minLength: metrics.bottomSpacer)

                    termsBlock
                }
                .padding(.horizontal, metrics.horizontalPadding)
                .padding(.vertical, metrics.verticalPadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func brandBlock(metrics: SignLayoutMetrics) -> some View {
        VStack(spacing: metrics.brandSpacing) {
            VStack(spacing: 12) {
                AppMarkView()
                    .frame(width: metrics.logoSize, height: metrics.logoSize)
                    .foregroundStyle(UITheme.primaryText.opacity(0.92))
                
                Text("sign.appName")
                    .font(.system(size: metrics.brandTitleSize, weight: .medium, design: .serif))
                    .tracking(0.4)
                    .minimumScaleFactor(0.9)
                    .foregroundStyle(UITheme.primaryText)
            }

            Text("sign.slogan")
                .font(.system(size: metrics.sloganSize, weight: .regular, design: .serif))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .tracking(0.55)
                .foregroundStyle(UITheme.secondaryText)
                .frame(maxWidth: metrics.sloganWidth)
        }
        .padding(.horizontal, 8)
    }

    private func actionBlock(metrics: SignLayoutMetrics) -> some View {
        VStack(spacing: 12) {
            AppleSignInActionButton(
                visualStyle: .capsule,
                height: 48
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
                        .frame(height: 44)
                } else {
                    Text("sign.action.skip")
                        .font(.subheadline.weight(.medium))
                        .tracking(0.2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(UITheme.secondaryText)
            .disabled(isSigningInAnonymously)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .lineSpacing(2)
                    .foregroundStyle(UITheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: metrics.actionWidth)
    }

    private var termsBlock: some View {
        VStack(spacing: 12) {
            Text(termsAttributedText)
                .multilineTextAlignment(.center)
                .font(.footnote)
                .lineSpacing(3)
                .foregroundStyle(UITheme.tertiaryText)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
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

private struct SignLayoutMetrics {
    let size: CGSize

    private var isCompactHeight: Bool { size.height < 760 }
    private var isNarrowWidth: Bool { size.width < 375 }

    var horizontalPadding: CGFloat { isNarrowWidth ? 22 : 28 }
    var verticalPadding: CGFloat { isCompactHeight ? 10 : 16 }

    var topSpacer: CGFloat { isCompactHeight ? 16 : 28 }
    var middleSpacer: CGFloat { isCompactHeight ? 20 : 32 }
    var bottomSpacer: CGFloat { isCompactHeight ? 10 : 18 }

    var brandSpacing: CGFloat { isCompactHeight ? 30 : 42 }
    var logoSize: CGFloat { isCompactHeight ? 96 : 112 }
    var brandTitleSize: CGFloat { isCompactHeight ? 40 : 44 }
    var sloganSize: CGFloat { isCompactHeight ? 22 : 24 }
    var sloganWidth: CGFloat { isNarrowWidth ? 286 : 320 }
    var actionWidth: CGFloat { min(356, size.width - horizontalPadding * 2) }
}

private struct AppMarkView: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let outerDiameter = side * (720.0 / 1024.0)
            let innerDiameter = side * (480.0 / 1024.0)
            let outerStroke = side * (16.0 / 1024.0)
            let innerStroke = side * (20.0 / 1024.0)

            ZStack {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: outerStroke))
                    .frame(width: outerDiameter, height: outerDiameter)
                    .opacity(0.5)

                Circle()
                    .stroke(style: StrokeStyle(lineWidth: innerStroke))
                    .frame(width: innerDiameter, height: innerDiameter)
                    .opacity(0.8)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
