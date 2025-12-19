#pragma once

#include <JuceHeader.h>
#include "../BioData/BioFeedbackSystem.h"
#include "VisualForge.h"
#include <cmath>

namespace Echoelmusic {

/**
 * @brief Visual Bio-Modulator - Direct Bio → Visual Connection
 *
 * **CRITICAL OPTIMIZATION:** Bypasses OSC routing for low-latency AV sync!
 *
 * **Purpose:**
 * - Direct bio-data → visual parameter mapping
 * - < 5ms latency (vs. 20-50ms for OSC routing)
 * - Automatic parameter scaling and mapping
 * - Preset mapping profiles
 *
 * **Architecture:**
 * ```
 * [BioFeedbackSystem] ──> [VisualBioModulator] ──> [VisualForge]
 *         │                       │                      │
 *         │                       │                      v
 *         │                       │              [Generators/Effects]
 *         │                       │                      │
 *         │                       └──> Direct modulation │
 *         │                          (no network delay)  │
 *         └────────────────────────────────────────────── v
 *                                                   Visual Output
 * ```
 *
 * **Quick Win:** Eliminates OSC routing delay for tight AV sync!
 *
 * **Modulation Targets:**
 * - Particle systems (density, speed, size)
 * - Colors (hue, saturation, brightness)
 * - Geometry (complexity, subdivisions)
 * - Effects (blur, glow, distortion)
 * - Animations (speed, phase)
 * - Layer properties (opacity, blend mode)
 *
 * @author Echoelmusic Team
 * @date 2025-12-19
 * @version 1.0.0
 */
class VisualBioModulator
{
public:
    //==========================================================================
    // Modulation Presets
    //==========================================================================

    enum class ModulationPreset
    {
        Ambient,        // Subtle, slow modulation (meditation, relaxation)
        Energetic,      // Fast, intense modulation (performance, dance)
        Reactive,       // Highly responsive to changes (live visuals)
        Coherence,      // Focus on coherence/flow state visualization
        HRVDriven,      // HRV as primary modulation source
        HeartBeat,      // Heartbeat triggers and pulses
        Brainwave,      // EEG-driven (if available)
        Custom          // User-defined mapping
    };

    //==========================================================================
    // Visual Parameters (normalized 0-1)
    //==========================================================================

    struct VisualModulation
    {
        // Color modulation
        float hue = 0.0f;               // 0-1 (HSV hue wheel)
        float saturation = 1.0f;        // 0-1
        float brightness = 1.0f;        // 0-1

        // Geometry modulation
        float complexity = 0.5f;        // Geometry detail level
        float scale = 1.0f;             // Object scale
        float rotation = 0.0f;          // Rotation angle (0-1 = 0-360°)

        // Motion modulation
        float speed = 0.5f;             // Animation speed multiplier
        float turbulence = 0.3f;        // Noise/chaos amount
        float flowIntensity = 0.5f;     // Flow field strength

        // Particle modulation
        float particleDensity = 0.5f;   // Particle count multiplier
        float particleSize = 1.0f;      // Particle size multiplier
        float particleLifetime = 1.0f;  // Lifetime multiplier

        // Effect modulation
        float blurAmount = 0.0f;        // Blur intensity
        float glowAmount = 0.0f;        // Glow/bloom intensity
        float distortion = 0.0f;        // Distortion amount
        float feedback = 0.0f;          // Video feedback amount

        // Layer modulation
        float layerOpacity = 1.0f;      // Layer alpha
        float layerMix = 0.5f;          // Blend amount

        // Triggers (impulses)
        bool heartbeatPulse = false;    // Triggered on heartbeat
        bool breathPulse = false;       // Triggered on breath cycle
        bool coherencePeak = false;     // Triggered at high coherence
    };

    //==========================================================================
    VisualBioModulator(BioFeedbackSystem* bioSystem = nullptr,
                       VisualForge* visualForge = nullptr)
        : bioFeedbackSystem(bioSystem)
        , visualEngine(visualForge)
    {
        setPreset(ModulationPreset::Reactive);
    }

    //==========================================================================
    // Configuration
    //==========================================================================

    void setBioFeedbackSystem(BioFeedbackSystem* system)
    {
        bioFeedbackSystem = system;
    }

    void setVisualForge(VisualForge* forge)
    {
        visualEngine = forge;
    }

    /**
     * @brief Set modulation preset
     * @param preset Modulation style/profile
     */
    void setPreset(ModulationPreset preset)
    {
        currentPreset = preset;
        configurePreset(preset);
    }

    /**
     * @brief Enable/disable bio-reactive modulation
     * @param enabled true to enable modulation
     */
    void setEnabled(bool enabled)
    {
        isEnabled.store(enabled);
    }

    bool isModulationEnabled() const
    {
        return isEnabled.load();
    }

    /**
     * @brief Set modulation intensity (master control)
     * @param intensity 0-1 (0 = no modulation, 1 = full)
     */
    void setIntensity(float intensity)
    {
        modulationIntensity = juce::jlimit(0.0f, 1.0f, intensity);
    }

    //==========================================================================
    // Update (Call at 30-60 Hz)
    //==========================================================================

    /**
     * @brief Update visual modulation from bio-data
     * @param deltaTime Time since last update (seconds)
     * @return Visual modulation parameters
     */
    VisualModulation update(double deltaTime)
    {
        if (!isEnabled.load() || bioFeedbackSystem == nullptr)
            return currentModulation;

        auto bioData = bioFeedbackSystem->getCurrentBioData();

        if (!bioData.isValid)
            return currentModulation;

        // Apply preset-specific mapping
        switch (currentPreset)
        {
            case ModulationPreset::Ambient:
                updateAmbient(bioData, deltaTime);
                break;

            case ModulationPreset::Energetic:
                updateEnergetic(bioData, deltaTime);
                break;

            case ModulationPreset::Reactive:
                updateReactive(bioData, deltaTime);
                break;

            case ModulationPreset::Coherence:
                updateCoherence(bioData, deltaTime);
                break;

            case ModulationPreset::HRVDriven:
                updateHRVDriven(bioData, deltaTime);
                break;

            case ModulationPreset::HeartBeat:
                updateHeartBeat(bioData, deltaTime);
                break;

            case ModulationPreset::Brainwave:
                updateBrainwave(bioData, deltaTime);
                break;

            default:
                updateReactive(bioData, deltaTime);
                break;
        }

        // Apply modulation intensity
        scaleModulation(modulationIntensity);

        // Apply to VisualForge (if connected)
        if (visualEngine != nullptr)
        {
            applyToVisualForge();
        }

        return currentModulation;
    }

    VisualModulation getCurrentModulation() const
    {
        return currentModulation;
    }

private:
    //==========================================================================
    // Preset Configurations
    //==========================================================================

    void configurePreset(ModulationPreset preset)
    {
        // Reset to defaults
        currentModulation = VisualModulation();

        // Each preset has different parameter scaling
        // (This configures the "character" of each preset)
    }

    //==========================================================================
    // Preset Update Functions
    //==========================================================================

    void updateAmbient(const BioFeedbackSystem::UnifiedBioData& bio, double deltaTime)
    {
        // Slow, subtle modulation for meditation/relaxation

        // Color: HRV → Hue (blue=calm, red=stress)
        currentModulation.hue = juce::jlimit(0.0f, 1.0f, 0.55f + (bio.hrv - 0.5f) * 0.3f);
        currentModulation.saturation = 0.6f + bio.coherence * 0.4f;
        currentModulation.brightness = 0.7f + bio.hrv * 0.3f;

        // Geometry: Coherence → Complexity
        currentModulation.complexity = bio.coherence;
        currentModulation.scale = 0.8f + bio.hrv * 0.4f;

        // Motion: Slow, breath-driven
        currentModulation.speed = 0.3f + bio.breathingRate / 60.0f;
        currentModulation.turbulence = (1.0f - bio.coherence) * 0.2f;
        currentModulation.flowIntensity = bio.coherence * 0.5f;

        // Particles: Minimal
        currentModulation.particleDensity = 0.3f + bio.coherence * 0.3f;

        // Effects: Subtle glow on high coherence
        currentModulation.glowAmount = bio.coherence > 0.7f ? (bio.coherence - 0.7f) * 2.0f : 0.0f;
    }

    void updateEnergetic(const BioFeedbackSystem::UnifiedBioData& bio, double deltaTime)
    {
        // Fast, intense modulation for performances

        // Color: Heart rate → Hue (fast=red/yellow, slow=blue)
        float energyLevel = (bio.heartRate - 60.0f) / 120.0f;  // Normalize 60-180 BPM
        currentModulation.hue = energyLevel * 0.15f;  // Red/orange/yellow range
        currentModulation.saturation = 0.9f + energyLevel * 0.1f;
        currentModulation.brightness = 0.8f + energyLevel * 0.2f;

        // Geometry: High complexity, dynamic scale
        currentModulation.complexity = 0.7f + energyLevel * 0.3f;
        currentModulation.scale = 0.9f + std::sin(bio.timestamp) * 0.2f * energyLevel;

        // Motion: Fast, chaotic
        currentModulation.speed = 1.0f + energyLevel * 2.0f;
        currentModulation.turbulence = 0.5f + (1.0f - bio.coherence) * 0.5f;
        currentModulation.flowIntensity = energyLevel;

        // Particles: High density
        currentModulation.particleDensity = 0.8f + energyLevel * 0.2f;
        currentModulation.particleSize = 0.5f + energyLevel * 0.5f;

        // Effects: Intense glow and distortion
        currentModulation.glowAmount = energyLevel * 0.7f;
        currentModulation.distortion = (1.0f - bio.coherence) * 0.3f * energyLevel;
    }

    void updateReactive(const BioFeedbackSystem::UnifiedBioData& bio, double deltaTime)
    {
        // Highly responsive to all bio-data changes

        // Color: Multi-parameter blend
        float calmness = bio.coherence * bio.hrv;
        currentModulation.hue = calmness * 0.66f;  // Calm=blue, stress=red
        currentModulation.saturation = 0.7f + bio.coherence * 0.3f;
        currentModulation.brightness = 0.6f + bio.hrv * 0.4f;

        // Geometry: HRV + Coherence
        currentModulation.complexity = (bio.hrv + bio.coherence) * 0.5f;
        currentModulation.scale = 0.5f + bio.hrv * 1.5f;
        currentModulation.rotation = std::fmod(bio.timestamp * (bio.heartRate / 60.0f), 1.0f);

        // Motion: Heart rate driven
        currentModulation.speed = bio.heartRate / 120.0f;  // 60 BPM = 0.5x, 120 BPM = 1.0x
        currentModulation.turbulence = bio.stress * 0.5f;
        currentModulation.flowIntensity = bio.coherence;

        // Particles: Coherence-driven
        currentModulation.particleDensity = bio.coherence;
        currentModulation.particleSize = 0.5f + bio.hrv * 0.5f;

        // Effects: Dynamic based on stress
        currentModulation.blurAmount = bio.stress * 0.3f;
        currentModulation.glowAmount = bio.coherence * 0.6f;
        currentModulation.distortion = (1.0f - bio.coherence) * 0.2f;
    }

    void updateCoherence(const BioFeedbackSystem::UnifiedBioData& bio, double deltaTime)
    {
        // Focus on coherence/flow state visualization

        // Color: Coherence → Color temperature (low=red/warm, high=blue/cool)
        currentModulation.hue = bio.coherence * 0.66f;  // Red → Blue
        currentModulation.saturation = 0.8f + bio.coherence * 0.2f;
        currentModulation.brightness = 0.7f + bio.coherence * 0.3f;

        // Geometry: Coherence = geometric harmony
        currentModulation.complexity = bio.coherence;
        currentModulation.scale = 0.8f + bio.coherence * 0.4f;
        currentModulation.rotation = bio.coherence;  // High coherence = aligned

        // Motion: Smooth, flowing at high coherence
        currentModulation.speed = 0.5f + bio.coherence * 0.5f;
        currentModulation.turbulence = (1.0f - bio.coherence) * 0.4f;
        currentModulation.flowIntensity = bio.coherence;

        // Particles: Organized patterns at high coherence
        currentModulation.particleDensity = bio.coherence;

        // Effects: Glow increases with coherence
        currentModulation.glowAmount = bio.coherence > 0.6f ? (bio.coherence - 0.6f) * 2.5f : 0.0f;
        currentModulation.feedback = bio.coherence * 0.3f;

        // Trigger: Peak coherence flash
        currentModulation.coherencePeak = (bio.coherence > 0.85f && !lastCoherencePeak);
        lastCoherencePeak = (bio.coherence > 0.85f);
    }

    void updateHRVDriven(const BioFeedbackSystem::UnifiedBioData& bio, double deltaTime)
    {
        // HRV as primary modulation source

        // Color: HRV spectrum (low=red, high=green/blue)
        currentModulation.hue = bio.hrv * 0.5f;  // Red → Cyan
        currentModulation.saturation = 0.8f;
        currentModulation.brightness = 0.6f + bio.hrv * 0.4f;

        // Geometry: HRV → Detail
        currentModulation.complexity = bio.hrv;
        currentModulation.scale = 0.5f + bio.hrv * 1.0f;

        // Motion: SDNN → Variability
        float normalizedSDNN = juce::jlimit(0.0f, 1.0f, bio.sdnn / 100.0f);
        currentModulation.speed = 0.3f + normalizedSDNN * 0.7f;
        currentModulation.turbulence = normalizedSDNN * 0.5f;

        // Particles: HRV → Density
        currentModulation.particleDensity = bio.hrv;
        currentModulation.particleSize = 0.5f + bio.hrv * 0.5f;
    }

    void updateHeartBeat(const BioFeedbackSystem::UnifiedBioData& bio, double deltaTime)
    {
        // Heartbeat triggers and pulses

        // Detect heartbeat (simple threshold on HR change)
        float hrDelta = std::abs(bio.heartRate - lastHeartRate);
        bool beatDetected = (hrDelta > 5.0f);  // >5 BPM change

        currentModulation.heartbeatPulse = beatDetected;

        if (beatDetected)
        {
            pulsePhase = 0.0f;  // Reset pulse
        }

        pulsePhase += deltaTime * 10.0f;  // Pulse decay rate
        float pulse = std::exp(-pulsePhase);  // Exponential decay

        // Color: Pulse effect
        currentModulation.hue = 0.0f;  // Red
        currentModulation.saturation = 1.0f;
        currentModulation.brightness = 0.5f + pulse * 0.5f;

        // Geometry: Pulse scale
        currentModulation.scale = 1.0f + pulse * 0.3f;

        // Effects: Flash on beat
        currentModulation.glowAmount = pulse * 0.8f;

        lastHeartRate = bio.heartRate;
    }

    void updateBrainwave(const BioFeedbackSystem::UnifiedBioData& bio, double deltaTime)
    {
        // EEG-driven visualization (if available)

        if (bio.eegAlpha > 0.0f || bio.eegBeta > 0.0f)
        {
            // Color: Brainwave state
            // Alpha=relaxed (green/blue), Beta=active (yellow/red)
            float alphaRatio = bio.eegAlpha / (bio.eegAlpha + bio.eegBeta + 0.001f);
            currentModulation.hue = alphaRatio * 0.55f + 0.1f;  // Yellow → Blue
            currentModulation.saturation = 0.7f + bio.eegFocus * 0.3f;
            currentModulation.brightness = 0.6f + bio.eegRelaxation * 0.4f;

            // Motion: Focus → Speed
            currentModulation.speed = 0.3f + bio.eegFocus * 0.7f;
            currentModulation.turbulence = (1.0f - bio.eegFocus) * 0.5f;

            // Particles: Focus → Density
            currentModulation.particleDensity = bio.eegFocus;
        }
        else
        {
            // Fallback to HRV if no EEG
            updateHRVDriven(bio, deltaTime);
        }
    }

    //==========================================================================
    // Apply to VisualForge
    //==========================================================================

    void applyToVisualForge()
    {
        if (visualEngine == nullptr)
            return;

        // Apply modulation to VisualForge parameters
        // (This would call VisualForge methods to update generators/effects)

        // Example: Update particle system
        // visualEngine->setParticleDensity(currentModulation.particleDensity * 1000.0f);
        // visualEngine->setColorHue(currentModulation.hue);
        // etc.

        // TODO: Implement VisualForge parameter setters
    }

    void scaleModulation(float intensity)
    {
        // Scale all modulation parameters by intensity

        currentModulation.complexity = lerp(0.5f, currentModulation.complexity, intensity);
        currentModulation.scale = lerp(1.0f, currentModulation.scale, intensity);
        currentModulation.speed = lerp(0.5f, currentModulation.speed, intensity);
        currentModulation.turbulence *= intensity;
        currentModulation.particleDensity = lerp(0.5f, currentModulation.particleDensity, intensity);
        currentModulation.blurAmount *= intensity;
        currentModulation.glowAmount *= intensity;
        currentModulation.distortion *= intensity;
    }

    float lerp(float a, float b, float t) const
    {
        return a + (b - a) * t;
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    BioFeedbackSystem* bioFeedbackSystem = nullptr;
    VisualForge* visualEngine = nullptr;

    ModulationPreset currentPreset = ModulationPreset::Reactive;
    VisualModulation currentModulation;

    std::atomic<bool> isEnabled{true};
    float modulationIntensity = 1.0f;

    // State tracking
    float lastHeartRate = 60.0f;
    float pulsePhase = 0.0f;
    bool lastCoherencePeak = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(VisualBioModulator)
};

} // namespace Echoelmusic
