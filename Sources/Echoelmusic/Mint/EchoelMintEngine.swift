// EchoelMintEngine.swift
// Echoelmusic — Bio-Reactive Dynamic NFT Engine
//
// ═══════════════════════════════════════════════════════════════════════════════
// EchoelMint — The world's first bio-reactive music NFT framework
//
// Vision: NFTs that are alive — they breathe with your heartbeat,
//         morph with your coherence, and evolve with your musical journey.
//
// Architecture:
// ┌──────────────────────────────────────────────────────────────────────────┐
// │  Biometric Input (Apple Watch, HealthKit)                                │
// │       │                                                                  │
// │       ▼                                                                  │
// │  Bio-State Processor ──→ Coherence, HRV, HR, Breathing                  │
// │       │                                                                  │
// │       ├──→ Generative Visual ──→ SVG/Metal rendered artwork             │
// │       ├──→ Audio Snapshot ──→ Spatial audio moment capture              │
// │       ├──→ Metadata Builder ──→ Dynamic on-chain attributes             │
// │       │                                                                  │
// │       ▼                                                                  │
// │  NFT Document (local)                                                    │
// │       │                                                                  │
// │       ├──→ Local Preview (SwiftUI)                                      │
// │       ├──→ Export (JSON metadata + media)                               │
// │       └──→ Mint (future: Solana/Base L2 integration)                    │
// └──────────────────────────────────────────────────────────────────────────┘
//
// Design Principles:
// 1. No blockchain dependency in core — NFT creation is local-first
// 2. Bio-reactive metadata — attributes change with bio-state
// 3. Audio + Visual + Bio combined in one token
// 4. Ethical monetization — artist gets 90%+ revenue
// 5. No speculation — value comes from authenticity, not scarcity
//
// Revenue Model:
// - Artists mint bio-reactive NFTs during live performances
// - Fans own a moment of authentic bio-reactive art
// - 10% royalties on secondary sales (perpetual income)
// - Platform: Solana (fast, cheap) or Base L2 (Ethereum ecosystem)
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import SwiftUI

// MARK: - NFT Types

/// Type of bio-reactive NFT
public enum MintType: String, CaseIterable, Codable, Sendable {
    case moment = "Moment"              // Single bio-reactive snapshot
    case journey = "Journey"            // Extended bio-reactive sequence
    case collaboration = "Collab"       // Multi-artist bio-reactive piece
    case live = "Live"                  // Minted during live performance
}

/// Rarity based on bio-state authenticity
public enum MintRarity: String, CaseIterable, Codable, Sendable {
    case common = "Common"              // Standard bio-state
    case uncommon = "Uncommon"          // Elevated coherence (>60%)
    case rare = "Rare"                  // High coherence (>80%)
    case legendary = "Legendary"        // Peak coherence (>95%) + musical peak
    case mythic = "Mythic"              // Sustained peak coherence during live performance

    /// Determine rarity from bio metrics
    public static func from(
        coherence: Float,
        isLive: Bool = false,
        sustainedSeconds: TimeInterval = 0
    ) -> MintRarity {
        if coherence > 0.95 && isLive && sustainedSeconds > 30 {
            return .mythic
        } else if coherence > 0.95 {
            return .legendary
        } else if coherence > 0.80 {
            return .rare
        } else if coherence > 0.60 {
            return .uncommon
        } else {
            return .common
        }
    }

    public var colorHex: String {
        switch self {
        case .common: return "#9CA3AF"
        case .uncommon: return "#34D399"
        case .rare: return "#60A5FA"
        case .legendary: return "#F59E0B"
        case .mythic: return "#EC4899"
        }
    }
}

/// Bio-reactive attributes that change dynamically
public struct BioReactiveAttributes: Codable, Sendable {
    public var coherence: Float             // 0-1 coherence at capture
    public var heartRate: Float             // BPM
    public var hrvSDNN: Float               // HRV in milliseconds
    public var breathingRate: Float         // Breaths per minute
    public var fieldGeometry: String        // fibonacci, grid, circle
    public var emotionalValence: Float      // -1 (negative) to 1 (positive)
    public var musicalEnergy: Float         // 0-1 energy level
    public var spatialDimension: String     // mono, stereo, spatial, immersive

    public static let empty = BioReactiveAttributes(
        coherence: 0, heartRate: 0, hrvSDNN: 0, breathingRate: 0,
        fieldGeometry: "grid", emotionalValence: 0, musicalEnergy: 0,
        spatialDimension: "stereo"
    )
}

/// Audio snapshot for NFT
public struct AudioSnapshot: Codable, Sendable {
    public var duration: TimeInterval       // Seconds (max 30s for moment)
    public var sampleRate: Int              // e.g., 44100
    public var format: String               // "wav", "aac", "flac"
    public var spatialFormat: String         // "stereo", "binaural", "ambisonics"
    public var peakFrequency: Float         // Dominant frequency Hz
    public var spectralCentroid: Float      // Brightness measure
    public var rmsLevel: Float              // Volume level
}

/// Visual snapshot for NFT
public struct VisualSnapshot: Codable, Sendable {
    public var type: String                 // "generative", "shader", "particle", "cymatics"
    public var resolution: String           // "1024x1024", "2048x2048"
    public var colorPalette: [String]       // Hex colors
    public var animationFrames: Int         // 0 = static, >0 = animated
    public var renderParameters: [String: Float]  // Shader/generation params
}

/// Complete NFT document (local, pre-mint)
public struct MintDocument: Codable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var description: String
    public var artistName: String
    public var mintType: MintType
    public var rarity: MintRarity
    public var bioAttributes: BioReactiveAttributes
    public var audioSnapshot: AudioSnapshot?
    public var visualSnapshot: VisualSnapshot?
    public var tags: [String]
    public var createdAt: Date
    public var location: String?            // Optional venue/location
    public var collaborators: [String]      // Other artists
    public var royaltyPercentage: Float     // Default 10%
    public var editionSize: Int             // 1 = unique, >1 = limited edition
    public var isMinted: Bool               // Has been published to chain
    public var mintHash: String?            // Transaction hash if minted

    public init(
        name: String,
        description: String = "",
        artistName: String = "",
        mintType: MintType = .moment,
        bioAttributes: BioReactiveAttributes = .empty
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.artistName = artistName
        self.mintType = mintType
        self.rarity = MintRarity.from(coherence: bioAttributes.coherence)
        self.bioAttributes = bioAttributes
        self.tags = []
        self.createdAt = Date()
        self.collaborators = []
        self.royaltyPercentage = 10.0
        self.editionSize = 1
        self.isMinted = false
    }

    /// Generate NFT metadata (ERC-721 / Metaplex compatible)
    public func toMetadata() -> [String: Any] {
        var metadata: [String: Any] = [
            "name": name,
            "description": description,
            "image": "ipfs://pending-upload/\(id.uuidString)", // Set after IPFS media upload
            "animation_url": "ipfs://pending-upload/\(id.uuidString)/animation",
            "external_url": "https://echoelmusic.com/nft/\(id.uuidString)",
            "attributes": [
                ["trait_type": "Type", "value": mintType.rawValue],
                ["trait_type": "Rarity", "value": rarity.rawValue],
                ["trait_type": "Coherence", "value": "\(Int(bioAttributes.coherence * 100))%"],
                ["trait_type": "Heart Rate", "value": "\(Int(bioAttributes.heartRate)) BPM"],
                ["trait_type": "HRV", "value": "\(Int(bioAttributes.hrvSDNN))ms"],
                ["trait_type": "Field Geometry", "value": bioAttributes.fieldGeometry],
                ["trait_type": "Musical Energy", "value": "\(Int(bioAttributes.musicalEnergy * 100))%"],
                ["trait_type": "Spatial", "value": bioAttributes.spatialDimension],
                ["trait_type": "Artist", "value": artistName],
                ["display_type": "date", "trait_type": "Created", "value": Int(createdAt.timeIntervalSince1970)],
            ],
            "properties": [
                "category": "audio",
                "creators": [
                    ["address": "", "share": 100]
                ],
                "files": [] as [[String: String]]
            ]
        ]

        if let location = location {
            var attrs = metadata["attributes"] as? [[String: Any]] ?? []
            attrs.append(["trait_type": "Venue", "value": location])
            metadata["attributes"] = attrs
        }

        return metadata
    }
}

/// Mint engine state
public enum MintEngineState: String, Sendable {
    case idle = "Idle"
    case capturing = "Capturing"          // Recording bio-reactive moment
    case processing = "Processing"        // Building NFT document
    case readyToMint = "Ready"           // Local document ready
    case minting = "Minting"              // Publishing to chain
    case minted = "Minted"               // Successfully published
    case error = "Error"
}

// MARK: - EchoelMintEngine

/// Bio-reactive Dynamic NFT creation engine
///
/// Captures bio-reactive moments and packages them as NFT-ready documents.
/// The engine handles local creation and preview — actual minting to blockchain
/// is delegated to a future integration layer.
///
/// Usage:
/// ```swift
/// let mint = EchoelMintEngine.shared
///
/// // Start capturing a bio-reactive moment
/// mint.startCapture(type: .moment)
///
/// // ... bio-reactive data flows in from EngineBus ...
///
/// // End capture
/// let document = mint.endCapture(
///     name: "Coherence Peak @ Berlin Show",
///     artistName: "Echoel"
/// )
///
/// // Preview
/// print(document.rarity) // .legendary
/// print(document.bioAttributes.coherence) // 0.97
///
/// // Export metadata
/// let metadata = document.toMetadata()
/// ```
@MainActor
public final class EchoelMintEngine: ObservableObject {

    public static let shared = EchoelMintEngine()

    // MARK: - Published State

    /// Current engine state
    @Published public var state: MintEngineState = .idle

    /// Active capture in progress
    @Published public var activeCapture: MintDocument?

    /// All local NFT documents (not yet minted)
    @Published public var drafts: [MintDocument] = []

    /// All minted NFTs
    @Published public var minted: [MintDocument] = []

    /// Current bio-reactive attributes (live)
    @Published public var liveBioAttributes: BioReactiveAttributes = .empty

    /// Capture duration (for journey type)
    @Published public var captureDuration: TimeInterval = 0

    /// Peak coherence during capture
    @Published public var peakCoherence: Float = 0

    /// Is live performance mode (affects rarity)
    @Published public var isLivePerformance: Bool = false

    /// Default artist name
    @Published public var defaultArtistName: String = ""

    /// Default royalty percentage
    @Published public var defaultRoyaltyPercentage: Float = 10.0

    // MARK: - Internal

    private var cancellables = Set<AnyCancellable>()
    private var busSubscription: BusSubscription?
    private var captureStartTime: Date?
    private var bioSamples: [BioReactiveAttributes] = []
    private var captureTimer: Timer?

    // MARK: - Initialization

    private init() {
        subscribeToBus()
        loadDrafts()
    }

    // MARK: - Capture API

    /// Start capturing a bio-reactive moment
    public func startCapture(type: MintType = .moment) {
        state = .capturing
        captureStartTime = Date()
        bioSamples.removeAll()
        peakCoherence = 0
        captureDuration = 0

        activeCapture = MintDocument(
            name: "",
            mintType: type,
            bioAttributes: liveBioAttributes
        )

        // Sample bio data at 10Hz during capture
        captureTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.bioSamples.append(self.liveBioAttributes)
                self.captureDuration = Date().timeIntervalSince(self.captureStartTime ?? Date())
                self.peakCoherence = max(self.peakCoherence, self.liveBioAttributes.coherence)
            }
        }

        EngineBus.shared.publish(.custom(
            topic: "mint.capture.start",
            payload: ["type": type.rawValue]
        ))
    }

    /// End capture and build NFT document
    public func endCapture(
        name: String,
        description: String = "",
        artistName: String? = nil,
        tags: [String] = [],
        location: String? = nil,
        editionSize: Int = 1
    ) -> MintDocument? {
        guard state == .capturing else { return nil }

        captureTimer?.invalidate()
        captureTimer = nil

        // Calculate averaged bio attributes from all samples
        let avgAttributes = averageBioAttributes(bioSamples)
        let duration = Date().timeIntervalSince(captureStartTime ?? Date())

        // Determine rarity
        let rarity = MintRarity.from(
            coherence: peakCoherence,
            isLive: isLivePerformance,
            sustainedSeconds: duration
        )

        var document = MintDocument(
            name: name,
            description: description.isEmpty ? generateDescription(rarity: rarity, attributes: avgAttributes) : description,
            artistName: artistName ?? defaultArtistName,
            mintType: activeCapture?.mintType ?? .moment,
            bioAttributes: avgAttributes
        )

        document.rarity = rarity
        document.tags = tags
        document.location = location
        document.editionSize = editionSize
        document.royaltyPercentage = defaultRoyaltyPercentage

        // Add audio snapshot
        document.audioSnapshot = AudioSnapshot(
            duration: min(duration, 30),
            sampleRate: 44100,
            format: "aac",
            spatialFormat: avgAttributes.spatialDimension,
            peakFrequency: 0,
            spectralCentroid: 0,
            rmsLevel: avgAttributes.musicalEnergy
        )

        // Add visual snapshot
        document.visualSnapshot = VisualSnapshot(
            type: "generative",
            resolution: "2048x2048",
            colorPalette: generateColorPalette(from: avgAttributes),
            animationFrames: document.mintType == .moment ? 0 : 120,
            renderParameters: [
                "coherence": avgAttributes.coherence,
                "energy": avgAttributes.musicalEnergy,
                "heartRate": avgAttributes.heartRate / 200.0, // Normalize
            ]
        )

        // Save draft
        drafts.append(document)
        saveDrafts()

        activeCapture = nil
        state = .readyToMint

        EngineBus.shared.publish(.custom(
            topic: "mint.capture.end",
            payload: [
                "name": name,
                "rarity": rarity.rawValue,
                "coherence": "\(Int(peakCoherence * 100))%",
                "duration": "\(Int(duration))s"
            ]
        ))

        return document
    }

    /// Cancel active capture
    public func cancelCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        activeCapture = nil
        bioSamples.removeAll()
        state = .idle
    }

    /// Quick capture — instant snapshot of current bio-state
    public func quickCapture(name: String) -> MintDocument {
        let rarity = MintRarity.from(
            coherence: liveBioAttributes.coherence,
            isLive: isLivePerformance
        )

        var document = MintDocument(
            name: name,
            description: generateDescription(rarity: rarity, attributes: liveBioAttributes),
            artistName: defaultArtistName,
            mintType: .moment,
            bioAttributes: liveBioAttributes
        )
        document.rarity = rarity

        drafts.append(document)
        saveDrafts()

        return document
    }

    // MARK: - Draft Management

    /// Delete a draft
    public func deleteDraft(id: UUID) {
        drafts.removeAll { $0.id == id }
        saveDrafts()
    }

    /// Export draft metadata as JSON
    public func exportMetadata(for document: MintDocument) -> Data? {
        let metadata = document.toMetadata()
        return try? JSONSerialization.data(
            withJSONObject: metadata,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    // MARK: - Private Methods

    /// Average bio attributes from samples
    private func averageBioAttributes(_ samples: [BioReactiveAttributes]) -> BioReactiveAttributes {
        guard !samples.isEmpty else { return liveBioAttributes }

        let count = Float(samples.count)
        return BioReactiveAttributes(
            coherence: samples.map(\.coherence).reduce(0, +) / count,
            heartRate: samples.map(\.heartRate).reduce(0, +) / count,
            hrvSDNN: samples.map(\.hrvSDNN).reduce(0, +) / count,
            breathingRate: samples.map(\.breathingRate).reduce(0, +) / count,
            fieldGeometry: samples.last?.fieldGeometry ?? "grid",
            emotionalValence: samples.map(\.emotionalValence).reduce(0, +) / count,
            musicalEnergy: samples.map(\.musicalEnergy).reduce(0, +) / count,
            spatialDimension: samples.last?.spatialDimension ?? "stereo"
        )
    }

    /// Generate automatic description based on bio-state
    private func generateDescription(rarity: MintRarity, attributes: BioReactiveAttributes) -> String {
        let coherenceDesc: String
        switch attributes.coherence {
        case 0..<0.3: coherenceDesc = "in a state of raw, unfiltered emotion"
        case 0.3..<0.6: coherenceDesc = "finding balance between chaos and harmony"
        case 0.6..<0.8: coherenceDesc = "in deep creative flow"
        case 0.8..<0.95: coherenceDesc = "at the edge of transcendent coherence"
        default: coherenceDesc = "in a state of peak human coherence"
        }

        let geometryDesc = attributes.fieldGeometry == "fibonacci"
            ? "with sacred geometry emerging naturally from the heartbeat"
            : "with crystalline patterns reflecting inner state"

        return "A bio-reactive moment captured \(coherenceDesc), \(geometryDesc). Heart rate: \(Int(attributes.heartRate)) BPM, HRV: \(Int(attributes.hrvSDNN))ms. This is not generated art — it is a direct translation of a human body's electromagnetic field into sound and light."
    }

    /// Generate color palette from bio attributes
    private func generateColorPalette(from attributes: BioReactiveAttributes) -> [String] {
        // Bio-reactive color mapping
        let coherenceHue = attributes.coherence * 120 // 0=red, 120=green
        let energySaturation = 0.5 + attributes.musicalEnergy * 0.5
        let valenceBrightness = 0.4 + (attributes.emotionalValence + 1) * 0.3

        // Generate 5-color palette
        return [
            hslToHex(h: coherenceHue, s: energySaturation, l: valenceBrightness),
            hslToHex(h: coherenceHue + 30, s: energySaturation * 0.8, l: valenceBrightness + 0.1),
            hslToHex(h: coherenceHue - 30, s: energySaturation * 0.6, l: valenceBrightness - 0.1),
            hslToHex(h: coherenceHue + 180, s: energySaturation * 0.4, l: 0.2), // Complementary dark
            hslToHex(h: coherenceHue, s: 0.1, l: 0.95), // Near-white accent
        ]
    }

    /// Convert HSL to hex color string
    private func hslToHex(h: Float, s: Float, l: Float) -> String {
        let hue = max(0, min(360, h)) / 360
        let sat = max(0, min(1, s))
        let light = max(0, min(1, l))

        let c = (1 - abs(2 * light - 1)) * sat
        let x = c * (1 - abs((hue * 6).truncatingRemainder(dividingBy: 2) - 1))
        let m = light - c / 2

        var r: Float = 0, g: Float = 0, b: Float = 0
        let segment = Int(hue * 6)

        switch segment {
        case 0: r = c; g = x; b = 0
        case 1: r = x; g = c; b = 0
        case 2: r = 0; g = c; b = x
        case 3: r = 0; g = x; b = c
        case 4: r = x; g = 0; b = c
        default: r = c; g = 0; b = x
        }

        let ri = Int((r + m) * 255)
        let gi = Int((g + m) * 255)
        let bi = Int((b + m) * 255)

        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }

    /// Subscribe to EngineBus for bio-reactive data
    private func subscribeToBus() {
        busSubscription = EngineBus.shared.subscribe(to: .bio) { [weak self] msg in
            if case .bioUpdate(let bio) = msg {
                Task { @MainActor in
                    self?.liveBioAttributes = BioReactiveAttributes(
                        coherence: bio.coherence,
                        heartRate: bio.heartRate,
                        hrvSDNN: bio.hrvSDNN,
                        breathingRate: bio.breathingRate,
                        fieldGeometry: bio.coherence > 0.6 ? "fibonacci" : "grid",
                        emotionalValence: bio.coherence > 0.5 ? 0.5 : -0.2,
                        musicalEnergy: bio.energy,
                        spatialDimension: "spatial"
                    )
                }
            }
        }
    }

    // MARK: - Persistence

    private var draftsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("echoelmint_drafts.json")
    }

    private func saveDrafts() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(drafts) else { return }
        try? data.write(to: draftsURL, options: .atomic)
    }

    private func loadDrafts() {
        guard let data = try? Data(contentsOf: draftsURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        drafts = (try? decoder.decode([MintDocument].self, from: data)) ?? []
    }
}
