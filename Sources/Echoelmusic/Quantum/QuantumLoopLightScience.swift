// QuantumLoopLightScience.swift
// Echoelmusic - Loop Quantum Light Science Engine
// λ% Ralph Wiggum Nobel Prize Genius Developer Mode
// Created 2026-01-05 - Phase λ∞ TRANSCENDENCE
//
// "Me fail English? That's unpossible!" - Ralph Wiggum, String Theorist
//
// ═══════════════════════════════════════════════════════════════════════════════
// This is a CREATIVE/ARTISTIC interpretation of quantum concepts for
// audio-visual synthesis. NOT a physics simulation or scientific tool.
// For entertainment and self-exploration purposes only.
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import SwiftUI
import Combine
import simd

//==============================================================================
// MARK: - Quantum Light Constants
//==============================================================================

/// Physical and creative constants for quantum light synthesis
public enum QuantumLightConstants {
    // Physical constants (for creative inspiration, not simulation)
    public static let planckLength: Double = 1.616255e-35          // meters
    public static let planckTime: Double = 5.391247e-44            // seconds
    public static let planckEnergy: Double = 1.956e9               // joules
    public static let speedOfLight: Double = 299792458.0           // m/s
    public static let fineStructure: Double = 1.0 / 137.035999084  // α

    // Creative mappings
    public static let coherenceQuantum: Double = 0.01              // Min coherence step
    public static let photonDensityMax: Int = 10000               // Max particles
    public static let wavePacketWidth: Double = 0.1                // Normalized
    public static let entanglementStrength: Double = 0.95          // Correlation

    // Golden ratio and sacred geometry
    public static let phi: Double = 1.618033988749895
    public static let phiInverse: Double = 0.618033988749895
    public static let sacredAngle: Double = 137.5077640500378      // Golden angle in degrees

    // Schumann resonances (Earth frequencies)
    public static let schumannFundamental: Double = 7.83           // Hz
    public static let schumannHarmonics: [Double] = [7.83, 14.3, 20.8, 27.3, 33.8]
}

//==============================================================================
// MARK: - Quantum State Types
//==============================================================================

/// Quantum-inspired state representations
public enum QuantumStateType: String, CaseIterable, Identifiable, Sendable {
    case groundState = "ground"                    // |0⟩ - Rest state
    case excitedState = "excited"                  // |1⟩ - Active state
    case superposition = "superposition"           // α|0⟩ + β|1⟩ - Both
    case entangled = "entangled"                   // Correlated pair
    case coherent = "coherent"                     // Laser-like state
    case squeezed = "squeezed"                     // Reduced uncertainty
    case catState = "cat"                          // Schrödinger cat
    case fock = "fock"                             // Definite photon number
    case thermal = "thermal"                       // Mixed state

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .groundState: return "Ground |0⟩"
        case .excitedState: return "Excited |1⟩"
        case .superposition: return "Superposition"
        case .entangled: return "Entangled"
        case .coherent: return "Coherent"
        case .squeezed: return "Squeezed"
        case .catState: return "Cat State"
        case .fock: return "Fock State"
        case .thermal: return "Thermal"
        }
    }

    public var symbol: String {
        switch self {
        case .groundState: return "|0⟩"
        case .excitedState: return "|1⟩"
        case .superposition: return "|ψ⟩"
        case .entangled: return "|Φ⁺⟩"
        case .coherent: return "|α⟩"
        case .squeezed: return "|ζ⟩"
        case .catState: return "|🐱⟩"
        case .fock: return "|n⟩"
        case .thermal: return "ρ"
        }
    }
}

//==============================================================================
// MARK: - Light Field Geometry
//==============================================================================

/// Geometric configurations for light field synthesis
public enum LightFieldGeometry: String, CaseIterable, Identifiable, Sendable {
    case spherical = "spherical"
    case toroidal = "toroidal"
    case fibonacci = "fibonacci"
    case platonic = "platonic"
    case hyperbolic = "hyperbolic"
    case fractal = "fractal"
    case moebius = "moebius"
    case hopfFibration = "hopf"
    case calabi_yau = "calabi_yau"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .spherical: return "Spherical"
        case .toroidal: return "Toroidal"
        case .fibonacci: return "Fibonacci Spiral"
        case .platonic: return "Platonic Solid"
        case .hyperbolic: return "Hyperbolic"
        case .fractal: return "Fractal"
        case .moebius: return "Möbius Strip"
        case .hopfFibration: return "Hopf Fibration"
        case .calabi_yau: return "Calabi-Yau"
        }
    }

    public var dimensionality: Int {
        switch self {
        case .spherical, .toroidal, .fibonacci, .platonic: return 3
        case .hyperbolic, .fractal, .moebius: return 3
        case .hopfFibration: return 4
        case .calabi_yau: return 6
        }
    }
}

//==============================================================================
// MARK: - Photon
//==============================================================================

/// A quantum-inspired photon representation
public struct QuantumPhoton: Identifiable, Sendable {
    public let id: UUID
    public var position: SIMD3<Float>
    public var momentum: SIMD3<Float>
    public var polarization: SIMD2<Float>      // Jones vector
    public var phase: Float
    public var wavelength: Float               // nm
    public var amplitude: Float
    public var coherence: Float
    public var entangledWith: UUID?

    public init(
        id: UUID = UUID(),
        position: SIMD3<Float> = .zero,
        momentum: SIMD3<Float> = SIMD3(0, 0, 1),
        polarization: SIMD2<Float> = SIMD2(1, 0),
        phase: Float = 0,
        wavelength: Float = 550,
        amplitude: Float = 1.0,
        coherence: Float = 1.0,
        entangledWith: UUID? = nil
    ) {
        self.id = id
        self.position = position
        self.momentum = momentum
        self.polarization = polarization
        self.phase = phase
        self.wavelength = wavelength
        self.amplitude = amplitude
        self.coherence = coherence
        self.entangledWith = entangledWith
    }

    /// Get color from wavelength
    public var color: SIMD3<Float> {
        wavelengthToRGB(wavelength)
    }

    private func wavelengthToRGB(_ nm: Float) -> SIMD3<Float> {
        var r: Float = 0, g: Float = 0, b: Float = 0

        if nm >= 380 && nm < 440 {
            r = -(nm - 440) / (440 - 380)
            b = 1.0
        } else if nm >= 440 && nm < 490 {
            g = (nm - 440) / (490 - 440)
            b = 1.0
        } else if nm >= 490 && nm < 510 {
            g = 1.0
            b = -(nm - 510) / (510 - 490)
        } else if nm >= 510 && nm < 580 {
            r = (nm - 510) / (580 - 510)
            g = 1.0
        } else if nm >= 580 && nm < 645 {
            r = 1.0
            g = -(nm - 645) / (645 - 580)
        } else if nm >= 645 && nm <= 780 {
            r = 1.0
        }

        return SIMD3(r, g, b)
    }
}

//==============================================================================
// MARK: - Wave Function
//==============================================================================

/// Quantum-inspired wave function for visualization
public struct WaveFunction: Sendable {
    public var realPart: [Float]
    public var imaginaryPart: [Float]
    public var gridSize: Int

    public init(gridSize: Int = 64) {
        self.gridSize = gridSize
        self.realPart = Array(repeating: 0, count: gridSize * gridSize)
        self.imaginaryPart = Array(repeating: 0, count: gridSize * gridSize)
    }

    /// Get probability density |ψ|²
    public var probabilityDensity: [Float] {
        zip(realPart, imaginaryPart).map { r, i in
            r * r + i * i
        }
    }

    /// Normalize the wave function
    public mutating func normalize() {
        let total = probabilityDensity.reduce(0, +)
        guard total > 0 else { return }
        let factor = 1.0 / sqrt(total)
        for i in realPart.indices {
            realPart[i] *= factor
            imaginaryPart[i] *= factor
        }
    }

    /// Apply phase rotation
    public mutating func applyPhase(_ phase: Float) {
        let cosP = cos(phase)
        let sinP = sin(phase)
        for i in realPart.indices {
            let r = realPart[i]
            let im = imaginaryPart[i]
            realPart[i] = r * cosP - im * sinP
            imaginaryPart[i] = r * sinP + im * cosP
        }
    }
}

//==============================================================================
// MARK: - Light Field
//==============================================================================

/// A coherent light field configuration
public struct LightField: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var geometry: LightFieldGeometry
    public var photons: [QuantumPhoton]
    public var waveFunction: WaveFunction
    public var coherenceLevel: Float
    public var entanglementDensity: Float
    public var scaleParameter: Float
    public var rotationRate: Float

    public init(
        id: UUID = UUID(),
        name: String = "Light Field",
        geometry: LightFieldGeometry = .fibonacci,
        photonCount: Int = 100,
        coherenceLevel: Float = 0.8,
        entanglementDensity: Float = 0.3,
        scaleParameter: Float = 1.0,
        rotationRate: Float = 0.1
    ) {
        self.id = id
        self.name = name
        self.geometry = geometry
        self.coherenceLevel = coherenceLevel
        self.entanglementDensity = entanglementDensity
        self.scaleParameter = scaleParameter
        self.rotationRate = rotationRate
        self.waveFunction = WaveFunction()

        // Generate photons based on geometry
        self.photons = LightField.generatePhotons(
            count: photonCount,
            geometry: geometry,
            scale: scaleParameter
        )
    }

    private static func generatePhotons(count: Int, geometry: LightFieldGeometry, scale: Float) -> [QuantumPhoton] {
        var photons: [QuantumPhoton] = []

        for i in 0..<count {
            let t = Float(i) / Float(count)
            var position: SIMD3<Float>

            switch geometry {
            case .spherical:
                let phi = Float(i) * Float(QuantumLightConstants.sacredAngle) * .pi / 180
                let theta = acos(1 - 2 * t)
                position = SIMD3(
                    sin(theta) * cos(phi),
                    sin(theta) * sin(phi),
                    cos(theta)
                ) * scale

            case .fibonacci:
                let phi = Float(i) * Float(QuantumLightConstants.sacredAngle) * .pi / 180
                let r = sqrt(t)
                position = SIMD3(
                    r * cos(phi),
                    r * sin(phi),
                    t * 2 - 1
                ) * scale

            case .toroidal:
                let u = t * .pi * 2
                let v = Float(i % 20) / 20.0 * .pi * 2
                let R: Float = 1.0
                let r: Float = 0.3
                position = SIMD3(
                    (R + r * cos(v)) * cos(u),
                    (R + r * cos(v)) * sin(u),
                    r * sin(v)
                ) * scale

            default:
                // Default to random sphere
                let phi = Float.random(in: 0...Float.pi * 2)
                let theta = acos(Float.random(in: -1...1))
                position = SIMD3(
                    sin(theta) * cos(phi),
                    sin(theta) * sin(phi),
                    cos(theta)
                ) * scale
            }

            // Wavelength varies with position for rainbow effect
            let wavelength = 380 + t * 400 // Visible spectrum

            photons.append(QuantumPhoton(
                position: position,
                wavelength: wavelength,
                coherence: Float.random(in: 0.7...1.0)
            ))
        }

        return photons
    }
}

//==============================================================================
// MARK: - Quantum Loop Light Science Engine
//==============================================================================

/// The Loop Quantum Light Science Engine
/// Creative interpretation of quantum concepts for audio-visual synthesis
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
public final class QuantumLoopLightScienceEngine: ObservableObject {

    //==========================================================================
    // MARK: - Published Properties
    //==========================================================================

    @Published public var isActive: Bool = false
    @Published public var currentState: QuantumStateType = .groundState
    @Published public var geometry: LightFieldGeometry = .fibonacci
    @Published public var lightField: LightField = LightField()

    // Coherence and entanglement
    @Published public var globalCoherence: Double = 0.5
    @Published public var entanglementStrength: Double = 0.3
    @Published public var quantumPhase: Double = 0.0

    // Bio-coupling
    @Published public var bioCoherence: Double = 0.5
    @Published public var heartRateFrequency: Double = 1.17  // 70 BPM in Hz
    @Published public var breathFrequency: Double = 0.1      // 6 breaths/min

    // Visualization parameters
    @Published public var photonCount: Int = 500
    @Published public var waveAmplitude: Double = 1.0
    @Published public var interferencePattern: Bool = true
    @Published public var showEntanglement: Bool = true

    // Rendering stats
    @Published public var fps: Double = 60.0
    @Published public var renderTime: Double = 0.0

    //==========================================================================
    // MARK: - Private Properties
    //==========================================================================

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private var time: Double = 0
    private var lastFrameTime: Date = Date()

    //==========================================================================
    // MARK: - Initialization
    //==========================================================================

    public init() {
        regenerateLightField()
    }

    //==========================================================================
    // MARK: - Engine Control
    //==========================================================================

    public func start() {
        guard !isActive else { return }
        isActive = true

        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        print("⚛️ Quantum Loop Light Science Engine ACTIVATED")
    }

    public func stop() {
        isActive = false
        updateTimer?.invalidate()
        updateTimer = nil
        print("⚛️ Quantum Loop Light Science Engine DEACTIVATED")
    }

    private func tick() {
        let now = Date()
        let deltaTime = now.timeIntervalSince(lastFrameTime)
        lastFrameTime = now

        time += deltaTime
        fps = 1.0 / deltaTime

        // Update quantum phase
        updateQuantumPhase(deltaTime: deltaTime)

        // Update photon positions
        updatePhotons(deltaTime: deltaTime)

        // Update wave function
        updateWaveFunction(deltaTime: deltaTime)

        // Update state transitions
        updateStateTransitions()
    }

    private func updateQuantumPhase(deltaTime: Double) {
        // Phase evolution based on bio signals
        let baseRate = 2.0 * .pi * heartRateFrequency
        let coherenceModulation = 1.0 + bioCoherence * 0.5
        let breathModulation = sin(time * breathFrequency * 2 * .pi) * 0.2

        quantumPhase += (baseRate * coherenceModulation + breathModulation) * deltaTime
        quantumPhase = quantumPhase.truncatingRemainder(dividingBy: 2 * .pi)
    }

    private func updatePhotons(deltaTime: Double) {
        // Rotate photons based on geometry
        let rotationAngle = Float(lightField.rotationRate * deltaTime)
        let cosR = cos(rotationAngle)
        let sinR = sin(rotationAngle)

        for i in lightField.photons.indices {
            var photon = lightField.photons[i]

            // Rotate around Z axis
            let x = photon.position.x
            let y = photon.position.y
            photon.position.x = x * cosR - y * sinR
            photon.position.y = x * sinR + y * cosR

            // Update phase
            photon.phase += Float(deltaTime * 2 * .pi * heartRateFrequency)
            photon.phase = photon.phase.truncatingRemainder(dividingBy: Float.pi * 2)

            // Update coherence based on bio
            photon.coherence = Float(0.5 + bioCoherence * 0.5)

            lightField.photons[i] = photon
        }
    }

    private func updateWaveFunction(deltaTime: Double) {
        // Evolve wave function (simplified Schrödinger-like evolution)
        let phase = Float(quantumPhase)
        lightField.waveFunction.applyPhase(Float(deltaTime) * phase)
        lightField.waveFunction.normalize()
    }

    private func updateStateTransitions() {
        // Transition states based on coherence
        let newState: QuantumStateType

        if bioCoherence > 0.9 && entanglementStrength > 0.8 {
            newState = .entangled
        } else if bioCoherence > 0.8 {
            newState = .coherent
        } else if bioCoherence > 0.6 {
            newState = .superposition
        } else if bioCoherence > 0.4 {
            newState = .excitedState
        } else {
            newState = .groundState
        }

        if newState != currentState {
            currentState = newState
        }
    }

    //==========================================================================
    // MARK: - Bio Input
    //==========================================================================

    public func updateBioData(coherence: Double, heartRate: Double, breathRate: Double) {
        bioCoherence = coherence
        heartRateFrequency = heartRate / 60.0
        breathFrequency = breathRate / 60.0
    }

    //==========================================================================
    // MARK: - Configuration
    //==========================================================================

    public func setGeometry(_ geometry: LightFieldGeometry) {
        self.geometry = geometry
        regenerateLightField()
    }

    public func setPhotonCount(_ count: Int) {
        photonCount = max(10, min(count, QuantumLightConstants.photonDensityMax))
        regenerateLightField()
    }

    private func regenerateLightField() {
        lightField = LightField(
            geometry: geometry,
            photonCount: photonCount,
            coherenceLevel: Float(globalCoherence),
            entanglementDensity: Float(entanglementStrength)
        )
    }

    //==========================================================================
    // MARK: - Measurement (Creative)
    //==========================================================================

    /// "Measure" the quantum state (creative interpretation)
    public func measure() -> MeasurementResult {
        // Collapse to classical state based on probabilities
        let random = Double.random(in: 0...1)

        let state: Int
        if random < bioCoherence {
            state = 1 // Excited
        } else {
            state = 0 // Ground
        }

        return MeasurementResult(
            state: state,
            coherence: bioCoherence,
            phase: quantumPhase,
            timestamp: Date()
        )
    }

    public struct MeasurementResult: Sendable {
        public let state: Int
        public let coherence: Double
        public let phase: Double
        public let timestamp: Date
    }

    //==========================================================================
    // MARK: - Presets
    //==========================================================================

    public func loadMeditationPreset() {
        geometry = .fibonacci
        photonCount = 200
        globalCoherence = 0.8
        entanglementStrength = 0.5
        lightField.rotationRate = 0.05
        interferencePattern = true
        regenerateLightField()
    }

    public func loadEnergeticPreset() {
        geometry = .toroidal
        photonCount = 800
        globalCoherence = 0.6
        entanglementStrength = 0.3
        lightField.rotationRate = 0.3
        interferencePattern = true
        regenerateLightField()
    }

    public func loadCosmicPreset() {
        geometry = .spherical
        photonCount = 1000
        globalCoherence = 0.9
        entanglementStrength = 0.7
        lightField.rotationRate = 0.1
        interferencePattern = true
        showEntanglement = true
        regenerateLightField()
    }

    public func loadSacredGeometryPreset() {
        geometry = .platonic
        photonCount = 500
        globalCoherence = 0.95
        entanglementStrength = 0.9
        lightField.rotationRate = 0.08
        interferencePattern = true
        regenerateLightField()
    }
}

//==============================================================================
// MARK: - Quantum Loop Light View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct QuantumLoopLightView: View {
    @ObservedObject var engine: QuantumLoopLightScienceEngine
    @State private var showSettings = false

    public init(engine: QuantumLoopLightScienceEngine) {
        self.engine = engine
    }

    public var body: some View {
        ZStack {
            // Visualization canvas
            QuantumLightCanvas(engine: engine)
                .ignoresSafeArea()

            // Overlay
            VStack {
                // Top bar
                HStack {
                    // State indicator
                    HStack(spacing: 6) {
                        Text(engine.currentState.symbol)
                            .font(.caption.bold())
                        Text(engine.currentState.displayName)
                            .font(.caption)
                    }
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

                // Bottom info
                HStack {
                    // Coherence meter
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Coherence")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(Int(engine.bioCoherence * 100))%")
                            .font(.headline.monospacedDigit())
                    }
                    .padding(12)
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

            // Disclaimer at bottom
            VStack {
                Spacer()
                Text("Creative visualization. Not a physics simulation.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showSettings) {
            QuantumLightSettingsView(engine: engine)
        }
    }
}

//==============================================================================
// MARK: - Quantum Light Canvas
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct QuantumLightCanvas: View {
    @ObservedObject var engine: QuantumLoopLightScienceEngine

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                // Background
                drawBackground(context: context, size: size)

                // Wave function
                if engine.interferencePattern {
                    drawInterference(context: context, size: size, time: time)
                }

                // Photons
                drawPhotons(context: context, size: size, time: time)

                // Entanglement lines
                if engine.showEntanglement {
                    drawEntanglement(context: context, size: size)
                }
            }
        }
    }

    private func drawBackground(context: GraphicsContext, size: CGSize) {
        let hue = 0.7 + engine.bioCoherence * 0.1

        let gradient = Gradient(colors: [
            Color(hue: hue, saturation: 0.5, brightness: 0.1),
            Color(hue: hue + 0.1, saturation: 0.3, brightness: 0.05),
            Color.black
        ])

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                gradient,
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            )
        )
    }

    private func drawInterference(context: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let wavelength = 30.0 * (1.0 + engine.bioCoherence * 0.5)
        let amplitude = 0.3 + engine.bioCoherence * 0.2

        // Draw interference rings
        for i in 0..<20 {
            let radius = Double(i) * wavelength
            let phase = engine.quantumPhase + Double(i) * 0.5
            let alpha = max(0, amplitude * cos(phase)) * (1.0 - Double(i) / 20.0)

            let path = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            context.stroke(
                path,
                with: .color(Color.cyan.opacity(alpha)),
                lineWidth: 1
            )
        }
    }

    private func drawPhotons(context: GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let scale = min(size.width, size.height) * 0.4

        for photon in engine.lightField.photons {
            // Project 3D to 2D
            let depth = photon.position.z * 0.5 + 0.5  // Normalize to 0-1
            let x = center.x + CGFloat(photon.position.x * Float(scale) * (0.5 + depth * 0.5))
            let y = center.y + CGFloat(photon.position.y * Float(scale) * (0.5 + depth * 0.5))

            // Size based on depth and coherence
            let baseSize = 3.0 + Double(photon.coherence) * 5.0
            let depthSize = baseSize * Double(0.5 + depth * 0.5)

            // Color from wavelength
            let rgb = photon.color
            let color = Color(
                red: Double(rgb.x),
                green: Double(rgb.y),
                blue: Double(rgb.z)
            )

            // Draw glow
            let glowSize = depthSize * 3
            context.fill(
                Path(ellipseIn: CGRect(x: x - glowSize/2, y: y - glowSize/2, width: glowSize, height: glowSize)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.5), Color.clear]),
                    center: CGPoint(x: x, y: y),
                    startRadius: 0,
                    endRadius: glowSize / 2
                )
            )

            // Draw photon core
            context.fill(
                Path(ellipseIn: CGRect(x: x - depthSize/2, y: y - depthSize/2, width: depthSize, height: depthSize)),
                with: .color(color.opacity(Double(photon.coherence)))
            )
        }
    }

    private func drawEntanglement(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let scale = min(size.width, size.height) * 0.4

        // Draw lines between entangled photon pairs (first few)
        let entangledPairs = min(10, engine.lightField.photons.count / 2)

        for i in 0..<entangledPairs {
            let p1 = engine.lightField.photons[i * 2]
            let p2 = engine.lightField.photons[i * 2 + 1]

            let x1 = center.x + CGFloat(p1.position.x * Float(scale))
            let y1 = center.y + CGFloat(p1.position.y * Float(scale))
            let x2 = center.x + CGFloat(p2.position.x * Float(scale))
            let y2 = center.y + CGFloat(p2.position.y * Float(scale))

            var path = Path()
            path.move(to: CGPoint(x: x1, y: y1))
            path.addLine(to: CGPoint(x: x2, y: y2))

            context.stroke(
                path,
                with: .color(Color.purple.opacity(0.3 * engine.entanglementStrength)),
                lineWidth: 1
            )
        }
    }
}

//==============================================================================
// MARK: - Quantum Light Settings View
//==============================================================================

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
struct QuantumLightSettingsView: View {
    @ObservedObject var engine: QuantumLoopLightScienceEngine
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Geometry") {
                    Picker("Light Field", selection: $engine.geometry) {
                        ForEach(LightFieldGeometry.allCases) { geo in
                            Text(geo.displayName).tag(geo)
                        }
                    }
                    .onChange(of: engine.geometry) { newValue in
                        engine.setGeometry(newValue)
                    }
                }

                Section("Particles") {
                    VStack(alignment: .leading) {
                        Text("Photon Count: \(engine.photonCount)")
                        Slider(value: Binding(
                            get: { Double(engine.photonCount) },
                            set: { engine.setPhotonCount(Int($0)) }
                        ), in: 50...2000, step: 50)
                    }
                }

                Section("Visualization") {
                    Toggle("Interference Pattern", isOn: $engine.interferencePattern)
                    Toggle("Show Entanglement", isOn: $engine.showEntanglement)
                }

                Section("Presets") {
                    Button("Meditation") { engine.loadMeditationPreset() }
                    Button("Energetic") { engine.loadEnergeticPreset() }
                    Button("Cosmic") { engine.loadCosmicPreset() }
                    Button("Sacred Geometry") { engine.loadSacredGeometryPreset() }
                }

                Section {
                    Text("This is a creative/artistic interpretation of quantum concepts for visualization. Not a physics simulation or scientific tool.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Quantum Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
