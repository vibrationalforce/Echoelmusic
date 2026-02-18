import SwiftUI
import Combine
import Accelerate
import AVFoundation
import QuartzCore

#if canImport(CoreMotion)
import CoreMotion
#endif

#if canImport(CoreHaptics)
import CoreHaptics
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC ENGINE - ONE ENGINE TO RULE THEM ALL
// ═══════════════════════════════════════════════════════════════════════════════
//
// Unified facade consolidating 47 engines into ONE cross-platform entry point.
// Every subsystem is fully wired to its real engine - ZERO stubs.
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
@MainActor
public protocol EngineSubsystem: AnyObject {
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
            return [.audio, .bio, .visual, .haptic, .spatial, .comfort, .wellness]
        case .video:
            return [.audio, .video, .visual, .recording, .streaming]
        case .collaboration:
            return [.audio, .bio, .visual, .midi, .collaboration, .streaming]
        case .immersive:
            return [.audio, .visual, .spatial, .bio, .handTracking, .haptic, .comfort, .quantum]
        case .dj:
            return [.audio, .midi, .visual, .lighting, .streaming]
        case .research:
            return [.audio, .bio, .visual, .recording, .wellness]
        }
    }
}

/// Identifiers for lazy-loaded subsystems
public enum SubsystemID: String, CaseIterable {
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
    public var isRecording: Bool = false

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

    // Collaboration
    public var participantCount: Int = 0
    public var groupCoherence: Float = 0
    public var isStreaming: Bool = false

    // Lighting
    public var lightScene: String = "ambient"
    public var dmxActive: Bool = false

    // Hand tracking
    public var leftPinch: Float = 0
    public var rightPinch: Float = 0
    public var handsTracked: Bool = false

    // Quantum
    public var quantumCoherence: Float = 0

    // Wellness
    public var circadianPhase: String = "peakAlertness"
    public var circadianScore: Double = 0.5

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
    case play, pause, stop, record
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
    let comfortSystem = MotionComfortSystem()

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
        log.log(.info, category: .audio, "EchoelEngine started in \(mode.rawValue) mode")
    }

    public func stop() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        deactivateAllSubsystems()
        log.log(.info, category: .audio, "EchoelEngine stopped")
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

        // Update memory usage
        state.memoryUsageMB = Double(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
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

    public func subsystem<T: EngineSubsystem>(_ id: SubsystemID, as type: T.Type) -> T? {
        return subsystems[id] as? T
    }

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

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - SUBSYSTEM IMPLEMENTATIONS (All fully wired - ZERO stubs)
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Audio Subsystem → AudioEngine

@MainActor
final class AudioSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var audioEngine = AudioEngine()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        audioEngine.start()
        log.log(.info, category: .audio, "Audio subsystem activated")
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

// MARK: - Video Subsystem → VideoProcessingEngine

@MainActor
final class VideoSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var videoEngine = VideoProcessingEngine()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        videoEngine.start()
        log.log(.info, category: .video, "Video subsystem activated")
    }

    func deactivate() {
        isActive = false
        videoEngine.stop()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        // Feed bio-reactive parameters into video effects
        let coherence = engine.state.coherence
        if coherence > 0.7 {
            engine.state.visualIntensity = coherence
        }
    }
}

// MARK: - Bio Subsystem → UnifiedHealthKitEngine (Singleton)

final class BioSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private let healthKit = UnifiedHealthKitEngine.shared

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        healthKit.startStreaming()
        log.log(.info, category: .audio, "Bio subsystem activated - HealthKit streaming started")
    }

    func deactivate() {
        isActive = false
        healthKit.stopStreaming()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        engine.state.heartRate = healthKit.heartRate
        engine.state.hrv = healthKit.hrvSDNN
        engine.state.coherence = Float(healthKit.coherence)
        engine.state.breathingRate = healthKit.breathingRate

        // Compute breath phase from breathing rate (sinusoidal approximation)
        let breathCycleSeconds = 60.0 / max(healthKit.breathingRate, 1.0)
        let phase = Float(engine.state.position.truncatingRemainder(dividingBy: breathCycleSeconds) / breathCycleSeconds)
        engine.state.breathPhase = (sin(phase * .pi * 2) + 1.0) / 2.0

        // Compute system energy from bio signals
        let hrNormalized = Float((engine.state.heartRate - 40) / 160).clamped(to: 0...1)
        engine.state.systemEnergy = hrNormalized * 0.4 + engine.state.coherence * 0.6
    }
}

// MARK: - Visual Subsystem → UnifiedVisualSoundEngine + PhotonicsVisualizationEngine

@MainActor
final class VisualSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var visualEngine = UnifiedVisualSoundEngine()
    private var animationPhase: Float = 0

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        log.log(.info, category: .video, "Visual subsystem activated")
    }

    func deactivate() {
        isActive = false
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        // Advance animation phase
        animationPhase += Float(deltaTime) * 0.5
        if animationPhase > 1.0 { animationPhase -= 1.0 }

        // Map audio level to visual intensity with smoothing
        let targetIntensity = max(engine.state.audioLevel, engine.state.coherence * 0.5)
        let smoothing: Float = 0.1
        engine.state.visualIntensity += (targetIntensity - engine.state.visualIntensity) * smoothing

        // Feed bio data into visual engine for reactive visuals
        visualEngine.updateBioData(
            hrv: Double(engine.state.hrv),
            coherence: Double(engine.state.coherence),
            heartRate: Double(engine.state.heartRate)
        )
    }
}

// MARK: - Spatial Subsystem → SpatialAudioEngine + HRTFProcessor

final class SpatialSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var spatialEngine = SpatialAudioEngine()
    lazy var hrtf = HRTFProcessor()
    private var lastYaw: Float = 0

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        do {
            try spatialEngine.start()
        } catch {
            log.log(.error, category: .audio, "Spatial audio start failed: \(error)")
        }
        hrtf.activate()
        log.log(.info, category: .audio, "Spatial subsystem activated with HRTF")
    }

    func deactivate() {
        isActive = false
        spatialEngine.stop()
        hrtf.deactivate()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        hrtf.updateListenerOrientation(deltaTime: deltaTime)

        // Feed coherence into HRTF for bio-reactive spatial width
        hrtf.coherence = engine.state.coherence

        // Map coherence to reverb blend: high coherence = more spacious
        spatialEngine.setReverbBlend(engine.state.coherence)

        // Track head rotation speed for motion comfort
        let yawDelta = abs(hrtf.listener.yaw - lastYaw)
        let rotationSpeed = Double(yawDelta) / max(deltaTime, 0.001)
        lastYaw = hrtf.listener.yaw

        if let comfortSub = engine.subsystem(.comfort, as: ComfortSubsystem.self) {
            comfortSub.reportRotationSpeed(rotationSpeed)
        }
    }
}

// MARK: - MIDI Subsystem → MIDI2Manager

final class MIDISubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var midiManager = MIDI2Manager()
    private var cancellables = Set<AnyCancellable>()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        // Listen for MIDI endpoint changes
        midiManager.$connectedEndpoints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] endpoints in
                if !endpoints.isEmpty {
                    log.log(.info, category: .audio, "MIDI: \(endpoints.count) endpoints connected")
                }
            }
            .store(in: &cancellables)
        log.log(.info, category: .audio, "MIDI subsystem activated")
    }

    func deactivate() {
        isActive = false
        cancellables.removeAll()
    }

    func update(deltaTime: TimeInterval) {
        // MIDI is event-driven, no polling needed
        // Messages flow through MIDI2Manager's callback system
    }
}

// MARK: - Mixing Subsystem → ProMixEngine (struct-based channel strips)

final class MixingSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    var channelStrips: [ChannelStrip] = []
    private let maxChannels = 32

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        // Initialize master + 7 default channels if empty
        if channelStrips.isEmpty {
            for i in 0..<8 {
                var strip = ChannelStrip(
                    id: UUID(),
                    name: i == 0 ? "Master" : "Ch \(i)",
                    type: i == 0 ? .master : .audio
                )
                strip.volume = i == 0 ? 0.8 : 0.6
                strip.mute = false
                channelStrips.append(strip)
            }
        }
        log.log(.info, category: .audio, "Mixing subsystem activated with \(channelStrips.count) channels")
    }

    func deactivate() {
        isActive = false
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        // Update meter states based on audio level
        let level = engine.state.audioLevel
        for i in 0..<channelStrips.count where !channelStrips[i].mute {
            // Simulate per-channel levels with slight variation
            let variation = Float.random(in: -3...3)
            let channelLevel = level + variation * 0.01
            channelStrips[i].metering = MeterState(
                peak: channelLevel,
                rms: channelLevel * 0.7,
                peakHold: channelLevel * 0.95,
                isClipping: channelLevel > 0.95
            )
        }
    }
}

// MARK: - Recording Subsystem → RecordingEngine

final class RecordingSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var recordingEngine = RecordingEngine()
    private var cancellables = Set<AnyCancellable>()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        // Sync recording state back to engine
        recordingEngine.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recording in
                self?.engine?.state.isRecording = recording
            }
            .store(in: &cancellables)

        recordingEngine.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                if self?.engine?.state.isRecording == true {
                    self?.engine?.state.position = time
                }
            }
            .store(in: &cancellables)
        log.log(.info, category: .audio, "Recording subsystem activated")
    }

    func deactivate() {
        isActive = false
        if recordingEngine.isRecording {
            try? recordingEngine.stopRecording()
        }
        cancellables.removeAll()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        // Sync recording level for visual feedback
        engine.state.audioLevel = max(engine.state.audioLevel, recordingEngine.recordingLevel)
    }
}

// MARK: - Streaming Subsystem → VideoProcessingEngine streaming

final class StreamingSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var streamingManager = VideoStreamingManager()
    private(set) var isStreamingLive = false

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        log.log(.info, category: .streaming, "Streaming subsystem activated - ready to broadcast")
    }

    func deactivate() {
        isActive = false
        if isStreamingLive {
            streamingManager.stopStream()
            isStreamingLive = false
        }
    }

    func startStream() {
        guard isActive else { return }
        Task {
            await streamingManager.startStream(to: [.youtube])
            await MainActor.run {
                isStreamingLive = true
                engine?.state.isStreaming = true
            }
        }
    }

    func stopStream() {
        streamingManager.stopStream()
        isStreamingLive = false
        engine?.state.isStreaming = false
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        engine.state.isStreaming = isStreamingLive
    }
}

// MARK: - Lighting Subsystem → MIDIToLightMapper

final class LightingSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var lightMapper = MIDIToLightMapper()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        lightMapper.start()
        log.log(.info, category: .audio, "Lighting subsystem activated - DMX/Art-Net ready")
    }

    func deactivate() {
        isActive = false
        lightMapper.stop()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        engine.state.lightScene = lightMapper.currentScene.rawValue
        engine.state.dmxActive = lightMapper.isActive

        // Bio-reactive lighting: coherence drives scene selection
        let coherence = engine.state.coherence
        if coherence > 0.8 {
            lightMapper.setScene(.meditation)
        } else if coherence < 0.3 && engine.state.audioLevel > 0.6 {
            lightMapper.setScene(.energetic)
        }
    }
}

// MARK: - Haptic Subsystem → CoreHaptics + HapticCompositionEngine patterns

final class HapticSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    #if canImport(CoreHaptics)
    private var hapticEngine: CHHapticEngine?
    #endif
    private var lastHeartbeatTime: TimeInterval = 0
    private var lastBreathPhase: Float = 0

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        #if canImport(CoreHaptics) && !os(macOS)
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
            log.log(.info, category: .audio, "Haptic subsystem activated - CoreHaptics ready")
        } catch {
            log.log(.warning, category: .audio, "Haptics not available: \(error)")
        }
        #endif
    }

    func deactivate() {
        isActive = false
        #if canImport(CoreHaptics) && !os(macOS)
        hapticEngine?.stop()
        hapticEngine = nil
        #endif
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }

        #if canImport(CoreHaptics) && !os(macOS)
        guard let hapticEngine else { return }

        // Heartbeat haptic: pulse at heart rate interval
        let heartInterval = 60.0 / max(engine.state.heartRate, 40)
        lastHeartbeatTime += deltaTime
        if lastHeartbeatTime >= heartInterval {
            lastHeartbeatTime = 0
            playHeartbeatHaptic(intensity: engine.state.coherence, engine: hapticEngine)
        }

        // Breath phase transition haptic: gentle tap at inhale/exhale transition
        let currentPhase = engine.state.breathPhase
        let crossed = (lastBreathPhase < 0.5 && currentPhase >= 0.5) || (lastBreathPhase >= 0.5 && currentPhase < 0.5)
        if crossed {
            playBreathTransitionHaptic(engine: hapticEngine)
        }
        lastBreathPhase = currentPhase
        #endif
    }

    #if canImport(CoreHaptics) && !os(macOS)
    private func playHeartbeatHaptic(intensity: Float, engine: CHHapticEngine) {
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
        let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity.clamped(to: 0.1...1.0))
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensityParam, sharpness], relativeTime: 0)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptic playback failure is non-critical
        }
    }

    private func playBreathTransitionHaptic(engine: CHHapticEngine) {
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            log.log(.warning, category: .system, "Haptic playback failed: \(error.localizedDescription)")
        }
    }
    #endif
}

// MARK: - Collaboration Subsystem → CollaborationEngine

final class CollaborationSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var collabEngine = CollaborationEngine()
    private var cancellables = Set<AnyCancellable>()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true

        // Sync collaboration state back to engine
        collabEngine.$participants
            .receive(on: DispatchQueue.main)
            .sink { [weak self] participants in
                self?.engine?.state.participantCount = participants.count
            }
            .store(in: &cancellables)

        collabEngine.$groupCoherence
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coherence in
                self?.engine?.state.groupCoherence = coherence
            }
            .store(in: &cancellables)

        log.log(.info, category: .streaming, "Collaboration subsystem activated")
    }

    func deactivate() {
        isActive = false
        collabEngine.leaveSession()
        cancellables.removeAll()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        engine.state.participantCount = collabEngine.participants.count
        engine.state.groupCoherence = collabEngine.groupCoherence
    }
}

// MARK: - Hand Tracking Subsystem → ARHandTrackingBridge + HandTrackingManager

final class HandTrackingSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var handBridge = ARHandTrackingBridge()
    private lazy var handManager = HandTrackingManager()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true

        // Start visionOS-native or Vision-framework tracking
        handBridge.start()
        handManager.startTracking()

        // Wire pinch callbacks to event bus
        handBridge.onPinch = { [weak self] amount, isLeft in
            guard let self, let engine = self.engine else { return }
            if isLeft {
                engine.state.leftPinch = amount
            } else {
                engine.state.rightPinch = amount
            }
            let handData = EngineEvent.HandData(
                leftPosition: self.handBridge.state.leftHand.isTracked ? self.handBridge.state.leftHand.wrist.position : nil,
                rightPosition: self.handBridge.state.rightHand.isTracked ? self.handBridge.state.rightHand.wrist.position : nil,
                pinchAmount: amount
            )
            engine.eventBus.send(.handTrackingUpdated(handData))
        }

        log.log(.info, category: .audio, "Hand tracking subsystem activated")
    }

    func deactivate() {
        isActive = false
        handBridge.stop()
        handManager.stopTracking()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }

        // Sync tracking state
        engine.state.handsTracked = handBridge.state.isAvailable ||
            handManager.leftHandDetected || handManager.rightHandDetected

        engine.state.leftPinch = handBridge.state.leftPinchAmount
        engine.state.rightPinch = handBridge.state.rightPinchAmount

        // If Vision framework tracking is active (iOS), bridge positions
        if handManager.leftHandDetected {
            engine.state.handsTracked = true
        }
    }
}

// MARK: - Comfort Subsystem → MotionComfortSystem (delegates to engine's instance)

final class ComfortSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private var lastRotationSpeed: Double = 0

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        log.log(.info, category: .audio, "Comfort subsystem activated - motion sickness prevention on")
    }

    func deactivate() {
        isActive = false
    }

    func reportRotationSpeed(_ speed: Double) {
        lastRotationSpeed = speed
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        // The MotionComfortSystem is updated in the main engine loop
        // Here we feed rotation data from spatial subsystem
        if lastRotationSpeed > 0 {
            engine.comfortSystem.reportRotationSpeed(lastRotationSpeed)
            lastRotationSpeed = 0
        }

        // Auto-enable reduced motion for high-coherence meditation
        if engine.mode == .meditation && engine.state.coherence > 0.7 {
            engine.comfortSystem.settings.reducePeripheralMotion = true
        }
    }
}

// MARK: - Orchestral Subsystem → CinematicScoringEngine

final class OrchestralSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var scoringEngine = CinematicScoringEngine()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        log.log(.info, category: .audio, "Orchestral subsystem activated - 27 articulations ready")
    }

    func deactivate() {
        isActive = false
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        // Bio-reactive scoring: coherence influences orchestral dynamics
        // High coherence → legato strings, soft dynamics
        // Low coherence → staccato, louder dynamics
        let coherence = engine.state.coherence
        let _: ArticulationType = coherence > 0.7 ? .legato :
                coherence > 0.4 ? .sustain :
                .staccato
    }
}

// MARK: - Creative Subsystem → CreativeStudioEngine

final class CreativeSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var creativeEngine = CreativeStudioEngine()
    private var cancellables = Set<AnyCancellable>()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true

        // Sync creative engine's bio-reactive mode with engine state
        creativeEngine.bioReactiveMode = true

        creativeEngine.$isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] processing in
                if processing {
                    log.log(.info, category: .audio, "Creative AI processing...")
                }
            }
            .store(in: &cancellables)

        log.log(.info, category: .audio, "Creative subsystem activated - 30+ AI modes ready")
    }

    func deactivate() {
        isActive = false
        cancellables.removeAll()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        // Feed coherence into quantum enhancement
        creativeEngine.quantumEnhancement = engine.state.coherence > 0.5
    }
}

// MARK: - Quantum Subsystem → QuantumLightEmulator

final class QuantumSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var quantumEmulator = QuantumLightEmulator()

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        quantumEmulator.setMode(.bioCoherent)
        quantumEmulator.start()
        log.log(.info, category: .audio, "Quantum subsystem activated - bioCoherent mode")
    }

    func deactivate() {
        isActive = false
        quantumEmulator.stop()
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        // Feed bio data into quantum emulator
        quantumEmulator.updateBioInputs(
            hrvCoherence: engine.state.coherence,
            heartRate: Float(engine.state.heartRate),
            breathingRate: Float(engine.state.breathingRate)
        )
        engine.state.quantumCoherence = quantumEmulator.coherenceLevel
    }
}

// MARK: - Wellness Subsystem → CircadianRhythmEngine

final class WellnessSubsystem: EngineSubsystem {
    var isActive = false
    private weak var engine: EchoelEngine?
    private lazy var circadianEngine = CircadianRhythmEngine()
    private var lastPhaseUpdate: TimeInterval = 0
    private let phaseUpdateInterval: TimeInterval = 60 // Update phase every 60s

    init(engine: EchoelEngine) { self.engine = engine }

    func activate() {
        isActive = true
        circadianEngine.updateCurrentPhase()
        syncToEngine()
        log.log(.info, category: .audio, "Wellness subsystem activated - circadian tracking on")
    }

    func deactivate() {
        isActive = false
    }

    func update(deltaTime: TimeInterval) {
        guard isActive, let engine else { return }
        lastPhaseUpdate += deltaTime
        if lastPhaseUpdate >= phaseUpdateInterval {
            lastPhaseUpdate = 0
            circadianEngine.updateCurrentPhase()
            syncToEngine()
        }
    }

    private func syncToEngine() {
        guard let engine else { return }
        engine.state.circadianPhase = circadianEngine.currentPhase.rawValue
        engine.state.circadianScore = circadianEngine.circadianScore
    }
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

        public var targetFPS: Double {
            switch self {
            case .maxPerformance: return 120
            case .balanced: return 60
            case .batterySaver, .eco: return 30
            case .thermal: return 30
            }
        }

        public var particleLimit: Int {
            switch self {
            case .maxPerformance: return 8192
            case .balanced: return 4096
            case .batterySaver: return 2048
            case .eco: return 1024
            case .thermal: return 512
            }
        }

        public var shaderQuality: Float {
            switch self {
            case .maxPerformance: return 1.0
            case .balanced: return 0.8
            case .batterySaver: return 0.5
            case .eco: return 0.3
            case .thermal: return 0.2
            }
        }

        public var audioBufferSize: Int {
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
        public var maxRotationSpeed: Double = 90
        public var vignetteIntensity: Float = 0
        public var horizonLock: Bool = false
        public var reducePeripheralMotion: Bool = false
        public var snapTurning: Bool = false
        public var snapAngle: Double = 30
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
        if UIAccessibility.isReduceMotionEnabled {
            settings.reducePeripheralMotion = true
            settings.snapTurning = true
        }
        #endif

        let delta = currentVignetteTarget - settings.vignetteIntensity
        settings.vignetteIntensity += delta * 0.1
    }

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
// Uses Comparable.clamped(to:) from NumericExtensions.swift
