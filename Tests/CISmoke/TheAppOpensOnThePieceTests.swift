import XCTest
@testable import Echoelmusic

/// THE APP OPENS ON THE PIECE — founder decision 2026-09-30 (interface audit, decision 2 of
/// fourteen: *"Startet die App im Stück statt im Vollbild-Visual? Ja"*).
///
/// ⛔ THIS FILE WAS `TheAppOpensInTheFullscreenVisualTests` (#1070) AND PINNED THE OPPOSITE. It
/// is REWRITTEN AS THE NEW DECISION, not weakened: every premise it held is still held here —
/// the seed exists, writes BOTH keys, is reachable behind a flag registered `true` before any
/// view reads it, and the two arguments that rested on the launch state are still written down.
/// What flipped is ONE token in `WorkspaceView`'s seed: `.fullscreen` → `.small`. The picture
/// stays visible at launch, as a card over the piece; fullscreen is one tap away, never the door.
/// Why: the audit measured a fresh install landing on a wall with the header, the tracks and the
/// instrument invisible beneath it — the opposite of "the piece is the home".
///
/// ⚠️ THE #1070 LESSON STILL APPLIES AND IS THE REASON THIS FILE EXISTS IN ANY DIRECTION: A
/// DEFAULT IS NOT A STATE. `@AppStorage`'s default is `.small` — today the SEED also writes
/// `.small`, so a reader who greps the declaration and the seed agree for the first time since
/// 2026-07-22. Do not read that agreement as "the seed is redundant": without it, a user who
/// quit in fullscreen (or was killed mid-take, `goImmersiveForTake` writes `.fullscreen`)
/// would relaunch onto the wall. The seed is what makes the front door DETERMINISTIC.
///
/// WHAT STILL DEPENDS ON THE LAUNCH STATE, and why both arguments survive the flip:
///   · `updateKeepAwake()` — the fullscreen term stays CONJUNCTIVE. A CHOSEN fullscreen picture
///     with no body running is a screensaver; awake is earned by a running measurement.
///   · `FloatingVisualLayout.chromeFit` — the Studio chip still sheds LAST: it is the only
///     LABELLED way back to the piece from the picture, whichever way the user got there.
///
/// ⚠️ KNOWN COST, pinned as prose here and at the seed: `InstrumentHintOverlay` is gated on a
/// visible FULLSCREEN window, so the two-gesture hint no longer appears at launch. It returns on
/// the first fullscreen entry (the #604 retire law is untouched). The launch teaching is the
/// founder's `GuideOverlay`, whose first card is rewritten in this commit and pinned below.
///
/// ⚠️ LIMITS (§1). Claims 1–4 are SOURCE-TEXT SCANS; claim 5 is END-TO-END over the shipped
/// `LearnLibrary` values. None proves a device renders a card over the piece — that is the
/// founder's look, the first of the five asks for the next build.
///
/// ⭐ GRADING (§3), hand-transcribed in Python against the parent (`ba3708380`) and this tree —
/// no local toolchain (§0). The file names no symbol this commit creates, so it compiles against
/// the parent and every assertion has a verdict there. **12 assertions.**
///   · **4 red on the parent, arising from TWO findings (#486):** the seed wrote `.fullscreen`
///     (claim 1: the `.small` needle absent AND the `.fullscreen` needle present inside the
///     seed body — one decision, two assertions) and the guide's first card said "opens as a
///     picture" (claim 5: the new summary absent AND the old one present — one copy, two
///     assertions). Both are the DECISION, red on the parent by design, not regressions.
///   · **8 COUNTERWEIGHTS**, green on both trees (#343): the seed still sets the window visible,
///     still consults the flag, the flag is still registered first, the header and the stage
///     are still mounted beneath the card in that order, and both dependent arguments still
///     name their premise.
///   · Stripper: **PROPHYLAKTISCH (0 of 12 verdicts flip)** — the seed body is three code
///     lines with no comment inside the braces, and the `.fullscreen` prose sits ABOVE the
///     `.onAppear`, outside the extracted body.
final class TheAppOpensOnThePieceTests: XCTestCase {

    private func source(_ path: String) throws -> String {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        let url = dir.appendingPathComponent(path)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(path) could not be read — a missing anchor is a finding.")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    /// Brace-matched body of the block that starts at `opener` (#408: a fixed line window is
    /// unsound by construction in a file that writes 30-line comment blocks; the body is the
    /// text between the opener's `{` and its matching `}`). Returns "" on a missed anchor, so
    /// callers anchor-check before expecting an absence (§2, the `slice` note).
    private func braceBody(of opener: String, in code: String) -> String {
        guard let start = code.range(of: opener) else { return "" }
        var depth = 0
        var i = start.upperBound
        // The opener ends with "{" — count it.
        depth = 1
        let bodyStart = i
        while i < code.endIndex {
            let ch = code[i]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(code[bodyStart..<i]) }
            }
            i = code.index(after: i)
        }
        return ""
    }

    // 1 — THE DECISION. The seed writes the card size AND makes the window visible; the
    // fullscreen size is written nowhere inside the seed. One without the other is not a
    // front door: a visible window at the wrong size is the wall; a card size on a hidden
    // window shows nothing.
    func testTheSeedOpensOnThePieceWithTheVisualAsACard() throws {
        let workspace = try source("Sources/Echoelmusic/Studio/WorkspaceView.swift")
        let seed = braceBody(of: "if FeatureFlags.instrumentHome {", in: workspace)
        guard !seed.isEmpty else {
            XCTFail("""
                The front-door seed (`if FeatureFlags.instrumentHome {` in `WorkspaceView`) is \
                gone or reshaped. Re-anchor this scan in the same commit; do not let an empty \
                body make the absence assertion below vacuously green (#367).
                """)
            return
        }
        XCTAssertTrue(
            seed.contains("floatingSizeRaw = FloatingVisualWindow.WindowSize.small.rawValue"),
            """
            The seed no longer opens the visual as a `.small` card. Founder decision 2026-09-30 \
            (audit decision 2): the app opens ON THE PIECE — header, tracks, instrument — with \
            the picture as a card over it. If the front door changed again, that is a founder \
            decision: say so, and sweep the launch-state prose in `EchoelStudioView` \
            (`updateKeepAwake`), `FloatingVisualLayout` (`chromeFit`), `LearnLibrary` (first \
            guide card), `CLAUDE.md` (Root view) and the three sibling guards in the same \
            commit (#456).
            """)
        XCTAssertFalse(seed.contains("WindowSize.fullscreen"), """
            The seed writes `.fullscreen` again. From 2026-07-22 to 2026-09-30 that was the \
            front door and a fresh install landed on a wall with the piece invisible beneath \
            it — the first finding of the interface audit, reversed by the founder. Fullscreen \
            is a tap away (`openFullscreenVisual()`, `cycleSize`), never the launch state.
            """)
        XCTAssertTrue(seed.contains("floatingVisualVisible = true"), """
            The seed sets a card SIZE without making the window VISIBLE. Then the piece opens \
            with no picture at all, while the stored size claims otherwise — and the visual is \
            part of the experience by product law ("wow von Sekunde 1"), a card, not a wall.
            """)
    }

    // 2 — COUNTERWEIGHT: the seed is REACHABLE. A seed behind a flag that reads false is a
    // seed that never runs, and this exact thing already happened here: the flag read false
    // for three weeks because it was registered after the first view appeared (#580).
    func testTheSeedsFlagIsRegisteredTrueBeforeAnyViewReadsIt() throws {
        let app = try source("Sources/Echoelmusic/EchoelmusicApp.swift")
        XCTAssertTrue(
            app.contains("register(defaults: [FeatureFlags.Key.instrumentHome.rawValue: true])"),
            """
            `instrumentHome` is no longer registered as `true`. `FeatureFlags.isOn` is a plain \
            `defaults.bool(forKey:)`, which answers false for an unregistered key — so the seed \
            in `WorkspaceView.onAppear` would silently never run and a user who quit in \
            fullscreen would relaunch onto the wall. That is not a hypothetical: it is #580, \
            where the registration sat AFTER the first view appeared and the one flag that is \
            read first read false for three weeks with nothing saying so.
            """)
        let workspace = try source("Sources/Echoelmusic/Studio/WorkspaceView.swift")
        XCTAssertTrue(workspace.contains("if FeatureFlags.instrumentHome {"), """
            The seed no longer consults `instrumentHome`. The flag is the documented one-line \
            rollback lever for the front door (`FeatureFlags.set(.instrumentHome, false)`); a \
            seed that ignores it cannot be rolled back without a build. (The KEY keeps its \
            2026-07-22 name because it is persisted; the thing it seeds is the piece.)
            """)
    }

    // 3 — COUNTERWEIGHT: the piece is MOUNTED, in reading order, beneath the card. "Opens on
    // the piece" means the header, the composition strip and the stage are the ZStack's base
    // layer and the visual window is layered AFTER them. Anchored on the root `body` only —
    // the file declares four more `body`s further down.
    func testTheHeaderAndTheStageAreMountedBeneathTheCard() throws {
        let workspace = try source("Sources/Echoelmusic/Studio/WorkspaceView.swift")
        guard let bodyAt = workspace.range(of: "var body: some View {")?.lowerBound else {
            XCTFail("`WorkspaceView.body` is gone — re-anchor this ordering scan (#454)")
            return
        }
        let body = workspace[bodyAt...]
        var last = body.startIndex
        // DAW shell S1a: the composition strip left the head for the Project plate; the head is
        // the brand bar and the project header now, in that order.
        XCTAssertFalse(body.contains("CompositionHeaderStrip()"),
                       "the composition strip is the Project plate's Song section, not a row of the head")
        for token in ["topBar", "ProjectHeader()", "SurfaceHost()",
                      "FloatingVisualWindow(isPresented: $floatingVisualVisible)"] {
            guard let at = body[last...].range(of: token)?.lowerBound else {
                XCTFail("""
                    `\(token)` no longer appears in `WorkspaceView.body` after the previous \
                    layer. The front door is "the piece with the picture over it": brand \
                    header, project header and stage first, the visual window layered \
                    after them. If the root was restructured, re-anchor this in the same commit.
                    """)
                return
            }
            last = at
        }
    }

    // 4 — COUNTERWEIGHT (#343/#367): the two arguments that used to rest on "fullscreen is
    // the launch state" are still written down, with their reasons re-grounded. Without this
    // the file would stay green on a tree that kept the SEED and lost the reasoning.
    func testBothDependentArgumentsStillHoldUnderTheNewDoor() throws {
        let studio = try source("Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        XCTAssertTrue(studio.contains("(floatingVisualIsFullscreen && cameraRPPG.isRunning)"), """
            The fullscreen keep-awake term is not conjunctive any more. A fullscreen picture \
            the user CHOSE with no body running is a screensaver; awake is earned by a running \
            measurement, not by a window size — the rule is the same under either front door.
            """)
        let layout = try source("Sources/Echoelmusic/Studio/FloatingVisualLayout.swift")
        XCTAssertTrue(layout.contains("$0.studioChip = false"), """
            The Studio chip is no longer the last non-recorder item in the shed order. It sheds \
            last because it is the only LABELLED way back to the piece from the picture — \
            whichever way the user got there. If the ranking changed, the reason has to change \
            with it.
            """)
    }

    // 5 — END-TO-END: the launch teaching tells the truth. `GuideOverlay` renders
    // `LearnLibrary.guideEntries` in order; its first card is the first sentence a newcomer
    // reads at launch, and it said "The app opens as a picture" while the picture was the
    // door. A guide that describes the previous front door is the #351 defect returned.
    func testTheGuidesFirstCardDescribesTheDoorThatShips() throws {
        let first = try XCTUnwrap(LearnLibrary.guideEntries.first)
        XCTAssertEqual(first.id, "guide.firstSession")
        XCTAssertTrue(first.summary.contains("opens on your piece"), """
            The first guide card no longer says the app opens on the piece. The front door is \
            the piece with the visual as a card (2026-09-30); the card that greets a newcomer \
            must describe the screen it is shown on.
            """)
        for entry in LearnLibrary.guideEntries {
            XCTAssertFalse(entry.summary.contains("opens as a picture")
                           || entry.detail.contains("opens into its living picture"), """
                Guide entry "\(entry.id)" still describes the 2026-07-22 front door (the \
                fullscreen picture). Since 2026-09-30 the picture is a card over the piece; \
                fullscreen is one tap away.
                """)
        }
    }
}
