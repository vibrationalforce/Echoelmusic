// AClosedPictureSaysSoTests.swift
// Echoel — #579. A log that answers "is the picture on?" only by staying silent is not an answer.
//
// THE DEVICE EVIDENCE, founder log 10.79.389/2506: **seventeen minutes**, a clean launch,
// `LaunchGuard: confirming healthy (studio)`, `body=1` on every single generate line — and
// **not one `visual:` line**. That breadcrumb fires every ~5 s from `MetalBioView`'s draw
// loop (`MetalBioView.swift`, the `nowGov - lastDiagLog > 5` block), so its absence means the
// renderer never ran, which means `isPresented` was false for the whole session.
//
// ⭐ THAT CONCLUSION IS CORRECT AND IT WAS REACHED THE WRONG WAY — by reading meaning into a
// line that was not printed. This bundle has a rule about exactly that shape (§5 / #445: a
// test name in the log proves it ran, its absence proves nothing), and here the same reasoning
// cost a whole verification round: #578's colour work was deployed with a note asking the
// founder to look at the picture, the picture was closed, and **nothing in the log said so**.
// The founder did everything right; the instrument could not report its own state.
//
// ⚠️ WHY IT REPORTS THE RENDERER AND NOT ONLY THE VISIBILITY. Until #1304 the two were
// genuinely different questions: `visualLayer` dropped `MetalBioView` on
// `!isPresented && !mustKeepRenderingForRecording`, so a HIDDEN window that was recording kept
// drawing (#319 — dropping it made a video take silently record nothing). Video capture is gone
// (founder 2026-09-12, "Kein Video Capture"), so today the renderer follows `isPresented`
// exactly and claim 1 can only ask for the `renderer=` TERM, not for a second condition.
//
// ⚠️ THAT IS A REAL WEAKENING AND IT IS NAMED RATHER THAN GLOSSED. The old claim 1b pinned the
// derivation (`mustKeepRenderingForRecording ? "on" : "off"`) precisely so nobody could replace
// the report with a restatement of visibility. With one term left, a scan cannot tell the
// honest line from the restatement — they are the same text. What claim 1 still buys is that
// the line says `renderer=` at BOTH sites, so the day anything else consumes the rendered
// picture the reader is looking at the right word. Retracted, not deleted: an assertion that
// can no longer fail for its named reason is the #367 defect.
//
// ⚠️ THE LIMIT, PER ASSERTION (§1): all SOURCE-TEXT SCANS. `FloatingVisualWindow` is a
// `View` with `@AppStorage` and `@Environment` members that no test bundle can instantiate,
// and `EchoelCrashLog.breadcrumb` writes to a device-side ring this bundle cannot read.
// DEVICE PROBE, open and NOT covered: whether the next pasted log actually carries the line.
// That is the founder's next paste, and it is the only thing that closes this.
//
// ⚠️ HONEST GRADING (§3) — THIS BLOCK GRADES #579 AGAINST ITS OWN PARENT (`75b4919`) AND IS
// KEPT AS HISTORY. It says nine assertions; #1304 retracted one (claim 1b, above), so the file
// carries eight today. The block is not re-graded because a grading is a statement about ONE
// commit's delta, and rewriting it to match a later tree would make it claim something #579
// never measured. Count the assertions, do not read the number here.
//   · **4 red by ANCHOR ABSENCE, reported as ONE finding (#486):** claims 1 and 2 scan for the
//     two breadcrumbs, which the parent does not have. Not booked as four regressions (#433).
//   · **5 COUNTERWEIGHTS**, green on both trees — and the point of the file. Every positive
//     scan here is satisfied just as well by a tree that made the window render
//     unconditionally (which would "fix" the missing line by burning 60 fps behind an
//     `opacity(0)` — the exact cost #311 paid to avoid), by one that re-added a conditional
//     mount (taking the Field's self-play display link with it, the #311 bug), or by one that
//     deleted the `visual:` breadcrumb this whole slice exists to explain the absence of.
//   · STRIPPER: **TRAGEND (1 of 9 verdicts flips)**, and the one that flips is worth naming
//     because it is this bundle's own documented collision. Claim 4's NEGATIVE scan
//     (`if floatingVisualVisible {` must be ABSENT) is **false on raw text and true only
//     through `SourceText.codeOnly`** — because `WorkspaceView.swift` deliberately QUOTES the
//     forbidden construct inside its ⭐ #311 explanation, which is exactly the "never ban a
//     file from naming what it forbids" case (#364). Without the shared stripper this
//     assertion would be red on a correct tree, in both directions, for ever.
//
// ⛔ AND MY FIRST VERSION OF THIS BLOCK CLAIMED "**PROPHYLAKTISCH (0 of 7)**" — wrong on the
// count AND on the grading, the second in the generous direction (#433): "prophylactic" asserts
// that the guard would hold without the stripper, and it would not. Both errors were found by
// transcribing, which is the only thing that can find them here (§0), and the count was wrong
// because the transcription folded claim 4's two assertions into one row before I split it.
// Recorded rather than silently corrected: a grading claim is a claim.

import Foundation
import XCTest

final class AClosedPictureSaysSoTests: XCTestCase {

    private static let window = "Sources/Echoelmusic/Studio/FloatingVisualWindow.swift"
    private static let metal = "Sources/Echoelmusic/Views/MetalBioView.swift"
    private static let mount = "Sources/Echoelmusic/Studio/WorkspaceView.swift"

    // MARK: - claim 1 — the report names the term that actually gates the renderer

    func testTheReportCarriesTheRendererTermNotOnlyVisibility() throws {
        let src = try source(Self.window)
        let hits = src.components(separatedBy: "renderer=\\(").count - 1
        XCTAssertEqual(hits, 2, """
            The window's state report no longer names `renderer=` at both sites (found \
            \(hits), expected 2). Visibility alone is the WEAKER fix and this assertion exists \
            to stop it replacing this one. Until #1304 the renderer had a SECOND gate (a \
            running video take kept a hidden window drawing, #319) and a log line saying only \
            "hidden" would have contradicted a stream of `visual:` lines. That gate is gone \
            with video capture, so the word `renderer=` is what remains: it is the term a \
            reader chases, and it must survive the day something consumes the picture again.
            """)
    }

    // MARK: - claim 2 — both a launch report and a change report, because each misses the other's case

    /// The 2506 session is the proof that launch-only is not optional: `isPresented` never
    /// CHANGED in seventeen minutes, so a change-only report would have printed nothing and
    /// left the log exactly as mute as before. The mirror case is a session that starts hidden
    /// and is opened at minute ten — launch-only would then claim "hidden" for the whole log.
    func testBothTheLaunchStateAndEveryChangeAreReported() throws {
        let src = try source(Self.window)
        XCTAssertTrue(src.contains("at launch (persisted)"), """
            The launch-time state report is gone. A session that never touches the monitor \
            button then prints nothing at all — which is precisely the 2506 session this slice \
            was written from, so removing this half restores the exact blindness it fixed.
            """)
        XCTAssertTrue(src.contains(".onChange(of: isPresented)"), """
            The change report is gone. A session that opens or closes the picture mid-run then \
            carries one launch line that is false for the rest of the log — worse than silence, \
            because it reads as an answer.
            """)
    }

    // MARK: - claim 3 (COUNTERWEIGHT) — the hidden window still costs nothing

    /// Green on both trees. The cheapest way to make `visual:` lines appear in every log is to
    /// render unconditionally — which would satisfy nothing above, look like a fix, and burn a
    /// 60 fps Metal layer behind an `.opacity(0)` for a picture nobody can see. #311 paid for
    /// that branch deliberately; #579 explains the silence, it does not remove it.
    func testTheHiddenWindowStillDropsItsRenderer() throws {
        let src = try source(Self.window)
        XCTAssertTrue(src.contains("if !isPresented {"), """
            The renderer-drop condition is gone from `visualLayer`. Either the hidden window is \
            now rendering at 60 fps for nobody (the battery cost #311 explicitly refused), or \
            the condition was rewritten and the report added by this slice no longer describes \
            what the code does. Both are worse than the silence being fixed.
            """)
        XCTAssertFalse(src.contains("mustKeepRenderingForRecording"), """
            `mustKeepRenderingForRecording` is back in the WINDOW'S CODE. It was the #319 \
            exception that kept a hidden window rendering so a running video take did not lose \
            its only frame source, and it went with video capture (#1304). If something \
            consumes the rendered picture again it needs that exception — and then it also \
            needs the external-stage exclusion the old term carried, because forcing the local \
            renderer back while an external stage holds one runs TWO renderers ("ONE \
            MetalBioView app-wide"), which is a worse defect than the one being fixed. Bring \
            the term back with BOTH halves, and update this guard and the header of this file \
            in the same commit.
            """)
    }

    // MARK: - claim 4 (COUNTERWEIGHT) — the window is still mounted unconditionally

    /// Green on both trees, and pinned here rather than left to `FieldSurvivesAHiddenPictureTests`
    /// alone because THIS slice adds `.onAppear` to that window: an `.onAppear` on a
    /// conditionally-mounted view fires on every re-insertion, so a future reader who re-adds an
    /// `if` would also silently turn the launch report into a repeating one. The two guards
    /// defend the same line for different reasons; that is not duplication.
    func testTheWindowIsStillMountedUnconditionally() throws {
        let src = try source(Self.mount)
        XCTAssertTrue(src.contains("FloatingVisualWindow(isPresented: $floatingVisualVisible)"), """
            The mount call changed shape — re-anchor this scan (#454) rather than letting it \
            drift green.
            """)
        XCTAssertFalse(src.contains("if floatingVisualVisible {"), """
            `FloatingVisualWindow` is mounted conditionally again. That is the #311 bug: the \
            Field's self-play arp runs on a `CADisplayLink` inside an overlay on this window, \
            and `didMoveToWindow` stops the link when the view leaves the hierarchy — so \
            hiding the picture took the AUDIO with it. Founder, 2026-07-31: "die arps soll \
            immer hörbar sein und nicht nur, wenn das Visual Fenster auf ist."
            """)
    }

    // MARK: - claim 5 (COUNTERWEIGHT) — the line whose absence started this still exists

    /// The premise of the entire slice. If the `visual:` breadcrumb were deleted, #579's report
    /// would explain the absence of nothing, and every assertion above would still be green.
    func testTheVisualHealthBreadcrumbStillExists() throws {
        let src = try source(Self.metal)
        XCTAssertTrue(src.contains("\"visual: bio=%d mfNotes=%d/%d"), """
            The `visual:` health breadcrumb is gone from `MetalBioView`. #579 exists to explain \
            why that line is sometimes absent; with the line itself deleted the explanation \
            describes nothing, and the log loses the only evidence that the renderer is \
            receiving sound and bio at all.
            """)
    }

    // MARK: - source access (§0/§2 — one stripper, skip on no tree, FAIL on a moved anchor)

    private struct PictureAnchorMissing: Error { let reason: String }

    private func source(_ relativePath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw PictureAnchorMissing(reason: """
                \(relativePath) is missing while the tree is present — it was renamed or moved. \
                Re-anchor this scan; do not let it skip (#454).
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
