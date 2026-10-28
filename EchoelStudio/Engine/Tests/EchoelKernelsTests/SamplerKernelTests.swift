import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelKernels

final class SamplerKernelTests: XCTestCase {
    private func render(_ kernel: SamplerKernel, frames: Int, gain: Float = 1) -> [Float] {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                kernel.render(frames: frames, left: lp, right: rp, gain: gain)
            }
        }
        return left
    }

    private func peak(_ samples: [Float]) -> Float { samples.map { abs($0) }.max() ?? 0 }

    /// A parameter's address, found by the identifier hosts store — never a bare index.
    private func address(_ identifier: String) throws -> Int {
        try XCTUnwrap(SamplerKernel.parameters.firstIndex { $0.identifier == identifier }, identifier)
    }

    /// One second of a constant level, so what a voice plays is easy to read.
    private func constant(_ value: Float, seconds: Double = 1) -> SampleBuffer? {
        SampleBuffer(samples: [Float](repeating: value, count: Int(48_000 * seconds)), sampleRate: 48_000)
    }

    func testWithoutASampleANoteIsSilentAndALoadedSamplePlays() throws {
        let kernel = SamplerKernel(sampleRate: 48_000)
        kernel.receive(status: 0x90, 60, 127)
        XCTAssertEqual(peak(render(kernel, frames: 960)), 0)
        XCTAssertTrue(kernel.load(try XCTUnwrap(constant(0.5))))
        _ = render(kernel, frames: 16) // a render takes the sample first, as in a host
        kernel.receive(status: 0x90, 60, 127)
        XCTAssertGreaterThan(peak(render(kernel, frames: 960)), 0.3)
        kernel.load(nil)
        XCTAssertEqual(peak(render(kernel, frames: 960)), 0, "taking the sample away stops every voice")
    }

    func testTheRootKeyDecidesWhichNotePlaysTheSampleAtItsOwnSpeed() throws {
        // A sample one second long: at its own speed it lasts a second, an octave up half that.
        let kernel = SamplerKernel(sampleRate: 48_000)
        kernel.load(try XCTUnwrap(constant(0.5)))
        kernel.setParameter(try address("sampler_mode"), 1) // one-shot: plays to the end
        kernel.setParameter(try address("sampler_root"), 48)
        _ = render(kernel, frames: 16) // parameters apply at the top of a render, as in a host
        kernel.receive(status: 0x90, 60, 127) // an octave above the root
        _ = render(kernel, frames: 26_400)
        XCTAssertEqual(peak(render(kernel, frames: 480)), 0, "an octave up the second lasts half")
        kernel.setParameter(try address("sampler_root"), 60)
        _ = render(kernel, frames: 16)
        kernel.receive(status: 0x90, 60, 127)
        _ = render(kernel, frames: 26_400)
        XCTAssertGreaterThan(peak(render(kernel, frames: 480)), 0.3, "at the root it plays on")
    }

    /// A host sends a change and a note at the same offset, before any render: the note hears
    /// the root key and the sample that came with it (audit 2026-10-23).
    func testAChangeThatArrivesWithANoteIsHeardByIt() throws {
        let kernel = SamplerKernel(sampleRate: 48_000)
        kernel.load(try XCTUnwrap(constant(0.5)))
        kernel.setParameter(try address("sampler_mode"), 1) // one-shot: plays to the end
        _ = render(kernel, frames: 16)
        kernel.setParameter(try address("sampler_root"), 48)
        kernel.receive(status: 0x90, 60, 127) // no render in between
        _ = render(kernel, frames: 26_400)
        XCTAssertEqual(peak(render(kernel, frames: 480)), 0, "an octave above the new root, the second lasts half")

        let fresh = SamplerKernel(sampleRate: 48_000)
        fresh.load(try XCTUnwrap(constant(0.5)))
        fresh.receive(status: 0x90, 60, 127)
        XCTAssertGreaterThan(peak(render(fresh, frames: 960)), 0.3, "the note plays the sample loaded just before it")
    }

    func testANoteOffFindsItsNoteAfterTheRootKeyMoved() throws {
        let kernel = SamplerKernel(sampleRate: 48_000)
        kernel.load(try XCTUnwrap(constant(0.5, seconds: 4)))
        kernel.setParameter(try address("sampler_release"), 0.01) // short release
        _ = render(kernel, frames: 16)
        kernel.receive(status: 0x90, 64, 127)
        _ = render(kernel, frames: 480)
        kernel.setParameter(try address("sampler_root"), 55)
        _ = render(kernel, frames: 480)
        kernel.receive(status: 0x80, 64, 0)
        _ = render(kernel, frames: 4_800)
        XCTAssertEqual(peak(render(kernel, frames: 480)), 0, "released, not stuck")
    }

    func testParametersAreClampedAndLoadsPastAStalledRenderAreRefused() throws {
        let kernel = SamplerKernel(sampleRate: 48_000)
        let level = try address("sampler_level")
        kernel.setParameter(level, 7)
        XCTAssertEqual(kernel.parameter(level), 1)
        kernel.setParameter(level, .infinity)
        XCTAssertEqual(kernel.parameter(level), 1)
        let buffer = try XCTUnwrap(constant(0.1, seconds: 0.01))
        for _ in 0..<63 { XCTAssertTrue(kernel.load(buffer)) }
        XCTAssertFalse(kernel.load(buffer), "the render thread has not taken one of them")
        _ = render(kernel, frames: 16)
        XCTAssertTrue(kernel.load(buffer), "once it has, the ring is free again")
    }

    // MARK: Held keys (Codex handover S3)

    /// A kernel with a long constant sample and a short release, rendered once so both apply.
    private func heldKernel() throws -> SamplerKernel {
        let kernel = SamplerKernel(sampleRate: 48_000)
        kernel.load(try XCTUnwrap(constant(0.5, seconds: 4)))
        kernel.setParameter(try address("sampler_release"), 0.01)
        _ = render(kernel, frames: 16)
        return kernel
    }

    /// Key on, root moved, the same key on again, key off: nothing is left sounding. The first
    /// voice sounded at the old pitch, so a note-off by the new pitch alone missed it.
    func testARepeatedKeyAfterTheRootMovedLeavesNoVoiceBehind() throws {
        let kernel = try heldKernel()
        kernel.receive(status: 0x90, 64, 127)
        _ = render(kernel, frames: 480)
        kernel.setParameter(try address("sampler_root"), 55)
        _ = render(kernel, frames: 480)
        kernel.receive(status: 0x90, 64, 127)
        _ = render(kernel, frames: 480)
        kernel.receive(status: 0x80, 64, 0)
        _ = render(kernel, frames: 4_800)
        XCTAssertFalse(kernel.isSounding, "both voices of the key have ended")
        XCTAssertEqual(peak(render(kernel, frames: 480)), 0)
    }

    /// Two keys clamped onto one pitch at the bottom of the range: each key ends only its own
    /// voice. At the bottom, not the top: clamped to 127 a key plays the sample about 48 times
    /// faster, and the four seconds end on their own before the check.
    func testTwoKeysOnOnePitchEndOnlyTheirOwnVoice() throws {
        let kernel = try heldKernel()
        kernel.setParameter(try address("sampler_root"), 107) // −47: keys 0 … 47 all land on 0
        _ = render(kernel, frames: 16)
        kernel.receive(status: 0x90, 10, 127)
        kernel.receive(status: 0x90, 20, 127)
        _ = render(kernel, frames: 480)
        kernel.receive(status: 0x80, 10, 0)
        _ = render(kernel, frames: 4_800)
        XCTAssertTrue(kernel.isSounding, "key 20 still holds its voice")
        kernel.receive(status: 0x80, 20, 0)
        _ = render(kernel, frames: 4_800)
        XCTAssertFalse(kernel.isSounding)
    }

    /// The same key on two channels is two keys: a note-off on one channel leaves the other held.
    /// A note-off for a key that never sounded ends nothing.
    func testTheSameKeyOnTwoChannelsIsTwoKeys() throws {
        let kernel = try heldKernel()
        kernel.receive(status: 0x90, 60, 127)
        kernel.receive(status: 0x91, 60, 127)
        _ = render(kernel, frames: 480)
        kernel.receive(status: 0x80, 60, 0)
        kernel.receive(status: 0x82, 61, 0)
        _ = render(kernel, frames: 4_800)
        XCTAssertTrue(kernel.isSounding, "channel 2's key is still held")
        kernel.receive(status: 0x91, 60, 0) // note-on with velocity 0 is a note-off
        _ = render(kernel, frames: 4_800)
        XCTAssertFalse(kernel.isSounding)
    }

    /// All sound off, all notes off and a new sample each end every held key, and the next
    /// note-off of an old key ends nothing that started after.
    func testResetNotesOffAndANewSampleLeaveNoStaleKey() throws {
        let kernel = try heldKernel()
        kernel.receive(status: 0x90, 60, 127)
        kernel.receive(status: 0xB0, 120, 0)
        XCTAssertFalse(kernel.isSounding, "CC 120 silences at once")
        kernel.receive(status: 0x90, 62, 127)
        kernel.receive(status: 0xB0, 123, 0)
        _ = render(kernel, frames: 4_800)
        XCTAssertFalse(kernel.isSounding, "CC 123 releases every held key")
        kernel.receive(status: 0x90, 64, 127)
        kernel.load(try XCTUnwrap(constant(0.5, seconds: 4)))
        _ = render(kernel, frames: 16)
        XCTAssertFalse(kernel.isSounding, "a new sample stops the voice")
        kernel.receive(status: 0x90, 65, 127)
        kernel.receive(status: 0x80, 64, 0) // the old key's off must not end key 65
        _ = render(kernel, frames: 4_800)
        XCTAssertTrue(kernel.isSounding)
        XCTAssertTrue(render(kernel, frames: 480).allSatisfy(\.isFinite))
    }
}

