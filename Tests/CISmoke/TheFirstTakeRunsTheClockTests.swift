// TheFirstTakeRunsTheClockTests.swift
// Echoel — GMMW R2 (founder 2026-10-13): the first human take lands in an EMPTY piece.
//
// THE DEFECT. A fresh install is two lanes and no part (`TimelineStore.migrate`). Recording R1
// made Record arm, then start the song through the Workstation's ONE start — and `play` refused
// a document with nothing to execute (`canPlay`, #1437…#1440), so the door read "Add a part with
// notes or audio first". The first part IS the take: nobody could ever record the first one, and
// the Composer was the only way a piece could begin. The deep audit (2026-10-13) named it R2.
//
// THE REPAIR, in one sentence: an ARMED TAKE is the other reason the clock may run. The app hands
// the player `takeArmed` (= `RecordController.isRecording`, the mirror of `followSongEnd`); `play`
// admits `canPlay || takeArmed`; the door's state for an unplayable piece with an armed track is
// `.firstTake`, which arms and starts like `.ready`. Play alone stays dimmed over the empty piece.
//
// WHAT IT PINS.
// 1. END-TO-END BEHAVIOUR (a real `TimelineRegionPlayer`, `PatternEngine`, `PianoRollModel`,
//    `ClipStore`): the seeded two-lane document, which `canPlay` refuses, PLAYS while a take is
//    armed — and has no song end, so the take runs until Stop (R1's "no song end" path).
// 2. COUNTERWEIGHT: the same document is still refused with `takeArmed` false or unset, and
//    `canPlay` still says no — the Play control's answer did not move.
// 3. COUNTERWEIGHT: a playable document needs no armed take (the pre-R2 path is untouched).
// 4. END-TO-END BEHAVIOUR (a real `RecordController` on a real `Transport` and `TimelineStore`):
//    the first take lands as a part at bar 1 on the armed track, with the note that was played.
// 5. BEHAVIOUR (pure) + SOURCE-TEXT SCAN: the door's state and word; the app's wiring line; the
//    player's guard admits the take AFTER asking `canPlay`; the Workstation never names
//    `takeArmed` (Play stays honest); the door arms BEFORE it starts.
//
// HONEST GRADING (§3), against the parent tree (5f01ec2a2): the file does NOT compile there —
// `takeArmed`, `.firstTake`, `offersATake` and `shownReason(_:gridSize:)` are new — so no
// assertion has a verdict on the parent. By transcription: claims 1 and 4 are REGRESSIONS there
// (`play` returns on the empty document, `isPlaying` stays false, no part is added); claims 2 and
// 3 are COUNTERWEIGHTS, green on both trees; claim 5's scans are ONE absence reported N times
// (#486). `SourceText.codeOnly` on claim 5: PROPHYLAKTISCH (0 of 5 verdicts flip raw vs stripped —
// the needles are code lines no comment in those files repeats; measured with `git grep -c`).
// NEEDS-FOUNDER-VERIFY: fresh install (or a new piece) → Arrange → a MIDI track → "Arm for
// recording" → Record is lit → tap it: the transport runs, the ruler moves, Play stays dimmed →
// play a few notes on a MIDI keyboard → Stop: a first part sits on that track from bar 1 and Play
// is now lit and sounds your notes.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheFirstTakeRunsTheClockTests: XCTestCase {

    private static let steps = Transport.stepsPerBar
    private static let bar = TimelineTime.ticksPerBar

    private var rigClips: ClipStore?
    private var rigPlayer: TimelineRegionPlayer?
    private var rigPattern: PatternEngine?
    /// Held for the whole test: `RecordController` keeps its timeline WEAK
    /// (`TheMIDITakeIsRecordedFromTheWorkstationTests`).
    private var rigTimeline: TimelineStore?

    /// The fresh-install shape: two lanes, no part. The clip grid is cleared first and last
    /// (`ClipStore` persists to the shared App Group file).
    private func emptyRig() -> (TimelineRegionPlayer, TimelineDocument, ClipStore, PatternEngine, PianoRollModel) {
        let clips = ClipStore()
        for i in clips.slots.indices { clips.clear(at: i) }
        rigClips = clips
        let keys = TimelineLane(name: "MIDI 1", kind: .midi)
        let audio = TimelineLane(name: "Audio 1", kind: .audio)
        let document = TimelineDocument(lanes: [keys, audio], regions: [])
        let player = TimelineRegionPlayer()
        let pattern = PatternEngine()
        rigPlayer = player
        rigPattern = pattern
        return (player, document, clips, pattern, PianoRollModel())
    }

    override func tearDown() async throws {
        rigPlayer?.stop()
        rigPattern?.stop()
        if let clips = rigClips { for i in clips.slots.indices { clips.clear(at: i) } }
        rigClips = nil
        rigPlayer = nil
        rigPattern = nil
        rigTimeline = nil
    }

    private func canPlay(_ document: TimelineDocument, clips: ClipStore, pattern: PatternEngine) -> Bool {
        TimelineRegionPlayer.canPlay(document, clips: clips.filledClips, bpm: pattern.tempo,
                                     resolveAudio: { _ in nil })
    }

    // MARK: 1 — an armed take runs the clock over the empty piece

    func testAnArmedTakeRunsTheClockOverAnEmptyPiece() {
        let (player, document, clips, pattern, roll) = emptyRig()
        XCTAssertFalse(canPlay(document, clips: clips, pattern: pattern),
                       "premise: the fresh-install shape is not a song (`TheWorkstationPlaysTheTimelineTests`)")
        player.takeArmed = { true }
        player.play(document: document, clips: clips, pattern: pattern, pianoRoll: roll)
        XCTAssertTrue(player.isPlaying, """
            GMMW R2: an ARMED TAKE is the other reason the clock may run. With `takeArmed` true the \
            player must start over a document `canPlay` refuses — otherwise the first part of every \
            piece can only ever come from the Composer, never from a human.
            """)
        XCTAssertNil(player.songEndTick, """
            An empty piece has no loop length, so the take has no song end: it runs until Stop and \
            Stop commits it (R1's "without a song end the take runs on" path, driven by \
            `TheMIDITakeIsRecordedFromTheWorkstationTests`). A non-nil end here would cut the first \
            take at a bar nobody chose.
            """)
        player.stop()
        XCTAssertFalse(player.isPlaying)
    }

    // MARK: 2 — COUNTERWEIGHT: without an armed take the empty piece is still refused

    func testWithoutAnArmedTakeTheEmptyPieceStillRefuses() {
        let (player, document, clips, pattern, roll) = emptyRig()
        player.play(document: document, clips: clips, pattern: pattern, pianoRoll: roll)
        XCTAssertFalse(player.isPlaying, "unset `takeArmed` admits nothing — every test rig and the app before `wire`")
        player.takeArmed = { false }
        player.play(document: document, clips: clips, pattern: pattern, pianoRoll: roll)
        XCTAssertFalse(player.isPlaying, "a recorder that is NOT armed admits nothing — Play over an empty piece stays a refusal")
        XCTAssertFalse(canPlay(document, clips: clips, pattern: pattern), """
            `canPlay` itself did not move: the Play control asks it alone and must still dim over \
            the empty piece. R2 widened the PLAYER's admission for a take, not the definition of a \
            playable song (#416 — one definition, in `firstExecutableRegion`).
            """)
    }

    // MARK: 3 — COUNTERWEIGHT: a playable piece needs no armed take

    func testAPlayablePieceNeedsNoArmedTake() {
        let (player, _, clips, pattern, roll) = emptyRig()
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let clip = Clip(name: "Part", melody: MelodyClip(notes: [Note(pitch: 60, startStep: 0, lengthSteps: 4)]))
        clips.setClip(at: 0, clip)
        let document = TimelineDocument(lanes: [keys], regions: [
            TimelineRegion(laneID: keys.id, clipID: clip.id, startTick: 0, lengthTicks: Self.bar)
        ])
        XCTAssertTrue(canPlay(document, clips: clips, pattern: pattern), "premise: one part with a note is a song")
        player.play(document: document, clips: clips, pattern: pattern, pianoRoll: roll)
        XCTAssertTrue(player.isPlaying, "the pre-R2 path: a playable document starts with `takeArmed` unset")
        XCTAssertEqual(player.songEndTick, Self.bar, "and keeps its song end — the loop length is untouched")
    }

    // MARK: 4 — the first take lands as the piece's first part

    func testTheFirstTakeLandsAsThePiecesFirstPart() throws {
        let (player, _, clips, pattern, roll) = emptyRig()
        let timeline = TimelineStore()
        rigTimeline = timeline
        timeline.addLane(kind: .midi, name: "Keys \(UUID().uuidString)")
        let lane = try XCTUnwrap(timeline.document.lanes.last?.id)
        for other in timeline.document.lanes where other.isArmed && other.id != lane {
            timeline.toggleArm(id: other.id)
        }
        timeline.toggleArm(id: lane)
        let transport = Transport()
        let controller = RecordController()
        controller.wire(transport: transport, timeline: timeline, clips: clips, bus: EngineBus())
        controller.followSongEnd { [weak player] in player?.songEndTick }
        // The app's two wiring lines, mirrored: the player learns whether a take is armed.
        player.takeArmed = { [weak controller] in controller?.isRecording == true }
        // The EMPTY piece the player is handed: this store's lanes, no part (the store itself may
        // hold another test's song — the player's document is what `canPlay` judges).
        let document = TimelineDocument(lanes: timeline.document.lanes, regions: [])
        XCTAssertFalse(canPlay(document, clips: clips, pattern: pattern), "premise: nothing to play")
        let regionsBefore = timeline.document.regions.count

        // The door's order: arm, then start (`RecordTakeButton`, `.ready, .firstTake`).
        controller.arm()
        XCTAssertTrue(controller.isRecording, "premise: the armed lane is a recordable target")
        player.play(document: document, clips: clips, pattern: pattern, pianoRoll: roll)
        XCTAssertTrue(player.isPlaying, "the clock runs for the armed take over the empty piece")
        transport.play()
        for s in 0..<3 { transport.tick(step: s % Self.steps) }
        controller.recordNoteOn(pitch: 60, velocity: 0.8)
        for s in 3..<6 { transport.tick(step: s % Self.steps) }
        controller.recordNoteOff(pitch: 60)
        for s in 6..<20 { transport.tick(step: s % Self.steps) }
        XCTAssertTrue(controller.isRecording, "no song end: the take runs past bar 1 until Stop")
        transport.stop()
        player.stop()

        let added = Array(timeline.document.regions.dropFirst(regionsBefore)).filter { $0.laneID == lane }
        XCTAssertEqual(added.count, 1, "one take, one part — the piece's first")
        let region = try XCTUnwrap(added.first)
        XCTAssertEqual(region.startTick, 0, "the first take starts at bar 1, where Record starts the clock")
        let clip = try XCTUnwrap(clips.slots.compactMap { $0 }.first { $0.id == region.clipID })
        XCTAssertEqual(clip.melody?.notes.map(\.pitch), [60], "the note that was played is the part's content")
        XCTAssertEqual(controller.droppedTakes, 0)
    }

    // MARK: 5 — the door's word, and the wiring

    func testTheDoorOffersTheFirstTakeAndTheAppWiresIt() throws {
        let one = RecordTake.Plan(armable: [UUID()], foreign: [])
        let state = RecordTake.state(recording: false, running: false, plan: one, freeSlots: 8, startable: false)
        XCTAssertEqual(state, .firstTake, "an armed track over an unplayable piece is the FIRST take, not a block")
        XCTAssertTrue(state.offersATake, "the button is lit and enabled for it, like `.ready`")
        XCTAssertTrue(RecordTake.State.ready.offersATake)
        XCTAssertFalse(RecordTake.State.armFirst.offersATake)
        let caption = RecordTake.caption(.firstTake, gridSize: 8)
        XCTAssertTrue(caption.contains("first part"), "the hint says what the take becomes")
        XCTAssertTrue(caption.contains("Stop ends the take"), "and how it ends — there is no song end to end it")
        XCTAssertNil(RecordTake.shownReason(.firstTake, gridSize: 8), "the button's word says it; no second sentence")
        XCTAssertNotNil(RecordTake.shownReason(.armFirst, gridSize: 8), """
            Over an EMPTY piece the way to the first take — arm a track — must be said: the bar's \
            own line says what PLAY lacks, this is a different fact (R2 removed the `startable` gate).
            """)

        let app = try code(at: "Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertTrue(app.contains("timelinePlayer.takeArmed = { [weak recordController] in recordController?.isRecording == true }"), """
            The app must hand the player the recorder's armed state, next to `followSongEnd`. \
            Without this line `takeArmed` is nil in the shipped app and claim 1 is true only in \
            tests — the first take is refused on the device exactly as before R2.
            """)
        let player = try code(at: "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift")
        let ask = try XCTUnwrap(player.range(of: "guard Self.canPlay(document, clips: clips.filledClips, bpm: pattern.tempo,"),
                                "ANCHOR MISSING: the `play` guard (`TheWorkstationPlaysTheTimelineTests` pins it) (#454)")
        let afterAsk = String(player[ask.upperBound...].prefix(260))
        XCTAssertTrue(afterAsk.contains("|| takeArmed?() == true"), """
            The take admits AFTER `canPlay` in the SAME guard — one `return`, no second path into \
            the clock. A take clause anywhere else is a second starter.
            """)
        XCTAssertEqual(player.components(separatedBy: "takeArmed?()").count - 1, 1,
                       "the provider is asked exactly once, in the guard")
        let workstation = try code(at: "Sources/Echoelmusic/Studio/WorkstationView.swift")
        XCTAssertFalse(workstation.contains("takeArmed"), """
            The Workstation's Play asks `canPlay` alone (`songCanStart`). If it read `takeArmed`, \
            Play would light up over an empty piece whenever a track is armed — a Play that runs a \
            clock over nothing, the "fake playback" the Phase 4 brief forbids.
            """)
        let door = try code(at: "Sources/Echoelmusic/Studio/RecordTakeControls.swift")
        let caseStart = try XCTUnwrap(door.range(of: "case .ready, .firstTake:"),
                                      "ANCHOR MISSING: the arm-and-start case of `RecordTakeButton` (#454)")
        let caseEnd = try XCTUnwrap(door.range(of: "case .stopFirst, .armFirst, .foreignArm, .gridFull:",
                                               range: caseStart.upperBound..<door.endIndex))
        XCTAssertTrue(door[caseStart.upperBound..<caseEnd.lowerBound].contains("beginTake()"),
                      "the take states start the take (directly, or after the count-in, A10)")
        // A10: the arm and the start live in `beginTake()`, the one path both the plain tap and the
        // end of a count-in take.
        let takeStart = try XCTUnwrap(door.range(of: "private func beginTake() {"),
                                      "ANCHOR MISSING: `RecordTakeButton.beginTake` (#454)")
        let takeEnd = try XCTUnwrap(door.range(of: "private func startCountIn(", range: takeStart.upperBound..<door.endIndex))
        let body = door[takeStart.upperBound..<takeEnd.lowerBound]
        let arm = try XCTUnwrap(body.range(of: "recorder.arm()"))
        let start = try XCTUnwrap(body.range(of: "if !startSong() { recorder.cancel() }"))
        XCTAssertTrue(arm.upperBound <= start.lowerBound, """
            Arm BEFORE the start: the player admits the empty piece only while `takeArmed` is \
            true, so a start before the arm is refused on the first take — and the refusal \
            cancels the arm, so nothing happens at all.
            """)
        XCTAssertTrue(door.contains(".disabled(!state.offersATake && state != .recording)"),
                      "the enabled set is the two take states plus recording — one predicate, not two spellings")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let reason: String }

    private func code(at relativePath: String) throws -> String {
        let path = try Self.treeRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor, do not skip")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// Directory-gated, never per-file (#475).
    private static func treeRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Sources").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("No source tree next to the test bundle — nothing to scan.")
    }
}
