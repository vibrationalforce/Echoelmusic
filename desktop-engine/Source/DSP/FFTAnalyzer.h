// FFTAnalyzer.h
// Real-time FFT spectrum analysis (8 frequency bands)
// Sends analysis back to iOS via OSC

#pragma once
#include <JuceHeader.h>
#include <vector>

class FFTAnalyzer
{
public:
    FFTAnalyzer();
    ~FFTAnalyzer();

    void prepare(double sampleRate, int samplesPerBlock);
    void process(const juce::AudioBuffer<float>& buffer);
    void reset();

    // Get analysis results
    std::vector<float> getSpectrum() const;  // 8 bands in dB
    float getRMS() const;                    // RMS level in dB
    float getPeak() const;                   // Peak level in dB

private:
    // FFT
    static constexpr int fftOrder = 11;  // 2^11 = 2048 samples
    static constexpr int fftSize = 1 << fftOrder;

    juce::dsp::FFT fft;
    juce::dsp::WindowingFunction<float> window;

    std::array<float, fftSize * 2> fftData;
    juce::AudioBuffer<float> fftBuffer;

    int fifoIndex = 0;
    bool nextFFTBlockReady = false;

    // Spectrum bands (8 bands, logarithmic spacing)
    struct FrequencyBand
    {
        float lowFreq;
        float highFreq;
        float magnitude;  // in dB
    };

    std::array<FrequencyBand, 8> bands;

    // Level metering
    float currentRMS = -80.0f;
    float currentPeak = -80.0f;

    double currentSampleRate = 44100.0;

    // Helpers
    void pushNextSampleIntoFifo(float sample);
    void performFFT();
    void calculateBands();
    void calculateLevels(const juce::AudioBuffer<float>& buffer);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FFTAnalyzer)
};
