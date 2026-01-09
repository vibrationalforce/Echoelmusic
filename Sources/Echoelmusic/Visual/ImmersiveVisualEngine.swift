// ImmersiveVisualEngine.swift
// Echoelmusic - Immersive VR/AR/Spatial Computing Visual Engine
// Created 2026-01-05 - Phase 8000 MAXIMUM OVERDRIVE

import Foundation
import SwiftUI
import Combine
import simd

#if canImport(RealityKit)
import RealityKit
#endif

#if canImport(ARKit)
import ARKit
#endif

//==============================================================================
// MARK: - Immersive Mode
//==============================================================================

/// Types of immersive experiences
public enum ImmersiveMode: String, CaseIterable, Identifiable, Sendable {
    case fullSpace = "full_space"           // Complete environment replacement
    case mixedReality = "mixed_reality"     // AR overlay on real world
    case portal = "portal"                  // Window into another space
    case volumetric = "volumetric"          // 3D content in shared space
    case passthrough = "passthrough"        // Enhanced real world
    case bioField = "bio_field"             // Coherence visualization around user
    case quantumSpace = "quantum_space"     // Quantum-inspired environment
    case soundscape = "soundscape"          // Audio-driven spatial visuals

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fullSpace: return "Full Immersive Space"
        case .mixedReality: return "Mixed Reality"
        case .portal: return "Portal Window"
        case .volumetric: return "Volumetric Display"
        case .passthrough: return "Enhanced Passthrough"
        case .bioField: return "Bio-Coherence Field"
        case .quantumSpace: return "Quantum Space"
        case .soundscape: return "Spatial Soundscape"
        }
    }

    public var description: String {
        switch self {
        case .fullSpace: return "Complete 360° environment replacement"
        case .mixedReality: return "Digital content blended with real world"
        case .portal: return "Window looking into virtual space"
        case .volumetric: return "3D holographic content"
        case .passthrough: return "Real world with visual enhancements"
        case .bioField: return "HRV-driven energy field visualization"
        case .quantumSpace: return "Quantum probability cloud environment"
        case .soundscape: return "Audio-reactive spatial environment"
        }
    }
}

//==============================================================================
// MARK: - Spatial Element
//==============================================================================

/// A 3D element in the immersive space
public struct SpatialElement: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var type: SpatialElementType
    public var position: SIMD3<Float>
    public var rotation: simd_quatf
    public var scale: SIMD3<Float>
    public var material: SpatialMaterial
    public var animation: SpatialAnimation?
    public var isBioReactive: Bool
    public var bioReactivityAmount: Float
    public var isVisible: Bool
    public var opacity: Float

    public init(
        id: UUID = UUID(),
        name: String = "Element",
        type: SpatialElementType = .sphere,
        position: SIMD3<Float> = .zero,
        rotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
        scale: SIMD3<Float> = SIMD3(1, 1, 1),
        material: SpatialMaterial = SpatialMaterial(),
        animation: SpatialAnimation? = nil,
        isBioReactive: Bool = false,
        bioReactivityAmount: Float = 0.5,
        isVisible: Bool = true,
        opacity: Float = 1.0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.material = material
        self.animation = animation
        self.isBioReactive = isBioReactive
        self.bioReactivityAmount = bioReactivityAmount
        self.isVisible = isVisible
        self.opacity = opacity
    }
}

//==============================================================================
// MARK: - Spatial Element Type
//==============================================================================

public enum SpatialElementType: String, CaseIterable, Identifiable, Sendable {
    // Primitives
    case sphere = "sphere"
    case cube = "cube"
    case cylinder = "cylinder"
    case cone = "cone"
    case torus = "torus"
    case plane = "plane"
    case capsule = "capsule"

    // Complex
    case particleSystem = "particle_system"
    case lightField = "light_field"
    case volumetricFog = "volumetric_fog"
    case portal = "portal"
    case mirror = "mirror"
    case text3D = "text_3d"
    case mesh = "custom_mesh"

    // Bio-reactive
    case coherenceOrb = "coherence_orb"
    case heartbeatPulse = "heartbeat_pulse"
    case breathingSphere = "breathing_sphere"
    case auraField = "aura_field"
    case spectrumRing = "spectrum_ring"

    // Audio-reactive
    case spectrumBar = "spectrum_bar"
    case waveformRing = "waveform_ring"
    case beatPulse = "beat_pulse"
    case frequencyOrb = "frequency_orb"

    // Quantum
    case quantumWave = "quantum_wave"
    case probabilityCloud = "probability_cloud"
    case entanglementLine = "entanglement_line"
    case superpositionGhost = "superposition_ghost"

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    public var category: String {
        switch self {
        case .sphere, .cube, .cylinder, .cone, .torus, .plane, .capsule:
            return "Primitive"
        case .particleSystem, .lightField, .volumetricFog, .portal, .mirror, .text3D, .mesh:
            return "Complex"
        case .coherenceOrb, .heartbeatPulse, .breathingSphere, .auraField, .spectrumRing:
            return "Bio-Reactive"
        case .spectrumBar, .waveformRing, .beatPulse, .frequencyOrb:
            return "Audio-Reactive"
        case .quantumWave, .probabilityCloud, .entanglementLine, .superpositionGhost:
            return "Quantum"
        }
    }
}

//==============================================================================
// MARK: - Spatial Material
//==============================================================================

public struct SpatialMaterial: Sendable {
    public var color: SIMD4<Float>
    public var metallic: Float
    public var roughness: Float
    public var emissive: SIMD3<Float>
    public var emissiveIntensity: Float
    public var transparency: Float
    public var refractionIndex: Float
    public var shader: ShaderType
    public var textureURL: URL?

    public init(
        color: SIMD4<Float> = SIMD4(0.5, 0.7, 1.0, 1.0),
        metallic: Float = 0.0,
        roughness: Float = 0.5,
        emissive: SIMD3<Float> = .zero,
        emissiveIntensity: Float = 0.0,
        transparency: Float = 0.0,
        refractionIndex: Float = 1.0,
        shader: ShaderType = .standard,
        textureURL: URL? = nil
    ) {
        self.color = color
        self.metallic = metallic
        self.roughness = roughness
        self.emissive = emissive
        self.emissiveIntensity = emissiveIntensity
        self.transparency = transparency
        self.refractionIndex = refractionIndex
        self.shader = shader
        self.textureURL = textureURL
    }

    public enum ShaderType: String, CaseIterable, Sendable {
        case standard = "standard"
        case unlit = "unlit"
        case emissive = "emissive"
        case glass = "glass"
        case holographic = "holographic"
        case bioGlow = "bio_glow"
        case quantumShimmer = "quantum_shimmer"
        case audioReactive = "audio_reactive"
        case portal = "portal"
        case aura = "aura"
    }
}

//==============================================================================
// MARK: - Spatial Animation
//==============================================================================

public struct SpatialAnimation: Sendable {
    public var type: AnimationType
    public var duration: Double
    public var repeatMode: RepeatMode
    public var easing: EasingType
    public var parameters: [String: Float]

    public init(
        type: AnimationType = .orbit,
        duration: Double = 5.0,
        repeatMode: RepeatMode = .loop,
        easing: EasingType = .linear,
        parameters: [String: Float] = [:]
    ) {
        self.type = type
        self.duration = duration
        self.repeatMode = repeatMode
        self.easing = easing
        self.parameters = parameters
    }

    public enum AnimationType: String, CaseIterable, Sendable {
        case orbit = "orbit"
        case rotate = "rotate"
        case pulse = "pulse"
        case float = "float"
        case breathe = "breathe"
        case oscillate = "oscillate"
        case spiral = "spiral"
        case morph = "morph"
        case followPath = "follow_path"
        case lookAtUser = "look_at_user"
        case bioSync = "bio_sync"
        case audioSync = "audio_sync"
    }

    public enum RepeatMode: String, Sendable {
        case once = "once"
        case loop = "loop"
        case pingPong = "ping_pong"
        case bioReactive = "bio_reactive"
    }

    public enum EasingType: String, Sendable {
        case linear = "linear"
        case easeIn = "ease_in"
        case easeOut = "ease_out"
        case easeInOut = "ease_in_out"
        case elastic = "elastic"
        case bounce = "bounce"
        case breath = "breath"
    }
}

//==============================================================================
// MARK: - Spatial Light
//==============================================================================

public struct SpatialLight: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var type: LightType
    public var color: SIMD3<Float>
    public var intensity: Float
    public var position: SIMD3<Float>
    public var direction: SIMD3<Float>
    public var castsShadows: Bool
    public var isBioReactive: Bool

    public init(
        id: UUID = UUID(),
        name: String = "Light",
        type: LightType = .point,
        color: SIMD3<Float> = SIMD3(1, 1, 1),
        intensity: Float = 1000,
        position: SIMD3<Float> = SIMD3(0, 2, 0),
        direction: SIMD3<Float> = SIMD3(0, -1, 0),
        castsShadows: Bool = true,
        isBioReactive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.color = color
        self.intensity = intensity
        self.position = position
        self.direction = direction
        self.castsShadows = castsShadows
        self.isBioReactive = isBioReactive
    }

    public enum LightType: String, CaseIterable, Sendable {
        case directional = "directional"
        case point = "point"
        case spot = "spot"
        case area = "area"
        case ambient = "ambient"
        case volumetric = "volumetric"
    }
}

//==============================================================================
// MARK: - Immersive Scene
//==============================================================================

public struct ImmersiveScene: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var mode: ImmersiveMode
    public var elements: [SpatialElement]
    public var lights: [SpatialLight]
    public var skybox: SkyboxConfig
    public var ambientAudio: URL?
    public var postProcessing: PostProcessingConfig

    public init(
        id: UUID = UUID(),
        name: String = "Untitled Scene",
        mode: ImmersiveMode = .fullSpace,
        elements: [SpatialElement] = [],
        lights: [SpatialLight] = [],
        skybox: SkyboxConfig = SkyboxConfig(),
        ambientAudio: URL? = nil,
        postProcessing: PostProcessingConfig = PostProcessingConfig()
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.elements = elements
        self.lights = lights
        self.skybox = skybox
        self.ambientAudio = ambientAudio
        self.postProcessing = postProcessing
    }
}

public struct SkyboxConfig: Sendable {
    public var type: SkyboxType
    public var color: SIMD4<Float>
    public var textureURL: URL?
    public var rotation: Float
    public var exposure: Float
    public var isBioReactive: Bool

    public init(
        type: SkyboxType = .gradient,
        color: SIMD4<Float> = SIMD4(0.1, 0.1, 0.2, 1.0),
        textureURL: URL? = nil,
        rotation: Float = 0,
        exposure: Float = 1.0,
        isBioReactive: Bool = false
    ) {
        self.type = type
        self.color = color
        self.textureURL = textureURL
        self.rotation = rotation
        self.exposure = exposure
        self.isBioReactive = isBioReactive
    }

    public enum SkyboxType: String, CaseIterable, Sendable {
        case solid = "solid"
        case gradient = "gradient"
        case hdri = "hdri"
        case procedural = "procedural"
        case stars = "stars"
        case nebula = "nebula"
        case bioReactive = "bio_reactive"
    }
}

public struct PostProcessingConfig: Sendable {
    public var bloom: Float
    public var contrast: Float
    public var saturation: Float
    public var vignette: Float
    public var chromaticAberration: Float
    public var filmGrain: Float
    public var depthOfField: Bool
    public var focalDistance: Float

    public init(
        bloom: Float = 0.3,
        contrast: Float = 1.0,
        saturation: Float = 1.0,
        vignette: Float = 0.0,
        chromaticAberration: Float = 0.0,
        filmGrain: Float = 0.0,
        depthOfField: Bool = false,
        focalDistance: Float = 2.0
    ) {
        self.bloom = bloom
        self.contrast = contrast
        self.saturation = saturation
        self.vignette = vignette
        self.chromaticAberration = chromaticAberration
        self.filmGrain = filmGrain
        self.depthOfField = depthOfField
        self.focalDistance = focalDistance
    }
}

//==============================================================================
// MARK: - User Spatial State
//==============================================================================

public struct UserSpatialState: Sendable {
    public var headPosition: SIMD3<Float>
    public var headRotation: simd_quatf
    public var leftHandPosition: SIMD3<Float>?
    public var rightHandPosition: SIMD3<Float>?
    public var gazeDirection: SIMD3<Float>
    public var isGrounded: Bool

    public init(
        headPosition: SIMD3<Float> = SIMD3(0, 1.6, 0),
        headRotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1),
        leftHandPosition: SIMD3<Float>? = nil,
        rightHandPosition: SIMD3<Float>? = nil,
        gazeDirection: SIMD3<Float> = SIMD3(0, 0, -1),
        isGrounded: Bool = true
    ) {
        self.headPosition = headPosition
        self.headRotation = headRotation
        self.leftHandPosition = leftHandPosition
        self.rightHandPosition = rightHandPosition
        self.gazeDirection = gazeDirection
        self.isGrounded = isGrounded
    }
}

//==============================================================================
// MARK: - Immersive Visual Engine
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
public final class ImmersiveVisualEngine: ObservableObject {

    //==========================================================================
    // MARK: - Published Properties
    //==========================================================================

    @Published public var isActive: Bool = false
    @Published public var currentMode: ImmersiveMode = .fullSpace
    @Published public var currentScene: ImmersiveScene = ImmersiveScene()
    @Published public var userState: UserSpatialState = UserSpatialState()

    // Bio-reactive
    @Published public var coherence: Double = 0.5
    @Published public var heartRate: Double = 70.0
    @Published public var breathPhase: Double = 0.5
    @Published public var hrvMs: Double = 50.0

    // Audio-reactive
    @Published public var audioLevel: Double = 0.0
    @Published public var spectrumData: [Float] = Array(repeating: 0, count: 64)
    @Published public var bpm: Double = 120.0
    @Published public var beatDetected: Bool = false

    // Performance
    @Published public var fps: Double = 90.0
    @Published public var renderTime: Double = 0.0
    @Published public var triangleCount: Int = 0

    //==========================================================================
    // MARK: - Private Properties
    //==========================================================================

    private var cancellables = Set<AnyCancellable>()
    private var renderTimer: Timer?
    private var lastFrameTime: Date = Date()
    private var time: Double = 0

    //==========================================================================
    // MARK: - Initialization
    //==========================================================================

    public init() {
        setupDefaultScene()
    }

    private func setupDefaultScene() {
        currentScene = ImmersiveScene(
            name: "Bio-Coherence Space",
            mode: .bioField,
            elements: [
                SpatialElement(
                    name: "Coherence Orb",
                    type: .coherenceOrb,
                    position: SIMD3(0, 1.5, -2),
                    material: SpatialMaterial(
                        color: SIMD4(0.3, 0.7, 1.0, 0.8),
                        emissiveIntensity: 1.0,
                        shader: .bioGlow
                    ),
                    isBioReactive: true,
                    bioReactivityAmount: 1.0
                ),
                SpatialElement(
                    name: "Aura Field",
                    type: .auraField,
                    position: SIMD3(0, 1, 0),
                    scale: SIMD3(2, 2, 2),
                    material: SpatialMaterial(
                        color: SIMD4(0.5, 0.3, 1.0, 0.3),
                        shader: .aura
                    ),
                    isBioReactive: true,
                    bioReactivityAmount: 0.8
                ),
                SpatialElement(
                    name: "Particle System",
                    type: .particleSystem,
                    position: SIMD3(0, 2, -3),
                    material: SpatialMaterial(
                        emissive: SIMD3(1, 1, 1),
                        emissiveIntensity: 0.5
                    ),
                    animation: SpatialAnimation(type: .bioSync)
                )
            ],
            lights: [
                SpatialLight(
                    name: "Main Light",
                    type: .point,
                    color: SIMD3(0.9, 0.9, 1.0),
                    intensity: 800,
                    position: SIMD3(0, 3, 0),
                    isBioReactive: true
                ),
                SpatialLight(
                    name: "Ambient",
                    type: .ambient,
                    color: SIMD3(0.2, 0.2, 0.4),
                    intensity: 200
                )
            ],
            skybox: SkyboxConfig(
                type: .bioReactive,
                color: SIMD4(0.05, 0.05, 0.15, 1.0)
            )
        )
    }

    //==========================================================================
    // MARK: - Engine Control
    //==========================================================================

    public func start() {
        guard !isActive else { return }
        isActive = true

        renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 90.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    public func stop() {
        isActive = false
        renderTimer?.invalidate()
        renderTimer = nil
    }

    private func tick() {
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastFrameTime)
        lastFrameTime = now

        time += deltaTime
        fps = 1.0 / deltaTime

        // Update bio-reactive elements
        updateBioReactiveElements(deltaTime: deltaTime)

        // Update audio-reactive elements
        updateAudioReactiveElements(deltaTime: deltaTime)

        // Update animations
        updateAnimations(deltaTime: deltaTime)
    }

    private func updateBioReactiveElements(deltaTime: Double) {
        for i in currentScene.elements.indices where currentScene.elements[i].isBioReactive {
            let amount = currentScene.elements[i].bioReactivityAmount

            // Scale based on coherence
            let coherenceScale = Float(0.8 + coherence * 0.4 * Double(amount))
            currentScene.elements[i].scale = SIMD3(coherenceScale, coherenceScale, coherenceScale)

            // Color based on coherence (blue to purple to gold)
            let hue = Float(0.55 + coherence * 0.15)
            let rgb = hsvToRGB(h: hue, s: 0.7, v: 0.9)
            currentScene.elements[i].material.color = SIMD4(rgb.0, rgb.1, rgb.2, 1.0)

            // Emissive based on breath
            let breathEmissive = Float(0.3 + breathPhase * 0.7 * Double(amount))
            currentScene.elements[i].material.emissiveIntensity = breathEmissive
        }

        // Update bio-reactive lights
        for i in currentScene.lights.indices where currentScene.lights[i].isBioReactive {
            let baseIntensity: Float = 800
            let coherenceBoost = Float(coherence * 400)
            currentScene.lights[i].intensity = baseIntensity + coherenceBoost

            // Pulsate with heartbeat
            let heartbeatPhase = Float(sin(time * (heartRate / 60.0) * .pi * 2))
            currentScene.lights[i].intensity *= (1.0 + heartbeatPhase * 0.1)
        }
    }

    private func updateAudioReactiveElements(deltaTime: Double) {
        for i in currentScene.elements.indices {
            guard let animation = currentScene.elements[i].animation,
                  animation.type == .audioSync else { continue }

            // Beat pulse
            if beatDetected {
                let currentScale = currentScene.elements[i].scale
                currentScene.elements[i].scale = currentScale * 1.2
            } else {
                // Decay back
                let currentScale = currentScene.elements[i].scale
                currentScene.elements[i].scale = currentScale * 0.95 + SIMD3(1, 1, 1) * 0.05
            }
        }
    }

    private func updateAnimations(deltaTime: Double) {
        for i in currentScene.elements.indices {
            guard let animation = currentScene.elements[i].animation else { continue }

            let progress = Float(time.truncatingRemainder(dividingBy: animation.duration) / animation.duration)

            switch animation.type {
            case .orbit:
                let angle = progress * 2 * .pi
                let radius: Float = animation.parameters["radius"] ?? 2.0
                currentScene.elements[i].position.x = cos(angle) * radius
                currentScene.elements[i].position.z = sin(angle) * radius

            case .rotate:
                let speed = animation.parameters["speed"] ?? 1.0
                let axis = SIMD3<Float>(0, 1, 0)
                currentScene.elements[i].rotation = simd_quatf(angle: progress * 2 * .pi * speed, axis: axis)

            case .pulse:
                let scale = 1.0 + sin(progress * 2 * .pi) * 0.2
                currentScene.elements[i].scale = SIMD3(scale, scale, scale)

            case .float:
                let height = animation.parameters["height"] ?? 0.3
                currentScene.elements[i].position.y = sin(progress * 2 * .pi) * height

            case .breathe:
                let breathScale = Float(0.9 + breathPhase * 0.2)
                currentScene.elements[i].scale = SIMD3(breathScale, breathScale, breathScale)

            case .bioSync:
                // Combines multiple bio signals
                let coherenceScale = Float(0.8 + coherence * 0.4)
                let breathOffset = Float(sin(breathPhase * .pi * 2) * 0.1)
                currentScene.elements[i].scale = SIMD3(coherenceScale, coherenceScale, coherenceScale)
                currentScene.elements[i].position.y += breathOffset

            default:
                break
            }
        }
    }

    private func hsvToRGB(h: Float, s: Float, v: Float) -> (Float, Float, Float) {
        let i = Int(h * 6)
        let f = h * 6 - Float(i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)

        switch i % 6 {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }

    //==========================================================================
    // MARK: - Bio Input
    //==========================================================================

    public func updateBioData(coherence: Double, heartRate: Double, breathPhase: Double, hrv: Double) {
        self.coherence = coherence
        self.heartRate = heartRate
        self.breathPhase = breathPhase
        self.hrvMs = hrv
    }

    //==========================================================================
    // MARK: - Audio Input
    //==========================================================================

    public func updateAudioData(level: Double, spectrum: [Float], bpm: Double, beat: Bool) {
        self.audioLevel = level
        self.spectrumData = spectrum
        self.bpm = bpm
        self.beatDetected = beat
    }

    //==========================================================================
    // MARK: - User Tracking
    //==========================================================================

    public func updateUserState(_ state: UserSpatialState) {
        self.userState = state
    }

    //==========================================================================
    // MARK: - Scene Management
    //==========================================================================

    public func loadScene(_ scene: ImmersiveScene) {
        currentScene = scene
        currentMode = scene.mode
    }

    public func addElement(_ element: SpatialElement) {
        currentScene.elements.append(element)
    }

    public func removeElement(id: UUID) {
        currentScene.elements.removeAll { $0.id == id }
    }

    public func addLight(_ light: SpatialLight) {
        currentScene.lights.append(light)
    }

    public func removeLight(id: UUID) {
        currentScene.lights.removeAll { $0.id == id }
    }

    //==========================================================================
    // MARK: - Presets
    //==========================================================================

    public func loadMeditationPreset() {
        currentScene = ImmersiveScene(
            name: "Meditation Space",
            mode: .bioField,
            elements: [
                SpatialElement(
                    name: "Coherence Orb",
                    type: .coherenceOrb,
                    position: SIMD3(0, 1.5, -2),
                    material: SpatialMaterial(
                        color: SIMD4(0.3, 0.7, 1.0, 0.8),
                        emissiveIntensity: 0.8,
                        shader: .bioGlow
                    ),
                    isBioReactive: true
                ),
                SpatialElement(
                    name: "Breathing Sphere",
                    type: .breathingSphere,
                    position: SIMD3(0, 1, -2),
                    scale: SIMD3(0.5, 0.5, 0.5),
                    material: SpatialMaterial(
                        color: SIMD4(0.4, 0.8, 0.6, 0.6),
                        shader: .glass
                    ),
                    animation: SpatialAnimation(type: .breathe),
                    isBioReactive: true
                ),
                SpatialElement(
                    name: "Particles",
                    type: .particleSystem,
                    position: SIMD3(0, 2, -2),
                    animation: SpatialAnimation(type: .bioSync)
                )
            ],
            lights: [
                SpatialLight(type: .ambient, color: SIMD3(0.2, 0.2, 0.4), intensity: 300)
            ],
            skybox: SkyboxConfig(type: .gradient, color: SIMD4(0.05, 0.08, 0.15, 1.0)),
            postProcessing: PostProcessingConfig(bloom: 0.5, vignette: 0.2)
        )
    }

    public func loadQuantumPreset() {
        currentScene = ImmersiveScene(
            name: "Quantum Space",
            mode: .quantumSpace,
            elements: [
                SpatialElement(
                    name: "Quantum Wave",
                    type: .quantumWave,
                    position: SIMD3(0, 1, -3),
                    scale: SIMD3(2, 2, 2),
                    material: SpatialMaterial(
                        color: SIMD4(0.7, 0.3, 1.0, 0.6),
                        shader: .quantumShimmer
                    ),
                    animation: SpatialAnimation(type: .oscillate)
                ),
                SpatialElement(
                    name: "Probability Cloud",
                    type: .probabilityCloud,
                    position: SIMD3(0, 2, -2),
                    material: SpatialMaterial(
                        color: SIMD4(0.3, 0.9, 0.8, 0.4),
                        shader: .holographic
                    ),
                    isBioReactive: true
                ),
                SpatialElement(
                    name: "Superposition Ghost",
                    type: .superpositionGhost,
                    position: SIMD3(-1, 1.5, -2),
                    material: SpatialMaterial(
                        color: SIMD4(1.0, 1.0, 1.0, 0.3),
                        shader: .holographic
                    )
                )
            ],
            lights: [
                SpatialLight(type: .volumetric, color: SIMD3(0.5, 0.3, 0.8), intensity: 500)
            ],
            skybox: SkyboxConfig(type: .nebula),
            postProcessing: PostProcessingConfig(bloom: 0.7, chromaticAberration: 0.1)
        )
    }

    public func loadConcertPreset() {
        currentScene = ImmersiveScene(
            name: "Concert Space",
            mode: .soundscape,
            elements: [
                SpatialElement(
                    name: "Spectrum Rings",
                    type: .waveformRing,
                    position: SIMD3(0, 2, -4),
                    scale: SIMD3(3, 3, 3),
                    material: SpatialMaterial(shader: .audioReactive),
                    animation: SpatialAnimation(type: .audioSync)
                ),
                SpatialElement(
                    name: "Beat Pulse",
                    type: .beatPulse,
                    position: SIMD3(0, 1, -3),
                    material: SpatialMaterial(
                        emissive: SIMD3(1, 0.3, 0.5),
                        emissiveIntensity: 1.0
                    ),
                    animation: SpatialAnimation(type: .audioSync)
                ),
                SpatialElement(
                    name: "Frequency Orbs",
                    type: .frequencyOrb,
                    position: SIMD3(0, 2.5, -2),
                    animation: SpatialAnimation(type: .audioSync)
                )
            ],
            lights: [
                SpatialLight(type: .spot, color: SIMD3(1, 0, 0.5), intensity: 1000, position: SIMD3(-2, 3, 0)),
                SpatialLight(type: .spot, color: SIMD3(0, 0.5, 1), intensity: 1000, position: SIMD3(2, 3, 0)),
                SpatialLight(type: .point, color: SIMD3(1, 1, 1), intensity: 500, position: SIMD3(0, 4, -2))
            ],
            skybox: SkyboxConfig(type: .stars),
            postProcessing: PostProcessingConfig(bloom: 0.8, contrast: 1.2)
        )
    }

    public func loadMixedRealityPreset() {
        currentScene = ImmersiveScene(
            name: "Mixed Reality",
            mode: .mixedReality,
            elements: [
                SpatialElement(
                    name: "Info Panel",
                    type: .plane,
                    position: SIMD3(0, 1.5, -1),
                    scale: SIMD3(0.5, 0.3, 1),
                    material: SpatialMaterial(
                        color: SIMD4(0.1, 0.1, 0.1, 0.9),
                        shader: .unlit
                    )
                ),
                SpatialElement(
                    name: "Bio Status Orb",
                    type: .coherenceOrb,
                    position: SIMD3(0.5, 1.2, -0.8),
                    scale: SIMD3(0.15, 0.15, 0.15),
                    material: SpatialMaterial(shader: .bioGlow),
                    isBioReactive: true
                )
            ],
            lights: [
                SpatialLight(type: .ambient, intensity: 400)
            ],
            skybox: SkyboxConfig(type: .solid, color: SIMD4(0, 0, 0, 0)),
            postProcessing: PostProcessingConfig(bloom: 0.2)
        )
    }
}

//==============================================================================
// MARK: - Immersive Visual View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct ImmersiveVisualView: View {
    @ObservedObject var engine: ImmersiveVisualEngine
    @State private var showSettings = false

    public init(engine: ImmersiveVisualEngine) {
        self.engine = engine
    }

    public var body: some View {
        ZStack {
            // 3D Scene Preview (2D representation)
            ImmersiveScenePreview(engine: engine)
                .ignoresSafeArea()

            // Overlay controls
            VStack {
                // Top bar
                HStack {
                    // Mode indicator
                    Text(engine.currentMode.displayName)
                        .font(.caption.bold())
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)

                    Spacer()

                    // FPS
                    Text("\(Int(engine.fps)) FPS")
                        .font(.caption.monospacedDigit())
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)

                    // Settings
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                }
                .padding()

                Spacer()

                // Bottom controls
                HStack {
                    // Bio status
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Coherence: \(Int(engine.coherence * 100))%")
                        Text("HR: \(Int(engine.heartRate)) BPM")
                    }
                    .font(.caption2)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)

                    Spacer()

                    // Start/Stop
                    Button {
                        if engine.isActive {
                            engine.stop()
                        } else {
                            engine.start()
                        }
                    } label: {
                        Image(systemName: engine.isActive ? "stop.fill" : "play.fill")
                            .font(.title2)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showSettings) {
            ImmersiveSettingsView(engine: engine)
        }
    }
}

//==============================================================================
// MARK: - Immersive Scene Preview
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct ImmersiveScenePreview: View {
    @ObservedObject var engine: ImmersiveVisualEngine

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                // Background
                drawBackground(context: context, size: size)

                // Elements
                for element in engine.currentScene.elements where element.isVisible {
                    drawElement(context: context, size: size, element: element)
                }

                // Post-processing effects
                drawPostProcessing(context: context, size: size)
            }
        }
    }

    private func drawBackground(context: GraphicsContext, size: CGSize) {
        let skybox = engine.currentScene.skybox
        let bioMod = engine.coherence

        let baseColor = Color(
            red: Double(skybox.color.x) + bioMod * 0.1,
            green: Double(skybox.color.y) + bioMod * 0.05,
            blue: Double(skybox.color.z) + bioMod * 0.15
        )

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(baseColor)
        )

        // Stars for certain skybox types
        if skybox.type == .stars || skybox.type == .nebula {
            for i in 0..<100 {
                let seed = Double(i) * 0.1
                let x = (sin(seed * 3) * 0.5 + 0.5) * size.width
                let y = (cos(seed * 2.5) * 0.5 + 0.5) * size.height
                let brightness = sin(seed * 7 + engine.coherence * .pi) * 0.5 + 0.5

                context.fill(
                    Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)),
                    with: .color(.white.opacity(brightness * 0.8))
                )
            }
        }
    }

    private func drawElement(context: GraphicsContext, size: CGSize, element: SpatialElement) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        // Project 3D to 2D (simple orthographic)
        let x = center.x + CGFloat(element.position.x) * 100
        let y = center.y - CGFloat(element.position.y) * 100 + CGFloat(element.position.z) * 30
        let scaleFactor = CGFloat(element.scale.x) * (50 + CGFloat(element.position.z) * 10)

        let color = Color(
            red: Double(element.material.color.x),
            green: Double(element.material.color.y),
            blue: Double(element.material.color.z)
        ).opacity(Double(element.material.color.w * element.opacity))

        switch element.type {
        case .sphere, .coherenceOrb, .breathingSphere, .frequencyOrb:
            let gradient = RadialGradient(
                colors: [color, color.opacity(0.3), Color.clear],
                center: .center,
                startRadius: 0,
                endRadius: scaleFactor
            )
            context.fill(
                Path(ellipseIn: CGRect(x: x - scaleFactor, y: y - scaleFactor, width: scaleFactor * 2, height: scaleFactor * 2)),
                with: .radialGradient(
                    Gradient(colors: [color, color.opacity(0.3), Color.clear]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: scaleFactor
                )
            )

        case .cube:
            context.fill(
                Path(roundedRect: CGRect(x: x - scaleFactor, y: y - scaleFactor, width: scaleFactor * 2, height: scaleFactor * 2), cornerRadius: 4),
                with: .color(color)
            )

        case .auraField:
            for i in 0..<5 {
                let ringRadius = scaleFactor * (1 + CGFloat(i) * 0.3)
                let ringOpacity = 0.3 - Double(i) * 0.05
                context.stroke(
                    Path(ellipseIn: CGRect(x: x - ringRadius, y: y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)),
                    with: .color(color.opacity(ringOpacity)),
                    lineWidth: 2
                )
            }

        case .particleSystem:
            for i in 0..<30 {
                let seed = Double(i) * 0.1
                let angle = seed * .pi * 2 + engine.coherence * .pi
                let dist = scaleFactor * (0.5 + sin(seed * 5) * 0.5)
                let px = x + cos(angle) * dist
                let py = y + sin(angle) * dist
                let particleSize = 3 + engine.coherence * 3

                context.fill(
                    Path(ellipseIn: CGRect(x: px - particleSize / 2, y: py - particleSize / 2, width: particleSize, height: particleSize)),
                    with: .color(color.opacity(0.8))
                )
            }

        case .waveformRing:
            var path = Path()
            let segments = 64
            for i in 0..<segments {
                let angle = Double(i) / Double(segments) * .pi * 2
                let spectrumIndex = i % engine.spectrumData.count
                let magnitude = CGFloat(engine.spectrumData[spectrumIndex])
                let radius = scaleFactor * (0.7 + magnitude * 0.5)
                let px = x + cos(angle) * radius
                let py = y + sin(angle) * radius

                if i == 0 {
                    path.move(to: CGPoint(x: px, y: py))
                } else {
                    path.addLine(to: CGPoint(x: px, y: py))
                }
            }
            path.closeSubpath()
            context.stroke(path, with: .color(color), lineWidth: 2)

        default:
            // Generic circle fallback
            context.fill(
                Path(ellipseIn: CGRect(x: x - scaleFactor / 2, y: y - scaleFactor / 2, width: scaleFactor, height: scaleFactor)),
                with: .color(color)
            )
        }
    }

    private func drawPostProcessing(context: GraphicsContext, size: CGSize) {
        let pp = engine.currentScene.postProcessing

        // Bloom (simplified)
        if pp.bloom > 0 {
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.white.opacity(Double(pp.bloom) * 0.05 * engine.coherence))
            )
        }

        // Vignette
        if pp.vignette > 0 {
            let vignetteGradient = RadialGradient(
                colors: [Color.clear, Color.black.opacity(Double(pp.vignette))],
                center: .center,
                startRadius: min(size.width, size.height) * 0.3,
                endRadius: max(size.width, size.height) * 0.8
            )
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    Gradient(colors: [Color.clear, Color.black.opacity(Double(pp.vignette))]),
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: min(size.width, size.height) * 0.3,
                    endRadius: max(size.width, size.height) * 0.8
                )
            )
        }
    }
}

//==============================================================================
// MARK: - Immersive Settings View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct ImmersiveSettingsView: View {
    @ObservedObject var engine: ImmersiveVisualEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Mode") {
                    Picker("Immersive Mode", selection: $engine.currentMode) {
                        ForEach(ImmersiveMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                Section("Presets") {
                    Button("Meditation") { engine.loadMeditationPreset() }
                    Button("Quantum Space") { engine.loadQuantumPreset() }
                    Button("Concert") { engine.loadConcertPreset() }
                    Button("Mixed Reality") { engine.loadMixedRealityPreset() }
                }

                Section("Elements (\(engine.currentScene.elements.count))") {
                    ForEach(engine.currentScene.elements) { element in
                        HStack {
                            Text(element.name)
                            Spacer()
                            Text(element.type.displayName)
                                .foregroundColor(.secondary)
                                .font(.caption)
                            if element.isBioReactive {
                                Image(systemName: "heart.fill")
                                    .foregroundColor(.pink)
                                    .font(.caption)
                            }
                        }
                    }
                }

                Section("Post Processing") {
                    HStack {
                        Text("Bloom")
                        Slider(value: Binding(
                            get: { Double(engine.currentScene.postProcessing.bloom) },
                            set: { engine.currentScene.postProcessing.bloom = Float($0) }
                        ), in: 0...1)
                    }
                    HStack {
                        Text("Vignette")
                        Slider(value: Binding(
                            get: { Double(engine.currentScene.postProcessing.vignette) },
                            set: { engine.currentScene.postProcessing.vignette = Float($0) }
                        ), in: 0...1)
                    }
                }
            }
            .navigationTitle("Immersive Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
