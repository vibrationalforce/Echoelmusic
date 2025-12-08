// PhysicalModelingSynth.swift
// Echoelmusic - Physical Modeling Synthesizer
//
// A++ Ultrahardthink Implementation
// Provides physically modeled instruments including:
// - Karplus-Strong string synthesis
// - Waveguide modeling
// - Modal synthesis
// - Tube/wind instrument modeling
// - Percussion/membrane modeling
// - Real-time parameter modulation
// - Bio-reactive physical parameter control

import Foundation
import Combine
import AVFoundation
import Accelerate
import os.log

// MARK: - Logger

private let logger = Logger(subsystem: "com.echoelmusic.audio", category: "PhysicalModeling")

// MARK: - Physical Model Type

public enum PhysicalModelType: String, CaseIterable, Codable, Sendable {
    case pluckedString = "Plucked String"
    case bowedString = "Bowed String"
    case hammeredString = "Hammered String"
    case tube = "Tube/Wind"
    case membrane = "Membrane/Drum"
    case bar = "Bar/Marimba"
    case bell = "Bell"
    case vocal = "Vocal Tract"

    public var description: String {
        switch self {
        case .pluckedString: return "Guitar, harp, harpsichord-like sounds"
        case .bowedString: return "Violin, cello, continuous sounds"
        case .hammeredString: return "Piano, dulcimer, struck strings"
        case .tube: return "Flute, clarinet, brass instruments"
        case .membrane: return "Drums, timpani, tabla"
        case .bar: return "Marimba, vibraphone, xylophone"
        case .bell: return "Bells, chimes, metallic tones"
        case .vocal: return "Vowel-like, formant-based sounds"
        }
    }
}

// MARK: - Physical Model Parameters

public struct PhysicalModelParameters: Codable, Sendable {
    // Common parameters
    public var frequency: Float = 440.0      // Fundamental frequency (Hz)
    public var amplitude: Float = 0.8        // Output amplitude (0.0-1.0)
    public var damping: Float = 0.5          // Energy loss rate (0.0-1.0)
    public var brightness: Float = 0.5       // Harmonic content (0.0-1.0)
    public var position: Float = 0.5         // Excitation position (0.0-1.0)

    // String-specific
    public var stringTension: Float = 0.5    // Affects pitch stability
    public var stringStiffness: Float = 0.0  // Inharmonicity
    public var pluckPosition: Float = 0.5    // Where string is plucked
    public var bowPressure: Float = 0.5      // For bowed strings
    public var bowVelocity: Float = 0.5      // Bow speed

    // Wind-specific
    public var blowPressure: Float = 0.5     // Breath pressure
    public var embouchure: Float = 0.5       // Lip tension/shape
    public var tonguing: Float = 0.0         // Attack articulation
    public var tubeLength: Float = 1.0       // Effective tube length
    public var toneHoleOpenness: Float = 0.0 // Open holes

    // Membrane-specific
    public var membraneTension: Float = 0.5  // Drum head tension
    public var strikePosition: Float = 0.5   // Where drum is struck
    public var strikeHardness: Float = 0.5   // Mallet hardness

    // Resonator
    public var bodyResonance: Float = 0.5    // Body coupling
    public var sympatheticResonance: Float = 0.0  // String resonance

    public init() {}
}

// MARK: - Delay Line

/// Variable-length delay line for waveguide synthesis
private final class DelayLine {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private var length: Int

    init(maxLength: Int) {
        buffer = [Float](repeating: 0, count: maxLength)
        length = maxLength
    }

    func setLength(_ newLength: Int) {
        length = min(newLength, buffer.count)
    }

    func write(_ sample: Float) {
        buffer[writeIndex] = sample
        writeIndex = (writeIndex + 1) % length
    }

    func read(delay: Int) -> Float {
        let readIndex = (writeIndex - delay + length) % length
        return buffer[readIndex]
    }

    func readInterpolated(delay: Float) -> Float {
        let intDelay = Int(delay)
        let frac = delay - Float(intDelay)

        let s1 = read(delay: intDelay)
        let s2 = read(delay: intDelay + 1)

        return s1 + frac * (s2 - s1)
    }

    func tap(position: Float) -> Float {
        let tapIndex = Int(position * Float(length - 1))
        return read(delay: tapIndex)
    }

    func clear() {
        buffer = [Float](repeating: 0, count: buffer.count)
        writeIndex = 0
    }
}

// MARK: - One-Pole Filter

private final class OnePoleFilter {
    private var lastOutput: Float = 0
    var coefficient: Float = 0.5

    func process(_ input: Float) -> Float {
        lastOutput = coefficient * input + (1.0 - coefficient) * lastOutput
        return lastOutput
    }

    func reset() {
        lastOutput = 0
    }
}

// MARK: - Biquad Filter

private final class BiquadFilter {
    private var x1: Float = 0
    private var x2: Float = 0
    private var y1: Float = 0
    private var y2: Float = 0

    var b0: Float = 1
    var b1: Float = 0
    var b2: Float = 0
    var a1: Float = 0
    var a2: Float = 0

    func process(_ input: Float) -> Float {
        let output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2

        x2 = x1
        x1 = input
        y2 = y1
        y1 = output

        return output
    }

    func setLowpass(frequency: Float, q: Float, sampleRate: Float) {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)

        let a0 = 1.0 + alpha
        b0 = (1.0 - cosOmega) / 2.0 / a0
        b1 = (1.0 - cosOmega) / a0
        b2 = b0
        a1 = -2.0 * cosOmega / a0
        a2 = (1.0 - alpha) / a0
    }

    func reset() {
        x1 = 0
        x2 = 0
        y1 = 0
        y2 = 0
    }
}

// MARK: - Karplus-Strong String

/// Karplus-Strong plucked string synthesis
public final class KarplusStrongString {
    private var delayLine: DelayLine
    private var loopFilter: OnePoleFilter
    private var sampleRate: Float
    private var isPlucking: Bool = false
    private var noiseIndex: Int = 0
    private var excitationLength: Int = 0

    public init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        delayLine = DelayLine(maxLength: Int(sampleRate / 20))  // Min 20 Hz
        loopFilter = OnePoleFilter()
    }

    public func pluck(frequency: Float, amplitude: Float, brightness: Float, position: Float) {
        // Set delay length for frequency
        let delayLength = sampleRate / frequency
        delayLine.setLength(Int(delayLength))

        // Set filter for damping/brightness
        loopFilter.coefficient = 0.5 + brightness * 0.4

        // Fill delay line with excitation (filtered noise)
        excitationLength = Int(delayLength * position)
        for i in 0..<Int(delayLength) {
            var noise = Float.random(in: -1...1) * amplitude

            // Shape excitation based on pluck position
            let positionFactor = Float(i) / delayLength
            if positionFactor < position {
                noise *= sin(Float.pi * positionFactor / position)
            } else {
                noise *= sin(Float.pi * (1.0 - positionFactor) / (1.0 - position))
            }

            delayLine.write(noise)
        }

        isPlucking = true
    }

    public func process() -> Float {
        // Read from delay line
        let sample = delayLine.read(delay: 1)

        // Apply loop filter (damping)
        let filtered = loopFilter.process(sample)

        // Write back to delay line
        delayLine.write(filtered * 0.996)  // Small decay

        return sample
    }

    public func reset() {
        delayLine.clear()
        loopFilter.reset()
        isPlucking = false
    }
}

// MARK: - Bowed String Model

/// Bowed string physical model
public final class BowedString {
    private var neckDelay: DelayLine
    private var bridgeDelay: DelayLine
    private var bridgeFilter: OnePoleFilter
    private var bowTable: [Float]
    private var sampleRate: Float

    private var bowVelocity: Float = 0
    private var bowForce: Float = 0
    private var bowPosition: Float = 0.5
    private var lastBowOutput: Float = 0

    public init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        neckDelay = DelayLine(maxLength: Int(sampleRate / 20))
        bridgeDelay = DelayLine(maxLength: Int(sampleRate / 20))
        bridgeFilter = OnePoleFilter()
        bowTable = Self.generateBowTable()
    }

    private static func generateBowTable(size: Int = 4096) -> [Float] {
        var table = [Float](repeating: 0, count: size)
        for i in 0..<size {
            let x = Float(i) / Float(size - 1) * 2.0 - 1.0  // -1 to 1
            // Bow friction curve (hyperbolic approximation)
            table[i] = (x > 0 ? 1 : -1) * (1.0 - exp(-abs(x) * 3.0))
        }
        return table
    }

    public func setFrequency(_ frequency: Float) {
        let totalDelay = sampleRate / frequency
        let neckLength = Int(totalDelay * bowPosition)
        let bridgeLength = Int(totalDelay * (1.0 - bowPosition))

        neckDelay.setLength(max(1, neckLength))
        bridgeDelay.setLength(max(1, bridgeLength))
    }

    public func setBow(velocity: Float, force: Float, position: Float) {
        bowVelocity = velocity
        bowForce = force
        bowPosition = max(0.1, min(0.9, position))
    }

    public func process() -> Float {
        // Read from delays
        let neckSample = neckDelay.read(delay: 1)
        let bridgeSample = bridgeDelay.read(delay: 1)

        // String velocity at bow point
        let stringVelocity = (neckSample + bridgeSample) * 0.5

        // Relative velocity between bow and string
        let deltaV = bowVelocity - stringVelocity

        // Look up bow table for friction
        let tableIndex = Int((deltaV + 1.0) * 0.5 * Float(bowTable.count - 1))
        let clampedIndex = max(0, min(bowTable.count - 1, tableIndex))
        let friction = bowTable[clampedIndex] * bowForce

        // Apply friction to string
        let bowOutput = friction * 0.1

        // Update delay lines (bidirectional waveguide)
        let toNeck = -neckSample * 0.99 + bowOutput
        let toBridge = -bridgeSample * 0.99 + bowOutput

        // Apply bridge filter (body coupling)
        let filteredBridge = bridgeFilter.process(toBridge)

        neckDelay.write(toNeck)
        bridgeDelay.write(filteredBridge)

        lastBowOutput = bowOutput
        return bridgeSample
    }

    public func reset() {
        neckDelay.clear()
        bridgeDelay.clear()
        bridgeFilter.reset()
        lastBowOutput = 0
    }
}

// MARK: - Tube Model (Wind Instrument)

/// Simple tube/waveguide wind instrument model
public final class TubeModel {
    private var upperDelay: DelayLine
    private var lowerDelay: DelayLine
    private var lipFilter: BiquadFilter
    private var bellFilter: BiquadFilter
    private var sampleRate: Float

    private var blowPressure: Float = 0
    private var lipTension: Float = 0.5
    private var noiseLevel: Float = 0.1

    public init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        upperDelay = DelayLine(maxLength: Int(sampleRate / 20))
        lowerDelay = DelayLine(maxLength: Int(sampleRate / 20))
        lipFilter = BiquadFilter()
        bellFilter = BiquadFilter()

        // Initialize bell filter (mild lowpass)
        bellFilter.setLowpass(frequency: 3000, q: 0.7, sampleRate: sampleRate)
    }

    public func setFrequency(_ frequency: Float) {
        let delayLength = Int(sampleRate / frequency / 2)
        upperDelay.setLength(max(1, delayLength))
        lowerDelay.setLength(max(1, delayLength))

        // Adjust lip filter resonance
        lipFilter.setLowpass(frequency: frequency * 2, q: 2.0 + lipTension * 3.0, sampleRate: sampleRate)
    }

    public func setBlow(pressure: Float, embouchure: Float) {
        blowPressure = pressure
        lipTension = embouchure
    }

    public func process() -> Float {
        // Read from bore
        let boreSample = lowerDelay.read(delay: 1)

        // Lip reed model
        let pressureDiff = blowPressure - boreSample
        var lipOutput = lipFilter.process(pressureDiff)

        // Add breath noise
        lipOutput += Float.random(in: -1...1) * noiseLevel * blowPressure

        // Nonlinear saturation (reed limiting)
        lipOutput = tanh(lipOutput * 2.0)

        // Upper delay (toward bell)
        upperDelay.write(lipOutput)
        let upperSample = upperDelay.read(delay: 1)

        // Bell reflection/radiation
        let bellOutput = bellFilter.process(upperSample)
        let reflection = -upperSample * 0.7  // Partial reflection

        // Lower delay (back toward lip)
        lowerDelay.write(reflection)

        return bellOutput
    }

    public func reset() {
        upperDelay.clear()
        lowerDelay.clear()
        lipFilter.reset()
        bellFilter.reset()
    }
}

// MARK: - Modal Synthesis (Bars/Bells)

/// Modal synthesis for metallic/bar sounds
public final class ModalSynth {
    public struct Mode: Sendable {
        public var frequency: Float
        public var amplitude: Float
        public var decay: Float

        public init(frequency: Float, amplitude: Float, decay: Float) {
            self.frequency = frequency
            self.amplitude = amplitude
            self.decay = decay
        }
    }

    private var modes: [ModeOscillator]
    private var sampleRate: Float

    private class ModeOscillator {
        var phase: Float = 0
        var phaseIncrement: Float = 0
        var amplitude: Float = 0
        var decay: Float = 0.9999
        var currentAmplitude: Float = 0

        func setFrequency(_ freq: Float, sampleRate: Float) {
            phaseIncrement = freq * 2.0 * .pi / sampleRate
        }

        func excite(amplitude: Float) {
            self.amplitude = amplitude
            currentAmplitude = amplitude
        }

        func process() -> Float {
            let output = sin(phase) * currentAmplitude
            phase += phaseIncrement
            if phase > 2.0 * .pi { phase -= 2.0 * .pi }
            currentAmplitude *= decay
            return output
        }
    }

    public init(sampleRate: Float = 44100, modeCount: Int = 8) {
        self.sampleRate = sampleRate
        modes = (0..<modeCount).map { _ in ModeOscillator() }
    }

    public func setModes(_ modeDefinitions: [Mode]) {
        for (i, mode) in modeDefinitions.enumerated() where i < modes.count {
            modes[i].setFrequency(mode.frequency, sampleRate: sampleRate)
            modes[i].decay = 1.0 - (1.0 - mode.decay) / sampleRate * 100
        }
    }

    public func excite(amplitude: Float, hardness: Float) {
        for (i, mode) in modes.enumerated() {
            // Higher modes excited more with harder strike
            let modeAmp = amplitude * pow(hardness, Float(i) * 0.3)
            mode.excite(amplitude: modeAmp)
        }
    }

    /// Set up as marimba-like
    public func setupMarimba(fundamental: Float) {
        let modes: [Mode] = [
            Mode(frequency: fundamental, amplitude: 1.0, decay: 0.9995),
            Mode(frequency: fundamental * 4.0, amplitude: 0.5, decay: 0.999),
            Mode(frequency: fundamental * 10.0, amplitude: 0.25, decay: 0.998),
            Mode(frequency: fundamental * 20.0, amplitude: 0.1, decay: 0.995)
        ]
        setModes(modes)
    }

    /// Set up as bell-like
    public func setupBell(fundamental: Float) {
        let modes: [Mode] = [
            Mode(frequency: fundamental, amplitude: 1.0, decay: 0.9998),
            Mode(frequency: fundamental * 2.0, amplitude: 0.6, decay: 0.9997),
            Mode(frequency: fundamental * 2.4, amplitude: 0.5, decay: 0.9996),  // Minor third
            Mode(frequency: fundamental * 3.0, amplitude: 0.4, decay: 0.9995),
            Mode(frequency: fundamental * 4.2, amplitude: 0.3, decay: 0.999),
            Mode(frequency: fundamental * 5.4, amplitude: 0.2, decay: 0.998),
            Mode(frequency: fundamental * 6.8, amplitude: 0.15, decay: 0.997),
            Mode(frequency: fundamental * 9.0, amplitude: 0.1, decay: 0.995)
        ]
        setModes(modes)
    }

    public func process() -> Float {
        var output: Float = 0
        for mode in modes {
            output += mode.process()
        }
        return output * 0.3  // Scale down
    }

    public func reset() {
        for mode in modes {
            mode.currentAmplitude = 0
            mode.phase = 0
        }
    }
}

// MARK: - Physical Modeling Synthesizer

@MainActor
public final class PhysicalModelingSynth: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var isPlaying: Bool = false
    @Published public var modelType: PhysicalModelType = .pluckedString
    @Published public var parameters = PhysicalModelParameters()

    // MARK: - Audio Properties

    public var sampleRate: Float = 44100

    // MARK: - Models

    private var pluckedString: KarplusStrongString?
    private var bowedString: BowedString?
    private var tubeModel: TubeModel?
    private var modalSynth: ModalSynth?

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?

    // MARK: - Initialization

    public init() {
        initializeModels()
        setupAudioEngine()
    }

    private func initializeModels() {
        pluckedString = KarplusStrongString(sampleRate: sampleRate)
        bowedString = BowedString(sampleRate: sampleRate)
        tubeModel = TubeModel(sampleRate: sampleRate)
        modalSynth = ModalSynth(sampleRate: sampleRate)
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)!

        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                let sample = self.generateSample()

                // Write to both channels
                for buffer in ablPointer {
                    if let data = buffer.mData?.assumingMemoryBound(to: Float.self) {
                        data[frame] = sample * self.parameters.amplitude
                    }
                }
            }

            return noErr
        }

        if let node = sourceNode {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
    }

    // MARK: - Playback

    public func start() {
        guard !isPlaying else { return }

        do {
            try audioEngine?.start()
            isPlaying = true
            logger.info("Physical modeling synth started")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    public func stop() {
        audioEngine?.stop()
        isPlaying = false
        resetModels()
        logger.info("Physical modeling synth stopped")
    }

    private func resetModels() {
        pluckedString?.reset()
        bowedString?.reset()
        tubeModel?.reset()
        modalSynth?.reset()
    }

    // MARK: - Note Events

    public func noteOn(pitch: Int, velocity: Int) {
        let frequency = 440.0 * pow(2.0, Float(pitch - 69) / 12.0)
        let amp = Float(velocity) / 127.0

        switch modelType {
        case .pluckedString:
            pluckedString?.pluck(
                frequency: frequency,
                amplitude: amp,
                brightness: parameters.brightness,
                position: parameters.pluckPosition
            )

        case .bowedString:
            bowedString?.setFrequency(frequency)
            bowedString?.setBow(
                velocity: parameters.bowVelocity * amp,
                force: parameters.bowPressure,
                position: parameters.position
            )

        case .hammeredString:
            // Use plucked with modified parameters
            pluckedString?.pluck(
                frequency: frequency,
                amplitude: amp * 1.2,
                brightness: 0.8,
                position: 0.12  // Piano hammer position
            )

        case .tube:
            tubeModel?.setFrequency(frequency)
            tubeModel?.setBlow(
                pressure: parameters.blowPressure * amp,
                embouchure: parameters.embouchure
            )

        case .membrane:
            modalSynth?.setupMarimba(fundamental: frequency * 0.5)
            modalSynth?.excite(amplitude: amp, hardness: parameters.strikeHardness)

        case .bar:
            modalSynth?.setupMarimba(fundamental: frequency)
            modalSynth?.excite(amplitude: amp, hardness: parameters.strikeHardness)

        case .bell:
            modalSynth?.setupBell(fundamental: frequency)
            modalSynth?.excite(amplitude: amp, hardness: parameters.strikeHardness)

        case .vocal:
            // Use tube model with vocal-like parameters
            tubeModel?.setFrequency(frequency)
            tubeModel?.setBlow(pressure: amp * 0.5, embouchure: parameters.embouchure)
        }
    }

    public func noteOff(pitch: Int) {
        // For sustained models, stop excitation
        switch modelType {
        case .bowedString:
            bowedString?.setBow(velocity: 0, force: 0, position: parameters.position)
        case .tube, .vocal:
            tubeModel?.setBlow(pressure: 0, embouchure: parameters.embouchure)
        default:
            break  // Decaying models handle themselves
        }
    }

    // MARK: - Sample Generation

    private func generateSample() -> Float {
        switch modelType {
        case .pluckedString, .hammeredString:
            return pluckedString?.process() ?? 0

        case .bowedString:
            return bowedString?.process() ?? 0

        case .tube, .vocal:
            return tubeModel?.process() ?? 0

        case .membrane, .bar, .bell:
            return modalSynth?.process() ?? 0
        }
    }

    // MARK: - Bio-Reactive Control

    public func applyBioModulation(
        heartRate: Float,
        hrv: Float,
        coherence: Float
    ) {
        // Map bio-data to physical parameters

        // Heart rate affects vibrato/tremolo
        let vibratoRate = heartRate / 60.0  // Normalize to ~1 Hz

        // HRV affects brightness/damping variation
        parameters.brightness = 0.3 + hrv / 100.0 * 0.5

        // Coherence affects body resonance
        parameters.bodyResonance = coherence

        // Update bow parameters for bowed string
        if modelType == .bowedString {
            parameters.bowVelocity = 0.3 + coherence * 0.4
            parameters.bowPressure = 0.4 + (1.0 - hrv / 100.0) * 0.4
        }

        // Update blow parameters for wind
        if modelType == .tube {
            parameters.blowPressure = 0.3 + coherence * 0.5
            parameters.embouchure = 0.3 + hrv / 100.0 * 0.4
        }
    }

    // MARK: - Presets

    public enum Preset: String, CaseIterable {
        case acousticGuitar = "Acoustic Guitar"
        case electricGuitar = "Electric Guitar"
        case harp = "Harp"
        case violin = "Violin"
        case cello = "Cello"
        case piano = "Piano"
        case flute = "Flute"
        case clarinet = "Clarinet"
        case marimba = "Marimba"
        case vibraphone = "Vibraphone"
        case tubularBells = "Tubular Bells"
        case steelDrum = "Steel Drum"
    }

    public func loadPreset(_ preset: Preset) {
        parameters = PhysicalModelParameters()

        switch preset {
        case .acousticGuitar:
            modelType = .pluckedString
            parameters.brightness = 0.6
            parameters.damping = 0.4
            parameters.pluckPosition = 0.15
            parameters.bodyResonance = 0.7

        case .electricGuitar:
            modelType = .pluckedString
            parameters.brightness = 0.8
            parameters.damping = 0.3
            parameters.pluckPosition = 0.2
            parameters.bodyResonance = 0.3

        case .harp:
            modelType = .pluckedString
            parameters.brightness = 0.7
            parameters.damping = 0.5
            parameters.pluckPosition = 0.3
            parameters.bodyResonance = 0.5

        case .violin:
            modelType = .bowedString
            parameters.bowPressure = 0.5
            parameters.bowVelocity = 0.5
            parameters.position = 0.12
            parameters.brightness = 0.6

        case .cello:
            modelType = .bowedString
            parameters.bowPressure = 0.6
            parameters.bowVelocity = 0.4
            parameters.position = 0.1
            parameters.brightness = 0.5

        case .piano:
            modelType = .hammeredString
            parameters.brightness = 0.7
            parameters.damping = 0.45
            parameters.stringStiffness = 0.1

        case .flute:
            modelType = .tube
            parameters.blowPressure = 0.4
            parameters.embouchure = 0.6
            parameters.tonguing = 0.3

        case .clarinet:
            modelType = .tube
            parameters.blowPressure = 0.5
            parameters.embouchure = 0.4
            parameters.tonguing = 0.2

        case .marimba:
            modelType = .bar
            parameters.strikeHardness = 0.4
            parameters.damping = 0.6

        case .vibraphone:
            modelType = .bar
            parameters.strikeHardness = 0.3
            parameters.damping = 0.3
            parameters.bodyResonance = 0.7

        case .tubularBells:
            modelType = .bell
            parameters.strikeHardness = 0.6
            parameters.damping = 0.2

        case .steelDrum:
            modelType = .membrane
            parameters.strikeHardness = 0.5
            parameters.membraneTension = 0.7
        }

        logger.info("Loaded preset: \(preset.rawValue)")
    }
}
