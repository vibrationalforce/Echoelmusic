import EchoelCore
import XCTest

final class EarlierSongImportTests: XCTestCase {
    /// What the next launch reads back: the app keeps exactly these values, so a state that
    /// survives this survives the app ending.
    private func relaunched(_ state: EarlierSongImport) -> EarlierSongImport {
        EarlierSongImport(isFinished: state.isFinished, done: Array(state.done), attempts: state.attempts,
                          isRunning: state.isRunning, current: state.current, suspect: state.suspect)
    }

    /// The keys of three songs as a run finds them: the earlier app's open song, then its library.
    private let three = ["t-open", "r-one", "r-two"]

    func testARunBringsEverySongOverAndFinishes() {
        var state = EarlierSongImport()
        XCTAssertNil(state.launchBegan(), "nothing was under way")
        XCTAssertTrue(state.runBegan())
        XCTAssertFalse(state.runBegan(), "one run at a time")
        let songs = state.found(three, sawEverything: true)
        XCTAssertEqual(songs, three)
        for song in songs {
            state.willBring(song)
            XCTAssertEqual(state.current, song)
            state.brought(song, song == "r-one" ? .unreadable : .written)
        }
        state.runEnded()
        XCTAssertTrue(state.isFinished, "an unreadable song is left out, not tried for ever")
        XCTAssertFalse(state.isRunning)
        XCTAssertFalse(state.runBegan(), "a finished import never runs again")
        var next = relaunched(state)
        XCTAssertFalse(next.runBegan())
    }

    func testFindingNothingNeverFinishesTheImport() {
        // A build without the App Group cannot see the earlier app's container: it finds no song.
        // Marking that run done would stop a later build with the group from ever looking.
        var state = EarlierSongImport()
        for _ in 0..<10 {
            XCTAssertTrue(state.runBegan())
            XCTAssertEqual(state.found([], sawEverything: true), [])
            state.runEnded()
            XCTAssertFalse(state.isFinished)
            XCTAssertFalse(state.isRunning)
            XCTAssertEqual(state.attempts, 0, "looking and finding nothing is not a failed run")
            state = relaunched(state)
            XCTAssertNil(state.launchBegan())
        }
    }

    func testARunThatCouldNotSeeEverythingNeverFinishes() {
        // The App Group container was not visible, or a file there could not be read this time:
        // what the run saw comes over, and the next start looks again (review 2026-10-22).
        var state = EarlierSongImport()
        _ = state.runBegan()
        XCTAssertEqual(state.found(["r-one"], sawEverything: false), ["r-one"])
        state.brought("r-one", .written)
        state.runEnded()
        XCTAssertFalse(state.isFinished)
        state = relaunched(state)
        _ = state.runBegan()
        XCTAssertEqual(state.found(["r-one"], sawEverything: false), [], "what came over is passed")
        XCTAssertFalse(state.isFinished)
        XCTAssertFalse(state.isRunning)
        XCTAssertEqual(state.attempts, 0)
        state = relaunched(state)
        _ = state.runBegan()
        XCTAssertEqual(state.found(["r-one", "r-two"], sawEverything: true), ["r-two"],
                       "the song that could not be seen before comes over")
        state.brought("r-two", .written)
        state.runEnded()
        XCTAssertTrue(state.isFinished)
    }

    func testASongIsNamedByItsKeyWhereverItSits() {
        // The earlier app ran again and saved a song ahead of the two already brought over: a
        // place number would now name the wrong songs (review 2026-10-22).
        var state = EarlierSongImport()
        _ = state.runBegan()
        _ = state.found(["r-one", "r-two", "r-three"], sawEverything: true)
        state.brought("r-one", .written)
        state.brought("r-two", .written)
        state.runPaused()
        state = relaunched(state)
        _ = state.runBegan()
        XCTAssertEqual(state.found(["r-new", "r-one", "r-two", "r-three"], sawEverything: true), ["r-new", "r-three"])
    }

    func testASongFoundTwiceIsBroughtOverOnce() {
        // The same song in the App Group container and in Application Support.
        var state = EarlierSongImport()
        _ = state.runBegan()
        XCTAssertEqual(state.found(["t-open", "r-one", "r-one", "", "t-open"], sawEverything: true), ["t-open", "r-one"])
    }

    func testSongsThatCouldNotBeWrittenAreTriedAgainAtEveryStart() {
        // A full disk. Each run ends without the app ending, so none counts toward giving up,
        // and space freed later still brings the songs over (review 2026-10-22).
        var state = EarlierSongImport()
        for run in 1...(EarlierSongImport.attemptLimit + 2) {
            XCTAssertTrue(state.runBegan(), "run \(run)")
            XCTAssertEqual(state.found(["r-one", "r-two"], sawEverything: true), ["r-one", "r-two"])
            state.brought("r-one", .failed)
            state.brought("r-two", .failed)
            state.runEnded()
            XCTAssertFalse(state.isFinished, "run \(run)")
            XCTAssertEqual(state.attempts, 0)
            state = relaunched(state)
            XCTAssertNil(state.launchBegan())
        }
        _ = state.runBegan()
        _ = state.found(["r-one", "r-two"], sawEverything: true)
        state.brought("r-one", .written)
        state.brought("r-two", .written)
        state.runEnded()
        XCTAssertTrue(state.isFinished)
    }

    func testARunThatBringsASongOverStartsTheCountAnew() {
        var state = EarlierSongImport(attempts: 2)
        _ = state.runBegan()
        _ = state.found(three, sawEverything: true)
        state.brought("t-open", .failed)
        state.brought("r-one", .written)
        XCTAssertEqual(state.attempts, 0, "a song came over")
        state.willBring("r-two")
        // The app ends here.
        state = relaunched(state)
        XCTAssertEqual(state.launchBegan(), .resumes)
        _ = state.runBegan()
        XCTAssertEqual(state.found(three, sawEverything: true), ["t-open", "r-two"], "what was written is passed")
    }

    func testARunTheAppEndsGoesOnPastWhatItWrote() {
        var state = EarlierSongImport()
        _ = state.runBegan()
        _ = state.found(three, sawEverything: true)
        state.willBring("t-open")
        state.brought("t-open", .written)
        state.willBring("r-one")
        // The app ends here — a crash, or swiped away: a run is still marked as under way.
        state = relaunched(state)
        XCTAssertTrue(state.isRunning)
        XCTAssertEqual(state.launchBegan(), .resumes)
        XCTAssertFalse(state.isRunning)
        XCTAssertNil(state.current)
        XCTAssertEqual(state.suspect, "r-one")
        XCTAssertNil(state.launchBegan(), "said once")
        XCTAssertTrue(state.runBegan())
        XCTAssertEqual(state.found(three, sawEverything: true), ["r-one", "r-two"])
        state.willBring("r-one")
        state.brought("r-one", .written)
        XCTAssertNil(state.suspect, "the song came over this time")
    }

    func testASongWrittenJustBeforeTheAppEndedIsMarkedAndNotBroughtAgain() {
        // The song's package was written, and the app ended before its mark was kept. The next
        // launch finds the written package and marks the song before it judges the run: it comes
        // over once, and it is not called left out although it ended a run before (review
        // 2026-10-22).
        var state = EarlierSongImport(suspect: "r-one")
        _ = state.runBegan()
        _ = state.found(three, sawEverything: true)
        state.willBring("r-one")
        state = relaunched(state)
        state.brought("r-one", .written)
        XCTAssertEqual(state.launchBegan(), .resumes)
        XCTAssertNil(state.suspect)
        XCTAssertNil(state.current)
        _ = state.runBegan()
        XCTAssertEqual(state.found(three, sawEverything: true), ["t-open", "r-two"])
    }

    func testEndingTwiceOnOneSongLeavesItOut() {
        var state = EarlierSongImport()
        for expected in [EarlierSongImport.Interruption.resumes, .leftOut] {
            _ = state.runBegan()
            _ = state.found(three, sawEverything: true)
            state.willBring("r-one")
            state = relaunched(state)
            XCTAssertEqual(state.launchBegan(), expected)
        }
        XCTAssertNil(state.suspect)
        _ = state.runBegan()
        XCTAssertEqual(state.found(three, sawEverything: true), ["t-open", "r-two"],
                       "the song that ended the app twice is left out")
        state.brought("t-open", .written)
        state.brought("r-two", .written)
        state.runEnded()
        XCTAssertTrue(state.isFinished)
    }

    func testEndingWhileTheFilesAreReadIsTriedAgainUpToTheLimit() {
        // The app ends before any song is under way. A swipe-away goes on; reading the earlier
        // app's files may also be what ends it, so it is not tried for ever.
        var state = EarlierSongImport()
        for run in 1...EarlierSongImport.attemptLimit {
            XCTAssertTrue(state.runBegan(), "run \(run)")
            state = relaunched(state)
            XCTAssertEqual(state.launchBegan(), run < EarlierSongImport.attemptLimit ? .resumes : .givenUp)
        }
        XCTAssertTrue(state.isFinished)
        XCTAssertFalse(state.runBegan())
    }

    func testOnlyRunsTheAppEndsCountTowardGivingUp() {
        // Runs the app ends, then one that ends on its own with a song it could not write: the
        // count starts anew, so the limit is runs ended in the middle in a row.
        var state = EarlierSongImport()
        for _ in 1..<EarlierSongImport.attemptLimit {
            _ = state.runBegan()
            state = relaunched(state)
            XCTAssertEqual(state.launchBegan(), .resumes)
        }
        _ = state.runBegan()
        _ = state.found(["r-one"], sawEverything: true)
        state.brought("r-one", .failed)
        state.runEnded()
        XCTAssertEqual(state.attempts, 0)
        state = relaunched(state)
        _ = state.runBegan()
        state = relaunched(state)
        XCTAssertEqual(state.launchBegan(), .resumes, "one run ended in the middle since the last that ended")
        XCTAssertFalse(state.isFinished)
    }

    func testEndingBetweenTwoSongsGoesOn() {
        var state = EarlierSongImport()
        _ = state.runBegan()
        XCTAssertEqual(state.found(three, sawEverything: true), three)
        state.willBring("t-open")
        state.brought("t-open", .written)
        // The app ends after one song was recorded and before the next is under way.
        state = relaunched(state)
        XCTAssertTrue(state.isRunning)
        XCTAssertNil(state.current)
        XCTAssertEqual(state.launchBegan(), .resumes)
        XCTAssertNil(state.suspect, "no song was under way, so none is suspected")
        _ = state.runBegan()
        XCTAssertEqual(state.found(three, sawEverything: true), ["r-one", "r-two"])
    }

    func testFindingNothingStaysOpenThroughEnds() {
        // Nothing is found, so the import stays open for a later build; a run that is ended now
        // and then while it looks must not close it.
        var state = EarlierSongImport()
        for _ in 0..<5 {
            _ = state.runBegan()
            state = relaunched(state)
            XCTAssertEqual(state.launchBegan(), .resumes)
            _ = state.runBegan()
            XCTAssertEqual(state.found([], sawEverything: true), [])
            XCTAssertEqual(state.attempts, 0)
            state = relaunched(state)
            XCTAssertNil(state.launchBegan())
        }
        XCTAssertFalse(state.isFinished)
    }

    func testAPauseGoesOnWhereItStoppedAndDoesNotCount() {
        var state = EarlierSongImport(attempts: 1)
        _ = state.runBegan()
        XCTAssertEqual(state.attempts, 2)
        _ = state.found(three, sawEverything: true)
        state.willBring("t-open")
        state.brought("t-open", .failed)
        state.runPaused()
        XCTAssertFalse(state.isRunning)
        XCTAssertNil(state.current)
        XCTAssertEqual(state.attempts, 1, "a pause is not a failed run")
        state = relaunched(state)
        XCTAssertNil(state.launchBegan(), "a paused run was not under way when the app ended")
        _ = state.runBegan()
        XCTAssertEqual(state.found(three, sawEverything: true), three, "the failed song is tried again")
        state.brought("t-open", .written)
        state.runPaused()
        XCTAssertEqual(state.attempts, 0, "a song came over before the pause")
        _ = state.runBegan()
        XCTAssertEqual(state.found(three, sawEverything: true), ["r-one", "r-two"])
    }

    func testAFinishedImportStaysFinishedWhateverWasLeftMarked() {
        var state = EarlierSongImport(isFinished: true, isRunning: true, current: "r-two")
        XCTAssertNil(state.launchBegan())
        XCTAssertFalse(state.isRunning)
        XCTAssertFalse(state.runBegan())
        XCTAssertEqual(state.found(three, sawEverything: true), [])
    }

    func testARunWhoseSongsAreAllDoneFinishes() {
        // The app ended after the last song was recorded but before the run was marked ended.
        var state = EarlierSongImport(done: ["r-one", "r-two"], isRunning: true)
        XCTAssertEqual(state.launchBegan(), .resumes)
        XCTAssertTrue(state.runBegan())
        XCTAssertEqual(state.found(["r-one", "r-two"], sawEverything: true), [])
        XCTAssertTrue(state.isFinished)
        XCTAssertFalse(state.isRunning)
    }

    func testStoredValuesOutOfRangeAreIgnored() {
        let state = EarlierSongImport(done: ["", "r-two"], attempts: -4, current: "", suspect: "")
        XCTAssertEqual(state.done, ["r-two"])
        XCTAssertEqual(state.attempts, 0)
        XCTAssertNil(state.current)
        XCTAssertNil(state.suspect)
    }
}
