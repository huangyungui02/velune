import SwiftUI

struct StarSeaGlimmerAccessoryView: View {
    @Binding var pulseScale: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon

                VStack(alignment: .leading, spacing: 4) {
                    Text("starsea.settlement.readyTitle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("starsea.settlement.clickToView")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.05, green: 0.06, blue: 0.09).opacity(0.55))
            )
            .glassEffect(in: .rect(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .white.opacity(0.04), .white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            }
            .shadow(color: Color.black.opacity(0.25), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .onAppear {
            pulseScale = 1.15
        }
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 44, height: 44)
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                    value: pulseScale
                )

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0.05), .white.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .frame(width: 36, height: 36)

            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.85, green: 0.9, blue: 1.0), Color(red: 0.6, green: 0.75, blue: 1.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }
}
