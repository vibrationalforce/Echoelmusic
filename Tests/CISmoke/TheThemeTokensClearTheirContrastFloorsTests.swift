// TheThemeTokensClearTheirContrastFloorsTests.swift
// Echoel — WCAG contrast floors for the design tokens, in the BLOCKING bundle.
//
// MOVED HERE from `Tests/EchoelmusicTests/ThemeContrastTests.swift` (interface audit
// 2026-09-30, "Kontrast-Wächter mit Zähnen ins blockierende Bündel"). The maths and the
// five floors are the ones that file carried since the 1.16:1 outline was found; nothing
// is weakened. What changed is WHO RUNS IT: `Tests/EchoelmusicTests` is compiled by NO gate
// (#208), so a token that slid under its floor went green through CI — the doc's finding
// "ein Token-Fehler geht grün durch CI". Here `Build for Testing` compiles it and
// `Run Tests` runs it on every push. Renamed to the bundle's sentence form (§2, #374);
// the method names say the claim, not the procedure.
//
// The repo had 296 test files and NOT ONE contrast test, which is how the interactive
// outline sat at 1.16:1 (needs 3:1) through several accessibility passes that each fixed
// something real: labels are 15.9:1, so a reviewer checking text contrast sees a clean
// bill of health while the BOUNDARIES of every control are invisible. Numbers, not
// eyeballs, are what keeps that fixed.
//
// These tests compute WCAG 2.x relative luminance from THE SAME constants the colours are
// built from (`EchoelTheme.textComponent` / `*Opacity`) instead of re-typing the values.
// That is load-bearing: `FlashGuardTests` validates the 2.5 Hz flash ceiling against a
// hand-copied literal, so raising the ceiling in the renderer leaves the suite green —
// exactly the trap this file must not repeat.
//
// THE TOOTH ADDED WITH THE MOVE (claim 6). The named constants were a PARALLEL copy: `text`
// is spelled `Color(red: 0.878, …)` and `textComponent` is `0.878`, two literals that agree
// today. A designer lifting the grey in the colour line alone would leave every floor here
// green while the rendered contrast moved — the same hole the header condemns, one level
// down. Claim 6 reads `EchoelTheme.swift` and requires each neutral token to be built from
// the constant it is named after (`.opacity(dimOpacity)` …) and the five grey lines to spell
// the same component `textComponent` holds. Change the grey in both places and it stays
// green; change it in one and it says which.
//
// ⚠️ LIMIT. The semantic colours (`accent`, `warning`, `danger`, `recording`) are RGB
// literals with no named components, so their ratios (11.6:1, 9.3:1, 5.5:1 on black by the
// same maths) are NOT asserted here — asserting them would mean re-typing the literals,
// the trap above. Naming their components is a separate slice.
//
// ⚠️ GRADING (§3): claims 1–5 are the moved assertions — green on both trees, they are
// COUNTERWEIGHTS to the move itself (the move changes the runner, not the numbers).
// Claim 6 is a SOURCE claim; transcribed in Python against this tree and its parent, it
// is green on both (the constants and the colour lines agree today) — its value is the
// drift it forbids, not a red it shows. Transcription: WORK 6/6, parent 6/6; the WCAG
// figures re-derived in Python match the Swift to two decimals (3.70 · 3.67 · 3.67 · 3.50
// outline-vs-fill; 3.59 / 3.31 pessimistic; 1.16 border; 14.61 / 6.56 text).

import XCTest
#if canImport(SwiftUI)
@testable import Echoelmusic

final class TheThemeTokensClearTheirContrastFloorsTests: XCTestCase {

    // MARK: - WCAG maths (sRGB; neutral greys composited over an opaque ground)

    /// sRGB channel → linear light (WCAG 2.x / IEC 61966-2-1).
    private func linearise(_ channel: Double) -> Double {
        channel <= 0.03928 ? channel / 12.92
                           : pow((channel + 0.055) / 1.055, 2.4)
    }

    /// Relative luminance of a NEUTRAL grey — R=G=B, so the 0.2126/0.7152/0.0722 weights
    /// sum to 1 and collapse to the single linearised channel.
    private func luminance(grey channel: Double) -> Double { linearise(channel) }

    /// Composite a grey at `opacity` over an opaque grey ground (Core Animation blends
    /// these layers in sRGB space), then return the result's relative luminance.
    private func luminance(grey channel: Double, opacity: Double, over ground: Double) -> Double {
        linearise(channel * opacity + ground * (1 - opacity))
    }

    private func contrast(_ a: Double, _ b: Double) -> Double {
        let (hi, lo) = a > b ? (a, b) : (b, a)
        return (hi + 0.05) / (lo + 0.05)
    }

    private func ratio(_ value: Double) -> String { String(format: "%.2f:1", value) }

    /// The page ground: `EchoelTheme.bg` is `Color.black`.
    private var pageLuminance: Double { luminance(grey: 0) }

    /// A control's OWN fill — itself a translucent grey over black. An outline has to be
    /// judged against this, not just against the page.
    private var fillLuminance: Double {
        luminance(grey: EchoelTheme.textComponent, opacity: EchoelTheme.fillOpacity, over: 0)
    }

    // MARK: - The floor that was missing

    func testTheInteractiveOutlineClearsThreeToOneAsRenderedThroughEveryRealNesting() {
        // WCAG 2.1 SC 1.4.11 Non-text Contrast: 3:1 for the visual boundary of a control.
        //
        // AS RENDERED: `.background(fill)` then `.overlay(strokeBorder)`, so the stroke lies
        // OVER the control's own fill — that composite is the pixel a colour-picker reads,
        // and the fill is what it must be distinguishable FROM. Checked on every ground a
        // control actually sits on, because each nesting lifts the ground and shrinks the
        // ratio: the page, one `EchoelPanel` fill, and `surface`.
        for (name, ground) in [("page", 0.0),
                               ("panel fill", EchoelTheme.textComponent * EchoelTheme.fillOpacity),
                               ("surface", EchoelTheme.surfaceComponent),
                               ("fill on surface",
                                EchoelTheme.textComponent * EchoelTheme.fillOpacity
                                + EchoelTheme.surfaceComponent * (1 - EchoelTheme.fillOpacity))] {
            let fill = EchoelTheme.textComponent * EchoelTheme.fillOpacity
                     + ground * (1 - EchoelTheme.fillOpacity)
            let outline = EchoelTheme.textComponent * EchoelTheme.borderStrongOpacity
                        + fill * (1 - EchoelTheme.borderStrongOpacity)
            let vsFill = contrast(luminance(grey: outline), luminance(grey: fill))
            XCTAssertGreaterThanOrEqual(vsFill, 3.0,
                "on \(name): outline vs the fill it lies on is \(ratio(vsFill)) — needs 3:1")
        }
    }

    func testTheInteractiveOutlineClearsTheFloorEvenOnTheMostPessimisticModel() {
        // A deliberately WORSE model than the one above: the stroke composited over black
        // while the fill is judged separately, i.e. as if the outline got no help from the
        // fill beneath it. Kept as a lower bound so the token has margin under whichever
        // way the compositor actually blends — linear blending would give 7.70:1, so sRGB
        // is already the conservative choice and this is more conservative still.
        let outline = luminance(grey: EchoelTheme.textComponent,
                                opacity: EchoelTheme.borderStrongOpacity, over: 0)
        let vsPage = contrast(outline, pageLuminance)
        let vsFill = contrast(outline, fillLuminance)
        XCTAssertGreaterThanOrEqual(vsPage, 3.0,
                                    "pessimistic outline vs page is \(ratio(vsPage))")
        XCTAssertGreaterThanOrEqual(vsFill, 3.0,
                                    "pessimistic outline vs fill is \(ratio(vsFill))")
    }

    func testTheDecorativeBorderIsDeliberatelyBelowTheFloorNotAnOversight() {
        // `border` (0.10) stays for hairlines and dividers, which SC 1.4.11 does not cover.
        // This asserts the SPLIT is real in both directions: point a control back at
        // `border` and it regresses; raise `border` itself to clear 3:1 and the two tokens
        // are redundant — either way this test is the one that says so.
        let decorative = luminance(grey: EchoelTheme.textComponent,
                                   opacity: EchoelTheme.borderOpacity, over: 0)
        let vsPage = contrast(decorative, pageLuminance)
        XCTAssertLessThan(vsPage, 3.0,
                          "`border` now measures \(ratio(vsPage)); if that is intended, "
                          + "collapse it and `borderStrong` into one token")
        XCTAssertGreaterThan(EchoelTheme.borderStrongOpacity, EchoelTheme.borderOpacity,
                             "the interactive token must be the more visible of the two")
    }

    func testBodyAndSecondaryTextStayAboveAA() {
        // Regression guard on the two text tokens: `dim` was lifted 0.55 → 0.65 for AA and
        // nothing has stopped it drifting back. Judged over `surface` (the panel fill it
        // actually sits on), the stricter ground for light-on-dark text.
        // Read from the tokens, NOT re-typed: the first version of this test hardcoded 0.65
        // and 0.055, so it could not detect the very drift its own comment claimed to guard
        // — the hand-copied-literal hole this file's header condemns, reintroduced inside
        // the file condemning it. (Even now the guard is coarse: 0.65 → 0.55 still measures
        // 4.99:1 and passes. It catches a slide to 0.50 or below.)
        let surface = EchoelTheme.surfaceComponent
        let body = luminance(grey: EchoelTheme.textComponent)
        let secondary = luminance(grey: EchoelTheme.textComponent,
                                  opacity: EchoelTheme.dimOpacity, over: surface)
        let bodyRatio = contrast(body, luminance(grey: surface))
        let secondaryRatio = contrast(secondary, luminance(grey: surface))
        XCTAssertGreaterThanOrEqual(bodyRatio, 4.5, "body text on a panel: \(ratio(bodyRatio))")
        XCTAssertGreaterThanOrEqual(secondaryRatio, 4.5,
                                    "secondary text on a panel: \(ratio(secondaryRatio))")
    }

    func testTheWCAGMathsMatchesKnownReferenceValues() {
        // Anchor the formula itself, so a wrong transfer function cannot make the floors
        // above pass vacuously. White-on-black is exactly 21:1 by definition.
        // NOTE: these first two are weak on their own — 21:1 holds for ANY monotonic f with
        // f(0)=0, f(1)=1 (the identity included), and black-vs-black is a tautology of
        // (x+0.05)/(x+0.05). The third assertion is the one that actually pins the transfer
        // function: the identity would yield 2.76 and a naive gamma-2.2 would yield 1.10,
        // both far outside the window. Do not delete it as "redundant".
        XCTAssertEqual(contrast(luminance(grey: 1.0), luminance(grey: 0.0)), 21.0, accuracy: 0.001)
        XCTAssertEqual(contrast(luminance(grey: 0.0), luminance(grey: 0.0)), 1.0, accuracy: 0.001)
        // The documented starting point of this fix: 0.878 grey at 10 % over black.
        let known = luminance(grey: 0.878, opacity: 0.10, over: 0)
        XCTAssertEqual(contrast(known, luminance(grey: 0)), 1.16, accuracy: 0.02,
                       "the 1.16:1 figure the audit reported — if this moves, the maths changed")
    }

    // MARK: - The tooth: the constants above ARE the colours' components

    func testTheColoursAreBuiltFromTheConstantsTheFloorsAreComputedFrom() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let path = root.appendingPathComponent("Sources/Echoelmusic/Studio/EchoelTheme.swift")
        guard let raw = try? String(contentsOf: path, encoding: .utf8) else {
            return XCTFail("ANCHOR MISSING: cannot read EchoelTheme.swift (#454)")
        }
        let code = SourceText.codeOnly(raw)
        // Each translucent neutral token takes its opacity from the constant it is named after.
        for (token, constant) in [("dim", "dimOpacity"), ("border", "borderOpacity"),
                                  ("fill", "fillOpacity")] {
            XCTAssertTrue(code.contains("static let \(token)") && code.contains(".opacity(\(constant))"),
                          "`\(token)` no longer takes `.opacity(\(constant))` — the floors above then measure a number the renderer does not use")
        }
        XCTAssertTrue(code.contains(".opacity(borderStrongOpacity)"),
                      "`borderStrong` no longer takes `.opacity(borderStrongOpacity)`")
        XCTAssertTrue(code.contains("Color(red: surfaceComponent, green: surfaceComponent, blue: 0.070)"),
                      "`surface` no longer spells its R/G channels as `surfaceComponent` — the panel ground the text floors are judged over")
        // The grey itself: every neutral token line spells the SAME component the constant
        // holds. Formatting the Double gives the literal the source must carry ("0.878").
        let grey = "\(EchoelTheme.textComponent)"
        let spelled = "Color(red: \(grey), green: \(grey), blue: \(grey))"
        let lines = code.components(separatedBy: spelled).count - 1
        XCTAssertGreaterThanOrEqual(lines, 5, """
            Only \(lines) neutral token line(s) spell `\(spelled)`; text · dim · border · \
            borderStrong · fill make five. Either a token's grey drifted away from \
            `textComponent` (then every floor above measures a colour that is not rendered — \
            move the constant WITH the colour), or a token was rewritten without this file.
            """)
    }
}
#endif
