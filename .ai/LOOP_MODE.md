# LOOP MODE - Ralph Wiggum Methodology

## Grundprinzip

Iteratives Arbeiten in klar definierten Zyklen. Nie "fertig" nach einem Durchlauf.

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ ANALYZE  │───▶│   PLAN   │───▶│ EXECUTE  │───▶│ VERIFY   │───▶│ IMPROVE  │
│          │    │          │    │          │    │          │    │          │
│ Kontext  │    │ Strategie│    │ Umsetzen │    │ Testen   │    │ Refine   │
│ verstehen│    │ definieren│   │          │    │ prüfen   │    │ iterate  │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └─────┬────┘
      ▲                                                               │
      └───────────────────────────────────────────────────────────────┘
```

## Phase 1: ANALYZE (Laser Eyes)

**Ziel:** Vollständiges Verständnis vor jeder Aktion

- [ ] Bestehendes lesen, nicht raten
- [ ] Abhängigkeiten identifizieren
- [ ] Architektur-Kontext verstehen
- [ ] Edge Cases erkennen

**Output:** Klares Problembild

```markdown
## Analyse
- Betrifft: [Dateien/Module]
- Abhängigkeiten: [Was hängt davon ab]
- Risiken: [Was kann schiefgehen]
- Unklarheiten: [Was muss geklärt werden]
```

## Phase 2: PLAN (Strategie)

**Ziel:** Durchdachter Ansatz vor Code

- [ ] Architekturentscheidungen dokumentieren
- [ ] Reihenfolge festlegen
- [ ] Alternativen abwägen
- [ ] Success Criteria definieren

**Output:** Actionable Plan

```markdown
## Plan
1. [Schritt 1] - [Warum]
2. [Schritt 2] - [Warum]
...
## Success Criteria
- [ ] [Messbares Kriterium 1]
- [ ] [Messbares Kriterium 2]
```

## Phase 3: EXECUTE (Umsetzen)

**Ziel:** Saubere Implementierung

- [ ] Kleinste sinnvolle Einheit
- [ ] Gegen CLAUDE_CODE_MASTER.md prüfen
- [ ] Tests parallel schreiben
- [ ] Dokumentation nicht vergessen

**Regeln:**
- Ein Commit = Ein logischer Change
- Keine "WIP" Commits
- Jeder Change muss buildbar sein

## Phase 4: VERIFY (Prüfen)

**Ziel:** Qualitätssicherung

- [ ] Tests laufen lassen
- [ ] Manuell verifizieren wo nötig
- [ ] Performance prüfen
- [ ] Edge Cases testen

**Checkliste:**
```markdown
- [ ] swift build erfolgreich
- [ ] swift test erfolgreich
- [ ] Keine neuen Warnings
- [ ] Keine force unwraps eingeführt
- [ ] Logger statt print()
- [ ] Dokumentation aktuell
```

## Phase 5: IMPROVE (Verbessern)

**Ziel:** Kontinuierliche Verbesserung

- [ ] Was könnte besser sein?
- [ ] Gibt es Refactoring-Potential?
- [ ] Sind neue Patterns entstanden?
- [ ] Dokumentation für Zukunft

**Output:** Nächste Iteration oder Done

## Bei Unklarheit

**NIEMALS raten!**

Stattdessen:
1. Unklarheit explizit benennen
2. Optionen auflisten
3. Empfehlung geben mit Begründung
4. Architekturentscheidung dokumentieren

```markdown
## Architekturentscheidung: [Titel]

**Kontext:** [Situation]

**Optionen:**
1. [Option A] - Pro: ... / Con: ...
2. [Option B] - Pro: ... / Con: ...

**Entscheidung:** [Gewählte Option]

**Begründung:** [Warum]
```

## Loop-Trigger

Starte neuen Loop wenn:
- Neue Anforderung kommt
- Test fehlschlägt
- Architektur-Problem entdeckt
- Performance-Issue gefunden
- Code Review Feedback

## Aktivierung

Im Chat einfach sagen:

> "Arbeite strikt nach LOOP_MODE.md"

oder

> "Ralph Wiggum Loop Mode aktivieren"
