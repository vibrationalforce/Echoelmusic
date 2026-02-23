// EchoelVisualCompositor.swift
// Echoelmusic - 8-Layer Bio-Reactive Visual Compositor
//
// Professional multi-layer visual compositor inspired by Imaginando VS's
// layer system, extended with bio-reactive capabilities. Replaces the
// single-mode architecture with a compositable 8-layer stack plus
// background, supporting independent blend modes, opacity, modulation
// routing, and MIDI channel assignment per layer.
//
// Integration: Receives data from UnifiedVisualSoundEngine (spectrumData,
// waveformData, beatDetected) and routes bio-reactive parameters
// (coherence, heartRate, breathPhase, audioLevel) to all layers.
// Actual GPU compositing delegated to MetalShaderManager.
//
// Architecture:
//   EchoelVisualCompositor (60Hz) ← UnifiedVisualSoundEngine
//       └─ 8 CompositorVisualLayers + 1 Background
//           └─ Per-layer: material, blend mode, opacity, modulation
//
// Supported Platforms: iOS 15+, macOS 12+, tvOS 15+, visionOS 1+
// Swift 5.9+, Zero external dependencies
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. All rights reserved.

import SwiftUI
import Combine

// MARK: - Visual Material Type

/// All available shader material types for visual layers.
///
/// Covers existing UnifiedVisualSoundEngine modes plus extended
/// procedural and bio-reactive material types. Each material maps
/// to a specific shader pipeline in MetalShaderManager.
enum VisualMaterialType: String, CaseIterable, Identifiable, Codable, Sendable {
    // Classic modes (from UnifiedVisualSoundEngine)
    case liquidLight = "Liquid Light"
    case rainbow = "Rainbow"
    case particles = "Particles"
    case spectrum = "Spectrum"
    case waveform = "Waveform"
    case mandala = "Mandala"
    case cymatics = "Cymatics"
    case vaporwave = "Vaporwave"
    case nebula = "Nebula"
    case kaleidoscope = "Kaleidoscope"
    case flowField = "Flow Field"

    // Sacred / organic
    case sacredGeometry = "Sacred Geometry"
    case fractalZoom = "Fractal Zoom"
    case reactionDiffusion = "Reaction Diffusion"
    case voronoiMesh = "Voronoi Mesh"
    case morphingBlob = "Morphing Blob"

    // Atmospheric / natural
    case auroraField = "Aurora Field"
    case plasmaWave = "Plasma Wave"
    case oceanWaves = "Ocean Waves"
    case fireEmbers = "Fire Embers"
    case crystalFormation = "Crystal Formation"
    case electricField = "Electric Field"

    // Tech / data
    case dataStream = "Data Stream"
    case tunnelEffect = "Tunnel Effect"
    case fluidSimulation = "Fluid Simulation"

    var id: String { rawValue }

    /// SF Symbol icon for picker UI
    var icon: String {
        switch self {
        case .liquidLight:        return "drop.fill"
        case .rainbow:            return "rainbow"
        case .particles:          return "sparkles"
        case .spectrum:           return "chart.bar.fill"
        case .waveform:           return "waveform.path"
        case .mandala:            return "circle.hexagongrid.fill"
        case .cymatics:           return "waveform.circle.fill"
        case .vaporwave:          return "square.grid.3x3.fill"
        case .nebula:             return "cloud.fill"
        case .kaleidoscope:       return "camera.filters"
        case .flowField:          return "wind"
        case .sacredGeometry:     return "seal.fill"
        case .fractalZoom:        return "arrow.up.left.and.arrow.down.right"
        case .reactionDiffusion:  return "drop.triangle.fill"
        case .voronoiMesh:        return "hexagon.fill"
        case .morphingBlob:       return "circle.and.line.horizontal"
        case .auroraField:        return "aqi.medium"
        case .plasmaWave:         return "bolt.fill"
        case .oceanWaves:         return "water.waves"
        case .fireEmbers:         return "flame.fill"
        case .crystalFormation:   return "diamond.fill"
        case .electricField:      return "bolt.horizontal.fill"
        case .dataStream:         return "ellipsis.curlybraces"
        case .tunnelEffect:       return "circle.dashed"
        case .fluidSimulation:    return "bubbles.and.sparkles.fill"
        }
    }

    /// Short description for tooltip / accessibility
    var description: String {
        switch self {
        case .liquidLight:        return "Flowing light streams synced to coherence"
        case .rainbow:            return "Physically correct rainbow spectrum mapping"
        case .particles:          return "Bio-reactive particle physics field"
        case .spectrum:           return "Real-time FFT frequency analyzer"
        case .waveform:           return "Audio oscilloscope display"
        case .mandala:            return "Sacred geometry with radial symmetry"
        case .cymatics:           return "Sound-driven Chladni plate patterns"
        case .vaporwave:          return "Retro neon grid aesthetic"
        case .nebula:             return "Cosmic gas cloud nebula"
        case .kaleidoscope:       return "Mirrored audio-reactive patterns"
        case .flowField:          return "Particles following vector fields"
        case .sacredGeometry:     return "Flower of life, Metatron, Fibonacci spirals"
        case .fractalZoom:        return "Infinite fractal zoom (Mandelbrot/Julia)"
        case .reactionDiffusion:  return "Turing pattern reaction-diffusion"
        case .voronoiMesh:        return "Dynamic Voronoi tessellation mesh"
        case .morphingBlob:       return "Organic morphing metaball blob"
        case .auroraField:        return "Northern lights curtain effect"
        case .plasmaWave:         return "Classic plasma wave interference"
        case .oceanWaves:         return "Raymarched ocean surface simulation"
        case .fireEmbers:         return "Volumetric fire with rising embers"
        case .crystalFormation:   return "Growing crystalline structures"
        case .electricField:      return "Electric arc and field lines"
        case .dataStream:         return "Matrix-style data stream overlay"
        case .tunnelEffect:       return "Infinite tunnel fly-through"
        case .fluidSimulation:    return "Navier-Stokes fluid dynamics"
        }
    }
}

// MARK: - Blend Mode

/// Blend modes for compositing visual layers.
///
/// Standard Photoshop/Metal blend modes plus a custom
/// ``quantumBlend`` mode that uses coherence to interpolate
/// between additive and multiply blending.
enum CompositorBlendMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case normal
    case additive
    case multiply
    case screen
    case overlay
    case softLight
    case hardLight
    case colorDodge
    case colorBurn
    case difference
    case exclusion
    case hue
    case saturation
    case luminosity
    case quantumBlend

    var id: String { rawValue }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .normal:       return "Normal"
        case .additive:     return "Additive"
        case .multiply:     return "Multiply"
        case .screen:       return "Screen"
        case .overlay:      return "Overlay"
        case .softLight:    return "Soft Light"
        case .hardLight:    return "Hard Light"
        case .colorDodge:   return "Color Dodge"
        case .colorBurn:    return "Color Burn"
        case .difference:   return "Difference"
        case .exclusion:    return "Exclusion"
        case .hue:          return "Hue"
        case .saturation:   return "Saturation"
        case .luminosity:   return "Luminosity"
        case .quantumBlend: return "Quantum Blend"
        }
    }
}

// MARK: - Visual Layer

/// A single compositable visual layer within the compositor stack.
///
/// Each layer owns its material type, blend mode, opacity, MIDI channel,
/// and a set of animatable parameters that can be driven by the
/// ``VisualModulationMatrix``.
struct CompositorVisualLayer: Identifiable, Equatable {

    // MARK: - Identity

    /// Unique identifier for this layer
    let id: UUID

    /// Human-readable layer name (editable)
    var name: String

    // MARK: - Core Properties

    /// Shader material assigned to this layer
    var material: VisualMaterialType

    /// Blend mode for compositing onto layers below
    var blendMode: CompositorBlendMode

    /// Layer opacity (0 = fully transparent, 1 = fully opaque)
    var opacity: Float

    /// Whether this layer is enabled (rendered)
    var isEnabled: Bool

    /// Whether this layer is solo'd (only solo layers render when any is solo)
    var isSolo: Bool

    // MARK: - MIDI

    /// MIDI channel this layer listens to (1-16, 0 = omni/all)
    var midiChannel: UInt8

    // MARK: - Transform Parameters

    /// Layer rotation in radians
    var rotation: Float

    /// Layer uniform scale factor
    var scale: Float

    /// Horizontal position offset (-1 to +1)
    var positionX: Float

    /// Vertical position offset (-1 to +1)
    var positionY: Float

    // MARK: - Color Adjustment

    /// Hue shift (0 to 1, wraps)
    var hueShift: Float

    /// Saturation multiplier (0 = grayscale, 1 = normal, 2 = oversaturated)
    var saturationMultiplier: Float

    /// Brightness offset (-1 to +1)
    var brightnessOffset: Float

    // MARK: - Material Parameters

    /// Animation speed multiplier for the shader
    var speed: Float

    /// Complexity / detail level of the shader (0-1)
    var complexity: Float

    /// Primary frequency parameter for oscillating materials
    var frequency: Float

    /// Primary amplitude parameter for oscillating materials
    var amplitude: Float

    // MARK: - Modulated Values (written by VisualModulationMatrix)

    /// Accumulated modulation offsets keyed by destination name.
    /// Applied additively on top of base parameter values during rendering.
    var modulationOffsets: [String: Float]

    // MARK: - Initialization

    /// Create a new visual layer with sensible defaults.
    ///
    /// - Parameters:
    ///   - name: Display name for the layer
    ///   - material: Initial shader material
    ///   - blendMode: Compositing blend mode
    ///   - opacity: Initial opacity
    init(
        name: String = "Layer",
        material: VisualMaterialType = .liquidLight,
        blendMode: CompositorBlendMode = .normal,
        opacity: Float = 1.0
    ) {
        self.id = UUID()
        self.name = name
        self.material = material
        self.blendMode = blendMode
        self.opacity = opacity
        self.isEnabled = true
        self.isSolo = false
        self.midiChannel = 0
        self.rotation = 0
        self.scale = 1.0
        self.positionX = 0
        self.positionY = 0
        self.hueShift = 0
        self.saturationMultiplier = 1.0
        self.brightnessOffset = 0
        self.speed = 1.0
        self.complexity = 0.5
        self.frequency = 1.0
        self.amplitude = 1.0
        self.modulationOffsets = [:]
    }

    // MARK: - Effective Values

    /// Effective opacity after applying modulation offset, clamped to 0-1
    var effectiveOpacity: Float {
        let offset = modulationOffsets["opacity"] ?? 0
        return Swift.max(0, Swift.min(1, opacity + offset))
    }

    /// Effective rotation after applying modulation offset
    var effectiveRotation: Float {
        rotation + (modulationOffsets["rotation"] ?? 0)
    }

    /// Effective scale after applying modulation offset, clamped >= 0.01
    var effectiveScale: Float {
        Swift.max(0.01, scale + (modulationOffsets["scale"] ?? 0))
    }

    /// Effective horizontal position after modulation
    var effectivePositionX: Float {
        Swift.max(-1, Swift.min(1, positionX + (modulationOffsets["positionX"] ?? 0)))
    }

    /// Effective vertical position after modulation
    var effectivePositionY: Float {
        Swift.max(-1, Swift.min(1, positionY + (modulationOffsets["positionY"] ?? 0)))
    }

    /// Effective hue shift after modulation (wraps 0-1)
    var effectiveHueShift: Float {
        var h = hueShift + (modulationOffsets["hue"] ?? 0)
        h = h - Float(Int(h)) // fmod-like wrap
        if h < 0 { h += 1 }
        return h
    }

    /// Effective saturation multiplier after modulation
    var effectiveSaturation: Float {
        Swift.max(0, saturationMultiplier + (modulationOffsets["saturation"] ?? 0))
    }

    /// Effective brightness offset after modulation
    var effectiveBrightness: Float {
        Swift.max(-1, Swift.min(1, brightnessOffset + (modulationOffsets["brightness"] ?? 0)))
    }

    /// Effective speed after modulation
    var effectiveSpeed: Float {
        Swift.max(0, speed + (modulationOffsets["speed"] ?? 0))
    }

    /// Effective complexity after modulation, clamped to 0-1
    var effectiveComplexity: Float {
        Swift.max(0, Swift.min(1, complexity + (modulationOffsets["complexity"] ?? 0)))
    }

    /// Effective frequency after modulation
    var effectiveFrequency: Float {
        Swift.max(0.001, frequency + (modulationOffsets["frequency"] ?? 0))
    }

    /// Effective amplitude after modulation
    var effectiveAmplitude: Float {
        Swift.max(0, amplitude + (modulationOffsets["amplitude"] ?? 0))
    }

    // MARK: - Equatable

    static func == (lhs: CompositorVisualLayer, rhs: CompositorVisualLayer) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Bio-Reactive Snapshot

/// A snapshot of all bio-reactive input signals fed into the compositor
/// each frame. These values propagate to every enabled layer and the
/// modulation matrix simultaneously.
struct BioReactiveSnapshot: Sendable {
    /// HRV coherence (0-1 normalized)
    var coherence: Float = 0.5

    /// Heart rate in BPM
    var heartRate: Float = 72

    /// Breathing cycle phase (0-1)
    var breathPhase: Float = 0

    /// Overall audio RMS level (0-1)
    var audioLevel: Float = 0

    /// FFT spectrum data (64 bands)
    var spectrumData: [Float] = []

    /// Waveform sample buffer (256 samples)
    var waveformData: [Float] = []

    /// Whether a beat was detected this frame
    var beatDetected: Bool = false

    /// Current detected BPM
    var tempo: Float = 120

    /// Beat phase (0-1 within current beat)
    var beatPhase: Float = 0

    /// Dominant audio frequency in Hz
    var dominantFrequency: Float = 0
}

// MARK: - Compositor Frame Output

/// Per-frame output describing how each layer should be rendered.
/// Consumed by the Metal rendering pipeline (MetalShaderManager)
/// or the SwiftUI Canvas fallback renderer.
struct CompositorFrameOutput {
    /// Ordered list of layer render descriptors (bottom to top)
    let layerDescriptors: [LayerRenderDescriptor]

    /// Background layer descriptor (rendered first)
    let backgroundDescriptor: LayerRenderDescriptor?

    /// Master opacity applied to the final composite
    let masterOpacity: Float

    /// Current animation time in seconds
    let time: Double

    /// Describes how to render a single layer
    struct LayerRenderDescriptor {
        let layerID: UUID
        let material: VisualMaterialType
        let blendMode: CompositorBlendMode
        let opacity: Float
        let rotation: Float
        let scale: Float
        let positionX: Float
        let positionY: Float
        let hueShift: Float
        let saturation: Float
        let brightness: Float
        let speed: Float
        let complexity: Float
        let frequency: Float
        let amplitude: Float
        let bioSnapshot: BioReactiveSnapshot
    }
}

// MARK: - Echoel Visual Compositor

/// Professional 8-layer bio-reactive visual compositor.
///
/// Manages a stack of ``CompositorVisualLayer`` instances, each with its own
/// shader material, blend mode, opacity, transform, and modulation
/// routing. Bio-reactive parameters (coherence, heart rate, breathing,
/// audio level) flow into every layer at 60 Hz.
///
/// ## Architecture
///
/// ```
/// Bio/Audio Sources ──> BioReactiveSnapshot
///                              │
///       ┌──────────────────────┼──────────────────────┐
///       ▼                      ▼                      ▼
///   Background          8 Visual Layers        Modulation Matrix
///       │               (bottom → top)              │
///       └──────────────────────┬──────────────────────┘
///                              ▼
///                   CompositorFrameOutput
///                              │
///                    MetalShaderManager (GPU)
/// ```
///
/// ## Usage
///
/// ```swift
/// let compositor = EchoelVisualCompositor()
/// compositor.start()
/// compositor.addLayer(name: "Base", material: .liquidLight)
/// compositor.addLayer(name: "Overlay", material: .particles, blendMode: .additive)
/// ```
@MainActor
class EchoelVisualCompositor: ObservableObject {

    // MARK: - Published State

    /// The 8 visual layers (bottom to top render order)
    @Published var layers: [CompositorVisualLayer] = []

    /// The background layer (rendered behind all other layers)
    @Published var backgroundLayer: CompositorVisualLayer

    /// Master opacity applied to the final composite (0-1)
    @Published var masterOpacity: Float = 1.0

    /// Whether the compositor update loop is running
    @Published private(set) var isRunning: Bool = false

    /// Current bio-reactive snapshot (updated each frame)
    @Published private(set) var bioSnapshot = BioReactiveSnapshot()

    /// Current animation time in seconds since start
    @Published private(set) var animationTime: Double = 0

    /// Current effective frames per second
    @Published private(set) var currentFPS: Double = 0

    /// Latest compositor frame output for the rendering pipeline
    @Published private(set) var currentFrameOutput: CompositorFrameOutput?

    // MARK: - Configuration

    /// Maximum number of visual layers (8)
    static let maxLayerCount: Int = 8

    /// Target update rate in Hz
    static let targetUpdateRate: Double = 60.0

    // MARK: - Adaptive Performance

    /// Current effective quality tier (from AdaptiveQualityManager)
    @Published private(set) var effectiveQualityTier: String = "High"

    /// Maximum active layers based on quality tier and thermal state
    var effectiveMaxLayers: Int {
        switch effectiveQualityTier {
        case "Minimal": return 2
        case "Niedrig": return 3
        case "Mittel": return 5
        case "Ultra": return 8
        default: return 8 // High
        }
    }

    /// Texture resolution scale factor (0.25 - 1.0)
    private(set) var textureScale: Float = 1.0

    /// Frame budget monitor for adaptive throttling
    private var frameBudgetMonitor = FrameBudgetMonitor(targetHz: 60.0)

    /// Optional adaptive quality manager for battery/thermal-aware rendering.
    /// Inject via ``connectAdaptiveQuality(_:)`` after initialization.
    var adaptiveQualityManager: AdaptiveQualityManager?

    /// Connect an adaptive quality manager for battery/thermal-aware rendering.
    func connectAdaptiveQuality(_ manager: AdaptiveQualityManager) {
        self.adaptiveQualityManager = manager
        adaptToQualityLevel(manager.currentQuality)
    }

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: AnyCancellable?
    private var displayLinkToken: CrossPlatformDisplayLink.Token?
    private var startTime: Date = Date()
    private var lastFrameTime: Date = Date()
    private var frameCount: Int = 0
    private var fpsAccumulator: Double = 0
    private var fpsUpdateInterval: Double = 0.5
    private var lastFPSUpdate: Date = Date()

    // MARK: - Initialization

    /// Create a new visual compositor with an empty layer stack.
    ///
    /// The background layer defaults to ``VisualMaterialType/nebula``
    /// at full opacity with normal blend mode.
    init() {
        self.backgroundLayer = CompositorVisualLayer(
            name: "Background",
            material: .nebula,
            blendMode: .normal,
            opacity: 1.0
        )

        log.log(.info, category: .video, "EchoelVisualCompositor initialized")
    }

    // MARK: - Lifecycle

    /// Start the compositor update loop using CrossPlatformDisplayLink.
    ///
    /// Uses the system display link for frame-accurate timing instead of
    /// a Timer. Subscribes to ``AdaptiveQualityManager`` for battery-aware
    /// quality scaling and thermal throttling.
    func start() {
        guard !isRunning else { return }

        startTime = Date()
        lastFrameTime = Date()
        lastFPSUpdate = Date()
        frameCount = 0
        isRunning = true

        // Use CrossPlatformDisplayLink for frame-accurate timing
        displayLinkToken = CrossPlatformDisplayLink.shared.subscribe { [weak self] timestamp, duration in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }

        // Subscribe to adaptive quality changes (if manager is injected)
        adaptiveQualityManager?.$currentQuality
            .receive(on: DispatchQueue.main)
            .sink { [weak self] quality in
                self?.adaptToQualityLevel(quality)
            }
            .store(in: &cancellables)

        log.log(.info, category: .video, "EchoelVisualCompositor started (DisplayLink + AdaptiveQuality)")
    }

    /// Stop the compositor update loop.
    ///
    /// Halts rendering. The current layer state is preserved and can be
    /// resumed by calling ``start()`` again.
    func stop() {
        guard isRunning else { return }

        if let token = displayLinkToken {
            CrossPlatformDisplayLink.shared.unsubscribe(token)
            displayLinkToken = nil
        }
        updateTimer?.cancel()
        updateTimer = nil
        cancellables.removeAll()
        isRunning = false

        log.log(.info, category: .video, "EchoelVisualCompositor stopped")
    }

    /// Adapt compositor parameters to the current quality level.
    ///
    /// Called when ``AdaptiveQualityManager`` changes quality tier.
    /// Adjusts texture resolution, active layer count, and effect
    /// complexity to maintain frame budget on weaker devices or
    /// when thermal state is elevated.
    private func adaptToQualityLevel(_ quality: AdaptiveQualityManager.QualityLevel) {
        effectiveQualityTier = quality.rawValue
        textureScale = quality.textureQuality

        // Disable expensive layers when quality drops
        let maxActive = effectiveMaxLayers
        for (index, _) in layers.enumerated() where index >= maxActive {
            layers[index].isEnabled = false
        }

        log.log(.info, category: .video,
            "Compositor adapted to quality '\(quality.rawValue)': maxLayers=\(maxActive), textureScale=\(textureScale)")
    }

    // MARK: - Layer Management

    /// Add a new visual layer to the top of the stack.
    ///
    /// - Parameters:
    ///   - name: Display name for the layer
    ///   - material: Shader material type
    ///   - blendMode: Compositing blend mode
    ///   - opacity: Initial opacity (0-1)
    /// - Returns: The newly created layer, or `nil` if the stack is full.
    @discardableResult
    func addLayer(
        name: String = "Layer",
        material: VisualMaterialType = .liquidLight,
        blendMode: CompositorBlendMode = .normal,
        opacity: Float = 1.0
    ) -> CompositorVisualLayer? {
        guard layers.count < Self.maxLayerCount else {
            log.log(.warning, category: .video,
                     "Cannot add layer: maximum of \(Self.maxLayerCount) layers reached")
            return nil
        }

        let layerName = name == "Layer" ? "Layer \(layers.count + 1)" : name
        let layer = CompositorVisualLayer(
            name: layerName,
            material: material,
            blendMode: blendMode,
            opacity: opacity
        )
        layers.append(layer)

        log.log(.info, category: .video,
                 "Added layer '\(layerName)' [\(material.rawValue), \(blendMode.displayName)]")
        return layer
    }

    /// Remove a layer by its unique identifier.
    ///
    /// - Parameter id: The UUID of the layer to remove.
    /// - Returns: `true` if the layer was found and removed.
    @discardableResult
    func removeLayer(id: UUID) -> Bool {
        guard let index = layers.firstIndex(where: { $0.id == id }) else {
            log.log(.warning, category: .video,
                     "Cannot remove layer: ID \(id) not found")
            return false
        }

        let removed = layers.remove(at: index)
        log.log(.info, category: .video, "Removed layer '\(removed.name)'")
        return true
    }

    /// Move a layer from one position to another in the stack.
    ///
    /// - Parameters:
    ///   - fromIndex: Current index of the layer
    ///   - toIndex: Desired destination index
    func moveLayer(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex >= 0, fromIndex < layers.count,
              toIndex >= 0, toIndex < layers.count,
              fromIndex != toIndex else {
            return
        }

        let layer = layers.remove(at: fromIndex)
        layers.insert(layer, at: toIndex)

        log.log(.debug, category: .video,
                 "Moved layer '\(layer.name)' from index \(fromIndex) to \(toIndex)")
    }

    /// Swap two layers by index.
    ///
    /// - Parameters:
    ///   - indexA: First layer index
    ///   - indexB: Second layer index
    func swapLayers(_ indexA: Int, _ indexB: Int) {
        guard indexA >= 0, indexA < layers.count,
              indexB >= 0, indexB < layers.count,
              indexA != indexB else {
            return
        }

        layers.swapAt(indexA, indexB)
    }

    /// Duplicate an existing layer and insert the copy directly above it.
    ///
    /// - Parameter id: UUID of the layer to duplicate.
    /// - Returns: The duplicated layer, or `nil` if the stack is full or the
    ///   source layer was not found.
    @discardableResult
    func duplicateLayer(id: UUID) -> CompositorVisualLayer? {
        guard layers.count < Self.maxLayerCount else {
            log.log(.warning, category: .video,
                     "Cannot duplicate: maximum layer count reached")
            return nil
        }
        guard let index = layers.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let source = layers[index]
        var copy = CompositorVisualLayer(
            name: source.name + " Copy",
            material: source.material,
            blendMode: source.blendMode,
            opacity: source.opacity
        )
        copy.isEnabled = source.isEnabled
        copy.midiChannel = source.midiChannel
        copy.rotation = source.rotation
        copy.scale = source.scale
        copy.positionX = source.positionX
        copy.positionY = source.positionY
        copy.hueShift = source.hueShift
        copy.saturationMultiplier = source.saturationMultiplier
        copy.brightnessOffset = source.brightnessOffset
        copy.speed = source.speed
        copy.complexity = source.complexity
        copy.frequency = source.frequency
        copy.amplitude = source.amplitude

        layers.insert(copy, at: index + 1)
        return copy
    }

    // MARK: - Layer Property Setters

    /// Set the shader material for a layer.
    ///
    /// - Parameters:
    ///   - material: The new material type
    ///   - layerID: UUID of the target layer
    func setMaterial(_ material: VisualMaterialType, for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].material = material
    }

    /// Set the blend mode for a layer.
    ///
    /// - Parameters:
    ///   - blendMode: The new blend mode
    ///   - layerID: UUID of the target layer
    func setBlendMode(_ blendMode: CompositorBlendMode, for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].blendMode = blendMode
    }

    /// Set the opacity for a layer.
    ///
    /// - Parameters:
    ///   - opacity: Opacity value (0-1, clamped)
    ///   - layerID: UUID of the target layer
    func setOpacity(_ opacity: Float, for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].opacity = Swift.max(0, Swift.min(1, opacity))
    }

    /// Set the enabled state for a layer.
    ///
    /// - Parameters:
    ///   - enabled: Whether the layer should render
    ///   - layerID: UUID of the target layer
    func setEnabled(_ enabled: Bool, for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].isEnabled = enabled
    }

    /// Set the solo state for a layer.
    ///
    /// When any layer is solo'd, only solo'd layers render.
    ///
    /// - Parameters:
    ///   - solo: Whether to solo this layer
    ///   - layerID: UUID of the target layer
    func setSolo(_ solo: Bool, for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].isSolo = solo
    }

    /// Set the MIDI channel for a layer.
    ///
    /// - Parameters:
    ///   - channel: MIDI channel (0 = omni, 1-16 for specific channel)
    ///   - layerID: UUID of the target layer
    func setMIDIChannel(_ channel: UInt8, for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].midiChannel = Swift.min(channel, 16)
    }

    /// Set the transform parameters for a layer.
    ///
    /// - Parameters:
    ///   - rotation: Rotation in radians
    ///   - scale: Uniform scale factor
    ///   - positionX: Horizontal offset (-1 to +1)
    ///   - positionY: Vertical offset (-1 to +1)
    ///   - layerID: UUID of the target layer
    func setTransform(
        rotation: Float? = nil,
        scale: Float? = nil,
        positionX: Float? = nil,
        positionY: Float? = nil,
        for layerID: UUID
    ) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        if let r = rotation { layers[index].rotation = r }
        if let s = scale { layers[index].scale = Swift.max(0.01, s) }
        if let x = positionX { layers[index].positionX = Swift.max(-1, Swift.min(1, x)) }
        if let y = positionY { layers[index].positionY = Swift.max(-1, Swift.min(1, y)) }
    }

    /// Set shader-specific parameters for a layer.
    ///
    /// - Parameters:
    ///   - speed: Animation speed multiplier
    ///   - complexity: Detail level (0-1)
    ///   - frequency: Primary oscillation frequency
    ///   - amplitude: Primary oscillation amplitude
    ///   - layerID: UUID of the target layer
    func setShaderParams(
        speed: Float? = nil,
        complexity: Float? = nil,
        frequency: Float? = nil,
        amplitude: Float? = nil,
        for layerID: UUID
    ) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        if let s = speed { layers[index].speed = Swift.max(0, s) }
        if let c = complexity { layers[index].complexity = Swift.max(0, Swift.min(1, c)) }
        if let f = frequency { layers[index].frequency = Swift.max(0.001, f) }
        if let a = amplitude { layers[index].amplitude = Swift.max(0, a) }
    }

    /// Set color adjustment parameters for a layer.
    ///
    /// - Parameters:
    ///   - hueShift: Hue rotation (0-1, wraps)
    ///   - saturation: Saturation multiplier
    ///   - brightness: Brightness offset (-1 to +1)
    ///   - layerID: UUID of the target layer
    func setColorAdjustment(
        hueShift: Float? = nil,
        saturation: Float? = nil,
        brightness: Float? = nil,
        for layerID: UUID
    ) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        if let h = hueShift {
            var wrapped = h - Float(Int(h))
            if wrapped < 0 { wrapped += 1 }
            layers[index].hueShift = wrapped
        }
        if let s = saturation { layers[index].saturationMultiplier = Swift.max(0, s) }
        if let b = brightness { layers[index].brightnessOffset = Swift.max(-1, Swift.min(1, b)) }
    }

    // MARK: - Bio-Reactive Input

    /// Update the bio-reactive snapshot with current biometric data.
    ///
    /// Called externally by UnifiedControlHub or EchoelCreativeWorkspace
    /// at up to 60 Hz.
    ///
    /// - Parameters:
    ///   - coherence: Normalized HRV coherence (0-1)
    ///   - heartRate: Heart rate in BPM
    ///   - breathPhase: Breathing cycle phase (0-1)
    ///   - audioLevel: Audio RMS level (0-1)
    func updateBioData(
        coherence: Float,
        heartRate: Float,
        breathPhase: Float,
        audioLevel: Float
    ) {
        bioSnapshot.coherence = Swift.max(0, Swift.min(1, coherence))
        bioSnapshot.heartRate = heartRate
        bioSnapshot.breathPhase = Swift.max(0, Swift.min(1, breathPhase))
        bioSnapshot.audioLevel = Swift.max(0, Swift.min(1, audioLevel))
    }

    /// Update the audio analysis data from UnifiedVisualSoundEngine.
    ///
    /// - Parameters:
    ///   - spectrumData: FFT spectrum data (64 bands)
    ///   - waveformData: Raw waveform sample buffer (256 samples)
    ///   - beatDetected: Whether a beat onset was detected this frame
    ///   - tempo: Detected tempo in BPM
    ///   - beatPhase: Phase within the current beat (0-1)
    ///   - dominantFrequency: Dominant spectral frequency in Hz
    func updateAudioAnalysis(
        spectrumData: [Float],
        waveformData: [Float],
        beatDetected: Bool,
        tempo: Float = 120,
        beatPhase: Float = 0,
        dominantFrequency: Float = 0
    ) {
        bioSnapshot.spectrumData = spectrumData
        bioSnapshot.waveformData = waveformData
        bioSnapshot.beatDetected = beatDetected
        bioSnapshot.tempo = tempo
        bioSnapshot.beatPhase = beatPhase
        bioSnapshot.dominantFrequency = dominantFrequency
    }

    /// Update bio-reactive data from a ``TypeSafeBioData`` struct.
    ///
    /// Convenience method for integration with the ``BioReactiveRegistry``.
    ///
    /// - Parameter bioData: Type-safe bio data from the HealthKit pipeline
    func updateFromTypeSafeBioData(_ bioData: TypeSafeBioData) {
        bioSnapshot.coherence = bioData.normalizedCoherence.floatValue
        bioSnapshot.heartRate = bioData.heartRate
        bioSnapshot.breathPhase = bioData.breathPhase
    }

    // MARK: - Modulation Integration

    /// Apply modulation offsets to a specific layer.
    ///
    /// Called by ``VisualModulationMatrix`` each frame after evaluating
    /// all modulation routes for this layer.
    ///
    /// - Parameters:
    ///   - offsets: Dictionary of destination name to modulation offset value
    ///   - layerID: UUID of the target layer
    func applyModulationOffsets(_ offsets: [String: Float], for layerID: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == layerID }) else { return }
        layers[index].modulationOffsets = offsets
    }

    /// Clear all modulation offsets for all layers.
    func clearAllModulation() {
        for i in layers.indices {
            layers[i].modulationOffsets = [:]
        }
        backgroundLayer.modulationOffsets = [:]
    }

    // MARK: - Preset Management

    /// Reset all layers to default state.
    func resetToDefault() {
        layers.removeAll()
        backgroundLayer = CompositorVisualLayer(
            name: "Background",
            material: .nebula,
            blendMode: .normal,
            opacity: 1.0
        )
        masterOpacity = 1.0
        log.log(.info, category: .video, "Compositor reset to default")
    }

    /// Apply a built-in compositor preset.
    ///
    /// - Parameter preset: The preset configuration to apply
    func applyPreset(_ preset: CompositorPreset) {
        resetToDefault()

        switch preset {
        case .meditation:
            backgroundLayer.material = .nebula
            backgroundLayer.speed = 0.3
            addLayer(name: "Mandala", material: .mandala, blendMode: .additive, opacity: 0.6)
            addLayer(name: "Particles", material: .particles, blendMode: .screen, opacity: 0.3)

        case .performance:
            backgroundLayer.material = .liquidLight
            addLayer(name: "Spectrum", material: .spectrum, blendMode: .additive, opacity: 0.8)
            addLayer(name: "Cymatics", material: .cymatics, blendMode: .screen, opacity: 0.5)
            addLayer(name: "Particles", material: .particles, blendMode: .additive, opacity: 0.4)

        case .psychedelic:
            backgroundLayer.material = .fractalZoom
            backgroundLayer.speed = 0.5
            addLayer(name: "Kaleidoscope", material: .kaleidoscope, blendMode: .overlay, opacity: 0.7)
            addLayer(name: "Plasma", material: .plasmaWave, blendMode: .screen, opacity: 0.5)
            addLayer(name: "Sacred", material: .sacredGeometry, blendMode: .additive, opacity: 0.3)
            addLayer(name: "Flow Field", material: .flowField, blendMode: .softLight, opacity: 0.4)

        case .ambient:
            backgroundLayer.material = .auroraField
            backgroundLayer.speed = 0.2
            addLayer(name: "Ocean", material: .oceanWaves, blendMode: .softLight, opacity: 0.4)
            addLayer(name: "Crystal", material: .crystalFormation, blendMode: .screen, opacity: 0.3)

        case .dataVisualization:
            backgroundLayer.material = .dataStream
            backgroundLayer.opacity = 0.5
            addLayer(name: "Voronoi", material: .voronoiMesh, blendMode: .additive, opacity: 0.6)
            addLayer(name: "Electric", material: .electricField, blendMode: .screen, opacity: 0.4)
            addLayer(name: "Tunnel", material: .tunnelEffect, blendMode: .overlay, opacity: 0.3)

        case .bioReactive:
            backgroundLayer.material = .liquidLight
            addLayer(name: "Cymatics", material: .cymatics, blendMode: .additive, opacity: 0.7)
            addLayer(name: "Aurora", material: .auroraField, blendMode: .screen, opacity: 0.4)
            addLayer(name: "Reaction", material: .reactionDiffusion, blendMode: .softLight, opacity: 0.3)
            addLayer(name: "Morph", material: .morphingBlob, blendMode: .overlay, opacity: 0.25)
        }

        log.log(.info, category: .video, "Applied compositor preset: \(preset.rawValue)")
    }

    // MARK: - Frame Compositing

    /// Generate the current frame's compositor output.
    ///
    /// Evaluates which layers should render (considering enabled/solo state),
    /// resolves effective parameter values (base + modulation), and builds
    /// an ordered array of ``CompositorFrameOutput/LayerRenderDescriptor``
    /// structs for the GPU rendering pipeline.
    ///
    /// - Returns: A ``CompositorFrameOutput`` describing the complete frame.
    func buildFrameOutput() -> CompositorFrameOutput {
        let hasSoloLayers = layers.contains { $0.isSolo }

        // Filter visible layers
        let visibleLayers = layers.filter { layer in
            guard layer.isEnabled else { return false }
            if hasSoloLayers { return layer.isSolo }
            return true
        }

        // Build descriptors
        let descriptors = visibleLayers.map { layer -> CompositorFrameOutput.LayerRenderDescriptor in
            CompositorFrameOutput.LayerRenderDescriptor(
                layerID: layer.id,
                material: layer.material,
                blendMode: layer.blendMode,
                opacity: layer.effectiveOpacity,
                rotation: layer.effectiveRotation,
                scale: layer.effectiveScale,
                positionX: layer.effectivePositionX,
                positionY: layer.effectivePositionY,
                hueShift: layer.effectiveHueShift,
                saturation: layer.effectiveSaturation,
                brightness: layer.effectiveBrightness,
                speed: layer.effectiveSpeed,
                complexity: layer.effectiveComplexity,
                frequency: layer.effectiveFrequency,
                amplitude: layer.effectiveAmplitude,
                bioSnapshot: bioSnapshot
            )
        }

        // Build background descriptor
        let bgDescriptor: CompositorFrameOutput.LayerRenderDescriptor? = backgroundLayer.isEnabled
            ? CompositorFrameOutput.LayerRenderDescriptor(
                layerID: backgroundLayer.id,
                material: backgroundLayer.material,
                blendMode: backgroundLayer.blendMode,
                opacity: backgroundLayer.effectiveOpacity,
                rotation: backgroundLayer.effectiveRotation,
                scale: backgroundLayer.effectiveScale,
                positionX: backgroundLayer.effectivePositionX,
                positionY: backgroundLayer.effectivePositionY,
                hueShift: backgroundLayer.effectiveHueShift,
                saturation: backgroundLayer.effectiveSaturation,
                brightness: backgroundLayer.effectiveBrightness,
                speed: backgroundLayer.effectiveSpeed,
                complexity: backgroundLayer.effectiveComplexity,
                frequency: backgroundLayer.effectiveFrequency,
                amplitude: backgroundLayer.effectiveAmplitude,
                bioSnapshot: bioSnapshot
            )
            : nil

        return CompositorFrameOutput(
            layerDescriptors: descriptors,
            backgroundDescriptor: bgDescriptor,
            masterOpacity: masterOpacity,
            time: animationTime
        )
    }

    // MARK: - Update Loop

    /// The core 60 Hz tick. Advances animation time, updates FPS counter,
    /// and builds the frame output for the rendering pipeline.
    private func tick() {
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastFrameTime)
        lastFrameTime = now
        animationTime = now.timeIntervalSince(startTime)

        // FPS calculation
        frameCount += 1
        fpsAccumulator += deltaTime
        let timeSinceFPSUpdate = now.timeIntervalSince(lastFPSUpdate)
        if timeSinceFPSUpdate >= fpsUpdateInterval {
            currentFPS = Double(frameCount) / timeSinceFPSUpdate
            frameCount = 0
            lastFPSUpdate = now
        }

        // Build and publish frame output
        currentFrameOutput = buildFrameOutput()
    }

    // MARK: - Query

    /// Get a layer by its UUID.
    ///
    /// - Parameter id: The layer's unique identifier.
    /// - Returns: The layer if found, otherwise `nil`.
    func layer(for id: UUID) -> CompositorVisualLayer? {
        layers.first { $0.id == id }
    }

    /// Get a layer by its index in the stack.
    ///
    /// - Parameter index: Zero-based index (0 = bottom).
    /// - Returns: The layer if the index is valid, otherwise `nil`.
    func layer(at index: Int) -> CompositorVisualLayer? {
        guard index >= 0, index < layers.count else { return nil }
        return layers[index]
    }

    /// The number of currently enabled layers.
    var enabledLayerCount: Int {
        layers.filter(\.isEnabled).count
    }

    // MARK: - Debug

    /// Multi-line debug summary of the compositor state.
    var debugDescription: String {
        var lines: [String] = []
        lines.append("EchoelVisualCompositor (\(isRunning ? "running" : "stopped"))")
        lines.append("  FPS: \(String(format: "%.1f", currentFPS)) / \(Int(Self.targetUpdateRate))")
        lines.append("  Master Opacity: \(String(format: "%.2f", masterOpacity))")
        lines.append("  Animation Time: \(String(format: "%.1f", animationTime))s")
        lines.append("  Background: \(backgroundLayer.material.rawValue) (\(backgroundLayer.isEnabled ? "on" : "off"))")
        lines.append("  Layers (\(layers.count)/\(Self.maxLayerCount)):")
        for (i, layer) in layers.enumerated() {
            let status = layer.isEnabled ? (layer.isSolo ? "SOLO" : "on") : "off"
            let modCount = layer.modulationOffsets.count
            lines.append("    [\(i)] \(layer.name): \(layer.material.rawValue) | "
                       + "\(layer.blendMode.displayName) | "
                       + "opacity=\(String(format: "%.2f", layer.effectiveOpacity)) | "
                       + "[\(status)] "
                       + (modCount > 0 ? "| \(modCount) mod routes" : ""))
        }
        lines.append("  Bio: coherence=\(String(format: "%.2f", bioSnapshot.coherence)) "
                    + "HR=\(String(format: "%.0f", bioSnapshot.heartRate)) "
                    + "breath=\(String(format: "%.2f", bioSnapshot.breathPhase)) "
                    + "audio=\(String(format: "%.2f", bioSnapshot.audioLevel))")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Compositor Preset

/// Built-in compositor presets that configure layer stacks for
/// common use cases.
enum CompositorPreset: String, CaseIterable, Identifiable {
    case meditation = "Meditation"
    case performance = "Performance"
    case psychedelic = "Psychedelic"
    case ambient = "Ambient"
    case dataVisualization = "Data Visualization"
    case bioReactive = "Bio-Reactive"

    var id: String { rawValue }

    /// Short description of the preset
    var description: String {
        switch self {
        case .meditation:        return "Calm, slow-moving mandala and particles"
        case .performance:       return "Audio-reactive spectrum and cymatics"
        case .psychedelic:       return "Complex layered fractals and kaleidoscope"
        case .ambient:           return "Gentle aurora and ocean atmosphere"
        case .dataVisualization: return "Tech-inspired data stream and voronoi"
        case .bioReactive:       return "Full bio-reactive multi-layer experience"
        }
    }
}
