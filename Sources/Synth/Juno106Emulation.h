#pragma once

#include <JuceHeader.h>

/**
 * Juno106Emulation - Vintage Poly Synth
 *
 * Authentic emulation of the Roland Juno-106.
 * Classic analog poly synth with legendary chorus.
 *
 * Features:
 * - 6-voice polyphony
 * - DCO oscillators (saw, square, sub)
 * - Roland chorus (authentic BBD modeling)
 * - High-pass filter
 * - LFO with triangle/square/random
 * - Arpeggiator
 * - Bio-reactive chorus modulation
 */
class Juno106Emulation : public juce::Synthesiser
{
public:
    struct DCO
    {
        float sawLevel = 0.5f;
        float squareLevel = 0.5f;
        float subLevel = 0.3f;
        float pulseWidth = 0.5f;
        float lfoAmount = 0.0f;
    };

    struct Chorus
    {
        enum class Mode { Off, I, II, Both };
        Mode mode = Mode::Off;
        float rate = 0.5f;              // BBD clock rate
        float depth = 0.5f;
    };

    struct Filter
    {
        float cutoff = 1000.0f;
        float resonance = 0.0f;
        float envelopeAmount = 0.5f;
        float lfoAmount = 0.0f;
        float keyTrack = 0.5f;
    };

    Juno106Emulation();
    ~Juno106Emulation() override = default;

    DCO& getDCO() { return dco; }
    Chorus& getChorus() { return chorus; }
    Filter& getFilter() { return filter; }

    void setArpeggiatorEnabled(bool enabled);
    void setArpeggiatorRate(float rate);

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

private:
    DCO dco;
    Chorus chorus;
    Filter filter;
    bool arpeggiatorEnabled = false;
    bool bioReactiveEnabled = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (Juno106Emulation)
};
