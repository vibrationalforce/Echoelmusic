// VisualRendererKernels.metal
// GPU compute kernels for bio-reactive visual renderers:
// Cymatics, Mandala, Particles, Waveform, Spectral

#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Params

struct VisualParams {
    float time;
    float coherence;     // 0-1 HRV coherence
    float heartRate;     // BPM
    float frequency;     // Hz (cymatics)
    float amplitude;     // 0-1
    float rotation;      // radians
    int   symmetry;      // mandala fold count
    int   bands;         // spectral band count
    float2 resolution;
};

// MARK: - Color Helpers

float3 vr_hsv2rgb(float3 c) {
    float3 p = abs(fract(float3(c.x) + float3(0.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
    return c.z * mix(float3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float3 vr_coherenceColor(float coherence, float phase) {
    // Low coherence = warm reds, high = cool cyans/blues
    float hue = mix(0.0, 0.55, coherence) + phase * 0.1;
    return vr_hsv2rgb(float3(fract(hue), 0.8, 0.9));
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 1. Cymatics — Chladni plate wave interference
// ═══════════════════════════════════════════════════════════════════

kernel void cymaticsKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant VisualParams &params        [[buffer(0)]],
    uint2 gid                            [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;

    float freq = params.frequency;
    float t = params.time;
    float coh = params.coherence;

    // Chladni pattern: sin(n*pi*x)*sin(m*pi*y) - sin(m*pi*x)*sin(n*pi*y)
    float n = freq / 100.0;
    float m = n * 1.618; // golden ratio harmonic

    float chladni = sin(n * M_PI_F * p.x) * sin(m * M_PI_F * p.y)
                  - sin(m * M_PI_F * p.x) * sin(n * M_PI_F * p.y);

    // Add time-varying ripple
    float dist = length(p);
    float ripple = sin(dist * freq * 0.05 - t * 3.0) * params.amplitude;

    // Combine with coherence-driven interference
    float pattern = abs(chladni) * (0.5 + 0.5 * coh) + ripple * 0.3;

    // Nodal lines glow brighter (where pattern ~ 0)
    float nodal = 1.0 - smoothstep(0.0, 0.08 + 0.05 * coh, abs(chladni));

    // Color: coherence drives palette
    float3 baseColor = vr_coherenceColor(coh, t * 0.2);
    float3 nodalColor = float3(1.0, 0.95, 0.85); // warm white

    float3 color = mix(baseColor * pattern, nodalColor, nodal * 0.7);

    // Vignette
    float vig = 1.0 - dot(p, p) * 0.4;
    color *= vig;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 2. Mandala — Rotational symmetry sacred geometry
// ═══════════════════════════════════════════════════════════════════

kernel void mandalaKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant VisualParams &params        [[buffer(0)]],
    uint2 gid                            [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;

    float t = params.time;
    float coh = params.coherence;
    int sym = max(params.symmetry, 3);

    // Polar coordinates
    float r = length(p);
    float a = atan2(p.y, p.x);

    // Apply rotational symmetry
    float segAngle = 2.0 * M_PI_F / float(sym);
    float symAngle = fmod(a + M_PI_F, segAngle);
    // Mirror alternate segments for kaleidoscope
    if (fmod(floor((a + M_PI_F) / segAngle), 2.0) > 0.5) {
        symAngle = segAngle - symAngle;
    }

    // Reconstruct position in symmetry space
    float2 sp = float2(cos(symAngle), sin(symAngle)) * r;

    // Concentric rings — breathing with heart rate
    float breathCycle = sin(t * params.heartRate / 60.0 * M_PI_F) * 0.5 + 0.5;
    float rings = sin((r * 8.0 - t * 0.5) * M_PI_F) * 0.5 + 0.5;

    // Petal pattern from symmetry
    float petals = sin(symAngle * 3.0 + t * 0.3) * 0.5 + 0.5;

    // Flower of life circles
    float flower = 0.0;
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * M_PI_F / 3.0 + params.rotation;
        float2 center = float2(cos(angle), sin(angle)) * 0.3;
        float d = length(p - center);
        flower += smoothstep(0.32, 0.28, d);
    }
    flower = clamp(flower, 0.0, 1.0);

    // Combine layers
    float pattern = mix(rings, petals, coh) * 0.6 + flower * 0.4;

    // Radial fade
    float fade = smoothstep(1.2, 0.2, r);

    // Color: golden spiral hue shift
    float hue = fract(r * 0.3 + a / (2.0 * M_PI_F) * 0.2 + t * 0.05);
    float sat = 0.6 + coh * 0.3;
    float val = pattern * fade * (0.7 + breathCycle * 0.3);

    float3 color = vr_hsv2rgb(float3(hue, sat, val));

    // Center glow
    float glow = exp(-r * r * 8.0) * coh;
    color += float3(1.0, 0.9, 0.7) * glow;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 3. Particles — Bio-reactive point field
// ═══════════════════════════════════════════════════════════════════

// Hash for particle positions
float2 vr_particleHash(float2 p, float seed) {
    p = float2(dot(p, float2(127.1 + seed, 311.7)),
               dot(p, float2(269.5, 183.3 + seed)));
    return fract(sin(p) * 43758.5453);
}

kernel void particlesKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant VisualParams &params        [[buffer(0)]],
    constant float *audioData            [[buffer(1)]],
    uint2 gid                            [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float2 uv = float2(gid) / params.resolution;
    float t = params.time;
    float coh = params.coherence;
    float hr = params.heartRate;

    float3 color = float3(0.0);
    float totalGlow = 0.0;

    // Generate particle field — 128 particles per pass
    for (int i = 0; i < 128; i++) {
        float fi = float(i);
        float2 seed = float2(fi * 0.73, fi * 1.37);

        // Particle position: orbital motion modulated by coherence
        float2 basePos = vr_particleHash(seed, 0.0);
        float orbitR = basePos.x * 0.4 + 0.05;
        float orbitSpeed = (basePos.y - 0.5) * 2.0;

        // Heart rate drives pulse
        float pulse = sin(t * hr / 60.0 * M_PI_F + fi * 0.5) * 0.5 + 0.5;

        // High coherence → organized spiral, low → chaotic scatter
        float angle = t * orbitSpeed * (0.5 + coh) + fi * 2.399; // golden angle
        float radius = orbitR * (1.0 + (1.0 - coh) * sin(t * 3.0 + fi));

        float2 pos = float2(0.5) + float2(cos(angle), sin(angle)) * radius;

        // Particle glow
        float d = length(uv - pos);
        float size = 0.003 + pulse * 0.004 * coh;
        float glow = size / (d * d + 0.0001);

        // Color per particle — coherence shifts hue range
        float hue = fract(fi * 0.618 + coh * 0.3);
        float3 particleColor = vr_hsv2rgb(float3(hue, 0.7 + coh * 0.2, 1.0));

        color += particleColor * glow * 0.0015;
        totalGlow += glow;
    }

    // Background subtle gradient
    float3 bg = vr_coherenceColor(coh, t * 0.1) * 0.03;
    color = bg + color;

    // Tone map
    color = color / (1.0 + color);

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 4. Waveform — Audio waveform visualization
// ═══════════════════════════════════════════════════════════════════

kernel void waveformKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant VisualParams &params        [[buffer(0)]],
    constant float *audioData            [[buffer(1)]],
    uint2 gid                            [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float2 uv = float2(gid) / params.resolution;
    float coh = params.coherence;
    float t = params.time;

    int fftSize = int(params.frequency); // reuse frequency field for fftSize
    if (fftSize < 64) fftSize = 2048;

    // Sample audio at this x position
    int sampleIdx = int(uv.x * float(fftSize));
    sampleIdx = clamp(sampleIdx, 0, fftSize - 1);
    float sample = audioData[sampleIdx];

    // Waveform line — centered at y=0.5
    float waveY = 0.5 + sample * 0.35 * params.amplitude;

    // Line thickness (thicker with coherence)
    float thickness = 0.004 + coh * 0.003;
    float dist = abs(uv.y - waveY);
    float line = smoothstep(thickness, 0.0, dist);

    // Glow around line
    float glowDist = abs(uv.y - waveY);
    float glow = exp(-glowDist * glowDist * 800.0) * 0.5;

    // Mirror waveform
    float mirrorY = 0.5 - sample * 0.35 * params.amplitude;
    float mirrorDist = abs(uv.y - mirrorY);
    float mirrorLine = smoothstep(thickness * 0.7, 0.0, mirrorDist) * 0.3;
    float mirrorGlow = exp(-mirrorDist * mirrorDist * 1200.0) * 0.2;

    // Color: position-based hue shift
    float hue = fract(uv.x * 0.3 + coh * 0.5 + t * 0.05);
    float3 waveColor = vr_hsv2rgb(float3(hue, 0.8, 1.0));
    float3 mirrorColor = vr_hsv2rgb(float3(fract(hue + 0.5), 0.6, 0.7));

    // Combine
    float3 color = waveColor * (line + glow) + mirrorColor * (mirrorLine + mirrorGlow);

    // Subtle grid lines
    float gridX = smoothstep(0.002, 0.0, fract(uv.x * 16.0));
    float gridY = smoothstep(0.002, 0.0, fract(uv.y * 8.0));
    float grid = max(gridX, gridY) * 0.04;
    color += float3(grid);

    // Background
    float3 bg = float3(0.02, 0.02, 0.04);
    color = bg + color;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 5. Spectral — FFT frequency spectrum bars
// ═══════════════════════════════════════════════════════════════════

kernel void spectralKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant VisualParams &params        [[buffer(0)]],
    constant float *fftMagnitudes        [[buffer(1)]],
    uint2 gid                            [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;

    float2 uv = float2(gid) / params.resolution;
    float coh = params.coherence;
    float t = params.time;
    int bandCount = max(params.bands, 8);

    // Which band does this pixel belong to?
    float bandWidth = 1.0 / float(bandCount);
    int band = int(uv.x / bandWidth);
    band = clamp(band, 0, bandCount - 1);

    // Read magnitude for this band (log-scaled)
    float mag = fftMagnitudes[band];

    // Smoothed bar height
    float barHeight = mag * params.amplitude;

    // Bar shape with gap
    float barCenter = (float(band) + 0.5) * bandWidth;
    float barX = abs(uv.x - barCenter);
    float barGap = bandWidth * 0.1;
    float inBar = step(barX, bandWidth * 0.5 - barGap);

    // Bar fill from bottom
    float barFill = step(1.0 - uv.y, barHeight) * inBar;

    // Peak dot (holds at max)
    float peakY = 1.0 - barHeight;
    float peakDot = smoothstep(0.008, 0.0, abs(uv.y - peakY)) * inBar;

    // Color: frequency-mapped hue (low=red, mid=green, high=blue)
    float hue = float(band) / float(bandCount) * 0.8;
    float sat = 0.7 + coh * 0.2;
    float val = 0.8 + mag * 0.2;
    float3 barColor = vr_hsv2rgb(float3(hue, sat, val));

    // Gradient within bar (brighter at top)
    float gradient = uv.y * 0.5 + 0.5;
    float3 color = barColor * barFill * gradient;

    // Peak dot: white-hot
    color += float3(1.0, 0.95, 0.85) * peakDot * 0.8;

    // Reflection below
    float reflY = 1.0 - (1.0 - uv.y) * 0.3;
    if (uv.y > 0.85) {
        float reflFill = step(reflY, barHeight) * inBar * 0.15;
        color += barColor * reflFill;
    }

    // Background
    float3 bg = float3(0.015, 0.015, 0.03);
    color = bg + color;

    output.write(float4(color, 1.0), gid);
}
