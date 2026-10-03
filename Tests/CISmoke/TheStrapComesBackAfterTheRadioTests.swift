// TheStrapComesBackAfterTheRadioTests.swift
// Echoel — audit 2026-10-03, slice hpp-3 ("Bluetooth aus und wieder an: der Gurt kommt zurück").
//
// WHAT IT GUARDS. When the Bluetooth radio leaves `.poweredOn`, iOS invalidates every peripheral
// it handed out, and `didDisconnectPeripheral` is not guaranteed to follow. The publisher only
// set `.bluetoothUnavailable` and kept its `peripheral`, and `handleDiscovered` refuses any find
// while `peripheral != nil` — so after the radio came back the fresh scan saw the strap and threw
// it away: "No strap" until the player stopped and restarted the source by hand. Now every
// non-poweredOn state first drops the link (`releaseLinkLostWithTheRadio`) and keeps
// `isPublishing`, so `.poweredOn` re-scans and reconnects on its own. A trailing disconnect no
// longer overwrites `.bluetoothUnavailable` with `.disconnected`.
//
// §1 LIMIT: SOURCE-TEXT SCANS — the publisher is a CoreBluetooth delegate; none of this runs
// without a radio. Whether a real strap reconnects after Control Centre → Bluetooth off/on is a
// DEVICE PROBE, open.
//
// §3 HONEST GRADING against the parent (52a986510): the file names no new Swift symbol, so it
// compiles there. Claims 1, 2 and 4 are REGRESSIONS (red for their named reason — no release on
// radio loss, no release member, the trailing disconnect overwrote the reason); claim 2 is red
// there by ANCHOR ABSENCE of the new member, which is the same missing feature as claim 1 (#486).
// Claim 3 is a COUNTERWEIGHT, green on both trees: the duplicate-find guard that made the
// release necessary is still there, and `.poweredOn` still scans. Stripper
// `SourceText.codeOnly`: PROPHYLAKTISCH (0 of 4 verdicts flip).

import Foundation
import XCTest

final class TheStrapComesBackAfterTheRadioTests: XCTestCase {

    private static let strap = "Sources/Echoelmusic/Bio/PolarH10BioPublisher.swift"

    // MARK: - Claim 1 — every non-poweredOn state releases the link before it reports

    func testEveryRadioLossReleasesTheLink() throws {
        let handler = try body("private func handleCentralStateChange(_ central: CBCentralManager) {")
        XCTAssertEqual(occurrences(of: "releaseLinkLostWithTheRadio()\n            state = .bluetoothUnavailable", in: handler), 2,
                       "both the named non-poweredOn states and `@unknown default` must drop the link, then report")
        XCTAssertEqual(occurrences(of: "state = .bluetoothUnavailable", in: handler), 2,
                       "no third path reports the radio loss without releasing")
    }

    // MARK: - Claim 2 — the release drops what blocks a rediscovery, and keeps the user's wish

    func testTheReleaseDropsTheStrapButKeepsPublishing() throws {
        let release = try body("private func releaseLinkLostWithTheRadio() {")
        for line in ["peripheral = nil", "publishTask = nil", "scanWatchdog = nil", "latestHR = 0",
                     "rrIntervals.removeAll()", "beatGate = RRIntervalHygiene.Gate()", "connectedDeviceName = \"\""] {
            XCTAssertTrue(release.contains(line), "the release must do `\(line)` like `stop()` does")
        }
        XCTAssertFalse(release.contains("isPublishing"),
                       "the user still wants a signal — `.poweredOn` re-scans only while publishing")
        XCTAssertFalse(release.contains("cancelPeripheralConnection"),
                       "there is no connection to cancel on a radio that is off")
    }

    // MARK: - Claim 3 — COUNTERWEIGHT: why the release is needed, and who re-scans

    func testTheDuplicateGuardAndTheRescanStillExist() throws {
        let discovered = try body("private func handleDiscovered(_ peripheral: CBPeripheral, named name: String, on central: CBCentralManager) {")
        XCTAssertTrue(discovered.contains("guard self.peripheral == nil else { return }"),
                      "the duplicate-find guard is what made a kept strap unfindable")
        let handler = try body("private func handleCentralStateChange(_ central: CBCentralManager) {")
        XCTAssertTrue(handler.contains("central.scanForPeripherals(withServices: [Self.hrServiceUUID])"),
                      "`.poweredOn` is the re-scan the release relies on")
    }

    // MARK: - Claim 4 — a trailing disconnect keeps the reason on screen

    func testATrailingDisconnectKeepsTheRadioReason() throws {
        let code = try source(Self.strap)
        XCTAssertFalse(code.contains("self.state = self.isPublishing ? .disconnected : .idle"),
                       "the unconditional ternary overwrote `.bluetoothUnavailable` with `.disconnected`")
        XCTAssertTrue(code.contains("} else if self.state != .bluetoothUnavailable {"),
                      "the disconnect handler must leave the radio reason in place")
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func body(_ head: String) throws -> String {
        try functionBody(head, in: try source(Self.strap))
    }

    private func functionBody(_ head: String, in code: String) throws -> String {
        guard let start = code.range(of: head) else {
            throw AnchorMissing(reason: "`\(head)` is gone")
        }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            let c = code[index]
            if c == "{" { depth += 1 }
            if c == "}" { depth -= 1; if depth == 0 { return String(code[start.lowerBound...index]) } }
            index = code.index(after: index)
        }
        throw AnchorMissing(reason: "unbalanced braces after `\(head)`")
    }

    private struct AnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }
}
