import SwiftUI
import Combine
import Accelerate
import AVFoundation

#if canImport(CoreMotion)
import CoreMotion
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC ENGINE - ONE ENGINE TO RULE THEM ALL
// ═══════════════════════════════════════════════════════════════════════════════
//
// Unified facade consolidating 47 engines into ONE cross-platform entry point.
//
// Architecture:
// ┌───────────────────────────────────────────────────────────────────────┐
// │                         EchoelEngine                                 │
// │                                                                       │
// │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐      │
// │  │  Audio  │ │  Video  │ │   Bio   │ │ Visual  │ │ Spatial │      │
// │  │ Domain  │ │ Domain  │ │ Domain  │ │ Domain  │ │ Domain  │      │
// │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘      │
// │       └───────────┴──────────┴──────────┴──────────┘               │
// │                           │                                         │
// │                  ┌────────▼────────┐                                │
// │                  │  Shared State   │ ← Single source of truth      │
// │                  │  + Event Bus    │                                │
// │                  └────────┬────────┘                                │
// │                           │                                         │
// │  ┌──────────┐ ┌──────────┐ ┌───────────┐ ┌──────────┐             │
// │  │ AutoScale│ │ Comfort  │ │ Collab    │ │  Export  │             │
// │  │ System   │ │ System   │ │ System    │ │  System  │             │
// │  └──────────┘ └──────────┘ └───────────┘ └──────────┘             │
// └───────────────────────────────────────────────────────────────────────┘
//
// Platforms: iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Engine Protocol

/// Standard lifecycle for all engine subsystems
protocol EngineSubsystem: AnyObject {
    var isActive: Bool { get }
    func activate()
    func deactivate()
    func update(deltaTime: TimeInterval)
}

// MARK: - Engine Mode

/// What the engine is optimized for right now
public enum EngineMode: String, CaseIterable, Identifiable, Codable {
    case studio = "Studio"
    case live = "Live Performance"
    case meditation = "Meditation"
    case video = "Video Production"
    case collaboration = "Collaboration"
    case immersive = "Immersive"
    case dj = "DJ Set"
    case research = "Research"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .studio: return "waveform"
        case .live: return "music.mic"
        case .meditation: return "brain.head.profile"
        case .video: return "film"
        case .collaboration: return "person.3.fill"
        case .immersive: return "visionpro"
        case .dj: return "dial.medium.fill"
        case .research: return "chart.xyaxis.line"
        }
    }

    /// Which subsystems are active in this mode
    var activeSubsystems: Set<SubsystemID> {
        switch self {
        case .studio:
            return [.audio, .visual, .bio, .midi, .mixing, .recording]
        case .live:
            return [.audio, .visual, .bio, .midi, .spatial, .streaming, .lighting, .haptic]
        case .meditation:
            return [.audio, .bio, .visual, .haptic, .spatial, .comfort]
        case .video:
            return [.audio, .video, .visual, .recording, .streaming]
        case .collaboration:
            return [.audio, .bio, .visual, .midi, .collaboration, .streaming]
        case .immersive:
            return [.audio, .visual, .spatial, .bio, .handTracking, .haptic, .comfort]
        case .dj:
            return [.audio, .midi, .visual, .lighting, .streaming]
        case .research:
            return [.audio, .bio, .visual, .recording]
        }
    }
}

/// Identifiers for lazy-loaded subsystems
enum SubsystemID: String, CaseIterable {
    case audio, video, bio, visual, spatial, midi
    case mixing, recording, streaming, lighting
    case haptic, collaboration, handTracking, comfort
    case orchestral, creative, quantum, wellness
}

// MARK: - Unified State

/// Single source of truth for the entire engine
public struct EngineState: Equatable {
    // Transport
    public var bpm: Double = 120
    public var isPlaying: Bool = false
    public var position: TimeInterval = 0

    // Bio
    public var heartRate: Double = 72
    public var hrv: Double = 50
    public var coherence: Float = 0.5
    public var breathingRate: Double = 15
    public var breathPhase: Float = 0

    // Energy
    public var systemEnergy: Float = 0.5
    public var audioLevel: Float = 0
    public var visualIntensity: Float = 0.5

    // Performance
    public var cpuUsage: Float = 0
    public var fps: Double = 60
    public var thermalState: ThermalLevel = .nominal
    public var memoryUsageMB: Double = 0

    public enum ThermalLevel: Int, Comparable {
        case nominal = 0, fair = 1, serious = 2, critical = 3
        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }
}

// MARK: - Event Bus

/// Lightweight event system replacing scattered Combine publishers
public enum EngineEvent {
    // Transport
    case play, pause, stop
    case bpmChanged(Double)
    case positionChanged(TimeInterval)

    // Bio
    case heartRateUpdated(Double)
    case coherenceUpdated(Float)
    case breathPhaseUpdated(Float)

    // Performance
    case thermalWarning(EngineState.ThermalLevel)
    case memoryWarning(Double)
    case fpsDropped(Double)

    // Interaction
    case gestureDetected(GestureKind)
    case handTrackingUpdated(HandData)
    case gazeUpdated(GazeData)

    // Mode
    case modeChanged(EngineMode)
    case subsystemActivated(SubsystemID)
    case subsystemDeactivated(SubsystemID)

    public enum GestureKind {
        case pinch(Float), spread(Float), fist, point, swipe(Direction)
        public enum Direction { case left, right, up, down }
    }

    public struct HandData {
        public var leftPosition: SIMD3<Float>?
        public var rightPosition: SIMD3<Float>?
        public var pinchAmount: Float = 0
    }

    public struct GazeData {
        public var position: SIMD2<Float> = .zero
        public var attention: Float = 0
    }
}

// MARK: - EchoelEngine

@MainActor
public final class EchoelEngine: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelEngine()

    // MARK: - Published State

    @Published public var state = EngineState()
    @Published public var mode: EngineMode = .studio {
        didSet { modeDidChange(from: oldValue, to: mode) }
    }
    @Published public var isRunning: Bool = false
    @Published public private(set) var activeSubsystems: Set<SubsystemID> = []

    // MARK: - Event Bus

    public let eventBus = PassthroughSubject<EngineEvent, Never>()

    // MARK: - Subsystem Registry (Lazy)

    private var subsystems: [SubsystemID: EngineSubsystem] = [:]
    private var displayLink: DisplayLinkProxy?
    private var cancellables = Set<AnyCancellable>()
    private var lastUpdateTime: TimeInterval = 0

    // MARK: - Performance

    private let autoScaler = PerformanceAutoScaler()
    private let comfortSystem = MotionComfortSystem()

    // MARK: - Lifecycle

    private init() {
        setupEventBusSubscriptions()
        setupThermalMonitoring()
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Start / Stop

    public func start(mode: EngineMode = .studio) {
        self.mode = mode
        isRunning = true
        activateSubsystems(for: mode)
        startUpdateLoop()
        ProfessionalLogger.log(.info, category: .audio, "EchoelEngine started in \(mode.rawValue) mode")
    }

    public func stop() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        deactivateAllSubsystems()
        ProfessionalLogger.log(.info, category: .audio, "EchoelEngine stopped")
    }

    // MARK: - Mode Switching

    private func modeDidChange(from oldMode: EngineMode, to newMode: EngineMode) {
        let toDeactivate = oldMode.activeSubsystems.subtracting(newMode.activeSubsystems)
        let toActivate = newMode.activeSubsystems.subtracting(oldMode.activeSubsystems)

        for id in toDeactivate {
            subsystems[id]?.deactivate()
            activeSubsystems.remove(id)
            eventBus.send(.subsystemDeactivated(id))
        }

        for id in toActivate {
            ensureSubsystem(id)
            subsystems[id]?.activate()
            activeSubsystems.insert(id)
            eventBus.send(.subsystemActivated(id))
        }

        autoScaler.adjustForMode(newMode, state: state)
        comfortSystem.adjustForMode(newMode)
        eventBus.send(.modeChanged(newMode))
    }

    // MARK: - Update Loop

    private func startUpdateLoop() {
        displayLink = DisplayLinkProxy { [weak self] dt in
            Task { @MainActor in
                self?.update(deltaTime: dt)
            }
        }
    }

    private func update(deltaTime: TimeInterval) {
        guard isRunning else { return }

        // Update transport
        if state.isPlaying {
            state.position += deltaTime
        }

        // Update active subsystems
        for id in activeSubsystems {
            subsystems[id]?.update(deltaTime: deltaTime)
        }

        // Performance monitoring
        autoScaler.update(state: &state, deltaTime: deltaTime)

        // Comfort system (motion sickness prevention)
        comfortSystem.update(state: state)
    }

    // MARK: - Subsystem Management

    private func activateSubsystems(for mode: EngineMode) {
        for id in mode.activeSubsystems {
            ensureSubsystem(id)
            subsystems[id]?.activate()
            activeSubsystems.insert(id)
        }
    }

    private func deactivateAllSubsystems() {
        for (_, subsystem) in subsystems {
            subsystem.deactivate()
        }
        activeSubsystems.removeAll()
    }

    /// Lazy-creates a subsystem if it doesn't exist yet
    private func ensureSubsystem(_ id: SubsystemID) {
        guard subsystems[id] == nil else { return }
        subsystems[id] = createSubsystem(id)
    }

    private func createSubsystem(_ id: SubsystemID) -> EngineSubsystem {
        switch id {
        case .audio:        return AudioSubsystem(engine: self)
        case .video:        return VideoSubsystem(engine: self)
        case .bio:          return BioSubsystem(engine: self)
        case .visual:       return VisualSubsystem(engine: self)
        case .spatial:      return SpatialSubsystem(engine: self)
        case .midi:         return MIDISubsystem(engine: self)
        case .mixing:       return MixingSubsystem(engine: self)
        case .recording:    return RecordingSubsystem(engine: self)
        case .streaming:    return StreamingSubsystem(engine: self)
        case .lighting:     return LightingSubsystem(engine: self)
        case .haptic:       return HapticSubsystem(engine: self)
        case .collaboration: return CollaborationSubsystem(engine: self)
        case .handTracking: return HandTrackingSubsystem(engine: self)
        case .comfort:      return ComfortSubsystem(engine: self)
        case .orchestral:   return OrchestralSubsystem(engine: self)
        case .creative:     return CreativeSubsystem(engine: self)
        case .quantum:      return QuantumSubsystem(engine: self)
        case .wellness:     return WellnessSubsystem(engine: self)
        }
    }

    // MARK: - Event Bus Subscriptions

    private func setupEventBusSubscriptions() {
        eventBus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleEvent(_ event: EngineEvent) {
        switch event {
        case .play:
            state.isPlaying = true
        case .pause:
            state.isPlaying = false
        case .stop:
            state.isPlaying = false
            state.position = 0
        case .bpmChanged(let bpm):
            state.bpm = bpm
        case .heartRateUpdated(let hr):
            state.heartRate = hr
        case .coherenceUpdated(let c):
            state.coherence = c
        case .breathPhaseUpdated(let p):
            state.breathPhase = p
        case .thermalWarning(let level):
            state.thermalState = level
            autoScaler.handleThermalChange(level)
        case .fpsDropped(let fps):
            autoScaler.handleFPSDrop(fps, state: &state)
        default:
            break
        }
    }

    // MARK: - Thermal Monitoring

    private func setupThermalMonitoring() {
        #if canImport(UIKit)
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                let level: EngineState.ThermalLevel
                switch ProcessInfo.processInfo.thermalState {
                case .nominal: level = .nominal
                case .fair: level = .fair
                case .serious: level = .serious
                case .critical: level = .critical
                @unknown default: level = .fair
                }
                self?.eventBus.send(.thermalWarning(level))
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Public API: Transport

    public func play() { eventBus.send(.play) }
    public func pause() { eventBus.send(.pause) }
    public func stopPlayback() { eventBus.send(.stop) }
    public func setBPM(_ bpm: Double) { eventBus.send(.bpmChanged(bpm.clamped(to: 20...300))) }

    // MARK: - Public API: Bio

    public func updateHeartRate(_ hr: Double) { eventBus.send(.heartRateUpdated(hr)) }
    public func updateCoherence(_ c: Float) { eventBus.send(.coherenceUpdated(c.clamped(to: 0...1))) }
    public func updateBreathPhase(_ p: Float) { eventBus.send(.breathPhaseUpdated(p)) }

    // MARK: - Public API: Subsystem Access

    /// Access a subsystem directly (type-safe). Returns nil if not activated.
    public func subsystem<T: EngineSubsystem>(_ id: SubsystemID, as type: T.Type) -> T? {
        return subsystems[id] as? T
    }

    /// Force-activate a subsystem regardless of mode
    public func activateSubsystem(_ id: SubsystemID) {
        ensureSubsystem(id)
        subsystems[id]?.activate()
        activeSubsystems.insert(id)
    }

    // MARK: - Public API: Performance

    public var performanceProfile: PerformanceAutoScaler.Profile {
        autoScaler.currentProfile
    }

    public var isMotionComfortActive: Bool {
        comfortSystem.isActive
    }
}

// MARK: - Subsystem Implementations (Thin wrappers around existing engines)

// Each subsystem is a lightweight adapter wrapping existing engine classes.
// This avoids rewriting 44K lines of engine code while providing a unified API.

final class AudioSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var audioEngine = AudioEngine()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        audioEngine.start()
    }

    func deactivate() {
        isActive = false
        audioEngine.stop()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        engine.state.audioLevel = audioEngine.currentLevel
    }
}

final class VideoSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var videoEngine = VideoProcessingEngine()

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class BioSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var healthKit = UnifiedHealthKitEngine()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        healthKit.startMonitoring()
    }

    func deactivate() {
        isActive = false
        healthKit.stopMonitoring()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        engine.state.heartRate = healthKit.heartRate
        engine.state.hrv = healthKit.hrv
        engine.state.coherence = Float(healthKit.coherence)
    }
}

final class VisualSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class SpatialSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var spatialEngine = SpatialAudioEngine()
    lazy var hrtf = HRTFProcessor()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        spatialEngine.start()
        hrtf.activate()
    }

    func deactivate() {
        isActive = false
        spatialEngine.stop()
        hrtf.deactivate()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        hrtf.updateListenerOrientation(deltaTime: deltaTime)
        // Map coherence to spatial width
        let width = engine.state.coherence
        spatialEngine.setReverbBlend(width)
    }
}

final class MIDISubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class MixingSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class RecordingSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class StreamingSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class LightingSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class HapticSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class CollaborationSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class HandTrackingSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class ComfortSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class OrchestralSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class CreativeSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class QuantumSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

final class WellnessSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?

    init(engine: EchoelEngine) { self.engine = engine }
    func activate() { isActive = true }
    func deactivate() { isActive = false }
    func update(deltaTime: TimeInterval) {}
}

// MARK: - Display Link Proxy

/// Cross-platform display link for the main update loop
final class DisplayLinkProxy {
    private var timer: Timer?
    private let callback: (TimeInterval) -> Void
    private var lastTimestamp: TimeInterval = 0

    init(callback: @escaping (TimeInterval) -> Void) {
        self.callback = callback
        let interval: TimeInterval = 1.0 / 60.0
        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = CACurrentMediaTime()
            let dt = self.lastTimestamp > 0 ? now - self.lastTimestamp : interval
            self.lastTimestamp = now
            self.callback(dt)
        }
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Performance Auto-Scaler

public final class PerformanceAutoScaler {

    public enum Profile: String, CaseIterable {
        case maxPerformance = "Max (120 FPS)"
        case balanced = "Balanced (60 FPS)"
        case batterySaver = "Battery Saver (30 FPS)"
        case eco = "Eco (30 FPS)"
        case thermal = "Thermal Throttle"

        var targetFPS: Double {
            switch self {
            case .maxPerformance: return 120
            case .balanced: return 60
            case .batterySaver, .eco: return 30
            case .thermal: return 30
            }
        }

        var particleLimit: Int {
            switch self {
            case .maxPerformance: return 8192
            case .balanced: return 4096
            case .batterySaver: return 2048
            case .eco: return 1024
            case .thermal: return 512
            }
        }

        var shaderQuality: Float {
            switch self {
            case .maxPerformance: return 1.0
            case .balanced: return 0.8
            case .batterySaver: return 0.5
            case .eco: return 0.3
            case .thermal: return 0.2
            }
        }

        var audioBufferSize: Int {
            switch self {
            case .maxPerformance: return 128
            case .balanced: return 256
            case .batterySaver: return 512
            case .eco: return 1024
            case .thermal: return 1024
            }
        }
    }

    private(set) var currentProfile: Profile = .balanced
    private var fpsHistory: [Double] = []
    private let fpsHistorySize = 30

    func adjustForMode(_ mode: EngineMode, state: EngineState) {
        switch mode {
        case .meditation, .research:
            currentProfile = .batterySaver
        case .live, .dj:
            currentProfile = .maxPerformance
        default:
            currentProfile = .balanced
        }
    }

    func update(state: inout EngineState, deltaTime: TimeInterval) {
        guard deltaTime > 0 else { return }
        let currentFPS = 1.0 / deltaTime
        fpsHistory.append(currentFPS)
        if fpsHistory.count > fpsHistorySize { fpsHistory.removeFirst() }

        let avgFPS = fpsHistory.reduce(0, +) / Double(fpsHistory.count)
        state.fps = avgFPS

        // Auto-downgrade if FPS drops below 90% of target
        let threshold = currentProfile.targetFPS * 0.9
        if avgFPS < threshold && currentProfile != .thermal {
            downgrade()
        }
    }

    func handleThermalChange(_ level: EngineState.ThermalLevel) {
        switch level {
        case .serious, .critical:
            currentProfile = .thermal
        case .fair:
            if currentProfile == .thermal { currentProfile = .batterySaver }
        case .nominal:
            if currentProfile == .thermal { currentProfile = .balanced }
        }
    }

    func handleFPSDrop(_ fps: Double, state: inout EngineState) {
        if fps < 20 { currentProfile = .eco }
    }

    private func downgrade() {
        switch currentProfile {
        case .maxPerformance: currentProfile = .balanced
        case .balanced: currentProfile = .batterySaver
        case .batterySaver: currentProfile = .eco
        default: break
        }
    }
}

// MARK: - Motion Comfort System

/// Prevents motion sickness in immersive/VR modes
public final class MotionComfortSystem {

    public struct Settings {
        /// Maximum rotation speed (degrees/second) before comfort vignette kicks in
        public var maxRotationSpeed: Double = 90
        /// Vignette intensity (0 = off, 1 = max tunnel vision)
        public var vignetteIntensity: Float = 0
        /// Whether to use fixed reference frame (horizon lock)
        public var horizonLock: Bool = false
        /// Reduce peripheral motion (comfort mode)
        public var reducePeripheralMotion: Bool = false
        /// Teleport-style movement instead of smooth locomotion
        public var snapTurning: Bool = false
        /// Snap turn angle in degrees
        public var snapAngle: Double = 30
        /// Whether rest frame overlay is shown
        public var showRestFrame: Bool = false
    }

    @Published public var settings = Settings()
    public private(set) var isActive: Bool = false
    private var currentVignetteTarget: Float = 0
    private var rotationHistory: [Double] = []

    func adjustForMode(_ mode: EngineMode) {
        switch mode {
        case .immersive:
            isActive = true
            settings.reducePeripheralMotion = true
            settings.showRestFrame = true
        case .meditation:
            isActive = true
            settings.reducePeripheralMotion = true
            settings.horizonLock = true
        default:
            isActive = false
            settings.vignetteIntensity = 0
        }
    }

    func update(state: EngineState) {
        guard isActive else { return }

        #if canImport(UIKit)
        // Respect system accessibility setting
        if UIAccessibility.isReduceMotionEnabled {
            settings.reducePeripheralMotion = true
            settings.snapTurning = true
        }
        #endif

        // Smooth vignette transition
        let delta = currentVignetteTarget - settings.vignetteIntensity
        settings.vignetteIntensity += delta * 0.1
    }

    /// Call when rotation speed is detected (from head tracking)
    public func reportRotationSpeed(_ degreesPerSecond: Double) {
        rotationHistory.append(degreesPerSecond)
        if rotationHistory.count > 10 { rotationHistory.removeFirst() }

        let avgSpeed = rotationHistory.reduce(0, +) / Double(rotationHistory.count)
        if avgSpeed > settings.maxRotationSpeed {
            currentVignetteTarget = Float(min(1.0, avgSpeed / (settings.maxRotationSpeed * 2.0)))
        } else {
            currentVignetteTarget = 0
        }
    }
}

// MARK: - Clamping Utility

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
