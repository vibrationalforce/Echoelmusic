// TheChromeTextMeetsTheElevenPointFloorTests.swift
// Echoel — interface audit 2026-09-30, Gestaltung rule 12 ("Textgröße"), the FLOOR half.
// BLOCKING bundle.
//
// The audit measured the app's type ladder: 205 sites at 11 pt, 37 at 10 pt, 5 at 9 pt, all
// through `EchoelTheme.font(_:_:)`, which is `relativeTo: .body` and so scales with Dynamic Type
// AND the one `StudioZoom` step (rule 12 parts 1 + 2). Scaling multiplies what is there: a 9 pt
// label at the default step is 9 pt, and the HIG floor for readable text on iPhone is 11 pt
// (`caption2`). The head — the strip a player reads mid-piece, at arm's length, in a dark room —
// had twelve labels under it: the version string (9), the loop counter and the file preview
// (10), the pulse pill's "Found" and "Demo" tags (10), the output tiles' status word (10), the
// visual card's transport readout (10 + 9) and its WAV status words (10). Every one of them
// ALSO carried a `minimumScaleFactor`, so what the player actually saw could be smaller still.
//
// THE DECISION: 11 pt is the chrome's floor. Hierarchy below the floor is carried by weight and
// by the `dim` colour, never by going smaller — the visual card's "1/8" beside its "1.2.3" keeps
// its `opacity(0.6)`, not its 9 pt. Nothing above the floor is touched: the 204 remaining 11 pt
// sites (below `body`'s 13) are a founder look on the device, not a scan.
//
// WHAT THIS GUARDS.
//   1. RATCHET: no `EchoelTheme.font(N` and no `.system(size: N` with N < 11 in the listed head
//      files, comment-stripped. The list grows; a file joins it in the same commit that lifts
//      its last sub-floor label. A file that MOVES turns the scan into a skip, not a pass.
//   2. PREMISE: `EchoelTheme.font` stays `relativeTo: .body`. A floor on an absolute font would
//      be a different, weaker claim — this one holds because the floor scales with the step.
//   3. SELF-TEST: the scanner finds a planted `font(9)` and a planted `.system(size: 10)`, and
//      ignores the same text inside a comment (#867: a rationale that QUOTES the old size must
//      not fail the scan, and a scanner that matches nothing is a finding, not a pass).
//
// ⚠️ LIMIT — source scan. That the lifted labels still fit their tiles at the default step is a
// look: the output tiles have founder-reference widths and shrink before they clip
// (`minimumScaleFactor(0.6)`), the visual card's transport row grows by roughly one digit.
// NEEDS-FOUNDER-VERIFY: head at the default text step — pulse pill "Found"/"Demo", the two
// output tiles' word, the small visual card's "1.2.3 · 1/8" row — nothing clipped, nothing
// wrapped.
//
// ⚠️ HONEST GRADING (#433/#464) — transcribed in Python against this tree and the parent
// 37ab57ac9 (no local toolchain): claim 1 RED on the parent (twelve sites), GREEN here; claims 2
// and 3 GREEN on both (premise and self-test). `Tests/CISmoke` is the blocking bundle.
// SECOND FAMILY (same day, parent e29787d68): three strip files joined the list with their nine
// sites lifted (AutomationStatusStrip 4 · AlwaysOnBioRow 2 · PatchbayView 2 + one glyph) — claim 1
// RED on that parent for exactly those nine, GREEN here.
// THIRD FAMILY (same day, parent a6648876d): `EchoelStudioView` joined with fifteen sites lifted
// (eight captions, seven glyphs) — claim 1 RED on that parent for exactly those, GREEN here.
// `SectionHeadingIsOneTreatmentTests` anchors `font(10, .medium)` only as an ABSENCE (no inline
// heading may be spelled that way), so lifting the captions leaves it green for its own reason.
// FOURTH FAMILY (same day, parent 983b15ba4): the bio surfaces joined with ten sites lifted
// (BioStripView 1 + 5 glyphs · BioMetricInfo 2 + 1 glyph · BioSourceView 1) — claim 1 RED on that
// parent for exactly those ten, GREEN here. `CoachingTextScalesTests` counts the banner's two
// `EchoelTheme.font(` calls and `InfoSheetTextScalesTests` asks who OWNS each `.system(size:`,
// neither reads the number — both stay green for their own reason.
// FIFTH FAMILY (same day, parent 21a11e2e6): EchoelFXView (two arrows 9/10 + the "Demo" chip 10),
// ImmersiveStageView (orientation labels, lane names), ArrangeCanvasView (hearing glyph, bar
// marks) joined with seven sites lifted — claim 1 RED on that parent for exactly those, GREEN
// here. The FX "Demo" chip now matches the 11 pt chip `AlwaysOnBioRow` got in the second family —
// the source comment beside it promises "same spelling, same treatment", and it was one point off.
// SIXTH FAMILY (same day, parent 146d67fe3): the last seven single sites (WorkstationView state
// tags · SessionView version · PartNoteEditor octave labels · MoodPads axis caption ·
// LiveColaboView "Demo" chip · LiveNarrationDisclosure chevron · the AUv3 view controller's
// section titles) — claim 1 RED on that parent for exactly those, GREEN here. With this the
// comment-stripped scan `git grep -nE 'EchoelTheme\.font\((10|9)|\.system\(size: *(10|9)\b' -- Sources`
// returns nothing: the floor is app-wide, and the list is the whole set of files that ever had a
// site below it. A NEW file under the floor is not caught by claim 1 — that is the ratchet's
// stated limit, and the next family adds the file, not a directory scan (#364).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheChromeTextMeetsTheElevenPointFloorTests: XCTestCase {

    /// The floor. Named once here; the message quotes it from this constant.
    private static let floor = 11

    /// The head files. RATCHET — append, never remove (#364 forbids nothing: a file may join as
    /// soon as its last sub-floor label is lifted, and that is the commit that adds it).
    private static let chrome = [
        "Sources/Echoelmusic/Studio/WorkspaceView.swift",
        "Sources/Echoelmusic/Studio/HeaderMonitors.swift",
        "Sources/Echoelmusic/Studio/FloatingVisualWindow.swift",
        // Second family (same day): the instrument's status strips — the automation strip's
        // captions, the always-on bio row's "Demo"/"held" tags, the routing surface's
        // conversion note, its "soon" tag (9 pt in a 16 pt pill) and one arrow glyph.
        "Sources/Echoelmusic/Studio/AutomationStatusStrip.swift",
        "Sources/Echoelmusic/Studio/AlwaysOnBioRow.swift",
        "Sources/Echoelmusic/Studio/PatchbayView.swift",
        // Third family (same day): the instrument itself — eight 10 pt captions (the bio
        // panel's four, the reset note, the AirPlay hint, the Weather attribution, the look
        // position) and seven 10 pt chevron/star glyphs beside 13 pt titles.
        "Sources/Echoelmusic/Studio/EchoelStudioView.swift",
        // Fourth family (same day): the bio surfaces — the strip's banner glyph and five 9 pt
        // tag/button glyphs, the metric sheet's two origin notes and its arrow, the doorless
        // source view's "Band" label.
        "Sources/Echoelmusic/Studio/BioStripView.swift",
        "Sources/Echoelmusic/Studio/BioMetricInfo.swift",
        "Sources/Echoelmusic/Studio/BioSourceView.swift",
        // Fifth family (same day): the FX routes' two arrows and their "Demo" chip, the stage's
        // orientation labels and lane names, the arrange canvas's hearing glyph and bar marks.
        "Sources/Echoelmusic/Studio/EchoelFXView.swift",
        "Sources/Echoelmusic/Studio/ImmersiveStageView.swift",
        "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift",
        // DAW shell S9a review: the time zoom's two buttons, beside the canvas they zoom.
        "Sources/Echoelmusic/Studio/ArrangeTimeZoom.swift",
        // Sixth family (same day): the last seven single sites — the Workstation's state tags,
        // the Session view's version, the note editor's octave labels (Canvas-drawn), the mood
        // pads' axis caption, the peer row's "Demo" chip, the narration disclosure's chevron,
        // and the AUv3 host view's section titles (no `EchoelTheme` in the extension — the
        // absolute `.system(size:)` stays, only its number rises).
        "Sources/Echoelmusic/Studio/WorkstationView.swift",
        "Sources/Echoelmusic/Studio/SessionView.swift",
        "Sources/Echoelmusic/Studio/PartNoteEditor.swift",
        "Sources/Echoelmusic/Studio/MoodPads.swift",
        "Sources/Echoelmusic/Studio/LiveColaboView.swift",
        "Sources/Echoelmusic/Studio/LiveNarrationDisclosure.swift",
        "Sources/EchoelmusicAUv3/AudioUnitViewController.swift",
    ]

    private static let theme = "Sources/Echoelmusic/Studio/EchoelTheme.swift"

    // MARK: - claim 1 — the ratchet

    func testNoHeadLabelSitsUnderTheFloor() throws {
        var offenders: [String] = []
        for rel in Self.chrome {
            let lines = try codeLines(rel)
            for (i, line) in lines.enumerated() {
                for size in Self.sizes(in: line) where size < Self.floor {
                    offenders.append("\(rel):\(i + 1): \(size) pt — \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty, """
            \(offenders.count) head label(s) sit under the \(Self.floor) pt floor (rule 12):
            \(offenders.joined(separator: "\n"))
            Lift the size to \(Self.floor) and carry the hierarchy with weight or `dim`, never by \
            going smaller — the head is read at arm's length and this size multiplies with the \
            text step. If a label genuinely is not text a player reads (a glyph sized by \
            `.system(size:)` next to a word, for instance), say so in a comment on the line and \
            raise it in the Council before exempting it here.
            """)
    }

    // MARK: - claim 2 — the premise: the floor scales

    func testTheThemeFontScalesWithTheBodyStyle() throws {
        let theme = SourceText.codeOnly(try source(Self.theme))
        XCTAssertTrue(theme.contains("static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {"),
                      "`EchoelTheme.font(_:_:)` moved — re-anchor this premise rather than letting it pass on nothing (#454)")
        XCTAssertTrue(theme.contains("relativeTo: .body"), """
            `EchoelTheme.font` no longer scales `relativeTo: .body`. The 11 pt floor is a floor at \
            the DEFAULT text step only because the size multiplies with Dynamic Type and the one \
            `StudioZoom` step; an absolute font would need a different, larger floor.
            """)
    }

    // MARK: - claim 3 — the scanner sees a plant and ignores a comment

    func testTheScannerFindsAPlantedSizeAndIgnoresAComment() {
        XCTAssertEqual(Self.sizes(in: "    .font(EchoelTheme.font(9))"), [9])
        XCTAssertEqual(Self.sizes(in: ".font(EchoelTheme.font(10, .semibold).monospacedDigit())"), [10])
        XCTAssertEqual(Self.sizes(in: "Image(systemName: glyph).font(.system(size: 10))"), [10])
        XCTAssertEqual(Self.sizes(in: ".font(EchoelTheme.font(11, .semibold))"), [11])
        XCTAssertEqual(Self.sizes(in: "let x = 9"), [], "a bare number is not a font size")
        let commented = SourceText.codeOnly("// was `EchoelTheme.font(9)` until rule 12\n.font(EchoelTheme.font(11))\n")
        XCTAssertEqual(commented.components(separatedBy: "\n").flatMap { Self.sizes(in: $0) }, [11],
                       "a rationale that quotes the old size must not fail the scan (#867)")
    }

    // MARK: - the scanner

    /// Every point size a line asks a font for: `EchoelTheme.font(N` and `.system(size: N`.
    static func sizes(in line: String) -> [Int] {
        var out: [Int] = []
        for pattern in [#"EchoelTheme\.font\((\d+)"#, #"\.system\(size:\s*(\d+)"#] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            for match in regex.matches(in: line, range: range) {
                if let r = Range(match.range(at: 1), in: line), let n = Int(line[r]) { out.append(n) }
            }
        }
        return out
    }

    // MARK: - reading the source

    private func repoRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) else {
            throw XCTSkip("repository root not found from \(#filePath) — source scan skipped, not passed")
        }
        return url
    }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw XCTSkip("\(relativePath) is absent — the list names a file that moved; update it, do not let the scan pass on nothing")
        }
        return try String(contentsOf: path, encoding: .utf8)
    }

    /// Comment-stripped lines (line numbers preserved for the failure text).
    private func codeLines(_ relativePath: String) throws -> [String] {
        SourceText.codeOnly(try source(relativePath)).components(separatedBy: "\n")
    }
}
