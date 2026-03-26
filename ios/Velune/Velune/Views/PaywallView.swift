import SwiftUI

struct PaywallView: View {
    private enum FeedbackMessage {
        case localized(LocalizedStringKey)
        case text(String)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var feedbackMessage: FeedbackMessage?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(.primary)
                            .padding(.top, 40)
                        
                        Text("paywall.title")
                            .font(.system(.largeTitle, design: .serif))
                            .fontWeight(.medium)
                        
                        Text("paywall.subtitle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    // Features
                    VStack(spacing: 24) {
                        FeatureRow(
                            icon: "sparkles.rectangle.stack",
                            title: "paywall.feature.moreStardust.title",
                            subtitle: "paywall.feature.moreStardust.subtitle"
                        )
                        
                        FeatureRow(
                            icon: "lock.open",
                            title: "paywall.feature.priorityAccess.title",
                            subtitle: "paywall.feature.priorityAccess.subtitle"
                        )
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    // Action Area
                    VStack(spacing: 16) {
                        Button {
                            Task { await purchase() }
                        } label: {
                            HStack {
                                if subscriptionManager.isPurchasing {
                                    ProgressView()
                                        .tint(UITheme.primaryActionForeground(for: colorScheme))
                                        .padding(.trailing, 8)
                                }
                                Text("paywall.action.subscribe")
                                    .fontWeight(.medium)

                                Text(subscriptionManager.monthlyPriceText)
                                    .font(.subheadline)
                                    .foregroundStyle(UITheme.primaryActionForeground(for: colorScheme).opacity(0.75))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(UITheme.primaryActionBackground(for: colorScheme))
                            .foregroundStyle(UITheme.primaryActionForeground(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(subscriptionManager.isPurchasing || !subscriptionManager.isRevenueCatAvailable)
                        .padding(.horizontal, 32)
                        
                        Button {
                            Task { await restore() }
                        } label: {
                            HStack {
                                if subscriptionManager.isRestoring {
                                    ProgressView()
                                        .controlSize(.small)
                                        .padding(.trailing, 4)
                                }
                                Text("settings.billing.action.restore")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .disabled(subscriptionManager.isRestoring || !subscriptionManager.isRevenueCatAvailable)
                    }
                    
                    // Legal
                    HStack(spacing: 16) {
                        Link("settings.link.terms", destination: AppLinks.terms)
                        Text("•").foregroundStyle(.tertiary)
                        Link("settings.link.privacy", destination: AppLinks.privacy)
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 32)
                }
            }
            .scrollIndicators(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.title3)
                    }
                }
            }
            .alert("settings.error.title", isPresented: Binding(
                get: { feedbackMessage != nil },
                set: { if !$0 { feedbackMessage = nil } }
            )) {
                Button("common.ok", role: .cancel) {}
            } message: {
                switch feedbackMessage {
                case .localized(let key):
                    Text(key)
                case .text(let message):
                    Text(message)
                case .none:
                    SwiftUI.EmptyView()
                }
            }
            .onChange(of: subscriptionManager.isPremium) { _, isPremium in
                if isPremium {
                    // Dismiss after a short delay to show success state if needed, or immediately
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func purchase() async {
        do {
            try await subscriptionManager.purchasePremium()
        } catch {
            feedbackMessage = .text(error.localizedDescription)
        }
    }

    private func restore() async {
        do {
            try await subscriptionManager.restorePurchases()
            if !subscriptionManager.isPremium {
                feedbackMessage = .localized("paywall.restore.notFound")
            }
        } catch {
            feedbackMessage = .text(error.localizedDescription)
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.primary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    PaywallView()
}
