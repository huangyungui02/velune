import SwiftUI
import RevenueCat

struct PaywallView: View {
    private enum FeedbackMessage {
        case localized(LocalizedStringKey)
        case text(String)
    }

    private enum SignInPromptReason {
        case subscribe
        case restore

        var descriptionKey: LocalizedStringKey {
            switch self {
            case .subscribe:
                "paywall.signInRequired.description"
            case .restore:
                "paywall.restore.signInRequired.description"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var authManager = AuthManager.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var feedbackMessage: FeedbackMessage?
    @State private var showSignInSheet = false
    @State private var signInPromptReason: SignInPromptReason = .subscribe
    @State private var selectedPackage: RevenueCat.Package?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.primary)
                            .padding(.top, 24)
                        
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
                    VStack(spacing: 16) {
                        FeatureRow(
                            icon: "sparkles",
                            title: "paywall.feature.unlimitedConversations.title",
                            subtitle: "paywall.feature.unlimitedConversations.subtitle"
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
                    VStack(spacing: 12) {
                        if !subscriptionManager.availablePackages.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(subscriptionManager.availablePackages, id: \.identifier) { package in
                                    PackageRow(
                                        package: package,
                                        isSelected: selectedPackage?.identifier == package.identifier,
                                        onSelect: { selectedPackage = package }
                                    )
                                }
                            }
                            .padding(.horizontal, 32)
                            .padding(.bottom, 8)
                        } else {
                            ProgressView()
                                .padding()
                        }
                        
                        Button {
                            handleSubscribeTap()
                        } label: {
                            HStack {
                                if subscriptionManager.isPurchasing {
                                    ProgressView()
                                        .tint(UITheme.primaryActionForeground(for: colorScheme))
                                        .padding(.trailing, 8)
                                }
                                Text("paywall.action.subscribe")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(UITheme.primaryActionBackground(for: colorScheme))
                            .foregroundStyle(UITheme.primaryActionForeground(for: colorScheme))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(subscriptionManager.isPurchasing || !subscriptionManager.isRevenueCatAvailable || selectedPackage == nil)
                        .opacity(selectedPackage == nil ? 0.5 : 1.0)
                        .padding(.horizontal, 32)
                        
                        Button {
                            handleRestoreTap()
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
                            .foregroundStyle(.secondary)
                        Text("•").foregroundStyle(.tertiary)
                        Link("settings.link.privacy", destination: AppLinks.privacy)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption2)
                    .padding(.bottom, 16)
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
            .onChange(of: subscriptionManager.availablePackages) { _, newPackages in
                if selectedPackage == nil, let first = newPackages.first {
                    selectedPackage = first
                }
            }
            .onAppear {
                if selectedPackage == nil, let first = subscriptionManager.availablePackages.first {
                    selectedPackage = first
                }
            }
            .sheet(isPresented: $showSignInSheet) {
                SignInRequiredSheet(descriptionKey: signInPromptReason.descriptionKey)
            }
        }
    }

    private func handleSubscribeTap() {
        guard let package = selectedPackage else { return }
        guard !authManager.isAnonymous else {
            signInPromptReason = .subscribe
            showSignInSheet = true
            return
        }

        Task { await purchase(package: package) }
    }

    private func handleRestoreTap() {
        guard !authManager.isAnonymous else {
            signInPromptReason = .restore
            showSignInSheet = true
            return
        }

        Task { await restore() }
    }
    
    private func purchase(package: RevenueCat.Package) async {
        do {
            try await subscriptionManager.purchasePremium(package: package)
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
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
    }
}

private struct PackageRow: View {
    let package: RevenueCat.Package
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var isAwaken: Bool {
        package.identifier.lowercased().contains("awaken")
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isAwaken ? "paywall.tier.awaken.title" : "paywall.tier.deep.title")
                        .font(.headline)
                        .foregroundStyle(isSelected ? UITheme.primaryActionBackground(for: colorScheme) : .primary)
                    Text(isAwaken ? "paywall.tier.awaken.subtitle" : "paywall.tier.deep.subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(package.storeProduct.localizedPriceString + " " + String(localized: "billing.price.perMonthSuffix"))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? UITheme.primaryActionBackground(for: colorScheme) : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .background(isSelected ? UITheme.primaryActionBackground(for: colorScheme).opacity(0.05) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
}
