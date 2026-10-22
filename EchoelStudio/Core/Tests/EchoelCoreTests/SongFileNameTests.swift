import XCTest
@testable import EchoelCore

/// The package follows a change of the song's own name, at a write while nothing holds it.
final class SongFileNameTests: XCTestCase {
    func testAChangedNameIsDueAndMovesOnceAtAQuietWrite() {
        var file = SongFileName()
        file.opened(named: "Beat")
        XCTAssertFalse(file.isDue(for: "Beat"), "the name it opened with is the one the package has")
        XCTAssertTrue(file.isDue(for: "Night"))
        XCTAssertTrue(file.shouldMove(for: "Night", busy: false))
        file.followed("Night")
        XCTAssertFalse(file.shouldMove(for: "Night", busy: false), "moved once, not on every write")
    }

    func testAMoveWaitsWhileThePackageIsBusy() {
        var file = SongFileName()
        file.opened(named: "Beat")
        XCTAssertFalse(file.shouldMove(for: "Night", busy: true), "an import or a take holds the package")
        XCTAssertTrue(file.isDue(for: "Night"), "and the move is still owed")
        XCTAssertTrue(file.shouldMove(for: "Night", busy: false), "the first quiet write does it")
    }

    func testAnUndoBackToTheFollowedNameLeavesNothingToDo() {
        var file = SongFileName()
        file.opened(named: "Beat")
        XCTAssertTrue(file.isDue(for: "Night"))
        XCTAssertFalse(file.shouldMove(for: "Beat", busy: false), "renamed and undone before the move")
        file.followed("Night")
        XCTAssertTrue(file.shouldMove(for: "Beat", busy: false), "an Undo after the move moves it back")
    }

    /// A package left under a name in between follows no name: every name is due, the one it
    /// followed too, so an Undo back to that name still moves the package home.
    func testAStrandedPackageIsOwedEvenUnderItsOldName() {
        var file = SongFileName()
        file.opened(named: "beat")
        file.stranded()
        XCTAssertTrue(file.isDue(for: "beat"), "an Undo back to the old name still owes the move")
        XCTAssertTrue(file.isDue(for: "Beat"))
        XCTAssertFalse(file.shouldMove(for: "beat", busy: true), "it still waits while the package is busy")
        XCTAssertTrue(file.shouldMove(for: "beat", busy: false))
        file.followed("beat")
        XCTAssertFalse(file.isDue(for: "beat"), "home again, nothing owed")
        file.stranded()
        file.opened(named: "Track")
        XCTAssertFalse(file.isDue(for: "Track"), "another song's package is its own")
    }

    func testAnotherSongDropsTheMoveAndNothingIsDueBeforeASong() {
        var file = SongFileName()
        XCTAssertFalse(file.isDue(for: "Anything"), "no song open, no package to follow")
        file.opened(named: "Beat")
        XCTAssertTrue(file.isDue(for: "Night"))
        file.opened(named: "Track")
        XCTAssertFalse(file.isDue(for: "Track"), "the next song's file name is its own")
    }
}
