# PLAN — Echoel Field: interaktive Fluidfläche unter der Spielfläche (2026-10-13)

**Quelle:** ein vom Founder eingefügter, fremd verfasster Prompt („Echoel Field, interaktive
Fluidfläche", 13 Schichten) samt browserseitiger Feldstudie. Lernmodus: 14 seiner 16 messbaren
Code-Behauptungen stimmen (`maxDrops = 6`, `minWakeInterval = 0.05`, `octaveBands = [3,4,5]`,
`playRect` ≠ Metal-Bounds, `MoodPads` rohes `@AppStorage("visual.intensity")`,
`LookBlendMap.defaultSequence = [3,5,7]` öffnet auf Water, `autoResizeDrawable = false`, fps 60
gepinnt, `sharedPipeline` nur am Device gecacht, `BioVisualPattern.cymatics` ohne Shader-Zweig,
`fieldWater` k ∝ f^(2/3), V1/V2 im Visual-Audit). **Zwei Korrekturen am Prompt:**
1. „`rg heightfield|viscosity|FluidSurface` ist leer" — FALSCH: `Core/FaradayDish.swift` trägt
   `kinematicViscosity` und löst die volle Dispersionsrelation (W1 #1100, W2 #1101, fünf Wächter).
   Die Fläche darf diesen Kern nicht duplizieren: `fieldDish`/`fieldWater` bleiben die
   Beleuchtung aus der FaradayDish-Lösung, die Fluidfläche ist die STÖRUNG darunter (Schicht 2 des
   Prompts sagt das selbst; die Quelle hat nur den Kern nicht gesehen).
2. `TouchVisualEnergy` und `TouchPitchMap` sind keine Dateien: `TouchPitchMap` ist ein `enum` in
   `Studio/TouchInstrumentView.swift:36`, `TouchToneChannel` eine Klasse in `Views/MetalBioView.swift:417`.

**Verdikt (Council, kurz):** ADOPT→PRODUCT als PLAN. Der Auftrag ist auf Vision (der Körper und
der Finger als Instrument, PERFORMANCE-Fläche, kein neuer Look, kein zweites Cover), aber er ist
KEIN Ralph-Zyklus: zwei Pipeline-States, Ping-Pong-Texturen, Kontaktkanal, Rect-Fix, vier
Bedienelemente, zwei Bindungsorte, acht Tests — das sind ≥8 Dateien. „Ein Diff" wäre genau die
Scheibe, die der Black-Screen-/Hot-State-Absatz verbietet. Also fünf Scheiben, je eine mit Wächter.

## Scheiben (Reihenfolge fest; jede baut auf der grünen davor)

| # | Scheibe | Dateien | Wächter | Gerät? |
|---|---|---|---|---|
| F1 ✅ `dec1986c0` (Build 2624; CI 12/12 Tests bestanden) | `FluidSurfaceMath` — Foundation-reiner Kern nach `WavefrontField`-Muster: Gitter N×N, h/v, zwei Substeps, Impuls nur im ersten, Sponge 8, Klemme ±2.5, `contactAmp`, `sanitize`, `cacheKey(deviceId:generation:)`, `shaderGeneration` | `Studio/FluidSurfaceMath.swift`, `Tests/CISmoke/TheFluidSurfaceKeepsItsEnergyBoundedTests.swift` | Tests 1–5, 7 des Prompts (Golden aus dem ersten grünen Lauf, Python-transkribiert) | nein |
| F2 | EINE Rect für Griffbrett und Feld — `TouchInstrumentView` misst in den Metal-Bounds, `TouchPitchMap.fieldPosition` und Zelle fallen zusammen | `Studio/TouchInstrumentView.swift` (+ `MetalBioView` nur wenn die Bounds-Übergabe fehlt) | Test 8 (rot vor dem Fix: Safe-Area-Versatz) | ja (Hoch/Quer, fullscreen) |
| F3 | `FluidContactChannel` (NSLock, 4 Slots, Überschreiben statt Lebensdauer) + Shader `fluid_step` (RGBA16Float Ping-Pong), angehängte Uniforms `fluidViscosity/Strength/Settle/Map/On`, Look-Gate {2,3}, Normal-Schattierung hinter `fluidOn`, Generationszähler am Cache, Fallback ohne rgba16Float | `Views/MetalBioView.swift` (+ eine Datei für den Kanal) | Uniform-Spiegel-Wächter; `TheWaterDishIsLitLikeTheExperimentTests` bleibt grün; Test 6 (Look-Indizes) nur, wenn kein Wächter sie schon pinnt — prüfen: `TheWaterDishObeysFaradayTests`, `LookBlendMap`-Guards | ja (1, 2, 5, 7, 8 der Abnahme) |
| F4 | Oberfläche: drei Regler + „Glätten", nur sichtbar bei Look Water/Dish; `StudioDefaultKeys` (Muster `visualIntensity`), gebunden in `EchoelStudioView`, `FloatingVisualWindow`, External Stage | `Core/StudioDefaultKeys.swift`, die drei Bindungsorte | `EveryFlagSaysWhatItGates`-Familie / Key-Wächter; `EchoelValueField` für die zwei Zahlen, Picker für die Farbkarte (benannte Werte) | ja (3, 4, 6) |
| F5 | Bio-Kopplung: `viscosityEff = clamp(viscosity + 0.15·(coherence − 0.5), 0, 1)` aus dem GEEASTEN `uniforms.coherence` im Draw — kein neuer Observer, keine zweite Atemwelle | `Views/MetalBioView.swift` | Wächter: der Read ist der eased Uniform, nicht `frame.coherence` | ja |

**Nicht in diesem Plan:** Cymatics (`PLAN_CYMATICS_VISUAL_2026-07-10.md`), neuer Look, Index-
Verschiebung, zweites Cover, FFT-Wasser, `isPaused`, `MoodPads`-Aufräumen. Copy, falls überhaupt:
„Die Fläche antwortet auf die Berührung. Ruhe dämpft sie." — keine Esoterik.

**Einordnung im GMMW-Plan:** P4 Visual (PLAN_GMMW §B11), PERFORMANCE-Fläche nach WA1-Zensus;
berührt weder Workstation noch Session. Start erst, wenn der Deep Audit `wf_b009e54f-195`
gelesen ist (er misst den Baum ohne neue Waisen; F1 legt genau einen an, bis F3 ihn ruft).

**Founder-Abnahme (Schicht 12 des Prompts, Punkte 1, 3, 6, 9):** wird mit F3 als
`NEEDS-FOUNDER-VERIFY` an die Konstruktionsstelle geschrieben, nicht hier.
