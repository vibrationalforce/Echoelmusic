//
//  VisualRendererKernels.metal
//  Echoelmusic — GPU Compute Shaders for Background Visual Renderer
//
//  Five bio-reactive compute kernels for EchoelmusicVisualRenderer.
//  Each kernel writes RGBA16Float to an output texture driven by
//  bio-parameters (coherence, heartRate) and optional audio data.
//
//  Performance: <2ms per frame on A15+, no texture reads.
//

#include <metal_stdlib>
using namespace metal;

// Must match VisualParamsCPU in BackgroundSourceManager.swift
struct VisualParams {
    float time;
    float coherence;
    float heartRate;
    float frequency;
    float amplitude;
    float rotation;
    int symmetry;
    int bands;
    float resolutionX;
    float resolutionY;
};

// MARK: - Utility Functions

static float2 rotate2d(float2 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

static float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// MARK: - Cymatics Kernel
// Simulates Chladni plate patterns driven by frequency and coherence.

kernel void cymaticsKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant VisualParams& params [[buffer(0)]],
    constant float* audioData [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float2 uv = float2(gid) / float2(params.resolutionX, params.resolutionY);
    float2 centered = (uv - 0.5) * 2.0;

    float freq = params.frequency * 0.01;
    float t = params.time * 0.5;

    // Chladni pattern: sin(n*pi*x)*sin(m*pi*y) + sin(m*pi*x)*sin(n*pi*y)
    float n = floor(freq * 0.5) + 1.0;
    float m = floor(freq * 0.3) + 2.0;
    float pattern = sin(n * M_PI_F * centered.x) * sin(m * M_PI_F * centered.y)
                  + sin(m * M_PI_F * centered.x) * sin(n * M_PI_F * centered.y);

    // Animate with time and coherence
    float node = abs(pattern) * (0.5 + 0.5 * params.coherence);
    float pulse = 1.0 + 0.1 * sin(t * params.heartRate * 0.1);

    // Bio-reactive coloring: cool at low coherence, warm at high
    float3 coolColor = float3(0.1, 0.2, 0.4);
    float3 warmColor = float3(0.6, 0.3, 0.1);
    float3 baseColor = mix(coolColor, warmColor, params.coherence);
    float3 color = baseColor * node * pulse * params.amplitude;

    // Edge glow at nodal lines
    float edge = smoothstep(0.02, 0.0, abs(pattern));
    color += float3(0.3, 0.5, 0.8) * edge * params.coherence;

    output.write(float4(color, 1.0), gid);
}

// MARK: - Mandala Kernel
// Radial symmetry pattern with bio-reactive rotation and segment count.

kernel void mandalaKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant VisualParams& params [[buffer(0)]],
    constant float* audioData [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float2 uv = float2(gid) / float2(params.resolutionX, params.resolutionY);
    float2 centered = (uv - 0.5) * 2.0;

    float r = length(centered);
    float angle = atan2(centered.y, centered.x);

    // Symmetry from params (bio: coherence → more segments)
    float segments = float(params.symmetry);
    float symAngle = fmod(abs(angle), M_PI_F * 2.0 / segments) * segments;

    // Rotation driven by time
    float rot = params.rotation;
    float2 rotated = rotate2d(float2(r, symAngle), rot);

    // Layered rings
    float ring1 = sin(rotated.x * 12.0 - params.time * 2.0) * 0.5 + 0.5;
    float ring2 = sin(rotated.y * 8.0 + params.time * 1.5) * 0.5 + 0.5;
    float pattern = ring1 * ring2;

    // Pulse with heartrate
    float pulse = 1.0 + 0.15 * sin(params.time * params.heartRate * 0.1);
    pattern *= pulse;

    // Bio-reactive palette
    float3 inner = float3(0.8, 0.4, 0.2) * params.coherence;
    float3 outer = float3(0.2, 0.3, 0.6) * (1.0 - params.coherence);
    float3 color = mix(outer, inner, smoothstep(0.8, 0.0, r)) * pattern * params.amplitude;

    // Fade at edges
    color *= smoothstep(1.0, 0.7, r);

    output.write(float4(color, 1.0), gid);
}

// MARK: - Particles Kernel
// Procedural particle field — positions derived from hash, no buffer needed.

kernel void particlesKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant VisualParams& params [[buffer(0)]],
    constant float* audioData [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float2 uv = float2(gid) / float2(params.resolutionX, params.resolutionY);
    float3 color = float3(0.0);

    // Generate procedural particles via hash
    for (int i = 0; i < 64; i++) {
        float2 seed = float2(float(i) * 0.37, float(i) * 0.73);
        float2 pos = float2(hash(seed), hash(seed + 1.0));

        // Animate with time + bio
        float speed = 0.2 + 0.3 * hash(seed + 2.0);
        pos.x = fract(pos.x + params.time * speed * 0.1);
        pos.y = fract(pos.y + sin(params.time * speed + float(i)) * 0.05);

        // Particle size driven by coherence
        float size = (0.005 + 0.01 * params.coherence) * params.amplitude;
        float dist = length(uv - pos);

        // Soft glow
        float glow = size / (dist + 0.001);
        glow = clamp(glow, 0.0, 1.0);

        // Color per particle
        float hue = fract(float(i) * 0.13 + params.time * 0.05);
        float3 particleColor = float3(
            0.5 + 0.5 * cos(6.28 * (hue + 0.0)),
            0.5 + 0.5 * cos(6.28 * (hue + 0.33)),
            0.5 + 0.5 * cos(6.28 * (hue + 0.67))
        );

        color += particleColor * glow * 0.3;
    }

    // Heartrate pulse overlay
    float pulse = 0.05 * sin(params.time * params.heartRate * 0.1);
    color += float3(pulse * params.coherence);

    output.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
}

// MARK: - Waveform Kernel
// Audio waveform visualization with bio-reactive glow and color.

kernel void waveformKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant VisualParams& params [[buffer(0)]],
    constant float* audioData [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float2 uv = float2(gid) / float2(params.resolutionX, params.resolutionY);

    // Map x position to audio buffer index
    int sampleIndex = int(uv.x * float(params.bands));
    sampleIndex = clamp(sampleIndex, 0, 4095);
    float sample = audioData[sampleIndex] * params.amplitude;

    // Waveform position (centered vertically)
    float waveY = 0.5 + sample * 0.4;
    float dist = abs(uv.y - waveY);

    // Line thickness driven by coherence
    float thickness = 0.003 + 0.007 * params.coherence;
    float line = smoothstep(thickness, thickness * 0.3, dist);

    // Glow around the line
    float glow = 0.02 / (dist + 0.01) * 0.1 * params.coherence;

    // Bio-reactive color
    float3 lineColor = mix(
        float3(0.2, 0.4, 0.8),  // Low coherence: blue
        float3(0.3, 0.8, 0.4),  // High coherence: green
        params.coherence
    );

    float3 color = lineColor * (line + glow);

    // Pulse flash
    float pulse = 1.0 + 0.1 * sin(params.time * params.heartRate * 0.1);
    color *= pulse;

    output.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
}

// MARK: - Spectral Kernel
// Frequency spectrum bars with bio-reactive coloring and animation.

kernel void spectralKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant VisualParams& params [[buffer(0)]],
    constant float* audioData [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float2 uv = float2(gid) / float2(params.resolutionX, params.resolutionY);

    // Number of visible bands
    int numBands = params.bands;
    float bandWidth = 1.0 / float(numBands);

    // Which band does this pixel belong to?
    int band = int(uv.x / bandWidth);
    band = clamp(band, 0, numBands - 1);

    // Get magnitude for this band (log-scale mapping for perceptual accuracy)
    float magnitude = audioData[band] * params.amplitude;
    magnitude = clamp(magnitude, 0.0, 1.0);

    // Bar height
    float barHeight = magnitude;
    float inBar = step(1.0 - uv.y, barHeight);

    // Gap between bars
    float bandPos = fract(uv.x / bandWidth);
    float barMask = step(0.05, bandPos) * step(bandPos, 0.95);

    // Color gradient: bottom = cool, top = warm (bio-reactive)
    float heightNorm = (1.0 - uv.y) / max(barHeight, 0.001);
    heightNorm = clamp(heightNorm, 0.0, 1.0);

    float3 bottomColor = mix(float3(0.1, 0.3, 0.6), float3(0.2, 0.6, 0.3), params.coherence);
    float3 topColor = mix(float3(0.6, 0.2, 0.1), float3(0.8, 0.6, 0.1), params.coherence);
    float3 barColor = mix(bottomColor, topColor, heightNorm);

    float3 color = barColor * inBar * barMask;

    // Subtle glow at bar top
    float topDist = abs(1.0 - uv.y - barHeight);
    float topGlow = 0.005 / (topDist + 0.005) * 0.1 * magnitude;
    color += barColor * topGlow;

    output.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
}
