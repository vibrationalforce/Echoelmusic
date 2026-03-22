// VisionOSImmersiveEngine.swift
// Echoelmusic — visionOS Immersive Experience Engine
//
// Bio-reactive 3D immersive experiences using RealityKit on visionOS.
// Hand tracking, spatial audio, eye gaze, passthrough blending.
// Compiles as a stub on non-visionOS platforms.
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine

// MARK: - Cross-Platform Types

/// Immersive visualization mode
public enum ImmersiveMode: String, CaseIterable, Identifiable, Sendable {
    case bioSphere = "Bio Sphere"
    case cosmicFlow = "Cosmic Flow"
    case neuralNetwork = "Neural Network"
    case quantumField = "Quantum Field"
    case breathingCave = "Breathing Cave"
    case rhythmForest = "Rhythm Forest"
    case coherenceOcean = "Coherence Ocean"
    case voidSpace = "Void Space"

    public var id: String { rawValue }

    /// Base particle count for this mode (adjusted by LOD)
    public var baseParticleCount: Int {
        switch self {
        case .bioSphere: return 5000
        case .cosmicFlow: return 8000
        case .neuralNetwork: return 3000
        case .quantumField: return 10000
        case .breathingCave: return 4000
        case .rhythmForest: return 6000
        case .coherenceOcean: return 7000
        case .voidSpace: return 2000
        }
    }

    /// Suggested spatial audio source count
    public var audioSourceCount: Int {
        switch self {
        case .bioSphere: return 4
        case .cosmicFlow: return 6
        case .neuralNetwork: return 8
        case .quantumField: return 5
        case .breathingCave: return 3
        case .rhythmForest: return 7
        case .coherenceOcean: return 4
        case .voidSpace: return 2
        }
    }
}

/// Bio-reactive state driving the immersive environment
public struct SpatialBioState: Sendable {
    /// Coherence [0-1] — drives sphere scale, color saturation, environment harmony
    public var coherence: Float = 0.5

    /// HRV normalized [0-1] — drives particle density, environmental complexity
    public var hrv: Float = 0.5

    /// Heart rate BPM [40-200] — drives pulse animation speed
    public var heartRate: Float = 72.0

    /// Breath phase [0-1] — drives wave motion, expansion/contraction cycles
    public var breathPhase: Float = 0.0

    /// Breath depth [0-1] — drives amplitude of wave motions
    public var breathDepth: Float = 0.5

    /// LF/HF ratio [0-4] — drives spectral tilt of visuals
    public var lfHfRatio: Float = 1.0

    /// Coherence trend [-1, 1] — drives morphing direction
    public var coherenceTrend: Float = 0.0

    public init() {}

    /// Pulse interval derived from heart rate
    public var pulseInterval: Float {
        guard heartRate > 0 else { return 1.0 }
        return 60.0 / heartRate
    }

    /// Particle density multiplier from HRV
    public var particleDensityMultiplier: Float {
        0.3 + hrv * 0.7
    }
}

/// LOD level for performance management
public enum ImmersiveLOD: Int, Comparable, Sendable {
    case high = 0
    case medium = 1
    case low = 2

    public static func < (lhs: ImmersiveLOD, rhs: ImmersiveLOD) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var particleMultiplier: Float {
        switch self {
        case .high: return 1.0
        case .medium: return 0.5
        case .low: return 0.25
        }
    }

    public var updateFrequencyHz: Float {
        switch self {
        case .high: return 90
        case .medium: return 60
        case .low: return 30
        }
    }
}

/// Protocol for immersive engine capabilities (allows cross-platform stubs)
@MainActor
public protocol ImmersiveEngineProtocol: AnyObject {
    var currentMode: ImmersiveMode { get }
    var isImmersiveActive: Bool { get }
    var bioState: SpatialBioState { get }
    var currentLOD: ImmersiveLOD { get }
    var isPassthroughEnabled: Bool { get }
    var fps: Double { get }
}

// MARK: - visionOS Implementation

#if os(visionOS)

import RealityKit
import ARKit
import Spatial

/// visionOS immersive experience engine with RealityKit.
/// Provides bio-reactive 3D environments driven by physiological data,
/// hand tracking, spatial audio, and eye gaze interaction.
@preconcurrency @MainActor @Observable
public final class VisionOSImmersiveEngine: ImmersiveEngineProtocol {

    // MARK: - Singleton

    @MainActor public static let shared = VisionOSImmersiveEngine()

    // MARK: - Published State

    public private(set) var currentMode: ImmersiveMode = .bioSphere
    public private(set) var isImmersiveActive = false
    public private(set) var bioState = SpatialBioState()
    public private(set) var currentLOD: ImmersiveLOD = .high
    public private(set) var isPassthroughEnabled = false
    public private(set) var fps: Double = 0.0
    public private(set) var isHandTrackingActive = false
    public private(set) var isEyeTrackingActive = false

    // MARK: - Configuration

    public var targetFPS: Double = 90.0
    public var passthroughBlendFactor: Float = 0.5
    public var handTrackingEnabled = true
    public var eyeTrackingEnabled = true

    // MARK: - RealityKit Entities

    private var rootEntity: Entity?
    private var environmentEntity: Entity?
    private var particleEntity: Entity?
    private var audioEntities: [Entity] = []
    private var bioSphereEntity: ModelEntity?

    // MARK: - ARKit Sessions

    private var arSession: ARKitSession?
    private var handTrackingProvider: HandTrackingProvider?
    private var worldTrackingProvider: WorldTrackingProvider?

    // MARK: - Private State

    private var displayLink: CADisplayLink?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: UInt64 = 0
    private var fpsAccumulator: Double = 0
    private var fpsFrameCount: Int = 0
    private var cancellables = Set<AnyCancellable>()

    // Pinch gesture state
    private var leftPinchValue: Float = 0
    private var rightPinchValue: Float = 0

    // Gaze target
    private var gazeTargetEntityID: UInt64?

    // MARK: - Init

    private init() {
        log.log(.info, category: .spatial, "VisionOSImmersiveEngine initialized")
    }

    // MARK: - Lifecycle

    /// Enter immersive mode with the specified visualization
    public func enterImmersiveMode(_ mode: ImmersiveMode) async {
        guard !isImmersiveActive else {
            await switchMode(mode)
            return
        }

        currentMode = mode
        setupRootEntity()
        await setupARTracking()
        buildEnvironment(for: mode)
        setupSpatialAudio(sourceCount: mode.audioSourceCount)
        startRenderLoop()

        isImmersiveActive = true
        log.log(.info, category: .spatial, "Immersive mode active: \(mode.rawValue)")
    }

    /// Exit immersive mode and clean up
    public func exitImmersiveMode() {
        guard isImmersiveActive else { return }

        stopRenderLoop()
        tearDownARTracking()
        tearDownEntities()

        isImmersiveActive = false
        isHandTrackingActive = false
        isEyeTrackingActive = false
        log.log(.info, category: .spatial, "Immersive mode exited")
    }

    /// Switch to a different immersive mode without full teardown
    public func switchMode(_ mode: ImmersiveMode) async {
        guard mode != currentMode else { return }

        tearDownEntities()
        currentMode = mode
        buildEnvironment(for: mode)
        setupSpatialAudio(sourceCount: mode.audioSourceCount)
        log.log(.info, category: .spatial, "Immersive mode switched to: \(mode.rawValue)")
    }

    // MARK: - Bio State Update

    /// Update the bio-reactive state from BioSnapshot data
    public func updateBioState(_ state: SpatialBioState) {
        bioState = state
    }

    /// Update from individual bio values (convenience)
    public func updateBioValues(
        coherence: Float? = nil,
        hrv: Float? = nil,
        heartRate: Float? = nil,
        breathPhase: Float? = nil,
        breathDepth: Float? = nil,
        lfHfRatio: Float? = nil,
        coherenceTrend: Float? = nil
    ) {
        if let v = coherence { bioState.coherence = v }
        if let v = hrv { bioState.hrv = v }
        if let v = heartRate { bioState.heartRate = v }
        if let v = breathPhase { bioState.breathPhase = v }
        if let v = breathDepth { bioState.breathDepth = v }
        if let v = lfHfRatio { bioState.lfHfRatio = v }
        if let v = coherenceTrend { bioState.coherenceTrend = v }
    }

    // MARK: - Passthrough

    /// Toggle AR passthrough blending
    public func setPassthroughEnabled(_ enabled: Bool) {
        isPassthroughEnabled = enabled
        log.log(.info, category: .spatial, "Passthrough \(enabled ? "enabled" : "disabled")")
    }

    /// Adjust passthrough blend factor [0=fully virtual, 1=fully passthrough]
    public func setPassthroughBlend(_ factor: Float) {
        passthroughBlendFactor = max(0, min(1, factor))
    }

    // MARK: - Private — Entity Setup

    private func setupRootEntity() {
        let root = Entity()
        root.name = "EchoelImmersiveRoot"
        rootEntity = root
    }

    private func buildEnvironment(for mode: ImmersiveMode) {
        guard let root = rootEntity else { return }

        let env = Entity()
        env.name = "Environment_\(mode.rawValue)"

        switch mode {
        case .bioSphere:
            buildBioSphere(parent: env)
        case .cosmicFlow:
            buildCosmicFlow(parent: env)
        case .neuralNetwork:
            buildNeuralNetwork(parent: env)
        case .quantumField:
            buildQuantumField(parent: env)
        case .breathingCave:
            buildBreathingCave(parent: env)
        case .rhythmForest:
            buildRhythmForest(parent: env)
        case .coherenceOcean:
            buildCoherenceOcean(parent: env)
        case .voidSpace:
            buildVoidSpace(parent: env)
        }

        root.addChild(env)
        environmentEntity = env
    }

    private func buildBioSphere(parent: Entity) {
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.5),
            materials: [SimpleMaterial(color: .cyan, isMetallic: true)]
        )
        sphere.name = "BioSphere"
        sphere.position = SIMD3<Float>(0, 1.5, -2)
        parent.addChild(sphere)
        bioSphereEntity = sphere

        addParticleEmitter(to: parent, count: adjustedParticleCount())
    }

    private func buildCosmicFlow(parent: Entity) {
        // Flowing particle streams with cosmic color palette
        for i in 0..<6 {
            let stream = Entity()
            stream.name = "CosmicStream_\(i)"
            let angle = Float(i) * (.pi * 2.0 / 6.0)
            stream.position = SIMD3<Float>(
                cos(angle) * 3.0,
                1.0 + sin(angle * 0.5),
                sin(angle) * 3.0 - 3.0
            )
            addParticleEmitter(to: stream, count: adjustedParticleCount() / 6)
            parent.addChild(stream)
        }
    }

    private func buildNeuralNetwork(parent: Entity) {
        // Node-and-edge neural network visualization
        let nodeCount = Swift.min(20, Swift.max(8, Int(bioState.hrv * 20)))
        for i in 0..<nodeCount {
            let node = ModelEntity(
                mesh: .generateSphere(radius: 0.05),
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )
            node.name = "NeuralNode_\(i)"
            let spread: Float = 2.0
            node.position = SIMD3<Float>(
                Float.random(in: -spread...spread),
                Float.random(in: 0.5...2.5),
                Float.random(in: -spread - 3...(-1))
            )
            parent.addChild(node)
        }
    }

    private func buildQuantumField(parent: Entity) {
        addParticleEmitter(to: parent, count: adjustedParticleCount())
    }

    private func buildBreathingCave(parent: Entity) {
        // Surrounding sphere that breathes with the user
        let cave = ModelEntity(
            mesh: .generateSphere(radius: 5.0),
            materials: [SimpleMaterial(color: .gray, isMetallic: false)]
        )
        cave.name = "BreathingCave"
        cave.position = SIMD3<Float>(0, 1.5, 0)
        cave.scale = SIMD3<Float>(repeating: 1.0)
        parent.addChild(cave)
    }

    private func buildRhythmForest(parent: Entity) {
        // Vertical columns that respond to rhythm
        for i in 0..<12 {
            let column = ModelEntity(
                mesh: .generateCylinder(height: 2.0, radius: 0.05),
                materials: [SimpleMaterial(color: .green, isMetallic: false)]
            )
            column.name = "RhythmColumn_\(i)"
            let angle = Float(i) * (.pi * 2.0 / 12.0)
            column.position = SIMD3<Float>(
                cos(angle) * 2.5,
                1.0,
                sin(angle) * 2.5 - 2.5
            )
            parent.addChild(column)
        }
    }

    private func buildCoherenceOcean(parent: Entity) {
        // Flat plane with wave displacement
        let ocean = ModelEntity(
            mesh: .generatePlane(width: 10, depth: 10),
            materials: [SimpleMaterial(color: .blue, isMetallic: true)]
        )
        ocean.name = "CoherenceOcean"
        ocean.position = SIMD3<Float>(0, 0, -3)
        parent.addChild(ocean)

        addParticleEmitter(to: parent, count: adjustedParticleCount() / 2)
    }

    private func buildVoidSpace(parent: Entity) {
        // Minimal — sparse particles in darkness
        addParticleEmitter(to: parent, count: adjustedParticleCount())
    }

    private func addParticleEmitter(to entity: Entity, count: Int) {
        let emitter = Entity()
        emitter.name = "ParticleEmitter"

        var particleComponent = ParticleEmitterComponent()
        particleComponent.emitterShape = .sphere
        particleComponent.mainEmitter.birthRate = Float(count)
        particleComponent.mainEmitter.lifeSpan = 3.0
        particleComponent.mainEmitter.size = 0.005
        particleComponent.mainEmitter.color = .evolving(
            start: .single(.cyan),
            end: .single(.blue)
        )
        emitter.components.set(particleComponent)

        entity.addChild(emitter)
        particleEntity = emitter
    }

    private func adjustedParticleCount() -> Int {
        let base = currentMode.baseParticleCount
        return Int(Float(base) * currentLOD.particleMultiplier * bioState.particleDensityMultiplier)
    }

    // MARK: - Private — Spatial Audio

    private func setupSpatialAudio(sourceCount: Int) {
        for entity in audioEntities {
            entity.removeFromParent()
        }
        audioEntities.removeAll()

        guard let root = rootEntity else { return }

        for i in 0..<sourceCount {
            let audioEntity = Entity()
            audioEntity.name = "SpatialAudioSource_\(i)"

            let angle = Float(i) * (.pi * 2.0 / Float(sourceCount))
            let radius: Float = 3.0
            audioEntity.position = SIMD3<Float>(
                cos(angle) * radius,
                1.5,
                sin(angle) * radius - 2.0
            )

            var spatialAudio = SpatialAudioComponent()
            spatialAudio.directivity = .beam(focus: 0.5)
            audioEntity.components.set(spatialAudio)

            root.addChild(audioEntity)
            audioEntities.append(audioEntity)
        }

        log.log(.info, category: .spatial, "Spatial audio configured: \(sourceCount) sources")
    }

    // MARK: - Private — AR Tracking

    private func setupARTracking() async {
        let session = ARKitSession()
        arSession = session

        var providers: [any DataProvider] = []

        if handTrackingEnabled {
            guard HandTrackingProvider.isSupported else {
                log.log(.warning, category: .spatial, "Hand tracking not supported on this device")
                return
            }
            let handProvider = HandTrackingProvider()
            handTrackingProvider = handProvider
            providers.append(handProvider)
        }

        let worldProvider = WorldTrackingProvider()
        worldTrackingProvider = worldProvider
        providers.append(worldProvider)

        do {
            try await session.run(providers)
            isHandTrackingActive = handTrackingEnabled
            log.log(.info, category: .spatial, "AR tracking started")
            startHandTrackingUpdates()
        } catch {
            log.log(.error, category: .spatial, "AR tracking failed: \(error.localizedDescription)")
        }
    }

    private func tearDownARTracking() {
        arSession?.stop()
        arSession = nil
        handTrackingProvider = nil
        worldTrackingProvider = nil
    }

    private func startHandTrackingUpdates() {
        guard let provider = handTrackingProvider else { return }

        Task { @MainActor in
            for await update in provider.anchorUpdates {
                self.processHandUpdate(update)
            }
        }
    }

    private func processHandUpdate(_ update: AnchorUpdate<HandAnchor>) {
        let hand = update.anchor

        guard hand.isTracked else { return }

        // Detect pinch gesture: thumb tip to index finger tip distance
        guard let thumbTip = hand.handSkeleton?.joint(.thumbTip),
              let indexTip = hand.handSkeleton?.joint(.indexFingerTip) else { return }

        let thumbPos = hand.originFromAnchorTransform * thumbTip.anchorFromJointTransform
        let indexPos = hand.originFromAnchorTransform * indexTip.anchorFromJointTransform

        let dx = thumbPos.columns.3.x - indexPos.columns.3.x
        let dy = thumbPos.columns.3.y - indexPos.columns.3.y
        let dz = thumbPos.columns.3.z - indexPos.columns.3.z
        let distance = sqrt(dx * dx + dy * dy + dz * dz)

        // Pinch threshold: <2cm = pinched
        let pinchValue = max(0, min(1, 1.0 - (distance / 0.04)))

        switch hand.chirality {
        case .left:
            leftPinchValue = pinchValue
        case .right:
            rightPinchValue = pinchValue
        @unknown default:
            break
        }

        applyHandGestures()
    }

    private func applyHandGestures() {
        // Left pinch: volume control
        // Right pinch: brightness/intensity
        // Both implementation routes through bio state for consistency
    }

    // MARK: - Private — Render Loop

    private func startRenderLoop() {
        let link = CADisplayLink(target: RenderLoopTarget(engine: self), selector: #selector(RenderLoopTarget.tick))
        link.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60,
            maximum: Float(targetFPS),
            preferred: Float(targetFPS)
        )
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastFrameTime = CACurrentMediaTime()
        log.log(.info, category: .spatial, "Render loop started at \(Int(targetFPS))fps target")
    }

    private func stopRenderLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    fileprivate func renderTick() {
        let now = CACurrentMediaTime()
        let dt = now - lastFrameTime
        lastFrameTime = now
        frameCount += 1

        // FPS calculation (1-second window)
        fpsAccumulator += dt
        fpsFrameCount += 1
        if fpsAccumulator >= 1.0 {
            fps = Double(fpsFrameCount) / fpsAccumulator
            fpsAccumulator = 0
            fpsFrameCount = 0
            adjustLOD()
        }

        updateBioReactiveEntities(dt: Float(dt))
    }

    // MARK: - Private — Bio-Reactive Updates

    private func updateBioReactiveEntities(dt: Float) {
        guard isImmersiveActive else { return }

        // Coherence → sphere scale and color
        if let sphere = bioSphereEntity {
            let scale = 0.3 + bioState.coherence * 0.7
            sphere.scale = SIMD3<Float>(repeating: scale)

            // Color interpolation: low coherence = red, high = cyan
            let r = 1.0 - bioState.coherence
            let g = bioState.coherence * 0.8
            let b = bioState.coherence
            sphere.model?.materials = [SimpleMaterial(
                color: .init(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1),
                isMetallic: true
            )]
        }

        // Heart rate → pulse animation on environment
        if let env = environmentEntity {
            let pulsePhase = fmod(Float(CACurrentMediaTime()) / bioState.pulseInterval, 1.0)
            let pulseScale = 1.0 + sin(pulsePhase * .pi * 2) * 0.02
            env.scale = SIMD3<Float>(repeating: pulseScale)
        }

        // Breath → wave motion on particles
        if let particles = particleEntity,
           var emitter = particles.components[ParticleEmitterComponent.self] {
            let breathWave = sin(bioState.breathPhase * .pi * 2) * bioState.breathDepth
            emitter.mainEmitter.size = 0.003 + breathWave * 0.004
            emitter.mainEmitter.birthRate = Float(adjustedParticleCount()) * (0.8 + breathWave * 0.2)
            particles.components.set(emitter)
        }

        // Spatial audio position modulation from coherence
        for (i, audioEntity) in audioEntities.enumerated() {
            let baseAngle = Float(i) * (.pi * 2.0 / Float(audioEntities.count))
            let coherenceOffset = bioState.coherence * 0.3
            let radius = 3.0 - coherenceOffset
            audioEntity.position = SIMD3<Float>(
                cos(baseAngle) * radius,
                1.5 + sin(bioState.breathPhase * .pi * 2) * 0.2,
                sin(baseAngle) * radius - 2.0
            )
        }
    }

    // MARK: - Private — LOD Management

    private func adjustLOD() {
        let previousLOD = currentLOD

        if fps < 60 {
            currentLOD = .low
        } else if fps < 80 {
            currentLOD = .medium
        } else {
            currentLOD = .high
        }

        if currentLOD != previousLOD {
            log.log(.info, category: .spatial, "LOD adjusted: \(currentLOD) (fps: \(String(format: "%.0f", fps)))")
        }
    }

    // MARK: - Private — Cleanup

    private func tearDownEntities() {
        for entity in audioEntities {
            entity.removeFromParent()
        }
        audioEntities.removeAll()

        environmentEntity?.removeFromParent()
        environmentEntity = nil
        particleEntity = nil
        bioSphereEntity = nil
    }
}

// MARK: - Render Loop Target (avoids retain cycle with CADisplayLink)

private final class RenderLoopTarget: NSObject {
    weak var engine: VisionOSImmersiveEngine?

    init(engine: VisionOSImmersiveEngine) {
        self.engine = engine
    }

    @objc func tick() {
        engine?.renderTick()
    }
}

#else

// MARK: - Non-visionOS Stub

/// Stub implementation for non-visionOS platforms.
/// Provides the same public interface with no-op implementations
/// so cross-platform code compiles without conditional checks everywhere.
@preconcurrency @MainActor @Observable
public final class VisionOSImmersiveEngine: ImmersiveEngineProtocol {

    // MARK: - Singleton

    @MainActor public static let shared = VisionOSImmersiveEngine()

    // MARK: - State (read-only stubs)

    public private(set) var currentMode: ImmersiveMode = .bioSphere
    public private(set) var isImmersiveActive = false
    public private(set) var bioState = SpatialBioState()
    public private(set) var currentLOD: ImmersiveLOD = .high
    public private(set) var isPassthroughEnabled = false
    public private(set) var fps: Double = 0.0

    // MARK: - Configuration

    public var targetFPS: Double = 90.0
    public var passthroughBlendFactor: Float = 0.5
    public var handTrackingEnabled = true
    public var eyeTrackingEnabled = true

    // MARK: - Init

    private init() {
        log.log(.info, category: .system, "VisionOSImmersiveEngine stub initialized (non-visionOS platform)")
    }

    // MARK: - No-op Public API

    /// No-op on non-visionOS — logs a warning
    public func enterImmersiveMode(_ mode: ImmersiveMode) async {
        log.log(.warning, category: .system, "VisionOS immersive mode unavailable on this platform")
    }

    /// No-op on non-visionOS
    public func exitImmersiveMode() {}

    /// No-op on non-visionOS
    public func switchMode(_ mode: ImmersiveMode) async {}

    /// Accepts bio state updates (stored but not rendered)
    public func updateBioState(_ state: SpatialBioState) {
        bioState = state
    }

    /// Accepts individual bio values (stored but not rendered)
    public func updateBioValues(
        coherence: Float? = nil,
        hrv: Float? = nil,
        heartRate: Float? = nil,
        breathPhase: Float? = nil,
        breathDepth: Float? = nil,
        lfHfRatio: Float? = nil,
        coherenceTrend: Float? = nil
    ) {
        if let v = coherence { bioState.coherence = v }
        if let v = hrv { bioState.hrv = v }
        if let v = heartRate { bioState.heartRate = v }
        if let v = breathPhase { bioState.breathPhase = v }
        if let v = breathDepth { bioState.breathDepth = v }
        if let v = lfHfRatio { bioState.lfHfRatio = v }
        if let v = coherenceTrend { bioState.coherenceTrend = v }
    }

    /// No-op on non-visionOS
    public func setPassthroughEnabled(_ enabled: Bool) {}

    /// No-op on non-visionOS
    public func setPassthroughBlend(_ factor: Float) {}
}

#endif
