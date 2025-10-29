import Foundation

/// Bio-Mapping Presets for different use cases
///
/// Each preset defines how biometric signals (HRV, heart rate, breathing) are mapped
/// to audio, visual, and light parameters for specific experiences.
///
/// **Presets:**
/// - Creative: Dynamic, energetic mapping for creative sessions
/// - Meditation: Calm, slow mapping for deep meditation
/// - Focus: Balanced mapping for concentration and flow
/// - Healing: Gentle, nurturing mapping for healing sessions
/// - Energetic: High-energy mapping for active movement
/// - Relaxation: Gentle, soothing mapping for relaxation
/// - Performance: Optimized for live performance and expression
/// - Exploration: Experimental mapping for sound exploration
/// - Sleep: Ultra-calm mapping for sleep preparation
/// - Flow: Adaptive mapping for flow states
public enum BioMappingPreset: String, CaseIterable {
    case creative = "Creative"
    case meditation = "Meditation"
    case focus = "Focus"
    case healing = "Healing"
    case energetic = "Energetic"
    case relaxation = "Relaxation"
    case performance = "Performance"
    case exploration = "Exploration"
    case sleep = "Sleep"
    case flow = "Flow"

    /// Icon name for UI display
    public var iconName: String {
        switch self {
        case .creative: return "sparkles"
        case .meditation: return "leaf.fill"
        case .focus: return "scope"
        case .healing: return "heart.fill"
        case .energetic: return "bolt.fill"
        case .relaxation: return "cloud.fill"
        case .performance: return "music.note"
        case .exploration: return "wand.and.stars"
        case .sleep: return "moon.fill"
        case .flow: return "water.waves"
        }
    }

    /// Description for UI display
    public var description: String {
        switch self {
        case .creative:
            return "Dynamic mapping for creative expression and artistic flow"
        case .meditation:
            return "Calm, slow mapping for deep meditation and mindfulness"
        case .focus:
            return "Balanced mapping for concentration and sustained focus"
        case .healing:
            return "Gentle, nurturing mapping for healing and recovery"
        case .energetic:
            return "High-energy mapping for movement and active expression"
        case .relaxation:
            return "Gentle, soothing mapping for deep relaxation"
        case .performance:
            return "Optimized for live performance and dynamic expression"
        case .exploration:
            return "Experimental mapping for sonic exploration"
        case .sleep:
            return "Ultra-calm mapping for sleep preparation"
        case .flow:
            return "Adaptive mapping for optimal flow states"
        }
    }

    /// Get mapping configuration for this preset
    public func mapping() -> BioMappingConfiguration {
        switch self {
        case .creative:
            return BioMappingConfiguration(
                // Audio parameters
                filterCutoffRange: 500...8000,
                filterResonanceRange: 1.0...5.0,
                reverbWetRange: 0.2...0.7,
                amplitudeRange: 0.4...0.9,
                tempoRange: 80...140,

                // Visual parameters
                colorSaturation: 0.8,
                brightnessRange: 0.6...1.0,
                motionIntensity: 0.7,

                // Light parameters
                ledBrightness: 0.8,
                colorChangeSpeed: 0.6,

                // Signal smoothing
                kalmanProcessNoise: 0.05,
                kalmanMeasurementNoise: 0.1
            )

        case .meditation:
            return BioMappingConfiguration(
                filterCutoffRange: 200...2000,
                filterResonanceRange: 0.5...2.0,
                reverbWetRange: 0.5...0.9,
                amplitudeRange: 0.2...0.5,
                tempoRange: 40...80,

                colorSaturation: 0.5,
                brightnessRange: 0.3...0.6,
                motionIntensity: 0.3,

                ledBrightness: 0.4,
                colorChangeSpeed: 0.2,

                kalmanProcessNoise: 0.01,
                kalmanMeasurementNoise: 0.05
            )

        case .focus:
            return BioMappingConfiguration(
                filterCutoffRange: 400...4000,
                filterResonanceRange: 1.0...3.0,
                reverbWetRange: 0.3...0.6,
                amplitudeRange: 0.3...0.7,
                tempoRange: 60...120,

                colorSaturation: 0.6,
                brightnessRange: 0.5...0.8,
                motionIntensity: 0.5,

                ledBrightness: 0.6,
                colorChangeSpeed: 0.4,

                kalmanProcessNoise: 0.02,
                kalmanMeasurementNoise: 0.08
            )

        case .healing:
            return BioMappingConfiguration(
                filterCutoffRange: 250...3000,
                filterResonanceRange: 0.5...2.5,
                reverbWetRange: 0.4...0.8,
                amplitudeRange: 0.2...0.6,
                tempoRange: 50...90,

                colorSaturation: 0.6,
                brightnessRange: 0.4...0.7,
                motionIntensity: 0.4,

                ledBrightness: 0.5,
                colorChangeSpeed: 0.3,

                kalmanProcessNoise: 0.01,
                kalmanMeasurementNoise: 0.06
            )

        case .energetic:
            return BioMappingConfiguration(
                filterCutoffRange: 800...12000,
                filterResonanceRange: 1.5...6.0,
                reverbWetRange: 0.1...0.5,
                amplitudeRange: 0.5...1.0,
                tempoRange: 100...180,

                colorSaturation: 0.9,
                brightnessRange: 0.7...1.0,
                motionIntensity: 0.9,

                ledBrightness: 0.9,
                colorChangeSpeed: 0.8,

                kalmanProcessNoise: 0.08,
                kalmanMeasurementNoise: 0.15
            )

        case .relaxation:
            return BioMappingConfiguration(
                filterCutoffRange: 200...2500,
                filterResonanceRange: 0.5...2.0,
                reverbWetRange: 0.5...0.9,
                amplitudeRange: 0.2...0.5,
                tempoRange: 45...75,

                colorSaturation: 0.4,
                brightnessRange: 0.3...0.6,
                motionIntensity: 0.3,

                ledBrightness: 0.4,
                colorChangeSpeed: 0.2,

                kalmanProcessNoise: 0.01,
                kalmanMeasurementNoise: 0.04
            )

        case .performance:
            return BioMappingConfiguration(
                filterCutoffRange: 500...10000,
                filterResonanceRange: 1.0...5.0,
                reverbWetRange: 0.2...0.7,
                amplitudeRange: 0.5...0.95,
                tempoRange: 80...160,

                colorSaturation: 0.8,
                brightnessRange: 0.6...1.0,
                motionIntensity: 0.8,

                ledBrightness: 0.85,
                colorChangeSpeed: 0.7,

                kalmanProcessNoise: 0.06,
                kalmanMeasurementNoise: 0.12
            )

        case .exploration:
            return BioMappingConfiguration(
                filterCutoffRange: 100...15000,
                filterResonanceRange: 0.5...8.0,
                reverbWetRange: 0.0...1.0,
                amplitudeRange: 0.3...1.0,
                tempoRange: 30...200,

                colorSaturation: 0.7,
                brightnessRange: 0.4...1.0,
                motionIntensity: 0.6,

                ledBrightness: 0.7,
                colorChangeSpeed: 0.5,

                kalmanProcessNoise: 0.1,
                kalmanMeasurementNoise: 0.2
            )

        case .sleep:
            return BioMappingConfiguration(
                filterCutoffRange: 150...1500,
                filterResonanceRange: 0.3...1.5,
                reverbWetRange: 0.6...0.95,
                amplitudeRange: 0.1...0.3,
                tempoRange: 30...60,

                colorSaturation: 0.3,
                brightnessRange: 0.2...0.4,
                motionIntensity: 0.2,

                ledBrightness: 0.2,
                colorChangeSpeed: 0.1,

                kalmanProcessNoise: 0.005,
                kalmanMeasurementNoise: 0.03
            )

        case .flow:
            return BioMappingConfiguration(
                filterCutoffRange: 400...6000,
                filterResonanceRange: 1.0...4.0,
                reverbWetRange: 0.3...0.7,
                amplitudeRange: 0.4...0.8,
                tempoRange: 70...130,

                colorSaturation: 0.7,
                brightnessRange: 0.5...0.9,
                motionIntensity: 0.6,

                ledBrightness: 0.7,
                colorChangeSpeed: 0.5,

                kalmanProcessNoise: 0.03,
                kalmanMeasurementNoise: 0.09
            )
        }
    }
}

/// Configuration for bio-signal to parameter mapping
public struct BioMappingConfiguration {
    // MARK: - Audio Parameters

    /// Filter cutoff frequency range (Hz)
    public let filterCutoffRange: ClosedRange<Float>

    /// Filter resonance range (Q factor)
    public let filterResonanceRange: ClosedRange<Float>

    /// Reverb wet/dry mix range (0-1)
    public let reverbWetRange: ClosedRange<Float>

    /// Amplitude range (0-1)
    public let amplitudeRange: ClosedRange<Float>

    /// Tempo range (BPM)
    public let tempoRange: ClosedRange<Float>

    // MARK: - Visual Parameters

    /// Color saturation (0-1)
    public let colorSaturation: Float

    /// Brightness range (0-1)
    public let brightnessRange: ClosedRange<Float>

    /// Motion/animation intensity (0-1)
    public let motionIntensity: Float

    // MARK: - Light Parameters

    /// LED brightness (0-1)
    public let ledBrightness: Float

    /// Color change speed (0-1)
    public let colorChangeSpeed: Float

    // MARK: - Signal Processing

    /// Kalman filter process noise (for signal smoothing)
    public let kalmanProcessNoise: Float

    /// Kalman filter measurement noise
    public let kalmanMeasurementNoise: Float

    // MARK: - Methods

    /// Apply this mapping configuration to bio-data
    /// - Parameter bioData: Current biometric data
    /// - Returns: Mapped parameters for audio/visual/light systems
    public func apply(to bioData: BioData) -> MappedParameters {
        // Map HRV coherence (0-100) to each parameter range
        let coherenceNormalized = Float(bioData.hrvCoherence) / 100.0

        // Map heart rate (40-180 BPM) to normalized range
        let heartRateNormalized = Float((bioData.heartRate - 40.0) / 140.0)
        let heartRateClamped = max(0, min(1, heartRateNormalized))

        // Apply Kalman filtering for smoothness
        let smoothCoherence = kalmanFilter(
            coherenceNormalized,
            processNoise: kalmanProcessNoise,
            measurementNoise: kalmanMeasurementNoise
        )

        // Map to parameters
        return MappedParameters(
            // Audio
            filterCutoff: mapRange(smoothCoherence, to: filterCutoffRange),
            filterResonance: mapRange(smoothCoherence, to: filterResonanceRange),
            reverbWet: mapRange(smoothCoherence, to: reverbWetRange),
            amplitude: mapRange(heartRateClamped, to: amplitudeRange),
            tempo: mapRange(heartRateClamped, to: tempoRange),

            // Visual
            colorHue: Float(bioData.hrvCoherence) / 100.0,
            colorSaturation: colorSaturation,
            brightness: mapRange(smoothCoherence, to: brightnessRange),
            motionIntensity: motionIntensity,

            // Light
            ledBrightness: ledBrightness,
            ledColorHue: Float(bioData.hrvCoherence) / 100.0,
            colorChangeSpeed: colorChangeSpeed
        )
    }

    /// Map a normalized value (0-1) to a target range
    private func mapRange(_ value: Float, to range: ClosedRange<Float>) -> Float {
        return range.lowerBound + value * (range.upperBound - range.lowerBound)
    }

    /// Simple Kalman filter for signal smoothing
    private func kalmanFilter(_ value: Float, processNoise: Float, measurementNoise: Float) -> Float {
        // Simplified Kalman filter implementation
        // In production, maintain state between calls for proper filtering
        let kalmanGain = processNoise / (processNoise + measurementNoise)
        return value * kalmanGain + value * (1.0 - kalmanGain)
    }
}

/// Input bio-data for mapping
public struct BioData {
    public let hrvCoherence: Double
    public let heartRate: Double
    public let breathingRate: Double
    public let audioLevel: Float

    public init(hrvCoherence: Double, heartRate: Double, breathingRate: Double, audioLevel: Float) {
        self.hrvCoherence = hrvCoherence
        self.heartRate = heartRate
        self.breathingRate = breathingRate
        self.audioLevel = audioLevel
    }
}

/// Mapped output parameters
public struct MappedParameters {
    // Audio
    public let filterCutoff: Float
    public let filterResonance: Float
    public let reverbWet: Float
    public let amplitude: Float
    public let tempo: Float

    // Visual
    public let colorHue: Float
    public let colorSaturation: Float
    public let brightness: Float
    public let motionIntensity: Float

    // Light
    public let ledBrightness: Float
    public let ledColorHue: Float
    public let colorChangeSpeed: Float
}
