# HANDOVER — W11 Loop Generator, Core-Scheiben abgegeben (2026-10-29)

**Session:** `01Rs2DgVk6x81mA152aJGL8u`
**Branch:** `claude/music-loop-generator-D1tml`
**Status bei Übergabe:** 6 Commits im Branch, Push 2× (Erst-Push + ein Fix-Commit für einen reinen Linux-Compile-Fehler); Studio-Gate auf dem Fix-SHA läuft beim Schreiben noch, der Erst-SHA hatte den Linux-Compile-Fehler.

---

## Was im Repo liegt

Jeder Commit atomar, mit Attribution. `git log --oneline origin/main..HEAD`:

```
3b3dd0f  fix(core): round before Int cast in VibeParameters.defaultSeed
e25e843  feat(core): Command .generateLoopFromVibe (One-door entry)
85abf50  feat(core): deterministic PatternGenerator for Loop-Generator wave
94cd589  feat(core): VibeMatrix 3x3 grid + VibePromptParser (local keywords)
4b1f80e  feat(core): VibeParameters pure value for Loop-Generator wave
7903d89  docs(w11): plan Loop Generator wave on top of Studio 1.0
```

### Neue Dateien (`EchoelStudio/Core/`)

**Sources:**
- `Vibe/VibeParameters.swift` — pure Werttyp (genre, energy, density, brightness, targetBPM, targetKeyRoot, targetScale, deterministischer `defaultSeed`), Codable/Equatable/Sendable, Door-validiert.
- `Vibe/VibeMatrix.swift` — 3×3 Preset-Grid pro Genre (HipHop, Chill, Score, EDM) mit Zell-Namen (Lo-Fi, Boom Bap, Trap, Ambient, Trip Hop, Drone, Climax, Deep House, DnB …).
- `Vibe/VibePromptParser.swift` — lokaler Keyword-Parser (kein LLM, kein Netz). Erkennt Genre, Energy, Density, Brightness, BPM, Tonart (Sharp + Flat).
- `Vibe/PatternGenerator.swift` — pure Funktion `(VibeParameters, Seed, Role, bars, signature) → [Note]`. Vier Rollen: `.drums`, `.bass`, `.chords`, `.lead`. Deterministisch via `SplitMix64`-PRNG mit Rollen-Salt.

**Command (One-door):**
- `Command.swift` erweitert um `.generateLoopFromVibe(ClipID, vibe:seed:role:bars:)` plus `apply`-Branch (validiert MIDI-Clip, `bars ∈ 1…16`, Note-Door-Validation, trimmt Noten jenseits `clip.length`).
- `CommandCatalog.swift` erweitert um `.generateLoopFromVibe` in `Kind`-Enum, kind-switch und `spec(for:)` (`loop.generate`).

**Tests (`EchoelStudio/Core/Tests/EchoelCoreTests/`):**
- `VibeParametersTests.swift` — 5 Behauptungen (Door-Klamping, Seed-Stabilität, Seed-Divergenz, Pitch-Class-Wrap, BPM-Clamp).
- `VibeMatrixTests.swift` — 5 Behauptungen (9 Cells pro Genre, Cell-Lookup, House-Values, Band-Monotonie, Score=dorian).
- `VibePromptParserTests.swift` — 7 Behauptungen (Vollständig, House-Fallback, nil ohne Genre, Energy/Density-Keywords, Determinismus, Case/Punct, Pitch-Class).
- `PatternGeneratorTests.swift` — 10 Behauptungen (Determinismus, Seed-Divergenz, GM-Drum-Hits, Oktav-Bänder, Chord-Count, Energy→Velocity, Bar-Range, Rollen-Divergenz, SplitMix64).
- `GenerateLoopFromVibeCommandTests.swift` — 7 Behauptungen (Apply-Pfad, Determinismus, Audio-Clip-Verweigerung, bars-Range, Trim, Catalog-Lookup, Kind-Roundtrip).

### Dokumentation

- `scratchpads/PLAN_v11_LOOP_GENERATOR_2026-10-29.md` — Plan: W11 als Welle über `PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md`.
- `scratchpads/HANDOVER_W11_LOOP_GENERATOR_2026-10-29.md` — diese Datei.
- `scratchpads/SESSION_LOG.md` — Session-Eintrag.
- `memory/decisions.md` — Decision „Loop Generator als Welle W11 von Studio 1.0" (Review 2026-11-28).
- `decisions.csv` — Zeile zur Decision.

---

## Vision-Alignment (gemessen)

| Studio-Gesetz | Wie dieser Branch es hält |
|---|---|
| **One door** | Jede Loop-Note erreicht ein Project nur über `.generateLoopFromVibe` → `ProjectStore.perform`. |
| **Format frozen** | Null neues Project-Feld, kein `ProjectCodec`-Pfad berührt, `StoredNamesTests` unverändert (Kind-Namen sind nicht persistiert — CLAUDE.md Zeile zur Catalog-Stabilität gilt und wird eingehalten durch stabile `name`-Werte `loop.generate`). |
| **Validate at the door** | `apply` prüft `clip.audio == nil`, `bars ∈ 1…16`, jede Note geht durch `validate(_:in:)`; non-finite/out-of-range in `VibeParameters.init` schon abgeklemmt. |
| **Render thread** | Nicht berührt — Code generiert Noten offline, kein Audio-Thread-Pfad. |
| **No hot state in view body** | Noch keine UI (W11.2 → Folge-Session). |
| **One presentation slot** | Dito. |
| **Tests test behaviour** | Kein Test liest Quelltext oder Prosa. |
| **Swift 6, no print, no force unwrap** | Eingehalten; Force-Unwrap im ersten Entwurf von `PatternGenerator.chords` beim Verfassen entdeckt und entfernt. |
| **Network only where turned on** | Null Netzkontakt — der Prompt-Parser ist lokal. |

**Authorship-First-Linie** (die zusätzliche Linie dieser Welle, aus Founder-Antwort 2026-10-29): keine Cloud-Generative-AI. Deterministische Lokal-Heuristiken + User-Samples + lokale DSP-Engines. Jede Note ist über Undo reversibel; der User ist alleiniger Urheber.

---

## Was noch offen ist — Folge-Scheiben

Explizit nicht in dieser Session geliefert:

- **W11.2 — UI-Chip + Agent-Tool.** Eine Studio-Chrome-Oberfläche (Panel ODER Agent-Satz), die eine Vibe-Matrix anzeigt bzw. einen Prompt annimmt und `generateLoopFromVibe` baut. Agent-Tool: `AgentTools.swift` erweitern. UI-Panel: separates Scheiben-Design nötig (Modifier-Decke von EchoelStudio prüfen, EchoelValueField für die 3 Slider).
- **W11.3 — Audio-Match-Engine** für importierte Audio-Spuren (BPM/Key-Detection + Time-Stretch). Dafür wird `EchoelDSP` einen `BPMDetector` und `KeyDetector` bekommen. Scope separat.
- **W11.4 — CLAUDE.md-Update.** EchoelStudio/CLAUDE.md bekommt EINEN Satz unter „Laws" oder „Layout", der die Vibe-Dateien benennt und die Authorship-Linie wiederholt. **Nur nach grünem Gate** (Plan §Gates / Risiken).

---

## CI zum Übergabezeitpunkt

- **`e25e843` (W11.1d-Erstpush):** `Echoel Studio (Linux)` rot wegen `Int.rounded()`-Reihenfolgefehler in `VibeParameters.defaultSeed`. Behoben in `3b3dd0f`.
- **`3b3dd0f` (Fix-Push):** `Echoel Studio (Linux)` + `Echoel Studio` (macOS) laufen beim Schreiben noch.

**Auto-Merge-Gate:** `auto-merge-claude.yml` wartet auf `Echoel Studio` (studio.yml) für Studio-Code-Änderungen. Dieser Branch berührt nur `EchoelStudio/Core/`, der Gate ist also `Echoel Studio` (macOS). `Echoel Studio (Linux)` ist informational (CLAUDE.md: „measures and does not block the merge").

**Was ein neuer Session-Owner tut, wenn das Gate rot bleibt:**
1. `python3 scripts/gh-run-status.py` (nach Download der `actions_list`-JSON) auf den aktuellen Branch.
2. Fehlende/falsche Import, Codable-Divergenz oder Swift-6-Konkurrenz nachsehen.
3. Minimal fixen, pushen; **kein Rückbau der Vibe-Scheiben** ohne Founder-Freigabe (die Decision ist dokumentiert).

---

## Attribution (durchgehend)

Jeder Commit endet mit:
```
Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Rs2DgVk6x81mA152aJGL8u
```

Kein PR eröffnet (CLAUDE.md: nur auf expliziten Wunsch). Branch wartet auf das Studio-Gate; Auto-Merge greift automatisch bei grünem Gate und nicht-leerem Diff.

---

## Übergabe-Zustand als eine Zeile

> **Core-Scheiben der Welle W11 im Branch, der Loop-Generator als One-door-Capability live, Format und Audio-Thread unberührt, UI (W11.2) und Audio-Match (W11.3) als nächste Scheiben benannt — alles was eine Folge-Session braucht, steht in diesem Repo.**
