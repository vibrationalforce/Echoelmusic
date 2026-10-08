// TheSongPositionIsReadAsANumberTests.swift
// Echoel — modes census 2026-09-26, design D1: while the song plays, the Workstation says WHICH bar.
//
// WHAT THIS PINS. The arrangement playhead showed where on the picture the song was, and nothing
// said which bar — a musician counting in, or a VoiceOver user, had no position at all. Beside
// Play/Stop a leaf now reads "Bar 12 · Beat 3" while the timeline plays.
//
// 1. END-TO-END BEHAVIOUR (`WorkstationSummary.positionText`, pure): bar from the one bar-number
//    rule, the beat always named (a readout that drops it on the downbeat changes width every
//    bar), a negative tick folds to the top.
// 2. SOURCE: the readout is its own self-driving leaf — a 15 Hz `TimelineView` paused while
//    stopped, the ONLY reader of `currentTick` in its file, speaking as "Position in the piece" (rule 1: piece, not song) with a
//    frequently-updating value — and does nothing but show.
// 4. BEHAVIOUR + SOURCE (D1b): the playing caption said "from the top" whatever the start; it now
//    names the start bar — red on the parent, where `transportCaption` took no tick. Since the
//    review of 09d35f56e (MED-5) the bar is recorded by the PLAYER inside `play`
//    (`startedFromTick`), so every door into the one start names its own bar; the behavioural
//    half (a header start after a bar-3 start reads "from the top") lives in
//    `TheProjectHeaderRunsOneTransportTests`, which owns the real-clock fixture.
//    ⚠️ Design slice C (2026-10-01): the plate no longer DRAWS the playing caption — its one line
//    now stands only for a piece that cannot start or a running instrument, and the start bar
//    shows in the head's counter (`ProjectPositionReadout`), which counts from the played tick.
//    What stays pinned is unchanged and still true: the pure function names the bar, and the
//    player is its one writer. The `fromTick: player.startedFromTick))` needle now pins only that
//    the plate's line is FED the player's value (no view-local copy, MED-5) — on screen today it
//    reaches the not-playing branches alone. Restoring a playing line needs a founder ask.
// 3. SOURCE: `WorkstationView` mounts it once, only while playing, in the transport row. That the
//    view itself never names `currentTick` is pinned ONCE, by
//    `TheWorkstationPlaysTheTimelineTests.testTheControlDoesNotReadThePlayhead` (#416).
//    ⭐ Design slice C (2026-10-01): the bar became ONE row, and the readout is now the element
//    that YIELDS when the row has no room (a phone in portrait) — the head counts the same
//    position on every stage. That yielding is `TheTransportBarIsOneRowTests` claim 6; this file
//    keeps "once, while playing, inside the group". The caption pin is re-anchored: the caption
//    now stands behind its own `if` after the group, so the old count "one more `}` than `{`
//    between the group and the caption" (exact only for a BARE caption) became false on a
//    correct tree. The law — the caption is outside the switching group — is measured directly
//    now, by walking the group's braces to its closing one.
//
// Grading (§0, no Swift toolchain): `positionText` and `SongPositionReadout` do not exist on the
// parent (`ce4b422dc`), so this file does not compile there — claims 1-3 were FORWARD guards, one
// absence (#486). Claim 1's arithmetic was transcribed into Python and driven on the cases below;
// claims 2 and 3 transcribed against this tree: green. Re-graded after the D1 review repairs
// (82ee9350b, 645b056c0): the claim-3 layout pins (dynamicTypeSize, AnyLayout, the caption's
// brace balance, the readout inside the group) and claim 2's one-read and read-inside-the-clock
// pins are COUNTERWEIGHTS against those parents — green there — mutation-driven instead
// (caption back in the group, readout after the group's brace, read hoisted above the clock).
// NOT covered: that the number keeps up with the sound on glass, and how VoiceOver paces an
// `.updatesFrequently` value — a device probe.
// NEEDS-FOUNDER-VERIFY: Workstation in LANDSCAPE (slice C: in portrait the readout yields to the
// head's counter) → Play: "Bar 1 · Beat 1" appears beside the meter and counts with the music;
// Play from a part at bar 9 starts it at "Bar 9"; Stop removes it.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheSongPositionIsReadAsANumberTests: XCTestCase {

    private static let leaf = "Sources/Echoelmusic/Studio/SongPositionReadout.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let player = "Sources/Echoelmusic/Sequencer/TimelineRegionPlayer.swift"

    // MARK: 1 — the words, pure

    func testThePositionNamesTheBarAndTheBeat() {
        let bar = TimelineTime.ticksPerBar
        let beat = TimelineTime.ticksPerBeat
        XCTAssertEqual(WorkstationSummary.positionText(forTick: 0), "Bar 1 · Beat 1")
        XCTAssertEqual(WorkstationSummary.positionText(forTick: beat - 1), "Bar 1 · Beat 1",
                       "the last tick of a beat still reads that beat")
        XCTAssertEqual(WorkstationSummary.positionText(forTick: bar), "Bar 2 · Beat 1",
                       "the downbeat names its beat too — the readout keeps its width")
        XCTAssertEqual(WorkstationSummary.positionText(forTick: 11 * bar + 2 * beat), "Bar 12 · Beat 3")
        XCTAssertEqual(WorkstationSummary.positionText(forTick: bar - 1), "Bar 1 · Beat 4")
        XCTAssertEqual(WorkstationSummary.positionText(forTick: -5), "Bar 1 · Beat 1",
                       "a negative tick folds to the top, as the bar-number rule does")
    }

    // MARK: 2 — the leaf self-drives and only shows

    func testTheReadoutIsASelfDrivingLeaf() throws {
        let code = try source(Self.leaf)
        guard let start = code.range(of: "struct SongPositionReadout: View {") else {
            return XCTFail("ANCHOR MISSING: `struct SongPositionReadout: View {` (#454)")
        }
        let body = String(code[start.upperBound...])
        XCTAssertTrue(body.contains("TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing))"),
                      "the readout redraws itself at the playhead's rate and stops while the song is stopped")
        XCTAssertTrue(body.contains("WorkstationSummary.positionText(forTick: player.currentTick)"),
                      "the words come from the one pure rule, fed the player's position")
        XCTAssertEqual(code.components(separatedBy: "currentTick").count - 1, 1,
                       "ONE read of the position in this file (review of e1036b874, LOW)")
        // Review of 82ee9350b, LOW-6: and that read is INSIDE the self-driving view — hoisted
        // above it, an `@ObservationIgnored` value is read once and never again.
        if let clock = body.range(of: "TimelineView("), let read = body.range(of: "player.currentTick") {
            XCTAssertLessThan(clock.lowerBound, read.lowerBound, "the position is read inside the `TimelineView`, per frame")
        }
        XCTAssertTrue(body.contains(".accessibilityLabel(\"Position in the piece\")"),
                      "the readout speaks the glossary word (rule 1, ratchet 13): piece, not song")
        XCTAssertTrue(body.contains(".accessibilityValue(text)"))
        XCTAssertTrue(body.contains(".accessibilityAddTraits(.updatesFrequently)"),
                      "VoiceOver is told the value moves, so it paces rather than floods")
        for banned in ["player.play(", "player.stop()", "relocate", "selection", "timeline.", "Button("] {
            XCTAssertFalse(body.contains(banned),
                           "`SongPositionReadout` contains `\(banned)` — it shows the position and does nothing else")
        }
    }

    // MARK: 3 — the Workstation mounts it once, while playing

    func testTheTransportRowShowsItOnlyWhilePlaying() throws {
        let code = try source(Self.workstation)
        guard let row = code.range(of: "private var transportRow: some View {"),
              let next = code.range(of: "private var addTrackRow: some View {", range: row.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: `transportRow` before `addTrackRow` (#454)")
        }
        let transport = String(code[row.upperBound..<next.lowerBound])
        // The row's Button action opens with `if playing {` too, so the gate is the NEAREST one
        // before the mount, searched backwards (#408), never the first in the row.
        guard let mount = transport.range(of: "SongPositionReadout()"),
              let gate = transport.range(of: "if playing {", options: .backwards,
                                         range: transport.startIndex..<mount.lowerBound) else {
            return XCTFail("the transport row no longer mounts `SongPositionReadout()` behind `if playing {`")
        }
        XCTAssertFalse(transport[gate.upperBound..<mount.lowerBound].contains("}"),
                       "the readout sits INSIDE the playing branch — a stopped song has no position to show")
        XCTAssertEqual(code.components(separatedBy: "SongPositionReadout()").count - 1, 1,
                       "one position readout on the plate")
        // Review of 82ee9350b, LOW-4: the MED fix itself. Play + readout switch to a stack at
        // accessibility sizes, and the caption lives OUTSIDE that group, on its own line.
        XCTAssertTrue(transport.contains("let controls = dynamicTypeSize.isAccessibilitySize"),
                      "the Play row's arrangement follows the text size")
        XCTAssertTrue(transport.contains("? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))"),
                      "at accessibility sizes Play and the readout stack")
        guard let group = transport.range(of: "controls {"),
              let caption = transport.range(of: "WorkstationSummary.transportCaption(", range: group.upperBound..<transport.endIndex) else {
            return XCTFail("the transport row no longer groups Play in `controls { … }` ahead of its caption")
        }
        XCTAssertLessThan(group.lowerBound, mount.lowerBound, "the readout comes after the switching group opens")
        // Review of 645b056c0, LOW-7: and before it CLOSES — moved between the group's `}` and the
        // caption, the readout would sit after the group and the delta above would not see it.
        if group.upperBound < mount.lowerBound {
            let lead = transport[group.upperBound..<mount.lowerBound]
            // Inside: the group is still open AND so is the `if playing {` that holds the
            // readout, so opens exceed closes by at least one. After the group's `}`, that
            // brace cancels the `if` and the balance falls to zero.
            XCTAssertGreaterThanOrEqual(lead.filter { $0 == "{" }.count - lead.filter { $0 == "}" }.count, 1,
                                        "the readout is inside the switching group, not after its closing brace")
        }
        // Slice C re-anchor (see the header): find the group's OWN closing brace and require the
        // caption after it and the readout before it. The old "+1" count assumed a bare caption.
        var depth = 1
        var close = transport.endIndex
        var cursor = group.upperBound
        while cursor < transport.endIndex {
            let ch = transport[cursor]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { close = cursor; break }
            }
            cursor = transport.index(after: cursor)
        }
        guard close < transport.endIndex else {
            return XCTFail("UNBALANCED: the transport row's `controls {` never closes (#454)")
        }
        XCTAssertLessThan(mount.lowerBound, close, "the readout is a member of the switching group")
        XCTAssertLessThan(close, caption.lowerBound, """
            the caption is back inside the Play group — at large sizes it becomes a narrow column \
            that re-wraps whenever the readout comes and goes. It has its own line.
            """)
    }

    // MARK: 4 — the caption names where the take started (D1b)

    func testThePlayingCaptionNamesTheStartBar() throws {
        let bar = TimelineTime.ticksPerBar
        XCTAssertEqual(WorkstationSummary.transportCaption(playing: true, startable: true, fromTick: 0),
                       "Playing from the top on the shared transport.")
        XCTAssertEqual(WorkstationSummary.transportCaption(playing: true, startable: true, fromTick: 8 * bar),
                       "Playing from bar 9 on the shared transport.",
                       "Play from a part at bar 9 must not be captioned 'from the top'")
        XCTAssertEqual(WorkstationSummary.transportCaption(playing: true, startable: true, fromTick: bar - 1),
                       "Playing from the top on the shared transport.",
                       "a tick inside bar 1 starts on bar 1 — the transport starts on the bar")
        XCTAssertEqual(WorkstationSummary.transportCaption(playing: false, startable: true, fromTick: 8 * bar),
                       WorkstationSummary.transportCaption(playing: false, startable: true, fromTick: 0),
                       "a stopped song's caption does not depend on where the last take started")

        // Review of 09d35f56e, MED-5: the start bar is recorded by the PLAYER, inside `play` — the
        // one place every door (the Workstation's Play, the part bar, a scene, the project header)
        // ends up. A view-local copy was written by the Workstation's own Play only, so after a
        // header start the caption named an older take's bar.
        let player = try source(Self.player)
        guard let head = player.range(of: "public func play("),
              let set = player.range(of: "self.startedFromTick = startTick", range: head.upperBound..<player.endIndex),
              // GMMW AE-7: `play` floors through `playStartTick`, the ONE fold the Play hint and the
              // ruler's marker also ask; that it is `barStartTick` is pinned by
              // `ThePlayStartsWhereTheRulerSaysTests`.
              let floor = player.range(of: "let startTick = Self.playStartTick(forCue: fromTick, in: document)",
                                       range: head.upperBound..<player.endIndex) else {
            return XCTFail("ANCHOR MISSING: `play` recording `startedFromTick` (#454)")
        }
        XCTAssertLessThan(floor.lowerBound, set.lowerBound, "the recorded start is the FLOORED bar the song starts on")
        let writes = player.components(separatedBy: "startedFromTick =").count
            - player.components(separatedBy: "var startedFromTick =").count
        XCTAssertEqual(writes, 1, "ONE writer (the declaration aside): `play`")
        let code = try source(Self.workstation)
        XCTAssertTrue(code.contains("fromTick: player.startedFromTick))"),
                      "the plate's line is fed the player's recorded start, never a view-local copy (MED-5) — slice C draws only its not-playing branches")
        XCTAssertFalse(code.contains("playedFromTick"), "no second, view-local copy of the start")
    }

    // MARK: helpers

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}
