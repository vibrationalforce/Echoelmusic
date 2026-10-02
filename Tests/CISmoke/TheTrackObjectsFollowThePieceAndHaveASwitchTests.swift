// TheTrackObjectsFollowThePieceAndHaveASwitchTests.swift
// Echoel — Workstation redesign C4a (2026-10-01): the spatial track objects follow the PIECE,
// app-wide, and the switch that streams them has a door in Routing.
//
// THE FINDING, measured at 25fe5593c before this slice. `ADMOSCSender.streamsScene` turns the
// per-tick ADM-OSC stream from ONE object (the music/bio mapping) into one object PER TRACK
// (`/adm/obj/1…N`). Two facts kept that branch unreachable and, worse, empty:
// · its only writer was a `Toggle` in `ImmersiveStageView`, a view with ZERO construction sites
//   (doorless by ship gate 4 — `TheStageStatusLineHasNoDoorTests` and claim 5 of
//   `TheSceneDialectHasNoWriterTests` pin that; this file does not repeat it, #416);
// · `SpatialSceneStore.rebuild(from:)` — the only thing that puts objects INTO the scene — had
//   its only callers in that same view. Arming the flag from anywhere else would have streamed
//   an empty scene, and the branch sends NOTHING for an empty scene (it never falls back to the
//   single object, which would collide on object 1).
// So C4a ships the two halves together: `EchoelmusicApp` rebuilds the scene from the piece at
// launch and on every document change, and Routing's ADM-OSC card carries the switch.
//
// ⚠️ THE EMPTY-PIECE HALF STAYS TRUE AFTER C4a, and the copy has to say it: a fresh install
// seeds NO track (`TimelineStore.init` falls back to `TimelineDocument()`; `bootstrapIfNeeded`
// has no production caller), so ON with no track silences ADM-OSC. Claim 5 pins that sentence.
//
// WHAT IS DELIBERATELY NOT HERE, and why it is not a gap:
// · NO Space tab — the C5 domain row it would have joined is gone (slice B,
//   `ThePieceHasOneTabRowTests`); C4a-2 brings Space with a landing of its own, not as a tab twin.
// · NO dialect picker (`TheSceneDialectHasNoWriterTests`).
// · NO movement and NO render. The copy says "Nothing moves them yet" and "no audio"; each
//   object also carries the instrument profile's FIXED gain, so the copy says "Position and a
//   fixed level only" rather than "Positions only" (`SpatialSceneOSC` emits `/gain`).
//
// THE FOUR CLAIMS:
// 1. The app rebuilds the scene from the piece: once at launch, then CHAINED onto the one
//    `onDocumentChanged` slot after the multiRoll block that owns it — outside that block, and
//    before the next statement (`timelinePlayer.liveDocument`), so the order scan is bounded.
// 2. Exactly two files call `.rebuild(from:` in code: the app and the (still unconstructed) stage.
// 3. The switch sits in `networkOutSection` between the ADM-OSC row and the sACN row, binds the
//    sender's flag through ONE setter, and carries no modal, no persistence and no hot read.
//    Counterweights: a fresh sender starts OFF and on `.admOSC`; the label names ADM-OSC.
// 4. The copy claims only what ships, and every visible string has a German unit.
//
// ⚠️ THE LIMIT FIRST. Claims 1–3 and 4 are SOURCE-TEXT scans plus one runtime counterweight.
// Nothing here proves a renderer receives N objects, that removed objects disappear on it, or
// that the German line fits — DEVICE PROBES, open.
//
// GRADING (§0/§3 — no toolchain; transcribe against parent 25fe5593c and the C4a tree). Parent:
// claims 1 and 2 red by ONE absence (no app-level rebuild); claim 3-source and claim 4 red by ONE
// absence (`admSceneStreamRow` — ANCHOR MISSING, #486); the runtime counterweight green on both.
// STRIPPER: claims 1–3 read `SourceText.codeOnly`; it is TRAGEND for claim 1 — the app's new
// comment block names `rebuild(from:)`.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTrackObjectsFollowThePieceAndHaveASwitchTests: XCTestCase {

    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let routing = "Sources/Echoelmusic/Studio/PatchbayView.swift"
    private static let catalog = "Sources/Echoelmusic/Resources/Localizable.xcstrings"
    private static let rowAnchor = "private var admSceneStreamRow: some View {"
    private static let rowLabel = "Every track as its own object (ADM-OSC)"

    // MARK: 1 — the scene follows the piece, app-wide, chained onto the one hook

    func testTheAppRebuildsTheSceneFromThePieceAndChainsTheHook() throws {
        let code = SourceText.codeOnly(try text(Self.app))
        XCTAssertEqual(occurrences(of: "spatialScene?.rebuild(from: lanes)", in: code), 1, """
            the app no longer rebuilds the spatial scene from the piece. Without it the scene the \
            Routing switch streams is EMPTY, and `ADMOSCSender.sendIfFresh` sends nothing for an \
            empty scene — the switch would silence the ADM-OSC output instead of widening it.
            """)
        guard let roll = code.range(of: "let syncRollMix") else {
            return XCTFail("ANCHOR MISSING: `let syncRollMix` in \(Self.app) (#454)")
        }
        guard let gate = code.range(of: "if FeatureFlags.multiRoll {", options: .backwards,
                                    range: code.startIndex..<roll.lowerBound) else {
            return XCTFail("ANCHOR MISSING: the multiRoll block that owns the roll-mix hook (#454)")
        }
        let block = try body(after: gate, in: code)
        XCTAssertTrue(block.contains("timelineStore.onDocumentChanged = {"), """
            premise: the roll-mix sync still owns the hook inside the multiRoll block. If it moved, \
            the chaining below may be chaining onto nothing — re-read before trusting claim 1.
            """)
        XCTAssertFalse(block.contains("previousDocumentHook"), """
            the scene rebuild moved INSIDE the multiRoll block — with the flag off the track \
            objects would never follow the piece. The objects are positions on the wire, not voices.
            """)
        let tail = code[gate.lowerBound...].dropFirst(block.count)
        guard let stop = tail.range(of: "timelinePlayer.liveDocument = {") else {
            return XCTFail("ANCHOR MISSING: `timelinePlayer.liveDocument = {` after the multiRoll block (#454)")
        }
        let window = String(tail[tail.startIndex..<stop.lowerBound])
        let steps = [
            "let rebuildScene = {",
            "rebuildScene()",
            "let previousDocumentHook = timelineStore.onDocumentChanged",
            "timelineStore.onDocumentChanged = {",
            "previousDocumentHook?()",
            "rebuildScene()",
        ]
        var cursor = window.startIndex
        for step in steps {
            guard let hit = window.range(of: step, range: cursor..<window.endIndex) else {
                return XCTFail("""
                    the chain between the multiRoll block and `timelinePlayer.liveDocument` is broken \
                    at `\(step)`. The order is the law: build once at launch (the loaded piece has \
                    had no persist yet), READ the previous hook, then assign a closure that calls it \
                    and rebuilds. A plain assignment would replace the roll-mix sync — one slot.
                    """)
            }
            cursor = hit.upperBound
        }
    }

    // MARK: 2 — exactly two rebuild callers: the app and the parked stage

    func testOnlyTheAppAndTheParkedStageRebuildTheScene() throws {
        let callers = try filesWhoseCodeContains(".rebuild(from:")
        XCTAssertEqual(callers, ["Echoelmusic/EchoelmusicApp.swift",
                                 "Echoelmusic/Studio/ImmersiveStageView.swift"], """
            `.rebuild(from:` is called from \(callers). The app-level rebuild (C4a) is the one the \
            stream depends on; the stage's own calls are harmless while it has no construction \
            site. A THIRD caller is a second owner of when the scene changes — make it a call to \
            the app's chain instead, or say here why it is not.
            """)
    }

    // MARK: 3 — the switch: placed in the ADM-OSC card, one setter, no modal, no hot read

    func testTheRoutingCardCarriesTheStreamSwitch() throws {
        let code = SourceText.codeOnly(try text(Self.routing))
        let section = try member("private var networkOutSection: some View {", in: code)
        guard let adm = section.range(of: "outputRow(\"ADM-OSC\""),
              let row = section.range(of: "admSceneStreamRow"),
              let sacn = section.range(of: "outputRow(String(localized: \"sACN · Light\")") else {
            return XCTFail("ANCHOR MISSING: the ADM-OSC row, `admSceneStreamRow` or the sACN row in `networkOutSection` (#454)")
        }
        XCTAssertTrue(adm.upperBound <= row.lowerBound && row.upperBound <= sacn.lowerBound, """
            the object switch left the ADM-OSC card's place — it belongs directly under the \
            ADM-OSC target row it modifies, before the light outputs.
            """)
        let switchRow = try member(Self.rowAnchor, in: code)
        XCTAssertTrue(switchRow.contains("Toggle(isOn: admSceneStream)"),
                      "the row no longer binds the sender's flag through `admSceneStream`")
        XCTAssertTrue(code.contains(
            "private var admSceneStream: Binding<Bool> { Binding(get: { admOSC.streamsScene }, set: { admOSC.streamsScene = $0 }) }"),
            "the binding must read and write the SENDER's flag — the one value the send branch reads (#416)")
        XCTAssertEqual(occurrences(of: "streamsScene =", in: code), 1, """
            Routing writes `streamsScene` in more than one place. ONE setter, through the binding; \
            a second write is how the card and the wire come to disagree.
            """)
        for forbidden in ["sceneDialect", "lastSentTimestamp", "lastSceneObjectCount", "@AppStorage",
                          ".sheet(", ".fullScreenCover(", ".popover(", ".alert("] {
            XCTAssertFalse(switchRow.contains(forbidden), """
                `admSceneStreamRow` contains `\(forbidden)`. No dialect choice here (claim 1 of \
                `TheSceneDialectHasNoWriterTests` governs that), no ~30 Hz read in the Routing \
                body (freeze law — the activity dot is the leaf), no persistence (the flag is \
                deliberately per-launch) and no modal (black-screen law).
                """)
        }
        XCTAssertTrue(switchRow.contains("Text(\"\(Self.rowLabel)\")"), """
            the switch no longer says `\(Self.rowLabel)`. Widening the label is CORRECT once a \
            dialect picker exists — then claim 1 of `TheSceneDialectHasNoWriterTests` is red in \
            the same run. Without the picker, a wider label promises a choice the app cannot make.
            """)
    }

    #if canImport(Network)
    @MainActor
    func testAFreshSenderStartsWithOneObjectOnTheStandardDialect() {
        let sender = ADMOSCSender()
        XCTAssertFalse(sender.streamsScene, """
            a fresh sender streams every track. The default IS the decision — and the copy promises \
            "Turns off when the app restarts"; a persisted or ON default makes that line false.
            """)
        XCTAssertEqual(sender.sceneDialect, .admOSC, """
            the scene dialect is no longer ADM-OSC polar — then the switch's label, which names \
            ADM-OSC, may be wrong. Widen it together with the picker.
            """)
    }
    #endif

    // MARK: 4 — the copy claims only what ships, in both languages

    func testTheSwitchCopyClaimsOnlyWhatShips() throws {
        let switchRow = try member(Self.rowAnchor, in: SourceText.codeOnly(try text(Self.routing)))
        let literals = stringLiterals(in: switchRow)
        XCTAssertEqual(literals.count, 5, """
            expected the label, two hints and two footnotes in `admSceneStreamRow`, found \
            \(literals.count). If copy was added, add it to the catalog check below too.
            """)
        for literal in literals {
            let lower = literal.lowercased()
            for word in ["render", "binaural", "speaker", "scene", "song", "project", "session", "lane",
                         "clip", "region", "your body", "heart", "positions only"] {
                XCTAssertFalse(lower.contains(word), """
                    `\(literal)` says `\(word)`. The render half is not built, "scene" is a Perform \
                    scene in this app's words, the struck nouns are piece/part/track here, the single \
                    object follows the MUSIC (bio may be refused egress), and each object also carries \
                    a fixed gain — "positions only" would be false.
                    """)
            }
        }
        let required: [(String, String)] = [
            ("Position and a fixed level only", "the ON copy must say what each object carries (`SpatialSceneOSC` emits `/gain`)"),
            ("Nothing moves them yet", "no automation writer reaches the objects"),
            ("With no track, nothing is sent", "an empty piece silences ADM-OSC while ON — the sender never falls back"),
            ("Turns off when the app restarts", "the flag is not persisted (`ADMOSCSender.streamsScene`)"),
            ("nothing while the piece has no track", "the OFF copy must not promise every track to an empty piece"),
        ]
        for (needle, why) in required {
            XCTAssertTrue(literals.contains { $0.contains(needle) }, "the copy lost `\(needle)` — \(why)")
        }
        XCTAssertTrue(switchRow.contains(".accessibilityHint(admOSC.streamsScene\n")
                      || switchRow.contains(".accessibilityHint(admOSC.streamsScene "),
                      "the hint must follow the switch's state")
        XCTAssertEqual(occurrences(of: "String(localized: \"", in: switchRow), 4, """
            both branches of the hint and of the footnote must be catalog lookups — a ternary of \
            bare literals is a `String`, never localised (E4-79).
            """)
        let data = try Data(contentsOf: root().appendingPathComponent(Self.catalog))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = json?["strings"] as? [String: Any] ?? [:]
        XCTAssertGreaterThan(strings.count, 400, "ANCHOR MISSING: the string catalog read as nearly empty (#454)")
        for literal in literals {
            let entry = strings[literal] as? [String: Any]
            let localizations = entry?["localizations"] as? [String: Any]
            let en = (localizations?["en"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertEqual(en?["state"] as? String, "translated", "`\(literal)` has no translated English unit")
            XCTAssertEqual(en?["value"] as? String, literal, "`\(literal)`: the English unit is the key")
            XCTAssertEqual(Set((localizations ?? [:]).keys), ["en"], "`\(literal)`: the app speaks one language (founder 2026-10-02) — no second unit")
        }
    }

    // MARK: - helpers

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// Plain `"…"` literals on one line (the row has no interpolation and no triple quotes).
    private func stringLiterals(in code: String) -> [String] {
        var out: [String] = []
        var current = ""
        var inside = false
        var escaped = false
        for ch in code {
            if inside {
                if escaped { current.append(ch); escaped = false; continue }
                if ch == "\\" { escaped = true; continue }
                if ch == "\"" { out.append(current); current = ""; inside = false; continue }
                if ch == "\n" { current = ""; inside = false; continue }
                current.append(ch)
            } else if ch == "\"" {
                inside = true
            }
        }
        return out
    }

    /// The text between `opening`'s `{` and its matching `}`, string-literal aware.
    private func body(after opening: Range<String.Index>, in code: String) throws -> String {
        var depth = 1
        var index = opening.upperBound
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
                    if depth == 0 { return String(code[opening.lowerBound...index]) }
                }
            }
            index = code.index(after: index)
        }
        XCTFail("UNBALANCED: the block at `\(code[opening])` never closes (#454)")
        return ""
    }

    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor) else {
            XCTFail("ANCHOR MISSING: `\(anchor)` (#454)")
            return ""
        }
        guard code.range(of: anchor, range: start.upperBound..<code.endIndex) == nil else {
            XCTFail("ANCHOR NOT UNIQUE: `\(anchor)` (#408)")
            return ""
        }
        return try body(after: start, in: code)
    }

    /// Relative paths under `Sources/` whose comment-stripped code contains `needle`.
    private func filesWhoseCodeContains(_ needle: String) throws -> [String] {
        let base = try root().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(atPath: base.path) else {
            XCTFail("ANCHOR MISSING: cannot walk Sources/ (#454)")
            return []
        }
        var hits: [String] = []
        var seen = 0
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            seen += 1
            let code = SourceText.codeOnly(
                try String(contentsOf: base.appendingPathComponent(rel), encoding: .utf8))
            if code.contains(needle) { hits.append(rel) }
        }
        XCTAssertGreaterThan(seen, 200, "ANCHOR MISSING: only \(seen) Swift files walked — a partial tree (#454)")
        return hits.sorted()
    }

    private func text(_ relativePath: String) throws -> String {
        let url = try root().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            XCTFail("ANCHOR MISSING: \(relativePath) is not present while Sources/ is (#454)")
            return ""
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func root() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(url.path)")
        }
        return url
    }
}
