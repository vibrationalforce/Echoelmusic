#pragma once

#include <JuceHeader.h>
#include "SpectralFramework.h"
#include <vector>

/**
 * SpectralReverb - FFT-Based Space Designer
 *
 * Advanced reverb combining spectral processing, convolution, and
 * algorithmic techniques for unique spatial effects.
 *
 * Features:
 * - Spectral decomposition with independent decay per frequency band
 * - Convolution + algorithmic hybrid
 * - Real-time IR morphing
 * - Spectral smearing and freezing
 * - Bio-reactive space morphing
 * - 3D spatial positioning
 * - Infinite reverb mode
 * - Neural space modeling (ML-trained)
 */
class SpectralReverb
{
public:
    enum class ReverbEngine
    {
        Algorithmic,        // Classic Schroeder reverb
        Convolution,        // IR-based
        Spectral,           // FFT-based frequency-dependent decay
        Granular,           // Grain-based reverb synthesis
        Neural,             // ML-trained space modeling
        Hybrid              // Combination of engines
    };

    SpectralReverb();
    ~SpectralReverb() = default;

    void setReverbEngine(ReverbEngine engine);

    // Parameters
    void setPreDelay(float ms);             // 0-500ms
    void setSize(float meters);             // 1-500 meters
    void setDecay(float seconds);           // 0.1-60 seconds
    void setDamping(float amount);          // 0.0-1.0
    void setWidth(float width);             // 0.0-2.0
    void setMix(float mix);                 // 0.0-1.0

    // Spectral
    void setSpectralDecay(const std::vector<float>& decayPerBand);
    void setFreezeEnabled(bool enabled);

    // Convolution
    bool loadImpulseResponse(const juce::File& irFile);
    void setIRMorphPosition(float position); // Morph between IRs

    // Bio-reactive
    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

private:
    ReverbEngine currentEngine = ReverbEngine::Hybrid;
    SpectralFramework spectralEngine;
    juce::AudioBuffer<float> impulseResponse;
    bool freezeEnabled = false;
    bool bioReactiveEnabled = false;
    double currentSampleRate = 48000.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SpectralReverb)
};
