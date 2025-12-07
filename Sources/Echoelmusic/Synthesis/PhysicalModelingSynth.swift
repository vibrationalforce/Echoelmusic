import Foundation
import Accelerate
import simd

// MARK: - Physical Modeling Synthesizer
// Karplus-Strong, waveguide synthesis, and modal synthesis
// Based on: Stanford CCRMA waveguide synthesis research (Smith, 1992)

// MARK: - ULTRA OPTIMIZATION: Sine LUT for Physical Modeling

/// High-precision sine LUT for physical modeling synthesis
fileprivate enum PMSineLUT {
    static let size: Int = 4096
    static let mask: Int = 4095
    static let twoPi: Float = 2.0 * .pi

    static let table: [Float] = {
        var t = [Float](repeating: 0, count: 4096)
        for i in 0..<4096 {
            t[i] = sin(Float(i) / 4096.0 * 2.0 * .pi)
        }
        return t
    }()

    /// Cosine table (phase-shifted sine)
    static let cosTable: [Float] = {
        var t = [Float](repeating: 0, count: 4096)
        for i in 0..<4096 {
            t[i] = cos(Float(i) / 4096.0 * 2.0 * .pi)
        }
        return t
    }()

    @inline(__always)
    static func sin(_ phase: Float) -> Float {
        var normalizedPhase = phase / twoPi
        normalizedPhase = normalizedPhase - Float(Int(normalizedPhase))
        if normalizedPhase < 0 { normalizedPhase += 1.0 }
        let index = Int(normalizedPhase * Float(size)) & mask
        return table[index]
    }

    @inline(__always)
    static func cos(_ phase: Float) -> Float {
        var normalizedPhase = phase / twoPi
        normalizedPhase = normalizedPhase - Float(Int(normalizedPhase))
        if normalizedPhase < 0 { normalizedPhase += 1.0 }
        let index = Int(normalizedPhase * Float(size)) & mask
        return cosTable[index]
    }
}

/// PhysicalModelingSynth: Realistic physical modeling synthesis
/// Implements digital waveguide models for strings, tubes, and percussion
///
/// Models included:
/// - Karplus-Strong plucked string
/// - Extended Karplus-Strong with dynamics
/// - Digital waveguide string (bowed, plucked, struck)
/// - Waveguide brass/woodwind
/// - Modal synthesis for percussion
/// - Commuted synthesis piano model
public final class PhysicalModelingSynth {

    // MARK: - Types

    /// Physical model types
    public enum ModelType: Int, CaseIterable {
        case karplusStrong      // Classic plucked string
        case extendedKS         // Enhanced with dynamics control
        case bowedString        // Bowed string waveguide
        case pluckedString      // Detailed plucked string
        case struckString       // Piano-like struck string
        case brass              // Brass tube waveguide
        case woodwind           // Woodwind with reed
        case flute              // Flute model
        case marimba            // Modal synthesis percussion
        case bell               // Inharmonic bell
        case membrane           // Drum membrane
        case bar                // Metal bar (glockenspiel)

        var displayName: String {
            switch self {
            case .karplusStrong: return "Karplus-Strong"
            case .extendedKS: return "Extended K-S"
            case .bowedString: return "Bowed String"
            case .pluckedString: return "Plucked String"
            case .struckString: return "Struck String"
            case .brass: return "Brass"
            case .woodwind: return "Woodwind"
            case .flute: return "Flute"
            case .marimba: return "Marimba"
            case .bell: return "Bell"
            case .membrane: return "Membrane"
            case .bar: return "Metal Bar"
            }
        }
    }

    /// Excitation types for string models
    public enum ExcitationType: Int, CaseIterable {
        case pluck      // Sharp attack
        case bow        // Sustained
        case hammer     // Piano-like
        case strike     // Percussion
        case noise      // White noise burst

        var displayName: String {
            switch self {
            case .pluck: return "Pluck"
            case .bow: return "Bow"
            case .hammer: return "Hammer"
            case .strike: return "Strike"
            case .noise: return "Noise"
            }
        }
    }

    /// Delay line for waveguide
    private struct DelayLine {
        var buffer: [Float]
        var writeIndex: Int = 0
        var length: Int

        init(maxLength: Int) {
            buffer = [Float](repeating: 0, count: maxLength)
            length = maxLength
        }

        mutating func write(_ sample: Float) {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % length
        }

        func read(delay: Int) -> Float {
            var index = writeIndex - delay - 1
            while index < 0 { index += length }
            return buffer[index % length]
        }

        func readInterpolated(delay: Float) -> Float {
            let delayInt = Int(delay)
            let frac = delay - Float(delayInt)

            let s0 = read(delay: delayInt)
            let s1 = read(delay: delayInt + 1)

            return s0 + frac * (s1 - s0)
        }

        mutating func clear() {
            vDSP_vclr(&buffer, 1, vDSP_Length(buffer.count))
        }

        mutating func setLength(_ newLength: Int) {
            length = min(newLength, buffer.count)
        }
    }

    /// Voice state for physical model
    private struct PMVoice {
        var isActive: Bool = false
        var frequency: Float = 440
        var velocity: Float = 0.8
        var noteOnTime: Int = 0

        // Delay lines for waveguide
        var delayLine1 = DelayLine(maxLength: 4096)
        var delayLine2 = DelayLine(maxLength: 4096)

        // Filter states
        var lpfState: Float = 0
        var allpassState: Float = 0
        var dcBlockState: Float = 0
        var dcBlockPrev: Float = 0

        // Bowing state
        var bowPosition: Float = 0.2
        var bowVelocity: Float = 0.1
        var bowForce: Float = 0.5

        // Excitation state
        var excitationPhase: Int = 0
        var excitationLength: Int = 0

        // Modal synthesis state
        var modalAmplitudes: [Float] = []
        var modalPhases: [Float] = []
        var modalDecays: [Float] = []

        mutating func reset() {
            isActive = false
            delayLine1.clear()
            delayLine2.clear()
            lpfState = 0
            allpassState = 0
            dcBlockState = 0
            dcBlockPrev = 0
            excitationPhase = 0
            modalAmplitudes = []
            modalPhases = []
            modalDecays = []
        }
    }

    // MARK: - Properties

    /// Sample rate
    private var sampleRate: Float = 44100

    /// Maximum polyphony
    private let maxVoices = 16

    /// Voice pool
    private var voices: [PMVoice] = []

    /// Active voice indices
    private var activeVoices: Set<Int> = []

    /// Current model type
    public var modelType: ModelType = .karplusStrong

    /// Excitation type for string models
    public var excitationType: ExcitationType = .pluck

    /// Damping factor (0-1, higher = more damping)
    public var damping: Float = 0.5

    /// Brightness (filter cutoff, 0-1)
    public var brightness: Float = 0.7

    /// Decay time (0-1)
    public var decay: Float = 0.99

    /// Inharmonicity coefficient
    public var inharmonicity: Float = 0.0001

    /// Pluck position (0-1)
    public var pluckPosition: Float = 0.25

    /// Bow pressure for bowed models
    public var bowPressure: Float = 0.5

    /// Bow velocity for bowed models
    public var bowSpeed: Float = 0.1

    /// Body resonance amount
    public var bodyResonance: Float = 0.3

    /// Global volume
    public var volume: Float = 0.8

    /// Body resonance filter
    private var bodyFilter1State: Float = 0
    private var bodyFilter2State: Float = 0

    // MARK: - Initialization

    public init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        voices = [PMVoice](repeating: PMVoice(), count: maxVoices)

        // ULTRA OPTIMIZATION: Pre-allocate voice output buffer
        voiceOutputBuffer = [Float](repeating: 0, count: 8192)
        voiceOutputBufferCapacity = 8192
    }

    // MARK: - ULTRA OPTIMIZATION: Pre-allocated buffers

    /// Pre-allocated voice output buffer to avoid per-frame allocation
    private var voiceOutputBuffer: [Float] = []
    private var voiceOutputBufferCapacity: Int = 0

    /// Ensure buffer capacity
    @inline(__always)
    private func ensureVoiceOutputCapacity(_ frameCount: Int) {
        if frameCount > voiceOutputBufferCapacity {
            voiceOutputBuffer = [Float](repeating: 0, count: frameCount)
            voiceOutputBufferCapacity = frameCount
        }
    }

    // MARK: - Note Control

    /// Trigger a note
    public func noteOn(frequency: Float, velocity: Float = 0.8) -> Int {
        // Find free voice or steal oldest
        var voiceIndex = voices.firstIndex { !$0.isActive }

        if voiceIndex == nil {
            // Voice stealing - find oldest
            voiceIndex = activeVoices.min { voices[$0].noteOnTime < voices[$1].noteOnTime }
            if let idx = voiceIndex {
                voices[idx].reset()
            }
        }

        guard let idx = voiceIndex else { return -1 }

        voices[idx].isActive = true
        voices[idx].frequency = frequency
        voices[idx].velocity = velocity
        voices[idx].noteOnTime = 0

        // Initialize based on model type
        initializeVoice(&voices[idx])

        activeVoices.insert(idx)
        return idx
    }

    /// Release a note
    public func noteOff(voiceIndex: Int) {
        guard voiceIndex >= 0 && voiceIndex < maxVoices else { return }

        // For physical models, we don't immediately stop
        // The model naturally decays based on damping
        // But we can increase damping on release

        // For bowed strings, stop the bow
        voices[voiceIndex].bowForce = 0
    }

    /// MIDI note on
    public func noteOn(note: Int, velocity: Int) -> Int {
        let frequency = 440.0 * pow(2.0, Float(note - 69) / 12.0)
        let vel = Float(velocity) / 127.0
        return noteOn(frequency: frequency, velocity: vel)
    }

    /// MIDI note off
    public func noteOff(note: Int) {
        // Find voice playing this note
        let frequency = 440.0 * pow(2.0, Float(note - 69) / 12.0)
        for i in activeVoices {
            if abs(voices[i].frequency - frequency) < 0.1 {
                noteOff(voiceIndex: i)
                break
            }
        }
    }

    // MARK: - Voice Initialization

    /// Initialize voice for current model
    private func initializeVoice(_ voice: inout PMVoice) {
        let delayLength = Int(sampleRate / voice.frequency)

        switch modelType {
        case .karplusStrong, .extendedKS, .pluckedString:
            initializeKarplusStrong(&voice, delayLength: delayLength)

        case .bowedString:
            initializeBowedString(&voice, delayLength: delayLength)

        case .struckString:
            initializeStruckString(&voice, delayLength: delayLength)

        case .brass, .woodwind, .flute:
            initializeWindModel(&voice, delayLength: delayLength)

        case .marimba, .bell, .bar:
            initializeModalSynth(&voice)

        case .membrane:
            initializeMembrane(&voice, delayLength: delayLength)
        }
    }

    /// Initialize Karplus-Strong string
    private func initializeKarplusStrong(_ voice: inout PMVoice, delayLength: Int) {
        voice.delayLine1.setLength(delayLength)
        voice.delayLine1.clear()

        // Fill delay line with excitation
        let excitationLength = min(delayLength, Int(Float(delayLength) * pluckPosition))
        voice.excitationLength = excitationLength
        voice.excitationPhase = 0

        // Generate excitation based on type
        for i in 0..<delayLength {
            var sample: Float = 0

            switch excitationType {
            case .pluck:
                // Triangular pluck
                if i < excitationLength / 2 {
                    sample = Float(i) / Float(excitationLength / 2)
                } else if i < excitationLength {
                    sample = 1.0 - Float(i - excitationLength / 2) / Float(excitationLength / 2)
                }
                sample *= voice.velocity

            case .noise:
                if i < excitationLength {
                    sample = Float.random(in: -1...1) * voice.velocity
                }

            case .hammer:
                // Raised cosine (soft hammer)
                if i < excitationLength {
                    let phase = Float(i) / Float(excitationLength) * .pi
                    sample = sin(phase) * voice.velocity
                }

            case .strike:
                // Sharp impulse
                if i < 10 {
                    sample = voice.velocity * (1.0 - Float(i) / 10.0)
                }

            case .bow:
                // Continuous excitation handled in processing
                break
            }

            voice.delayLine1.write(sample)
        }
    }

    /// Initialize bowed string model
    private func initializeBowedString(_ voice: inout PMVoice, delayLength: Int) {
        voice.delayLine1.setLength(delayLength / 2)
        voice.delayLine2.setLength(delayLength / 2)
        voice.delayLine1.clear()
        voice.delayLine2.clear()

        voice.bowPosition = pluckPosition
        voice.bowVelocity = bowSpeed
        voice.bowForce = bowPressure * voice.velocity
    }

    /// Initialize struck string (piano-like)
    private func initializeStruckString(_ voice: inout PMVoice, delayLength: Int) {
        voice.delayLine1.setLength(delayLength)
        voice.delayLine1.clear()

        // Piano hammer excitation
        let hammerWidth = Int(Float(delayLength) * 0.05)
        let hammerPosition = Int(Float(delayLength) * pluckPosition)

        for i in 0..<delayLength {
            var sample: Float = 0

            let dist = abs(i - hammerPosition)
            if dist < hammerWidth {
                let t = Float(dist) / Float(hammerWidth)
                // Hammer is a raised cosine
                sample = (1.0 - cos(.pi * (1.0 - t))) * 0.5 * voice.velocity
            }

            voice.delayLine1.write(sample)
        }
    }

    /// Initialize wind instrument model
    private func initializeWindModel(_ voice: inout PMVoice, delayLength: Int) {
        // Bidirectional waveguide for tube
        voice.delayLine1.setLength(delayLength / 2)  // Upper rail
        voice.delayLine2.setLength(delayLength / 2)  // Lower rail
        voice.delayLine1.clear()
        voice.delayLine2.clear()

        voice.excitationPhase = 0
    }

    /// Initialize modal synthesis for percussion
    private func initializeModalSynth(_ voice: inout PMVoice) {
        // Modal frequencies and decay times vary by instrument
        let (frequencies, decays, amplitudes) = getModalParameters(for: modelType, baseFreq: voice.frequency)

        voice.modalAmplitudes = amplitudes.map { $0 * voice.velocity }
        voice.modalPhases = [Float](repeating: 0, count: frequencies.count)
        voice.modalDecays = decays

        // Store frequency ratios in phases temporarily
        for i in 0..<frequencies.count {
            voice.modalPhases[i] = 0
            // We'll use frequency directly in processing
        }
    }

    /// Initialize drum membrane
    private func initializeMembrane(_ voice: inout PMVoice, delayLength: Int) {
        // 2D waveguide simulation using crossed delay lines
        voice.delayLine1.setLength(delayLength)
        voice.delayLine2.setLength(Int(Float(delayLength) * 1.414))  // Diagonal mode
        voice.delayLine1.clear()
        voice.delayLine2.clear()

        // Impulse excitation
        let exciteLength = 20
        for i in 0..<exciteLength {
            let sample = voice.velocity * (1.0 - Float(i) / Float(exciteLength))
            voice.delayLine1.write(sample)
            voice.delayLine2.write(sample * 0.7)
        }
    }

    /// Get modal parameters for percussion instruments
    private func getModalParameters(for type: ModelType, baseFreq: Float) -> (frequencies: [Float], decays: [Float], amplitudes: [Float]) {

        switch type {
        case .marimba:
            // Marimba has nearly harmonic partials
            return (
                [1.0, 2.0, 3.0, 4.0, 5.0, 6.0].map { baseFreq * $0 },
                [0.999, 0.998, 0.995, 0.990, 0.980, 0.970],
                [1.0, 0.5, 0.25, 0.15, 0.1, 0.05]
            )

        case .bell:
            // Bell has inharmonic partials
            return (
                [1.0, 2.0, 2.4, 3.0, 3.2, 4.1, 5.4, 6.8].map { baseFreq * $0 },
                [0.9999, 0.9998, 0.9997, 0.9995, 0.9990, 0.9985, 0.9980, 0.9970],
                [1.0, 0.6, 0.5, 0.35, 0.3, 0.2, 0.15, 0.1]
            )

        case .bar:
            // Metal bar (glockenspiel) - more inharmonic
            return (
                [1.0, 2.756, 5.404, 8.933, 13.344].map { baseFreq * $0 },
                [0.9998, 0.9995, 0.9990, 0.9980, 0.9960],
                [1.0, 0.4, 0.2, 0.1, 0.05]
            )

        default:
            return ([baseFreq], [0.999], [1.0])
        }
    }

    // MARK: - Audio Processing

    /// Process audio buffer
    public func process(buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Clear buffer
        vDSP_vclr(buffer, 1, vDSP_Length(frameCount))

        // OPTIMIZED: Process each active voice using pre-allocated buffer
        var voicesToRemove: [Int] = []

        for voiceIndex in activeVoices {
            processVoice(&voices[voiceIndex], frameCount: frameCount)

            // Mix to buffer using pre-allocated voice output
            vDSP_vadd(buffer, 1, voiceOutputBuffer, 1, buffer, 1, vDSP_Length(frameCount))

            // Check if voice is done (energy below threshold)
            if voiceOutputBuffer.prefix(frameCount).max() ?? 0 < 0.0001 && !voices[voiceIndex].isActive {
                voicesToRemove.append(voiceIndex)
            }

            voices[voiceIndex].noteOnTime += frameCount
        }

        // Remove finished voices
        for idx in voicesToRemove {
            voices[idx].reset()
            activeVoices.remove(idx)
        }

        // Apply body resonance
        if bodyResonance > 0 {
            applyBodyResonance(buffer, frameCount: frameCount)
        }

        // Apply volume
        var vol = volume
        vDSP_vsmul(buffer, 1, &vol, buffer, 1, vDSP_Length(frameCount))
    }

    /// OPTIMIZED: Process single voice using pre-allocated buffer
    private func processVoice(_ voice: inout PMVoice, frameCount: Int) {
        // OPTIMIZED: Use pre-allocated buffer instead of creating new array
        ensureVoiceOutputCapacity(frameCount)
        vDSP_vclr(&voiceOutputBuffer, 1, vDSP_Length(frameCount))

        switch modelType {
        case .karplusStrong, .extendedKS, .pluckedString:
            processKarplusStrong(&voice, output: &voiceOutputBuffer, frameCount: frameCount)

        case .bowedString:
            processBowedString(&voice, output: &voiceOutputBuffer, frameCount: frameCount)

        case .struckString:
            processStruckString(&voice, output: &voiceOutputBuffer, frameCount: frameCount)

        case .brass, .woodwind, .flute:
            processWindModel(&voice, output: &voiceOutputBuffer, frameCount: frameCount)

        case .marimba, .bell, .bar:
            processModalSynth(&voice, output: &voiceOutputBuffer, frameCount: frameCount)

        case .membrane:
            processMembrane(&voice, output: &voiceOutputBuffer, frameCount: frameCount)
        }
    }

    /// Process Karplus-Strong algorithm
    private func processKarplusStrong(_ voice: inout PMVoice, output: inout [Float], frameCount: Int) {
        let delayLength = Float(voice.delayLine1.length)

        // Apply inharmonicity - stretch factor
        let stretchFactor = sqrt(1 + inharmonicity * delayLength * delayLength)

        // Low-pass coefficient based on brightness and decay
        let lpfCoeff = brightness * decay

        for i in 0..<frameCount {
            // Read from delay line
            let delaySamples = delayLength / stretchFactor
            let sample = voice.delayLine1.readInterpolated(delay: delaySamples)

            // Low-pass filter (simple averaging with state)
            voice.lpfState = lpfCoeff * sample + (1 - lpfCoeff) * voice.lpfState

            // Apply damping (decay)
            let filtered = voice.lpfState * decay

            // Write back to delay line
            voice.delayLine1.write(filtered)

            // DC blocking
            let dcBlocked = filtered - voice.dcBlockPrev + 0.995 * voice.dcBlockState
            voice.dcBlockState = dcBlocked
            voice.dcBlockPrev = filtered

            output[i] = dcBlocked
        }
    }

    /// Process bowed string model
    private func processBowedString(_ voice: inout PMVoice, output: inout [Float], frameCount: Int) {
        let bowPos = Int(voice.bowPosition * Float(voice.delayLine1.length))

        for i in 0..<frameCount {
            // Read waves traveling in both directions
            let vPlus = voice.delayLine1.read(delay: bowPos)
            let vMinus = voice.delayLine2.read(delay: voice.delayLine2.length - bowPos - 1)

            // Bow-string interaction (simplified nonlinear model)
            let vBow = voice.bowVelocity
            let deltaV = vBow - (vPlus + vMinus)

            // Friction curve (hyperbolic)
            let force = voice.bowForce
            let friction = force * deltaV / (0.3 + abs(deltaV))

            // Add friction force to both waves
            let newVPlus = vPlus + friction * 0.5
            let newVMinus = vMinus + friction * 0.5

            // Low-pass filter at bridge
            voice.lpfState = brightness * newVPlus + (1 - brightness) * voice.lpfState
            let bridgeReflection = -voice.lpfState * decay

            // Write to delay lines
            voice.delayLine1.write(bridgeReflection)
            voice.delayLine2.write(-newVMinus * decay)

            output[i] = vPlus + vMinus
        }
    }

    /// Process struck string (piano model)
    private func processStruckString(_ voice: inout PMVoice, output: inout [Float], frameCount: Int) {
        // Similar to Karplus-Strong but with:
        // - Higher inharmonicity
        // - Multiple coupled strings (simplified)
        // - Loss filter

        let delayLength = Float(voice.delayLine1.length)
        let stretchFactor = sqrt(1 + inharmonicity * 10 * delayLength * delayLength)

        // Two-pole loss filter for realistic piano decay
        let lpfCoeff1 = brightness * 0.9
        let lpfCoeff2 = decay

        for i in 0..<frameCount {
            let delaySamples = delayLength / stretchFactor
            let sample = voice.delayLine1.readInterpolated(delay: delaySamples)

            // Two-stage filtering
            voice.lpfState = lpfCoeff1 * sample + (1 - lpfCoeff1) * voice.lpfState
            voice.allpassState = lpfCoeff2 * voice.lpfState + (1 - lpfCoeff2) * voice.allpassState

            voice.delayLine1.write(voice.allpassState)

            output[i] = sample
        }
    }

    /// Process wind instrument model
    private func processWindModel(_ voice: inout PMVoice, output: inout [Float], frameCount: Int) {
        let breathPressure = bowPressure * voice.velocity

        for i in 0..<frameCount {
            // Jet/reed excitation
            var excitation: Float = 0

            switch modelType {
            case .brass:
                // Lip reed model
                let pMouth = breathPressure
                let pBore = voice.delayLine1.read(delay: 0)
                let deltap = pMouth - pBore
                excitation = deltap * tanh(deltap * 5)

            case .woodwind:
                // Single reed model
                let pMouth = breathPressure
                let pBore = voice.delayLine1.read(delay: 0)
                let x = pMouth - pBore
                excitation = min(1, max(-1, x * 3)) * (1 - abs(x))

            case .flute:
                // Jet-drive model
                let jetDelay = voice.delayLine2.read(delay: 5)
                let jetVelocity = breathPressure + jetDelay * 0.2
                excitation = tanh(jetVelocity * 2) + Float.random(in: -0.05...0.05)

            default:
                break
            }

            // Bore propagation
            let bore1 = voice.delayLine1.read(delay: voice.delayLine1.length - 1)
            let bore2 = voice.delayLine2.read(delay: voice.delayLine2.length - 1)

            // Bell radiation (high-pass at open end)
            let bellOutput = bore1 * (1 - brightness * 0.5)

            // Reflection at closed end (with loss)
            voice.delayLine1.write((excitation + bore2) * decay)
            voice.delayLine2.write(-bore1 * decay * 0.95)

            output[i] = bellOutput

            voice.excitationPhase += 1
        }
    }

    /// OPTIMIZED: Process modal synthesis using LUT (percussion)
    private func processModalSynth(_ voice: inout PMVoice, output: inout [Float], frameCount: Int) {
        let (frequencies, _, _) = getModalParameters(for: modelType, baseFreq: voice.frequency)
        let twoPi = PMSineLUT.twoPi

        for i in 0..<frameCount {
            var sample: Float = 0

            for m in 0..<min(voice.modalAmplitudes.count, frequencies.count) {
                // Oscillator for each mode
                voice.modalPhases[m] += frequencies[m] / sampleRate * twoPi
                if voice.modalPhases[m] > twoPi {
                    voice.modalPhases[m] -= twoPi
                }

                // OPTIMIZED: Use LUT instead of sin()
                sample += PMSineLUT.sin(voice.modalPhases[m]) * voice.modalAmplitudes[m]

                // Apply decay
                voice.modalAmplitudes[m] *= voice.modalDecays[m]
            }

            output[i] = sample
        }

        // Check if all modes have decayed
        if voice.modalAmplitudes.max() ?? 0 < 0.0001 {
            voice.isActive = false
        }
    }

    /// Process drum membrane
    private func processMembrane(_ voice: inout PMVoice, output: inout [Float], frameCount: Int) {
        for i in 0..<frameCount {
            // Read from both delay lines (2D modes)
            let mode1 = voice.delayLine1.read(delay: voice.delayLine1.length - 1)
            let mode2 = voice.delayLine2.read(delay: voice.delayLine2.length - 1)

            // Low-pass for membrane damping
            voice.lpfState = damping * (mode1 + mode2) + (1 - damping) * voice.lpfState

            // Write back with coupling
            voice.delayLine1.write(-mode1 * decay + mode2 * 0.1)
            voice.delayLine2.write(-mode2 * decay * 0.95 + mode1 * 0.1)

            output[i] = voice.lpfState
        }
    }

    /// OPTIMIZED: Apply body resonance filter using LUT
    private func applyBodyResonance(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Two resonant filters simulating body resonances
        let freq1: Float = 250
        let freq2: Float = 450
        let q: Float = 5

        let w1 = PMSineLUT.twoPi * freq1 / sampleRate
        let w2 = PMSineLUT.twoPi * freq2 / sampleRate
        // OPTIMIZED: Use LUT instead of sin()
        let alpha1 = PMSineLUT.sin(w1) / (2 * q)
        let alpha2 = PMSineLUT.sin(w2) / (2 * q)

        for i in 0..<frameCount {
            let input = buffer[i]

            // Simple resonant filter approximation
            bodyFilter1State = bodyFilter1State * (1 - alpha1) + input * alpha1
            bodyFilter2State = bodyFilter2State * (1 - alpha2) + input * alpha2

            let resonance = (bodyFilter1State + bodyFilter2State) * bodyResonance
            buffer[i] = input + resonance
        }
    }

    // MARK: - Utility

    /// Set sample rate
    public func setSampleRate(_ rate: Float) {
        sampleRate = rate
        reset()
    }

    /// Reset all voices
    public func reset() {
        for i in 0..<maxVoices {
            voices[i].reset()
        }
        activeVoices.removeAll()
    }

    /// Get active voice count
    public var activeVoiceCount: Int {
        return activeVoices.count
    }
}

// MARK: - Presets

extension PhysicalModelingSynth {

    /// Factory presets
    public enum PMPreset: String, CaseIterable {
        case acousticGuitar = "Acoustic Guitar"
        case electricGuitar = "Electric Guitar"
        case bass = "Bass"
        case cello = "Cello"
        case violin = "Violin"
        case harp = "Harp"
        case piano = "Piano"
        case trumpet = "Trumpet"
        case clarinet = "Clarinet"
        case flute = "Flute"
        case marimba = "Marimba"
        case vibraphone = "Vibraphone"
        case tubularBells = "Tubular Bells"
        case steelDrum = "Steel Drum"
        case kalimba = "Kalimba"
        case sitar = "Sitar"

        public func apply(to synth: PhysicalModelingSynth) {
            switch self {
            case .acousticGuitar:
                synth.modelType = .pluckedString
                synth.excitationType = .pluck
                synth.brightness = 0.7
                synth.decay = 0.995
                synth.damping = 0.4
                synth.pluckPosition = 0.25
                synth.bodyResonance = 0.4
                synth.inharmonicity = 0.0001

            case .electricGuitar:
                synth.modelType = .pluckedString
                synth.excitationType = .pluck
                synth.brightness = 0.85
                synth.decay = 0.997
                synth.damping = 0.3
                synth.pluckPosition = 0.2
                synth.bodyResonance = 0.1
                synth.inharmonicity = 0.0002

            case .bass:
                synth.modelType = .pluckedString
                synth.excitationType = .pluck
                synth.brightness = 0.5
                synth.decay = 0.993
                synth.damping = 0.5
                synth.pluckPosition = 0.15
                synth.bodyResonance = 0.5
                synth.inharmonicity = 0.0003

            case .cello:
                synth.modelType = .bowedString
                synth.excitationType = .bow
                synth.brightness = 0.6
                synth.decay = 0.998
                synth.bowPressure = 0.5
                synth.bowSpeed = 0.12
                synth.bodyResonance = 0.4

            case .violin:
                synth.modelType = .bowedString
                synth.excitationType = .bow
                synth.brightness = 0.75
                synth.decay = 0.998
                synth.bowPressure = 0.4
                synth.bowSpeed = 0.15
                synth.bodyResonance = 0.35

            case .harp:
                synth.modelType = .pluckedString
                synth.excitationType = .pluck
                synth.brightness = 0.8
                synth.decay = 0.996
                synth.damping = 0.2
                synth.pluckPosition = 0.1
                synth.bodyResonance = 0.3
                synth.inharmonicity = 0.00005

            case .piano:
                synth.modelType = .struckString
                synth.excitationType = .hammer
                synth.brightness = 0.7
                synth.decay = 0.998
                synth.pluckPosition = 0.12
                synth.bodyResonance = 0.45
                synth.inharmonicity = 0.0004

            case .trumpet:
                synth.modelType = .brass
                synth.brightness = 0.8
                synth.decay = 0.99
                synth.bowPressure = 0.6

            case .clarinet:
                synth.modelType = .woodwind
                synth.brightness = 0.65
                synth.decay = 0.995
                synth.bowPressure = 0.5

            case .flute:
                synth.modelType = .flute
                synth.brightness = 0.9
                synth.decay = 0.99
                synth.bowPressure = 0.4

            case .marimba:
                synth.modelType = .marimba
                synth.brightness = 0.6
                synth.decay = 0.998
                synth.bodyResonance = 0.5

            case .vibraphone:
                synth.modelType = .bar
                synth.brightness = 0.75
                synth.decay = 0.9995
                synth.bodyResonance = 0.3

            case .tubularBells:
                synth.modelType = .bell
                synth.brightness = 0.85
                synth.decay = 0.9998
                synth.bodyResonance = 0.2

            case .steelDrum:
                synth.modelType = .membrane
                synth.brightness = 0.7
                synth.decay = 0.995
                synth.damping = 0.4
                synth.bodyResonance = 0.4

            case .kalimba:
                synth.modelType = .bar
                synth.brightness = 0.8
                synth.decay = 0.996
                synth.bodyResonance = 0.35

            case .sitar:
                synth.modelType = .pluckedString
                synth.excitationType = .pluck
                synth.brightness = 0.85
                synth.decay = 0.997
                synth.pluckPosition = 0.05
                synth.bodyResonance = 0.5
                synth.inharmonicity = 0.001  // Sympathetic strings simulation
            }
        }
    }

    /// Apply preset
    public func applyPreset(_ preset: PMPreset) {
        preset.apply(to: self)
    }
}

// MARK: - Extensions for Complex Physics

extension PhysicalModelingSynth {

    /// Sympathetic string resonance (for sitar, piano, etc.)
    public struct SympatheticString {
        var frequency: Float
        var resonance: Float
        var decay: Float
        var amplitude: Float = 0

        mutating func update(input: Float) {
            // Simple resonant filter
            let diff = input - amplitude
            amplitude += diff * resonance
            amplitude *= decay
        }
    }

    /// Create sympathetic strings for current frequency
    public func createSympatheticStrings(baseFreq: Float, count: Int = 5) -> [SympatheticString] {
        return (1...count).map { harmonic in
            SympatheticString(
                frequency: baseFreq * Float(harmonic),
                resonance: 0.1 / Float(harmonic),
                decay: 0.9995
            )
        }
    }
}
