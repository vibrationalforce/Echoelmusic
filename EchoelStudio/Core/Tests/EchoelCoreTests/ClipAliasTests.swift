import Foundation
import XCTest
@testable import EchoelCore

/// Linked copies (an alias, Cubase's shared copy): two placements naming one clip. Duplicate as
/// Linked places the same clip again, Make Unique gives a placement a clip of its own, and every
/// export writes each placement as a copy of its own.
final class ClipAliasTests: XCTestCase {
    private let bar = MusicalTime.ticksPerBar(.common)

    /// A Keys track with a one-bar clip of one note at bar 1, placed again as a linked copy at bar 2.
    private func linked() throws -> (project: Project, track: TrackID, clip: ClipID, first: PlacementID, second: PlacementID) {
        var project = Project()
        let track = TrackID(), clip = ClipID(), first = PlacementID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.createClip(track: track, id: clip, name: "Riff", length: bar).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 60, start: 0, length: 480)]).apply(to: &project)
        try Command.placeClip(track: track, id: first, clip: clip, start: 0).apply(to: &project)
        let t = try XCTUnwrap(project.track(track))
        let copy = try XCTUnwrap(Arranging.duplicated(try XCTUnwrap(t.placements.first), in: t))
        try copy.apply(to: &project)
        guard case let .placeClip(_, second, _, _) = copy else {
            XCTFail("\(copy)")
            return (project, track, clip, first, first)
        }
        return (project, track, clip, first, second)
    }

    private func noteOns(_ project: Project) -> [String] {
        (PlaybackPlan(compiling: project).tracks.first?.events ?? []).compactMap { event in
            guard case .noteOn = event.kind else { return nil }
            return "\(event.tick) \(event.pitch)"
        }
    }

    func testDuplicateAsLinkedPlacesTheSameClipAgain() throws {
        let (p, track, clip, _, _) = try linked()
        let t = try XCTUnwrap(p.track(track))
        XCTAssertEqual(t.placements.map(\.start), [0, bar])
        XCTAssertEqual(t.placements.map(\.clip), [clip, clip])
        XCTAssertEqual(t.clips.count, 1, "a linked copy copies no clip")
        XCTAssertEqual(t.uses(of: clip), 2)
        XCTAssertNoThrow(try p.validate())
    }

    func testANoteEditedOnALinkedCopyChangesEveryPlacement() throws {
        var (p, _, clip, _, _) = try linked()
        let note = try XCTUnwrap(p.clip(clip)?.notes.first)
        var moved = note
        moved.pitch = 67
        try Command.updateNotes(clip, [moved]).apply(to: &p)
        try Command.addNotes(clip, [Note(pitch: 72, start: 960, length: 480)]).apply(to: &p)
        XCTAssertEqual(noteOns(p), ["0 67", "960 72", "\(bar) 67", "\(bar + 960) 72"])
    }

    func testMakeUniqueGivesThePlacementAClipOfItsOwn() throws {
        var (p, track, clip, first, second) = try linked()
        let t = try XCTUnwrap(p.track(track))
        let placement = try XCTUnwrap(t.placements.first { $0.id == second })
        let command = try XCTUnwrap(Arranging.madeUnique(placement, in: t))
        try command.apply(to: &p)
        guard case let .makePlacementUnique(_, _, own) = command else { return XCTFail("\(command)") }

        let after = try XCTUnwrap(p.track(track))
        XCTAssertEqual(after.placements.first { $0.id == first }?.clip, clip)
        XCTAssertEqual(after.placements.first { $0.id == second }?.clip, own)
        XCTAssertEqual(after.clips.map(\.id), [clip, own], "the copy sits next to its original")
        XCTAssertEqual(p.clip(own)?.notes, p.clip(clip)?.notes)
        XCTAssertEqual(p.clip(own)?.name, "Riff")
        XCTAssertEqual(after.uses(of: clip), 1)
        XCTAssertNil(Arranging.madeUnique(placement, in: after), "nothing to separate any more")

        // From now on an edit stays with its clip.
        try Command.addNotes(own, [Note(pitch: 72, start: 960, length: 480)]).apply(to: &p)
        XCTAssertEqual(noteOns(p), ["0 60", "\(bar) 60", "\(bar + 960) 72"])
        XCTAssertNoThrow(try p.validate())
    }

    func testMakeUniqueIsRefusedWhereNothingIsShared() throws {
        var (p, track, clip, first, second) = try linked()
        let own = ClipID()
        try Command.makePlacementUnique(track: track, second, clip: own).apply(to: &p)
        let before = p
        for command: Command in [
            .makePlacementUnique(track: track, first, clip: ClipID()),
            .makePlacementUnique(track: track, second, clip: ClipID()),
            .makePlacementUnique(track: TrackID(), first, clip: ClipID()),
            .makePlacementUnique(track: track, PlacementID(), clip: ClipID()),
        ] {
            XCTAssertThrowsError(try command.apply(to: &p), "\(command)")
            XCTAssertEqual(p, before, "a refused command leaves the song as it was")
        }
        // A clip id already in the song is refused too.
        try Command.placeClip(track: track, id: PlacementID(), clip: clip, start: 4 * bar).apply(to: &p)
        XCTAssertThrowsError(try Command.makePlacementUnique(track: track, first, clip: own).apply(to: &p))
    }

    func testASessionSlotCountsAsAPlaceTheClipPlays() throws {
        var p = Project()
        let track = TrackID(), clip = ClipID(), placement = PlacementID(), scene = SceneID()
        try Command.addTrack(id: track, name: "Keys", kind: .instrument, index: nil).apply(to: &p)
        try Command.createClip(track: track, id: clip, name: "Riff", length: bar).apply(to: &p)
        try Command.placeClip(track: track, id: placement, clip: clip, start: 0).apply(to: &p)
        XCTAssertNil(Arranging.madeUnique(try XCTUnwrap(p.track(track)?.placements.first), in: try XCTUnwrap(p.track(track))))
        try Command.addScene(id: scene, name: "A", index: nil).apply(to: &p)
        try Command.setSlot(track: track, scene: scene, clip: clip).apply(to: &p)
        XCTAssertEqual(p.track(track)?.uses(of: clip), 2)
        let own = ClipID()
        try Command.makePlacementUnique(track: track, placement, clip: own).apply(to: &p)
        XCTAssertEqual(p.track(track)?.clipInSlot(scene), clip, "the slot keeps the original")
        XCTAssertEqual(p.track(track)?.placements.first?.clip, own)
    }

    func testDuplicateMakesAnIndependentCopyInOneStep() throws {
        var (p, track, clip, _, _) = try linked()
        let t = try XCTUnwrap(p.track(track))
        let last = try XCTUnwrap(t.placements.last)
        let commands = try XCTUnwrap(Arranging.copied(last, in: t))
        for command in commands { try command.apply(to: &p) }
        let after = try XCTUnwrap(p.track(track))
        XCTAssertEqual(after.placements.map(\.start), [0, bar, 2 * bar])
        XCTAssertEqual(after.uses(of: clip), 2, "the two linked copies stay linked")
        let copy = try XCTUnwrap(after.placements.last?.clip)
        XCTAssertNotEqual(copy, clip)
        XCTAssertEqual(p.clip(copy)?.notes, p.clip(clip)?.notes)
        XCTAssertNoThrow(try p.validate())
    }

    func testRemovingOnePlacementKeepsTheClipForTheOthers() throws {
        var (p, track, clip, first, _) = try linked()
        try Command.removePlacement(track: track, first).apply(to: &p)
        XCTAssertEqual(p.track(track)?.placements.map(\.clip), [clip])
        XCTAssertEqual(p.clip(clip)?.notes.map(\.pitch), [60])
        XCTAssertEqual(noteOns(p), ["\(bar) 60"])
        XCTAssertNoThrow(try p.validate())
    }

    func testEveryAliasActionIsOneUndoStep() async throws {
        let (start, track, clip, first, second) = try linked()
        try await MainActor.run {
            let store = ProjectStore(project: start)
            let own = ClipID()
            try store.perform(.makePlacementUnique(track: track, second, clip: own))
            XCTAssertEqual(store.undoTitle, "Make Unique")
            XCTAssertEqual(store.project.track(track)?.placements.map(\.clip), [clip, own])
            store.undo()
            XCTAssertEqual(store.project, start)
            store.redo()
            XCTAssertEqual(store.project.track(track)?.placements.map(\.clip), [clip, own])
            store.undo()

            // Duplicate (independent) is the two commands as one step.
            let t = store.project.track(track)
            let placement = t?.placements.first { $0.id == first }
            if let t, let placement, let commands = Arranging.copied(placement, in: t) {
                try store.perform(commands, title: "Duplicate")
            } else {
                XCTFail("no duplicate")
            }
            XCTAssertEqual(store.project.track(track)?.placements.count, 3)
            XCTAssertEqual(store.project.track(track)?.clips.count, 2)
            store.undo()
            XCTAssertEqual(store.project, start, "one undo takes back the copy and its clip")
        }
    }

    func testTheMIDIExportWritesEveryLinkedCopy() throws {
        var (p, _, clip, _, _) = try linked()
        let note = try XCTUnwrap(p.clip(clip)?.notes.first)
        var raised = note
        raised.pitch = 64
        try Command.updateNotes(clip, [raised]).apply(to: &p)
        let content = try MIDIFileImport.read(MIDIFile.data(for: p))
        let notes = content.tracks.flatMap(\.notes).map { "\($0.start) \($0.pitch)" }.sorted()
        XCTAssertEqual(notes, ["0 64", "\(bar) 64"].sorted())
    }

    func testTheDAWprojectWritesEveryLinkedCopyAsAClipOfItsOwn() throws {
        var (p, _, clip, _, _) = try linked()
        let note = try XCTUnwrap(p.clip(clip)?.notes.first)
        var raised = note
        raised.pitch = 64
        try Command.updateNotes(clip, [raised]).apply(to: &p)
        let xml = DAWprojectExport.projectXML(for: p, mediaPaths: [:], channels: [:])
        let clips = xml.components(separatedBy: "<Clip ").dropFirst()
        XCTAssertEqual(clips.count, 2, xml)
        XCTAssertEqual(clips.filter { $0.contains("key=\"64\"") }.count, 2, xml)
        XCTAssertFalse(xml.contains("key=\"60\""), "the edit reaches every copy")
        XCTAssertTrue(xml.contains("time=\"0.0\"") && xml.contains("time=\"4.0\""), xml)
    }

    /// A song as a format-4 build writes linked copies: two placements and a slot naming one clip.
    /// Nothing new is stored for a link — the shared id is the link.
    private let linkedSong = Data("""
    {
      "formatVersion": 4,
      "name": "Linked",
      "tempo": 120,
      "timeSignature": { "numerator": 4, "denominator": 4 },
      "master": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
      "scenes": [ { "id": "5CE7E000-0000-4000-8000-0000000000A1", "name": "A" } ],
      "modRoutes": [],
      "tracks": [
        {
          "id": "7A000000-0000-4000-8000-0000000000A1",
          "name": "Keys",
          "kind": "instrument",
          "colorIndex": 0,
          "mixer": { "volumeDB": 0, "pan": 0, "isMuted": false, "isSoloed": false },
          "clips": [
            { "id": "C1000000-0000-4000-8000-0000000000A1", "name": "Riff", "length": 3840,
              "notes": [ { "id": "40000000-0000-4000-8000-0000000000A1", "pitch": 60, "velocity": 100,
                           "start": 0, "length": 480 } ] }
          ],
          "placements": [
            { "id": "B1000000-0000-4000-8000-0000000000A1", "clip": "C1000000-0000-4000-8000-0000000000A1", "start": 0 },
            { "id": "B1000000-0000-4000-8000-0000000000A2", "clip": "C1000000-0000-4000-8000-0000000000A1", "start": 3840 }
          ],
          "slots": [ { "scene": "5CE7E000-0000-4000-8000-0000000000A1", "clip": "C1000000-0000-4000-8000-0000000000A1" } ]
        }
      ]
    }
    """.utf8)

    func testALinkedSongOpensLinkedAndSavesTheSameShape() throws {
        var p = try ProjectCodec.decode(linkedSong)
        let track = try XCTUnwrap(p.tracks.first)
        let clip = try XCTUnwrap(track.clips.first?.id)
        XCTAssertEqual(track.uses(of: clip), 3)
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(p)), p)

        let second = try XCTUnwrap(track.placements.last)
        try Command.makePlacementUnique(track: track.id, second.id, clip: ClipID()).apply(to: &p)
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: ProjectCodec.encode(p)) as? [String: Any])
        let tracks = try XCTUnwrap(saved["tracks"] as? [[String: Any]])
        XCTAssertEqual((tracks.first?["clips"] as? [Any])?.count, 2, "a unique copy is an ordinary clip")
        XCTAssertNil(tracks.first?["links"], "nothing new is stored for a link")
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(p)), p)
    }
}
