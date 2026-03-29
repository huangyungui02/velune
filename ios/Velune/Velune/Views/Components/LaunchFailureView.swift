import SwiftUI

struct LaunchFailureView: View {
    let failure: AppLaunchFailure

    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 64, height: 64)

                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(UITheme.primaryText)
                }

                VStack(spacing: 10) {
                    Text(failure.title)
                        .font(.title3.weight(.semibold))
                        .fontDesign(.serif)
                        .foregroundStyle(UITheme.primaryText)
                        .multilineTextAlignment(.center)

                    Text(failure.message)
                        .font(.subheadline)
                        .foregroundStyle(UITheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Link(destination: AppLinks.contactEmail) {
                    Text("Contact Support")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(UITheme.primaryText)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.08), in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(.white.opacity(0.12), lineWidth: 0.8)
                        }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 30)
            .frame(maxWidth: 360)
            .glassEffect(in: .rect(cornerRadius: 26))
            .padding(.horizontal, 24)
        }
        .ignoresSafeArea()
    }
}
