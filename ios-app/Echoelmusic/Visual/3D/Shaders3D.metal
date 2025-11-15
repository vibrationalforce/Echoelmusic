//
//  Shaders3D.metal
//  Echoelmusic
//
//  Metal shaders for 3D rendering, particles, and compute operations.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct Vertex3D {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
};

struct Particle3D {
    float3 position;
    float3 velocity;
    float4 color;
    float size;
    float lifetime;
    float age;
};

struct Material3D {
    float4 albedo;
    float metallic;
    float roughness;
    float3 emission;
    float emissionStrength;
};

struct Uniforms3D {
    float4x4 projectionMatrix;
    float4x4 viewMatrix;
    float3 cameraPosition;
    float time;
};

struct LightData {
    float4 position;
    float4 direction;
    float4 color;
    float intensity;
    float range;
    float spotAngle;
    float spotSoftness;
    int type; // 0: directional, 1: point, 2: spot, 3: ambient
    float3 padding;
};

struct ParticleUpdateParams {
    float deltaTime;
    float3 gravity;
    float damping;
    uint particleCount;
};

struct ParticleRenderParams {
    float size;
    float4 color;
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float2 uv;
};

struct ParticleVertexOut {
    float4 position [[position]];
    float4 color;
    float size [[point_size]];
};

// MARK: - Vertex Shader (3D Meshes)

vertex VertexOut vertex3D(
    const device Vertex3D* vertices [[buffer(0)]],
    constant Uniforms3D& uniforms [[buffer(1)]],
    constant float4x4& modelMatrix [[buffer(2)]],
    uint vid [[vertex_id]]
) {
    Vertex3D in = vertices[vid];

    float4 worldPosition = modelMatrix * float4(in.position, 1.0);
    float4 viewPosition = uniforms.viewMatrix * worldPosition;
    float4 clipPosition = uniforms.projectionMatrix * viewPosition;

    // Transform normal
    float3x3 normalMatrix = float3x3(modelMatrix[0].xyz, modelMatrix[1].xyz, modelMatrix[2].xyz);
    float3 worldNormal = normalize(normalMatrix * in.normal);

    VertexOut out;
    out.position = clipPosition;
    out.worldPosition = worldPosition.xyz;
    out.normal = worldNormal;
    out.uv = in.uv;

    return out;
}

// MARK: - Fragment Shader (3D Meshes with PBR)

float3 fresnelSchlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float distributionGGX(float3 N, float3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float num = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = 3.14159265359 * denom * denom;

    return num / denom;
}

float geometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;

    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return num / denom;
}

float geometrySmith(float3 N, float3 V, float3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = geometrySchlickGGX(NdotV, roughness);
    float ggx1 = geometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

fragment float4 fragment3D(
    VertexOut in [[stage_in]],
    constant Material3D& material [[buffer(0)]],
    constant LightData* lights [[buffer(1)]],
    constant int& lightCount [[buffer(2)]],
    constant Uniforms3D& uniforms [[buffer(3)]]
) {
    float3 N = normalize(in.normal);
    float3 V = normalize(uniforms.cameraPosition - in.worldPosition);

    // Material properties
    float3 albedo = material.albedo.rgb;
    float metallic = material.metallic;
    float roughness = max(material.roughness, 0.04);

    // Calculate reflectance at normal incidence
    float3 F0 = float3(0.04);
    F0 = mix(F0, albedo, metallic);

    // Reflectance equation
    float3 Lo = float3(0.0);

    for (int i = 0; i < lightCount; ++i) {
        LightData light = lights[i];

        float3 L;
        float attenuation = 1.0;

        if (light.type == 0) {
            // Directional light
            L = normalize(-light.direction.xyz);
        } else if (light.type == 1) {
            // Point light
            L = normalize(light.position.xyz - in.worldPosition);
            float distance = length(light.position.xyz - in.worldPosition);
            attenuation = 1.0 / (distance * distance);
            attenuation *= smoothstep(light.range, 0.0, distance);
        } else if (light.type == 2) {
            // Spot light
            L = normalize(light.position.xyz - in.worldPosition);
            float distance = length(light.position.xyz - in.worldPosition);
            attenuation = 1.0 / (distance * distance);

            float theta = dot(L, normalize(-light.direction.xyz));
            float epsilon = cos(radians(light.spotAngle)) - cos(radians(light.spotAngle + light.spotSoftness));
            float intensity = clamp((theta - cos(radians(light.spotAngle + light.spotSoftness))) / epsilon, 0.0, 1.0);
            attenuation *= intensity;
        } else {
            // Ambient light
            Lo += light.color.rgb * light.intensity * albedo;
            continue;
        }

        float3 H = normalize(V + L);
        float3 radiance = light.color.rgb * light.intensity * attenuation;

        // Cook-Torrance BRDF
        float NDF = distributionGGX(N, H, roughness);
        float G = geometrySmith(N, V, L, roughness);
        float3 F = fresnelSchlick(max(dot(H, V), 0.0), F0);

        float3 kS = F;
        float3 kD = float3(1.0) - kS;
        kD *= 1.0 - metallic;

        float3 numerator = NDF * G * F;
        float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
        float3 specular = numerator / denominator;

        float NdotL = max(dot(N, L), 0.0);
        Lo += (kD * albedo / 3.14159265359 + specular) * radiance * NdotL;
    }

    // Add emission
    float3 emission = material.emission * material.emissionStrength;
    float3 color = Lo + emission;

    // Tone mapping
    color = color / (color + float3(1.0));

    // Gamma correction
    color = pow(color, float3(1.0 / 2.2));

    return float4(color, material.albedo.a);
}

// MARK: - Particle Vertex Shader

vertex ParticleVertexOut vertexParticle3D(
    const device Particle3D* particles [[buffer(0)]],
    constant Uniforms3D& uniforms [[buffer(1)]],
    constant ParticleRenderParams& params [[buffer(2)]],
    uint vid [[vertex_id]]
) {
    Particle3D particle = particles[vid];

    float4 worldPosition = float4(particle.position, 1.0);
    float4 viewPosition = uniforms.viewMatrix * worldPosition;
    float4 clipPosition = uniforms.projectionMatrix * viewPosition;

    // Calculate size based on distance (perspective scaling)
    float distance = length(viewPosition.xyz);
    float perspectiveSize = params.size * 100.0 / distance;

    ParticleVertexOut out;
    out.position = clipPosition;
    out.color = particle.color;
    out.size = perspectiveSize;

    return out;
}

// MARK: - Particle Fragment Shader

fragment float4 fragmentParticle3D(
    ParticleVertexOut in [[stage_in]],
    float2 pointCoord [[point_coord]]
) {
    // Create circular particle
    float2 coord = pointCoord * 2.0 - 1.0;
    float dist = length(coord);

    if (dist > 1.0) {
        discard_fragment();
    }

    // Soft edges
    float alpha = 1.0 - smoothstep(0.7, 1.0, dist);

    float4 color = in.color;
    color.a *= alpha;

    return color;
}

// MARK: - Particle Update Compute Shader

kernel void updateParticles3D(
    device Particle3D* particles [[buffer(0)]],
    constant ParticleUpdateParams& params [[buffer(1)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= params.particleCount) {
        return;
    }

    device Particle3D& particle = particles[gid];

    // Update age
    particle.age += params.deltaTime;

    // Apply gravity
    particle.velocity += params.gravity * params.deltaTime;

    // Apply damping
    particle.velocity *= params.damping;

    // Update position
    particle.position += particle.velocity * params.deltaTime;

    // Update alpha based on lifetime
    float lifeRatio = particle.age / particle.lifetime;
    particle.color.a = 1.0 - lifeRatio;
}

// MARK: - Advanced Effects Compute Shaders

kernel void computeNormals(
    device Vertex3D* vertices [[buffer(0)]],
    constant uint* indices [[buffer(1)]],
    constant uint& indexCount [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= indexCount / 3) {
        return;
    }

    uint i0 = indices[gid * 3 + 0];
    uint i1 = indices[gid * 3 + 1];
    uint i2 = indices[gid * 3 + 2];

    float3 v0 = vertices[i0].position;
    float3 v1 = vertices[i1].position;
    float3 v2 = vertices[i2].position;

    float3 edge1 = v1 - v0;
    float3 edge2 = v2 - v0;
    float3 normal = normalize(cross(edge1, edge2));

    // Accumulate normals (will need normalization pass)
    vertices[i0].normal += normal;
    vertices[i1].normal += normal;
    vertices[i2].normal += normal;
}

kernel void normalizeNormals(
    device Vertex3D* vertices [[buffer(0)]],
    constant uint& vertexCount [[buffer(1)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= vertexCount) {
        return;
    }

    vertices[gid].normal = normalize(vertices[gid].normal);
}

// MARK: - Post-Processing Effects

kernel void bloom(
    texture2d<half, access::read> input [[texture(0)]],
    texture2d<half, access::write> output [[texture(1)]],
    constant float& threshold [[buffer(0)]],
    constant float& intensity [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    half4 color = input.read(gid);

    // Extract bright areas
    float luminance = dot(color.rgb, half3(0.299, 0.587, 0.114));

    if (luminance > threshold) {
        half4 bloom = color * half(intensity);
        output.write(color + bloom, gid);
    } else {
        output.write(color, gid);
    }
}

kernel void gaussianBlur(
    texture2d<half, access::read> input [[texture(0)]],
    texture2d<half, access::write> output [[texture(1)]],
    constant float& radius [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    int r = int(radius);
    half4 sum = half4(0.0);
    float weightSum = 0.0;

    for (int y = -r; y <= r; ++y) {
        for (int x = -r; x <= r; ++x) {
            int2 offset = int2(x, y);
            uint2 samplePos = uint2(int2(gid) + offset);

            if (samplePos.x < input.get_width() && samplePos.y < input.get_height()) {
                float distance = length(float2(x, y));
                float weight = exp(-(distance * distance) / (2.0 * radius * radius));

                sum += input.read(samplePos) * half(weight);
                weightSum += weight;
            }
        }
    }

    output.write(sum / half(weightSum), gid);
}

kernel void depthOfField(
    texture2d<half, access::read> colorInput [[texture(0)]],
    texture2d<float, access::read> depthInput [[texture(1)]],
    texture2d<half, access::write> output [[texture(2)]],
    constant float& focalDistance [[buffer(0)]],
    constant float& focalRange [[buffer(1)]],
    constant float& blurAmount [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    float depth = depthInput.read(gid).r;
    float blur = abs(depth - focalDistance) / focalRange;
    blur = clamp(blur, 0.0, 1.0) * blurAmount;

    int radius = int(blur * 5.0);
    half4 sum = half4(0.0);
    float weightSum = 0.0;

    for (int y = -radius; y <= radius; ++y) {
        for (int x = -radius; x <= radius; ++x) {
            uint2 samplePos = uint2(int2(gid) + int2(x, y));

            if (samplePos.x < colorInput.get_width() && samplePos.y < colorInput.get_height()) {
                float distance = length(float2(x, y));
                float weight = exp(-(distance * distance) / (2.0 * blur * blur));

                sum += colorInput.read(samplePos) * half(weight);
                weightSum += weight;
            }
        }
    }

    output.write(sum / half(weightSum), gid);
}

kernel void motionBlur(
    texture2d<half, access::read> currentFrame [[texture(0)]],
    texture2d<half, access::read> previousFrame [[texture(1)]],
    texture2d<half, access::write> output [[texture(2)]],
    constant float& blendFactor [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    half4 current = currentFrame.read(gid);
    half4 previous = previousFrame.read(gid);

    half4 blended = mix(current, previous, half(blendFactor));

    output.write(blended, gid);
}

kernel void ssao(
    texture2d<half, access::read> normalInput [[texture(0)]],
    texture2d<float, access::read> depthInput [[texture(1)]],
    texture2d<half, access::write> output [[texture(2)]],
    constant float4x4& projectionMatrix [[buffer(0)]],
    constant float& radius [[buffer(1)]],
    constant float& bias [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    float3 normal = float3(normalInput.read(gid).rgb);
    float depth = depthInput.read(gid).r;

    // Reconstruct position from depth
    float2 uv = float2(gid) / float2(output.get_width(), output.get_height());
    float4 clipSpace = float4(uv * 2.0 - 1.0, depth, 1.0);

    // Simple SSAO approximation
    float occlusion = 0.0;
    const int sampleCount = 16;

    for (int i = 0; i < sampleCount; ++i) {
        float angle = float(i) * 3.14159265359 * 2.0 / float(sampleCount);
        float2 offset = float2(cos(angle), sin(angle)) * radius;

        uint2 samplePos = uint2(int2(gid) + int2(offset));

        if (samplePos.x < depthInput.get_width() && samplePos.y < depthInput.get_height()) {
            float sampleDepth = depthInput.read(samplePos).r;

            if (sampleDepth >= depth + bias) {
                occlusion += 1.0;
            }
        }
    }

    occlusion = 1.0 - (occlusion / float(sampleCount));

    output.write(half4(half3(occlusion), 1.0), gid);
}
