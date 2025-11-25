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

// MARK: - Advanced Color Temperature

struct ColorTemperatureParams {
    float temperature;  // Kelvin (2000-10000)
    float tint;        // Green-Magenta shift
    float exposure;
    float contrast;
    float saturation;
    float highlights;
    float shadows;
    float whites;
    float blacks;
    // Lift/Gamma/Gain (Color Wheels)
    float3 lift;
    float3 gamma;
    float3 gain;
};

// Convert Kelvin temperature to RGB multiplier
float3 kelvinToRGB(float kelvin) {
    float temp = kelvin / 100.0;
    float3 color;

    // Red
    if (temp <= 66.0) {
        color.r = 1.0;
    } else {
        color.r = temp - 60.0;
        color.r = 1.2929 * pow(color.r, -0.1332);
        color.r = clamp(color.r, 0.0, 1.0);
    }

    // Green
    if (temp <= 66.0) {
        color.g = 0.390082 * log(temp) - 0.631841;
    } else {
        color.g = temp - 60.0;
        color.g = 1.1298 * pow(color.g, -0.0755);
    }
    color.g = clamp(color.g, 0.0, 1.0);

    // Blue
    if (temp >= 66.0) {
        color.b = 1.0;
    } else if (temp <= 19.0) {
        color.b = 0.0;
    } else {
        color.b = temp - 10.0;
        color.b = 0.543206 * log(color.b) - 1.196254;
        color.b = clamp(color.b, 0.0, 1.0);
    }

    return color;
}

fragment float4 advancedColorTemperatureShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    constant ColorTemperatureParams& params [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // 1. Apply color temperature
    float3 tempRGB = kelvinToRGB(params.temperature);
    color.rgb *= tempRGB;

    // 2. Apply tint (green-magenta)
    color.g += params.tint * 0.01;
    color.rb -= params.tint * 0.005;

    // 3. Exposure
    color.rgb *= pow(2.0, params.exposure);

    // 4. Lift/Gamma/Gain (CDL - Color Decision List)
    // Lift (Shadows)
    color.rgb = color.rgb + params.lift;

    // Gamma (Midtones)
    color.rgb = pow(max(color.rgb, 0.0), 1.0 / (params.gamma + 1.0));

    // Gain (Highlights)
    color.rgb *= (params.gain + 1.0);

    // 5. Highlights/Shadows (Parametric adjustment)
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));

    // Highlight adjustment (affects bright areas)
    float highlightMask = smoothstep(0.5, 1.0, luminance);
    color.rgb += params.highlights * 0.01 * highlightMask;

    // Shadow adjustment (affects dark areas)
    float shadowMask = smoothstep(0.5, 0.0, luminance);
    color.rgb += params.shadows * 0.01 * shadowMask;

    // Whites (pure white adjustment)
    float whiteMask = smoothstep(0.8, 1.0, luminance);
    color.rgb += params.whites * 0.01 * whiteMask;

    // Blacks (pure black adjustment)
    float blackMask = smoothstep(0.2, 0.0, luminance);
    color.rgb += params.blacks * 0.01 * blackMask;

    // 6. Contrast
    color.rgb = ((color.rgb - 0.5) * params.contrast) + 0.5;

    // 7. Saturation
    float finalLuminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    color.rgb = mix(float3(finalLuminance), color.rgb, params.saturation);

    return clamp(color, 0.0, 1.0);
}

// MARK: - LUT (Look-Up Table)

fragment float4 lutShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    texture3d<float> lutTexture [[texture(1)]],
    constant float& intensity [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    constexpr sampler lutSampler(mag_filter::linear, min_filter::linear);

    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // Sample 3D LUT
    float3 lutCoord = clamp(color.rgb, 0.0, 1.0);
    float3 gradedColor = lutTexture.sample(lutSampler, lutCoord).rgb;

    // Blend with original based on intensity
    color.rgb = mix(color.rgb, gradedColor, intensity);

    return color;
}

// MARK: - Tone Curves

struct ToneCurveParams {
    float4 shadows;    // x=input, y=output for shadows
    float4 midtones;   // x=input, y=output for midtones
    float4 highlights; // x=input, y=output for highlights
};

float evaluateCurve(float x, float4 shadows, float4 midtones, float4 highlights) {
    if (x < 0.33) {
        // Shadows curve
        float t = x / 0.33;
        return mix(shadows.y, midtones.y, smoothstep(0.0, 1.0, t));
    } else if (x < 0.67) {
        // Midtones curve
        float t = (x - 0.33) / 0.34;
        return mix(midtones.y, highlights.y, smoothstep(0.0, 1.0, t));
    } else {
        // Highlights curve
        float t = (x - 0.67) / 0.33;
        return mix(highlights.y, 1.0, smoothstep(0.0, 1.0, t));
    }
}

fragment float4 toneCurveShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    constant ToneCurveParams& params [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // Apply curve to each channel
    color.r = evaluateCurve(color.r, params.shadows, params.midtones, params.highlights);
    color.g = evaluateCurve(color.g, params.shadows, params.midtones, params.highlights);
    color.b = evaluateCurve(color.b, params.shadows, params.midtones, params.highlights);

    return clamp(color, 0.0, 1.0);
}

// MARK: - Color Wheels (Hue/Saturation)

struct ColorWheelParams {
    float liftHue;
    float liftSaturation;
    float gammaHue;
    float gammaSaturation;
    float gainHue;
    float gainSaturation;
};

float3 rgbToHsv(float3 rgb) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = mix(float4(rgb.bg, K.wz), float4(rgb.gb, K.xy), step(rgb.b, rgb.g));
    float4 q = mix(float4(p.xyw, rgb.r), float4(rgb.r, p.yzx), step(p.x, rgb.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsvToRgb(float3 hsv) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(hsv.xxx + K.xyz) * 6.0 - K.www);
    return hsv.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), hsv.y);
}

fragment float4 colorWheelShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]],
    constant ColorWheelParams& params [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    float3 hsv = rgbToHsv(color.rgb);
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));

    // Lift (Shadows) - affects dark areas
    if (luminance < 0.33) {
        float mask = smoothstep(0.33, 0.0, luminance);
        hsv.x += params.liftHue * mask;
        hsv.y = mix(hsv.y, hsv.y * (1.0 + params.liftSaturation), mask);
    }

    // Gamma (Midtones) - affects mid-range
    if (luminance >= 0.33 && luminance <= 0.67) {
        float mask = 1.0 - abs(luminance - 0.5) * 2.0;
        hsv.x += params.gammaHue * mask;
        hsv.y = mix(hsv.y, hsv.y * (1.0 + params.gammaSaturation), mask);
    }

    // Gain (Highlights) - affects bright areas
    if (luminance > 0.67) {
        float mask = smoothstep(0.67, 1.0, luminance);
        hsv.x += params.gainHue * mask;
        hsv.y = mix(hsv.y, hsv.y * (1.0 + params.gainSaturation), mask);
    }

    color.rgb = hsvToRgb(hsv);

    return clamp(color, 0.0, 1.0);
}

// MARK: - Cinematic Color Presets

fragment float4 cinematicWarmShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // Orange/Teal look
    color.r *= 1.15;
    color.g *= 1.05;
    color.b *= 0.85;

    // Lift shadows
    color.rgb += float3(0.02, 0.01, 0.0);

    // Reduce saturation slightly in shadows
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));
    float shadowMask = smoothstep(0.3, 0.0, luminance);
    color.rgb = mix(color.rgb, float3(luminance), shadowMask * 0.2);

    return clamp(color, 0.0, 1.0);
}

fragment float4 cinematicCoolShader(
    VertexOut in [[stage_in]],
    texture2d<float> colorTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = colorTexture.sample(textureSampler, in.texCoord);

    // Teal/Blue look
    color.r *= 0.9;
    color.g *= 1.05;
    color.b *= 1.2;

    // Crush blacks
    color.rgb = max(color.rgb - 0.03, 0.0) * 1.05;

    // Increase contrast
    color.rgb = ((color.rgb - 0.5) * 1.15) + 0.5;

    return clamp(color, 0.0, 1.0);
}
