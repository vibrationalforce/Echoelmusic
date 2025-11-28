//
//  MetalShaders.metal
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  METAL SHADERS - GPU-accelerated video effects
//  Professional video processing shaders
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Vertex Shader

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(VertexIn in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

// MARK: - Chroma Key

struct ChromaKeyParams {
    float3 keyColor;
    float threshold;
    float smoothness;
};

fragment float4 chromaKeyShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    constant ChromaKeyParams& params [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // Calculate distance from key color
    float3 diff = color.rgb - params.keyColor;
    float distance = length(diff);

    // Alpha based on distance
    float alpha = smoothstep(params.threshold - params.smoothness,
                            params.threshold + params.smoothness,
                            distance);

    return float4(color.rgb, color.a * alpha);
}

// MARK: - Blur

fragment float4 gaussianBlurShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    constant float& blurRadius [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float4 color = float4(0.0);
    float totalWeight = 0.0;

    // 9-tap Gaussian blur
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 offset = float2(x, y) * blurRadius / 1000.0;
            float weight = exp(-(x*x + y*y) / 2.0);

            color += colorTexture.sample(textureSampler, in.texCoord + offset) * weight;
            totalWeight += weight;
        }
    }

    return color / totalWeight;
}

// MARK: - Color Grading

struct ColorGradeParams {
    float exposure;
    float contrast;
    float saturation;
    float temperature;
    float tint;
};

fragment float4 colorGradeShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    constant ColorGradeParams& params [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // Exposure
    color.rgb *= pow(2.0, params.exposure);

    // Contrast
    color.rgb = ((color.rgb - 0.5) * params.contrast) + 0.5;

    // Saturation
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    color.rgb = mix(float3(luminance), color.rgb, params.saturation);

    // Temperature & Tint
    color.r *= 1.0 + params.temperature * 0.2;
    color.b *= 1.0 - params.temperature * 0.2;
    color.g *= 1.0 + params.tint * 0.2;

    return color;
}

// MARK: - Particle System

struct Particle {
    float2 position;
    float2 velocity;
    float4 color;
    float size;
    float life;
};

kernel void particleUpdateKernel(
    device Particle* particles [[buffer(0)]],
    constant float& deltaTime [[buffer(1)]],
    constant float2& gravity [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    Particle p = particles[id];

    if (p.life > 0.0) {
        // Update position
        p.position += p.velocity * deltaTime;
        p.velocity += gravity * deltaTime;

        // Update life
        p.life -= deltaTime;

        // Fade alpha
        p.color.a = p.life;

        particles[id] = p;
    }
}

// MARK: - Perlin Noise

float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

fragment float4 perlinNoiseShader(
    VertexOut in [[stage_in]],
    constant float& time [[buffer(0)]],
    constant float& scale [[buffer(1)]]
) {
    float2 uv = in.texCoord * scale;
    float n = noise(uv + time);

    return float4(n, n, n, 1.0);
}

// MARK: - Angular Gradient

fragment float4 angularGradientShader(
    VertexOut in [[stage_in]],
    constant float4& color1 [[buffer(0)]],
    constant float4& color2 [[buffer(1)]],
    constant float2& center [[buffer(2)]]
) {
    float2 dir = in.texCoord - center;
    float angle = atan2(dir.y, dir.x) / (2.0 * M_PI_F) + 0.5;

    return mix(color1, color2, angle);
}

// MARK: - Star Field

kernel void starFieldKernel(
    device Particle* stars [[buffer(0)]],
    constant float& time [[buffer(1)]],
    constant float& speed [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    Particle star = stars[id];

    // Move star
    star.position.y += speed * 0.016;  // 60fps

    // Wrap around
    if (star.position.y > 1.0) {
        star.position.y = 0.0;
        star.position.x = hash(float2(id, time));
    }

    // Twinkle
    star.color.a = 0.5 + 0.5 * sin(time * 3.0 + float(id) * 0.1);

    stars[id] = star;
}

// MARK: - Sobel Edge Detection

fragment float4 sobelEdgeShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    constant float& strength [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float2 texelSize = 1.0 / float2(colorTexture.get_width(), colorTexture.get_height());

    // Sobel kernels
    float3 gx = float3(0.0);
    float3 gy = float3(0.0);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 offset = float2(x, y) * texelSize;
            float3 sample = colorTexture.sample(textureSampler, in.texCoord + offset).rgb;

            // Horizontal gradient
            gx += sample * float(x);

            // Vertical gradient
            gy += sample * float(y);
        }
    }

    float edge = length(float2(length(gx), length(gy)));
    edge *= strength;

    return float4(edge, edge, edge, 1.0);
}

// MARK: - Bloom

fragment float4 bloomShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    constant float& threshold [[buffer(0)]],
    constant float& intensity [[buffer(1)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // Extract bright areas
    float brightness = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float3 bloom = max(color.rgb - threshold, 0.0) * intensity;

    return float4(color.rgb + bloom, color.a);
}

// MARK: - Vignette

fragment float4 vignetteShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    constant float& strength [[buffer(0)]],
    constant float& radius [[buffer(1)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // Calculate distance from center
    float2 center = float2(0.5, 0.5);
    float dist = distance(in.texCoord, center);

    // Apply vignette
    float vignette = smoothstep(radius, radius - strength, dist);

    return float4(color.rgb * vignette, color.a);
}

// MARK: - Film Grain

fragment float4 filmGrainShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    constant float& time [[buffer(0)]],
    constant float& strength [[buffer(1)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // Generate grain
    float grain = hash(in.texCoord * 1000.0 + time);
    grain = (grain - 0.5) * strength;

    return float4(color.rgb + grain, color.a);
}
