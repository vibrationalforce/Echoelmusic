#pragma once

#include <JuceHeader.h>
#include <array>
#include <cmath>

/**
 * HarmonicExciter - Professional High-Frequency Enhancement
 *
 * Adds presence, air, and sparkle to audio:
 * - Psychoacoustic harmonic generation
 * - Multi-band excitation (Low, Mid, High, Air)
 * - Vintage tube and tape modes
 * - Dynamic harmonic enhancement
 * - Soft saturation with even/odd harmonic control
 * - Mix-ready presence boost
 *
 * Inspired by: Aphex Aural Exciter, SPL Vitalizer, Waves Vitamin
 */

namespace Echoelmusic {
namespace DSP {

//==============================================================================
// Exciter Mode
//==============================================================================

enum class ExciterMode
{
    Tube,           // Warm, even harmonics
    Tape,           // Subtle saturation with compression
    Transistor,     // Bright, odd harmonics
    Digital,        // Clean harmonic synthesis
    Vintage,        // Classic Aphex-style
    Modern          // Transparent enhancement
};

//==============================================================================
// Exciter Band
//==============================================================================

struct ExciterBand
{
    float frequency = 1000.0f;      // Crossover frequency
    float drive = 0.5f;             // Harmonic drive amount
    float harmonics = 0.5f;         // Harmonic content mix
    float mix = 0.5f;               // Wet/dry per band
    bool enabled = true;

    // Filter state
    float lpState[2] = { 0.0f, 0.0f };
    float hpState[2] = { 0.0f, 0.0f };
};

//==============================================================================
// Harmonic Exciter
//==============================================================================

class HarmonicExciter
{
public:
    //==========================================================================
    // Constructor
    //==========================================================================

    HarmonicExciter() = default;

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;

        // Initialize crossover frequencies
        bands[0].frequency = 200.0f;    // Low
        bands[1].frequency = 2000.0f;   // Mid
        bands[2].frequency = 8000.0f;   // High
        bands[3].frequency = 12000.0f;  // Air

        updateFilters();
    }

    void reset()
    {
        for (auto& band : bands)
        {
            band.lpState[0] = band.lpState[1] = 0.0f;
            band.hpState[0] = band.hpState[1] = 0.0f;
        }
    }

    //==========================================================================
    // Parameters
    //==========================================================================

    void setMode(ExciterMode mode)
    {
        currentMode = mode;
    }

    void setDrive(float drive)
    {
        masterDrive = juce::jlimit(0.0f, 1.0f, drive);
    }

    void setMix(float mix)
    {
        masterMix = juce::jlimit(0.0f, 1.0f, mix);
    }

    void setHarmonics(float amount)
    {
        harmonicAmount = juce::jlimit(0.0f, 1.0f, amount);
    }

    /** Set band-specific parameters */
    void setBandDrive(int bandIndex, float drive)
    {
        if (bandIndex >= 0 && bandIndex < 4)
            bands[bandIndex].drive = juce::jlimit(0.0f, 1.0f, drive);
    }

    void setBandEnabled(int bandIndex, bool enabled)
    {
        if (bandIndex >= 0 && bandIndex < 4)
            bands[bandIndex].enabled = enabled;
    }

    void setBandFrequency(int bandIndex, float frequency)
    {
        if (bandIndex >= 0 && bandIndex < 4)
        {
            bands[bandIndex].frequency = juce::jlimit(20.0f, 20000.0f, frequency);
            updateFilters();
        }
    }

    /** Quick presets */
    void setPresence(float amount)
    {
        // Boost 2-5kHz region
        bands[1].drive = amount * 0.7f;
        bands[2].drive = amount * 0.5f;
    }

    void setAir(float amount)
    {
        // Boost 10kHz+ region
        bands[3].drive = amount;
        bands[3].enabled = amount > 0.01f;
    }

    void setWarmth(float amount)
    {
        // Enhance low harmonics
        bands[0].drive = amount * 0.6f;
        bands[1].drive = amount * 0.3f;
    }

    //==========================================================================
    // Processing
    //==========================================================================

    void processBlock(juce::AudioBuffer<float>& buffer)
    {
        int numSamples = buffer.getNumSamples();
        int numChannels = buffer.getNumChannels();

        for (int ch = 0; ch < numChannels; ++ch)
        {
            float* channelData = buffer.getWritePointer(ch);

            for (int i = 0; i < numSamples; ++i)
            {
                float input = channelData[i];
                float output = processSample(input, ch);
                channelData[i] = output;
            }
        }
    }

    float processSample(float input, int channel = 0)
    {
        float dry = input;
        float excited = 0.0f;

        // Process each band
        float bandSignals[4];
        splitBands(input, bandSignals, channel);

        for (int b = 0; b < 4; ++b)
        {
            if (!bands[b].enabled)
            {
                excited += bandSignals[b];
                continue;
            }

            float bandDrive = bands[b].drive * masterDrive;

            // Generate harmonics based on mode
            float harmonics = generateHarmonics(bandSignals[b], bandDrive);

            // Mix original band with harmonics
            float bandMix = bands[b].mix * harmonicAmount;
            excited += bandSignals[b] + harmonics * bandMix;
        }

        // Apply soft clipping
        excited = softClip(excited);

        // Final mix
        return dry * (1.0f - masterMix) + excited * masterMix;
    }

    //==========================================================================
    // Presets
    //==========================================================================

    enum class Preset
    {
        Subtle,
        Vocal_Presence,
        Drum_Punch,
        Guitar_Sparkle,
        Master_Sheen,
        Lo_Fi_Warmth,
        Broadcast,
        Extreme
    };

    void loadPreset(Preset preset)
    {
        switch (preset)
        {
            case Preset::Subtle:
                setMode(ExciterMode::Modern);
                setDrive(0.2f);
                setHarmonics(0.3f);
                setMix(0.4f);
                break;

            case Preset::Vocal_Presence:
                setMode(ExciterMode::Tube);
                setDrive(0.4f);
                setPresence(0.6f);
                setAir(0.3f);
                setMix(0.5f);
                break;

            case Preset::Drum_Punch:
                setMode(ExciterMode::Transistor);
                setDrive(0.5f);
                bands[0].drive = 0.4f;  // Low punch
                bands[2].drive = 0.6f;  // High attack
                setMix(0.5f);
                break;

            case Preset::Guitar_Sparkle:
                setMode(ExciterMode::Tube);
                setDrive(0.5f);
                setPresence(0.7f);
                setMix(0.6f);
                break;

            case Preset::Master_Sheen:
                setMode(ExciterMode::Modern);
                setDrive(0.25f);
                setAir(0.5f);
                setHarmonics(0.4f);
                setMix(0.35f);
                break;

            case Preset::Lo_Fi_Warmth:
                setMode(ExciterMode::Tape);
                setDrive(0.6f);
                setWarmth(0.7f);
                setMix(0.6f);
                break;

            case Preset::Broadcast:
                setMode(ExciterMode::Vintage);
                setDrive(0.35f);
                setPresence(0.5f);
                setAir(0.4f);
                setMix(0.45f);
                break;

            case Preset::Extreme:
                setMode(ExciterMode::Transistor);
                setDrive(0.8f);
                setHarmonics(0.8f);
                setMix(0.7f);
                break;
        }
    }

private:
    double currentSampleRate = 48000.0;

    ExciterMode currentMode = ExciterMode::Modern;
    float masterDrive = 0.5f;
    float masterMix = 0.5f;
    float harmonicAmount = 0.5f;

    std::array<ExciterBand, 4> bands;

    // Filter coefficients
    std::array<float, 4> lpCoeffs;
    std::array<float, 4> hpCoeffs;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateFilters()
    {
        for (int i = 0; i < 4; ++i)
        {
            float omega = 2.0f * juce::MathConstants<float>::pi *
                         bands[i].frequency / static_cast<float>(currentSampleRate);
            lpCoeffs[i] = 1.0f - std::exp(-omega);
            hpCoeffs[i] = std::exp(-omega);
        }
    }

    void splitBands(float input, float* bandSignals, int channel)
    {
        float remaining = input;

        // Band 0: Low (below bands[0].frequency)
        bands[0].lpState[channel] += lpCoeffs[0] * (remaining - bands[0].lpState[channel]);
        bandSignals[0] = bands[0].lpState[channel];
        remaining -= bandSignals[0];

        // Band 1: Low-Mid
        bands[1].lpState[channel] += lpCoeffs[1] * (remaining - bands[1].lpState[channel]);
        bandSignals[1] = bands[1].lpState[channel];
        remaining -= bandSignals[1];

        // Band 2: High-Mid
        bands[2].lpState[channel] += lpCoeffs[2] * (remaining - bands[2].lpState[channel]);
        bandSignals[2] = bands[2].lpState[channel];
        remaining -= bandSignals[2];

        // Band 3: Air (remaining high frequencies)
        bandSignals[3] = remaining;
    }

    float generateHarmonics(float input, float drive)
    {
        if (drive < 0.001f)
            return 0.0f;

        float output = 0.0f;

        switch (currentMode)
        {
            case ExciterMode::Tube:
                // Even harmonics (2nd, 4th) - warm character
                output = tubeHarmonics(input, drive);
                break;

            case ExciterMode::Tape:
                // Soft saturation with compression
                output = tapeHarmonics(input, drive);
                break;

            case ExciterMode::Transistor:
                // Odd harmonics (3rd, 5th) - bright/edgy
                output = transistorHarmonics(input, drive);
                break;

            case ExciterMode::Digital:
                // Clean harmonic synthesis
                output = digitalHarmonics(input, drive);
                break;

            case ExciterMode::Vintage:
                // Classic Aphex-style
                output = vintageHarmonics(input, drive);
                break;

            case ExciterMode::Modern:
            default:
                // Transparent enhancement
                output = modernHarmonics(input, drive);
                break;
        }

        return output;
    }

    float tubeHarmonics(float input, float drive)
    {
        // Asymmetric soft clipping for even harmonics
        float x = input * (1.0f + drive * 3.0f);

        // Asymmetric waveshaping
        if (x > 0)
            return std::tanh(x * 1.2f) - input;
        else
            return std::tanh(x * 0.8f) - input;
    }

    float tapeHarmonics(float input, float drive)
    {
        // Tape-style saturation with subtle compression
        float x = input * (1.0f + drive * 2.0f);

        // Hysteresis-like behavior
        float sat = x / (1.0f + std::abs(x) * 0.5f);

        // Add subtle 2nd harmonic
        float harmonic2 = input * input * drive * 0.3f;

        return sat - input + harmonic2;
    }

    float transistorHarmonics(float input, float drive)
    {
        // Symmetric clipping for odd harmonics
        float x = input * (1.0f + drive * 4.0f);

        // Hard-ish clipping
        float clipped = std::tanh(x);

        // Emphasize 3rd harmonic
        float harmonic3 = input * input * input * drive * 0.4f;

        return clipped - input + harmonic3;
    }

    float digitalHarmonics(float input, float drive)
    {
        // Clean harmonic synthesis
        float harmonic2 = input * std::abs(input) * drive * 0.5f;
        float harmonic3 = input * input * input * drive * 0.3f;

        return harmonic2 + harmonic3;
    }

    float vintageHarmonics(float input, float drive)
    {
        // Classic exciter - rectified harmonics
        float rectified = std::abs(input);
        float shaped = rectified * rectified * drive;

        // High-pass the harmonics (only add high frequency content)
        static float hpState = 0.0f;
        float hp = shaped - hpState;
        hpState = shaped * 0.95f;

        return hp * 2.0f;
    }

    float modernHarmonics(float input, float drive)
    {
        // Transparent - dynamic harmonic enhancement
        float envelope = std::abs(input);

        // Generate harmonics proportional to envelope
        float harmonic2 = input * envelope * drive * 0.4f;
        float harmonic3 = input * envelope * envelope * drive * 0.2f;

        return harmonic2 + harmonic3;
    }

    float softClip(float input)
    {
        // Soft clipper to prevent harsh digital clipping
        if (input > 1.0f)
            return 1.0f - std::exp(-(input - 1.0f));
        else if (input < -1.0f)
            return -1.0f + std::exp(-(-input - 1.0f));
        return input;
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HarmonicExciter)
};

} // namespace DSP
} // namespace Echoelmusic
