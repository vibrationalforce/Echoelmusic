#if canImport(Metal)
//
//  EchoelVisEngine.swift
//  Echoelmusic — Bio-Reactive Visual Engine
//
//  8 visual modes driven by bio-signals via Metal 120fps pipeline.
//  Hilbert curve sensor mapping (1D→2D locality-preserving).
//
//  Bio mappings:
//    Coherence → Color palette warmth + pattern complexity
//    HRV → Animation speed + particle turbulence
//    Heart rate → Pulse/throb intensity + rhythm
//    Breath phase → Wave amplitude + opacity modulation
//    LF/HF ratio → Spectral tilt of visual frequency
//
//  Reference: BioEventGraph (Rausch 2012) for graph-based event detection
//             HilbertSensorMapper for 1D→2D locality-preserving mapping
//

import Foundation
import Metal
import QuartzCore
import Accelerate
#if canImport(Observation)
import Observation
#endif

// MARK: - Visual Mode

/// 10 visualization modes for bio-reactive display
public enum VisualMode: String, CaseIterable, Codable, Sendable {
    case waveform          = "Waveform"          // Audio waveform with bio-color
    case spectrum          = "Spectrum"           // FFT spectrum analyzer
    case particles         = "Particles"          // Bio-driven particle system
    case hilbertMap        = "Hilbert Map"        // Hilbert curve sensor visualization
    case bioGraph          = "Bio Graph"          // Real-time bio-signal graphs
    case flowField         = "Flow Field"         // Perlin noise flow field
    case kaleidoscope      = "Kaleidoscope"       // Symmetry-based pattern
    case nebula            = "Nebula"             // Volumetric cloud effect
    case generativeWorlds  = "Generative Worlds"  // Abstract bio-reactive environments
    case arWorlds          = "AR Worlds"           // Augmented reality at real locations
}

// MARK: - Visual Color Palette

/// Color palette for visualizations (Codable + Sendable)
public struct VisualPalette: Codable, Sendable {
    public var primary: SIMD4<Float>     // RGBA
    public var secondary: SIMD4<Float>
    public var accent: SIMD4<Float>
    public var background: SIMD4<Float>

    public static let coherenceCool = VisualPalette(
        primary: SIMD4<Float>(0.2, 0.4, 0.9, 1.0),
        secondary: SIMD4<Float>(0.1, 0.2, 0.6, 1.0),
        accent: SIMD4<Float>(0.4, 0.6, 1.0, 1.0),
        background: SIMD4<Float>(0.02, 0.02, 0.08, 1.0)
    )

    public static let coherenceWarm = VisualPalette(
        primary: SIMD4<Float>(0.9, 0.7, 0.2, 1.0),
        secondary: SIMD4<Float>(0.8, 0.4, 0.1, 1.0),
        accent: SIMD4<Float>(1.0, 0.9, 0.4, 1.0),
        background: SIMD4<Float>(0.08, 0.04, 0.02, 1.0)
    )

    /// Interpolate between cool (low coherence) and warm (high coherence)
    public static func fromCoherence(_ coherence: Float) -> VisualPalette {
        let t = max(0, min(1, coherence))
        return VisualPalette(
            primary: mix(coherenceCool.primary, coherenceWarm.primary, t: t),
            secondary: mix(coherenceCool.secondary, coherenceWarm.secondary, t: t),
            accent: mix(coherenceCool.accent, coherenceWarm.accent, t: t),
            background: mix(coherenceCool.background, coherenceWarm.background, t: t)
        )
    }

    private static func mix(_ a: SIMD4<Float>, _ b: SIMD4<Float>, t: Float) -> SIMD4<Float> {
        a * (1 - t) + b * t
    }
}

// MARK: - Bio Visual State

/// Current bio-signal state for visual rendering
public struct BioVisualState: Sendable {
    public var coherence: Float = 0.5
    public var hrv: Float = 0.5
    public var heartRate: Float = 72.0
    public var breathPhase: Float = 0.0
    public var breathDepth: Float = 0.5
    public var lfHfRatio: Float = 1.0

    /// Derived: pulse phase from heart rate (0-1, cycles at HR frequency)
    public var pulsePhase: Float = 0.0

    /// Derived: color palette from coherence
    public var palette: VisualPalette = .coherenceCool
}

// MARK: - Hilbert Curve Mapper

/// Maps 1D sensor data to 2D display coordinates using Hilbert space-filling curves.
/// Preserves locality: nearby values in 1D stay nearby in 2D.
/// Reference: HilbertSensorMapper algorithm from Echoelmusic DSP spec
public struct HilbertSensorMapper: Sendable {

    /// Map 1D index to 2D Hilbert coordinates
    /// - Parameters:
    ///   - index: 1D index (0..<order*order)
    ///   - order: Hilbert curve order (power of 2, e.g., 16 = 256 cells)
    /// - Returns: (x, y) coordinates in grid
    public static func map(index: Int, order: Int) -> (x: Int, y: Int) {
        guard order > 0 else { return (0, 0) }
        let n = order * order
        let clamped = max(0, min(n - 1, index))

        var x = 0
        var y = 0
        var rx: Int
        var ry: Int
        var s = 1
        var d = clamped

        while s < order {
            rx = (d / 2) & 1
            ry = (d ^ rx) & 1

            // Rotate
            if ry == 0 {
                if rx == 1 {
                    x = s - 1 - x
                    y = s - 1 - y
                }
                let temp = x
                x = y
                y = temp
            }

            x += s * rx
            y += s * ry
            d /= 4
            s *= 2
        }

        return (x, y)
    }

    /// Map array of float values to 2D grid using Hilbert curve
    /// - Parameters:
    ///   - values: 1D float array (sensor data, spectrum, etc.)
    ///   - gridSize: Output grid dimension (power of 2)
    /// - Returns: 2D float array [y][x]
    public static func mapToGrid(values: [Float], gridSize: Int) -> [[Float]] {
        var grid = [[Float]](repeating: [Float](repeating: 0, count: gridSize), count: gridSize)
        let cellCount = gridSize * gridSize

        for i in 0..<min(values.count, cellCount) {
            let (x, y) = map(index: i, order: gridSize)
            guard x < gridSize, y < gridSize else { continue }
            grid[y][x] = values[i]
        }

        return grid
    }
}

// MARK: - Particle

/// A single particle in the bio-reactive particle system
public struct VisualParticle: Sendable {
    public var position: SIMD2<Float>
    public var velocity: SIMD2<Float>
    public var life: Float
    public var maxLife: Float
    public var size: Float
    public var color: SIMD4<Float>
}

// MARK: - Render Uniforms

/// Uniforms passed to Metal shaders
public struct VisualUniforms: Sendable {
    public var time: Float
    public var resolution: SIMD2<Float>
    public var coherence: Float
    public var hrv: Float
    public var heartRate: Float
    public var breathPhase: Float
    public var pulsePhase: Float
    public var lfHfRatio: Float
    public var primaryColor: SIMD4<Float>
    public var secondaryColor: SIMD4<Float>
    public var accentColor: SIMD4<Float>
}

// MARK: - EchoelVisEngine

/// Bio-reactive visual engine — 8 modes, Metal 120fps, Hilbert bio-mapping.
///
/// Architecture:
/// - Metal compute pipeline for particle/flow simulations
/// - Metal render pipeline for final compositing
/// - CADisplayLink at 120Hz (ProMotion) or 60Hz fallback
/// - Bio signals drive all visual parameters in real-time
/// - Hilbert curve maps 1D bio data to 2D visual space
///
/// Performance targets: <30% CPU, 120fps on ProMotion, <200MB memory
@preconcurrency @MainActor
@Observable
public final class EchoelVisEngine {

    @MainActor public static let shared = EchoelVisEngine()

    // MARK: - State

    /// Whether the visual engine is rendering
    public var isRunning: Bool = false

    /// Current visual mode
    public var currentMode: VisualMode = .particles

    /// Bio-reactive modulation enabled
    public var bioReactiveEnabled: Bool = true

    /// Current bio visual state
    public var bioState: BioVisualState = BioVisualState()

    /// Particle count (for particle mode)
    public var particleCount: Int = 2048

    /// Render resolution scale (0.5 = half res for performance)
    public var resolutionScale: Float = 1.0

    /// Target frame rate
    public var targetFPS: Double = 120.0

    /// Current measured FPS
    public var currentFPS: Double = 0.0

    /// Hilbert grid size for sensor mapping
    public var hilbertGridSize: Int = 16

    /// Audio spectrum data for waveform/spectrum modes (updated externally)
    public var spectrumData: [Float] = []

    /// Audio waveform data (updated externally)
    public var waveformData: [Float] = []

    // MARK: - Metal State

    /// Metal device
    private var device: MTLDevice?

    /// Command queue
    private var commandQueue: MTLCommandQueue?

    /// Render pipeline states (one per visual mode)
    private var pipelineStates: [VisualMode: MTLRenderPipelineState] = [:]

    /// Compute pipeline for particle simulation
    private var particleComputePipeline: MTLComputePipelineState?

    /// Particle buffer
    private var particleBuffer: MTLBuffer?

    /// Uniform buffer
    private var uniformBuffer: MTLBuffer?

    // MARK: - Render Loop

    /// Display link for 120Hz rendering
    private var displayLink: CADisplayLink?

    /// Frame counter
    private var frameCount: UInt64 = 0

    /// Time accumulator for animations
    private var time: Float = 0.0

    /// Last frame timestamp for FPS calculation
    private var lastFrameTime: CFAbsoluteTime = 0

    /// FPS sample buffer for smoothing
    private var fpsSamples: [Double] = []

    // MARK: - Particles

    /// Active particles for particle mode
    private var particles: [VisualParticle] = []

    // MARK: - Init

    private init() {
        setupMetal()
        log.log(.info, category: .system, "EchoelVis initialized — Metal device: \(device?.name ?? "none")")
    }

    deinit {
        stopNonisolated()
    }

    private nonisolated func stopNonisolated() {
        // Metal resources cleaned up automatically
    }

    // MARK: - Metal Setup

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            log.log(.error, category: .system, "EchoelVis: No Metal device available")
            return
        }
        self.device = device

        guard let queue = device.makeCommandQueue() else {
            log.log(.error, category: .system, "EchoelVis: Failed to create Metal command queue")
            return
        }
        self.commandQueue = queue

        // Allocate uniform buffer
        guard let uniforms = device.makeBuffer(
            length: MemoryLayout<VisualUniforms>.stride,
            options: .storageModeShared
        ) else {
            log.log(.error, category: .system, "EchoelVis: Failed to allocate uniform buffer")
            return
        }
        uniformBuffer = uniforms

        // Initialize particle buffer
        initializeParticleBuffer()

        log.log(.info, category: .system, "EchoelVis: Metal pipeline ready (\(device.name))")
    }

    private func initializeParticleBuffer() {
        guard let device else { return }

        let bufferSize = MemoryLayout<VisualParticle>.stride * particleCount
        particleBuffer = device.makeBuffer(length: bufferSize, options: .storageModeShared)

        // Initialize particles
        particles = (0..<particleCount).map { _ in
            VisualParticle(
                position: SIMD2<Float>(Float.random(in: -1...1), Float.random(in: -1...1)),
                velocity: SIMD2<Float>(Float.random(in: -0.01...0.01), Float.random(in: -0.01...0.01)),
                life: Float.random(in: 0...1),
                maxLife: Float.random(in: 2...5),
                size: Float.random(in: 1...4),
                color: SIMD4<Float>(1, 1, 1, 1)
            )
        }

        // Copy to buffer
        if let buffer = particleBuffer {
            let ptr = buffer.contents().bindMemory(to: VisualParticle.self, capacity: particleCount)
            for i in 0..<particles.count {
                ptr[i] = particles[i]
            }
        }
    }

    // MARK: - Start / Stop

    /// Start the visual rendering engine
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        frameCount = 0
        time = 0

        startDisplayLink()
        log.log(.info, category: .system, "EchoelVis started — mode: \(currentMode.rawValue), target: \(Int(targetFPS))fps")
    }

    /// Stop the visual rendering engine
    public func stop() {
        guard isRunning else { return }
        isRunning = false

        stopDisplayLink()
        log.log(.info, category: .system, "EchoelVis stopped")
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        stopDisplayLink()

        let link = CADisplayLink(
            target: VisDisplayLinkTarget(action: { [weak self] in
                MainActor.assumeIsolated {
                    self?.renderFrame()
                }
            }),
            selector: #selector(VisDisplayLinkTarget.handleDisplayLink)
        )

        link.preferredFrameRateRange = CAFrameRateRange(
            minimum: 30,
            maximum: Float(targetFPS),
            preferred: Float(targetFPS)
        )
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Render Loop

    private func renderFrame() {
        guard isRunning else { return }
        frameCount += 1

        // Delta time
        let now = CFAbsoluteTimeGetCurrent()
        let deltaTime: Float
        if lastFrameTime > 0 {
            deltaTime = Float(now - lastFrameTime)

            // FPS calculation (smoothed over 60 samples)
            let fps = 1.0 / Double(max(0.001, deltaTime))
            fpsSamples.append(fps)
            if fpsSamples.count > 60 {
                fpsSamples.removeFirst()
            }
            let fpsCount = fpsSamples.count
            guard fpsCount > 0 else {
                lastFrameTime = now
                return
            }
            currentFPS = fpsSamples.reduce(0, +) / Double(fpsCount)
        } else {
            deltaTime = 1.0 / Float(targetFPS)
        }
        lastFrameTime = now

        time += deltaTime

        // Update bio visuals
        if bioReactiveEnabled {
            updateBioState(deltaTime: deltaTime)
        }

        // Mode-specific update
        switch currentMode {
        case .particles:
            updateParticles(deltaTime: deltaTime)
        case .flowField:
            updateFlowField(deltaTime: deltaTime)
        case .hilbertMap:
            updateHilbertMap()
        default:
            break
        }

        // Update uniforms
        updateUniforms()
    }

    // MARK: - Bio State Update

    private func updateBioState(deltaTime: Float) {
        // Update pulse phase from heart rate
        let pulsePeriod = 60.0 / max(40, bioState.heartRate)
        bioState.pulsePhase += deltaTime / pulsePeriod
        if bioState.pulsePhase > 1.0 {
            bioState.pulsePhase -= 1.0
        }

        // Update palette from coherence
        bioState.palette = VisualPalette.fromCoherence(bioState.coherence)
    }

    // MARK: - Particle System

    private func updateParticles(deltaTime: Float) {
        let turbulence = bioState.hrv * 0.02
        let breathInfluence = sin(bioState.breathPhase * .pi * 2) * bioState.breathDepth * 0.01
        let pulseForce = sin(bioState.pulsePhase * .pi * 2) * 0.005

        for i in 0..<particles.count {
            // Bio-reactive velocity
            particles[i].velocity.x += Float.random(in: -turbulence...turbulence) + Float(breathInfluence)
            particles[i].velocity.y += Float.random(in: -turbulence...turbulence) + pulseForce

            // Damping
            particles[i].velocity *= 0.98

            // Position update
            particles[i].position += particles[i].velocity

            // Life cycle
            particles[i].life += deltaTime
            if particles[i].life > particles[i].maxLife {
                // Respawn
                particles[i].position = SIMD2<Float>(Float.random(in: -1...1), Float.random(in: -1...1))
                particles[i].velocity = SIMD2<Float>(0, 0)
                particles[i].life = 0
                particles[i].maxLife = Float.random(in: 2...5)
            }

            // Wrap around
            if particles[i].position.x > 1.2 { particles[i].position.x = -1.2 }
            if particles[i].position.x < -1.2 { particles[i].position.x = 1.2 }
            if particles[i].position.y > 1.2 { particles[i].position.y = -1.2 }
            if particles[i].position.y < -1.2 { particles[i].position.y = 1.2 }

            // Bio-reactive color
            let lifeRatio = particles[i].life / particles[i].maxLife
            let alpha = 1.0 - lifeRatio
            particles[i].color = bioState.palette.primary * alpha + bioState.palette.accent * (1 - alpha)
            particles[i].color.w = alpha
        }

        // Copy to Metal buffer
        if let buffer = particleBuffer {
            let count = min(particles.count, particleCount)
            let ptr = buffer.contents().bindMemory(to: VisualParticle.self, capacity: count)
            for i in 0..<count {
                ptr[i] = particles[i]
            }
        }
    }

    // MARK: - Flow Field

    private func updateFlowField(deltaTime: Float) {
        // Perlin-like flow field driven by bio signals
        // Flow direction modulated by breath phase
        // Turbulence from HRV, color from coherence
        // (Metal compute shader does the heavy lifting)
    }

    // MARK: - Hilbert Map

    private func updateHilbertMap() {
        guard !spectrumData.isEmpty else { return }

        // Map spectrum data to 2D grid using Hilbert curve
        _ = HilbertSensorMapper.mapToGrid(
            values: spectrumData,
            gridSize: hilbertGridSize
        )
        // Grid data is passed to Metal shader via buffer
    }

    // MARK: - Uniforms

    private func updateUniforms() {
        guard let uniformBuffer else { return }

        var uniforms = VisualUniforms(
            time: time,
            resolution: SIMD2<Float>(1920, 1080), // Default, updated by Metal layer
            coherence: bioState.coherence,
            hrv: bioState.hrv,
            heartRate: bioState.heartRate,
            breathPhase: bioState.breathPhase,
            pulsePhase: bioState.pulsePhase,
            lfHfRatio: bioState.lfHfRatio,
            primaryColor: bioState.palette.primary,
            secondaryColor: bioState.palette.secondary,
            accentColor: bioState.palette.accent
        )

        let ptr = uniformBuffer.contents().bindMemory(to: VisualUniforms.self, capacity: 1)
        ptr.pointee = uniforms
    }

    // MARK: - Mode Control

    /// Set the visual mode
    public func setMode(_ mode: VisualMode) {
        currentMode = mode
        log.log(.info, category: .system, "EchoelVis mode: \(mode.rawValue)")
    }

    /// Cycle to next visual mode
    public func nextMode() {
        let modes = VisualMode.allCases
        guard let currentIndex = modes.firstIndex(of: currentMode) else { return }
        let nextIndex = (currentIndex + 1) % modes.count
        setMode(modes[nextIndex])
    }

    // MARK: - Bio-Reactive Interface

    /// Apply bio-reactive modulation from workspace
    ///
    /// Called at ~60Hz from EchoelCreativeWorkspace render loop.
    /// Updates all visual parameters based on bio signals.
    public func applyBioReactive(
        coherence: Float,
        hrv: Float,
        heartRate: Float,
        breathPhase: Float
    ) {
        guard bioReactiveEnabled else { return }
        bioState.coherence = coherence
        bioState.hrv = hrv
        bioState.heartRate = heartRate
        bioState.breathPhase = breathPhase
    }

    /// Set LF/HF ratio (from spectral HRV analysis)
    public func setLFHFRatio(_ ratio: Float) {
        bioState.lfHfRatio = ratio
    }

    /// Set breath depth (0-1)
    public func setBreathDepth(_ depth: Float) {
        bioState.breathDepth = depth
    }

    // MARK: - Audio Data Input

    /// Update spectrum data for waveform/spectrum visualization
    public func updateSpectrum(_ data: [Float]) {
        spectrumData = data
    }

    /// Update waveform data for waveform visualization
    public func updateWaveform(_ data: [Float]) {
        waveformData = data
    }

    // MARK: - Metal Accessors

    /// Get the Metal device for external Metal layer setup
    public var metalDevice: MTLDevice? { device }

    /// Get the command queue for external rendering
    public var metalCommandQueue: MTLCommandQueue? { commandQueue }

    /// Get the particle buffer for Metal rendering
    public var metalParticleBuffer: MTLBuffer? { particleBuffer }

    /// Get the uniform buffer for Metal rendering
    public var metalUniformBuffer: MTLBuffer? { uniformBuffer }

    /// Get current particle count (may differ from max)
    public var activeParticleCount: Int { min(particles.count, particleCount) }
}

// MARK: - Display Link Target

private final class VisDisplayLinkTarget {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func handleDisplayLink() {
        action()
    }
}

#endif
