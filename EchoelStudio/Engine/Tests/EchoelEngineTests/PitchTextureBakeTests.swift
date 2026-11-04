import EchoelCore
import EchoelDSP
@testable import EchoelEngine
import Foundation
import XCTest

/// W3: a region's bake reads the song's key, scale and concert pitch, cuts its stretch out of the
/// original, and repeats under one seed.
final class PitchTextureBakeTests: XCTestCase {
    private let rate = 48_000.0

    private func tone(_ hertz: Double, seconds: Double) -> [Float] {
        (0..<Int(seconds * rate)).map { (index: Int) -> Float in
            Float(0.5 * sin(2 * Double.pi * hertz * Double(index) / rate))
        }
    }

    private func hertz(_ samples: [Float], from start: Int, to end: Int) -> Double {
        var first = -1.0, last = 0.0, count = 0
        for index in Swift.max(start, 1)..<end where samples[index - 1] < 0 && samples[index] >= 0 {
            let at = Double(index - 1) + Double(-samples[index - 1]) / Double(samples[index] - samples[index - 1])
            if first < 0 { first = at }
            last = at
            count += 1
        }
        return count > 2 ? Double(count - 1) * rate / (last - first) : 0
    }

    func testTheSongsKeyAndConcertPitchAreTheTargets() throws {
        // D major at A = 442: C♯ is in the key, C is not. A C sharp by 30 cents of 442 lands on C♯.
        let context = MusicalContext(root: 2, scale: .major, concertPitch: 442)
        let cSharp = 442 * Foundation.pow(2, -8.0 / 12)
        let input = tone(cSharp * Foundation.pow(2, 30.0 / 1_200), seconds: 2)
        let bake = RegionBaking(source: MediaID(), sourceOffset: 0, pitchCorrection: .init(strength: 1, retune: 0.01))
        let output = try XCTUnwrap(PitchTextureBake.render(.init(left: input), sampleRate: rate, bake: bake, context: context))
        let landed = hertz(output.left, from: Int(0.5 * rate), to: Int(1.8 * rate))
        XCTAssertEqual(1_200 * Foundation.log2(landed / cSharp), 0, accuracy: 5)
        let settings = PitchTextureBake.correctorSettings(for: context, .init())
        XCTAssertEqual(settings.allowed, PitchCorrector.Settings.mask(root: 2, steps: [0, 2, 4, 5, 7, 9, 11]))
        XCTAssertEqual(settings.reference, 442)
    }

    func testAStretchIsCutFromBothSidesAndAnOutsideOneIsRefused() throws {
        let left = (0..<100).map { Float($0) }, right = (0..<100).map { Float(-$0) }
        let buffer = try XCTUnwrap(SampleBuffer(left: left, right: right, sampleRate: rate))
        let cut = try XCTUnwrap(PitchTextureBake.excerpt(of: buffer, offset: 10, length: 5))
        XCTAssertEqual(cut.left, [10, 11, 12, 13, 14])
        XCTAssertEqual(cut.right, [-10, -11, -12, -13, -14])
        let mono = try XCTUnwrap(SampleBuffer(samples: left, sampleRate: rate))
        XCTAssertEqual(PitchTextureBake.excerpt(of: mono, offset: 98, length: 2)?.left, [98, 99])
        XCTAssertNil(PitchTextureBake.excerpt(of: mono, offset: 98, length: 3))
        XCTAssertNil(PitchTextureBake.excerpt(of: mono, offset: -1, length: 3))
    }

    func testBothEditsRepeatBitForBitAndAWrittenFileHasTheFrames() throws {
        let bake = RegionBaking(source: MediaID(), sourceOffset: 0, pitchCorrection: .init(),
                                texture: .init(size: 0.04, density: 0.6, scatter: 0.05, pitch: 3, seed: 8))
        let input = OfflineBake.Audio(left: tone(450, seconds: 1))
        let first = try XCTUnwrap(PitchTextureBake.render(input, sampleRate: rate, bake: bake, context: MusicalContext()))
        let second = try XCTUnwrap(PitchTextureBake.render(input, sampleRate: rate, bake: bake, context: MusicalContext()))
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.frameCount, input.frameCount)
        XCTAssertNil(PitchTextureBake.render(input, sampleRate: rate, bake: RegionBaking(source: MediaID(), sourceOffset: 0),
                                             context: MusicalContext()), "no edit, nothing to bake")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bake-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try PitchTextureBake.write(first, to: url, sampleRate: rate)
        let size = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        XCTAssertGreaterThanOrEqual(size, first.frameCount * 2 * 4, "two channels of 32-bit float")
    }
}
