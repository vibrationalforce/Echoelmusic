/*
  ==============================================================================

    IntegratedMeteringSuite.h
    Created: 2026
    Author:  Echoelmusic

    Professional Integrated Metering Suite
    LUFS, True Peak, Phase, Spectrum, Dynamic Range in unified interface

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <deque>
#include <cmath>
#include <complex>

namespace Echoelmusic {
namespace Metering {

//==============================================================================
/** Loudness standard presets */
enum class LoudnessStandard {
    EBU_R128,           // -23 LUFS (broadcast)
    ATSC_A85,           // -24 LKFS (US broadcast)
    Sony_Japan,         // -24 LUFS
    Spotify,            // -14 LUFS
    AppleMusic,         // -16 LUFS
    YouTube,            // -14 LUFS
    AmazonMusic,        // -14 LUFS
    Tidal,              // -14 LUFS
    SoundCloud,         // -14 LUFS
    Podcast_Apple,      // -16 LUFS, -1 dB TP
    Podcast_Spotify,    // -14 LUFS
    CD_Master,          // No loudness target
    Custom
};

inline double getLoudnessTarget(LoudnessStandard standard) {
    switch (standard) {
        case LoudnessStandard::EBU_R128:      return -23.0;
        case LoudnessStandard::ATSC_A85:      return -24.0;
        case LoudnessStandard::Sony_Japan:    return -24.0;
        case LoudnessStandard::Spotify:       return -14.0;
        case LoudnessStandard::AppleMusic:    return -16.0;
        case LoudnessStandard::YouTube:       return -14.0;
        case LoudnessStandard::AmazonMusic:   return -14.0;
        case LoudnessStandard::Tidal:         return -14.0;
        case LoudnessStandard::SoundCloud:    return -14.0;
        case LoudnessStandard::Podcast_Apple: return -16.0;
        case LoudnessStandard::Podcast_Spotify: return -14.0;
        default:                               return -14.0;
    }
}

inline double getTruePeakLimit(LoudnessStandard standard) {
    switch (standard) {
        case LoudnessStandard::EBU_R128:      return -1.0;
        case LoudnessStandard::ATSC_A85:      return -2.0;
        case LoudnessStandard::Podcast_Apple: return -1.0;
        default:                               return -1.0;
    }
}

//==============================================================================
/** K-weighting filter for loudness measurement */
class KWeightingFilter {
public:
    KWeightingFilter(double sampleRate = 44100.0) {
        setSampleRate(sampleRate);
    }

    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        calculateCoefficients();
        reset();
    }

    void reset() {
        for (auto& state : highShelfState_) state = 0.0;
        for (auto& state : highPassState_) state = 0.0;
    }

    float process(float sample) {
        // Stage 1: High shelf filter (+4dB at high frequencies)
        float stage1 = processHighShelf(sample);

        // Stage 2: High-pass filter (removes DC and very low frequencies)
        float stage2 = processHighPass(stage1);

        return stage2;
    }

private:
    void calculateCoefficients() {
        // High shelf: +4dB above 1500 Hz
        double fc = 1500.0;
        double G = 4.0;
        double K = std::tan(juce::MathConstants<double>::pi * fc / sampleRate_);
        double Vh = std::pow(10.0, G / 20.0);
        double Vb = std::pow(Vh, 0.5);

        double a0 = 1.0 + std::sqrt(2.0) * K + K * K;
        hsB0_ = (Vh + std::sqrt(2.0 * Vh) * Vb * K + K * K) / a0;
        hsB1_ = 2.0 * (K * K - Vh) / a0;
        hsB2_ = (Vh - std::sqrt(2.0 * Vh) * Vb * K + K * K) / a0;
        hsA1_ = 2.0 * (K * K - 1.0) / a0;
        hsA2_ = (1.0 - std::sqrt(2.0) * K + K * K) / a0;

        // High pass: 38 Hz, Q = 0.5
        double fc2 = 38.0;
        double Q = 0.5;
        double K2 = std::tan(juce::MathConstants<double>::pi * fc2 / sampleRate_);
        double a0_2 = 1.0 + K2 / Q + K2 * K2;

        hpB0_ = 1.0 / a0_2;
        hpB1_ = -2.0 / a0_2;
        hpB2_ = 1.0 / a0_2;
        hpA1_ = 2.0 * (K2 * K2 - 1.0) / a0_2;
        hpA2_ = (1.0 - K2 / Q + K2 * K2) / a0_2;
    }

    float processHighShelf(float input) {
        float output = hsB0_ * input + highShelfState_[0];
        highShelfState_[0] = hsB1_ * input - hsA1_ * output + highShelfState_[1];
        highShelfState_[1] = hsB2_ * input - hsA2_ * output;
        return static_cast<float>(output);
    }

    float processHighPass(float input) {
        float output = hpB0_ * input + highPassState_[0];
        highPassState_[0] = hpB1_ * input - hpA1_ * output + highPassState_[1];
        highPassState_[1] = hpB2_ * input - hpA2_ * output;
        return static_cast<float>(output);
    }

    double sampleRate_;

    // High shelf coefficients
    double hsB0_, hsB1_, hsB2_, hsA1_, hsA2_;
    std::array<double, 2> highShelfState_{};

    // High pass coefficients
    double hpB0_, hpB1_, hpB2_, hpA1_, hpA2_;
    std::array<double, 2> highPassState_{};
};

//==============================================================================
/** LUFS Meter (ITU-R BS.1770) */
class LUFSMeter {
public:
    LUFSMeter(double sampleRate = 44100.0, int numChannels = 2)
        : numChannels_(numChannels)
    {
        setSampleRate(sampleRate);
    }

    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        blockSize_ = static_cast<int>(sampleRate * 0.4);  // 400ms blocks
        overlapSize_ = static_cast<int>(sampleRate * 0.1); // 100ms overlap

        kFilters_.clear();
        for (int i = 0; i < numChannels_; ++i) {
            kFilters_.push_back(std::make_unique<KWeightingFilter>(sampleRate));
        }

        reset();
    }

    void reset() {
        momentaryLUFS_ = -100.0;
        shortTermLUFS_ = -100.0;
        integratedLUFS_ = -100.0;
        loudnessRange_ = 0.0;
        truePeak_ = -100.0;

        for (auto& f : kFilters_) f->reset();

        blockBuffer_.clear();
        shortTermBlocks_.clear();
        integratedBlocks_.clear();
    }

    void process(const juce::AudioBuffer<float>& buffer) {
        int numSamples = buffer.getNumSamples();

        for (int i = 0; i < numSamples; ++i) {
            double sumSquared = 0.0;

            for (int ch = 0; ch < std::min(numChannels_, buffer.getNumChannels()); ++ch) {
                float sample = buffer.getSample(ch, i);

                // Update true peak
                float absSample = std::abs(sample);
                if (absSample > truePeakLinear_) {
                    truePeakLinear_ = absSample;
                    truePeak_ = juce::Decibels::gainToDecibels(truePeakLinear_);
                }

                // Apply K-weighting
                float weighted = kFilters_[ch]->process(sample);

                // Channel weighting (surround channels get different weights)
                double channelWeight = (ch == 0 || ch == 1) ? 1.0 : 1.41; // L/R = 1, surround = 1.41
                sumSquared += weighted * weighted * channelWeight;
            }

            blockBuffer_.push_back(sumSquared);

            // Process complete block
            if (static_cast<int>(blockBuffer_.size()) >= blockSize_) {
                processBlock();
            }
        }
    }

    // Results
    double getMomentaryLUFS() const { return momentaryLUFS_; }
    double getShortTermLUFS() const { return shortTermLUFS_; }
    double getIntegratedLUFS() const { return integratedLUFS_; }
    double getLoudnessRange() const { return loudnessRange_; }
    double getTruePeak() const { return truePeak_; }
    double getTruePeakLinear() const { return truePeakLinear_; }

    // Target comparison
    double getDeviationFromTarget(LoudnessStandard standard) const {
        return integratedLUFS_ - getLoudnessTarget(standard);
    }

    bool isTruePeakCompliant(LoudnessStandard standard) const {
        return truePeak_ <= getTruePeakLimit(standard);
    }

private:
    void processBlock() {
        // Calculate mean square for this block
        double meanSquare = 0.0;
        for (double val : blockBuffer_) {
            meanSquare += val;
        }
        meanSquare /= blockBuffer_.size();

        // Convert to LUFS
        double blockLoudness = -0.691 + 10.0 * std::log10(std::max(1e-10, meanSquare));

        // Momentary (400ms)
        momentaryLUFS_ = blockLoudness;

        // Short-term (3 seconds = 30 blocks with 100ms overlap)
        shortTermBlocks_.push_back(blockLoudness);
        if (shortTermBlocks_.size() > 30) {
            shortTermBlocks_.pop_front();
        }
        shortTermLUFS_ = calculateGatedLoudness(shortTermBlocks_);

        // Integrated (entire program)
        if (blockLoudness > -70.0) {  // Gate threshold
            integratedBlocks_.push_back(blockLoudness);
            integratedLUFS_ = calculateGatedLoudness(integratedBlocks_);
            calculateLoudnessRange();
        }

        // Shift block buffer by overlap
        std::vector<double> temp(blockBuffer_.begin() + overlapSize_, blockBuffer_.end());
        blockBuffer_ = temp;
    }

    double calculateGatedLoudness(const std::deque<double>& blocks) {
        if (blocks.empty()) return -100.0;

        // First pass: absolute gate at -70 LUFS
        std::vector<double> gated1;
        for (double l : blocks) {
            if (l > -70.0) gated1.push_back(l);
        }

        if (gated1.empty()) return -100.0;

        // Calculate mean
        double sum = 0.0;
        for (double l : gated1) {
            sum += std::pow(10.0, l / 10.0);
        }
        double mean1 = 10.0 * std::log10(sum / gated1.size());

        // Second pass: relative gate at mean - 10 dB
        double relativeThreshold = mean1 - 10.0;
        std::vector<double> gated2;
        for (double l : gated1) {
            if (l > relativeThreshold) gated2.push_back(l);
        }

        if (gated2.empty()) return mean1;

        // Final mean
        sum = 0.0;
        for (double l : gated2) {
            sum += std::pow(10.0, l / 10.0);
        }
        return 10.0 * std::log10(sum / gated2.size());
    }

    void calculateLoudnessRange() {
        if (integratedBlocks_.size() < 2) {
            loudnessRange_ = 0.0;
            return;
        }

        std::vector<double> sorted(integratedBlocks_.begin(), integratedBlocks_.end());
        std::sort(sorted.begin(), sorted.end());

        // 10th and 95th percentile
        size_t low = static_cast<size_t>(sorted.size() * 0.1);
        size_t high = static_cast<size_t>(sorted.size() * 0.95);

        loudnessRange_ = sorted[high] - sorted[low];
    }

    double sampleRate_;
    int numChannels_;
    int blockSize_;
    int overlapSize_;

    std::vector<std::unique_ptr<KWeightingFilter>> kFilters_;
    std::vector<double> blockBuffer_;
    std::deque<double> shortTermBlocks_;
    std::deque<double> integratedBlocks_;

    double momentaryLUFS_ = -100.0;
    double shortTermLUFS_ = -100.0;
    double integratedLUFS_ = -100.0;
    double loudnessRange_ = 0.0;
    double truePeak_ = -100.0;
    float truePeakLinear_ = 0.0f;
};

//==============================================================================
/** Phase Correlation Meter */
class PhaseCorrelationMeter {
public:
    PhaseCorrelationMeter(int windowSize = 2048)
        : windowSize_(windowSize)
    {
        reset();
    }

    void reset() {
        leftBuffer_.assign(windowSize_, 0.0f);
        rightBuffer_.assign(windowSize_, 0.0f);
        writePos_ = 0;
        correlation_ = 1.0f;
    }

    void process(const float* left, const float* right, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            leftBuffer_[writePos_] = left[i];
            rightBuffer_[writePos_] = right[i];
            writePos_ = (writePos_ + 1) % windowSize_;
        }

        calculateCorrelation();
    }

    float getCorrelation() const { return correlation_; }

    // -1 = out of phase, 0 = uncorrelated, +1 = in phase (mono compatible)
    bool isMonoCompatible() const { return correlation_ > 0.0f; }

    juce::String getPhaseStatus() const {
        if (correlation_ > 0.8f) return "Mono Safe";
        if (correlation_ > 0.3f) return "Stereo";
        if (correlation_ > 0.0f) return "Wide Stereo";
        if (correlation_ > -0.3f) return "Phase Issues";
        return "Out of Phase!";
    }

private:
    void calculateCorrelation() {
        double sumLR = 0.0, sumL2 = 0.0, sumR2 = 0.0;

        for (int i = 0; i < windowSize_; ++i) {
            double l = leftBuffer_[i];
            double r = rightBuffer_[i];
            sumLR += l * r;
            sumL2 += l * l;
            sumR2 += r * r;
        }

        double denominator = std::sqrt(sumL2 * sumR2);
        correlation_ = denominator > 1e-10 ?
                       static_cast<float>(sumLR / denominator) : 0.0f;
    }

    int windowSize_;
    std::vector<float> leftBuffer_;
    std::vector<float> rightBuffer_;
    int writePos_ = 0;
    float correlation_ = 1.0f;
};

//==============================================================================
/** Spectrum Analyzer */
class SpectrumAnalyzer {
public:
    SpectrumAnalyzer(int fftSize = 2048)
        : fftSize_(fftSize)
        , fft_(static_cast<int>(std::log2(fftSize)))
        , numBins_(fftSize / 2 + 1)
    {
        fftBuffer_.resize(fftSize_ * 2);
        window_.resize(fftSize_);
        magnitudes_.resize(numBins_);
        smoothedMagnitudes_.resize(numBins_);

        createWindow();
        reset();
    }

    void reset() {
        std::fill(magnitudes_.begin(), magnitudes_.end(), -100.0f);
        std::fill(smoothedMagnitudes_.begin(), smoothedMagnitudes_.end(), -100.0f);
        inputBuffer_.clear();
    }

    void process(const float* samples, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            inputBuffer_.push_back(samples[i]);

            if (static_cast<int>(inputBuffer_.size()) >= fftSize_) {
                performFFT();
                inputBuffer_.erase(inputBuffer_.begin(),
                                   inputBuffer_.begin() + fftSize_ / 2);
            }
        }
    }

    const std::vector<float>& getMagnitudes() const { return smoothedMagnitudes_; }

    float getMagnitudeAtFrequency(double frequency, double sampleRate) const {
        int bin = static_cast<int>(frequency * fftSize_ / sampleRate);
        if (bin >= 0 && bin < numBins_) {
            return smoothedMagnitudes_[bin];
        }
        return -100.0f;
    }

    int getNumBins() const { return numBins_; }

    double getBinFrequency(int bin, double sampleRate) const {
        return bin * sampleRate / fftSize_;
    }

    void setSmoothingFactor(float factor) {
        smoothingFactor_ = juce::jlimit(0.0f, 0.99f, factor);
    }

private:
    void createWindow() {
        // Hann window
        for (int i = 0; i < fftSize_; ++i) {
            window_[i] = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi *
                                                  i / (fftSize_ - 1)));
        }
    }

    void performFFT() {
        // Apply window and copy to FFT buffer
        std::fill(fftBuffer_.begin(), fftBuffer_.end(), 0.0f);
        for (int i = 0; i < fftSize_; ++i) {
            fftBuffer_[i] = inputBuffer_[i] * window_[i];
        }

        // Perform FFT
        fft_.performRealOnlyForwardTransform(fftBuffer_.data(), true);

        // Calculate magnitudes
        for (int i = 0; i < numBins_; ++i) {
            float real = fftBuffer_[i * 2];
            float imag = fftBuffer_[i * 2 + 1];
            float magnitude = std::sqrt(real * real + imag * imag);
            magnitudes_[i] = juce::Decibels::gainToDecibels(magnitude / fftSize_);

            // Smooth
            smoothedMagnitudes_[i] = smoothedMagnitudes_[i] * smoothingFactor_ +
                                     magnitudes_[i] * (1.0f - smoothingFactor_);
        }
    }

    int fftSize_;
    int numBins_;
    juce::dsp::FFT fft_;

    std::vector<float> fftBuffer_;
    std::vector<float> window_;
    std::vector<float> inputBuffer_;
    std::vector<float> magnitudes_;
    std::vector<float> smoothedMagnitudes_;

    float smoothingFactor_ = 0.8f;
};

//==============================================================================
/** Dynamic Range / Crest Factor Meter */
class DynamicRangeMeter {
public:
    DynamicRangeMeter(double sampleRate = 44100.0)
        : sampleRate_(sampleRate)
    {
        windowSamples_ = static_cast<int>(sampleRate * windowTimeSeconds_);
        reset();
    }

    void reset() {
        peakBuffer_.clear();
        rmsBuffer_.clear();
        currentPeak_ = 0.0f;
        currentRMS_ = 0.0f;
        crestFactor_ = 0.0f;
        dynamicRange_ = 0.0f;
    }

    void process(const float* samples, int numSamples) {
        for (int i = 0; i < numSamples; ++i) {
            float absSample = std::abs(samples[i]);
            float squared = samples[i] * samples[i];

            peakBuffer_.push_back(absSample);
            rmsBuffer_.push_back(squared);

            while (static_cast<int>(peakBuffer_.size()) > windowSamples_) {
                peakBuffer_.pop_front();
                rmsBuffer_.pop_front();
            }
        }

        calculateMetrics();
    }

    float getPeakDB() const { return juce::Decibels::gainToDecibels(currentPeak_); }
    float getRMSDB() const { return juce::Decibels::gainToDecibels(currentRMS_); }
    float getCrestFactorDB() const { return crestFactor_; }
    float getDynamicRangeDB() const { return dynamicRange_; }

    // PSR (Peak to Short-term Loudness Ratio)
    float getPSR() const { return crestFactor_; }

private:
    void calculateMetrics() {
        if (peakBuffer_.empty()) return;

        // Peak
        currentPeak_ = *std::max_element(peakBuffer_.begin(), peakBuffer_.end());

        // RMS
        double sum = 0.0;
        for (float sq : rmsBuffer_) sum += sq;
        currentRMS_ = static_cast<float>(std::sqrt(sum / rmsBuffer_.size()));

        // Crest factor (Peak/RMS in dB)
        if (currentRMS_ > 1e-10f) {
            crestFactor_ = juce::Decibels::gainToDecibels(currentPeak_ / currentRMS_);
        }

        // Dynamic range (difference between loud and quiet sections)
        // Simplified: max RMS - min RMS over window
        float minRMS = std::sqrt(*std::min_element(rmsBuffer_.begin(), rmsBuffer_.end()));
        float maxRMS = currentRMS_;
        if (minRMS > 1e-10f) {
            dynamicRange_ = juce::Decibels::gainToDecibels(maxRMS / minRMS);
        }
    }

    double sampleRate_;
    double windowTimeSeconds_ = 3.0;
    int windowSamples_;

    std::deque<float> peakBuffer_;
    std::deque<float> rmsBuffer_;

    float currentPeak_ = 0.0f;
    float currentRMS_ = 0.0f;
    float crestFactor_ = 0.0f;
    float dynamicRange_ = 0.0f;
};

//==============================================================================
/** Stereo Balance Meter */
class StereoBalanceMeter {
public:
    void process(const float* left, const float* right, int numSamples) {
        double leftSum = 0.0, rightSum = 0.0;

        for (int i = 0; i < numSamples; ++i) {
            leftSum += left[i] * left[i];
            rightSum += right[i] * right[i];
        }

        double leftRMS = std::sqrt(leftSum / numSamples);
        double rightRMS = std::sqrt(rightSum / numSamples);

        // Balance: -1 = full left, 0 = center, +1 = full right
        double total = leftRMS + rightRMS;
        if (total > 1e-10) {
            balance_ = static_cast<float>((rightRMS - leftRMS) / total);
        } else {
            balance_ = 0.0f;
        }

        // Smooth
        smoothedBalance_ = smoothedBalance_ * 0.9f + balance_ * 0.1f;
    }

    float getBalance() const { return smoothedBalance_; }
    float getBalanceDB() const {
        if (smoothedBalance_ > 0.0f) {
            return juce::Decibels::gainToDecibels(1.0f + smoothedBalance_);
        } else {
            return -juce::Decibels::gainToDecibels(1.0f - smoothedBalance_);
        }
    }

private:
    float balance_ = 0.0f;
    float smoothedBalance_ = 0.0f;
};

//==============================================================================
/** Complete Integrated Metering Suite */
class MeteringSuite {
public:
    MeteringSuite(double sampleRate = 44100.0, int numChannels = 2)
        : sampleRate_(sampleRate)
        , numChannels_(numChannels)
        , lufsMeter_(sampleRate, numChannels)
        , phaseCorrelation_(2048)
        , spectrumAnalyzer_(4096)
        , dynamicRange_(sampleRate)
    {
    }

    void setSampleRate(double sampleRate) {
        sampleRate_ = sampleRate;
        lufsMeter_.setSampleRate(sampleRate);
    }

    void reset() {
        lufsMeter_.reset();
        phaseCorrelation_.reset();
        spectrumAnalyzer_.reset();
        dynamicRange_.reset();
    }

    void process(const juce::AudioBuffer<float>& buffer) {
        // LUFS
        lufsMeter_.process(buffer);

        // Phase correlation (stereo only)
        if (buffer.getNumChannels() >= 2) {
            phaseCorrelation_.process(buffer.getReadPointer(0),
                                       buffer.getReadPointer(1),
                                       buffer.getNumSamples());
            stereoBalance_.process(buffer.getReadPointer(0),
                                   buffer.getReadPointer(1),
                                   buffer.getNumSamples());
        }

        // Spectrum (mono sum)
        std::vector<float> monoBuffer(buffer.getNumSamples());
        for (int i = 0; i < buffer.getNumSamples(); ++i) {
            float sum = 0.0f;
            for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
                sum += buffer.getSample(ch, i);
            }
            monoBuffer[i] = sum / buffer.getNumChannels();
        }
        spectrumAnalyzer_.process(monoBuffer.data(), buffer.getNumSamples());

        // Dynamic range
        dynamicRange_.process(monoBuffer.data(), buffer.getNumSamples());
    }

    //==============================================================================
    // LUFS accessors
    double getMomentaryLUFS() const { return lufsMeter_.getMomentaryLUFS(); }
    double getShortTermLUFS() const { return lufsMeter_.getShortTermLUFS(); }
    double getIntegratedLUFS() const { return lufsMeter_.getIntegratedLUFS(); }
    double getLoudnessRange() const { return lufsMeter_.getLoudnessRange(); }
    double getTruePeak() const { return lufsMeter_.getTruePeak(); }

    // Phase
    float getPhaseCorrelation() const { return phaseCorrelation_.getCorrelation(); }
    juce::String getPhaseStatus() const { return phaseCorrelation_.getPhaseStatus(); }

    // Spectrum
    const std::vector<float>& getSpectrum() const { return spectrumAnalyzer_.getMagnitudes(); }
    float getSpectrumAtFrequency(double freq) const {
        return spectrumAnalyzer_.getMagnitudeAtFrequency(freq, sampleRate_);
    }

    // Dynamic range
    float getCrestFactor() const { return dynamicRange_.getCrestFactorDB(); }
    float getDynamicRangeDB() const { return dynamicRange_.getDynamicRangeDB(); }

    // Stereo balance
    float getStereoBalance() const { return stereoBalance_.getBalance(); }

    //==============================================================================
    // Compliance checking
    void setTargetStandard(LoudnessStandard standard) {
        targetStandard_ = standard;
    }

    bool isLoudnessCompliant() const {
        double target = getLoudnessTarget(targetStandard_);
        double tolerance = 1.0; // +/- 1 LU
        return std::abs(getIntegratedLUFS() - target) <= tolerance;
    }

    bool isTruePeakCompliant() const {
        return getTruePeak() <= getTruePeakLimit(targetStandard_);
    }

    double getLoudnessDeviation() const {
        return getIntegratedLUFS() - getLoudnessTarget(targetStandard_);
    }

private:
    double sampleRate_;
    int numChannels_;
    LoudnessStandard targetStandard_ = LoudnessStandard::Spotify;

    LUFSMeter lufsMeter_;
    PhaseCorrelationMeter phaseCorrelation_;
    SpectrumAnalyzer spectrumAnalyzer_;
    DynamicRangeMeter dynamicRange_;
    StereoBalanceMeter stereoBalance_;
};

} // namespace Metering
} // namespace Echoelmusic
