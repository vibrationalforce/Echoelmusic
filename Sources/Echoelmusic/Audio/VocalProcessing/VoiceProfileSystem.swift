import Foundation
import Combine
import AVFoundation
import Accelerate

// MARK: - Voice Profile

/// Complete snapshot of all ProVocalChain parameters — serializable, shareable, switchable.
/// Implements EnginePreset for integration with the existing PresetManager system.
public struct VoiceProfile: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var category: VoiceProfileCategory
    public var author: String
    public var version: String
    public var createdAt: Date
    public var isFactory: Bool

    // MARK: - Voice Characterization (from analysis of recorded voice)

    /// MFCC fingerprint (13 coefficients) — captures vocal timbre
    public var mfccFingerprint: [Float]?
    /// Average fundamental frequency (Hz) — vocal range center
    public var fundamentalFrequency: Float?
    /// Spectral centroid — voice brightness (Hz)
    public var spectralCentroid: Float?
    /// Formant frequencies [F1, F2, F3] — throat shape signature
    public var formantFrequencies: [Float]?
    /// Pitch range (min Hz, max Hz) — vocal extent
    public var pitchRange: (min: Float, max: Float)?

    // MARK: - Pitch Correction Settings

    public var pitchCorrectionEnabled: Bool = true
    public var rootNote: Int = 0
    public var scaleType: RealTimePitchCorrector.ScaleType = .chromatic
    public var correctionSpeed: Float = 50
    public var correctionStrength: Float = 0.8
    public var humanize: Float = 0.2
    public var flexTuneThreshold: Float = 10
    public var preserveFormants: Bool = true
    public var formantShift: Float = 0
    public var transpose: Int = 0
    public var referenceA4: Float = 440

    // MARK: - Vibrato Settings

    public var vibratoEnabled: Bool = true
    public var vibratoRate: Float = 5.5
    public var vibratoDepth: Float = 40
    public var vibratoShape: VibratoEngine.VibratoShape = .sine
    public var vibratoOnsetDelay: Float = 0.2
    public var vibratoFadeInTime: Float = 0.3
    public var vibratoFadeOutTime: Float = 0.1
    public var vibratoRateVariation: Float = 0.1
    public var vibratoDepthVariation: Float = 0.1
    public var vibratoAsymmetry: Float = 0

    // MARK: - Harmony Settings

    public var harmonyEnabled: Bool = false
    public var harmonyMode: VocalHarmonyGenerator.HarmonyMode = .diatonic
    public var harmonyKey: Int = 0
    public var harmonyScale: VocalHarmonyGenerator.ScaleType = .major
    public var harmonyDryWet: Float = 0.5
    public var harmonyHumanize: Float = 0.1
    public var harmonyVoices: [VocalHarmonyGenerator.HarmonyVoice] = []

    // MARK: - Doubling Settings

    public var doublingEnabled: Bool = false
    public var doublingStyle: VocalDoublingEngine.DoublingStyle = .natural
    public var doublingDryWet: Float = 0.5
    public var doublingStereoWidth: Float = 0.7
    public var doublingVoices: [VocalDoublingEngine.DoublingVoice] = []

    // MARK: - Breath Detection Settings

    public var breathDetectionEnabled: Bool = false
    public var breathSensitivity: Float = 0.5
    public var breathMinDuration: Float = 0.1
    public var breathMaxDuration: Float = 2.0
    public var breathReductionGain: Float = 0.0
    public var breathMode: BreathDetector.DetectionMode = .remove

    // MARK: - Bio-Reactive Settings

    public var bioReactiveEnabled: Bool = false
    public var bioMappingPreset: String = "default"
    public var bioSensitivity: Float = 0.7

    // MARK: - Codable for pitchRange tuple

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, author, version, createdAt, isFactory
        case mfccFingerprint, fundamentalFrequency, spectralCentroid, formantFrequencies
        case pitchRangeMin, pitchRangeMax
        case pitchCorrectionEnabled, rootNote, scaleType, correctionSpeed, correctionStrength
        case humanize, flexTuneThreshold, preserveFormants, formantShift, transpose, referenceA4
        case vibratoEnabled, vibratoRate, vibratoDepth, vibratoShape, vibratoOnsetDelay
        case vibratoFadeInTime, vibratoFadeOutTime, vibratoRateVariation, vibratoDepthVariation, vibratoAsymmetry
        case harmonyEnabled, harmonyMode, harmonyKey, harmonyScale, harmonyDryWet, harmonyHumanize, harmonyVoices
        case doublingEnabled, doublingStyle, doublingDryWet, doublingStereoWidth, doublingVoices
        case breathDetectionEnabled, breathSensitivity, breathMinDuration, breathMaxDuration
        case breathReductionGain, breathMode
        case bioReactiveEnabled, bioMappingPreset, bioSensitivity
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decode(String.self, forKey: .description)
        category = try c.decode(VoiceProfileCategory.self, forKey: .category)
        author = try c.decode(String.self, forKey: .author)
        version = try c.decode(String.self, forKey: .version)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        isFactory = try c.decode(Bool.self, forKey: .isFactory)
        mfccFingerprint = try c.decodeIfPresent([Float].self, forKey: .mfccFingerprint)
        fundamentalFrequency = try c.decodeIfPresent(Float.self, forKey: .fundamentalFrequency)
        spectralCentroid = try c.decodeIfPresent(Float.self, forKey: .spectralCentroid)
        formantFrequencies = try c.decodeIfPresent([Float].self, forKey: .formantFrequencies)
        if let pMin = try c.decodeIfPresent(Float.self, forKey: .pitchRangeMin),
           let pMax = try c.decodeIfPresent(Float.self, forKey: .pitchRangeMax) {
            pitchRange = (pMin, pMax)
        }
        pitchCorrectionEnabled = try c.decode(Bool.self, forKey: .pitchCorrectionEnabled)
        rootNote = try c.decode(Int.self, forKey: .rootNote)
        scaleType = try c.decode(RealTimePitchCorrector.ScaleType.self, forKey: .scaleType)
        correctionSpeed = try c.decode(Float.self, forKey: .correctionSpeed)
        correctionStrength = try c.decode(Float.self, forKey: .correctionStrength)
        humanize = try c.decode(Float.self, forKey: .humanize)
        flexTuneThreshold = try c.decode(Float.self, forKey: .flexTuneThreshold)
        preserveFormants = try c.decode(Bool.self, forKey: .preserveFormants)
        formantShift = try c.decode(Float.self, forKey: .formantShift)
        transpose = try c.decode(Int.self, forKey: .transpose)
        referenceA4 = try c.decode(Float.self, forKey: .referenceA4)
        vibratoEnabled = try c.decode(Bool.self, forKey: .vibratoEnabled)
        vibratoRate = try c.decode(Float.self, forKey: .vibratoRate)
        vibratoDepth = try c.decode(Float.self, forKey: .vibratoDepth)
        vibratoShape = try c.decode(VibratoEngine.VibratoShape.self, forKey: .vibratoShape)
        vibratoOnsetDelay = try c.decode(Float.self, forKey: .vibratoOnsetDelay)
        vibratoFadeInTime = try c.decode(Float.self, forKey: .vibratoFadeInTime)
        vibratoFadeOutTime = try c.decode(Float.self, forKey: .vibratoFadeOutTime)
        vibratoRateVariation = try c.decode(Float.self, forKey: .vibratoRateVariation)
        vibratoDepthVariation = try c.decode(Float.self, forKey: .vibratoDepthVariation)
        vibratoAsymmetry = try c.decode(Float.self, forKey: .vibratoAsymmetry)
        harmonyEnabled = try c.decode(Bool.self, forKey: .harmonyEnabled)
        harmonyMode = try c.decode(VocalHarmonyGenerator.HarmonyMode.self, forKey: .harmonyMode)
        harmonyKey = try c.decode(Int.self, forKey: .harmonyKey)
        harmonyScale = try c.decode(VocalHarmonyGenerator.ScaleType.self, forKey: .harmonyScale)
        harmonyDryWet = try c.decode(Float.self, forKey: .harmonyDryWet)
        harmonyHumanize = try c.decode(Float.self, forKey: .harmonyHumanize)
        harmonyVoices = try c.decode([VocalHarmonyGenerator.HarmonyVoice].self, forKey: .harmonyVoices)
        doublingEnabled = try c.decode(Bool.self, forKey: .doublingEnabled)
        doublingStyle = try c.decode(VocalDoublingEngine.DoublingStyle.self, forKey: .doublingStyle)
        doublingDryWet = try c.decode(Float.self, forKey: .doublingDryWet)
        doublingStereoWidth = try c.decode(Float.self, forKey: .doublingStereoWidth)
        doublingVoices = try c.decode([VocalDoublingEngine.DoublingVoice].self, forKey: .doublingVoices)
        breathDetectionEnabled = try c.decode(Bool.self, forKey: .breathDetectionEnabled)
        breathSensitivity = try c.decode(Float.self, forKey: .breathSensitivity)
        breathMinDuration = try c.decode(Float.self, forKey: .breathMinDuration)
        breathMaxDuration = try c.decode(Float.self, forKey: .breathMaxDuration)
        breathReductionGain = try c.decode(Float.self, forKey: .breathReductionGain)
        breathMode = try c.decode(BreathDetector.DetectionMode.self, forKey: .breathMode)
        bioReactiveEnabled = try c.decode(Bool.self, forKey: .bioReactiveEnabled)
        bioMappingPreset = try c.decode(String.self, forKey: .bioMappingPreset)
        bioSensitivity = try c.decode(Float.self, forKey: .bioSensitivity)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(description, forKey: .description)
        try c.encode(category, forKey: .category)
        try c.encode(author, forKey: .author)
        try c.encode(version, forKey: .version)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(isFactory, forKey: .isFactory)
        try c.encodeIfPresent(mfccFingerprint, forKey: .mfccFingerprint)
        try c.encodeIfPresent(fundamentalFrequency, forKey: .fundamentalFrequency)
        try c.encodeIfPresent(spectralCentroid, forKey: .spectralCentroid)
        try c.encodeIfPresent(formantFrequencies, forKey: .formantFrequencies)
        try c.encodeIfPresent(pitchRange?.min, forKey: .pitchRangeMin)
        try c.encodeIfPresent(pitchRange?.max, forKey: .pitchRangeMax)
        try c.encode(pitchCorrectionEnabled, forKey: .pitchCorrectionEnabled)
        try c.encode(rootNote, forKey: .rootNote)
        try c.encode(scaleType, forKey: .scaleType)
        try c.encode(correctionSpeed, forKey: .correctionSpeed)
        try c.encode(correctionStrength, forKey: .correctionStrength)
        try c.encode(humanize, forKey: .humanize)
        try c.encode(flexTuneThreshold, forKey: .flexTuneThreshold)
        try c.encode(preserveFormants, forKey: .preserveFormants)
        try c.encode(formantShift, forKey: .formantShift)
        try c.encode(transpose, forKey: .transpose)
        try c.encode(referenceA4, forKey: .referenceA4)
        try c.encode(vibratoEnabled, forKey: .vibratoEnabled)
        try c.encode(vibratoRate, forKey: .vibratoRate)
        try c.encode(vibratoDepth, forKey: .vibratoDepth)
        try c.encode(vibratoShape, forKey: .vibratoShape)
        try c.encode(vibratoOnsetDelay, forKey: .vibratoOnsetDelay)
        try c.encode(vibratoFadeInTime, forKey: .vibratoFadeInTime)
        try c.encode(vibratoFadeOutTime, forKey: .vibratoFadeOutTime)
        try c.encode(vibratoRateVariation, forKey: .vibratoRateVariation)
        try c.encode(vibratoDepthVariation, forKey: .vibratoDepthVariation)
        try c.encode(vibratoAsymmetry, forKey: .vibratoAsymmetry)
        try c.encode(harmonyEnabled, forKey: .harmonyEnabled)
        try c.encode(harmonyMode, forKey: .harmonyMode)
        try c.encode(harmonyKey, forKey: .harmonyKey)
        try c.encode(harmonyScale, forKey: .harmonyScale)
        try c.encode(harmonyDryWet, forKey: .harmonyDryWet)
        try c.encode(harmonyHumanize, forKey: .harmonyHumanize)
        try c.encode(harmonyVoices, forKey: .harmonyVoices)
        try c.encode(doublingEnabled, forKey: .doublingEnabled)
        try c.encode(doublingStyle, forKey: .doublingStyle)
        try c.encode(doublingDryWet, forKey: .doublingDryWet)
        try c.encode(doublingStereoWidth, forKey: .doublingStereoWidth)
        try c.encode(doublingVoices, forKey: .doublingVoices)
        try c.encode(breathDetectionEnabled, forKey: .breathDetectionEnabled)
        try c.encode(breathSensitivity, forKey: .breathSensitivity)
        try c.encode(breathMinDuration, forKey: .breathMinDuration)
        try c.encode(breathMaxDuration, forKey: .breathMaxDuration)
        try c.encode(breathReductionGain, forKey: .breathReductionGain)
        try c.encode(breathMode, forKey: .breathMode)
        try c.encode(bioReactiveEnabled, forKey: .bioReactiveEnabled)
        try c.encode(bioMappingPreset, forKey: .bioMappingPreset)
        try c.encode(bioSensitivity, forKey: .bioSensitivity)
    }

    // MARK: - Convenience Init

    public init(name: String, category: VoiceProfileCategory = .custom, description: String = "", author: String = "User") {
        self.id = UUID()
        self.name = name
        self.description = description
        self.category = category
        self.author = author
        self.version = "1.0"
        self.createdAt = Date()
        self.isFactory = false
    }
}

// MARK: - Voice Profile Category

public enum VoiceProfileCategory: String, Codable, Sendable, CaseIterable {
    case natural = "Natural"
    case autoTune = "Auto-Tune"
    case character = "Character"
    case meditation = "Meditation"
    case performance = "Performance"
    case voiceClone = "Voice Clone"
    case custom = "Custom"
}

// MARK: - Voice Profile Manager

/// Manages voice profiles — factory presets, custom profiles, persistence, and application to ProVocalChain.
/// Extends the existing PresetManager pattern (QuantumPresets.swift).
@MainActor
public class VoiceProfileManager: ObservableObject {

    public static let shared = VoiceProfileManager()

    @Published public var profiles: [VoiceProfile] = []
    @Published public var activeProfile: VoiceProfile?
    @Published public var recentProfileIds: [UUID] = []

    private let storageKey = "echoelmusic_voice_profiles_v1"
    private let recentKey = "echoelmusic_voice_profiles_recent"

    private init() {
        loadFactoryProfiles()
        loadCustomProfiles()
        loadRecentIds()
    }

    // MARK: - Apply Profile to ProVocalChain

    public func apply(_ profile: VoiceProfile, to chain: ProVocalChain) {
        // Pitch correction
        chain.pitchCorrectionEnabled = profile.pitchCorrectionEnabled
        chain.pitchCorrector.rootNote = profile.rootNote
        chain.pitchCorrector.scaleType = profile.scaleType
        chain.pitchCorrector.correctionSpeed = profile.correctionSpeed
        chain.pitchCorrector.correctionStrength = profile.correctionStrength
        chain.pitchCorrector.humanize = profile.humanize
        chain.pitchCorrector.flexTuneThreshold = profile.flexTuneThreshold
        chain.pitchCorrector.preserveFormants = profile.preserveFormants
        chain.pitchCorrector.formantShift = profile.formantShift
        chain.pitchCorrector.transpose = profile.transpose
        chain.pitchCorrector.referenceA4 = profile.referenceA4

        // Vibrato
        chain.vibratoEnabled = profile.vibratoEnabled

        // Harmony
        chain.harmonyEnabled = profile.harmonyEnabled

        // Doubling
        chain.doublingEnabled = profile.doublingEnabled

        // Breath detection
        chain.breathDetectionEnabled = profile.breathDetectionEnabled

        // Bio-reactive
        chain.bioReactiveEnabled = profile.bioReactiveEnabled

        // Track active + recent
        activeProfile = profile
        trackRecent(profile.id)

        log.info("🎤 VoiceProfile applied: \(profile.name)", category: .audio)
    }

    // MARK: - Snapshot from Current Chain

    public func snapshot(from chain: ProVocalChain, name: String, category: VoiceProfileCategory = .custom) -> VoiceProfile {
        var profile = VoiceProfile(name: name, category: category)

        // Capture pitch correction state
        profile.pitchCorrectionEnabled = chain.pitchCorrectionEnabled
        profile.rootNote = chain.pitchCorrector.rootNote
        profile.scaleType = chain.pitchCorrector.scaleType
        profile.correctionSpeed = chain.pitchCorrector.correctionSpeed
        profile.correctionStrength = chain.pitchCorrector.correctionStrength
        profile.humanize = chain.pitchCorrector.humanize
        profile.flexTuneThreshold = chain.pitchCorrector.flexTuneThreshold
        profile.preserveFormants = chain.pitchCorrector.preserveFormants
        profile.formantShift = chain.pitchCorrector.formantShift
        profile.transpose = chain.pitchCorrector.transpose
        profile.referenceA4 = chain.pitchCorrector.referenceA4

        // Capture module enable states
        profile.vibratoEnabled = chain.vibratoEnabled
        profile.harmonyEnabled = chain.harmonyEnabled
        profile.doublingEnabled = chain.doublingEnabled
        profile.breathDetectionEnabled = chain.breathDetectionEnabled
        profile.bioReactiveEnabled = chain.bioReactiveEnabled

        return profile
    }

    // MARK: - CRUD Operations

    public func save(_ profile: VoiceProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        persistCustomProfiles()
    }

    public func delete(_ profileId: UUID) {
        profiles.removeAll { $0.id == profileId && !$0.isFactory }
        if activeProfile?.id == profileId { activeProfile = nil }
        persistCustomProfiles()
    }

    public func duplicate(_ profile: VoiceProfile, newName: String) -> VoiceProfile {
        var copy = profile
        copy = VoiceProfile(name: newName, category: profile.category, description: profile.description)
        // Copy all settings from original
        copy.pitchCorrectionEnabled = profile.pitchCorrectionEnabled
        copy.rootNote = profile.rootNote
        copy.scaleType = profile.scaleType
        copy.correctionSpeed = profile.correctionSpeed
        copy.correctionStrength = profile.correctionStrength
        copy.humanize = profile.humanize
        copy.flexTuneThreshold = profile.flexTuneThreshold
        copy.preserveFormants = profile.preserveFormants
        copy.formantShift = profile.formantShift
        copy.transpose = profile.transpose
        copy.referenceA4 = profile.referenceA4
        copy.vibratoEnabled = profile.vibratoEnabled
        copy.vibratoRate = profile.vibratoRate
        copy.vibratoDepth = profile.vibratoDepth
        copy.vibratoShape = profile.vibratoShape
        copy.harmonyEnabled = profile.harmonyEnabled
        copy.doublingEnabled = profile.doublingEnabled
        copy.breathDetectionEnabled = profile.breathDetectionEnabled
        copy.bioReactiveEnabled = profile.bioReactiveEnabled
        copy.bioSensitivity = profile.bioSensitivity
        copy.mfccFingerprint = profile.mfccFingerprint
        save(copy)
        return copy
    }

    public func profiles(for category: VoiceProfileCategory) -> [VoiceProfile] {
        profiles.filter { $0.category == category }
    }

    // MARK: - Persistence

    private func persistCustomProfiles() {
        let custom = profiles.filter { !$0.isFactory }
        if let data = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadCustomProfiles() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let custom = try? JSONDecoder().decode([VoiceProfile].self, from: data) else { return }
        profiles.append(contentsOf: custom)
    }

    private func trackRecent(_ id: UUID) {
        recentProfileIds.removeAll { $0 == id }
        recentProfileIds.insert(id, at: 0)
        if recentProfileIds.count > 10 { recentProfileIds = Array(recentProfileIds.prefix(10)) }
        let strings = recentProfileIds.map { $0.uuidString }
        UserDefaults.standard.set(strings, forKey: recentKey)
    }

    private func loadRecentIds() {
        guard let strings = UserDefaults.standard.array(forKey: recentKey) as? [String] else { return }
        recentProfileIds = strings.compactMap { UUID(uuidString: $0) }
    }

    // MARK: - Factory Profiles

    private func loadFactoryProfiles() {
        profiles = [
            Self.makeNatural(),
            Self.makeWarmVintage(),
            Self.makeHardTune(),
            Self.makeRobot(),
            Self.makeMeditation(),
            Self.makeOperatic(),
            Self.makeGospelSoul(),
            Self.makeChoirLeader(),
            Self.makeBioReactivePerformance(),
            Self.makeWhisper(),
            Self.makeDeepVoice(),
            Self.makeBrightPop(),
        ]
    }

    private static func makeNatural() -> VoiceProfile {
        var p = VoiceProfile(name: "Natural", category: .natural, description: "Clean natural voice with subtle correction")
        p.isFactory = true
        p.correctionSpeed = 120
        p.correctionStrength = 0.4
        p.humanize = 0.6
        p.vibratoEnabled = false
        return p
    }

    private static func makeWarmVintage() -> VoiceProfile {
        var p = VoiceProfile(name: "Warm Vintage", category: .natural, description: "Warm analog-style vocal character")
        p.isFactory = true
        p.correctionSpeed = 100
        p.correctionStrength = 0.5
        p.humanize = 0.4
        p.formantShift = -1.5
        p.vibratoRate = 5.0
        p.vibratoDepth = 35
        p.vibratoShape = .human
        return p
    }

    private static func makeHardTune() -> VoiceProfile {
        var p = VoiceProfile(name: "Hard-Tune", category: .autoTune, description: "T-Pain / Cher effect — instant pitch snap")
        p.isFactory = true
        p.correctionSpeed = 0
        p.correctionStrength = 1.0
        p.humanize = 0
        p.flexTuneThreshold = 0
        p.vibratoEnabled = false
        return p
    }

    private static func makeRobot() -> VoiceProfile {
        var p = VoiceProfile(name: "Robot", category: .character, description: "Robotic vocoder-style voice")
        p.isFactory = true
        p.correctionSpeed = 0
        p.correctionStrength = 1.0
        p.humanize = 0
        p.formantShift = -8
        p.vibratoEnabled = false
        p.doublingEnabled = true
        p.doublingStyle = .tight
        return p
    }

    private static func makeMeditation() -> VoiceProfile {
        var p = VoiceProfile(name: "Meditation Guide", category: .meditation, description: "Soft, warm, bio-reactive meditation voice")
        p.isFactory = true
        p.correctionSpeed = 150
        p.correctionStrength = 0.3
        p.humanize = 0.8
        p.formantShift = -0.5
        p.vibratoRate = 4.5
        p.vibratoDepth = 20
        p.vibratoShape = .sine
        p.breathDetectionEnabled = true
        p.breathSensitivity = 0.3
        p.breathMode = .reduce
        p.breathReductionGain = 0.4
        p.bioReactiveEnabled = true
        p.bioMappingPreset = "meditation"
        p.bioSensitivity = 0.9
        return p
    }

    private static func makeOperatic() -> VoiceProfile {
        var p = VoiceProfile(name: "Operatic", category: .performance, description: "Wide operatic vibrato with rich harmonics")
        p.isFactory = true
        p.correctionSpeed = 80
        p.correctionStrength = 0.6
        p.vibratoRate = 5.0
        p.vibratoDepth = 80
        p.vibratoShape = .operatic
        p.vibratoOnsetDelay = 0.3
        p.vibratoFadeInTime = 0.5
        p.harmonyEnabled = true
        p.harmonyDryWet = 0.3
        return p
    }

    private static func makeGospelSoul() -> VoiceProfile {
        var p = VoiceProfile(name: "Gospel Soul", category: .performance, description: "Intense gospel vibrato with rich harmonics")
        p.isFactory = true
        p.correctionSpeed = 60
        p.correctionStrength = 0.7
        p.vibratoRate = 6.5
        p.vibratoDepth = 60
        p.vibratoShape = .gospel
        p.vibratoRateVariation = 0.2
        p.formantShift = 0.5
        return p
    }

    private static func makeChoirLeader() -> VoiceProfile {
        var p = VoiceProfile(name: "Choir Leader", category: .performance, description: "4-voice choir stack with wide stereo")
        p.isFactory = true
        p.correctionSpeed = 50
        p.correctionStrength = 0.8
        p.vibratoRate = 5.5
        p.vibratoDepth = 40
        p.vibratoShape = .operatic
        p.doublingEnabled = true
        p.doublingStyle = .wide
        p.harmonyEnabled = true
        p.harmonyDryWet = 0.4
        return p
    }

    private static func makeBioReactivePerformance() -> VoiceProfile {
        var p = VoiceProfile(name: "Bio-Reactive Live", category: .performance, description: "Full bio-reactive performance — voice breathes with you")
        p.isFactory = true
        p.correctionSpeed = 50
        p.correctionStrength = 0.8
        p.vibratoRate = 5.5
        p.vibratoDepth = 40
        p.bioReactiveEnabled = true
        p.bioMappingPreset = "performance"
        p.bioSensitivity = 1.0
        p.breathDetectionEnabled = true
        p.breathSensitivity = 0.5
        p.breathMode = .reduce
        p.breathReductionGain = 0.2
        return p
    }

    private static func makeWhisper() -> VoiceProfile {
        var p = VoiceProfile(name: "Whisper", category: .character, description: "Soft whisper with intimate presence")
        p.isFactory = true
        p.correctionSpeed = 200
        p.correctionStrength = 0.2
        p.humanize = 0.9
        p.formantShift = 2
        p.vibratoEnabled = false
        p.breathDetectionEnabled = false
        return p
    }

    private static func makeDeepVoice() -> VoiceProfile {
        var p = VoiceProfile(name: "Deep Voice", category: .character, description: "Deep radio announcer voice — formant shift down")
        p.isFactory = true
        p.correctionSpeed = 80
        p.correctionStrength = 0.5
        p.formantShift = -6
        p.transpose = -5
        p.vibratoRate = 4.5
        p.vibratoDepth = 25
        return p
    }

    private static func makeBrightPop() -> VoiceProfile {
        var p = VoiceProfile(name: "Bright Pop", category: .autoTune, description: "Modern pop vocal — tight correction with bright formants")
        p.isFactory = true
        p.correctionSpeed = 15
        p.correctionStrength = 0.9
        p.humanize = 0.05
        p.formantShift = 1.5
        p.vibratoRate = 6.0
        p.vibratoDepth = 30
        p.vibratoShape = .sine
        p.vibratoOnsetDelay = 0.15
        p.doublingEnabled = true
        p.doublingStyle = .tight
        return p
    }
}

// MARK: - Voice Characterizer

/// Analyzes a recorded voice sample to extract a voice fingerprint (MFCC, formants, pitch range).
/// Uses the existing AudioFeatureExtractor from EnhancedMLModels.swift — no duplicate code.
@MainActor
public class VoiceCharacterizer: ObservableObject {

    @Published public var isAnalyzing: Bool = false
    @Published public var analysisProgress: Float = 0
    @Published public var lastAnalysis: VoiceAnalysisResult?

    public struct VoiceAnalysisResult: Codable, Sendable {
        public let mfcc: [Float]
        public let fundamentalFrequency: Float
        public let spectralCentroid: Float
        public let formantFrequencies: [Float]
        public let pitchMin: Float
        public let pitchMax: Float
        public let breathiness: Float
        public let brightness: Float
        public let duration: Float
    }

    private let pitchDetector = PitchDetector()
    private let fftSize = 4096
    private let hopSize = 1024

    /// Analyze a voice recording and create a characterization
    public func analyze(audioURL: URL) async throws -> VoiceAnalysisResult {
        isAnalyzing = true
        analysisProgress = 0
        defer { isAnalyzing = false }

        // Load audio file
        let audioFile = try AVAudioFile(forReading: audioURL)
        let format = audioFile.processingFormat
        let sampleRate = Float(format.sampleRate)
        let frameCount = AVAudioFrameCount(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw VoiceAnalysisError.invalidFormat
        }
        try audioFile.read(into: buffer)
        guard let channelData = buffer.floatChannelData?[0] else {
            throw VoiceAnalysisError.noAudioData
        }
        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))

        analysisProgress = 0.1

        // 1. MFCC extraction (reuses AudioFeatureExtractor pattern)
        let mfcc = calculateMFCC(samples: samples, sampleRate: sampleRate, numCoefficients: 13)
        analysisProgress = 0.3

        // 2. Pitch detection across entire sample
        var pitches: [Float] = []
        let windowSize = fftSize
        var offset = 0
        while offset + windowSize < samples.count {
            let window = Array(samples[offset..<(offset + windowSize)])
            let pitch = pitchDetector.detectPitch(samples: window, sampleRate: sampleRate)
            if pitch > 0 { pitches.append(pitch) }
            offset += hopSize
        }
        analysisProgress = 0.6

        let fundamentalFrequency = pitches.isEmpty ? 0 : pitches.reduce(0, +) / Float(pitches.count)
        let pitchMin = pitches.min() ?? 0
        let pitchMax = pitches.max() ?? 0

        // 3. Spectral centroid (brightness)
        let spectralCentroid = calculateSpectralCentroid(samples: samples, sampleRate: sampleRate)
        analysisProgress = 0.7

        // 4. Formant estimation (from spectral envelope peaks)
        let formants = estimateFormants(samples: samples, sampleRate: sampleRate)
        analysisProgress = 0.85

        // 5. Breathiness (noise-to-harmonic ratio via zero-crossing rate)
        let zcr = calculateZeroCrossingRate(samples: samples)
        let breathiness = min(1.0, zcr / 0.15)
        let brightness = min(1.0, spectralCentroid / 4000.0)

        analysisProgress = 1.0

        let result = VoiceAnalysisResult(
            mfcc: mfcc,
            fundamentalFrequency: fundamentalFrequency,
            spectralCentroid: spectralCentroid,
            formantFrequencies: formants,
            pitchMin: pitchMin,
            pitchMax: pitchMax,
            breathiness: breathiness,
            brightness: brightness,
            duration: Float(samples.count) / sampleRate
        )
        lastAnalysis = result
        return result
    }

    /// Create a VoiceProfile from analysis results
    public func createProfile(from result: VoiceAnalysisResult, name: String) -> VoiceProfile {
        var profile = VoiceProfile(name: name, category: .voiceClone, description: "Voice profile from recording analysis")
        profile.mfccFingerprint = result.mfcc
        profile.fundamentalFrequency = result.fundamentalFrequency
        profile.spectralCentroid = result.spectralCentroid
        profile.formantFrequencies = result.formantFrequencies
        profile.pitchRange = (result.pitchMin, result.pitchMax)

        // Auto-configure processing based on voice characteristics
        if result.fundamentalFrequency < 165 {
            // Low voice (bass/baritone) — less aggressive correction
            profile.correctionSpeed = 100
            profile.correctionStrength = 0.5
            profile.vibratoRate = 5.0
        } else if result.fundamentalFrequency > 330 {
            // High voice (soprano) — faster, lighter correction
            profile.correctionSpeed = 40
            profile.correctionStrength = 0.7
            profile.vibratoRate = 6.0
        }

        if result.breathiness > 0.5 {
            // Breathy voice — gentle breath handling
            profile.breathDetectionEnabled = true
            profile.breathSensitivity = 0.3
            profile.breathMode = .reduce
            profile.breathReductionGain = 0.5
        }

        return profile
    }

    // MARK: - DSP Helpers (using Accelerate — zero external deps)

    private func calculateMFCC(samples: [Float], sampleRate: Float, numCoefficients: Int) -> [Float] {
        let frameSize = 2048
        let numFilters = 26
        guard samples.count >= frameSize else { return Array(repeating: 0, count: numCoefficients) }

        // Window + FFT
        var windowed = [Float](repeating: 0, count: frameSize)
        var window = [Float](repeating: 0, count: frameSize)
        vDSP_hamm_window(&window, vDSP_Length(frameSize), 0)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(frameSize))

        // Magnitude spectrum via real FFT
        let halfN = frameSize / 2
        let log2N = vDSP_Length(log2(Float(frameSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2N, FFTRadix(kFFTRadix2)) else {
            return Array(repeating: 0, count: numCoefficients)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var realPart = [Float](repeating: 0, count: halfN)
        var imagPart = [Float](repeating: 0, count: halfN)
        windowed.withUnsafeBufferPointer { inPtr in
            realPart.withUnsafeMutableBufferPointer { rPtr in
                imagPart.withUnsafeMutableBufferPointer { iPtr in
                    guard let rBase = rPtr.baseAddress,
                          let iBase = iPtr.baseAddress,
                          let inBase = inPtr.baseAddress else { return }
                    var splitComplex = DSPSplitComplex(realp: rBase, imagp: iBase)
                    inBase.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(halfN))
                    }
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2N, FFTDirection(FFT_FORWARD))
                }
            }
        }

        // Magnitude
        var magnitudes = [Float](repeating: 0, count: halfN)
        realPart.withUnsafeBufferPointer { rPtr in
            imagPart.withUnsafeBufferPointer { iPtr in
                guard let rBase = rPtr.baseAddress,
                      let iBase = iPtr.baseAddress else { return }
                var split = DSPSplitComplex(realp: UnsafeMutablePointer(mutating: rBase),
                                           imagp: UnsafeMutablePointer(mutating: iBase))
                vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(halfN))
            }
        }

        // Mel filterbank
        let maxMel = 2595.0 * log10(1.0 + Double(sampleRate / 2) / 700.0)
        var melEnergies = [Float](repeating: 0, count: numFilters)
        for i in 0..<numFilters {
            let melLow = maxMel * Double(i) / Double(numFilters + 1)
            let melHigh = maxMel * Double(i + 2) / Double(numFilters + 1)
            let fLow = Int(700.0 * (pow(10.0, melLow / 2595.0) - 1.0) / Double(sampleRate) * Double(frameSize))
            let fHigh = Int(700.0 * (pow(10.0, melHigh / 2595.0) - 1.0) / Double(sampleRate) * Double(frameSize))
            let low = max(0, min(fLow, halfN - 1))
            let high = max(low + 1, min(fHigh, halfN))
            var sum: Float = 0
            for j in low..<high { sum += magnitudes[j] }
            melEnergies[i] = Foundation.log(max(sum, 1e-10))
        }

        // DCT for cepstral coefficients
        var mfcc = [Float](repeating: 0, count: numCoefficients)
        for k in 0..<numCoefficients {
            var sum: Float = 0
            for n in 0..<numFilters {
                sum += melEnergies[n] * cos(Float.pi * Float(k) * (Float(n) + 0.5) / Float(numFilters))
            }
            mfcc[k] = sum
        }
        return mfcc
    }

    private func calculateSpectralCentroid(samples: [Float], sampleRate: Float) -> Float {
        let frameSize = min(4096, samples.count)
        guard frameSize > 0 else { return 0 }

        var magnitudes = [Float](repeating: 0, count: frameSize / 2)
        var weightedSum: Float = 0
        var totalMagnitude: Float = 0

        // Simple magnitude estimation via DFT bin energies
        for k in 0..<(frameSize / 2) {
            var re: Float = 0, im: Float = 0
            for n in 0..<frameSize {
                let angle = 2.0 * Float.pi * Float(k) * Float(n) / Float(frameSize)
                re += samples[n] * cos(angle)
                im += samples[n] * sin(angle)
            }
            magnitudes[k] = sqrt(re * re + im * im)
            let freq = Float(k) * sampleRate / Float(frameSize)
            weightedSum += freq * magnitudes[k]
            totalMagnitude += magnitudes[k]
        }

        return totalMagnitude > 0 ? weightedSum / totalMagnitude : 0
    }

    private func estimateFormants(samples: [Float], sampleRate: Float) -> [Float] {
        // Simple formant estimation via spectral peak picking
        // Returns [F1, F2, F3] approximate formant frequencies
        let frameSize = min(4096, samples.count)
        guard frameSize > 256 else { return [500, 1500, 2500] }

        var magnitudes = [Float](repeating: 0, count: frameSize / 2)
        for k in 0..<(frameSize / 2) {
            var re: Float = 0, im: Float = 0
            let step = max(1, frameSize / 512)  // Subsample for speed
            for n in stride(from: 0, to: frameSize, by: step) {
                let angle = 2.0 * Float.pi * Float(k) * Float(n) / Float(frameSize)
                re += samples[n] * cos(angle)
                im += samples[n] * sin(angle)
            }
            magnitudes[k] = sqrt(re * re + im * im)
        }

        // Smooth spectrum to find formant peaks
        let smoothed = smoothArray(magnitudes, windowSize: 15)

        // Find peaks in voice formant ranges
        var peaks: [(freq: Float, mag: Float)] = []
        for i in 2..<(smoothed.count - 2) {
            let freq = Float(i) * sampleRate / Float(frameSize)
            guard freq > 200 && freq < 5000 else { continue }
            if smoothed[i] > smoothed[i-1] && smoothed[i] > smoothed[i+1] &&
               smoothed[i] > smoothed[i-2] && smoothed[i] > smoothed[i+2] {
                peaks.append((freq, smoothed[i]))
            }
        }

        peaks.sort { $0.mag > $1.mag }
        var formants: [Float] = []
        for peak in peaks.prefix(5) {
            // Ensure formants are spaced at least 200 Hz apart
            if formants.allSatisfy({ abs($0 - peak.freq) > 200 }) {
                formants.append(peak.freq)
            }
            if formants.count >= 3 { break }
        }
        formants.sort()

        while formants.count < 3 { formants.append(formants.last.map { $0 + 1000 } ?? 500) }
        return Array(formants.prefix(3))
    }

    private func calculateZeroCrossingRate(samples: [Float]) -> Float {
        guard samples.count > 1 else { return 0 }
        var crossings: Int = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0) != (samples[i-1] >= 0) { crossings += 1 }
        }
        return Float(crossings) / Float(samples.count)
    }

    private func smoothArray(_ input: [Float], windowSize: Int) -> [Float] {
        guard input.count > windowSize else { return input }
        var output = [Float](repeating: 0, count: input.count)
        let half = windowSize / 2
        for i in 0..<input.count {
            let lo = max(0, i - half)
            let hi = min(input.count, i + half + 1)
            var sum: Float = 0
            for j in lo..<hi { sum += input[j] }
            output[i] = sum / Float(hi - lo)
        }
        return output
    }
}

public enum VoiceAnalysisError: LocalizedError {
    case invalidFormat
    case noAudioData
    case tooShort

    public var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Invalid audio format"
        case .noAudioData: return "No audio data found"
        case .tooShort: return "Recording too short for analysis (minimum 2 seconds)"
        }
    }
}

// MARK: - Voice Synthesis Engine

/// Bridges voice characterization, ProVocalChain processing, and Apple Personal Voice API.
/// Provides real-time voice transformation based on VoiceProfile targets.
@MainActor
public class VoiceSynthesisEngine: ObservableObject {

    public static let shared = VoiceSynthesisEngine()

    @Published public var isRecording: Bool = false
    @Published public var isTraining: Bool = false
    @Published public var isSynthesizing: Bool = false
    @Published public var trainingProgress: Float = 0
    @Published public var availableVoiceModels: [String] = ["Natural", "Robot", "Clone 1", "Clone 2"]

    private let characterizer = VoiceCharacterizer()
    private let profileManager = VoiceProfileManager.shared
    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Forward characterizer state
        characterizer.$isAnalyzing
            .receive(on: RunLoop.main)
            .sink { [weak self] val in self?.isTraining = val }
            .store(in: &cancellables)
        characterizer.$analysisProgress
            .receive(on: RunLoop.main)
            .sink { [weak self] val in self?.trainingProgress = val }
            .store(in: &cancellables)
    }

    // MARK: - Recording

    /// Start recording a voice sample for profile creation
    public func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice_sample_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        recordingURL = url
        isRecording = true

        log.info("🎤 Voice sample recording started", category: .audio)
    }

    /// Stop recording and return the audio URL
    public func stopRecording() -> URL? {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false

        log.info("🎤 Voice sample recording stopped", category: .audio)
        return recordingURL
    }

    // MARK: - Training (Voice Analysis)

    /// Analyze a recorded voice sample and create a voice profile
    public func trainVoiceModel(from audioURL: URL, profileName: String) async throws -> VoiceProfile {
        let result = try await characterizer.analyze(audioURL: audioURL)
        var profile = characterizer.createProfile(from: result, name: profileName)

        // Save to profile manager
        profileManager.save(profile)

        // Update available models
        updateAvailableModels()

        log.info("🎤 Voice model trained: \(profileName) (F0=\(Int(result.fundamentalFrequency))Hz)", category: .audio)
        return profile
    }

    /// Record + analyze in one step
    public func recordAndTrain(profileName: String, duration: TimeInterval = 10) async throws -> VoiceProfile {
        try startRecording()

        // Wait for specified duration
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        guard let url = stopRecording() else {
            throw VoiceAnalysisError.noAudioData
        }

        return try await trainVoiceModel(from: url, profileName: profileName)
    }

    // MARK: - Synthesis (Apply Profile)

    /// Apply a voice profile to the vocal chain for real-time processing
    public func synthesize(profile: VoiceProfile, chain: ProVocalChain) {
        isSynthesizing = true
        profileManager.apply(profile, to: chain)
        log.info("🎤 Voice synthesis active: \(profile.name)", category: .audio)
    }

    /// Stop synthesis (revert to default)
    public func stopSynthesis(chain: ProVocalChain) {
        isSynthesizing = false
        // Apply default profile
        if let natural = profileManager.profiles.first(where: { $0.name == "Natural" }) {
            profileManager.apply(natural, to: chain)
        }
    }

    // MARK: - Apple Personal Voice Integration (iOS 17+)

    #if canImport(AVFoundation)
    /// Check if Apple Personal Voice is available
    @available(iOS 17.0, macOS 14.0, *)
    public var isPersonalVoiceAvailable: Bool {
        AVSpeechSynthesizer.personalVoiceAuthorizationStatus == .authorized
    }

    /// Request Personal Voice authorization
    @available(iOS 17.0, macOS 14.0, *)
    public func requestPersonalVoiceAccess() async -> Bool {
        let status = await AVSpeechSynthesizer.requestPersonalVoiceAuthorization()
        let granted = status == .authorized
        if granted {
            log.info("🎤 Personal Voice access granted", category: .audio)
        }
        return granted
    }

    /// Synthesize speech using Apple Personal Voice
    @available(iOS 17.0, macOS 14.0, *)
    public func speakWithPersonalVoice(text: String) {
        let synthesizer = AVSpeechSynthesizer()
        let utterance = AVSpeechUtterance(string: text)

        // Find personal voice
        let voices = AVSpeechSynthesisVoice.speechVoices()
        if let personalVoice = voices.first(where: { $0.voiceTraits.contains(.isPersonalVoice) }) {
            utterance.voice = personalVoice
        }

        synthesizer.speak(utterance)
        log.info("🎤 Speaking with Personal Voice: \"\(text.prefix(50))...\"", category: .audio)
    }
    #endif

    // MARK: - Helpers

    private func updateAvailableModels() {
        var models = ["Natural", "Robot"]
        let cloneProfiles = profileManager.profiles(for: .voiceClone)
        for (i, profile) in cloneProfiles.prefix(8).enumerated() {
            models.append(profile.name)
        }
        availableVoiceModels = models
    }
}
