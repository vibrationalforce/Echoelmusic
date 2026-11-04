import Foundation
import XCTest
@testable import EchoelCore

/// Recovery 4: takes of one track stacked as lanes of a folder, and the comp — which take sounds
/// where — kept as a list of stretches. The takes themselves are never touched.
final class TakeCompTests: XCTestCase {
    /// Two seconds at 48 kHz: one 4/4 bar at 120 BPM, 25 frames per tick.
    private let first = MediaFile(name: "Take 1", path: "Media/take1.wav", frameCount: 96_000, sampleRate: 48_000)
    private let second = MediaFile(name: "Take 2", path: "Media/take2.wav", frameCount: 96_000, sampleRate: 48_000)

    private struct Song {
        var project: Project
        var track: TrackID
        var a: RegionID
        var b: RegionID
    }

    /// Two takes recorded over the same bar, the second folded with the first as recording does.
    private func song(foldAs group: TakeGroupID = TakeGroupID()) throws -> Song {
        var p = Project(tempo: 120)
        let track = TrackID(), a = RegionID(), b = RegionID()
        try Command.addTrack(id: track, name: "Vocal", kind: .audio, index: nil).apply(to: &p)
        try Command.addMedia(first).apply(to: &p)
        try Command.addMedia(second).apply(to: &p)
        try Command.placeAudio(track: track, id: a, media: first.id, start: 0).apply(to: &p)
        try Command.placeAudio(track: track, id: b, media: second.id, start: 0).apply(to: &p)
        try Command.foldTake(track: track, take: b.rawValue, group: group).apply(to: &p)
        return Song(project: p, track: track, a: a, b: b)
    }

    func testANewTakeFoldsWithWhatItOverlapsAndSoundsOverItsSpan() throws {
        let group = TakeGroupID()
        let s = try song(foldAs: group)
        let folder = try XCTUnwrap(s.project.track(s.track)?.takeGroups.first)
        XCTAssertEqual(folder.id, group)
        XCTAssertEqual(folder.takes, [s.a.rawValue, s.b.rawValue], "oldest first; the new take is the last lane")
        XCTAssertEqual(folder.comp, [CompSegment(start: 0, end: 3_840, take: s.b.rawValue)])
        XCTAssertEqual(s.project.track(s.track)?.regions.count, 2, "both takes stay as recorded")
    }

    func testATakeOverNothingStaysAPlainRegion() throws {
        var p = Project(tempo: 120)
        let track = TrackID(), a = RegionID(), b = RegionID()
        try Command.addTrack(id: track, name: "Vocal", kind: .audio, index: nil).apply(to: &p)
        try Command.addMedia(first).apply(to: &p)
        try Command.addMedia(second).apply(to: &p)
        try Command.placeAudio(track: track, id: a, media: first.id, start: 0).apply(to: &p)
        try Command.placeAudio(track: track, id: b, media: second.id, start: 3_840).apply(to: &p)
        let before = p
        try Command.foldTake(track: track, take: b.rawValue, group: TakeGroupID()).apply(to: &p)
        XCTAssertEqual(p, before, "a take that overlaps nothing changes nothing")
        XCTAssertEqual(p.track(track)?.playedRegions(in: p), p.track(track)?.regions)
    }

    func testAThirdTakeJoinsTheFolderAndOlderTakesOnlyFillGaps() throws {
        var s = try song()
        let c = RegionID()
        let third = MediaFile(name: "Take 3", path: "Media/take3.wav", frameCount: 48_000, sampleRate: 48_000)
        try Command.addMedia(third).apply(to: &s.project)
        try Command.placeAudio(track: s.track, id: c, media: third.id, start: 1_920).apply(to: &s.project)
        try Command.foldTake(track: s.track, take: c.rawValue, group: TakeGroupID()).apply(to: &s.project)
        let groups = try XCTUnwrap(s.project.track(s.track)?.takeGroups)
        XCTAssertEqual(groups.count, 1, "joins the folder it overlaps, no second folder")
        XCTAssertEqual(groups[0].takes, [s.a.rawValue, s.b.rawValue, c.rawValue])
        XCTAssertEqual(groups[0].comp, [CompSegment(start: 0, end: 1_920, take: s.b.rawValue),
                                        CompSegment(start: 1_920, end: 3_840, take: c.rawValue)])
        XCTAssertEqual(TakeComp.filling([CompSegment(start: 100, end: 200, take: s.b.rawValue)], take: s.a.rawValue, from: 0, to: 300),
                       [CompSegment(start: 0, end: 100, take: s.a.rawValue), CompSegment(start: 100, end: 200, take: s.b.rawValue),
                        CompSegment(start: 200, end: 300, take: s.a.rawValue)])
    }

    func testChoosingATakePaintsItsStretchAndIsValidatedAtTheDoor() throws {
        var s = try song()
        let group = try XCTUnwrap(s.project.track(s.track)?.takeGroups.first?.id)
        try Command.compTake(track: s.track, group: group, take: s.a.rawValue, start: 960, end: 1_920).apply(to: &s.project)
        XCTAssertEqual(s.project.track(s.track)?.takeGroups.first?.comp,
                       [CompSegment(start: 0, end: 960, take: s.b.rawValue), CompSegment(start: 960, end: 1_920, take: s.a.rawValue),
                        CompSegment(start: 1_920, end: 3_840, take: s.b.rawValue)])
        // Painting the same take back joins the stretches again.
        try Command.compTake(track: s.track, group: group, take: s.b.rawValue, start: 960, end: 1_920).apply(to: &s.project)
        XCTAssertEqual(s.project.track(s.track)?.takeGroups.first?.comp, [CompSegment(start: 0, end: 3_840, take: s.b.rawValue)])

        let before = s.project
        let refused: [Command] = [
            .compTake(track: s.track, group: group, take: UUID(), start: 0, end: 960),
            .compTake(track: s.track, group: group, take: s.a.rawValue, start: 960, end: 960),
            .compTake(track: s.track, group: group, take: s.a.rawValue, start: -1, end: 960),
            .compTake(track: s.track, group: group, take: s.a.rawValue, start: 0, end: MusicalTime.maximumTick + 1),
            .compTake(track: s.track, group: TakeGroupID(), take: s.a.rawValue, start: 0, end: 960),
            .compTake(track: TrackID(), group: group, take: s.a.rawValue, start: 0, end: 960),
            .removeTakeGroup(track: s.track, TakeGroupID()),
            .foldTake(track: s.track, take: UUID(), group: TakeGroupID()),
        ]
        for command in refused {
            XCTAssertThrowsError(try command.apply(to: &s.project), "\(command)")
            XCTAssertEqual(s.project, before, "a refused command leaves the song as it was")
        }
    }

    func testDeletingATakeDissolvesAFolderOfTwoAndUnfoldingKeepsTheTakes() throws {
        var s = try song()
        try Command.removeRegion(track: s.track, s.a).apply(to: &s.project)
        XCTAssertTrue(s.project.track(s.track)?.takeGroups.isEmpty ?? false, "one take is no folder")
        XCTAssertNoThrow(try s.project.validate())

        var t = try song()
        let group = try XCTUnwrap(t.project.track(t.track)?.takeGroups.first?.id)
        try Command.removeTakeGroup(track: t.track, group).apply(to: &t.project)
        XCTAssertTrue(t.project.track(t.track)?.takeGroups.isEmpty ?? false)
        XCTAssertEqual(t.project.track(t.track)?.regions.count, 2, "unfolding keeps every take")

        var u = try song()
        try Command.removeTrack(u.track).apply(to: &u.project)
        XCTAssertNoThrow(try u.project.validate())
    }

    func testSplittingATakeKeepsTheFolderSoundingAsBefore() throws {
        var s = try song()
        let tail = RegionID()
        try Command.splitRegion(track: s.track, s.b, at: 1_920, newID: tail).apply(to: &s.project)
        let folder = try XCTUnwrap(s.project.track(s.track)?.takeGroups.first)
        XCTAssertEqual(folder.takes, [s.a.rawValue, s.b.rawValue, tail.rawValue])
        XCTAssertEqual(folder.comp, [CompSegment(start: 0, end: 1_920, take: s.b.rawValue),
                                     CompSegment(start: 1_920, end: 3_840, take: tail.rawValue)])
        // The file runs on across the split: two pieces, no fade between them.
        let played = try XCTUnwrap(s.project.track(s.track)?.playedRegions(in: s.project))
        XCTAssertEqual(played.map(\.offset), [0, 48_000])
        XCTAssertEqual(played.map(\.length), [48_000, 48_000])
        XCTAssertTrue(played.allSatisfy { $0.fadeIn == nil && $0.fadeOut == nil })
    }

    /// At a cut the outgoing take falls and the incoming one rises over 10 ms around it (10 ticks
    /// either side at 120 BPM), with equal power; the takes' own edges keep their own fades.
    func testACutCrossfadesTheTwoTakes() throws {
        var s = try song()
        let group = try XCTUnwrap(s.project.track(s.track)?.takeGroups.first?.id)
        try Command.compTake(track: s.track, group: group, take: s.a.rawValue, start: 0, end: 1_920).apply(to: &s.project)
        let played = try XCTUnwrap(s.project.track(s.track)?.playedRegions(in: s.project))
        XCTAssertEqual(played.count, 2)
        let (outgoing, incoming) = (played[0], played[1])
        XCTAssertEqual(outgoing.media, first.id)
        XCTAssertEqual(outgoing.start, 0)
        XCTAssertEqual(outgoing.offset, 0)
        XCTAssertEqual(outgoing.length, 48_250, "runs on 10 ticks past the cut")
        XCTAssertNil(outgoing.fadeIn, "the take's own start")
        XCTAssertEqual(outgoing.fadeOut, 500)
        XCTAssertEqual(outgoing.fadeOutCurve, .equalPower)
        XCTAssertEqual(incoming.media, second.id)
        XCTAssertEqual(incoming.start, 1_910, "comes in 10 ticks before the cut")
        XCTAssertEqual(incoming.offset, 47_750, "in time with where it was recorded")
        XCTAssertEqual(incoming.length, 48_250)
        XCTAssertEqual(incoming.fadeIn, 500)
        XCTAssertEqual(incoming.fadeInCurve, .equalPower)
        XCTAssertNil(incoming.fadeOut)
    }

    func testAStretchThatMeetsSilenceFadesInsideItself() throws {
        var s = try song()
        let group = try XCTUnwrap(s.project.track(s.track)?.takeGroups.first?.id)
        try Command.removeTakeGroup(track: s.track, group).apply(to: &s.project)
        let custom = TakeGroupID()
        // A folder whose comp leaves the first half silent.
        var track = try XCTUnwrap(s.project.track(s.track))
        track.takeGroups = [TakeGroup(id: custom, takes: [s.a.rawValue, s.b.rawValue],
                                      comp: [CompSegment(start: 1_920, end: 3_840, take: s.a.rawValue)])]
        let played = track.playedRegions(in: s.project)
        XCTAssertEqual(played.count, 1)
        XCTAssertEqual(played[0].start, 1_920)
        XCTAssertEqual(played[0].offset, 48_000)
        XCTAssertEqual(played[0].fadeIn, 500, "rises over one crossfade's length out of silence")
    }

    func testAFolderCutDownToOneTakePlaysItWhole() throws {
        let s = try song()
        var track = try XCTUnwrap(s.project.track(s.track))
        track.regions.removeAll { $0.id == s.a }
        XCTAssertEqual(track.playedRegions(in: s.project), track.regions, "a bake's song of one region plays it whole")
    }

    func testATapChoosesItsBarAndASwipeItsStretchOnTheGrid() {
        let meter = MeterMap(signature: .common)
        let span: Range<Tick> = 960..<9_000
        XCTAssertEqual(TakeComp.stretch(tappedAt: 5_000, in: span, meter: meter), 3_840..<7_680)
        XCTAssertEqual(TakeComp.stretch(tappedAt: 100, in: span, meter: meter), 960..<3_840, "held to the take")
        XCTAssertNil(TakeComp.stretch(tappedAt: 12_000, in: span, meter: meter), "a bar the take does not reach")
        XCTAssertEqual(TakeComp.stretch(swipedFrom: 2_100, to: 1_000, in: span, snap: .beat, meter: meter), 960..<1_920,
                       "either direction, both ends on the grid")
        XCTAssertEqual(TakeComp.stretch(swipedFrom: 1_000, to: 99_000, in: span, snap: .bar, meter: meter), 960..<9_000)
        XCTAssertNil(TakeComp.stretch(swipedFrom: 1_000, to: 1_100, in: span, snap: .bar, meter: meter))
        let a = UUID(), b = UUID()
        XCTAssertEqual(TakeComp.chosen(a, in: [CompSegment(start: 0, end: 10, take: a), CompSegment(start: 10, end: 20, take: b),
                                               CompSegment(start: 30, end: 40, take: a)]), [0..<10, 30..<40])
    }

    // MARK: - MIDI takes

    func testAnInstrumentTracksCompPlaysOnlyTheChosenTakesNotes() throws {
        var p = Project(tempo: 120)
        let track = TrackID(), one = ClipID(), two = ClipID(), a = PlacementID(), b = PlacementID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &p)
        for (clip, pitch) in [(one, 60), (two, 72)] {
            try Command.createClip(track: track, id: clip, name: "Take", length: 3_840).apply(to: &p)
            try Command.addNotes(clip, [Note(pitch: pitch, start: 0, length: 900), Note(pitch: pitch + 1, start: 1_920, length: 1_200)])
                .apply(to: &p)
        }
        try Command.placeClip(track: track, id: a, clip: one, start: 0).apply(to: &p)
        try Command.placeClip(track: track, id: b, clip: two, start: 0).apply(to: &p)
        try Command.foldTake(track: track, take: b.rawValue, group: TakeGroupID()).apply(to: &p)
        var plan = PlaybackPlan(compiling: p)
        XCTAssertEqual(Set(plan.tracks[0].events.map(\.pitch)), [72, 73], "the newest take sounds")
        let group = try XCTUnwrap(p.track(track)?.takeGroups.first?.id)
        try Command.compTake(track: track, group: group, take: a.rawValue, start: 1_920, end: 2_400).apply(to: &p)
        plan = PlaybackPlan(compiling: p)
        let ons = plan.tracks[0].events.filter { if case .noteOn = $0.kind { true } else { false } }
        XCTAssertEqual(ons.map(\.pitch), [72, 61])
        let off = plan.tracks[0].events.first { $0.pitch == 61 && $0.kind == .noteOff }
        XCTAssertEqual(off?.tick, 2_400, "a note is ended where its stretch ends")
        XCTAssertNotEqual(PlaybackPlan.Source(p), PlaybackPlan.Source(try {
            var q = p
            try Command.compTake(track: track, group: group, take: b.rawValue, start: 1_920, end: 2_400).apply(to: &q)
            return q
        }()), "a comp change compiles again")
    }

    // MARK: - Store and file

    func testEveryCompChangeIsOneUndoStep() async throws {
        let s = try song()
        try await MainActor.run {
            let store = ProjectStore(project: s.project)
            let group = try XCTUnwrap(store.project.track(s.track)?.takeGroups.first?.id)
            try store.perform(.compTake(track: s.track, group: group, take: s.a.rawValue, start: 0, end: 960))
            try store.perform(.compTake(track: s.track, group: group, take: s.a.rawValue, start: 2_880, end: 3_840))
            XCTAssertEqual(store.project.track(s.track)?.takeGroups.first?.comp.count, 3)
            store.undo()
            XCTAssertEqual(store.project.track(s.track)?.takeGroups.first?.comp,
                           [CompSegment(start: 0, end: 960, take: s.a.rawValue), CompSegment(start: 960, end: 3_840, take: s.b.rawValue)])
            store.undo()
            XCTAssertEqual(store.project, s.project)
        }
    }

    func testAFolderSurvivesTheFileAndADamagedOneRefusesIt() throws {
        var s = try song()
        let group = try XCTUnwrap(s.project.track(s.track)?.takeGroups.first?.id)
        try Command.compTake(track: s.track, group: group, take: s.a.rawValue, start: 0, end: 960).apply(to: &s.project)
        let data = try ProjectCodec.encode(s.project)
        XCTAssertEqual(try ProjectCodec.decode(data), s.project)
        var broken = s.project
        broken.tracks[0].takeGroups[0].comp.append(CompSegment(start: 3_000, end: 3_500, take: s.a.rawValue))
        XCTAssertThrowsError(try ProjectCodec.decode(ProjectCodec.encode(broken)), "overlapping stretches")
        var stranger = s.project
        stranger.tracks[0].takeGroups[0].takes[0] = UUID()
        XCTAssertThrowsError(try ProjectCodec.decode(ProjectCodec.encode(stranger)), "a take that names nothing")
    }
}
