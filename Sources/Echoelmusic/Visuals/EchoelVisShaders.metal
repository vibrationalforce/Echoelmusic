//
//  EchoelVisShaders.metal
//  Echoelmusic — Bio-Reactive Visual Shaders
//
//  Metal shaders for 10 visual modes driven by bio-signals.
//  All modes receive BioUniforms with real-time coherence, HRV,
//  heart rate, breath phase, and palette colors.
//
//  Performance target: 120fps on ProMotion, <30% GPU.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Structures (must match Swift VisualUniforms)

struct BioUniforms {
    float time;
    float2 resolution;
    float coherence;
    float hrv;
    float heartRate;
    float breathPhase;
    float pulsePhase;
    float lfHfRatio;
    float4 primaryColor;
    float4 secondaryColor;
    float4 accentColor;
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct Particle {
    float2 position;
    float2 velocity;
    float life;
    float maxLife;
    float size;
    float4 color;
};

// MARK: - Full-Screen Quad Vertex Shader

vertex VertexOut fullscreenVertex(uint vid [[vertex_id]]) {
    // Two-triangle fullscreen quad from vertex ID
    VertexOut out;
    float2 uv = float2((vid << 1) & 2, vid & 2);
    out.position = float4(uv * 2.0 - 1.0, 0.0, 1.0);
    out.uv = float2(uv.x, 1.0 - uv.y);
    return out;
}

// MARK: - Helper Functions

float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i + float2(0,0)), hash(i + float2(1,0)), u.x),
               mix(hash(i + float2(0,1)), hash(i + float2(1,1)), u.x), u.y);
}

float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// MARK: - Waveform Mode

fragment float4 waveformFragment(VertexOut in [[stage_in]],
                                  constant BioUniforms &u [[buffer(0)]],
                                  constant float *waveData [[buffer(1)]],
                                  constant uint &waveCount [[buffer(2)]]) {
    float2 uv = in.uv;
    float4 bg = float4(u.primaryColor.rgb * 0.05, 1.0);

    if (waveCount == 0) {
        // No audio data — show bio-reactive breathing wave
        float wave = sin(uv.x * 6.28 + u.time * 2.0) * 0.2 * u.breathPhase;
        float dist = abs(uv.y - 0.5 - wave);
        float glow = smoothstep(0.02, 0.0, dist);
        return bg + float4(u.primaryColor.rgb * glow, glow);
    }

    uint idx = uint(uv.x * float(waveCount));
    idx = min(idx, waveCount - 1);
    float sample = waveData[idx];

    float yPos = 0.5 + sample * 0.4;
    float dist = abs(uv.y - yPos);

    // Bio-reactive line thickness: HRV increases glow spread
    float thickness = 0.003 + u.hrv * 0.008;
    float glow = smoothstep(thickness * 4.0, 0.0, dist);
    float core = smoothstep(thickness, 0.0, dist);

    // Pulse throb from heart rate
    float pulse = 0.8 + 0.2 * sin(u.pulsePhase * 6.28);

    float4 color = mix(u.secondaryColor, u.primaryColor, core) * pulse;
    return bg + color * glow;
}

// MARK: - Spectrum Mode

fragment float4 spectrumFragment(VertexOut in [[stage_in]],
                                  constant BioUniforms &u [[buffer(0)]],
                                  constant float *specData [[buffer(1)]],
                                  constant uint &specCount [[buffer(2)]]) {
    float2 uv = in.uv;
    float4 bg = float4(u.primaryColor.rgb * 0.03, 1.0);

    if (specCount == 0) {
        // Placeholder spectrum bars from noise
        float barWidth = 1.0 / 32.0;
        float barIndex = floor(uv.x / barWidth);
        float barHeight = noise(float2(barIndex, u.time * 0.5)) * 0.6;
        barHeight *= (0.7 + u.breathPhase * 0.3);
        float bar = step(uv.y, barHeight) * step(fract(uv.x / barWidth), 0.8);
        float4 barColor = mix(u.primaryColor, u.accentColor, uv.y / 0.6);
        return bg + barColor * bar * 0.8;
    }

    float barWidth = 1.0 / float(specCount);
    uint idx = uint(uv.x / barWidth);
    idx = min(idx, specCount - 1);
    float magnitude = specData[idx];

    float barHeight = magnitude * (0.7 + u.breathPhase * 0.3);
    float bar = step(uv.y, barHeight) * step(fract(uv.x / barWidth), 0.8);

    float4 barColor = mix(u.primaryColor, u.accentColor, uv.y / max(barHeight, 0.01));
    float pulse = 0.85 + 0.15 * sin(u.pulsePhase * 6.28);
    return bg + barColor * bar * pulse;
}

// MARK: - Particle Mode

struct ParticleVertexOut {
    float4 position [[position]];
    float4 color;
    float pointSize [[point_size]];
};

vertex ParticleVertexOut particleVertex(uint vid [[vertex_id]],
                                         constant Particle *particles [[buffer(0)]],
                                         constant BioUniforms &u [[buffer(1)]]) {
    ParticleVertexOut out;
    Particle p = particles[vid];
    out.position = float4(p.position, 0.0, 1.0);
    out.color = p.color;
    out.pointSize = p.size * (1.0 + u.coherence * 2.0);
    return out;
}

fragment float4 particleFragment(ParticleVertexOut in [[stage_in]],
                                  float2 pointCoord [[point_coord]]) {
    float dist = length(pointCoord - float2(0.5));
    float alpha = smoothstep(0.5, 0.2, dist) * in.color.w;
    return float4(in.color.rgb, alpha);
}

// MARK: - Hilbert Map Mode

fragment float4 hilbertMapFragment(VertexOut in [[stage_in]],
                                    constant BioUniforms &u [[buffer(0)]],
                                    constant float *gridData [[buffer(1)]],
                                    constant uint &gridSize [[buffer(2)]]) {
    float2 uv = in.uv;
    float4 bg = float4(u.primaryColor.rgb * 0.02, 1.0);

    if (gridSize == 0) return bg;

    uint gx = uint(uv.x * float(gridSize));
    uint gy = uint(uv.y * float(gridSize));
    gx = min(gx, gridSize - 1);
    gy = min(gy, gridSize - 1);

    float value = gridData[gy * gridSize + gx];

    // Bio-reactive color: coherence shifts hue
    float4 low = u.primaryColor;
    float4 high = u.accentColor;
    float4 color = mix(low, high, value);

    // Cell border
    float2 cellUV = fract(uv * float(gridSize));
    float border = step(0.05, cellUV.x) * step(cellUV.x, 0.95) *
                   step(0.05, cellUV.y) * step(cellUV.y, 0.95);

    return bg + color * value * border;
}

// MARK: - Bio Graph Mode

fragment float4 bioGraphFragment(VertexOut in [[stage_in]],
                                  constant BioUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float4 bg = float4(0.02, 0.02, 0.04, 1.0);

    // Grid lines
    float gridX = step(0.99, fract(uv.x * 10.0));
    float gridY = step(0.99, fract(uv.y * 5.0));
    float4 gridColor = float4(0.1, 0.1, 0.15, 1.0);
    bg += gridColor * max(gridX, gridY);

    // Coherence line (top third)
    float cohY = 0.7 + 0.25 * u.coherence;
    float cohDist = abs(uv.y - cohY);
    float cohLine = smoothstep(0.005, 0.0, cohDist);
    bg += u.accentColor * cohLine;

    // Heart rate pulse (middle)
    float hrPhase = fract(uv.x * 3.0 + u.time * u.heartRate / 60.0);
    float hrWave = exp(-20.0 * hrPhase) * sin(hrPhase * 20.0) * 0.15;
    float hrY = 0.4 + hrWave;
    float hrDist = abs(uv.y - hrY);
    float hrLine = smoothstep(0.004, 0.0, hrDist);
    bg += u.primaryColor * hrLine;

    // Breath wave (bottom third)
    float breathWave = sin(uv.x * 6.28 + u.breathPhase * 6.28) * 0.1;
    float breathY = 0.15 + breathWave;
    float breathDist = abs(uv.y - breathY);
    float breathLine = smoothstep(0.004, 0.0, breathDist);
    bg += u.secondaryColor * breathLine;

    return bg;
}

// MARK: - Flow Field Mode

fragment float4 flowFieldFragment(VertexOut in [[stage_in]],
                                   constant BioUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float4 bg = float4(u.primaryColor.rgb * 0.02, 1.0);

    // Bio-reactive flow: breath modulates direction, HRV modulates turbulence
    float2 flowUV = uv * 4.0;
    float angle = fbm(flowUV + float2(u.time * 0.3 * (0.5 + u.hrv), u.breathPhase * 2.0), 4) * 6.28;
    float2 flow = float2(cos(angle), sin(angle));

    // Trace flow lines
    float2 pos = uv;
    float intensity = 0.0;
    for (int i = 0; i < 16; i++) {
        float2 samplePos = pos * 4.0;
        float a = fbm(samplePos + float2(u.time * 0.3 * (0.5 + u.hrv), u.breathPhase * 2.0), 4) * 6.28;
        float2 dir = float2(cos(a), sin(a));
        pos += dir * 0.005;
        intensity += noise(pos * 8.0 + u.time * 0.5) * 0.06;
    }

    // Coherence controls color warmth
    float4 color = mix(u.primaryColor, u.accentColor, intensity);
    float pulse = 0.85 + 0.15 * sin(u.pulsePhase * 6.28);

    return bg + color * intensity * pulse;
}

// MARK: - Kaleidoscope Mode

fragment float4 kaleidoscopeFragment(VertexOut in [[stage_in]],
                                      constant BioUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv * 2.0 - 1.0;
    float4 bg = float4(0.01, 0.01, 0.03, 1.0);

    // Number of symmetry segments: coherence increases complexity
    float segments = 4.0 + u.coherence * 8.0;

    // Polar coordinates
    float r = length(uv);
    float a = atan2(uv.y, uv.x);

    // Mirror across segments
    a = abs(fmod(a, 6.28 / segments) - 3.14 / segments);

    // Back to cartesian
    float2 p = float2(cos(a), sin(a)) * r;

    // Pattern: layered noise
    float pattern = fbm(p * 3.0 + u.time * 0.2, 5);
    pattern += fbm(p * 6.0 - u.time * 0.15, 3) * 0.5;

    // Breath modulates radial fade
    float fade = smoothstep(1.2, 0.1, r * (1.0 - u.breathPhase * 0.3));

    float4 color = mix(u.primaryColor, u.accentColor, pattern);
    float pulse = 0.85 + 0.15 * sin(u.pulsePhase * 6.28);

    return bg + color * pattern * fade * pulse;
}

// MARK: - Nebula Mode

fragment float4 nebulaFragment(VertexOut in [[stage_in]],
                                constant BioUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv;
    float4 bg = float4(0.005, 0.005, 0.015, 1.0);

    // Volumetric layers
    float density = 0.0;
    float2 p = uv * 2.0 - 1.0;

    for (int i = 0; i < 5; i++) {
        float scale = 2.0 + float(i) * 1.5;
        float speed = 0.1 + float(i) * 0.05;
        float layer = fbm(p * scale + u.time * speed + float2(u.breathPhase, u.hrv), 4);
        density += layer * (0.5 / float(i + 1));
    }

    // Coherence brightens the nebula
    density *= (0.5 + u.coherence * 0.5);

    // Color gradient based on density
    float4 color = mix(u.primaryColor, u.secondaryColor, density * 0.5);
    color = mix(color, u.accentColor, density * density);

    float pulse = 0.9 + 0.1 * sin(u.pulsePhase * 6.28);
    return bg + color * density * pulse;
}

// MARK: - Generative Worlds Mode

fragment float4 generativeWorldsFragment(VertexOut in [[stage_in]],
                                          constant BioUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv * 2.0 - 1.0;
    float4 bg = float4(0.01, 0.01, 0.02, 1.0);

    // Terrain-like generative landscape
    float terrain = 0.0;
    float2 p = uv;
    p.y += u.time * 0.05;
    p.x += u.breathPhase * 0.5;

    // Layered Perlin terrain
    terrain = fbm(p * 2.0, 6) * 0.5;
    terrain += fbm(p * 4.0 + u.time * 0.1, 4) * 0.25;

    // Horizon line
    float horizon = 0.0 + terrain * u.coherence;
    float above = step(horizon, uv.y);

    // Sky: bio-reactive gradient
    float skyGradient = smoothstep(0.0, 0.8, uv.y - horizon);
    float4 sky = mix(u.secondaryColor * 0.3, u.primaryColor * 0.1, skyGradient);

    // Ground: terrain coloring
    float4 ground = mix(u.primaryColor, u.accentColor, terrain);

    // Heart rate pulses as "stars" in sky
    float stars = 0.0;
    if (above > 0.5) {
        float2 starUV = uv * 20.0;
        float starNoise = hash(floor(starUV));
        stars = step(0.98, starNoise) * (0.5 + 0.5 * sin(u.time * 5.0 + starNoise * 100.0));
    }

    float4 color = mix(ground, sky, above) + float4(stars);
    return bg + color;
}

// MARK: - AR Worlds Mode (Placeholder — renders abstract environment)

fragment float4 arWorldsFragment(VertexOut in [[stage_in]],
                                  constant BioUniforms &u [[buffer(0)]]) {
    float2 uv = in.uv * 2.0 - 1.0;
    float4 bg = float4(0.02, 0.02, 0.04, 1.0);

    // Abstract spatial environment as placeholder for AR
    float r = length(uv);
    float a = atan2(uv.y, uv.x);

    // Concentric rings pulsing with heart rate
    float rings = sin(r * 15.0 - u.time * 2.0) * 0.5 + 0.5;
    rings *= smoothstep(1.2, 0.3, r);

    // Rotating sectors from breath
    float sectors = sin(a * 6.0 + u.breathPhase * 6.28) * 0.5 + 0.5;

    float pattern = rings * sectors * (0.5 + u.coherence * 0.5);

    float4 color = mix(u.primaryColor, u.accentColor, pattern);
    float pulse = 0.9 + 0.1 * sin(u.pulsePhase * 6.28);

    return bg + color * pattern * pulse * 0.6;
}
