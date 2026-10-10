// TheAgentStartsATrackComposerTests.swift
// Echoel — GMMW AI-6c. The agent can do what "Compose here" does on a rack track's Device page:
// let the instrument's composer write a part on that track. Generation stays a choice the person
// can take back, and the agent's Undo takes back only what it set.
//
// WHAT THIS GUARDS (END-TO-END over a real `TimelineStore` + `ClipStore` and the shipped executor;
// claim 7's last assertion is a SOURCE-TEXT SCAN of the app's one construction):
//   1. `track.composeHere` on a rack track places ONE composer part and a variation of its own,
//      through `TrackCompose.turnOn` — the rows read it as on. The agent's Undo removes the part
//      and puts the variation back to "follow the piece"; the song's Undo afterwards brings the
//      part back (the removal is one ordinary song step).
//   2. The Echoel track (it IS the instrument's part) and an audio track are refused by device
//      name, and nothing changes.
//   3. A part of the person's own inside the loop is refused, and nothing changes.
//   4. A track that already composes says so and journals nothing.
//   5. A variation a person rolled since is kept on Undo — and so is the part.
//   6. PARSER: `track.composeHere` takes exactly `track`; "the selected track" with none selected
//      is refused before any step runs.
//   8. Review LOW: after the song's Undo took the agent's part, a person turned it back on —
//      the agent's Undo keeps the variation that part now composes with.
//   7. The loop length is asked, not assumed (#431): the app hands the executor the rows' own key
//      (`TrackCompose.loopBars(in:)`), which falls back to the rows' default and reads a stored
//      length back — on a private suite, never the app's own defaults.
//
// GRADING (Tests/CISmoke/CLAUDE.md §3): the file names `EchoelCommand.composeHere`,
// `TrackCompose.loopBars(in:)` and two new errors, all created by this commit, so it does NOT
// compile against the parent and no assertion has a verdict there. All eight claims are FORWARD
// guards, hand-transcribed against the executor before the push.
//
// ⚠️ THE LIMIT. No intent posts `track.composeHere` yet — a Siri phrase is its own slice. Until
// then the command is reachable only through a planner. NOT covered: that the composer's notes
// arrive on the next take and sound — a device probe.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheAgentStartsATrackComposerTests: XCTestCase {

    private func rig(_ body: (TimelineStore, ClipStore, EchoelCommandExecutor, TimelineLane, TimelineLane)
                         async throws -> Void) async rethrows {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        defer {
            _ = clips.replaceSlots(originalSlots)
            timeline.replaceDocument(originalDocument)
        }
        XCTAssertTrue(clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount)),
                      "fixture premise: an empty grid")
        let echoel = TimelineLane(name: "AI-6c Echoel", kind: .midi)
        let track = TimelineLane(name: "AI-6c Track", kind: .midi)
        timeline.replaceDocument(TimelineDocument(lanes: [echoel, track], regions: []))
        XCTAssertEqual(timeline.document.rollLaneID, echoel.id, "fixture premise: the first MIDI track is the Echoel track")
        let looks = UserDefaults(suiteName: "echoel.tests.agentStartsATrackComposer") ?? UserDefaults()
        let executor = EchoelCommandExecutor(timeline: timeline, clips: clips, selection: WorkstationSelection(),
                                             voiceCapacity: { 4 }, loopBars: { Self.loopBars },
                                             mediaLooks: MediaLookUndo(),
                                             visualDefaults: looks)
        XCTAssertEqual(TrackMix.role(of: track.id, in: timeline.document, voiceCapacity: 4), .laneSynth(.poly),
                       "fixture premise: a rack voice plays the second MIDI track")
        try await body(timeline, clips, executor, echoel, track)
    }

    private static let loopBars = 4

    private func plan(_ steps: [EchoelCommand], on executor: EchoelCommandExecutor) -> EchoelActionPlan {
        EchoelActionPlan(requestID: UUID(), steps: steps, basis: executor.snapshot(), consents: [])
    }

    private func composing(_ lane: TimelineLane, _ timeline: TimelineStore, _ clips: ClipStore) -> Bool {
        TrackCompose.isComposing(lane.id, in: timeline.document, clips: clips.filledClips, loopBars: Self.loopBars)
    }

    // MARK: 1 — on, and the agent's Undo takes it back

    func testTheAgentStartsTheComposerAndItsUndoTakesItBack() async throws {
        try await rig { timeline, clips, executor, _, track in
            let report = await executor.execute(plan([.composeHere(track: .id(track.id))], on: executor))
            guard case .done = report.steps.first?.outcome else { return XCTFail("the composer starts: \(report)") }
            XCTAssertTrue(composing(track, timeline, clips), "the rows read it as on")
            XCTAssertEqual(timeline.document.regions(in: track.id).count, 1, "one composer part")
            let part = try XCTUnwrap(timeline.document.regions(in: track.id).first)
            XCTAssertEqual(clips.clip(id: part.clipID)?.composerOwned, true, "the composer's part")
            XCTAssertNotNil(timeline.document.lanes.first { $0.id == track.id }?.variationSeed,
                            "a variation of its own, so it composes its own line")
            XCTAssertTrue(executor.canUndoAgentChange)

            let undo = await executor.execute(plan([.undoAgentChange], on: executor))
            guard case .done = undo.steps.first?.outcome else { return XCTFail("undo runs: \(undo)") }
            XCTAssertTrue(timeline.document.regions(in: track.id).isEmpty, "the part is gone")
            XCTAssertNil(timeline.document.lanes.first { $0.id == track.id }?.variationSeed,
                         "the variation follows the piece again")
            XCTAssertFalse(composing(track, timeline, clips), "the rows read it as off")

            timeline.undo()
            XCTAssertTrue(timeline.document.regions.contains { $0.id == part.id },
                          "the take-back was one ordinary song step")
        }
    }

    // MARK: 2 — refused where no rack voice plays

    func testTheEchoelTrackAndAnAudioTrackAreRefused() async throws {
        try await rig { timeline, clips, executor, echoel, _ in
            let audio = TimelineLane(name: "AI-6c Audio", kind: .audio)
            timeline.replaceDocument(TimelineDocument(lanes: timeline.document.lanes + [audio], regions: []))
            let cases: [(TimelineLane, TrackMix.Role)] = [(echoel, .echoelInstrument), (audio, .audio)]
            for (lane, role) in cases {
                let before = (timeline.document, clips.slots)
                let report = await executor.execute(plan([.composeHere(track: .id(lane.id))], on: executor))
                XCTAssertEqual(report.steps.first?.outcome, .failed(.cannotCompose(TrackMix.deviceName(role))),
                               "\(lane.name) has no rack voice to play what the composer writes")
                XCTAssertEqual(timeline.document, before.0)
                XCTAssertEqual(clips.slots, before.1)
                XCTAssertFalse(executor.canUndoAgentChange)
            }
        }
    }

    // MARK: 3 — never over the person's own part

    func testAPartOfThePersonsOwnInTheLoopIsRefused() async throws {
        try await rig { timeline, clips, executor, _, track in
            let own = Clip(name: "AI-6c own", kind: .midi, melody: MelodyClip(notes: [Note(pitch: 60, startStep: 0)]))
            clips.setClip(at: 1, own)
            let ownPart = TimelineRegion(laneID: track.id, clipID: own.id, startTick: 0,
                                         lengthTicks: TimelineTime.ticksPerBar)
            timeline.replaceDocument(TimelineDocument(lanes: timeline.document.lanes, regions: [ownPart]))
            let before = (timeline.document, clips.slots)
            let report = await executor.execute(plan([.composeHere(track: .id(track.id))], on: executor))
            XCTAssertEqual(report.steps.first?.outcome, .failed(.wouldCoverOwnPart))
            XCTAssertEqual(timeline.document, before.0, "no part placed over it, no variation written")
            XCTAssertEqual(clips.slots, before.1)
            XCTAssertFalse(executor.canUndoAgentChange)
        }
    }

    // MARK: 4 — already on

    func testATrackThatAlreadyComposesJournalsNothing() async throws {
        try await rig { timeline, clips, executor, _, track in
            XCTAssertNil(TrackCompose.turnOn(track.id, timeline: timeline, clips: clips,
                                             loopBars: Self.loopBars, seed: 42), "the person turned it on")
            let before = timeline.document
            let report = await executor.execute(plan([.composeHere(track: .id(track.id))], on: executor))
            guard case .done = report.steps.first?.outcome else { return XCTFail("it says so: \(report)") }
            XCTAssertEqual(timeline.document, before, "nothing written")
            XCTAssertFalse(executor.canUndoAgentChange, "nothing of the agent's to take back")
        }
    }

    // MARK: 5 — a variation rolled since is the person's

    func testAVariationRolledSinceIsKeptWithItsPart() async throws {
        try await rig { timeline, clips, executor, _, track in
            _ = await executor.execute(plan([.composeHere(track: .id(track.id))], on: executor))
            let part = try XCTUnwrap(timeline.document.regions(in: track.id).first)
            timeline.setLaneVariationSeed(track.id, seed: 7)   // "New variation" on the rows
            let undo = await executor.execute(plan([.undoAgentChange], on: executor))
            XCTAssertEqual(undo.steps.first?.outcome, .failed(.changedSince("The variation of \(track.name)")))
            XCTAssertEqual(timeline.document.lanes.first { $0.id == track.id }?.variationSeed, 7,
                           "the person's variation stays")
            XCTAssertTrue(timeline.document.regions.contains { $0.id == part.id }, "and so does the part")
        }
    }

    // MARK: 8 — turned back on by a person after the song's Undo: theirs

    func testAComposerTurnedBackOnByAPersonIsKept() async throws {
        try await rig { timeline, clips, executor, _, track in
            _ = await executor.execute(plan([.composeHere(track: .id(track.id))], on: executor))
            let seed = timeline.document.lanes.first { $0.id == track.id }?.variationSeed
            timeline.undo()   // the song's Undo takes the agent's part back
            XCTAssertNil(TrackCompose.turnOn(track.id, timeline: timeline, clips: clips,
                                             loopBars: Self.loopBars, seed: 42), "the person turns it on again")
            let undo = await executor.execute(plan([.undoAgentChange], on: executor))
            XCTAssertEqual(undo.steps.first?.outcome, .failed(.changedSince("The composer on \(track.name)")))
            XCTAssertEqual(timeline.document.lanes.first { $0.id == track.id }?.variationSeed, seed,
                           "the variation the person's part composes with stays")
            XCTAssertTrue(composing(track, timeline, clips), "and the rows still read on")
        }
    }

    // MARK: 7 — the loop length is the rows' own key

    func testTheLoopLengthIsTheRowsOwnKey() throws {
        let name = "echoel.tests.agentLoopBars"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        XCTAssertEqual(TrackCompose.loopBars(in: defaults), StudioDefaultKeys.loopBars.value.rawValue,
                       "nothing stored: the rows' default")
        let other = try XCTUnwrap(LoopBarLength.allCases.first { $0 != StudioDefaultKeys.loopBars.value },
                                  "fixture premise: more than one loop length")
        defaults.set(other.rawValue, forKey: StudioDefaultKeys.loopBars.key)
        XCTAssertEqual(TrackCompose.loopBars(in: defaults), other.rawValue, "a stored length is read back")
        defaults.set(-3, forKey: StudioDefaultKeys.loopBars.key)
        XCTAssertEqual(TrackCompose.loopBars(in: defaults), StudioDefaultKeys.loopBars.value.rawValue,
                       "an unreadable length falls back, as the rows' storage does")

        var root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: root.appendingPathComponent("Package.swift").path) {
            guard root.pathComponents.count > 1 else { throw XCTSkip("source tree not present above \(#filePath)") }
            root = root.deletingLastPathComponent()
        }
        let app = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(
            "Sources/Echoelmusic/EchoelmusicApp.swift"), encoding: .utf8))
        XCTAssertTrue(app.contains("loopBars: { TrackCompose.loopBars(in: .standard) },"),
                      "the app hands the executor the rows' own key")
    }

    // MARK: 6 — the parser, and no selection

    func testTheParserTakesExactlyATrackAndNoSelectionIsRefused() async throws {
        func parse(_ arguments: [String: String]) -> Result<EchoelCommand, EchoelCommandError> {
            EchoelCommandParser.parse(EchoelProposedAction(command: "track.composeHere", arguments: arguments))
        }
        XCTAssertEqual(parse(["track": "selected"]), .success(.composeHere(track: .selected)))
        XCTAssertEqual(parse(["track": "selected", "genre": "house"]), .failure(.unknownArgument("genre")))
        XCTAssertEqual(parse([:]), .failure(.invalidArgument("that track")))
        XCTAssertEqual(EchoelCommandRegistry.spec(.composeHere).permission, .reversibleEdit)

        try await rig { timeline, _, executor, _, _ in
            let before = timeline.document
            let report = await executor.execute(plan([.composeHere(track: .selected)], on: executor))
            XCTAssertEqual(report.refusal, .nothingSelected("track"), "refused before any step")
            XCTAssertEqual(timeline.document, before)
        }
    }
}
