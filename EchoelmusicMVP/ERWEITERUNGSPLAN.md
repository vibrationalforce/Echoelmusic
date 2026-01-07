# Echoelmusic MVP Erweiterungsplan

## Übersicht

Schrittweise Erweiterung des MVP von **1.575 Zeilen** zu einer vollständigen App.
Jede Phase ist in sich abgeschlossen und testbar.

```
Phase 1: Visualisierungen     (+800 Zeilen)  → 2.375 Zeilen
Phase 2: Audio Erweiterung    (+600 Zeilen)  → 2.975 Zeilen
Phase 3: Presets System       (+400 Zeilen)  → 3.375 Zeilen
Phase 4: MIDI Support         (+500 Zeilen)  → 3.875 Zeilen
Phase 5: Einstellungen        (+300 Zeilen)  → 4.175 Zeilen
Phase 6: Watch App            (+400 Zeilen)  → 4.575 Zeilen
```

---

## Phase 1: Visualisierungen (Woche 1)

### Ziel
3 weitere Visualisierungsmodi hinzufügen.

### Neue Dateien

```
Sources/EchoelmusicMVP/UI/
├── Visualizations/
│   ├── MandalaVisualization.swift      (NEU)
│   ├── ParticleVisualization.swift     (NEU)
│   ├── WaveformVisualization.swift     (NEU)
│   └── VisualizationType.swift         (NEU)
└── VisualizationPicker.swift           (NEU)
```

### Schritt 1.1: VisualizationType erstellen

**Datei:** `Sources/EchoelmusicMVP/UI/Visualizations/VisualizationType.swift`

```swift
import SwiftUI

public enum VisualizationType: String, CaseIterable, Identifiable {
    case coherence = "Coherence"
    case mandala = "Mandala"
    case particles = "Particles"
    case waveform = "Waveform"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .coherence: return "circle.hexagongrid"
        case .mandala: return "star.circle"
        case .particles: return "sparkles"
        case .waveform: return "waveform.path"
        }
    }

    public var description: String {
        switch self {
        case .coherence: return "Pulsierender Kohärenz-Ring"
        case .mandala: return "Rotierendes Mandala-Muster"
        case .particles: return "Bio-reaktive Partikel"
        case .waveform: return "Audio-Wellenform"
        }
    }
}
```

### Schritt 1.2: MandalaVisualization erstellen

**Datei:** `Sources/EchoelmusicMVP/UI/Visualizations/MandalaVisualization.swift`

```swift
import SwiftUI

public struct MandalaVisualization: View {
    let coherence: Double
    let heartRate: Double
    let isActive: Bool

    @State private var rotation: Double = 0
    @State private var scale: Double = 1.0

    private let petalCount = 12

    public var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            ZStack {
                // Äußere Blütenblätter
                ForEach(0..<petalCount, id: \.self) { index in
                    petal(index: index, size: size, layer: 0)
                }

                // Innere Blütenblätter
                ForEach(0..<petalCount, id: \.self) { index in
                    petal(index: index, size: size, layer: 1)
                }

                // Zentrum
                Circle()
                    .fill(centerGradient)
                    .frame(width: size * 0.15, height: size * 0.15)
                    .scaleEffect(scale)
            }
            .rotationEffect(.degrees(rotation))
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .onAppear { startAnimation() }
    }

    private func petal(index: Int, size: CGFloat, layer: Int) -> some View {
        let angle = Double(index) / Double(petalCount) * 360
        let layerScale = layer == 0 ? 1.0 : 0.6
        let layerRotation = layer == 0 ? 0.0 : 15.0

        return Ellipse()
            .fill(petalGradient(index: index))
            .frame(width: size * 0.12 * layerScale, height: size * 0.35 * layerScale)
            .offset(y: -size * 0.2 * layerScale)
            .rotationEffect(.degrees(angle + layerRotation))
            .opacity(0.7 + coherence * 0.3)
    }

    private func petalGradient(index: Int) -> LinearGradient {
        let hue = (Double(index) / Double(petalCount) + coherence * 0.5).truncatingRemainder(dividingBy: 1.0)
        return LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.7, brightness: 0.9),
                Color(hue: hue, saturation: 0.5, brightness: 0.6)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var centerGradient: RadialGradient {
        RadialGradient(
            colors: [.white, coherenceColor],
            center: .center,
            startRadius: 0,
            endRadius: 50
        )
    }

    private var coherenceColor: Color {
        Color(hue: coherence * 0.3, saturation: 0.8, brightness: 0.9)
    }

    private func startAnimation() {
        guard isActive else { return }

        // Rotation basierend auf Kohärenz
        withAnimation(.linear(duration: 20 / max(coherence, 0.2)).repeatForever(autoreverses: false)) {
            rotation = 360
        }

        // Puls basierend auf Herzfrequenz
        let pulseDuration = 60.0 / max(heartRate, 40)
        withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
            scale = 1.1
        }
    }
}
```

### Schritt 1.3: ParticleVisualization erstellen

**Datei:** `Sources/EchoelmusicMVP/UI/Visualizations/ParticleVisualization.swift`

```swift
import SwiftUI

public struct ParticleVisualization: View {
    let coherence: Double
    let heartRate: Double
    let isActive: Bool

    @State private var particles: [Particle] = []
    @State private var timer: Timer?

    private let maxParticles = 50

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .blur(radius: particle.size * 0.2)
                }
            }
            .onAppear {
                initializeParticles(in: geometry.size)
                startAnimation()
            }
            .onDisappear {
                timer?.invalidate()
            }
        }
    }

    private func initializeParticles(in size: CGSize) {
        particles = (0..<maxParticles).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -1...1),
                    y: CGFloat.random(in: -1...1)
                ),
                size: CGFloat.random(in: 4...12),
                color: randomColor(),
                opacity: Double.random(in: 0.3...0.8)
            )
        }
    }

    private func startAnimation() {
        guard isActive else { return }

        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            updateParticles()
        }
    }

    private func updateParticles() {
        for i in particles.indices {
            // Bewegung basierend auf Kohärenz
            let speed = 1.0 + coherence * 2.0
            particles[i].position.x += particles[i].velocity.x * speed
            particles[i].position.y += particles[i].velocity.y * speed

            // Bildschirmrand-Wrapping
            if particles[i].position.x < 0 { particles[i].position.x = 400 }
            if particles[i].position.x > 400 { particles[i].position.x = 0 }
            if particles[i].position.y < 0 { particles[i].position.y = 400 }
            if particles[i].position.y > 400 { particles[i].position.y = 0 }

            // Pulsieren basierend auf Herzfrequenz
            let pulse = sin(Date().timeIntervalSince1970 * heartRate / 30) * 0.3
            particles[i].opacity = 0.5 + pulse + coherence * 0.2
        }
    }

    private func randomColor() -> Color {
        Color(
            hue: Double.random(in: 0.5...0.8),
            saturation: 0.7,
            brightness: 0.9
        )
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var size: CGFloat
    var color: Color
    var opacity: Double
}
```

### Schritt 1.4: VisualizationPicker erstellen

**Datei:** `Sources/EchoelmusicMVP/UI/VisualizationPicker.swift`

```swift
import SwiftUI

public struct VisualizationPicker: View {
    @Binding var selectedType: VisualizationType

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(VisualizationType.allCases) { type in
                    Button(action: { selectedType = type }) {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 24))
                            Text(type.rawValue)
                                .font(.caption)
                        }
                        .foregroundColor(selectedType == type ? .white : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedType == type ? Color.blue.opacity(0.6) : Color.white.opacity(0.1))
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
```

### Schritt 1.5: ContentView aktualisieren

**Änderung in:** `Sources/EchoelmusicMVP/UI/ContentView.swift`

```swift
// Neue State-Variable hinzufügen:
@State private var selectedVisualization: VisualizationType = .coherence

// Im body, Visualization ersetzen:
Group {
    switch selectedVisualization {
    case .coherence:
        CoherenceVisualization(
            coherence: appState.currentCoherence,
            heartRate: appState.heartRate,
            isActive: appState.isSessionActive
        )
    case .mandala:
        MandalaVisualization(
            coherence: appState.currentCoherence,
            heartRate: appState.heartRate,
            isActive: appState.isSessionActive
        )
    case .particles:
        ParticleVisualization(
            coherence: appState.currentCoherence,
            heartRate: appState.heartRate,
            isActive: appState.isSessionActive
        )
    case .waveform:
        WaveformVisualization(
            coherence: appState.currentCoherence,
            heartRate: appState.heartRate,
            isActive: appState.isSessionActive
        )
    }
}
.frame(height: 300)

// Picker unter der Visualization hinzufügen:
VisualizationPicker(selectedType: $selectedVisualization)
    .padding(.top, 10)
```

### Schritt 1.6: Tests hinzufügen

**Datei:** `Tests/EchoelmusicMVPTests/VisualizationTests.swift`

```swift
import XCTest
@testable import EchoelmusicMVP

final class VisualizationTests: XCTestCase {

    func testVisualizationTypeCases() {
        XCTAssertEqual(VisualizationType.allCases.count, 4)
    }

    func testVisualizationIcons() {
        for type in VisualizationType.allCases {
            XCTAssertFalse(type.icon.isEmpty)
        }
    }

    func testVisualizationDescriptions() {
        for type in VisualizationType.allCases {
            XCTAssertFalse(type.description.isEmpty)
        }
    }
}
```

### Phase 1 Checkliste

- [ ] VisualizationType.swift erstellen
- [ ] MandalaVisualization.swift erstellen
- [ ] ParticleVisualization.swift erstellen
- [ ] WaveformVisualization.swift erstellen
- [ ] VisualizationPicker.swift erstellen
- [ ] ContentView.swift aktualisieren
- [ ] Tests schreiben
- [ ] Build testen: `swift build`
- [ ] Commit: `git commit -m "feat: Add 4 visualization modes"`

---

## Phase 2: Audio Erweiterung (Woche 2)

### Ziel
Binaural Beats und mehr Audio-Modi hinzufügen.

### Neue Dateien

```
Sources/EchoelmusicMVP/Audio/
├── BasicAudioEngine.swift          (existiert)
├── BinauralBeatEngine.swift        (NEU)
├── DroneEngine.swift               (NEU)
└── AudioMode.swift                 (NEU)
```

### Schritt 2.1: AudioMode erstellen

**Datei:** `Sources/EchoelmusicMVP/Audio/AudioMode.swift`

```swift
import Foundation

public enum AudioMode: String, CaseIterable, Identifiable {
    case tone = "Grundton"
    case binaural = "Binaural"
    case drone = "Drone"
    case silence = "Stille"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .tone: return "Einfacher bio-reaktiver Ton"
        case .binaural: return "Binaural Beats für Fokus/Entspannung"
        case .drone: return "Atmosphärischer Ambient-Klang"
        case .silence: return "Nur Visualisierung, kein Audio"
        }
    }

    public var icon: String {
        switch self {
        case .tone: return "waveform"
        case .binaural: return "headphones"
        case .drone: return "cloud"
        case .silence: return "speaker.slash"
        }
    }
}
```

### Schritt 2.2: BinauralBeatEngine erstellen

**Datei:** `Sources/EchoelmusicMVP/Audio/BinauralBeatEngine.swift`

```swift
import AVFoundation
import Foundation

public final class BinauralBeatEngine: ObservableObject {
    @Published public var isRunning = false
    @Published public var baseFrequency: Float = 200.0
    @Published public var beatFrequency: Float = 10.0  // Hz difference

    private var audioEngine: AVAudioEngine?
    private var leftNode: AVAudioSourceNode?
    private var rightNode: AVAudioSourceNode?

    private var leftPhase: Float = 0
    private var rightPhase: Float = 0

    private let sampleRate: Double = 44100

    public init() {}

    public func start() {
        guard !isRunning else { return }
        setupEngine()

        do {
            try audioEngine?.start()
            isRunning = true
        } catch {
            print("Binaural engine error: \(error)")
        }
    }

    public func stop() {
        audioEngine?.stop()
        audioEngine = nil
        isRunning = false
    }

    private func setupEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        // Stereo node für Binaural
        let binauralNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            return self.generateBinaural(frameCount: frameCount, audioBufferList: audioBufferList)
        }

        engine.attach(binauralNode)
        engine.connect(binauralNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.5
    }

    private func generateBinaural(
        frameCount: AVAudioFrameCount,
        audioBufferList: UnsafeMutablePointer<AudioBufferList>
    ) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

        let leftFreq = baseFrequency
        let rightFreq = baseFrequency + beatFrequency

        let leftIncrement = (leftFreq / Float(sampleRate)) * 2 * .pi
        let rightIncrement = (rightFreq / Float(sampleRate)) * 2 * .pi

        for frame in 0..<Int(frameCount) {
            let leftSample = sin(leftPhase) * 0.3
            let rightSample = sin(rightPhase) * 0.3

            // Stereo: Links = Kanal 0, Rechts = Kanal 1
            if ablPointer.count >= 2 {
                let leftBuf = ablPointer[0].mData?.assumingMemoryBound(to: Float.self)
                let rightBuf = ablPointer[1].mData?.assumingMemoryBound(to: Float.self)
                leftBuf?[frame] = leftSample
                rightBuf?[frame] = rightSample
            }

            leftPhase += leftIncrement
            rightPhase += rightIncrement

            if leftPhase > 2 * .pi { leftPhase -= 2 * .pi }
            if rightPhase > 2 * .pi { rightPhase -= 2 * .pi }
        }

        return noErr
    }

    /// Bio-reaktive Anpassung
    public func updateFromCoherence(_ coherence: Double) {
        // Höhere Kohärenz → niedrigere Beat-Frequenz (Alpha/Theta)
        // Niedrige Kohärenz → höhere Beat-Frequenz (Beta)
        if coherence > 0.7 {
            beatFrequency = 8.0  // Alpha (entspannt)
        } else if coherence > 0.4 {
            beatFrequency = 10.0 // Alpha (wach)
        } else {
            beatFrequency = 15.0 // Beta (fokussiert)
        }
    }
}
```

### Schritt 2.3: AppState erweitern

**Änderung in:** `Sources/EchoelmusicMVP/App/EchoelmusicMVPApp.swift`

```swift
// Neue Properties:
@Published var audioMode: AudioMode = .tone
let binauralEngine: BinauralBeatEngine

// In init():
self.binauralEngine = BinauralBeatEngine()

// In startSession():
switch audioMode {
case .tone:
    audioEngine.start()
case .binaural:
    binauralEngine.start()
case .drone:
    // DroneEngine starten
case .silence:
    break
}

// In stopSession():
audioEngine.stop()
binauralEngine.stop()
```

### Phase 2 Checkliste

- [ ] AudioMode.swift erstellen
- [ ] BinauralBeatEngine.swift erstellen
- [ ] DroneEngine.swift erstellen
- [ ] AppState erweitern
- [ ] Audio-Picker UI erstellen
- [ ] Tests schreiben
- [ ] Build testen
- [ ] Commit: `git commit -m "feat: Add binaural beats and drone audio"`

---

## Phase 3: Presets System (Woche 3)

### Ziel
Speicherbare Presets für Kombinationen aus Visualisierung + Audio.

### Neue Dateien

```
Sources/EchoelmusicMVP/
├── Presets/
│   ├── Preset.swift                (NEU)
│   ├── PresetManager.swift         (NEU)
│   └── DefaultPresets.swift        (NEU)
└── UI/
    └── PresetPicker.swift          (NEU)
```

### Schritt 3.1: Preset Model

**Datei:** `Sources/EchoelmusicMVP/Presets/Preset.swift`

```swift
import Foundation

public struct Preset: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var visualization: String  // VisualizationType.rawValue
    public var audioMode: String      // AudioMode.rawValue
    public var baseFrequency: Float
    public var volume: Float
    public var icon: String
    public var color: String          // Hex color

    public init(
        id: UUID = UUID(),
        name: String,
        visualization: String,
        audioMode: String,
        baseFrequency: Float = 432.0,
        volume: Float = 0.7,
        icon: String = "star",
        color: String = "#007AFF"
    ) {
        self.id = id
        self.name = name
        self.visualization = visualization
        self.audioMode = audioMode
        self.baseFrequency = baseFrequency
        self.volume = volume
        self.icon = icon
        self.color = color
    }
}
```

### Schritt 3.2: PresetManager

**Datei:** `Sources/EchoelmusicMVP/Presets/PresetManager.swift`

```swift
import Foundation

@MainActor
public final class PresetManager: ObservableObject {
    @Published public var presets: [Preset] = []
    @Published public var activePreset: Preset?

    private let storageKey = "echoelmusic_presets"

    public init() {
        loadPresets()
    }

    public func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Preset].self, from: data) {
            presets = decoded
        } else {
            presets = DefaultPresets.all
        }
    }

    public func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    public func addPreset(_ preset: Preset) {
        presets.append(preset)
        savePresets()
    }

    public func deletePreset(_ preset: Preset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }

    public func applyPreset(_ preset: Preset) {
        activePreset = preset
        // Notification senden für AppState
        NotificationCenter.default.post(
            name: .presetApplied,
            object: preset
        )
    }
}

extension Notification.Name {
    static let presetApplied = Notification.Name("presetApplied")
}
```

### Schritt 3.3: Default Presets

**Datei:** `Sources/EchoelmusicMVP/Presets/DefaultPresets.swift`

```swift
import Foundation

public struct DefaultPresets {
    public static let all: [Preset] = [
        Preset(
            name: "Meditation",
            visualization: "mandala",
            audioMode: "binaural",
            baseFrequency: 432.0,
            volume: 0.5,
            icon: "leaf",
            color: "#34C759"
        ),
        Preset(
            name: "Fokus",
            visualization: "particles",
            audioMode: "binaural",
            baseFrequency: 528.0,
            volume: 0.6,
            icon: "target",
            color: "#007AFF"
        ),
        Preset(
            name: "Entspannung",
            visualization: "coherence",
            audioMode: "drone",
            baseFrequency: 396.0,
            volume: 0.4,
            icon: "moon",
            color: "#5856D6"
        ),
        Preset(
            name: "Energie",
            visualization: "waveform",
            audioMode: "tone",
            baseFrequency: 639.0,
            volume: 0.7,
            icon: "bolt",
            color: "#FF9500"
        )
    ]
}
```

### Phase 3 Checkliste

- [ ] Preset.swift erstellen
- [ ] PresetManager.swift erstellen
- [ ] DefaultPresets.swift erstellen
- [ ] PresetPicker.swift UI erstellen
- [ ] AppState mit PresetManager verbinden
- [ ] Tests schreiben
- [ ] Build testen
- [ ] Commit: `git commit -m "feat: Add preset system"`

---

## Phase 4: MIDI Support (Woche 4)

### Ziel
MIDI Input für externe Controller (optional).

### Neue Dateien

```
Sources/EchoelmusicMVP/
├── MIDI/
│   ├── MIDIManager.swift           (NEU)
│   └── MIDIMapping.swift           (NEU)
```

### Schritt 4.1: MIDIManager

**Datei:** `Sources/EchoelmusicMVP/MIDI/MIDIManager.swift`

```swift
import Foundation
import CoreMIDI

@MainActor
public final class MIDIManager: ObservableObject {
    @Published public var isConnected = false
    @Published public var lastCC: (controller: UInt8, value: UInt8)?
    @Published public var availableDevices: [String] = []

    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0

    public var onCCReceived: ((UInt8, UInt8) -> Void)?
    public var onNoteReceived: ((UInt8, UInt8, Bool) -> Void)?

    public init() {
        setupMIDI()
    }

    private func setupMIDI() {
        let status = MIDIClientCreate("EchoelmusicMVP" as CFString, nil, nil, &midiClient)
        guard status == noErr else {
            print("MIDI client creation failed: \(status)")
            return
        }

        MIDIInputPortCreate(midiClient, "Input" as CFString, midiReadProc, Unmanaged.passUnretained(self).toOpaque(), &inputPort)

        // Alle Sources verbinden
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            MIDIPortConnectSource(inputPort, source, nil)
        }

        updateDeviceList()
        isConnected = sourceCount > 0
    }

    private func updateDeviceList() {
        var devices: [String] = []
        let sourceCount = MIDIGetNumberOfSources()

        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            var name: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &name)
            if let deviceName = name?.takeRetainedValue() as String? {
                devices.append(deviceName)
            }
        }

        availableDevices = devices
    }

    private let midiReadProc: MIDIReadProc = { packetList, readProcRefCon, srcConnRefCon in
        let manager = Unmanaged<MIDIManager>.fromOpaque(readProcRefCon!).takeUnretainedValue()

        let packets = packetList.pointee
        var packet = packets.packet

        for _ in 0..<packets.numPackets {
            let data = Mirror(reflecting: packet.data).children.map { $0.value as! UInt8 }

            if data[0] & 0xF0 == 0xB0 {
                // Control Change
                let controller = data[1]
                let value = data[2]
                Task { @MainActor in
                    manager.lastCC = (controller, value)
                    manager.onCCReceived?(controller, value)
                }
            } else if data[0] & 0xF0 == 0x90 {
                // Note On
                let note = data[1]
                let velocity = data[2]
                Task { @MainActor in
                    manager.onNoteReceived?(note, velocity, velocity > 0)
                }
            }

            packet = MIDIPacketNext(&packet).pointee
        }
    }
}
```

### Phase 4 Checkliste

- [ ] MIDIManager.swift erstellen
- [ ] MIDIMapping.swift erstellen
- [ ] MIDI-Einstellungen UI erstellen
- [ ] AppState mit MIDI verbinden
- [ ] Tests schreiben
- [ ] Build testen
- [ ] Commit: `git commit -m "feat: Add MIDI controller support"`

---

## Phase 5: Einstellungen (Woche 5)

### Ziel
Einstellungen-Screen mit allen Optionen.

### Neue Dateien

```
Sources/EchoelmusicMVP/UI/
├── Settings/
│   ├── SettingsView.swift          (NEU)
│   ├── AudioSettingsView.swift     (NEU)
│   ├── VisualSettingsView.swift    (NEU)
│   └── AboutView.swift             (NEU)
```

### Phase 5 Checkliste

- [ ] SettingsView.swift erstellen
- [ ] AudioSettingsView.swift erstellen
- [ ] VisualSettingsView.swift erstellen
- [ ] AboutView.swift erstellen (mit Disclaimer)
- [ ] Navigation hinzufügen
- [ ] UserDefaults für Persistenz
- [ ] Build testen
- [ ] Commit: `git commit -m "feat: Add settings screen"`

---

## Phase 6: Watch App (Woche 6)

### Ziel
Standalone watchOS App mit Kohärenz-Anzeige.

### Neue Dateien

```
Sources/EchoelmusicMVPWatch/
├── EchoelmusicWatchApp.swift       (NEU)
├── ContentView.swift               (NEU)
├── CoherenceGauge.swift            (NEU)
└── WatchHealthKit.swift            (NEU)
```

### Package.swift Erweiterung

```swift
platforms: [
    .iOS(.v15),
    .macOS(.v12),
    .watchOS(.v8)  // NEU
],
targets: [
    // ... existierende targets
    .target(
        name: "EchoelmusicMVPWatch",
        dependencies: [],
        path: "Sources/EchoelmusicMVPWatch"
    )
]
```

### Phase 6 Checkliste

- [ ] Watch target in Package.swift
- [ ] EchoelmusicWatchApp.swift
- [ ] Watch ContentView
- [ ] CoherenceGauge Complication
- [ ] WatchHealthKit Manager
- [ ] Build testen
- [ ] Commit: `git commit -m "feat: Add watchOS app"`

---

## Qualitätssicherung

### Nach jeder Phase

```bash
# 1. Build prüfen
cd EchoelmusicMVP
swift build

# 2. Tests ausführen
swift test

# 3. Lint (optional)
swiftlint

# 4. Commit
git add .
git commit -m "feat: Phase X complete"
git push
```

### Code Review Checkliste

- [ ] Keine Force-Unwraps (`!`)
- [ ] Alle public APIs dokumentiert
- [ ] Health Disclaimer vorhanden
- [ ] Fehlerbehandlung implementiert
- [ ] Tests für neue Features
- [ ] Accessibility Labels gesetzt

---

## Architektur-Regeln

### DO ✅

```swift
// Dependency Injection
init(healthKit: SimpleHealthKitManager) {
    self.healthKit = healthKit
}

// Protokolle für Testbarkeit
protocol AudioEngineProtocol {
    func start()
    func stop()
}

// Optionals sicher behandeln
if let value = optional {
    use(value)
}
```

### DON'T ❌

```swift
// Keine Singletons
static let shared = MyManager()  // ❌

// Keine Force-Unwraps
let value = optional!  // ❌

// Keine hardcodierten Strings
Text("Meditation")  // ❌ → Text(LocalizedStringKey("meditation"))
```

---

## Zeitplan Übersicht

| Woche | Phase | Zeilen | Gesamt |
|-------|-------|--------|--------|
| 1 | Visualisierungen | +800 | 2.375 |
| 2 | Audio | +600 | 2.975 |
| 3 | Presets | +400 | 3.375 |
| 4 | MIDI | +500 | 3.875 |
| 5 | Einstellungen | +300 | 4.175 |
| 6 | Watch | +400 | 4.575 |

**Endergebnis:** ~4.500 Zeilen sauberer, erweiterbarer Code.

---

## Support

Bei Fragen zur Implementierung:
1. Code aus dem Haupt-Echoelmusic als Referenz nutzen
2. Apple Developer Documentation
3. SwiftUI Tutorials

**Viel Erfolg!** 🎵
