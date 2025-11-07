import Foundation
import Combine

/// Protocol for all parameter mapping systems in BLAB
/// Provides unified interface for converting input signals to output parameters
protocol ParameterMapper: AnyObject, ObservableObject {

    /// Input type for this mapper
    associatedtype Input

    /// Output type for this mapper
    associatedtype Output

    /// Current output parameters (published for reactive updates)
    var currentOutput: Output { get }

    /// Map input to output
    /// - Parameter input: Input signal/data
    /// - Returns: Mapped output parameters
    func map(_ input: Input) -> Output

    /// Reset mapper to default state
    func reset()
}

/// Common bio-signal parameters shared across all mappers
struct BioSignals: Codable, Equatable {
    /// HRV coherence score (0-100)
    var hrvCoherence: Double

    /// Heart rate in BPM
    var heartRate: Double

    /// Breathing rate in breaths/minute
    var breathingRate: Double

    /// Audio level (0.0-1.0)
    var audioLevel: Float

    /// Voice pitch in Hz
    var voicePitch: Float

    /// Initialize with default values
    init(
        hrvCoherence: Double = 50.0,
        heartRate: Double = 70.0,
        breathingRate: Double = 12.0,
        audioLevel: Float = 0.5,
        voicePitch: Float = 0.0
    ) {
        self.hrvCoherence = hrvCoherence
        self.heartRate = heartRate
        self.breathingRate = breathingRate
        self.audioLevel = audioLevel
        self.voicePitch = voicePitch
    }
}

/// Common audio parameters shared across mappers
struct AudioParameters: Codable, Equatable {
    /// Filter cutoff frequency (20-20000 Hz)
    var filterCutoff: Float

    /// Filter resonance (0.1-10.0)
    var filterResonance: Float

    /// Reverb wetness (0.0-1.0)
    var reverbWet: Float

    /// Master amplitude (0.0-1.0)
    var amplitude: Float

    /// Tempo in BPM (40-200)
    var tempo: Float

    /// Initialize with default values
    init(
        filterCutoff: Float = 1000.0,
        filterResonance: Float = 1.0,
        reverbWet: Float = 0.3,
        amplitude: Float = 0.7,
        tempo: Float = 120.0
    ) {
        self.filterCutoff = filterCutoff
        self.filterResonance = filterResonance
        self.reverbWet = reverbWet
        self.amplitude = amplitude
        self.tempo = tempo
    }
}

/// Common visual parameters shared across mappers
struct VisualParameters: Codable, Equatable {
    /// Hue (0.0-1.0)
    var hue: Float

    /// Saturation (0.0-1.0)
    var saturation: Float

    /// Brightness (0.0-1.0)
    var brightness: Float

    /// Particle count (100-10000)
    var particleCount: Int

    /// Animation speed (0.1-5.0)
    var animationSpeed: Float

    /// Initialize with default values
    init(
        hue: Float = 0.5,
        saturation: Float = 0.8,
        brightness: Float = 0.7,
        particleCount: Int = 1000,
        animationSpeed: Float = 1.0
    ) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.particleCount = particleCount
        self.animationSpeed = animationSpeed
    }
}

/// Extension for convenient value mapping
extension ParameterMapper {

    /// Map value from one range to another with optional smoothing
    /// - Parameters:
    ///   - value: Input value
    ///   - fromLow: Input range minimum
    ///   - fromHigh: Input range maximum
    ///   - toLow: Output range minimum
    ///   - toHigh: Output range maximum
    ///   - smooth: Smoothing factor (0.0 = no smoothing, 1.0 = maximum smoothing)
    /// - Returns: Mapped and optionally smoothed value
    func mapRange<T: FloatingPoint>(
        _ value: T,
        from fromLow: T,
        to fromHigh: T,
        toLow: T,
        toHigh: T,
        smooth: T = 0.0
    ) -> T {
        // Clamp input to valid range
        let clampedValue = min(max(value, fromLow), fromHigh)

        // Linear interpolation
        let normalized = (clampedValue - fromLow) / (fromHigh - fromLow)
        let mapped = normalized * (toHigh - toLow) + toLow

        // Apply smoothing (exponential moving average)
        // In real implementation, this would use previous value
        // For now, just return mapped value
        return mapped
    }

    /// Map value with exponential curve
    /// - Parameters:
    ///   - value: Input value (0.0-1.0)
    ///   - exponent: Curve exponent (1.0 = linear, <1.0 = ease-in, >1.0 = ease-out)
    /// - Returns: Exponentially curved value
    func exponentialMap<T: FloatingPoint>(_ value: T, exponent: T) -> T {
        let clamped = min(max(value, 0), 1)
        return pow(clamped, exponent)
    }
}
