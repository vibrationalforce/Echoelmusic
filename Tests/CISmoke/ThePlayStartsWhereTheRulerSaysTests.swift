// ThePlayStartsWhereTheRulerSaysTests.swift
// Echoel — GMMW AE-7 (founder 2026-10-08: "Die klassische DAW Audio Editing View fehlt mir noch.
// Orientiere dich an den Bigplayern"). Every DAW lets you tap the ruler to say where the music
// plays from. Here the ruler's numbers took no touch and Play always started at bar 1;
// `relocate(toTick:)` existed, tested, with NO production caller.
//
// WHAT THIS PINS.
// 1. END-TO-END (`RulerLocate`, pure): which bar a tap names on the lane, and where one VoiceOver
//    step goes — bar lines only, never before the top or past the last bar, nothing for
//    degenerate geometry.
// 2. END-TO-END (`TimelineRegionPlayer.playStartTick`, pure): the bar Play really starts on is
//    `barStartTick` over the document's loop length — the ONE fold (#416) that `play`, the Play
//    hint and the ruler's line all ask.
// 3. END-TO-END (`ProjectTransport.buttonHint`): the Play hint names the bar it starts on; bar 1
//    keeps the sentences it always had; Stop and the instrument's own start ignore the bar.
// 4. END-TO-END on the real owners: stopped, `locate` only moves the cue (floored, never
//    negative, nothing starts); playing, it also moves the piece there at once; Play from the
//    cue starts on that bar; `resetCue` puts it back to the top.
// 5. SOURCE: one path each — `relocate` is called only by `locate`; `locate` only by the ruler
//    row; the ruler row reads no position; the ONE Play passes the cue, its hint and the head's
//    stopped counter the fold; Record and the WAV bounce keep bar 1; Open and New piece reset
//    the cue.
//
// Grading (§0/§3, no Swift toolchain, parent `ae3e5b1`): `RulerLocate`, `playStartTick`,
// `locate`, `resetCue`, `cueTick` and the hint's `fromTick:` do not exist there, so this file
// does not compile against the parent — every claim is a FORWARD guard, one absence (#486), and
// no assertion has a verdict there. Claims 1–3 were transcribed into Python and driven on the
// cases below against this tree; claim 5's scans were transcribed against both trees (the
// counterweights — Record's bar 1, the bounce's bar 1, `play` still the one starter — are green
// on both).
// NOT covered: that a tap lands on the bar the finger meant, that the line is visible, that a
// relocate mid-piece is click-free — a device look, registered at `ArrangeRulerLocator`.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ThePlayStartsWhereTheRulerSaysTests: XCTestCase {

    private static let bar = TimelineTime.ticksPerBar
    private static let playerPath = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"
    private static let locatorPath = "Sources/Echoelmusic/Studio/ArrangeRulerLocator.swift"
    private static let headerPath = "Sources/Echoelmusic/Studio/ProjectHeader.swift"
    private static let openPath = "Sources/Echoelmusic/Core/SessionSaveOpen.swift"
    private static let bouncePath = "Sources/Echoelmusic/Studio/PieceAudioExportTab.swift"

    // MARK: 1 — which bar a tap and a VoiceOver step name (pure)

    func testATapNamesTheBarUnderTheFinger() {
        let song = 8 * Self.bar   // 40 pt per bar on 320 pt
        XCTAssertEqual(RulerLocate.barTick(atX: 0, laneWidth: 320, songTicks: song), 0)
        XCTAssertEqual(RulerLocate.barTick(atX: 39.9, laneWidth: 320, songTicks: song), 0,
                       "anywhere inside bar 1 names bar 1")
        XCTAssertEqual(RulerLocate.barTick(atX: 40, laneWidth: 320, songTicks: song), Self.bar,
                       "the downbeat of bar 2 names bar 2")
        XCTAssertEqual(RulerLocate.barTick(atX: 319.9, laneWidth: 320, songTicks: song), 7 * Self.bar)
        XCTAssertEqual(RulerLocate.barTick(atX: 320, laneWidth: 320, songTicks: song), 7 * Self.bar,
                       "the lane's right edge is the last bar, never one past the piece")
        XCTAssertEqual(RulerLocate.barTick(atX: 1000, laneWidth: 320, songTicks: song), 7 * Self.bar)
        XCTAssertEqual(RulerLocate.barTick(atX: -5, laneWidth: 320, songTicks: song), 0,
                       "left of the lane is the top, never a negative tick")
        for x: CGFloat in [0, 13, 40, 77.5, 200, 319] {
            if let tick = RulerLocate.barTick(atX: x, laneWidth: 320, songTicks: song) {
                XCTAssertEqual(tick % Self.bar, 0, "x \(x): a tap names a bar line, the only place the transport starts")
            } else {
                XCTFail("x \(x) on a real lane named nothing")
            }
        }
    }

    func testDegenerateGeometryNamesNoBar() {
        XCTAssertNil(RulerLocate.barTick(atX: 10, laneWidth: 320, songTicks: 0))
        XCTAssertNil(RulerLocate.barTick(atX: 10, laneWidth: 320, songTicks: Self.bar - 1), "less than one bar is no bar")
        XCTAssertNil(RulerLocate.barTick(atX: 10, laneWidth: 0, songTicks: 8 * Self.bar))
        XCTAssertNil(RulerLocate.barTick(atX: 10, laneWidth: .nan, songTicks: 8 * Self.bar))
        XCTAssertNil(RulerLocate.barTick(atX: 10, laneWidth: .infinity, songTicks: 8 * Self.bar))
        XCTAssertNil(RulerLocate.barTick(atX: .nan, laneWidth: 320, songTicks: 8 * Self.bar))
    }

    func testAVoiceOverStepMovesOneBarAndStopsAtTheEdges() {
        let song = 8 * Self.bar
        XCTAssertEqual(RulerLocate.steppedBarTick(from: 0, later: true, songTicks: song), Self.bar)
        XCTAssertNil(RulerLocate.steppedBarTick(from: 0, later: false, songTicks: song), "nothing before the top")
        XCTAssertEqual(RulerLocate.steppedBarTick(from: 3 * Self.bar, later: false, songTicks: song), 2 * Self.bar)
        XCTAssertNil(RulerLocate.steppedBarTick(from: 7 * Self.bar, later: true, songTicks: song), "nothing past the last bar")
        XCTAssertEqual(RulerLocate.steppedBarTick(from: 3 * Self.bar + 100, later: true, songTicks: song), 4 * Self.bar,
                       "a mid-bar start steps from its own bar")
        XCTAssertEqual(RulerLocate.steppedBarTick(from: 20 * Self.bar, later: false, songTicks: song), 6 * Self.bar,
                       "a start past a piece that got shorter steps back from the last bar")
        XCTAssertNil(RulerLocate.steppedBarTick(from: 0, later: true, songTicks: 0))
    }

    // MARK: 2 — the ONE fold

    func testPlayStartsOnTheBarTheOneFoldNames() {
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let region = TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 8 * Self.bar)
        let document = TimelineDocument(lanes: [lane], regions: [region])
        let loop = TimelineRegionPlayer.loopTicks(for: document)
        XCTAssertEqual(loop, 8 * Self.bar, "ANCHOR: an eight-bar piece loops over eight bars")
        let cues: [Int] = [0, 77, 3 * Self.bar, 3 * Self.bar + 77, 8 * Self.bar, 9 * Self.bar + 5, -40]
        for cue in cues {
            XCTAssertEqual(TimelineRegionPlayer.playStartTick(forCue: cue, in: document),
                           TimelineRegionPlayer.barStartTick(for: cue, loopTicks: loop),
                           "cue \(cue): the start a surface names is the start `play` takes")
        }
        XCTAssertEqual(TimelineRegionPlayer.playStartTick(forCue: 3 * Self.bar + 77, in: document), 3 * Self.bar)
        XCTAssertEqual(TimelineRegionPlayer.playStartTick(forCue: 9 * Self.bar + 5, in: document), Self.bar,
                       "a cue past a piece that got shorter folds the way the loop wraps")
        XCTAssertEqual(TimelineRegionPlayer.playStartTick(forCue: 5 * Self.bar, in: TimelineDocument(lanes: [lane], regions: [])), 0,
                       "an empty piece starts at the top")
    }

    // MARK: 3 — the Play hint names the bar

    func testThePlayHintNamesTheBarItStartsOn() {
        XCTAssertEqual(ProjectTransport.buttonHint(running: false, play: .startSong, fromTick: 0),
                       "Plays the piece from the top on the shared transport.",
                       "counterweight: from bar 1 the hint is the sentence it always was")
        XCTAssertEqual(ProjectTransport.buttonHint(running: false, play: .startSong, fromTick: 2 * Self.bar),
                       "Plays the piece from bar 3 on the shared transport.")
        XCTAssertEqual(ProjectTransport.buttonHint(running: false, play: .startSongAndInstrument, fromTick: 0),
                       "Plays the piece from the top. The instrument's held music comes back with it.")
        XCTAssertEqual(ProjectTransport.buttonHint(running: false, play: .startSongAndInstrument, fromTick: 2 * Self.bar),
                       "Plays the piece from bar 3. The instrument's held music comes back with it.")
        let ticks: [Int] = [0, 5 * Self.bar]
        for tick in ticks {
            XCTAssertEqual(ProjectTransport.buttonHint(running: true, play: .startSong, fromTick: tick), ProjectTransport.stopHint,
                           "Stop is Stop wherever Play would start")
            XCTAssertEqual(ProjectTransport.buttonHint(running: false, play: .startInstrument, fromTick: tick),
                           ProjectTransport.buttonHint(running: false, play: .startInstrument, fromTick: 0),
                           "the instrument's own start has no bar")
        }
    }

    // MARK: 4 — the player, on the real owners

    private var restore: [() -> Void] = []

    override func tearDown() async throws {
        for undo in restore.reversed() { undo() }
        restore.removeAll()
    }

    /// An eight-bar MIDI part with a note on its first step, on the real `TimelineStore` and
    /// `ClipStore` (both persist, so both are restored — `TheProjectHeaderRunsOneTransportTests`).
    private func makeSong() -> (timeline: TimelineStore, clips: ClipStore) {
        let timeline = TimelineStore()
        let clips = ClipStore()
        let originalDocument = timeline.document
        let originalSlots = clips.slots
        restore.append { clips.replaceSlots(originalSlots); timeline.replaceDocument(originalDocument) }
        clips.replaceSlots([Clip?](repeating: nil, count: ClipStore.slotCount))
        let clip = Clip(name: "Keys", melody: MelodyClip(notes: [Note(pitch: 60, startStep: 0, lengthSteps: 4)]))
        clips.setClip(at: 0, clip)
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let region = TimelineRegion(laneID: lane.id, clipID: clip.id, startTick: 0, lengthTicks: 8 * Self.bar)
        timeline.replaceDocument(TimelineDocument(lanes: [lane], regions: [region]))
        return (timeline, clips)
    }

    func testStoppedTheRulerOnlyMovesWherePlayStarts() {
        let player = TimelineRegionPlayer()
        XCTAssertEqual(player.cueTick, 0, "a fresh player plays from the top")
        player.locate(toTick: 3 * Self.bar + 77)
        XCTAssertEqual(player.cueTick, 3 * Self.bar, "floored to the bar — the transport starts on bars")
        XCTAssertFalse(player.isPlaying, "a ruler tap never starts the piece")
        player.locate(toTick: -500)
        XCTAssertEqual(player.cueTick, 0, "never before the top")
        player.locate(toTick: 5 * Self.bar)
        player.resetCue()
        XCTAssertEqual(player.cueTick, 0, "a new piece plays from the top")
    }

    func testPlayingTheRulerMovesThePieceAndPlayStartsThere() {
        let song = makeSong()
        let player = TimelineRegionPlayer()
        // The app's wiring, as `TheProjectHeaderRunsOneTransportTests` reproduces it.
        let pattern = PatternEngine()
        let transport = Transport()
        pattern.transport = transport
        transport.addStopSubscriber("timeline") { [weak player] in player?.handleTransportStopped() }
        restore.append { player.stop(); pattern.stop() }
        XCTAssertTrue(WorkstationView.songCanStart(player: player, timeline: song.timeline, clipStore: song.clips),
                      "ANCHOR: the fixture piece must be playable, or nothing below says anything")
        WorkstationView.startSong(player: player, timeline: song.timeline, clipStore: song.clips,
                                  pattern: pattern, pianoRoll: PianoRollModel(),
                                  fromTick: player.cueTick, launching: [])
        XCTAssertTrue(player.isPlaying, "ANCHOR: the piece runs")
        XCTAssertEqual(player.startedFromTick, 0)

        player.locate(toTick: 5 * Self.bar + 300)
        XCTAssertTrue(player.isPlaying, "a locate is not a stop")
        XCTAssertEqual(player.cueTick, 5 * Self.bar)
        XCTAssertGreaterThanOrEqual(player.currentTick, 5 * Self.bar, "the piece moved to bar 6 at once")
        XCTAssertLessThan(player.currentTick, 6 * Self.bar,
                          "…at the pattern's own phase inside that bar (`relocateAnchorTick`), never past it")

        ProjectTransport.stop(song: player, pattern: pattern, source: "test")
        XCTAssertFalse(player.isPlaying)
        XCTAssertEqual(player.cueTick, 5 * Self.bar, "a Stop keeps where the ruler said")
        WorkstationView.startSong(player: player, timeline: song.timeline, clipStore: song.clips,
                                  pattern: pattern, pianoRoll: PianoRollModel(),
                                  fromTick: player.cueTick, launching: [])
        XCTAssertEqual(player.startedFromTick, 5 * Self.bar, "Play from the cue starts on that bar")
    }

    // MARK: 5 — one path each (source)

    func testRelocateHasOneCallerAndLocateHasOneDoor() throws {
        var relocateSites: [String] = []
        var locateSites: [String] = []
        for (path, code) in try sources() {
            // The declaration spells `relocate(toTick tick:`, so this needle counts CALLS only.
            let relocates = code.components(separatedBy: "relocate(toTick:").count - 1
            if relocates > 0 { relocateSites.append("\(path) ×\(relocates)") }
            let locates = code.components(separatedBy: ".locate(toTick:").count - 1
            if locates > 0 { locateSites.append("\(path) ×\(locates)") }
        }
        XCTAssertEqual(relocateSites, ["Sequencer/TimelineRegionPlayer.swift ×1"], """
            `relocate(toTick:)` is called from \(relocateSites). Its ONE production caller is \
            `locate`, so the cue and the position can never name two different bars. A second door \
            goes through `locate`. NEVER per drag frame (HARNESS_LEDGER 2026-07-16).
            """)
        let player = try source(Self.playerPath)
        guard let locate = bracedBody(after: "public func locate(toTick tick: Int) {", in: player) else {
            return XCTFail("ANCHOR MISSING: `locate(toTick:)` in TimelineRegionPlayer (#454)")
        }
        XCTAssertTrue(locate.contains("if isPlaying { relocate(toTick: bar) }"), "the relocate is inside `locate`, playing only")
        XCTAssertTrue(locate.contains("let bar = (max(0, tick) / TimelineTime.ticksPerBar) * TimelineTime.ticksPerBar"),
                      "the cue is floored to the bar and never negative")
        XCTAssertEqual(locateSites, ["Studio/ArrangeRulerLocator.swift ×2"], """
            `locate(toTick:)` is called from \(locateSites). Its doors are the ruler row's tap and \
            its VoiceOver step — both in `ArrangeRulerLocator`.
            """)
        let writes = player.components(separatedBy: "cueTick = ").count - 1
            - player.components(separatedBy: "var cueTick = ").count + 1
        XCTAssertEqual(writes, 2, "the cue's writers are `locate` and `resetCue` (the declaration aside)")
        XCTAssertTrue(player.contains("let startTick = Self.playStartTick(forCue: fromTick, in: document)"),
                      "`play` folds through the one fold the surfaces ask")
        guard let fold = bracedBody(after: "nonisolated static func playStartTick(forCue tick: Int, in document: TimelineDocument) -> Int {",
                                    in: player) else {
            return XCTFail("ANCHOR MISSING: `playStartTick` (#454)")
        }
        XCTAssertTrue(fold.contains("barStartTick(for: tick, loopTicks: loopTicks(for: document))"),
                      "the fold is `barStartTick` over the document's loop length")
    }

    func testTheRulerRowReadsNoPositionAndHasANonGestureTwin() throws {
        let locator = try source(Self.locatorPath)
        guard let row = bracedBody(after: "struct ArrangeRulerLocator: View {", in: locator) else {
            return XCTFail("ANCHOR MISSING: `ArrangeRulerLocator` (#454)")
        }
        for banned in ["currentTick", "relocate", "player.play(", "player.stop(", "DragGesture",
                       "TimelineView(", "@State", "@GestureState"] {
            XCTAssertFalse(row.contains(banned), """
                `ArrangeRulerLocator` contains `\(banned)`. It reads the cue (cold: a tap) and \
                nothing hot — a position read here makes the canvas an 8 Hz reader (10.76.41/50); \
                a drag would be a relocate storm.
                """)
        }
        XCTAssertTrue(row.contains("TimelineRegionPlayer.playStartTick(forCue: player.cueTick, in: document)"),
                      "the line marks the bar Play takes — the one fold")
        XCTAssertEqual(row.components(separatedBy: ".onTapGesture(coordinateSpace: .local)").count - 1, 1, "one tap")
        XCTAssertTrue(row.contains("RulerLocate.barTick(atX: location.x, laneWidth: width,"), "the tap asks the pure rule")
        XCTAssertTrue(row.contains(".accessibilityElement(children: .ignore)"), "ONE VoiceOver element, not a list of numbers")
        XCTAssertTrue(row.contains(".accessibilityAdjustableAction"), "the non-gesture twin: a swipe moves a bar")
        XCTAssertTrue(row.contains("RulerLocate.steppedBarTick(from: start, later: later,"), "the step asks the pure rule")
        XCTAssertTrue(row.contains(".accessibilityValue(SessionGrid.label(forTick: start))"),
                      "VoiceOver hears the bar in the words every part speaks")
    }

    func testTheOnePlayPassesTheCueAndRecordAndTheBounceKeepBarOne() throws {
        let header = try source(Self.headerPath)
        guard let headStart = header.range(of: "struct ProjectHeader: View {"),
              let buttonStart = header.range(of: "struct ProjectPlayStopButton: View {",
                                             range: headStart.upperBound..<header.endIndex),
              let buttonEnd = header.range(of: "private struct ProjectTempoReadout: View {",
                                           range: buttonStart.upperBound..<header.endIndex) else {
            return XCTFail("ANCHOR MISSING: ProjectHeader → ProjectPlayStopButton → ProjectTempoReadout (#454)")
        }
        let head = String(header[headStart.upperBound..<buttonStart.lowerBound])
        let button = String(header[buttonStart.upperBound..<buttonEnd.lowerBound])
        XCTAssertEqual(button.components(separatedBy: "fromTick: player.cueTick, launching: [])").count - 1, 1,
                       "the ONE Play starts where the ruler said")
        XCTAssertFalse(button.contains("fromTick: 0, launching: [])"), "…and nowhere else")
        XCTAssertTrue(button.contains("fromTick: TimelineRegionPlayer.playStartTick("),
                      "its hint names the bar the fold names, not the bar that was tapped")
        XCTAssertEqual(header.components(separatedBy: "let stoppedAt = TimelineRegionPlayer.playStartTick(forCue: player.cueTick, in: timeline.document)").count - 1, 1,
                       "stopped, the head's counter shows where the ONE Play will start — the same fold")
        XCTAssertTrue(head.contains("fromTick: 0, launching: [])"),
                      "counterweight: the header's Record start stays at bar 1 — its words say \"from bar 1\"")
        XCTAssertFalse(head.contains("player.cueTick"), "Record does not read the cue")
        let bounce = try source(Self.bouncePath)
        XCTAssertTrue(bounce.contains("fromTick: 0, launching: [])"), "counterweight: the WAV bounce plays the piece from bar 1")
        XCTAssertFalse(bounce.contains("cueTick"))
    }

    func testANewPieceForgetsTheOldCue() throws {
        let open = try source(Self.openPath)
        let reset = "        timeline.replaceDocument(song.document)\n        player.resetCue()"
        XCTAssertEqual(open.components(separatedBy: reset).count - 1, 2,
                       "Open and New piece both reset the cue right after the piece is replaced")
        XCTAssertEqual(open.components(separatedBy: "player.resetCue()").count - 1, 2)
    }

    // MARK: helpers

    private func root() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("source tree not present")
    }

    private func source(_ relativePath: String) throws -> String {
        let url = try root().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("ANCHOR MISSING: \(relativePath) is gone while the tree is present (#454)")
            return ""
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    /// Every Swift file under `Sources/Echoelmusic`, comment-stripped, keyed by its path below it.
    private func sources() throws -> [(String, String)] {
        let base = try root().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            throw XCTSkip("cannot walk Sources/Echoelmusic (#454)")
        }
        var out: [(String, String)] = []
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            let text = (try? String(contentsOf: base.appendingPathComponent(rel), encoding: .utf8)) ?? ""
            out.append((rel, SourceText.codeOnly(text)))
        }
        XCTAssertGreaterThan(out.count, 250, "the walk saw too few files to mean anything (#454)")
        return out.sorted { $0.0 < $1.0 }
    }

    /// The text between `head` (which ends in `{`) and its matching `}`.
    private func bracedBody(after head: String, in text: String) -> String? {
        guard head.hasSuffix("{"), let start = text.range(of: head) else { return nil }
        var depth = 1
        var index = start.upperBound
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[start.upperBound..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        return nil
    }
}
