// PerformIsASecondViewOfTheSameSessionTests.swift
// Echoel — DMMW Phase 3 · slice 1 (founder 2026-09-29: "Compose und Perform als zwei Sichten
// derselben Session — gleiche IDs, keine Kopien. Perform kann starten, stoppen, muten und
// Clips/Parts wechseln").
//
// WHAT IT PINS. The Perform plate (the Sound panel behind the area row's "Perform") showed the
// instrument's sound controls and nothing of the song: the parts a player wrote in Compose could
// be launched only from inside the Workstation. `PerformSessionView` mounts the EXISTING Session
// projection (`SessionLaunchView`) on that plate — no copy of the grid, no second scene list, no
// second start.
//
// 1. END-TO-END BEHAVIOUR over the real `TimelineStore`, `ClipStore`, `TimelineRegionPlayer`
//    and `PatternEngine` → `Transport`: the scene the Perform grid would offer is computed from
//    the store's document with the view's own inputs, and its cell holds the DOCUMENT's region
//    id — the id Compose selects, edits and moves. Starting it through the one start
//    (`WorkstationView.startSong`, the call the Perform door makes) runs the song at the scene's
//    bar with that region launched on its lane; the ONE Stop (`ProjectTransport.stop`) ends the
//    song and the clock every surface reads.
// 2. SOURCE-TEXT SCAN (the view is a `View`; its body cannot be driven here): the Sound panel
//    mounts the leaf exactly once; the leaf hands the grid a start that goes through
//    `WorkstationView.startSong` with the scene's bar and parts; it constructs no store, calls no
//    `player.play(`, asks no second `canPlay`, opens no modal, runs no timer; `beatPlayer` is read
//    only inside the start closure (the freeze law — `pattern` leads to the gliding tempo).
// 3. The words: the empty note names the area where parts are made BY ITS LABEL, and the
//    Perform area's spoken hint says the plate now holds the song's scenes (#482: a door's
//    spoken name lists what it reaches).
//
// GRADING (§3). Against the parent (`fec4463dc`) this file does NOT COMPILE —
// `PerformSessionView` is new — so no assertion has a verdict there: ONE absence (#486), every
// claim a FORWARD guard. Counterweights (#343), green on both trees: claim 1's scene
// computation and start/stop (the Workstation's path, unchanged). Transcribed in Python against
// THIS tree (no toolchain here): each scan needle found, each ban absent.
//
// 4. SLICE 2 — Mute and Solo. END-TO-END over a real `TimelineStore`: `mixRows` offers exactly
//    the HEARD tracks (`TrackMix.controls(…).muteSolo`, the track header's rule), and a flip
//    through `TrackMix.flipMute`/`flipSolo` is the same lane flag the Workstation's header reads.
//    SOURCE: the switches write only through those two doors and speak `TrackMix.muteHint`/
//    `soloHint`; 44-pt targets; toggle trait and value for VoiceOver.
//    GRADING: `mixRows` is new, so again no verdict on the parent — FORWARD guards.
//
// ⛔ HONEST LIMITS. Part SWITCHING by tapping a single cell while stopped is not here: the grid's
// per-part launch is disabled while the song is stopped (a scene starts it). Since B3c each Mute
// or Solo tap is one Undo step in both views (`EveryHandMadeMixChangeIsOneUndoStepTests`).
// That the grid reads well on the Sound panel, on an iPhone, with VoiceOver, is a DEVICE PROBE.
// NEEDS-FOUNDER-VERIFY: Compose → write a part → Perform → the part's bar appears as a scene →
// "Launch scene" starts the song there → the header's Stop ends it; VoiceOver reads the scene.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class PerformIsASecondViewOfTheSameSessionTests: XCTestCase {

    private static let leafPath = "Sources/Echoelmusic/Studio/PerformSessionView.swift"
    private static let studioPath = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
    }

    // MARK: 1 — the same ids, the one start, the one Stop

    func testAPerformSceneIsTheDocumentsPartAndStartsThroughTheOneStart() {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        restore.append { clips.replaceSlots(originalSlots); timeline.replaceDocument(originalDocument) }
        clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount))
        let clip = Clip(name: "Keys", melody: MelodyClip(notes: [Note(pitch: 60, startStep: 0, lengthSteps: 4)]))
        clips.setClip(at: 0, clip)
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let bar = TimelineTime.ticksPerBar
        let region = TimelineRegion(laneID: lane.id, clipID: clip.id,
                                    startTick: 2 * bar, lengthTicks: bar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [region]))

        let player = TimelineRegionPlayer()
        let pattern = PatternEngine()
        let transport = Transport()
        pattern.transport = transport
        transport.addStopSubscriber("timeline") { [weak player] in player?.handleTransportStopped() }
        restore.append { player.stop(); pattern.stop() }

        // The grid's own inputs, exactly as `SessionLaunchView.body` reads them.
        let document = timeline.document
        let playable = SessionGrid.playableRegionIDs(
            in: document, clips: clips.filledClips, bpm: player.preflightTempo,
            resolveAudio: { player.audioLanes?.resolvedURL(forClipID: $0) })
        let scenes = SessionGrid.scenes(in: document, voiceCapacity: player.laneVoiceCapacity,
                                        playable: playable)
        guard let scene = scenes.first else {
            return XCTFail("ANCHOR: the fixture part must open a scene, or nothing below says anything")
        }
        XCTAssertEqual(scenes.count, 1)
        XCTAssertEqual(scene.startTick, region.startTick, "the scene is the part's bar")
        XCTAssertEqual(scene.cells, [lane.id: region.id], """
            the Perform cell holds the DOCUMENT's region id — the id Compose edits. A copy or a \
            second scene list would carry its own ids.
            """)
        XCTAssertTrue(WorkstationView.songCanStart(player: player, timeline: timeline, clipStore: clips),
                      "the empty note is hidden exactly when the one start guard says the song can start")

        // What the Perform door's closure does for a stopped song.
        let parts = Array(scene.cells.values)
        WorkstationView.startSong(player: player, timeline: timeline, clipStore: clips,
                                  pattern: pattern, pianoRoll: PianoRollModel(),
                                  fromTick: scene.startTick, launching: parts)
        XCTAssertTrue(player.isPlaying, "the song runs")
        XCTAssertTrue(transport.isPlaying, "on the ONE clock")
        XCTAssertEqual(player.startedFromTick, 2 * bar, "from the scene's bar")
        XCTAssertEqual(player.launchState(laneID: lane.id),
                       .playing(LaunchedRegion(regionID: region.id, startedAtTick: 2 * bar)), """
            the scene's part is launched on its lane — the same region id, on the same player \
            the Workstation's Session grid reads
            """)

        ProjectTransport.stop(song: player, pattern: pattern, source: "test")
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(transport.isPlaying, "the ONE Stop ends what Perform started")
        XCTAssertEqual(player.launchState(laneID: lane.id), .idle, "and nothing stays launched")
    }

    // MARK: 2 — the leaf and its mount

    func testTheSoundPanelMountsTheLeafOnce() throws {
        let studio = try source(Self.studioPath)
        let panel = try member("private var soundPanel: some View {", in: studio)
        XCTAssertEqual(panel.components(separatedBy: "PerformSessionView()").count - 1, 1,
                       "the Perform plate shows the song's scenes, once")
        XCTAssertEqual(studio.components(separatedBy: "PerformSessionView(").count - 1, 1,
                       "and nowhere else in the root view")
    }

    func testTheLeafStartsThroughTheOneStartAndOwnsNothing() throws {
        let leaf = try source(Self.leafPath)
        // Review repair: the grid lives in the OPEN section's builder, not in `body` itself.
        let body = try member("@ViewBuilder private var openContent: some View {", in: leaf)
        let mount = try XCTUnwrap(body.range(of: "SessionLaunchView(playFrom: { tick, parts in"))
        let closure = String(body[mount.lowerBound...])
        XCTAssertTrue(closure.contains("WorkstationView.startSong(player: player, timeline: timeline, clipStore: clipStore,"))
        XCTAssertTrue(closure.contains("pattern: beatPlayer.pattern, pianoRoll: pianoRoll,"))
        XCTAssertTrue(closure.contains("fromTick: tick, launching: parts)"))
        XCTAssertTrue(body.contains("WorkstationView.songCanStart(player: player, timeline: timeline,"),
                      "the empty note asks the one start guard (#416)")

        // `beatPlayer` only inside the start closure: its `pattern` leads to the gliding tempo.
        let beforeMount = String(body[..<mount.lowerBound])
        XCTAssertFalse(beforeMount.contains("beatPlayer"), "no hot read in the leaf's body (freeze law)")
        XCTAssertEqual(leaf.components(separatedBy: "beatPlayer.").count - 1, 1)

        for banned in ["player.play(", "canPlay(", "TimelineStore(", "ClipStore(", "TimelineRegionPlayer(",
                       "PatternEngine(", "Transport(", ".sheet(", ".fullScreenCover(", ".alert(",
                       ".popover(", "Timer", ".task", ".onReceive(", "launchRegion", "launchScene("] {
            XCTAssertFalse(leaf.contains(banned), "the Perform leaf must not use \(banned)")
        }
    }

    // MARK: 2b — review repair: closed by default, no launch under the running instrument

    func testNoSceneIsOfferedWhileTheInstrumentPlaysAlone() {
        // END-TO-END over the pure rule, every row of the truth table.
        XCTAssertTrue(PerformSessionView.instrumentOnly(running: true, songPlaying: false), """
            the instrument runs on the clock and the song is stopped: a launch would start the \
            song under the running pattern — no scene is offered
            """)
        XCTAssertFalse(PerformSessionView.instrumentOnly(running: true, songPlaying: true),
                       "the song plays: scenes switch on the bar")
        XCTAssertFalse(PerformSessionView.instrumentOnly(running: false, songPlaying: false),
                       "nothing runs: a scene starts the song at its bar")
        XCTAssertTrue(PerformSessionView.instrumentRunningNote.contains("Stop it in the header"),
                      "the note names the control that resolves it")
        XCTAssertTrue(PerformSessionView.instrumentRunningNote.contains("scene"))
        // Review LOW: the toggle's spoken hint used to promise "Launch the song's scenes" in the
        // one state where the scenes are hidden. It now names that state and its way out — the
        // same Stop the note names.
        XCTAssertTrue(PerformSessionView.sectionHint.contains("plays on its own"),
                      "the hint names the state in which no scene is offered")
        XCTAssertTrue(PerformSessionView.sectionHint.contains("stop it in the header"),
                      "and the control that resolves it, the note's own Stop")
    }

    func testTheSectionAsksTheOneRunningTruthAndOpensOnDemand() throws {
        let leaf = try source(Self.leafPath)
        let open = try member("@ViewBuilder private var openContent: some View {", in: leaf)
        XCTAssertTrue(open.contains(
            "ProjectTransport.isRunning(clockRunning: transport.isPlaying, songPlaying: songPlaying)"),
                      "the ONE running truth the header reads (#416), not the song alone")
        guard let gate = open.range(of: "if instrumentOnly {"),
              let otherwise = open.range(of: "} else {", range: gate.upperBound..<open.endIndex),
              let grid = open.range(of: "SessionLaunchView(playFrom:") else {
            return XCTFail("ANCHOR MISSING: the instrument-only branch or the grid (#454)")
        }
        XCTAssertTrue(otherwise.upperBound <= grid.lowerBound,
                      "the grid is mounted only in the branch where the instrument does not run alone")
        XCTAssertTrue(leaf.contains("@State private var isOpen = false"),
                      "closed on every launch: the patch rows below stay in place")
        let body = try member("var body: some View {", in: leaf)
        XCTAssertTrue(body.contains("if isOpen {"))
        XCTAssertFalse(body.contains("songCanStart("),
                       "a closed section runs no preflight and builds no grid")
        let toggle = try member("private var sectionToggle: some View {", in: leaf)
        XCTAssertTrue(toggle.contains(".frame(minHeight: 44)"), "a 44-pt target")
        // E4-40: the value says Expanded/Collapsed like its three sibling disclosures, as two catalog keys.
        XCTAssertTrue(toggle.contains(".accessibilityValue(isOpen ? String(localized: \"Expanded\") : String(localized: \"Collapsed\"))"))
        XCTAssertTrue(toggle.contains(".accessibilityHint(Self.sectionHint)"),
                      "the toggle speaks the one hint that is true in both states")
        // #482: the Sound chip opens this panel, so its spoken name lists what it now reaches.
        // E4-73: the spoken name is a catalog key now — same sentence, read through String(localized:).
        let studio = try source(Self.studioPath)
        XCTAssertTrue(studio.contains(
            "case .sound:       return String(localized: \"Sound and texture, plus the piece's scenes and tracks\")"))
    }

    // MARK: 4 — slice 2: Mute and Solo, one lane flag seen from both views

    func testPerformMutesTheSameLaneFlagComposeShows() {
        let timeline = TimelineStore()
        let originalDocument = timeline.document
        restore.append { timeline.replaceDocument(originalDocument) }
        let keys = TimelineLane(name: "Keys", kind: .midi)
        let body = TimelineLane(name: "Body", kind: .midi, isBio: true)
        let loop = TimelineLane(name: "Loop", kind: .audio)
        let look = TimelineLane(name: "Look", kind: .visual)
        timeline.replaceDocument(TimelineDocument(lanes: [keys, body, loop, look], regions: []))

        let rows = PerformSessionView.mixRows(in: timeline.document, voiceCapacity: 0)
        XCTAssertEqual(rows.map(\.id), [keys.id, loop.id], """
            only HEARD tracks get a switch — the bio curve and a visual lane make no sound, so a \
            Mute there would move nothing (#164/#227)
            """)
        XCTAssertEqual(rows.map(\.id).filter { id in
            TrackMix.controls(of: id, in: timeline.document, voiceCapacity: 0)?.muteSolo == true
        }, rows.map(\.id), "the rule is the track header's own (`TrackMix.controls`)")

        TrackMix.flipMute(laneID: loop.id, timeline: timeline)
        TrackMix.flipSolo(laneID: keys.id, timeline: timeline)
        let after = PerformSessionView.mixRows(in: timeline.document, voiceCapacity: 0)
        XCTAssertEqual(after.first { $0.id == loop.id }?.isMuted, true)
        XCTAssertEqual(after.first { $0.id == keys.id }?.isSoloed, true)
        // Compose's header reads the SAME document flags — no copy to drift.
        XCTAssertEqual(timeline.document.lanes.first { $0.id == loop.id }?.isMuted, true)
        XCTAssertEqual(timeline.document.lanes.first { $0.id == keys.id }?.isSoloed, true)
        TrackMix.flipMute(laneID: loop.id, timeline: timeline)
        XCTAssertEqual(PerformSessionView.mixRows(in: timeline.document, voiceCapacity: 0)
                        .first { $0.id == loop.id }?.isMuted, false, "and a second tap clears it")
    }

    func testTheSwitchesWriteThroughTheTrackHeadersDoors() throws {
        let leaf = try source(Self.leafPath)
        let row = try member("private func mixRow(_ row: MixRow) -> some View {", in: leaf)
        XCTAssertTrue(row.contains("TrackMix.flipMute(laneID: row.id, timeline: timeline)"))
        XCTAssertTrue(row.contains("TrackMix.flipSolo(laneID: row.id, timeline: timeline)"))
        XCTAssertTrue(row.contains("hint: TrackMix.muteHint(row.role)"), "one wording of what Mute does (#416)")
        XCTAssertTrue(row.contains("hint: TrackMix.soloHint(row.role)"))
        XCTAssertFalse(leaf.contains("toggleMute("), "never the store directly — `TrackMix` is the door")
        XCTAssertFalse(leaf.contains("toggleSolo("))
        let control = try member("private func mixSwitch(", in: leaf)
        XCTAssertTrue(control.contains(".frame(minWidth: 44, minHeight: 44)"), "a 44-pt target")
        XCTAssertTrue(control.contains(".accessibilityAddTraits(.isToggle)"))
        // E4-44: both arms are catalog keys — the needle follows the spelling, the claim is unchanged.
        XCTAssertTrue(control.contains(".accessibilityValue(on ? String(localized: \"On\") : String(localized: \"Off\"))"))
    }

    // MARK: 3 — the words

    func testTheWordsNameTheAreaAndTheScenes() {
        XCTAssertEqual(StudioArea.compose.label, "Compose", "ANCHOR: the note names this label")
        XCTAssertTrue(PerformSessionView.emptyNote.contains(StudioArea.compose.label),
                      "the empty Perform grid names the area where parts are made")
        XCTAssertTrue(PerformSessionView.emptyNote.contains("scene"))
        XCTAssertTrue(StudioArea.perform.spokenHint.contains("scenes"), """
            the Perform door's spoken hint must list the song's scenes, which it now reaches (#482)
            """)
        XCTAssertTrue(StudioArea.perform.spokenHint.contains("Opens the Sound panel."),
                      "counterweight: it still names the plate it opens")
    }

    // MARK: - helpers

    private struct AnchorMissing: Error {}

    /// Brace-matched body after `anchor` (§2, #408).
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code.range(of: "{", range: start.lowerBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing()
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let ch = code[index]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[open.lowerBound...index]) }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing()
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }
}
