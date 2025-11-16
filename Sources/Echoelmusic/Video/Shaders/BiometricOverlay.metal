#include <metal_stdlib>
using namespace metal;

/// Biometric Overlay Shader
/// Renders real-time biometric data overlays on camera feed
/// Features:
/// - Heart rate pulse effect
/// - HRV coherence glow
/// - EEG wave visualization
/// - Breathing rate indicator
/// - Movement tracking trails

kernel void biometricOverlay(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant float& heartRate [[buffer(0)]],
    constant float& hrvCoherence [[buffer(1)]],
    constant float4& eegWaves [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Read input pixel
    float4 color = input.read(gid);

    // Get normalized coordinates
    float2 size = float2(input.get_width(), input.get_height());
    float2 uv = float2(gid) / size;

    // === HEART RATE PULSE EFFECT ===
    // Create radial pulse from center based on heart rate
    float2 center = float2(0.5, 0.5);
    float dist = length(uv - center);

    // Calculate pulse wave (60-180 BPM range)
    float normalizedHR = heartRate / 120.0;  // Normalize to ~60-180 BPM range
    float pulse = sin(normalizedHR * 6.28318 + dist * 5.0) * 0.5 + 0.5;

    // Apply subtle red pulse overlay
    color.r += pulse * 0.15 * normalizedHR;

    // === HRV COHERENCE GLOW ===
    // Add glow effect that intensifies with higher coherence
    float coherenceGlow = hrvCoherence * 0.003;  // hrvCoherence is 0-100

    // Create vignette effect
    float vignette = 1.0 - smoothstep(0.3, 0.8, dist);

    // Apply cyan/green glow for high coherence
    color.g += coherenceGlow * vignette;
    color.b += coherenceGlow * vignette * 0.8;

    // === EEG WAVE OVERLAY ===
    // Draw EEG waves at bottom 20% of screen
    float waveZone = 0.8;  // Start waves at 80% down the screen

    if (uv.y > waveZone) {
        float waveY = (uv.y - waveZone) / (1.0 - waveZone);  // 0-1 in wave zone
        float xPos = uv.x * 4.0;  // 4 waves across screen

        // Each EEG band gets a section
        int waveIndex = int(xPos);
        float waveValue = 0.0;

        switch (waveIndex) {
            case 0:
                waveValue = eegWaves.x;  // Delta (0.5-4 Hz) - Deep sleep
                color.rgb += float3(1.0, 0.0, 0.0) * 0.3;  // Red tint
                break;
            case 1:
                waveValue = eegWaves.y;  // Theta (4-8 Hz) - Meditation
                color.rgb += float3(1.0, 0.5, 0.0) * 0.3;  // Orange tint
                break;
            case 2:
                waveValue = eegWaves.z;  // Alpha (8-13 Hz) - Relaxed
                color.rgb += float3(0.0, 1.0, 0.0) * 0.3;  // Green tint
                break;
            case 3:
                waveValue = eegWaves.w;  // Beta (13-30 Hz) - Active
                color.rgb += float3(0.0, 0.0, 1.0) * 0.3;  // Blue tint
                break;
        }

        // Draw wave line
        float localX = fract(xPos);  // 0-1 within wave section
        float wave = sin(localX * 6.28318 * 3.0) * waveValue * 0.3 + 0.5;

        // Check if current pixel is on the wave line (with some thickness)
        if (abs(waveY - wave) < 0.05) {
            color = float4(0.0, 1.0, 1.0, 1.0);  // Cyan wave line
        }
    }

    // === BIOMETRIC INFO OVERLAY ===
    // Create subtle info bar at top
    if (uv.y < 0.05) {
        // Heart rate indicator (left side)
        if (uv.x < 0.25) {
            float heartPulse = sin(normalizedHR * 6.28318) * 0.5 + 0.5;
            color.r = mix(color.r, 1.0, heartPulse * 0.5);
        }

        // HRV coherence indicator (center-left)
        if (uv.x >= 0.25 && uv.x < 0.5) {
            float coherenceLevel = hrvCoherence / 100.0;
            if (coherenceLevel < 0.4) {
                color.r = mix(color.r, 1.0, 0.5);  // Red for low
            } else if (coherenceLevel < 0.6) {
                color.r = mix(color.r, 1.0, 0.3);  // Yellow for medium
                color.g = mix(color.g, 1.0, 0.3);
            } else {
                color.g = mix(color.g, 1.0, 0.5);  // Green for high
            }
        }
    }

    // === EDGE GLOW BASED ON COHERENCE ===
    // Add glow to edges when coherence is high
    float edgeDist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    if (edgeDist < 0.02 && hrvCoherence > 60.0) {
        float edgeGlow = (1.0 - edgeDist / 0.02) * ((hrvCoherence - 60.0) / 40.0);
        color.g += edgeGlow * 0.3;
        color.b += edgeGlow * 0.3;
    }

    // Ensure colors stay in valid range
    color = clamp(color, 0.0, 1.0);

    // Write output
    output.write(color, gid);
}

/// Simplified overlay for lower-end devices
kernel void biometricOverlaySimple(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant float& heartRate [[buffer(0)]],
    constant float& hrvCoherence [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float4 color = input.read(gid);

    float2 size = float2(input.get_width(), input.get_height());
    float2 uv = float2(gid) / size;

    // Simple pulse effect
    float pulse = sin(heartRate / 60.0 * 6.28318) * 0.5 + 0.5;
    color.r += pulse * 0.1;

    // Simple coherence glow
    float2 center = float2(0.5, 0.5);
    float dist = length(uv - center);
    float glow = (1.0 - dist) * (hrvCoherence / 100.0) * 0.2;
    color.gb += glow;

    color = clamp(color, 0.0, 1.0);
    output.write(color, gid);
}

/// Particle visualization overlay
kernel void particleOverlay(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    texture2d<float, access::read> particles [[texture(2)]],
    constant float& blend [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float4 camera = input.read(gid);
    float4 particle = particles.read(gid);

    // Alpha blend particles over camera
    float4 color = mix(camera, particle, particle.a * blend);

    output.write(color, gid);
}
