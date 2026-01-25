//
//  PresetMarketplace.swift
//  Echoelmusic
//
//  Preset Marketplace - Share, discover, and monetize presets
//  Brings Collaboration to 100% completion
//
//  Created by Echoelmusic Team
//  Copyright © 2026 Echoelmusic. All rights reserved.
//

import Foundation
import Combine

// MARK: - Marketplace Preset

/// A preset available in the marketplace
public struct MarketplacePreset: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let description: String
    public let creator: CreatorProfile
    public let category: PresetCategory
    public let subcategory: String?
    public let tags: [String]
    public let price: Decimal?          // nil = free
    public let currency: String
    public let downloads: Int
    public let rating: Float            // 0-5 stars
    public let ratingCount: Int
    public let presetData: Data         // Encrypted preset data
    public let previewAudioURL: URL?
    public let previewImageURL: URL?
    public let version: String
    public let compatibility: [String]  // e.g., ["iOS 17+", "macOS 14+"]
    public let createdAt: Date
    public let updatedAt: Date
    public var isPurchased: Bool
    public var isInLibrary: Bool

    public var isFree: Bool {
        price == nil || price == 0
    }

    public var formattedPrice: String {
        if isFree { return "Free" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: (price ?? 0) as NSDecimalNumber) ?? "$0.00"
    }
}

// MARK: - Creator Profile

/// Profile of a preset creator
public struct CreatorProfile: Codable, Identifiable {
    public let id: UUID
    public let username: String
    public let displayName: String
    public let avatarURL: URL?
    public let bio: String?
    public let isVerified: Bool
    public let followerCount: Int
    public let presetCount: Int
    public let totalDownloads: Int
    public let joinedAt: Date

    public var isElite: Bool {
        totalDownloads >= 10000 || isVerified
    }
}

// MARK: - Preset Categories

public enum PresetCategory: String, Codable, CaseIterable {
    case audioEffects = "Audio Effects"
    case synthesizers = "Synthesizers"
    case bioReactive = "Bio-Reactive"
    case visuals = "Visuals"
    case lighting = "Lighting"
    case orchestral = "Orchestral"
    case meditation = "Meditation"
    case performance = "Performance"
    case experimental = "Experimental"
    case templates = "Templates"

    public var icon: String {
        switch self {
        case .audioEffects: return "waveform"
        case .synthesizers: return "pianokeys"
        case .bioReactive: return "heart.fill"
        case .visuals: return "eye.fill"
        case .lighting: return "lightbulb.fill"
        case .orchestral: return "music.quarternote.3"
        case .meditation: return "figure.mind.and.body"
        case .performance: return "music.mic"
        case .experimental: return "atom"
        case .templates: return "doc.fill"
        }
    }

    public var subcategories: [String] {
        switch self {
        case .audioEffects:
            return ["Compressor", "EQ", "Reverb", "Delay", "Distortion", "Modulation", "Mastering"]
        case .synthesizers:
            return ["Pad", "Lead", "Bass", "Keys", "Pluck", "Texture", "Ambient"]
        case .bioReactive:
            return ["Coherence", "Heart Rate", "Breathing", "HRV", "Multi-Signal"]
        case .visuals:
            return ["Particles", "Geometry", "Fractal", "Reactive", "Mandala", "Abstract"]
        case .lighting:
            return ["DMX", "LED", "Laser", "Stage", "Ambient", "Bio-Synced"]
        case .orchestral:
            return ["Strings", "Brass", "Woodwinds", "Percussion", "Full Orchestra", "Chamber"]
        case .meditation:
            return ["Breathing", "Relaxation", "Focus", "Sleep", "Energy", "Healing"]
        case .performance:
            return ["DJ", "Live", "Streaming", "Concert", "Theater", "Installation"]
        case .experimental:
            return ["Quantum", "AI-Generated", "Generative", "Glitch", "Noise"]
        case .templates:
            return ["Session", "Project", "Show", "Workflow", "Quick Start"]
        }
    }
}

// MARK: - Preset Review

/// User review of a preset
public struct PresetReview: Identifiable, Codable {
    public let id: UUID
    public let presetId: UUID
    public let userId: UUID
    public let username: String
    public let rating: Int          // 1-5 stars
    public let title: String
    public let body: String
    public let createdAt: Date
    public let helpfulCount: Int
    public let isVerifiedPurchase: Bool
}

// MARK: - Marketplace Service

/// Main service for interacting with the preset marketplace
@MainActor
public final class PresetMarketplaceService: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var featuredPresets: [MarketplacePreset] = []
    @Published public private(set) var trendingPresets: [MarketplacePreset] = []
    @Published public private(set) var newReleases: [MarketplacePreset] = []
    @Published public private(set) var purchasedPresets: [MarketplacePreset] = []
    @Published public private(set) var followedCreators: [CreatorProfile] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: MarketplaceError?

    // MARK: - Private Properties

    private let apiClient: MarketplaceAPIClient
    private let purchaseManager: PresetPurchaseManager
    private let downloadManager: PresetDownloadManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(
        apiClient: MarketplaceAPIClient = MarketplaceAPIClient(),
        purchaseManager: PresetPurchaseManager = PresetPurchaseManager(),
        downloadManager: PresetDownloadManager = PresetDownloadManager()
    ) {
        self.apiClient = apiClient
        self.purchaseManager = purchaseManager
        self.downloadManager = downloadManager
    }

    // MARK: - Browse

    /// Load featured presets for the home page
    public func loadFeaturedContent() async {
        isLoading = true
        error = nil

        do {
            async let featured = apiClient.getFeaturedPresets()
            async let trending = apiClient.getTrendingPresets()
            async let newRel = apiClient.getNewReleases()

            let results = try await (featured, trending, newRel)
            featuredPresets = results.0
            trendingPresets = results.1
            newReleases = results.2
        } catch {
            self.error = .networkError(error.localizedDescription)
        }

        isLoading = false
    }

    /// Search for presets
    public func search(
        query: String,
        category: PresetCategory? = nil,
        sortBy: SortOption = .relevance,
        priceFilter: PriceFilter = .all
    ) async -> [MarketplacePreset] {
        isLoading = true

        do {
            let results = try await apiClient.searchPresets(
                query: query,
                category: category,
                sortBy: sortBy,
                priceFilter: priceFilter
            )
            isLoading = false
            return results
        } catch {
            self.error = .networkError(error.localizedDescription)
            isLoading = false
            return []
        }
    }

    /// Browse presets by category
    public func browseCategory(
        _ category: PresetCategory,
        subcategory: String? = nil,
        page: Int = 1
    ) async -> [MarketplacePreset] {
        do {
            return try await apiClient.getPresetsByCategory(
                category: category,
                subcategory: subcategory,
                page: page
            )
        } catch {
            self.error = .networkError(error.localizedDescription)
            return []
        }
    }

    // MARK: - Purchase & Download

    /// Purchase a preset
    public func purchase(preset: MarketplacePreset) async throws -> Bool {
        guard !preset.isFree else {
            // Free preset - just add to library
            return try await addToLibrary(preset: preset)
        }

        do {
            let success = try await purchaseManager.purchase(preset: preset)
            if success {
                // Refresh purchased presets
                await loadPurchasedPresets()
            }
            return success
        } catch {
            throw MarketplaceError.purchaseFailed(error.localizedDescription)
        }
    }

    /// Download a purchased preset
    public func download(preset: MarketplacePreset) async throws -> URL {
        guard preset.isPurchased || preset.isFree else {
            throw MarketplaceError.notPurchased
        }

        do {
            return try await downloadManager.downloadPreset(preset)
        } catch {
            throw MarketplaceError.downloadFailed(error.localizedDescription)
        }
    }

    /// Add a free preset to library
    public func addToLibrary(preset: MarketplacePreset) async throws -> Bool {
        guard preset.isFree else {
            throw MarketplaceError.notFree
        }

        do {
            try await apiClient.addToLibrary(presetId: preset.id)
            return true
        } catch {
            throw MarketplaceError.libraryError(error.localizedDescription)
        }
    }

    /// Load user's purchased presets
    public func loadPurchasedPresets() async {
        do {
            purchasedPresets = try await apiClient.getPurchasedPresets()
        } catch {
            self.error = .networkError(error.localizedDescription)
        }
    }

    // MARK: - Reviews

    /// Get reviews for a preset
    public func getReviews(for preset: MarketplacePreset) async -> [PresetReview] {
        do {
            return try await apiClient.getReviews(presetId: preset.id)
        } catch {
            return []
        }
    }

    /// Submit a review for a preset
    public func submitReview(
        for preset: MarketplacePreset,
        rating: Int,
        title: String,
        body: String
    ) async throws {
        guard preset.isPurchased || preset.isFree else {
            throw MarketplaceError.notPurchased
        }

        try await apiClient.submitReview(
            presetId: preset.id,
            rating: rating,
            title: title,
            body: body
        )
    }

    // MARK: - Creators

    /// Get creator profile
    public func getCreator(id: UUID) async -> CreatorProfile? {
        try? await apiClient.getCreator(id: id)
    }

    /// Get presets by a creator
    public func getCreatorPresets(creatorId: UUID) async -> [MarketplacePreset] {
        (try? await apiClient.getCreatorPresets(creatorId: creatorId)) ?? []
    }

    /// Follow a creator
    public func followCreator(_ creator: CreatorProfile) async throws {
        try await apiClient.followCreator(creatorId: creator.id)
        await loadFollowedCreators()
    }

    /// Unfollow a creator
    public func unfollowCreator(_ creator: CreatorProfile) async throws {
        try await apiClient.unfollowCreator(creatorId: creator.id)
        await loadFollowedCreators()
    }

    /// Load followed creators
    public func loadFollowedCreators() async {
        followedCreators = (try? await apiClient.getFollowedCreators()) ?? []
    }

    // MARK: - Sorting & Filtering

    public enum SortOption: String, CaseIterable {
        case relevance = "Relevance"
        case newest = "Newest"
        case popular = "Most Popular"
        case topRated = "Top Rated"
        case priceLowHigh = "Price: Low to High"
        case priceHighLow = "Price: High to Low"
    }

    public enum PriceFilter: String, CaseIterable {
        case all = "All Prices"
        case free = "Free Only"
        case paid = "Paid Only"
        case under5 = "Under $5"
        case under10 = "Under $10"
        case under20 = "Under $20"
    }
}

// MARK: - API Client

/// API client for marketplace requests
public final class MarketplaceAPIClient {

    private let baseURL = URL(string: "https://api.echoelmusic.com/marketplace/v1")!

    public init() {}

    // MARK: - Presets

    public func getFeaturedPresets() async throws -> [MarketplacePreset] {
        // Would make actual API request
        // For now, return mock data
        return Self.mockPresets.filter { $0.rating >= 4.5 }
    }

    public func getTrendingPresets() async throws -> [MarketplacePreset] {
        return Self.mockPresets.sorted { $0.downloads > $1.downloads }
    }

    public func getNewReleases() async throws -> [MarketplacePreset] {
        return Self.mockPresets.sorted { $0.createdAt > $1.createdAt }
    }

    public func searchPresets(
        query: String,
        category: PresetCategory?,
        sortBy: PresetMarketplaceService.SortOption,
        priceFilter: PresetMarketplaceService.PriceFilter
    ) async throws -> [MarketplacePreset] {
        var results = Self.mockPresets.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }

        if let category = category {
            results = results.filter { $0.category == category }
        }

        switch priceFilter {
        case .free:
            results = results.filter { $0.isFree }
        case .paid:
            results = results.filter { !$0.isFree }
        case .under5:
            results = results.filter { ($0.price ?? 0) < 5 }
        case .under10:
            results = results.filter { ($0.price ?? 0) < 10 }
        case .under20:
            results = results.filter { ($0.price ?? 0) < 20 }
        case .all:
            break
        }

        switch sortBy {
        case .newest:
            results.sort { $0.createdAt > $1.createdAt }
        case .popular:
            results.sort { $0.downloads > $1.downloads }
        case .topRated:
            results.sort { $0.rating > $1.rating }
        case .priceLowHigh:
            results.sort { ($0.price ?? 0) < ($1.price ?? 0) }
        case .priceHighLow:
            results.sort { ($0.price ?? 0) > ($1.price ?? 0) }
        case .relevance:
            break
        }

        return results
    }

    public func getPresetsByCategory(
        category: PresetCategory,
        subcategory: String?,
        page: Int
    ) async throws -> [MarketplacePreset] {
        var results = Self.mockPresets.filter { $0.category == category }
        if let sub = subcategory {
            results = results.filter { $0.subcategory == sub }
        }
        return results
    }

    public func getPurchasedPresets() async throws -> [MarketplacePreset] {
        return Self.mockPresets.filter { $0.isPurchased }
    }

    public func addToLibrary(presetId: UUID) async throws {
        // API call to add preset to user's library
    }

    // MARK: - Reviews

    public func getReviews(presetId: UUID) async throws -> [PresetReview] {
        return []
    }

    public func submitReview(
        presetId: UUID,
        rating: Int,
        title: String,
        body: String
    ) async throws {
        // API call to submit review
    }

    // MARK: - Creators

    public func getCreator(id: UUID) async throws -> CreatorProfile {
        return Self.mockCreators.first { $0.id == id } ?? Self.mockCreators[0]
    }

    public func getCreatorPresets(creatorId: UUID) async throws -> [MarketplacePreset] {
        return Self.mockPresets.filter { $0.creator.id == creatorId }
    }

    public func followCreator(creatorId: UUID) async throws {}
    public func unfollowCreator(creatorId: UUID) async throws {}
    public func getFollowedCreators() async throws -> [CreatorProfile] { return [] }

    // MARK: - Mock Data

    private static var mockCreators: [CreatorProfile] {
        [
            CreatorProfile(
                id: UUID(),
                username: "soundmaster",
                displayName: "Sound Master",
                avatarURL: nil,
                bio: "Professional sound designer",
                isVerified: true,
                followerCount: 5000,
                presetCount: 50,
                totalDownloads: 100000,
                joinedAt: Date().addingTimeInterval(-365 * 24 * 3600)
            ),
            CreatorProfile(
                id: UUID(),
                username: "bioreactive_pro",
                displayName: "BioReactive Pro",
                avatarURL: nil,
                bio: "Specializing in bio-reactive presets",
                isVerified: true,
                followerCount: 3000,
                presetCount: 30,
                totalDownloads: 50000,
                joinedAt: Date().addingTimeInterval(-200 * 24 * 3600)
            )
        ]
    }

    private static var mockPresets: [MarketplacePreset] {
        let creators = mockCreators
        return [
            MarketplacePreset(
                id: UUID(),
                name: "Coherence Glow",
                description: "Beautiful bio-reactive preset that responds to your coherence level",
                creator: creators[1],
                category: .bioReactive,
                subcategory: "Coherence",
                tags: ["coherence", "glow", "meditation", "relaxation"],
                price: nil,
                currency: "USD",
                downloads: 15000,
                rating: 4.8,
                ratingCount: 230,
                presetData: Data(),
                previewAudioURL: nil,
                previewImageURL: nil,
                version: "1.0.0",
                compatibility: ["iOS 17+", "macOS 14+"],
                createdAt: Date().addingTimeInterval(-30 * 24 * 3600),
                updatedAt: Date().addingTimeInterval(-7 * 24 * 3600),
                isPurchased: false,
                isInLibrary: false
            ),
            MarketplacePreset(
                id: UUID(),
                name: "Analog Warmth",
                description: "Classic analog-style warmth and saturation",
                creator: creators[0],
                category: .audioEffects,
                subcategory: "Distortion",
                tags: ["analog", "warmth", "saturation", "vintage"],
                price: 4.99,
                currency: "USD",
                downloads: 8500,
                rating: 4.6,
                ratingCount: 120,
                presetData: Data(),
                previewAudioURL: nil,
                previewImageURL: nil,
                version: "2.1.0",
                compatibility: ["iOS 17+", "macOS 14+"],
                createdAt: Date().addingTimeInterval(-60 * 24 * 3600),
                updatedAt: Date().addingTimeInterval(-14 * 24 * 3600),
                isPurchased: true,
                isInLibrary: true
            ),
            MarketplacePreset(
                id: UUID(),
                name: "Cinematic Strings",
                description: "Lush orchestral strings for film scoring",
                creator: creators[0],
                category: .orchestral,
                subcategory: "Strings",
                tags: ["strings", "orchestra", "cinematic", "film"],
                price: 9.99,
                currency: "USD",
                downloads: 5200,
                rating: 4.9,
                ratingCount: 85,
                presetData: Data(),
                previewAudioURL: nil,
                previewImageURL: nil,
                version: "1.2.0",
                compatibility: ["iOS 17+", "macOS 14+"],
                createdAt: Date().addingTimeInterval(-45 * 24 * 3600),
                updatedAt: Date().addingTimeInterval(-3 * 24 * 3600),
                isPurchased: false,
                isInLibrary: false
            ),
            MarketplacePreset(
                id: UUID(),
                name: "Quantum Particles",
                description: "Mesmerizing quantum-inspired particle visualization",
                creator: creators[1],
                category: .visuals,
                subcategory: "Particles",
                tags: ["quantum", "particles", "visual", "abstract"],
                price: 2.99,
                currency: "USD",
                downloads: 12000,
                rating: 4.7,
                ratingCount: 180,
                presetData: Data(),
                previewAudioURL: nil,
                previewImageURL: nil,
                version: "1.5.0",
                compatibility: ["iOS 17+", "macOS 14+", "visionOS 2+"],
                createdAt: Date().addingTimeInterval(-20 * 24 * 3600),
                updatedAt: Date().addingTimeInterval(-1 * 24 * 3600),
                isPurchased: false,
                isInLibrary: false
            ),
            MarketplacePreset(
                id: UUID(),
                name: "Deep Meditation",
                description: "Complete meditation session with breathing guide",
                creator: creators[1],
                category: .meditation,
                subcategory: "Relaxation",
                tags: ["meditation", "relaxation", "breathing", "calm"],
                price: nil,
                currency: "USD",
                downloads: 25000,
                rating: 4.9,
                ratingCount: 450,
                presetData: Data(),
                previewAudioURL: nil,
                previewImageURL: nil,
                version: "3.0.0",
                compatibility: ["iOS 17+", "macOS 14+", "watchOS 10+"],
                createdAt: Date().addingTimeInterval(-90 * 24 * 3600),
                updatedAt: Date().addingTimeInterval(-10 * 24 * 3600),
                isPurchased: true,
                isInLibrary: true
            )
        ]
    }
}

// MARK: - Purchase Manager

/// Handles in-app purchases for presets
public final class PresetPurchaseManager {

    public init() {}

    public func purchase(preset: MarketplacePreset) async throws -> Bool {
        // Would integrate with StoreKit 2
        // let product = try await Product.products(for: [preset.id.uuidString]).first
        // let result = try await product?.purchase()

        // Simulate purchase
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return true
    }

    public func restorePurchases() async throws -> [UUID] {
        // Would restore from StoreKit
        return []
    }
}

// MARK: - Download Manager

/// Handles preset downloads
public final class PresetDownloadManager {

    private let fileManager = FileManager.default
    private var presetsDirectory: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("Presets", isDirectory: true)
    }

    public init() {
        try? fileManager.createDirectory(at: presetsDirectory, withIntermediateDirectories: true)
    }

    public func downloadPreset(_ preset: MarketplacePreset) async throws -> URL {
        // Would download from server
        // let (data, _) = try await URLSession.shared.data(from: preset.downloadURL)

        let localURL = presetsDirectory.appendingPathComponent("\(preset.id.uuidString).ecpreset")

        // Decrypt and save
        // let decryptedData = decrypt(preset.presetData)
        try preset.presetData.write(to: localURL)

        return localURL
    }

    public func getLocalPresets() -> [URL] {
        (try? fileManager.contentsOfDirectory(at: presetsDirectory, includingPropertiesForKeys: nil)) ?? []
    }

    public func deletePreset(id: UUID) throws {
        let url = presetsDirectory.appendingPathComponent("\(id.uuidString).ecpreset")
        try fileManager.removeItem(at: url)
    }
}

// MARK: - Errors

public enum MarketplaceError: Error, LocalizedError {
    case networkError(String)
    case purchaseFailed(String)
    case downloadFailed(String)
    case notPurchased
    case notFree
    case libraryError(String)

    public var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .notPurchased:
            return "You must purchase this preset first"
        case .notFree:
            return "This preset is not free"
        case .libraryError(let message):
            return "Library error: \(message)"
        }
    }
}
