import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelKernels

final class EffectKernelTests: XCTestCase {
    private let rate = 48_000.0

    private func process(_ kernel: EffectKernel, _ input: [Float]) -> [Float] {
        var l = input, r = input
        l.withUnsafeMutableBufferPointer { a in
            r.withUnsafeMutableBufferPointer { b in
                guard let x = a.baseAddress, let y = b.baseAddress else { return }
                kernel.process(left: x, right: y, frames: a.count)
            }
        }
        return l
    }

    func testEveryEffectStartsAtItsDefaultsAndHoldsValuesInRange() {
        for effect in StandardEffect.allCases {
            let kernel = EffectKernel(effect: effect, sampleRate: rate)
            XCTAssertFalse(kernel.parameters.isEmpty)
            XCTAssertEqual(kernel.parameters.map(\.address), Array(kernel.parameters.indices))
            XCTAssertEqual(Set(kernel.parameters.map(\.identifier)).count, kernel.parameters.count)
            for p in kernel.parameters {
                XCTAssertTrue(p.range.contains(p.defaultValue), "\(effect) \(p.title)")
                XCTAssertEqual(kernel.parameter(p.address), p.defaultValue)
                kernel.setParameter(p.address, p.range.upperBound + 1_000)
                XCTAssertEqual(kernel.parameter(p.address), p.range.upperBound)
                kernel.setParameter(p.address, .nan)
                XCTAssertEqual(kernel.parameter(p.address), p.defaultValue)
            }
            let noise = (0..<4_096).map { Float(sin(Double($0) * 0.21)) * 0.8 }
            XCTAssertTrue(process(kernel, noise).allSatisfy(\.isFinite), "\(effect)")
        }
    }

    /// A saved insert stores its values by address, so a standard effect's parameters keep their
    /// order: a new one goes at the end. The four effects of ECHOELTOOLS B9/B10, pinned as they shipped.
    func testTheNewEffectsKeepTheirParameterOrder() {
        let expected: [StandardEffect: [String]] = [
            .formantFilter: ["vowel", "resonance", "mix"],
            .transientDesigner: ["attack", "sustain", "output"],
            .midSide: ["width", "midGain", "sideGain", "tilt", "monoBelow"],
            .multibandCompressor: ["lowCrossover", "highCrossover", "lowThreshold", "lowRatio", "midThreshold", "midRatio",
                                   "highThreshold", "highRatio", "attack", "release", "makeup"],
            .dynamicEQ: ["lowFrequency", "lowQ", "lowThreshold", "lowRange", "highFrequency", "highQ", "highThreshold",
                         "highRange", "attack", "release"],
            .multibandClipper: ["inputGain", "lowCrossover", "highCrossover", "lowDrive", "midDrive", "highDrive",
                                "softness", "ceiling", "mix"],
            .deEsser: ["frequency", "threshold", "range", "listen"],
        ]
        for (effect, identifiers) in expected {
            XCTAssertEqual(EffectKernel.parameters(for: effect).map(\.identifier), identifiers, effect.rawValue)
        }
    }

    /// Each new effect's parameters reach its sound: turned from its default, the output changes.
    func testEveryNewEffectHearsItsParameters() {
        let tone: [Float] = (0..<9_600).map { (index: Int) -> Float in
            let t = Double(index) / 48_000
            return Float(0.4 * sin(2 * Double.pi * 180 * t) + 0.2 * sin(2 * Double.pi * 2_700 * t))
        }
        let turned: [(StandardEffect, Int, Float)] = [(.formantFilter, 0, 3), (.transientDesigner, 2, -12),
                                                      (.midSide, 1, -12), (.multibandCompressor, 10, 12),
                                                      (.dynamicEQ, 7, -18), (.multibandClipper, 0, 24),
                                                      (.deEsser, 3, 1)]
        for (effect, address, value) in turned {
            let plain = process(EffectKernel(effect: effect, sampleRate: rate), tone)
            let kernel = EffectKernel(effect: effect, sampleRate: rate)
            kernel.setParameter(address, value)
            let moved = process(kernel, tone)
            let difference = zip(plain.suffix(4_800), moved.suffix(4_800)).map { abs($0 - $1) }.max() ?? 0
            XCTAssertGreaterThan(difference, 0.01, "\(effect.rawValue) address \(address)")
        }
        let multiband = EffectKernel(effect: .multibandCompressor, sampleRate: rate)
        multiband.setParameter(2, -50)
        _ = process(multiband, tone)
        XCTAssertLessThan(multiband.gainReduction, -10, "the meter reads the multiband's deepest band")
    }

    /// The clipper's ranges and defaults as they shipped, and its delay reported to the host in
    /// seconds at the rate the kernel runs at — the other new effects report none.
    func testTheMultibandClipperPinsItsRangesAndReportsItsLatency() {
        let parameters = EffectKernel.parameters(for: .multibandClipper)
        let ranges: [ClosedRange<Float>] = [-12...24, 40...800, 1_000...10_000, 0...18, 0...18, 0...18, 0...1, -12...0, 0...1]
        let defaults: [Float] = [0, 150, 3_000, 0, 0, 0, 0.3, -0.3, 1]
        let units: [EffectParameter.Unit] = [.decibels, .hertz, .hertz, .decibels, .decibels, .decibels, .amount, .decibels, .amount]
        XCTAssertEqual(parameters.map(\.range), ranges)
        XCTAssertEqual(parameters.map(\.defaultValue), defaults)
        XCTAssertEqual(parameters.map(\.unit), units)
        for kernelRate in [44_100.0, 48_000, 96_000] {
            let kernel = EffectKernel(effect: .multibandClipper, sampleRate: kernelRate)
            XCTAssertEqual(kernel.latencySeconds, Double(MultibandClipper.latencySamples) / kernelRate, accuracy: 1e-12)
        }
        XCTAssertEqual(EffectKernel(effect: .dynamicEQ, sampleRate: rate).latencySeconds, 0)
    }

    /// The de-esser's ranges and defaults as they shipped, no delay to report, and its meter: a
    /// 9 kHz tone at −6 dBFS is far over the −30 dB threshold, so its highs come down by the
    /// whole default Range of 6 dB (4.9 dB at 9 kHz in a float simulation, the shelf's corner
    /// being 6.5 kHz), and at a threshold of 0 dB nothing changes at all.
    func testTheDeEsserPinsItsRangesAndTurnsDownOnlyWhatIsOverItsThreshold() {
        let parameters = EffectKernel.parameters(for: .deEsser)
        let ranges: [ClosedRange<Float>] = [3_000...12_000, -60...0, 0...24, 0...1]
        let defaults: [Float] = [6_500, -30, 6, 0]
        let units: [EffectParameter.Unit] = [.hertz, .decibels, .decibels, .boolean]
        XCTAssertEqual(parameters.map(\.range), ranges)
        XCTAssertEqual(parameters.map(\.defaultValue), defaults)
        XCTAssertEqual(parameters.map(\.unit), units)
        XCTAssertEqual(EffectKernel(effect: .deEsser, sampleRate: rate).latencySeconds, 0)
        let hiss: [Float] = (0..<9_600).map { (index: Int) -> Float in
            let phase: Double = 2 * Double.pi * 9_000 * Double(index) / 48_000
            return Float(0.5 * sin(phase))
        }
        func level(_ x: [Float]) -> Float {
            let tail = Array(x.suffix(4_800))
            return 10 * log10f(tail.reduce(Float(0)) { $0 + $1 * $1 } / Float(tail.count))
        }
        let kernel = EffectKernel(effect: .deEsser, sampleRate: rate)
        let change = level(process(kernel, hiss)) - level(hiss)
        XCTAssertLessThan(change, -4)
        XCTAssertGreaterThan(change, -6.01, "never more than Range")
        XCTAssertEqual(kernel.gainReduction, -6, accuracy: 1e-4, "the meter reads the highs' reduction")
        let untouched = EffectKernel(effect: .deEsser, sampleRate: rate)
        untouched.setParameter(1, 0)
        XCTAssertEqual(process(untouched, hiss), hiss, "under the threshold the input passes untouched")
        XCTAssertEqual(untouched.gainReduction, 0)
    }

    /// The reverb's mode is its last parameter, a named choice that starts at Hall: an insert saved
    /// before it existed keeps its five addresses and sounds as it did, and Room is heard.
    func testTheReverbsModeIsItsLastParameterAndStartsAtHall() {
        let kernel = EffectKernel(effect: .reverb, sampleRate: rate)
        XCTAssertEqual(kernel.parameters.map(\.identifier), ["size", "decay", "damping", "predelay", "mix", "mode"])
        let mode = kernel.parameters[5]
        XCTAssertEqual(mode.unit, .choice)
        XCTAssertEqual(mode.choices, ["Hall", "Plate", "Room"])
        XCTAssertEqual(mode.choice(at: kernel.parameter(5)), "Hall")
        let saved = EffectKernel(effect: .reverb, sampleRate: rate, values: [0.6, 2.2, 7_000, 0.02, 0.5])
        XCTAssertEqual(saved.parameter(5), 0, "five stored values: the mode takes Hall")

        let tone: [Float] = (0..<9_600).map { (index: Int) -> Float in
            let phase: Double = 2 * Double.pi * 220 * Double(index) / 48_000
            return index < 2_400 ? Float(0.5 * sin(phase)) : 0
        }
        let hall = EffectKernel(effect: .reverb, sampleRate: rate, values: [0.6, 2.2, 7_000, 0.02, 0.5, 0])
        XCTAssertEqual(process(saved, tone), process(hall, tone), "no stored mode plays the hall")
        let room = EffectKernel(effect: .reverb, sampleRate: rate, values: [0.6, 2.2, 7_000, 0.02, 0.5, 2])
        let roomed = process(room, tone)
        XCTAssertTrue(roomed.allSatisfy(\.isFinite))
        let difference = zip(process(EffectKernel(effect: .reverb, sampleRate: rate, values: [0.6, 2.2, 7_000, 0.02, 0.5]), tone),
                             roomed).map { (pair: (Float, Float)) -> Float in abs(pair.0 - pair.1) }.max() ?? 0
        XCTAssertGreaterThan(difference, 0.001, "the room is heard")
    }

    func testAParameterReachesTheSoundAtTheNextBlockAndCarriesToANewRate() {
        let eq = EffectKernel(effect: .equalizer, sampleRate: rate)
        let tone = (0..<4_800).map { Float(sin(2 * Double.pi * 3_000 * Double($0) / 48_000)) }
        XCTAssertEqual(process(eq, tone), tone, "a flat EQ passes the signal")
        eq.setParameter(7, 12) // High Mid Gain at 3 kHz
        let boosted = process(eq, tone)
        XCTAssertGreaterThan(boosted.suffix(1_000).map { abs($0) }.max() ?? 0, 3)

        let moved = EffectKernel(effect: .equalizer, sampleRate: 44_100, values: eq.allValues)
        XCTAssertEqual(moved.parameter(7), 12)

        let compressor = EffectKernel(effect: .compressor, sampleRate: rate)
        compressor.setParameter(0, -30)
        _ = process(compressor, tone)
        XCTAssertLessThan(compressor.gainReduction, -10, "the meter reads the reduction")
    }

    private func voiceTone(_ hertz: Double) -> [Float] {
        (0..<48_000).map { (index: Int) -> Float in
            let phase = 2 * Double.pi * hertz * Double(index) / 48_000
            return Float(0.5 * sin(phase) + 0.2 * sin(2 * phase))
        }
    }

    private func cents(_ found: Double?, _ expected: Double) -> Double {
        guard let found else { return .infinity }
        return 1_200 * log2(found / expected)
    }

    /// The key and scale are names whose index the kernel turns into targets: an F sung 30 cents
    /// sharp stays F in C major and becomes F sharp in D major.
    func testTheCorrectionFollowsTheChosenKeyAndScale() throws {
        let kernel = EffectKernel(effect: .pitchCorrection, sampleRate: rate)
        let names = kernel.parameters.map(\.identifier)
        let key = try XCTUnwrap(names.firstIndex(of: "key"))
        let scale = try XCTUnwrap(names.firstIndex(of: "scale"))
        XCTAssertEqual(kernel.parameters[key].choice(at: kernel.parameter(key)), "C")
        XCTAssertEqual(kernel.parameters[scale].choice(at: kernel.parameter(scale)), "Major")
        let sung = voiceTone(349.23 * pow(2, 30.0 / 1_200))
        let inC = process(kernel, sung)
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(inC.suffix(4_096)), sampleRate: rate), 349.23), 0, accuracy: 3)
        let inD = EffectKernel(effect: .pitchCorrection, sampleRate: rate)
        inD.setParameter(key, 2)
        let output = process(inD, sung)
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(output.suffix(4_096)), sampleRate: rate), 369.99), 0, accuracy: 3)
    }

    /// Both sides of the effect's output, minus the dry sound: the voices alone.
    private func voices(_ kernel: EffectKernel, _ input: [Float]) -> (left: [Float], right: [Float]) {
        var l = input, r = input
        l.withUnsafeMutableBufferPointer { a in
            r.withUnsafeMutableBufferPointer { b in
                guard let x = a.baseAddress, let y = b.baseAddress else { return }
                kernel.process(left: x, right: y, frames: a.count)
            }
        }
        let minus = { (out: [Float]) -> [Float] in zip(out, input).map { (pair: (Float, Float)) -> Float in pair.0 - pair.1 } }
        return (minus(l), minus(r))
    }

    /// A harmonizer with its two side voices hard left and right at full level, in `style`.
    private func harmonizer(_ style: HarmonyStyle) throws -> EffectKernel {
        let kernel = EffectKernel(effect: .harmonizer, sampleRate: rate)
        let names = kernel.parameters.map(\.identifier)
        kernel.setParameter(try XCTUnwrap(names.firstIndex(of: "level")), 1)
        kernel.setParameter(try XCTUnwrap(names.firstIndex(of: "spread")), 1)
        kernel.setParameter(try XCTUnwrap(names.firstIndex(of: "style")), Float(style.rawValue))
        return kernel
    }

    /// The style is the effect's last parameter, a named choice that starts at Free: an insert saved
    /// before it existed keeps its addresses and plays as it did.
    func testTheHarmonizersStyleIsItsLastParameterAndStartsFree() {
        let kernel = EffectKernel(effect: .harmonizer, sampleRate: rate)
        XCTAssertEqual(kernel.parameters.map(\.identifier), ["voice1", "voice2", "voice3", "level", "spread", "style"])
        let style = kernel.parameters[5]
        XCTAssertEqual(style.unit, .choice)
        XCTAssertEqual(style.choices, HarmonyStyle.allCases.map(\.title))
        XCTAssertEqual(style.choice(at: kernel.parameter(5)), "Free")
        let saved = EffectKernel(effect: .harmonizer, sampleRate: rate, values: [12, 0, 0, 1, 0.5])
        XCTAssertEqual(saved.parameter(5), Float(HarmonyStyle.free.rawValue), "five stored values: the style takes its default")
    }

    func testOrganumSingsAFifthAndAnOctaveBelowTheVoice() throws {
        let sung = voices(try harmonizer(.organum), voiceTone(330))
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(sung.left.suffix(6_000)), sampleRate: rate),
                             330 * pow(2, -7.0 / 12)), 0, accuracy: 3)
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(sung.right.suffix(6_000)), sampleRate: rate), 165), 0,
                       accuracy: 3)
    }

    /// Diatonic thirds come from the key the host hands over: E takes G and C in C major, G sharp
    /// and C sharp in E major.
    func testDiatonicThirdsSingInTheSongsKey() throws {
        let inC = try harmonizer(.diatonicThirds)
        inC.follow(key: SongKey(MusicalContext(root: 0, scale: .major)))
        let c = voices(inC, voiceTone(329.63))
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(c.left.suffix(6_000)), sampleRate: rate), 392.00), 0, accuracy: 4)
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(c.right.suffix(6_000)), sampleRate: rate), 261.63), 0, accuracy: 4)
        let inE = try harmonizer(.diatonicThirds)
        inE.follow(key: SongKey(MusicalContext(root: 4, scale: .major)))
        XCTAssertEqual(inE.key.root, 4)
        let e = voices(inE, voiceTone(329.63))
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(e.left.suffix(6_000)), sampleRate: rate), 415.30), 0, accuracy: 4)
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(e.right.suffix(6_000)), sampleRate: rate), 277.18), 0, accuracy: 4)
    }

    /// The ison sings the key's root below the voice: D under an A in D Dorian.
    func testTheIsonSingsTheKeysRoot() throws {
        let kernel = try harmonizer(.ison)
        kernel.follow(key: SongKey(MusicalContext(root: 2, scale: .dorian)))
        let sung = voices(kernel, voiceTone(440))
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(sung.left.suffix(6_000)), sampleRate: rate), 293.66), 0,
                       accuracy: 5)
    }

    /// A style a later build adds plays Free here; Free keeps the chosen intervals.
    func testAStyleThisBuildDoesNotKnowPlaysFree() throws {
        XCTAssertEqual(EffectKernel.voicing(HarmonyStyle(index: 40), in: SongKey()), .free)
        let kernel = EffectKernel(effect: .harmonizer, sampleRate: rate)
        kernel.setParameter(5, 40)
        XCTAssertEqual(kernel.parameter(5), Float(HarmonyStyle.allCases.count - 1), "the range holds the known styles")
    }

    func testAHarmonizerVoiceIsChosenByItsIntervalsName() throws {
        let kernel = EffectKernel(effect: .harmonizer, sampleRate: rate)
        let voice = kernel.parameters[0]
        XCTAssertEqual(voice.unit, .choice)
        XCTAssertEqual(voice.choices, HarmonyInterval.allCases.map(\.title))
        XCTAssertEqual(voice.choice(at: kernel.parameter(0)), "Fifth up")
        kernel.setParameter(0, Float(HarmonyInterval.octaveUp.rawValue))
        kernel.setParameter(3, 1)
        let input = voiceTone(220)
        let added = zip(process(kernel, input), input).map { (pair: (Float, Float)) -> Float in pair.0 - pair.1 }
        XCTAssertEqual(cents(PitchTracker.frequency(of: Array(added.suffix(6_000)), sampleRate: rate), 440), 0, accuracy: 3)
        kernel.setParameter(0, Float(HarmonyInterval.off.rawValue))
        let silent = process(kernel, input)
        XCTAssertEqual(Array(silent.suffix(1_000)), Array(input.suffix(1_000)), "every voice off passes the sound")
    }

    /// The tail a host waits for after the input stops grows with what makes it: the reverb's decay,
    /// the delay's feedback. Room rings shorter than Hall at the same decay; a delay without feedback
    /// rings for one repeat; the longest stays at the cap.
    func testTheReverbAndTheDelayReportATailThatGrowsWithDecayAndFeedback() {
        let reverb = EffectKernel(effect: .reverb, sampleRate: rate)
        let hall = reverb.tailSeconds
        XCTAssertGreaterThan(hall, 2.2, "at least the default decay")
        reverb.setParameter(1, 10)
        XCTAssertGreaterThan(reverb.tailSeconds, hall + 7)
        let longHall = reverb.tailSeconds
        reverb.setParameter(5, 2) // Room
        XCTAssertLessThan(reverb.tailSeconds, longHall, "Room decays faster than the decay set")
        XCTAssertGreaterThan(reverb.tailSeconds, 0)

        let delay = EffectKernel(effect: .delay, sampleRate: rate)
        let plain = delay.tailSeconds
        XCTAssertGreaterThan(plain, 0.375)
        delay.setParameter(1, 0.8)
        XCTAssertGreaterThan(delay.tailSeconds, plain)
        delay.setParameter(1, 0)
        XCTAssertEqual(delay.tailSeconds, 0.375, accuracy: 1e-6, "one repeat without feedback")
        delay.setParameter(0, 2)
        delay.setParameter(1, 0.95)
        XCTAssertEqual(delay.tailSeconds, EffectKernel.longestTailSeconds)
    }

    /// An EQ, a compressor or a limiter stops with its input; no effect reports a tail that is
    /// negative, past the cap or not a number, at either end of any parameter.
    func testEveryTailIsFiniteAndOnlyTheRingingEffectsHaveOne() {
        for effect in [StandardEffect.equalizer, .compressor, .limiter, .saturation, .stereoWidth] {
            XCTAssertEqual(EffectKernel(effect: effect, sampleRate: rate).tailSeconds, 0, effect.rawValue)
        }
        for effect in [StandardEffect.chorus, .flanger, .phaser, .tape, .granular, .pitchCorrection, .harmonizer] {
            XCTAssertGreaterThan(EffectKernel(effect: effect, sampleRate: rate).tailSeconds, 0, effect.rawValue)
        }
        for effect in StandardEffect.allCases {
            for edge in [false, true] {
                let kernel = EffectKernel(effect: effect, sampleRate: rate)
                for p in kernel.parameters { kernel.setParameter(p.address, edge ? p.range.upperBound : p.range.lowerBound) }
                let tail = kernel.tailSeconds
                XCTAssertTrue(tail.isFinite, "\(effect)")
                XCTAssertTrue((0...EffectKernel.longestTailSeconds).contains(tail), "\(effect) \(tail)")
            }
        }
    }

    /// The tail is what the delay plays: after it, an impulse's repeats have fallen below −60 dB.
    func testTheDelayIsSilentAfterTheTailItReports() {
        let delay = EffectKernel(effect: .delay, sampleRate: rate, values: [0.01, 0.5, 1, 6_000, 0])
        let tailFrames = Int(delay.tailSeconds * rate)
        XCTAssertGreaterThan(tailFrames, 480)
        var impulse = [Float](repeating: 0, count: tailFrames + 4_800)
        impulse[0] = 1
        let out = process(delay, impulse)
        XCTAssertGreaterThan(out[300..<700].map { abs($0) }.max() ?? 0, 0.5, "the first repeat")
        XCTAssertLessThan(out[(tailFrames + 50)...].map { abs($0) }.max() ?? 1, 0.001)
    }

    /// A host's ramp runs over its frames exactly where the kernel says it can: a number moves in a
    /// straight line — a tenth of the way after a tenth of a one-second ramp — and a named choice,
    /// a switch and the delay's time (which glides itself) take the end value at once.
    func testAHostsRampRunsOverItsFramesExactlyWhereTheKernelCanRamp() {
        let silence = [Float](repeating: 0, count: 256)
        let tenth = [Float](repeating: 0, count: 4_800)
        for effect in StandardEffect.allCases {
            for p in EffectKernel.parameters(for: effect) {
                let kernel = EffectKernel(effect: effect, sampleRate: rate)
                _ = process(kernel, silence)
                let start = kernel.playingValue(p.address)
                let end = p.defaultValue - p.range.lowerBound > p.range.upperBound - p.defaultValue
                    ? p.range.lowerBound : p.range.upperBound
                kernel.rampParameter(p.address, to: end, frames: 48_000)
                XCTAssertEqual(kernel.parameter(p.address), end, "\(effect) \(p.identifier) is set to its end")
                _ = process(kernel, tenth)
                let now = kernel.playingValue(p.address)
                let label = "\(effect) \(p.identifier)"
                if EffectKernel.canRamp(effect, p.address) {
                    XCTAssertEqual(now, start + (end - start) * 0.1, accuracy: abs(end - start) * 1e-3, label)
                } else {
                    XCTAssertEqual(now, end, label)
                }
                if p.unit == .choice || p.unit == .boolean {
                    XCTAssertFalse(EffectKernel.canRamp(effect, p.address), "\(label) never ramps")
                }
            }
        }
        XCTAssertFalse(EffectKernel.canRamp(.delay, 0), "the delay's time glides itself")
        XCTAssertTrue(EffectKernel.canRamp(.reverb, 1))
        XCTAssertFalse(EffectKernel.canRamp(.reverb, 99))
    }

    /// A ramp shorter than a glide is stretched to one, so a host's 32-frame step still glides; a
    /// value set during a ramp replaces it; a ramp before the first block is taken at once.
    func testAShortRampGlidesAndANewValueReplacesARamp() {
        let kernel = EffectKernel(effect: .equalizer, sampleRate: rate)
        kernel.rampParameter(10, to: 12, frames: 4_800)
        _ = process(kernel, [Float](repeating: 0, count: 32))
        XCTAssertEqual(kernel.playingValue(10), 12, "before the first block the song's value is taken at once")

        kernel.rampParameter(10, to: -12, frames: 32)
        _ = process(kernel, [Float](repeating: 0, count: 64))
        XCTAssertGreaterThan(kernel.playingValue(10), 0, "64 frames into a 32-frame ramp of 24 dB it is still on its way")
        _ = process(kernel, [Float](repeating: 0, count: 960))
        XCTAssertEqual(kernel.playingValue(10), -12, "after the glide it is there")

        kernel.rampParameter(10, to: 12, frames: 48_000)
        _ = process(kernel, [Float](repeating: 0, count: 480))
        kernel.setParameter(10, -6)
        _ = process(kernel, [Float](repeating: 0, count: 9_600))
        XCTAssertEqual(kernel.playingValue(10), -6, accuracy: 1e-3, "the newer value wins over the ramp")
    }
}
