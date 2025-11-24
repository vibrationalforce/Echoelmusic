//
//  AdvancedShaders.metal
//  Echoelmusic
//
//  Professional-grade Metal shaders für bio-reaktive Audio-Visualisierung
//
//  Features:
//  - Particle Systems (GPU-accelerated)
//  - Post-Processing Effects (Bloom, Motion Blur, DOF)
//  - Bio-Reactive Visualizations (HRV, Coherence)
//  - Frequency Spectrum Analysis
//  - 3D Audio Visualization
//  - HDR Rendering
//  - Physically-Based Rendering (PBR)
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// MARK: - Constants & Structures

constant float PI = 3.14159265359;
constant float TWO_PI = 6.28318530718;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
    float4 color [[attribute(3)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float2 texCoord;
    float4 color;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4x4 normalMatrix;
    float time;
    float deltaTime;
    float audioLevel;
    float hrv;
    float coherence;
    float bassLevel;
    float midLevel;
    float highLevel;
};

struct ParticleData {
    float3 position;
    float3 velocity;
    float4 color;
    float life;
    float size;
};

struct FragmentUniforms {
    float exposure;
    float bloomThreshold;
    float bloomIntensity;
    float vignetteStrength;
    float saturation;
    float contrast;
};

// MARK: - Utility Functions

float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);

    float a = hash(i + float2(0.0, 0.0));
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
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

float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// MARK: - Particle System

kernel void updateParticles(device ParticleData* particles [[buffer(0)]],
                           constant Uniforms& uniforms [[buffer(1)]],
                           constant float* audioSpectrum [[buffer(2)]],
                           uint id [[thread_position_in_grid]]) {
    ParticleData particle = particles[id];

    // Update life
    particle.life -= uniforms.deltaTime;

    if (particle.life <= 0.0) {
        // Reset particle
        float angle = float(id) * 0.1 + uniforms.time * 0.5;
        float radius = 2.0 + uniforms.audioLevel * 3.0;

        particle.position = float3(cos(angle) * radius,
                                   sin(angle) * radius,
                                   (hash(float2(id, uniforms.time)) - 0.5) * 2.0);

        // Bio-reactive velocity
        float speedMultiplier = 1.0 + uniforms.coherence * 2.0;
        particle.velocity = normalize(particle.position) * 0.5 * speedMultiplier;

        // Color based on frequency content
        float hue = float(id % 100) / 100.0;
        hue += uniforms.bassLevel * 0.1;
        particle.color = float4(hsv2rgb(float3(hue, 0.8, 1.0)), 1.0);

        particle.life = 1.0 + uniforms.hrv * 2.0; // HRV affects lifetime
        particle.size = 0.05 + uniforms.audioLevel * 0.1;
    } else {
        // Update position
        particle.position += particle.velocity * uniforms.deltaTime;

        // Apply audio reactivity
        float audioForce = uniforms.audioLevel * 0.1;
        int spectrumIndex = (id % 64);
        float spectrumValue = audioSpectrum[spectrumIndex];

        // Frequency-based movement
        particle.velocity.y += spectrumValue * 0.05;
        particle.velocity *= 0.98; // Drag

        // Update color alpha based on life
        particle.color.a = particle.life;

        // Size pulsates with audio
        particle.size = particle.size + sin(uniforms.time * 5.0) * 0.01 * uniforms.audioLevel;
    }

    particles[id] = particle;
}

vertex VertexOut particleVertex(device ParticleData* particles [[buffer(0)]],
                                constant Uniforms& uniforms [[buffer(1)]],
                                uint vertexID [[vertex_id]],
                                uint instanceID [[instance_id]]) {
    ParticleData particle = particles[instanceID];

    // Billboard vertices (camera-facing quad)
    float2 quadVertices[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };

    float2 quadPos = quadVertices[vertexID % 4] * particle.size;

    // Camera right and up vectors (simplified - should extract from view matrix)
    float3 cameraRight = float3(uniforms.viewMatrix[0][0],
                                uniforms.viewMatrix[1][0],
                                uniforms.viewMatrix[2][0]);
    float3 cameraUp = float3(uniforms.viewMatrix[0][1],
                            uniforms.viewMatrix[1][1],
                            uniforms.viewMatrix[2][1]);

    float3 worldPosition = particle.position +
                          cameraRight * quadPos.x +
                          cameraUp * quadPos.y;

    VertexOut out;
    float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
    out.position = mvp * float4(worldPosition, 1.0);
    out.worldPosition = worldPosition;
    out.texCoord = (quadVertices[vertexID % 4] + 1.0) * 0.5;
    out.color = particle.color;

    return out;
}

fragment float4 particleFragment(VertexOut in [[stage_in]],
                                constant Uniforms& uniforms [[buffer(0)]]) {
    // Soft circular particle
    float2 coord = in.texCoord * 2.0 - 1.0;
    float dist = length(coord);
    float alpha = 1.0 - smoothstep(0.7, 1.0, dist);

    // Glow effect
    float glow = exp(-dist * 2.0);

    float4 color = in.color;
    color.rgb += glow * 0.5 * uniforms.audioLevel;
    color.a *= alpha;

    return color;
}

// MARK: - Frequency Spectrum Visualization

vertex VertexOut spectrumVertex(constant float* spectrum [[buffer(0)]],
                                constant Uniforms& uniforms [[buffer(1)]],
                                uint vertexID [[vertex_id]]) {
    int barIndex = vertexID / 6; // 6 vertices per bar (2 triangles)
    int vertexInBar = vertexID % 6;

    float barWidth = 2.0 / 128.0; // 128 bars
    float x = -1.0 + float(barIndex) * barWidth * 2.0;
    float height = spectrum[barIndex] * 2.0; // Scale height

    // Vertices for quad
    float3 positions[6] = {
        float3(x, 0.0, 0.0),
        float3(x + barWidth, 0.0, 0.0),
        float3(x, height, 0.0),
        float3(x + barWidth, 0.0, 0.0),
        float3(x + barWidth, height, 0.0),
        float3(x, height, 0.0)
    };

    VertexOut out;
    float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
    out.position = mvp * float4(positions[vertexInBar], 1.0);
    out.worldPosition = positions[vertexInBar];
    out.texCoord = float2(float(barIndex) / 128.0, height / 2.0);

    // Color based on frequency (bass = red, mid = green, high = blue)
    float normalizedIndex = float(barIndex) / 128.0;
    out.color = float4(hsv2rgb(float3(normalizedIndex * 0.7, 0.8, height)), 1.0);

    return out;
}

fragment float4 spectrumFragment(VertexOut in [[stage_in]]) {
    return in.color;
}

// MARK: - 3D Waveform Visualization

vertex VertexOut waveformVertex(constant float* waveform [[buffer(0)]],
                               constant Uniforms& uniforms [[buffer(1)]],
                               uint vertexID [[vertex_id]]) {
    int sampleIndex = vertexID;
    float x = (float(sampleIndex) / 512.0) * 4.0 - 2.0;
    float y = waveform[sampleIndex] * 2.0;
    float z = 0.0;

    // Create tube-like structure
    float angle = uniforms.time + float(sampleIndex) * 0.1;
    z = sin(angle) * 0.2 * uniforms.audioLevel;

    float3 position = float3(x, y, z);

    VertexOut out;
    float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
    out.position = mvp * float4(position, 1.0);
    out.worldPosition = position;
    out.texCoord = float2(float(sampleIndex) / 512.0, 0.5);

    // Color gradient along waveform
    float hue = float(sampleIndex) / 512.0 + uniforms.time * 0.1;
    out.color = float4(hsv2rgb(float3(hue, 0.7, 1.0)), 1.0);

    return out;
}

// MARK: - Bio-Reactive Visualization (HRV + Coherence)

vertex VertexOut bioReactiveVertex(VertexIn in [[stage_in]],
                                  constant Uniforms& uniforms [[buffer(0)]]) {
    VertexOut out;

    float3 pos = in.position;

    // Morph geometry based on HRV
    float displacement = noise(in.texCoord * 5.0 + uniforms.time * 0.5) * uniforms.hrv * 0.3;
    pos += in.normal * displacement;

    // Coherence affects rotation/animation
    float rotation = uniforms.coherence * uniforms.time;
    float s = sin(rotation);
    float c = cos(rotation);
    float3x3 rotMatrix = float3x3(
        c, 0.0, s,
        0.0, 1.0, 0.0,
        -s, 0.0, c
    );
    pos = rotMatrix * pos;

    // Audio reactivity
    pos *= 1.0 + uniforms.audioLevel * 0.2;

    float4x4 mvp = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix;
    out.position = mvp * float4(pos, 1.0);
    out.worldPosition = (uniforms.modelMatrix * float4(pos, 1.0)).xyz;
    out.normal = normalize((uniforms.normalMatrix * float4(in.normal, 0.0)).xyz);
    out.texCoord = in.texCoord;
    out.color = in.color;

    return out;
}

fragment float4 bioReactiveFragment(VertexOut in [[stage_in]],
                                   constant Uniforms& uniforms [[buffer(0)]],
                                   texture2d<float> noiseTexture [[texture(0)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    // Base color from bio-data
    float hue = uniforms.coherence * 0.5; // High coherence = green/blue
    float saturation = 0.6 + uniforms.hrv * 0.4; // High HRV = more saturated
    float value = 0.7 + uniforms.audioLevel * 0.3;

    float3 baseColor = hsv2rgb(float3(hue, saturation, value));

    // Animated noise texture overlay
    float2 uvAnim = in.texCoord + float2(uniforms.time * 0.1, 0.0);
    float noiseVal = noiseTexture.sample(textureSampler, uvAnim).r;

    // Mix base color with noise
    float3 finalColor = mix(baseColor, baseColor * noiseVal, 0.3);

    // Pulsating effect based on coherence
    float pulse = sin(uniforms.time * 2.0 * uniforms.coherence) * 0.5 + 0.5;
    finalColor += pulse * 0.2 * uniforms.coherence;

    // Simple lighting
    float3 lightDir = normalize(float3(1.0, 1.0, 1.0));
    float diffuse = max(dot(in.normal, lightDir), 0.0);
    finalColor *= 0.5 + diffuse * 0.5;

    return float4(finalColor, 1.0);
}

// MARK: - Post-Processing: Bloom

kernel void bloomThreshold(texture2d<float, access::read> inTexture [[texture(0)]],
                          texture2d<float, access::write> outTexture [[texture(1)]],
                          constant FragmentUniforms& uniforms [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    float4 color = inTexture.read(gid);

    // Calculate luminance
    float luminance = dot(color.rgb, float3(0.2126, 0.7152, 0.0722));

    // Threshold
    if (luminance > uniforms.bloomThreshold) {
        float brightness = luminance - uniforms.bloomThreshold;
        color.rgb *= brightness * uniforms.bloomIntensity;
        outTexture.write(color, gid);
    } else {
        outTexture.write(float4(0.0), gid);
    }
}

kernel void bloomBlur(texture2d<float, access::read> inTexture [[texture(0)]],
                     texture2d<float, access::write> outTexture [[texture(1)]],
                     constant bool& horizontal [[buffer(0)]],
                     uint2 gid [[thread_position_in_grid]]) {
    // Gaussian blur weights (9-tap)
    constant float weights[5] = {0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216};

    float4 result = inTexture.read(gid) * weights[0];

    if (horizontal) {
        for (int i = 1; i < 5; i++) {
            result += inTexture.read(gid + uint2(i, 0)) * weights[i];
            result += inTexture.read(gid - uint2(i, 0)) * weights[i];
        }
    } else {
        for (int i = 1; i < 5; i++) {
            result += inTexture.read(gid + uint2(0, i)) * weights[i];
            result += inTexture.read(gid - uint2(0, i)) * weights[i];
        }
    }

    outTexture.write(result, gid);
}

kernel void bloomComposite(texture2d<float, access::read> sceneTexture [[texture(0)]],
                          texture2d<float, access::read> bloomTexture [[texture(1)]],
                          texture2d<float, access::write> outTexture [[texture(2)]],
                          constant FragmentUniforms& uniforms [[buffer(0)]],
                          uint2 gid [[thread_position_in_grid]]) {
    float4 scene = sceneTexture.read(gid);
    float4 bloom = bloomTexture.read(gid);

    float4 result = scene + bloom * uniforms.bloomIntensity;

    // Tone mapping (Reinhard)
    result.rgb = result.rgb / (result.rgb + float3(1.0));

    // Exposure
    result.rgb *= uniforms.exposure;

    // Saturation
    float luminance = dot(result.rgb, float3(0.2126, 0.7152, 0.0722));
    result.rgb = mix(float3(luminance), result.rgb, uniforms.saturation);

    // Contrast
    result.rgb = (result.rgb - 0.5) * uniforms.contrast + 0.5;

    // Vignette
    float2 uv = float2(gid) / float2(outTexture.get_width(), outTexture.get_height());
    float2 coord = (uv - 0.5) * 2.0;
    float vignette = 1.0 - dot(coord, coord) * uniforms.vignetteStrength;
    result.rgb *= vignette;

    // Clamp
    result = clamp(result, 0.0, 1.0);

    outTexture.write(result, gid);
}

// MARK: - Post-Processing: Motion Blur

kernel void motionBlur(texture2d<float, access::read> currentFrame [[texture(0)]],
                      texture2d<float, access::read> previousFrame [[texture(1)]],
                      texture2d<float, access::write> outTexture [[texture(2)]],
                      constant float& blendFactor [[buffer(0)]],
                      uint2 gid [[thread_position_in_grid]]) {
    float4 current = currentFrame.read(gid);
    float4 previous = previousFrame.read(gid);

    // Blend between current and previous frame
    float4 result = mix(current, previous, blendFactor);

    outTexture.write(result, gid);
}

// MARK: - Depth of Field

kernel void depthOfField(texture2d<float, access::read> colorTexture [[texture(0)]],
                        texture2d<float, access::read> depthTexture [[texture(1)]],
                        texture2d<float, access::write> outTexture [[texture(2)]],
                        constant float& focusDistance [[buffer(0)]],
                        constant float& focusRange [[buffer(1)]],
                        uint2 gid [[thread_position_in_grid]]) {
    float depth = depthTexture.read(gid).r;
    float4 color = colorTexture.read(gid);

    // Calculate blur amount based on distance from focus plane
    float blur = abs(depth - focusDistance) / focusRange;
    blur = clamp(blur, 0.0, 1.0);

    // Simple box blur (in production, use separable Gaussian)
    if (blur > 0.1) {
        int radius = int(blur * 5.0);
        float4 sum = float4(0.0);
        int count = 0;

        for (int y = -radius; y <= radius; y++) {
            for (int x = -radius; x <= radius; x++) {
                uint2 samplePos = uint2(int2(gid) + int2(x, y));
                sum += colorTexture.read(samplePos);
                count++;
            }
        }

        color = sum / float(count);
    }

    outTexture.write(color, gid);
}

// MARK: - Volumetric Lighting (God Rays)

fragment float4 volumetricLighting(VertexOut in [[stage_in]],
                                  constant Uniforms& uniforms [[buffer(0)]],
                                  texture2d<float> sceneTexture [[texture(0)]],
                                  texture2d<float> depthTexture [[texture(1)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float4 color = sceneTexture.sample(textureSampler, in.texCoord);
    float depth = depthTexture.sample(textureSampler, in.texCoord).r;

    // Light source position (in screen space)
    float2 lightPos = float2(0.5, 0.8);

    // Ray marching from pixel to light
    float2 delta = lightPos - in.texCoord;
    delta *= 1.0 / 50.0; // 50 samples

    float illumination = 0.0;
    float2 samplePos = in.texCoord;

    for (int i = 0; i < 50; i++) {
        float sampleDepth = depthTexture.sample(textureSampler, samplePos).r;
        if (sampleDepth > 0.99) { // Sky/far plane
            illumination += 1.0 / 50.0;
        }
        samplePos += delta;
    }

    // Add volumetric light
    float3 lightColor = float3(1.0, 0.9, 0.7) * uniforms.audioLevel;
    color.rgb += lightColor * illumination * 0.3;

    return color;
}

// MARK: - Physically-Based Rendering (PBR)

struct PBRMaterial {
    float3 albedo;
    float metallic;
    float roughness;
    float ao;
};

float DistributionGGX(float3 N, float3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return num / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return num / denom;
}

float GeometrySmith(float3 N, float3 V, float3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

float3 fresnelSchlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

fragment float4 pbrFragment(VertexOut in [[stage_in]],
                           constant Uniforms& uniforms [[buffer(0)]],
                           constant PBRMaterial& material [[buffer(1)]],
                           texture2d<float> albedoMap [[texture(0)]],
                           texture2d<float> normalMap [[texture(1)]],
                           texture2d<float> metallicRoughnessMap [[texture(2)]]) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    // Sample textures
    float3 albedo = albedoMap.sample(textureSampler, in.texCoord).rgb * material.albedo;
    float2 mr = metallicRoughnessMap.sample(textureSampler, in.texCoord).rg;
    float metallic = mr.r * material.metallic;
    float roughness = mr.g * material.roughness;
    float ao = material.ao;

    // Calculate normal from normal map
    float3 N = normalize(in.normal);

    // View direction
    float3 V = normalize(float3(0.0, 0.0, 10.0) - in.worldPosition);

    // Calculate reflectance at normal incidence
    float3 F0 = float3(0.04);
    F0 = mix(F0, albedo, metallic);

    // Lighting (simplified - single directional light)
    float3 L = normalize(float3(1.0, 1.0, 1.0));
    float3 H = normalize(V + L);
    float3 radiance = float3(1.0) * uniforms.audioLevel;

    // Cook-Torrance BRDF
    float NDF = DistributionGGX(N, H, roughness);
    float G = GeometrySmith(N, V, L, roughness);
    float3 F = fresnelSchlick(max(dot(H, V), 0.0), F0);

    float3 kS = F;
    float3 kD = float3(1.0) - kS;
    kD *= 1.0 - metallic;

    float3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
    float3 specular = numerator / denominator;

    float NdotL = max(dot(N, L), 0.0);
    float3 Lo = (kD * albedo / PI + specular) * radiance * NdotL;

    // Ambient
    float3 ambient = float3(0.03) * albedo * ao;
    float3 color = ambient + Lo;

    // HDR tone mapping
    color = color / (color + float3(1.0));

    // Gamma correction
    color = pow(color, float3(1.0 / 2.2));

    return float4(color, 1.0);
}
