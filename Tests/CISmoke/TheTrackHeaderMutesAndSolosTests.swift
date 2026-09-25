// TheTrackHeaderMutesAndSolosTests.swift
// Echoel — WA4 critical path 6: Mute and Solo in the track header.
//
// WHAT THIS PINS. Until WA4 path 6 a track could be muted or soloed only after opening its
// inspector. The switches now sit in the track row (`WorkstationView.laneRow`), and the
// inspector no longer draws them — one control per fact on screen. The risk is not a crash but
// a switch that moves nothing (#164/#227) or a second wording of what it does (#416):
//
// 1. END-TO-END over the shipped pure type: `TrackMix.muteHint`/`soloHint` name the coupling
//    with the Studio instrument exactly where it exists — muting the Echoel track silences the
//    instrument, soloing any OTHER track does.
// 2. SOURCE: the header draws the switches only where `TrackMix.controls(…).muteSolo` says the
//    track is heard (the inspector's own rule), writes only through `TrackMix.flipMute`/
//    `flipSolo`, speaks the shared hints, and keeps the switches OUTSIDE the combined facts
//    element (#621).
// 3. SOURCE: ONE door — `TimelineStore.toggleMute`/`toggleSolo` have exactly one production
//    caller each (inside `TrackMix`), and the only callers of `TrackMix.flipMute`/`flipSolo` are
//    the header's; the inspector draws neither any more.
//
// Grading (§0, no Swift toolchain in a web session): claim 1 HAND-TRACED against `TrackMix` as
// written; claims 2–3 driven in Python against this tree. On the parent (048b4c69c)
// `muteHint`/`soloHint` do not exist, so the bundle does not build there — ONE absence (#486);
// every claim is a FORWARD guard, and claim 3's store-caller half is a COUNTERWEIGHT (green on
// both trees). NOT covered: that a tapped M is HEARD, or that the row still fits at the
// largest type size — a device probe.
// NEEDS-FOUNDER-VERIFY: Workstation → while the song plays, tap M and S on a track row; the
// Echoel track's M also silences the Studio instrument and Start un-mutes it.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTrackHeaderMutesAndSolosTests: XCTestCase {

    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"

    // MARK: 1 — the hints name the coupling where it exists

    func testTheHintsNameTheInstrumentCouplingOnlyWhereItExists() {
        XCTAssertTrue(TrackMix.muteHint(.echoelInstrument).contains("Studio instrument"),
                      "muting the Echoel track silences the instrument — the hint must say so")
        XCTAssertFalse(TrackMix.muteHint(.audio).contains("Studio instrument"),
                       "muting an audio track leaves the instrument alone")
        XCTAssertFalse(TrackMix.soloHint(.echoelInstrument).contains("Studio instrument"),
                       "soloing the Echoel track keeps the instrument playing")
        for role: TrackMix.Role in [.audio, .laneSynth(.poly)] {
            XCTAssertTrue(TrackMix.soloHint(role).contains("Studio instrument"),
                          "soloing \(role) zeroes the unsoloed instrument — the hint must say so")
        }
    }

    // MARK: 2 — the header draws them where they are heard, through the store's API

    func testTheHeaderDrawsWiredSwitchesThroughTrackMix() throws {
        let view = try code(Self.workstationPath)
        guard let rowStart = view.range(of: "private func laneRow("),
              let rowEnd = view.range(of: "private func headerSwitch(",
                                      range: rowStart.upperBound..<view.endIndex) else {
            return XCTFail("ANCHOR MISSING: laneRow / headerSwitch (#454)")
        }
        let row = String(view[rowStart.upperBound..<rowEnd.lowerBound])
        for needle in ["TrackMix.controls(of: row.id, in: timeline.document,",
                       "voiceCapacity: player.laneVoiceCapacity)",
                       "$0.muteSolo ? $0.role : nil",
                       "if let role = muteSoloRole {",
                       "TrackMix.flipMute(laneID: row.id, timeline: timeline)",
                       "TrackMix.flipSolo(laneID: row.id, timeline: timeline)",
                       "hint: TrackMix.muteHint(role)", "hint: TrackMix.soloHint(role)"] {
            XCTAssertTrue(row.contains(needle), "the track header lost `\(needle)`")
        }

        guard let factsStart = view.range(of: "private func laneFacts("),
              let factsEnd = view.range(of: "private func warpSwitch(",
                                        range: factsStart.upperBound..<view.endIndex) else {
            return XCTFail("ANCHOR MISSING: laneFacts / warpSwitch (#454)")
        }
        XCTAssertFalse(view[factsStart.upperBound..<factsEnd.lowerBound].contains("headerSwitch("),
                       "a switch inside the combined facts element loses its own focus (#621)")

        guard let switchStart = view.range(of: "private func headerSwitch("),
              let switchEnd = view.range(of: "private func laneFacts(",
                                         range: switchStart.upperBound..<view.endIndex) else {
            return XCTFail("ANCHOR MISSING: headerSwitch / laneFacts (#454)")
        }
        let control = String(view[switchStart.upperBound..<switchEnd.lowerBound])
        for needle in [".accessibilityLabel(name)", ".accessibilityInputLabels([name, letter])",
                       ".accessibilityAddTraits(.isToggle)",
                       ".accessibilityValue(on ? \"On\" : \"Off\")", ".accessibilityHint(hint)",
                       ".frame(minWidth: 44, minHeight: 44)"] {
            XCTAssertTrue(control.contains(needle), "the header switch lost `\(needle)`")
        }
    }

    // MARK: 3 — one door per fact

    func testMuteAndSoloHaveOneDoor() throws {
        let inspector = try code(Self.inspectorPath)
        let view = try code(Self.workstationPath)
        for call in ["timeline.toggleMute(", "timeline.toggleSolo("] {
            XCTAssertEqual(inspector.components(separatedBy: call).count - 1, 1,
                           "`\(call)` is called once, inside `TrackMix`")
        }
        for call in ["TrackMix.flipMute(", "TrackMix.flipSolo("] {
            XCTAssertFalse(inspector.contains(call),
                           "the inspector draws `\(call)` again — two switches for one fact on screen")
            XCTAssertEqual(view.components(separatedBy: call).count - 1, 1,
                           "the track header is the one caller of `\(call)`")
        }
    }

    // MARK: helpers

    private func code(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }
}
