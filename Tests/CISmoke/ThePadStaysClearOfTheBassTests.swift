// ThePadStaysClearOfTheBassTests.swift
// Echoel — #1362. Die unterste Pad-Stimme darf nicht auf der Bassnote landen. BLOCKIERENDES Bündel.
//
// KIND: PURE VALUE-TYPE BEHAVIOUR (`BioComposer.padRegisterFloor`, `BioComposer.padBassClearance`,
// `MusicStyle.harmonicProfile`) plus EIN Quelltext-Scan auf die Aufrufstelle. Keine Engine, keine
// Ansicht, kein RNG, kein Gerät.
//
// ⭐ WARUM DIESER WÄCHTER ÜBERHAUPT ETWAS BEWEIST. Der Defekt war strukturell, nicht statistisch:
// das Voice-Leading-Fenster des Pads reichte exakt bis zur Bassnote HERUNTER, in jedem Genre und
// jedem Abschnitt. Der Beweis hat drei Prämissen, und ALLE DREI sind hier als Anspruch gepinnt,
// nicht als Prosa behauptet —
//   (1) jedes authored `chordTones` beginnt mit 0 (Anspruch 3),
//   (2) jedes `padOctave` ist ≥ 2, so dass `max(0, padOctave - 1 + octShift)` in `composeHarmonic`
//       nie greift und der Bass genau eine Oktave unter der Grundstellung liegt (Anspruch 3),
//   (3) `MusicalKey.degree` rechnet `base = (octave + 1) * 12 + root`, zwei Oktaven liegen also
//       exakt 12 Halbtöne auseinander (Anspruch 4).
// Wer eine davon bricht — ein Genre mit `chordTones: [2, 4, 6]`, ein `padOctave: 1`, eine
// Tonsystem-Änderung — macht diesen Wächter rot und NENNT die Prämisse, statt den Defekt still
// zurückzubringen. Das ist der Unterschied zu einem Wächter, der nur die neue Formel abschreibt.
//
// ⛔ WAS HIER BEWUSST NICHT STEHT (#364/#818): die Zahl 3. Sie wird aus
// `BioComposer.padBassClearance` GELESEN, nie wiederholt — eine zweite Fassung derselben
// Entscheidung in `Tests/` ist genau die #416-Doppelung, die dieses Repo teuer gelernt hat. Der
// Founder darf den Abstand morgen auf 4 oder 2 stellen; dieser Wächter zieht mit, ohne dass
// jemand eine Zeile hier ändert. Verboten wird nur, dass er auf 0 fällt — und DAS ist der
// gemessene Defekt, nicht eine Geschmacksfrage.
//
// ⛔ UND WAS DIESER WÄCHTER NICHT KANN, gesagt statt verschwiegen: er hört nichts. Ob die um eine
// kleine Terz angehobene unterste Pad-Stimme BESSER klingt als das Unisono, ist eine Ohrfrage und
// gehört dem Founder (NEEDS-FOUNDER-VERIFY steht am Code, nicht hier). Er kann auch nicht zählen,
// wie oft `VoiceLeader` den Boden tatsächlich WÄHLTE — dafür müsste er den ganzen Komponisten
// fahren und seine Ausgabe gegen einen früheren Baum halten, und beides hat diese Sitzung nicht.
// Er beweist, dass der Leader es nicht mehr DARF. Das ist die Hälfte, die ein Test halten kann.
//
// ⚠️ HONEST GRADING (§3): dieses Repo hat in der Web-Sitzung keine Swift-Toolchain. Jeder
// Anspruch unten ist in Python gegen BEIDE Bäume nachgefahren (Eltern-Stand `37fefd8` und
// Arbeitsbaum), mit gedruckter COVERAGE: 57 von 57 `HarmonicProfile(`-Stellen und 57 von 57
// deklarierten `Scale`-Fällen erreicht.
//   · Am ELTERNBAUM rot: Ansprüche 1, 2 und 5 (`padBassClearance` und `padRegisterFloor`
//     existieren dort nicht, und die alte Fensterformel steht dort im Code).
//   · In BEIDEN grün: 3, 4 und 6. Das ist kein Mangel und wird deshalb hier genannt statt
//     verschwiegen — 3 und 4 pinnen die PRÄMISSEN des Beweises (die der Defekt nicht verletzte),
//     6 ist das #343-Gegengewicht, das eine ÜBER-Reparatur fängt und nicht die Reparatur selbst.
//     Ein Wächter, dessen Ansprüche ALLE am Elternbaum rot sind, hätte gar keine Gegengewichte.
//   · MUTANTEN, alle vier gefangen: `padBassClearance = 0` → Anspruch 2 · der Boden mit
//     `profile.padOctave` statt `bassOct` gefüttert → Anspruch 5 · ein Genre auf `padOctave: 1`
//     → Anspruch 3 · `padRegisterFloor` auf `max(0, padBottom - 12)` zurückgedreht → 1 und 2.
// ⛔ Und die Transkription selbst musste zweimal repariert werden, beide Male in der
// BERUHIGENDEN Richtung: sie modellierte den Boden erst in Python nach, statt ihn aus dem
// Quelltext zu LESEN — und war damit gegen genau den Mutanten blind, der die Formel ändert; und
// ihr Skalen-Zähler verschluckte die im `Scale`-Rumpf geschachtelte Regal-Enum und meldete
// 57 von 65 statt 57 von 57. Eine Messung, die ihre eigene Abdeckung nicht nennt, ist keine
// Messung (#1350); eine Transkription, die die Formel NACHBAUT statt sie zu lesen, auch nicht.

import Foundation
import XCTest
@testable import Echoelmusic

final class ThePadStaysClearOfTheBassTests: XCTestCase {

    // MARK: - claim 1 — der Boden hebt die Kollision, und zwar um genau den benannten Abstand

    /// DER FALL, DER DEN DEFEKT WAR. `padBottom - 12` IST die Bassnote (Prämissen 1–3 oben), also
    /// genau die Lage, in der das alte Fenster dem Leader erlaubte, die unterste Pad-Stimme auf
    /// den Bass zu legen. Der Boden muss sie anheben — und zwar auf `bassRoot + padBassClearance`,
    /// nicht irgendwohin darüber: ein Boden, der HÖHER liegt als nötig, kostet Bewegung, und
    /// Bewegungsarmut ist der ganze Zweck des Voice-Leadings.
    func testTheCollisionCaseIsLiftedByExactlyTheClearance() {
        for padBottom in [48, 55, 60, 67, 72] {
            let bassRoot = padBottom - 12
            let floor = BioComposer.padRegisterFloor(padBottom: padBottom, bassRoot: bassRoot)
            XCTAssertEqual(floor, bassRoot + BioComposer.padBassClearance, """
                Bei padBottom \(padBottom) (Bass \(bassRoot), also GENAU die Lage jedes \
                gespielten Abschnitts) liefert der Boden \(floor) statt \
                \(bassRoot + BioComposer.padBassClearance).

                Liegt er auf \(bassRoot), ist #1362 zurück: `VoiceLeader` darf die unterste \
                Pad-Stimme auf die Bassnote legen und Bewegungsminimierung zieht sie dahin — \
                zwei Synth-Stimmen auf demselben Grundton. Liegt er HÖHER als nötig, zahlt jeder \
                Akkord Bewegung für nichts.
                """)
        }
    }

    /// Der Abstand ist eine ECHTE Trennung, keine Null. Dieser Anspruch ist absichtlich der
    /// einzige, der eine Zahl vergleicht — und er vergleicht sie gegen 0, nicht gegen 3: er
    /// verbietet dem Founder nicht, den Abstand zu ändern (#364), nur ihn abzuschaffen.
    func testTheClearanceIsARealSeparation() {
        XCTAssertGreaterThan(BioComposer.padBassClearance, 0, """
            `padBassClearance` ist \(BioComposer.padBassClearance) — bei 0 ist der Boden wieder \
            die Bassnote selbst und #1362 ist vollständig zurück, mit einem grünen Wächter \
            daneben. Wenn der Abstand wirklich weg soll, gehört die ⛔-Prosa an der Aufrufstelle \
            in `BioComposer.composeHarmonic` im SELBEN Commit mit.
            """)
    }

    // MARK: - claim 2 — der Boden liegt NIE unter dem Bass, über eine Sweep-Fläche

    /// Anspruch 1 prüft den einen Fall, der heute auftritt. Dieser prüft die FLÄCHE: für jede
    /// Kombination aus Akkord-Grundstellung und Basslage darf der Boden nie unter
    /// `bassRoot + padBassClearance` fallen — auch dann nicht, wenn eine künftige Änderung an
    /// `composeHarmonic` den Bass näher an den Pad heranrückt oder ihn (etwa über einen
    /// Oktav-Versatz) darüber schiebt.
    func testTheFloorNeverDipsToTheBass() {
        for padBottom in stride(from: 24, through: 96, by: 4) {
            for delta in stride(from: -24, through: 24, by: 3) {
                let bassRoot = padBottom + delta
                let floor = BioComposer.padRegisterFloor(padBottom: padBottom, bassRoot: bassRoot)
                XCTAssertGreaterThanOrEqual(floor, bassRoot + BioComposer.padBassClearance, """
                    Boden \(floor) liegt bei padBottom \(padBottom) / bassRoot \(bassRoot) \
                    unter dem Bass-Abstand \(bassRoot + BioComposer.padBassClearance).
                    """)
                XCTAssertGreaterThanOrEqual(floor, 0,
                                            "Boden \(floor) ist keine gültige MIDI-Tonhöhe")
            }
        }
    }

    /// GEGENGEWICHT (#343) — der Boden darf die Grundstellung des Akkords nicht VERLIEREN. Wäre
    /// er immer `bassRoot + clearance`, läge er bei einem tief gesetzten Bass weit unter dem
    /// Fenster und das Voice-Leading dürfte den Akkord beliebig weit nach unten ziehen; wäre er
    /// immer `padBottom`, gäbe es gar keine Inversion mehr nach unten. Er muss beides können:
    /// eine Oktave Spielraum, WO der Bass sie lässt.
    func testTheFloorStillAllowsADownwardInversionWhereTheBassAllowsIt() {
        // Bass zwei Oktaven tief: der Boden gehört dann der Oktavregel, nicht dem Bass.
        for padBottom in [48, 60, 72] {
            let floor = BioComposer.padRegisterFloor(padBottom: padBottom, bassRoot: padBottom - 24)
            XCTAssertEqual(floor, padBottom - 12, """
                Bei einem Bass zwei Oktaven unter der Grundstellung muss der Boden die alte \
                Oktavregel sein (\(padBottom - 12)), nicht \(floor). Sonst hat #1362 das \
                Voice-Leading-Fenster generell verengt statt nur den Bass freigestellt — eine \
                Reparatur, die mehr wegnimmt als der Defekt kostete.
                """)
        }
    }

    // MARK: - claim 3 — die beiden Prämissen, die den Beweis tragen, gelten für JEDES Genre

    /// ⭐ DER ANSPRUCH, DEN NIEMAND ERWARTET UND DER AM MEISTEN WERT HAT. Der ganze Befund steht
    /// und fällt damit, dass `basePitches.min()` der Akkord-GRUNDTON ist und der Bass exakt eine
    /// Oktave darunter. Beides ist eine Eigenschaft der AUTHORED Profile, nicht des Komponisten —
    /// ein Genre mit `chordTones: [2, 4, 6]` oder `padOctave: 1` bricht den Beweis, ohne eine
    /// Zeile in `BioComposer` anzufassen. Dann ist dieser Anspruch rot und NENNT das Genre.
    func testEveryAuthoredProfileCarriesTheProof() {
        for style in MusicStyle.allCases {
            let profile = style.harmonicProfile
            XCTAssertEqual(profile.chordTones.first, 0, """
                \(style.rawValue) hat `chordTones: \(profile.chordTones)` — der erste Eintrag \
                ist nicht 0.

                Damit ist `basePitches.min()` nicht mehr der Akkord-Grundton, und die Herleitung \
                im ⛔-Block an `composeHarmonic`s Voice-Leading-Fenster gilt für dieses Genre \
                nicht. Der Boden bleibt sicher (er nimmt das Maximum), aber die PROSA wird falsch \
                — sie im selben Commit mitziehen.
                """)
            XCTAssertGreaterThanOrEqual(profile.padOctave, 2, """
                \(style.rawValue) hat `padOctave: \(profile.padOctave)`. Bei 1 oder darunter \
                greift in `composeHarmonic` das `max(0, profile.padOctave - 1 + octShift)` \
                (octShift ist −1 auf dunklen Takes), der Bass liegt dann NICHT mehr eine Oktave \
                unter der Grundstellung, und `bassRoot` beschreibt eine andere Note als die \
                gespielte. Prüfen, ob der Boden dann noch das Richtige tut.
                """)
            XCTAssertFalse(profile.chordTones.isEmpty,
                           "\(style.rawValue) hat kein `chordTones` — der Pad hätte keine Stimmen")
        }
    }

    // MARK: - claim 4 — das Tonsystem hält die Oktave bei genau 12

    /// Die dritte Prämisse, und die einzige, die außerhalb von `Sequencer/` liegen könnte.
    /// `MusicalKey.degree` rechnet `base = (octave + 1) * 12 + root`; wäre der Oktavabstand nicht
    /// exakt 12, wäre `bassRoot` nicht `padBottom - 12` und der ⛔-Block eine Behauptung über ein
    /// Tonsystem, das das Repo nicht mehr benutzt. Über mehrere Skalen gefahren, weil
    /// `degreesPerOctave` je Skala verschieden ist — der OKTAVSCHRITT ist es nicht.
    func testAnOctaveIsExactlyTwelveSemitonesInEveryScale() {
        for scale in Scale.allCases {
            let key = MusicalKey(root: 0, scale: scale)
            for degree in 0...(max(1, key.degreesPerOctave) * 2) {
                XCTAssertEqual(key.degree(degree, octave: 4) - key.degree(degree, octave: 3), 12, """
                    In \(scale) liegt Grad \(degree) zwischen Oktave 3 und 4 nicht 12 Halbtöne \
                    auseinander. Die #1362-Herleitung („der Bass ist `basePitches.min() - 12`") \
                    gilt dann nicht mehr.
                    """)
            }
        }
    }

    // MARK: - claim 5 — die Aufrufstelle benutzt den Boden, und sie füttert ihn mit dem BASS

    /// Ein korrekter reiner Rechner ohne Aufrufer ist derselbe Defekt mit mehr Schritten (#403).
    /// Dieser Scan pinnt beide Hälften: dass `composeHarmonic` den Boden ruft, UND dass das
    /// `bassRoot`-Argument aus `bassOct` kommt — also aus der Oktave, die eine Zeile höher an
    /// `appendBass` geht. Ein Boden, der mit der PAD-Oktave gefüttert wird, wäre grün in jedem
    /// Anspruch oben und im Ergebnis wirkungslos.
    func testTheComposerAsksTheFloorAndFeedsItTheBass() throws {
        let code = try self.code(at: "Sources/Echoelmusic/Sequencer/BioComposer.swift")
        XCTAssertTrue(code.contains("padRegisterFloor(padBottom:"), """
            `BioComposer.composeHarmonic` ruft `padRegisterFloor(padBottom:…)` nicht mehr. \
            Wenn das Voice-Leading-Fenster anders gebaut wird, muss die neue Form den Bass \
            weiterhin freihalten — sonst ist #1362 zurück.
            """)
        XCTAssertTrue(code.contains("let bassRoot = key.degree(rootDegree, octave: bassOct)"), """
            `bassRoot` wird nicht mehr aus `bassOct` abgeleitet. `bassOct` ist die Oktave, die \
            eine Zeile weiter oben an `appendBass` geht — wird der Boden mit einer anderen \
            gefüttert (etwa `profile.padOctave`), hält er einen Abstand zu einer Note, die \
            niemand spielt, und der echte Bass bleibt kollisionsfähig.
            """)
        XCTAssertTrue(code.contains("bassRoot: bassRoot"), """
            Der Boden bekommt nicht mehr `bassRoot` übergeben.
            """)
    }

    /// Und die Gegenrichtung: die ALTE Formel darf nicht daneben wieder auftauchen. Ein
    /// `register:`-Argument, das erneut direkt aus `basePitches.min() - 12` gebaut wird, ist
    /// wörtlich der zurückgenommene Defekt.
    func testTheOldUnguardedWindowIsNotBackInCode() throws {
        let code = try self.code(at: "Sources/Echoelmusic/Sequencer/BioComposer.swift")
        XCTAssertFalse(code.contains("let lo = Swift.max(0, (basePitches.min() ?? 0) - 12)"), """
            Der alte Fensterboden `Swift.max(0, (basePitches.min() ?? 0) - 12)` steht wieder im \
            CODE (nicht in einem Kommentar — dieser Scan liest `SourceText.codeOnly`). Er ist \
            IDENTISCH mit der Bassnote; #1362 wäre damit vollständig zurück.
            """)
    }

    // MARK: - claim 6 — das Fenster bleibt spielbar

    /// GEGENGEWICHT (#343), die zweite Hälfte: ein Boden, der den Bereich zu eng macht, ersetzt
    /// ein Unisono durch ein kaputtes Voicing. Über die echten Profile gerechnet — Grundstellung
    /// und Spitze aus `chordTones`, Bass eine Oktave darunter — muss das Fenster in jedem
    /// angebotenen Genre mindestens eine Oktave breit bleiben, damit `candidateVoicings`
    /// überhaupt eine Wahl hat und nicht auf `fallbackStack` zurückfällt.
    func testTheWindowStaysAtLeastAnOctaveWideForEveryOfferedGenre() {
        let key = MusicalKey(root: 0, scale: .minor)
        for style in MusicStyle.offered {
            let profile = style.harmonicProfile
            guard let lowTone = profile.chordTones.min(),
                  let highTone = profile.chordTones.max() else { continue }
            for octShift in [-1, 0] {
                let padBottom = key.degree(lowTone, octave: profile.padOctave + octShift)
                let padTop = key.degree(highTone, octave: profile.padOctave + octShift)
                let bassRoot = key.degree(0, octave: max(0, profile.padOctave - 1 + octShift))
                let hi = Swift.min(127, padTop + 12)
                let lo = Swift.min(BioComposer.padRegisterFloor(padBottom: padBottom,
                                                                bassRoot: bassRoot), hi)
                XCTAssertLessThanOrEqual(lo, hi, """
                    \(style.rawValue) (octShift \(octShift)): Boden \(lo) über Decke \(hi). \
                    `lo...hi` würde fallen — ein Absturz mitten in einer Performance.
                    """)
                XCTAssertGreaterThanOrEqual(hi - lo, 12, """
                    \(style.rawValue) (octShift \(octShift)): das Voice-Leading-Fenster ist nur \
                    \(hi - lo) Halbtöne breit (\(lo)…\(hi)). Unter einer Oktave findet \
                    `candidateVoicings` keine echte Auswahl mehr und fällt auf `fallbackStack` \
                    zurück — das Voice-Leading wäre formal an und musikalisch aus.
                    """)
            }
        }
    }

    // MARK: - Werkzeug

    private struct AnchorMissing: Error { let reason: String }

    /// Verzeichnis-gegated, nie pro Datei (#475): eine `fileExists`-Klammer um jede einzelne
    /// Lesung macht aus genau der Katastrophe, gegen die hier geprüft wird, ein grünes SKIP.
    private func code(at relativePath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: """
                \(relativePath) fehlt, während der Baum da ist — umbenannt oder verschoben. \
                Neu verankern, nicht überspringen lassen (#454).
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }
}
