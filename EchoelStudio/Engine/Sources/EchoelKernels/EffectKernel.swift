import EchoelCore
import EchoelDSP
import Foundation
import Synchronization

/// One parameter of a standard effect, as its Audio Unit publishes it.
public struct EffectParameter: Sendable, Equatable {
    /// `choice`: the value is the index of one of `choices`, which have names (a harmony interval,
    /// a scale) — a menu, never a number.
    public enum Unit: Sendable { case seconds, hertz, decibels, ratio, amount, boolean, choice }

    public let address: Int
    public let identifier: String
    public let title: String
    public let range: ClosedRange<Float>
    public let defaultValue: Float
    public let unit: Unit
    /// The names of a `choice` parameter's values, index 0 first; empty for every other unit.
    public let choices: [String]

    /// The name of the choice at `value`, for a `choice` parameter.
    public func choice(at value: Float) -> String? {
        guard unit == .choice, value.isFinite else { return nil }
        let index = Int(Swift.min(Swift.max(value.rounded(), 0), Float(Swift.max(choices.count - 1, 0))))
        return choices.indices.contains(index) ? choices[index] : nil
    }
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
    private let phaser: Phaser?
    private let flanger: Flanger?
    private let limiter: Limiter?
    private let saturation: Saturation?
    private let tremolo: Tremolo?
    private let bitcrusher: Bitcrusher?
    private let tape: Tape?
    private let stereoWidth: StereoWidth?
    private let ringModulator: RingModulator?
    private let frequencyShifter: FrequencyShifter?
    private let pitchCorrector: PitchCorrector?
    private let harmonizer: Harmonizer?
    private let granulator: Granulator?
    /// The correction's targets, worked out once here so a change of key on the render thread
    /// only looks them up: each scale's pitch classes above C, and each tone system's cents for
    /// every root (`tuning × 12 + root`).
    private let scaleMasks: [UInt16]
    private let toneSystemCents: [SIMD16<Float>]

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
        phaser = effect == .phaser ? Phaser(sampleRate: self.sampleRate) : nil
        flanger = effect == .flanger ? Flanger(sampleRate: self.sampleRate) : nil
        limiter = effect == .limiter ? Limiter(sampleRate: self.sampleRate) : nil
        saturation = effect == .saturation ? Saturation(sampleRate: self.sampleRate) : nil
        tremolo = effect == .tremolo ? Tremolo(sampleRate: self.sampleRate) : nil
        bitcrusher = effect == .bitcrusher ? Bitcrusher(sampleRate: self.sampleRate) : nil
        tape = effect == .tape ? Tape(sampleRate: self.sampleRate) : nil
        stereoWidth = effect == .stereoWidth ? StereoWidth(sampleRate: self.sampleRate) : nil
        ringModulator = effect == .ringModulator ? RingModulator(sampleRate: self.sampleRate) : nil
        frequencyShifter = effect == .frequencyShifter ? FrequencyShifter(sampleRate: self.sampleRate) : nil
        pitchCorrector = effect == .pitchCorrection ? PitchCorrector(sampleRate: self.sampleRate) : nil
        harmonizer = effect == .harmonizer ? Harmonizer(sampleRate: self.sampleRate) : nil
        granulator = effect == .granular ? Granulator(sampleRate: self.sampleRate) : nil
        scaleMasks = effect == .pitchCorrection
            ? Scale.allCases.map { PitchCorrector.Settings.mask(root: 0, steps: $0.intervals) } : []
        toneSystemCents = effect == .pitchCorrection ? Self.toneSystemCents() : []
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

    /// How far the output sits behind the input, in seconds: the pitch correction's delay, 0 for
    /// every other effect (the harmonizer's voices lag, its dry sound does not).
    public var latencySeconds: Double { effect == .pitchCorrection ? PitchCorrector.latencySeconds : 0 }

    /// Every value, in address order, to carry into a new kernel.
    public var allValues: [Float] { parameters.indices.map(parameter) }

    /// The compressor's or the limiter's gain reduction in dB (0 or less); 0 for the other effects.
    public var gainReduction: Float { Float(bitPattern: reductionBits.load(ordering: .relaxed)) }

    /// Empties delay lines and tails.
    public func reset() {
        equalizer.reset()
        compressor.reset()
        delay?.reset()
        reverb?.reset()
        chorus?.reset()
        phaser?.reset()
        flanger?.reset()
        limiter?.reset()
        saturation?.reset()
        tremolo?.reset()
        bitcrusher?.reset()
        tape?.reset()
        stereoWidth?.reset()
        ringModulator?.reset()
        frequencyShifter?.reset()
        pitchCorrector?.reset()
        harmonizer?.reset()
        granulator?.reset()
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
        case .phaser: phaser?.process(left: left, right: right, frames: frames)
        case .flanger: flanger?.process(left: left, right: right, frames: frames)
        case .limiter:
            guard let limiter else { return }
            limiter.process(left: left, right: right, frames: frames)
            reductionBits.store(limiter.reduction.bitPattern, ordering: .relaxed)
        case .saturation: saturation?.process(left: left, right: right, frames: frames)
        case .tremolo: tremolo?.process(left: left, right: right, frames: frames)
        case .bitcrusher: bitcrusher?.process(left: left, right: right, frames: frames)
        case .tape: tape?.process(left: left, right: right, frames: frames)
        case .stereoWidth: stereoWidth?.process(left: left, right: right, frames: frames)
        case .ringModulator: ringModulator?.process(left: left, right: right, frames: frames)
        case .frequencyShifter: frequencyShifter?.process(left: left, right: right, frames: frames)
        case .pitchCorrection: pitchCorrector?.process(left: left, right: right, frames: frames)
        case .harmonizer: harmonizer?.process(left: left, right: right, frames: frames)
        case .granular: granulator?.process(left: left, right: right, frames: frames)
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
        case .phaser:
            guard let phaser else { return }
            let s = Phaser.Settings(rate: value(0), depth: value(1), feedback: value(2), mix: value(3))
            if s != phaser.settings { phaser.settings = s }
        case .flanger:
            guard let flanger else { return }
            let s = Flanger.Settings(rate: value(0), depth: value(1), feedback: value(2), mix: value(3))
            if s != flanger.settings { flanger.settings = s }
        case .limiter:
            guard let limiter else { return }
            let s = Limiter.Settings(gain: value(0), ceiling: value(1), release: value(2))
            if s != limiter.settings { limiter.settings = s }
        case .saturation:
            guard let saturation else { return }
            let s = Saturation.Settings(drive: value(0), tone: value(1), mix: value(2))
            if s != saturation.settings { saturation.settings = s }
        case .tremolo:
            guard let tremolo else { return }
            let s = Tremolo.Settings(rate: value(0), depth: value(1), pan: value(2) >= 0.5)
            if s != tremolo.settings { tremolo.settings = s }
        case .bitcrusher:
            guard let bitcrusher else { return }
            let s = Bitcrusher.Settings(bits: value(0), downsample: value(1), mix: value(2))
            if s != bitcrusher.settings { bitcrusher.settings = s }
        case .tape:
            guard let tape else { return }
            let s = Tape.Settings(wow: value(0), saturation: value(1), tone: value(2))
            if s != tape.settings { tape.settings = s }
        case .stereoWidth:
            guard let stereoWidth else { return }
            let s = StereoWidth.Settings(width: value(0))
            if s != stereoWidth.settings { stereoWidth.settings = s }
        case .ringModulator:
            guard let ringModulator else { return }
            let s = RingModulator.Settings(frequency: value(0), mix: value(1))
            if s != ringModulator.settings { ringModulator.settings = s }
        case .frequencyShifter:
            guard let frequencyShifter else { return }
            let s = FrequencyShifter.Settings(shift: value(0), mix: value(1))
            if s != frequencyShifter.settings { frequencyShifter.settings = s }
        case .pitchCorrection:
            guard let pitchCorrector else { return }
            let root = Swift.min(Swift.max(Int(value(0).rounded()), 0), 11)
            let scale = Swift.min(Swift.max(Int(value(1).rounded()), 0), scaleMasks.count - 1)
            let system = Swift.min(Swift.max(Int(value(2).rounded()), 0), toneSystemCents.count / 12 - 1)
            guard scale >= 0, system >= 0 else { return }
            let mask = scaleMasks[scale]
            let rotated = root == 0 ? mask : ((mask << UInt16(root)) | (mask >> UInt16(12 - root))) & 0x0FFF
            let s = PitchCorrector.Settings(allowed: rotated, cents: toneSystemCents[system * 12 + root],
                                            reference: value(3), speed: value(4), amount: value(5))
            if s != pitchCorrector.settings { pitchCorrector.settings = s }
        case .harmonizer:
            guard let harmonizer else { return }
            func shift(_ address: Int) -> Double? {
                HarmonyInterval(index: parameter(address)).semitones.map { Double($0) }
            }
            let s = Harmonizer.Settings(first: shift(0), second: shift(1), third: shift(2), level: value(3),
                                        spread: value(4))
            if s != harmonizer.settings { harmonizer.settings = s }
        case .granular:
            guard let granulator else { return }
            let s = Granulator.Settings(size: value(0), density: value(1), pitch: value(2), position: value(3),
                                        spray: value(4), spread: value(5), mix: value(6))
            if s != granulator.settings { granulator.settings = s }
        }
    }

    /// Every tone system's deviation from twelve equal steps with its 1/1 on each root.
    private static func toneSystemCents() -> [SIMD16<Float>] {
        var tables: [SIMD16<Float>] = []
        for system in TuningSystem.library {
            for root in MusicalContext.rootRange {
                let cents = MusicalContext(root: root, tuning: system.id).centsTable()
                var lanes = SIMD16<Float>.zero
                for (index, value) in cents.prefix(12).enumerated() { lanes[index] = Float(value) }
                tables.append(lanes)
            }
        }
        return tables
    }

    public static func parameters(for effect: StandardEffect) -> [EffectParameter] {
        var list: [EffectParameter] = []
        func add(_ id: String, _ title: String, _ range: ClosedRange<Float>, _ value: Float, _ unit: EffectParameter.Unit) {
            list.append(EffectParameter(address: list.count, identifier: id, title: title, range: range,
                                        defaultValue: value, unit: unit, choices: []))
        }
        // A named choice: its value is the index, so the order of `names` is stored (Law 3).
        func choose(_ id: String, _ title: String, _ names: [String], _ index: Int) {
            list.append(EffectParameter(address: list.count, identifier: id, title: title,
                                        range: 0...Float(Swift.max(names.count - 1, 0)), defaultValue: Float(index),
                                        unit: .choice, choices: names))
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
        case .phaser:
            add("rate", "Rate", 0.05...8, 0.4, .hertz)
            add("depth", "Depth", 0...1, 0.7, .amount)
            add("feedback", "Feedback", 0...0.95, 0.3, .amount)
            add("mix", "Mix", 0...1, 0.5, .amount)
        case .flanger:
            add("rate", "Rate", 0.05...8, 0.25, .hertz)
            add("depth", "Depth", 0...1, 0.7, .amount)
            add("feedback", "Feedback", -0.95...0.95, 0.5, .amount)
            add("mix", "Mix", 0...1, 0.5, .amount)
        case .limiter:
            add("gain", "Gain", 0...24, 0, .decibels)
            add("ceiling", "Ceiling", -24...0, -0.3, .decibels)
            add("release", "Release", 0.005...1, 0.06, .seconds)
        case .saturation:
            add("drive", "Drive", 0...1, 0.4, .amount)
            add("tone", "Tone", 0...1, 0.85, .amount)
            add("mix", "Mix", 0...1, 0.6, .amount)
        case .tremolo:
            add("rate", "Rate", 0.1...20, 5, .hertz)
            add("depth", "Depth", 0...1, 0.5, .amount)
            add("pan", "Pan", 0...1, 0, .boolean)
        case .bitcrusher:
            add("bits", "Bits", 1...16, 8, .ratio)
            add("downsample", "Downsample", 1...64, 4, .ratio)
            add("mix", "Mix", 0...1, 1, .amount)
        case .tape:
            add("wow", "Wow", 0...1, 0.35, .amount)
            add("saturation", "Saturation", 0...1, 0.25, .amount)
            add("tone", "Tone", 0...1, 0.8, .amount)
        case .stereoWidth:
            add("width", "Width", 0...2, 1.4, .ratio)
        case .ringModulator:
            add("frequency", "Frequency", 1...5_000, 440, .hertz)
            add("mix", "Mix", 0...1, 0.5, .amount)
        case .frequencyShifter:
            add("shift", "Shift", -1_000...1_000, 100, .hertz)
            add("mix", "Mix", 0...1, 0.5, .amount)
        case .pitchCorrection:
            // By name; the effect panel can set the three from the song's own frame.
            choose("key", "Key", MusicalContext.rootNames, 0)
            choose("scale", "Scale", Scale.allCases.map(\.title), Scale.allCases.firstIndex(of: .major) ?? 0)
            choose("tuning", "Tone System", TuningSystem.library.map(\.name), 0)
            add("reference", "Concert A", 400...480, 440, .hertz)
            add("speed", "Speed", 0...0.5, 0.04, .seconds)
            add("amount", "Amount", 0...1, 1, .amount)
        case .harmonizer:
            let intervals = HarmonyInterval.allCases.map(\.title)
            choose("voice1", "Voice 1", intervals, HarmonyInterval.fifthUp.rawValue)
            choose("voice2", "Voice 2", intervals, HarmonyInterval.off.rawValue)
            choose("voice3", "Voice 3", intervals, HarmonyInterval.off.rawValue)
            add("level", "Level", 0...1, 0.5, .amount)
            add("spread", "Spread", 0...1, 0.5, .amount)
        case .granular:
            add("size", "Grain Size", 0.01...0.5, 0.08, .seconds)
            add("density", "Density", 0...1, 0.5, .amount)
            add("pitch", "Pitch", -24...24, 0, .amount)
            add("position", "Position", 0...2, 0.25, .seconds)
            add("spray", "Spray", 0...0.5, 0.05, .seconds)
            add("spread", "Spread", 0...1, 0.5, .amount)
            add("mix", "Mix", 0...1, 0.5, .amount)
        }
        return list
    }
}
