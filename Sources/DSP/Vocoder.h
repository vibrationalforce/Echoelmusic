#pragma once

#include <JuceHeader.h>
#include "../Core/DSPOptimizations.h"

/**
 * Vocoder - Classic Carrier/Modulator Synthesis
 *
 * Creates robotic/synthetic vocal effects through spectral envelope transfer:
 * - 8-32 frequency bands (adjustable)
 * - Internal carrier oscillator (saw/square/noise)
 * - External carrier input support
 * - Band width control (narrow = more robotic)
 * - Attack/Release per band
 * - Sibilance preservation
 *
 * Used on: Daft Punk, Kraftwerk, Herbie Hancock, EDM vocals
 */
class Vocoder
{
public:
    Vocoder();
    ~Vocoder();

    //==============================================================================
    // DSP Lifecycle
    void prepare(double sampleRate, int maximumBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Parameters

    /** Set number of bands (8-32) */
    void setBandCount(int bands);

    /** Set carrier type (0=saw, 1=square, 2=noise, 3=external) */
    void setCarrierType(int type);

    /** Set carrier frequency (50-500 Hz for internal oscillator) */
    void setCarrierFrequency(float hz);

    /** Set band width (0-1): 0=narrow/robotic, 1=wide/natural */
    void setBandWidth(float width);

    /** Set attack time (0.1-100 ms) */
    void setAttack(float ms);

    /** Set release time (10-1000 ms) */
    void setRelease(float ms);

    /** Set sibilance preservation (0-1): preserve high-freq detail */
    void setSibilance(float amount);

    /** Set mix (0-1): dry/wet blend */
    void setMix(float mix);

private:
    //==============================================================================
    // Vocoder Band (Bandpass + Envelope Follower)
    struct VocoderBand
    {
        // Bandpass filter (for carrier and modulator)
        juce::dsp::IIR::Filter<float> carrierFilter;
        juce::dsp::IIR::Filter<float> modulatorFilter;

        // Envelope follower
        float envelope = 0.0f;
        float attackCoeff = 0.0f;
        float releaseCoeff = 0.0f;

        void prepare(const juce::dsp::ProcessSpec& spec)
        {
            carrierFilter.prepare(spec);
            modulatorFilter.prepare(spec);
        }

        void reset()
        {
            carrierFilter.reset();
            modulatorFilter.reset();
            envelope = 0.0f;
        }

        void setCoefficients(float centerFreq, float Q, float sampleRate)
        {
            auto coeffs = juce::dsp::IIR::Coefficients<float>::makeBandPass(sampleRate, centerFreq, Q);
            carrierFilter.coefficients = coeffs;
            modulatorFilter.coefficients = coeffs;
        }

        void setEnvelopeParams(float attack, float release, float sampleRate)
        {
            attackCoeff = 1.0f - Echoel::DSP::FastMath::fastExp(-1.0f / (attack * 0.001f * sampleRate));
            releaseCoeff = 1.0f - Echoel::DSP::FastMath::fastExp(-1.0f / (release * 0.001f * sampleRate));
        }

        float process(float carrierSample, float modulatorSample)
        {
            // Filter both signals
            float filteredCarrier = carrierFilter.processSample(carrierSample);
            float filteredModulator = modulatorFilter.processSample(modulatorSample);

            // Extract envelope from modulator
            float modulatorLevel = std::abs(filteredModulator);

            if (modulatorLevel > envelope)
                envelope += attackCoeff * (modulatorLevel - envelope);
            else
                envelope += releaseCoeff * (modulatorLevel - envelope);

            // Apply envelope to carrier
            return filteredCarrier * envelope;
        }
    };

    std::array<VocoderBand, 32> bandsL;
    std::array<VocoderBand, 32> bandsR;

    //==============================================================================
    // Internal Carrier Oscillator
    struct CarrierOscillator
    {
        float phase = 0.0f;
        float frequency = 110.0f;  // Hz
        float sampleRate = 44100.0f;
        int type = 0;  // 0=saw, 1=square, 2=noise
        juce::Random random;

        void setSampleRate(float sr) { sampleRate = sr; }
        void setFrequency(float hz) { frequency = juce::jlimit(50.0f, 500.0f, hz); }
        void setType(int t) { type = juce::jlimit(0, 2, t); }

        float generate()
        {
            if (type == 0)  // Sawtooth
            {
                float output = phase * 2.0f - 1.0f;
                phase += frequency / sampleRate;
                if (phase >= 1.0f) phase -= 1.0f;
                return output;
            }
            else if (type == 1)  // Square
            {
                float output = (phase < 0.5f) ? 1.0f : -1.0f;
                phase += frequency / sampleRate;
                if (phase >= 1.0f) phase -= 1.0f;
                return output;
            }
            else  // White Noise
            {
                return random.nextFloat() * 2.0f - 1.0f;
            }
        }

        void reset() { phase = 0.0f; }
    };

    CarrierOscillator oscillatorL, oscillatorR;

    //==============================================================================
    // Sibilance Preservation (High-Pass + Mix)
    struct SibilancePreserver
    {
        juce::dsp::IIR::Filter<float> highpass;
        float amount = 0.3f;

        void prepare(const juce::dsp::ProcessSpec& spec)
        {
            highpass.prepare(spec);
            // High-pass at 6kHz to preserve sibilants
            auto coeffs = juce::dsp::IIR::Coefficients<float>::makeHighPass(spec.sampleRate, 6000.0f, 0.707f);
            highpass.coefficients = coeffs;
        }

        void reset() { highpass.reset(); }

        float process(float vocodedSample, float originalSample)
        {
            float sibilance = highpass.processSample(originalSample);
            return vocodedSample + sibilance * amount;
        }
    };

    SibilancePreserver sibilanceL, sibilanceR;

    //==============================================================================
    // Calculate band frequencies (exponential spacing)
    void updateBandFrequencies()
    {
        float minFreq = 80.0f;   // Hz
        float maxFreq = 8000.0f; // Hz
        float ratio = std::pow(maxFreq / minFreq, 1.0f / (currentBandCount - 1));

        for (int b = 0; b < currentBandCount; ++b)
        {
            float centerFreq = minFreq * std::pow(ratio, b);
            float Q = juce::jmap(currentBandWidth, 0.0f, 1.0f, 15.0f, 3.0f);

            bandsL[b].setCoefficients(centerFreq, Q, static_cast<float>(currentSampleRate));
            bandsR[b].setCoefficients(centerFreq, Q, static_cast<float>(currentSampleRate));

            bandsL[b].setEnvelopeParams(currentAttack, currentRelease, static_cast<float>(currentSampleRate));
            bandsR[b].setEnvelopeParams(currentAttack, currentRelease, static_cast<float>(currentSampleRate));
        }
    }

    //==============================================================================
    // Dry Buffer (pre-allocated to avoid allocations in audio thread)
    juce::AudioBuffer<float> dryBuffer;

    //==============================================================================
    // Parameters
    int currentBandCount = 16;
    int carrierType = 0;  // 0=saw, 1=square, 2=noise, 3=external
    float carrierFrequency = 110.0f;
    float currentBandWidth = 0.5f;
    float currentAttack = 10.0f;   // ms
    float currentRelease = 100.0f; // ms
    float currentSibilance = 0.3f;
    float currentMix = 0.8f;

    double currentSampleRate = 44100.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (Vocoder)
};
