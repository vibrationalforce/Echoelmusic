# Echoelmusic Wise Mode Self-Improvement Prompt

> **Purpose:** Comprehensive prompt for AI-assisted continuous improvement of the Echoelmusic codebase
> **Version:** 1.0 | **Created:** 2025-12-11

---

## System Context

You are improving **Echoelmusic**, a multimodal bio-reactive audio-visual music creation platform.

**Tech Stack:**
- Swift 5.9+ (60,980+ LOC across 131 source files)
- Platforms: iOS 15+, macOS 12+, watchOS, tvOS, visionOS, Android, Windows, Linux
- Frameworks: AVFoundation, Metal, Combine, HealthKit, CoreMIDI, ARKit, Vision
- Build: Swift Package Manager, CMake (C++), XcodeGen

**Core Features:**
- Real-time audio processing with 60 Hz control loop
- MIDI 2.0/MPE support (15-voice polyphonic expression)
- Spatial audio (6 modes: Stereo, 3D, 4D Orbital, AFA, Binaural, Ambisonics)
- Biofeedback integration (HRV, heart rate, coherence)
- Visual rendering (Cymatics, Mandala, Waveform, Spectral, Particles)
- LED control (Push 3, DMX/Art-Net, WS2812B)
- Face tracking (52 ARKit blend shapes) + hand gestures (Vision)

---

## Improvement Directives

### 1. SCAN Phase - Deep Codebase Analysis

Before making changes, perform comprehensive analysis:

```
SCAN PROTOCOL:
1. Read DEVELOPER_SUGGESTIONS_WISE_MODE.md for current recommendations
2. Check existing Core infrastructure (Logger, EchoelErrors, EventBus, etc.)
3. Identify patterns already established in the codebase
4. Search for: force unwraps (!), fatalError, print statements, TODOs
5. Analyze test coverage gaps
6. Review SwiftLint violations if available
```

**Key Files to Reference:**
- `/Sources/Echoelmusic/Core/Logger.swift` - Logging patterns
- `/Sources/Echoelmusic/Core/EchoelErrors.swift` - Error handling patterns
- `/Sources/Echoelmusic/Core/InputValidator.swift` - Validation patterns
- `/Sources/Echoelmusic/Core/Protocols.swift` - Architecture patterns
- `/Sources/Echoelmusic/Core/EventBus.swift` - Event patterns
- `/Sources/Echoelmusic/Core/DependencyContainer.swift` - DI patterns
- `/.swiftlint.yml` - Code quality rules

---

### 2. IMPROVE Phase - Code Quality Enhancements

#### A. Force Unwrap Elimination (P0 Priority)

**Search Pattern:**
```swift
// Find force unwraps
grep -rn "!" --include="*.swift" Sources/ | grep -v "!=" | grep -v "!//"
```

**Replacement Pattern:**
```swift
// BEFORE (unsafe)
let value = optionalValue!
let item = array[index]!

// AFTER (safe)
guard let value = optionalValue else {
    Logger.error("Expected value was nil", category: .system)
    return
}

guard let item = array[safe: index] else {
    Logger.warning("Index out of bounds", category: .system)
    return
}
```

#### B. Logger Integration

**Replace print statements:**
```swift
// BEFORE
print("Audio engine started")

// AFTER
Logger.info("Audio engine started", category: .audio)
```

**Add performance signposts:**
```swift
// For hot paths
Logger.measure("ProcessAudioBuffer", category: .performance) {
    // ... processing code
}
```

#### C. Error Handling Enhancement

**Use domain-specific errors:**
```swift
// BEFORE
throw NSError(domain: "Audio", code: 1, userInfo: nil)

// AFTER
throw AudioEngineError.deviceNotAvailable(reason: "No input device")
```

#### D. Input Validation

**Add validation at boundaries:**
```swift
// BEFORE
func setVolume(_ volume: Float) {
    self.volume = volume
}

// AFTER
func setVolume(_ volume: Float) {
    self.volume = InputValidator.validateAudioLevel(volume)
}
```

#### E. Event Bus Integration

**Decouple module communication:**
```swift
// BEFORE (tight coupling)
audioEngine.delegate = visualizer
audioEngine.onLevelChange = { level in visualizer.update(level) }

// AFTER (decoupled)
EventBus.shared.emit(.audioLevelChanged(level))

// In visualizer
EventBus.shared.onAudioLevel { level in
    self.update(level: level)
}
```

---

### 3. TEST Phase - Coverage Expansion

**Priority Test Areas:**
1. `Video/` - No tests (5 files, ~2,700 LOC)
2. `Performance/` - No tests (2 files, ~1,496 LOC)
3. `Stream/` - No tests (5 files)
4. `Recording/` - Partial (10 files)

**Test Template:**
```swift
import XCTest
@testable import Echoelmusic

final class [Module]Tests: XCTestCase {

    var sut: [SystemUnderTest]!  // System Under Test

    override func setUp() {
        super.setUp()
        sut = [SystemUnderTest]()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Unit Tests

    func test[Behavior]_when[Condition]_should[ExpectedResult]() {
        // Given
        let input = ...

        // When
        let result = sut.method(input)

        // Then
        XCTAssertEqual(result, expected)
    }

    // MARK: - Performance Tests

    func test[Operation]Performance() {
        measure {
            for _ in 0..<1000 {
                _ = sut.operation()
            }
        }
    }
}
```

---

### 4. REFACTOR Phase - Architecture Improvements

#### A. Large File Decomposition

**Files exceeding 500 LOC to split:**
| File | Current LOC | Split Into |
|------|-------------|------------|
| `TouchInstruments.swift` | 1,171 | `KeyboardView`, `DrumPadView`, `StringsView` |
| `MultiCamStabilizer.swift` | 1,021 | `GyroStabilizer`, `VisualStabilizer` |
| `TR808BassSynth.swift` | 966 | `OscillatorBank`, `FilterChain`, `EnvelopeGenerator` |
| `VideoEditingEngine.swift` | 935 | `TimelineManager`, `EffectsProcessor`, `ExportPipeline` |

#### B. Protocol Conformance

**Add protocol conformance to existing types:**
```swift
// Make audio nodes conform to AudioProcessable
extension CompressorNode: AudioProcessable {
    func process(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? { ... }
    func reset() { ... }
}

// Make bio-reactive components conform to BioReactive
extension CymaticsRenderer: BioReactive {
    func onHeartRateUpdate(_ bpm: Double) { ... }
    func onHRVUpdate(_ rmssd: Double) { ... }
    func onCoherenceUpdate(_ score: Double) { ... }
}
```

#### C. Dependency Injection

**Register services in DependencyContainer:**
```swift
// In DependencyContainer.registerCoreServices()
registerFactory { RealAudioEngine() as AudioEngineProtocol }
registerFactory { RealMIDIManager() as MIDIServiceProtocol }
```

---

### 5. DOCUMENT Phase - Documentation Enhancement

#### A. DocC Comments

**Add documentation to public APIs:**
```swift
/// Generates binaural beats for brainwave entrainment.
///
/// Binaural beats occur when two tones of slightly different frequencies
/// are presented to each ear, creating a perceived third tone.
///
/// - Parameter brainwaveState: The target brainwave state
/// - Returns: Audio buffer containing the binaural beat
/// - Throws: `AudioEngineError.bufferAllocationFailed` if buffer cannot be created
///
/// ## Example
/// ```swift
/// let generator = BinauralBeatGenerator(baseFrequency: 200)
/// let buffer = try generator.generateBeat(brainwaveState: .alpha)
/// ```
public func generateBeat(brainwaveState: BrainwaveState) throws -> AVAudioPCMBuffer
```

#### B. Architecture Decision Records

**Create ADRs for significant decisions:**
```markdown
# ADR-XXX: [Title]

## Status
[Proposed | Accepted | Deprecated | Superseded]

## Context
[Why is this decision needed?]

## Decision
[What was decided?]

## Consequences
[What are the implications?]
```

---

### 6. SECURE Phase - Security Hardening

#### A. Keychain Usage

**Store sensitive data securely:**
```swift
// API keys, tokens, credentials
try SecureStorage.save(apiKey.data(using: .utf8)!, forKey: "api_key")
let apiKey = try SecureStorage.load(forKey: "api_key")
```

#### B. Input Sanitization

**Sanitize all user inputs:**
```swift
let safeName = InputValidator.sanitizeUserInput(userInput)
let safeFilename = InputValidator.validateFilename(filename)
let safeURL = InputValidator.validateURL(urlString)
```

#### C. Rate Limiting

**Protect expensive operations:**
```swift
let limiter = RateLimiter(maxRequests: 10, windowSeconds: 60)

func makeAPICall() async throws {
    guard await limiter.isAllowed() else {
        let waitTime = await limiter.timeUntilAllowed()
        throw NetworkError.rateLimited(retryAfter: waitTime)
    }
    await limiter.recordRequest()
    // ... make call
}
```

---

### 7. OPTIMIZE Phase - Performance Improvements

#### A. SIMD Optimization

**Use SIMD for audio/visual processing:**
```swift
import simd

// Vectorized operations
func processFFTBins(_ bins: UnsafeMutablePointer<Float>, count: Int) {
    let simdCount = count / 4
    bins.withMemoryRebound(to: SIMD4<Float>.self, capacity: simdCount) { simdBins in
        for i in 0..<simdCount {
            simdBins[i] = simd_clamp(simdBins[i], .zero, .one)
        }
    }
}
```

#### B. Async/Await Parallelism

**Use task groups for parallel operations:**
```swift
func loadAssets(_ urls: [URL]) async throws -> [Asset] {
    try await withThrowingTaskGroup(of: (Int, Asset).self) { group in
        for (index, url) in urls.enumerated() {
            group.addTask { (index, try await Asset.load(from: url)) }
        }

        var results = [Asset?](repeating: nil, count: urls.count)
        for try await (index, asset) in group {
            results[index] = asset
        }
        return results.compactMap { $0 }
    }
}
```

#### C. Memory Management

**Prevent retain cycles:**
```swift
// Use [weak self] in closures
audioEngine.onBufferReady = { [weak self] buffer in
    self?.processBuffer(buffer)
}

// Cancel Combine subscriptions
class ViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    deinit {
        cancellables.forEach { $0.cancel() }
    }
}
```

---

## Execution Checklist

When running Wise Mode improvements, follow this order:

```
[ ] 1. SCAN - Read existing patterns and identify issues
[ ] 2. PLAN - Create TodoWrite list of specific improvements
[ ] 3. IMPROVE - Make changes following established patterns
[ ] 4. TEST - Add/update tests for changed code
[ ] 5. VERIFY - Run existing tests if possible
[ ] 6. DOCUMENT - Update docs if behavior changed
[ ] 7. COMMIT - Commit with descriptive message
[ ] 8. PUSH - Push to feature branch
```

---

## Commit Message Format

```
<type>(<scope>): <description>

<body>

<footer>
```

**Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `perf`, `chore`

**Example:**
```
feat(audio): Add SIMD optimization to FFT processing

- Vectorized FFT bin processing using SIMD4<Float>
- 4x throughput improvement for 1024-sample buffers
- Added performance tests

Closes #123
```

---

## Quality Gates

Before completing any improvement session:

1. **No new force unwraps** introduced
2. **All new code uses Logger** instead of print
3. **Errors use domain-specific types** from EchoelErrors
4. **Input validation** at all boundaries
5. **Tests added** for new functionality
6. **SwiftLint rules** not violated
7. **Existing patterns** followed consistently

---

## Session Prompt Template

Use this when starting a new improvement session:

```
I am continuing Wise Mode improvements on Echoelmusic.

Current focus: [AREA - e.g., "Audio module force unwrap elimination"]

Please:
1. Scan the [AREA] for issues
2. Create a TodoWrite plan
3. Implement improvements following patterns in:
   - /Sources/Echoelmusic/Core/Logger.swift
   - /Sources/Echoelmusic/Core/EchoelErrors.swift
   - /Sources/Echoelmusic/Core/InputValidator.swift
4. Add tests for changes
5. Commit and push to the feature branch

Reference: DEVELOPER_SUGGESTIONS_WISE_MODE.md
Reference: WISE_MODE_SELF_PROMPT.md
```

---

## Metrics to Track

| Metric | Current | Target | Check Command |
|--------|---------|--------|---------------|
| Force Unwraps | ~280 | 0 | `grep -rn "!" Sources/ \| grep -v "!=" \| wc -l` |
| Print Statements | Unknown | 0 | `grep -rn "print(" Sources/ \| wc -l` |
| Test Files | 10 | 20+ | `ls Tests/EchoelmusicTests/*.swift \| wc -l` |
| Max File LOC | 1,171 | <500 | `wc -l Sources/**/*.swift \| sort -n \| tail -10` |
| TODOs | 20+ | <10 | `grep -rn "TODO" Sources/ \| wc -l` |

---

## Priority Queue (P0 → P3)

**P0 - Critical (Do First):**
- [ ] Eliminate force unwraps in audio-critical paths
- [ ] Thread safety audit for 60 Hz control loop
- [ ] Convert TODOs to GitHub issues

**P1 - High:**
- [ ] Test coverage for Video, Stream, Performance modules
- [ ] Refactor files >500 LOC
- [ ] Complete Logger integration

**P2 - Medium:**
- [ ] DocC documentation for public APIs
- [ ] Performance benchmarks
- [ ] SwiftUI previews for all views

**P3 - Low:**
- [ ] Vision Pro AR visualization
- [ ] Cloud sync architecture
- [ ] Vapor backend integration

---

*This prompt is self-improving. Update it as new patterns emerge.*
*Last Updated: 2025-12-11*
