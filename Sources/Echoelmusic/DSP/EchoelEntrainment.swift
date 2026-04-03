import Foundation

/// Brainwave frequency bands for isochronic entrainment
public enum BrainwaveBand: String, CaseIterable, Sendable {
    case delta = "Delta"     // 0.5-4 Hz — deep sleep
    case theta = "Theta"     // 4-8 Hz — meditation, REM
    case alpha = "Alpha"     // 8-13 Hz — relaxed focus
    case beta  = "Beta"      // 13-30 Hz — alert, active
    case gamma = "Gamma"     // 30-50 Hz — peak cognition

    /// Center frequency of the band
    public var centerFrequency: Float {
        switch self {
        case .delta: return 2.0
        case .theta: return 6.0
        case .alpha: return 10.0
        case .beta:  return 20.0
        case .gamma: return 40.0
        }
    }

    /// Human-readable description
    public var stateDescription: String {
        switch self {
        case .delta: return "Deep Sleep"
        case .theta: return "Meditation"
        case .alpha: return "Relaxed Focus"
        case .beta:  return "Alert"
        case .gamma: return "Peak Flow"
        }
    }
}

/// Isochronic brainwave entrainment processor.
/// Applies rhythmic amplitude modulation at brainwave frequencies.
///
/// Unlike binaural beats (headphones only), isochronic tones work
/// through any speaker — they modulate the amplitude of the carrier
/// signal at the target brainwave frequency.
///
/// Audio-thread safe — no allocation.
public final class EchoelEntrainment: @unchecked Sendable {

    // MARK: - Parameters

    /// Target brainwave band
    public var band: BrainwaveBand = .alpha

    /// Entrainment depth [0-1] (0 = off, 1 = full pulse)
    public var depth: Float = 0.0

    /// Whether entrainment is active
    public var isActive: Bool { depth > 0.01 }

    // MARK: - State

    private var phase: Float = 0
    private var sampleRate: Float

    // MARK: - Init

    public init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    // MARK: - Process

    /// Process a single sample with isochronic amplitude modulation.
    /// Audio-thread safe — no allocation.
    @inline(__always)
    public func process(_ sample: Float) -> Float {
        guard depth > 0.01 else { return sample }

        // Advance phase at brainwave frequency
        phase += band.centerFrequency / sampleRate
        if phase >= 1.0 { phase -= 1.0 }

        // Smooth isochronic pulse: raised cosine envelope
        // Sounds smoother than a hard on/off square pulse
        let envelope = (1.0 + cosf(phase * Float.pi * 2)) * 0.5  // 0→1→0 per cycle

        // Modulate amplitude: full signal at peak, reduced at trough
        let modulation = 1.0 - depth + depth * envelope
        return sample * modulation
    }

    /// Process a buffer in-place
    public func processBuffer(_ buffer: inout [Float], frameCount: Int) {
        guard depth > 0.01 else { return }
        for i in 0..<frameCount {
            buffer[i] = process(buffer[i])
        }
    }

    /// Reset phase
    public func reset() {
        phase = 0
    }
}
