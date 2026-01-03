#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <cmath>

/**
 * PlateReverb - Professional Algorithmic Plate Reverb
 *
 * Emulates classic plate reverb hardware:
 * - Dense, smooth reverb tail
 * - Adjustable plate size and damping
 * - Pre-delay with tempo sync
 * - Modulation for shimmer
 * - Low/High cut filters
 * - Stereo width control
 *
 * Inspired by: EMT 140, Lexicon, Universal Audio
 */

namespace Echoelmusic {
namespace DSP {

//==============================================================================
// Allpass Filter
//==============================================================================

class AllpassFilter
{
public:
    AllpassFilter(int maxDelay = 8192)
    {
        buffer.resize(maxDelay, 0.0f);
    }

    void setDelay(int samples)
    {
        delayLength = std::min(samples, static_cast<int>(buffer.size()) - 1);
    }

    void setFeedback(float fb)
    {
        feedback = juce::jlimit(-0.99f, 0.99f, fb);
    }

    float process(float input)
    {
        float delayed = buffer[readIndex];
        float output = -input + delayed;
        buffer[writeIndex] = input + delayed * feedback;

        writeIndex = (writeIndex + 1) % buffer.size();
        readIndex = (readIndex + 1) % buffer.size();

        return output;
    }

    void clear()
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        readIndex = 0;
        writeIndex = delayLength;
    }

private:
    std::vector<float> buffer;
    int delayLength = 100;
    int readIndex = 0;
    int writeIndex = 100;
    float feedback = 0.5f;
};

//==============================================================================
// Comb Filter with Damping
//==============================================================================

class DampedCombFilter
{
public:
    DampedCombFilter(int maxDelay = 8192)
    {
        buffer.resize(maxDelay, 0.0f);
    }

    void setDelay(int samples)
    {
        delayLength = std::min(samples, static_cast<int>(buffer.size()) - 1);
        writeIndex = (readIndex + delayLength) % buffer.size();
    }

    void setFeedback(float fb)
    {
        feedback = juce::jlimit(0.0f, 0.99f, fb);
    }

    void setDamping(float damp)
    {
        damping = juce::jlimit(0.0f, 1.0f, damp);
    }

    float process(float input)
    {
        float delayed = buffer[readIndex];

        // One-pole lowpass for damping
        filterState = delayed * (1.0f - damping) + filterState * damping;

        buffer[writeIndex] = input + filterState * feedback;

        writeIndex = (writeIndex + 1) % buffer.size();
        readIndex = (readIndex + 1) % buffer.size();

        return delayed;
    }

    void clear()
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        filterState = 0.0f;
    }

private:
    std::vector<float> buffer;
    int delayLength = 1000;
    int readIndex = 0;
    int writeIndex = 1000;
    float feedback = 0.8f;
    float damping = 0.3f;
    float filterState = 0.0f;
};

//==============================================================================
// Plate Reverb
//==============================================================================

class PlateReverb
{
public:
    static constexpr int NumCombs = 8;
    static constexpr int NumAllpasses = 4;

    //==========================================================================
    // Constructor
    //==========================================================================

    PlateReverb()
    {
        for (int i = 0; i < NumCombs; ++i)
            combFilters[i] = std::make_unique<DampedCombFilter>(8192);

        for (int i = 0; i < NumAllpasses; ++i)
            allpassFilters[i] = std::make_unique<AllpassFilter>(4096);

        preDelayBuffer.resize(96000, 0.0f);  // 2 seconds max
    }

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;

        // Prime number delay times for dense reverb (scaled to sample rate)
        const float combDelaysMs[NumCombs] = { 29.7f, 37.1f, 41.1f, 43.7f,
                                                47.9f, 53.3f, 59.3f, 61.9f };

        const float allpassDelaysMs[NumAllpasses] = { 5.0f, 1.7f, 7.3f, 3.1f };

        for (int i = 0; i < NumCombs; ++i)
        {
            int delaySamples = static_cast<int>(combDelaysMs[i] * sampleRate / 1000.0);
            combFilters[i]->setDelay(delaySamples);
        }

        for (int i = 0; i < NumAllpasses; ++i)
        {
            int delaySamples = static_cast<int>(allpassDelaysMs[i] * sampleRate / 1000.0);
            allpassFilters[i]->setDelay(delaySamples);
            allpassFilters[i]->setFeedback(0.5f);
        }

        updateParameters();
        reset();
    }

    void reset()
    {
        for (auto& comb : combFilters)
            comb->clear();
        for (auto& ap : allpassFilters)
            ap->clear();

        std::fill(preDelayBuffer.begin(), preDelayBuffer.end(), 0.0f);
        preDelayReadIndex = 0;
        preDelayWriteIndex = 0;

        lpFilterState = hpFilterState = 0.0f;
        modPhase = 0.0;
    }

    //==========================================================================
    // Parameters
    //==========================================================================

    void setDecay(float decay)
    {
        decayTime = juce::jlimit(0.1f, 10.0f, decay);
        updateParameters();
    }

    void setSize(float size)
    {
        plateSize = juce::jlimit(0.0f, 1.0f, size);
        updateParameters();
    }

    void setDamping(float damp)
    {
        damping = juce::jlimit(0.0f, 1.0f, damp);
        updateParameters();
    }

    void setPreDelay(float ms)
    {
        preDelayMs = juce::jlimit(0.0f, 500.0f, ms);
        int samples = static_cast<int>(preDelayMs * currentSampleRate / 1000.0);
        preDelayWriteIndex = (preDelayReadIndex + samples) % preDelayBuffer.size();
    }

    void setLowCut(float frequency)
    {
        lowCutFreq = juce::jlimit(20.0f, 2000.0f, frequency);
        updateFilters();
    }

    void setHighCut(float frequency)
    {
        highCutFreq = juce::jlimit(1000.0f, 20000.0f, frequency);
        updateFilters();
    }

    void setModulation(float amount)
    {
        modAmount = juce::jlimit(0.0f, 1.0f, amount);
    }

    void setModRate(float hz)
    {
        modRate = juce::jlimit(0.1f, 5.0f, hz);
    }

    void setWidth(float width)
    {
        stereoWidth = juce::jlimit(0.0f, 1.0f, width);
    }

    void setMix(float mix)
    {
        wetMix = juce::jlimit(0.0f, 1.0f, mix);
    }

    //==========================================================================
    // Processing
    //==========================================================================

    void processBlock(juce::AudioBuffer<float>& buffer)
    {
        int numSamples = buffer.getNumSamples();

        // Create mono input from stereo
        std::vector<float> monoInput(numSamples);
        for (int i = 0; i < numSamples; ++i)
        {
            float sum = 0.0f;
            for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
                sum += buffer.getSample(ch, i);
            monoInput[i] = sum / buffer.getNumChannels();
        }

        // Process
        std::vector<float> reverbL(numSamples), reverbR(numSamples);

        for (int i = 0; i < numSamples; ++i)
        {
            auto [left, right] = processSample(monoInput[i]);
            reverbL[i] = left;
            reverbR[i] = right;
        }

        // Mix output
        for (int i = 0; i < numSamples; ++i)
        {
            float dryL = buffer.getSample(0, i);
            float dryR = buffer.getNumChannels() > 1 ? buffer.getSample(1, i) : dryL;

            buffer.setSample(0, i, dryL * (1.0f - wetMix) + reverbL[i] * wetMix);
            if (buffer.getNumChannels() > 1)
                buffer.setSample(1, i, dryR * (1.0f - wetMix) + reverbR[i] * wetMix);
        }
    }

    std::pair<float, float> processSample(float input)
    {
        // Pre-delay
        preDelayBuffer[preDelayWriteIndex] = input;
        float delayed = preDelayBuffer[preDelayReadIndex];
        preDelayWriteIndex = (preDelayWriteIndex + 1) % preDelayBuffer.size();
        preDelayReadIndex = (preDelayReadIndex + 1) % preDelayBuffer.size();

        // Input diffusion (allpass cascade)
        float diffused = delayed;
        for (int i = 0; i < 2; ++i)
            diffused = allpassFilters[i]->process(diffused);

        // Parallel comb filters
        float combSum = 0.0f;
        for (int i = 0; i < NumCombs; ++i)
        {
            // Add modulation to delay time
            float modOffset = modAmount * std::sin(modPhase + i * 0.5) * 0.001f;
            combSum += combFilters[i]->process(diffused);
        }
        combSum /= NumCombs;

        // Output diffusion
        float output = combSum;
        for (int i = 2; i < NumAllpasses; ++i)
            output = allpassFilters[i]->process(output);

        // Filters
        output = applyFilters(output);

        // Update modulation
        modPhase += modRate * 2.0 * juce::MathConstants<double>::pi / currentSampleRate;
        if (modPhase > juce::MathConstants<double>::twoPi)
            modPhase -= juce::MathConstants<double>::twoPi;

        // Stereo spread
        float left = output;
        float right = output;

        if (stereoWidth > 0.0f)
        {
            // Decorrelate channels
            static float decorrelateState = 0.0f;
            decorrelateState = decorrelateState * 0.9f + output * 0.1f;

            left = output + decorrelateState * stereoWidth * 0.3f;
            right = output - decorrelateState * stereoWidth * 0.3f;
        }

        return { left, right };
    }

    //==========================================================================
    // Presets
    //==========================================================================

    enum class Preset
    {
        Small_Plate,
        Medium_Plate,
        Large_Plate,
        Bright_Plate,
        Dark_Plate,
        Shimmer,
        Vintage_EMT,
        Modern_Clean
    };

    void loadPreset(Preset preset)
    {
        switch (preset)
        {
            case Preset::Small_Plate:
                setSize(0.3f);
                setDecay(1.2f);
                setDamping(0.4f);
                setPreDelay(10.0f);
                setHighCut(8000.0f);
                break;

            case Preset::Medium_Plate:
                setSize(0.5f);
                setDecay(2.0f);
                setDamping(0.3f);
                setPreDelay(20.0f);
                setHighCut(10000.0f);
                break;

            case Preset::Large_Plate:
                setSize(0.8f);
                setDecay(3.5f);
                setDamping(0.25f);
                setPreDelay(30.0f);
                setHighCut(12000.0f);
                break;

            case Preset::Bright_Plate:
                setSize(0.6f);
                setDecay(2.5f);
                setDamping(0.1f);
                setPreDelay(15.0f);
                setHighCut(16000.0f);
                setLowCut(200.0f);
                break;

            case Preset::Dark_Plate:
                setSize(0.7f);
                setDecay(3.0f);
                setDamping(0.6f);
                setPreDelay(25.0f);
                setHighCut(4000.0f);
                break;

            case Preset::Shimmer:
                setSize(0.9f);
                setDecay(4.0f);
                setDamping(0.2f);
                setModulation(0.5f);
                setModRate(0.5f);
                setPreDelay(40.0f);
                break;

            case Preset::Vintage_EMT:
                setSize(0.55f);
                setDecay(2.2f);
                setDamping(0.35f);
                setPreDelay(22.0f);
                setHighCut(7500.0f);
                setLowCut(100.0f);
                break;

            case Preset::Modern_Clean:
                setSize(0.5f);
                setDecay(1.8f);
                setDamping(0.2f);
                setPreDelay(15.0f);
                setHighCut(14000.0f);
                setLowCut(80.0f);
                setModulation(0.1f);
                break;
        }
    }

private:
    double currentSampleRate = 48000.0;

    // Parameters
    float decayTime = 2.0f;
    float plateSize = 0.5f;
    float damping = 0.3f;
    float preDelayMs = 20.0f;
    float lowCutFreq = 100.0f;
    float highCutFreq = 10000.0f;
    float modAmount = 0.0f;
    float modRate = 0.5f;
    float stereoWidth = 0.5f;
    float wetMix = 0.3f;

    // Filters
    std::array<std::unique_ptr<DampedCombFilter>, NumCombs> combFilters;
    std::array<std::unique_ptr<AllpassFilter>, NumAllpasses> allpassFilters;

    // Pre-delay
    std::vector<float> preDelayBuffer;
    int preDelayReadIndex = 0;
    int preDelayWriteIndex = 0;

    // Tone filters
    float lpFilterState = 0.0f;
    float hpFilterState = 0.0f;
    float lpCoeff = 0.5f;
    float hpCoeff = 0.01f;

    // Modulation
    double modPhase = 0.0;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateParameters()
    {
        // Calculate feedback from decay time
        float feedback = std::pow(0.001f, 1.0f / (decayTime * static_cast<float>(currentSampleRate) / 1000.0f));
        feedback = juce::jlimit(0.0f, 0.98f, feedback);

        // Scale feedback by plate size
        feedback *= 0.7f + plateSize * 0.28f;

        for (auto& comb : combFilters)
        {
            comb->setFeedback(feedback);
            comb->setDamping(damping);
        }
    }

    void updateFilters()
    {
        lpCoeff = 1.0f - std::exp(-2.0f * juce::MathConstants<float>::pi *
                                   highCutFreq / static_cast<float>(currentSampleRate));
        hpCoeff = std::exp(-2.0f * juce::MathConstants<float>::pi *
                           lowCutFreq / static_cast<float>(currentSampleRate));
    }

    float applyFilters(float input)
    {
        // Low-pass
        lpFilterState += lpCoeff * (input - lpFilterState);

        // High-pass
        hpFilterState = hpCoeff * (hpFilterState + lpFilterState - input);
        float output = lpFilterState - hpFilterState;

        return output;
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PlateReverb)
};

} // namespace DSP
} // namespace Echoelmusic
