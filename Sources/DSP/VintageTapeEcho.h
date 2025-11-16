#pragma once

#include <JuceHeader.h>

/**
 * VintageTapeEcho - Space Echo RE-201 Emulation
 *
 * Authentic emulation of the Roland Space Echo RE-201.
 * Classic tape delay with spring reverb.
 *
 * Features:
 * - Authentic tape delay modeling
 * - Variable tape heads (1, 2, 3, 4 combinations)
 * - Spring reverb simulation
 * - Wow & flutter (tape speed variations)
 * - Tape saturation
 * - Feedback control
 * - Repeat rate control
 * - Bio-reactive flutter modulation
 * - Self-oscillation at high feedback
 */
class VintageTapeEcho
{
public:
    struct TapeHead
    {
        bool enabled = false;
        float delayTime = 250.0f;       // ms
    };

    VintageTapeEcho();
    ~VintageTapeEcho() = default;

    // Tape heads (4 heads like RE-201)
    std::array<TapeHead, 4>& getTapeHeads() { return tapeHeads; }

    // Parameters
    void setRepeatRate(float rate);     // Speed of tape motor
    void setFeedback(float amount);     // 0.0 to 1.5 (self-oscillation)
    void setTapeMix(float mix);         // Delay mix
    void setReverbMix(float mix);       // Spring reverb mix

    // Character
    void setWowFlutter(float amount);   // Tape speed variations
    void setSaturation(float amount);   // Tape saturation
    void setAge(float amount);          // Tape degradation

    // Bio-reactive
    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

private:
    std::array<TapeHead, 4> tapeHeads;
    float repeatRate = 1.0f;
    float feedback = 0.5f;
    float tapeMix = 0.5f;
    float reverbMix = 0.3f;
    float wowFlutter = 0.1f;
    float saturation = 0.5f;
    float age = 0.2f;
    bool bioReactiveEnabled = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (VintageTapeEcho)
};
