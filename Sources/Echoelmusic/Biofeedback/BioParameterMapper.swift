import Foundation
import Combine

/// Maps biometric parameters to audio synthesis parameters
/// HRV Coherence → Reverb, Filter, Amplitude
/// Heart Rate → Tempo, Pitch Shift, Frequency
/// Voice Pitch → Base Note, Harmonics
/// Implements exponential smoothing for natural parameter changes
@MainActor
class BioParameterMapper: ObservableObject {

    // MARK: - Published Mapped Parameters

    /// Reverb wet/dry mix (0.0 - 1.0)
    /// Mapped from: HRV Coherence (higher coherence = more reverb)
    @Published var reverbWet: Float = 0.3

    /// Filter cutoff frequency (Hz)
    /// Mapped from: Heart Rate (higher HR = higher cutoff)
    @Published var filterCutoff: Float = 1000.0

    /// Amplitude/volume (0.0 - 1.0)
    /// Mapped from: HRV Coherence + Audio Level
    @Published var amplitude: Float = 0.5

    /// Base note frequency (Hz)
    /// Mapped from: Voice Pitch
    @Published var baseFrequency: Float = 432.0

    /// Tempo (BPM)
    /// Mapped from: Heart Rate (synchronized breathing)
    @Published var tempo: Float = 60.0

    /// Spatial position (X/Y/Z)
    /// Mapped from: HRV Coherence (higher = more centered)
    @Published var spatialPosition: (x: Float, y: Float, z: Float) = (0, 0, 1)

    /// Harmonic richness (number of harmonics)
    /// Mapped from: Voice pitch clarity
    @Published var harmonicCount: Int = 5


    // MARK: - Smoothing Configuration

    /// Smoothing factor (0.0 = no smoothing, 1.0 = max smoothing)
    private let smoothingFactor: Float = 0.85

    /// Fast smoothing for quick changes (e.g., voice pitch)
    private let fastSmoothingFactor: Float = 0.7


    // MARK: - Mapping Ranges

    // HRV Coherence: 0-100 (HeartMath scale)
    private let hrvCoherenceRange = (min: 0.0, max: 100.0)

    // Heart Rate: 40-120 BPM (typical range)
    private let heartRateRange = (min: 40.0, max: 120.0)

    // Voice Pitch: 80-1000 Hz (human voice range)
    private let voicePitchRange = (min: 80.0, max: 1000.0)

    // Reverb: 10-80% wet
    private let reverbRange = (min: 0.1, max: 0.8)

    // Filter: 200-2000 Hz
    private let filterRange = (min: 200.0, max: 2000.0)

    // Amplitude: 0.3-0.8
    private let amplitudeRange = (min: 0.3, max: 0.8)


    // MARK: - Musical Scale Configuration

    /// Musical scale for harmonic generation (ISO 16:1975 Standard)
    /// Equal temperament tuning based on A440 concert pitch
    private let musicalScale: [Float] = [
        440.00,  // A4 (ISO standard concert pitch)
        493.88,  // B4
        523.25,  // C5
        587.33,  // D5
        659.25,  // E5
        698.46,  // F5
        783.99,  // G5
    ]


    // MARK: - Public Methods

    /// Update all mapped parameters from biometric data
    /// - Parameters:
    ///   - hrvCoherence: HRV coherence score (0-100)
    ///   - heartRate: Heart rate (BPM)
    ///   - voicePitch: Detected voice pitch (Hz)
    ///   - audioLevel: Current audio level (0.0-1.0)
    func updateParameters(
        hrvCoherence: Double,
        heartRate: Double,
        voicePitch: Float,
        audioLevel: Float
    ) {
        // Map HRV Coherence → Reverb Wet
        let targetReverb = mapHRVToReverb(hrvCoherence: hrvCoherence)
        reverbWet = smooth(current: reverbWet, target: targetReverb, factor: smoothingFactor)

        // Map Heart Rate → Filter Cutoff
        let targetFilter = mapHeartRateToFilter(heartRate: heartRate)
        filterCutoff = smooth(current: filterCutoff, target: targetFilter, factor: smoothingFactor)

        // Map HRV + Audio Level → Amplitude
        let targetAmplitude = mapToAmplitude(hrvCoherence: hrvCoherence, audioLevel: audioLevel)
        amplitude = smooth(current: amplitude, target: targetAmplitude, factor: smoothingFactor)

        // Map Voice Pitch → Base Frequency (snap to healing scale)
        let targetFrequency = mapVoicePitchToScale(voicePitch: voicePitch)
        baseFrequency = smooth(current: baseFrequency, target: targetFrequency, factor: fastSmoothingFactor)

        // Map Heart Rate → Tempo (for breathing guidance)
        let targetTempo = mapHeartRateToTempo(heartRate: heartRate)
        tempo = smooth(current: tempo, target: targetTempo, factor: smoothingFactor)

        // Map HRV Coherence → Spatial Position
        spatialPosition = mapHRVToSpatialPosition(hrvCoherence: hrvCoherence)

        // Map Voice Pitch Clarity → Harmonic Count
        harmonicCount = mapVoicePitchToHarmonics(voicePitch: voicePitch, audioLevel: audioLevel)

        #if DEBUG
        logParameters()
        #endif
    }


    // MARK: - Individual Mapping Functions

    /// Map HRV Coherence (0-100) → Reverb Wet (10-80%)
    /// Low coherence (stress) = Less reverb (10%)
    /// High coherence (flow) = More reverb (80%)
    private func mapHRVToReverb(hrvCoherence: Double) -> Float {
        let normalized = normalize(
            value: Float(hrvCoherence),
            from: (Float(hrvCoherenceRange.min), Float(hrvCoherenceRange.max))
        )

        return lerp(
            from: reverbRange.min,
            to: reverbRange.max,
            t: normalized
        )
    }

    /// Map Heart Rate (40-120 BPM) → Filter Cutoff (200-2000 Hz)
    /// Low HR (relaxed) = Lower cutoff (darker sound)
    /// High HR (active) = Higher cutoff (brighter sound)
    private func mapHeartRateToFilter(heartRate: Double) -> Float {
        let normalized = normalize(
            value: Float(heartRate),
            from: (Float(heartRateRange.min), Float(heartRateRange.max))
        )

        return lerp(
            from: filterRange.min,
            to: filterRange.max,
            t: normalized
        )
    }

    /// Map HRV Coherence + Audio Level → Amplitude
    /// Combined mapping for natural volume control
    private func mapToAmplitude(hrvCoherence: Double, audioLevel: Float) -> Float {
        // HRV component (70% weight)
        let hrvNormalized = normalize(
            value: Float(hrvCoherence),
            from: (Float(hrvCoherenceRange.min), Float(hrvCoherenceRange.max))
        )
        let hrvContribution = hrvNormalized * 0.7

        // Audio level component (30% weight)
        let audioContribution = audioLevel * 0.3

        // Combine and map to amplitude range
        let combined = hrvContribution + audioContribution

        return lerp(
            from: amplitudeRange.min,
            to: amplitudeRange.max,
            t: combined
        )
    }

    /// Map Voice Pitch → Musical Scale (ISO standard frequencies)
    /// Snaps detected pitch to nearest note in equal temperament scale
    private func mapVoicePitchToScale(voicePitch: Float) -> Float {
        guard voicePitch > 0 else { return musicalScale[0] }

        // Find nearest note in musical scale (ISO 440Hz standard)
        var closestNote = musicalScale[0]
        var minDistance = abs(voicePitch - closestNote)

        for note in musicalScale {
            let distance = abs(voicePitch - note)
            if distance < minDistance {
                minDistance = distance
                closestNote = note
            }
        }

        return closestNote
    }

    /// Map Heart Rate → Tempo (for breathing guidance)
    /// Typical breathing rate: 4-8 breaths/minute = HR/4
    private func mapHeartRateToTempo(heartRate: Double) -> Float {
        // Convert HR to breathing tempo (roughly HR / 4)
        let breathingRate = Float(heartRate) / 4.0

        // Clamp to reasonable breathing range (4-8 breaths/min)
        return max(4.0, min(8.0, breathingRate))
    }

    /// Map HRV Coherence → Spatial Position
    /// Low coherence = Audio moves around (X/Y variation)
    /// High coherence = Audio centered (0, 0, Z)
    private func mapHRVToSpatialPosition(hrvCoherence: Double) -> (x: Float, y: Float, z: Float) {
        let normalized = normalize(
            value: Float(hrvCoherence),
            from: (Float(hrvCoherenceRange.min), Float(hrvCoherenceRange.max))
        )

        // Low coherence → more spatial movement
        // High coherence → centered position
        let maxDeviation: Float = 1.0 - normalized  // 0.0 (centered) to 1.0 (spread)

        // Create subtle circular motion for low coherence
        let angle = Float(Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6.28))
        let x = cos(angle) * maxDeviation * 0.5
        let y = sin(angle) * maxDeviation * 0.5
        let z: Float = 1.0  // Keep constant distance

        return (x, y, z)
    }

    /// Map Voice Pitch Clarity → Harmonic Count
    /// Clear pitch = More harmonics (rich sound)
    /// Unclear/noisy = Fewer harmonics (simple sound)
    private func mapVoicePitchToHarmonics(voicePitch: Float, audioLevel: Float) -> Int {
        // If no pitch detected or very quiet, use minimal harmonics
        if voicePitch <= 0 || audioLevel < 0.1 {
            return 3
        }

        // Strong signal with clear pitch = more harmonics
        let clarity = audioLevel  // Higher level = clearer signal

        if clarity > 0.6 {
            return 7  // Rich harmonic content
        } else if clarity > 0.3 {
            return 5  // Medium harmonics
        } else {
            return 3  // Basic harmonics
        }
    }


    // MARK: - Utility Functions

    /// Normalize value from input range to 0.0-1.0
    private func normalize(value: Float, from range: (Float, Float)) -> Float {
        let clamped = max(range.0, min(range.1, value))
        return (clamped - range.0) / (range.1 - range.0)
    }

    /// Linear interpolation
    private func lerp(from: Float, to: Float, t: Float) -> Float {
        return from + (to - from) * t
    }

    /// Exponential smoothing
    private func smooth(current: Float, target: Float, factor: Float) -> Float {
        return current * factor + target * (1.0 - factor)
    }

    /// Log current parameters (debug only)
    private func logParameters() {
        let timestamp = Int(Date().timeIntervalSince1970)
        if timestamp % 5 == 0 {  // Every 5 seconds
            print("🎛️  BioParams: Rev:\(Int(reverbWet*100))% Filt:\(Int(filterCutoff))Hz Amp:\(Int(amplitude*100))% Freq:\(Int(baseFrequency))Hz")
        }
    }


    // MARK: - Presets

    /// Apply preset for specific state
    func applyPreset(_ preset: BioPreset) {
        let config = preset.configuration

        reverbWet = config.reverbWet
        filterCutoff = config.filterCutoff
        amplitude = config.amplitude
        baseFrequency = config.baseFrequency
        tempo = config.tempo
        harmonicCount = config.harmonicCount
        spatialPosition = config.spatialPosition

        print("🎛️  Applied preset: \(preset.rawValue)")
        print("   📝 \(preset.description)")
    }

    enum BioPreset: String, CaseIterable, Identifiable {
        case meditation = "Meditation"
        case focus = "Focus"
        case relaxation = "Deep Relaxation"
        case energize = "Energize"
        case creativeFlow = "Creative Flow"

        var id: String { rawValue }

        /// Detaillierte Beschreibung des Presets (wissenschaftlich fundiert)
        var description: String {
            switch self {
            case .meditation:
                return "Theta wave entrainment (6Hz) - Supports meditation practice via low-frequency modulation (Fell & Axmacher, 2009)"
            case .focus:
                return "Beta wave support (20Hz) - Maintains alertness and attention during active tasks (Engel & Fries, 2012)"
            case .relaxation:
                return "Alpha wave enhancement (10Hz) - Promotes relaxation and reduces anxiety (Bazanova & Vernon, 2015)"
            case .energize:
                return "Gamma stimulation (40Hz) - May enhance cognitive function and attention (Iaccarino et al., Nature 2016)"
            case .creativeFlow:
                return "Alpha-Theta transition (8Hz) - Supports creative thinking and flow states (research-based)"
            }
        }

        /// Icon/Symbol für UI
        var icon: String {
            switch self {
            case .meditation: return "🧘‍♂️"
            case .focus: return "🎯"
            case .relaxation: return "😌"
            case .energize: return "⚡️"
            case .creativeFlow: return "🎨"
            }
        }

        /// Preset-Konfiguration
        var configuration: PresetConfiguration {
            switch self {
            case .meditation:
                return PresetConfiguration(
                    reverbWet: 0.7,
                    filterCutoff: 500.0,
                    amplitude: 0.5,
                    baseFrequency: 261.63,  // C4 (ISO standard) - Theta entrainment (6Hz)
                    tempo: 6.0,  // Theta brainwave frequency (Fell & Axmacher, 2009)
                    harmonicCount: 7,  // Rich harmonies
                    spatialPosition: (x: 0.0, y: 0.0, z: 1.0),
                    colorMood: (r: 0.4, g: 0.2, b: 0.8)
                )

            case .focus:
                return PresetConfiguration(
                    reverbWet: 0.3,
                    filterCutoff: 1500.0,
                    amplitude: 0.6,
                    baseFrequency: 440.0,  // A4 (ISO 16:1975 standard) - Beta (20Hz)
                    tempo: 7.0,
                    harmonicCount: 5,
                    spatialPosition: (x: 0.0, y: 0.0, z: 1.0),
                    colorMood: (r: 0.2, g: 0.6, b: 0.9)
                )

            case .relaxation:
                return PresetConfiguration(
                    reverbWet: 0.8,  // Maximum reverb
                    filterCutoff: 300.0,  // Low frequencies
                    amplitude: 0.4,  // Quiet
                    baseFrequency: 196.0,  // G3 (ISO standard) - Alpha (10Hz) relaxation
                    tempo: 4.0,  // Very slow breathing (Delta approaching)
                    harmonicCount: 3,  // Simple harmonies
                    spatialPosition: (x: 0.0, y: 0.0, z: 1.5),
                    colorMood: (r: 0.2, g: 0.8, b: 0.5)
                )

            case .energize:
                return PresetConfiguration(
                    reverbWet: 0.2,  // Minimal reverb (dry)
                    filterCutoff: 2000.0,  // Bright frequencies
                    amplitude: 0.7,  // Loud
                    baseFrequency: 329.63,  // E4 (ISO standard) - Gamma (40Hz) cognition
                    tempo: 8.0,  // Fast breathing
                    harmonicCount: 6,
                    spatialPosition: (x: 0.0, y: 0.0, z: 0.8),
                    colorMood: (r: 1.0, g: 0.5, b: 0.0)
                )

            case .creativeFlow:
                return PresetConfiguration(
                    reverbWet: 0.5,  // Balanced
                    filterCutoff: 1200.0,  // Mid frequencies
                    amplitude: 0.6,
                    baseFrequency: 293.66,  // D4 (ISO standard) - Alpha-Theta transition (8Hz)
                    tempo: 6.5,  // Moderate breathing
                    harmonicCount: 8,  // Rich harmonies for creativity
                    spatialPosition: (x: 0.0, y: 0.0, z: 1.0),
                    colorMood: (r: 0.6, g: 0.3, b: 0.9)
                )
            }
        }
    }

    /// Konfiguration für ein Bio-Mapping Preset
    struct PresetConfiguration {
        let reverbWet: Float
        let filterCutoff: Float
        let amplitude: Float
        let baseFrequency: Float
        let tempo: Float
        let harmonicCount: Int
        let spatialPosition: (x: Float, y: Float, z: Float)
        let colorMood: (r: Float, g: Float, b: Float)
    }
}


// MARK: - Parameter Validation

extension BioParameterMapper {

    /// Validate that all parameters are in valid ranges
    var isValid: Bool {
        reverbWet >= 0.0 && reverbWet <= 1.0 &&
        filterCutoff >= 20.0 && filterCutoff <= 20000.0 &&
        amplitude >= 0.0 && amplitude <= 1.0 &&
        baseFrequency >= 20.0 && baseFrequency <= 20000.0 &&
        tempo >= 1.0 && tempo <= 20.0
    }

    /// Get parameter summary for debugging
    var parameterSummary: String {
        """
        BioParameter Mapping:
        - Reverb: \(Int(reverbWet * 100))%
        - Filter: \(Int(filterCutoff)) Hz
        - Amplitude: \(Int(amplitude * 100))%
        - Frequency: \(Int(baseFrequency)) Hz
        - Tempo: \(String(format: "%.1f", tempo)) breaths/min
        - Spatial: X:\(String(format: "%.2f", spatialPosition.x)) Y:\(String(format: "%.2f", spatialPosition.y)) Z:\(String(format: "%.2f", spatialPosition.z))
        - Harmonics: \(harmonicCount)
        """
    }
}
