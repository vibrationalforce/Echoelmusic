// TheSoundChoiceIsOneUndoStepTests.swift
// Echoel — Workstation redesign B2b (plan `scratchpads/PLAN_WORKSTATION_REDESIGN_2026-10-01.md`,
// Phase B: "B2b Klangwahl in die Undo-Historie"). ⚠️ Not "Media B2b" — that name is the relink
// (`.clipSource`); this slice is the track's SOUND.
//
// WHY. B2a gave a POLY rack track a Sound row (`TrackMix.setSound` → `TimelineStore.setLanePatch`)
// and left the pick outside the piece's history: it could not be taken back, and a pick over the
// piece's kept copy (a sound no stored sound equals) lost that copy for good. The history is now
// entered by a SEPARATE person's path, the B3b shape: `TimelineStore.editLanePatch(id:_:)` runs the
// pick and records ONE `.lanePatch` step holding both sounds as VALUES (`SynthPatch?`, nil =
// Default). `setLanePatch` and `TrackMix.setSound` stay bare — the funnel a non-person writer takes
// (the agent's executor, as `TrackMix.setLevel` is for the mixer; it writes no sound today), and
// the contract `TimelineStoreLanePatchTests` states.
//
// WHAT IT PINS. END-TO-END on a real `TimelineStore` for 1–5; SOURCE-TEXT SCAN for 6–7.
// 1. A pick is one step: Undo gives the found sound back, Redo picks again; two picks, two steps.
// 2. Values, not ids: a pick over the piece's kept copy is undone to THAT copy, which no stored
//    sound holds — B2a's honest limit "a pick that replaces a kept copy loses it" now holds only
//    past the reach of the history.
// 3. A pick that writes nothing records nothing (the kept copy, an unknown id, Default at Default,
//    a re-pick, an unknown track — whose write never runs).
// 4. The bare writer and the bare funnel record nothing; Undo never takes back a sound written
//    since (the step is dropped) and never brings back a removed track.
// 5. A sound step and a mixer step on the same track are separate: neither Undo moves the other's field.
// 6. Source: the Sound row wraps its pick; `TrackMix.setSound` stays bare; every call of it in
//    `Sources/` outside the agent's executor sits inside `editLanePatch(id:) {`; only the funnel
//    calls the store's sound writer; the store writes a track's sound in ONE place, so Undo and
//    Redo go through `setLanePatch`.
// 7. The head's Undo hint names a track's picked sound, says the Studio instrument's own sound is
//    not covered (it is shaped in its Sound panel, outside this history), and is catalogued (with a German line until 2026-10-02).
//
// GRADING (Tests/CISmoke/CLAUDE.md §3). Against the parent this file does NOT COMPILE —
// `TimelineStore.editLanePatch` is new — so no assertion has a verdict there: ONE absence (#486).
// FORWARD guards: claims 1, 2, 3, 5, the wrap census of 6, and 7 (its hint text is new).
// COUNTERWEIGHTS (#343), true of the parent's code in intent though unbuildable there: claim 4's
// "the bare writer and funnel record nothing" (`TimelineStoreLanePatchTests` says the same of the
// writer), and claim 6's "the funnel still writes through `setLanePatch`", "only the funnel calls
// `.setLanePatch(`" and "one `.patch = ` write in the store".
// §0 transcription of claims 6–7 is OWED against the worktree as committed; claims 1–5 drive Swift
// and are graded by CI alone.
// STRIPPER: `SourceText.codeOnly` — expected PROPHYLAKTISCH (no comment in `Sources/` writes the
// call shapes `TrackMix.setSound(` or `.setLanePatch(`); measure raw vs. stripped when transcribing.
//
// ⛔ HONEST LIMITS. The history lives in memory: an Open, a relaunch or 50 later steps
// (`undoDepth`) drop it — and with it the kept copy a pick replaced. An Undo while the song plays
// re-primes the rack exactly as a pick does (held notes on every extra track stop once) — heard,
// not tested here. The Undo/Redo LABELS still say "parts, notes, automation, mix or a relinked
// file"; only the hint names the sound (two pinned label keys stay unmoved in this slice).
// NEEDS-FOUNDER-VERIFY: Workstation → Add MIDI Track → select it → Device → Sound: Bright Lead →
// the head's Undo → the Sound row reads Default again; Redo → Bright Lead; once stopped, once
// playing (held notes on the extra track stop once, the Echoel keeps its sound).

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSoundChoiceIsOneUndoStepTests: XCTestCase {

    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let storePath = "Sources/Echoelmusic/Core/TimelineStore.swift"
    private static let historyPath = "Sources/Echoelmusic/Studio/SongHistoryRow.swift"
    private static let catalogPath = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    private static let executorPath = "Sources/Echoelmusic/EchoelAI/EchoelCommandExecutor.swift"

    // One fixture VALUE per lane — never a factory (#1419). Keys is the Echoel track (the first
    // non-bio MIDI lane); Lead a poly rack track at Default; Kept a rack track holding the piece's
    // own copy of a sound no stored sound equals.
    private static let foreign = SynthPatch(name: "From another install", brightness: 0.77)
    private static let keysLane = TimelineLane(name: "Keys", kind: .midi)
    private static let leadLane = TimelineLane(name: "Lead", kind: .midi)
    private static let keptLane = TimelineLane(name: "Kept", kind: .midi, patch: foreign)
    private static let fixture = TimelineDocument(lanes: [keysLane, leadLane, keptLane], regions: [])

    /// The store loaded fresh, its prior document handed back so each claim restores it
    /// (`TimelineStore()` loads whatever an earlier run persisted). The Open clears the history.
    private func rig() -> (TimelineStore, TimelineDocument) {
        let timeline = TimelineStore()
        let original = timeline.document
        timeline.replaceDocument(Self.fixture)
        return (timeline, original)
    }

    private func library() throws -> [SynthPatch] {
        let sounds = SynthPatch.factory
        guard sounds.count >= 2, sounds[0] != sounds[1] else {
            XCTFail("ANCHOR MISSING: two different factory sounds (#454)")
            throw AnchorMissing()
        }
        return sounds
    }

    private func sound(of lane: TimelineLane, in timeline: TimelineStore) -> SynthPatch? {
        timeline.document.lanes.first(where: { $0.id == lane.id })?.patch
    }

    private func level(of lane: TimelineLane, in timeline: TimelineStore) -> Float? {
        timeline.document.lanes.first(where: { $0.id == lane.id })?.level
    }

    /// The Sound row's call shape, re-typed (a `View`'s private member cannot be driven from this
    /// bundle); claim 6 pins that the row really has this shape.
    private func pick(_ choice: TrackMix.SoundChoice, on lane: TimelineLane, from sounds: [SynthPatch],
                      in timeline: TimelineStore) {
        timeline.editLanePatch(id: lane.id) {
            TrackMix.setSound(choice, laneID: lane.id, library: sounds, timeline: timeline)
        }
    }

    // MARK: 1 — a pick is one step

    func testAPickIsOneUndoStepAndRedoPicksAgain() throws {
        let sounds = try library()
        let (timeline, original) = rig()
        defer { timeline.replaceDocument(original) }
        XCTAssertFalse(timeline.canUndo, "ANCHOR: an Open starts with an empty history")

        pick(.library(sounds[1].id), on: Self.leadLane, from: sounds, in: timeline)
        XCTAssertEqual(sound(of: Self.leadLane, in: timeline), sounds[1], "the pick lands as a copy")
        XCTAssertTrue(timeline.canUndo, "a pick is a step")
        timeline.undo()
        XCTAssertNil(sound(of: Self.leadLane, in: timeline), "Undo gives Default back")
        XCTAssertFalse(timeline.canUndo, "one pick, one step")
        XCTAssertTrue(timeline.canRedo)
        timeline.redo()
        XCTAssertEqual(sound(of: Self.leadLane, in: timeline), sounds[1], "Redo picks it again")

        pick(.library(sounds[0].id), on: Self.leadLane, from: sounds, in: timeline)
        timeline.undo()
        XCTAssertEqual(sound(of: Self.leadLane, in: timeline), sounds[1],
                       "two picks, two steps — the first Undo takes back the second pick only")
        timeline.undo()
        XCTAssertNil(sound(of: Self.leadLane, in: timeline))
        XCTAssertFalse(timeline.canUndo)
        XCTAssertNil(sound(of: Self.keysLane, in: timeline), "counterweight: the Echoel track is untouched")
        XCTAssertEqual(sound(of: Self.keptLane, in: timeline), Self.foreign, "counterweight: so is the other track")
    }

    // MARK: 2 — the step holds the sound, not an id

    func testThePiecesKeptCopyComesBackByValue() throws {
        let sounds = try library()
        XCTAssertFalse(sounds.contains(Self.foreign), "ANCHOR: the kept copy equals no stored sound")
        let (timeline, original) = rig()
        defer { timeline.replaceDocument(original) }
        XCTAssertEqual(TrackMix.soundChoice(of: Self.keptLane.id, in: timeline.document, library: sounds), .kept)

        pick(.library(sounds[1].id), on: Self.keptLane, from: sounds, in: timeline)
        XCTAssertEqual(sound(of: Self.keptLane, in: timeline), sounds[1], "the pick replaced the kept copy")
        timeline.undo()
        XCTAssertEqual(sound(of: Self.keptLane, in: timeline), Self.foreign,
                       "Undo brings back the piece's own copy — no stored sound could have resolved it")
        XCTAssertEqual(TrackMix.soundChoice(of: Self.keptLane.id, in: timeline.document, library: sounds), .kept,
                       "and the row shows it as the piece's copy again")

        pick(.standard, on: Self.keptLane, from: sounds, in: timeline)
        XCTAssertNil(sound(of: Self.keptLane, in: timeline), "Default over the kept copy clears it")
        timeline.undo()
        XCTAssertEqual(sound(of: Self.keptLane, in: timeline), Self.foreign, "and is undone the same way")
    }

    // MARK: 3 — a pick that writes nothing records nothing

    func testAPickThatWritesNothingRecordsNothing() throws {
        let sounds = try library()
        let (timeline, original) = rig()
        defer { timeline.replaceDocument(original) }

        pick(.kept, on: Self.keptLane, from: sounds, in: timeline)
        pick(.library(UUID()), on: Self.keptLane, from: sounds, in: timeline)
        pick(.standard, on: Self.leadLane, from: sounds, in: timeline)
        timeline.editLanePatch(id: UUID()) {
            XCTFail("a track the song does not hold runs no write")
        }
        XCTAssertFalse(timeline.canUndo, "the kept copy, an unknown sound, Default at Default and an unknown track are no step")
        XCTAssertEqual(timeline.document, Self.fixture, "and nothing moved")

        pick(.library(sounds[1].id), on: Self.leadLane, from: sounds, in: timeline)
        XCTAssertTrue(timeline.canUndo, "counterweight: a real change still records")
        pick(.library(sounds[1].id), on: Self.leadLane, from: sounds, in: timeline)
        timeline.undo()
        XCTAssertNil(sound(of: Self.leadLane, in: timeline),
                     "the re-pick of what already plays added no step — one Undo goes back to Default")
        XCTAssertFalse(timeline.canUndo)
    }

    // MARK: 4 — the bare paths record nothing; a later sound and a removed track are not taken back

    func testTheBarePathsRecordNothingAndALaterSoundIsNotTakenBack() throws {
        let sounds = try library()
        let (timeline, original) = rig()
        defer { timeline.replaceDocument(original) }

        timeline.setLanePatch(Self.leadLane.id, patch: sounds[0])
        XCTAssertFalse(timeline.canUndo, "`setLanePatch` alone is no step — the store's writer stays bare")
        TrackMix.setSound(.library(sounds[1].id), laneID: Self.leadLane.id, library: sounds, timeline: timeline)
        XCTAssertEqual(sound(of: Self.leadLane, in: timeline), sounds[1], "ANCHOR: the bare funnel wrote")
        XCTAssertFalse(timeline.canUndo, "nor is the bare funnel — only the row's wrap records")

        pick(.standard, on: Self.leadLane, from: sounds, in: timeline)
        timeline.setLanePatch(Self.leadLane.id, patch: sounds[0])
        timeline.undo()
        XCTAssertEqual(sound(of: Self.leadLane, in: timeline), sounds[0],
                       "a sound written since the pick is not the pick's to take back")
        XCTAssertFalse(timeline.canUndo, "the stale step is dropped, not kept for later")
        XCTAssertFalse(timeline.canRedo, "and nothing was undone")

        pick(.library(sounds[1].id), on: Self.keptLane, from: sounds, in: timeline)
        timeline.removeLaneIfEmpty(id: Self.keptLane.id)
        XCTAssertNil(timeline.document.lanes.first(where: { $0.id == Self.keptLane.id }),
                     "ANCHOR: the empty track is removed")
        timeline.undo()
        XCTAssertNil(timeline.document.lanes.first(where: { $0.id == Self.keptLane.id }),
                     "Undo of a sound never brings a removed track back")
        XCTAssertFalse(timeline.canUndo, "the step whose track is gone is dropped")
    }

    // MARK: 5 — the sound and the mix are separate steps

    func testTheSoundAndTheMixAreSeparateSteps() throws {
        let sounds = try library()
        let (timeline, original) = rig()
        defer { timeline.replaceDocument(original) }
        let lead = Self.leadLane.id
        let startLevel = level(of: Self.leadLane, in: timeline)

        timeline.editLaneMix(id: lead) { TrackMix.setLevel(0.5, laneID: lead, timeline: timeline) }
        timeline.commitLaneMix(id: lead)
        pick(.library(sounds[1].id), on: Self.leadLane, from: sounds, in: timeline)

        timeline.undo()
        XCTAssertNil(sound(of: Self.leadLane, in: timeline), "the first Undo takes back the sound")
        XCTAssertEqual(level(of: Self.leadLane, in: timeline), 0.5, "and leaves the level the gesture before it set")
        timeline.undo()
        XCTAssertEqual(level(of: Self.leadLane, in: timeline), startLevel, "the second takes back the level")
        XCTAssertNil(sound(of: Self.leadLane, in: timeline), "and leaves the sound alone")
        XCTAssertFalse(timeline.canUndo, "two kinds, two steps")
    }

    // MARK: 6 — source: the row wraps, the funnel stays bare, one writer in the store

    func testTheRowWrapsThePickAndTheFunnelStaysBare() throws {
        let inspector = try code(Self.inspectorPath)
        let row = try member("private var soundRow: some View {", in: inspector)
        XCTAssertTrue(row.contains("timeline.editLanePatch(id: laneID) {"),
                      "the Sound row's pick runs inside the person's step")
        XCTAssertTrue(row.contains("TrackMix.setSound(choice, laneID: laneID, library: patchStore.patches, timeline: timeline)"),
                      "the write inside the step is still the funnel")
        XCTAssertFalse(inspector.contains("set: { TrackMix.setSound($0"),
                       "the bare pick is a sound no Undo can take back")
        let funnel = try member(
            "static func setSound(_ choice: SoundChoice, laneID: UUID, library: [SynthPatch], timeline: TimelineStore) {",
            in: inspector)
        XCTAssertTrue(funnel.contains("timeline.setLanePatch(laneID, patch: next)"),
                      "counterweight: the funnel still writes through the store's one writer")
        for recorder in ["editLanePatch", "pushUndo", "editLaneMix", "commitLaneMix"] {
            XCTAssertFalse(funnel.contains(recorder),
                           "`TrackMix.setSound` stays bare (`\(recorder)`): the step belongs to the surface, as in B3b")
        }

        let call = try NSRegularExpression(pattern: "TrackMix\\.setSound\\(")
        let wrapped = try NSRegularExpression(pattern: "editLanePatch\\(id: [A-Za-z.]+\\) \\{\\s*TrackMix\\.setSound\\(")
        let all = try sources()
        var pickers: [String] = []
        for (path, text) in all where path != Self.executorPath {
            let range = NSRange(text.startIndex..., in: text)
            let count = call.numberOfMatches(in: text, range: range)
            guard count > 0 else { continue }
            pickers.append(path)
            XCTAssertEqual(wrapped.numberOfMatches(in: text, range: range), count, """
                \(path) picks a track's sound outside a step. A person's pick must be one Undo step \
                (B2b): wrap `TrackMix.setSound` in `timeline.editLanePatch(id:) { … }`. Only the \
                agent's executor calls the funnel bare — it keeps its own way back, as for levels (B3b).
                """)
        }
        XCTAssertTrue(pickers.contains(Self.inspectorPath), """
            the census did not find the Sound row's pick in \(Self.inspectorPath) — a scan that sees \
            nothing is not a pass (#454). If the row moved, move this anchor with it.
            """)
        let direct = all.filter { $0.1.contains(".setLanePatch(") }.map { $0.0 }.sorted()
        XCTAssertEqual(direct, [Self.inspectorPath], """
            the store's sound writer is called from \(direct) — only `TrackMix.setSound` (in \
            \(Self.inspectorPath)) may call it, so every pick passes the funnel the census above reads.
            """)

        let store = try code(Self.storePath)
        XCTAssertEqual(store.components(separatedBy: ".patch = ").count - 1, 1,
                       "a track's sound is written in ONE place in the store (`setLanePatch`) — Undo and Redo go through it")
        let recorder = try member("public func editLanePatch(id: UUID, _ write: () -> Void) {", in: store)
        XCTAssertTrue(recorder.contains("pushUndo(.lanePatch(laneID: id, before: before, after: after))"),
                      "the person's path records one step holding both sounds")
        let writer = try member("public func setLanePatch(_ laneID: UUID, patch: SynthPatch?) {", in: store)
        XCTAssertFalse(writer.contains("pushUndo"), "the store's writer records nothing itself")
    }

    // MARK: 7 — the head's hint names the picked sound and excludes the instrument's own, and is catalogued

    func testTheHistoryHintNamesThePickedSound() throws {
        let history = try code(Self.historyPath)
        guard let open = history.range(of: ".accessibilityHint(\""),
              let close = history.range(of: "\")", range: open.upperBound..<history.endIndex) else {
            XCTFail("ANCHOR MISSING: the head's Undo hint literal (#454)")
            throw AnchorMissing()
        }
        let hint = String(history[open.upperBound..<close.lowerBound])
        XCTAssertTrue(hint.contains("a track's level, pan, mute, solo or picked sound"),
                      "the hint names the sound picked in a track's Sound row among what Undo covers")
        XCTAssertTrue(hint.contains("not the Studio instrument's own sound or what its Start changes"),
                      "the instrument's own sound (its Sound panel) and its Start are not covered, and the hint says so")

        let data = try Data(contentsOf: repoURL(Self.catalogPath))
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: Any],
              let entry = strings[hint] as? [String: Any] else {
            XCTFail("ANCHOR MISSING: the hint's catalog entry (#454)")
            throw AnchorMissing()
        }
        XCTAssertEqual(entry["extractionState"] as? String, "manual")
        XCTAssertFalse((entry["comment"] as? String ?? "").isEmpty, "the entry says where it is read")
        let localizations = entry["localizations"] as? [String: Any] ?? [:]
        let en = (localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
        XCTAssertEqual(en?["state"] as? String, "translated")
        XCTAssertEqual(en?["value"] as? String, hint, "the catalogued hint is the one the head draws")
        XCTAssertEqual(Set(localizations.keys), ["en"], "the app speaks one language (founder 2026-10-02) — no second unit")
    }

    // MARK: - helpers

    private struct AnchorMissing: Error {}

    /// Brace-matched body after `anchor`, starting at its `{` (§2, #408).
    private func member(_ anchor: String, in text: String) throws -> String {
        guard let start = text.range(of: anchor),
              let open = text.range(of: "{", range: start.lowerBound..<text.endIndex) else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing()
        }
        var depth = 0
        var index = open.lowerBound
        while index < text.endIndex {
            let ch = text[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(text[open.lowerBound...index]) }
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing()
    }

    /// Every Swift file under `Sources/Echoelmusic`, comment-stripped, keyed by repo-relative path.
    private func sources() throws -> [(String, String)] {
        let base = "Sources/Echoelmusic"
        let root = repoURL(base)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("ANCHOR MISSING: cannot enumerate \(base) — a scan that saw nothing is not a pass (#454)")
            throw AnchorMissing()
        }
        var out: [(String, String)] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8) else { continue }
            out.append((base + "/" + relative, SourceText.codeOnly(text)))
        }
        XCTAssertGreaterThan(out.count, 200, "the walk saw \(out.count) files — the wrong directory")
        return out
    }

    private func repoURL(_ relativePath: String) -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root.appendingPathComponent(relativePath)
    }

    private func code(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: repoURL(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }
}
