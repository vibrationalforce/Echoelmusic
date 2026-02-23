// ═══════════════════════════════════════════════════════════════════════════════
// EchoelExtendedShaders.metal
// Echoelmusic - Extended Bio-Reactive Visual Compute Kernels
// ═══════════════════════════════════════════════════════════════════════════════
//
// 20 advanced GPU compute kernels for bio-reactive visual synthesis.
// Extends VisualRendererKernels.metal (Cymatics, Mandala, Particles, Waveform,
// Spectral) with new shader materials.
//
// Each kernel receives ExtendedVisualParams and writes to a texture2d output.
// Bio-reactive: coherence, heartRate, breathPhase drive visual parameters.
// Audio-reactive: frequency, amplitude, audioLevel drive motion and intensity.
//
// Optimized for Apple GPU families A9+, M1+, Apple GPU 3+.
// Target: 60 FPS at 1080p on iPhone 12+, 4K on M1+ Macs.
//
// Created 2026-02-23
// Copyright (c) 2026 Echoelmusic. All rights reserved.
// ═══════════════════════════════════════════════════════════════════════════════

#include <metal_stdlib>
using namespace metal;

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Extended Parameters
// ═══════════════════════════════════════════════════════════════════════════════
//
// Superset of VisualParams from VisualRendererKernels.metal.
// First 10 fields match VisualParams layout for buffer compatibility.
// Extended fields add breath, audio level, and 4 general-purpose parameters.

struct ExtendedVisualParams {
    float time;          // Animation time in seconds
    float coherence;     // 0-1 HRV coherence (low=stress, high=flow)
    float heartRate;     // BPM (60-200 typical range)
    float frequency;     // Hz — primary audio frequency / cymatics driver
    float amplitude;     // 0-1 — audio amplitude envelope
    float rotation;      // Radians — global rotation offset
    int   symmetry;      // Fold count for symmetric patterns (3-24)
    int   bands;         // Spectral band count for FFT visuals
    float2 resolution;   // Output texture dimensions in pixels
    // --- Extended fields ---
    float breathPhase;   // 0-1 breathing cycle (0=start inhale, 0.5=start exhale)
    float audioLevel;    // 0-1 RMS audio level (smoothed)
    float param1;        // General purpose: shader-specific meaning
    float param2;        // General purpose: shader-specific meaning
    float param3;        // General purpose: shader-specific meaning
    float param4;        // General purpose: shader-specific meaning
};

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Utility Functions (ext_ prefixed to avoid linker conflicts)
// ═══════════════════════════════════════════════════════════════════════════════

/// HSV to RGB color conversion
/// - Parameter c: (hue 0-1, saturation 0-1, value 0-1)
/// - Returns: RGB color
float3 ext_hsv2rgb(float3 c) {
    float3 p = abs(fract(float3(c.x) + float3(0.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
    return c.z * mix(float3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

/// Fast hash function for procedural noise
float ext_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

/// 2D hash returning float2 (for Voronoi point placement etc.)
float2 ext_hash2(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

/// 3D hash for volumetric noise
float3 ext_hash3(float2 p) {
    float3 q = float3(dot(p, float2(127.1, 311.7)),
                       dot(p, float2(269.5, 183.3)),
                       dot(p, float2(419.2, 371.9)));
    return fract(sin(q) * 43758.5453);
}

/// Smooth value noise (Perlin-style interpolation)
float ext_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // Hermite smoothstep
    float a = ext_hash(i);
    float b = ext_hash(i + float2(1.0, 0.0));
    float c = ext_hash(i + float2(0.0, 1.0));
    float d = ext_hash(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

/// Fractal Brownian Motion — layered noise for organic textures
/// - Parameter octaves: Number of noise layers (4-6 typical)
float ext_fbm(float2 p, int octaves) {
    float value = 0.0;
    float amp = 0.5;
    float freq = 1.0;
    for (int i = 0; i < octaves; i++) {
        value += amp * ext_noise(p * freq);
        amp *= 0.5;
        freq *= 2.0;
    }
    return value;
}

/// Smooth pulse function for ring/circle effects
float ext_pulse(float x, float center, float width) {
    float d = abs(x - center);
    return smoothstep(width, 0.0, d);
}

/// Bio-reactive color palette: low coherence = warm reds, high = cool cyans
float3 ext_coherenceColor(float coherence, float phase) {
    float hue = mix(0.0, 0.55, coherence) + phase * 0.1;
    return ext_hsv2rgb(float3(fract(hue), 0.8, 0.9));
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 1. Sacred Geometry — Flower of Life, Metatron's Cube
// ═══════════════════════════════════════════════════════════════════
//
// Draws the Flower of Life pattern (interlocking circles arranged in
// hexagonal symmetry) with Metatron's Cube connecting lines overlaid.
// Bio-reactive: coherence grows the pattern outward, breathing pulses
// the circles, heart rate modulates the rotation speed.

kernel void sacredGeometryKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    p.x *= params.resolution.x / params.resolution.y; // Aspect correction
    float t = params.time;
    float coh = params.coherence;

    // Circle radius breathes with respiratory phase
    float breathScale = sin(params.breathPhase * 2.0 * M_PI_F) * 0.03 + 1.0;
    float circleR = (0.22 + coh * 0.08) * breathScale;
    float lineWidth = 0.006 + coh * 0.004; // Thicker lines at high coherence

    // Rotation speed tied to heart rate
    float rot = t * params.heartRate / 600.0;

    // --- Flower of Life: 3 rings of circles ---
    float pattern = 0.0;

    // Ring 0: center circle
    float d0 = abs(length(p) - circleR);
    pattern += smoothstep(lineWidth, lineWidth * 0.3, d0);

    // Ring 1: 6 circles at radius = circleR
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * M_PI_F / 3.0 + rot;
        float2 center = float2(cos(angle), sin(angle)) * circleR;
        float d = abs(length(p - center) - circleR);
        pattern += smoothstep(lineWidth, lineWidth * 0.3, d);
    }

    // Ring 2: 6 circles at radius = circleR * sqrt(3) (only at high coherence)
    float ring2Alpha = smoothstep(0.3, 0.6, coh);
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * M_PI_F / 3.0 + M_PI_F / 6.0 + rot * 0.5;
        float2 center = float2(cos(angle), sin(angle)) * circleR * 1.732;
        float d = abs(length(p - center) - circleR);
        pattern += smoothstep(lineWidth, lineWidth * 0.3, d) * ring2Alpha;
    }

    // Ring 3: 12 circles (outer seed of life, appears at very high coherence)
    float ring3Alpha = smoothstep(0.6, 0.9, coh);
    for (int i = 0; i < 12; i++) {
        float angle = float(i) * M_PI_F / 6.0 + rot * 0.3;
        float2 center = float2(cos(angle), sin(angle)) * circleR * 2.0;
        float d = abs(length(p - center) - circleR);
        pattern += smoothstep(lineWidth, lineWidth * 0.3, d) * ring3Alpha * 0.5;
    }

    // --- Metatron's Cube: connecting lines between vertices ---
    float lines = 0.0;
    // 6 radial lines through center
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * M_PI_F / 3.0 + rot;
        float2 dir = float2(cos(angle), sin(angle));
        float d = abs(dot(p, float2(-dir.y, dir.x)));
        float maxR = circleR * (1.732 + ring3Alpha);
        float mask = smoothstep(maxR, maxR * 0.95, length(p));
        lines += smoothstep(lineWidth * 0.5, lineWidth * 0.1, d) * mask * 0.25;
    }

    // Hexagonal outline
    float hexDist = 0.0;
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * M_PI_F / 3.0 + rot;
        float2 dir = float2(cos(angle), sin(angle));
        hexDist = max(hexDist, abs(dot(p, dir)));
    }
    float hexLine = smoothstep(lineWidth, lineWidth * 0.3, abs(hexDist - circleR * 1.732));
    lines += hexLine * ring2Alpha * 0.3;

    float combined = clamp(pattern * 0.6 + lines, 0.0, 1.0);

    // Color: golden at high coherence, silver-blue at low
    float hue = fract(0.1 + coh * 0.12 + t * 0.01);
    float sat = 0.4 + coh * 0.4;
    float3 color = ext_hsv2rgb(float3(hue, sat, combined * 0.9));

    // Center glow
    float glow = exp(-length(p) * length(p) * 6.0) * coh * 0.4;
    color += float3(1.0, 0.95, 0.8) * glow;

    // Vignette
    float vig = 1.0 - dot(p * 0.5, p * 0.5);
    color *= max(vig, 0.0);

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 2. Fractal Zoom — Mandelbrot/Julia with bio-reactive coloring
// ═══════════════════════════════════════════════════════════════════
//
// Continuous zoom into the Mandelbrot set with smooth iteration count
// coloring. Coherence controls iteration depth (detail level) and
// smoothly morphs between Mandelbrot and Julia set modes.
// Audio level brightens the color intensity; heart rate pulses edges.

kernel void fractalZoomKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float t = params.time;
    float coh = params.coherence;

    // Exponential zoom into a mini-brot at the antenna tip
    float zoomPow = 2.0 + t * 0.15;
    float zoom = pow(1.5, zoomPow);
    float2 center = float2(-0.7435669, 0.1314023); // Seahorse valley
    float2 c = center + (uv * 2.0 - 1.0) / zoom;

    // Coherence morphs toward Julia set (c becomes fixed, z varies)
    float juliaMix = smoothstep(0.7, 1.0, coh);
    float2 juliaC = float2(-0.4, 0.6 + sin(t * 0.1) * 0.1);
    float2 z = mix(float2(0.0), c, 1.0 - juliaMix);
    float2 iterC = mix(c, juliaC, juliaMix);

    // More iterations at higher coherence for finer detail
    int maxIter = 48 + int(coh * 80.0);
    int iter = 0;
    float smoothVal = 0.0;
    for (int i = 0; i < 128; i++) {
        if (i >= maxIter) break;
        if (dot(z, z) > 256.0) break; // Higher bailout for smoother coloring
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + iterC;
        iter = i;
    }

    // Smooth iteration count (continuous coloring, avoids banding)
    if (iter < maxIter - 1) {
        float zn = sqrt(dot(z, z));
        smoothVal = float(iter) + 1.0 - log2(log2(zn));
    }
    float normalized = smoothVal / float(maxIter);

    // Color palette driven by coherence
    float hue = fract(normalized * 2.5 + coh * 0.5 + t * 0.03);
    float sat = 0.6 + coh * 0.3;
    float heartPulse = sin(t * params.heartRate / 60.0 * M_PI_F) * 0.5 + 0.5;
    float val = (iter < maxIter - 1) ? (0.7 + params.audioLevel * 0.2 + heartPulse * 0.1) : 0.0;
    float3 color = ext_hsv2rgb(float3(hue, sat, val));

    // Edge glow for the set boundary
    float edgeDist = smoothstep(0.0, 0.1, normalized) * smoothstep(1.0, 0.9, normalized);
    color += float3(1.0, 0.9, 0.7) * edgeDist * 0.15 * coh;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 3. Reaction-Diffusion — Gray-Scott inspired patterns
// ═══════════════════════════════════════════════════════════════════
//
// Simulates reaction-diffusion patterns (spots, stripes, coral-like
// structures) by emulating Gray-Scott dynamics procedurally. The feed
// rate (f) and kill rate (k) are driven by coherence, creating different
// pattern regimes: spots at low coherence, labyrinthine at high.
// Breathing phase pulses the pattern brightness.

kernel void reactionDiffusionKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = params.time;
    float coh = params.coherence;

    // Gray-Scott parameters: coherence sweeps through pattern regimes
    // Low coh: spots (f=0.035, k=0.065), High coh: stripes (f=0.055, k=0.062)
    float f = 0.035 + coh * 0.02;
    float k = 0.065 - coh * 0.003;

    // Simulate via layered procedural spots + noise
    float pattern = 0.0;
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        // Spot centers drift slowly
        float2 offset = float2(
            sin(t * 0.15 + fi * 1.618) * (0.4 + fi * 0.05),
            cos(t * 0.12 + fi * 2.399) * (0.4 + fi * 0.05)
        );
        float d = length(p - offset);
        float spotSize = 0.08 + f * 2.0 + sin(t * 0.3 + fi) * 0.02;
        float spot = smoothstep(spotSize + k, spotSize - k * 0.5, d);

        // Ring structure at each spot (reaction front)
        float ring = smoothstep(0.01, 0.0, abs(d - spotSize * 1.5)) * 0.4;
        pattern += spot + ring;
    }

    // Organic noise overlay simulates diffusion
    float noise = ext_fbm(p * 5.0 + float2(t * 0.08, t * 0.06), 5);
    float noisePattern = smoothstep(0.35 - coh * 0.1, 0.65 + coh * 0.1, noise);
    pattern = clamp(pattern * 0.5 + noisePattern * 0.5, 0.0, 1.0);

    // Color: deep blue background, coral/cyan activated areas
    float3 bgColor = float3(0.03, 0.06, 0.12);
    float3 activeColor = ext_hsv2rgb(float3(0.5 + coh * 0.15, 0.75, 0.9));
    float3 edgeColor = ext_hsv2rgb(float3(0.1 + coh * 0.1, 0.8, 0.7));
    float edgeMask = smoothstep(0.4, 0.5, pattern) - smoothstep(0.5, 0.6, pattern);
    float3 color = mix(bgColor, activeColor, pattern) + edgeColor * edgeMask * 0.3;

    // Breathing modulation
    float breathe = sin(params.breathPhase * 2.0 * M_PI_F) * 0.12 + 0.88;
    color *= breathe;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 4. Voronoi Mesh — Audio-driven cells, coherence edges
// ═══════════════════════════════════════════════════════════════════
//
// Animated Voronoi tessellation where cell centers drift with time.
// Audio level pumps cell brightness, coherence makes edges glow brighter
// and cell shapes more regular. Edge detection uses F2-F1 distance.

kernel void voronoiMeshKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    // Grid scale: more cells at higher audio levels
    float gridScale = 5.0 + params.audioLevel * 3.0;
    float2 p = uv * gridScale;
    float t = params.time;
    float coh = params.coherence;

    float2 cellID = float2(0.0);
    float minDist = 10.0;   // F1: distance to nearest cell center
    float secondDist = 10.0; // F2: distance to second nearest

    // Search 3x3 neighborhood for Voronoi
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 neighbor = float2(float(x), float(y));
            float2 cell = floor(p) + neighbor;
            float2 point = ext_hash2(cell);
            // Animate points: smoother at high coherence, jittery at low
            float animSpeed = 0.3 + (1.0 - coh) * 0.5;
            point = 0.5 + 0.5 * sin(t * animSpeed + 6.2831 * point);
            float d = length(neighbor + point - fract(p));
            if (d < minDist) {
                secondDist = minDist;
                minDist = d;
                cellID = cell;
            } else if (d < secondDist) {
                secondDist = d;
            }
        }
    }

    // Edge detection: F2 - F1
    float edge = secondDist - minDist;
    float edgeWidth = 0.02 + coh * 0.06;
    float edgeLine = 1.0 - smoothstep(0.0, edgeWidth, edge);

    // Cell color keyed to cell ID hash
    float cellHue = fract(ext_hash(cellID) + t * 0.015);
    float cellVal = 0.4 + params.audioLevel * 0.4 + minDist * 0.2;
    float3 cellColor = ext_hsv2rgb(float3(cellHue, 0.5 + coh * 0.3, cellVal));

    // Edge glow: warm white at high coherence, dim at low
    float3 edgeColor = mix(float3(0.3, 0.2, 0.15), float3(1.0, 0.95, 0.85), coh);

    // Combine: edge glows over cell interiors
    float3 color = cellColor * (1.0 - edgeLine * 0.5) + edgeColor * edgeLine * (0.3 + coh * 0.7);

    // Heartbeat pulse on edges
    float heartPulse = pow(sin(t * params.heartRate / 60.0 * M_PI_F) * 0.5 + 0.5, 3.0);
    color += edgeColor * edgeLine * heartPulse * 0.2;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 5. Aurora Field — Northern lights curtain effect
// ═══════════════════════════════════════════════════════════════════
//
// Multiple translucent curtains of light sway across the screen,
// mimicking the aurora borealis. Coherence controls the vibrancy
// and saturation; breathing phase gently lifts/lowers the curtains.
// Stars twinkle in the background at a rate tied to heart rate.

kernel void auroraFieldKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float t = params.time;
    float coh = params.coherence;

    float3 color = float3(0.0);

    // Breathing lifts/lowers the aurora band
    float breathLift = sin(params.breathPhase * 2.0 * M_PI_F) * 0.05;

    // 6 curtain layers with different frequencies and speeds
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float layerOffset = fi * 0.618; // Golden ratio spacing

        // Horizontal wave pattern (multiple octaves)
        float wave = sin(uv.x * (2.0 + fi) + t * (0.2 + fi * 0.05) + layerOffset) * 0.12;
        wave += sin(uv.x * (5.0 + fi * 2.0) - t * (0.35 + fi * 0.08) + layerOffset * 3.0) * 0.06;
        wave += ext_noise(float2(uv.x * (1.5 + fi * 0.3), t * (0.08 + fi * 0.02))) * 0.08;

        // Curtain center position with breathing offset
        float y = 0.25 + fi * 0.08 + wave + breathLift;

        // Soft curtain shape: brighter at top, fading downward
        float curtainTop = smoothstep(0.2, 0.0, uv.y - y) * smoothstep(-0.3, 0.0, uv.y - y + 0.3);
        float curtainGlow = exp(-abs(uv.y - y) * 8.0) * 0.5;
        float curtain = (curtainTop + curtainGlow) * (0.3 + 0.7 * coh);

        // Color: green core (557nm), magenta/purple edges
        float hue = 0.28 + fi * 0.04 + coh * 0.15;
        float sat = 0.75 + coh * 0.15;
        float3 auroraColor = ext_hsv2rgb(float3(hue, sat, 1.0));
        color += auroraColor * curtain * (0.35 - fi * 0.03);
    }

    // Star field background
    float2 starGrid = floor(uv * 250.0);
    float starHash = ext_hash(starGrid);
    float isStar = step(0.997, starHash);
    // Twinkle tied to heart rate phase
    float twinkle = sin(t * params.heartRate / 30.0 + starHash * 100.0) * 0.5 + 0.5;
    color += isStar * twinkle * 0.4;

    // Dark sky gradient: deep blue at top, dark teal at horizon
    float3 skyTop = float3(0.0, 0.005, 0.02);
    float3 skyBottom = float3(0.0, 0.02, 0.04);
    float3 sky = mix(skyBottom, skyTop, uv.y);
    color += sky;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 6. Plasma Wave — Classic plasma with bio-reactive cycling
// ═══════════════════════════════════════════════════════════════════
//
// Classic demo-scene plasma effect using overlapping sine waves.
// Coherence shifts the color phase offsets, creating different palette
// "moods" (warm/cool). Heart rate pulses overall brightness.
// Audio level modulates the plasma frequency for visual bass response.

kernel void plasmaWaveKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = params.time;
    float coh = params.coherence;

    // Audio-reactive frequency scaling
    float freqMod = 8.0 + params.audioLevel * 6.0;

    // Four overlapping plasma functions
    float v = sin(p.x * freqMod + t * 1.2);
    v += sin((p.y * freqMod + t * 0.8) * 0.7);
    v += sin((p.x * freqMod * 0.7 + p.y * freqMod * 0.7 + t * 0.6) * 0.5);

    // Radial component with moving center
    float cx = p.x + 0.5 * sin(t * 0.25);
    float cy = p.y + 0.5 * cos(t * 0.35);
    v += sin(sqrt(cx * cx + cy * cy + 1.0) * freqMod + t);
    v *= 0.25;

    // Color channels with coherence-driven phase offsets
    float phaseR = 0.0;
    float phaseG = 2.094 + coh * 1.5;  // 120 degrees + coherence shift
    float phaseB = 4.189 + coh * 0.8;  // 240 degrees + coherence shift

    float r = sin(v * M_PI_F + phaseR) * 0.5 + 0.5;
    float g = sin(v * M_PI_F + phaseG) * 0.5 + 0.5;
    float b = sin(v * M_PI_F + phaseB) * 0.5 + 0.5;

    float3 color = float3(r, g, b);

    // Heartbeat brightness pulse
    float heartPulse = pow(sin(t * params.heartRate / 60.0 * M_PI_F) * 0.5 + 0.5, 2.0);
    color *= (0.85 + heartPulse * 0.15);

    // Breathing warmth shift
    float breathe = sin(params.breathPhase * 2.0 * M_PI_F);
    color.r += breathe * 0.05;
    color.b -= breathe * 0.03;

    output.write(float4(clamp(color, 0.0, 1.0), 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 7. Data Stream — Matrix-style data rain
// ═══════════════════════════════════════════════════════════════════
//
// Cascading columns of glowing characters (matrix rain effect).
// Coherence controls the fall speed: high coherence = faster, more
// organized streams. Audio level brightens the leading head of each
// stream. Each column has independent speed and phase.

kernel void dataStreamKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float t = params.time;
    float coh = params.coherence;

    float3 color = float3(0.0);
    float columns = 50.0;
    float colWidth = 1.0 / columns;

    // 4 depth layers for parallax effect
    for (int layer = 0; layer < 4; layer++) {
        float layerF = float(layer);
        float layerScale = 1.0 - layerF * 0.15; // Further layers dimmer
        float layerCols = columns * (1.0 + layerF * 0.3);

        float colIndex = floor(uv.x * layerCols);
        float colCenter = (colIndex + 0.5) / layerCols;

        // Per-column random properties
        float colSeed = ext_hash(float2(colIndex, layerF * 7.0));
        float speed = (0.2 + colSeed * 0.6) * (0.5 + coh * 0.8);
        float trailLen = 0.15 + colSeed * 0.2;

        // Drop position (wrapping)
        float dropY = fract(t * speed + colSeed * 10.0);
        float dist = uv.y - (1.0 - dropY); // Top-down rain

        // Trail: fades behind the leading edge
        float trail = smoothstep(trailLen, 0.0, dist) * smoothstep(-0.01, 0.01, dist);
        // Bright leading head
        float head = smoothstep(0.015, 0.0, abs(dist));

        // Column mask (only within this column)
        float colMask = smoothstep(colWidth * 0.4, colWidth * 0.1, abs(uv.x - colCenter));

        float brightness = (trail * 0.4 + head * (0.8 + params.audioLevel * 0.5)) * colMask;
        brightness *= layerScale;

        // Character grid simulation (small squares within column)
        float charGrid = step(0.4, fract(uv.y * layerCols * 2.0)) * 0.3 + 0.7;
        brightness *= charGrid;

        // Color: green primary, coherence shifts toward cyan
        float3 streamColor = mix(float3(0.0, 0.5, 0.1), float3(0.0, 0.8, 0.4 + coh * 0.3), head);
        color += streamColor * brightness;
    }

    // Subtle dark green background glow
    color += float3(0.0, 0.015, 0.005);

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 8. Tunnel Effect — Infinite tunnel zoom with rotation
// ═══════════════════════════════════════════════════════════════════
//
// Infinite tunnel (wormhole) effect using polar coordinate inversion.
// Coherence controls forward speed, breathing modulates the tunnel
// diameter (claustrophobic vs expansive). Rotation param spins the
// tunnel. Audio level adds wobble to the tunnel walls.

kernel void tunnelEffectKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    p.x *= params.resolution.x / params.resolution.y;
    float t = params.time;
    float coh = params.coherence;

    // Audio wobble on tunnel walls
    float wobble = sin(atan2(p.y, p.x) * 3.0 + t * 2.0) * params.audioLevel * 0.1;

    float angle = atan2(p.y, p.x);
    float radius = length(p) + wobble;

    // Tunnel UV mapping: depth = 1/radius, angle = texture U
    float speed = 0.3 + coh * 0.7;
    float tunnelZ = 1.0 / (radius + 0.01) + t * speed;
    float tunnelA = angle / M_PI_F + params.rotation + t * 0.1;

    // Breathing modulates apparent tunnel diameter
    float breathe = sin(params.breathPhase * 2.0 * M_PI_F) * 0.15;
    tunnelZ += breathe;

    // Checkerboard pattern with smooth edges
    float checkU = sin(tunnelZ * 5.0);
    float checkV = sin(tunnelA * 8.0);
    float pattern = smoothstep(-0.05, 0.05, checkU * checkV);

    // Ring lines at regular depth intervals
    float rings = smoothstep(0.02, 0.0, abs(fract(tunnelZ * 0.5) - 0.5));

    // Depth fog (further = darker, with coherence controlling visibility)
    float depth = 1.0 / (radius + 0.01);
    float fog = exp(-depth * (0.1 + (1.0 - coh) * 0.15));

    // Color: depth-hue cycling
    float hue = fract(tunnelZ * 0.04 + coh * 0.3);
    float3 wallColor = ext_hsv2rgb(float3(hue, 0.6 + coh * 0.2, pattern * 0.7 + 0.2));
    float3 ringColor = float3(1.0, 0.95, 0.85) * rings * 0.4;

    float3 color = (wallColor + ringColor) * fog;

    // Center bright light (tunnel exit/entrance)
    float centerGlow = exp(-radius * radius * 4.0) * 0.3;
    color += float3(1.0, 0.95, 0.9) * centerGlow;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 9. Fluid Simulation — Navier-Stokes inspired flow
// ═══════════════════════════════════════════════════════════════════
//
// Emulates fluid dynamics using advected FBM noise layers. Multiple
// dye colors flow and mix, driven by a velocity field that curls and
// swirls. Coherence controls viscosity (high = smooth laminar flow,
// low = turbulent). Audio level injects energy (faster flow).

kernel void fluidSimulationKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = params.time;
    float coh = params.coherence;

    // Velocity field (curl noise for divergence-free flow)
    float flowSpeed = 0.15 + params.audioLevel * 0.25;
    float turbulence = 1.0 + (1.0 - coh) * 2.0; // Low coherence = turbulent

    float3 color = float3(0.0);

    // 5 layers of advected dye
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float layerPhase = fi * 1.618; // Golden ratio separation

        // Compute velocity field using curl of noise potential
        float2 noiseCoord = p * (1.5 + fi * 0.3) + float2(t * flowSpeed + layerPhase, 0.0);
        float potentialR = ext_fbm(noiseCoord + float2(0.01, 0.0), 4);
        float potentialL = ext_fbm(noiseCoord - float2(0.01, 0.0), 4);
        float potentialU = ext_fbm(noiseCoord + float2(0.0, 0.01), 4);
        float potentialD = ext_fbm(noiseCoord - float2(0.0, 0.01), 4);

        // Curl: perpendicular to gradient
        float2 velocity = float2(potentialU - potentialD, potentialL - potentialR) * turbulence;

        // Advect position
        float2 advected = p + velocity * (0.4 + fi * 0.1);

        // Sample density at advected position
        float density = ext_fbm(advected * (2.0 + fi * 0.5) + float2(t * 0.05, t * 0.03), 5);
        density = smoothstep(0.25, 0.75, density);

        // Dye color: each layer has a different hue
        float hue = fract(fi * 0.2 + coh * 0.3 + t * 0.015);
        float sat = 0.6 + coh * 0.25;
        float3 dyeColor = ext_hsv2rgb(float3(hue, sat, 0.85));
        color += dyeColor * density * 0.25;
    }

    // Dark background with slight blue tint
    color += float3(0.015, 0.015, 0.035);

    // Breathing modulates overall flow brightness
    float breathe = sin(params.breathPhase * 2.0 * M_PI_F) * 0.08 + 0.92;
    color *= breathe;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 10. Crystal Formation — Growing ice/crystal branches
// ═══════════════════════════════════════════════════════════════════
//
// Dendrite crystal growth radiating from center with 6-fold symmetry
// (snowflake/ice pattern). Coherence increases the number of branches
// and sub-branches (more intricate crystals at high coherence).
// Growth front advances with time; breathing pulses the crystal glow.

kernel void crystalFormationKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    p.x *= params.resolution.x / params.resolution.y;
    float t = params.time;
    float coh = params.coherence;

    float crystal = 0.0;
    int branches = 6 + int(coh * 6.0);

    // Growth front advances with time
    float growthRadius = fract(t * 0.15) * 1.2;

    for (int i = 0; i < 12; i++) {
        if (i >= branches) break;
        float angle = float(i) * 2.0 * M_PI_F / float(branches);
        float2 dir = float2(cos(angle), sin(angle));

        // Main branch: line from center along dir
        float projection = dot(p, dir);
        float perp = length(p - dir * max(projection, 0.0));
        float growth = smoothstep(growthRadius, growthRadius - 0.05, length(p));
        float branchWidth = 0.02 + coh * 0.01;

        float branch = smoothstep(branchWidth, branchWidth * 0.2, perp) *
                       step(0.0, projection) * growth;

        // Sub-branches at 60-degree angles (fractal-like)
        for (int j = -1; j <= 1; j += 2) {
            float subAngle = angle + float(j) * M_PI_F / (3.0 + coh * 3.0);
            float2 subDir = float2(cos(subAngle), sin(subAngle));

            // Sub-branch origins along main branch
            for (int k = 1; k <= 3; k++) {
                float fk = float(k);
                float2 origin = dir * fk * 0.15;
                float subProj = dot(p - origin, subDir);
                float subPerp = length(p - origin - subDir * max(subProj, 0.0));
                float subLen = 0.15 - fk * 0.03;
                float subBranch = smoothstep(branchWidth * 0.6, branchWidth * 0.1, subPerp) *
                                 smoothstep(0.0, 0.02, subProj) *
                                 smoothstep(subLen, subLen * 0.5, subProj) * growth;
                crystal += subBranch * (0.5 - fk * 0.1);
            }
        }

        crystal += branch;
    }

    crystal = clamp(crystal, 0.0, 1.0);

    // Crystal color: translucent ice blue, brighter at edges
    float3 iceColor = mix(float3(0.3, 0.5, 0.9), float3(0.85, 0.92, 1.0), crystal);
    float3 bg = float3(0.02, 0.02, 0.06);
    float3 color = mix(bg, iceColor, crystal);

    // Breathing glow on crystal
    float breathGlow = sin(params.breathPhase * 2.0 * M_PI_F) * 0.15 + 0.85;
    color *= breathGlow;

    // Center seed glow
    float centerGlow = exp(-dot(p, p) * 10.0) * 0.2;
    color += float3(0.6, 0.8, 1.0) * centerGlow;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 11. Fire Embers — Rising particle-like embers with audio
// ═══════════════════════════════════════════════════════════════════
//
// Glowing ember particles rise from the bottom of the screen, with
// horizontal drift, fading as they ascend. Audio level launches more
// embers higher and faster. Coherence controls color temperature:
// low = angry red/orange, high = warm golden glow.

kernel void fireEmbersKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float t = params.time;
    float coh = params.coherence;

    float3 color = float3(0.0);

    // 100 ember particles
    for (int i = 0; i < 100; i++) {
        float fi = float(i);
        float2 seed = float2(fi * 0.73, fi * 1.37);
        float2 basePos = ext_hash2(seed);

        // Rise speed: faster with audio level
        float speed = 0.15 + basePos.y * 0.25 + params.audioLevel * 0.5;
        // Horizontal drift with sinusoidal wobble
        float drift = sin(t * (1.0 + basePos.x * 2.0) + fi) * 0.04;
        float x = basePos.x + drift;
        // Vertical: rising from bottom, wrapping
        float y = fract(basePos.y * 0.2 + t * speed);

        float2 emberPos = float2(x, 1.0 - y);
        float d = length(uv - emberPos);

        // Life fades as ember rises
        float life = pow(1.0 - y, 1.5);
        float size = (0.0015 + basePos.x * 0.002) * life;
        float glow = size / (d * d + 0.00005);

        // Color temperature: hot white core -> orange -> red as it cools
        float temp = life * (0.5 + coh * 0.5);
        float3 emberColor = mix(
            float3(0.8, 0.1, 0.0),  // Cool red
            float3(1.0, 0.9, 0.4),  // Hot yellow-white
            temp
        );
        color += emberColor * glow * 0.002 * life;
    }

    // Base fire glow at bottom
    float fireGlow = exp(-(1.0 - uv.y) * 3.0) * 0.15;
    float fireNoise = ext_noise(float2(uv.x * 5.0, t * 3.0)) * 0.5 + 0.5;
    float3 fireColor = mix(float3(0.4, 0.05, 0.0), float3(0.6, 0.15, 0.0), fireNoise);
    color += fireColor * fireGlow * (0.5 + params.audioLevel * 0.5);

    // Heartbeat flicker
    float heartFlicker = sin(t * params.heartRate / 60.0 * M_PI_F * 2.0) * 0.5 + 0.5;
    color *= (0.9 + heartFlicker * 0.1);

    // Reinhard tone mapping
    color = color / (1.0 + color);

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 12. Ocean Waves — Coherence-driven calm/storm ocean
// ═══════════════════════════════════════════════════════════════════
//
// Stylized ocean surface viewed from above/side. Coherence maps
// directly to sea state: high coherence = glassy calm waters,
// low coherence = stormy choppy seas. Audio level adds splash energy.
// Breathing phase gently rocks the horizon.

kernel void oceanWavesKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float t = params.time;
    float coh = params.coherence;

    float stormLevel = 1.0 - coh; // Low coherence = storm

    // Breathing rocks the horizon
    float horizonShift = sin(params.breathPhase * 2.0 * M_PI_F) * 0.02;

    // Composite wave function (6 octaves)
    float waves = 0.0;
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        float freq = 1.5 + fi * 1.2;
        float amp = 0.08 / (fi + 1.0) * (0.3 + stormLevel * 0.7);
        float speed = 0.4 + fi * 0.15 + params.audioLevel * 0.3;
        float phase = fi * 1.37;
        waves += sin(uv.x * freq * 12.0 + t * speed + phase) * amp;
        // Cross-wave for choppiness
        waves += sin((uv.x * 0.7 + uv.y * 0.3) * freq * 8.0 - t * speed * 0.6 + phase) * amp * 0.3 * stormLevel;
    }

    float waterLine = 0.45 + waves + horizonShift;
    float isWater = smoothstep(waterLine + 0.005, waterLine - 0.005, uv.y);

    // Water color with depth
    float depth = clamp((waterLine - uv.y) * 4.0, 0.0, 1.0);
    float3 shallowColor = mix(float3(0.05, 0.35, 0.5), float3(0.1, 0.55, 0.65), coh);
    float3 deepColor = float3(0.01, 0.05, 0.12);
    float3 waterColor = mix(shallowColor, deepColor, depth);

    // Subsurface scattering (light through wave crests)
    float subsurface = smoothstep(0.03, 0.0, abs(uv.y - waterLine + 0.01)) * 0.3;
    waterColor += float3(0.1, 0.3, 0.2) * subsurface * coh;

    // Foam at crest: more foam in storms
    float foamWidth = 0.005 + stormLevel * 0.02;
    float foam = smoothstep(foamWidth, 0.0, abs(uv.y - waterLine));
    foam += ext_noise(float2(uv.x * 20.0, t * 2.0)) * 0.3 * smoothstep(0.05, 0.0, abs(uv.y - waterLine));
    waterColor += clamp(foam, 0.0, 1.0) * float3(0.8, 0.9, 1.0) * (0.3 + stormLevel * 0.7);

    // Specular highlight (sun reflection)
    float specular = pow(max(0.0, sin(uv.x * 30.0 + t * 0.3 + waves * 5.0)), 20.0) * 0.3;
    waterColor += specular * float3(1.0, 0.95, 0.85) * coh;

    // Sky gradient with clouds
    float3 skyTop = mix(float3(0.15, 0.25, 0.5), float3(0.05, 0.08, 0.2), stormLevel);
    float3 skyBottom = mix(float3(0.5, 0.65, 0.85), float3(0.2, 0.25, 0.35), stormLevel);
    float3 skyColor = mix(skyBottom, skyTop, (uv.y - waterLine) / (1.0 - waterLine + 0.001));

    // Simple cloud layer
    float clouds = ext_fbm(float2(uv.x * 3.0 + t * 0.02, (uv.y - 0.5) * 2.0), 4);
    clouds = smoothstep(0.4, 0.6, clouds) * 0.3 * (1.0 - stormLevel * 0.5);
    skyColor += clouds;

    float3 color = mix(skyColor, waterColor, isWater);
    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 13. Electric Field — Lightning arcs between points
// ═══════════════════════════════════════════════════════════════════
//
// Multiple electric arcs jump between anchor points, with jagged
// paths generated from high-frequency noise. Audio level increases
// the jitter (wilder arcs), coherence controls brightness and arc
// count. Heart rate triggers periodic bright flashes (lightning).

kernel void electricFieldKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    p.x *= params.resolution.x / params.resolution.y;
    float t = params.time;
    float coh = params.coherence;

    float3 color = float3(0.0);
    int arcCount = 3 + int(coh * 4.0);

    // Lightning flash on heartbeat
    float heartPhase = fract(t * params.heartRate / 60.0);
    float flash = pow(max(0.0, 1.0 - heartPhase * 8.0), 4.0);

    for (int i = 0; i < 7; i++) {
        if (i >= arcCount) break;
        float fi = float(i);

        // Anchor points that slowly orbit
        float2 start = float2(
            sin(t * 0.3 + fi * 2.1) * 0.7,
            cos(t * 0.25 + fi * 1.7) * 0.7
        );
        float2 end = float2(
            sin(t * 0.35 + fi * 1.3 + 3.0) * 0.7,
            cos(t * 0.28 + fi * 2.3 + 3.0) * 0.7
        );

        // Trace arc path with jagged noise displacement
        float segments = 30.0;
        float minDist = 10.0;
        float jitterStrength = 0.08 + params.audioLevel * 0.2;

        for (float s = 0.0; s < segments; s += 1.0) {
            float progress = s / segments;
            float2 segPos = mix(start, end, progress);

            // Jagged displacement perpendicular to arc direction
            float2 arcDir = normalize(end - start);
            float2 perpDir = float2(-arcDir.y, arcDir.x);
            // High-frequency time-varying noise for the zap effect
            float jitter = ext_noise(float2(s * 7.0, t * 15.0 + fi * 137.0)) - 0.5;
            jitter += ext_noise(float2(s * 15.0, t * 25.0 + fi * 73.0)) * 0.5 - 0.25;
            segPos += perpDir * jitter * jitterStrength * sin(progress * M_PI_F);

            float d = length(p - segPos);
            minDist = min(minDist, d);
        }

        // Arc glow (inverse distance, bright core)
        float arcIntensity = 0.003 / (minDist * minDist + 0.0002);
        arcIntensity *= (0.2 + coh * 0.8);

        // Color: blue-white core, purple-blue glow
        float3 coreColor = float3(0.7, 0.8, 1.0);
        float3 glowColor = float3(0.3, 0.4, 0.9);
        float3 arcColor = mix(glowColor, coreColor, smoothstep(0.0, 1.0, arcIntensity));
        color += arcColor * arcIntensity * 0.15;
    }

    // Ambient electric field glow
    float ambientGlow = exp(-dot(p, p) * 1.5) * params.audioLevel * 0.15;
    color += float3(0.15, 0.2, 0.5) * ambientGlow;

    // Flash overlay on heartbeat
    color += float3(0.3, 0.35, 0.6) * flash * 0.3;

    // Tone map
    color = color / (1.0 + color);

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 14. Morphing Blob — Metaball merge and split
// ═══════════════════════════════════════════════════════════════════
//
// Classic metaball (isosurface) effect where blobs merge smoothly
// when close. Audio level spawns more blobs; coherence controls how
// smoothly they merge (high = organic, low = sharp boundaries).
// Heart rate pulses blob sizes in sync with the beat.

kernel void morphingBlobKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    p.x *= params.resolution.x / params.resolution.y;
    float t = params.time;
    float coh = params.coherence;

    // Heartbeat pulse on blob sizes
    float heartPulse = pow(sin(t * params.heartRate / 60.0 * M_PI_F) * 0.5 + 0.5, 3.0);

    float field = 0.0;
    int blobCount = 4 + int(params.audioLevel * 6.0);

    for (int i = 0; i < 10; i++) {
        if (i >= blobCount) break;
        float fi = float(i);

        // Each blob orbits at different speeds on Lissajous paths
        float2 center = float2(
            sin(t * (0.2 + fi * 0.07) + fi * 2.094) * (0.4 + fi * 0.05),
            cos(t * (0.25 + fi * 0.09) + fi * 1.571) * (0.4 + fi * 0.05)
        );

        // Blob radius with heartbeat and per-blob phase
        float baseRadius = 0.12 + fi * 0.01;
        float radius = baseRadius * (0.8 + coh * 0.2 + heartPulse * 0.1);
        radius += sin(t * 0.6 + fi * 1.5) * 0.02;

        float d = length(p - center);
        // Metaball potential field (1/r^2 falloff)
        field += (radius * radius) / (d * d + 0.0005);
    }

    // Isosurface threshold
    float threshold = 1.0;
    float iso = smoothstep(threshold - 0.05, threshold + 0.05, field);

    // Edge highlight (bright rim where field ~ threshold)
    float edgeWidth = 0.08 + coh * 0.08;
    float edge = smoothstep(threshold - edgeWidth, threshold, field) -
                 smoothstep(threshold, threshold + edgeWidth, field);

    // Interior gradient
    float interior = smoothstep(threshold, threshold + 1.0, field);

    // Color: hue varies with field strength
    float hue = fract(field * 0.08 + t * 0.015 + coh * 0.3);
    float3 blobColor = ext_hsv2rgb(float3(hue, 0.65 + coh * 0.2, 0.75 + interior * 0.2));
    float3 edgeColor = float3(1.0, 0.95, 0.9);
    float3 bg = float3(0.02, 0.02, 0.05);

    float3 color = bg + blobColor * iso + edgeColor * edge * (0.3 + coh * 0.4);

    // Breathing ambient modulation
    float breathe = sin(params.breathPhase * 2.0 * M_PI_F) * 0.06 + 0.94;
    color *= breathe;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 15. Kaleidoscope — Advanced multi-axis symmetry
// ═══════════════════════════════════════════════════════════════════
//
// Kaleidoscopic symmetry applied to FBM noise with mirror reflections.
// The symmetry order is controlled by the params.symmetry field (4-24).
// Coherence controls pattern complexity and color richness. Audio
// level modulates the radial wave speed. Includes concentric rings
// and a central jewel-like glow.

kernel void kaleidoscopeKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    p.x *= params.resolution.x / params.resolution.y;
    float t = params.time;
    float coh = params.coherence;
    int sym = max(params.symmetry, 4);

    float r = length(p);
    float a = atan2(p.y, p.x);

    // Apply rotational symmetry with mirror reflections
    float segAngle = 2.0 * M_PI_F / float(sym);
    float originalA = a;
    a = fmod(a + M_PI_F, segAngle);
    // Mirror alternate segments for true kaleidoscope effect
    if (fmod(floor((originalA + M_PI_F) / segAngle), 2.0) > 0.5) {
        a = segAngle - a;
    }

    // Reconstruct position in symmetry-reduced space
    float2 kp = float2(cos(a), sin(a)) * r;

    // Layered pattern: FBM + radial waves + angular features
    float waveSpeed = 1.5 + params.audioLevel * 2.0;
    float pattern = ext_fbm(kp * (2.5 + coh) + float2(t * 0.15, t * 0.1), 5);
    pattern += sin(r * 12.0 - t * waveSpeed) * 0.2;          // Radial wave
    pattern += sin(a * 5.0 + t * 0.5) * 0.15 * coh;          // Angular feature
    pattern = smoothstep(0.15, 0.85, pattern);

    // Concentric ring accents
    float rings = smoothstep(0.02, 0.0, abs(fract(r * 5.0 - t * 0.3) - 0.5)) * 0.2;

    // Color: radial hue shift with coherence warmth
    float hue = fract(r * 0.25 + a * 0.08 + t * 0.02 + coh * 0.4);
    float sat = 0.6 + coh * 0.3;
    float val = pattern * 0.8 + rings;
    float3 color = ext_hsv2rgb(float3(hue, sat, val));

    // Central jewel glow
    float jewel = exp(-r * r * 8.0) * (0.3 + coh * 0.4);
    float3 jewelColor = ext_hsv2rgb(float3(fract(t * 0.05), 0.5, 1.0));
    color += jewelColor * jewel;

    // Radial fade
    float fade = smoothstep(1.3, 0.1, r);
    color *= fade;

    // Breathing luminance modulation
    float breathe = sin(params.breathPhase * 2.0 * M_PI_F) * 0.08 + 0.92;
    color *= breathe;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 16. Nebula Clouds — Volumetric gas clouds
// ═══════════════════════════════════════════════════════════════════
//
// Multi-layered nebula gas clouds using high-octave FBM with different
// color channels. Coherence controls the clarity (high = visible detail,
// low = more obscured). Breathing phase slowly shifts the nebula drift.
// Stars twinkle in the background at heart-rate-influenced frequency.

kernel void nebulaCloudsKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = params.time;
    float coh = params.coherence;

    float3 color = float3(0.0);

    // Breathing-driven drift direction
    float breathDrift = sin(params.breathPhase * 2.0 * M_PI_F) * 0.01;

    // 5 cloud layers with distinct hues (emission nebula, reflection nebula, dust)
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float2 offset = float2(
            t * (0.02 + fi * 0.008) + breathDrift,
            t * (0.015 + fi * 0.005) * (1.0 - fi * 0.1)
        );

        // High-octave FBM for detailed cloud structure
        float density = ext_fbm(p * (1.2 + fi * 0.4) + offset + fi * 1.618, 6);

        // Coherence sharpens the cloud edges
        float lo = 0.3 - coh * 0.08;
        float hi = 0.6 + coh * 0.1;
        density = smoothstep(lo, hi, density);

        // Each layer has a different nebula color
        float3 nebulaColor;
        if (i == 0) nebulaColor = float3(0.6, 0.1, 0.2);   // Red emission (H-alpha)
        else if (i == 1) nebulaColor = float3(0.2, 0.1, 0.5); // Blue reflection
        else if (i == 2) nebulaColor = float3(0.1, 0.3, 0.4); // Teal (OIII)
        else if (i == 3) nebulaColor = float3(0.5, 0.3, 0.1); // Warm dust
        else nebulaColor = float3(0.3, 0.05, 0.3);            // Purple (SII)

        // Coherence shifts palette: high coherence = cooler, low = warmer
        nebulaColor = mix(nebulaColor, nebulaColor.bgr, coh * 0.3);

        color += nebulaColor * density * (0.3 - fi * 0.03);
    }

    // Star field with twinkling
    float2 starGrid = floor(uv * 350.0);
    float starHash = ext_hash(starGrid);
    float isStar = step(0.996, starHash);
    // Twinkle frequency influenced by heart rate
    float twinkleFreq = 2.0 + (params.heartRate / 60.0) * 0.5;
    float twinkle = sin(t * twinkleFreq + starHash * 50.0) * 0.5 + 0.5;
    // Star color varies
    float3 starColor = ext_hsv2rgb(float3(starHash * 0.3, 0.2, 1.0));
    color += isStar * twinkle * starColor * 0.5;

    // Bright star centers (fewer, larger)
    float brightStar = step(0.9995, starHash);
    float brightGlow = exp(-length(uv - (starGrid + 0.5) / 350.0) * 350.0 * 3.0);
    color += brightStar * brightGlow * 0.4 * starColor;

    // Deep space background
    color += float3(0.008, 0.004, 0.015);

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 17. Geometric Patterns — Islamic star / tiling patterns
// ═══════════════════════════════════════════════════════════════════
//
// Islamic geometric star patterns with interlacing lines on a tiled
// grid. Coherence controls the intricacy (more star points at high
// coherence). The pattern slowly rotates with time. Audio level
// pulses tile fill brightness. Breathing shifts the color palette.

kernel void geometricPatternsKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 8.0;
    float t = params.time;
    float coh = params.coherence;

    float2 cell = floor(p);
    float2 f = fract(p) - 0.5;

    // Slow rotation of the entire pattern
    float angle = t * 0.03 + params.rotation * 0.5;
    float ca = cos(angle), sa = sin(angle);
    float2 rp = float2(f.x * ca - f.y * sa, f.x * sa + f.y * ca);

    // Star pattern: number of points varies with coherence
    int points = 6 + int(coh * 6.0); // 6 to 12-pointed star
    float star = 0.0;
    for (int i = 0; i < 12; i++) {
        if (i >= points) break;
        float a = float(i) * 2.0 * M_PI_F / float(points);
        float2 dir = float2(cos(a), sin(a));
        float d = abs(dot(rp, dir));
        star = max(star, d);
    }

    // Star fill and outline
    float starFill = smoothstep(0.38, 0.36, star);
    float starLine = smoothstep(0.39, 0.38, star) - smoothstep(0.37, 0.36, star);

    // Grid lines (interlace pattern)
    float gridX = smoothstep(0.01, 0.003, abs(f.x));
    float gridY = smoothstep(0.01, 0.003, abs(f.y));
    float grid = max(gridX, gridY);

    // Diagonal interlace lines
    float diagA = smoothstep(0.01, 0.003, abs(f.x + f.y));
    float diagB = smoothstep(0.01, 0.003, abs(f.x - f.y));
    float diag = max(diagA, diagB) * coh;

    // Tile color: alternating hues per cell
    float cellParity = fmod(cell.x + cell.y, 2.0);
    float hue = fract(cellParity * 0.15 + coh * 0.3 + sin(params.breathPhase * 2.0 * M_PI_F) * 0.05 + t * 0.008);
    float3 tileColor = ext_hsv2rgb(float3(hue, 0.45 + coh * 0.3, 0.6 + params.audioLevel * 0.2));
    float3 lineColor = float3(0.85, 0.8, 0.65); // Golden lines
    float3 bg = float3(0.04, 0.03, 0.05);

    // Composite
    float3 color = bg;
    color = mix(color, tileColor, starFill);
    color += lineColor * (starLine * 0.6 + grid * 0.25 + diag * 0.15);

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 18. Liquid Light — 1960s psychedelic light show
// ═══════════════════════════════════════════════════════════════════
//
// Emulates a 1960s liquid light show projector: colored oil and water
// between glass plates, heated from below. Multiple dye layers flow
// and morph, creating organic blob interactions. Coherence controls
// the "heat" (flow speed); audio level brightens and saturates.
// Breathing phase gently pulses the overall glow.

kernel void liquidLightKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = params.time;
    float coh = params.coherence;

    // Flow speed increases with coherence ("heat")
    float flowSpeed = 0.08 + coh * 0.12;

    // 4 flowing dye layers with different viscosities
    float v1 = ext_fbm(p * 1.8 + float2(t * flowSpeed, t * flowSpeed * 0.7), 6);
    float v2 = ext_fbm(p * 1.4 + float2(-t * flowSpeed * 0.8, t * flowSpeed * 1.1), 6);
    float v3 = ext_fbm(p * 2.2 + float2(t * flowSpeed * 0.5, -t * flowSpeed * 0.9), 5);
    float v4 = ext_fbm(p * 1.0 + float2(-t * flowSpeed * 0.3, -t * flowSpeed * 0.4), 5);

    // Sharp blob boundaries (oil/water separation)
    float blob1 = smoothstep(0.42, 0.58, v1);
    float blob2 = smoothstep(0.44, 0.62, v2);
    float blob3 = smoothstep(0.38, 0.56, v3);
    float blob4 = smoothstep(0.46, 0.60, v4);

    // Psychedelic color palette (intense, saturated)
    float satBoost = 0.7 + params.audioLevel * 0.3;
    float3 color = float3(0.0);
    color += float3(0.95, 0.15, 0.3) * blob1 * satBoost;  // Hot pink
    color += float3(0.1, 0.25, 0.95) * blob2 * satBoost;   // Electric blue
    color += float3(0.95, 0.75, 0.05) * blob3 * satBoost;  // Acid yellow
    color += float3(0.6, 0.1, 0.85) * blob4 * 0.5;          // Deep purple

    // Blend interactions (where blobs overlap, colors mix and brighten)
    float overlap = blob1 * blob2 + blob2 * blob3 + blob1 * blob3;
    color += float3(1.0, 0.6, 0.8) * overlap * 0.15;

    // Coherence warmth shift
    float warmth = coh * 0.2;
    color.r += warmth * 0.3;
    color.b -= warmth * 0.15;

    // Breathing glow
    float breathe = sin(params.breathPhase * 2.0 * M_PI_F) * 0.1 + 0.9;
    color *= breathe;

    // Vignette (projector light circle)
    float vig = 1.0 - smoothstep(0.6, 1.2, length(p));
    color *= vig;

    // Soft clamp with a warm tone bias
    color = clamp(color, 0.0, 1.0);

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 19. Coherence Field — Bio-reactive wave interference field
// ═══════════════════════════════════════════════════════════════════
//
// Visualizes coherence as an interference pattern: multiple wave
// sources emit ripples at heart rate frequency, and their coherent
// superposition creates constructive/destructive interference.
// High coherence = ordered, beautiful interference fringes.
// Low coherence = chaotic, noisy field. Contour lines show
// equal-amplitude surfaces. Center indicator grows with coherence.

kernel void coherenceFieldKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    p.x *= params.resolution.x / params.resolution.y;
    float t = params.time;
    float coh = params.coherence;
    float hr = params.heartRate;

    // Heart rate drives wave emission frequency
    float waveFreq = hr / 60.0;

    // Multiple wave sources
    float field = 0.0;
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        // Source positions: more organized at high coherence
        float2 center = float2(
            sin(t * 0.15 + fi * 1.2 + (1.0 - coh) * sin(t * 2.0 + fi)) * 0.5,
            cos(t * 0.12 + fi * 0.8 + (1.0 - coh) * cos(t * 1.5 + fi)) * 0.5
        );

        float d = length(p - center);

        // Coherent wave: all sources emit at same phase (high coh)
        // Decoherent wave: random phase offsets (low coh)
        float phaseOffset = (1.0 - coh) * ext_hash(float2(fi, 0.0)) * 6.28;
        float wave = sin(d * 12.0 - t * waveFreq * 6.28 + phaseOffset + fi * coh);
        float amplitude = 1.0 / (d * 2.5 + 0.5);
        field += wave * amplitude;
    }

    // Normalize field
    field = field / 8.0 * 0.5 + 0.5;

    // Color mapping: coherence determines palette
    float3 lowColor = float3(0.7, 0.15, 0.08);   // Warm red (stress/chaos)
    float3 midColor = float3(0.6, 0.6, 0.2);      // Yellow (transition)
    float3 highColor = float3(0.08, 0.5, 0.7);    // Cool teal (flow state)

    float3 baseColor;
    if (coh < 0.5) {
        baseColor = mix(lowColor, midColor, coh * 2.0);
    } else {
        baseColor = mix(midColor, highColor, (coh - 0.5) * 2.0);
    }

    float3 color = baseColor * field;

    // Contour lines (topographic map appearance)
    float contourSpacing = 6.0 + coh * 4.0;
    float contour = smoothstep(0.015, 0.003, abs(fract(field * contourSpacing) - 0.5));
    color += float3(1.0, 0.95, 0.9) * contour * 0.2;

    // Center coherence indicator: growing circle shows coherence level
    float indicatorRadius = coh * 0.4 + 0.05;
    float indicatorRing = smoothstep(0.015, 0.005, abs(length(p) - indicatorRadius));
    float indicatorFill = smoothstep(indicatorRadius, indicatorRadius - 0.02, length(p)) * 0.1;
    float3 indicatorColor = mix(float3(0.8, 0.3, 0.2), float3(0.2, 0.85, 0.4), coh);
    color += indicatorColor * (indicatorRing * 0.5 + indicatorFill);

    // Breathing pulse on the entire field
    float breathe = sin(params.breathPhase * 2.0 * M_PI_F) * 0.08 + 0.92;
    color *= breathe;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 20. Breathing Guide — Visual breathing circle
// ═══════════════════════════════════════════════════════════════════

kernel void breathingGuideKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    p.x *= params.resolution.x / params.resolution.y;
    float t = params.time;
    float coh = params.coherence;
    float breathPhase = params.breathPhase;

    float dist = length(p);

    // Main breathing circle
    float breathSize = 0.2 + breathPhase * 0.3;
    float circle = smoothstep(breathSize + 0.02, breathSize - 0.02, dist);
    float ring = smoothstep(breathSize + 0.03, breathSize + 0.01, dist) -
                 smoothstep(breathSize - 0.01, breathSize - 0.03, dist);

    // Color based on coherence (green=good, red=stressed)
    float3 circleColor = mix(float3(0.3, 0.5, 0.8), float3(0.2, 0.8, 0.4), coh);
    float3 ringColor = float3(1.0, 1.0, 1.0) * 0.5;

    // Soft glow
    float glow = exp(-dist * dist * 3.0) * breathPhase * 0.3;
    float3 glowColor = circleColor * 0.5;

    // Pulse rings expanding outward
    float3 pulseColor = float3(0.0);
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float pulseRadius = fract(breathPhase + fi * 0.33) * 0.8;
        float pulseFade = 1.0 - fract(breathPhase + fi * 0.33);
        float pulseRing = smoothstep(0.02, 0.0, abs(dist - pulseRadius));
        pulseColor += circleColor * pulseRing * pulseFade * 0.3;
    }

    // Heart rate indicator dots
    float hrPulse = sin(t * params.heartRate / 60.0 * M_PI_F * 2.0) * 0.5 + 0.5;
    float hrDot = smoothstep(0.04, 0.02, abs(dist - 0.08)) * hrPulse;
    float3 hrColor = mix(float3(1.0, 0.3, 0.3), float3(0.3, 1.0, 0.5), coh) * hrDot;

    // Compose
    float3 bg = float3(0.02, 0.02, 0.04);
    float3 color = bg + glowColor * glow + circleColor * circle * 0.6 +
                   ringColor * ring + pulseColor + hrColor;

    output.write(float4(color, 1.0), gid);
}
