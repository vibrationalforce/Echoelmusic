// AMidPlayNoteEditKeepsTheBarTests.swift
// Echoel — Phase 3 / Creation Workflow, MIDI editor slice M5: hear the edit where it belongs.
//
// WHAT IT PINS. Since M1 a note edit made while the song plays is pulled into playback on the
// next transport step (`TimelineRegionPlayer.refreshNoteContent`). The first version of that
// pull re-loaded at the PREVIOUS step's tick (`lastTick`) with the roll's `step: 0`, through the
// STRUCTURE chase paths. On a part longer than one bar that was wrong three ways, all audible:
//   · on a bar line, `lastTick` sits in the bar before — every MIDI track re-entered the old bar
//     and played it again, then stayed one bar late for the rest of playback;
//   · mid-bar, `step: 0` told the roll's bar plan the load lands on a bar line, so the plan staged
//     no next bar and a phase one short (`ArrangementLoadPlan.plan` states both cases);
//   · `primeSecondaryLanes` reset every secondary pump, which cut the notes ringing on every
//     other MIDI track at each edit anywhere.
//
// 1. END-TO-END BEHAVIOUR over a real `TimelineRegionPlayer`, `ClipStore`, `PatternEngine` and
//    `PianoRollModel`: an edit at a bar line enters the NEW bar on the roll and on a rack track;
//    an edit mid-bar cuts no ringing note, and the next bar still arrives on time.
// 2. PURE: the plan's two cases — the mechanism behind the mid-bar half of the roll repair.
//    The roll's staged bar and phase are private and its trigger needs a live voice, so the
//    roll's MID-BAR behaviour is carried by this claim plus the call-order scan in
//    `TheSelectedPartsNotesAreEditedThroughOneWriterTests`, not by a driven roll.
// 3. SOURCE: the refresh loads the roll with THIS step, and re-windows the pumps without a reset.
//
// Grading (§0, no Swift toolchain in a web session): the player's step path, `LaneNotePump`,
// `ArrangementLoadPlan.plan` and `PianoRollModel.loadRegionArrangement` were transcribed into
// Python and driven against both trees. On the parent (`c32ff66f6`) this file COMPILES — it names
// no new symbol — and claims 1a (roll re-enters bar 0: pitch 60, not 72), 1b (the rack track
// plays 48 again, not 50) and 1c (an off for 48 at the edit step, so none at its own end) are
// REGRESSIONS, red for the reason their messages give; claim 1d (the next bar arrives on time
// after a mid-bar edit, and the added note sounds) is a COUNTERWEIGHT, green on both — mid-bar,
// `lastTick` and `newTick` share a bar, which is why the lag hid there on a rack track; claim 2 is a COUNTERWEIGHT; claim 3 is red on the parent by
// ANCHOR ABSENCE (one absence, #486).
// NOT covered: that the edit is HEARD in time on a device, and the roll's mid-bar phase under a
// running trigger — a device probe, owned by the marker below.
// NEEDS-FOUNDER-VERIFY: Workstation → a MIDI part two bars or longer → Play → while it loops, open
// Notes and add a note in bar 2 during bar 1 → the bars keep their order (bar 2 does not repeat
// bar 1), the new note sounds when bar 2 comes round, and a note ringing on another MIDI track is
// not cut by the edit.

import Foundation
import XCTest
@testable import Echoelmusic

#if canImport(SwiftUI)
@MainActor
final class AMidPlayNoteEditKeepsTheBarTests: XCTestCase {

    private static let steps = 16
    private static let playerPath = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"

    private var rigClips: ClipStore?
    private var rigPlayer: TimelineRegionPlayer?
    private var rigPattern: PatternEngine?

    /// Everything the rig plays and what the rack sink heard.
    private final class Rig {
        let player: TimelineRegionPlayer
        let clips: ClipStore
        let pattern: PatternEngine
        let roll: PianoRollModel
        let rollClip: Clip
        let rackClip: Clip
        var heard: [LaneNotePump.Event] = []
        init(player: TimelineRegionPlayer, clips: ClipStore, pattern: PatternEngine,
             roll: PianoRollModel, rollClip: Clip, rackClip: Clip) {
            self.player = player; self.clips = clips; self.pattern = pattern
            self.roll = roll; self.rollClip = rollClip; self.rackClip = rackClip
        }
    }

    /// Two MIDI tracks, each with ONE two-bar part from bar 1. The first track is the roll
    /// (`rollLaneID`): bar 1 plays pitch 60, bar 2 plays 72. The second rides a rack slot: bar 1
    /// holds 48 for the whole bar, bar 2 plays 50. `ClipStore` persists to the shared App Group
    /// file, so the grid is cleared first and last (the `RecordControllerAudioHookTests` idiom).
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
        let rig = Rig(player: player, clips: clips, pattern: pattern, roll: roll,
                      rollClip: rollClip, rackClip: rackClip)
        player.enableMultiRoll(capacity: 4, sink: { [weak rig] slot, events in
            if slot == 0 { rig?.heard.append(contentsOf: events) }
        })
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

    /// A user note write — the counter `refreshNoteContent` polls (`TimelineStore.setClipNotes`
    /// ends in exactly this call). The added note is in bar 2 of the rack part.
    private func edit(_ rig: Rig) {
        let notes = (rig.rackClip.melody?.notes ?? []) + [Note(pitch: 55, startStep: 24, lengthSteps: 2)]
        XCTAssertTrue(rig.clips.updateMelody(id: rig.rackClip.id, notes: notes),
                      "ANCHOR MISSING: the edit did not land — the claims below would say nothing")
    }

    private func ons(_ events: [LaneNotePump.Event]) -> [Int] { events.filter(\.isOn).map(\.pitch) }
    private func offs(_ events: [LaneNotePump.Event]) -> [Int] { events.filter { !$0.isOn }.map(\.pitch) }

    // MARK: 1 — END-TO-END

    /// 1a + 1b: an edit that lands on a bar line enters the bar that line opens.
    func testAnEditOnABarLineEntersTheNewBar() {
        let rig = makeRig()
        run(rig, steps: 0..<16)                               // bar 1, all of it
        edit(rig)
        let downbeat = run(rig, steps: 16..<17)               // bar 2, step 0
        XCTAssertEqual(rig.roll.notes.map(\.pitch), [72], """
            1a: after an edit on the bar line the roll holds bar 2 (pitch 72). Pitch 60 is bar 1 \
            again — the reload re-entered the PREVIOUS step's bar, and the part then runs a bar late.
            """)
        XCTAssertTrue(ons(downbeat).contains(50), "1b: the rack track plays its bar 2 (pitch 50) on the downbeat")
        XCTAssertFalse(ons(downbeat).contains(48), """
            1b: pitch 48 is the rack track's bar 1 — replaying it on bar 2's downbeat is the \
            one-bar lag on every MIDI track, not only the one being edited.
            """)
    }

    /// 1c + 1d: an edit mid-bar cuts no ringing note, and the next bar arrives on time.
    func testAnEditMidBarCutsNothingAndKeepsTheBar() {
        let rig = makeRig()
        let opening = run(rig, steps: 0..<5)                  // 48 starts at step 0 and rings
        XCTAssertEqual(ons(opening), [48], "ANCHOR MISSING: the rack track did not start its bar 1")
        edit(rig)
        let atTheEdit = run(rig, steps: 5..<6)
        XCTAssertFalse(offs(atTheEdit).contains(48), """
            1c: the edit released pitch 48 mid-bar. A note edit changes notes, not the track — \
            re-binding and resetting every rack slot cut what rang on every other MIDI track.
            """)
        let rest = run(rig, steps: 6..<16)
        XCTAssertFalse(offs(rest).contains(48), "1c: the whole-bar note rings to its own end")
        let downbeat = run(rig, steps: 16..<17)
        XCTAssertEqual(offs(downbeat), [48], "1c: pitch 48 ends where it was written — on bar 2's downbeat")
        XCTAssertEqual(ons(downbeat), [50], "1d: and bar 2 arrives on time")
        let added = run(rig, steps: 17..<25)
        XCTAssertTrue(ons(added).contains(55), "1d: the note the edit added sounds when bar 2 reaches it")
    }

    // MARK: 2 — PURE: why the roll needs the real step

    func testTheRollsBarPlanNeedsToKnowWhetherTheLoadIsOnABarLine() {
        // A two-bar part, entered in bar 1 mid-bar after one bar line was counted.
        let midBar = ArrangementLoadPlan.plan(barCount: 2, startBar: 0, playedBars: 1,
                                              atStepZero: false, playing: true)
        XCTAssertEqual(midBar.pendingIndex, 1, "mid-bar, the next bar line must find bar 2 staged")
        let toldBarLine = ArrangementLoadPlan.plan(barCount: 2, startBar: 0, playedBars: 1,
                                                   atStepZero: true, playing: true)
        XCTAssertNil(toldBarLine.pendingIndex, """
            told "bar line" mid-bar, the plan stages nothing and the next bar line repeats bar 1 — \
            which is why the refresh passes this step, never a literal 0
            """)
    }

    // MARK: 3 — SOURCE

    func testTheRefreshLoadsWithThisStepAndResetsNoPump() throws {
        let player = try source(Self.playerPath)
        guard let head = player.range(of: "private func refreshNoteContent(atTick tick: Int, step: Int) {"),
              let end = player.range(of: "private func soundingRegion(laneID: UUID, at tick: Int)",
                                     range: head.upperBound..<player.endIndex),
              let reloadHead = player.range(of: "private func reloadSecondaryNotes(at tick: Int) {"),
              let reloadEnd = player.range(of: "/// Release every sounding secondary voice",
                                           range: reloadHead.upperBound..<player.endIndex)
        else {
            return XCTFail("ANCHOR MISSING: the M5 note refresh (#454)")
        }
        let refresh = String(player[head.upperBound..<end.lowerBound])
        let reload = String(player[reloadHead.upperBound..<reloadEnd.lowerBound])
        XCTAssertTrue(refresh.contains("loadClip(region, atTick: tick, step: step)"),
                      "the roll's bar plan gets THIS step (claim 2)")
        XCTAssertFalse(refresh.contains("lastTick"), "the refresh reads the tick it is handed, never the previous step's")
        XCTAssertFalse(refresh.contains("primeSecondaryLanes("), "the structure prime re-binds and resets every slot")
        XCTAssertTrue(reload.contains("pump.load(bars: windowedBars(for: region), startBar: startBar)"))
        XCTAssertFalse(reload.contains(".reset()"), "a note edit cuts no ringing note")
        XCTAssertFalse(reload.contains("Sink?("), "a note edit re-binds no slot and re-sends no patch or mix")
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
}
#endif
