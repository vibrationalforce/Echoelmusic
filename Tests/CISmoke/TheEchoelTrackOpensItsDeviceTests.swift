// TheEchoelTrackOpensItsDeviceTests.swift
// Echoel — WA4 critical path 9: Echoel as a Device on its track.
//
// WHAT THIS PINS. The Workstation's track inspector named the Echoel track's device ("Echoel
// instrument") and offered no way to reach it. The instrument's editor is the Sound plate
// (patch, presets, tone). The door is ONE button on the Echoel track's device row that posts
// the existing chrome door — the inspector is a leaf of the Workstation plate and owns none of
// the Studio's state, which is the shape `.echoelChromeDoor` exists for. No new modal.
//
// 1. SOURCE: the button sits inside `if controls.role == .echoelInstrument` (a rack voice or an
//    audio player has no such editor) and AFTER the combined device element, not inside it
//    (#621 — a control inside a merged element loses its own focus).
// 2. SOURCE: producer and receiver move together — exactly one poster of `"sound"` in
//    `Sources/`, and the Studio's receiver turns it into `activeMenu = .sound`.
// 3. COUNTERWEIGHT: the inspector adds no presentation modifier (the black-screen budget).
//
// Grading (§0, no Swift toolchain in a web session): all claims driven in Python against this
// tree. On the parent (e0ba07564) claims 1–2 are red by ABSENCE of the button and the case —
// ONE absence (#486); they are FORWARD guards. Claim 3 is a COUNTERWEIGHT, green on both.
// NOT covered: that tapping Open lands on the Sound plate on a device — a device probe.
// NEEDS-FOUNDER-VERIFY: Workstation → tap the Echoel track → Open → the Sound plate shows;
// the Workstation chip returns to the song.

import Foundation
import XCTest

final class TheEchoelTrackOpensItsDeviceTests: XCTestCase {

    private static let inspectorPath = "Sources/Echoelmusic/Studio/TrackInspectorView.swift"
    private static let studioPath = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"

    // MARK: 1 — only on the Echoel track, outside the combined element

    func testTheDeviceDoorIsOnTheEchoelTrackOnly() throws {
        let inspector = try code(Self.inspectorPath)
        guard let combine = inspector.range(of: ".accessibilityElement(children: .combine)"),
              let gate = inspector.range(of: "if controls.role == .echoelInstrument {"),
              let door = inspector.range(of: "openDeviceButton", range: gate.upperBound..<inspector.endIndex)
        else {
            return XCTFail("ANCHOR MISSING: the device row, its role gate or the door (#454)")
        }
        XCTAssertLessThan(combine.lowerBound, gate.lowerBound,
                          "the door must follow the combined device element, not sit inside it (#621)")
        XCTAssertLessThan(inspector.distance(from: gate.upperBound, to: door.lowerBound), 200,
                          "the door must be the gate's content, not a later use of the name")
        XCTAssertEqual(inspector.components(separatedBy: "openDeviceButton").count - 1, 2,
                       "one declaration, one use — inside the Echoel gate")
    }

    // MARK: 2 — producer and receiver together

    func testTheDoorHasOneProducerAndItsReceiver() throws {
        let poster = "NotificationCenter.default.post(name: .echoelChromeDoor, object: \"sound\")"
        let root = repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            return XCTFail("cannot enumerate Sources/Echoelmusic — a scan that saw nothing is not a pass")
        }
        var posters: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if SourceText.codeOnly(text).contains(poster) { posters.append(relative) }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        XCTAssertEqual(posters, ["Studio/TrackInspectorView.swift"],
                       "the device door is the one producer of the \"sound\" chrome door")

        let studio = try code(Self.studioPath)
        guard let receiverStart = studio.range(of: "publisher(for: .echoelChromeDoor)) { note in"),
              let receiverEnd = studio.range(of: "default: break",
                                             range: receiverStart.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: the chrome-door receiver (#454)")
        }
        let receiver = studio[receiverStart.upperBound..<receiverEnd.lowerBound]
        XCTAssertTrue(receiver.contains("case \"sound\":") && receiver.contains("activeMenu = .sound"),
                      "a posted door with no receiver case is a button that does nothing (#164/#227)")
    }

    // MARK: 3 — counterweight: no new modal

    func testTheInspectorAddsNoPresentation() throws {
        let inspector = try code(Self.inspectorPath)
        for modifier in [".sheet(", ".fullScreenCover(", ".alert(", ".confirmationDialog(", ".popover("] {
            XCTAssertFalse(inspector.contains(modifier),
                           "the inspector presents `\(modifier)` — the Studio's modal budget has no headroom")
        }
    }

    // MARK: helpers

    private func code(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: repoRoot().appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }
}
