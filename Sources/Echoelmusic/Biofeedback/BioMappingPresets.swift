import Foundation

/// Bio-Mapping Presets System
/// Scientific approach to mapping biometric parameters to audio/visual parameters
/// Based on psychoacoustics, HRV research, and auditory perception science

// MARK: - Preset Definitions

/// Bio-mapping preset with full parameter configuration
/// All parameters are based on measurable physiological responses
struct BioMappingPreset: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: PresetCategory
    let description: String
    let icon: String

    // Parameter mappings (scientifically grounded)
    let hrvToReverbRange: ClosedRange<Float>
    let heartRateToFilterRange: ClosedRange<Float>
    let coherenceToAmplitudeRange: ClosedRange<Float>
    let baseFrequency: Float          // Reference pitch (A4 tuning)
    let tempoRange: ClosedRange<Float> // Breathing rate guidance (breaths/min)
    let harmonicProfile: HarmonicProfile
    let spatialMode: SpatialMappingMode
    let visualMode: String

    // Binaural beat configuration
    // Based on EEG brainwave frequency bands (Niedermeyer & da Silva, 2004)
    let binauralBaseFrequency: Float  // Carrier frequency (Hz)
    let binauralBeatFrequency: Float  // Difference frequency for entrainment
    let brainwaveTarget: BrainwaveBand

    init(
        name: String,
        category: PresetCategory,
        description: String,
        icon: String,
        hrvToReverbRange: ClosedRange<Float> = 0.1...0.8,
        heartRateToFilterRange: ClosedRange<Float> = 200...2000,
        coherenceToAmplitudeRange: ClosedRange<Float> = 0.3...0.8,
        baseFrequency: Float = 440.0,  // Standard concert pitch
        tempoRange: ClosedRange<Float> = 4...8,
        harmonicProfile: HarmonicProfile = .balanced,
        spatialMode: SpatialMappingMode = .centered,
        visualMode: String = "waveform",
        binauralBaseFrequency: Float = 200,
        binauralBeatFrequency: Float = 10,
        brainwaveTarget: BrainwaveBand = .alpha
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.description = description
        self.icon = icon
        self.hrvToReverbRange = hrvToReverbRange
        self.heartRateToFilterRange = heartRateToFilterRange
        self.coherenceToAmplitudeRange = coherenceToAmplitudeRange
        self.baseFrequency = baseFrequency
        self.tempoRange = tempoRange
        self.harmonicProfile = harmonicProfile
        self.spatialMode = spatialMode
        self.visualMode = visualMode
        self.binauralBaseFrequency = binauralBaseFrequency
        self.binauralBeatFrequency = binauralBeatFrequency
        self.brainwaveTarget = brainwaveTarget
    }
}

// MARK: - Supporting Types

enum PresetCategory: String, Codable, CaseIterable {
    case relaxation = "Relaxation"
    case focus = "Focus"
    case creative = "Creative"
    case sleep = "Sleep"
    case energizing = "Energizing"
    case experimental = "Experimental"
    case custom = "Custom"
}

/// Harmonic content profiles based on Fourier series
enum HarmonicProfile: String, Codable, CaseIterable {
    case pure = "Pure"            // Sine wave - fundamental only
    case minimal = "Minimal"      // 2-3 harmonics (clarinet-like)
    case balanced = "Balanced"    // 5 harmonics (typical acoustic)
    case rich = "Rich"            // 7+ harmonics (brass-like)
    case oddOnly = "Odd Only"     // Odd harmonics (square wave character)
}

/// Spatial audio mapping modes
enum SpatialMappingMode: String, Codable, CaseIterable {
    case centered = "Centered"
    case orbital = "Orbital"
    case breathing = "Breathing"
    case coherenceResponsive = "Coherence Responsive"
    case immersive = "Immersive"
}

/// EEG Brainwave frequency bands
/// Reference: Niedermeyer E, da Silva FL. Electroencephalography (2004)
enum BrainwaveBand: String, Codable, CaseIterable {
    case delta = "Delta"      // 0.5-4 Hz - Deep sleep, NREM stage 3-4
    case theta = "Theta"      // 4-8 Hz - Drowsiness, light sleep, REM
    case alpha = "Alpha"      // 8-13 Hz - Relaxed wakefulness, eyes closed
    case beta = "Beta"        // 13-30 Hz - Active thinking, focus
    case gamma = "Gamma"      // 30-100 Hz - Cognitive processing, attention

    /// Frequency range based on clinical EEG standards
    var frequencyRange: ClosedRange<Float> {
        switch self {
        case .delta: return 0.5...4.0
        case .theta: return 4.0...8.0
        case .alpha: return 8.0...13.0
        case .beta: return 13.0...30.0
        case .gamma: return 30.0...100.0
        }
    }

    /// Center frequency for binaural beat generation
    var centerFrequency: Float {
        let range = frequencyRange
        return (range.lowerBound + range.upperBound) / 2
    }

    /// Associated cognitive state (based on EEG research)
    var associatedState: String {
        switch self {
        case .delta: return "Deep sleep, unconscious"
        case .theta: return "Drowsy, light meditation"
        case .alpha: return "Relaxed, calm alertness"
        case .beta: return "Active thinking, concentration"
        case .gamma: return "High-level cognition, perception"
        }
    }
}

// MARK: - Scientific Tuning Standards

/// Reference tuning systems
enum TuningStandard: String, Codable, CaseIterable {
    case concert440 = "A440 (Concert)"     // ISO 16:1975 standard
    case baroque415 = "A415 (Baroque)"     // Historical tuning
    case scientific432 = "A432 (Verdi)"    // Proposed by Verdi, no scientific advantage
    case orchestral442 = "A442 (European)" // Common European orchestra tuning

    var a4Frequency: Float {
        switch self {
        case .concert440: return 440.0
        case .baroque415: return 415.0
        case .scientific432: return 432.0
        case .orchestral442: return 442.0
        }
    }

    /// Calculate frequency for any MIDI note given this tuning
    func frequency(forMidiNote note: Int) -> Float {
        // f = A4 * 2^((n-69)/12)
        return a4Frequency * pow(2.0, Float(note - 69) / 12.0)
    }
}

// MARK: - Preset Library

/// Library of scientifically-grounded bio-mapping presets
class BioMappingPresetLibrary {

    static let shared = BioMappingPresetLibrary()

    let presets: [BioMappingPreset]

    private init() {
        self.presets = Self.createDefaultPresets()
    }

    func presets(for category: PresetCategory) -> [BioMappingPreset] {
        presets.filter { $0.category == category }
    }

    func preset(named name: String) -> BioMappingPreset? {
        presets.first { $0.name == name }
    }

    // MARK: - Default Presets

    private static func createDefaultPresets() -> [BioMappingPreset] {
        return [
            // RELAXATION PRESETS
            // Alpha waves (8-13 Hz) are associated with relaxed wakefulness (Klimesch, 1999)
            BioMappingPreset(
                name: "Deep Relaxation",
                category: .relaxation,
                description: "Alpha-band binaural beats for relaxed alertness. Research shows alpha activity increases during eyes-closed rest.",
                icon: "leaf.fill",
                hrvToReverbRange: 0.5...0.9,
                heartRateToFilterRange: 150...600,
                coherenceToAmplitudeRange: 0.3...0.6,
                baseFrequency: 440.0,
                tempoRange: 4...6,  // Slow breathing promotes parasympathetic response
                harmonicProfile: .pure,
                spatialMode: .breathing,
                visualMode: "waveform",
                binauralBaseFrequency: 200,
                binauralBeatFrequency: 10,  // Alpha center
                brainwaveTarget: .alpha
            ),

            BioMappingPreset(
                name: "HRV Coherence Training",
                category: .relaxation,
                description: "Optimized for heart rate variability biofeedback. 6 breaths/min maximizes respiratory sinus arrhythmia (Lehrer et al., 2003).",
                icon: "heart.fill",
                hrvToReverbRange: 0.4...0.8,
                heartRateToFilterRange: 200...800,
                coherenceToAmplitudeRange: 0.4...0.8,
                baseFrequency: 440.0,
                tempoRange: 5.5...6.5,  // Resonance frequency breathing
                harmonicProfile: .balanced,
                spatialMode: .coherenceResponsive,
                visualMode: "heartCoherenceMandala",
                binauralBaseFrequency: 250,
                binauralBeatFrequency: 10,
                brainwaveTarget: .alpha
            ),

            // FOCUS PRESETS
            // Beta waves (13-30 Hz) correlate with active concentration (Engel & Fries, 2010)
            BioMappingPreset(
                name: "Concentration",
                category: .focus,
                description: "Beta-band targeting for sustained attention. Low-beta (13-15 Hz) associated with calm focus.",
                icon: "brain.head.profile",
                hrvToReverbRange: 0.1...0.4,
                heartRateToFilterRange: 800...2500,
                coherenceToAmplitudeRange: 0.5...0.8,
                baseFrequency: 440.0,
                tempoRange: 6...8,
                harmonicProfile: .minimal,
                spatialMode: .centered,
                visualMode: "brainwave",
                binauralBaseFrequency: 300,
                binauralBeatFrequency: 14,  // Low beta
                brainwaveTarget: .beta
            ),

            BioMappingPreset(
                name: "Active Focus",
                category: .focus,
                description: "Mid-beta range for active problem solving and analytical thinking.",
                icon: "lightbulb.fill",
                hrvToReverbRange: 0.1...0.3,
                heartRateToFilterRange: 1000...2000,
                coherenceToAmplitudeRange: 0.6...0.9,
                baseFrequency: 440.0,
                tempoRange: 7...9,
                harmonicProfile: .minimal,
                spatialMode: .centered,
                visualMode: "spectral",
                binauralBaseFrequency: 350,
                binauralBeatFrequency: 20,  // Mid beta
                brainwaveTarget: .beta
            ),

            // CREATIVE PRESETS
            // Theta waves (4-8 Hz) linked to creative insight and memory (Raghavachari et al., 2001)
            BioMappingPreset(
                name: "Creative Flow",
                category: .creative,
                description: "Theta-alpha border for divergent thinking. Research links theta bursts to creative insight.",
                icon: "paintbrush.fill",
                hrvToReverbRange: 0.4...0.8,
                heartRateToFilterRange: 400...1200,
                coherenceToAmplitudeRange: 0.4...0.8,
                baseFrequency: 440.0,
                tempoRange: 4...7,
                harmonicProfile: .rich,
                spatialMode: .orbital,
                visualMode: "particles",
                binauralBaseFrequency: 220,
                binauralBeatFrequency: 7,  // High theta
                brainwaveTarget: .theta
            ),

            BioMappingPreset(
                name: "Sound Design",
                category: .creative,
                description: "Full parameter range for experimental audio. No binaural targeting - pure sonic exploration.",
                icon: "waveform.path.ecg",
                hrvToReverbRange: 0.1...0.95,
                heartRateToFilterRange: 100...4000,
                coherenceToAmplitudeRange: 0.2...0.9,
                baseFrequency: 440.0,
                tempoRange: 2...12,
                harmonicProfile: .rich,
                spatialMode: .immersive,
                visualMode: "spectral",
                binauralBaseFrequency: 150,
                binauralBeatFrequency: 0,  // No binaural beat
                brainwaveTarget: .alpha
            ),

            // SLEEP PRESETS
            // Delta waves (0.5-4 Hz) dominant in deep NREM sleep (Steriade et al., 1993)
            BioMappingPreset(
                name: "Sleep Onset",
                category: .sleep,
                description: "Delta-band for sleep induction. Progressive slowing mimics natural sleep onset EEG patterns.",
                icon: "moon.fill",
                hrvToReverbRange: 0.7...0.95,
                heartRateToFilterRange: 100...300,
                coherenceToAmplitudeRange: 0.2...0.4,
                baseFrequency: 440.0,
                tempoRange: 3...5,
                harmonicProfile: .pure,
                spatialMode: .breathing,
                visualMode: "waveform",
                binauralBaseFrequency: 100,
                binauralBeatFrequency: 2,  // Delta range
                brainwaveTarget: .delta
            ),

            BioMappingPreset(
                name: "Deep Rest",
                category: .sleep,
                description: "Low delta frequencies for deep relaxation. Minimal harmonic content reduces arousal.",
                icon: "zzz",
                hrvToReverbRange: 0.8...0.95,
                heartRateToFilterRange: 80...200,
                coherenceToAmplitudeRange: 0.1...0.3,
                baseFrequency: 440.0,
                tempoRange: 2...4,
                harmonicProfile: .pure,
                spatialMode: .centered,
                visualMode: "waveform",
                binauralBaseFrequency: 80,
                binauralBeatFrequency: 1,  // Very low delta
                brainwaveTarget: .delta
            ),

            // ENERGIZING PRESETS
            // Gamma waves (30-100 Hz) associated with heightened perception (Tallon-Baudry & Bertrand, 1999)
            BioMappingPreset(
                name: "Alert Wakefulness",
                category: .energizing,
                description: "High beta to low gamma for alertness. Note: High frequencies may cause fatigue with prolonged use.",
                icon: "sun.max.fill",
                hrvToReverbRange: 0.1...0.3,
                heartRateToFilterRange: 1000...3000,
                coherenceToAmplitudeRange: 0.6...0.9,
                baseFrequency: 440.0,
                tempoRange: 8...12,
                harmonicProfile: .oddOnly,
                spatialMode: .immersive,
                visualMode: "particles",
                binauralBaseFrequency: 400,
                binauralBeatFrequency: 32,  // Low gamma
                brainwaveTarget: .gamma
            ),

            // EXPERIMENTAL PRESETS
            BioMappingPreset(
                name: "Cymatics Lab",
                category: .experimental,
                description: "Frequency sweep for observing Chladni patterns. Visual feedback shows standing wave nodes.",
                icon: "waveform.circle",
                hrvToReverbRange: 0.3...0.7,
                heartRateToFilterRange: 200...2000,
                coherenceToAmplitudeRange: 0.5...0.8,
                baseFrequency: 440.0,
                tempoRange: 4...8,
                harmonicProfile: .pure,
                spatialMode: .centered,
                visualMode: "cymatics",
                binauralBaseFrequency: 0,   // No binaural
                binauralBeatFrequency: 0,
                brainwaveTarget: .alpha
            ),

            BioMappingPreset(
                name: "Harmonic Series",
                category: .experimental,
                description: "Explore natural harmonic relationships. Frequencies follow integer ratios (1:2:3:4...).",
                icon: "chart.bar.fill",
                hrvToReverbRange: 0.2...0.6,
                heartRateToFilterRange: 300...1500,
                coherenceToAmplitudeRange: 0.4...0.8,
                baseFrequency: 110.0,  // A2 - clear harmonic series
                tempoRange: 4...8,
                harmonicProfile: .rich,
                spatialMode: .immersive,
                visualMode: "spectral",
                binauralBaseFrequency: 0,
                binauralBeatFrequency: 0,
                brainwaveTarget: .alpha
            ),

            BioMappingPreset(
                name: "Resonance Explorer",
                category: .experimental,
                description: "Study resonance and Q-factor relationships. Visualizes frequency response curves.",
                icon: "tuningfork",
                hrvToReverbRange: 0.1...0.9,
                heartRateToFilterRange: 100...5000,
                coherenceToAmplitudeRange: 0.3...0.9,
                baseFrequency: 440.0,
                tempoRange: 2...10,
                harmonicProfile: .balanced,
                spatialMode: .orbital,
                visualMode: "spectral",
                binauralBaseFrequency: 0,
                binauralBeatFrequency: 0,
                brainwaveTarget: .alpha
            )
        ]
    }
}

// MARK: - Preset Application

extension BioMappingPreset {

    @MainActor
    func apply(to mapper: BioParameterMapper) {
        mapper.reverbWet = (hrvToReverbRange.lowerBound + hrvToReverbRange.upperBound) / 2
        mapper.filterCutoff = (heartRateToFilterRange.lowerBound + heartRateToFilterRange.upperBound) / 2
        mapper.amplitude = (coherenceToAmplitudeRange.lowerBound + coherenceToAmplitudeRange.upperBound) / 2
        mapper.baseFrequency = baseFrequency
        mapper.tempo = (tempoRange.lowerBound + tempoRange.upperBound) / 2

        switch harmonicProfile {
        case .minimal:
            mapper.harmonicCount = 3
        case .balanced:
            mapper.harmonicCount = 5
        case .rich:
            mapper.harmonicCount = 7
        case .pure:
            mapper.harmonicCount = 1
        case .oddOnly:
            mapper.harmonicCount = 9
        }

        print("🎛️ Applied preset: \(name)")
    }

    func mapHRVToReverb(_ hrvCoherence: Double) -> Float {
        let normalized = Float(hrvCoherence / 100.0)
        return hrvToReverbRange.lowerBound + normalized * (hrvToReverbRange.upperBound - hrvToReverbRange.lowerBound)
    }

    func mapHeartRateToFilter(_ heartRate: Double) -> Float {
        let normalized = Float((heartRate - 40.0) / 80.0).clamped(to: 0...1)
        return heartRateToFilterRange.lowerBound + normalized * (heartRateToFilterRange.upperBound - heartRateToFilterRange.lowerBound)
    }

    func mapCoherenceToAmplitude(_ coherence: Double) -> Float {
        let normalized = Float(coherence / 100.0)
        return coherenceToAmplitudeRange.lowerBound + normalized * (coherenceToAmplitudeRange.upperBound - coherenceToAmplitudeRange.lowerBound)
    }
}

// MARK: - Float Extension

extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
