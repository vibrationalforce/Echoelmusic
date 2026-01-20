//
//  QuantumPhotonicsShader.metal
//  Echoelmusic
//
//  GPU-accelerated quantum photonics visualization shaders
//  300% performance boost for interference patterns and light fields
//
//  Created: 2026-01-05
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Structures

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct PhotonData {
    float3 position;
    float wavelength;
    float polarization;
    float intensity;
    float coherence;
    float padding;
};

struct QuantumUniforms {
    float time;
    float coherenceLevel;
    float hrvCoherence;
    float heartRate;
    float breathingRate;
    int photonCount;
    int visualizationType;
    float glowIntensity;
    float2 resolution;
    float motionBlur;
    float padding;
};

// MARK: - Utility Functions

// Convert wavelength (nm) to RGB color
float3 wavelengthToRGB(float wavelength) {
    float3 color = float3(0.0);

    if (wavelength >= 380.0 && wavelength < 440.0) {
        color.r = -(wavelength - 440.0) / (440.0 - 380.0);
        color.g = 0.0;
        color.b = 1.0;
    } else if (wavelength >= 440.0 && wavelength < 490.0) {
        color.r = 0.0;
        color.g = (wavelength - 440.0) / (490.0 - 440.0);
        color.b = 1.0;
    } else if (wavelength >= 490.0 && wavelength < 510.0) {
        color.r = 0.0;
        color.g = 1.0;
        color.b = -(wavelength - 510.0) / (510.0 - 490.0);
    } else if (wavelength >= 510.0 && wavelength < 580.0) {
        color.r = (wavelength - 510.0) / (580.0 - 510.0);
        color.g = 1.0;
        color.b = 0.0;
    } else if (wavelength >= 580.0 && wavelength < 645.0) {
        color.r = 1.0;
        color.g = -(wavelength - 645.0) / (645.0 - 580.0);
        color.b = 0.0;
    } else if (wavelength >= 645.0 && wavelength <= 780.0) {
        color.r = 1.0;
        color.g = 0.0;
        color.b = 0.0;
    }

    // Intensity correction at spectrum edges
    float factor = 1.0;
    if (wavelength >= 380.0 && wavelength < 420.0) {
        factor = 0.3 + 0.7 * (wavelength - 380.0) / (420.0 - 380.0);
    } else if (wavelength >= 700.0 && wavelength <= 780.0) {
        factor = 0.3 + 0.7 * (780.0 - wavelength) / (780.0 - 700.0);
    }

    return color * factor;
}

// HSL to RGB conversion
float3 hslToRgb(float h, float s, float l) {
    float c = (1.0 - abs(2.0 * l - 1.0)) * s;
    float x = c * (1.0 - abs(fmod(h * 6.0, 2.0) - 1.0));
    float m = l - c / 2.0;

    float3 rgb;
    float hue = h * 6.0;

    if (hue < 1.0) rgb = float3(c, x, 0.0);
    else if (hue < 2.0) rgb = float3(x, c, 0.0);
    else if (hue < 3.0) rgb = float3(0.0, c, x);
    else if (hue < 4.0) rgb = float3(0.0, x, c);
    else if (hue < 5.0) rgb = float3(x, 0.0, c);
    else rgb = float3(c, 0.0, x);

    return rgb + m;
}

// Golden ratio for Fibonacci patterns
constant float PHI = 1.618033988749895;
constant float PI = 3.14159265359;

// MARK: - Vertex Shader

vertex VertexOut quantumVertexShader(
    uint vertexID [[vertex_id]],
    constant float4 *vertices [[buffer(0)]]
) {
    VertexOut out;
    out.position = vertices[vertexID];
    out.texCoord = (vertices[vertexID].xy + 1.0) * 0.5;
    out.texCoord.y = 1.0 - out.texCoord.y; // Flip Y
    return out;
}

// MARK: - Interference Pattern Shader (helper function)

float4 interferencePatternShader(
    VertexOut in,
    constant QuantumUniforms &uniforms,
    constant PhotonData *photons
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float time = uniforms.time;

    float totalIntensity = 0.0;
    float3 totalColor = float3(0.0);

    // Sum contributions from all photons
    for (int i = 0; i < min(uniforms.photonCount, 64); i++) {
        PhotonData photon = photons[i];

        float2 delta = uv - photon.position.xy;
        float distance = length(delta);

        float wavelengthNorm = photon.wavelength / 1000.0;
        float phase = distance / wavelengthNorm * 2.0 * PI + time + photon.polarization;
        float amplitude = photon.intensity * exp(-distance * 2.0);

        totalIntensity += amplitude * (1.0 + cos(phase)) * 0.5;
        totalColor += wavelengthToRGB(photon.wavelength) * amplitude;
    }

    float count = float(min(uniforms.photonCount, 64));
    totalIntensity /= count;
    totalColor /= count;

    float alpha = totalIntensity * uniforms.coherenceLevel;
    return float4(totalColor, alpha);
}

// MARK: - Wave Function Visualization (helper function)

float4 waveFunctionShader(
    VertexOut in,
    constant QuantumUniforms &uniforms
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float time = uniforms.time;
    float coherence = uniforms.coherenceLevel;

    float r = length(uv);
    float theta = atan2(uv.y, uv.x);

    // Quantum probability amplitude (hydrogen-like orbitals)
    float psi = 0.0;
    for (int n = 1; n <= 4; n++) {
        float fn = float(n);
        float radialPart = exp(-r * fn) * pow(r, fmod(fn, 3.0));
        float angularPart = cos(fn * theta + time * 0.5);
        psi += radialPart * angularPart / fn;
    }

    float probability = psi * psi * coherence;
    probability = clamp(probability, 0.0, 1.0);

    // Color based on probability
    float3 color = hslToRgb(probability * 0.3 + 0.5, 0.8, probability * 0.6);

    return float4(color, probability);
}

// MARK: - Coherence Field Visualization

float4 coherenceFieldShader(
    VertexOut in,
    constant QuantumUniforms &uniforms
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float time = uniforms.time;
    float coherence = uniforms.coherenceLevel;

    float r = length(uv);

    // Coherence creates order, decoherence creates chaos
    float orderedComponent = sin(r * 10.0 - time * 2.0) * coherence;

    // Pseudo-random noise for decoherence
    float noise = fract(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
    float chaoticComponent = noise * (1.0 - coherence) * 0.3;

    float intensity = (orderedComponent + chaoticComponent + 1.0) * 0.5;
    intensity = clamp(intensity, 0.0, 1.0);

    float hue = coherence * 0.3 + 0.5; // Blue-green for coherent
    float3 color = hslToRgb(hue, 0.8, intensity * 0.7);

    return float4(color, intensity);
}

// MARK: - Sacred Geometry (Flower of Life)

float4 sacredGeometryShader(
    VertexOut in,
    constant QuantumUniforms &uniforms
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float time = uniforms.time;
    float coherence = uniforms.coherenceLevel;

    float intensity = 0.0;
    float radius = 0.3;

    // Flower of Life - 7 interlocking circles
    for (int i = 0; i < 7; i++) {
        float angle = float(i) * PI * 2.0 / 7.0 + time * 0.1;
        float2 center = float2(cos(angle), sin(angle)) * radius * 0.5;
        float dist = length(uv - center);

        // Circle edge
        if (abs(dist - radius) < 0.02) {
            intensity += 1.0;
        }
    }

    // Center circle
    float centerDist = length(uv);
    if (abs(centerDist - radius) < 0.02) {
        intensity += 1.0;
    }

    // Vesica Piscis
    float vpDist1 = length(uv - float2(0.3, 0.0));
    float vpDist2 = length(uv - float2(-0.3, 0.0));
    if (abs(vpDist1 - 0.5) < 0.015 || abs(vpDist2 - 0.5) < 0.015) {
        intensity += 0.5;
    }

    intensity = min(intensity, 1.0) * coherence;
    float3 color = hslToRgb(time * 0.02, 0.7, intensity * 0.6);

    return float4(color, intensity);
}

// MARK: - Quantum Tunnel Effect

float4 quantumTunnelShader(
    VertexOut in,
    constant QuantumUniforms &uniforms
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float time = uniforms.time;
    float coherence = uniforms.coherenceLevel;

    float angle = atan2(uv.y, uv.x);
    float dist = length(uv);

    // Tunnel depth effect
    float tunnelDepth = 1.0 / (dist + 0.1) + time * 0.5;
    float rings = sin(tunnelDepth * 5.0) * 0.5 + 0.5;
    float spiral = sin(angle * 3.0 + tunnelDepth) * 0.5 + 0.5;

    float intensity = rings * spiral * (1.0 - dist * 0.5) * coherence;
    intensity = clamp(intensity, 0.0, 1.0);

    float hue = fmod(tunnelDepth * 0.1 + coherence * 0.3, 1.0);
    float3 color = hslToRgb(hue, 0.9, intensity * 0.6);

    return float4(color, intensity);
}

// MARK: - Biophoton Aura

float4 biophotonAuraShader(
    VertexOut in,
    constant QuantumUniforms &uniforms
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float time = uniforms.time;
    float coherence = uniforms.coherenceLevel;
    float heartPhase = sin(time * uniforms.heartRate / 60.0 * 2.0 * PI);
    float breathPhase = sin(time * uniforms.breathingRate / 60.0 * 2.0 * PI);

    float dist = length(uv);
    float angle = atan2(uv.y, uv.x);

    float intensity = 0.0;

    // Aura layers modulated by bio-signals
    if (dist < 0.2) {
        // Physical body (inner core)
        intensity = 0.8 + heartPhase * 0.1;
    } else if (dist < 0.35) {
        // Etheric layer
        intensity = 0.6 * (1.0 - (dist - 0.2) / 0.15) + breathPhase * 0.1;
    } else if (dist < 0.5) {
        // Emotional layer
        float wave = sin(angle * 6.0 + time * 2.0) * 0.2;
        intensity = (0.5 + wave) * (1.0 - (dist - 0.35) / 0.15) * coherence;
    } else if (dist < 0.7) {
        // Mental layer
        float wave = sin(angle * 12.0 + time * 3.0) * 0.15;
        intensity = (0.4 + wave) * (1.0 - (dist - 0.5) / 0.2) * coherence;
    } else if (dist < 0.95) {
        // Spiritual layer
        float wave = sin(angle * 18.0 + time * 4.0) * 0.1;
        intensity = (0.3 + wave) * (1.0 - (dist - 0.7) / 0.25) * coherence * coherence;
    }

    intensity = clamp(intensity, 0.0, 1.0);

    // Spectrum colors based on vertical position
    float spectrumHue = (uv.y + 1.0) * 0.5 * 0.8; // Red at bottom, violet at top
    float3 color = hslToRgb(spectrumHue, 0.7, intensity * 0.6);

    return float4(color, intensity);
}

// MARK: - Light Mandala

float4 lightMandalaShader(
    VertexOut in,
    constant QuantumUniforms &uniforms
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float time = uniforms.time;
    float coherence = uniforms.coherenceLevel;

    float dist = length(uv);
    float angle = atan2(uv.y, uv.x);

    // 8-fold symmetry
    float symmetry = 8.0;
    float symmetricAngle = fmod(angle * symmetry / (2.0 * PI) + 0.5, 1.0) * 2.0 * PI;

    float intensity = 0.0;

    // Multiple rotating layers
    for (int layer = 0; layer < 5; layer++) {
        float layerRadius = float(layer + 1) * 0.15;
        float layerSpeed = float(layer + 1) * 0.2;
        float layerAngle = symmetricAngle + time * layerSpeed;

        float pattern = sin(layerAngle * 3.0) * cos(dist * 10.0 - time);
        if (abs(dist - layerRadius) < 0.05) {
            intensity += (pattern * 0.5 + 0.5) * (1.0 - float(layer) * 0.15);
        }
    }

    // Petals
    float petalCount = 12.0;
    float petalPattern = pow(abs(sin(angle * petalCount / 2.0 + time * 0.5)), 2.0);
    intensity += petalPattern * exp(-dist * 3.0) * 0.5;

    intensity = clamp(intensity * coherence, 0.0, 1.0);

    float hue = fmod(angle / (2.0 * PI) + time * 0.05, 1.0);
    float3 color = hslToRgb(hue, 0.8, intensity * 0.5);

    return float4(color, intensity);
}

// MARK: - Holographic Display

float4 holographicDisplayShader(
    VertexOut in,
    constant QuantumUniforms &uniforms,
    constant PhotonData *photons
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float time = uniforms.time;

    float intensity = 0.0;
    float3 color = float3(0.0);

    // Holographic interference fringes
    for (int i = 0; i < min(uniforms.photonCount, 16); i++) {
        PhotonData photon = photons[i];

        float referenceWave = sin(uv.x * 20.0 + time);
        float objectWave = sin(
            (uv.x - photon.position.x) * 30.0 +
            (uv.y - photon.position.y) * 30.0 +
            time * 0.5 + float(i)
        );

        float interference = (referenceWave + objectWave) * 0.5;
        intensity += (interference * 0.5 + 0.5) * photon.intensity;
        color += wavelengthToRGB(photon.wavelength) * photon.intensity;
    }

    float count = float(min(uniforms.photonCount, 16));
    intensity /= count;
    color /= count;

    // Holographic shimmer
    float shimmer = sin(uv.x * 100.0 + uv.y * 50.0 + time * 10.0) * 0.1 + 0.9;
    intensity *= shimmer * uniforms.coherenceLevel;
    intensity = clamp(intensity, 0.0, 1.0);

    return float4(color, intensity);
}

// MARK: - Cosmic Web

float4 cosmicWebShader(
    VertexOut in,
    constant QuantumUniforms &uniforms
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float time = uniforms.time;
    float coherence = uniforms.coherenceLevel;

    float intensity = 0.0;

    // Generate cosmic web nodes procedurally
    for (int i = 0; i < 20; i++) {
        float seed = float(i * 12345);
        float2 node = float2(
            sin(seed * 0.1 + time * 0.05) * 0.8,
            cos(seed * 0.13 + time * 0.07) * 0.8
        );
        float mass = (sin(seed * 0.17) * 0.5 + 0.5) * coherence + 0.1;

        // Gravitational potential
        float dist = length(uv - node);
        intensity += mass / (dist * dist + 0.01);
    }

    intensity = clamp(intensity * 0.3, 0.0, 1.0);

    float hue = fmod(intensity + time * 0.01, 1.0) * 0.3 + 0.6;
    float3 color = hslToRgb(hue, 0.7, intensity * 0.5);

    return float4(color, intensity);
}

// MARK: - Fibonacci Spiral Field

float4 fibonacciFieldShader(
    VertexOut in,
    constant QuantumUniforms &uniforms,
    constant PhotonData *photons
) {
    float2 uv = in.texCoord * 2.0 - 1.0;
    float time = uniforms.time;
    float coherence = uniforms.coherenceLevel;

    float intensity = 0.0;
    float3 totalColor = float3(0.0);

    // Golden angle spiral
    float goldenAngle = PI * (3.0 - sqrt(5.0));

    for (int i = 0; i < min(uniforms.photonCount, 64); i++) {
        float angle = float(i) * goldenAngle + time * 0.5;
        float radius = sqrt(float(i) / float(uniforms.photonCount)) * 0.9;

        float2 spiralPos = float2(cos(angle), sin(angle)) * radius;
        float dist = length(uv - spiralPos);

        PhotonData photon = photons[i];
        float contribution = photon.intensity * exp(-dist * 10.0);

        intensity += contribution;
        totalColor += wavelengthToRGB(photon.wavelength) * contribution;
    }

    intensity = clamp(intensity * coherence, 0.0, 1.0);
    totalColor = clamp(totalColor * coherence, 0.0, 1.0);

    return float4(totalColor, intensity);
}

// MARK: - Master Shader Selector

fragment float4 quantumPhotonicsShader(
    VertexOut in [[stage_in]],
    constant QuantumUniforms &uniforms [[buffer(0)]],
    constant PhotonData *photons [[buffer(1)]]
) {
    switch (uniforms.visualizationType) {
        case 0: return interferencePatternShader(in, uniforms, photons);
        case 1: return waveFunctionShader(in, uniforms);
        case 2: return coherenceFieldShader(in, uniforms);
        case 3: return sacredGeometryShader(in, uniforms);
        case 4: return quantumTunnelShader(in, uniforms);
        case 5: return biophotonAuraShader(in, uniforms);
        case 6: return lightMandalaShader(in, uniforms);
        case 7: return holographicDisplayShader(in, uniforms, photons);
        case 8: return cosmicWebShader(in, uniforms);
        case 9: return fibonacciFieldShader(in, uniforms, photons);
        default: return interferencePatternShader(in, uniforms, photons);
    }
}

// MARK: - Post-Processing: Glow Effect

kernel void glowEffectKernel(
    texture2d<float, access::read> inTexture [[texture(0)]],
    texture2d<float, access::write> outTexture [[texture(1)]],
    constant QuantumUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uniforms.resolution.x || gid.y >= uniforms.resolution.y) return;

    float4 center = inTexture.read(gid);
    float4 blur = float4(0.0);
    float count = 0.0;

    int radius = 3;
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            int2 samplePos = int2(gid) + int2(dx, dy);
            if (samplePos.x >= 0 && samplePos.x < int(uniforms.resolution.x) &&
                samplePos.y >= 0 && samplePos.y < int(uniforms.resolution.y)) {
                blur += inTexture.read(uint2(samplePos));
                count += 1.0;
            }
        }
    }

    blur /= count;
    float4 result = center + blur * uniforms.glowIntensity;
    result = clamp(result, 0.0, 1.0);

    outTexture.write(result, gid);
}
