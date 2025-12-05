import Foundation
import Metal
import MetalKit
import simd

// ═══════════════════════════════════════════════════════════════════════════════════════
// ╔═══════════════════════════════════════════════════════════════════════════════════╗
// ║               METAL SHADER LIBRARY - COMPLETE GPU IMPLEMENTATIONS                 ║
// ║                                                                                    ║
// ║   Full Metal shader implementations for:                                           ║
// ║   • Perlin/Simplex noise generation                                               ║
// ║   • Particle system compute shaders                                               ║
// ║   • Angular gradient rendering                                                    ║
// ║   • Audio visualization shaders                                                   ║
// ║   • Bio-reactive visual effects                                                   ║
// ║                                                                                    ║
// ╚═══════════════════════════════════════════════════════════════════════════════════╝
// ═══════════════════════════════════════════════════════════════════════════════════════

// MARK: - Shader Source Code

public enum MetalShaderSource {

    // MARK: - Perlin Noise Shader

    public static let perlinNoise = """
    #include <metal_stdlib>
    using namespace metal;

    // Permutation table
    constant int perm[512] = {
        151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,
        8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,
        35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,
        134,139,48,27,166,77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,
        55,46,245,40,244,102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,
        18,169,200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,
        250,124,123,5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,
        189,28,42,223,183,170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,
        172,9,129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,
        228,251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,
        107,49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,150,254,
        138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180,
        // Repeat
        151,160,137,91,90,15,131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,
        8,99,37,240,21,10,23,190,6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,
        35,11,32,57,177,33,88,237,149,56,87,174,20,125,136,171,168,68,175,74,165,71,
        134,139,48,27,166,77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,
        55,46,245,40,244,102,143,54,65,25,63,161,1,216,80,73,209,76,132,187,208,89,
        18,169,200,196,135,130,116,188,159,86,164,100,109,198,173,186,3,64,52,217,226,
        250,124,123,5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,
        189,28,42,223,183,170,213,119,248,152,2,44,154,163,70,221,153,101,155,167,43,
        172,9,129,22,39,253,19,98,108,110,79,113,224,232,178,185,112,104,218,246,97,
        228,251,34,242,193,238,210,144,12,191,179,162,241,81,51,145,235,249,14,239,
        107,49,192,214,31,181,199,106,157,184,84,204,176,115,121,50,45,127,4,150,254,
        138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
    };

    float fade(float t) {
        return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
    }

    float grad(int hash, float x, float y, float z) {
        int h = hash & 15;
        float u = h < 8 ? x : y;
        float v = h < 4 ? y : (h == 12 || h == 14 ? x : z);
        return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
    }

    float perlin3D(float x, float y, float z) {
        int X = int(floor(x)) & 255;
        int Y = int(floor(y)) & 255;
        int Z = int(floor(z)) & 255;

        x -= floor(x);
        y -= floor(y);
        z -= floor(z);

        float u = fade(x);
        float v = fade(y);
        float w = fade(z);

        int A = perm[X] + Y;
        int AA = perm[A] + Z;
        int AB = perm[A + 1] + Z;
        int B = perm[X + 1] + Y;
        int BA = perm[B] + Z;
        int BB = perm[B + 1] + Z;

        return mix(
            mix(mix(grad(perm[AA], x, y, z), grad(perm[BA], x-1, y, z), u),
                mix(grad(perm[AB], x, y-1, z), grad(perm[BB], x-1, y-1, z), u), v),
            mix(mix(grad(perm[AA+1], x, y, z-1), grad(perm[BA+1], x-1, y, z-1), u),
                mix(grad(perm[AB+1], x, y-1, z-1), grad(perm[BB+1], x-1, y-1, z-1), u), v), w);
    }

    float fbm(float x, float y, float z, int octaves, float persistence) {
        float total = 0.0;
        float frequency = 1.0;
        float amplitude = 1.0;
        float maxValue = 0.0;

        for (int i = 0; i < octaves; i++) {
            total += perlin3D(x * frequency, y * frequency, z * frequency) * amplitude;
            maxValue += amplitude;
            amplitude *= persistence;
            frequency *= 2.0;
        }

        return total / maxValue;
    }

    struct PerlinUniforms {
        float time;
        float scale;
        int octaves;
        float persistence;
        float4 colorLow;
        float4 colorHigh;
    };

    kernel void perlinNoiseKernel(
        texture2d<float, access::write> output [[texture(0)]],
        constant PerlinUniforms& uniforms [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        float2 size = float2(output.get_width(), output.get_height());
        float2 uv = float2(gid) / size;

        float noise = fbm(
            uv.x * uniforms.scale,
            uv.y * uniforms.scale,
            uniforms.time * 0.5,
            uniforms.octaves,
            uniforms.persistence
        );

        noise = noise * 0.5 + 0.5; // Map to 0-1

        float4 color = mix(uniforms.colorLow, uniforms.colorHigh, noise);
        output.write(color, gid);
    }
    """

    // MARK: - Particle System Shader

    public static let particleSystem = """
    #include <metal_stdlib>
    using namespace metal;

    struct Particle {
        float2 position;
        float2 velocity;
        float4 color;
        float size;
        float life;
        float maxLife;
        float rotation;
    };

    struct ParticleUniforms {
        float deltaTime;
        float2 gravity;
        float2 center;
        float centerForce;
        float turbulence;
        float coherence;
        float energy;
        float2 bounds;
    };

    // Hash function for pseudo-random
    float hash(float n) {
        return fract(sin(n) * 43758.5453);
    }

    kernel void updateParticles(
        device Particle* particles [[buffer(0)]],
        constant ParticleUniforms& uniforms [[buffer(1)]],
        uint id [[thread_position_in_grid]]
    ) {
        Particle p = particles[id];

        // Skip dead particles
        if (p.life <= 0) {
            // Respawn
            float seed = float(id) * 0.001;
            p.position = float2(
                hash(seed) * uniforms.bounds.x,
                hash(seed + 0.5) * uniforms.bounds.y
            );
            p.velocity = float2(
                (hash(seed + 1.0) - 0.5) * 2.0,
                (hash(seed + 1.5) - 0.5) * 2.0
            );
            p.life = p.maxLife;
            p.size = 4.0 + hash(seed + 2.0) * 8.0;
        }

        // Apply forces
        float2 toCenter = uniforms.center - p.position;
        float dist = length(toCenter);
        float2 centerPull = normalize(toCenter) * uniforms.centerForce / max(dist * 0.1, 1.0);

        // Turbulence based on coherence (less coherent = more chaos)
        float chaos = (1.0 - uniforms.coherence) * uniforms.turbulence;
        float2 turbulence = float2(
            sin(p.position.y * 0.1 + uniforms.deltaTime * 10.0),
            cos(p.position.x * 0.1 + uniforms.deltaTime * 10.0)
        ) * chaos;

        // Energy affects speed
        float speedMult = 0.5 + uniforms.energy * 1.5;

        // Update velocity
        p.velocity += uniforms.gravity * uniforms.deltaTime;
        p.velocity += centerPull * uniforms.deltaTime;
        p.velocity += turbulence * uniforms.deltaTime;
        p.velocity *= 0.99; // Damping

        // Update position
        p.position += p.velocity * uniforms.deltaTime * speedMult * 60.0;

        // Wrap around bounds
        if (p.position.x < 0) p.position.x += uniforms.bounds.x;
        if (p.position.x > uniforms.bounds.x) p.position.x -= uniforms.bounds.x;
        if (p.position.y < 0) p.position.y += uniforms.bounds.y;
        if (p.position.y > uniforms.bounds.y) p.position.y -= uniforms.bounds.y;

        // Update life
        p.life -= uniforms.deltaTime;

        // Update color based on coherence
        float lifeRatio = p.life / p.maxLife;
        float4 lowColor = float4(1.0, 0.2, 0.2, lifeRatio); // Red for low coherence
        float4 highColor = float4(0.2, 1.0, 0.4, lifeRatio); // Green for high coherence
        p.color = mix(lowColor, highColor, uniforms.coherence);

        // Update rotation
        p.rotation += length(p.velocity) * 0.1;

        particles[id] = p;
    }

    struct VertexOut {
        float4 position [[position]];
        float4 color;
        float size [[point_size]];
        float rotation;
    };

    vertex VertexOut particleVertex(
        const device Particle* particles [[buffer(0)]],
        constant float2& viewSize [[buffer(1)]],
        uint id [[vertex_id]]
    ) {
        Particle p = particles[id];

        VertexOut out;
        out.position = float4(
            (p.position.x / viewSize.x) * 2.0 - 1.0,
            1.0 - (p.position.y / viewSize.y) * 2.0,
            0.0,
            1.0
        );
        out.color = p.color;
        out.size = p.size * (p.life / p.maxLife);
        out.rotation = p.rotation;

        return out;
    }

    fragment float4 particleFragment(
        VertexOut in [[stage_in]],
        float2 pointCoord [[point_coord]]
    ) {
        // Circular particle with soft edges
        float2 center = pointCoord - 0.5;
        float dist = length(center);

        if (dist > 0.5) {
            discard_fragment();
        }

        float alpha = 1.0 - smoothstep(0.3, 0.5, dist);
        return float4(in.color.rgb, in.color.a * alpha);
    }
    """

    // MARK: - Angular Gradient Shader

    public static let angularGradient = """
    #include <metal_stdlib>
    using namespace metal;

    struct GradientUniforms {
        float2 center;
        float rotation;
        float4 colors[8];
        float stops[8];
        int colorCount;
        float time;
        float animationSpeed;
    };

    kernel void angularGradientKernel(
        texture2d<float, access::write> output [[texture(0)]],
        constant GradientUniforms& uniforms [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        float2 size = float2(output.get_width(), output.get_height());
        float2 uv = (float2(gid) / size) - uniforms.center;

        // Calculate angle
        float angle = atan2(uv.y, uv.x);
        angle = angle / (2.0 * M_PI_F) + 0.5; // Normalize to 0-1
        angle = fract(angle + uniforms.rotation + uniforms.time * uniforms.animationSpeed);

        // Find color stops
        float4 color = uniforms.colors[0];
        for (int i = 0; i < uniforms.colorCount - 1; i++) {
            if (angle >= uniforms.stops[i] && angle < uniforms.stops[i + 1]) {
                float t = (angle - uniforms.stops[i]) / (uniforms.stops[i + 1] - uniforms.stops[i]);
                color = mix(uniforms.colors[i], uniforms.colors[i + 1], t);
                break;
            }
        }

        output.write(color, gid);
    }
    """

    // MARK: - Audio Spectrum Visualizer

    public static let audioSpectrum = """
    #include <metal_stdlib>
    using namespace metal;

    struct SpectrumUniforms {
        float time;
        float4 lowColor;
        float4 midColor;
        float4 highColor;
        float smoothing;
        float barWidth;
        float gap;
        int style; // 0: bars, 1: wave, 2: circle
    };

    kernel void spectrumBarsKernel(
        texture2d<float, access::write> output [[texture(0)]],
        constant SpectrumUniforms& uniforms [[buffer(0)]],
        constant float* spectrum [[buffer(1)]],
        constant int& spectrumSize [[buffer(2)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        float2 size = float2(output.get_width(), output.get_height());
        float2 uv = float2(gid) / size;

        float totalWidth = uniforms.barWidth + uniforms.gap;
        int barIndex = int(uv.x / totalWidth * float(spectrumSize));
        float barX = fract(uv.x / totalWidth);

        if (barX > uniforms.barWidth / totalWidth || barIndex >= spectrumSize) {
            output.write(float4(0, 0, 0, 1), gid);
            return;
        }

        float value = spectrum[barIndex];
        float barHeight = value;

        if (uv.y > 1.0 - barHeight) {
            // Color based on frequency
            float freq = float(barIndex) / float(spectrumSize);
            float4 color;
            if (freq < 0.33) {
                color = mix(uniforms.lowColor, uniforms.midColor, freq * 3.0);
            } else if (freq < 0.66) {
                color = mix(uniforms.midColor, uniforms.highColor, (freq - 0.33) * 3.0);
            } else {
                color = uniforms.highColor;
            }

            // Gradient fade at top
            float fadeStart = 1.0 - barHeight * 0.9;
            float fade = smoothstep(fadeStart, 1.0 - barHeight, uv.y);
            color.a = 1.0 - fade * 0.5;

            output.write(color, gid);
        } else {
            output.write(float4(0, 0, 0, 1), gid);
        }
    }

    kernel void spectrumCircleKernel(
        texture2d<float, access::write> output [[texture(0)]],
        constant SpectrumUniforms& uniforms [[buffer(0)]],
        constant float* spectrum [[buffer(1)]],
        constant int& spectrumSize [[buffer(2)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        float2 size = float2(output.get_width(), output.get_height());
        float2 uv = (float2(gid) / size) * 2.0 - 1.0;
        uv.x *= size.x / size.y; // Aspect correction

        float angle = atan2(uv.y, uv.x);
        float normalizedAngle = (angle / M_PI_F + 1.0) * 0.5;
        int spectrumIndex = int(normalizedAngle * float(spectrumSize)) % spectrumSize;

        float dist = length(uv);
        float baseRadius = 0.3;
        float spectrumValue = spectrum[spectrumIndex];
        float maxRadius = baseRadius + spectrumValue * 0.4;

        if (dist > baseRadius && dist < maxRadius) {
            float freq = float(spectrumIndex) / float(spectrumSize);
            float4 color = mix(uniforms.lowColor, uniforms.highColor, freq);

            float edgeFade = 1.0 - smoothstep(maxRadius - 0.02, maxRadius, dist);
            color.a = edgeFade;

            output.write(color, gid);
        } else {
            output.write(float4(0, 0, 0, 0), gid);
        }
    }
    """

    // MARK: - Bio-Reactive Glow Shader

    public static let bioReactiveGlow = """
    #include <metal_stdlib>
    using namespace metal;

    struct BioUniforms {
        float coherence;    // 0-1
        float heartRate;    // normalized
        float hrv;          // normalized
        float breathPhase;  // 0-1 breathing cycle
        float time;
        float2 center;
    };

    float pulse(float t, float frequency) {
        return (sin(t * frequency * 2.0 * M_PI_F) + 1.0) * 0.5;
    }

    kernel void bioReactiveGlowKernel(
        texture2d<float, access::write> output [[texture(0)]],
        constant BioUniforms& uniforms [[buffer(0)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        float2 size = float2(output.get_width(), output.get_height());
        float2 uv = float2(gid) / size;
        float2 centered = uv - uniforms.center;
        centered.x *= size.x / size.y;

        float dist = length(centered);

        // Breathing ring
        float breathRadius = 0.3 + uniforms.breathPhase * 0.1;
        float breathRing = smoothstep(breathRadius + 0.05, breathRadius, dist) *
                          smoothstep(breathRadius - 0.15, breathRadius - 0.1, dist);

        // Heart pulse ring
        float heartPulse = pulse(uniforms.time, uniforms.heartRate * 2.0);
        float pulseRadius = 0.2 + heartPulse * 0.05;
        float pulseRing = smoothstep(pulseRadius + 0.02, pulseRadius, dist) *
                         smoothstep(pulseRadius - 0.1, pulseRadius - 0.05, dist);

        // Core glow
        float coreGlow = exp(-dist * 3.0);

        // Color based on coherence
        float3 lowCoherence = float3(1.0, 0.3, 0.2);   // Red
        float3 midCoherence = float3(1.0, 0.8, 0.2);   // Yellow
        float3 highCoherence = float3(0.2, 1.0, 0.4);  // Green

        float3 color;
        if (uniforms.coherence < 0.5) {
            color = mix(lowCoherence, midCoherence, uniforms.coherence * 2.0);
        } else {
            color = mix(midCoherence, highCoherence, (uniforms.coherence - 0.5) * 2.0);
        }

        // HRV affects color saturation
        float saturation = 0.7 + uniforms.hrv * 0.3;
        float3 gray = float3(dot(color, float3(0.299, 0.587, 0.114)));
        color = mix(gray, color, saturation);

        // Combine effects
        float intensity = coreGlow * 0.8 + breathRing * 0.5 + pulseRing * 0.3;
        intensity *= uniforms.coherence * 0.5 + 0.5; // Dim for low coherence

        float4 finalColor = float4(color * intensity, intensity);
        output.write(finalColor, gid);
    }
    """
}

// MARK: - Metal Shader Manager

@MainActor
public final class MetalShaderManager: ObservableObject {

    public static let shared = MetalShaderManager()

    @Published public private(set) var isReady: Bool = false

    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var library: MTLLibrary?

    // Compiled pipelines
    private var perlinPipeline: MTLComputePipelineState?
    private var particleUpdatePipeline: MTLComputePipelineState?
    private var particleRenderPipeline: MTLRenderPipelineState?
    private var gradientPipeline: MTLComputePipelineState?
    private var spectrumBarsPipeline: MTLComputePipelineState?
    private var spectrumCirclePipeline: MTLComputePipelineState?
    private var bioGlowPipeline: MTLComputePipelineState?

    private init() {
        setupMetal()
    }

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("Metal not available")
            return
        }

        self.device = device
        self.commandQueue = device.makeCommandQueue()

        Task {
            await compileShaders()
        }
    }

    private func compileShaders() async {
        guard let device = device else { return }

        do {
            // Compile Perlin noise shader
            let perlinSource = MetalShaderSource.perlinNoise
            let perlinLibrary = try device.makeLibrary(source: perlinSource, options: nil)
            if let perlinFunc = perlinLibrary.makeFunction(name: "perlinNoiseKernel") {
                perlinPipeline = try device.makeComputePipelineState(function: perlinFunc)
            }

            // Compile Particle shaders
            let particleSource = MetalShaderSource.particleSystem
            let particleLibrary = try device.makeLibrary(source: particleSource, options: nil)
            if let updateFunc = particleLibrary.makeFunction(name: "updateParticles") {
                particleUpdatePipeline = try device.makeComputePipelineState(function: updateFunc)
            }

            // Compile Angular gradient shader
            let gradientSource = MetalShaderSource.angularGradient
            let gradientLibrary = try device.makeLibrary(source: gradientSource, options: nil)
            if let gradientFunc = gradientLibrary.makeFunction(name: "angularGradientKernel") {
                gradientPipeline = try device.makeComputePipelineState(function: gradientFunc)
            }

            // Compile Spectrum shaders
            let spectrumSource = MetalShaderSource.audioSpectrum
            let spectrumLibrary = try device.makeLibrary(source: spectrumSource, options: nil)
            if let barsFunc = spectrumLibrary.makeFunction(name: "spectrumBarsKernel") {
                spectrumBarsPipeline = try device.makeComputePipelineState(function: barsFunc)
            }
            if let circleFunc = spectrumLibrary.makeFunction(name: "spectrumCircleKernel") {
                spectrumCirclePipeline = try device.makeComputePipelineState(function: circleFunc)
            }

            // Compile Bio-reactive shader
            let bioSource = MetalShaderSource.bioReactiveGlow
            let bioLibrary = try device.makeLibrary(source: bioSource, options: nil)
            if let bioFunc = bioLibrary.makeFunction(name: "bioReactiveGlowKernel") {
                bioGlowPipeline = try device.makeComputePipelineState(function: bioFunc)
            }

            isReady = true
            print("✅ Metal shaders compiled successfully")

        } catch {
            print("❌ Metal shader compilation failed: \(error)")
        }
    }

    // MARK: - Public API

    public func createPerlinNoiseTexture(
        width: Int,
        height: Int,
        time: Float,
        scale: Float = 4.0,
        octaves: Int = 4,
        persistence: Float = 0.5,
        colorLow: SIMD4<Float> = SIMD4(0, 0, 0.2, 1),
        colorHigh: SIMD4<Float> = SIMD4(0.2, 0.5, 1, 1)
    ) -> MTLTexture? {
        guard let device = device,
              let commandQueue = commandQueue,
              let pipeline = perlinPipeline else { return nil }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .shaderRead]

        guard let texture = device.makeTexture(descriptor: textureDescriptor),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }

        struct Uniforms {
            var time: Float
            var scale: Float
            var octaves: Int32
            var persistence: Float
            var colorLow: SIMD4<Float>
            var colorHigh: SIMD4<Float>
        }

        var uniforms = Uniforms(
            time: time,
            scale: scale,
            octaves: Int32(octaves),
            persistence: persistence,
            colorLow: colorLow,
            colorHigh: colorHigh
        )

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 0)

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return texture
    }

    public func createBioReactiveTexture(
        width: Int,
        height: Int,
        coherence: Float,
        heartRate: Float,
        hrv: Float,
        breathPhase: Float,
        time: Float
    ) -> MTLTexture? {
        guard let device = device,
              let commandQueue = commandQueue,
              let pipeline = bioGlowPipeline else { return nil }

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderWrite, .shaderRead]

        guard let texture = device.makeTexture(descriptor: textureDescriptor),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else { return nil }

        struct BioUniforms {
            var coherence: Float
            var heartRate: Float
            var hrv: Float
            var breathPhase: Float
            var time: Float
            var center: SIMD2<Float>
        }

        var uniforms = BioUniforms(
            coherence: coherence,
            heartRate: heartRate,
            hrv: hrv,
            breathPhase: breathPhase,
            time: time,
            center: SIMD2(0.5, 0.5)
        )

        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(texture, index: 0)
        encoder.setBytes(&uniforms, length: MemoryLayout<BioUniforms>.size, index: 0)

        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return texture
    }
}
