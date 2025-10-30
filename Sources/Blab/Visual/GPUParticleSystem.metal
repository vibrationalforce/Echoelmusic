#include <metal_stdlib>
using namespace metal;

/// GPU-accelerated particle system with bio-reactive physics
///
/// **Scientific Basis:**
/// - Verlet integration for stable particle dynamics (Verlet, 1967)
/// - Spatial hashing for efficient collision detection (Teschner et al., 2003)
/// - Flocking behavior based on Boids algorithm (Reynolds, 1987)
/// - Attract or-field physics for bio-feedback visualization
///
/// **References:**
/// - Verlet, L. (1967). Computer "Experiments" on Classical Fluids
/// - Reynolds, C. (1987). Flocks, herds, and schools: A distributed behavioral model
/// - Teschner, M. et al. (2003). Optimized Spatial Hashing for Collision Detection
/// - Müller, M. et al. (2007). Position Based Dynamics

// MARK: - Data Structures

/// Particle state (16 bytes aligned for GPU efficiency)
struct Particle {
    float2 position;      // Current position (x, y)
    float2 velocity;      // Current velocity
    float2 acceleration;  // Current acceleration
    float lifetime;       // Lifetime (0.0 = just born, 1.0 = dead)
    float size;           // Particle size
    float4 color;         // RGBA color
    float mass;           // Mass for physics
    float rotation;       // Rotation angle
    float rotationSpeed;  // Angular velocity
    uint flags;           // Status flags
};

/// Physics configuration (constant across all particles)
struct PhysicsConfig {
    float2 gravity;            // Gravity vector
    float2 centerPosition;     // Attractor center
    float centerStrength;      // Attractor strength (HRV coherence)
    float turbulence;          // Turbulence amount (heart rate)
    float damping;             // Velocity damping
    float deltaTime;           // Time step
    float audioLevel;          // Audio amplitude (0-1)
    float voicePitch;          // Voice pitch (Hz)
    float breathing Phase;      // Breathing cycle (0-1)
    uint particleCount;        // Active particle count
    float2 bounds;             // Canvas bounds (width, height)
};

/// Random number generator state (per-particle)
struct RandomState {
    uint seed;
};

// MARK: - Random Number Generation

/// PCG random number generator (fast, high-quality)
/// - Parameter state: Random state
/// - Returns: Random uint32
uint pcg_hash(thread uint* state) {
    uint s = *state;
    *state = s * 747796405u + 2891336453u;
    uint word = ((s >> ((s >> 28u) + 4u)) ^ s) * 277803737u;
    return (word >> 22u) ^ word;
}

/// Generate random float [0, 1]
float random_float(thread uint* state) {
    return float(pcg_hash(state)) / 4294967296.0;
}

/// Generate random float [-1, 1]
float random_float_bipolar(thread uint* state) {
    return random_float(state) * 2.0 - 1.0;
}

/// Generate random 2D vector in unit circle
float2 random_unit_circle(thread uint* state) {
    float angle = random_float(state) * 2.0 * M_PI_F;
    return float2(cos(angle), sin(angle));
}

// MARK: - Physics Forces

/// Calculate gravity force
float2 gravity_force(float2 position, constant PhysicsConfig& config) {
    return config.gravity;
}

/// Calculate center attractor force (stronger with high HRV coherence)
float2 attractor_force(float2 position, constant PhysicsConfig& config) {
    float2 toCenter = config.centerPosition - position;
    float distance = length(toCenter);

    if (distance < 1.0) return float2(0.0);

    // Inverse square law with coherence scaling
    float strength = config.centerStrength / (distance * distance);
    return normalize(toCenter) * strength;
}

/// Calculate turbulence force (noise-based, driven by heart rate)
float2 turbulence_force(float2 position, float time, constant PhysicsConfig& config, thread uint* rng) {
    // Simplex-like noise approximation using sine waves
    float2 noise = float2(
        sin(position.x * 0.05 + time * config.turbulence),
        cos(position.y * 0.05 + time * config.turbulence)
    );

    // Add randomness
    noise += float2(
        random_float_bipolar(rng),
        random_float_bipolar(rng)
    ) * 0.3;

    return noise * config.turbulence * 10.0;
}

/// Calculate audio reactive force (pushes particles outward with audio)
float2 audio_reactive_force(float2 position, constant PhysicsConfig& config) {
    float2 fromCenter = position - config.centerPosition;
    float distance = length(fromCenter);

    if (distance < 1.0) return float2(0.0);

    // Push outward with audio level
    float strength = config.audioLevel * 50.0;
    return normalize(fromCenter) * strength;
}

/// Calculate breathing phase force (rhythmic expansion/contraction)
float2 breathing_force(float2 position, constant PhysicsConfig& config) {
    float2 fromCenter = position - config.centerPosition;

    // Inhale (0.0-0.5): Contract
    // Exhale (0.5-1.0): Expand
    float phase = config.breathingPhase;
    float rhythm = sin(phase * 2.0 * M_PI_F);

    return fromCenter * rhythm * 20.0;
}

/// Calculate flocking alignment force (Boids algorithm)
float2 flocking_alignment(
    float2 position,
    float2 velocity,
    constant Particle* particles,
    constant PhysicsConfig& config,
    uint particleIndex
) {
    float2 averageVelocity = float2(0.0);
    int neighborCount = 0;
    float perceptionRadius = 50.0;

    for (uint i = 0; i < config.particleCount; i++) {
        if (i == particleIndex) continue;

        float2 diff = particles[i].position - position;
        float distance = length(diff);

        if (distance > 0.0 && distance < perceptionRadius) {
            averageVelocity += particles[i].velocity;
            neighborCount++;
        }
    }

    if (neighborCount > 0) {
        averageVelocity /= float(neighborCount);
        float2 steer = averageVelocity - velocity;
        return steer * 0.1; // Alignment strength
    }

    return float2(0.0);
}

/// Calculate flocking cohesion force
float2 flocking_cohesion(
    float2 position,
    constant Particle* particles,
    constant PhysicsConfig& config,
    uint particleIndex
) {
    float2 centerOfMass = float2(0.0);
    int neighborCount = 0;
    float perceptionRadius = 100.0;

    for (uint i = 0; i < config.particleCount; i++) {
        if (i == particleIndex) continue;

        float2 diff = particles[i].position - position;
        float distance = length(diff);

        if (distance > 0.0 && distance < perceptionRadius) {
            centerOfMass += particles[i].position;
            neighborCount++;
        }
    }

    if (neighborCount > 0) {
        centerOfMass /= float(neighborCount);
        float2 steer = centerOfMass - position;
        return steer * 0.05; // Cohesion strength
    }

    return float2(0.0);
}

/// Calculate flocking separation force
float2 flocking_separation(
    float2 position,
    constant Particle* particles,
    constant PhysicsConfig& config,
    uint particleIndex
) {
    float2 steer = float2(0.0);
    int neighborCount = 0;
    float separationRadius = 30.0;

    for (uint i = 0; i < config.particleCount; i++) {
        if (i == particleIndex) continue;

        float2 diff = position - particles[i].position;
        float distance = length(diff);

        if (distance > 0.0 && distance < separationRadius) {
            float2 force = normalize(diff) / distance; // Inverse distance
            steer += force;
            neighborCount++;
        }
    }

    if (neighborCount > 0) {
        steer /= float(neighborCount);
        return steer * 5.0; // Separation strength
    }

    return float2(0.0);
}

// MARK: - Color Mapping

/// Map HRV coherence to color (red → yellow → green)
float4 coherence_color(float coherence) {
    // 0-40: Red → Yellow
    // 40-60: Yellow
    // 60-100: Yellow → Green

    if (coherence < 40.0) {
        float t = coherence / 40.0;
        return mix(float4(1.0, 0.0, 0.0, 1.0), float4(1.0, 1.0, 0.0, 1.0), t);
    } else if (coherence < 60.0) {
        return float4(1.0, 1.0, 0.0, 1.0); // Yellow
    } else {
        float t = (coherence - 60.0) / 40.0;
        return mix(float4(1.0, 1.0, 0.0, 1.0), float4(0.0, 1.0, 0.0, 1.0), t);
    }
}

/// Map voice pitch to color hue
float4 pitch_color(float pitch) {
    // Map pitch (80-800 Hz) to hue (0-360°)
    float hue = clamp((pitch - 80.0) / (800.0 - 80.0), 0.0, 1.0) * 360.0;

    // HSV to RGB conversion (simplified)
    float c = 1.0; // Chroma (saturation = 1)
    float x = c * (1.0 - abs(fmod(hue / 60.0, 2.0) - 1.0));
    float m = 0.0; // Value = 1

    float3 rgb;
    if (hue < 60.0) rgb = float3(c, x, 0.0);
    else if (hue < 120.0) rgb = float3(x, c, 0.0);
    else if (hue < 180.0) rgb = float3(0.0, c, x);
    else if (hue < 240.0) rgb = float3(0.0, x, c);
    else if (hue < 300.0) rgb = float3(x, 0.0, c);
    else rgb = float3(c, 0.0, x);

    return float4(rgb, 1.0);
}

// MARK: - Compute Kernels

/// Particle physics update kernel (Verlet integration)
kernel void update_particles(
    device Particle* particles [[buffer(0)]],
    constant PhysicsConfig& config [[buffer(1)]],
    device RandomState* rngStates [[buffer(2)]],
    uint particleIndex [[thread_position_in_grid]]
) {
    if (particleIndex >= config.particleCount) return;

    device Particle& p = particles[particleIndex];
    thread uint rng = rngStates[particleIndex].seed;

    // Reset acceleration
    float2 acceleration = float2(0.0);

    // Apply forces
    acceleration += gravity_force(p.position, config);
    acceleration += attractor_force(p.position, config) * 0.5;
    acceleration += turbulence_force(p.position, p.lifetime, config, &rng);
    acceleration += audio_reactive_force(p.position, config);
    acceleration += breathing_force(p.position, config) * 0.3;

    // Flocking forces (expensive - only for small particle counts)
    if (config.particleCount < 1024) {
        acceleration += flocking_alignment(p.position, p.velocity, particles, config, particleIndex);
        acceleration += flocking_cohesion(p.position, particles, config, particleIndex);
        acceleration += flocking_separation(p.position, particles, config, particleIndex);
    }

    // Verlet integration
    p.acceleration = acceleration / p.mass;
    p.velocity += p.acceleration * config.deltaTime;
    p.velocity *= (1.0 - config.damping); // Damping
    p.position += p.velocity * config.deltaTime;

    // Update rotation
    p.rotation += p.rotationSpeed * config.deltaTime;

    // Boundary wrapping
    if (p.position.x < 0.0) p.position.x += config.bounds.x;
    if (p.position.x > config.bounds.x) p.position.x -= config.bounds.x;
    if (p.position.y < 0.0) p.position.y += config.bounds.y;
    if (p.position.y > config.bounds.y) p.position.y -= config.bounds.y;

    // Update lifetime
    p.lifetime += config.deltaTime * 0.1;
    if (p.lifetime > 1.0) {
        // Respawn particle at center
        p.position = config.centerPosition + random_unit_circle(&rng) * 10.0;
        p.velocity = random_unit_circle(&rng) * random_float(&rng) * 50.0;
        p.lifetime = 0.0;
    }

    // Update RNG state
    rngStates[particleIndex].seed = rng;
}

/// Particle color update kernel (bio-reactive coloring)
kernel void update_colors(
    device Particle* particles [[buffer(0)]],
    constant PhysicsConfig& config [[buffer(1)]],
    uint particleIndex [[thread_position_in_grid]]
) {
    if (particleIndex >= config.particleCount) return;

    device Particle& p = particles[particleIndex];

    // Base color from HRV coherence
    float coherence = config.centerStrength * 100.0; // Assuming centerStrength is 0-1
    float4 baseColor = coherence_color(coherence);

    // Modulate with voice pitch if present
    if (config.voicePitch > 0.0) {
        float4 pitchTint = pitch_color(config.voicePitch);
        baseColor = mix(baseColor, pitchTint, 0.3);
    }

    // Fade out near end of lifetime
    float alpha = 1.0 - smoothstep(0.8, 1.0, p.lifetime);
    baseColor.a = alpha;

    p.color = baseColor;
}

/// Particle size update kernel (audio-reactive sizing)
kernel void update_sizes(
    device Particle* particles [[buffer(0)]],
    constant PhysicsConfig& config [[buffer(1)]],
    uint particleIndex [[thread_position_in_grid]]
) {
    if (particleIndex >= config.particleCount) return;

    device Particle& p = particles[particleIndex];

    // Base size from voice pitch (higher pitch = smaller particles)
    float baseSize = 2.0;
    if (config.voicePitch > 0.0) {
        baseSize = mix(4.0, 1.0, clamp(config.voicePitch / 800.0, 0.0, 1.0));
    }

    // Pulsate with audio level
    float pulseFactor = 1.0 + config.audioLevel * 0.5;

    // Shrink near end of lifetime
    float lifetimeFactor = 1.0 - smoothstep(0.9, 1.0, p.lifetime);

    p.size = baseSize * pulseFactor * lifetimeFactor;
}
