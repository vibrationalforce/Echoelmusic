import SwiftUI

/// Monetization & Pro Features View
/// Subscription management, revenue analytics, NFT minting, and marketplace
struct MonetizationView: View {

    // MARK: - State

    @State private var selectedTab: MonetizationTab = .subscription
    @State private var currentTier: SubscriptionTier = .free
    @State private var showUpgradeSheet = false
    @State private var showNFTMintSheet = false

    // MARK: - Monetization Tabs

    enum MonetizationTab: String, CaseIterable {
        case subscription = "Subscription"
        case revenue = "Revenue"
        case nft = "NFT Studio"
        case marketplace = "Marketplace"

        var icon: String {
            switch self {
            case .subscription: return "star.fill"
            case .revenue: return "chart.line.uptrend.xyaxis"
            case .nft: return "cube.transparent.fill"
            case .marketplace: return "cart.fill"
            }
        }
    }

    // MARK: - Subscription Tier

    enum SubscriptionTier: String, CaseIterable {
        case free = "Free"
        case basic = "Basic"
        case pro = "Pro"
        case studio = "Studio"

        var price: String {
            switch self {
            case .free: return "$0"
            case .basic: return "$9.99"
            case .pro: return "$29.99"
            case .studio: return "$99.99"
            }
        }

        var period: String {
            switch self {
            case .free: return "Forever"
            case .basic, .pro, .studio: return "/month"
            }
        }

        var color: Color {
            switch self {
            case .free: return .gray
            case .basic: return .blue
            case .pro: return .purple
            case .studio: return .orange
            }
        }

        var features: [String] {
            switch self {
            case .free:
                return [
                    "5 min session limit",
                    "Basic visualizations",
                    "Watermarked exports",
                    "Community support"
                ]
            case .basic:
                return [
                    "Unlimited sessions",
                    "All visualizations",
                    "HD exports (1080p)",
                    "Remove watermarks",
                    "Email support"
                ]
            case .pro:
                return [
                    "Everything in Basic",
                    "4K exports",
                    "Live streaming",
                    "Multi-platform streaming",
                    "Auto-highlight detection",
                    "Priority support",
                    "10 NFT mints/month"
                ]
            case .studio:
                return [
                    "Everything in Pro",
                    "Cloud GPU rendering",
                    "Dolby Atmos export",
                    "Collaborative sessions",
                    "API access",
                    "White-label licensing",
                    "Unlimited NFT mints",
                    "Dedicated support"
                ]
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Tab Picker
                    tabPicker

                    // MARK: - Content
                    tabContent
                }
            }
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showUpgradeSheet) {
                upgradeSheet
            }
            .sheet(isPresented: $showNFTMintSheet) {
                nftMintSheet
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(MonetizationTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 6) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18))

                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .white : .white.opacity(0.5))
                        .frame(width: 90, height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedTab == tab ? Color.cyan.opacity(0.3) : Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(selectedTab == tab ? Color.cyan : Color.clear, lineWidth: 2)
                                )
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .subscription:
            subscriptionView
        case .revenue:
            revenueView
        case .nft:
            nftStudioView
        case .marketplace:
            marketplaceView
        }
    }

    // MARK: - Subscription View

    private var subscriptionView: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Current Plan Badge
                currentPlanBadge

                // Subscription Tiers
                VStack(spacing: 16) {
                    ForEach(SubscriptionTier.allCases, id: \.self) { tier in
                        subscriptionCard(tier: tier)
                    }
                }

                // Feature Comparison
                featureComparisonSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Revenue View

    private var revenueView: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Revenue Summary Cards
                HStack(spacing: 16) {
                    revenueCard(
                        title: "This Month",
                        value: "$1,247",
                        change: "+23%",
                        color: .green
                    )

                    revenueCard(
                        title: "All Time",
                        value: "$12,450",
                        change: "+156%",
                        color: .cyan
                    )
                }

                // Revenue Chart Placeholder
                VStack(alignment: .leading, spacing: 12) {
                    Text("Revenue Trend")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 200)

                        // Placeholder chart
                        VStack {
                            Text("📈")
                                .font(.system(size: 48))

                            Text("Revenue analytics coming soon")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }

                // Revenue Sources
                VStack(alignment: .leading, spacing: 16) {
                    Text("Revenue Sources")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    revenueSourceRow(
                        icon: "star.fill",
                        name: "Subscriptions",
                        amount: "$850",
                        percentage: 68,
                        color: .purple
                    )

                    revenueSourceRow(
                        icon: "cube.transparent.fill",
                        name: "NFT Sales",
                        amount: "$297",
                        percentage: 24,
                        color: .cyan
                    )

                    revenueSourceRow(
                        icon: "cart.fill",
                        name: "Marketplace",
                        amount: "$100",
                        percentage: 8,
                        color: .orange
                    )
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }

    // MARK: - NFT Studio View

    private var nftStudioView: some View {
        ScrollView {
            VStack(spacing: 24) {

                // NFT Hero
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 200)

                        VStack(spacing: 12) {
                            Image(systemName: "cube.transparent.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)

                            Text("Mint Your Peak Moments")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Text("Turn biometric performances into NFTs")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Button(action: { showNFTMintSheet = true }) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Mint New NFT")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                }

                // Your NFTs
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Minted NFTs")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(0..<4, id: \.self) { index in
                            nftCard(index: index)
                        }
                    }
                }

                // NFT Stats
                HStack(spacing: 16) {
                    nftStatCard(
                        icon: "cube.fill",
                        title: "Minted",
                        value: "12"
                    )

                    nftStatCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Total Sales",
                        value: "$2.4K"
                    )
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Marketplace View

    private var marketplaceView: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Marketplace Header
                VStack(spacing: 8) {
                    Text("Content Marketplace")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text("Buy and sell presets, sessions, and effects")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }

                // Categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        categoryPill(name: "Presets", icon: "slider.horizontal.3", isSelected: true)
                        categoryPill(name: "Sessions", icon: "waveform.circle.fill", isSelected: false)
                        categoryPill(name: "Effects", icon: "sparkles", isSelected: false)
                        categoryPill(name: "Visuals", icon: "eye.fill", isSelected: false)
                    }
                }

                // Marketplace Items
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(0..<6, id: \.self) { index in
                        marketplaceItemCard(index: index)
                    }
                }

                // Your Listings
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Your Listings")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        Button(action: {}) {
                            Text("+ New Listing")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.cyan)
                        }
                    }

                    if true { // No listings placeholder
                        VStack(spacing: 12) {
                            Image(systemName: "tray")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.3))

                            Text("No listings yet")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))

                            Button(action: {}) {
                                Text("Create First Listing")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        Capsule()
                                            .fill(Color.cyan.opacity(0.3))
                                    )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
    }

    // MARK: - Helper Views

    private var currentPlanBadge: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Plan")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))

                Text(currentTier.rawValue)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            if currentTier != .studio {
                Button(action: { showUpgradeSheet = true }) {
                    Text("Upgrade")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(currentTier.color)
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(currentTier.color.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(currentTier.color, lineWidth: 2)
                )
        )
    }

    private func subscriptionCard(tier: SubscriptionTier) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.rawValue)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(tier.price)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(tier.color)

                        Text(tier.period)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                if currentTier == tier {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
                }
            }

            Divider()
                .background(Color.white.opacity(0.2))

            // Features
            VStack(alignment: .leading, spacing: 10) {
                ForEach(tier.features, id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(tier.color)

                        Text(feature)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }

            // Action Button
            if currentTier != tier {
                Button(action: { currentTier = tier }) {
                    Text(currentTier.rawValue < tier.rawValue ? "Upgrade" : "Downgrade")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(tier.color)
                        )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(currentTier == tier ? tier.color : Color.clear, lineWidth: 2)
                )
        )
    }

    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feature Comparison")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("Compare all tiers")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
    }

    private func revenueCard(title: String, value: String, change: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                Text(change)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func revenueSourceRow(icon: String, name: String, amount: String, percentage: Int, color: Color) -> some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .frame(width: 24)

                    Text(name)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Text(amount)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(percentage) / 100)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func nftCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)

                VStack {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Peak Moment #\(index + 1)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text("0.08 ETH")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.cyan)
            }
        }
    }

    private func nftStatCard(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))

                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func categoryPill(name: String, icon: String, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))

            Text(name)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(isSelected ? .black : .white.opacity(0.7))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(isSelected ? Color.cyan : Color.white.opacity(0.1))
        )
    }

    private func marketplaceItemCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 100)

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.5))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Preset Pack \(index + 1)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                HStack {
                    Text("$4.99")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)

                    Spacer()

                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("4.8")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.yellow)
                }
            }
        }
    }

    private var upgradeSheet: some View {
        Text("Upgrade flow coming soon")
            .padding()
    }

    private var nftMintSheet: some View {
        Text("NFT minting flow coming soon")
            .padding()
    }
}

// MARK: - Preview

#Preview {
    MonetizationView()
}
