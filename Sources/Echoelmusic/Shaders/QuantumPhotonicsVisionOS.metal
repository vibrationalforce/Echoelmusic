//
//  QuantumPhotonicsVisionOS.metal
//  Echoelmusic
//
//  Metal GPU Shader for visionOS Quantum Photonics Visualization
//  High-performance bio-reactive particle rendering
//
//  Created: 2026-01-25
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// MARK: - Uniforms

struct QuantumUniforms {
    float4x4 modelMatrix;
    float4x4 viewProjectionMatrix;
    float3 cameraPosition;
    float time;

    // Bio-reactive parameters
    float heartPulse;        // 0-1, synced to heartbeat
    float coherenceLevel;    // 0-1, HRV coherence
    float breathingPhase;    // 0-1, breathing cycle
    float bioIntensity;      // Overall bio reactivity

    // Quantum parameters
    float quantumCoherence;  // Quantum state coherence
    float entanglementLevel; // Entanglement strength
    float collapseProgress;  // Wave function collapse progress

    // Visual parameters
    float3 coherenceLowColor;
    float3 coherenceMidColor;
    float3 coherenceHighColor;
    float particleSize;
    float glowIntensity;
};

struct ParticleData {
    float3 position;
    float wavelength;
    float intensity;
    float phase;
    float coherence;
    uint particleIndex;
};

// MARK: - Vertex Structures

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 normal;
    float2 texCoord;
    float4 color;
    float pointSize [[point_size]];
    float intensity;
};

// MARK: - Utility Functions

// Golden ratio for Fibonacci spiral
constant float PHI = 1.618033988749895;
constant float GOLDEN_ANGLE = 2.399963229728653; // PI * (3 - sqrt(5))

// Wavelength to RGB color conversion (visible spectrum)
float3 wavelengthToRGB(float wavelength) {
    float3 rgb = float3(0.0);

    if (wavelength >= 380.0 && wavelength < 440.0) {
        rgb.r = -(wavelength - 440.0) / (440.0 - 380.0);
        rgb.b = 1.0;
    } else if (wavelength >= 440.0 && wavelength < 490.0) {
        rgb.g = (wavelength - 440.0) / (490.0 - 440.0);
        rgb.b = 1.0;
    } else if (wavelength >= 490.0 && wavelength < 510.0) {
        rgb.g = 1.0;
        rgb.b = -(wavelength - 510.0) / (510.0 - 490.0);
    } else if (wavelength >= 510.0 && wavelength < 580.0) {
        rgb.r = (wavelength - 510.0) / (580.0 - 510.0);
        rgb.g = 1.0;
    } else if (wavelength >= 580.0 && wavelength < 645.0) {
        rgb.r = 1.0;
        rgb.g = -(wavelength - 645.0) / (645.0 - 580.0);
    } else if (wavelength >= 645.0 && wavelength <= 780.0) {
        rgb.r = 1.0;
    }

    // Intensity factor for edges of visible spectrum
    float factor;
    if (wavelength >= 380.0 && wavelength < 420.0) {
        factor = 0.3 + 0.7 * (wavelength - 380.0) / (420.0 - 380.0);
    } else if (wavelength >= 420.0 && wavelength <= 700.0) {
        factor = 1.0;
    } else if (wavelength > 700.0 && wavelength <= 780.0) {
        factor = 0.3 + 0.7 * (780.0 - wavelength) / (780.0 - 700.0);
    } else {
        factor = 0.0;
    }

    return rgb * factor;
}

// Coherence-based color interpolation
float3 coherenceColor(float coherence, float3 low, float3 mid, float3 high) {
    if (coherence < 0.4) {
        float t = coherence / 0.4;
        return mix(low, mid, t);
    } else {
        float t = (coherence - 0.4) / 0.6;
        return mix(mid, high, t);
    }
}

// Smooth pulse function (cardiac-like)
float cardiacPulse(float phase) {
    float normalizedPhase = fmod(phase, 1.0);
    if (normalizedPhase < 0.15) {
        return sin(normalizedPhase / 0.15 * M_PI_F) * 0.5 + 0.5;
    } else {
        return exp(-(normalizedPhase - 0.15) * 3.0) * 0.3;
    }
}

// Breathing wave function
float breathingWave(float phase) {
    // Inhale: 0-0.3, Hold: 0.3-0.4, Exhale: 0.4-0.7, Rest: 0.7-1.0
    if (phase < 0.3) {
        return phase / 0.3;
    } else if (phase < 0.4) {
        return 1.0;
    } else if (phase < 0.7) {
        return 1.0 - (phase - 0.4) / 0.3;
    } else {
        return 0.0;
    }
}

// Quantum superposition visualization
float3 superpositionColor(float phase, float3 baseColor) {
    float wave1 = sin(phase * 2.0 * M_PI_F);
    float wave2 = sin(phase * 4.0 * M_PI_F + M_PI_F / 4.0);
    float interference = (wave1 + wave2) * 0.5;

    return baseColor * (0.5 + 0.5 * interference);
}

// Fibonacci spiral position
float3 fibonacciPosition(uint index, uint total, float radius, float height) {
    float t = float(index) / float(total);
    float angle = float(index) * GOLDEN_ANGLE;
    float r = sqrt(t) * radius;

    return float3(
        cos(angle) * r,
        sin(t * M_PI_F) * height - height * 0.5,
        sin(angle) * r
    );
}

// MARK: - Quantum Particle Vertex Shader

vertex VertexOut quantumParticleVertex(
    uint vertexID [[vertex_id]],
    constant QuantumUniforms &uniforms [[buffer(0)]],
    constant ParticleData *particles [[buffer(1)]]
) {
    VertexOut out;

    ParticleData particle = particles[vertexID];

    // Calculate base position with Fibonacci spiral arrangement
    float3 basePosition = particle.position;

    // Apply heart-synced pulsing
    float pulseScale = 1.0 + uniforms.heartPulse * 0.2 * uniforms.bioIntensity;

    // Apply breathing modulation
    float breathScale = 1.0 + breathingWave(uniforms.breathingPhase) * 0.15 * uniforms.bioIntensity;

    // Apply quantum coherence effects
    float coherenceScale = 1.0 + (uniforms.quantumCoherence - 0.5) * 0.1;

    // Combine scales
    float totalScale = pulseScale * breathScale * coherenceScale;

    // Apply floating animation
    float floatOffset = sin(uniforms.time * 0.5 + float(particle.particleIndex) * 0.1) * 0.1;
    basePosition.y += floatOffset;

    // Apply orbital motion for higher coherence
    if (uniforms.coherenceLevel > 0.6) {
        float orbitAngle = uniforms.time * 0.2 + float(particle.particleIndex) * GOLDEN_ANGLE;
        float orbitRadius = 0.05 * (uniforms.coherenceLevel - 0.6) / 0.4;
        basePosition.x += cos(orbitAngle) * orbitRadius;
        basePosition.z += sin(orbitAngle) * orbitRadius;
    }

    // Transform position
    float4 worldPosition = uniforms.modelMatrix * float4(basePosition * totalScale, 1.0);
    out.worldPosition = worldPosition.xyz;
    out.position = uniforms.viewProjectionMatrix * worldPosition;

    // Calculate color based on coherence and wavelength
    float3 baseColor = wavelengthToRGB(particle.wavelength);
    float3 cohColor = coherenceColor(
        uniforms.coherenceLevel,
        uniforms.coherenceLowColor,
        uniforms.coherenceMidColor,
        uniforms.coherenceHighColor
    );

    // Blend wavelength color with coherence color
    float3 finalColor = mix(baseColor, cohColor, 0.5);

    // Apply superposition effect during quantum operations
    if (uniforms.collapseProgress > 0.0 && uniforms.collapseProgress < 1.0) {
        finalColor = superpositionColor(particle.phase + uniforms.time, finalColor);
    }

    // Apply entanglement glow
    if (uniforms.entanglementLevel > 0.5) {
        float entanglementGlow = (uniforms.entanglementLevel - 0.5) * 2.0;
        finalColor += float3(0.2, 0.5, 1.0) * entanglementGlow * sin(uniforms.time * 5.0 + particle.phase);
    }

    // Calculate intensity with bio-reactivity
    float intensity = particle.intensity * uniforms.bioIntensity;
    intensity *= (0.7 + 0.3 * cardiacPulse(uniforms.heartPulse));

    out.color = float4(finalColor * intensity, intensity);
    out.intensity = intensity;

    // Point size based on distance and coherence
    float distanceToCamera = distance(out.worldPosition, uniforms.cameraPosition);
    float baseSize = uniforms.particleSize * (1.0 + uniforms.coherenceLevel * 0.5);
    out.pointSize = baseSize / max(distanceToCamera * 0.5, 1.0);

    out.texCoord = float2(0.5);
    out.normal = float3(0, 0, 1);

    return out;
}

// MARK: - Quantum Particle Fragment Shader

fragment float4 quantumParticleFragment(
    VertexOut in [[stage_in]],
    constant QuantumUniforms &uniforms [[buffer(0)]]
) {
    // Calculate distance from center of point sprite
    float2 pointCoord = in.texCoord * 2.0 - 1.0;
    float distFromCenter = length(pointCoord);

    // Discard pixels outside circle
    if (distFromCenter > 1.0) {
        discard_fragment();
    }

    // Create soft glow effect
    float glow = 1.0 - smoothstep(0.0, 1.0, distFromCenter);
    glow = pow(glow, 2.0);

    // Apply quantum coherence shimmer
    float shimmer = sin(uniforms.time * 10.0 + distFromCenter * 5.0) * 0.1 + 0.9;
    shimmer = mix(1.0, shimmer, uniforms.quantumCoherence);

    // Calculate final color with glow
    float3 color = in.color.rgb * glow * shimmer;

    // Add edge glow for high coherence
    if (uniforms.coherenceLevel > 0.7) {
        float edgeGlow = smoothstep(0.7, 1.0, distFromCenter);
        edgeGlow *= (uniforms.coherenceLevel - 0.7) / 0.3;
        color += float3(0.3, 0.8, 1.0) * edgeGlow * uniforms.glowIntensity;
    }

    float alpha = glow * in.color.a;

    return float4(color, alpha);
}

// MARK: - Quantum Field Vertex Shader

vertex VertexOut quantumFieldVertex(
    VertexIn vertexIn [[stage_in]],
    constant QuantumUniforms &uniforms [[buffer(0)]]
) {
    VertexOut out;

    // Apply breathing and pulse deformation to sphere
    float3 position = vertexIn.position;

    // Radial pulse with heart rate
    float pulseAmount = cardiacPulse(uniforms.heartPulse) * 0.1 * uniforms.bioIntensity;
    position *= (1.0 + pulseAmount);

    // Breathing expansion
    float breathAmount = breathingWave(uniforms.breathingPhase) * 0.05 * uniforms.bioIntensity;
    position *= (1.0 + breathAmount);

    // Wave deformation based on coherence
    float wave = sin(vertexIn.position.y * 5.0 + uniforms.time * 2.0) * 0.02;
    wave *= uniforms.coherenceLevel;
    position.x += wave * vertexIn.normal.x;
    position.z += wave * vertexIn.normal.z;

    // Transform
    float4 worldPosition = uniforms.modelMatrix * float4(position, 1.0);
    out.worldPosition = worldPosition.xyz;
    out.position = uniforms.viewProjectionMatrix * worldPosition;

    // Normal transformation
    out.normal = normalize((uniforms.modelMatrix * float4(vertexIn.normal, 0.0)).xyz);

    out.texCoord = vertexIn.texCoord;

    // Calculate color
    float3 baseColor = coherenceColor(
        uniforms.coherenceLevel,
        uniforms.coherenceLowColor,
        uniforms.coherenceMidColor,
        uniforms.coherenceHighColor
    );

    // Apply superposition during collapse
    if (uniforms.collapseProgress > 0.0 && uniforms.collapseProgress < 1.0) {
        baseColor = superpositionColor(
            vertexIn.texCoord.x + vertexIn.texCoord.y + uniforms.time,
            baseColor
        );
    }

    out.color = float4(baseColor, 0.6);
    out.intensity = uniforms.bioIntensity;
    out.pointSize = 1.0;

    return out;
}

// MARK: - Quantum Field Fragment Shader

fragment float4 quantumFieldFragment(
    VertexOut in [[stage_in]],
    constant QuantumUniforms &uniforms [[buffer(0)]]
) {
    // Fresnel effect for edge glow
    float3 viewDir = normalize(uniforms.cameraPosition - in.worldPosition);
    float fresnel = 1.0 - abs(dot(viewDir, in.normal));
    fresnel = pow(fresnel, 3.0);

    // Base color with fresnel
    float3 color = in.color.rgb;
    color += fresnel * float3(0.3, 0.6, 1.0) * uniforms.glowIntensity;

    // Interference pattern
    float pattern = sin(in.texCoord.x * 20.0 + uniforms.time) * sin(in.texCoord.y * 20.0 - uniforms.time);
    pattern = pattern * 0.1 + 0.9;
    pattern = mix(1.0, pattern, uniforms.quantumCoherence);
    color *= pattern;

    // Entanglement pulse
    if (uniforms.entanglementLevel > 0.5) {
        float pulse = sin(uniforms.time * 8.0) * 0.5 + 0.5;
        pulse *= (uniforms.entanglementLevel - 0.5) * 2.0;
        color += float3(0.5, 0.2, 1.0) * pulse * fresnel;
    }

    // Alpha based on fresnel and coherence
    float alpha = in.color.a * (0.3 + fresnel * 0.7);
    alpha *= (0.5 + uniforms.coherenceLevel * 0.5);

    return float4(color, alpha);
}

// MARK: - Sacred Geometry Vertex Shader

vertex VertexOut sacredGeometryVertex(
    VertexIn vertexIn [[stage_in]],
    constant QuantumUniforms &uniforms [[buffer(0)]],
    uint instanceID [[instance_id]]
) {
    VertexOut out;

    // Calculate Flower of Life circle position
    float angle = float(instanceID) * (M_PI_F / 3.0); // 6 circles
    float radius = 1.0;

    float3 offset = float3(0.0);
    if (instanceID > 0) {
        offset = float3(cos(angle) * radius, 0.0, sin(angle) * radius);
    }

    // Apply bio-reactive scaling
    float scale = 1.0 + uniforms.heartPulse * 0.1 * uniforms.bioIntensity;
    scale *= (1.0 + breathingWave(uniforms.breathingPhase) * 0.05);

    // Apply rotation
    float rotationAngle = uniforms.time * 0.1 * uniforms.coherenceLevel;
    float2x2 rotation = float2x2(cos(rotationAngle), -sin(rotationAngle),
                                  sin(rotationAngle), cos(rotationAngle));
    float2 rotatedXZ = rotation * offset.xz;
    offset.x = rotatedXZ.x;
    offset.z = rotatedXZ.y;

    float3 position = vertexIn.position * scale + offset;

    // Transform
    float4 worldPosition = uniforms.modelMatrix * float4(position, 1.0);
    out.worldPosition = worldPosition.xyz;
    out.position = uniforms.viewProjectionMatrix * worldPosition;

    out.normal = normalize((uniforms.modelMatrix * float4(vertexIn.normal, 0.0)).xyz);
    out.texCoord = vertexIn.texCoord;

    // Color based on instance and coherence
    float hue = float(instanceID) / 7.0 + uniforms.time * 0.1;
    float3 baseColor = coherenceColor(
        uniforms.coherenceLevel,
        uniforms.coherenceLowColor,
        uniforms.coherenceMidColor,
        uniforms.coherenceHighColor
    );

    // Add golden ratio color shift
    hue = fmod(hue * PHI, 1.0);
    float3 hueShift = float3(
        sin(hue * 2.0 * M_PI_F) * 0.5 + 0.5,
        sin((hue + 0.333) * 2.0 * M_PI_F) * 0.5 + 0.5,
        sin((hue + 0.666) * 2.0 * M_PI_F) * 0.5 + 0.5
    );

    out.color = float4(mix(baseColor, hueShift, 0.3), 0.5);
    out.intensity = uniforms.bioIntensity;
    out.pointSize = 1.0;

    return out;
}

// MARK: - Post-Processing Glow Shader

struct PostProcessVertex {
    float4 position [[position]];
    float2 texCoord;
};

vertex PostProcessVertex glowVertex(
    uint vertexID [[vertex_id]]
) {
    PostProcessVertex out;

    // Full-screen quad vertices
    float2 positions[4] = {
        float2(-1.0, -1.0),
        float2( 1.0, -1.0),
        float2(-1.0,  1.0),
        float2( 1.0,  1.0)
    };

    float2 texCoords[4] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(1.0, 0.0)
    };

    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.texCoord = texCoords[vertexID];

    return out;
}

fragment float4 glowFragment(
    PostProcessVertex in [[stage_in]],
    texture2d<float> inputTexture [[texture(0)]],
    constant QuantumUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

    float4 color = inputTexture.sample(textureSampler, in.texCoord);

    // Gaussian blur for glow
    float2 texelSize = 1.0 / float2(inputTexture.get_width(), inputTexture.get_height());

    float4 blurred = float4(0.0);
    float weights[5] = { 0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216 };

    for (int i = 0; i < 5; i++) {
        float offset = float(i) * uniforms.glowIntensity;
        blurred += inputTexture.sample(textureSampler, in.texCoord + float2(texelSize.x * offset, 0.0)) * weights[i];
        blurred += inputTexture.sample(textureSampler, in.texCoord - float2(texelSize.x * offset, 0.0)) * weights[i];
        blurred += inputTexture.sample(textureSampler, in.texCoord + float2(0.0, texelSize.y * offset)) * weights[i];
        blurred += inputTexture.sample(textureSampler, in.texCoord - float2(0.0, texelSize.y * offset)) * weights[i];
    }

    // Combine original with glow
    float4 finalColor = color + blurred * uniforms.glowIntensity * uniforms.coherenceLevel;

    // Bio-reactive color grading
    float3 graded = finalColor.rgb;

    // Add subtle pulse effect to overall scene
    float pulse = cardiacPulse(uniforms.heartPulse) * 0.1 * uniforms.bioIntensity;
    graded *= (1.0 + pulse);

    // Coherence-based saturation boost
    float saturation = 1.0 + uniforms.coherenceLevel * 0.3;
    float luminance = dot(graded, float3(0.2126, 0.7152, 0.0722));
    graded = mix(float3(luminance), graded, saturation);

    return float4(graded, finalColor.a);
}

// MARK: - Compute Kernels for Particle Updates

kernel void updateParticlePositions(
    device ParticleData *particles [[buffer(0)]],
    constant QuantumUniforms &uniforms [[buffer(1)]],
    uint id [[thread_position_in_grid]]
) {
    ParticleData particle = particles[id];

    // Update phase
    particle.phase = fmod(particle.phase + 0.01, 1.0);

    // Update coherence based on global coherence
    particle.coherence = mix(particle.coherence, uniforms.coherenceLevel, 0.1);

    // Update intensity with bio-reactivity
    float targetIntensity = 0.5 + uniforms.coherenceLevel * 0.5;
    targetIntensity *= (1.0 + cardiacPulse(uniforms.heartPulse) * 0.2);
    particle.intensity = mix(particle.intensity, targetIntensity, 0.05);

    // Apply quantum collapse effect
    if (uniforms.collapseProgress > 0.0) {
        // Particles converge to center during collapse
        float3 center = float3(0.0);
        particle.position = mix(particle.position, center, uniforms.collapseProgress * 0.1);
    }

    // Apply entanglement effect
    if (uniforms.entanglementLevel > 0.5) {
        // Synchronize phases
        float globalPhase = uniforms.time * 2.0;
        particle.phase = mix(particle.phase, fmod(globalPhase, 1.0), (uniforms.entanglementLevel - 0.5) * 0.2);
    }

    particles[id] = particle;
}

kernel void generateFibonacciParticles(
    device ParticleData *particles [[buffer(0)]],
    constant uint &particleCount [[buffer(1)]],
    constant float &radius [[buffer(2)]],
    constant float &height [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= particleCount) return;

    ParticleData particle;
    particle.particleIndex = id;

    // Fibonacci spiral position
    particle.position = fibonacciPosition(id, particleCount, radius, height);

    // Wavelength based on position (creates rainbow effect)
    float normalizedIndex = float(id) / float(particleCount);
    particle.wavelength = 380.0 + normalizedIndex * 400.0; // 380-780nm visible spectrum

    // Initial values
    particle.intensity = 1.0;
    particle.phase = normalizedIndex;
    particle.coherence = 0.5;

    particles[id] = particle;
}
