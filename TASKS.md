# TASKS.md — Vorlage für eine Feature-Sitzung nach PRD (gegen Context Rot)

**Eine Vorlage, kein Board.** Eine Sitzung, die ein Feature über viele Scheiben baut, kopiert den Block unten nach
`echoelmusic-intern/scratchpads/tasks/<JJJJ-MM-TT>-<thema>.md` (privat: Pläne, Gründe und Founder-Worte gehören nicht
in dieses öffentliche Repo) und führt ihn dort. Das Board (`scratchpads/BAUSTELLEN_BOARD.md`, privat) bleibt die eine
Warteschlange; diese Datei ist das Arbeitsheft EINES Features darin.

## Wie die Datei Context Rot verhindert

1. **Zustand auf Platte, nicht im Kopf.** Nach jeder Scheibe wird der Kopf der Datei (Stand, nächste Scheibe, offene
   Messung) neu geschrieben und gepusht. Nach einer Komprimierung oder in einer neuen Sitzung ist er das Erste, was
   gelesen wird — vor jeder Erinnerung.
2. **Eine Scheibe in Arbeit.** Genau eine Zeile trägt `in Arbeit`; die nächste wird erst gezogen, wenn ihre CI gelesen ist.
3. **Jede Scheibe ist ein Commit mit Test** und nennt ihren Prüfweg: welcher CI-Schritt, welcher Test, welche
   Geräte-Frage. „Grün kompiliert“ ist nicht „am Gerät geprüft“.
4. **Messen, nicht erinnern.** Jede Zahl im Heft steht mit dem Befehl, der sie ergab.
5. **Funde einer Gegenlesung werden eigene Zeilen** (`-R` an der Kennung), nie still in die laufende Scheibe gemischt.

## Vorlage

```markdown
# <Thema> — Arbeitsheft (Start <UTC>)

## Kopf (nach jeder Scheibe neu schreiben)
- Stand: <letzte grüne Scheibe, sha, CI-Lauf>
- In Arbeit: <Kennung> seit <UTC> auf <Zweig>
- Nächste: <Kennung>
- Offen beim Founder: <nur was eine Regel nicht entscheiden kann; einmal in der Inbox>

## PRD
- Ziel (ein Satz, aus der Sicht der Musikerin):
- Quelle: <Founder-Chat Datum | WEEKLY.md Schritt 5 | Board-Zeile> — ohne Quelle kein Scope
- Muss: <Abnahmekriterien als prüfbare Sätze>
- Nicht: <was ausdrücklich nicht gebaut wird>
- Gesetze, die es berührt: <Law-Nummern aus EchoelStudio/CLAUDE.md; Render-Thread? Song-Format? Netz? Sprache?>
- Was nach außen gesagt werden darf: <nichts, bis es ausgeliefert ist (ContentPipeline/CLAIMS.md)>

## Scheiben
| Kennung | Was (ein Commit) | Test zuerst | Prüfweg | Status |
|---|---|---|---|---|
| X-1 | reine Regel in Core | <Testname, heute rot> | CI „Test (macOS host)“ | offen |
| X-2 | Anschluss in App/ | – (App hat kein Testziel) | CI Build + Start-Smoke; Geräte-Frage | offen |

## Messungen
| Was | Befehl | Ergebnis | Zeit |
|---|---|---|---|

## Gegenlesungen
| Scheibe | Linsen | bestätigt / widerlegt | Funde als Zeilen |
|---|---|---|---|
```

## Der Takt einer Scheibe

1. Kopf lesen. Board-Anspruch schreiben und pushen (`in Arbeit <zweig> seit <UTC>`).
2. Test zuerst (Core, DSP, Engine: ein Verhaltenstest, der heute rot ist; App: die Regel in Core ziehen).
3. Code. Der Hook `.claude/hooks/verify-after-edit.py` prüft jede Datei beim Speichern.
4. Commit (eine Sache, Conventional Commit, Begründung im Text, nichts Privates), Push.
5. CI-Lauf auf genau diesem Commit lesen (`Echoel Studio`, Schritte einzeln). Rot ist die einzige Arbeit.
6. Gegenlesung für Render-Pfad, Sicherheit, Format oder sichtbare Texte; Funde als `-R`-Zeilen.
7. Kopf neu schreiben, Board-Status mit Zeit, SESSION_LOG — dann erst die nächste Scheibe.
