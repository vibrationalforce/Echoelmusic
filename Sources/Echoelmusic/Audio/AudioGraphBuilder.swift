// AudioGraphBuilder.swift
// Echoelmusic - Result Builder DSL for Audio Graph Construction
// Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Declarative Swift DSL for building audio processing graphs.
// Makes complex audio routing readable and maintainable.
//
// Supported Platforms: iOS, macOS, watchOS, tvOS, visionOS
// Created 2026-01-16

import Foundation
import AVFoundation

// MARK: - Audio Node Protocol

/// Protocol for audio graph nodes
public protocol AudioGraphNode {
    /// Unique identifier
    var nodeId: String { get }

    /// Node type for routing
    var nodeType: AudioNodeType { get }

    /// Input connections
    var inputs: [String] { get }

    /// Output connections
    var outputs: [String] { get }

    /// Node parameters
    var parameters: [String: Any] { get }
}

/// Audio node types
public enum AudioNodeType: String, Sendable {
    case source
    case effect
    case mixer
    case output
    case analyzer
    case splitter
    case bioReactive
}

// MARK: - Audio Graph

/// Complete audio graph configuration
public struct AudioGraph {
    public let nodes: [AudioGraphNode]
    public let connections: [AudioConnection]

    public struct AudioConnection: Sendable {
        public let from: String
        public let to: String
        public let bus: Int

        public init(from: String, to: String, bus: Int = 0) {
            self.from = from
            self.to = to
            self.bus = bus
        }
    }
}

// MARK: - Result Builder

/// Result builder for declarative audio graph construction
///
/// Usage:
/// ```swift
/// let graph = AudioGraphBuilder.build {
///     Source("oscillator")
///         .frequency(440)
///         .waveform(.sine)
///
///     Effect("filter", type: .lowPass)
///         .cutoff(1000)
///         .resonance(0.7)
///         .input("oscillator")
///
///     BioReactiveNode("coherenceFilter")
///         .parameter(.cutoff, mappedTo: .coherence)
///         .input("filter")
///
///     Effect("reverb", type: .hall)
///         .mix(0.3)
///         .input("coherenceFilter")
///
///     Output("main")
///         .input("reverb")
/// }
/// ```
@resultBuilder
public struct AudioGraphBuilder {

    public static func buildBlock(_ components: AudioGraphNode...) -> [AudioGraphNode] {
        components
    }

    public static func buildArray(_ components: [[AudioGraphNode]]) -> [AudioGraphNode] {
        components.flatMap { $0 }
    }

    public static func buildOptional(_ component: [AudioGraphNode]?) -> [AudioGraphNode] {
        component ?? []
    }

    public static func buildEither(first component: [AudioGraphNode]) -> [AudioGraphNode] {
        component
    }

    public static func buildEither(second component: [AudioGraphNode]) -> [AudioGraphNode] {
        component
    }

    public static func buildExpression(_ expression: AudioGraphNode) -> [AudioGraphNode] {
        [expression]
    }

    /// Build a complete audio graph
    public static func build(@AudioGraphBuilder _ builder: () -> [AudioGraphNode]) -> AudioGraph {
        let nodes = builder()
        let connections = inferConnections(from: nodes)
        return AudioGraph(nodes: nodes, connections: connections)
    }

    private static func inferConnections(from nodes: [AudioGraphNode]) -> [AudioGraph.AudioConnection] {
        var connections: [AudioGraph.AudioConnection] = []

        for node in nodes {
            for (index, inputId) in node.inputs.enumerated() {
                connections.append(AudioGraph.AudioConnection(
                    from: inputId,
                    to: node.nodeId,
                    bus: index
                ))
            }
        }

        return connections
    }
}

// MARK: - Source Node

/// Audio source node (oscillator, sampler, etc.)
public struct Source: AudioGraphNode {
    public let nodeId: String
    public let nodeType: AudioNodeType = .source
    public var inputs: [String] = []
    public var outputs: [String] = []
    public var parameters: [String: Any] = [:]

    private var _frequency: Float = 440
    private var _waveform: Waveform = .sine
    private var _amplitude: Float = 0.5

    public enum Waveform: String {
        case sine, square, sawtooth, triangle, noise
    }

    public init(_ id: String) {
        self.nodeId = id
        self.outputs = [id]
    }

    public func frequency(_ freq: Float) -> Source {
        var copy = self
        copy._frequency = freq
        copy.parameters["frequency"] = freq
        return copy
    }

    public func waveform(_ wf: Waveform) -> Source {
        var copy = self
        copy._waveform = wf
        copy.parameters["waveform"] = wf.rawValue
        return copy
    }

    public func amplitude(_ amp: Float) -> Source {
        var copy = self
        copy._amplitude = amp
        copy.parameters["amplitude"] = amp
        return copy
    }
}

// MARK: - Effect Node

/// Audio effect node
public struct Effect: AudioGraphNode {
    public let nodeId: String
    public let nodeType: AudioNodeType = .effect
    public var inputs: [String] = []
    public var outputs: [String] = []
    public var parameters: [String: Any] = [:]

    public enum EffectType: String {
        case lowPass, highPass, bandPass, notch
        case reverb, delay, chorus, flanger, phaser
        case distortion, compressor, limiter
        case eq, parametricEQ
        case hall, plate, room, spring
    }

    private let effectType: EffectType

    public init(_ id: String, type: EffectType) {
        self.nodeId = id
        self.effectType = type
        self.outputs = [id]
        self.parameters["type"] = type.rawValue
    }

    public func input(_ sourceId: String) -> Effect {
        var copy = self
        copy.inputs.append(sourceId)
        return copy
    }

    public func cutoff(_ freq: Float) -> Effect {
        var copy = self
        copy.parameters["cutoff"] = freq
        return copy
    }

    public func resonance(_ q: Float) -> Effect {
        var copy = self
        copy.parameters["resonance"] = q
        return copy
    }

    public func mix(_ wet: Float) -> Effect {
        var copy = self
        copy.parameters["mix"] = wet
        return copy
    }

    public func time(_ seconds: Float) -> Effect {
        var copy = self
        copy.parameters["time"] = seconds
        return copy
    }

    public func feedback(_ amount: Float) -> Effect {
        var copy = self
        copy.parameters["feedback"] = amount
        return copy
    }

    public func threshold(_ db: Float) -> Effect {
        var copy = self
        copy.parameters["threshold"] = db
        return copy
    }

    public func ratio(_ ratio: Float) -> Effect {
        var copy = self
        copy.parameters["ratio"] = ratio
        return copy
    }

    public func attack(_ ms: Float) -> Effect {
        var copy = self
        copy.parameters["attack"] = ms
        return copy
    }

    public func release(_ ms: Float) -> Effect {
        var copy = self
        copy.parameters["release"] = ms
        return copy
    }
}

// MARK: - Bio-Reactive Node

/// Bio-reactive modulation node
public struct BioReactiveNode: AudioGraphNode {
    public let nodeId: String
    public let nodeType: AudioNodeType = .bioReactive
    public var inputs: [String] = []
    public var outputs: [String] = []
    public var parameters: [String: Any] = [:]

    public enum TargetParameter: String {
        case cutoff, resonance, mix, amplitude, pitch, pan
        case attack, release, threshold, ratio
        case delayTime, feedback, reverbMix
    }

    public enum BioSource: String {
        case coherence, heartRate, hrv, breathPhase, breathRate
        case gsr, spO2, attention
    }

    public init(_ id: String) {
        self.nodeId = id
        self.outputs = [id]
    }

    public func input(_ sourceId: String) -> BioReactiveNode {
        var copy = self
        copy.inputs.append(sourceId)
        return copy
    }

    public func parameter(_ target: TargetParameter, mappedTo source: BioSource) -> BioReactiveNode {
        var copy = self
        var mappings = (copy.parameters["mappings"] as? [[String: String]]) ?? []
        mappings.append([
            "target": target.rawValue,
            "source": source.rawValue
        ])
        copy.parameters["mappings"] = mappings
        return copy
    }

    public func range(min: Float, max: Float) -> BioReactiveNode {
        var copy = self
        copy.parameters["rangeMin"] = min
        copy.parameters["rangeMax"] = max
        return copy
    }

    public func curve(_ curve: MappingCurve) -> BioReactiveNode {
        var copy = self
        copy.parameters["curve"] = curve.rawValue
        return copy
    }

    public func smoothing(_ factor: Float) -> BioReactiveNode {
        var copy = self
        copy.parameters["smoothing"] = factor
        return copy
    }
}

// MARK: - Mixer Node

/// Audio mixer node
public struct Mixer: AudioGraphNode {
    public let nodeId: String
    public let nodeType: AudioNodeType = .mixer
    public var inputs: [String] = []
    public var outputs: [String] = []
    public var parameters: [String: Any] = [:]

    public init(_ id: String) {
        self.nodeId = id
        self.outputs = [id]
    }

    public func input(_ sourceId: String, volume: Float = 1.0, pan: Float = 0) -> Mixer {
        var copy = self
        copy.inputs.append(sourceId)

        var inputParams = (copy.parameters["inputParams"] as? [[String: Any]]) ?? []
        inputParams.append([
            "source": sourceId,
            "volume": volume,
            "pan": pan
        ])
        copy.parameters["inputParams"] = inputParams

        return copy
    }

    public func masterVolume(_ volume: Float) -> Mixer {
        var copy = self
        copy.parameters["masterVolume"] = volume
        return copy
    }
}

// MARK: - Output Node

/// Audio output node
public struct Output: AudioGraphNode {
    public let nodeId: String
    public let nodeType: AudioNodeType = .output
    public var inputs: [String] = []
    public var outputs: [String] = []
    public var parameters: [String: Any] = [:]

    public init(_ id: String) {
        self.nodeId = id
    }

    public func input(_ sourceId: String) -> Output {
        var copy = self
        copy.inputs.append(sourceId)
        return copy
    }

    public func volume(_ level: Float) -> Output {
        var copy = self
        copy.parameters["volume"] = level
        return copy
    }

    public func muted(_ isMuted: Bool) -> Output {
        var copy = self
        copy.parameters["muted"] = isMuted
        return copy
    }
}

// MARK: - Analyzer Node

/// Audio analyzer node
public struct Analyzer: AudioGraphNode {
    public let nodeId: String
    public let nodeType: AudioNodeType = .analyzer
    public var inputs: [String] = []
    public var outputs: [String] = []
    public var parameters: [String: Any] = [:]

    public enum AnalyzerType: String {
        case fft, rms, peak, beatDetector, pitchDetector
    }

    public init(_ id: String, type: AnalyzerType) {
        self.nodeId = id
        self.outputs = [id]
        self.parameters["analyzerType"] = type.rawValue
    }

    public func input(_ sourceId: String) -> Analyzer {
        var copy = self
        copy.inputs.append(sourceId)
        return copy
    }

    public func fftSize(_ size: Int) -> Analyzer {
        var copy = self
        copy.parameters["fftSize"] = size
        return copy
    }
}

// MARK: - Splitter Node

/// Audio splitter node (one input to multiple outputs)
public struct Splitter: AudioGraphNode {
    public let nodeId: String
    public let nodeType: AudioNodeType = .splitter
    public var inputs: [String] = []
    public var outputs: [String] = []
    public var parameters: [String: Any] = [:]

    public init(_ id: String) {
        self.nodeId = id
    }

    public func input(_ sourceId: String) -> Splitter {
        var copy = self
        copy.inputs.append(sourceId)
        return copy
    }

    public func outputCount(_ count: Int) -> Splitter {
        var copy = self
        copy.outputs = (0..<count).map { "\(nodeId)_\($0)" }
        copy.parameters["outputCount"] = count
        return copy
    }
}

// MARK: - Presets

public extension AudioGraphBuilder {

    /// Build a meditation audio graph
    static func meditationGraph() -> AudioGraph {
        build {
            Source("carrier")
                .frequency(432)
                .waveform(.sine)
                .amplitude(0.3)

            Source("binaural")
                .frequency(442)  // +10Hz for alpha
                .waveform(.sine)
                .amplitude(0.3)

            Mixer("binauralMix")
                .input("carrier", volume: 1.0, pan: -1.0)
                .input("binaural", volume: 1.0, pan: 1.0)

            BioReactiveNode("coherenceMod")
                .input("binauralMix")
                .parameter(.amplitude, mappedTo: .coherence)
                .smoothing(0.8)

            Effect("reverb", type: .hall)
                .input("coherenceMod")
                .mix(0.5)
                .time(2.0)

            Output("main")
                .input("reverb")
                .volume(0.8)
        }
    }

    /// Build an energetic bio-reactive graph
    static func energeticGraph() -> AudioGraph {
        build {
            Source("bass")
                .frequency(55)
                .waveform(.sawtooth)
                .amplitude(0.4)

            Source("lead")
                .frequency(220)
                .waveform(.square)
                .amplitude(0.3)

            Effect("bassFilter", type: .lowPass)
                .input("bass")
                .cutoff(200)
                .resonance(0.5)

            BioReactiveNode("filterMod")
                .input("bassFilter")
                .parameter(.cutoff, mappedTo: .heartRate)
                .range(min: 100, max: 2000)

            Effect("leadDelay", type: .delay)
                .input("lead")
                .time(0.25)
                .feedback(0.3)
                .mix(0.4)

            Mixer("main")
                .input("filterMod", volume: 0.8)
                .input("leadDelay", volume: 0.6)
                .masterVolume(0.9)

            Output("output")
                .input("main")
        }
    }
}
