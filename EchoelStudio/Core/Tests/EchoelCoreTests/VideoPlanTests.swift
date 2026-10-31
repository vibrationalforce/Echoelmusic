import Foundation
import XCTest
@testable import EchoelCore

/// What the video tracks show at each moment of the song clock, how a drifting player is brought
/// back, and what a video export cuts and how loud it plays (wave W7, C3/C6).
final class VideoPlanTests: XCTestCase {
    private let first = MediaFile(name: "Take A", path: "Media/a.mov", frameCount: 480_000, sampleRate: 48_000, kind: .video)
    private let second = MediaFile(name: "Take B", path: "Media/b.mov", frameCount: 960_000, sampleRate: 48_000, kind: .video)
    private let top = TrackID(), below = TrackID()
    private let shotA = RegionID(), shotB = RegionID()

    /// At 120 BPM in 4/4 a bar is 3 840 ticks and two seconds. Take A (10 s) on the top track from
    /// bar 1, take B (20 s) on the track below from bar 1.
    private func song() throws -> Project {
        var project = Project()
        try Command.addTrack(id: top, name: "Video 1", kind: .video, index: nil).apply(to: &project)
        try Command.addTrack(id: below, name: "Video 2", kind: .video, index: nil).apply(to: &project)
        try Command.addMedia(first).apply(to: &project)
        try Command.addMedia(second).apply(to: &project)
        try Command.placeVideo(track: top, id: shotA, media: first.id, start: 0).apply(to: &project)
        try Command.placeVideo(track: below, id: shotB, media: second.id, start: 0).apply(to: &project)
        return project
    }

    func testTheTopTrackShowsAndTheOneBelowShowsThroughItsGaps() throws {
        let project = try song()
        XCTAssertEqual(VideoPlan.shot(in: project, at: 0)?.region, shotA)
        XCTAssertEqual(try XCTUnwrap(VideoPlan.shot(in: project, at: 3_840)).fileSeconds, 2, accuracy: 1e-9)
        let later = try XCTUnwrap(VideoPlan.shot(in: project, at: 12 * 1_920))
        XCTAssertEqual(later.region, shotB, "take A ended at ten seconds")
        XCTAssertEqual(later.fileSeconds, 12, accuracy: 1e-9)
        XCTAssertNil(VideoPlan.shot(in: project, at: 21 * 1_920), "past both takes")
        XCTAssertNil(VideoPlan.shot(in: project, at: .nan))

        var muted = project
        try Command.setMute(top, true).apply(to: &muted)
        XCTAssertEqual(VideoPlan.shot(in: muted, at: 0)?.region, shotB, "a muted video track shows nothing")
    }

    func testWithinATrackThePartThatStartsLaterShows() throws {
        var project = try song()
        let late = RegionID()
        try Command.placeVideo(track: top, id: late, media: second.id, start: 3_840).apply(to: &project)
        XCTAssertEqual(VideoPlan.shot(in: project, at: 1_000)?.region, shotA)
        let shot = try XCTUnwrap(VideoPlan.shot(in: project, at: 3_840 + 1_920))
        XCTAssertEqual(shot.region, late)
        XCTAssertEqual(shot.fileSeconds, 1, accuracy: 1e-9)
    }

    func testAPartPlaysAtItsFilesOwnSpeedUnderATempoChange() throws {
        var project = try song()
        try Command.setTempoChange(at: 1_920, bpm: 60).apply(to: &project)
        // One second at 120, then 960 ticks at 60 is one more second.
        XCTAssertEqual(try XCTUnwrap(VideoPlan.shot(in: project, at: 2_880)).fileSeconds, 2, accuracy: 1e-9)
    }

    func testDriftIsHeldNudgedOrSoughtAndTheNudgeStartsAtZero() {
        XCTAssertEqual(VideoPlan.correction(expected: 5, observed: 5.02), .hold)
        guard case .nudge(let ahead) = VideoPlan.correction(expected: 5, observed: 5 + VideoPlan.deadbandSeconds + 0.02) else {
            return XCTFail("a small drift is slewed")
        }
        XCTAssertEqual(ahead, 0.99, accuracy: 1e-9, "a picture ahead slows down by the drift beyond the deadband")
        guard case .nudge(let behind) = VideoPlan.correction(expected: 5, observed: 5 - VideoPlan.deadbandSeconds - 0.02) else {
            return XCTFail("a small drift is slewed")
        }
        XCTAssertEqual(behind, 1.01, accuracy: 1e-9)
        guard case .nudge(let edge) = VideoPlan.correction(expected: 5, observed: 5 + VideoPlan.deadbandSeconds + 1e-6) else {
            return XCTFail("just past the deadband")
        }
        XCTAssertEqual(edge, 1, accuracy: 1e-5, "continuous with hold at the edge")
        guard case .nudge(let most) = VideoPlan.correction(expected: 5, observed: 5.2) else { return XCTFail("still slewed") }
        XCTAssertGreaterThanOrEqual(most, 1 - VideoPlan.maxSlew)
        XCTAssertEqual(VideoPlan.correction(expected: 5, observed: 6), .seek(toSeconds: 5))
        XCTAssertEqual(VideoPlan.correction(expected: 5, observed: .nan), .seek(toSeconds: 5))
        XCTAssertEqual(VideoPlan.correction(expected: .nan, observed: 5), .hold)
    }

    func testTheCutListFollowsWhatTheSongShows() throws {
        var project = try song()
        XCTAssertEqual(VideoPlan.program(of: project), [
            VideoPlan.Segment(region: shotA, media: first.id, fileSeconds: 0, songSeconds: 0, duration: 10),
            VideoPlan.Segment(region: shotB, media: second.id, fileSeconds: 10, songSeconds: 10, duration: 10),
        ])
        XCTAssertEqual(VideoPlan.programEnd(of: project), 20)

        // A cut on the top track at bar 2 and its second half removed: take B shows through.
        let tail = RegionID()
        try Command.splitRegion(track: top, shotA, at: 3_840, newID: tail).apply(to: &project)
        try Command.removeRegion(track: top, tail).apply(to: &project)
        let cut = VideoPlan.program(of: project)
        XCTAssertEqual(cut.map(\.region), [shotA, shotB])
        XCTAssertEqual(cut.map(\.songSeconds), [0, 2])
        XCTAssertEqual(cut.map(\.fileSeconds), [0, 2])
        XCTAssertEqual(cut.map(\.duration), [2, 18])
        XCTAssertNotNil(project.mediaFile(first.id), "a cut leaves the take in the song")
    }

    func testAGapIsLeftOutAndALaterStartIsKept() throws {
        var project = try song()
        try Command.removeTrack(below).apply(to: &project)
        try Command.moveRegion(track: top, shotA, start: 7_680).apply(to: &project)
        XCTAssertNil(VideoPlan.shot(in: project, at: 0))
        XCTAssertEqual(VideoPlan.program(of: project),
                       [VideoPlan.Segment(region: shotA, media: first.id, fileSeconds: 0, songSeconds: 4, duration: 10)])
    }

    // MARK: - Export

    func testALongExportRunsAsLongAsTheLongerOfMixAndPicture() throws {
        let project = try song()
        XCTAssertEqual(VideoExportPlan.longFormSeconds(mixSeconds: 3, of: project), 20, "a short mix never cuts the picture")
        XCTAssertEqual(VideoExportPlan.longFormSeconds(mixSeconds: 45, of: project), 45, "a short picture never cuts the mix")
        XCTAssertEqual(VideoExportPlan.longFormSeconds(mixSeconds: .nan, of: Project()), 0)
    }

    func testAShortExportCoversWholeBarsNearItsLength() throws {
        let project = try song()
        XCTAssertEqual(VideoExportPlan.shortFormSeconds, [15, 30, 60, 90])
        XCTAssertEqual(VideoExportPlan.shortRange(in: project, startBar: 1, seconds: 15), 0...30_720, "7.5 bars round to 8")
        XCTAssertEqual(VideoExportPlan.shortRange(in: project, startBar: 3, seconds: 30), 7_680...65_280, "15 bars")
        XCTAssertEqual(VideoExportPlan.shortRange(in: project, startBar: 1, seconds: 0.1), 0...3_840, "at least one bar")
        XCTAssertNil(VideoExportPlan.shortRange(in: project, startBar: 0, seconds: 15))
        XCTAssertNil(VideoExportPlan.shortRange(in: project, startBar: 1, seconds: .nan))
        let range = try XCTUnwrap(VideoExportPlan.shortRange(in: project, startBar: 1, seconds: 15))
        let seconds = VideoExportPlan.seconds(of: range, in: project)
        XCTAssertEqual(seconds.from, 0)
        XCTAssertEqual(seconds.to, 16)
    }

    func testAShortExportCutsTheProgramToItsStretchAndStartsAtZero() throws {
        let project = try song()
        let part = VideoExportPlan.program(of: project, from: 8, to: 12)
        XCTAssertEqual(part.map(\.region), [shotA, shotB])
        XCTAssertEqual(part.map(\.songSeconds), [0, 2])
        XCTAssertEqual(part.map(\.fileSeconds), [8, 10])
        XCTAssertEqual(part.map(\.duration), [2, 2])
        XCTAssertTrue(VideoExportPlan.program(of: project, from: 5, to: 5).isEmpty)
    }

    func testEveryShapeHasItsFrameAndAPictureFillsOrFitsWithoutLosingItsFile() throws {
        XCTAssertEqual(VideoExportPlan.Shape.allCases.map { "\($0.width)x\($0.height)" },
                       ["1080x1920", "1920x1080", "1080x1080", "1080x1350"])
        let fill = try XCTUnwrap(VideoExportPlan.placement(sourceWidth: 1_920, sourceHeight: 1_080, targetWidth: 1_080,
                                                           targetHeight: 1_920, fit: .fill))
        XCTAssertEqual(fill.scale, 1_920.0 / 1_080.0, accuracy: 1e-9)
        XCTAssertEqual(fill.x, (1_080 - 1_920 * fill.scale) / 2, accuracy: 1e-9)
        XCTAssertEqual(fill.y, 0, accuracy: 1e-9)
        let fit = try XCTUnwrap(VideoExportPlan.placement(sourceWidth: 1_920, sourceHeight: 1_080, targetWidth: 1_080,
                                                          targetHeight: 1_920, fit: .fit))
        XCTAssertEqual(fit.scale, 0.5625, accuracy: 1e-9)
        XCTAssertEqual(fit.x, 0, accuracy: 1e-9)
        XCTAssertEqual(fit.y, (1_920 - 1_080 * 0.5625) / 2, accuracy: 1e-9)
        XCTAssertNil(VideoExportPlan.placement(sourceWidth: 0, sourceHeight: 1, targetWidth: 1, targetHeight: 1, fit: .fit))
    }

    func testTheMixIsBroughtToSocialLoudnessUnderThePeakCeiling() {
        XCTAssertEqual(VideoExportPlan.socialLoudness, -14)
        XCTAssertEqual(VideoExportPlan.loudnessGain(integrated: -20, truePeak: -10), 6, accuracy: 1e-9)
        XCTAssertEqual(VideoExportPlan.loudnessGain(integrated: -20, truePeak: -6), 5, accuracy: 1e-9, "the peak would pass −1 dBTP")
        XCTAssertEqual(VideoExportPlan.loudnessGain(integrated: -10, truePeak: -3), -4, accuracy: 1e-9, "a loud mix is lowered")
        XCTAssertEqual(VideoExportPlan.loudnessGain(integrated: -.infinity, truePeak: -.infinity), 0, "silence is not raised")
        XCTAssertEqual(VideoExportPlan.loudnessGain(integrated: .nan, truePeak: 0), 0)
    }
}
