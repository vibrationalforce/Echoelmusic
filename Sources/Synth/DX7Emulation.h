#pragma once

#include <JuceHeader.h>
#include <array>

/**
 * DX7Emulation - Legendary FM Synth
 *
 * Authentic emulation of the Yamaha DX7.
 * 6-operator FM synthesis with 32 algorithms.
 *
 * Features:
 * - 6 operators with 32 classic algorithms
 * - Ratio/fixed frequency modes
 * - 4 envelope generators per operator
 * - LFO with multiple waveforms
 * - 128+ authentic DX7 patches included
 * - Modern enhancements (filters, effects)
 * - Bio-reactive operator modulation
 */
class DX7Emulation : public juce::Synthesiser
{
public:
    static constexpr int numOperators = 6;
    static constexpr int numAlgorithms = 32;

    struct Operator
    {
        float outputLevel = 99.0f;      // 0-99 (DX7 scale)
        float frequencyCoarse = 1.0f;   // 0.5, 1, 2, 3, etc.
        float frequencyFine = 0.0f;     // -99 to +99
        bool fixedFrequency = false;
        float detune = 0.0f;            // -7 to +7

        // Envelope (DX7-style)
        struct DX7Envelope
        {
            std::array<int, 4> rates = {99, 99, 99, 99};    // 0-99
            std::array<int, 4> levels = {99, 99, 99, 0};    // 0-99
        };
        DX7Envelope envelope;

        float velocitySensitivity = 0.0f;
        float keyScaling = 0.0f;
    };

    DX7Emulation();
    ~DX7Emulation() override = default;

    std::array<Operator, numOperators>& getOperators() { return operators; }

    void setAlgorithm(int algorithmNumber);  // 1-32
    int getAlgorithm() const { return currentAlgorithm; }

    void loadDX7Patch(const std::string& patchName);
    std::vector<std::string> getAvailablePatches() const;

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

private:
    std::array<Operator, numOperators> operators;
    int currentAlgorithm = 1;
    bool bioReactiveEnabled = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (DX7Emulation)
};
