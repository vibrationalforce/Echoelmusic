#pragma once

#include <JuceHeader.h>
#include "../BioData/BioReactiveModulator.h"
#include "BioReactiveOSCBridge.h"

namespace Echoelmusic {

/**
 * @brief Visual Integration API
 *
 * High-level API for integrating Echoelmusic bio-reactive data
 * with visual software (VJ tools, 3D engines, lighting).
 *
 * Designed for:
 * - Bladehouse 3D Visuals
 * - TouchDesigner
 * - Resolume Arena/Avenue
 * - Unity/Unreal Engine
 * - ILDA Laser systems
 * - DMX Lighting
 *
 * Output Protocols:
 * - OSC (default)
 * - MIDI CC (planned)
 * - Spout/Syphon (planned)
 * - NDI (planned)
 */
class VisualIntegrationAPI
{
public:
    //==========================================================================
    // Visual Parameter Output

    /**
     * @brief Normalized visual parameters (0-1 range)
     *
     * All values are normalized for easy mapping in visual software.
     * Use these to drive:
     * - Color (hue, saturation, brightness)
     * - Motion (speed, scale, rotation)
     * - Effects (blur, glow, distortion)
     * - Geometry (particles, shapes, meshes)
     */
    struct VisualParameters
    {
        // Bio-derived (direct from body)
        float energy = 0.5f;        // Heart rate normalized (0=calm, 1=excited)
        float flow = 0.5f;          // Coherence (0=chaotic, 1=flowing)
        float tension = 0.5f;       // Stress (0=relaxed, 1=tense)
        float variability = 0.5f;   // HRV (0=rigid, 1=variable)
        float breath = 0.5f;        // Breathing phase (0-1 cycle)

        // Audio-derived
        float bass = 0.0f;          // Low frequency energy
        float mid = 0.0f;           // Mid frequency energy
        float high = 0.0f;          // High frequency energy
        float loudness = 0.0f;      // Overall level
        float beatPhase = 0.0f;     // 0-1 beat cycle

        // Triggers (impulses)
        bool heartbeat = false;     // True on each heartbeat
        bool breathIn = false;      // True on inhale start
        bool breathOut = false;     // True on exhale start
        bool beat = false;          // True on audio beat

        // Combined/derived
        float intensity = 0.5f;     // energy * loudness * (1-flow)
        float harmony = 0.5f;       // flow * (1-tension)
        float pulse = 0.5f;         // heartbeat-synced oscillation
    };

    //==========================================================================
    // Color Suggestions (based on bio-state)

    struct ColorSuggestion
    {
        float hue = 0.0f;           // 0-1 (red=0, green=0.33, blue=0.66)
        float saturation = 1.0f;    // 0-1
        float brightness = 1.0f;    // 0-1

        // Convert to RGB
        juce::Colour toColour() const
        {
            return juce::Colour::fromHSV(hue, saturation, brightness, 1.0f);
        }
    };

    //==========================================================================
    VisualIntegrationAPI()
    {
        oscBridge = std::make_unique<BioReactiveOSCBridge>();
    }

    //==========================================================================
    // Connection

    bool connect(const juce::String& host = "127.0.0.1", int port = 9000)
    {
        return oscBridge->connect(host, port);
    }

    void disconnect()
    {
        oscBridge->disconnect();
    }

    bool isConnected() const
    {
        return oscBridge->isConnected();
    }

    //==========================================================================
    // Update (call at 30-60 Hz)

    void update(const BioDataInput::BioDataSample& bioData,
                const BioReactiveModulator::ModulatedParameters& modParams)
    {
        // Calculate visual parameters
        currentParams = calculateVisualParams(bioData, modParams);

        // Send via OSC
        sendVisualParams(currentParams);

        // Update triggers
        detectTriggers(bioData);
    }

    //==========================================================================
    // Get current parameters

    VisualParameters getCurrentParams() const
    {
        return currentParams;
    }

    ColorSuggestion getSuggestedColor() const
    {
        return calculateColor(currentParams);
    }

    //==========================================================================
    // Direct OSC send (for custom mappings)

    void sendCustomOSC(const juce::String& address, float value)
    {
        if (oscBridge->isConnected())
        {
            // Direct access to OSC bridge would be needed here
            // For now, log the intent
            DBG("Custom OSC: " << address << " = " << value);
        }
    }

    //==========================================================================
    // Presets for target software

    void configureForBladehouse()
    {
        oscBridge->getConfig().targetPort = 8000;
        oscBridge->getConfig().addressPrefix = "/bladehouse/echoelmusic";
        oscBridge->getConfig().updateRateHz = 60;
    }

    void configureForTouchDesigner()
    {
        oscBridge->configureForTouchDesigner();
    }

    void configureForResolume()
    {
        oscBridge->configureForResolume();
    }

    void configureForUnity()
    {
        oscBridge->getConfig().targetPort = 8050;
        oscBridge->getConfig().addressPrefix = "/unity/bio";
        oscBridge->getConfig().updateRateHz = 60;
    }

    void configureForUnreal()
    {
        oscBridge->getConfig().targetPort = 8060;
        oscBridge->getConfig().addressPrefix = "/unreal/bio";
        oscBridge->getConfig().updateRateHz = 60;
    }

private:
    std::unique_ptr<BioReactiveOSCBridge> oscBridge;
    VisualParameters currentParams;

    // Previous values for trigger detection
    float lastHeartPhase = 0.0f;
    float lastBreathPhase = 0.0f;

    //==========================================================================
    // Calculate visual parameters from bio-data

    VisualParameters calculateVisualParams(
        const BioDataInput::BioDataSample& bio,
        const BioReactiveModulator::ModulatedParameters& mod)
    {
        VisualParameters params;

        // Normalize heart rate (60-180 BPM → 0-1)
        params.energy = juce::jlimit(0.0f, 1.0f, (bio.heartRate - 60.0f) / 120.0f);

        // Direct mappings
        params.flow = bio.coherence;
        params.tension = bio.stressIndex;
        params.variability = bio.hrv;

        // Breathing phase (simplified - would use actual breathing detection)
        float breathCycle = std::fmod(juce::Time::getMillisecondCounterHiRes() / 4000.0f, 1.0f);
        params.breath = breathCycle;

        // Combined parameters
        params.intensity = params.energy * (1.0f - params.flow) * 0.5f + 0.5f;
        params.harmony = params.flow * (1.0f - params.tension);

        // Pulse (synced to heartbeat)
        float heartPhase = std::fmod(juce::Time::getMillisecondCounterHiRes() *
                                     (bio.heartRate / 60000.0f), 1.0f);
        params.pulse = 0.5f + 0.5f * std::sin(heartPhase * juce::MathConstants<float>::twoPi);

        return params;
    }

    //==========================================================================
    // Detect triggers (heartbeat, breath)

    void detectTriggers(const BioDataInput::BioDataSample& bio)
    {
        // Heartbeat detection
        float heartPhase = std::fmod(juce::Time::getMillisecondCounterHiRes() *
                                     (bio.heartRate / 60000.0f), 1.0f);

        currentParams.heartbeat = (heartPhase < lastHeartPhase);
        lastHeartPhase = heartPhase;

        // Breath detection (simplified)
        float breathPhase = std::fmod(juce::Time::getMillisecondCounterHiRes() / 4000.0f, 1.0f);

        currentParams.breathIn = (breathPhase < 0.1f && lastBreathPhase > 0.9f);
        currentParams.breathOut = (breathPhase > 0.45f && breathPhase < 0.55f &&
                                   lastBreathPhase < 0.45f);
        lastBreathPhase = breathPhase;
    }

    //==========================================================================
    // Calculate suggested color based on bio-state

    ColorSuggestion calculateColor(const VisualParameters& params) const
    {
        ColorSuggestion color;

        // Hue: tension (red) → harmony (blue/green)
        // Low tension + high flow = cool colors (blue/green)
        // High tension + low flow = warm colors (red/orange)
        color.hue = 0.6f * params.harmony + 0.0f * (1.0f - params.harmony);

        // Saturation: higher with more energy
        color.saturation = 0.5f + 0.5f * params.energy;

        // Brightness: based on coherence
        color.brightness = 0.5f + 0.5f * params.flow;

        return color;
    }

    //==========================================================================
    // Send visual parameters via OSC

    void sendVisualParams(const VisualParameters& params)
    {
        if (!oscBridge->isConnected())
            return;

        // The actual sending would be implemented via the OSC bridge
        // This is a placeholder for the structure

        // Bio parameters
        // /echoelmusic/visual/energy [float]
        // /echoelmusic/visual/flow [float]
        // /echoelmusic/visual/tension [float]
        // etc.
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(VisualIntegrationAPI)
};

} // namespace Echoelmusic
