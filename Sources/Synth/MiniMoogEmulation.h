#pragma once

#include <JuceHeader.h>

/**
 * MiniMoogEmulation - Classic Subtractive Synth
 *
 * Circuit-accurate emulation of the Minimoog Model D.
 * The legendary mono synthesizer that defined analog synthesis.
 *
 * Features:
 * - 3 oscillators (saw, triangle, square with variable width)
 * - Moog ladder filter (24dB/oct lowpass with self-oscillation)
 * - Oscillator drift simulation (temperature-dependent)
 * - Glide (portamento)
 * - Noise generator (white/pink)
 * - Bio-reactive filter modulation
 * - Polyphonic mode (modern enhancement)
 */
class MiniMoogEmulation : public juce::Synthesiser
{
public:
    struct Oscillator
    {
        enum class Waveform { Saw, Triangle, Square, Pulse };
        Waveform waveform = Waveform::Saw;
        float octave = 0.0f;            // -2, -1, 0, +1, +2
        float detune = 0.0f;            // cents
        float pulseWidth = 0.5f;        // For pulse wave
        float level = 1.0f;
    };

    struct Filter
    {
        float cutoff = 1000.0f;         // Hz
        float resonance = 0.0f;         // 0.0 to 1.0
        float envelopeAmount = 0.5f;    // 0.0 to 1.0
        float keyTrack = 0.3f;          // 0.0 to 1.0
    };

    struct Envelope
    {
        float attack = 0.01f;
        float decay = 0.3f;
        float sustain = 0.7f;
        float release = 0.5f;
    };

    MiniMoogEmulation();
    ~MiniMoogEmulation() override = default;

    std::array<Oscillator, 3>& getOscillators() { return oscillators; }
    Filter& getFilter() { return filter; }
    Envelope& getAmpEnvelope() { return ampEnvelope; }
    Envelope& getFilterEnvelope() { return filterEnvelope; }

    void setGlideTime(float seconds);
    void setOscillatorDrift(float amount);  // Simulate temperature drift
    void setNoiseLevel(float level);

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

private:
    std::array<Oscillator, 3> oscillators;
    Filter filter;
    Envelope ampEnvelope, filterEnvelope;
    float glideTime = 0.0f;
    float driftAmount = 0.02f;
    float noiseLevel = 0.0f;
    bool bioReactiveEnabled = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MiniMoogEmulation)
};
