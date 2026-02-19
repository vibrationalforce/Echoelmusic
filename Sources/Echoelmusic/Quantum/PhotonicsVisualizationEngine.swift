//
//  PhotonicsVisualizationEngine.swift
//  Echoelmusic
//
//  Photonics-based visualization engine for quantum light fields
//  Creates stunning visual effects from coherent light simulations
//
//  Created: 2026-01-05
//

import Foundation
import Combine
import simd
import Accelerate

#if canImport(QuartzCore)
import QuartzCore
#endif

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Photonics Visualization Engine

@MainActor
public class PhotonicsVisualizationEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var currentVisualization: VisualizationType = .interferencePattern
    @Published public private(set) var frameRate: Double = 0.0
    @Published public private(set) var colorPalette: [SIMD3<Float>] = []

    // MARK: - Visualization Types

    public enum VisualizationType: String, CaseIterable, Sendable {
        case interferencePattern = "Interference Pattern"
        case waveFunction = "Wave Function"
        case coherenceField = "Coherence Field"
        case photonFlow = "Photon Flow"
        case sacredGeometry = "Sacred Geometry"
        case quantumTunnel = "Quantum Tunnel"
        case biophotonAura = "Biophoton Aura"
        case lightMandala = "Light Mandala"
        case holographicDisplay = "Holographic Display"
        case cosmicWeb = "Cosmic Web"
    }

    // MARK: - Configuration

    public struct Configuration: Sendable {
        public var width: Int = 512
        public var height: Int = 512
        public var targetFrameRate: Double = 60.0
        public var colorMode: ColorMode = .spectrum
        public var blendMode: BlendMode = .additive
        public var motionBlur: Float = 0.1
        public var glowIntensity: Float = 0.5
        public var particleTrails: Bool = true

        public enum ColorMode: String, Sendable {
            case spectrum = "Full Spectrum"
            case coherence = "Coherence Based"
            case rainbow = "Rainbow Spectrum"
            case monochrome = "Monochrome"
            case thermal = "Thermal"
            case aurora = "Aurora"
        }

        public enum BlendMode: String, Sendable {
            case additive = "Additive"
            case multiply = "Multiply"
            case screen = "Screen"
            case overlay = "Overlay"
        }

        public init() {}
    }

    public var configuration: Configuration

    // MARK: - Private Properties

    #if !WIDGET_EXTENSION
    private weak var quantumEmulator: QuantumLightEmulator?
    #endif
    private var displayLink: CADisplayLink?
    private var renderTimer: Timer?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameBuffer: [[SIMD4<Float>]] = []
    private var previousFrame: [[SIMD4<Float>]] = []
    private var particleSystem: PhotonParticleSystem?
    private var cancellables = Set<AnyCancellable>()

    // Pre-computed sin/cos lookup table for performance
    private static let trigTableSize = 1024
    private static let sinTable: [Float] = (0..<1024).map { Float(sin(Double($0) / 1024.0 * 2.0 * .pi)) }
    private static let cosTable: [Float] = (0..<1024).map { Float(cos(Double($0) / 1024.0 * 2.0 * .pi)) }

    private static func fastSin(_ x: Float) -> Float {
        let normalized = (x / (2 * Float.pi)).truncatingRemainder(dividingBy: 1.0)
        let index = Int((normalized < 0 ? normalized + 1 : normalized) * Float(trigTableSize)) % trigTableSize
        return sinTable[index]
    }

    private static func fastCos(_ x: Float) -> Float {
        let normalized = (x / (2 * Float.pi)).truncatingRemainder(dividingBy: 1.0)
        let index = Int((normalized < 0 ? normalized + 1 : normalized) * Float(trigTableSize)) % trigTableSize
        return cosTable[index]
    }

    // MARK: - Initialization

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        initializeFrameBuffer()
        initializeParticleSystem()
    }

    // MARK: - Public Methods

    /// Connect to quantum emulator
    public func connect(to emulator: QuantumLightEmulator) {
        self.quantumEmulator = emulator

        // Subscribe to emulator updates
        emulator.$currentEmulatorLightField
            .receive(on: DispatchQueue.main)
            .sink { [weak self] field in
                if let field = field {
                    self?.updateFromLightField(field)
                }
            }
            .store(in: &cancellables)

        emulator.$coherenceLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coherence in
                self?.updateColorPalette(coherence: coherence)
            }
            .store(in: &cancellables)
    }

    /// Start visualization
    public func start() {
        guard !isActive else { return }

        isActive = true
        startDisplayLink()
        log.quantum("[PhotonicsVisualization] Started - \(currentVisualization.rawValue)")
    }

    /// Stop visualization
    public func stop() {
        isActive = false
        displayLink?.invalidate()
        displayLink = nil
    }

    /// Set visualization type
    public func setVisualization(_ type: VisualizationType) {
        currentVisualization = type
        clearFrameBuffer()
    }

    /// Get current frame as RGBA pixel data
    public func getCurrentFrame() -> [[SIMD4<Float>]] {
        return frameBuffer
    }

    /// Generate interference pattern texture
    public func generateInterferenceTexture() -> [[SIMD4<Float>]] {
        guard let field = quantumEmulator?.currentEmulatorLightField else {
            return frameBuffer
        }

        var texture: [[SIMD4<Float>]] = Array(
            repeating: Array(repeating: .zero, count: configuration.width),
            count: configuration.height
        )

        let centerX = Float(configuration.width) / 2
        let centerY = Float(configuration.height) / 2
        let scale: Float = 0.01

        for y in 0..<configuration.height {
            for x in 0..<configuration.width {
                let point = SIMD3<Float>(
                    (Float(x) - centerX) * scale,
                    (Float(y) - centerY) * scale,
                    0
                )

                let interference = field.interferencePattern(at: point)
                let normalizedIntensity = (interference + 1) / 2

                let color = colorFromIntensity(normalizedIntensity, coherence: field.fieldCoherence)
                texture[y][x] = SIMD4<Float>(color.x, color.y, color.z, normalizedIntensity)
            }
        }

        return texture
    }

    // MARK: - Private Methods

    private func initializeFrameBuffer() {
        frameBuffer = Array(
            repeating: Array(repeating: .zero, count: configuration.width),
            count: configuration.height
        )
        previousFrame = frameBuffer
    }

    private func initializeParticleSystem() {
        particleSystem = PhotonParticleSystem(particleCount: 1000)
    }

    private func startDisplayLink() {
        #if os(iOS) || os(tvOS)
        displayLink = CADisplayLink(target: DisplayLinkTarget(handler: { [weak self] in
            self?.renderFrame()
        }), selector: #selector(DisplayLinkTarget.tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 30,
            maximum: Float(configuration.targetFrameRate),
            preferred: Float(configuration.targetFrameRate)
        )
        displayLink?.add(to: .main, forMode: .common)
        #else
        // macOS: Use timer
        renderTimer?.invalidate()
        renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / configuration.targetFrameRate, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.renderFrame()
            }
        }
        #endif
    }

    private func renderFrame() {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTime
        lastFrameTime = currentTime

        // Calculate frame rate
        frameRate = 1.0 / max(deltaTime, 0.001)

        // Store previous frame for motion blur
        if configuration.motionBlur > 0 {
            previousFrame = frameBuffer
        }

        // Render based on visualization type
        switch currentVisualization {
        case .interferencePattern:
            renderInterferencePattern()
        case .waveFunction:
            renderWaveFunction()
        case .coherenceField:
            renderCoherenceField()
        case .photonFlow:
            renderPhotonFlow(deltaTime: Float(deltaTime))
        case .sacredGeometry:
            renderSacredGeometry()
        case .quantumTunnel:
            renderQuantumTunnel()
        case .biophotonAura:
            renderBiophotonAura()
        case .lightMandala:
            renderLightMandala()
        case .holographicDisplay:
            renderHolographicDisplay()
        case .cosmicWeb:
            renderCosmicWeb()
        }

        // Apply motion blur
        if configuration.motionBlur > 0 {
            applyMotionBlur()
        }

        // Apply glow effect
        if configuration.glowIntensity > 0 {
            applyGlowEffect()
        }
    }

    private func renderInterferencePattern() {
        guard let field = quantumEmulator?.currentEmulatorLightField else { return }

        let time = Float(CACurrentMediaTime())
        let centerX = Float(configuration.width) / 2
        let centerY = Float(configuration.height) / 2

        for y in 0..<configuration.height {
            for x in 0..<configuration.width {
                let nx = (Float(x) - centerX) / centerX
                let ny = (Float(y) - centerY) / centerY

                var totalIntensity: Float = 0
                var totalColor = SIMD3<Float>.zero

                // Sum contributions from photons
                for photon in field.photons.prefix(32) {
                    let dx = nx - photon.position.x
                    let dy = ny - photon.position.y
                    let distance = sqrt(dx * dx + dy * dy)

                    let wavelengthNorm = photon.wavelength / 1000.0
                    let phase = distance / wavelengthNorm * 2 * Float.pi + time + photon.polarization
                    let amplitude = photon.intensity * exp(-distance * 2)

                    totalIntensity += amplitude * (1 + cos(phase)) / 2
                    totalColor += photon.color * amplitude
                }

                totalIntensity /= Float(min(32, field.photons.count))
                totalColor = simd_clamp(totalColor / Float(min(32, field.photons.count)), .zero, SIMD3<Float>(1, 1, 1))

                let alpha = totalIntensity * field.fieldCoherence
                frameBuffer[y][x] = SIMD4<Float>(totalColor.x, totalColor.y, totalColor.z, alpha)
            }
        }
    }

    private func renderWaveFunction() {
        guard let state = quantumEmulator?.currentQuantumState else { return }

        let time = Float(CACurrentMediaTime())
        let centerX = Float(configuration.width) / 2
        let centerY = Float(configuration.height) / 2

        for y in 0..<configuration.height {
            for x in 0..<configuration.width {
                let nx = (Float(x) - centerX) / centerX
                let ny = (Float(y) - centerY) / centerY
                let r = sqrt(nx * nx + ny * ny)
                let theta = atan2(ny, nx)

                // Quantum probability amplitude
                var psi: Float = 0
                for (i, amplitude) in state.amplitudes.enumerated() {
                    let phase = state.phases[i % state.phases.count]
                    let n = Float(i + 1)

                    // Hydrogen-like orbital pattern
                    let radialPart = exp(-r * n) * pow(r, Float(i % 3))
                    let angularPart = cos(n * theta + phase + time * 0.5)

                    psi += radialPart * angularPart * amplitude.x
                }

                let probability = psi * psi * state.coherence
                let color = colorFromIntensity(probability, coherence: state.coherence)

                frameBuffer[y][x] = SIMD4<Float>(color.x, color.y, color.z, probability)
            }
        }
    }

    private func renderCoherenceField() {
        guard let emulator = quantumEmulator else { return }

        let coherence = emulator.coherenceLevel
        let time = Float(CACurrentMediaTime())

        for y in 0..<configuration.height {
            for x in 0..<configuration.width {
                let nx = Float(x) / Float(configuration.width) * 2 - 1
                let ny = Float(y) / Float(configuration.height) * 2 - 1
                let r = sqrt(nx * nx + ny * ny)

                // Coherence creates order, decoherence creates chaos
                let orderedComponent = sin(r * 10 - time * 2) * coherence
                let chaoticComponent = Float.random(in: -1...1) * (1 - coherence) * 0.3

                let intensity = (orderedComponent + chaoticComponent + 1) / 2
                let hue = coherence * 0.3 + 0.5 // Blue-green for coherent, red for decoherent
                let color = hslToRgb(hue: hue, saturation: 0.8, lightness: intensity * 0.7)

                frameBuffer[y][x] = SIMD4<Float>(color.x, color.y, color.z, intensity)
            }
        }
    }

    private func renderPhotonFlow(deltaTime: Float) {
        particleSystem?.update(deltaTime: deltaTime, field: quantumEmulator?.currentEmulatorLightField)

        // Clear with fade
        for y in 0..<configuration.height {
            for x in 0..<configuration.width {
                frameBuffer[y][x] *= 0.95
            }
        }

        // Render particles
        if let particles = particleSystem?.particles {
            for particle in particles {
                let screenX = Int((particle.position.x + 1) / 2 * Float(configuration.width))
                let screenY = Int((particle.position.y + 1) / 2 * Float(configuration.height))

                if screenX >= 0 && screenX < configuration.width && screenY >= 0 && screenY < configuration.height {
                    let color = particle.color
                    let alpha = particle.life * particle.intensity
                    frameBuffer[screenY][screenX] += SIMD4<Float>(color.x, color.y, color.z, 1) * alpha
                }
            }
        }
    }

    private func renderSacredGeometry() {
        let time = Float(CACurrentMediaTime())
        let coherence = quantumEmulator?.coherenceLevel ?? 0.5

        for y in 0..<configuration.height {
            for x in 0..<configuration.width {
                let nx = Float(x) / Float(configuration.width) * 2 - 1
                let ny = Float(y) / Float(configuration.height) * 2 - 1

                // Flower of Life pattern
                var intensity: Float = 0
                let numCircles = 7
                let radius: Float = 0.3

                for i in 0..<numCircles {
                    let angle = Float(i) * Float.pi * 2 / Float(numCircles) + time * 0.1
                    let cx = cos(angle) * radius * 0.5
                    let cy = sin(angle) * radius * 0.5
                    let dist = sqrt(pow(nx - cx, 2) + pow(ny - cy, 2))

                    // Circle edge
                    let edge = abs(dist - radius) < 0.02 ? 1.0 : 0.0
                    intensity += Float(edge)
                }

                // Center circle
                let centerDist = sqrt(nx * nx + ny * ny)
                if abs(centerDist - radius) < 0.02 {
                    intensity += 1
                }

                // Vesica Piscis overlays
                let goldenRatio: Float = 1.618
                let vpDist1 = sqrt(pow(nx - 0.3, 2) + pow(ny, 2))
                let vpDist2 = sqrt(pow(nx + 0.3, 2) + pow(ny, 2))
                if abs(vpDist1 - 0.5) < 0.015 || abs(vpDist2 - 0.5) < 0.015 {
                    intensity += 0.5
                }

                intensity = min(1, intensity) * coherence
                let color = colorFromIntensity(intensity, coherence: coherence)
                frameBuffer[y][x] = SIMD4<Float>(color.x, color.y, color.z, intensity)
            }
        }
    }

    private func renderQuantumTunnel() {
        let time = Float(CACurrentMediaTime())
        let coherence = quantumEmulator?.coherenceLevel ?? 0.5

        for y in 0..<configuration.height {
            for x in 0..<configuration.width {
                let nx = Float(x) / Float(configuration.width) * 2 - 1
                let ny = Float(y) / Float(configuration.height) * 2 - 1

                // Tunnel effect with depth
                let angle = atan2(ny, nx)
                let dist = sqrt(nx * nx + ny * ny)

                let tunnelDepth = 1.0 / (dist + 0.1) + time * 0.5
                let rings = sin(tunnelDepth * 5) * 0.5 + 0.5
                let spiral = sin(angle * 3 + tunnelDepth) * 0.5 + 0.5

                let intensity = rings * spiral * (1 - dist * 0.5) * coherence
                let hue = fmod(tunnelDepth * 0.1 + coherence * 0.3, 1.0)
                let color = hslToRgb(hue: hue, saturation: 0.9, lightness: intensity * 0.6)

                frameBuffer[y][x] = SIMD4<Float>(color.x, color.y, color.z, intensity)
            }
        }
    }

    private func renderBiophotonAura() {
        let time = Float(CACurrentMediaTime())
        let coherence = quantumEmulator?.coherenceLevel ?? 0.5

        for y in 0..<configuration.height {
            for x in 0..<configuration.width {
                let nx = Float(x) / Float(configuration.width) * 2 - 1
                let ny = Float(y) / Float(configuration.height) * 2 - 1
                let dist = sqrt(nx * nx + ny * ny)
                let angle = atan2(ny, nx)

                // Aura layers
                var intensity: Float = 0

                // Physical body (inner)
                if dist < 0.2 {
                    intensity = 0.8
                }
                // Etheric layer
                else if dist < 0.35 {
                    intensity = 0.6 * (1 - (dist - 0.2) / 0.15)
                }
                // Emotional layer
                else if dist < 0.5 {
                    let wave = sin(angle * 6 + time * 2) * 0.2
                    intensity = (0.5 + wave) * (1 - (dist - 0.35) / 0.15) * coherence
                }
                // Mental layer
                else if dist < 0.7 {
                    let wave = sin(angle * 12 + time * 3) * 0.15
                    intensity = (0.4 + wave) * (1 - (dist - 0.5) / 0.2) * coherence
                }
                // Spiritual layer
                else if dist < 0.95 {
                    let wave = sin(angle * 18 + time * 4) * 0.1
                    intensity = (0.3 + wave) * (1 - (dist - 0.7) / 0.25) * coherence * coherence
                }

                // Spectrum colors based on angle (vertical axis)
                let spectrumHue = (ny + 1) / 2 // Red at bottom, violet at top
                let color = hslToRgb(hue: spectrumHue * 0.8, saturation: 0.7, lightness: intensity * 0.6)

                frameBuffer[y][x] = SIMD4<Float>(color.x, color.y, color.z, intensity)
            }
        }
    }

    private func renderLightMandala() {
        let time = Float(CACurrentMediaTime())
        let coherence = quantumEmulator?.coherenceLevel ?? 0.5

        for y in 0..<configuration.height {
            for x in 0..<configuration.width {
                let nx = Float(x) / Float(configuration.width) * 2 - 1
                let ny = Float(y) / Float(configuration.height) * 2 - 1
                let dist = sqrt(nx * nx + ny * ny)
                let angle = atan2(ny, nx)

                // Mandala with rotating symmetry
                let symmetry: Float = 8
                let symmetricAngle = fmod(angle * symmetry / (2 * Float.pi) + 0.5, 1.0) * 2 * Float.pi

                // Multiple rotating layers
                var intensity: Float = 0
                for layer in 0..<5 {
                    let layerRadius = Float(layer + 1) * 0.15
                    let layerSpeed = Float(layer + 1) * 0.2
                    let layerAngle = symmetricAngle + time * layerSpeed

                    let pattern = sin(layerAngle * 3) * cos(dist * 10 - time)
                    if abs(dist - layerRadius) < 0.05 {
                        intensity += (pattern * 0.5 + 0.5) * (1 - Float(layer) * 0.15)
                    }
                }

                // Petals
                let petalCount: Float = 12
                let petalPattern = pow(abs(sin(angle * petalCount / 2 + time * 0.5)), 2.0)
                intensity += petalPattern * exp(-dist * 3) * 0.5

                intensity *= coherence
                let hue = fmod(angle / (2 * Float.pi) + time * 0.05, 1.0)
                let color = hslToRgb(hue: hue, saturation: 0.8, lightness: intensity * 0.5)

                frameBuffer[y][x] = SIMD4<Float>(color.x, color.y, color.z, intensity)
            }
        }
    }

    private func renderHolographicDisplay() {
        guard let field = quantumEmulator?.currentEmulatorLightField else { return }

        let time = Float(CACurrentMediaTime())

        for y in 0..<configuration.height {
            for x in 0..<configuration.width {
                let nx = Float(x) / Float(configuration.width) * 2 - 1
                let ny = Float(y) / Float(configuration.height) * 2 - 1

                // Holographic interference fringes
                var intensity: Float = 0
                var color = SIMD3<Float>.zero

                for (i, photon) in field.photons.prefix(16).enumerated() {
                    let referenceWave = sin(nx * 20 + time)
                    let objectWave = sin(
                        (nx - photon.position.x) * 30 +
                        (ny - photon.position.y) * 30 +
                        time * 0.5 + Float(i)
                    )

                    let interference = (referenceWave + objectWave) / 2
                    intensity += (interference * 0.5 + 0.5) * photon.intensity
                    color += photon.color * photon.intensity
                }

                intensity /= Float(min(16, field.photons.count))
                color /= Float(min(16, field.photons.count))

                // Holographic shimmer
                let shimmer = sin(nx * 100 + ny * 50 + time * 10) * 0.1 + 0.9
                intensity *= shimmer * field.fieldCoherence

                frameBuffer[y][x] = SIMD4<Float>(color.x, color.y, color.z, intensity)
            }
        }
    }

    private func renderCosmicWeb() {
        let time = Float(CACurrentMediaTime())
        let coherence = quantumEmulator?.coherenceLevel ?? 0.5

        // Generate cosmic web nodes
        let nodeCount = 20
        var nodes: [(SIMD2<Float>, Float)] = []

        for i in 0..<nodeCount {
            let seed = Float(i * 12345)
            let x = sin(seed * 0.1 + time * 0.05) * 0.8
            let y = cos(seed * 0.13 + time * 0.07) * 0.8
            let mass = (sin(seed * 0.17) * 0.5 + 0.5) * coherence + 0.1
            nodes.append((SIMD2<Float>(x, y), mass))
        }

        for y in 0..<configuration.height {
            for x in 0..<configuration.width {
                let nx = Float(x) / Float(configuration.width) * 2 - 1
                let ny = Float(y) / Float(configuration.height) * 2 - 1
                let point = SIMD2<Float>(nx, ny)

                var intensity: Float = 0

                // Calculate gravitational potential
                for node in nodes {
                    let dist = simd_length(point - node.0)
                    intensity += node.1 / (dist * dist + 0.01)
                }

                // Filaments between nearby nodes
                for i in 0..<nodes.count {
                    for j in (i+1)..<nodes.count {
                        let nodeDist = simd_length(nodes[i].0 - nodes[j].0)
                        if nodeDist < 0.6 {
                            // Distance from point to line segment
                            let v = nodes[j].0 - nodes[i].0
                            let w = point - nodes[i].0
                            let c1 = simd_dot(w, v)
                            let c2 = simd_dot(v, v)

                            if c1 >= 0 && c1 <= c2 {
                                let t = c1 / c2
                                let projection = nodes[i].0 + t * v
                                let distToLine = simd_length(point - projection)

                                if distToLine < 0.02 {
                                    intensity += (1 - distToLine / 0.02) * (nodes[i].1 + nodes[j].1) * 0.5
                                }
                            }
                        }
                    }
                }

                intensity = min(1, intensity * 0.3)
                let hue = fmod(intensity + time * 0.01, 1.0) * 0.3 + 0.6 // Blue-purple palette
                let color = hslToRgb(hue: hue, saturation: 0.7, lightness: intensity * 0.5)

                frameBuffer[y][x] = SIMD4<Float>(color.x, color.y, color.z, intensity)
            }
        }
    }

    private func updateFromLightField(_ field: EmulatorLightField) {
        // Update color palette from photons
        colorPalette = field.photons.prefix(8).map(\.color)
    }

    private func updateColorPalette(coherence: Float) {
        if colorPalette.isEmpty {
            // Default palette based on coherence
            let baseHue = coherence * 0.3 + 0.5 // Blue-green for high coherence
            colorPalette = (0..<8).map { i in
                let hue = fmod(baseHue + Float(i) * 0.05, 1.0)
                return hslToRgb(hue: hue, saturation: 0.8, lightness: 0.5)
            }
        }
    }

    private func clearFrameBuffer() {
        let zero = SIMD4<Float>.zero
        for y in 0..<configuration.height {
            for i in frameBuffer[y].indices {
                frameBuffer[y][i] = zero
            }
        }
    }

    private func applyMotionBlur() {
        let blur = configuration.motionBlur
        let retain = 1 - blur
        for y in 0..<configuration.height {
            for x in 0..<configuration.width {
                frameBuffer[y][x] = frameBuffer[y][x] * retain + previousFrame[y][x] * blur
            }
        }
    }

    private func applyGlowEffect() {
        // Separable box blur for glow - O(n*r) instead of O(n*r^2)
        let intensity = configuration.glowIntensity
        let radius = 2
        let kernelSize = Float(radius * 2 + 1)

        // Horizontal pass
        var tempBuffer = frameBuffer
        for y in 0..<configuration.height {
            for x in radius..<(configuration.width - radius) {
                var sum = SIMD4<Float>.zero
                for dx in -radius...radius {
                    sum += frameBuffer[y][x + dx]
                }
                tempBuffer[y][x] = sum / kernelSize
            }
        }

        // Vertical pass
        var glowBuffer = tempBuffer
        for y in radius..<(configuration.height - radius) {
            for x in radius..<(configuration.width - radius) {
                var sum = SIMD4<Float>.zero
                for dy in -radius...radius {
                    sum += tempBuffer[y + dy][x]
                }
                let blur = sum / kernelSize
                glowBuffer[y][x] = frameBuffer[y][x] + blur * intensity
            }
        }

        frameBuffer = glowBuffer
    }

    private func colorFromIntensity(_ intensity: Float, coherence: Float) -> SIMD3<Float> {
        switch configuration.colorMode {
        case .spectrum:
            return hslToRgb(hue: intensity * 0.8, saturation: 0.9, lightness: intensity * 0.6)

        case .coherence:
            let hue = coherence * 0.3 + 0.5 // Blue-green for coherent
            return hslToRgb(hue: hue, saturation: 0.8, lightness: intensity * 0.6)

        case .rainbow:
            // Red -> Orange -> Yellow -> Green -> Blue -> Indigo -> Violet
            return hslToRgb(hue: intensity * 0.8, saturation: 0.9, lightness: 0.5)

        case .monochrome:
            return SIMD3<Float>(intensity, intensity, intensity)

        case .thermal:
            // Black -> Blue -> Cyan -> Green -> Yellow -> Red -> White
            if intensity < 0.2 {
                return SIMD3<Float>(0, 0, intensity * 5)
            } else if intensity < 0.4 {
                return SIMD3<Float>(0, (intensity - 0.2) * 5, 1)
            } else if intensity < 0.6 {
                return SIMD3<Float>((intensity - 0.4) * 5, 1, 1 - (intensity - 0.4) * 5)
            } else if intensity < 0.8 {
                return SIMD3<Float>(1, 1 - (intensity - 0.6) * 5, 0)
            } else {
                return SIMD3<Float>(1, (intensity - 0.8) * 5, (intensity - 0.8) * 5)
            }

        case .aurora:
            let hue = fmod(intensity * 0.4 + 0.3, 1.0) // Green to purple
            return hslToRgb(hue: hue, saturation: 0.7, lightness: intensity * 0.6)
        }
    }

    private func hslToRgb(hue: Float, saturation: Float, lightness: Float) -> SIMD3<Float> {
        let c = (1 - abs(2 * lightness - 1)) * saturation
        let x = c * (1 - abs(fmod(hue * 6, 2) - 1))
        let m = lightness - c / 2

        var r: Float = 0, g: Float = 0, b: Float = 0

        let h = hue * 6
        if h < 1 { r = c; g = x; b = 0 }
        else if h < 2 { r = x; g = c; b = 0 }
        else if h < 3 { r = 0; g = c; b = x }
        else if h < 4 { r = 0; g = x; b = c }
        else if h < 5 { r = x; g = 0; b = c }
        else { r = c; g = 0; b = x }

        return SIMD3<Float>(r + m, g + m, b + m)
    }
}

// MARK: - Display Link Target (for iOS/tvOS)

#if os(iOS) || os(tvOS)
private class DisplayLinkTarget {
    let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func tick() {
        handler()
    }
}
#endif

// MARK: - Photon Particle System

private class PhotonParticleSystem {

    struct Particle {
        var position: SIMD3<Float>
        var velocity: SIMD3<Float>
        var color: SIMD3<Float>
        var life: Float
        var intensity: Float
    }

    var particles: [Particle]

    init(particleCount: Int) {
        particles = (0..<particleCount).map { _ in
            Particle(
                position: SIMD3<Float>.random(in: -1...1),
                velocity: SIMD3<Float>.random(in: -0.1...0.1),
                color: SIMD3<Float>.random(in: 0.5...1),
                life: Float.random(in: 0.5...1),
                intensity: Float.random(in: 0.3...1)
            )
        }
    }

    func update(deltaTime: Float, field: EmulatorLightField?) {
        for i in 0..<particles.count {
            // Update position
            particles[i].position += particles[i].velocity * deltaTime

            // Update life
            particles[i].life -= deltaTime * 0.1

            // Respawn if dead
            if particles[i].life <= 0 {
                respawnParticle(at: i, field: field)
            }

            // Wrap around
            for j in 0..<3 {
                if particles[i].position[j] < -1 { particles[i].position[j] = 1 }
                if particles[i].position[j] > 1 { particles[i].position[j] = -1 }
            }

            // Apply field influence using coherence level
            if let field = field {
                let fieldInfluence = field.fieldCoherence * 0.5
                particles[i].velocity += SIMD3<Float>(fieldInfluence, fieldInfluence, 0) * 0.01
            }
        }
    }

    private func respawnParticle(at index: Int, field: EmulatorLightField?) {
        let randomPhoton = field?.photons.randomElement()

        particles[index] = Particle(
            position: randomPhoton?.position ?? SIMD3<Float>.random(in: -1...1),
            velocity: SIMD3<Float>.random(in: -0.1...0.1),
            color: randomPhoton?.color ?? SIMD3<Float>.random(in: 0.5...1),
            life: 1.0,
            intensity: Float.random(in: 0.5...1)
        )
    }
}
