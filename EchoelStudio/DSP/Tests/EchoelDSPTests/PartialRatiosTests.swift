import Foundation
import XCTest
@testable import EchoelDSP

/// The partial-ratio meter: a harmonic tone reads whole numbers, a bell its inharmonic ratios
/// with their distance in cents, a quiet partial is left out, silence reads nothing.
final class PartialRatiosTests: XCTestCase {
    func testAHarmonicToneReadsWholeNumbers() {
        let peaks = SpectralPeaks([(660, 0.2), (220, 0.8), (440, 0.4)])
        let ratios = PartialRatios.of(peaks)
        XCTAssertEqual(ratios.lowestHz, 220)
        XCTAssertEqual(ratios.entries.map(\.harmonic), [1, 2, 3])
        for (entry, expected) in zip(ratios.entries, [1.0, 2.0, 3.0]) {
            XCTAssertEqual(entry.ratio, expected, accuracy: 1e-12)
            XCTAssertEqual(entry.cents, 0, accuracy: 1e-9)
        }
        XCTAssertEqual(ratios.entries.map(\.level), [1.0, 0.5, 0.25])
    }

    /// A bell's second mode at 2.76 lies between 2 and 3, nearer 3, 144 cents flat of it.
    func testABellReadsItsInharmonicRatioInCents() {
        let ratios = PartialRatios.of(SpectralPeaks([(220, 1), (220 * 2.76, 0.5)]))
        XCTAssertEqual(ratios.entries[1].harmonic, 3)
        XCTAssertEqual(ratios.entries[1].cents, 1200 * log2(2.76 / 3), accuracy: 1e-9)
        XCTAssertEqual(ratios.entries[1].cents, -144.3, accuracy: 0.1)
    }

    /// A rumble far below the tone does not become the reference; the lowest partial strong
    /// enough does — even when the fundamental is missing.
    func testAQuietPartialIsLeftOutAndTheLowestStrongOneIsTheReference() {
        let ratios = PartialRatios.of(SpectralPeaks([(40, 0.005), (440, 1), (660, 0.5)]))
        XCTAssertEqual(ratios.lowestHz, 440, "the 40 Hz rumble is under 1 % of the strongest")
        XCTAssertEqual(ratios.entries.count, 2)
        XCTAssertEqual(ratios.entries[1].ratio, 1.5, accuracy: 1e-12)
        XCTAssertEqual(ratios.entries[1].harmonic, 2, "1.5 rounds to 2: a fifth reads as a ratio, not a harmonic")
    }

    func testSilenceReadsNothing() {
        XCTAssertEqual(PartialRatios.of(.silent), .silent)
        XCTAssertEqual(PartialRatios.of(.silent).spoken, "No partials")
        XCTAssertTrue(PartialRatios.of(SpectralPeaks([(220, 1), (440, 0.5)])).spoken.contains("1.00, 2.00"))
    }
}
