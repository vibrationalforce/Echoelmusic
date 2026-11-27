import XCTest
@testable import EchoelCore

final class SpokenTests: XCTestCase {
    func testAPanPositionIsSaidInWordsOnTheScreensRounding() {
        XCTAssertEqual(Spoken.pan(0), "Center")
        XCTAssertEqual(Spoken.pan(0.004), "Center", "the screen shows C here too")
        XCTAssertEqual(Spoken.pan(-0.2), "20 percent left")
        XCTAssertEqual(Spoken.pan(0.2), "20 percent right")
        XCTAssertEqual(Spoken.pan(-1), "100 percent left")
        XCTAssertEqual(Spoken.pan(1), "100 percent right")
        XCTAssertEqual(Spoken.pan(0.333), "33 percent right")
        XCTAssertEqual(Spoken.pan(.nan), "Center", "a value that is no number says nothing alarming")
        XCTAssertEqual(Spoken.pan(-.infinity), "Center")
    }

    func testAControllerIsSaidAsTheDeviceCountsIt() {
        XCTAssertEqual(Spoken.control(MIDIControl(channel: 0, number: 7)), "controller 7 on channel 1")
        XCTAssertEqual(Spoken.control(MIDIControl(channel: 15, number: 127)), "controller 127 on channel 16")
    }

    func testVoiceControlHearsWhatTheKeyShowsFirstThenTheSpokenName() {
        XCTAssertEqual(Spoken.voiceNames(shown: "M", word: "Mute", spoken: "Mute Lead"), ["M", "Mute", "Mute Lead"])
        XCTAssertEqual(Spoken.voiceNames(shown: "S", word: "Solo", spoken: "Solo Lead"), ["S", "Solo", "Solo Lead"])
        XCTAssertEqual(Spoken.voiceNames(shown: "MIDI", spoken: "MIDI Learn"), ["MIDI", "MIDI Learn"])
    }

    func testAVoiceControlNameIsNeverSaidTwiceAndNeverEmpty() {
        XCTAssertEqual(Spoken.voiceNames(shown: "MIDI", word: "midi", spoken: "MIDI Learn"), ["MIDI", "MIDI Learn"],
                       "one name, whatever its case")
        XCTAssertEqual(Spoken.voiceNames(shown: "", word: "Arm", spoken: "Arm Lead for Recording"),
                       ["Arm", "Arm Lead for Recording"], "a key that shows a symbol has no shown name")
        XCTAssertEqual(Spoken.voiceNames(shown: "  S ", word: "Solo", spoken: " Solo Lead "), ["S", "Solo", "Solo Lead"])
        XCTAssertEqual(Spoken.voiceNames(shown: "M", word: "Mute", spoken: "Mute "), ["M", "Mute"],
                       "a track without a name leaves the action's word")
        XCTAssertEqual(Spoken.voiceNames(shown: "", spoken: "   "), [String]())
    }

    func testTheSpokenNameStaysInTheListSoVoiceControlAndVoiceOverAgree() {
        let names = Spoken.voiceNames(shown: "M", word: "Mute", spoken: "Mute M")
        XCTAssertEqual(names.last, "Mute M", "a track named like the key keeps its whole spoken name")
        XCTAssertEqual(names.first, "M")
    }
}
