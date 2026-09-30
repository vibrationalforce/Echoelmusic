// TheProjectHeaderRunsOneTransportTests.swift
// DMMW Phase 1 · slice 3 (founder 2026-09-29): "Nimm als nächste Scheibe den durchgehenden
// Projektkopf mit globalem Transport … Compose, Perform und später Visuals müssen dasselbe
// kanonische Projekt bedienen." Tests asked for: Play/Stop from the global transport, a visible
// status change, the global Stop, identical project/clip state in Compose and Perform.
//
// WHAT KIND OF GREEN THIS IS (Tests/CISmoke/CLAUDE.md §1), per claim:
// · 1–5 END-TO-END BEHAVIOUR on the shipped pure rules (`ProjectTransport`) and the real owners
//   (`TimelineRegionPlayer`, `PatternEngine`, `Transport`, `TimelineStore`, `ClipStore`,
//   `ProjectStore`) — the strong kind. The song is started through the Workstation's ONE start
//   (`WorkstationView.startSong`), the same function the header calls.
// · 6–9 SOURCE-TEXT SCANS — where the header is mounted, what it may not construct or present,
//   that its hot read is confined to its own leaf, and that the Workstation's Play/Stop reads
//   the same running truth. They prove where text sits, not that the app renders it.
// · 10 (interface audit 2026-09-30, "ein Kopf, der spricht") MIXED, labelled per assertion:
//   END-TO-END on `ProjectTransport.buttonWord` against `buttonLabel` (the drawn word is the
//   spoken label's first word, for every state), then SOURCE-TEXT that the header's ONE
//   Play/Stop mounts that word beside its glyph and that the compact Record beside it stays a
//   glyph (two "Stop"s with two effects would be the `OneStartControlTests` confusion).
// · DEVICE PROBE, OPEN (NEEDS-FOUNDER-VERIFY): that the header renders legibly at the largest
//   text size, that VoiceOver speaks the status change, and that Stop is heard to stop — and,
//   since claim 10, that the worded button and the compact Record still share one row at the
//   default size on an iPhone (375 pt) without the summary collapsing to its ellipsis.
//
// HONEST GRADING of claim 10 (§3), against its parent (`4fa757884`): `buttonWord` does not exist
// there, so the file does not compile against the parent and no assertion has a verdict; by
// transcription, the behaviour half and the mount needle are FORWARD (they name the new symbol),
// the glyph needle and the compact-Record needle are COUNTERWEIGHTS (green on both trees), and
// the `.padding(.horizontal, 12)` needle is red on the parent by the same one absence.
//
// HONEST GRADING (§3), against the parent tree (`811fdddeb`): the file does NOT compile there —
// it names `ProjectTransport`, `WorkstationView.startSong`/`songCanStart(player:…)` and
// `ProjectStore.currentProjectName`, all created by this commit — so no assertion has a verdict
// on the parent. Graded by transcription instead: claims 1–5 are FORWARD guards (they drive
// symbols this commit creates); 6–9 are REGRESSION scans for the mount/no-modal/no-store/
// hot-read laws, of which the no-store and no-modal halves are COUNTERWEIGHTS (they would have
// held for any header) and the mount, the one-Stop wiring and the shared running truth are red
// on the parent by ANCHOR ABSENCE (one absence: the header does not exist there, #486).

import Foundation
import XCTest
@testable import Echoelmusic

#if canImport(SwiftUI)
@MainActor
final class TheProjectHeaderRunsOneTransportTests: XCTestCase {

    private static let header = "Sources/Echoelmusic/Studio/ProjectHeader.swift"
    private static let model = "Sources/Echoelmusic/Studio/ProjectTransport.swift"
    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    // MARK: 1 — the status is derived from the owners' own flags

    private func facts(clock: Bool = false, song: Bool = false, recording: Bool = false,
                       session: Bool = false, startable: Bool = false) -> ProjectTransport.Facts {
        ProjectTransport.Facts(clockRunning: clock, songPlaying: song, recording: recording,
                               sessionRunning: session, songStartable: startable)
    }

    func testTheStatusSaysWhatRunsInTheOrderTheUserMustKnowIt() {
        XCTAssertEqual(ProjectTransport.status(facts()), .stopped)
        XCTAssertEqual(ProjectTransport.status(facts(session: true)), .paused,
                       "a held bio session with the music stopped is paused, not stopped")
        XCTAssertEqual(ProjectTransport.status(facts(clock: true, session: true)), .playingInstrument)
        XCTAssertEqual(ProjectTransport.status(facts(clock: true, song: true)), .playingSong,
                       "the song outranks the instrument on the same clock")
        XCTAssertEqual(ProjectTransport.status(facts(clock: true, song: true, recording: true)), .recording,
                       "a running take outranks everything")
        let words = [ProjectTransport.Status.stopped, .paused, .playingInstrument, .playingSong, .recording]
            .map(ProjectTransport.statusWord)
        XCTAssertEqual(Set(words).count, words.count, "every status reads differently on screen")
        XCTAssertFalse(ProjectTransport.isRunning(facts(session: true)), "a paused session is not running")
        XCTAssertTrue(ProjectTransport.isRunning(facts(clock: true)))
        XCTAssertTrue(ProjectTransport.isRunning(facts(song: true)))
        XCTAssertTrue(ProjectTransport.isRunning(facts(recording: true)))
    }

    func testPlayMeansTheSongFirstThenAHeldSession() {
        XCTAssertEqual(ProjectTransport.playAction(facts(startable: true)), .startSong,
                       "the canonical project is the arrangement")
        // Review of 09d35f56e, MED-1: during a held session the song's start also brings the
        // instrument's music back (the ONE-Stop observer reads a clock start as `.resume`), so
        // the SAME start gets its own words — never "Play the song" over a tap that plays two.
        XCTAssertEqual(ProjectTransport.playAction(facts(session: true, startable: true)), .startSongAndInstrument,
                       "the canonical project is still the arrangement — the session only changes the words")
        XCTAssertEqual(ProjectTransport.buttonLabel(running: false, play: .startSongAndInstrument),
                       "Play the song and the instrument")
        XCTAssertTrue(ProjectTransport.buttonHint(running: false, play: .startSongAndInstrument)
                        .contains("music comes back"), "the hint says the held music returns with the song")
        // MED-2: the one Stop ends the pulse session, and its hint says so on EVERY surface.
        XCTAssertTrue(ProjectTransport.stopHint.contains("pulse session ends"))
        XCTAssertEqual(ProjectTransport.buttonHint(running: true, play: .startSong), ProjectTransport.stopHint)
        XCTAssertEqual(WorkstationSummary.transportHint(playing: true, startable: true), ProjectTransport.stopHint,
                       "the Workstation's Stop is the same Stop, so it reads the same")
        XCTAssertEqual(ProjectTransport.playAction(facts(session: true)), .resumeInstrument)
        XCTAssertEqual(ProjectTransport.playAction(facts()), .unavailable)
        XCTAssertEqual(ProjectTransport.buttonLabel(running: true, play: .startSong), "Stop all playback",
                       "while anything runs the one button is Stop — for everything")
        XCTAssertEqual(ProjectTransport.buttonLabel(running: false, play: .startSong), "Play the song")
        XCTAssertTrue(ProjectTransport.buttonHint(running: false, play: .unavailable).hasPrefix("Unavailable:"),
                      "a dimmed control says what is missing")
    }

    func testStopPicksTheRoadThatEndsEverything() {
        XCTAssertEqual(ProjectTransport.stopAction(songPlaying: true, clockRunning: true), .song)
        XCTAssertEqual(ProjectTransport.stopAction(songPlaying: false, clockRunning: true), .clock)
        XCTAssertEqual(ProjectTransport.stopAction(songPlaying: false, clockRunning: false), .nothing)
    }

    // MARK: 2 — Play and the global Stop, on the real owners

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
    }

    /// One MIDI track with one one-bar part holding a note, on the real `TimelineStore` and
    /// `ClipStore` (both persist, so both are restored — the `ANewMIDIPartOpensTheNoteEditorTests`
    /// idiom).
    private func makeSong() -> (timeline: TimelineStore, clips: ClipStore, lane: TimelineLane,
                                region: TimelineRegion) {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        restore.append { clips.replaceSlots(originalSlots); timeline.replaceDocument(originalDocument) }
        clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount))
        let clip = Clip(name: "Keys", melody: MelodyClip(notes: [Note(pitch: 60, startStep: 0, lengthSteps: 4)]))
        clips.setClip(at: 0, clip)
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let region = TimelineRegion(laneID: lane.id, clipID: clip.id,
                                    startTick: 2 * TimelineTime.ticksPerBar,
                                    lengthTicks: TimelineTime.ticksPerBar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [region]))
        return (timeline, clips, lane, region)
    }

    /// The app's wiring, reproduced: the pattern relays into the transport, and the transport's
    /// stop reaches the song through the same subscriber id the app registers.
    private func makeClock(player: TimelineRegionPlayer) -> (PatternEngine, Transport) {
        let pattern = PatternEngine()
        let transport = Transport()
        pattern.transport = transport
        transport.addStopSubscriber("timeline") { [weak player] in player?.handleTransportStopped() }
        restore.append { player.stop(); pattern.stop() }
        return (pattern, transport)
    }

    private func liveFacts(_ transport: Transport, _ player: TimelineRegionPlayer,
                           startable: Bool) -> ProjectTransport.Facts {
        facts(clock: transport.isPlaying, song: player.isPlaying, startable: startable)
    }

    func testTheHeadersPlayStartsTheSongAndItsStopEndsEverything() {
        let song = makeSong()
        let player = TimelineRegionPlayer()
        let (pattern, transport) = makeClock(player: player)
        let startable = WorkstationView.songCanStart(player: player, timeline: song.timeline,
                                                     clipStore: song.clips)
        XCTAssertTrue(startable, "ANCHOR: the fixture song must be playable, or nothing below says anything")
        XCTAssertEqual(ProjectTransport.playAction(liveFacts(transport, player, startable: startable)), .startSong)
        XCTAssertEqual(ProjectTransport.status(liveFacts(transport, player, startable: startable)), .stopped)

        WorkstationView.startSong(player: player, timeline: song.timeline, clipStore: song.clips,
                                  pattern: pattern, pianoRoll: PianoRollModel(),
                                  fromTick: 0, launching: [])
        XCTAssertTrue(player.isPlaying, "the song runs")
        XCTAssertTrue(transport.isPlaying, "on the ONE clock — the pattern relayed into the transport")
        let playing = ProjectTransport.status(liveFacts(transport, player, startable: startable))
        XCTAssertEqual(playing, .playingSong, "the header's status flips on Play")

        ProjectTransport.stop(song: player, pattern: pattern, source: "test")
        XCTAssertFalse(player.isPlaying)
        XCTAssertFalse(pattern.isPlaying)
        XCTAssertFalse(transport.isPlaying, "the global Stop reaches the clock every surface reads")
        let stopped = ProjectTransport.status(liveFacts(transport, player, startable: startable))
        XCTAssertEqual(stopped, .stopped, "and the status flips back")
        XCTAssertNotEqual(ProjectTransport.statusWord(playing), ProjectTransport.statusWord(stopped),
                          "the change is visible, not only internal")

        // Review of 09d35f56e, MED-5: the Workstation's caption names the bar the PLAYER started
        // from, so a header start (always from the top) after a start at the part's bar reads
        // "from the top" — never the older take's bar.
        let bar = TimelineTime.ticksPerBar
        WorkstationView.startSong(player: player, timeline: song.timeline, clipStore: song.clips,
                                  pattern: pattern, pianoRoll: PianoRollModel(),
                                  fromTick: song.region.startTick, launching: [])
        XCTAssertEqual(player.startedFromTick, 2 * bar, "a start at the part records the part's bar")
        XCTAssertEqual(WorkstationSummary.transportCaption(playing: true, startable: true,
                                                           fromTick: player.startedFromTick),
                       "Playing from bar 3 on the shared transport.")
        ProjectTransport.stop(song: player, pattern: pattern, source: "test")
        WorkstationView.startSong(player: player, timeline: song.timeline, clipStore: song.clips,
                                  pattern: pattern, pianoRoll: PianoRollModel(),
                                  fromTick: 0, launching: [])
        XCTAssertEqual(player.startedFromTick, 0, "the header's start from the top is recorded too")
        XCTAssertEqual(WorkstationSummary.transportCaption(playing: true, startable: true,
                                                           fromTick: player.startedFromTick),
                       "Playing from the top on the shared transport.")
        ProjectTransport.stop(song: player, pattern: pattern, source: "test")
    }

    func testTheGlobalStopEndsTheInstrumentsClockAndAClockStopEndsTheSong() {
        let player = TimelineRegionPlayer()
        let (pattern, transport) = makeClock(player: player)
        // The instrument's music alone — the call the instrument's own ▶ makes.
        ProjectTransport.resumeInstrument(pattern: pattern)
        XCTAssertTrue(transport.isPlaying)
        XCTAssertEqual(ProjectTransport.status(liveFacts(transport, player, startable: false)),
                       .playingInstrument)
        XCTAssertEqual(ProjectTransport.stopAction(songPlaying: player.isPlaying,
                                                   clockRunning: pattern.isPlaying), .clock)
        ProjectTransport.stop(song: player, pattern: pattern, source: "test")
        XCTAssertFalse(transport.isPlaying, "the global Stop ends the instrument's music too")

        // Counterweight (#343): a Stop that reaches ONLY the clock still ends the song, through the
        // stop subscriber the app registers — which is why `.clock` is a complete Stop.
        let song = makeSong()
        WorkstationView.startSong(player: player, timeline: song.timeline, clipStore: song.clips,
                                  pattern: pattern, pianoRoll: PianoRollModel(),
                                  fromTick: 0, launching: [])
        XCTAssertTrue(player.isPlaying, "ANCHOR: the song must be running for the claim below")
        pattern.stop()
        XCTAssertFalse(player.isPlaying, "a clock-only stop resets the song's follow-state")
    }

    // MARK: 3 — one project: the name and the place come from the one owner each

    func testTheHeaderNeverInventsAName() throws {
        XCTAssertEqual(ProjectTransport.projectName(nil), ProjectTransport.unsavedName)
        XCTAssertEqual(ProjectTransport.projectName("  "), ProjectTransport.unsavedName)
        XCTAssertEqual(ProjectTransport.projectName("Night drive"), "Night drive")

        let store = ProjectStore(store: AppGroupStore(subdirectory: "Header-\(UUID().uuidString)"),
                                 writeProjects: { _ in true })
        XCTAssertNil(store.currentProjectName, "a fresh run has no named project")
        var project = Project(
            name: "Night drive", styleRaw: "ambient", keyRoot: 0,
            scaleRaw: "major", bpm: 96, modeRaw: "flowFree",
            fxCharacterRaw: "warm", loopBars: 4, a4Hz: 440,
            toneSystemID: nil, moodFields: nil, artist: "",
            patch: SynthPatch(name: "Default"), notes: [], rawTake: nil,
            drumSteps: [], drumAccents: [])
        store.save(project)
        XCTAssertEqual(store.currentProjectName, "Night drive", "Save names the header")
        project.id = Project.autosaveSlotID
        project.name = "Recovery"
        store.save(project)
        XCTAssertEqual(store.currentProjectName, "Night drive",
                       "the recovery slot is not the project the user named")

        // Review of 09d35f56e, MED-4: an ARRIVAL (a file import, a Live Colabo peer's Save) only
        // adds a row — the working take is unchanged, so the header keeps its name.
        var arriving = project
        arriving.id = UUID()
        arriving.name = "Peer take"
        let adopted = store.adoptArriving(arriving)
        XCTAssertNotNil(store.project(id: adopted.id), "premise: the arrival IS in the library")
        XCTAssertEqual(store.currentProjectName, "Night drive",
                       "an arrival is not the project the player works on")
        // Review LOW: deleting the named row takes the name back; deleting another row does not.
        store.delete(id: adopted.id)
        XCTAssertEqual(store.currentProjectName, "Night drive", "another row's delete keeps the name")
        let named = try XCTUnwrap(store.projects.first { $0.name == "Night drive" })
        store.delete(id: named.id)
        XCTAssertNil(store.currentProjectName, "the header never names a project the library no longer has")

        let studio = try source(Self.studio)
        let open = try body(of: "private func open(_ p: Project)", in: studio)
        XCTAssertTrue(open.contains("projects.noteCurrent(p)"), "Open names the header too")
    }

    func testThePlaceIsReadFromTheSameDocumentEveryAreaReads() {
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let region = TimelineRegion(laneID: lane.id, clipID: UUID(),
                                    startTick: 2 * TimelineTime.ticksPerBar,
                                    lengthTicks: TimelineTime.ticksPerBar)
        let document = TimelineDocument(lanes: [lane], regions: [region])
        XCTAssertEqual(ProjectTransport.place(document: document, trackID: nil, regionID: nil),
                       "No track selected")
        XCTAssertEqual(ProjectTransport.place(document: document, trackID: lane.id, regionID: nil), "Keys")
        XCTAssertEqual(ProjectTransport.place(document: document, trackID: lane.id, regionID: region.id),
                       "Keys · part at bar 3")
        XCTAssertEqual(ProjectTransport.place(document: document, trackID: UUID(), regionID: region.id),
                       "No track selected", "a deleted track never shows a stale name")
    }

    // MARK: 4 — SCANS: mount, one Stop, no second project, no hot read, no modal

    func testTheHeaderIsMountedOnceAboveEveryArea() throws {
        let workspace = try source(Self.workspace)
        XCTAssertEqual(workspace.components(separatedBy: "ProjectHeader()").count - 1, 1,
                       "one project header")
        guard let strip = workspace.range(of: "CompositionHeaderStrip()\n"),
              let header = workspace.range(of: "ProjectHeader()", range: strip.upperBound..<workspace.endIndex),
              let clamp = workspace.range(of: ".dynamicTypeSize(...DynamicTypeSize.accessibility1)",
                                          range: header.upperBound..<workspace.endIndex),
              workspace.range(of: "SurfaceHost()", range: clamp.upperBound..<workspace.endIndex) != nil else {
            return XCTFail("the header must sit in the chrome group (under its one Dynamic Type clamp), above `SurfaceHost()` — every area")
        }
        let header2 = try source(Self.header)
        XCTAssertFalse(header2.contains(".dynamicTypeSize("), "the header inherits the chrome's ONE clamp")
        XCTAssertFalse(header2.contains("minimumScaleFactor"), "large text grows the header, it does not shrink the text")
        XCTAssertTrue(header2.contains(".fixedSize(horizontal: false, vertical: true)\n        .frame(minHeight: 44)"),
                      "the bar grows with its text and never splits the screen with the area below")
        XCTAssertTrue(header2.contains(".frame(minWidth: 44, minHeight: 44)"), "a 44 pt Play/Stop target")
        XCTAssertTrue(header2.contains("compact: true)"), "the header mounts the existing Record door, compact")
        XCTAssertTrue(header2.contains("AccessibilityNotification.Announcement(ProjectTransport.statusWord(new)).post()"),
                      "a status change is spoken")
        XCTAssertTrue(header2.contains(".accessibilityLabel(ProjectTransport.buttonLabel(running: running, play: play))"))
    }

    // MARK: 10 — the ONE Play / Stop wears its word (interface audit 2026-09-30)

    func testThePlayStopWearsTheFirstWordOfItsSpokenLabel() throws {
        // END-TO-END: the drawn word is the spoken label's first word, in every state — so the
        // two can never disagree, and neither is a second copy of the other (#416).
        let plays: [ProjectTransport.PlayAction] = [.startSong, .startSongAndInstrument,
                                                    .resumeInstrument, .unavailable]
        for running in [true, false] {
            let word = ProjectTransport.buttonWord(running: running)
            XCTAssertFalse(word.contains(" "), "one word, not a sentence: \"\(word)\"")
            XCTAssertEqual(word, running ? "Stop" : "Play")
            for play in plays {
                let label = ProjectTransport.buttonLabel(running: running, play: play)
                XCTAssertTrue(label.hasPrefix(word + " ") || label == word, """
                running=\(running) play=\(play): the button draws "\(word)" but VoiceOver says \
                "\(label)" — the drawn word must be the spoken label's first word.
                """)
            }
        }
        // SOURCE-TEXT: the header's one button mounts the word beside the glyph it always had.
        let header = try source(Self.header)
        let button = try body(of: "private func playStopButton(running: Bool, play: ProjectTransport.PlayAction) -> some View",
                              in: header)
        XCTAssertTrue(button.contains("Image(systemName: running ? \"stop.fill\" : \"play.fill\")"),
                      "the glyph stays — the word joins it, it does not replace it")
        XCTAssertTrue(button.contains("Text(ProjectTransport.buttonWord(running: running))"),
                      "the ONE Play/Stop wears its word (interface audit 2026-09-30)")
        XCTAssertTrue(button.contains(".padding(.horizontal, 12)"),
                      "a worded button is no longer a 44 pt square; it needs side room before the 44 pt floor")
        // SOURCE-TEXT: the compact Record beside it stays a glyph — "Stop" twice on one row with
        // two effects is the confusion `OneStartControlTests` names.
        let record = try source("Sources/Echoelmusic/Studio/RecordTakeControls.swift")
        guard let gate = record.range(of: "if !compact {"),
              let recordWord = record.range(of: "Text(recording ? \"Stop recording\" : \"Record\")",
                                            range: gate.upperBound..<record.endIndex) else {
            return XCTFail("ANCHOR MISSING: the compact Record's word is no longer behind `if !compact {` (#454)")
        }
        XCTAssertLessThan(record.distance(from: gate.upperBound, to: recordWord.lowerBound), 120,
                          "the Record's word must sit directly under its `!compact` gate, so the header's compact Record stays glyph-only")
    }

    func testThereIsOneStartOneStopAndNoSecondProject() throws {
        let header = try source(Self.header)
        let model = try source(Self.model)
        for text in [header, model] {
            for constructed in ["TimelineStore(", "ClipStore(", "ProjectStore(", "TimelineRegionPlayer(",
                                "PatternEngine(", "Transport(", "WorkstationSelection(", "RecordController("] {
                XCTAssertFalse(text.contains(constructed), "the header constructs `\(constructed)` — a second owner")
            }
            for modal in [".sheet(", ".fullScreenCover(", ".alert(", ".popover(", ".confirmationDialog("] {
                XCTAssertFalse(text.contains(modal), "no new modal (the black-screen law): `\(modal)`")
            }
            XCTAssertFalse(text.contains("player.play("), "only the Workstation starts the song")
            XCTAssertFalse(text.contains("canPlay("), "only the Workstation asks the engine")
            for clock in ["Timer", "DispatchSourceTimer", "CADisplayLink", "Task.sleep", "asyncAfter"] {
                XCTAssertFalse(text.contains(clock), "no second clock: `\(clock)`")
            }
        }
        XCTAssertTrue(header.contains("WorkstationView.startSong(player: player, timeline: timeline, clipStore: clipStore,"),
                      "the header's Play is the Workstation's one start")
        XCTAssertTrue(header.contains("ProjectTransport.stop(song: player, pattern: beatPlayer.pattern, source: \"project header\")"))
        XCTAssertTrue(header.contains("case .startSong, .startSongAndInstrument: startSong()"),
                      "both song cases take the ONE song start — the second case only changes the words")

        let workstation = try source(Self.workstation)
        XCTAssertTrue(workstation.contains("ProjectTransport.stop(song: player, pattern: beatPlayer.pattern, source: \"workstation\")"),
                      "the Workstation's Stop is the same one Stop")
        XCTAssertTrue(workstation.contains("let running = ProjectTransport.isRunning(clockRunning: transport.isPlaying, songPlaying: playing)"),
                      "and its Play/Stop shows the same running truth as the header")
        XCTAssertEqual(workstation.components(separatedBy: "player.play(").count - 1, 1,
                       "still ONE `player.play(` in the app's one start file")

        // One construction of each owner, in the app — every area reads them from the environment.
        let app = try source(Self.app)
        for owner in ["TimelineStore()", "ClipStore()", "ProjectStore()", "TimelineRegionPlayer()",
                      "WorkstationSelection()"] {
            XCTAssertEqual(app.components(separatedBy: owner).count - 1, 1, "one `\(owner)`")
        }
        for (path, reads) in [(Self.workstation, ["@Environment(TimelineStore.self)", "@Environment(ClipStore.self)"]),
                              (Self.studio, ["@Environment(TimelineStore.self)", "@Environment(ClipStore.self)"]),
                              (Self.header, ["@Environment(TimelineStore.self)", "@Environment(ClipStore.self)",
                                             "@Environment(ProjectStore.self)"])] {
            let text = try source(path)
            for read in reads { XCTAssertTrue(text.contains(read), "\(path) must read `\(read)`, not own a copy") }
        }
    }

    func testTheTempoIsReadOnlyInItsOwnLeaf() throws {
        let header = try source(Self.header)
        guard let leaf = header.range(of: "private struct ProjectTempoReadout: View {") else {
            return XCTFail("ANCHOR MISSING: the tempo leaf")
        }
        XCTAssertFalse(header[..<leaf.lowerBound].contains(".tempo"),
                       "the gliding tempo is read in the header's body — it would rebuild the root chrome at ~20 Hz")
        XCTAssertTrue(header[leaf.upperBound...].contains("beatPlayer.pattern.tempo"),
                      "counterweight: the leaf does read it, or the BPM would not be shown")
        XCTAssertTrue(header[leaf.upperBound...].contains("tempo.isFinite ? Int(tempo.rounded()) : 0"),
                      "a non-finite tempo cannot trap the header")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// The brace-matched body that follows `head`.
    private func body(of head: String, in code: String) throws -> String {
        guard let start = code.range(of: head),
              let open = code.range(of: "{", range: start.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: `\(head)` (#454)")
            throw AnchorMissing(name: head)
        }
        var depth = 0
        var index = open.lowerBound
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(code[open.lowerBound...index]) } }
            index = code.index(after: index)
        }
        XCTFail("ANCHOR MISSING: unbalanced `\(head)`")
        throw AnchorMissing(name: head)
    }
}
#endif
