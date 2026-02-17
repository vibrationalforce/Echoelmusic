//  HilbertVisualization.metal
//  Echoelmusic - Hilbert Curve Bio-Visualization Shader
//
//  Renders the HilbertSensorMapper density grid as a GPU-accelerated heatmap
//  with animated particle trails along the Hilbert curve path.
//
//  Two render modes:
//  1. Density Heatmap — 2D grid colored by bio-signal accumulation
//  2. Particle Trail — Points flowing along the Hilbert curve, colored by value
//
//  Input: Density grid texture (R channel = density 0-1) + uniform params
//  Output: Fragment color with glow, coherence-driven palette, and time animation
//
//  Created 2026-02-17
//  Copyright (c) 2026 Echoelmusic. All rights reserved.

#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms

struct HilbertUniforms {
    float time;           // Elapsed seconds
    float coherence;      // Bio coherence (0-1)
    float intensity;      // Visual intensity (0-1)
    float gridSize;       // Hilbert grid dimension (e.g., 32)
    float particleCount;  // Number of active particles
    float hue;            // Base hue (0-1)
};

// MARK: - Vertex Types

struct HilbertVertex {
    float4 position [[position]];
    float2 uv;
};

// MARK: - Color Utilities

/// HSV to RGB conversion
float3 hilbert_hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

/// Coherence-driven palette: warm (low) → cool (high)
float3 coherencePalette(float density, float coherence, float hue, float time) {
    // Low coherence: warm orange/red, High coherence: cool blue/green
    float baseHue = mix(0.05, hue, coherence);  // Orange → user hue
    float saturation = 0.7 + density * 0.3;
    float value = density;

    // Subtle time-based shimmer
    float shimmer = sin(time * 2.0 + density * 6.28) * 0.05;

    return hilbert_hsv2rgb(float3(baseHue + shimmer, saturation, value));
}

// MARK: - Density Heatmap Fragment Shader

/// Renders the Hilbert density grid as a glowing heatmap
/// Input texture: R channel = density (0-1)
fragment float4 hilbertDensityFragment(
    HilbertVertex in [[stage_in]],
    texture2d<float> densityTexture [[texture(0)]],
    constant HilbertUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler texSampler(mag_filter::linear, min_filter::linear, address::clamp_to_edge);
    float2 uv = in.uv;

    // Sample density with slight blur for smoother visualization
    float density = densityTexture.sample(texSampler, uv).r;

    // Sample neighbors for glow effect
    float texelSize = 1.0 / uniforms.gridSize;
    float densityL = densityTexture.sample(texSampler, uv + float2(-texelSize, 0)).r;
    float densityR = densityTexture.sample(texSampler, uv + float2( texelSize, 0)).r;
    float densityU = densityTexture.sample(texSampler, uv + float2(0, -texelSize)).r;
    float densityD = densityTexture.sample(texSampler, uv + float2(0,  texelSize)).r;

    // Glow: average of neighbors adds soft bloom
    float glow = (densityL + densityR + densityU + densityD) * 0.15;
    float totalDensity = clamp(density + glow, 0.0, 1.0);

    // Apply intensity
    totalDensity *= uniforms.intensity;

    // Color from coherence palette
    float3 color = coherencePalette(totalDensity, uniforms.coherence, uniforms.hue, uniforms.time);

    // Add subtle grid lines (Hilbert cell boundaries)
    float2 gridUV = fract(uv * uniforms.gridSize);
    float gridLine = smoothstep(0.0, 0.05, gridUV.x) * smoothstep(0.0, 0.05, gridUV.y);
    gridLine *= smoothstep(0.0, 0.05, 1.0 - gridUV.x) * smoothstep(0.0, 0.05, 1.0 - gridUV.y);
    color *= mix(0.85, 1.0, gridLine);

    // Alpha: density drives visibility (black background)
    float alpha = totalDensity > 0.01 ? totalDensity * 0.9 + 0.1 : 0.0;

    return float4(color, alpha);
}

// MARK: - Particle Trail Vertex Shader

struct HilbertParticle {
    float2 position;    // 0-1 normalized (from HilbertSensorMapper)
    float value;        // Sensor value at this point
    float age;          // 0-1 (0 = just born, 1 = about to die)
};

struct ParticleVertex {
    float4 position [[position]];
    float pointSize [[point_size]];
    float value;
    float age;
};

/// Vertex shader for Hilbert curve particles
vertex ParticleVertex hilbertParticleVertex(
    uint vertexID [[vertex_id]],
    constant HilbertParticle *particles [[buffer(0)]],
    constant HilbertUniforms &uniforms [[buffer(1)]]
) {
    HilbertParticle p = particles[vertexID];

    ParticleVertex out;
    // Map 0-1 to clip space (-1 to 1)
    out.position = float4(p.position.x * 2.0 - 1.0, p.position.y * 2.0 - 1.0, 0.0, 1.0);
    // Particle size: larger for newer, scales with intensity
    out.pointSize = mix(2.0, 8.0, 1.0 - p.age) * uniforms.intensity;
    out.value = p.value;
    out.age = p.age;

    return out;
}

/// Fragment shader for Hilbert curve particles (point sprites)
fragment float4 hilbertParticleFragment(
    ParticleVertex in [[stage_in]],
    float2 pointCoord [[point_coord]],
    constant HilbertUniforms &uniforms [[buffer(0)]]
) {
    // Soft circle
    float dist = length(pointCoord - float2(0.5));
    float circle = 1.0 - smoothstep(0.3, 0.5, dist);

    if (circle < 0.01) discard_fragment();

    // Color from value + coherence
    float3 color = coherencePalette(abs(in.value), uniforms.coherence, uniforms.hue, uniforms.time);

    // Fade with age
    float alpha = circle * (1.0 - in.age * 0.8);

    return float4(color * alpha, alpha);
}

// MARK: - Full-Screen Quad Vertex Shader

/// Simple full-screen quad for density heatmap rendering
vertex HilbertVertex hilbertQuadVertex(uint vertexID [[vertex_id]]) {
    // Triangle strip: 4 vertices for full-screen quad
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };
    float2 uvs[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };

    HilbertVertex out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = uvs[vertexID];
    return out;
}
