import XCTest
@testable import EchoelCore

final class AnnouncementTests: XCTestCase {
    private let quiet = StatusStrip()

    func testAnExportIsSaidWhenItStartsAndNotAtEachStep() {
        let started = StatusStrip(exportStep: "Exporting the song…")
        XCTAssertEqual(StatusStrip.announcement(from: quiet, to: started),
                       Announcement("Exporting the song…", priority: .normal))
        let stem1 = StatusStrip(exportStep: "Exporting stem 1 of 4…")
        let stem2 = StatusStrip(exportStep: "Exporting stem 2 of 4…")
        XCTAssertNil(StatusStrip.announcement(from: stem1, to: stem2), "a step is not news")
        XCTAssertNil(StatusStrip.announcement(from: started, to: stem1))
    }

    func testAFailedExportIsSaidOnceAndUrgently() {
        let running = StatusStrip(exportStep: "Exporting the song…")
        let failed = StatusStrip(documentError: "A plugin stopped rendering during the export.")
        let said = StatusStrip.announcement(from: running, to: failed)
        XCTAssertEqual(said, Announcement("A plugin stopped rendering during the export.", priority: .urgent),
                       "the end of the export and the new message are one thing, said once")
    }

    func testAFailureInTheSameWordsAsTheLastOneIsSaidAgain() {
        let message = "The song is longer than a WAV file can hold."
        let running = StatusStrip(documentError: message, exportStep: "Exporting the song…")
        let failedAgain = StatusStrip(documentError: message)
        XCTAssertEqual(StatusStrip.announcement(from: running, to: failedAgain),
                       Announcement(message, priority: .urgent))
    }

    func testAFinishedExportSaysItsLoudnessAfterWhatIsBeingSaid() {
        let running = StatusStrip(exportStep: "Writing the video…")
        let done = StatusStrip(exportResult: "Last export: -14.0 LUFS · -1.2 dBTP")
        XCTAssertEqual(StatusStrip.announcement(from: running, to: done),
                       Announcement("Last export: -14.0 LUFS · -1.2 dBTP", priority: .queued))
        XCTAssertNil(StatusStrip.announcement(from: running, to: quiet), "a share prepared quietly says nothing")
        XCTAssertNil(StatusStrip.announcement(from: quiet, to: done), "a result without an export is not news")
    }

    func testAProblemIsSaidUrgentlyAndOnlyWhenItArrives() {
        let unsaved = StatusStrip(saveError: "Could not save. Your changes are still open.")
        XCTAssertEqual(StatusStrip.announcement(from: quiet, to: unsaved)?.priority, .urgent)
        XCTAssertNil(StatusStrip.announcement(from: unsaved, to: unsaved), "a line that stands is not said again")
        XCTAssertNil(StatusStrip.announcement(from: unsaved, to: quiet), "a line that goes says nothing")
        let silent = StatusStrip(audioError: "Audio could not start.")
        XCTAssertEqual(StatusStrip.announcement(from: quiet, to: silent),
                       Announcement("Audio could not start.", priority: .urgent))
        let broken = StatusStrip(documentError: "Could not import the MIDI file.")
        let other = StatusStrip(documentError: "Could not rename the song.")
        XCTAssertEqual(StatusStrip.announcement(from: broken, to: other)?.text, "Could not rename the song.")
    }

    func testThingsThatArriveTogetherAreOneAnnouncementAtTheMostUrgentPriority() {
        let both = StatusStrip(saveError: "Could not save.", notice: "Paused: the headphones were disconnected.")
        XCTAssertEqual(StatusStrip.announcement(from: quiet, to: both),
                       Announcement("Could not save. Paused: the headphones were disconnected.", priority: .urgent))
        let standing = StatusStrip(saveError: "Could not save.")
        XCTAssertEqual(StatusStrip.announcement(from: standing, to: both),
                       Announcement("Paused: the headphones were disconnected.", priority: .normal),
                       "the standing line is not said again with the new one")
    }

    func testMIDILearnWaitsForWhatIsBeingSaid() {
        let learning = StatusStrip(learning: "MIDI Learn: tap a control.")
        XCTAssertEqual(StatusStrip.announcement(from: quiet, to: learning)?.priority, .queued)
        let target = StatusStrip(learning: "MIDI Learn: move a knob.")
        XCTAssertEqual(StatusStrip.announcement(from: learning, to: target)?.text, "MIDI Learn: move a knob.")
        XCTAssertNil(StatusStrip.announcement(from: target, to: quiet))
    }

    func testJoiningNothingSaysNothing() {
        XCTAssertNil(Announcement.joined([]))
        XCTAssertEqual(Announcement.joined([Announcement("One.", priority: .queued), Announcement("Two.", priority: .normal)]),
                       Announcement("One. Two.", priority: .normal))
    }
}
