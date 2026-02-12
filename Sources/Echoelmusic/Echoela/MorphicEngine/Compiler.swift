// MARK: - MorphicCompiler.swift
// Echoelmusic Suite - Echoela Morphic Engine
// Copyright 2026 Echoelmusic. All rights reserved.
//
// Morphic Logic Synthesis: Natural Language -> DSP Graph
// Echoela doesn't just control functions - she WRITES custom effects & instruments.

import Foundation
import Combine

// MARK: - Morphic DSP Node Protocol

/// A single DSP processing node in the Morphic graph
public protocol MorphicNode: AnyObject {
    var id: String { get }
    var name: String { get }
    var parameters: [MorphicParameter] { get set }
    func process(_ input: [Float]) -> [Float]
    func reset()
}

// MARK: - Morphic Parameter

/// A modulatable parameter on a DSP node
public struct MorphicParameter: Identifiable, Codable {
    public let id: String
    public let name: String
    public var value: Float
    public let range: ClosedRange<Float>
    public let defaultValue: Float
    public var bioBinding: BioBinding?

    /// Bio-reactive binding: maps a body signal to this parameter
    public struct BioBinding: Codable {
        public let source: BioSource
        public let curve: MappingCurve
        public let intensity: Float // 0-1

        public enum BioSource: String, Codable, CaseIterable {
            case heartRate
            case hrv
            case coherence
            case breathRate
            case breathPhase
        }

        public enum MappingCurve: String, Codable, CaseIterable {
            case linear
            case exponential
            case logarithmic
            case sCurve
            case sine
            case stepped
        }
    }

    public init(id: String, name: String, value: Float, range: ClosedRange<Float>, defaultValue: Float, bioBinding: BioBinding? = nil) {
        self.id = id
        self.name = name
        self.value = value
        self.range = range
        self.defaultValue = defaultValue
        self.bioBinding = bioBinding
    }
}

// MARK: - Morphic Graph

/// A compiled DSP processing graph - chain of MorphicNodes
public class MorphicGraph: Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let createdAt: Date
    public internal(set) var nodes: [MorphicNode]
    public var bioBindings: [String: MorphicParameter.BioBinding] // paramID -> binding

    public init(id: String = UUID().uuidString, name: String, description: String, nodes: [MorphicNode] = [], bioBindings: [String: MorphicParameter.BioBinding] = [:]) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = Date()
        self.nodes = nodes
        self.bioBindings = bioBindings
    }

    /// Process audio through the entire graph
    public func process(_ input: [Float]) -> [Float] {
        var signal = input
        for node in nodes {
            signal = node.process(signal)
        }
        return signal
    }

    /// Update bio-reactive parameters from body data
    public func updateBio(_ body: EchoelPulse.BodyMusic) {
        for node in nodes {
            for i in 0..<node.parameters.count {
                guard let binding = node.parameters[i].bioBinding else { continue }
                let bioValue = resolveBioSource(binding.source, from: body)
                let mapped = applyMappingCurve(bioValue, curve: binding.curve, intensity: binding.intensity)
                let range = node.parameters[i].range
                node.parameters[i].value = range.lowerBound + mapped * (range.upperBound - range.lowerBound)
            }
        }
    }

    /// Reset all nodes
    public func reset() {
        nodes.forEach { $0.reset() }
    }

    private func resolveBioSource(_ source: MorphicParameter.BioBinding.BioSource, from body: EchoelPulse.BodyMusic) -> Float {
        switch source {
        case .heartRate:   return ((body.heartRate - 40.0) / 160.0).clamped(to: 0...1)
        case .hrv:         return ((body.hrv - 10.0) / 90.0).clamped(to: 0...1)
        case .coherence:   return (body.coherence / 100.0).clamped(to: 0...1)
        case .breathRate:  return ((body.breathRate - 4.0) / 20.0).clamped(to: 0...1)
        case .breathPhase: return body.breathPhase.clamped(to: 0...1)
        }
    }

    private func applyMappingCurve(_ value: Float, curve: MorphicParameter.BioBinding.MappingCurve, intensity: Float) -> Float {
        let shaped: Float
        switch curve {
        case .linear:      shaped = value
        case .exponential: shaped = pow(value, 2.0)
        case .logarithmic: shaped = Foundation.log(1.0 + value * 9.0) / Foundation.log(10.0)
        case .sCurve:      shaped = value * value * (3.0 - 2.0 * value)
        case .sine:        shaped = (1.0 - cos(value * Float.pi)) / 2.0
        case .stepped:     shaped = (value * 8.0).rounded(.down) / 8.0
        }
        return shaped * intensity
    }
}

// MARK: - Built-in Morphic DSP Nodes

/// Gain/Volume node
public final class MorphicGainNode: MorphicNode {
    public let id: String
    public let name = "Gain"
    public var parameters: [MorphicParameter]

    public init(id: String = UUID().uuidString, gain: Float = 1.0) {
        self.id = id
        self.parameters = [
            MorphicParameter(id: "\(id).gain", name: "Gain", value: gain, range: 0...4.0, defaultValue: 1.0)
        ]
    }

    public func process(_ input: [Float]) -> [Float] {
        let gain = parameters[0].value
        return input.map { $0 * gain }
    }

    public func reset() {}
}

/// Low-pass filter node (simple one-pole)
public final class MorphicFilterNode: MorphicNode {
    public let id: String
    public let name = "Filter"
    public var parameters: [MorphicParameter]
    private var lastOutput: Float = 0.0

    public enum FilterType: String, Codable, CaseIterable {
        case lowPass, highPass, bandPass
    }

    public let filterType: FilterType

    public init(id: String = UUID().uuidString, type: FilterType = .lowPass, cutoff: Float = 1000.0, resonance: Float = 0.0) {
        self.id = id
        self.filterType = type
        self.parameters = [
            MorphicParameter(id: "\(id).cutoff", name: "Cutoff", value: cutoff, range: 20...20000, defaultValue: 1000.0),
            MorphicParameter(id: "\(id).resonance", name: "Resonance", value: resonance, range: 0...1.0, defaultValue: 0.0)
        ]
    }

    public func process(_ input: [Float]) -> [Float] {
        let cutoff = parameters[0].value
        let alpha = cutoff / (cutoff + EchoelCore.defaultSampleRate / (2.0 * Float.pi))

        return input.map { sample in
            switch filterType {
            case .lowPass:
                lastOutput = lastOutput + alpha * (sample - lastOutput)
                return lastOutput
            case .highPass:
                lastOutput = lastOutput + alpha * (sample - lastOutput)
                return sample - lastOutput
            case .bandPass:
                lastOutput = lastOutput + alpha * (sample - lastOutput)
                return (sample - lastOutput) * alpha
            }
        }
    }

    public func reset() { lastOutput = 0 }
}

/// Saturation/distortion node
public final class MorphicSaturationNode: MorphicNode {
    public let id: String
    public let name = "Saturation"
    public var parameters: [MorphicParameter]

    public enum SaturationMode: String, Codable, CaseIterable {
        case soft     // tanh soft clip
        case hard     // hard clip
        case tube     // asymmetric tube
        case bitCrush // bit reduction
        case foldback // wave folding
    }

    public let mode: SaturationMode

    public init(id: String = UUID().uuidString, mode: SaturationMode = .soft, drive: Float = 1.0) {
        self.id = id
        self.mode = mode
        self.parameters = [
            MorphicParameter(id: "\(id).drive", name: "Drive", value: drive, range: 0.1...10.0, defaultValue: 1.0),
            MorphicParameter(id: "\(id).mix", name: "Mix", value: 1.0, range: 0...1.0, defaultValue: 1.0)
        ]
    }

    public func process(_ input: [Float]) -> [Float] {
        let drive = parameters[0].value
        let mix = parameters[1].value
        return input.map { sample in
            let driven = sample * drive
            let saturated: Float
            switch mode {
            case .soft:
                saturated = tanh(driven)
            case .hard:
                saturated = max(-1.0, min(1.0, driven))
            case .tube:
                saturated = driven >= 0
                    ? driven / (1.0 + driven * 0.4)
                    : driven / (1.0 - driven * 0.3)
            case .bitCrush:
                let bits = max(2.0, 16.0 - drive * 14.0)
                let levels = pow(2.0, bits)
                saturated = (driven * levels).rounded() / levels
            case .foldback:
                var folded = driven
                while abs(folded) > 1.0 { folded = abs(folded) - 1.0; folded = 1.0 - folded }
                saturated = folded
            }
            return sample * (1.0 - mix) + saturated * mix
        }
    }

    public func reset() {}
}

/// Delay node
public final class MorphicDelayNode: MorphicNode {
    public let id: String
    public let name = "Delay"
    public var parameters: [MorphicParameter]
    private var buffer: [Float]
    private var writeIndex: Int = 0

    public init(id: String = UUID().uuidString, timeMs: Float = 250.0, feedback: Float = 0.3, mix: Float = 0.5) {
        self.id = id
        self.parameters = [
            MorphicParameter(id: "\(id).time", name: "Time (ms)", value: timeMs, range: 1...2000, defaultValue: 250.0),
            MorphicParameter(id: "\(id).feedback", name: "Feedback", value: feedback, range: 0...0.95, defaultValue: 0.3),
            MorphicParameter(id: "\(id).mix", name: "Mix", value: mix, range: 0...1.0, defaultValue: 0.5)
        ]
        let maxSamples = Int(EchoelCore.defaultSampleRate * 2.0) // 2 sec max
        self.buffer = [Float](repeating: 0, count: maxSamples)
    }

    public func process(_ input: [Float]) -> [Float] {
        let delaySamples = Int(parameters[0].value / 1000.0 * EchoelCore.defaultSampleRate)
        let feedback = parameters[1].value
        let mix = parameters[2].value

        return input.map { sample in
            let readIndex = (writeIndex - min(delaySamples, buffer.count) + buffer.count) % buffer.count
            let delayed = buffer[readIndex]
            buffer[writeIndex] = sample + delayed * feedback
            writeIndex = (writeIndex + 1) % buffer.count
            return sample * (1.0 - mix) + delayed * mix
        }
    }

    public func reset() {
        buffer = [Float](repeating: 0, count: buffer.count)
        writeIndex = 0
    }
}

/// Oscillator node (for synthesis, not effect processing)
public final class MorphicOscillatorNode: MorphicNode {
    public let id: String
    public let name = "Oscillator"
    public var parameters: [MorphicParameter]
    private var phase: Float = 0.0

    public enum Waveform: String, Codable, CaseIterable {
        case sine, saw, square, triangle, noise
    }

    public let waveform: Waveform

    public init(id: String = UUID().uuidString, waveform: Waveform = .sine, frequency: Float = 440.0, amplitude: Float = 0.8) {
        self.id = id
        self.waveform = waveform
        self.parameters = [
            MorphicParameter(id: "\(id).freq", name: "Frequency", value: frequency, range: 20...20000, defaultValue: 440.0),
            MorphicParameter(id: "\(id).amp", name: "Amplitude", value: amplitude, range: 0...1.0, defaultValue: 0.8)
        ]
    }

    public func process(_ input: [Float]) -> [Float] {
        let freq = parameters[0].value
        let amp = parameters[1].value
        let phaseInc = freq / EchoelCore.defaultSampleRate

        return input.enumerated().map { (i, existing) in
            let sample: Float
            switch waveform {
            case .sine:
                sample = sin(phase * 2.0 * Float.pi) * amp
            case .saw:
                sample = (2.0 * (phase - Float(Int(phase + 0.5))) ) * amp
            case .square:
                sample = (phase.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1.0 : -1.0) * amp
            case .triangle:
                sample = (4.0 * abs(phase.truncatingRemainder(dividingBy: 1.0) - 0.5) - 1.0) * amp
            case .noise:
                sample = Float.random(in: -1...1) * amp
            }
            phase += phaseInc
            if phase > 1.0 { phase -= 1.0 }
            return existing + sample // additive
        }
    }

    public func reset() { phase = 0 }
}

/// Reverb node (simple Schroeder)
public final class MorphicReverbNode: MorphicNode {
    public let id: String
    public let name = "Reverb"
    public var parameters: [MorphicParameter]
    private var combBuffers: [[Float]]
    private var combIndices: [Int]
    private let combDelays = [1557, 1617, 1491, 1422]

    public init(id: String = UUID().uuidString, roomSize: Float = 0.5, mix: Float = 0.3) {
        self.id = id
        self.parameters = [
            MorphicParameter(id: "\(id).roomSize", name: "Room Size", value: roomSize, range: 0.1...1.0, defaultValue: 0.5),
            MorphicParameter(id: "\(id).mix", name: "Mix", value: mix, range: 0...1.0, defaultValue: 0.3)
        ]
        self.combBuffers = combDelays.map { [Float](repeating: 0, count: $0) }
        self.combIndices = [Int](repeating: 0, count: combDelays.count)
    }

    public func process(_ input: [Float]) -> [Float] {
        let feedback = parameters[0].value * 0.85
        let mix = parameters[1].value

        return input.map { sample in
            var reverbSample: Float = 0
            for c in 0..<combDelays.count {
                let delayed = combBuffers[c][combIndices[c]]
                combBuffers[c][combIndices[c]] = sample + delayed * feedback
                combIndices[c] = (combIndices[c] + 1) % combDelays[c]
                reverbSample += delayed
            }
            reverbSample /= Float(combDelays.count)
            return sample * (1.0 - mix) + reverbSample * mix
        }
    }

    public func reset() {
        for i in 0..<combBuffers.count {
            combBuffers[i] = [Float](repeating: 0, count: combDelays[i])
            combIndices[i] = 0
        }
    }
}

// MARK: - Morphic Compiler

/// Translates natural language descriptions into MorphicGraph DSP chains
/// This is the brain of Echoela's effect/instrument creation
@MainActor
public final class MorphicCompiler: ObservableObject {

    // MARK: - Singleton

    public static let shared = MorphicCompiler()

    // MARK: - Published State

    @Published public private(set) var compiledGraphs: [MorphicGraph] = []
    @Published public private(set) var isCompiling: Bool = false
    @Published public private(set) var lastError: String?

    // MARK: - Compilation Result

    public struct CompilationResult {
        public let graph: MorphicGraph
        public let sourceDescription: String
        public let compilationTime: TimeInterval
        public let nodeCount: Int
        public let parameterCount: Int
    }

    // MARK: - Intent Recognition

    /// Recognized DSP intent from natural language
    private struct DSPIntent {
        let effectType: EffectType
        let modifiers: [Modifier]
        let bioBindings: [(paramHint: String, source: MorphicParameter.BioBinding.BioSource)]

        enum EffectType {
            case filter(MorphicFilterNode.FilterType)
            case saturation(MorphicSaturationNode.SaturationMode)
            case delay
            case reverb
            case oscillator(MorphicOscillatorNode.Waveform)
            case chain([EffectType])
            case custom(String)
        }

        enum Modifier {
            case intensity(Float)  // 0-1
            case speed(Float)      // tempo modifier
            case wet(Float)        // mix amount
            case bioReactive       // enable bio binding
            case warm              // add warmth character
            case cold              // add brightness
            case dark              // reduce highs
            case bright            // boost highs
        }
    }

    // MARK: - Public API

    /// Compile a natural language description into a DSP graph
    public func compile(description: String, name: String? = nil) async throws -> CompilationResult {
        isCompiling = true
        lastError = nil
        let startTime = Date()

        defer { isCompiling = false }

        do {
            // Step 1: Parse intent from natural language
            let intent = parseIntent(from: description)

            // Step 2: Build DSP graph from intent
            let graphName = name ?? generateName(from: description)
            let graph = buildGraph(from: intent, name: graphName, description: description)

            // Step 3: Apply bio bindings
            applyBioBindings(to: graph, from: intent)

            // Step 4: Validate the graph
            try validateGraph(graph)

            // Store compiled graph
            compiledGraphs.append(graph)

            let compilationTime = Date().timeIntervalSince(startTime)
            return CompilationResult(
                graph: graph,
                sourceDescription: description,
                compilationTime: compilationTime,
                nodeCount: graph.nodes.count,
                parameterCount: graph.nodes.flatMap { $0.parameters }.count
            )
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Compile using LLM for complex descriptions
    public func compileWithLLM(description: String, name: String? = nil, bioContext: EchoelPulse.BodyMusic? = nil) async throws -> CompilationResult {
        isCompiling = true
        lastError = nil
        let startTime = Date()

        defer { isCompiling = false }

        do {
            // Build a structured prompt for the LLM
            let prompt = buildLLMPrompt(description: description, bioContext: bioContext)

            // Get LLM response
            let llmResponse = try await LLMService.shared.sendMessage(prompt, bioContext: nil)

            // Parse LLM response into DSP instructions
            let instructions = parseLLMResponse(llmResponse)

            // Build graph from LLM instructions
            let graphName = name ?? generateName(from: description)
            let graph = buildGraphFromInstructions(instructions, name: graphName, description: description)

            try validateGraph(graph)
            compiledGraphs.append(graph)

            let compilationTime = Date().timeIntervalSince(startTime)
            return CompilationResult(
                graph: graph,
                sourceDescription: description,
                compilationTime: compilationTime,
                nodeCount: graph.nodes.count,
                parameterCount: graph.nodes.flatMap { $0.parameters }.count
            )
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    /// Remove a compiled graph
    public func removeGraph(id: String) {
        compiledGraphs.removeAll { $0.id == id }
    }

    /// Get a graph by ID
    public func graph(withID id: String) -> MorphicGraph? {
        compiledGraphs.first { $0.id == id }
    }

    // MARK: - Intent Parsing (NL -> DSP Intent)

    private func parseIntent(from description: String) -> DSPIntent {
        let lower = description.lowercased()
        var effectTypes: [DSPIntent.EffectType] = []
        var modifiers: [DSPIntent.Modifier] = []
        var bioBindings: [(String, MorphicParameter.BioBinding.BioSource)] = []

        // Detect effect types
        if lower.contains("filter") || lower.contains("sweep") || lower.contains("wah") {
            if lower.contains("high") { effectTypes.append(.filter(.highPass)) }
            else if lower.contains("band") { effectTypes.append(.filter(.bandPass)) }
            else { effectTypes.append(.filter(.lowPass)) }
        }

        if lower.contains("distort") || lower.contains("saturate") || lower.contains("overdrive") || lower.contains("fuzz") {
            if lower.contains("tube") || lower.contains("warm") { effectTypes.append(.saturation(.tube)) }
            else if lower.contains("bit") || lower.contains("crush") { effectTypes.append(.saturation(.bitCrush)) }
            else if lower.contains("fold") { effectTypes.append(.saturation(.foldback)) }
            else if lower.contains("hard") { effectTypes.append(.saturation(.hard)) }
            else { effectTypes.append(.saturation(.soft)) }
        }

        if lower.contains("delay") || lower.contains("echo") || lower.contains("repeat") {
            effectTypes.append(.delay)
        }

        if lower.contains("reverb") || lower.contains("space") || lower.contains("room") || lower.contains("hall") {
            effectTypes.append(.reverb)
        }

        if lower.contains("oscillat") || lower.contains("synth") || lower.contains("tone") || lower.contains("generator") {
            if lower.contains("saw") { effectTypes.append(.oscillator(.saw)) }
            else if lower.contains("square") { effectTypes.append(.oscillator(.square)) }
            else if lower.contains("triangle") { effectTypes.append(.oscillator(.triangle)) }
            else if lower.contains("noise") { effectTypes.append(.oscillator(.noise)) }
            else { effectTypes.append(.oscillator(.sine)) }
        }

        // Default to a filter + reverb chain if nothing matched
        if effectTypes.isEmpty {
            effectTypes.append(.filter(.lowPass))
            effectTypes.append(.reverb)
        }

        // Detect modifiers
        if lower.contains("heavy") || lower.contains("intense") || lower.contains("extreme") {
            modifiers.append(.intensity(0.9))
        } else if lower.contains("subtle") || lower.contains("gentle") || lower.contains("light") {
            modifiers.append(.intensity(0.3))
        }

        if lower.contains("warm") { modifiers.append(.warm) }
        if lower.contains("cold") || lower.contains("icy") { modifiers.append(.cold) }
        if lower.contains("dark") { modifiers.append(.dark) }
        if lower.contains("bright") || lower.contains("airy") { modifiers.append(.bright) }

        if lower.contains("wet") { modifiers.append(.wet(0.7)) }
        if lower.contains("dry") { modifiers.append(.wet(0.2)) }

        // Detect bio-reactive bindings
        if lower.contains("heart") || lower.contains("pulse") || lower.contains("bio") || lower.contains("body") {
            modifiers.append(.bioReactive)
            bioBindings.append(("cutoff", .heartRate))
        }
        if lower.contains("breath") || lower.contains("atm") {
            modifiers.append(.bioReactive)
            bioBindings.append(("time", .breathPhase))
        }
        if lower.contains("coherence") || lower.contains("flow") {
            modifiers.append(.bioReactive)
            bioBindings.append(("mix", .coherence))
        }
        if lower.contains("hrv") || lower.contains("variabil") {
            modifiers.append(.bioReactive)
            bioBindings.append(("roomSize", .hrv))
        }

        return DSPIntent(
            effectType: effectTypes.count == 1 ? effectTypes[0] : .chain(effectTypes),
            modifiers: modifiers,
            bioBindings: bioBindings
        )
    }

    // MARK: - Graph Building

    private func buildGraph(from intent: DSPIntent, name: String, description: String) -> MorphicGraph {
        let graph = MorphicGraph(name: name, description: description)
        var nodes: [MorphicNode] = []

        // Extract intensity modifier
        let intensity: Float = intent.modifiers.compactMap { mod -> Float? in
            if case .intensity(let val) = mod { return val }
            return nil
        }.first ?? 0.5

        // Build nodes from effect types
        func addNodes(for effectType: DSPIntent.EffectType) {
            switch effectType {
            case .filter(let type):
                let cutoff: Float = intent.modifiers.contains(where: { if case .dark = $0 { return true }; return false })
                    ? 800.0
                    : intent.modifiers.contains(where: { if case .bright = $0 { return true }; return false })
                        ? 4000.0
                        : 1500.0
                nodes.append(MorphicFilterNode(type: type, cutoff: cutoff, resonance: intensity * 0.6))

            case .saturation(let mode):
                nodes.append(MorphicSaturationNode(mode: mode, drive: 1.0 + intensity * 4.0))

            case .delay:
                let mix: Float = intent.modifiers.compactMap { if case .wet(let v) = $0 { return v }; return nil }.first ?? 0.4
                nodes.append(MorphicDelayNode(timeMs: 250 + intensity * 500, feedback: 0.2 + intensity * 0.4, mix: mix))

            case .reverb:
                let mix: Float = intent.modifiers.compactMap { if case .wet(let v) = $0 { return v }; return nil }.first ?? 0.35
                nodes.append(MorphicReverbNode(roomSize: 0.3 + intensity * 0.6, mix: mix))

            case .oscillator(let waveform):
                nodes.append(MorphicOscillatorNode(waveform: waveform, frequency: 440.0, amplitude: 0.7))

            case .chain(let effects):
                for effect in effects { addNodes(for: effect) }

            case .custom:
                // Custom types need LLM compilation
                nodes.append(MorphicFilterNode(type: .lowPass, cutoff: 2000.0))
            }
        }

        addNodes(for: intent.effectType)

        // Add warmth if requested
        if intent.modifiers.contains(where: { if case .warm = $0 { return true }; return false }) {
            nodes.append(MorphicSaturationNode(mode: .tube, drive: 1.3))
        }

        // Ensure output gain control
        nodes.append(MorphicGainNode(gain: 0.9))

        // Assign nodes to graph (using internal mutation)
        for node in nodes {
            graph.nodes.append(node)
        }

        return graph
    }

    private func applyBioBindings(to graph: MorphicGraph, from intent: DSPIntent) {
        for (paramHint, source) in intent.bioBindings {
            // Find matching parameter in the graph
            for node in graph.nodes {
                for i in 0..<node.parameters.count {
                    let paramName = node.parameters[i].name.lowercased()
                    if paramName.contains(paramHint.lowercased()) {
                        node.parameters[i].bioBinding = MorphicParameter.BioBinding(
                            source: source,
                            curve: .sCurve,
                            intensity: 0.7
                        )
                        graph.bioBindings[node.parameters[i].id] = node.parameters[i].bioBinding
                    }
                }
            }
        }
    }

    // MARK: - LLM Integration

    private func buildLLMPrompt(description: String, bioContext: EchoelPulse.BodyMusic?) -> String {
        var prompt = """
        You are the Morphic Engine compiler for Echoelmusic's Echoela AI assistant.
        Your task: translate a natural language description into a DSP processing chain.

        Available DSP nodes:
        - FILTER(type: lowPass|highPass|bandPass, cutoff: 20-20000, resonance: 0-1)
        - SATURATION(mode: soft|hard|tube|bitCrush|foldback, drive: 0.1-10, mix: 0-1)
        - DELAY(timeMs: 1-2000, feedback: 0-0.95, mix: 0-1)
        - REVERB(roomSize: 0.1-1, mix: 0-1)
        - OSCILLATOR(waveform: sine|saw|square|triangle|noise, freq: 20-20000, amp: 0-1)
        - GAIN(gain: 0-4)

        Bio-reactive bindings (optional):
        - heartRate -> parameter (40-200 BPM mapped to 0-1)
        - hrv -> parameter (10-100ms mapped to 0-1)
        - coherence -> parameter (0-100 mapped to 0-1)
        - breathRate -> parameter (4-24 BPM mapped to 0-1)
        - breathPhase -> parameter (0-1 inhale/exhale cycle)

        Respond ONLY with a JSON array of nodes:
        [{"node":"FILTER","params":{"type":"lowPass","cutoff":1000,"resonance":0.3},"bio":{"cutoff":"heartRate"}}]

        Description: \(description)
        """

        if let bio = bioContext {
            prompt += "\n\nCurrent bio state: HR=\(Int(bio.heartRate)), HRV=\(Int(bio.hrv)), Coherence=\(Int(bio.coherence))%"
        }

        return prompt
    }

    private struct LLMNodeInstruction {
        let nodeType: String
        let params: [String: Float]
        let bioMappings: [String: String]
    }

    private func parseLLMResponse(_ response: String) -> [LLMNodeInstruction] {
        // Try to extract JSON from the response
        guard let jsonStart = response.firstIndex(of: "["),
              let jsonEnd = response.lastIndex(of: "]") else {
            return []
        }

        let jsonString = String(response[jsonStart...jsonEnd])
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return array.compactMap { dict -> LLMNodeInstruction? in
            guard let nodeType = dict["node"] as? String,
                  let params = dict["params"] as? [String: Any] else { return nil }

            let floatParams = params.compactMapValues { value -> Float? in
                if let num = value as? NSNumber { return num.floatValue }
                if let str = value as? String, let f = Float(str) { return f }
                return nil
            }

            let bio = (dict["bio"] as? [String: String]) ?? [:]
            return LLMNodeInstruction(nodeType: nodeType, params: floatParams, bioMappings: bio)
        }
    }

    private func buildGraphFromInstructions(_ instructions: [LLMNodeInstruction], name: String, description: String) -> MorphicGraph {
        let graph = MorphicGraph(name: name, description: description)

        for instruction in instructions {
            let node: MorphicNode?
            switch instruction.nodeType.uppercased() {
            case "FILTER":
                let type: MorphicFilterNode.FilterType
                if let typeStr = instruction.params["type"], typeStr > 1 { type = .highPass }
                else { type = .lowPass }
                node = MorphicFilterNode(
                    type: type,
                    cutoff: instruction.params["cutoff"] ?? 1000,
                    resonance: instruction.params["resonance"] ?? 0
                )
            case "SATURATION":
                node = MorphicSaturationNode(
                    mode: .soft,
                    drive: instruction.params["drive"] ?? 1.0
                )
            case "DELAY":
                node = MorphicDelayNode(
                    timeMs: instruction.params["timeMs"] ?? 250,
                    feedback: instruction.params["feedback"] ?? 0.3,
                    mix: instruction.params["mix"] ?? 0.5
                )
            case "REVERB":
                node = MorphicReverbNode(
                    roomSize: instruction.params["roomSize"] ?? 0.5,
                    mix: instruction.params["mix"] ?? 0.3
                )
            case "OSCILLATOR":
                node = MorphicOscillatorNode(
                    waveform: .sine,
                    frequency: instruction.params["freq"] ?? 440,
                    amplitude: instruction.params["amp"] ?? 0.8
                )
            case "GAIN":
                node = MorphicGainNode(gain: instruction.params["gain"] ?? 1.0)
            default:
                node = nil
            }

            if let node = node {
                // Apply bio mappings
                for (param, source) in instruction.bioMappings {
                    if let bioSource = MorphicParameter.BioBinding.BioSource(rawValue: source) {
                        for i in 0..<node.parameters.count {
                            if node.parameters[i].name.lowercased().contains(param.lowercased()) {
                                node.parameters[i].bioBinding = MorphicParameter.BioBinding(
                                    source: bioSource,
                                    curve: .sCurve,
                                    intensity: 0.7
                                )
                            }
                        }
                    }
                }
                graph.nodes.append(node)
            }
        }

        // Always end with gain safety
        graph.nodes.append(MorphicGainNode(gain: 0.9))
        return graph
    }

    // MARK: - Validation

    private func validateGraph(_ graph: MorphicGraph) throws {
        guard !graph.nodes.isEmpty else {
            throw MorphicError.emptyGraph
        }
        guard graph.nodes.count <= 32 else {
            throw MorphicError.tooManyNodes(graph.nodes.count)
        }
        // Verify all parameters are within range
        for node in graph.nodes {
            for param in node.parameters {
                guard param.range.contains(param.value) else {
                    throw MorphicError.parameterOutOfRange(param.name, param.value, param.range)
                }
            }
        }
    }

    // MARK: - Helpers

    private func generateName(from description: String) -> String {
        let words = description.split(separator: " ").prefix(3)
        return words.map { String($0).capitalized }.joined(separator: " ")
    }
}

// MARK: - Morphic Errors

public enum MorphicError: LocalizedError {
    case emptyGraph
    case tooManyNodes(Int)
    case parameterOutOfRange(String, Float, ClosedRange<Float>)
    case compilationFailed(String)
    case sandboxViolation(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .emptyGraph:
            return "Morphic compilation produced an empty graph"
        case .tooManyNodes(let count):
            return "Too many nodes (\(count)). Maximum is 32."
        case .parameterOutOfRange(let name, let value, let range):
            return "Parameter '\(name)' value \(value) out of range \(range)"
        case .compilationFailed(let reason):
            return "Morphic compilation failed: \(reason)"
        case .sandboxViolation(let reason):
            return "Sandbox violation: \(reason)"
        case .timeout:
            return "Morphic compilation timed out"
        }
    }
}

// Note: clamped(to:) extension is defined in Core/NumericExtensions.swift
