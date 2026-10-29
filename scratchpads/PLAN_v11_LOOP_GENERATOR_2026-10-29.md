# PLAN — Loop Generator als DMMW-Scheibe (2026-10-29)

> **Founder 2026-10-29:** „Ich habe mein Konzept überdacht. Alles soll auf Null gesetzt werden.
> Wir starten neu. Was ich wirklich brauche: Loop Generator für meine Hip Hop / Trap, Chill,
> Score und Electronic/Dance Musik. … Deep Research und Adaptive Thinking für den Sound, aber
> wichtig: Urheber bleibt allein der User. Es gibt einen Sampler, wo man eigene Sounds laden
> und recorden kann, und umfangreiche Engines." Plus: „Alle Apple Plattformen, aber iPhone
> First", Input per Audio oder MIDI, Vibe per Matrix oder Prompt, Multi-Spur, Match-Funktion
> (BPM/Tonart), Stem- oder Summenexport.

Dieser Plan ersetzt **nichts** aus `PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md`. Er fügt eine
**neue Welle W11 „Loop-Generator"** hinzu, die auf **W2 (Modulation)** und **W5 (Klang+/DDSP)**
aufsetzt. Das Produktgesetz („DMMW, own the complete creative workflow") bleibt die Linie — der
Loop-Generator ist eine seiner Kernflächen für Produzent:innen.

## Authorship-First (die eine neue Linie)

Der User bleibt alleiniger Urheber jedes erzeugten Loops. Daraus folgt für diese Welle:

- **Keine Cloud-Generative-AI** (Suno/Udio/MusicGen-API) — würde Urheberschaft verwässern.
- Pattern entstehen aus **lokalen, deterministischen Generatoren** (gleiche Vibe + gleicher
  Seed → identisches Pattern) + **User-eigenen Samples** + **lokalen DSP-Engines**.
- „Deep Research/Adaptive Thinking" bedeutet hier: das System macht **Vorschläge** (Match,
  Vibe-Variation, Rolle-Pattern), aber jede Entscheidung bleibt beim User über die bestehende
  **One-door `ProjectStore.perform`-Kette**.

## Wie das in EchoelStudio reinpasst

EchoelStudio hat zwei nicht-verhandelbare Gesetze:

1. **One door** — alle Projekt-Mutationen gehen durch `Command` + `ProjectStore.perform`.
2. **Format frozen** — ein Songformat-Change ist eine Version-3-Migration mit Golden-Tests.

Der Loop-Generator passt vollständig in diese Form:

- `VibeParameters`, `VibeMatrix`, `VibePromptParser`, `PatternGenerator` = **pure Werttypen** in
  `EchoelCore`, kein Format-Change (sie werden nicht persistiert, sondern erzeugen Noten).
- Ein neuer `Command.generateLoopFromVibe(…)` ruft `PatternGenerator` und übersetzt den Output
  in **bestehende** `addPattern`/`addNote`-Mutationen. Null neue Felder im Project.
- Keine neue UI-Fläche in diesem MVP — die ganze Welle fließt zuerst durch die
  **Agent/CommandCatalog-Tür** (ein Satz vom User → ein Command). UI-Scheibe kommt in W11.2.

## Die Scheiben (jede ≤ 3 Dateien, Gate grün, dann Commit)

| # | Scheibe | Dateien | Gate |
|---|---|---|---|
| **W11.0** | **Dokumentation** | `scratchpads/PLAN_v11_LOOP_GENERATOR_2026-10-29.md` · `decisions.csv` · `scratchpads/SESSION_LOG.md` · `memory/decisions.md` | — |
| **W11.1a** | **VibeParameters** (Core, pure Werttyp) | `EchoelStudio/Core/Sources/EchoelCore/Vibe/VibeParameters.swift` · `.../VibeParametersTests.swift` | `swift test` grün |
| **W11.1b** | **VibeMatrix + VibePromptParser** | `.../Vibe/VibeMatrix.swift` · `.../Vibe/VibePromptParser.swift` · Tests | `swift test` grün |
| **W11.1c** | **PatternGenerator** (deterministisch, pure function) | `.../Vibe/PatternGenerator.swift` · Tests | Determinismus-Test |
| **W11.1d** | **Command `.generateLoopFromVibe`** | `Command.swift` (+ case) · `CommandCatalog.swift` (+ entry) · apply-Pfad · Tests | Projekt-Zustand nach apply |
| **W11.2** (Folge-Session) | **Agent-Tool + UI-Scheibe** | `AgentTools.swift` (+ tool) · ein Chip oder Panel im App-Layer | TestFlight |
| **W11.3** (Folge-Session) | **Match-Engine** (BPM/Key-Angleich) | wenn der Founder Audio-Spuren matchen will — DSP-Pfad | — |

Jede Scheibe W11.1x = ein eigener Commit, atomar.

## Was diese Session liefert (W11.0 + W11.1a–d)

- 4 Commits auf `claude/music-loop-generator-D1tml` (Dokumentation + 4 Core-Scheiben).
- Jede Datei pure Swift, `EchoelCore`-only, keine Audio-Thread-Pfade, keine neuen Abhängigkeiten.
- Jeder Commit mit `Co-Authored-By: Claude Opus 4.7` + `Claude-Session:`-Zeile.
- Push mit Retry-Backoff.
- Kein PR (CLAUDE.md: nur auf expliziten Wunsch).
- Session-End: `memory/decisions.md` · `decisions.csv` · `scratchpads/SESSION_LOG.md`
  aktualisiert.

## Nicht in dieser Session (ehrlich benannt)

- Kein App-UI-Chip, kein neues `.sheet`. Die Modifier-Decke der Legacy-App betrifft diese
  Welle nicht (EchoelStudio hat eigene View-Struktur), aber ein neues Panel ist W11.2.
- Kein Mikrofon-Rückbau. Audio-Eingang war in Studio nie weg (W1 kommt), aber eine
  Audio→MIDI-Transkription ist W11.3.
- Keine Audio-Match-Engine. Pattern aus Vibe erzeugen reicht als Fundament; das Matchen
  importierter Audio-Spuren ist W11.3.
- Kein Format-Change. Alle generierten Noten gehen durch bestehende `addNote`-Mutationen.

## Gates / Risiken

- **Blocking-Bundle**: `Tests/CISmoke` ist das zweite Gate. Für diese Core-Scheiben baue ich
  parallel Wächter nach Sentence-Case-Konvention (`TheXDoesYTests.testTheXDoesY`).
- **Format-Golden**: NICHT berührt — kein Projekt-Feld wird neu persistiert. Pattern werden in
  bestehende `Note`-Shapes übersetzt.
- **CLAUDE.md-Update**: EchoelStudio/CLAUDE.md bekommt nach grünem Build einen W11-Satz. Die
  Legacy-Root-CLAUDE.md bleibt unberührt (betrifft `Sources/Echoelmusic`, nicht Studio).

## Attribution (jeder Commit)

```
Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Rs2DgVk6x81mA152aJGL8u
```
