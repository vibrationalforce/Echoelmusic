#include <metal_stdlib>
using namespace metal;

// MARK: - Advanced Generative Shaders for Echoelmusic
// Touch Designer / Resolume inspired visual effects

// MARK: - Utility Functions

float hash(float2 p) {
    float h = dot(p, float2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
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

float fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    for (int i = 0; i < octaves; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

// MARK: - Generator: Perlin Noise

kernel void generator_noise(
    texture2d<half, access::write> output [[texture(0)]],
    constant float &time [[buffer(0)]],
    constant float &scale [[buffer(1)]],
    constant float &octaves [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
    uv = uv * scale + time * 0.1;

    float n = fbm(uv, int(octaves));

    half4 color = half4(n, n, n, 1.0);
    output.write(color, gid);
}

// MARK: - Generator: Fractal

kernel void generator_fractal(
    texture2d<half, access::write> output [[texture(0)]],
    constant float &time [[buffer(0)]],
    constant float &zoom [[buffer(1)]],
    constant int &iterations [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = (float2(gid) / float2(output.get_width(), output.get_height())) * 2.0 - 1.0;
    uv *= zoom;

    // Mandelbrot set
    float2 c = uv + float2(sin(time * 0.1) * 0.2, cos(time * 0.1) * 0.2);
    float2 z = float2(0.0);

    float iter = 0.0;
    for (int i = 0; i < iterations; i++) {
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
        if (length(z) > 2.0) break;
        iter += 1.0;
    }

    float value = iter / float(iterations);

    // Color mapping
    float3 col = float3(
        sin(value * 3.0 + time),
        sin(value * 3.0 + time + 2.0),
        sin(value * 3.0 + time + 4.0)
    ) * 0.5 + 0.5;

    output.write(half4(half3(col), 1.0), gid);
}

// MARK: - Generator: Plasma

kernel void generator_plasma(
    texture2d<half, access::write> output [[texture(0)]],
    constant float &time [[buffer(0)]],
    constant float &speed [[buffer(1)]],
    constant float &scale [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = float2(gid) / float2(output.get_width(), output.get_height());

    float t = time * speed;

    float v = sin((uv.x + t) * scale);
    v += sin((uv.y + t) * scale);
    v += sin((uv.x + uv.y + t) * scale);

    float cx = uv.x + 0.5 * sin(t / 5.0);
    float cy = uv.y + 0.5 * cos(t / 3.0);
    v += sin(sqrt(100.0 * (cx * cx + cy * cy) + 1.0) + t);

    v = v / 2.0;

    float3 col = float3(
        sin(v * M_PI_F),
        sin(v * M_PI_F + M_PI_2_F),
        sin(v * M_PI_F + M_PI_F)
    );

    output.write(half4(half3(col), 1.0), gid);
}

// MARK: - Generator: Voronoi

kernel void generator_voronoi(
    texture2d<half, access::write> output [[texture(0)]],
    constant float &time [[buffer(0)]],
    constant float &scale [[buffer(1)]],
    constant int &points [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
    uv *= scale;

    float minDist = 1e10;
    float2 closestPoint;

    for (int i = 0; i < points; i++) {
        float2 point = float2(
            hash(float2(float(i), 0.0) + time * 0.1),
            hash(float2(float(i), 1.0) + time * 0.1)
        ) * scale;

        float dist = distance(uv, point);
        if (dist < minDist) {
            minDist = dist;
            closestPoint = point;
        }
    }

    float value = minDist;

    float3 col = float3(value) * hash(closestPoint);
    output.write(half4(half3(col), 1.0), gid);
}

// MARK: - Filter: Blur

kernel void filter_blur(
    texture2d<half, access::read> input [[texture(0)]],
    texture2d<half, access::write> output [[texture(1)]],
    constant float &radius [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    int r = int(radius);
    float4 sum = float4(0.0);
    float count = 0.0;

    for (int y = -r; y <= r; y++) {
        for (int x = -r; x <= r; x++) {
            int2 pos = int2(gid) + int2(x, y);
            if (pos.x >= 0 && pos.x < input.get_width() &&
                pos.y >= 0 && pos.y < input.get_height()) {
                sum += float4(input.read(uint2(pos)));
                count += 1.0;
            }
        }
    }

    output.write(half4(sum / count), gid);
}

// MARK: - Filter: Edge Detection

kernel void filter_edge(
    texture2d<half, access::read> input [[texture(0)]],
    texture2d<half, access::write> output [[texture(1)]],
    constant float &strength [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Sobel operator
    float3x3 sobelX = float3x3(
        -1, 0, 1,
        -2, 0, 2,
        -1, 0, 1
    );

    float3x3 sobelY = float3x3(
        -1, -2, -1,
         0,  0,  0,
         1,  2,  1
    );

    float gx = 0.0;
    float gy = 0.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            int2 pos = int2(gid) + int2(x, y);
            if (pos.x >= 0 && pos.x < input.get_width() &&
                pos.y >= 0 && pos.y < input.get_height()) {

                float4 col = float4(input.read(uint2(pos)));
                float gray = dot(col.rgb, float3(0.299, 0.587, 0.114));

                gx += gray * sobelX[y + 1][x + 1];
                gy += gray * sobelY[y + 1][x + 1];
            }
        }
    }

    float edge = sqrt(gx * gx + gy * gy) * strength;
    output.write(half4(edge, edge, edge, 1.0), gid);
}

// MARK: - Filter: Kaleidoscope

kernel void filter_kaleidoscope(
    texture2d<half, access::read> input [[texture(0)]],
    texture2d<half, access::write> output [[texture(1)]],
    constant int &segments [[buffer(0)]],
    constant float &rotation [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = (float2(gid) / float2(output.get_width(), output.get_height())) * 2.0 - 1.0;

    float angle = atan2(uv.y, uv.x) + rotation;
    float radius = length(uv);

    // Mirror angle
    float segmentAngle = M_PI_F * 2.0 / float(segments);
    angle = fmod(abs(angle), segmentAngle * 2.0);
    if (angle > segmentAngle) {
        angle = segmentAngle * 2.0 - angle;
    }

    float2 newUV = float2(cos(angle), sin(angle)) * radius;
    newUV = (newUV + 1.0) * 0.5;

    uint2 samplePos = uint2(newUV * float2(input.get_width(), input.get_height()));
    samplePos = clamp(samplePos, uint2(0), uint2(input.get_width() - 1, input.get_height() - 1));

    half4 color = input.read(samplePos);
    output.write(color, gid);
}

// MARK: - Filter: Chromatic Aberration

kernel void filter_chromatic(
    texture2d<half, access::read> input [[texture(0)]],
    texture2d<half, access::write> output [[texture(1)]],
    constant float &strength [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
    float2 center = float2(0.5);
    float2 offset = (uv - center) * strength;

    float2 uvR = uv + offset;
    float2 uvG = uv;
    float2 uvB = uv - offset;

    uint2 posR = uint2(uvR * float2(input.get_width(), input.get_height()));
    uint2 posG = uint2(uvG * float2(input.get_width(), input.get_height()));
    uint2 posB = uint2(uvB * float2(input.get_width(), input.get_height()));

    posR = clamp(posR, uint2(0), uint2(input.get_width() - 1, input.get_height() - 1));
    posG = clamp(posG, uint2(0), uint2(input.get_width() - 1, input.get_height() - 1));
    posB = clamp(posB, uint2(0), uint2(input.get_width() - 1, input.get_height() - 1));

    half r = input.read(posR).r;
    half g = input.read(posG).g;
    half b = input.read(posB).b;

    output.write(half4(r, g, b, 1.0), gid);
}

// MARK: - Filter: Feedback

kernel void filter_feedback(
    texture2d<half, access::read> input [[texture(0)]],
    texture2d<half, access::read> feedback [[texture(1)]],
    texture2d<half, access::write> output [[texture(2)]],
    constant float &mix [[buffer(0)]],
    constant float &decay [[buffer(1)]],
    constant float &displacement [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = float2(gid) / float2(output.get_width(), output.get_height());

    // Displace feedback
    float2 fbUV = uv + float2(sin(uv.y * 10.0), cos(uv.x * 10.0)) * displacement;
    uint2 fbPos = uint2(fbUV * float2(feedback.get_width(), feedback.get_height()));
    fbPos = clamp(fbPos, uint2(0), uint2(feedback.get_width() - 1, feedback.get_height() - 1));

    half4 inputColor = input.read(gid);
    half4 feedbackColor = feedback.read(fbPos) * decay;

    half4 result = mix(inputColor, feedbackColor, mix);
    output.write(result, gid);
}

// MARK: - Operator: Add

kernel void operator_add(
    texture2d<half, access::read> input1 [[texture(0)]],
    texture2d<half, access::read> input2 [[texture(1)]],
    texture2d<half, access::write> output [[texture(2)]],
    constant float &mix [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    half4 col1 = input1.read(gid);
    half4 col2 = input2.read(gid);

    half4 result = col1 + col2 * mix;
    output.write(result, gid);
}

// MARK: - Operator: Multiply

kernel void operator_multiply(
    texture2d<half, access::read> input1 [[texture(0)]],
    texture2d<half, access::read> input2 [[texture(1)]],
    texture2d<half, access::write> output [[texture(2)]],
    constant float &mix [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    half4 col1 = input1.read(gid);
    half4 col2 = input2.read(gid);

    half4 result = col1 * (col2 * mix + (1.0 - mix));
    output.write(result, gid);
}

// MARK: - Operator: Screen

kernel void operator_screen(
    texture2d<half, access::read> input1 [[texture(0)]],
    texture2d<half, access::read> input2 [[texture(1)]],
    texture2d<half, access::write> output [[texture(2)]],
    constant float &mix [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    half4 col1 = input1.read(gid);
    half4 col2 = input2.read(gid);

    half4 screen = 1.0 - (1.0 - col1) * (1.0 - col2);
    half4 result = mix(col1, screen, mix);

    output.write(result, gid);
}

// MARK: - Operator: Overlay

kernel void operator_overlay(
    texture2d<half, access::read> input1 [[texture(0)]],
    texture2d<half, access::read> input2 [[texture(1)]],
    texture2d<half, access::write> output [[texture(2)]],
    constant float &mix [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    half4 col1 = input1.read(gid);
    half4 col2 = input2.read(gid);

    half4 overlay;
    for (int i = 0; i < 3; i++) {
        if (col1[i] < 0.5) {
            overlay[i] = 2.0 * col1[i] * col2[i];
        } else {
            overlay[i] = 1.0 - 2.0 * (1.0 - col1[i]) * (1.0 - col2[i]);
        }
    }
    overlay.a = col1.a;

    half4 result = mix(col1, overlay, mix);
    output.write(result, gid);
}

// MARK: - Audio Reactive: FFT Visualizer

kernel void audio_fft_bars(
    texture2d<half, access::write> output [[texture(0)]],
    constant float *fftData [[buffer(0)]],
    constant int &numBands [[buffer(1)]],
    constant float &smoothing [[buffer(2)]],
    constant float3 &color [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = float2(gid) / float2(output.get_width(), output.get_height());

    int band = int(uv.x * float(numBands));
    float amplitude = fftData[band] * smoothing;

    float bar = step(1.0 - amplitude, uv.y);

    half3 col = half3(color) * bar;
    output.write(half4(col, 1.0), gid);
}

// MARK: - Audio Reactive: Waveform

kernel void audio_waveform(
    texture2d<half, access::write> output [[texture(0)]],
    constant float *waveData [[buffer(0)]],
    constant int &numSamples [[buffer(1)]],
    constant float &thickness [[buffer(2)]],
    constant float3 &color [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = float2(gid) / float2(output.get_width(), output.get_height());

    int sample = int(uv.x * float(numSamples));
    float wave = waveData[sample] * 0.5 + 0.5;  // Normalize to 0-1

    float dist = abs(uv.y - wave);
    float line = smoothstep(thickness, 0.0, dist);

    half3 col = half3(color) * line;
    output.write(half4(col, 1.0), gid);
}

// MARK: - 3D: Ray Marching Sphere

kernel void render_3d_sphere(
    texture2d<half, access::write> output [[texture(0)]],
    constant float &time [[buffer(0)]],
    constant float3 &spherePos [[buffer(1)]],
    constant float &sphereRadius [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 uv = (float2(gid) / float2(output.get_width(), output.get_height())) * 2.0 - 1.0;
    uv.x *= float(output.get_width()) / float(output.get_height());

    float3 rayOrigin = float3(0.0, 0.0, -5.0);
    float3 rayDir = normalize(float3(uv, 1.0));

    // Ray-sphere intersection
    float3 oc = rayOrigin - spherePos;
    float b = dot(oc, rayDir);
    float c = dot(oc, oc) - sphereRadius * sphereRadius;
    float discriminant = b * b - c;

    half4 color = half4(0.0, 0.0, 0.0, 1.0);

    if (discriminant > 0.0) {
        float t = -b - sqrt(discriminant);
        float3 hitPoint = rayOrigin + rayDir * t;
        float3 normal = normalize(hitPoint - spherePos);

        // Simple lighting
        float3 lightDir = normalize(float3(1.0, 1.0, -1.0));
        float diffuse = max(dot(normal, lightDir), 0.0);

        color = half4(diffuse, diffuse, diffuse, 1.0);
    }

    output.write(color, gid);
}
