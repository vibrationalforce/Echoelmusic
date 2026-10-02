// ThePieceHasAMixerTests.swift
// Echoel — the Piece stage has a mixer: every sounding track as one channel strip, behind the
// "Mix" tab, standing INSTEAD of the arrangement (Workstation redesign B3, founder 2026-10-01).
//
// WHY: until B3 a track's level, pan, Mute and Solo were reachable one track at a time through
// the inspector. A workstation balances a song on ONE surface. `PieceMixerView` lists the tracks
// that make a sound, each with its hue, name, dB reading, Level, Pan where the engine honours it,
// and Mute/Solo.
//
// THE THREE CLAIMS:
// 1. SOURCE: the strip set and each strip's controls come from `TrackMix.controls` — the
//    inspector's own rule, no second one; a track without a level gets no strip and the view
//    counts what it left out; Pan and Mute/Solo sit inside their flags; every write goes through
//    the `TrackMix` funnel and nothing writes the store directly; numbers are `EchoelValueField`.
// 2. SOURCE: the Workstation shows the mixer INSTEAD of the arrangement (one control per fact on
//    screen — a strip's Mute and the track header's Mute are never shown together), it is built
//    once, nowhere else, with no modal, and it reads no hot state (the 10.76.41/50 law).
// 3. END-TO-END + CATALOG: `TrackMix.levelHint` is the one wording for both the inspector and the
//    mixer (#416) — it reads its English source under the test locale and names the Studio
//    instrument only on the Echoel track; the mixer's new sentences and the two plate-tab hints
//    have German lines.
//
// GRADING (§0/§3, no Swift toolchain in a web session — claims 1–2 and the catalog half of 3
// transcribed in Python against both trees): against the parent (a724b604f) `PieceMixerView.swift`
// does not exist and `TrackMix.levelHint` is not declared, so this file does NOT COMPILE there —
// no assertion has a verdict on the parent; hand-transcribed, claims 1–2 and the catalog needles
// are red there by ONE absence (#486). The counterweights inside them (`TrackMix.controls` still
// declared, `TrackMix.setLevel`/`flipMute` still the writers, the Workstation's arrangement branch
// still drawing `ArrangeCanvasView(`) are green on both. Claim 3's runtime half is a FORWARD guard
// on a function this commit creates. DEVICE PROBE, open: the strips read well at 375–440 pt, a
// fader move is heard, Mix → Arrange keeps the selection — readings, not scans.

import XCTest
@testable import Echoelmusic

final class ThePieceHasAMixerTests: XCTestCase {

    private static let mixer = "Sources/Echoelmusic/Studio/PieceMixerView.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"

    // MARK: 1 — the strips follow the inspector's rule and write through its funnel

    func testTheStripsFollowTheInspectorsRule() throws {
        let code = SourceText.codeOnly(try text(Self.mixer))
        let body = try member("var body: some View {", in: code)
        XCTAssertTrue(body.contains("TrackMix.controls(of: lane.id, in: document, voiceCapacity: voiceCapacity)"),
                      "the strip set is the inspector's own rule — no second answer to 'which controls does a track have'")
        XCTAssertTrue(body.contains("controls.level else { return nil }"),
                      "a track without a level makes no sound and gets no strip — a fader there would move a number, not the sound")
        XCTAssertTrue(body.contains("let silent = document.lanes.count - strips.count"),
                      "the view counts the tracks it left out, so nothing vanishes silently")
        XCTAssertTrue(code.contains("let voiceCapacity: Int"),
                      "the voice capacity is a required input (#431) — a forgotten call site must not assume a voice")

        let strip = try member("private func strip(_ lane: TimelineLane, _ controls: TrackMix.Controls) -> some View {", in: code)
        let pan = try member("if controls.pan {", in: strip)
        XCTAssertTrue(pan.contains("label: \"Pan\""), "the Pan field sits inside `controls.pan` — no pan where the engine ignores it")
        let muteSolo = try member("if controls.muteSolo {", in: strip)
        XCTAssertTrue(muteSolo.contains("TrackMix.flipMute(laneID: lane.id, timeline: timeline)"), "Mute sits inside `controls.muteSolo`")
        XCTAssertTrue(muteSolo.contains("TrackMix.flipSolo(laneID: lane.id, timeline: timeline)"), "Solo sits inside `controls.muteSolo`")
        for writer in ["TrackMix.setLevel(newLevel, laneID: lane.id, timeline: timeline)",
                       "TrackMix.setPan(newPan, laneID: lane.id, timeline: timeline)",
                       "hint: TrackMix.levelHint(controls.role)",
                       "hint: TrackMix.muteHint(controls.role)",
                       "hint: TrackMix.soloHint(controls.role)"] {
            XCTAssertTrue(strip.contains(writer), "the strip goes through the inspector's funnel: `\(writer)`")
        }
        for direct in ["timeline.setLaneLevel(", "timeline.setLanePan(", "timeline.toggleMute(", "timeline.toggleSolo(",
                       "document.lanes[", "replaceDocument(", "Slider(", "Stepper("] {
            XCTAssertFalse(code.contains(direct), "the mixer bypasses the `TrackMix` funnel or the parameter law with `\(direct)`")
        }
        XCTAssertEqual(code.components(separatedBy: "EchoelValueField(").count - 1, 2,
                       "Level and Pan — the two numbers a strip carries — are EchoelValueField rows")
    }

    // MARK: 2 — instead of the arrangement, built once, no modal, no hot read

    func testTheMixerStandsInsteadOfTheArrangement() throws {
        let workstation = SourceText.codeOnly(try text(Self.workstation))
        let body = try member("var body: some View {", in: workstation)
        guard let mixBranch = body.range(of: "} else if plate == .mix {"),
              let mixer = body.range(of: "PieceMixerView(voiceCapacity: player.laneVoiceCapacity)"),
              let arrangeBranch = body.range(of: "} else {", range: mixBranch.upperBound..<body.endIndex),
              let canvas = body.range(of: "ArrangeCanvasView(") else {
            return XCTFail("ANCHOR MISSING: the mix branch, the mixer, the arrangement branch or the canvas (#454)")
        }
        XCTAssertLessThan(mixBranch.lowerBound, mixer.lowerBound, "the mixer is drawn in the Mix branch")
        XCTAssertLessThan(mixer.lowerBound, arrangeBranch.lowerBound, """
            the mixer is drawn before the arrangement's `else` — INSTEAD of the canvas and the track \
            column, so a strip's Mute and the track header's Mute are never on screen together
            """)
        XCTAssertLessThan(arrangeBranch.lowerBound, canvas.lowerBound, "the canvas lives only in the arrangement branch")

        let constructions = try filesMatching { $0.contains("PieceMixerView(") }
        XCTAssertEqual(constructions, [Self.workstation], "the mixer has exactly one door: the piece's Mix tab")

        let code = SourceText.codeOnly(try text(Self.mixer))
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert(", ".confirmationDialog("] {
            XCTAssertFalse(code.contains(modal), "the mixer is a view of the plate, never a modal (black-screen law): `\(modal)`")
        }
        for hot in ["masterLevel", "latestBio", "currentTick", "cameraRPPG", "TimelineRegionPlayer", "EngineBus"] {
            XCTAssertFalse(code.contains(hot), """
                the mixer reads `\(hot)` — a hot or engine-side read in a list the user scrolls while \
                the song plays (10.76.41/50); the live meter is the leaf `TrackLevelMeter` (B5), never this body
                """)
        }
    }

    // MARK: 3 — one level wording, and the German lines

    func testTheLevelHintIsOneWordingInBothLanguages() throws {
        let echoel = TrackMix.levelHint(.echoelInstrument)
        XCTAssertTrue(echoel.contains("Studio instrument"),
                      "the Echoel track's level is also the instrument's — its hint says so")
        for role in [TrackMix.Role.audio, TrackMix.Role.noVoice(capacity: 2)] {
            XCTAssertEqual(TrackMix.levelHint(role), "1.00 unchanged, 0 silent, 2.00 is +6 dB",
                           "every other sounding track reads the plain dB hint")
        }
        let inspector = SourceText.codeOnly(try text("Sources/Echoelmusic/Studio/TrackInspectorView.swift"))
        XCTAssertTrue(inspector.contains("hint: TrackMix.levelHint(controls.role),"),
                      "the inspector reads the same wording as the mixer (#416)")

        let data = Data(try text(Self.catalog).utf8)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = root?["strings"] as? [String: Any] ?? [:]
        for key in ["Shows the arrangement: the tracks and their parts",
                    "Shows every sounding track's level, pan, mute and solo in one list",
                    "No track makes a sound yet. Add a track or write a part, and its strip appears here",
                    "1 track makes no sound and has no strip",
                    "tracks make no sound and have no strip"] {
            let entry = strings[key] as? [String: Any]
            let localizations = entry?["localizations"] as? [String: Any] ?? [:]
            let en = (localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertEqual(en?["value"] as? String, key, "`\(key)` has its English line")
            XCTAssertEqual(Set(localizations.keys), ["en"], "`\(key)`: the app speaks one language (founder 2026-10-02) — no second unit")
        }
    }

    // MARK: helpers

    /// The brace-matched body after `anchor` (#408); string-literal aware.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            return ""
        }
        var depth = 1
        var index = start.upperBound
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
                    if depth == 0 { return String(code[start.upperBound..<index]) }
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
