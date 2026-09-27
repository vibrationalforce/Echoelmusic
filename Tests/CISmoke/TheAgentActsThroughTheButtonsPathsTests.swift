// TheAgentActsThroughTheButtonsPathsTests.swift
// EchoelAI step 1 (founder order 2026-09-27): `EchoelCommandExecutor` reads the selection and the
// song, changes a track's level, copies the selected part directly after it, and takes back its
// own last change — through the same writers the inspector and the part bar use, checking every
// change after it is made.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claims 1–7 are END-TO-END over a REAL `TimelineStore` and `WorkstationSelection`.
//     Assertions are on the fixture's OWN ids; the store's prior document is restored after
//     each claim (`TimelineStore()` loads whatever an earlier run persisted).
//   · Claim 8 is a SOURCE-TEXT SCAN: the executor writes only through the button writers and
//     touches nothing on the audio side, the network or the disk.
//   · NOT covered here: a busy refusal (two requests interleaving on the main actor cannot be
//     ordered deterministically in a test; the guard is one line, transcribed) and anything a
//     person sees — no agent surface exists yet.
//
// HONEST GRADING against the parent (7d245c76a, §3): the file does not COMPILE there — it names
// `EchoelCommandExecutor`, which this commit creates — so no assertion has a verdict on the parent:
// ONE absence (#486), all claims FORWARD guards. Hand-transcribed in Python over a model of the
// store's region/level writes; mutants driven, each red for its named reason: a copy placed at the
// original's start (claim 3), a repeated request that runs again (claim 5), an undo that restores
// a level the person has moved since (claim 6), the executor writing `setLaneLevel` directly
// instead of through `TrackMix.setLevel` (claim 8).
// Step 2b (`media.applyLook`) widened the rig and claim 8: the executor now takes the media-look
// owner and a defaults suite, and claim 8 names the owner's writers. `UserDefaults` as a bare word
// was forbidden and is now allowed as a TYPE — the look lives there and a test must hand in a
// private suite — while `UserDefaults.standard`, `.set(`, `forKey:` and `removeObject` stay out,
// and `MediaSeedApplication.apply(`, `.write(to:` and `mediaLooks.record(` join the bypass list.
// Review repair 2a (2026-09-27): a step naming "the selection" while the plan saw none is now a
// REFUSAL before the first step (`report.refusal`, a clear error), not a step failure — claim 3 moved
// its two `.selected` cases accordingly, and claim 9 drives the case the old shape allowed: a
// selection made AFTER the plan was never resolved live. Mutant: executor resolving `.selected`
// from the live selection at step time → claim 9 red (Keys quieter, the person never asked).
// Review repair 2b: claim 6 also re-enters the agent's own value by hand and expects Undo to keep
// it (`TimelineStore.laneLevelWrites`, counted per write); claim 8 pins the counter at the writer.
// Mutant: undo comparing the value only → the re-entered value is overwritten, claim 6 red.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheAgentActsThroughTheButtonsPathsTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let clip = UUID()

    // One fixture VALUE per lane — never a factory (#1419).
    private static let bioLane = TimelineLane(name: "Body", kind: .midi, isBio: true)
    private static let keysLane = TimelineLane(name: "Keys", kind: .midi)
    private static let loopLane = TimelineLane(name: "Loop", kind: .audio)
    private static let quietLane = TimelineLane(name: "Quiet", kind: .audio, level: 0)
    private static let keysPart = TimelineRegion(laneID: keysLane.id, clipID: clip, startTick: 0, lengthTicks: bar)
    private static let loopPart = TimelineRegion(laneID: loopLane.id, clipID: clip, startTick: bar,
                                                 lengthTicks: 2 * bar)
    private static let fixture = TimelineDocument(lanes: [bioLane, keysLane, loopLane, quietLane],
                                                  regions: [keysPart, loopPart])

    /// The store loaded fresh, its prior document handed back so each claim restores it.
    private func rig() -> (TimelineStore, WorkstationSelection, EchoelCommandExecutor, TimelineDocument) {
        let timeline = TimelineStore()
        let original = timeline.document
        timeline.replaceDocument(Self.fixture)
        let selection = WorkstationSelection()
        // No claim here applies a media look, so the defaults are never written; a fixed suite name
        // always resolves, and the fallback is never the app's own domain being touched.
        let looks = UserDefaults(suiteName: "echoel.tests.agentButtonsPaths") ?? UserDefaults()
        let executor = EchoelCommandExecutor(timeline: timeline, selection: selection, voiceCapacity: { 4 },
                                             mediaLooks: MediaLookUndo(), visualDefaults: looks)
        return (timeline, selection, executor, original)
    }

    private func plan(_ steps: [EchoelCommand], on executor: EchoelCommandExecutor,
                      id: UUID = UUID()) -> EchoelActionPlan {
        EchoelActionPlan(requestID: id, steps: steps, basis: executor.snapshot(), consents: [])
    }

    private func level(_ lane: TimelineLane, in timeline: TimelineStore) -> Float? {
        timeline.document.lanes.first(where: { $0.id == lane.id })?.level
    }

    // MARK: 1 — "What is selected?" reads the canonical owners and changes nothing

    func testTheAgentReadsTheSelectionAndChangesNothing() async {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        XCTAssertTrue(EchoelStateText.describe(executor.snapshot()).hasPrefix("No track is selected."))
        selection.selectRegion(Self.keysPart.id, in: timeline.document)
        let report = await executor.execute(plan([.describeState], on: executor))
        guard case .done(let text) = report.steps.first?.outcome else { return XCTFail("the state is read") }
        XCTAssertEqual(text, "Selected track: Keys — Echoel instrument, level 0.0 dB. "
                       + "Selected part: Bar 1 · 1 bar. The song has 4 tracks and 2 parts.")
        XCTAssertEqual(timeline.document, Self.fixture, "reading changes nothing")
        XCTAssertFalse(executor.canUndoAgentChange, "a read leaves nothing to take back")
    }

    // MARK: 2 — "three decibels quieter" moves exactly that track, through the inspector's writer

    func testALevelChangeMovesOnlyTheTargetTrack() async throws {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.toggleTrack(Self.loopLane.id)
        let songUndoBefore = timeline.canUndo
        let report = await executor.execute(plan([.setTrackLevel(track: .selected, change: .relativeDecibels(-3))],
                                                 on: executor))
        XCTAssertEqual(report.state, .done)
        XCTAssertEqual(report.steps.first?.outcome, .done("Loop: 0.0 dB → −3.0 dB."))
        let loop = try XCTUnwrap(level(Self.loopLane, in: timeline))
        XCTAssertEqual(loop, Float(pow(10, -3.0 / 20)), "the level reads back as asked")
        XCTAssertEqual(level(Self.keysLane, in: timeline), 1, "the neighbour is untouched")
        XCTAssertEqual(timeline.document.regions, Self.fixture.regions)
        XCTAssertEqual(timeline.canUndo, songUndoBefore, "a level is not a song-history step (store rule, kept)")
        XCTAssertTrue(executor.canUndoAgentChange, "the agent keeps its own way back")
    }

    // MARK: 3 — invalid requests change nothing and say why

    func testARefusedLevelChangesNothing() async {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        let cases: [(EchoelCommand, EchoelCommandError)] = [
            (.setTrackLevel(track: .id(Self.bioLane.id), change: .relativeDecibels(-3)), .noLevel("Bio curve — no sound")),
            (.setTrackLevel(track: .id(Self.quietLane.id), change: .relativeDecibels(3)), .levelIsSilent),
            (.setTrackLevel(track: .id(UUID()), change: .absoluteDecibels(0)), .targetGone("track")),
            (.duplicatePart(part: .id(UUID())), .targetGone("part")),
            (.undoAgentChange, .nothingToUndo),
        ]
        for (command, expected) in cases {
            let report = await executor.execute(plan([command], on: executor))
            XCTAssertEqual(report.steps.first?.outcome, .failed(expected), "\(command)")
            XCTAssertEqual(timeline.document, Self.fixture, "a refused `\(command)` changed the song")
        }
        // "The selection" with nothing selected is refused BEFORE the first step — a clear error,
        // not a half-run request (review repair 2a).
        for (command, expected) in [(EchoelCommand.setTrackLevel(track: .selected, change: .relativeDecibels(-3)),
                                     EchoelCommandError.nothingSelected("track")),
                                    (.duplicatePart(part: .selected), .nothingSelected("part"))] {
            let report = await executor.execute(plan([.describeState, command], on: executor))
            XCTAssertEqual(report.refusal, expected, "\(command)")
            XCTAssertEqual(report.steps.map(\.outcome), [.notRun, .notRun], "nothing ran, not even the read")
            XCTAssertEqual(report.state, .failed(expected.message))
            XCTAssertEqual(timeline.document, Self.fixture)
        }
        XCTAssertEqual(EchoelCommandError.nothingSelected("track").message, "No track is selected. Select one first.")
        selection.toggleTrack(Self.keysLane.id)
        let loud = await executor.execute(plan([.setTrackLevel(track: .selected, change: .absoluteDecibels(9))],
                                               on: executor))
        guard case .failed(.outOfRange) = loud.steps.first?.outcome else { return XCTFail("+9 dB is refused") }
        XCTAssertEqual(timeline.document, Self.fixture, "never clamped to the ceiling instead")
        XCTAssertFalse(executor.canUndoAgentChange)
    }

    // MARK: 4 — "copy the selected part right after it": one copy, same track, same clip

    func testTheSelectedPartIsCopiedDirectlyAfterItOnce() async throws {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.selectRegion(Self.loopPart.id, in: timeline.document)
        let report = await executor.execute(plan([.duplicatePart(part: .selected)], on: executor))
        XCTAssertEqual(report.state, .done)
        let added = timeline.document.regions.filter { $0.id != Self.keysPart.id && $0.id != Self.loopPart.id }
        XCTAssertEqual(added.count, 1)
        let copy = try XCTUnwrap(added.first)
        XCTAssertEqual(copy.laneID, Self.loopLane.id)
        XCTAssertEqual(copy.clipID, Self.clip, "the copy plays the same clip — no new media")
        XCTAssertEqual(copy.startTick, Self.loopPart.startTick + Self.loopPart.lengthTicks, "directly after it")
        XCTAssertEqual(copy.lengthTicks, Self.loopPart.lengthTicks)
        XCTAssertEqual(report.steps.first?.outcome, .done("Copied the part to Bar 4 · 2 bars."))
        XCTAssertEqual(selection.regionID, Self.loopPart.id, "the selection stays, as the part bar's Copy leaves it")
        XCTAssertTrue(timeline.canUndo, "the copy is one ordinary song step, like the button's")

        // "Copy it twice" in one request: the second copy would land UNDER the first (the copy
        // always starts at the original's end) — refused, never reported as a second copy.
        let twice = await executor.execute(plan([.duplicatePart(part: .selected), .duplicatePart(part: .selected)],
                                                on: executor))
        XCTAssertEqual(twice.steps.map(\.outcome), [.failed(.placeTaken), .notRun],
                       "the first copy of this test already holds the place")
        XCTAssertEqual(timeline.document.regions.count, Self.fixture.regions.count + 1, "still exactly one copy")
    }

    // MARK: 5 — a stale selection, a changed song, a repeated request

    func testStaleSelectionChangedSongAndRepeatsAreSafe() async throws {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.selectRegion(Self.keysPart.id, in: timeline.document)
        let copyIt = plan([.duplicatePart(part: .selected)], on: executor)

        // The person changes the song after the agent read it: the plan does not start.
        timeline.setLaneLevel(id: Self.keysLane.id, 0.5)
        let changed = await executor.execute(copyIt)
        XCTAssertEqual(changed.refusal, .projectChanged)
        XCTAssertEqual(changed.state, .needsAnswer(EchoelCommandError.projectChanged.message))
        XCTAssertEqual(timeline.document.regions, Self.fixture.regions, "nothing copied")

        // A fresh read, the same words sent twice: one copy.
        let once = plan([.duplicatePart(part: .selected)], on: executor)
        let first = await executor.execute(once)
        let second = await executor.execute(once)
        XCTAssertEqual(first.state, .done)
        XCTAssertTrue(second.replayed, "the repeat returns the first answer")
        XCTAssertEqual(second.steps, first.steps)
        XCTAssertEqual(timeline.document.regions.count, Self.fixture.regions.count + 1, "exactly one copy")
        let reused = await executor.execute(EchoelActionPlan(requestID: once.requestID, steps: [.undoAgentChange],
                                                             basis: executor.snapshot(), consents: []))
        XCTAssertEqual(reused.refusal, .requestIDReused, "an id names one request; another plan under it never runs")
        XCTAssertEqual(timeline.document.regions.count, Self.fixture.regions.count + 1)

        // The selected part is removed by the person: the selection is stale, nothing is guessed.
        timeline.removeRegion(id: Self.keysPart.id)
        let stale = await executor.execute(plan([.duplicatePart(part: .selected)], on: executor))
        XCTAssertEqual(stale.steps.first?.outcome, .failed(.targetGone("part")))
        XCTAssertEqual(timeline.document.regions.count, Self.fixture.regions.count, "one removed, none added")
    }

    // MARK: 6 — partial success is named; the agent's Undo takes back the whole request and
    //           keeps what the person changed since

    func testPartialSuccessIsNamedAndUndoRespectsLaterEdits() async throws {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.selectRegion(Self.loopPart.id, in: timeline.document)
        let mixed = await executor.execute(plan([
            .setTrackLevel(track: .selected, change: .relativeDecibels(-3)),
            .duplicatePart(part: .selected),
            .setTrackLevel(track: .id(Self.bioLane.id), change: .relativeDecibels(-3)),
            .setTrackLevel(track: .selected, change: .relativeDecibels(-3)),
        ], on: executor))
        XCTAssertTrue(mixed.isPartial)
        XCTAssertEqual(mixed.state, .failed("2 of 4 done. This track has no level to change (Bio curve — no sound)."))
        XCTAssertEqual(mixed.steps.last?.outcome, .notRun, "after a failure the rest does not run")
        XCTAssertEqual(timeline.document.regions.count, Self.fixture.regions.count + 1)

        let undo = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(undo.steps.first?.outcome, .done("Took back my last 2 changes."))
        XCTAssertEqual(timeline.document, Self.fixture, "level and copy are both back, as one group")
        XCTAssertFalse(executor.canUndoAgentChange)

        // The agent lowers Keys; the person then moves Keys by hand; Undo leaves the person's value.
        selection.toggleTrack(Self.keysLane.id)
        _ = await executor.execute(plan([.setTrackLevel(track: .selected, change: .absoluteDecibels(-6))], on: executor))
        timeline.setLaneLevel(id: Self.keysLane.id, 1.5)
        let conflict = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(conflict.steps.first?.outcome, .failed(.changedSince("The level of Keys")))
        XCTAssertEqual(level(Self.keysLane, in: timeline), 1.5, "the person's later value is kept")

        // Review repair 2b: the person re-enters the SAME number the agent left (the inspector's
        // field, so the value reads unchanged) — that is their decision now, and Undo leaves it.
        _ = await executor.execute(plan([.setTrackLevel(track: .selected, change: .absoluteDecibels(-6))], on: executor))
        let agentsValue = try XCTUnwrap(level(Self.keysLane, in: timeline))
        let writesAfterAgent = try XCTUnwrap(timeline.laneLevelWrites[Self.keysLane.id])
        TrackMix.setLevel(Double(agentsValue), laneID: Self.keysLane.id, timeline: timeline)
        XCTAssertEqual(level(Self.keysLane, in: timeline), agentsValue, "the value itself did not move")
        XCTAssertEqual(timeline.laneLevelWrites[Self.keysLane.id], writesAfterAgent + 1, "but the store counted the write")
        let reentered = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(reentered.steps.first?.outcome, .failed(.changedSince("The level of Keys")),
                       "a value written since — even the same one — is the person's")
        XCTAssertEqual(level(Self.keysLane, in: timeline), agentsValue)
        XCTAssertFalse(executor.canUndoAgentChange, "the entry is spent, not retried forever")
        TrackMix.setLevel(1.5, laneID: Self.keysLane.id, timeline: timeline)   // back to where this block found it

        // Half of a request moved on since: the other half IS taken back, and the report says both.
        selection.selectRegion(Self.loopPart.id, in: timeline.document)
        _ = await executor.execute(plan([.setTrackLevel(track: .selected, change: .relativeDecibels(-3)),
                                         .duplicatePart(part: .selected)], on: executor))
        timeline.setLaneLevel(id: Self.loopLane.id, 0.25)
        let half = await executor.execute(plan([.undoAgentChange], on: executor))
        XCTAssertEqual(half.steps.first?.outcome, .failed(.partlyUndone(restored: 1, kept: "The level of Loop")))
        XCTAssertEqual(timeline.document.regions, Self.fixture.regions, "the copy is gone")
        XCTAssertEqual(level(Self.loopLane, in: timeline), 0.25, "the person's level stays")
    }

    // MARK: 7 — Cancel ends what has not started

    func testCancelEndsEveryStepNotYetStarted() async {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        selection.selectRegion(Self.loopPart.id, in: timeline.document)
        let request = plan([.duplicatePart(part: .selected), .duplicatePart(part: .selected)], on: executor)
        let task = Task { @MainActor in await executor.execute(request) }
        task.cancel()   // before the task's first step: the main actor is still ours
        let report = await task.value
        XCTAssertEqual(report.steps.map(\.outcome), [.cancelled, .cancelled])
        XCTAssertEqual(report.state, .failed("Cancelled."))
        XCTAssertEqual(timeline.document, Self.fixture, "nothing ran")
        let again = await executor.execute(request)
        XCTAssertTrue(again.replayed, "a cancelled request is answered; the same id does not run later")
        XCTAssertEqual(timeline.document, Self.fixture)
    }

    // MARK: 9 — a selection made AFTER the plan is never the target (review repair 2a)

    func testASelectionMadeAfterThePlanIsNeverAdopted() async throws {
        let (timeline, selection, executor, original) = rig()
        defer { timeline.replaceDocument(original) }
        // Planned with nothing selected; the person selects Keys before the request runs.
        let unaimed = plan([.setTrackLevel(track: .selected, change: .relativeDecibels(-3))], on: executor)
        XCTAssertNil(unaimed.basis.track)
        selection.toggleTrack(Self.keysLane.id)
        let refused = await executor.execute(unaimed)
        XCTAssertEqual(refused.refusal, .nothingSelected("track"), "the plan carried no target, so none is guessed")
        XCTAssertEqual(level(Self.keysLane, in: timeline), 1, "Keys is untouched — the person never asked for it")
        XCTAssertFalse(executor.canUndoAgentChange)

        // Planned on Loop; the person moves the selection to Keys before it runs: a question, and
        // neither track moves.
        selection.toggleTrack(Self.keysLane.id)   // clears
        selection.toggleTrack(Self.loopLane.id)
        let aimedAtLoop = plan([.setTrackLevel(track: .selected, change: .relativeDecibels(-3))], on: executor)
        XCTAssertEqual(aimedAtLoop.basis.track?.id, Self.loopLane.id)
        selection.toggleTrack(Self.keysLane.id)
        let moved = await executor.execute(aimedAtLoop)
        XCTAssertEqual(moved.refusal, .projectChanged)
        XCTAssertEqual(moved.state, .needsAnswer(EchoelCommandError.projectChanged.message))
        XCTAssertEqual(level(Self.keysLane, in: timeline), 1)
        XCTAssertEqual(level(Self.loopLane, in: timeline), 1)

        // Planned on Loop and unchanged: both steps land on the plan's track (the id was pinned
        // before the first step, so nothing between the steps could move the second one).
        selection.toggleTrack(Self.loopLane.id)
        let onLoop = plan([.setTrackLevel(track: .selected, change: .relativeDecibels(-3)),
                           .setTrackLevel(track: .selected, change: .relativeDecibels(-3))], on: executor)
        let done = await executor.execute(onLoop)
        XCTAssertEqual(done.state, .done)
        let loop = try XCTUnwrap(level(Self.loopLane, in: timeline))
        XCTAssertEqual(loop, Float(pow(10, -6.0 / 20)), accuracy: 1e-6, "two steps of −3 dB")
        XCTAssertEqual(level(Self.keysLane, in: timeline), 1)
    }

    // MARK: 8 — same writers as the buttons; nothing on the audio side, the disk or the network

    func testTheExecutorWritesOnlyThroughTheButtonWriters() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        func code(_ path: String) throws -> String {
            SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8))
        }
        let executor = try code("Sources/Echoelmusic/EchoelAI/EchoelCommandExecutor.swift")
        let commands = try code("Sources/Echoelmusic/EchoelAI/EchoelCommand.swift")
        for writer in ["TrackMix.setLevel(", "TrackParts.duplicate(", "TrackParts.remove(",
                       "mediaLooks.apply(photo:", "mediaLooks.apply(video:", "mediaLooks.undo(on:"] {
            XCTAssertTrue(executor.contains(writer), "the executor writes through `\(writer)`, the buttons' path")
        }
        for direct in ["setLaneLevel(", "duplicateRegion(", "removeRegion(", "replaceDocument(", "timeline.undo(",
                       "document.regions.append", "document.lanes[", "MediaSeedApplication.apply(", ".write(to:",
                       "mediaLooks.record("] {
            XCTAssertFalse(executor.contains(direct), "the executor bypasses the button writers with `\(direct)`")
        }
        for file in [executor, commands] {
            // `UserDefaults` may be NAMED — the visual look lives there and the test hands in a
            // private suite — but the agent never picks the app's own, and never writes a key.
            for forbidden in ["AudioEngine", "EngineBus", "renderBlock", "AVAudio", "DispatchQueue", "URLSession",
                              "FileManager", "UserDefaults.standard", ".set(", "forKey:",
                              "removeObject", "Task.detached", "Thread.",
                              // review LOW-2: the other ways to reach the app's own defaults or owner
                              "UserDefaults(", "PersistentDomain", "register(defaults", "= .standard",
                              "MediaLookUndo.shared"] {
                XCTAssertFalse(file.contains(forbidden), "the agent layer names `\(forbidden)`")
            }
        }
        XCTAssertTrue(executor.contains("@MainActor\nfinal class EchoelCommandExecutor"))
        // Allow-list, not only a deny-list (review LOW): the store is READ through `document`,
        // and every write goes through a button writer that is handed the store.
        let regex = try NSRegularExpression(pattern: "\\btimeline\\.([A-Za-z_]+)")
        let range = NSRange(executor.startIndex..., in: executor)
        let members = Set(regex.matches(in: executor, range: range).compactMap { match in
            Range(match.range(at: 1), in: executor).map { String(executor[$0]) }
        })
        XCTAssertEqual(members, ["document", "laneLevelWrites"],
                       "the executor touches the store beyond reading its document and the level write count")
        // Review repair 2b: the write count is bumped at the ONE lane-level writer, on every write.
        let store = try code("Sources/Echoelmusic/Core/TimelineStore.swift")
        guard let head = store.range(of: "public func setLaneLevel(id: UUID, _ level: Float) {"),
              let tail = store.range(of: "persist()", range: head.upperBound..<store.endIndex) else {
            return XCTFail("`TimelineStore.setLaneLevel` or its `persist()` moved — re-anchor")
        }
        XCTAssertTrue(store[head.upperBound..<tail.lowerBound].contains("laneLevelWrites[id, default: 0] += 1"),
                      "the same number entered again must count as a write, or the agent's Undo overwrites a decision")
        XCTAssertTrue(store.contains("@ObservationIgnored public private(set) var laneLevelWrites: [UUID: Int]"),
                      "not observed (nothing renders it), not writable from outside the store")
        XCTAssertTrue(executor.contains("run(Self.pinned(command, to: plan.basis), seen: plan.basis"),
                      "\"the selection\" is resolved from the state the plan saw, not re-read between steps (review MED)")
        // Review repair 2a: the live selection is read in ONE place, `snapshot()` — a resolver that
        // read it at step time would adopt a selection made after the plan.
        XCTAssertEqual(executor.components(separatedBy: "selection.trackID").count - 1, 1)
        XCTAssertEqual(executor.components(separatedBy: "selection.regionID").count - 1, 1)
        XCTAssertTrue(executor.contains("if let missing = Self.missingTarget(in: plan) { return refused(plan, missing) }"),
                      "a missing target is a refusal before the first step")
    }
}
