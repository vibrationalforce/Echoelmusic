// ThePieceHasTabsTests.swift
// Echoel — the Piece stage carries a row of tabs above the arrangement: Arrange · Mix · Export
// (Workstation redesign A7, founder 2026-10-01; slice B the same day).
//
// WHY: the tablet mockup the founder pointed at („Das angehängte Bild gefällt mir auch") puts
// the workstation's areas in one tab row above the arrangement. A7 built it WITHOUT a second copy
// of any panel and WITHOUT a modal. Export was deliberately NOT a tab while no song export existed
// — a tab with no destination is a button that does nothing (#164/#227). ⭐ B4 (2026-10-01) gave it
// one: `SongExportTab`, a `ShareLink` in its own leaf, behind its own `showsSongs` gate (its
// behaviour and its door: `ThePieceExportsTheSongAsMIDITests`). UX audit 2026-10-02 added two tiles
// after it: the WAV door in the same gate (slice 10b, `ThePieceHasAWavDoorTests`) and, last and at
// every level, the Add menu (slice 4, `TheAddMenuHoldsTheCreationDoorsTests`) — both act in place. It posts nothing, so the
// ban on an `"export"` POSTER below still holds — the share sheet is the destination.
// ⭐ B3 (2026-10-01) made the plate TWO views — Arrange and Mix — so Arrange stopped being a
// passive tile: it is the button that brings the arrangement back from the mixer. Each plate tab
// sets ITS plate, the current one says selected, and neither posts a door.
// ⭐ SLICE B (founder order 2026-10-01: „Vermeide das es mehrfache Wege zu einem Bereich gibt …
// Vermeide slop"). A7 also put Sound, FX and Master in this row as tiles that posted the chrome
// door and JUMPED to the Instrument stage. Each was a SECOND door: FX and Master are chips of the
// Instrument strip (`studioChips`, same `showsSongs`/`showsProTabs` gates), Sound is a chip AND the
// Echoel track's device door (`TrackInspectorView.openDeviceButton`). Slice B removed the three
// tiles and their two receiver cases; the row's law is now the sharper one — EVERY TAB ACTS IN
// PLACE: no tab here posts the chrome door, none turns the stage. FX and Master are one seam tap
// („Instrument") plus their chip away, at the same levels as before — a measured cost, accepted.
//
// THE THREE CLAIMS (per-claim history of the slice-B rewrite at the end of this header):
// 1. `WorkstationView` pins `pieceTabs` above the plate's scroll (`.safeAreaInset(edge: .top)`);
//    Arrange, Mix and Export stand in that order; each plate tab sets its own plate and carries
//    `.isSelected` only while it is the current one; Mix follows the Instrument strip's
//    `showsSongs` gate; and the row posts NOTHING (no `NotificationCenter`, no `.echoelChromeDoor`).
// 2. The stage-jumping cases left with their tiles: the receiver has no `case "effects":` and no
//    `case "master":`, no file in `Sources/` posts either string, and both panels keep their door
//    on the Instrument stage (`.effects` and `.master` stay in `studioChips`, behind their gates).
// 3. Counterweights — no Mix or Export POSTER on the piece (Export is a `ShareLink`, B4), no
//    presentation modifier added to the row (the black-screen law), the row is solid with a 1-px
//    border (Uncodixfy), every plate tab's visible word is in its spoken label, the row reads no
//    hot state (it is pinned in `WorkstationView.body`, an ancestor of the plate's pickers — the
//    10.76.41/50 freeze), and it names no Space, Stream or XR tab (H5: Stream and XR stay out;
//    Space arrives with C4a-2 and a landing of its own).
//
// SLICE-B REWRITE, per claim (nothing weakened; two claims inverted from "the door exists" to
// "the twin is gone", one counterweight narrowed to the words that still exist):
// · claim 1 — KEPT: the inset, the plate default, Arrange-before-Mix, both conditional traits, the
//   ban on an unconditional `.isSelected`, the Mix gate, the one level key. CHANGED: "the plate
//   tabs come before the door tabs" became "Mix comes before Export" (there are no door tabs);
//   "the three posts are literal, exactly once" became "the row posts nothing"; the FX and Master
//   gate needles are gone with their tiles (their gates now live only in `chips(for:)`, which
//   `TheChipStripFollowsTheSkillLevelTests` pins).
// · claim 2 — INVERTED: it pinned that the receiver opens `"effects"`/`"master"` and turns the
//   stage; with no poster left those cases would be the #290/#492 hook-without-a-producer, so it
//   now pins their ABSENCE plus the panels' surviving Instrument doors (the honest half of
//   "nothing was lost").
// · claim 3 — KEPT except the word list: Sound, FX and Master are no longer words of this row.
//   Export's word lives in `SongExportTab` and is pinned by `ThePieceExportsTheSongAsMIDITests`.
//   GAINED two laws the deleted domain-row guard carried for the row ABOVE this one, restated
//   here for the one top row that is left instead of dropped with their row: the hot-read ban
//   (minus the level key, which this row reads legitimately and COLD) and the Space/Stream/XR ban.
//
// GRADING (§0/§3, no Swift toolchain in a web session — transcribed in Python against both
// trees): all claims are SOURCE-TEXT scans. Against the parent (A7+B3+B4+C5 tree): claim 1's two
// no-post needles (`NotificationCenter`, `.echoelChromeDoor`) are REGRESSIONS, red there for their
// named reason (three literal posts sit in the row); every other claim-1 needle, including
// Mix-before-Export, is green on both. Claim 2's three absence assertions (two cases, the poster
// walk) are REGRESSIONS, red there for their named reason; its `"sound"` anchor and two chip
// counterweights are green on both. Claim 3 is green on both (the two laws it gained are
// COUNTERWEIGHTS — `pieceTabs` read no hot state and named no Space tab on the parent either).
// Against this tree: all green
// (Python transcription, 66 checks over the five touched guards). DEVICE PROBE, open: the row
// reads Arrange · Mix · Export at Pro level, Mix shows the strips and Arrange brings the canvas
// back, and „Instrument" then the FX/Master chip reaches what the removed tiles reached.

import XCTest

final class ThePieceHasTabsTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let sourcesRoot = "Sources/Echoelmusic"

    // MARK: 1 — the row is pinned above the plate, and every tab acts in place

    func testThePieceTabsArePinnedAboveThePlateAndActInPlace() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        let body = try member("var body: some View {", in: code)
        XCTAssertTrue(body.contains(".safeAreaInset(edge: .top, spacing: 0) { pieceTabs }"),
                      "the tabs are pinned above the scroll, like the transport below it (A3)")

        let tabs = try member("private var pieceTabs: some View {", in: code)
        XCTAssertTrue(code.contains("@State private var plate: PlateView = .arrange"),
                      "the plate opens on the arrangement — the mixer is one tap away, never the default")
        guard let arrange = tabs.range(of: "plate = .arrange"),
              let mix = tabs.range(of: "plate = .mix"),
              let export = tabs.range(of: "SongExportTab()") else {
            return XCTFail("ANCHOR MISSING: the two plate tabs or the export tab (#454)")
        }
        XCTAssertLessThan(arrange.lowerBound, mix.lowerBound, "Arrange is the first tab, Mix the second")
        XCTAssertLessThan(mix.lowerBound, export.lowerBound, """
            Export comes after Mix — the two that switch THIS plate sit together, ahead of the one \
            that hands the piece away
            """)
        for (view, word) in [(".arrange", "Arrange"), (".mix", "Mix")] {
            XCTAssertTrue(tabs.contains("prominent: plate == \(view)"),
                          "the \(word) tile is filled only while \(word) is the current plate")
            XCTAssertTrue(tabs.contains(".accessibilityAddTraits(plate == \(view) ? .isSelected : [])"), """
                VoiceOver hears which plate is the current one — never colour alone, and never \
                `.isSelected` on both tabs at once
                """)
        }
        XCTAssertFalse(tabs.contains(".accessibilityAddTraits(.isSelected)"),
                       "an UNCONDITIONAL selected trait would call a tab current while the other plate shows")

        for door in ["NotificationCenter", ".echoelChromeDoor", "showStage("] {
            XCTAssertFalse(tabs.contains(door), """
                the piece's tab row contains `\(door)`. Every tab here acts IN PLACE (slice B, \
                founder 2026-10-01: one door per area): a tile that jumps to the Instrument stage \
                is a second door to a panel whose chip is already one seam tap away. If a new tab \
                genuinely needs another surface, remove its twin in the same commit and rewrite \
                this claim to name both (#364).
                """)
        }
        guard let mixGate = tabs.range(of: "if level.showsSongs {"),
              let mixTab = tabs.range(of: "plate = .mix") else {
            return XCTFail("ANCHOR MISSING: the Mix tab's SkillLevel gate (#454)")
        }
        XCTAssertLessThan(mixGate.lowerBound, mixTab.lowerBound, """
            Mix follows the strip's `showsSongs` gate — the same level that first shows a song's \
            parts shows its mixer
            """)
        XCTAssertTrue(code.contains("@AppStorage(StudioDefaultKeys.skillLevel.key)"),
                      "the level is read through the ONE key (#416)")
    }

    // MARK: 2 — the stage-jumping cases left with their tiles; the panels keep their own doors

    func testTheStageJumpingTabsLeftAndTheirPanelsKeepTheirChips() throws {
        let studio = SourceText.codeOnly(try text(Self.studio))
        guard let start = studio.range(of: "publisher(for: .echoelChromeDoor)) { note in"),
              let end = studio.range(of: "default: break", range: start.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: the chrome-door receiver (#454)")
        }
        let receiver = String(studio[start.upperBound..<end.lowerBound])
        XCTAssertTrue(receiver.contains("case \"sound\":"), """
            ANCHOR: the receiver's surviving `"sound"` case is gone — an absence scan over a \
            receiver that lost everything is the #343 trap, so this anchors on a case that MUST stay
            """)
        for door in ["effects", "master"] {
            XCTAssertFalse(receiver.contains("case \"\(door)\":"), """
                `case "\(door)":` is back in the chrome-door receiver. Its only poster was the \
                piece's \(door == "effects" ? "FX" : "Master") tile, removed by slice B as a second \
                door. A case with no poster compiles silently and reads like a live hook (#290/#492) \
                — re-add it only TOGETHER with a poster that is not a twin of the chip.
                """)
        }

        let posters = try postersInSources(of: ["effects", "master"])
        XCTAssertTrue(posters.isEmpty, """
            `.echoelChromeDoor` posts \(posters) — a door with no receiver case is a button that \
            does nothing (#164/#227), and a door WITH one is the second door slice B removed.
            """)

        guard let declaration = studio.range(of: "private static let studioChips: [StudioMenu] ="),
              let opening = studio.range(of: "[", range: declaration.upperBound..<studio.endIndex),
              let closing = studio.range(of: "]", range: opening.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: the Instrument strip `studioChips` (#454)")
        }
        let strip = studio[opening.upperBound..<closing.lowerBound]
        for chip in [".effects", ".master"] {
            XCTAssertTrue(strip.contains(chip), """
                `\(chip)` left the Instrument strip — with the piece's tile gone too, that panel \
                would have NO door at all. The tile was removed BECAUSE this chip exists.
                """)
        }
    }

    // MARK: 3 — counterweights: no dead tab, no modal, solid chrome, words spoken

    func testThePieceTabsAddNoDeadTabAndNoModal() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        for dead in ["object: \"mix\"", "object: \"mixer\"", "object: \"export\""] {
            XCTAssertFalse(code.contains(dead), """
                `\(dead)` is posted from the piece — the mixer (B3) is a view of THIS plate, not a \
                door to another surface, and the song export (B4) is a `ShareLink` whose share \
                sheet is its destination. A posted door with no receiver is a button that does nothing.
                """)
        }
        XCTAssertTrue(code.contains("PieceMixerView(voiceCapacity: player.laneVoiceCapacity)"),
                      "the Mix tab has its destination on this plate — the tab is not a dead button")
        XCTAssertTrue(code.contains("SongExportTab()"),
                      "the Export tab has its destination — the share sheet of its own `ShareLink` (B4)")
        let tabs = try member("private var pieceTabs: some View {", in: code)
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert("] {
            XCTAssertFalse(tabs.contains(modal), "the tabs act in place, never through a modal (black-screen law)")
        }
        XCTAssertTrue(tabs.contains(".background(EchoelTheme.bg)"), "a solid row — no blur, no glass")
        XCTAssertTrue(tabs.contains("Rectangle().fill(EchoelTheme.border).frame(height: 1)"),
                      "a 1-px border separates it from the plate")
        XCTAssertFalse(tabs.contains(".shadow("), "no shadow layer (Uncodixfy)")
        for word in ["Arrange", "Mix"] {
            XCTAssertTrue(tabs.contains("title: \"\(word)\""), "the \(word) tab shows its word")
            XCTAssertTrue(tabs.contains(".accessibilityLabel(\"\(word)\")"),
                          "and says the same word to VoiceOver (Label in Name)")
        }
        for read in ["player.", "transport.", "metronome.", "cameraRPPG", "bus."] {
            XCTAssertFalse(tabs.contains(read), """
                the piece's tab row reads `\(read)`. It is pinned in `WorkstationView.body`, an \
                ancestor of the plate's pickers; a hot read here is the 10.76.41/50 freeze. Read it \
                in a leaf, the way `SongExportTab` reads the tempo mirror in its own body.
                """)
        }
        for word in ["Space", "Stream", "XR"] {
            XCTAssertFalse(tabs.contains("\"\(word)\""), """
                the row shows `\(word)`. Stream and XR stay out (H5: no HaishinKit, no visionOS \
                target). Space arrives with C4a-2 and a landing of its own — never as a twin of the \
                header light tile's Routing door (slice B). Add it AND its landing in one commit.
                """)
        }
    }

    // MARK: helpers

    /// Every file under `Sources/Echoelmusic` whose CODE posts the chrome door with one of `doors`.
    /// A walk that saw too few files is a finding, never a pass.
    private func postersInSources(of doors: [String]) throws -> [String] {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let base = root.appendingPathComponent(Self.sourcesRoot)
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            XCTFail("cannot enumerate \(Self.sourcesRoot) — a scan that saw nothing is not a pass")
            return []
        }
        var found: [String] = []
        var seen = 0
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            seen += 1
            guard let raw = try? String(contentsOf: base.appendingPathComponent(relative), encoding: .utf8)
            else { continue }
            let code = SourceText.codeOnly(raw)
            for door in doors
            where code.contains("NotificationCenter.default.post(name: .echoelChromeDoor, object: \"\(door)\")") {
                found.append("\(relative) → \"\(door)\"")
            }
        }
        XCTAssertGreaterThan(seen, 200, "the walk saw \(seen) files — the wrong directory")
        return found
    }

    /// The brace-matched body after `anchor` (#408); string-literal aware.
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            return ""
        }
        var depth = 1
        var index = start.upperBound
        var inString = false
        while index < code.endIndex {
            let ch = code[index]
            if inString, ch == "\\" {
                index = code.index(after: index)
                if index < code.endIndex { index = code.index(after: index) }
                continue
            }
            if ch == "\"" { inString.toggle() }
            if !inString {
                if ch == "{" { depth += 1 }
                if ch == "}" {
                    depth -= 1
                    if depth == 0 { return String(code[start.upperBound..<index]) }
                }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: `\(anchor)` never closes (#454)")
        return ""
    }

    private func text(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
