// Intelligent360VisualEngine.swift
// Echoelmusic - Intelligent 360° Multidimensional Visual System
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
// MARK: - 360° Visual Dimensions
//==============================================================================

/// Supported visual dimensions
public enum VisualDimension: Int, CaseIterable, Identifiable, Sendable {
    case two = 2           // 2D - Flat plane
    case three = 3         // 3D - Spatial volume
    case four = 4          // 4D - Time-based volumetric
    case five = 5          // 5D - Probability/quantum field
    case six = 6           // 6D - Bio-coherence manifold

    public var id: Int { rawValue }

    public var name: String {
        switch self {
        case .two: return "2D Plane"
        case .three: return "3D Spatial"
        case .four: return "4D Temporal"
        case .five: return "5D Quantum Field"
        case .six: return "6D Bio-Coherence Manifold"
        }
    }

    public var description: String {
        switch self {
        case .two: return "Classic flat visualization"
        case .three: return "Full 360° spatial environment"
        case .four: return "Time-evolving volumetric display"
        case .five: return "Quantum probability cloud"
        case .six: return "HRV-coherence dimensional mapping"
        }
    }
}

//==============================================================================
// MARK: - 360° Projection Modes
//==============================================================================

/// 360° projection mapping modes
public enum ProjectionMode360: String, CaseIterable, Identifiable, Sendable {
    case equirectangular = "equirectangular"
    case cubemap = "cubemap"
    case fisheye = "fisheye"
    case domemaster = "domemaster"
    case cylindrical = "cylindrical"
    case stereoscopic = "stereoscopic"
    case ambisonic = "ambisonic"
    case holographic = "holographic"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .equirectangular: return "Equirectangular 360°"
        case .cubemap: return "Cubemap 6-Face"
        case .fisheye: return "Fisheye Dome"
        case .domemaster: return "Planetarium Domemaster"
        case .cylindrical: return "Cylindrical Panorama"
        case .stereoscopic: return "Stereoscopic 3D"
        case .ambisonic: return "Ambisonic Audio-Visual"
        case .holographic: return "Holographic Light Field"
        }
    }

    public var fieldOfView: Double {
        switch self {
        case .equirectangular: return 360.0
        case .cubemap: return 360.0
        case .fisheye: return 180.0
        case .domemaster: return 180.0
        case .cylindrical: return 360.0
        case .stereoscopic: return 180.0
        case .ambisonic: return 360.0
        case .holographic: return 360.0
        }
    }
}

//==============================================================================
// MARK: - Intelligent Visual Modes
//==============================================================================

/// AI-driven intelligent visual generation modes
public enum IntelligentVisualMode: String, CaseIterable, Identifiable, Sendable {
    // Geometric
    case sacredGeometry = "sacred_geometry"
    case fractalMandala = "fractal_mandala"
    case platonic = "platonic"
    case hypercube = "hypercube"
    case toroidal = "toroidal"

    // Organic
    case bioMorphic = "bio_morphic"
    case cellularAutomata = "cellular_automata"
    case neuralNetwork = "neural_network"
    case flowField = "flow_field"
    case particleLife = "particle_life"

    // Quantum
    case quantumWave = "quantum_wave"
    case coherenceField = "coherence_field"
    case entanglementWeb = "entanglement_web"
    case probabilityCloud = "probability_cloud"
    case waveFunctionCollapse = "wave_function_collapse"

    // Audio-Reactive
    case spectrumRings = "spectrum_rings"
    case waveformSphere = "waveform_sphere"
    case frequencyLandscape = "frequency_landscape"
    case harmonicOrbitals = "harmonic_orbitals"
    case rhythmicPulse = "rhythmic_pulse"

    // Atmospheric
    case cosmicNebula = "cosmic_nebula"
    case auroraField = "aurora_field"
    case crystalCave = "crystal_cave"
    case underwaterCaustics = "underwater_caustics"
    case fireEmbers = "fire_embers"

    // Abstract
    case glitchMatrix = "glitch_matrix"
    case dataStream = "data_stream"
    case noiseField = "noise_field"
    case voronoiMesh = "voronoi_mesh"
    case rayMarch = "ray_march"

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    public var category: String {
        switch self {
        case .sacredGeometry, .fractalMandala, .platonic, .hypercube, .toroidal:
            return "Geometric"
        case .bioMorphic, .cellularAutomata, .neuralNetwork, .flowField, .particleLife:
            return "Organic"
        case .quantumWave, .coherenceField, .entanglementWeb, .probabilityCloud, .waveFunctionCollapse:
            return "Quantum"
        case .spectrumRings, .waveformSphere, .frequencyLandscape, .harmonicOrbitals, .rhythmicPulse:
            return "Audio-Reactive"
        case .cosmicNebula, .auroraField, .crystalCave, .underwaterCaustics, .fireEmbers:
            return "Atmospheric"
        case .glitchMatrix, .dataStream, .noiseField, .voronoiMesh, .rayMarch:
            return "Abstract"
        }
    }
}

//==============================================================================
// MARK: - Visual Layer
//==============================================================================

/// A visual layer in the multidimensional composition
public struct VisualLayer: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var mode: IntelligentVisualMode
    public var opacity: Double
    public var blendMode: VisualBlendMode
    public var scale: Double
    public var rotation: SIMD3<Double>
    public var position: SIMD3<Double>
    public var isEnabled: Bool
    public var isBioReactive: Bool
    public var bioReactivityAmount: Double

    public init(
        id: UUID = UUID(),
        name: String = "Layer",
        mode: IntelligentVisualMode = .coherenceField,
        opacity: Double = 1.0,
        blendMode: VisualBlendMode = .normal,
        scale: Double = 1.0,
        rotation: SIMD3<Double> = .zero,
        position: SIMD3<Double> = .zero,
        isEnabled: Bool = true,
        isBioReactive: Bool = true,
        bioReactivityAmount: Double = 1.0
    ) {
        self.id = id
        self.name = name
        self.mode = mode
        self.opacity = opacity
        self.blendMode = blendMode
        self.scale = scale
        self.rotation = rotation
        self.position = position
        self.isEnabled = isEnabled
        self.isBioReactive = isBioReactive
        self.bioReactivityAmount = bioReactivityAmount
    }
}

//==============================================================================
// MARK: - Visual Blend Modes
//==============================================================================

public enum VisualBlendMode: String, CaseIterable, Identifiable, Sendable {
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
    case color
    case luminosity
    case quantumBlend

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }
}

//==============================================================================
// MARK: - 360° Environment
//==============================================================================

/// 360° environment configuration
public struct Environment360: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var projection: ProjectionMode360
    public var resolution: (width: Int, height: Int)
    public var frameRate: Double
    public var skybox: SkyboxType
    public var ambientLight: SIMD3<Float>
    public var fogDensity: Float
    public var bloomIntensity: Float
    public var chromaticAberration: Float

    public init(
        id: UUID = UUID(),
        name: String = "Default Environment",
        projection: ProjectionMode360 = .equirectangular,
        resolution: (width: Int, height: Int) = (4096, 2048),
        frameRate: Double = 60.0,
        skybox: SkyboxType = .cosmic,
        ambientLight: SIMD3<Float> = SIMD3(0.1, 0.1, 0.15),
        fogDensity: Float = 0.0,
        bloomIntensity: Float = 0.3,
        chromaticAberration: Float = 0.0
    ) {
        self.id = id
        self.name = name
        self.projection = projection
        self.resolution = resolution
        self.frameRate = frameRate
        self.skybox = skybox
        self.ambientLight = ambientLight
        self.fogDensity = fogDensity
        self.bloomIntensity = bloomIntensity
        self.chromaticAberration = chromaticAberration
    }
}

public enum SkyboxType: String, CaseIterable, Identifiable, Sendable {
    case none = "none"
    case cosmic = "cosmic"
    case nebula = "nebula"
    case aurora = "aurora"
    case gradient = "gradient"
    case proceduralSky = "procedural_sky"
    case hdri = "hdri"
    case bioReactive = "bio_reactive"

    public var id: String { rawValue }
}

//==============================================================================
// MARK: - Intelligent 360° Visual Engine
//==============================================================================

/// Main engine for intelligent 360° multidimensional visuals
@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
@MainActor
public final class Intelligent360VisualEngine: ObservableObject {

    //==========================================================================
    // MARK: - Published Properties
    //==========================================================================

    @Published public var isRunning: Bool = false
    @Published public var currentDimension: VisualDimension = .three
    @Published public var projectionMode: ProjectionMode360 = .equirectangular
    @Published public var activeMode: IntelligentVisualMode = .coherenceField
    @Published public var layers: [VisualLayer] = []
    @Published public var environment: Environment360 = Environment360()

    // Bio-reactivity
    @Published public var coherence: Double = 0.5
    @Published public var heartRate: Double = 70.0
    @Published public var breathPhase: Double = 0.5
    @Published public var hrvMs: Double = 50.0

    // Audio-reactivity
    @Published public var audioLevel: Double = 0.0
    @Published public var spectrumData: [Float] = Array(repeating: 0, count: 64)
    @Published public var beatDetected: Bool = false
    @Published public var bpm: Double = 120.0

    // Rendering stats
    @Published public var fps: Double = 60.0
    @Published public var renderTime: Double = 0.0
    @Published public var particleCount: Int = 0

    //==========================================================================
    // MARK: - Private Properties
    //==========================================================================

    private var cancellables = Set<AnyCancellable>()
    private var renderTimer: Timer?
    private var lastFrameTime: Date = Date()

    // AI parameters
    private var aiEvolutionRate: Double = 0.1
    private var aiComplexity: Double = 0.5
    private var aiHarmony: Double = 0.8

    // Multidimensional state
    private var dimensionalOffset: SIMD4<Double> = .zero
    private var quantumPhase: Double = 0.0
    private var coherenceHistory: [Double] = []
    private var coherenceHistoryIndex: Int = 0
    private static let coherenceHistoryCapacity = 100

    //==========================================================================
    // MARK: - Initialization
    //==========================================================================

    public init() {
        setupDefaultLayers()
    }

    private func setupDefaultLayers() {
        layers = [
            VisualLayer(
                name: "Background Field",
                mode: .coherenceField,
                opacity: 0.6,
                blendMode: .normal,
                scale: 1.5
            ),
            VisualLayer(
                name: "Sacred Geometry",
                mode: .sacredGeometry,
                opacity: 0.8,
                blendMode: .additive,
                scale: 1.0
            ),
            VisualLayer(
                name: "Particle System",
                mode: .particleLife,
                opacity: 0.5,
                blendMode: .screen,
                scale: 1.0
            )
        ]
    }

    //==========================================================================
    // MARK: - Engine Control
    //==========================================================================

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    public func stop() {
        isRunning = false
        renderTimer?.invalidate()
        renderTimer = nil
    }

    private func tick() {
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastFrameTime)
        lastFrameTime = now

        // Update FPS
        fps = 1.0 / deltaTime

        // Update quantum phase
        quantumPhase += deltaTime * (1.0 + coherence)

        // Update dimensional offset based on bio data
        updateDimensionalState(deltaTime: deltaTime)

        // AI evolution
        evolveVisuals(deltaTime: deltaTime)

        // Track coherence history using circular buffer pattern
        if coherenceHistory.count < Self.coherenceHistoryCapacity {
            coherenceHistory.append(coherence)
        } else {
            coherenceHistory[coherenceHistoryIndex % Self.coherenceHistoryCapacity] = coherence
        }
        coherenceHistoryIndex += 1
    }

    private func updateDimensionalState(deltaTime: Double) {
        // Map bio signals to dimensional coordinates
        dimensionalOffset.x += sin(breathPhase * .pi * 2) * deltaTime * 0.1
        dimensionalOffset.y += cos(quantumPhase) * coherence * deltaTime * 0.1
        dimensionalOffset.z += sin(heartRate / 60.0 * .pi) * deltaTime * 0.05
        dimensionalOffset.w = coherence * hrvMs / 100.0
    }

    private func evolveVisuals(deltaTime: Double) {
        // AI-driven visual evolution based on coherence trends
        let coherenceTrend = calculateCoherenceTrend()

        // Adjust complexity based on HRV
        aiComplexity = 0.3 + (hrvMs / 150.0) * 0.7

        // Adjust harmony based on coherence
        aiHarmony = 0.5 + coherence * 0.5

        // Evolution rate increases with positive coherence trend
        aiEvolutionRate = 0.05 + max(0, coherenceTrend) * 0.15
    }

    private func calculateCoherenceTrend() -> Double {
        let count = coherenceHistory.count
        guard count >= 10 else { return 0 }
        // Calculate in-place without array copies
        var recentSum: Double = 0
        var olderSum: Double = 0
        for i in (count - 10)..<count { recentSum += coherenceHistory[i] }
        for i in 0..<10 { olderSum += coherenceHistory[i] }
        return (recentSum - olderSum) * 0.1  // / 10.0
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

    public func updateAudioData(level: Double, spectrum: [Float], beat: Bool, bpm: Double) {
        self.audioLevel = level
        self.spectrumData = spectrum
        self.beatDetected = beat
        self.bpm = bpm
    }

    //==========================================================================
    // MARK: - Layer Management
    //==========================================================================

    public func addLayer(_ layer: VisualLayer) {
        layers.append(layer)
    }

    public func removeLayer(at index: Int) {
        guard layers.indices.contains(index) else { return }
        layers.remove(at: index)
    }

    public func moveLayer(from source: IndexSet, to destination: Int) {
        layers.move(fromOffsets: source, toOffset: destination)
    }

    //==========================================================================
    // MARK: - Dimension Control
    //==========================================================================

    public func setDimension(_ dimension: VisualDimension) {
        currentDimension = dimension
    }

    public func setProjection(_ projection: ProjectionMode360) {
        projectionMode = projection
    }

    //==========================================================================
    // MARK: - Presets
    //==========================================================================

    public func loadMeditationPreset() {
        currentDimension = .six
        projectionMode = .equirectangular
        activeMode = .coherenceField
        environment = Environment360(
            name: "Deep Meditation",
            projection: .equirectangular,
            skybox: .bioReactive,
            ambientLight: SIMD3(0.05, 0.08, 0.12),
            bloomIntensity: 0.5
        )
        layers = [
            VisualLayer(name: "Coherence Field", mode: .coherenceField, opacity: 0.8),
            VisualLayer(name: "Sacred Geometry", mode: .sacredGeometry, opacity: 0.4, blendMode: .additive),
            VisualLayer(name: "Aurora", mode: .auroraField, opacity: 0.3, blendMode: .screen)
        ]
    }

    public func loadEnergeticPreset() {
        currentDimension = .four
        projectionMode = .stereoscopic
        activeMode = .rhythmicPulse
        environment = Environment360(
            name: "Energy Burst",
            projection: .stereoscopic,
            skybox: .cosmic,
            ambientLight: SIMD3(0.15, 0.1, 0.2),
            bloomIntensity: 0.8
        )
        layers = [
            VisualLayer(name: "Spectrum Rings", mode: .spectrumRings, opacity: 1.0),
            VisualLayer(name: "Particle Life", mode: .particleLife, opacity: 0.7, blendMode: .additive),
            VisualLayer(name: "Glitch Matrix", mode: .glitchMatrix, opacity: 0.3, blendMode: .screen)
        ]
    }

    public func loadCosmicPreset() {
        currentDimension = .five
        projectionMode = .holographic
        activeMode = .cosmicNebula
        environment = Environment360(
            name: "Cosmic Journey",
            projection: .holographic,
            skybox: .nebula,
            ambientLight: SIMD3(0.08, 0.05, 0.15),
            bloomIntensity: 0.6,
            chromaticAberration: 0.1
        )
        layers = [
            VisualLayer(name: "Cosmic Nebula", mode: .cosmicNebula, opacity: 1.0),
            VisualLayer(name: "Quantum Wave", mode: .quantumWave, opacity: 0.5, blendMode: .additive),
            VisualLayer(name: "Entanglement Web", mode: .entanglementWeb, opacity: 0.4, blendMode: .screen)
        ]
    }

    public func loadImmersivePreset() {
        currentDimension = .six
        projectionMode = .domemaster
        activeMode = .bioMorphic
        environment = Environment360(
            name: "Full Immersion",
            projection: .domemaster,
            resolution: (8192, 8192),
            frameRate: 90.0,
            skybox: .proceduralSky,
            fogDensity: 0.05,
            bloomIntensity: 0.4
        )
        layers = [
            VisualLayer(name: "Bio-Morphic", mode: .bioMorphic, opacity: 0.9),
            VisualLayer(name: "Flow Field", mode: .flowField, opacity: 0.6, blendMode: .overlay),
            VisualLayer(name: "Fractal Mandala", mode: .fractalMandala, opacity: 0.3, blendMode: .additive),
            VisualLayer(name: "Probability Cloud", mode: .probabilityCloud, opacity: 0.4, blendMode: .screen)
        ]
    }

    //==========================================================================
    // MARK: - Rendering Data
    //==========================================================================

    /// Get render parameters for current frame
    public func getRenderParameters() -> RenderParameters360 {
        return RenderParameters360(
            dimension: currentDimension,
            projection: projectionMode,
            layers: layers.filter { $0.isEnabled },
            environment: environment,
            coherence: coherence,
            heartRate: heartRate,
            breathPhase: breathPhase,
            hrvMs: hrvMs,
            audioLevel: audioLevel,
            spectrumData: spectrumData,
            beatDetected: beatDetected,
            bpm: bpm,
            dimensionalOffset: dimensionalOffset,
            quantumPhase: quantumPhase,
            aiComplexity: aiComplexity,
            aiHarmony: aiHarmony
        )
    }
}

//==============================================================================
// MARK: - Render Parameters
//==============================================================================

/// Parameters for 360° rendering
public struct RenderParameters360: Sendable {
    public let dimension: VisualDimension
    public let projection: ProjectionMode360
    public let layers: [VisualLayer]
    public let environment: Environment360
    public let coherence: Double
    public let heartRate: Double
    public let breathPhase: Double
    public let hrvMs: Double
    public let audioLevel: Double
    public let spectrumData: [Float]
    public let beatDetected: Bool
    public let bpm: Double
    public let dimensionalOffset: SIMD4<Double>
    public let quantumPhase: Double
    public let aiComplexity: Double
    public let aiHarmony: Double
}

//==============================================================================
// MARK: - 360° Visual View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct Intelligent360VisualView: View {
    @ObservedObject var engine: Intelligent360VisualEngine
    @State private var selectedLayerIndex: Int? = nil
    @State private var showSettings = false

    public init(engine: Intelligent360VisualEngine) {
        self.engine = engine
    }

    public var body: some View {
        ZStack {
            // Main 360° Canvas
            Canvas360View(engine: engine)
                .ignoresSafeArea()

            // Overlay Controls
            VStack {
                // Top bar
                HStack {
                    // Dimension selector
                    Menu {
                        ForEach(VisualDimension.allCases) { dim in
                            Button(dim.name) {
                                engine.setDimension(dim)
                            }
                        }
                    } label: {
                        Label(engine.currentDimension.name, systemImage: "cube.transparent")
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }

                    Spacer()

                    // FPS indicator
                    Text("\(Int(engine.fps)) FPS")
                        .font(.caption.monospacedDigit())
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)

                    // Settings button
                    Button {
                        showSettings.toggle()
                    } label: {
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
                    // Coherence meter
                    CoherenceMeter360(value: engine.coherence)

                    Spacer()

                    // Mode selector
                    Menu {
                        ForEach(IntelligentVisualMode.allCases) { mode in
                            Button(mode.displayName) {
                                engine.activeMode = mode
                            }
                        }
                    } label: {
                        Text(engine.activeMode.displayName)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }

                    // Play/Stop
                    Button {
                        if engine.isRunning {
                            engine.stop()
                        } else {
                            engine.start()
                        }
                    } label: {
                        Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
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
            Visual360SettingsView(engine: engine)
        }
    }
}

//==============================================================================
// MARK: - Canvas 360 View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct Canvas360View: View {
    @ObservedObject var engine: Intelligent360VisualEngine

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let params = engine.getRenderParameters()

                // Draw background
                drawBackground(context: context, size: size, params: params)

                // Draw each layer
                for layer in params.layers {
                    drawLayer(context: context, size: size, layer: layer, params: params)
                }

                // Draw foreground effects
                drawForegroundEffects(context: context, size: size, params: params)
            }
        }
    }

    private func drawBackground(context: GraphicsContext, size: CGSize, params: RenderParameters360) {
        // Bio-reactive gradient background
        let hue = 0.6 + params.coherence * 0.2 // Blue to purple
        let brightness = 0.05 + params.coherence * 0.1

        let gradient = Gradient(colors: [
            Color(hue: hue, saturation: 0.8, brightness: brightness),
            Color(hue: hue + 0.1, saturation: 0.6, brightness: brightness * 0.5),
            Color.black
        ])

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: size.width / 2, y: 0),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            )
        )
    }

    private func drawLayer(context: GraphicsContext, size: CGSize, layer: VisualLayer, params: RenderParameters360) {
        var layerContext = context
        layerContext.opacity = layer.opacity

        let bioMod = layer.isBioReactive ? params.coherence * layer.bioReactivityAmount : 0.5

        switch layer.mode {
        case .sacredGeometry:
            drawSacredGeometry(context: layerContext, size: size, params: params, bioMod: bioMod)
        case .coherenceField:
            drawCoherenceField(context: layerContext, size: size, params: params, bioMod: bioMod)
        case .particleLife:
            drawParticleLife(context: layerContext, size: size, params: params, bioMod: bioMod)
        case .spectrumRings:
            drawSpectrumRings(context: layerContext, size: size, params: params, bioMod: bioMod)
        case .cosmicNebula:
            drawCosmicNebula(context: layerContext, size: size, params: params, bioMod: bioMod)
        default:
            drawGenericField(context: layerContext, size: size, params: params, bioMod: bioMod)
        }
    }

    private func drawSacredGeometry(context: GraphicsContext, size: CGSize, params: RenderParameters360, bioMod: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.35 * (0.8 + bioMod * 0.4)
        let rotation = params.quantumPhase * 0.1

        // Flower of Life pattern
        let petalCount = 6
        var path = Path()

        for i in 0..<petalCount {
            let angle = Double(i) * .pi * 2 / Double(petalCount) + rotation
            let petalCenter = CGPoint(
                x: center.x + cos(angle) * radius * 0.5,
                y: center.y + sin(angle) * radius * 0.5
            )
            path.addEllipse(in: CGRect(
                x: petalCenter.x - radius * 0.5,
                y: petalCenter.y - radius * 0.5,
                width: radius,
                height: radius
            ))
        }

        // Center circle
        path.addEllipse(in: CGRect(
            x: center.x - radius * 0.5,
            y: center.y - radius * 0.5,
            width: radius,
            height: radius
        ))

        let hue = 0.5 + bioMod * 0.3
        context.stroke(
            path,
            with: .color(Color(hue: hue, saturation: 0.7, brightness: 0.9)),
            lineWidth: 2
        )
    }

    private func drawCoherenceField(context: GraphicsContext, size: CGSize, params: RenderParameters360, bioMod: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let ringCount = 8

        for i in 0..<ringCount {
            let progress = Double(i) / Double(ringCount)
            let radius = min(size.width, size.height) * 0.4 * progress * (0.8 + bioMod * 0.4)
            let pulse = sin(params.quantumPhase * 2 + progress * .pi * 2) * 0.1 + 1.0

            let path = Path(ellipseIn: CGRect(
                x: center.x - radius * pulse,
                y: center.y - radius * pulse,
                width: radius * 2 * pulse,
                height: radius * 2 * pulse
            ))

            let hue = 0.55 + progress * 0.15 + bioMod * 0.1
            let opacity = (1.0 - progress) * 0.6 * bioMod

            context.stroke(
                path,
                with: .color(Color(hue: hue, saturation: 0.8, brightness: 0.9).opacity(opacity)),
                lineWidth: 2 + bioMod * 2
            )
        }
    }

    private func drawParticleLife(context: GraphicsContext, size: CGSize, params: RenderParameters360, bioMod: Double) {
        let particleCount = 50
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        for i in 0..<particleCount {
            let seed = Double(i) * 0.1
            let angle = seed * .pi * 2 + params.quantumPhase * (0.5 + seed * 0.5)
            let distance = (sin(seed * 5 + params.quantumPhase) * 0.5 + 0.5) * min(size.width, size.height) * 0.4 * bioMod

            let x = center.x + cos(angle) * distance
            let y = center.y + sin(angle) * distance
            let particleSize = 3 + bioMod * 5 * (sin(seed * 10 + params.quantumPhase * 2) * 0.5 + 0.5)

            let hue = (seed + params.quantumPhase * 0.1).truncatingRemainder(dividingBy: 1.0)

            context.fill(
                Path(ellipseIn: CGRect(x: x - particleSize / 2, y: y - particleSize / 2, width: particleSize, height: particleSize)),
                with: .color(Color(hue: hue, saturation: 0.8, brightness: 0.95))
            )
        }
    }

    private func drawSpectrumRings(context: GraphicsContext, size: CGSize, params: RenderParameters360, bioMod: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let barCount = min(params.spectrumData.count, 32)

        for i in 0..<barCount {
            let angle = Double(i) * .pi * 2 / Double(barCount) - .pi / 2
            let magnitude = Double(params.spectrumData[i])
            let radius = min(size.width, size.height) * 0.15
            let barHeight = magnitude * min(size.width, size.height) * 0.25 * bioMod

            let innerPoint = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            let outerPoint = CGPoint(
                x: center.x + cos(angle) * (radius + barHeight),
                y: center.y + sin(angle) * (radius + barHeight)
            )

            var path = Path()
            path.move(to: innerPoint)
            path.addLine(to: outerPoint)

            let hue = Double(i) / Double(barCount)
            context.stroke(
                path,
                with: .color(Color(hue: hue, saturation: 0.9, brightness: 0.95)),
                lineWidth: 4
            )
        }
    }

    private func drawCosmicNebula(context: GraphicsContext, size: CGSize, params: RenderParameters360, bioMod: Double) {
        let cloudCount = 20

        for i in 0..<cloudCount {
            let seed = Double(i) * 0.15
            let x = (sin(seed * 3 + params.quantumPhase * 0.3) * 0.5 + 0.5) * size.width
            let y = (cos(seed * 2.5 + params.quantumPhase * 0.2) * 0.5 + 0.5) * size.height
            let cloudSize = 50 + bioMod * 100 * (sin(seed * 7) * 0.5 + 0.5)

            let hue = (seed * 0.5 + params.quantumPhase * 0.02).truncatingRemainder(dividingBy: 1.0)
            let opacity = 0.1 + bioMod * 0.2

            let gradient = RadialGradient(
                colors: [
                    Color(hue: hue, saturation: 0.8, brightness: 0.9).opacity(opacity),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: cloudSize
            )

            context.fill(
                Path(ellipseIn: CGRect(x: x - cloudSize, y: y - cloudSize, width: cloudSize * 2, height: cloudSize * 2)),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(hue: hue, saturation: 0.8, brightness: 0.9).opacity(opacity),
                        Color.clear
                    ]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: cloudSize
                )
            )
        }
    }

    private func drawGenericField(context: GraphicsContext, size: CGSize, params: RenderParameters360, bioMod: Double) {
        // Fallback generic visualization
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.3 * bioMod

        let path = Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        context.fill(
            path,
            with: .color(Color(hue: 0.6, saturation: 0.7, brightness: 0.8).opacity(0.3))
        )
    }

    private func drawForegroundEffects(context: GraphicsContext, size: CGSize, params: RenderParameters360) {
        // Bloom effect simulation
        if params.environment.bloomIntensity > 0 {
            let bloomOpacity = Double(params.environment.bloomIntensity) * params.coherence * 0.3
            let gradient = RadialGradient(
                colors: [
                    Color.white.opacity(bloomOpacity),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: min(size.width, size.height) * 0.5
            )

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    Gradient(colors: [Color.white.opacity(bloomOpacity), Color.clear]),
                    center: CGPoint(x: size.width / 2, y: size.height / 2),
                    startRadius: 0,
                    endRadius: min(size.width, size.height) * 0.5
                )
            )
        }

        // Beat flash
        if params.beatDetected {
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.white.opacity(0.1))
            )
        }
    }
}

//==============================================================================
// MARK: - Coherence Meter 360
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct CoherenceMeter360: View {
    let value: Double

    var body: some View {
        VStack(spacing: 4) {
            Text("COHERENCE")
                .font(.caption2)
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: value)
                    .stroke(
                        Color(hue: 0.3 + value * 0.4, saturation: 0.8, brightness: 0.9),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(Int(value * 100))%")
                    .font(.caption.bold().monospacedDigit())
            }
            .frame(width: 50, height: 50)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

//==============================================================================
// MARK: - Settings View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct Visual360SettingsView: View {
    @ObservedObject var engine: Intelligent360VisualEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        EchoelNavigationStack {
            List {
                Section("Dimension") {
                    Picker("Dimension", selection: $engine.currentDimension) {
                        ForEach(VisualDimension.allCases) { dim in
                            Text(dim.name).tag(dim)
                        }
                    }
                }

                Section("Projection") {
                    Picker("Mode", selection: $engine.projectionMode) {
                        ForEach(ProjectionMode360.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                }

                Section("Presets") {
                    Button("Meditation") { engine.loadMeditationPreset() }
                    Button("Energetic") { engine.loadEnergeticPreset() }
                    Button("Cosmic") { engine.loadCosmicPreset() }
                    Button("Full Immersion") { engine.loadImmersivePreset() }
                }

                Section("Layers") {
                    ForEach(engine.layers) { layer in
                        HStack {
                            Text(layer.name)
                            Spacer()
                            Text(layer.mode.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onMove { engine.moveLayer(from: $0, to: $1) }
                    .onDelete { engine.layers.remove(atOffsets: $0) }
                }
            }
            .navigationTitle("360° Visual Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
