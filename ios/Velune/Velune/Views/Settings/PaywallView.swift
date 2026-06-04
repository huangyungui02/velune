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
    
    private var monthlyPackage: RevenueCat.Package? {
        depthPackages.first { $0.storeProduct.productIdentifier.lowercased() == BillingConfig.depthMonthlyProductId }
    }
    
    private var annualPackage: RevenueCat.Package? {
        depthPackages.first { $0.storeProduct.productIdentifier.lowercased() == BillingConfig.depthAnnualProductId }
    }
    
    private var annualDiscountPercentage: Int? {
        guard let monthly = monthlyPackage, let annual = annualPackage else { return nil }
        let monthlyPrice = monthly.storeProduct.price
        let annualPrice = annual.storeProduct.price
        let annualMonthlyEquivalent = annualPrice / 12
        guard monthlyPrice > 0 else { return nil }
        let discount = (monthlyPrice - annualMonthlyEquivalent) / monthlyPrice
        let percentage = NSDecimalNumber(decimal: discount * 100).intValue
        return percentage > 0 ? percentage : nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background Theme with cosmic ambient glow
                Color.black.ignoresSafeArea()
                
                RadialGradient(
                    colors: [UITheme.glimmerGlow.opacity(0.12), Color.clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 38, weight: .light))
                                .foregroundStyle(UITheme.glimmerGlow)
                                .shadow(color: UITheme.glimmerGlow.opacity(0.4), radius: 8)
                                .padding(.top, 24)
                            
                            Text("paywall.title")
                                .font(.system(.largeTitle, design: .serif))
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                                .tracking(0.5)
                            
                        }
                        
                        // Poetic & Spiritual Feature list in an elegant card container
                        VStack(spacing: 20) {
                            FeatureRow(
                                icon: "book.closed",
                                title: "paywall.feature.fullContent.title",
                                subtitle: "paywall.feature.fullContent.subtitle"
                            )

                            FeatureRow(
                                icon: "sparkles",
                                title: "paywall.feature.advancedModel.title",
                                subtitle: "paywall.feature.advancedModel.subtitle"
                            )
                            
                            FeatureRow(
                                icon: "lock.open",
                                title: "paywall.feature.priorityAccess.title",
                                subtitle: "paywall.feature.priorityAccess.subtitle"
                            )
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white.opacity(0.02))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        
                        // Action Area (Packages & Subscription Button)
                        VStack(spacing: 20) {
                            if !depthPackages.isEmpty {
                                HStack(spacing: 14) {
                                    ForEach(depthPackages, id: \.identifier) { package in
                                        let isAnnual = package.storeProduct.productIdentifier.lowercased() == BillingConfig.depthAnnualProductId
                                        let isSelected = selectedPackage?.identifier == package.identifier
                                        
                                        ZStack(alignment: .top) {
                                            PackageCard(
                                                package: package,
                                                isSelected: isSelected,
                                                onSelect: { selectedPackage = package }
                                            )
                                            
                                            if isAnnual, let discount = annualDiscountPercentage {
                                                Text(String(format: String(localized: "paywall.tier.saveBadge"), discount))
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundStyle(UITheme.primaryActionForeground(for: colorScheme))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        Capsule()
                                                            .fill(UITheme.glimmerGlow)
                                                    )
                                                    .offset(y: -9)
                                                    .shadow(color: UITheme.glimmerGlow.opacity(0.3), radius: 4, x: 0, y: 2)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 24)
                            } else {
                                ProgressView()
                                    .tint(UITheme.glimmerGlow)
                                    .padding(.vertical, 32)
                            }
                            
                            VStack(spacing: 14) {
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
                                            .font(.system(.body, design: .default))
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(UITheme.primaryActionBackground(for: colorScheme))
                                    .foregroundStyle(UITheme.primaryActionForeground(for: colorScheme))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
                                }
                                .disabled(subscriptionManager.isPurchasing || !subscriptionManager.isRevenueCatAvailable || selectedPackage == nil)
                                .opacity(selectedPackage == nil ? 0.5 : 1.0)
                                .padding(.horizontal, 24)
                                
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
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(UITheme.secondaryText)
                                }
                                .disabled(subscriptionManager.isRestoring || !subscriptionManager.isRevenueCatAvailable)
                            }
                        }
                        
                        // Legal links
                        HStack(spacing: 16) {
                            Link("settings.link.terms", destination: AppLinks.terms)
                                .foregroundStyle(UITheme.tertiaryText)
                            Text("•")
                                .foregroundStyle(UITheme.tertiaryText.opacity(0.5))
                            Link("settings.link.privacy", destination: AppLinks.privacy)
                                .foregroundStyle(UITheme.tertiaryText)
                        }
                        .font(.system(size: 11))
                        .padding(.top, 8)
                        .padding(.bottom, 24)
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
                                .foregroundStyle(UITheme.tertiaryText.opacity(0.7))
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
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            dismiss()
                        }
                    }
                }
                .onChange(of: subscriptionManager.availablePackages) { _, newPackages in
                    let packages = sortedDepthPackages(newPackages)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        if let selectedPackage, !packages.contains(where: { $0.identifier == selectedPackage.identifier }) {
                            self.selectedPackage = packages.first
                        } else if selectedPackage == nil, let first = packages.first {
                            selectedPackage = first
                        }
                    }
                }
                .onAppear {
                    if selectedPackage == nil, let first = depthPackages.first {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            selectedPackage = first
                        }
                    }
                }
                .sheet(isPresented: $showSignInSheet) {
                    SignInRequiredSheet(descriptionKey: signInPromptReason.descriptionKey)
                }
            }
        }
    }

    private var depthPackages: [RevenueCat.Package] {
        sortedDepthPackages(subscriptionManager.availablePackages)
    }

    private func sortedDepthPackages(_ packages: [RevenueCat.Package]) -> [RevenueCat.Package] {
        packages
            .filter { BillingConfig.isDepthProduct($0.storeProduct.productIdentifier) }
            .sorted { lhs, rhs in
                packageSortRank(lhs) < packageSortRank(rhs)
            }
    }

    private func packageSortRank(_ package: RevenueCat.Package) -> Int {
        let productId = package.storeProduct.productIdentifier.lowercased()
        if productId == BillingConfig.depthMonthlyProductId { return 0 }
        if productId == BillingConfig.depthAnnualProductId { return 1 }
        return 2
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
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(UITheme.glimmerGlow)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(UITheme.glimmerGlow.opacity(0.08))
                )
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(UITheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 0)
        }
    }
}

private struct PackageCard: View {
    let package: RevenueCat.Package
    let isSelected: Bool
    let onSelect: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var isAnnual: Bool {
        package.storeProduct.productIdentifier.lowercased() == BillingConfig.depthAnnualProductId
    }
    
    private var titleKey: LocalizedStringKey {
        isAnnual ? "paywall.tier.annual.label" : "paywall.tier.monthly.label"
    }
    
    private var priceString: String {
        package.storeProduct.localizedPriceString
    }
    
    private var priceSuffix: String {
        isAnnual ? NSLocalizedString("billing.price.perYearSuffix", comment: "") : NSLocalizedString("billing.price.perMonthSuffix", comment: "")
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Card Header (Label)
                Text(titleKey)
                    .font(.system(.headline, design: .serif))
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? UITheme.glimmerGlow : .white)
                
                Spacer(minLength: 0)
                
                // Pricing Area
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(priceString)
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? .white : UITheme.primaryText)
                        
                        Text(priceSuffix)
                            .font(.system(size: 11))
                            .foregroundStyle(UITheme.secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .frame(height: 98) // Sized to match premium clean styling without subtext!
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.08 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? UITheme.glimmerGlow.opacity(0.8) : Color.white.opacity(0.12),
                        lineWidth: isSelected ? 1.5 : 1.0
                    )
            )
            .shadow(color: isSelected ? UITheme.glimmerGlow.opacity(0.08) : Color.clear, radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
}
