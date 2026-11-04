import XCTest
@testable import EchoelCore

final class ExportLoudnessTests: XCTestCase {
    /// Off first — the mix as it plays — then the three targets, each under the same −1 dBTP
    /// ceiling, and the peak guard with no loudness target.
    func testTheChoicesAreOffThreeTargetsAndThePeakUnderOneCeiling() {
        XCTAssertEqual(ExportLoudness.allCases, [.off, .minus14, .minus16, .minus23, .peak])
        XCTAssertEqual(ExportLoudness.allCases.map(\.target), [nil, -14, -16, -23, nil])
        XCTAssertEqual(ExportLoudness.allCases.map(\.title), ["Off", "−14 LUFS", "−16 LUFS", "−23 LUFS", "Peak −1 dBTP"])
        XCTAssertEqual(ExportLoudness.allCases.map(\.changesMix), [false, true, true, true, true])
        XCTAssertEqual(ExportLoudness.truePeakCeiling, -1)
    }

    /// The device keeps the choice by these names between launches.
    func testTheKeptNamesStayAsTheyAre() {
        XCTAssertEqual(ExportLoudness.allCases.map(\.rawValue), ["off", "-14", "-16", "-23", "peak"])
        XCTAssertEqual(ExportLoudness(rawValue: "-16"), .minus16)
        XCTAssertNil(ExportLoudness(rawValue: "-18"), "a name this build does not know is not guessed")
    }

    /// Within half an LU a file is on its target; silence never is, and Off has nothing to reach.
    func testAFileIsOnItsTargetWithinHalfAnLU() {
        XCTAssertTrue(ExportLoudness.minus14.isReached(by: -14.4))
        XCTAssertTrue(ExportLoudness.minus14.isReached(by: -13.5))
        XCTAssertFalse(ExportLoudness.minus14.isReached(by: -14.6))
        XCTAssertFalse(ExportLoudness.minus23.isReached(by: -.infinity))
        XCTAssertFalse(ExportLoudness.minus16.isReached(by: .nan))
        XCTAssertTrue(ExportLoudness.off.isReached(by: -.infinity))
        XCTAssertTrue(ExportLoudness.peak.isReached(by: -30))
    }

    /// The default export keeps a mix under −1 dBTP by a plain gain, down only (audit 2026-11-04:
    /// the Four Tracks starter exported at +0.15 dBTP under Off, the default before).
    func testTheDefaultExportLowersOnlyAPeakAboveTheCeiling() {
        XCTAssertEqual(ExportLoudness.exportDefault, .peak)
        XCTAssertEqual(try XCTUnwrap(ExportLoudness.peak.peakGain(forTruePeak: 0.15)), -1.15, accuracy: 1e-12)
        XCTAssertEqual(ExportLoudness.peak.peakGain(forTruePeak: -1), 0)
        XCTAssertEqual(ExportLoudness.peak.peakGain(forTruePeak: -6), 0, "never raised")
        XCTAssertEqual(ExportLoudness.peak.peakGain(forTruePeak: -.infinity), 0, "silence")
        XCTAssertNil(ExportLoudness.minus14.peakGain(forTruePeak: 0.15))
    }
}
