// ═══════════════════════════════════════════════════════════════════════════════
// METAL VIDEO SHADERS - GPU-ACCELERATED VIDEO EFFECTS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Complete Metal shader implementations for:
// • Scene rendering (vertex + fragment)
// • Gaussian blur
// • Chroma key (green screen)
// • Color grading / LUT
// • Vignette effect
// • Gradient backgrounds
// • Particle systems
// • Perlin noise
//
// ═══════════════════════════════════════════════════════════════════════════════

#include <metal_stdlib>
using namespace metal;

// MARK: - Common Structures

struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct LayerUniforms {
    float opacity;
    float time;
    int effectType;
};

struct BlurUniforms {
    float radius;
    float2 textureSize;
    int horizontal;
};

struct ChromaKeyUniforms {
    float3 keyColor;
    float threshold;
    float smoothing;
    float spillSuppression;
};

struct ColorGradeUniforms {
    float brightness;
    float contrast;
    float saturation;
    float3 shadows;
    float3 midtones;
    float3 highlights;
    float temperature;
    float tint;
};

struct VignetteUniforms {
    float intensity;
    float radius;
    float softness;
    float2 center;
};

struct GradientUniforms {
    float4 color1;
    float4 color2;
    float angle;
    int gradientType; // 0: linear, 1: radial, 2: angular
};

struct ParticleUniforms {
    float time;
    int particleCount;
    float speed;
    float size;
    float4 color;
};

struct Particle {
    float2 position;
    float2 velocity;
    float life;
    float size;
};

// MARK: - Scene Rendering Shaders

vertex VertexOut sceneVertexShader(
    uint vertexID [[vertex_id]],
    constant float *vertices [[buffer(0)]]
) {
    VertexOut out;

    // Each vertex has 5 floats: x, y, z, u, v
    int idx = vertexID * 5;

    out.position = float4(vertices[idx], vertices[idx + 1], vertices[idx + 2], 1.0);
    out.texCoord = float2(vertices[idx + 3], vertices[idx + 4]);

    return out;
}

fragment float4 sceneFragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    constant LayerUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float4 color = texture.sample(textureSampler, in.texCoord);

    // Apply effect based on type
    switch (uniforms.effectType) {
        case 1: // Blur - handled separately with compute shader
            break;
        case 2: // Vignette - basic version
            {
                float2 uv = in.texCoord - 0.5;
                float dist = length(uv);
                float vignette = 1.0 - smoothstep(0.3, 0.7, dist);
                color.rgb *= vignette;
            }
            break;
        default:
            break;
    }

    color.a *= uniforms.opacity;
    return color;
}

// MARK: - Gaussian Blur Shader

kernel void gaussianBlurHorizontal(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant BlurUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float weights[5] = {0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216};

    float4 result = inTexture.read(gid) * weights[0];

    for (int i = 1; i < 5; i++) {
        float offset = float(i) * uniforms.radius;
        uint2 left = uint2(max(0, int(gid.x) - int(offset)), gid.y);
        uint2 right = uint2(min(int(outTexture.get_width()) - 1, int(gid.x) + int(offset)), gid.y);

        result += inTexture.read(left) * weights[i];
        result += inTexture.read(right) * weights[i];
    }

    outTexture.write(result, gid);
}

kernel void gaussianBlurVertical(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant BlurUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float weights[5] = {0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216};

    float4 result = inTexture.read(gid) * weights[0];

    for (int i = 1; i < 5; i++) {
        float offset = float(i) * uniforms.radius;
        uint2 up = uint2(gid.x, max(0, int(gid.y) - int(offset)));
        uint2 down = uint2(gid.x, min(int(outTexture.get_height()) - 1, int(gid.y) + int(offset)));

        result += inTexture.read(up) * weights[i];
        result += inTexture.read(down) * weights[i];
    }

    outTexture.write(result, gid);
}

// MARK: - Chroma Key Shader

kernel void chromaKey(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant ChromaKeyUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float4 color = inTexture.read(gid);

    // Convert to YCbCr for better color matching
    float Y = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
    float Cb = -0.169 * color.r - 0.331 * color.g + 0.500 * color.b;
    float Cr = 0.500 * color.r - 0.419 * color.g - 0.081 * color.b;

    float keyY = 0.299 * uniforms.keyColor.r + 0.587 * uniforms.keyColor.g + 0.114 * uniforms.keyColor.b;
    float keyCb = -0.169 * uniforms.keyColor.r - 0.331 * uniforms.keyColor.g + 0.500 * uniforms.keyColor.b;
    float keyCr = 0.500 * uniforms.keyColor.r - 0.419 * uniforms.keyColor.g - 0.081 * uniforms.keyColor.b;

    // Calculate distance in color space
    float dist = sqrt(pow(Cb - keyCb, 2) + pow(Cr - keyCr, 2));

    // Create alpha mask with smoothing
    float alpha = smoothstep(uniforms.threshold - uniforms.smoothing,
                             uniforms.threshold + uniforms.smoothing,
                             dist);

    // Spill suppression - remove green tint from edges
    float spillFactor = 1.0 - alpha;
    if (uniforms.spillSuppression > 0 && color.g > max(color.r, color.b)) {
        float spill = color.g - max(color.r, color.b);
        color.g -= spill * uniforms.spillSuppression * spillFactor;
    }

    color.a = alpha;
    outTexture.write(color, gid);
}

// MARK: - Color Grading Shader

kernel void colorGrade(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant ColorGradeUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float4 color = inTexture.read(gid);

    // Brightness
    color.rgb += uniforms.brightness;

    // Contrast
    color.rgb = (color.rgb - 0.5) * uniforms.contrast + 0.5;

    // Saturation
    float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
    color.rgb = mix(float3(gray), color.rgb, uniforms.saturation);

    // Lift/Gamma/Gain (Shadows/Midtones/Highlights)
    float luminance = dot(color.rgb, float3(0.299, 0.587, 0.114));

    // Shadows affect darks
    float shadowWeight = 1.0 - luminance;
    shadowWeight = pow(shadowWeight, 2.0);
    color.rgb += uniforms.shadows * shadowWeight;

    // Midtones affect mid-range
    float midWeight = 1.0 - abs(luminance - 0.5) * 2.0;
    color.rgb *= 1.0 + (uniforms.midtones - 1.0) * midWeight;

    // Highlights affect brights
    float highWeight = pow(luminance, 2.0);
    color.rgb *= 1.0 + (uniforms.highlights - 1.0) * highWeight;

    // Temperature (warm/cool)
    if (uniforms.temperature != 0) {
        color.r += uniforms.temperature * 0.1;
        color.b -= uniforms.temperature * 0.1;
    }

    // Tint (green/magenta)
    if (uniforms.tint != 0) {
        color.g += uniforms.tint * 0.1;
    }

    // Clamp
    color.rgb = clamp(color.rgb, 0.0, 1.0);

    outTexture.write(color, gid);
}

// MARK: - Vignette Shader

kernel void vignette(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant VignetteUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float4 color = inTexture.read(gid);

    float2 uv = float2(gid) / float2(outTexture.get_width(), outTexture.get_height());
    float2 center = uniforms.center;

    float dist = distance(uv, center);
    float vignette = smoothstep(uniforms.radius, uniforms.radius - uniforms.softness, dist);

    color.rgb *= mix(1.0 - uniforms.intensity, 1.0, vignette);

    outTexture.write(color, gid);
}

// MARK: - Gradient Background Shader

kernel void gradientBackground(
    texture2d<float, access::write> outTexture [[texture(0)]],
    constant GradientUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float2 uv = float2(gid) / float2(outTexture.get_width(), outTexture.get_height());
    float4 color;

    switch (uniforms.gradientType) {
        case 0: // Linear gradient
        {
            float angle = uniforms.angle;
            float2 direction = float2(cos(angle), sin(angle));
            float t = dot(uv - 0.5, direction) + 0.5;
            color = mix(uniforms.color1, uniforms.color2, t);
        }
        break;

        case 1: // Radial gradient
        {
            float dist = distance(uv, float2(0.5));
            float t = clamp(dist * 2.0, 0.0, 1.0);
            color = mix(uniforms.color1, uniforms.color2, t);
        }
        break;

        case 2: // Angular (conic) gradient
        {
            float2 centered = uv - 0.5;
            float angle = atan2(centered.y, centered.x);
            float t = (angle + M_PI_F) / (2.0 * M_PI_F);
            t = fract(t + uniforms.angle / (2.0 * M_PI_F));
            color = mix(uniforms.color1, uniforms.color2, t);
        }
        break;

        default:
            color = uniforms.color1;
            break;
    }

    outTexture.write(color, gid);
}

// MARK: - Perlin Noise Functions

float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    float2 u = f * f * (3.0 - 2.0 * f);

    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return value;
}

kernel void perlinNoiseBackground(
    texture2d<float, access::write> outTexture [[texture(0)]],
    constant float &time [[buffer(0)]],
    constant float4 &color1 [[buffer(1)]],
    constant float4 &color2 [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float2 uv = float2(gid) / float2(outTexture.get_width(), outTexture.get_height());

    // Animated noise
    float n = fbm(uv * 4.0 + float2(time * 0.1), 5);

    float4 color = mix(color1, color2, n);

    outTexture.write(color, gid);
}

// MARK: - Star Particles Shader

kernel void starParticles(
    texture2d<float, access::write> outTexture [[texture(0)]],
    constant ParticleUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float2 uv = float2(gid) / float2(outTexture.get_width(), outTexture.get_height());
    float4 color = float4(0, 0, 0, 1);

    // Generate pseudo-random stars
    for (int i = 0; i < min(uniforms.particleCount, 200); i++) {
        // Pseudo-random position based on particle index
        float2 starPos = float2(
            fract(sin(float(i) * 12.9898) * 43758.5453),
            fract(sin(float(i) * 78.233) * 43758.5453)
        );

        // Animate y position
        starPos.y = fract(starPos.y + uniforms.time * uniforms.speed * 0.1);

        // Calculate distance to star
        float dist = distance(uv, starPos);

        // Star size with twinkle
        float twinkle = 0.5 + 0.5 * sin(uniforms.time * 2.0 + float(i));
        float starSize = uniforms.size * 0.01 * twinkle;

        // Star glow
        if (dist < starSize) {
            float intensity = 1.0 - (dist / starSize);
            intensity = pow(intensity, 2.0);
            color.rgb += uniforms.color.rgb * intensity * uniforms.color.a;
        }
    }

    color.rgb = clamp(color.rgb, 0.0, 1.0);
    outTexture.write(color, gid);
}

// MARK: - Split Screen Composite

kernel void splitScreenComposite(
    texture2d<float, access::read> textureA [[texture(0)]],
    texture2d<float, access::read> textureB [[texture(1)]],
    texture2d<float, access::write> outTexture [[texture(2)]],
    constant float &splitPosition [[buffer(0)]],
    constant int &splitType [[buffer(1)]], // 0: vertical, 1: horizontal, 2: diagonal
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float2 uv = float2(gid) / float2(outTexture.get_width(), outTexture.get_height());
    float4 color;

    bool useA;

    switch (splitType) {
        case 0: // Vertical split
            useA = uv.x < splitPosition;
            break;
        case 1: // Horizontal split
            useA = uv.y < splitPosition;
            break;
        case 2: // Diagonal split
            useA = (uv.x + uv.y) * 0.5 < splitPosition;
            break;
        default:
            useA = uv.x < splitPosition;
            break;
    }

    color = useA ? textureA.read(gid) : textureB.read(gid);

    outTexture.write(color, gid);
}

// MARK: - Edge Quality Overlay (for chroma key debugging)

kernel void edgeQualityOverlay(
    texture2d<float, access::read> maskTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float alpha = maskTexture.read(gid).a;

    // Calculate edge using Sobel operator
    float sobelX = 0;
    float sobelY = 0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            uint2 samplePos = uint2(
                clamp(int(gid.x) + x, 0, int(outTexture.get_width()) - 1),
                clamp(int(gid.y) + y, 0, int(outTexture.get_height()) - 1)
            );

            float sample = maskTexture.read(samplePos).a;

            // Sobel kernels
            float kernelX[9] = {-1, 0, 1, -2, 0, 2, -1, 0, 1};
            float kernelY[9] = {-1, -2, -1, 0, 0, 0, 1, 2, 1};

            int idx = (y + 1) * 3 + (x + 1);
            sobelX += sample * kernelX[idx];
            sobelY += sample * kernelY[idx];
        }
    }

    float edge = sqrt(sobelX * sobelX + sobelY * sobelY);

    // Color code: red = hard edge, green = soft edge, blue = solid area
    float4 color;
    if (edge > 0.5) {
        color = float4(1, 0, 0, 1); // Hard edge - red
    } else if (edge > 0.1) {
        color = float4(0, 1, 0, 1); // Soft edge - green
    } else {
        color = float4(alpha, alpha, 1, 1); // Solid - blue tint
    }

    outTexture.write(color, gid);
}

// MARK: - Spill Map Visualization

kernel void spillMapVisualization(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant float3 &keyColor [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
        return;
    }

    float4 color = inTexture.read(gid);

    // Calculate green spill amount
    float spill = 0;
    if (color.g > max(color.r, color.b)) {
        spill = color.g - max(color.r, color.b);
    }

    // Visualize: green channel shows spill amount
    float4 output = float4(0, spill * 2.0, 0, 1);

    outTexture.write(output, gid);
}
