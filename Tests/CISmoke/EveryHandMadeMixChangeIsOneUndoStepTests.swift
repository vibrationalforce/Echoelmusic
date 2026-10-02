// EveryHandMadeMixChangeIsOneUndoStepTests.swift
// Echoel — Workstation redesign B3c (plan 2026-10-01, phase B): a track's level, pan, Mute or Solo
// set by a person is ONE step in the piece's Undo wherever the hand reaches it — the piece mixer
// (B3b), the inspector's Level/Pan, the track header's M/S, the Perform grid's Mute/Solo.
//
// WHY: B3b gave the piece mixer a separate person's path into the history (`editLaneMix` +
// `commitLaneMix`, `.laneMix`) and left the three other surfaces bare, so the SAME fader move was
// undoable in Mix and not in the inspector, and the head's hint had to say "not … anywhere else".
// The bare funnel stays bare on purpose: the agent writes levels through `TrackMix.setLevel` and
// keeps its own way back (`TheAgentActsThroughTheButtonsPathsTests` claim 2), so the step is entered
// at the CALL SITE — the person's — never inside `TrackMix`.
//
// THE FIVE CLAIMS (claims 1–3 and 5 are SOURCE-TEXT SCANS; claim 4 is END-TO-END over a real store):
// 1. SOURCE: the inspector's Level and Pan fields run every finger sample inside
//    `timeline.editLaneMix(id: laneID)` and close the gesture on the field's `onCommit` — one step
//    per drag, never one per sample; the write inside is still the `TrackMix` funnel.
// 2. SOURCE: the track header's M/S and the Perform grid's Mute/Solo are each a whole gesture — the
//    flip inside `editLaneMix`, then `commitLaneMix` at once.
// 3. CENSUS over `Sources/Echoelmusic`: the store's four mixer writers are called only inside
//    `TrackMix`; every call of a `TrackMix` mixer writer (`setLevel`, `setPan`, `flipMute`,
//    `flipSolo`) outside the agent's executor sits directly inside a gesture (`editLaneMix(id: …) {`
//    or the piece mixer's `tapped(lane.id) {`); and every file that opens a gesture also closes one
//    (`commitLaneMix(`) — a wrap without a close records nothing and leaks its start into the next
//    gesture on that track. A FIFTH surface that wraps and closes passes; one that writes bare goes
//    red here, because its change would be the one the hint promises and Undo silently skips. The
//    census also requires the four known surfaces, so a walk that found nothing cannot pass.
// 4. END-TO-END over a REAL `TimelineStore`: the three closure shapes of claims 1–2, re-typed here
//    (a `View`'s private members cannot be driven from this bundle), stack as three steps in gesture
//    order; Undo walks them back one by one; an agent level written in between records nothing and
//    survives the Undo of a gesture on the same track (B3b's cross-contamination rule).
// 5. SOURCE + CATALOG: `SongHistoryRow`'s hint says a track's level, pan, mute or solo is covered
//    (since B2b also a track's picked sound — `TheSoundChoiceIsOneUndoStepTests`; the key moved, this claim did not)
//    and names the one writer a person can see that is not (the Studio instrument's Start); its
//    German line exists, `extractionState` manual, with a comment.
//
// GRADING (Tests/CISmoke/CLAUDE.md §3; no Swift toolchain in a web session — transcribed in Python
// against both trees): the file COMPILES against the parent (it names no new symbol — `editLaneMix`
// and `commitLaneMix` exist since B3b). On the parent: REGRESSIONS — claim 1 (inspector `set:` bare,
// no `onCommit`), claim 2 (header and Perform flip bare), claim 5 (hint text absent); claim 3's wrap
// and close rules are red on the parent for the SAME three bare surfaces (one finding, #486 — they
// exist to catch a fourth). ANCHOR ABSENCE: none (every anchor exists on both trees). COUNTERWEIGHTS,
// green on both: claim 4 whole (it drives store API B3b shipped — it pins the composition, it cannot
// fail for the surfaces' sake), and inside claims 1–3 the "still through the funnel" needles, the
// "store writers only inside `TrackMix`" census and the census floor.
// STRIPPER: `SourceText.codeOnly` is PROPHYLAKTISCH here — 0 of the scan verdicts flip raw vs.
// stripped on either tree (measured over every `Sources/Echoelmusic` file for claim 3).
// NOT covered: that the three surfaces FEEL like one gesture under a finger, that an Undo while the
// piece plays is heard at once, and two cases that fold two gestures into one step — a tap on the
// header during an inspector drag on the same track, and a drag SwiftUI cancels without the field's
// revert running (`EchoelValueField`'s stated honest limit), whose open start the next tap inherits.
// Both are B3b store behaviour, reached from more surfaces now — device readings, not scans.
// NEEDS-FOUNDER-VERIFY: Workstation → open a track → drag its Level in the inspector, tap M in the
// track header, switch to Perform and tap Solo on another track; then the head's Undo three times —
// Solo off, Mute off, level back where the drag began; once stopped, once playing.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class EveryHandMadeMixChangeIsOneUndoStepTests: XCTestCase {

    private static let inspector = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let perform = "Sources/Echoelmusic/Studio/PerformSessionView.swift"
    private static let mixer = "Sources/Echoelmusic/Studio/PieceMixerView.swift"
    private static let executor = "Sources/Echoelmusic/EchoelAI/EchoelCommandExecutor.swift"
    private static let history = "Sources/Echoelmusic/Studio/SongHistoryRow.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"

    /// The hint `SongHistoryRow` speaks — the one catalog key this slice rewords.
    private static let hint = "Covers moves, copies, splits, removals, imports, note edits, automation points, relinked files, the composer's part and a track's level, pan, mute, solo or picked sound — not the Studio instrument's own sound or what its Start changes"

    private static let bar = TimelineTime.ticksPerBar
    private static let clip = UUID()
    // One fixture VALUE per lane — never a factory (#1419). Keys is the Echoel track; Loop an audio
    // track with all four controls.
    private static let bioLane = TimelineLane(name: "Body", kind: .midi, isBio: true)
    private static let keysLane = TimelineLane(name: "Keys", kind: .midi)
    private static let loopLane = TimelineLane(name: "Loop", kind: .audio)
    private static let loopPart = TimelineRegion(laneID: loopLane.id, clipID: clip, startTick: 0, lengthTicks: bar)
    private static let fixture = TimelineDocument(lanes: [bioLane, keysLane, loopLane], regions: [loopPart])

    // MARK: 1 — the inspector's Level and Pan are drags with one step each

    func testTheInspectorsLevelAndPanAreOneStepPerDrag() throws {
        let code = SourceText.codeOnly(try text(Self.inspector))
        let level = try member("if controls.level {", in: code)
        XCTAssertTrue(level.contains("timeline.editLaneMix(id: laneID) { TrackMix.setLevel(newLevel, laneID: laneID, timeline: timeline) }"),
                      "every Level sample runs inside the person's gesture, through the `TrackMix` funnel")
        XCTAssertTrue(level.contains("onCommit: { timeline.commitLaneMix(id: laneID) }"),
                      "the Level field closes its gesture once, on commit — never per sample")
        let pan = try member("if controls.pan {", in: code)
        XCTAssertTrue(pan.contains("timeline.editLaneMix(id: laneID) { TrackMix.setPan(newPan, laneID: laneID, timeline: timeline) }"),
                      "every Pan sample runs inside the person's gesture, through the `TrackMix` funnel")
        XCTAssertTrue(pan.contains("onCommit: { timeline.commitLaneMix(id: laneID) }"),
                      "the Pan field closes its gesture once, on commit")
        for bare in ["set: { TrackMix.setLevel($0", "set: { TrackMix.setPan($0"] {
            XCTAssertFalse(code.contains(bare), "`\(bare)` is the bare write — a drag no Undo can take back")
        }
    }

    // MARK: 2 — the header's and Perform's Mute/Solo are taps with one step each

    func testTheHeaderAndPerformTapsAreOneStepEach() throws {
        let view = SourceText.codeOnly(try text(Self.workstation))
        let header = try member("private func laneRow(_ row: WorkstationSummary.LaneRow) -> some View {", in: view)
        let perform = SourceText.codeOnly(try text(Self.perform))
        let grid = try member("private func mixRow(_ row: MixRow) -> some View {", in: perform)
        for (name, body) in [("the track header", header), ("the Perform grid", grid)] {
            for flip in ["flipMute", "flipSolo"] {
                XCTAssertTrue(body.contains("timeline.editLaneMix(id: row.id) { TrackMix.\(flip)(laneID: row.id, timeline: timeline) }"),
                              "\(name): `\(flip)` runs inside the person's gesture")
            }
            XCTAssertEqual(body.components(separatedBy: "timeline.commitLaneMix(id: row.id)").count - 1, 2,
                           "\(name): each of the two taps closes its gesture at once — one tap, one step")
        }
    }

    // MARK: 3 — census: no hand-reached mixer write outside a gesture

    func testNoHandMadeMixWriteBypassesTheGesture() throws {
        let writer = try NSRegularExpression(pattern: "TrackMix\\.(setLevel|setPan|flipMute|flipSolo)\\(")
        let wrapped = try NSRegularExpression(
            pattern: "(editLaneMix\\(id: [A-Za-z.]+\\)|tapped\\(lane\\.id\\)) \\{\\s*TrackMix\\.(setLevel|setPan|flipMute|flipSolo)\\(")
        let all = try sources()
        var writers: [String] = []
        for (path, code) in all where path != Self.executor {
            let range = NSRange(code.startIndex..., in: code)
            let count = writer.numberOfMatches(in: code, range: range)
            guard count > 0 else { continue }
            writers.append(path)
            XCTAssertEqual(wrapped.numberOfMatches(in: code, range: range), count, """
                \(path) writes a track's level, pan, Mute or Solo outside a gesture. A hand-made mixer \
                change must be one Undo step (B3c): wrap the write in `timeline.editLaneMix(id:)` and \
                close it with `commitLaneMix(id:)` — on the field's `onCommit`, or right after a tap. \
                A helper that does both (the piece mixer's `tapped(lane.id)`) is fine: add its call \
                shape to `wrapped` here. Only the agent's executor writes bare — it keeps its own way back.
                """)
            XCTAssertTrue(code.contains("commitLaneMix("), """
                \(path) opens mixer gestures but never closes one — without `commitLaneMix(id:)` no step \
                is recorded, and the open start leaks into the next gesture on that track.
                """)
        }
        // The funnel is the only door to the store's four mixer writers — a surface that called
        // `timeline.setLaneLevel(` itself would pass the wrap rule above without ever being seen.
        let direct = all.filter { entry in
            [".setLaneLevel(", ".setLanePan(", ".toggleMute(", ".toggleSolo("].contains { entry.1.contains($0) }
        }.map { $0.0 }.sorted()
        XCTAssertEqual(direct, [Self.inspector], """
            the store's mixer writers are called from \(direct) — only `TrackMix` (in \(Self.inspector)) \
            may call them, so that every hand-made write passes the funnel this census reads.
            """)
        for surface in [Self.inspector, Self.mixer, Self.perform, Self.workstation] {
            XCTAssertTrue(writers.contains(surface), """
                the census did not find a mixer write in \(surface) — a scan that sees nothing is not a \
                pass (#454). If the surface moved, move this list with it.
                """)
        }
    }

    // MARK: 4 — end to end: three surfaces, three steps, walked back in order

    func testThreeSurfacesStackThreeStepsAndUndoWalksThemBack() {
        let timeline = TimelineStore()
        let original = timeline.document
        timeline.replaceDocument(Self.fixture)
        defer { timeline.replaceDocument(original) }
        let loop = Self.loopLane.id
        let keys = Self.keysLane.id
        XCTAssertFalse(timeline.canUndo, "an Open clears the history — the claim starts from nothing")

        // The inspector's Level drag on Loop: what its `set:` runs per sample, then its `onCommit`.
        for sample in [0.75, 0.5] {
            timeline.editLaneMix(id: loop) { TrackMix.setLevel(sample, laneID: loop, timeline: timeline) }
        }
        timeline.commitLaneMix(id: loop)
        // The track header's M on Keys.
        timeline.editLaneMix(id: keys) { TrackMix.flipMute(laneID: keys, timeline: timeline) }
        timeline.commitLaneMix(id: keys)
        // The agent lowers Keys — its bare path, no step.
        TrackMix.setLevel(0.875, laneID: keys, timeline: timeline)
        // The Perform grid's Solo on Loop.
        timeline.editLaneMix(id: loop) { TrackMix.flipSolo(laneID: loop, timeline: timeline) }
        timeline.commitLaneMix(id: loop)

        timeline.undo()
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.isSoloed, false, "the newest step is the Perform tap")
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.level, 0.5, "a Solo step does not move the level")
        timeline.undo()
        XCTAssertEqual(lane(Self.keysLane, in: timeline)?.isMuted, false, "then the header tap")
        XCTAssertEqual(lane(Self.keysLane, in: timeline)?.level, 0.875,
                       "the agent's level, written after the tap, is not the tap's to take back")
        timeline.undo()
        XCTAssertEqual(lane(Self.loopLane, in: timeline)?.level, 1, "then the whole inspector drag, back to where it began")
        XCTAssertFalse(timeline.canUndo, "three gestures, three steps — the agent's write added none")
    }

    // MARK: 5 — the hint says what Undo now covers

    func testTheHistoryHintCoversEveryHandMadeMixChange() throws {
        let history = SourceText.codeOnly(try text(Self.history))
        XCTAssertTrue(history.contains(".accessibilityHint(\"\(Self.hint)\")"),
                      "the head's Undo hint says a track's level, pan, mute or solo is covered, wherever it was set")
        XCTAssertFalse(history.contains("changes made in Mix"),
                       "naming Mix alone would read as 'the inspector, the header and Perform are not covered'")
        let data = Data(try text(Self.catalog).utf8)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let entry = (root?["strings"] as? [String: Any])?[Self.hint] as? [String: Any] else {
            return XCTFail("ANCHOR MISSING: the hint's catalog entry (#454)")
        }
        XCTAssertEqual(entry["extractionState"] as? String, "manual")
        XCTAssertFalse((entry["comment"] as? String ?? "").isEmpty, "the entry says where it is read")
        let localizations = entry["localizations"] as? [String: Any] ?? [:]
        let en = (localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
        XCTAssertEqual(en?["state"] as? String, "translated")
        XCTAssertEqual(en?["value"] as? String, Self.hint, "the hint's English line is its key")
        XCTAssertEqual(Set(localizations.keys), ["en"], "the app speaks one language (founder 2026-10-02) — no second unit")
    }

    // MARK: helpers

    private func lane(_ lane: TimelineLane, in timeline: TimelineStore) -> TimelineLane? {
        timeline.document.lanes.first(where: { $0.id == lane.id })
    }

    /// The brace-matched body after `anchor` (#408); string-literal aware. Returns the text AFTER
    /// the anchor (the anchor itself is not part of the body).
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

    /// Every Swift file under `Sources/Echoelmusic`, comment-stripped, keyed by repo-relative path.
    private func sources() throws -> [(String, String)] {
        let base = "Sources/Echoelmusic"
        let root = repoRoot().appendingPathComponent(base)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(base) — a scan that saw nothing is not a pass")
            return []
        }
        var out: [(String, String)] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8) else { continue }
            out.append((base + "/" + relative, SourceText.codeOnly(text)))
        }
        XCTAssertGreaterThan(out.count, 200, "the walk saw \(out.count) files — the wrong directory")
        return out
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
