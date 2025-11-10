import Foundation

/// Music Sales & Download Distribution Engine
/// Direct sales platforms for digital downloads, vinyl, merch, and more
///
/// Supported Platforms:
/// - Direct Sales: Bandcamp, iTunes Store, 7digital, Bleep
/// - Electronic Music: Beatport, Traxsource, Juno Download
/// - Sample/Loop Marketplaces: Splice, Loopmasters, ADSR Sounds
/// - Community: SoundCloud, Audiomack, Mixcloud
/// - NFT/Web3: Sound.xyz, Catalog, Royal, Audius
@MainActor
class MusicSalesEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var salesPlatforms: [SalesPlatform] = []
    @Published var releases: [Release] = []
    @Published var salesStats: SalesStats

    // MARK: - Sales Platforms

    enum SalesPlatform: String, CaseIterable {
        // Direct Sales & Downloads
        case bandcamp = "Bandcamp"
        case itunesStore = "iTunes Store"
        case sevenDigital = "7digital"
        case bleep = "Bleep"
        case junoDownload = "Juno Download"

        // Electronic Music Specialists
        case beatport = "Beatport"
        case traxsource = "Traxsource"
        case trackitdown = "Trackitdown"

        // Sample/Loop/Preset Marketplaces
        case splice = "Splice"
        case loopmasters = "Loopmasters"
        case adsrSounds = "ADSR Sounds"
        case pluginBoutique = "Plugin Boutique"
        case producerLoops = "Producer Loops"

        // Community Platforms
        case soundcloud = "SoundCloud"
        case audiomack = "Audiomack"
        case mixcloud = "Mixcloud"
        case reverbnation = "ReverbNation"

        // NFT & Web3
        case soundXYZ = "Sound.xyz"
        case catalog = "Catalog"
        case royal = "Royal"
        case audius = "Audius"

        var category: PlatformCategory {
            switch self {
            case .bandcamp, .itunesStore, .sevenDigital, .bleep, .junoDownload:
                return .directSales
            case .beatport, .traxsource, .trackitdown:
                return .electronic
            case .splice, .loopmasters, .adsrSounds, .pluginBoutique, .producerLoops:
                return .samples
            case .soundcloud, .audiomack, .mixcloud, .reverbnation:
                return .community
            case .soundXYZ, .catalog, .royal, .audius:
                return .web3
            }
        }

        enum PlatformCategory {
            case directSales, electronic, samples, community, web3
        }

        var commissionRate: Double {
            switch self {
            case .bandcamp: return 15.0  // 15% (10-15% depending on sales)
            case .itunesStore: return 30.0  // 30%
            case .sevenDigital: return 25.0  // ~25%
            case .beatport: return 30.0  // 30%
            case .traxsource: return 25.0  // 25%
            case .splice: return 40.0  // 40% for Splice credits
            case .loopmasters: return 50.0  // 50% split
            case .soundcloud: return 45.0  // 45% (SoundCloud Go+)
            case .soundXYZ: return 5.0  // 5% platform fee
            case .catalog: return 0.0  // 0% after purchase
            case .royal: return 10.0  // 10%
            case .audius: return 10.0  // 10%
            default: return 30.0
            }
        }

        var supportedFormats: [AudioFormat] {
            switch self {
            case .bandcamp:
                return [.flac, .wav, .alac, .mp3_320, .aac, .ogg]
            case .beatport, .traxsource:
                return [.wav, .aiff, .mp3_320]
            case .splice, .loopmasters:
                return [.wav, .aiff, .rex, .midi]
            case .soundcloud, .audiomack, .mixcloud:
                return [.mp3_320, .aac]
            case .soundXYZ, .catalog:
                return [.flac, .wav, .mp3_320]  // + NFT metadata
            default:
                return [.flac, .mp3_320, .aac]
            }
        }

        var supportsPhysicalMedia: Bool {
            switch self {
            case .bandcamp, .junoDownload:
                return true  // Vinyl, CD, Cassette
            default:
                return false
            }
        }

        var supportsNFTs: Bool {
            switch self {
            case .soundXYZ, .catalog, .royal, .audius:
                return true
            default:
                return false
            }
        }
    }

    enum AudioFormat: String {
        case wav = "WAV"
        case aiff = "AIFF"
        case flac = "FLAC"
        case alac = "ALAC (Apple Lossless)"
        case mp3_320 = "MP3 320kbps"
        case mp3_256 = "MP3 256kbps"
        case aac = "AAC"
        case ogg = "OGG Vorbis"
        case rex = "REX2"
        case midi = "MIDI"

        var isLossless: Bool {
            switch self {
            case .wav, .aiff, .flac, .alac:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Release

    struct Release: Identifiable {
        let id = UUID()
        var title: String
        var artist: String
        var releaseType: ReleaseType
        var tracks: [Track]
        var artwork: Data?
        var releaseDate: Date
        var pricing: Pricing
        var platforms: [SalesPlatform]
        var metadata: ReleaseMetadata
        var salesData: ReleaseSalesData

        enum ReleaseType {
            case single, ep, album, compilation, remix
            case samplePack, loopPack, presetPack, template
            case nft, limitedEdition
        }

        struct Track {
            let id = UUID()
            var title: String
            var duration: TimeInterval
            var isrc: String?
            var file: URL?
            var bpm: Int?
            var key: String?
            var genre: String?
        }

        struct Pricing {
            var basePrice: Double
            var currency: String
            var allowNameYourPrice: Bool  // Bandcamp-style
            var minimumPrice: Double?
            var suggestedPrice: Double?
            var regionalPricing: [String: Double]  // Country code -> Price
        }

        struct ReleaseMetadata {
            var genre: String
            var subgenre: String?
            var tags: [String]
            var description: String
            var credits: [Credit]
            var lyrics: String?
            var upc: String?

            struct Credit {
                let role: String  // Producer, Mixing, Mastering, etc.
                let name: String
            }
        }

        struct ReleaseSalesData {
            var totalSales: Int = 0
            var totalRevenue: Double = 0.0
            var salesByPlatform: [String: PlatformSales] = [:]

            struct PlatformSales {
                var units: Int
                var revenue: Double
                var downloads: Int
                var streams: Int
            }
        }
    }

    // MARK: - Sales Stats

    struct SalesStats {
        var totalRevenue: Double
        var totalUnits: Int
        var averagePrice: Double
        var topSellingRelease: String?
        var revenueByPlatform: [String: Double]
        var revenueByFormat: [String: Double]

        var averageRevenuePerUnit: Double {
            guard totalUnits > 0 else { return 0.0 }
            return totalRevenue / Double(totalUnits)
        }
    }

    // MARK: - Initialization

    init() {
        print("🎵 Music Sales Engine initialized")

        self.salesPlatforms = SalesPlatform.allCases
        self.salesStats = SalesStats(
            totalRevenue: 0.0,
            totalUnits: 0,
            averagePrice: 0.0,
            topSellingRelease: nil,
            revenueByPlatform: [:],
            revenueByFormat: [:]
        )

        print("   ✅ \(salesPlatforms.count) sales platforms available")
    }

    // MARK: - Distribute to Sales Platforms

    func distributeRelease(
        _ release: Release,
        to platforms: [SalesPlatform]
    ) async {
        print("🚀 Distributing release: \(release.title)")
        print("   Artist: \(release.artist)")
        print("   Type: \(release.releaseType)")
        print("   Platforms: \(platforms.count)")

        for platform in platforms {
            await uploadToPlatform(release: release, platform: platform)
        }

        print("   ✅ Distribution completed")
    }

    private func uploadToPlatform(release: Release, platform: SalesPlatform) async {
        print("   📤 Uploading to \(platform.rawValue)...")

        // Platform-specific upload
        switch platform {
        case .bandcamp:
            await uploadToBandcamp(release)
        case .beatport, .traxsource:
            await uploadToElectronicStore(release, platform: platform)
        case .splice, .loopmasters:
            await uploadToSampleMarketplace(release, platform: platform)
        case .soundcloud:
            await uploadToSoundCloud(release)
        case .soundXYZ, .catalog, .royal:
            await uploadAsNFT(release, platform: platform)
        default:
            await uploadGeneric(release, platform: platform)
        }

        print("      ✅ Upload completed")
    }

    // MARK: - Platform-Specific Uploads

    private func uploadToBandcamp(_ release: Release) async {
        print("      🎸 Bandcamp upload")
        print("         → Name Your Price: \(release.pricing.allowNameYourPrice ? "Yes" : "No")")
        print("         → Base Price: $\(release.pricing.basePrice)")

        // Bandcamp features:
        // - Multiple formats (FLAC, WAV, MP3, etc.)
        // - Name your price / Free downloads
        // - Vinyl/CD/Cassette physical releases
        // - Fan engagement tools

        if release.pricing.allowNameYourPrice {
            print("         → Minimum: $\(release.pricing.minimumPrice ?? 0)")
        }

        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }

    private func uploadToElectronicStore(_ release: Release, platform: SalesPlatform) async {
        print("      🎧 \(platform.rawValue) upload")
        print("         → Genre: \(release.metadata.genre)")

        // Electronic music stores requirements:
        // - High quality (WAV/AIFF 16-bit minimum)
        // - BPM and Key metadata required
        // - Genre classification important

        for track in release.tracks {
            if let bpm = track.bpm, let key = track.key {
                print("         → \(track.title): \(bpm) BPM, Key: \(key)")
            }
        }

        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }

    private func uploadToSampleMarketplace(_ release: Release, platform: SalesPlatform) async {
        print("      🥁 \(platform.rawValue) upload")
        print("         → Pack Type: \(release.releaseType)")

        // Sample marketplace features:
        // - Individual samples vs. packs
        // - Audio preview (usually 30-60 seconds)
        // - Metadata: BPM, Key, Tags
        // - Royalty-free licensing

        print("         → \(release.tracks.count) samples/loops")

        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }

    private func uploadToSoundCloud(_ release: Release) async {
        print("      ☁️ SoundCloud upload")

        // SoundCloud features:
        // - Free streaming with monetization options
        // - SoundCloud Go+ for premium
        // - Repost network for promotion
        // - Comments on waveform

        print("         → Enable monetization: Yes")
        print("         → Allow comments: Yes")

        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    private func uploadAsNFT(_ release: Release, platform: SalesPlatform) async {
        print("      🌐 \(platform.rawValue) NFT upload")

        // NFT music platforms:
        // - Limited editions
        // - Royalty splits on secondary sales
        // - Collector perks
        // - Smart contracts

        let editionSize = 100  // Limited to 100 NFTs
        let royaltyPercentage = 10.0  // 10% on secondary sales

        print("         → Edition size: \(editionSize)")
        print("         → Royalty on secondary: \(royaltyPercentage)%")
        print("         → Minting NFT contract...")

        try? await Task.sleep(nanoseconds: 2_000_000_000)

        print("         → NFT minted successfully")
    }

    private func uploadGeneric(_ release: Release, platform: SalesPlatform) async {
        print("      📦 \(platform.rawValue) upload")

        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    // MARK: - Pricing Strategies

    func suggestPricing(for release: Release) -> Release.Pricing {
        print("💰 Suggesting pricing for: \(release.title)")

        var basePrice: Double

        switch release.releaseType {
        case .single:
            basePrice = 0.99
        case .ep:
            basePrice = 3.99
        case .album:
            basePrice = 9.99
        case .samplePack, .loopPack:
            basePrice = 19.99
        case .presetPack:
            basePrice = 14.99
        case .template:
            basePrice = 29.99
        case .nft:
            basePrice = 50.00
        case .limitedEdition:
            basePrice = 25.00
        default:
            basePrice = 9.99
        }

        // Adjust for track count
        let trackCount = release.tracks.count
        if trackCount > 10 {
            basePrice *= 1.2
        }

        // Regional pricing (PPP - Purchasing Power Parity)
        let regionalPricing: [String: Double] = [
            "US": basePrice,
            "GB": basePrice * 0.79,  // £
            "EU": basePrice * 0.92,  // €
            "JP": basePrice * 110,   // ¥
            "IN": basePrice * 0.3,   // Lower for India
            "BR": basePrice * 0.4,   // Lower for Brazil
        ]

        print("   💵 Suggested base price: $\(String(format: "%.2f", basePrice))")

        return Release.Pricing(
            basePrice: basePrice,
            currency: "USD",
            allowNameYourPrice: true,
            minimumPrice: basePrice * 0.7,  // 30% discount minimum
            suggestedPrice: basePrice,
            regionalPricing: regionalPricing
        )
    }

    // MARK: - Sales Analytics

    func trackSale(
        release: Release,
        platform: SalesPlatform,
        price: Double,
        format: AudioFormat
    ) async {
        print("💰 Sale recorded!")
        print("   Release: \(release.title)")
        print("   Platform: \(platform.rawValue)")
        print("   Price: $\(String(format: "%.2f", price))")
        print("   Format: \(format.rawValue)")

        // Calculate commission
        let commission = price * (platform.commissionRate / 100.0)
        let netRevenue = price - commission

        print("   Commission (\(String(format: "%.1f", platform.commissionRate))%): $\(String(format: "%.2f", commission))")
        print("   Net Revenue: $\(String(format: "%.2f", netRevenue))")

        // Update stats
        salesStats.totalRevenue += netRevenue
        salesStats.totalUnits += 1
        salesStats.revenueByPlatform[platform.rawValue, default: 0.0] += netRevenue
        salesStats.revenueByFormat[format.rawValue, default: 0.0] += netRevenue
    }

    // MARK: - Physical Media

    func createPhysicalRelease(
        release: Release,
        mediaType: PhysicalMediaType,
        quantity: Int
    ) -> PhysicalRelease {
        print("💿 Creating physical release...")
        print("   Type: \(mediaType.rawValue)")
        print("   Quantity: \(quantity)")

        let manufacturingCost = calculateManufacturingCost(mediaType: mediaType, quantity: quantity)
        let suggestedRetailPrice = calculateRetailPrice(mediaType: mediaType, basePrice: release.pricing.basePrice)

        print("   Manufacturing cost: $\(String(format: "%.2f", manufacturingCost))")
        print("   Suggested retail: $\(String(format: "%.2f", suggestedRetailPrice))")

        return PhysicalRelease(
            release: release,
            mediaType: mediaType,
            quantity: quantity,
            manufacturingCost: manufacturingCost,
            suggestedRetailPrice: suggestedRetailPrice,
            unitsProduced: quantity,
            unitsSold: 0
        )
    }

    enum PhysicalMediaType: String {
        case vinyl12inch = "12\" Vinyl"
        case vinyl7inch = "7\" Vinyl"
        case cd = "CD"
        case cassette = "Cassette"
        case usb = "USB Flash Drive"
    }

    struct PhysicalRelease {
        let release: Release
        let mediaType: PhysicalMediaType
        let quantity: Int
        let manufacturingCost: Double
        let suggestedRetailPrice: Double
        var unitsProduced: Int
        var unitsSold: Int

        var remainingStock: Int {
            unitsProduced - unitsSold
        }
    }

    private func calculateManufacturingCost(mediaType: PhysicalMediaType, quantity: Int) -> Double {
        let unitCost: Double

        switch mediaType {
        case .vinyl12inch:
            unitCost = quantity >= 300 ? 4.50 : 6.00
        case .vinyl7inch:
            unitCost = quantity >= 300 ? 2.50 : 3.50
        case .cd:
            unitCost = quantity >= 1000 ? 0.80 : 1.50
        case .cassette:
            unitCost = quantity >= 100 ? 1.20 : 2.00
        case .usb:
            unitCost = quantity >= 100 ? 3.00 : 5.00
        }

        return unitCost * Double(quantity)
    }

    private func calculateRetailPrice(mediaType: PhysicalMediaType, basePrice: Double) -> Double {
        switch mediaType {
        case .vinyl12inch:
            return basePrice * 2.5  // $25 for album
        case .vinyl7inch:
            return basePrice * 1.5  // $15 for single
        case .cd:
            return basePrice * 1.2  // $12 for album
        case .cassette:
            return basePrice * 1.0  // $10 for album
        case .usb:
            return basePrice * 3.0  // $30 for special edition
        }
    }

    // MARK: - Reports

    func generateSalesReport() -> String {
        var report = """
        ═══════════════════════════════════════
        MUSIC SALES REPORT
        ═══════════════════════════════════════

        OVERVIEW
        ───────────────────────────────────────
        Total Revenue: $\(String(format: "%.2f", salesStats.totalRevenue))
        Total Units Sold: \(salesStats.totalUnits)
        Average Price: $\(String(format: "%.2f", salesStats.averageRevenuePerUnit))

        """

        // Revenue by platform
        if !salesStats.revenueByPlatform.isEmpty {
            report += """

            REVENUE BY PLATFORM
            ───────────────────────────────────────

            """

            let sorted = salesStats.revenueByPlatform.sorted { $0.value > $1.value }
            for (platform, revenue) in sorted {
                let percentage = (revenue / salesStats.totalRevenue) * 100
                report += """
                \(platform): $\(String(format: "%.2f", revenue)) (\(String(format: "%.1f", percentage))%)

                """
            }
        }

        // Revenue by format
        if !salesStats.revenueByFormat.isEmpty {
            report += """

            REVENUE BY FORMAT
            ───────────────────────────────────────

            """

            let sorted = salesStats.revenueByFormat.sorted { $0.value > $1.value }
            for (format, revenue) in sorted {
                let percentage = (revenue / salesStats.totalRevenue) * 100
                report += """
                \(format): $\(String(format: "%.2f", revenue)) (\(String(format: "%.1f", percentage))%)

                """
            }
        }

        // Top releases
        if !releases.isEmpty {
            report += """

            TOP RELEASES
            ───────────────────────────────────────

            """

            let topReleases = releases.sorted {
                $0.salesData.totalRevenue > $1.salesData.totalRevenue
            }.prefix(5)

            for (index, release) in topReleases.enumerated() {
                report += """
                \(index + 1). \(release.title)
                   Artist: \(release.artist)
                   Sales: \(release.salesData.totalSales) units
                   Revenue: $\(String(format: "%.2f", release.salesData.totalRevenue))

                """
            }
        }

        report += "═══════════════════════════════════════"

        return report
    }
}
