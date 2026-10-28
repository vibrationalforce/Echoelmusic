# Plan — alle Instrument- und Field-Teile in die DMMW (2026-10-28)

Founder 28.10.: „Baue alles fertig, sämtliche Instrument und Field Teile strukturiert Architecture
intelligent in die GSI(D)MMW Vision integriert.“ Nach außen gilt weiter: nie „Superintelligenz“
(`decisions.csv` 2026-10-25), es heißt „generative Intelligenz auf dem Gerät“.

## Das Architektur-Prinzip: eine Achse, viele Teile

Jedes Teil dockt an die Achse an, die schon trägt, statt eine zweite daneben zu bauen:

| Achse | Was sie heute trägt | Was ein neues Teil dort bekommt, ohne Zusatzarbeit |
|---|---|---|
| **Parametertabelle** (`InstrumentDevice.parameters`, Core) | Synth/Drums/Sampler-Werte | Speichern im Song, Undo, Automation, MIDI-Learn, Körper-Modulation (W2), AUv3-Parameterbaum, Assistent |
| **`PatchField` → DSP-Patch** (Kernels) | eine Abbildung Werte → Klang | App, Plugin, Export klingen gleich |
| **`ModulationInputs` + Routen** (Engine) | Puls, HRV, Kohärenz → Fader/Pan/Instrumentwerte | jede neue Quelle (LFO, Makro, Kamera-rPPG, Bewegung) wirkt sofort auf alles |
| **`EngineSnapshot`** (Engine) | was der Render-Thread spielt | Field liest denselben Takt, dieselbe Tonart, dieselben Pegel |

**Regel:** Ein Instrument-Teil ist zuerst eine *Engine-Wahl* im Synth (eine Zeile in der Tabelle),
erst wenn es eine eigene Spielweise braucht, ein *Gerät* (`InstrumentDevice`) — jede neue Wahl ans
Ende ihrer Liste (StoredNames).

## Instrumente (Katalog A)

| # | Teil | Form | Stand |
|---|---|---|---|
| A1/A4/A8 | Supersaw, 2-Op-FM, Sub | Engine-Wahl + „Character“ | **gebaut 28.10.** (`SynthEngine`, `synth.engine`, `synth.character`) |
| A6 | Karplus-Strong „Pluck“ | eigenes Gerät (Delay-Puffer je Stimme passt nicht in den Werttyp der Synth-Stimme) | später |
| A7 | Wavetable → „Morph“ | Engine-Wahl: vier bandbegrenzte Formen (Sinus·Dreieck·Säge·Rechteck) überblendet, Character = Position, keine Tabellen | **gebaut 28.10.** (Index 4) |
| A2 | Moog-Ladder + Slide/Accent | `LadderFilter` als `synth.filter`; Slide/Accent offen | **Ladder gebaut 28.10.** |
| A3 | 808-Glide/Reese | Presets auf A1/A2 + Kick-Pitch | Presets |
| A5 | Modalbank „Mallets“ | eigenes Gerät (angeschlagene Objekte, keine Hüllkurve) | Gerät |
| A10 | Zellulärer Automat „Texture“ | eigenes Gerät | Gerät |
| A9 | DDSP Harmonic+Noise | viertes eingebautes Gerät (W5) | groß |
| A11/A12 | Drum-Ausbau, euklidisch | `DrumKit` / Schritt-Befehl | klein |

## Field (W3) — das Bild als Teil des Instruments

„Field“ war in der alten App die Fläche, auf der Körper und Musik ein Bild werden (`MetalBioView`,
Spektral-Donuts, Analyse-Ansichten). In Studio wird sie **eine Ausgabe derselben Achse**:

1. ✅ **F1 `FieldFrame` (Core, rein):** ein Wert je Bildfrage — Takt-Phase, Tonart-Farbe, Pegel,
   Puls/HRV/Kohärenz — aus Snapshot-Zeit, `MeterBank` und `ModulationInputs`; 3-Hz-Blitzgrenze
   als getestete Funktion (`FlashLimit`), nie als Absicht im Shader.
2. ✅ **F2 Renderer:** SwiftUI `Canvas`/`TimelineView` zuerst (null Abhängigkeit, kein Metal-Risiko),
   Metal später; liest `FieldFrame` in einer Blatt-Ansicht (Law 6: kein heißer Zustand im Rumpf).
3. ✅ **F3 Fläche (als fünfte Fläche statt Fenster):** ein schwebendes Fenster über dem Studio + Vollbild; Tür im Song-Menü; durch den
   EINEN Sheet-Slot (Law 7).
4. **F4 Modulation des Bildes:** Bildparameter sind Routenziele wie Klangwerte (eine Tabelle
   „field.*“ im Projekt, Format bleibt 3: Werte in einem neuen optionalen Feld → Format 4 nur, wenn
   gespeichert).
5. **F5 Ausgabe:** Licht (Art-Net/sACN) und OSC lesen denselben `FieldFrame` (W4, wartet auf F25).

## Reihenfolge und Takt
Engine-Wahlen A6 → A7 → A2, dann F1–F3 (TestFlight 11 bis 31.10. mit dem, was grün ist), dann
Geräte A5/A10, dann A9 und F4/F5. Jede Scheibe ≤ 3 Dateien, Test zuerst, Gate grün vor Release.

## Himmel und Natur als Quelle (Founder 28.10., nach einem Abend mit Sky Guide)

Idee: der Stern, auf den das Telefon zeigt, wird Klang; ebenso Moleküle, Pflanzen, Tiere, Menschen.
Gesetz dafür: **Sonifikation und Rechnung, nie Wirkung** — die App sagt, welche Messgröße welchen
Klangwert bewegt, und nichts darüber, was der Klang mit einem Menschen macht.

| Teil | Was echt messbar ist | Form in Echoel |
|---|---|---|
| Stern im Blick | Position (Katalog + Standort + Uhrzeit + Ausrichtung), Helligkeit, Farbe (B−V ≈ Temperatur) | **S1** Core: Sternkatalog offline (hellste ~300, gemeinfreier Yale Bright Star Catalogue) + reine Rechnung Rektaszension/Deklination → Höhe/Azimut, mit Tests · **S2** App: CoreLocation + Kompass/Lage → der Stern in Blickrichtung; ohne Netz; Kamera nur optional als Bild dahinter · **S3** Stern = Modulationsquelle (Helligkeit, Farbe) und Grundton-Vorschlag |
| „Ton“ eines Sterns | Asteroseismologie: echte Eigenschwingungen (Sonne ~3 mHz, Kepler-Daten), um Oktaven hochgesetzt | Kammerton-/Grundton-Vorschlag wie die Planeten (Rechnung, Quelle genannt) |
| Moleküle | Schwingungsspektren (IR/Raman, THz), um Oktaven heruntergesetzt | Tonsystem oder Akkord aus den Linien eines Moleküls (z. B. Wasser), mit Quelle |
| Pflanzen | bioelektrische Signale nur mit Sensor (Elektroden) | später, über BLE/MIDI eines Sensors, wie der Brustgurt |
| Tiere | Rufe (Aufnahme), Herzschlag mit Sensor | Sampler/Audio-Import; kein Sensor im Telefon |
| Menschen | Puls, HRV, Kohärenz | **schon da** (Gurt) |

Offen und zu klären vor S2: zwei neue Berechtigungen (Standort, Bewegung) — Begründungstexte; der
Katalog als gebündelte Daten (Lizenz prüfen, Quelle nennen). Nichts davon kopiert Sky Guide.
