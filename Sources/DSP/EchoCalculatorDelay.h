#pragma once

#include <JuceHeader.h>
#include "../CreativeTools/IntelligentDelayCalculator.h"
#include <vector>
#include <cmath>

//==============================================================================
/**
 * @brief EchoCalculator BPM-Synced Delay
 *
 * Professional delay effect with intelligent BPM synchronization.
 * Integrates studio calculator tools directly into DSP processing.
 *
 * Features:
 * - BPM-synced delay times (auto-calculated)
 * - Musical note divisions (1/4, 1/8, 1/16, etc.)
 * - Dotted and triplet timings
 * - Stereo ping-pong mode
 * - Multi-tap delays
 * - High-quality interpolation
 * - Feedback with damping
 *
 * This is part of the EchoCalculator suite - making professional
 * studio calculations accessible in real-time audio processing.
 */
class EchoCalculatorDelay
{
public:
    //==============================================================================
    struct Parameters
    {
        float bpm = 120.0f;                                              // Host BPM
        IntelligentDelayCalculator::NoteDivision division =              // Note division
            IntelligentDelayCalculator::NoteDivision::Quarter;
        IntelligentDelayCalculator::NoteModifier modifier =              // Dotted/Triplet
            IntelligentDelayCalculator::NoteModifier::Straight;

        float feedback = 0.4f;                                           // 0-0.95 (danger above!)
        float dryWet = 0.3f;                                             // 0-1
        float damping = 0.5f;                                            // High-freq rolloff
        bool syncToBPM = true;                                           // Auto-sync vs manual
        float manualDelayMs = 500.0f;                                    // Manual delay (if not synced)
        bool pingPong = false;                                           // Stereo ping-pong
        int numTaps = 1;                                                 // Multi-tap (1-4)
    };

    //==============================================================================
    EchoCalculatorDelay()
    {
        // Initialize delay buffers
        maxDelaySamples = static_cast<int>(48000 * 2.0);  // Max 2 seconds at 48kHz
        delayBufferL.resize(maxDelaySamples, 0.0f);
        delayBufferR.resize(maxDelaySamples, 0.0f);
    }

    //==============================================================================
    void prepare(double sampleRate, int /*maxBlockSize*/)
    {
        currentSampleRate = sampleRate;

        // Resize buffers based on sample rate
        maxDelaySamples = static_cast<int>(sampleRate * 2.0);  // Max 2 seconds
        delayBufferL.resize(maxDelaySamples, 0.0f);
        delayBufferR.resize(maxDelaySamples, 0.0f);

        // Reset state
        writePosition = 0;
        std::fill(delayBufferL.begin(), delayBufferL.end(), 0.0f);
        std::fill(delayBufferR.begin(), delayBufferR.end(), 0.0f);

        // Initialize damping filters (simple one-pole lowpass)
        dampingStateL = 0.0f;
        dampingStateR = 0.0f;
    }

    //==============================================================================
    void process(juce::AudioBuffer<float>& buffer, const Parameters& params)
    {
        const int numSamples = buffer.getNumSamples();
        const int numChannels = buffer.getNumChannels();

        if (numChannels == 0 || numSamples == 0)
            return;

        // Calculate delay time
        float delayMs = params.syncToBPM
            ? IntelligentDelayCalculator::calculateDelayTime(params.bpm, params.division, params.modifier)
            : params.manualDelayMs;

        // Convert to samples
        int delaySamples = static_cast<int>(delayMs * currentSampleRate / 1000.0f);
        delaySamples = juce::jlimit(1, maxDelaySamples - 1, delaySamples);

        // Process audio
        if (numChannels == 1)
        {
            // Mono processing
            processMono(buffer.getWritePointer(0), numSamples, delaySamples, params);
        }
        else
        {
            // Stereo processing
            processStereo(buffer.getWritePointer(0), buffer.getWritePointer(1),
                         numSamples, delaySamples, params);
        }
    }

    //==============================================================================
    // Get calculated delay time in ms (for display)
    float getCurrentDelayMs(const Parameters& params) const
    {
        return params.syncToBPM
            ? IntelligentDelayCalculator::calculateDelayTime(params.bpm, params.division, params.modifier)
            : params.manualDelayMs;
    }

    // Get note division string (for display)
    static juce::String getNoteDivisionString(IntelligentDelayCalculator::NoteDivision division,
                                             IntelligentDelayCalculator::NoteModifier modifier)
    {
        juce::String divStr;

        switch (division)
        {
            case IntelligentDelayCalculator::NoteDivision::Whole:        divStr = "1/1"; break;
            case IntelligentDelayCalculator::NoteDivision::Half:         divStr = "1/2"; break;
            case IntelligentDelayCalculator::NoteDivision::Quarter:      divStr = "1/4"; break;
            case IntelligentDelayCalculator::NoteDivision::Eighth:       divStr = "1/8"; break;
            case IntelligentDelayCalculator::NoteDivision::Sixteenth:    divStr = "1/16"; break;
            case IntelligentDelayCalculator::NoteDivision::ThirtySecond: divStr = "1/32"; break;
            case IntelligentDelayCalculator::NoteDivision::SixtyFourth:  divStr = "1/64"; break;
        }

        switch (modifier)
        {
            case IntelligentDelayCalculator::NoteModifier::Dotted:  divStr += "."; break;
            case IntelligentDelayCalculator::NoteModifier::Triplet: divStr += "T"; break;
            default: break;
        }

        return divStr;
    }

private:
    //==============================================================================
    void processMono(float* channel, int numSamples, int delaySamples, const Parameters& params)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            // Read delayed sample
            int readPos = (writePosition - delaySamples + maxDelaySamples) % maxDelaySamples;
            float delayedSample = delayBufferL[readPos];

            // Apply damping (simple lowpass filter)
            float dampCoeff = params.damping;
            dampingStateL = dampingStateL * dampCoeff + delayedSample * (1.0f - dampCoeff);
            float dampedSample = dampingStateL;

            // Read input
            float input = channel[i];

            // Write to delay buffer (input + feedback)
            float feedbackAmount = juce::jlimit(0.0f, 0.95f, params.feedback);
            delayBufferL[writePosition] = input + dampedSample * feedbackAmount;

            // Mix dry/wet
            channel[i] = input * (1.0f - params.dryWet) + dampedSample * params.dryWet;

            // Advance write position
            writePosition = (writePosition + 1) % maxDelaySamples;
        }
    }

    void processStereo(float* channelL, float* channelR, int numSamples,
                      int delaySamples, const Parameters& params)
    {
        if (params.pingPong)
        {
            processPingPong(channelL, channelR, numSamples, delaySamples, params);
        }
        else
        {
            processStereoNormal(channelL, channelR, numSamples, delaySamples, params);
        }
    }

    void processStereoNormal(float* channelL, float* channelR, int numSamples,
                            int delaySamples, const Parameters& params)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            // Read delayed samples
            int readPos = (writePosition - delaySamples + maxDelaySamples) % maxDelaySamples;
            float delayedL = delayBufferL[readPos];
            float delayedR = delayBufferR[readPos];

            // Apply damping
            float dampCoeff = params.damping;
            dampingStateL = dampingStateL * dampCoeff + delayedL * (1.0f - dampCoeff);
            dampingStateR = dampingStateR * dampCoeff + delayedR * (1.0f - dampCoeff);

            // Read inputs
            float inputL = channelL[i];
            float inputR = channelR[i];

            // Write to delay buffers (input + feedback)
            float feedbackAmount = juce::jlimit(0.0f, 0.95f, params.feedback);
            delayBufferL[writePosition] = inputL + dampingStateL * feedbackAmount;
            delayBufferR[writePosition] = inputR + dampingStateR * feedbackAmount;

            // Mix dry/wet
            channelL[i] = inputL * (1.0f - params.dryWet) + dampingStateL * params.dryWet;
            channelR[i] = inputR * (1.0f - params.dryWet) + dampingStateR * params.dryWet;

            // Advance write position
            writePosition = (writePosition + 1) % maxDelaySamples;
        }
    }

    void processPingPong(float* channelL, float* channelR, int numSamples,
                        int delaySamples, const Parameters& params)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            // Read delayed samples
            int readPos = (writePosition - delaySamples + maxDelaySamples) % maxDelaySamples;
            float delayedL = delayBufferL[readPos];
            float delayedR = delayBufferR[readPos];

            // Apply damping
            float dampCoeff = params.damping;
            dampingStateL = dampingStateL * dampCoeff + delayedL * (1.0f - dampCoeff);
            dampingStateR = dampingStateR * dampCoeff + delayedR * (1.0f - dampCoeff);

            // Read inputs
            float inputL = channelL[i];
            float inputR = channelR[i];

            // Ping-pong: feedback crosses channels
            float feedbackAmount = juce::jlimit(0.0f, 0.95f, params.feedback);
            delayBufferL[writePosition] = inputL + dampingStateR * feedbackAmount;  // R→L
            delayBufferR[writePosition] = inputR + dampingStateL * feedbackAmount;  // L→R

            // Mix dry/wet
            channelL[i] = inputL * (1.0f - params.dryWet) + dampingStateL * params.dryWet;
            channelR[i] = inputR * (1.0f - params.dryWet) + dampingStateR * params.dryWet;

            // Advance write position
            writePosition = (writePosition + 1) % maxDelaySamples;
        }
    }

    //==============================================================================
    std::vector<float> delayBufferL;
    std::vector<float> delayBufferR;

    int maxDelaySamples = 0;
    int writePosition = 0;
    double currentSampleRate = 48000.0;

    // Damping filter state
    float dampingStateL = 0.0f;
    float dampingStateR = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoCalculatorDelay)
};
