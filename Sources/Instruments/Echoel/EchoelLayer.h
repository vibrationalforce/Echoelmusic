#pragma once

#include <JuceHeader.h>
#include <vector>

/**
 * 🎚️ EchoelLayer - Intelligent Multi-Layering Engine
 *
 * SUPER INTELLIGENCE FEATURES:
 * - AI suggests complementary layers based on current sound
 * - Auto-generates counter-melodies and harmonies
 * - Smart voice allocation (up to 64 layers)
 * - Biometric layer crossfading (coherence controls blend)
 * - ML-based frequency masking prevention
 *
 * LAYER TYPES:
 * - Parallel: All layers play simultaneously
 * - Velocity Switch: Different layers per velocity
 * - Round Robin: Alternates between layers
 * - Random: Chooses random layer each note
 * - Crossfade: Smooth morphing between layers (mod wheel)
 *
 * USE CASES:
 * - Huge synth pads (8+ layers)
 * - Evolving textures
 * - Orchestral ensembles
 * - Film score soundscapes
 *
 * COMPETITORS: Omnisphere, Falcon, Kontakt
 * USP: AI layer suggestions + Smart masking + 64 layers + Biometric morphing
 */
class EchoelLayer
{
public:
    struct Layer {
        std::string name;
        juce::File sampleFile;          // Audio sample OR
        std::string synthPreset;        // Synth preset

        float volume = 1.0f;
        float pan = 0.0f;               // -1.0 to +1.0
        float tuning = 0.0f;            // Cents
        float velocityMin = 0.0f;
        float velocityMax = 1.0f;

        // Layer-specific effects
        float filterCutoff = 20000.0f;
        float filterResonance = 0.0f;
        float reverbAmount = 0.0f;
        float delayAmount = 0.0f;
    };

    enum class LayerMode {
        Parallel,           // All play together
        VelocitySwitch,     // Velocity lanes
        RoundRobin,         // Alternate
        Random,             // Random each time
        KeySwitch,          // MIDI key switches
        Crossfade,          // Mod wheel fades
        BiometricMorph      // Heart rate/coherence morphs
    };

    void addLayer(const Layer& layer);
    void removeLayer(int index);
    void setLayerMode(LayerMode mode);

    // AI Layer Assistant
    struct LayerSuggestion {
        Layer suggestedLayer;
        float confidence;       // 0.0 - 1.0
        std::string reason;     // "Adds warmth in low-mids"
    };

    std::vector<LayerSuggestion> getSuggestedLayers(int count = 3);

    // Smart frequency masking prevention
    void enableAutoEQ(bool enable);     // AI prevents frequency conflicts

    // Biometric morphing
    void enableBiometricMorph(bool enable);
    void setCoherence(float coherence); // Crossfades between layers

    void prepare(double sampleRate, int samplesPerBlock);
    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi);

private:
    std::vector<Layer> layers;
    LayerMode mode = LayerMode::Parallel;
    int roundRobinIndex = 0;

    // ML frequency analyzer
    void analyzeFrequencyConflicts();
    void applySmartEQ();
};
