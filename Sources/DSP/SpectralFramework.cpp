#include "SpectralFramework.h"
#include <algorithm>
#include <numeric>

//==============================================================================
// Constructor / Destructor
//==============================================================================

SpectralFramework::SpectralFramework(FFTSize size, WindowType windowType)
    : fftOrder(static_cast<int>(size))
    , fftSize(1 << fftOrder)
    , currentWindowType(windowType)
{
    hopSize = static_cast<int>(fftSize * (1.0f - overlapFactor));
    updateFFTEngine();
    updateWindow();
}

//==============================================================================
// Configuration
//==============================================================================

void SpectralFramework::setFFTSize(FFTSize size)
{
    fftOrder = static_cast<int>(size);
    fftSize = 1 << fftOrder;
    hopSize = static_cast<int>(fftSize * (1.0f - overlapFactor));
    updateFFTEngine();
    updateWindow();
}

void SpectralFramework::setWindowType(WindowType type)
{
    currentWindowType = type;
    updateWindow();
}

void SpectralFramework::setOverlapFactor(float factor)
{
    overlapFactor = juce::jlimit(0.0f, 0.9f, factor);
    hopSize = static_cast<int>(fftSize * (1.0f - overlapFactor));
}

//==============================================================================
// Processing
//==============================================================================

void SpectralFramework::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;
    fftBuffer.resize(fftSize * 2, 0.0f);
}

void SpectralFramework::reset()
{
    std::fill(fftBuffer.begin(), fftBuffer.end(), 0.0f);
}

void SpectralFramework::performForwardFFT(const float* timeDomain, SpectralData& output)
{
    output.resize(getNumBins());

    // Copy input and apply window
    std::copy(timeDomain, timeDomain + fftSize, fftBuffer.begin());
    applyWindow(fftBuffer.data());

    // Zero-pad second half
    std::fill(fftBuffer.begin() + fftSize, fftBuffer.end(), 0.0f);

    // Perform FFT
    forwardFFT->performFrequencyOnlyForwardTransform(fftBuffer.data());

    // Extract complex bins (first half + Nyquist)
    int numBins = getNumBins();
    for (int i = 0; i < numBins; ++i)
    {
        float real = fftBuffer[i * 2];
        float imag = fftBuffer[i * 2 + 1];
        output.bins[i] = std::complex<float>(real, imag);
        output.magnitude[i] = std::sqrt(real * real + imag * imag);
        output.phase[i] = std::atan2(imag, real);
    }
}

void SpectralFramework::performInverseFFT(const SpectralData& input, float* timeDomain)
{
    int numBins = getNumBins();

    // Reconstruct full spectrum (conjugate symmetry)
    for (int i = 0; i < numBins; ++i)
    {
        fftBuffer[i * 2] = input.bins[i].real();
        fftBuffer[i * 2 + 1] = input.bins[i].imag();
    }

    // Mirror for negative frequencies (conjugate symmetry)
    for (int i = numBins; i < fftSize; ++i)
    {
        int mirrorIndex = fftSize - i;
        fftBuffer[i * 2] = fftBuffer[mirrorIndex * 2];          // Real stays same
        fftBuffer[i * 2 + 1] = -fftBuffer[mirrorIndex * 2 + 1]; // Imaginary negated
    }

    // Perform inverse FFT
    inverseFFT->performRealOnlyInverseTransform(fftBuffer.data());

    // Copy output
    std::copy(fftBuffer.begin(), fftBuffer.begin() + fftSize, timeDomain);
}

void SpectralFramework::extractMagnitudePhase(const std::vector<std::complex<float>>& bins,
                                               std::vector<float>& magnitude,
                                               std::vector<float>& phase)
{
    int numBins = static_cast<int>(bins.size());
    magnitude.resize(numBins);
    phase.resize(numBins);

    for (int i = 0; i < numBins; ++i)
    {
        magnitude[i] = std::abs(bins[i]);
        phase[i] = std::arg(bins[i]);
    }
}

void SpectralFramework::reconstructFromMagnitudePhase(const std::vector<float>& magnitude,
                                                       const std::vector<float>& phase,
                                                       std::vector<std::complex<float>>& bins)
{
    int numBins = static_cast<int>(magnitude.size());
    bins.resize(numBins);

    for (int i = 0; i < numBins; ++i)
    {
        float real = magnitude[i] * std::cos(phase[i]);
        float imag = magnitude[i] * std::sin(phase[i]);
        bins[i] = std::complex<float>(real, imag);
    }
}

//==============================================================================
// Frequency Utilities
//==============================================================================

float SpectralFramework::binToFrequency(int bin) const
{
    return static_cast<float>(bin * currentSampleRate / fftSize);
}

int SpectralFramework::frequencyToBin(float frequency) const
{
    return static_cast<int>(frequency * fftSize / currentSampleRate);
}

float SpectralFramework::frequencyToBark(float frequency)
{
    // Traunmüller formula
    return 26.81f * frequency / (1960.0f + frequency) - 0.53f;
}

float SpectralFramework::barkToFrequency(float bark)
{
    // Inverse Traunmüller formula
    return 1960.0f * (bark + 0.53f) / (26.28f - bark);
}

float SpectralFramework::frequencyToERB(float frequency)
{
    // ERB = 24.7 * (4.37 * f + 1)
    return 24.7f * (4.37f * frequency / 1000.0f + 1.0f);
}

float SpectralFramework::erbToFrequency(float erb)
{
    return (erb / 24.7f - 1.0f) * 1000.0f / 4.37f;
}

int SpectralFramework::getNumERBBands(float minFreq, float maxFreq)
{
    return static_cast<int>(frequencyToERB(maxFreq) - frequencyToERB(minFreq));
}

//==============================================================================
// Spectral Filtering
//==============================================================================

void SpectralFramework::applySpectralGain(SpectralData& data,
                                          int startBin,
                                          int endBin,
                                          float gainDb)
{
    float gainLinear = juce::Decibels::decibelsToGain(gainDb);

    for (int i = startBin; i <= endBin && i < data.numBins; ++i)
    {
        data.bins[i] *= gainLinear;
        data.magnitude[i] *= gainLinear;
    }
}

void SpectralFramework::applySpectralGainCurve(SpectralData& data,
                                               const std::vector<float>& gainCurveDb)
{
    int numBins = std::min(data.numBins, static_cast<int>(gainCurveDb.size()));

    for (int i = 0; i < numBins; ++i)
    {
        float gainLinear = juce::Decibels::decibelsToGain(gainCurveDb[i]);
        data.bins[i] *= gainLinear;
        data.magnitude[i] *= gainLinear;
    }
}

void SpectralFramework::applySpectralGate(SpectralData& data,
                                          float thresholdDb,
                                          float ratio)
{
    float thresholdLinear = juce::Decibels::decibelsToGain(thresholdDb);

    for (int i = 0; i < data.numBins; ++i)
    {
        if (data.magnitude[i] < thresholdLinear)
        {
            float reduction = std::pow(data.magnitude[i] / thresholdLinear, 1.0f / ratio);
            data.bins[i] *= reduction;
            data.magnitude[i] *= reduction;
        }
    }
}

void SpectralFramework::smoothSpectrum(std::vector<float>& spectrum, int windowSize)
{
    if (windowSize <= 1) return;

    std::vector<float> smoothed(spectrum.size());
    int halfWindow = windowSize / 2;

    for (size_t i = 0; i < spectrum.size(); ++i)
    {
        float sum = 0.0f;
        int count = 0;

        for (int j = -halfWindow; j <= halfWindow; ++j)
        {
            int index = static_cast<int>(i) + j;
            if (index >= 0 && index < static_cast<int>(spectrum.size()))
            {
                sum += spectrum[index];
                ++count;
            }
        }

        smoothed[i] = sum / static_cast<float>(count);
    }

    spectrum = smoothed;
}

//==============================================================================
// Psychoacoustic Utilities
//==============================================================================

float SpectralFramework::getAWeighting(float frequency)
{
    // A-weighting formula (simplified)
    float f2 = frequency * frequency;
    float numerator = 12194.0f * 12194.0f * f2 * f2;
    float denominator = (f2 + 20.6f * 20.6f) *
                        std::sqrt((f2 + 107.7f * 107.7f) * (f2 + 737.9f * 737.9f)) *
                        (f2 + 12194.0f * 12194.0f);

    return 20.0f * std::log10(numerator / denominator) + 2.0f;
}

int SpectralFramework::getCriticalBand(float frequency)
{
    float bark = frequencyToBark(frequency);
    return static_cast<int>(std::round(bark));
}

std::vector<float> SpectralFramework::calculateMaskingThreshold(
    const std::vector<float>& magnitude,
    double sampleRate)
{
    // Simplified psychoacoustic masking model
    std::vector<float> threshold(magnitude.size());

    for (size_t i = 0; i < magnitude.size(); ++i)
    {
        float freq = static_cast<float>(i * sampleRate / (magnitude.size() * 2));
        float maskingLevel = magnitude[i] * 0.1f;  // Simplified

        // Apply spreading function (simplified)
        for (size_t j = 0; j < magnitude.size(); ++j)
        {
            float distance = std::abs(static_cast<float>(i - j));
            float spreading = std::exp(-distance * 0.1f);
            threshold[j] = std::max(threshold[j], maskingLevel * spreading);
        }
    }

    return threshold;
}

std::vector<float> SpectralFramework::detectTonalComponents(
    const std::vector<float>& magnitude,
    float tonalityThreshold)
{
    std::vector<float> tonality(magnitude.size(), 0.0f);

    for (size_t i = 2; i < magnitude.size() - 2; ++i)
    {
        float localAverage = (magnitude[i-2] + magnitude[i-1] + magnitude[i+1] + magnitude[i+2]) / 4.0f;
        float ratio = magnitude[i] / (localAverage + 1e-8f);

        tonality[i] = (ratio > tonalityThreshold) ? 1.0f : 0.0f;
    }

    return tonality;
}

//==============================================================================
// Advanced Analysis
//==============================================================================

std::vector<SpectralFramework::SpectralPeak> SpectralFramework::detectPeaks(
    const SpectralData& data,
    float minMagnitude,
    int minDistance)
{
    std::vector<SpectralPeak> peaks;

    for (int i = minDistance; i < data.numBins - minDistance; ++i)
    {
        if (data.magnitude[i] < minMagnitude)
            continue;

        // Check if local maximum
        bool isPeak = true;
        for (int j = -minDistance; j <= minDistance; ++j)
        {
            if (j != 0 && data.magnitude[i + j] >= data.magnitude[i])
            {
                isPeak = false;
                break;
            }
        }

        if (isPeak)
        {
            SpectralPeak peak;
            peak.bin = i;
            peak.frequency = binToFrequency(i);
            peak.magnitude = data.magnitude[i];
            peak.phase = data.phase[i];
            peaks.push_back(peak);
        }
    }

    return peaks;
}

float SpectralFramework::calculateSpectralCentroid(const SpectralData& data, double sampleRate)
{
    float numerator = 0.0f;
    float denominator = 0.0f;

    for (int i = 0; i < data.numBins; ++i)
    {
        float freq = static_cast<float>(i * sampleRate / (data.numBins * 2));
        numerator += freq * data.magnitude[i];
        denominator += data.magnitude[i];
    }

    return (denominator > 0.0f) ? (numerator / denominator) : 0.0f;
}

float SpectralFramework::calculateSpectralFlatness(const std::vector<float>& magnitude)
{
    float geometricMean = 1.0f;
    float arithmeticMean = 0.0f;
    int count = 0;

    for (float mag : magnitude)
    {
        if (mag > 1e-8f)
        {
            geometricMean *= mag;
            arithmeticMean += mag;
            ++count;
        }
    }

    if (count == 0) return 0.0f;

    geometricMean = std::pow(geometricMean, 1.0f / count);
    arithmeticMean /= count;

    return (arithmeticMean > 0.0f) ? (geometricMean / arithmeticMean) : 0.0f;
}

float SpectralFramework::calculateSpectralCrest(const std::vector<float>& magnitude)
{
    if (magnitude.empty()) return 0.0f;

    float maxMag = *std::max_element(magnitude.begin(), magnitude.end());
    float avgMag = std::accumulate(magnitude.begin(), magnitude.end(), 0.0f) / magnitude.size();

    return (avgMag > 0.0f) ? (maxMag / avgMag) : 0.0f;
}

float SpectralFramework::calculateSpectralRolloff(const SpectralData& data,
                                                   double sampleRate,
                                                   float percentage)
{
    float totalEnergy = 0.0f;
    for (int i = 0; i < data.numBins; ++i)
    {
        totalEnergy += data.magnitude[i] * data.magnitude[i];
    }

    float targetEnergy = totalEnergy * percentage;
    float cumulativeEnergy = 0.0f;

    for (int i = 0; i < data.numBins; ++i)
    {
        cumulativeEnergy += data.magnitude[i] * data.magnitude[i];
        if (cumulativeEnergy >= targetEnergy)
        {
            return static_cast<float>(i * sampleRate / (data.numBins * 2));
        }
    }

    return static_cast<float>(sampleRate / 2.0);  // Nyquist
}

//==============================================================================
// Internal Methods
//==============================================================================

void SpectralFramework::updateFFTEngine()
{
    forwardFFT = std::make_unique<juce::dsp::FFT>(fftOrder);
    inverseFFT = std::make_unique<juce::dsp::FFT>(fftOrder);
    fftBuffer.resize(fftSize * 2, 0.0f);
}

void SpectralFramework::updateWindow()
{
    windowBuffer.resize(fftSize);

    juce::dsp::WindowingFunction<float>::WindowingMethod method;

    switch (currentWindowType)
    {
        case WindowType::Hann:
            method = juce::dsp::WindowingFunction<float>::hann;
            break;
        case WindowType::Hamming:
            method = juce::dsp::WindowingFunction<float>::hamming;
            break;
        case WindowType::Blackman:
            method = juce::dsp::WindowingFunction<float>::blackman;
            break;
        case WindowType::BlackmanHarris:
            method = juce::dsp::WindowingFunction<float>::blackmanHarris;
            break;
        case WindowType::Rectangular:
            method = juce::dsp::WindowingFunction<float>::rectangular;
            break;
        default:
            method = juce::dsp::WindowingFunction<float>::hann;
            break;
    }

    window = std::make_unique<juce::dsp::WindowingFunction<float>>(fftSize, method);
}

void SpectralFramework::applyWindow(float* data)
{
    window->multiplyWithWindowingTable(data, fftSize);
}
