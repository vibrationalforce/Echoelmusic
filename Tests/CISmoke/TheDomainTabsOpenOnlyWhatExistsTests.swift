// TheDomainTabsOpenOnlyWhatExistsTests.swift
// Echoel — the Piece stage carries a row of DOMAINS above its tabs: Music · Visual · Light
// (Workstation redesign C5, founder 2026-10-01, FOUNDER_INBOX H5; the plan's wording:
// "Music · Visual · Light · Space (Space = ADM-OSC-Steuerung). Stream und XR bleiben weg").
//
// WHY: a tab with no target is a dead button (#164/#227). The founder asked for four domains;
// three have a destination on a reachable surface TODAY, and only those three are built:
// · Music  — where you are (the arrangement and `pieceTabs` below). A MARKER, not a button, for
//            A7's Arrange-tile reason: with nothing to switch to, a button opens what is open.
// · Visual — the chrome door "field" → the Field panel (`visualPanel`) on the Instrument stage.
//            UNGATED: the Instrument's area row reaches the same plate at every level
//            (`areaBar` iterates `StudioArea.allCases` unfiltered, `.visuals` → `.field`), and so
//            does the header's visual tile; a level gate here would hide from the piece what the
//            instrument already offers.
// · Light  — the chrome door "routing" → Routing (`PatchbayView`, whose `lichtSection` holds
//            master, blackout, DMX resolution and fixtures), the door the header's light monitor
//            already posts. The receiver now refuses while a medium-detent sheet is up (FX, Live
//            Colabo) — never two modals true at once.
// ⛔ Space is NOT built: the only spatial control on a reachable surface is the ADM-OSC row
// inside Routing (a second word for Light's door), and `ImmersiveStageView` is doorless by ship
// gate 4. Claim 4 forbids the word in the row; it is a ratchet with an instruction, not a ban
// on C4 (#364) — C4 adds Space TOGETHER with its target and edits that one needle.
//
// THE FOUR CLAIMS:
// 1. `domainTabs` is pinned by its own top inset AFTER `pieceTabs`' (a later inset sits outside,
//    i.e. above); Music comes first, posts nothing, is the ONE element that says selected, and
//    the row reads no state (freeze law).
// 2. Exactly two literal posts, neither behind a level gate — and the Instrument's area row,
//    which reaches the same Field plate, is itself ungated (the counterweight that makes
//    "ungated" the consistent choice).
// 3. The receiver handles both: "field" opens `.field` and turns the Instrument stage; "routing"
//    raises the existing routing slot only while neither medium-detent sheet is up. The two
//    destinations are real: `.field` builds `visualPanel`, the routing slot builds
//    `PatchbayView`, and `PatchbayView`'s `content` mounts `lichtSection`.
// 4. Counterweights — no Space/Stream/XR word, no `ImmersiveStageView`, no presentation modifier
//    in the row (the black-screen law), a solid row, and each visible word is its spoken label.
//
// GRADING (§0/§3 — no Swift toolchain in a web session; transcribed in Python against the
// parent tree d05aa750f and the C5 tree): all claims are SOURCE-TEXT scans. Parent tree:
// claims 1, 2 and 4 are red by ABSENCE of `domainTabs` — one absence (#486); claim 2's two
// area-row needles are COUNTERWEIGHTS, green on both. Claim 3: the "field" arm is red by ABSENCE
// of the case (the receiver half of the same absence); the "routing" arm's two refusal needles
// (`!showAllFX`, `!showLiveColabo`) are REGRESSIONS, red there for their named reason — the door
// raised the sheet unconditionally; `showRouting = true` and the destination needles are
// COUNTERWEIGHTS, green on both. Nothing here is a forward guard over a new type.
// DEVICE PROBE, open: the two rows read as two levels; Visual lands on the Field panel and
// "Piece" brings the player back; Light opens Routing over the piece; every level sees
// Music · Visual · Light; VoiceOver says "Music, selected"; German shows Musik · Visual · Licht
// untruncated at the largest type size; in landscape on the smallest phone the arrangement keeps
// usable height; with FX open at medium detent a Light tap does nothing and nothing freezes —
// readings, not scans.

import XCTest

final class TheDomainTabsOpenOnlyWhatExistsTests: XCTestCase {

    private static let workstation = "Sources/Echoelmusic/Studio/WorkstationView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let patchbay = "Sources/Echoelmusic/Studio/PatchbayView.swift"
    private static let post = "NotificationCenter.default.post(name: .echoelChromeDoor, object: "

    // MARK: 1 — the domains sit above the tabs, Music is where you are, nothing hot is read

    func testTheDomainsArePinnedAboveThePieceTabs() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        let body = try member("var body: some View {", in: code)
        guard let tabs = body.range(of: ".safeAreaInset(edge: .top, spacing: 0) { pieceTabs }"),
              let domains = body.range(of: ".safeAreaInset(edge: .top, spacing: 0) { domainTabs }") else {
            return XCTFail("ANCHOR MISSING: the pinned `pieceTabs` or `domainTabs` inset (#454)")
        }
        XCTAssertLessThan(tabs.lowerBound, domains.lowerBound, """
            the domains' inset must come AFTER the tabs' — a later `.safeAreaInset(edge: .top)` is \
            placed outside the earlier one, so this order is what puts the domains ABOVE the tabs
            """)

        let row = try member("private var domainTabs: some View {", in: code)
        guard let music = row.range(of: "Text(\"Music\")"),
              let firstButton = row.range(of: "Button {") else {
            return XCTFail("ANCHOR MISSING: the Music marker or the first door button in `domainTabs` (#454)")
        }
        XCTAssertLessThan(music.lowerBound, firstButton.lowerBound, "Music is the first domain")
        XCTAssertFalse(row[row.startIndex..<firstButton.lowerBound].contains("NotificationCenter"), """
            Music posts a door — but it is where the player already is. A button that opens what \
            is already open is the A7 Arrange-tile mistake.
            """)
        XCTAssertEqual(row.components(separatedBy: ".accessibilityAddTraits(").count - 1, 1, """
            exactly one element of the row carries a trait — Music's `.isSelected`. A door that \
            says selected would tell VoiceOver the player is somewhere they are not.
            """)
        XCTAssertTrue(row.contains(".accessibilityAddTraits(.isSelected)"), """
            Music says selected to VoiceOver — never colour or an underline alone. Unconditional \
            is honest: this row exists only on the Piece stage.
            """)
        for read in ["player.", "transport.", "cameraRPPG", "bus.", "level.", "skillLevelRaw"] {
            XCTAssertFalse(row.contains(read), """
                the domain row reads `\(read)`. It is pinned in `WorkstationView.body`, an ancestor \
                of the plate's pickers; a hot read here is the 10.76.41/50 freeze, and a level read \
                re-introduces the gate this slice measured as inconsistent (claim 2).
                """)
        }
    }

    // MARK: 2 — two doors, each literal, neither gated — like the area row that reaches the same plate

    func testTheDomainRowPostsExactlyTwoUngatedDoors() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        let row = try member("private var domainTabs: some View {", in: code)
        for door in ["field", "routing"] {
            XCTAssertEqual(row.components(separatedBy: Self.post + "\"\(door)\")").count - 1, 1,
                           "the row posts `\(door)` exactly once, literally (the producer census reads it)")
        }
        XCTAssertEqual(row.components(separatedBy: "object: \"").count - 1, 2, """
            the row posts exactly two doors. A third is a new domain, and a domain is added \
            TOGETHER with a reachable destination — Space waits for C4 (#164/#227).
            """)
        XCTAssertFalse(row.contains("if "), """
            a domain sits behind a condition. The Instrument's area row reaches the Field plate at \
            every level and the header's light monitor reaches Routing at every level; a gate here \
            would hide from the piece what the instrument already offers.
            """)

        let studio = SourceText.codeOnly(try text(Self.studio))
        let bar = try member("private var areaBar: some View {", in: studio)
        XCTAssertTrue(bar.contains("ForEach(StudioArea.allCases) { areaButton($0, sharesRow: true) }"),
                      "the area row still offers every area — the reason Visual is ungated here")
        XCTAssertFalse(bar.contains("level"), """
            the area row now filters by level. Then the Visual domain's reason for being ungated is \
            gone — re-decide the gate here in the same commit.
            """)
        let home = try member("private static func areaHome(_ area: StudioArea) -> StudioMenu? {", in: studio)
        XCTAssertTrue(home.contains("case .visuals:  return .field"),
                      "the Visuals area still opens the Field plate — the same destination as the Visual domain")
    }

    // MARK: 3 — both doors land, and their destinations are real

    func testBothDoorsLandOnARealDestination() throws {
        let studio = SourceText.codeOnly(try text(Self.studio))
        guard let start = studio.range(of: "publisher(for: .echoelChromeDoor)) { note in"),
              let end = studio.range(of: "default: break", range: start.upperBound..<studio.endIndex) else {
            return XCTFail("ANCHOR MISSING: the chrome-door receiver (#454)")
        }
        let receiver = String(studio[start.upperBound..<end.lowerBound])
        func arm(_ door: String) -> Substring? {
            guard let caseStart = receiver.range(of: "case \"\(door)\":") else { return nil }
            let tail = receiver[caseStart.upperBound...]
            let next = tail.range(of: "case \"")?.lowerBound ?? tail.endIndex
            return tail[..<next]
        }
        if let field = arm("field") {
            XCTAssertTrue(field.contains("activeMenu = .field"), "`field` opens the Field panel")
            XCTAssertTrue(field.contains("showStage(.instrument)"), """
                `field` must turn the Instrument stage — its poster sits on the Piece stage, where \
                the studio is hidden (slice 2b's first measured defect)
                """)
        } else {
            XCTFail("the receiver has no `case \"field\":` — the Visual tab would be a button that does nothing")
        }
        if let routing = arm("routing") {
            XCTAssertTrue(routing.contains("showRouting = true"), "`routing` raises the EXISTING routing slot")
            for refusal in ["!showAllFX", "!showLiveColabo"] {
                XCTAssertTrue(routing.contains(refusal), """
                    `routing` raises its sheet without `\(refusal)`. The Light tab posts from the \
                    Piece stage, where a medium-detent sheet can still be up; driving a second \
                    modal true is the invisible tap-blocking layer (the two-modals hang). \
                    `selectArea` keeps the same guard.
                    """)
            }
        } else {
            XCTFail("the receiver has no `case \"routing\":` — the Light tab and the header light monitor would both be dead")
        }

        XCTAssertTrue(studio.contains("case .field:       return AnyView(visualPanel)"),
                      "the Field plate still builds `visualPanel` — the Visual tab's destination")
        XCTAssertTrue(studio.contains(".sheet(isPresented: $showRouting) { AnyView(PatchbayView("),
                      "the routing slot still builds `PatchbayView` — the Light tab's destination")
        let patchbay = SourceText.codeOnly(try text(Self.patchbay))
        XCTAssertTrue(patchbay.contains("private var lichtSection: some View {"),
                      "Routing still holds the light card")
        let content = try member("private var content: some View {", in: patchbay)
        XCTAssertTrue(content.contains("lichtSection"),
                      "and Routing's content still mounts it — a declared card nobody shows is not the Light destination")
    }

    // MARK: 4 — counterweights: no promised domain, no modal, solid chrome, words spoken

    func testTheDomainRowPromisesNothingThatIsNotThere() throws {
        let code = SourceText.codeOnly(try text(Self.workstation))
        let row = try member("private var domainTabs: some View {", in: code)
        for word in ["Space", "Stream", "XR"] {
            XCTAssertFalse(row.contains("\"\(word)\""), """
                the row shows `\(word)`. Stream and XR stay out (H5). Space arrives with C4 and its \
                target — the only spatial control reachable today is the ADM-OSC row inside \
                Routing, which Light already opens. When C4 lands, add Space AND its door in one \
                commit and drop it from this list.
                """)
        }
        XCTAssertFalse(row.contains("ImmersiveStageView"),
                       "the spatial stage stays doorless (ship gate 4) — the row must not open it")
        for modal in [".sheet(", ".fullScreenCover(", ".popover(", ".alert("] {
            XCTAssertFalse(row.contains(modal), "the domains open through the door, never a modal (black-screen law)")
        }
        XCTAssertTrue(row.contains(".background(EchoelTheme.bg)"), "a solid row — no blur, no glass")
        XCTAssertFalse(row.contains(".shadow("), "no shadow layer (Uncodixfy)")
        for word in ["Music", "Visual", "Light"] {
            XCTAssertTrue(row.contains("Text(\"\(word)\")"), "the \(word) domain shows its word")
            XCTAssertTrue(row.contains(".accessibilityLabel(\"\(word)\")"),
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
