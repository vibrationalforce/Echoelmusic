# PLAN — Live Set · Spatial · Binaural · Broadcast (2026-10-03)

Founder, 2026-10-03: „Du entscheidest und integrierst meine Visionen von Live Set,
binaural broadcast, Spatial Audio, immersive und multidimensional media."

## Entscheidung (Council, kompakt)

- **Architect:** EIN Raum-Modell trägt alles — `SpatialSceneStore` (Objekt n = Spur n).
  Eingang, Render, Live-Set und Broadcast hängen sich daran, nie daneben.
- **DSP Purist:** Binaural-Render greift in den Audio-Graphen (#862-Absturzfamilie,
  Lebenszyklus-Leiter) → eigene Scheibe, gerätegeprüft, hinter Flag.
- **Vision-Keeper:** offene Standards (ADM-OSC); Dante/Atmos/DVS werden ANGEBUNDEN, nie
  nachgebaut (Produktgesetz). Keine Behauptung „rendert Atmos".
- **Shipper:** Reihenfolge nach Beweisbarkeit: was off-device beweisbar ist, zuerst.
- **Skeptic:** Audio-Eingang (Xone:96) bleibt draußen — #1302-Absturzfamilie ungelöst,
  Founder-Entscheidung „kein Mikrofon".

## Scheiben

| # | Scheibe | Stand |
|---|---|---|
| S1 | **ADM-OSC-Eingang** — Grapes/L-ISA/SPAT bewegen die Spuren (`ADMObjectInput` → `SpatialSceneStore.apply`), der Szenen-Stream reicht weiter | **GEBAUT** `6097629b6`, Gerät offen |
| S2 | **Glättung + Besitz**: Zielwerte statt Sprünge (Ein-Pol-Glide auf einem 20-Hz-Tick, der NICHT im Empfänger-Callback läuft); externe Bahn hält ein Objekt N s, danach gibt sie es frei; Status „Objekte kommen an" als Blatt in `OSCInputStatusLine` | offen |
| S3 | **Binaural-Render on device** (Kopfhörer): `AVAudioEnvironmentNode` (HRTF-HQ, Apple, keine Abhängigkeit) zwischen den Spur-Stimmen und `masterMixer`, Positionen aus der Szene. ⚠️ Das Environment-Node räumlicht nur MONO-Eingänge — jede Spur braucht einen Mono-Abgriff. Audio-Graph-Eingriff → Lebenszyklus-Sprossen, `audio-thread-reviewer`, hinter Flag, NUR gerätebeweisbar. `DSP/BinauralPanner` bleibt der reine Kern für den AUv3/Fallback | offen |
| S4 | **Live Set**: Raum-Schnappschuss je Perform-Szene (Szenenwechsel = Objektbahnen mit Glide), über den vorhandenen Szenen-Start | offen |
| S5 | **Binaural Broadcast** = Broadcast-S3 (Tap post-Limiter) hinter S3 — der Stream hört dann den binauralen Mix. Hängt an Broadcast-S2 (HaishinKit, `project.yml` founder-gated) | blockiert |
| — | **Dante / Atmos / Club-Mehrkanal**: über ADM-OSC an externen Renderer (FletcherMachine, L-ISA, SPAT, Atmos-Renderer im DAW-Host) — Echoel liefert Objekte + Steuerung, nicht den Mehrkanal-Treiber | Integration, kein Bau |
| — | **Xone:96 / Live-Eingänge** | gestrichen (#1302), nur auf Founder-Frage |
