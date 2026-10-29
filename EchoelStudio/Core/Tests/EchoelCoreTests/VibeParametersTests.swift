import XCTest
@testable import EchoelCore

/// A `VibeParameters` is pure, bounded, deterministic (wave W11.1a). Three claims:
/// 1. non-finite and out-of-range inputs are clamped at the door;
/// 2. equal parameters hash to equal `defaultSeed`s, different parameters do not;
/// 3. negative pitch classes wrap into 0 … 11.
final class VibeParametersTests: XCTestCase {

    func testTheDoorClampsNonFiniteAndOutOfRangeValues() {
        let v = VibeParameters(
            genre: .hipHop,
            energy: .nan,
            density: 1.7,
            brightness: -0.5,
            targetBPM: .infinity,
            targetKeyRoot: 14,
            targetScale: .minor
        )
        XCTAssertEqual(v.energy, 0)
        XCTAssertEqual(v.density, 1)
        XCTAssertEqual(v.brightness, 0)
        XCTAssertEqual(v.targetBPM, 90)
        XCTAssertEqual(v.targetKeyRoot, 2)
    }

    func testTheDefaultSeedIsStableAcrossEqualParameters() {
        let a = VibeParameters(genre: .chill, energy: 0.3, density: 0.4,
                               brightness: 0.6, targetBPM: 72,
                               targetKeyRoot: 9, targetScale: .minorPentatonic)
        let b = VibeParameters(genre: .chill, energy: 0.3, density: 0.4,
                               brightness: 0.6, targetBPM: 72,
                               targetKeyRoot: 9, targetScale: .minorPentatonic)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.defaultSeed, b.defaultSeed)
    }

    func testTheDefaultSeedDiffersAcrossDifferentGenres() {
        let a = VibeParameters(genre: .hipHop, energy: 0.5, density: 0.5,
                               brightness: 0.5, targetBPM: 90,
                               targetKeyRoot: 0, targetScale: .minor)
        let b = VibeParameters(genre: .edm, energy: 0.5, density: 0.5,
                               brightness: 0.5, targetBPM: 90,
                               targetKeyRoot: 0, targetScale: .minor)
        XCTAssertNotEqual(a.defaultSeed, b.defaultSeed)
    }

    func testTheDoorWrapsNegativePitchClasses() {
        let v = VibeParameters(genre: .score, energy: 0.5, density: 0.5,
                               brightness: 0.5, targetBPM: 72,
                               targetKeyRoot: -5, targetScale: .dorian)
        XCTAssertEqual(v.targetKeyRoot, 7)
    }

    func testBPMClampsIntoTheMusicalRange() {
        let slow = VibeParameters(genre: .score, energy: 0, density: 0.2,
                                  brightness: 0.5, targetBPM: 20,
                                  targetKeyRoot: 0, targetScale: .minor)
        XCTAssertEqual(slow.targetBPM, 40)
        let fast = VibeParameters(genre: .edm, energy: 1, density: 1,
                                  brightness: 1, targetBPM: 500,
                                  targetKeyRoot: 0, targetScale: .minor)
        XCTAssertEqual(fast.targetBPM, 240)
    }
}
