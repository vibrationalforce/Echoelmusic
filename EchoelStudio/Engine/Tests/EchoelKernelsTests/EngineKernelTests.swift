import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelKernels

/// What the app's engine needs from a built-in kernel (`EngineInstrumentKernel`): activity,
/// parameters committed before the next event, all-sound-off, and a sample handed over directly.
final class EngineKernelTests: XCTestCase {
    private let rate = 48_000.0

    /// Renders `frames` in blocks of `block`, calling `before` ahead of each block; returns the left channel.
    private func render(_ kernel: any InstrumentKernel, frames: Int, block: Int = 4_096,
                        before: () -> Void = {}) -> [Float] {
        var out: [Float] = []
        var left = [Float](repeating: 0, count: block)
        var right = [Float](repeating: 0, count: block)
        var done = 0
        while done < frames {
            let n = Swift.min(block, frames - done)
            before()
            left.withUnsafeMutableBufferPointer { l in
                right.withUnsafeMutableBufferPointer { r in
                    guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                    kernel.render(frames: n, left: lp, right: rp, gain: 1)
                }
            }
            out += left[0..<n]
            done += n
        }
        return out
    }

    private func reference(frames: Int, _ fill: (UnsafeMutableBufferPointer<Float>) -> Void) -> [Float] {
        var out = [Float](repeating: 0, count: frames)
        out.withUnsafeMutableBufferPointer { fill($0) }
        return out
    }

    private func firstDifference(_ a: [Float], _ b: [Float]) -> Int? {
        guard a.count == b.count else { return 0 }
        return zip(a, b).enumerated().first { $0.element.0 != $0.element.1 }?.offset
    }

    private func peak<C: Collection>(_ samples: C) -> Float where C.Element == Float {
        samples.reduce(Float(0)) { Swift.max($0, Swift.abs($1)) }
    }

    private func sample(seconds: Double = 1) throws -> SampleBuffer {
        let count = Int(rate * seconds)
        return try XCTUnwrap(SampleBuffer(samples: [Float](repeating: 0.5, count: count), sampleRate: rate))
    }

    func testResetIsAllSoundOffOnEveryKernel() throws {
        let buffer = try sample()
        let make: [() -> any EngineInstrumentKernel] = [
            { SynthKernel(sampleRate: self.rate, maximumFrames: 4_096) },
            { DrumKernel(sampleRate: self.rate, maximumFrames: 4_096) },
            {
                let kernel = SamplerKernel(sampleRate: self.rate, maximumFrames: 4_096)
                kernel.assign(buffer)
                return kernel
            },
        ]
        for build in make {
            let byMethod = build(), byController = build()
            for kernel in [byMethod, byController] {
                kernel.receive(status: 0x90, 36, 110)
                _ = render(kernel, frames: 480)
            }
            byMethod.reset()
            byController.receive(status: 0xB0, 120, 0)
            let a = render(byMethod, frames: 960), b = render(byController, frames: 960)
            XCTAssertNil(firstDifference(a, b), "\(type(of: byMethod))")
            XCTAssertFalse(byMethod.isSounding, "\(type(of: byMethod))")
        }
    }

    func testACommittedParameterShapesANoteAtItsFirstSample() throws {
        let cutoff = try XCTUnwrap(SynthKernel.parameters.firstIndex { $0.identifier == "synth_cutoff" })
        let kernel = SynthKernel(sampleRate: rate, maximumFrames: 4_096)
        kernel.setParameter(cutoff, 2_000)
        kernel.commitParameters()
        kernel.receive(status: 0x90, 60, 100)
        let played = render(kernel, frames: 4_000)

        var settings = InstrumentSettings()
        settings.values[SynthParameter.cutoff.key.rawValue] = 2_000
        var synth = PolySynth(sampleRate: Float(rate))
        synth.setPatch(SynthPatch(settings))
        synth.noteOn(pitch: 60, velocity: 100)
        let expected = reference(frames: 4_000) { synth.render(into: $0) }

        XCTAssertNil(firstDifference(played, expected), "first differing frame")
        XCTAssertGreaterThan(peak(expected), 0.01, "the reference plays")
    }

    func testResendingEqualValuesChangesNoSample() {
        let resent = SynthKernel(sampleRate: rate, maximumFrames: 4_096)
        let left = SynthKernel(sampleRate: rate, maximumFrames: 4_096)
        for kernel in [resent, left] { kernel.receive(status: 0x90, 57, 100) }
        let count = SynthKernel.parameters.count
        let a = render(resent, frames: 4_096, block: 32) {
            for address in 0..<count { resent.setParameter(address, resent.parameter(address)) }
        }
        let b = render(left, frames: 4_096, block: 32)
        XCTAssertNil(firstDifference(a, b), "a host that re-sends its automation must not move the sound")
    }

    func testDrumsAtUnityAreTheBareKit() {
        let kernel = DrumKernel(sampleRate: rate, maximumFrames: 4_096, level: 1)
        kernel.receive(status: 0x90, 36, 100)
        kernel.receive(status: 0x90, 42, 90)
        let played = render(kernel, frames: 4_000)

        var kit = DrumKit(sampleRate: Float(rate))
        kit.noteOn(pitch: 36, velocity: 100)
        kit.noteOn(pitch: 42, velocity: 90)
        let expected = reference(frames: 4_000) { kit.render(into: $0) }

        XCTAssertNil(firstDifference(played, expected), "first differing frame")
        XCTAssertGreaterThan(peak(expected), 0.01, "the kit plays")
        XCTAssertEqual(DrumKernel(sampleRate: rate).parameter(0), 0.8, "the plugin still starts at the table's default")
    }

    func testAnAssignedSampleSoundsWithTheNextNote() throws {
        let buffer = try sample()
        let kernel = SamplerKernel(sampleRate: rate, maximumFrames: 4_096)
        kernel.assign(buffer)
        kernel.commitParameters()
        kernel.receive(status: 0x90, 64, 100)
        let played = render(kernel, frames: 4_000)

        var sampler = Sampler(sampleRate: Float(rate))
        sampler.setSample(buffer)
        sampler.setPatch(SamplerPatch())
        sampler.noteOn(pitch: 64, velocity: 100)
        let expected = reference(frames: 4_000) { sampler.render(into: $0) }

        XCTAssertNil(firstDifference(played, expected), "first differing frame")
        XCTAssertGreaterThan(peak(played.prefix(480)), 0.05, "it sounds within the first 10 ms")
    }

    func testANoteOffForAKeyThatNeverSoundedReleasesNothing() throws {
        let kernel = SamplerKernel(sampleRate: rate, maximumFrames: 4_096)
        kernel.assign(try sample())
        kernel.commitParameters()
        kernel.receive(status: 0x90, 0, 100)  // pitch 0: the one-second sample lasts 32 s down there
        kernel.receive(status: 0x80, 64, 0)   // key 64 never sounded
        let out = render(kernel, frames: 24_000)
        XCTAssertGreaterThan(peak(out.suffix(480)), 0.05, "the held note was not released by a stranger's note-off")
    }

    func testIsSoundingFollowsTheVoices() throws {
        let synth = SynthKernel(sampleRate: rate, maximumFrames: 4_096)
        XCTAssertFalse(synth.isSounding)
        synth.receive(status: 0x90, 60, 100)
        XCTAssertTrue(synth.isSounding)
        synth.receive(status: 0x80, 60, 0)
        _ = render(synth, frames: 48_000)
        XCTAssertFalse(synth.isSounding, "the release has run out")

        let drums = DrumKernel(sampleRate: rate, maximumFrames: 4_096, level: 1)
        drums.receive(status: 0x90, 38, 100)
        XCTAssertTrue(drums.isSounding)
        drums.reset()
        XCTAssertFalse(drums.isSounding)

        let sampler = SamplerKernel(sampleRate: rate, maximumFrames: 4_096)
        sampler.receive(status: 0x90, 60, 100)
        XCTAssertFalse(sampler.isSounding, "no sample, no voice")
        sampler.assign(try sample())
        sampler.receive(status: 0x90, 60, 100)
        XCTAssertTrue(sampler.isSounding)
    }
}
