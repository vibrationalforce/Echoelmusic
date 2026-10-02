// TheRecordButtonWearsTheRecordingRedTests.swift
// Echoel — H14 (decided 2026-10-02 under the founder's "Du entscheidest"): Record must never read
// as a second Stop. Since slice C the transport is ONE row, so the piece's Stop and the Record
// button's "Stop recording" stand side by side. The DAW convention separates them by colour:
// Record is a red dot while ready and a red fill while recording.
//
// THE THREE CLAIMS:
// 1. SOURCE: `RecordTakeButton` fills with `EchoelTheme.recording` while recording, and no longer
//    with `EchoelTheme.warning` (amber is the "needs attention" colour, not "recording").
// 2. SOURCE: the glyph is red while ready (`state == .ready ? EchoelTheme.recording`), dim while
//    blocked, and the black label colour while recording (it sits on the red fill).
// 3. ARITHMETIC on numbers PARSED from `EchoelTheme.swift` (never hand-copied, #416): black on
//    the `recording` red clears 4.5:1, so the word "Stop recording" stays legible on its fill.
//
// GRADING (§0/§3 — transcribed in Python against the parent b364574e4 and this tree):
// claim 1 is a REGRESSION (red on the parent: the fill was `.warning`); claim 2 is a REGRESSION
// (red on the parent: the glyph took the label colour); claim 3 is a COUNTERWEIGHT, green on both
// (the token existed; 5.5:1). DEVICE PROBE, open: the red dot reads as Record beside Stop at 375 pt.

import XCTest

final class TheRecordButtonWearsTheRecordingRedTests: XCTestCase {

    private static let controls = "Sources/Echoelmusic/Studio/RecordTakeControls.swift"
    private static let theme = "Sources/Echoelmusic/Studio/EchoelTheme.swift"

    func testRecordingFillsWithTheRecordingRed() throws {
        let button = try buttonBody()
        XCTAssertTrue(button.contains(".fill(recording ? EchoelTheme.recording : EchoelTheme.fill))"), """
            `RecordTakeButton` no longer fills with the `recording` red while a take runs. Beside \
            the piece's Stop (one transport row since slice C) an amber "Stop recording" reads as a \
            second Stop (H14).
            """)
        XCTAssertFalse(button.contains("EchoelTheme.warning"),
                       "amber means 'needs attention'; the Record button is red or neutral, never amber")
    }

    func testTheReadyGlyphIsARedDot() throws {
        // Whitespace is collapsed so a re-indent cannot red this claim (#364).
        let button = try buttonBody().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        XCTAssertTrue(button.contains(
            ".foregroundStyle(recording ? EchoelTheme.onPrimary : (state == .ready ? EchoelTheme.recording : EchoelTheme.dim))"), """
            the Record glyph is no longer red while ready (black on the red fill while recording, \
            dim while blocked). A ready Record that looks like every other icon is the H14 confusion.
            """)
    }

    func testBlackOnTheRecordingRedIsLegible() throws {
        let theme = try text(Self.theme)
        guard let line = theme.components(separatedBy: "\n")
                .first(where: { $0.contains("static let recording = Color(") }) else {
            return XCTFail("ANCHOR MISSING: `EchoelTheme.recording` is gone — re-anchor (#454)")
        }
        let numbers = line.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .compactMap(Double.init).filter { $0 <= 1 }
        guard numbers.count >= 3 else { return XCTFail("could not parse three components from: \(line)") }
        func linear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        let luminance = 0.2126 * linear(numbers[0]) + 0.7152 * linear(numbers[1]) + 0.0722 * linear(numbers[2])
        let ratio = (luminance + 0.05) / 0.05
        XCTAssertGreaterThanOrEqual(ratio, 4.5, """
            black on `EchoelTheme.recording` reads \(ratio):1 — under WCAG AA, so "Stop recording" \
            on the red fill is not legible. Darken the label or lighten the red.
            """)
    }

    // MARK: helpers

    private func buttonBody() throws -> String {
        let code = SourceText.codeOnly(try text(Self.controls))
        guard let start = code.range(of: "struct RecordTakeButton: View"),
              let end = code.range(of: "struct RecordTakeNote: View", range: start.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: `RecordTakeButton` or its neighbour `RecordTakeNote` moved (#454)")
            return ""
        }
        return String(code[start.lowerBound..<end.lowerBound])
    }

    private func text(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
