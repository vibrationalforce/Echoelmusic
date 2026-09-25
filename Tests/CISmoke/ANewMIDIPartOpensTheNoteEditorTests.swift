// ANewMIDIPartOpensTheNoteEditorTests.swift
// Echoel — Phase 3 / Creation Workflow, slice M1b: "New MIDI Part".
//
// WHAT IT PINS. M1 gave the Workstation a note editor for the selected MIDI part, but the only
// thing that could MAKE an editable part was a MIDI file (`MIDIImport.perform`). On a fresh
// install with no file at hand the editor had nothing to open. "New MIDI Part" is the second
// producer: an EMPTY, user-owned MIDI part on the roll lane, selected at once.
//
// 1. PURE (`MIDIImport.planEmptyPart`, END-TO-END BEHAVIOUR on shipped value types): the part
//    lands on the import's lane (`rollLaneID`, #416), four bars, on a barline after the lane's
//    last part; its clip is user-owned, MIDI and empty, and the note editor ACCEPTS it
//    (`ClipNoteEdit.refusal` is nil) — the reason this door exists.
// 2. PURE: an orphaned EMPTY user clip is reused by id; a clip with notes, a composer clip, or a
//    clip a part still plays is never taken. No lane → `.noMIDILane`; a full grid with nothing
//    reusable → `.clipGridFull`, and the grid is not overwritten.
// 3. END-TO-END over a REAL `TimelineStore` and `ClipStore`: one tap is ONE undo step; New →
//    Undo, repeated, spends ONE slot, not one per cycle.
// 4. SOURCE-TEXT SCAN: the Workstation row is labelled, hands both stores to
//    `MIDIImport.addEmptyPart`, selects the landed part through the one selection owner, and is
//    the only production caller; the transaction writes the clip before the region.
//
// Grading (§0 — no Swift toolchain here): claims 1–3 were transcribed into Python over a model of
// `planEmptyPart` (slot search, barline rounding) and of the store's undo; claim 4 was driven
// against this tree. On the parent `planEmptyPart`/`addEmptyPart`/`emptyPartBars` do not exist, so
// the bundle does not build there: ONE absence, not N findings (#486) — every claim here is a
// FORWARD guard. Counterweights: the refusal and the never-overwrite assertions in claim 2 pin
// premises (#343) that were already true of the import.
// NOT covered: that the row renders, that the part appears selected on the canvas, that notes
// written into it are heard — a device probe, owned by the marker below.
// NEEDS-FOUNDER-VERIFY: fresh install → Workstation → Add MIDI Track → New MIDI Part → the
// part is selected under the canvas → Notes → tap cells → Play: the notes sound; Undo removes
// the part, and New MIDI Part again does not fill the clip grid.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ANewMIDIPartOpensTheNoteEditorTests: XCTestCase {

    private static let importerPath = "Sources/Echoelmusic/Sequencer/MIDIImport.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"
    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — pure: where it lands and that the editor takes it

    func testAnEmptyPartLandsOnTheRollLaneOnABarlineAndTheEditorTakesIt() throws {
        let bio = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let second = TimelineLane(name: "Lead", kind: .midi)
        let empty = TimelineDocument(lanes: [bio, keys, second], regions: [])
        XCTAssertEqual(empty.rollLaneID, keys.id, "fixture premise: the roll lane skips the bio lane")

        let slots = [Clip?](repeating: nil, count: ClipStore.slotCount)
        guard case .success(let first) = MIDIImport.planEmptyPart(document: empty, slots: slots) else {
            return XCTFail("an empty song with a MIDI track must get a part")
        }
        XCTAssertEqual(first.laneID, keys.id, "the import's lane, never a second opinion (#416)")
        XCTAssertEqual(first.region.laneID, keys.id)
        XCTAssertEqual(first.region.startTick, 0)
        XCTAssertEqual(first.region.lengthTicks, MIDIImport.emptyPartBars * Self.bar)
        XCTAssertEqual(first.slotIndex, 0)
        XCTAssertEqual(first.region.clipID, first.clip.id)
        XCTAssertEqual(first.clip.kind, .midi)
        XCTAssertFalse(first.clip.composerOwned, "evolve must never rewrite the user's notes")
        XCTAssertEqual(first.clip.melody?.notes ?? [Note(pitch: 60, startStep: 0)], [])
        XCTAssertNil(ClipNoteEdit.refusal(clip: first.clip, region: first.region),
                     "the note editor must accept the part this door makes — that is its purpose")

        // A part that ends mid-bar: the new one starts on the NEXT barline.
        let trimmed = TimelineRegion(laneID: keys.id, clipID: UUID(), startTick: 0,
                                     lengthTicks: 2 * Self.bar + 100)
        let busy = TimelineDocument(lanes: [bio, keys, second], regions: [trimmed])
        guard case .success(let after) = MIDIImport.planEmptyPart(document: busy, slots: slots) else {
            return XCTFail("a lane with a part must still take a new one")
        }
        XCTAssertEqual(after.region.startTick, 3 * Self.bar, "after the last part, on a barline")
        XCTAssertEqual(after.region.startTick % Self.bar, 0)
    }

    // MARK: 2 — pure: reuse and refusals

    func testOnlyAnEmptyUnplayedUserClipIsReusedAndNothingIsOverwritten() throws {
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let orphanEmpty = Clip(name: "old", kind: .midi, melody: MelodyClip(notes: []))
        let orphanMusic = Clip(name: "song", kind: .midi,
                               melody: MelodyClip(notes: [Note(pitch: 62, startStep: 0)]))
        let composed = Clip(name: "Composed", kind: .midi, melody: MelodyClip(notes: []),
                            composerOwned: true)
        let playedEmpty = Clip(name: "played", kind: .midi, melody: MelodyClip(notes: []))
        let playing = TimelineRegion(laneID: keys.id, clipID: playedEmpty.id, startTick: 0,
                                     lengthTicks: Self.bar)
        let doc = TimelineDocument(lanes: [keys], regions: [playing])

        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[1] = orphanMusic
        grid[2] = composed
        grid[3] = playedEmpty
        grid[5] = orphanEmpty
        guard case .success(let reused) = MIDIImport.planEmptyPart(document: doc, slots: grid) else {
            return XCTFail("a free grid must take a part")
        }
        XCTAssertEqual(reused.slotIndex, 5, "the one orphaned EMPTY user clip is reused")
        XCTAssertEqual(reused.clip.id, orphanEmpty.id, "…by id, not replaced")
        XCTAssertEqual(reused.clip.name, "MIDI · Keys")

        // Without it: a free slot, never one of the three that hold something.
        grid[5] = nil
        guard case .success(let fresh) = MIDIImport.planEmptyPart(document: doc, slots: grid) else {
            return XCTFail("a free grid must take a part")
        }
        XCTAssertEqual(fresh.slotIndex, 0)
        XCTAssertFalse([orphanMusic.id, composed.id, playedEmpty.id].contains(fresh.clip.id))

        // Full grid, nothing reusable → refused, nothing chosen.
        let full: [Clip?] = (0..<ClipStore.slotCount).map { i in
            Clip(name: "n\(i)", kind: .midi, melody: MelodyClip(notes: [Note(pitch: 60, startStep: i)]))
        }
        XCTAssertEqual(MIDIImport.planEmptyPart(document: doc, slots: full).failureValue, .clipGridFull)

        // No MIDI track → refused with the sentence the row above can act on.
        let audioOnly = TimelineDocument(lanes: [TimelineLane(name: "Audio", kind: .audio)], regions: [])
        XCTAssertEqual(MIDIImport.planEmptyPart(document: audioOnly, slots: grid).failureValue,
                       .noMIDILane)
    }

    // MARK: 3 — the real stores

    func testOneTapIsOneUndoStepAndNewUndoCyclesSpendOneSlot() throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)),
                      "fixture premise: an empty grid")
        let keys = TimelineLane(name: "Keys", kind: .midi)
        timeline.replaceDocument(TimelineDocument(lanes: [keys], regions: []))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")

        guard case .success(let landing) = MIDIImport.addEmptyPart(clipStore: clips, timeline: timeline) else {
            return XCTFail("the transaction must land")
        }
        XCTAssertEqual(timeline.document.regions.map(\.id), [landing.region.id])
        XCTAssertEqual(clips.clip(id: landing.clip.id)?.kind, .midi, "the clip is in the grid")
        XCTAssertTrue(timeline.canUndo, "one tap is an undo step")
        timeline.undo()
        XCTAssertTrue(timeline.document.regions.isEmpty, "ONE Undo takes the part back")
        XCTAssertFalse(timeline.canUndo)

        for _ in 0..<3 {
            _ = MIDIImport.addEmptyPart(clipStore: clips, timeline: timeline)
            timeline.undo()
        }
        XCTAssertEqual(clips.filledClips.count, 1,
                       "New → Undo must reuse its empty clip, not spend a slot per cycle")
    }

    // MARK: 4 — source

    func testTheWorkstationRowHandsTheStoresOverAndSelectsThePart() throws {
        let view = try source(Self.workstationPath)
        let row = try body(of: "private var newMIDIPartRow: some View {", in: view)
        XCTAssertTrue(row.contains("Text(\"New MIDI Part\")"), "the row is no longer labelled")
        XCTAssertTrue(row.contains("MIDIImport.addEmptyPart(clipStore: clipStore, timeline: timeline)"),
                      "the view hands both stores over; the write is `MIDIImport`'s (claim F)")
        XCTAssertTrue(row.contains("selection.selectRegion(landing.region.id, in: timeline.document)"),
                      "the new part must be selected, so the part bar and Notes open on it")
        XCTAssertTrue(row.contains("importNote = failure.userMessage"),
                      "every refusal must say what happened on the one note line")
        XCTAssertTrue(view.contains("            importMIDIRow\n") && view.contains("            newMIDIPartRow\n"),
                      "the row must be mounted beside Import MIDI")

        XCTAssertEqual(try filesUnderSources(containing: "MIDIImport.addEmptyPart("),
                       ["Studio/WorkstationView.swift"],
                       "a second caller of the empty-part transaction needs this guard moved with it")

        let importer = try source(Self.importerPath)
        let commit = try body(of: "public static func addEmptyPart(", in: importer)
        let clip = try XCTUnwrap(commit.range(of: "clipStore.setClip("))
        let region = try XCTUnwrap(commit.range(of: "timeline.addRegion("))
        XCTAssertLessThan(clip.lowerBound, region.lowerBound,
                          "clip FIRST, region SECOND — playback resolves `clipID` through the grid")
        let refusal = try XCTUnwrap(commit.range(of: "case .failure"))
        XCTAssertLessThan(refusal.lowerBound, clip.lowerBound, "a refusal must return before any write")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    /// The brace-matched body after `anchor` (§2, #408 — never a fixed line window).
    private func body(of anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code.range(of: "{", range: start.lowerBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: \(anchor)")
            throw AnchorMissing(name: anchor)
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let ch = code[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing(name: anchor)
    }

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// `Sources/Echoelmusic`-relative paths of every Swift file whose CODE contains `needle`.
    private func filesUnderSources(containing needle: String) throws -> [String] {
        let root = repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(Self.sourcesRoot) — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var scanned = 0
        while let relative = walker.nextObject() as? String {
            guard relative.hasSuffix(".swift") else { continue }
            let code = try source("\(Self.sourcesRoot)/\(relative)")
            scanned += 1
            if code.contains(needle) { hits.append(relative) }
        }
        XCTAssertGreaterThan(scanned, 100, "the walk saw \(scanned) files — a short walk is not a pass")
        return hits.sorted()
    }
}

private extension Result {
    var failureValue: Failure? {
        if case .failure(let failure) = self { return failure }
        return nil
    }
}
