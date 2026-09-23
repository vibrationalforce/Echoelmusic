// TheMasteringMetersRunWhileAnyReaderIsOnScreenTests.swift
// Echoel — S4a (founder 2026-09-23, "all tasks"): the expensive mastering meters (true peak +
// EBU R128) run while ANY reader is on screen, and stop when the last one leaves.
//
// WHY. The gate was one Bool that `MasterLoudnessGrid` flipped on appear/disappear. S4 gives the
// oscilloscope a door, and its peak label reads one of the gated meters — so with the old Bool,
// closing the scope beside an open Master panel would have frozen the panel's numbers (the grid's
// own note predicted it), and opening the scope alone would have shown a frozen peak.
//
// WHAT KIND OF GUARD THIS IS (§1): claims 1–2 are END-TO-END BEHAVIOUR on the shipped pure type
// `DetailedMeteringClaims`; claims 3–6 are SOURCE-TEXT SCANS. Whether the numbers MOVE on the
// device is a DEVICE PROBE and stays open.
//
// HONEST GRADING (§3): this file does not compile against the parent — it names
// `DetailedMeteringClaims`, which this commit creates. No assertion has a verdict there.
// Transcribed: claims 1, 2, 4 and 6 are FORWARD; claim 3's `setDetailedMetering(` = 0 half is a
// REGRESSION (the parent had two callers); claim 5 is a COUNTERWEIGHT (the scope never reset
// anything on either tree).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheMasteringMetersRunWhileAnyReaderIsOnScreenTests: XCTestCase {

    private static let engine = "Sources/Echoelmusic/Audio/AudioEngine.swift"
    private static let scope = "Sources/Echoelmusic/Studio/AnalysisScopeView.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"

    /// 1. A second reader leaving does not stop the first.
    func testASecondReaderLeavingDoesNotStopTheFirst() {
        var claims = DetailedMeteringClaims()
        XCTAssertFalse(claims.gateOpen, "the meters start OFF")
        XCTAssertTrue(claims.claim(.masterPanel))
        XCTAssertTrue(claims.claim(.scope))
        XCTAssertTrue(claims.release(.scope), "the Master panel is still on screen")
        XCTAssertFalse(claims.release(.masterPanel), "the last reader left — the meters stop")
    }

    /// 2. A repeated appear cannot unbalance the gate (the #299 lesson), and releasing an owner
    /// that holds nothing is harmless.
    func testARepeatedClaimCannotUnbalanceTheGate() {
        var claims = DetailedMeteringClaims()
        claims.claim(.scope)
        claims.claim(.scope)
        XCTAssertFalse(claims.release(.scope), "two appears are one claim, so one disappear ends it")
        XCTAssertFalse(claims.release(.scope))
        XCTAssertFalse(claims.release(.masterPanel))
        XCTAssertTrue(claims.owners.isEmpty)
    }

    /// 3. One writer of the gate; the old Bool setter is gone everywhere.
    func testTheGateHasExactlyOneWriter() throws {
        let code = SourceText.codeOnly(try rawText(Self.engine))
        XCTAssertEqual(occurrences(of: "_detailedMetering.pointee =", in: code), 1,
                       "the gate must have ONE writer — `applyDetailedMeteringGate`")
        XCTAssertEqual(try filesUnderSources(containing: "setDetailedMetering("), [],
                       "the single-Bool setter is back; two readers would fight over it again")
    }

    /// 4. Every reader that claims releases the SAME owner in the same file, and there are at
    /// least the two known readers.
    func testEveryClaimIsReleasedBySameReader() throws {
        let claimers = try filesUnderSources(containing: "claimDetailedMetering(.")
        XCTAssertGreaterThanOrEqual(claimers.count, 2, "the Master panel and the scope both claim")
        for file in claimers {
            let code = SourceText.codeOnly(try rawText("\(Self.sourcesRoot)/\(file)"))
            for owner in DetailedMeteringOwner.allCases {
                let name = "\(owner)"
                let claimed = code.contains("claimDetailedMetering(.\(name))")
                let released = code.contains("releaseDetailedMetering(.\(name))")
                XCTAssertEqual(claimed, released,
                               "\(file) claims `.\(name)` without releasing it (or the reverse) — the meters would run forever")
            }
        }
    }

    /// 5. The scope never resets the meters: that would wipe the Master panel's integration
    /// while both are on screen.
    func testTheScopeNeverResetsTheMastering() throws {
        let code = SourceText.codeOnly(try rawText(Self.scope))
        XCTAssertFalse(code.contains("resetMastering("))
        XCTAssertTrue(code.contains("claimDetailedMetering(.scope)"), "counterweight: the scope claims")
    }

    /// 6. Opening a CLOSED gate requests a reset first (no stale peak); an open gate is never
    /// reset from here.
    func testOpeningAClosedGateResetsTheHeldValues() throws {
        let code = SourceText.codeOnly(try rawText(Self.engine))
        guard let start = code.range(of: "func applyDetailedMeteringGate("),
              let end = code.range(of: "\n    }", range: start.upperBound..<code.endIndex)
        else { return XCTFail("`applyDetailedMeteringGate` moved — re-anchor this claim") }
        let body = String(code[start.upperBound..<end.lowerBound])
        let reset = try XCTUnwrap(body.range(of: "if open && !_detailedMetering.pointee { _resetMeters.pointee = true }"))
        let write = try XCTUnwrap(body.range(of: "_detailedMetering.pointee = open"))
        XCTAssertLessThan(reset.lowerBound, write.lowerBound, "the reset must be requested before the gate opens")
    }

    // MARK: - Helpers

    private func occurrences(of needle: String, in text: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        var count = 0
        var index = text.startIndex
        while let found = text.range(of: needle, range: index..<text.endIndex) {
            count += 1
            index = found.upperBound
        }
        return count
    }

    private func filesUnderSources(containing needle: String) throws -> [String] {
        let root = try repoRoot().appendingPathComponent(Self.sourcesRoot)
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw XCTSkip("\(Self.sourcesRoot) is not present — this guard inspects source text (#454)")
        }
        // #1240: the tree exists, so a walk that cannot start is a red, never a skip.
        guard let walker = FileManager.default.enumerator(atPath: root.path) else {
            XCTFail("cannot enumerate \(Self.sourcesRoot) — refusing to report a green it did not earn")
            return []
        }
        var hits: [String] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let text = try? String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            if SourceText.codeOnly(text).contains(needle) { hits.append(relative) }
        }
        return hits.sorted()
    }

    private func rawText(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(relativePath) is not present — this guard inspects source text (#454)")
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    private func repoRoot() throws -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
