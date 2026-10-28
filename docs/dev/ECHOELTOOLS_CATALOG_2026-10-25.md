# EchoelTools-Katalog — was die alte App hatte und was davon in Echoel Studio 1.0 kommt (2026-10-25/28)

> **Founder 2026-10-25:** „Alle alten Features geschickt in die Studio Umgebung implementieren, die alten
> EchoelTools aus der history nochmal prüfen und vorlegen … Video-Aufnahme und -Schnitt, Harmonizer,
> Granular und Autotune sowie Gesicht und Bewegung. Und die ganze on Device generative Super Inteligence.“
> Plan dazu: `scratchpads/PLAN_ONE_POINT_ZERO_COMPLETE_2026-10-25.md` (Wellen W1–W10).

**Wie gemessen.** Vier Leser haben getrennt gesucht: Instrumente, Effekte, Video/Gesicht/Bewegung und KI.
Sie haben `docs/dev/HISTORY_ARCHIVE.md`, die Grabstein-Kommentare und den lebenden Code gelesen.
Danach habe ich selbst geprüft, ob jede gelöschte Quelle in der History noch lesbar ist. Bei allen acht ist
sie es (Zeilenzahl vor der Löschung): Harmonizer 139, Granular 349, Tonhöhenkorrektur 287,
Phase-Vocoder 481, alter Synth 969, alter Bass 906, Gesichtsquelle 614, Video-Recorder 285.
**Spalte „lief“:** J = klang oder lief in der alten App, N = nie kompiliert oder nie erreichbar,
? = nicht belegt. Nichts davon ist auf einem Gerät mit Studio geprüft.

## Drei Grundregeln für jede Portierung

1. **Den Kern portieren, nie das alte Subsystem.** Die Mathematik kommt in Studios eigene Besitzer, also
   EchoelDSP, die Kernels und die Befehlstür. Besitz, UI und Speicherung der alten App kommen nicht mit.
2. **Studio-DSP kennt kein Accelerate.** Alle 14 DSP-Dateien importieren nur Foundation. Jeder alte
   vDSP-Kern wird deshalb in einfache Schleifen umgeschrieben und nicht kopiert. Das gilt für FFT,
   Modalbank, Hall und WSOLA.
3. **Auf dem Render-Thread wird nichts allokiert.** Mehrere alte Kerne allokieren beim Aufruf, zum Beispiel
   `morphMaterials`, `PitchTracker.detect` und `EchoelSpaceReverb.process`. Sie werden vorher zu
   vorallokierten Werttypen.

## A · Instrumente (Studio heute: Synth mit 4 Wellenformen, Drums mit 8 Teilen, Sampler)

| # | Instrument | Klang | lief | Weg nach Studio | Größe |
|---|---|---|---|---|---|
| A1 | **Supersaw / Unison** | breite, verstimmte Leads und Pads | J | neue Engine-Wahl im Studio-Synth | S |
| A2 | **Moog-Ladder + 303-Slide/Accent** | fetter Bass, Acid-Linien | J | Ladder als Filtermodus in EchoelDSP; Slide/Accent als Patch-Felder | M |
| A3 | **808-Glide-Bass / Reese** | lang gleitender Bass | J | Presets auf A1/A2 plus Kick mit Tonhöhe | M |
| A4 | **2-Operator-FM** | Glocken, E-Piano, metallischer Bass | J | Engine-Wahl im Synth | S |
| A5 | **Modalbank** (Glocke, Platte, Stab, Glas, Gong) | angeschlagene Objekte | J (als Pads bis #166) | eigenes Gerät „Mallets“ | M |
| A6 | **Karplus-Strong** | gezupfte Saiten | J | Engine-Wahl im Synth | S |
| A7 | **Wavetable (8 Formen)** | digitale Klangmorphs | J | Engine-Wahl; Tabellen beim Start bauen | M |
| A8 | **Sub-Oktave mit Presence/Heat** | Sub-Layer | J | Layer im Synth | S |
| A9 | **Harmonic-plus-noise (DDSP)**, sechs Timbres | Geige, Flöte, Trompete u. a. | J | viertes eingebautes Instrument (W5) | L |
| A10 | **Zellulärer Automat** (Regeln 30/90/110/184, Life) | sich entwickelnde Texturen | J (nur im alten AUv3) | Gerät „Texture“ | M |
| A11 | Drum-Ausbau (808-Hihat, Kick-Glide, modale Toms) | dichtere Drums | J | `DrumKit` erweitern | M |
| A12 | Euklidische Rhythmen | Muster-Werkzeug, keine Stimme | J | Schritt-Befehl in EchoelCore, nur auf Anfrage | S |

**Schon abgedeckt:** der One-Shot-Sampler (Studio-`Sampler` mit `oneShot`).
**Später:** das GM-Soundfont mit 31 MB (erst Lizenz prüfen).
**Nicht portieren:** Schrödinger-Synthese als „Quantum“, die nie kompilierte C++/JUCE-Suite, die
„alle Instrumente der Welt“-Bibliothek, die nie klang.

## B · Effekte (Studio heute: EQ, Kompressor, Delay, Hall als FDN mit 8 Leitungen)

| # | Effekt | lief | Weg nach Studio | Größe |
|---|---|---|---|---|
| B1 | **Phase-Vocoder mit Formant** | J (kompiliert, nicht erreichbar) | Kernel, der B2, B3 und das Time-Stretching trägt. Braucht eine FFT ohne Accelerate | L |
| B2 | **Harmonizer**: 2 Stimmen, 15 benannte Intervalle, Zwei-Tap-Pitch-Shifter | J | zuerst als Live-Insert im Zeitbereich; die Formant-Version folgt nach B1 | M |
| B3 | **Tonhöhenkorrektur („Autotune“)**: YIN, dann Einrasten auf die Skala | J (nur Monitor) | **zuerst offline je Clip**, live am Eingang erst, wenn die Latenz auf dem Gerät gemessen ist | L |
| B4 | **Granular „Echoel Grain“** | J. Der Kern `GrainCloud` ist Foundation-only und lebt noch | zuerst als Offline-Bake am Clip (`GrainBake` hat diese Form), live später | S/M |
| B5 | Chorus, Flanger, Phaser, Tremolo | J | 4 Standardeffekte mehr, Foundation-only | S je |
| B6 | Tape, Bitcrusher, Stereo-Breite | J | Standardeffekte | S |
| B7 | Sättigung + Klangfilter | J | Standardeffekt | S |
| B8 | Limiter | J | fünfter Standardeffekt | S |
| B9 | Ringmodulator, Frequenzschieber, Formantfilter | N (nie Audio) | AUv3, später | S–M |
| B10 | Multiband, M/S, Transient Designer, dynamischer EQ | N | später | M je |

**Kommt nicht wieder:** die 34 Namen, die auf nur 4 Prozessoren abgebildet waren; die
„Healer“-Rahmung; Markennamen-Emulationen; der falsche True-Peak; der umgebaute Monitor-Graph der alten
Tonhöhenkorrektur. Er war die Quelle von fünf SIGABRT-Abstürzen. Die Lehre: **die Tonhöhenstufe
hängt fest im Graphen und wird nur umgangen, nie neu verdrahtet.**

## C · Video, Gesicht, Bewegung

**Korrektur zu meinem Plan:** Die Video-Aufnahme wurde in der alten App am **2026-10-15 neu gebaut**, also
nach der Streichung #1304. Diese Dateien leben noch: `Video/VideoTakeCamera.swift`, `VideoTakeLedger.swift`,
`Sequencer/VideoImport.swift`, `VideoLanePlayer.swift` und sieben Wächter. **Das ist die beste Quelle**,
nicht die gelöschten Dateien von #1304. Sie ist auf keinem Gerät geprüft. Einen Bildexport gibt es auch
dort nicht, nur M4A.

| # | Fähigkeit | lief | Weg nach Studio | Größe |
|---|---|---|---|---|
| C1 | Video-Spur im Song | — | **Format-Version-Sprung**: `"kind":"video"` wird heute absichtlich abgelehnt (Golden-Test) | M |
| C2 | Video importieren und auf Takte legen | ? | reine Teile von `VideoImport`/`VideoLanePlan` portieren | M |
| C3 | Abspielen synchron zur Song-Uhr | ? | `VideoLanePlayer` hinter einem Sink-Protokoll | M |
| C4 | Kamera-Take | ? | `VideoTakeLedger` unverändert übernehmen, der Recorder kommt in den einen Sheet-Slot | M |
| C5 | Schnitt auf Takte | — | reiner Befehl + Test | S |
| C6 | Export mit Mix (mp4) | — | Mix offline rendern, dann `AVMutableComposition`. **Die Ausrichtung löscht nie Material** (alter Bug: ein kurzes Audio kürzte einen 60-s-Take auf 3 s und löschte das Original) | L |
| C7 | Gerätebewegung als Modulationsquelle | — | CoreMotion-Lage, reine Abbildungs-Tests | M |
| C8 | Gesicht/Kopf/Hände als Quelle (17 Kanäle) | J (1 Tag türig) | **zuletzt**: erst ein Einverständnis-Design, nur auf dem Gerät, ausgehend standardmäßig aus, nie Emotionen ableiten | L |

**Konflikte, die nur du lösen kannst:**
- `NEUSTART_2026-10-17.md` sagt „Nicht in Version 1: Video“. Dein Wort vom 25.10. hebt das auf, und ich
  trage es dort nach.
- Kamera und Puls teilen sich die hintere Linse samt Licht. Video-Aufnahme und rPPG laufen also nie
  gleichzeitig.
- Der Kamera-Text der alten App („No images are stored“) wäre mit Video falsch. In Studio wird er neu
  geschrieben, wenn W1 und W7 kommen.

## D · Generative Intelligenz auf dem Gerät

**Studio hat schon einen Assistenten**: Apple Foundation Models mit 11 Werkzeugen, nur auf dem Gerät. Jede
Anfrage ist **ein** Undo-Schritt durch die eine Befehlstür. Er braucht iOS 26 und ein Gerät mit
Apple Intelligence. **Er lief noch auf keinem Gerät.**

| # | Posten | Weg | Größe |
|---|---|---|---|
| D1 | Der Assistent kennt Tonart und Skala. Heute nennt `describe()` sie nicht, und es gibt kein Werkzeug dafür, obwohl `setKeyRoot`/`setScale` existieren | Werkzeug `set_key` + `describe()` | S |
| D2 | Pattern, Melodie und Harmonie **nur auf Anfrage**, gezwungen in die Skala. Töne außerhalb werden gemeldet, nie still verschoben | `writeNotes`/`drumPattern` + `MusicalContext.contains` | S–M |
| D3 | Klang aus einem Satz | neues Werkzeug `set_parameter` über `setInstrumentParameter` | S |
| D4 | Arrangement-Vorschläge (verlängern, Intro) | `repeatClip`, `automate` | S |
| D5 | Akkordvorschläge ohne Modell (deterministisch) | `ChordSuggest` portieren | M |
| D6 | Generative Visuals zu Song und Körper | Teil von W3, nicht dieser Welle | L |

**Das Gesetz „nichts komponiert ungefragt“ bleibt erfüllt**, wenn vier Bedingungen gelten:
1. Nur ein getippter Satz von dir löst aus, kein Timer und kein Gerät.
2. Das Ergebnis sind gewöhnliche, editierbare Noten, mit einem Schritt rückgängig.
3. Die Aktionszeile zeigt, dass der Assistent geschrieben hat.
4. Nichts generiert dauerhaft weiter.

**Nach außen** heißt das „Assistent auf dem Gerät“. Nie „Superintelligenz“, nie „KI komponiert“.
`BioComposer` (der Regel-Komponist der alten App) wird nicht portiert.
**Kommt nicht wieder:** „CoreML-powered“ ohne Modell, „Demucs“ als Bandmaske, SuperIntelligence,
WorldModel, Quantum.

## Reihenfolge, die ich vorschlage (je Zeile ≤ 3 Dateien, Gate grün, dann TestFlight)

1. **W1 Körper** läuft (Pulsmathematik portiert, 7 Kerne mit Tests).
2. **Klang-Schnellgewinne:** A1 Supersaw · A4 FM · B5 Chorus/Flanger/Phaser · B8 Limiter · B7 Sättigung.
   Alle S, alle Foundation-only.
3. **W8 Stimme:** B4 Granular als Clip-Bake (Kern existiert) → B2 Harmonizer live → B1 Phase-Vocoder →
   B3 Tonhöhenkorrektur offline.
4. **W10:** D1 → D3 → D2 → D4. D1 und D3 sind je eine kleine Scheibe.
5. **W5:** A2 Ladder/303 · A5 Mallets · A9 DDSP.
6. **W7 Video:** C1–C6, danach **W9:** C7, und C8 zuletzt.

## Was ich von dir brauche

- **Ja/Nein zu C1:** Video als eigene Spurart bedeutet Format-Version 3, die schon W2 auslöst. Ich würde
  beide in **einen** Formatsprung legen.
- **Gesicht (C8):** Einverständnis-Text und „verlässt nie das Gerät“ als harte Regel. Das ist eine
  Produktentscheidung, keine Code-Frage.
