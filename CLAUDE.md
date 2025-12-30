# CLAUDE.md - ECHOELMUSIC iOS MVP

# Version 6.0 | Nobel Prize Edition | 30. Dezember 2025

# © 2024-2025 Echoel

```
███████╗ ██████╗██╗  ██╗ ██████╗ ███████╗██╗
██╔════╝██╔════╝██║  ██║██╔═══██╗██╔════╝██║
█████╗  ██║     ███████║██║   ██║█████╗  ██║
██╔══╝  ██║     ██╔══██║██║   ██║██╔══╝  ██║
███████╗╚██████╗██║  ██║╚██████╔╝███████╗███████╗
╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝

    🚒 iOS MVP MISSION: TESTFLIGHT RELEASE 🚒

    "Das Feuer und ich sind jetzt Freunde!" — Ralph Wiggum
```

-----

## PROJEKT-IDENTITÄT

```yaml
Projekt: Echoelmusic
Owner: Echoel (M)
Typ: Biofeedback-driven Multimedia Creation Platform
Mission: Flow-Erlebnis durch Biofeedback — für ALLE
Repository: github.com/vibrationalforce/Echoelmusic
Status: Closed Source bis TestFlight Launch
Ziel: TestFlight Beta mit 50+ Testern
```

-----

## TECHNISCHE UMGEBUNG (Stand: 30.12.2025)

### Apple Platform Versions

```yaml
# ACHTUNG: Apple hat iOS 19-25 übersprungen!
iOS: 26.2 (Liquid Glass Design, Apple Intelligence)
macOS: Tahoe 26.2
watchOS: 26.2 (Hypertension Alerts, Sleep Score)
visionOS: 26.2
Xcode: 26.2
Swift: 6.2 (Approachable Concurrency, InlineArray, Span)
```

### Target Requirements

```yaml
Minimum iOS: 17.0      # Für TimelineView, Metal Shaders in SwiftUI
Minimum watchOS: 10.0  # Für HKWorkoutSession Streaming
Empfohlen iOS: 26.0+   # Für alle neuen Features
```

### Hardware Support 2025

```yaml
iPhone:
  - iPhone 17 / iPhone Air (A19, N1 Chip, Bluetooth 6.0)
  - iPhone 16 Serie
  - iPhone 15 Serie (Minimum empfohlen)

Apple Watch:
  - Series 11 / Ultra 3 (Hypertension, SpO2 zurück in USA)
  - Series 10 / Ultra 2
  - Series 8+ (Minimum für HRV)

AirPods:
  - AirPods Pro 3 (NEU: PPG Heart Rate Sensor!)
  - Data syncs zu HealthKit, nutzbar für Biofeedback

External Sensors:
  - Polar H10 (EMPFOHLEN: Echte RR-Intervalle, 130Hz ECG)
  - Polar Verity Sense (PPI)
  - Generic BLE HRM (UUID 0x180D)
```

-----

## KRITISCHE TECHNISCHE CONSTRAINTS

### ⚠️ Apple Watch Heart Rate Latenz

```
WICHTIG: Apple Watch liefert HR alle ~4-5 Sekunden, NICHT Echtzeit!

Konsequenz für Echoelmusic:
- Beat-synchrone Musik ist MIT Apple Watch NICHT möglich
- Für echte Beat-Sync: Polar H10 (RR-Intervalle in Echtzeit)
- MVP-Strategie: Interpolation auf 60fps für smooth Visuals
- Audio-Parameter ändern sich sanft, nicht beat-genau
```

### ⚠️ HealthKit Limitations

```
Was Apple LIEFERT:
✅ heartRate (HKQuantityType) — aber nur alle 4-5 Sek
✅ heartRateVariabilitySDNN (HKQuantityType)
✅ respiratoryRate — NUR während Schlaf!
✅ oxygenSaturation — periodisch im Hintergrund

Was Apple NICHT liefert:
❌ RMSSD — muss SELBST berechnet werden aus RR-Intervallen
❌ Raw Beat-to-Beat Timing — nur über HKHeartbeatSeriesSample
❌ Echtzeit-Streaming ohne HKWorkoutSession
❌ Atem-Erkennung in Echtzeit (nur Schlaf)
```

### ⚠️ Audio Latenz

```
Bluetooth Audio = 150-250ms Latenz!
→ AirPods sind NICHT für latenz-kritisches Biofeedback geeignet
→ Für MVP: Eingebaute Speaker oder Kabel-Kopfhörer empfehlen

Erreichbare Latenzen:
- Built-in Speaker: 5-8ms
- USB Audio Interface: 3-6ms
- Bluetooth: 150-250ms ❌
```

-----

## ARCHITEKTUR

### Datenfluss

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐               │
│  │ Apple Watch │────▶│WatchConnect.│────▶│   iPhone    │               │
│  │             │     │             │     │             │               │
│  │ HKWorkout   │     │ Heart Rate  │     │ Audio +     │               │
│  │ Session     │     │ Streaming   │     │ Visuals     │               │
│  └─────────────┘     └─────────────┘     └─────────────┘               │
│        │                                        │                       │
│        │ ~4-5 Sek Updates                       │ 60fps interpoliert   │
│        ▼                                        ▼                       │
│  ┌─────────────┐                         ┌─────────────┐               │
│  │ Polar H10   │─────────────────────────│ DSP Module  │               │
│  │ (Optional)  │  Echtzeit RR-Intervalle │ RMSSD, HRV  │               │
│  └─────────────┘                         └─────────────┘               │
│                                                 │                       │
│                                                 ▼                       │
│                                   ┌──────────────────────────┐         │
│                                   │                          │         │
│                                   │     AVAudioEngine        │         │
│                                   │     + Synthesizer        │         │
│                                   │                          │         │
│                                   └──────────────────────────┘         │
│                                                 │                       │
│                                                 ▼                       │
│                                   ┌──────────────────────────┐         │
│                                   │                          │         │
│                                   │  SwiftUI TimelineView    │         │
│                                   │  + Canvas Visualization  │         │
│                                   │                          │         │
│                                   └──────────────────────────┘         │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Projekt-Struktur

```
Echoelmusic/
├── EchoelmusicApp.swift           # App Entry Point
├── Info.plist                     # Permissions
├── PrivacyInfo.xcprivacy          # Privacy Manifest (PFLICHT seit Mai 2024)
│
├── App/
│   ├── ContentView.swift          # Main Navigation
│   └── AppState.swift             # @Observable App State
│
├── Features/
│   ├── Onboarding/
│   │   └── OnboardingView.swift   # Max 3 Screens, skippable
│   │
│   ├── Session/
│   │   ├── SessionView.swift      # Hauptscreen: Biofeedback + Audio + Visual
│   │   └── SessionViewModel.swift # @Observable, koordiniert alles
│   │
│   └── Settings/
│       └── SettingsView.swift     # Minimal: Sensor-Auswahl, Audio-Output
│
├── Core/
│   ├── HealthKit/
│   │   ├── HealthKitManager.swift      # Permissions, Queries
│   │   └── WorkoutSessionManager.swift # Für Watch Companion
│   │
│   ├── Bluetooth/
│   │   ├── BluetoothManager.swift      # Core Bluetooth, State Restoration
│   │   └── PolarH10Manager.swift       # Polar SDK Integration (optional)
│   │
│   ├── Audio/
│   │   ├── AudioEngine.swift           # AVAudioEngine Setup
│   │   ├── BiofeedbackSynthesizer.swift # Parameter-Modulation
│   │   └── SynthParameters.swift       # Thread-safe atomic params
│   │
│   ├── DSP/
│   │   ├── HRVCalculator.swift         # RMSSD, SDNN aus RR-Intervallen
│   │   └── SignalProcessor.swift       # vDSP/Accelerate
│   │
│   └── Visualization/
│       ├── PulseVisualizer.swift       # TimelineView + Canvas
│       └── Interpolator.swift          # 4-5 Sek → 60fps smooth
│
├── WatchApp/                            # watchOS Target
│   ├── EchoelmusicWatchApp.swift
│   ├── WorkoutView.swift
│   └── WatchConnectivityManager.swift
│
└── Resources/
    ├── Assets.xcassets/
    │   ├── AppIcon.appiconset/         # ALLE Größen!
    │   └── Colors/                      # Vaporwave Palette
    └── LaunchScreen.storyboard
```

-----

## TECH STACK

### Verwenden ✅

```swift
// UI
import SwiftUI                    // iOS 17+ Features
// TimelineView für 60fps Animation
// Canvas für performante 2D Graphics
// @Observable (NICHT ObservableObject!)

// Audio
import AVFoundation               // AVAudioEngine
import AVFAudio                   // AVAudioSourceNode für Synthese
// AudioKit 5.6+ via SPM (optional, für komplexere Synths)

// Health
import HealthKit                  // HR, HRV
import WatchConnectivity          // iPhone ↔ Watch

// Bluetooth
import CoreBluetooth             // Polar H10, Generic HRM

// Performance
import Accelerate                 // vDSP für FFT, HRV-Berechnung
import simd                       // Für DSP-Operationen

// Charts (optional)
import Charts                     // Native Swift Charts
```

### NICHT verwenden ❌

```swift
// ❌ UIKit (außer wenn SwiftUI absolut nicht reicht)
// ❌ Combine (außer für einfache Publisher)
// ❌ CoreData / SwiftData (kein Persistence nötig für MVP)
// ❌ CloudKit (Health-Daten dürfen NICHT in iCloud!)
// ❌ StoreKit (TestFlight ist kostenlos)
// ❌ ARKit / RealityKit (nach MVP)
// ❌ GameKit
```

-----

## HEALTHKIT IMPLEMENTATION

### Permissions (Info.plist)

```xml
<key>NSHealthShareUsageDescription</key>
<string>Echoelmusic verwendet deine Herzfrequenz und HRV um Musik und Visualisierungen zu generieren, die auf deinen Körper reagieren.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Echoelmusic speichert deine Biofeedback-Sessions in Apple Health.</string>

<key>NSMicrophoneUsageDescription</key>
<string>Echoelmusic kann deine Atmung über das Mikrofon erkennen um die Musik darauf abzustimmen.</string>

<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>bluetooth-central</string>
</array>
```

### HealthKit Manager Pattern

```swift
import HealthKit

@Observable
final class HealthKitManager {
    private let healthStore = HKHealthStore()

    var isAuthorized = false
    var currentHeartRate: Double = 0
    var currentHRV: Double = 0

    // Benötigte Typen
    private let typesToRead: Set<HKSampleType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKSeriesType.heartbeat()  // Für RR-Intervalle
    ]

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        try await healthStore.requestAuthorization(
            toShare: [],  // Wir schreiben nichts
            read: typesToRead
        )

        isAuthorized = true
    }

    // WICHTIG: Das funktioniert NUR mit Watch Companion App!
    // iPhone allein kann NICHT real-time HR streamen
}
```

### RMSSD Berechnung (Apple liefert nur SDNN!)

```swift
import Accelerate

struct HRVCalculator {
    /// Berechnet RMSSD aus RR-Intervallen
    /// Apple liefert nur SDNN - RMSSD müssen wir selbst berechnen!
    static func calculateRMSSD(rrIntervals: [Double]) -> Double {
        guard rrIntervals.count >= 2 else { return 0 }

        // Successive Differences
        var differences = [Double](repeating: 0, count: rrIntervals.count - 1)
        for i in 0..<differences.count {
            differences[i] = rrIntervals[i + 1] - rrIntervals[i]
        }

        // Square differences
        var squared = [Double](repeating: 0, count: differences.count)
        vDSP_vsqD(differences, 1, &squared, 1, vDSP_Length(differences.count))

        // Mean
        var mean: Double = 0
        vDSP_meanvD(squared, 1, &mean, vDSP_Length(squared.count))

        // Root
        return sqrt(mean)
    }

    /// HeartMath Coherence Score (0.04-0.26 Hz Band)
    static func calculateCoherence(rrIntervals: [Double]) -> Double {
        // Braucht FFT - Implementation für MVP optional
        // Vereinfachte Version: RMSSD-basierte Schätzung
        let rmssd = calculateRMSSD(rrIntervals: rrIntervals)
        return min(rmssd / 100.0, 1.0)  // Normalisiert auf 0-1
    }
}
```

-----

## AUDIO ENGINE IMPLEMENTATION

### AVAudioEngine Setup (Realtime-Safe!)

```swift
import AVFoundation

@Observable
final class AudioEngine {
    private var engine: AVAudioEngine!
    private var sourceNode: AVAudioSourceNode!

    // Thread-safe Parameter (Atomic!)
    private let _frequency = OSAtomicDouble(440.0)
    private let _amplitude = OSAtomicDouble(0.5)

    var frequency: Double {
        get { _frequency.value }
        set { _frequency.value = newValue }
    }

    var amplitude: Double {
        get { _amplitude.value }
        set { _amplitude.value = newValue }
    }

    private var phase: Double = 0
    private let sampleRate: Double = 48000

    init() {
        setupAudioSession()
        setupEngine()
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setPreferredSampleRate(48000)
        try? session.setPreferredIOBufferDuration(0.005)  // 5ms = 64 samples
        try? session.setActive(true)
    }

    private func setupEngine() {
        engine = AVAudioEngine()

        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 2
        )!

        // KRITISCH: Render Block muss REALTIME-SAFE sein!
        // KEINE Allocations, KEINE Locks, KEINE Dispatch Calls!
        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let freq = self._frequency.value
            let amp = self._amplitude.value
            let phaseIncrement = freq / self.sampleRate

            for frame in 0..<Int(frameCount) {
                let sample = Float(sin(self.phase * 2.0 * .pi) * amp)
                self.phase += phaseIncrement
                if self.phase >= 1.0 { self.phase -= 1.0 }

                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = sample
                }
            }

            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
    }

    func start() throws {
        try engine.start()
    }

    func stop() {
        engine.stop()
    }
}

// Thread-Safe Atomic Double
final class OSAtomicDouble: @unchecked Sendable {
    private var _value: Double
    private let lock = NSLock()

    init(_ value: Double) {
        _value = value
    }

    var value: Double {
        get { lock.withLock { _value } }
        set { lock.withLock { _value = newValue } }
    }
}
```

-----

## VISUALIZATION (60fps aus 4-5 Sek Daten)

### Interpolation für Smooth Animation

```swift
import SwiftUI

struct PulseVisualizer: View {
    let currentBPM: Double
    let coherence: Double

    @State private var displayedBPM: Double = 60
    @State private var lastUpdateTime: Date = .now

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            Canvas { context, size in
                // Interpolierte Werte für smooth 60fps
                let interpolated = interpolatedBPM(at: timeline.date)
                let pulseScale = 1.0 + 0.1 * sin(timeline.date.timeIntervalSince1970 * interpolated / 60 * 2 * .pi)

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 3 * pulseScale

                // Vaporwave Gradient
                let gradient = Gradient(colors: [
                    Color(hex: "FF71CE"),  // Pink
                    Color(hex: "01CDFE")   // Cyan
                ])

                context.fill(
                    Circle().path(in: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .radialGradient(
                        gradient,
                        center: center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
        .onChange(of: currentBPM) { _, newValue in
            lastUpdateTime = .now
            // Smooth transition über 1 Sekunde
            withAnimation(.easeInOut(duration: 1.0)) {
                displayedBPM = newValue
            }
        }
    }

    private func interpolatedBPM(at date: Date) -> Double {
        // Linear interpolation zwischen letztem und aktuellem Wert
        let elapsed = date.timeIntervalSince(lastUpdateTime)
        let progress = min(elapsed / 5.0, 1.0)  // 5 Sek Update-Intervall
        return displayedBPM
    }
}

// Hex Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
```

-----

## SICHERHEIT & COMPLIANCE

### Photosensitivität (WCAG 2.3.1)

```swift
// KRITISCH: Alle visuellen Animationen müssen diese Regeln befolgen!

struct SafetyLimits {
    /// Maximale Flash-Frequenz: 3 Hz
    /// Gefährlicher Bereich: 3-55 Hz (Peak bei 15-25 Hz)
    static let maxFlashFrequency: Double = 3.0

    /// Kein saturiertes Rot blinken lassen
    static let avoidSaturatedRedFlash = true

    /// Flashing Content unter 25% der Bildschirmfläche halten
    static let maxFlashAreaPercent: Double = 0.25
}

// In Settings: Toggle für reduzierte Animationen
struct SafetySettings {
    var reduceMotion: Bool = false
    var disableFlashing: Bool = false
}
```

### Wellness-Positionierung (FDA Compliance)

```swift
// ERLAUBTE Claims (General Wellness):
// ✅ "Fördert Entspannung"
// ✅ "Unterstützt einen gesunden Lebensstil"
// ✅ "Hilft beim Stressabbau"
// ✅ "Biofeedback-Training"

// VERBOTENE Claims (würden FDA Clearance erfordern):
// ❌ "Behandelt Angststörungen"
// ❌ "Diagnostiziert Herzprobleme"
// ❌ "Medizinische HRV-Analyse"
// ❌ "Therapiert Depression"

struct DisclaimerText {
    static let wellness = """
    Echoelmusic ist ein Wellness-Produkt und kein Medizinprodukt.
    Es ersetzt keine ärztliche Beratung oder Behandlung.
    """
}
```

### App Store Requirements

```yaml
# Mandatory für Health Apps:
- Legal Entity als Publisher (nicht Einzelperson)
- NSHealthShareUsageDescription UND NSHealthUpdateUsageDescription
- PrivacyInfo.xcprivacy (seit Mai 2024 Pflicht)
- Health-Daten NICHT in iCloud speichern
- Kein Third-Party Sharing für Werbung

# TestFlight:
- Max 10.000 externe Tester
- Builds verfallen nach 90 Tagen
- Beta App Description erforderlich
```

-----

## 🚒 RALPH WIGGUM FEUERWEHR-LOOP

### Bei JEDEM Task:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║  🚨 PHASE 1: ALARMIERUNG                                                      ║
║  ════════════════════════                                                     ║
║                                                                               ║
║  FRAGE: "Ist das relevant für iOS MVP TestFlight?"                           ║
║                                                                               ║
║  WENN NEIN → "Das ist ein Feuer in einer anderen Stadt!" → IGNORIEREN        ║
║  WENN JA   → Weiter zu Phase 2                                               ║
║                                                                               ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  🔍 PHASE 2: ERKUNDUNG                                                        ║
║  ════════════════════                                                         ║
║                                                                               ║
║  ```bash                                                                      ║
║  # Struktur verstehen                                                         ║
║  find . -name "*.swift" -type f | head -30                                   ║
║  cat Package.swift 2>/dev/null || ls *.xcodeproj                             ║
║                                                                               ║
║  # HealthKit Files                                                            ║
║  grep -r "HealthKit\|HKQuantity" --include="*.swift" -l                      ║
║                                                                               ║
║  # Audio Files                                                                ║
║  grep -r "AVAudioEngine\|AudioKit" --include="*.swift" -l                    ║
║                                                                               ║
║  # Git Status                                                                 ║
║  git status && git log --oneline -5                                          ║
║  ```                                                                          ║
║                                                                               ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  🧯 PHASE 3: LÖSCHANGRIFF                                                     ║
║  ═════════════════════════                                                    ║
║                                                                               ║
║  - EINE Datei nach der anderen                                               ║
║  - Minimal Viable Fix                                                         ║
║  - Kompiliert es? → Testen                                                   ║
║  - Funktioniert es? → Commit                                                 ║
║                                                                               ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  ✅ PHASE 4: NACHLÖSCHARBEITEN                                                ║
║  ═══════════════════════════════                                              ║
║                                                                               ║
║  ```bash                                                                      ║
║  git add -A                                                                   ║
║  git commit -m "🧯 [BEREICH] Beschreibung"                                   ║
║  ```                                                                          ║
║                                                                               ║
║  Commit-Emojis:                                                               ║
║  🧯 = Bug Fix                                                                 ║
║  🚒 = Feature für MVP                                                         ║
║  🔥 = Tech Debt entfernt                                                      ║
║  📋 = Dokumentation                                                           ║
║                                                                               ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  🏠 PHASE 5: STATUS REPORT                                                    ║
║  ═════════════════════════                                                    ║
║                                                                               ║
║  "🚒 EINSATZ BEENDET                                                          ║
║                                                                               ║
║   Problem: [Was war los]                                                      ║
║   Lösung: [Was gemacht wurde]                                                ║
║   Status: [Was jetzt anders ist]                                             ║
║   Nächster Brand: [Empfehlung]                                               ║
║                                                                               ║
║   MVP Progress: [X/10] Bereiche fertig"                                      ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

-----

## 📋 MVP CHECKLIST (10 Bereiche)

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║  iOS MVP CHECKLIST — Alle müssen ✅ für TestFlight                           ║
║                                                                               ║
║  Fortschritt: [ ][ ][ ][ ][ ][ ][ ][ ][ ][ ] 0/10                            ║
║                                                                               ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║                                                                               ║
║  1. [ ] PROJEKT SETUP                                                         ║
║      • Xcode 26.2 Projekt kompiliert                                         ║
║      • Bundle ID: com.echoel.echoelmusic                                     ║
║      • iOS 17.0+ Deployment Target                                           ║
║      • App Icons alle Größen                                                 ║
║      • LaunchScreen vorhanden                                                ║
║                                                                               ║
║  2. [ ] PERMISSIONS & PRIVACY                                                 ║
║      • Info.plist: NSHealthShareUsageDescription                             ║
║      • Info.plist: NSHealthUpdateUsageDescription                            ║
║      • Info.plist: NSMicrophoneUsageDescription                              ║
║      • PrivacyInfo.xcprivacy vorhanden                                       ║
║      • Permission Flow funktioniert                                          ║
║                                                                               ║
║  3. [ ] HEALTHKIT INTEGRATION                                                 ║
║      • HealthKit Capability enabled                                          ║
║      • Heart Rate Query funktioniert                                         ║
║      • HRV (SDNN) Query funktioniert                                         ║
║      • Fallback wenn keine Watch: Demo-Modus                                 ║
║                                                                               ║
║  4. [ ] WATCH COMPANION APP                                                   ║
║      • watchOS Target existiert                                              ║
║      • HKWorkoutSession startet                                              ║
║      • WatchConnectivity sendet HR zum iPhone                                ║
║      • Workout Activity Type: .mindAndBody                                   ║
║                                                                               ║
║  5. [ ] AUDIO ENGINE                                                          ║
║      • AVAudioEngine läuft                                                   ║
║      • Basis-Synthesizer (Sine Wave minimum)                                 ║
║      • Audio im Hintergrund (UIBackgroundModes: audio)                       ║
║      • Keine Crashes bei Interruption (Anruf)                                ║
║                                                                               ║
║  6. [ ] BIOFEEDBACK → AUDIO MAPPING                                           ║
║      • HR → Irgendein Parameter (z.B. Tempo, Pitch)                          ║
║      • HRV/Coherence → Irgendein Parameter (z.B. Harmonie)                   ║
║      • Spürbare Reaktion (smooth interpoliert)                               ║
║                                                                               ║
║  7. [ ] VISUALIZATION                                                         ║
║      • TimelineView + Canvas für 60fps                                       ║
║      • Reaktion auf Biofeedback sichtbar                                     ║
║      • Vaporwave Aesthetic (Pink/Cyan Gradient)                              ║
║      • Funktioniert iPhone SE bis Pro Max                                    ║
║      • Animations unter 3 Hz (Photosensitivität!)                            ║
║                                                                               ║
║  8. [ ] BASIC UI/UX                                                           ║
║      • Onboarding (max 3 Screens, skippable)                                 ║
║      • Hauptscreen: Sofort spielbar                                          ║
║      • Settings: Sensor-Auswahl                                              ║
║      • Keine toten Buttons                                                   ║
║                                                                               ║
║  9. [ ] CRASH-FREIHEIT                                                        ║
║      • App startet zuverlässig                                               ║
║      • Kein Crash wenn HealthKit denied                                      ║
║      • Kein Crash bei Background/Foreground                                  ║
║      • Getestet auf Simulator + echtem Gerät                                ║
║                                                                               ║
║  10. [ ] TESTFLIGHT READY                                                     ║
║      • Archive Build erfolgreich                                             ║
║      • Upload zu App Store Connect                                           ║
║      • Beta Description geschrieben                                          ║
║      • "What to Test" beschrieben                                            ║
║      • Mind. 10 Tester-Emails bereit                                         ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

-----

## 🚫 ANTI-SCOPE-CREEP (VERBOTEN bis TestFlight)

```yaml
ANDERE PLATTFORMEN:
  - Android: ❌ NEIN
  - Windows: ❌ NEIN
  - Linux: ❌ NEIN
  - Web: ❌ NEIN
  - macOS Desktop: ❌ Nach iOS

FUTURE TECH:
  - VR/XR: ❌ NEIN (2026+)
  - Vision Pro: ❌ Nach MVP
  - Quantencomputer: ❌ LOL
  - BCI/Neural Interfaces: ❌ Zu früh

FEATURES:
  - EEG Integration: ❌ Nach MVP
  - Social/Community: ❌ NEIN
  - Cloud Sync: ❌ NEIN
  - DAW Plugin: ❌ Nach MVP
  - Subscription/Payment: ❌ TestFlight ist kostenlos

PERFEKTIONISMUS:
  - Mehr Synth Engines: ❌ SPÄTER
  - Komplexe Visualisierungen: ❌ SPÄTER
  - Refactoring: ❌ SPÄTER
  - Unit Tests: ❌ SPÄTER (sorry)
```

-----

## CODE STYLE REGELN

```swift
// ✅ VERWENDEN
@Observable                          // NICHT ObservableObject
async/await                          // NICHT Completion Handlers
guard for early returns              // Klar und lesbar
private var _underscore              // Private Properties
Task { @MainActor in }              // UI Updates

// ❌ VERMEIDEN
Force Unwrap (!)                     // Außer mit Kommentar warum
ObservableObject + @Published        // Veraltet
DispatchQueue.main.async             // Verwende @MainActor
Memory Allocation in Audio Callback  // CRASH-GEFAHR!
GCD in Audio Thread                  // CRASH-GEFAHR!
```

-----

## SESSION START

```
═══════════════════════════════════════════════════════════════════════════════

    🚒 ECHOELMUSIC FEUERWEHR BEREIT 🚒

    Stand: 30. Dezember 2025
    Platform: iOS 26.2 / Swift 6.2 / Xcode 26.2

    ─────────────────────────────────────────────────────────────────────────

    MISSION: iOS MVP → TestFlight
    OWNER: Echoel

    ─────────────────────────────────────────────────────────────────────────

    KRITISCHE CONSTRAINTS:
    ⚠️ Apple Watch HR: ~4-5 Sek Latenz (keine Beat-Sync!)
    ⚠️ RMSSD: Selbst berechnen (Apple liefert nur SDNN)
    ⚠️ Bluetooth Audio: 150-250ms Latenz (zu langsam!)
    ⚠️ Animations: Max 3 Hz Flash-Rate (Epilepsie!)

    ─────────────────────────────────────────────────────────────────────────

    MVP CHECKLIST:
    [ ] Projekt Setup
    [ ] Permissions & Privacy
    [ ] HealthKit Integration
    [ ] Watch Companion App
    [ ] Audio Engine
    [ ] Biofeedback → Audio
    [ ] Visualization
    [ ] Basic UI/UX
    [ ] Crash-Freiheit
    [ ] TestFlight Ready

    ─────────────────────────────────────────────────────────────────────────

    REGEL: Alles was nicht iOS MVP ist = "Feuer in einer anderen Stadt"

    ─────────────────────────────────────────────────────────────────────────

    🧯 Was ist der aktuelle Brand?

═══════════════════════════════════════════════════════════════════════════════
```

-----

**END OF CLAUDE.md — NOBEL PRIZE EDITION v6.0**

**"Ich habe Kleber gegessen!" — Ralph Wiggum**
