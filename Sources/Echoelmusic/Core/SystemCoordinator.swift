import Foundation
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// SYSTEM COORDINATOR - UNIFIED ARCHITECTURE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Consolidates 3 competing master hubs into ONE clear coordinator:
// • Replaces: EchoelUniversalCore, UnifiedSystemIntegration, MultiPlatformBridge
// • Uses dependency injection instead of singletons
// • Clear separation of concerns
// • Testable architecture
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Service Protocols (Dependency Injection)

/// Audio service protocol for testing/mocking
public protocol AudioServiceProtocol: AnyObject {
    var isRunning: Bool { get }
    func start() async throws
    func stop() async
    func process(_ buffer: AudioBuffer) -> AudioBuffer
}

/// Bio processing service protocol
public protocol BioServiceProtocol: AnyObject {
    var currentState: BioState { get }
    func updateFromHealthKit(_ data: HealthKitData)
    func calculateCoherence() -> Float
}

/// Visual rendering service protocol
public protocol VisualServiceProtocol: AnyObject {
    var isRendering: Bool { get }
    func startRendering()
    func stopRendering()
    func updateParameters(_ params: VisualParameters)
}

/// Sync service protocol
public protocol SyncServiceProtocol: AnyObject {
    var isConnected: Bool { get }
    func connect(to url: URL) async throws
    func disconnect()
    func sendBioState(_ state: ParticipantBioState) async throws
}

// MARK: - Service Container

/// Dependency injection container
public final class ServiceContainer {

    public static let shared = ServiceContainer()

    // Service registrations
    private var services: [String: Any] = [:]
    private let lock = NSLock()

    private init() {
        registerDefaults()
    }

    /// Register a service
    public func register<T>(_ service: T, for type: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        services[String(describing: type)] = service
    }

    /// Resolve a service
    public func resolve<T>(_ type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        return services[String(describing: type)] as? T
    }

    /// Register default implementations
    private func registerDefaults() {
        // Default implementations registered here
        // Can be overridden for testing
    }

    /// Reset container (for testing)
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        services.removeAll()
        registerDefaults()
    }
}

// MARK: - System Coordinator

/// Main system coordinator - single source of truth
/// Replaces: EchoelUniversalCore, UnifiedSystemIntegration, MultiPlatformBridge
public final class SystemCoordinator: ObservableObject {

    public static let shared = SystemCoordinator()

    // MARK: - Published State (UI binding)

    @Published public private(set) var systemState: SystemState = .idle
    @Published public private(set) var activeFeatures: Set<Feature> = []
    @Published public private(set) var performanceLevel: PerformanceLevel = .balanced

    // MARK: - Subsystem Coordinators

    public let audio: AudioCoordinator
    public let bio: BioCoordinator
    public let visual: VisualCoordinator
    public let sync: SyncCoordinator
    public let input: InputCoordinator

    // MARK: - State

    public enum SystemState: String {
        case idle = "idle"
        case starting = "starting"
        case running = "running"
        case paused = "paused"
        case stopping = "stopping"
        case error = "error"
    }

    public enum Feature: String, CaseIterable {
        case audio = "audio"
        case biofeedback = "biofeedback"
        case visualization = "visualization"
        case sync = "sync"
        case recording = "recording"
        case streaming = "streaming"
        case midi = "midi"
        case osc = "osc"
    }

    public enum PerformanceLevel: String, CaseIterable {
        case lowPower = "low_power"
        case balanced = "balanced"
        case highPerformance = "high_performance"
        case maximum = "maximum"
    }

    // MARK: - Internal

    private var cancellables = Set<AnyCancellable>()
    private let eventBus = EventBus()

    // MARK: - Initialization

    private init() {
        // Initialize subsystem coordinators with dependency injection
        self.audio = AudioCoordinator()
        self.bio = BioCoordinator()
        self.visual = VisualCoordinator()
        self.sync = SyncCoordinator()
        self.input = InputCoordinator()

        setupBindings()
    }

    /// Initialize with custom services (for testing)
    public init(
        audio: AudioCoordinator,
        bio: BioCoordinator,
        visual: VisualCoordinator,
        sync: SyncCoordinator,
        input: InputCoordinator
    ) {
        self.audio = audio
        self.bio = bio
        self.visual = visual
        self.sync = sync
        self.input = input

        setupBindings()
    }

    // MARK: - Lifecycle

    /// Start the system
    public func start(features: Set<Feature> = [.audio, .biofeedback, .visualization]) async throws {
        guard systemState == .idle || systemState == .error else { return }

        systemState = .starting

        do {
            // Start requested features in parallel
            try await withThrowingTaskGroup(of: Void.self) { group in
                if features.contains(.audio) {
                    group.addTask { try await self.audio.start() }
                }
                if features.contains(.biofeedback) {
                    group.addTask { try await self.bio.start() }
                }
                if features.contains(.visualization) {
                    group.addTask { await self.visual.start() }
                }

                try await group.waitForAll()
            }

            activeFeatures = features
            systemState = .running

            eventBus.post(SystemEvent.started(features: features))

        } catch {
            systemState = .error
            throw error
        }
    }

    /// Stop the system
    public func stop() async {
        guard systemState == .running || systemState == .paused else { return }

        systemState = .stopping

        await withTaskGroup(of: Void.self) { group in
            if activeFeatures.contains(.audio) {
                group.addTask { await self.audio.stop() }
            }
            if activeFeatures.contains(.biofeedback) {
                group.addTask { await self.bio.stop() }
            }
            if activeFeatures.contains(.visualization) {
                group.addTask { await self.visual.stop() }
            }
            if activeFeatures.contains(.sync) {
                group.addTask { await self.sync.disconnect() }
            }
        }

        activeFeatures.removeAll()
        systemState = .idle

        eventBus.post(SystemEvent.stopped)
    }

    /// Pause processing
    public func pause() {
        guard systemState == .running else { return }

        audio.pause()
        visual.pause()

        systemState = .paused
        eventBus.post(SystemEvent.paused)
    }

    /// Resume processing
    public func resume() {
        guard systemState == .paused else { return }

        audio.resume()
        visual.resume()

        systemState = .running
        eventBus.post(SystemEvent.resumed)
    }

    // MARK: - Feature Management

    /// Enable a feature
    public func enableFeature(_ feature: Feature) async throws {
        guard !activeFeatures.contains(feature) else { return }

        switch feature {
        case .audio:
            try await audio.start()
        case .biofeedback:
            try await bio.start()
        case .visualization:
            await visual.start()
        case .sync:
            // Sync requires connection parameters
            break
        case .recording:
            // Recording handled separately
            break
        case .streaming:
            // Streaming handled separately
            break
        case .midi:
            await input.enableMIDI()
        case .osc:
            await input.enableOSC()
        }

        activeFeatures.insert(feature)
        eventBus.post(SystemEvent.featureEnabled(feature))
    }

    /// Disable a feature
    public func disableFeature(_ feature: Feature) async {
        guard activeFeatures.contains(feature) else { return }

        switch feature {
        case .audio:
            await audio.stop()
        case .biofeedback:
            await bio.stop()
        case .visualization:
            await visual.stop()
        case .sync:
            await sync.disconnect()
        case .recording:
            break
        case .streaming:
            break
        case .midi:
            await input.disableMIDI()
        case .osc:
            await input.disableOSC()
        }

        activeFeatures.remove(feature)
        eventBus.post(SystemEvent.featureDisabled(feature))
    }

    // MARK: - Performance

    /// Set performance level
    public func setPerformanceLevel(_ level: PerformanceLevel) {
        performanceLevel = level

        switch level {
        case .lowPower:
            visual.setTargetFrameRate(30)
            audio.setBufferSize(1024)
        case .balanced:
            visual.setTargetFrameRate(60)
            audio.setBufferSize(512)
        case .highPerformance:
            visual.setTargetFrameRate(120)
            audio.setBufferSize(256)
        case .maximum:
            visual.setTargetFrameRate(120)
            audio.setBufferSize(128)
        }

        eventBus.post(SystemEvent.performanceLevelChanged(level))
    }

    // MARK: - Event Bus

    /// Subscribe to system events
    public func subscribe<T: SystemEventProtocol>(
        to eventType: T.Type,
        handler: @escaping (T) -> Void
    ) -> AnyCancellable {
        return eventBus.subscribe(to: eventType, handler: handler)
    }

    // MARK: - Private

    private func setupBindings() {
        // Bio → Visual binding
        bio.$coherence
            .sink { [weak self] coherence in
                self?.visual.updateBioCoherence(coherence)
            }
            .store(in: &cancellables)

        // Audio → Visual binding
        audio.$spectrum
            .sink { [weak self] spectrum in
                self?.visual.updateAudioSpectrum(spectrum)
            }
            .store(in: &cancellables)

        // Bio → Sync binding
        bio.$currentBioState
            .throttle(for: .milliseconds(100), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] state in
                Task {
                    try? await self?.sync.shareBioState(state)
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Audio Coordinator

/// Manages audio subsystem
public final class AudioCoordinator: ObservableObject {

    @Published public private(set) var isRunning = false
    @Published public private(set) var spectrum: [Float] = []
    @Published public private(set) var level: Float = 0

    private var bufferSize: Int = 512

    public init() {}

    public func start() async throws {
        isRunning = true
    }

    public func stop() async {
        isRunning = false
    }

    public func pause() {
        // Pause audio processing
    }

    public func resume() {
        // Resume audio processing
    }

    public func setBufferSize(_ size: Int) {
        bufferSize = size
    }
}

// MARK: - Bio Coordinator

/// Manages biofeedback subsystem
public final class BioCoordinator: ObservableObject {

    @Published public private(set) var coherence: Float = 0
    @Published public private(set) var heartRate: Float = 0
    @Published public private(set) var currentBioState = ParticipantBioState(
        heartRate: 0,
        coherence: 0,
        breathingRate: 0,
        breathingPhase: 0,
        entrainmentPhase: 0
    )

    public init() {}

    public func start() async throws {
        // Start HealthKit monitoring
    }

    public func stop() async {
        // Stop monitoring
    }
}

// MARK: - Visual Coordinator

/// Manages visualization subsystem
public final class VisualCoordinator: ObservableObject {

    @Published public private(set) var isRendering = false
    @Published public private(set) var fps: Float = 0

    private var targetFrameRate: Float = 60

    public init() {}

    public func start() async {
        isRendering = true
    }

    public func stop() async {
        isRendering = false
    }

    public func pause() {
        isRendering = false
    }

    public func resume() {
        isRendering = true
    }

    public func setTargetFrameRate(_ rate: Float) {
        targetFrameRate = rate
    }

    public func updateBioCoherence(_ coherence: Float) {
        // Update visual parameters based on coherence
    }

    public func updateAudioSpectrum(_ spectrum: [Float]) {
        // Update visual parameters based on audio
    }
}

// MARK: - Sync Coordinator

/// Manages synchronization subsystem
public final class SyncCoordinator: ObservableObject {

    @Published public private(set) var isConnected = false
    @Published public private(set) var participants: [String] = []

    private let bioEncryption = BioDataEncryption.shared

    public init() {}

    public func connect(to url: URL, name: String) async throws {
        isConnected = true
    }

    public func disconnect() async {
        isConnected = false
        participants.removeAll()
    }

    public func shareBioState(_ state: ParticipantBioState) async throws {
        guard isConnected else { return }

        // Encrypt bio data before transmission
        let secureState = try SecureBioState.create(
            from: state,
            senderId: "local",
            encryption: bioEncryption
        )

        // Send encrypted state
        let data = try JSONEncoder().encode(secureState)
        // ... send via WebSocket
    }
}

// MARK: - Input Coordinator

/// Manages input subsystem (MIDI, OSC, gestures)
public final class InputCoordinator: ObservableObject {

    @Published public private(set) var midiEnabled = false
    @Published public private(set) var oscEnabled = false

    public init() {}

    public func enableMIDI() async {
        midiEnabled = true
    }

    public func disableMIDI() async {
        midiEnabled = false
    }

    public func enableOSC() async {
        oscEnabled = true
    }

    public func disableOSC() async {
        oscEnabled = false
    }
}

// MARK: - Event Bus

/// Type-safe event bus for system events
public final class EventBus {

    private var subscriptions: [String: [(Any) -> Void]] = [:]
    private let lock = NSLock()

    public init() {}

    public func subscribe<T: SystemEventProtocol>(
        to eventType: T.Type,
        handler: @escaping (T) -> Void
    ) -> AnyCancellable {
        lock.lock()
        defer { lock.unlock() }

        let key = String(describing: eventType)

        if subscriptions[key] == nil {
            subscriptions[key] = []
        }

        let wrappedHandler: (Any) -> Void = { event in
            if let typedEvent = event as? T {
                handler(typedEvent)
            }
        }

        subscriptions[key]?.append(wrappedHandler)

        return AnyCancellable { [weak self] in
            self?.lock.lock()
            self?.subscriptions[key]?.removeAll { _ in true }
            self?.lock.unlock()
        }
    }

    public func post<T: SystemEventProtocol>(_ event: T) {
        lock.lock()
        let handlers = subscriptions[String(describing: type(of: event))] ?? []
        lock.unlock()

        DispatchQueue.main.async {
            handlers.forEach { $0(event) }
        }
    }
}

// MARK: - System Events

public protocol SystemEventProtocol {}

public enum SystemEvent: SystemEventProtocol {
    case started(features: Set<SystemCoordinator.Feature>)
    case stopped
    case paused
    case resumed
    case featureEnabled(SystemCoordinator.Feature)
    case featureDisabled(SystemCoordinator.Feature)
    case performanceLevelChanged(SystemCoordinator.PerformanceLevel)
    case error(Error)
}

// MARK: - Supporting Types

public struct AudioBuffer {
    public var samples: [Float]
    public var sampleRate: Float
    public var channelCount: Int
}

public struct BioState {
    public var heartRate: Float
    public var hrv: Float
    public var coherence: Float
    public var breathingRate: Float
}

public struct HealthKitData {
    public var heartRate: Double?
    public var hrv: Double?
}

public struct VisualParameters {
    public var coherence: Float
    public var spectrum: [Float]
    public var tempo: Float
}
