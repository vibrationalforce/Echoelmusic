#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <cmath>
#include <complex>
#include <memory>

/**
 * FormantShifter - Professional Formant Manipulation Processor
 *
 * Features:
 * - Independent formant shift from pitch
 * - Gender transformation (male/female/child)
 * - Vowel morphing and modification
 * - Formant freeze/capture
 * - Throat/mouth modeling
 * - Voice character preservation
 * - Real-time LPC analysis
 *
 * Inspired by: Soundtoys Little AlterBoy, Antares Throat, Waves OVox
 */

namespace Echoelmusic {
namespace DSP {

//==============================================================================
// LPC (Linear Predictive Coding) Analyzer
//==============================================================================

class LPCAnalyzer
{
public:
    static constexpr int MaxOrder = 32;

    void setOrder(int order)
    {
        lpcOrder = juce::jlimit(8, MaxOrder, order);
    }

    void analyze(const float* samples, int numSamples)
    {
        // Compute autocorrelation
        std::array<float, MaxOrder + 1> autocorr{};

        for (int lag = 0; lag <= lpcOrder; ++lag)
        {
            float sum = 0.0f;
            for (int i = 0; i < numSamples - lag; ++i)
            {
                sum += samples[i] * samples[i + lag];
            }
            autocorr[lag] = sum;
        }

        // Levinson-Durbin recursion
        std::array<float, MaxOrder> k{};  // Reflection coefficients
        std::array<float, MaxOrder> a{};  // LPC coefficients
        std::array<float, MaxOrder> aPrev{};

        float E = autocorr[0];

        for (int i = 0; i < lpcOrder; ++i)
        {
            float lambda = 0.0f;
            for (int j = 0; j < i; ++j)
            {
                lambda += aPrev[j] * autocorr[i - j];
            }
            lambda = autocorr[i + 1] - lambda;

            k[i] = lambda / E;

            a[i] = k[i];
            for (int j = 0; j < i; ++j)
            {
                a[j] = aPrev[j] - k[i] * aPrev[i - 1 - j];
            }

            E = E * (1.0f - k[i] * k[i]);

            aPrev = a;
        }

        // Store coefficients
        for (int i = 0; i < lpcOrder; ++i)
            lpcCoeffs[i] = a[i];

        // Calculate prediction gain
        predictionGain = std::sqrt(autocorr[0] / E);
    }

    const std::array<float, MaxOrder>& getCoefficients() const
    {
        return lpcCoeffs;
    }

    float getPredictionGain() const
    {
        return predictionGain;
    }

    int getOrder() const
    {
        return lpcOrder;
    }

    // Find formant frequencies from LPC coefficients
    void findFormants(std::vector<float>& frequencies, std::vector<float>& bandwidths,
                      double sampleRate)
    {
        frequencies.clear();
        bandwidths.clear();

        // Find roots of LPC polynomial
        std::vector<std::complex<float>> roots;
        findRoots(roots);

        // Convert roots to frequencies and bandwidths
        for (const auto& root : roots)
        {
            // Only use roots inside unit circle with positive imaginary part
            float mag = std::abs(root);
            if (mag < 1.0f && root.imag() > 0.0f)
            {
                float angle = std::arg(root);
                float freq = angle * static_cast<float>(sampleRate) /
                             (2.0f * juce::MathConstants<float>::pi);

                // Bandwidth from distance to unit circle
                float bw = -std::log(mag) * static_cast<float>(sampleRate) /
                           juce::MathConstants<float>::pi;

                if (freq > 50.0f && freq < 5000.0f && bw < 500.0f)
                {
                    frequencies.push_back(freq);
                    bandwidths.push_back(bw);
                }
            }
        }

        // Sort by frequency
        for (size_t i = 0; i < frequencies.size(); ++i)
        {
            for (size_t j = i + 1; j < frequencies.size(); ++j)
            {
                if (frequencies[j] < frequencies[i])
                {
                    std::swap(frequencies[i], frequencies[j]);
                    std::swap(bandwidths[i], bandwidths[j]);
                }
            }
        }
    }

private:
    int lpcOrder = 16;
    std::array<float, MaxOrder> lpcCoeffs{};
    float predictionGain = 1.0f;

    void findRoots(std::vector<std::complex<float>>& roots)
    {
        // Simplified root finding using Durand-Kerner method
        roots.resize(lpcOrder);

        // Initialize roots on unit circle
        for (int i = 0; i < lpcOrder; ++i)
        {
            float angle = 2.0f * juce::MathConstants<float>::pi * (i + 0.5f) / lpcOrder;
            roots[i] = std::complex<float>(0.9f * std::cos(angle), 0.9f * std::sin(angle));
        }

        // Iterate
        for (int iter = 0; iter < 50; ++iter)
        {
            bool converged = true;

            for (int i = 0; i < lpcOrder; ++i)
            {
                // Evaluate polynomial
                std::complex<float> p(1.0f, 0.0f);
                std::complex<float> z = roots[i];
                std::complex<float> zPow(1.0f, 0.0f);

                for (int j = 0; j < lpcOrder; ++j)
                {
                    zPow *= z;
                    p -= lpcCoeffs[j] * zPow;
                }

                // Product of differences
                std::complex<float> q(1.0f, 0.0f);
                for (int j = 0; j < lpcOrder; ++j)
                {
                    if (i != j)
                        q *= (roots[i] - roots[j]);
                }

                // Update
                std::complex<float> delta = p / q;
                roots[i] -= delta;

                if (std::abs(delta) > 1e-6f)
                    converged = false;
            }

            if (converged)
                break;
        }
    }
};

//==============================================================================
// Formant Filter Bank
//==============================================================================

class FormantFilterBank
{
public:
    static constexpr int NumFormants = 5;

    struct Formant
    {
        float frequency = 500.0f;
        float bandwidth = 100.0f;
        float gain = 1.0f;
    };

    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        updateFilters();
    }

    void setFormant(int index, float freq, float bw, float gain)
    {
        if (index >= 0 && index < NumFormants)
        {
            formants[index].frequency = juce::jlimit(50.0f, 8000.0f, freq);
            formants[index].bandwidth = juce::jlimit(20.0f, 500.0f, bw);
            formants[index].gain = juce::jlimit(0.0f, 2.0f, gain);
            updateFilters();
        }
    }

    void setFormantFrequency(int index, float freq)
    {
        if (index >= 0 && index < NumFormants)
        {
            formants[index].frequency = juce::jlimit(50.0f, 8000.0f, freq);
            updateFilters();
        }
    }

    void shiftAllFormants(float semitones)
    {
        float ratio = std::pow(2.0f, semitones / 12.0f);
        for (int i = 0; i < NumFormants; ++i)
        {
            formants[i].frequency = juce::jlimit(50.0f, 8000.0f,
                                                  baseFormants[i].frequency * ratio);
        }
        updateFilters();
    }

    void captureFormants()
    {
        baseFormants = formants;
    }

    float process(float input)
    {
        float output = 0.0f;

        for (int i = 0; i < NumFormants; ++i)
        {
            output += processFilter(input, i) * formants[i].gain;
        }

        return output * 0.3f;  // Normalize
    }

    void reset()
    {
        for (auto& state : filterStates)
            std::fill(state.begin(), state.end(), 0.0f);
    }

    const std::array<Formant, NumFormants>& getFormants() const
    {
        return formants;
    }

private:
    double currentSampleRate = 48000.0;
    std::array<Formant, NumFormants> formants;
    std::array<Formant, NumFormants> baseFormants;

    // Biquad filter states and coefficients
    std::array<std::array<float, 4>, NumFormants> filterStates{};
    std::array<std::array<float, 5>, NumFormants> filterCoeffs{};

    void updateFilters()
    {
        for (int i = 0; i < NumFormants; ++i)
        {
            // Bandpass filter design
            float w0 = 2.0f * juce::MathConstants<float>::pi *
                       formants[i].frequency / static_cast<float>(currentSampleRate);
            float bw = 2.0f * juce::MathConstants<float>::pi *
                       formants[i].bandwidth / static_cast<float>(currentSampleRate);

            float cosW0 = std::cos(w0);
            float sinW0 = std::sin(w0);
            float alpha = sinW0 * std::sinh(bw / 2.0f);

            float a0 = 1.0f + alpha;
            filterCoeffs[i][0] = alpha / a0;           // b0
            filterCoeffs[i][1] = 0.0f;                 // b1
            filterCoeffs[i][2] = -alpha / a0;          // b2
            filterCoeffs[i][3] = -2.0f * cosW0 / a0;   // a1
            filterCoeffs[i][4] = (1.0f - alpha) / a0;  // a2
        }
    }

    float processFilter(float input, int index)
    {
        const auto& c = filterCoeffs[index];
        auto& s = filterStates[index];

        float output = c[0] * input + s[0];
        s[0] = c[1] * input - c[3] * output + s[1];
        s[1] = c[2] * input - c[4] * output;

        return output;
    }

public:
    FormantFilterBank()
    {
        // Initialize default vowel formants (neutral 'uh')
        formants[0] = { 500.0f, 100.0f, 1.0f };
        formants[1] = { 1500.0f, 120.0f, 0.8f };
        formants[2] = { 2500.0f, 150.0f, 0.5f };
        formants[3] = { 3500.0f, 200.0f, 0.3f };
        formants[4] = { 4500.0f, 250.0f, 0.2f };

        baseFormants = formants;
    }
};

//==============================================================================
// Pitch Shifter (for independent pitch/formant control)
//==============================================================================

class GranularPitchShifter
{
public:
    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;

        int maxGrainSize = static_cast<int>(0.1 * sampleRate);  // 100ms max grain
        buffer.resize(maxGrainSize * 2, 0.0f);

        grainSize = static_cast<int>(0.02 * sampleRate);  // 20ms default
    }

    void setPitchShift(float semitones)
    {
        pitchRatio = std::pow(2.0f, semitones / 12.0f);
    }

    void setGrainSize(float ms)
    {
        grainSize = static_cast<int>(ms * 0.001f * currentSampleRate);
        grainSize = juce::jlimit(64, static_cast<int>(buffer.size() / 2), grainSize);
    }

    float process(float input)
    {
        // Write input to circular buffer
        buffer[writePos] = input;
        writePos = (writePos + 1) % buffer.size();

        // Two overlapping grains for smooth output
        float output = 0.0f;

        // Grain 1
        float window1 = hannWindow(grainPhase1);
        int readPos1 = static_cast<int>(writePos - grainSize + grainPhase1 * grainSize * (1.0f - pitchRatio));
        if (readPos1 < 0) readPos1 += buffer.size();
        readPos1 = readPos1 % buffer.size();
        output += buffer[readPos1] * window1;

        // Grain 2 (offset by half grain)
        float window2 = hannWindow(grainPhase2);
        int readPos2 = static_cast<int>(writePos - grainSize + grainPhase2 * grainSize * (1.0f - pitchRatio));
        if (readPos2 < 0) readPos2 += buffer.size();
        readPos2 = readPos2 % buffer.size();
        output += buffer[readPos2] * window2;

        // Advance grain phases
        float phaseInc = 1.0f / grainSize;
        grainPhase1 += phaseInc;
        if (grainPhase1 >= 1.0f) grainPhase1 -= 1.0f;

        grainPhase2 += phaseInc;
        if (grainPhase2 >= 1.0f) grainPhase2 -= 1.0f;

        return output;
    }

    void reset()
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        writePos = 0;
        grainPhase1 = 0.0f;
        grainPhase2 = 0.5f;
    }

private:
    double currentSampleRate = 48000.0;
    std::vector<float> buffer;
    int writePos = 0;
    int grainSize = 1024;
    float pitchRatio = 1.0f;
    float grainPhase1 = 0.0f;
    float grainPhase2 = 0.5f;

    float hannWindow(float phase)
    {
        return 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi * phase));
    }
};

//==============================================================================
// Formant Shifter (Main Class)
//==============================================================================

class FormantShifter
{
public:
    //==========================================================================
    // Vowel Types
    //==========================================================================

    enum class Vowel
    {
        A,      // "ah" as in "father"
        E,      // "eh" as in "bed"
        I,      // "ee" as in "beet"
        O,      // "oh" as in "boat"
        U,      // "oo" as in "boot"
        Neutral // schwa
    };

    //==========================================================================
    // Presets
    //==========================================================================

    enum class Preset
    {
        Natural,
        Male_To_Female,
        Female_To_Male,
        Child,
        Giant,
        Robot,
        Monster,
        Whisper
    };

    //==========================================================================
    // Constructor
    //==========================================================================

    FormantShifter()
    {
        lpcAnalyzer = std::make_unique<LPCAnalyzer>();
        filterBank = std::make_unique<FormantFilterBank>();
        pitchShifter = std::make_unique<GranularPitchShifter>();
    }

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;

        filterBank->prepare(sampleRate);
        pitchShifter->prepare(sampleRate, maxBlockSize);

        // Analysis buffer
        analysisBuffer.resize(static_cast<size_t>(0.03 * sampleRate));  // 30ms
        analysisWritePos = 0;

        reset();
    }

    void reset()
    {
        filterBank->reset();
        pitchShifter->reset();
        std::fill(analysisBuffer.begin(), analysisBuffer.end(), 0.0f);
        analysisWritePos = 0;
    }

    //==========================================================================
    // Parameters
    //==========================================================================

    void setFormantShift(float semitones)
    {
        formantShift = juce::jlimit(-24.0f, 24.0f, semitones);
        filterBank->shiftAllFormants(formantShift);
    }

    void setPitchShift(float semitones)
    {
        pitchShiftAmount = juce::jlimit(-24.0f, 24.0f, semitones);
        pitchShifter->setPitchShift(pitchShiftAmount);
    }

    void setThroatLength(float factor)
    {
        // Throat length affects all formants proportionally
        throatLength = juce::jlimit(0.5f, 2.0f, factor);

        // Shorter throat = higher formants (child-like)
        // Longer throat = lower formants (giant-like)
        float shift = -12.0f * std::log2(throatLength);
        filterBank->shiftAllFormants(formantShift + shift);
    }

    void setBreathiness(float amount)
    {
        breathiness = juce::jlimit(0.0f, 1.0f, amount);
    }

    void setVowel(Vowel vowel)
    {
        currentVowel = vowel;

        // Set formant frequencies for vowel
        switch (vowel)
        {
            case Vowel::A:  // "ah"
                filterBank->setFormant(0, 800.0f, 80.0f, 1.0f);
                filterBank->setFormant(1, 1200.0f, 90.0f, 0.8f);
                filterBank->setFormant(2, 2500.0f, 120.0f, 0.5f);
                break;

            case Vowel::E:  // "eh"
                filterBank->setFormant(0, 600.0f, 70.0f, 1.0f);
                filterBank->setFormant(1, 1700.0f, 100.0f, 0.7f);
                filterBank->setFormant(2, 2400.0f, 120.0f, 0.5f);
                break;

            case Vowel::I:  // "ee"
                filterBank->setFormant(0, 300.0f, 60.0f, 1.0f);
                filterBank->setFormant(1, 2300.0f, 100.0f, 0.6f);
                filterBank->setFormant(2, 2900.0f, 120.0f, 0.4f);
                break;

            case Vowel::O:  // "oh"
                filterBank->setFormant(0, 500.0f, 70.0f, 1.0f);
                filterBank->setFormant(1, 1000.0f, 80.0f, 0.9f);
                filterBank->setFormant(2, 2300.0f, 110.0f, 0.5f);
                break;

            case Vowel::U:  // "oo"
                filterBank->setFormant(0, 350.0f, 60.0f, 1.0f);
                filterBank->setFormant(1, 800.0f, 80.0f, 0.8f);
                filterBank->setFormant(2, 2300.0f, 100.0f, 0.4f);
                break;

            case Vowel::Neutral:
            default:
                filterBank->setFormant(0, 500.0f, 80.0f, 1.0f);
                filterBank->setFormant(1, 1500.0f, 100.0f, 0.7f);
                filterBank->setFormant(2, 2500.0f, 120.0f, 0.5f);
                break;
        }

        filterBank->captureFormants();
    }

    void setMix(float mix)
    {
        wetMix = juce::jlimit(0.0f, 1.0f, mix);
    }

    void setAutoAnalysis(bool enabled)
    {
        autoAnalysis = enabled;
    }

    //==========================================================================
    // Presets
    //==========================================================================

    void loadPreset(Preset preset)
    {
        currentPreset = preset;

        switch (preset)
        {
            case Preset::Natural:
                setFormantShift(0.0f);
                setPitchShift(0.0f);
                setThroatLength(1.0f);
                setBreathiness(0.0f);
                break;

            case Preset::Male_To_Female:
                setFormantShift(4.0f);
                setPitchShift(5.0f);
                setThroatLength(0.85f);
                setBreathiness(0.1f);
                break;

            case Preset::Female_To_Male:
                setFormantShift(-4.0f);
                setPitchShift(-5.0f);
                setThroatLength(1.15f);
                setBreathiness(0.0f);
                break;

            case Preset::Child:
                setFormantShift(6.0f);
                setPitchShift(7.0f);
                setThroatLength(0.7f);
                setBreathiness(0.05f);
                break;

            case Preset::Giant:
                setFormantShift(-8.0f);
                setPitchShift(-12.0f);
                setThroatLength(1.5f);
                setBreathiness(0.0f);
                break;

            case Preset::Robot:
                setFormantShift(0.0f);
                setPitchShift(0.0f);
                setThroatLength(1.0f);
                setBreathiness(0.0f);
                // Robot effect would add additional processing
                break;

            case Preset::Monster:
                setFormantShift(-12.0f);
                setPitchShift(-7.0f);
                setThroatLength(1.8f);
                setBreathiness(0.2f);
                break;

            case Preset::Whisper:
                setFormantShift(0.0f);
                setPitchShift(0.0f);
                setThroatLength(1.0f);
                setBreathiness(0.8f);
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
                data[i] = processSample(data[i]);
                data[i] = dry * (1.0f - wetMix) + data[i] * wetMix;
            }
        }
    }

    float processSample(float input)
    {
        // Store in analysis buffer
        analysisBuffer[analysisWritePos] = input;
        analysisWritePos = (analysisWritePos + 1) % analysisBuffer.size();

        // Periodic analysis
        if (autoAnalysis && analysisWritePos == 0)
        {
            performAnalysis();
        }

        // Pitch shift (optional)
        float pitched = input;
        if (std::abs(pitchShiftAmount) > 0.01f)
        {
            pitched = pitchShifter->process(input);
        }

        // Apply formant filtering
        float formanted = filterBank->process(pitched);

        // Add breathiness (filtered noise)
        if (breathiness > 0.0f)
        {
            static std::mt19937 gen(42);
            static std::uniform_real_distribution<float> dist(-1.0f, 1.0f);
            float noise = dist(gen) * breathiness * 0.3f;

            // Envelope follow
            float envelope = std::abs(input);
            envelopeState = envelopeState * 0.99f + envelope * 0.01f;

            formanted += noise * envelopeState;
        }

        return formanted;
    }

    //==========================================================================
    // Analysis
    //==========================================================================

    void performAnalysis()
    {
        lpcAnalyzer->analyze(analysisBuffer.data(),
                             static_cast<int>(analysisBuffer.size()));

        // Find formants
        std::vector<float> freqs, bws;
        lpcAnalyzer->findFormants(freqs, bws, currentSampleRate);

        // Update filter bank with detected formants
        for (size_t i = 0; i < std::min(freqs.size(), static_cast<size_t>(5)); ++i)
        {
            filterBank->setFormant(static_cast<int>(i), freqs[i], bws[i], 1.0f - i * 0.15f);
        }

        filterBank->captureFormants();
        filterBank->shiftAllFormants(formantShift);
    }

    void captureCurrentFormants()
    {
        filterBank->captureFormants();
    }

    //==========================================================================
    // Getters
    //==========================================================================

    Preset getCurrentPreset() const { return currentPreset; }
    float getFormantShift() const { return formantShift; }
    float getPitchShift() const { return pitchShiftAmount; }

private:
    double currentSampleRate = 48000.0;

    std::unique_ptr<LPCAnalyzer> lpcAnalyzer;
    std::unique_ptr<FormantFilterBank> filterBank;
    std::unique_ptr<GranularPitchShifter> pitchShifter;

    std::vector<float> analysisBuffer;
    size_t analysisWritePos = 0;

    Preset currentPreset = Preset::Natural;
    Vowel currentVowel = Vowel::Neutral;

    float formantShift = 0.0f;
    float pitchShiftAmount = 0.0f;
    float throatLength = 1.0f;
    float breathiness = 0.0f;
    float wetMix = 1.0f;
    bool autoAnalysis = false;

    float envelopeState = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FormantShifter)
};

} // namespace DSP
} // namespace Echoelmusic
