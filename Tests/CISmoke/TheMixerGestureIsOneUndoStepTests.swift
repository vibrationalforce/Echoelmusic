// TheMixerGestureIsOneUndoStepTests.swift
// Echoel — Workstation redesign B3b (founder 2026-10-01): a change made in the piece mixer is ONE
// step in the piece's Undo — one per gesture, never one per finger sample — while the agent's level
// writes stay out of that history.
//
// WHY: B3 gave every sounding track a strip (`PieceMixerView`) and the piece's Undo said "never mixer
// changes". A workstation takes a fader move back like any other edit. The obvious repair — a step
// inside `TrackMix.setLevel` — breaks `TheAgentActsThroughTheButtonsPathsTests` claim 2: the agent
// writes levels through that funnel and keeps its OWN way back, so one change would get two Undos.
// The history is therefore entered by a SEPARATE path: `TimelineStore.editLaneMix(id:_:)` wraps one
// person's write (the `TrackMix` call itself — the funnel stays the one writer) and remembers where
// the gesture began; `commitLaneMix(id:)` turns the finished gesture into ONE `.laneMix` step that
// moves back only the fields the gesture changed.
//
// THE FOUR CLAIMS:
// 1. END-TO-END over a REAL `TimelineStore`: four drag samples and one commit are ONE step; Undo
//    goes back to where the drag began, Redo to where it ended; a drag that returns to its start is
//    no step at all.
// 2. END-TO-END: a Mute tap is one step; the agent's path (`TrackMix.setLevel` alone) records
//    nothing; a write by someone else in the middle of a gesture restarts it; undoing a pan gesture
//    leaves a level written after it; and a field the gesture changed but someone wrote SINCE keeps
//    the later value — a mixer Undo never reverts a change made elsewhere (the store's
//    cross-contamination rule), and a step left with nothing to put back is dropped.
// 3. END-TO-END: a mixer step and a parts step do not touch each other; a level put back by Undo
//    counts as a level write (so the agent's own Undo then leaves it — review repair 2b's rule); a
//    step whose fields already read what it would restore (the Studio's Start healed the mute) is
//    dropped, so Undo never reads as available while it would do nothing.
// 4. SOURCE + CATALOG: the strip wraps Level/Pan per sample and closes each on `onCommit`, Mute and
//    Solo through one tap helper; the writes inside are still `TrackMix.*`; the files that record are
//    the four surfaces a hand reaches (B3c widened it from the piece mixer alone — the per-surface
//    wrap rule lives in `EveryHandMadeMixChangeIsOneUndoStepTests`); the agent never does;
//    `SongHistoryRow` no longer says "never mixer changes" nor "changed anywhere else"; the two
//    reworded labels have German lines (the hint's own line is checked by the B3c guard).
//
// GRADING (§0/§3, no Swift toolchain in a web session): against the parent this file does NOT
// COMPILE — `editLaneMix`/`commitLaneMix` do not exist — so no assertion has a verdict there: ONE
// absence (#486), all four claims FORWARD guards. Claims 1–3 hand-transcribed in Python over a model
// of `editLaneMix`/`commitLaneMix`/`apply(.laneMix)`/`unsilenceRollSlot`; mutants driven, each red for
// its named reason: a step per drag sample (claim 1, "no step while the finger is down"); a gesture
// that keeps its start across a stranger's write (claim 2, Undo lands on 1.00, not 0.75); an Undo
// that restores all four fields (claim 2, the later level is overwritten); an Undo that restores a
// changed field without checking it still reads the gesture's result (claim 2, 0.625 written since
// is overwritten with 0.25); no write count on a level
// Undo (claim 3); a step inside `TrackMix.setLevel` (claim 2, "the agent's path records nothing").
// Claim 4 transcribed against both trees: red on the parent by the same one absence.
// TAP-SEAM RE-GRADE (2026-10-02, claim 4's recorder census only): the header and Perform taps moved
// behind `TrackMix.tapStep`, so the census matcher also accepts that seam. Graded by transcription on
// both trees: the set is the same four files on the parent (`.editLaneMix(` inline) and here (seam);
// with the OLD matcher it would read [mixer, inspector] here — red on a correct tree, the reason for
// this edit. No assertion is removed or loosened: the list stays an exact equality.
// B3c RE-GRADE (2026-10-01, claim 4 only — claims 1–3 untouched): this file now COMPILES against its
// parent. REGRESSIONS there: two — the recorder list (the parent records from the piece mixer alone)
// and the hint (the parent still says "changed anywhere else"). COUNTERWEIGHTS, green on both: the
// strip's wrap/commit counts, the funnel needles, the bare `TrackMix.setLevel`, the agent's absence,
// "never mixer changes", and the two German labels. Stripper PROPHYLAKTISCH (0 of the scan verdicts
// flip raw vs. stripped on either tree).
// NOT covered: that a strip FEELS like one gesture under a finger, and that a mixer Undo while the
// piece plays is heard at once — device readings.
// NEEDS-FOUNDER-VERIFY: Workstation → Mix → drag a track's Level, tap Mute, then the head's Undo
// twice — Mute comes back off, the level returns to where the drag began; once stopped, once playing.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheMixerGestureIsOneUndoStepTests: XCTestCase {

    private static let mixer = "Sources/Echoelmusic/Studio/PieceMixerView.swift"
    private static let perform = "Sources/Echoelmusic/Studio/PerformSessionView.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let inspector = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let history = "Sources/Echoelmusic/Studio/SongHistoryRow.swift"
    private static let executor = "Sources/Echoelmusic/EchoelAI/EchoelCommandExecutor.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"

    private static let bar = TimelineTime.ticksPerBar
    private static let clip = UUID()
    // One fixture VALUE per lane — never a factory (#1419). Keys is the Echoel track (the first
    // non-bio MIDI lane, `unsilenceRollSlot`'s target); Loop an audio track with all four controls.
    private static let bioLane = TimelineLane(name: "Body", kind: .midi, isBio: true)
    private static let keysLane = TimelineLane(name: "Keys", kind: .midi)
    private static let loopLane = TimelineLane(name: "Loop", kind: .audio)
    private static let loopPart = TimelineRegion(laneID: loopLane.id, clipID: clip, startTick: 0, lengthTicks: bar)
    private static let fixture = TimelineDocument(lanes: [bioLane, keysLane, loopLane], regions: [loopPart])

    /// The store loaded fresh, its prior document handed back so each claim restores it
    /// (`TimelineStore()` loads whatever an earlier run persisted). The Open clears the history.
    private func rig() -> (TimelineStore, TimelineDocument) {
        let timeline = TimelineStore()
        let original = timeline.document
        timeline.replaceDocument(Self.fixture)
        return (timeline, original)
    }

    private func lane(_ lane: TimelineLane, in timeline: TimelineStore) -> TimelineLane? {
        timeline.document.lanes.first(where: { $0.id == lane.id })
    }

    // MARK: 1 — a drag is one step

    func testADragIsOneUndoStep() {
        let (timeline, original) = rig()
        defer { timeline.replaceDocument(original) }
        let loop = Self.loopLane.id
        XCTAssertFalse(timeline.canUndo, "an Open clears the history (`replaceDocument`) — the claim starts from nothing")
        for sample in [0.875, 0.75, 0.625, 0.5] {
            timeline.editLaneMix(id: loop) { TrackMix.setLevel(sample, laneID: loop, timeline: timeline) }
            XCTAssertFalse(timeline.canUndo, "no step while the finger is down — one per sample would take four Undos to take back one move")
        }
        timeline.commitLaneMix(id: loop)
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.level, 0.5)
        XCTAssertTrue(timeline.canUndo, "the finished gesture is a step")
        timeline.undo()
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.level, 1, "Undo takes the whole drag back to where it began")
        XCTAssertFalse(timeline.canUndo, "one gesture, one step")
        timeline.redo()
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.level, 0.5, "Redo puts it where the drag ended")

        // A drag that comes back to where it started is not an edit.
        timeline.editLaneMix(id: loop) { TrackMix.setLevel(0.75, laneID: loop, timeline: timeline) }
        timeline.editLaneMix(id: loop) { TrackMix.setLevel(0.5, laneID: loop, timeline: timeline) }
        timeline.commitLaneMix(id: loop)
        timeline.undo()
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.level, 1, "the round trip left no step — Undo reached the drag before it")
        XCTAssertFalse(timeline.canUndo)
    }

    // MARK: 2 — a tap is one step; only the person's gesture is taken back

    func testATapIsOneStepAndOnlyThePersonsGestureIsTakenBack() {
        let (timeline, original) = rig()
        defer { timeline.replaceDocument(original) }
        let loop = Self.loopLane.id
        timeline.editLaneMix(id: loop) { TrackMix.flipMute(laneID: loop, timeline: timeline) }
        timeline.commitLaneMix(id: loop)
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.isMuted, true)
        timeline.undo()
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.isMuted, false, "Undo un-mutes")
        XCTAssertFalse(timeline.canUndo, "a tap is one step")

        TrackMix.setLevel(0.875, laneID: loop, timeline: timeline)
        XCTAssertFalse(timeline.canUndo, """
            the agent's path — `TrackMix.setLevel` alone — records nothing in the piece's history; the \
            agent keeps its own way back (TheAgentActsThroughTheButtonsPathsTests claim 2)
            """)

        timeline.editLaneMix(id: loop) { TrackMix.setLevel(0.5, laneID: loop, timeline: timeline) }
        TrackMix.setLevel(0.75, laneID: loop, timeline: timeline)   // someone else, mid-gesture
        timeline.editLaneMix(id: loop) { TrackMix.setLevel(0.375, laneID: loop, timeline: timeline) }
        timeline.commitLaneMix(id: loop)
        timeline.undo()
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.level, 0.75,
                       "Undo takes back the person's gesture, never the write that came in between")

        timeline.editLaneMix(id: loop) { TrackMix.setPan(-0.5, laneID: loop, timeline: timeline) }
        timeline.commitLaneMix(id: loop)
        TrackMix.setLevel(0.25, laneID: loop, timeline: timeline)   // a later level, not part of the gesture
        timeline.undo()
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.pan, 0, "the pan gesture is taken back")
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.level, 0.25,
                       "a mixer Undo moves only the fields its gesture changed — a level written since stays")
        timeline.redo()
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.pan, -0.5)
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.level, 0.25)

        // A field the gesture changed, written by someone else SINCE: Undo keeps the later value and,
        // with nothing left to put back, drops the step and takes the one before it (the pan gesture).
        timeline.editLaneMix(id: loop) { TrackMix.setLevel(0.5, laneID: loop, timeline: timeline) }
        timeline.commitLaneMix(id: loop)
        TrackMix.setLevel(0.625, laneID: loop, timeline: timeline)   // the inspector or the agent, later
        timeline.undo()
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.level, 0.625, """
            a mixer Undo never reverts a level written after its gesture — the store's \
            cross-contamination rule, and what the hint promises ("not … changed anywhere else")
            """)
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.pan, 0,
                       "the emptied step is dropped and the one before it — the pan gesture — is taken")
    }

    // MARK: 3 — separate kinds; the agent sees the Undo; a dead step is dropped

    func testTheMixerAndThePartsAreSeparateSteps() {
        let (timeline, original) = rig()
        defer { timeline.replaceDocument(original) }
        let loop = Self.loopLane.id
        let extra = TimelineRegion(laneID: loop, clipID: Self.clip, startTick: 4 * Self.bar, lengthTicks: Self.bar)
        timeline.addRegion(extra)
        timeline.editLaneMix(id: loop) { TrackMix.setLevel(0.5, laneID: loop, timeline: timeline) }
        timeline.commitLaneMix(id: loop)
        let writes = timeline.laneLevelWrites[loop] ?? 0
        timeline.undo()
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.level, 1, "the mixer step is the newest")
        XCTAssertTrue(timeline.document.regions.contains { $0.id == extra.id }, "a mixer step cannot touch a part")
        XCTAssertEqual(timeline.laneLevelWrites[loop] ?? 0, writes + 1, """
            a level put back by Undo is a write — without the count the agent's own Undo would \
            overwrite the person's Undo with the value it once replaced (review repair 2b)
            """)
        timeline.undo()
        XCTAssertFalse(timeline.document.regions.contains { $0.id == extra.id }, "the parts step is next")
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.level, 1, "a parts step cannot touch a fader")

        let keys = Self.keysLane.id
        timeline.editLaneMix(id: keys) { TrackMix.flipMute(laneID: keys, timeline: timeline) }
        timeline.commitLaneMix(id: keys)
        XCTAssertEqual(lane(Self.keysLane, in: timeline)?.isMuted, true)
        timeline.unsilenceRollSlot()   // the instrument's Start heals the Echoel track
        XCTAssertEqual(lane(Self.keysLane, in: timeline)?.isMuted, false)
        XCTAssertTrue(timeline.canUndo)
        timeline.undo()
        XCTAssertFalse(timeline.canUndo, "a step that would change nothing is dropped, not left reading as available")
        XCTAssertEqual(lane(Self.keysLane, in: timeline)?.isMuted, false)
    }

    // MARK: 4 — source and catalog

    func testTheStripRecordsAndTheAgentsFunnelStaysBare() throws {
        let mixer = SourceText.codeOnly(try text(Self.mixer))
        let strip = try member("private func strip(_ lane: TimelineLane, _ controls: TrackMix.Controls) -> some View {", in: mixer)
        XCTAssertEqual(strip.components(separatedBy: "timeline.editLaneMix(id: lane.id) {").count - 1, 2,
                       "Level and Pan run every finger sample inside the gesture")
        XCTAssertEqual(strip.components(separatedBy: "onCommit: { timeline.commitLaneMix(id: lane.id) }").count - 1, 2,
                       "Level and Pan close their gesture once, on the field's commit — never per sample")
        XCTAssertEqual(strip.components(separatedBy: "tapped(lane.id) {").count - 1, 2, "Mute and Solo are one-tap gestures")
        let helper = try member("private func tapped(_ laneID: UUID, _ write: () -> Void) {", in: mixer)
        XCTAssertTrue(helper.contains("timeline.editLaneMix(id: laneID, write)"), "the tap runs its write inside the gesture")
        XCTAssertTrue(helper.contains("timeline.commitLaneMix(id: laneID)"), "and closes it at once")
        for writer in ["TrackMix.setLevel(newLevel, laneID: lane.id, timeline: timeline)",
                       "TrackMix.setPan(newPan, laneID: lane.id, timeline: timeline)",
                       "TrackMix.flipMute(laneID: lane.id, timeline: timeline)",
                       "TrackMix.flipSolo(laneID: lane.id, timeline: timeline)"] {
            XCTAssertTrue(strip.contains(writer), "the write inside the gesture is still the funnel: `\(writer)`")
        }

        // Since the tap seam (2026-10-02): the track header and the Perform grid record through
        // `TrackMix.tapStep` — it opens and closes the gesture inside `TrackMix` — so a recorder is a
        // file that opens a gesture OR taps through the seam. Same four surfaces, same strictness.
        let recorders = try filesMatching { $0.contains(".editLaneMix(") || $0.contains("TrackMix.tapStep(") }
        XCTAssertEqual(recorders, [Self.perform, Self.mixer, Self.inspector, Self.workstation], """
            the surfaces whose edits enter the piece's Undo are the four a hand reaches (B3c). A new \
            recorder is welcome: add it here and check `SongHistoryRow`'s hint in the same commit, \
            because it says which mixer changes Undo covers.
            """)
        let executor = SourceText.codeOnly(try text(Self.executor))
        XCTAssertFalse(executor.contains("editLaneMix") || executor.contains("commitLaneMix"),
                       "the agent's level writes stay out of the piece's history — it keeps its own way back")
        let inspector = SourceText.codeOnly(try text(Self.inspector))
        let setLevel = try member("static func setLevel(_ level: Double, laneID: UUID, timeline: TimelineStore) {", in: inspector)
        XCTAssertTrue(setLevel.contains("timeline.setLaneLevel(id: laneID, Float(level))"),
                      "`TrackMix.setLevel` is still the bare funnel the agent and the gesture share")
        XCTAssertFalse(setLevel.contains("editLaneMix") || setLevel.contains("commitLaneMix") || setLevel.contains("pushUndo"),
                       "a step inside the shared funnel would give the agent's change two Undos")

        let history = SourceText.codeOnly(try text(Self.history))
        XCTAssertFalse(history.contains("never mixer changes"), "the hint no longer denies what Undo now does")
        XCTAssertFalse(history.contains("changed anywhere else"),
                       "since B3c the inspector, the track header and Perform record too — the hint no longer excludes them")

        let data = Data(try text(Self.catalog).utf8)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = root?["strings"] as? [String: Any] ?? [:]
        for key in ["Undo the last change to the piece's parts, notes, automation, mix or a relinked file",
                    "Redo the last undone change to the piece's parts, notes, automation, mix or a relinked file"] {
            let entry = strings[key] as? [String: Any]
            let localizations = entry?["localizations"] as? [String: Any] ?? [:]
            let en = (localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertEqual(en?["value"] as? String, key, "`\(key)` has its English line")
            XCTAssertEqual(Set(localizations.keys), ["en"], "`\(key)`: the app speaks one language (founder 2026-10-02) — no second unit")
        }
    }

    // MARK: helpers

    /// The brace-matched body after `anchor` (#408); string-literal aware.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            return ""
        }
        var depth = 1
        var index = start.upperBound
        var inString = false
        while index < code.endIndex {
            let ch = code[index]
            if inString, ch == "\\" {
                index = code.index(after: index)
                if index < code.endIndex { index = code.index(after: index) }
                continue
            }
            if ch == "\"" { inString.toggle() }
            if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(code[start.upperBound..<index]) }
                }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: `\(anchor)` never closes (#454)")
        return ""
    }

    /// Comment-stripped files under `Sources/Echoelmusic` for which `matches` holds, repo-relative, sorted.
    private func filesMatching(_ matches: (String) -> Bool) throws -> [String] {
        let base = "Sources/Echoelmusic"
        let root = repoRoot().appendingPathComponent(base)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(base) — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8) else { continue }
            if matches(SourceText.codeOnly(text)) { hits.append(base + "/" + relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return hits.sorted()
    }

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}
