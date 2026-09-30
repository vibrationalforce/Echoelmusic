import XCTest
@testable import Echoelmusic

/// THE PIECE IS THE FRONT STAGE — slice 2a of the interface audit (founder 2026-09-30:
/// decisions 2 + 3 approved, then *"Du entscheidest alles und weißt, dass das Design insgesamt
/// vor allem im Vordergrund eine DMMW ist"*).
///
/// WHAT SHIPS: `SurfaceHost` mounts `StageShell`, a seam „Piece | Instrument". The Piece stage
/// is `ArrangeStage` — `WorkstationView` standing free — and it is the DEFAULT: a fresh install
/// opens on the arrangement. The Instrument stage is `EchoelStudioView`, unchanged inside.
///
/// ⛔ THE ONE THING THIS FILE EXISTS TO KEEP: THE INSTRUMENT IS HIDDEN, NEVER UNMOUNTED. The
/// audit doc planned the seam as a sibling switch; measured, `EchoelStudioView.onDisappear`
/// calls `stopEverything(reason: "unmount")` and the studio hosts the Save/Open doors the
/// workstation opens through the chrome. An `if/else` would stop the pulse session and the
/// take on every switch to the piece. So the studio is always in the tree — transparent,
/// untouchable and unspoken while the piece shows — and `ArrangeStage` is conditional on top.
///
/// ⚠️ LIMITS (§1). Claims 1 and 10 are END-TO-END over shipped values (`StudioStage`,
/// `LearnLibrary`); claims 2–9 are SOURCE-TEXT SCANS. Nothing here renders: that a hidden studio keeps its session across a
/// tap is SwiftUI behaviour the founder proves on the device (first device ask of this slice).
///
/// ⭐ GRADING (§3), hand-transcribed in Python (§0). This file names two symbols this commit
/// creates (`StudioStage`, `StageShell`), so it DOES NOT COMPILE against the parent
/// (`0c12d960f`) and no assertion has a verdict there. Against the parent's TEXT, transcribed:
/// **47 assertions (loops unrolled).** Claim 2's absence needle (`SurfaceHost` no longer builds
/// `EchoelStudioView()` directly) is the ONE regression the parent text can show; every other
/// scan of `StageShell.swift` is red there by ONE anchor absence — the file (#486) — reported
/// once, not eleven times; claim 1 has no verdict. **COUNTERWEIGHTS, green on both trees
/// (#343):** the studio still stops everything in `.onDisappear` (the reason the seam hides
/// instead of unmounting), Safe Mode still points `reopensWorkstation` at Sound, and the
/// studio's Workstation panel still constructs `WorkstationView()` (`TheWorkstationHasADoorTests`
/// stays true in letter and, on the Instrument stage, in fact). Stripper: PROPHYLAKTISCH
/// (0 of 47 verdicts flip) — measured raw vs. `codeOnly` on this tree.
final class TheArrangeStageIsTheFrontStageTests: XCTestCase {

    private static let seam = "Sources/Echoelmusic/Studio/StageShell.swift"
    private static let host = "Sources/Echoelmusic/Studio/SurfaceSwitcher.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    private func repoRoot() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { break }
            dir = dir.deletingLastPathComponent()
        }
        return dir
    }

    private func source(_ path: String) throws -> String {
        let url = repoRoot().appendingPathComponent(path)
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(path) could not be read — a missing anchor is a finding.")
            return ""
        }
        return SourceText.codeOnly(text)
    }

    /// Brace-matched body after `opener` (#408 — never a fixed line window in this repo).
    /// Returns "" on a missed anchor; callers anchor-check before expecting an absence.
    private func braceBody(of opener: String, in code: String) -> String {
        guard let start = code.range(of: opener) else { return "" }
        var depth = 1
        var i = start.upperBound
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

    private func count(_ needle: String, in code: String) -> Int {
        code.components(separatedBy: needle).count - 1
    }

    // 1 — END-TO-END: the values the seam ships. Piece FIRST and Piece by DEFAULT is the
    // decision ("im Vordergrund eine DMMW"); the raw values are persisted, so they are pinned;
    // neither label may be "Play", because the transport button already is.
    func testThePieceIsTheDefaultStageAndComesFirst() {
        XCTAssertEqual(StudioDefaultKeys.stage.value, .piece, """
            A fresh install no longer opens on the piece. Founder decision 2026-09-30: the DMMW \
            is the foreground; the instrument is a device on one of the piece's tracks. If the \
            front stage changed again, that is a founder decision — say so, and sweep the \
            `StageShell.swift` header, the CLAUDE.md Root-view line and the first guide card.
            """)
        XCTAssertEqual(StudioDefaultKeys.stage.key, "studio.stage")
        XCTAssertEqual(StudioStage.allCases, [.piece, .instrument], "the piece stands FIRST on the seam")
        XCTAssertEqual(StudioStage.piece.rawValue, "piece", "persisted — rename the label, never the case")
        XCTAssertEqual(StudioStage.instrument.rawValue, "instrument", "persisted — rename the label, never the case")
        XCTAssertEqual(StudioStage.piece.label, "Piece", "the glossary word (decision 4): Stück · Spur · Teil · Szene")
        for stage in StudioStage.allCases {
            XCTAssertFalse(stage.spokenHint.isEmpty, "\(stage.label) has no spoken hint (#482)")
            XCTAssertFalse(stage.label.contains("Play"), """
                "\(stage.label)" puts a second "Play" on the screen next to the transport's — the \
                one ambiguity a cognitively loaded reader must never meet.
                """)
        }
    }

    // 2 — THE DECISION, as text: the surface host mounts the seam, not the studio directly.
    func testTheSurfaceHostMountsTheSeam() throws {
        let host = try source(Self.host)
        let body = braceBody(of: "var body: some View {", in: host)
        guard !body.isEmpty else {
            XCTFail("`SurfaceHost.body` is gone or reshaped — re-anchor this scan (#367)")
            return
        }
        XCTAssertTrue(body.contains("StageShell()"), """
            `SurfaceHost` no longer mounts `StageShell`. The seam „Piece | Instrument" IS the \
            surface since slice 2a; without it the piece has no stage and the app opens on the \
            instrument again.
            """)
        XCTAssertFalse(body.contains("EchoelStudioView()"), """
            `SurfaceHost` builds `EchoelStudioView()` directly again — the pre-2026-09-30 shape. \
            The studio belongs INSIDE `StageShell`, always mounted, hidden while the piece shows.
            """)
    }

    // 3 — THE LAW: the instrument is hidden, never unmounted. Its construction sits in the
    // ZStack BEFORE the piece's `if`, never inside one; the piece is the conditional branch.
    func testTheInstrumentStaysMountedAndHiddenBeneathThePiece() throws {
        let seam = try source(Self.seam)
        let zstack = braceBody(of: "ZStack {", in: seam)
        guard !zstack.isEmpty else {
            XCTFail("`StageShell` has no `ZStack {` — the hide-not-unmount shape is gone; re-anchor (#367)")
            return
        }
        XCTAssertEqual(count("EchoelStudioView()", in: seam), 1, """
            `StageShell.swift` must construct `EchoelStudioView()` exactly once (found \
            \(count("EchoelStudioView()", in: seam))). Zero: the instrument is gone from the \
            tree and its session with it. Two: a second instrument, a second engine owner.
            """)
        let pieceBranch = braceBody(of: "if stage == .piece {", in: zstack)
        XCTAssertFalse(pieceBranch.isEmpty, "the piece's conditional branch `if stage == .piece {` is gone from the ZStack")
        XCTAssertTrue(pieceBranch.contains("ArrangeStage()"), "the piece branch must mount `ArrangeStage()`")
        XCTAssertFalse(pieceBranch.contains("EchoelStudioView()"), """
            `EchoelStudioView()` moved INSIDE the piece's `if`. Then switching stages unmounts \
            the studio, `.onDisappear { stopEverything(reason: "unmount") }` fires, and the \
            pulse session and the take die on a navigation tap.
            """)
        if let studioAt = zstack.range(of: "EchoelStudioView()")?.lowerBound,
           let ifAt = zstack.range(of: "if stage == .piece {")?.lowerBound {
            XCTAssertLessThan(studioAt, ifAt, "the studio is the ZStack's base layer; the piece is mounted on top of it")
        } else {
            XCTFail("the ZStack must hold both `EchoelStudioView()` and `if stage == .piece {`")
        }
        for modifier in [".opacity(stage == .instrument ? 1 : 0)",
                         ".allowsHitTesting(stage == .instrument)",
                         ".accessibilityHidden(stage != .instrument)"] {
            XCTAssertTrue(zstack.contains(modifier), """
                `\(modifier)` is gone. The hidden studio must be hidden THREE ways — invisible, \
                untouchable, unspoken — or a VoiceOver user reads an instrument under the piece, \
                or a tap lands on a panel nobody can see.
                """)
        }
        // COUNTERWEIGHT (#343): the REASON still holds. The day the studio stops stopping on
        // unmount, this pin says the seam's shape may be revisited — not silently kept.
        let studio = try source(Self.studio)
        XCTAssertTrue(studio.contains(".onDisappear { stopEverything(reason: \"unmount\")"), """
            `EchoelStudioView` no longer stops everything in `.onDisappear`. That was the \
            measured reason the seam HIDES the studio instead of switching it out; revisit the \
            `StageShell.swift` header in the same commit rather than leaving a reason that is \
            no longer true.
            """)
    }

    // 4 — BLACK-SCREEN LAW + #W1: the seam carries no presentation modifier and no importer.
    func testTheSeamCarriesNoPresentationModifier() throws {
        let seam = try source(Self.seam)
        XCTAssertTrue(seam.contains("struct StageShell: View"), "anchor: the seam type exists")
        for modal in [".sheet(", ".fullScreenCover(", ".alert(", ".confirmationDialog(",
                      ".popover(", ".fileImporter("] {
            XCTAssertFalse(seam.contains(modal), """
                `StageShell.swift` now carries `\(modal)`. The seam is an ancestor of every \
                surface: a modal here rides above the studio's 11-deep chain (black-screen law), \
                and an importer here shadows the workstation's own (#W1).
                """)
        }
    }

    // 5 — the piece stage stands the workstation free, once, in this file.
    func testThePieceStageStandsTheWorkstationFree() throws {
        let seam = try source(Self.seam)
        let stage = braceBody(of: "struct ArrangeStage: View {", in: seam)
        XCTAssertTrue(stage.contains("WorkstationView()"), "`ArrangeStage` must construct the real surface")
        XCTAssertEqual(count("WorkstationView()", in: seam), 1, """
            `StageShell.swift` constructs `WorkstationView()` \(count("WorkstationView()", in: seam)) \
            times; exactly one — on the piece stage — is the design. A second is a second \
            arrangement in the tree.
            """)
    }

    // 6 — one arrangement in the tree: the hidden studio mounts no second one while the piece
    // shows, and the studio only READS the stage.
    func testTheStudioMountsNoSecondArrangementWhileThePieceShows() throws {
        let studio = try source(Self.studio)
        let panel = braceBody(of: "private var workstationPanel: some View {", in: studio)
        guard !panel.isEmpty else {
            XCTFail("`workstationPanel` is gone — slice 2b retires the chip; move this claim with it")
            return
        }
        XCTAssertTrue(panel.contains("if stageRaw == StudioStage.piece.rawValue {"), """
            The studio's Workstation panel no longer branches on the stage. While the piece \
            shows, the studio is mounted but hidden, and a `WorkstationView` there runs the \
            directory listing, the playhead leaf and the analyses a second time for nobody.
            """)
        XCTAssertTrue(panel.contains("WorkstationView()"), """
            COUNTERWEIGHT: on the Instrument stage the chip must still reach the real surface \
            (`TheWorkstationHasADoorTests`) until slice 2b retires it.
            """)
        XCTAssertTrue(studio.contains("@AppStorage(StudioDefaultKeys.stage.key) private var stageRaw"),
                      "the studio reads the stage through the ONE key (#416)")
        XCTAssertEqual(count("stageRaw = ", in: studio), 1, """
            `stageRaw = ` occurs \(count("stageRaw = ", in: studio)) times in the studio; exactly \
            one — the declaration's default — is legal (the needle carries its trailing space \
            because `stageRaw ==` would otherwise count, measured). The studio never CHOOSES \
            the stage: a surface opening itself is the #1298/#1300 shape.
            """)
    }

    // 7 — Safe Mode: a piece stage that crashed at render is not where "Continue" lands.
    func testSafeModePointsTheStageAtTheInstrument() throws {
        let app = try source(Self.app)
        let write = "UserDefaults.standard.set(StudioStage.instrument.rawValue, forKey: StudioDefaultKeys.stage.key)"
        XCTAssertEqual(count(write, in: app), 1, """
            The Safe-Mode recovery must point the stage at the instrument exactly once. With a \
            PIECE default, clearing the key would mean "piece" — the recovery writes the \
            instrument instead of forgetting, the same reasoning as `reopensWorkstation` (WA4-P2 M1).
            """)
        XCTAssertFalse(app.contains("StudioStage.piece.rawValue"), "the app may point the stage at the instrument, never at the piece")
        // COUNTERWEIGHT: the sibling write it reasons from is still there, before it.
        let sibling = "UserDefaults.standard.set(false, forKey: EchoelStudioView.reopensWorkstationKey)"
        XCTAssertTrue(app.contains(sibling), "Safe Mode still points the plate memory at Sound")
        if let a = app.range(of: sibling)?.lowerBound, let b = app.range(of: write)?.lowerBound {
            XCTAssertLessThan(a, b, "both writes sit in the one recovery `.onAppear`, plate first, stage second")
        }
    }

    // 8 — one definition of the key, two writers, both deliberate.
    func testOnlyTheSeamAndSafeModeWriteTheStage() throws {
        let root = repoRoot().appendingPathComponent("Sources/Echoelmusic")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            XCTFail("could not enumerate Sources/Echoelmusic"); return
        }
        var literal: [String] = []
        var readers: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let code = SourceText.codeOnly(raw)
            if code.contains("\"studio.stage\"") { literal.append(url.lastPathComponent) }
            if code.contains("StudioDefaultKeys.stage.key") { readers.append(url.lastPathComponent) }
        }
        XCTAssertEqual(literal, ["StudioDefaultKeys.swift"], """
            The literal "studio.stage" is spelled in \(literal). One definition (#416): every \
            reader and writer goes through `StudioDefaultKeys.stage.key`.
            """)
        XCTAssertEqual(Set(readers), ["StageShell.swift", "EchoelStudioView.swift", "EchoelmusicApp.swift"], """
            The stage key is referenced by \(readers.sorted()). Three files are the design: the \
            seam (reads and writes on a tap), the studio (reads only) and Safe Mode (writes the \
            instrument once). A fourth is a new writer or a new reader — name it here with its reason.
            """)
        let seam = try source(Self.seam)
        XCTAssertEqual(count("stageRaw = ", in: seam), 2, """
            `stageRaw = ` occurs \(count("stageRaw = ", in: seam)) times in the seam; exactly two \
            — the declaration's default and the ONE Button action. A third is a code path \
            choosing the stage for the player.
            """)
    }

    // 10 — END-TO-END: the launch teaching names the seam by the words it shows. The first
    // guide card is the first sentence a newcomer reads; since the piece is the front stage,
    // it has to say where the instrument's Play button went (#351: a guide that describes the
    // previous screen).
    func testTheGuidesFirstCardNamesBothStages() throws {
        let first = try XCTUnwrap(LearnLibrary.guideEntries.first)
        XCTAssertTrue(first.detail.contains("Piece and Instrument"), """
            The first guide card no longer names the two stages. It greets a newcomer on the \
            Piece stage and must say that the instrument — and its Play button — is one word away.
            """)
        for stage in StudioStage.allCases {
            XCTAssertTrue(first.detail.contains(stage.label), """
                The guide names a stage by a word the seam does not show: "\(stage.label)" is \
                missing from the first card. Rename both in the same commit (#351).
                """)
        }
    }

    // 9 — the seam is a real control: 44 pt, selected trait, spoken hint.
    func testTheSeamIsATapTargetThatSpeaks() throws {
        let seam = try source(Self.seam)
        XCTAssertTrue(seam.contains("minHeight: EchoelTheme.controlTapHeight"), "44 pt by NAME, never a literal (#364)")
        XCTAssertTrue(seam.contains(".accessibilityAddTraits(isActive ? .isSelected : [])"), "VoiceOver hears which stage is showing")
        XCTAssertTrue(seam.contains(".accessibilityHint(candidate.spokenHint)"), "the door names what it reaches (#482)")
    }
}
