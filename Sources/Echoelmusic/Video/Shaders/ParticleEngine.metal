#include <metal_stdlib>
using namespace metal;

/// Particle structure for GPU compute
struct Particle {
    float2 position;     // Current position in screen space
    float2 velocity;     // Velocity vector
    float4 color;        // RGBA color
    float size;          // Particle size in pixels
    float life;          // Remaining life (0-1)
    float age;           // Current age
    float mass;          // For physics calculations
};

/// Biometric data structure
struct BiometricData {
    float heartRate;     // 60-180 BPM
    float hrv;           // 0-100 coherence
    float4 eegWaves;     // delta, theta, alpha, beta (0-1 each)
    float breathing;     // 0-1 breathing phase
    float movement;      // 0-1 movement intensity
};

/// Random number generator (Xorshift)
float random(uint seed, float2 uv) {
    uint x = seed ^ uint(uv.x * 1000.0);
    uint y = uint(uv.y * 1000.0);
    uint z = x ^ (x << 13);
    z ^= (z >> 17);
    z ^= (z << 5);
    z += y;
    return float(z) / 4294967295.0;
}

/// COMPUTE KERNEL: Update particle physics
/// This runs 100,000+ times per frame @ 60 FPS = 6+ million operations/sec
kernel void updateParticles(
    device Particle *particles [[buffer(0)]],
    constant BiometricData &bio [[buffer(1)]],
    constant float &deltaTime [[buffer(2)]],
    constant float2 &screenSize [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    Particle p = particles[id];

    // Skip dead particles
    if (p.life <= 0.0) {
        // Respawn at center with random velocity
        float2 center = screenSize * 0.5;
        float angle = random(id, float2(bio.heartRate, bio.breathing)) * 6.28318;
        float speed = random(id + 1, float2(bio.hrv, bio.movement)) * 200.0;

        p.position = center;
        p.velocity = float2(cos(angle), sin(angle)) * speed;
        p.life = 1.0;
        p.age = 0.0;
        p.size = 2.0 + random(id + 2, float2(bio.eegWaves.x, bio.eegWaves.y)) * 6.0;
        p.mass = 1.0;

        particles[id] = p;
        return;
    }

    // === HEART RATE INFLUENCES SPEED ===
    float speedMultiplier = bio.heartRate / 60.0;  // Normalize to 60 BPM baseline
    float2 scaledVelocity = p.velocity * speedMultiplier;

    // === HRV CREATES TURBULENCE ===
    float turbulenceStrength = (100.0 - bio.hrv) / 100.0;  // Lower coherence = more chaos
    float turbulenceX = sin(p.position.x * 0.1 + bio.breathing * 6.28318) * turbulenceStrength;
    float turbulenceY = cos(p.position.y * 0.1 + bio.breathing * 6.28318) * turbulenceStrength;
    float2 turbulence = float2(turbulenceX, turbulenceY) * 100.0;

    p.velocity += turbulence * deltaTime;

    // === EEG WAVES INFLUENCE COLOR ===
    // Delta (deep sleep) = Red
    // Theta (meditation) = Orange
    // Alpha (relaxed) = Green
    // Beta (active) = Blue
    p.color.r = bio.eegWaves.x + bio.eegWaves.y * 0.5;  // Delta + Theta
    p.color.g = bio.eegWaves.y * 0.5 + bio.eegWaves.z;  // Theta + Alpha
    p.color.b = bio.eegWaves.z * 0.5 + bio.eegWaves.w;  // Alpha + Beta
    p.color.a = 0.6 + bio.hrv * 0.004;  // Alpha increases with coherence

    // === BREATHING PULSATES SIZE ===
    float breathePulse = sin(bio.breathing * 6.28318) * 0.5 + 0.5;
    p.size = 2.0 + breathePulse * 4.0;

    // === MOVEMENT CREATES TRAILS (slower fade) ===
    float lifeFade = 0.5;  // Base fade rate
    if (bio.movement > 0.5) {
        lifeFade = 0.2;  // Slower fade = longer trails
    }

    // === CENTER ATTRACTOR (COHERENCE BASED) ===
    float2 center = screenSize * 0.5;
    float2 toCenter = center - p.position;
    float distToCenter = length(toCenter);

    if (distToCenter > 1.0) {
        float attractorStrength = (bio.hrv / 100.0) * 500.0;  // Higher coherence = stronger pull
        float2 attractorForce = normalize(toCenter) * attractorStrength;
        p.velocity += attractorForce * deltaTime;
    }

    // === PHYSICS INTEGRATION ===
    // Damping (air resistance)
    p.velocity *= 0.99;

    // Update position
    p.position += scaledVelocity * deltaTime;

    // Update age and life
    p.age += deltaTime;
    p.life -= deltaTime * lifeFade;

    // Screen wrapping (optional - comment out for bounded)
    if (p.position.x < 0) p.position.x = screenSize.x;
    if (p.position.x > screenSize.x) p.position.x = 0;
    if (p.position.y < 0) p.position.y = screenSize.y;
    if (p.position.y > screenSize.y) p.position.y = 0;

    // Write back
    particles[id] = p;
}

/// VERTEX SHADER: Transform particles for rendering
struct VertexOut {
    float4 position [[position]];
    float4 color;
    float pointSize [[point_size]];
};

vertex VertexOut particleVertex(
    constant Particle *particles [[buffer(0)]],
    constant float2 &screenSize [[buffer(1)]],
    uint id [[vertex_id]]
) {
    Particle p = particles[id];

    VertexOut out;

    // Convert screen coordinates to clip space (-1 to 1)
    float2 normalized = (p.position / screenSize) * 2.0 - 1.0;
    normalized.y = -normalized.y;  // Flip Y for screen coordinates

    out.position = float4(normalized, 0.0, 1.0);
    out.color = p.color;
    out.pointSize = p.size * (p.life * 0.5 + 0.5);  // Size fades with life

    return out;
}

/// FRAGMENT SHADER: Render particles with glow
fragment float4 particleFragment(
    VertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]]
) {
    // Create circular particles with soft edge
    float dist = length(pointCoord - 0.5);

    // Soft circle
    float alpha = smoothstep(0.5, 0.3, dist);

    // Add glow
    float glow = exp(-dist * 3.0) * 0.3;

    float4 color = in.color;
    color.a *= (alpha + glow);

    return color;
}

/// COMPUTE KERNEL: Advanced particle interactions
/// Includes particle-particle forces and field effects
kernel void updateParticlesAdvanced(
    device Particle *particles [[buffer(0)]],
    constant BiometricData &bio [[buffer(1)]],
    constant float &deltaTime [[buffer(2)]],
    constant float2 &screenSize [[buffer(3)]],
    constant uint &particleCount [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    Particle p = particles[id];

    if (p.life <= 0.0) {
        // Respawn logic (same as above)
        float2 center = screenSize * 0.5;
        float angle = random(id, float2(bio.heartRate, bio.breathing)) * 6.28318;
        float speed = random(id + 1, float2(bio.hrv, bio.movement)) * 200.0;

        p.position = center;
        p.velocity = float2(cos(angle), sin(angle)) * speed;
        p.life = 1.0;
        p.age = 0.0;
        p.size = 2.0 + random(id + 2, float2(bio.eegWaves.x, bio.eegWaves.y)) * 6.0;
        p.mass = 1.0;

        particles[id] = p;
        return;
    }

    // All the standard forces from basic version
    float speedMultiplier = bio.heartRate / 60.0;
    float2 scaledVelocity = p.velocity * speedMultiplier;

    float turbulenceStrength = (100.0 - bio.hrv) / 100.0;
    float turbulenceX = sin(p.position.x * 0.1 + bio.breathing * 6.28318) * turbulenceStrength;
    float turbulenceY = cos(p.position.y * 0.1 + bio.breathing * 6.28318) * turbulenceStrength;
    float2 turbulence = float2(turbulenceX, turbulenceY) * 100.0;
    p.velocity += turbulence * deltaTime;

    // === PARTICLE-PARTICLE INTERACTION ===
    // Sample nearby particles for flocking/avoidance
    // Note: This is expensive! Only sample a subset for 100k particles
    float2 separation = float2(0.0);
    float2 alignment = float2(0.0);
    float2 cohesion = float2(0.0);
    int neighborCount = 0;

    // Sample every 100th particle to keep performance at 60 FPS
    for (uint i = id - 50; i <= id + 50; i += 10) {
        if (i >= particleCount || i == id) continue;

        Particle other = particles[i];
        if (other.life <= 0.0) continue;

        float2 diff = p.position - other.position;
        float dist = length(diff);

        if (dist < 100.0 && dist > 0.1) {  // Within influence radius
            // Separation: avoid crowding
            separation += normalize(diff) / dist;

            // Alignment: match velocity
            alignment += other.velocity;

            // Cohesion: move toward average position
            cohesion += other.position;

            neighborCount++;
        }
    }

    if (neighborCount > 0) {
        // Apply flocking forces (subtle)
        p.velocity += separation * 10.0 * deltaTime;
        p.velocity += (alignment / float(neighborCount) - p.velocity) * 0.1 * deltaTime;

        float2 avgPosition = cohesion / float(neighborCount);
        p.velocity += (avgPosition - p.position) * 0.1 * deltaTime;
    }

    // === FIELD EFFECTS ===
    // Create swirling vortex fields based on EEG activity
    float2 center = screenSize * 0.5;
    float2 toCenter = p.position - center;
    float distFromCenter = length(toCenter);

    // Vortex strength based on alpha waves (relaxed state)
    float vortexStrength = bio.eegWaves.z * 50.0;
    if (distFromCenter > 1.0) {
        // Perpendicular force creates rotation
        float2 tangent = float2(-toCenter.y, toCenter.x) / distFromCenter;
        p.velocity += tangent * vortexStrength * deltaTime;
    }

    // Color and size updates (same as basic)
    p.color.r = bio.eegWaves.x + bio.eegWaves.y * 0.5;
    p.color.g = bio.eegWaves.y * 0.5 + bio.eegWaves.z;
    p.color.b = bio.eegWaves.z * 0.5 + bio.eegWaves.w;
    p.color.a = 0.6 + bio.hrv * 0.004;

    float breathePulse = sin(bio.breathing * 6.28318) * 0.5 + 0.5;
    p.size = 2.0 + breathePulse * 4.0;

    // Physics integration
    p.velocity *= 0.99;
    p.position += scaledVelocity * deltaTime;
    p.age += deltaTime;
    p.life -= deltaTime * 0.5;

    // Screen wrapping
    if (p.position.x < 0) p.position.x = screenSize.x;
    if (p.position.x > screenSize.x) p.position.x = 0;
    if (p.position.y < 0) p.position.y = screenSize.y;
    if (p.position.y > screenSize.y) p.position.y = 0;

    particles[id] = p;
}
