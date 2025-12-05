import Foundation
#if canImport(Metal)
import Metal
import MetalKit
import simd
#endif

// MARK: - Physics Visual Engine (Antigravity/Particle Systems)
// Advanced physics simulation for visual effects
// Inspired by Google's research on visual physics and particle dynamics

@MainActor
public final class PhysicsVisualEngine: ObservableObject {
    public static let shared = PhysicsVisualEngine()

    @Published public private(set) var isRunning = false
    @Published public private(set) var particleCount: Int = 0
    @Published public private(set) var fps: Double = 60
    @Published public private(set) var activeForces: [PhysicsForce] = []

    // Metal rendering
    #if canImport(Metal)
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var particleBuffer: MTLBuffer?
    private var forceBuffer: MTLBuffer?
    private var computePipeline: MTLComputePipelineState?
    private var renderPipeline: MTLRenderPipelineState?
    #endif

    // Particle systems
    private var particleSystems: [ParticleSystem] = []
    private var globalForces: [PhysicsForce] = []

    // Audio reactivity
    private var audioReactive = false
    private var audioData: AudioVisualizationData?

    // Configuration
    public struct Configuration {
        public var maxParticles: Int = 100000
        public var simulationSteps: Int = 4
        public var gravity: SIMD3<Float> = SIMD3(0, -9.81, 0)
        public var enableCollisions: Bool = true
        public var enableAudioReactivity: Bool = true
        public var targetFPS: Double = 60

        public static let `default` = Configuration()
        public static let highPerformance = Configuration(maxParticles: 1000000, simulationSteps: 8)
        public static let mobile = Configuration(maxParticles: 10000, simulationSteps: 2)
    }

    private var config: Configuration = .default

    public init() {
        setupMetal()
    }

    // MARK: - Setup

    private func setupMetal() {
        #if canImport(Metal)
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal not available")
            return
        }

        self.device = device
        self.commandQueue = device.makeCommandQueue()

        // Create particle buffer
        let particleSize = MemoryLayout<Particle>.stride * config.maxParticles
        particleBuffer = device.makeBuffer(length: particleSize, options: .storageModeShared)

        // Create force buffer
        let forceSize = MemoryLayout<ForceData>.stride * 32
        forceBuffer = device.makeBuffer(length: forceSize, options: .storageModeShared)

        // Load compute shader
        setupComputePipeline()
        #endif
    }

    #if canImport(Metal)
    private func setupComputePipeline() {
        guard let device = device else { return }

        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct Particle {
            float3 position;
            float3 velocity;
            float3 acceleration;
            float4 color;
            float size;
            float life;
            float mass;
            uint flags;
        };

        struct Force {
            float3 position;
            float3 direction;
            float strength;
            float radius;
            uint type; // 0=gravity, 1=point, 2=vortex, 3=turbulence, 4=antigravity
        };

        struct SimParams {
            float deltaTime;
            float3 globalGravity;
            uint particleCount;
            uint forceCount;
            uint simSteps;
        };

        kernel void updateParticles(
            device Particle* particles [[buffer(0)]],
            constant Force* forces [[buffer(1)]],
            constant SimParams& params [[buffer(2)]],
            uint id [[thread_position_in_grid]]
        ) {
            if (id >= params.particleCount) return;

            Particle p = particles[id];

            if (p.life <= 0) return;

            // Reset acceleration
            p.acceleration = float3(0);

            // Apply global gravity
            p.acceleration += params.globalGravity;

            // Apply forces
            for (uint f = 0; f < params.forceCount; f++) {
                Force force = forces[f];
                float3 toForce = force.position - p.position;
                float dist = length(toForce);

                if (dist > force.radius && force.radius > 0) continue;

                float3 dir = normalize(toForce);
                float falloff = force.radius > 0 ? 1.0 - (dist / force.radius) : 1.0;

                switch (force.type) {
                    case 0: // Directional gravity
                        p.acceleration += force.direction * force.strength;
                        break;

                    case 1: // Point attractor
                        p.acceleration += dir * force.strength * falloff / max(dist * dist, 0.01);
                        break;

                    case 2: // Vortex
                        float3 tangent = cross(dir, float3(0, 1, 0));
                        p.acceleration += tangent * force.strength * falloff;
                        break;

                    case 3: // Turbulence (simplified noise)
                        float noise = sin(p.position.x * 10 + p.position.y * 7 + p.position.z * 13);
                        p.acceleration += float3(noise, noise * 0.5, noise * 0.3) * force.strength;
                        break;

                    case 4: // Antigravity (repulsion from point)
                        p.acceleration -= dir * force.strength * falloff / max(dist * dist, 0.01);
                        break;

                    case 5: // Magnetic field
                        float3 magnetic = cross(p.velocity, force.direction);
                        p.acceleration += magnetic * force.strength;
                        break;
                }
            }

            // Integration (Verlet)
            float dt = params.deltaTime / float(params.simSteps);
            for (uint s = 0; s < params.simSteps; s++) {
                p.velocity += p.acceleration * dt;
                p.position += p.velocity * dt;

                // Damping
                p.velocity *= 0.999;
            }

            // Update life
            p.life -= params.deltaTime;

            // Fade color with life
            p.color.a = min(p.life, 1.0);

            particles[id] = p;
        }
        """

        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            if let function = library.makeFunction(name: "updateParticles") {
                computePipeline = try device.makeComputePipelineState(function: function)
            }
        } catch {
            print("Failed to create compute pipeline: \(error)")
        }
    }
    #endif

    // MARK: - Simulation Control

    /// Start physics simulation
    public func start() {
        isRunning = true
        startSimulationLoop()
    }

    /// Stop physics simulation
    public func stop() {
        isRunning = false
    }

    private var displayLink: Timer?

    private func startSimulationLoop() {
        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / config.targetFPS, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
    }

    private func update() {
        guard isRunning else { return }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Update audio data if reactive
        if audioReactive {
            updateAudioReactivity()
        }

        // Run physics simulation
        #if canImport(Metal)
        runSimulation()
        #endif

        // Update particle count
        particleCount = particleSystems.reduce(0) { $0 + $1.activeParticles }

        // Calculate FPS
        let frameTime = CFAbsoluteTimeGetCurrent() - startTime
        fps = 1.0 / max(frameTime, 0.001)
    }

    #if canImport(Metal)
    private func runSimulation() {
        guard let commandQueue = commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let computePipeline = computePipeline,
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        encoder.setComputePipelineState(computePipeline)
        encoder.setBuffer(particleBuffer, offset: 0, index: 0)
        encoder.setBuffer(forceBuffer, offset: 0, index: 1)

        // Set simulation parameters
        var params = SimParams(
            deltaTime: Float(1.0 / config.targetFPS),
            globalGravity: config.gravity,
            particleCount: UInt32(particleCount),
            forceCount: UInt32(globalForces.count),
            simSteps: UInt32(config.simulationSteps)
        )

        encoder.setBytes(&params, length: MemoryLayout<SimParams>.stride, index: 2)

        let threadGroupSize = MTLSize(width: 256, height: 1, depth: 1)
        let threadGroups = MTLSize(
            width: (particleCount + 255) / 256,
            height: 1,
            depth: 1
        )

        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
    }
    #endif

    // MARK: - Particle Systems

    /// Create a new particle system
    public func createParticleSystem(
        name: String,
        emitter: ParticleEmitter,
        maxParticles: Int = 10000
    ) -> ParticleSystem {
        let system = ParticleSystem(
            id: UUID(),
            name: name,
            emitter: emitter,
            maxParticles: maxParticles
        )
        particleSystems.append(system)
        return system
    }

    /// Remove particle system
    public func removeParticleSystem(_ id: UUID) {
        particleSystems.removeAll { $0.id == id }
    }

    // MARK: - Forces

    /// Add a physics force
    public func addForce(_ force: PhysicsForce) {
        globalForces.append(force)
        activeForces = globalForces
        updateForceBuffer()
    }

    /// Remove a force
    public func removeForce(_ id: UUID) {
        globalForces.removeAll { $0.id == id }
        activeForces = globalForces
        updateForceBuffer()
    }

    /// Create antigravity zone
    public func createAntigravityZone(
        position: SIMD3<Float>,
        radius: Float,
        strength: Float
    ) -> PhysicsForce {
        let force = PhysicsForce(
            id: UUID(),
            type: .antigravity,
            position: position,
            direction: SIMD3(0, 1, 0),
            strength: strength,
            radius: radius
        )
        addForce(force)
        return force
    }

    /// Create vortex
    public func createVortex(
        position: SIMD3<Float>,
        axis: SIMD3<Float>,
        strength: Float,
        radius: Float
    ) -> PhysicsForce {
        let force = PhysicsForce(
            id: UUID(),
            type: .vortex,
            position: position,
            direction: normalize(axis),
            strength: strength,
            radius: radius
        )
        addForce(force)
        return force
    }

    /// Create point attractor
    public func createAttractor(
        position: SIMD3<Float>,
        strength: Float,
        radius: Float
    ) -> PhysicsForce {
        let force = PhysicsForce(
            id: UUID(),
            type: .pointAttractor,
            position: position,
            direction: SIMD3(0, 0, 0),
            strength: strength,
            radius: radius
        )
        addForce(force)
        return force
    }

    private func updateForceBuffer() {
        #if canImport(Metal)
        guard let forceBuffer = forceBuffer else { return }

        let forces = globalForces.prefix(32).map { force -> ForceData in
            ForceData(
                position: force.position,
                direction: force.direction,
                strength: force.strength,
                radius: force.radius,
                type: force.type.rawValue
            )
        }

        let pointer = forceBuffer.contents().bindMemory(to: ForceData.self, capacity: 32)
        for (i, force) in forces.enumerated() {
            pointer[i] = force
        }
        #endif
    }

    // MARK: - Audio Reactivity

    /// Enable audio reactivity
    public func enableAudioReactivity(_ enabled: Bool) {
        audioReactive = enabled
    }

    /// Update with audio data
    public func setAudioData(_ data: AudioVisualizationData) {
        audioData = data
    }

    private func updateAudioReactivity() {
        guard let audio = audioData else { return }

        // Modulate forces based on audio
        for i in 0..<globalForces.count {
            switch globalForces[i].type {
            case .antigravity:
                // Antigravity pulses with bass
                globalForces[i].strength = globalForces[i].baseStrength * (1 + audio.bass * 2)

            case .vortex:
                // Vortex speed with mid frequencies
                globalForces[i].strength = globalForces[i].baseStrength * (1 + audio.mid * 1.5)

            case .turbulence:
                // Turbulence intensity with high frequencies
                globalForces[i].strength = globalForces[i].baseStrength * (1 + audio.high * 3)

            default:
                break
            }
        }

        // Update particle emission rate based on level
        for i in 0..<particleSystems.count {
            particleSystems[i].emitter.rate = particleSystems[i].emitter.baseRate * (1 + audio.level * 2)
        }

        updateForceBuffer()
    }

    // MARK: - Presets

    /// Load preset effect
    public func loadPreset(_ preset: PhysicsPreset) {
        // Clear existing
        globalForces.removeAll()
        particleSystems.removeAll()

        switch preset {
        case .starfield:
            createStarfieldPreset()
        case .galaxy:
            createGalaxyPreset()
        case .explosion:
            createExplosionPreset()
        case .rain:
            createRainPreset()
        case .fire:
            createFirePreset()
        case .aurora:
            createAuroraPreset()
        case .antigravityField:
            createAntigravityFieldPreset()
        case .blackHole:
            createBlackHolePreset()
        case .dnaHelix:
            createDNAHelixPreset()
        }
    }

    public enum PhysicsPreset: String, CaseIterable {
        case starfield, galaxy, explosion, rain, fire, aurora
        case antigravityField, blackHole, dnaHelix
    }

    private func createStarfieldPreset() {
        let emitter = ParticleEmitter(
            position: SIMD3(0, 0, -100),
            shape: .sphere(radius: 50),
            rate: 100,
            lifetime: 10,
            speed: 20,
            color: SIMD4(1, 1, 1, 1),
            size: 0.5
        )
        _ = createParticleSystem(name: "Stars", emitter: emitter)
    }

    private func createGalaxyPreset() {
        let emitter = ParticleEmitter(
            position: SIMD3(0, 0, 0),
            shape: .disk(radius: 30),
            rate: 500,
            lifetime: 20,
            speed: 5,
            color: SIMD4(0.8, 0.9, 1, 1),
            size: 0.3
        )
        _ = createParticleSystem(name: "Galaxy", emitter: emitter)
        _ = createVortex(position: SIMD3(0, 0, 0), axis: SIMD3(0, 1, 0), strength: 10, radius: 50)
        _ = createAttractor(position: SIMD3(0, 0, 0), strength: 5, radius: 100)
    }

    private func createExplosionPreset() {
        let emitter = ParticleEmitter(
            position: SIMD3(0, 0, 0),
            shape: .point,
            rate: 10000,
            lifetime: 2,
            speed: 50,
            color: SIMD4(1, 0.5, 0, 1),
            size: 1
        )
        _ = createParticleSystem(name: "Explosion", emitter: emitter, maxParticles: 50000)
    }

    private func createRainPreset() {
        let emitter = ParticleEmitter(
            position: SIMD3(0, 50, 0),
            shape: .rectangle(width: 100, height: 100),
            rate: 1000,
            lifetime: 3,
            speed: 30,
            color: SIMD4(0.7, 0.8, 1, 0.5),
            size: 0.1
        )
        _ = createParticleSystem(name: "Rain", emitter: emitter)
        config.gravity = SIMD3(0, -20, 0)
    }

    private func createFirePreset() {
        let emitter = ParticleEmitter(
            position: SIMD3(0, 0, 0),
            shape: .disk(radius: 2),
            rate: 500,
            lifetime: 1.5,
            speed: 10,
            color: SIMD4(1, 0.3, 0, 1),
            size: 2
        )
        _ = createParticleSystem(name: "Fire", emitter: emitter)
        config.gravity = SIMD3(0, 5, 0) // Upward
        _ = PhysicsForce(id: UUID(), type: .turbulence, position: SIMD3(0, 5, 0), direction: SIMD3(0, 0, 0), strength: 5, radius: 20)
    }

    private func createAuroraPreset() {
        let emitter = ParticleEmitter(
            position: SIMD3(0, 30, 0),
            shape: .line(start: SIMD3(-50, 30, 0), end: SIMD3(50, 30, 0)),
            rate: 200,
            lifetime: 5,
            speed: 2,
            color: SIMD4(0.2, 1, 0.5, 0.5),
            size: 3
        )
        _ = createParticleSystem(name: "Aurora", emitter: emitter)
        _ = PhysicsForce(id: UUID(), type: .turbulence, position: SIMD3(0, 30, 0), direction: SIMD3(0, 0, 0), strength: 3, radius: 100)
    }

    private func createAntigravityFieldPreset() {
        let emitter = ParticleEmitter(
            position: SIMD3(0, -20, 0),
            shape: .disk(radius: 20),
            rate: 300,
            lifetime: 8,
            speed: 5,
            color: SIMD4(0.5, 0.8, 1, 1),
            size: 1
        )
        _ = createParticleSystem(name: "Antigravity", emitter: emitter)
        _ = createAntigravityZone(position: SIMD3(0, 10, 0), radius: 30, strength: 20)
    }

    private func createBlackHolePreset() {
        let emitter = ParticleEmitter(
            position: SIMD3(0, 0, 0),
            shape: .sphere(radius: 50),
            rate: 500,
            lifetime: 10,
            speed: 2,
            color: SIMD4(1, 0.8, 0.5, 1),
            size: 0.5
        )
        _ = createParticleSystem(name: "BlackHole", emitter: emitter)
        _ = createAttractor(position: SIMD3(0, 0, 0), strength: 100, radius: 0)
        _ = createVortex(position: SIMD3(0, 0, 0), axis: SIMD3(0, 1, 0), strength: 20, radius: 30)
    }

    private func createDNAHelixPreset() {
        let emitter1 = ParticleEmitter(
            position: SIMD3(0, -20, 0),
            shape: .helix(radius: 5, pitch: 10),
            rate: 100,
            lifetime: 5,
            speed: 10,
            color: SIMD4(1, 0.2, 0.2, 1),
            size: 1
        )
        let emitter2 = ParticleEmitter(
            position: SIMD3(0, -20, 0),
            shape: .helix(radius: 5, pitch: 10, offset: Float.pi),
            rate: 100,
            lifetime: 5,
            speed: 10,
            color: SIMD4(0.2, 0.2, 1, 1),
            size: 1
        )
        _ = createParticleSystem(name: "DNA1", emitter: emitter1)
        _ = createParticleSystem(name: "DNA2", emitter: emitter2)
    }

    public func configure(_ config: Configuration) {
        self.config = config
    }
}

// MARK: - Particle

public struct Particle {
    public var position: SIMD3<Float>
    public var velocity: SIMD3<Float>
    public var acceleration: SIMD3<Float>
    public var color: SIMD4<Float>
    public var size: Float
    public var life: Float
    public var mass: Float
    public var flags: UInt32
}

// MARK: - Particle System

public class ParticleSystem: Identifiable {
    public let id: UUID
    public var name: String
    public var emitter: ParticleEmitter
    public let maxParticles: Int
    public var activeParticles: Int = 0
    public var enabled: Bool = true
}

// MARK: - Particle Emitter

public struct ParticleEmitter {
    public var position: SIMD3<Float>
    public var shape: EmitterShape
    public var rate: Float
    public var baseRate: Float
    public var lifetime: Float
    public var speed: Float
    public var color: SIMD4<Float>
    public var size: Float

    public enum EmitterShape {
        case point
        case sphere(radius: Float)
        case disk(radius: Float)
        case rectangle(width: Float, height: Float)
        case line(start: SIMD3<Float>, end: SIMD3<Float>)
        case helix(radius: Float, pitch: Float, offset: Float = 0)
    }

    public init(
        position: SIMD3<Float>,
        shape: EmitterShape,
        rate: Float,
        lifetime: Float,
        speed: Float,
        color: SIMD4<Float>,
        size: Float
    ) {
        self.position = position
        self.shape = shape
        self.rate = rate
        self.baseRate = rate
        self.lifetime = lifetime
        self.speed = speed
        self.color = color
        self.size = size
    }
}

// MARK: - Physics Force

public struct PhysicsForce: Identifiable {
    public let id: UUID
    public var type: ForceType
    public var position: SIMD3<Float>
    public var direction: SIMD3<Float>
    public var strength: Float
    public var baseStrength: Float
    public var radius: Float

    public enum ForceType: UInt32 {
        case gravity = 0
        case pointAttractor = 1
        case vortex = 2
        case turbulence = 3
        case antigravity = 4
        case magnetic = 5
    }

    public init(
        id: UUID,
        type: ForceType,
        position: SIMD3<Float>,
        direction: SIMD3<Float>,
        strength: Float,
        radius: Float
    ) {
        self.id = id
        self.type = type
        self.position = position
        self.direction = direction
        self.strength = strength
        self.baseStrength = strength
        self.radius = radius
    }
}

// MARK: - Metal Structures

#if canImport(Metal)
struct SimParams {
    var deltaTime: Float
    var globalGravity: SIMD3<Float>
    var particleCount: UInt32
    var forceCount: UInt32
    var simSteps: UInt32
}

struct ForceData {
    var position: SIMD3<Float>
    var direction: SIMD3<Float>
    var strength: Float
    var radius: Float
    var type: UInt32
}
#endif

// MARK: - Audio Visualization Data

public struct AudioVisualizationData {
    public var level: Float
    public var bass: Float
    public var mid: Float
    public var high: Float
    public var spectrum: [Float]
    public var beatPhase: Float
    public var isBeat: Bool
}
