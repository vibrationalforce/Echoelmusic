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
///
/// A number the sound already plays glides to a new value over about 10 ms, set again every 32
/// frames, instead of stepping in one sample: a turned value field, a MIDI knob, an automation
/// step or a route threw the EQ's high shelf from −18 to +18 dB in one sample — a step of nearly
/// twice the level — and the chorus' depth, the tape's wow and the limiter's ceiling as hard
/// (click hunt, 2026-11-01). Named choices and switches still change at once, and so does every
/// value set before the first block, so an effect loads as its song stores it.
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
    /// The song's key (`SongKey.packed`), which the harmonizer's key-following styles sing in. Any
    /// thread writes it (`follow(key:)`); the render thread picks it up with the parameters. Until
    /// a host tells it — another app has no song key — it is C, with no scale: major on C.
    private let keyBits = Atomic<UInt64>(SongKey().packed)
    /// Render thread: the values the sound plays now, gliding toward the ones set.
    private let playing: UnsafeMutablePointer<Float>
    /// Per parameter: whether it glides (a number) or changes at once (a choice, a switch), and how
    /// close to its value it counts as there.
    private let glides: UnsafeMutablePointer<Bool>
    private let arrived: UnsafeMutablePointer<Float>
    private var isGliding = false
    private var hasProcessed = false
    /// Frames between two settings while a value glides: 0.67 ms at 48 kHz.
    static let glideFrames = 32
    /// The glide's time constant.
    static let glideSeconds: Float = 0.01

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
    private let formantFilter: FormantFilter?
    private let transientDesigner: TransientDesigner?
    private let midSide: MidSide?
    private let multiband: MultibandCompressor?
    private let dynamicEQ: DynamicEQ?
    private let multibandClipper: MultibandClipper?
    private let deEsser: DeEsser?
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
        playing = .allocate(capacity: parameters.count)
        glides = .allocate(capacity: parameters.count)
        arrived = .allocate(capacity: parameters.count)
        for (index, parameter) in parameters.enumerated() {
            let value = index < from.count && from[index].isFinite ? from[index] : parameter.defaultValue
            (values + index).initialize(to: Atomic(Self.clamp(value, parameter).bitPattern))
            (playing + index).initialize(to: Self.clamp(value, parameter))
            (glides + index).initialize(to: Self.glidesHere(effect, parameter))
            (arrived + index).initialize(to: (parameter.range.upperBound - parameter.range.lowerBound) * 1e-5)
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
        formantFilter = effect == .formantFilter ? FormantFilter(sampleRate: self.sampleRate) : nil
        transientDesigner = effect == .transientDesigner ? TransientDesigner(sampleRate: self.sampleRate) : nil
        midSide = effect == .midSide ? MidSide(sampleRate: self.sampleRate) : nil
        multiband = effect == .multibandCompressor ? MultibandCompressor(sampleRate: self.sampleRate) : nil
        dynamicEQ = effect == .dynamicEQ ? DynamicEQ(sampleRate: self.sampleRate) : nil
        multibandClipper = effect == .multibandClipper ? MultibandClipper(sampleRate: self.sampleRate) : nil
        deEsser = effect == .deEsser ? DeEsser(sampleRate: self.sampleRate) : nil
        scaleMasks = effect == .pitchCorrection
            ? Scale.allCases.map { PitchCorrector.Settings.mask(root: 0, steps: $0.intervals) } : []
        toneSystemCents = effect == .pitchCorrection ? Self.toneSystemCents() : []
        applySettings()
    }

    deinit {
        values.deinitialize(count: parameters.count)
        values.deallocate()
        playing.deallocate()
        glides.deallocate()
        arrived.deallocate()
    }

    /// Whether the kernel glides `parameter`: every number, but not a named choice or a switch,
    /// and not the delay's time — the delay glides its read position itself, sample by sample, as
    /// a tape's would (`StereoDelay`), and a second glide on top bent that sweep into a step.
    private static func glidesHere(_ effect: StandardEffect, _ parameter: EffectParameter) -> Bool {
        guard parameter.unit != .choice, parameter.unit != .boolean else { return false }
        return !(effect == .delay && parameter.identifier == "time")
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

    /// Any thread, the render thread included (the engine hands every insert the snapshot's key at
    /// each chunk): the song's key. Only a change reaches the sound, at the start of the next block.
    public func follow(key: SongKey) {
        let packed = key.packed
        guard keyBits.load(ordering: .relaxed) != packed else { return }
        keyBits.store(packed, ordering: .relaxed)
        revision.wrappingAdd(1, ordering: .releasing)
    }

    /// The key the effect plays in now.
    public var key: SongKey { SongKey(packed: keyBits.load(ordering: .relaxed)) }

    /// How far the output sits behind the input, in seconds: the pitch correction's delay and the
    /// multiband clipper's oversampling and look-ahead (`MultibandClipper.latencySamples`), 0 for
    /// every other effect (the harmonizer's voices lag, its dry sound does not).
    public var latencySeconds: Double {
        switch effect {
        case .pitchCorrection: PitchCorrector.latencySeconds
        case .multibandClipper: Double(MultibandClipper.latencySamples) / sampleRate
        default: 0
        }
    }

    /// Every value, in address order, to carry into a new kernel.
    public var allValues: [Float] { parameters.indices.map(parameter) }

    /// The compressor's, the multiband's (its deepest band), the limiter's or the de-esser's (its
    /// highs) gain reduction in dB (0 or less); 0 for the other effects.
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
        formantFilter?.reset()
        transientDesigner?.reset()
        midSide?.reset()
        multiband?.reset()
        dynamicEQ?.reset()
        multibandClipper?.reset()
        deEsser?.reset()
    }

    /// Render thread: processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let current = revision.load(ordering: .acquiring)
        if current != applied {
            applied = current
            for index in 0..<parameters.count {
                let target = Float(bitPattern: values[index].load(ordering: .relaxed))
                if !hasProcessed || !glides[index] {
                    playing[index] = target
                } else if playing[index] != target {
                    isGliding = true
                }
            }
            if !isGliding { applySettings() }
        }
        hasProcessed = true
        guard isGliding else {
            render(left: left, right: right, frames: frames)
            return
        }
        var done = 0
        while done < frames {
            let piece = Swift.min(Self.glideFrames, frames - done)
            isGliding = glide(frames: piece)
            applySettings()
            render(left: left + done, right: right + done, frames: piece)
            done += piece
        }
    }

    /// Render thread: every gliding value `frames` further toward its set value. Whether one is
    /// still on its way.
    private func glide(frames: Int) -> Bool {
        let pole = expf(-Float(frames) / (Self.glideSeconds * Float(sampleRate)))
        var moving = false
        for index in 0..<parameters.count where glides[index] {
            let target = Float(bitPattern: values[index].load(ordering: .relaxed))
            var now = playing[index]
            guard now != target else { continue }
            now = target + (now - target) * pole
            if Swift.abs(now - target) <= arrived[index] || !now.isFinite {
                now = target
            } else {
                moving = true
            }
            playing[index] = now
        }
        return moving
    }

    /// Render thread: the effect itself on `frames` samples, at the values it plays now.
    private func render(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
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
        case .formantFilter: formantFilter?.process(left: left, right: right, frames: frames)
        case .transientDesigner: transientDesigner?.process(left: left, right: right, frames: frames)
        case .midSide: midSide?.process(left: left, right: right, frames: frames)
        case .multibandCompressor:
            guard let multiband else { return }
            multiband.process(left: left, right: right, frames: frames)
            reductionBits.store(multiband.reduction.bitPattern, ordering: .relaxed)
        case .dynamicEQ: dynamicEQ?.process(left: left, right: right, frames: frames)
        case .multibandClipper: multibandClipper?.process(left: left, right: right, frames: frames)
        case .deEsser:
            guard let deEsser else { return }
            deEsser.process(left: left, right: right, frames: frames)
            reductionBits.store(deEsser.reduction.bitPattern, ordering: .relaxed)
        }
    }

    /// What the sound plays now: the set value, or where a glide toward it has got to.
    private func value(_ address: Int) -> Double {
        address >= 0 && address < parameters.count ? Double(playing[address]) : 0
    }

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
            let style = HarmonyStyle(index: parameter(5))
            let s = Harmonizer.Settings(first: shift(0), second: shift(1), third: shift(2), level: value(3),
                                        spread: value(4), voicing: Self.voicing(style, in: key))
            if s != harmonizer.settings { harmonizer.settings = s }
        case .granular:
            guard let granulator else { return }
            let s = Granulator.Settings(size: value(0), density: value(1), pitch: value(2), position: value(3),
                                        spray: value(4), spread: value(5), mix: value(6))
            if s != granulator.settings { granulator.settings = s }
        case .formantFilter:
            guard let formantFilter else { return }
            let s = FormantFilter.Settings(vowel: value(0), resonance: value(1), mix: value(2))
            if s != formantFilter.settings { formantFilter.settings = s }
        case .transientDesigner:
            guard let transientDesigner else { return }
            let s = TransientDesigner.Settings(attack: value(0), sustain: value(1), output: value(2))
            if s != transientDesigner.settings { transientDesigner.settings = s }
        case .midSide:
            guard let midSide else { return }
            let s = MidSide.Settings(width: value(0), midGain: value(1), sideGain: value(2), tilt: value(3),
                                     monoBelow: value(4))
            if s != midSide.settings { midSide.settings = s }
        case .multibandCompressor:
            guard let multiband else { return }
            let s = MultibandCompressor.Settings(lowCrossover: value(0), highCrossover: value(1),
                                                 lowThreshold: value(2), midThreshold: value(4), highThreshold: value(6),
                                                 lowRatio: value(3), midRatio: value(5), highRatio: value(7),
                                                 attack: value(8), release: value(9), makeup: value(10))
            if s != multiband.settings { multiband.settings = s }
        case .dynamicEQ:
            guard let dynamicEQ else { return }
            let s = DynamicEQ.Settings(low: DynamicEQ.Band(frequency: value(0), q: value(1), threshold: value(2), range: value(3)),
                                       high: DynamicEQ.Band(frequency: value(4), q: value(5), threshold: value(6), range: value(7)),
                                       attack: value(8), release: value(9))
            if s != dynamicEQ.settings { dynamicEQ.settings = s }
        case .multibandClipper:
            guard let multibandClipper else { return }
            let s = MultibandClipper.Settings(inputGain: value(0), lowCrossover: value(1), highCrossover: value(2),
                                              lowDrive: value(3), midDrive: value(4), highDrive: value(5),
                                              softness: value(6), ceiling: value(7), mix: value(8))
            if s != multibandClipper.settings { multibandClipper.settings = s }
        case .deEsser:
            guard let deEsser else { return }
            let s = DeEsser.Settings(frequency: value(0), threshold: value(1), range: value(2), listen: value(3) >= 0.5)
            if s != deEsser.settings { deEsser.settings = s }
        }
    }

    /// The harmonizer's voicing for a style in a key: the style's two voices for every pitch class,
    /// or the ison's root. Arithmetic on two vectors: it runs on the render thread when the style or
    /// the key changes.
    static func voicing(_ style: HarmonyStyle, in key: SongKey) -> Harmonizer.Voicing {
        switch style {
        case .free:
            return .free
        case .ison:
            return .ison(root: key.root, reference: key.concertPitch)
        case .organum, .organumAtTheFourth, .fauxbourdon, .diatonicThirds:
            var left = SIMD16<Float>.zero
            var right = SIMD16<Float>.zero
            for note in 0..<12 {
                guard let sides = style.sides(for: note, in: key) else { return .free }
                left[note] = Float(sides.left)
                right[note] = Float(sides.right)
            }
            return .following(left: left, right: right, reference: key.concertPitch)
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
            add("feedback", "Feedback", -Float(Flanger.maximumFeedback)...Float(Flanger.maximumFeedback), 0.5, .amount)
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
            // Appended (VOX): an insert saved before it has no value here and plays Free, as it did.
            choose("style", "Style", HarmonyStyle.allCases.map(\.title), HarmonyStyle.free.rawValue)
        case .granular:
            add("size", "Grain Size", 0.01...0.5, 0.08, .seconds)
            add("density", "Density", 0...1, 0.5, .amount)
            add("pitch", "Pitch", -24...24, 0, .amount)
            add("position", "Position", 0...2, 0.25, .seconds)
            add("spray", "Spray", 0...0.5, 0.05, .seconds)
            add("spread", "Spread", 0...1, 0.5, .amount)
            add("mix", "Mix", 0...1, 0.5, .amount)
        case .formantFilter:
            // 0 "a" · 1 "e" · 2 "i" · 3 "o" · 4 "u", morphing in between: a number, so it sweeps.
            add("vowel", "Vowel", 0...4, 0, .amount)
            add("resonance", "Resonance", 0...1, 0.5, .amount)
            add("mix", "Mix", 0...1, 1, .amount)
        case .transientDesigner:
            add("attack", "Attack", -24...24, 0, .decibels)
            add("sustain", "Sustain", -24...24, 0, .decibels)
            add("output", "Output", -24...12, 0, .decibels)
        case .midSide:
            add("width", "Width", 0...2, 1, .ratio)
            add("midGain", "Mid Gain", -24...12, 0, .decibels)
            add("sideGain", "Side Gain", -24...12, 0, .decibels)
            add("tilt", "Side Tilt", -6...6, 0, .decibels)
            add("monoBelow", "Mono Below", 20...500, 20, .hertz)
        case .multibandCompressor:
            add("lowCrossover", "Low Crossover", 50...1_000, 200, .hertz)
            add("highCrossover", "High Crossover", 1_000...12_000, 2_500, .hertz)
            add("lowThreshold", "Low Threshold", -60...0, -18, .decibels)
            add("lowRatio", "Low Ratio", 1...20, 3, .ratio)
            add("midThreshold", "Mid Threshold", -60...0, -18, .decibels)
            add("midRatio", "Mid Ratio", 1...20, 2, .ratio)
            add("highThreshold", "High Threshold", -60...0, -18, .decibels)
            add("highRatio", "High Ratio", 1...20, 2, .ratio)
            add("attack", "Attack", 0.0001...0.2, 0.01, .seconds)
            add("release", "Release", 0.01...2, 0.15, .seconds)
            add("makeup", "Makeup", 0...24, 0, .decibels)
        case .dynamicEQ:
            add("lowFrequency", "Band 1 Freq", 20...20_000, 250, .hertz)
            add("lowQ", "Band 1 Q", 0.3...8, 1, .ratio)
            add("lowThreshold", "Band 1 Threshold", -60...0, -24, .decibels)
            add("lowRange", "Band 1 Range", -18...18, -6, .decibels)
            add("highFrequency", "Band 2 Freq", 20...20_000, 3_000, .hertz)
            add("highQ", "Band 2 Q", 0.3...8, 1, .ratio)
            add("highThreshold", "Band 2 Threshold", -60...0, -24, .decibels)
            add("highRange", "Band 2 Range", -18...18, -6, .decibels)
            add("attack", "Attack", 0.0001...0.2, 0.005, .seconds)
            add("release", "Release", 0.01...2, 0.15, .seconds)
        case .multibandClipper:
            add("inputGain", "Input", -12...24, 0, .decibels)
            add("lowCrossover", "Low Crossover", 40...800, 150, .hertz)
            add("highCrossover", "High Crossover", 1_000...10_000, 3_000, .hertz)
            add("lowDrive", "Low Drive", 0...18, 0, .decibels)
            add("midDrive", "Mid Drive", 0...18, 0, .decibels)
            add("highDrive", "High Drive", 0...18, 0, .decibels)
            add("softness", "Softness", 0...1, 0.3, .amount)
            add("ceiling", "Ceiling", -12...0, -0.3, .decibels)
            add("mix", "Mix", 0...1, 1, .amount)
        case .deEsser:
            add("frequency", "Frequency", 3_000...12_000, 6_500, .hertz)
            add("threshold", "Threshold", -60...0, -30, .decibels)
            add("range", "Range", 0...24, 6, .decibels)
            add("listen", "Listen", 0...1, 0, .boolean)
        }
        return list
    }
}
