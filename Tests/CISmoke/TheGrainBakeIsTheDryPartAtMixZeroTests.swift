// TheGrainBakeIsTheDryPartAtMixZeroTests.swift
// Echoel — GMMW GA-10b: `Sequencer/GrainBake` renders a part's grain ONCE, off the render thread.
//
// WHAT IT PINS.
// 1. MIX 0 IS THE DRY PART, BIT FOR BIT — both channels equal the source, silence past its end,
//    a non-finite source sample as silence.
// 2. SILENCE IN → SILENCE OUT, and every sample finite under wild settings and a wild source.
// 3. THE SEED PINS THE BAKE — equal inputs give equal buffers; another seed another pattern.
// 4. LEVEL-MATCHED AGAINST OFF — a steady source through a centred, fully wet cloud comes out at
//    the dry level (the √2 power match), and the bake refuses what it cannot hold (no frames, a bad
//    rate, a part longer than `maxSeconds`) so the caller plays the part dry.
//
// END-TO-END BEHAVIOUR over the shipped function; no source-text scan.
// HONEST GRADING (§3): the file does NOT compile against the parent — `GrainBake` is new — so no
// assertion has a verdict there; every claim is a FORWARD guard (one absence, #486). Counterweights:
// claim 3's "another seed differs", claim 4's nil cases. Graded by a Python transcription of
// `GrainCloud.process` + `GrainBake.render` (claim 4 measured 0.49999… in the steady region).
//
// ⚠️ THE LIMIT. Nothing plays a bake yet — GA-10c schedules it in `TimelineAudioSink`. How it
// SOUNDS and what it costs on a phone are a device probe.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheGrainBakeIsTheDryPartAtMixZeroTests: XCTestCase {

    private static let rate: Double = 48_000

    /// Deterministic noise in −0.5 … 0.5, so the claims do not depend on a random source.
    private func noise(_ count: Int, seed: UInt64 = 1) -> [Float] {
        var state = seed
        return (0..<count).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float(state >> 40) / Float(1 << 24) - 0.5
        }
    }

    private func settings(mix: Float, seed: UInt64 = 7) -> GrainSettings {
        var s = GrainSettings()
        s.position = 0.5
        s.spraySeconds = 0.2
        s.mix = mix
        s.seed = seed
        return s
    }

    // MARK: 1

    func testMixZeroIsTheDryPartBitForBit() throws {
        var source = noise(9_000)
        let dry = source
        source[10] = .nan
        source[11] = .infinity
        let baked = try XCTUnwrap(GrainBake.render(source: source, sampleRate: Self.rate,
                                                   frameCount: 10_000, settings: settings(mix: 0)))
        XCTAssertEqual(baked.frameCount, 10_000)
        XCTAssertEqual(baked.left, baked.right, "the dry part sits on both channels")
        var expected = dry + [Float](repeating: 0, count: 1_000)
        expected[10] = 0
        expected[11] = 0
        XCTAssertEqual(baked.left, expected, "dry samples untouched, silence past the end, non-finite as 0")

        let shorter = try XCTUnwrap(GrainBake.render(source: dry, sampleRate: Self.rate,
                                                     frameCount: 500, settings: settings(mix: 0)))
        XCTAssertEqual(shorter.left, Array(dry.prefix(500)), "a shorter part takes the start of the source")
    }

    // MARK: 2

    func testSilenceStaysSilentAndEverySampleIsFinite() throws {
        let silent = try XCTUnwrap(GrainBake.render(source: [Float](repeating: 0, count: 48_000),
                                                    sampleRate: Self.rate, frameCount: 24_000,
                                                    settings: settings(mix: 1)))
        XCTAssertTrue(silent.left.allSatisfy { $0 == 0 } && silent.right.allSatisfy { $0 == 0 })

        var wild = GrainSettings()
        wild.position = .nan
        wild.grainMilliseconds = .infinity
        wild.density = 9
        wild.pitchSemitones = -.infinity
        wild.stereoSpread = 4
        wild.mix = 0.6
        var source = noise(48_000)
        source[100] = .nan
        source[200] = -.infinity
        let baked = try XCTUnwrap(GrainBake.render(source: source, sampleRate: Self.rate,
                                                   frameCount: 24_000, settings: wild))
        XCTAssertTrue(baked.left.allSatisfy(\.isFinite) && baked.right.allSatisfy(\.isFinite))
        XCTAssertEqual(baked.right.count, 24_000)
    }

    // MARK: 3

    func testTheSeedPinsTheBake() throws {
        let source = noise(48_000)
        let a = try XCTUnwrap(GrainBake.render(source: source, sampleRate: Self.rate, frameCount: 24_000,
                                               settings: settings(mix: 1, seed: 1)))
        let b = try XCTUnwrap(GrainBake.render(source: source, sampleRate: Self.rate, frameCount: 24_000,
                                               settings: settings(mix: 1, seed: 1)))
        let other = try XCTUnwrap(GrainBake.render(source: source, sampleRate: Self.rate, frameCount: 24_000,
                                                   settings: settings(mix: 1, seed: 2)))
        XCTAssertEqual(a, b, "equal inputs bake equal buffers")
        XCTAssertNotEqual(a.left, other.left, "COUNTERWEIGHT: another seed is another pattern")
    }

    // MARK: 4

    func testTheCloudIsLevelMatchedAndTheBakeRefusesWhatItCannotHold() throws {
        // A steady source, centred grains at overlap 2 (density 0.5): two Hann windows at half a
        // grain's hop sum to 1, each channel carries −3 dB, the √2 match brings it back to 0.5.
        var centred = GrainSettings()
        centred.position = 0.5
        centred.density = 0.5
        centred.stereoSpread = 0
        centred.mix = 1
        let steady = [Float](repeating: 0.5, count: 48_000)
        let baked = try XCTUnwrap(GrainBake.render(source: steady, sampleRate: Self.rate,
                                                   frameCount: 24_000, settings: centred))
        // From the second grain on (80 ms grains, hop 40 ms = 1 920 frames) the sum is flat.
        for i in stride(from: 4_000, to: 24_000, by: 997) {
            XCTAssertEqual(baked.left[i], 0.5, accuracy: 5e-3, "left at \(i)")
            XCTAssertEqual(baked.right[i], 0.5, accuracy: 5e-3, "right at \(i)")
        }

        let source = noise(1_000)
        XCTAssertNil(GrainBake.render(source: source, sampleRate: Self.rate, frameCount: 0, settings: centred))
        XCTAssertNil(GrainBake.render(source: source, sampleRate: .nan, frameCount: 100, settings: centred))
        XCTAssertNil(GrainBake.render(source: source, sampleRate: 0, frameCount: 100, settings: centred))
        let tooLong = Int(GrainBake.maxSeconds * Self.rate) + 1
        XCTAssertNil(GrainBake.render(source: source, sampleRate: Self.rate, frameCount: tooLong,
                                      settings: centred), "longer than the cap: the caller plays it dry")
    }
}
