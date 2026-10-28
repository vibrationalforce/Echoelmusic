import EchoelCore
import EchoelDSP
import Foundation
import Synchronization

/// One parameter of a standard effect, as its Audio Unit publishes it.
public struct EffectParameter: Sendable, Equatable {
    public enum Unit: Sendable { case seconds, hertz, decibels, ratio, amount, boolean }

    public let address: Int
    public let identifier: String
    public let title: String
    public let range: ClosedRange<Float>
    public let defaultValue: Float
    public let unit: Unit
}

/// A standard effect's processor with its parameters held in atomics: any thread may set a
/// parameter, the render thread picks the whole set up at the start of the next block. Nothing
/// on the render path locks or allocates.
public final class EffectKernel: @unchecked Sendable {
    public let effect: StandardEffect
    public let sampleRate: Double
    public let parameters: [EffectParameter]
    private let values: UnsafeMutablePointer<Atomic<UInt32>>
    /// Counts writes so the render thread knows to pick the set up. 64 bits and a wrapping add:
    /// a 32-bit checked add trapped the render thread after 2^32 writes — about two weeks of
    /// automation on ten parameters, an installation's run (audit 2026-10-23).
    private let revision = Atomic<UInt64>(0)
    private var applied: UInt64 = .max
    private let reductionBits = Atomic<UInt32>(0)

    private var equalizer: ParametricEQ
    private var compressor: Compressor
    private let delay: StereoDelay?
    private let reverb: Reverb?
    private let chorus: Chorus?

    /// `values` carries settings over from a kernel at another rate; missing ones take defaults.
    public init(effect: StandardEffect, sampleRate: Double, values from: [Float] = []) {
        self.effect = effect
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        parameters = Self.parameters(for: effect)
        values = .allocate(capacity: parameters.count)
        for (index, parameter) in parameters.enumerated() {
            let value = index < from.count && from[index].isFinite ? from[index] : parameter.defaultValue
            (values + index).initialize(to: Atomic(Self.clamp(value, parameter).bitPattern))
        }
        equalizer = ParametricEQ(sampleRate: self.sampleRate)
        compressor = Compressor(sampleRate: self.sampleRate)
        delay = effect == .delay ? StereoDelay(sampleRate: self.sampleRate) : nil
        reverb = effect == .reverb ? Reverb(sampleRate: self.sampleRate) : nil
        chorus = effect == .chorus ? Chorus(sampleRate: self.sampleRate) : nil
        applySettings()
    }

    deinit {
        values.deinitialize(count: parameters.count)
        values.deallocate()
    }

    private static func clamp(_ value: Float, _ parameter: EffectParameter) -> Float {
        guard value.isFinite else { return parameter.defaultValue }
        return Swift.min(Swift.max(value, parameter.range.lowerBound), parameter.range.upperBound)
    }

    /// Any thread. An unknown address is ignored.
    public func setParameter(_ address: Int, _ value: Float) {
        guard address >= 0, address < parameters.count else { return }
        values[address].store(Self.clamp(value, parameters[address]).bitPattern, ordering: .relaxed)
        revision.wrappingAdd(1, ordering: .releasing)
    }

    public func parameter(_ address: Int) -> Float {
        guard address >= 0, address < parameters.count else { return 0 }
        return Float(bitPattern: values[address].load(ordering: .relaxed))
    }

    /// Every value, in address order, to carry into a new kernel.
    public var allValues: [Float] { parameters.indices.map(parameter) }

    /// The compressor's gain reduction in dB (0 or less); 0 for the other effects.
    public var gainReduction: Float { Float(bitPattern: reductionBits.load(ordering: .relaxed)) }

    /// Empties delay lines and tails.
    public func reset() {
        equalizer.reset()
        compressor.reset()
        delay?.reset()
        reverb?.reset()
        chorus?.reset()
    }

    /// Render thread: processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let current = revision.load(ordering: .acquiring)
        if current != applied {
            applied = current
            applySettings()
        }
        switch effect {
        case .equalizer: equalizer.process(left: left, right: right, frames: frames)
        case .compressor:
            compressor.process(left: left, right: right, frames: frames)
            reductionBits.store(compressor.reduction.bitPattern, ordering: .relaxed)
        case .delay: delay?.process(left: left, right: right, frames: frames)
        case .reverb: reverb?.process(left: left, right: right, frames: frames)
        case .chorus: chorus?.process(left: left, right: right, frames: frames)
        }
    }

    private func value(_ address: Int) -> Double { Double(parameter(address)) }

    private func applySettings() {
        switch effect {
        case .equalizer:
            var s = ParametricEQ.Settings()
            s.highpass = value(0)
            s.lowFrequency = value(1)
            s.lowGain = value(2)
            s.lowMidFrequency = value(3)
            s.lowMidGain = value(4)
            s.lowMidQ = value(5)
            s.highMidFrequency = value(6)
            s.highMidGain = value(7)
            s.highMidQ = value(8)
            s.highFrequency = value(9)
            s.highGain = value(10)
            if s != equalizer.settings { equalizer.settings = s }
        case .compressor:
            var s = Compressor.Settings()
            s.threshold = value(0)
            s.ratio = value(1)
            s.attack = value(2)
            s.release = value(3)
            s.knee = value(4)
            s.makeup = value(5)
            s.mix = value(6)
            if s != compressor.settings { compressor.settings = s }
        case .delay:
            guard let delay else { return }
            let s = StereoDelay.Settings(time: value(0), feedback: value(1), mix: value(2), damping: value(3),
                                         pingPong: value(4) >= 0.5)
            if s != delay.settings { delay.settings = s }
        case .reverb:
            guard let reverb else { return }
            let s = Reverb.Settings(size: value(0), decay: value(1), damping: value(2), predelay: value(3), mix: value(4))
            if s != reverb.settings { reverb.settings = s }
        case .chorus:
            guard let chorus else { return }
            let s = Chorus.Settings(rate: value(0), depth: value(1), mix: value(2))
            if s != chorus.settings { chorus.settings = s }
        }
    }

    public static func parameters(for effect: StandardEffect) -> [EffectParameter] {
        var list: [EffectParameter] = []
        func add(_ id: String, _ title: String, _ range: ClosedRange<Float>, _ value: Float, _ unit: EffectParameter.Unit) {
            list.append(EffectParameter(address: list.count, identifier: id, title: title, range: range,
                                        defaultValue: value, unit: unit))
        }
        switch effect {
        case .equalizer:
            add("highpass", "Low Cut", 20...1_000, 20, .hertz)
            add("lowFrequency", "Low Freq", 30...1_000, 120, .hertz)
            add("lowGain", "Low Gain", -18...18, 0, .decibels)
            add("lowMidFrequency", "Low Mid Freq", 60...8_000, 500, .hertz)
            add("lowMidGain", "Low Mid Gain", -18...18, 0, .decibels)
            add("lowMidQ", "Low Mid Q", 0.3...8, 1, .ratio)
            add("highMidFrequency", "High Mid Freq", 200...16_000, 3_000, .hertz)
            add("highMidGain", "High Mid Gain", -18...18, 0, .decibels)
            add("highMidQ", "High Mid Q", 0.3...8, 1, .ratio)
            add("highFrequency", "High Freq", 1_000...18_000, 8_000, .hertz)
            add("highGain", "High Gain", -18...18, 0, .decibels)
        case .compressor:
            add("threshold", "Threshold", -60...0, -18, .decibels)
            add("ratio", "Ratio", 1...20, 4, .ratio)
            add("attack", "Attack", 0.0001...0.2, 0.01, .seconds)
            add("release", "Release", 0.01...2, 0.15, .seconds)
            add("knee", "Knee", 0...24, 6, .decibels)
            add("makeup", "Makeup", 0...24, 0, .decibels)
            add("mix", "Mix", 0...1, 1, .amount)
        case .delay:
            add("time", "Time", 0.001...2, 0.375, .seconds)
            add("feedback", "Feedback", 0...0.95, 0.35, .amount)
            add("mix", "Mix", 0...1, 0.25, .amount)
            add("damping", "Damping", 500...20_000, 6_000, .hertz)
            add("pingPong", "Ping-Pong", 0...1, 0, .boolean)
        case .reverb:
            add("size", "Size", 0...1, 0.6, .amount)
            add("decay", "Decay", 0.2...20, 2.2, .seconds)
            add("damping", "Damping", 500...20_000, 7_000, .hertz)
            add("predelay", "Pre-Delay", 0...0.2, 0.02, .seconds)
            add("mix", "Mix", 0...1, 0.2, .amount)
        case .chorus:
            add("rate", "Rate", 0.05...8, 0.6, .hertz)
            add("depth", "Depth", 0...1, 0.5, .amount)
            add("mix", "Mix", 0...1, 0.5, .amount)
        }
        return list
    }
}
