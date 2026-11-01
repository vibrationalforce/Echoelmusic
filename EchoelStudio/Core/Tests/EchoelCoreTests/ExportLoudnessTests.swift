import XCTest
@testable import EchoelCore

final class ExportLoudnessTests: XCTestCase {
    /// Off first — the mix as it plays, every export's default — then the three targets, each under
    /// the same −1 dBTP ceiling.
    func testTheChoicesAreOffAndThreeTargetsUnderOneCeiling() {
        XCTAssertEqual(ExportLoudness.allCases, [.off, .minus14, .minus16, .minus23])
        XCTAssertEqual(ExportLoudness.allCases.map(\.target), [nil, -14, -16, -23])
        XCTAssertEqual(ExportLoudness.allCases.map(\.title), ["Off", "−14 LUFS", "−16 LUFS", "−23 LUFS"])
        XCTAssertEqual(ExportLoudness.truePeakCeiling, -1)
    }

    /// The device keeps the choice by these names between launches.
    func testTheKeptNamesStayAsTheyAre() {
        XCTAssertEqual(ExportLoudness.allCases.map(\.rawValue), ["off", "-14", "-16", "-23"])
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
    }
}
