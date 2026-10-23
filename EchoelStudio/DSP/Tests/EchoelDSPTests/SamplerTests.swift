import Foundation
import XCTest
@testable import EchoelDSP

final class SamplerTests: XCTestCase {
    private let rate: Float = 48_000

    private func render(_ sampler: inout Sampler, frames: Int) -> [Float] {
        var buffer = [Float](repeating: 0, count: frames)
        var start = 0
        while start < frames {
            let end = Swift.min(start + 256, frames)
            buffer[start..<end].withUnsafeMutableBufferPointer { sampler.render(into: $0) }
            start = end
        }
        return buffer
    }

    /// A ramp 0, 1, 2 … so the read position can be read straight off the output.
    private func ramp(_ count: Int, root: UInt8 = 60) -> SampleBuffer? {
        SampleBuffer(samples: (0..<count).map { Float($0) / Float(count) }, sampleRate: Double(rate), rootPitch: root)
    }

    private func flat() -> SamplerPatch {
        SamplerPatch(envelope: .init(attack: 0.0001, decay: 0.0001, sustain: 1, release: 0.0001), oneShot: true, level: 1)
    }

    func testABadSampleIsRefused() {
        XCTAssertNil(SampleBuffer(samples: [], sampleRate: 48_000))
        XCTAssertNil(SampleBuffer(samples: [1], sampleRate: .nan))
        XCTAssertNil(try SampleBuffer(capacity: 0, sampleRate: 48_000) { _ in 0 })
        XCTAssertNil(try SampleBuffer(capacity: 4, sampleRate: 48_000) { _ in 0 }, "nothing written, no sample")
        XCTAssertNil(SampleBuffer(samples: [1], sampleRate: 0))
        let cleaned = SampleBuffer(samples: [.nan, .infinity, 0.5], sampleRate: 48_000)
        XCTAssertEqual(cleaned.map { [$0.frames[0], $0.frames[1], $0.frames[2]] }, [0, 0, 0.5])
    }

    /// Decoding writes straight into the sample's own memory, so a file is held once, not twice.
    func testAFillWritesTheSampleInPlace() throws {
        let buffer = try XCTUnwrap(try SampleBuffer(capacity: 4, sampleRate: 44_100) { frames in
            frames[0] = 0.25
            frames[1] = .nan
            frames[2] = -0.5
            return 3
        })
        XCTAssertEqual(buffer.frameCount, 3, "the frames it wrote, not the room it had")
        XCTAssertEqual(buffer.heldFrames, 4, "three of four keep their block, and the block is counted")
        XCTAssertEqual(buffer.copyFrames(), [0.25, 0, -0.5], "a non-finite frame is silence")
        let inPlace: [Float] = buffer.withFrames { (frames: UnsafeBufferPointer<Float>) -> [Float] in Array(frames) }
        XCTAssertEqual(inPlace, [0.25, 0, -0.5], "read in place, the same frames")
        XCTAssertEqual(buffer.sampleRate, 44_100)
        let clamped = try XCTUnwrap(try SampleBuffer(capacity: 2, sampleRate: 48_000) { _ in 10 })
        XCTAssertEqual(clamped.frameCount, 2, "never more than it holds")
        struct Broken: Error {}
        XCTAssertThrowsError(try SampleBuffer(capacity: 2, sampleRate: 48_000) { _ in throw Broken() }) {
            XCTAssertTrue($0 is Broken)
        }
        // A size no memory can hold is said as such, not as a file without audio.
        XCTAssertThrowsError(try SampleBuffer(capacity: Int.max / 2, sampleRate: 48_000) { _ in 1 }) {
            XCTAssertTrue($0 is SampleBuffer.OutOfMemory)
        }
    }

    /// A file whose header promises far more frames than it holds gives the unwritten room back:
    /// the buffer holds what it wrote, and says so.
    func testAShortFillKeepsOnlyTheMemoryItWrote() throws {
        let capacity = 1_000_000
        let buffer = try XCTUnwrap(try SampleBuffer(capacity: capacity, sampleRate: 48_000) { (frames: UnsafeMutableBufferPointer<Float>) -> Int in
            for index in 0..<1_000 { frames[index] = Float(index) / 1_000 }
            return 1_000
        })
        XCTAssertEqual(buffer.frameCount, 1_000)
        XCTAssertEqual(buffer.heldFrames, 1_000)
        let kept: [Float] = buffer.copyFrames()
        XCTAssertEqual(kept.first, 0)
        XCTAssertEqual(kept.last, 0.999)
        #if canImport(Darwin)
        let held = malloc_size(buffer.frames)
        XCTAssertGreaterThanOrEqual(held, 1_000 * MemoryLayout<Float>.size)
        XCTAssertLessThan(held, capacity * MemoryLayout<Float>.size / 100, "the unwritten room is given back")
        #endif
    }

    /// A file one frame short keeps its block, and counts it: moving almost all of it into a new
    /// block would cost more at its peak than it gives back.
    func testAFillShortByAFrameKeepsItsBlockAndCountsIt() throws {
        let capacity = 1_600
        let buffer = try XCTUnwrap(try SampleBuffer(capacity: capacity, sampleRate: 48_000) { (frames: UnsafeMutableBufferPointer<Float>) -> Int in
            for index in 0..<(capacity - 1) { frames[index] = Float(index) / Float(capacity) }
            return capacity - 1
        })
        XCTAssertEqual(buffer.frameCount, capacity - 1, "it plays what it wrote")
        XCTAssertEqual(buffer.heldFrames, capacity, "and holds, and is counted for, its whole block")
        let kept: [Float] = buffer.copyFrames()
        XCTAssertEqual(kept.count, capacity - 1)
        XCTAssertEqual(kept.first, 0)
        XCTAssertEqual(kept.last, Float(capacity - 2) / Float(capacity))
    }

    /// A file just under half as long as its header promised: Darwin's `realloc` rounds both sizes
    /// and keeps a block that would shrink by less than half of its rounded size, so a shrink in
    /// place stayed whole here while the count said half (seventh night review, 2026-10-23). The
    /// frames move into a block of their own size, and the block held is the one counted.
    func testAFillJustUnderHalfHoldsTheBlockItCounts() throws {
        let capacity = 1_000_000
        let written = capacity / 2 - 100
        let buffer = try XCTUnwrap(try SampleBuffer(capacity: capacity, sampleRate: 48_000) { (frames: UnsafeMutableBufferPointer<Float>) -> Int in
            for index in 0..<written { frames[index] = 0.25 }
            return written
        })
        XCTAssertEqual(buffer.frameCount, written)
        XCTAssertEqual(buffer.heldFrames, written, "it holds what it plays")
        let kept: [Float] = buffer.copyFrames()
        XCTAssertEqual(kept.count, written)
        XCTAssertEqual(kept.last, 0.25, "the frames survive the move")
        #if canImport(Darwin)
        XCTAssertLessThan(malloc_size(buffer.frames), capacity * MemoryLayout<Float>.size * 3 / 4,
                          "the block the allocator holds is about the counted half, not the whole")
        #endif
    }

    /// A file a quarter as long as its header promised gives the rest back: the block the
    /// allocator holds is smaller than the one it was given, and the buffer counts what it plays.
    func testAFillOfAQuarterGivesTheRestBack() throws {
        let capacity = 1_000_000
        let buffer = try XCTUnwrap(try SampleBuffer(capacity: capacity, sampleRate: 48_000) { (frames: UnsafeMutableBufferPointer<Float>) -> Int in
            for index in 0..<(capacity / 4) { frames[index] = 0.5 }
            return capacity / 4
        })
        XCTAssertEqual(buffer.frameCount, capacity / 4)
        XCTAssertEqual(buffer.heldFrames, capacity / 4)
        XCTAssertEqual(buffer.copyFrames().last, 0.5, "the frames survive the move")
        #if canImport(Darwin)
        XCTAssertLessThan(malloc_size(buffer.frames), capacity * MemoryLayout<Float>.size, "the room went back")
        #endif
    }

    func testWithoutASampleNothingSounds() {
        var sampler = Sampler(sampleRate: rate)
        sampler.noteOn(pitch: 60, velocity: 127)
        XCTAssertEqual(sampler.activeVoiceCount, 0)
        XCTAssertTrue(render(&sampler, frames: 256).allSatisfy { $0 == 0 })
    }

    func testTheRootNotePlaysAtOriginalSpeedAndStopsAtTheEnd() throws {
        let buffer = try XCTUnwrap(ramp(1_000))
        var sampler = Sampler(patch: flat(), sampleRate: rate)
        sampler.setSample(buffer)
        sampler.noteOn(pitch: 60, velocity: 127)
        let out = render(&sampler, frames: 2_000)
        // After the attack, output tracks the ramp sample for sample.
        XCTAssertEqual(out[500], 0.5, accuracy: 0.01)
        XCTAssertEqual(out[1_500], 0, "the voice stops when the sample ends")
        XCTAssertEqual(sampler.activeVoiceCount, 0)
    }

    /// A sample that ends mid-waveform fades out over its last frames instead of falling to 0 in
    /// one sample (audit 2026-10-23).
    func testAVoiceThatReachesTheSampleEndFadesInsteadOfClicking() throws {
        var sampler = Sampler(patch: flat(), sampleRate: rate)
        sampler.setSample(try XCTUnwrap(SampleBuffer(samples: Array(repeating: 0.5, count: 1_000), sampleRate: Double(rate))))
        sampler.noteOn(pitch: 60, velocity: 127)
        let out = render(&sampler, frames: 2_000)
        XCTAssertEqual(out[900], 0.5, accuracy: 0.01, "full level before the end")
        let tail = Array(out[900...])
        let steepest: Float = zip(tail.dropFirst(), tail).map { (pair: (Float, Float)) -> Float in abs(pair.0 - pair.1) }.max() ?? 1
        XCTAssertLessThan(steepest, 0.01, "no step at the end")
        XCTAssertEqual(out[1_500], 0, "and the voice stops")
    }

    func testAnOctaveUpPlaysTwiceAsFast() throws {
        let buffer = try XCTUnwrap(ramp(1_000))
        var sampler = Sampler(patch: flat(), sampleRate: rate)
        sampler.setSample(buffer)
        sampler.noteOn(pitch: 72, velocity: 127)
        let out = render(&sampler, frames: 1_000)
        XCTAssertEqual(out[250], 0.5, accuracy: 0.01)
        XCTAssertEqual(out[600], 0, "half the sample length is the whole note")
    }

    func testAGatedNoteReleasesAndAOneShotDoesNot() throws {
        let buffer = try XCTUnwrap(SampleBuffer(samples: Array(repeating: 0.5, count: 48_000), sampleRate: 48_000))
        var gated = Sampler(patch: SamplerPatch(oneShot: false), sampleRate: rate)
        var shot = Sampler(patch: SamplerPatch(oneShot: true), sampleRate: rate)
        gated.setSample(buffer)
        shot.setSample(buffer)
        gated.noteOn(pitch: 60, velocity: 100)
        shot.noteOn(pitch: 60, velocity: 100)
        _ = render(&gated, frames: 1_000)
        _ = render(&shot, frames: 1_000)
        gated.noteOff(pitch: 60)
        shot.noteOff(pitch: 60)
        _ = render(&gated, frames: 24_000)
        _ = render(&shot, frames: 24_000)
        XCTAssertEqual(gated.activeVoiceCount, 0, "released after 0.15 s")
        XCTAssertEqual(shot.activeVoiceCount, 1, "still playing its one second")
    }

    func testSwappingTheSampleStopsTheVoices() throws {
        var sampler = Sampler(sampleRate: rate)
        sampler.setSample(try XCTUnwrap(ramp(48_000)))
        sampler.noteOn(pitch: 60, velocity: 127)
        sampler.noteOn(pitch: 64, velocity: 127)
        XCTAssertEqual(sampler.activeVoiceCount, 2)
        sampler.setSample(try XCTUnwrap(ramp(48_000)))
        XCTAssertEqual(sampler.activeVoiceCount, 0)
    }

    func testVoicesAreStolenOldestFirstAndOutputStaysFinite() throws {
        var sampler = Sampler(voiceCount: 2, sampleRate: rate)
        sampler.setSample(try XCTUnwrap(ramp(48_000)))
        for pitch: UInt8 in [0, 60, 127] { sampler.noteOn(pitch: pitch, velocity: 127) }
        XCTAssertEqual(sampler.activeVoiceCount, 2)
        XCTAssertTrue(render(&sampler, frames: 4_800).allSatisfy(\.isFinite))
    }

    /// A stolen voice fades out what it played before the new note starts (ultra-audit A9): its
    /// read position jumps, so cutting it stepped the waveform. A constant sample makes any step
    /// visible: held at 0.5, a cut fell to the new note's attack at once. The new note waits
    /// for the fade, so the two never add up to more than one voice.
    func testAStolenVoiceFadesOutInsteadOfCutting() throws {
        var sampler = Sampler(patch: SamplerPatch(envelope: .init(attack: 0.01, decay: 0.0001, sustain: 1, release: 0.0001),
                                                  oneShot: true, level: 1),
                              voiceCount: 1, sampleRate: rate)
        sampler.setSample(try XCTUnwrap(SampleBuffer(samples: Array(repeating: 0.5, count: 48_000), sampleRate: Double(rate))))
        sampler.noteOn(pitch: 60, velocity: 127)
        var out = render(&sampler, frames: 4_800)
        XCTAssertEqual(out[4_799], 0.5, accuracy: 1e-3, "held")
        sampler.noteOn(pitch: 64, velocity: 127)
        out += render(&sampler, frames: 4_800)
        let around = out[4_000...]
        let steepest = zip(around.dropFirst(), around).map { abs($0 - $1) }.max() ?? 0
        XCTAssertLessThan(steepest, 0.01, "no step where the voice was stolen")
        XCTAssertLessThanOrEqual(out.max() ?? 0, 0.5 + 1e-3, "the new note waits for the fade")
        XCTAssertEqual(out.last ?? 0, 0.5, accuracy: 1e-3, "the new note sounds")
        XCTAssertEqual(sampler.activeVoiceCount, 1)
    }

    func testAStretchReadsOnlyItsFramesAndDoesNotDependOnTheBlockSplit() throws {
        let ramp = (0..<1_000).map { Float($0) }
        let buffer = try XCTUnwrap(SampleBuffer(samples: ramp, sampleRate: 48_000))
        func read(elapsed: Int64, count: Int) -> [Float] {
            var out = [Float](repeating: 0, count: count)
            out.withUnsafeMutableBufferPointer {
                buffer.add(into: $0, elapsed: elapsed, step: 0.75, offset: 100, length: 300, fade: 0)
            }
            return out
        }
        let whole = read(elapsed: -10, count: 500)
        XCTAssertTrue(whole[..<10].allSatisfy { $0 == 0 }, "nothing before the stretch")
        XCTAssertEqual(whole[10], 100, "starts at the offset")
        XCTAssertEqual(whole[14], 103, accuracy: 1e-4, "steps at the given rate")
        XCTAssertTrue(whole[410...].allSatisfy { $0 == 0 }, "nothing after the stretch's 400 output frames")
        XCTAssertEqual(read(elapsed: -10, count: 137) + read(elapsed: 127, count: 363), whole)
    }

    /// A level moved while a note sounds glides there in about 5 ms instead of stepping, the way
    /// an automation lane moves it; at rest the voices play the level itself.
    func testAMovedLevelGlidesWhileANoteSounds() throws {
        let buffer = try XCTUnwrap(SampleBuffer(samples: Array(repeating: 0.5, count: 48_000), sampleRate: 48_000))
        var sampler = Sampler(patch: flat(), sampleRate: rate)
        sampler.setSample(buffer)
        sampler.noteOn(pitch: 60, velocity: 127)
        let held = render(&sampler, frames: 1_000)
        XCTAssertEqual(held[999], 0.5, accuracy: 1e-4, "full level at rest")
        var quiet = flat()
        quiet.level = 0
        sampler.setPatch(quiet)
        let fading = render(&sampler, frames: 4_800)
        let jumps: [Float] = zip(fading.dropFirst(), fading).map { (pair: (Float, Float)) -> Float in abs(pair.0 - pair.1) }
        XCTAssertLessThan(jumps.max() ?? 1, 0.01, "no frame steps")
        XCTAssertLessThan(abs(fading[0] - held[999]), 0.01, "the first frame continues from the held level")
        XCTAssertEqual(fading[4_799], 0, accuracy: 1e-5, "and 100 ms later it is silent")
    }

    /// A note on a silent sampler starts at the level set while it was silent.
    func testANoteOnASilentSamplerStartsAtItsLevel() throws {
        let buffer = try XCTUnwrap(SampleBuffer(samples: Array(repeating: 0.5, count: 48_000), sampleRate: 48_000))
        var sampler = Sampler(patch: flat(), sampleRate: rate)
        sampler.setSample(buffer)
        var quiet = flat()
        quiet.level = 0
        sampler.setPatch(quiet)
        sampler.noteOn(pitch: 60, velocity: 127)
        XCTAssertTrue(render(&sampler, frames: 480).allSatisfy { $0 == 0 }, "silent from the first frame")
    }
}
