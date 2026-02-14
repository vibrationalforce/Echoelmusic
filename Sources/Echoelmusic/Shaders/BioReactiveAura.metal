//  BioReactiveAura.metal
//  Echoelmusic - GPU-Accelerated Bio-Reactive Aura Shader
//
//  Metal shader for real-time coherence visualization with < 20ms latency
//  Synchronized to heartbeat, breathing, and HRV coherence
//
//  "Me fail English? That's unpossible!" - Ralph Wiggum, GPU Architect
//
//  Created 2026-02-04
//  Copyright (c) 2026 Echoelmusic. All rights reserved.

#include <metal_stdlib>
using namespace metal;

// SwiftUI Metal shaders ([[stitchable]]) require iOS 17.0+ / macOS 14.0+
// Guard with __has_include to prevent compile errors on unsupported targets
#if __has_include(<SwiftUI/SwiftUI_Metal.h>)
#include <SwiftUI/SwiftUI_Metal.h>
#define SWIFTUI_METAL_AVAILABLE 1
#endif

// MARK: - Constants

constant float PI = 3.14159265359;
constant float TAU = 6.28318530718;

// Coherence level thresholds
constant float COHERENCE_LOW = 0.4;
constant float COHERENCE_HIGH = 0.6;

// MARK: - Color Utilities

/// Convert HSV to RGB for dynamic color generation
float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

/// Smooth step with configurable edge
float smootherstep(float edge0, float edge1, float x) {
    x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

// MARK: - Noise Functions

/// Simple hash function for noise generation
float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

/// 2D Perlin-style noise
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

/// Fractal Brownian Motion for organic textures
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

// MARK: - SwiftUI Stitchable Shaders (iOS 17.0+ only)

#if defined(SWIFTUI_METAL_AVAILABLE)

// MARK: - Bio-Reactive Aura Shader

/// Main aura shader - creates pulsing glow synchronized to biometrics
///
/// Parameters:
/// - position: Current pixel position
/// - args: [time, coherence, heartRate, breathPhase, confidence, glowRadius]
[[stitchable]] half4 bioReactiveAura(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float coherence,      // 0-1 coherence level
    float heartRate,      // BPM (60-180)
    float breathPhase,    // 0-1 breathing cycle
    float confidence,     // 0-1 prediction confidence
    float glowRadius      // Glow radius in pixels
) {
    // Normalized coordinates
    float2 uv = position / size;
    float2 center = float2(0.5, 0.5);
    float2 toCenter = uv - center;
    float dist = length(toCenter);
    float angle = atan2(toCenter.y, toCenter.x);

    // === HEARTBEAT PULSE ===
    // Convert BPM to pulse frequency
    float heartFreq = heartRate / 60.0;  // Beats per second
    float heartPulse = sin(time * heartFreq * TAU) * 0.5 + 0.5;
    heartPulse = pow(heartPulse, 3.0);  // Sharper pulse like real heartbeat

    // === BREATHING WAVE ===
    // Smooth breathing modulation
    float breathWave = sin(breathPhase * TAU) * 0.5 + 0.5;
    breathWave = smootherstep(0.0, 1.0, breathWave);

    // === COHERENCE-BASED COLOR ===
    float3 auraColor;
    if (coherence < COHERENCE_LOW) {
        // Low coherence: Orange to Red (stress)
        float t = coherence / COHERENCE_LOW;
        auraColor = mix(float3(1.0, 0.3, 0.1), float3(1.0, 0.5, 0.2), t);
    } else if (coherence < COHERENCE_HIGH) {
        // Medium coherence: Yellow to Cyan (transition)
        float t = (coherence - COHERENCE_LOW) / (COHERENCE_HIGH - COHERENCE_LOW);
        auraColor = mix(float3(1.0, 0.8, 0.2), float3(0.2, 0.8, 1.0), t);
    } else {
        // High coherence: Cyan to Green (flow state)
        float t = (coherence - COHERENCE_HIGH) / (1.0 - COHERENCE_HIGH);
        auraColor = mix(float3(0.2, 0.8, 1.0), float3(0.2, 1.0, 0.5), t);
    }

    // === CONFIDENCE SHIMMER ===
    // Higher confidence = more stable, lower = more shimmer
    float shimmer = fbm(uv * 10.0 + time * 0.5, 4);
    float shimmerAmount = (1.0 - confidence) * 0.3;
    auraColor += shimmer * shimmerAmount;

    // === GLOW CALCULATION ===
    // Normalized glow radius
    float normalizedRadius = glowRadius / max(size.x, size.y);

    // Base glow falloff (smooth edge)
    float glowFalloff = 1.0 - smootherstep(0.0, normalizedRadius, dist);

    // Heartbeat modulates glow intensity
    float pulseIntensity = 0.7 + heartPulse * 0.3;

    // Breathing modulates glow radius
    float breathRadius = normalizedRadius * (0.9 + breathWave * 0.2);
    float breathGlow = 1.0 - smootherstep(0.0, breathRadius, dist);

    // Combine glows
    float finalGlow = mix(glowFalloff, breathGlow, 0.5) * pulseIntensity;

    // === EDGE HIGHLIGHT ===
    // Bright edge ring for depth
    float edgeWidth = 0.02;
    float edge = smootherstep(normalizedRadius - edgeWidth, normalizedRadius, dist) *
                 (1.0 - smootherstep(normalizedRadius, normalizedRadius + edgeWidth, dist));
    edge *= 0.5;

    // === ANGULAR VARIATION ===
    // Subtle rotation based on time and coherence
    float rotationSpeed = coherence * 0.5;
    float angularVariation = sin(angle * 6.0 + time * rotationSpeed) * 0.1 + 1.0;
    finalGlow *= angularVariation;

    // === FINAL COMPOSITE ===
    // Sample original layer
    half4 original = layer.sample(position);

    // Create glow color with alpha
    float3 glowColor = auraColor * (finalGlow + edge);
    float glowAlpha = finalGlow * 0.8;

    // Additive blend for glow effect
    half4 result;
    result.rgb = original.rgb + half3(glowColor * glowAlpha);
    result.a = original.a;

    return result;
}

// MARK: - Coherence Ring Shader

/// Creates a pulsing ring that expands with heartbeat
[[stitchable]] half4 coherenceRing(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float coherence,
    float heartRate,
    float ringWidth
) {
    float2 uv = position / size;
    float2 center = float2(0.5, 0.5);
    float dist = length(uv - center);

    // Heartbeat-driven ring expansion
    float heartFreq = heartRate / 60.0;
    float pulse = fract(time * heartFreq);
    float ringRadius = pulse * 0.5;  // Expands from center

    // Ring with smooth falloff
    float ring = smootherstep(ringRadius - ringWidth, ringRadius, dist) *
                 (1.0 - smootherstep(ringRadius, ringRadius + ringWidth, dist));

    // Fade out as ring expands
    ring *= 1.0 - pulse;

    // Coherence-based color
    float3 ringColor;
    if (coherence >= COHERENCE_HIGH) {
        ringColor = float3(0.2, 1.0, 0.5);  // Green
    } else if (coherence >= COHERENCE_LOW) {
        ringColor = float3(1.0, 0.8, 0.2);  // Yellow
    } else {
        ringColor = float3(1.0, 0.4, 0.2);  // Orange
    }

    half4 original = layer.sample(position);
    half4 result;
    result.rgb = original.rgb + half3(ringColor * ring * 0.5);
    result.a = original.a;

    return result;
}

// MARK: - Quantum Field Shader

/// Creates a quantum-inspired field visualization
[[stitchable]] half4 quantumField(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float coherence,
    float entanglement  // 0-1 entanglement level for multiplayer
) {
    float2 uv = position / size;

    // Create quantum interference pattern
    float wave1 = sin(uv.x * 20.0 + time * 2.0) * sin(uv.y * 20.0 + time * 1.5);
    float wave2 = sin(uv.x * 15.0 - time * 1.8) * sin(uv.y * 15.0 - time * 2.2);
    float interference = (wave1 + wave2) * 0.5;

    // Entanglement modulates pattern complexity
    float complexity = 1.0 + entanglement * 2.0;
    interference *= complexity;

    // Coherence affects visibility
    float visibility = coherence * 0.3;

    // Quantum color palette (purple to cyan)
    float3 quantumColor = mix(
        float3(0.6, 0.2, 1.0),  // Purple
        float3(0.2, 0.8, 1.0),  // Cyan
        (interference + 1.0) * 0.5
    );

    half4 original = layer.sample(position);
    half4 result;
    result.rgb = original.rgb + half3(quantumColor * visibility * abs(interference));
    result.a = original.a;

    return result;
}

// MARK: - Breathing Guide Shader

/// Creates a visual breathing guide circle
[[stitchable]] half4 breathingGuide(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float breathPhase,    // 0-0.5 inhale, 0.5-1.0 exhale
    float targetRate      // Target breaths per minute (e.g., 6 for coherence)
) {
    float2 uv = position / size;
    float2 center = float2(0.5, 0.5);
    float dist = length(uv - center);

    // Breathing circle radius
    float minRadius = 0.15;
    float maxRadius = 0.35;

    // Smooth breathing curve
    float breath;
    if (breathPhase < 0.5) {
        // Inhale (expand)
        breath = smootherstep(0.0, 0.5, breathPhase);
    } else {
        // Exhale (contract)
        breath = 1.0 - smootherstep(0.5, 1.0, breathPhase);
    }

    float radius = mix(minRadius, maxRadius, breath);

    // Circle with soft edge
    float circle = smootherstep(radius + 0.02, radius, dist) *
                   (1.0 - smootherstep(radius - 0.02, radius - 0.04, dist));

    // Fill color based on phase
    float3 fillColor;
    if (breathPhase < 0.5) {
        fillColor = float3(0.2, 0.6, 1.0);  // Blue for inhale
    } else {
        fillColor = float3(0.2, 0.8, 0.4);  // Green for exhale
    }

    // Inner fill (semi-transparent)
    float innerFill = 1.0 - smootherstep(0.0, radius - 0.02, dist);
    innerFill *= 0.2;

    half4 original = layer.sample(position);
    half4 result;
    result.rgb = half3(float3(original.rgb) * (1.0 - innerFill) + fillColor * (circle * 0.8 + innerFill));
    result.a = original.a;

    return result;
}

// MARK: - Particle Field Shader

/// Creates floating particles that respond to coherence
[[stitchable]] half4 coherenceParticles(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float time,
    float coherence,
    int particleCount
) {
    float2 uv = position / size;
    float particles = 0.0;

    // Generate particles
    for (int i = 0; i < particleCount; i++) {
        float fi = float(i);

        // Particle position with coherence-based movement
        float speed = 0.1 + coherence * 0.2;
        float2 particlePos = float2(
            fract(hash(float2(fi, 0.0)) + time * speed * hash(float2(fi, 1.0))),
            fract(hash(float2(fi, 2.0)) + time * speed * 0.5 * hash(float2(fi, 3.0)))
        );

        // Particle size varies with coherence
        float particleSize = 0.005 + coherence * 0.01;

        // Distance to particle
        float dist = length(uv - particlePos);

        // Soft particle with glow
        float particle = smootherstep(particleSize, 0.0, dist);
        particles += particle;
    }

    // Clamp and color
    particles = clamp(particles, 0.0, 1.0);

    // Coherence-based particle color
    float3 particleColor = mix(
        float3(1.0, 0.5, 0.2),  // Warm (low coherence)
        float3(0.2, 1.0, 0.8),  // Cool (high coherence)
        coherence
    );

    half4 original = layer.sample(position);
    half4 result;
    result.rgb = original.rgb + half3(particleColor * particles * 0.5);
    result.a = original.a;

    return result;
}

#endif // SWIFTUI_METAL_AVAILABLE
