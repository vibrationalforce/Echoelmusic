/*
  ==============================================================================

    TimeStretchEngine.h
    Created: 2026
    Author:  Echoelmusic

    Professional Audio Time-Stretching and Pitch-Shifting Engine
    Elastique/Rubberband style phase vocoder with transient preservation

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <complex>
#include <memory>
#include <cmath>
#include <algorithm>

namespace Echoelmusic {
namespace DSP {

//==============================================================================
/** Time-stretch algorithm types */
enum class StretchAlgorithm {
    Standard,       // Phase vocoder (good for most audio)
    Transient,      // Preserves transients (drums, percussion)
    Tonal,          // Optimized for tonal content (vocals, instruments)
    Extreme,        // For extreme stretch ratios (>4x)
    Monophonic,     // Single-pitch sources (solo instruments)
    Polyphonic      // Complex polyphonic material
};

/** Pitch shift mode */
enum class PitchMode {
    Semitones,      // Discrete semitone steps
    Cents,          // Fine pitch in cents
    Frequency,      // Absolute frequency ratio
    Formant         // Pitch shift with formant preservation
};

//==============================================================================
/** Transient detection for time-stretching */
class TransientDetector {
public:
    TransientDetector(int sampleRate = 44100)
        : sampleRate_(sampleRate)
    {
        reset();
    }

    void reset() {
        prevEnergy_ = 0.0f;
        smoothedEnergy_ = 0.0f;
        transientThreshold_ = 0.3f;
    }

    void setThreshold(float threshold) {
        transientThreshold_ = juce::jlimit(0.0f, 1.0f, threshold);
    }

    /** Detect transients in a block of audio */
    std::vector<int> detectTransients(const float* audio, int numSamples) {
        std::vector<int> transientPositions;
        const int windowSize = 256;
        const int hopSize = 64;

        for (int i = 0; i < numSamples - windowSize; i += hopSize) {
            // Calculate spectral flux
            float energy = 0.0f;
            for (int j = 0; j < windowSize; ++j) {
                float sample = audio[i + j];
                energy += sample * sample;
            }
            energy = std::sqrt(energy / windowSize);

            // Exponential smoothing
            smoothedEnergy_ = 0.9f * smoothedEnergy_ + 0.1f * energy;

            // Detect onset
            float flux = energy - prevEnergy_;
            if (flux > transientThreshold_ * smoothedEnergy_ && energy > 0.01f) {
                transientPositions.push_back(i);
            }

            prevEnergy_ = energy;
        }

        return transientPositions;
    }

    /** Check if a single position is near a transient */
    bool isNearTransient(int position, const std::vector<int>& transients, int tolerance = 512) {
        for (int t : transients) {
            if (std::abs(position - t) < tolerance) {
                return true;
            }
        }
        return false;
    }

private:
    int sampleRate_;
    float prevEnergy_ = 0.0f;
    float smoothedEnergy_ = 0.0f;
    float transientThreshold_ = 0.3f;
};

//==============================================================================
/** Phase vocoder frame */
struct VocoderFrame {
    std::vector<float> magnitude;
    std::vector<float> phase;
    std::vector<float> frequency;  // Instantaneous frequency
    int originalPosition = 0;
    bool isTransient = false;

    void resize(int size) {
        magnitude.resize(size);
        phase.resize(size);
        frequency.resize(size);
    }
};

//==============================================================================
/** Phase vocoder core for time-stretching */
class PhaseVocoder {
public:
    PhaseVocoder(int fftSize = 2048, int hopSize = 512)
        : fftSize_(fftSize)
        , hopSize_(hopSize)
        , numBins_(fftSize / 2 + 1)
        , fft_(static_cast<int>(std::log2(fftSize)))
    {
        analysisWindow_.resize(fftSize_);
        synthesisWindow_.resize(fftSize_);
        createWindows();

        fftBuffer_.resize(fftSize_ * 2);
        prevPhase_.resize(numBins_, 0.0f);
        synthPhase_.resize(numBins_, 0.0f);

        phaseAccumulator_.resize(numBins_, 0.0f);
    }

    void createWindows() {
        // Hann window for analysis
        for (int i = 0; i < fftSize_; ++i) {
            analysisWindow_[i] = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi * i / fftSize_));
            synthesisWindow_[i] = analysisWindow_[i];
        }

        // Normalize synthesis window for OLA
        float sum = 0.0f;
        for (int i = 0; i < fftSize_; i += hopSize_) {
            sum += synthesisWindow_[i] * synthesisWindow_[i];
        }
        float norm = 1.0f / sum;
        for (int i = 0; i < fftSize_; ++i) {
            synthesisWindow_[i] *= norm;
        }
    }

    /** Analyze a frame */
    VocoderFrame analyze(const float* input) {
        VocoderFrame frame;
        frame.resize(numBins_);

        // Apply window and prepare FFT buffer
        std::fill(fftBuffer_.begin(), fftBuffer_.end(), 0.0f);
        for (int i = 0; i < fftSize_; ++i) {
            fftBuffer_[i] = input[i] * analysisWindow_[i];
        }

        // Forward FFT
        fft_.performRealOnlyForwardTransform(fftBuffer_.data(), true);

        // Extract magnitude, phase, and instantaneous frequency
        float freqPerBin = 44100.0f / fftSize_;
        float expectedPhaseDiff = 2.0f * juce::MathConstants<float>::pi * hopSize_ / fftSize_;

        for (int bin = 0; bin < numBins_; ++bin) {
            float real = fftBuffer_[bin * 2];
            float imag = fftBuffer_[bin * 2 + 1];

            frame.magnitude[bin] = std::sqrt(real * real + imag * imag);
            frame.phase[bin] = std::atan2(imag, real);

            // Calculate instantaneous frequency
            float phaseDiff = frame.phase[bin] - prevPhase_[bin];

            // Unwrap phase
            phaseDiff -= bin * expectedPhaseDiff;
            phaseDiff = std::fmod(phaseDiff + juce::MathConstants<float>::pi,
                                  2.0f * juce::MathConstants<float>::pi) -
                        juce::MathConstants<float>::pi;

            // Convert to frequency deviation
            float freqDev = phaseDiff * 44100.0f / (2.0f * juce::MathConstants<float>::pi * hopSize_);
            frame.frequency[bin] = bin * freqPerBin + freqDev;

            prevPhase_[bin] = frame.phase[bin];
        }

        return frame;
    }

    /** Synthesize a frame */
    void synthesize(const VocoderFrame& frame, float* output, int synthHopSize) {
        float freqPerBin = 44100.0f / fftSize_;
        float expectedPhaseDiff = 2.0f * juce::MathConstants<float>::pi * synthHopSize / fftSize_;

        // Reconstruct phase from instantaneous frequency
        for (int bin = 0; bin < numBins_; ++bin) {
            float freqDev = frame.frequency[bin] - bin * freqPerBin;
            float phaseDiff = freqDev * 2.0f * juce::MathConstants<float>::pi * synthHopSize / 44100.0f;
            phaseDiff += bin * expectedPhaseDiff;

            synthPhase_[bin] += phaseDiff;

            // Convert to complex
            fftBuffer_[bin * 2] = frame.magnitude[bin] * std::cos(synthPhase_[bin]);
            fftBuffer_[bin * 2 + 1] = frame.magnitude[bin] * std::sin(synthPhase_[bin]);
        }

        // Inverse FFT
        fft_.performRealOnlyInverseTransform(fftBuffer_.data());

        // Apply synthesis window
        for (int i = 0; i < fftSize_; ++i) {
            output[i] = fftBuffer_[i] * synthesisWindow_[i];
        }
    }

    void reset() {
        std::fill(prevPhase_.begin(), prevPhase_.end(), 0.0f);
        std::fill(synthPhase_.begin(), synthPhase_.end(), 0.0f);
        std::fill(phaseAccumulator_.begin(), phaseAccumulator_.end(), 0.0f);
    }

    int getFFTSize() const { return fftSize_; }
    int getHopSize() const { return hopSize_; }
    int getLatency() const { return fftSize_; }

private:
    int fftSize_;
    int hopSize_;
    int numBins_;

    juce::dsp::FFT fft_;

    std::vector<float> analysisWindow_;
    std::vector<float> synthesisWindow_;
    std::vector<float> fftBuffer_;
    std::vector<float> prevPhase_;
    std::vector<float> synthPhase_;
    std::vector<float> phaseAccumulator_;
};

//==============================================================================
/** Formant shifter for vocal processing */
class FormantShifter {
public:
    FormantShifter(int fftSize = 2048)
        : fftSize_(fftSize)
        , numBins_(fftSize / 2 + 1)
    {
        envelope_.resize(numBins_);
        fineStructure_.resize(numBins_);
    }

    /** Separate spectral envelope from fine structure */
    void analyzeFormants(const std::vector<float>& magnitude) {
        // Cepstral smoothing for envelope extraction
        const int cepstralCutoff = 30; // Quefrency cutoff

        // Simple moving average as envelope approximation
        const int smoothingWindow = 5;
        for (int i = 0; i < numBins_; ++i) {
            float sum = 0.0f;
            int count = 0;
            for (int j = std::max(0, i - smoothingWindow);
                 j < std::min(numBins_, i + smoothingWindow + 1); ++j) {
                sum += magnitude[j];
                count++;
            }
            envelope_[i] = sum / count;
            fineStructure_[i] = (envelope_[i] > 0.0001f) ?
                                magnitude[i] / envelope_[i] : 1.0f;
        }
    }

    /** Shift formants independently of pitch */
    void shiftFormants(std::vector<float>& magnitude, float formantRatio) {
        std::vector<float> newMagnitude(numBins_, 0.0f);

        for (int i = 0; i < numBins_; ++i) {
            // Shift envelope
            float srcBin = i / formantRatio;
            if (srcBin >= 0 && srcBin < numBins_ - 1) {
                int srcBinInt = static_cast<int>(srcBin);
                float frac = srcBin - srcBinInt;

                float shiftedEnvelope = envelope_[srcBinInt] * (1.0f - frac) +
                                        envelope_[srcBinInt + 1] * frac;
                newMagnitude[i] = fineStructure_[i] * shiftedEnvelope;
            }
        }

        magnitude = newMagnitude;
    }

private:
    int fftSize_;
    int numBins_;
    std::vector<float> envelope_;
    std::vector<float> fineStructure_;
};

//==============================================================================
/** Warp marker for non-linear time-stretching */
struct WarpMarker {
    double sourceTime;      // Time in source audio (seconds)
    double targetTime;      // Time in output (seconds)
    bool isAnchor = false;  // Lock point (transient)

    double getStretchRatio(const WarpMarker& next) const {
        if (next.sourceTime - sourceTime <= 0.0) return 1.0;
        return (next.targetTime - targetTime) / (next.sourceTime - sourceTime);
    }
};

//==============================================================================
/** Warp region for complex warping */
struct WarpRegion {
    std::vector<WarpMarker> markers;
    double sourceDuration = 0.0;
    double targetDuration = 0.0;

    void addMarker(double sourceTime, double targetTime, bool anchor = false) {
        WarpMarker marker;
        marker.sourceTime = sourceTime;
        marker.targetTime = targetTime;
        marker.isAnchor = anchor;
        markers.push_back(marker);

        // Keep sorted
        std::sort(markers.begin(), markers.end(),
                  [](const WarpMarker& a, const WarpMarker& b) {
                      return a.sourceTime < b.sourceTime;
                  });
    }

    double getStretchRatioAt(double sourceTime) const {
        if (markers.size() < 2) return 1.0;

        // Find surrounding markers
        for (size_t i = 0; i < markers.size() - 1; ++i) {
            if (sourceTime >= markers[i].sourceTime &&
                sourceTime < markers[i + 1].sourceTime) {
                return markers[i].getStretchRatio(markers[i + 1]);
            }
        }

        return 1.0;
    }

    double sourceToTarget(double sourceTime) const {
        if (markers.size() < 2) return sourceTime;

        for (size_t i = 0; i < markers.size() - 1; ++i) {
            if (sourceTime >= markers[i].sourceTime &&
                sourceTime < markers[i + 1].sourceTime) {
                double ratio = markers[i].getStretchRatio(markers[i + 1]);
                double offset = sourceTime - markers[i].sourceTime;
                return markers[i].targetTime + offset * ratio;
            }
        }

        return sourceTime;
    }
};

//==============================================================================
/** Main time-stretch engine */
class TimeStretchEngine {
public:
    TimeStretchEngine(int sampleRate = 44100)
        : sampleRate_(sampleRate)
        , vocoder_(2048, 512)
        , transientDetector_(sampleRate)
        , formantShifter_(2048)
    {
    }

    //==============================================================================
    /** Set time-stretch ratio (1.0 = original, 2.0 = double length) */
    void setStretchRatio(double ratio) {
        stretchRatio_ = juce::jlimit(0.1, 10.0, ratio);
    }

    double getStretchRatio() const { return stretchRatio_; }

    /** Set pitch shift in semitones */
    void setPitchShift(double semitones) {
        pitchShiftSemitones_ = juce::jlimit(-24.0, 24.0, semitones);
        pitchRatio_ = std::pow(2.0, pitchShiftSemitones_ / 12.0);
    }

    double getPitchShift() const { return pitchShiftSemitones_; }

    /** Set pitch shift in cents */
    void setPitchShiftCents(double cents) {
        setPitchShift(cents / 100.0);
    }

    /** Set algorithm type */
    void setAlgorithm(StretchAlgorithm algo) {
        algorithm_ = algo;
    }

    /** Enable/disable formant preservation */
    void setFormantPreservation(bool enable) {
        preserveFormants_ = enable;
    }

    /** Set transient sensitivity */
    void setTransientSensitivity(float sensitivity) {
        transientDetector_.setThreshold(1.0f - sensitivity);
    }

    //==============================================================================
    /** Process entire audio buffer (offline) */
    juce::AudioBuffer<float> process(const juce::AudioBuffer<float>& input) {
        int numChannels = input.getNumChannels();
        int numInputSamples = input.getNumSamples();

        // Calculate output length
        int numOutputSamples = static_cast<int>(numInputSamples * stretchRatio_);
        juce::AudioBuffer<float> output(numChannels, numOutputSamples);
        output.clear();

        // Detect transients for transient-aware processing
        std::vector<int> transients;
        if (algorithm_ == StretchAlgorithm::Transient ||
            algorithm_ == StretchAlgorithm::Standard) {
            transients = transientDetector_.detectTransients(
                input.getReadPointer(0), numInputSamples);
        }

        // Process each channel
        for (int ch = 0; ch < numChannels; ++ch) {
            processChannel(input.getReadPointer(ch), numInputSamples,
                           output.getWritePointer(ch), numOutputSamples,
                           transients);
        }

        // Apply pitch shift if needed
        if (std::abs(pitchShiftSemitones_) > 0.01) {
            output = applyPitchShift(output);
        }

        return output;
    }

    /** Process with warp markers (non-linear stretching) */
    juce::AudioBuffer<float> processWithWarping(
        const juce::AudioBuffer<float>& input,
        const WarpRegion& warpRegion)
    {
        int numChannels = input.getNumChannels();
        int numInputSamples = input.getNumSamples();
        int numOutputSamples = static_cast<int>(warpRegion.targetDuration * sampleRate_);

        juce::AudioBuffer<float> output(numChannels, numOutputSamples);
        output.clear();

        // Process in segments between warp markers
        const auto& markers = warpRegion.markers;

        for (size_t i = 0; i < markers.size() - 1; ++i) {
            int srcStart = static_cast<int>(markers[i].sourceTime * sampleRate_);
            int srcEnd = static_cast<int>(markers[i + 1].sourceTime * sampleRate_);
            int dstStart = static_cast<int>(markers[i].targetTime * sampleRate_);
            int dstEnd = static_cast<int>(markers[i + 1].targetTime * sampleRate_);

            // Extract segment
            int srcLen = srcEnd - srcStart;
            int dstLen = dstEnd - dstStart;

            if (srcLen <= 0 || dstLen <= 0) continue;

            juce::AudioBuffer<float> segment(numChannels, srcLen);
            for (int ch = 0; ch < numChannels; ++ch) {
                segment.copyFrom(ch, 0, input, ch, srcStart, srcLen);
            }

            // Stretch segment
            double segmentRatio = static_cast<double>(dstLen) / srcLen;
            setStretchRatio(segmentRatio);
            auto stretched = process(segment);

            // Copy to output
            int copyLen = std::min(stretched.getNumSamples(), dstLen);
            for (int ch = 0; ch < numChannels; ++ch) {
                output.copyFrom(ch, dstStart, stretched, ch, 0, copyLen);
            }
        }

        return output;
    }

    //==============================================================================
    /** Real-time processing setup */
    void prepareToPlay(double sampleRate, int blockSize) {
        sampleRate_ = static_cast<int>(sampleRate);
        blockSize_ = blockSize;

        // Initialize buffers
        inputFifo_.resize(vocoder_.getFFTSize() * 4);
        outputFifo_.resize(vocoder_.getFFTSize() * 4);
        inputWritePos_ = 0;
        inputReadPos_ = 0;
        outputWritePos_ = 0;
        outputReadPos_ = 0;

        vocoder_.reset();
    }

    /** Process a block in real-time */
    void processBlock(juce::AudioBuffer<float>& buffer) {
        int numSamples = buffer.getNumSamples();

        // Simple real-time implementation
        // Full phase vocoder requires buffering

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            float* data = buffer.getWritePointer(ch);

            // Push samples to input FIFO
            for (int i = 0; i < numSamples; ++i) {
                inputFifo_[inputWritePos_++ % inputFifo_.size()] = data[i];
            }

            // Process when we have enough samples
            while (inputWritePos_ - inputReadPos_ >= vocoder_.getFFTSize()) {
                processRealtimeFrame(ch);
            }

            // Read from output FIFO
            for (int i = 0; i < numSamples; ++i) {
                if (outputReadPos_ < outputWritePos_) {
                    data[i] = outputFifo_[outputReadPos_++ % outputFifo_.size()];
                } else {
                    data[i] = 0.0f;
                }
            }
        }
    }

    int getLatency() const {
        return vocoder_.getLatency();
    }

    //==============================================================================
    /** Tempo-match audio to target BPM */
    juce::AudioBuffer<float> tempoMatch(
        const juce::AudioBuffer<float>& input,
        double sourceBPM,
        double targetBPM)
    {
        double ratio = sourceBPM / targetBPM;
        setStretchRatio(ratio);
        return process(input);
    }

    /** Match audio to target duration */
    juce::AudioBuffer<float> matchDuration(
        const juce::AudioBuffer<float>& input,
        double targetDurationSeconds)
    {
        double sourceDuration = input.getNumSamples() / static_cast<double>(sampleRate_);
        double ratio = targetDurationSeconds / sourceDuration;
        setStretchRatio(ratio);
        return process(input);
    }

    //==============================================================================
    /** Auto-detect and quantize to grid */
    WarpRegion autoQuantize(
        const juce::AudioBuffer<float>& audio,
        double bpm,
        double gridResolution = 0.25) // Quarter notes
    {
        WarpRegion region;
        region.sourceDuration = audio.getNumSamples() / static_cast<double>(sampleRate_);

        // Detect transients
        auto transients = transientDetector_.detectTransients(
            audio.getReadPointer(0), audio.getNumSamples());

        // Calculate grid positions
        double beatDuration = 60.0 / bpm;
        double gridDuration = beatDuration * gridResolution;

        // Add start marker
        region.addMarker(0.0, 0.0, true);

        // Quantize each transient to nearest grid position
        for (int t : transients) {
            double transientTime = t / static_cast<double>(sampleRate_);
            double nearestGrid = std::round(transientTime / gridDuration) * gridDuration;
            region.addMarker(transientTime, nearestGrid, true);
        }

        // Add end marker
        double quantizedDuration = std::ceil(region.sourceDuration / gridDuration) * gridDuration;
        region.addMarker(region.sourceDuration, quantizedDuration, true);
        region.targetDuration = quantizedDuration;

        return region;
    }

private:
    void processChannel(const float* input, int numInputSamples,
                        float* output, int numOutputSamples,
                        const std::vector<int>& transients)
    {
        int fftSize = vocoder_.getFFTSize();
        int analysisHop = vocoder_.getHopSize();
        int synthesisHop = static_cast<int>(analysisHop / stretchRatio_);

        // Analyze all frames
        std::vector<VocoderFrame> frames;
        for (int i = 0; i + fftSize <= numInputSamples; i += analysisHop) {
            auto frame = vocoder_.analyze(input + i);
            frame.originalPosition = i;
            frame.isTransient = transientDetector_.isNearTransient(i, transients);
            frames.push_back(frame);
        }

        // Synthesize with time-stretching
        std::vector<float> outputBuffer(numOutputSamples, 0.0f);
        std::vector<float> windowSum(numOutputSamples, 0.0f);
        std::vector<float> frameBuffer(fftSize);

        int outputPos = 0;
        for (size_t frameIdx = 0; frameIdx < frames.size() && outputPos < numOutputSamples; ++frameIdx) {
            auto frame = frames[frameIdx];

            // Apply formant preservation if enabled
            if (preserveFormants_ && std::abs(pitchShiftSemitones_) > 0.01) {
                formantShifter_.analyzeFormants(frame.magnitude);
                float formantRatio = static_cast<float>(std::pow(2.0, pitchShiftSemitones_ / 12.0));
                formantShifter_.shiftFormants(frame.magnitude, formantRatio);
            }

            // Synthesize frame
            vocoder_.synthesize(frame, frameBuffer.data(), synthesisHop);

            // Overlap-add
            for (int i = 0; i < fftSize && outputPos + i < numOutputSamples; ++i) {
                outputBuffer[outputPos + i] += frameBuffer[i];
                windowSum[outputPos + i] += 1.0f;
            }

            // Handle transients - reset phase at transient boundaries
            if (frame.isTransient && algorithm_ == StretchAlgorithm::Transient) {
                vocoder_.reset();
            }

            outputPos += synthesisHop;
        }

        // Normalize
        for (int i = 0; i < numOutputSamples; ++i) {
            if (windowSum[i] > 0.0f) {
                output[i] = outputBuffer[i] / windowSum[i];
            }
        }
    }

    juce::AudioBuffer<float> applyPitchShift(const juce::AudioBuffer<float>& input) {
        // Pitch shift by resampling
        int numChannels = input.getNumChannels();
        int numInputSamples = input.getNumSamples();
        int numOutputSamples = static_cast<int>(numInputSamples / pitchRatio_);

        juce::AudioBuffer<float> output(numChannels, numOutputSamples);

        for (int ch = 0; ch < numChannels; ++ch) {
            const float* src = input.getReadPointer(ch);
            float* dst = output.getWritePointer(ch);

            for (int i = 0; i < numOutputSamples; ++i) {
                double srcPos = i * pitchRatio_;
                int srcIdx = static_cast<int>(srcPos);
                float frac = static_cast<float>(srcPos - srcIdx);

                if (srcIdx + 1 < numInputSamples) {
                    // Linear interpolation
                    dst[i] = src[srcIdx] * (1.0f - frac) + src[srcIdx + 1] * frac;
                } else if (srcIdx < numInputSamples) {
                    dst[i] = src[srcIdx];
                } else {
                    dst[i] = 0.0f;
                }
            }
        }

        // Time-stretch back to original length
        double compensationRatio = static_cast<double>(numInputSamples) / numOutputSamples;
        setStretchRatio(compensationRatio);
        return process(output);
    }

    void processRealtimeFrame(int channel) {
        int fftSize = vocoder_.getFFTSize();
        std::vector<float> frameInput(fftSize);
        std::vector<float> frameOutput(fftSize);

        // Read from input FIFO
        for (int i = 0; i < fftSize; ++i) {
            frameInput[i] = inputFifo_[(inputReadPos_ + i) % inputFifo_.size()];
        }
        inputReadPos_ += vocoder_.getHopSize();

        // Process frame
        auto frame = vocoder_.analyze(frameInput.data());
        int synthHop = static_cast<int>(vocoder_.getHopSize() / stretchRatio_);
        vocoder_.synthesize(frame, frameOutput.data(), synthHop);

        // Write to output FIFO
        for (int i = 0; i < synthHop; ++i) {
            outputFifo_[outputWritePos_++ % outputFifo_.size()] = frameOutput[i];
        }
    }

    int sampleRate_;
    int blockSize_ = 512;

    double stretchRatio_ = 1.0;
    double pitchShiftSemitones_ = 0.0;
    double pitchRatio_ = 1.0;

    StretchAlgorithm algorithm_ = StretchAlgorithm::Standard;
    bool preserveFormants_ = false;

    PhaseVocoder vocoder_;
    TransientDetector transientDetector_;
    FormantShifter formantShifter_;

    // Real-time buffers
    std::vector<float> inputFifo_;
    std::vector<float> outputFifo_;
    size_t inputWritePos_ = 0;
    size_t inputReadPos_ = 0;
    size_t outputWritePos_ = 0;
    size_t outputReadPos_ = 0;
};

//==============================================================================
/** Audio warping editor component */
class WarpEditor {
public:
    WarpEditor() = default;

    void setAudio(const juce::AudioBuffer<float>& audio, double sampleRate) {
        sourceAudio_ = audio;
        sampleRate_ = sampleRate;
        sourceDuration_ = audio.getNumSamples() / sampleRate;

        // Initialize with start and end markers
        warpRegion_.markers.clear();
        warpRegion_.sourceDuration = sourceDuration_;
        warpRegion_.targetDuration = sourceDuration_;
        warpRegion_.addMarker(0.0, 0.0, true);
        warpRegion_.addMarker(sourceDuration_, sourceDuration_, true);

        // Auto-detect transients and add as potential anchor points
        TransientDetector detector(static_cast<int>(sampleRate));
        auto transients = detector.detectTransients(
            sourceAudio_.getReadPointer(0), sourceAudio_.getNumSamples());

        for (int t : transients) {
            double time = t / sampleRate;
            suggestedAnchors_.push_back(time);
        }
    }

    /** Add a warp marker */
    void addMarker(double sourceTime, double targetTime, bool anchor = false) {
        warpRegion_.addMarker(sourceTime, targetTime, anchor);
    }

    /** Remove a marker by index */
    void removeMarker(int index) {
        if (index > 0 && index < static_cast<int>(warpRegion_.markers.size()) - 1) {
            warpRegion_.markers.erase(warpRegion_.markers.begin() + index);
        }
    }

    /** Move a marker */
    void moveMarker(int index, double newTargetTime) {
        if (index >= 0 && index < static_cast<int>(warpRegion_.markers.size())) {
            warpRegion_.markers[index].targetTime = newTargetTime;
        }
    }

    /** Get suggested anchor points (transients) */
    const std::vector<double>& getSuggestedAnchors() const {
        return suggestedAnchors_;
    }

    /** Apply warping */
    juce::AudioBuffer<float> applyWarp() {
        TimeStretchEngine engine(static_cast<int>(sampleRate_));
        return engine.processWithWarping(sourceAudio_, warpRegion_);
    }

    /** Get warp region for visualization */
    const WarpRegion& getWarpRegion() const { return warpRegion_; }

private:
    juce::AudioBuffer<float> sourceAudio_;
    double sampleRate_ = 44100.0;
    double sourceDuration_ = 0.0;

    WarpRegion warpRegion_;
    std::vector<double> suggestedAnchors_;
};

//==============================================================================
/** Elastic audio clip for DAW integration */
class ElasticAudioClip {
public:
    ElasticAudioClip(const juce::File& audioFile) {
        loadFromFile(audioFile);
    }

    bool loadFromFile(const juce::File& file) {
        juce::AudioFormatManager formatManager;
        formatManager.registerBasicFormats();

        std::unique_ptr<juce::AudioFormatReader> reader(
            formatManager.createReaderFor(file));

        if (!reader) return false;

        originalAudio_.setSize(reader->numChannels,
                               static_cast<int>(reader->lengthInSamples));
        reader->read(&originalAudio_, 0,
                     static_cast<int>(reader->lengthInSamples), 0, true, true);

        sampleRate_ = reader->sampleRate;
        originalDuration_ = reader->lengthInSamples / reader->sampleRate;

        return true;
    }

    /** Set clip tempo (will stretch to match project tempo) */
    void setSourceTempo(double bpm) { sourceBPM_ = bpm; }
    void setProjectTempo(double bpm) { projectBPM_ = bpm; }

    /** Enable/disable tempo sync */
    void setTempoSync(bool sync) { tempoSync_ = sync; }

    /** Get processed audio for playback */
    juce::AudioBuffer<float> getProcessedAudio() {
        if (!tempoSync_ || sourceBPM_ <= 0.0 || projectBPM_ <= 0.0) {
            return originalAudio_;
        }

        TimeStretchEngine engine(static_cast<int>(sampleRate_));
        engine.setAlgorithm(StretchAlgorithm::Standard);
        return engine.tempoMatch(originalAudio_, sourceBPM_, projectBPM_);
    }

    double getOriginalDuration() const { return originalDuration_; }

    double getProcessedDuration() const {
        if (!tempoSync_ || sourceBPM_ <= 0.0 || projectBPM_ <= 0.0) {
            return originalDuration_;
        }
        return originalDuration_ * sourceBPM_ / projectBPM_;
    }

private:
    juce::AudioBuffer<float> originalAudio_;
    double sampleRate_ = 44100.0;
    double originalDuration_ = 0.0;
    double sourceBPM_ = 0.0;
    double projectBPM_ = 120.0;
    bool tempoSync_ = false;
};

} // namespace DSP
} // namespace Echoelmusic
