// AStructureEditKeepsTheBarTests.swift
// Echoel — Phase 3 / Creation Workflow, MIDI editor slice M7: a part edited while the song plays
// stays in its bar.
//
// WHAT IT PINS. A STRUCTURAL edit made during playback — a part moved, trimmed, split, added or
// removed — is pulled in by `TimelineRegionPlayer.refreshStructure` on the next transport step.
// M5 fixed the NOTE edit's pull and left this one recorded open (review M2): it re-loaded the
// roll and the rack at the PREVIOUS step's tick (`lastTick`) with the roll's `step: 0`, BEFORE the
// cursor advanced. On a part longer than one bar that was wrong in two places, both audible:
//   · on a bar line, `lastTick` sits in the bar before — the roll and every rack track
//     re-entered the old bar and stayed one bar late until the part's next onset;
//   · mid-bar (15 of every 16 edits), `step: 0` told the roll's bar plan the load lands on a bar
//     line, so it staged no next bar — the roll then played its current bar twice and ran a bar
//     late (`ArrangementLoadPlan.plan` states both cases). A playhead drop mid-bar (`relocate`)
//     did the same.
// The repair splits the refresh: the DOCUMENT is still adopted before the advance (the wrap reads
// its loop length), the voices are re-driven by `chaseStructure` at this step's tick and step.
//
// 1. END-TO-END BEHAVIOUR over a real `TimelineRegionPlayer`, `ClipStore`, `PatternEngine` and
//    `PianoRollModel`: the roll's part is lengthened from two bars to three while the song plays.
//    On bar 2's line the roll holds bar 2 and the rack track plays its bar 2; mid-bar, the rack's
//    next bar still arrives on time.
// 2. SOURCE: the order of the two halves inside `transportStep`, the voice half's tick and step,
//    and the playhead drop's step. The roll's staged bar is private and its trigger needs a live
//    voice, so the roll's MID-BAR half is carried by this scan plus the pure plan claim in
//    `AMidPlayNoteEditKeepsTheBarTests` (claim 2), not by a driven roll.
//
// Grading (§0, no Swift toolchain in a web session): the pump, the plan's now-index and both
// orderings of the chase were transcribed into Python and driven on both trees. On the parent
// (`1481c6851`) this file COMPILES — it names no new symbol — and claims 1a (the roll holds bar 1,
// pitch 60, not 72) and 1b (the rack plays 48 again, not 50) are REGRESSIONS, red for the reason
// their messages give; claim 1c (mid-bar, the rack's bar 2 arrives on time) is a COUNTERWEIGHT,
// green on both — mid-bar, `lastTick` and this step share a bar, which is why the rack only lagged
// on a bar line; claim 2 is red on the parent by ANCHOR ABSENCE (one absence, #486).
// NOT covered: that it is HEARD in time on a device, and a relocate mid-bar under a running
// pattern (the rig's pattern never advances, so its next step is 0) — the scan carries that.
// NEEDS-FOUNDER-VERIFY: Workstation → a MIDI part two bars or longer on the first track, a second
// MIDI track with its own part → Play → while it loops, drag the first part's end one bar longer
// (or move another part) → both tracks keep their bars in order and together; drop the playhead
// mid-bar → the bar after the drop is the next bar of the part, not the same one again.

import Foundation
import XCTest
@testable import Echoelmusic

#if canImport(SwiftUI)
@MainActor
final class AStructureEditKeepsTheBarTests: XCTestCase {

    private static let steps = 16
    private static let playerPath = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"

    private var rigClips: ClipStore?
    private var rigPlayer: TimelineRegionPlayer?
    private var rigPattern: PatternEngine?

    /// Everything the rig plays, what the rack sink heard, and the document the store would
    /// hand the player (nil = no edit yet).
    private final class Rig {
        let player: TimelineRegionPlayer
        let roll: PianoRollModel
        let document: TimelineDocument
        var live: TimelineDocument?
        var heard: [LaneNotePump.Event] = []
        init(player: TimelineRegionPlayer, roll: PianoRollModel, document: TimelineDocument) {
            self.player = player; self.roll = roll; self.document = document
        }
    }

    /// Two MIDI tracks, each with ONE two-bar part from bar 1 — the `AMidPlayNoteEditKeepsTheBarTests`
    /// rig. The first track is the roll: bar 1 plays 60, bar 2 plays 72. The second rides a rack
    /// slot: bar 1 holds 48 for the whole bar, bar 2 plays 50.
    private func makeRig() -> Rig {
        let clips = ClipStore()
        for i in clips.slots.indices { clips.clear(at: i) }
        let rollClip = Clip(name: "Roll", melody: MelodyClip(notes: [
            Note(pitch: 60, startStep: 0, lengthSteps: 4),
            Note(pitch: 72, startStep: 16, lengthSteps: 4),
        ]))
        let rackClip = Clip(name: "Rack", melody: MelodyClip(notes: [
            Note(pitch: 48, startStep: 0, lengthSteps: 16),
            Note(pitch: 50, startStep: 16, lengthSteps: 4),
        ]))
        clips.setClip(at: 0, rollClip)
        clips.setClip(at: 1, rackClip)
        let first = TimelineLane(name: "Keys", kind: .midi)
        let second = TimelineLane(name: "Pad", kind: .midi)
        let bars = 2 * TimelineTime.ticksPerBar
        let document = TimelineDocument(lanes: [first, second], regions: [
            TimelineRegion(laneID: first.id, clipID: rollClip.id, startTick: 0, lengthTicks: bars),
            TimelineRegion(laneID: second.id, clipID: rackClip.id, startTick: 0, lengthTicks: bars),
        ])
        let player = TimelineRegionPlayer()
        let pattern = PatternEngine()
        let roll = PianoRollModel()
        let rig = Rig(player: player, roll: roll, document: document)
        player.enableMultiRoll(capacity: 4, sink: { [weak rig] slot, events in
            if slot == 0 { rig?.heard.append(contentsOf: events) }
        })
        player.liveDocument = { [weak rig] in rig?.live }
        rigClips = clips
        rigPlayer = player
        rigPattern = pattern
        player.play(document: document, clips: clips, pattern: pattern, pianoRoll: roll)
        return rig
    }

    /// `async` so it runs on the class's main actor (`TheMIDITakeIsRecordedFromTheWorkstationTests`).
    override func tearDown() async throws {
        rigPlayer?.stop()
        rigPattern?.stop()
        if let clips = rigClips { for i in clips.slots.indices { clips.clear(at: i) } }
        rigClips = nil
        rigPlayer = nil
        rigPattern = nil
    }

    /// Transport steps `range`, counted from Play (bar = step / 16); returns what the rack heard.
    @discardableResult
    private func run(_ rig: Rig, steps range: Range<Int>) -> [LaneNotePump.Event] {
        rig.heard.removeAll()
        for s in range { rig.player.transportStep(s % Self.steps) }
        return rig.heard
    }

    /// The structural edit: the roll's part is dragged one bar longer. Its notes do not change;
    /// the region does, so the roll's arrangement decision reloads it.
    private func lengthenTheRollPart(_ rig: Rig) {
        var edited = rig.document
        guard !edited.regions.isEmpty else {
            return XCTFail("ANCHOR MISSING: the rig has no part to edit")
        }
        edited.regions[0].lengthTicks = 3 * TimelineTime.ticksPerBar
        XCTAssertFalse(TimelineDocument.structurallyEqual(rig.document, edited),
                       "ANCHOR MISSING: the edit is not structural — the claims below would say nothing")
        rig.live = edited
    }

    private func ons(_ events: [LaneNotePump.Event]) -> [Int] { events.filter(\.isOn).map(\.pitch) }

    // MARK: 1 — END-TO-END

    /// 1a + 1b: an edit that lands on a bar line enters the bar that line opens, on both tracks.
    func testAnEditOnABarLineEntersTheNewBar() {
        let rig = makeRig()
        XCTAssertEqual(ons(run(rig, steps: 0..<1)), [48], "ANCHOR MISSING: the rack track did not start its bar 1")
        run(rig, steps: 1..<16)
        lengthenTheRollPart(rig)
        let downbeat = run(rig, steps: 16..<17)               // bar 2, step 0
        XCTAssertEqual(rig.roll.notes.map(\.pitch), [72], """
            1a: after a structural edit on the bar line the roll holds bar 2 (pitch 72). Pitch 60 \
            is bar 1 again — the chase loaded at the PREVIOUS step's tick, and the part then runs \
            a bar late until its next onset.
            """)
        XCTAssertEqual(ons(downbeat), [50], """
            1b: the rack track plays its bar 2 (pitch 50) on the downbeat. Pitch 48 is its bar 1 — \
            an edit on ANY track re-entered the previous bar on every MIDI track.
            """)
    }

    /// 1c: mid-bar, the rack's next bar still arrives on time (green on both trees — the roll's
    /// mid-bar half is claim 2).
    func testAnEditMidBarKeepsTheNextBarOnTime() {
        let rig = makeRig()
        XCTAssertEqual(ons(run(rig, steps: 0..<5)), [48], "ANCHOR MISSING: the rack track did not start its bar 1")
        lengthenTheRollPart(rig)
        run(rig, steps: 5..<16)
        XCTAssertEqual(rig.roll.notes.map(\.pitch), [60], "mid-bar the roll stays in bar 1")
        XCTAssertEqual(ons(run(rig, steps: 16..<17)), [50], "1c: and the rack's bar 2 arrives on time")
    }

    // MARK: 2 — SOURCE

    func testTheVoicesAreReDrivenAtTheTickAndStepThisStepSounds() throws {
        let player = try source(Self.playerPath)
        let step = try body(of: "public func transportStep(_ step: Int) {", in: player)
        guard let adopt = step.range(of: "let structureChase = refreshStructure()"),
              let advance = step.range(of: "var newTick = cursor.advance(step: step)"),
              let chase = step.range(of: "chaseStructure(structureChase, atTick: newTick, step: step)"),
              let notes = step.range(of: "refreshNoteContent(atTick: newTick, step: step)")
        else {
            return XCTFail("ANCHOR MISSING: the M7 two-half chase in transportStep (#454)")
        }
        XCTAssertLessThan(adopt.lowerBound, advance.lowerBound,
                          "the document is adopted BEFORE the advance — the wrap reads its loop length")
        XCTAssertLessThan(advance.lowerBound, chase.lowerBound,
                          "the voices are re-driven AFTER the advance, at the tick this step sounds")
        XCTAssertLessThan(chase.lowerBound, notes.lowerBound, "structure first, then the note refresh")

        let voices = try body(of: "private func chaseStructure(_ chase: StructureChase, atTick tick: Int, step: Int) {",
                              in: player)
        XCTAssertTrue(voices.contains("loadRollRegion(at: tick, step: step)"),
                      "the roll's bar plan gets THIS step — mid-bar is not a bar line")
        XCTAssertTrue(voices.contains("primeSecondaryLanes(at: tick)"))
        XCTAssertTrue(voices.contains("reapplyLaunched(laneID: lane, atTick: tick, step: step)"))
        XCTAssertFalse(voices.contains("lastTick"), "the voice half reads the tick it is handed, never the previous step's")

        let adoption = try body(of: "private func refreshStructure() -> StructureChase? {", in: player)
        for voiceCall in ["loadRollRegion(", "primeSecondaryLanes(", "reapplyLaunched("] {
            XCTAssertFalse(adoption.contains(voiceCall),
                           "\(voiceCall) inside refreshStructure loads a voice before the advance")
        }
        XCTAssertTrue(adoption.contains("flushPumps()"), "the chase still releases through the OLD bindings first (H5b)")

        let relocate = try body(of: "public func relocate(toTick tick: Int) {", in: player)
        XCTAssertTrue(relocate.contains("loadRollRegion(at: anchor, step: nextStep)"),
                      "a playhead drop mid-bar tells the roll's plan the step the next transport step carries")
        XCTAssertTrue(player.contains("private func loadRollRegion(at tick: Int, step: Int) {"),
                      "the step is required — a literal 0 at a new call site is the defect this pins")
        XCTAssertFalse(player.contains("loadRollRegion(at: lastTick"), "no load at the previous step's tick")
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    private struct AnchorMissing: Error { let name: String }

    /// The brace-matched body after `anchor` — never a fixed window (#408).
    private func body(of anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing(name: anchor)
        }
        guard let open = code[code.index(before: start.upperBound)...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: no body after \(anchor) (#454)")
            throw AnchorMissing(name: anchor)
        }
        var depth = 0
        var index = open
        while index < code.endIndex {
            switch code[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(code[code.index(after: open)..<index]) }
            default: break
            }
            index = code.index(after: index)
        }
        XCTFail("ANCHOR MISSING: unbalanced body after \(anchor) (#454)")
        throw AnchorMissing(name: anchor)
    }
}
#endif
