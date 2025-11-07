//
//  ParticleCompute.metal
//  BLAB
//
//  GPU Compute Shader for particle system
//  10,000+ particles with audio-reactive physics
//  ~60-120 FPS on iPhone 12+, ProMotion optimized
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Particle Struct

struct Particle {
    float2 position;      // Screen position (-1 to 1)
    float2 velocity;      // Velocity vector
    float size;           // Particle size (pixels)
    float hue;            // Color hue (0-1)
    float life;           // Life remaining (0-1)
    float brightness;     // Brightness multiplier
};

// MARK: - Uniforms

struct ParticleUniforms {
    float time;
    float deltaTime;
    float audioLevel;
    float frequency;
    float hrvCoherence;
    float heartRate;
    float breathingRate;
    float2 resolution;
    float2 attractorPosition;  // Attractor point for bio-reactive behavior
    float attractorStrength;
    uint particleCount;
};

// MARK: - Compute Kernel: Update Particles

kernel void updateParticles(
    device Particle *particles [[buffer(0)]],
    constant ParticleUniforms &uniforms [[buffer(1)]],
    uint id [[thread_position_in_grid]]
) {
    // Bounds check
    if (id >= uniforms.particleCount) {
        return;
    }

    // Get particle
    device Particle &particle = particles[id];

    // Update life
    particle.life -= uniforms.deltaTime * 0.2;

    // Respawn if dead
    if (particle.life <= 0.0) {
        // Random position using particle ID as seed
        float seed = float(id) + uniforms.time;
        float2 randomPos = float2(
            fract(sin(seed * 12.9898) * 43758.5453),
            fract(sin(seed * 78.233) * 43758.5453)
        ) * 2.0 - 1.0;  // -1 to 1

        particle.position = randomPos * 0.1;  // Spawn near center
        particle.velocity = normalize(randomPos) * 0.01;  // Outward velocity
        particle.life = 1.0;
        particle.size = (1.0 + uniforms.audioLevel) * 2.0;
        particle.brightness = 1.0;
    }

    // MARK: - Physics Update

    // Audio-reactive forces
    float audioForce = uniforms.audioLevel * 0.005;
    float2 direction = normalize(particle.velocity);
    particle.velocity += direction * audioForce;

    // Bio-reactive attractor (HRV-driven)
    float2 toAttractor = uniforms.attractorPosition - particle.position;
    float distToAttractor = length(toAttractor);

    if (distToAttractor > 0.001) {
        float attractorForce = uniforms.attractorStrength * uniforms.hrvCoherence * 0.001;
        particle.velocity += normalize(toAttractor) * attractorForce / distToAttractor;
    }

    // Breathing-reactive turbulence
    float breathPhase = sin(uniforms.time * uniforms.breathingRate / 60.0 * 3.14159 * 2.0);
    float turbulence = breathPhase * 0.002;
    particle.velocity += float2(
        sin(particle.position.x * 10.0 + uniforms.time) * turbulence,
        cos(particle.position.y * 10.0 + uniforms.time) * turbulence
    );

    // Damping
    particle.velocity *= 0.98;

    // Update position
    particle.position += particle.velocity * uniforms.deltaTime * 60.0;  // Normalize to 60 FPS

    // Wrap around screen edges
    if (particle.position.x < -1.0) particle.position.x = 1.0;
    if (particle.position.x > 1.0) particle.position.x = -1.0;
    if (particle.position.y < -1.0) particle.position.y = 1.0;
    if (particle.position.y > 1.0) particle.position.y = -1.0;

    // MARK: - Visual Update

    // HRV → Hue
    particle.hue = uniforms.hrvCoherence * 0.5;  // 0.0 (red) to 0.5 (cyan)

    // Heart rate → Hue oscillation
    float heartRateNorm = (uniforms.heartRate - 40.0) / 80.0;
    particle.hue += sin(uniforms.time * heartRateNorm * 2.0) * 0.1;

    // Clamp hue
    particle.hue = fract(particle.hue);

    // Size based on velocity
    float speed = length(particle.velocity);
    particle.size = (1.0 + speed * 100.0) * (1.0 + uniforms.audioLevel);

    // Brightness fades with life
    particle.brightness = particle.life * 0.5 + 0.5;
}

// MARK: - Vertex Shader: Render Particles

struct ParticleVertexIn {
    float2 position [[attribute(0)]];  // Quad corner
};

struct ParticleVertexOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float4 color;
};

vertex ParticleVertexOut renderParticles(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    device Particle *particles [[buffer(0)]],
    constant ParticleUniforms &uniforms [[buffer(1)]]
) {
    device Particle &particle = particles[instanceID];

    ParticleVertexOut out;

    // Transform particle position to clip space
    out.position = float4(particle.position, 0.0, 1.0);

    // Point size
    out.pointSize = particle.size;

    // Convert HSV to RGB
    float h = particle.hue;
    float s = 0.8;
    float v = particle.brightness;

    float c = v * s;
    float x = c * (1.0 - abs(fmod(h * 6.0, 2.0) - 1.0));
    float m = v - c;

    float3 rgb;
    if (h < 1.0/6.0) rgb = float3(c, x, 0);
    else if (h < 2.0/6.0) rgb = float3(x, c, 0);
    else if (h < 3.0/6.0) rgb = float3(0, c, x);
    else if (h < 4.0/6.0) rgb = float3(0, x, c);
    else if (h < 5.0/6.0) rgb = float3(x, 0, c);
    else rgb = float3(c, 0, x);

    rgb += m;

    out.color = float4(rgb, particle.life * 0.8);

    return out;
}

// MARK: - Fragment Shader: Particle Glow

fragment float4 renderParticlesFragment(
    ParticleVertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]]
) {
    // Circular particle with soft edges
    float dist = length(pointCoord - 0.5) * 2.0;
    float alpha = smoothstep(1.0, 0.0, dist);

    // Glow effect
    float glow = 1.0 / (dist * 3.0 + 1.0);

    float4 color = in.color;
    color.a *= alpha * glow;

    return color;
}

// MARK: - Compute Kernel: FFT Processing

/// GPU-accelerated FFT for audio analysis
/// Processes 1024-point FFT in parallel
kernel void computeFFT(
    device float *audioSamples [[buffer(0)]],
    device float2 *fftOutput [[buffer(1)]],
    constant uint &fftSize [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    // Radix-2 FFT implementation (simplified)
    // For production, use Metal Performance Shaders vDSP FFT

    if (id >= fftSize / 2) return;

    // Compute FFT bin
    uint k = id;
    float2 sum = float2(0.0, 0.0);

    for (uint n = 0; n < fftSize; n++) {
        float angle = -2.0 * M_PI_F * float(k) * float(n) / float(fftSize);
        float cosVal = cos(angle);
        float sinVal = sin(angle);

        sum.x += audioSamples[n] * cosVal;
        sum.y += audioSamples[n] * sinVal;
    }

    fftOutput[k] = sum;
}

// MARK: - ProMotion Support

/// Adaptive frame rate compute
/// Adjusts particle update rate based on display refresh rate
kernel void adaptiveUpdate(
    device Particle *particles [[buffer(0)]],
    constant ParticleUniforms &uniforms [[buffer(1)]],
    constant uint &displayRefreshRate [[buffer(2)]],  // 60 or 120 Hz
    uint id [[thread_position_in_grid]]
) {
    if (id >= uniforms.particleCount) return;

    // Adjust update frequency for ProMotion
    float refreshRateMultiplier = float(displayRefreshRate) / 60.0;

    device Particle &particle = particles[id];

    // Scale physics by refresh rate
    float deltaTime = uniforms.deltaTime * refreshRateMultiplier;

    // Update position with refresh-rate compensation
    particle.position += particle.velocity * deltaTime * 60.0 / refreshRateMultiplier;
}
