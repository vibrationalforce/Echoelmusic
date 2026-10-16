# Externe Prüf-Aufträge — SuperGrok Heavy · ChatGPT (2026-10-16 → 2026-11-06)

Founder 2026-10-16: „Schreib in den kommenden 3 Wochen immer wieder zwischendurch Aufträge um
supergrok Heavy und ChatGPT nach Feedback und aktuellen Entwicklungen zu fragen. So können wir
sicherstellen, dass wir unseren Plan verfolgen Echoelmusic wirklich nutzbar zu machen."

**Ablauf:** Montags und donnerstags schreibt die Sitzung hier eine neue Runde (je ein Auftrag pro
Modell, zugeschnitten auf das, was seit der letzten Runde gebaut wurde). Der Founder kopiert den
Auftrag in SuperGrok Heavy bzw. ChatGPT und fügt die Antwort hier im Chat ein. Die Antwort läuft
durch den Lernmodus (`.claude/skills/learn-mode/SKILL.md`): gesäubert, jede Behauptung gemessen,
einmal geloggt (`inspiration.csv`, `memory/inspiration_intake.md`), dann Verdikt.

**Was rausgeht (Lernmodus „Was RAUSGEHT"):** die öffentliche Repo-URL, der Zweig, Dateipfade und
Auszüge GETRACKTER Dateien. Nie: `.claude/settings.local.json`, Diagnose-Logs (Puls/Atem =
Gesundheitsdaten), App-Store-Schlüssel, Tester-Feedback, Geräte-Logs echter Nutzer.

**Rolle der fremden Modelle:** PRÜFER, nie Bauer. Höchstens 8 Punkte, jeder mit Datei und Zeile
oder Quelle mit Datum, je „sicher" oder „vermutet", kein Code. Die Bilanz je Quelle:
`python3 -I scripts/learn-intake.py --tally`.

---

## Runde 1 — Donnerstag, 16.10.2026 (Stand `39f954d`)

### Auftrag an SuperGrok Heavy — aktuelle Entwicklungen

```
Rolle: externer Prüfer für Echoelmusic, ein iPhone-first Musik- und Multimedia-Instrument
(Swift, null externe Abhängigkeiten, alles auf dem Gerät). Öffentliches Repo:
https://github.com/vibrationalforce/Echoelmusic — Zweig claude/echoelmusic-review-optimize-u5jjpd.

Wir bauen gerade eine Assistenz-Schicht: Eine Bitte in eigenen Worten ("make the selected track
3 dB quieter") geht an Apples On-Device-Sprachmodell (Foundation Models). Das Modell darf nur
VORSCHLAGEN — höchstens 3 Schritte aus 3 erlaubten Befehlen (Stück beschreiben, Spurlautstärke,
Teil kopieren). Erst ein Tap auf "Apply" ändert das Stück; Undo nimmt es zurück; ändert sich die
Auswahl vorher, wird abgewiesen. Zugang heute nur über Siri/Kurzbefehle ("Ask Echoelmusic").
Dateien: Sources/Echoelmusic/EchoelAI/EchoelModelPlanner.swift,
Sources/Echoelmusic/EchoelAI/EchoelAgentDesk.swift, Sources/Echoelmusic/Studio/EchoelAppIntents.swift.

Bitte recherchiere die AKTUELLEN Entwicklungen der letzten 4 Wochen (Stand heute), nur mit Quelle
und Datum:
1. Apple Foundation Models / Apple Intelligence: Änderungen an Verfügbarkeit, Kontextgröße,
   Guided Generation, Tool Calling, Latenz auf iPhone — und was davon für "Vorschlag statt
   Ausführung" relevant ist.
2. App Intents / Siri: Wie lange wartet Siri auf ein perform(), das ein On-Device-Modell
   aufruft (Sekunden)? Gibt es neue Muster für "Ergebnis in der App bestätigen"?
3. Musik-Software mit Sprach-/Agenten-Bedienung (Logic, Ableton, Bitwig, BandLab, neue Startups):
   was ist wirklich ausgeliefert, was ist Ankündigung?
4. On-Device-Musikgenerierung (symbolisch/MIDI) auf Apple-Hardware: neue Modelle mit Lizenz,
   Größe, Latenz.

Form: höchstens 8 Punkte. Jeder Punkt: Behauptung · Quelle (URL) · Datum · "sicher" oder
"vermutet" · was das für Echoelmusic konkret heißt. Keine Code-Vorschläge. Gerüchte als
Gerüchte kennzeichnen.
```

### Auftrag an ChatGPT — Nutzbarkeit des neuen Ablaufs

```
Rolle: externer UX- und Workflow-Prüfer für Echoelmusic (iPhone-Musik-Instrument, Swift).
Öffentliches Repo: https://github.com/vibrationalforce/Echoelmusic —
Zweig claude/echoelmusic-review-optimize-u5jjpd, Stand 39f954d.

Lies nur diese Dateien:
- Sources/Echoelmusic/EchoelAI/EchoelAgentDesk.swift (proposePlan, applyProposal,
  discardProposal, proposalSentence)
- Sources/Echoelmusic/Studio/AgentReportBanner.swift (die Zeile mit Apply / Discard / Stop / Undo)
- Sources/Echoelmusic/Studio/EchoelAppIntents.swift (AskEchoelIntent)
- docs/dev/FEATURE_STATUS.md §1b (was gebaut, aber noch nicht ausgeliefert ist)

Ablauf, den wir abnehmen wollen: Absicht sagen → Vorschlag oder Rückfrage → Apply →
normales, bearbeitbares Ergebnis im Stück → Undo.

Fragen:
1. Versteht ein Musiker VOR dem Apply, was sich ändert? Ist der Satz
   "Echoel would make Keys 3.0 dB quieter. Nothing changes until you tap Apply." klar genug?
2. Wo kann der Ablauf hängen bleiben (Siri wartet, App im Hintergrund, Auswahl gewechselt,
   anderes Stück geöffnet)? Nenne Datei und Zeile.
3. Was fehlt, damit das im Alltag einer Produktion wirklich benutzt wird — ohne neues Fenster,
   ohne neuen Chat-Bereich?
4. Welche zwei Gerätetests würdest du als erstes machen, und was genau soll man sehen?

Form: höchstens 8 Punkte, je Datei:Zeile, "sicher" oder "vermutet", kein Code.
```

**Antworten:** _(hier im Chat einfügen; die Sitzung loggt sie im Lernmodus)_
