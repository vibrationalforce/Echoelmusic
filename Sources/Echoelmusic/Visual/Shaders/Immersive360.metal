#include <metal_stdlib>
using namespace metal;

// MARK: - 360° Equirectangular & Cubemap Shaders
// Echoelmusic - Immersive 360° visual rendering pipeline
// Supports equirectangular projection, cubemap sampling, and bio-reactive overlays

// MARK: - Structs

struct Immersive360VertexIn {
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct Immersive360VertexOut {
    float4 position [[position]];
    float3 worldDirection;
    float2 texCoord;
};

struct Immersive360Uniforms {
    float4x4 viewProjectionMatrix;
    float4x4 inverseViewMatrix;
    float time;
    float coherence;          // HRV coherence 0-1
    float heartRate;          // BPM
    float breathingPhase;     // 0-1
    float audioLevel;         // 0-1
    float2 resolution;
    float fieldOfView;        // Degrees
    float yaw;                // Head tracking rotation (radians)
    float pitch;
    float roll;
    int projectionMode;       // 0=equirect, 1=cubemap, 2=fisheye, 3=stereographic
};

// MARK: - Utility Functions

/// Convert equirectangular UV to 3D direction vector
float3 equirectToDirection(float2 uv) {
    float theta = uv.x * 2.0 * M_PI_F;     // Longitude: 0 to 2π
    float phi = uv.y * M_PI_F;               // Latitude: 0 to π

    return float3(
        sin(phi) * cos(theta),   // X
        cos(phi),                 // Y (up)
        sin(phi) * sin(theta)    // Z
    );
}

/// Convert 3D direction to equirectangular UV
float2 directionToEquirect(float3 dir) {
    float theta = atan2(dir.z, dir.x);
    float phi = acos(clamp(dir.y, -1.0f, 1.0f));

    float u = theta / (2.0 * M_PI_F);
    float v = phi / M_PI_F;

    // Wrap u to [0, 1]
    u = fract(u);

    return float2(u, v);
}

/// Convert 3D direction to fisheye UV (equisolid projection)
float2 directionToFisheye(float3 dir, float fov) {
    float theta = atan2(sqrt(dir.x * dir.x + dir.z * dir.z), dir.y);
    float phi = atan2(dir.z, dir.x);

    float maxAngle = fov * 0.5 * M_PI_F / 180.0;
    float r = theta / maxAngle;

    if (r > 1.0) return float2(-1.0); // Outside FOV

    float u = 0.5 + 0.5 * r * cos(phi);
    float v = 0.5 + 0.5 * r * sin(phi);

    return float2(u, v);
}

/// Convert 3D direction to stereographic UV
float2 directionToStereographic(float3 dir) {
    float d = 1.0 + dir.y;
    if (abs(d) < 0.0001) return float2(0.5);

    float u = 0.5 + dir.x / (2.0 * d);
    float v = 0.5 + dir.z / (2.0 * d);

    return float2(u, v);
}

/// Apply head-tracked rotation to direction vector
float3 rotateDirection(float3 dir, float yaw, float pitch, float roll) {
    // Yaw (around Y axis)
    float cosY = cos(yaw), sinY = sin(yaw);
    float3 d1 = float3(
        dir.x * cosY + dir.z * sinY,
        dir.y,
        -dir.x * sinY + dir.z * cosY
    );

    // Pitch (around X axis)
    float cosP = cos(pitch), sinP = sin(pitch);
    float3 d2 = float3(
        d1.x,
        d1.y * cosP - d1.z * sinP,
        d1.y * sinP + d1.z * cosP
    );

    // Roll (around Z axis)
    float cosR = cos(roll), sinR = sin(roll);
    return float3(
        d2.x * cosR - d2.y * sinR,
        d2.x * sinR + d2.y * cosR,
        d2.z
    );
}

/// Cubemap face selection - returns face index and UV within face
int selectCubemapFace(float3 dir, thread float2& faceUV) {
    float3 absDir = abs(dir);
    int face;
    float ma, sc, tc;

    if (absDir.x >= absDir.y && absDir.x >= absDir.z) {
        face = dir.x > 0 ? 0 : 1;  // +X / -X
        ma = absDir.x;
        sc = dir.x > 0 ? -dir.z : dir.z;
        tc = -dir.y;
    } else if (absDir.y >= absDir.x && absDir.y >= absDir.z) {
        face = dir.y > 0 ? 2 : 3;  // +Y / -Y
        ma = absDir.y;
        sc = dir.x;
        tc = dir.y > 0 ? dir.z : -dir.z;
    } else {
        face = dir.z > 0 ? 4 : 5;  // +Z / -Z
        ma = absDir.z;
        sc = dir.z > 0 ? dir.x : -dir.x;
        tc = -dir.y;
    }

    faceUV = float2(
        0.5 * (sc / ma + 1.0),
        0.5 * (tc / ma + 1.0)
    );

    return face;
}

// MARK: - Bio-Reactive Effects

/// Compute bio-reactive color tint based on coherence and heart rate
float3 bioReactiveColorShift(float3 color, float coherence, float heartRate, float time) {
    // Coherence-based warmth: low coherence = cooler (blue), high = warmer (gold)
    float warmth = coherence;
    float3 coolTint = float3(0.7, 0.8, 1.0);
    float3 warmTint = float3(1.0, 0.95, 0.8);
    float3 tint = mix(coolTint, warmTint, warmth);

    // Subtle pulse synchronized to heart rate
    float pulseRate = heartRate / 60.0;
    float pulse = 1.0 + 0.03 * sin(time * pulseRate * 2.0 * M_PI_F) * coherence;

    return color * tint * pulse;
}

/// Bio-reactive distortion amount (breathing-synced gentle warping)
float bioReactiveWarp(float2 uv, float breathingPhase, float coherence) {
    float breathWave = sin(breathingPhase * 2.0 * M_PI_F);
    float intensity = 0.005 * (1.0 - coherence * 0.7); // Less warp at high coherence
    return breathWave * intensity;
}

// MARK: - Vertex Shaders

/// Fullscreen quad vertex shader for 360° rendering
vertex Immersive360VertexOut immersive360_vertex(
    Immersive360VertexIn in [[stage_in]],
    constant Immersive360Uniforms& uniforms [[buffer(1)]]
) {
    Immersive360VertexOut out;
    out.position = float4(in.position, 1.0);
    out.texCoord = in.texCoord;

    // Compute view direction from screen position
    float2 ndc = in.position.xy;
    float fovRad = uniforms.fieldOfView * M_PI_F / 180.0;
    float aspect = uniforms.resolution.x / uniforms.resolution.y;

    float3 dir = float3(
        ndc.x * tan(fovRad * 0.5) * aspect,
        ndc.y * tan(fovRad * 0.5),
        -1.0
    );

    dir = normalize(dir);

    // Apply head tracking rotation
    dir = rotateDirection(dir, uniforms.yaw, uniforms.pitch, uniforms.roll);

    out.worldDirection = dir;

    return out;
}

// MARK: - Fragment Shaders

/// Equirectangular 360° texture sampling with bio-reactive effects
fragment float4 equirectangular360_fragment(
    Immersive360VertexOut in [[stage_in]],
    constant Immersive360Uniforms& uniforms [[buffer(0)]],
    texture2d<float> equirectTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float3 dir = normalize(in.worldDirection);

    // Apply bio-reactive breathing warp
    float2 equirectUV = directionToEquirect(dir);
    float warp = bioReactiveWarp(equirectUV, uniforms.breathingPhase, uniforms.coherence);
    equirectUV.x += warp;
    equirectUV = fract(equirectUV);

    // Sample equirectangular texture
    float4 color = equirectTexture.sample(textureSampler, equirectUV);

    // Apply bio-reactive color modulation
    color.rgb = bioReactiveColorShift(color.rgb, uniforms.coherence, uniforms.heartRate, uniforms.time);

    // Audio-reactive brightness pulse
    color.rgb *= 1.0 + uniforms.audioLevel * 0.15;

    return color;
}

/// Cubemap 360° texture sampling with bio-reactive effects
fragment float4 cubemap360_fragment(
    Immersive360VertexOut in [[stage_in]],
    constant Immersive360Uniforms& uniforms [[buffer(0)]],
    texturecube<float> cubemapTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float3 dir = normalize(in.worldDirection);

    // Sample cubemap directly
    float4 color = cubemapTexture.sample(textureSampler, dir);

    // Bio-reactive modulation
    color.rgb = bioReactiveColorShift(color.rgb, uniforms.coherence, uniforms.heartRate, uniforms.time);
    color.rgb *= 1.0 + uniforms.audioLevel * 0.15;

    return color;
}

/// Cubemap sampling from 6 individual 2D textures (atlas layout)
fragment float4 cubemapAtlas_fragment(
    Immersive360VertexOut in [[stage_in]],
    constant Immersive360Uniforms& uniforms [[buffer(0)]],
    texture2d<float> faceTexturePosX [[texture(0)]],
    texture2d<float> faceTextureNegX [[texture(1)]],
    texture2d<float> faceTexturePosY [[texture(2)]],
    texture2d<float> faceTextureNegY [[texture(3)]],
    texture2d<float> faceTexturePosZ [[texture(4)]],
    texture2d<float> faceTextureNegZ [[texture(5)]],
    sampler textureSampler [[sampler(0)]]
) {
    float3 dir = normalize(in.worldDirection);
    float2 faceUV;
    int face = selectCubemapFace(dir, faceUV);

    float4 color;
    switch (face) {
        case 0: color = faceTexturePosX.sample(textureSampler, faceUV); break;
        case 1: color = faceTextureNegX.sample(textureSampler, faceUV); break;
        case 2: color = faceTexturePosY.sample(textureSampler, faceUV); break;
        case 3: color = faceTextureNegY.sample(textureSampler, faceUV); break;
        case 4: color = faceTexturePosZ.sample(textureSampler, faceUV); break;
        default: color = faceTextureNegZ.sample(textureSampler, faceUV); break;
    }

    color.rgb = bioReactiveColorShift(color.rgb, uniforms.coherence, uniforms.heartRate, uniforms.time);

    return color;
}

/// Fisheye projection fragment shader
fragment float4 fisheye360_fragment(
    Immersive360VertexOut in [[stage_in]],
    constant Immersive360Uniforms& uniforms [[buffer(0)]],
    texture2d<float> fisheyeTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float3 dir = normalize(in.worldDirection);
    float2 fisheyeUV = directionToFisheye(dir, uniforms.fieldOfView);

    if (fisheyeUV.x < 0) {
        return float4(0, 0, 0, 1); // Outside FOV
    }

    float4 color = fisheyeTexture.sample(textureSampler, fisheyeUV);
    color.rgb = bioReactiveColorShift(color.rgb, uniforms.coherence, uniforms.heartRate, uniforms.time);

    return color;
}

/// Stereographic projection fragment shader
fragment float4 stereographic360_fragment(
    Immersive360VertexOut in [[stage_in]],
    constant Immersive360Uniforms& uniforms [[buffer(0)]],
    texture2d<float> stereoTexture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]
) {
    float3 dir = normalize(in.worldDirection);
    float2 stereoUV = directionToStereographic(dir);

    float4 color = stereoTexture.sample(textureSampler, stereoUV);
    color.rgb = bioReactiveColorShift(color.rgb, uniforms.coherence, uniforms.heartRate, uniforms.time);

    return color;
}

// MARK: - Compute Kernels

/// Equirectangular to cubemap face conversion (offline/bake)
kernel void equirectToCubemap(
    texture2d<float, access::read> equirectTexture [[texture(0)]],
    texture2d<float, access::write> cubeFace [[texture(1)]],
    constant int& faceIndex [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 faceSize = float2(cubeFace.get_width(), cubeFace.get_height());
    float2 uv = (float2(gid) + 0.5) / faceSize;

    // Convert face UV to 3D direction
    float2 ndc = uv * 2.0 - 1.0;
    float3 dir;

    switch (faceIndex) {
        case 0: dir = float3( 1.0, -ndc.y, -ndc.x); break; // +X
        case 1: dir = float3(-1.0, -ndc.y,  ndc.x); break; // -X
        case 2: dir = float3( ndc.x,  1.0,  ndc.y); break; // +Y
        case 3: dir = float3( ndc.x, -1.0, -ndc.y); break; // -Y
        case 4: dir = float3( ndc.x, -ndc.y,  1.0); break; // +Z
        default: dir = float3(-ndc.x, -ndc.y, -1.0); break; // -Z
    }

    dir = normalize(dir);
    float2 equirectUV = directionToEquirect(dir);

    // Read from equirectangular with bilinear sampling
    uint2 texSize = uint2(equirectTexture.get_width(), equirectTexture.get_height());
    float2 texCoord = equirectUV * float2(texSize);
    uint2 readPos = uint2(clamp(texCoord, float2(0), float2(texSize - 1)));

    float4 color = equirectTexture.read(readPos);
    cubeFace.write(color, gid);
}

/// Cubemap to equirectangular conversion (for export/streaming)
kernel void cubemapToEquirect(
    texturecube<float, access::read> cubemap [[texture(0)]],
    texture2d<float, access::write> equirect [[texture(1)]],
    sampler textureSampler [[sampler(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 outSize = float2(equirect.get_width(), equirect.get_height());
    float2 uv = (float2(gid) + 0.5) / outSize;

    float3 dir = equirectToDirection(uv);
    float4 color = cubemap.sample(textureSampler, dir);

    equirect.write(color, gid);
}
