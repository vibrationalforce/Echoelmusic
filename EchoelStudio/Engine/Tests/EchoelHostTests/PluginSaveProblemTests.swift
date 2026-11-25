import EchoelCore
import XCTest
@testable import EchoelHost

/// The sentence a plugin's page shows when its settings did not reach the song.
final class PluginSaveProblemTests: XCTestCase {
    func testSettingsThatWereReadClearAnEarlierSentence() {
        XCTAssertEqual(PluginSaveProblem.verdict(for: .changed(Data([1])), name: "Ripple", isLoaded: true), .clear)
        XCTAssertEqual(PluginSaveProblem.verdict(for: .unchanged, name: "Ripple", isLoaded: true), .clear)
    }

    func testAUnitThatIsNotLoadedChangesNothingOnThePage() {
        XCTAssertEqual(PluginSaveProblem.verdict(for: .unavailable, name: "Ripple", isLoaded: false), .keep)
    }

    func testEachFailureNamesThePluginItsCauseAndWhatTheSongKeeps() {
        let cases: [(PluginStateCapture, String)] = [
            (.unavailable, "gave no settings to save"),
            (.notSerializable, "settings a song cannot hold"),
            (.tooLarge(byteCount: 9 * 1_048_576), "too large to save (9.0 MB, the limit is 8.0 MB)"),
        ]
        for (capture, cause) in cases {
            guard case .problem(let text) = PluginSaveProblem.verdict(for: capture, name: "Ripple", isLoaded: true) else {
                XCTFail("\(capture) said nothing")
                continue
            }
            XCTAssertTrue(text.hasPrefix("Ripple"), text)
            XCTAssertTrue(text.contains(cause), text)
            XCTAssertTrue(text.hasSuffix("The song keeps the settings saved before."), text)
        }
    }

    func testASongThatRefusesTheSettingsSaysWhyAndWhatItKeeps() {
        let text = PluginSaveProblem.refused(name: "Ripple", reason: "the track has no plugin")
        XCTAssertEqual(text, "The song did not take Ripple's settings (the track has no plugin). It keeps the settings saved before.")
    }

    func testSizesReadAsMegabytesWithOneDecimal() {
        XCTAssertEqual(PluginSaveProblem.megabytes(0), "0.0 MB")
        XCTAssertEqual(PluginSaveProblem.megabytes(1_048_576), "1.0 MB")
        XCTAssertEqual(PluginSaveProblem.megabytes(1_572_864), "1.5 MB")
        XCTAssertEqual(PluginSaveProblem.megabytes(PluginComponent.maximumStateBytes + 1), "8.0 MB")
    }
}
