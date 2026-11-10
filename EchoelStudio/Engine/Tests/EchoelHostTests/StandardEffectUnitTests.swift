import AVFoundation
import EchoelCore
@testable import EchoelKernels
import XCTest
@testable import EchoelHost

final class StandardEffectUnitTests: XCTestCase {
    private func unit(_ effect: StandardEffect) throws -> StandardEffectUnit {
        let unit = try StandardEffectUnit(componentDescription: StandardEffectUnit.audioComponent(effect.component))
        try unit.allocateRenderResources()
        return unit
    }

    private func render(_ unit: StandardEffectUnit, _ input: [Float]) -> [Float] {
        let effect = HostedEffect(render: unit.renderBlock, sampleRate: 48_000, maximumFrames: 4_096, owner: unit)
        var left = input, right = input
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let a = l.baseAddress, let b = r.baseAddress else { return }
                var done = 0
                while done < l.count {
                    let n = Swift.min(256, l.count - done)
                    effect.process(frames: n, left: a + done, right: b + done)
                    done += n
                }
            }
        }
        return left
    }

    func testEachStandardEffectIsAStereoEffectWithItsParametersInATree() throws {
        for effect in StandardEffect.allCases {
            let u = try unit(effect)
            XCTAssertEqual(u.effect, effect)
            XCTAssertEqual(u.inputBusses.count, 1)
            XCTAssertEqual(u.outputBusses.count, 1)
            XCTAssertEqual(u.parameterTree?.allParameters.count, EffectKernel.parameters(for: effect).count)
        }
        XCTAssertThrowsError(try StandardEffectUnit(componentDescription: StandardEffectUnit.audioComponent(OwnPlugin.synth.component)),
                             "only a standard effect's id makes one")
    }

    /// A host reads the one channel layout the unit plays — stereo to stereo — before it offers
    /// the insert, instead of guessing and getting a refusal at load.
    func testEachStandardEffectDeclaresStereoInStereoOut() throws {
        for effect in StandardEffect.allCases {
            let u = try unit(effect)
            XCTAssertEqual(u.channelCapabilities?.map(\.intValue), [2, 2], "\(effect)")
        }
    }

    /// A named choice reaches a host as an indexed parameter with its names.
    func testANamedChoiceIsAnIndexedParameterWithItsNames() throws {
        let u = try unit(.harmonizer)
        let voice = try XCTUnwrap(u.parameterTree?.parameter(withAddress: 0))
        XCTAssertEqual(voice.unit, .indexed)
        XCTAssertEqual(voice.valueStrings, HarmonyInterval.allCases.map(\.title))
        XCTAssertNil(u.parameterTree?.parameter(withAddress: 3)?.valueStrings, "a number has no names")
    }

    /// The engine hands every insert the song's key (VOX): Echoel's harmonizer takes it through its
    /// host, keeps it when its resources are made again, and lists its styles by name; a unit that is
    /// not Echoel's never hears of it.
    func testTheHarmonizerTakesTheSongsKeyThroughItsHost() throws {
        let u = try unit(.harmonizer)
        let style = try XCTUnwrap(u.parameterTree?.parameter(withAddress: 5))
        XCTAssertEqual(style.unit, .indexed)
        XCTAssertEqual(style.valueStrings, HarmonyStyle.allCases.map(\.title))
        XCTAssertEqual(u.key, SongKey(), "C, no scale, until the engine says otherwise")
        let gMajor = SongKey(MusicalContext(root: 7, scale: .major))
        HostedEffect(render: u.renderBlock, sampleRate: 48_000, maximumFrames: 4_096, owner: u).follow(key: gMajor)
        XCTAssertEqual(u.key, gMajor)
        u.deallocateRenderResources()
        try u.allocateRenderResources()
        XCTAssertEqual(u.key, gMajor, "a new kernel keeps the key")
        HostedEffect(render: u.renderBlock, sampleRate: 48_000, maximumFrames: 4_096, owner: nil).follow(key: SongKey())
        XCTAssertEqual(u.key, gMajor, "a host without Echoelmusic's unit passes nothing on")
    }

    func testOnlyThePitchCorrectionReportsALatency() throws {
        XCTAssertEqual(try unit(.pitchCorrection).latency, 0.019, accuracy: 0.0005)
        XCTAssertEqual(try unit(.harmonizer).latency, 0)
        XCTAssertEqual(try unit(.equalizer).latency, 0)
    }

    /// The engine's delay compensation reads the unit's latency through the effect it plays.
    func testTheHostedEffectReportsItsUnitsLatencyInFramesAndNoneWhileBypassed() throws {
        let tuned = try unit(.pitchCorrection)
        let effect = HostedEffect(render: tuned.renderBlock, sampleRate: 48_000, maximumFrames: 4_096, owner: tuned)
        XCTAssertEqual(effect.latencyFrames, PluginLatency.frames(seconds: tuned.latency, sampleRate: 48_000))
        XCTAssertEqual(Double(effect.latencyFrames), 912, accuracy: 24, "about 19 ms at 48 kHz")
        let bypassed = HostedEffect(render: tuned.renderBlock, sampleRate: 48_000, maximumFrames: 4_096, isBypassed: true,
                                    owner: tuned)
        XCTAssertEqual(bypassed.latencyFrames, 0)
        let flat = try unit(.equalizer)
        XCTAssertEqual(HostedEffect(render: flat.renderBlock, sampleRate: 48_000, maximumFrames: 4_096, owner: flat).latencyFrames, 0)
        XCTAssertEqual(HostedEffect(render: flat.renderBlock, sampleRate: 48_000, maximumFrames: 4_096, owner: nil).latencyFrames, 0,
                       "without its unit there is nothing to ask")
    }

    func testTheExtensionCopyIsTheSameEffectAndPlaysAsADemoUntilUnlocked() throws {
        let paid = try StandardEffectUnit(componentDescription: StandardEffectUnit.audioComponent(StandardEffect.equalizer.extensionComponent))
        try paid.allocateRenderResources()
        XCTAssertEqual(paid.effect, .equalizer)
        XCTAssertTrue(paid.isUnlocked, "a unit plays until something locks it")
        paid.isUnlocked = false
        let rate = 48_000
        let step: Double = 2 * Double.pi * 440 / Double(rate)
        let input: [Float] = (0..<(30 * rate)).map { (n: Int) -> Float in
            let phase: Double = Double(n) * step
            return Float(sin(phase)) * 0.5
        }
        let out = render(paid, input)
        func peak(_ seconds: ClosedRange<Double>) -> Float {
            let from = Int(seconds.lowerBound * Double(rate))
            let to = Int(seconds.upperBound * Double(rate))
            return out[from..<to].map { abs($0) }.max() ?? 0
        }
        XCTAssertGreaterThan(peak(1...2), 0.3, "the demo plays")
        XCTAssertEqual(peak(28.1...29.9), 0, "then two seconds of silence")
        XCTAssertFalse(StandardEffectUnit.demoIsSilent(atFrame: 0, sampleRate: 48_000))
        XCTAssertTrue(StandardEffectUnit.demoIsSilent(atFrame: 29 * 48_000, sampleRate: 48_000))
        XCTAssertFalse(StandardEffectUnit.demoIsSilent(atFrame: 31 * 48_000, sampleRate: 48_000), "and again")

        let free = try self.unit(.equalizer)
        XCTAssertTrue(free.isUnlocked)
        let late: [Float] = Array(input[(28 * rate)..<(29 * rate)])
        let freePeak: Float = render(free, late).map { abs($0) }.max() ?? 0
        XCTAssertGreaterThan(freePeak, 0.3, "the app's own copy never goes silent")
    }

    func testTheDelayRepeatsAnImpulseWhenItsTreeSaysSo() throws {
        let delay = try unit(.delay)
        let tree = try XCTUnwrap(delay.parameterTree)
        tree.parameter(withAddress: 0)?.value = 0.01 // time
        tree.parameter(withAddress: 1)?.value = 0 // feedback
        tree.parameter(withAddress: 2)?.value = 1 // mix
        var impulse = [Float](repeating: 0, count: 2_000)
        impulse[0] = 1
        let out = render(delay, impulse)
        XCTAssertEqual(out[0], 0, accuracy: 1e-6, "fully wet")
        XCTAssertEqual(out[480], 1, accuracy: 0.05, "10 ms later, across block boundaries")
        XCTAssertEqual(tree.parameter(withAddress: 2)?.value, 1, "the tree reads what the kernel holds")
    }

    private func stereo(_ rate: Double) throws -> AVAudioFormat {
        try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2))
    }

    /// The delay at a host's rate: 10 ms is 441 frames at 44.1 kHz and 480 at 48 kHz, and the
    /// values in its tree survive resources made again at another rate.
    func testTheDelayPlaysAtTheHostsRateAndKeepsItsValuesAcrossARateChange() throws {
        let delay = try StandardEffectUnit(componentDescription: StandardEffectUnit.audioComponent(StandardEffect.delay.component))
        try delay.inputBusses[0].setFormat(try stereo(44_100))
        try delay.outputBusses[0].setFormat(try stereo(44_100))
        try delay.allocateRenderResources()
        let tree = try XCTUnwrap(delay.parameterTree)
        tree.parameter(withAddress: 0)?.value = 0.01 // time
        tree.parameter(withAddress: 1)?.value = 0 // feedback
        tree.parameter(withAddress: 2)?.value = 1 // mix
        var impulse = [Float](repeating: 0, count: 2_000)
        impulse[0] = 1
        let slow = render(delay, impulse)
        XCTAssertEqual(slow[441], 1, accuracy: 0.05, "10 ms at 44.1 kHz")
        XCTAssertEqual(slow[480], 0, accuracy: 0.05, "not at the 48 kHz frame")

        delay.deallocateRenderResources()
        try delay.inputBusses[0].setFormat(try stereo(48_000))
        try delay.outputBusses[0].setFormat(try stereo(48_000))
        try delay.allocateRenderResources()
        let time = try XCTUnwrap(tree.parameter(withAddress: 0)?.value)
        XCTAssertEqual(time, 0.01, accuracy: 1e-6, "the time survives the new rate")
        XCTAssertEqual(tree.parameter(withAddress: 2)?.value, 1, "and the mix")
        let fast = render(delay, impulse)
        XCTAssertEqual(fast[480], 1, accuracy: 0.05, "10 ms at 48 kHz")
        XCTAssertEqual(fast[441], 0, accuracy: 0.05, "not at the 44.1 kHz frame")
    }

    /// Input and output at different rates are refused with the format error, not played at the
    /// wrong pitch; the same unit allocates once both sides agree.
    func testDifferentInputAndOutputRatesAreRefused() throws {
        let equalizer = try StandardEffectUnit(componentDescription: StandardEffectUnit.audioComponent(StandardEffect.equalizer.component))
        try equalizer.inputBusses[0].setFormat(try stereo(44_100))
        try equalizer.outputBusses[0].setFormat(try stereo(48_000))
        XCTAssertThrowsError(try equalizer.allocateRenderResources()) { error in
            let failure = error as NSError
            XCTAssertEqual(failure.domain, NSOSStatusErrorDomain)
            XCTAssertEqual(failure.code, Int(kAudioUnitErr_FormatNotSupported))
        }
        try equalizer.outputBusses[0].setFormat(try stereo(44_100))
        XCTAssertNoThrow(try equalizer.allocateRenderResources(), "one rate on both sides")
    }

    /// A host's reset empties the tail: an impulse that would repeat 10 ms later is gone once the
    /// host resets the unit, while a unit that is not reset still plays the repeat.
    func testAResetEmptiesTheDelaysTail() throws {
        func primed() throws -> StandardEffectUnit {
            let delay = try unit(.delay)
            let tree = try XCTUnwrap(delay.parameterTree)
            tree.parameter(withAddress: 0)?.value = 0.01 // time: 480 frames
            tree.parameter(withAddress: 1)?.value = 0 // feedback
            tree.parameter(withAddress: 2)?.value = 1 // mix
            var impulse = [Float](repeating: 0, count: 256)
            impulse[0] = 1
            _ = render(delay, impulse)
            return delay
        }
        let silence = [Float](repeating: 0, count: 512)
        let kept = render(try primed(), silence)
        XCTAssertEqual(kept[480 - 256], 1, accuracy: 0.05, "without a reset the repeat is still in the line")
        let cleared = try primed()
        cleared.reset()
        let out = render(cleared, silence)
        XCTAssertEqual(out.map { abs($0) }.max() ?? 1, 0, accuracy: 1e-6, "after a reset: silence")
        XCTAssertEqual(cleared.parameterTree?.parameter(withAddress: 2)?.value, 1, "the parameters stay")
    }

    /// A host's bypass passes the input through untouched, and the effect plays again when the
    /// host switches it back on (review 2026-10-23: GarageBand's switch did nothing before).
    func testTheHostsBypassPassesTheInputThrough() throws {
        let delay = try unit(.delay)
        let tree = try XCTUnwrap(delay.parameterTree)
        tree.parameter(withAddress: 0)?.value = 0.01 // time
        tree.parameter(withAddress: 1)?.value = 0 // feedback
        tree.parameter(withAddress: 2)?.value = 1 // mix
        var impulse = [Float](repeating: 0, count: 2_000)
        impulse[0] = 1
        delay.shouldBypassEffect = true
        XCTAssertTrue(delay.shouldBypassEffect)
        let passed = render(delay, impulse)
        XCTAssertEqual(passed, impulse, "bypassed: the input, sample for sample")
        delay.shouldBypassEffect = false
        let played = render(delay, impulse)
        XCTAssertEqual(played[0], 0, accuracy: 1e-6, "on again: fully wet")
        XCTAssertEqual(played[480], 1, accuracy: 0.05, "and the repeat is back")
    }

    /// A bypassed unit keeps the latency it reports: the dry impulse emerges exactly that many
    /// frames late, so a host that compensates the latency (Logic, AUM) keeps the bypassed track in
    /// time. An effect without latency passes at 0.
    func testABypassedImpulseEmergesAtTheReportedLatency() throws {
        for effect in [StandardEffect.pitchCorrection, .multibandClipper, .equalizer] {
            let u = try unit(effect)
            let lag = Int((u.latency * 48_000).rounded())
            u.shouldBypassEffect = true
            var impulse = [Float](repeating: 0, count: 2_000)
            impulse[0] = 1
            let out = render(u, impulse)
            var expected = [Float](repeating: 0, count: 2_000)
            expected[lag] = 1
            XCTAssertEqual(out, expected, "\(effect): the input, \(lag) frames late")
            XCTAssertEqual(u.latency, Double(lag) / 48_000, accuracy: 1.0 / 48_000, "\(effect): bypass does not change the latency")
        }
        XCTAssertEqual(Int((try unit(.pitchCorrection).latency * 48_000).rounded()), 912)
        XCTAssertEqual(Int((try unit(.multibandClipper).latency * 48_000).rounded()), 85)
    }

    /// The dry line hears the input while the effect plays, so a bypass switched on after an
    /// impulse still plays it at the latency, not late by the time it was on.
    func testSwitchingToBypassKeepsTheDrySoundInTime() throws {
        let clipper = try unit(.multibandClipper)
        var impulse = [Float](repeating: 0, count: 64)
        impulse[0] = 1
        _ = render(clipper, impulse)
        clipper.shouldBypassEffect = true
        let out = render(clipper, [Float](repeating: 0, count: 512))
        XCTAssertEqual(out[85 - 64], 1, "the impulse 85 frames after it arrived")
        let others = out.enumerated().filter { $0.offset != 85 - 64 }.map { abs($0.element) }
        XCTAssertEqual(others.max() ?? 1, 0, "and nothing else of the dry sound")
    }

    /// An upstream that reports silence does not silence a tail: once the unit has processed, the
    /// hint is gone, so a host does not skip the delay's or reverb's ring-out (review 2026-10-23).
    func testATailIsNotReportedAsSilence() throws {
        let delay = try unit(.delay)
        let tree = try XCTUnwrap(delay.parameterTree)
        tree.parameter(withAddress: 0)?.value = 0.01 // time: 480 frames
        tree.parameter(withAddress: 1)?.value = 0 // feedback
        tree.parameter(withAddress: 2)?.value = 1 // mix
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256),
              let channels = buffer.floatChannelData else {
            return XCTFail("no stereo buffer")
        }
        buffer.frameLength = 256
        var stamp = AudioTimeStamp()
        stamp.mFlags = .sampleTimeValid
        var flags = AudioUnitRenderActionFlags()
        let block = delay.internalRenderBlock
        let impulse: AURenderPullInputBlock = { _, _, frames, _, list in
            for channel in UnsafeMutableAudioBufferListPointer(list) {
                guard let data = channel.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for index in 0..<Int(frames) { data[index] = index == 0 ? 1 : 0 }
            }
            return noErr
        }
        let silence: AURenderPullInputBlock = { actionFlags, _, frames, _, list in
            actionFlags.pointee.insert(.unitRenderAction_OutputIsSilence)
            for channel in UnsafeMutableAudioBufferListPointer(list) {
                guard let data = channel.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for index in 0..<Int(frames) { data[index] = 0 }
            }
            return noErr
        }
        XCTAssertEqual(block(&flags, &stamp, 256, 0, buffer.mutableAudioBufferList, nil, impulse), noErr)
        stamp.mSampleTime += 256
        flags = AudioUnitRenderActionFlags()
        XCTAssertEqual(block(&flags, &stamp, 256, 0, buffer.mutableAudioBufferList, nil, silence), noErr)
        XCTAssertFalse(flags.contains(.unitRenderAction_OutputIsSilence), "the unit processed: no silence hint")
        XCTAssertEqual(channels[0][480 - 256], 1, accuracy: 0.05, "the repeat rings out of a silent input")
    }

    /// A host that asks for more frames than the unit allocated gets the documented refusal,
    /// not a write past the buffers (B7). The allocated count itself still plays.
    func testARenderCallAskingForMoreFramesThanAllocatedIsRefused() throws {
        let equalizer = try unit(.equalizer)
        let allocated = equalizer.maximumFramesToRender
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: allocated * 2) else {
            return XCTFail("no stereo buffer")
        }
        buffer.frameLength = allocated * 2
        var stamp = AudioTimeStamp()
        stamp.mFlags = .sampleTimeValid
        var flags = AudioUnitRenderActionFlags()
        let pull: AURenderPullInputBlock = { _, _, _, _, _ in noErr }
        let block = equalizer.internalRenderBlock
        let refused = block(&flags, &stamp, allocated + 1, 0, buffer.mutableAudioBufferList, nil, pull)
        XCTAssertEqual(refused, kAudioUnitErr_TooManyFramesToProcess, "one frame more than allocated")
        let played = block(&flags, &stamp, allocated, 0, buffer.mutableAudioBufferList, nil, pull)
        XCTAssertEqual(played, noErr, "exactly the allocated frames still render")
    }

    /// A host owes its numbers no meaning: a timestamp's flags may say its sample time is not
    /// valid, and an event's time and address are the host's. None of them may stop the process
    /// the unit runs in — in another app's host that is every Echoelmusic unit of the session at
    /// once. The call plays, and an address no parameter has changes nothing.
    func testARenderCallWithNumbersThatAreNoTimeStillPlays() throws {
        let equalizer = try unit(.equalizer)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256) else {
            return XCTFail("no stereo buffer")
        }
        buffer.frameLength = 256
        let before = equalizer.parameterTree?.allParameters.map(\.value)
        let pull: AURenderPullInputBlock = { _, _, _, _, _ in noErr }
        let block = equalizer.internalRenderBlock
        var stray = AUParameterEvent()
        stray.eventSampleTime = .min
        stray.eventType = .parameter
        stray.parameterAddress = .max
        stray.value = 1
        var event = AURenderEvent()
        event.parameter = stray
        let times: [Double] = [.nan, .infinity, -.infinity, 1e300, -1e300, 4_096, 0]
        for time in times {
            var stamp = AudioTimeStamp()
            stamp.mSampleTime = time
            var flags = AudioUnitRenderActionFlags()
            let played = withUnsafePointer(to: event) { list in
                block(&flags, &stamp, 256, 0, buffer.mutableAudioBufferList, list, pull)
            }
            XCTAssertEqual(played, noErr, "sample time \(time)")
        }
        XCTAssertEqual(equalizer.parameterTree?.allParameters.map(\.value), before, "no parameter moved")
    }

    func testARegisteredEffectLoadsLikeAnyAudioUnit() throws {
        StandardEffectUnit.register()
        let loaded = expectation(description: "instantiated")
        nonisolated(unsafe) var found: AUAudioUnit?
        AUAudioUnit.instantiate(with: StandardEffectUnit.audioComponent(StandardEffect.reverb.component), options: []) { unit, _ in
            found = unit
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 10)
        XCTAssertTrue(found is StandardEffectUnit)
    }

    /// A host reads the tail from the unit: the reverb's grows with its decay as the tree sets it,
    /// an EQ has none.
    func testTheUnitReportsItsKernelsTail() throws {
        let reverb = try unit(.reverb)
        let before = reverb.tailTime
        XCTAssertGreaterThan(before, 0)
        reverb.parameterTree?.parameter(withAddress: 1)?.value = 12 // decay
        XCTAssertGreaterThan(reverb.tailTime, before)
        XCTAssertEqual(try unit(.equalizer).tailTime, 0)
    }

    /// The tree tells a host `.flag_CanRamp` exactly where the kernel runs a ramp, and never on an
    /// indexed choice or a switch.
    func testTheTreeSaysCanRampExactlyWhereTheKernelRamps() throws {
        for effect in StandardEffect.allCases {
            let tree = try XCTUnwrap(try unit(effect).parameterTree)
            for node in tree.allParameters {
                let label = "\(effect) \(node.identifier)"
                XCTAssertEqual(node.flags.contains(.flag_CanRamp), EffectKernel.canRamp(effect, Int(node.address)), label)
                if node.unit == .indexed || node.unit == .boolean {
                    XCTAssertFalse(node.flags.contains(.flag_CanRamp), "\(label) never ramps")
                }
            }
        }
        let reverb = try XCTUnwrap(try unit(.reverb).parameterTree)
        XCTAssertTrue(reverb.parameter(withAddress: 1)?.flags.contains(.flag_CanRamp) ?? false, "the decay ramps")
    }

    /// A host's scheduled ramp moves the value over the ramp's length: the width, ramped from 1.4 to
    /// 0 over 8,192 frames, is about half way after 4,096 — a ramp taken as its end value would have
    /// narrowed a pure side signal to silence within a few milliseconds.
    func testAScheduledRampMovesTheValueOverItsLength() throws {
        let width = try unit(.stereoWidth)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_096),
              let channels = buffer.floatChannelData else {
            return XCTFail("no stereo buffer")
        }
        let side: AURenderPullInputBlock = { _, _, frames, _, list in
            for (index, channel) in UnsafeMutableAudioBufferListPointer(list).enumerated() {
                guard let data = channel.mData?.assumingMemoryBound(to: Float.self) else { continue }
                for frame in 0..<Int(frames) { data[frame] = index == 0 ? 0.5 : -0.5 }
            }
            return noErr
        }
        let block = width.internalRenderBlock
        var stamp = AudioTimeStamp()
        stamp.mFlags = .sampleTimeValid
        var flags = AudioUnitRenderActionFlags()
        buffer.frameLength = 256
        XCTAssertEqual(block(&flags, &stamp, 256, 0, buffer.mutableAudioBufferList, nil, side), noErr)
        XCTAssertEqual(channels[0][255], 0.7, accuracy: 0.01, "width 1.4 on a side of 0.5")

        stamp.mSampleTime += 256
        var ramp = AUParameterEvent()
        ramp.eventSampleTime = AUEventSampleTime(stamp.mSampleTime)
        ramp.eventType = .parameterRamp
        ramp.rampDurationSampleFrames = 8_192
        ramp.parameterAddress = 0
        ramp.value = 0
        var event = AURenderEvent()
        event.parameter = ramp
        buffer.frameLength = 4_096
        flags = AudioUnitRenderActionFlags()
        let played = withUnsafePointer(to: event) { list in
            block(&flags, &stamp, 4_096, 0, buffer.mutableAudioBufferList, list, side)
        }
        XCTAssertEqual(played, noErr)
        XCTAssertGreaterThan(channels[0][1_024], channels[0][3_072], "it narrows as it goes")
        XCTAssertGreaterThan(channels[0][4_095], 0.3, "half way, not at the end")
        XCTAssertLessThan(channels[0][4_095], 0.45)

        stamp.mSampleTime += 4_096
        flags = AudioUnitRenderActionFlags()
        XCTAssertEqual(block(&flags, &stamp, 4_096, 0, buffer.mutableAudioBufferList, nil, side), noErr)
        stamp.mSampleTime += 4_096
        flags = AudioUnitRenderActionFlags()
        XCTAssertEqual(block(&flags, &stamp, 4_096, 0, buffer.mutableAudioBufferList, nil, side), noErr)
        XCTAssertLessThan(channels[0][4_095], 0.01, "the ramp has arrived")
    }
}
