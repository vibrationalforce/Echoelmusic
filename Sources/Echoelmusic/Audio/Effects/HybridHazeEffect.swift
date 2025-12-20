import Foundation
import AVFoundation
import Accelerate

// ═══════════════════════════════════════════════════════════════════════════════
// HYBRID HAZE EFFECT - SPECTRAL DISPERSION + CHORUS + REVERB
// ═══════════════════════════════════════════════════════════════════════════════
//
// Inspired by Lunacy Audio's "Haze":
// • Spectral Dispersion: Frequency-dependent delay spreading
// • Shimmer Chorus: Multi-voice pitch modulation with octave harmonics
// • Atmospheric Reverb: Diffuse tail with modulation
// • All combined into one lush, atmospheric effect
//
// Bio-reactive: Coherence affects dispersion spread, HRV affects modulation
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Hybrid Haze Effect Node

@MainActor
class HybridHazeEffect: BaseEchoelmusicNode {

    // MARK: - Parameters

    struct Parameters {
        // Master
        var wetDry: Float = 50.0        // 0-100%
        var width: Float = 100.0        // 0-200% stereo width

        // Dispersion
        var dispersionAmount: Float = 50.0   // 0-100%
        var dispersionTime: Float = 200.0    // ms (max delay for high frequencies)
        var dispersionCurve: DispersionCurve = .exponential

        // Chorus
        var chorusRate: Float = 0.5      // Hz
        var chorusDepth: Float = 30.0    // 0-100%
        var chorusVoices: Int = 4        // 1-8
        var shimmerOctave: Float = 0.0   // 0-100% octave up mix

        // Reverb
        var reverbDecay: Float = 2.5     // seconds
        var reverbDamping: Float = 50.0  // 0-100% high frequency damping
        var reverbModulation: Float = 20.0 // 0-100%
        var reverbPredelay: Float = 20.0 // ms

        // Character
        var warmth: Float = 30.0         // 0-100% low-end boost
        var sparkle: Float = 40.0        // 0-100% high-end shimmer
        var density: Float = 60.0        // 0-100% effect density
    }

    enum DispersionCurve: String, CaseIterable {
        case linear = "Linear"
        case exponential = "Exponential"
        case logarithmic = "Logarithmic"
        case sCurve = "S-Curve"

        func calculate(frequency: Float, maxDelay: Float, sampleRate: Float) -> Int {
            // Normalize frequency to 0-1 range (20Hz - 20kHz)
            let normalizedFreq = log2(max(20, min(20000, frequency)) / 20) / log2(1000)

            let delayFactor: Float
            switch self {
            case .linear:
                delayFactor = normalizedFreq
            case .exponential:
                delayFactor = pow(normalizedFreq, 2)
            case .logarithmic:
                delayFactor = sqrt(normalizedFreq)
            case .sCurve:
                delayFactor = normalizedFreq * normalizedFreq * (3 - 2 * normalizedFreq)
            }

            // Higher frequencies get more delay (dispersion effect)
            let delayMs = maxDelay * delayFactor
            return Int(delayMs * sampleRate / 1000.0)
        }
    }

    // MARK: - State

    var params = Parameters()

    // Audio buffers
    private var delayBuffer: [Float] = []
    private var delayWriteIndex: Int = 0
    private var reverbBuffer: [Float] = []
    private var chorusLFOPhase: Float = 0.0

    // FFT for spectral processing
    private var fftSetup: vDSP_DFT_Setup?
    private var fftSize: Int = 2048
    private var realBuffer: [Float] = []
    private var imagBuffer: [Float] = []

    // Chorus voices
    private struct ChorusVoice {
        var phase: Float = 0.0
        var phaseIncrement: Float = 0.0
        var pan: Float = 0.5  // 0-1 (left-right)
    }
    private var chorusVoices: [ChorusVoice] = []

    // All-pass reverb network
    private struct AllPassFilter {
        var buffer: [Float]
        var bufferSize: Int
        var index: Int = 0
        var feedback: Float

        mutating func process(_ input: Float) -> Float {
            let bufferedSample = buffer[index]
            let output = -input + bufferedSample
            buffer[index] = input + bufferedSample * feedback
            index = (index + 1) % bufferSize
            return output
        }
    }
    private var allPassFilters: [AllPassFilter] = []

    // Sample rate
    private var sampleRate: Double = 44100.0
    private var maxDelayFrames: Int = 44100  // 1 second max

    // Bio-reactive state
    private var currentCoherence: Float = 50.0
    private var currentHRV: Float = 50.0

    // MARK: - Initialization

    init() {
        super.init(name: "Hybrid Haze", type: .effect)
        setupParameters()
    }

    private func setupParameters() {
        parameters = [
            NodeParameter(name: "wetDry", label: "Wet/Dry", value: params.wetDry,
                         min: 0, max: 100, defaultValue: 50, unit: "%",
                         isAutomatable: true, type: .continuous),
            NodeParameter(name: "dispersionAmount", label: "Dispersion", value: params.dispersionAmount,
                         min: 0, max: 100, defaultValue: 50, unit: "%",
                         isAutomatable: true, type: .continuous),
            NodeParameter(name: "dispersionTime", label: "Dispersion Time", value: params.dispersionTime,
                         min: 10, max: 500, defaultValue: 200, unit: "ms",
                         isAutomatable: true, type: .continuous),
            NodeParameter(name: "chorusRate", label: "Chorus Rate", value: params.chorusRate,
                         min: 0.1, max: 5.0, defaultValue: 0.5, unit: "Hz",
                         isAutomatable: true, type: .continuous),
            NodeParameter(name: "chorusDepth", label: "Chorus Depth", value: params.chorusDepth,
                         min: 0, max: 100, defaultValue: 30, unit: "%",
                         isAutomatable: true, type: .continuous),
            NodeParameter(name: "shimmerOctave", label: "Shimmer", value: params.shimmerOctave,
                         min: 0, max: 100, defaultValue: 0, unit: "%",
                         isAutomatable: true, type: .continuous),
            NodeParameter(name: "reverbDecay", label: "Reverb Decay", value: params.reverbDecay,
                         min: 0.1, max: 10.0, defaultValue: 2.5, unit: "s",
                         isAutomatable: true, type: .continuous),
            NodeParameter(name: "reverbDamping", label: "Damping", value: params.reverbDamping,
                         min: 0, max: 100, defaultValue: 50, unit: "%",
                         isAutomatable: true, type: .continuous),
            NodeParameter(name: "warmth", label: "Warmth", value: params.warmth,
                         min: 0, max: 100, defaultValue: 30, unit: "%",
                         isAutomatable: true, type: .continuous),
            NodeParameter(name: "sparkle", label: "Sparkle", value: params.sparkle,
                         min: 0, max: 100, defaultValue: 40, unit: "%",
                         isAutomatable: true, type: .continuous),
            NodeParameter(name: "width", label: "Width", value: params.width,
                         min: 0, max: 200, defaultValue: 100, unit: "%",
                         isAutomatable: true, type: .continuous),
            NodeParameter(name: "density", label: "Density", value: params.density,
                         min: 0, max: 100, defaultValue: 60, unit: "%",
                         isAutomatable: true, type: .continuous)
        ]
    }

    // MARK: - Lifecycle

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        self.sampleRate = sampleRate
        self.maxDelayFrames = Int(sampleRate)  // 1 second

        // Allocate buffers
        delayBuffer = [Float](repeating: 0, count: maxDelayFrames)
        reverbBuffer = [Float](repeating: 0, count: Int(sampleRate * 5))  // 5 sec reverb buffer

        // FFT setup
        fftSize = 2048
        realBuffer = [Float](repeating: 0, count: fftSize)
        imagBuffer = [Float](repeating: 0, count: fftSize)
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)

        // Setup chorus voices
        setupChorusVoices()

        // Setup all-pass reverb network
        setupAllPassNetwork()

        print("✨ HybridHaze prepared @ \(sampleRate) Hz")
    }

    private func setupChorusVoices() {
        chorusVoices = (0..<8).map { i in
            ChorusVoice(
                phase: Float(i) / 8.0 * Float.pi * 2,
                phaseIncrement: params.chorusRate / Float(sampleRate) * Float.pi * 2,
                pan: Float(i) / 7.0  // Spread across stereo field
            )
        }
    }

    private func setupAllPassNetwork() {
        // Schroeder-style all-pass reverb network
        let sizes = [1051, 337, 113, 37]  // Prime numbers for less metallic sound
        let feedback: Float = 0.5 + params.reverbDecay / 20.0

        allPassFilters = sizes.map { size in
            AllPassFilter(
                buffer: [Float](repeating: 0, count: size),
                bufferSize: size,
                feedback: feedback
            )
        }
    }

    override func start() {
        super.start()
        print("✨ HybridHaze started")
    }

    override func stop() {
        super.stop()
        // Clear buffers
        delayBuffer = delayBuffer.map { _ in 0 }
        reverbBuffer = reverbBuffer.map { _ in 0 }
        print("✨ HybridHaze stopped")
    }

    override func reset() {
        super.reset()
        delayBuffer = delayBuffer.map { _ in 0 }
        reverbBuffer = reverbBuffer.map { _ in 0 }
        chorusLFOPhase = 0
    }

    // MARK: - Audio Processing

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard !isBypassed, isActive else { return buffer }

        // Update parameters from node parameter values
        syncParameters()

        guard let channelData = buffer.floatChannelData else { return buffer }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Process mono or stereo
        if channelCount == 1 {
            processMonoBuffer(channelData[0], frameCount: frameCount)
        } else if channelCount >= 2 {
            processStereoBuffer(left: channelData[0], right: channelData[1], frameCount: frameCount)
        }

        return buffer
    }

    private func syncParameters() {
        params.wetDry = getParameter(name: "wetDry") ?? params.wetDry
        params.dispersionAmount = getParameter(name: "dispersionAmount") ?? params.dispersionAmount
        params.dispersionTime = getParameter(name: "dispersionTime") ?? params.dispersionTime
        params.chorusRate = getParameter(name: "chorusRate") ?? params.chorusRate
        params.chorusDepth = getParameter(name: "chorusDepth") ?? params.chorusDepth
        params.shimmerOctave = getParameter(name: "shimmerOctave") ?? params.shimmerOctave
        params.reverbDecay = getParameter(name: "reverbDecay") ?? params.reverbDecay
        params.reverbDamping = getParameter(name: "reverbDamping") ?? params.reverbDamping
        params.warmth = getParameter(name: "warmth") ?? params.warmth
        params.sparkle = getParameter(name: "sparkle") ?? params.sparkle
        params.width = getParameter(name: "width") ?? params.width
        params.density = getParameter(name: "density") ?? params.density
    }

    private func processMonoBuffer(_ data: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            let input = data[i]

            // Apply effect chain
            var processed = input

            // 1. Spectral Dispersion
            processed = applyDispersion(processed)

            // 2. Chorus with shimmer
            processed = applyChorus(processed)

            // 3. Reverb
            processed = applyReverb(processed)

            // 4. Warmth (low shelf boost)
            processed = applyWarmth(processed)

            // 5. Sparkle (high shelf with modulation)
            processed = applySparkle(processed)

            // Mix wet/dry
            let wetAmount = params.wetDry / 100.0
            data[i] = input * (1.0 - wetAmount) + processed * wetAmount
        }
    }

    private func processStereoBuffer(left: UnsafeMutablePointer<Float>,
                                      right: UnsafeMutablePointer<Float>,
                                      frameCount: Int) {
        for i in 0..<frameCount {
            let inputL = left[i]
            let inputR = right[i]
            let mono = (inputL + inputR) * 0.5

            // Process mono through effect chain
            var processed = mono
            processed = applyDispersion(processed)
            processed = applyChorus(processed)
            processed = applyReverb(processed)
            processed = applyWarmth(processed)
            processed = applySparkle(processed)

            // Apply stereo width
            let widthFactor = params.width / 100.0
            let mid = processed
            let side = (inputL - inputR) * 0.5 * widthFactor

            let wetL = mid + side
            let wetR = mid - side

            // Mix wet/dry
            let wetAmount = params.wetDry / 100.0
            left[i] = inputL * (1.0 - wetAmount) + wetL * wetAmount
            right[i] = inputR * (1.0 - wetAmount) + wetR * wetAmount
        }
    }

    // MARK: - Effect Components

    /// Spectral dispersion - frequency-dependent delay
    private func applyDispersion(_ input: Float) -> Float {
        guard params.dispersionAmount > 0 else { return input }

        // Write to delay buffer
        delayBuffer[delayWriteIndex] = input

        // Simple approximation: blend multiple taps with different delays
        // (Full spectral dispersion would require FFT-based processing)
        let dispersionFactor = params.dispersionAmount / 100.0
        let maxDelaySamples = Int(params.dispersionTime * Float(sampleRate) / 1000.0)

        var output: Float = 0
        let taps = 8

        for tap in 0..<taps {
            // Higher taps = higher frequency simulation = more delay
            let tapDelay = Int(Float(maxDelaySamples) * pow(Float(tap) / Float(taps), 2) * dispersionFactor)
            let readIndex = (delayWriteIndex - tapDelay + delayBuffer.count) % delayBuffer.count
            let tapGain = 1.0 / Float(taps)
            output += delayBuffer[readIndex] * tapGain
        }

        delayWriteIndex = (delayWriteIndex + 1) % delayBuffer.count

        return output
    }

    /// Multi-voice chorus with optional octave shimmer
    private func applyChorus(_ input: Float) -> Float {
        guard params.chorusDepth > 0 else { return input }

        let activeVoices = min(params.chorusVoices, chorusVoices.count)
        var output: Float = 0

        for i in 0..<activeVoices {
            // Update LFO phase
            chorusVoices[i].phase += params.chorusRate / Float(sampleRate) * Float.pi * 2
            if chorusVoices[i].phase > Float.pi * 2 {
                chorusVoices[i].phase -= Float.pi * 2
            }

            // Calculate modulated delay
            let lfoValue = sin(chorusVoices[i].phase + Float(i) * Float.pi / 4)
            let delayMs = 10.0 + 20.0 * (params.chorusDepth / 100.0) * (lfoValue + 1.0) / 2.0
            let delaySamples = Int(delayMs * Float(sampleRate) / 1000.0)

            // Read from delay buffer with interpolation
            let readIndex = (delayWriteIndex - delaySamples + delayBuffer.count) % delayBuffer.count
            let delayed = delayBuffer[readIndex]

            // Add shimmer octave (pitch shift approximation)
            var voiceOutput = delayed
            if params.shimmerOctave > 0 {
                let shimmerAmount = params.shimmerOctave / 100.0
                // Simple octave up simulation (read at double speed)
                let shimmerIndex = (delayWriteIndex - delaySamples / 2 + delayBuffer.count) % delayBuffer.count
                voiceOutput = delayed * (1.0 - shimmerAmount) + delayBuffer[shimmerIndex] * shimmerAmount
            }

            output += voiceOutput / Float(activeVoices)
        }

        // Blend with dry
        return input * 0.5 + output * 0.5
    }

    /// All-pass reverb network
    private func applyReverb(_ input: Float) -> Float {
        guard params.reverbDecay > 0 else { return input }

        var signal = input

        // Pre-delay
        let predelaySamples = Int(params.reverbPredelay * Float(sampleRate) / 1000.0)
        if predelaySamples > 0 && predelaySamples < reverbBuffer.count {
            // Simple predelay using reverb buffer
            signal = reverbBuffer[predelaySamples % reverbBuffer.count]
        }

        // All-pass cascade
        for i in 0..<allPassFilters.count {
            signal = allPassFilters[i].process(signal)
        }

        // Damping (simple low-pass)
        let dampingFactor = 1.0 - (params.reverbDamping / 100.0) * 0.5
        signal *= dampingFactor

        // Modulation
        if params.reverbModulation > 0 {
            let modAmount = params.reverbModulation / 100.0 * 0.1
            signal *= 1.0 + modAmount * sin(chorusLFOPhase * 0.3)
        }

        return signal * (params.density / 100.0)
    }

    /// Low-frequency warmth boost
    private func applyWarmth(_ input: Float) -> Float {
        guard params.warmth > 0 else { return input }

        // Simple low-frequency emphasis (in a real implementation, use proper EQ)
        let boostFactor = 1.0 + (params.warmth / 100.0) * 0.3
        return input * boostFactor
    }

    /// High-frequency sparkle with subtle modulation
    private func applySparkle(_ input: Float) -> Float {
        guard params.sparkle > 0 else { return input }

        // High-frequency emphasis simulation
        let sparkleAmount = params.sparkle / 100.0

        // Add subtle high-frequency content
        let highFreqEmphasis = 1.0 + sparkleAmount * 0.2

        // Subtle modulation for shimmer effect
        chorusLFOPhase += 0.01
        let modulation = 1.0 + sparkleAmount * 0.05 * sin(chorusLFOPhase * 5.0)

        return input * highFreqEmphasis * modulation
    }

    // MARK: - Bio-Reactivity

    override func react(to signal: BioSignal) {
        currentCoherence = signal.coherence
        currentHRV = signal.hrv

        // High coherence = more focused, controlled dispersion
        let coherenceFactor = signal.coherence / 100.0
        let targetDispersion = 30.0 + coherenceFactor * 40.0  // 30-70%
        params.dispersionAmount = params.dispersionAmount * 0.95 + targetDispersion * 0.05

        // HRV affects modulation rate
        let hrvFactor = min(signal.hrv / 100.0, 1.0)
        params.chorusRate = 0.3 + hrvFactor * 0.7  // 0.3-1.0 Hz

        // Energy affects density
        params.density = 40.0 + signal.energy * 40.0  // 40-80%

        // Update node parameters
        setParameter(name: "dispersionAmount", value: params.dispersionAmount)
        setParameter(name: "chorusRate", value: params.chorusRate)
        setParameter(name: "density", value: params.density)
    }

    // MARK: - Presets

    static func lushAtmosphere() -> HybridHazeEffect {
        let effect = HybridHazeEffect()
        effect.params.wetDry = 60
        effect.params.dispersionAmount = 70
        effect.params.dispersionTime = 300
        effect.params.chorusDepth = 40
        effect.params.shimmerOctave = 30
        effect.params.reverbDecay = 4.0
        effect.params.warmth = 40
        effect.params.sparkle = 50
        effect.params.width = 150
        return effect
    }

    static func subtleShimmer() -> HybridHazeEffect {
        let effect = HybridHazeEffect()
        effect.params.wetDry = 30
        effect.params.dispersionAmount = 40
        effect.params.chorusDepth = 20
        effect.params.shimmerOctave = 50
        effect.params.reverbDecay = 2.0
        effect.params.sparkle = 60
        return effect
    }

    static func deepSpace() -> HybridHazeEffect {
        let effect = HybridHazeEffect()
        effect.params.wetDry = 80
        effect.params.dispersionAmount = 100
        effect.params.dispersionTime = 500
        effect.params.reverbDecay = 8.0
        effect.params.reverbDamping = 70
        effect.params.density = 80
        effect.params.width = 200
        return effect
    }
}
