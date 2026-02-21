/*
 *  EchoelCompute.hlsl
 *  Echoelmusic — HLSL Compute Shader (DirectX 11+ / FFX / Vulkan SPIR-V)
 *
 *  Created: February 2026
 *  GPU-accelerated bio-reactive audio visualization & video processing.
 *
 *  Compatible with:
 *  - DirectX 11/12 Compute (Windows)
 *  - AMD FidelityFX (FSR, CAS, SPD integration points)
 *  - Vulkan via SPIR-V cross-compilation (spirv-cross)
 *  - Xbox Series X|S (GDK)
 *  - PlayStation 5 (PSSL converted via shader compiler)
 *
 *  Thread Group: 8x8x1 (64 threads per group — optimal for GPU occupancy)
 */

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Constant Buffer (updated per-frame from CPU)                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

cbuffer EchoelParams : register(b0) {
    /* Audio analysis */
    float audioRMS;
    float audioPeak;
    float audioBass;
    float audioMid;

    float audioHigh;
    float audioOnset;       /* 0 or 1: beat detected this frame */
    float bpm;
    float beatPhase;        /* 0-1 within current beat */

    /* Bio-reactive */
    float bioCoherence;
    float bioHeartRate;
    float bioBreathPhase;
    float bioHRV;

    /* Transform */
    float time;
    float frameRate;
    uint  imageWidth;
    uint  imageHeight;

    /* Effect parameters */
    float warmth;
    float glowAmount;
    float cymaticsScale;
    float auraRadius;

    float saturationMod;
    float vignetteAmount;
    float chromaShiftAmount;
    float mixAmount;

    /* Audio spectrum (first 16 bins for GPU efficiency) */
    float4 spectrumBins[4]; /* 16 float values packed into 4 float4s */
};

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Resources                                                                  */
/* ═══════════════════════════════════════════════════════════════════════════ */

Texture2D<float4>   InputTexture  : register(t0);
RWTexture2D<float4> OutputTexture : register(u0);

SamplerState LinearSampler : register(s0);

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Utility Functions                                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

float luminance(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

float softClamp(float x) {
    return x / (x + 1.0);  /* Reinhard tonemap */
}

float chladniPattern(float2 p, float m, float n) {
    float pi = 3.14159265;
    return cos(m * pi * p.x) * cos(n * pi * p.y)
         - cos(n * pi * p.x) * cos(m * pi * p.y);
}

/* Simple hash for noise */
float hash(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return frac(sin(h) * 43758.5453123);
}

float noise2D(float2 p) {
    float2 i = floor(p);
    float2 f = frac(p);
    f = f * f * (3.0 - 2.0 * f);  /* smoothstep */
    float a = hash(i);
    float b = hash(i + float2(1, 0));
    float c = hash(i + float2(0, 1));
    float d = hash(i + float2(1, 1));
    return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Bio-Reactive Color Grading                                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

float3 applyBioGrading(float3 color, float2 uv) {
    /* Color temperature shift based on coherence */
    float warmthOffset = (bioCoherence - 0.5) * 2.0 * warmth;
    color.r *= 1.0 + warmthOffset * 0.15;
    color.g *= 1.0 + warmthOffset * 0.05;
    color.b *= 1.0 - warmthOffset * 0.12;

    /* Audio-reactive glow */
    float energy = audioRMS * glowAmount;
    float pulse = audioPeak * glowAmount * 0.5;
    color += float3(energy * 0.04 + pulse * 0.08,
                    energy * 0.025 + pulse * 0.05,
                    energy * 0.06 + pulse * 0.1);

    /* Bio-reactive saturation */
    float lum = luminance(color);
    float sat = 1.0 + (bioCoherence - 0.5) * 0.4 + saturationMod;
    sat = max(sat, 0.0);
    color = float3(lum, lum, lum) + (color - float3(lum, lum, lum)) * sat;

    /* Heart pulse brightness */
    float heartPulse = sin(bioBreathPhase * 6.283185) * 0.02;
    color *= 1.0 + heartPulse * bioCoherence;

    return color;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Cymatics Overlay                                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

float3 applyCymatics(float2 uv) {
    float2 p = (uv - 0.5) * cymaticsScale * 6.0;

    float m = 2.0 + audioMid * 6.0;
    float n = 2.0 + audioHigh * 4.0;

    float pattern = abs(chladniPattern(p, m, n));
    pattern = pow(pattern, 1.0 + bioCoherence);
    pattern *= audioBass * 2.0;

    float hue = 0.55 + bioCoherence * 0.15;
    return hsv2rgb(float3(hue, 0.7, pattern));
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Aura Effect                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

float3 applyAura(float2 uv) {
    float2 center = float2(0.5, 0.5);
    float dist = length(uv - center);

    float breathMod = sin(bioBreathPhase * 6.283185) * 0.05;
    float radius = auraRadius + bioCoherence * 0.15 + breathMod;

    float noiseVal = noise2D(uv * 8.0 + time * 0.5) * 0.1;
    float auraEdge = smoothstep(radius + 0.1, radius - 0.05, dist + noiseVal);
    float innerGlow = exp(-dist * dist * 12.0) * 0.3;

    float3 auraColor;
    if (bioCoherence > 0.7)
        auraColor = float3(0.9, 0.8, 0.2);     /* golden */
    else if (bioCoherence > 0.4)
        auraColor = float3(0.3, 0.4, 0.9);     /* blue */
    else
        auraColor = float3(0.9, 0.3, 0.2);     /* red */

    return auraColor * (auraEdge * 0.6 + innerGlow);
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Dynamic Vignette                                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

float applyVignette(float2 uv) {
    float2 center = uv - 0.5;
    float dist = length(center) * 2.0;
    float vigStr = vignetteAmount * (1.0 + (0.5 - bioCoherence) * 0.5);
    return 1.0 - smoothstep(0.5, 1.2, dist) * vigStr;
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Chromatic Aberration                                                       */
/* ═══════════════════════════════════════════════════════════════════════════ */

float3 applyChromaShift(float2 uv) {
    float amount = chromaShiftAmount * audioPeak * 0.01;
    float2 dir = normalize(uv - 0.5) * amount;

    float r = InputTexture.SampleLevel(LinearSampler, uv + dir, 0).r;
    float g = InputTexture.SampleLevel(LinearSampler, uv, 0).g;
    float b = InputTexture.SampleLevel(LinearSampler, uv - dir, 0).b;

    return float3(r, g, b);
}

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Main Compute Kernel                                                        */
/* ═══════════════════════════════════════════════════════════════════════════ */

[numthreads(8, 8, 1)]
void CSMain(uint3 dispatchThreadID : SV_DispatchThreadID) {
    uint2 pixel = dispatchThreadID.xy;

    /* Bounds check */
    if (pixel.x >= imageWidth || pixel.y >= imageHeight) return;

    float2 uv = float2(pixel) / float2(imageWidth, imageHeight);

    /* Read source pixel */
    float4 srcColor;
    if (chromaShiftAmount > 0.001) {
        srcColor = float4(applyChromaShift(uv), 1.0);
    } else {
        srcColor = InputTexture[pixel];
    }

    float3 color = srcColor.rgb;

    /* Apply bio-reactive color grading */
    color = applyBioGrading(color, uv);

    /* Overlay effects */
    float3 effects = float3(0, 0, 0);
    effects += applyCymatics(uv) * 0.3;
    effects += applyAura(uv) * 0.4;
    effects += float3(1, 1, 1) * pow(audioPeak, 3.0) * glowAmount * 0.2; /* beat flash */

    color += effects;

    /* Vignette */
    color *= applyVignette(uv);

    /* Tonemap */
    color = color / (color + float3(1, 1, 1));

    /* Mix with original */
    color = lerp(srcColor.rgb, color, mixAmount);

    OutputTexture[pixel] = float4(color, srcColor.a);
}
