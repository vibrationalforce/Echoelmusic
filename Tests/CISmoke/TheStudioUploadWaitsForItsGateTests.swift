// TheStudioUploadWaitsForItsGateTests.swift
// Echoel — 2026-10-20, the session took the CI over. Blocking bundle.
//
// The production lessons of the legacy TestFlight pipeline, carried into the Studio upload
// (ultra-audit 2026-10-20, findings TF-4 · TF-7 · TF-8 · TF-9 · TF-11 · CI-05 · CI-06). Before
// this commit `studio-testflight.yml` archived, uploaded and printed a hard-coded "11.0.0":
//  - it did not wait for the `Echoel Studio` run on its own commit (run 155 of studio.yml and
//    run 8 of the upload started in the same second on f61d7872);
//  - it never asked App Store Connect whether the build arrived or what processing made of it;
//  - its signing job and the legacy one used DIFFERENT concurrency groups, while both revoke
//    every development certificate of the team (fastlane setup_signing);
//  - it checked that the secrets were present, never that they sign in.
//
// WHAT IS PINNED, and why each claim is not the obvious one:
//  1. the anchor: the upload has a gate job and the archive job needs it (without `needs:` the
//     gate is a parallel job whose red changes nothing — the #683 shape one level down).
//  2. the gate reads `Echoel Studio` by CONCLUSION and refuses everything but `success`,
//     including `never-ran` and `timeout`. Absence is refusal, never approval.
//  3. both upload workflows take ONE concurrency group. Pinned as the shared NAME, not as a
//     place: a later move of the group between job and workflow level is legitimate (#364).
//  4. App Store Connect is asked twice: a sign-in BEFORE the step that revokes certificates,
//     and a processing check AFTER the export. ⚠️ The order of the first is the point — a sign-in
//     after `setup_signing` would revoke certificates with a key that cannot sign in.
//  5. the summary carries the version the archive carries, not a literal.
//  6. a failure log is scrubbed of the team ID before it is kept as an artifact. GitHub masks
//     secrets in the job log only, never inside an uploaded file.
//  7. the EARLIER app uploads only when a dispatch types legacy_upload=LEGACY (TF-1): five
//     doors still dispatch testflight.yml, and the lock sits at the destination, not at each door.
//
// ⚠️ HONEST LIMITS. This proves what the workflow SAYS. The gate's jq, the Ruby script's HTTP
// calls and the artifact paths run for the first time on the next upload, not in this bundle.
// Raw file reads: YAML is not Swift, so `SourceText.codeOnly` would mangle it (same reason as
// TheAutoMergeWaitsForTheGatesTests); the needles are shell or Ruby fragments a `#` comment
// does not carry.
//
// ⭐ GRADING (§3). Transcribed in Python against both trees: claims 1, 2, 4, 5 and 6 are red at
// the parent for ONE reason each (the parent has no gate job, no ASC call, a literal version,
// no artifact step) and green here; claim 3 is red at the parent because the two groups differed;
// claim 7 is red at the parent (no legacy_upload input) and green here.
// The premise inside claim 4 (the export step still exists) is green on both — the counterweight.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheStudioUploadWaitsForItsGateTests: XCTestCase {

    private static let upload = ".github/workflows/studio-testflight.yml"
    private static let legacyUpload = ".github/workflows/testflight.yml"

    // MARK: - 1: the gate job exists and the archive waits for it

    func testTheArchiveJobNeedsTheGateJob() throws {
        let yml = try rawFile(Self.upload)
        XCTAssertNotNil(yml.range(of: #"(?m)^  gate:\s*$"#, options: .regularExpression), """
            studio-testflight.yml has no `gate:` job. The upload no longer waits for the \
            Echoel Studio run on its commit; "only bump RELEASE on a green commit" is a sentence again.
            """)
        XCTAssertNotNil(yml.range(of: #"(?m)^    needs: \[gate\]\s*$"#, options: .regularExpression), """
            The archive job does not `needs: [gate]`. A gate that runs beside the archive changes \
            nothing — the upload happens whatever the gate says.
            """)
    }

    // MARK: - 2: the gate reads the Studio run by conclusion and refuses anything else

    func testTheGateRefusesEverythingButASuccessfulStudioRun() throws {
        let yml = try rawFile(Self.upload)
        XCTAssertTrue(yml.contains(#"select(.name == "Echoel Studio")"#)
                      && yml.contains(#"| .conclusion // empty'"#), """
            The gate no longer reads the `Echoel Studio` run by its conclusion.
            """)
        XCTAssertTrue(yml.contains(#"verdict="never-ran""#)
                      && yml.contains(#"if [ "$verdict" != "success" ]; then"#), """
            The gate no longer refuses a run that never appeared, or accepts something other \
            than `success`. A missing gate must stop the upload, never wave it through.
            """)
    }

    // MARK: - 3: one signing lock across both upload workflows

    func testBothUploadsShareOneSigningLock() throws {
        let lock = #"(?m)^\s*group: apple-signing\s*$"#
        let studio = try rawFile(Self.upload)
        let legacy = try rawFile(Self.legacyUpload)
        XCTAssertNotNil(studio.range(of: lock, options: .regularExpression), """
            The Studio upload no longer takes the `apple-signing` group. fastlane setup_signing \
            revokes every development certificate; two signing runs at once revoke each other's.
            """)
        XCTAssertNotNil(legacy.range(of: lock, options: .regularExpression), """
            testflight.yml no longer takes the `apple-signing` group, so a legacy dispatch can \
            again revoke a Studio certificate mid-archive.
            """)
    }

    // MARK: - 4: App Store Connect is asked before signing and after the upload

    func testAppStoreConnectIsAskedBeforeSigningAndAfterTheUpload() throws {
        let yml = try rawFile(Self.upload)
        guard let auth = yml.range(of: "ruby scripts/asc-build-state.rb auth"),
              let signing = yml.range(of: "fastlane ios setup_signing"),
              let export = yml.range(of: "xcodebuild -exportArchive"),
              let wait = yml.range(of: #"ruby scripts/asc-build-state.rb wait "$BUILD" "$VERSION""#)
        else {
            return XCTFail("""
                The upload lost one of: the App Store Connect sign-in, setup_signing, the export, \
                or the processing check after it.
                """)
        }
        XCTAssertLessThan(auth.lowerBound, signing.lowerBound, """
            The sign-in runs after setup_signing: certificates are revoked before anyone knows \
            whether the key can sign in at all.
            """)
        XCTAssertLessThan(export.lowerBound, wait.lowerBound, """
            The processing check runs before the export — it would poll for a build that has not \
            been uploaded yet.
            """)
        let script = try rawFile("scripts/asc-build-state.rb")
        XCTAssertTrue(script.contains("when 'INVALID', 'FAILED'") && script.contains("exit 1"), """
            asc-build-state.rb no longer fails the run on an INVALID or FAILED build.
            """)
    }

    // MARK: - 5: the summary names the version the archive carries

    func testTheSummaryNamesTheArchivedVersion() throws {
        let yml = try rawFile(Self.upload)
        XCTAssertTrue(yml.contains("CFBundleShortVersionString' \"$APP/Info.plist\")\" >> \"$GITHUB_ENV\"")
                      && yml.contains("Uploaded Echoel Studio $VERSION ($BUILD)"), """
            The upload summary no longer reads the version from the archive. A literal there \
            reports a version project.yml no longer carries.
            """)
    }

    // MARK: - 6: a kept failure log carries no team ID

    func testAFailureLogIsScrubbedBeforeItIsKept() throws {
        let yml = try rawFile(Self.upload)
        guard let scrub = yml.range(of: "name: \"Scrub the failure logs\""),
              let keep = yml.range(of: "name: \"Keep the failure logs\"")
        else {
            return XCTFail("The scrub step or the failure-log artifact step is gone.")
        }
        XCTAssertLessThan(scrub.lowerBound, keep.lowerBound, """
            The failure logs are kept before they are scrubbed: the artifact would carry the team ID.
            """)
        XCTAssertTrue(yml.contains("TEAM: ${{ secrets.APPLE_TEAM_ID }}")
                      && yml.contains(#"sed -i '' "s/$TEAM/<team>/g" "$f""#), """
            The scrub step no longer replaces the team ID. Masking reaches the job log, never a file.
            """)
    }

    // MARK: - 7: the earlier app cannot reach the shared record by accident

    /// Five places dispatch testflight.yml without this word (ultra-audit TF-1). The lock sits at
    /// the destination so a sixth door cannot upload either. It does not forbid a legacy upload
    /// (#364) — it makes one a typed decision.
    func testTheEarlierAppUploadsOnlyWhenSomeoneTypesLegacy() throws {
        let legacy = try rawFile(Self.legacyUpload)
        XCTAssertTrue(legacy.contains("github.event.inputs.legacy_upload == 'LEGACY'"), """
            testflight.yml's upload job no longer asks for legacy_upload=LEGACY. deploy-on-tag, \
            trigger-testflight, check-testflight.sh and /testflight-deploy would then upload the \
            earlier app onto the record testers get Echoel Studio from.
            """)
        XCTAssertTrue(legacy.range(of: #"(?m)^      legacy_upload:\s*$"#, options: .regularExpression) != nil
                      && legacy.contains("        default: ''"), """
            The legacy_upload input is gone or no longer defaults to empty. A default of LEGACY \
            would open every door again.
            """)
    }

    // MARK: - raw file access (YAML and Ruby: NO Swift stripper)

    private struct AnchorMissing: Error { let reason: String }

    private func rawFile(_ relativePath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — renamed or moved. \
                Re-anchor this scan; do not let it skip (#454).
                """)
        }
        return try String(contentsOf: path, encoding: .utf8)
    }
}
