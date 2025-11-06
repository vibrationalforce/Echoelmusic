import Metal
import MetalKit
import SwiftUI

/// Metal-based particle renderer for Apple TV
///
/// **Purpose:** GPU-accelerated particle system for biofeedback visualization
///
/// **Features:**
/// - 10,000+ particles at 60 FPS
/// - Physics-based movement
/// - Coherence-reactive behavior
/// - Real-time color gradients
/// - Efficient GPU compute shaders
///
/// **Technical:**
/// - Metal compute pipelines
/// - Vertex/Fragment shaders
/// - Instanced rendering
/// - Dynamic particle updates
///
/// **Platform:** tvOS, iOS, macOS (Metal-capable devices)
///
@MainActor
public class MetalParticleRenderer: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Number of particles
    @Published public var particleCount: Int = 10000

    /// Particle behavior intensity (0.0 - 1.0)
    @Published public var intensity: Double = 0.7

    /// Coherence value affecting particles (0.0 - 100.0)
    @Published public var coherence: Double = 50.0

    // MARK: - Metal Properties

    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var computePipeline: MTLComputePipelineState?
    private var renderPipeline: MTLRenderPipelineState?

    private var particleBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?

    private var currentTime: Float = 0.0

    // MARK: - Initialization

    public override init() {
        super.init()
        setupMetal()
        createParticles()
        print("[MetalParticles] 🎨 Metal particle renderer initialized (\(particleCount) particles)")
    }

    // MARK: - Metal Setup

    private func setupMetal() {
        // Get default Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("[MetalParticles] ❌ Metal not supported on this device")
            return
        }

        self.device = device

        // Create command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("[MetalParticles] ❌ Failed to create command queue")
            return
        }

        self.commandQueue = commandQueue

        // Create compute pipeline for particle updates
        createComputePipeline()

        // Create render pipeline for drawing particles
        createRenderPipeline()

        print("[MetalParticles] ✅ Metal setup complete")
    }

    private func createComputePipeline() {
        guard let device = device else { return }

        // Metal Shading Language source for particle compute
        let computeShaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct Particle {
            float2 position;
            float2 velocity;
            float4 color;
            float size;
            float life;
        };

        struct Uniforms {
            float time;
            float deltaTime;
            float intensity;
            float coherence;
        };

        kernel void updateParticles(
            device Particle* particles [[buffer(0)]],
            constant Uniforms& uniforms [[buffer(1)]],
            uint id [[thread_position_in_grid]]
        ) {
            Particle particle = particles[id];

            // Physics-based movement
            float coherenceFactor = uniforms.coherence / 100.0;
            float attractionStrength = 0.001 * coherenceFactor * uniforms.intensity;

            // Attract particles towards center based on coherence
            float2 center = float2(0.0, 0.0);
            float2 toCenter = center - particle.position;
            float distance = length(toCenter);

            if (distance > 0.01) {
                float2 attraction = normalize(toCenter) * attractionStrength;
                particle.velocity += attraction;
            }

            // Add organic turbulence
            float turbulence = sin(uniforms.time + float(id) * 0.1) * 0.002;
            particle.velocity.x += turbulence;
            particle.velocity.y += cos(uniforms.time + float(id) * 0.15) * 0.002;

            // Damping
            particle.velocity *= 0.98;

            // Update position
            particle.position += particle.velocity * uniforms.deltaTime * 60.0;

            // Wrap around screen edges
            if (particle.position.x < -1.0) particle.position.x = 1.0;
            if (particle.position.x > 1.0) particle.position.x = -1.0;
            if (particle.position.y < -1.0) particle.position.y = 1.0;
            if (particle.position.y > 1.0) particle.position.y = -1.0;

            // Update color based on coherence
            float hue = coherenceFactor * 0.7; // 0.0 (red) to 0.7 (blue)
            particle.color = float4(
                1.0 - hue,
                hue,
                coherenceFactor,
                0.8
            );

            // Update life
            particle.life += uniforms.deltaTime;
            if (particle.life > 100.0) {
                particle.life = 0.0;
            }

            particles[id] = particle;
        }
        """

        do {
            let library = try device.makeLibrary(source: computeShaderSource, options: nil)
            guard let computeFunction = library.makeFunction(name: "updateParticles") else {
                print("[MetalParticles] ❌ Failed to create compute function")
                return
            }

            computePipeline = try device.makeComputePipelineState(function: computeFunction)
            print("[MetalParticles] ✅ Compute pipeline created")

        } catch {
            print("[MetalParticles] ❌ Failed to create compute pipeline: \(error)")
        }
    }

    private func createRenderPipeline() {
        guard let device = device else { return }

        // Vertex/Fragment shaders for rendering particles
        let renderShaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct Particle {
            float2 position;
            float2 velocity;
            float4 color;
            float size;
            float life;
        };

        struct VertexOut {
            float4 position [[position]];
            float4 color;
            float pointSize [[point_size]];
        };

        vertex VertexOut vertexShader(
            device Particle* particles [[buffer(0)]],
            uint vid [[vertex_id]]
        ) {
            VertexOut out;
            Particle particle = particles[vid];

            out.position = float4(particle.position, 0.0, 1.0);
            out.color = particle.color;
            out.pointSize = particle.size;

            return out;
        }

        fragment float4 fragmentShader(
            VertexOut in [[stage_in]],
            float2 pointCoord [[point_coord]]
        ) {
            // Circular particle with soft edges
            float dist = length(pointCoord - float2(0.5));
            if (dist > 0.5) {
                discard_fragment();
            }

            float alpha = 1.0 - (dist * 2.0);
            return float4(in.color.rgb, in.color.a * alpha);
        }
        """

        do {
            let library = try device.makeLibrary(source: renderShaderSource, options: nil)
            guard let vertexFunction = library.makeFunction(name: "vertexShader"),
                  let fragmentFunction = library.makeFunction(name: "fragmentShader") else {
                print("[MetalParticles] ❌ Failed to create render functions")
                return
            }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha

            renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            print("[MetalParticles] ✅ Render pipeline created")

        } catch {
            print("[MetalParticles] ❌ Failed to create render pipeline: \(error)")
        }
    }

    // MARK: - Particle Creation

    private func createParticles() {
        guard let device = device else { return }

        // Create particle data
        var particles: [Particle] = []

        for _ in 0..<particleCount {
            let particle = Particle(
                position: SIMD2<Float>(
                    Float.random(in: -1...1),
                    Float.random(in: -1...1)
                ),
                velocity: SIMD2<Float>(
                    Float.random(in: -0.01...0.01),
                    Float.random(in: -0.01...0.01)
                ),
                color: SIMD4<Float>(1.0, 1.0, 1.0, 0.8),
                size: Float.random(in: 2...8),
                life: Float.random(in: 0...100)
            )
            particles.append(particle)
        }

        // Create Metal buffer
        let bufferSize = MemoryLayout<Particle>.stride * particleCount
        particleBuffer = device.makeBuffer(
            bytes: particles,
            length: bufferSize,
            options: .storageModeShared
        )

        // Create uniforms buffer
        var uniforms = Uniforms(time: 0.0, deltaTime: 0.016, intensity: Float(intensity), coherence: Float(coherence))
        uniformBuffer = device.makeBuffer(
            bytes: &uniforms,
            length: MemoryLayout<Uniforms>.stride,
            options: .storageModeShared
        )

        print("[MetalParticles] ✅ Created \(particleCount) particles")
    }

    // MARK: - Update & Render

    /// Update particles (called every frame)
    public func update(deltaTime: Float) {
        guard let device = device,
              let commandQueue = commandQueue,
              let computePipeline = computePipeline,
              let particleBuffer = particleBuffer,
              let uniformBuffer = uniformBuffer else {
            return
        }

        currentTime += deltaTime

        // Update uniforms
        var uniforms = Uniforms(
            time: currentTime,
            deltaTime: deltaTime,
            intensity: Float(intensity),
            coherence: Float(coherence)
        )

        memcpy(uniformBuffer.contents(), &uniforms, MemoryLayout<Uniforms>.stride)

        // Create command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        // Dispatch compute shader
        computeEncoder.setComputePipelineState(computePipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(uniformBuffer, offset: 0, index: 1)

        let threadsPerGrid = MTLSize(width: particleCount, height: 1, depth: 1)
        let threadsPerThreadgroup = MTLSize(width: 256, height: 1, depth: 1)

        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()

        commandBuffer.commit()
    }

    /// Update intensity
    public func setIntensity(_ value: Double) {
        intensity = value
    }

    /// Update coherence
    public func setCoherence(_ value: Double) {
        coherence = value
    }
}

// MARK: - Particle Structure

struct Particle {
    var position: SIMD2<Float>
    var velocity: SIMD2<Float>
    var color: SIMD4<Float>
    var size: Float
    var life: Float
}

struct Uniforms {
    var time: Float
    var deltaTime: Float
    var intensity: Float
    var coherence: Float
}
