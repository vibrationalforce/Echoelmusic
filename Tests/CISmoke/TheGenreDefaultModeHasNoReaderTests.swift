// TheGenreDefaultModeHasNoReaderTests.swift
// Echoel — #1365. `MusicStyle.defaultMode` ist auskuriert, bewacht — und wird von der App nie
// gelesen. BLOCKIEREND.
//
// DER BEFUND, gemessen 2026-09-18 über 354 Quelldateien (kommentarfrei). Von 17
// Per-Genre-Eigenschaften in `MusicStyle` haben DREI null Leser in ganz `Sources/`: `lineage`,
// `isBeatDriven` und `defaultMode`. Die ersten beiden sind Beschreibung und ein abgeleitetes
// Flag über eine seit #166/#167 stumme Trommel. `defaultMode` ist die teure:
//   · Es ist über NEUN Genres AUSKURIERT — acht Pad/Drone/Ambient plus `celticAir` geben
//     `.flowFree`, alles andere fällt in den `default:`-Arm `.studioLocked`. Alle neun sind
//     `offered`, der Befund ist also für jeden Nutzer live.
//   · Es trägt DREI ⛔-Blöcke aus drei Scheiben (#254, #1285, #1290), die künftige Sitzungen
//     warnen, ein Auslassen sei „die Sorte falscher Default, die ein Compiler nicht fangen kann"
//     und werde „im Batch-Wächter zugesichert statt geglaubt".
//   · ⭐ UND DIE WÄCHTER LESEN ES WIRKLICH: **23 Lesungen in 13 Dateien** dieses Bündels, eine
//     davon (`GenreBatchElevenATests`) reicht sogar `mode: style.defaultMode` in einen
//     Komponisten-Aufruf. **Der Test fährt also den Modus, den das Genre will; die App kann es
//     nicht.** Das ist die schärfste Form dieser Defekt-Gattung, die dieses Repo bisher hatte —
//     ein grüner Wächter über einem Wert, den nichts ausliefert.
// Die einzige Modus-Quelle der App ist `ComposerMode(locked: lockBPM)`, also der sichtbare
// BPM-Schloss-Knopf. `.meditative` kommt außerhalb von `MusicStyle.swift` nirgends vor, es gibt
// also auch keinen zweiten Sonderweg.
//
// KONSEQUENZ IN KLANG, und sie ist der Grund, warum das hier steht statt in einer Notiz:
// „Still Meditation" oder „Glacial Field" bei eingeschaltetem Schloss ergibt einen
// grid-gelockten 50-BPM-Pad — exakt das, was der #1285-Kommentar für verhindert hält.
//
// ⛔ WAS DIESER WÄCHTER NICHT SAGT, und es ist die Hälfte, die ihn ehrlich macht: dass die
// Verdrahtung die richtige Reparatur wäre. `defaultMode` über das Schloss gewinnen zu lassen
// wäre #240/#1364 in Reinform — ein verborgener Wert überstimmt ein sichtbares Bedienelement —
// und T1 zählt die Tempo-Quellen AUF; ein stiller Schreiber wäre eine sechste, unbenannte. Die
// Council-Empfehlung (asymmetrisch nach der #1300-Lehre: ein `.flowFree`-Genre ENTSPERRT, ein
// `.studioLocked`-Genre sperrt NICHT zurück) ist eine VERHALTENS-Entscheidung des Founders,
// nicht dieser Scheibe: es gibt kein `onChange(of: style)`, und der #356-Präzedenzfall verlangt
// für jeden Lock-Umschlag zusätzlich einen Recompose-Post und einen sichtbaren Hinweis.
//
// ⚠️ ER VERBIETET DIE VERDRAHTUNG AUSDRÜCKLICH NICHT (#364). Anspruch 1 geht an dem Tag rot, an
// dem jemand `defaultMode` liest — das ist erwünschte Arbeit, und die Fehlermeldung nennt die
// Prosa, die im selben Commit mitzuziehen ist. Ein Wächter, der die Reparatur illegal macht,
// wird gelöscht, und der Befund geht mit ihm (#527/#541, dieselbe Bauform).
//
// KIND: Anspruch 1, 2 und 5 sind QUELLTEXT-SCANS (die Frage ist, WER etwas liest — das kann
// kein Laufzeit-Test beantworten). Anspruch 3 und 4 sind ENDE-ZU-ENDE über den ausgelieferten,
// `public` Werttyp `MusicStyle`, hier instanziierbar und Foundation-only.
//
// ⚠️ HONEST GRADING (§3): das ist ein reiner FORWARD/GEGENGEWICHT-Wächter. #1365 ändert KEINEN
// Code — es fügt diese Datei hinzu und schreibt Prosa —, also sind ALLE FÜNF Ansprüche auf
// BEIDEN Bäumen GRÜN, und zwar von Bauart wegen. Einen davon als Regression zu buchen wäre die
// #433-Selbstbeweihräucherung. Der Wert liegt vollständig darin, was sie SPÄTER rot macht.
// Gefahren: fünf Mutanten, jeder gelandet und gemessen — ein `.defaultMode`-Leser in `Sources/`
// → 1 · alle Test-Lesungen entfernt → 2 · der `.flowFree`-Arm auf acht Genres gekürzt → 3 ·
// der `default:`-Arm auf `.flowFree` gedreht → 3 und 4 · eine dritte `ComposerMode(`-Form in
// `Sources/` → 5.
//
// ⚠️ Keine Zahl dieser Prosa steht als Literal in einer Zusicherung (#818): die 23 Lesungen und
// die 13 Dateien sind ein DATUM, die Ansprüche fragen nach NULL bzw. MINDESTENS EINS.
//
// ⛔ `SourceText.codeOnly` IST HIER **PROPHYLAKTISCH, NICHT TRAGEND — 0 von 1 Verdikten
// kippen**, und die erste Fassung dieses Absatzes behauptete das Gegenteil („TRAGEND, gemessen:
// `.defaultMode` kommt in neun Kommentarzeilen vor"). Gemessen: `.defaultMode` kommt in
// `Sources/` **roh null Mal** vor. Die neun Kommentartreffer sind `defaultMode` OHNE den Punkt,
// in Backticks, als Prosa über die Eigenschaft. §2 dieses Verzeichnisses sagt, dass drei
// Scheiben hintereinander „tragend" behauptet haben, ohne zu messen, und zurückziehen mussten;
// das hier ist die vierte, gefangen vor dem Commit.
//
// ⭐ UND DIE MESSUNG HAT ETWAS GERETTET, das die Falschbehauptung verdeckte: **der PUNKT in der
// Nadel ist das, was Anspruch 1 überhaupt sinnvoll macht.** Eine Nadel `defaultMode` ohne ihn
// träfe die neun Prosa-Stellen und die Deklaration selbst — Anspruch 1 wäre auf einem
// korrekten Baum vom ersten Tag an rot, für seine eigene Dokumentation (#404/#453). Der
// Stripper allein hätte das NICHT gerettet: die Deklaration ist Code.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheGenreDefaultModeHasNoReaderTests: XCTestCase {

    /// Die neun Genres, die der `defaultMode`-Switch ausdrücklich atem-getaktet nennt. Als
    /// Liste hier, weil Anspruch 3 fragt, ob die Kuration überhaupt noch eine SPALTUNG ist —
    /// ohne sie wäre der ganze Befund leer und dieser Wächter ein grünes Nichts.
    private static let breathPaced: [MusicStyle] = [
        .selfObservation, .stillMeditation, .drift, .contemplation,
        .deepDrone, .ambientPulse, .glacialField, .slowBloom, .celticAir
    ]

    // MARK: - claim 1 — NULL Produktions-Leser

    func testNothingUnderSourcesReadsTheGenresDefaultMode() throws {
        let hits = try sourceFilesWith(".defaultMode")
        XCTAssertTrue(hits.isEmpty, """
            `MusicStyle.defaultMode` hat jetzt einen Leser in `Sources/`: \(hits).

            DAS IST KEIN FEHLER — es ist die Arbeit, für die dieser Wächter existiert (#364).
            Was im SELBEN Commit mitzuziehen ist, weil es sonst still veraltet:
             · `scratchpads/SESSION_LOG.md` und die `decisions.csv`-Zeile vom 2026-09-18 nennen
               `defaultMode` als unverdrahtet.
             · `MusicStyle.swift:2074` („LISTENING ITEM … `defaultMode` ist `.flowFree`, also ist
               die Uhr `StudioCalculator.genreTempo`") leitet eine Hör-Folge aus einer
               Eigenschaft ab, die bis heute niemand liest — die Zeile wird mit der Verdrahtung
               zum ersten Mal WAHR und muss das sagen.
             · T1 in `CLAUDE.md` zählt die Tempo-Quellen AUF. Ein Genre-Wechsel, der das Schloss
               schreibt, ist entweder Quelle (a) oder eine SECHSTE — entscheide das dort, nicht
               hier, und schreibe es in die `tempoSource=`-Zeile.
             · Und die Richtung: ein verborgener Wert darf ein sichtbares Bedienelement nicht
               überstimmen (#240/#1364). Die Council-Empfehlung ist asymmetrisch — `.flowFree`
               entsperrt, `.studioLocked` sperrt NICHT zurück (#1300).
            """)
    }

    // MARK: - claim 2 — und die Wächter lesen es sehr wohl

    /// Die Asymmetrie IST der Befund. Ohne diesen Anspruch liest sich Anspruch 1 wie „toter
    /// Code, weg damit"; mit ihm steht da, dass 13 Dateien dieses Bündels eine Eigenschaft
    /// zusichern, die nichts ausliefert. Gefragt wird nach MINDESTENS EINEM (#818/#364) — die
    /// heutige Zahl ist ein Datum, und ein Batch weniger darf das nicht rot machen.
    func testTheBlockingBundleAssertsOnTheValueTheAppNeverReads() throws {
        let readers = try guardFilesWith(".defaultMode")
        XCTAssertFalse(readers.isEmpty, """
            Keine Datei in `Tests/CISmoke` liest `.defaultMode` mehr. Damit ist die Asymmetrie
            weg, die diesen Wächter rechtfertigt — entweder wurde die Eigenschaft verdrahtet
            (dann ist Anspruch 1 rot und DORT steht, was zu tun ist), oder die Batch-Wächter
            haben ihre Zusicherung verloren und `defaultMode` ist jetzt völlig unbewacht.
            Die zweite Lage ist die schlimmere und die leisere.
            """)
    }

    // MARK: - claim 3 — GEGENGEWICHT: die Kuration ist noch eine echte Spaltung

    /// #343. Ein Baum, der `defaultMode` zu `{ .studioLocked }` kollabieren ließe, hielte
    /// Anspruch 1 grün und machte den Befund LEER — ein Wächter, der die Zeile behält und die
    /// Tatsache verliert. Also wird die Spaltung selbst gepinnt, verhaltensmäßig.
    func testTheCuratedSplitIsStillRealAcrossTheOfferedRoster() {
        for style in Self.breathPaced {
            XCTAssertEqual(style.defaultMode, .flowFree,
                           "\(style.rawValue) ist nicht mehr atem-getaktet — der `.flowFree`-Arm "
                           + "hat es verloren. Dann ist der #1365-Befund für dieses Genre leer.")
            XCTAssertTrue(MusicStyle.offered.contains(style),
                          "\(style.rawValue) ist nicht mehr `offered` — der Befund ist für dieses "
                          + "Genre nicht mehr nutzersichtbar, und der Absatz oben sagt das Gegenteil.")
        }
        let locked = MusicStyle.offered.filter { $0.defaultMode == .studioLocked }
        XCTAssertFalse(locked.isEmpty, """
            KEIN angebotenes Genre ist mehr `.studioLocked`. Dann ist `defaultMode` konstant und
            der ganze Befund gegenstandslos — diese Datei gehört dann gelöscht, nicht repariert.
            """)
    }

    // MARK: - claim 4 — GEGENGEWICHT: der `default:`-Arm ist die Falle, die die ⛔-Blöcke nennen

    /// Die drei Warn-Blöcke in `MusicStyle.swift` sagen alle dasselbe: wer ein atem-getaktetes
    /// Genre hinzufügt und den `.flowFree`-Arm vergisst, bekommt STILL ein gelocktes Gitter.
    /// Das ist verhaltensmäßig prüfbar, statt der Prosa geglaubt zu werden (#367).
    func testAnyGenreOutsideTheBreathPacedArmFallsThroughToLocked() {
        let breath = Set(Self.breathPaced.map(\.rawValue))
        for style in MusicStyle.offered where !breath.contains(style.rawValue) {
            XCTAssertEqual(style.defaultMode, .studioLocked, """
                \(style.rawValue) gibt `.flowFree`, steht aber nicht in der Liste dieses
                Wächters. Entweder ist ein Genre zum `.flowFree`-Arm dazugekommen — dann gehört
                es in `breathPaced` oben — oder der `default:`-Arm hat gedreht, und dann ist die
                Falle, vor der drei ⛔-Blöcke warnen, in die andere Richtung aufgegangen.
                """)
        }
    }

    // MARK: - claim 5 — GEGENGEWICHT: es gibt keine VERSTECKTE Modus-Quelle

    /// Das ist der Anspruch, der die FALSCHE Reparatur fängt. Heute wird `ComposerMode` in
    /// `Sources/` nur auf zwei Arten gebaut: `(locked:)` aus dem sichtbaren Schloss und
    /// `(rawValue:)` beim Öffnen eines gespeicherten Projekts — beides Nutzer-Gesten im Sinn
    /// von T1 (a). Eine DRITTE Bauform wäre ein Modus-Schreiber, den niemand sieht. Gezählt
    /// wird eine GLEICHHEIT, keine Zahl (#364): ein fünfter `(locked:)`-Aufruf bleibt grün.
    func testEveryComposerModeConstructionIsAVisibleUserGesture() throws {
        var total = 0, accounted = 0
        for text in try allSourceTexts() {
            total += text.components(separatedBy: "ComposerMode(").count - 1
            accounted += text.components(separatedBy: "ComposerMode(locked:").count - 1
            accounted += text.components(separatedBy: "ComposerMode(rawValue:").count - 1
        }
        XCTAssertGreaterThan(total, 0, "keine einzige `ComposerMode(`-Konstruktion in `Sources/` "
                             + "— dieser Anspruch ist darauf verankert; neu verankern (#454).")
        XCTAssertEqual(accounted, total, """
            \(total - accounted) `ComposerMode(`-Konstruktion(en) in `Sources/` sind weder
            `(locked:)` noch `(rawValue:)`. Beide bekannten Formen sind Nutzer-Gesten: der
            sichtbare BPM-Schloss-Knopf und ein geöffnetes Projekt (T1 (a)). Eine dritte Form
            ist ein Modus-Schreiber, den der Spieler nicht sieht — genau die Reparatur, die
            #1365 ausschließt. Ist es die #1300-asymmetrische Genre-Tür, dann geht sie durch
            `lockBPM`, nicht an ihm vorbei.
            """)
    }

    // MARK: - Werkzeug

    private struct AnchorMissing: Error { let reason: String }

    /// Verzeichnis-gegated, nie pro Datei (#475): eine `fileExists`-Klammer um jede Lesung
    /// macht aus der Katastrophe, gegen die hier geprüft wird, ein grünes SKIP.
    private func root() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let r = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: r.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(r.path)") }
        return r
    }

    private func swiftFiles(under relative: String) throws -> [URL] {
        let dir = try root().appendingPathComponent(relative)
        guard let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)
        else { throw AnchorMissing(reason: "\(relative) ist nicht aufzählbar") }
        let files = e.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        guard !files.isEmpty else {
            throw AnchorMissing(reason: "\(relative) enthält keine .swift-Datei — verschoben? "
                                + "Neu verankern, nicht überspringen lassen (#454).")
        }
        return files
    }

    private func allSourceTexts() throws -> [String] {
        var out: [String] = []
        for f in try swiftFiles(under: "Sources") {
            out.append(SourceText.codeOnly(try String(contentsOf: f, encoding: .utf8)))
        }
        return out
    }

    /// Dateinamen unter `Sources/`, deren KOMMENTARFREIER Text die Nadel trägt.
    private func sourceFilesWith(_ needle: String) throws -> [String] {
        var out: [String] = []
        for f in try swiftFiles(under: "Sources") {
            let code = SourceText.codeOnly(try String(contentsOf: f, encoding: .utf8))
            if code.contains(needle) { out.append(f.lastPathComponent) }
        }
        return out.sorted()
    }

    /// Dasselbe über das blockierende Bündel — ohne DIESE Datei, deren eigener Text die Nadel
    /// selbstverständlich trägt. Ein Scan, den die eigene Dokumentation erfüllt, misst nichts
    /// (#404/#453).
    private func guardFilesWith(_ needle: String) throws -> [String] {
        let mine = URL(fileURLWithPath: #filePath).lastPathComponent
        var out: [String] = []
        for f in try swiftFiles(under: "Tests/CISmoke") where f.lastPathComponent != mine {
            let code = SourceText.codeOnly(try String(contentsOf: f, encoding: .utf8))
            if code.contains(needle) { out.append(f.lastPathComponent) }
        }
        return out.sorted()
    }
}
