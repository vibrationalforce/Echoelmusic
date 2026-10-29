# HANDOFF — Lambda, Loop Mode & visionOS Integration

Stand: Branch `claude/fix-app-crash-sdk-ticsF`, Basis-Commit `461bed1`.
Diese Session hat nur analysiert — **kein Produktionscode wurde geändert**.
Build konnte nicht geprüft werden (kein Swift im Container). Verifikation: `swift build && swift test` bzw. TestFlight-Workflow (`.github/workflows/testflight.yml`).

## Ziel

Lambda-Modus und Loop-Modus vollständig, realistisch und absturzfrei in die App integrieren (iOS/macOS/tvOS **und** visionOS).

## Befund

### 1. Lambda ist toter Code
Alle Dateien in `Sources/Echoelmusic/Lambda/` sind implementiert, aber nie angeschlossen:

| Typ | Problem |
|-----|---------|
| `LambdaModeEngine` (+ `LambdaModeView`) | kein `.shared`, nie instanziiert, View nie angezeigt |
| `EnvironmentLoopProcessor.shared` | `start()` wird nie aufgerufen |
| `SelfHealingCodeTransformation.shared` | `activate()` wird nie aufgerufen |
| `UniversalEnvironmentEngine.shared` | bekommt keine Sensordaten, keine Ausgänge |

### 2. Zwei getrennte Loop-Implementierungen
- Transport-Button in `Views/MainNavigationHub.swift:891–912`: `@State loopActive` + `toggleLoopMode()` setzt `clip.loopEnabled` in `EchoelCreativeWorkspace.shared.proSession` — **funktioniert**, aber nur Clip-Looping.
- `Audio/LoopEngine.swift` (Aufnahme, Overdub, Quantisierung, Tempo-Sync, Save/Load) — **nie verwendet**.

### 3. visionOS ohne Engines
`Platforms/visionOS/VisionApp.swift` hat eigenes `@main` und initialisiert nur `HealthKitManager`. Lambda, Loop, Creative Workspace und Pro-Engines fehlen.

### 4. Absturzrisiko
`LambdaModeEngine`: `DispatchSourceTimer` mit `[weak self]` kann nach `cancel()` im `deinit` noch einmal feuern. Timer im deinit nonisolated canceln und im Handler `guard let self` prüfen (siehe CLAUDE.md: „deinit calls @MainActor method").

Die Detailprüfung der Lambda-Dateien auf weitere Bugs wurde abgebrochen und ist **unvollständig** — als ersten Schritt nachholen.

## Aufgaben (in dieser Reihenfolge)

1. **Audit** aller Dateien in `Lambda/`, `Audio/LoopEngine.swift`, `Quantum/QuantumLoopLightScience.swift`: Force-Unwraps, Index-/Division-Fehler, `@MainActor`/Sendable-Konflikte, Verweise auf nicht existierende APIs.
2. **Lambda verdrahten** in `EchoelmusicApp.swift`:
   - `LambdaModeEngine.shared` anlegen (`@MainActor`).
   - Neue Init-Phase in `initializeCoreSystems()` nach Phase 13 (Creative Workspace); `totalPhases` (Zeile 188) und Log-Text „14 phases" anpassen.
   - In `connectSystems()` (Zeile 275): Bio-Daten von `UnifiedHealthKitEngine.shared` → Lambda; `EnvironmentLoopProcessor.shared.start()`; Ausgänge → `AudioEngine` / Visuals.
   - `LambdaModeView` in `MainNavigationHub` / `WorkspaceContentRouter` erreichbar machen.
3. **Loop vereinen**: `LoopEngine` instanziieren, an `AudioEngine` + `workspace.$globalBPM` koppeln; `loopActive` in `MainNavigationHub` vom Engine-State treiben statt lokalem `@State`.
4. **visionOS**: in `VisionApp.swift` dieselbe sequenzielle Init (mindestens Creative Workspace, Lambda, Loop) übernehmen; `#if os(visionOS)`-Branch in `MainNavigationHub` (Zeile ~161, 220–232) prüfen.
5. **Timer-Race** in `LambdaModeEngine` beheben (Punkt 4 oben).
6. **Tests** in `Tests/EchoelmusicTests/` für Lambda-Start/Stopp und Loop-Toggle ergänzen.
7. Build + Tests grün, committen (`fix:`/`feat:`), auf diesen Branch pushen.

## Regeln
Siehe `CLAUDE.md` — insbesondere Logger (`log.log(.info, category:, ...)`), Zugriffsebenen, `#if canImport(UIKit)`, keine externen Dependencies.
