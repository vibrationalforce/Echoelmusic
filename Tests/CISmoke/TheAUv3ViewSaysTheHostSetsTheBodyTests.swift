// TheAUv3ViewSaysTheHostSetsTheBodyTests.swift
// Echoel — interface audit 2026-09-30, gap check: "Das AUv3-Plugin hat keinen Körper. Sein
// 'Heart Rate' ist ein Host-Parameter mit Startwert 0,5. Kein Text darf 'bio-reaktiv im Host'
// sagen." Claim surfaces are the class this repo has paid for most (#158/#192 AUv3 on the
// website, #184 twelve claims in the store text).
//
// WHAT IT GUARDS. The plug-in view's subtitle read "Bio-Reactive Instrument" and its first
// section "Bio-Reactive"; the parameter tree's first group was DISPLAYED as "Bio-Reactive" in
// every host's automation menu. All true of the engine, none true of the situation: the
// extension has no body source (measured: no HealthKit, camera, `BioSampleFrame` or bus in
// `Sources/EchoelmusicAUv3/`), and the four values start at 0.5 and move only when the host
// moves them. The sentence now says who sets the body; the section and the group say what
// the values are. The IDENTIFIER `bio` is unchanged — hosts and saved automation bind by
// identifier and address, and renaming it would orphan every existing project.
//
// §1 LIMIT: SOURCE-TEXT SCAN, all claims. Nothing here instantiates the AU or renders the
// view in a host; AUM is the founder's probe. What the scans carry: the sentence exists, the
// bare claim is gone, the identifier survived the rename.
//
// §3 HONEST GRADING, transcribed in Python against the parent (d03259749) and this tree:
// claim 1's two assertions and claim 2's display-name assertion are the DECISION, RED on the
// parent (one decision, #486); claim 2's identifier assertion and claim 3 are COUNTERWEIGHTS,
// green on both trees. ZERO regressions claimed.

import Foundation
import XCTest

final class TheAUv3ViewSaysTheHostSetsTheBodyTests: XCTestCase {

    private static let view = "Sources/EchoelmusicAUv3/AudioUnitViewController.swift"
    private static let unit = "Sources/EchoelmusicAUv3/EchoelmusicAudioUnit.swift"

    // MARK: - claim 1 — the view says who sets the body, and drops the bare claim

    func testTheSubtitleSaysTheHostSetsTheBodyValues() throws {
        let code = try source(Self.view)
        XCTAssertTrue(code.contains("the host sets the body values"), """
            The plug-in subtitle no longer says who sets the body. Inside a host there is no \
            pulse, no breath, no camera — the four body values are host parameters at 0.5 until \
            the host moves them. A subtitle that only says "bio-reactive" claims a body the \
            plug-in cannot have (gap check, interface audit 2026-09-30).
            """)
        XCTAssertFalse(code.contains("Text(\"Bio-Reactive Instrument\")") || code.contains("parameterSection(\"Bio-Reactive\")"), """
            The bare "Bio-Reactive" claim is back in the plug-in view — as the subtitle or as \
            the section title. It is true of the ENGINE and false of the SITUATION; say what the \
            values are ("Body values (from the host)") and who sets them.
            """)
    }

    // MARK: - claim 2 — the host-visible group name changed, the identifier did not

    func testTheParameterGroupIsNamedForWhatItIsAndKeepsItsIdentifier() throws {
        let code = try source(Self.unit)
        XCTAssertFalse(code.contains("name: \"Bio-Reactive\""), """
            The parameter tree's first group is displayed as "Bio-Reactive" again — that is the \
            name every host shows in its automation menu, i.e. the claim on the surface the \
            player automates from. Display it as what it is: body VALUES the host sets.
            """)
        XCTAssertTrue(code.contains("withIdentifier: \"bio\""), """
            The group identifier `bio` changed. Hosts and saved automation bind by identifier \
            and address; renaming it orphans every project that automated these parameters. \
            Rename the DISPLAY name freely, never the identifier.
            """)
    }

    // MARK: - claim 3 (COUNTERWEIGHT, #343) — the premise: the extension still has no body source

    /// If a body source ever reaches the extension, the subtitle becomes a LIE in the other
    /// direction and this file must be rewritten with it (#456). The scan is over the whole
    /// extension directory, comment-stripped, for the producers the app uses.
    func testTheExtensionStillHasNoBodySource() throws {
        let root = try repoRoot()
        let dir = root.appendingPathComponent("Sources/EchoelmusicAUv3")
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".swift") }
        XCTAssertFalse(files.isEmpty, "ANCHOR: Sources/EchoelmusicAUv3 has no Swift files — re-anchor")
        var hits: [String] = []
        for f in files {
            let code = try source("Sources/EchoelmusicAUv3/\(f)")
            for needle in ["HKHealthStore", "CameraRPPGBioPublisher", "BioSampleFrame", "EngineBus", "AVCaptureSession"]
            where code.contains(needle) {
                hits.append("\(f): \(needle)")
            }
        }
        XCTAssertTrue(hits.isEmpty, """
            The extension now reaches a body source (\(hits)). Then "the host sets the body \
            values" is no longer the whole truth — rewrite the subtitle and this guard in the \
            same commit, and read ContentPipeline/CLAIMS.md before any caption says so.
            """)
    }

    // MARK: - source access

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

    /// Comment-stripped source (#453 — one stripper for the whole bundle). A SKIP without a
    /// checkout, a FAILURE when a named file moved (#454: a skip passes CI).
    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
