//
//  ChromaKey.metal
//  Echoelmusic
//
//  Chroma Key 6-Pass Pipeline for Real-Time Greenscreen/Bluescreen
//  Optimized for 120 FPS @ 1080p on iPhone 16 Pro
//
//  Pipeline:
//  1. Color Key Extraction (HSV distance-based)
//  2. Edge Detection (Sobel operator for matte refinement)
//  3. Despill Algorithm (Remove green/blue reflections)
//  4. Edge Feathering (Gaussian blur on alpha)
//  5. Light Wrap (Background color bleeding on edges)
//  6. Final Composite (Pre-multiplied alpha blend)
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Shader Parameters (Must match Swift struct)

struct ChromaKeyParams {
    float3 keyColor;          // HSV key color (hue, saturation, value)
    float tolerance;          // Color distance tolerance (0.0 - 1.0)
    float edgeSoftness;       // Edge feathering amount (0.0 - 1.0)
    float despillStrength;    // Spill removal strength (0.0 - 1.0)
    float lightWrapAmount;    // Light wrap intensity (0.0 - 1.0)
};

// MARK: - Helper Functions

/// Convert RGB to HSV color space
float3 rgb_to_hsv(float3 rgb) {
    float maxC = max(rgb.r, max(rgb.g, rgb.b));
    float minC = min(rgb.r, min(rgb.g, rgb.b));
    float delta = maxC - minC;

    float h = 0.0;
    float s = maxC == 0.0 ? 0.0 : delta / maxC;
    float v = maxC;

    if (delta != 0.0) {
        if (maxC == rgb.r) {
            h = fmod((rgb.g - rgb.b) / delta, 6.0);
        } else if (maxC == rgb.g) {
            h = ((rgb.b - rgb.r) / delta) + 2.0;
        } else {
            h = ((rgb.r - rgb.g) / delta) + 4.0;
        }
        h /= 6.0;
        if (h < 0.0) h += 1.0;
    }

    return float3(h, s, v);
}

/// Convert HSV to RGB color space
float3 hsv_to_rgb(float3 hsv) {
    float h = hsv.x * 6.0;
    float s = hsv.y;
    float v = hsv.z;

    float c = v * s;
    float x = c * (1.0 - abs(fmod(h, 2.0) - 1.0));
    float m = v - c;

    float3 rgb;
    if (h < 1.0)      rgb = float3(c, x, 0.0);
    else if (h < 2.0) rgb = float3(x, c, 0.0);
    else if (h < 3.0) rgb = float3(0.0, c, x);
    else if (h < 4.0) rgb = float3(0.0, x, c);
    else if (h < 5.0) rgb = float3(x, 0.0, c);
    else              rgb = float3(c, 0.0, x);

    return rgb + m;
}

/// Calculate HSV color distance with proper hue wrapping
float hsv_distance(float3 hsv1, float3 hsv2) {
    // Hue distance (circular, 0-1 wraps around)
    float hueDist = abs(hsv1.x - hsv2.x);
    if (hueDist > 0.5) hueDist = 1.0 - hueDist;

    // Saturation and value distances
    float satDist = abs(hsv1.y - hsv2.y);
    float valDist = abs(hsv1.z - hsv2.z);

    // Weighted distance (hue is most important for chroma keying)
    return sqrt(hueDist * hueDist * 4.0 + satDist * satDist + valDist * valDist * 0.5);
}

/// Smoothstep function for smooth alpha transitions
float smoothstep_alpha(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

// MARK: - Pass 1: Color Key Extraction (HSV Distance)

kernel void chromaKeyColorExtraction(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant ChromaKeyParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Bounds check
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // Read input pixel
    float4 pixel = inputTexture.read(gid);
    float3 rgb = pixel.rgb;

    // Convert to HSV
    float3 hsv = rgb_to_hsv(rgb);

    // Calculate distance from key color in HSV space
    float distance = hsv_distance(hsv, params.keyColor);

    // Generate alpha matte
    // Distance < tolerance → fully transparent (alpha = 0)
    // Distance > tolerance → fully opaque (alpha = 1)
    float alpha = smoothstep_alpha(0.0, params.tolerance, distance);

    // Output: RGB (original) + Alpha (matte)
    outputTexture.write(float4(rgb, alpha), gid);
}

// MARK: - Pass 2: Edge Detection (Sobel Operator)

kernel void chromaKeyEdgeDetection(
    texture2d<float, access::read> inputTexture [[texture(0)]],   // Matte from pass 1
    texture2d<float, access::write> outputTexture [[texture(1)]],  // Refined matte
    constant ChromaKeyParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Bounds check
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // Read input pixel
    float4 center = inputTexture.read(gid);

    // Sample 3x3 neighborhood (Sobel operator)
    // Only sample alpha channel for edge detection
    float samples[9];
    int idx = 0;
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            int2 offset = int2(gid) + int2(dx, dy);
            // Clamp to texture bounds
            offset.x = clamp(offset.x, 0, int(inputTexture.get_width()) - 1);
            offset.y = clamp(offset.y, 0, int(inputTexture.get_height()) - 1);

            float4 sample = inputTexture.read(uint2(offset));
            samples[idx++] = sample.a;
        }
    }

    // Sobel kernels for edge detection
    // Horizontal gradient
    float Gx = -samples[0] + samples[2]
               -2.0*samples[3] + 2.0*samples[5]
               -samples[6] + samples[8];

    // Vertical gradient
    float Gy = -samples[0] - 2.0*samples[1] - samples[2]
               +samples[6] + 2.0*samples[7] + samples[8];

    // Gradient magnitude
    float edgeStrength = sqrt(Gx*Gx + Gy*Gy);

    // Refine alpha based on edge strength
    // Strong edges → reduce alpha for better edge quality
    float refinedAlpha = center.a * (1.0 - edgeStrength * 0.3);
    refinedAlpha = clamp(refinedAlpha, 0.0, 1.0);

    // Output refined matte
    outputTexture.write(float4(center.rgb, refinedAlpha), gid);
}

// MARK: - Pass 3: Despill Algorithm (Remove Green/Blue Reflections)

kernel void chromaKeyDespill(
    texture2d<float, access::read> inputTexture [[texture(0)]],   // Original RGB
    texture2d<float, access::write> outputTexture [[texture(1)]],  // Despilled RGB
    texture2d<float, access::read> matteTexture [[texture(3)]],    // Refined matte
    constant ChromaKeyParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Bounds check
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // Read input pixel
    float4 pixel = inputTexture.read(gid);
    float3 rgb = pixel.rgb;

    // Read matte alpha
    float4 matte = matteTexture.read(gid);
    float alpha = matte.a;

    // Despill only on semi-transparent edges (0.1 < alpha < 0.9)
    if (alpha > 0.1 && alpha < 0.9) {
        // Detect dominant key color channel
        float keyChannel;
        if (params.keyColor.x < 0.2 || params.keyColor.x > 0.9) {
            // Red key (rare)
            keyChannel = rgb.r;
        } else if (params.keyColor.x < 0.4) {
            // Green key (most common)
            keyChannel = rgb.g;
        } else {
            // Blue key
            keyChannel = rgb.b;
        }

        // Calculate spill amount
        float maxOther = max(rgb.r, max(rgb.g, rgb.b));
        float spillAmount = max(0.0, keyChannel - maxOther);

        // Remove spill by reducing the key channel
        float3 despilled = rgb;
        if (params.keyColor.x < 0.4) {
            // Green despill
            despilled.g -= spillAmount * params.despillStrength;
        } else {
            // Blue despill
            despilled.b -= spillAmount * params.despillStrength;
        }

        // Clamp to valid range
        despilled = clamp(despilled, 0.0, 1.0);

        // Blend based on alpha
        rgb = mix(rgb, despilled, params.despillStrength);
    }

    // Output despilled color with original alpha
    outputTexture.write(float4(rgb, alpha), gid);
}

// MARK: - Pass 4: Edge Feathering (Gaussian Blur on Alpha)

kernel void chromaKeyFeathering(
    texture2d<float, access::read> inputTexture [[texture(0)]],   // Matte
    texture2d<float, access::write> outputTexture [[texture(1)]],  // Feathered matte
    constant ChromaKeyParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Bounds check
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // Read center pixel
    float4 center = inputTexture.read(gid);

    // If fully opaque or fully transparent, no feathering needed
    if (center.a <= 0.01 || center.a >= 0.99) {
        outputTexture.write(center, gid);
        return;
    }

    // Gaussian blur on alpha channel (5x5 kernel)
    // Kernel size scales with edgeSoftness parameter
    int kernelRadius = int(params.edgeSoftness * 4.0) + 1;  // 1-5 pixels

    float alphaSum = 0.0;
    float weightSum = 0.0;

    // Gaussian weights (approximated)
    for (int dy = -kernelRadius; dy <= kernelRadius; dy++) {
        for (int dx = -kernelRadius; dx <= kernelRadius; dx++) {
            int2 offset = int2(gid) + int2(dx, dy);

            // Clamp to texture bounds
            offset.x = clamp(offset.x, 0, int(inputTexture.get_width()) - 1);
            offset.y = clamp(offset.y, 0, int(inputTexture.get_height()) - 1);

            float4 sample = inputTexture.read(uint2(offset));

            // Gaussian weight (approximated)
            float dist = float(dx*dx + dy*dy);
            float weight = exp(-dist / (2.0 * params.edgeSoftness * 5.0));

            alphaSum += sample.a * weight;
            weightSum += weight;
        }
    }

    // Normalize
    float blurredAlpha = alphaSum / weightSum;

    // Output feathered matte
    outputTexture.write(float4(center.rgb, blurredAlpha), gid);
}

// MARK: - Pass 5: Light Wrap (Background Color Bleeding)

kernel void chromaKeyLightWrap(
    texture2d<float, access::read> inputTexture [[texture(0)]],       // Despilled foreground
    texture2d<float, access::write> outputTexture [[texture(1)]],      // Wrapped foreground
    texture2d<float, access::read> backgroundTexture [[texture(2)]],   // Background
    texture2d<float, access::read> matteTexture [[texture(3)]],        // Feathered matte
    constant ChromaKeyParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Bounds check
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // Read foreground pixel
    float4 foreground = inputTexture.read(gid);

    // Read matte alpha
    float4 matte = matteTexture.read(gid);
    float alpha = matte.a;

    // Light wrap only on edges (0.3 < alpha < 0.9)
    if (alpha > 0.3 && alpha < 0.9) {
        // Sample dilated background (slightly offset towards transparent area)
        // This simulates light wrapping around subject edges

        float3 bgColorSum = float3(0.0);
        float weightSum = 0.0;

        // Sample 3x3 background neighborhood
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                int2 offset = int2(gid) + int2(dx, dy);

                // Clamp to texture bounds
                offset.x = clamp(offset.x, 0, int(backgroundTexture.get_width()) - 1);
                offset.y = clamp(offset.y, 0, int(backgroundTexture.get_height()) - 1);

                float4 bgSample = backgroundTexture.read(uint2(offset));

                // Weight towards transparent side
                float weight = 1.0 - alpha;
                bgColorSum += bgSample.rgb * weight;
                weightSum += weight;
            }
        }

        // Average background color
        float3 bgColor = bgColorSum / max(weightSum, 0.001);

        // Blend background color onto foreground edges
        float wrapStrength = params.lightWrapAmount * (1.0 - alpha);
        foreground.rgb = mix(foreground.rgb, bgColor, wrapStrength);
    }

    // Output wrapped foreground
    outputTexture.write(float4(foreground.rgb, alpha), gid);
}

// MARK: - Pass 6: Final Composite (Pre-Multiplied Alpha)

kernel void chromaKeyComposite(
    texture2d<float, access::read> inputTexture [[texture(0)]],       // Wrapped foreground
    texture2d<float, access::write> outputTexture [[texture(1)]],      // Final output
    texture2d<float, access::read> backgroundTexture [[texture(2)]],   // Background (optional)
    texture2d<float, access::read> matteTexture [[texture(3)]],        // Feathered matte
    constant ChromaKeyParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Bounds check
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    // Read foreground pixel (already despilled and wrapped)
    float4 foreground = inputTexture.read(gid);

    // Read final matte alpha
    float4 matte = matteTexture.read(gid);
    float alpha = matte.a;

    // Pre-multiply alpha
    float3 premultipliedFG = foreground.rgb * alpha;

    // Composite with background (if provided)
    float3 finalColor;
    if (backgroundTexture.get_width() > 0) {
        // Read background
        float4 background = backgroundTexture.read(gid);

        // Standard alpha compositing: FG over BG
        // Output = FG_rgb * FG_alpha + BG_rgb * (1 - FG_alpha)
        finalColor = premultipliedFG + background.rgb * (1.0 - alpha);
    } else {
        // No background - output foreground with alpha
        finalColor = premultipliedFG;
    }

    // Output final composited image
    outputTexture.write(float4(finalColor, 1.0), gid);
}

// MARK: - Bonus: Preview Mode Shaders

/// Preview Mode: Key Only (Alpha matte visualization)
kernel void chromaKeyPreviewKeyOnly(
    texture2d<float, access::read> matteTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= matteTexture.get_width() || gid.y >= matteTexture.get_height()) {
        return;
    }

    float4 matte = matteTexture.read(gid);
    float alpha = matte.a;

    // Display alpha as grayscale
    float3 gray = float3(alpha);
    outputTexture.write(float4(gray, 1.0), gid);
}

/// Preview Mode: Edge Overlay (Red = bad key, Green = good key)
kernel void chromaKeyPreviewEdgeOverlay(
    texture2d<float, access::read> inputTexture [[texture(0)]],   // Original
    texture2d<float, access::read> matteTexture [[texture(1)]],   // Matte
    texture2d<float, access::write> outputTexture [[texture(2)]],  // Overlay
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    float4 original = inputTexture.read(gid);
    float4 matte = matteTexture.read(gid);
    float alpha = matte.a;

    // Color code key quality
    float3 overlay;
    if (alpha < 0.1) {
        // Fully keyed (transparent) → Green
        overlay = float3(0.0, 1.0, 0.0);
    } else if (alpha > 0.9) {
        // Fully opaque (good) → No overlay
        overlay = original.rgb;
    } else {
        // Semi-transparent (edge) → Red (needs attention)
        overlay = float3(1.0, 0.0, 0.0);
    }

    // Blend overlay with original
    float3 finalColor = mix(original.rgb, overlay, 0.5);
    outputTexture.write(float4(finalColor, 1.0), gid);
}

/// Preview Mode: Spill Map (Visualize green/blue reflections)
kernel void chromaKeyPreviewSpillMap(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant ChromaKeyParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height()) {
        return;
    }

    float4 pixel = inputTexture.read(gid);
    float3 rgb = pixel.rgb;

    // Detect spill based on key color
    float spillAmount = 0.0;
    if (params.keyColor.x < 0.4) {
        // Green spill
        spillAmount = max(0.0, rgb.g - max(rgb.r, rgb.b));
    } else {
        // Blue spill
        spillAmount = max(0.0, rgb.b - max(rgb.r, rgb.g));
    }

    // Visualize spill (black to red gradient)
    float3 spillColor = float3(spillAmount * 5.0, 0.0, 0.0);
    spillColor = clamp(spillColor, 0.0, 1.0);

    outputTexture.write(float4(spillColor, 1.0), gid);
}
