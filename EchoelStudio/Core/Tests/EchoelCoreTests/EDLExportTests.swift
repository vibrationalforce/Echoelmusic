import Foundation
import XCTest
@testable import EchoelCore

/// The arrangement as a CMX 3600 edit decision list (PRO-W1 slice 5): the first way into Resolve.
final class EDLExportTests: XCTestCase {
    private let take = MediaFile(name: "Take 1", path: "Media/take.mov", frameCount: 480_000, sampleRate: 48_000,
                                 kind: .video)
    private let loop = MediaFile(name: "Loop", path: "Media/loop.wav", frameCount: 96_000, sampleRate: 48_000)
    private let bar = MusicalTime.ticksPerBar(.common)

    private func song() throws -> Project {
        var project = Project(name: "Night", tempo: 120)
        let video = TrackID(), drums = TrackID(), bass = TrackID()
        try Command.addTrack(id: video, name: "Video 1", kind: .video, index: nil).apply(to: &project)
        try Command.addTrack(id: drums, name: "Drums", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: bass, name: "Bass", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: TrackID(), name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.addMedia(take).apply(to: &project)
        try Command.addMedia(loop).apply(to: &project)
        let shot = RegionID()
        try Command.placeVideo(track: video, id: shot, media: take.id, start: 0).apply(to: &project)
        // From one second into the take (half a bar at 120), for its next four seconds.
        try Command.trimRegion(track: video, shot, offset: 48_000, length: 192_000).apply(to: &project)
        try Command.moveRegion(track: video, shot, start: bar).apply(to: &project)
        try Command.placeAudio(track: drums, id: RegionID(), media: loop.id, start: bar).apply(to: &project)
        try Command.placeAudio(track: bass, id: RegionID(), media: loop.id, start: 0).apply(to: &project)
        try Command.addMarker(at: 2 * bar, name: "Drop").apply(to: &project)
        return project
    }

    func testEachRegionIsOneEventWithItsSourceAndRecordTimecode() throws {
        let events = EDLExport.events(for: try song(), rate: .fps25)
        XCTAssertEqual(events.map(\.number), [1, 2, 3])
        XCTAssertEqual(events.map(\.channel), ["A2", "V", "A"], "record order, video first at one time, A2 for the second audio track")
        let hour = 3_600 * 25
        // Bass loop at bar 1: two seconds of file.
        XCTAssertEqual(events[0].sourceIn, 0)
        XCTAssertEqual(events[0].recordIn, hour)
        XCTAssertEqual(events[0].recordOut, hour + 50)
        // The video from one second into the take, at bar 2 (two seconds in), for four seconds.
        XCTAssertEqual(events[1].sourceIn, 25)
        XCTAssertEqual(events[1].sourceOut, 125)
        XCTAssertEqual(events[1].recordIn, hour + 50)
        XCTAssertEqual(events[1].recordOut, hour + 150)
        XCTAssertEqual(events[1].clipName, "Take 1")
    }

    func testTheTextIsCMX3600() throws {
        let text = EDLExport.text(for: try song(), title: "Night", rate: .fps25,
                                  fileNames: [take.id: "Take 1.mov"])
        let lines = text.components(separatedBy: "\r\n")
        XCTAssertEqual(lines[0], "TITLE: Night")
        XCTAssertEqual(lines[1], "FCM: NON-DROP FRAME")
        XCTAssertTrue(lines.contains("002  AX       V     C        00:00:01:00 00:00:05:00 01:00:02:00 01:00:06:00"))
        XCTAssertTrue(lines.contains("001  AX       A2    C        00:00:00:00 00:00:02:00 01:00:00:00 01:00:02:00"))
        XCTAssertTrue(lines.contains("* FROM CLIP NAME: Take 1"))
        XCTAssertTrue(lines.contains("* SOURCE FILE: Take 1.mov"))
        XCTAssertTrue(lines.contains("* LOC: 01:00:04:00 YELLOW Drop"), "a marker four seconds in")
        XCTAssertTrue(text.hasSuffix("\r\n"))
    }

    func testTimecodeCountsNonDropFramesAtTheNominalBase() {
        XCTAssertEqual(EDLExport.timecode(0, rate: .fps24), "00:00:00:00")
        XCTAssertEqual(EDLExport.timecode(3_600 * 30 + 61, rate: .fps29_97), "01:00:02:01")
        XCTAssertEqual(EDLExport.timecode(-5, rate: .fps25), "00:00:00:00")
        XCTAssertEqual(EDLExport.timecode(24 * 3_600 * 25 + 1, rate: .fps25), "00:00:00:01", "wraps after a day")
        XCTAssertEqual(EDLExport.FrameRate.fps23_976.actual, 24_000.0 / 1_001, accuracy: 1e-12)
    }

    func testAnEmptyArrangementIsAListWithNoEventsAndTextIsOneLine() {
        var project = Project()
        project.name = "x"
        let text = EDLExport.text(for: project, title: "Two\nLines", rate: .fps30)
        XCTAssertEqual(text, "TITLE: Two Lines\r\nFCM: NON-DROP FRAME\r\n\r\n")
        XCTAssertTrue(EDLExport.events(for: project, rate: .fps30).isEmpty)
    }
}
