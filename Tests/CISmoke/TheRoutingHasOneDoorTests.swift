// TheRoutingHasOneDoorTests.swift
// Echoel — Routing (`PatchbayView`: MIDI pairing, the MIDI out switches, the OSC / Art-Net / sACN /
// spatial-audio targets, the light master) has exactly ONE door, and it is the head's light tile
// (slice G, founder order 2026-10-01: „Vermeide das es mehrfache Wege zu einem Bereich gibt und das
// es so unübersichtlich ist.").
//
// WHAT STOOD BEFORE, measured on the parent tree: THREE doors to one sheet.
// · the head's light tile `EchoelLuxMonitorMini` (`HeaderMonitors`) → chrome door `"routing"` →
//   the receiver arm in `EchoelStudioView` — rendered by `WorkspaceView.topBar`, i.e. on BOTH stages
//   (Piece and Instrument) and at EVERY skill level;
// · the bio panel's „Open Routing" button — Instrument stage only, behind the pulse pill, in a room
//   whose subject is the body while nothing in Routing is bio (#355(c) had to strip a false
//   "connect a heart-rate strap" promise off this very button);
// · the master panel's „Routing" button (`masterDoorButton`) — Instrument stage only, and the
//   Master chip shows only from Pro (`chips(for:)` → `level.showsProTabs`).
//
// WHY THE TILE AND NOT ONE OF THE OTHER TWO. It is the only door present wherever the user can be:
// both stages, every level. It is a STATUS that opens its own configuration (the tile says whether
// light is going out; tapping it opens where that is set) — the grammar of every other head tile.
// The Master chip would hide Routing below Pro and on the whole Piece stage; the bio panel is the
// wrong room and also Instrument-only. The sheet itself lives on `EchoelStudioView`, which
// `StageShell` keeps MOUNTED (hidden, never unmounted) on the Piece stage, so the one door can
// present it from either stage — the same path the Workstation's "save" door already takes to the
// studio's Save alert.
//
// ⚠️ WHAT THE TILE COSTS, stated rather than hidden: its VISIBLE face is a lightbulb and a status
// word, so a sighted user who wants MIDI or OSC has to learn that the light tile is the way in.
// The two deleted buttons said "Routing" on their face. This file cannot fix that (the tile is 38 pt
// wide by founder reference, `OneChromeControlHeightTests`); it pins the half it CAN carry — the
// spoken name. VoiceOver users can switch hints off, so the LABEL, not the hint, is the door's
// identity: it says "Light and Routing" (claim 4).
//
// THE FOUR CLAIMS (all SOURCE-TEXT scans — `EchoelStudioView`'s members are `private` on a view no
// bundle can instantiate, and there is no simulator here):
// 1. `EchoelStudioView` sets `showRouting = true` EXACTLY ONCE, in the receiver's `case "routing":`
//    arm, and that line carries the half-high-sheet refusal (`if !showAllFX, !showLiveColabo`).
// 2. The two Instrument doors are GONE app-wide: no `"Open Routing"` literal and no
//    `masterDoorButton` anywhere in `Sources/` code.
// 3. The one door is reachable everywhere: the tile's own body posts `"routing"`; `WorkspaceView`
//    mounts `EchoelLuxMonitorMini()` exactly once, inside `topBar` and inside no `if` / level /
//    stage condition; `topBar` itself is used exactly once and that use sits in `body` under no
//    `if` (a tile mounted in an ungated `topBar` that `body` only shows conditionally would pass
//    the first half and still vanish); `StageShell` keeps `EchoelStudioView()` in the tree on both
//    stages (opacity, not `if`), so the sheet can present while the Piece stage is in front.
// 4. The door says what it is and what is inside, in both languages: the tile's LABEL names
//    Routing; its HINT names Routing's contents; both carry a translated German unit; and the bio
//    button's retired key `Open Routing` is gone from the catalog. Only that ONE retired key is
//    pinned here: `StringCatalogIsHonestTests`' orphan check matches the QUOTED literal over a RAW
//    haystack, and two comments in Sources still quote "Open Routing", so it cannot see a stale
//    entry for that key. The other retired keys ("Opens routing", "OSC, immersive object, and
//    lighting outputs", "EchoelLux light monitor") occur nowhere in Sources and are the orphan
//    check's to catch — not restated here (#416).
// COUNTERWEIGHTS (#343): the sheet still builds `PatchbayView` with `.echoelSheetPanel()`;
// `panelSheetUp` still includes `showRouting` (the one door's sheet still locks the others); the
// Master chip is still gated at `showsProTabs` — which is WHY the master door could not be the one.
// ⚠️ THE POSTER COUNT IS NOT RESTATED HERE (#416): exactly one file posting `"routing"` is
// `ThePieceHasOneTabRowTests` claim 2. This file pins the SETTERS; together they are "one door".
//
// GRADING (§0/§3 — no Swift toolchain in a web session; transcribed in Python against the parent
// tree 3deb54e77 and the slice-G tree):
// parent — claim 1 is a REGRESSION (three setters; two of them inside `Button` actions, without the
// refusal); claim 2 is a REGRESSION twice over (`"Open Routing"` in EchoelStudioView: 2 code sites
// — `Label` and `.accessibilityLabel`; `masterDoorButton`: 2 code sites — the call and the
// declaration); claim 4's label needle and hint needle are REGRESSIONS (the parent spoke
// "EchoelLux light monitor" / "Opens routing"), its retired-key absence is a REGRESSION (the key is
// present), and its two German-unit checks are red by ANCHOR ABSENCE (neither key exists yet —
// one absence, reported twice, #486). Claim 3 and every counterweight are green on BOTH trees —
// they are the premises, not the change (topBar: 2 code occurrences, 1 use, enclosing scopes
// `struct WorkspaceView` › `var body` › `ZStack` › `VStack` › `Group` on both trees).
// Slice-G tree: all green. No forward guard over a new type.
// DEVICE PROBE, open: Piece stage → tap the light tile → Routing opens at half height over the
// arrangement; Instrument stage → same; with FX open at half height a tile tap does nothing and
// nothing freezes; VoiceOver on the tile reads "Licht und Routing", the rung sentence, then the
// German hint — and with Speak Hints OFF still says "Routing" — readings, not scans.

import Foundation
import XCTest

final class TheRoutingHasOneDoorTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let monitors = "Sources/Echoelmusic/Studio/HeaderMonitors.swift"
    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let stageShell = "Sources/Echoelmusic/Studio/StageShell.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"

    /// The tile's label, verbatim — the door's NAME, which survives "Speak Hints" being off.
    private static let doorLabel = "Light and Routing"
    /// The tile's hint, verbatim — the ONE spelling of what Routing holds (catalog key and English unit).
    private static let doorHint =
        "Opens Routing: MIDI pairing, the MIDI out switches, the OSC, Art-Net, sACN and spatial-audio targets, and the light master."

    // MARK: 1 — one setter, and it is the chrome-door arm

    func testRoutingHasExactlyOneSetterTheChromeDoorArm() throws {
        let lines = SourceText.codeOnly(try text(Self.studio)).components(separatedBy: "\n")
        let setters = lines.indices.filter { lines[$0].contains("showRouting = true") }
        XCTAssertEqual(setters.count, 1, """
            `showRouting = true` is written \(setters.count) times in EchoelStudioView (lines \
            \(setters.map { $0 + 1 })). Routing has ONE door — the head's light tile, through the \
            chrome door's `case "routing":` arm. Slice G (founder order 2026-10-01, one door per \
            area) deleted the bio panel's „Open Routing" and the master panel's „Routing" button; a \
            second setter is a second door to the same sheet.
            """)
        guard let only = setters.first else {
            return XCTFail("ANCHOR MISSING: no `showRouting = true` at all — the one door opens nothing (#454)")
        }
        XCTAssertTrue(lines[only].contains("if !showAllFX, !showLiveColabo"), """
            the one Routing setter lost its refusal: \(lines[only].trimmingCharacters(in: .whitespaces))
            The light tile is on screen while FX or Live Colabo is up at half height; raising a \
            second modal over a presented sheet is the two-modals hang.
            """)
        let previous = lines[..<only].last { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        XCTAssertEqual(previous?.trimmingCharacters(in: .whitespaces), "case \"routing\":", """
            the one Routing setter is not the chrome door's `case "routing":` arm — it sits under \
            `\(previous?.trimmingCharacters(in: .whitespaces) ?? "nothing")`. The door is the tile's \
            post, received here; a setter anywhere else is a door the tile does not own.
            """)
    }

    // MARK: 2 — the two Instrument doors are gone app-wide

    func testTheBioAndMasterRoutingDoorsAreGone() throws {
        let files = try sourceFiles()
        for gone in ["\"Open Routing\"", "masterDoorButton"] {
            let hits = files.filter { $0.code.contains(gone) }.map { $0.relative }.sorted()
            XCTAssertTrue(hits.isEmpty, """
                `\(gone)` is back in code: \(hits). Slice G deleted the bio panel's „Open Routing" \
                and the master panel's Routing button with its helper `masterDoorButton` (founder \
                order 2026-10-01, one door per area). Routing's one door is the head's light tile, \
                on both stages and at every skill level.
                """)
        }
    }

    // MARK: 3 — the one door is reachable wherever the user is

    func testTheOneDoorIsTheHeadLightTileOnBothStagesAtEveryLevel() throws {
        let monitors = SourceText.codeOnly(try text(Self.monitors))
        guard let tile = body(of: "struct EchoelLuxMonitorMini: View {", in: monitors) else {
            return XCTFail("ANCHOR MISSING: `struct EchoelLuxMonitorMini: View {` in HeaderMonitors (#454)")
        }
        XCTAssertTrue(tile.contains("NotificationCenter.default.post(name: .echoelChromeDoor, object: \"routing\")"), """
            the light tile no longer posts the `"routing"` chrome door — Routing would have no door \
            at all. (Exactly one poster is `ThePieceHasOneTabRowTests` claim 2.)
            """)

        let workspace = SourceText.codeOnly(try text(Self.workspace))
        let mounts = workspace.components(separatedBy: "EchoelLuxMonitorMini()").count - 1
        XCTAssertEqual(mounts, 1, "`WorkspaceView` mounts the light tile \(mounts) times; the head carries it once")
        if let mount = workspace.range(of: "EchoelLuxMonitorMini()") {
            let openers = enclosingScopeOpeners(of: mount.lowerBound, in: workspace)
            XCTAssertTrue(openers.contains { $0.contains("private var topBar: some View {") }, """
                the light tile is no longer mounted in `WorkspaceView.topBar` — the head row that \
                renders above BOTH stages. Enclosing scopes: \(openers)
                """)
            let gated = openers.filter(Self.isGate)
            XCTAssertTrue(gated.isEmpty, """
                the light tile is mounted inside a condition: \(gated). It is Routing's ONE door; \
                gating it by stage or skill level leaves Routing with no door there. (The Master chip \
                is level-gated, which is exactly why it was not chosen as the door.)
                """)
        } else {
            XCTFail("ANCHOR MISSING: `EchoelLuxMonitorMini()` in WorkspaceView (#454)")
        }

        // The tile's host must itself be shown unconditionally: an ungated tile inside a `topBar`
        // that `body` renders only under `if` is the same missing door one level up.
        XCTAssertEqual(workspace.components(separatedBy: "topBar").count - 1, 2, """
            `topBar` occurs \(workspace.components(separatedBy: "topBar").count - 1) times in \
            WorkspaceView code; two are expected — its declaration and its ONE use in `body`. A \
            second use, or a renamed host, needs this scan re-anchored before it can vouch for the door.
            """)
        let uses = Self.lineUse(of: "topBar", in: workspace)
        XCTAssertEqual(uses.count, 1, "`topBar` is used on \(uses.count) bare lines in WorkspaceView; one is expected")
        if let use = uses.first {
            let openers = enclosingScopeOpeners(of: use, in: workspace)
            XCTAssertTrue(openers.contains { $0.contains("var body: some View {") }, """
                `topBar` is no longer used inside `WorkspaceView.body` — the head row (and Routing's \
                one door in it) would not render. Enclosing scopes: \(openers)
                """)
            let gated = openers.filter(Self.isGate)
            XCTAssertTrue(gated.isEmpty, """
                `topBar` is rendered inside a condition: \(gated). It carries Routing's ONE door; a \
                head row shown only on one stage or level leaves Routing with no door elsewhere.
                """)
        } else {
            XCTFail("ANCHOR MISSING: the bare `topBar` use in WorkspaceView.body (#454)")
        }

        let shell = SourceText.codeOnly(try text(Self.stageShell))
        guard let shellBody = body(of: "struct StageShell: View {", in: shell) else {
            return XCTFail("ANCHOR MISSING: `struct StageShell: View {` (#454)")
        }
        XCTAssertTrue(shellBody.contains(".opacity(stage == .instrument ? 1 : 0)"), """
            `StageShell` no longer HIDES the studio by opacity on the Piece stage. Routing's sheet \
            hangs on `EchoelStudioView`; if the studio is unmounted on the Piece stage, the light \
            tile there posts to a receiver that does not exist.
            """)
        if let studioMount = shellBody.range(of: "EchoelStudioView()") {
            let openers = enclosingScopeOpeners(of: studioMount.lowerBound, in: shellBody)
            XCTAssertFalse(openers.contains { $0.contains("if ") }, """
                `EchoelStudioView()` is mounted under a condition in `StageShell`: \(openers). It \
                must stay in the tree on both stages — it owns the chrome-door receiver and the \
                Routing sheet the head's light tile opens from the Piece stage.
                """)
        } else {
            XCTFail("ANCHOR MISSING: `EchoelStudioView()` in StageShell (#454)")
        }
    }

    // MARK: 4 — the door says what it is and what is inside, in both languages

    func testTheDoorSaysWhatRoutingHolds() throws {
        let monitors = SourceText.codeOnly(try text(Self.monitors))
        guard let tile = body(of: "struct EchoelLuxMonitorMini: View {", in: monitors) else {
            return XCTFail("ANCHOR MISSING: `struct EchoelLuxMonitorMini: View {` in HeaderMonitors (#454)")
        }
        XCTAssertTrue(tile.contains(".accessibilityLabel(\"\(Self.doorLabel)\")"), """
            the light tile's VoiceOver label is no longer `\(Self.doorLabel)`. Since slice G it is \
            Routing's ONE door, and VoiceOver users can switch hints off — the label is the only \
            part of the door that is always spoken. Reword freely; keep "Routing" in it and move \
            `doorLabel` with it.
            """)
        XCTAssertTrue(Self.doorLabel.contains("Routing"),
                      "the door's label must name the room it opens — `doorLabel` lost \"Routing\"")
        XCTAssertTrue(tile.contains(".accessibilityHint(\"\(Self.doorHint)\")"), """
            the light tile's hint no longer names what Routing holds. Since slice G it is Routing's \
            ONE door, so its hint is the only place a VoiceOver user learns that the light tile \
            opens MIDI and the network outputs too. Reword freely — move `doorHint` with it.
            """)

        let strings = try catalogStrings()
        // Checked BEFORE the catalog units below, whose loop `continue`s per missing key — so on a
        // tree without the new keys this absence still gets a verdict.
        XCTAssertNil(strings["Open Routing"], """
            the catalog still carries `Open Routing`, the key of the bio panel's Routing button that \
            slice G deleted. `StringCatalogIsHonestTests`' orphan check cannot see it — two comments \
            in Sources still quote "Open Routing" — so a stale entry would ship a string for \
            a door that no longer exists.
            """)

        for key in [Self.doorLabel, Self.doorHint] {
            guard let entry = strings[key] as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let en = (localizations["en"] as? [String: Any])?["stringUnit"] as? [String: Any],
                  let value = en["value"] as? String else {
                XCTFail("""
                    `\(key)` has no English unit in Localizable.xcstrings — the one Routing door's \
                    words left the catalog they are looked up in.
                    """)
                continue
            }
            XCTAssertEqual(en["state"] as? String, "translated", "`\(key)`: a `new` unit ships nothing")
            XCTAssertEqual(value, key, "`\(key)`: the English unit is the key")
            XCTAssertEqual(Set(localizations.keys), ["en"], "`\(key)`: the app speaks one language (founder 2026-10-02) — no second unit")
            XCTAssertTrue(value.contains("Routing"), """
                `\(key)` does not say "Routing" (\(value)) — the door must name the room it opens.
                """)
        }
    }

    // MARK: counterweights — the sheet, the lock and the chip gate are unchanged

    func testTheSheetTheLockAndTheChipGateStand() throws {
        let code = SourceText.codeOnly(try text(Self.studio))
        XCTAssertTrue(code.contains(".sheet(isPresented: $showRouting) { AnyView(PatchbayView().echoelSheetPanel()) }"),
                      "COUNTERWEIGHT: the one door still lands on `PatchbayView` at half height")
        XCTAssertTrue(code.contains("private var panelSheetUp: Bool { showAllFX || showLiveColabo || showRouting }"),
                      "COUNTERWEIGHT: Routing's sheet still locks the other sheet doors (`AHalfHighSheetLocksTheOtherSheetDoorsTests`)")
        guard let chips = body(of: "private static func chips(for level: SkillLevel) -> [StudioMenu] {", in: code) else {
            return XCTFail("ANCHOR MISSING: `chips(for:)` in EchoelStudioView (#454)")
        }
        XCTAssertTrue(chips.contains("case .master:\n                return level.showsProTabs"), """
            COUNTERWEIGHT: the Master chip is no longer gated at `showsProTabs`. That gate is the \
            measured reason the master panel could not be Routing's one door; if it moved, re-judge \
            the choice in the header of this file rather than only this needle.
            """)
    }

    // MARK: helpers

    /// An enclosing scope that would make the door conditional on stage, level or anything else.
    private static func isGate(_ opener: String) -> Bool {
        ["if ", "level", "showsProTabs", "showsSongs", "stage"].contains { opener.contains($0) }
    }

    /// The start index of every line whose only code is `name` — a bare use in a view builder,
    /// never the declaration (`private var name: some View {`) or a member access.
    private static func lineUse(of name: String, in code: String) -> [String.Index] {
        var out: [String.Index] = []
        var lineStart = code.startIndex
        for line in code.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces) == name { out.append(lineStart) }
            lineStart = code.index(lineStart, offsetBy: line.count + 1, limitedBy: code.endIndex) ?? code.endIndex
        }
        return out
    }

    private func repoRoot() -> URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return root
    }

    private func text(_ relativePath: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    /// Every Swift file under `Sources/`, comment-stripped. A walk that saw too few files is a
    /// FAIL, never a pass — an absence claim over nothing is vacuous.
    private func sourceFiles() throws -> [(relative: String, code: String)] {
        let base = repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            XCTFail("cannot enumerate Sources/ — a scan that saw nothing is not a pass")
            return []
        }
        var out: [(relative: String, code: String)] = []
        for case let relative as String in walker where relative.hasSuffix(".swift") {
            guard let raw = try? String(contentsOf: base.appendingPathComponent(relative), encoding: .utf8) else { continue }
            out.append((relative, SourceText.codeOnly(raw)))
        }
        XCTAssertGreaterThan(out.count, 200, "the walk read \(out.count) Swift files — the wrong directory")
        return out
    }

    /// The brace-matched body of the declaration that ends with `opener` (which must end in `{`),
    /// or nil when the anchor is missing or the braces never close. Brace-matched rather than a
    /// fixed line window (§2, #408): this repo writes long comment blocks, and `codeOnly` keeps
    /// their line count.
    private func body(of opener: String, in code: String) -> Substring? {
        guard let start = code.range(of: opener) else { return nil }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex {
            switch code[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return code[start.upperBound..<index] }
            default: break
            }
            index = code.index(after: index)
        }
        return nil
    }

    /// The trimmed source lines that OPEN each scope enclosing `position`, outermost first.
    private func enclosingScopeOpeners(of position: String.Index, in code: some StringProtocol) -> [String] {
        var opens: [String.Index] = []
        var index = code.startIndex
        while index < position {
            switch code[index] {
            case "{": opens.append(index)
            case "}": if !opens.isEmpty { opens.removeLast() }
            default: break
            }
            index = code.index(after: index)
        }
        return opens.map { brace in
            let lineStart = code[..<brace].lastIndex(of: "\n").map { code.index(after: $0) } ?? code.startIndex
            return String(code[lineStart...brace]).trimmingCharacters(in: .whitespaces)
        }
    }

    private func catalogStrings() throws -> [String: Any] {
        let data = try Data(contentsOf: repoRoot().appendingPathComponent(Self.catalog))
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let strings = object["strings"] as? [String: Any] else {
            XCTFail("ANCHOR MISSING: Localizable.xcstrings is not the JSON shape this guard reads (#454)")
            return [:]
        }
        return strings
    }
}
