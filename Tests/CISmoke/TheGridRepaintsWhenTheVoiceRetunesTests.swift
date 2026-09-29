// TheGridRepaintsWhenTheVoiceRetunesTests.swift
// Echoel — DMMW Phase 6 · slice 2 (founder 2026-09-29, "Klang-zu-Licht und Grit": key and A4
// changes must change colour and position CONSISTENTLY).
//
// THE DEFECT. The note grid on the play surface tints each cell with its note's sounding colour,
// computed from the touch voice's concert pitch and tone-system table. It rebuilt when the synth
// INSTANCE changed (`synth !== oldValue`), when the key, the grid toggle or the size changed —
// and an A4 or tone-system change retunes the SAME instance. So after "A4 = 432" or a maqām
// table the voice sounded the new tuning while every cell kept the old colour, until something
// unrelated happened to trigger a rebuild. Both inputs were also invisible to SwiftUI:
// `uiTuningCents` was `@ObservationIgnored` and the A4 lived only in the engine (`poly.a4Hz`).
//
// THE REPAIR, on the existing owners (no new store, no new clock, no modal):
//   · `PolySynthVoice` keeps two OBSERVED mirrors of what the engine TOOK — `uiA4Hz` (the
//     clamped value, written by `setTuning(a4Hz:)`) and `uiTuningCents` (no longer ignored).
//   · `TouchGridTuning(of:)` reads the pair; the window passes it for the SAME voice it hands the
//     surface; the UIKit view rebuilds the grid when it changes.
//   · `frequency(of:)` colours from the same two mirrors, so the trigger and the colour read one
//     input — the stamp cannot move without the colour following, nor the colour without the stamp.
//
// Claims, labelled per `Tests/CISmoke/CLAUDE.md` §1:
//   1. END-TO-END — the mirrors hold what the ENGINE took: the default, a clamp, a refused NaN,
//      a refused non-finite table.
//   2. END-TO-END — both writes are VISIBLE to observation (`withObservationTracking` fires), which
//      is what makes SwiftUI re-run the window's body and call `updateUIView`.
//   3. END-TO-END (UIKit only) — the stamp changes on a retune and stays equal on a refused one,
//      so a refused edit cannot cost a rebuild.
//   4. SOURCE-TEXT SCAN — the view rebuilds on the stamp; make/update both hand it over; the
//      window builds it from the voice it plays; the colour reads the two mirrors.
//   5. COUNTERWEIGHT — the instance-change rebuild is still there.
// GRADING against the parent: `uiA4Hz` and `TouchGridTuning` do not exist there, so this file does
// NOT compile against it — no assertion has a verdict on the parent; hand-transcribed instead.
// Claims 1–3 are FORWARD guards over symbols this commit creates (claim 2's `uiTuningCents` half
// would have been a real regression: the parent's `@ObservationIgnored` never fires). Claim 4 is
// red on the parent by ANCHOR ABSENCE (one absence). Claim 5 is a COUNTERWEIGHT, green on both.
// ⛔ HONEST LIMITS. That the grid visibly repaints is a DEVICE PROBE: SwiftUI's update, the
// representable's `updateUIView` and UIKit's layout pass are not driven here. The ORDER argument —
// the edit handler retunes the voice synchronously inside the header's binding `set` (the
// notification is delivered synchronously), and the layout pass that rebuilds the grid runs at
// the end of that run-loop turn — is read from source, not measured. (Generated notes' cents:
// slice 3, `AGeneratedNoteIsLitByItsTunedPitchTests`.) NEEDS-FOUNDER-VERIFY: open the Visual window, switch the note
// grid on, change A4 and the tone system — the cells change colour at once.

import Foundation
import Observation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheGridRepaintsWhenTheVoiceRetunesTests: XCTestCase {

    private static let touch = "Sources/Echoelmusic/Studio/TouchInstrumentView.swift"
    private static let window = "Sources/Echoelmusic/Studio/FloatingVisualWindow.swift"

    private static func table(_ c4: Float) -> [Float] {
        var t = Array(repeating: Float(0), count: 12)
        t[4] = c4
        return t
    }

    // MARK: 1 — the mirrors hold what the engine took

    func testTheMirrorsHoldWhatTheEngineTook() {
        let voice = PolySynthVoice(maxVoices: 1)
        XCTAssertEqual(voice.uiA4Hz, Double(voice.poly.a4Hz), "the two agree before any call")

        voice.setTuning(a4Hz: 432)
        XCTAssertEqual(voice.uiA4Hz, 432, accuracy: 1e-9)
        XCTAssertEqual(voice.uiA4Hz, Double(voice.poly.a4Hz))

        voice.setTuning(a4Hz: 900)   // outside the musical range: the engine clamps
        XCTAssertEqual(voice.uiA4Hz, Double(voice.poly.a4Hz), "the mirror is the CLAMPED value, not the request")
        XCTAssertLessThan(voice.uiA4Hz, 900)

        let before = voice.uiA4Hz
        voice.setTuning(a4Hz: .nan)  // refused: the engine keeps its last good pitch
        XCTAssertEqual(voice.uiA4Hz, before)
        XCTAssertEqual(voice.uiA4Hz, Double(voice.poly.a4Hz))

        let maqam = Self.table(-13.7)
        voice.setTuningCents(maqam)
        XCTAssertEqual(voice.uiTuningCents, maqam)
        voice.setTuningCents(Self.table(.nan))
        XCTAssertEqual(voice.uiTuningCents, maqam, "a table the engine refused never reaches the mirror")
    }

    // MARK: 2 — both writes are visible to observation

    /// The observation callback is `@Sendable`; a reference box is what it may capture (Swift 6).
    private final class Seen: @unchecked Sendable { var fired = false }

    func testARetuneIsVisibleToObservation() {
        let voice = PolySynthVoice(maxVoices: 1)

        let a4Seen = Seen()
        withObservationTracking({ _ = voice.uiA4Hz }, onChange: { a4Seen.fired = true })
        voice.setTuning(a4Hz: 444)
        XCTAssertTrue(a4Seen.fired, "a concert-pitch change must re-run a body that reads it")

        let centsSeen = Seen()
        withObservationTracking({ _ = voice.uiTuningCents }, onChange: { centsSeen.fired = true })
        voice.setTuningCents(Self.table(-13.7))
        XCTAssertTrue(centsSeen.fired, """
            a tone-system change must re-run a body that reads it — `@ObservationIgnored` here \
            is exactly the defect: the grid kept the old colours
            """)
    }

    // MARK: 3 — the stamp moves on a retune, not on a refusal

    #if canImport(UIKit)
    func testTheStampMovesOnARetuneAndNotOnARefusal() {
        let voice = PolySynthVoice(maxVoices: 1)
        let start = TouchGridTuning(of: voice)
        XCTAssertEqual(TouchGridTuning(of: voice), start, "nothing changed, no rebuild")

        voice.setTuning(a4Hz: 432)
        let at432 = TouchGridTuning(of: voice)
        XCTAssertNotEqual(at432, start, "A4 moved: the grid must repaint")
        XCTAssertEqual(at432.a4Hz, 432, accuracy: 1e-9)

        voice.setTuningCents(Self.table(-13.7))
        let retuned = TouchGridTuning(of: voice)
        XCTAssertNotEqual(retuned, at432, "the tone system moved: the grid must repaint")

        voice.setTuning(a4Hz: .nan)
        voice.setTuningCents(Self.table(.infinity))
        XCTAssertEqual(TouchGridTuning(of: voice), retuned, "a refused edit changes nothing the grid reads")
    }
    #endif

    // MARK: 4 — SOURCE: the wiring

    func testTheSurfaceRebuildsOnTheStampItsWindowBuildsFromThePlayingVoice() throws {
        let touch = try source(Self.touch)
        let property = try member("var tuning: TouchGridTuning? {", in: touch)
        XCTAssertTrue(property.contains("if tuning != oldValue { setNeedsGridRebuild() }"),
                      "the view repaints when the stamp changes — and only then")

        let make = try member("func makeUIView(context: Context) -> TouchInstrumentUIView {", in: touch)
        XCTAssertTrue(make.contains("v.tuning = tuning"), "the first build already knows the tuning")
        let update = try member("func updateUIView(_ uiView: TouchInstrumentUIView, context: Context) {", in: touch)
        XCTAssertTrue(update.contains("uiView.tuning = tuning"), "every SwiftUI update hands the stamp over")

        let colour = try member("private func frequency(of pitch: Int) -> Double {", in: touch)
        XCTAssertTrue(colour.contains("synth?.uiA4Hz"), "the colour reads the same A4 the stamp carries")
        XCTAssertTrue(colour.contains("synth?.uiTuningCents["), "and the same table")
        XCTAssertFalse(colour.contains("poly.a4Hz"), "not a second, unobserved A4")

        let window = try source(Self.window)
        XCTAssertTrue(window.contains("synth: touchSynth ?? synth,"), "ANCHOR: the voice the surface plays")
        XCTAssertTrue(window.contains("tuning: TouchGridTuning(of: touchSynth ?? synth)"),
                      "the stamp is built from the SAME voice the surface plays — not the take voice beside it")
    }

    // MARK: 5 — COUNTERWEIGHT

    func testSwappingTheVoiceStillRepaints() throws {
        let touch = try source(Self.touch)
        let property = try member("weak var synth: PolySynthVoice? {", in: touch)
        XCTAssertTrue(property.contains("if synth !== oldValue {"))
        XCTAssertTrue(property.contains("setNeedsGridRebuild()"))
    }

    // MARK: - Helpers

    private struct AnchorMissing: Error {}

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }

    /// The brace-matched body that starts at `anchor`, searched from the anchor's FIRST character (#408).
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing()
        }
        var depth = 0
        var cursor = open
        while cursor < code.endIndex {
            if code[cursor] == "{" { depth += 1 }
            if code[cursor] == "}" {
                depth -= 1
                if depth == 0 { return String(code[open...cursor]) }
            }
            cursor = code.index(after: cursor)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing()
    }
}
