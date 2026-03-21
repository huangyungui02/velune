import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var feedbackMessage: String?
    @State private var isSuccess = false
    
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
                        
                        Text("Aevra Premium")
                            .font(.system(.largeTitle, design: .serif))
                            .fontWeight(.medium)
                        
                        Text("Unlock the full depth of the cosmos.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Features
                    VStack(spacing: 24) {
                        FeatureRow(
                            icon: "infinity",
                            title: "Unlimited Echoes",
                            subtitle: "Connect without boundaries. 1000 credits per month."
                        )
                        
                        FeatureRow(
                            icon: "sparkles.rectangle.stack",
                            title: "Deeper Resonances",
                            subtitle: "Experience more profound and meaningful interactions."
                        )
                        
                        FeatureRow(
                            icon: "lock.open",
                            title: "Priority Access",
                            subtitle: "Be the first to experience new features and capabilities."
                        )
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer(minLength: 40)
                    
                    // Action Area
                    VStack(spacing: 16) {
                        Button {
                            Task { await purchase() }
                        } label: {
                            HStack {
                                if subscriptionManager.isPurchasing {
                                    ProgressView()
                                        .tint(.white)
                                        .padding(.trailing, 8)
                                }
                                Text("Subscribe for \(subscriptionManager.monthlyPriceText)")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primary)
                            .foregroundStyle(Color(UIColor.systemBackground))
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
                Text(feedbackMessage ?? "")
            }
            .onChange(of: subscriptionManager.isPremium) { _, isPremium in
                if isPremium {
                    isSuccess = true
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
            feedbackMessage = error.localizedDescription
        }
    }

    private func restore() async {
        do {
            try await subscriptionManager.restorePurchases()
            if !subscriptionManager.isPremium {
                feedbackMessage = String(localized: "paywall.restore.notFound")
            }
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
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
