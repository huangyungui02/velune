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

struct StardustInfoPopover: View {
    let subscriptionManager: SubscriptionManager

    private var descriptionText: String {
        guard subscriptionManager.currentPlan != .free else {
            return String(localized: "settings.billing.stardust.description")
        }

        let format = String(localized: "settings.billing.stardust.description.premium.format")
        return String(format: format, locale: Locale.current, subscriptionManager.dailyCreditsAllowance)
    }

    var body: some View {
        ScrollView {
            Text(descriptionText)
                .font(.subheadline)
                .foregroundStyle(UITheme.secondaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(width: 320, alignment: .topLeading)
        .frame(maxHeight: 360, alignment: .topLeading)
        .presentationCompactAdaptation(.popover)
    }
}
