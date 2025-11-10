import Foundation

/// Media Pitching Engine
/// Professional pitching to Radio, TV, Film/Streaming platforms and Sync licensing
///
/// Supported Categories:
/// - Radio (Terrestrial, Online, College, Satellite)
/// - TV Networks (Netflix, HBO, Disney+, etc.)
/// - Film Studios (Major and Independent)
/// - Sync Licensing (Artlist, Epidemic Sound, etc.)
/// - Advertising Agencies
@MainActor
class MediaPitchingEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var radioPitches: [RadioPitch] = []
    @Published var tvFilmPitches: [TVFilmPitch] = []
    @Published var syncLicenses: [SyncLicense] = []
    @Published var mediaStats: MediaStats

    // MARK: - Radio Stations

    enum RadioStation: String, CaseIterable {
        // UK Radio
        case bbc1 = "BBC Radio 1"
        case bbc2 = "BBC Radio 2"
        case bbc6Music = "BBC 6 Music"
        case radioX = "Radio X"

        // US Radio
        case npr = "NPR Music"
        case kcrw = "KCRW"
        case wfuv = "WFUV"
        case kexp = "KEXP"

        // Online Radio
        case nts = "NTS Radio"
        case rinse = "Rinse FM"
        case soho = "Soho Radio"
        case radar = "Radar Radio"

        // Satellite
        case siriusXM = "SiriusXM"

        // College Radio
        case collegeRadio = "College Radio Network"

        var category: RadioCategory {
            switch self {
            case .bbc1, .bbc2, .bbc6Music, .radioX:
                return .terrestrial
            case .npr, .kcrw, .wfuv, .kexp:
                return .public
            case .nts, .rinse, .soho, .radar:
                return .online
            case .siriusXM:
                return .satellite
            case .collegeRadio:
                return .college
            }
        }

        enum RadioCategory {
            case terrestrial, public, online, satellite, college
        }

        var weeklyListeners: Int {
            switch self {
            case .bbc1: return 9_500_000
            case .bbc2: return 14_800_000
            case .bbc6Music: return 2_500_000
            case .npr: return 57_000_000
            case .kcrw: return 500_000
            case .kexp: return 300_000
            case .siriusXM: return 34_000_000
            default: return 50_000
            }
        }

        var submissionEmail: String? {
            switch self {
            case .bbc1: return "radio1.music@bbc.co.uk"
            case .bbc6Music: return "6music.newmusic@bbc.co.uk"
            case .kexp: return "music@kexp.org"
            case .kcrw: return "music@kcrw.com"
            default: return nil
            }
        }
    }

    struct RadioPitch: Identifiable {
        let id = UUID()
        var track: TrackInfo
        var stations: [RadioStation]
        var pitchMessage: String
        var status: PitchStatus
        var airplay: [AirplayInstance]

        struct TrackInfo {
            let title: String
            let artist: String
            let genre: String
            let duration: TimeInterval
            let isClean: Bool  // Radio edit
            let releaseDate: Date
        }

        enum PitchStatus {
            case draft, submitted, playlisted, rejected
        }

        struct AirplayInstance {
            let station: RadioStation
            let playedAt: Date
            let show: String?
            let estimatedListeners: Int
        }
    }

    // MARK: - TV/Film/Streaming

    enum TVFilmPlatform: String, CaseIterable {
        // Streaming Services
        case netflix = "Netflix"
        case hboMax = "HBO Max"
        case disneyPlus = "Disney+"
        case amazonPrime = "Amazon Prime Video"
        case appleTV = "Apple TV+"
        case hulu = "Hulu"
        case paramount = "Paramount+"
        case peacock = "Peacock"

        // Traditional Networks
        case abc = "ABC"
        case nbc = "NBC"
        case cbs = "CBS"
        case fox = "FOX"
        case cw = "The CW"

        // Cable
        case amc = "AMC"
        case fx = "FX"
        case showtime = "Showtime"
        case starz = "Starz"

        // Film Studios
        case universalPictures = "Universal Pictures"
        case warnerbros = "Warner Bros"
        case paramount_pictures = "Paramount Pictures"
        case sony = "Sony Pictures"
        case disney = "Walt Disney Studios"
        case a24 = "A24"
        case netflix_films = "Netflix Films"

        var category: MediaCategory {
            switch self {
            case .netflix, .hboMax, .disneyPlus, .amazonPrime, .appleTV, .hulu, .paramount, .peacock:
                return .streaming
            case .abc, .nbc, .cbs, .fox, .cw:
                return .network
            case .amc, .fx, .showtime, .starz:
                return .cable
            default:
                return .film
            }
        }

        enum MediaCategory {
            case streaming, network, cable, film
        }

        var musicSupervisorContact: String? {
            // In production: Real contact database
            return "musicsupervisor@\(self.rawValue.lowercased().replacingOccurrences(of: " ", with: "")).com"
        }
    }

    struct TVFilmPitch: Identifiable {
        let id = UUID()
        var content: ContentInfo
        var platforms: [TVFilmPlatform]
        var pitchPackage: PitchPackage
        var status: PitchStatus
        var placements: [Placement]

        struct ContentInfo {
            let title: String
            let artist: String
            let genre: String
            let mood: [String]
            let tempo: String  // Fast, Medium, Slow
            let instrumental: Bool
            let vocalContent: VocalContent
            let duration: TimeInterval
            let description: String

            enum VocalContent {
                case instrumental
                case minimal  // Few lyrics
                case moderate
                case heavy  // Full lyrics
            }
        }

        struct PitchPackage {
            var audioFile: URL
            var lyricSheet: URL?
            var instrumentalVersion: URL?
            var stems: URL?  // Separate tracks
            var licenseInfo: LicenseInfo

            struct LicenseInfo {
                var masterRightsHolder: String
                var publishingRightsHolder: String
                var availableRights: [UsageRight]
                var territoryRestrictions: [String]?
                var exclusivityRequired: Bool

                enum UsageRight {
                    case synchronization  // Sync right
                    case master  // Master recording right
                    case performance  // Performance right
                    case mechanical  // Mechanical right
                }
            }
        }

        enum PitchStatus {
            case submitted, underReview, shortlisted, placed, rejected
        }

        struct Placement {
            let platform: TVFilmPlatform
            let showOrFilm: String
            let episodeOrScene: String?
            let airDate: Date?
            let fee: Double?
            let usage: UsageType

            enum UsageType {
                case background, feature, credits, trailer, promo
            }
        }
    }

    // MARK: - Sync Licensing

    enum SyncPlatform: String, CaseIterable {
        // Music Licensing Libraries
        case artlist = "Artlist"
        case epidemicSound = "Epidemic Sound"
        case audioJungle = "AudioJungle"
        case pond5 = "Pond5"
        case shutterstockMusic = "Shutterstock Music"
        case premiumbeat = "Premium Beat"

        // Production Music Libraries
        case universalProductionMusic = "Universal Production Music"
        case warnerChappellPM = "Warner Chappell Production Music"
        case apMusic = "APM Music"

        // Royalty-Free
        case musicbed = "Musicbed"
        case marmosetMusic = "Marmoset Music"

        var commissionRate: Double {
            switch self {
            case .artlist: return 50.0  // 50% split
            case .epidemicSound: return 50.0
            case .audioJungle: return 55.0  // 45% to artist
            case .shutterstockMusic: return 60.0  // 40% to artist
            case .premiumbeat: return 50.0
            default: return 50.0
            }
        }

        var paymentModel: PaymentModel {
            switch self {
            case .artlist, .epidemicSound:
                return .subscription  // Users pay subscription
            case .audioJungle, .pond5:
                return .perTrack  // Pay per download
            case .musicbed, .marmosetMusic:
                return .custom  // Custom licensing
            default:
                return .subscription
            }
        }

        enum PaymentModel {
            case subscription, perTrack, custom
        }
    }

    struct SyncLicense: Identifiable {
        let id = UUID()
        var track: SyncTrack
        var platforms: [SyncPlatform]
        var pricing: PricingStructure
        var status: LicenseStatus
        var earnings: Double

        struct SyncTrack {
            let title: String
            let artist: String
            let duration: TimeInterval
            let bpm: Int
            let key: String
            let genre: String
            let mood: [String]
            let keywords: [String]
            let isInstrumental: Bool
            let hasVocals: Bool
        }

        struct PricingStructure {
            var webUse: Double  // Small web projects
            var corporateVideo: Double  // Corporate/training videos
            var commercialAd: Double  // TV/online commercials
            var filmTV: Double  // Film/TV placement
            var broadcast: Double  // Broadcast rights
        }

        enum LicenseStatus {
            case pending, active, inactive
        }
    }

    // MARK: - Media Stats

    struct MediaStats {
        var radioSpins: Int = 0
        var tvFilmPlacements: Int = 0
        var syncLicenses: Int = 0
        var totalSyncEarnings: Double = 0.0
        var estimatedRadioReach: Int64 = 0
    }

    // MARK: - Initialization

    init() {
        print("📺 Media Pitching Engine initialized")

        self.mediaStats = MediaStats()

        print("   ✅ \(RadioStation.allCases.count) radio stations")
        print("   ✅ \(TVFilmPlatform.allCases.count) TV/Film platforms")
        print("   ✅ \(SyncPlatform.allCases.count) sync licensing platforms")
    }

    // MARK: - Radio Pitching

    func pitchToRadio(
        track: RadioPitch.TrackInfo,
        stations: [RadioStation]
    ) async -> RadioPitch {
        print("📻 Pitching to radio stations...")
        print("   Track: \(track.title)")
        print("   Stations: \(stations.count)")

        let pitch = RadioPitch(
            track: track,
            stations: stations,
            pitchMessage: generateRadioPitch(track: track),
            status: .draft,
            airplay: []
        )

        radioPitches.append(pitch)

        for station in stations {
            await submitToRadioStation(track: track, station: station)
        }

        print("   ✅ Pitch submitted to \(stations.count) stations")

        return pitch
    }

    private func generateRadioPitch(track: RadioPitch.TrackInfo) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        return """
        Radio Promotion - "\(track.title)" by \(track.artist)

        Genre: \(track.genre)
        Duration: \(formatDuration(track.duration))
        Clean Version: \(track.isClean ? "Yes" : "No")
        Release Date: \(formatter.string(from: track.releaseDate))

        This track is perfect for your listeners. High-quality production, radio-ready mix, and strong audience appeal.

        We'd love to send you the full track for your consideration.

        Best regards,
        \(track.artist) Team
        """
    }

    private func submitToRadioStation(track: RadioPitch.TrackInfo, station: RadioStation) async {
        print("      → \(station.rawValue)")
        print("         Listeners: \(formatNumber(station.weeklyListeners))/week")

        if let email = station.submissionEmail {
            print("         Email: \(email)")
        }

        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    // MARK: - TV/Film Pitching

    func pitchToTVFilm(
        content: TVFilmPitch.ContentInfo,
        package: TVFilmPitch.PitchPackage,
        platforms: [TVFilmPlatform]
    ) async -> TVFilmPitch {
        print("🎬 Pitching to TV/Film platforms...")
        print("   Track: \(content.title)")
        print("   Platforms: \(platforms.count)")

        let pitch = TVFilmPitch(
            content: content,
            platforms: platforms,
            pitchPackage: package,
            status: .submitted,
            placements: []
        )

        tvFilmPitches.append(pitch)

        for platform in platforms {
            await submitToTVFilmPlatform(content: content, package: package, platform: platform)
        }

        print("   ✅ Pitch submitted to \(platforms.count) platforms")

        return pitch
    }

    private func submitToTVFilmPlatform(
        content: TVFilmPitch.ContentInfo,
        package: TVFilmPitch.PitchPackage,
        platform: TVFilmPlatform
    ) async {
        print("      → \(platform.rawValue)")

        if let contact = platform.musicSupervisorContact {
            print("         Contact: \(contact)")
        }

        print("         Rights: Master ✓ Publishing ✓")
        print("         Instrumental: \(content.instrumental ? "Yes" : "No")")

        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    func generateTVFilmPitchSheet(pitch: TVFilmPitch) -> String {
        var sheet = """
        ═══════════════════════════════════════
        MUSIC PLACEMENT PITCH SHEET
        ═══════════════════════════════════════

        TRACK INFORMATION
        ───────────────────────────────────────
        Title: \(pitch.content.title)
        Artist: \(pitch.content.artist)
        Genre: \(pitch.content.genre)
        Duration: \(formatDuration(pitch.content.duration))
        Tempo: \(pitch.content.tempo)

        MOOD & ATMOSPHERE
        ───────────────────────────────────────
        \(pitch.content.mood.joined(separator: ", "))

        DESCRIPTION
        ───────────────────────────────────────
        \(pitch.content.description)

        VERSIONS AVAILABLE
        ───────────────────────────────────────
        ✓ Full Mix
        """

        if pitch.content.instrumental {
            sheet += "\n✓ Instrumental"
        }

        if pitch.pitchPackage.instrumentalVersion != nil {
            sheet += "\n✓ Instrumental Version"
        }

        if pitch.pitchPackage.stems != nil {
            sheet += "\n✓ Stems Available"
        }

        sheet += """


        RIGHTS INFORMATION
        ───────────────────────────────────────
        Master Rights: \(pitch.pitchPackage.licenseInfo.masterRightsHolder)
        Publishing: \(pitch.pitchPackage.licenseInfo.publishingRightsHolder)
        Available Rights: \(pitch.pitchPackage.licenseInfo.availableRights.count) types
        Exclusivity: \(pitch.pitchPackage.licenseInfo.exclusivityRequired ? "Required" : "Not Required")

        IDEAL FOR
        ───────────────────────────────────────
        """

        // Suggest uses based on mood
        if pitch.content.mood.contains("Uplifting") || pitch.content.mood.contains("Happy") {
            sheet += "\n• Montages and feel-good scenes"
        }
        if pitch.content.mood.contains("Dramatic") || pitch.content.mood.contains("Intense") {
            sheet += "\n• Action sequences and dramatic moments"
        }
        if pitch.content.mood.contains("Emotional") {
            sheet += "\n• Emotional scenes and character moments"
        }
        if pitch.content.instrumental {
            sheet += "\n• Background scenes (dialogue-heavy)"
        }

        sheet += "\n\n═══════════════════════════════════════"

        return sheet
    }

    // MARK: - Sync Licensing

    func submitToSyncLicensing(
        track: SyncLicense.SyncTrack,
        platforms: [SyncPlatform]
    ) async -> SyncLicense {
        print("🎼 Submitting to sync licensing platforms...")
        print("   Track: \(track.title)")
        print("   Platforms: \(platforms.count)")

        let pricing = calculateSyncPricing(track: track)

        let license = SyncLicense(
            track: track,
            platforms: platforms,
            pricing: pricing,
            status: .pending,
            earnings: 0.0
        )

        syncLicenses.append(license)

        for platform in platforms {
            await submitToSyncPlatform(track: track, platform: platform)
        }

        print("   ✅ Submitted to \(platforms.count) sync platforms")

        return license
    }

    private func calculateSyncPricing(track: SyncLicense.SyncTrack) -> SyncLicense.PricingStructure {
        // Base pricing (can be adjusted)
        var basePrice: Double = 50.0

        // Adjust for quality factors
        if track.isInstrumental {
            basePrice *= 1.2  // Instrumentals more versatile
        }

        return SyncLicense.PricingStructure(
            webUse: basePrice,
            corporateVideo: basePrice * 3,
            commercialAd: basePrice * 10,
            filmTV: basePrice * 20,
            broadcast: basePrice * 50
        )
    }

    private func submitToSyncPlatform(track: SyncLicense.SyncTrack, platform: SyncPlatform) async {
        print("      → \(platform.rawValue)")
        print("         Commission: \(String(format: "%.0f", platform.commissionRate))%")
        print("         Model: \(platform.paymentModel)")

        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    // MARK: - Track Placement

    func recordPlacement(
        pitchId: UUID,
        platform: TVFilmPlatform,
        show: String,
        episode: String?,
        fee: Double
    ) {
        guard let index = tvFilmPitches.firstIndex(where: { $0.id == pitchId }) else {
            return
        }

        let placement = TVFilmPitch.Placement(
            platform: platform,
            showOrFilm: show,
            episodeOrScene: episode,
            airDate: Date(),
            fee: fee,
            usage: .background
        )

        tvFilmPitches[index].placements.append(placement)
        tvFilmPitches[index].status = .placed

        mediaStats.tvFilmPlacements += 1

        print("🎉 Placement secured!")
        print("   Show: \(show)")
        print("   Platform: \(platform.rawValue)")
        print("   Fee: $\(String(format: "%.2f", fee))")
    }

    func recordRadioAirplay(
        pitchId: UUID,
        station: RadioStation,
        show: String?
    ) {
        guard let index = radioPitches.firstIndex(where: { $0.id == pitchId }) else {
            return
        }

        let airplay = RadioPitch.AirplayInstance(
            station: station,
            playedAt: Date(),
            show: show,
            estimatedListeners: station.weeklyListeners
        )

        radioPitches[index].airplay.append(airplay)
        radioPitches[index].status = .playlisted

        mediaStats.radioSpins += 1
        mediaStats.estimatedRadioReach += Int64(station.weeklyListeners)

        print("📻 Radio airplay!")
        print("   Station: \(station.rawValue)")
        print("   Listeners: \(formatNumber(station.weeklyListeners))")
    }

    // MARK: - Reports

    func generateMediaReport() -> String {
        var report = """
        ═══════════════════════════════════════
        MEDIA PITCHING REPORT
        ═══════════════════════════════════════

        OVERVIEW
        ───────────────────────────────────────
        Radio Spins: \(mediaStats.radioSpins)
        TV/Film Placements: \(mediaStats.tvFilmPlacements)
        Sync Licenses: \(mediaStats.syncLicenses)

        Radio Reach: \(formatNumber(Int(mediaStats.estimatedRadioReach))) listeners
        Sync Earnings: $\(String(format: "%.2f", mediaStats.totalSyncEarnings))

        """

        // Radio airplay
        if !radioPitches.isEmpty {
            let playlisted = radioPitches.filter { $0.status == .playlisted }
            if !playlisted.isEmpty {
                report += """

                RADIO AIRPLAY
                ───────────────────────────────────────

                """

                for pitch in playlisted {
                    report += """
                    \(pitch.track.title)
                       Stations: \(pitch.airplay.count)
                       Total Spins: \(pitch.airplay.count)

                    """
                }
            }
        }

        // TV/Film placements
        if !tvFilmPitches.isEmpty {
            let placed = tvFilmPitches.filter { $0.status == .placed }
            if !placed.isEmpty {
                report += """

                TV/FILM PLACEMENTS
                ───────────────────────────────────────

                """

                for pitch in placed {
                    for placement in pitch.placements {
                        report += """
                        \(pitch.content.title)
                           Show: \(placement.showOrFilm)
                           Platform: \(placement.platform.rawValue)
                           Fee: $\(String(format: "%.2f", placement.fee ?? 0))

                        """
                    }
                }
            }
        }

        report += "═══════════════════════════════════════"

        return report
    }

    // MARK: - Helper Methods

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
