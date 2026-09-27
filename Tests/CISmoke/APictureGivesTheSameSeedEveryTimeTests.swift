// APictureGivesTheSameSeedEveryTimeTests.swift
// MS1 (founder order 2026-09-27, "Foto und Video werden zu kreativem Material"): the pure core
// that turns a downsampled RGBA8 picture into a `MediaSeed`.
//
// WHAT KIND OF GREEN THIS IS (§1): END-TO-END on a shipped, Foundation-only function
// (`MediaSeedAnalysis.analyzeRGBA8`). No picture file, no ImageIO, no device — bytes in, seed out.
// The expectations come from colour science, not from the implementation: pure red has hue 0 and
// pure blue 240° = 2/3 of a turn; a black/white checkerboard has the largest possible luma spread.
// DEVICE PROBE, open: that a real photo decoded by ImageIO gives a seed a person would call right.
//
// HONEST GRADING against the parent (dfe9525e6, §3): the file does not COMPILE there — every claim
// names `MediaSeedAnalysis`, which this commit creates — so no assertion has a verdict on the parent.
// All claims are FORWARD guards, reported once (#486). Hand-transcribed in Python against the new
// tree; mutants driven, each red for its named reason: `>=` in the bin arg-max (claim 4), the
// size limit removed (claim 3), the colour-share floor removed (claim 5), padding bytes read as
// pixels (claim 1b), contrast not normalised (claim 2).
// REVIEW REPAIR (2026-09-27): an overflowing stride gives nil instead of a trap (claim 3, a
// REGRESSION guard — it traps on the MS1 tree), and a flat picture has contrast 0 (claim 3b,
// REGRESSION: the MS1 one-pass variance gives 1.86e-9 for solid blue, transcribed). Hue bins
// stay fixed, not circular — a red split across bins 35 and 0 can lose to a smaller orange
// bin; recorded as a known limit, not fixed.

import Foundation
import XCTest
@testable import Echoelmusic

final class APictureGivesTheSameSeedEveryTimeTests: XCTestCase {

    // MARK: fixtures

    private func solid(_ r: UInt8, _ g: UInt8, _ b: UInt8, side: Int = 8) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(side * side * 4)
        for _ in 0..<(side * side) { bytes += [r, g, b, 255] }
        return bytes
    }

    /// A deterministic pseudo-random picture (LCG), so "any picture" is the same picture every run.
    private func noise(side: Int, seed: UInt32) -> [UInt8] {
        var state = seed
        var bytes: [UInt8] = []
        bytes.reserveCapacity(side * side * 4)
        for _ in 0..<(side * side * 4) {
            state = state &* 1_664_525 &+ 1_013_904_223
            bytes.append(UInt8(truncatingIfNeeded: state >> 24))
        }
        return bytes
    }

    // MARK: 1 — determinism

    func testTheSameBytesGiveTheSameSeed() throws {
        let picture = noise(side: 64, seed: 7)
        let first = try XCTUnwrap(MediaSeedAnalysis.analyzeRGBA8(picture, width: 64, height: 64, bytesPerRow: 256))
        let copy = Array(picture)
        let second = try XCTUnwrap(MediaSeedAnalysis.analyzeRGBA8(copy, width: 64, height: 64, bytesPerRow: 256))
        XCTAssertEqual(first, second, "identical input, identical seed — nothing random, nothing clock-dependent")
        XCTAssertEqual(first.version, MediaSeed.formatVersion)
        XCTAssertEqual(first.sampledPixels, 64 * 64)
    }

    func testRowPaddingIsNotReadAsPicture() throws {
        // The same 8×8 red picture, once tight and once with 16 padding bytes of WHITE per row.
        let tight = solid(255, 0, 0)
        var padded: [UInt8] = []
        for row in 0..<8 {
            padded += tight[(row * 32)..<(row * 32 + 32)]
            padded += [UInt8](repeating: 255, count: 16)
        }
        let a = try XCTUnwrap(MediaSeedAnalysis.analyzeRGBA8(tight, width: 8, height: 8, bytesPerRow: 32))
        let b = try XCTUnwrap(MediaSeedAnalysis.analyzeRGBA8(padded, width: 8, height: 8, bytesPerRow: 48))
        XCTAssertEqual(a, b, "a decoder's row stride must not leak white padding into the seed")
    }

    // MARK: 2 — the numbers mean what their names say, and stay in bounds

    func testPrimaryColoursLandOnTheirHues() throws {
        let red = try XCTUnwrap(MediaSeedAnalysis.analyzeRGBA8(solid(255, 0, 0), width: 8, height: 8, bytesPerRow: 32))
        XCTAssertTrue(red.hasDominantColour)
        XCTAssertEqual(red.hue, 0, accuracy: 1e-9, "red is hue 0")
        XCTAssertEqual(red.saturation, 1, accuracy: 1e-9)
        XCTAssertEqual(red.contrast, 0, accuracy: 1e-9, "a flat picture has no contrast")
        XCTAssertEqual(red.dominantRed, 1, accuracy: 1e-9)
        XCTAssertEqual(red.dominantGreen, 0, accuracy: 1e-9)

        let blue = try XCTUnwrap(MediaSeedAnalysis.analyzeRGBA8(solid(0, 0, 255), width: 8, height: 8, bytesPerRow: 32))
        XCTAssertEqual(blue.hue, 2.0 / 3.0, accuracy: 1e-9, "blue is 240°, two thirds of a turn")
        XCTAssertLessThan(blue.brightness, red.brightness, "blue reads darker than red (Rec. 709 luma)")
    }

    func testACheckerboardHasFullContrastAndMidBrightness() throws {
        var bytes: [UInt8] = []
        for y in 0..<8 { for x in 0..<8 {
            let v: UInt8 = (x + y) % 2 == 0 ? 0 : 255
            bytes += [v, v, v, 255]
        } }
        let seed = try XCTUnwrap(MediaSeedAnalysis.analyzeRGBA8(bytes, width: 8, height: 8, bytesPerRow: 32))
        XCTAssertEqual(seed.brightness, 0.5, accuracy: 1e-9)
        XCTAssertEqual(seed.contrast, 1, accuracy: 1e-9, "half black, half white is the largest spread a 0…1 luma has")
        XCTAssertFalse(seed.hasDominantColour, "black and white have no hue")
    }

    func testEveryValueStaysInsideItsRange() throws {
        for s: UInt32 in [1, 2, 3, 99, 12_345] {
            let seed = try XCTUnwrap(MediaSeedAnalysis.analyzeRGBA8(noise(side: 32, seed: s), width: 32, height: 32, bytesPerRow: 128))
            for (name, value) in [("hue", seed.hue), ("brightness", seed.brightness), ("saturation", seed.saturation),
                                  ("contrast", seed.contrast), ("red", seed.dominantRed),
                                  ("green", seed.dominantGreen), ("blue", seed.dominantBlue)] {
                XCTAssertTrue(value.isFinite && value >= 0 && value <= 1, "\(name) = \(value) for noise seed \(s)")
            }
            XCTAssertLessThan(seed.hue, 1, "hue is a turn, 0 ≤ hue < 1")
        }
    }

    // MARK: 3 — invalid or oversized input falls back safely

    func testABufferThatCannotBeWhatItClaimsGivesNoSeed() {
        let good = solid(10, 20, 30)
        XCTAssertNil(MediaSeedAnalysis.analyzeRGBA8(good, width: 0, height: 8, bytesPerRow: 32))
        XCTAssertNil(MediaSeedAnalysis.analyzeRGBA8(good, width: 8, height: -1, bytesPerRow: 32))
        XCTAssertNil(MediaSeedAnalysis.analyzeRGBA8(good, width: 8, height: 8, bytesPerRow: 31),
                     "a row stride shorter than a row")
        XCTAssertNil(MediaSeedAnalysis.analyzeRGBA8(Array(good.dropLast()), width: 8, height: 8, bytesPerRow: 32),
                     "one byte short of the last row")
        XCTAssertNil(MediaSeedAnalysis.analyzeRGBA8([], width: 1, height: 1, bytesPerRow: 4))
        XCTAssertNil(MediaSeedAnalysis.analyzeRGBA8(good, width: 8, height: 8, bytesPerRow: Int.max / 2),
                     "a stride from a broken caller gives nil — it must not trap on overflow (review)")
    }

    func testAFlatPictureHasNoContrastAtAll() throws {
        // The one-pass variance cancelled here and gave ~2e-9 (review LOW); two passes give 0.
        let seed = try XCTUnwrap(MediaSeedAnalysis.analyzeRGBA8(solid(0, 0, 255), width: 8, height: 8, bytesPerRow: 32))
        XCTAssertEqual(seed.contrast, 0, accuracy: 1e-12)
    }

    func testTheAnalysisRefusesAPictureTheDecoderDidNotShrink() {
        let limit = MediaSeedAnalysis.maxAnalysisSide
        let atLimit = [UInt8](repeating: 128, count: limit * 4)
        XCTAssertNotNil(MediaSeedAnalysis.analyzeRGBA8(atLimit, width: limit, height: 1, bytesPerRow: limit * 4))
        let over = [UInt8](repeating: 128, count: (limit + 1) * 4)
        XCTAssertNil(MediaSeedAnalysis.analyzeRGBA8(over, width: limit + 1, height: 1, bytesPerRow: (limit + 1) * 4),
                     "one pixel over the side limit is refused — the work is bounded by construction")
        XCTAssertNil(MediaSeedAnalysis.analyzeRGBA8(over, width: 1, height: limit + 1, bytesPerRow: 4))
    }

    // MARK: 4 — ties resolve the same way every time

    func testATieBetweenTwoHuesGoesToTheLowerHue() throws {
        // One red and one green pixel: equal weight in two bins. The first maximum wins.
        let seed = try XCTUnwrap(MediaSeedAnalysis.analyzeRGBA8([255, 0, 0, 255, 0, 255, 0, 255],
                                                                width: 2, height: 1, bytesPerRow: 8))
        XCTAssertEqual(seed.hue, 0, accuracy: 1e-9, "red (bin 0) beats green (bin 12) on a tie")
    }

    // MARK: 5 — a grey picture says it has no colour instead of reporting its noise

    func testAFewColouredPixelsDoNotMakeADominantColour() throws {
        func picture(colouredPixels: Int) -> [UInt8] {
            var bytes: [UInt8] = []
            for i in 0..<100 { bytes += i < colouredPixels ? [0, 0, 255, 255] : [128, 128, 128, 255] }
            return bytes
        }
        let floor = MediaSeedAnalysis.minColourShare
        XCTAssertTrue(floor > 0 && floor < 0.5, "the floor is a small share, not a majority")
        let below = try XCTUnwrap(MediaSeedAnalysis.analyzeRGBA8(picture(colouredPixels: Int(floor * 100) - 1),
                                                                 width: 10, height: 10, bytesPerRow: 40))
        XCTAssertFalse(below.hasDominantColour)
        XCTAssertEqual(below.hue, 0, "no dominant colour → no hue claimed")
        let above = try XCTUnwrap(MediaSeedAnalysis.analyzeRGBA8(picture(colouredPixels: Int(floor * 100) + 1),
                                                                 width: 10, height: 10, bytesPerRow: 40))
        XCTAssertTrue(above.hasDominantColour)
        XCTAssertEqual(above.hue, 2.0 / 3.0, accuracy: 1e-9)
    }

    // MARK: 6 — the analysis stays off the audio path by construction

    func testTheCoreImportsOnlyFoundation() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent("Sources/Echoelmusic/Core/MediaSeed.swift")
        let code = SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
        let imports = code.split(separator: "\n").filter { $0.hasPrefix("import ") }.map(String.init)
        XCTAssertEqual(imports, ["import Foundation"],
                       "the seed core is pure — no AVFoundation, no ImageIO, no UIKit, no engine type")
        for engine in ["AudioEngine", "EngineBus", "PatternEngine", "DispatchQueue", "Task {"] {
            XCTAssertFalse(code.contains(engine), "the pure core names `\(engine)`")
        }
    }
}
