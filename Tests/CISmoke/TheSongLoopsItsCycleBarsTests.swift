// TheSongLoopsItsCycleBarsTests.swift
// Echoel — GMMW AE-12a (founder 2026-10-08, "Die klassische DAW Audio Editing View fehlt mir noch …
// Orientiere dich an den Bigplayern"): a piece can loop a range of its bars, the way a DAW's cycle
// region does.
//
// WHAT IT PINS. `TimelineDocument.cycle` is a stored `TimelineCycle` (two raw ticks); what PLAYS is
// `TimelineCycle.window(loopTicks:)` — whole bars inside the song, at least one, never the whole
// song (that IS the song loop, which keeps its own wrap). While the loop is on and the playhead is
// before the cycle's end, `TimelineRegionPlayer.transportStep` sends the song back to the cycle's
// first bar through the SAME hard cut a locate uses (`cutAndPrime`, one recipe, #416), and
// `songEndTick` — where a take ends — names that same tick (`wrapTick`).
//
// 1. PURE: the window — floored edges, clamped end, the one-bar minimum, the whole-song nil, and
//    edges no ruler writes (negative, `Int.max`).
// 2. PURE: the song file — no cycle writes no key (an older build reads the file unchanged), an
//    older song decodes with none, a malformed cycle costs the cycle and never the song, and the
//    cycle is document state (`==` sees it) that is not sound structure (`structurallyEqual`
//    does not — a cycle edit must not re-attack a voice).
// 3. PURE: the wrap rule and the take end agree on every step of a song.
// 4. END-TO-END BEHAVIOUR over a real `TimelineRegionPlayer`, `ClipStore`, `PatternEngine` and
//    `PianoRollModel` (the `AStructureEditKeepsTheBarTests` rig): the song goes back to the cycle's
//    first bar and the roll and the rack track play THAT bar; with the loop off it plays through
//    and stops; a cycle set while the piece plays takes the next wrap; a playhead past the cycle
//    plays on to the song's end, wraps to bar 1 and meets the cycle again.
// 5. SOURCE: the cycle branch sits before the song wrap and calls the shared cut; `relocate` calls
//    it too, and nothing else does; the refresh adopts a cycle before its structure gate; the piece
//    bounce still turns the loop off, so a bounce renders the whole piece, never a cycle.
//
// Grading (§0, no Swift toolchain in a web session): on the parent (`013126d`) this file does NOT
// COMPILE — it names `TimelineCycle`, `TimelineDocument.cycle`, `wrapTick` and `cycleWraps`, which
// this commit creates — so no assertion has a verdict there. Every claim is a FORWARD guard; claim
// 5's `LoopExporter` scan is a COUNTERWEIGHT (green on both trees). The window, the wrap rule, the
// cursor and the step sequences of claim 4 were transcribed into Python and driven on the worktree.
// NOT covered: that the jump is heard click-free and in time on a device, and anything a person
// does — nothing sets a cycle yet; the ruler's gesture is AE-12b.
// KNOWN LIMITS, written where a reader looks: the cycle's wrap is a hard cut, so a clip launched
// from the session view dies at it (a locate does the same); a take armed after a wrap ends at once,
// because `RecordController` counts transport ticks, which do not wrap (the song wrap has the same
// limit since R1).

import Foundation
import XCTest
@testable import Echoelmusic

#if canImport(SwiftUI)
@MainActor
final class TheSongLoopsItsCycleBarsTests: XCTestCase {

    private static let steps = 16
    private static let bar = TimelineTime.ticksPerBar
    private static let playerPath = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"

    private var rigClips: ClipStore?
    private var rigPlayer: TimelineRegionPlayer?
    private var rigPattern: PatternEngine?

    // MARK: 1 — the window

    func testTheWindowIsWholeBarsInsideTheSong() {
        let b = Self.bar
        let song = 8 * b
        func window(_ start: Int, _ end: Int, loop: Int = 8 * TimelineTime.ticksPerBar) -> Range<Int>? {
            TimelineCycle(startTick: start, endTick: end).window(loopTicks: loop)
        }
        XCTAssertEqual(window(2 * b, 4 * b), (2 * b)..<(4 * b), "bars 3 and 4 loop")
        XCTAssertEqual(window(2 * b + 100, 4 * b + 300), (2 * b)..<(4 * b), "both edges floor to a bar line")
        XCTAssertEqual(window(6 * b, 20 * b), (6 * b)..<song, "an end past the song stops at the song's end")
        XCTAssertEqual(window(-5, 2 * b), 0..<(2 * b), "a negative start reads as bar 1")
        XCTAssertEqual(window(Int.min, 2 * b), 0..<(2 * b))
        XCTAssertEqual(window(b, Int.max), b..<song, "no edge can overflow")
        XCTAssertNil(window(3 * b, 3 * b + b - 1), "less than one whole bar loops nothing")
        XCTAssertNil(window(5 * b, 2 * b), "a reversed range loops nothing")
        XCTAssertNil(window(0, song), "the whole song is the song loop, not a cycle")
        XCTAssertNil(window(0, 40 * b), "…also when the end only reaches it through the clamp")
        XCTAssertNil(window(9 * b, 12 * b), "a cycle wholly after a song that got shorter loops nothing")
        XCTAssertNil(window(b, 2 * b, loop: 0), "an empty song has no bars to loop")
    }

    // MARK: 2 — the song file

    func testACycleTravelsInTheSongFileAndAnOlderSongHasNone() throws {
        let lane = TimelineLane(name: "Keys", kind: .midi)
        let plain = TimelineDocument(lanes: [lane], regions: [
            TimelineRegion(laneID: lane.id, clipID: UUID(), startTick: 0, lengthTicks: 4 * Self.bar),
        ])
        XCTAssertNil(plain.cycle, "a new document has no cycle")

        let plainJSON = try object(plain)
        XCTAssertNil(plainJSON["cycle"], "no cycle writes no key — an older build reads the file unchanged")
        let older = try JSONDecoder().decode(TimelineDocument.self, from: try JSONSerialization.data(withJSONObject: plainJSON))
        XCTAssertNil(older.cycle, "a song from before AE-12a decodes with no cycle")
        XCTAssertEqual(older.lanes.count, 1)

        var cycled = plain
        cycled.cycle = TimelineCycle(startTick: Self.bar, endTick: 3 * Self.bar)
        let back = try JSONDecoder().decode(TimelineDocument.self, from: try JSONEncoder().encode(cycled))
        XCTAssertEqual(back.cycle, cycled.cycle, "the cycle round-trips through Save and Open")

        let malformed: [Any] = ["bars 2 to 4", 7, ["startTick": "two"], ["endTick": 3]]
        for bad in malformed {
            var json = try object(plain)
            json["cycle"] = bad
            let doc = try JSONDecoder().decode(TimelineDocument.self, from: try JSONSerialization.data(withJSONObject: json))
            XCTAssertNil(doc.cycle, "a malformed cycle (\(bad)) is dropped")
            XCTAssertEqual(doc.lanes.count, 1, "…and never costs the song")
            XCTAssertEqual(doc.regions.count, 1)
        }

        XCTAssertNotEqual(plain, cycled, "the cycle is document state — Undo and Save see the change")
        XCTAssertTrue(TimelineDocument.structurallyEqual(plain, cycled), """
            a cycle changes where the song wraps, not what sounds at a tick — a structural verdict \
            here would flush and re-attack every voice each time the cycle moves
            """)
    }

    // MARK: 3 — the wrap rule and the take end

    func testTheWrapAndTheTakeEndNameTheSameTick() {
        let b = Self.bar
        let song = 8 * b
        let cycle = (2 * b)..<(4 * b)
        XCTAssertEqual(TimelineRegionPlayer.wrapTick(lastTick: 0, loopTicks: song, cycle: cycle), 4 * b,
                       "before the cycle's end the song wraps there")
        XCTAssertEqual(TimelineRegionPlayer.wrapTick(lastTick: 4 * b, loopTicks: song, cycle: cycle), song,
                       "past it the song plays on to its end")
        XCTAssertEqual(TimelineRegionPlayer.wrapTick(lastTick: 0, loopTicks: song, cycle: nil), song)
        let step = TimelineTime.ticksPerTransportStep
        XCTAssertTrue(TimelineRegionPlayer.cycleWraps(lastTick: 4 * b - step, newTick: 4 * b, cycle: cycle))
        XCTAssertFalse(TimelineRegionPlayer.cycleWraps(lastTick: 4 * b - 2 * step, newTick: 4 * b - step, cycle: cycle))
        XCTAssertFalse(TimelineRegionPlayer.cycleWraps(lastTick: 5 * b, newTick: 5 * b + step, cycle: cycle),
                       "a playhead past the cycle is not pulled back")
        XCTAssertFalse(TimelineRegionPlayer.cycleWraps(lastTick: 4 * b - step, newTick: 4 * b, cycle: nil))

        let windows: [Range<Int>] = [cycle, 0..<b, (6 * b)..<song]
        for window in windows {
            for last in stride(from: 0, to: song, by: step) {
                let next = last + step
                let end = TimelineRegionPlayer.wrapTick(lastTick: last, loopTicks: song, cycle: window)
                XCTAssertEqual(TimelineRegionPlayer.cycleWraps(lastTick: last, newTick: next, cycle: window),
                               end == window.upperBound && next >= end, """
                    at tick \(last) the step's wrap and the take's end disagree for \(window) — a take \
                    would end somewhere the song does not wrap
                    """)
            }
        }
    }

    // MARK: 4 — END-TO-END

    func testThePlayingSongGoesBackToTheCyclesFirstBar() {
        let rig = makeRig(cycle: TimelineCycle(startTick: Self.bar, endTick: 3 * Self.bar))
        XCTAssertEqual(ons(run(rig, steps: 0..<1)), [48], "ANCHOR MISSING: the rack track did not start its bar 1")
        run(rig, steps: 1..<48)
        XCTAssertEqual(rig.player.songEndTick, 3 * Self.bar, "a take started now ends at the cycle's end")
        let back = run(rig, steps: 48..<49)
        XCTAssertEqual(rig.player.currentTick, Self.bar, "the cycle's end sends the song to the cycle's first bar")
        XCTAssertEqual(ons(back), [50], "the rack track plays its bar 2 there, not its bar 4 (53)")
        XCTAssertEqual(rig.roll.notes.map(\.pitch), [62], "the roll holds its bar 2 there, not its bar 4 (65)")
        run(rig, steps: 49..<64)
        XCTAssertEqual(ons(run(rig, steps: 64..<65)), [52], "the cycle's second bar follows in time")
        run(rig, steps: 65..<80)
        run(rig, steps: 80..<81)
        XCTAssertEqual(rig.player.currentTick, Self.bar, "and it cycles again")
        XCTAssertTrue(rig.player.isPlaying)
    }

    func testWithTheLoopOffTheSongPlaysThroughAndStops() {
        let rig = makeRig(cycle: TimelineCycle(startTick: Self.bar, endTick: 3 * Self.bar), looping: false)
        run(rig, steps: 0..<48)
        XCTAssertEqual(rig.player.songEndTick, 4 * Self.bar, "with the loop off a take ends at the song's end")
        XCTAssertEqual(ons(run(rig, steps: 48..<49)), [53], "no cycle: the rack track plays its bar 4")
        XCTAssertEqual(rig.player.currentTick, 3 * Self.bar)
        run(rig, steps: 49..<65)
        XCTAssertFalse(rig.player.isPlaying, "the song stops at its end")
        XCTAssertTrue(rig.player.lastStopReachedSongEnd)
    }

    func testACycleSetWhileThePiecePlaysTakesTheNextWrap() {
        let rig = makeRig(cycle: nil)
        run(rig, steps: 0..<20)
        XCTAssertEqual(rig.player.songEndTick, 4 * Self.bar, "ANCHOR MISSING: no cycle yet, the song ends at its end")
        var cycled = rig.document
        cycled.cycle = TimelineCycle(startTick: Self.bar, endTick: 2 * Self.bar)
        rig.live = cycled
        run(rig, steps: 20..<21)
        XCTAssertEqual(rig.player.songEndTick, 2 * Self.bar, "the refresh took the cycle on the next step")
        run(rig, steps: 21..<32)
        let back = run(rig, steps: 32..<33)
        XCTAssertEqual(rig.player.currentTick, Self.bar, "the cycle set mid-play takes this wrap")
        XCTAssertEqual(ons(back), [50])
        XCTAssertEqual(rig.roll.notes.map(\.pitch), [62])
    }

    func testAPlayheadPastTheCyclePlaysOnAndMeetsItAfterTheSongWraps() {
        let rig = makeRig(cycle: TimelineCycle(startTick: Self.bar, endTick: 2 * Self.bar), from: 3 * Self.bar)
        XCTAssertEqual(ons(run(rig, steps: 0..<1)), [53], "ANCHOR MISSING: Play did not start on bar 4")
        XCTAssertEqual(rig.player.songEndTick, 4 * Self.bar, "past the cycle a take ends at the song's end")
        run(rig, steps: 1..<16)
        run(rig, steps: 16..<17)
        XCTAssertEqual(rig.player.currentTick, 0, "the song wraps to bar 1, as it always has")
        run(rig, steps: 17..<48)
        let back = run(rig, steps: 48..<49)
        XCTAssertEqual(rig.player.currentTick, Self.bar, "…and meets the cycle again")
        XCTAssertEqual(ons(back), [50])
    }

    // MARK: 5 — SOURCE

    func testTheCycleWrapsThroughTheLocatesCutBeforeTheSongWraps() throws {
        let player = try source(Self.playerPath)
        let step = try body(of: "public func transportStep(_ step: Int) {", in: player)
        guard let cycleBranch = step.range(of: "if Self.cycleWraps(lastTick: lastTick, newTick: newTick, cycle: cycle), let cycle {"),
              let songWrap = step.range(of: "} else if loopTicks > 0, newTick >= loopTicks {") else {
            return XCTFail("ANCHOR MISSING: the cycle branch or the song wrap in transportStep (#454)")
        }
        XCTAssertLessThan(cycleBranch.lowerBound, songWrap.lowerBound,
                          "the cycle is asked first — the song wrap is its else")
        let cycled = String(step[cycleBranch.upperBound..<songWrap.lowerBound])
        XCTAssertTrue(cycled.contains("cursor = TimelinePlaybackCursor(startBar: cycle.lowerBound / TimelineTime.ticksPerBar)"))
        XCTAssertTrue(cycled.contains("cutAndPrime(atTick: newTick, step: step)"),
                      "the wrap back is the locate's hard cut, at the tick and step this step sounds")

        XCTAssertEqual(player.components(separatedBy: "cutAndPrime(atTick: ").count - 1, 2, """
            one recipe, two jumps: `relocate` and the cycle's wrap. A third caller is fine when it is \
            a jump too — name it in `cutAndPrime`'s doc and here.
            """)
        let relocate = try body(of: "public func relocate(toTick tick: Int) {", in: player)
        XCTAssertTrue(relocate.contains("cutAndPrime(atTick: anchor, step: nextStep)"))
        XCTAssertTrue(player.contains("loopEnabled ? doc.cycle?.window(loopTicks: loopTicks) : nil"),
                      "with the loop off nothing cycles")

        let refresh = try body(of: "private func refreshStructure() -> StructureChase? {", in: player)
        guard let adopt = refresh.range(of: "if doc.cycle != fresh.cycle { doc.cycle = fresh.cycle }"),
              let gate = refresh.range(of: "guard !TimelineDocument.structurallyEqual(doc, fresh) else { return nil }") else {
            return XCTFail("ANCHOR MISSING: the cycle adoption or the structure gate in refreshStructure (#454)")
        }
        XCTAssertLessThan(adopt.lowerBound, gate.lowerBound,
                          "behind the gate a cycle-only edit would never reach the playing song")

        // Counterweight: the piece bounce turns the loop off, so it renders the whole piece.
        let exporter = try source("Sources/Echoelmusic/Audio/LoopExporter.swift")
        XCTAssertTrue(exporter.contains("player.loopEnabled = false"),
                      "a bounce that kept the loop on would write the cycle, not the piece")
    }

    // MARK: rig

    /// Everything the rig plays, what the rack sink heard, and the document the store would hand
    /// the player (nil = no edit yet).
    private final class Rig {
        let player: TimelineRegionPlayer
        let roll: PianoRollModel
        let document: TimelineDocument
        var live: TimelineDocument?
        var heard: [LaneNotePump.Event] = []
        init(player: TimelineRegionPlayer, roll: PianoRollModel, document: TimelineDocument) {
            self.player = player; self.roll = roll; self.document = document
        }
    }

    /// Two MIDI tracks, each with ONE four-bar part from bar 1, a different pitch in every bar so a
    /// bar can be named by what sounds: the roll plays 60 · 62 · 64 · 65, the rack track
    /// 48 · 50 · 52 · 53. The song is four bars long.
    private func makeRig(cycle: TimelineCycle?, looping: Bool = true, from: Int = 0) -> Rig {
        let clips = ClipStore()
        for i in clips.slots.indices { clips.clear(at: i) }
        let rollClip = Clip(name: "Roll", melody: oneNotePerBar([60, 62, 64, 65]))
        let rackClip = Clip(name: "Rack", melody: oneNotePerBar([48, 50, 52, 53]))
        clips.setClip(at: 0, rollClip)
        clips.setClip(at: 1, rackClip)
        let first = TimelineLane(name: "Keys", kind: .midi)
        let second = TimelineLane(name: "Pad", kind: .midi)
        let length = 4 * Self.bar
        var document = TimelineDocument(lanes: [first, second], regions: [
            TimelineRegion(laneID: first.id, clipID: rollClip.id, startTick: 0, lengthTicks: length),
            TimelineRegion(laneID: second.id, clipID: rackClip.id, startTick: 0, lengthTicks: length),
        ])
        document.cycle = cycle
        let player = TimelineRegionPlayer()
        player.loopEnabled = looping
        let pattern = PatternEngine()
        let roll = PianoRollModel()
        let rig = Rig(player: player, roll: roll, document: document)
        player.enableMultiRoll(capacity: 4, sink: { [weak rig] slot, events in
            if slot == 0 { rig?.heard.append(contentsOf: events) }
        })
        player.liveDocument = { [weak rig] in rig?.live }
        rigClips = clips
        rigPlayer = player
        rigPattern = pattern
        player.play(document: document, clips: clips, pattern: pattern, pianoRoll: roll, fromTick: from)
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

    private func ons(_ events: [LaneNotePump.Event]) -> [Int] { events.filter(\.isOn).map(\.pitch) }

    /// One quarter-bar note at the top of each bar, `pitches[n]` in bar n + 1.
    private func oneNotePerBar(_ pitches: [Int]) -> MelodyClip {
        var notes: [Note] = []
        for (bar, pitch) in pitches.enumerated() {
            notes.append(Note(pitch: pitch, startStep: bar * Self.steps, lengthSteps: 4))
        }
        return MelodyClip(notes: notes)
    }

    private func object(_ document: TimelineDocument) throws -> [String: Any] {
        let data = try JSONEncoder().encode(document)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("ANCHOR MISSING: a document does not encode as a JSON object")
            return [:]
        }
        return json
    }

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

    /// The brace-matched body after `anchor` — never a fixed window (#408).
    private func body(of anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing(name: anchor)
        }
        guard let open = code[code.index(before: start.upperBound)...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: no body after \(anchor) (#454)")
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
        XCTFail("ANCHOR MISSING: unbalanced braces after \(anchor) (#454)")
        throw AnchorMissing(name: anchor)
    }
}
#endif
