import XCTest
@testable import EchoelCore

/// The pattern generator is a pure function (wave W11.1c): same vibe + seed + role + bars →
/// same notes, every time, on every platform. The role shapes pitch bands and rhythm; the
/// vibe shapes count, density and velocity.
final class PatternGeneratorTests: XCTestCase {

    private func vibe(energy: Double = 0.5, density: Double = 0.5) -> VibeParameters {
        VibeParameters(genre: .hipHop, energy: energy, density: density, brightness: 0.5,
                       targetBPM: 90, targetKeyRoot: 0, targetScale: .minor)
    }

    func testSameInputProducesSameOutput() {
        let v = vibe()
        let a = PatternGenerator.generate(vibe: v, seed: 42, role: .drums)
        let b = PatternGenerator.generate(vibe: v, seed: 42, role: .drums)
        XCTAssertEqual(a, b)
    }

    func testDifferentSeedProducesDifferentOutputForRandomParts() {
        let v = vibe(density: 0.6)
        let a = PatternGenerator.generate(vibe: v, seed: 1, role: .drums)
        let b = PatternGenerator.generate(vibe: v, seed: 2, role: .drums)
        XCTAssertNotEqual(a, b)
    }

    func testDrumsPlaceKickOnBeatOne() {
        let notes = PatternGenerator.generate(vibe: vibe(), seed: 7, role: .drums)
        XCTAssertTrue(notes.contains(where: { $0.pitch == 36 && $0.start == 0 }))
    }

    func testDrumsPlaceSnareOnTwoAndFour() {
        let notes = PatternGenerator.generate(vibe: vibe(), seed: 7, role: .drums)
        let ticksPerBar = MusicalTime.ticksPerBar(.common)
        let step = ticksPerBar / 16
        XCTAssertTrue(notes.contains(where: { $0.pitch == 38 && $0.start == 4 * step }))
        XCTAssertTrue(notes.contains(where: { $0.pitch == 38 && $0.start == 12 * step }))
    }

    func testBassStaysInLowOctave() {
        let notes = PatternGenerator.generate(vibe: vibe(), seed: 7, role: .bass)
        XCTAssertFalse(notes.isEmpty)
        for n in notes {
            XCTAssertGreaterThanOrEqual(n.pitch, 36)
            XCTAssertLessThanOrEqual(n.pitch, 72)
        }
    }

    func testChordsEmitThreeNotesPerChord() {
        let notes = PatternGenerator.generate(vibe: vibe(density: 0.3), seed: 7, role: .chords)
        // Two chords per bar for density < 0.55 → 6 notes.
        XCTAssertEqual(notes.count, 6)
    }

    func testLeadStaysInUpperRegister() {
        let v = vibe(density: 0.9)
        let notes = PatternGenerator.generate(vibe: v, seed: 7, role: .lead)
        for n in notes {
            XCTAssertGreaterThanOrEqual(n.pitch, 72)
            XCTAssertLessThanOrEqual(n.pitch, 96)
        }
    }

    func testHigherEnergyRaisesVelocities() {
        let soft = PatternGenerator.generate(vibe: vibe(energy: 0.0), seed: 7, role: .drums)
        let hard = PatternGenerator.generate(vibe: vibe(energy: 1.0), seed: 7, role: .drums)
        let softMean = soft.map { Double($0.velocity) }.reduce(0, +) / Double(soft.count)
        let hardMean = hard.map { Double($0.velocity) }.reduce(0, +) / Double(hard.count)
        XCTAssertLessThan(softMean, hardMean)
    }

    func testBarsExtendTheLoopLinearly() {
        let v = vibe()
        let oneBar = PatternGenerator.generate(vibe: v, seed: 7, role: .drums, bars: 1)
        let twoBars = PatternGenerator.generate(vibe: v, seed: 7, role: .drums, bars: 2)
        XCTAssertGreaterThan(twoBars.count, oneBar.count)
        let ticksPerBar = MusicalTime.ticksPerBar(.common)
        for n in twoBars {
            XCTAssertGreaterThanOrEqual(n.start, 0)
            XCTAssertLessThan(n.start, 2 * ticksPerBar)
        }
    }

    func testRolesWithSameSeedDiverge() {
        let v = vibe()
        let drums = PatternGenerator.generate(vibe: v, seed: 7, role: .drums)
        let bass = PatternGenerator.generate(vibe: v, seed: 7, role: .bass)
        XCTAssertNotEqual(drums.map(\.pitch), bass.map(\.pitch))
    }

    func testSplitMix64IsReproducible() {
        var a = SplitMix64(seed: 123)
        var b = SplitMix64(seed: 123)
        for _ in 0..<10 {
            XCTAssertEqual(a.next(), b.next())
        }
    }
}
