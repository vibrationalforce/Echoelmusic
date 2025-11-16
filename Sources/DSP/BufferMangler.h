#pragma once

#include <JuceHeader.h>
#include "SpectralFramework.h"
#include <vector>

/**
 * BufferMangler - Extreme Buffer Manipulation
 *
 * Real-time buffer recording with glitch effects, stuttering,
 * slicing, scrambling, and spectral manipulation.
 *
 * Features:
 * - Real-time buffer recording (up to 60 seconds)
 * - Stutter/repeat effects
 * - Buffer slicing & rearrangement
 * - Reverse/scramble
 * - Spectral manipulation
 * - Glitch generation
 * - Beat-synced effects
 * - Bio-reactive buffer control
 * - XY performance pad
 */
class BufferMangler
{
public:
    enum class ManglingMode
    {
        Stutter,            // Repeat buffer sections
        Slice,              // Chop buffer into slices, rearrange
        Scramble,           // Random buffer playback
        Reverse,            // Reverse sections
        Pitch,              // Pitch-shift buffer segments
        Granular,           // Granular buffer processing
        Spectral            // FFT-based mangling
    };

    BufferMangler();
    ~BufferMangler() = default;

    void setManglingMode(ManglingMode mode);
    void setBufferSize(float seconds);      // 1-60 seconds
    void setIntensity(float intensity);     // 0.0-1.0
    void setRandomization(float amount);    // 0.0-1.0

    // Performance controls
    void setXYPosition(float x, float y);   // -1.0 to +1.0

    // Bio-reactive
    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    // Capture
    void startRecording();
    void stopRecording();
    bool isRecording() const { return recording; }

private:
    ManglingMode currentMode = ManglingMode::Stutter;
    juce::AudioBuffer<float> recordBuffer;
    bool recording = false;
    bool bioReactiveEnabled = false;
    SpectralFramework spectralEngine;
    double currentSampleRate = 48000.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (BufferMangler)
};
