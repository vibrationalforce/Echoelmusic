// Echoelmusic Metal Shaders
// Advanced GPU-accelerated visual effects for bio-reactive audio-visual experiences

#include <metal_stdlib>
using namespace metal;

// MARK: - Common Types (Echoelmusic prefixed to avoid linker conflicts)

struct EchoelVertexIn {
    float4 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct EchoelVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct EchoelUniforms {
    float time;
    float coherence;      // 0-1, HRV coherence level
    float heartRate;      // BPM
    float breathingPhase; // 0-1, current breathing phase
    float audioLevel;     // 0-1, current audio amplitude
    float2 resolution;
};

// MARK: - Utility Functions

// Simplex noise 2D
float2 hash2(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)),
               dot(p, float2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

float simplex2D(float2 p) {
    const float K1 = 0.366025404; // (sqrt(3)-1)/2
    const float K2 = 0.211324865; // (3-sqrt(3))/6

    float2 i = floor(p + (p.x + p.y) * K1);
    float2 a = p - i + (i.x + i.y) * K2;
    float2 o = (a.x > a.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 b = a - o + K2;
    float2 c = a - 1.0 + 2.0 * K2;

    float3 h = max(0.5 - float3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    float3 n = h * h * h * h * float3(
        dot(a, hash2(i) * 2.0 - 1.0),
        dot(b, hash2(i + o) * 2.0 - 1.0),
        dot(c, hash2(i + 1.0) * 2.0 - 1.0)
    );

    return dot(n, float3(70.0));
}

// Fractal Brownian Motion (Echoelmusic prefixed to avoid linker conflicts - 2026-01-20 fix)
float echoelFbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * simplex2D(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

// MARK: - Vertex Shader

vertex EchoelVertexOut vertexShader(EchoelVertexIn in [[stage_in]]) {
    EchoelVertexOut out;
    out.position = in.position;
    out.texCoord = in.texCoord;
    return out;
}

// MARK: - Angular Gradient Shader

fragment float4 angularGradientShader(
    EchoelVertexOut in [[stage_in]],
    constant EchoelUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord * 2.0 - 1.0;

    // Calculate angle from center
    float angle = atan2(uv.y, uv.x);
    float normalizedAngle = (angle + M_PI_F) / (2.0 * M_PI_F);

    // Add rotation based on time and coherence
    float rotation = uniforms.time * 0.1 * (1.0 + uniforms.coherence);
    normalizedAngle = fract(normalizedAngle + rotation);

    // Create gradient colors (Vaporwave palette)
    float3 color1 = float3(0.58, 0.4, 0.98);   // Neon pink
    float3 color2 = float3(0.0, 0.878, 1.0);   // Cyan
    float3 color3 = float3(1.0, 0.4, 0.6);     // Coral

    // Blend based on angle
    float3 color;
    if (normalizedAngle < 0.33) {
        color = mix(color1, color2, normalizedAngle * 3.0);
    } else if (normalizedAngle < 0.66) {
        color = mix(color2, color3, (normalizedAngle - 0.33) * 3.0);
    } else {
        color = mix(color3, color1, (normalizedAngle - 0.66) * 3.0);
    }

    // Add pulsing based on heart rate
    float pulse = sin(uniforms.time * uniforms.heartRate / 60.0 * 2.0 * M_PI_F) * 0.1 + 0.9;
    color *= pulse;

    return float4(color, 1.0);
}

// MARK: - Perlin Noise Background Shader

fragment float4 perlinNoiseShader(
    EchoelVertexOut in [[stage_in]],
    constant EchoelUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;

    // Scale and animate
    float2 p = uv * 3.0 + float2(uniforms.time * 0.1, uniforms.time * 0.05);

    // Generate fractal noise
    float noise = echoelFbm(p, 6);

    // Map to colors based on coherence
    float3 lowCoherenceColor = float3(0.1, 0.05, 0.15);   // Dark purple
    float3 highCoherenceColor = float3(0.0, 0.3, 0.4);    // Teal

    float3 baseColor = mix(lowCoherenceColor, highCoherenceColor, uniforms.coherence);

    // Add noise variation
    float3 color = baseColor + noise * 0.3;

    // Add audio reactivity
    color += uniforms.audioLevel * 0.2 * float3(0.5, 0.2, 0.8);

    return float4(color, 1.0);
}

// MARK: - Starfield Shader

fragment float4 starfieldShader(
    EchoelVertexOut in [[stage_in]],
    constant EchoelUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;

    float3 color = float3(0.0);

    // Create multiple star layers with parallax
    for (int layer = 0; layer < 4; layer++) {
        float depth = 1.0 + float(layer) * 0.5;
        float2 starUV = uv * depth;

        // Move based on time and layer
        starUV.y += uniforms.time * 0.05 * depth;

        // Grid for star positions
        float2 gridPos = floor(starUV * 20.0);
        float2 gridUV = fract(starUV * 20.0) - 0.5;

        // Random star brightness per cell
        float2 randomVec = hash2(gridPos);
        float starBrightness = step(0.97 - uniforms.coherence * 0.1, randomVec.x);

        // Star shape
        float dist = length(gridUV - (randomVec - 0.5) * 0.5);
        float star = starBrightness * smoothstep(0.1, 0.0, dist);

        // Twinkle effect
        float twinkle = sin(uniforms.time * 3.0 + randomVec.y * 10.0) * 0.5 + 0.5;
        star *= 0.5 + twinkle * 0.5;

        color += star / depth;
    }

    // Add subtle nebula
    float nebula = echoelFbm(uv * 2.0 + uniforms.time * 0.02, 4) * 0.15;
    color += nebula * float3(0.3, 0.1, 0.5);

    return float4(color, 1.0);
}

// MARK: - Bio-Reactive Pulse Shader

fragment float4 bioReactivePulseShader(
    EchoelVertexOut in [[stage_in]],
    constant EchoelUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;

    float dist = length(uv);

    // Heart rate pulse (multiple rings expanding outward)
    float pulseSpeed = uniforms.heartRate / 60.0;
    float pulse = 0.0;

    for (int i = 0; i < 5; i++) {
        float offset = float(i) * 0.2;
        float ring = fract(uniforms.time * pulseSpeed - offset);
        float ringDist = abs(dist - ring);
        float ringWidth = 0.02 + uniforms.coherence * 0.03;
        pulse += smoothstep(ringWidth, 0.0, ringDist) * (1.0 - ring);
    }

    // Breathing overlay (slower, larger scale)
    float breathe = sin(uniforms.breathingPhase * 2.0 * M_PI_F) * 0.5 + 0.5;
    float breatheEffect = smoothstep(0.8, 0.0, dist) * breathe * 0.3;

    // Color based on coherence
    float3 lowColor = float3(1.0, 0.3, 0.3);    // Red (low coherence)
    float3 midColor = float3(1.0, 0.8, 0.2);    // Yellow (medium)
    float3 highColor = float3(0.3, 1.0, 0.5);   // Green (high coherence)

    float3 pulseColor;
    if (uniforms.coherence < 0.5) {
        pulseColor = mix(lowColor, midColor, uniforms.coherence * 2.0);
    } else {
        pulseColor = mix(midColor, highColor, (uniforms.coherence - 0.5) * 2.0);
    }

    float3 color = pulse * pulseColor + breatheEffect * float3(0.5, 0.7, 1.0);

    // Add subtle background
    color += float3(0.02, 0.01, 0.03);

    return float4(color, 1.0);
}

// MARK: - Cymatics Pattern Shader

fragment float4 cymaticsShader(
    EchoelVertexOut in [[stage_in]],
    constant EchoelUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;

    // Base frequency affected by audio and coherence
    float baseFreq = 4.0 + uniforms.audioLevel * 8.0;
    float freq = baseFreq * (1.0 + uniforms.coherence * 0.5);

    // Chladni pattern formula
    float pattern = 0.0;

    // Multiple harmonics
    for (int i = 1; i <= 5; i++) {
        float n = float(i);
        float harmonic = sin(uv.x * freq * n + uniforms.time) *
                        sin(uv.y * freq * n + uniforms.time * 0.7);
        pattern += harmonic / n;
    }

    // Add rotation
    float angle = uniforms.time * 0.2;
    float2 rotatedUV = float2(
        uv.x * cos(angle) - uv.y * sin(angle),
        uv.x * sin(angle) + uv.y * cos(angle)
    );

    float rotatedPattern = sin(rotatedUV.x * freq) * sin(rotatedUV.y * freq);
    pattern = mix(pattern, rotatedPattern, 0.3);

    // Normalize and colorize
    pattern = abs(pattern);

    // Vaporwave color palette
    float3 color1 = float3(0.0, 0.878, 1.0);   // Cyan
    float3 color2 = float3(0.58, 0.4, 0.98);   // Pink
    float3 color = mix(color1, color2, pattern);

    // Add glow at nodes
    float nodes = smoothstep(0.1, 0.0, pattern);
    color += nodes * float3(1.0, 1.0, 1.0) * 0.5;

    return float4(color, 1.0);
}

// MARK: - Mandala Sacred Geometry Shader

fragment float4 mandalaShader(
    EchoelVertexOut in [[stage_in]],
    constant EchoelUniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv.x *= uniforms.resolution.x / uniforms.resolution.y;

    float dist = length(uv);
    float angle = atan2(uv.y, uv.x);

    // Number of petals based on coherence (6-12)
    float petals = floor(6.0 + uniforms.coherence * 6.0);

    // Create radial symmetry
    float symmetryAngle = fmod(angle + M_PI_F, 2.0 * M_PI_F / petals);
    symmetryAngle = abs(symmetryAngle - M_PI_F / petals);

    // Flower of Life circles
    float pattern = 0.0;
    float circleRadius = 0.3;

    for (int i = 0; i < 7; i++) {
        float ringAngle = float(i) * M_PI_F / 3.0 + uniforms.time * 0.1;
        float2 circleCenter = float2(cos(ringAngle), sin(ringAngle)) * circleRadius;
        float circleDist = length(uv - circleCenter);
        pattern += smoothstep(circleRadius + 0.02, circleRadius - 0.02, circleDist);
    }

    // Center circle
    pattern += smoothstep(circleRadius + 0.02, circleRadius - 0.02, dist);

    // Add rotating petals
    float petalPattern = cos(symmetryAngle * petals) * 0.5 + 0.5;
    petalPattern *= smoothstep(1.0, 0.2, dist);

    // Combine patterns
    float combined = pattern * 0.3 + petalPattern * 0.7;

    // Color based on distance and coherence
    float3 innerColor = float3(1.0, 0.8, 0.3);   // Gold
    float3 outerColor = float3(0.3, 0.1, 0.5);   // Purple
    float3 color = mix(innerColor, outerColor, dist);

    color *= combined;

    // Add breathing glow
    float breathGlow = sin(uniforms.breathingPhase * 2.0 * M_PI_F) * 0.3 + 0.7;
    color *= breathGlow;

    return float4(color, 1.0);
}

// MARK: - Compute Kernel: Particle Update

struct Particle {
    float2 position;
    float2 velocity;
    float life;
    float size;
    float4 color;
};

kernel void updateParticles(
    device Particle *particles [[buffer(0)]],
    constant EchoelUniforms &uniforms [[buffer(1)]],
    uint id [[thread_position_in_grid]]
) {
    Particle p = particles[id];

    // Update life
    p.life -= 0.016; // Assuming 60fps

    if (p.life <= 0.0) {
        // Reset particle
        float2 random = hash2(float2(float(id), uniforms.time));
        p.position = float2(random.x * 2.0 - 1.0, -1.0);
        p.velocity = float2((random.x - 0.5) * 0.5, random.y * 0.5 + 0.5);
        p.life = 1.0 + random.y;
        p.size = 0.01 + random.x * 0.02;

        // Color based on coherence
        float3 lowColor = float3(1.0, 0.3, 0.3);
        float3 highColor = float3(0.3, 1.0, 0.5);
        p.color = float4(mix(lowColor, highColor, uniforms.coherence), 1.0);
    }

    // Apply forces
    float2 center = float2(0.0, 0.0);
    float2 toCenter = center - p.position;
    float centerForce = uniforms.coherence * 0.01;
    p.velocity += toCenter * centerForce;

    // Audio reactivity
    p.velocity.y += uniforms.audioLevel * 0.1;

    // Update position
    p.position += p.velocity * 0.016;

    // Damping
    p.velocity *= 0.99;

    // Store back
    particles[id] = p;
}
