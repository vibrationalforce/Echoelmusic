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
/// instead of unmounting) and Safe Mode still writes a recovery default. Stripper:
/// PROPHYLAKTISCH (0 of 47 verdicts flip) — measured raw vs. `codeOnly` on this tree.
///
/// ⭐ SLICE 2b (2026-09-30) — claims 6, 7 and 8 rewritten as the decision, none weakened.
/// 2a left the studio's Workstation PLATE constructing a second `WorkstationView` on the
/// Instrument stage and a persisted plate memory (`reopensWorkstation`) beside the stage key —
/// two truths about where a launch lands. 2b: the plate is a DOOR to the Piece stage and
/// constructs nothing (claim 6, the counterweight inverted); the plate memory is folded into the
/// stage key, so Safe Mode's write of it is gone (claim 7, the sibling pin inverted into an
/// absence); and the studio gains ONE hand on the stage, `showStage(_:)`, called on three user
/// actions — the two plate doors posted from the piece ("sound", "bio") turn the Instrument
/// stage, because a plate selected in a hidden studio is a button that does nothing (the first
/// defect measured on 2a), and "New piece" turns the Piece stage (claims 6 + 8, "the studio only
/// reads" inverted into "one function, three named calls"). ⚠️ The Workstation CHIP itself is
/// transitional: `.deploy/release` sends the founder along "Workstation-Chip" and is
/// founder-gated; slice 2b-ii retires it with that note.
///
/// ⭐ A7 (2026-10-01) — the piece's tabs (`WorkstationView.pieceTabs`) add three posters from
/// the Piece stage: "sound" (a second producer of the inspector's door), "effects" and "master"
/// (two cases re-added together with their producer, as the receiver's #290 note requires). The
/// Instrument-stage count in claim 6 is therefore four, and each turn is now pinned to its OWN
/// case rather than only counted — a count could pair a turn with the wrong door. Regression
/// against the parent: the count needles are red there for their named reason (2, not 4), and
/// the per-case loop is red by ABSENCE of the two new cases — one absence (#486).
/// ⭐ C5 (2026-10-01) — the piece's domain row (`WorkstationView.domainTabs`) posts "field" from
/// the Piece stage: the Field panel, re-added TOGETHER with its producer. The count is five.
/// Against the parent: both count needles red for their named reason (4, not 5); the loop's new
/// `case "field":` entry red by ABSENCE — one absence (#486).
/// ⭐ SLICE B (founder order 2026-10-01, one door per area) — the piece's FX and Master tabs and its
/// Visual domain tab were SECOND doors to plates the Instrument strip already opens; they went, and
/// their three cases with them (#290/#492). The count is TWO again — the two plate doors posted
/// from the piece, "sound" (the track inspector, now its ONLY producer) and "bio" (the pulse pill) —
/// exactly 2b's original pair, and each is still pinned to its OWN case. Against the parent: both
/// count needles red for their named reason (5, not 2); the per-case loop green on both (its two
/// remaining entries exist on both trees) — the three dropped entries are now `ThePieceHasTabsTests`
/// claim 2 and `ThePieceHasOneTabRowTests` claim 3, which pin their ABSENCE.
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

    // 6 — one arrangement in the tree, and one hand on the stage: the studio constructs NO
    // `WorkstationView` (its Workstation plate is a door to the Piece stage), and every move of
    // the stage from the studio goes through `showStage(_:)`, on a user action that names the
    // other stage's content.
    func testTheStudioMountsNoSecondArrangementAndHasOneHandOnTheStage() throws {
        let studio = try source(Self.studio)
        XCTAssertEqual(count("WorkstationView()", in: studio), 0, """
            The studio constructs `WorkstationView()` \(count("WorkstationView()", in: studio)) \
            times — a second arrangement in the tree, hidden beneath the piece, running the \
            directory listing, the playhead leaf and the analyses for nobody. The arrangement is \
            `ArrangeStage`'s (claim 5); the studio's plate is a door (slice 2b).
            """)
        let panel = braceBody(of: "private var workstationPanel: some View {", in: studio)
        guard !panel.isEmpty else {
            XCTFail("`workstationPanel` is gone — slice 2b-ii retires the chip with `.deploy/release`; move this claim with it")
            return
        }
        XCTAssertTrue(panel.contains("showStage(.piece)"), """
            The Workstation plate no longer leads to the Piece stage — a chip whose plate only \
            says where the arrangement went is a lying tab with a caption.
            """)
        XCTAssertTrue(studio.contains("@AppStorage(StudioDefaultKeys.stage.key) private var stageRaw"),
                      "the studio reads the stage through the ONE key (#416)")
        XCTAssertTrue(studio.contains("private func showStage(_ stage: StudioStage) { stageRaw = stage.rawValue }"),
                      "the studio's hand on the stage is ONE function taking a named stage, never a raw string")
        XCTAssertEqual(count("stageRaw = ", in: studio), 2, """
            `stageRaw = ` occurs \(count("stageRaw = ", in: studio)) times in the studio; exactly \
            two — the declaration's default and the body of `showStage(_:)` (the needle carries \
            its trailing space because `stageRaw ==` would otherwise count, measured). A third is \
            a second hand on the stage.
            """)
        // The calls — each a user action naming the other stage's content. A further call is a
        // code path choosing the stage FOR the player (the #1298/#1300 shape): name it here.
        let receiver = braceBody(of: "publisher(for: .echoelChromeDoor)) { note in", in: studio)
        XCTAssertFalse(receiver.isEmpty, "ANCHOR: the chrome-door receiver moved — re-anchor (#454)")
        // A7 and C5 (2026-10-01) named three more here ("effects", "master", "field"); slice B
        // removed them the same day as second doors (founder: one door per area). Each remaining
        // call is a user action naming a panel of the other stage.
        XCTAssertEqual(count("showStage(.instrument)", in: receiver), 2, """
            The chrome-door receiver turns the Instrument stage \
            \(count("showStage(.instrument)", in: receiver)) times; exactly two — the "sound" \
            door (the Echoel track's device door in the track inspector, on the Piece stage) and \
            the "bio" door (the pulse pill, visible on both stages). A plate selected in a hidden \
            studio is a button that does nothing (#164/#227) — the first defect measured on slice \
            2a. A third turn is a new door from the piece: name it here, and check it is not a \
            twin of a chip one seam tap away (slice B).
            """)
        for door in ["case \"sound\":", "case \"bio\":"] {
            guard let start = receiver.range(of: door) else {
                XCTFail("the receiver lost `\(door)` — the two turns above are named by their cases")
                continue
            }
            let tail = receiver[start.upperBound...]
            let next = tail.range(of: "case \"")?.lowerBound ?? tail.endIndex
            XCTAssertTrue(tail[..<next].contains("showStage(.instrument)"),
                          "`\(door)` must turn the Instrument stage itself — the count alone could pair a turn with the wrong door")
        }
        XCTAssertEqual(count("showStage(.instrument)", in: studio), 2,
                       "no call outside the receiver turns the Instrument stage")
        let newPiece = braceBody(of: "private func startNewPiece() {", in: studio)
        XCTAssertTrue(newPiece.contains("showStage(.piece)"),
                      "New piece turns the Piece stage — the empty song and its compose guide are there")
        XCTAssertEqual(count("showStage(.piece)", in: studio), 2,
                       "exactly two calls turn the Piece stage: the Workstation plate's door and New piece")
    }

    // 7 — Safe Mode: a piece stage that crashed at render is not where "Continue" lands.
    func testSafeModePointsTheStageAtTheInstrument() throws {
        let app = try source(Self.app)
        let write = "UserDefaults.standard.set(StudioStage.instrument.rawValue, forKey: StudioDefaultKeys.stage.key)"
        XCTAssertEqual(count(write, in: app), 1, """
            The Safe-Mode recovery must point the stage at the instrument exactly once. With a \
            PIECE default, clearing the key would mean "piece" — the recovery writes the \
            instrument instead of forgetting (WA4-P2 M1's reasoning, carried to the stage).
            """)
        XCTAssertFalse(app.contains("StudioStage.piece.rawValue"), "the app may point the stage at the instrument, never at the piece")
        // ⛔ 2a pinned the SIBLING write here — Safe Mode pointing `reopensWorkstation` at Sound,
        // before the stage write. Slice 2b folded that plate memory into the stage key, so the
        // sibling is inverted into an absence: the stage write is the whole recovery.
        XCTAssertFalse(app.contains("reopensWorkstationKey"), """
            Safe Mode writes the plate memory again. It went with slice 2b — the instrument's \
            launch plate is Sound by itself, and the stage key is the only relaunch memory.
            """)
    }

    // 8 — one definition of the key, four hands on it, each deliberate.
    func testTheStageKeyHasOneSpellingAndFourHands() throws {
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
        XCTAssertEqual(Set(readers), ["StageShell.swift", "EchoelStudioView.swift", "EchoelmusicApp.swift", "ProjectHeader.swift"], """
            The stage key is referenced by \(readers.sorted()). Four files are the design: the \
            seam (reads and writes on a tap), the studio (reads, and writes through `showStage` \
            on the user actions claim 6 lists), Safe Mode (writes the instrument once) and the \
            head (reads only, A3b — it drops its Play/Record on the Piece stage). A fifth is a \
            new writer or a new reader — name it here with its reason.
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
