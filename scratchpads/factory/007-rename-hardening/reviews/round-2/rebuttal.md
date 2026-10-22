# Runde 2 — Antwort des PM

Runde 2 (`wf_864aabbe-500`, `4c4bd5ad8..2e7f68ca0`, Nacharbeit seit `5942df4fd`) gab frei: vier
Linsen PASS, alle neun Befunde aus Runde 1 am Kopf bestätigt behoben, CI grün (Echoel Studio
`39824850887`, Linux `39824850931`). Drei neue Minors, jeder nachgemessen; alle drei gehen in
Nacharbeit 2, Runde 3 ist die letzte.

| # | Linse | Befund | Antwort |
|---|---|---|---|
| 1 | code m1 | Der Doc-Kommentar von `stemByteLimit` nennt den Zwischennamen klein („ renaming 1a2b3c4d“), den `isBetweenStem` jetzt ablehnt | **Eingearbeitet.** „ renaming 1A2B3C4D“. Das Byte-Budget ist gleich (Hex ist ein Byte in beiden Schreibweisen). |
| 2 | ux m1 | „Echoel tries again when it next saves“ hat kein Objekt und kann in der roten Zeile wie ein gescheitertes Speichern gelesen werden | **Eingearbeitet** mit eigenem Wortlaut statt des vorgeschlagenen („is still called“ wäre für das gestrandete Paket falsch, dessen Name gerade NEU ist): „Only the file lags behind: in the Files app the song is called X for now, and Echoel tries to rename it when it next saves.“ Wahr nach einer Umbenennung, nach Undo und beim Öffnen aus einem Zwischennamen. Spec A5 nachgeführt. |
| 3 | ux m2 | Mit „Hinweise sprechen“ aus hört ein VoiceOver-Nutzer die verborgene Zeile nicht | **Als Messung ins Gerät-Kriterium 6 aufgenommen**, nicht vorab umgebaut: die Ansage ist kein Hinweis und kommt auch dann; ob der Grund für das gedimmte „Rename“ fehlt, sagt nur das Gerät. Fehlt er, wird die Zeile wieder ein Element und der doppelte Feld-Hinweis geht. |
