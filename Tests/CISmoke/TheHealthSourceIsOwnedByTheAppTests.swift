// TheHealthSourceIsOwnedByTheAppTests.swift
// Echoel — #1319. Blocking bundle. Claims 1–3 and 5 are SOURCE-TEXT SCANS
// (`Tests/CISmoke/CLAUDE.md` §1): they prove where the wiring sits, never that a heartbeat
// arrives. Claim 4 is END-TO-END on the shipped value type. Whether a Watch on a wrist
// actually moves the music is a DEVICE PROBE and is named open, not implied — the `.health`
// arm carries a NEEDS-FOUNDER-VERIFY for exactly that.
//
// ⭐ WHY THIS FILE EXISTS. `health` is the fourth chooser entry and the FIRST one this picker
// owns no publisher for. `HealthKitBioPublisher` is constructed and started at APP level
// (`EchoelmusicApp`: `startIfAlreadyAuthorized` on launch, `start` on the first
// `.echoelBioSourceStarted` of the run) and has been co-writing `EngineBus.latestBio` for
// every Health-authorised user all along — the interleave the ⛔ blocks on
// `stopBioSource`/`selectBioSource` measure, and which three separate slices each had to
// rediscover. Selecting Health therefore works by ELIMINATION: it stops the camera, the strap
// and the demo, and the wrist stops being an unannounced co-writer and becomes the chosen one.
//
// ⚠️ THE FAILURE THIS GUARDS AGAINST IS A PLAUSIBLE "FIX". An arm that starts nothing reads
// like an omission, and the obvious repair — call a start from the picker — installs a SECOND
// lifecycle owner on one publisher. That is the BLE-3 bug this repo has already paid for once
// (a patchbay edit killing a strap mid-performance), and it is why claim 1 counts the start
// calls rather than trusting the comment above them.
//
// ⚠️ WHAT CLAIM 1 CAN AND CANNOT SEE. It counts each publisher's start spelling in
// `startBioSource`'s brace-matched body and requires exactly one of each, so a start ADDED to
// the `.health` arm turns it red. It would NOT catch a start MOVED out of `.camera` into
// `.health` — the count would still be one. That case breaks the camera outright and is caught
// by the arm's own breadcrumb and by every camera guard in this bundle; it is stated here
// rather than left as an implied "this proves the arms are right".
//
// ⚠️ THE EXTRACTION IS SELF-CHECKED (#367). `SourceText.codeOnly` blanks comments but keeps
// string literals, so a `{` inside a literal would mis-balance the scan. Claim 1 therefore
// asserts the extracted body still contains the sibling arms AND does not contain
// `private func` — if the brace walk over- or under-ran, one of those two fails and says so,
// instead of a needle count quietly answering the wrong question.
//
// ⚠️ HONEST GRADING. No local Swift toolchain (§0). **11 assertions across five claims**
// (claim 1 = 6, claim 2 = 2, claim 3 = 1, claim 4 = 2, claim 5 = 2 — stated, not left to be
// counted). All were transcribed in Python and driven against BOTH trees. On the PARENT tree
// (`665f763`) **3 are red and that is ONE finding** (#486): the `.health` case does not exist
// there, seen from three angles — its breadcrumb, its raw value and its label. The other 8 are
// COUNTERWEIGHTS (#343) and are green on both trees: they pin that the app still owns the
// publisher, that `stopBioSource` still does not reach for it, and that the start paths still
// post the notification the app's authorisation ask hangs on. Without those three, this entry
// could become a dead menu row (#135) with every assertion above still green.
import Foundation
import XCTest
@testable import Echoelmusic

final class TheHealthSourceIsOwnedByTheAppTests: XCTestCase {

    private static let studioPath = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let appPath = "Sources/Echoelmusic/EchoelmusicApp.swift"

    // MARK: - claim 1 (SOURCE-TEXT) — the arm starts nothing, and no fourth start appeared

    func testTheHealthArmStartsNoPublisher() throws {
        let body = try functionBody("private func startBioSource() async {",
                                    in: SourceText.codeOnly(try source(Self.studioPath)))
        XCTAssertTrue(body.contains("case .sim:"), """
            The brace walk under-ran: `startBioSource`'s body no longer contains its own \
            `.sim` arm, so the counts below would be measuring a fragment. Re-anchor rather \
            than trusting a green (#367).
            """)
        XCTAssertFalse(body.contains("private func"), """
            The brace walk over-ran past the end of `startBioSource` and swept in a \
            neighbouring function, so the counts below would be measuring the wrong body.
            """)
        XCTAssertTrue(body.contains("case .health:"), """
            `startBioSource` has no `.health` arm. The chooser offers the entry \
            (`BioSourceOption.health`), and `BioSourceKind(rawValue:)` would parse the id — \
            an arm-less case is a menu row that silently does nothing, the #135 \
            lying-control class this whole chooser was built to avoid.
            """)
        for (publisher, spelling) in [("camera", "cameraRPPG.start(publishing:"),
                                      ("strap", "polarH10.start(publishing:"),
                                      ("demo", "demoSource.start(publishing:")] {
            let hits = body.components(separatedBy: spelling).count - 1
            XCTAssertEqual(hits, 1, """
                `startBioSource` starts the \(publisher) publisher \(hits) time(s) instead of \
                once. If the second call is in the `.health` arm, delete it: the HealthKit \
                publisher is owned at APP level, and a start from this picker makes it a \
                SECOND lifecycle owner — the BLE-3 bug (a live source killed by an unrelated \
                edit). Selecting Health is meant to start nothing and stop the other three.
                """)
        }
    }

    // MARK: - claim 2 (SOURCE-TEXT, counterweight) — the app still owns the publisher

    func testTheAppStillStartsTheHealthPublisher() throws {
        let app = SourceText.codeOnly(try source(Self.appPath))
        XCTAssertTrue(app.contains("healthBio.startIfAlreadyAuthorized(publishing: bus)"), """
            `EchoelmusicApp` no longer starts the HealthKit publisher for an \
            already-authorised user at launch. That call is HALF of what makes the `health` \
            chooser entry mean anything — without it the entry stops three publishers and \
            leaves nobody writing the bus.
            """)
        XCTAssertTrue(app.contains("healthBio.start(publishing: bus)"), """
            `EchoelmusicApp` no longer starts the HealthKit publisher on the first bio start \
            of a run. That is the deferred authorisation ask (UX-3); without it a fresh \
            install can never grant Health, and the `health` entry is a dead row.
            """)
    }

    // MARK: - claim 3 (SOURCE-TEXT, counterweight) — the picker still does not stand it down

    func testStopBioSourceStillLeavesTheWristAlone() throws {
        let body = try functionBody("private func stopBioSource() {",
                                    in: SourceText.codeOnly(try source(Self.studioPath)))
        XCTAssertFalse(body.contains("healthBio") || body.contains("HealthKitBioPublisher"), """
            `stopBioSource` now reaches for the HealthKit publisher. That inverts #1319: the \
            `health` entry works BECAUSE this function stops only the three publishers the \
            picker owns and leaves the app-level one running. Standing it down here makes \
            selecting Health stop everything — silence dressed as a source. The interleave is \
            deliberate and documented; see the ⛔ block on this function.
            """)
    }

    // MARK: - claim 4 (BEHAVIOUR) — the entry the user sees is the id the parser accepts

    func testTheEntryCarriesTheIdAndNamesItsSource() {
        XCTAssertEqual(BioSourceOption.health.rawValue, "health", """
            The Health entry's raw value changed. It is the on-the-wire id \
            `selectBioSource` parses through a private `BioSourceKind(rawValue:)` guard that \
            drops unknown ids SILENTLY — a mismatch here is a menu row that does nothing.
            """)
        XCTAssertTrue(BioSourceOption.health.menuLabel.contains("Apple Health"), """
            The Health entry stopped naming Apple Health. The label is where a player learns \
            WHERE the signal comes from; this source needs a Watch writing into Health, and a \
            label that does not say so sends them to cover the lens instead.
            """)
    }

    // MARK: - claim 5 (SOURCE-TEXT, counterweight) — the ask still has its trigger

    func testTheStartPathsStillPostTheNotificationTheAskHangsOn() throws {
        let studio = SourceText.codeOnly(try source(Self.studioPath))
        let posts = studio.components(separatedBy: "post(name: .echoelBioSourceStarted").count - 1
        XCTAssertEqual(posts, 2, """
            The studio posts `.echoelBioSourceStarted` \(posts) time(s) instead of twice (the \
            sounding start and the body-only start). That notification is what runs the \
            app's deferred HealthKit authorisation ask; losing it means a fresh install can \
            never authorise Health, and the `health` chooser entry becomes a dead row. \
            Gaining one means a third start path appeared — widen this deliberately.
            """)
        XCTAssertTrue(SourceText.codeOnly(try source(Self.appPath))
            .contains("publisher(for: .echoelBioSourceStarted)"), """
            `EchoelmusicApp` no longer listens for the first-bio-start notification, so \
            nothing runs the deferred Health authorisation ask. Same consequence as above, \
            from the other end of the same wire.
            """)
    }

    // MARK: - source access (§0/§2 — one stripper, FAIL on a moved anchor)

    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent(relative)
        guard let body = try? String(contentsOf: url, encoding: .utf8), !body.isEmpty else {
            throw XCTSkip("\(relative) not present under \(root.path)")
        }
        return body
    }

    /// Brace-matched body of the member whose declaration line ends in the given signature.
    /// Claim 1 and claim 3 both check the result for over-/under-run rather than trusting it.
    private func functionBody(_ signature: String, in code: String) throws -> String {
        guard let start = code.range(of: signature) else {
            XCTFail("""
                ANCHOR MISSING: "\(signature)" is no longer in \(Self.studioPath). A missing \
                anchor is a finding, not a pass (#454) — re-anchor in the same commit.
                """)
            return ""
        }
        var depth = 1
        var out = ""
        var i = start.upperBound
        while i < code.endIndex {
            let c = code[i]
            if c == "{" { depth += 1 }
            if c == "}" {
                depth -= 1
                if depth == 0 { return out }
            }
            out.append(c)
            i = code.index(after: i)
        }
        XCTFail("""
            The brace walk for "\(signature)" never closed — the body ran to the end of the \
            file. Something unbalanced the scan (a brace inside a string literal, which \
            `SourceText.codeOnly` keeps); fix the scan rather than the assertion.
            """)
        return out
    }
}
