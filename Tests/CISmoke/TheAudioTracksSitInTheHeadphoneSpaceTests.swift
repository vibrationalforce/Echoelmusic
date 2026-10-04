//
//  TheAudioTracksSitInTheHeadphoneSpaceTests.swift
//  Restructure S3c (founder 2026-10-04, wörtlich: „Bereite S3 als hörbaren binauralen
//  Kopfhörer-Ausgang vor. Abnahme ist eine reproduzierbar hörbare Raumposition samt
//  Wiederherstellung im Stück. Vorhandene Renderer-Kerne oder gesendete ADM-OSC-Daten allein
//  schließen diese Aufgabe nicht.")
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claim 5's first half) — the persisted default is OFF, read from the
//    shipped `StudioDefaultKeys` value.
//  · SOURCE-TEXT SCAN (claims 1–6) — `AudioEngine` and `TimelineAudioSink` need a live
//    AVAudioEngine graph and `PieceMixerView` is a `View`; the guard pins where the rendering,
//    the mode read, the placement and the door sit.
//  · DEVICE PROBE, OPEN — that a track is HEARD at its place on headphones, and that reopening
//    the piece puts it back there. That is the acceptance the founder named; nothing here can
//    hear. It is asked as G6 in `docs/dev/FOUNDER_INBOX.md`.
//
//  GRADING against the parent tree (#433/#464): the parent has no `attachSpaceBus`, no
//  `headphoneSpaceEnabled`, no `StudioDefaultKeys.headphoneSpace` — claim 5's runtime half does
//  not compile there, so no assertion has a verdict on the parent. Every claim is a FORWARD
//  guard, transcribed in Python against the worktree before push; the needles of claims 1–4 and
//  6 are absent on the parent (ONE absence, #486).
//  COUNTERWEIGHTS (#343): claim 6 — with the switch off, both attach paths still reach the
//  ordinary `attachPlayerNode` overloads, so every piece plays exactly as before S3c; claim 7's
//  tail — a refused space attach falls back to those same overloads.
//  Claim 7 (review repair) is a FORWARD guard: `mayRewire`, `parkedSinceStop` and `inSpace` are
//  created by the repair commit and are absent on `5cf8d02fe`.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheAudioTracksSitInTheHeadphoneSpaceTests: XCTestCase {

    private static let engine = "Sources/Echoelmusic/Audio/AudioEngine.swift"
    private static let sink = "Sources/Echoelmusic/Sequencer/TimelineAudioSink.swift"
    private static let mixer = "Sources/Echoelmusic/Studio/PieceMixerView.swift"

    // MARK: 1 — the engine renders a mono bus through Apple's HRTF for headphones

    func testTheSpaceBusIsAMonoHRTFInputForHeadphones() throws {
        let body = try member("func attachSpaceBus() -> AVAudioMixerNode? {", in: Self.engine)
        for needle in ["environment.outputType = .headphones",
                       "standardFormatWithSampleRate: rate, channels: 1",
                       "masterEngine.connect(environment, to: masterMixer, format: stereo)",
                       "masterEngine.connect(bus, to: environment",
                       "bus.renderingAlgorithm = .HRTFHQ"] {
            XCTAssertTrue(body.contains(needle), """
                `attachSpaceBus` lost `\(needle)`. The environment node spatialises MONO inputs \
                only and renders HRTF for headphones — without any one of these the track plays, \
                but not at a place.
                """)
        }
        try assertOrder(in: body, ["if wasRunning { masterEngine.pause() }",
                                   "masterEngine.attach(bus)",
                                   "restartOrDegrade(after: \"space bus attach\")"],
                        why: "a graph edit on a running engine pauses first and restarts through the helper (#611)")
    }

    // MARK: 2 — the sink changes mode only at prime time

    func testTheSinkReadsTheModeOnlyWhenItPrimes() throws {
        let code = SourceText.codeOnly(try text(Self.sink))
        XCTAssertEqual(code.components(separatedBy: "engine.headphoneSpaceEnabled").count - 1, 2, """
            The sink reads the switch somewhere new. It may read it only in `preload` — prime \
            time, transport parked or wrapping — because moving a node pauses the whole engine. \
            A read in `play` would pause the mix in the middle of the song.
            """)
        let preload = try member("func preload(url: URL, warped: Bool) {", in: Self.sink)
        try assertOrder(in: preload, ["engine.headphoneSpaceEnabled != wiredInSpace",
                                      "releaseNodes()",
                                      "wiredInSpace = engine.headphoneSpaceEnabled",
                                      "if let key = knownURLs[url], nodes[key] != nil"],
                        why: "the rebuild comes BEFORE the wrap no-op, or a changed switch never takes effect")
        let release = try member("private func releaseNodes() {", in: Self.sink)
        try assertOrder(in: release, ["engine.detachPlayerNode(node)",
                                      "engine.detachSpaceBus(spaceBus)",
                                      "spaceBus = nil"],
                        why: "the players that feed the bus go first, then the bus")
    }

    // MARK: 3 — the point lands on the bus, axis for axis

    func testThePointLandsOnTheBusAxisForAxis() throws {
        let code = SourceText.codeOnly(try text(Self.sink))
        XCTAssertTrue(code.contains("bus.position = AVAudio3DPoint(x: point.x, y: point.y, z: point.z)"), """
            The bus must take `HeadphoneSpace.Point` axis for axis — the conversion and its signs \
            live in ONE place (`TheHeadphoneSpaceKeepsTheADMSidesTests`). A swap here puts the \
            track on the other ear than the rig hears it.
            """)
        let setter = try member("func setSpacePosition(_ point: HeadphoneSpace.Point) {", in: Self.sink)
        XCTAssertTrue(setter.contains("spacePoint = point"),
                      "the sink must remember the point — a bus attached later starts there")
        let lazy = try member("private func spaceBusIfWired() -> AVAudioMixerNode? {", in: Self.sink)
        XCTAssertTrue(lazy.contains("if let spacePoint { place(bus, at: spacePoint) }"), """
            A newly attached bus is not placed at the lane's remembered point. The coordinator \
            hands a point over only when it CHANGES (S3b), so a bus built after that would sit \
            at the listener until the track moved.
            """)
    }

    // MARK: 4 — both attach paths route into the bus while the space is on

    func testBothAttachPathsRouteIntoTheBus() throws {
        let code = SourceText.codeOnly(try text(Self.sink))
        XCTAssertTrue(code.contains("engine.attachSpacePlayer(node, timePitch: nil, format: format, bus: bus)"),
                      "the plain node must play into the space bus while the space is on")
        XCTAssertTrue(code.contains("engine.attachSpacePlayer(player, timePitch: timePitch, format: file.processingFormat, bus: bus)"), """
            The warp/transpose chain must play into the space bus too — otherwise a stretched or \
            transposed track jumps back into the stereo mix the moment it is warped.
            """)
    }

    // MARK: 5 — off by default, one key, one writer: the Mixer's switch

    func testTheSwitchStartsOffAndHasOneWriter() throws {
        XCTAssertFalse(StudioDefaultKeys.headphoneSpace.value, """
            The headphone space must start OFF: a binaural cue over a speaker is a filter, not a \
            place, and a fresh install cannot know what the player listens on.
            """)
        let engine = SourceText.codeOnly(try text(Self.engine))
        XCTAssertTrue(engine.contains("UserDefaults.standard.object(forKey: StudioDefaultKeys.headphoneSpace.key) as? Bool"),
                      "the engine reads the switch from its one key")
        XCTAssertTrue(engine.contains("?? StudioDefaultKeys.headphoneSpace.value"),
                      "an unset key falls back to the registry's default, not to a second spelling of it (#416)")
        XCTAssertTrue(engine.contains("UserDefaults.standard.set(headphoneSpaceEnabled, forKey: StudioDefaultKeys.headphoneSpace.key)"),
                      "the engine persists the switch under the same key")
        var writers: [String] = []
        for rel in try swiftFiles(under: "Sources") {
            let code = SourceText.codeOnly(try text(rel))
            if code.contains("headphoneSpaceEnabled = ") { writers.append(rel) }
        }
        XCTAssertEqual(writers, [Self.mixer], """
            The switch has a writer other than the Mixer's door: \(writers). A second writer is \
            a second owner of where the audio tracks sound.
            """)
    }

    // MARK: 6 — the door says what it does, and the stereo path is unchanged (COUNTERWEIGHT)

    func testTheDoorSaysItsLimitsAndTheStereoPathStays() throws {
        let row = try member("private var headphoneSpaceRow: some View {", in: Self.mixer)
        for needle in ["Text(\"Headphone space\")",
                       "audioEngine.headphoneSpaceEnabled = $0",
                       ".frame(minHeight: 44)",
                       ".accessibilityHint(",
                       "audio tracks", "headphones", "Generated voices stay in the stereo mix",
                       "A change applies when playback starts"] {
            XCTAssertTrue(row.contains(needle), """
                The Headphone space row lost `\(needle)`. It must name the switch, reach 44 pt, \
                speak a hint, and say both limits: audio tracks only, from the next start.
                """)
        }
        let mixer = SourceText.codeOnly(try text(Self.mixer))
        let body = try member("var body: some View {", in: Self.mixer)
        XCTAssertTrue(body.contains("headphoneSpaceRow"), "the row is mounted at the head of the mixer")
        XCTAssertFalse(mixer.contains("Slider("), "no raw slider on the mixer (parameter law)")

        let sink = SourceText.codeOnly(try text(Self.sink))
        XCTAssertTrue(sink.contains("engine.attachPlayerNode(node, format: format)"), """
            The stereo attach of the plain node is gone. With the switch off every audio track \
            must play exactly as before S3c.
            """)
        XCTAssertTrue(sink.contains("engine.attachPlayerNode(player, through: timePitch, format: file.processingFormat)"),
                      "the stereo attach of the warp chain is gone — the off path must stay unchanged")
    }

    // MARK: 7 — the rewire happens only on the prime that STARTS playback (review MED-1/MED-2)

    func testTheRewireWaitsForThePrimeThatStartsPlayback() throws {
        let sink = SourceText.codeOnly(try text(Self.sink))
        XCTAssertTrue(sink.contains("if mayRewire, let engine, engine.headphoneSpaceEnabled != wiredInSpace {"), """
            The sink rewires without asking whether playback is starting. A wrap or a structure \
            edit primes while the song plays, and a rewire there pauses the whole engine and \
            stops a launched loop that is sounding.
            """)
        let player = "Sources/Echoelmusic/Sequencer/AudioLanePlayer.swift"
        let prime = try member("launchingInThisCall: Set<UUID>) {", in: player)   // the opening line of `prime`
        try assertOrder(in: prime, ["let mayRewire = parkedSinceStop",
                                    "parkedSinceStop = false",
                                    "sink(for: laneID).setMayRewire(mayRewire)"],
                        why: "only the first prime after a stop may rewire, and every sink is told before it preloads")
        let stop = try member("public func stopAll() {", in: player)
        try assertOrder(in: stop, ["sink.stop()", "parkedSinceStop = true"],
                        why: "a transport stop re-arms the rewire for the next start")
        // COUNTERWEIGHT: a refused space attach falls back to the stereo path, never to nothing.
        XCTAssertTrue(sink.contains("if !inSpace { engine.attachPlayerNode(node, format: format) }"),
                      "a node the space bus refused must still be attached in stereo")
        XCTAssertTrue(sink.contains("if !inSpace { engine.attachPlayerNode(player, through: timePitch, format: file.processingFormat) }"),
                      "a warp chain the space bus refused must still be attached in stereo")
    }

    // MARK: - helpers

    /// The brace-matched body of the ONE declaration that starts with `signature` (#408).
    private func member(_ signature: String, in relative: String) throws -> String {
        let code = SourceText.codeOnly(try text(relative))
        XCTAssertEqual(code.components(separatedBy: signature).count - 1, 1,
                       "`\(signature)` must occur exactly once in \(relative) — re-anchor this guard")
        guard let start = code.range(of: signature) else {
            XCTFail("`\(signature)` is gone from \(relative) — re-anchor this guard on its new home")
            return ""
        }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex, depth > 0 {
            switch code[index] {
            case "{": depth += 1
            case "}": depth -= 1
            default: break
            }
            index = code.index(after: index)
        }
        return String(code[start.upperBound..<index])
    }

    /// Each needle must occur, and each AFTER the previous one.
    private func assertOrder(in body: String, _ needles: [String], why: String) throws {
        XCTAssertFalse(body.isEmpty, "the declaration body is empty — the anchor missed")
        var cursor = body.startIndex
        for needle in needles {
            guard let hit = body.range(of: needle, range: cursor..<body.endIndex) else {
                XCTFail("`\(needle)` is missing or out of order. \(why)")
                return
            }
            cursor = hit.upperBound
        }
    }

    private func root() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }

    private func text(_ relative: String) throws -> String {
        let file = root().appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }

    /// Every `.swift` file under `relative`, as repo-relative paths, sorted.
    private func swiftFiles(under relative: String) throws -> [String] {
        let base = root()
        let dir = base.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: dir.path),
              let walker = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        var out: [String] = []
        let prefix = base.path.hasSuffix("/") ? base.path : base.path + "/"
        for case let url as URL in walker where url.pathExtension == "swift" {
            out.append(String(url.path.dropFirst(prefix.count)))
        }
        return out.sorted()
    }
}
