import XCTest
@testable import EchoelEngine

final class PluginReloadNoticeTests: XCTestCase {
    private typealias Notice = PluginReloadNotice<Int, String>

    func testAReloadIsSaidOnlyOnceItHappened() {
        var notice = Notice()
        notice.stopped(1, name: "Alpha", component: "a", cause: .crash)
        XCTAssertNil(notice.text, "nothing is said at the stop: the unit has not come back yet")
        XCTAssertTrue(notice.isPending(1))
        notice.loaded(1)
        XCTAssertEqual(notice.text, "Alpha stopped and was loaded again with its last saved settings.")
        XCTAssertFalse(notice.isPending(1))
    }

    func testAReloadThatFailsSaysWhyInstead() {
        var notice = Notice()
        notice.stopped(1, name: "Alpha", component: "a", cause: .crash)
        notice.failed(1, reason: "Alpha is not installed on this device.")
        XCTAssertEqual(notice.text, "Alpha is not installed on this device.")
    }

    func testAUnitRefusedAtTheRestartLimitIsSaidAtOnce() {
        var notice = Notice()
        notice.refused(name: "Alpha", reason: "Alpha stopped working and was not loaded again.")
        XCTAssertEqual(notice.text, "Alpha stopped working and was not loaded again.")
    }

    func testAFailureStandsBesideTheReloadsOfTheSameReset() {
        var notice = Notice()
        notice.stopped(1, name: "Alpha", component: "a", cause: .reset)
        notice.stopped(2, name: "Beta", component: "b", cause: .reset)
        notice.failed(1, reason: "Alpha cannot play in stereo at this rate.")
        notice.loaded(2)
        XCTAssertEqual(notice.text, "Alpha cannot play in stereo at this rate. "
                       + "Beta was loaded again after an audio reset, with its last saved settings.")
    }

    func testAResetNamesTheUnitsThatCameBackSoFar() {
        var notice = Notice()
        notice.stopped(1, name: "Alpha", component: "a", cause: .reset)
        notice.stopped(2, name: "Beta", component: "b", cause: .reset)
        notice.loaded(1)
        XCTAssertEqual(notice.text, "Alpha was loaded again after an audio reset, with its last saved settings.",
                       "a reset that is half done does not claim the plugins all came back")
        notice.loaded(2)
        XCTAssertEqual(notice.text, "Alpha and Beta were loaded again after an audio reset, with their last saved settings.")
    }

    func testAfterTheLineIsClearedOnlyWhatHappensNextIsSaid() {
        var notice = Notice()
        notice.stopped(1, name: "Alpha", component: "a", cause: .reset)
        notice.stopped(2, name: "Beta", component: "b", cause: .reset)
        notice.failed(1, reason: "Alpha cannot play in stereo at this rate.")
        notice.clear()
        XCTAssertNil(notice.text)
        notice.loaded(2)
        XCTAssertEqual(notice.text, "Beta was loaded again after an audio reset, with its last saved settings.",
                       "the sentence names Beta only, so it says nothing false about Alpha")
    }

    func testSeveralFailuresAreAllNamed() {
        var notice = Notice()
        notice.stopped(1, name: "Alpha", component: "a", cause: .reset)
        notice.stopped(2, name: "Beta", component: "b", cause: .reset)
        notice.failed(1, reason: "Alpha cannot play in stereo at this rate.")
        notice.failed(2, reason: "Beta is not installed on this device.")
        XCTAssertEqual(notice.text, "Alpha and Beta did not load again; their pages say why.")
    }

    func testASlotThatNowWantsAnotherPluginSaysNothing() {
        var notice = Notice()
        notice.stopped(1, name: "Alpha", component: "a", cause: .crash)
        notice.keep { _, component in component == "b" }
        XCTAssertFalse(notice.isPending(1))
        notice.loaded(1)
        XCTAssertNil(notice.text, "the plugin that loads now never stopped")
    }

    func testAReloadForANewRateIsSaidOnlyWhenItFails() {
        var notice = Notice()
        notice.stopped(1, name: "Alpha", component: "a", cause: .rate)
        notice.loaded(1)
        XCTAssertNil(notice.text)
        notice.stopped(2, name: "Beta", component: "b", cause: .rate)
        notice.failed(2, reason: "Beta cannot play in stereo at this rate.")
        XCTAssertEqual(notice.text, "Beta cannot play in stereo at this rate.")
    }

    func testAnAnswerForASlotThatIsNotWaitingChangesNothing() {
        var notice = Notice()
        notice.loaded(9)
        notice.failed(9, reason: "Nine is not installed on this device.")
        XCTAssertNil(notice.text)
    }

    func testNamesReadAsAListAndTwoCopiesAreOneName() {
        XCTAssertEqual(Notice.list([]), "")
        XCTAssertEqual(Notice.list(["Alpha"]), "Alpha")
        XCTAssertEqual(Notice.list(["Alpha", "Beta", "Gamma"]), "Alpha, Beta and Gamma")
        var notice = Notice()
        notice.stopped(1, name: "Alpha", component: "a", cause: .crash)
        notice.stopped(2, name: "Alpha", component: "a", cause: .crash)
        notice.loaded(1)
        notice.loaded(2)
        XCTAssertEqual(notice.text, "Alpha stopped and was loaded again with its last saved settings.")
    }
}
