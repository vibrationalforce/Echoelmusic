// TheSceneLaunchIsASwitchTests.swift
// Echoel — Phase 3 / Clips·Scenes·Session, first slice S1 "Perform scenes" (plan
// `scratchpads/PLAN_CLIPS_SCENES_2026-09-26.md`). Until now "Launch scene" called
// `launchRegion` once per cell: the scene's parts launched, and every OTHER launched track kept
// looping whatever it had — so two scenes in a row played as their union, and nothing brought the
// whole song back in one tap. A scene is now a SWITCH: its parts launch and every other launched
// track returns to the song, all on the same bar, and "Back to song" returns every track at once.
//
// WHAT IT PINS.
// 1. END-TO-END BEHAVIOUR (`ClipLaunchEngine`, a pure public value type): a scene switches a
//    playing lane, starts an idle one and stops the lane it leaves out — all three at ONE
//    boundary; a lane already looping its scene part is untouched; "Back to song" stops every
//    lane on one boundary and simply cancels a launch that never started; an empty scene on an
//    idle engine leaves it idle.
// 2. END-TO-END BEHAVIOUR (`SessionGrid.sceneState`): a scene reads "Playing" only when every
//    cell's track loops that cell's part AND every other track is on the song; "Queued" while
//    the rest is on its way at the boundary; neither while any track plays something else.
// 3. SOURCE-TEXT SCAN: the player's `launchScene` asks the ONE launch rule `launchRegion` asks
//    (the lane refusal literal occurs once in the file), no-ops while stopped and bumps
//    `launchGeneration` once; `stopAllLaunched` goes through the engine; the view's scene button
//    makes ONE player call and never loops `launchRegion`.
//
// HONEST GRADING (§3), against the parent tree (`c5dd5e6b1`): the file does NOT compile there —
// `requestScene`, `requestStopAll` and `SessionGrid.sceneState` are new — so no assertion has a
// verdict on the parent; every claim is a FORWARD guard (one absence, #486). Counterweights
// (#343): claim 1 asserts a lane already playing its scene part keeps its anchor (the
// `requestLaunch` no-op law survives the composition), and claim 3 asserts `launchRegion` still
// refuses on its own (`TheSessionLaunchesWhatTheSongPlaysTests` pins the literal's range).
// Graded by Python transcription of the engine laws and every scan anchor against the worktree.
//
// REVIEW OF f5b573b9e (no HIGH): MED — the Back-to-song claim was satisfied by the DECLARATION;
// it now scans the launched-tracks block for the USE (mutant without the use: red). LOW 7 — the
// two missing composition paths and the queued-stop scene state are driven here. LOW 2/3/5/6
// repaired in the sources; LOW 4 (two scenes with identical cells both read Playing) recorded.
//
// 4. S2: a scene starts a STOPPED song at its bar — the view asks the Workstation's transport
//    (`playFrom`, the Workstation stays the one `player.play(` caller) with the scene's parts;
//    a launch requested on a boundary lands on that bar and does not fire twice (engine, end to
//    end).
//
// 5. S2 REVIEW of 526804d0c (no HIGH). MED-1: starting a scene AFTER `play` returned let the
//    audio prime start the arrangement's file on the scene's lane, and the launch restart it
//    from the top one step later — the same file twice. `play` now takes the scene's parts and
//    fires them on the start bar inside the call; the audio prime warms but does not start a
//    lane its launch owns. END-TO-END against `AudioLanePlayer` with a spy sink (one start,
//    counterweight: the old order is two); the `play` → prime link is SOURCE-TEXT only (the
//    order scan). Review of e245def93: no HIGH/MED. MED-2: the spoken
//    hint named "Bar 5 beat 3" while the song starts on Bar 5 — `songStartLabel`, end to end.
//    LOW 1 (a `canPlay` refusal makes the scene button do nothing, as it does Play) and LOW 2
//    (the old claim was order-only) recorded; LOW 2 is answered by the spy test.
//    GRADING: the new claims name `songStartLabel`, `prime(…launchingInThisCall:)` and
//    `play(…launching:)`, which do not exist at 526804d0c, so the file does not compile there —
//    FORWARD guards, one absence (#486). Transcribed in Python against the worktree: every scan
//    anchor green.
//
// NOT HERE — DEVICE PROBE, open. That the switch is HEARD on one bar, and reads well on iPhone.
// NEEDS-FOUNDER-VERIFY: Workstation → Play → Session → "Launch scene" at Bar 1, then at a later
// bar → on the next bar only the second scene's parts loop and the other tracks play the song;
// the scene header reads "Queued" then "Playing". "Back to song" → every track plays the song.
// NEEDS-FOUNDER-VERIFY: S2 — song stopped → Session → "Launch scene" at a later bar → the song
// starts at that bar and the scene loops; Stop, then Play → the song from the top.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheSceneLaunchIsASwitchTests: XCTestCase {

    private static let playerPath = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let viewPath = "Sources/Echoelmusic/Studio/SessionLaunchView.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let bar = TimelineTime.ticksPerBar

    // MARK: 1 — the engine: a scene is a switch on one boundary

    func testASceneSwitchesStartsAndStopsOnOneBoundary() {
        let (laneA, laneB, laneC) = (UUID(), UUID(), UUID())
        let (a1, a2, b1, c1) = (UUID(), UUID(), UUID(), UUID())
        var engine = ClipLaunchEngine()
        engine.requestLaunch(laneID: laneA, regionID: a1, atTick: 0, quantize: .bar)
        engine.requestLaunch(laneID: laneC, regionID: c1, atTick: 0, quantize: .bar)
        let first = engine.tick(now: 0)
        XCTAssertEqual(first.count, 2, "both launches fire at the first boundary")

        engine.requestScene([laneA: a2, laneB: b1], atTick: 100, quantize: .bar)
        XCTAssertEqual(engine.state(laneID: laneA),
                       .queued(regionID: a2, startAtTick: Self.bar,
                               current: LaunchedRegion(regionID: a1, startedAtTick: 0)))
        XCTAssertEqual(engine.state(laneID: laneB), .queued(regionID: b1, startAtTick: Self.bar, current: nil))
        XCTAssertEqual(engine.state(laneID: laneC),
                       .queuedStop(current: LaunchedRegion(regionID: c1, startedAtTick: 0), stopAtTick: Self.bar),
                       "the lane the scene leaves out goes back to the song")

        let early = engine.tick(now: Self.bar - 1)
        XCTAssertTrue(early.isEmpty, "nothing fires before the bar")
        let fired = engine.tick(now: Self.bar)
        XCTAssertEqual(Set(fired.map(\.atTick)), [Self.bar], "one boundary for the whole switch")
        XCTAssertEqual(Set(fired.map(\.laneID)), [laneA, laneB, laneC])
        XCTAssertEqual(engine.state(laneID: laneA), .playing(LaunchedRegion(regionID: a2, startedAtTick: Self.bar)))
        XCTAssertEqual(engine.state(laneID: laneB), .playing(LaunchedRegion(regionID: b1, startedAtTick: Self.bar)))
        XCTAssertEqual(engine.state(laneID: laneC), .idle)
    }

    func testALaneAlreadyPlayingItsScenePartKeepsItsLoop() {
        let lane = UUID(), region = UUID()
        var engine = ClipLaunchEngine()
        engine.requestLaunch(laneID: lane, regionID: region, atTick: 0, quantize: .bar)
        _ = engine.tick(now: 0)
        engine.requestScene([lane: region], atTick: 700, quantize: .bar)
        XCTAssertEqual(engine.state(laneID: lane), .playing(LaunchedRegion(regionID: region, startedAtTick: 0)),
                       "re-launching the same scene never restarts a part that is already looping")

        // Review of f5b573b9e, LOW 7: the two other composition paths.
        engine.requestStop(laneID: lane, atTick: 800, quantize: .bar)
        engine.requestScene([lane: region], atTick: 900, quantize: .bar)
        XCTAssertEqual(engine.state(laneID: lane), .playing(LaunchedRegion(regionID: region, startedAtTick: 0)),
                       "a scene that keeps the part cancels its queued stop")
        engine.requestLaunch(laneID: lane, regionID: UUID(), atTick: 1000, quantize: .bar)
        engine.requestScene([lane: region], atTick: 1100, quantize: .bar)
        XCTAssertEqual(engine.state(laneID: lane), .playing(LaunchedRegion(regionID: region, startedAtTick: 0)),
                       "a scene that keeps the sounding part cancels a queued switch away from it")
    }

    func testBackToSongStopsEveryLaneOnOneBoundary() {
        let (playing, waiting) = (UUID(), UUID())
        let (p1, w1) = (UUID(), UUID())
        var engine = ClipLaunchEngine()
        engine.requestLaunch(laneID: playing, regionID: p1, atTick: 0, quantize: .bar)
        _ = engine.tick(now: 0)
        engine.requestLaunch(laneID: waiting, regionID: w1, atTick: 10, quantize: .bar)
        engine.requestStopAll(atTick: 10, quantize: .bar)
        XCTAssertEqual(engine.state(laneID: playing),
                       .queuedStop(current: LaunchedRegion(regionID: p1, startedAtTick: 0), stopAtTick: Self.bar))
        XCTAssertEqual(engine.state(laneID: waiting), .idle, "a launch that never started is cancelled")
        _ = engine.tick(now: Self.bar)
        XCTAssertTrue(engine.isIdle, "every track plays the song again")

        var idle = ClipLaunchEngine()
        idle.requestScene([:], atTick: 0, quantize: .bar)
        idle.requestStopAll(atTick: 0, quantize: .bar)
        XCTAssertTrue(idle.isIdle, "an empty scene and Back to song on an idle engine change nothing")
    }

    // MARK: 2 — what a scene reads

    func testASceneIsPlayingOnlyWhenItOwnsEveryTrack() {
        let (t1, t2, t3) = (UUID(), UUID(), UUID())
        let tracks = [t1, t2, t3].map { SessionGrid.Track(id: $0, name: "T") }
        let (r1, r2, other) = (UUID(), UUID(), UUID())
        let scene = SessionGrid.LaunchScene(startTick: 0, cells: [t1: r1, t2: r2])
        func looping(_ region: UUID) -> LaneLaunchState {
            .playing(LaunchedRegion(regionID: region, startedAtTick: 0))
        }

        XCTAssertEqual(SessionGrid.sceneState(scene, tracks: tracks, states: [t1: looping(r1), t2: looping(r2)]),
                       .playing)
        XCTAssertNil(SessionGrid.sceneState(scene, tracks: tracks, states: [:]),
                     "nothing launched: the song plays, not the scene")
        XCTAssertEqual(SessionGrid.sceneState(scene, tracks: tracks, states: [
            t1: looping(r1),
            t2: .queued(regionID: r2, startAtTick: Self.bar, current: nil),
            t3: .queuedStop(current: LaunchedRegion(regionID: other, startedAtTick: 0), stopAtTick: Self.bar)
        ]), .queued, "on its way at the boundary")
        XCTAssertNil(SessionGrid.sceneState(scene, tracks: tracks, states: [
            t1: looping(r1), t2: looping(r2), t3: looping(other)
        ]), "a track outside the scene still loops something else")
        XCTAssertNil(SessionGrid.sceneState(scene, tracks: tracks, states: [
            t1: .queued(regionID: other, startAtTick: Self.bar,
                        current: LaunchedRegion(regionID: r1, startedAtTick: 0)),
            t2: looping(r2)
        ]), "a track switching AWAY from the scene's part is not the scene")
        XCTAssertNil(SessionGrid.sceneState(scene, tracks: tracks, states: [
            t1: .queuedStop(current: LaunchedRegion(regionID: r1, startedAtTick: 0), stopAtTick: Self.bar),
            t2: looping(r2)
        ]), "a scene part on its way back to the song is not the scene")
    }

    // MARK: 3 — one rule, one call

    func testThePlayerSwitchesThroughTheOneLaunchRule() throws {
        let player = try source(Self.playerPath)
        XCTAssertEqual(player.components(separatedBy: "(lane.kind == .midi || lane.kind == .audio), !lane.isBio").count - 1,
                       1, "one launch rule for a part and a scene (#416)")
        let single = try body(of: "public func launchRegion(", in: player)
        XCTAssertTrue(single.contains("launchableLaneID(ofRegion: regionID)"))
        let scene = try body(of: "public func launchScene(", in: player)
        XCTAssertTrue(scene.contains("guard isPlaying else { return }"), "launching rides the running song")
        XCTAssertTrue(scene.contains("launch.requestScene(sceneLaunches(regionIDs)"))
        let lanes = try body(of: "private func sceneLaunches(", in: player)
        XCTAssertTrue(lanes.contains("launchableLaneID(ofRegion: regionID)"))
        XCTAssertEqual(scene.components(separatedBy: "launchGeneration &+= 1").count - 1, 1,
                       "one repaint for the whole switch")
        let all = try body(of: "public func stopAllLaunched(", in: player)
        XCTAssertTrue(all.contains("launch.requestStopAll("))
        XCTAssertTrue(all.contains("launchGeneration &+= 1"))
    }

    func testTheSceneButtonMakesOnePlayerCall() throws {
        let view = try source(Self.viewPath)
        let scene = try body(of: "private func launchScene(_ scene: SessionGrid.LaunchScene)", in: view)
        XCTAssertEqual(scene.components(separatedBy: "player.launchScene(parts, quantize: SessionGrid.quantize)").count - 1, 1)
        XCTAssertFalse(scene.contains("launchRegion"),
                       "a per-cell loop cannot stop the tracks the scene leaves out")
        let back = try body(of: "private var backToSongButton: some View", in: view)
        XCTAssertTrue(back.contains("player.stopAllLaunched(quantize: SessionGrid.quantize)"))
        XCTAssertTrue(view.contains("SessionGrid.sceneState(scene, tracks: tracks, states: states)"))
        // Review of f5b573b9e, MED: the DECLARATION satisfied a bare `contains`; the USE is what
        // puts the button on screen — inside the launched-tracks block, from two tracks on.
        // Anchor WITHOUT the brace: `body(of:)` opens at the first `{` after the anchor.
        let launchedBlock = try body(of: "if playing && !launched.isEmpty", in: view)
        XCTAssertTrue(launchedBlock.contains("if launched.count > 1 {"))
        XCTAssertTrue(launchedBlock.contains("backToSongButton"),
                      "Back to song is on screen while two or more tracks are launched")
    }

    // MARK: 4 — S2: a scene starts a stopped song at its bar

    func testALaunchOnTheBoundaryLandsOnThatBar() {
        // `play(fromTick:)` floors to the bar, so the launch that follows it is requested ON a
        // boundary; `boundaryTick(onOrAfter:)` maps that to itself, so it lands there — not a bar
        // later.
        let lane = UUID(), region = UUID()
        var engine = ClipLaunchEngine()
        engine.requestScene([lane: region], atTick: 2 * Self.bar, quantize: .bar)
        let fired = engine.tick(now: 2 * Self.bar)
        XCTAssertEqual(fired.map(\.atTick), [2 * Self.bar])
        XCTAssertEqual(engine.state(laneID: lane), .playing(LaunchedRegion(regionID: region, startedAtTick: 2 * Self.bar)))
        // S2 review (MED-1): `play` fires the scene itself, so the first transport step asks the
        // engine at the SAME tick again — and must find nothing left to start.
        let firstStep = engine.tick(now: 2 * Self.bar)
        XCTAssertTrue(firstStep.isEmpty, "the first transport step never starts a scene part a second time")
    }

    /// S2 review (MED-1), END-TO-END against `AudioLanePlayer` (NOT through `play` — the link
    /// from `play` to this call is held by the order scan below): a lane whose launch fires
    /// in the same call is warmed by `prime` but NOT started — the launch starts it once.
    /// Counterweight: the plain prime still starts the arrangement, and a launch after it is
    /// the second start that was the defect.
    func testAnAudioScenePartStartsOnce() {
        let lane = TimelineLane(name: "Audio 1", kind: .audio)
        let clipID = UUID()
        let region = TimelineRegion(laneID: lane.id, clipID: clipID, startTick: 2 * Self.bar,
                                    lengthTicks: 4 * Self.bar, warpEnabled: false, stretchMode: .clean)
        let doc = TimelineDocument(lanes: [lane], regions: [region])
        func coordinator() -> (AudioLanePlayer, Spy) {
            let spy = Spy()
            let url = URL(fileURLWithPath: "/tmp/loop.wav")
            let player = AudioLanePlayer(makeSink: { spy },
                                         resolveURL: { $0 == clipID ? url : nil },
                                         resolveNativeBPM: { _ in 0 })
            return (player, spy)
        }

        let (scene, sceneSpy) = coordinator()
        scene.prime(in: doc, atTick: 2 * Self.bar, bpm: 120, launchingInThisCall: [lane.id])
        XCTAssertEqual(sceneSpy.plays, 0, "the launching lane is warmed, not started")
        XCTAssertEqual(sceneSpy.preloads, 1, "its file is still warmed at prime time")
        scene.setLaunchOverride(region, laneID: lane.id, atTick: 2 * Self.bar, in: doc, bpm: 120)
        XCTAssertEqual(sceneSpy.plays, 1, "the scene part starts exactly once")

        let (song, songSpy) = coordinator()
        song.prime(in: doc, atTick: 2 * Self.bar, bpm: 120)
        XCTAssertEqual(songSpy.plays, 1, "plain Play still starts the arrangement")
        song.setLaunchOverride(region, laneID: lane.id, atTick: 2 * Self.bar, in: doc, bpm: 120)
        XCTAssertEqual(songSpy.plays, 2, "a launch AFTER the prime is the restart MED-1 removed from play")
    }

    @MainActor
    private final class Spy: AudioRegionSink {
        var plays = 0
        var preloads = 0
        func play(url: URL, fromSeconds: Double, lengthSeconds: Double, gain: Float,
                  stretch: StretchPlan) { plays += 1 }
        func stop() {}
        func preload(url: URL, warped: Bool) { preloads += 1 }
        func prepareBeats(url: URL, fromSeconds: Double, lengthSeconds: Double, rate: Double) {}
        func setTranspose(_ semitones: Int) {}
    }

    func testAStoppedSongStartsThroughTheWorkstationsTransport() throws {
        let view = try source(Self.viewPath)
        XCTAssertTrue(view.contains("let playFrom: (_ tick: Int, _ parts: [UUID]) -> Void"))
        XCTAssertFalse(view.contains("player.play("), "the view asks the owner; it never starts the transport")
        let scene = try body(of: "private func launchScene(_ scene: SessionGrid.LaunchScene)", in: view)
        XCTAssertTrue(scene.contains("playFrom(scene.startTick, parts)"),
                      "a stopped song is started WITH the scene's parts (S2 review, MED-1)")

        let workstation = try source(Self.workstationPath)
        XCTAssertTrue(workstation.contains("SessionLaunchView(playFrom: { tick, parts in startTimeline(fromTick: tick, launching: parts) })"))
        XCTAssertTrue(workstation.contains("startTimeline(fromTick: 0, launching: [])"), "Play is still the song from the top")
        let start2 = try body(of: "private func startTimeline(fromTick: Int, launching: [UUID])", in: workstation)
        XCTAssertTrue(start2.contains("fromTick: fromTick"))
        XCTAssertTrue(start2.contains("launching: launching"))

        // Premises (#343): play clears launches, and floors the start to a bar.
        let player = try source(Self.playerPath)
        let play = try body(of: "public func play(", in: player)
        XCTAssertTrue(play.contains("launch.removeAll()"))
        XCTAssertTrue(play.contains("Self.barStartTick(for: fromTick, loopTicks: loopTicks)"))
    }

    /// S2 review (MED-1), SOURCE-TEXT SCAN: inside `play`, the scene is fired on the start bar
    /// BEFORE any lane starts, a launched roll lane skips its arrangement load, the audio prime
    /// is told which lanes the launch owns, and the launch is applied before the clock runs.
    func testPlayLandsTheSceneBeforeAnyLaneStarts() throws {
        let player = try source(Self.playerPath)
        let play = try body(of: "public func play(", in: player)
        guard let fire = play.range(of: "launchesOnTheStartBar(sceneRegionIDs, atTick: startTick)"),
              let roll = play.range(of: "loadRollRegion(at: startTick)"),
              let prime = play.range(of: "launchingInThisCall: Set(startLaunches.map("),
              let apply = play.range(of: "applyLaunchTransitions(startLaunches, atTick: startTick, step: 0)"),
              let clock = play.range(of: "pattern.play(cause: .timelineRegion)"),
              let cleared = play.range(of: "launch.removeAll()") else {
            return XCTFail("ANCHOR MISSING: play's start-bar scene sequence (#454)")
        }
        XCTAssertLessThan(cleared.lowerBound, fire.lowerBound, "the scene is queued on an emptied engine")
        XCTAssertLessThan(fire.lowerBound, roll.lowerBound, "fired before the roll decides what to load")
        XCTAssertLessThan(roll.lowerBound, prime.lowerBound)
        XCTAssertLessThan(prime.lowerBound, apply.lowerBound, "the files are warm before the launch starts one")
        XCTAssertLessThan(apply.lowerBound, clock.lowerBound, "the parts are in place before the clock runs")
        XCTAssertTrue(play.contains("launch.isOverriding(laneID: $0)"), "a launched roll lane skips the arrangement load")

        let start = try body(of: "private func launchesOnTheStartBar(", in: player)
        XCTAssertTrue(start.contains("launch.requestScene(launches, atTick: tick, quantize: .bar)"))
        XCTAssertTrue(start.contains("return launch.tick(now: tick)"))

        let lanes = try source("Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift")
        XCTAssertTrue(lanes.contains("if overrides[laneID] != nil || launchingInThisCall.contains(laneID) { continue }"),
                      "the audio prime skips the start of a lane its launch owns")
    }

    /// S2 review (MED-2), END-TO-END: the song starts on the bar, so the spoken hint names the
    /// bar — never the beat of a mid-bar scene.
    func testTheStartHintNamesTheBarTheSongStartsOn() throws {
        XCTAssertEqual(SessionGrid.songStartLabel(forTick: 4 * Self.bar + 2 * TimelineTime.ticksPerBeat), "Bar 5")
        XCTAssertEqual(SessionGrid.songStartLabel(forTick: 4 * Self.bar), "Bar 5")
        XCTAssertEqual(SessionGrid.label(forTick: 4 * Self.bar + 2 * TimelineTime.ticksPerBeat), "Bar 5 beat 3",
                       "counterweight: the scene itself keeps its beat")
        let view = try source(Self.viewPath)
        XCTAssertTrue(view.contains("Starts the song at the start of \\(songStart)"))
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    /// The brace-matched body after the first occurrence of `anchor` (#408).
    private func body(of anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code[start.upperBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
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
}
