// ModularSynthesisEngine.swift
// Echoelmusic - Virtual Modular Synthesizer
// Created by Claude (Phase 4) - December 2025

import Foundation
import Accelerate
import simd

// MARK: - Module Types

/// Types of modules available in the modular system
public enum ModuleType: String, Codable, CaseIterable {
    // Oscillators
    case vco = "VCO"              // Voltage Controlled Oscillator
    case lfo = "LFO"              // Low Frequency Oscillator
    case noiseGen = "Noise"       // Noise Generator
    case wavetable = "Wavetable"  // Wavetable Oscillator

    // Filters
    case vcf = "VCF"              // Voltage Controlled Filter
    case lpg = "LPG"              // Low Pass Gate
    case svf = "SVF"              // State Variable Filter
    case comb = "Comb"            // Comb Filter

    // Envelopes & Modulation
    case adsr = "ADSR"            // Envelope Generator
    case ar = "AR"                // Attack-Release
    case envelope = "Envelope"     // Complex Envelope
    case slew = "Slew"            // Slew Limiter
    case sh = "S&H"               // Sample and Hold

    // VCAs & Mixing
    case vca = "VCA"              // Voltage Controlled Amplifier
    case mixer = "Mixer"          // 4-channel Mixer
    case attenuverter = "Atten"   // Attenuverter
    case crossfader = "XFade"     // Crossfader

    // Utilities
    case mult = "Mult"            // Multiple/Splitter
    case quantizer = "Quant"      // Pitch Quantizer
    case clockDiv = "ClkDiv"      // Clock Divider
    case logic = "Logic"          // Logic Gates
    case sequencer = "Seq"        // Step Sequencer

    // Effects
    case delay = "Delay"          // Delay Line
    case reverb = "Reverb"        // Reverb
    case distortion = "Dist"      // Waveshaper/Distortion
    case chorus = "Chorus"        // Chorus/Ensemble

    // I/O
    case audioIn = "Audio In"
    case audioOut = "Audio Out"
    case midiIn = "MIDI In"
    case cvIn = "CV In"
    case cvOut = "CV Out"
}

// MARK: - Jack Types

/// Types of input/output jacks
public enum JackType: String, Codable {
    case audio = "Audio"      // Audio rate signal
    case cv = "CV"            // Control voltage
    case gate = "Gate"        // Gate/trigger
    case clock = "Clock"      // Clock signal
}

// MARK: - Module Base

/// Base class for all modules
open class Module: Identifiable, Codable {
    public let id: UUID
    public let type: ModuleType
    public var name: String
    public var position: CGPoint

    // Inputs and outputs
    public var inputs: [Jack]
    public var outputs: [Jack]

    // Parameters
    public var parameters: [String: Float]

    public init(type: ModuleType, name: String? = nil) {
        self.id = UUID()
        self.type = type
        self.name = name ?? type.rawValue
        self.position = .zero
        self.inputs = []
        self.outputs = []
        self.parameters = [:]
    }

    /// Process one sample
    open func process(sampleRate: Float) -> Float {
        return 0
    }

    /// Get input value (from connected cable or default)
    public func getInput(_ name: String, default defaultValue: Float = 0) -> Float {
        guard let input = inputs.first(where: { $0.name == name }) else {
            return defaultValue
        }
        return input.value ?? defaultValue
    }

    /// Set output value
    public func setOutput(_ name: String, value: Float) {
        guard let index = outputs.firstIndex(where: { $0.name == name }) else { return }
        outputs[index].value = value
    }
}

// MARK: - Jack

/// Input or output jack on a module
public struct Jack: Identifiable, Codable {
    public let id: UUID
    public let moduleId: UUID
    public var name: String
    public var type: JackType
    public var isInput: Bool
    public var value: Float?
    public var connectedTo: UUID?  // Connected jack ID

    public init(moduleId: UUID, name: String, type: JackType, isInput: Bool) {
        self.id = UUID()
        self.moduleId = moduleId
        self.name = name
        self.type = type
        self.isInput = isInput
    }
}

// MARK: - Cable

/// Connection between two jacks
public struct Cable: Identifiable, Codable {
    public let id: UUID
    public let sourceJackId: UUID
    public let destJackId: UUID
    public var color: CableColor

    public init(source: UUID, dest: UUID, color: CableColor = .red) {
        self.id = UUID()
        self.sourceJackId = source
        self.destJackId = dest
        self.color = color
    }
}

public enum CableColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, blue, purple, white, black
}

// MARK: - Oscillator Module

public final class VCOModule: Module {
    public enum Waveform: String, Codable, CaseIterable {
        case sine, triangle, saw, square, pulse
    }

    private var phase: Float = 0
    private var syncPhase: Float = 0

    public init() {
        super.init(type: .vco, name: "VCO")

        inputs = [
            Jack(moduleId: id, name: "V/Oct", type: .cv, isInput: true),
            Jack(moduleId: id, name: "FM", type: .cv, isInput: true),
            Jack(moduleId: id, name: "PWM", type: .cv, isInput: true),
            Jack(moduleId: id, name: "Sync", type: .audio, isInput: true)
        ]

        outputs = [
            Jack(moduleId: id, name: "Sine", type: .audio, isInput: false),
            Jack(moduleId: id, name: "Tri", type: .audio, isInput: false),
            Jack(moduleId: id, name: "Saw", type: .audio, isInput: false),
            Jack(moduleId: id, name: "Square", type: .audio, isInput: false)
        ]

        parameters = [
            "frequency": 440,    // Base frequency
            "fmAmount": 0,       // FM modulation depth
            "pulseWidth": 0.5,   // Pulse width
            "octave": 0,         // Octave offset
            "fine": 0            // Fine tune (cents)
        ]
    }

    public override func process(sampleRate: Float) -> Float {
        // Get CV inputs
        let vOct = getInput("V/Oct", default: 0)
        let fm = getInput("FM", default: 0) * parameters["fmAmount"]!
        let pwm = getInput("PWM", default: 0)
        let sync = getInput("Sync", default: 0)

        // Calculate frequency
        let baseFreq = parameters["frequency"]!
        let octave = parameters["octave"]!
        let fine = parameters["fine"]! / 1200  // Cents to ratio

        let freq = baseFreq * pow(2, vOct + octave + fine) + fm * baseFreq

        // Hard sync
        if sync > 0.5 && syncPhase < 0.5 {
            phase = 0
        }
        syncPhase = sync

        // Increment phase
        let phaseInc = freq / sampleRate
        phase += phaseInc
        if phase >= 1 { phase -= 1 }

        // Calculate pulse width
        let pw = max(0.01, min(0.99, parameters["pulseWidth"]! + pwm * 0.4))

        // Generate waveforms
        let sine = sin(phase * 2 * .pi)
        let triangle = 4 * abs(phase - 0.5) - 1
        let saw = 2 * phase - 1
        let square: Float = phase < pw ? 1 : -1

        // Set outputs
        setOutput("Sine", value: sine)
        setOutput("Tri", value: triangle)
        setOutput("Saw", value: saw)
        setOutput("Square", value: square)

        return saw  // Default output
    }
}

// MARK: - Filter Module

public final class VCFModule: Module {
    public enum FilterMode: String, Codable, CaseIterable {
        case lowpass, highpass, bandpass, notch
    }

    // State variables for filter
    private var lp: Float = 0
    private var bp: Float = 0
    private var hp: Float = 0

    public init() {
        super.init(type: .vcf, name: "VCF")

        inputs = [
            Jack(moduleId: id, name: "In", type: .audio, isInput: true),
            Jack(moduleId: id, name: "Cutoff CV", type: .cv, isInput: true),
            Jack(moduleId: id, name: "Res CV", type: .cv, isInput: true),
            Jack(moduleId: id, name: "FM", type: .cv, isInput: true)
        ]

        outputs = [
            Jack(moduleId: id, name: "LP", type: .audio, isInput: false),
            Jack(moduleId: id, name: "HP", type: .audio, isInput: false),
            Jack(moduleId: id, name: "BP", type: .audio, isInput: false),
            Jack(moduleId: id, name: "Notch", type: .audio, isInput: false)
        ]

        parameters = [
            "cutoff": 1000,      // Cutoff frequency
            "resonance": 0.5,   // Resonance (0-1)
            "drive": 0,         // Input drive
            "cvAmount": 1       // CV modulation amount
        ]
    }

    public override func process(sampleRate: Float) -> Float {
        let input = getInput("In", default: 0)
        let cutoffCV = getInput("Cutoff CV", default: 0)
        let resCV = getInput("Res CV", default: 0)
        let fm = getInput("FM", default: 0)

        // Calculate cutoff
        let baseCutoff = parameters["cutoff"]!
        let cvAmount = parameters["cvAmount"]!
        var cutoff = baseCutoff * pow(2, cutoffCV * cvAmount + fm)
        cutoff = max(20, min(20000, cutoff))

        // Calculate resonance
        var resonance = parameters["resonance"]! + resCV * 0.3
        resonance = max(0, min(0.99, resonance))

        // State variable filter
        let f = 2 * sin(.pi * cutoff / sampleRate)
        let q = 1 - resonance

        // Apply drive
        let drive = parameters["drive"]!
        let drivenInput = tanh(input * (1 + drive * 4))

        // Filter calculation
        hp = drivenInput - lp - q * bp
        bp += f * hp
        lp += f * bp

        // Notch
        let notch = hp + lp

        // Set outputs
        setOutput("LP", value: lp)
        setOutput("HP", value: hp)
        setOutput("BP", value: bp)
        setOutput("Notch", value: notch)

        return lp  // Default output
    }
}

// MARK: - ADSR Module

public final class ADSRModule: Module {
    private enum Stage { case idle, attack, decay, sustain, release }

    private var stage: Stage = .idle
    private var envelope: Float = 0
    private var gateWasHigh = false

    public init() {
        super.init(type: .adsr, name: "ADSR")

        inputs = [
            Jack(moduleId: id, name: "Gate", type: .gate, isInput: true),
            Jack(moduleId: id, name: "Retrig", type: .gate, isInput: true)
        ]

        outputs = [
            Jack(moduleId: id, name: "Env", type: .cv, isInput: false),
            Jack(moduleId: id, name: "Inv", type: .cv, isInput: false),
            Jack(moduleId: id, name: "EOC", type: .gate, isInput: false)  // End of cycle
        ]

        parameters = [
            "attack": 0.01,     // Attack time (seconds)
            "decay": 0.1,       // Decay time
            "sustain": 0.7,     // Sustain level
            "release": 0.3      // Release time
        ]
    }

    public override func process(sampleRate: Float) -> Float {
        let gate = getInput("Gate", default: 0) > 0.5
        let retrig = getInput("Retrig", default: 0) > 0.5

        // Gate on
        if gate && !gateWasHigh {
            stage = .attack
        }
        // Gate off
        if !gate && gateWasHigh {
            stage = .release
        }
        // Retrigger
        if retrig {
            stage = .attack
        }

        gateWasHigh = gate

        // Calculate envelope
        let attack = max(0.001, parameters["attack"]!)
        let decay = max(0.001, parameters["decay"]!)
        let sustain = parameters["sustain"]!
        let release = max(0.001, parameters["release"]!)

        switch stage {
        case .idle:
            envelope = 0

        case .attack:
            let rate = 1.0 / (attack * sampleRate)
            envelope += rate
            if envelope >= 1.0 {
                envelope = 1.0
                stage = .decay
            }

        case .decay:
            let rate = 1.0 / (decay * sampleRate)
            envelope -= rate * (1.0 - sustain)
            if envelope <= sustain {
                envelope = sustain
                stage = .sustain
            }

        case .sustain:
            envelope = sustain

        case .release:
            let rate = 1.0 / (release * sampleRate)
            envelope -= rate * envelope
            if envelope <= 0.001 {
                envelope = 0
                stage = .idle
            }
        }

        // Set outputs
        setOutput("Env", value: envelope)
        setOutput("Inv", value: 1 - envelope)
        setOutput("EOC", value: stage == .idle && gateWasHigh ? 1 : 0)

        return envelope
    }
}

// MARK: - VCA Module

public final class VCAModule: Module {
    public init() {
        super.init(type: .vca, name: "VCA")

        inputs = [
            Jack(moduleId: id, name: "In", type: .audio, isInput: true),
            Jack(moduleId: id, name: "CV", type: .cv, isInput: true)
        ]

        outputs = [
            Jack(moduleId: id, name: "Out", type: .audio, isInput: false)
        ]

        parameters = [
            "gain": 1.0,        // Base gain
            "response": 0.5     // Linear (0) to exponential (1)
        ]
    }

    public override func process(sampleRate: Float) -> Float {
        let input = getInput("In", default: 0)
        var cv = getInput("CV", default: 1)

        let gain = parameters["gain"]!
        let response = parameters["response"]!

        // Apply response curve
        if response > 0 {
            cv = pow(cv, 1 + response * 3)
        }

        let output = input * cv * gain

        setOutput("Out", value: output)
        return output
    }
}

// MARK: - Sequencer Module

public final class SequencerModule: Module {
    private var currentStep: Int = 0
    private var clockWasHigh = false

    public init() {
        super.init(type: .sequencer, name: "Sequencer")

        inputs = [
            Jack(moduleId: id, name: "Clock", type: .clock, isInput: true),
            Jack(moduleId: id, name: "Reset", type: .gate, isInput: true)
        ]

        outputs = [
            Jack(moduleId: id, name: "CV", type: .cv, isInput: false),
            Jack(moduleId: id, name: "Gate", type: .gate, isInput: false)
        ]

        // 8 steps with pitch and gate
        parameters = [
            "step1": 0, "gate1": 1,
            "step2": 0.2, "gate2": 1,
            "step3": 0.4, "gate3": 1,
            "step4": 0.2, "gate4": 0,
            "step5": 0.5, "gate5": 1,
            "step6": 0.4, "gate6": 1,
            "step7": 0.7, "gate7": 1,
            "step8": 0.4, "gate8": 0,
            "length": 8,
            "direction": 0  // 0=forward, 1=backward, 2=pingpong, 3=random
        ]
    }

    public override func process(sampleRate: Float) -> Float {
        let clock = getInput("Clock", default: 0) > 0.5
        let reset = getInput("Reset", default: 0) > 0.5

        // Reset
        if reset {
            currentStep = 0
        }

        // Clock edge
        if clock && !clockWasHigh {
            let length = Int(parameters["length"]!)
            let direction = Int(parameters["direction"]!)

            switch direction {
            case 0: // Forward
                currentStep = (currentStep + 1) % length
            case 1: // Backward
                currentStep = (currentStep - 1 + length) % length
            case 2: // Ping-pong (simplified)
                currentStep = (currentStep + 1) % (length * 2)
                if currentStep >= length {
                    currentStep = length * 2 - currentStep - 1
                }
            case 3: // Random
                currentStep = Int.random(in: 0..<length)
            default:
                currentStep = (currentStep + 1) % length
            }
        }
        clockWasHigh = clock

        // Get current step values
        let stepKey = "step\(currentStep + 1)"
        let gateKey = "gate\(currentStep + 1)"

        let cv = parameters[stepKey] ?? 0
        let gate = parameters[gateKey] ?? 1

        setOutput("CV", value: cv)
        setOutput("Gate", value: gate)

        return cv
    }
}

// MARK: - LFO Module

public final class LFOModule: Module {
    private var phase: Float = 0

    public init() {
        super.init(type: .lfo, name: "LFO")

        inputs = [
            Jack(moduleId: id, name: "Rate CV", type: .cv, isInput: true),
            Jack(moduleId: id, name: "Reset", type: .gate, isInput: true)
        ]

        outputs = [
            Jack(moduleId: id, name: "Sine", type: .cv, isInput: false),
            Jack(moduleId: id, name: "Tri", type: .cv, isInput: false),
            Jack(moduleId: id, name: "Saw", type: .cv, isInput: false),
            Jack(moduleId: id, name: "Square", type: .cv, isInput: false),
            Jack(moduleId: id, name: "S&H", type: .cv, isInput: false)
        ]

        parameters = [
            "rate": 1,          // Hz
            "amplitude": 1,     // Output amplitude
            "offset": 0,        // DC offset
            "shape": 0          // Waveshape morph
        ]
    }

    public override func process(sampleRate: Float) -> Float {
        let rateCV = getInput("Rate CV", default: 0)
        let reset = getInput("Reset", default: 0) > 0.5

        if reset {
            phase = 0
        }

        // Calculate rate (exponential CV response)
        let baseRate = parameters["rate"]!
        let rate = baseRate * pow(2, rateCV * 4)

        // Increment phase
        phase += rate / sampleRate
        if phase >= 1 { phase -= 1 }

        let amp = parameters["amplitude"]!
        let offset = parameters["offset"]!

        // Generate waveforms (bipolar, -1 to 1)
        let sine = sin(phase * 2 * .pi)
        let triangle = 4 * abs(phase - 0.5) - 1
        let saw = 2 * phase - 1
        let square: Float = phase < 0.5 ? 1 : -1

        // Sample and hold (changes at phase wrap)
        let sh = Float.random(in: -1...1)

        // Apply amplitude and offset
        setOutput("Sine", value: sine * amp + offset)
        setOutput("Tri", value: triangle * amp + offset)
        setOutput("Saw", value: saw * amp + offset)
        setOutput("Square", value: square * amp + offset)
        setOutput("S&H", value: sh * amp + offset)

        return sine * amp + offset
    }
}

// MARK: - Delay Module

public final class DelayModule: Module {
    private var buffer: [Float] = []
    private var writeIndex: Int = 0
    private let maxDelaySamples = 96000  // 2 seconds at 48kHz

    public init() {
        super.init(type: .delay, name: "Delay")
        buffer = [Float](repeating: 0, count: maxDelaySamples)

        inputs = [
            Jack(moduleId: id, name: "In", type: .audio, isInput: true),
            Jack(moduleId: id, name: "Time CV", type: .cv, isInput: true),
            Jack(moduleId: id, name: "Feedback CV", type: .cv, isInput: true)
        ]

        outputs = [
            Jack(moduleId: id, name: "Out", type: .audio, isInput: false),
            Jack(moduleId: id, name: "Wet", type: .audio, isInput: false)
        ]

        parameters = [
            "time": 0.25,       // Delay time (seconds)
            "feedback": 0.5,    // Feedback amount
            "mix": 0.5,         // Dry/wet mix
            "damping": 0.3      // High frequency damping
        ]
    }

    public override func process(sampleRate: Float) -> Float {
        let input = getInput("In", default: 0)
        let timeCV = getInput("Time CV", default: 0)
        let feedbackCV = getInput("Feedback CV", default: 0)

        // Calculate delay time
        let baseTime = parameters["time"]!
        let time = baseTime * pow(2, timeCV)
        let delaySamples = Int(time * sampleRate)

        // Calculate read position
        let readIndex = (writeIndex - min(delaySamples, maxDelaySamples - 1) + maxDelaySamples) % maxDelaySamples

        // Read delayed sample
        let delayed = buffer[readIndex]

        // Calculate feedback
        let baseFeedback = parameters["feedback"]!
        let feedback = min(0.99, max(0, baseFeedback + feedbackCV * 0.3))

        // Apply damping (simple lowpass)
        let damping = parameters["damping"]!
        let dampedFeedback = delayed * (1 - damping) + buffer[(readIndex + 1) % maxDelaySamples] * damping

        // Write to buffer
        buffer[writeIndex] = input + dampedFeedback * feedback
        writeIndex = (writeIndex + 1) % maxDelaySamples

        // Mix
        let mix = parameters["mix"]!
        let output = input * (1 - mix) + delayed * mix

        setOutput("Out", value: output)
        setOutput("Wet", value: delayed)

        return output
    }
}

// MARK: - Mixer Module

public final class MixerModule: Module {
    public init() {
        super.init(type: .mixer, name: "Mixer")

        inputs = [
            Jack(moduleId: id, name: "In 1", type: .audio, isInput: true),
            Jack(moduleId: id, name: "In 2", type: .audio, isInput: true),
            Jack(moduleId: id, name: "In 3", type: .audio, isInput: true),
            Jack(moduleId: id, name: "In 4", type: .audio, isInput: true)
        ]

        outputs = [
            Jack(moduleId: id, name: "Out", type: .audio, isInput: false)
        ]

        parameters = [
            "level1": 1, "pan1": 0,
            "level2": 1, "pan2": 0,
            "level3": 1, "pan3": 0,
            "level4": 1, "pan4": 0,
            "master": 1
        ]
    }

    public override func process(sampleRate: Float) -> Float {
        var sum: Float = 0

        for i in 1...4 {
            let input = getInput("In \(i)", default: 0)
            let level = parameters["level\(i)"] ?? 1
            sum += input * level
        }

        let output = sum * (parameters["master"] ?? 1)
        setOutput("Out", value: output)

        return output
    }
}

// MARK: - Modular Synthesis Engine

/// Main modular synthesizer engine
public actor ModularSynthesisEngine {

    public static let shared = ModularSynthesisEngine()

    private var modules: [UUID: Module] = [:]
    private var cables: [UUID: Cable] = [:]
    private var processingOrder: [UUID] = []

    private let sampleRate: Float = 48000

    private init() {}

    // MARK: - Module Management

    public func addModule(_ type: ModuleType) -> Module {
        let module: Module

        switch type {
        case .vco: module = VCOModule()
        case .vcf: module = VCFModule()
        case .adsr: module = ADSRModule()
        case .vca: module = VCAModule()
        case .lfo: module = LFOModule()
        case .sequencer: module = SequencerModule()
        case .delay: module = DelayModule()
        case .mixer: module = MixerModule()
        default:
            module = Module(type: type)
        }

        modules[module.id] = module
        updateProcessingOrder()

        return module
    }

    public func removeModule(id: UUID) {
        // Remove associated cables
        cables = cables.filter { $0.value.sourceJackId != id && $0.value.destJackId != id }
        modules.removeValue(forKey: id)
        updateProcessingOrder()
    }

    public func getModule(id: UUID) -> Module? {
        modules[id]
    }

    public func getAllModules() -> [Module] {
        Array(modules.values)
    }

    // MARK: - Cable Management

    public func connect(source: UUID, dest: UUID, color: CableColor = .red) -> Cable? {
        // Find jacks
        guard let sourceJack = findJack(id: source),
              let destJack = findJack(id: dest),
              !sourceJack.isInput,
              destJack.isInput else {
            return nil
        }

        // Create cable
        let cable = Cable(source: source, dest: dest, color: color)
        cables[cable.id] = cable

        updateProcessingOrder()
        return cable
    }

    public func disconnect(cableId: UUID) {
        cables.removeValue(forKey: cableId)
        updateProcessingOrder()
    }

    public func getAllCables() -> [Cable] {
        Array(cables.values)
    }

    private func findJack(id: UUID) -> Jack? {
        for module in modules.values {
            if let jack = module.inputs.first(where: { $0.id == id }) {
                return jack
            }
            if let jack = module.outputs.first(where: { $0.id == id }) {
                return jack
            }
        }
        return nil
    }

    // MARK: - Parameter Control

    public func setParameter(moduleId: UUID, name: String, value: Float) {
        modules[moduleId]?.parameters[name] = value
    }

    public func getParameter(moduleId: UUID, name: String) -> Float? {
        modules[moduleId]?.parameters[name]
    }

    // MARK: - Processing

    private func updateProcessingOrder() {
        // Topological sort based on cable connections
        // For now, simple order by module type
        var order: [UUID] = []

        // Sources first (LFOs, Sequencers)
        for (id, module) in modules {
            if module.type == .lfo || module.type == .sequencer {
                order.append(id)
            }
        }

        // Then oscillators
        for (id, module) in modules where module.type == .vco {
            if !order.contains(id) { order.append(id) }
        }

        // Envelopes
        for (id, module) in modules where module.type == .adsr {
            if !order.contains(id) { order.append(id) }
        }

        // Filters
        for (id, module) in modules where module.type == .vcf {
            if !order.contains(id) { order.append(id) }
        }

        // VCAs
        for (id, module) in modules where module.type == .vca {
            if !order.contains(id) { order.append(id) }
        }

        // Everything else
        for id in modules.keys {
            if !order.contains(id) { order.append(id) }
        }

        processingOrder = order
    }

    public func process(frameCount: Int) -> [Float] {
        var output = [Float](repeating: 0, count: frameCount)

        for i in 0..<frameCount {
            // Propagate cable values
            for cable in cables.values {
                if let sourceModule = findModuleForJack(id: cable.sourceJackId),
                   let destModule = findModuleForJack(id: cable.destJackId),
                   let sourceJackIndex = sourceModule.outputs.firstIndex(where: { $0.id == cable.sourceJackId }),
                   let destJackIndex = destModule.inputs.firstIndex(where: { $0.id == cable.destJackId }) {
                    destModule.inputs[destJackIndex].value = sourceModule.outputs[sourceJackIndex].value
                }
            }

            // Process each module
            var sample: Float = 0
            for moduleId in processingOrder {
                if let module = modules[moduleId] {
                    let moduleSample = module.process(sampleRate: sampleRate)

                    // Mix audio outputs
                    if module.type == .vca || module.type == .mixer {
                        sample += moduleSample
                    }
                }
            }

            output[i] = sample
        }

        return output
    }

    private func findModuleForJack(id: UUID) -> Module? {
        for module in modules.values {
            if module.inputs.contains(where: { $0.id == id }) ||
               module.outputs.contains(where: { $0.id == id }) {
                return module
            }
        }
        return nil
    }

    // MARK: - Presets

    public struct Patch: Codable {
        var modules: [Module]
        var cables: [Cable]
        var name: String
    }

    public func savePatch(name: String) -> Patch {
        Patch(
            modules: Array(modules.values),
            cables: Array(cables.values),
            name: name
        )
    }

    public func loadPatch(_ patch: Patch) {
        modules.removeAll()
        cables.removeAll()

        for module in patch.modules {
            modules[module.id] = module
        }

        for cable in patch.cables {
            cables[cable.id] = cable
        }

        updateProcessingOrder()
    }

    // MARK: - Factory Presets

    public func createBasicSynthPatch() async {
        // Create modules
        let vco = addModule(.vco)
        let vcf = addModule(.vcf)
        let adsr = addModule(.adsr)
        let vca = addModule(.vca)
        let lfo = addModule(.lfo)

        // Set parameters
        setParameter(moduleId: vco.id, name: "frequency", value: 220)
        setParameter(moduleId: vcf.id, name: "cutoff", value: 800)
        setParameter(moduleId: vcf.id, name: "resonance", value: 0.6)
        setParameter(moduleId: adsr.id, name: "attack", value: 0.01)
        setParameter(moduleId: adsr.id, name: "decay", value: 0.2)
        setParameter(moduleId: adsr.id, name: "sustain", value: 0.5)
        setParameter(moduleId: adsr.id, name: "release", value: 0.3)
        setParameter(moduleId: lfo.id, name: "rate", value: 0.5)

        // Connect VCO -> VCF -> VCA
        if let vcoOut = vco.outputs.first(where: { $0.name == "Saw" }),
           let vcfIn = vcf.inputs.first(where: { $0.name == "In" }) {
            _ = connect(source: vcoOut.id, dest: vcfIn.id, color: .yellow)
        }

        if let vcfOut = vcf.outputs.first(where: { $0.name == "LP" }),
           let vcaIn = vca.inputs.first(where: { $0.name == "In" }) {
            _ = connect(source: vcfOut.id, dest: vcaIn.id, color: .orange)
        }

        // Connect ADSR -> VCA CV
        if let envOut = adsr.outputs.first(where: { $0.name == "Env" }),
           let vcaCV = vca.inputs.first(where: { $0.name == "CV" }) {
            _ = connect(source: envOut.id, dest: vcaCV.id, color: .blue)
        }

        // Connect LFO -> Filter cutoff
        if let lfoOut = lfo.outputs.first(where: { $0.name == "Sine" }),
           let vcfCV = vcf.inputs.first(where: { $0.name == "Cutoff CV" }) {
            _ = connect(source: lfoOut.id, dest: vcfCV.id, color: .green)
        }
    }
}
