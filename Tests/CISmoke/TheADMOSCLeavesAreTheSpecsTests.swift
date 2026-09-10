// TheADMOSCLeavesAreTheSpecsTests.swift
// Echoel — #1210. The immersive object was addressed in a dialect no renderer speaks.
//
// THE DEFECT. Three formatters (`ADMOSCSender.admMessages`, `MusicMediaMap.admMessages(forMusic:)`,
// `SpatialSceneOSC`'s polar and Cartesian branches) emitted `/adm/obj/{n}/position/azimuth`,
// `/position/elevation`, `/position/distance` and `/position/x|y|z`. The ADM-OSC v1.0 address
// table (github.com/immersive-audio-live/ADM-OSC, docs/adm-osc.bs, fetched 2026-09-10) has NO
// `position` segment: the object leaves are `/azim`, `/elev`, `/dist`, `/aed`, `/x`, `/y`, `/z`,
// `/xyz`, `/gain`. A conforming receiver (the repo's reference Python receiver included) logs
// "unrecognized ADM address" and moves nothing. The identity line, README, the website and
// `ContentPipeline/CLAIMS.md` all sell "bio-reactive object source over ADM-OSC"; on the wire
// that was false for as long as the sender existed. Ranges, sign convention (positive azimuth
// = left) and the 1-based object index were right all along — only the leaf names were wrong.
//
// WHY THE GOLDEN TESTS DID NOT CATCH IT. Four test files pinned the exact wrong strings
// (`ADMOSCAbsenceTests`, `ADMOSCSenderTests`, `MusicMediaMappingTests`, `SpatialSceneOSCTests`):
// a golden file proves the formatter is STABLE, never that it is RIGHT. This guard is the
// missing half — it pins the leaf set against the standard, not against yesterday's output.
//
// ⚠️ HONEST GRADING — TRANSCRIBED (Tests/CISmoke/CLAUDE.md §0) against the parent tree
// (`57dd7b7`, before #1210) and this tree: claims 1 and 3 are RED on the parent (the parent's
// formatters write `/position/`, and its `ADMOSCSender` has no `/azim` literal) and GREEN here;
// claim 2 is a source scan over `Sync/` that is red on the parent for the same reason. **Zero
// counterweight regressions** — claim 3 is the END-TO-END counterweight (#367): a formatter that
// emitted nothing at all would pass the negative scans, so a fully measured frame must still
// drive all three polar leaves.
//
// ⚠️ THE LIMIT. That a real renderer MOVES on these addresses needs a renderer; the address
// table is cited from the spec, the reception is not proved here. The `NEEDS-FOUNDER-VERIFY`
// for that lives in `ADMOSCSender.swift`'s header.

#if canImport(Network)
import Foundation
import XCTest
@testable import Echoelmusic

final class TheADMOSCLeavesAreTheSpecsTests: XCTestCase {

    private static let syncDir = "Sources/Echoelmusic/Sync"
    private static let sender = "Sources/Echoelmusic/Sync/ADMOSCSender.swift"

    // MARK: - claim 1 — the sender's code names the spec leaves

    func testTheSenderEmitsTheSpecLeafNames() throws {
        let code = try source(Self.sender)
        for leaf in ["/azim", "/elev", "/dist", "/gain"] {
            XCTAssertTrue(code.contains("\(leaf)\""), """
                `ADMOSCSender.swift` no longer writes the ADM-OSC leaf `\(leaf)`. The spec's \
                object table (docs/adm-osc.bs) names exactly /azim /elev /dist /aed /x /y /z /xyz \
                /gain — a renamed leaf is a message every conforming renderer drops on the floor.
                """)
        }
    }

    // MARK: - claim 2 — no formatter under Sync/ uses the phantom `position` segment

    func testNoSyncFormatterWritesThePhantomPositionSegment() throws {
        var hits: [String] = []
        let root = try repoRoot()
        let dir = root.appendingPathComponent(Self.syncDir)
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".swift") }.sorted()
        XCTAssertFalse(names.isEmpty, "no Swift files under \(Self.syncDir) — the scan is empty")
        for name in names {
            let code = try source("\(Self.syncDir)/\(name)")
            if code.contains("/position/") { hits.append(name) }
        }
        XCTAssertTrue(hits.isEmpty, """
            `/position/` is back in \(hits.joined(separator: ", ")). That segment exists in no \
            version of ADM-OSC (#1210); the object leaves are /azim /elev /dist and /x /y /z, \
            directly under /adm/obj/{n}. Rename the leaf and move the golden test with it.
            """)
    }

    // MARK: - claim 3 (COUNTERWEIGHT, END-TO-END) — a measured body still drives all three leaves

    func testAFullyMeasuredFrameDrivesTheThreeSpecLeaves() {
        let f = BioSampleFrame(timestamp: 0, heartRateBPM: 62, hrvNormalized: 0.5,
                               breathRate: 12, breathPhase: 0.5, coherence: 0.7,
                               motionEnergy: 0, source: .cameraPPG)
        let addresses = ADMOSCSender.admMessages(for: f, object: 1).map { $0.0 }
        XCTAssertEqual(addresses.filter { !$0.hasSuffix("/gain") },
                       ["/adm/obj/1/azim", "/adm/obj/1/elev", "/adm/obj/1/dist"],
                       "a measured body must still drive azimuth, elevation and distance — "
                       + "under their spec names, in the spec order")
        XCTAssertTrue(addresses.allSatisfy { $0.hasPrefix("/adm/obj/1/") },
                      "an address left the /adm/obj/{n}/ namespace: \(addresses)")
    }

    // MARK: - source access (the #453 stripper; a FAILURE when a named file moved, #454)

    private struct AnchorMissing: Error { let reason: String }

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

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor, do not skip")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
#endif
