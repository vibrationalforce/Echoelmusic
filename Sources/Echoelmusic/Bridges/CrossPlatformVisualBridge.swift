import Foundation
import Combine
import simd

#if canImport(Metal)
import Metal
import MetalKit
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// CROSS-PLATFORM VISUAL BRIDGE FOR ECHOELMUSIC
// ═══════════════════════════════════════════════════════════════════════════════
//
// Unified visual API that abstracts platform-specific implementations:
// • Apple Platforms: Metal + MetalFX
// • Android: Vulkan via JNI
// • Windows: DirectX 12 / Vulkan
// • Linux: Vulkan / OpenGL
//
// Features:
// • Audio-reactive visualizations
// • Particle systems
// • Shader-based effects
// • Performance-adaptive rendering
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Visual Bridge Configuration

public struct VisualBridgeConfig {
    public var targetFPS: Int = 60
    public var maxResolution: CGSize = CGSize(width: 1920, height: 1080)
    public var enableHDR: Bool = false
    public var enableBloom: Bool = true
    public var particleCount: Int = 5000
    public var antiAliasing: Int = 2
    public var vsyncEnabled: Bool = true
    public var preferredColorSpace: ColorSpace = .sRGB

    public enum ColorSpace: String {
        case sRGB = "sRGB"
        case displayP3 = "Display P3"
        case extendedLinear = "Extended Linear"
    }

    public init() {}
}

// MARK: - Cross-Platform Visual Bridge

@MainActor
public final class CrossPlatformVisualBridge: ObservableObject {

    // MARK: Singleton
    public static let shared = CrossPlatformVisualBridge()

    // MARK: Published State
    @Published public private(set) var isInitialized: Bool = false
    @Published public private(set) var isRendering: Bool = false
    @Published public private(set) var currentFPS: Double = 0
    @Published public private(set) var gpuUtilization: Double = 0
    @Published public private(set) var frameTime: Double = 0

    // MARK: Configuration
    @Published public var config: VisualBridgeConfig = VisualBridgeConfig()

    // MARK: Audio Reactivity
    @Published public var audioLevel: Float = 0
    @Published public var audioPeak: Float = 0
    @Published public var audioSpectrum: [Float] = []

    // MARK: Private
    #if canImport(Metal)
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var displayLink: CADisplayLink?
    #endif

    private var frameCount: Int = 0
    private var lastFPSUpdate: Date = Date()
    private var cancellables = Set<AnyCancellable>()

    // MARK: Initialization
    private init() {
        print("=== CrossPlatformVisualBridge Initialized ===")
    }

    // MARK: - Public API

    /// Initialize the visual system
    public func initialize(config: VisualBridgeConfig = VisualBridgeConfig()) async throws {
        self.config = config

        print("Initializing Visual Bridge...")
        print("  Target FPS: \(config.targetFPS)")
        print("  Max Resolution: \(Int(config.maxResolution.width))x\(Int(config.maxResolution.height))")

        #if canImport(Metal)
        try initializeMetal()
        #else
        try initializeNativeGraphics()
        #endif

        isInitialized = true
        print("Visual Bridge initialized successfully")
    }

    /// Start rendering
    public func startRendering() {
        guard isInitialized else { return }

        #if os(iOS) || os(tvOS)
        startDisplayLink()
        #elseif os(macOS)
        startDisplayLink()
        #else
        startNativeRenderLoop()
        #endif

        isRendering = true
        print("Visual rendering started")
    }

    /// Stop rendering
    public func stopRendering() {
        #if canImport(Metal)
        displayLink?.invalidate()
        displayLink = nil
        #endif

        isRendering = false
        print("Visual rendering stopped")
    }

    /// Update audio-reactive parameters
    public func updateAudioData(level: Float, peak: Float, spectrum: [Float]) {
        self.audioLevel = level
        self.audioPeak = peak
        self.audioSpectrum = spectrum
    }

    // MARK: - Metal Implementation

    #if canImport(Metal)
    private func initializeMetal() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw VisualBridgeError.noGPUDevice
        }

        self.device = device
        self.commandQueue = device.makeCommandQueue()

        print("  Metal Device: \(device.name)")
        print("  Max Threads Per Threadgroup: \(device.maxThreadsPerThreadgroup)")

        // Check capabilities
        let supportsFamily7 = device.supportsFamily(.apple7)
        let supportsMac2 = device.supportsFamily(.mac2)

        print("  Apple7 Family: \(supportsFamily7)")
        print("  Mac2 Family: \(supportsMac2)")
    }

    #if os(iOS) || os(tvOS)
    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(renderFrame))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 30,
            maximum: Float(config.targetFPS),
            preferred: Float(config.targetFPS)
        )
        displayLink?.add(to: .main, forMode: .common)
    }
    #elseif os(macOS)
    private func startDisplayLink() {
        // macOS uses CVDisplayLink, but for simplicity using timer
        Timer.publish(every: 1.0 / Double(config.targetFPS), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.renderFrame()
            }
            .store(in: &cancellables)
    }
    #endif

    @objc private func renderFrame() {
        guard isRendering else { return }

        let startTime = CACurrentMediaTime()

        // Perform render
        performRender()

        // Update frame timing
        let endTime = CACurrentMediaTime()
        frameTime = (endTime - startTime) * 1000  // Convert to ms

        // Update FPS counter
        frameCount += 1
        let elapsed = Date().timeIntervalSince(lastFPSUpdate)
        if elapsed >= 1.0 {
            currentFPS = Double(frameCount) / elapsed
            frameCount = 0
            lastFPSUpdate = Date()
        }
    }

    private func performRender() {
        guard let commandQueue = commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        // Render commands would go here
        // This is a placeholder for actual rendering

        commandBuffer.commit()
    }
    #endif

    // MARK: - Native Graphics Implementation

    private func initializeNativeGraphics() throws {
        #if os(Android)
        print("  Using Vulkan (Android)")
        #elseif os(Windows)
        print("  Using DirectX 12 / Vulkan (Windows)")
        #elseif os(Linux)
        print("  Using Vulkan / OpenGL (Linux)")
        #endif
    }

    private func startNativeRenderLoop() {
        // Native render loop for non-Apple platforms
    }

    // MARK: - Visualization Parameters

    /// Get visualization parameters based on audio input
    public func getVisualizationParams() -> VisualizationParams {
        return VisualizationParams(
            intensity: audioLevel,
            scale: 1.0 + audioPeak * 0.5,
            rotation: audioLevel * 360,
            colorShift: audioPeak,
            particleSpeed: 0.5 + audioLevel * 2.0,
            bloomIntensity: audioPeak * 2.0
        )
    }
}

// MARK: - Visualization Parameters

public struct VisualizationParams {
    public var intensity: Float = 0
    public var scale: Float = 1.0
    public var rotation: Float = 0
    public var colorShift: Float = 0
    public var particleSpeed: Float = 1.0
    public var bloomIntensity: Float = 0.5

    public init() {}

    public init(intensity: Float, scale: Float, rotation: Float, colorShift: Float, particleSpeed: Float, bloomIntensity: Float) {
        self.intensity = intensity
        self.scale = scale
        self.rotation = rotation
        self.colorShift = colorShift
        self.particleSpeed = particleSpeed
        self.bloomIntensity = bloomIntensity
    }
}

// MARK: - Visual Bridge Errors

public enum VisualBridgeError: Error, LocalizedError {
    case noGPUDevice
    case shaderCompilationFailed(String)
    case pipelineCreationFailed
    case textureCreationFailed
    case renderTargetCreationFailed

    public var errorDescription: String? {
        switch self {
        case .noGPUDevice:
            return "No GPU device available"
        case .shaderCompilationFailed(let message):
            return "Shader compilation failed: \(message)"
        case .pipelineCreationFailed:
            return "Render pipeline creation failed"
        case .textureCreationFailed:
            return "Texture creation failed"
        case .renderTargetCreationFailed:
            return "Render target creation failed"
        }
    }
}

// MARK: - Cross-Platform Particle System

/// Platform-agnostic particle system for visualizations
public final class CrossPlatformParticleSystem {

    // MARK: Particle Data
    public struct Particle {
        public var position: SIMD3<Float>
        public var velocity: SIMD3<Float>
        public var color: SIMD4<Float>
        public var size: Float
        public var life: Float
        public var maxLife: Float
    }

    // MARK: Properties
    private var particles: [Particle] = []
    private let maxParticles: Int
    private var emissionRate: Float = 100  // particles per second
    private var emissionAccumulator: Float = 0

    // MARK: Emitter Properties
    public var emitterPosition: SIMD3<Float> = .zero
    public var emitterVelocity: SIMD3<Float> = SIMD3(0, 1, 0)
    public var velocityRandomness: Float = 0.5
    public var colorStart: SIMD4<Float> = SIMD4(1, 1, 1, 1)
    public var colorEnd: SIMD4<Float> = SIMD4(1, 1, 1, 0)
    public var sizeStart: Float = 10
    public var sizeEnd: Float = 0
    public var lifeRange: ClosedRange<Float> = 1.0...3.0
    public var gravity: SIMD3<Float> = SIMD3(0, -1, 0)

    // MARK: Audio Reactivity
    public var audioIntensity: Float = 0 {
        didSet {
            emissionRate = 50 + audioIntensity * 500
        }
    }

    // MARK: Initialization
    public init(maxParticles: Int = 10000) {
        self.maxParticles = maxParticles
        particles.reserveCapacity(maxParticles)
    }

    // MARK: Update
    public func update(deltaTime: Float) {
        // Update existing particles
        var i = 0
        while i < particles.count {
            particles[i].life -= deltaTime

            if particles[i].life <= 0 {
                // Remove dead particle
                particles.swapAt(i, particles.count - 1)
                particles.removeLast()
                continue
            }

            // Update physics
            particles[i].velocity += gravity * deltaTime
            particles[i].position += particles[i].velocity * deltaTime

            // Update appearance based on life
            let lifeRatio = particles[i].life / particles[i].maxLife
            particles[i].color = simd_mix(colorEnd, colorStart, SIMD4(repeating: lifeRatio))
            particles[i].size = simd_mix(sizeEnd, sizeStart, lifeRatio)

            i += 1
        }

        // Emit new particles
        emissionAccumulator += emissionRate * deltaTime
        while emissionAccumulator >= 1.0 && particles.count < maxParticles {
            emitParticle()
            emissionAccumulator -= 1.0
        }
    }

    private func emitParticle() {
        let randomVelocity = SIMD3<Float>(
            Float.random(in: -velocityRandomness...velocityRandomness),
            Float.random(in: -velocityRandomness...velocityRandomness),
            Float.random(in: -velocityRandomness...velocityRandomness)
        )

        let life = Float.random(in: lifeRange)

        let particle = Particle(
            position: emitterPosition,
            velocity: emitterVelocity + randomVelocity,
            color: colorStart,
            size: sizeStart,
            life: life,
            maxLife: life
        )

        particles.append(particle)
    }

    // MARK: Accessors
    public var particleCount: Int { particles.count }
    public var allParticles: [Particle] { particles }

    /// Get particle data as flat array for GPU upload
    public func getPositionData() -> [Float] {
        var data = [Float]()
        data.reserveCapacity(particles.count * 3)
        for p in particles {
            data.append(p.position.x)
            data.append(p.position.y)
            data.append(p.position.z)
        }
        return data
    }

    public func getColorData() -> [Float] {
        var data = [Float]()
        data.reserveCapacity(particles.count * 4)
        for p in particles {
            data.append(p.color.x)
            data.append(p.color.y)
            data.append(p.color.z)
            data.append(p.color.w)
        }
        return data
    }

    // MARK: Presets
    public enum ParticlePreset {
        case fire
        case water
        case sparkle
        case smoke
        case energy
        case bioReactive

        public func apply(to system: CrossPlatformParticleSystem) {
            switch self {
            case .fire:
                system.colorStart = SIMD4(1, 0.5, 0, 1)
                system.colorEnd = SIMD4(1, 0, 0, 0)
                system.sizeStart = 20
                system.sizeEnd = 5
                system.gravity = SIMD3(0, 2, 0)
                system.lifeRange = 0.5...1.5

            case .water:
                system.colorStart = SIMD4(0.3, 0.5, 1, 0.8)
                system.colorEnd = SIMD4(0.1, 0.3, 0.8, 0)
                system.sizeStart = 10
                system.sizeEnd = 15
                system.gravity = SIMD3(0, -5, 0)
                system.lifeRange = 1.0...2.0

            case .sparkle:
                system.colorStart = SIMD4(1, 1, 1, 1)
                system.colorEnd = SIMD4(0.8, 0.8, 1, 0)
                system.sizeStart = 5
                system.sizeEnd = 0
                system.gravity = .zero
                system.lifeRange = 0.3...0.8

            case .smoke:
                system.colorStart = SIMD4(0.5, 0.5, 0.5, 0.5)
                system.colorEnd = SIMD4(0.3, 0.3, 0.3, 0)
                system.sizeStart = 30
                system.sizeEnd = 100
                system.gravity = SIMD3(0, 0.5, 0)
                system.lifeRange = 2.0...5.0

            case .energy:
                system.colorStart = SIMD4(0, 1, 1, 1)
                system.colorEnd = SIMD4(1, 0, 1, 0)
                system.sizeStart = 8
                system.sizeEnd = 2
                system.gravity = .zero
                system.lifeRange = 0.5...1.5

            case .bioReactive:
                // Colors change based on bio-data
                system.colorStart = SIMD4(0.2, 0.8, 0.4, 1)  // Calm green
                system.colorEnd = SIMD4(0.8, 0.2, 0.2, 0)    // Stress red
                system.sizeStart = 15
                system.sizeEnd = 5
                system.gravity = SIMD3(0, 0.5, 0)
                system.lifeRange = 1.0...3.0
            }
        }
    }

    public func applyPreset(_ preset: ParticlePreset) {
        preset.apply(to: self)
    }
}

// MARK: - Color Utilities

public enum ColorUtils {

    /// Convert HSV to RGB
    public static func hsvToRGB(h: Float, s: Float, v: Float) -> SIMD3<Float> {
        let c = v * s
        let x = c * (1 - abs(fmod(h / 60, 2) - 1))
        let m = v - c

        var rgb: SIMD3<Float>

        switch h {
        case 0..<60:
            rgb = SIMD3(c, x, 0)
        case 60..<120:
            rgb = SIMD3(x, c, 0)
        case 120..<180:
            rgb = SIMD3(0, c, x)
        case 180..<240:
            rgb = SIMD3(0, x, c)
        case 240..<300:
            rgb = SIMD3(x, 0, c)
        default:
            rgb = SIMD3(c, 0, x)
        }

        return rgb + SIMD3(repeating: m)
    }

    /// Get color for audio frequency band
    public static func colorForFrequency(_ normalizedFreq: Float) -> SIMD3<Float> {
        // Map frequency to hue (red = low, blue = high)
        let hue = normalizedFreq * 240  // 0-240 degrees
        return hsvToRGB(h: hue, s: 1.0, v: 1.0)
    }

    /// Get color for bio-data state
    public static func colorForBioState(hrv: Float, coherence: Float) -> SIMD3<Float> {
        // High HRV + High coherence = Green (calm)
        // Low HRV + Low coherence = Red (stress)
        let calmness = (hrv / 100 + coherence) / 2
        let hue = calmness * 120  // 0 (red) to 120 (green)
        return hsvToRGB(h: hue, s: 0.8, v: 0.9)
    }
}

// MARK: - Performance Monitor

/// Monitor visual performance across platforms
@MainActor
public final class VisualPerformanceMonitor: ObservableObject {

    @Published public private(set) var averageFPS: Double = 0
    @Published public private(set) var minFPS: Double = 0
    @Published public private(set) var maxFPS: Double = 0
    @Published public private(set) var frameTimeMs: Double = 0
    @Published public private(set) var gpuMemoryUsageMB: Double = 0

    private var frameTimes: [Double] = []
    private let maxSamples = 120  // 2 seconds at 60fps

    public init() {}

    public func recordFrame(timeMs: Double) {
        frameTimes.append(timeMs)
        if frameTimes.count > maxSamples {
            frameTimes.removeFirst()
        }

        // Update statistics
        frameTimeMs = timeMs
        let fps = 1000.0 / timeMs
        averageFPS = 1000.0 / (frameTimes.reduce(0, +) / Double(frameTimes.count))
        minFPS = 1000.0 / (frameTimes.max() ?? timeMs)
        maxFPS = 1000.0 / (frameTimes.min() ?? timeMs)
    }

    public func reset() {
        frameTimes.removeAll()
        averageFPS = 0
        minFPS = 0
        maxFPS = 0
        frameTimeMs = 0
    }
}
