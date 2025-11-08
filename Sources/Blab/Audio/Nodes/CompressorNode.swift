import Foundation
import AVFoundation

/// Dynamic range compressor node with bio-reactive parameters
/// Respiratory Rate → Threshold (breath controls compression)
/// HRV → Attack/Release (coherence controls dynamics)
@MainActor
class CompressorNode: BaseBlabNode {

    // MARK: - AVAudioUnit Compressor

    private let compressorUnit: AVAudioUnitEffect

    // MARK: - DSP State

    // Envelope follower state (per channel)
    private var envelope: [Float] = [0.0, 0.0]
    private var currentSampleRate: Double = 44100.0

    // MARK: - Parameters

    private enum Params {
        static let threshold = "threshold"
        static let ratio = "ratio"
        static let attack = "attack"
        static let release = "release"
        static let makeupGain = "makeupGain"
    }


    // MARK: - Initialization

    init() {
        // Create dynamics processor (compressor)
        let componentDescription = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )

        self.compressorUnit = AVAudioUnitEffect(audioComponentDescription: componentDescription)

        super.init(name: "Bio-Reactive Compressor", type: .effect)

        // Setup parameters
        parameters = [
            NodeParameter(
                name: Params.threshold,
                label: "Threshold",
                value: -20.0,
                min: -40.0,
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
                max: 100.0,
                defaultValue: 10.0,
                unit: "ms",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.release,
                label: "Release Time",
                value: 50.0,
                min: 10.0,
                max: 500.0,
                defaultValue: 50.0,
                unit: "ms",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.makeupGain,
                label: "Makeup Gain",
                value: 0.0,
                min: 0.0,
                max: 20.0,
                defaultValue: 0.0,
                unit: "dB",
                isAutomatable: true,
                type: .continuous
            )
        ]

        // Configure compressor
        configureCompressor()
    }

    private func configureCompressor() {
        // Set initial parameters via Audio Unit parameters
        // Parameter IDs from Apple's DynamicsProcessor documentation
        let kDynamicsProcessorParam_Threshold: AudioUnitParameterID = 0
        let kDynamicsProcessorParam_HeadRoom: AudioUnitParameterID = 1
        let kDynamicsProcessorParam_ExpansionRatio: AudioUnitParameterID = 2
        let kDynamicsProcessorParam_ExpansionThreshold: AudioUnitParameterID = 3
        let kDynamicsProcessorParam_AttackTime: AudioUnitParameterID = 4
        let kDynamicsProcessorParam_ReleaseTime: AudioUnitParameterID = 5
        let kDynamicsProcessorParam_MasterGain: AudioUnitParameterID = 6
        let kDynamicsProcessorParam_CompressionAmount: AudioUnitParameterID = 1000
        let kDynamicsProcessorParam_InputAmplitude: AudioUnitParameterID = 2000
        let kDynamicsProcessorParam_OutputAmplitude: AudioUnitParameterID = 3000

        // Note: In production, we'd set these via the Audio Unit's parameter tree
        // For now, this is architectural placeholder
    }


    // MARK: - Audio Processing

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard !isBypassed, isActive else {
            return buffer
        }

        // Get compressor parameters
        guard let threshold = getParameter(name: Params.threshold),
              let ratio = getParameter(name: Params.ratio),
              let attackTime = getParameter(name: Params.attack),
              let releaseTime = getParameter(name: Params.release),
              let makeupGain = getParameter(name: Params.makeupGain) else {
            return buffer
        }

        // Process audio buffer (in-place)
        guard let channelData = buffer.floatChannelData else {
            return buffer
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        // Convert dB to linear
        let thresholdLin = dBToLinear(threshold)
        let makeupGainLin = dBToLinear(makeupGain)

        // Calculate attack/release coefficients
        let attackCoeff = exp(-1.0 / (Float(currentSampleRate) * attackTime * 0.001))  // ms to seconds
        let releaseCoeff = exp(-1.0 / (Float(currentSampleRate) * releaseTime * 0.001))

        for channel in 0..<min(channelCount, 2) {
            let channelDataPtr = channelData[channel]

            for frame in 0..<frameLength {
                let input = channelDataPtr[frame]
                let inputAbs = abs(input)

                // Envelope follower (peak detector)
                if inputAbs > envelope[channel] {
                    // Attack
                    envelope[channel] = attackCoeff * envelope[channel] + (1.0 - attackCoeff) * inputAbs
                } else {
                    // Release
                    envelope[channel] = releaseCoeff * envelope[channel] + (1.0 - releaseCoeff) * inputAbs
                }

                // Calculate gain reduction
                var gainReduction: Float = 1.0
                if envelope[channel] > thresholdLin {
                    // Compression above threshold
                    let overThreshold = envelope[channel] / thresholdLin
                    let compressed = pow(overThreshold, 1.0 / ratio)
                    gainReduction = compressed / overThreshold
                }

                // Apply gain reduction and makeup gain
                let output = input * gainReduction * makeupGainLin

                // Write output
                channelDataPtr[frame] = output
            }
        }

        return buffer
    }

    /// Convert dB to linear gain
    private func dBToLinear(_ dB: Float) -> Float {
        return pow(10.0, dB / 20.0)
    }

    /// Convert linear gain to dB
    private func linearTodB(_ linear: Float) -> Float {
        return 20.0 * log10(max(linear, 0.00001))
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

        // Release: 50ms to 200ms
        let targetRelease = 50.0 + Float(coherence / 100.0) * 150.0
        if let currentRelease = getParameter(name: Params.release) {
            let smoothed = currentRelease * 0.95 + targetRelease * 0.05
            setParameter(name: Params.release, value: smoothed)
        }

        // Audio Level → Makeup Gain (compensate for compression)
        let audioLevel = signal.audioLevel
        let targetMakeup = Float(audioLevel) * 10.0  // 0-10 dB
        if let currentMakeup = getParameter(name: Params.makeupGain) {
            let smoothed = currentMakeup * 0.9 + targetMakeup * 0.1
            setParameter(name: Params.makeupGain, value: smoothed)
        }
    }


    // MARK: - Lifecycle

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        currentSampleRate = sampleRate

        // Reset envelope state
        envelope = [0.0, 0.0]

        print("🎵 CompressorNode prepared")
    }

    override func start() {
        super.start()
        print("🎵 CompressorNode started")
    }

    override func stop() {
        super.stop()
        print("🎵 CompressorNode stopped")
    }
}
