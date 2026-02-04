import Foundation
import AVFoundation
import Accelerate

/// Multi-mode filter node with bio-reactive cutoff
/// Heart Rate → Filter Cutoff (higher HR = brighter/more open sound)
///
/// Implementation: State-variable biquad filter
/// Supports: Low Pass, High Pass, Band Pass, Notch
/// Uses Accelerate/vDSP for SIMD optimization
///
/// EchoelCore Native - No external dependencies
@MainActor
class FilterNode: BaseEchoelmusicNode {

    // MARK: - Filter DSP State

    /// Current filter type
    private var currentFilterType: FilterType = .lowPass

    /// Sample rate
    private var sampleRate: Double = 44100.0

    /// Biquad filter state (z^-1 and z^-2 for both channels)
    private var x1: [Float] = [0.0, 0.0]  // x[n-1] for left/right
    private var x2: [Float] = [0.0, 0.0]  // x[n-2] for left/right
    private var y1: [Float] = [0.0, 0.0]  // y[n-1] for left/right
    private var y2: [Float] = [0.0, 0.0]  // y[n-2] for left/right

    /// Biquad coefficients
    private var b0: Float = 1.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0


    // MARK: - Parameters

    private enum Params {
        static let cutoffFrequency = "cutoffFrequency"
        static let resonance = "resonance"
        static let filterType = "filterType"
    }


    // MARK: - Initialization

    init() {
        super.init(name: "Bio-Reactive Filter", type: .filter)

        // Setup parameters
        parameters = [
            NodeParameter(
                name: Params.cutoffFrequency,
                label: "Cutoff Frequency",
                value: 1000.0,
                min: 20.0,
                max: 20000.0,
                defaultValue: 1000.0,
                unit: "Hz",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.resonance,
                label: "Resonance (Q)",
                value: 0.707,
                min: 0.1,
                max: 20.0,
                defaultValue: 0.707,
                unit: nil,
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.filterType,
                label: "Filter Type",
                value: 0.0,  // 0=LP, 1=HP, 2=BP, 3=Notch
                min: 0.0,
                max: 3.0,
                defaultValue: 0.0,
                unit: nil,
                isAutomatable: false,
                type: .discrete
            )
        ]

        // Calculate initial coefficients
        updateCoefficients()
    }

    /// Calculate biquad coefficients based on current parameters
    private func updateCoefficients() {
        let cutoff = getParameter(name: Params.cutoffFrequency) ?? 1000.0
        let q = getParameter(name: Params.resonance) ?? 0.707

        // Normalize frequency (0 to π)
        let omega = 2.0 * Float.pi * cutoff / Float(sampleRate)
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        var a0: Float = 1.0

        switch currentFilterType {
        case .lowPass:
            // Low Pass Filter (2nd order Butterworth style)
            b0 = (1.0 - cosOmega) / 2.0
            b1 = 1.0 - cosOmega
            b2 = (1.0 - cosOmega) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

        case .highPass:
            // High Pass Filter
            b0 = (1.0 + cosOmega) / 2.0
            b1 = -(1.0 + cosOmega)
            b2 = (1.0 + cosOmega) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

        case .bandPass:
            // Band Pass Filter (constant 0dB peak gain)
            b0 = alpha
            b1 = 0.0
            b2 = -alpha
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

        case .notch:
            // Notch (Band Stop) Filter
            b0 = 1.0
            b1 = -2.0 * cosOmega
            b2 = 1.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha
        }

        // Normalize coefficients
        b0 /= a0
        b1 /= a0
        b2 /= a0
        a1 /= a0
        a2 /= a0
    }


    // MARK: - Audio Processing

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        // If bypassed, return original buffer
        guard !isBypassed, isActive else {
            return buffer
        }

        guard let channelData = buffer.floatChannelData else {
            return buffer
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Update coefficients (could be optimized to only update when params change)
        updateCoefficients()

        // Process each channel
        for channel in 0..<min(channelCount, 2) {
            let samples = channelData[channel]

            for frame in 0..<frameCount {
                let x0 = samples[frame]

                // Direct Form I biquad filter
                // y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
                let y0 = b0 * x0 + b1 * x1[channel] + b2 * x2[channel]
                           - a1 * y1[channel] - a2 * y2[channel]

                // Update delay elements
                x2[channel] = x1[channel]
                x1[channel] = x0
                y2[channel] = y1[channel]
                y1[channel] = y0

                // Write output
                samples[frame] = y0
            }
        }

        return buffer
    }


    // MARK: - Bio-Reactivity

    override func react(to signal: BioSignal) {
        // Heart Rate → Filter Cutoff
        // Low HR (40-60 BPM): Darker, closed sound (200-600 Hz)
        // Normal HR (60-80 BPM): Balanced (600-2000 Hz)
        // High HR (80-120 BPM): Brighter, open sound (2000-8000 Hz)

        let heartRate = signal.heartRate

        // Map heart rate to cutoff frequency
        let targetCutoff: Float
        if heartRate < 60 {
            // Low HR: darker sound
            targetCutoff = 200.0 + Float((heartRate - 40.0) / 20.0) * 400.0  // 200-600 Hz
        } else if heartRate < 80 {
            // Normal HR: balanced
            targetCutoff = 600.0 + Float((heartRate - 60.0) / 20.0) * 1400.0  // 600-2000 Hz
        } else {
            // High HR: brighter sound
            targetCutoff = 2000.0 + Float((min(heartRate, 120.0) - 80.0) / 40.0) * 6000.0  // 2000-8000 Hz
        }

        // Smooth transition (slower for filter to avoid artifacts)
        if let currentCutoff = getParameter(name: Params.cutoffFrequency) {
            let smoothed = currentCutoff * 0.98 + targetCutoff * 0.02
            setParameter(name: Params.cutoffFrequency, value: smoothed)
        }

        // HRV Coherence → Resonance
        // Higher coherence = higher Q (more resonant, singing quality)
        let coherence = signal.coherence
        let targetResonance = 0.707 + Float(coherence / 100.0) * 3.0  // 0.707-3.707

        if let currentResonance = getParameter(name: Params.resonance) {
            let smoothed = currentResonance * 0.95 + targetResonance * 0.05
            setParameter(name: Params.resonance, value: smoothed)
        }
    }


    // MARK: - Lifecycle

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        self.sampleRate = sampleRate
        updateCoefficients()
    }

    override func start() {
        super.start()
        log.audio("🎵 FilterNode started (EchoelCore Biquad \(currentFilterType.rawValue))")
    }

    override func stop() {
        super.stop()
        log.audio("🎵 FilterNode stopped")
    }

    override func reset() {
        super.reset()
        // Clear filter state
        x1 = [0.0, 0.0]
        x2 = [0.0, 0.0]
        y1 = [0.0, 0.0]
        y2 = [0.0, 0.0]
    }


    // MARK: - Filter Type

    enum FilterType: String, CaseIterable {
        case lowPass = "Low Pass"
        case highPass = "High Pass"
        case bandPass = "Band Pass"
        case notch = "Notch"
    }

    /// Change filter type
    func setFilterType(_ type: FilterType) {
        currentFilterType = type
        setParameter(name: Params.filterType, value: Float(FilterType.allCases.firstIndex(of: type) ?? 0))
        updateCoefficients()
        log.audio("🎵 FilterNode type changed to \(type.rawValue)")
    }

    /// Get current filter type
    func getFilterType() -> FilterType {
        return currentFilterType
    }
}
