// AGeneratedTakeCanBeKeptTests.swift
// Echoel — GMMW GA-2a ("Keep take: the store verb"). The composer rewrites its own clip on every
// Evolve (`ClipStore.updateComposerMelody`, gated on `composerOwned`) and the note editor refuses
// that clip (`ClipNoteEdit.acceptsEdits`). A take the person liked could neither be kept nor edited
// — and the only copy verb, `duplicateRegion`, shares the clip, so the copy would keep evolving too.
// `TimelineStore.keepComposerTake(regionID:clips:)` copies the composer part's clip into a NEW,
// user-owned clip in the first free slot and places it as a new part on the same track, from the
// first bar line after the track's last part. The composer's part is not touched.
//
// WHAT IT PINS.
// 1. PURE (`keptTakeStart`): the first bar line at or after the end of the track's last part — never
//    over a part, always on a downbeat; another track's parts do not count.
// 2. END-TO-END over a real `TimelineStore` + `ClipStore`: the kept clip holds the same notes, is
//    user-owned (the note editor takes it, the composer cannot rewrite it), lands in the first free
//    slot; the new part copies the composer part's length on the same track; the composer's part
//    and clip are untouched.
// 3. END-TO-END: ONE undo step removes the new part AND frees the slot (a `.regions` step alone
//    would leave the copy filling a slot for good); Redo puts both back; a slot refilled after the
//    Undo (an import) makes the Redo change nothing.
// 4. END-TO-END refusals write nothing and record no step: a user part, an unknown part, a full grid.
// 5. SOURCE: one `.keptTake` step is recorded, by the verb.
// GA-2b — THE DOOR ("Edit a copy" on the part bar, `PartEditCopyButton`):
// 6. END-TO-END: the button's rule (the note editor's own refusal, `.composerOwned`) and the verb
//    agree — where it shows, the verb keeps; on a user part and an audio part it neither shows nor
//    keeps.
// 7. SOURCE: the bar mounts the leaf once; the leaf decides on that refusal rule, writes the timeline
//    ONLY through `keepComposerTake` (the one call in `Sources/`), then selects the copy and opens its
//    notes; it reads no player or transport. COUNTERWEIGHT: the bar's own body still reads no clip grid.
//
// Grading (§0, no Swift toolchain): claims 1–5 (GA-2a, `c7d9704`) do NOT COMPILE on its parent
// (`854a621`) — they name `keepComposerTake` and `keptTakeStart` — so no assertion has a verdict there;
// they are FORWARD guards, transcribed into Python and driven through the same sequences. Against
// `c7d9704`, the parent of GA-2b: claim 6 is a COUNTERWEIGHT (green on both — it pins the agreement the
// door relies on); claim 7 is red there as ONE anchor absence (`PartEditCopyButton` does not exist,
// #486) plus one REGRESSION for its named reason (the verb has no caller). Claim 7 was transcribed and
// driven against both trees.
// NOT covered: how the button reads at large type sizes, whether VoiceOver speaks the announcement,
// and the copy opening on the Notes page — device probes. NEEDS-FOUNDER-VERIFY: select the composer's
// part on Arrange → "Edit a copy" → a new part after the last one on that track, its notes open and
// editable; the composer's part keeps evolving; Undo removes the copy.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class AGeneratedTakeCanBeKeptTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — where a kept take lands

    func testAKeptTakeLandsOnTheFirstBarAfterTheTracksLastPart() {
        let b = Self.bar
        let lane = UUID()
        let other = UUID()
        let source = TimelineRegion(laneID: lane, clipID: UUID(), startTick: 0, lengthTicks: 4 * b)
        func start(_ regions: [TimelineRegion]) -> Int {
            TimelineStore.keptTakeStart(after: source, in: TimelineDocument(lanes: [], regions: regions))
        }
        XCTAssertEqual(start([source]), 4 * b, "right after the composer's part")
        XCTAssertEqual(start([source, TimelineRegion(laneID: lane, clipID: UUID(), startTick: 5 * b, lengthTicks: b + 10)]),
                       7 * b, "after the track's LAST part, rounded up to a bar line")
        XCTAssertEqual(start([source, TimelineRegion(laneID: other, clipID: UUID(), startTick: 0, lengthTicks: 20 * b)]),
                       4 * b, "another track's parts do not push it")
        let short = TimelineRegion(laneID: lane, clipID: UUID(), startTick: 0, lengthTicks: 3 * b + 1)
        XCTAssertEqual(TimelineStore.keptTakeStart(after: short, in: TimelineDocument(lanes: [], regions: [short])),
                       4 * b, "never inside a bar: the next downbeat")
    }

    // MARK: 2 — the kept take is the person's, and the composer's part is untouched

    func testKeepingCopiesTheNotesIntoAUserPartOnTheSameTrack() throws {
        try withStores { timeline, clips, composed, composerRegion in
            let before = timeline.document.regions
            let part = try XCTUnwrap(timeline.keepComposerTake(regionID: composerRegion.id, clips: clips),
                                     "a composer MIDI part can be kept")
            let kept = try XCTUnwrap(clips.clip(id: part.clipID))
            XCTAssertNotEqual(kept.id, composed.id, "a NEW clip — a shared one would keep evolving")
            XCTAssertEqual(kept.melody?.notes, composed.melody?.notes, "the take as heard")
            XCTAssertFalse(kept.composerOwned, "the person's clip: generate/evolve can never rewrite it")
            XCTAssertTrue(ClipNoteEdit.acceptsEdits(kept), "the note editor takes it")
            XCTAssertFalse(ClipNoteEdit.acceptsEdits(composed), "COUNTERWEIGHT: the composer's own clip is still refused")
            XCTAssertEqual(clips.slots.firstIndex { $0?.id == kept.id }, 1, "the first free slot")
            XCTAssertEqual(part.laneID, composerRegion.laneID, "on the same track")
            XCTAssertEqual(part.lengthTicks, composerRegion.lengthTicks, "as long as the composer's part")
            XCTAssertEqual(part.startTick, 4 * Self.bar, "after the composer's part, on a bar line")
            XCTAssertEqual(timeline.document.regions, before + [part], "one part added, none moved")
            XCTAssertEqual(clips.clip(id: composed.id), composed, "the composer's clip is untouched")
            XCTAssertTrue(timeline.canUndo, "one undo step")
        }
    }

    // MARK: 3 — one step takes back the part AND the slot

    func testOneUndoRemovesThePartAndFreesTheSlot() throws {
        try withStores { timeline, clips, composed, composerRegion in
            let before = timeline.document.regions
            let part = try XCTUnwrap(timeline.keepComposerTake(regionID: composerRegion.id, clips: clips))
            let kept = try XCTUnwrap(clips.clip(id: part.clipID))

            timeline.undo()
            XCTAssertEqual(timeline.document.regions, before, "Undo removes the kept part")
            XCTAssertNil(clips.slots[1], "…and frees its slot in the same step")
            XCTAssertEqual(clips.clip(id: composed.id), composed, "the composer's clip is untouched")
            XCTAssertFalse(timeline.canUndo, "it was ONE step")

            timeline.redo()
            XCTAssertEqual(clips.slots[1]?.id, kept.id, "Redo puts the same clip back in its slot")
            XCTAssertEqual(timeline.document.regions, before + [part], "…and the part")

            timeline.undo()
            let importClip = Clip(name: "GA-2a import", kind: .midi, melody: MelodyClip(notes: []))
            clips.setClip(at: 1, importClip)
            timeline.redo()
            XCTAssertEqual(clips.slots[1]?.id, importClip.id, "a slot refilled since keeps what fills it")
            XCTAssertEqual(timeline.document.regions, before, "…and the Redo changes nothing")
            XCTAssertFalse(timeline.canRedo)
        }
    }

    // MARK: 4 — refusals write nothing

    func testARefusedKeepWritesNothing() throws {
        try withStores { timeline, clips, _, _ in
            let userClip = Clip(name: "GA-2a user", kind: .midi, melody: MelodyClip(notes: [Note(pitch: 64, startStep: 0)]))
            clips.setClip(at: 2, userClip)
            let lane = try XCTUnwrap(timeline.document.lanes.first)
            let userPart = TimelineRegion(laneID: lane.id, clipID: userClip.id, startTick: 8 * Self.bar, lengthTicks: Self.bar)
            timeline.replaceDocument(TimelineDocument(lanes: timeline.document.lanes,
                                                      regions: timeline.document.regions + [userPart]))
            let slots = clips.slots
            let regions = timeline.document.regions

            XCTAssertNil(timeline.keepComposerTake(regionID: userPart.id, clips: clips), "a user part is already the person's")
            XCTAssertNil(timeline.keepComposerTake(regionID: UUID(), clips: clips), "an unknown part")
            XCTAssertEqual(clips.slots, slots)
            XCTAssertEqual(timeline.document.regions, regions)
            XCTAssertFalse(timeline.canUndo, "a refusal leaves no dead undo step")
        }
    }

    func testAFullGridKeepsNothing() throws {
        try withStores { timeline, clips, composed, composerRegion in
            var grid: [Clip?] = (0..<ClipStore.slotCount).map { index in
                Clip(name: "GA-2a fill \(index)", kind: .midi, melody: MelodyClip(notes: []))
            }
            grid[0] = composed
            XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: a full grid")
            let regions = timeline.document.regions
            XCTAssertNil(timeline.keepComposerTake(regionID: composerRegion.id, clips: clips),
                         "a full grid: no user clip is displaced (the never-clobber law)")
            XCTAssertEqual(clips.slots, grid)
            XCTAssertEqual(timeline.document.regions, regions)
            XCTAssertFalse(timeline.canUndo)
        }
    }

    // MARK: 5 — one recorder of the step

    func testTheStepIsRecordedByTheVerbAlone() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let text = try String(contentsOf: root.appendingPathComponent("Sources/Echoelmusic/Core/TimelineStore.swift"),
                              encoding: .utf8)
        let code = SourceText.codeOnly(text)
        XCTAssertEqual(code.components(separatedBy: "pushUndo(.keptTake(").count - 1, 1,
                       "one place records a kept take: `keepComposerTake`")
        guard let verb = code.range(of: "public func keepComposerTake(regionID: UUID, clips: ClipStore) -> TimelineRegion? {"),
              let push = code.range(of: "pushUndo(.keptTake(") else {
            return XCTFail("ANCHOR MISSING: the verb or its step (#454)")
        }
        XCTAssertLessThan(verb.lowerBound, push.lowerBound, "the step is pushed inside the verb, after its declaration")
    }

    // MARK: 6 — the door's rule and the verb agree

    func testTheButtonShowsExactlyWhereTheVerbKeeps() throws {
        try withStores { timeline, clips, composed, composerRegion in
            let lane = try XCTUnwrap(timeline.document.lanes.first)
            let userClip = Clip(name: "GA-2b user", kind: .midi, melody: MelodyClip(notes: []))
            let audioClip = Clip(name: "GA-2b audio", kind: .audio, mediaRef: "ga2b.wav")
            clips.setClip(at: 2, userClip)
            clips.setClip(at: 3, audioClip)
            let userPart = TimelineRegion(laneID: lane.id, clipID: userClip.id, startTick: 8 * Self.bar, lengthTicks: Self.bar)
            let audioPart = TimelineRegion(laneID: lane.id, clipID: audioClip.id, startTick: 12 * Self.bar, lengthTicks: Self.bar)
            timeline.replaceDocument(TimelineDocument(lanes: timeline.document.lanes,
                                                      regions: timeline.document.regions + [userPart, audioPart]))

            XCTAssertNotEqual(ClipNoteEdit.refusal(clip: userClip, region: userPart), .composerOwned,
                              "a user part: the editor takes it, so no button")
            XCTAssertNil(timeline.keepComposerTake(regionID: userPart.id, clips: clips), "…and the verb keeps nothing")
            XCTAssertNotEqual(ClipNoteEdit.refusal(clip: audioClip, region: audioPart), .composerOwned,
                              "an audio part: no notes, so no button")
            XCTAssertNil(timeline.keepComposerTake(regionID: audioPart.id, clips: clips), "…and the verb keeps nothing")
            XCTAssertEqual(ClipNoteEdit.refusal(clip: composed, region: composerRegion), .composerOwned,
                           "the composer's part: the editor refuses it for being the composer's, so the button shows")
            XCTAssertNotNil(timeline.keepComposerTake(regionID: composerRegion.id, clips: clips),
                            "…and where the button shows, the verb keeps")
        }
    }

    // MARK: 7 — the door: one leaf, one write

    func testTheEditACopyButtonCallsOnlyTheVerb() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let text = try String(contentsOf: root.appendingPathComponent("Sources/Echoelmusic/Studio/SelectedPartBar.swift"),
                              encoding: .utf8)
        let code = SourceText.codeOnly(text)
        let bar = try member("struct SelectedPartBar: View {", in: code)
        let barBody = try member("var body: some View {", in: bar)
        XCTAssertEqual(barBody.components(separatedBy: "PartEditCopyButton(regionID: regionID)").count - 1, 1,
                       "the part bar mounts the Edit a copy leaf once")
        XCTAssertFalse(barBody.contains("clipStore."),
                       "COUNTERWEIGHT: the bar's body reads no clip grid — the leaf does, in its own body")

        let leaf = try member("private struct PartEditCopyButton: View {", in: code)
        XCTAssertTrue(leaf.contains("ClipNoteEdit.refusal(clip: clipStore.clip(id: region.clipID), region: region) == .composerOwned"),
                      "it shows exactly where the note editor refuses a part for being the composer's (#416)")
        XCTAssertEqual(leaf.components(separatedBy: "timeline.keepComposerTake(regionID: regionID, clips: clipStore)").count - 1, 1,
                       "its one write is the store's verb")
        let timelineUses = leaf.components(separatedBy: "timeline.").dropFirst()
        XCTAssertFalse(timelineUses.isEmpty, "ANCHOR: the leaf reads the timeline")
        for use in timelineUses {
            XCTAssertTrue(use.hasPrefix("document") || use.hasPrefix("keepComposerTake("),
                          "the leaf touches the timeline with `\(use.prefix(30))` — only the document and the verb (one undo step)")
        }
        XCTAssertTrue(leaf.contains("selection.selectRegion(copy.id"), "the copy is selected")
        XCTAssertTrue(leaf.contains("selection.setNotesOpen(true)"), "…and its notes open")
        for hot in ["player.", "transport.", "TimelineRegionPlayer", "Transport.self"] {
            XCTAssertFalse(leaf.contains(hot), "`\(hot)` in the Edit a copy leaf — it reads nothing that moves with the song")
        }

        var calls = 0
        let sources = root.appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: sources.path) else {
            return XCTFail("cannot enumerate Sources/Echoelmusic — a scan that saw nothing is not a pass")
        }
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let file = try? String(contentsOf: sources.appendingPathComponent(relative), encoding: .utf8) else { continue }
            calls += SourceText.codeOnly(file).components(separatedBy: ".keepComposerTake(").count - 1
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        XCTAssertEqual(calls, 1, "one door keeps a take: the part bar's Edit a copy")
    }

    // MARK: rig

    private func withStores(_ body: (TimelineStore, ClipStore, Clip, TimelineRegion) throws -> Void) throws {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        let notes = [Note(pitch: 60, startStep: 0), Note(pitch: 67, startStep: 4)]
        let composed = Clip(name: "Composed · GA-2a", kind: .midi, melody: MelodyClip(notes: notes), composerOwned: true)
        var grid = [Clip?](repeating: nil, count: ClipStore.slotCount)
        grid[0] = composed
        XCTAssertTrue(clips.replaceSlots(grid), "fixture premise: the grid takes the composer's clip")
        let lane = TimelineLane(name: "GA-2a", kind: .midi)
        let region = TimelineRegion(laneID: lane.id, clipID: composed.id, startTick: 0, lengthTicks: 4 * Self.bar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [region]))
        XCTAssertFalse(timeline.canUndo, "fixture premise: a fresh history")
        try body(timeline, clips, composed, region)
    }

    private struct AnchorMissing: Error { let reason: String }

    /// The text inside the braces that open at the first `{` from `head` on (#408 — never a window).
    private func member(_ head: String, in text: String) throws -> String {
        guard let start = text.range(of: head),
              let open = text[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: `\(head)` (#454)")
            throw AnchorMissing(reason: head)
        }
        var depth = 1
        var index = text.index(after: open)
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: open)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED: `\(head)` never closes (#454)")
        throw AnchorMissing(reason: head)
    }
}
