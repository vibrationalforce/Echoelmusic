# Runde 1 — Antwort des PM

Runde 1 (`wf_f738a9cc-f68`, `4c4bd5ad8..5942df4fd`) gab frei: vier Linsen PASS, der Approver
benotete alle sieben Kriterien, CI grün auf dem Kopf (Echoel Studio `39822259909`, Linux
`39822259249`; Core 289 Tests ohne Fehler, die vier neuen Wächter namentlich bestanden). Die neun
Minor-Befunde blockieren nicht. Sieben davon sind billig und richtig, deshalb eine Nacharbeit mit
Runde 2 statt eines dritten Jobs. Jeder Befund wurde am Code nachgemessen.

| # | Linse | Befund | Antwort |
|---|---|---|---|
| 1 | code m1 | Nach einem Strand und einem gescheiterten Folgeversuch wechselt der Satz („is called“ → „keeps the name“), obwohl die Datei am selben Ort liegt | **Eingearbeitet.** EIN Satz, der nur den Ort nennt („In the Files app the song is called X for now; Echoel tries again when it next saves.“); der `moved`-Parameter ist entfallen. Der Satz ändert sich jetzt genau mit dem Ort. |
| 2 | code m2 | `isBetweenStem` nimmt auch Kleinbuchstaben, `betweenStem` schreibt nur große | **Eingearbeitet.** Nur `0-9A-F`; `betweenStem` schreibt mit `.uppercased()`, damit Schreiber und Leser auf jeder Plattform übereinstimmen. Neuer Negativfall `beat renaming 1a2b3c4d` im Wächter. |
| 3 | security m1 | Der Wächter stubbt den Rückweg; dass der echte Umzug einen belegten LEEREN Ordner verweigert, prüft er nicht (POSIX `rename(2)` ersetzt einen leeren Ordner) | **Eingearbeitet.** Nur Schritt 2 ist erfunden; Schritt 1 und der Rückweg sind echte `FileManager.moveItem`. Verweigert der Umzug den belegten Ordner nicht, ist der Wächter rot — auf jeder Plattform, auf der er läuft. |
| 4 | ux m1 | Der Einmal-Wächter vergleicht den Satz, nicht den Ort | **Eingearbeitet** mit 1: mit einem einzigen Satz IST der Satz der Ort. |
| 5 | ux m2 | Beide Sätze beginnen mit „The song is renamed“, auch nach Undo und beim Öffnen aus einem Zwischennamen | **Eingearbeitet** mit 1: kein „renamed“ mehr. |
| 6 | ux m3 | Die Ansage hat Standard-Priorität und kann vom Echo der Taste überdeckt werden | **Eingearbeitet.** `AttributedString` mit `accessibilitySpeechAnnouncementPriority = .high` (WWDC23-Form, iOS 17+ unter dem Boden iOS 18). Gerät-Kriterium 6 bleibt die Probe. |
| 7 | ux m4 | Die Zeile unter dem Feld wird doppelt gelesen (Hinweis und statischer Text) | **Eingearbeitet.** `.accessibilityHidden(true)` an der Zeile. |
| 8 | ui-state m1 | wie 6 | **Eingearbeitet** mit 6. |
| 9 | ui-state m2 | Beim Öffnen aus einem Zwischennamen meldet die Zeile ein Umbenennen, das niemand machte | **Eingearbeitet** mit 1. |

Spec nachgeführt: A4 (Großbuchstaben), A5 (ein Satz), A8 (Priorität, verborgene Zeile), Kriterien
1, 2, 4, 5. Nicht gelaufen vor dem Push (keine Swift-Toolchain); ob
`accessibilitySpeechAnnouncementPriority` mit `import SwiftUI` kompiliert, zeigt der App-Build.
