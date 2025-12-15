//
//  BackgroundEffects.metal
//  Echoelmusic
//
//  Professional Background Effects - GPU-Accelerated
//
//  Features:
//  - Angular Gradient (Conic gradient with smooth interpolation)
//  - Perlin Noise (Multi-octave procedural noise)
//  - Star Particles (GPU-accelerated particle system with twinkling)
//
//  Optimized for real-time rendering @ 120 FPS on all platforms
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Constants

constant float PI = 3.14159265359;
constant float TWO_PI = 6.28318530718;

// MARK: - Shader Parameters

struct AngularGradientParams {
    float2 center;           // Center point (normalized 0-1)
    float rotation;          // Rotation angle in radians
    uint colorCount;         // Number of gradient stops (max 8)
    float4 colors[8];        // Gradient colors (RGBA)
    float positions[8];      // Color stop positions (0-1)
};

struct PerlinNoiseParams {
    float scale;             // Noise scale (higher = more detail)
    uint octaves;            // Number of octaves (1-8)
    float persistence;       // Amplitude multiplier per octave (0-1)
    float lacunarity;        // Frequency multiplier per octave (typically 2.0)
    float time;              // Animation time
    float speed;             // Animation speed multiplier
};

struct StarParticlesParams {
    uint starCount;          // Number of stars (max 1000)
    float time;              // Animation time
    float twinkleSpeed;      // Twinkling frequency
    float minSize;           // Minimum star size (pixels)
    float maxSize;           // Maximum star size (pixels)
    float minBrightness;     // Minimum brightness (0-1)
    float maxBrightness;     // Maximum brightness (0-1)
    float4 starColor;        // Star color (RGBA)
};

// MARK: - Angular Gradient Shader

/// Angular/Conic gradient - color transitions in circular pattern around center
kernel void angularGradient(
    texture2d<float, access::write> output [[texture(0)]],
    constant AngularGradientParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    // Get output dimensions
    uint2 size = uint2(output.get_width(), output.get_height());
    if (gid.x >= size.x || gid.y >= size.y) return;

    // Normalize coordinates (0-1)
    float2 uv = float2(gid) / float2(size);

    // Calculate angle from center
    float2 toPixel = uv - params.center;
    float angle = atan2(toPixel.y, toPixel.x) + PI;  // 0 to 2π
    angle = fmod(angle + params.rotation, TWO_PI);   // Apply rotation
    float normalizedAngle = angle / TWO_PI;          // 0 to 1

    // Find color stops for interpolation
    float4 color = float4(0.0);

    if (params.colorCount == 0) {
        // Fallback to black
        output.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }

    if (params.colorCount == 1) {
        // Single color
        color = params.colors[0];
    } else {
        // Find surrounding color stops
        bool found = false;
        for (uint i = 0; i < params.colorCount - 1; i++) {
            float pos1 = params.positions[i];
            float pos2 = params.positions[i + 1];

            if (normalizedAngle >= pos1 && normalizedAngle <= pos2) {
                // Interpolate between these two colors
                float t = (normalizedAngle - pos1) / (pos2 - pos1);
                color = mix(params.colors[i], params.colors[i + 1], t);
                found = true;
                break;
            }
        }

        if (!found) {
            // Wrap around: interpolate between last and first color
            float lastPos = params.positions[params.colorCount - 1];
            float firstPos = params.positions[0] + 1.0;  // Wrap position

            if (normalizedAngle >= lastPos) {
                float t = (normalizedAngle - lastPos) / (firstPos - lastPos);
                color = mix(params.colors[params.colorCount - 1], params.colors[0], t);
            } else {
                // Before first position, wrap from end
                float t = (normalizedAngle + 1.0 - lastPos) / (firstPos - lastPos);
                color = mix(params.colors[params.colorCount - 1], params.colors[0], t);
            }
        }
    }

    output.write(color, gid);
}

// MARK: - Perlin Noise Shader

/// Hash function for pseudo-random values (deterministic)
float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

/// 2D gradient noise (smooth interpolation)
float gradientNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    // Smoothstep interpolation (Hermite cubic)
    float2 u = f * f * (3.0 - 2.0 * f);

    // Hash corners
    float a = hash(i + float2(0.0, 0.0));
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    // Bilinear interpolation
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

/// Multi-octave Perlin noise (fractal Brownian motion)
float perlinNoise(float2 p, uint octaves, float persistence, float lacunarity) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxValue = 0.0;

    for (uint i = 0; i < octaves; i++) {
        value += gradientNoise(p * frequency) * amplitude;
        maxValue += amplitude;

        amplitude *= persistence;
        frequency *= lacunarity;
    }

    // Normalize to 0-1 range
    return value / maxValue;
}

/// Perlin noise background generator
kernel void perlinNoiseBackground(
    texture2d<float, access::write> output [[texture(0)]],
    constant PerlinNoiseParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint2 size = uint2(output.get_width(), output.get_height());
    if (gid.x >= size.x || gid.y >= size.y) return;

    // Normalize coordinates
    float2 uv = float2(gid) / float2(size);

    // Scale UV coordinates
    float2 p = uv * params.scale;

    // Add time-based animation
    p += float2(params.time * params.speed * 0.1, params.time * params.speed * 0.05);

    // Calculate Perlin noise
    float noise = perlinNoise(p, params.octaves, params.persistence, params.lacunarity);

    // Map to grayscale (0-1)
    float4 color = float4(noise, noise, noise, 1.0);

    output.write(color, gid);
}

// MARK: - Star Particles Shader

/// Pseudo-random number generator (deterministic based on seed)
float random(float seed) {
    return fract(sin(seed * 12.9898) * 43758.5453);
}

float2 random2(float seed) {
    return float2(
        fract(sin(seed * 12.9898) * 43758.5453),
        fract(sin(seed * 78.233) * 43758.5453)
    );
}

/// Star particles renderer with twinkling effect
kernel void starParticles(
    texture2d<float, access::write> output [[texture(0)]],
    constant StarParticlesParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint2 size = uint2(output.get_width(), output.get_height());
    if (gid.x >= size.x || gid.y >= size.y) return;

    // Start with black background
    float4 color = float4(0.0, 0.0, 0.0, 1.0);

    // Normalize pixel coordinates
    float2 pixelPos = float2(gid);

    // Render each star
    for (uint i = 0; i < params.starCount; i++) {
        float seed = float(i) * 0.123456;

        // Generate star position (deterministic)
        float2 starPos = random2(seed) * float2(size);

        // Calculate distance from pixel to star
        float dist = length(pixelPos - starPos);

        // Generate star size (deterministic, varies per star)
        float starSize = mix(params.minSize, params.maxSize, random(seed + 1.0));

        // Twinkling effect (time-based animation)
        float twinklePhase = params.time * params.twinkleSpeed + seed * TWO_PI;
        float twinkle = 0.5 + 0.5 * sin(twinklePhase);

        // Star brightness (varies per star + twinkling)
        float baseBrightness = mix(params.minBrightness, params.maxBrightness, random(seed + 2.0));
        float brightness = baseBrightness * twinkle;

        // Soft circular falloff (Gaussian-like)
        float falloff = exp(-dist * dist / (starSize * starSize));

        // Add star contribution to pixel
        color.rgb += params.starColor.rgb * brightness * falloff;
    }

    // Clamp to prevent HDR overflow
    color.rgb = clamp(color.rgb, 0.0, 1.0);

    output.write(color, gid);
}

// MARK: - Optimized Star Particles (Tile-based)

/// Fast star renderer using tile-based culling for 1000+ stars
kernel void starParticlesFast(
    texture2d<float, access::write> output [[texture(0)]],
    constant StarParticlesParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]],
    uint2 tid [[thread_position_in_threadgroup]],
    uint2 tgid [[threadgroup_position_in_grid]])
{
    uint2 size = uint2(output.get_width(), output.get_height());
    if (gid.x >= size.x || gid.y >= size.y) return;

    // Tile-based optimization: 16x16 tiles
    constexpr uint TILE_SIZE = 16;
    float2 tileMin = float2(tgid * TILE_SIZE);
    float2 tileMax = tileMin + float2(TILE_SIZE);

    float4 color = float4(0.0, 0.0, 0.0, 1.0);
    float2 pixelPos = float2(gid);

    // Only test stars that could affect this tile
    for (uint i = 0; i < params.starCount; i++) {
        float seed = float(i) * 0.123456;
        float2 starPos = random2(seed) * float2(size);
        float starSize = mix(params.minSize, params.maxSize, random(seed + 1.0));

        // Tile culling: skip stars far from this tile
        float maxInfluence = starSize * 3.0;  // 3σ for Gaussian
        if (starPos.x + maxInfluence < tileMin.x || starPos.x - maxInfluence > tileMax.x ||
            starPos.y + maxInfluence < tileMin.y || starPos.y - maxInfluence > tileMax.y) {
            continue;  // Star doesn't affect this tile
        }

        // Calculate star contribution (same as above)
        float dist = length(pixelPos - starPos);

        float twinklePhase = params.time * params.twinkleSpeed + seed * TWO_PI;
        float twinkle = 0.5 + 0.5 * sin(twinklePhase);

        float baseBrightness = mix(params.minBrightness, params.maxBrightness, random(seed + 2.0));
        float brightness = baseBrightness * twinkle;

        float falloff = exp(-dist * dist / (starSize * starSize));

        color.rgb += params.starColor.rgb * brightness * falloff;
    }

    color.rgb = clamp(color.rgb, 0.0, 1.0);
    output.write(color, gid);
}

// MARK: - Combined Utility Shaders

/// Convert grayscale noise to colored gradient
kernel void noiseToGradient(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant AngularGradientParams& gradientParams [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint2 size = uint2(output.get_width(), output.get_height());
    if (gid.x >= size.x || gid.y >= size.y) return;

    // Read noise value (grayscale)
    float noiseValue = input.read(gid).r;

    // Map noise to gradient color
    float4 color = float4(0.0);

    if (gradientParams.colorCount <= 1) {
        color = gradientParams.colors[0];
    } else {
        // Find surrounding color stops
        for (uint i = 0; i < gradientParams.colorCount - 1; i++) {
            if (noiseValue >= gradientParams.positions[i] &&
                noiseValue <= gradientParams.positions[i + 1]) {
                float t = (noiseValue - gradientParams.positions[i]) /
                          (gradientParams.positions[i + 1] - gradientParams.positions[i]);
                color = mix(gradientParams.colors[i], gradientParams.colors[i + 1], t);
                break;
            }
        }
    }

    output.write(color, gid);
}

/// Blend two textures (for layering effects)
kernel void blendTextures(
    texture2d<float, access::read> background [[texture(0)]],
    texture2d<float, access::read> foreground [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant float& opacity [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint2 size = uint2(output.get_width(), output.get_height());
    if (gid.x >= size.x || gid.y >= size.y) return;

    float4 bg = background.read(gid);
    float4 fg = foreground.read(gid);

    // Alpha blend with opacity control
    float4 blended = mix(bg, fg, fg.a * opacity);

    output.write(blended, gid);
}
