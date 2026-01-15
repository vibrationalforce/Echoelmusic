# CLAUDE CODE MASTER - Echoelmusic

## Projektvision

**Echoelmusic** ist eine bio-reaktive Audio-Visual-Plattform, die biometrische Signale (HRV, Herzfrequenz, Atmung) in räumliches Audio, Echtzeit-Visualisierungen und LED/DMX-Beleuchtung transformiert.

## Ziel

- Cross-Platform: iOS, macOS, watchOS, tvOS, visionOS, Android, Windows, Linux
- Maximal stabil, skalierbar, produktionsreif
- Nobel Prize Multitrillion Dollar Quality

## Architektur-Dogmen

### 1. Platform-agnostischer Core
```
┌─────────────────────────────────────────────────────┐
│                    UI Layer                          │
│  (SwiftUI / Jetpack Compose / Qt / Web)             │
├─────────────────────────────────────────────────────┤
│                 Platform Bridge                      │
│  (Swift ↔ Kotlin ↔ C++ ↔ TypeScript)               │
├─────────────────────────────────────────────────────┤
│                   EchoelCore                         │
│  (Audio DSP, Bio Processing, State Management)      │
│  Pure algorithms - NO platform dependencies         │
└─────────────────────────────────────────────────────┘
```

### 2. UI strikt getrennt
- Business Logic: EchoelCore (platform-agnostic)
- UI: Thin layer per platform
- Kein UI-Code in Core, kein Core-Code in UI

### 3. Deterministischer State
- Unidirectional data flow
- Immutable state where possible
- All state transitions logged and testable

### 4. Real-Time First
- Audio Thread: Lock-free, no allocations
- Control Loop: 60 Hz guaranteed
- Network: Async, non-blocking

## Qualitätsregeln

### Code Quality
- **Kein Magic Code** - Alles explizit, keine versteckten Abhängigkeiten
- **Testbar** - Jede Funktion unit-testbar, DI everywhere
- **Dokumentiert** - Public APIs mit `///` Kommentaren
- **Typsicher** - Keine force unwraps (`!`), keine `Any` ohne Grund
- **Fehlerbehandlung** - `Result` types, keine silent failures

### Patterns
```swift
// RICHTIG
guard let value = optionalValue else {
    log.error("Value missing", category: .audio)
    return .failure(.missingValue)
}

// FALSCH
let value = optionalValue!  // CRASH RISK
let _ = try? something()    // SILENT FAILURE
```

### Performance
- Audio Latency: <10ms
- Control Loop: 60 Hz
- CPU Usage: <30%
- Memory: <200 MB

## Bio-Reactive Mapping Principles

```
HRV Coherence → Audio Harmonic Complexity
Heart Rate   → Tempo / Energy
Breathing    → Filter Modulation / Spatial Movement
Gaze         → Pan / Focus Point
Gesture      → Effect Intensity
```

## Verbotene Praktiken

1. **Keine Quick Hacks** - Immer richtige Lösung
2. **Keine JUCE Dependencies** - Native EchoelCore only
3. **Keine Platform-Specific Code in Core**
4. **Keine print() in Production** - Use Logger
5. **Keine fatalError()** - Graceful degradation
6. **Keine hardcoded Values** - Configuration/Constants

## Module Structure

```
Sources/
├── EchoelCore/           # Platform-agnostic core
│   ├── Audio/            # DSP, synthesis, effects
│   ├── Bio/              # Biofeedback processing
│   ├── State/            # State management
│   └── Protocols/        # Shared interfaces
├── Echoelmusic/          # Apple platforms
│   ├── iOS/
│   ├── macOS/
│   ├── watchOS/
│   ├── tvOS/
│   └── visionOS/
├── EchoelAndroid/        # Android
├── EchoelDesktop/        # Windows/Linux
└── EchoelWeb/            # WebAssembly/PWA
```

## Referenziere diese Datei

Bei jeder Arbeit im Repo gilt:
- Analysiere gegen diese Architektur-Dogmen
- Prüfe gegen Qualitätsregeln
- Folge LOOP_MODE.md für Arbeitsweise
