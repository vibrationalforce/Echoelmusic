import Foundation
import XCTest
@testable import EchoelDSP

/// A sample in memory keeps its two sides (W17): a stereo file stays stereo, a mono one stays mono,
/// and two sides that are the same are one channel.
final class StereoSampleBufferTests: XCTestCase {
    private let rate: Float = 48_000

    /// `count` frames of `left` and `right` read by the stereo stretch, from `elapsed` on.
    private func sides(_ buffer: SampleBuffer, elapsed: Int64, count: Int, step: Double = 1, offset: Double = 0,
                       length: Double = 1_000_000, fade: Double = 0) -> (left: [Float], right: [Float]) {
        var left = [Float](repeating: 0, count: count)
        var right = [Float](repeating: 0, count: count)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                buffer.add(intoLeft: lp, right: rp, count: count, elapsed: elapsed, step: step, offset: offset,
                           length: length, fade: fade)
            }
        }
        return (left, right)
    }

    func testTwoSidesStayApartAndTheLeftNeverReachesTheRight() throws {
        let left: [Float] = (0..<1_000).map { (index: Int) -> Float in Float(index) / 1_000 }
        let right = [Float](repeating: 0, count: 1_000)
        let buffer = try XCTUnwrap(SampleBuffer(left: left, right: right, sampleRate: 48_000))
        XCTAssertEqual(buffer.channelCount, 2)
        XCTAssertEqual(buffer.frameCount, 1_000)
        XCTAssertEqual(buffer.heldBytes, 2_000 * MemoryLayout<Float>.stride, "two values a frame")
        XCTAssertEqual(buffer.heldFrames, 1_000)
        let copied = buffer.copyFrames()
        XCTAssertEqual(copied.count, 2_000)
        XCTAssertEqual(Array(copied[200..<204]), [0.1, 0, 0.101, 0], "left and right, interleaved")

        let read = sides(buffer, elapsed: 0, count: 1_000, step: 0.5)
        XCTAssertEqual(read.left[500], 0.25, accuracy: 1e-6, "the left at half speed")
        XCTAssertEqual(read.left[501], 0.2505, accuracy: 1e-6, "interpolated between two frames")
        XCTAssertTrue(read.right.allSatisfy { $0 == 0 }, "a silent right stays silent")
    }

    func testTwoSidesThatAreTheSameAreOneChannel() throws {
        let sound: [Float] = (0..<500).map { (index: Int) -> Float in Float(sin(Double(index) * 0.1)) }
        let buffer = try XCTUnwrap(SampleBuffer(left: sound, right: sound, sampleRate: 44_100))
        XCTAssertEqual(buffer.channelCount, 1, "a stereo file of a mono sound is mono")
        XCTAssertEqual(buffer.copyFrames(), sound)
        XCTAssertEqual(buffer.heldBytes, 500 * MemoryLayout<Float>.stride, "and holds one value a frame")
        let cleaned = try XCTUnwrap(SampleBuffer(left: [.nan, 0.5], right: [0, 0.5], sampleRate: 48_000))
        XCTAssertEqual(cleaned.channelCount, 1, "a non-finite value is silence before the sides are compared")
        XCTAssertEqual(cleaned.copyFrames(), [0, 0.5])
        let short = try XCTUnwrap(SampleBuffer(left: [0.1, 0.2, 0.3], right: [0.4, 0.5], sampleRate: 48_000))
        XCTAssertEqual(short.frameCount, 2, "as long as the shorter side")
        XCTAssertNil(SampleBuffer(left: [], right: [1], sampleRate: 48_000))
        XCTAssertNil(SampleBuffer(left: [1], right: [1], sampleRate: .nan))
    }

    /// A decode writes left and right interleaved straight into the buffer's own memory, and a file
    /// shorter than its header gives the room back as a mono one does.
    func testAStereoFillKeepsItsSidesAndGivesUnwrittenRoomBack() throws {
        let capacity = 100_000
        let buffer = try XCTUnwrap(try SampleBuffer(capacity: capacity, channels: 2, sampleRate: 48_000) {
            (values: UnsafeMutableBufferPointer<Float>) -> Int in
            XCTAssertEqual(values.count, 2 * capacity, "room for two values a frame")
            for frame in 0..<1_000 {
                values[2 * frame] = 0.5
                values[2 * frame + 1] = frame == 3 ? .infinity : -0.25
            }
            return 1_000
        })
        XCTAssertEqual(buffer.channelCount, 2)
        XCTAssertEqual(buffer.frameCount, 1_000)
        let copied = buffer.copyFrames()
        XCTAssertEqual(copied.count, 2_000)
        XCTAssertEqual(Array(copied[4..<8]), [0.5, -0.25, 0.5, 0], "a non-finite value is silence")
        XCTAssertGreaterThanOrEqual(buffer.heldBytes, 2_000 * MemoryLayout<Float>.stride)
        XCTAssertLessThan(buffer.heldBytes, 2 * capacity * MemoryLayout<Float>.stride / 10, "the unwritten room went back")
        #if canImport(Darwin)
        XCTAssertEqual(buffer.heldBytes, malloc_size(buffer.frames), "the count is the block the allocator keeps")
        #else
        XCTAssertEqual(buffer.heldBytes, 2_000 * MemoryLayout<Float>.stride)
        #endif
        XCTAssertNil(try SampleBuffer(capacity: 4, channels: 3, sampleRate: 48_000) { _ in 4 }, "one channel or two")
        XCTAssertNil(try SampleBuffer(capacity: 4, channels: 2, sampleRate: 48_000) { _ in 0 }, "nothing written")
    }

    /// A stereo file whose sides are the same is read as two and kept as one, in the same block:
    /// the right half of the room goes back.
    func testAStereoFillWhoseSidesMatchIsKeptAsOneChannelInHalfTheRoom() throws {
        let frames = 50_000
        let buffer = try XCTUnwrap(try SampleBuffer(capacity: frames, channels: 2, sampleRate: 48_000) {
            (values: UnsafeMutableBufferPointer<Float>) -> Int in
            for frame in 0..<frames {
                values[2 * frame] = Float(frame) / Float(frames)
                values[2 * frame + 1] = Float(frame) / Float(frames)
            }
            return frames
        })
        XCTAssertEqual(buffer.channelCount, 1)
        XCTAssertEqual(buffer.frameCount, frames)
        let copied = buffer.copyFrames()
        XCTAssertEqual(copied.count, frames)
        XCTAssertEqual(copied[0], 0)
        XCTAssertEqual(copied[12_345], Float(12_345) / Float(frames), "every frame moved to its own place")
        XCTAssertEqual(copied[frames - 1], Float(frames - 1) / Float(frames))
        XCTAssertGreaterThanOrEqual(buffer.heldBytes, frames * MemoryLayout<Float>.stride)
        #if canImport(Darwin)
        XCTAssertEqual(buffer.heldBytes, Swift.min(2 * frames * MemoryLayout<Float>.stride, malloc_size(buffer.frames)),
                       "the count is the block the allocator keeps, whole or shrunk")
        #else
        XCTAssertEqual(buffer.heldBytes, frames * MemoryLayout<Float>.stride, "half the room")
        #endif
    }

    /// A mono sample read by the stereo stretch puts the very values the mono stretch makes into
    /// both sides: an audio region of a mono file plays as it did before W17.
    func testAMonoSampleReadsIntoBothSidesExactlyAsIntoOne() throws {
        let ramp: [Float] = (0..<2_000).map { (index: Int) -> Float in Float(sin(Double(index) * 0.03)) }
        let buffer = try XCTUnwrap(SampleBuffer(samples: ramp, sampleRate: 44_100))
        for (step, fade) in [(1.0, 0.0), (0.918_75, 58.8), (1.5, 64.0)] {
            var mono = [Float](repeating: 0, count: 1_500)
            mono.withUnsafeMutableBufferPointer {
                buffer.add(into: $0, elapsed: -7, step: step, offset: 120, length: 1_400, fade: fade)
            }
            let read = sides(buffer, elapsed: -7, count: 1_500, step: step, offset: 120, length: 1_400, fade: fade)
            XCTAssertEqual(read.left, mono, "step \(step)")
            XCTAssertEqual(read.right, mono, "step \(step)")
        }
    }

    func testAStereoStretchReadsOnlyItsFramesAndDoesNotDependOnTheBlockSplit() throws {
        let left: [Float] = (0..<1_000).map { (index: Int) -> Float in Float(index) }
        let right: [Float] = (0..<1_000).map { (index: Int) -> Float in -Float(index) }
        let buffer = try XCTUnwrap(SampleBuffer(left: left, right: right, sampleRate: 48_000))
        let whole = sides(buffer, elapsed: -10, count: 500, step: 0.75, offset: 100, length: 300)
        XCTAssertTrue(whole.left[..<10].allSatisfy { $0 == 0 }, "nothing before the stretch")
        XCTAssertEqual(whole.left[10], 100, "starts at the offset")
        XCTAssertEqual(whole.right[10], -100)
        XCTAssertEqual(whole.left[14], 103, accuracy: 1e-4, "steps at the given rate")
        XCTAssertEqual(whole.right[14], -103, accuracy: 1e-4)
        XCTAssertTrue(whole.left[410...].allSatisfy { $0 == 0 }, "nothing after the stretch's 400 output frames")
        let first = sides(buffer, elapsed: -10, count: 137, step: 0.75, offset: 100, length: 300)
        let second = sides(buffer, elapsed: 127, count: 363, step: 0.75, offset: 100, length: 300)
        XCTAssertEqual(first.left + second.left, whole.left)
        XCTAssertEqual(first.right + second.right, whole.right)
        // The mono stretch of a stereo sample is its sides averaged.
        var mono = [Float](repeating: 0, count: 500)
        mono.withUnsafeMutableBufferPointer {
            buffer.add(into: $0, elapsed: -10, step: 0.75, offset: 100, length: 300, fade: 0)
        }
        XCTAssertTrue(mono.allSatisfy { $0 == 0 }, "the sides cancel")
    }

    /// A sampler plays a stereo sample as its two sides averaged — exactly the mono file the
    /// import made of it before W17, so a sampler track sounds as it did.
    func testTheSamplerPlaysAStereoSampleAsItsSidesAveraged() throws {
        let left: [Float] = (0..<4_800).map { (index: Int) -> Float in Float(sin(Double(index) * 0.05)) * 0.8 }
        let right: [Float] = (0..<4_800).map { (index: Int) -> Float in Float(cos(Double(index) * 0.02)) * 0.4 }
        let averaged: [Float] = zip(left, right).map { (pair: (Float, Float)) -> Float in (pair.0 + pair.1) * 0.5 }
        let stereo = try XCTUnwrap(SampleBuffer(left: left, right: right, sampleRate: 48_000))
        let mono = try XCTUnwrap(SampleBuffer(samples: averaged, sampleRate: 48_000))
        XCTAssertEqual(stereo.channelCount, 2)
        func play(_ buffer: SampleBuffer, pitch: UInt8) -> [Float] {
            var sampler = Sampler(patch: SamplerPatch(envelope: .init(attack: 0.001, decay: 0.01, sustain: 0.7, release: 0.01),
                                                      oneShot: false, level: 0.9),
                                  voiceCount: 2, sampleRate: rate)
            sampler.setSample(buffer)
            sampler.noteOn(pitch: pitch, velocity: 100)
            sampler.noteOn(pitch: pitch + 7, velocity: 80)
            var out = [Float](repeating: 0, count: 6_000)
            var start = 0
            while start < out.count {
                let end = Swift.min(start + 256, out.count)
                out[start..<end].withUnsafeMutableBufferPointer { sampler.render(into: $0) }
                if start == 2_048 { sampler.noteOff(pitch: pitch) }
                start = end
            }
            return out
        }
        for pitch: UInt8 in [60, 55, 72] {
            XCTAssertEqual(play(stereo, pitch: pitch), play(mono, pitch: pitch), "pitch \(pitch)")
        }
    }
}
