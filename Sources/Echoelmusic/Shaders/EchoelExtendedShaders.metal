// EchoelExtendedShaders.metal
// 20+ advanced GPU compute kernels for bio-reactive visual synthesis
// Extends VisualRendererKernels.metal with new shader materials
//
// Each kernel receives ExtendedVisualParams and writes to a texture2d output.
// Bio-reactive: coherence, heartRate, breathPhase drive visual parameters.
// Audio-reactive: frequency, amplitude, audioLevel drive motion and intensity.

#include <metal_stdlib>
using namespace metal;

// MARK: - Extended Parameters

struct ExtendedVisualParams {
    float time;
    float coherence;     // 0-1 HRV coherence
    float heartRate;     // BPM
    float frequency;     // Hz
    float amplitude;     // 0-1
    float rotation;      // radians
    int   symmetry;      // fold count
    int   bands;         // spectral band count
    float2 resolution;
    // Extended
    float breathPhase;   // 0-1
    float audioLevel;    // 0-1
    float param1;
    float param2;
    float param3;
    float param4;
};

// MARK: - Utility Functions

float3 ext_hsv2rgb(float3 c) {
    float3 p = abs(fract(float3(c.x) + float3(0.0, 2.0/3.0, 1.0/3.0)) * 6.0 - 3.0);
    return c.z * mix(float3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

float ext_hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float2 ext_hash2(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

float ext_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = ext_hash(i);
    float b = ext_hash(i + float2(1.0, 0.0));
    float c = ext_hash(i + float2(0.0, 1.0));
    float d = ext_hash(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

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

// ═══════════════════════════════════════════════════════════════════
// MARK: - 1. Sacred Geometry — Flower of Life + Metatron's Cube
// ═══════════════════════════════════════════════════════════════════

kernel void sacredGeometryKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = params.time;
    float coh = params.coherence;

    float pattern = 0.0;
    float circleR = 0.25 + coh * 0.1;

    // Flower of Life: 7 interlocking circles
    pattern += smoothstep(circleR + 0.01, circleR - 0.01, length(p));
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * M_PI_F / 3.0 + t * 0.05;
        float2 center = float2(cos(angle), sin(angle)) * circleR;
        pattern += smoothstep(circleR + 0.01, circleR - 0.01, length(p - center));
    }
    // Second ring
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * M_PI_F / 3.0 + M_PI_F / 6.0 + t * 0.03;
        float2 center = float2(cos(angle), sin(angle)) * circleR * 1.732;
        pattern += smoothstep(circleR + 0.01, circleR - 0.01, length(p - center)) * 0.5;
    }

    // Metatron's Cube lines (connecting nodes)
    float lines = 0.0;
    for (int i = 0; i < 6; i++) {
        float angle = float(i) * M_PI_F / 3.0;
        float2 dir = float2(cos(angle), sin(angle));
        float d = abs(dot(p, float2(-dir.y, dir.x)));
        lines += smoothstep(0.008, 0.002, d) * 0.3;
    }

    float combined = clamp(pattern * 0.4 + lines, 0.0, 1.0);
    float hue = fract(0.1 + coh * 0.3 + t * 0.02);
    float3 color = ext_hsv2rgb(float3(hue, 0.6 + coh * 0.3, combined));

    float breathPulse = sin(params.breathPhase * 2.0 * M_PI_F) * 0.15 + 0.85;
    color *= breathPulse;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 2. Fractal Zoom — Mandelbrot with bio-reactive coloring
// ═══════════════════════════════════════════════════════════════════

kernel void fractalZoomKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float t = params.time;
    float coh = params.coherence;

    // Zoom level driven by time
    float zoom = 1.5 + sin(t * 0.1) * 0.5;
    float2 center = float2(-0.745, 0.186);
    float2 c = center + (uv * 2.0 - 1.0) / zoom;
    float2 z = float2(0.0);

    int maxIter = 64 + int(coh * 64.0);
    int iter = 0;
    for (int i = 0; i < 128; i++) {
        if (i >= maxIter) break;
        if (dot(z, z) > 4.0) break;
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        iter = i;
    }

    float smoothIter = float(iter) - log2(log2(dot(z, z)));
    float normalized = smoothIter / float(maxIter);

    float hue = fract(normalized * 3.0 + coh * 0.5 + t * 0.05);
    float sat = 0.7 + coh * 0.2;
    float val = (iter < maxIter) ? 0.8 + params.audioLevel * 0.2 : 0.0;
    float3 color = ext_hsv2rgb(float3(hue, sat, val));

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 3. Reaction-Diffusion — Gray-Scott patterns
// ═══════════════════════════════════════════════════════════════════

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

    float f = 0.0545 + coh * 0.01;
    float k = 0.062 + (1.0 - coh) * 0.005;

    float pattern = 0.0;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float2 offset = float2(sin(t * 0.3 + fi), cos(t * 0.2 + fi * 1.5)) * 0.5;
        float d = length(p - offset);
        float spot = smoothstep(0.3 + f, 0.1 + k, d);
        pattern += spot;
    }

    float noise = ext_fbm(p * 4.0 + t * 0.1, 4);
    pattern = clamp(pattern + noise * 0.3, 0.0, 1.0);

    float3 color1 = float3(0.05, 0.1, 0.2);
    float3 color2 = ext_hsv2rgb(float3(0.55 + coh * 0.15, 0.8, 0.9));
    float3 color = mix(color1, color2, pattern);

    float pulse = sin(params.breathPhase * 2.0 * M_PI_F) * 0.1 + 0.9;
    color *= pulse;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 4. Voronoi Mesh — Audio-driven cells, coherence edges
// ═══════════════════════════════════════════════════════════════════

kernel void voronoiMeshKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 6.0;
    float t = params.time;
    float coh = params.coherence;

    float2 cellID = float2(0.0);
    float minDist = 10.0;
    float secondDist = 10.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 neighbor = float2(float(x), float(y));
            float2 cell = floor(p) + neighbor;
            float2 point = ext_hash2(cell);
            point = 0.5 + 0.5 * sin(t * 0.5 + 6.28 * point);
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

    float edge = secondDist - minDist;
    float edgeLine = smoothstep(0.0, 0.05 + coh * 0.05, edge);

    float hue = fract(ext_hash(cellID) + t * 0.02);
    float3 cellColor = ext_hsv2rgb(float3(hue, 0.6 + coh * 0.3, 0.7 + params.audioLevel * 0.3));
    float3 edgeColor = float3(1.0, 0.95, 0.85) * coh;

    float3 color = mix(edgeColor, cellColor, edgeLine);
    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 5. Aurora Field — Northern lights curtains
// ═══════════════════════════════════════════════════════════════════

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

    for (int i = 0; i < 5; i++) {
        float fi = float(i) * 0.7;
        float wave = sin(uv.x * 3.0 + t * 0.3 + fi) * 0.15;
        wave += sin(uv.x * 7.0 - t * 0.5 + fi * 2.0) * 0.08;
        wave += ext_noise(float2(uv.x * 2.0 + fi, t * 0.1)) * 0.1;

        float y = 0.3 + fi * 0.1 + wave;
        float curtain = smoothstep(0.15, 0.0, abs(uv.y - y));
        curtain *= (0.5 + 0.5 * coh);

        float hue = 0.3 + fi * 0.05 + coh * 0.2;
        float3 auroraColor = ext_hsv2rgb(float3(hue, 0.8, 1.0));
        color += auroraColor * curtain * 0.5;
    }

    // Stars background
    float stars = step(0.998, ext_hash(floor(uv * 200.0)));
    color += stars * 0.3;

    // Dark sky gradient
    float3 sky = mix(float3(0.0, 0.02, 0.05), float3(0.0, 0.0, 0.02), uv.y);
    color += sky;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 6. Plasma Wave — Bio-reactive color cycling
// ═══════════════════════════════════════════════════════════════════

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

    float v = sin(p.x * 10.0 + t);
    v += sin((p.y * 10.0 + t) * 0.5);
    v += sin((p.x * 10.0 + p.y * 10.0 + t * 0.7) * 0.5);
    float cx = p.x + 0.5 * sin(t * 0.3);
    float cy = p.y + 0.5 * cos(t * 0.4);
    v += sin(sqrt(cx * cx + cy * cy + 1.0) * 10.0 + t);
    v *= 0.25;

    float r = sin(v * M_PI_F) * 0.5 + 0.5;
    float g = sin(v * M_PI_F + 2.094 + coh * 2.0) * 0.5 + 0.5;
    float b = sin(v * M_PI_F + 4.189 + coh) * 0.5 + 0.5;

    float3 color = float3(r, g, b);
    float pulse = sin(params.heartRate / 60.0 * t * M_PI_F * 2.0) * 0.1 + 0.9;
    color *= pulse;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 7. Data Stream — Matrix-style data rain
// ═══════════════════════════════════════════════════════════════════

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
    float columns = 40.0;

    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float colX = floor(uv.x * columns + fi * 13.37) / columns;
        float speed = 0.3 + ext_hash(float2(colX, fi)) * 0.7;
        speed *= (0.5 + coh * 1.0);

        float dropY = fract(t * speed + ext_hash(float2(colX * 100.0, fi)));
        float dist = abs(uv.y - dropY);

        float trail = smoothstep(0.3, 0.0, dist) * smoothstep(0.0, 0.01, dist);
        float head = smoothstep(0.02, 0.0, dist);

        float brightness = trail * 0.4 + head * 1.0;
        brightness *= step(abs(uv.x - colX - 0.5 / columns), 0.4 / columns);

        float3 streamColor = mix(float3(0.0, 0.4, 0.1), float3(0.0, 1.0, 0.3), head);
        color += streamColor * brightness * (0.5 + fi * 0.2);
    }

    color += float3(0.0, 0.02, 0.01);
    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 8. Tunnel Effect — Infinite tunnel zoom
// ═══════════════════════════════════════════════════════════════════

kernel void tunnelEffectKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = params.time;
    float coh = params.coherence;

    float angle = atan2(p.y, p.x);
    float radius = length(p);

    float tunnelZ = 1.0 / (radius + 0.001) + t * (0.5 + coh * 0.5);
    float tunnelA = angle / M_PI_F + params.rotation;

    float pattern = sin(tunnelZ * 4.0) * sin(tunnelA * 6.0);
    pattern = smoothstep(-0.1, 0.1, pattern);

    float fog = smoothstep(2.0, 0.0, 1.0 / (radius + 0.001));
    float hue = fract(tunnelZ * 0.05 + coh * 0.3);
    float3 color = ext_hsv2rgb(float3(hue, 0.7, pattern * fog));

    float breathScale = sin(params.breathPhase * 2.0 * M_PI_F) * 0.1 + 0.9;
    color *= breathScale;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 9. Fluid Simulation — Simplified Navier-Stokes
// ═══════════════════════════════════════════════════════════════════

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

    // Multiple flow layers
    float3 color = float3(0.0);
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float2 flow = float2(
            ext_fbm(p * 2.0 + float2(t * 0.2 + fi, 0.0), 4),
            ext_fbm(p * 2.0 + float2(0.0, t * 0.15 + fi), 4)
        );

        float2 advected = p + flow * (0.3 + coh * 0.3);
        float density = ext_fbm(advected * 3.0 + t * 0.1, 5);
        density = smoothstep(0.2, 0.8, density);

        float hue = fract(fi * 0.25 + coh * 0.3 + t * 0.02);
        float3 layerColor = ext_hsv2rgb(float3(hue, 0.7, 0.8));
        color += layerColor * density * 0.3;
    }

    color += float3(0.02, 0.02, 0.04);
    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 10. Crystal Formation — Growing crystal branches
// ═══════════════════════════════════════════════════════════════════

kernel void crystalFormationKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = params.time;
    float coh = params.coherence;

    float crystal = 0.0;
    int branches = 6 + int(coh * 6.0);

    for (int i = 0; i < 12; i++) {
        if (i >= branches) break;
        float angle = float(i) * 2.0 * M_PI_F / float(branches);
        float2 dir = float2(cos(angle), sin(angle));

        float projection = dot(p, dir);
        float perp = length(p - dir * projection);
        float growth = smoothstep(0.0, 0.8 + sin(t * 0.3) * 0.2, projection);

        float branch = smoothstep(0.03, 0.005, perp) * growth;

        // Sub-branches
        float subAngle = angle + M_PI_F / float(branches);
        float2 subDir = float2(cos(subAngle), sin(subAngle));
        float2 branchStart = dir * 0.3;
        float subProj = dot(p - branchStart, subDir);
        float subPerp = length(p - branchStart - subDir * subProj);
        float subBranch = smoothstep(0.02, 0.003, subPerp) *
                         smoothstep(0.0, 0.3, subProj) *
                         smoothstep(0.5, 0.3, subProj);

        crystal += branch + subBranch * 0.5;
    }

    crystal = clamp(crystal, 0.0, 1.0);
    float3 crystalColor = mix(float3(0.4, 0.6, 1.0), float3(0.8, 0.9, 1.0), crystal);
    float3 bg = float3(0.02, 0.02, 0.06);
    float3 color = mix(bg, crystalColor, crystal);

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 11. Fire Embers — Rising particles with audio
// ═══════════════════════════════════════════════════════════════════

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

    for (int i = 0; i < 80; i++) {
        float fi = float(i);
        float2 seed = float2(fi * 0.73, fi * 1.37);
        float2 basePos = ext_hash2(seed);

        float speed = 0.2 + basePos.y * 0.3 + params.audioLevel * 0.5;
        float x = basePos.x + sin(t * basePos.y * 2.0 + fi) * 0.05;
        float y = fract(basePos.y * 0.3 + t * speed);

        float2 emberPos = float2(x, 1.0 - y);
        float d = length(uv - emberPos);

        float life = 1.0 - y;
        float size = (0.002 + basePos.x * 0.003) * life;
        float glow = size / (d * d + 0.0001);

        float temp = life;
        float3 emberColor = mix(float3(1.0, 0.2, 0.0), float3(1.0, 0.8, 0.2), temp);
        color += emberColor * glow * 0.003 * life;
    }

    // Base fire glow
    float fireGlow = smoothstep(1.0, 0.7, uv.y) * 0.1;
    color += float3(0.3, 0.05, 0.0) * fireGlow;

    color = color / (1.0 + color); // Tonemap
    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 12. Ocean Waves — Coherence-driven calm/storm
// ═══════════════════════════════════════════════════════════════════

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

    float waves = 0.0;
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float freq = 2.0 + fi * 1.5;
        float amp = 0.1 / (fi + 1.0) * (0.5 + stormLevel * 0.5);
        float speed = 0.5 + fi * 0.2;
        waves += sin(uv.x * freq * 10.0 + t * speed + fi) * amp;
    }

    float waterLine = 0.5 + waves;
    float isWater = step(uv.y, waterLine);

    // Water color
    float depth = (waterLine - uv.y) * 5.0;
    float3 shallowColor = float3(0.1, 0.5, 0.6);
    float3 deepColor = float3(0.02, 0.1, 0.2);
    float3 waterColor = mix(shallowColor, deepColor, clamp(depth, 0.0, 1.0));

    // Foam at crest
    float foam = smoothstep(0.02, 0.0, abs(uv.y - waterLine));
    waterColor += foam * float3(0.8, 0.9, 1.0);

    // Sky gradient
    float3 skyColor = mix(float3(0.4, 0.6, 0.9), float3(0.1, 0.15, 0.3), uv.y);

    float3 color = mix(skyColor, waterColor, isWater);
    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 13. Electric Field — Lightning arcs
// ═══════════════════════════════════════════════════════════════════

kernel void electricFieldKernel(
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

    // Multiple electric arcs
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float2 start = float2(-0.8, -0.5 + fi * 0.25);
        float2 end = float2(0.8, -0.3 + fi * 0.2 + sin(t + fi) * 0.2);

        float segments = 20.0;
        float minDist = 10.0;

        for (float s = 0.0; s < segments; s += 1.0) {
            float progress = s / segments;
            float2 segPos = mix(start, end, progress);
            float jitter = ext_noise(float2(s * 5.0, t * 10.0 + fi * 100.0)) - 0.5;
            segPos.y += jitter * (0.1 + params.audioLevel * 0.2) * sin(progress * M_PI_F);
            float d = length(p - segPos);
            minDist = min(minDist, d);
        }

        float arc = 0.005 / (minDist + 0.001);
        float3 arcColor = mix(float3(0.3, 0.5, 1.0), float3(0.8, 0.9, 1.0), arc);
        color += arcColor * arc * 0.1 * (0.3 + coh * 0.7);
    }

    // Ambient glow
    float glow = exp(-length(p) * 2.0) * params.audioLevel * 0.2;
    color += float3(0.2, 0.3, 0.8) * glow;

    color = color / (1.0 + color);
    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 14. Morphing Blob — Metaballs
// ═══════════════════════════════════════════════════════════════════

kernel void morphingBlobKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = params.time;
    float coh = params.coherence;

    float field = 0.0;
    int blobCount = 5 + int(params.audioLevel * 5.0);

    for (int i = 0; i < 10; i++) {
        if (i >= blobCount) break;
        float fi = float(i);
        float2 center = float2(
            sin(t * 0.3 + fi * 2.1) * 0.6,
            cos(t * 0.4 + fi * 1.7) * 0.6
        );
        float radius = 0.15 + sin(t * 0.5 + fi) * 0.05;
        radius *= (0.7 + coh * 0.3);
        float d = length(p - center);
        field += radius * radius / (d * d + 0.001);
    }

    float iso = smoothstep(0.95, 1.05, field);
    float edge = smoothstep(0.9, 1.0, field) - smoothstep(1.0, 1.1, field);

    float hue = fract(field * 0.1 + t * 0.02 + coh * 0.3);
    float3 blobColor = ext_hsv2rgb(float3(hue, 0.7 + coh * 0.2, 0.8));
    float3 edgeColor = float3(1.0, 0.95, 0.9);
    float3 bg = float3(0.02, 0.02, 0.05);

    float3 color = bg + blobColor * iso + edgeColor * edge * 0.5;
    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 15. Kaleidoscope — Multi-axis symmetry
// ═══════════════════════════════════════════════════════════════════

kernel void kaleidoscopeKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = params.time;
    float coh = params.coherence;
    int sym = max(params.symmetry, 4);

    float r = length(p);
    float a = atan2(p.y, p.x);

    float segAngle = 2.0 * M_PI_F / float(sym);
    a = fmod(a + M_PI_F, segAngle);
    if (fmod(floor((atan2(p.y, p.x) + M_PI_F) / segAngle), 2.0) > 0.5)
        a = segAngle - a;

    float2 kp = float2(cos(a), sin(a)) * r;

    float pattern = ext_fbm(kp * 3.0 + t * 0.2, 5);
    pattern += sin(r * 10.0 - t * 2.0) * 0.3;
    pattern = smoothstep(0.2, 0.8, pattern);

    float hue = fract(r * 0.3 + a * 0.1 + t * 0.03 + coh * 0.5);
    float3 color = ext_hsv2rgb(float3(hue, 0.7 + coh * 0.2, pattern));

    float fade = smoothstep(1.2, 0.0, r);
    color *= fade;

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 16. Nebula Clouds — Volumetric gas
// ═══════════════════════════════════════════════════════════════════

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

    // Multiple cloud layers
    for (int i = 0; i < 4; i++) {
        float fi = float(i);
        float2 offset = float2(t * 0.03 * (fi + 1.0), t * 0.02 * fi);
        float density = ext_fbm(p * (1.5 + fi * 0.5) + offset, 6);
        density = smoothstep(0.3 - coh * 0.1, 0.7 + coh * 0.1, density);

        float hue = fract(0.6 + fi * 0.15 + coh * 0.2);
        float3 nebulaColor = ext_hsv2rgb(float3(hue, 0.6, 0.8));
        color += nebulaColor * density * 0.3;
    }

    // Stars
    float stars = step(0.997, ext_hash(floor(uv * 300.0)));
    float twinkle = sin(t * 3.0 + ext_hash(floor(uv * 300.0)) * 20.0) * 0.5 + 0.5;
    color += stars * twinkle * 0.5;

    color += float3(0.01, 0.005, 0.02);
    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 17. Geometric Patterns — Islamic/Penrose tiling
// ═══════════════════════════════════════════════════════════════════

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

    // Rotated grid for Islamic star patterns
    float angle = t * 0.05 + coh * 0.5;
    float2 rp = float2(f.x * cos(angle) - f.y * sin(angle),
                       f.x * sin(angle) + f.y * cos(angle));

    float star = 0.0;
    int points = 8;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 2.0 * M_PI_F / float(points);
        float2 dir = float2(cos(a), sin(a));
        float d = abs(dot(rp, dir));
        star = max(star, d);
    }

    float pattern = smoothstep(0.4, 0.38, star);
    float grid = smoothstep(0.01, 0.0, min(abs(f.x), abs(f.y))) * 0.3;

    float hue = fract(ext_hash(cell) * 0.3 + coh * 0.5 + t * 0.01);
    float3 tileColor = ext_hsv2rgb(float3(hue, 0.5 + coh * 0.3, 0.7));
    float3 lineColor = float3(0.9, 0.85, 0.7);

    float3 color = tileColor * pattern + lineColor * grid;
    float3 bg = float3(0.05, 0.04, 0.06);
    color = mix(bg, color, max(pattern, grid));

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 18. Liquid Light — 1960s psychedelic light show
// ═══════════════════════════════════════════════════════════════════

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

    // Flowing lava-lamp layers
    float v1 = ext_fbm(p * 2.0 + float2(t * 0.15, t * 0.1), 5);
    float v2 = ext_fbm(p * 1.5 + float2(-t * 0.1, t * 0.2), 5);
    float v3 = ext_fbm(p * 3.0 + float2(t * 0.05, -t * 0.15), 4);

    // Create color-separated blobs
    float3 color = float3(0.0);
    float blob1 = smoothstep(0.4, 0.6, v1);
    float blob2 = smoothstep(0.45, 0.65, v2);
    float blob3 = smoothstep(0.35, 0.55, v3);

    color += float3(0.9, 0.2, 0.3) * blob1;
    color += float3(0.2, 0.3, 0.9) * blob2;
    color += float3(0.9, 0.7, 0.1) * blob3;

    // Coherence shifts palette warmth
    float warmth = coh * 0.3;
    color.r += warmth;
    color.b -= warmth * 0.5;

    // Breathing modulation
    float breathe = sin(params.breathPhase * 2.0 * M_PI_F) * 0.1 + 0.9;
    color *= breathe;

    // Saturate and vignette
    float vig = 1.0 - dot(p, p) * 0.3;
    color = clamp(color * vig, 0.0, 1.0);

    output.write(float4(color, 1.0), gid);
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - 19. Coherence Field — Bio-reactive height field
// ═══════════════════════════════════════════════════════════════════

kernel void coherenceFieldKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant ExtendedVisualParams &params  [[buffer(0)]],
    uint2 gid                              [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) return;
    float2 uv = float2(gid) / params.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = params.time;
    float coh = params.coherence;
    float hr = params.heartRate;

    // Height field from coherence
    float field = 0.0;
    for (int i = 0; i < 8; i++) {
        float fi = float(i);
        float2 center = float2(sin(t * 0.2 + fi * 1.2), cos(t * 0.15 + fi * 0.8)) * 0.5;
        float d = length(p - center);
        float wave = sin(d * 10.0 - t * hr / 60.0 * 2.0 + fi) * coh;
        field += wave / (d * 3.0 + 1.0);
    }

    field = field * 0.5 + 0.5;

    // Low coherence: chaotic red, high: ordered blue-green
    float3 lowColor = float3(0.8, 0.2, 0.1);
    float3 highColor = float3(0.1, 0.6, 0.8);
    float3 baseColor = mix(lowColor, highColor, coh);

    float3 color = baseColor * field;

    // Contour lines
    float contour = smoothstep(0.02, 0.0, abs(fract(field * 8.0) - 0.5));
    color += float3(1.0) * contour * 0.2;

    // Center coherence indicator
    float indicator = smoothstep(coh * 0.5 + 0.01, coh * 0.5, length(p));
    color += float3(0.3, 0.8, 0.4) * indicator * 0.3;

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
