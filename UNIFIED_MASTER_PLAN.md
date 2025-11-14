# UNIFIED MASTER PLAN - ECHOELMUSIC

**Generated:** 2025-11-14
**Current Branch:** `claude/echoelmusic-phase3-migrate-01DsLLpgYQKonYVPjn2E9EJW`
**Status:** Migration Complete → **READY FOR IMPLEMENTATION**

---

## 🎯 CURRENT STATE

### ✅ Completed (Phases 1-3 Migration)
- Phase 1: Rename Blab → Echoelmusic (79 files)
- Phase 2: Create 9 modular targets with skeleton code
- Phase 3 (Commits 1-5): Migrate 55 files to modules

### ❌ Blocking Issues (Must Fix Before Compile)
- **App does not compile** - missing implementations
- **AudioEngine** - no start/stop/record/play
- **UnifiedControlHub** - no 60Hz loop
- **SessionModel** - save/load not tested
- **Test imports** - still using monolithic imports
- **Some "Blab" references** - in comments/docs (20 files)

### 🎯 Immediate Goal
**Get app to COMPILE → LAUNCH → PLAY AUDIO** with minimal stubs

---

## 📋 MASTER TASK MATRIX

### Legend
- **Priority:** P1 (Critical/Blocking) | P2 (High) | P3 (Medium/Future)
- **Complexity:** S (Small: <4h) | M (Medium: 4-8h) | L (Large: >8h)
- **Status:** ✅ DONE | ⚠️ PARTIAL | ❌ TODO | ⏸️ BLOCKED

---

## A) REPO CLEANUP

| ID | Task | P | Size | Status | Dependencies | Code Exists | Next PR |
|----|------|---|------|--------|--------------|-------------|---------|
| **A.1** | Remove "Blab" from code comments | P1 | S | ❌ | None | YES (20 files) | Current |
| **A.2** | Remove "Blab" from documentation | P2 | S | ❌ | None | YES (MD files) | Current |
| **A.3** | Update test imports to modules | P1 | S | ❌ | None | YES | Current |
| **A.4** | Fix broken import paths | P1 | S | ❌ | Migration | PARTIAL | Current |
| **A.5** | Verify Package.swift deps | P1 | S | ❌ | Migration | YES | Current |
| **A.6** | Clean empty directories | P2 | S | ❌ | Migration | N/A | Current |
| **A.7** | Update GitHub workflows | P2 | S | ❌ | None | YES (.github/) | Later |

**Estimated Total:** 3 hours
**Next PR:** Continue `claude/echoelmusic-phase3-migrate-01DsLLpgYQKonYVPjn2E9EJW`

---

## B) ARCHITECTURE

| ID | Task | P | Size | Status | Dependencies | Code Exists | Next PR |
|----|------|---|------|--------|--------------|-------------|---------|
| **B.1** | Define EventBus event types | P1 | M | ⚠️ | None | PARTIAL (skeleton) | Current |
| **B.2** | Define StateGraph states | P2 | S | ⚠️ | None | PARTIAL (skeleton) | Current |
| **B.3** | Merge NodeGraph + RoutingGraph | P2 | M | ❌ | A.* | YES (2 impls) | `claude/merge-routing-01DsL...` |
| **B.4** | Document module dependencies | P2 | S | ✅ | None | DONE | - |
| **B.5** | Create architecture tests | P2 | M | ❌ | B.1-B.3 | NO | Later |

**Key Event Types Needed:**
```swift
// EchoelmusicCore/EventBus/Events.swift
public protocol EventProtocol: Sendable {
    var timestamp: Date { get }
    var source: String { get }
}

// Audio Events
public struct AudioEngineStartedEvent: EventProtocol
public struct AudioEngineStoppedEvent: EventProtocol
public struct AudioBufferReadyEvent: EventProtocol

// Bio Events
public struct BioSignalUpdatedEvent: EventProtocol {
    public let hrv: Double
    public let heartRate: Double
    public let coherence: Double
}

// Control Events
public struct GestureDetectedEvent: EventProtocol
public struct FaceTrackingUpdatedEvent: EventProtocol

// UI Events
public struct ModeChangedEvent: EventProtocol
public struct SessionLoadedEvent: EventProtocol
```

**Estimated Total:** 6 hours
**Next PR:** Define events in current branch, merge routing later

---

## C) CORE AUDIO

| ID | Task | P | Size | Status | Dependencies | Code Exists | Next PR |
|----|------|---|------|--------|--------------|-------------|---------|
| **C.1** | Implement AudioEngine.start() | P1 | M | ❌ | A.* | PARTIAL | Current (Commit 6) |
| **C.2** | Implement AudioEngine.stop() | P1 | S | ❌ | C.1 | PARTIAL | Current (Commit 6) |
| **C.3** | Implement WAV playback | P1 | M | ❌ | C.1 | NO | Current (Commit 6) |
| **C.4** | Implement WAV recording | P1 | M | ❌ | C.1 | NO | Current (Commit 6) |
| **C.5** | Thread-safe buffer queue | P1 | L | ❌ | C.1 | NO | Current (Commit 6) |
| **C.6** | Microphone input pipeline | P1 | M | ⚠️ | C.1 | PARTIAL | Current (Commit 6) |
| **C.7** | Audio routing (cycle detect) | P2 | L | ⚠️ | B.3, C.1 | PARTIAL | Later |
| **C.8** | Effect node processing | P2 | M | ⚠️ | C.7 | PARTIAL | Later |
| **C.9** | Spatial audio integration | P2 | L | ⚠️ | C.1 | PARTIAL | Later |
| **C.10** | Binaural beat generation | P2 | M | ⚠️ | C.1 | PARTIAL | Later |

**Critical Path:** C.1 → C.2 → C.6 (basic audio I/O)

**Estimated Total:** 20 hours (P1 items: 14 hours)
**Next PR:** Implement C.1-C.6 in current branch (Commit 6)

---

## D) CONTROL ENGINE (UnifiedControlHub)

| ID | Task | P | Size | Status | Dependencies | Code Exists | Next PR |
|----|------|---|------|--------|--------------|-------------|---------|
| **D.1** | Implement 60Hz control loop | P1 | M | ❌ | B.1, C.1 | NO | Current (Commit 7) |
| **D.2** | Wire to EventBus | P1 | M | ❌ | D.1 | NO | Current (Commit 7) |
| **D.3** | Integrate gesture recognition | P2 | M | ⚠️ | D.1 | PARTIAL | Current (Commit 7) |
| **D.4** | Integrate face tracking | P2 | M | ⚠️ | D.1 | PARTIAL | Later |
| **D.5** | Integrate bio signals (HRV) | P2 | M | ⚠️ | D.1 | PARTIAL | Later |
| **D.6** | Integrate MIDI input | P2 | M | ⚠️ | D.1 | PARTIAL | Later |
| **D.7** | Performance monitoring | P1 | S | ❌ | D.1 | NO | Current (Commit 7) |
| **D.8** | Conflict resolution | P2 | L | ⚠️ | D.3-D.6 | PARTIAL | Later |

**Critical Path:** D.1 → D.2 → D.7 (basic 60Hz loop with EventBus)

**Estimated Total:** 16 hours (P1 items: 8 hours)
**Next PR:** Implement D.1, D.2, D.7 in current branch (Commit 7)

---

## E) UI/UX MULTI-TOUCH + ORIENTATION

| ID | Task | P | Size | Status | Dependencies | Code Exists | Next PR |
|----|------|---|------|--------|--------------|-------------|---------|
| **E.1** | Multi-touch gesture detection | P2 | M | ❌ | None | NO | `claude/multitouch-01DsL...` |
| **E.2** | Orientation auto-detection | P2 | S | ❌ | None | NO | `claude/orientation-01DsL...` |
| **E.3** | Layout adapt (portrait/landscape) | P2 | M | ❌ | E.2 | NO | `claude/orientation-01DsL...` |
| **E.4** | Mode switcher UI | P1 | M | ⚠️ | B.2 | PARTIAL | Current |
| **E.5** | Minimal audio controls UI | P1 | S | ❌ | C.1-C.2 | NO | Current (Commit 6) |
| **E.6** | Session browser integration | P2 | M | ⚠️ | H.1 | PARTIAL | Later |
| **E.7** | Visualization mode switcher | P2 | S | ⚠️ | F.1 | PARTIAL | Later |

**Critical Path:** E.5 (minimal audio controls for testing)

**Estimated Total:** 11 hours (P1 items: 4 hours)
**Next PR:** Implement E.5 in current branch

---

## F) RENDERING (Audio / Visual / XR)

| ID | Task | P | Size | Status | Dependencies | Code Exists | Next PR |
|----|------|---|------|--------|--------------|-------------|---------|
| **F.1** | Basic waveform visualization | P2 | M | ⚠️ | C.1 | PARTIAL | Current |
| **F.2** | Cymatics renderer (Metal) | P3 | L | ⚠️ | C.1 | PARTIAL | Later |
| **F.3** | Spectral analyzer (FFT) | P2 | M | ⚠️ | C.1 | PARTIAL | Later |
| **F.4** | Mandala mode | P3 | M | ⚠️ | C.1 | PARTIAL | Later |
| **F.5** | Particle system | P3 | M | ⚠️ | C.1 | PARTIAL | Later |
| **F.6** | XR/visionOS integration | P3 | L | ⚠️ | None | STUB | Later |

**Critical Path:** F.1 (basic waveform for debugging)

**Estimated Total:** 18 hours (P2 items: 8 hours)
**Next PR:** Integrate F.1 in current branch

---

## G) ML / BIOFEEDBACK / PREDICTION

| ID | Task | P | Size | Status | Dependencies | Code Exists | Next PR |
|----|------|---|------|--------|--------------|-------------|---------|
| **G.1** | HealthKit HRV integration | P2 | M | ⚠️ | None | PARTIAL | `claude/healthkit-01DsL...` |
| **G.2** | Bio-parameter mapping | P2 | M | ⚠️ | G.1 | PARTIAL | `claude/bio-mapping-01DsL...` |
| **G.3** | CoreML emotion detection | P3 | L | ⚠️ | None | STUB | Later |
| **G.4** | CoreML voice analysis | P3 | L | ⚠️ | None | STUB | Later |
| **G.5** | Adaptive EQ (ML-based) | P3 | L | ⚠️ | None | STUB | Later |

**Estimated Total:** 28 hours (Deferred to P3)

---

## H) SESSION / COLLABORATION

| ID | Task | P | Size | Status | Dependencies | Code Exists | Next PR |
|----|------|---|------|--------|--------------|-------------|---------|
| **H.1** | Session save/load (Codable) | P1 | M | ⚠️ | None | PARTIAL | Current (Commit 8) |
| **H.2** | Roundtrip tests (save→load) | P1 | S | ❌ | H.1 | NO | Current (Commit 8) |
| **H.3** | Session templates (presets) | P2 | S | ⚠️ | H.1 | PARTIAL | Later |
| **H.4** | Session export/import | P2 | M | ⚠️ | H.1 | PARTIAL | Later |
| **H.5** | Multi-user collaboration | P3 | L | ❌ | H.1 | NO | Later |
| **H.6** | Cloud sync | P3 | L | ❌ | H.1 | NO | Later |

**Critical Path:** H.1 → H.2 (basic session persistence)

**Estimated Total:** 18 hours (P1 items: 6 hours)
**Next PR:** Implement H.1-H.2 in current branch (Commit 8)

---

## I) CROSS-PLATFORM (iOS, macOS, visionOS)

| ID | Task | P | Size | Status | Dependencies | Code Exists | Next PR |
|----|------|---|------|--------|--------------|-------------|---------|
| **I.1** | Device capability detection | P2 | S | ⚠️ | None | PARTIAL | Current |
| **I.2** | Permission management | P2 | M | ⚠️ | None | PARTIAL | Later |
| **I.3** | macOS target support | P3 | M | ❌ | Package.swift | NO | Later |
| **I.4** | visionOS target support | P3 | L | ❌ | F.6 | NO | Later |
| **I.5** | Platform-specific UI | P3 | M | ❌ | I.3-I.4 | NO | Later |

**Estimated Total:** 14 hours (Deferred to P3)

---

## J) FUTURE MODULES

| ID | Task | P | Size | Status | Dependencies | Code Exists | Next PR |
|----|------|---|------|--------|--------------|-------------|---------|
| **J.1** | Voice command engine | P3 | M | ⚠️ | None | STUB | Later |
| **J.2** | Wearable device integration | P3 | L | ⚠️ | None | STUB | Later |
| **J.3** | Live streaming (RTMP) | P3 | L | ❌ | C.1 | NO | Later |
| **J.4** | Content engine (presets) | P3 | L | ❌ | H.1 | NO | Later |
| **J.5** | VR integration | P3 | L | ❌ | F.6 | NO | Later |

**Estimated Total:** 40+ hours (All P3 - deferred)

---

## 🔥 FIRST IMPLEMENTATION PACKAGE

### Goal
**Get Echoelmusic to COMPILE, LAUNCH, and PLAY AUDIO with minimal stubs**

### Scope
Implement **ONLY** the critical path items needed for basic functionality:

1. **A.1-A.5** - Clean up blocking issues (3h)
2. **B.1** - Define core event types (2h)
3. **C.1, C.2, C.6** - Basic audio engine (6h)
4. **D.1, D.2, D.7** - Basic 60Hz loop (6h)
5. **E.5** - Minimal UI controls (2h)
6. **H.1, H.2** - Session save/load (6h)

**Total Estimated Time:** ~25 hours (3 days)

---

### Package 1: Repository Cleanup (A.1-A.5)

**Commit:** "fix: Remove Blab references and fix imports"

#### Files to Patch

**1. Remove "Blab" from code comments:**

```bash
# Sources/EchoelmusicAudio/Engine/AudioEngine.swift:14
# OLD: This class acts as the central hub for all audio processing in Blab
# NEW: This class acts as the central hub for all audio processing in Echoelmusic

find Sources -name "*.swift" -exec sed -i '' 's/in Blab/in Echoelmusic/g' {} \;
find Sources -name "*.swift" -exec sed -i '' 's/for Blab/for Echoelmusic/g' {} \;
find Sources -name "*.swift" -exec sed -i '' 's/Blab /Echoelmusic /g' {} \;
```

**2. Update test imports:**

```swift
// Tests/EchoelmusicTests/*Tests.swift
// OLD:
@testable import Echoelmusic

// NEW (example):
@testable import EchoelmusicCore
@testable import EchoelmusicAudio
import XCTest
```

**3. Verify Package.swift:**

```swift
// Package.swift - ensure all dependencies correct
let package = Package(
    name: "Echoelmusic",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "EchoelmusicCore", targets: ["EchoelmusicCore"]),
        .library(name: "EchoelmusicAudio", targets: ["EchoelmusicAudio"]),
        // ... all 9 modules
    ],
    targets: [
        .target(name: "EchoelmusicCore", dependencies: []),
        .target(name: "EchoelmusicAudio", dependencies: ["EchoelmusicCore"]),
        .target(name: "EchoelmusicBio", dependencies: ["EchoelmusicCore"]),
        .target(name: "EchoelmusicVisual", dependencies: ["EchoelmusicCore"]),
        .target(name: "EchoelmusicMIDI", dependencies: ["EchoelmusicCore"]),
        .target(name: "EchoelmusicControl", dependencies: [
            "EchoelmusicCore",
            "EchoelmusicAudio",
            "EchoelmusicBio",
            "EchoelmusicVisual",
            "EchoelmusicMIDI"
        ]),
        .target(name: "EchoelmusicHardware", dependencies: [
            "EchoelmusicCore",
            "EchoelmusicMIDI"
        ]),
        .target(name: "EchoelmusicPlatform", dependencies: ["EchoelmusicCore"]),
        .target(name: "EchoelmusicUI", dependencies: [
            "EchoelmusicCore",
            "EchoelmusicAudio",
            "EchoelmusicBio",
            "EchoelmusicVisual",
            "EchoelmusicControl",
            "EchoelmusicPlatform"
        ]),
        // Tests
        .testTarget(name: "EchoelmusicCoreTests", dependencies: ["EchoelmusicCore"]),
        .testTarget(name: "EchoelmusicAudioTests", dependencies: ["EchoelmusicAudio"]),
        // ... test targets for each module
    ]
)
```

---

### Package 2: EventBus Event Definitions (B.1)

**Commit:** "feat(core): Define core event types for EventBus"

**File:** `Sources/EchoelmusicCore/EventBus/Events.swift` (NEW)

```swift
import Foundation

// MARK: - Base Protocol

public protocol EventProtocol: Sendable {
    var timestamp: Date { get }
    var source: String { get }
}

// MARK: - Audio Events

public struct AudioEngineStartedEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let sampleRate: Double
    public let bufferSize: Int

    public init(source: String = "AudioEngine", sampleRate: Double, bufferSize: Int) {
        self.timestamp = Date()
        self.source = source
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
    }
}

public struct AudioEngineStoppedEvent: EventProtocol {
    public let timestamp: Date
    public let source: String

    public init(source: String = "AudioEngine") {
        self.timestamp = Date()
        self.source = source
    }
}

public struct AudioBufferReadyEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let level: Float
    public let pitch: Float?

    public init(source: String = "AudioEngine", level: Float, pitch: Float? = nil) {
        self.timestamp = Date()
        self.source = source
        self.level = level
        self.pitch = pitch
    }
}

// MARK: - Bio Events

public struct BioSignalUpdatedEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let hrv: Double
    public let heartRate: Double
    public let coherence: Double

    public init(source: String = "HealthKitManager", hrv: Double, heartRate: Double, coherence: Double) {
        self.timestamp = Date()
        self.source = source
        self.hrv = hrv
        self.heartRate = heartRate
        self.coherence = coherence
    }
}

// MARK: - Control Events

public struct GestureDetectedEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let gesture: String
    public let hand: String
    public let confidence: Float

    public init(source: String = "GestureRecognizer", gesture: String, hand: String, confidence: Float) {
        self.timestamp = Date()
        self.source = source
        self.gesture = gesture
        self.hand = hand
        self.confidence = confidence
    }
}

public struct ControlLoopTickEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let frameNumber: Int
    public let actualHz: Double

    public init(source: String = "UnifiedControlHub", frameNumber: Int, actualHz: Double) {
        self.timestamp = Date()
        self.source = source
        self.frameNumber = frameNumber
        self.actualHz = actualHz
    }
}

// MARK: - UI Events

public struct ModeChangedEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let oldMode: String
    public let newMode: String

    public init(source: String = "UI", oldMode: String, newMode: String) {
        self.timestamp = Date()
        self.source = source
        self.oldMode = oldMode
        self.newMode = newMode
    }
}

public struct SessionLoadedEvent: EventProtocol {
    public let timestamp: Date
    public let source: String
    public let sessionID: UUID
    public let sessionName: String

    public init(source: String = "SessionManager", sessionID: UUID, sessionName: String) {
        self.timestamp = Date()
        self.source = source
        self.sessionID = sessionID
        self.sessionName = sessionName
    }
}
```

**Update EventBus.swift to import Events:**

```swift
// Sources/EchoelmusicCore/EventBus/EventBus.swift
// Add at top after existing imports:
// (Events.swift will be automatically available in same module)
```

---

### Package 3: Minimal AudioEngine Implementation (C.1, C.2, C.6)

**Commit:** "feat(audio): Implement basic AudioEngine start/stop/input"

**File:** `Sources/EchoelmusicAudio/Engine/AudioEngine.swift`

**Changes:**

```swift
// ADD these imports at top
import EchoelmusicCore

// REPLACE the start() method stub with:
public func start() async throws {
    guard !isRunning else { return }

    // Configure audio session
    do {
        try AudioConfiguration.configureAudioSession()
        print("✅ Audio session configured: \(AudioConfiguration.latencyStats())")
    } catch {
        print("❌ Failed to configure audio session: \(error)")
        throw error
    }

    // Initialize AVAudioEngine if not already
    if audioEngine == nil {
        audioEngine = AVAudioEngine()
    }

    guard let engine = audioEngine else {
        throw AudioEngineError.initializationFailed
    }

    // Setup microphone input
    let inputNode = engine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)

    print("🎤 Input format: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount) channels")

    // Install tap for audio processing
    inputNode.installTap(onBus: 0, bufferSize: 512, format: inputFormat) { [weak self] buffer, time in
        self?.processAudioBuffer(buffer, time: time)
    }

    // Start engine
    try engine.start()

    // Update state
    await MainActor.run {
        self.isRunning = true
    }

    // Publish event
    EventBus.shared.publish(AudioEngineStartedEvent(
        sampleRate: inputFormat.sampleRate,
        bufferSize: 512
    ))

    print("🎵 AudioEngine started successfully")
}

// REPLACE the stop() method stub with:
public func stop() {
    guard isRunning else { return }

    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)

    Task { @MainActor in
        self.isRunning = false
    }

    EventBus.shared.publish(AudioEngineStoppedEvent())

    print("🛑 AudioEngine stopped")
}

// ADD this new method for audio processing:
private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
    // Calculate audio level (RMS)
    guard let channelData = buffer.floatChannelData else { return }
    let channelDataValue = channelData.pointee
    let frameLength = Int(buffer.frameLength)

    var sum: Float = 0
    for i in 0..<frameLength {
        let sample = channelDataValue[i]
        sum += sample * sample
    }

    let rms = sqrt(sum / Float(frameLength))
    let level = 20 * log10(rms) // Convert to dB

    // Publish audio level event
    EventBus.shared.publish(AudioBufferReadyEvent(level: level))

    // Update published property (on main thread)
    Task { @MainActor in
        self.currentAudioLevel = max(0, min(1, (level + 60) / 60)) // Normalize -60dB to 0dB → 0 to 1
    }
}

// ADD these properties to the class:
private var audioEngine: AVAudioEngine?
@Published public var currentAudioLevel: Float = 0.0

// ADD error enum:
public enum AudioEngineError: Error {
    case initializationFailed
    case audioSessionFailed
    case startFailed
}
```

---

### Package 4: UnifiedControlHub 60Hz Loop (D.1, D.2, D.7)

**Commit:** "feat(control): Implement 60Hz control loop with EventBus"

**File:** `Sources/EchoelmusicControl/Hub/UnifiedControlHub.swift`

**Changes:**

```swift
// ADD these imports at top
import EchoelmusicCore
import Combine

// REPLACE the start() method with:
public func start() {
    guard !isRunning else { return }

    isRunning = true
    frameCount = 0
    lastTickTime = Date()

    // Create 60Hz timer using CADisplayLink-like behavior
    // On iOS, we'd use CADisplayLink, but for cross-platform we use Timer
    #if os(iOS)
    // Use CADisplayLink for precise 60Hz on iOS
    let displayLink = CADisplayLink(target: self, selector: #selector(tick))
    displayLink.add(to: .main, forMode: .common)
    self.displayLink = displayLink
    #else
    // Use Timer for macOS/other platforms
    controlTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
        self?.tick()
    }
    #endif

    print("🎮 UnifiedControlHub started at 60Hz")
}

public func stop() {
    guard isRunning else { return }

    isRunning = false

    #if os(iOS)
    displayLink?.invalidate()
    displayLink = nil
    #else
    controlTimer?.invalidate()
    controlTimer = nil
    #endif

    print("🛑 UnifiedControlHub stopped")
}

// ADD the tick method:
@objc private func tick() {
    frameCount += 1

    // Calculate actual Hz
    let now = Date()
    let deltaTime = now.timeIntervalSince(lastTickTime)
    let actualHz = 1.0 / deltaTime
    lastTickTime = now

    // Update published Hz
    currentHz = actualHz

    // Publish tick event every 60 frames (once per second)
    if frameCount % 60 == 0 {
        EventBus.shared.publish(ControlLoopTickEvent(
            frameNumber: frameCount,
            actualHz: actualHz
        ))

        // Performance check
        if abs(actualHz - 60.0) > 5.0 {
            print("⚠️ Control loop drift detected: \(actualHz)Hz (target: 60Hz)")
        }
    }

    // TODO: Poll input providers here
    // - gestureRecognizer?.update()
    // - faceTracker?.update()
    // - bioSignals?.update()
    // - midiController?.poll()
}

// ADD these properties:
private var displayLink: CADisplayLink?
private var controlTimer: Timer?
private var frameCount: Int = 0
private var lastTickTime: Date = Date()
@Published public var currentHz: Double = 0.0
```

---

### Package 5: Minimal UI Controls (E.5)

**Commit:** "feat(ui): Add minimal audio controls to ContentView"

**File:** `Sources/EchoelmusicUI/Screens/ContentView.swift`

**Changes:**

```swift
// In the body, ADD a minimal control panel at the bottom:

VStack {
    // Existing visualization content
    // ...

    Spacer()

    // MINIMAL AUDIO CONTROLS
    VStack(spacing: 12) {
        // Audio level indicator
        HStack {
            Text("Level:")
            ProgressView(value: audioEngine.currentAudioLevel)
                .progressViewStyle(.linear)
        }
        .padding(.horizontal)

        // Start/Stop button
        Button(action: {
            Task {
                if audioEngine.isRunning {
                    audioEngine.stop()
                } else {
                    try? await audioEngine.start()
                }
            }
        }) {
            HStack {
                Image(systemName: audioEngine.isRunning ? "stop.circle.fill" : "play.circle.fill")
                Text(audioEngine.isRunning ? "Stop Audio" : "Start Audio")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(audioEngine.isRunning ? Color.red : Color.green)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding(.horizontal)

        // Status text
        Text(audioEngine.isRunning ? "Audio Engine Running" : "Audio Engine Stopped")
            .font(.caption)
            .foregroundColor(.gray)
    }
    .padding(.bottom, 20)
}
```

---

### Package 6: Session Save/Load Implementation (H.1, H.2)

**Commit:** "feat(core): Implement Session save/load with tests"

**File:** `Sources/EchoelmusicCore/Types/Session.swift`

**Verification (already implemented, just add validation):**

```swift
// ADD validation method to Session:
public func validate() throws {
    // Validate session data
    guard !name.isEmpty else {
        throw SessionError.invalidName
    }

    guard tempo > 0 && tempo < 999 else {
        throw SessionError.invalidTempo
    }

    // Validate all tracks
    for track in tracks {
        guard !track.name.isEmpty else {
            throw SessionError.invalidTrackName
        }
    }
}

public enum SessionError: Error {
    case invalidName
    case invalidTempo
    case invalidTrackName
    case saveFailed(Error)
    case loadFailed(Error)
}
```

**File:** `Tests/EchoelmusicCoreTests/SessionTests.swift` (NEW)

```swift
import XCTest
@testable import EchoelmusicCore

final class SessionTests: XCTestCase {

    func testSessionSaveLoad() throws {
        // Create a session
        var session = Session(name: "Test Session", tempo: 120.0)
        session.addTrack(.voiceTrack())
        session.addTrack(.binauralTrack())

        let bioPoint = BioDataPoint(
            timestamp: 1.0,
            hrv: 50.0,
            heartRate: 70.0,
            coherence: 0.8,
            audioLevel: 0.5,
            frequency: 440.0
        )
        session.addBioDataPoint(bioPoint)

        // Save
        try session.save()

        // Load
        let loaded = try Session.load(id: session.id)

        // Verify
        XCTAssertEqual(loaded.id, session.id)
        XCTAssertEqual(loaded.name, session.name)
        XCTAssertEqual(loaded.tempo, session.tempo)
        XCTAssertEqual(loaded.tracks.count, session.tracks.count)
        XCTAssertEqual(loaded.bioData.count, session.bioData.count)

        // Verify bio data
        XCTAssertEqual(loaded.bioData.first?.hrv, 50.0)
        XCTAssertEqual(loaded.bioData.first?.heartRate, 70.0)

        print("✅ Session roundtrip test passed")
    }

    func testSessionValidation() throws {
        var session = Session(name: "", tempo: 120.0)
        XCTAssertThrowsError(try session.validate()) { error in
            XCTAssertEqual(error as? Session.SessionError, .invalidName)
        }

        session.name = "Valid Name"
        session.tempo = -10
        XCTAssertThrowsError(try session.validate()) { error in
            XCTAssertEqual(error as? Session.SessionError, .invalidTempo)
        }
    }
}
```

---

## 🔍 CROSS-CHECK: "Blab" References

### Found in 20 files (mostly documentation):

**Code Files (3) - MUST FIX:**
1. `Sources/EchoelmusicAudio/Engine/AudioEngine.swift:14` - comment
2. `Sources/EchoelmusicControl/Hub/UnifiedControlHub.swift` - comment
3. `Sources/EchoelmusicMIDI/Core/MIDI2Manager.swift` - comment (if any)

**Documentation Files (17) - CAN DEFER:**
- ECHOELMUSIC_EXTENDED_VISION.md
- BUGFIXES.md
- DAW_INTEGRATION_GUIDE.md
- GitHub workflows (.github/workflows/*.yml)
- Markdown guides (*.md)
- Sources/Echoelmusic/Visual/Shaders/Cymatics.metal (leftover file?)

**Fix Script:**

```bash
# Fix code comments
find Sources/Echoelmusic* -name "*.swift" -exec sed -i '' \
    -e 's/in Blab/in Echoelmusic/g' \
    -e 's/for Blab/for Echoelmusic/g' \
    -e 's/Blab /Echoelmusic /g' \
    -e 's/BLAB /ECHOELMUSIC /g' \
    {} \;

# Fix documentation (optional, P2)
find . -name "*.md" -not -path "./node_modules/*" -exec sed -i '' \
    -e 's/BLAB/ECHOELMUSIC/g' \
    -e 's/Blab/Echoelmusic/g' \
    -e 's/blab/echoelmusic/g' \
    {} \;

# Check for leftover old files
find Sources/Echoelmusic -type f -name "*.swift" 2>/dev/null
# Should return nothing (or only non-migrated files)
```

---

## ⚠️ MISSING/BROKEN PARTS DETECTED

### 1. Audio Engine
- ❌ **Missing:** AVAudioEngine instance initialization
- ❌ **Missing:** Audio tap for buffer processing
- ❌ **Missing:** WAV file player
- ❌ **Missing:** WAV file recorder
- ⚠️ **Partial:** Microphone manager (has structure, needs integration)

### 2. Session Engine
- ⚠️ **Partial:** Save/load exists but untested
- ❌ **Missing:** Session validation
- ❌ **Missing:** Error handling for corrupt files
- ❌ **Missing:** Migration support for schema changes

### 3. Multi-Touch Switchable Mode
- ❌ **Missing:** No multi-touch gesture recognizer
- ⚠️ **Partial:** Mode enum exists (VisualizationMode)
- ❌ **Missing:** Mode state machine integration
- ❌ **Missing:** Mode switcher UI component

### 4. Orientation Auto-Detection
- ❌ **Missing:** No orientation change observer
- ❌ **Missing:** No layout adaptation logic
- ❌ **Missing:** No portrait/landscape-specific layouts

### 5. Rendering Pipeline Skeleton
- ⚠️ **Partial:** Visualization renderers exist
- ❌ **Missing:** Renderer lifecycle management
- ❌ **Missing:** Renderer switching logic
- ❌ **Missing:** Audio → Visual data pipeline

### 6. Device Capability Detection
- ⚠️ **Partial:** DeviceCapabilities class exists
- ❌ **Missing:** Actual capability detection implementation
- ❌ **Missing:** Wearable device detection
- ❌ **Missing:** Desktop vs mobile differentiation

---

## 📦 BUILD PLAN

### Phase 3 Implementation - Current Branch

**Branch:** `claude/echoelmusic-phase3-migrate-01DsLLpgYQKonYVPjn2E9EJW`

#### Commit 6: AudioCore Implementation
**Estimated:** 8 hours
**Tasks:**
- [ ] A.1-A.5: Clean up Blab references, fix imports (2h)
- [ ] B.1: Define EventBus event types (2h)
- [ ] C.1, C.2, C.6: Implement AudioEngine start/stop/input (4h)
- [ ] E.5: Add minimal UI controls (1h)

**Deliverable:** App compiles and can start/stop audio

#### Commit 7: ControlHub Implementation
**Estimated:** 6 hours
**Tasks:**
- [ ] D.1: Implement 60Hz control loop (3h)
- [ ] D.2: Wire to EventBus (2h)
- [ ] D.7: Add performance monitoring (1h)

**Deliverable:** Control loop runs at stable 60Hz with EventBus events

#### Commit 8: Session Implementation
**Estimated:** 6 hours
**Tasks:**
- [ ] H.1: Verify/fix Session save/load (3h)
- [ ] H.2: Add roundtrip tests (2h)
- [ ] Final integration testing (1h)

**Deliverable:** Sessions can be saved/loaded reliably

**Total Branch Time:** ~20 hours (2-3 days)

---

### Phase 3+ Future PRs

#### PR 1: Merge Audio Routing
**Branch:** `claude/merge-routing-graph-01DsLLpgYQKonYVPjn2E9EJW`
**Estimated:** 6 hours
**Tasks:**
- [ ] B.3: Merge NodeGraph + RoutingGraph (4h)
- [ ] C.7: Integrate routing with AudioEngine (2h)

#### PR 2: Multi-Touch + Orientation
**Branch:** `claude/multitouch-orientation-01DsLLpgYQKonYVPjn2E9EJW`
**Estimated:** 8 hours
**Tasks:**
- [ ] E.1: Multi-touch gesture detection (4h)
- [ ] E.2, E.3: Orientation auto-detect + layout adapt (4h)

#### PR 3: Rendering Pipeline
**Branch:** `claude/rendering-pipeline-01DsLLpgYQKonYVPjn2E9EJW`
**Estimated:** 12 hours
**Tasks:**
- [ ] F.1: Basic waveform visualization (3h)
- [ ] F.3: Spectral analyzer (FFT) (4h)
- [ ] Renderer lifecycle management (3h)
- [ ] Audio → Visual data pipeline (2h)

#### PR 4: HealthKit Integration
**Branch:** `claude/healthkit-bio-01DsLLpgYQKonYVPjn2E9EJW`
**Estimated:** 8 hours
**Tasks:**
- [ ] G.1: HealthKit HRV integration (4h)
- [ ] G.2: Bio-parameter mapping (3h)
- [ ] Integration with ControlHub (1h)

---

## ✅ GO → READY TO IMPLEMENT CHECKLIST

### Pre-Implementation Checklist

- [ ] **1. Review unified master plan** (this document)
- [ ] **2. Confirm current branch:** `claude/echoelmusic-phase3-migrate-01DsLLpgYQKonYVPjn2E9EJW`
- [ ] **3. Verify all 5 migration commits are pushed**
- [ ] **4. Read FIRST IMPLEMENTATION PACKAGE section**
- [ ] **5. Understand the 6-package approach (A → H)**

### Implementation Checklist (Commit 6-8)

#### Commit 6: AudioCore (Package 1-5)
- [ ] **6.1** Run Blab cleanup script (Package 1)
- [ ] **6.2** Create `Events.swift` with event types (Package 2)
- [ ] **6.3** Implement AudioEngine start/stop/input (Package 3)
- [ ] **6.4** Implement UnifiedControlHub 60Hz loop (Package 4)
- [ ] **6.5** Add minimal UI controls (Package 5)
- [ ] **6.6** Test: App compiles
- [ ] **6.7** Test: App launches
- [ ] **6.8** Test: Can start audio (mic input)
- [ ] **6.9** Test: Audio level displayed in UI
- [ ] **6.10** Commit: "feat(audio): Implement AudioCore start/stop/input with 60Hz control loop"

#### Commit 7: ControlHub (Already in Commit 6)
- [x] Merged with Commit 6

#### Commit 8: Session (Package 6)
- [ ] **8.1** Add Session validation method (Package 6)
- [ ] **8.2** Create SessionTests.swift (Package 6)
- [ ] **8.3** Test: Session save/load roundtrip
- [ ] **8.4** Test: Session validation errors
- [ ] **8.5** Commit: "feat(core): Add Session validation and tests"

### Post-Implementation Checklist

- [ ] **9. Run all tests:** `swift test`
- [ ] **10. Verify no "Blab" in code:** `grep -r "Blab" Sources/Echoelmusic*/`
- [ ] **11. Build on device:** Test on actual iPhone
- [ ] **12. Create migration report addendum**
- [ ] **13. Push all commits**
- [ ] **14. Create draft PR**

### Ready to Merge Checklist

- [ ] **15. All tests passing**
- [ ] **16. Code review completed**
- [ ] **17. Performance validated (60Hz stable)**
- [ ] **18. No regressions in existing features**
- [ ] **19. Documentation updated**
- [ ] **20. PR approved and merged**

---

## 🎯 SUCCESS CRITERIA

After implementing FIRST IMPLEMENTATION PACKAGE, the app should:

✅ **Compile** without errors
✅ **Launch** on iOS simulator/device
✅ **Start audio** engine with microphone input
✅ **Display** audio level in UI
✅ **Run** 60Hz control loop (verified in console)
✅ **Publish** EventBus events
✅ **Save** session to disk
✅ **Load** session from disk (roundtrip verified)

---

## 📊 EFFORT SUMMARY

| Category | P1 Tasks | P1 Hours | P2 Tasks | P2 Hours | P3 Tasks | P3 Hours | Total Hours |
|----------|----------|----------|----------|----------|----------|----------|-------------|
| A) Cleanup | 5 | 3 | 2 | 1 | 0 | 0 | 4 |
| B) Architecture | 1 | 2 | 3 | 4 | 1 | 4 | 10 |
| C) Audio | 6 | 14 | 4 | 16 | 0 | 0 | 30 |
| D) Control | 3 | 8 | 5 | 12 | 0 | 0 | 20 |
| E) UI/UX | 2 | 4 | 5 | 12 | 0 | 0 | 16 |
| F) Rendering | 0 | 0 | 3 | 12 | 3 | 18 | 30 |
| G) ML/Bio | 0 | 0 | 2 | 8 | 3 | 30 | 38 |
| H) Session | 2 | 6 | 2 | 6 | 2 | 20 | 32 |
| I) Platform | 0 | 0 | 2 | 6 | 3 | 18 | 24 |
| J) Future | 0 | 0 | 0 | 0 | 5 | 40 | 40 |
| **TOTALS** | **19** | **37** | **28** | **77** | **17** | **130** | **244** |

**FIRST IMPLEMENTATION PACKAGE:** 25 hours (subset of P1: A.1-A.5, B.1, C.1-C.2/C.6, D.1-D.2/D.7, E.5, H.1-H.2)

---

## 📝 RECOMMENDED PR SEQUENCE

1. **Current Branch (Phase 3 Complete)** - `claude/echoelmusic-phase3-migrate-01DsLLpgYQKonYVPjn2E9EJW`
   - Commits 1-5: ✅ Migration complete
   - Commits 6-8: ⏳ Implementation (FIRST PACKAGE)
   - **Timeline:** 3 days (20 hours)
   - **Merge:** When app compiles/launches/plays audio

2. **PR: Merge Audio Routing** - `claude/merge-routing-graph-01DsLLpgYQKonYVPjn2E9EJW`
   - Merge NodeGraph + RoutingGraph
   - Integrate with AudioEngine
   - **Timeline:** 1 day (6 hours)

3. **PR: Multi-Touch + Orientation** - `claude/multitouch-orientation-01DsLLpgYQKonYVPjn2E9EJW`
   - Multi-touch gesture detection
   - Orientation auto-detect + layout
   - **Timeline:** 1 day (8 hours)

4. **PR: Rendering Pipeline** - `claude/rendering-pipeline-01DsLLpgYQKonYVPjn2E9EJW`
   - Waveform + FFT visualization
   - Renderer lifecycle
   - **Timeline:** 2 days (12 hours)

5. **PR: HealthKit Integration** - `claude/healthkit-bio-01DsLLpgYQKonYVPjn2E9EJW`
   - HRV monitoring
   - Bio-parameter mapping
   - **Timeline:** 1 day (8 hours)

**Total Timeline to Functional App:** ~8 days (54 hours of dev time)

---

## 🚀 NEXT IMMEDIATE STEPS

### Step 1: Execute FIRST IMPLEMENTATION PACKAGE

```bash
# Verify current branch
git branch --show-current
# Should output: claude/echoelmusic-phase3-migrate-01DsLLpgYQKonYVPjn2E9EJW

# Start implementation
echo "Starting FIRST IMPLEMENTATION PACKAGE..."

# Package 1: Clean up Blab references
find Sources/Echoelmusic* -name "*.swift" -exec sed -i '' \
    -e 's/in Blab/in Echoelmusic/g' \
    -e 's/for Blab/for Echoelmusic/g' \
    {} \;

# Package 2: Create Events.swift
# (Use code from Package 2 section above)

# Package 3-6: Implement AudioEngine, ControlHub, UI, Session
# (Use code from respective package sections above)

# Test compilation
swift build

# If successful, commit
git add -A
git commit -m "feat(audio/control/core): Implement FIRST IMPLEMENTATION PACKAGE

- Clean up remaining Blab references
- Define core EventBus event types
- Implement AudioEngine start/stop/input
- Implement UnifiedControlHub 60Hz loop with EventBus
- Add minimal UI controls for audio
- Add Session validation and roundtrip tests

**Status:** App now compiles, launches, and plays audio ✨"

# Push
git push origin claude/echoelmusic-phase3-migrate-01DsLLpgYQKonYVPjn2E9EJW
```

### Step 2: Verify Success

```bash
# Build and test
swift build && swift test

# Check for Blab references
grep -r "Blab" Sources/Echoelmusic* || echo "✅ No Blab references found"

# Run on simulator
open -a Simulator
# Then build and run in Xcode
```

### Step 3: Create Draft PR

```bash
gh pr create \
  --title "Phase 3: Complete Modular Architecture + Basic Implementation" \
  --body "$(cat MIGRATION_REPORT.md)

---

## Implementation Complete

**FIRST IMPLEMENTATION PACKAGE:**
- ✅ AudioEngine start/stop/input
- ✅ UnifiedControlHub 60Hz loop
- ✅ EventBus event types
- ✅ Session save/load with tests
- ✅ Minimal UI controls

**Status:** App compiles, launches, and plays audio.

**Next Steps:** See UNIFIED_MASTER_PLAN.md for future PRs." \
  --draft
```

---

**END OF UNIFIED MASTER PLAN**

**Status:** ✅ **READY TO IMPLEMENT**
**Next Action:** Execute FIRST IMPLEMENTATION PACKAGE (Packages 1-6)
**Estimated Time:** 25 hours (3 days)

---

**Generated:** 2025-11-14
**Maintained By:** Claude (Sonnet 4.5)
**Branch:** `claude/echoelmusic-phase3-migrate-01DsLLpgYQKonYVPjn2E9EJW`
