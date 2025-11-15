#pragma once

#include <JuceHeader.h>
#include <array>

/**
 * Spectrum Analyzer
 *
 * Real-time frequency spectrum visualization with:
 * - FFT-based frequency analysis
 * - Logarithmic frequency scale
 * - Peak hold indicators
 * - Smooth interpolation
 * - Professional metering
 */
class SpectrumAnalyzer : public juce::Component,
                          private juce::Timer
{
public:
    SpectrumAnalyzer();
    ~SpectrumAnalyzer() override;

    //==========================================================================
    // Component
    //==========================================================================

    void paint (juce::Graphics&) override;
    void resized() override;

    //==========================================================================
    // Audio Data Updates
    //==========================================================================

    /** Update with new audio spectrum data (0.0 to 1.0 per bin) */
    void updateAudioData (const std::vector<float>& spectrumData);

    /** Update with raw audio buffer (will perform FFT) */
    void processAudioBuffer (const juce::AudioBuffer<float>& buffer);

private:
    //==========================================================================
    // Timer
    //==========================================================================

    void timerCallback() override;

    //==========================================================================
    // FFT
    //==========================================================================

    static constexpr int fftOrder = 11; // 2048 samples
    static constexpr int fftSize = 1 << fftOrder; // 2048
    static constexpr int numBins = 64; // Number of display bins

    juce::dsp::FFT fft {fftOrder};
    juce::dsp::WindowingFunction<float> window {fftSize, juce::dsp::WindowingFunction<float>::hann};

    std::array<float, fftSize * 2> fftData;
    int fftDataIndex = 0;

    //==========================================================================
    // Spectrum Data
    //==========================================================================

    std::array<float, numBins> spectrumBins;      // Current levels
    std::array<float, numBins> smoothedBins;      // Smoothed for display
    std::array<float, numBins> peakBins;          // Peak hold
    std::array<int, numBins> peakHoldTimers;      // Peak hold countdown

    void updateSpectrum();

    //==========================================================================
    // Rendering
    //==========================================================================

    void drawSpectrum (juce::Graphics& g);
    void drawGrid (juce::Graphics& g);
    void drawLabels (juce::Graphics& g);

    float binToFrequency (int bin) const;
    juce::String formatFrequency (float freq) const;

    //==========================================================================
    // Colors
    //==========================================================================

    juce::Colour backgroundColour {0xff1a1a1a};
    juce::Colour gridColour {0xff404040};
    juce::Colour barColour {0xff00d4ff};
    juce::Colour peakColour {0xffff6b6b};
    juce::Colour textColour {0xffffffff};

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (SpectrumAnalyzer)
};
