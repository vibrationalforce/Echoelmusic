import Foundation
import SwiftUI

/// Bio-Mapping Presets System
/// 10 scientifically-calibrated presets for different biofeedback states
/// Each preset configures how biometric data maps to audio parameters

// MARK: - Preset Definition

/// All available bio-mapping presets with their configurations
enum BioMappingPreset: String, CaseIterable, Identifiable, Codable {
    case creative = "Creative Flow"
    case meditation = "Deep Meditation"
    case focus = "Focus Mode"
    case healing = "Healing Resonance"
    case energize = "Energize"
    case relaxation = "Relaxation"
    case sleep = "Sleep Preparation"
    case breathwork = "Breathwork"
    case performance = "Peak Performance"
    case grounding = "Grounding"

    var id: String { rawValue }

    // MARK: - Visual Properties

    /// Icon for the preset (SF Symbols)
    var icon: String {
        switch self {
        case .creative: return "paintbrush.fill"
        case .meditation: return "sparkles"
        case .focus: return "target"
        case .healing: return "heart.fill"
        case .energize: return "bolt.fill"
        case .relaxation: return "leaf.fill"
        case .sleep: return "moon.fill"
        case .breathwork: return "wind"
        case .performance: return "flame.fill"
        case .grounding: return "tree.fill"
        }
    }

    /// Primary color for the preset
    var color: Color {
        switch self {
        case .creative: return .purple
        case .meditation: return .indigo
        case .focus: return .orange
        case .healing: return .pink
        case .energize: return .yellow
        case .relaxation: return .mint
        case .sleep: return .blue
        case .breathwork: return .cyan
        case .performance: return .red
        case .grounding: return .brown
        }
    }

    /// Secondary gradient color
    var gradientColor: Color {
        switch self {
        case .creative: return .pink
        case .meditation: return .purple
        case .focus: return .red
        case .healing: return .red
        case .energize: return .orange
        case .relaxation: return .green
        case .sleep: return .indigo
        case .breathwork: return .blue
        case .grounding: return .green
        }
    }

    /// Description of the preset's purpose
    var description: String {
        switch self {
        case .creative:
            return "Optimized for artistic expression. HRV variations enhance harmonic richness while coherence drives spatial movement."
        case .meditation:
            return "Deep, immersive soundscapes. High coherence creates expansive reverb, low heart rate enables warm, slow frequencies."
        case .focus:
            return "Minimal distraction, maximum clarity. Bright frequencies, reduced reverb, steady spatial positioning."
        case .healing:
            return "Based on Solfeggio frequencies. Heart-centered mapping for emotional release and cellular regeneration."
        case .energize:
            return "Uplifting, dynamic audio. High heart rate drives bright tones, HRV variations create rhythmic pulses."
        case .relaxation:
            return "Gentle, soothing soundscape. Low-pass filtering, generous reverb, stable centered positioning."
        case .sleep:
            return "Ultra-calm delta wave induction. Very low frequencies, maximum reverb, slow breathing tempo."
        case .breathwork:
            return "Synchronized with breath cycle. Tempo directly mapped to breathing rate, spatial audio follows inhale/exhale."
        case .performance:
            return "High-energy peak state. Fast response times, dynamic range, competitive edge audio."
        case .grounding:
            return "Earth-connected stability. Root chakra frequencies, steady bass, centered positioning."
        }
    }

    /// Recommended use cases
    var useCases: [String] {
        switch self {
        case .creative:
            return ["Music composition", "Art creation", "Writing", "Brainstorming"]
        case .meditation:
            return ["Morning meditation", "Evening wind-down", "Mindfulness", "Contemplation"]
        case .focus:
            return ["Work sessions", "Study", "Reading", "Deep work"]
        case .healing:
            return ["Emotional processing", "Recovery", "Self-care", "Therapy support"]
        case .energize:
            return ["Morning activation", "Pre-workout", "Energy boost", "Motivation"]
        case .relaxation:
            return ["Stress relief", "Evening relaxation", "Anxiety reduction", "Calm"]
        case .sleep:
            return ["Pre-sleep", "Insomnia support", "Nap preparation", "Rest"]
        case .breathwork:
            return ["Pranayama", "Box breathing", "Wim Hof method", "Coherent breathing"]
        case .performance:
            return ["Sports", "Competition", "Public speaking", "Presentations"]
        case .grounding:
            return ["Anxiety relief", "Overwhelm", "Dissociation recovery", "Stability"]
        }
    }

    // MARK: - Audio Parameters

    /// Get the mapping configuration for this preset
    var mapping: BioMappingConfiguration {
        switch self {
        case .creative:
            return BioMappingConfiguration(
                // HRV → Reverb: More variation = more reverb
                hrvToReverbRange: (min: 0.3, max: 0.8),
                hrvToReverbCurve: .exponential(factor: 1.5),

                // HR → Filter: Higher HR = brighter
                hrToFilterRange: (min: 800.0, max: 3000.0),
                hrToFilterCurve: .linear,

                // Coherence → Amplitude: More coherence = more volume
                coherenceToAmplitudeRange: (min: 0.4, max: 0.8),
                coherenceToAmplitudeCurve: .logarithmic,

                // Base frequency (A4 healing)
                baseFrequency: 432.0,

                // Tempo from HR
                hrToTempoMultiplier: 0.25, // HR/4
                tempoRange: (min: 5.0, max: 10.0),

                // Spatial mapping
                coherenceToSpatialStability: 0.6, // Medium stability
                spatialMovementIntensity: 0.4,

                // Harmonic settings
                harmonicEnrichmentFactor: 1.5,

                // Smoothing (medium - responsive but smooth)
                kalmanProcessNoise: 0.01,
                kalmanMeasurementNoise: 0.1,

                // Response speed
                parameterSmoothingFactor: 0.8
            )

        case .meditation:
            return BioMappingConfiguration(
                hrvToReverbRange: (min: 0.6, max: 0.95),
                hrvToReverbCurve: .logarithmic,

                hrToFilterRange: (min: 200.0, max: 800.0),
                hrToFilterCurve: .exponential(factor: 0.5),

                coherenceToAmplitudeRange: (min: 0.3, max: 0.6),
                coherenceToAmplitudeCurve: .linear,

                baseFrequency: 432.0, // Om frequency

                hrToTempoMultiplier: 0.2,
                tempoRange: (min: 4.0, max: 6.0),

                coherenceToSpatialStability: 0.9,
                spatialMovementIntensity: 0.1,

                harmonicEnrichmentFactor: 1.2,

                kalmanProcessNoise: 0.005,
                kalmanMeasurementNoise: 0.2,

                parameterSmoothingFactor: 0.95
            )

        case .focus:
            return BioMappingConfiguration(
                hrvToReverbRange: (min: 0.1, max: 0.3),
                hrvToReverbCurve: .linear,

                hrToFilterRange: (min: 1500.0, max: 4000.0),
                hrToFilterCurve: .linear,

                coherenceToAmplitudeRange: (min: 0.5, max: 0.7),
                coherenceToAmplitudeCurve: .linear,

                baseFrequency: 528.0, // DNA repair / Transformation

                hrToTempoMultiplier: 0.15,
                tempoRange: (min: 6.0, max: 8.0),

                coherenceToSpatialStability: 1.0,
                spatialMovementIntensity: 0.0,

                harmonicEnrichmentFactor: 0.8,

                kalmanProcessNoise: 0.02,
                kalmanMeasurementNoise: 0.05,

                parameterSmoothingFactor: 0.7
            )

        case .healing:
            return BioMappingConfiguration(
                hrvToReverbRange: (min: 0.5, max: 0.85),
                hrvToReverbCurve: .exponential(factor: 1.2),

                hrToFilterRange: (min: 300.0, max: 1200.0),
                hrToFilterCurve: .logarithmic,

                coherenceToAmplitudeRange: (min: 0.4, max: 0.7),
                coherenceToAmplitudeCurve: .exponential(factor: 1.3),

                baseFrequency: 396.0, // Liberation from fear

                hrToTempoMultiplier: 0.22,
                tempoRange: (min: 4.0, max: 7.0),

                coherenceToSpatialStability: 0.8,
                spatialMovementIntensity: 0.15,

                harmonicEnrichmentFactor: 1.3,

                kalmanProcessNoise: 0.008,
                kalmanMeasurementNoise: 0.15,

                parameterSmoothingFactor: 0.9
            )

        case .energize:
            return BioMappingConfiguration(
                hrvToReverbRange: (min: 0.1, max: 0.4),
                hrvToReverbCurve: .linear,

                hrToFilterRange: (min: 2000.0, max: 6000.0),
                hrToFilterCurve: .exponential(factor: 1.5),

                coherenceToAmplitudeRange: (min: 0.6, max: 0.9),
                coherenceToAmplitudeCurve: .linear,

                baseFrequency: 741.0, // Awakening intuition

                hrToTempoMultiplier: 0.3,
                tempoRange: (min: 8.0, max: 12.0),

                coherenceToSpatialStability: 0.5,
                spatialMovementIntensity: 0.5,

                harmonicEnrichmentFactor: 1.8,

                kalmanProcessNoise: 0.03,
                kalmanMeasurementNoise: 0.03,

                parameterSmoothingFactor: 0.6
            )

        case .relaxation:
            return BioMappingConfiguration(
                hrvToReverbRange: (min: 0.5, max: 0.9),
                hrvToReverbCurve: .logarithmic,

                hrToFilterRange: (min: 150.0, max: 600.0),
                hrToFilterCurve: .logarithmic,

                coherenceToAmplitudeRange: (min: 0.25, max: 0.5),
                coherenceToAmplitudeCurve: .linear,

                baseFrequency: 417.0, // Facilitating change

                hrToTempoMultiplier: 0.18,
                tempoRange: (min: 4.0, max: 6.0),

                coherenceToSpatialStability: 0.95,
                spatialMovementIntensity: 0.05,

                harmonicEnrichmentFactor: 1.0,

                kalmanProcessNoise: 0.005,
                kalmanMeasurementNoise: 0.2,

                parameterSmoothingFactor: 0.93
            )

        case .sleep:
            return BioMappingConfiguration(
                hrvToReverbRange: (min: 0.7, max: 0.98),
                hrvToReverbCurve: .logarithmic,

                hrToFilterRange: (min: 80.0, max: 300.0),
                hrToFilterCurve: .exponential(factor: 0.3),

                coherenceToAmplitudeRange: (min: 0.15, max: 0.35),
                coherenceToAmplitudeCurve: .logarithmic,

                baseFrequency: 174.0, // Foundation frequency

                hrToTempoMultiplier: 0.12,
                tempoRange: (min: 3.0, max: 5.0),

                coherenceToSpatialStability: 1.0,
                spatialMovementIntensity: 0.0,

                harmonicEnrichmentFactor: 0.6,

                kalmanProcessNoise: 0.002,
                kalmanMeasurementNoise: 0.3,

                parameterSmoothingFactor: 0.98
            )

        case .breathwork:
            return BioMappingConfiguration(
                hrvToReverbRange: (min: 0.3, max: 0.7),
                hrvToReverbCurve: .linear,

                hrToFilterRange: (min: 400.0, max: 1500.0),
                hrToFilterCurve: .linear,

                coherenceToAmplitudeRange: (min: 0.4, max: 0.8),
                coherenceToAmplitudeCurve: .linear,

                baseFrequency: 639.0, // Connection / Relationships

                hrToTempoMultiplier: 0.25,
                tempoRange: (min: 4.0, max: 8.0),

                coherenceToSpatialStability: 0.7,
                spatialMovementIntensity: 0.3,

                harmonicEnrichmentFactor: 1.2,

                kalmanProcessNoise: 0.015,
                kalmanMeasurementNoise: 0.08,

                parameterSmoothingFactor: 0.75
            )

        case .performance:
            return BioMappingConfiguration(
                hrvToReverbRange: (min: 0.05, max: 0.25),
                hrvToReverbCurve: .linear,

                hrToFilterRange: (min: 3000.0, max: 8000.0),
                hrToFilterCurve: .exponential(factor: 2.0),

                coherenceToAmplitudeRange: (min: 0.7, max: 1.0),
                coherenceToAmplitudeCurve: .exponential(factor: 1.5),

                baseFrequency: 852.0, // Returning to spiritual order

                hrToTempoMultiplier: 0.35,
                tempoRange: (min: 10.0, max: 15.0),

                coherenceToSpatialStability: 0.4,
                spatialMovementIntensity: 0.6,

                harmonicEnrichmentFactor: 2.0,

                kalmanProcessNoise: 0.05,
                kalmanMeasurementNoise: 0.02,

                parameterSmoothingFactor: 0.5
            )

        case .grounding:
            return BioMappingConfiguration(
                hrvToReverbRange: (min: 0.3, max: 0.6),
                hrvToReverbCurve: .linear,

                hrToFilterRange: (min: 100.0, max: 500.0),
                hrToFilterCurve: .logarithmic,

                coherenceToAmplitudeRange: (min: 0.35, max: 0.55),
                coherenceToAmplitudeCurve: .linear,

                baseFrequency: 256.0, // Root chakra (C4)

                hrToTempoMultiplier: 0.2,
                tempoRange: (min: 5.0, max: 7.0),

                coherenceToSpatialStability: 1.0,
                spatialMovementIntensity: 0.0,

                harmonicEnrichmentFactor: 0.7,

                kalmanProcessNoise: 0.008,
                kalmanMeasurementNoise: 0.12,

                parameterSmoothingFactor: 0.88
            )
        }
    }
}


// MARK: - Mapping Curve Types

/// Different curve types for parameter mapping
enum MappingCurve: Codable, Equatable {
    case linear
    case logarithmic
    case exponential(factor: Double)

    /// Apply the curve transformation to a normalized value (0-1)
    func apply(_ normalizedValue: Double) -> Double {
        switch self {
        case .linear:
            return normalizedValue

        case .logarithmic:
            // log curve: more sensitive at lower values
            return log10(1.0 + normalizedValue * 9.0) / log10(10.0)

        case .exponential(let factor):
            // exponential curve: pow(x, factor)
            return pow(normalizedValue, factor)
        }
    }
}


// MARK: - Mapping Configuration

/// Complete configuration for bio-parameter mapping
struct BioMappingConfiguration: Codable, Equatable {
    // HRV → Reverb
    let hrvToReverbRange: (min: Float, max: Float)
    let hrvToReverbCurve: MappingCurve

    // Heart Rate → Filter Cutoff
    let hrToFilterRange: (min: Float, max: Float)
    let hrToFilterCurve: MappingCurve

    // Coherence → Amplitude
    let coherenceToAmplitudeRange: (min: Float, max: Float)
    let coherenceToAmplitudeCurve: MappingCurve

    // Base frequency for synthesis
    let baseFrequency: Float

    // Tempo mapping
    let hrToTempoMultiplier: Float
    let tempoRange: (min: Float, max: Float)

    // Spatial audio
    let coherenceToSpatialStability: Float // 0-1: how centered the sound is
    let spatialMovementIntensity: Float    // 0-1: how much the sound moves

    // Harmonic richness
    let harmonicEnrichmentFactor: Float // multiplier for harmonic count

    // Kalman filter parameters
    let kalmanProcessNoise: Double      // Q: process noise covariance
    let kalmanMeasurementNoise: Double  // R: measurement noise covariance

    // Parameter smoothing
    let parameterSmoothingFactor: Float // 0-1: higher = smoother/slower response

    // Codable conformance for tuple types
    enum CodingKeys: String, CodingKey {
        case hrvToReverbRangeMin, hrvToReverbRangeMax
        case hrvToReverbCurve
        case hrToFilterRangeMin, hrToFilterRangeMax
        case hrToFilterCurve
        case coherenceToAmplitudeRangeMin, coherenceToAmplitudeRangeMax
        case coherenceToAmplitudeCurve
        case baseFrequency
        case hrToTempoMultiplier
        case tempoRangeMin, tempoRangeMax
        case coherenceToSpatialStability
        case spatialMovementIntensity
        case harmonicEnrichmentFactor
        case kalmanProcessNoise
        case kalmanMeasurementNoise
        case parameterSmoothingFactor
    }

    init(hrvToReverbRange: (min: Float, max: Float),
         hrvToReverbCurve: MappingCurve,
         hrToFilterRange: (min: Float, max: Float),
         hrToFilterCurve: MappingCurve,
         coherenceToAmplitudeRange: (min: Float, max: Float),
         coherenceToAmplitudeCurve: MappingCurve,
         baseFrequency: Float,
         hrToTempoMultiplier: Float,
         tempoRange: (min: Float, max: Float),
         coherenceToSpatialStability: Float,
         spatialMovementIntensity: Float,
         harmonicEnrichmentFactor: Float,
         kalmanProcessNoise: Double,
         kalmanMeasurementNoise: Double,
         parameterSmoothingFactor: Float) {
        self.hrvToReverbRange = hrvToReverbRange
        self.hrvToReverbCurve = hrvToReverbCurve
        self.hrToFilterRange = hrToFilterRange
        self.hrToFilterCurve = hrToFilterCurve
        self.coherenceToAmplitudeRange = coherenceToAmplitudeRange
        self.coherenceToAmplitudeCurve = coherenceToAmplitudeCurve
        self.baseFrequency = baseFrequency
        self.hrToTempoMultiplier = hrToTempoMultiplier
        self.tempoRange = tempoRange
        self.coherenceToSpatialStability = coherenceToSpatialStability
        self.spatialMovementIntensity = spatialMovementIntensity
        self.harmonicEnrichmentFactor = harmonicEnrichmentFactor
        self.kalmanProcessNoise = kalmanProcessNoise
        self.kalmanMeasurementNoise = kalmanMeasurementNoise
        self.parameterSmoothingFactor = parameterSmoothingFactor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let reverbMin = try container.decode(Float.self, forKey: .hrvToReverbRangeMin)
        let reverbMax = try container.decode(Float.self, forKey: .hrvToReverbRangeMax)
        hrvToReverbRange = (min: reverbMin, max: reverbMax)
        hrvToReverbCurve = try container.decode(MappingCurve.self, forKey: .hrvToReverbCurve)

        let filterMin = try container.decode(Float.self, forKey: .hrToFilterRangeMin)
        let filterMax = try container.decode(Float.self, forKey: .hrToFilterRangeMax)
        hrToFilterRange = (min: filterMin, max: filterMax)
        hrToFilterCurve = try container.decode(MappingCurve.self, forKey: .hrToFilterCurve)

        let ampMin = try container.decode(Float.self, forKey: .coherenceToAmplitudeRangeMin)
        let ampMax = try container.decode(Float.self, forKey: .coherenceToAmplitudeRangeMax)
        coherenceToAmplitudeRange = (min: ampMin, max: ampMax)
        coherenceToAmplitudeCurve = try container.decode(MappingCurve.self, forKey: .coherenceToAmplitudeCurve)

        baseFrequency = try container.decode(Float.self, forKey: .baseFrequency)
        hrToTempoMultiplier = try container.decode(Float.self, forKey: .hrToTempoMultiplier)

        let tempoMin = try container.decode(Float.self, forKey: .tempoRangeMin)
        let tempoMax = try container.decode(Float.self, forKey: .tempoRangeMax)
        tempoRange = (min: tempoMin, max: tempoMax)

        coherenceToSpatialStability = try container.decode(Float.self, forKey: .coherenceToSpatialStability)
        spatialMovementIntensity = try container.decode(Float.self, forKey: .spatialMovementIntensity)
        harmonicEnrichmentFactor = try container.decode(Float.self, forKey: .harmonicEnrichmentFactor)
        kalmanProcessNoise = try container.decode(Double.self, forKey: .kalmanProcessNoise)
        kalmanMeasurementNoise = try container.decode(Double.self, forKey: .kalmanMeasurementNoise)
        parameterSmoothingFactor = try container.decode(Float.self, forKey: .parameterSmoothingFactor)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(hrvToReverbRange.min, forKey: .hrvToReverbRangeMin)
        try container.encode(hrvToReverbRange.max, forKey: .hrvToReverbRangeMax)
        try container.encode(hrvToReverbCurve, forKey: .hrvToReverbCurve)

        try container.encode(hrToFilterRange.min, forKey: .hrToFilterRangeMin)
        try container.encode(hrToFilterRange.max, forKey: .hrToFilterRangeMax)
        try container.encode(hrToFilterCurve, forKey: .hrToFilterCurve)

        try container.encode(coherenceToAmplitudeRange.min, forKey: .coherenceToAmplitudeRangeMin)
        try container.encode(coherenceToAmplitudeRange.max, forKey: .coherenceToAmplitudeRangeMax)
        try container.encode(coherenceToAmplitudeCurve, forKey: .coherenceToAmplitudeCurve)

        try container.encode(baseFrequency, forKey: .baseFrequency)
        try container.encode(hrToTempoMultiplier, forKey: .hrToTempoMultiplier)

        try container.encode(tempoRange.min, forKey: .tempoRangeMin)
        try container.encode(tempoRange.max, forKey: .tempoRangeMax)

        try container.encode(coherenceToSpatialStability, forKey: .coherenceToSpatialStability)
        try container.encode(spatialMovementIntensity, forKey: .spatialMovementIntensity)
        try container.encode(harmonicEnrichmentFactor, forKey: .harmonicEnrichmentFactor)
        try container.encode(kalmanProcessNoise, forKey: .kalmanProcessNoise)
        try container.encode(kalmanMeasurementNoise, forKey: .kalmanMeasurementNoise)
        try container.encode(parameterSmoothingFactor, forKey: .parameterSmoothingFactor)
    }

    static func == (lhs: BioMappingConfiguration, rhs: BioMappingConfiguration) -> Bool {
        lhs.hrvToReverbRange == rhs.hrvToReverbRange &&
        lhs.hrvToReverbCurve == rhs.hrvToReverbCurve &&
        lhs.hrToFilterRange == rhs.hrToFilterRange &&
        lhs.hrToFilterCurve == rhs.hrToFilterCurve &&
        lhs.coherenceToAmplitudeRange == rhs.coherenceToAmplitudeRange &&
        lhs.coherenceToAmplitudeCurve == rhs.coherenceToAmplitudeCurve &&
        lhs.baseFrequency == rhs.baseFrequency &&
        lhs.hrToTempoMultiplier == rhs.hrToTempoMultiplier &&
        lhs.tempoRange == rhs.tempoRange &&
        lhs.coherenceToSpatialStability == rhs.coherenceToSpatialStability &&
        lhs.spatialMovementIntensity == rhs.spatialMovementIntensity &&
        lhs.harmonicEnrichmentFactor == rhs.harmonicEnrichmentFactor &&
        lhs.kalmanProcessNoise == rhs.kalmanProcessNoise &&
        lhs.kalmanMeasurementNoise == rhs.kalmanMeasurementNoise &&
        lhs.parameterSmoothingFactor == rhs.parameterSmoothingFactor
    }
}


// MARK: - Preset Manager

/// Manages preset selection and persistence
@MainActor
class BioPresetManager: ObservableObject {

    /// Currently selected preset
    @Published var currentPreset: BioMappingPreset {
        didSet {
            savePreset()
            onPresetChanged?(currentPreset)
        }
    }

    /// Custom user presets (future feature)
    @Published var customPresets: [String: BioMappingConfiguration] = [:]

    /// Callback when preset changes
    var onPresetChanged: ((BioMappingPreset) -> Void)?

    private let userDefaultsKey = "com.echoelmusic.selectedPreset"

    init() {
        // Load saved preset or default to meditation
        if let savedPresetRaw = UserDefaults.standard.string(forKey: userDefaultsKey),
           let savedPreset = BioMappingPreset(rawValue: savedPresetRaw) {
            self.currentPreset = savedPreset
        } else {
            self.currentPreset = .meditation
        }
    }

    /// Save current preset to UserDefaults
    private func savePreset() {
        UserDefaults.standard.set(currentPreset.rawValue, forKey: userDefaultsKey)
    }

    /// Get the active mapping configuration
    var activeConfiguration: BioMappingConfiguration {
        currentPreset.mapping
    }

    /// Cycle to the next preset
    func nextPreset() {
        let allPresets = BioMappingPreset.allCases
        guard let currentIndex = allPresets.firstIndex(of: currentPreset) else { return }
        let nextIndex = (currentIndex + 1) % allPresets.count
        currentPreset = allPresets[nextIndex]
    }

    /// Cycle to the previous preset
    func previousPreset() {
        let allPresets = BioMappingPreset.allCases
        guard let currentIndex = allPresets.firstIndex(of: currentPreset) else { return }
        let previousIndex = (currentIndex - 1 + allPresets.count) % allPresets.count
        currentPreset = allPresets[previousIndex]
    }
}
