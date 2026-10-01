// TheWorkstationArmsTheClickTests.swift
// Design slice 10, second half (modes census 2026-09-26): the click can be armed where the song
// is played. The Workstation had Play, Record and a position readout, and no click — playing in
// time there meant leaving the surface for the Tempo panel.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claim 1 is END-TO-END on a shipped, public, Foundation-only function (`clickHint(on:)`).
//   · Claims 2–4 are SOURCE-TEXT SCANS: the leaf is a private-state SwiftUI `View` no test bundle
//     can render. They prove where the text sits, not that the button lights up.
//   · DEVICE PROBE, open: that the click is heard on the song's beats after a Workstation Play,
//     and that VoiceOver reads "Click, On, toggle button". NEEDS-FOUNDER-VERIFY.
//
// HONEST GRADING against the parent (54b2e28cf, §3): the file does not COMPILE there — claim 1
// names `WorkstationSummary.clickHint(on:)`, which this commit creates — so no assertion has a
// verdict on the parent. Hand-transcribed instead: claims 1–3 are FORWARD guards (one absence —
// the leaf file and its mount do not exist there — reported once, #486); claim 4 is a
// COUNTERWEIGHT, green on both trees: the anchor that makes a Workstation click land on the
// song's beats (54b2e28cf) and the environment injection the leaf resolves through.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheWorkstationArmsTheClickTests: XCTestCase {

    private static let leaf = "Sources/Echoelmusic/Studio/WorkstationClickToggle.swift"
    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    // MARK: 1 — the words, pure

    func testTheHintSaysWhatTheSwitchDoes() {
        XCTAssertEqual(WorkstationSummary.clickHint(on: true), "Turns the click off.")
        let off = WorkstationSummary.clickHint(on: false)
        XCTAssertTrue(off.contains("current tempo"), "the click plays at the tempo the song has now")
        XCTAssertTrue(off.contains("beats"), "and it names what it lands on")
        for promise in ["count-in", "count in", "pre-roll", "preroll"] {
            XCTAssertFalse(off.lowercased().contains(promise),
                           "the hint promises a \(promise) — there is none; the click only clicks")
        }
    }

    // MARK: 2 — the leaf arms the one metronome and reads nothing hot

    func testTheLeafTogglesTheOneMetronomeAndReadsOnlyItsSwitch() throws {
        let code = try source(Self.leaf)
        guard let start = code.range(of: "struct WorkstationClickToggle: View {") else {
            return XCTFail("ANCHOR MISSING: `struct WorkstationClickToggle: View {` (#454)")
        }
        let body = String(code[start.upperBound...])
        // The receiver is DERIVED from the declaration, never assumed (review of 9d64dd8a8, MED —
        // the #408 blind spot `TheMenuHostReadsNoHotStateTests` closed with `environmentReceiver`):
        // renamed to `click`, a scan for the literal `metronome.` would see nothing and pass.
        let declaration = "@Environment(MetronomeVoice.self) private var "
        guard let decl = body.range(of: declaration) else {
            return XCTFail("the leaf no longer resolves the ONE metronome the app injects through `@Environment(MetronomeVoice.self)` (#454)")
        }
        let receiver = String(body[decl.upperBound...].prefix { $0.isLetter || $0.isNumber || $0 == "_" })
        XCTAssertFalse(receiver.isEmpty, "the voice binding has a name")
        XCTAssertTrue(body.contains("\(receiver).enabled.toggle()"), "the tap flips the click")
        // No alias the member scan below could not follow — `@Bindable var m = …` or `let m = …`.
        XCTAssertFalse(body.contains("@Bindable"), "the leaf binds nothing — a Bindable alias hides its reads")
        XCTAssertFalse(body.contains("= \(receiver)\n") || body.contains("= \(receiver) "),
                       "the voice is not aliased to a second name")
        // Every member this leaf touches on the voice must be the cold switch. `bpm` is pushed by
        // the "metronome" tempo relay during a glide (`TheMenuHostReadsNoHotStateTests`), and this
        // leaf sits under the menu host (#479).
        var members: Set<String> = []
        var rest = body[...]
        while let hit = rest.range(of: "\(receiver).") {
            let tail = rest[hit.upperBound...]
            let name = String(tail.prefix { $0.isLetter || $0.isNumber || $0 == "_" })
            members.insert(name)
            rest = tail
        }
        XCTAssertEqual(members, ["enabled"], """
            `WorkstationClickToggle` touches \(members.sorted()) on the metronome — only the cold \
            `enabled` switch belongs here. A tempo or level readout is its own self-driving leaf.
            """)
        XCTAssertEqual(code.components(separatedBy: "MetronomeVoice(").count - 1, 0,
                       "the leaf constructs no voice")
        // The same control language as the Play beside it, and a real switch for VoiceOver.
        XCTAssertTrue(body.contains(".frame(minHeight: 44)"), "a 44 pt target, as Play has")
        XCTAssertTrue(body.contains("cornerRadius: EchoelTheme.radius"), "the theme's radius, as Play has")
        XCTAssertTrue(body.contains(".accessibilityAddTraits(.isToggle)"), "VoiceOver hears a switch")
        // E4-44: both arms are catalog keys — the needle follows the spelling, the claim is unchanged.
        XCTAssertTrue(body.contains(".accessibilityValue(on ? String(localized: \"On\") : String(localized: \"Off\"))"), "and its state")
        XCTAssertTrue(body.contains(".accessibilityHint(WorkstationSummary.clickHint(on: on))"),
                      "the hint comes from the one pure sentence (claim 1)")
    }

    // MARK: 3 — the Workstation mounts it once, beside Play, and names no voice

    func testTheTransportRowMountsTheSwitchBesidePlay() throws {
        let code = try source(Self.workstation)
        guard let row = code.range(of: "private var transportRow: some View {"),
              let next = code.range(of: "private var addTrackRow: some View {", range: row.upperBound..<code.endIndex) else {
            return XCTFail("ANCHOR MISSING: `transportRow` before `addTrackRow` (#454)")
        }
        let transport = String(code[row.upperBound..<next.lowerBound])
        XCTAssertEqual(code.components(separatedBy: "WorkstationClickToggle()").count - 1, 1,
                       "one Click switch on the plate")
        guard let group = transport.range(of: "controls {"),
              let hint = transport.range(of: "ProjectPlayStopButton(source: \"workstation\")", range: group.upperBound..<transport.endIndex),
              let mount = transport.range(of: "WorkstationClickToggle()", range: hint.upperBound..<transport.endIndex),
              transport.range(of: "SongPositionReadout()", range: mount.upperBound..<transport.endIndex) != nil else {
            return XCTFail("the Click switch is not mounted after Play and before the position readout, inside `controls { … }`")
        }
        // Balanced braces between the group's opening and the mount: the switch is a direct child
        // of the switching group. +1 would put it inside a branch (`if playing {` — a switch that
        // vanishes while stopped); -1 would put it after the group's `}`, under the caption,
        // where it would not stack with Play at accessibility sizes.
        let lead = transport[group.upperBound..<mount.lowerBound]
        XCTAssertEqual(lead.filter { $0 == "{" }.count - lead.filter { $0 == "}" }.count, 0,
                       "the switch is a direct, unconditional child of the Play group")
        // Narrow on purpose (review of 9d64dd8a8, LOW-4, #364): the TYPE and a member read. A
        // symbol name, a copy string or a helper that merely says "metronome" is not a voice.
        for name in ["MetronomeVoice", "metronome."] {
            XCTAssertFalse(code.contains(name), """
                `WorkstationView` names `\(name)` — the view names no voice; the click lives in \
                its own leaf (`WorkstationClickToggle`), as the recorder does (`RecordTakeControls`).
                """)
        }
    }

    // MARK: 4 — counterweights: the voice is injected, and anchored to the transport's beats

    func testTheClickTheSwitchArmsLandsOnTheSongsBeats() throws {
        let code = try source(Self.app)
        XCTAssertTrue(code.contains(".environment(metronome)"),
                      "the app injects the one metronome the leaf resolves — without it the leaf traps at runtime")
        XCTAssertEqual(code.components(separatedBy: "addStepSubscriber(\"metronome\"").count - 1, 1, """
            the transport no longer anchors the click on its beats (54b2e28cf) — a click armed on \
            the Workstation would then run on its own clock and drift against the song
            """)
        XCTAssertTrue(code.contains("metronome?.anchorBeat(pos.step / Transport.stepsPerBeat, of: Transport.beatsPerBar)"),
                      "the anchor names the beat inside the transport's bar")
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
