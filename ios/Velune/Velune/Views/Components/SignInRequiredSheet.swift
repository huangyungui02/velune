import SwiftUI

struct SignInRequiredSheet: View {
    let descriptionKey: LocalizedStringKey

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.primary)

                    Text("paywall.signInRequired.title")
                        .font(.title3.weight(.semibold))
                        .fontDesign(.serif)
                        .multilineTextAlignment(.center)

                    Text(descriptionKey)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AppleSignInActionButton(
                    visualStyle: .capsule,
                    height: 46,
                    showInlineError: true,
                    onSuccess: { dismiss() }
                )
                .frame(maxWidth: 320)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}
