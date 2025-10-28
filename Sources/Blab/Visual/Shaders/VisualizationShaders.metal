#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Shader Structures

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// MARK: - Uniforms

struct Uniforms {
    float time;
    float audioLevel;
    float frequency;
    float hrvCoherence;
    float heartRate;
    float2 resolution;
};

// MARK: - Basic Vertex Shader

vertex VertexOut vertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// MARK: - Particle Visualization

fragment float4 particleFragment(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);

    // Normalize UV to -1 to 1
    float2 pos = (uv - center) * 2.0;

    // Create particle field based on audio
    float particles = 0.0;
    int numParticles = 50;

    for (int i = 0; i < numParticles; i++) {
        float angle = float(i) / float(numParticles) * 6.28318;
        float radius = 0.3 + uniforms.audioLevel * 0.5;

        // Rotate particles over time
        float rotatedAngle = angle + uniforms.time;
        float2 particlePos = float2(
            cos(rotatedAngle) * radius,
            sin(rotatedAngle) * radius
        );

        // Distance from current pixel to particle
        float dist = length(pos - particlePos);

        // Particle size based on audio
        float size = 0.02 + uniforms.audioLevel * 0.03;

        // Add particle glow
        particles += smoothstep(size, 0.0, dist);
    }

    // Color based on HRV coherence
    float hue = uniforms.hrvCoherence / 100.0;
    float3 color = float3(
        0.5 + 0.5 * cos(6.28318 * hue),
        0.5 + 0.5 * cos(6.28318 * (hue + 0.33)),
        0.5 + 0.5 * cos(6.28318 * (hue + 0.67))
    );

    color *= particles;

    return float4(color, 1.0);
}

// MARK: - Cymatics Visualization

fragment float4 cymaticsFragment(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);
    float2 pos = (uv - center) * 2.0;

    // Distance from center
    float dist = length(pos);

    // Create Chladni pattern (standing wave simulation)
    float frequency = uniforms.frequency / 440.0;
    float pattern = 0.0;

    // Multiple wave modes
    for (int i = 1; i <= 5; i++) {
        float mode = float(i);
        float wave = sin(dist * mode * 10.0 * frequency + uniforms.time);
        pattern += wave * uniforms.audioLevel / mode;
    }

    // Angular waves
    float angle = atan2(pos.y, pos.x);
    float angularWaves = sin(angle * 6.0 + uniforms.time) * 0.5;

    pattern += angularWaves * uniforms.audioLevel;

    // Normalize pattern
    pattern = abs(pattern);
    pattern = smoothstep(0.3, 0.7, pattern);

    // Color based on HRV
    float hue = uniforms.hrvCoherence / 100.0;
    float3 color = float3(0.2, 0.5, 0.8) * pattern;
    color = mix(color, float3(hue, 0.7, 1.0), 0.5);

    return float4(color, 1.0);
}

// MARK: - Waveform Visualization

fragment float4 waveformFragment(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;

    // Horizontal waveform
    float wave = sin(uv.x * 20.0 + uniforms.time * 2.0) * uniforms.audioLevel * 0.3;
    wave += sin(uv.x * 40.0 - uniforms.time * 3.0) * uniforms.audioLevel * 0.15;

    // Center line at y = 0.5
    float centerY = 0.5 + wave;
    float lineWidth = 0.02;

    // Distance from waveform line
    float dist = abs(uv.y - centerY);
    float waveform = smoothstep(lineWidth, 0.0, dist);

    // Add glow
    float glow = exp(-dist * 20.0) * 0.5;

    // Color based on frequency
    float hue = uniforms.frequency / 1000.0;
    float3 color = float3(0.0, 1.0, 0.0) * (waveform + glow);

    return float4(color, 1.0);
}

// MARK: - Spectral Analyzer

fragment float4 spectralFragment(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;

    // Create frequency bars
    int numBars = 32;
    float barWidth = 1.0 / float(numBars);
    int barIndex = int(uv.x / barWidth);
    float barX = float(barIndex) * barWidth;

    // Bar height based on frequency and audio level
    float barHeight = uniforms.audioLevel * (0.5 + 0.5 * sin(float(barIndex) * 0.5 + uniforms.time));

    // Check if pixel is within bar
    float isInBar = step(uv.y, barHeight);

    // Color gradient based on height
    float3 lowColor = float3(0.5, 0.0, 1.0);
    float3 highColor = float3(1.0, 0.5, 0.0);
    float3 color = mix(lowColor, highColor, uv.y);

    color *= isInBar;

    // Add bar separation
    float separation = smoothstep(barX + barWidth * 0.9, barX + barWidth, uv.x);
    color *= (1.0 - separation * 0.5);

    return float4(color, 1.0);
}

// MARK: - Mandala Visualization

fragment float4 mandalaFragment(
    VertexOut in [[stage_in]],
    constant Uniforms &uniforms [[buffer(0)]]
) {
    float2 uv = in.texCoord;
    float2 center = float2(0.5, 0.5);
    float2 pos = (uv - center) * 2.0;

    // Polar coordinates
    float dist = length(pos);
    float angle = atan2(pos.y, pos.x);

    // Number of petals based on heart rate
    int numPetals = int(6.0 + uniforms.heartRate / 20.0);
    float petalAngle = 6.28318 / float(numPetals);

    // Rotating mandala
    float rotation = uniforms.time * 0.5;
    angle += rotation;

    // Create petal pattern
    float petalIndex = floor(angle / petalAngle);
    float petalOffset = fmod(angle, petalAngle) - petalAngle * 0.5;

    // Petal shape
    float petal = cos(petalOffset / (petalAngle * 0.5) * 3.14159);
    petal = smoothstep(0.0, 1.0, petal);

    // Radial rings
    float rings = sin(dist * 20.0 - uniforms.time * 2.0) * 0.5 + 0.5;
    rings *= uniforms.audioLevel;

    // Combine patterns
    float pattern = petal * rings;
    pattern *= smoothstep(1.0, 0.0, dist);

    // Color based on HRV coherence
    float hue = uniforms.hrvCoherence / 100.0;
    float3 color = float3(
        0.5 + 0.5 * cos(6.28318 * (hue + 0.0)),
        0.5 + 0.5 * cos(6.28318 * (hue + 0.33)),
        0.5 + 0.5 * cos(6.28318 * (hue + 0.67))
    );

    color *= pattern;

    // Add center glow
    float centerGlow = exp(-dist * 5.0) * 0.3;
    color += centerGlow;

    return float4(color, 1.0);
}

// MARK: - Utility Functions

// HSV to RGB conversion
float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
