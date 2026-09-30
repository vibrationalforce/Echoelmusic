// TheValueFieldOffersItsDefaultTests.swift
// Echoel — interface audit 2026-09-30, rule 6: "Alles rückgängig machbar … Jeder Wert hat
// „Auf Standard"" (WCAG 3.3.4 / 3.3.7).
//
// WHAT THIS GUARDS. `EchoelValueField` is the app's ONE numeric control (84 call sites), and
// until this slice none of them could say "back to the value a fresh install has" — a player
// who had dragged the concert pitch to 447 Hz had to know that 440 is the standard and type
// it. Rule 6 gives every value that KNOWS its default two doors, both through the field's own
// `apply(_:)` so `onChange` and `onCommit` fire exactly as for a typed number:
//   · the keypad's "Default 440" key (rule 3: symbol plus word). It TYPES the default into the
//     buffer and OK confirms — the same tap every digit needs, so a reset is never one
//     accidental touch, and the header shows what OK will keep. Dimmed while the pending value
//     already IS the default (#164/#227: a key may not offer a change it cannot make).
//   · a VoiceOver custom action "Default 440" on the row itself.
// `standard` is OPTIONAL and `nil` shows nothing: a row whose default is not a fact (a bio
// mapping's live value, a derived binding) offers no key rather than a wrong one.
//
// FIRST CONSUMERS, and why these: the concert pitch (`SessionContext.defaultA4Hz`, 440 —
// the founder's own device note "A4 ≠ 440 banner" is about exactly this row) and the two
// mixer levels (`MixerStore.defaultLevel`, unity). Each names a constant the engine already
// owns — no second definition of a default is born here (#416). The other 81 rows join one
// family per commit, each with its owner's constant; a literal typed at a call site would be
// the #416 defect the parameter exists to avoid.
//
// ⚠️ LIMIT — SOURCE-TEXT SCAN plus two constants. Nothing here taps the key on a device; that
// the dimmed key reads as "you are at the default" and not as "broken" is a founder look.
// `ValueFieldNotifiesEveryPathTests` owns the swipe/drag/keypad closure pairs and is
// unchanged: this file pins only the NEW path and its two premises.
//
// ⚠️ HONEST GRADING (#433/#464) — transcribed in Python against this tree and the parent
// 62ceec462 (no local toolchain): claims 1–3 RED on the parent for their named reasons (the
// parameter, the key, the action and the three call-site arguments are born here; the two
// constants exist on both trees and are GREEN there — they are the premises, not the slice);
// claim 4 GREEN on both — the counterweight (#343): the pad still commits in exactly ONE
// place, so a "Default" key that committed on its own would turn it red.
// `Tests/CISmoke` is the blocking bundle. SKIPS rather than passes if the tree is absent.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheValueFieldOffersItsDefaultTests: XCTestCase {

    private static let field = "Sources/Echoelmusic/Studio/EchoelValueField.swift"
    private static let pad = "Sources/Echoelmusic/Studio/EchoelNumberPad.swift"
    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"
    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    // MARK: - claim 1 — the field carries an optional default and hands it to both doors

    func testTheFieldCarriesAnOptionalDefaultAndOffersItAsAnAction() throws {
        let code = try source(Self.field)
        let hint = code.range(of: "var hint: String = \"\"")
        let standard = code.range(of: "var standard: V? = nil")
        let onChange = code.range(of: "var onChange: () -> Void = {}")
        XCTAssertNotNil(standard, "`EchoelValueField` lost `var standard: V? = nil` — rule 6's default per value")
        if let hint, let standard, let onChange {
            XCTAssertTrue(hint.lowerBound < standard.lowerBound && standard.lowerBound < onChange.lowerBound, """
                `standard` must be declared AFTER `hint` and BEFORE the closures: the memberwise \
                initialiser follows declaration order, and every call site writes \
                `…, decimals: 2, standard: 440, onCommit: …`. Moving it is a compile error at \
                84 sites (#930b learned this with `hint`).
                """)
        }
        XCTAssertTrue(code.contains("standard: standard.map { Double($0) }"), """
            The field no longer hands its default to the keypad. The pad's "Default" key is the \
            sighted door of rule 6; without this argument the key never appears and the row's \
            VoiceOver action is the only way back.
            """)
        let actions = slice(code, from: ".accessibilityActions {", to: "\n        }")
        XCTAssertTrue(actions.contains("if let standard {"), "the VoiceOver action is offered only when a default exists — a nil default shows nothing")
        XCTAssertTrue(actions.contains("if apply(Double(standard)) { onChange(); onCommit() }"), """
            The VoiceOver "Default" action no longer goes through `apply` with BOTH closures. \
            Every path of this field fires `onChange` (live-apply) and `onCommit` (persist) only \
            when the value moved (#232/#375); a reset that skipped either would change the \
            number and not the instrument, or the instrument and not the file.
            """)
    }

    // MARK: - claim 2 — the keypad's key types the default; OK still confirms

    func testTheKeypadKeyTypesTheDefaultAndOKConfirms() throws {
        let code = try source(Self.pad)
        let standard = code.range(of: "var standard: Double? = nil")
        let commitDecl = code.range(of: "let onCommit: (Double) -> Void")
        XCTAssertNotNil(standard, "`EchoelNumberPad` lost `var standard: Double? = nil`")
        if let standard, let commitDecl {
            XCTAssertTrue(standard.lowerBound < commitDecl.lowerBound,
                          "`standard` is declared before `onCommit` so the field's trailing closure still binds to `onCommit`")
        }
        let header = slice(code, from: "private var header: some View {", to: "\n    }")
        XCTAssertTrue(header.contains("if let standard {") && header.contains("defaultKey(standard)"), """
            The keypad header no longer mounts `defaultKey` behind `if let standard` — the key \
            must exist exactly when the row has a default, and nowhere else on the pad (the \
            5×3 grid is full and the sheet's 440 pt detent has no room for a sixth row).
            """)
        let key = slice(code, from: "private func defaultKey(_ standard: Double) -> some View {", to: "\n    }")
        XCTAssertTrue(key.contains("buffer = String(format:"), """
            The "Default" key no longer TYPES the default into the buffer. It must write the \
            same ASCII buffer the digit keys write and let OK confirm — a reset that committed \
            by itself would be the one key on this pad that changes a value without OK.
            """)
        XCTAssertFalse(key.contains("onCommit("), "the \"Default\" key must not commit — OK is the pad's one committer")
        XCTAssertFalse(key.contains("dismiss()"), "the \"Default\" key must not close the pad — the header shows what OK will keep")
        XCTAssertTrue(key.contains(".disabled(atDefault)"), """
            The "Default" key is no longer dimmed while the pending value already is the \
            default. A key that offers a change it cannot make is the lying-control class \
            (#164/#227) — the same rule that dims the sign pair on a non-negative row.
            """)
        XCTAssertTrue(key.contains("Label(\"Default \\(text)\", systemImage:"), "the key wears symbol PLUS the word \"Default\" (rule 3) — the glossary's word for this thing")
    }

    // MARK: - claim 3 — the first consumers name their owner's constant, and the constant is inside the row's range

    func testTheFirstConsumersNameTheirOwnersConstant() throws {
        XCTAssertEqual(SessionContext.defaultA4Hz, 440, "the concert-pitch default is the ISO 16 standard")
        XCTAssertTrue((380.0...500.0).contains(SessionContext.defaultA4Hz), "the default must sit inside the row's own range, or the key would type a value the row clamps")
        XCTAssertEqual(MixerStore.defaultLevel, 1, "the mixer default is unity")
        XCTAssertTrue((Float(0)...Float(1)).contains(MixerStore.defaultLevel), "unity must sit inside the level row's 0…1 range")

        let workspace = try source(Self.workspace)
        let a4 = slice(workspace, from: "EchoelValueField(label: \"\", value: $session.a4Hz", to: "\n                        .accessibilityLabel(\"Concert pitch A4\")")
        XCTAssertTrue(a4.contains("standard: SessionContext.defaultA4Hz"), """
            The concert-pitch row no longer passes `standard: SessionContext.defaultA4Hz`. This is \
            the row the founder's device note ("A4 ≠ 440") is about; a player who dragged it to \
            447 Hz needs the way back to be one key, not a number they have to know.
            """)
        let studio = try source(Self.studio)
        XCTAssertEqual(occurrences(of: "standard: MixerStore.defaultLevel", in: studio), 2, """
            The two mixer level rows (Bass Level, Melodic Pad) must pass `MixerStore.defaultLevel` \
            as their default — the ENGINE's constant, never a literal `1` typed at the call site \
            (#416). A third mixer row joining is fine: raise this count in the same commit.
            """)
    }

    // MARK: - claim 4 — counterweight: the pad still commits in exactly one place

    func testThePadStillCommitsInExactlyOnePlace() throws {
        let code = try source(Self.pad)
        XCTAssertEqual(occurrences(of: "onCommit(", in: code), 1, """
            `EchoelNumberPad` calls `onCommit(` in more than one place. Only `commit()` — the OK \
            key — may commit; the "Default" key types, the digits type, the sign keys type. A \
            second committer is exactly the accidental one-touch reset rule 6's "in klaren \
            Worten bestätigt" forbids.
            """)
        let field = try source(Self.field)
        XCTAssertTrue(field.contains(".accessibilityAdjustableAction { dir in"),
                      "the swipe path `ValueFieldNotifiesEveryPathTests` owns is still there — the default action is added beside it, never in place of it")
    }

    // MARK: - Reading the source

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(relativePath) is absent — rewrite this guard with the move, do not let it pass on nothing")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// The text from `from` up to the first `to` after it; empty when either is missing, so the
    /// assertions on it read as absences with their own messages.
    private func slice(_ code: String, from: String, to: String) -> String {
        guard let start = code.range(of: from) else { return "" }
        guard let end = code.range(of: to, range: start.upperBound..<code.endIndex) else { return "" }
        return String(code[start.lowerBound..<end.lowerBound])
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }
}
