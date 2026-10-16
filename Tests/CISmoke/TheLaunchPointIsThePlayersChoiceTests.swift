// TheLaunchPointIsThePlayersChoiceTests.swift
// P3 (founder 2026-10-16, Session on Ableton level): Live's launch quantization. Above the grid a
// switch picks where a launched part, a scene or a Stop lands — the next beat, bar, two bars or
// four bars. Before, `SessionGrid.quantize` was a constant `.bar`, and the copy said "the next
// bar" in five places; the copy now says "the next launch point", the point the switch shows.
//
// WHAT KIND OF GREEN THIS IS (§1):
//   · Claim 1 is END-TO-END on the pure `SessionLaunchPoint.resolved` (every offered value, the
//     default, a retired and an unknown raw value).
//   · Claims 2–3 are SOURCE-TEXT SCANS: every launch call reads the one choice; no session copy
//     still promises "the next bar"; the picker is mounted in the grid's header.
//   · NOT CLAIMED (DEVICE PROBE): that a launch lands on the picked boundary. The engine's
//     quantize maths is pinned elsewhere (`LaneLaunchLatch`); the wiring is what is new.
//     NEEDS-FOUNDER-VERIFY (P3): Session view, pick "2 Bars", launch a part while the piece plays —
//     does it wait for the next two-bar line? ("Beat" is withdrawn, claim 1.)
//
// HONEST GRADING against the parent (§3): the file does not compile there (`SessionLaunchPoint`
// is new), so no assertion has a verdict on the parent. Hand-transcribed: claim 1 is the
// CAPABILITY plus its COUNTERWEIGHT (an unknown value falls back to `.bar`, never reaches the
// engine), claim 2's "no next bar" half is a REGRESSION on the parent (five sites), claim 3 is a
// FORWARD guard. Mutants: no fallback (1) · `.off` offered (1) · one call site keeps `.bar` (2) ·
// a hint still says "next bar" (2) · picker unmounted (3).

import Foundation
import XCTest
// `@testable` IS LOAD-BEARING: `SessionLaunchPoint` is internal.
@testable import Echoelmusic

final class TheLaunchPointIsThePlayersChoiceTests: XCTestCase {

    // MARK: 1 — the stored choice resolves to an offered point, bar by default

    func testTheStoredChoiceResolvesToAnOfferedPoint() {
        XCTAssertEqual(SessionLaunchPoint.offered, [.bar, .twoBar, .fourBar])
        XCTAssertEqual(SessionLaunchPoint.resolved(LaunchQuantize.beat.rawValue), .bar, """
            "Beat" is withdrawn (finesse review 2026-10-16): a MIDI part launched mid-bar plays on the \
            bar grid with its first beat skipped, and a recorded take lands a beat off. A stored \
            "beat" must launch on the bar until a sub-bar launch phase exists.
            """)
        for point in SessionLaunchPoint.offered {
            XCTAssertEqual(SessionLaunchPoint.resolved(point.rawValue), point)
        }
        XCTAssertEqual(SessionLaunchPoint.resolved(nil), .bar, "a fresh install launches on the bar, as before")
        XCTAssertEqual(SessionLaunchPoint.resolved(LaunchQuantize.off.rawValue), .bar, """
            An unquantized launch is not offered — it would start a part mid-step in the \
            lane-override model — so a stored "off" must never reach the engine.
            """)
        XCTAssertEqual(SessionLaunchPoint.resolved(LaunchQuantize.sixteenth.rawValue), .bar)
        XCTAssertEqual(SessionLaunchPoint.resolved("eightBar"), .bar, "an unknown raw value falls back")
        XCTAssertFalse(SessionLaunchPoint.offered.contains { $0.ticks == nil }, "every offered point has a grid")
    }

    // MARK: 2 — every launch reads the one choice, and no copy still promises the bar

    func testEveryLaunchReadsTheOneChoiceAndTheCopySaysLaunchPoint() throws {
        let view = try source("Sources/Echoelmusic/Studio/SessionLaunchView.swift")
        XCTAssertTrue(view.contains("static var quantize: LaunchQuantize { SessionLaunchPoint.current }"),
                      "the grid's one quantize IS the player's choice (#416)")
        for call in ["player.launchRegion(regionID, quantize: SessionGrid.quantize)",
                     "player.stopLaunched(laneID: track.id, quantize: SessionGrid.quantize)",
                     "player.launchScene(parts, quantize: SessionGrid.quantize)",
                     "player.stopAllLaunched(quantize: SessionGrid.quantize)"] {
            XCTAssertEqual(view.components(separatedBy: call).count - 1, 1, "`\(call)` reads the choice once")
        }
        XCTAssertFalse(view.contains("quantize: .bar)"), "a launch call fixed to the bar again")
        let raw = try rawSource("Sources/Echoelmusic/Studio/SessionLaunchView.swift")
        for line in raw.components(separatedBy: "\n") where line.contains("\"") && !line.contains("//") {
            XCTAssertFalse(line.contains("next bar"), """
                A Session sentence still promises "the next bar" while the launch point is the \
                player's choice: \(line.trimmingCharacters(in: .whitespaces))
                """)
        }
    }

    // MARK: 3 — the switch sits in the grid's header, in its own leaf

    func testTheSwitchIsMountedInTheGridsHeader() throws {
        let view = try source("Sources/Echoelmusic/Studio/SessionLaunchView.swift")
        XCTAssertEqual(view.components(separatedBy: "SessionLaunchPointPicker()").count - 1, 1)
        guard let caption = view.range(of: ".fixedSize(horizontal: false, vertical: true)\n                SessionLaunchPointPicker()"),
              let grid = view.range(of: "ScrollView(.horizontal, showsIndicators: false) {") else {
            return XCTFail("ANCHOR MISSING: the caption, the switch or the grid (#408)")
        }
        XCTAssertLessThan(caption.lowerBound, grid.lowerBound, "the switch stands above the grid it governs")
        let picker = try source("Sources/Echoelmusic/Studio/SessionLaunchPoint.swift")
        XCTAssertTrue(picker.contains("@AppStorage(SessionLaunchPoint.key)"), "one writer, the switch")
        XCTAssertTrue(picker.contains("ForEach(SessionLaunchPoint.offered, id: \\.self)"), "it offers exactly the offered points")
        XCTAssertTrue(picker.contains(".pickerStyle(.segmented)"))
    }

    // MARK: helpers

    private struct Unreadable: Error {}

    private func rawSource(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw Unreadable()
        }
        return text
    }

    private func source(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try rawSource(relativePath))
    }
}
