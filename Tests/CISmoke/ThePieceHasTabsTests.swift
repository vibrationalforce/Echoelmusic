// ThePieceHasTabsTests.swift
// Echoel — the Piece stage carries a row of tabs above the arrangement: Arrange · Sound · FX ·
// Master (Workstation redesign A7, founder 2026-10-01).
//
// WHY: the tablet mockup the founder pointed at („Das angehängte Bild gefällt mir auch") puts
// the workstation's areas in one tab row above the arrangement. On the Piece stage the panels
// that shape the sound lived one stage away behind a seam a new player does not read as a door.
// A7 adds the row WITHOUT a second copy of any panel and WITHOUT a modal: Sound, FX and Master
// post the existing chrome door, whose receiver opens the panel AND turns the Instrument stage
// (the slice-2b nothing-button law). Export is deliberately NOT a tab: a song export (B4) does not
// exist yet, and a tab with no destination is a button that does nothing (#164/#227).
// ⭐ B3 (2026-10-01) made the plate TWO views — Arrange and Mix — so Arrange stopped being a
// passive tile: it is the button that brings the arrangement back from the mixer. A7's law
// survives in its sharper form: each plate tab sets ITS plate, the current one says selected,
// and neither posts a door (the mixer is `PieceMixerView` on this plate, not a panel elsewhere).
//
// THE THREE CLAIMS:
// 1. `WorkstationView` pins `pieceTabs` above the plate's scroll (`.safeAreaInset(edge: .top)`);
//    Arrange and Mix come FIRST, each sets its own plate and carries `.isSelected` only while it
//    is the current one; the three posts are literal; Mix and FX follow the Instrument strip's
//    `showsSongs` gate, Master its `showsProTabs` gate.
// 2. The receiver handles `"effects"` and `"master"` — each opens its panel and turns the stage.
// 3. Counterweights — no Mix or Export POSTER on the piece, no presentation modifier added to
//    `WorkstationView` (the black-screen law), the row is solid with a 1-px border (Uncodixfy),
//    and every tab's visible word is in its spoken label (TheIconTileCarriesAWordTests' rule).
//
// GRADING (§0/§3, no Swift toolchain in a web session — transcribed in Python against both
// trees): all claims are SOURCE-TEXT scans. Parent tree: claims 1–2 red by ABSENCE of
// `pieceTabs` and the two cases — one absence (#486); claim 3 is COUNTERWEIGHTS, green on both
// except its two bar needles, which read `pieceTabs` and belong to claim 1's absence. B3 re-grade
// against A7's tree (7303c048a): claim 1's plate-tab needles (`plate = .arrange`, `plate = .mix`,
// the two conditional traits, the Mix word) are red there by ABSENCE of the plate state — one
// absence (#486); the ban on an UNCONDITIONAL `.isSelected` is a REGRESSION there, red for its
// named reason (A7's tile carried it, correctly while the plate had one view); the three posts,
// the gates and claims 2–3 stay green on both. DEVICE PROBE,
// open: the row reads as tabs, Mix shows the strips and Arrange brings the canvas back, FX/Master
// land on their panel, and „Piece" brings the player back — readings, not scans.

import XCTest

final class ThePieceHasTabsTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    // MARK: 1 — the row is pinned above the plate, Arrange is where you are

    func testThePieceTabsArePinnedAboveThePlate() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        let body = try member("var body: some View {", in: code)
        XCTAssertTrue(body.contains(".safeAreaInset(edge: .top, spacing: 0) { pieceTabs }"),
                      "the tabs are pinned above the scroll, like the transport below it (A3)")

        let tabs = try member("private var pieceTabs: some View {", in: code)
        XCTAssertTrue(code.contains("@State private var plate: PlateView = .arrange"),
                      "the plate opens on the arrangement — the mixer is one tap away, never the default")
        guard let arrange = tabs.range(of: "plate = .arrange"),
              let mix = tabs.range(of: "plate = .mix"),
              let firstPost = tabs.range(of: "NotificationCenter.default.post(") else {
            return XCTFail("ANCHOR MISSING: the two plate tabs or the first door post (#454)")
        }
        XCTAssertLessThan(arrange.lowerBound, mix.lowerBound, "Arrange is the first tab, Mix the second")
        XCTAssertLessThan(mix.lowerBound, firstPost.lowerBound, """
            the plate tabs come before the door tabs — the two that change THIS surface sit together, \
            ahead of the three that turn the stage
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

        for door in ["sound", "effects", "master"] {
            XCTAssertEqual(tabs.components(separatedBy:
                "NotificationCenter.default.post(name: .echoelChromeDoor, object: \"\(door)\")").count - 1, 1,
                "the \(door) tab posts the chrome door exactly once, literally (the producer census reads it)")
        }
        guard let mixGate = tabs.range(of: "if level.showsSongs {"),
              let mixTab = tabs.range(of: "plate = .mix"),
              let fxGate = tabs.range(of: "if level.showsSongs {", options: .backwards),
              let fx = tabs.range(of: "object: \"effects\""),
              let masterGate = tabs.range(of: "if level.showsProTabs {"),
              let master = tabs.range(of: "object: \"master\"") else {
            return XCTFail("ANCHOR MISSING: a SkillLevel gate or the FX/Master post (#454)")
        }
        XCTAssertLessThan(mixGate.lowerBound, mixTab.lowerBound, """
            Mix follows the strip's `showsSongs` gate — the same level that first shows a song's \
            parts shows its mixer
            """)
        XCTAssertLessThan(fxGate.lowerBound, fx.lowerBound,
                          "FX follows the strip's `showsSongs` gate — a beginner sees the same panels here as there")
        XCTAssertLessThan(masterGate.lowerBound, master.lowerBound,
                          "Master follows the strip's `showsProTabs` gate")
        XCTAssertTrue(code.contains("@AppStorage(StudioDefaultKeys.skillLevel.key)"),
                      "the level is read through the ONE key (#416)")
    }

    // MARK: 2 — the receiver opens each panel and turns the stage

    func testTheReceiverOpensEachTabsPanel() throws {
        let studio = SourceText.codeOnly(try text(Self.studio))
        guard let start = studio.range(of: "publisher(for: .echoelChromeDoor)) { note in"),
              let end = studio.range(of: "default: break", range: start.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: the chrome-door receiver (#454)")
        }
        let receiver = String(studio[start.upperBound..<end.lowerBound])
        for (door, menu) in [("effects", ".effects"), ("master", ".master")] {
            guard let caseStart = receiver.range(of: "case \"\(door)\":") else {
                XCTFail("the receiver has no `case \"\(door)\":` — the tab would be a button that does nothing")
                continue
            }
            let tail = receiver[caseStart.upperBound...]
            let next = tail.range(of: "case \"")?.lowerBound ?? tail.endIndex
            let arm = tail[..<next]
            XCTAssertTrue(arm.contains("activeMenu = \(menu)"), "`\(door)` opens its own panel")
            XCTAssertTrue(arm.contains("showStage(.instrument)"), """
                `\(door)` must turn the Instrument stage — its poster sits on the Piece stage, \
                where the studio is hidden (slice 2b's first measured defect).
                """)
        }
    }

    // MARK: 3 — counterweights: no dead tab, no modal, solid chrome, words spoken

    func testThePieceTabsAddNoDeadTabAndNoModal() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        for dead in ["object: \"mix\"", "object: \"mixer\"", "object: \"export\""] {
            XCTAssertFalse(code.contains(dead), """
                `\(dead)` is posted from the piece — the mixer (B3) is a view of THIS plate, not a \
                door to another surface, and a song export (B4) does not exist yet. A tab with no \
                destination is a button that does nothing.
                """)
        }
        XCTAssertTrue(code.contains("PieceMixerView(voiceCapacity: player.laneVoiceCapacity)"),
                      "the Mix tab has its destination on this plate — the tab is not a dead button")
        let tabs = try member("private var pieceTabs: some View {", in: code)
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert("] {
            XCTAssertFalse(tabs.contains(modal), "the tabs open panels through the door, never a modal (black-screen law)")
        }
        XCTAssertTrue(tabs.contains(".background(EchoelTheme.bg)"), "a solid row — no blur, no glass")
        XCTAssertTrue(tabs.contains("Rectangle().fill(EchoelTheme.border).frame(height: 1)"),
                      "a 1-px border separates it from the plate")
        XCTAssertFalse(tabs.contains(".shadow("), "no shadow layer (Uncodixfy)")
        for word in ["Arrange", "Mix", "Sound", "FX", "Master"] {
            XCTAssertTrue(tabs.contains("title: \"\(word)\""), "the \(word) tab shows its word")
            XCTAssertTrue(tabs.contains(".accessibilityLabel(\"\(word)\")"),
                          "and says the same word to VoiceOver (Label in Name)")
        }
    }

    // MARK: helpers

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
