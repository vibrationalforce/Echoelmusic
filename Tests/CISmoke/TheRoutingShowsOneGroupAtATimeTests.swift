// TheRoutingShowsOneGroupAtATimeTests.swift
// Echoel — GMMW P1-1 (founder 2026-10-08: „vermeide Unübersichtlichkeit"). Routing (`PatchbayView`)
// stacked nine cards in one scroll: the network outputs, the light, the OSC input, MIDI pairing, the
// MIDI status and switches, the body's routes, the routing graph. It now shows ONE group at a time
// behind a segmented row at the top: Light · Connections · Body.
//
// WHY LIGHT FIRST, AND WHY EVERY OPENING LANDS THERE. The sheet has ONE door, the head's light tile
// (`TheRoutingHasOneDoorTests`): a status that opens its own configuration. Opening on anything but
// Light would hide the very thing the tile reports. The choice is `@State`, so each opening starts
// fresh; a person who wants MIDI taps one segment.
//
// WHAT IT PINS.
// 1. PURE: the three groups, in that order; the sheet opens on Light; each has its own word.
// 2. SOURCE: `content` starts with the segmented row, holds exactly one `if` per group, and mounts
//    every card exactly once, inside its group's `if` — so no card is lost and none shows twice.
//    The Light card's note names the Connections segment by the word the segment wears.
// 3. SOURCE: the row is a segmented `Picker` over `RoutingGroup.allCases`, written only by a tap
//    (`@State`), and it reads nothing hot.
// The other guards over this sheet keep their own claims (#416): `content` still mounts
// `lichtSection` (`ThePieceHasOneTabRowTests`), `oscInSection` (`TheOSCControlInputIsAWhitelistTests`),
// `modulationSection` (`TheMatrixHasADoorTests`), and `MIDIStatusRow()` after the CoreMIDI gate and
// before `networkMIDISection` (`TheMIDIRowSaysWhatTheCableIsDoingTests`).
//
// Grading (§0, no Swift toolchain): on the parent (`11b61b8`) this file does NOT COMPILE — it names
// `RoutingGroup`, which this commit creates — so no assertion has a verdict there; every claim is a
// FORWARD guard. Claim 1 and every scan were transcribed into Python and driven on the worktree.
// NOT covered: how the segments read at large text sizes, and what VoiceOver speaks — device probes.
// NEEDS-FOUNDER-VERIFY: tap the light tile → Routing opens on Light (master, blackout, DMX,
// fixtures); tap Connections → outputs, OSC input, MIDI and the connection cards; tap Body → the
// body's routes. Close and reopen → Light again.

import Foundation
import XCTest
@testable import Echoelmusic

#if canImport(SwiftUI)
@MainActor
final class TheRoutingShowsOneGroupAtATimeTests: XCTestCase {

    private static let patchbay = "Sources/Echoelmusic/Studio/PatchbayView.swift"

    // MARK: 1 — three groups, Light first

    func testThereAreThreeGroupsAndTheSheetOpensOnLight() {
        XCTAssertEqual(RoutingGroup.allCases, [.light, .connections, .body],
                       "Light · Connections · Body — Light first, the subject of the sheet's one door")
        XCTAssertEqual(RoutingGroup.opening, .light, "every opening comes through the light tile, so it lands on Light")
        let titles = RoutingGroup.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count, "each segment has its own word")
        XCTAssertFalse(titles.contains(where: \.isEmpty), "no segment is blank")
    }

    // MARK: 2 — one `if` per group, every card once, inside its group

    func testEveryCardIsMountedOnceInsideItsGroup() throws {
        let content = try member("private var content: some View {", in: try source(Self.patchbay))
        guard let picker = content.range(of: "groupPicker"),
              let firstGroup = content.range(of: "if group == .") else {
            return XCTFail("ANCHOR MISSING: `groupPicker` or a group `if` in `content` (#454)")
        }
        XCTAssertLessThan(picker.lowerBound, firstGroup.lowerBound, "the segmented row comes first, above every group")

        let cards: [(RoutingGroup, [String])] = [
            (.light, ["lichtSection"]),
            (.body, ["modulationSection"]),
            (.connections, ["headerBar", "networkOutSection", "oscInSection", "bluetoothMIDISection",
                            "MIDIStatusRow()", "networkMIDISection", "midiOutSection",
                            "ForEach(router.graph.sources)"]),
        ]
        for (group, mounts) in cards {
            let head = "if group == .\(group.rawValue) {"
            XCTAssertEqual(content.components(separatedBy: head).count - 1, 1, "exactly one `\(head)` in `content`")
            let body = try member(head, in: content)
            for mount in mounts {
                XCTAssertEqual(content.components(separatedBy: mount).count - 1, 1,
                               "`\(mount)` is mounted exactly once in `content` — not lost, not shown twice")
                XCTAssertTrue(body.contains(mount), "`\(mount)` sits inside the \(group.rawValue) group")
            }
        }

        let light = try member("if group == .light {", in: content)
        XCTAssertTrue(light.contains("is set under Connections."),
                      "the Light card says where its node address lives — the Connections segment")
        XCTAssertEqual(RoutingGroup.connections.title, "Connections",
                       "COUNTERWEIGHT: the note's word is the segment's word")
    }

    // MARK: 3 — a segmented row, written by a tap

    func testTheRowIsASegmentedPickerWrittenByATap() throws {
        let code = try source(Self.patchbay)
        XCTAssertEqual(code.components(separatedBy: "@State private var group = RoutingGroup.opening").count - 1, 1,
                       "the group is view state that starts at the opening group")
        let row = try member("private var groupPicker: some View {", in: code)
        XCTAssertTrue(row.contains("Picker(\"Routing group\", selection: $group)"), "the row is a Picker over the group")
        XCTAssertTrue(row.contains("ForEach(RoutingGroup.allCases)"), "it offers every group")
        XCTAssertTrue(row.contains(".pickerStyle(.segmented)"), "a segmented row — named choices, not a number (CLAUDE.md, NUMERIC)")
        for hot in ["lastOutputs", "currentTick", "masterLevel", "TimelineView("] {
            XCTAssertFalse(row.contains(hot), "`\(hot)` in the segmented row — Routing's chrome reads nothing hot (10.76.41/50)")
        }
        XCTAssertEqual(code.components(separatedBy: "group = ").count - 1, 1,
                       "COUNTERWEIGHT: nothing but a tap writes the group (one initialiser, no assignment)")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(reason: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// The text inside the braces that open at the first `{` from `head` on (#408 — never a window).
    private func member(_ head: String, in text: String) throws -> String {
        guard let start = text.range(of: head),
              let open = text[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: `\(head)` (#454)")
            throw AnchorMissing(reason: head)
        }
        var depth = 1
        var index = text.index(after: open)
        while index < text.endIndex {
            switch text[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(text[text.index(after: open)..<index]) }
            default: break
            }
            index = text.index(after: index)
        }
        XCTFail("UNBALANCED: `\(head)` never closes (#454)")
        throw AnchorMissing(reason: head)
    }
}
#endif
