// TheSongAloneCanBeSavedTests.swift
// Echoel — WA4 Acceptance Test A: create → import → SAVE → reopen.
//
// WHAT THIS PINS. The Save tile was `.disabled(!hasComposed)`: a player who only imported audio
// into the Workstation — no composed take — could not save the song they had built, so
// Acceptance Test A broke at its third step. The Session carries the song since WA4-S3, so a
// song holding the USER's parts is worth a save on its own. The tile is now the
// `SaveSessionButton` leaf, enabled by `hasComposed || SessionSaveOpen.songHasUserParts(…)` —
// the SAME predicate the recovery slot uses (`autosaveTake`), asked, not restated (#416).
//
// 1. SOURCE: the leaf computes that one predicate, and the dim state tracks `.disabled` exactly
//    (a lit tile that eats the tap is the #482 lie). The leaf reads the song in its OWN body:
//    the root body hosts every `.menu` Picker and must not observe the document (freeze law).
// 2. SOURCE: the save still goes through `withSession`, and the Save message names the song —
//    a save that carries the song while its sentence says "the loop" under-claims (#495).
// 3. COUNTERWEIGHT: `songHasUserParts` still ignores the composer's own part (the #622 law —
//    never an empty take under a real name — holds for a plain launch). Its behaviour is driven
//    end to end in `TheSessionSaveOpensTheSameSongTests`; here the source keeps the gate on it.
// 4. SOURCE: the Workstation plate carries the same two doors (`WorkstationProjectRow`), Save
//    gated on the same facts and Open never (2026-10-01: its sheet holds New piece and Import,
//    which an empty library needs — the `canOpen` needle left with the gate), raising the Studio's OWN Save alert and Open sheet through the chrome door —
//    no presentation modifier of its own (the black-screen budget), and a receiver case per post.
// ⭐ 2026-09-30 (rule 1, one word per thing): the tile's spoken name is "Save this piece" —
//    the glossary word — and the Workstation row's `spoken:` says the same; "Save this session"
//    was a third word for the saved work. The needles below follow (a guard rewritten as the
//    decision, never weakened); `TheChromeSpeaksOneWordPerThingTests` scans the row's file.
// ⭐ DAW SHELL S3 (2026-10-02, inbox E18): Save and Open moved into the ≡ menu on both stages.
//    Claim 1 now pins the SAME predicate in the "save" door's arm (asked at tap time, so the
//    root never reads the document) and the alert's "Nothing to save yet" branch; claim 4 pins
//    the deleted row ABSENT and the menu's two entries, ungated, with no modifier of its own.
//    Against f4b4f006d both are REGRESSIONS (the tile and the row still exist there; the arm has
//    no gate); claims 2, 3 and 5 are untouched.
// 5. SOURCE (review of c69af8995, MEDIUM): a row whose only content is its song cannot be
//    shared — `sharedDocumentData` strips the Session, so it would arrive empty. The rule is
//    driven end to end in `TheWorkstationJourneySurvivesSaveAndOpenTests` claim 3.
//
// Grading (§0, no Swift toolchain in a web session): all claims driven in Python against this
// tree. On 8820621fd claims 1–2 are red by ABSENCE of `SaveSessionButton` and the new
// sentence; on c69af8995 claim 4 is red by ABSENCE of `WorkstationProjectRow` — one absence
// each (#486); all are FORWARD guards. Claim 3 is a COUNTERWEIGHT, green
// on both. NOT covered: that the tile lights up on the device after an import, and that the
// Open of a song-only project restores it audibly — device probes.
// NEEDS-FOUNDER-VERIFY: fresh launch, do NOT press Start → Workstation → Add Audio Track →
// Import Audio → the plate's Save lights → Save → clear the song → the plate's Open → the saved
// project → the track and the part come back and play.

import Foundation
import XCTest

final class TheSongAloneCanBeSavedTests: XCTestCase {

    private static let studioPath = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let sessionPath = "Sources/Echoelmusic/Core/SessionSaveOpen.swift"
    private static let workstationPath = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let workspacePath = "Sources/Echoelmusic/Studio/WorkspaceView.swift"

    // MARK: 1 — the leaf asks the one predicate

    /// ⛔ UNTIL DAW SHELL S3 (2026-10-02) THIS PINNED THE `SaveSessionButton` LEAF, which greyed
    /// the Save tile on the predicate below. S3 moved Save into the ≡ menu, which cannot grey
    /// its entry — it is built in the ROOT body, and reading the document there is the 10.76.50
    /// freeze. So the SAME predicate is now asked by the "save" chrome door at TAP time, and the
    /// alert answers "Nothing to save yet" instead of offering a Save on nothing (#622). Every
    /// needle of the old claim has a stricter successor: the predicate is still the one shared
    /// with the recovery slot (asked, not restated — #416), the Save BUTTONS are reachable only
    /// in the not-empty branch, and the flag is cold `@State`.
    func testTheSaveTileIsEnabledByASongWithTheUsersParts() throws {
        let studio = try code(Self.studioPath)
        XCTAssertFalse(studio.contains("struct SaveSessionButton"),
                       "the Save tile is back beside the ≡ menu's Save — two doors to one alert (DAW shell S3)")
        guard let receiverStart = studio.range(of: "publisher(for: .echoelChromeDoor)) { note in"),
              let saveArm = studio.range(of: "case \"save\":",
                                         range: receiverStart.upperBound..<studio.endIndex),
              let raise = studio.range(of: "showSaveDialog = true",
                                       range: saveArm.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: the chrome door's `case \"save\":` arm (#454)")
        }
        let arm = String(studio[saveArm.upperBound..<raise.lowerBound])
        for needle in ["guard !panelSheetUp else { break }",
                       "saveHasNothing = !(hasComposed",
                       "|| SessionSaveOpen.songHasUserParts(timelineStore.document,",
                       "clips: clipStore.filledClips))"] {
            XCTAssertTrue(arm.contains(needle), """
                the "save" door no longer asks `\(needle)` BEFORE it raises the alert — the #622 \
                gate (never an empty take under a real name) has no other home since the Save \
                tile went with DAW shell S3
                """)
        }
        XCTAssertTrue(studio.contains("@State private var saveHasNothing = false"),
                      "the gate is cold `@State`, written once per tap — never a document read in `body`")
        guard let alert = studio.range(of: ".alert(\"Save piece\", isPresented: $showSaveDialog) {"),
              let empty = studio.range(of: "if saveHasNothing {", range: alert.upperBound..<studio.endIndex),
              let ok = studio.range(of: "Button(\"OK\", role: .cancel) {}", range: empty.upperBound..<studio.endIndex),
              let otherwise = studio.range(of: "} else {", range: ok.upperBound..<studio.endIndex),
              let field = studio.range(of: "TextField(\"Name\", text: $saveName)", range: alert.upperBound..<studio.endIndex),
              let firstSave = studio.range(of: "saveIntoOpenProject()", range: alert.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: the Save alert's empty branch (#454)")
        }
        XCTAssertTrue(empty.upperBound <= ok.lowerBound && ok.upperBound <= otherwise.lowerBound
                      && otherwise.upperBound <= field.lowerBound && field.upperBound <= firstSave.lowerBound, """
            the Save alert offers a name field or a Save button while there is nothing to save — \
            the empty branch must hold only OK, and every writer must sit in the `else`
            """)
        XCTAssertTrue(studio.contains("Text(\"Nothing to save yet. Press Play to compose a loop, or add a part to the piece, then save.\")"),
                      "the empty alert says why nothing is saved and what makes something to save")
    }

    // MARK: 2 — the save carries the song and says so

    func testTheSaveCarriesTheSongAndItsSentenceSaysSo() throws {
        let studio = try code(Self.studioPath)
        XCTAssertTrue(studio.contains("projects.save(withSession(currentProject()))"),
                      "Save must capture the song through `withSession` — an enabled tile that saves only the take is the lie")
        let raw = try text(Self.studioPath)
        XCTAssertTrue(raw.contains("sound and FX character, and the piece — its tracks and parts. "),
                      "the Save message must name the piece it now carries — its tracks and parts (#495: under-claiming is still false; rule 1: the glossary word)")
        // Review of c69af8995 (LOW): a song-only save has no loop, so the message may not open
        // by promising one.
        XCTAssertFalse(raw.contains("Saves the loop with its genre"),
                       "the Save message promises a loop that a song-only save does not have")
        XCTAssertTrue(raw.contains("Saves the composed loop, if there is one, with its genre"),
                      "the Save message says the loop is there only if one was composed")
    }

    // MARK: 3 — counterweight: the composer's part is not the user's

    func testTheComposersOwnPartDoesNotEnableTheSave() throws {
        let session = try code(Self.sessionPath)
        XCTAssertTrue(session.contains("let composed = Set(clips.filter(\\.composerOwned).map(\\.id))"),
                      "songHasUserParts must still skip the composer's own clip — otherwise a plain launch enables Save on nothing (#622)")
        XCTAssertTrue(session.contains("known.contains($0.clipID) && !composed.contains($0.clipID)"),
                      "songHasUserParts must still require a part whose clip is known and not the composer's")
    }

    // MARK: 4 — one Save and one Open for both stages: the ≡ menu, through the chrome door

    /// ⛔ UNTIL DAW SHELL S3 THIS PINNED `WorkstationProjectRow`, the Piece stage's own Save/Open
    /// pair. S3 moved both into the ≡ menu, which leads the bar on BOTH stages — so the row is
    /// pinned ABSENT and the menu is pinned in its place, with the row's two structural laws
    /// carried over: it raises the Studio's OWN alert and sheet through the chrome door (no
    /// presentation modifier of its own — the black-screen budget), and every door it posts has
    /// a receiver case.
    func testTheWorkstationSavesAndOpensThroughTheStudiosOwnSlots() throws {
        let view = try code(Self.workstationPath)
        XCTAssertFalse(view.contains("struct WorkstationProjectRow"),
                       "the Piece stage's own Save/Open row is back beside the ≡ menu — a second door to each (DAW shell S3)")
        XCTAssertFalse(view.contains("object: \"open\""),
                       "the Piece stage posts \"open\" again — the ≡ menu is its one Open")

        let workspace = try code(Self.workspacePath)
        guard let bar = workspace.range(of: "private var topBar: some View {"),
              let menu = workspace.range(of: "Menu {", range: bar.upperBound..<workspace.endIndex),
              let logo = workspace.range(of: "EchoelLogoMark()", range: menu.upperBound..<workspace.endIndex),
              // The MENU's own label, found backwards from the mark it draws — each entry is a
              // `Button { … } label: {` too, so the first `} label: {` would cut at entry one.
              let label = workspace.range(of: "} label: {", options: .backwards,
                                          range: menu.upperBound..<logo.lowerBound) else {
            return XCTFail("ANCHOR MISSING: the ≡ menu in `WorkspaceView.topBar` (#454)")
        }
        let items = String(workspace[menu.upperBound..<label.lowerBound])
        for door in ["save", "open"] {
            XCTAssertEqual(items.components(separatedBy: "Button { Self.postDoor(\"\(door)\") }").count - 1, 1,
                           "the ≡ menu holds exactly one `\(door)` entry")
        }
        XCTAssertFalse(items.contains(".disabled("), """
            a ≡ menu entry is greyed. The menu is built in the root body, so a gate there reads \
            the document at render rate (freeze law); the #622 gate lives in the "save" arm.
            """)
        for modifier in [".sheet(", ".fullScreenCover(", ".alert(", ".confirmationDialog(", ".popover("] {
            XCTAssertFalse(workspace.contains(modifier),
                           "the root presents `\(modifier)` itself — the menu must raise the Studio's existing slot")
        }

        let studio = try code(Self.studioPath)
        guard let receiverStart = studio.range(of: "publisher(for: .echoelChromeDoor)) { note in"),
              let receiverEnd = studio.range(of: "default: break",
                                             range: receiverStart.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: the chrome-door receiver (#454)")
        }
        let receiver = String(studio[receiverStart.upperBound..<receiverEnd.lowerBound])
        for needle in ["case \"save\":", "showSaveDialog = true", "case \"open\":", "showOpen = true"] {
            XCTAssertTrue(receiver.contains(needle),
                          "a posted door with no receiver case is a button that does nothing (#164/#227) — `\(needle)`")
        }
    }

    // MARK: 5 — a song-only row is not shared as an empty take (review of c69af8995, MEDIUM)

    func testASongOnlyRowCannotBeSharedAsAnEmptyTake() throws {
        let studio = try code(Self.studioPath)
        guard let start = studio.range(of: "ShareLink(item: SharedEchoelProject(project: p),") else {
            return XCTFail("ANCHOR MISSING: the library row's ShareLink (#454)")
        }
        let before = String(studio[studio.startIndex..<start.lowerBound].suffix(400))
        let after = String(studio[start.upperBound...].prefix(700))
        XCTAssertTrue(before.contains("let shareable = p.shareCarriesItsContent"),
                      "the row asks `Project.shareCarriesItsContent` — the one rule, next to `sharedDocumentData`")
        for needle in [".disabled(!shareable)", ".opacity(shareable ? 1 : 0.35)"] {
            XCTAssertTrue(after.contains(needle),
                          "the share control lost `\(needle)` — the dim state must track `.disabled` (#482)")
        }
        let project = try code("Sources/Echoelmusic/Core/Project.swift")
        XCTAssertTrue(project.contains("!(notes.isEmpty && rawTake == nil && sessionEnvelope != nil)"),
                      "the rule is: nothing in the take AND a song that sharing would strip")
    }

    // MARK: helpers

    private func text(_ relativePath: String) throws -> String {
        guard let text = try? String(contentsOf: repoRoot().appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            return ""
        }
        return text
    }

    private func code(_ relativePath: String) throws -> String {
        SourceText.codeOnly(try text(relativePath))
    }

    private func repoRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        return url
    }
}
