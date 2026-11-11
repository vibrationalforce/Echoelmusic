# Architektur-Gedächtnis — Scan vom 2026-11-11 (öffentlich, nur Code-Fakten)

Was eine Sitzung über Echoel Studio wissen muss, BEVOR sie Engine, DSP, Kernels, App/Engine, App/Body oder
Plugins anfasst. Nicht immer geladen (die Karte `CLAUDE.md` zeigt hierher); privates Gedächtnis — Entscheidungen,
Protokolle, Founder-Fragen — liegt nur in `echoelmusic-intern/memory/`. Jede Zeile nennt den Ort im Code; was hier
steht, ist ein Datum, kein Gesetz: vor einer Entscheidung den Ort neu lesen. Erneuern: Workflow-Scan wie am
2026-11-11 (vier Leser: Harness, Befehle, Architektur, Hook-Prüfungen) und diese Datei ersetzen, nicht anhängen.

## 1. Module und wer was importieren darf

| Modul | Besitzt | Darf importieren (CI: studio.yml „Imports only where named“) |
|---|---|---|
| EchoelCore (`EchoelStudio/Core`) | Song-Dokument, `Command`/`CommandCatalog`, Undo, `ProjectCodec` (Format 4), `PlaybackPlan`, `TempoMap`, reine Regeln (`CameraArbitration`, `VideoFlashLimit`, `ChordRow`, `TouchVelocity`, `PlaySurface` …) | Foundation, Observation |
| EchoelDSP (`EchoelStudio/DSP`) | reine Prozessoren, render-sicher, ohne Core | Foundation |
| EchoelKernels (`Engine/Sources/EchoelKernels`) | Instrument- und Effekt-Kernels, die Engine UND AUv3 spielen; `OutputSafety`, `DemoGate` | Foundation, Synchronization, EchoelCore, EchoelDSP |
| EchoelEngine (`Engine/Sources/EchoelEngine`) | Render-Hälfte: `EngineCore`, `EngineSnapshot`, Ringe, `ModulationInputs`, `OfflineRender`, Watchdog | dazu EchoelKernels |
| EchoelHost (`Engine/Sources/EchoelHost`) | fremde Audio Units für die Engine, eigene Effekte als AU, `SampleFile` | Foundation, Synchronization, EchoelCore, EchoelKernels, AVFoundation, AudioToolbox — nie EchoelEngine |
| App (`EchoelStudio/App`, Ziel EchoelStudio) | AVAudioEngine-Glue, MIDI, Körperquellen, Video, Stream (HaishinKit nur in `App/Streaming/`), Jam, Views | alles; Netz nur in 7 Dateien (Law 10) |
| Plugins (`EchoelStudio/Plugins`, Ziel EchoelPlugins) | die EINE AUv3-Erweiterung | Core, DSP, Kernels, Host — nie EchoelEngine (CI scannt die gebaute Erweiterung) |

Nur zwei Xcode-Ziele: App/ und Plugins/ laufen in keinem Test, nur im Build und im 20-s-Start-Smoke.

## 2. Threads und ihre Grenzen

- **Main Actor:** `ProjectStore`, `AudioEngine` (`@MainActor @Observable`), `MIDIInput`, Körperquellen, Views.
  `AudioEngine.send` baut einen `EngineSnapshot` und übergibt ihn.
- **Main → Render, Snapshot:** `EngineCore.publish` legt eine `SnapshotBox` in EIN `Atomic<UnsafeMutableRawPointer?>`;
  der Render-Thread nimmt sie unretained (`takePendingSnapshot`) und quittiert die Generation. Der Main-Thread hält
  jede Box ≥ Quittung am Leben (`EngineCore.swift` publish/take, ~506–525, ~1373–1519).
- **Main → Render, Transport:** etwa 25 Atomics mit je einem Schreiber (play, stop, seek, nudge/jump als `add`,
  Loop als ein gepacktes Wort, count-in …).
- **MIDI-Thread → Render, Live-Noten:** `LiveRouter` (`App/Engine/MIDIInput.swift`) entscheidet unter EINEM
  `Mutex` und schiebt in den `EventRing` (SPSC, 1 024). Dieser Mutex hält den Ring einzeln-produzierend: jeder neue
  Aufrufer von `core.playLive` muss durch ihn. Auf dem Render-Thread gibt es keinen Lock (gemessen per grep).
- **Render → MIDI-Sender:** clockOut, noteOut, timecodeOut sind `SPSCRing`s, geleert auf eigenen Queues.
- **Eingang → Render und Platte:** `InputRecorder` (AVAudioSinkNode) → `AudioRing` (10 s, verwirft und zählt) →
  `TakeWriter` in `Task.detached`; `InputMonitor` unter Seqlock.
- **Körper → Render:** `ModulationInputs`, ein `Atomic<UInt64>` je Quelle; NaN = fehlt, negativ = bleibt auf dem
  Gerät (Health). Werte haben KEIN Alter im Render-Thread.
- **AUv3 im fremden Host:** `InstrumentAudioUnit.internalRenderBlock`; Kernel nur in `allocateRenderResources`
  getauscht; Host-Parameter über den Parameterbaum, Events stichgenau über `RenderEvents`.

## 3. Risikozonen — was eine Änderung bricht, und was es heute hält

| Zone | Risiko | Ort | Hält es heute |
|---|---|---|---|
| Snapshot-Lebensdauer | Reihenfolge in `takePendingSnapshot` oder Generation ändern = Zugriff auf freigegebenen Speicher | `EngineCore.swift` ~506–525, ~1373–1519 | Engine-Tests indirekt; keine Prüfung der Reihenfolge |
| Render-Reinheit | Allokation, Lock, ObjC, I/O, GCD oder eine MainActor-erbende Closure kompiliert und knackt erst am Gerät | `AudioEngine.swift` Source-Node-Block (nonisolated static, `@Sendable`), `EngineCore.renderChunk`, Kernels, `InstrumentAudioUnit.internalRenderBlock` | Hook `verify-after-edit.py` (Zeilen-Muster), Review; kein Test |
| Live-Noten an Umlauf/Sprung/Stop | ein Umlauf ist ein Seek: `releaseAllNotes` beendet live gehaltene Tasten | `EngineCore.swift` ~856–873, ~909–931, ~1820 | Pins in `EngineCoreTests`, `ArpeggioPlaybackTests`, `InstrumentPathTests`, `HostedProtocolTests` (heute grün); Reparatur PLAY-3 in Arbeit |
| Ring-Überlauf | volle Ringe verwerfen still | `EventRing.swift`; `EngineCore.playLive` | seit `a9def5c` beendet ein verworfenes Live-Ereignis alles (auch Arpeggio, `c52f3e1`); andere Ringe (launchRequests 256) prüfen das Ergebnis nicht |
| Ein Schreiber je Modulationszelle | Gurt, Kamera, Health schreiben dieselbe Zelle; nur `BodySourceMenu` stoppt die anderen | `App/Body/BodySourceMenu.swift` | nichts |
| Sensor-Abriss, alte Werte | Zellen ohne Alter; Frische lebt im Erzeuger (Gurt/Kamera 3 s, Bewegung 0,5 s, Health 120 s) | `ModulationInputs.swift`, `HeartRateStrap.swift` | nichts im Render-Thread |
| Kamera-Besitz | drei AVCaptureSessions; nur `CameraArbitration` darf entscheiden | `CameraPulseSource.swift`, `CameraCapture.swift`, `SkyCamera.swift`, `TakeCamera` | Core-Tests der Arbitration |
| Blitzgrenze | nur im Videofenster; fail-open, solange der Main-Thread hängt; Stream und Export gehen nicht hindurch | `App/Media/VideoMonitor.swift`, `Core/…/VideoFlashLimit.swift` | `VideoFlashLimitTests`, `VideoFlashCellsTests`; Gerät offen |
| Song-Format | gespeicherte Namen und Auswahl-Indizes sind eingefroren | `ProjectCodec.swift`, `docs/FORMAT.md` | `FormatGoldenTests`, `StoredNamesTests` |
| AUv3 ohne Engine | ein `import EchoelEngine` in Plugins/ zieht die Engine in die Erweiterung | `EchoelStudio/project.yml`, `Engine/Package.swift` | CI „Imports only where named“ und „Extension carries no engine code“; Hook |
| Netz nur wo eingeschaltet | CI prüft nur WO Netz-APIs stehen, nicht dass sie aus sind | 7 Dateien (studio.yml-Liste) | CI-Schritt; Hook |
| Körperdaten verlassen das Gerät | Health-Wert negiert, `shareableValue` = nil; MPE/Stream nur mit `bodyConsent` | `ModulationInputs.swift`, `AudioEngine.swift` | `ModulationInputsTests` |
| Export unabhängig von Sensoren | Live-Eingänge in `OfflineRender` brechen die Determinismus-Zusage | `MixModulation.swift` | `PhoneMotionExportTests` |
| Fremde Plugins | laufen IN unserem Render-Callback; Zustand nur an Speicherpunkten gesichert | `HostedUnit.swift`, `PluginHost.swift` | Zählung von Fehlern; nichts gegen langsame Units |
| Audio-Session, Routen, Rate | Unterbrechung oder neue Rate = neuer EngineCore, Playhead als Tick | `AudioEngine.swift` ~387–604, `RenderWatchdog.swift` | Engine-Tests der Teile; Gerät |

## 4. Systemgrenzen

- **Keine Swift-Toolchain in der Cloud-Sitzung.** Hier läuft nur Python 3; der Compiler ist die CI
  (`Echoel Studio`, studio.yml). `python3 EchoelStudio/Support/CI/swift_imports.py --selftest` läuft hier.
- **Kein Linter und kein Sanitizer für Studio** in der CI (`.swiftlint.yml` deckt nur die frühere App, nicht
  blockierend). Den Platz nimmt der Hook `.claude/hooks/verify-after-edit.py` ein, auf dem Mac dazu `swift test`.
- **Zeitmessung:** einzig `KernelLoadTests` liest eine Uhr und prüft nur VERHÄLTNISSE (Debug-Build). Keine
  Messung der Audio-Latenz, des Render-Budgets je Puffer oder von Leaks in Tests oder CI.
- **Gerät allein entscheidet:** Latenz (die App bittet um 48 kHz/512 Frames, iOS darf ablehnen; geloggt beim
  Start), Live-MIDI-Jitter bis ein Puffer (~10,7 ms), Bluetooth-Ausgabe 150–250 ms, Apple-Watch-Puls 4–5 s,
  Blitzgrenzen-Timing, ob der Start-Smoke überhaupt Audio rendert.
- **Kein C/C++ in Studio** (0 Dateien): die Render-Sicherheit ruht auf Swift-Disziplin, Review und Tests, nicht
  auf einer Sprachgrenze.
