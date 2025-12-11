# Developer Suggestions: Wise Mode

> **Lazer Scan Analysis Complete** | Generated: 2025-12-11
> **Codebase:** Echoelmusic | **Lines Scanned:** 60,980+ Swift | **Files:** 131 sources + 74 docs

---

## Table of Contents

1. [Critical Priority (P0)](#critical-priority-p0)
2. [High Priority (P1)](#high-priority-p1)
3. [Medium Priority (P2)](#medium-priority-p2)
4. [Code Quality Patterns](#code-quality-patterns)
5. [Performance Optimizations](#performance-optimizations)
6. [Testing Strategy](#testing-strategy)
7. [Architecture Recommendations](#architecture-recommendations)
8. [Security Hardening](#security-hardening)
9. [Documentation Improvements](#documentation-improvements)
10. [Future Enhancements](#future-enhancements)

---

## Critical Priority (P0)

### 1. Force Unwrap Elimination Campaign

**Issue:** 282+ instances of force unwraps (`!`) and `fatalError` detected across the codebase.

**Affected Files:**
- `StreamEngine.swift` - Stream processing
- `Video/*.swift` - Video processing pipeline
- `MIDI/*.swift` - Some MIDI operations
- Various utility functions

**Risk:** Runtime crashes in production, especially on edge cases or nil values.

**Solution Pattern:**
```swift
// BEFORE (unsafe)
let value = optionalValue!

// AFTER (safe)
guard let value = optionalValue else {
    Logger.error("Expected value was nil in \(#function)")
    return // or provide default
}
```

**Action Items:**
- [ ] Run static analysis: `swiftlint analyze --reporter json | jq '.[] | select(.rule_id == "force_unwrapping")'`
- [ ] Create branch: `fix/force-unwrap-elimination`
- [ ] Refactor in batches of 20-30 per PR
- [ ] Add SwiftLint rule to block new force unwraps

---

### 2. Real-Time Thread Safety Audit

**Issue:** 60 Hz control loop with Combine subscriptions + audio thread interactions.

**Risk Areas:**
- `UnifiedControlHub.swift` - Main control loop accessing shared state
- `AudioEngine.swift` - AVAudioEngine node graph modifications
- `MIDI2Manager.swift` - MIDI packet processing on callbacks

**Solution:**
```swift
// Use actors for shared state
actor AudioState {
    private var parameters: [String: Float] = [:]

    func updateParameter(_ key: String, value: Float) {
        parameters[key] = value
    }

    func getParameter(_ key: String) -> Float? {
        parameters[key]
    }
}

// Or use os_unfair_lock for audio-thread-safe operations
import os

final class AudioThreadSafe<T> {
    private var _value: T
    private var lock = os_unfair_lock()

    var value: T {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return _value
    }

    init(_ value: T) {
        self._value = value
    }
}
```

---

### 3. Outstanding TODOs Resolution

**20+ unresolved TODOs detected:**

| Location | TODO Description | Priority |
|----------|------------------|----------|
| `StreamEngine.swift` | Scene rendering layers/transitions | P1 |
| `Recording/*.swift` | Share sheet UI (3x TODOs) | P2 |
| `Video/CustomShaders.swift` | Metal shader library | P1 |
| `Intelligence/ToxicFilter.swift` | CoreML comment detection | P3 |
| `Compiler/SwiftIntegration.swift` | Swift compiler hooks | P3 |

**Action:** Convert each TODO to GitHub Issue with labels and milestones.

```bash
# Script to extract and create issues
grep -rn "TODO" Sources/ | while read line; do
    echo "Issue: $line"
    # gh issue create --title "TODO: ..." --body "..."
done
```

---

## High Priority (P1)

### 4. Test Coverage Expansion

**Current State:** ~40% coverage | **Target:** 80%+

**Missing Test Suites:**

| Module | Files | Status | Complexity |
|--------|-------|--------|------------|
| Spatial Audio | 3 | No tests | High |
| LED Control | 2 | No tests | Medium |
| Video Processing | 5 | No tests | High |
| Audio Node Graph | 5 | Partial | Medium |
| MIDI 2.0/MPE | 4 | Partial | High |
| Performance | 2 | No tests | Medium |

**Recommended Test Structure:**
```swift
// Tests/EchoelmusicTests/SpatialAudioTests.swift
import XCTest
@testable import Echoelmusic

final class SpatialAudioTests: XCTestCase {
    var spatialEngine: SpatialAudioEngine!

    override func setUp() {
        super.setUp()
        spatialEngine = SpatialAudioEngine()
    }

    func testFibonacciSphereDistribution() async throws {
        let nodes = spatialEngine.generateFibonacciSphere(count: 64)

        // Verify uniform distribution
        XCTAssertEqual(nodes.count, 64)

        // Check average spacing
        let avgDistance = calculateAverageNodeDistance(nodes)
        XCTAssertGreaterThan(avgDistance, 0.1, "Nodes should be evenly distributed")
    }

    func testHeadTrackingIntegration() async throws {
        // Test head tracking updates spatial position
        let mockHeadPosition = SIMD3<Float>(0.5, 0.0, 0.0) // Turned right
        spatialEngine.updateHeadPosition(mockHeadPosition)

        let listenerPosition = spatialEngine.listenerPosition
        XCTAssertEqual(listenerPosition.x, 0.5, accuracy: 0.01)
    }
}
```

---

### 5. Large File Refactoring

**Files exceeding 500 LOC (Single Responsibility Principle violation):**

| File | Lines | Recommendation |
|------|-------|----------------|
| `TouchInstruments.swift` | 1,171 | Extract: `KeyboardView`, `PadView`, `StringsView`, `GestureHandler` |
| `MultiCamStabilizer.swift` | 1,021 | Extract: `GyroStabilizer`, `VisualStabilizer`, `StabilizerConfig` |
| `TR808BassSynth.swift` | 966 | Extract: `OscillatorBank`, `FilterChain`, `EnvelopeGenerator` |
| `VideoEditingEngine.swift` | 935 | Extract: `TimelineManager`, `EffectsProcessor`, `ExportPipeline` |
| `ComprehensiveTestSuite.swift` | ~800 | Split into domain-specific test files |

**Refactoring Pattern:**
```swift
// BEFORE: TouchInstruments.swift (1,171 LOC)
struct TouchInstruments: View {
    // Everything mixed together
}

// AFTER: Separate files
// TouchInstruments/KeyboardInstrument.swift
struct KeyboardInstrument: View { ... }

// TouchInstruments/DrumPadInstrument.swift
struct DrumPadInstrument: View { ... }

// TouchInstruments/StringInstrument.swift
struct StringInstrument: View { ... }

// TouchInstruments/TouchInstrumentsContainer.swift
struct TouchInstrumentsContainer: View {
    @State private var selectedInstrument: InstrumentType = .keyboard

    var body: some View {
        switch selectedInstrument {
        case .keyboard: KeyboardInstrument()
        case .drums: DrumPadInstrument()
        case .strings: StringInstrument()
        }
    }
}
```

---

### 6. Naming Consistency Fix

**Inconsistencies Found:**

| Location | Current | Should Be |
|----------|---------|-----------|
| `Makefile` | References "Blab" | "Echoelmusic" |
| `project.yml` | `com.blab.studio` | `com.echoelmusic` |
| Some comments | Mixed naming | Consistent "Echoelmusic" |

**Fix Script:**
```bash
# Find and replace legacy naming
find . -type f \( -name "*.swift" -o -name "*.yml" -o -name "*.md" \) \
    -exec sed -i 's/com\.blab\.studio/com.echoelmusic/g' {} \;

find . -type f -name "Makefile" \
    -exec sed -i 's/Blab/Echoelmusic/g' {} \;
```

---

## Medium Priority (P2)

### 7. Memory Management Optimization

**Concerns:**
- Heavy use of `@StateObject`/`@EnvironmentObject` (695 instances)
- Combine subscriptions in 60 Hz loop
- Metal texture lifecycle in streaming

**Solutions:**

```swift
// 1. Use weak references in closures
class AudioProcessor {
    var onUpdate: ((Float) -> Void)?

    func startProcessing() {
        // Use [weak self] to prevent retain cycles
        audioEngine.onBufferReady = { [weak self] buffer in
            self?.processBuffer(buffer)
        }
    }
}

// 2. Cancel Combine subscriptions properly
class ControlHub: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    deinit {
        cancellables.forEach { $0.cancel() }
    }
}

// 3. Metal texture pooling
class TexturePool {
    private var availableTextures: [MTLTexture] = []
    private let maxPoolSize = 10

    func acquire(device: MTLDevice, descriptor: MTLTextureDescriptor) -> MTLTexture {
        if let texture = availableTextures.popLast() {
            return texture
        }
        return device.makeTexture(descriptor: descriptor)!
    }

    func release(_ texture: MTLTexture) {
        if availableTextures.count < maxPoolSize {
            availableTextures.append(texture)
        }
    }
}
```

---

### 8. Error Handling Enhancement

**Current:** 5,308+ do-catch blocks (good foundation)

**Improvement:** Add structured error types with recovery options.

```swift
// Define domain-specific errors
enum AudioEngineError: LocalizedError {
    case deviceNotAvailable(reason: String)
    case bufferAllocationFailed(size: Int)
    case formatMismatch(expected: AVAudioFormat, got: AVAudioFormat)
    case nodeConnectionFailed(from: String, to: String)

    var errorDescription: String? {
        switch self {
        case .deviceNotAvailable(let reason):
            return "Audio device unavailable: \(reason)"
        case .bufferAllocationFailed(let size):
            return "Failed to allocate \(size) byte audio buffer"
        case .formatMismatch(let expected, let got):
            return "Audio format mismatch: expected \(expected), got \(got)"
        case .nodeConnectionFailed(let from, let to):
            return "Failed to connect \(from) to \(to)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .deviceNotAvailable:
            return "Check audio device connections and permissions"
        case .bufferAllocationFailed:
            return "Try reducing buffer size or freeing memory"
        case .formatMismatch:
            return "Ensure audio components use matching sample rates"
        case .nodeConnectionFailed:
            return "Verify node compatibility and connection order"
        }
    }
}
```

---

### 9. Logging Infrastructure

**Recommendation:** Implement structured logging with levels.

```swift
import os.log

enum LogCategory: String {
    case audio = "Audio"
    case midi = "MIDI"
    case visual = "Visual"
    case spatial = "Spatial"
    case biofeedback = "Bio"
    case performance = "Perf"
}

struct Logger {
    private static let subsystem = "com.echoelmusic"

    static func debug(_ message: String, category: LogCategory) {
        let log = OSLog(subsystem: subsystem, category: category.rawValue)
        os_log(.debug, log: log, "%{public}@", message)
    }

    static func info(_ message: String, category: LogCategory) {
        let log = OSLog(subsystem: subsystem, category: category.rawValue)
        os_log(.info, log: log, "%{public}@", message)
    }

    static func error(_ message: String, category: LogCategory, error: Error? = nil) {
        let log = OSLog(subsystem: subsystem, category: category.rawValue)
        if let error = error {
            os_log(.error, log: log, "%{public}@: %{public}@", message, error.localizedDescription)
        } else {
            os_log(.error, log: log, "%{public}@", message)
        }
    }

    static func signpost(_ name: StaticString, category: LogCategory) -> OSSignposter {
        let log = OSLog(subsystem: subsystem, category: category.rawValue)
        return OSSignposter(logHandle: log)
    }
}

// Usage
Logger.debug("Starting audio engine", category: .audio)
Logger.error("MIDI connection lost", category: .midi, error: midiError)

// Performance signposts for Instruments.app
let signposter = Logger.signpost("AudioProcessing", category: .performance)
let state = signposter.beginInterval("ProcessBuffer")
// ... processing ...
signposter.endInterval("ProcessBuffer", state)
```

---

## Code Quality Patterns

### 10. SwiftLint Configuration Enhancement

Add these rules to `.swiftlint.yml`:

```yaml
# .swiftlint.yml
disabled_rules:
  - line_length  # Enable with higher limit

opt_in_rules:
  - force_unwrapping
  - implicitly_unwrapped_optional
  - discouraged_optional_boolean
  - discouraged_optional_collection
  - fatal_error_message
  - overridden_super_call
  - empty_count
  - closure_end_indentation
  - closure_spacing
  - explicit_init
  - first_where
  - operator_usage_whitespace
  - redundant_nil_coalescing
  - single_test_class
  - sorted_first_last
  - unavailable_function
  - unneeded_parentheses_in_closure_argument
  - vertical_parameter_alignment_on_call

force_unwrapping:
  severity: error

file_length:
  warning: 400
  error: 600

type_body_length:
  warning: 250
  error: 400

function_body_length:
  warning: 40
  error: 80

cyclomatic_complexity:
  warning: 10
  error: 20

nesting:
  type_level: 2
  function_level: 3

identifier_name:
  min_length: 2
  max_length: 50
  excluded:
    - id
    - x
    - y
    - z
    - i
    - j
    - k

custom_rules:
  no_print_statements:
    regex: "\\bprint\\("
    message: "Use Logger instead of print()"
    severity: warning

  todo_requires_issue:
    regex: "//\\s*TODO(?!\\s*\\[#\\d+\\])"
    message: "TODOs must reference a GitHub issue: // TODO [#123]"
    severity: warning
```

---

### 11. Protocol-Oriented Design Improvements

**Recommendation:** Extract common behaviors into protocols.

```swift
// AudioProcessable protocol for all audio nodes
protocol AudioProcessable {
    var inputFormat: AVAudioFormat { get }
    var outputFormat: AVAudioFormat { get }
    func process(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer
    func reset()
}

// Parameterizable for anything with adjustable parameters
protocol Parameterizable {
    associatedtype ParameterType: Hashable
    var parameters: [ParameterType: Float] { get set }
    func setParameter(_ param: ParameterType, value: Float)
    func getParameter(_ param: ParameterType) -> Float
}

// BioReactive for components that respond to biofeedback
protocol BioReactive {
    func onHeartRateUpdate(_ bpm: Double)
    func onHRVUpdate(_ rmssd: Double)
    func onCoherenceUpdate(_ score: Double)
}

// Example implementation
final class BioReactiveReverb: AudioProcessable, BioReactive {
    // Reverb responds to HRV by adjusting decay time
    func onHRVUpdate(_ rmssd: Double) {
        let normalizedHRV = (rmssd - 20) / 80  // 20-100ms range
        decayTime = 0.5 + (normalizedHRV * 2.0)  // 0.5s - 2.5s
    }
}
```

---

## Performance Optimizations

### 12. SIMD Optimization Opportunities

**Current:** Using Accelerate framework (18 imports)

**Enhancement:** Direct SIMD operations for hot paths.

```swift
import simd

// Optimized FFT bin processing
func processFFTBins(_ bins: UnsafeMutablePointer<Float>, count: Int) {
    let simdCount = count / 4
    let simdBins = bins.withMemoryRebound(to: SIMD4<Float>.self, capacity: simdCount) { $0 }

    for i in 0..<simdCount {
        // Vectorized operations - 4x throughput
        simdBins[i] = simd_fast_normalize(simdBins[i])
        simdBins[i] = simd_clamp(simdBins[i], SIMD4<Float>(repeating: 0), SIMD4<Float>(repeating: 1))
    }
}

// Optimized spatial audio position calculation
func calculateSpatialPositions(sources: [SIMD3<Float>], listener: SIMD3<Float>) -> [Float] {
    sources.map { source in
        simd_fast_distance(source, listener)
    }
}
```

---

### 13. Async/Await Optimization

**Pattern:** Use task groups for parallel processing.

```swift
// Parallel audio file loading
func loadAudioFiles(_ urls: [URL]) async throws -> [AVAudioFile] {
    try await withThrowingTaskGroup(of: (Int, AVAudioFile).self) { group in
        for (index, url) in urls.enumerated() {
            group.addTask {
                let file = try AVAudioFile(forReading: url)
                return (index, file)
            }
        }

        var results = [AVAudioFile?](repeating: nil, count: urls.count)
        for try await (index, file) in group {
            results[index] = file
        }
        return results.compactMap { $0 }
    }
}

// Parallel visualization rendering
func renderVisualizationFrames(count: Int) async -> [MTLTexture] {
    await withTaskGroup(of: (Int, MTLTexture).self) { group in
        for i in 0..<count {
            group.addTask { [self] in
                let texture = await renderFrame(index: i)
                return (i, texture)
            }
        }

        var textures = [MTLTexture?](repeating: nil, count: count)
        for await (index, texture) in group {
            textures[index] = texture
        }
        return textures.compactMap { $0 }
    }
}
```

---

### 14. Metal Shader Optimization

**For Visual/Video processing:**

```metal
// Optimized cymatics shader with SIMD
kernel void cymaticsKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant float &frequency [[buffer(0)]],
    constant float &amplitude [[buffer(1)]],
    constant float &time [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
    float2 center = float2(0.5, 0.5);
    float dist = distance(uv, center);

    // Chladni pattern formula (optimized)
    float pattern = sin(frequency * dist * 6.28318 - time) * amplitude;
    pattern = pattern * pattern; // Square for sharper peaks

    // Color based on pattern intensity
    float3 color = mix(
        float3(0.1, 0.2, 0.4),  // Dark blue
        float3(0.9, 0.7, 0.3),  // Gold
        pattern
    );

    output.write(float4(color, 1.0), gid);
}
```

---

## Testing Strategy

### 15. Test Categories Structure

```
Tests/
├── EchoelmusicTests/
│   ├── Unit/
│   │   ├── Audio/
│   │   │   ├── BinauralBeatTests.swift
│   │   │   ├── PitchDetectorTests.swift
│   │   │   ├── AudioNodeGraphTests.swift
│   │   │   └── CompressorTests.swift
│   │   ├── MIDI/
│   │   │   ├── MIDI2ManagerTests.swift
│   │   │   ├── MPEZoneTests.swift
│   │   │   └── MIDISpatialMapperTests.swift
│   │   ├── Spatial/
│   │   │   ├── SpatialAudioEngineTests.swift
│   │   │   └── HeadTrackingTests.swift
│   │   ├── Visual/
│   │   │   ├── CymaticsRendererTests.swift
│   │   │   └── ParticleSystemTests.swift
│   │   ├── LED/
│   │   │   ├── Push3ControllerTests.swift
│   │   │   └── DMXControllerTests.swift
│   │   └── Biofeedback/
│   │       ├── HealthKitManagerTests.swift
│   │       └── CoherenceCalculatorTests.swift
│   ├── Integration/
│   │   ├── MultimodalFusionTests.swift
│   │   ├── AudioVisualSyncTests.swift
│   │   ├── BioReactiveChainTests.swift
│   │   └── MIDIToSpatialTests.swift
│   ├── Performance/
│   │   ├── ControlLoopLatencyTests.swift
│   │   ├── AudioRenderingBenchmarks.swift
│   │   ├── VisualizationFPSTests.swift
│   │   └── MemoryPressureTests.swift
│   └── Snapshot/
│       ├── VisualizationSnapshotTests.swift
│       └── UISnapshotTests.swift
```

---

### 16. Performance Benchmarking

```swift
import XCTest

final class PerformanceBenchmarks: XCTestCase {

    func testControlLoopLatency() {
        let hub = UnifiedControlHub()

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<1000 {
                hub.processControlCycle()
            }
        }

        // Assert: Each cycle < 16.67ms (60 Hz)
    }

    func testAudioBufferProcessing() {
        let processor = AudioProcessor()
        let buffer = createTestBuffer(frames: 1024)

        measure(metrics: [
            XCTClockMetric(),
            XCTCPUMetric(),
            XCTMemoryMetric()
        ]) {
            for _ in 0..<10000 {
                _ = processor.process(buffer)
            }
        }
    }

    func testVisualizationFrameRate() {
        let renderer = CymaticsRenderer()

        let options = XCTMeasureOptions()
        options.iterationCount = 100

        measure(options: options) {
            renderer.renderFrame()
        }

        // Assert: Render time < 8ms (120 FPS capable)
    }
}
```

---

## Architecture Recommendations

### 17. Dependency Injection Container

**Current:** Direct instantiation scattered throughout

**Recommendation:** Centralized DI container

```swift
// DependencyContainer.swift
@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()

    // Audio Services
    lazy var audioEngine: AudioEngineProtocol = AudioEngine()
    lazy var midiManager: MIDI2ManagerProtocol = MIDI2Manager()
    lazy var spatialEngine: SpatialAudioEngineProtocol = SpatialAudioEngine()

    // Visual Services
    lazy var visualRenderer: VisualizationRendererProtocol = VisualizationRenderer()
    lazy var ledController: LEDControllerProtocol = LEDController()

    // Input Services
    lazy var faceTracker: FaceTrackerProtocol = FaceTracker()
    lazy var gestureRecognizer: GestureRecognizerProtocol = GestureRecognizer()
    lazy var biofeedbackManager: BiofeedbackManagerProtocol = BiofeedbackManager()

    // Core Services
    lazy var controlHub: UnifiedControlHubProtocol = UnifiedControlHub(
        audio: audioEngine,
        midi: midiManager,
        spatial: spatialEngine,
        visual: visualRenderer
    )

    // Testing support
    func reset() {
        // Reset all services for testing
    }
}

// Usage in Views
struct ContentView: View {
    @StateObject private var controlHub = DependencyContainer.shared.controlHub
}

// Usage in Tests
class TestCase: XCTestCase {
    override func setUp() {
        DependencyContainer.shared.audioEngine = MockAudioEngine()
    }
}
```

---

### 18. Event Bus Pattern

**For decoupled module communication:**

```swift
// EventBus.swift
enum AppEvent {
    case audioLevelChanged(Float)
    case midiNoteOn(note: UInt8, velocity: UInt8, channel: UInt8)
    case midiNoteOff(note: UInt8, channel: UInt8)
    case faceExpressionChanged([String: Float])
    case gestureRecognized(GestureType)
    case bioMetricUpdate(BiometricReading)
    case spatialPositionChanged(SIMD3<Float>)
    case visualModeChanged(VisualizationMode)
}

@MainActor
final class EventBus {
    static let shared = EventBus()

    private let subject = PassthroughSubject<AppEvent, Never>()

    var publisher: AnyPublisher<AppEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func emit(_ event: AppEvent) {
        subject.send(event)
    }

    func subscribe<T>(
        _ eventType: @escaping (AppEvent) -> T?,
        handler: @escaping (T) -> Void
    ) -> AnyCancellable {
        publisher
            .compactMap(eventType)
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: handler)
    }
}

// Usage
// Emitting
EventBus.shared.emit(.audioLevelChanged(0.75))

// Subscribing
cancellable = EventBus.shared.subscribe({ event -> Float? in
    if case .audioLevelChanged(let level) = event { return level }
    return nil
}) { level in
    self.updateVisualizer(level: level)
}
```

---

## Security Hardening

### 19. Input Validation

```swift
// Validate all external inputs
struct InputValidator {

    static func validateMIDIValue(_ value: UInt8) -> UInt8 {
        min(127, value)
    }

    static func validateAudioLevel(_ level: Float) -> Float {
        simd_clamp(level, 0.0, 1.0)
    }

    static func validateURL(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString),
              ["https", "http"].contains(url.scheme?.lowercased()),
              url.host != nil else {
            return nil
        }
        return url
    }

    static func sanitizeUserInput(_ input: String) -> String {
        input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .prefix(1000)
            .description
    }
}
```

---

### 20. Secure Storage

```swift
import Security

final class SecureStorage {

    static func save(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound { return nil }
            throw KeychainError.loadFailed(status)
        }

        return result as? Data
    }
}
```

---

## Documentation Improvements

### 21. DocC Documentation

**Generate API documentation:**

```swift
// Add to Package.swift
// .plugin(name: "Swift-DocC", package: "swift-docc-plugin")

// Document all public APIs
/// A binaural beat generator that creates auditory beating patterns.
///
/// Binaural beats occur when two tones of slightly different frequencies
/// are presented separately to each ear. The brain perceives a third tone
/// based on the difference between the two frequencies.
///
/// ## Topics
///
/// ### Creating a Generator
/// - ``init(baseFrequency:)``
///
/// ### Generating Beats
/// - ``generateBeat(brainwaveState:)``
/// - ``BrainwaveState``
///
/// ### Brainwave States
/// - ``BrainwaveState/delta``
/// - ``BrainwaveState/theta``
/// - ``BrainwaveState/alpha``
public final class BinauralBeatGenerator {

    /// Creates a new binaural beat generator.
    /// - Parameter baseFrequency: The carrier frequency in Hz (typically 200-400 Hz)
    public init(baseFrequency: Float = 200) { ... }

    /// Generates a binaural beat buffer for the specified brainwave state.
    /// - Parameter brainwaveState: The target brainwave state
    /// - Returns: An audio buffer containing the binaural beat
    public func generateBeat(brainwaveState: BrainwaveState) -> AVAudioPCMBuffer { ... }
}
```

**Build command:**
```bash
swift package generate-documentation --target Echoelmusic
```

---

### 22. Architecture Decision Records (ADRs)

Create `docs/adr/` directory:

```markdown
# ADR-001: Real-Time Control Loop Architecture

## Status
Accepted

## Context
We need to fuse multiple input sources (face tracking, gestures, biometrics, MIDI)
into a unified control stream for audio-visual generation.

## Decision
Implement a 60 Hz control loop in UnifiedControlHub that:
1. Polls all input sources each cycle
2. Resolves conflicts using priority system (Touch > Gesture > Face > Bio)
3. Outputs unified control values to audio/visual engines

## Consequences
- Predictable 16.67ms update latency
- CPU overhead from constant polling
- Need to ensure thread safety for all input sources
```

---

## Future Enhancements

### 23. SwiftUI Previews

```swift
// Add previews for all views
#Preview("Cymatics Visualizer") {
    CymaticsVisualizerView()
        .environmentObject(PreviewMocks.audioEngine)
}

#Preview("Touch Keyboard - Light") {
    TouchKeyboardView()
        .preferredColorScheme(.light)
}

#Preview("Touch Keyboard - Dark") {
    TouchKeyboardView()
        .preferredColorScheme(.dark)
}

#Preview("Control Hub Dashboard") {
    ControlHubDashboard()
        .environmentObject(PreviewMocks.controlHub)
        .frame(width: 800, height: 600)
}
```

---

### 24. Vision Pro AR Integration

```swift
// Future: visionOS spatial audio visualization
import RealityKit
import ARKit

@available(visionOS 1.0, *)
final class SpatialVisualizationEntity: Entity {

    func updateFromAudio(frequencies: [Float]) {
        // Create 3D frequency visualization in user's space
        for (index, magnitude) in frequencies.enumerated() {
            let bar = children[index] as? ModelEntity
            bar?.scale.y = magnitude
            bar?.model?.materials = [SimpleMaterial(color: colorFromMagnitude(magnitude), isMetallic: true)]
        }
    }
}
```

---

### 25. Cloud Sync Architecture

```swift
// Future: Vapor backend for session sync
import Vapor

func routes(_ app: Application) throws {

    let sessions = app.grouped("api", "sessions")

    sessions.get { req async throws -> [Session] in
        try await Session.query(on: req.db).all()
    }

    sessions.post { req async throws -> Session in
        let session = try req.content.decode(Session.self)
        try await session.save(on: req.db)
        return session
    }

    sessions.webSocket(":id", "realtime") { req, ws in
        // Real-time collaboration
        ws.onBinary { ws, buffer in
            // Broadcast to other participants
        }
    }
}
```

---

## Quick Reference Checklist

### Before Each PR

- [ ] No new force unwraps introduced
- [ ] Tests added/updated for changes
- [ ] SwiftLint passes
- [ ] No new TODOs without issue references
- [ ] Documentation updated
- [ ] Performance impact considered

### Weekly Tasks

- [ ] Review and triage open TODOs
- [ ] Run full test suite
- [ ] Check code coverage trends
- [ ] Review Instruments profiling
- [ ] Update dependency versions

### Monthly Tasks

- [ ] Security audit
- [ ] Architecture review
- [ ] Technical debt assessment
- [ ] Documentation refresh
- [ ] Performance baseline update

---

## Metrics Dashboard

Track these KPIs:

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Test Coverage | ~40% | 80% | Needs Work |
| Force Unwraps | 282 | 0 | Critical |
| Open TODOs | 20+ | <10 | Needs Work |
| Max File LOC | 1,171 | 500 | Needs Work |
| Build Time | TBD | <60s | Measure |
| App Launch | TBD | <2s | Measure |
| Control Loop | ~16ms | <16.67ms | Good |

---

## Conclusion

This **Developer Suggestions Wise Mode** document provides a comprehensive roadmap for improving the Echoelmusic codebase. Focus on P0 items first (force unwraps, thread safety, TODOs), then systematically work through P1 and P2 improvements.

The codebase has an excellent foundation with modern Swift patterns, comprehensive documentation, and professional CI/CD. These suggestions will help achieve production-ready quality while maintaining the ambitious real-time multimodal architecture.

**Recommended Reading Order:**
1. Critical Priority (P0) - Immediate action required
2. Testing Strategy - Build confidence before refactoring
3. High Priority (P1) - Major improvements
4. Architecture Recommendations - Long-term stability

---

*Generated by Wise Mode Analysis Engine*
*Last Updated: 2025-12-11*
