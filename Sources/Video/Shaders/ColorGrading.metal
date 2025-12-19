// ColorGrading.metal - GPU-Accelerated Color Grading for VideoWeaver
// Professional color correction with real-time performance
#include <metal_stdlib>
using namespace metal;

//==============================================================================
// Color Grading Parameters
//==============================================================================

struct ColorGradingParams {
    float brightness;      // -1.0 to 1.0
    float contrast;        // -1.0 to 1.0
    float saturation;      // -1.0 to 1.0
    float hue;            // 0.0 to 1.0 (hue wheel rotation)
    float temperature;     // -1.0 to 1.0 (cool to warm)
    float tint;           // -1.0 to 1.0 (green to magenta)
    float exposure;        // -2.0 to 2.0 (EV stops)
    float highlights;      // -1.0 to 1.0
    float shadows;         // -1.0 to 1.0
    float whites;          // -1.0 to 1.0
    float blacks;          // -1.0 to 1.0
    float vignette;        // 0.0 to 1.0 (amount)
    float grain;           // 0.0 to 1.0 (film grain)
};

//==============================================================================
// Color Space Utilities
//==============================================================================

// RGB to HSV conversion
float3 rgb_to_hsv(float3 rgb) {
    float cmax = max(rgb.r, max(rgb.g, rgb.b));
    float cmin = min(rgb.r, min(rgb.g, rgb.b));
    float delta = cmax - cmin;

    float h = 0.0;
    if (delta > 0.0001) {
        if (cmax == rgb.r) {
            h = fmod((rgb.g - rgb.b) / delta + 6.0, 6.0);
        } else if (cmax == rgb.g) {
            h = (rgb.b - rgb.r) / delta + 2.0;
        } else {
            h = (rgb.r - rgb.g) / delta + 4.0;
        }
        h /= 6.0;
    }

    float s = (cmax > 0.0001) ? (delta / cmax) : 0.0;
    float v = cmax;

    return float3(h, s, v);
}

// HSV to RGB conversion
float3 hsv_to_rgb(float3 hsv) {
    float h = hsv.x * 6.0;
    float s = hsv.y;
    float v = hsv.z;

    float c = v * s;
    float x = c * (1.0 - abs(fmod(h, 2.0) - 1.0));
    float m = v - c;

    float3 rgb;
    if (h < 1.0) {
        rgb = float3(c, x, 0.0);
    } else if (h < 2.0) {
        rgb = float3(x, c, 0.0);
    } else if (h < 3.0) {
        rgb = float3(0.0, c, x);
    } else if (h < 4.0) {
        rgb = float3(0.0, x, c);
    } else if (h < 5.0) {
        rgb = float3(x, 0.0, c);
    } else {
        rgb = float3(c, 0.0, x);
    }

    return rgb + m;
}

// Luminance calculation (Rec. 709)
float luminance(float3 rgb) {
    return dot(rgb, float3(0.2126, 0.7152, 0.0722));
}

// Soft light blend mode (for selective adjustments)
float soft_light(float base, float blend) {
    if (blend < 0.5) {
        return 2.0 * base * blend + base * base * (1.0 - 2.0 * blend);
    } else {
        return 2.0 * base * (1.0 - blend) + sqrt(base) * (2.0 * blend - 1.0);
    }
}

// Film grain noise (fast pseudorandom)
float grain_noise(float2 uv, float seed) {
    float x = dot(uv, float2(12.9898, 78.233)) + seed;
    return fract(sin(x) * 43758.5453) - 0.5;
}

//==============================================================================
// Main Color Grading Kernel
//==============================================================================

kernel void colorGradingKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant ColorGradingParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    // Bounds check
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // Read input pixel
    float4 pixel = inputTexture.read(gid);
    float3 rgb = pixel.rgb;
    float alpha = pixel.a;

    // ========== STEP 1: Exposure ==========
    rgb *= exp2(params.exposure);

    // ========== STEP 2: Temperature & Tint ==========

    // Temperature (warm = more red/yellow, cool = more blue)
    if (params.temperature > 0.0) {
        // Warm
        rgb.r += params.temperature * 0.1;
        rgb.b -= params.temperature * 0.1;
    } else {
        // Cool
        rgb.b -= params.temperature * 0.1;
        rgb.r += params.temperature * 0.1;
    }

    // Tint (magenta vs green)
    if (params.tint > 0.0) {
        // Magenta
        rgb.r += params.tint * 0.1;
        rgb.b += params.tint * 0.1;
        rgb.g -= params.tint * 0.05;
    } else {
        // Green
        rgb.g -= params.tint * 0.1;
    }

    // ========== STEP 3: Brightness ==========
    float brightness = 1.0 + params.brightness;
    rgb *= brightness;

    // ========== STEP 4: Contrast ==========
    float contrast = 1.0 + params.contrast;
    rgb = (rgb - 0.5) * contrast + 0.5;

    // ========== STEP 5: Highlights, Shadows, Whites, Blacks ==========
    float luma = luminance(rgb);

    // Highlights (affect bright areas)
    float highlightMask = smoothstep(0.5, 1.0, luma);
    rgb = mix(rgb, rgb * (1.0 + params.highlights * 0.5), highlightMask);

    // Shadows (affect dark areas)
    float shadowMask = smoothstep(0.5, 0.0, luma);
    rgb = mix(rgb, rgb * (1.0 + params.shadows * 0.5), shadowMask);

    // Whites (affect very bright areas)
    float whiteMask = smoothstep(0.75, 1.0, luma);
    rgb = mix(rgb, rgb + params.whites * 0.3, whiteMask);

    // Blacks (affect very dark areas)
    float blackMask = smoothstep(0.25, 0.0, luma);
    rgb = mix(rgb, rgb - params.blacks * 0.3, blackMask);

    // ========== STEP 6: Saturation ==========
    float gray = luminance(rgb);
    float saturation = 1.0 + params.saturation;
    rgb = mix(float3(gray), rgb, saturation);

    // ========== STEP 7: Hue Shift ==========
    if (abs(params.hue) > 0.001) {
        float3 hsv = rgb_to_hsv(rgb);
        hsv.x = fract(hsv.x + params.hue);  // Wrap hue
        rgb = hsv_to_rgb(hsv);
    }

    // ========== STEP 8: Vignette ==========
    if (params.vignette > 0.001) {
        float2 uv = float2(gid) / float2(inputTexture.get_width(), inputTexture.get_height());
        float2 center = uv - 0.5;
        float dist = length(center);
        float vignette = smoothstep(0.8, 0.3, dist);
        vignette = mix(1.0, vignette, params.vignette);
        rgb *= vignette;
    }

    // ========== STEP 9: Film Grain ==========
    if (params.grain > 0.001) {
        float2 uv = float2(gid) / float2(inputTexture.get_width(), inputTexture.get_height());
        float noise = grain_noise(uv, gid.x * 0.001);
        rgb += noise * params.grain * 0.05;
    }

    // ========== STEP 10: Clamp & Output ==========
    rgb = clamp(rgb, 0.0, 1.0);

    outputTexture.write(float4(rgb, alpha), gid);
}

//==============================================================================
// 3D LUT Application Kernel
//==============================================================================

kernel void applyLUTKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    texture3d<float, access::sample> lutTexture [[texture(2)]],
    uint2 gid [[thread_position_in_grid]])
{
    // Bounds check
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // Read input pixel
    float4 pixel = inputTexture.read(gid);
    float3 rgb = pixel.rgb;
    float alpha = pixel.a;

    // Sample 3D LUT (using trilinear interpolation)
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    float3 lutColor = lutTexture.sample(s, rgb).rgb;

    // Write output
    outputTexture.write(float4(lutColor, alpha), gid);
}

//==============================================================================
// Chroma Key Kernel (Greenscreen Removal)
//==============================================================================

struct ChromaKeyParams {
    float3 keyColor;       // Target color to remove (typically green)
    float threshold;       // 0.0 to 1.0
    float smoothness;      // Edge feathering
    float spillSuppression; // Reduce color spill on edges
};

kernel void chromaKeyKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant ChromaKeyParams& params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    float4 pixel = inputTexture.read(gid);
    float3 rgb = pixel.rgb;
    float alpha = pixel.a;

    // Calculate color difference in YCbCr space for better chroma keying
    float3 ycbcr_key = float3(
        0.299 * params.keyColor.r + 0.587 * params.keyColor.g + 0.114 * params.keyColor.b,
        0.5 + (-0.169 * params.keyColor.r - 0.331 * params.keyColor.g + 0.5 * params.keyColor.b),
        0.5 + (0.5 * params.keyColor.r - 0.419 * params.keyColor.g - 0.081 * params.keyColor.b)
    );

    float3 ycbcr_pixel = float3(
        0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b,
        0.5 + (-0.169 * rgb.r - 0.331 * rgb.g + 0.5 * rgb.b),
        0.5 + (0.5 * rgb.r - 0.419 * rgb.g - 0.081 * rgb.b)
    );

    // Chroma distance (ignore luminance Y, compare Cb/Cr only)
    float2 chromaDist = ycbcr_pixel.yz - ycbcr_key.yz;
    float dist = length(chromaDist);

    // Calculate alpha mask
    float mask = smoothstep(params.threshold, params.threshold + params.smoothness, dist);
    alpha *= mask;

    // Spill suppression (remove green tint from edges)
    if (params.spillSuppression > 0.0 && mask < 0.95) {
        float spillAmount = (1.0 - mask) * params.spillSuppression;
        rgb.r = max(rgb.r, rgb.g * spillAmount);
        rgb.b = max(rgb.b, rgb.g * spillAmount);
    }

    outputTexture.write(float4(rgb, alpha), gid);
}

//==============================================================================
// Fast Blur Kernel (Separable Gaussian)
//==============================================================================

kernel void horizontalBlurKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float& blurRadius [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // 5-tap Gaussian blur (horizontal pass)
    float4 sum = float4(0.0);
    float weights[5] = {0.06136, 0.24477, 0.38774, 0.24477, 0.06136};
    int offsets[5] = {-2, -1, 0, 1, 2};

    for (int i = 0; i < 5; ++i) {
        int x = clamp(int(gid.x) + int(blurRadius * offsets[i]), 0, int(inputTexture.get_width()) - 1);
        sum += inputTexture.read(uint2(x, gid.y)) * weights[i];
    }

    outputTexture.write(sum, gid);
}

kernel void verticalBlurKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float& blurRadius [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // 5-tap Gaussian blur (vertical pass)
    float4 sum = float4(0.0);
    float weights[5] = {0.06136, 0.24477, 0.38774, 0.24477, 0.06136};
    int offsets[5] = {-2, -1, 0, 1, 2};

    for (int i = 0; i < 5; ++i) {
        int y = clamp(int(gid.y) + int(blurRadius * offsets[i]), 0, int(inputTexture.get_height()) - 1);
        sum += inputTexture.read(uint2(gid.x, y)) * weights[i];
    }

    outputTexture.write(sum, gid);
}

//==============================================================================
// Sharpen Kernel (Unsharp Mask)
//==============================================================================

kernel void sharpenKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float& amount [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // 3x3 unsharp mask kernel
    float4 center = inputTexture.read(gid);

    float4 neighbors = float4(0.0);
    for (int dy = -1; dy <= 1; ++dy) {
        for (int dx = -1; dx <= 1; ++dx) {
            if (dx == 0 && dy == 0) continue;

            int x = clamp(int(gid.x) + dx, 0, int(inputTexture.get_width()) - 1);
            int y = clamp(int(gid.y) + dy, 0, int(inputTexture.get_height()) - 1);
            neighbors += inputTexture.read(uint2(x, y));
        }
    }
    neighbors /= 8.0;

    // Sharpen = original + amount * (original - blurred)
    float4 sharpened = center + amount * (center - neighbors);
    sharpened = clamp(sharpened, 0.0, 1.0);

    outputTexture.write(sharpened, gid);
}
