# ADR-008 — Stem-Capture-Strategie: Echtzeit-Mitschnitt vs. deterministische Offline-Neuberechnung

- **Status:** **Accepted** (2026-10-04) für G-A … G-C, nach der Empfehlung der Tabelle unten. Der Founder hat alle Entscheidungen übertragen („Du machst und entscheidest alles“). **G-D bleibt offen**, weil es Gerätezeit des Founders ist. S-A3 beginnt erst, wenn S-A1 und S-A2 grün sind.
- **Datum:** 2026-10-04
- **Kontext:** Founder-Prompt „SPATIAL MIX SOVEREIGNTY v1.0“, L2 R5 / L5 S-A3. Belege: `docs/research/SPATIAL_MIX_RESEARCH.md` §5. CLAUDE.md überstimmt.

## Problem

Ein bio-reaktiver Take ist **nicht wiederholbar**: Der Körper spielt ihn genau einmal. Ein Immersive-Master braucht aber pro Quelle eine eigene Spur, und zwar sample-genau zueinander und so lang wie der Stereo-Master.

Dafür gibt es zwei Wege:
- **(A) Echtzeit-Mitschnitt.** Alle Stems werden in dem einen Durchgang mitgeschrieben, in dem der Take spielt.
- **(B) Offline-Neuberechnung.** Der Take wird aus Seed und aufgezeichneten Bio-Frames schneller als Echtzeit neu gerendert, im Manual Rendering Mode.

## Entscheidung (vorgeschlagen)

**(A) Echtzeit-Mitschnitt in EINEM Durchgang. (B) ist heute ABGELEHNT**, mit Beleg und einer Bedingung für die Wiedervorlage.

### Warum (B) heute nicht geht (gemessen, Research §5)

Jede der folgenden Ursachen allein bricht die Bit-Gleichheit:

- **Der Sequencer-Takt hängt an der Systemzeit, nicht an Samples.** Er ist ein `DispatchSourceTimer` auf der Main Queue (`Sequencer/PatternEngine.swift:5,21`, „W2 will replace the Timer…“).
- **Die Notenlage ist ein Wettlauf zwischen Main und Render.** Noten werden am Anfang eines Render-Blocks ohne Sample-Offset abgeholt (`PolySynthVoice`, `drainNoteCommands`).
- **Mehrere Entscheidungen fallen nach Wanduhr:**
  - die Re-Seed-Zeitpunkte (Evolve 25–45 s, `Date()` plus Sleep),
  - die Veralterung eines Frames (`usableBio()` liest `CFAbsoluteTimeGetCurrent()`),
  - der Zeitschritt des FX-Bio-Moduls (`systemUptime`),
  - der 100-ms-Poll der Bio-Events.
- **Es gibt verborgene oder externe Eingänge:**
  - `UInt64.random`-Fallback-Seed,
  - Performer-Signatur-Salz in UserDefaults,
  - Live-WeatherKit-Salz,
  - „Randomize patch“,
  - Live-MIDI.
- **Die Sample-Rate hängt an der Audio-Route.**

**Wiedervorlage**, sobald W2 (sample-genaues Noten- und Parameter-Scheduling) gebaut ist **und** jede `generate()`-Eingabe samt Seeds, Salzen und Tick → Sample → Frame-Zuordnung mitgeloggt wird. Selbst dann ist die Bit-Stabilität von vDSP über Geräte und OS-Versionen hinweg offen. (B) wäre dann ein *zusätzlicher* Weg, z. B. für einen sauberen Re-Render in höherer Rate, nie der einzige.

### Wie (A) gebaut wird (Architektur, noch kein Code)

1. **Eine Engine, eine Uhr.** Alle Stems laufen in der bestehenden Master-Engine mit, eine zweite gibt es nicht.
   - Innerhalb einer Engine teilen alle Knoten einen Sample-Zeitstrahl, also gibt es keine Drift (LIKELY, Research §5).
   - Ausgerichtet wird über `AVAudioTime.sampleTime`, **nie** über Chunk-Grenzen. Die Tap-Puffergröße ist nicht garantiert.
2. **Generierte Stimmen** (`PolySynthVoice`, `SubBassVoice`, `BioReactiveSynthVoice`): Sie werden **im eigenen Render-Block** mitgeschnitten. Jede Stimme rendert schon in eigene Scratch-Puffer.
   - Neu ist eine Kopie in einen **vorallokierten lock-freien SPSC-Ring** pro Stimme.
   - Im Render-Pfad: keine Allokation, kein Lock, kein I/O, kein ObjC (CLAUDE.md Audio-Thread-Gesetz).
   - Damit ist der Mitschnitt sample-genau per Konstruktion und braucht **keinen Tap**.
3. **Audiospuren** (`AVAudioPlayerNode` über `TimelineAudioSink`): Sie haben keinen eigenen Render-Block. Jede Spur hat aber einen eigenen Knoten, also ist **ein Tap pro Spur** erlaubt, denn die Regel lautet ein Tap pro *Bus*.
   - Der Tap-Block kopiert in den Ring der Spur.
   - Die Ausrichtung läuft über `when.sampleTime`.
   - Abgegriffen wird **vor** dem HRTF-Bus. Der Stem ist trocken und mono; der Raum entsteht im Studio aus der Trajektorie.
4. **Ein Schreiber-Thread** außerhalb des Render-Pfads leert alle Ringe und schreibt PCM 48 kHz / 24 bit. Das ist dasselbe Muster wie RetroCapture seit #1413: Disk-I/O nie im Tap-Callback.
5. **Gleiche Länge, gleicher Nullpunkt.**
   - Start und Ende werden für alle Stems an derselben Sample-Zeit geschnitten.
   - Fehlende Anfänge werden mit Stille aufgefüllt, nie verschoben.
   - **Der Stereo-Master entsteht im selben Durchgang wie heute** (RetroCapture auf `mainMixerNode`) und ist damit gleich lang.
6. **Trajektorie im selben Durchgang (S-A2).** Positionen aus `SpatialSceneStore` werden mit **derselben Sample-Zeit** gestempelt, nicht mit `Date()`. Aufgezeichnet wird mit 20 Hz; das Ausdünnen läuft beim Export.
7. **Hinter einer Flagge**, Release-Default AUS. Die Flagge bekommt **im selben Commit ihren Leser**, sonst wäre es die elfte Flagge ohne Leser.

### Beweis (L6, je Scheibe)

- **Ausrichtungstest:** Ein Impuls auf Takt 1 landet in **jedem** Stem auf demselben Sample. Alle Stems sind gleich lang.
- **Zero-Alloc-Nachweis** im Render-Pfad, Review durch den `audio-thread-reviewer`, Tests zuerst durch den `tdd-agent`.
- **CPU:** Mit eingeschalteter Flagge bleibt die App innerhalb des Hard-Limits (< 30 %). Der Mitschnitt wird nicht zum bisherigen Verbrauch dazugerechnet, sondern das Gesamtergebnis zählt.
- **Speicher:** Ring pro Stem ≈ 2 s bei 48 kHz × 4 B ≈ 384 KB. Bei 16 Stems sind das ≈ 6 MB, innerhalb des 200-MB-Ziels.
- **Gerät (Founder):** ein Stück mit 4+ Spuren aufnehmen und die Stems in einer DAW nebeneinander legen. Sie müssen phasengleich sein.

## Konsequenzen

- **Positiv:**
  - Jeder Take ist exportierbar, auch der unwiederholbare.
  - Keine zweite Engine, kein Manual Rendering.
  - Der Stereo-Master und die Stems stammen aus demselben Moment.
- **Negativ:**
  - Ein Export dauert so lange wie das Stück. Das ist schon heute so, denn „Piece (WAV)“ spielt das Stück einmal ab.
  - Speicherbedarf auf der Platte: 16 Stems sind ≈ 8,3 GB/h.
  - **Laut Apple ist ein Tap-Block keine Echtzeit-Garantie.** Ob ein langsamer Schreiber Puffer verliert, ist offen. Der Ring muss das messen und melden, nie still verlieren.

## Entscheidung zu Gate R (2026-10-04)

- **G-A:** (A) Echtzeit-Mitschnitt ist der einzige Weg für v1. (B) wird erst nach W2 neu bewertet.
- **G-B:** Stems **mit** Spur-Effekten, **ohne** Master-Kette, Limiter und HRTF.
- **G-C:** Jede generierte Stimme wird ein eigener Stem. Für den ADM-Master v1 werden sie zum Stereo-Bett summiert (ADR-007 F-B).
- **G-D:** offen (Gerät und Stück wählt der Founder).

## Fragen an den Founder (Gate R) — die ursprüngliche Vorlage

| # | Frage | Empfehlung | Warum es deine Entscheidung ist |
|---|---|---|---|
| **G-A** | (A) Echtzeit-Mitschnitt als einziger Weg für v1, (B) erst nach W2? | **Ja** | Bestimmt, ob W2 (sample-genauer Sequencer) vorgezogen wird |
| **G-B** | Stems **trocken und vor dem Master** (ohne FX-Kette des Masters, ohne Limiter, ohne HRTF), oder **mit** den Spur-Effekten? | **Mit Spur-Effekten, ohne Master-Kette.** So klingt die Spur wie im Stück, und der Mix bleibt beim Studio | Klangliche Übergabe |
| **G-C** | Generierte Stimmen als **eine** Stereo-Bett-Datei, oder jede Stimme als eigener Stem? | **Jede Stimme ein eigener Stem** (Synth, Bass, Body). Für ADR-007 v1 werden sie zum Stereo-Bett summiert | Wie viel Einzelkontrolle das Studio bekommt |
| **G-D** | Welches Gerät und welches Stück nimmst du für den ersten Ausrichtungstest (S-A3)? | Ein Stück mit 4+ Audiospuren, Kopfhörer-Raum an | Gerätezeit gehört dir |
