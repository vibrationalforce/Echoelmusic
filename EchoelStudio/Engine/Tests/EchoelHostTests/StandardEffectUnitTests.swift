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
}
