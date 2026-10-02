// TheTrackMeterReadsTheTracksOwnVoiceTests.swift
// Echoel — a track's mixer strip shows that track's level, read from the track's OWN voice, or it
// says "Not metered" (Workstation redesign B5, founder 2026-10-01).
//
// WHY: until B5 the Piece mixer had faders and no meters, because no per-track level source
// existed. A rack slot is the one place a track has its own audio node (`PolySynthVoice.sourceNode`),
// and its render block already measured a block peak — but only inside the entrainment gate, and
// only to decide when to sleep. B5 lets that peak feed ONE held cell per voice, read through the
// rack's own slot resolution, by a leaf view, while the piece plays.
//
// THE SIX CLAIMS:
// 1. END-TO-END: `PolySynthVoice.heldPeak` rises instantly, releases at the master meter's rate
//    (×0.92 per 800 frames), reads exactly 0 under its floor, and turns NaN/±inf and negative
//    frame counts into a finite reading — a poisoned block must not freeze the bar.
// 2. END-TO-END (Debug seams): `LaneVoiceRack.meterLevel(slot:)` is nil for an unattached rack and
//    out-of-range slots, a number for a slot bound to its own poly voice, and nil while that slot
//    is bound to the shared sub unit — then a number again once it is poly again.
// 3. SOURCE-TEXT: in the render body the block peak is measured BEFORE the entrainment gate and
//    stored once per block; the sleep path zeroes the cell; the body still names no allocation,
//    lock, task, queue or log; the cell is written nowhere else and is `@ObservationIgnored`.
// 4. SOURCE-TEXT: the leaf reads the cell inside its own paused-when-stopped `TimelineView`, takes
//    its slot from the player's rule, opens no modal and names no hot engine state; the mixer
//    mounts it once, inside the strip, and names neither the rack nor the cell.
// 5. CATALOG: the three new sentences are catalogued (German lines until 2026-10-02; English-only since).
// 6. SOURCE-TEXT PREMISE: the app root injects the three `@Observable`s the leaf resolves. Before B5
//    the mixer subtree needed only `TimelineStore`; an `@Environment(X.self)` with no injection
//    traps at the first render, so the leaf's two new dependencies are pinned at their one injector.
//
// THE LIMIT. Claims 1–2 drive shipped code but cannot render audio: no claim here proves a bar
// MOVES with a sounding track. DEVICE PROBE, open: the bar follows a playing poly track, drops to
// zero on Mute, rests at zero after Stop, an open Picker on the plate stays open while it moves,
// the Echoel track and an audio track say "Not metered".
//
// GRADING (§0/§3, no Swift toolchain in a web session — claims 3–6 transcribed in Python against
// both trees): against the parent `PolySynthVoice.heldPeak`, `LaneVoiceRack.meterLevel(slot:)` and
// `TrackLevelMeter` do not exist, so this file does NOT COMPILE there — no assertion has a verdict
// on the parent. Hand-transcribed, claims 3–5 are red there by ONE absence each family
// (`renderPeakHold`, `TrackLevelMeter.swift`, the three catalog keys — #486, not twelve findings).
// Claims 1–2 are FORWARD guards on functions this commit creates. COUNTERWEIGHTS, green on both
// trees: the render body's no-allocation/no-lock/no-log scan (3d), the sleep decision still under
// `if !audioEntrainmentActive {` (3b), PieceMixerView never naming the rack (4c), and all of
// claim 6 (the three injections exist on the parent already — it pins the PREMISE, #343).
// Stripper: `SourceText.codeOnly` is TRAGEND (1 of 43 transcribed verdicts flips raw vs. stripped):
// PieceMixerView's header prose names `LaneVoiceRack.setPan`, so the raw text
// would turn claim 4's "the mixer never names the rack" red on correct code.

import XCTest
@testable import Echoelmusic

final class TheTrackMeterReadsTheTracksOwnVoiceTests: XCTestCase {

    private static let voice = "Sources/Echoelmusic/Tools/PolySynthVoice.swift"
    private static let rack = "Sources/Echoelmusic/Sequencer/LaneVoiceRack.swift"
    private static let leaf = "Sources/Echoelmusic/Studio/TrackLevelMeter.swift"
    private static let mixer = "Sources/Echoelmusic/Studio/PieceMixerView.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    // MARK: 1 — the held peak

    func testTheHeldPeakRisesAtOnceAndFallsAtTheMixMetersRate() {
        XCTAssertEqual(PolySynthVoice.heldPeak(previous: 0, blockPeak: 0.5, frames: 128), 0.5,
                       "a louder block shows at once — a meter that lags the attack hides the peak")
        let released = PolySynthVoice.heldPeak(previous: 1, blockPeak: 0, frames: 800)
        XCTAssertEqual(released, 0.92, accuracy: 0.001,
                       "800 frames at 48 kHz is one 60 Hz tick of the mix meter, which keeps 0.92 per tick — one release for both bars")
        XCTAssertEqual(PolySynthVoice.heldPeak(previous: 0.3, blockPeak: 0, frames: 0), 0.3,
                       "an empty block changes nothing")
        XCTAssertEqual(PolySynthVoice.heldPeak(previous: 1, blockPeak: 0, frames: 480_000), 0,
                       "ten silent seconds read exactly zero, not a denormal tail")
        XCTAssertEqual(PolySynthVoice.heldPeak(previous: 0.4, blockPeak: 0, frames: -100), 0.4,
                       "a negative frame count is no frames, never a rise")
    }

    func testAPoisonedBlockCannotFreezeTheBar() {
        let poison: [Float] = [.nan, .infinity, -.infinity]
        for p in poison {
            let fromPrevious = PolySynthVoice.heldPeak(previous: p, blockPeak: 0.2, frames: 128)
            let fromBlock = PolySynthVoice.heldPeak(previous: 0.2, blockPeak: p, frames: 0)
            for reading in [fromPrevious, fromBlock] {
                XCTAssertTrue(reading.isFinite && reading >= 0,
                              "a \(p) reached the held peak as \(reading) — a non-finite cell pins the bar for good")
            }
            XCTAssertEqual(fromPrevious, 0.2, "a poisoned hold is dropped, the fresh block shows")
            XCTAssertEqual(fromBlock, 0.2, "a poisoned block is dropped, the hold stays")
        }
    }

    // MARK: 2 — the rack answers only for a slot's own poly voice

    @MainActor
    func testOnlyASlotsOwnPolyVoiceHasALevel() {
        #if DEBUG
        let rack = LaneVoiceRack(capacity: 2)
        XCTAssertNil(rack.meterLevel(slot: 0), "an unattached rack has no voice to meter")
        rack.installVoicesForTests([PolySynthVoice(maxVoices: 1), PolySynthVoice(maxVoices: 1)])
        XCTAssertEqual(rack.meterLevel(slot: 0), 0, "a silent poly voice reads zero — a number, not 'Not metered'")
        XCTAssertEqual(rack.meterLevel(slot: 1), 0)
        XCTAssertNil(rack.meterLevel(slot: -1), "no slot below zero")
        XCTAssertNil(rack.meterLevel(slot: 2), "no slot past the voices")

        rack.installKindUnitsForTests(subs: [SubBassVoice()])
        rack.setKind(slot: 1, kind: .subBass)
        XCTAssertEqual(rack.bindingsForTests[1], .subBass(0),
                       "premise: slot 1 now sounds through the shared sub unit")
        XCTAssertNil(rack.meterLevel(slot: 1), """
            a slot bound to the shared sub unit read a level — the sub carries no meter cell and \
            can also be the Echoel track's voice, so the bar would show another track's sound
            """)
        XCTAssertEqual(rack.meterLevel(slot: 0), 0, "the neighbouring poly slot keeps its meter")
        rack.setKind(slot: 1, kind: .poly)
        XCTAssertEqual(rack.meterLevel(slot: 1), 0, "back on its own poly voice, the slot meters again")
        #else
        XCTFail("the rack's test seams are Debug-only; this claim needs the Debug build that Build for Testing makes")
        #endif
    }

    // MARK: 3 — the render stores one cell per block and stays audio-thread clean

    func testTheRenderStoresTheBlockPeakOncePerBlock() throws {
        let code = SourceText.codeOnly(try text(Self.voice))
        let render = try body(after: "nonisolated(unsafe) private func renderOnAudioThread(", in: code)

        let store = "renderPeakHold = Self.heldPeak(previous: renderPeakHold, blockPeak: peak, frames: count)"
        XCTAssertEqual(render.components(separatedBy: store).count - 1, 1,
                       "the render stores the held peak exactly once per block")
        guard let measure = render.range(of: "var peak: Float = 0"),
              let stored = render.range(of: store),
              let gate = render.range(of: "if !audioEntrainmentActive {") else {
            XCTFail("ANCHOR MISSING: the block-peak loop, its store or the sleep gate is gone from the render (#454)")
            return
        }
        XCTAssertLessThan(measure.lowerBound, gate.lowerBound, """
            the block peak is measured INSIDE the entrainment gate again — with a stimulus armed \
            the meter would freeze on its last value while the track keeps sounding
            """)
        XCTAssertLessThan(measure.lowerBound, stored.lowerBound)
        XCTAssertLessThan(stored.lowerBound, gate.lowerBound, "the store sits between the measurement and the sleep decision")
        XCTAssertTrue(render[gate.upperBound...].contains("if peak < Self.idlePeakFloor {"),
                      "counterweight: the sleep decision still reads the same block peak, under the gate")

        let sleeping = try body(after: "if renderIdle {", in: render)
        guard let reset = sleeping.range(of: "renderPeakHold = 0"),
              let leave = sleeping.range(of: "return") else {
            XCTFail("ANCHOR MISSING: the sleep path no longer zeroes the cell before it returns (#454)")
            return
        }
        XCTAssertLessThan(reset.lowerBound, leave.lowerBound,
                          "a sleeping voice meters silence — otherwise the bar holds the last note for ever")

        for banned in ["String(", "Task {", "DispatchQueue", "NSLock", "os_log", "print(", ".append(", "log.log("] {
            XCTAssertFalse(render.contains(banned),
                           "the render body contains `\(banned)` — no allocation, lock, task, queue or log on the audio thread")
        }

        let writes = code.components(separatedBy: "renderPeakHold =").count - 1
        let renderWrites = render.components(separatedBy: "renderPeakHold =").count - 1
        XCTAssertEqual(renderWrites, 2, "two writes in the render: the per-block store and the sleep reset")
        XCTAssertEqual(writes, renderWrites, "the cell has one writer, the audio thread — nothing on the main actor writes it")
        XCTAssertTrue(code.contains("@ObservationIgnored\n    nonisolated(unsafe) private var renderPeakHold: Float = 0"), """
            the cell must stay `@ObservationIgnored` — an observed property written on every \
            render block re-renders every reader (the 10.76.41/50 freeze law)
            """)
    }

    // MARK: 4 — the leaf reads it, the mixer only mounts the leaf

    func testOnlyTheLeafReadsTheLevelAndOnlyWhilePlaying() throws {
        let leaf = SourceText.codeOnly(try text(Self.leaf))
        let leafBody = try body(after: "var body: some View {", in: leaf)
        XCTAssertEqual(leafBody.components(separatedBy: "rack.meterLevel(slot: slot)").count - 1, 1,
                       "the level is read once, in the leaf")
        guard let clock = leafBody.range(of: "TimelineView("),
              let read = leafBody.range(of: "rack.meterLevel(slot: slot)") else {
            XCTFail("ANCHOR MISSING: the leaf's TimelineView or its read is gone (#454)")
            return
        }
        XCTAssertLessThan(clock.lowerBound, read.lowerBound,
                          "the cell is read inside the leaf's own clock, never in a body that re-renders for other reasons")
        XCTAssertTrue(leafBody.contains("paused: !playing"), "the clock stops with the piece — no work while stopped")
        XCTAssertTrue(leafBody.contains("let shown: Float = playing ? level : 0"), "stopped reads zero, not the last block")
        XCTAssertTrue(leafBody.contains("MultiRollFanout.slot(forLaneID: laneID, in: document,"),
                      "the slot is the player's own rule (#416) — the same answer `TrackMix.role` gets")
        XCTAssertTrue(leafBody.contains("Text(\"Not metered\")"), "a track without its own voice says so in words")
        for banned in [".sheet(", ".fullScreenCover(", ".popover(", ".alert(", ".confirmationDialog(",
                       "masterLevel", "latestBio", "currentTick", "cameraRPPG", "EngineBus", "AudioEngine"] {
            XCTAssertFalse(leaf.contains(banned), "the meter leaf contains `\(banned)` — no modal, no other hot state")
        }

        let mixer = SourceText.codeOnly(try text(Self.mixer))
        let strip = try body(after: "private func strip(_ lane: TimelineLane, _ controls: TrackMix.Controls) -> some View {",
                                  in: mixer)
        XCTAssertEqual(strip.components(separatedBy: "TrackLevelMeter(laneID: lane.id, voiceCapacity: voiceCapacity)").count - 1, 1,
                       "each strip mounts the meter once")
        for banned in ["meterLevel", "LaneVoiceRack", "outputPeak"] {
            XCTAssertFalse(mixer.contains(banned), """
                `PieceMixerView` names `\(banned)` — the strip list would read the meter in its own \
                body and re-render every strip at meter rate. The read belongs to `TrackLevelMeter`.
                """)
        }
        let mounts = try filesMatching { $0.contains("TrackLevelMeter(") }
        XCTAssertEqual(mounts, [Self.mixer], "the track meter has one home, the Piece mixer's strip")
    }

    // MARK: 5 — catalog

    func testTheMeterWordsAreCatalogued() throws {
        let data = try Data(contentsOf: repoRoot().appendingPathComponent(Self.catalog))
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = root["strings"] as? [String: Any] else {
            XCTFail("the catalog is not the expected JSON shape")
            return
        }
        let expected = [
            "Track level",
            "Peak of this track's sound after its fader, as a share of full scale. Moves while the piece plays.",
            "Not metered",
        ]
        for key in expected {
            guard let entry = strings[key] as? [String: Any],
                  let units = entry["localizations"] as? [String: Any],
                  let en = (units["en"] as? [String: Any])?["stringUnit"] as? [String: Any] else {
                XCTFail("`\(key)` has no English line in the catalog")
                continue
            }
            XCTAssertEqual(Set(units.keys), ["en"], "`\(key)`: the app speaks one language (founder 2026-10-02) — no second unit")
            XCTAssertEqual(en["state"] as? String, "translated")
            XCTAssertEqual(en["value"] as? String, key, "the English line is the key")
            XCTAssertEqual(entry["extractionState"] as? String, "manual")
        }
    }

    // MARK: 6 — the root injects what the leaf resolves

    func testTheAppInjectsWhatTheMeterLeafResolves() throws {
        let leaf = SourceText.codeOnly(try text(Self.leaf))
        let app = SourceText.codeOnly(try text(Self.app))
        guard let root = app.range(of: "WorkspaceView()") else {
            XCTFail("ANCHOR MISSING: the app root `WorkspaceView()` is gone from EchoelmusicApp (#454)")
            return
        }
        let chain = app[root.upperBound...]
        let needs: [(resolved: String, injected: String)] = [
            ("@Environment(TimelineStore.self)", ".environment(timelineStore)"),
            ("@Environment(TimelineRegionPlayer.self)", ".environment(timelinePlayer)"),
            ("@Environment(LaneVoiceRack.self)", ".environment(laneVoiceRack)"),
        ]
        for need in needs {
            XCTAssertTrue(leaf.contains(need.resolved), "premise: the leaf resolves `\(need.resolved)`")
            XCTAssertTrue(chain.contains(need.injected), """
                the app root no longer injects `\(need.injected)` — the meter leaf resolves it, and an \
                `@Environment` with no injection traps at the first render of the Piece mixer
                """)
        }
    }

    // MARK: helpers

    /// The brace-matched body of the first `{` at or after `anchor` (#408); string-literal aware.
    private func body(after anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            return ""
        }
        var depth = 1
        var index = code.index(after: open)
        var inString = false
        while index < code.endIndex {
            let ch = code[index]
            if inString, ch == "\\" {
                index = code.index(after: index)
                if index < code.endIndex { index = code.index(after: index) }
                continue
            }
            if ch == "\"" { inString.toggle() }
            if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(code[code.index(after: open)..<index]) }
                }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: `\(anchor)` never closes (#454)")
        return ""
    }

    /// Comment-stripped files under `Sources/Echoelmusic` for which `matches` holds, repo-relative, sorted.
    private func filesMatching(_ matches: (String) -> Bool) throws -> [String] {
        let base = "Sources/Echoelmusic"
        let root = repoRoot().appendingPathComponent(base)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(base) — a scan that saw nothing is not a pass")
            return []
        }
        var hits: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8) else { continue }
            if matches(SourceText.codeOnly(text)) { hits.append(base + "/" + relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return hits.sorted()
    }

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }
}
