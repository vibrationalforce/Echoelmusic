// ═══════════════════════════════════════════════════════════════════════════════
// QUANTUM VISUAL SHADERS - GPU-ACCELERATED QUANTUM EFFECTS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Metal compute shaders for quantum-inspired visual processing:
// • Superposition rendering - multiple visual states
// • Entanglement-based color correlation
// • Quantum tunneling transitions
// • Wave interference patterns
// • Probabilistic wave collapse
// • Bio-coherence visualization
// • Holographic depth projection
//
// ═══════════════════════════════════════════════════════════════════════════════

#include <metal_stdlib>
using namespace metal;

// MARK: - Uniform Structures

struct SuperpositionUniforms {
    float time;
    int stateCount;
    float4 amplitudes;
    float4 phases;
    float coherence;
    float2 resolution;
};

struct EntanglementUniforms {
    float time;
    float entanglementStrength;
    float3 colorCorrelation;
    float2 resolution;
};

struct TunnelingUniforms {
    float time;
    float barrierHeight;
    float tunnelProbability;
    float particleEnergy;
    float wavePacketWidth;
    float2 resolution;
};

struct InterferenceUniforms {
    float time;
    int waveCount;
    float8 amplitudes;
    float8 frequencies;
    float coherence;
    float2 resolution;
};

struct WaveCollapseUniforms {
    float time;
    float collapseProgress;
    float measurementStrength;
    float4 probabilityField;
    uint seed;
    float2 resolution;
};

struct BioCoherenceUniforms {
    float time;
    float hrv;
    float coherence;
    float heartRate;
    float heartPhase;
    float breathingRate;
    float2 coherenceZone;
    float3 colorLow;
    float3 colorMedium;
    float3 colorHigh;
    float2 resolution;
};

struct HolographicUniforms {
    float time;
    int layerCount;
    float2 viewAngle;
    float focalDepth;
    float chromaDispersion;
    float2 resolution;
};

struct HolographicLayerData {
    float depth;
    float opacity;
    float parallaxFactor;
    float interferencePattern;
};

// MARK: - Utility Functions

// Complex multiplication
float2 cmul(float2 a, float2 b) {
    return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

// Complex exponential e^(i*theta)
float2 cexp(float theta) {
    return float2(cos(theta), sin(theta));
}

// Hash function for pseudo-random numbers
float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float hash3(float3 p) {
    return fract(sin(dot(p, float3(127.1, 311.7, 74.7))) * 43758.5453);
}

// Smooth noise
float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    float2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Fractal Brownian motion
float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

// MARK: - Quantum Superposition Kernel

kernel void quantumSuperpositionKernel(
    texture2d<float, access::write> outTexture [[texture(0)]],
    constant SuperpositionUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float2 uv = float2(gid) / uniforms.resolution;
    float2 centered = uv - 0.5;

    // Create multiple visual states in superposition
    float4 color = float4(0, 0, 0, 1);

    // State 1: Circular wave pattern
    float dist1 = length(centered);
    float wave1 = sin(dist1 * 20.0 - uniforms.time * 2.0 + uniforms.phases.x);
    float amplitude1 = uniforms.amplitudes.x * uniforms.amplitudes.x; // |ψ|²
    float3 color1 = float3(0.2, 0.5, 0.9) * (wave1 * 0.5 + 0.5) * amplitude1;

    // State 2: Radial gradient
    float angle = atan2(centered.y, centered.x);
    float radial = sin(angle * 6.0 + uniforms.phases.y);
    float amplitude2 = uniforms.amplitudes.y * uniforms.amplitudes.y;
    float3 color2 = float3(0.9, 0.3, 0.5) * (radial * 0.5 + 0.5) * amplitude2;

    // State 3: Grid pattern
    float2 grid = sin(uv * 40.0 + uniforms.phases.z);
    float gridPattern = grid.x * grid.y;
    float amplitude3 = uniforms.amplitudes.z * uniforms.amplitudes.z;
    float3 color3 = float3(0.3, 0.9, 0.4) * (gridPattern * 0.5 + 0.5) * amplitude3;

    // State 4: Noise field
    float noiseVal = fbm(uv * 5.0 + float2(uniforms.time * 0.1), 4);
    float amplitude4 = uniforms.amplitudes.w * uniforms.amplitudes.w;
    float3 color4 = float3(0.9, 0.7, 0.2) * noiseVal * amplitude4;

    // Quantum interference between states
    float interference = cos(uniforms.phases.x - uniforms.phases.y) * uniforms.coherence;

    // Superpose all states
    color.rgb = color1 + color2 + color3 + color4;

    // Add interference fringes
    float fringes = sin((dist1 + angle * 0.5) * 30.0) * interference * 0.3;
    color.rgb += fringes;

    // Normalize and add coherence glow
    float glow = exp(-dist1 * 3.0) * uniforms.coherence;
    color.rgb += float3(0.5, 0.8, 1.0) * glow;

    outTexture.write(saturate(color), gid);
}

// MARK: - Quantum Entanglement Kernel

kernel void quantumEntanglementKernel(
    texture2d<float, access::write> outTexture [[texture(0)]],
    constant EntanglementUniforms &uniforms [[buffer(0)]],
    constant float *entanglementMatrix [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float2 uv = float2(gid) / uniforms.resolution;

    // Create two entangled "particles" (visual regions)
    float2 particle1 = float2(0.3 + sin(uniforms.time * 0.5) * 0.1, 0.5);
    float2 particle2 = float2(0.7 - sin(uniforms.time * 0.5) * 0.1, 0.5);

    float dist1 = length(uv - particle1);
    float dist2 = length(uv - particle2);

    // Entangled color correlation
    // When one particle is measured (approached), it affects the other
    float measurement1 = exp(-dist1 * 10.0);
    float measurement2 = exp(-dist2 * 10.0);

    // Correlated spins visualized as colors
    float3 spin1Color = float3(1, 0, 0); // Red (spin up)
    float3 spin2Color = float3(0, 0, 1); // Blue (spin down) - anti-correlated

    // Entanglement strength affects how much they correlate
    float correlation = uniforms.entanglementStrength;

    // Apply bio-correlation to color mixing
    float3 correlatedColor = mix(spin1Color, spin2Color,
        measurement2 * correlation + (1.0 - correlation) * 0.5);

    // Create quantum connection line between particles
    float2 toP1 = particle1 - uv;
    float2 toP2 = particle2 - uv;
    float2 p1toP2 = particle2 - particle1;

    float lineT = clamp(dot(uv - particle1, p1toP2) / dot(p1toP2, p1toP2), 0.0, 1.0);
    float2 closest = particle1 + lineT * p1toP2;
    float lineDist = length(uv - closest);

    // Quantum correlation visualization along the connection
    float connectionStrength = exp(-lineDist * 50.0) * correlation;
    float connectionWave = sin(lineT * 20.0 - uniforms.time * 5.0);

    float3 connectionColor = float3(0.8, 0.4, 1.0) * connectionStrength * (connectionWave * 0.5 + 0.5);

    // Combine all effects
    float4 color;
    color.rgb = correlatedColor * (measurement1 + measurement2) * 0.5;
    color.rgb += connectionColor;

    // Add entanglement "field" background
    float fieldNoise = fbm(uv * 10.0 + float2(uniforms.time * 0.2), 3);
    color.rgb += float3(0.1, 0.05, 0.15) * fieldNoise * correlation;

    color.a = 1.0;

    outTexture.write(saturate(color), gid);
}

// MARK: - Quantum Tunneling Kernel

kernel void quantumTunnelingKernel(
    texture2d<float, access::write> outTexture [[texture(0)]],
    constant TunnelingUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float2 uv = float2(gid) / uniforms.resolution;
    float4 color = float4(0, 0, 0, 1);

    // Create potential barrier
    float barrierCenter = 0.5;
    float barrierWidth = 0.1;
    float barrierDist = abs(uv.x - barrierCenter);
    float barrier = barrierDist < barrierWidth ?
        uniforms.barrierHeight * (1.0 - barrierDist / barrierWidth) : 0.0;

    // Incoming wave packet from left
    float waveX = uv.x - 0.2 + fract(uniforms.time * 0.2) * 0.4;
    float wavePacket = exp(-pow(waveX / uniforms.wavePacketWidth, 2.0));
    float wave = sin(uv.x * 40.0 - uniforms.time * 5.0) * wavePacket;

    // Transmitted wave (tunneled through barrier)
    float transmitted = 0.0;
    if (uv.x > barrierCenter + barrierWidth) {
        float tunneledX = uv.x - barrierCenter - barrierWidth;
        // Exponential decay based on barrier height and particle energy
        float transmission = exp(-uniforms.barrierHeight * 10.0 / uniforms.particleEnergy);
        transmission *= uniforms.tunnelProbability;

        float tunneledPacket = exp(-pow((tunneledX - fract(uniforms.time * 0.2) * 0.3) / uniforms.wavePacketWidth, 2.0));
        transmitted = sin(uv.x * 40.0 - uniforms.time * 5.0) * tunneledPacket * transmission;
    }

    // Reflected wave
    float reflected = 0.0;
    if (uv.x < barrierCenter - barrierWidth) {
        float reflectedX = barrierCenter - uv.x;
        float reflectedPacket = exp(-pow((reflectedX - fract(uniforms.time * 0.2) * 0.3) / uniforms.wavePacketWidth, 2.0));
        float reflection = 1.0 - uniforms.tunnelProbability;
        reflected = sin(-uv.x * 40.0 - uniforms.time * 5.0) * reflectedPacket * reflection;
    }

    // Evanescent wave inside barrier
    float evanescent = 0.0;
    if (barrierDist < barrierWidth) {
        float decayDist = barrierDist / barrierWidth;
        evanescent = exp(-decayDist * uniforms.barrierHeight * 5.0);
        evanescent *= sin(uniforms.time * 5.0);
    }

    // Color the wave function
    color.rgb += float3(0.2, 0.5, 1.0) * (wave * 0.5 + 0.5) * wavePacket;
    color.rgb += float3(0.2, 1.0, 0.5) * (transmitted * 0.5 + 0.5);
    color.rgb += float3(1.0, 0.5, 0.2) * (reflected * 0.5 + 0.5);
    color.rgb += float3(0.8, 0.2, 0.8) * evanescent;

    // Draw barrier
    color.rgb += float3(0.3, 0.1, 0.1) * barrier;

    // Add probability density at bottom
    float probY = 1.0 - uv.y;
    float probCurve = (wave * wave + transmitted * transmitted + reflected * reflected) * 0.3;
    if (probY < probCurve) {
        color.rgb += float3(0.5, 0.3, 0.7) * 0.5;
    }

    outTexture.write(saturate(color), gid);
}

// MARK: - Quantum Interference Kernel

kernel void quantumInterferenceKernel(
    texture2d<float, access::write> outTexture [[texture(0)]],
    constant InterferenceUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float2 uv = float2(gid) / uniforms.resolution;
    float2 centered = uv - 0.5;

    // Multiple wave sources (like double-slit experiment)
    float2 sources[8];
    sources[0] = float2(-0.2, 0.0);
    sources[1] = float2(0.2, 0.0);
    sources[2] = float2(0.0, -0.2);
    sources[3] = float2(0.0, 0.2);
    sources[4] = float2(-0.15, -0.15);
    sources[5] = float2(0.15, -0.15);
    sources[6] = float2(-0.15, 0.15);
    sources[7] = float2(0.15, 0.15);

    // Calculate interference from all wave sources
    float2 totalWave = float2(0, 0); // Complex amplitude

    for (int i = 0; i < uniforms.waveCount && i < 8; i++) {
        float dist = length(centered - sources[i]);
        float amplitude = uniforms.amplitudes[i];
        float frequency = uniforms.frequencies[i];

        // Wave from this source
        float phase = dist * frequency * 20.0 - uniforms.time * 3.0;

        // Add as complex number for proper interference
        totalWave += float2(cos(phase), sin(phase)) * amplitude / (1.0 + dist * 2.0);
    }

    // Calculate intensity (|ψ|²)
    float intensity = dot(totalWave, totalWave);

    // Create interference pattern colors
    float4 color;

    // Bright fringes
    float3 brightColor = float3(0.2, 0.6, 1.0);

    // Dark fringes
    float3 darkColor = float3(0.02, 0.05, 0.1);

    color.rgb = mix(darkColor, brightColor, intensity);

    // Add coherence-based glow in center
    float centerGlow = exp(-length(centered) * 4.0) * uniforms.coherence;
    color.rgb += float3(1.0, 0.8, 0.4) * centerGlow;

    // Add phase visualization
    float phaseAngle = atan2(totalWave.y, totalWave.x);
    float3 phaseColor = float3(
        sin(phaseAngle) * 0.5 + 0.5,
        sin(phaseAngle + 2.094) * 0.5 + 0.5,
        sin(phaseAngle + 4.189) * 0.5 + 0.5
    );
    color.rgb = mix(color.rgb, phaseColor, 0.2 * uniforms.coherence);

    color.a = 1.0;

    outTexture.write(saturate(color), gid);
}

// MARK: - Wave Collapse Kernel

kernel void waveCollapseKernel(
    texture2d<float, access::write> outTexture [[texture(0)]],
    constant WaveCollapseUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float2 uv = float2(gid) / uniforms.resolution;

    // Random seed based on position and time
    float rand = hash(uv * 1000.0 + float(uniforms.seed) * 0.001);

    // Probability distribution before collapse (superposition of possibilities)
    float prob1 = uniforms.probabilityField.x * exp(-length(uv - float2(0.3, 0.5)) * 5.0);
    float prob2 = uniforms.probabilityField.y * exp(-length(uv - float2(0.7, 0.5)) * 5.0);
    float prob3 = uniforms.probabilityField.z * exp(-length(uv - float2(0.5, 0.3)) * 5.0);
    float prob4 = uniforms.probabilityField.w * exp(-length(uv - float2(0.5, 0.7)) * 5.0);

    float totalProb = prob1 + prob2 + prob3 + prob4;

    float4 color;

    // Before collapse: show probability cloud
    if (uniforms.collapseProgress < 1.0) {
        // Fuzzy quantum uncertainty
        float uncertainty = 1.0 - uniforms.collapseProgress;

        float3 probColor = float3(0, 0, 0);
        probColor += float3(1.0, 0.2, 0.2) * prob1;
        probColor += float3(0.2, 1.0, 0.2) * prob2;
        probColor += float3(0.2, 0.2, 1.0) * prob3;
        probColor += float3(1.0, 1.0, 0.2) * prob4;

        // Add quantum fuzziness
        float fuzz = noise(uv * 50.0 + uniforms.time) * uncertainty;
        probColor += float3(0.5) * fuzz;

        // Collapse wave animation
        float collapseWave = sin(length(uv - 0.5) * 30.0 - uniforms.collapseProgress * 20.0);
        collapseWave *= (1.0 - uniforms.collapseProgress);

        color.rgb = probColor + float3(0.3, 0.5, 0.8) * collapseWave * 0.3;
    }

    // After collapse: definite state
    if (uniforms.collapseProgress >= uniforms.measurementStrength) {
        // Determine which state collapsed based on probabilities
        float cumProb = 0;
        float3 collapsedColor = float3(0);
        float threshold = rand;

        cumProb += prob1 / totalProb;
        if (threshold < cumProb && length(collapsedColor) == 0.0) {
            collapsedColor = float3(1.0, 0.2, 0.2);
        }

        cumProb += prob2 / totalProb;
        if (threshold < cumProb && length(collapsedColor) == 0.0) {
            collapsedColor = float3(0.2, 1.0, 0.2);
        }

        cumProb += prob3 / totalProb;
        if (threshold < cumProb && length(collapsedColor) == 0.0) {
            collapsedColor = float3(0.2, 0.2, 1.0);
        }

        if (length(collapsedColor) == 0.0) {
            collapsedColor = float3(1.0, 1.0, 0.2);
        }

        // Sharp collapsed state
        color.rgb = mix(color.rgb, collapsedColor, uniforms.collapseProgress);
    }

    color.a = 1.0;

    outTexture.write(saturate(color), gid);
}

// MARK: - Bio Coherence Kernel

kernel void bioCoherenceKernel(
    texture2d<float, access::write> outTexture [[texture(0)]],
    constant BioCoherenceUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float2 uv = float2(gid) / uniforms.resolution;
    float2 centered = uv - 0.5;
    float dist = length(centered);
    float angle = atan2(centered.y, centered.x);

    // Heart-shaped coherence visualization
    float heartShape = pow(abs(sin(angle)), 0.5) * 0.3;
    float heartDist = abs(dist - 0.25 - heartShape * sin(uniforms.heartPhase));
    float heart = exp(-heartDist * 20.0);

    // Coherence level determines color
    float coherenceNorm = (uniforms.coherence - uniforms.coherenceZone.x) /
                          (uniforms.coherenceZone.y - uniforms.coherenceZone.x);
    coherenceNorm = saturate(coherenceNorm);

    float3 coherenceColor;
    if (coherenceNorm < 0.5) {
        coherenceColor = mix(uniforms.colorLow, uniforms.colorMedium, coherenceNorm * 2.0);
    } else {
        coherenceColor = mix(uniforms.colorMedium, uniforms.colorHigh, (coherenceNorm - 0.5) * 2.0);
    }

    // HRV wave visualization
    float hrvWave = sin(angle * 8.0 + uniforms.time * 2.0) * uniforms.hrv / 100.0;
    float hrvRing = exp(-abs(dist - 0.35 - hrvWave * 0.05) * 30.0);

    // Breathing circle
    float breathPhase = sin(uniforms.time / uniforms.breathingRate * M_PI_F * 2.0);
    float breathRadius = 0.2 + breathPhase * 0.05;
    float breathCircle = exp(-abs(dist - breathRadius) * 40.0) * 0.5;

    // Combine all visualizations
    float4 color;
    color.rgb = coherenceColor * heart;
    color.rgb += float3(0.3, 0.6, 0.9) * hrvRing;
    color.rgb += float3(0.5, 0.8, 0.5) * breathCircle;

    // Add coherence glow
    float glow = exp(-dist * 3.0) * coherenceNorm;
    color.rgb += coherenceColor * glow * 0.5;

    // Heart rate pulse effect
    float pulse = sin(uniforms.heartPhase) * 0.5 + 0.5;
    color.rgb *= 0.8 + pulse * 0.4;

    color.a = 1.0;

    outTexture.write(saturate(color), gid);
}

// MARK: - Holographic Projection Kernel

kernel void holographicProjectionKernel(
    texture2d<float, access::write> outTexture [[texture(0)]],
    constant HolographicUniforms &uniforms [[buffer(0)]],
    constant HolographicLayerData *layers [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float2 uv = float2(gid) / uniforms.resolution;
    float4 color = float4(0, 0, 0, 1);

    // Render each holographic layer with parallax
    for (int i = 0; i < uniforms.layerCount && i < 8; i++) {
        HolographicLayerData layer = layers[i];

        // Apply parallax based on view angle and depth
        float2 parallaxOffset = uniforms.viewAngle * layer.parallaxFactor * layer.depth;
        float2 layerUV = uv + parallaxOffset;

        // Layer content (abstract holographic pattern)
        float pattern = 0.0;

        // Circular interference rings
        float layerDist = length(layerUV - 0.5);
        pattern += sin(layerDist * 30.0 - uniforms.time * 2.0 + layer.depth * 10.0) * 0.5 + 0.5;

        // Scan lines
        pattern *= 0.8 + sin(layerUV.y * 200.0) * 0.2;

        // Apply interference pattern from layer
        pattern *= 0.8 + layer.interferencePattern * 0.2;

        // Depth-based focus blur (layers far from focal depth are blurry)
        float focusDistance = abs(layer.depth - uniforms.focalDepth);
        float blur = focusDistance * 0.1;
        pattern = mix(pattern, 0.5, blur);

        // Chromatic dispersion (RGB separation for holographic effect)
        float3 layerColor;
        float dispersion = uniforms.chromaDispersion * layer.depth;

        layerColor.r = sin(layerDist * 30.0 - uniforms.time * 2.0 + dispersion * 10.0) * 0.5 + 0.5;
        layerColor.g = sin(layerDist * 30.0 - uniforms.time * 2.0) * 0.5 + 0.5;
        layerColor.b = sin(layerDist * 30.0 - uniforms.time * 2.0 - dispersion * 10.0) * 0.5 + 0.5;

        layerColor *= pattern;

        // Base holographic color tint
        layerColor *= float3(0.3 + layer.depth * 0.7, 0.5 + layer.depth * 0.3, 0.8);

        // Blend with existing color using layer opacity
        color.rgb += layerColor * layer.opacity;
    }

    // Add holographic shimmer
    float shimmer = sin(uv.x * 100.0 + uniforms.time * 10.0) * sin(uv.y * 80.0 + uniforms.time * 8.0);
    color.rgb += float3(0.1, 0.2, 0.3) * shimmer * 0.1;

    // Edge glow
    float2 centered = uv - 0.5;
    float edgeDist = max(abs(centered.x), abs(centered.y));
    float edgeGlow = smoothstep(0.4, 0.5, edgeDist);
    color.rgb += float3(0.2, 0.5, 1.0) * edgeGlow * 0.3;

    outTexture.write(saturate(color), gid);
}

// MARK: - Quantum Particle Update Kernel

struct QuantumParticle {
    float3 position;
    float3 velocity;
    float2 quantumState;
    float spin;
    float energy;
    int entanglementID;
    float lifetime;
};

kernel void quantumParticleUpdateKernel(
    device QuantumParticle *particles [[buffer(0)]],
    constant float &time [[buffer(1)]],
    constant float &coherence [[buffer(2)]],
    constant uint &particleCount [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= particleCount) {
        return;
    }

    QuantumParticle p = particles[gid];

    // Quantum random walk with coherence
    float3 randomForce = float3(
        hash(float2(float(gid), time)) - 0.5,
        hash(float2(time, float(gid))) - 0.5,
        hash(float2(float(gid) * 0.5, time * 0.5)) - 0.5
    );

    // Coherent particles move more deterministically
    float randomStrength = 1.0 - coherence;
    p.velocity += randomForce * 0.001 * randomStrength;

    // Entanglement force - particles with same ID are attracted
    // (simplified - real implementation would use spatial hashing)

    // Energy-based velocity damping
    p.velocity *= 0.99 + p.energy * 0.009;

    // Update position
    p.position += p.velocity;

    // Boundary wrap
    p.position = fract(p.position * 0.5 + 0.5) * 2.0 - 1.0;

    // Evolve quantum state (Schrödinger evolution)
    float phase = p.energy * time * 0.1;
    float2 newState = float2(
        p.quantumState.x * cos(phase) - p.quantumState.y * sin(phase),
        p.quantumState.x * sin(phase) + p.quantumState.y * cos(phase)
    );
    p.quantumState = newState;

    // Lifetime decay
    p.lifetime -= 0.01;
    if (p.lifetime <= 0) {
        // Respawn particle
        p.position = float3(
            hash(float2(float(gid), time * 2.0)) * 2.0 - 1.0,
            hash(float2(time * 2.0, float(gid))) * 2.0 - 1.0,
            hash(float2(float(gid) * 0.7, time * 1.5)) * 2.0 - 1.0
        );
        p.velocity = float3(0);
        p.lifetime = 5.0 + hash(float2(float(gid), time)) * 10.0;
        p.quantumState = float2(1.0, 0.0);
    }

    particles[gid] = p;
}
