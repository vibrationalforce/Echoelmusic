// TheTracksWearTheirOwnHueTests.swift
// Echoel — every track carries ONE hue through its header and its parts, and the hue is legible,
// distinct, and never the only cue (Workstation redesign A1, founder 2026-10-01).
//
// WHY: the founder, beside the tablet workstation mockup — *„Gestalte alles so um, dass ich
// Echoelmusic als Workstation ernsthaft vertreten kann."* Every reference (Logic, Cubasis, both
// mockups) colours a track once and carries that colour into its parts; the arrange canvas drew
// every part in the same `dim` grey, so four tracks read as one strip. `EchoelTheme.TrackHue` is
// the one switch that decides a track's hue (the way `TrackInstrument.systemImage` decides its
// symbol), and `ArrangeCanvasView` paints the gutter band, the symbol and the part body with it.
//
// THE FOUR CLAIMS:
// 1. Every hue reads on the dark ground (≥ 4.5:1 on black AND on `surface`), computed from the
//    SAME components the colour is built from — never a re-typed literal (#416).
// 2. Only the body track wears the bio-green: every other hue stays clear of `accent`, `danger`
//    and `warning` (parsed from `EchoelTheme.swift`), and no two hues are near-twins.
// 3. One switch maps every instrument and every kind — the mapping is pinned by behaviour.
// 4. The canvas never lets colour travel alone: the gutter pairs the hue with the instrument's
//    symbol and the track's name; the part's body is the hue; the selection ring stays `accent`.
//
// GRADING (§0, no Swift toolchain in a web session): claims 1–3 are RUNTIME claims on a type that
// does not exist on the parent tree — they cannot be red there, they would not compile. They were
// re-derived in Python on the work tree (contrast 6.95…11.59:1, closest pair sampler/breakbeat
// 0.139, nearest meaning colour 0.249). Claim 4 is a SOURCE claim: transcribed against the work
// tree (green) and the parent (red — the gutter had no hue and the block filled with `dim`).

import XCTest
#if canImport(SwiftUI)
@testable import Echoelmusic

final class TheTracksWearTheirOwnHueTests: XCTestCase {

    private static let theme = "Sources/Echoelmusic/Studio/EchoelTheme.swift"
    private static let canvas = "Sources/Echoelmusic/Studio/ArrangeCanvasView.swift"

    private typealias RGB = (red: Double, green: Double, blue: Double)

    // MARK: 1 — legible on the dark ground

    func testEveryTrackHueReadsOnTheDarkGround() {
        let black = luminance((0, 0, 0))
        let surface = luminance((EchoelTheme.surfaceComponent, EchoelTheme.surfaceComponent, 0.070))
        for hue in EchoelTheme.TrackHue.allCases {
            let own = luminance(hue.components)
            XCTAssertGreaterThanOrEqual(contrast(own, black), 4.5,
                                        "\(hue) reads \(ratio(contrast(own, black))) on black — needs 4.5:1")
            XCTAssertGreaterThanOrEqual(contrast(own, surface), 4.5,
                                        "\(hue) reads \(ratio(contrast(own, surface))) on `surface` — needs 4.5:1")
        }
    }

    // MARK: 2 — only the body wears the bio-green; no hue imitates a meaning colour

    func testOnlyTheBodyTrackWearsTheBioGreen() throws {
        let code = SourceText.codeOnly(try text(Self.theme))
        let accent = try token("accent", in: code)
        let danger = try token("danger", in: code)
        let warning = try token("warning", in: code)

        XCTAssertLessThan(distance(EchoelTheme.TrackHue.body.components, accent), 0.001,
                          "the body track IS the body's signal — it wears `accent`, exactly")
        let others = EchoelTheme.TrackHue.allCases.filter { $0 != .body }
        for hue in others {
            for (name, meaning) in [("accent", accent), ("danger", danger), ("warning", warning)] {
                XCTAssertGreaterThanOrEqual(distance(hue.components, meaning), 0.2, """
                    \(hue) sits within 0.2 of `\(name)` — a track colour must not read as the bio \
                    signal, an error or a recording state
                    """)
            }
        }
        for (i, a) in others.enumerated() {
            for b in others.dropFirst(i + 1) {
                XCTAssertGreaterThanOrEqual(distance(a.components, b.components), 0.12,
                                            "\(a) and \(b) are near-twins — two tracks would read as one")
            }
        }
    }

    // MARK: 3 — one switch maps every instrument and every kind

    func testOneSwitchMapsEveryTrack() {
        typealias Hue = EchoelTheme.TrackHue
        XCTAssertEqual(Hue.of(kind: .midi, instrument: .polySynth, isBio: false), .synth)
        XCTAssertEqual(Hue.of(kind: .midi, instrument: .subBass, isBio: false), .bass)
        XCTAssertEqual(Hue.of(kind: .midi, instrument: .sampler, isBio: false), .sampler)
        XCTAssertEqual(Hue.of(kind: .midi, instrument: .breakLoop, isBio: false), .breakbeat)
        XCTAssertEqual(Hue.of(kind: .midi, instrument: .bioVoice, isBio: false), .body)
        XCTAssertEqual(Hue.of(kind: .midi, instrument: nil, isBio: false), .echoel,
                       "a MIDI track without a built-in instrument is the generative Echoel track")
        XCTAssertEqual(Hue.of(kind: .audio, instrument: nil, isBio: false), .audio)
        XCTAssertEqual(Hue.of(kind: .visual, instrument: nil, isBio: false), .visual)
        XCTAssertEqual(Hue.of(kind: .audio, instrument: nil, isBio: true), .body,
                       "a bio lane carries the body's curve — it wears the body's colour")
        // Every combination resolves, and every resolution carries a symbol beside it.
        let instruments: [TrackInstrument?] = [nil] + TrackInstrument.allCases.map { $0 }
        for kind in ClipKind.allCases {
            for instrument in instruments {
                for isBio in [false, true] {
                    XCTAssertFalse(Hue.symbol(kind: kind, instrument: instrument, isBio: isBio).isEmpty,
                                   "\(kind)/\(String(describing: instrument)) has a hue and no symbol")
                }
            }
        }
    }

    // MARK: 4 — the canvas never lets colour travel alone

    func testTheCanvasPairsTheHueWithASymbolAndAName() throws {
        let file = SourceText.codeOnly(try text(Self.canvas))
        guard let gutter = file.range(of: "private func nameGutter(_ row: WorkstationSummary.LaneRow) -> some View {"),
              let gutterEnd = file.range(of: "private func laneRow(", range: gutter.upperBound..<file.endIndex),
              let block = file.range(of: "struct ArrangePartBlock: View {") else {
            return XCTFail("ANCHOR MISSING: `nameGutter`, `laneRow` or `ArrangePartBlock` (#454)")
        }
        let gutterBody = String(file[gutter.upperBound..<gutterEnd.lowerBound])
        XCTAssertTrue(gutterBody.contains("EchoelTheme.TrackHue.of(kind: row.kind, instrument: row.instrument, isBio: row.isBio)"),
                      "the gutter asks the one switch for the track's hue")
        XCTAssertTrue(gutterBody.contains("EchoelTheme.TrackHue.symbol(kind: row.kind, instrument: row.instrument,"),
                      "the hue travels with the instrument's symbol")
        XCTAssertTrue(gutterBody.contains("Text(row.name)"), "and with the track's name")

        let blockBody = String(file[block.upperBound...])
        XCTAssertTrue(blockBody.contains("let tint: Color"), "a part knows its track's hue")
        XCTAssertTrue(blockBody.contains(".fill(tint.opacity(Self.tintOpacity))"),
                      "the part's body is its track's hue — not one grey for every track")
        XCTAssertTrue(blockBody.contains(".strokeBorder(isSelected || moving ? EchoelTheme.accent :"),
                      "the selection ring stays `accent`, so a selected part is louder than its hue")
        XCTAssertFalse(blockBody.contains(".fill(EchoelTheme.dim)"),
                       "a part filled with `dim` is the grey strip the founder rejected")
    }

    // MARK: helpers

    private func linearise(_ c: Double) -> Double {
        c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    private func luminance(_ c: RGB) -> Double {
        0.2126 * linearise(c.red) + 0.7152 * linearise(c.green) + 0.0722 * linearise(c.blue)
    }

    private func contrast(_ a: Double, _ b: Double) -> Double {
        let (hi, lo) = a > b ? (a, b) : (b, a)
        return (hi + 0.05) / (lo + 0.05)
    }

    private func ratio(_ value: Double) -> String { String(format: "%.2f:1", value) }

    private func distance(_ a: RGB, _ b: RGB) -> Double {
        let dr = a.red - b.red, dg = a.green - b.green, db = a.blue - b.blue
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    /// A semantic colour's components, read from its `static let <name> = Color(red:green:blue:)`
    /// line — never re-typed here (#416).
    private func token(_ name: String, in code: String) throws -> RGB {
        let pattern = "static let \(name)\\s*=\\s*Color\\(red: ([0-9.]+), green: ([0-9.]+), blue: ([0-9.]+)\\)"
        guard let match = code.range(of: pattern, options: .regularExpression) else {
            XCTFail("ANCHOR MISSING: `static let \(name) = Color(red:green:blue:)` in EchoelTheme (#454)")
            return (0, 0, 0)
        }
        let line = String(code[match])
        guard let colour = line.range(of: "Color(") else { return (0, 0, 0) }
        let nums = line[colour.upperBound...]
            .components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
            .compactMap(Double.init)
        guard nums.count == 3 else {
            XCTFail("ANCHOR MISSING: three components expected for `\(name)`, got \(nums.count)")
            return (0, 0, 0)
        }
        return (nums[0], nums[1], nums[2])
    }

    private func text(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
#endif
