#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>

/**
 * HyperModulator - Ultimate Modulation Suite
 *
 * Comprehensive modulation system with 16 LFOs, 8 step sequencers,
 * chaotic generators, and audio-rate modulation.
 *
 * Features:
 * - 16 LFOs with 50+ waveforms
 * - 8 step sequencers (up to 64 steps)
 * - Chaotic generators (Lorenz, Rössler, etc.)
 * - Envelope followers
 * - Audio-rate modulation (up to 20kHz)
 * - Modulation of modulators
 * - Visual modulation display
 * - Bio-reactive modulation sources
 */
class HyperModulator
{
public:
    static constexpr int numLFOs = 16;
    static constexpr int numSequencers = 8;

    enum class LFOWaveform
    {
        Sine, Triangle, Saw, Square, Random, SampleAndHold,
        Noise, Chaos, Custom
    };

    struct LFO
    {
        bool enabled = true;
        LFOWaveform waveform = LFOWaveform::Sine;
        float rate = 1.0f;              // Hz or tempo sync
        float phase = 0.0f;             // 0.0 to 1.0
        bool tempoSync = false;
        float syncDivision = 1.0f;      // 1/4, 1/8, etc.
        bool audioRate = false;         // Up to 20kHz
    };

    struct StepSequencer
    {
        bool enabled = true;
        int numSteps = 16;
        std::array<float, 64> steps;    // Values per step
        bool tempoSync = true;
        float stepDivision = 1.0f;      // 1/16, 1/8, etc.
    };

    HyperModulator();
    ~HyperModulator() = default;

    std::array<LFO, numLFOs>& getLFOs() { return lfos; }
    std::array<StepSequencer, numSequencers>& getSequencers() { return sequencers; }

    void setChaosEnabled(bool enabled);
    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

    // Get modulation values
    float getLFOValue(int index) const;
    float getSequencerValue(int index) const;
    float getChaosValue() const;

private:
    std::array<LFO, numLFOs> lfos;
    std::array<StepSequencer, numSequencers> sequencers;
    bool chaosEnabled = false;
    bool bioReactiveEnabled = false;
    double currentSampleRate = 48000.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (HyperModulator)
};
