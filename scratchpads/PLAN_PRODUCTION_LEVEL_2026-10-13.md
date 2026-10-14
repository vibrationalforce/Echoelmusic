# PLAN — Produktionsniveau (Founder 2026-10-13)

Founder wörtlich: „Solange keine vernünftige produktionesumgebung wie auv3 Plugins für Effekte und
MIDI Instrumente sowie brauchbares Pianoroll, automation etc vorhanden ist finde ich testen planlos.
Sieh zu das wir auf Produktion Level kommen." Eingetragen als E11 (neu entschieden) in
`docs/dev/FOUNDER_INBOX.md`.

Gemessen am 2026-10-13 von zwei Lesern (nur lesend, file:line in der Sitzung). Die tragenden Fakten:

- **Kein Fremd-Plugin wird geladen.** `AVAudioUnitComponentManager`, `AVAudioUnit.instantiate`,
  `requestViewController` kommen in `Sources/` nicht vor.
- **Jede Stimme ist ein `AVAudioSourceNode` direkt am `masterMixer`.** Es gibt keinen Spur-Mixer-Knoten,
  also auch keinen Ort für einen Effekt zwischen Stimme und Master.
- **Knoten werden VOR dem Engine-Start angehängt** (`EchoelmusicApp` Startblock 2/4). Ein Anhängen an
  eine laufende Engine hat Build 1363 beim Start abstürzen lassen. Später geht nur der Weg
  pause → attach → `restartOrDegrade`.
- **Der Speicherplatz existiert schon:** `DeviceChain.instrument: DeviceInsert?` und `inserts`;
  `DeviceInsert` = `typeID` + `stateBlob`, unbekannte Typen bleiben byteweise erhalten. Ein Plugin
  (Komponente + `fullState`) passt hinein, ohne das Format zu ändern.
- **Die Plugin-Oberfläche braucht kein neues `.sheet`:** die Geräte-Seite im Spur-Detail ist eine
  Inline-Fläche (Black-Screen-Gesetz bleibt unberührt).
- **Format- und Medien-Reset:** es gibt kein Register angehängter Knoten; ein gehostetes Plugin
  braucht eigenes Wieder-Anhängen.

## Reihenfolge (jede Scheibe einzeln: Wächter, beide Gates, dann TestFlight)

### A. AUv3-Hosting — erst Instrumente, dann Effekte

| # | Scheibe | Kern |
|---|---|---|
| H1 | Liste der installierten AUv3-Instrumente und -Effekte auf der Geräte-Seite (nur lesen) | `Audio/PluginCatalog.swift`, `Studio/TrackPluginRow.swift` |
| H2a | Ein Instrument für eine MIDI-Spur WÄHLEN: `DeviceInsert` mit `typeID` `auv3` + Komponente; ein Undo-Schritt | `Core/DeviceChain`, `TimelineStore` |
| H2b | Das gewählte Instrument laden (`.loadOutOfProcess`, damit ein Plugin-Absturz die App nicht mitnimmt), über pause → attach → restart anhängen, die Noten der Spur als MIDI an das Plugin geben | `Audio/PluginHost.swift`, `LaneVoiceRack`/Slot-Senke |
| H3 | Die Plugin-Oberfläche inline auf der Geräte-Seite (`requestViewController`) | `Studio/HostedPluginView.swift` |
| H4 | Der Plugin-Zustand reist im Stück (`fullState` → `stateBlob`, beim Laden zurück) | `PluginHost`, Speichern/Laden |
| H5 | Spur-Mixer-Knoten je Spur (Voraussetzung für Effekte) | `AudioEngine`, `LaneVoiceRack`, `TimelineAudioSink` |
| H6 | AUv3-Effekte als Inserts auf MIDI- und Audiospuren | `PluginHost`, Geräte-Seite |

### B. Noten-Editor (in Wertreihenfolge des Lesers)

| # | Scheibe |
|---|---|
| N1 | Noten beim Setzen, Verschieben und Antippen hören |
| N2 | Klaviatur links, vertikaler Zoom |
| N3 | Raster wählbar (1/4 … 1/32, Triolen, frei) und Länge neuer Noten |
| N4 | Kopieren/Einfügen, Legato |
| N5 | CC-/Pitch-Bend-Spur |

### C. Automation

| # | Scheibe |
|---|---|
| A1 | Lautstärke und Pan jeder Spur automatisieren (MIDI, Audio, Echoel) |
| A2 | Kurvenformen und Freihand-Zeichnen |
| A3 | Live-Aufnahme (Latch/Touch) von Reglerbewegungen |

## Was eine Sitzung NICHT beweisen kann

Ob ein Fremd-Plugin lädt, klingt und seine Oberfläche zeigt, sieht nur ein Gerät mit installierten
Plugins. Jede H-Scheibe trägt deshalb eine `NEEDS-FOUNDER-VERIFY`-Bitte mit genauem Weg.

## Stand 2026-10-13 (abends)

| Scheibe | Commit | Stand |
|---|---|---|
| H1 Liste der installierten AUv3 | `800110e1c` | gepusht, Gates offen |
| N1 Noten hören beim Setzen/Antippen/Verschieben | `ca233360d` | gepusht |
| N3a Raster zeichnet (Start an der Zelle, Länge = Zelle) | `69439cd36` | gepusht |
| N4a Legato | `da2dbd3a8` | gepusht; repariert zugleich `TheSelectedPartsNotesAreEditedThroughOneWriterTests` (rot seit `f60fda649`) |
| A1a/b Lautstärke-/Pan-Kurve je Rack-Spur | `12680a37e` | gepusht |
| A1c Volume/Pan im Automations-Editor | `e3f862fc0` | gepusht |
| A1d Audiospuren folgen den Kurven | `3ee945bc7` | gepusht |
| N4b Kopieren/Einfügen in jeden Part | `2b6661391` | gepusht |
| H2a Plugin-Wahl im Song (Modell, Schreiber, Undo) | `a19f74c87` | gepusht |
| H2b1 Host + `AudioEngine.attachAudioUnit` | `d43d1eb89` | gepusht |
| H2b2 Verdrahtung (Player → Host, Noten-Senke) | `a6beb256e` | gepusht |
| H2c Auswahl-Menü auf der Geräte-Seite | `4ca337a53` | gepusht; Gates in der Warteschlange (Stau, siehe HARNESS_LEDGER) |

**Offen:** H3 Plugin-Oberfläche · H4 Plugin-Zustand im Stück · H5 Spur-Knoten · H6 Effekt-Inserts · A1e Echoel-Spur · N2 Tastatur · N3b Triolen · N5 CC-Spur · A2/A3. Gerät: H1, H2 (Klang, Klick beim Laden, Kopfhörer-Wechsel, Media-Reset), N1, A1.

## A1 — gemessener Weg (Explore-Bericht 2026-10-13, Belege file:line dort nachprüfen)

- Heute bietet `SongAutomationEdit.offered` nur `PolySynthVoice.automatableBases`, und `sounds(on:)` nur POLY-Rack-Spuren
  (`Studio/SongAutomationEditor.swift` ~62/133). Kein Lautstärke-/Pan-Ziel.
- Anwenden läuft über `AutomationPlayer.applyStep` → `ParameterApplyRouter.applyPerTrack` → Slot; Roll-, Audio-
  und Bio-Spuren lösen dort zu nil auf.
- Pegel/Pan heute: Rack über `slotGainSink`/`slotPanSink` (`refreshMixer` jeden Schritt, aber früher Ausstieg ohne
  Mixer-Änderung) · Audio über `AudioLanePlayer.reconcileMix` (jeden Schritt, mit Diff-Cache) · Roll nur
  `pianoRoll.mixGain` = Anschlags-Skalierung, KEIN Live-Fader, KEIN Pan-Verbraucher.
- **Entwurf (nicht über den Router, kein Dokument-Schreiben pro Schritt):**
  - A1a: reservierte Basen `mix.gain`/`mix.pan` (ohne Registry-Deskriptor, also kein Doppel-Anwenden) +
    reine `TimelineDocument.automatedGain(for:atTick:)`/`automatedPan(for:atTick:)`; Noten-Gate bleibt auf
    `effectiveGain`.
  - A1b: Rack — `refreshMixer` mit Tick, Diff-Cache je Slot statt frühem Ausstieg; Audio — Tick in
    `start`/`reconcileMix`/Override.
  - A1c: Editor bietet `mix.gain`/`mix.pan` jeder Spur mit Verbraucher an (Roll: nur Gain, und ehrlich: formt nur
    Anschläge, bis ein Spur-Knoten existiert = H5).
- Treppen-Artefakte bei schnellen Rampen (Schritt-Rate) — Glättung im Sink optional, als Grenze nennen.
