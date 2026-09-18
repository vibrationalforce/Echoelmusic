// PatternEngineSwingGapTests.swift
// Pins PatternEngine.swingGap — the single source of truth for the swung step
// interval, shared by advance() and the setTempo re-arm. Regression for the
// setTempo swing-parity inversion: the re-arm must key off the JUST-PLAYED step
// (currentStep − 1), because between ticks currentStep already points at the NEXT
// step; keying off currentStep inverted the swing for the step right after a
// mid-play tempo change.
//
// ⛔ #1363 — DIESE DATEI PINNTE DEN SECHZEHNTEL-SWING, und der verschob in 21 von 22
// geschwungenen Genres keine einzige Akkord-Note (Herleitung im `swingGap`-Doc). Sie ist
// auf den ACHTEL-Swing nachgezogen: lang nach Schritt 0 UND 1, kurz nach 2 UND 3.
// ⭐ Und die Inversions-Regression unten musste dabei UMGEHÄNGT werden, nicht nur
// nachgerechnet: unter dem Achtel-Swing teilen sich Schritt 0 und Schritt 1 denselben Gap,
// also ist der `currentStep`-statt-`justPlayed`-Fehler an genau der Stelle UNSICHTBAR, an der
// diese Datei ihn seit jeher gemessen hat. Der Anker sitzt jetzt bei currentStep == 2
// (justPlayed 1 → lang, currentStep 2 → kurz), wo die zwei sich wieder unterscheiden.
// Das ist die eigentliche Lehre: eine Gesetzesänderung kann einen Wächter GRÜN lassen und
// ihm trotzdem den Gegenstand nehmen.

import XCTest
@testable import Echoelmusic

@MainActor
final class PatternEngineSwingGapTests: XCTestCase {

    func testGapInsideAnEvenEighthIsLengthened() {
        // Beide Schritte der geraden Achtel (0–1, 4–5, …) tragen den langen Gap → die
        // Offbeat-Achtel (Schritt 2, 6, 10, 14) kommt um 2 · swing · base zu spät.
        XCTAssertEqual(PatternEngine.swingGap(afterStep: 0, base: 1.0, swing: 0.5), 1.5, accuracy: 1e-12)
        XCTAssertEqual(PatternEngine.swingGap(afterStep: 1, base: 1.0, swing: 0.5), 1.5, accuracy: 1e-12)
        XCTAssertEqual(PatternEngine.swingGap(afterStep: 4, base: 1.0, swing: 0.5), 1.5, accuracy: 1e-12)
    }

    func testGapInsideAnOddEighthIsShortened() {
        XCTAssertEqual(PatternEngine.swingGap(afterStep: 2, base: 1.0, swing: 0.5), 0.5, accuracy: 1e-12)
        XCTAssertEqual(PatternEngine.swingGap(afterStep: 3, base: 1.0, swing: 0.5), 0.5, accuracy: 1e-12)
        XCTAssertEqual(PatternEngine.swingGap(afterStep: 15, base: 1.0, swing: 0.5), 0.5, accuracy: 1e-12)
    }

    /// Der Tempo-Erhalt liegt jetzt auf der VIERTEL, nicht mehr auf dem 16tel-Paar: vier
    /// aufeinanderfolgende Gaps müssen exakt 4 · base ergeben, sonst driftet Swing das Tempo
    /// gegen jede geslavte Uhr.
    func testEveryQuarterKeepsItsNominalLength() {
        for swing in [0.0, 0.04, 0.18, 0.3, 0.5] {
            for quarter in 0..<4 {
                let total = (0..<4).reduce(0.0) { acc, k in
                    acc + PatternEngine.swingGap(afterStep: quarter * 4 + k, base: 1.0, swing: swing)
                }
                XCTAssertEqual(total, 4.0, accuracy: 1e-12,
                               "swing \(swing), Viertel \(quarter) summiert auf \(total) statt 4 — Swing würde das TEMPO ziehen")
            }
        }
    }

    /// Bei swing 0.33 muss das Achtel-Verhältnis ~2:1 sein — genau das, was der Doc-Kommentar
    /// an `MusicStyle.swing` seit jeher behauptet und was der 16tel-Swing nie geliefert hat.
    func testAThirdOfSwingIsRoughlyATripletFeelOnTheEighth() {
        let first = (0..<2).reduce(0.0) { $0 + PatternEngine.swingGap(afterStep: $1, base: 1.0, swing: 0.33) }
        let second = (2..<4).reduce(0.0) { $0 + PatternEngine.swingGap(afterStep: $1, base: 1.0, swing: 0.33) }
        XCTAssertEqual(first / second, 2.0, accuracy: 0.02,
                       "0.33 soll ~2:1 auf der ACHTEL sein, ist aber \(first / second):1")
    }

    func testSwingClampedIntoWindow() {
        XCTAssertEqual(PatternEngine.swingGap(afterStep: 0, base: 1.0, swing: 0.9), 1.5, accuracy: 1e-12,
                       "swing clamps to 0.5")
        XCTAssertEqual(PatternEngine.swingGap(afterStep: 0, base: 1.0, swing: -0.3), 1.0, accuracy: 1e-12,
                       "negative swing clamps to 0 → straight")
    }

    func testZeroSwing_isStraight() {
        for step in 0..<16 {
            XCTAssertEqual(PatternEngine.swingGap(afterStep: step, base: 1.0, swing: 0), 1.0, accuracy: 1e-12)
        }
    }

    /// Ein negativer Schritt kann heute keine Aufrufstelle erreichen — die Faltung in
    /// `swingGap` schuldet ihre Existenz der Erreichbarkeit des `static`. Gepinnt wird sie
    /// trotzdem, weil `%` in Swift vorzeichenerhaltend ist und `-1 < 2` ohne Faltung einen
    /// LANGEN Gap ergäbe, wo ein kurzer gehört. Die alte `% 2 == 0`-Form war dagegen immun;
    /// dieses Prädikat ist es nicht.
    func testANegativeStepFoldsInsteadOfFlippingTheFeel() {
        XCTAssertEqual(PatternEngine.swingGap(afterStep: -1, base: 1.0, swing: 0.5), 0.5, accuracy: 1e-12,
                       "Schritt −1 liegt auf Phase 3 (kurz), nicht auf einem langen Gap")
        XCTAssertEqual(PatternEngine.swingGap(afterStep: -2, base: 1.0, swing: 0.5), 0.5, accuracy: 1e-12)
        XCTAssertEqual(PatternEngine.swingGap(afterStep: -4, base: 1.0, swing: 0.5), 1.5, accuracy: 1e-12,
                       "Schritt −4 liegt auf Phase 0 (lang)")
    }

    /// Regression: der Re-arm muss den JUST-PLAYED-Schritt nehmen, nicht `currentStep`.
    /// ⚠️ ANKER UMGEHÄNGT (#1363): unter dem Achtel-Swing tragen Schritt 0 und 1 denselben
    /// Gap, der Fehler wäre dort also unsichtbar. Bei currentStep == 2 (Schritt 1 gerade
    /// gespielt) unterscheiden sie sich wieder — justPlayed 1 → lang, currentStep 2 → kurz.
    func testSetTempoReArm_usesJustPlayedStep_notCurrentStep() {
        let base = 60.0 / 140.0 / 4.0
        let currentStep = 2                       // Schritt 1 wurde gerade gespielt
        let justPlayed = (currentStep + PatternEngine.stepCount - 1) % PatternEngine.stepCount
        XCTAssertEqual(justPlayed, 1)
        let correct = PatternEngine.swingGap(afterStep: justPlayed, base: base, swing: 0.5)
        XCTAssertEqual(correct, base * 1.5, accuracy: 1e-12,
                       "der Gap vor der Offbeat-Achtel (Schritt 2) ist der lange")
        let buggy = PatternEngine.swingGap(afterStep: currentStep, base: base, swing: 0.5)
        XCTAssertEqual(buggy, base * 0.5, accuracy: 1e-12)
        XCTAssertNotEqual(correct, buggy, "der Unterschied IST die Inversion, die der Fix entfernt")
    }

    /// Wrap: nach dem letzten Schritt (15, Phase 3) ist currentStep == 0, justPlayed == 15,
    /// der Gap vor Schritt 0 ist also der kurze.
    func testSetTempoReArm_wrapAtStepZero_usesStep15Parity() {
        let currentStep = 0
        let justPlayed = (currentStep + PatternEngine.stepCount - 1) % PatternEngine.stepCount
        XCTAssertEqual(justPlayed, 15)
        XCTAssertEqual(PatternEngine.swingGap(afterStep: justPlayed, base: 1.0, swing: 0.5), 0.5, accuracy: 1e-12,
                       "nach Schritt 15 (Phase 3) ist der Gap vor Schritt 0 kurz")
    }
}
