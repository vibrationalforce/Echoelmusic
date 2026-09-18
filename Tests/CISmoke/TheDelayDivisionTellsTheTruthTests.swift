// TheDelayDivisionTellsTheTruthTests.swift
// Echoel — #1364. Die VIERTE Character-Stempelstelle zieht den Delay-Teiler nach. BLOCKIEREND.
//
// DER DEFEKT. Vier Stellen stempeln einen FX-Character auf jede Kette, und jeder Stempel setzt
// eine Delay-ZEIT. Drei davon — `EchoelStudioView.applyFX()`, der Re-Seed-Pfad und der
// Open-Take-Pfad — rufen unmittelbar danach `applyDelaySync(bpm:)` und machen damit die Kette zu
// dem, was der sichtbare Teiler-Picker ANZEIGT. Die vierte, `FXViewModel.applyCharacter` in der
// FX-Fläche, tat es nicht. Nach einem Tap auf „Cassette" oder „Dream" zeigte der Studio-Picker
// also eine Notenteilung an, die keine Kette hielt — genau das, was #240s eigenes Gesetz
// verbietet: ein sichtbares Bedienelement darf nicht eine Teilung anzeigen, während die Kette
// eine andere spielt.
//
// ⭐ WARUM DIE KETTE DEM PICKER FOLGT UND NICHT UMGEKEHRT — die Frage ist im Repo bereits
// dreimal beantwortet, und der Open-Take-Pfad schreibt die Antwort in seinem eigenen ⛔-Block:
// „die Kette zu dem zu machen, was der Picker ZEIGT, ist das, was das Lügen beendet". Die
// vierte Stelle anders zu lösen wäre die Inkonsistenz, vor der derselbe Absatz warnt — „half of
// #240 fixed is a new inconsistency, not a smaller one".
//
// ⚠️ WAS DIE REPARATUR KOSTET, gepinnt als Wissen und nicht als Wunsch: die vom Character
// AUTORISIERTE Delay-ZEIT geht auf dieser Stelle jetzt genauso verloren wie auf den drei
// anderen. Seine sieben übrigen Delay-Felder (Modus, Mix, Feedback, Ton, Spread, Wow, Drive)
// bleiben unangetastet. Wer das zurückdreht, dreht es an ALLEN VIER Stellen zurück.
//
// KIND: QUELLTEXT-SCAN, aus demselben Grund wie `DelayReachesEveryChainTests` — die Ketten
// liegen hinter `@Environment` auf einem SwiftUI-`View`, `applyDelaySync` ist `private`, und es
// gibt hier keine Toolchain für einen UI-Test-Host. Jeder Scan liest `SourceText.codeOnly`; die
// ⛔-Blöcke dieser Reparatur zitieren die Nadeln absichtlich in Prosa, und ein Scan, den die
// eigene Dokumentation erfüllt, misst nichts (#404/#453).
//
// ⛔ WAS HIER BEWUSST NICHT STEHT (#364/#491): ein Negativ-Scan auf die alte „noch nicht
// behoben"-Prosa. Die vier Zuhause tragen ihre Rücknahme WÖRTLICH — ein solcher Scan träfe
// seine eigene Rücknahme, derselbe Fehler, den CLAUDE.md dreimal aufschreibt.
//
// ⚠️ HONEST GRADING (§3): keine Swift-Toolchain in der Web-Sitzung. Jeder Anspruch ist in Python
// gegen BEIDE Bäume gefahren, mit einer zeilengetreuen Portierung von `SourceText.codeOnly` und
// der klammermatchenden Rumpf-Hilfe — nicht mit einem NACHGEBAUTEN Modell davon: eine
// Transkription, die die Formel neu erfindet statt sie zu LESEN, ist blind für genau den
// Mutanten, der die Formel ändert. Am Eltern-Stand `5f24b28` sind ALLE VIER Ansprüche ROT.
//
// ⚠️ Anspruch 3 ist damit KEIN reines Gegengewicht mehr, und das wird hier gesagt statt
// geglättet: seine Schwelle ist die heutige Trefferzahl (6), also fängt er zusätzlich das
// Fehlen der neuen Closure. Als #343-Gegengewicht wirkt er trotzdem — er ist der einzige
// Anspruch, den ein VERSCHIEBEN statt Ergänzen rot färbt.
//
// Sechs Mutanten, jeder gelandet und dann gemessen (nicht erschlossen): `resyncDelayDivision()`
// aus `applyCharacter` entfernt → 1 · dieselbe Zeile HINTER `reseed()` → 1 ·
// Produktions-Aufrufstelle auf das Default `{}` zurückgesetzt → 2 UND 3 · einer der fünf
// `applyDelaySync`-Aufrufe entfernt statt ergänzt → 3 · `currentTempo` durch `pattern.tempo`
// ersetzt → 2 · `self.resyncDelayDivision = …` aus dem `init` entfernt → 4. Keiner entkam.
//
// ⚠️ Die erste Fassung dieser Zeile SCHÄTZTE zwei davon falsch — sie schrieb den ersten Mutanten
// „→ 1, 4" (Anspruch 4 prüft Deklaration, Speicherung und Durchreichung; ein entfernter AUFRUF
// lässt alle drei stehen) und den dritten „→ 2" (er nimmt zugleich einen der sechs Nadel-Treffer
// weg, also fällt auch 3). Beide Richtungen sind harmlos, die Lehre ist es nicht: **eine
// Mutanten-Tabelle, die man aus dem Kopf schreibt statt sie zu FAHREN, behauptet Deckung,
// die niemand geprüft hat** — und genau das ist der Anspruch, den dieser Wächter erhebt.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheDelayDivisionTellsTheTruthTests: XCTestCase {

    // MARK: - claim 1 — die vierte Stelle ruft die Nachführung, und zwar VOR `reseed()`

    /// Die REIHENFOLGE ist das ganze Gesetz, nicht ein Stilpunkt: `reseed()` liest
    /// `c.delay.timeSeconds` in den `delayTime`-Spiegel der FX-Fläche zurück. Liefe die
    /// Nachführung danach, hielte die Kette die Picker-Zeit und der FX-Regler zeigte die
    /// Character-Zeit — dieselbe Lüge, nur eine Fläche weiter. Ein Wächter, der nur die
    /// ANWESENHEIT des Aufrufs prüft, ließe genau diesen Fehler durch.
    func testTheCharacterStampResyncsTheDivisionBeforeItReseedsTheMirrors() throws {
        let body = try declarationBody(of: "func applyCharacter(_ character: FXCharacter) {",
                                       in: "Sources/Echoelmusic/Studio/EchoelFXView.swift")
        guard let resync = body.range(of: "resyncDelayDivision()") else {
            return XCTFail("""
                `FXViewModel.applyCharacter` ruft `resyncDelayDivision()` nicht mehr. Damit ist
                die vierte Character-Stempelstelle wieder die einzige ohne Teiler-Nachführung,
                und der Studio-Picker zeigt nach einem Tap auf einen Character eine Notenteilung
                an, die keine Kette hält (#240s Gesetz, #1364s Reparatur).
                """)
        }
        guard let reseed = body.range(of: "reseed()") else {
            return XCTFail("`applyCharacter` ruft `reseed()` nicht mehr — dieser Anspruch ist auf beide verankert")
        }
        XCTAssertLessThan(resync.lowerBound, reseed.lowerBound, """
            `resyncDelayDivision()` steht HINTER `reseed()`. `reseed()` liest
            `c.delay.timeSeconds` in den `delayTime`-Spiegel zurück — läuft die Nachführung
            danach, zeigt der FX-Regler die Character-Zeit, während die Kette die Picker-Zeit
            hält. Die Lüge wäre dann nur eine Fläche weiter gewandert, nicht weg.
            """)
    }

    // MARK: - claim 2 — die Produktions-Aufrufstelle benutzt nicht das Default

    /// Das `= {}`-Default existiert, damit `FXViewModel` ohne Studio konstruierbar bleibt (Tests,
    /// Vorschau). Genau deshalb kann es den Defekt still zurückbringen: ein vergessenes Argument
    /// an der EINEN Produktions-Aufrufstelle sähe im Diff aus wie nichts (#431/#440/#443). Also
    /// wird die Aufrufstelle selbst gepinnt — samt der Tempo-Quelle.
    func testTheStudioPassesTheClosureAndUsesItsOwnAuthoritativeTempo() throws {
        let code = try self.code(at: "Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        XCTAssertTrue(code.contains("resyncDelayDivision: { applyDelaySync(bpm: currentTempo) })"), """
            Die Produktions-Aufrufstelle von `EchoelFXView` reicht die Nachführung nicht mehr
            als `resyncDelayDivision: { applyDelaySync(bpm: currentTempo) }` durch.

            Zwei Dinge hängen an dieser einen Zeile:
             · OHNE sie fällt `FXViewModel` auf sein `= {}`-Default zurück, und die vierte
               Stempelstelle lügt wieder — ohne dass irgendwo etwas fehlt, das man SIEHT.
             · `currentTempo` und NICHT das bei `init` eingefrorene `pattern.tempo` der
               FX-Fläche: EINE autoritative Zahl. Der Open-Take-Pfad schreibt dieselbe Regel
               drei Zeilen über seinem eigenen Aufruf auf („a tempo the app never actually
               plays at").
            """)
    }

    // MARK: - claim 3 — GEGENGEWICHT: jeder ältere Nachführ-Pfad überlebt den neuen

    /// #343. Die naheliegende Fehl-Reparatur ist, den Aufruf zu VERSCHIEBEN statt einen zu
    /// ergänzen — etwa „die FX-Fläche macht es jetzt, also kann `applyFX()` es lassen". Das wäre
    /// ein Rückschritt auf vier Pfaden für einen Gewinn auf einem. Gezählt wird deshalb die ZAHL
    /// der Treffer, nicht ihre Anwesenheit; eine Obergrenze steht bewusst NICHT da (#364 — ein
    /// sechster Pfad darf entstehen).
    ///
    /// ⛔ DIE ERSTE FASSUNG DIESES ANSPRUCHS RECHNETE ZWEIMAL FALSCH, und beide Fehler machten
    /// die Schwelle ZU NIEDRIG — also die Richtung, in der ein Wächter beruhigt statt misst.
    /// (a) Sie schrieb „die Deklaration zählt hier nicht mit". Doch: `applyDelaySync(bpm: Double)`
    /// ENTHÄLT die Nadel `applyDelaySync(bpm:` als Teilkette. (b) Sie sagte „drei alte" und meinte
    /// die drei Character-Stempelstellen — es gibt aber eine VIERTE Aufrufstelle, die kein
    /// Character-Stempel ist: die Delay-Einschaltzeile (`chain.delayEnabled = true`), #240s
    /// eigener Pfad. Gemessen über `SourceText.codeOnly`: Eltern-Stand **5**, heute **6**
    /// (1 Deklaration + 5 Aufrufstellen). Die Prosa in den vier Zuhausen sagt weiterhin richtig
    /// „die drei anderen" — sie zählt Character-Stempel, dieser Anspruch zählt Nadeln. **Zwei
    /// verschiedene Fragen, und der Wächter hatte die Antwort der einen auf die andere gelegt.**
    func testEveryOlderResyncPathSurvivesTheNewOne() throws {
        let code = try self.code(at: "Sources/Echoelmusic/Studio/EchoelStudioView.swift")
        let hits = code.components(separatedBy: "applyDelaySync(bpm:").count - 1
        XCTAssertGreaterThanOrEqual(hits, 6, """
            Nur \(hits) `applyDelaySync(bpm:`-Treffer im Studio (kommentarfrei) — erwartet sind
            mindestens SECHS: die Deklaration, die drei Character-Stempelpfade (applyFX, Re-Seed,
            Open-Take), die Delay-Einschaltzeile aus #240 und die #1364-Closure.

            Wurde ein Aufruf VERSCHOBEN statt einer ergänzt? Das repariert einen Pfad und bricht
            vier. Die Deklaration IST in dieser Zahl enthalten — sie lautet
            `applyDelaySync(bpm: Double)` und trägt die Nadel als Teilkette.
            """)
    }

    // MARK: - claim 4 — die Closure ist verdrahtet, nicht nur deklariert

    /// Ein reiner Rechner ohne Aufrufer ist derselbe Defekt mit mehr Schritten (#403). Hier ist
    /// die Kette drei Glieder lang — Speicher, View-`init`, VM-`init` —, und jedes einzelne kann
    /// still reißen, ohne dass etwas nicht mehr kompiliert.
    func testTheClosureIsStoredAndThreadedThroughBothInits() throws {
        let code = try self.code(at: "Sources/Echoelmusic/Studio/EchoelFXView.swift")
        XCTAssertTrue(code.contains("private let resyncDelayDivision: () -> Void"),
                      "`FXViewModel` hält die Closure nicht mehr")
        XCTAssertTrue(code.contains("self.resyncDelayDivision = resyncDelayDivision"),
                      "der `FXViewModel`-init speichert die Closure nicht mehr")
        XCTAssertTrue(code.contains("resyncDelayDivision: resyncDelayDivision"), """
            Der `EchoelFXView`-init reicht die Closure nicht mehr an `FXViewModel` weiter. Die
            Kette Studio → View → ViewModel ist damit unterbrochen, und das VM fällt auf sein
            No-op-Default zurück — kompiliert sauber, lügt still.
            """)
    }

    // MARK: - Werkzeug

    private struct AnchorMissing: Error { let reason: String }

    /// Verzeichnis-gegated, nie pro Datei (#475): eine `fileExists`-Klammer um jede Lesung macht
    /// aus der Katastrophe, gegen die hier geprüft wird, ein grünes SKIP.
    private func code(at relativePath: String) throws -> String {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("Sources").path)
        else { throw XCTSkip("source tree not present under \(root.path)") }
        let path = root.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: """
                \(relativePath) fehlt, während der Baum da ist — umbenannt oder verschoben.
                Neu verankern, nicht überspringen lassen (#454).
                """)
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    /// Der klammergematchte Rumpf hinter `key`, der auf dessen öffnender Klammer endet.
    private func declarationBody(of key: String, in relativePath: String) throws -> String {
        let text = try code(at: relativePath)
        guard let start = text.range(of: key) else {
            throw AnchorMissing(reason: """
                \(relativePath) deklariert `\(key)` nicht mehr. Dieser Scan ist darauf verankert;
                neu verankern, statt die Zusicherung zu löschen.
                """)
        }
        var depth = 0
        var idx = text.index(before: start.upperBound)   // die öffnende Klammer von `key`
        while idx < text.endIndex {
            let ch = text[idx]
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 { return String(text[start.upperBound..<idx]) }
            }
            idx = text.index(after: idx)
        }
        throw AnchorMissing(reason: "unbalancierte Klammern hinter `\(key)` in \(relativePath)")
    }
}
