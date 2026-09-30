// TheTextSizeHasButtonsTests.swift
// Echoel — interface audit 2026-09-30, rule 12: "Sichtbare Anpassung: Textgröße als Knöpfe
// (nicht nur Kneifen)" (WCAG 1.4.4).
//
// WHAT THIS GUARDS. The app already had an in-app text size: `StudioZoom` drives Dynamic Type
// through a nine-rung ladder (`.large` … `.accessibility5`) from a persisted step, `-1` meaning
// "follow the system". Its ONLY writer was a two-finger pinch — a gesture nothing on screen
// announces, that a person with one hand, a tremor or a switch cannot make, and that the
// founder's own audit line names as the defect. This slice adds the buttons and keeps ONE size:
//   · `StudioDefaultKeys.zoomStep` — the key moves into the keystore because it now has two
//     writers (pinch + buttons); its STRING stays the pre-keystore literal so a size a user
//     pinched before this commit survives the update.
//   · `TextSizeRow` in Save & Export, beside the level picker: Smaller · Larger · Default, each
//     symbol PLUS word (rule 3), 44 pt tall, dimmed where it cannot move (#164/#227). Smaller and
//     Larger step from the rung IN EFFECT (`StudioZoom.systemIndex` while at `-1`), Default
//     returns to `-1`. The caption says the level and the SCOPE: the instrument's text — the
//     head keeps its `.accessibility1` ceiling (`ChromeDynamicTypeTests`) and the piece follows
//     the system size, because `StudioZoom` is mounted inside `EchoelStudioView`.
//
// ⚠️ LIMIT — SOURCE-TEXT SCAN plus one keystore constant. `StudioZoom` and `TextSizeRow` are
// file-private, so nothing here taps a button; that three 44 pt buttons fit a portrait phone at
// the top rung is a founder look. The chrome ceiling and the pinch scope are pinned by
// `ChromeDynamicTypeTests`, not repeated here (#416) — claim 4 only checks the pinch survives.
//
// ⚠️ HONEST GRADING (#433/#464) — transcribed in Python against this tree and the parent
// 27b8918e3 (no local toolchain): claims 1–3 RED on the parent for their named reasons (the
// keystore entry, the row, the mount and the non-private `systemIndex` are born here; the raw
// `"ui.zoomStep"` literal sat in the root); claim 4 GREEN on both — the counterweight (#343):
// the pinch gesture and the nine-rung ladder are unchanged, so a slice that replaced the pinch
// with the buttons instead of adding to it would turn it red.
// `Tests/CISmoke` is the blocking bundle. SKIPS rather than passes if the tree is absent.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTextSizeHasButtonsTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let keystore = "Sources/Echoelmusic/Core/StudioDefaultKeys.swift"

    // MARK: - claim 1 — one key, in the keystore, with the shipped string and the follow-system default

    func testTheTextSizeIsOneKeystoreKeyWithTheShippedString() throws {
        XCTAssertEqual(StudioDefaultKeys.zoomStep.key, "ui.zoomStep", """
            The text-size key string changed. It is the on-disk contract with every install that \
            ever pinched: a new string silently resets their size to the system's.
            """)
        XCTAssertEqual(StudioDefaultKeys.zoomStep.value, -1, "-1 = follow the system text size; a fresh install must not zoom")

        // The literal lives ONCE, in the keystore — no view re-types it (H15-KEYSTORE).
        let root = try repoRoot()
        let swift = try trackedSources(root)
        var carriers: [String] = []
        for rel in swift {
            let code = SourceText.codeOnly(try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8))
            if code.contains("\"ui.zoomStep\"") { carriers.append(rel) }
        }
        XCTAssertEqual(carriers, [Self.keystore], """
            `"ui.zoomStep"` is spelled outside `StudioDefaultKeys` (\(carriers)). Two writers on \
            one key are only safe while both read the key AND its default from the same place; \
            a view that re-types the string is the fresh-install split the keystore exists for.
            """)
        let studio = try source(Self.studio)
        XCTAssertEqual(occurrences(of: "@AppStorage(StudioDefaultKeys.zoomStep.key)", in: studio), 2,
                       "exactly two readers of the key in the instrument file: the root that applies it and `TextSizeRow` that writes it")
    }

    // MARK: - claim 2 — the row: three buttons, symbol plus word, dimmed at the ends, one writer each

    func testTheRowHasThreeWordedButtonsThatStepTheLadderAndDimAtTheEnds() throws {
        let code = try source(Self.studio)
        let row = slice(code, from: "private struct TextSizeRow: View {", to: "\n}\n")
        XCTAssertFalse(row.isEmpty, "`TextSizeRow` is gone from `EchoelStudioView.swift` — rule 12's buttons")
        XCTAssertTrue(row.contains("Text(\"Text size\")"), "the row is titled with the plain words \"Text size\" (rule 9)")
        for (word, symbol) in [("Smaller", "textformat.size.smaller"),
                               ("Larger", "textformat.size.larger"),
                               ("Default", "arrow.counterclockwise")] {
            XCTAssertTrue(row.contains("sizeButton(\"\(word)\", systemImage: \"\(symbol)\""), """
                The "\(word)" button lost its word or its symbol. Rule 3: symbol PLUS word, always — \
                and "Default" is the glossary's word for the value a fresh install has.
                """)
        }
        XCTAssertTrue(row.contains("enabled: effective > 0"), "Smaller is dimmed on the first rung — a key may not offer a move it cannot make (#164/#227)")
        XCTAssertTrue(row.contains("enabled: effective < last"), "Larger is dimmed on the last rung")
        XCTAssertTrue(row.contains("enabled: step >= 0"), "Default is dimmed while the size already follows the system")
        XCTAssertTrue(row.contains("step = Swift.max(effective - 1, 0)") && row.contains("step = Swift.min(effective + 1, last)"), """
            Smaller / Larger no longer step from the rung IN EFFECT with a clamp. At -1 the rung in \
            effect is the system size's own (`StudioZoom.systemIndex`), so the first tap must move \
            one step from what the eye sees — never jump to `.large`.
            """)
        XCTAssertTrue(row.contains("step = StudioDefaultKeys.zoomStep.value"), "Default writes the keystore's default, not a literal -1 (#416)")
        XCTAssertTrue(row.contains("StudioZoom.systemIndex(sizeInEffect)"), "the rung in effect at -1 is asked from `StudioZoom`, the one owner of the ladder")
        XCTAssertTrue(row.contains(".frame(maxWidth: .infinity, minHeight: 44)"), "each button is at least 44 pt tall (HIG floor; WCAG 2.5.8)")
        XCTAssertTrue(row.contains(".disabled(!enabled)"), "the dimming is a real `.disabled`, not a colour alone")
        XCTAssertTrue(row.contains("isAccessibilitySize") && row.contains("AnyLayout(VStackLayout"), "at accessibility sizes the three words stack instead of clipping")
        XCTAssertTrue(row.contains("follow the system size") || row.contains("follows the system size"), "the caption states the SCOPE — the instrument's text; head and piece follow the system size (rule 9)")
        XCTAssertTrue(row.contains("\\(StudioZoom.ladder.count)"), "the caption's denominator is the ladder's count, never a typed 9 (#818)")
    }

    // MARK: - claim 3 — the door and the shared rung

    func testTheRowIsMountedOnceInSaveAndExportAndCanReadTheSystemRung() throws {
        let code = try source(Self.studio)
        let plate = slice(code, from: "private var utilityRow: some View {", to: "private var skillLevelRow: some View {")
        XCTAssertEqual(occurrences(of: "TextSizeRow()", in: plate), 1, """
            Save & Export builds `TextSizeRow` exactly once, beside the level picker — the plate \
            that holds the app's other settings (rule 8: one fixed place), reachable at every \
            skill level because `.export` is unconditional in the strip filter.
            """)
        XCTAssertEqual(occurrences(of: "TextSizeRow()", in: code), 1, "and nowhere else — one door")
        let zoom = slice(code, from: "private struct StudioZoom: ViewModifier {", to: "\n}\n")
        XCTAssertTrue(zoom.contains("    static func systemIndex(_ s: DynamicTypeSize) -> Int {"), """
            `StudioZoom.systemIndex` went private again. The row steps from the rung in effect, \
            and at -1 that rung is the system size's — only this function knows it.
            """)
        XCTAssertFalse(zoom.contains("private static func systemIndex"), "the row needs `systemIndex`; a private one would not compile")
    }

    // MARK: - claim 4 — counterweight: the pinch and the nine-rung ladder survive

    func testThePinchAndTheLadderAreUnchanged() throws {
        let code = try source(Self.studio)
        let zoom = slice(code, from: "private struct StudioZoom: ViewModifier {", to: "\n}\n")
        XCTAssertTrue(zoom.contains("MagnifyGesture(minimumScaleDelta: 0.05)"), "the pinch stays — the buttons are added beside it, never in place of it")
        let ladder = slice(zoom, from: "static let ladder: [DynamicTypeSize] = [", to: "]")
        let rungs = ladder.components(separatedBy: ".").count - 1
        XCTAssertEqual(rungs, 9, "nine rungs, `.large` … `.accessibility5` — the caption reads its count from here")
        XCTAssertTrue(ladder.contains(".large,") && ladder.contains(".accessibility5"), "first `.large`, last `.accessibility5`")
        XCTAssertTrue(code.contains(".modifier(StudioZoom(step: $zoomStep))"), "the root still applies the size — one application point, inside the instrument")
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

    /// Every Swift file under `Sources/`, by walking the tree (no git needed on the runner).
    private func trackedSources(_ root: URL) throws -> [String] {
        let base = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: base, includingPropertiesForKeys: nil) else { return [] }
        var out: [String] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            out.append("Sources/" + url.path.replacingOccurrences(of: base.path + "/", with: ""))
        }
        return out.sorted()
    }

    private func slice(_ code: String, from: String, to: String) -> String {
        guard let start = code.range(of: from) else { return "" }
        guard let end = code.range(of: to, range: start.upperBound..<code.endIndex) else { return "" }
        return String(code[start.lowerBound..<end.lowerBound])
    }

    private func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }
}
