import Foundation
import XCTest
@testable import EchoelCore

/// The exports for other programs (EDL, OTIO, DAWproject) carry what the song plays: a folder of
/// takes as its comp (`Track.playedRegions`), never every take stacked (PRO-W2 after Recovery 4).
final class ExportCompTests: XCTestCase {
    /// Two seconds at 48 kHz: one 4/4 bar at 120 BPM.
    private let first = MediaFile(name: "Take 1", path: "Media/take1.wav", frameCount: 96_000, sampleRate: 48_000)
    private let second = MediaFile(name: "Take 2", path: "Media/take2.wav", frameCount: 96_000, sampleRate: 48_000)

    /// Two takes over bar 1, folded as recording does; `split` comps take 1 for the first half.
    private func song(split: Bool) throws -> Project {
        var p = Project(name: "Comp", tempo: 120)
        let track = TrackID(), a = RegionID(), b = RegionID(), group = TakeGroupID()
        try Command.addTrack(id: track, name: "Vocal", kind: .audio, index: nil).apply(to: &p)
        try Command.addMedia(first).apply(to: &p)
        try Command.addMedia(second).apply(to: &p)
        try Command.placeAudio(track: track, id: a, media: first.id, start: 0).apply(to: &p)
        try Command.placeAudio(track: track, id: b, media: second.id, start: 0).apply(to: &p)
        try Command.foldTake(track: track, take: b.rawValue, group: group).apply(to: &p)
        if split {
            try Command.compTake(track: track, group: group, take: a.rawValue, start: 0, end: 1_920).apply(to: &p)
        }
        return p
    }

    func testAWholeTakeCompExportsOnlyThatTake() throws {
        let p = try song(split: false)
        XCTAssertEqual(ExportMedia.arrangementMedia(of: p), [second.id], "the take that does not sound is not copied")
        let events = EDLExport.events(for: p, rate: .fps25)
        XCTAssertEqual(events.map(\.clipName), ["Take 2"])
        let lanes = OTIOExport.lanes(for: p, rate: .fps25)
        XCTAssertEqual(lanes.map(\.name), ["Vocal"], "no second track of takes")
        XCTAssertEqual(lanes.first?.cuts.map(\.name), ["Take 2"])
        let paths = ExportMedia.names(for: p, using: ExportMedia.arrangementMedia(of: p), folder: "audio")
        let xml = DAWprojectExport.projectXML(for: p, mediaPaths: paths)
        XCTAssertEqual(xml.components(separatedBy: "<Clip ").count - 1, 1)
        XCTAssertFalse(xml.contains("Take_1"))
    }

    func testASplitCompExportsItsPiecesWithTheCrossfade() throws {
        let p = try song(split: true)
        XCTAssertEqual(ExportMedia.arrangementMedia(of: p), [first.id, second.id])

        // EDL: take 1 from its start, then take 2 from one second into it — not two whole takes.
        let events = EDLExport.events(for: p, rate: .fps25)
        XCTAssertEqual(events.map(\.clipName), ["Take 1", "Take 2"])
        XCTAssertEqual(events[0].sourceIn, 0)
        XCTAssertEqual(events[1].sourceIn, events[1].recordIn - EDLExport.defaultRecordStart(.fps25))
        XCTAssertEqual(events[1].recordIn - EDLExport.defaultRecordStart(.fps25), 25, "the cut at one second")
        XCTAssertEqual(events[1].recordOut - EDLExport.defaultRecordStart(.fps25), 50)

        // OTIO: one track, the cut at one second. The 10 ms crossfade is less than a frame at every
        // rate, so the pieces meet end to end.
        for rate in [OTIOExport.FrameRate.fps25, .fps60] {
            let lanes = OTIOExport.lanes(for: p, rate: rate)
            XCTAssertEqual(lanes.map(\.name), ["Vocal"], "\(rate)")
            let cuts = try XCTUnwrap(lanes.first?.cuts)
            XCTAssertEqual(cuts.map(\.name), ["Take 1", "Take 2"])
            XCTAssertEqual(cuts[0].recordOut, cuts[1].recordIn, "end to end on one track")
            XCTAssertEqual(Double(cuts[1].recordIn), (1 * rate.actual).rounded(), accuracy: 1)
            XCTAssertEqual(cuts[1].sourceIn, cuts[1].recordIn, "take 2 plays from where it lies in the song")
        }
        let json = OTIOExport.json(for: p, title: "Comp", rate: .fps60)
        XCTAssertEqual(json.components(separatedBy: "\"Track.1\"").count - 1, 1)

        // DAWproject: two clips meeting at beat 2, the outgoing falling and the incoming rising.
        let paths = ExportMedia.names(for: p, using: ExportMedia.arrangementMedia(of: p), folder: "audio")
        let xml = DAWprojectExport.projectXML(for: p, mediaPaths: paths)
        let clips = xml.components(separatedBy: "<Clip ").dropFirst().map { String($0.prefix { $0 != ">" }) }
        XCTAssertEqual(clips.count, 2)
        XCTAssertTrue(clips[0].contains("time=\"0.0\""))
        XCTAssertGreaterThan(attribute("fadeOutTime", clips[0]) ?? 0, 0, "the outgoing take falls: \(clips[0])")
        XCTAssertGreaterThan(attribute("fadeInTime", clips[1]) ?? 0, 0, "the incoming take rises: \(clips[1])")
        XCTAssertEqual(attribute("time", clips[1]) ?? 0, 2, accuracy: 0.05, "the cut at beat 2, less half the crossfade")
        XCTAssertTrue(clips[1].contains("name=\"Take 2\""))
    }

    /// Where two parts of a track overlap by a frame — the rounding of a crossfade — OTIO gets one
    /// track with a dissolve, cut at the middle, not a second track.
    func testAFrameOfOverlapIsADissolveOnOneTrack() throws {
        var p = Project(name: "Cut", tempo: 120)
        let track = TrackID(), a = RegionID()
        try Command.addTrack(id: track, name: "Vocal", kind: .audio, index: nil).apply(to: &p)
        try Command.addMedia(first).apply(to: &p)
        try Command.addMedia(second).apply(to: &p)
        try Command.placeAudio(track: track, id: a, media: first.id, start: 0).apply(to: &p)
        // One second and 40 ms (a frame at 25 fps) of take 1; take 2 from one second.
        try Command.trimRegion(track: track, a, offset: 0, length: 49_920).apply(to: &p)
        try Command.placeAudio(track: track, id: RegionID(), media: second.id, start: 1_920).apply(to: &p)
        let lanes = OTIOExport.lanes(for: p, rate: .fps25)
        XCTAssertEqual(lanes.map(\.name), ["Vocal"])
        let cuts = try XCTUnwrap(lanes.first?.cuts)
        XCTAssertEqual(cuts.map(\.recordIn), [0, 25])
        XCTAssertEqual(cuts.map(\.recordOut), [25, 75])
        XCTAssertEqual([cuts[1].dissolveIn, cuts[1].dissolveOut], [0, 1])
        let json = OTIOExport.json(for: p, title: "Cut", rate: .fps25)
        XCTAssertTrue(json.contains("\"Transition.1\""))
    }

    /// The number in `name="…"` of an element's attribute text.
    private func attribute(_ name: String, _ text: String) -> Double? {
        let spaced = " " + text
        guard let range = spaced.range(of: " \(name)=\"") else { return nil }
        return Double(spaced[range.upperBound...].prefix { $0 != "\"" })
    }
}
