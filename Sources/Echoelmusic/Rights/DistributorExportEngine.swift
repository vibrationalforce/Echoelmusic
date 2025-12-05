// DistributorExportEngine.swift
// Echoelmusic
//
// Export to Free/Low-Cost Music Distributors
// Supports: Amuse (Free), RouteNote (Free), DistroKid ($20/yr), TuneCore, etc.
//
// Created by Echoelmusic on 2025-12-05.

import Foundation
import Combine

// MARK: - Distributor Platform

public enum DistributorPlatform: String, CaseIterable, Codable {
    // Free Tier Available
    case amuse = "Amuse"
    case routeNote = "RouteNote"
    case soundrop = "Soundrop"
    case unitedMasters = "UnitedMasters"
    case freeYourMusic = "FreeYourMusic"

    // German/EU Focused
    case musicHub = "musicHub" // User's distributor
    case recordJet = "RecordJet"
    case spinnup = "Spinnup"
    case iMusician = "iMusician"

    // Low Cost ($15-30/year)
    case distroKid = "DistroKid"
    case cdbaby = "CD Baby"
    case landr = "LANDR"

    // Pay Per Release
    case tunecore = "TuneCore"
    case ditto = "Ditto Music"
    case awal = "AWAL"
    case symphonic = "Symphonic"

    // Immersive Audio Specialists
    case appleMusicForArtists = "Apple Music for Artists" // Direct Spatial Audio upload
    case dolbyAtmosMusic = "Dolby Atmos Music"
    case sonyMusic360 = "Sony 360 Reality Audio"

    // Label Services
    case believe = "Believe Digital"
    case theOrchard = "The Orchard"
    case ingrooves = "Ingrooves"

    public var hasFreesTier: Bool {
        switch self {
        case .amuse, .routeNote, .soundrop, .unitedMasters, .freeYourMusic:
            return true
        default:
            return false
        }
    }

    public var pricing: String {
        switch self {
        case .amuse: return "Free (keep 100%)"
        case .routeNote: return "Free (85%) or Premium (100%)"
        case .soundrop: return "Free (Spotify only)"
        case .unitedMasters: return "Free (90%) or Gold (100%)"
        case .freeYourMusic: return "Free transfer tool"
        case .musicHub: return "From €9.99/release"
        case .recordJet: return "From €9.99/release"
        case .spinnup: return "€9.99/year"
        case .iMusician: return "From €14.99/release"
        case .distroKid: return "$22.99/year unlimited"
        case .cdbaby: return "$9.95/single"
        case .landr: return "$9.99/month"
        case .tunecore: return "$14.99/single/year"
        case .ditto: return "$19/year"
        case .awal: return "Apply only"
        case .symphonic: return "Custom"
        case .appleMusicForArtists: return "Free (Spatial Audio direct)"
        case .dolbyAtmosMusic: return "Via distributor"
        case .sonyMusic360: return "Via distributor"
        case .believe: return "Label services"
        case .theOrchard: return "Label services"
        case .ingrooves: return "Label services"
        }
    }

    /// Required audio format for upload
    public var audioRequirements: AudioRequirements {
        switch self {
        case .musicHub:
            return AudioRequirements(
                sampleRate: 44100,
                bitDepth: 24,
                format: .wav,
                channels: .stereo,
                supportsImmersive: false
            )
        case .distroKid:
            return AudioRequirements(
                sampleRate: 44100,
                bitDepth: 16,
                format: .wav,
                channels: .stereo,
                supportsImmersive: false
            )
        case .appleMusicForArtists:
            return AudioRequirements(
                sampleRate: 48000,
                bitDepth: 24,
                format: .wav,
                channels: .dolbyAtmos,
                supportsImmersive: true
            )
        case .dolbyAtmosMusic:
            return AudioRequirements(
                sampleRate: 48000,
                bitDepth: 24,
                format: .adm, // ADM BWF
                channels: .dolbyAtmos,
                supportsImmersive: true
            )
        case .sonyMusic360:
            return AudioRequirements(
                sampleRate: 48000,
                bitDepth: 24,
                format: .wav,
                channels: .sony360,
                supportsImmersive: true
            )
        default:
            return AudioRequirements(
                sampleRate: 44100,
                bitDepth: 16,
                format: .wav,
                channels: .stereo,
                supportsImmersive: false
            )
        }
    }

    public struct AudioRequirements {
        public let sampleRate: Int // Hz
        public let bitDepth: Int
        public let format: AudioFormat
        public let channels: ChannelConfig
        public let supportsImmersive: Bool

        public enum AudioFormat: String {
            case wav = "WAV"
            case flac = "FLAC"
            case aiff = "AIFF"
            case adm = "ADM BWF" // Dolby Atmos master
        }

        public enum ChannelConfig: String {
            case stereo = "Stereo (2.0)"
            case dolbyAtmos = "Dolby Atmos (7.1.4)"
            case sony360 = "Sony 360RA (24 objects)"
            case ambisonics = "Ambisonics (3rd order)"
        }

        public var description: String {
            "\(bitDepth)-bit / \(sampleRate / 1000)kHz \(format.rawValue) - \(channels.rawValue)"
        }
    }

    public var royaltyRate: Float {
        switch self {
        case .amuse: return 1.0 // 100%
        case .routeNote: return 0.85 // 85% on free tier
        case .soundrop: return 1.0
        case .unitedMasters: return 0.90
        case .distroKid: return 1.0
        case .cdbaby: return 0.91 // 9% fee
        case .landr: return 1.0
        case .tunecore: return 1.0
        case .ditto: return 1.0
        case .awal: return 0.85
        default: return 0.80
        }
    }

    public var supportedStores: [String] {
        // Most distributors reach all stores, but some have exclusives
        let allStores = [
            "Spotify", "Apple Music", "Amazon Music", "YouTube Music",
            "Deezer", "Tidal", "Pandora", "iHeartRadio", "TikTok",
            "Instagram/Facebook", "Snapchat", "Tencent", "NetEase"
        ]

        switch self {
        case .soundrop:
            return ["Spotify"] // Free tier is Spotify-only
        default:
            return allStores
        }
    }

    public var exportFormat: ExportFormat {
        switch self {
        case .distroKid, .amuse, .routeNote:
            return .csv
        case .tunecore, .cdbaby:
            return .xml
        default:
            return .csv
        }
    }

    public enum ExportFormat {
        case csv, xml, json, excel
    }
}

// MARK: - Release Type

public enum ReleaseType: String, Codable, CaseIterable {
    case single = "Single"
    case ep = "EP"
    case album = "Album"
    case compilation = "Compilation"
    case mixtape = "Mixtape"

    public var maxTracks: Int {
        switch self {
        case .single: return 3
        case .ep: return 6
        case .album: return 50
        case .compilation: return 100
        case .mixtape: return 30
        }
    }
}

// MARK: - Release Metadata

public struct ReleaseMetadata: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var version: String? // "Deluxe", "Remastered", etc.
    public var releaseType: ReleaseType
    public var artists: [ArtistCredit]
    public var tracks: [TrackMetadata]

    // Identifiers
    public var upc: String? // Universal Product Code
    public var catalogNumber: String?

    // Release Info
    public var releaseDate: Date
    public var originalReleaseDate: Date?
    public var recordLabel: String
    public var copyrightLine: String // (C) line
    public var phonographicLine: String // (P) line

    // Genre & Style
    public var primaryGenre: String
    public var secondaryGenre: String?
    public var subgenre: String?
    public var mood: [String]
    public var language: String

    // Artwork
    public var artworkURL: URL?
    public var artworkData: Data?

    // Territories
    public var territories: [String] // ISO codes, empty = worldwide
    public var excludedTerritories: [String]

    // Pricing
    public var priceCategory: PriceCategory
    public var preOrderDate: Date?

    // Extras
    public var explicit: Bool
    public var isCompilation: Bool
    public var description: String?
    public var credits: String?

    public enum PriceCategory: String, Codable {
        case budget = "Budget"
        case mid = "Mid-Price"
        case full = "Full Price"
        case premium = "Premium"
        case free = "Free"
    }

    public init(title: String, releaseType: ReleaseType) {
        self.id = UUID()
        self.title = title
        self.releaseType = releaseType
        self.artists = []
        self.tracks = []
        self.releaseDate = Date()
        self.recordLabel = "Self-Released"
        self.copyrightLine = ""
        self.phonographicLine = ""
        self.primaryGenre = "Electronic"
        self.language = "EN"
        self.territories = []
        self.excludedTerritories = []
        self.priceCategory = .full
        self.explicit = false
        self.isCompilation = false
    }
}

public struct ArtistCredit: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var role: ArtistRole
    public var spotifyId: String?
    public var appleMusicId: String?
    public var isPrimary: Bool

    public enum ArtistRole: String, Codable {
        case primary = "Primary Artist"
        case featuring = "Featuring"
        case remixer = "Remixer"
        case producer = "Producer"
        case composer = "Composer"
        case performer = "Performer"
    }

    public init(name: String, role: ArtistRole = .primary) {
        self.id = UUID()
        self.name = name
        self.role = role
        self.isPrimary = role == .primary
    }
}

public struct TrackMetadata: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var version: String?
    public var trackNumber: Int
    public var discNumber: Int
    public var isrc: String?
    public var duration: TimeInterval
    public var artists: [ArtistCredit]
    public var writers: [String]
    public var producers: [String]
    public var explicit: Bool
    public var previewStart: TimeInterval?
    public var audioFileURL: URL?
    public var lyrics: String?
    public var lyricsLanguage: String?

    public init(title: String, trackNumber: Int) {
        self.id = UUID()
        self.title = title
        self.trackNumber = trackNumber
        self.discNumber = 1
        self.duration = 0
        self.artists = []
        self.writers = []
        self.producers = []
        self.explicit = false
    }
}

// MARK: - Export Result

public struct DistributorExportResult {
    public let platform: DistributorPlatform
    public let format: DistributorPlatform.ExportFormat
    public let filename: String
    public let data: Data
    public let validationErrors: [String]
    public let warnings: [String]

    public var isValid: Bool {
        validationErrors.isEmpty
    }
}

// MARK: - Distributor Export Engine

@MainActor
public final class DistributorExportEngine: ObservableObject {
    public static let shared = DistributorExportEngine()

    // MARK: Published State

    @Published public private(set) var lastExportResult: DistributorExportResult?
    @Published public private(set) var exportHistory: [ExportHistoryEntry] = []

    public struct ExportHistoryEntry: Identifiable, Codable {
        public let id: UUID
        public let releaseId: UUID
        public let releaseTitle: String
        public let platform: DistributorPlatform
        public let exportedAt: Date
        public let filename: String
    }

    // MARK: Initialization

    private init() {}

    // MARK: - Export Methods

    /// Export release for a specific distributor
    public func export(
        release: ReleaseMetadata,
        for platform: DistributorPlatform
    ) -> DistributorExportResult {
        let validation = validateRelease(release, for: platform)

        guard validation.isValid else {
            return DistributorExportResult(
                platform: platform,
                format: platform.exportFormat,
                filename: "",
                data: Data(),
                validationErrors: validation.errors,
                warnings: validation.warnings
            )
        }

        let data: Data
        let filename: String

        switch platform.exportFormat {
        case .csv:
            data = generateCSV(release: release, platform: platform)
            filename = "\(sanitizeFilename(release.title))_\(platform.rawValue).csv"
        case .xml:
            data = generateXML(release: release, platform: platform)
            filename = "\(sanitizeFilename(release.title))_\(platform.rawValue).xml"
        case .json:
            data = generateJSON(release: release, platform: platform)
            filename = "\(sanitizeFilename(release.title))_\(platform.rawValue).json"
        case .excel:
            data = generateCSV(release: release, platform: platform) // Fallback
            filename = "\(sanitizeFilename(release.title))_\(platform.rawValue).csv"
        }

        let result = DistributorExportResult(
            platform: platform,
            format: platform.exportFormat,
            filename: filename,
            data: data,
            validationErrors: [],
            warnings: validation.warnings
        )

        lastExportResult = result

        // Add to history
        let entry = ExportHistoryEntry(
            id: UUID(),
            releaseId: release.id,
            releaseTitle: release.title,
            platform: platform,
            exportedAt: Date(),
            filename: filename
        )
        exportHistory.insert(entry, at: 0)

        return result
    }

    /// Export for all free platforms
    public func exportForFreePlatforms(release: ReleaseMetadata) -> [DistributorExportResult] {
        return DistributorPlatform.allCases
            .filter { $0.hasFreesTier }
            .map { export(release: release, for: $0) }
    }

    // MARK: - Validation

    public struct ValidationResult {
        public var isValid: Bool
        public var errors: [String]
        public var warnings: [String]
    }

    public func validateRelease(_ release: ReleaseMetadata, for platform: DistributorPlatform) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Required fields
        if release.title.isEmpty {
            errors.append("Release title is required")
        }

        if release.artists.isEmpty {
            errors.append("At least one artist is required")
        }

        if release.tracks.isEmpty {
            errors.append("At least one track is required")
        }

        if release.primaryGenre.isEmpty {
            errors.append("Primary genre is required")
        }

        // Track validation
        for track in release.tracks {
            if track.title.isEmpty {
                errors.append("Track \(track.trackNumber): Title is required")
            }

            if track.duration < 30 {
                warnings.append("Track \(track.trackNumber): Very short duration (<30s)")
            }

            if track.isrc == nil {
                warnings.append("Track \(track.trackNumber): No ISRC (will be assigned by distributor)")
            }
        }

        // Artwork
        if release.artworkData == nil && release.artworkURL == nil {
            errors.append("Cover artwork is required")
        }

        // Release date
        if release.releaseDate < Date() {
            warnings.append("Release date is in the past")
        }

        // Platform-specific
        switch platform {
        case .soundrop:
            if release.tracks.count > 1 {
                warnings.append("Soundrop free tier only supports singles")
            }

        case .amuse:
            if release.tracks.count > 20 {
                warnings.append("Amuse has a 20 track limit per release")
            }

        default:
            break
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }

    // MARK: - CSV Generation

    private func generateCSV(release: ReleaseMetadata, platform: DistributorPlatform) -> Data {
        var csv = ""

        switch platform {
        case .distroKid:
            csv = generateDistroKidCSV(release)
        case .amuse:
            csv = generateAmuseCSV(release)
        case .routeNote:
            csv = generateRouteNoteCSV(release)
        default:
            csv = generateGenericCSV(release)
        }

        return csv.data(using: .utf8) ?? Data()
    }

    private func generateDistroKidCSV(_ release: ReleaseMetadata) -> String {
        var lines: [String] = []

        // Header
        lines.append("track_number,title,artist,featured_artist,isrc,duration,explicit,genre,release_date,upc,label,copyright")

        // Tracks
        for track in release.tracks {
            let primaryArtist = release.artists.first(where: { $0.isPrimary })?.name ?? ""
            let featuredArtist = track.artists.first(where: { $0.role == .featuring })?.name ?? ""

            let row = [
                "\(track.trackNumber)",
                escapeCSV(track.title),
                escapeCSV(primaryArtist),
                escapeCSV(featuredArtist),
                track.isrc ?? "",
                formatDuration(track.duration),
                track.explicit ? "Y" : "N",
                escapeCSV(release.primaryGenre),
                formatDate(release.releaseDate),
                release.upc ?? "",
                escapeCSV(release.recordLabel),
                escapeCSV(release.copyrightLine)
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    private func generateAmuseCSV(_ release: ReleaseMetadata) -> String {
        var lines: [String] = []

        // Amuse format
        lines.append("Release Title,Artist Name,Track Title,Track Number,ISRC,Genre,Release Date,Label,Copyright,Explicit")

        for track in release.tracks {
            let artist = release.artists.first(where: { $0.isPrimary })?.name ?? ""
            let row = [
                escapeCSV(release.title),
                escapeCSV(artist),
                escapeCSV(track.title),
                "\(track.trackNumber)",
                track.isrc ?? "",
                escapeCSV(release.primaryGenre),
                formatDate(release.releaseDate),
                escapeCSV(release.recordLabel),
                escapeCSV(release.copyrightLine),
                track.explicit ? "Yes" : "No"
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    private func generateRouteNoteCSV(_ release: ReleaseMetadata) -> String {
        var lines: [String] = []

        // RouteNote format
        lines.append("TRACK_TITLE,ARTIST,VERSION,TRACK_NO,DISC_NO,ISRC,DURATION,EXPLICIT,GENRE,SUB_GENRE")

        for track in release.tracks {
            let artist = release.artists.first(where: { $0.isPrimary })?.name ?? ""
            let row = [
                escapeCSV(track.title),
                escapeCSV(artist),
                escapeCSV(track.version ?? ""),
                "\(track.trackNumber)",
                "\(track.discNumber)",
                track.isrc ?? "",
                formatDuration(track.duration),
                track.explicit ? "1" : "0",
                escapeCSV(release.primaryGenre),
                escapeCSV(release.secondaryGenre ?? "")
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    private func generateGenericCSV(_ release: ReleaseMetadata) -> String {
        var lines: [String] = []

        lines.append("Title,Artist,Track Number,ISRC,Duration,Genre,Release Date,Label,Copyright,Explicit")

        for track in release.tracks {
            let artist = release.artists.first(where: { $0.isPrimary })?.name ?? ""
            let row = [
                escapeCSV(track.title),
                escapeCSV(artist),
                "\(track.trackNumber)",
                track.isrc ?? "",
                formatDuration(track.duration),
                escapeCSV(release.primaryGenre),
                formatDate(release.releaseDate),
                escapeCSV(release.recordLabel),
                escapeCSV(release.copyrightLine),
                track.explicit ? "Yes" : "No"
            ]
            lines.append(row.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - XML Generation

    private func generateXML(release: ReleaseMetadata, platform: DistributorPlatform) -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <release>
            <title>\(escapeXML(release.title))</title>
            <upc>\(release.upc ?? "")</upc>
            <release_date>\(formatDate(release.releaseDate))</release_date>
            <label>\(escapeXML(release.recordLabel))</label>
            <genre>\(escapeXML(release.primaryGenre))</genre>
            <copyright>\(escapeXML(release.copyrightLine))</copyright>
            <artists>

        """

        for artist in release.artists {
            xml += """
                    <artist>
                        <name>\(escapeXML(artist.name))</name>
                        <role>\(artist.role.rawValue)</role>
                        <primary>\(artist.isPrimary)</primary>
                    </artist>

            """
        }

        xml += """
            </artists>
            <tracks>

        """

        for track in release.tracks {
            xml += """
                    <track>
                        <number>\(track.trackNumber)</number>
                        <title>\(escapeXML(track.title))</title>
                        <isrc>\(track.isrc ?? "")</isrc>
                        <duration>\(Int(track.duration))</duration>
                        <explicit>\(track.explicit)</explicit>
                    </track>

            """
        }

        xml += """
            </tracks>
        </release>
        """

        return xml.data(using: .utf8) ?? Data()
    }

    // MARK: - JSON Generation

    private func generateJSON(release: ReleaseMetadata, platform: DistributorPlatform) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return (try? encoder.encode(release)) ?? Data()
    }

    // MARK: - Helpers

    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return string
    }

    private func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func sanitizeFilename(_ string: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        return string.components(separatedBy: invalidChars).joined(separator: "_")
    }

    // MARK: - Platform Recommendations

    /// Get recommended distributors based on release type and artist status
    public func getRecommendedDistributors(
        releaseType: ReleaseType,
        isFirstRelease: Bool,
        wantsFree: Bool
    ) -> [DistributorRecommendation] {
        var recommendations: [DistributorRecommendation] = []

        if wantsFree {
            recommendations.append(DistributorRecommendation(
                platform: .amuse,
                reason: "100% royalties, free unlimited releases, good for building catalog",
                bestFor: "Solo artists, building catalog"
            ))

            recommendations.append(DistributorRecommendation(
                platform: .routeNote,
                reason: "85% free tier, 100% premium ($10/release), professional dashboard",
                bestFor: "Artists who want data analytics"
            ))

            if releaseType == .single {
                recommendations.append(DistributorRecommendation(
                    platform: .soundrop,
                    reason: "Free Spotify distribution, great for testing market",
                    bestFor: "Spotify-focused releases"
                ))
            }

            recommendations.append(DistributorRecommendation(
                platform: .unitedMasters,
                reason: "90% free tier, potential brand deals, good social media tools",
                bestFor: "Hip-hop, R&B, artists seeking brand partnerships"
            ))
        } else {
            recommendations.append(DistributorRecommendation(
                platform: .distroKid,
                reason: "$22.99/year unlimited, fastest delivery, 100% royalties",
                bestFor: "Prolific releasers, best value for frequent releases"
            ))

            recommendations.append(DistributorRecommendation(
                platform: .cdbaby,
                reason: "One-time fee, keeps your music forever, physical distribution",
                bestFor: "Album releases, artists who want physical CDs"
            ))
        }

        return recommendations
    }

    public struct DistributorRecommendation {
        public let platform: DistributorPlatform
        public let reason: String
        public let bestFor: String
    }
}

// MARK: - Quick Export Extension

extension DistributorExportEngine {
    /// Quick export for all free platforms
    public func quickExportFree(_ release: ReleaseMetadata) -> URL? {
        let results = exportForFreePlatforms(release: release)

        // Create a folder with all exports
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Echoelmusic_Export_\(UUID().uuidString.prefix(8))")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            for result in results where result.isValid {
                let fileURL = tempDir.appendingPathComponent(result.filename)
                try result.data.write(to: fileURL)
            }

            return tempDir
        } catch {
            print("Export error: \(error)")
            return nil
        }
    }
}
