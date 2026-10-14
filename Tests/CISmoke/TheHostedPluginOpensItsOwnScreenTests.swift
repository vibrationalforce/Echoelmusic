//
//  TheHostedPluginOpensItsOwnScreenTests.swift
//  Production level H3 (founder 2026-10-13: AUv3 instruments at production level) — "Open plugin"
//  on a rack track's Device page shows the chosen Audio Unit's OWN screen.
//
//  KIND: SOURCE-TEXT SCAN (Tests/CISmoke/CLAUDE.md §1). The members are a `View` and a
//  `@MainActor` host that needs a loaded out-of-process unit, which no test bundle can make.
//  What it pins:
//  · claim 1 — the host asks the LOADED unit for its controller (`requestViewController`) only
//    inside `requestView(forSlot:done:)`, answers false for a slot with no unit, and crosses the
//    system's completion thread in a box onto the main actor; `live` is set once, in `init`.
//  · claim 2 — the row asks on the TAP only (`open(`), finds the slot through the one lookup
//    (`MultiRollFanout.slot`), keeps the controller only in the sheet's item, and takes the child
//    out again in `dismantleUIViewController`.
//  · claim 3 (counterweight) — the host is still the only file that loads a unit, and the row
//    still never does.
//  DEVICE PROBE, OPEN: the NEEDS-FOUNDER-VERIFY H3 ask at `TrackPluginRow`.
//
//  GRADING against the parent tree (#433/#464): `requestView`, `live` and `PluginScreenHost` do
//  not exist there, so claims 1–2 are red by ONE absence (#486) — forward guards. Claim 3 is a
//  COUNTERWEIGHT, green on both trees. Transcribed in Python against the worktree.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest

final class TheHostedPluginOpensItsOwnScreenTests: XCTestCase {

    private static let host = "Sources/Echoelmusic/Audio/HostedInstrumentHost.swift"
    private static let row = "Sources/Echoelmusic/Studio/TrackPluginRow.swift"

    private func code(_ path: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(path) not on disk — this run has no source tree")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    // MARK: 1 — the host asks the loaded unit, once, and hops to the main actor

    func testTheHostAsksTheLoadedUnitForItsScreen() throws {
        let host = try code(Self.host)
        XCTAssertEqual(occurrences(of: ".requestViewController", in: host), 1,
                       "the plugin's screen is asked for in exactly one place")
        guard let request = host.range(of: "func requestView(forSlot slot: Int,"),
              let ask = host.range(of: ".requestViewController") else {
            return XCTFail("the host no longer offers `requestView(forSlot:done:)`")
        }
        XCTAssertLessThan(request.lowerBound, ask.lowerBound, "the request lives inside `requestView`")
        XCTAssertTrue(host.contains("guard let unit = hosted[slot]?.unit else { return false }"),
                      "a slot with no loaded unit must answer false at once — never call into nothing")
        XCTAssertTrue(host.contains("Task { @MainActor in done(box.controller) }"),
                      "the controller arrives off the main thread and must be handed over on the main actor")
        XCTAssertEqual(occurrences(of: "Self.live = self", in: host), 1, "`live` is set once, in init")
    }

    // MARK: 2 — the row asks on the tap, holds the controller only while shown

    func testTheRowAsksOnTheTapAndLetsGoOnClose() throws {
        let row = try code(Self.row)
        XCTAssertEqual(occurrences(of: ".requestView(forSlot:", in: row), 1, "asked in one place")
        guard let open = row.range(of: "private func open(_ component: DeviceInsert.PluginComponent)"),
              let ask = row.range(of: ".requestView(forSlot:") else {
            return XCTFail("the row no longer asks for the screen inside `open(_:)`")
        }
        XCTAssertLessThan(open.lowerBound, ask.lowerBound, "asked on the tap, never in `body`")
        XCTAssertTrue(row.contains("Button(\"Open plugin\") { open(current) }"))
        XCTAssertTrue(row.contains("MultiRollFanout.slot(forLaneID: laneID, in: document"),
                      "the slot comes from the one lane→slot lookup")
        XCTAssertTrue(row.contains(".sheet(item: $window, onDismiss: keepSettings)"), "the sheet's item is the only holder")
        XCTAssertTrue(row.contains("static func dismantleUIViewController"),
                      "closing must take the plugin's view out of the container")
        XCTAssertTrue(row.contains("child.removeFromParent()"))
    }

    // MARK: 2b — the screen and the kept settings belong to the plugin the person means

    /// Night sweep 2026-10-14 (B3): while stopped, a pick does not reach the host, so the slot
    /// can still hold the PREVIOUS plugin. "Open plugin" then showed that one under the new
    /// name, and closing the window kept its settings under the new plugin.
    func testTheScreenAndTheSettingsBelongToThePluginTheRowNames() throws {
        let host = try code(Self.host)
        let row = try code(Self.row)
        for head in ["func requestView(forSlot slot: Int, expecting component: DeviceInsert.PluginComponent,",
                     "func captureState(forSlot slot: Int, expecting component: DeviceInsert.PluginComponent) -> Data? {"] {
            guard let start = host.range(of: head) else { return XCTFail("ANCHOR MISSING: \(head)") }
            let body = host[start.upperBound...].prefix(260)
            XCTAssertTrue(body.contains("hosted[slot]?.component == component"),
                          "the host answers only for the plugin the caller names: \(head)")
        }
        XCTAssertTrue(row.contains("host.requestView(forSlot: slot, expecting: component, done:"))
        XCTAssertTrue(row.contains("host.captureState(forSlot: slot, expecting: component)"))
        XCTAssertTrue(row.contains("shownComponent = component"),
                      "the window remembers which plugin it shows, for the settings kept on close")
    }

    // MARK: 3 — counterweight: only the host loads a unit

    func testOnlyTheHostLoadsAUnit() throws {
        let host = try code(Self.host)
        let row = try code(Self.row)
        XCTAssertTrue(host.contains("AVAudioUnit.instantiate(with: description"))
        for loader in ["instantiate(", "AVAudioUnit(", "attachAudioUnit("] {
            XCTAssertFalse(row.contains(loader), "the row never loads a unit: found \(loader)")
        }
    }
}
