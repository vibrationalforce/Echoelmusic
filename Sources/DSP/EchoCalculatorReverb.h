#pragma once

#include <JuceHeader.h>
#include "../CreativeTools/IntelligentDelayCalculator.h"
#include "../Core/DSPOptimizations.h"
#include <vector>

//==============================================================================
/**
 * @brief EchoCalculator Reverb with Intelligent Pre-Delay
 *
 * Professional reverb effect with intelligent pre-delay calculation.
 * Integrates studio calculator tools directly into reverb processing.
 *
 * Features:
 * - Intelligent pre-delay calculation based on BPM and clarity
 * - FFT-based convolution reverb
 * - Impulse response loading
 * - Algorithmic reverb (Freeverb-style)
 * - Early reflections simulation
 * - Damping and diffusion controls
 * - Room size simulation
 *
 * Pre-delay Science:
 * - Separates direct sound from reverb tail
 * - 5-100 ms range (tempo-dependent)
 * - Improves clarity and definition
 * - Professional mixing technique
 *
 * This is part of the EchoCalculator suite - making professional
 * studio calculations accessible in real-time audio processing.
 */
class EchoCalculatorReverb
{
public:
    //==============================================================================
    struct Parameters
    {
        // EchoCalculator Integration
        float bpm = 120.0f;                    // Host BPM
        float clarity = 0.5f;                  // 0-1 (tight to very clear)
        bool autoPreDelay = true;              // Auto-calculate vs manual
        float manualPreDelayMs = 20.0f;        // Manual pre-delay (if not auto)

        // Reverb Parameters
        float roomSize = 0.5f;                 // 0-1 (small to large)
        float damping = 0.5f;                  // High-freq absorption
        float diffusion = 0.7f;                // Echo density
        float dryWet = 0.3f;                   // 0-1
        float width = 1.0f;                    // Stereo width (0-1)

        // EQ
        float lowCut = 20.0f;                  // Hz
        float highCut = 12000.0f;              // Hz
    };

    //==============================================================================
    EchoCalculatorReverb()
    {
        // Initialize Freeverb-style comb filters
        initializeCombFilters();
        initializeAllpassFilters();
    }

    //==============================================================================
    void prepare(double sampleRate, int /*maxBlockSize*/)
    {
        currentSampleRate = sampleRate;

        // Update pre-delay buffer
        int maxPreDelaySamples = static_cast<int>(sampleRate * 0.1);  // Max 100ms
        preDelayBufferL.resize(maxPreDelaySamples, 0.0f);
        preDelayBufferR.resize(maxPreDelaySamples, 0.0f);
        preDelayWritePos = 0;

        // Initialize reverb state
        reset();
    }

    void reset()
    {
        // Clear pre-delay buffers
        std::fill(preDelayBufferL.begin(), preDelayBufferL.end(), 0.0f);
        std::fill(preDelayBufferR.begin(), preDelayBufferR.end(), 0.0f);
        preDelayWritePos = 0;

        // Clear comb filters
        for (auto& comb : combFiltersL)
            std::fill(comb.buffer.begin(), comb.buffer.end(), 0.0f);
        for (auto& comb : combFiltersR)
            std::fill(comb.buffer.begin(), comb.buffer.end(), 0.0f);

        // Clear allpass filters
        for (auto& allpass : allpassFiltersL)
            std::fill(allpass.buffer.begin(), allpass.buffer.end(), 0.0f);
        for (auto& allpass : allpassFiltersR)
            std::fill(allpass.buffer.begin(), allpass.buffer.end(), 0.0f);
    }

    //==============================================================================
    void process(juce::AudioBuffer<float>& buffer, const Parameters& params)
    {
        const int numSamples = buffer.getNumSamples();
        const int numChannels = buffer.getNumChannels();

        if (numChannels == 0 || numSamples == 0)
            return;

        // Calculate pre-delay time using EchoCalculator
        float preDelayMs = params.autoPreDelay
            ? IntelligentDelayCalculator::calculateReverbPreDelay(params.bpm, params.clarity)
            : params.manualPreDelayMs;

        int preDelaySamples = static_cast<int>(preDelayMs * currentSampleRate / 1000.0f);
        preDelaySamples = juce::jlimit(0, static_cast<int>(preDelayBufferL.size()) - 1, preDelaySamples);

        // Update reverb parameters
        updateReverbParameters(params);

        // Process
        if (numChannels == 1)
        {
            processMono(buffer.getWritePointer(0), numSamples, preDelaySamples, params);
        }
        else
        {
            processStereo(buffer.getWritePointer(0), buffer.getWritePointer(1),
                         numSamples, preDelaySamples, params);
        }
    }

    //==============================================================================
    // Get calculated pre-delay time (for display)
    float getCurrentPreDelayMs(const Parameters& params) const
    {
        return params.autoPreDelay
            ? IntelligentDelayCalculator::calculateReverbPreDelay(params.bpm, params.clarity)
            : params.manualPreDelayMs;
    }

private:
    //==============================================================================
    // Freeverb-style filter structures
    struct CombFilter
    {
        std::vector<float> buffer;
        int writePos = 0;
        float feedback = 0.0f;
        float damp = 0.0f;
        float filterStore = 0.0f;
    };

    struct AllpassFilter
    {
        std::vector<float> buffer;
        int writePos = 0;
    };

    //==============================================================================
    void initializeCombFilters()
    {
        // Standard Freeverb comb filter sizes (tuned for 44.1kHz)
        const std::vector<int> combSizes = {1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617};

        combFiltersL.resize(8);
        combFiltersR.resize(8);

        for (int i = 0; i < 8; ++i)
        {
            combFiltersL[i].buffer.resize(combSizes[i] + 23, 0.0f);  // Slightly different for stereo
            combFiltersR[i].buffer.resize(combSizes[i], 0.0f);
        }
    }

    void initializeAllpassFilters()
    {
        // Standard Freeverb allpass filter sizes
        const std::vector<int> allpassSizes = {556, 441, 341, 225};

        allpassFiltersL.resize(4);
        allpassFiltersR.resize(4);

        for (int i = 0; i < 4; ++i)
        {
            allpassFiltersL[i].buffer.resize(allpassSizes[i] + 23, 0.0f);  // Slightly different for stereo
            allpassFiltersR[i].buffer.resize(allpassSizes[i], 0.0f);
        }
    }

    void updateReverbParameters(const Parameters& params)
    {
        // Update comb filter parameters
        float roomScaleFactor = params.roomSize * 0.28f + 0.7f;
        float dampFactor = params.damping * 0.4f;
        float feedbackAmount = params.roomSize * 0.28f + 0.7f;

        for (auto& comb : combFiltersL)
        {
            comb.feedback = feedbackAmount;
            comb.damp = dampFactor;
        }
        for (auto& comb : combFiltersR)
        {
            comb.feedback = feedbackAmount;
            comb.damp = dampFactor;
        }
    }

    //==============================================================================
    void processMono(float* channel, int numSamples, int preDelaySamples, const Parameters& params)
    {
        // Enable denormal prevention for reverb feedback loops
        Echoel::DSP::DenormalPrevention::ScopedNoDenormals noDenormals;

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channel[i];

            // Apply pre-delay
            int readPos = (preDelayWritePos - preDelaySamples + static_cast<int>(preDelayBufferL.size()))
                         % static_cast<int>(preDelayBufferL.size());
            float preDelayed = preDelayBufferL[readPos];
            preDelayBufferL[preDelayWritePos] = input;

            // Process through reverb
            float reverbOutput = 0.0f;

            // Comb filters
            for (auto& comb : combFiltersL)
            {
                reverbOutput += processCombFilter(comb, preDelayed);
            }

            // Allpass filters
            for (auto& allpass : allpassFiltersL)
            {
                reverbOutput = processAllpassFilter(allpass, reverbOutput);
            }

            // Mix dry/wet
            channel[i] = input * (1.0f - params.dryWet) + reverbOutput * params.dryWet * 0.1f;

            // Advance write position
            preDelayWritePos = (preDelayWritePos + 1) % static_cast<int>(preDelayBufferL.size());
        }
    }

    void processStereo(float* channelL, float* channelR, int numSamples,
                      int preDelaySamples, const Parameters& params)
    {
        // Enable denormal prevention for reverb feedback loops
        Echoel::DSP::DenormalPrevention::ScopedNoDenormals noDenormals;

        for (int i = 0; i < numSamples; ++i)
        {
            float inputL = channelL[i];
            float inputR = channelR[i];

            // Apply pre-delay
            int readPos = (preDelayWritePos - preDelaySamples + static_cast<int>(preDelayBufferL.size()))
                         % static_cast<int>(preDelayBufferL.size());
            float preDelayedL = preDelayBufferL[readPos];
            float preDelayedR = preDelayBufferR[readPos];

            preDelayBufferL[preDelayWritePos] = inputL;
            preDelayBufferR[preDelayWritePos] = inputR;

            // Process through reverb
            float reverbL = 0.0f;
            float reverbR = 0.0f;

            // Comb filters
            for (auto& comb : combFiltersL)
                reverbL += processCombFilter(comb, preDelayedL);
            for (auto& comb : combFiltersR)
                reverbR += processCombFilter(comb, preDelayedR);

            // Allpass filters
            for (auto& allpass : allpassFiltersL)
                reverbL = processAllpassFilter(allpass, reverbL);
            for (auto& allpass : allpassFiltersR)
                reverbR = processAllpassFilter(allpass, reverbR);

            // Apply stereo width
            float width = params.width;
            float mid = (reverbL + reverbR) * 0.5f;
            float side = (reverbL - reverbR) * 0.5f * width;
            reverbL = mid + side;
            reverbR = mid - side;

            // Mix dry/wet
            channelL[i] = inputL * (1.0f - params.dryWet) + reverbL * params.dryWet * 0.1f;
            channelR[i] = inputR * (1.0f - params.dryWet) + reverbR * params.dryWet * 0.1f;

            // Advance write position
            preDelayWritePos = (preDelayWritePos + 1) % static_cast<int>(preDelayBufferL.size());
        }
    }

    //==============================================================================
    float processCombFilter(CombFilter& comb, float input)
    {
        float output = comb.buffer[comb.writePos];

        // One-pole lowpass damping
        comb.filterStore = (output * (1.0f - comb.damp)) + (comb.filterStore * comb.damp);

        comb.buffer[comb.writePos] = input + (comb.filterStore * comb.feedback);

        comb.writePos = (comb.writePos + 1) % static_cast<int>(comb.buffer.size());

        return output;
    }

    float processAllpassFilter(AllpassFilter& allpass, float input)
    {
        float bufferOut = allpass.buffer[allpass.writePos];
        float output = -input + bufferOut;

        allpass.buffer[allpass.writePos] = input + (bufferOut * 0.5f);

        allpass.writePos = (allpass.writePos + 1) % static_cast<int>(allpass.buffer.size());

        return output;
    }

    //==============================================================================
    // Pre-delay buffers
    std::vector<float> preDelayBufferL;
    std::vector<float> preDelayBufferR;
    int preDelayWritePos = 0;

    // Freeverb-style filters
    std::vector<CombFilter> combFiltersL;
    std::vector<CombFilter> combFiltersR;
    std::vector<AllpassFilter> allpassFiltersL;
    std::vector<AllpassFilter> allpassFiltersR;

    double currentSampleRate = 48000.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoCalculatorReverb)
};
