// TheTextSizeHasButtonsTests.swift
// Echoel — interface audit 2026-09-30, rule 12: "Sichtbare Anpassung: Textgröße als Knöpfe
// (nicht nur Kneifen)" (WCAG 1.4.4).
//
// WHAT THIS GUARDS. The app already had an in-app text size: `StudioZoom` drives Dynamic Type
// through a nine-rung ladder (`.large` … `.accessibility5`) from a persisted step, `-1` meaning
// "follow the system". Its ONLY writer was a two-finger pinch — a gesture nothing on screen
// announces, that a person with one hand, a tremor or a switch cannot make, and that the
// founder's own audit line names as the defect. This slice adds the buttons and keeps ONE size:
//   · `StudioDefaultKeys.zoomStep` — the key moves into the keystore because it then had two
//     writers (pinch + buttons); its STRING stays the pre-keystore literal so a size a user
//     pinched before this commit survives the update.
//   ⭐ DAW SHELL S9a (founder 2026-10-02, inbox E16 „Zeit zoomen"): the pinch LEFT `StudioZoom` —
//     it zooms the arrangement's time now — so the buttons are the ONE writer and `StudioZoom`
//     takes the step as a value. Claim 4 pins that (it pinned "the pinch stays" until S9a).
//   · `TextSizeRow` in Save & Export, beside the level picker: Smaller · Larger · Default, each
//     symbol PLUS word (rule 3), 44 pt tall, dimmed where it cannot move (#164/#227). Smaller and
//     Larger step from the rung IN EFFECT (`StudioZoom.systemIndex` while at `-1`), Default
//     returns to `-1`. The caption says the level and the SCOPE: the piece and the instrument —
//     the head keeps its `.accessibility1` ceiling (`ChromeDynamicTypeTests`). ⛔ Until part 2
//     (same day) the scope was the instrument alone, because `StudioZoom` was mounted inside
//     `EchoelStudioView`; part 2 moved the ONE application point to `SurfaceHost` in
//     `WorkspaceView`, the host of both stages — never a second key, never a second pinch.
//
// ⚠️ LIMIT — SOURCE-TEXT SCAN plus one keystore constant. `TextSizeRow` is file-private and
// `StudioZoom` is internal only so the root can mount it, so nothing here taps a button; that
// three 44 pt buttons fit a portrait phone at the top rung is a founder look. The chrome ceiling is pinned by
// `ChromeDynamicTypeTests`, not repeated here (#416). Where the pinch went is pinned by
// `ThePinchZoomsTheArrangementsTimeTests`; claim 4 here only pins that it is GONE from `StudioZoom`.
//
// ⚠️ HONEST GRADING (#433/#464) — transcribed in Python against this tree and the parent
// 27b8918e3 (no local toolchain): claims 1–3 RED on the parent for their named reasons (the
// keystore entry, the row, the mount and the non-private `systemIndex` are born here; the raw
// `"ui.zoomStep"` literal sat in the root); claim 4 GREEN on both — the counterweight (#343):
// the pinch gesture and the nine-rung ladder are unchanged, so a slice that replaced the pinch
// with the buttons instead of adding to it would turn it red.
// S9a (parent 88058461d): claim 4's gesture, `let step`, no-`@Binding` and no-assignment
// assertions are RED on the parent for their named reason (the pinch sat on `StudioZoom` and
// assigned `step = …` through a binding) — one finding, the move (#486); the mount needle moved
// with the value (`$zoomStep` → `zoomStep`) and is red there by the same move; the ladder and
// one-application-point assertions are counterweights, green on both. The S9a review narrowed
// the no-assignment needle from `"step ="` to an assignment pattern that a comparison cannot
// match — still red on the parent (it assigned), green here.
// PART 2 (same day, parent 8b9bd76b1): claims 1, 3 and 4 RED on the parent — the studio file
// held TWO readers of the key and the root none, `StudioZoom` was `private` so the
// `\nstruct StudioZoom` slice was empty, and `SurfaceHost` carried no modifier; claim 2 GREEN on
// both (the row and its caption shape are unchanged; only the scope sentence moved).
// `Tests/CISmoke` is the blocking bundle. SKIPS rather than passes if the tree is absent.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheTextSizeHasButtonsTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let keystore = "Sources/Echoelmusic/Core/StudioDefaultKeys.swift"
    private static let workspace = "Sources/Echoelmusic/Studio/WorkspaceView.swift"

    // MARK: - claim 1 — one key, in the keystore, with the shipped string and the follow-system default

    func testTheTextSizeIsOneKeystoreKeyWithTheShippedString() throws {
        XCTAssertEqual(StudioDefaultKeys.zoomStep.key, "ui.zoomStep", """
            The text-size key string changed. It is the on-disk contract with every install that \
            ever set a size: a new string silently resets their size to the system's.
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
        XCTAssertEqual(occurrences(of: "@AppStorage(StudioDefaultKeys.zoomStep.key)", in: studio), 1,
                       "exactly one reader of the key in the instrument file: `TextSizeRow`, which writes it (part 2 moved the applying reader to the root)")
        let workspace = try source(Self.workspace)
        XCTAssertEqual(occurrences(of: "@AppStorage(StudioDefaultKeys.zoomStep.key)", in: workspace), 1,
                       "exactly one reader of the key in the root: the property `StudioZoom` is bound to on `SurfaceHost`")
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
        XCTAssertTrue(row.contains("follow the system size") || row.contains("follows the system size"), "the caption states the SCOPE — the piece and the instrument; the head follows the system size (rule 9)")
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
        let zoom = slice(code, from: "\nstruct StudioZoom: ViewModifier {", to: "\n}\n")
        XCTAssertTrue(zoom.contains("    static func systemIndex(_ s: DynamicTypeSize) -> Int {"), """
            `StudioZoom.systemIndex` went private again. The row steps from the rung in effect, \
            and at -1 that rung is the system size's — only this function knows it.
            """)
        XCTAssertFalse(zoom.contains("private static func systemIndex"), "the row needs `systemIndex`; a private one would not compile")
    }

    // MARK: - claim 4 — the buttons are the ONE writer; the ladder and the one application point survive

    func testTheButtonsAreTheOneWriterAndTheLadderIsUnchanged() throws {
        let code = try source(Self.studio)
        let zoom = slice(code, from: "\nstruct StudioZoom: ViewModifier {", to: "\n}\n")
        XCTAssertFalse(zoom.isEmpty, "ANCHOR MISSING: `struct StudioZoom: ViewModifier` (#454)")
        // DAW shell S9a (founder 2026-10-02, E16 „Zeit zoomen"): the pinch zooms the arrangement's
        // TIME. A gesture left on this modifier sits on the ancestor of the canvas and would resize
        // the text under every time-zoom — one gesture, two meanings.
        for gesture in ["MagnifyGesture", "MagnificationGesture", ".gesture(", ".simultaneousGesture(", ".highPriorityGesture("] {
            XCTAssertFalse(zoom.contains(gesture), """
                `StudioZoom` carries `\(gesture)` again. Since S9a it only APPLIES the stored step; the \
                pinch belongs to the arrangement's time axis (`ArrangeTimeZoom`), and the text size is \
                set by the three buttons in Save & Export.
                """)
        }
        XCTAssertTrue(zoom.contains("    let step: Int\n"), """
            `StudioZoom.step` is no longer a plain value. A binding here is a second writer waiting \
            to happen — `TextSizeRow` is the one writer of the key (S9a).
            """)
        XCTAssertFalse(zoom.contains("@Binding"), "`StudioZoom` takes the step as a value — it never writes it")
        // An ASSIGNMENT (`=`, `+=`, `-=`, …), never a comparison: the S9a needle was the bare
        // `"step ="`, which a later `step == …` would have turned red on correct code (review LOW-11).
        XCTAssertNil(zoom.range(of: #"\bstep\s*[-+*/]?=(?!=)"#, options: .regularExpression),
                     "`StudioZoom` assigns the step — only `TextSizeRow` writes the key")
        let ladder = slice(zoom, from: "static let ladder: [DynamicTypeSize] = [", to: "]")
        let rungs = ladder.components(separatedBy: ".").count - 1
        XCTAssertEqual(rungs, 9, "nine rungs, `.large` … `.accessibility5` — the caption reads its count from here")
        XCTAssertTrue(ladder.contains(".large,") && ladder.contains(".accessibility5"), "first `.large`, last `.accessibility5`")
        // Part 2 (2026-09-30): the ONE application point is the root, on `SurfaceHost` — both stages.
        let workspace = try source(Self.workspace)
        let host = slice(workspace, from: "                SurfaceHost()", to: ".frame(maxWidth: .infinity, maxHeight: .infinity)")
        XCTAssertTrue(host.contains(".modifier(StudioZoom(step: zoomStep))"), """
            `WorkspaceView` no longer mounts `StudioZoom` on `SurfaceHost`. That is the one application \
            point since part 2: the piece and the instrument share the size, the head keeps its ceiling.
            """)
        XCTAssertEqual(occurrences(of: ".modifier(StudioZoom(step:", in: workspace), 1, "one application point in the root")
        XCTAssertEqual(occurrences(of: ".modifier(StudioZoom(step:", in: code), 0, """
            The instrument applies `StudioZoom` again. Two application points on one key size the \
            instrument twice — the scope is widened by MOVING the point, never by adding one.
            """)
        XCTAssertFalse(code.contains("private struct StudioZoom"), "`StudioZoom` must stay internal so the root can mount it")
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
