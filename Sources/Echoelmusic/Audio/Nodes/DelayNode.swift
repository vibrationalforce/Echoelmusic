#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Accelerate

/// Delay effect node with bio-reactive parameters
/// HRV → Delay Time (coherence creates rhythmic echoes)
/// Heart Rate → Feedback (tempo-synced repeats)
///
/// Implementation: Circular buffer delay line with one-pole LP in feedback path.
/// Supports up to 2 seconds at 96kHz (192k samples per channel).
///
/// EchoelCore Native - No external dependencies
@MainActor
class DelayNode: BaseEchoelmusicNode {

    // MARK: - Delay DSP State

    /// Maximum delay in seconds
    private let maxDelaySec: Double = 2.0

    /// Circular delay buffers per channel (pre-allocated)
    private var delayBuffers: [[Float]] = [[], []]

    /// Write position per channel
    private var writeIndex: [Int] = [0, 0]

    /// Current sample rate
    private var currentSampleRate: Double = 48000.0

    /// One-pole LP filter state per channel (for feedback damping)
    private var lpState: [Float] = [0.0, 0.0]


    // MARK: - Parameters

    private enum Params {
        static let delayTime = "delayTime"
        static let feedback = "feedback"
        static let wetDryMix = "wetDryMix"
        static let lowPassCutoff = "lowPassCutoff"
    }


    // MARK: - Initialization

    init() {
        super.init(name: "Bio-Reactive Delay", type: .effect)

        parameters = [
            NodeParameter(
                name: Params.delayTime,
                label: "Delay Time",
                value: 0.5,
                min: 0.01,
                max: 2.0,
                defaultValue: 0.5,
                unit: "s",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.feedback,
                label: "Feedback",
                value: 30.0,
                min: 0.0,
                max: 90.0,
                defaultValue: 30.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.wetDryMix,
                label: "Wet/Dry Mix",
                value: 30.0,
                min: 0.0,
                max: 100.0,
                defaultValue: 30.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.lowPassCutoff,
                label: "Low Pass Cutoff",
                value: 8000.0,
                min: 1000.0,
                max: 15000.0,
                defaultValue: 8000.0,
                unit: "Hz",
                isAutomatable: true,
                type: .continuous
            )
        ]

        allocateBuffers(sampleRate: 48000.0)
    }

    /// Pre-allocate delay buffers for maximum delay length.
    private func allocateBuffers(sampleRate: Double) {
        currentSampleRate = sampleRate
        let maxSamples = Int(sampleRate * maxDelaySec) + 1
        delayBuffers = [
            [Float](repeating: 0.0, count: maxSamples),
            [Float](repeating: 0.0, count: maxSamples)
        ]
        writeIndex = [0, 0]
        lpState = [0.0, 0.0]
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
        let channelCount = min(Int(buffer.format.channelCount), 2)

        let delayTimeSec = getParameter(name: Params.delayTime) ?? 0.5
        let feedbackPct = getParameter(name: Params.feedback) ?? 30.0
        let wetDryPct = getParameter(name: Params.wetDryMix) ?? 30.0
        let lpCutoff = getParameter(name: Params.lowPassCutoff) ?? 8000.0

        let feedbackGain = feedbackPct / 100.0
        let wetMix = wetDryPct / 100.0
        let dryMix = 1.0 - wetMix

        // One-pole LP coefficient: y = (1-a)*x + a*y_prev
        let omega = 2.0 * Float.pi * lpCutoff / Float(currentSampleRate)
        let lpCoeff = expf(-omega)

        let delaySamples = Int(delayTimeSec * Float(currentSampleRate))
        let bufferSize = delayBuffers[0].count

        guard delaySamples > 0, bufferSize > 0 else { return buffer }

        for ch in 0..<channelCount {
            let samples = channelData[ch]

            for frame in 0..<frameCount {
                let input = samples[frame]

                // Read from delay line (circular buffer)
                var readIdx = writeIndex[ch] - delaySamples
                if readIdx < 0 { readIdx += bufferSize }

                let delayed = delayBuffers[ch][readIdx]

                // One-pole LP on the delayed signal (feedback damping)
                lpState[ch] = delayed * (1.0 - lpCoeff) + lpState[ch] * lpCoeff

                // Write input + feedback into delay line
                delayBuffers[ch][writeIndex[ch]] = input + lpState[ch] * feedbackGain

                // Advance write pointer
                writeIndex[ch] = (writeIndex[ch] + 1) % bufferSize

                // Mix dry + wet
                samples[frame] = input * dryMix + delayed * wetMix
            }
        }

        return buffer
    }


    // MARK: - Bio-Reactivity

    override func react(to signal: BioSignal) {
        // Heart Rate → Delay Time (tempo-synced)
        // Convert BPM to delay time for rhythmic echoes
        // 60 BPM = 1.0s delay (quarter note)
        // 120 BPM = 0.5s delay

        let heartRate = signal.heartRate
        let bpm = max(40.0, min(120.0, heartRate))  // Clamp to reasonable range

        // Calculate quarter note duration in seconds
        let quarterNoteDuration = 60.0 / max(bpm, 20.0)

        // Use eighth note for delay (half of quarter)
        let targetDelayTime = Float(quarterNoteDuration / 2.0)  // Eighth note

        // Smooth transition
        if let currentDelay = getParameter(name: Params.delayTime) {
            let smoothed = currentDelay * 0.95 + targetDelayTime * 0.05
            setParameter(name: Params.delayTime, value: smoothed)
        }

        // HRV Coherence → Feedback Amount
        // Higher coherence = more repeats (creates rhythmic texture)
        let coherence = signal.coherence

        let targetFeedback: Float
        if coherence < 40 {
            // Low coherence: minimal feedback (10-30%)
            targetFeedback = 10.0 + Float(coherence / 40.0) * 20.0
        } else if coherence < 60 {
            // Medium coherence: moderate feedback (30-50%)
            targetFeedback = 30.0 + Float((coherence - 40.0) / 20.0) * 20.0
        } else {
            // High coherence: more feedback (50-70%)
            targetFeedback = 50.0 + Float((coherence - 60.0) / 40.0) * 20.0
        }

        if let currentFeedback = getParameter(name: Params.feedback) {
            let smoothed = currentFeedback * 0.98 + targetFeedback * 0.02
            setParameter(name: Params.feedback, value: smoothed)
        }

        // Audio Level → Wet/Dry Mix
        // More audio = more delay effect
        let audioLevel = signal.audioLevel
        let targetMix = 20.0 + Float(audioLevel) * 40.0  // 20-60%

        if let currentMix = getParameter(name: Params.wetDryMix) {
            let smoothed = currentMix * 0.9 + targetMix * 0.1
            setParameter(name: Params.wetDryMix, value: smoothed)
        }

        // HRV → Low Pass Cutoff (darker = more stressed)
        let targetCutoff = 4000.0 + Float(coherence / 100.0) * 8000.0  // 4-12kHz

        if let currentCutoff = getParameter(name: Params.lowPassCutoff) {
            let smoothed = currentCutoff * 0.95 + targetCutoff * 0.05
            setParameter(name: Params.lowPassCutoff, value: smoothed)
        }
    }


    // MARK: - Lifecycle

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        if abs(sampleRate - currentSampleRate) > 1.0 {
            allocateBuffers(sampleRate: sampleRate)
        }
    }

    override func start() {
        super.start()
        log.audio("DelayNode started (EchoelCore circular buffer)")
    }

    override func stop() {
        super.stop()
        log.audio("DelayNode stopped")
    }

    override func reset() {
        super.reset()
        for ch in 0..<delayBuffers.count {
            let count = delayBuffers[ch].count
            delayBuffers[ch].withUnsafeMutableBufferPointer { ptr in
                vDSP_vclr(ptr.baseAddress!, 1, vDSP_Length(count))
            }
            writeIndex[ch] = 0
            lpState[ch] = 0.0
        }
    }


    // MARK: - Tempo Sync Helpers

    /// Get delay time for musical subdivision
    func setTempoSyncedDelay(bpm: Double, subdivision: MusicalSubdivision) {
        let quarterNoteDuration = 60.0 / max(bpm, 20.0)
        let delayTime = Float(quarterNoteDuration * subdivision.multiplier)
        setParameter(name: Params.delayTime, value: delayTime)
    }

    enum MusicalSubdivision {
        case whole      // 4 beats
        case half       // 2 beats
        case quarter    // 1 beat
        case eighth     // 1/2 beat
        case sixteenth  // 1/4 beat
        case triplet    // 1/3 beat

        var multiplier: Double {
            switch self {
            case .whole: return 4.0
            case .half: return 2.0
            case .quarter: return 1.0
            case .eighth: return 0.5
            case .sixteenth: return 0.25
            case .triplet: return 1.0 / 3.0
            }
        }
    }
}
#endif
