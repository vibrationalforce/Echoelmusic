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

    func testAnotherSongDropsTheMoveAndNothingIsDueBeforeASong() {
        var file = SongFileName()
        XCTAssertFalse(file.isDue(for: "Anything"), "no song open, no package to follow")
        file.opened(named: "Beat")
        XCTAssertTrue(file.isDue(for: "Night"))
        file.opened(named: "Track")
        XCTAssertFalse(file.isDue(for: "Track"), "the next song's file name is its own")
    }
}
