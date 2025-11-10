import Foundation
import AVFoundation
import Accelerate

/// Therapeutic Audio Engine
/// Generates therapeutic sounds for healing, meditation, and brainwave entrainment
/// Includes: Binaural beats, Isochronic tones, Solfeggio frequencies, Sound therapy
@MainActor
class TherapeuticAudioEngine: ObservableObject {

    // MARK: - Audio Components

    private let audioEngine = AVAudioEngine()
    private let sampleRate: Double = 48000
    private var playerNodes: [AVAudioPlayerNode] = []

    // MARK: - Published State

    @Published var currentTherapy: TherapyType = .binauralBeats(.alpha)
    @Published var isPlaying = false
    @Published var volume: Float = 0.5

    // MARK: - Therapy Types

    enum TherapyType {
        case binauralBeats(BrainwaveState)
        case isochronicTones(BrainwaveState)
        case solfeggioFrequency(SolfeggioFrequency)
        case colorNoise(NoiseColor)
        case tibetanSingingBowl
        case crystalBowl(note: String)
        case natureSound(NatureSound)

        var description: String {
            switch self {
            case .binauralBeats(let state):
                return "Binaural Beats (\(state.rawValue))"
            case .isochronicTones(let state):
                return "Isochronic Tones (\(state.rawValue))"
            case .solfeggioFrequency(let freq):
                return "Solfeggio Frequency (\(freq.rawValue))"
            case .colorNoise(let color):
                return "\(color.rawValue) Noise"
            case .tibetanSingingBowl:
                return "Tibetan Singing Bowl"
            case .crystalBowl(let note):
                return "Crystal Bowl (\(note))"
            case .natureSound(let sound):
                return "Nature Sound (\(sound.rawValue))"
            }
        }
    }

    // MARK: - Brainwave States

    enum BrainwaveState: String, CaseIterable {
        case delta = "Delta (0.5-4 Hz)"    // Deep sleep, healing, regeneration
        case theta = "Theta (4-8 Hz)"      // Meditation, creativity, deep relaxation
        case alpha = "Alpha (8-14 Hz)"     // Relaxation, learning, light meditation
        case beta = "Beta (14-30 Hz)"      // Focus, alertness, active thinking
        case gamma = "Gamma (30-100 Hz)"   // Peak performance, insight, flow state

        var frequency: Float {
            switch self {
            case .delta: return 2.0    // 2 Hz (center of delta range)
            case .theta: return 6.0    // 6 Hz (center of theta range)
            case .alpha: return 10.0   // 10 Hz (optimal alpha)
            case .beta: return 20.0    // 20 Hz (focus frequency)
            case .gamma: return 40.0   // 40 Hz (gamma wave)
            }
        }

        var benefits: String {
            switch self {
            case .delta:
                return "Deep sleep, physical healing, immune system boost, pain relief"
            case .theta:
                return "Deep meditation, creativity, intuition, emotional healing"
            case .alpha:
                return "Relaxation, stress reduction, learning enhancement, positive thinking"
            case .beta:
                return "Focus, concentration, problem-solving, active learning"
            case .gamma:
                return "Peak performance, heightened perception, cognitive enhancement"
            }
        }

        var recommendedDuration: TimeInterval {
            switch self {
            case .delta: return 60 * 60  // 60 minutes for sleep
            case .theta: return 30 * 60  // 30 minutes for meditation
            case .alpha: return 20 * 60  // 20 minutes for relaxation
            case .beta: return 45 * 60   // 45 minutes for focus
            case .gamma: return 15 * 60  // 15 minutes for peak performance
            }
        }
    }

    // MARK: - Solfeggio Frequencies

    enum SolfeggioFrequency: String, CaseIterable {
        case ut174Hz = "174 Hz"     // Pain relief, grounding
        case re285Hz = "285 Hz"     // Tissue healing, cellular regeneration
        case mi396Hz = "396 Hz"     // Liberation from fear and guilt
        case fa417Hz = "417 Hz"     // Facilitating change, undoing situations
        case sol528Hz = "528 Hz"    // DNA repair, love frequency, miracles
        case la639Hz = "639 Hz"     // Harmonious relationships, connection
        case ti741Hz = "741 Hz"     // Awakening intuition, expression
        case sol852Hz = "852 Hz"    // Spiritual order, third eye activation
        case om963Hz = "963 Hz"     // Divine consciousness, pineal gland activation

        var frequency: Float {
            switch self {
            case .ut174Hz: return 174.0
            case .re285Hz: return 285.0
            case .mi396Hz: return 396.0
            case .fa417Hz: return 417.0
            case .sol528Hz: return 528.0
            case .la639Hz: return 639.0
            case .ti741Hz: return 741.0
            case .sol852Hz: return 852.0
            case .om963Hz: return 963.0
            }
        }

        var benefits: String {
            switch self {
            case .ut174Hz:
                return "Pain relief, physical grounding, security"
            case .re285Hz:
                return "Tissue healing, cellular regeneration, wounds"
            case .mi396Hz:
                return "Release fear, guilt, trauma"
            case .fa417Hz:
                return "Facilitate change, clear negative energy"
            case .sol528Hz:
                return "DNA repair, love, transformation, miracles"
            case .la639Hz:
                return "Harmonious relationships, empathy, communication"
            case .ti741Hz:
                return "Expression, intuition, creative solutions"
            case .sol852Hz:
                return "Spiritual awakening, intuition, third eye"
            case .om963Hz:
                return "Divine connection, pineal gland activation, oneness"
            }
        }
    }

    // MARK: - Noise Colors

    enum NoiseColor: String, CaseIterable {
        case white = "White"    // All frequencies equal (hiss)
        case pink = "Pink"      // Lower frequencies louder (natural)
        case brown = "Brown"    // Even lower frequencies (rumble)
        case blue = "Blue"      // Higher frequencies louder
        case violet = "Violet"  // Highest frequencies emphasized

        var description: String {
            switch self {
            case .white: return "White noise (masking, sleep)"
            case .pink: return "Pink noise (natural, calming)"
            case .brown: return "Brown noise (deep relaxation)"
            case .blue: return "Blue noise (focus, concentration)"
            case .violet: return "Violet noise (high-frequency stimulation)"
            }
        }
    }

    // MARK: - Nature Sounds

    enum NatureSound: String, CaseIterable {
        case ocean = "Ocean Waves"
        case rain = "Rain"
        case thunder = "Thunderstorm"
        case forest = "Forest Ambience"
        case birds = "Bird Songs"
        case stream = "Flowing Stream"
        case wind = "Wind in Trees"
        case fire = "Crackling Fire"
    }

    // MARK: - Sound Generation

    /// Generate binaural beats
    /// Left ear: base frequency
    /// Right ear: base + target brainwave frequency
    /// Brain perceives the difference as the target frequency
    func generateBinauralBeats(targetState: BrainwaveState, baseFrequency: Float = 200.0) -> AVAudioPCMBuffer {
        let targetFrequency = targetState.frequency
        let leftFreq = baseFrequency                    // e.g., 200 Hz
        let rightFreq = baseFrequency + targetFrequency // e.g., 210 Hz for 10 Hz alpha

        print("🎧 Generating Binaural Beats:")
        print("   Target: \(targetState.rawValue) (\(targetFrequency) Hz)")
        print("   Left ear: \(leftFreq) Hz")
        print("   Right ear: \(rightFreq) Hz")
        print("   Perceived: \(targetFrequency) Hz")

        let duration: Float = 60.0  // 60 seconds
        let frameCount = AVAudioFrameCount(sampleRate * Double(duration))

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return buffer
        }

        // Generate sine waves
        for i in 0..<Int(frameCount) {
            let time = Float(i) / Float(sampleRate)

            // Left ear: base frequency
            leftChannel[i] = sin(2.0 * .pi * leftFreq * time)

            // Right ear: base + difference frequency
            rightChannel[i] = sin(2.0 * .pi * rightFreq * time)
        }

        return buffer
    }

    /// Generate isochronic tones
    /// Pulsing tones at target frequency (works without headphones)
    func generateIsochronicTones(targetState: BrainwaveState, carrierFrequency: Float = 200.0) -> AVAudioPCMBuffer {
        let targetFrequency = targetState.frequency

        print("🔊 Generating Isochronic Tones:")
        print("   Target: \(targetState.rawValue) (\(targetFrequency) Hz)")
        print("   Carrier: \(carrierFrequency) Hz")
        print("   Pulse rate: \(targetFrequency) Hz")

        let duration: Float = 60.0
        let frameCount = AVAudioFrameCount(sampleRate * Double(duration))

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return buffer
        }

        // Generate carrier tone with amplitude modulation
        for i in 0..<Int(frameCount) {
            let time = Float(i) / Float(sampleRate)

            // Carrier tone
            let carrier = sin(2.0 * .pi * carrierFrequency * time)

            // Pulse modulator (square wave at target frequency)
            let pulse = sin(2.0 * .pi * targetFrequency * time) > 0 ? Float(1.0) : Float(0.0)

            // Modulated signal
            let signal = carrier * pulse * 0.5  // Reduce amplitude

            leftChannel[i] = signal
            rightChannel[i] = signal
        }

        return buffer
    }

    /// Generate Solfeggio frequency
    func generateSolfeggioFrequency(_ frequency: SolfeggioFrequency) -> AVAudioPCMBuffer {
        let freq = frequency.frequency

        print("🎶 Generating Solfeggio Frequency:")
        print("   \(frequency.rawValue)")
        print("   Benefits: \(frequency.benefits)")

        let duration: Float = 60.0
        let frameCount = AVAudioFrameCount(sampleRate * Double(duration))

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return buffer
        }

        // Generate pure sine wave at Solfeggio frequency
        for i in 0..<Int(frameCount) {
            let time = Float(i) / Float(sampleRate)
            let sample = sin(2.0 * .pi * freq * time) * 0.3  // Gentle volume

            leftChannel[i] = sample
            rightChannel[i] = sample
        }

        return buffer
    }

    /// Generate colored noise
    func generateColoredNoise(_ color: NoiseColor) -> AVAudioPCMBuffer {
        print("📢 Generating \(color.rawValue) Noise")

        let duration: Float = 60.0
        let frameCount = AVAudioFrameCount(sampleRate * Double(duration))

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!

        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
            return buffer
        }

        // Generate white noise
        for i in 0..<Int(frameCount) {
            let whiteNoise = Float.random(in: -1.0...1.0)
            leftChannel[i] = whiteNoise
            rightChannel[i] = whiteNoise
        }

        // Apply filter for colored noise
        switch color {
        case .white:
            break  // No filter needed

        case .pink:
            // Apply 1/f filter (pink noise)
            applyPinkNoiseFilter(buffer)

        case .brown:
            // Apply 1/f² filter (brown noise)
            applyBrownNoiseFilter(buffer)

        case .blue:
            // Apply f filter (blue noise)
            applyBlueNoiseFilter(buffer)

        case .violet:
            // Apply f² filter (violet noise)
            applyVioletNoiseFilter(buffer)
        }

        return buffer
    }

    // MARK: - Noise Filters

    private func applyPinkNoiseFilter(_ buffer: AVAudioPCMBuffer) {
        // Simplified pink noise filter
        // Production would use proper 1/f filter with vDSP
        guard let channel = buffer.floatChannelData?[0] else { return }

        var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0

        for i in 0..<Int(buffer.frameLength) {
            let white = channel[i]

            b0 = 0.99886 * b0 + white * 0.0555179
            b1 = 0.99332 * b1 + white * 0.0750759
            b2 = 0.96900 * b2 + white * 0.1538520
            b3 = 0.86650 * b3 + white * 0.3104856
            b4 = 0.55000 * b4 + white * 0.5329522
            b5 = -0.7616 * b5 - white * 0.0168980

            channel[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11

            b6 = white * 0.115926
        }
    }

    private func applyBrownNoiseFilter(_ buffer: AVAudioPCMBuffer) {
        // Brown noise: integrate white noise
        guard let channel = buffer.floatChannelData?[0] else { return }

        var lastOutput: Float = 0

        for i in 0..<Int(buffer.frameLength) {
            let white = channel[i]
            lastOutput = (lastOutput + white * 0.02) * 0.99
            channel[i] = lastOutput * 3.5  // Boost amplitude
        }
    }

    private func applyBlueNoiseFilter(_ buffer: AVAudioPCMBuffer) {
        // Blue noise: differentiate white noise
        guard let channel = buffer.floatChannelData?[0] else { return }

        var lastInput: Float = 0

        for i in 0..<Int(buffer.frameLength) {
            let white = channel[i]
            channel[i] = white - lastInput
            lastInput = white
        }
    }

    private func applyVioletNoiseFilter(_ buffer: AVAudioPCMBuffer) {
        // Violet noise: differentiate twice
        applyBlueNoiseFilter(buffer)
        applyBlueNoiseFilter(buffer)  // Apply twice
    }

    // MARK: - Playback Control

    func play(therapy: TherapyType) {
        print("▶️  Starting therapy: \(therapy.description)")

        currentTherapy = therapy
        isPlaying = true

        let buffer: AVAudioPCMBuffer

        switch therapy {
        case .binauralBeats(let state):
            buffer = generateBinauralBeats(targetState: state)

        case .isochronicTones(let state):
            buffer = generateIsochronicTones(targetState: state)

        case .solfeggioFrequency(let freq):
            buffer = generateSolfeggioFrequency(freq)

        case .colorNoise(let color):
            buffer = generateColoredNoise(color)

        default:
            print("⚠️ Therapy type not yet implemented")
            return
        }

        playBuffer(buffer)
    }

    private func playBuffer(_ buffer: AVAudioPCMBuffer) {
        // Create player node
        let playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)

        // Connect to output
        audioEngine.connect(
            playerNode,
            to: audioEngine.mainMixerNode,
            format: buffer.format
        )

        // Set volume
        playerNode.volume = volume

        // Start engine
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }

        // Schedule buffer to loop
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops)

        // Start playback
        playerNode.play()

        playerNodes.append(playerNode)
    }

    func stop() {
        print("⏹  Stopping therapy")

        isPlaying = false

        for playerNode in playerNodes {
            playerNode.stop()
            audioEngine.detach(playerNode)
        }

        playerNodes.removeAll()
        audioEngine.stop()
    }
}

// MARK: - Medical Disclaimer

extension TherapeuticAudioEngine {
    static let medicalDisclaimer = """
    ⚠️ MEDICAL DISCLAIMER

    This therapeutic audio is not a medical device and is not intended to diagnose,
    treat, cure, or prevent any disease or medical condition.

    IMPORTANT WARNINGS:
    • Do NOT use if you have epilepsy or are prone to seizures
    • Do NOT use while driving or operating machinery
    • Do NOT use if photosensitive or prone to migraines
    • Consult a physician before use if you have any medical conditions
    • Not suitable for children without parental supervision
    • Pregnant women should consult their doctor before use

    This is for wellness and relaxation purposes only. If you have any medical
    concerns, please consult a qualified healthcare professional.

    Use at your own risk.
    """
}
