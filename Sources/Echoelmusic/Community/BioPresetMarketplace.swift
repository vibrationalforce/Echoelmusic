// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic
// Inspired by Aiode's Revenue Sharing Model - Adapted for Bio-Preset Community

import Foundation
import SwiftUI
import Combine

// MARK: - Bio-Preset Marketplace
/// Community marketplace for bio-reactive presets with creator revenue sharing
/// Like Aiode's musician compensation model, but for bio-preset creators
@MainActor
public final class BioPresetMarketplace: ObservableObject {

    public static let shared = BioPresetMarketplace()

    // MARK: - State

    @Published public var featuredPresets: [CommunityBioPreset] = []
    @Published public var popularPresets: [CommunityBioPreset] = []
    @Published public var newPresets: [CommunityBioPreset] = []
    @Published public var myPresets: [CommunityBioPreset] = []
    @Published public var purchasedPresets: [CommunityBioPreset] = []

    @Published public var currentUser: Creator?
    @Published public var isLoading: Bool = false

    // Revenue sharing: 70% to creator, 30% platform
    public let creatorRevenueShare: Double = 0.70
    public let platformRevenueShare: Double = 0.30

    // MARK: - Models

    public struct CommunityBioPreset: Identifiable, Codable {
        public let id: UUID
        public var name: String
        public var description: String
        public var category: PresetCategory
        public var creatorId: UUID
        public var creatorName: String
        public var creatorVerified: Bool

        // Bio-signature captured from creator
        public var bioSignature: BioSignature?

        // Pricing
        public var price: Decimal // 0 = free
        public var currency: String = "EUR"

        // Stats
        public var downloads: Int
        public var rating: Double // 0-5
        public var reviewCount: Int
        public var usageCount: Int // Times used in projects

        // Metadata
        public var createdAt: Date
        public var updatedAt: Date
        public var tags: [String]
        public var previewAudioURL: String?
        public var previewImageURL: String?

        // Revenue tracking
        public var totalRevenue: Decimal
        public var creatorEarnings: Decimal

        public var isFree: Bool { price == 0 }

        public var formattedPrice: String {
            if isFree { return "Free" }
            return String(format: "€%.2f", NSDecimalNumber(decimal: price).doubleValue)
        }

        public enum PresetCategory: String, Codable, CaseIterable {
            case meditation = "Meditation"
            case focus = "Focus"
            case creative = "Creative"
            case relaxation = "Relaxation"
            case energy = "Energy"
            case sleep = "Sleep"
            case performance = "Performance"
            case healing = "Healing"
            case soundDesign = "Sound Design"
            case visualArt = "Visual Art"
            case lightShow = "Light Show"
            case fullExperience = "Full Experience"

            public var icon: String {
                switch self {
                case .meditation: return "brain.head.profile"
                case .focus: return "target"
                case .creative: return "paintbrush.fill"
                case .relaxation: return "leaf.fill"
                case .energy: return "bolt.fill"
                case .sleep: return "moon.zzz.fill"
                case .performance: return "star.fill"
                case .healing: return "heart.fill"
                case .soundDesign: return "waveform"
                case .visualArt: return "sparkles"
                case .lightShow: return "lightbulb.fill"
                case .fullExperience: return "cube.transparent.fill"
                }
            }

            public var color: String {
                switch self {
                case .meditation: return "#8B5CF6"
                case .focus: return "#3B82F6"
                case .creative: return "#EC4899"
                case .relaxation: return "#22C55E"
                case .energy: return "#F59E0B"
                case .sleep: return "#6366F1"
                case .performance: return "#EF4444"
                case .healing: return "#14B8A6"
                case .soundDesign: return "#6B7280"
                case .visualArt: return "#D946EF"
                case .lightShow: return "#FBBF24"
                case .fullExperience: return "#22C55E"
                }
            }
        }
    }

    // MARK: - Bio-Signature

    public struct BioSignature: Codable {
        public let capturedAt: Date
        public let creatorId: UUID

        // Creator's bio-state when creating the preset
        public var avgHeartRate: Double
        public var avgHRVCoherence: Double
        public var avgBreathingRate: Double
        public var dominantEmotionalState: String

        // Bio-modulation settings
        public var coherenceTarget: Double
        public var energyProfile: EnergyProfile
        public var breathPattern: BreathPattern

        public enum EnergyProfile: String, Codable, CaseIterable {
            case calm = "Calm"
            case balanced = "Balanced"
            case energetic = "Energetic"
            case intense = "Intense"
        }

        public enum BreathPattern: String, Codable, CaseIterable {
            case natural = "Natural"
            case slow = "Slow (6/min)"
            case coherent = "Coherent (5/min)"
            case energizing = "Energizing (15/min)"
            case boxBreathing = "Box Breathing"
        }

        /// Generate signature description for users
        public var description: String {
            """
            Created in \(dominantEmotionalState) state with \(Int(avgHRVCoherence * 100))% coherence.
            Energy: \(energyProfile.rawValue), Breath: \(breathPattern.rawValue)
            """
        }
    }

    // MARK: - Creator Profile

    public struct Creator: Identifiable, Codable {
        public let id: UUID
        public var username: String
        public var displayName: String
        public var bio: String?
        public var avatarURL: String?

        // Verification & status
        public var isVerified: Bool
        public var creatorTier: CreatorTier
        public var joinedAt: Date

        // Stats
        public var totalPresets: Int
        public var totalDownloads: Int
        public var totalEarnings: Decimal
        public var averageRating: Double
        public var followerCount: Int

        // Payout info (encrypted in production)
        public var payoutMethod: PayoutMethod?

        public enum CreatorTier: String, Codable, CaseIterable {
            case starter = "Starter"
            case rising = "Rising"
            case established = "Established"
            case elite = "Elite"
            case legend = "Legend"

            public var minDownloads: Int {
                switch self {
                case .starter: return 0
                case .rising: return 100
                case .established: return 1000
                case .elite: return 10000
                case .legend: return 100000
                }
            }

            public var badge: String {
                switch self {
                case .starter: return "🌱"
                case .rising: return "🌟"
                case .established: return "⭐"
                case .elite: return "💎"
                case .legend: return "👑"
                }
            }
        }

        public enum PayoutMethod: String, Codable, CaseIterable {
            case paypal = "PayPal"
            case bankTransfer = "Bank Transfer"
            case stripe = "Stripe"
            case crypto = "Cryptocurrency"
        }
    }

    // MARK: - Transaction

    public struct Transaction: Identifiable, Codable {
        public let id: UUID
        public let presetId: UUID
        public let presetName: String
        public let buyerId: UUID
        public let creatorId: UUID
        public let amount: Decimal
        public let creatorShare: Decimal
        public let platformShare: Decimal
        public let currency: String
        public let timestamp: Date
        public let status: TransactionStatus

        public enum TransactionStatus: String, Codable {
            case pending = "Pending"
            case completed = "Completed"
            case refunded = "Refunded"
            case failed = "Failed"
        }
    }

    // MARK: - Marketplace Operations

    /// Fetch featured presets
    public func fetchFeaturedPresets() async {
        isLoading = true
        defer { isLoading = false }

        // In production: API call
        // Simulated data:
        featuredPresets = [
            createSamplePreset(name: "Deep Meditation Flow", category: .meditation, price: 4.99, downloads: 12500),
            createSamplePreset(name: "Laser Focus State", category: .focus, price: 3.99, downloads: 8700),
            createSamplePreset(name: "Creative Burst", category: .creative, price: 0, downloads: 25000),
        ]
    }

    /// Fetch presets by category
    public func fetchPresets(category: CommunityBioPreset.PresetCategory) async -> [CommunityBioPreset] {
        // In production: API call with category filter
        return []
    }

    /// Search presets
    public func searchPresets(query: String) async -> [CommunityBioPreset] {
        // In production: API call with search
        return []
    }

    /// Purchase preset
    public func purchasePreset(_ preset: CommunityBioPreset) async throws -> Transaction {
        guard let user = currentUser else {
            throw MarketplaceError.notLoggedIn
        }

        // Calculate shares
        let creatorShare = preset.price * Decimal(creatorRevenueShare)
        let platformShare = preset.price * Decimal(platformRevenueShare)

        let transaction = Transaction(
            id: UUID(),
            presetId: preset.id,
            presetName: preset.name,
            buyerId: user.id,
            creatorId: preset.creatorId,
            amount: preset.price,
            creatorShare: creatorShare,
            platformShare: platformShare,
            currency: preset.currency,
            timestamp: Date(),
            status: .completed
        )

        // Add to purchased
        purchasedPresets.append(preset)

        return transaction
    }

    /// Download free preset
    public func downloadFreePreset(_ preset: CommunityBioPreset) async throws {
        guard preset.isFree else {
            throw MarketplaceError.presetNotFree
        }

        purchasedPresets.append(preset)
    }

    // MARK: - Creator Operations

    /// Publish a new preset
    public func publishPreset(
        name: String,
        description: String,
        category: CommunityBioPreset.PresetCategory,
        price: Decimal,
        tags: [String],
        bioSignature: BioSignature?
    ) async throws -> CommunityBioPreset {
        guard let creator = currentUser else {
            throw MarketplaceError.notLoggedIn
        }

        let preset = CommunityBioPreset(
            id: UUID(),
            name: name,
            description: description,
            category: category,
            creatorId: creator.id,
            creatorName: creator.displayName,
            creatorVerified: creator.isVerified,
            bioSignature: bioSignature,
            price: price,
            currency: "EUR",
            downloads: 0,
            rating: 0,
            reviewCount: 0,
            usageCount: 0,
            createdAt: Date(),
            updatedAt: Date(),
            tags: tags,
            previewAudioURL: nil,
            previewImageURL: nil,
            totalRevenue: 0,
            creatorEarnings: 0
        )

        myPresets.append(preset)
        return preset
    }

    /// Get creator earnings summary
    public func getEarningsSummary() -> EarningsSummary {
        guard let creator = currentUser else {
            return EarningsSummary(totalEarnings: 0, pendingPayout: 0, lastPayout: nil, presetBreakdown: [])
        }

        return EarningsSummary(
            totalEarnings: creator.totalEarnings,
            pendingPayout: creator.totalEarnings * 0.1, // Example: 10% pending
            lastPayout: Date().addingTimeInterval(-7 * 24 * 60 * 60),
            presetBreakdown: myPresets.map { ($0.name, $0.creatorEarnings) }
        )
    }

    public struct EarningsSummary {
        public let totalEarnings: Decimal
        public let pendingPayout: Decimal
        public let lastPayout: Date?
        public let presetBreakdown: [(name: String, earnings: Decimal)]
    }

    // MARK: - Helpers

    private func createSamplePreset(
        name: String,
        category: CommunityBioPreset.PresetCategory,
        price: Double,
        downloads: Int
    ) -> CommunityBioPreset {
        CommunityBioPreset(
            id: UUID(),
            name: name,
            description: "A carefully crafted bio-preset for \(category.rawValue.lowercased()) experiences.",
            category: category,
            creatorId: UUID(),
            creatorName: "BioCreator",
            creatorVerified: true,
            bioSignature: BioSignature(
                capturedAt: Date(),
                creatorId: UUID(),
                avgHeartRate: 65,
                avgHRVCoherence: 0.85,
                avgBreathingRate: 6,
                dominantEmotionalState: "calm",
                coherenceTarget: 0.8,
                energyProfile: .balanced,
                breathPattern: .coherent
            ),
            price: Decimal(price),
            currency: "EUR",
            downloads: downloads,
            rating: 4.7,
            reviewCount: downloads / 10,
            usageCount: downloads * 3,
            createdAt: Date().addingTimeInterval(-30 * 24 * 60 * 60),
            updatedAt: Date(),
            tags: [category.rawValue.lowercased(), "bio-reactive", "community"],
            previewAudioURL: nil,
            previewImageURL: nil,
            totalRevenue: Decimal(price) * Decimal(downloads),
            creatorEarnings: Decimal(price) * Decimal(downloads) * Decimal(creatorRevenueShare)
        )
    }

    // MARK: - Errors

    public enum MarketplaceError: LocalizedError {
        case notLoggedIn
        case presetNotFree
        case purchaseFailed(String)
        case publishFailed(String)

        public var errorDescription: String? {
            switch self {
            case .notLoggedIn:
                return "Please log in to access the marketplace"
            case .presetNotFree:
                return "This preset requires purchase"
            case .purchaseFailed(let reason):
                return "Purchase failed: \(reason)"
            case .publishFailed(let reason):
                return "Publishing failed: \(reason)"
            }
        }
    }
}

// MARK: - Marketplace View

public struct BioPresetMarketplaceView: View {
    @ObservedObject private var marketplace = BioPresetMarketplace.shared
    @State private var selectedCategory: BioPresetMarketplace.CommunityBioPreset.PresetCategory?
    @State private var searchText: String = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Banner
                    heroBanner

                    // Categories
                    categoriesSection

                    // Featured Presets
                    if !marketplace.featuredPresets.isEmpty {
                        presetSection(title: "Featured", presets: marketplace.featuredPresets)
                    }

                    // Creator Spotlight
                    creatorSpotlight

                    // Revenue Share Info
                    revenueShareInfo
                }
                .padding()
            }
            .navigationTitle("Bio-Preset Marketplace")
            .searchable(text: $searchText, prompt: "Search presets...")
            .task {
                await marketplace.fetchFeaturedPresets()
            }
        }
    }

    private var heroBanner: some View {
        VStack(spacing: 12) {
            Text("Share Your Bio-Signature")
                .font(.title)
                .fontWeight(.bold)

            Text("Create, share, and earn from bio-reactive presets. Creators receive 70% of every sale.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button {
                    // Browse action
                } label: {
                    Text("Browse Presets")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    // Create action
                } label: {
                    Text("Create Preset")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.2), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BioPresetMarketplace.CommunityBioPreset.PresetCategory.allCases, id: \.self) { category in
                        categoryChip(category)
                    }
                }
            }
        }
    }

    private func categoryChip(_ category: BioPresetMarketplace.CommunityBioPreset.PresetCategory) -> some View {
        Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                Text(category.rawValue)
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selectedCategory == category ? Color(hex: category.color)?.opacity(0.2) : Color(.tertiarySystemBackground))
            .foregroundStyle(selectedCategory == category ? Color(hex: category.color) ?? .primary : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    private func presetSection(title: String, presets: [BioPresetMarketplace.CommunityBioPreset]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("See All") {}
                    .font(.subheadline)
            }

            ForEach(presets) { preset in
                presetCard(preset)
            }
        }
    }

    private func presetCard(_ preset: BioPresetMarketplace.CommunityBioPreset) -> some View {
        HStack(spacing: 12) {
            // Category icon
            Image(systemName: preset.category.icon)
                .font(.title2)
                .foregroundStyle(Color(hex: preset.category.color) ?? .green)
                .frame(width: 50, height: 50)
                .background(Color(hex: preset.category.color)?.opacity(0.1) ?? Color.green.opacity(0.1))
                .cornerRadius(12)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(preset.name)
                        .font(.headline)
                    if preset.creatorVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                Text("by \(preset.creatorName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Label("\(preset.downloads)", systemImage: "arrow.down.circle")
                    Label(String(format: "%.1f", preset.rating), systemImage: "star.fill")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            // Price
            Text(preset.formattedPrice)
                .font(.headline)
                .foregroundStyle(preset.isFree ? .green : .primary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var creatorSpotlight: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.largeTitle)
                        .foregroundStyle(.green)

                    VStack(alignment: .leading) {
                        Text("Become a Creator")
                            .font(.headline)
                        Text("Share your bio-presets and earn 70% of every sale")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    // Apply to become creator
                } label: {
                    Text("Apply Now")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        } label: {
            Label("Creator Program", systemImage: "star.circle.fill")
        }
    }

    private var revenueShareInfo: some View {
        GroupBox {
            VStack(spacing: 16) {
                HStack {
                    VStack {
                        Text("70%")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                        Text("Creator")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()
                        .frame(height: 50)

                    VStack {
                        Text("30%")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("Platform")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text("Fair revenue sharing - creators keep most of their earnings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        } label: {
            Label("Revenue Share", systemImage: "chart.pie.fill")
        }
    }
}

#Preview {
    BioPresetMarketplaceView()
}
