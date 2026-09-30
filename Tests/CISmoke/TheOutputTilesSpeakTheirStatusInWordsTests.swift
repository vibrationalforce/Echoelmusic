// TheOutputTilesSpeakTheirStatusInWordsTests.swift
// Echoel — interface audit 2026-09-30, "Status-Leiter in Wörtern … an Puls und Ausgabe", the
// OUTPUT half (the pulse half is `ThePulseSpeaksItsStatusInWordsTests`). The two output tiles in
// the head — the visual monitor and the light monitor — showed a glyph, a colour or a TV glyph,
// and said "Live" / "Idle" / "On external screen" / "Sending to fixtures" / "No light route" to
// VoiceOver ONLY, as five inline strings in the view. A sighted player who does not know the glyph
// grammar saw a dim bulb and could not tell "light off" from "light idle"; a colour-blind one saw
// a tile. The rungs are now named once (`OutputStatusWord.swift`), the tile renders the rung's
// word beside its glyph, and VoiceOver reads the same rung's sentence.
//
// WHAT THIS GUARDS.
//   1. END-TO-END: the two truth tables — external wins over live; a route enabled is sending.
//   2. END-TO-END: the words fit the tiles (≤ `OutputStatusWord.maxLength`, the longest word sets
//      it), carry no digit, percent or space, and the two PICTURE rungs (live, sending) have NO
//      word — a word over a colour that changes every beat is the contrast defect the audit's
//      next line exists to catch. The spoken sentences are the five VoiceOver said before: moved,
//      not rewritten.
//   3. SOURCE: both tiles compute ONE rung, render `MonitorWordTile` with `rung.word` on their
//      resting faces, speak `rung.spoken`, and spell no `Text(` of their own; the shared tile
//      scales its word with `EchoelTheme.font` and shrinks before it clips. The five inline
//      strings are gone from the view (#416).
//   4. COUNTERWEIGHTS (#343): the founder-reference tile sizes (54 / 38 × controlHeight, pinned in
//      `OneChromeControlHeightTests`) and the two flash policies (20 Hz gradient clock,
//      `FlashGuard.maxPulseRateHz` light clock, `lightColor` in both Reduce-Motion arms) still hold.
//
// ⚠️ LIMIT. Claims 3–4 are source text: nothing here renders a tile or proves "Idle" is legible at
// 10 pt on a 54 pt tile in daylight — that is a NEEDS-FOUNDER-VERIFY at the tile.
//
// ⚠️ GRADING (§0, no toolchain in a web session): claims 1–2 transcribed into Python over the same
// tables; claims 3–4 driven against this tree and its parent 773a795c3. On the parent
// `OutputStatusWord.swift` does not exist — claims 1–2 cannot compile (ONE absence, #486), claim
// 3's needles are absent together, claim 4 is green on both.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheOutputTilesSpeakTheirStatusInWordsTests: XCTestCase {

    private static let monitors = "Sources/Echoelmusic/Studio/HeaderMonitors.swift"
    private static let words = "Sources/Echoelmusic/Studio/OutputStatusWord.swift"

    // MARK: 1 — the truth tables

    func testExternalWinsOverLiveAndARouteIsSending() {
        XCTAssertEqual(VisualMonitorRung.rung(onExternalScreen: true, active: true), .externalScreen,
                       "a projector that has the picture is the fact, whether or not a pulse runs")
        XCTAssertEqual(VisualMonitorRung.rung(onExternalScreen: true, active: false), .externalScreen)
        XCTAssertEqual(VisualMonitorRung.rung(onExternalScreen: false, active: true), .live)
        XCTAssertEqual(VisualMonitorRung.rung(onExternalScreen: false, active: false), .idle)
        XCTAssertEqual(VisualMonitorRung.allCases, [.externalScreen, .live, .idle])
        XCTAssertEqual(LightMonitorRung.rung(routeEnabled: true), .sending)
        XCTAssertEqual(LightMonitorRung.rung(routeEnabled: false), .noRoute)
        XCTAssertEqual(LightMonitorRung.allCases, [.sending, .noRoute])
    }

    // MARK: 2 — the words fit, the pictures keep none, the sentences are the old ones

    func testTheWordsFitTheTilesAndThePictureRungsHaveNone() {
        XCTAssertNil(VisualMonitorRung.live.word, "the live tile is the visual's own colour — no word over it")
        XCTAssertNil(LightMonitorRung.sending.word, "the sending tile is the colour the fixtures receive — no word over it")
        XCTAssertEqual(VisualMonitorRung.idle.word, "Idle")
        XCTAssertEqual(VisualMonitorRung.externalScreen.word, "Screen")
        XCTAssertEqual(LightMonitorRung.noRoute.word, "Off")
        let words = VisualMonitorRung.allCases.compactMap(\.word) + LightMonitorRung.allCases.compactMap(\.word)
        XCTAssertEqual(words.count, 3, "three resting faces, three words: \(words)")
        XCTAssertEqual(Set(words).count, words.count, "two rungs share a word: \(words)")
        for word in words {
            XCTAssertLessThanOrEqual(word.count, OutputStatusWord.maxLength,
                                     "\"\(word)\" does not fit a 38 pt tile beside its glyph")
            XCTAssertNil(word.rangeOfCharacter(from: .decimalDigits), "\"\(word)\" is a number, not a word")
            XCTAssertFalse(word.contains("%") || word.contains(" "), "\"\(word)\" is a reading or a sentence, not a word")
        }
        XCTAssertEqual(words.map(\.count).max(), OutputStatusWord.maxLength,
                       "the longest word in use sets `maxLength`; a looser number is a guess")
        // The sentences VoiceOver said before this slice — moved into the rung, not rewritten.
        XCTAssertEqual(VisualMonitorRung.externalScreen.spoken, "On external screen")
        XCTAssertEqual(VisualMonitorRung.live.spoken, "Live")
        XCTAssertEqual(VisualMonitorRung.idle.spoken, "Idle")
        XCTAssertEqual(LightMonitorRung.sending.spoken, "Sending to fixtures")
        XCTAssertEqual(LightMonitorRung.noRoute.spoken, "No light route")
        XCTAssertEqual(Set(VisualMonitorRung.allCases.map(\.spoken)).count, 3)
        XCTAssertEqual(Set(LightMonitorRung.allCases.map(\.spoken)).count, 2)
    }

    // MARK: 3 — the tiles render the word and speak the rung

    func testTheTilesRenderTheWordAndSpeakTheRung() throws {
        let monitors = try source(Self.monitors)
        XCTAssertEqual(occurrences(of: "accessibilityValue(rung.spoken)", in: monitors), 2,
                       "both tiles speak the rung they render — one definition per state (#416)")
        XCTAssertEqual(occurrences(of: "MonitorWordTile(", in: monitors), 3,
                       "three resting faces build the shared word tile: idle, external screen, no route")
        let visual = try body(from: "struct ImmersiveMonitorMini: View {",
                              to: "static func flashSafePulseRate", in: monitors)
        XCTAssertTrue(visual.contains("VisualMonitorRung.rung(onExternalScreen: onExternalScreen, active: active)"),
                      "the visual tile computes its rung from the two facts it already had")
        XCTAssertTrue(visual.contains("MonitorWordTile(glyph: \"tv\", word: rung.word, tint: EchoelTheme.text)"),
                      "external screen: the TV glyph and the rung's word, bright — an output that is on, elsewhere")
        XCTAssertTrue(visual.contains("MonitorWordTile(glyph: \"sparkles\", word: rung.word, tint: EchoelTheme.dim)"),
                      "idle: the sparkle glyph and the rung's word, dim")
        XCTAssertFalse(visual.contains("Text("), "the visual tile spells no word of its own — none over the live colour")
        let light = try body(from: "struct EchoelLuxMonitorMini: View {",
                             to: "static func lightColor", in: monitors)
        XCTAssertTrue(light.contains("LightMonitorRung.rung(routeEnabled: luxActive)"),
                      "the light tile computes its rung from the route fact it already had")
        XCTAssertTrue(light.contains("MonitorWordTile(glyph: \"lightbulb\", word: rung.word, tint: EchoelTheme.dim)"),
                      "no route: the bulb and the rung's word, dim")
        XCTAssertFalse(light.contains("Text("), "the light tile spells no word of its own — none over the sent colour")
        let tile = try body(from: "private struct MonitorWordTile: View {", to: "#endif", in: monitors)
        XCTAssertTrue(tile.contains("Text(word)"), "the shared tile renders the word it is handed")
        XCTAssertTrue(tile.contains(".font(EchoelTheme.font(10, .semibold))"),
                      "the word scales with Dynamic Type at the pill's \"Found\" size, never an absolute point size")
        XCTAssertTrue(tile.contains(".lineLimit(1)") && tile.contains(".minimumScaleFactor(0.6)"),
                      "the word shrinks before it clips — the tiles have founder-reference widths")
        for gone in ["\"On external screen\"", "\"Sending to fixtures\"", "\"No light route\"", "\"Idle\"", "\"Live\""] {
            XCTAssertFalse(monitors.contains(gone),
                           "\(gone) is spelled inline in the view again — the rung owns that sentence (#416)")
        }
        let words = try source(Self.words)
        XCTAssertFalse(words.contains("import SwiftUI") || words.contains("@Environment"),
                       "the rungs are pure Foundation types — testable without a view")
    }

    // MARK: 4 — counterweights: the tile sizes and the flash policies

    func testTheTileSizesAndTheFlashPoliciesStillHold() throws {
        let monitors = try source(Self.monitors)
        XCTAssertEqual(occurrences(of: ".frame(width: 54, height: EchoelTheme.controlHeight)", in: monitors), 1,
                       "the visual tile keeps its founder-reference width")
        XCTAssertEqual(occurrences(of: ".frame(width: 38, height: EchoelTheme.controlHeight)", in: monitors), 1,
                       "the light tile keeps its founder-reference width")
        XCTAssertEqual(occurrences(of: "TimelineView(.animation(minimumInterval: 1.0 / 20.0))", in: monitors), 1,
                       "the live visual tile keeps its 20 Hz gradient clock")
        XCTAssertEqual(occurrences(of: "TimelineView(.animation(minimumInterval: 1.0 / FlashGuard.maxPulseRateHz))",
                                   in: monitors), 1, "the sending light tile keeps the flash ceiling as its clock")
        XCTAssertEqual(occurrences(of: "Self.lightColor(mf: bus.freshMusical(maxAge: 1.5))", in: monitors), 2,
                       "both Reduce-Motion arms of the light tile still paint the sent colour")
    }

    // MARK: helpers

    private struct AnchorMissing: Error { let name: String }

    private func occurrences(of needle: String, in code: String) -> Int {
        code.components(separatedBy: needle).count - 1
    }

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing(name: relativePath)
        }
        return SourceText.codeOnly(text)
    }

    /// The text between two unique anchors.
    private func body(from start: String, to end: String, in code: String) throws -> String {
        guard let s = code.range(of: start), let e = code.range(of: end, range: s.upperBound..<code.endIndex) else {
            XCTFail("ANCHOR MISSING: `\(start)` → `\(end)` (#454)")
            throw AnchorMissing(name: start)
        }
        return String(code[s.lowerBound..<e.lowerBound])
    }
}
