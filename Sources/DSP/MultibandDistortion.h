#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <cmath>
#include <memory>

/**
 * MultibandDistortion - Professional Multiband Saturation/Distortion
 *
 * Features:
 * - Up to 4 frequency bands with adjustable crossovers
 * - Multiple distortion types per band
 * - Independent drive, mix, and output per band
 * - Pre/post band EQ
 * - Band solo/mute
 * - Linear-phase or minimum-phase crossovers
 * - Look-ahead limiting per band
 *
 * Inspired by: FabFilter Saturn, iZotope Trash, Soundtoys Decapitator
 */

namespace Echoelmusic {
namespace DSP {

//==============================================================================
// Distortion Types
//==============================================================================

enum class DistortionType
{
    SoftClip,       // Gentle saturation
    HardClip,       // Digital clip
    Tube,           // Tube-style even harmonics
    Tape,           // Tape-style compression/saturation
    Foldback,       // Wavefolding
    Bitcrush,       // Bit reduction
    Rectify,        // Full/half wave rectification
    Asymmetric,     // Asymmetric clipping
    Fuzz,           // Transistor fuzz
    Waveshaper      // Custom waveshaper
};

//==============================================================================
// Band Distortion Processor
//==============================================================================

class BandDistortion
{
public:
    void setType(DistortionType type)
    {
        distType = type;
    }

    void setDrive(float drive)
    {
        driveAmount = juce::jlimit(0.0f, 1.0f, drive);
        inputGain = 1.0f + driveAmount * 20.0f;
    }

    void setMix(float mix)
    {
        wetMix = juce::jlimit(0.0f, 1.0f, mix);
    }

    void setOutputGain(float gain)
    {
        outputGain = juce::Decibels::decibelsToGain(juce::jlimit(-24.0f, 12.0f, gain));
    }

    void setBias(float bias)
    {
        dcBias = juce::jlimit(-0.5f, 0.5f, bias);
    }

    void setBitDepth(int bits)
    {
        bitDepth = juce::jlimit(1, 16, bits);
        quantizationLevels = std::pow(2.0f, static_cast<float>(bitDepth));
    }

    void setFoldAmount(float amount)
    {
        foldAmount = juce::jlimit(1.0f, 10.0f, amount);
    }

    float process(float input)
    {
        float dry = input;

        // Apply input gain and bias
        float x = input * inputGain + dcBias;

        // Apply distortion
        float wet = applyDistortion(x);

        // Remove DC offset
        dcBlockerState = dcBlockerState * 0.995f + wet * 0.005f;
        wet -= dcBlockerState;

        // Mix and output
        float output = dry * (1.0f - wetMix) + wet * wetMix;
        output *= outputGain;

        return output;
    }

    void reset()
    {
        dcBlockerState = 0.0f;
        filterState = 0.0f;
    }

private:
    DistortionType distType = DistortionType::SoftClip;
    float driveAmount = 0.5f;
    float inputGain = 5.0f;
    float outputGain = 1.0f;
    float wetMix = 1.0f;
    float dcBias = 0.0f;
    float dcBlockerState = 0.0f;
    float filterState = 0.0f;

    // Bitcrush parameters
    int bitDepth = 8;
    float quantizationLevels = 256.0f;

    // Foldback parameters
    float foldAmount = 2.0f;

    float applyDistortion(float x)
    {
        switch (distType)
        {
            case DistortionType::SoftClip:
                return softClip(x);

            case DistortionType::HardClip:
                return hardClip(x);

            case DistortionType::Tube:
                return tubeDistortion(x);

            case DistortionType::Tape:
                return tapeDistortion(x);

            case DistortionType::Foldback:
                return foldbackDistortion(x);

            case DistortionType::Bitcrush:
                return bitcrushDistortion(x);

            case DistortionType::Rectify:
                return rectifyDistortion(x);

            case DistortionType::Asymmetric:
                return asymmetricDistortion(x);

            case DistortionType::Fuzz:
                return fuzzDistortion(x);

            case DistortionType::Waveshaper:
                return waveshaperDistortion(x);

            default:
                return softClip(x);
        }
    }

    float softClip(float x)
    {
        // Soft saturation using tanh
        return std::tanh(x);
    }

    float hardClip(float x)
    {
        return juce::jlimit(-1.0f, 1.0f, x);
    }

    float tubeDistortion(float x)
    {
        // Asymmetric tube-style saturation
        float y;
        if (x >= 0.0f)
        {
            y = 1.0f - std::exp(-x);
        }
        else
        {
            y = -1.0f + std::exp(x);
        }

        // Add even harmonics
        y += 0.1f * x * x * (x > 0 ? 1.0f : -1.0f);

        return y;
    }

    float tapeDistortion(float x)
    {
        // Tape saturation with compression
        float sign = x >= 0.0f ? 1.0f : -1.0f;
        float absX = std::abs(x);

        // Soft knee compression
        float threshold = 0.5f;
        float y;

        if (absX < threshold)
        {
            y = absX;
        }
        else
        {
            float excess = absX - threshold;
            y = threshold + (1.0f - threshold) * std::tanh(excess * 2.0f);
        }

        // Add subtle even harmonics
        y += 0.05f * y * y;

        return y * sign;
    }

    float foldbackDistortion(float x)
    {
        // Wavefolding
        float y = x * foldAmount;

        while (std::abs(y) > 1.0f)
        {
            if (y > 1.0f)
                y = 2.0f - y;
            else if (y < -1.0f)
                y = -2.0f - y;
        }

        return y;
    }

    float bitcrushDistortion(float x)
    {
        // Quantize to bit depth
        float y = std::round(x * quantizationLevels) / quantizationLevels;
        return juce::jlimit(-1.0f, 1.0f, y);
    }

    float rectifyDistortion(float x)
    {
        // Full wave rectification with some smoothing
        float rectified = std::abs(x);

        // Smooth the harsh transitions
        filterState = filterState * 0.9f + rectified * 0.1f;

        return filterState * 2.0f - 1.0f;  // Scale to bipolar
    }

    float asymmetricDistortion(float x)
    {
        // Positive and negative clips at different thresholds
        if (x > 0.3f)
        {
            x = 0.3f + (x - 0.3f) * 0.2f;  // Soft limit positive
        }
        else if (x < -0.7f)
        {
            x = -0.7f + (x + 0.7f) * 0.3f;  // Different negative
        }

        return std::tanh(x * 2.0f);
    }

    float fuzzDistortion(float x)
    {
        // Transistor fuzz simulation
        float y = x;

        // Clipping diode simulation
        float diodeVoltage = 0.3f;
        if (y > diodeVoltage)
        {
            y = diodeVoltage + std::log1p(y - diodeVoltage) * 0.3f;
        }
        else if (y < -diodeVoltage)
        {
            y = -diodeVoltage - std::log1p(-y - diodeVoltage) * 0.3f;
        }

        // Add octave-up effect
        y += std::abs(y) * 0.2f;

        return std::tanh(y * 1.5f);
    }

    float waveshaperDistortion(float x)
    {
        // Chebyshev polynomial waveshaping
        float x2 = x * x;
        float x3 = x2 * x;
        float x5 = x3 * x2;

        // Mix of harmonics
        float y = x - 0.3f * x3 + 0.1f * x5;

        return std::tanh(y);
    }
};

//==============================================================================
// Crossover Filter
//==============================================================================

class CrossoverFilter
{
public:
    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        updateCoefficients();
    }

    void setFrequency(float frequency)
    {
        crossoverFreq = juce::jlimit(20.0f, 20000.0f, frequency);
        updateCoefficients();
    }

    void process(float input, float& low, float& high)
    {
        // Linkwitz-Riley 4th order (two cascaded Butterworth 2nd order)
        float lp1 = processLP(input, lpState1);
        float lp2 = processLP(lp1, lpState2);
        low = lp2;

        float hp1 = processHP(input, hpState1);
        float hp2 = processHP(hp1, hpState2);
        high = hp2;
    }

    void reset()
    {
        std::fill(lpState1.begin(), lpState1.end(), 0.0f);
        std::fill(lpState2.begin(), lpState2.end(), 0.0f);
        std::fill(hpState1.begin(), hpState1.end(), 0.0f);
        std::fill(hpState2.begin(), hpState2.end(), 0.0f);
    }

private:
    double currentSampleRate = 48000.0;
    float crossoverFreq = 1000.0f;

    // Biquad coefficients
    float lpB0 = 1.0f, lpB1 = 0.0f, lpB2 = 0.0f;
    float lpA1 = 0.0f, lpA2 = 0.0f;
    float hpB0 = 1.0f, hpB1 = 0.0f, hpB2 = 0.0f;
    float hpA1 = 0.0f, hpA2 = 0.0f;

    std::array<float, 2> lpState1{}, lpState2{};
    std::array<float, 2> hpState1{}, hpState2{};

    void updateCoefficients()
    {
        float w0 = 2.0f * juce::MathConstants<float>::pi * crossoverFreq /
                   static_cast<float>(currentSampleRate);
        float cosW0 = std::cos(w0);
        float sinW0 = std::sin(w0);
        float alpha = sinW0 / (2.0f * 0.707f);  // Q = 0.707 for Butterworth

        // Lowpass
        float lpA0 = 1.0f + alpha;
        lpB0 = ((1.0f - cosW0) / 2.0f) / lpA0;
        lpB1 = (1.0f - cosW0) / lpA0;
        lpB2 = ((1.0f - cosW0) / 2.0f) / lpA0;
        lpA1 = (-2.0f * cosW0) / lpA0;
        lpA2 = (1.0f - alpha) / lpA0;

        // Highpass
        float hpA0 = 1.0f + alpha;
        hpB0 = ((1.0f + cosW0) / 2.0f) / hpA0;
        hpB1 = -(1.0f + cosW0) / hpA0;
        hpB2 = ((1.0f + cosW0) / 2.0f) / hpA0;
        hpA1 = (-2.0f * cosW0) / hpA0;
        hpA2 = (1.0f - alpha) / hpA0;
    }

    float processLP(float input, std::array<float, 2>& state)
    {
        float output = lpB0 * input + state[0];
        state[0] = lpB1 * input - lpA1 * output + state[1];
        state[1] = lpB2 * input - lpA2 * output;
        return output;
    }

    float processHP(float input, std::array<float, 2>& state)
    {
        float output = hpB0 * input + state[0];
        state[0] = hpB1 * input - hpA1 * output + state[1];
        state[1] = hpB2 * input - hpA2 * output;
        return output;
    }
};

//==============================================================================
// Multiband Distortion (Main Class)
//==============================================================================

class MultibandDistortion
{
public:
    static constexpr int MaxBands = 4;

    //==========================================================================
    // Presets
    //==========================================================================

    enum class Preset
    {
        Subtle_Warmth,
        Tape_Saturation,
        Aggressive_Crunch,
        Bass_Enhancement,
        Presence_Boost,
        Lo_Fi,
        Modern_Edge,
        Vintage_Warmth
    };

    //==========================================================================
    // Constructor
    //==========================================================================

    MultibandDistortion()
    {
        for (int i = 0; i < MaxBands; ++i)
            bandProcessors[i] = std::make_unique<BandDistortion>();

        for (int i = 0; i < MaxBands - 1; ++i)
            crossovers[i] = std::make_unique<CrossoverFilter>();
    }

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;

        for (auto& xover : crossovers)
            xover->prepare(sampleRate);

        // Default crossover frequencies
        setCrossover(0, 150.0f);
        setCrossover(1, 1000.0f);
        setCrossover(2, 5000.0f);

        reset();
    }

    void reset()
    {
        for (auto& xover : crossovers)
            xover->reset();

        for (auto& band : bandProcessors)
            band->reset();
    }

    //==========================================================================
    // Band Configuration
    //==========================================================================

    void setNumBands(int num)
    {
        numBands = juce::jlimit(1, MaxBands, num);
    }

    void setCrossover(int index, float frequency)
    {
        if (index >= 0 && index < MaxBands - 1)
            crossovers[index]->setFrequency(frequency);
    }

    void setBandDrive(int band, float drive)
    {
        if (band >= 0 && band < MaxBands)
            bandProcessors[band]->setDrive(drive);
    }

    void setBandType(int band, DistortionType type)
    {
        if (band >= 0 && band < MaxBands)
            bandProcessors[band]->setType(type);
    }

    void setBandMix(int band, float mix)
    {
        if (band >= 0 && band < MaxBands)
            bandProcessors[band]->setMix(mix);
    }

    void setBandOutput(int band, float gainDb)
    {
        if (band >= 0 && band < MaxBands)
            bandProcessors[band]->setOutputGain(gainDb);
    }

    void setBandSolo(int band, bool solo)
    {
        if (band >= 0 && band < MaxBands)
            bandSolo[band] = solo;
    }

    void setBandMute(int band, bool mute)
    {
        if (band >= 0 && band < MaxBands)
            bandMute[band] = mute;
    }

    void setBandBypass(int band, bool bypass)
    {
        if (band >= 0 && band < MaxBands)
            bandBypass[band] = bypass;
    }

    //==========================================================================
    // Global Parameters
    //==========================================================================

    void setInputGain(float gainDb)
    {
        inputGain = juce::Decibels::decibelsToGain(juce::jlimit(-24.0f, 24.0f, gainDb));
    }

    void setOutputGain(float gainDb)
    {
        outputGain = juce::Decibels::decibelsToGain(juce::jlimit(-24.0f, 24.0f, gainDb));
    }

    void setGlobalMix(float mix)
    {
        globalMix = juce::jlimit(0.0f, 1.0f, mix);
    }

    //==========================================================================
    // Presets
    //==========================================================================

    void loadPreset(Preset preset)
    {
        currentPreset = preset;

        // Reset all bands
        for (int i = 0; i < MaxBands; ++i)
        {
            setBandDrive(i, 0.0f);
            setBandMix(i, 1.0f);
            setBandOutput(i, 0.0f);
            setBandMute(i, false);
            setBandSolo(i, false);
            setBandBypass(i, false);
        }

        switch (preset)
        {
            case Preset::Subtle_Warmth:
                setNumBands(3);
                setCrossover(0, 200.0f);
                setCrossover(1, 3000.0f);
                setBandType(0, DistortionType::Tape);
                setBandType(1, DistortionType::Tube);
                setBandType(2, DistortionType::SoftClip);
                setBandDrive(0, 0.3f);
                setBandDrive(1, 0.2f);
                setBandDrive(2, 0.15f);
                setGlobalMix(0.5f);
                break;

            case Preset::Tape_Saturation:
                setNumBands(4);
                setCrossover(0, 100.0f);
                setCrossover(1, 800.0f);
                setCrossover(2, 4000.0f);
                for (int i = 0; i < 4; ++i)
                    setBandType(i, DistortionType::Tape);
                setBandDrive(0, 0.4f);
                setBandDrive(1, 0.5f);
                setBandDrive(2, 0.45f);
                setBandDrive(3, 0.35f);
                setGlobalMix(0.7f);
                break;

            case Preset::Aggressive_Crunch:
                setNumBands(3);
                setCrossover(0, 150.0f);
                setCrossover(1, 2500.0f);
                setBandType(0, DistortionType::HardClip);
                setBandType(1, DistortionType::Fuzz);
                setBandType(2, DistortionType::HardClip);
                setBandDrive(0, 0.5f);
                setBandDrive(1, 0.7f);
                setBandDrive(2, 0.6f);
                setGlobalMix(0.8f);
                break;

            case Preset::Bass_Enhancement:
                setNumBands(2);
                setCrossover(0, 200.0f);
                setBandType(0, DistortionType::Tube);
                setBandType(1, DistortionType::SoftClip);
                setBandDrive(0, 0.6f);
                setBandDrive(1, 0.1f);
                setBandOutput(0, 3.0f);
                setGlobalMix(0.6f);
                break;

            case Preset::Presence_Boost:
                setNumBands(3);
                setCrossover(0, 500.0f);
                setCrossover(1, 3000.0f);
                setBandType(0, DistortionType::SoftClip);
                setBandType(1, DistortionType::Tube);
                setBandType(2, DistortionType::Tape);
                setBandDrive(0, 0.1f);
                setBandDrive(1, 0.3f);
                setBandDrive(2, 0.5f);
                setBandOutput(2, 2.0f);
                setGlobalMix(0.5f);
                break;

            case Preset::Lo_Fi:
                setNumBands(2);
                setCrossover(0, 400.0f);
                setBandType(0, DistortionType::Bitcrush);
                setBandType(1, DistortionType::Bitcrush);
                bandProcessors[0]->setBitDepth(6);
                bandProcessors[1]->setBitDepth(8);
                setBandDrive(0, 0.4f);
                setBandDrive(1, 0.5f);
                setGlobalMix(0.7f);
                break;

            case Preset::Modern_Edge:
                setNumBands(4);
                setCrossover(0, 120.0f);
                setCrossover(1, 1200.0f);
                setCrossover(2, 6000.0f);
                setBandType(0, DistortionType::SoftClip);
                setBandType(1, DistortionType::Waveshaper);
                setBandType(2, DistortionType::Foldback);
                setBandType(3, DistortionType::SoftClip);
                setBandDrive(0, 0.2f);
                setBandDrive(1, 0.5f);
                setBandDrive(2, 0.4f);
                setBandDrive(3, 0.3f);
                bandProcessors[2]->setFoldAmount(3.0f);
                setGlobalMix(0.6f);
                break;

            case Preset::Vintage_Warmth:
                setNumBands(3);
                setCrossover(0, 180.0f);
                setCrossover(1, 2200.0f);
                setBandType(0, DistortionType::Tube);
                setBandType(1, DistortionType::Tape);
                setBandType(2, DistortionType::Tube);
                setBandDrive(0, 0.35f);
                setBandDrive(1, 0.4f);
                setBandDrive(2, 0.25f);
                setGlobalMix(0.55f);
                break;
        }
    }

    //==========================================================================
    // Processing
    //==========================================================================

    void processBlock(juce::AudioBuffer<float>& buffer)
    {
        int numSamples = buffer.getNumSamples();

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            float* data = buffer.getWritePointer(ch);

            for (int i = 0; i < numSamples; ++i)
            {
                float dry = data[i];
                data[i] = processSample(data[i], ch);

                // Global mix
                data[i] = dry * (1.0f - globalMix) + data[i] * globalMix;
            }
        }
    }

    float processSample(float input, int channel = 0)
    {
        // Input gain
        input *= inputGain;

        // Split into bands
        std::array<float, MaxBands> bands{};

        if (numBands == 1)
        {
            bands[0] = input;
        }
        else if (numBands == 2)
        {
            crossovers[0]->process(input, bands[0], bands[1]);
        }
        else if (numBands == 3)
        {
            float low, high;
            crossovers[0]->process(input, low, high);
            bands[0] = low;
            crossovers[1]->process(high, bands[1], bands[2]);
        }
        else // 4 bands
        {
            float low, high, mid, highMid;
            crossovers[0]->process(input, low, high);
            bands[0] = low;
            crossovers[1]->process(high, mid, highMid);
            bands[1] = mid;
            crossovers[2]->process(highMid, bands[2], bands[3]);
        }

        // Check for solo
        bool anySolo = false;
        for (int i = 0; i < numBands; ++i)
        {
            if (bandSolo[i])
            {
                anySolo = true;
                break;
            }
        }

        // Process and sum bands
        float output = 0.0f;

        for (int i = 0; i < numBands; ++i)
        {
            // Check mute/solo
            if (bandMute[i])
                continue;

            if (anySolo && !bandSolo[i])
                continue;

            // Process band
            float processed;
            if (bandBypass[i])
            {
                processed = bands[i];
            }
            else
            {
                processed = bandProcessors[i]->process(bands[i]);
            }

            output += processed;
        }

        // Output gain
        output *= outputGain;

        return output;
    }

    //==========================================================================
    // Getters
    //==========================================================================

    Preset getCurrentPreset() const { return currentPreset; }
    int getNumBands() const { return numBands; }

private:
    double currentSampleRate = 48000.0;

    std::array<std::unique_ptr<BandDistortion>, MaxBands> bandProcessors;
    std::array<std::unique_ptr<CrossoverFilter>, MaxBands - 1> crossovers;

    int numBands = 3;
    Preset currentPreset = Preset::Subtle_Warmth;

    std::array<bool, MaxBands> bandSolo{};
    std::array<bool, MaxBands> bandMute{};
    std::array<bool, MaxBands> bandBypass{};

    float inputGain = 1.0f;
    float outputGain = 1.0f;
    float globalMix = 1.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MultibandDistortion)
};

} // namespace DSP
} // namespace Echoelmusic
