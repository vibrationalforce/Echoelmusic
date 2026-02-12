// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC EFFECTS - Custom Metal Shaders
// ═══════════════════════════════════════════════════════════════════════════════
//
// Missing 55% shaders: Gaussian Blur, Bloom, Volumetric Fog
// Optimized for all Apple GPU families (A9+, M1+, Apple GPU 3+)
//
// ═══════════════════════════════════════════════════════════════════════════════

#include <metal_stdlib>
using namespace metal;

// MARK: - Shared Types

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct EffectUniforms {
    float time;
    float intensity;
    float coherence;       // Bio-reactive: 0-1
    float breathPhase;     // Bio-reactive: 0-1
    float2 resolution;
    float blurRadius;
    float bloomThreshold;
    float bloomIntensity;
    float fogDensity;
    float fogNear;
    float fogFar;
    float3 fogColor;
};

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - GAUSSIAN BLUR (Separable, 2-pass)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Two-pass separable Gaussian blur for efficient O(2N) instead of O(N²).
// Supports variable radius (1-64 pixels) with bio-reactive modulation.

// 9-tap weights for sigma ≈ radius/3
constant float gaussWeights[9] = {
    0.0270, 0.0663, 0.1216, 0.1665, 0.1712,
    0.1665, 0.1216, 0.0663, 0.0270
};

// Horizontal blur pass
[[kernel]]
void gaussianBlurHorizontal(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant EffectUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;

    float radius = uniforms.blurRadius * (1.0 + uniforms.coherence * 0.5);
    float step = max(1.0, radius / 4.0);

    float4 color = float4(0.0);
    float totalWeight = 0.0;

    for (int i = -4; i <= 4; i++) {
        int2 coord = int2(gid) + int2(int(float(i) * step), 0);
        coord.x = clamp(coord.x, 0, int(inTexture.get_width()) - 1);

        float w = gaussWeights[i + 4];
        color += inTexture.read(uint2(coord)) * w;
        totalWeight += w;
    }

    outTexture.write(color / totalWeight, gid);
}

// Vertical blur pass
[[kernel]]
void gaussianBlurVertical(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant EffectUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;

    float radius = uniforms.blurRadius * (1.0 + uniforms.coherence * 0.5);
    float step = max(1.0, radius / 4.0);

    float4 color = float4(0.0);
    float totalWeight = 0.0;

    for (int i = -4; i <= 4; i++) {
        int2 coord = int2(gid) + int2(0, int(float(i) * step));
        coord.y = clamp(coord.y, 0, int(inTexture.get_height()) - 1);

        float w = gaussWeights[i + 4];
        color += inTexture.read(uint2(coord)) * w;
        totalWeight += w;
    }

    outTexture.write(color / totalWeight, gid);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - BLOOM (Extract + Blur + Composite)
// ═══════════════════════════════════════════════════════════════════════════════
//
// HDR bloom pipeline:
// 1. Extract bright pixels above threshold
// 2. Blur the bright pixels (reuse Gaussian blur above)
// 3. Composite bloom back onto original
//
// Bio-reactive: coherence increases bloom warmth, breathPhase pulses intensity

// Step 1: Extract bright regions
[[kernel]]
void bloomExtract(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant EffectUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;

    float4 color = inTexture.read(gid);

    // Luminance (Rec. 709)
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));

    // Bio-reactive threshold: higher coherence = more bloom
    float threshold = uniforms.bloomThreshold * (1.0 - uniforms.coherence * 0.3);

    if (luminance > threshold) {
        // Soft knee extraction
        float knee = 0.1;
        float soft = luminance - threshold + knee;
        soft = clamp(soft * soft / (4.0 * knee + 0.00001), 0.0, 1.0);
        float contribution = max(soft, luminance - threshold) / max(luminance, 0.00001);

        outTexture.write(float4(color.rgb * contribution, 1.0), gid);
    } else {
        outTexture.write(float4(0.0, 0.0, 0.0, 1.0), gid);
    }
}

// Step 3: Composite bloom onto original
[[kernel]]
void echoelBloomComposite(
    texture2d<float, access::read> originalTexture [[texture(0)]],
    texture2d<float, access::read> bloomTexture [[texture(1)]],
    texture2d<float, access::write> outTexture [[texture(2)]],
    constant EffectUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;

    float4 original = originalTexture.read(gid);
    float4 bloom = bloomTexture.read(gid);

    // Bio-reactive: breath phase pulses bloom intensity
    float breathPulse = 1.0 + sin(uniforms.breathPhase * M_PI_F * 2.0) * 0.15;
    float intensity = uniforms.bloomIntensity * breathPulse;

    // Warm tint based on coherence (golden glow at high coherence)
    float3 warmth = mix(float3(1.0), float3(1.0, 0.9, 0.7), uniforms.coherence * 0.3);

    float4 result = original + float4(bloom.rgb * warmth * intensity, 0.0);

    // Tone mapping (Reinhard)
    result.rgb = result.rgb / (result.rgb + 1.0);
    result.a = 1.0;

    outTexture.write(result, gid);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - VOLUMETRIC FOG (Ray marching)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Screen-space volumetric fog using ray marching with:
// - Depth-based density (exponential falloff)
// - Animated noise for organic movement
// - Light scattering (Henyey-Greenstein phase function)
// - Bio-reactive: coherence controls clarity, breathPhase animates fog movement
//
// 16 ray march steps for real-time performance (60+ FPS on A12+)

// Simplex noise for fog turbulence
float echoelHash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.13);
    p3 += dot(p3, p3.yzx + 3.333);
    return fract((p3.x + p3.y) * p3.z);
}

float noise2D(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // smoothstep

    float a = echoelHash(i);
    float b = echoelHash(i + float2(1.0, 0.0));
    float c = echoelHash(i + float2(0.0, 1.0));
    float d = echoelHash(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbmFog(float2 p, float time) {
    float value = 0.0;
    float amplitude = 0.5;
    float2 shift = float2(time * 0.3, time * 0.15);

    for (int i = 0; i < 4; i++) {
        value += amplitude * noise2D(p + shift);
        p *= 2.0;
        amplitude *= 0.5;
        shift *= 1.3;
    }
    return value;
}

// Henyey-Greenstein phase function for light scattering
float henyeyGreenstein(float cosTheta, float g) {
    float g2 = g * g;
    return (1.0 - g2) / (4.0 * M_PI_F * pow(1.0 + g2 - 2.0 * g * cosTheta, 1.5));
}

[[kernel]]
void volumetricFog(
    texture2d<float, access::read> colorTexture [[texture(0)]],
    texture2d<float, access::read> depthTexture [[texture(1)]],
    texture2d<float, access::write> outTexture [[texture(2)]],
    constant EffectUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;

    float2 uv = float2(gid) / uniforms.resolution;
    float4 sceneColor = colorTexture.read(gid);
    float depth = depthTexture.read(gid).r;

    // Bio-reactive fog density: higher coherence = clearer view
    float density = uniforms.fogDensity * (1.0 - uniforms.coherence * 0.6);

    // Animated fog offset from breath phase
    float breathOffset = sin(uniforms.breathPhase * M_PI_F * 2.0) * 0.1;

    // Ray marching (16 steps)
    float fogAccum = 0.0;
    float3 scatterAccum = float3(0.0);
    int steps = 16;
    float stepSize = (uniforms.fogFar - uniforms.fogNear) / float(steps);

    // Light direction (top-right, slightly forward)
    float3 lightDir = normalize(float3(0.5, 1.0, -0.3));

    for (int i = 0; i < steps; i++) {
        float t = uniforms.fogNear + float(i) * stepSize;

        // Only accumulate fog up to scene depth
        if (t > depth * uniforms.fogFar) break;

        // Sample position with animation
        float2 samplePos = uv * 4.0 + float2(t * 0.5, breathOffset);
        float noiseSample = fbmFog(samplePos, uniforms.time);

        // Exponential density falloff
        float heightFalloff = exp(-t * 0.5);
        float localDensity = density * noiseSample * heightFalloff * stepSize;

        // Light scattering
        float cosAngle = dot(normalize(float3(uv - 0.5, 1.0)), lightDir);
        float scatter = henyeyGreenstein(cosAngle, 0.3);

        scatterAccum += uniforms.fogColor * scatter * localDensity;
        fogAccum += localDensity;
    }

    // Apply fog with scattering
    fogAccum = clamp(fogAccum, 0.0, 1.0);
    float3 fogContribution = uniforms.fogColor * fogAccum + scatterAccum * 0.5;

    float4 result = float4(mix(sceneColor.rgb, fogContribution, fogAccum), 1.0);
    outTexture.write(result, gid);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - COMFORT VIGNETTE (Motion Sickness Prevention)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Dynamic vignette that reduces peripheral vision during fast movement.
// Used by MotionComfortSystem to prevent VR/immersive motion sickness.

struct ComfortUniforms {
    float vignetteIntensity;  // 0 = off, 1 = full tunnel vision
    float vignetteRadius;     // Inner radius (default 0.4)
    float vignetteSoftness;   // Softness of edge (default 0.3)
    float2 resolution;
};

[[kernel]]
void comfortVignette(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant ComfortUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;

    float2 uv = float2(gid) / uniforms.resolution;
    float4 color = inTexture.read(gid);

    // Distance from center
    float2 center = uv - 0.5;
    float dist = length(center);

    // Vignette mask
    float inner = uniforms.vignetteRadius;
    float outer = inner + uniforms.vignetteSoftness;
    float vignette = 1.0 - smoothstep(inner, outer, dist);

    // Apply comfort darkening
    float mask = mix(1.0, vignette, uniforms.vignetteIntensity);
    color.rgb *= mask;

    // Optional: add subtle rest frame ring at the vignette edge
    float ringDist = abs(dist - inner);
    float ring = smoothstep(0.02, 0.0, ringDist) * uniforms.vignetteIntensity * 0.15;
    color.rgb += float3(ring);

    outTexture.write(color, gid);
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - BIO-REACTIVE GLOW (Enhanced)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Soft glow that responds to coherence level.
// High coherence = warm golden glow, low = cool blue shimmer.

[[kernel]]
void bioReactiveGlow(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant EffectUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) return;

    float4 color = inTexture.read(gid);
    float2 uv = float2(gid) / uniforms.resolution;

    // Coherence-based color
    float3 lowColor = float3(0.2, 0.4, 0.9);   // Cool blue
    float3 highColor = float3(0.9, 0.8, 0.3);   // Warm gold
    float3 glowColor = mix(lowColor, highColor, uniforms.coherence);

    // Radial glow from center
    float dist = length(uv - 0.5);
    float glow = exp(-dist * 3.0) * uniforms.intensity;

    // Pulse with breath
    float pulse = 1.0 + sin(uniforms.breathPhase * M_PI_F * 2.0) * 0.2;

    color.rgb += glowColor * glow * pulse;
    outTexture.write(color, gid);
}
