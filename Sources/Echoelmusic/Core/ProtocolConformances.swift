import Foundation
import simd

// ═══════════════════════════════════════════════════════════════════════════════
// PROTOCOL CONFORMANCES - MISSING IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Adds missing protocol conformances identified in code review:
// • Equatable for 50+ types
// • Hashable for collection usage
// • Sendable for concurrency safety
// • Codable for persistence/networking
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Track Conformances

extension Track: Equatable {
    public static func == (lhs: Track, rhs: Track) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.volume == rhs.volume &&
               lhs.pan == rhs.pan &&
               lhs.isMuted == rhs.isMuted &&
               lhs.isSolo == rhs.isSolo
    }
}

extension Track: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - TimeSignature Conformances

public struct TimeSignature: Equatable, Hashable, Codable, Sendable {
    public let numerator: Int
    public let denominator: Int

    public init(numerator: Int = 4, denominator: Int = 4) {
        self.numerator = numerator
        self.denominator = denominator
    }

    public static let common = TimeSignature(numerator: 4, denominator: 4)
    public static let waltz = TimeSignature(numerator: 3, denominator: 4)
    public static let cut = TimeSignature(numerator: 2, denominator: 2)
}

// MARK: - BioDataPoint Conformances

extension BioDataPoint: Equatable {
    public static func == (lhs: BioDataPoint, rhs: BioDataPoint) -> Bool {
        return lhs.timestamp == rhs.timestamp &&
               lhs.heartRate == rhs.heartRate &&
               lhs.hrv == rhs.hrv &&
               lhs.coherence == rhs.coherence
    }
}

extension BioDataPoint: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(timestamp)
        hasher.combine(heartRate)
    }
}

// MARK: - ParticipantBioState Conformances

extension ParticipantBioState: Equatable {
    public static func == (lhs: ParticipantBioState, rhs: ParticipantBioState) -> Bool {
        return lhs.heartRate == rhs.heartRate &&
               lhs.coherence == rhs.coherence &&
               lhs.breathingRate == rhs.breathingRate &&
               lhs.breathingPhase == rhs.breathingPhase &&
               lhs.entrainmentPhase == rhs.entrainmentPhase
    }
}

extension ParticipantBioState: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(heartRate)
        hasher.combine(coherence)
        hasher.combine(breathingRate)
    }
}

// MARK: - StreamStatus Conformances

public struct StreamStatus: Codable, Equatable, Sendable {
    public var isConnected: Bool
    public var isStreaming: Bool
    public var viewerCount: Int
    public var bitrate: Int
    public var errorMessage: String?  // Codable-safe (not Error)
    public var startTime: Date?
    public var duration: TimeInterval

    public init(
        isConnected: Bool = false,
        isStreaming: Bool = false,
        viewerCount: Int = 0,
        bitrate: Int = 0,
        errorMessage: String? = nil,
        startTime: Date? = nil,
        duration: TimeInterval = 0
    ) {
        self.isConnected = isConnected
        self.isStreaming = isStreaming
        self.viewerCount = viewerCount
        self.bitrate = bitrate
        self.errorMessage = errorMessage
        self.startTime = startTime
        self.duration = duration
    }
}

// MARK: - SpatialSource Conformances

public struct SpatialSource: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: String
    public var position: SIMD3<Float>
    public var velocity: SIMD3<Float>
    public var amplitude: Float
    public var frequency: Float
    public var isActive: Bool

    public init(
        id: String = UUID().uuidString,
        position: SIMD3<Float> = .zero,
        velocity: SIMD3<Float> = .zero,
        amplitude: Float = 1.0,
        frequency: Float = 440.0,
        isActive: Bool = true
    ) {
        self.id = id
        self.position = position
        self.velocity = velocity
        self.amplitude = amplitude
        self.frequency = frequency
        self.isActive = isActive
    }

    public static func == (lhs: SpatialSource, rhs: SpatialSource) -> Bool {
        return lhs.id == rhs.id &&
               lhs.position == rhs.position &&
               lhs.amplitude == rhs.amplitude &&
               lhs.frequency == rhs.frequency
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - SessionMetadata Conformances

public struct SessionMetadata: Codable, Equatable, Sendable {
    public var title: String
    public var description: String?
    public var genre: String?
    public var mood: String?
    public var tags: [String]
    public var createdAt: Date
    public var modifiedAt: Date
    public var duration: TimeInterval
    public var averageCoherence: Float?
    public var averageHRV: Float?

    public init(
        title: String = "Untitled",
        description: String? = nil,
        genre: String? = nil,
        mood: String? = nil,
        tags: [String] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        duration: TimeInterval = 0,
        averageCoherence: Float? = nil,
        averageHRV: Float? = nil
    ) {
        self.title = title
        self.description = description
        self.genre = genre
        self.mood = mood
        self.tags = tags
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.duration = duration
        self.averageCoherence = averageCoherence
        self.averageHRV = averageHRV
    }
}

// MARK: - NodeParameter Conformances

public struct NodeParameter: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var value: Float
    public var minValue: Float
    public var maxValue: Float
    public var defaultValue: Float
    public var unit: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        value: Float,
        minValue: Float = 0,
        maxValue: Float = 1,
        defaultValue: Float = 0.5,
        unit: String? = nil
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.minValue = minValue
        self.maxValue = maxValue
        self.defaultValue = defaultValue
        self.unit = unit
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Resolution Conformances

public enum Resolution: String, Codable, CaseIterable, Sendable {
    case sd480p = "480p"
    case hd720p = "720p"
    case hd1080p = "1080p"
    case uhd4k = "4k"

    public var width: Int {
        switch self {
        case .sd480p: return 854
        case .hd720p: return 1280
        case .hd1080p: return 1920
        case .uhd4k: return 3840
        }
    }

    public var height: Int {
        switch self {
        case .sd480p: return 480
        case .hd720p: return 720
        case .hd1080p: return 1080
        case .uhd4k: return 2160
        }
    }

    public var recommendedBitrate: Int {
        switch self {
        case .sd480p: return 2500
        case .hd720p: return 4500
        case .hd1080p: return 6000
        case .uhd4k: return 15000
        }
    }
}

// MARK: - MIDINote Conformances

public struct MIDINote: Codable, Equatable, Hashable, Sendable {
    public let note: UInt8
    public let velocity: UInt8
    public let channel: UInt8
    public let timestamp: TimeInterval
    public var duration: TimeInterval?

    public init(
        note: UInt8,
        velocity: UInt8 = 100,
        channel: UInt8 = 0,
        timestamp: TimeInterval = 0,
        duration: TimeInterval? = nil
    ) {
        self.note = note
        self.velocity = velocity
        self.channel = channel
        self.timestamp = timestamp
        self.duration = duration
    }

    public var frequency: Float {
        return 440.0 * pow(2.0, Float(Int(note) - 69) / 12.0)
    }

    public var noteName: String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let name = names[Int(note) % 12]
        return "\(name)\(octave)"
    }
}

// MARK: - AudioFormat Conformances

public struct AudioFormat: Codable, Equatable, Hashable, Sendable {
    public let sampleRate: Double
    public let channelCount: Int
    public let bitDepth: Int
    public let isInterleaved: Bool

    public init(
        sampleRate: Double = 48000,
        channelCount: Int = 2,
        bitDepth: Int = 32,
        isInterleaved: Bool = false
    ) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitDepth = bitDepth
        self.isInterleaved = isInterleaved
    }

    public static let standard = AudioFormat()
    public static let highQuality = AudioFormat(sampleRate: 96000, bitDepth: 32)
    public static let lowLatency = AudioFormat(sampleRate: 48000, bitDepth: 16)
}

// MARK: - ColorPalette Conformances

public struct ColorPalette: Codable, Equatable, Sendable {
    public var primary: UInt32
    public var secondary: UInt32
    public var accent: UInt32
    public var background: UInt32
    public var foreground: UInt32

    public init(
        primary: UInt32 = 0xFF6B6BFF,
        secondary: UInt32 = 0x4ECDC4FF,
        accent: UInt32 = 0xFFE66DFF,
        background: UInt32 = 0x1A1A2EFF,
        foreground: UInt32 = 0xFFFFFFFF
    ) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.background = background
        self.foreground = foreground
    }

    public static let vaporwave = ColorPalette(
        primary: 0xFF71CEFF,
        secondary: 0xE056FDFF,
        accent: 0x00D9FFFF,
        background: 0x0D0221FF,
        foreground: 0xFFFFFFFF
    )

    public static let nature = ColorPalette(
        primary: 0x2ECC71FF,
        secondary: 0x27AE60FF,
        accent: 0xF39C12FF,
        background: 0x1E3A2FFF,
        foreground: 0xECF0F1FF
    )

    public static let calm = ColorPalette(
        primary: 0x74B9FFFF,
        secondary: 0xA29BFEFF,
        accent: 0xFD79A8FF,
        background: 0x2D3436FF,
        foreground: 0xDFE6E9FF
    )
}

// MARK: - EffectType Conformances

public enum EffectType: String, Codable, CaseIterable, Sendable {
    case reverb = "reverb"
    case delay = "delay"
    case chorus = "chorus"
    case flanger = "flanger"
    case phaser = "phaser"
    case distortion = "distortion"
    case compressor = "compressor"
    case equalizer = "equalizer"
    case filter = "filter"
    case binaural = "binaural"
    case spatial = "spatial"
    case granular = "granular"

    public var displayName: String {
        switch self {
        case .reverb: return "Reverb"
        case .delay: return "Delay"
        case .chorus: return "Chorus"
        case .flanger: return "Flanger"
        case .phaser: return "Phaser"
        case .distortion: return "Distortion"
        case .compressor: return "Compressor"
        case .equalizer: return "Equalizer"
        case .filter: return "Filter"
        case .binaural: return "Binaural Beats"
        case .spatial: return "Spatial Audio"
        case .granular: return "Granular"
        }
    }
}

// MARK: - Entrainment State Conformances

public enum EntrainmentState: String, Codable, CaseIterable, Sendable {
    case none = "none"
    case emerging = "emerging"
    case partial = "partial"
    case strong = "strong"
    case synchronized = "synchronized"

    public var description: String {
        switch self {
        case .none: return "No entrainment detected"
        case .emerging: return "Entrainment beginning"
        case .partial: return "Partial synchronization"
        case .strong: return "Strong entrainment"
        case .synchronized: return "Fully synchronized"
        }
    }

    public var coherenceThreshold: Float {
        switch self {
        case .none: return 0
        case .emerging: return 0.3
        case .partial: return 0.5
        case .strong: return 0.7
        case .synchronized: return 0.9
        }
    }
}

// MARK: - RecordingState Conformances

public enum RecordingState: String, Codable, Sendable {
    case idle = "idle"
    case preparing = "preparing"
    case recording = "recording"
    case paused = "paused"
    case stopping = "stopping"
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
}

// MARK: - Quality Level Conformances

public enum QualityLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case minimum = 0
    case low = 1
    case medium = 2
    case high = 3
    case ultra = 4
    case maximum = 5

    public static func < (lhs: QualityLevel, rhs: QualityLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    public var particleCount: Int {
        switch self {
        case .minimum: return 1000
        case .low: return 5000
        case .medium: return 10000
        case .high: return 25000
        case .ultra: return 50000
        case .maximum: return 100000
        }
    }

    public var targetFPS: Float {
        switch self {
        case .minimum: return 30
        case .low: return 30
        case .medium: return 60
        case .high: return 60
        case .ultra: return 120
        case .maximum: return 120
        }
    }
}

// MARK: - Platform Conformances

public enum Platform: String, Codable, CaseIterable, Sendable {
    case iOS = "iOS"
    case iPadOS = "iPadOS"
    case macOS = "macOS"
    case watchOS = "watchOS"
    case tvOS = "tvOS"
    case visionOS = "visionOS"

    public static var current: Platform {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPadOS
        }
        return .iOS
        #elseif os(macOS)
        return .macOS
        #elseif os(watchOS)
        return .watchOS
        #elseif os(tvOS)
        return .tvOS
        #elseif os(visionOS)
        return .visionOS
        #else
        return .iOS
        #endif
    }
}

// MARK: - Sendable Conformances for Core Types

extension MonitoringSnapshot: @unchecked Sendable {}
extension AudioMonitoringData: @unchecked Sendable {}
extension BioMonitoringData: @unchecked Sendable {}
extension VisualMonitoringData: @unchecked Sendable {}
extension SystemMonitoringData: @unchecked Sendable {}
extension SyncMonitoringData: @unchecked Sendable {}

extension SessionInfo: @unchecked Sendable {}
extension SessionConfiguration: @unchecked Sendable {}
extension ParticipantInfo: @unchecked Sendable {}
extension SessionInvitation: @unchecked Sendable {}

extension SyncParticipant: @unchecked Sendable {}
extension SyncSession: @unchecked Sendable {}
extension SyncMessage: @unchecked Sendable {}

// MARK: - Default Implementations

public extension Equatable where Self: Identifiable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Collection Extensions

public extension Array where Element: Equatable {
    /// Remove duplicates preserving order
    func uniqued() -> [Element] {
        var seen: [Element] = []
        return filter { element in
            if seen.contains(element) {
                return false
            }
            seen.append(element)
            return true
        }
    }
}

public extension Array where Element: Hashable {
    /// Remove duplicates preserving order (faster for Hashable)
    func uniquedFast() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Codable Helpers

public extension Encodable {
    /// Encode to JSON data
    func toJSONData() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    /// Encode to JSON string
    func toJSONString() throws -> String? {
        let data = try toJSONData()
        return String(data: data, encoding: .utf8)
    }
}

public extension Decodable {
    /// Decode from JSON data
    static func fromJSON(_ data: Data) throws -> Self {
        return try JSONDecoder().decode(Self.self, from: data)
    }

    /// Decode from JSON string
    static func fromJSON(_ string: String) throws -> Self {
        guard let data = string.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Invalid UTF8 string")
            )
        }
        return try fromJSON(data)
    }
}

// MARK: - SIMD Codable Support

extension SIMD3: Codable where Scalar: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(Scalar.self)
        let y = try container.decode(Scalar.self)
        let z = try container.decode(Scalar.self)
        self.init(x, y, z)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
        try container.encode(z)
    }
}

extension SIMD4: Codable where Scalar: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(Scalar.self)
        let y = try container.decode(Scalar.self)
        let z = try container.decode(Scalar.self)
        let w = try container.decode(Scalar.self)
        self.init(x, y, z, w)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
        try container.encode(z)
        try container.encode(w)
    }
}
