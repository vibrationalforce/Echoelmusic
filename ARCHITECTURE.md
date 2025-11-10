# Echoelmusic - Software Architecture

Modern, scalable, maintainable architecture based on industry best practices.

---

## 📐 Architecture Principles

### SOLID Principles

**S** - Single Responsibility Principle
- Each class has ONE reason to change
- Example: `AudioEngine` handles audio, `VideoEngine` handles video (not mixed)

**O** - Open/Closed Principle
- Open for extension, closed for modification
- Use protocols/interfaces for extensibility

**L** - Liskov Substitution Principle
- Subclasses must be substitutable for base classes
- All `BiofeedbackProvider` implementations work interchangeably

**I** - Interface Segregation Principle
- Many specific interfaces > one general interface
- `AudioProcessor`, `VideoProcessor`, `BiofeedbackSource` (not one `MediaProcessor`)

**D** - Dependency Inversion Principle
- Depend on abstractions, not concretions
- Inject dependencies via protocols

### Clean Architecture (Uncle Bob)

```
┌─────────────────────────────────────────────────┐
│                  Presentation                    │  ← SwiftUI Views
│  (UI, ViewModels, Coordinators)                 │
├─────────────────────────────────────────────────┤
│                    Use Cases                     │  ← Business Logic
│  (Interactors, Application Services)            │
├─────────────────────────────────────────────────┤
│                   Domain Layer                   │  ← Core Business
│  (Entities, Value Objects, Domain Services)     │
├─────────────────────────────────────────────────┤
│                 Infrastructure                   │  ← External
│  (Repositories, APIs, Database, Hardware)       │
└─────────────────────────────────────────────────┘
```

**Dependency Rule**: Inner layers NEVER depend on outer layers

### Domain-Driven Design (DDD)

- **Entities**: Objects with identity (User, Project, Track)
- **Value Objects**: Immutable objects (Frequency, Amplitude, Color)
- **Aggregates**: Cluster of entities (AudioProject = Tracks + Effects + Settings)
- **Repositories**: Abstract data access
- **Domain Services**: Business logic that doesn't fit in entities
- **Domain Events**: Events that domain experts care about (TrackRecorded, EffectApplied)

---

## 🏗️ Architecture Patterns

### 1. Clean Architecture Layers

#### **Presentation Layer** (`Sources/Echoelmusic/Presentation/`)
```
Presentation/
├── Views/
│   ├── Audio/
│   │   ├── AudioEditorView.swift
│   │   ├── MixerView.swift
│   │   └── WaveformView.swift
│   ├── Video/
│   │   ├── VideoEditorView.swift
│   │   ├── TimelineView.swift
│   │   └── PreviewView.swift
│   └── Shared/
│       ├── Components/
│       └── Modifiers/
├── ViewModels/
│   ├── AudioEditorViewModel.swift
│   ├── VideoEditorViewModel.swift
│   └── BiofeedbackViewModel.swift
└── Coordinators/
    ├── AppCoordinator.swift
    └── NavigationCoordinator.swift
```

**Responsibilities**:
- UI rendering (SwiftUI)
- User input handling
- Display logic ONLY
- NO business logic

#### **Use Cases Layer** (`Sources/Echoelmusic/UseCases/`)
```
UseCases/
├── Audio/
│   ├── RecordAudioUseCase.swift
│   ├── ApplyEffectUseCase.swift
│   └── ExportAudioUseCase.swift
├── Video/
│   ├── CaptureVideoUseCase.swift
│   ├── ApplyLUTUseCase.swift
│   └── ExportVideoUseCase.swift
└── Biofeedback/
    ├── MonitorHRVUseCase.swift
    └── GenerateTherapeuticAudioUseCase.swift
```

**Responsibilities**:
- Application business logic
- Orchestrate domain objects
- Transaction boundaries
- Input validation

#### **Domain Layer** (`Sources/Echoelmusic/Domain/`)
```
Domain/
├── Entities/
│   ├── Track.swift
│   ├── Effect.swift
│   ├── Project.swift
│   └── BiofeedbackSession.swift
├── ValueObjects/
│   ├── Frequency.swift
│   ├── Amplitude.swift
│   ├── TimeCode.swift
│   └── Color.swift
├── Services/
│   ├── AudioProcessingService.swift
│   ├── VideoProcessingService.swift
│   └── BiofeedbackAnalysisService.swift
├── Repositories/
│   ├── ProjectRepository.swift
│   ├── EffectRepository.swift
│   └── PresetRepository.swift
└── Events/
    ├── TrackRecorded.swift
    ├── EffectApplied.swift
    └── SessionCompleted.swift
```

**Responsibilities**:
- Core business logic
- Domain rules and invariants
- Platform-agnostic
- No dependencies on outer layers

#### **Infrastructure Layer** (`Sources/Echoelmusic/Infrastructure/`)
```
Infrastructure/
├── Persistence/
│   ├── CoreData/
│   ├── SQLite/
│   └── FileSystem/
├── Network/
│   ├── API/
│   ├── Streaming/
│   └── CloudSync/
├── Hardware/
│   ├── Audio/
│   │   ├── CoreAudio/
│   │   └── AVFoundation/
│   ├── Video/
│   │   ├── VideoToolbox/
│   │   └── Metal/
│   ├── Sensors/
│   │   ├── HealthKit/
│   │   └── CoreMotion/
│   └── Controllers/
│       ├── MIDI/
│       └── DMX/
└── External/
    ├── Analytics/
    ├── Crash Reporting/
    └── Cloud Services/
```

**Responsibilities**:
- External system integration
- Database access
- API calls
- Hardware interfacing
- Third-party libraries

---

## 🎯 Design Patterns Used

### Creational Patterns

**1. Factory Pattern**
```swift
protocol AudioEngineFactory {
    func createEngine(config: AudioConfig) -> AudioEngine
}

class DefaultAudioEngineFactory: AudioEngineFactory {
    func createEngine(config: AudioConfig) -> AudioEngine {
        switch config.latencyMode {
        case .ultraLow:
            return UltraLowLatencyEngine(config: config)
        case .balanced:
            return BalancedAudioEngine(config: config)
        case .highQuality:
            return HighQualityAudioEngine(config: config)
        }
    }
}
```

**2. Builder Pattern**
```swift
class AudioProjectBuilder {
    private var tracks: [Track] = []
    private var effects: [Effect] = []
    private var tempo: Int = 120
    private var sampleRate: Double = 48000

    func addTrack(_ track: Track) -> Self {
        tracks.append(track)
        return self
    }

    func setTempo(_ tempo: Int) -> Self {
        self.tempo = tempo
        return self
    }

    func build() -> AudioProject {
        return AudioProject(
            tracks: tracks,
            effects: effects,
            tempo: tempo,
            sampleRate: sampleRate
        )
    }
}

// Usage
let project = AudioProjectBuilder()
    .addTrack(vocals)
    .addTrack(guitar)
    .setTempo(140)
    .build()
```

**3. Singleton Pattern** (sparingly)
```swift
@MainActor
class AppConfiguration {
    static let shared = AppConfiguration()
    private init() {}  // Prevent external instantiation

    var theme: Theme = .dark
    var audioBufferSize: Int = 512
}
```

### Structural Patterns

**4. Adapter Pattern**
```swift
// Adapt HealthKit to our domain
protocol BiofeedbackProvider {
    func getHeartRate() async -> HeartRate?
    func getHRV() async -> HRV?
}

class HealthKitAdapter: BiofeedbackProvider {
    private let healthStore = HKHealthStore()

    func getHeartRate() async -> HeartRate? {
        // Adapt HealthKit's API to our domain model
        let samples = try? await fetchHeartRateSamples()
        return samples?.last.map { HeartRate(bpm: $0) }
    }

    func getHRV() async -> HRV? {
        // Similar adaptation
    }
}
```

**5. Facade Pattern**
```swift
// Simplify complex subsystems
class AudioProductionFacade {
    private let engine: AudioEngine
    private let recorder: AudioRecorder
    private let mixer: AudioMixer
    private let exporter: AudioExporter

    func startRecording() {
        engine.configure()
        recorder.prepare()
        recorder.start()
    }

    func applyEffect(_ effect: Effect) {
        mixer.addEffect(effect)
        engine.process()
    }

    func export(to url: URL) async throws {
        try await exporter.export(mixer.mix(), to: url)
    }
}
```

**6. Decorator Pattern**
```swift
protocol AudioEffect {
    func process(_ buffer: AudioBuffer) -> AudioBuffer
}

class ReverbEffect: AudioEffect {
    func process(_ buffer: AudioBuffer) -> AudioBuffer {
        // Add reverb
    }
}

class DelayDecorator: AudioEffect {
    private let decorated: AudioEffect

    init(decorating effect: AudioEffect) {
        self.decorated = effect
    }

    func process(_ buffer: AudioBuffer) -> AudioBuffer {
        let processed = decorated.process(buffer)
        // Add delay on top
        return addDelay(to: processed)
    }
}

// Usage: Stack effects
let effect = DelayDecorator(
    decorating: ReverbEffect()
)
```

### Behavioral Patterns

**7. Observer Pattern** (via Combine)
```swift
class AudioEngine: ObservableObject {
    @Published var currentLevel: Float = 0.0
    @Published var isClipping: Bool = false

    private var cancellables = Set<AnyCancellable>()

    func setupObservers() {
        $currentLevel
            .filter { $0 > 1.0 }
            .sink { [weak self] _ in
                self?.isClipping = true
            }
            .store(in: &cancellables)
    }
}
```

**8. Strategy Pattern**
```swift
protocol CompressionStrategy {
    func compress(_ video: Video) async throws -> CompressedVideo
}

class H264Strategy: CompressionStrategy {
    func compress(_ video: Video) async throws -> CompressedVideo {
        // H.264 compression
    }
}

class AV1Strategy: CompressionStrategy {
    func compress(_ video: Video) async throws -> CompressedVideo {
        // AV1 compression (better quality)
    }
}

class VideoCompressor {
    private var strategy: CompressionStrategy

    func setStrategy(_ strategy: CompressionStrategy) {
        self.strategy = strategy
    }

    func compress(_ video: Video) async throws -> CompressedVideo {
        return try await strategy.compress(video)
    }
}
```

**9. Command Pattern**
```swift
protocol Command {
    func execute()
    func undo()
}

class AddEffectCommand: Command {
    private let mixer: AudioMixer
    private let effect: Effect

    func execute() {
        mixer.addEffect(effect)
    }

    func undo() {
        mixer.removeEffect(effect)
    }
}

class CommandHistory {
    private var commands: [Command] = []
    private var currentIndex = -1

    func execute(_ command: Command) {
        command.execute()
        commands.append(command)
        currentIndex += 1
    }

    func undo() {
        guard currentIndex >= 0 else { return }
        commands[currentIndex].undo()
        currentIndex -= 1
    }

    func redo() {
        guard currentIndex < commands.count - 1 else { return }
        currentIndex += 1
        commands[currentIndex].execute()
    }
}
```

**10. Chain of Responsibility**
```swift
protocol EffectProcessor {
    var next: EffectProcessor? { get set }
    func process(_ buffer: AudioBuffer) -> AudioBuffer
}

class EqualizerProcessor: EffectProcessor {
    var next: EffectProcessor?

    func process(_ buffer: AudioBuffer) -> AudioBuffer {
        let eqBuffer = applyEQ(buffer)
        return next?.process(eqBuffer) ?? eqBuffer
    }
}

class CompressionProcessor: EffectProcessor {
    var next: EffectProcessor?

    func process(_ buffer: AudioBuffer) -> AudioBuffer {
        let compressed = applyCompression(buffer)
        return next?.process(compressed) ?? compressed
    }
}

// Chain: Input → EQ → Compression → Reverb → Output
let eq = EqualizerProcessor()
let comp = CompressionProcessor()
let reverb = ReverbProcessor()

eq.next = comp
comp.next = reverb

let output = eq.process(input)
```

---

## 🔄 Reactive Programming (Combine)

### Publishers & Subscribers
```swift
class AudioLevelMonitor {
    let levelPublisher = PassthroughSubject<Float, Never>()

    func measureLevel() {
        // Publish level changes
        levelPublisher.send(currentLevel)
    }
}

class LevelMeter {
    private var cancellables = Set<AnyCancellable>()

    func subscribe(to monitor: AudioLevelMonitor) {
        monitor.levelPublisher
            .debounce(for: 0.1, scheduler: RunLoop.main)  // Throttle updates
            .removeDuplicates()                            // Skip duplicates
            .sink { [weak self] level in
                self?.updateDisplay(level)
            }
            .store(in: &cancellables)
    }
}
```

### Functional Reactive Programming
```swift
// Transform, filter, combine streams
audioEngine.levelPublisher
    .map { $0 > 1.0 }                    // Convert to boolean (clipping?)
    .removeDuplicates()                   // Only when changes
    .sink { isClipping in
        if isClipping {
            showClippingWarning()
        }
    }
    .store(in: &cancellables)

// Combine multiple streams
Publishers.CombineLatest(
    audioEngine.levelPublisher,
    biofeedback.hrvPublisher
)
.map { audioLevel, hrv in
    // Adjust audio based on HRV (bio-reactive)
    return audioLevel * (hrv / 100.0)
}
.sink { adjustedLevel in
    audioEngine.setLevel(adjustedLevel)
}
.store(in: &cancellables)
```

---

## 🌐 Concurrency (Swift 6 / Strict Concurrency)

### Actor Model (Thread-Safe State)
```swift
actor AudioBufferPool {
    private var pool: [AudioBuffer] = []

    func acquire() -> AudioBuffer? {
        return pool.popLast()
    }

    func release(_ buffer: AudioBuffer) {
        pool.append(buffer)
    }
}

// Usage (automatically thread-safe)
let buffer = await bufferPool.acquire()
defer { await bufferPool.release(buffer) }
```

### Async/Await
```swift
func processAudio() async throws {
    // Sequential async operations
    let recording = try await recorder.record()
    let processed = try await processor.process(recording)
    let exported = try await exporter.export(processed)

    print("✅ Exported to \(exported.url)")
}

// Parallel async operations
async let vocals = processTrack(vocalsTrack)
async let guitar = processTrack(guitarTrack)
async let drums = processTrack(drumsTrack)

let mixed = try await mixer.mix([vocals, guitar, drums])
```

### Task Groups (Parallel Processing)
```swift
func exportMultipleFormats(_ video: Video) async throws {
    try await withThrowingTaskGroup(of: URL.self) { group in
        // Export to multiple formats in parallel
        group.addTask { try await export(video, format: .h264) }
        group.addTask { try await export(video, format: .hevc) }
        group.addTask { try await export(video, format: .av1) }

        for try await url in group {
            print("✅ Exported: \(url)")
        }
    }
}
```

---

## 📊 Event Sourcing & CQRS

### Event Sourcing
```swift
// Store events, not current state
protocol DomainEvent {
    var timestamp: Date { get }
    var aggregateId: UUID { get }
}

struct TrackRecorded: DomainEvent {
    let timestamp: Date
    let aggregateId: UUID
    let duration: TimeInterval
    let sampleRate: Double
}

struct EffectApplied: DomainEvent {
    let timestamp: Date
    let aggregateId: UUID
    let effectType: EffectType
    let parameters: [String: Any]
}

class EventStore {
    private var events: [DomainEvent] = []

    func append(_ event: DomainEvent) {
        events.append(event)
    }

    func getEvents(for aggregateId: UUID) -> [DomainEvent] {
        return events.filter { $0.aggregateId == aggregateId }
    }

    func rebuild(aggregateId: UUID) -> Track {
        let events = getEvents(for: aggregateId)
        return Track.from(events: events)  // Rebuild state from events
    }
}
```

### CQRS (Command Query Responsibility Segregation)
```swift
// Commands (Write Model)
protocol Command {}

struct RecordTrackCommand: Command {
    let projectId: UUID
    let trackName: String
    let duration: TimeInterval
}

struct ApplyEffectCommand: Command {
    let trackId: UUID
    let effect: Effect
}

// Queries (Read Model)
protocol Query {}

struct GetProjectQuery: Query {
    let projectId: UUID
}

struct GetTracksQuery: Query {
    let projectId: UUID
}

// Separate handlers
class CommandHandler {
    func handle(_ command: RecordTrackCommand) async throws {
        // Modify state
        let event = TrackRecorded(...)
        eventStore.append(event)
    }
}

class QueryHandler {
    func handle(_ query: GetProjectQuery) async throws -> Project {
        // Read optimized view
        return readModel.getProject(query.projectId)
    }
}
```

---

## 🧪 Testing Architecture

### Test Pyramid
```
        ┌─────────┐
        │   E2E   │  ← Few, slow, fragile (UI tests)
        ├─────────┤
        │Integration│  ← Moderate number (API, DB tests)
        ├─────────┤
        │   Unit  │  ← Many, fast, reliable
        └─────────┘
```

### Unit Tests (Fast, Isolated)
```swift
class AudioProcessorTests: XCTestCase {
    func testApplyGain() {
        // Arrange
        let processor = AudioProcessor()
        let input = createSilentBuffer(frameCount: 1000)

        // Act
        let output = processor.applyGain(2.0, to: input)

        // Assert
        XCTAssertEqual(output.peak, input.peak * 2.0)
    }
}
```

### Integration Tests
```swift
class AudioEngineIntegrationTests: XCTestCase {
    func testRecordAndProcess() async throws {
        // Test full recording pipeline
        let engine = AudioEngine()
        try await engine.start()
        let recording = try await engine.record(duration: 1.0)
        let processed = try await engine.process(recording)

        XCTAssertNotNil(processed)
    }
}
```

### UI Tests (SwiftUI)
```swift
class AudioEditorUITests: XCTestCase {
    func testRecordButton() {
        let app = XCUIApplication()
        app.launch()

        let recordButton = app.buttons["Record"]
        recordButton.tap()

        XCTAssertTrue(app.staticTexts["Recording..."].exists)
    }
}
```

---

## 📈 Performance Optimization

### Lazy Loading
```swift
class TrackManager {
    // Don't load all tracks upfront
    private(set) lazy var tracks: [Track] = {
        return loadTracksFromDisk()
    }()
}
```

### Memoization (Caching)
```swift
class FFTProcessor {
    private var cache: [Int: [Float]] = [:]

    func computeFFT(samples: [Float]) -> [Float] {
        let key = samples.hashValue

        if let cached = cache[key] {
            return cached  // Return cached result
        }

        let result = performFFT(samples)
        cache[key] = result
        return result
    }
}
```

### Object Pooling
```swift
class AudioBufferPool {
    private var availableBuffers: [AudioBuffer] = []

    func acquire(size: Int) -> AudioBuffer {
        if let buffer = availableBuffers.popLast() {
            return buffer
        }
        return AudioBuffer(size: size)  // Create new if none available
    }

    func release(_ buffer: AudioBuffer) {
        buffer.reset()
        availableBuffers.append(buffer)
    }
}
```

---

## 🔒 Security Best Practices

### 1. Never store sensitive data in UserDefaults
```swift
// ❌ BAD
UserDefaults.standard.set(apiKey, forKey: "apiKey")

// ✅ GOOD - Use Keychain
KeychainManager.save(apiKey, for: "apiKey")
```

### 2. Input validation
```swift
func processAudio(url: URL) throws {
    // Validate file exists
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw AudioError.fileNotFound
    }

    // Validate file type
    guard url.pathExtension == "wav" || url.pathExtension == "mp3" else {
        throw AudioError.invalidFormat
    }

    // Validate file size (prevent DOS)
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    let fileSize = attributes[.size] as? UInt64 ?? 0
    guard fileSize < 500_000_000 else {  // 500 MB limit
        throw AudioError.fileTooLarge
    }
}
```

### 3. Sanitize user input
```swift
func createProject(name: String) throws {
    // Sanitize filename
    let sanitized = name
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "\\", with: "_")
        .prefix(255)  // Max filename length

    guard !sanitized.isEmpty else {
        throw ProjectError.invalidName
    }

    // Proceed with sanitized name
}
```

---

## 📚 Documentation Standards

### Code Documentation (SwiftDoc)
```swift
/// Processes audio buffer with specified effect
///
/// This function applies a digital audio effect to the input buffer
/// and returns a new buffer with the processed audio.
///
/// - Parameters:
///   - buffer: Input audio buffer (unmodified)
///   - effect: Effect to apply (reverb, delay, etc.)
/// - Returns: New buffer with processed audio
/// - Throws: `AudioError.processingFailed` if DSP fails
///
/// - Complexity: O(n) where n = buffer length
/// - Performance: ~0.1ms for 512-sample buffer @ 48kHz
///
/// # Example
/// ```swift
/// let reverb = ReverbEffect(roomSize: 0.8)
/// let processed = try processAudio(inputBuffer, effect: reverb)
/// ```
///
/// - Note: Original buffer is not modified (functional style)
/// - Warning: Large buffers may cause memory pressure
///
/// - SeeAlso: `AudioEffect`, `AudioBuffer`
func processAudio(_ buffer: AudioBuffer, effect: AudioEffect) throws -> AudioBuffer {
    // Implementation
}
```

### Architecture Decision Records (ADR)
```markdown
# ADR-001: Use Clean Architecture

## Status
Accepted

## Context
Need maintainable, testable codebase for complex multimedia app

## Decision
Adopt Clean Architecture with clear layer separation

## Consequences
+ Clear separation of concerns
+ Highly testable
+ Platform-independent domain logic
- More boilerplate code
- Steeper learning curve
```

---

## 🎯 Summary

Echoelmusic architecture follows **industry best practices**:

✅ **SOLID Principles** (clean, maintainable code)
✅ **Clean Architecture** (testable, decoupled layers)
✅ **Domain-Driven Design** (business logic first)
✅ **Design Patterns** (proven solutions)
✅ **Reactive Programming** (responsive, async)
✅ **Actor Model** (thread-safe concurrency)
✅ **Event Sourcing** (audit trail, time travel)
✅ **CQRS** (optimized reads/writes)
✅ **Test Pyramid** (comprehensive testing)
✅ **Security First** (validated, sanitized, encrypted)
✅ **Well-Documented** (SwiftDoc, ADRs)

**Result**: World-class software architecture ready for scale! 🚀
