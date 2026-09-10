# Visual-/Render-Ressourcen-Audit (2026-09-10, read-only Explore-Agent, #1241-Nachlese)

Founder-Ask: „resourcensparende Audio Visual Performance". Sechs Befunde, je mit kleinstem Ein-Datei-Fix. GPU-ms/Frame,
Temperatur- und Akku-Delta sind im Repo NIRGENDS gemessen (kein Metal-Counter-/Instruments-Artefakt) — jede Zeile hier
ist Code-Lesung, kein Messwert.

| # | Befund | Schwere | Evidenz | Kleinster Fix | Status |
|---|---|---|---|---|---|
| V1 | Detail-Tier senkt den LOOK, nicht die GPU-Last: `visualDetailScale` (0.5/0.7) ist im Shader nur ein Dichte-Multiplikator (`clamp(u.ringDensity, 4, 120)`), Schleifen fix (`k < 6`, `k < 5`); Drawable immer auf nativem Scale, ohne Cap (`MetalBioView.swift:1044-1046`) — Vollbild 3x ≈ 8 MP Fragment-Shader bei 60 fps auch bei thermal `.critical` | hoch | `AdaptiveQuality.swift:109/113`, `MetalBioView.swift:1315/2465/1728/1923/1044` | `want` in der Settled-Size-Maschine (`:1047-1058`) mit einem Auflösungsfaktor aus dem Tier multiplizieren | offen |
| V2 | Reduce-Motion zeichnet 60 identische Frames/s: `uniforms.time = reduceMotion ? 0 : …` (`:1635`), Phasen stehen (`:1612`), aber `isPaused = false` / `enableSetNeedsDisplay = false` (`:532-533`, einzige Schreiber im Repo) | hoch | `MetalBioView.swift:532/1612/1635` | `isPaused = true` + `enableSetNeedsDisplay = true`, sobald `effectiveReduceMotion` und kein Easing läuft; UNMEASURED ob der letzte Drawable stehen bleibt (`presentsWithTransaction`) — Gerät | offen |
| V3 | Kein Gating bei Verdeckung (Sheet/Cover pausiert nichts; `scenePhase`-onChange macht nur Autosave); der ganze Bio-/Noten-/Easing-Block läuft VOR `guard let drawable` (`:1331`) | mittel | `MetalBioView.swift:1331`, `EchoelStudioView.swift:1436` | Drawable-Guard an den Anfang von `draw(in:)` | offen |
| V4 | Per-Frame-Allokationen im Draw-Pfad: vier Heap-Arrays (`slotTaken`, `slotSeeded`, `noteConsumed`, `targetW`, `:1366-1369`), `(0..<5).filter` (`:1389`), `mf.notes.sorted` (`:1188`), `held.map(\.hz)` unter Lock (`:396`). Kein `makeBuffer` pro Frame (`setVertexBytes`/`setFragmentBytes`, korrekt) | mittel | `MetalBioView.swift` | die vier Arrays als gespeicherte Properties, pro Frame nur zurücksetzen | offen |
| V5 | `targetFPS`/`allowSpectralDonuts`/`oscHz` ohne Konsumenten (bekannt, CLAUDE.md); `VideoRecorder.swift:234` behauptet ein Throttling auf 30/24, das nirgends passiert; der Donut-Pfad (`FloatingVisualWindow.swift:830/846`) läuft ungoverned mit `TimelineView(.animation(minimumInterval: 1/60))` + volle FFT + neue Band-Arrays pro Frame auf dem Main-Thread (`SpectralDonutView.swift:44`) | mittel | s. links | `minimumInterval` 1/30 (halbiert FFT + Canvas sofort); Kommentar in `VideoRecorder.swift:234` korrigieren | offen |
| V6 | Aufnahme blittet/encodiert ungedrosselt mit Renderrate (`VisualRecorder.swift:250`, kein PTS-Skip; `AVVideoExpectedSourceFrameRateKey: 60`, bis 20 Mbps) | niedrig | s. links | PTS-basierter Skip auf 30 fps — ÄNDERT die Aufnahme-Rate, Founder-Frage | offen |

**Geprüft und sauber (nicht erneut auditieren):** Shader-Compile prozessweit gecacht (`MetalBioView.swift:614-621`) ·
verstecktes Fenster rendert `Color.clear`, kein 60-fps-Geisterbild, External-Stage yieldet (`FloatingVisualWindow.swift:780-812/743`) ·
`TouchInstrumentView` `CADisplayLink` weak-Proxy, self-invalidierend, `window == nil → stopAutoPlay()` · Drawable-Churn:
`autoResizeDrawable = false` + Settled-Size · `VisualRecorder`: gepoolte PixelBuffer + `CVMetalTextureCache`, ein Actor-Hop pro Still.

Reihenfolge (Ralph, je eine Scheibe): V5 (eine Zeile + Kommentar) → V3 → V4 → V2 (mit statischem Wächter, Gerät-Verify) → V1 (Gerät-Verify) → V6 (Founder).
