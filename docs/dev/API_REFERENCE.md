# Echoelmusic API Reference

Version: 10000.0.0 (Ultimate Ralph Wiggum Loop Mode)
Released: 2026-01-06

## Table of Contents

1. [UnifiedControlHub](#unifiedcontrolhub)
2. [AudioEngine](#audioengine)
3. [SpatialAudioEngine](#spatialaudioengine)
4. [HealthKitManager](#healthkitmanager)
5. [QuantumLightEmulator](#quantumlightemulator)
6. [Plugin SDK](#plugin-sdk)
7. [StreamEngine](#streamengine)
8. [WorldwideCollaborationHub](#worldwidecollaborationhub)
9. [CinematicScoringEngine](#cinematicscoringengine)
10. [ProductionConfiguration](#productionconfiguration)
11. [HardwareEcosystem](#hardwareecosystem)

---

## UnifiedControlHub

**Category:** Core
**Platforms:** iOS, macOS, visionOS

Central orchestrator for all input modalities (bio, gesture, face, gaze, MIDI)

### Properties

- **`activeInputMode`** (`@Published InputMode`, read-only): Current active input priority (touch, gesture, face, gaze, bio)
- **`conflictResolved`** (`@Published Bool`, read-only): Whether input conflicts were successfully resolved
- **`controlLoopFrequency`** (`@Published Double`, read-only): Current control loop frequency in Hz (target: 60)

### Methods

#### `init`

```swift
init(audioEngine: AudioEngine? = nil)
```

Initialize the unified control hub with optional audio engine

**Parameters:**
- `audioEngine` (`AudioEngine?`): Audio engine to control (default: `nil`)

**Returns:** `UnifiedControlHub`

**Example:**

```swift
let audioEngine = AudioEngine(microphoneManager: micManager)
let hub = UnifiedControlHub(audioEngine: audioEngine)
```

#### `start`

```swift
func start()
```

Start the 60Hz control loop and all enabled input modalities

**Returns:** `Void`

**Example:**

```swift
hub.start()
// Control loop now running at 60 Hz
```

#### `stop`

```swift
func stop()
```

Stop the control loop and disable all input sources

**Returns:** `Void`

**Example:**

```swift
hub.stop()
```

#### `enableFaceTracking`

```swift
func enableFaceTracking()
```

Enable ARKit face tracking integration for facial expression → audio mapping

**Returns:** `Void`

**Example:**

```swift
hub.enableFaceTracking()
// Face expressions now control audio parameters
```

#### `enableHandTracking`

```swift
func enableHandTracking()
```

Enable hand gesture tracking for gesture → audio mapping

**Returns:** `Void`

**Example:**

```swift
hub.enableHandTracking()
// Hand gestures now control spatial position and effects
```

#### `enableBiometricMonitoring`

```swift
func enableBiometricMonitoring() async throws
```

Enable HealthKit biometric monitoring (HRV, heart rate, coherence)

**Returns:** `Void`

**Throws:** HealthKit authorization errors

**Example:**

```swift
do {
    try await hub.enableBiometricMonitoring()
    // HRV coherence now controls spatial field geometry
} catch {
    print("Failed to enable biometrics: \(error)")
}
```

#### `setCoherence`

```swift
func setCoherence(_ value: Double)
```

Manually set coherence value (0-100) for testing or external bio sources

**Parameters:**
- `value` (`Double`): Coherence score 0-100

**Returns:** `Void`

**Example:**

```swift
hub.setCoherence(85.0)
// High coherence → Fibonacci spatial field
```

#### `getCoherence`

```swift
func getCoherence() -> Double
```

Get current coherence value

**Returns:** `Double`

**Example:**

```swift
let coherence = hub.getCoherence()
print("Current coherence: \(coherence)%")
```

---

## AudioEngine

**Category:** Audio
**Platforms:** iOS, macOS, watchOS, tvOS

Central audio processing engine managing microphone, Multidimensional Brainwave Entrainment, effects, and mixing

### Properties

- **`isRunning`** (`@Published Bool`, read-only): Whether the audio engine is currently running
- **`binauralBeatsEnabled`** (`@Published Bool`, read-only): Whether Multidimensional Brainwave Entrainment are enabled
- **`spatialAudioEnabled`** (`@Published Bool`, read-only): Whether spatial audio is enabled
- **`currentBrainwaveState`** (`@Published BrainwaveState`, read-only): Current binaural beat brainwave state
- **`binauralAmplitude`** (`@Published Float`, read-only): Multidimensional Brainwave Entrainment volume (0.0 - 1.0)

### Methods

#### `init`

```swift
init(microphoneManager: MicrophoneManager)
```

Initialize audio engine with microphone manager

**Parameters:**
- `microphoneManager` (`MicrophoneManager`): Microphone input manager

**Returns:** `AudioEngine`

**Example:**

```swift
let micManager = MicrophoneManager()
let audioEngine = AudioEngine(microphoneManager: micManager)
```

#### `start`

```swift
func start()
```

Start the audio engine (microphone, Multidimensional Brainwave Entrainment, spatial audio)

**Returns:** `Void`

**Example:**

```swift
audioEngine.start()
// Audio engine now running
```

#### `setBrainwaveState`

```swift
func setBrainwaveState(_ state: BinauralBeatGenerator.BrainwaveState)
```

Set target brainwave state for Multidimensional Brainwave Entrainment

**Parameters:**
- `state` (`BrainwaveState`): Target brainwave state (delta, theta, alpha, beta, gamma)

**Returns:** `Void`

**Example:**

```swift
// Alpha waves for relaxation (8-12 Hz)
audioEngine.setBrainwaveState(.alpha)

// Theta waves for meditation (4-8 Hz)
audioEngine.setBrainwaveState(.theta)

// Gamma waves for focus (32-100 Hz)
audioEngine.setBrainwaveState(.gamma)
```

#### `addEffect`

```swift
func addEffect(_ effect: AudioEffect) -> UUID
```

Add an audio effect to the processing chain

**Parameters:**
- `effect` (`AudioEffect`): Effect to add (reverb, delay, filter, etc.)

**Returns:** `UUID`

**Example:**

```swift
let reverbEffect = ReverbEffect(roomSize: 0.8, damping: 0.5)
let effectId = audioEngine.addEffect(reverbEffect)
```

---

## SpatialAudioEngine

**Category:** Audio
**Platforms:** iOS, macOS, visionOS

3D/4D spatial audio rendering with head tracking and bio-reactive field geometries

### Properties

- **`isActive`** (`@Published Bool`, read-only): Whether spatial audio is active
- **`currentMode`** (`@Published SpatialMode`, read-only): Current spatial rendering mode
- **`headTrackingEnabled`** (`@Published Bool`, read-only): Whether head tracking is enabled
- **`spatialSources`** (`@Published [SpatialSource]`, read-only): Array of active spatial sources

### Methods

#### `start`

```swift
func start() throws
```

Start the spatial audio engine

**Returns:** `Void`

**Throws:** Audio session configuration errors

**Example:**

```swift
do {
    try spatialEngine.start()
} catch {
    print("Failed to start spatial audio: \(error)")
}
```

#### `addSource`

```swift
func addSource(position: SIMD3<Float>, amplitude: Float = 1.0, frequency: Float = 440.0) -> UUID
```

Add a spatial audio source at a 3D position

**Parameters:**
- `position` (`SIMD3<Float>`): 3D position (x, y, z)
- `amplitude` (`Float`): Source amplitude (default: `1.0`)
- `frequency` (`Float`): Source frequency in Hz (default: `440.0`)

**Returns:** `UUID`

**Example:**

```swift
// Add source 2 meters in front, 1 meter up
let sourceId = spatialEngine.addSource(
    position: SIMD3<Float>(0, 1, -2),
    amplitude: 0.8,
    frequency: 432.0
)
```

#### `setFieldGeometry`

```swift
func setFieldGeometry(_ geometry: FieldGeometry, sourceCount: Int = 8)
```

Set the spatial field geometry for algorithmic source placement

**Parameters:**
- `geometry` (`FieldGeometry`): Geometry type (circle, sphere, fibonacci, grid)
- `sourceCount` (`Int`): Number of sources to create (default: `8`)

**Returns:** `Void`

**Example:**

```swift
// Bio-reactive: High coherence → Fibonacci spiral
if coherence > 60 {
    spatialEngine.setFieldGeometry(.fibonacci, sourceCount: 13)
} else {
    spatialEngine.setFieldGeometry(.grid, sourceCount: 9)
}
```

---

## HealthKitManager

**Category:** Biofeedback
**Platforms:** iOS, watchOS

Real-time HealthKit integration for HRV, heart rate, and HeartMath coherence monitoring

### Properties

- **`heartRate`** (`@Published Double`, read-only): Current heart rate in BPM
- **`hrvRMSSD`** (`@Published Double`, read-only): HRV RMSSD in milliseconds
- **`hrvCoherence`** (`@Published Double`, read-only): HeartMath coherence score (0-100)
- **`breathingRate`** (`@Published Double`, read-only): Estimated breathing rate in breaths/minute
- **`isAuthorized`** (`@Published Bool`, read-only): Whether HealthKit authorization is granted
- **`errorMessage`** (`@Published String?`, read-only): Error message if monitoring fails

### Methods

#### `requestAuthorization`

```swift
func requestAuthorization() async throws
```

Request HealthKit authorization for heart rate and HRV access

**Returns:** `Void`

**Throws:** HealthKit authorization errors

**Example:**

```swift
let healthKit = HealthKitManager()

do {
    try await healthKit.requestAuthorization()
    if healthKit.isAuthorized {
        print("✅ HealthKit authorized")
    }
} catch {
    print("❌ Authorization failed: \(error)")
}
```

#### `startMonitoring`

```swift
func startMonitoring()
```

Start real-time monitoring of heart rate and HRV

**Returns:** `Void`

**Example:**

```swift
healthKit.startMonitoring()
// Now receiving real-time HRV updates
```

#### `getCoherence`

```swift
func getCoherence() -> Double
```

Get HeartMath coherence score (0-100)

**Returns:** `Double`

**Example:**

```swift
let coherence = healthKit.getCoherence()

if coherence > 60 {
    print("High coherence - optimal state")
} else if coherence > 40 {
    print("Medium coherence - transitional")
} else {
    print("Low coherence - stressed")
}
```

---

## QuantumLightEmulator

**Category:** Quantum
**Platforms:** iOS, macOS, visionOS, tvOS

Quantum-inspired audio processing and photonics visualization engine

### Properties

- **`currentMode`** (`@Published EmulationMode`, read-only): Current quantum emulation mode
- **`coherence`** (`@Published Float`, read-only): Quantum coherence level (0.0 - 1.0)
- **`isActive`** (`@Published Bool`, read-only): Whether quantum processing is active
- **`currentState`** (`@Published QuantumAudioState`, read-only): Current quantum audio state

### Methods

#### `setMode`

```swift
func setMode(_ mode: EmulationMode)
```

Set quantum emulation mode

**Parameters:**
- `mode` (`EmulationMode`): Emulation mode (classical, quantumInspired, fullQuantum, hybridPhotonic, bioCoherent)

**Returns:** `Void`

**Example:**

```swift
// Bio-reactive quantum processing
emulator.setMode(.bioCoherent)

// Quantum-inspired superposition
emulator.setMode(.quantumInspired)

// Full quantum (future hardware ready)
emulator.setMode(.fullQuantum)
```

#### `getVisualization`

```swift
func getVisualization(_ type: VisualizationType) -> LightField
```

Get photonics visualization data

**Parameters:**
- `type` (`VisualizationType`): Visualization type (interference, waveFunction, coherenceField, etc.)

**Returns:** `LightField`

**Example:**

```swift
// Get wave function visualization
let lightField = emulator.getVisualization(.waveFunction)

// Render photons
for photon in lightField.photons {
    renderPhoton(photon)
}
```

#### `collapseState`

```swift
func collapseState() -> Int
```

Collapse quantum superposition to classical state (measurement)

**Returns:** `Int`

**Example:**

```swift
let measuredState = emulator.collapseState()
print("Quantum state collapsed to: \(measuredState)")
```

---

## Plugin SDK

**Category:** Developer
**Platforms:** iOS, macOS, visionOS, tvOS, watchOS

Developer SDK for creating plugins, extensions, and integrations

### Properties

- **`identifier`** (`String`, read-only): Unique plugin identifier (reverse DNS)
- **`name`** (`String`, read-only): Human-readable plugin name
- **`version`** (`String`, read-only): Plugin version (semver)
- **`capabilities`** (`Set<PluginCapability>`, read-only): Plugin capabilities (audio, visual, bio, quantum, etc.)

### Methods

#### `EchoelmusicPlugin Protocol`

```swift
protocol EchoelmusicPlugin: AnyObject
```

Main protocol for creating Echoelmusic plugins

**Returns:** `Protocol`

**Example:**

```swift
class MyCustomPlugin: EchoelmusicPlugin {
    let identifier = "com.example.myplugin"
    let name = "My Custom Plugin"
    let version = "1.0.0"
    let author = "Your Name"
    let pluginDescription = "Does amazing things"
    let requiredSDKVersion = "10000.0.0"
    let capabilities: Set<PluginCapability> = [
        .audioEffect,
        .visualization,
        .bioProcessing
    ]

    func onLoad(context: PluginContext) async throws {
        // Initialize plugin
    }

    func onUnload() async {
        // Cleanup
    }

    func onFrame(deltaTime: TimeInterval) {
        // 60Hz update
    }

    func onBioDataUpdate(_ bioData: BioData) {
        // Process biometric data
    }

    func onQuantumStateChange(_ state: QuantumPluginState) {
        // React to quantum state
    }

    func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
        // Process audio
    }

    func renderVisual(context: RenderContext) -> VisualOutput? {
        // Render visuals
        return nil
    }

    func handleInteraction(_ interaction: UserInteraction) {
        // Handle user input
    }
}
```

#### `register`

```swift
func PluginManager.shared.register(_ plugin: EchoelmusicPlugin) throws
```

Register a plugin with the plugin manager

**Parameters:**
- `plugin` (`EchoelmusicPlugin`): Plugin instance to register

**Returns:** `Void`

**Throws:** Plugin registration errors

**Example:**

```swift
let plugin = MyCustomPlugin()
try PluginManager.shared.register(plugin)
```

---

## StreamEngine

**Category:** Streaming
**Platforms:** iOS, macOS

Professional live streaming to multiple platforms with hardware encoding and bio-reactive scenes

### Properties

- **`isStreaming`** (`@Published Bool`, read-only): Whether actively streaming
- **`activeStreams`** (`@Published [StreamDestination: StreamStatus]`, read-only): Status of each active stream
- **`currentScene`** (`@Published Scene?`, read-write): Currently active scene
- **`resolution`** (`@Published Resolution`, read-write): Current stream resolution
- **`frameRate`** (`@Published Int`, read-write): Current frame rate
- **`bitrate`** (`@Published Int`, read-write): Current bitrate in kbps
- **`actualFrameRate`** (`@Published Double`, read-only): Actual achieved frame rate
- **`droppedFrames`** (`@Published Int`, read-only): Number of dropped frames

### Methods

#### `startStreaming`

```swift
func startStreaming(destinations: [StreamDestination], streamKeys: [StreamDestination: String]) async throws
```

Start streaming to one or more platforms

**Parameters:**
- `destinations` (`[StreamDestination]`): Platforms to stream to (Twitch, YouTube, Facebook, Custom)
- `streamKeys` (`[StreamDestination: String]`): Stream keys for each destination

**Returns:** `Void`

**Throws:** Streaming connection errors

**Example:**

```swift
let destinations: [StreamDestination] = [.twitch, .youtube]
let keys: [StreamDestination: String] = [
    .twitch: "live_12345_abcdefghijklmnop",
    .youtube: "abcd-1234-efgh-5678-ijkl"
]

do {
    try await streamEngine.startStreaming(
        destinations: destinations,
        streamKeys: keys
    )
    print("✅ Streaming to Twitch and YouTube")
} catch {
    print("❌ Failed to start stream: \(error)")
}
```

#### `setQuality`

```swift
func setQuality(resolution: Resolution, frameRate: Int, bitrate: Int)
```

Set stream quality settings

**Parameters:**
- `resolution` (`Resolution`): Video resolution (720p, 1080p, 4K)
- `frameRate` (`Int`): Frame rate (30 or 60 fps)
- `bitrate` (`Int`): Bitrate in kbps

**Returns:** `Void`

**Example:**

```swift
// 1080p @ 60fps, 6000 kbps
streamEngine.setQuality(
    resolution: .hd1920x1080,
    frameRate: 60,
    bitrate: 6000
)
```

---

## WorldwideCollaborationHub

**Category:** Collaboration
**Platforms:** iOS, macOS, visionOS

Zero-latency worldwide collaboration platform for music, art, science, and wellness

### Properties

- **`activeSessions`** (`@Published [CollaborationSession]`, read-only): Currently active sessions
- **`currentSession`** (`@Published CollaborationSession?`, read-only): Current session if joined
- **`participants`** (`@Published [Participant]`, read-only): Participants in current session
- **`connectionQuality`** (`@Published NetworkQuality`, read-only): Network connection quality

### Methods

#### `createSession`

```swift
func createSession(name: String, mode: CollaborationMode, settings: SessionSettings) async throws -> CollaborationSession
```

Create a new collaboration session

**Parameters:**
- `name` (`String`): Session name
- `mode` (`CollaborationMode`): Collaboration mode (musicJam, meditation, research, etc.)
- `settings` (`SessionSettings`): Session configuration

**Returns:** `CollaborationSession`

**Throws:** Session creation errors

**Example:**

```swift
let settings = SessionSettings(
    maxParticipants: 8,
    allowChat: true,
    lowLatencyMode: true,
    quantumSyncEnabled: true
)

let session = try await hub.createSession(
    name: "Global Music Jam",
    mode: .musicJam,
    settings: settings
)

print("Session code: \(session.code)")
```

#### `joinSession`

```swift
func joinSession(code: String, participant: Participant) async throws -> CollaborationSession
```

Join an existing collaboration session

**Parameters:**
- `code` (`String`): 6-digit session code
- `participant` (`Participant`): Your participant info

**Returns:** `CollaborationSession`

**Throws:** Join errors (invalid code, session full, etc.)

**Example:**

```swift
let participant = Participant(
    userId: "user123",
    displayName: "Alice",
    location: Participant.Location(
        city: "San Francisco",
        country: "USA",
        timezone: "America/Los_Angeles"
    ),
    role: .contributor
)

let session = try await hub.joinSession(
    code: "ABC123",
    participant: participant
)
```

#### `syncState`

```swift
func syncState(sessionId: UUID, parameters: [String: Double]) async throws
```

Sync audio/visual parameters with all participants

**Parameters:**
- `sessionId` (`UUID`): Session identifier
- `parameters` (`[String: Double]`): Parameters to sync (BPM, filter, reverb, etc.)

**Returns:** `Void`

**Throws:** Sync errors

**Example:**

```swift
// Sync BPM and filter cutoff
try await hub.syncState(
    sessionId: session.id,
    parameters: [
        "bpm": 120.0,
        "filter_cutoff": 2000.0,
        "reverb_wet": 0.4
    ]
)
```

#### `sendBioData`

```swift
func sendBioData(sessionId: UUID, bioData: BioData) async throws
```

Share biometric data with session participants

**Parameters:**
- `sessionId` (`UUID`): Session identifier
- `bioData` (`BioData`): Biometric data to share

**Returns:** `Void`

**Throws:** Transmission errors

**Example:**

```swift
let bioData = BioData(
    heartRate: 75.0,
    hrvSDNN: 65.0,
    hrvRMSSD: 42.0,
    coherence: 0.82,
    breathingRate: 8.0,
    timestamp: Date()
)

try await hub.sendBioData(
    sessionId: session.id,
    bioData: bioData
)
```

---

## CinematicScoringEngine

**Category:** Creative
**Platforms:** iOS, macOS

Professional orchestral composition and playback (Walt Disney, BBCSO, Spitfire inspired)

### Properties

- **`currentStyle`** (`@Published ScoringStyle`, read-write): Current scoring style
- **`currentDynamic`** (`@Published DynamicMarking`, read-write): Current dynamic level
- **`activeVoices`** (`@Published [OrchestraVoice]`, read-only): Currently playing voices

### Methods

#### `playNote`

```swift
func playNote(instrument: Instrument, note: UInt8, velocity: Float, articulation: Articulation)
```

Play an orchestral note with articulation

**Parameters:**
- `instrument` (`Instrument`): Orchestra instrument (violin, cello, horn, flute, etc.)
- `note` (`UInt8`): MIDI note number
- `velocity` (`Float`): Note velocity 0.0-1.0
- `articulation` (`Articulation`): Playing technique (legato, spiccato, pizzicato, etc.)

**Returns:** `Void`

**Example:**

```swift
// Violin playing G4 with legato articulation
scoringEngine.playNote(
    instrument: .violin,
    note: 67,  // G4
    velocity: 0.7,
    articulation: .legato
)

// French horn with cuivré (brassy)
scoringEngine.playNote(
    instrument: .horn,
    note: 60,  // C4
    velocity: 0.9,
    articulation: .cuivre
)
```

#### `setDynamicMarking`

```swift
func setDynamicMarking(_ marking: DynamicMarking)
```

Set orchestral dynamic level (ppp to fff)

**Parameters:**
- `marking` (`DynamicMarking`): Dynamic marking (ppp, pp, p, mp, mf, f, ff, fff, sf, sff, sfz)

**Returns:** `Void`

**Example:**

```swift
// Fortissimo climax
scoringEngine.setDynamicMarking(.fff)

// Soft entrance
scoringEngine.setDynamicMarking(.pp)

// Sudden accent
scoringEngine.setDynamicMarking(.sforzando)
```

---

## ProductionConfiguration

**Category:** Production
**Platforms:** iOS, macOS, watchOS, tvOS, visionOS

Production-ready deployment system with security, monitoring, and release management

### Properties

- **`environment`** (`Environment`, read-only): Current environment (dev/staging/prod/enterprise)
- **`version`** (`String`, read-only): App version string
- **`buildNumber`** (`String`, read-only): Build number

### Methods

#### `currentEnvironment`

```swift
static func ProductionConfiguration.currentEnvironment() -> Environment
```

Get current runtime environment

**Returns:** `Environment`

**Example:**

```swift
let env = ProductionConfiguration.currentEnvironment()

switch env {
case .development:
    print("Development mode - verbose logging enabled")
case .staging:
    print("Staging mode - testing production features")
case .production:
    print("Production mode - optimized and secure")
case .enterprise:
    print("Enterprise mode - maximum security")
}
```

#### `isFeatureEnabled`

```swift
func FeatureFlagManager.shared.isEnabled(_ feature: String) -> Bool
```

Check if a feature flag is enabled

**Parameters:**
- `feature` (`String`): Feature identifier

**Returns:** `Bool`

**Example:**

```swift
if FeatureFlagManager.shared.isEnabled("quantum_mode") {
    enableQuantumMode()
}
```

#### `authenticateBiometric`

```swift
func BiometricAuthService.shared.authenticate() async throws -> Bool
```

Authenticate user with Face ID / Touch ID / Optic ID

**Returns:** `Bool`

**Throws:** Authentication errors

**Example:**

```swift
do {
    let success = try await BiometricAuthService.shared.authenticate()
    if success {
        unlockSensitiveFeature()
    }
} catch {
    print("Authentication failed: \(error)")
}
```

---

## HardwareEcosystem

**Category:** Hardware
**Platforms:** iOS, macOS, visionOS

Universal device registry supporting 60+ audio interfaces, 40+ MIDI controllers, and more

### Properties

- **`connectedDevices`** (`@Published [HardwareDevice]`, read-only): All connected hardware devices
- **`audioInterfaces`** (`[HardwareDevice]`, read-only): Connected audio interfaces
- **`midiControllers`** (`[HardwareDevice]`, read-only): Connected MIDI controllers

### Methods

#### `registerDevice`

```swift
func HardwareEcosystem.shared.registerDevice(_ device: HardwareDevice) -> UUID
```

Register a hardware device in the ecosystem

**Parameters:**
- `device` (`HardwareDevice`): Device to register

**Returns:** `UUID`

**Example:**

```swift
let device = HardwareDevice(
    name: "Universal Audio Apollo Twin",
    category: .audioInterface,
    manufacturer: "Universal Audio",
    connectionType: .thunderbolt
)

let deviceId = HardwareEcosystem.shared.registerDevice(device)
```

#### `getConnectedDevices`

```swift
func HardwareEcosystem.shared.getConnectedDevices(category: DeviceCategory? = nil) -> [HardwareDevice]
```

Get all connected hardware devices, optionally filtered by category

**Parameters:**
- `category` (`DeviceCategory?`): Device category filter (default: `nil`)

**Returns:** `[HardwareDevice]`

**Example:**

```swift
// Get all audio interfaces
let interfaces = HardwareEcosystem.shared.getConnectedDevices(
    category: .audioInterface
)

// Get all devices
let allDevices = HardwareEcosystem.shared.getConnectedDevices()
```

---

## Complete Integration Examples

### Full Bio-Reactive Session

```swift
// Complete Bio-Reactive Spatial Audio Session

import Echoelmusic

@MainActor
class BioReactiveSession: ObservableObject {
    private let micManager = MicrophoneManager()
    private let audioEngine: AudioEngine
    private let spatialEngine: SpatialAudioEngine
    private let hub: UnifiedControlHub
    private let healthKit = HealthKitManager()

    init() {
        // Initialize audio
        audioEngine = AudioEngine(microphoneManager: micManager)
        spatialEngine = SpatialAudioEngine()

        // Initialize control hub
        hub = UnifiedControlHub(audioEngine: audioEngine)
    }

    func startSession() async throws {
        // 1. Request biometric authorization
        try await healthKit.requestAuthorization()

        // 2. Start audio engines
        audioEngine.start()
        try spatialEngine.start()

        // 3. Enable all input modalities
        hub.enableFaceTracking()
        hub.enableHandTracking()
        try await hub.enableBiometricMonitoring()

        // 4. Configure Multidimensional Brainwave Entrainment for meditation
        audioEngine.setBrainwaveState(.theta)
        audioEngine.setBinauralAmplitude(0.3)
        audioEngine.toggleBinauralBeats()

        // 5. Start control loop
        hub.start()

        // 6. Monitor coherence and adapt spatial field
        monitorCoherence()
    }

    private func monitorCoherence() {
        // Subscribe to coherence changes
        healthKit.$hrvCoherence
            .sink { [weak self] coherence in
                self?.adaptSpatialField(coherence: coherence)
            }
            .store(in: &cancellables)
    }

    private func adaptSpatialField(coherence: Double) {
        if coherence > 60 {
            // High coherence → Fibonacci spiral (harmonious)
            spatialEngine.setFieldGeometry(.fibonacci, sourceCount: 13)
        } else {
            // Low coherence → Grid (grounded)
            spatialEngine.setFieldGeometry(.grid, sourceCount: 9)
        }
    }

    func stopSession() {
        hub.stop()
        audioEngine.stop()
        spatialEngine.stop()
    }

    private var cancellables = Set<AnyCancellable>()
}
```

### Plugin Development

```swift
// Creating a Custom Echoelmusic Plugin

import Echoelmusic

class BioReactiveVisualizerPlugin: EchoelmusicPlugin {
    let identifier = "com.example.bioreactive-visualizer"
    let name = "Bio-Reactive Visualizer"
    let version = "1.0.0"
    let author = "Your Name"
    let pluginDescription = "Creates visualizations synchronized to HRV coherence"
    let requiredSDKVersion = "10000.0.0"

    let capabilities: Set<PluginCapability> = [
        .visualization,
        .bioProcessing,
        .coherenceTracking
    ]

    private var coherence: Float = 0.5
    private var particles: [Particle] = []

    func onLoad(context: PluginContext) async throws {
        print("Plugin loaded on \(context.platform)")

        // Initialize particle system
        particles = (0..<100).map { _ in
            Particle(
                position: randomPosition(),
                velocity: randomVelocity(),
                color: .white
            )
        }
    }

    func onUnload() async {
        particles.removeAll()
    }

    func onFrame(deltaTime: TimeInterval) {
        // Update particles based on coherence
        for i in 0..<particles.count {
            particles[i].update(deltaTime: deltaTime, coherence: coherence)
        }
    }

    func onBioDataUpdate(_ bioData: BioData) {
        // React to biometric changes
        coherence = bioData.coherence

        // High coherence → particles move in harmony
        // Low coherence → particles move chaotically
        let harmony = coherence > 0.6

        for i in 0..<particles.count {
            if harmony {
                particles[i].setAttractor(center: .zero)
            } else {
                particles[i].setAttractor(nil)
            }
        }
    }

    func onQuantumStateChange(_ state: QuantumPluginState) {
        // React to quantum coherence
        if state.coherenceLevel > 0.8 {
            // Trigger quantum entanglement visual
            triggerEntanglementEffect()
        }
    }

    func processAudio(buffer: inout [Float], sampleRate: Int, channels: Int) {
        // Not used for visualization-only plugin
    }

    func renderVisual(context: RenderContext) -> VisualOutput? {
        // Render particles to Metal texture
        let renderer = ParticleRenderer(context: context)
        return renderer.render(particles: particles)
    }

    func handleInteraction(_ interaction: UserInteraction) {
        switch interaction {
        case .tap(let location):
            // Create particle burst at tap location
            createBurst(at: location)
        default:
            break
        }
    }
}

// Register plugin
let plugin = BioReactiveVisualizerPlugin()
try PluginManager.shared.register(plugin)
```

---

*Documentation generated for Echoelmusic SDK 10000.0.0 (Ultimate Ralph Wiggum Loop Mode)*
*Released: 2026-01-06*
*Copyright 2026 Echoelmusic. MIT License.*
