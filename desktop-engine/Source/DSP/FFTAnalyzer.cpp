// FFTAnalyzer.cpp
// Implementation of real-time FFT spectrum analysis

#include "FFTAnalyzer.h"
#include <cmath>

FFTAnalyzer::FFTAnalyzer()
    : fft(fftOrder),
      window(fftSize, juce::dsp::WindowingFunction<float>::hann)
{
    fftData.fill(0.0f);

    // Initialize 8 frequency bands (logarithmic spacing)
    // 20Hz - 20kHz range, 8 bands
    bands[0] = {20.0f, 80.0f, -80.0f};       // Sub-bass
    bands[1] = {80.0f, 200.0f, -80.0f};      // Bass
    bands[2] = {200.0f, 500.0f, -80.0f};     // Low-mids
    bands[3] = {500.0f, 1000.0f, -80.0f};    // Mids
    bands[4] = {1000.0f, 2000.0f, -80.0f};   // Upper-mids
    bands[5] = {2000.0f, 5000.0f, -80.0f};   // Presence
    bands[6] = {5000.0f, 10000.0f, -80.0f};  // Brilliance
    bands[7] = {10000.0f, 20000.0f, -80.0f}; // Air
}

FFTAnalyzer::~FFTAnalyzer()
{
}

void FFTAnalyzer::prepare(double sampleRate, int samplesPerBlock)
{
    currentSampleRate = sampleRate;
    fftBuffer.setSize(1, samplesPerBlock);
    reset();
}

void FFTAnalyzer::reset()
{
    fftData.fill(0.0f);
    fftBuffer.clear();
    fifoIndex = 0;
    nextFFTBlockReady = false;
    currentRMS = -80.0f;
    currentPeak = -80.0f;

    for (auto& band : bands)
    {
        band.magnitude = -80.0f;
    }
}

void FFTAnalyzer::process(const juce::AudioBuffer<float>& buffer)
{
    // Calculate RMS and Peak levels
    calculateLevels(buffer);

    // Process samples through FFT FIFO
    const int numSamples = buffer.getNumSamples();
    const float* channelData = buffer.getReadPointer(0);  // Mono or left channel

    for (int i = 0; i < numSamples; ++i)
    {
        pushNextSampleIntoFifo(channelData[i]);

        if (nextFFTBlockReady)
        {
            performFFT();
            calculateBands();
            nextFFTBlockReady = false;
        }
    }
}

void FFTAnalyzer::pushNextSampleIntoFifo(float sample)
{
    // Add sample to FFT data buffer
    if (fifoIndex < fftSize)
    {
        fftData[fifoIndex++] = sample;

        if (fifoIndex == fftSize)
        {
            nextFFTBlockReady = true;
            fifoIndex = 0;
        }
    }
}

void FFTAnalyzer::performFFT()
{
    // Apply windowing function
    window.multiplyWithWindowingTable(fftData.data(), fftSize);

    // Perform forward FFT
    fft.performFrequencyOnlyForwardTransform(fftData.data());
}

void FFTAnalyzer::calculateBands()
{
    const float binWidth = static_cast<float>(currentSampleRate) / static_cast<float>(fftSize);

    for (auto& band : bands)
    {
        // Find bin range for this band
        int startBin = static_cast<int>(std::ceil(band.lowFreq / binWidth));
        int endBin = static_cast<int>(std::floor(band.highFreq / binWidth));

        // Clamp to valid range
        startBin = juce::jlimit(0, fftSize / 2, startBin);
        endBin = juce::jlimit(0, fftSize / 2, endBin);

        if (startBin >= endBin)
        {
            band.magnitude = -80.0f;
            continue;
        }

        // Calculate average magnitude in this band
        float sum = 0.0f;
        int count = 0;

        for (int bin = startBin; bin < endBin; ++bin)
        {
            sum += fftData[bin];
            count++;
        }

        if (count > 0)
        {
            float average = sum / static_cast<float>(count);

            // Convert to dB (with floor at -80dB)
            float dB = -80.0f;
            if (average > 0.0f)
            {
                dB = 20.0f * std::log10(average);
                dB = juce::jlimit(-80.0f, 0.0f, dB);
            }

            band.magnitude = dB;
        }
        else
        {
            band.magnitude = -80.0f;
        }
    }
}

void FFTAnalyzer::calculateLevels(const juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numSamples == 0 || numChannels == 0)
    {
        currentRMS = -80.0f;
        currentPeak = -80.0f;
        return;
    }

    // Calculate RMS and Peak from all channels
    float sumSquares = 0.0f;
    float peakValue = 0.0f;

    for (int ch = 0; ch < numChannels; ++ch)
    {
        const float* channelData = buffer.getReadPointer(ch);

        for (int i = 0; i < numSamples; ++i)
        {
            const float sample = channelData[i];
            sumSquares += sample * sample;
            peakValue = std::max(peakValue, std::abs(sample));
        }
    }

    // RMS calculation
    float rms = std::sqrt(sumSquares / static_cast<float>(numSamples * numChannels));

    // Convert to dB
    if (rms > 0.0f)
    {
        currentRMS = 20.0f * std::log10(rms);
        currentRMS = juce::jlimit(-80.0f, 0.0f, currentRMS);
    }
    else
    {
        currentRMS = -80.0f;
    }

    if (peakValue > 0.0f)
    {
        currentPeak = 20.0f * std::log10(peakValue);
        currentPeak = juce::jlimit(-80.0f, 0.0f, currentPeak);
    }
    else
    {
        currentPeak = -80.0f;
    }
}

std::vector<float> FFTAnalyzer::getSpectrum() const
{
    std::vector<float> spectrum;
    spectrum.reserve(8);

    for (const auto& band : bands)
    {
        spectrum.push_back(band.magnitude);
    }

    return spectrum;
}

float FFTAnalyzer::getRMS() const
{
    return currentRMS;
}

float FFTAnalyzer::getPeak() const
{
    return currentPeak;
}
