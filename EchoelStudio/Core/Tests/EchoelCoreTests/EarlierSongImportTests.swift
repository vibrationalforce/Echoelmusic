import EchoelCore
import XCTest

final class EarlierSongImportTests: XCTestCase {
    /// What the next launch reads back: the app keeps exactly these values, so a state that
    /// survives this survives the app ending.
    private func relaunched(_ state: EarlierSongImport) -> EarlierSongImport {
        EarlierSongImport(isFinished: state.isFinished, done: Array(state.done), attempts: state.attempts,
                          isRunning: state.isRunning, current: state.current, suspect: state.suspect)
    }

    func testARunBringsEverySongOverAndFinishes() {
        var state = EarlierSongImport()
        XCTAssertNil(state.launchBegan(), "nothing was under way")
        XCTAssertTrue(state.runBegan())
        XCTAssertFalse(state.runBegan(), "one run at a time")
        let places = state.found(3)
        XCTAssertEqual(places, [0, 1, 2])
        for place in places {
            state.willBring(place)
            XCTAssertEqual(state.current, place)
            state.brought(place, place == 1 ? .unreadable : .written)
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
            XCTAssertEqual(state.found(0), [])
            state.runEnded()
            XCTAssertFalse(state.isFinished)
            XCTAssertFalse(state.isRunning)
            XCTAssertEqual(state.attempts, 0, "looking and finding nothing is not a failed run")
            state = relaunched(state)
            XCTAssertNil(state.launchBegan())
        }
    }

    func testARunWithFailuresIsRetriedAndGivenUpAfterTheLimit() {
        var state = EarlierSongImport()
        for run in 1...EarlierSongImport.attemptLimit {
            XCTAssertTrue(state.runBegan(), "run \(run)")
            XCTAssertEqual(state.found(2), [0, 1])
            state.brought(0, .failed)
            state.brought(1, .failed)
            state.runEnded()
            XCTAssertEqual(state.isFinished, run == EarlierSongImport.attemptLimit,
                           "a full disk is tried again a few times, then given up")
            state = relaunched(state)
        }
    }

    func testARunThatBringsASongOverStartsTheCountAnew() {
        var state = EarlierSongImport()
        _ = state.runBegan()
        _ = state.found(3)
        state.brought(0, .failed)
        state.brought(1, .failed)
        state.brought(2, .written)
        state.runEnded()
        XCTAssertFalse(state.isFinished)
        XCTAssertEqual(state.attempts, 0)
        state = relaunched(state)
        _ = state.runBegan()
        XCTAssertEqual(state.found(3), [0, 1], "what was written is passed")
    }

    func testARunTheAppEndsGoesOnPastWhatItWrote() {
        var state = EarlierSongImport()
        _ = state.runBegan()
        _ = state.found(3)
        state.willBring(0)
        state.brought(0, .written)
        state.willBring(1)
        // The app ends here — a crash, or swiped away: a run is still marked as under way.
        state = relaunched(state)
        XCTAssertTrue(state.isRunning)
        XCTAssertEqual(state.launchBegan(), .resumes)
        XCTAssertFalse(state.isRunning)
        XCTAssertNil(state.current)
        XCTAssertEqual(state.suspect, 1)
        XCTAssertNil(state.launchBegan(), "said once")
        XCTAssertTrue(state.runBegan())
        XCTAssertEqual(state.found(3), [1, 2])
        state.willBring(1)
        state.brought(1, .written)
        XCTAssertNil(state.suspect, "the song came over this time")
    }

    func testEndingTwiceOnOneSongLeavesItOut() {
        var state = EarlierSongImport()
        for expected in [EarlierSongImport.Interruption.resumes, .leftOut] {
            _ = state.runBegan()
            _ = state.found(3)
            state.willBring(1)
            state = relaunched(state)
            XCTAssertEqual(state.launchBegan(), expected)
        }
        XCTAssertNil(state.suspect)
        _ = state.runBegan()
        XCTAssertEqual(state.found(3), [0, 2], "the song that ended the app twice is left out")
        state.brought(0, .written)
        state.brought(2, .written)
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

    func testEndingBetweenTwoSongsGoesOn() {
        var state = EarlierSongImport()
        _ = state.runBegan()
        XCTAssertEqual(state.found(3), [0, 1, 2])
        state.willBring(0)
        state.brought(0, .written)
        // The app ends after one song was recorded and before the next is under way.
        state = relaunched(state)
        XCTAssertTrue(state.isRunning)
        XCTAssertNil(state.current)
        XCTAssertEqual(state.launchBegan(), .resumes)
        XCTAssertNil(state.suspect, "no song was under way, so none is suspected")
        _ = state.runBegan()
        XCTAssertEqual(state.found(3), [1, 2])
    }

    func testAPlaceThatHoldsNothingReadableStaysOpenThroughEnds() {
        // Nothing is readable here, so the import stays open for a later build; a run that is
        // ended now and then while it looks must not close it.
        var state = EarlierSongImport()
        for _ in 0..<5 {
            _ = state.runBegan()
            state = relaunched(state)
            XCTAssertEqual(state.launchBegan(), .resumes)
            _ = state.runBegan()
            XCTAssertEqual(state.found(0), [])
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
        _ = state.found(3)
        state.willBring(0)
        state.brought(0, .failed)
        state.runPaused()
        XCTAssertFalse(state.isRunning)
        XCTAssertNil(state.current)
        XCTAssertEqual(state.attempts, 1, "a pause is not a failed run")
        state = relaunched(state)
        XCTAssertNil(state.launchBegan(), "a paused run was not under way when the app ended")
        _ = state.runBegan()
        XCTAssertEqual(state.found(3), [0, 1, 2], "the failed song is tried again")
        state.brought(0, .written)
        state.runPaused()
        XCTAssertEqual(state.attempts, 0, "a song came over before the pause")
        _ = state.runBegan()
        XCTAssertEqual(state.found(3), [1, 2])
    }

    func testEndingOnTheLastAllowedRunGivesTheImportUp() {
        var state = EarlierSongImport()
        for _ in 1..<EarlierSongImport.attemptLimit {
            _ = state.runBegan()
            _ = state.found(2)
            state.brought(0, .failed)
            state.brought(1, .failed)
            state.runEnded()
        }
        XCTAssertFalse(state.isFinished)
        _ = state.runBegan()
        _ = state.found(2)
        state.willBring(0)
        state = relaunched(state)
        XCTAssertEqual(state.launchBegan(), .givenUp, "there is no next run to promise")
        XCTAssertTrue(state.isFinished)
    }

    func testAFinishedImportStaysFinishedWhateverWasLeftMarked() {
        var state = EarlierSongImport(isFinished: true, isRunning: true, current: 2)
        XCTAssertNil(state.launchBegan())
        XCTAssertFalse(state.isRunning)
        XCTAssertFalse(state.runBegan())
        XCTAssertEqual(state.found(4), [])
    }

    func testARunWhoseSongsAreAllDoneFinishes() {
        // The app ended after the last song was recorded but before the run was marked ended.
        var state = EarlierSongImport(done: [0, 1], isRunning: true)
        XCTAssertEqual(state.launchBegan(), .resumes)
        XCTAssertTrue(state.runBegan())
        XCTAssertEqual(state.found(2), [])
        XCTAssertTrue(state.isFinished)
        XCTAssertFalse(state.isRunning)
    }

    func testStoredValuesOutOfRangeAreIgnored() {
        let state = EarlierSongImport(done: [-1, 2], attempts: -4, current: -3, suspect: -1)
        XCTAssertEqual(state.done, [2])
        XCTAssertEqual(state.attempts, 0)
        XCTAssertNil(state.current)
        XCTAssertNil(state.suspect)
    }
}
