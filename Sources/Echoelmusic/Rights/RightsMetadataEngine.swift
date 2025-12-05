// RightsMetadataEngine.swift
// Echoelmusic
//
// Rights Metadata Management - Free & Pragmatic Approach
// No paid APIs - prepares exports for free distributor tiers
//
// Created by Echoelmusic on 2025-12-05.

import Foundation
import Combine

// MARK: - Rights Holder

public struct RightsHolder: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var role: Role
    public var share: Float // 0.0 to 1.0 (100%)
    public var publisherName: String?
    public var pro: PerformingRightsOrg? // GEMA, ASCAP, BMI, etc.
    public var proMemberId: String?
    public var ipi: String? // Interested Parties Information (international)
    public var email: String?
    public var paypalEmail: String? // For direct splits
    public var isControlled: Bool // Do we control this share?

    public enum Role: String, Codable, CaseIterable {
        case composer = "Composer"
        case lyricist = "Lyricist"
        case producer = "Producer"
        case performer = "Performer"
        case featuredArtist = "Featured Artist"
        case mixer = "Mixer"
        case masteringEngineer = "Mastering Engineer"
        case arranger = "Arranger"
        case sampleCreator = "Sample Creator"
        case beatmaker = "Beatmaker"

        public var defaultShare: Float {
            switch self {
            case .composer: return 0.50
            case .lyricist: return 0.50
            case .producer: return 0.25
            case .performer: return 0.10
            case .featuredArtist: return 0.15
            case .mixer: return 0.05
            case .masteringEngineer: return 0.03
            case .arranger: return 0.10
            case .sampleCreator: return 0.15
            case .beatmaker: return 0.30
            }
        }

        public var rightType: RightType {
            switch self {
            case .composer, .lyricist, .arranger:
                return .composition
            case .producer, .performer, .featuredArtist, .mixer, .masteringEngineer, .beatmaker:
                return .master
            case .sampleCreator:
                return .sample
            }
        }
    }

    public enum RightType: String, Codable {
        case composition = "Composition (Publishing)"
        case master = "Master Recording"
        case sample = "Sample"
    }

    public enum PerformingRightsOrg: String, Codable, CaseIterable {
        // German-speaking
        case gema = "GEMA"
        case aume = "AKM (Austria)"
        case suisa = "SUISA (Switzerland)"

        // US
        case ascap = "ASCAP"
        case bmi = "BMI"
        case sesac = "SESAC"

        // UK
        case prs = "PRS for Music"

        // Other EU
        case sacem = "SACEM (France)"
        case siae = "SIAE (Italy)"
        case sgae = "SGAE (Spain)"
        case buma = "BUMA/STEMRA (Netherlands)"

        // Other
        case apra = "APRA AMCOS (Australia)"
        case socan = "SOCAN (Canada)"
        case jasrac = "JASRAC (Japan)"

        case none = "Not Registered"
    }

    public init(
        name: String,
        role: Role,
        share: Float = 0
    ) {
        self.id = UUID()
        self.name = name
        self.role = role
        self.share = share > 0 ? share : role.defaultShare
        self.isControlled = true
    }
}

// MARK: - Track Rights

public struct TrackRights: Identifiable, Codable {
    public let id: UUID
    public var trackId: UUID
    public var trackTitle: String
    public var version: String? // "Radio Edit", "Extended Mix", etc.

    // Identifiers
    public var isrc: String? // International Standard Recording Code
    public var iswc: String? // International Standard Musical Work Code
    public var upc: String? // For releases/albums

    // Rights Holders
    public var compositionHolders: [RightsHolder] // Publishing/songwriting
    public var masterHolders: [RightsHolder] // Recording rights
    public var sampleClearances: [SampleClearance]

    // Copyright Info
    public var copyrightYear: Int
    public var copyrightHolder: String // (P) and (C) line
    public var recordLabel: String?

    // Licensing
    public var license: License
    public var territorialRestrictions: [TerritorialRestriction]
    public var exclusivityStatus: ExclusivityStatus

    // Timestamps (for proof of creation)
    public var createdAt: Date
    public var lastModified: Date
    public var registeredAt: Date? // When submitted to distributor
    public var blockchainHash: String? // Optional timestamping

    // Status
    public var status: RegistrationStatus
    public var disputes: [Dispute]

    public init(trackId: UUID, trackTitle: String) {
        self.id = UUID()
        self.trackId = trackId
        self.trackTitle = trackTitle
        self.compositionHolders = []
        self.masterHolders = []
        self.sampleClearances = []
        self.copyrightYear = Calendar.current.component(.year, from: Date())
        self.copyrightHolder = ""
        self.license = .allRightsReserved
        self.territorialRestrictions = []
        self.exclusivityStatus = .nonExclusive
        self.createdAt = Date()
        self.lastModified = Date()
        self.status = .draft
        self.disputes = []
    }

    // MARK: Validation

    public var isValid: Bool {
        compositionSharesValid && masterSharesValid && hasRequiredInfo
    }

    public var compositionSharesValid: Bool {
        let total = compositionHolders.reduce(0) { $0 + $1.share }
        return abs(total - 1.0) < 0.001 || compositionHolders.isEmpty
    }

    public var masterSharesValid: Bool {
        let total = masterHolders.reduce(0) { $0 + $1.share }
        return abs(total - 1.0) < 0.001 || masterHolders.isEmpty
    }

    public var hasRequiredInfo: Bool {
        !trackTitle.isEmpty && !copyrightHolder.isEmpty
    }

    public var validationErrors: [String] {
        var errors: [String] = []
        if trackTitle.isEmpty { errors.append("Track title required") }
        if copyrightHolder.isEmpty { errors.append("Copyright holder required") }
        if !compositionSharesValid { errors.append("Composition shares must total 100%") }
        if !masterSharesValid { errors.append("Master shares must total 100%") }
        return errors
    }
}

// MARK: - License Types

public enum License: String, Codable, CaseIterable {
    case allRightsReserved = "All Rights Reserved"

    // Creative Commons
    case ccBy = "CC BY (Attribution)"
    case ccBySa = "CC BY-SA (Attribution-ShareAlike)"
    case ccByNc = "CC BY-NC (Attribution-NonCommercial)"
    case ccByNcSa = "CC BY-NC-SA (Attribution-NonCommercial-ShareAlike)"
    case ccByNd = "CC BY-ND (Attribution-NoDerivatives)"
    case ccByNcNd = "CC BY-NC-ND (Attribution-NonCommercial-NoDerivatives)"
    case cc0 = "CC0 (Public Domain)"

    // Other
    case royaltyFree = "Royalty-Free"
    case syncLicenseAvailable = "Sync License Available"
    case custom = "Custom License"

    public var allowsCommercialUse: Bool {
        switch self {
        case .ccByNc, .ccByNcSa, .ccByNcNd:
            return false
        default:
            return true
        }
    }

    public var allowsDerivatives: Bool {
        switch self {
        case .ccByNd, .ccByNcNd:
            return false
        default:
            return true
        }
    }

    public var requiresAttribution: Bool {
        switch self {
        case .cc0, .allRightsReserved:
            return false
        default:
            return true
        }
    }
}

// MARK: - Sample Clearance

public struct SampleClearance: Identifiable, Codable {
    public let id: UUID
    public var originalTrack: String
    public var originalArtist: String
    public var originalLabel: String?
    public var sampleType: SampleType
    public var duration: TimeInterval // How long is the sample
    public var clearanceStatus: ClearanceStatus
    public var clearanceDocument: URL?
    public var royaltyType: RoyaltyType
    public var royaltyPercentage: Float?
    public var oneTimeFee: Decimal?
    public var notes: String?

    public enum SampleType: String, Codable {
        case audio = "Audio Sample"
        case interpolation = "Interpolation"
        case replay = "Replay/Re-record"
        case midi = "MIDI/Melody"
        case drums = "Drums Only"
        case vocal = "Vocal Sample"
        case instrument = "Instrument Loop"
    }

    public enum ClearanceStatus: String, Codable {
        case notNeeded = "Not Needed"
        case pending = "Pending"
        case approved = "Approved"
        case denied = "Denied"
        case negotiating = "Negotiating"
    }

    public enum RoyaltyType: String, Codable {
        case none = "No Royalty"
        case percentage = "Percentage"
        case oneTime = "One-Time Fee"
        case both = "Fee + Percentage"
    }
}

// MARK: - Territorial Restriction

public struct TerritorialRestriction: Codable {
    public var territory: String // ISO country code or "WORLD"
    public var type: RestrictionType
    public var reason: String?

    public enum RestrictionType: String, Codable {
        case allowed = "Allowed"
        case blocked = "Blocked"
        case exclusive = "Exclusive"
    }
}

// MARK: - Exclusivity Status

public enum ExclusivityStatus: String, Codable {
    case nonExclusive = "Non-Exclusive"
    case exclusive = "Exclusive"
    case limitedExclusive = "Limited Exclusive"
    case expired = "Exclusivity Expired"
}

// MARK: - Registration Status

public enum RegistrationStatus: String, Codable {
    case draft = "Draft"
    case readyToSubmit = "Ready to Submit"
    case submitted = "Submitted"
    case processing = "Processing"
    case registered = "Registered"
    case rejected = "Rejected"
    case disputed = "Disputed"
}

// MARK: - Dispute

public struct Dispute: Identifiable, Codable {
    public let id: UUID
    public var platform: String
    public var disputeType: DisputeType
    public var claimant: String
    public var status: DisputeStatus
    public var createdAt: Date
    public var resolvedAt: Date?
    public var notes: String?

    public enum DisputeType: String, Codable {
        case copyrightClaim = "Copyright Claim"
        case ownershipDispute = "Ownership Dispute"
        case contentId = "Content ID Match"
        case takedownRequest = "Takedown Request"
    }

    public enum DisputeStatus: String, Codable {
        case active = "Active"
        case appealed = "Appealed"
        case resolved = "Resolved"
        case rejected = "Rejected"
    }
}

// MARK: - Split Sheet

public struct SplitSheet: Identifiable, Codable {
    public let id: UUID
    public var trackRights: TrackRights
    public var generatedAt: Date
    public var signedBy: [Signature]
    public var version: Int
    public var notes: String?

    public struct Signature: Codable {
        public var holderId: UUID
        public var name: String
        public var signedAt: Date?
        public var signatureData: Data? // Drawn signature
        public var agreedToTerms: Bool
    }

    public var isFullySigned: Bool {
        let allHolders = trackRights.compositionHolders + trackRights.masterHolders
        return signedBy.count == allHolders.count &&
               signedBy.allSatisfy { $0.agreedToTerms }
    }

    /// Generate PDF-ready split sheet
    public func generateDocument() -> SplitSheetDocument {
        SplitSheetDocument(sheet: self)
    }
}

public struct SplitSheetDocument {
    public let sheet: SplitSheet

    public var asText: String {
        var text = """
        ═══════════════════════════════════════════════════════════════
                              SPLIT SHEET AGREEMENT
        ═══════════════════════════════════════════════════════════════

        TRACK INFORMATION
        ─────────────────
        Title: \(sheet.trackRights.trackTitle)
        Version: \(sheet.trackRights.version ?? "Original")
        ISRC: \(sheet.trackRights.isrc ?? "Pending")
        Copyright Year: \(sheet.trackRights.copyrightYear)
        Copyright Holder: \(sheet.trackRights.copyrightHolder)

        ═══════════════════════════════════════════════════════════════
        COMPOSITION / PUBLISHING RIGHTS
        ═══════════════════════════════════════════════════════════════

        """

        for holder in sheet.trackRights.compositionHolders {
            text += """
            \(holder.name)
            Role: \(holder.role.rawValue)
            Share: \(String(format: "%.1f", holder.share * 100))%
            PRO: \(holder.pro?.rawValue ?? "Not Registered")
            IPI: \(holder.ipi ?? "N/A")
            Publisher: \(holder.publisherName ?? "Self-Published")

            """
        }

        text += """

        ═══════════════════════════════════════════════════════════════
        MASTER RECORDING RIGHTS
        ═══════════════════════════════════════════════════════════════

        """

        for holder in sheet.trackRights.masterHolders {
            text += """
            \(holder.name)
            Role: \(holder.role.rawValue)
            Share: \(String(format: "%.1f", holder.share * 100))%

            """
        }

        if !sheet.trackRights.sampleClearances.isEmpty {
            text += """

            ═══════════════════════════════════════════════════════════════
            SAMPLE CLEARANCES
            ═══════════════════════════════════════════════════════════════

            """

            for sample in sheet.trackRights.sampleClearances {
                text += """
                Original: "\(sample.originalTrack)" by \(sample.originalArtist)
                Type: \(sample.sampleType.rawValue)
                Status: \(sample.clearanceStatus.rawValue)

                """
            }
        }

        text += """

        ═══════════════════════════════════════════════════════════════
        AGREEMENT
        ═══════════════════════════════════════════════════════════════

        The undersigned parties agree to the above split percentages
        for all income derived from the exploitation of this work,
        including but not limited to:
        - Streaming royalties
        - Download sales
        - Sync licensing fees
        - Performance royalties
        - Mechanical royalties

        LICENSE: \(sheet.trackRights.license.rawValue)

        Generated: \(sheet.generatedAt.formatted())
        Document ID: \(sheet.id.uuidString.prefix(8))

        ═══════════════════════════════════════════════════════════════
        SIGNATURES
        ═══════════════════════════════════════════════════════════════

        """

        for sig in sheet.signedBy {
            let signedStatus = sig.signedAt != nil ? "✓ Signed \(sig.signedAt!.formatted())" : "☐ Pending"
            text += "\(sig.name): \(signedStatus)\n"
        }

        return text
    }
}

// MARK: - Rights Metadata Engine

@MainActor
public final class RightsMetadataEngine: ObservableObject {
    public static let shared = RightsMetadataEngine()

    // MARK: Published State

    @Published public private(set) var trackRights: [UUID: TrackRights] = [:]
    @Published public private(set) var splitSheets: [UUID: SplitSheet] = [:]
    @Published public private(set) var recentHolders: [RightsHolder] = []

    // MARK: Storage

    private let storageKey = "echoelmusic.rights"
    private var cancellables = Set<AnyCancellable>()

    // MARK: Initialization

    private init() {
        loadFromStorage()
    }

    // MARK: - Track Rights Management

    /// Create rights for a new track
    public func createTrackRights(trackId: UUID, title: String) -> TrackRights {
        var rights = TrackRights(trackId: trackId, trackTitle: title)

        // Set defaults
        rights.copyrightYear = Calendar.current.component(.year, from: Date())

        trackRights[trackId] = rights
        saveToStorage()

        return rights
    }

    /// Get rights for a track
    public func getRights(for trackId: UUID) -> TrackRights? {
        return trackRights[trackId]
    }

    /// Update track rights
    public func updateRights(_ rights: TrackRights) {
        var updated = rights
        updated.lastModified = Date()
        trackRights[rights.trackId] = updated
        saveToStorage()
    }

    // MARK: - Rights Holders

    /// Add a rights holder to a track
    public func addHolder(
        to trackId: UUID,
        name: String,
        role: RightsHolder.Role,
        share: Float
    ) {
        guard var rights = trackRights[trackId] else { return }

        let holder = RightsHolder(name: name, role: role, share: share)

        switch role.rightType {
        case .composition:
            rights.compositionHolders.append(holder)
        case .master, .sample:
            rights.masterHolders.append(holder)
        }

        // Add to recent for quick re-use
        if !recentHolders.contains(where: { $0.name == name }) {
            recentHolders.insert(holder, at: 0)
            if recentHolders.count > 20 {
                recentHolders = Array(recentHolders.prefix(20))
            }
        }

        updateRights(rights)
    }

    /// Auto-balance shares equally
    public func balanceShares(for trackId: UUID, rightType: RightsHolder.RightType) {
        guard var rights = trackRights[trackId] else { return }

        switch rightType {
        case .composition:
            let count = Float(rights.compositionHolders.count)
            guard count > 0 else { return }
            let equalShare = 1.0 / count
            for i in 0..<rights.compositionHolders.count {
                rights.compositionHolders[i].share = equalShare
            }

        case .master, .sample:
            let count = Float(rights.masterHolders.count)
            guard count > 0 else { return }
            let equalShare = 1.0 / count
            for i in 0..<rights.masterHolders.count {
                rights.masterHolders[i].share = equalShare
            }
        }

        updateRights(rights)
    }

    // MARK: - Split Sheets

    /// Generate a split sheet for signing
    public func generateSplitSheet(for trackId: UUID) -> SplitSheet? {
        guard let rights = trackRights[trackId] else { return nil }

        let allHolders = rights.compositionHolders + rights.masterHolders

        let signatures = allHolders.map { holder in
            SplitSheet.Signature(
                holderId: holder.id,
                name: holder.name,
                agreedToTerms: false
            )
        }

        let sheet = SplitSheet(
            id: UUID(),
            trackRights: rights,
            generatedAt: Date(),
            signedBy: signatures,
            version: (splitSheets[trackId]?.version ?? 0) + 1
        )

        splitSheets[trackId] = sheet
        saveToStorage()

        return sheet
    }

    /// Sign a split sheet
    public func signSplitSheet(trackId: UUID, holderId: UUID, signatureData: Data?) {
        guard var sheet = splitSheets[trackId] else { return }

        if let index = sheet.signedBy.firstIndex(where: { $0.holderId == holderId }) {
            sheet.signedBy[index].signedAt = Date()
            sheet.signedBy[index].signatureData = signatureData
            sheet.signedBy[index].agreedToTerms = true
        }

        splitSheets[trackId] = sheet
        saveToStorage()
    }

    // MARK: - ISRC Generation Helper

    /// Generate a placeholder ISRC (actual ISRC comes from distributor)
    public func generatePlaceholderISRC(countryCode: String = "DE", registrantCode: String = "XXX") -> String {
        let year = String(Calendar.current.component(.year, from: Date())).suffix(2)
        let serial = String(format: "%05d", Int.random(in: 0..<100000))
        return "\(countryCode)-\(registrantCode)-\(year)-\(serial)"
    }

    // MARK: - Timestamp / Proof of Creation

    /// Create a timestamp proof (free, uses hash)
    public func createTimestampProof(for trackId: UUID) -> String? {
        guard let rights = trackRights[trackId] else { return nil }

        let data = "\(rights.trackTitle)|\(rights.copyrightHolder)|\(rights.createdAt.timeIntervalSince1970)"

        // Simple SHA256 hash as proof
        guard let inputData = data.data(using: .utf8) else { return nil }

        var hash = [UInt8](repeating: 0, count: 32)
        inputData.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }

        let hashString = hash.map { String(format: "%02x", $0) }.joined()

        // Update rights with hash
        var updated = rights
        updated.blockchainHash = hashString
        updateRights(updated)

        return hashString
    }

    // MARK: - Storage

    private func saveToStorage() {
        let encoder = JSONEncoder()

        if let rightsData = try? encoder.encode(trackRights) {
            UserDefaults.standard.set(rightsData, forKey: "\(storageKey).rights")
        }

        if let sheetsData = try? encoder.encode(splitSheets) {
            UserDefaults.standard.set(sheetsData, forKey: "\(storageKey).sheets")
        }

        if let holdersData = try? encoder.encode(recentHolders) {
            UserDefaults.standard.set(holdersData, forKey: "\(storageKey).holders")
        }
    }

    private func loadFromStorage() {
        let decoder = JSONDecoder()

        if let rightsData = UserDefaults.standard.data(forKey: "\(storageKey).rights"),
           let rights = try? decoder.decode([UUID: TrackRights].self, from: rightsData) {
            trackRights = rights
        }

        if let sheetsData = UserDefaults.standard.data(forKey: "\(storageKey).sheets"),
           let sheets = try? decoder.decode([UUID: SplitSheet].self, from: sheetsData) {
            splitSheets = sheets
        }

        if let holdersData = UserDefaults.standard.data(forKey: "\(storageKey).holders"),
           let holders = try? decoder.decode([RightsHolder].self, from: holdersData) {
            recentHolders = holders
        }
    }
}

// SHA256 import
import CommonCrypto

// MARK: - Quick Actions Extension

extension RightsMetadataEngine {
    /// Quick setup for solo artist (100% ownership)
    public func setupSoloArtist(trackId: UUID, artistName: String, pro: RightsHolder.PerformingRightsOrg? = nil) {
        guard var rights = trackRights[trackId] else { return }

        var composerHolder = RightsHolder(name: artistName, role: .composer, share: 1.0)
        composerHolder.pro = pro

        var masterHolder = RightsHolder(name: artistName, role: .producer, share: 1.0)

        rights.compositionHolders = [composerHolder]
        rights.masterHolders = [masterHolder]
        rights.copyrightHolder = artistName

        updateRights(rights)
    }

    /// Quick setup for beat + topliner (typical collab)
    public func setupBeatAndTopliner(
        trackId: UUID,
        beatmaker: String,
        topliner: String,
        beatShare: Float = 0.5
    ) {
        guard var rights = trackRights[trackId] else { return }

        let toplinerShare = 1.0 - beatShare

        rights.compositionHolders = [
            RightsHolder(name: beatmaker, role: .beatmaker, share: beatShare),
            RightsHolder(name: topliner, role: .composer, share: toplinerShare)
        ]

        rights.masterHolders = [
            RightsHolder(name: beatmaker, role: .producer, share: beatShare),
            RightsHolder(name: topliner, role: .performer, share: toplinerShare)
        ]

        rights.copyrightHolder = "\(beatmaker) & \(topliner)"

        updateRights(rights)
    }
}
