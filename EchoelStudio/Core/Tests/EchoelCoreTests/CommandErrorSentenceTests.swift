import XCTest
@testable import EchoelCore

final class CommandErrorSentenceTests: XCTestCase {
    /// A refused edit is said in one sentence: a reason that reads alone as it is, one written
    /// against a parameter as "does not fit", a missing part as gone.
    func testARefusedEditIsSaidInOneSentence() {
        XCTAssertEqual(CommandError.invalidValue(parameter: "clip", reason: "an audio clip has no notes").sentence,
                       "Not done: an audio clip has no notes.")
        XCTAssertEqual(CommandError.invalidValue(parameter: "at", reason: "must fall inside the region").sentence,
                       "Not done: that does not fit here.")
        XCTAssertEqual(CommandError.invalidValue(parameter: "channel", reason: "0…14").sentence,
                       "Not done: that does not fit here.")
        XCTAssertEqual(CommandError.invalidValue(parameter: "name", reason: "  ").sentence,
                       "Not done: that does not fit here.")
        XCTAssertEqual(CommandError.unknownClip(ClipID()).sentence, "Not done: that part of the song is no longer there.")
        XCTAssertEqual(CommandError.duplicateID("x").sentence, "Not done: that is already in the song.")
    }
}
