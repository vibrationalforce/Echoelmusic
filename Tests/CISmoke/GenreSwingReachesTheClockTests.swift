// GenreSwingReachesTheClockTests.swift
// Echoel — #327. `MusicStyle.swing` was authored in GROOVE CYCLE 2 with per-genre values,
// and the ONE production caller of `PatternEngine.setSwing` passed a hardwired `0`. Every
// genre ran dead on the grid; the numbers existed, were tested, and reached nothing.
//
// ⭐ WHY A GUARD AND NOT JUST THE FIX. This defect is invisible from both ends. From the
// data side everything looks healthy — `MusicStyleSwingTests` asserts the values are sane
// and that jazz is the maximum, and it passes whether or not anyone reads them. From the
// call side the literal `0` carried a justification that sounded right ("no beat → nothing
// to swing"), so it read as a deliberate choice rather than a dropped wire. Nothing in
// between could fail. That gap is what this file closes.
//
// It fires on the two halves that must BOTH hold:
//   1. the generate path resolves swing from the style instead of a literal, and
//   2. the resolved value actually changes the clock — `swingGap` must not equal `base`
//      for a swung genre, and must equal it for a straight one.
//
// ⭐ #1363 ADDED A THIRD HALF, AND IT IS THE ONE THIS FILE WAS MISSING FOR TWO YEARS'
// WORTH OF GENRES: **the steps the swing DISPLACES must be the steps the composer puts
// CHORDS on.** Halves 1 and 2 were both green while `swingGap` swung the SIXTEENTH and
// every live chord grid sat on EVEN steps — so the value reached the clock, the clock bent,
// and not one note moved in 21 of the 22 swung genres. A guard can pin a law correctly and
// pin it onto nothing; „der Wert erreicht die Uhr" and „die Uhr bewegt die Musik" are two
// questions, and only the first was asked here.
//   ⚠️ Die Herleitung mit gedruckter Abdeckung steht EINMAL, im Doc von
//   `PatternEngine.swingGap` (#416) — nicht hier nachgesprochen.
//
// ⛔ HONEST LIMITS.
//   · Half 1 is a SOURCE SCAN. The call sits inside a SwiftUI view body, which no pure
//     assertion can reach and no simulator here can drive (house pattern —
//     `SoundPromptHasADoorTests`, `SoundPanelPresetBarTests`). It proves the argument is
//     written, not that the take audibly swings.
//   · It does NOT check the ordering of the genres' feel against each other, and it does
//     not know whether 0.16 is the right amount of shuffle for deep house. Whether the six
//     changed genres now sound better is the founder's ear (#254/#314), not a test's.
//   · Half 2 exercises `PatternEngine.swingGap`, the pure static both the per-tick re-arm
//     and the `setTempo` re-arm call. It is the real law, but it is not the audio.

import Foundation
import XCTest
@testable import Echoelmusic

final class GenreSwingReachesTheClockTests: XCTestCase {

    private static let generateSite = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    // MARK: - Half 1: the wire is connected

    /// Deliberately matches "not a literal" rather than one exact spelling, so a later
    /// refactor (a resolver function, a local `let`) stays green as long as the value still
    /// comes from the style — and a re-hardwired constant goes red however it is written.
    func testGenerateDoesNotHardwireTheSwingAmount() throws {
        let calls = try codeLines(Self.generateSite).filter { $0.contains("setSwing(") }

        XCTAssertFalse(calls.isEmpty, """
        no `setSwing(` call found in \(Self.generateSite). Either generate stopped setting \
        swing at all — in which case the engine keeps whatever the previous take left, which \
        is its own bug — or this scan's anchor rotted. Both need a human; a silent green here \
        would mean the guard scanned nothing.
        """)

        let hardwired = calls.filter { line in
            guard let open = line.range(of: "setSwing(") else { return false }
            let rest = line[open.upperBound...]
            guard let close = rest.firstIndex(of: ")") else { return false }
            let argument = rest[rest.startIndex..<close].trimmingCharacters(in: .whitespaces)
            // A numeric literal (0, 0.0, .25) is a hardwire. Anything naming something —
            // `style.swing`, a resolver call, a local — is not.
            return argument.allSatisfy { $0.isNumber || $0 == "." || $0 == "-" }
                && !argument.isEmpty
        }

        XCTAssertTrue(hardwired.isEmpty, """
        `setSwing` is called with a numeric literal in \(Self.generateSite):
        \(hardwired.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n"))

        That is exactly #327: `MusicStyle.swing` carries per-genre values, they are unit-tested, \
        and a hardwired argument means none of them ever reaches the clock. The melody rides \
        this tick — "there are no drums to swing" is not a reason, because a note's onset is \
        decided by when the tick fires, not by what else is playing. Pass the style's value; \
        the ten straight genres already return 0 on their own.
        """)
    }

    // MARK: - Half 2: the value actually bends the clock

    /// The pure law, at the exact call the engine makes. A swung genre must lengthen BOTH gaps
    /// inside an even EIGHTH and shorten both inside the odd one — and every QUARTER must still
    /// sum to `4 × base`, or swing would drift the tempo.
    ///
    /// ⛔ #1363 — DIESER ANSPRUCH PINNTE DEN SECHZEHNTEL-SWING (`afterStep: 0` lang,
    /// `afterStep: 1` kurz, Paarsumme `2 × base`) UND WAR DIE GANZE ZEIT GRÜN, während der
    /// Swing in 21 von 22 geschwungenen Genres keine einzige Akkord-Note verschob: jedes
    /// lebende Akkord-Raster des Komponisten sitzt auf GERADEN Schritten, und der 16tel-Swing
    /// verschiebt die UNGERADEN. **Ein Wächter kann ein Gesetz korrekt pinnen, das auf nichts
    /// trifft** — die Herleitung mit gedruckter Abdeckung steht im Doc von
    /// `PatternEngine.swingGap`, nicht hier (#416).
    func testASwungGenreBendsTheGridAndKeepsTheTempo() {
        let base = 0.125   // one 16th at 120 BPM
        let swung = MusicStyle.offered.filter { $0.swing > 0 }

        XCTAssertFalse(swung.isEmpty, """
        no offered genre has a non-zero swing. If the curation legitimately went all-straight, \
        delete this test with a note; until then this means the swing table lost its values, \
        and the fix in #327 protects nothing.
        """)

        for style in swung {
            for k in 0..<2 {
                XCTAssertGreaterThan(
                    PatternEngine.swingGap(afterStep: k, base: base, swing: style.swing), base,
                    "\(style): Schritt \(k) liegt in der geraden Achtel und muss den LANGEN Gap tragen")
            }
            for k in 2..<4 {
                XCTAssertLessThan(
                    PatternEngine.swingGap(afterStep: k, base: base, swing: style.swing), base,
                    "\(style): Schritt \(k) liegt in der ungeraden Achtel und muss den KURZEN Gap tragen")
            }
            let quarter = (0..<4).reduce(0.0) {
                $0 + PatternEngine.swingGap(afterStep: $1, base: base, swing: style.swing)
            }
            XCTAssertEqual(quarter, 4 * base, accuracy: 1e-12, """
            \(style)'s swung quarter does not sum to 4× base — swing would then change the TEMPO, \
            not the feel, and every bar would drift against a slaved clock.
            """)
        }
    }

    /// ⭐ DER ANSPRUCH, DER #1363 ÜBERHAUPT ERST ZU ETWAS MACHT, und der bis dahin nirgends
    /// stand: die verschobenen Schritte müssen die sein, auf denen der Komponist AKKORDE legt.
    /// `BioComposer.chordOnsets` trifft skank auf `phase % 4 == 2`, stab auf `phase % 4 == 0`
    /// und comp auf `phase % 8 == 4` — das Offbeat-Raster der Skank (2, 6, 10, 14) ist genau
    /// die Achtel, die swingen MUSS, und die Stab-/Comp-Raster liegen auf der Viertel, die
    /// gerade bleiben MUSS. Ein Swing, der beide gleich behandelt, ist kein Swing.
    func testTheDisplacedStepsAreTheOnesTheComposerPutsChordsOn() {
        let base = 0.125
        let swing = 0.3
        // Offbeat-Achtel: das skank-Raster. Muss SPÄT kommen.
        for step in [2, 6, 10, 14] {
            XCTAssertLessThan(PatternEngine.swingGap(afterStep: step, base: base, swing: swing), base, """
            Schritt \(step) ist ein skank-Akkord (`phase % 4 == 2`). Der Gap NACH ihm muss kurz \
            sein, weil er selbst schon verspätet ankam — sonst trägt das Offbeat-Raster keinen \
            Swing, und genau das war #1363.
            """)
        }
        // Die Viertel: das stab-/comp-Raster. Muss auf dem Raster bleiben, also ist die
        // kumulative Versetzung bei jedem Viertelanfang exakt null.
        for quarter in 0..<4 {
            let elapsed = (0..<(quarter * 4)).reduce(0.0) {
                $0 + PatternEngine.swingGap(afterStep: $1, base: base, swing: swing)
            }
            XCTAssertEqual(elapsed, Double(quarter * 4) * base, accuracy: 1e-12, """
            Viertel \(quarter) beginnt versetzt. Die stab- (`% 4 == 0`) und comp-Raster \
            (`% 8 == 4`) sitzen dort; ein Swing, der die Viertel verschiebt, verschiebt den \
            Downbeat und klingt wie ein Timing-Fehler, nicht wie ein Groove.
            """)
        }
        // Und die Offbeat-Achtel kommt um genau 2 · swing · base zu spät — die Größe, die im
        // `tickToTime`-Doc als verdoppelte Abweichung steht (#328).
        let atStepTwo = (0..<2).reduce(0.0) {
            $0 + PatternEngine.swingGap(afterStep: $1, base: base, swing: swing)
        }
        XCTAssertEqual(atStepTwo - 2 * base, 2 * swing * base, accuracy: 1e-12,
                       "die Offbeat-Achtel muss um 2 · swing · base verspätet sein")
    }

    /// The other half of the contract, and the one the old hardwire was pretending to protect:
    /// the meditative and ambient genres must stay dead straight on their own, without anyone
    /// forcing them to.
    func testTheContemplativeGenresStayStraightWithoutBeingForced() {
        let base = 0.125
        let straight = MusicStyle.offered.filter { $0.swing == 0 }

        XCTAssertGreaterThan(straight.count, 5, """
        only \(straight.count) offered genres are straight. The point of #327 is that the ten \
        calm genres never needed the hardwired 0 — if that majority disappears, the decision \
        to let the data speak deserves a fresh look.
        """)

        for style in straight {
            XCTAssertEqual(PatternEngine.swingGap(afterStep: 0, base: base, swing: style.swing),
                           base, accuracy: 1e-12,
                           "\(style) must run straight — a swung Fläche reads as a genre shuffle")
            XCTAssertEqual(PatternEngine.swingGap(afterStep: 1, base: base, swing: style.swing),
                           base, accuracy: 1e-12, "\(style) must run straight")
        }
    }

    // MARK: - Files

    private func codeLines(_ path: String) throws -> [String] {
        let url = try repoRoot().appendingPathComponent(path)
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { Self.stripComment(String($0)) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Comment stripping is load-bearing: the block above the call site now DISCUSSES
    /// `setSwing(0)` at length, and without stripping the tombstone explaining the fix would
    /// itself fail the test it documents.
    private static func stripComment(_ line: String) -> String {
        var quotes = 0
        var previous: Character?
        var index = line.startIndex
        while index < line.endIndex {
            let ch = line[index]
            if ch == "\"" { quotes += 1 }
            if ch == "/", previous == "/", quotes % 2 == 0 {
                return String(line[line.startIndex..<line.index(before: index)])
            }
            previous = ch
            index = line.index(after: index)
        }
        return line
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources/Echoelmusic")
        guard FileManager.default.fileExists(atPath: sources.path) else {
            throw XCTSkip("""
            source tree not present at \(sources.path) — the scanning half of this file reads \
            source text, so it SKIPS rather than reporting a green it did not earn
            """)
        }
        return root
    }
}
