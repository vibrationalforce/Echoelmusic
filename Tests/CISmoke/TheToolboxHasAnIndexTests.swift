// TheToolboxHasAnIndexTests.swift
// Echoel — #1359: `scripts/` hatte 24 Werkzeuge und kein Inhaltsverzeichnis.
//
// WHY THIS EXISTS. Acht Prüfer laufen in jedem Zyklus, weil sie in den Anweisungsdateien
// namentlich stehen. Gemessen 2026-09-17 standen **zwei** Werkzeuge in KEINER: `window-margins.py`
// und `doorless-state.py` (`git grep` über `CLAUDE.md`, `.claude/**`, `Tests/CISmoke/CLAUDE.md`
// → null Treffer für beide). Ein Werkzeug, das niemand findet, ist teurer als keines: es sieht
// aus wie erledigte Arbeit und wird trotzdem noch einmal getippt. Genau das ist im selben Zyklus
// im Kleinen passiert — für einen Patch-Kommentar wurde fast ein Wegwerf-Parser getippt, obwohl
// `genre-prebatch.py --patch` seit #1351 existiert und seine eigene Abdeckung druckt (#1350).
//
// ⭐ DER WERT LIEGT IN DER SPALTE „WANN", NICHT IN „WAS". Ein Verzeichnis, das nur beschreibt,
// wird beim Suchen nicht gelesen — man sucht ja, WEIL man das Werkzeug nicht kennt. Anspruch 4
// pinnt deshalb die Trennung zwischen dem Acht-Satz und den engen Auslösern: fällt sie weg, ist
// das Verzeichnis wieder ein `ls` mit Fließtext.
//
// ⛔ DIE ERSTE FASSUNG DES VERZEICHNISSES BEHAUPTETE „DREI STANDEN NIRGENDS" UND ZÄHLTE
// `needle-reachability.py` MIT — falsch, es steht in `Tests/CISmoke/CLAUDE.md` §#808 mit Befehl
// und Auslöser. Eine Aussage über einen NACHBARN ist in diesem Repo eine MESSUNG (das Gesetz
// steht im Kopf von `GenreBatchFourteenBTests`); zwei `git grep` haben sie in Sekunden
// widerlegt, bevor sie committet wurde. Anspruch 5 hält die korrigierte Hälfte fest.
//
// #364 — NICHTS HIER VERBIETET EIN NEUES WERKZEUG. Ansprüche 2 und 3 werden rot, wenn eines
// hinzukommt oder verschwindet, und nennen in ihrer Meldung die Zeile, die dann zu schreiben ist.
// Das ist der Zweck: den Eintrag erzwingen, nicht das Werkzeug.
//
// KIND (§1): **SOURCE-TEXT SCAN** über `scripts/` und `scripts/INDEX.md`. Er beweist, dass jedes
// Werkzeug benannt ist — nie, dass die Beschreibung stimmt. Das bleibt beim Lesen.

import XCTest

final class TheToolboxHasAnIndexTests: XCTestCase {

    private static let indexPath = "scripts/INDEX.md"

    /// Die zwei, die 2026-09-17 in KEINER Anweisungsdatei standen. Gepinnt als NAMEN, damit
    /// Anspruch 5 nicht auf eine Zahl fällt, die mit dem nächsten Werkzeug altert (#818).
    private static let narrowTriggerTools = ["window-margins.py", "doorless-state.py"]

    private func root() -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(
                atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    private func text(_ relative: String) throws -> String {
        let url = root().appendingPathComponent(relative)
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: \(relative) could not be read. This guard fails rather "
                    + "than skips (§4) — a missing anchor is a finding, not a pass.")
            return ""
        }
        return contents
    }

    /// Jede Datei in `scripts/`, die ein ausführbares Werkzeug ist. `__pycache__` und alles
    /// ohne diese drei Endungen bleibt draußen.
    private func shippedTools() -> [String] {
        let dir = root().appendingPathComponent("scripts")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.filter { $0.hasSuffix(".py") || $0.hasSuffix(".sh") || $0.hasSuffix(".rb") }
            .sorted()
    }

    /// Jeder Werkzeug-Dateiname, den das Verzeichnis NENNT.
    private func namedTools(in index: String) -> Set<String> {
        var found: Set<String> = []
        var current = ""
        for character in index {
            if character.isLetter || character.isNumber || character == "_"
                || character == "-" || character == "." {
                current.append(character)
            } else {
                if current.hasSuffix(".py") || current.hasSuffix(".sh") || current.hasSuffix(".rb") {
                    found.insert(current)
                }
                current = ""
            }
        }
        if current.hasSuffix(".py") || current.hasSuffix(".sh") || current.hasSuffix(".rb") {
            found.insert(current)
        }
        return found
    }

    // 1 — das Verzeichnis existiert und hat überhaupt etwas gelesen.
    //
    // ⚠️ Nicht Kosmetik: ein Scan, der NICHTS findet, ist ein Wächter, der für immer vacuous
    // grün steht auf einem Dokument, das er nie gelesen hat (#808).
    func testTheToolboxIndexExistsAndNamesTools() throws {
        let index = try text(Self.indexPath)
        XCTAssertGreaterThan(index.count, 1_000, """
            \(Self.indexPath) ist leer oder fast leer. Diese Datei ist der einzige Ort, an dem \
            steht, WANN man ein Werkzeug holt — ohne sie ist `scripts/` ein `ls`.
            """)
        XCTAssertGreaterThanOrEqual(namedTools(in: index).count, 20, """
            \(Self.indexPath) nennt fast keine Werkzeug-Datei. Entweder ist das Verzeichnis \
            ausgeräumt, oder dieser Scan trifft seine Formatierung nicht mehr — das Zweite ist \
            die Art, wie ein Wächter für immer grün bleibt (#808).
            """)
    }

    // 2 — jedes ausgelieferte Werkzeug ist benannt.
    func testEveryToolInTheFolderIsNamedInTheIndex() throws {
        let index = try text(Self.indexPath)
        let named = namedTools(in: index)
        let tools = shippedTools()
        XCTAssertFalse(tools.isEmpty, """
            ANCHOR MISSING: in `scripts/` liegt kein .py/.sh/.rb. Der Scan liest das falsche \
            Verzeichnis — das ist ein Befund, kein Pass (§4).
            """)
        for tool in tools {
            XCTAssertTrue(named.contains(tool), """
                `scripts/\(tool)` steht in \(Self.indexPath) nicht. Das verbietet das Werkzeug \
                NICHT (#364) — es verlangt die EINE Zeile, die sagt, WANN man es holt. Ohne sie \
                findet es nur, wer sich an es erinnert, und genau dafür existiert diese Datei.
                """)
        }
    }

    // 3 — die Gegenrichtung: kein Eintrag zeigt auf ein Werkzeug, das es nicht mehr gibt.
    //
    // #343 — das ist das Gegengewicht zu Anspruch 2. Ein Verzeichnis, das nur WÄCHST, wird zur
    // Liste gelöschter Werkzeuge, und dann schickt es eine Sitzung an einen Befehl ins Leere —
    // derselbe Defekt, den `doctor --section B` an den Skill-Dateien misst.
    func testTheIndexNamesNoToolThatIsGone() throws {
        let index = try text(Self.indexPath)
        let tools = Set(shippedTools())
        for named in namedTools(in: index).sorted() {
            XCTAssertTrue(tools.contains(named), """
                \(Self.indexPath) nennt `scripts/\(named)`, das es nicht gibt. Ein Verzeichnis, \
                das auf ein gelöschtes Werkzeug zeigt, ist teurer als gar keines: es liest sich \
                wie ein Befehl, den man ausführen kann.
                """)
        }
    }

    // 4 — die Trennung, die den Wert ausmacht: Acht-Satz gegen enge Auslöser.
    //
    // ⚠️ Gepinnt werden die ÜBERSCHRIFTEN-Rollen, nicht ihr Wortlaut — ein Umbenennen der
    // Abschnitte ist erlaubt, solange beide Mengen unterscheidbar bleiben.
    func testTheIndexSeparatesEveryCycleFromOnDemand() throws {
        let index = try text(Self.indexPath)
        XCTAssertTrue(index.contains("DIE ACHT PRÜFER"), """
            \(Self.indexPath) trennt den Acht-Satz nicht mehr ab. Die Trennung IST der Inhalt: \
            wer nicht sieht, welche Werkzeuge jeden Zyklus laufen, fährt entweder alle oder \
            keines.
            """)
        XCTAssertTrue(index.contains("ENGEN AUSLÖSER"), """
            \(Self.indexPath) benennt die Werkzeuge mit engem Auslöser nicht mehr als eigene \
            Gruppe. Genau die sind ohne diese Zeile unsichtbar — das war der Befund von #1359.
            """)
    }

    // 5 — die zwei Werkzeuge, die den Befund erzeugt haben, sind benannt UND haben einen Auslöser.
    //
    // ⛔ DIESER ANSPRUCH IST DIE KORRIGIERTE HÄLFTE. Die erste Fassung des Verzeichnisses zählte
    // `needle-reachability.py` zu dieser Menge; es steht in `Tests/CISmoke/CLAUDE.md` §#808 und
    // gehört nicht dazu. Gepinnt sind deshalb NUR die zwei, die gemessen nirgends standen.
    func testTheTwoUnnamedToolsCarryATrigger() throws {
        let index = try text(Self.indexPath)
        for tool in Self.narrowTriggerTools {
            XCTAssertTrue(index.contains(tool), """
                `\(tool)` fehlt in \(Self.indexPath). Es ist eines der zwei Werkzeuge, die am \
                2026-09-17 in KEINER Anweisungsdatei standen — es hier zu verlieren, stellt \
                genau den Zustand wieder her, gegen den diese Datei geschrieben ist.
                """)
        }
        XCTAssertTrue(index.contains("Sobald ein ⛔-Block"), """
            Der Auslöser von `window-margins.py` ist aus \(Self.indexPath) verschwunden. Der \
            Name allein hilft niemandem — man sucht das Werkzeug ja, WEIL man es nicht kennt.
            """)
        XCTAssertTrue(index.contains("Nach einer Löschung"), """
            Der Auslöser von `doorless-state.py` ist aus \(Self.indexPath) verschwunden. \
            Dasselbe: ohne das WANN ist der Eintrag ein `ls` mit mehr Wörtern.
            """)
    }
}
