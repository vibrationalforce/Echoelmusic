// EchoelGodotBridge.swift
// Echoelmusic — Godot Engine Integration via LibGodot / SwiftGodotKit
//
// ═══════════════════════════════════════════════════════════════════════════════
// EchoelGodot — Embeds Godot 4.6 as rendering engine for 3D worlds & visuals
//
// Why Godot (not Unity/Unreal):
// - MIT license (100% free, forever)
// - Apple contributed visionOS support directly
// - LibGodot (4.6): Build Godot as embeddable library
// - SwiftGodotKit: Embed Godot into native Swift/SwiftUI apps
// - GDExtension: Native C++ plugin API for audio engine bridging
// - Zero runtime cost (no Unity splash screen, no revenue share)
//
// Architecture:
// ┌──────────────────────────────────────────────────────────────────────────┐
// │  Swift App (Echoelmusic)                                                 │
// │       │                                                                  │
// │       ├─→ SwiftGodotKit ──→ Embed Godot rendering in SwiftUI            │
// │       │                                                                  │
// │       ├─→ GDExtension ──→ Echoelmusic AudioEngine as Godot plugin       │
// │       │                                                                  │
// │       ├─→ EngineBus ──→ Bio/Audio data → Godot scene parameters         │
// │       │                                                                  │
// │       ▼                                                                  │
// │  Godot Engine (LibGodot)                                                 │
// │       │                                                                  │
// │       ├─→ EchoelWorldEngine scenes (procedural terrain/biomes)          │
// │       ├─→ EchoelAvatarEngine 3D models (Gaussian Splatting viewer)      │
// │       ├─→ Bio-reactive particle systems                                 │
// │       ├─→ Shader-based visuals (cymatics, aura, sacred geometry)        │
// │       ├─→ visionOS immersive spaces                                     │
// │       │                                                                  │
// │  Render Targets:                                                         │
// │       ├─→ SwiftUI embedded view (main app)                              │
// │       ├─→ External display (via ExternalDisplayRenderingPipeline)        │
// │       ├─→ visionOS spatial window / immersive space                     │
// │       └─→ Stream overlay (OBS/RTMP video source)                        │
// └──────────────────────────────────────────────────────────────────────────┘
//
// Integration Points:
// - LibGodot (Godot 4.6): godotengine.org — build as shared/static library
// - SwiftGodotKit: github.com/migueldeicaza/SwiftGodotKit — Swift/SwiftUI embed
// - GDExtension API: JSON-based interface for C++/Swift interop
// - Godot visionOS: Apple-contributed (Ricardo Sanchez-Saez, Apple visionOS team)
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Godot Scene Types

/// Predefined Godot scenes available for Echoelmusic
public enum GodotScene: String, CaseIterable, Sendable {
    case bioReactiveWorld = "bio_reactive_world"      // EchoelWorldEngine terrain
    case avatarViewer = "avatar_viewer"               // 3DGS avatar display
    case particleField = "particle_field"             // Bio-reactive particles
    case sacredGeometry = "sacred_geometry"            // Fibonacci/Mandala 3D
    case cymaticsPlane = "cymatics_plane"             // Audio-reactive surface
    case cosmicNebula = "cosmic_nebula"               // Space visualization
    case concertStage = "concert_stage"               // Virtual stage environment
    case collaborationSpace = "collaboration_space"   // Multi-user spatial
    case nftGallery = "nft_gallery"                   // NFT showcase space
    case immersiveVR = "immersive_vr"                 // visionOS full immersive

    public var description: String {
        switch self {
        case .bioReactiveWorld: return "Procedural world that breathes with your biometrics"
        case .avatarViewer: return "3D Gaussian Splatting avatar display"
        case .particleField: return "Bio-reactive particle field visualization"
        case .sacredGeometry: return "Sacred geometry patterns from coherence"
        case .cymaticsPlane: return "Audio-reactive cymatics visualization"
        case .cosmicNebula: return "Deep space nebula driven by music"
        case .concertStage: return "Virtual concert stage environment"
        case .collaborationSpace: return "Multi-user collaboration space"
        case .nftGallery: return "Dynamic NFT gallery showcase"
        case .immersiveVR: return "Full immersive VR experience (visionOS)"
        }
    }

    public var scenePath: String {
        "res://scenes/\(rawValue).tscn"
    }
}

/// Godot renderer type
public enum GodotRenderer: String, CaseIterable, Sendable {
    case forwardPlus = "Forward+"       // Desktop quality (Mac, Vision Pro)
    case mobile = "Mobile"              // Optimized for iPhone/iPad
    case compatibility = "Compatibility" // Widest support (OpenGL fallback)

    /// Auto-select best renderer for current device
    public static var recommended: GodotRenderer {
        #if os(iOS)
        return .mobile
        #elseif os(visionOS)
        return .forwardPlus
        #else
        return .forwardPlus
        #endif
    }
}

/// Godot engine state
public enum GodotEngineState: String, Sendable {
    case notLoaded = "Not Loaded"
    case loading = "Loading"
    case ready = "Ready"
    case running = "Running"
    case paused = "Paused"
    case error = "Error"
}

/// Parameters passed from Echoelmusic to Godot scenes
public struct GodotSceneParameters: Sendable {
    // Bio-reactive
    public var coherence: Float = 0.5
    public var heartRate: Float = 70
    public var breathingRate: Float = 15
    public var energy: Float = 0.5

    // Audio
    public var audioSpectrum: [Float] = []
    public var rmsLevel: Float = 0
    public var dominantFrequency: Float = 440
    public var tempo: Float = 120

    // World state (from EchoelWorldEngine)
    public var biome: String = "forest"
    public var weather: String = "clear"
    public var terrainAmplitude: Float = 0.5
    public var floraDensity: Float = 0.5
    public var waterLevel: Float = 0.3
    public var windSpeed: Float = 0.2

    // Avatar (from EchoelAvatarEngine)
    public var avatarStyle: String = "particle"
    public var auraIntensity: Float = 0.5
    public var facialValence: Float = 0

    // Visual
    public var colorTemperature: Float = 0.5
    public var particleDensity: Float = 0.5
    public var bloomIntensity: Float = 0.3
}

// MARK: - EchoelGodotBridge

/// Bridge between Echoelmusic and Godot Engine via LibGodot/SwiftGodotKit
///
/// Manages Godot lifecycle, scene loading, and parameter passing.
/// All bio/audio data flows through EngineBus → this bridge → Godot scene uniforms.
///
/// Usage:
/// ```swift
/// let godot = EchoelGodotBridge.shared
///
/// // Initialize Godot runtime
/// try await godot.initialize()
///
/// // Load a scene
/// godot.loadScene(.bioReactiveWorld)
///
/// // Parameters auto-update from EngineBus
/// // Or set manually:
/// godot.updateParameter("coherence", value: 0.85)
///
/// // In SwiftUI:
/// EchoelGodotView(scene: .bioReactiveWorld)
/// ```
@MainActor
public final class EchoelGodotBridge: ObservableObject {

    public static let shared = EchoelGodotBridge()

    // MARK: - Published State

    /// Godot engine state
    @Published public var state: GodotEngineState = .notLoaded

    /// Current active scene
    @Published public var activeScene: GodotScene?

    /// Selected renderer
    @Published public var renderer: GodotRenderer = .recommended

    /// Current scene parameters
    @Published public var parameters: GodotSceneParameters = GodotSceneParameters()

    /// Frames per second
    @Published public var fps: Float = 0

    /// GPU memory usage estimate (MB)
    @Published public var gpuMemoryMB: Float = 0

    /// Is LibGodot available on this device
    @Published public var isAvailable: Bool = false

    /// Scene list with availability
    @Published public var availableScenes: [GodotScene] = GodotScene.allCases

    // MARK: - Internal

    private var cancellables = Set<AnyCancellable>()
    private var busSubscription: BusSubscription?
    private var audioBusSubscription: BusSubscription?
    private var parameterUpdateTimer: Timer?

    // MARK: - Initialization

    private init() {
        checkAvailability()
        subscribeToBus()
    }

    // MARK: - Lifecycle

    /// Initialize the Godot engine runtime
    ///
    /// This loads LibGodot as an embedded library.
    /// On iOS/macOS: Uses SwiftGodotKit
    /// On visionOS: Uses Godot visionOS export (Apple-contributed)
    public func initialize() async throws {
        guard state == .notLoaded else { return }
        state = .loading

        // LibGodot initialization:
        //
        // import SwiftGodotKit
        //
        // GodotRuntime.run {
        //     // Godot main loop runs here
        //     // Register GDExtensions for Echoelmusic audio bridge
        // }
        //
        // Or via LibGodot C API:
        // let instance = GodotInstance()
        // instance.start(with: embeddedConfig)

        // For now, publish readiness event
        state = .ready

        EngineBus.shared.publish(.custom(
            topic: "godot.initialized",
            payload: [
                "renderer": renderer.rawValue,
                "scenes": "\(availableScenes.count)"
            ]
        ))

        // Start parameter sync at 30Hz
        startParameterSync()
    }

    /// Shutdown Godot engine
    public func shutdown() {
        parameterUpdateTimer?.invalidate()
        parameterUpdateTimer = nil
        activeScene = nil
        state = .notLoaded

        EngineBus.shared.publish(.custom(
            topic: "godot.shutdown",
            payload: [:]
        ))
    }

    // MARK: - Scene Management

    /// Load a Godot scene
    public func loadScene(_ scene: GodotScene) {
        guard state == .ready || state == .running else { return }

        activeScene = scene
        state = .running

        // SwiftGodotKit scene loading:
        // GodotRuntime.loadScene(scene.scenePath)

        EngineBus.shared.publish(.custom(
            topic: "godot.scene.loaded",
            payload: [
                "scene": scene.rawValue,
                "path": scene.scenePath
            ]
        ))
    }

    /// Unload current scene
    public func unloadScene() {
        activeScene = nil
        state = .ready
    }

    /// Switch to a different scene
    public func switchScene(to scene: GodotScene) {
        unloadScene()
        loadScene(scene)
    }

    // MARK: - Parameter Control

    /// Update a single parameter in the active Godot scene
    public func updateParameter(_ name: String, value: Float) {
        // In production, this calls into Godot via GDExtension:
        // godotInstance.setGlobal(name, value: Variant(value))

        EngineBus.shared.publish(.custom(
            topic: "godot.param",
            payload: [name: "\(value)"]
        ))
    }

    /// Update all parameters at once (efficient batch update)
    public func updateAllParameters(_ params: GodotSceneParameters) {
        parameters = params
    }

    // MARK: - visionOS Integration

    /// Create an immersive visionOS space with the current scene
    ///
    /// Uses Godot's visionOS export (Apple-contributed):
    /// - Phase 1: Windowed app (floating in 3D space) ✅ Merged
    /// - Phase 2: Swift/SwiftUI lifecycle integration
    /// - Phase 3: Fully immersive VR experiences
    public func createImmersiveSpace() {
        guard activeScene != nil else { return }

        #if os(visionOS)
        // Godot visionOS rendering via Metal + CompositorServices
        EngineBus.shared.publish(.custom(
            topic: "godot.visionos.immersive",
            payload: ["scene": activeScene?.rawValue ?? ""]
        ))
        #endif
    }

    // MARK: - GDExtension Bridge

    /// Register Echoelmusic audio engine as GDExtension
    ///
    /// This exposes the Echoelmusic audio engine to Godot scenes,
    /// allowing Godot to use our spatial audio, binaural beats,
    /// and bio-reactive audio processing.
    public func registerAudioExtension() {
        // GDExtension registration:
        //
        // class EchoelAudioGDExtension: GDExtension {
        //     func _ready() {
        //         // Bridge to Echoelmusic AudioEngine
        //     }
        //
        //     func processAudio(buffer: PackedFloat32Array) -> PackedFloat32Array {
        //         // Run through Echoelmusic DSP pipeline
        //     }
        // }

        EngineBus.shared.publish(.custom(
            topic: "godot.extension.registered",
            payload: ["name": "EchoelAudio"]
        ))
    }

    // MARK: - Private Methods

    private func checkAvailability() {
        // LibGodot requires:
        // 1. Godot 4.6+ compiled as library (libgodot.dylib / .a)
        // 2. SwiftGodotKit SPM package
        // 3. Metal-capable GPU

        // For now, mark as available on all Apple platforms with Metal
        #if canImport(MetalKit)
        isAvailable = true
        #else
        isAvailable = false
        #endif
    }

    /// Sync Echoelmusic parameters to Godot at 30Hz
    private func startParameterSync() {
        parameterUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncParametersToGodot()
            }
        }
    }

    /// Push current parameters to Godot runtime
    private func syncParametersToGodot() {
        guard state == .running else { return }

        // In production, this batches all parameter updates to Godot:
        // godotInstance.call("_echoelmusic_update", parameters.toDictionary())

        // Publish for any listeners
        EngineBus.shared.publish(.custom(
            topic: "godot.sync",
            payload: [
                "coherence": "\(parameters.coherence)",
                "energy": "\(parameters.energy)",
                "biome": parameters.biome
            ]
        ))
    }

    /// Subscribe to EngineBus for bio/audio data
    private func subscribeToBus() {
        busSubscription = EngineBus.shared.subscribe(to: .bio) { [weak self] msg in
            if case .bioUpdate(let bio) = msg {
                Task { @MainActor in
                    self?.parameters.coherence = bio.coherence
                    self?.parameters.heartRate = bio.heartRate
                    self?.parameters.breathingRate = bio.breathingRate
                    self?.parameters.energy = bio.energy
                }
            }
        }

        audioBusSubscription = EngineBus.shared.subscribe(to: .audio) { [weak self] msg in
            if case .audioAnalysis(let audio) = msg {
                Task { @MainActor in
                    self?.parameters.audioSpectrum = audio.spectrum
                    self?.parameters.rmsLevel = audio.rmsLevel
                    self?.parameters.dominantFrequency = audio.dominantFrequency
                }
            }
        }

        // Listen for world state updates
        let worldSub = EngineBus.shared.subscribe(to: .custom) { [weak self] msg in
            if case .custom(let topic, let payload) = msg, topic == "world.evolved" {
                Task { @MainActor in
                    self?.parameters.biome = payload["biome"] ?? "forest"
                    self?.parameters.weather = payload["weather"] ?? "clear"
                }
            }
        }
        _ = worldSub
    }
}
