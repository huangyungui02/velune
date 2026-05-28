import SwiftUI

struct SettingsAccountRow: View {
    let authManager: AuthManager

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.09))
                    .frame(width: 44, height: 44)

                Image(systemName: "person.crop.circle")
                    .font(.system(size: 23))
                    .foregroundStyle(UITheme.primaryText.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    authManager.userName
                        ?? String(
                            localized: "settings.account.defaultName",
                            defaultValue: "Soul Traveler"
                        )
                )
                .font(.headline)
                .foregroundStyle(UITheme.primaryText)

                if let email = authManager.userEmail {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(UITheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
