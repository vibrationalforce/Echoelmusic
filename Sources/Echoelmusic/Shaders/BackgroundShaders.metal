// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC BACKGROUND SHADERS - GPU-ACCELERATED VISUAL GENERATION
// ═══════════════════════════════════════════════════════════════════════════════
//
// High-performance Metal shaders for:
// • Procedural gradients (linear, radial, angular, diamond)
// • Perlin/Simplex noise generation
// • Particle systems (stars, dust, energy)
// • Bio-reactive visual effects
// • Real-time color grading
//
// ═══════════════════════════════════════════════════════════════════════════════

#include <metal_stdlib>
using namespace metal;

// MARK: - Constants

constant float PI = 3.14159265359;
constant float TAU = 6.28318530718;

// MARK: - Utility Functions

float2 hash2(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)),
               dot(p, float2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float hash1(float2 p) {
    return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

float3 hash3(float2 p) {
    float3 q = float3(dot(p, float2(127.1, 311.7)),
                      dot(p, float2(269.5, 183.3)),
                      dot(p, float2(419.2, 371.9)));
    return fract(sin(q) * 43758.5453);
}

// MARK: - Noise Functions

// Simplex 2D noise
float simplex2D(float2 p) {
    constant float K1 = 0.366025404; // (sqrt(3)-1)/2
    constant float K2 = 0.211324865; // (3-sqrt(3))/6

    float2 i = floor(p + (p.x + p.y) * K1);
    float2 a = p - i + (i.x + i.y) * K2;
    float2 o = (a.x > a.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
    float2 b = a - o + K2;
    float2 c = a - 1.0 + 2.0 * K2;

    float3 h = max(0.5 - float3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    float3 n = h * h * h * h * float3(dot(a, hash2(i)),
                                       dot(b, hash2(i + o)),
                                       dot(c, hash2(i + 1.0)));
    return dot(n, float3(70.0));
}

// Fractal Brownian Motion
float fbm(float2 p, int octaves, float lacunarity, float gain) {
    float sum = 0.0;
    float amp = 1.0;
    float freq = 1.0;
    float maxAmp = 0.0;

    for (int i = 0; i < octaves; i++) {
        sum += simplex2D(p * freq) * amp;
        maxAmp += amp;
        amp *= gain;
        freq *= lacunarity;
    }

    return sum / maxAmp;
}

// Perlin noise (classic)
float perlin2D(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);

    // Quintic interpolation
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    float a = hash1(i);
    float b = hash1(i + float2(1.0, 0.0));
    float c = hash1(i + float2(0.0, 1.0));
    float d = hash1(i + float2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// MARK: - Gradient Kernels

kernel void linearGradient(
    texture2d<float, access::write> output [[texture(0)]],
    constant float4 &color1 [[buffer(0)]],
    constant float4 &color2 [[buffer(1)]],
    constant float &angle [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(output.get_width(), output.get_height());
    float2 uv = float2(gid) / size;

    // Rotate UV based on angle
    float s = sin(angle);
    float c = cos(angle);
    float2 center = float2(0.5);
    float2 rotated = float2(
        c * (uv.x - center.x) - s * (uv.y - center.y) + center.x,
        s * (uv.x - center.x) + c * (uv.y - center.y) + center.y
    );

    float t = rotated.x;
    float4 color = mix(color1, color2, t);

    output.write(color, gid);
}

kernel void radialGradient(
    texture2d<float, access::write> output [[texture(0)]],
    constant float4 &color1 [[buffer(0)]],
    constant float4 &color2 [[buffer(1)]],
    constant float2 &center [[buffer(2)]],
    constant float &radius [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(output.get_width(), output.get_height());
    float2 uv = float2(gid) / size;

    float dist = distance(uv, center) / radius;
    dist = clamp(dist, 0.0, 1.0);

    float4 color = mix(color1, color2, dist);
    output.write(color, gid);
}

kernel void angularGradient(
    texture2d<float, access::write> output [[texture(0)]],
    constant float4 &color1 [[buffer(0)]],
    constant float4 &color2 [[buffer(1)]],
    constant float2 &center [[buffer(2)]],
    constant float &startAngle [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(output.get_width(), output.get_height());
    float2 uv = float2(gid) / size;

    float2 dir = uv - center;
    float angle = atan2(dir.y, dir.x) + PI;
    angle = fmod(angle - startAngle + TAU, TAU);

    float t = angle / TAU;
    float4 color = mix(color1, color2, t);

    output.write(color, gid);
}

kernel void diamondGradient(
    texture2d<float, access::write> output [[texture(0)]],
    constant float4 &color1 [[buffer(0)]],
    constant float4 &color2 [[buffer(1)]],
    constant float2 &center [[buffer(2)]],
    constant float &size_param [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(output.get_width(), output.get_height());
    float2 uv = float2(gid) / size;

    float2 diff = abs(uv - center);
    float dist = (diff.x + diff.y) / size_param;
    dist = clamp(dist, 0.0, 1.0);

    float4 color = mix(color1, color2, dist);
    output.write(color, gid);
}

// MARK: - Noise Backgrounds

kernel void perlinNoiseBackground(
    texture2d<float, access::write> output [[texture(0)]],
    constant float4 &color1 [[buffer(0)]],
    constant float4 &color2 [[buffer(1)]],
    constant float &scale [[buffer(2)]],
    constant float &time [[buffer(3)]],
    constant int &octaves [[buffer(4)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(output.get_width(), output.get_height());
    float2 uv = float2(gid) / size;

    float2 p = uv * scale + float2(time * 0.1, time * 0.05);
    float noise = fbm(p, octaves, 2.0, 0.5) * 0.5 + 0.5;

    float4 color = mix(color1, color2, noise);
    output.write(color, gid);
}

kernel void turbulentNoiseBackground(
    texture2d<float, access::write> output [[texture(0)]],
    constant float4 &color1 [[buffer(0)]],
    constant float4 &color2 [[buffer(1)]],
    constant float &scale [[buffer(2)]],
    constant float &time [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(output.get_width(), output.get_height());
    float2 uv = float2(gid) / size;

    float2 p = uv * scale;

    // Turbulent noise using absolute value
    float noise = 0.0;
    float amp = 1.0;
    float freq = 1.0;

    for (int i = 0; i < 5; i++) {
        noise += abs(simplex2D(p * freq + float2(time * 0.1))) * amp;
        amp *= 0.5;
        freq *= 2.0;
    }

    noise = clamp(noise, 0.0, 1.0);

    float4 color = mix(color1, color2, noise);
    output.write(color, gid);
}

// MARK: - Star Field

struct Star {
    float2 position;
    float brightness;
    float size;
    float twinklePhase;
};

kernel void starFieldBackground(
    texture2d<float, access::write> output [[texture(0)]],
    constant float4 &backgroundColor [[buffer(0)]],
    constant float4 &starColor [[buffer(1)]],
    constant float &time [[buffer(2)]],
    constant float &density [[buffer(3)]],
    constant float &twinkleSpeed [[buffer(4)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(output.get_width(), output.get_height());
    float2 uv = float2(gid) / size;

    float4 color = backgroundColor;

    // Grid-based star placement
    float gridSize = 0.02 / density;
    float2 gridUV = fmod(uv, gridSize) / gridSize;
    float2 gridID = floor(uv / gridSize);

    // Random star properties per grid cell
    float3 rand = hash3(gridID);

    if (rand.x < density * 0.5) {
        // Star exists in this cell
        float2 starPos = float2(rand.y, rand.z);
        float dist = distance(gridUV, starPos);

        float starSize = 0.02 + rand.x * 0.03;
        float brightness = smoothstep(starSize, 0.0, dist);

        // Twinkle
        float twinkle = 0.7 + 0.3 * sin(time * twinkleSpeed + rand.x * TAU);
        brightness *= twinkle;

        // Add glow
        float glow = exp(-dist * 30.0) * 0.3;
        brightness += glow;

        color = mix(color, starColor, brightness);
    }

    // Add distant stars (smaller, more numerous)
    float2 smallGridID = floor(uv * 200.0);
    float smallRand = hash1(smallGridID);
    if (smallRand > 0.995) {
        float twinkle = 0.5 + 0.5 * sin(time * 2.0 + smallRand * TAU);
        color = mix(color, starColor, 0.3 * twinkle);
    }

    output.write(color, gid);
}

// MARK: - Particle Effects

kernel void energyParticles(
    texture2d<float, access::write> output [[texture(0)]],
    constant float4 &backgroundColor [[buffer(0)]],
    constant float4 &particleColor [[buffer(1)]],
    constant float &time [[buffer(2)]],
    constant float &coherence [[buffer(3)]],
    constant float &energy [[buffer(4)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(output.get_width(), output.get_height());
    float2 uv = float2(gid) / size;

    float4 color = backgroundColor;

    // Bio-reactive particle speed and count
    float speed = 0.5 + energy * 1.5;
    float particleCount = 20.0 + coherence * 30.0;

    float brightness = 0.0;

    for (float i = 0.0; i < 50.0; i++) {
        if (i >= particleCount) break;

        float3 rand = hash3(float2(i, i * 0.7));

        // Particle path (flowing upward with organic movement)
        float t = fmod(time * speed * (0.5 + rand.x * 0.5) + rand.y * 10.0, 10.0) / 10.0;

        float2 pos;
        pos.x = rand.z + sin(t * TAU + rand.x * TAU) * 0.1 * coherence;
        pos.y = t;

        float dist = distance(uv, pos);
        float particleSize = 0.01 + rand.x * 0.02 * energy;

        // Soft particle with glow
        float particle = smoothstep(particleSize * 2.0, 0.0, dist);
        particle *= smoothstep(0.0, 0.1, t) * smoothstep(1.0, 0.9, t); // Fade in/out

        brightness += particle;
    }

    brightness = clamp(brightness, 0.0, 1.0);
    color = mix(color, particleColor, brightness);

    output.write(color, gid);
}

// MARK: - Bio-Reactive Overlay

kernel void bioReactiveOverlay(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant float &coherence [[buffer(0)]],
    constant float &heartRate [[buffer(1)]],
    constant float &hrv [[buffer(2)]],
    constant float &time [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float4 color = input.read(gid);
    float2 size = float2(input.get_width(), input.get_height());
    float2 uv = float2(gid) / size;

    // Heartbeat pulse effect
    float heartbeatFreq = heartRate / 60.0;
    float pulse = sin(time * heartbeatFreq * TAU) * 0.5 + 0.5;
    pulse = pow(pulse, 4.0); // Sharper pulse

    // Vignette that pulses with heartbeat
    float2 center = float2(0.5);
    float vignette = 1.0 - distance(uv, center) * (0.8 + pulse * 0.2);
    vignette = clamp(vignette, 0.0, 1.0);

    // Color warmth based on coherence
    float warmth = coherence;
    color.r *= 1.0 + warmth * 0.1;
    color.b *= 1.0 - warmth * 0.1;

    // Saturation based on HRV
    float saturation = 0.8 + hrv / 100.0 * 0.4;
    float gray = dot(color.rgb, float3(0.299, 0.587, 0.114));
    color.rgb = mix(float3(gray), color.rgb, saturation);

    // Apply vignette
    color.rgb *= vignette;

    // Subtle breathing overlay (based on typical breathing rate)
    float breathRate = 0.2; // ~12 breaths per minute
    float breath = sin(time * breathRate * TAU) * 0.5 + 0.5;
    color.rgb *= 0.95 + breath * 0.05;

    output.write(color, gid);
}

// MARK: - Scene Compositing

kernel void sceneComposite(
    texture2d<float, access::read> layer1 [[texture(0)]],
    texture2d<float, access::read> layer2 [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant float &opacity [[buffer(0)]],
    constant int &blendMode [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float4 base = layer1.read(gid);
    float4 blend = layer2.read(gid);

    float4 result;

    switch (blendMode) {
        case 0: // Normal
            result = mix(base, blend, blend.a * opacity);
            break;

        case 1: // Multiply
            result.rgb = base.rgb * blend.rgb;
            result.a = base.a;
            result = mix(base, result, opacity);
            break;

        case 2: // Screen
            result.rgb = 1.0 - (1.0 - base.rgb) * (1.0 - blend.rgb);
            result.a = base.a;
            result = mix(base, result, opacity);
            break;

        case 3: // Overlay
            result.rgb = mix(
                2.0 * base.rgb * blend.rgb,
                1.0 - 2.0 * (1.0 - base.rgb) * (1.0 - blend.rgb),
                step(0.5, base.rgb)
            );
            result.a = base.a;
            result = mix(base, result, opacity);
            break;

        case 4: // Add
            result.rgb = base.rgb + blend.rgb * opacity;
            result.a = base.a;
            break;

        default:
            result = mix(base, blend, blend.a * opacity);
    }

    output.write(result, gid);
}

// MARK: - Scene Transitions

kernel void sceneTransition(
    texture2d<float, access::read> from [[texture(0)]],
    texture2d<float, access::read> to [[texture(1)]],
    texture2d<float, access::write> output [[texture(2)]],
    constant float &progress [[buffer(0)]],
    constant int &transitionType [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 size = float2(from.get_width(), from.get_height());
    float2 uv = float2(gid) / size;

    float4 fromColor = from.read(gid);
    float4 toColor = to.read(gid);
    float4 result;

    switch (transitionType) {
        case 0: // Dissolve/Fade
            result = mix(fromColor, toColor, progress);
            break;

        case 1: // Slide Right
        {
            float slidePos = progress * size.x;
            if (float(gid.x) < slidePos) {
                result = toColor;
            } else {
                result = fromColor;
            }
        }
            break;

        case 2: // Slide Left
        {
            float slidePos = (1.0 - progress) * size.x;
            if (float(gid.x) > slidePos) {
                result = toColor;
            } else {
                result = fromColor;
            }
        }
            break;

        case 3: // Wipe Circle
        {
            float2 center = float2(0.5);
            float dist = distance(uv, center);
            float radius = progress * 1.5; // 1.5 to cover corners
            result = dist < radius ? toColor : fromColor;
        }
            break;

        case 4: // Zoom
        {
            float scale = 1.0 + progress * 0.5;
            float2 scaledUV = (uv - 0.5) / scale + 0.5;

            if (scaledUV.x >= 0.0 && scaledUV.x <= 1.0 &&
                scaledUV.y >= 0.0 && scaledUV.y <= 1.0) {
                uint2 scaledGID = uint2(scaledUV * size);
                fromColor = from.read(scaledGID);
            }

            float fadeProgress = smoothstep(0.3, 0.7, progress);
            result = mix(fromColor, toColor, fadeProgress);
        }
            break;

        case 5: // Pixelate
        {
            float pixelSize = mix(1.0, 50.0, 1.0 - abs(progress - 0.5) * 2.0);
            float2 pixelUV = floor(uv * size / pixelSize) * pixelSize;
            uint2 pixelGID = uint2(pixelUV);

            if (progress < 0.5) {
                result = from.read(pixelGID);
            } else {
                result = to.read(pixelGID);
            }
        }
            break;

        default:
            result = mix(fromColor, toColor, progress);
    }

    output.write(result, gid);
}

// MARK: - Color Grading

kernel void colorGrading(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant float &brightness [[buffer(0)]],
    constant float &contrast [[buffer(1)]],
    constant float &saturation [[buffer(2)]],
    constant float &temperature [[buffer(3)]],
    constant float &tint [[buffer(4)]],
    constant float3 &lift [[buffer(5)]],
    constant float3 &gamma [[buffer(6)]],
    constant float3 &gain [[buffer(7)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float4 color = input.read(gid);

    // Apply brightness
    color.rgb += brightness;

    // Apply contrast
    color.rgb = (color.rgb - 0.5) * contrast + 0.5;

    // Apply saturation
    float luma = dot(color.rgb, float3(0.299, 0.587, 0.114));
    color.rgb = mix(float3(luma), color.rgb, saturation);

    // Apply temperature (simple approximation)
    float tempShift = temperature / 100.0;
    color.r += tempShift * 0.1;
    color.b -= tempShift * 0.1;

    // Apply tint
    float tintShift = tint / 100.0;
    color.g += tintShift * 0.1;

    // Apply lift/gamma/gain (color wheels)
    color.rgb = pow(max(color.rgb + lift, 0.0), gamma) * gain;

    // Clamp
    color.rgb = clamp(color.rgb, 0.0, 1.0);

    output.write(color, gid);
}
