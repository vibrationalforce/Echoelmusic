# Astra (ChatGPT, höchste Stufe) — drei Aufträge, Hardware · Klang · Design (2026-10-15)

Stand: öffentlicher `main` = `e75d99b7f` (alle unten genannten Pfade dort mit `git cat-file -e`
geprüft). Repo: https://github.com/vibrationalforce/Echoelmusic

**Gebrauch:** Kopf (Abschnitt 1) + GENAU EINEN Auftrag (A, B oder C) als EINE Nachricht in einen
NEUEN Chat. Drei Aufträge = drei Chats. Die Antwort kommt unverändert an Claude Code zurück; dort
wird jede Behauptung am Code gemessen, bevor etwas übernommen wird.

Nichts hier ist Store-Text oder Website. Nichts Privates mitschicken (keine Logs, keine Schlüssel).

---

## 1. Kopf (immer mitschicken)

Du bist PRÜFER und ARCHITEKT, nicht Bauer. Echoelmusic ist eine iPhone-App (Swift 6, SwiftUI,
AVAudioEngine, CoreMIDI, null externe Abhängigkeiten): ein bio-reaktives Instrument und eine
Workstation. Lies den Code im öffentlichen Repo auf Stand `e75d99b7f`.

Harte Regeln des Projekts, die deine Vorschläge einhalten müssen:
- Audio-Thread: keine Locks, kein malloc, kein ObjC-Messaging, keine Datei-I/O, kein GCD.
- Kein Force-Unwrap; `os_log` statt `print`; Swift-6-Concurrency streng.
- Keine neuen Abhängigkeiten, keine neuen Targets.
- Die App muss OHNE Hardware vollständig klingen; Hardware ist ein zuschaltbarer Zusatz.
- Der SwiftUI-Body der Haupt-Ansicht darf keine weiteren `.sheet`-Modifier bekommen (Absturzgrenze).

Antwortformat (Pflicht): höchstens 8 Punkte. Jeder Punkt: Datei:Zeile auf `e75d99b7f` · Befund ·
SICHER oder VERMUTET · kleinster nächster Schritt. Kein Code, keine Diffs. Am Ende EINE Empfehlung,
welche Scheibe zuerst kommt, und warum. Was du nicht im Code gesehen hast, nennst du UNGEPRÜFT.

---

## 2. Auftrag A — Architektur: Mehrkanal-Ausgang ans Xone:96 (HW-5)

Ziel: Das iPhone hängt per USB an einem Allen & Heath Xone:96 (iOS meldet laut Hersteller-Doku
mehrere Ausgangskanäle). Spurgruppen (Drums, Bass, Pad, Rest) sollen auf getrennten Kanalpaaren
landen; ohne Interface bleibt alles auf Stereo.

Heute (gemessen): `Sources/Echoelmusic/Audio/AudioEngine.swift` klemmt das Verarbeitungsformat auf
`min(outputFormat.channelCount, 2)` (~:866) und baut es einmal hinter `graphPrepared`. Alles summiert
über `masterMixer` → `AutoMixChain` → `mainMixerNode`; `RetroCapture` tappt `mainMixerNode`.
Spur-Busse pro Rack-Slot (`attachTrackBus`, `Sequencer/LaneVoiceRack.swift`) nur VOR dem Engine-Start.
`AudioConfiguration.swift`: `.playback`, 48 kHz, kein `setPreferredOutputNumberOfChannels`; ein
neues USB-Gerät wird nur geloggt, ein Verlust startet die Engine neu, nie mit neuem Format.
Plan: `scratchpads/PLAN_HARDWARE_LIVE_2026-10-15.md` (HW-3 … HW-6).

Fragen:
1. Welcher AVAudioEngine-Aufbau trägt N Ausgangskanäle, ohne die Stereo-Master-Kette (Limiter,
   RetroCapture, Export) zu brechen? (Mehrkanal-`outputNode`-Format + pro Paar ein Stereo-Submix?
   Channel-Map am Output-AU? Was ist auf iOS tatsächlich unterstützt?)
2. Wie wird der Graph bei USB-An/Abstecken neu gebaut, ohne die bekannte Absturzfamilie beim
   Attach/Restart zu treffen? Welche Reihenfolge, welche Breadcrumbs?
3. Wie gehen Busse, die heute nur vor dem Start entstehen, mit einem Interface um, das erst später
   ankommt?
4. Welche Risiken für Latenz, CPU und den 60-Hz-Meter-Pfad?

---

## 3. Auftrag B — Architektur: eigene Drums + Acid-Bass im Instrument (SP-3, SP-4)

Ziel: Echoelmusic bekommt eigene Drums (Techno/Electro-Kits) und eine Acid-Bassfigur mit Accent und
Slide. Plan: `scratchpads/PLAN_SOUND_PALETTE_2026-10-15.md`.

Heute (gemessen): Der Komponist berechnet Drum-Raster (`Sequencer/BioComposer.swift`, vier
Archetypen, 8 Spuren × 16 Schritte), das Instrument spielt aber `BioComposer.silentBeat()`
(`Studio/EchoelStudioView.swift` ~:11058). `DSP/EchoelModalBank.swift` (Modal-Synthese, `.drum`)
hat keinen Aufrufer und alloziert in zwei Methoden. `Sequencer/SamplerVoice.swift` lädt nur aus
einer URL. `Sequencer/PatternEngine.swift` taktet auf einem Main-Queue-Timer (Jitter);
`onStep` hat keinen Setter. `Tools/SubBassVoice.swift` ist mono mit fester ~5-ms-Glide,
`Sequencer/BassGrammar.swift` hat keine Acid-Figur, `Tools/PolySynthVoice.swift` hat `slide()`.

Fragen:
1. Wo entstehen die Drum-Treffer sample-genau — im Render-Block mit Sample-Offset statt vom
   Main-Queue-Timer? Wie kommt das Raster lock-frei dorthin (SPSC, Doppelpuffer)?
2. Gebackene One-Shots (einmal beim Start in `[Float]`) über `SamplerVoice` oder eine eigene
   Drum-Stimme? Speicher- und CPU-Budget für 8 Spuren.
3. Accent und Slide für die Acid-Figur: über welche vorhandenen Parameter (Velocity,
   Filter-Hüllkurve, `slide()`), ohne den Audio-Thread zu verletzen?
4. Wie bleibt der Klang identisch, wenn dieselben Treffer gleichzeitig als MIDI an eine externe
   TR-8S gehen (HW-10)? Ein Zeitgeber für beide?

---

## 4. Auftrag C — Design: Hardware-Routing und die Klangkarte

Ziel: zwei Oberflächen, die zum bestehenden Design passen müssen (Uncodixfy-Regeln in `CLAUDE.md`:
Radien ≤ 16 px, keine Glas-/Blur-Effekte, keine Glow-/Neon-Akzente, 1-px-Rahmen, Zahlen vor
Visualisierung; jeder numerische Parameter ist ein `EchoelValueField`; benannte Werte sind ein
Menü-Picker; die Akzentfarbe gehört allein dem Körpersignal).

1. **Hardware im Routing** (`Studio/PatchbayView.swift`): pro Nachrichtenart (Clock, Noten, Drums,
   CC, Program Change) Ziel und MIDI-Kanal; „Drums to MIDI" (Kanal 10); MPE-Hinweis bei Kanal-10-
   Konflikt; eine Ausgangswahl pro Spur im Mixer (`Studio/PieceMixerView.swift`), die nur erscheint,
   wenn das Interface mehr als 2 Kanäle meldet. Wie bleibt das für jemanden ohne Hardware unsichtbar
   und für jemanden mit Hardware in zwei Taps erreichbar?
2. **Klangkarte mit vier Makros** (Dichte · Weite · Bewegung · Zerfall) über dem lebenden Bild —
   inspiriert von einer Preset-Karte mit vier Makro-Reglern. Wo sitzt sie (`Studio/EchoelStudioView.swift`,
   `Studio/SoundBrowserView.swift`), ohne einen neuen `.sheet` anzuhängen? Wie lesen sich die vier
   Makros als `EchoelValueField`s?

Gewünscht: je Oberfläche eine Skizze in Worten (Reihenfolge der Zeilen, was standardmäßig verborgen
ist), die drei größten Risiken, und welche bestehende Fläche wiederverwendet wird.
