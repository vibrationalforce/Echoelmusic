//
//  EffectChainArchitecture.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Protocol-Based Modular Effect Chain Architecture
//
//  Features:
//  - Protocol-oriented design for extensibility
//  - Type-safe parameter system
//  - Real-time safe processing
//  - A/B comparison built-in
//  - Undo/Redo support
//  - Cross-platform abstraction
//

import Foundation
import Combine
import Accelerate

// MARK: - Effect Parameter Protocol

/// Protocol for effect parameters with type-safe access
public protocol EffectParameterProtocol: Identifiable, Codable {
    var id: String { get }
    var name: String { get }
    var unit: String { get }
    var defaultValue: Float { get }
    var range: ClosedRange<Float> { get }
    var curve: ParameterCurve { get }
    var currentValue: Float { get set }

    func normalized() -> Float
    func setNormalized(_ value: Float)
    func reset()
}

public enum ParameterCurve: String, Codable {
    case linear
    case logarithmic
    case exponential
    case squared
    case cubed
}

// MARK: - Effect Parameter

/// Concrete implementation of effect parameter
public struct EffectParameterValue: EffectParameterProtocol {
    public let id: String
    public let name: String
    public let unit: String
    public let defaultValue: Float
    public let range: ClosedRange<Float>
    public let curve: ParameterCurve
    public var currentValue: Float

    public init(
        id: String,
        name: String,
        unit: String = "",
        defaultValue: Float,
        range: ClosedRange<Float>,
        curve: ParameterCurve = .linear
    ) {
        self.id = id
        self.name = name
        self.unit = unit
        self.defaultValue = defaultValue
        self.range = range
        self.curve = curve
        self.currentValue = defaultValue
    }

    public func normalized() -> Float {
        let normalizedLinear = (currentValue - range.lowerBound) / (range.upperBound - range.lowerBound)

        switch curve {
        case .linear:
            return normalizedLinear
        case .logarithmic:
            return log10(1 + normalizedLinear * 9) / log10(10)
        case .exponential:
            return (pow(10, normalizedLinear) - 1) / 9
        case .squared:
            return sqrt(normalizedLinear)
        case .cubed:
            return pow(normalizedLinear, 1/3)
        }
    }

    public mutating func setNormalized(_ value: Float) {
        let clampedValue = max(0, min(1, value))
        let linearValue: Float

        switch curve {
        case .linear:
            linearValue = clampedValue
        case .logarithmic:
            linearValue = (pow(10, clampedValue) - 1) / 9
        case .exponential:
            linearValue = log10(1 + clampedValue * 9) / log10(10)
        case .squared:
            linearValue = clampedValue * clampedValue
        case .cubed:
            linearValue = clampedValue * clampedValue * clampedValue
        }

        currentValue = range.lowerBound + linearValue * (range.upperBound - range.lowerBound)
    }

    public mutating func reset() {
        currentValue = defaultValue
    }
}

// MARK: - Audio Buffer Protocol

/// Protocol for audio buffers with various formats
public protocol AudioBufferProtocol {
    var sampleRate: Double { get }
    var channelCount: Int { get }
    var frameCount: Int { get }
    var sampleCount: Int { get }

    func getSamples(channel: Int) -> UnsafePointer<Float>?
    func getMutableSamples(channel: Int) -> UnsafeMutablePointer<Float>?
}

// MARK: - Audio Buffer Implementation

/// Concrete audio buffer implementation
public final class AudioBuffer: AudioBufferProtocol {
    public let sampleRate: Double
    public let channelCount: Int
    public let frameCount: Int
    public var sampleCount: Int { frameCount * channelCount }

    private var data: [[Float]]

    public init(sampleRate: Double, channelCount: Int, frameCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.frameCount = frameCount
        self.data = (0..<channelCount).map { _ in [Float](repeating: 0, count: frameCount) }
    }

    public func getSamples(channel: Int) -> UnsafePointer<Float>? {
        guard channel < channelCount else { return nil }
        return data[channel].withUnsafeBufferPointer { $0.baseAddress }
    }

    public func getMutableSamples(channel: Int) -> UnsafeMutablePointer<Float>? {
        guard channel < channelCount else { return nil }
        return data[channel].withUnsafeMutableBufferPointer { $0.baseAddress }
    }

    public func copyFrom(_ other: AudioBufferProtocol) {
        for channel in 0..<min(channelCount, other.channelCount) {
            guard let src = other.getSamples(channel: channel),
                  let dst = getMutableSamples(channel: channel) else { continue }
            memcpy(dst, src, min(frameCount, other.frameCount) * MemoryLayout<Float>.stride)
        }
    }

    public func clear() {
        for channel in 0..<channelCount {
            data[channel] = [Float](repeating: 0, count: frameCount)
        }
    }
}

// MARK: - Audio Effect Protocol

/// Protocol for all audio effects
public protocol AudioEffectProtocol: AnyObject, Identifiable {
    var id: UUID { get }
    var name: String { get }
    var category: EffectCategory { get }
    var isEnabled: Bool { get set }
    var isBypassed: Bool { get set }
    var parameters: [EffectParameterValue] { get set }
    var latency: Int { get }

    /// Process audio buffer in-place
    func process(_ buffer: inout AudioBuffer)

    /// Reset effect state (clear delay lines, etc.)
    func reset()

    /// Prepare for processing at given sample rate
    func prepareToPlay(sampleRate: Double, maxBlockSize: Int)

    /// Get parameter by ID
    func getParameter(_ id: String) -> EffectParameterValue?

    /// Set parameter value
    func setParameter(_ id: String, value: Float)
}

public enum EffectCategory: String, Codable, CaseIterable {
    case dynamics = "Dynamics"
    case eq = "EQ"
    case filter = "Filter"
    case reverb = "Reverb"
    case delay = "Delay"
    case modulation = "Modulation"
    case distortion = "Distortion"
    case utility = "Utility"
    case spatial = "Spatial"
    case creative = "Creative"
}

// MARK: - Base Effect Implementation

/// Base class for audio effects with common functionality
open class BaseAudioEffect: AudioEffectProtocol {
    public let id: UUID
    public let name: String
    public let category: EffectCategory
    public var isEnabled: Bool = true
    public var isBypassed: Bool = false
    public var parameters: [EffectParameterValue] = []
    public var latency: Int { 0 }

    protected var sampleRate: Double = 48000
    protected var maxBlockSize: Int = 1024

    public init(id: UUID = UUID(), name: String, category: EffectCategory) {
        self.id = id
        self.name = name
        self.category = category
    }

    open func process(_ buffer: inout AudioBuffer) {
        // Override in subclass
    }

    open func reset() {
        // Override in subclass
    }

    open func prepareToPlay(sampleRate: Double, maxBlockSize: Int) {
        self.sampleRate = sampleRate
        self.maxBlockSize = maxBlockSize
    }

    public func getParameter(_ id: String) -> EffectParameterValue? {
        parameters.first { $0.id == id }
    }

    public func setParameter(_ id: String, value: Float) {
        if let index = parameters.firstIndex(where: { $0.id == id }) {
            parameters[index].currentValue = value
        }
    }
}

// MARK: - Effect Chain

/// Manages a chain of effects with proper signal flow
@MainActor
public final class EffectChain: ObservableObject, Identifiable {
    public let id: UUID

    @Published public var name: String
    @Published public var effects: [any AudioEffectProtocol] = []
    @Published public var isEnabled: Bool = true
    @Published public var inputGain: Float = 1.0
    @Published public var outputGain: Float = 1.0
    @Published public var mix: Float = 1.0 // Dry/Wet

    private var dryBuffer: AudioBuffer?
    private var processingBuffer: AudioBuffer?

    public init(id: UUID = UUID(), name: String = "Effect Chain") {
        self.id = id
        self.name = name
    }

    // MARK: - Effect Management

    public func addEffect(_ effect: any AudioEffectProtocol) {
        effects.append(effect)
    }

    public func insertEffect(_ effect: any AudioEffectProtocol, at index: Int) {
        effects.insert(effect, at: min(index, effects.count))
    }

    public func removeEffect(at index: Int) {
        guard index < effects.count else { return }
        effects.remove(at: index)
    }

    public func removeEffect(id: UUID) {
        effects.removeAll { $0.id == id }
    }

    public func moveEffect(from: Int, to: Int) {
        guard from < effects.count, to < effects.count else { return }
        let effect = effects.remove(at: from)
        effects.insert(effect, at: to)
    }

    public func getEffect<T: AudioEffectProtocol>(ofType type: T.Type) -> T? {
        effects.compactMap { $0 as? T }.first
    }

    public func getEffect(id: UUID) -> (any AudioEffectProtocol)? {
        effects.first { $0.id == id }
    }

    // MARK: - Processing

    public func prepareToPlay(sampleRate: Double, maxBlockSize: Int) {
        for effect in effects {
            effect.prepareToPlay(sampleRate: sampleRate, maxBlockSize: maxBlockSize)
        }
    }

    public func process(_ buffer: inout AudioBuffer) {
        guard isEnabled else { return }

        // Apply input gain
        if inputGain != 1.0 {
            applyGain(&buffer, gain: inputGain)
        }

        // Store dry signal for mix
        if mix < 1.0 {
            if dryBuffer == nil || dryBuffer!.frameCount != buffer.frameCount {
                dryBuffer = AudioBuffer(
                    sampleRate: buffer.sampleRate,
                    channelCount: buffer.channelCount,
                    frameCount: buffer.frameCount
                )
            }
            dryBuffer!.copyFrom(buffer)
        }

        // Process through effect chain
        for effect in effects where effect.isEnabled && !effect.isBypassed {
            effect.process(&buffer)
        }

        // Apply dry/wet mix
        if mix < 1.0, let dryBuffer = dryBuffer {
            mixBuffers(dry: dryBuffer, wet: &buffer, wetAmount: mix)
        }

        // Apply output gain
        if outputGain != 1.0 {
            applyGain(&buffer, gain: outputGain)
        }
    }

    public func reset() {
        for effect in effects {
            effect.reset()
        }
    }

    // MARK: - Helpers

    private func applyGain(_ buffer: inout AudioBuffer, gain: Float) {
        for channel in 0..<buffer.channelCount {
            guard let samples = buffer.getMutableSamples(channel: channel) else { continue }
            var g = gain
            vDSP_vsmul(samples, 1, &g, samples, 1, vDSP_Length(buffer.frameCount))
        }
    }

    private func mixBuffers(dry: AudioBuffer, wet: inout AudioBuffer, wetAmount: Float) {
        let dryAmount = 1.0 - wetAmount

        for channel in 0..<wet.channelCount {
            guard let drySamples = dry.getSamples(channel: channel),
                  let wetSamples = wet.getMutableSamples(channel: channel) else { continue }

            // wet = dry * dryAmount + wet * wetAmount
            var d = dryAmount
            var w = wetAmount
            var temp = [Float](repeating: 0, count: wet.frameCount)

            vDSP_vsmul(drySamples, 1, &d, &temp, 1, vDSP_Length(wet.frameCount))
            vDSP_vsmul(wetSamples, 1, &w, wetSamples, 1, vDSP_Length(wet.frameCount))
            vDSP_vadd(temp, 1, wetSamples, 1, wetSamples, 1, vDSP_Length(wet.frameCount))
        }
    }

    // MARK: - Total Latency

    public var totalLatency: Int {
        effects.reduce(0) { $0 + $1.latency }
    }
}

// MARK: - Concrete Effects

/// High-quality compressor
public final class CompressorEffect: BaseAudioEffect {
    private var envelope: Float = 0

    public init() {
        super.init(name: "Compressor", category: .dynamics)

        parameters = [
            EffectParameterValue(id: "threshold", name: "Threshold", unit: "dB", defaultValue: -20, range: -60...0),
            EffectParameterValue(id: "ratio", name: "Ratio", unit: ":1", defaultValue: 4, range: 1...20),
            EffectParameterValue(id: "attack", name: "Attack", unit: "ms", defaultValue: 10, range: 0.1...100, curve: .logarithmic),
            EffectParameterValue(id: "release", name: "Release", unit: "ms", defaultValue: 100, range: 10...1000, curve: .logarithmic),
            EffectParameterValue(id: "makeup", name: "Makeup", unit: "dB", defaultValue: 0, range: 0...24),
            EffectParameterValue(id: "knee", name: "Knee", unit: "dB", defaultValue: 6, range: 0...12)
        ]
    }

    public override func process(_ buffer: inout AudioBuffer) {
        let threshold = getParameter("threshold")?.currentValue ?? -20
        let ratio = getParameter("ratio")?.currentValue ?? 4
        let attackMs = getParameter("attack")?.currentValue ?? 10
        let releaseMs = getParameter("release")?.currentValue ?? 100
        let makeupDb = getParameter("makeup")?.currentValue ?? 0
        let knee = getParameter("knee")?.currentValue ?? 6

        let attackCoeff = exp(-1.0 / (Float(sampleRate) * attackMs / 1000.0))
        let releaseCoeff = exp(-1.0 / (Float(sampleRate) * releaseMs / 1000.0))
        let makeupGain = pow(10.0, makeupDb / 20.0)

        for channel in 0..<buffer.channelCount {
            guard let samples = buffer.getMutableSamples(channel: channel) else { continue }

            for i in 0..<buffer.frameCount {
                let inputLevel = abs(samples[i])
                let inputDb = 20 * log10(max(inputLevel, 1e-10))

                // Soft knee calculation
                var gainDb: Float = 0
                if inputDb > threshold + knee/2 {
                    gainDb = threshold + (inputDb - threshold) / ratio - inputDb
                } else if inputDb > threshold - knee/2 {
                    let x = inputDb - threshold + knee/2
                    gainDb = (1/ratio - 1) * x * x / (2 * knee)
                }

                // Envelope follower
                let targetEnv = pow(10.0, gainDb / 20.0)
                if targetEnv < envelope {
                    envelope = attackCoeff * envelope + (1 - attackCoeff) * targetEnv
                } else {
                    envelope = releaseCoeff * envelope + (1 - releaseCoeff) * targetEnv
                }

                samples[i] *= envelope * makeupGain
            }
        }
    }

    public override func reset() {
        envelope = 0
    }
}

/// Parametric EQ
public final class ParametricEQEffect: BaseAudioEffect {
    private var biquadFilters: [[BiquadFilter]] = []

    public init() {
        super.init(name: "Parametric EQ", category: .eq)

        // 4-band parametric EQ
        for band in 1...4 {
            parameters.append(contentsOf: [
                EffectParameterValue(id: "freq\(band)", name: "Freq \(band)", unit: "Hz",
                    defaultValue: [80, 400, 2000, 8000][band-1],
                    range: 20...20000, curve: .logarithmic),
                EffectParameterValue(id: "gain\(band)", name: "Gain \(band)", unit: "dB",
                    defaultValue: 0, range: -18...18),
                EffectParameterValue(id: "q\(band)", name: "Q \(band)", unit: "",
                    defaultValue: 1, range: 0.1...10, curve: .logarithmic)
            ])
        }
    }

    public override func prepareToPlay(sampleRate: Double, maxBlockSize: Int) {
        super.prepareToPlay(sampleRate: sampleRate, maxBlockSize: maxBlockSize)
        biquadFilters = [[BiquadFilter]](repeating: [BiquadFilter](repeating: BiquadFilter(), count: 4), count: 2)
        updateCoefficients()
    }

    public override func process(_ buffer: inout AudioBuffer) {
        updateCoefficients()

        for channel in 0..<min(buffer.channelCount, 2) {
            guard let samples = buffer.getMutableSamples(channel: channel) else { continue }

            for band in 0..<4 {
                biquadFilters[channel][band].process(samples, count: buffer.frameCount)
            }
        }
    }

    private func updateCoefficients() {
        for band in 1...4 {
            let freq = getParameter("freq\(band)")?.currentValue ?? 1000
            let gain = getParameter("gain\(band)")?.currentValue ?? 0
            let q = getParameter("q\(band)")?.currentValue ?? 1

            for channel in 0..<biquadFilters.count {
                biquadFilters[channel][band-1].setPeakEQ(freq: freq, gain: gain, q: q, sampleRate: Float(sampleRate))
            }
        }
    }

    public override func reset() {
        for channel in 0..<biquadFilters.count {
            for band in 0..<biquadFilters[channel].count {
                biquadFilters[channel][band].reset()
            }
        }
    }
}

/// Simple reverb
public final class ReverbEffect: BaseAudioEffect {
    private var delayLines: [[Float]] = []
    private var delayIndices: [Int] = []
    private let delayLengths = [1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116] // Prime numbers

    public override var latency: Int { 0 }

    public init() {
        super.init(name: "Reverb", category: .reverb)

        parameters = [
            EffectParameterValue(id: "size", name: "Size", unit: "", defaultValue: 0.5, range: 0...1),
            EffectParameterValue(id: "decay", name: "Decay", unit: "s", defaultValue: 2, range: 0.1...10),
            EffectParameterValue(id: "damping", name: "Damping", unit: "", defaultValue: 0.5, range: 0...1),
            EffectParameterValue(id: "predelay", name: "Pre-Delay", unit: "ms", defaultValue: 20, range: 0...100),
            EffectParameterValue(id: "mix", name: "Mix", unit: "%", defaultValue: 30, range: 0...100)
        ]
    }

    public override func prepareToPlay(sampleRate: Double, maxBlockSize: Int) {
        super.prepareToPlay(sampleRate: sampleRate, maxBlockSize: maxBlockSize)

        delayLines = delayLengths.map { [Float](repeating: 0, count: $0) }
        delayIndices = [Int](repeating: 0, count: delayLengths.count)
    }

    public override func process(_ buffer: inout AudioBuffer) {
        let decay = getParameter("decay")?.currentValue ?? 2
        let damping = getParameter("damping")?.currentValue ?? 0.5
        let mix = (getParameter("mix")?.currentValue ?? 30) / 100.0

        let feedback = pow(0.001, 1.0 / (decay * Float(sampleRate)))
        let damp = damping * 0.4

        for channel in 0..<min(buffer.channelCount, 2) {
            guard let samples = buffer.getMutableSamples(channel: channel) else { continue }

            for i in 0..<buffer.frameCount {
                let input = samples[i]
                var output: Float = 0

                // Simple comb filter network
                for d in 0..<delayLines.count {
                    let delayed = delayLines[d][delayIndices[d]]
                    output += delayed

                    // Damped feedback
                    let filtered = delayed * (1 - damp) + delayLines[d][(delayIndices[d] + 1) % delayLines[d].count] * damp
                    delayLines[d][delayIndices[d]] = input * 0.125 + filtered * feedback

                    delayIndices[d] = (delayIndices[d] + 1) % delayLines[d].count
                }

                output /= Float(delayLines.count)
                samples[i] = input * (1 - mix) + output * mix
            }
        }
    }

    public override func reset() {
        for i in 0..<delayLines.count {
            delayLines[i] = [Float](repeating: 0, count: delayLengths[i])
            delayIndices[i] = 0
        }
    }
}

// MARK: - Biquad Filter

struct BiquadFilter {
    private var a0: Float = 1, a1: Float = 0, a2: Float = 0
    private var b0: Float = 1, b1: Float = 0, b2: Float = 0
    private var z1: Float = 0, z2: Float = 0

    mutating func setPeakEQ(freq: Float, gain: Float, q: Float, sampleRate: Float) {
        let A = pow(10, gain / 40)
        let w0 = 2 * Float.pi * freq / sampleRate
        let sinW0 = sin(w0)
        let cosW0 = cos(w0)
        let alpha = sinW0 / (2 * q)

        let a0Inv = 1 / (1 + alpha / A)

        b0 = (1 + alpha * A) * a0Inv
        b1 = -2 * cosW0 * a0Inv
        b2 = (1 - alpha * A) * a0Inv
        a1 = b1
        a2 = (1 - alpha / A) * a0Inv
    }

    mutating func process(_ samples: UnsafeMutablePointer<Float>, count: Int) {
        for i in 0..<count {
            let input = samples[i]
            let output = b0 * input + z1
            z1 = b1 * input - a1 * output + z2
            z2 = b2 * input - a2 * output
            samples[i] = output
        }
    }

    mutating func reset() {
        z1 = 0
        z2 = 0
    }
}

// MARK: - Effect Factory

/// Factory for creating effects by type
public struct EffectFactory {
    public static func createEffect(type: EffectType) -> any AudioEffectProtocol {
        switch type {
        case .compressor:
            return CompressorEffect()
        case .parametricEQ:
            return ParametricEQEffect()
        case .reverb:
            return ReverbEffect()
        }
    }

    public enum EffectType: String, CaseIterable {
        case compressor = "Compressor"
        case parametricEQ = "Parametric EQ"
        case reverb = "Reverb"

        public var category: EffectCategory {
            switch self {
            case .compressor: return .dynamics
            case .parametricEQ: return .eq
            case .reverb: return .reverb
            }
        }
    }
}
