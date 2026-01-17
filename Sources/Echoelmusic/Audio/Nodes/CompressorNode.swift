import Foundation
import AVFoundation
import Accelerate

/// Dynamic range compressor node with bio-reactive parameters
/// Respiratory Rate → Threshold (breath controls compression)
/// HRV → Attack/Release (coherence controls dynamics)
///
/// Implementation: Analog-style feed-forward compressor
/// Features: Peak/RMS detection, soft knee, attack/release smoothing
///
/// EchoelCore Native - No external dependencies
@MainActor
class CompressorNode: BaseEchoelmusicNode {

    // MARK: - Compressor DSP State

    /// Detection mode
    enum DetectionMode: String, CaseIterable {
        case peak = "Peak"
        case rms = "RMS"
    }

    /// Current detection mode
    private var detectionMode: DetectionMode = .peak

    /// Sample rate
    private var sampleRate: Double = 44100.0

    /// Envelope follower state (per channel)
    private var envelope: [Float] = [0.0, 0.0]

    /// Gain reduction in dB (for metering)
    private(set) var gainReduction: Float = 0.0

    /// RMS window buffer
    private var rmsBuffer: [[Float]] = [[], []]
    private var rmsIndex: Int = 0
    private let rmsWindowSize: Int = 128


    // MARK: - Parameters

    private enum Params {
        static let threshold = "threshold"
        static let ratio = "ratio"
        static let attack = "attack"
        static let release = "release"
        static let makeupGain = "makeupGain"
        static let knee = "knee"
    }


    // MARK: - Initialization

    init() {
        super.init(name: "Bio-Reactive Compressor", type: .effect)

        // Setup parameters
        parameters = [
            NodeParameter(
                name: Params.threshold,
                label: "Threshold",
                value: -20.0,
                min: -60.0,
                max: 0.0,
                defaultValue: -20.0,
                unit: "dB",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.ratio,
                label: "Ratio",
                value: 4.0,
                min: 1.0,
                max: 20.0,
                defaultValue: 4.0,
                unit: ":1",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.attack,
                label: "Attack Time",
                value: 10.0,
                min: 0.1,
                max: 200.0,
                defaultValue: 10.0,
                unit: "ms",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.release,
                label: "Release Time",
                value: 100.0,
                min: 10.0,
                max: 2000.0,
                defaultValue: 100.0,
                unit: "ms",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.makeupGain,
                label: "Makeup Gain",
                value: 0.0,
                min: 0.0,
                max: 30.0,
                defaultValue: 0.0,
                unit: "dB",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.knee,
                label: "Knee",
                value: 6.0,
                min: 0.0,
                max: 12.0,
                defaultValue: 6.0,
                unit: "dB",
                isAutomatable: true,
                type: .continuous
            )
        ]

        // Initialize RMS buffers
        rmsBuffer = [[Float](repeating: 0.0, count: rmsWindowSize),
                     [Float](repeating: 0.0, count: rmsWindowSize)]
    }


    // MARK: - Audio Processing

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard !isBypassed, isActive else {
            return buffer
        }

        guard let channelData = buffer.floatChannelData else {
            return buffer
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Get parameters
        let threshold = getParameter(name: Params.threshold) ?? -20.0
        let ratio = getParameter(name: Params.ratio) ?? 4.0
        let attackMs = getParameter(name: Params.attack) ?? 10.0
        let releaseMs = getParameter(name: Params.release) ?? 100.0
        let makeupGaindB = getParameter(name: Params.makeupGain) ?? 0.0
        let kneedB = getParameter(name: Params.knee) ?? 6.0

        // Calculate attack/release coefficients
        let attackCoeff = exp(-1.0 / (Float(sampleRate) * attackMs / 1000.0))
        let releaseCoeff = exp(-1.0 / (Float(sampleRate) * releaseMs / 1000.0))

        // Makeup gain in linear
        let makeupGainLinear = powf(10.0, makeupGaindB / 20.0)

        // Track gain reduction for metering
        var maxGainReduction: Float = 0.0

        // Process each channel
        for channel in 0..<min(channelCount, 2) {
            let samples = channelData[channel]

            for frame in 0..<frameCount {
                let input = samples[frame]

                // Detect level
                var detectedLevel: Float
                switch detectionMode {
                case .peak:
                    detectedLevel = abs(input)
                case .rms:
                    // Update RMS buffer
                    rmsBuffer[channel][rmsIndex % rmsWindowSize] = input * input
                    var sum: Float = 0.0
                    vDSP_sve(rmsBuffer[channel], 1, &sum, vDSP_Length(rmsWindowSize))
                    detectedLevel = sqrt(sum / Float(rmsWindowSize))
                }

                // Convert to dB
                let inputdB = 20.0 * log10(max(detectedLevel, 1e-10))

                // Envelope follower (smooth the detection)
                let coeff = detectedLevel > envelope[channel] ? attackCoeff : releaseCoeff
                envelope[channel] = coeff * envelope[channel] + (1.0 - coeff) * detectedLevel

                // Convert envelope to dB
                let envelopedB = 20.0 * log10(max(envelope[channel], 1e-10))

                // Calculate gain reduction with soft knee
                var gainReductiondB: Float = 0.0

                if kneedB > 0 && envelopedB > (threshold - kneedB / 2) && envelopedB < (threshold + kneedB / 2) {
                    // In the knee region - soft knee compression
                    let x = envelopedB - threshold + kneedB / 2
                    gainReductiondB = (1.0 / ratio - 1.0) * x * x / (2.0 * kneedB)
                } else if envelopedB > threshold {
                    // Above threshold - full compression
                    let excess = envelopedB - threshold
                    gainReductiondB = excess * (1.0 / ratio - 1.0)
                }

                // Track maximum gain reduction for metering
                maxGainReduction = min(maxGainReduction, gainReductiondB)

                // Convert gain reduction to linear and apply
                let gainLinear = powf(10.0, gainReductiondB / 20.0) * makeupGainLinear

                // Apply gain
                samples[frame] = input * gainLinear
            }
        }

        // Update RMS index
        rmsIndex += frameCount

        // Store gain reduction for UI metering
        gainReduction = maxGainReduction

        return buffer
    }


    // MARK: - Bio-Reactivity

    override func react(to signal: BioSignal) {
        // Respiratory Rate → Threshold
        // Slow breathing (4-6 BPM): High threshold (less compression) -10 dB
        // Normal breathing (12-20 BPM): Medium threshold -20 dB
        // Fast breathing (>20 BPM): Low threshold (more compression) -30 dB

        if let respiratoryRate = signal.respiratoryRate {
            let targetThreshold: Float
            if respiratoryRate < 8 {
                // Slow breathing: less compression (calming)
                targetThreshold = -10.0
            } else if respiratoryRate < 16 {
                // Normal breathing: balanced
                targetThreshold = -20.0
            } else {
                // Fast breathing: more compression (control dynamics)
                targetThreshold = -30.0
            }

            // Smooth transition
            if let currentThreshold = getParameter(name: Params.threshold) {
                let smoothed = currentThreshold * 0.98 + targetThreshold * 0.02
                setParameter(name: Params.threshold, value: smoothed)
            }
        }

        // HRV Coherence → Attack/Release Times
        // Higher coherence = slower, more musical dynamics
        let coherence = signal.coherence

        // Attack: 5ms (fast) to 50ms (slow)
        let targetAttack = 5.0 + Float(coherence / 100.0) * 45.0
        if let currentAttack = getParameter(name: Params.attack) {
            let smoothed = currentAttack * 0.95 + targetAttack * 0.05
            setParameter(name: Params.attack, value: smoothed)
        }

        // Release: 50ms to 300ms
        let targetRelease = 50.0 + Float(coherence / 100.0) * 250.0
        if let currentRelease = getParameter(name: Params.release) {
            let smoothed = currentRelease * 0.95 + targetRelease * 0.05
            setParameter(name: Params.release, value: smoothed)
        }

        // Heart Rate → Ratio (higher HR = more aggressive compression)
        let heartRate = signal.heartRate
        let normalizedHR = Float(min(max((heartRate - 60.0) / 60.0, 0.0), 1.0))
        let targetRatio = 2.0 + normalizedHR * 6.0  // 2:1 to 8:1
        if let currentRatio = getParameter(name: Params.ratio) {
            let smoothed = currentRatio * 0.97 + targetRatio * 0.03
            setParameter(name: Params.ratio, value: smoothed)
        }
    }


    // MARK: - Lifecycle

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        self.sampleRate = sampleRate
    }

    override func start() {
        super.start()
        log.audio("🎵 CompressorNode started (EchoelCore Dynamics, \(detectionMode.rawValue) mode)")
    }

    override func stop() {
        super.stop()
        log.audio("🎵 CompressorNode stopped")
    }

    override func reset() {
        super.reset()
        envelope = [0.0, 0.0]
        gainReduction = 0.0
        rmsBuffer = [[Float](repeating: 0.0, count: rmsWindowSize),
                     [Float](repeating: 0.0, count: rmsWindowSize)]
        rmsIndex = 0
    }


    // MARK: - Detection Mode

    /// Set detection mode (peak or RMS)
    func setDetectionMode(_ mode: DetectionMode) {
        detectionMode = mode
        log.audio("🎵 CompressorNode detection mode: \(mode.rawValue)")
    }

    /// Get current detection mode
    func getDetectionMode() -> DetectionMode {
        return detectionMode
    }
}
