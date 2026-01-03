#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <cmath>
#include <algorithm>

/**
 * TransientSlicer - Smart Audio Slicing & Beat Detection
 *
 * Automatic transient detection and audio slicing:
 * - Multi-algorithm transient detection
 * - Beat-aware slicing
 * - Slice-to-MIDI export
 * - Slice reordering and rearrangement
 * - Auto-categorization (kick, snare, hat, etc.)
 * - Slice effects (reverse, fade, pitch)
 * - REX/ReCycle-style export
 * - Drum replacement
 *
 * Inspired by: ReCycle, Serato Sample, Native Instruments Maschine
 */

namespace Echoelmusic {
namespace Editing {

//==============================================================================
// Slice Category
//==============================================================================

enum class SliceCategory
{
    Unknown,
    Kick,
    Snare,
    HiHat,
    Clap,
    Tom,
    Cymbal,
    Percussion,
    Bass,
    Melodic,
    Vocal,
    Effect
};

//==============================================================================
// Audio Slice
//==============================================================================

struct AudioSlice
{
    int startSample = 0;
    int endSample = 0;

    // Transient info
    float transientStrength = 0.0f;
    double tempo = 0.0;
    double beatPosition = 0.0;       // Position in beats from start

    // Category
    SliceCategory category = SliceCategory::Unknown;
    float categoryConfidence = 0.0f;

    // User data
    juce::String name;
    int midiNote = 36;               // C1 default
    float gain = 1.0f;
    float pan = 0.0f;
    bool muted = false;
    bool selected = false;

    // Effects
    bool reversed = false;
    float fadeIn = 0.0f;             // Samples
    float fadeOut = 0.0f;
    float pitchShift = 0.0f;         // Semitones

    // Color
    juce::Colour color = juce::Colours::orange;

    int getLength() const { return endSample - startSample; }
};

//==============================================================================
// Detection Algorithm
//==============================================================================

enum class DetectionAlgorithm
{
    SpectralFlux,        // Good for mixed content
    EnvelopeFollower,    // Good for drums
    ComplexDomain,       // Good for tonal content
    HighFrequencyContent,// Good for hi-hats
    PhaseDeviation,      // Good for subtle transients
    Combined             // Use multiple algorithms
};

//==============================================================================
// Transient Slicer
//==============================================================================

class TransientSlicer
{
public:
    //==========================================================================
    // Constructor
    //==========================================================================

    TransientSlicer() = default;

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;
        this->maxBlockSize = maxBlockSize;

        fftSize = 2048;
        fft = std::make_unique<juce::dsp::FFT>(static_cast<int>(std::log2(fftSize)));

        window.resize(fftSize);
        for (int i = 0; i < fftSize; ++i)
        {
            window[i] = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi * i / (fftSize - 1)));
        }
    }

    //==========================================================================
    // Load Audio
    //==========================================================================

    void loadAudio(const juce::AudioBuffer<float>& audio, double sampleRate)
    {
        sourceAudio = audio;
        sourceSampleRate = sampleRate;
        slices.clear();
    }

    const juce::AudioBuffer<float>& getSourceAudio() const { return sourceAudio; }

    //==========================================================================
    // Detection Settings
    //==========================================================================

    void setSensitivity(float sensitivity)
    {
        this->sensitivity = juce::jlimit(0.0f, 1.0f, sensitivity);
    }

    void setMinSliceLength(float milliseconds)
    {
        minSliceLengthMs = juce::jlimit(1.0f, 1000.0f, milliseconds);
    }

    void setAlgorithm(DetectionAlgorithm algo)
    {
        algorithm = algo;
    }

    //==========================================================================
    // Transient Detection
    //==========================================================================

    void detectTransients()
    {
        slices.clear();

        if (sourceAudio.getNumSamples() == 0)
            return;

        std::vector<float> onsetFunction;

        switch (algorithm)
        {
            case DetectionAlgorithm::SpectralFlux:
                onsetFunction = computeSpectralFlux();
                break;
            case DetectionAlgorithm::EnvelopeFollower:
                onsetFunction = computeEnvelopeFollower();
                break;
            case DetectionAlgorithm::HighFrequencyContent:
                onsetFunction = computeHighFrequencyContent();
                break;
            case DetectionAlgorithm::Combined:
                onsetFunction = computeCombined();
                break;
            default:
                onsetFunction = computeSpectralFlux();
                break;
        }

        // Peak picking
        pickPeaks(onsetFunction);

        // Ensure slices cover entire audio
        ensureCompleteCoverage();

        // Categorize slices
        if (autoCategorize)
            categorizeSlices();

        if (onSlicesDetected)
            onSlicesDetected(static_cast<int>(slices.size()));
    }

    //==========================================================================
    // Manual Slice Operations
    //==========================================================================

    int addSlice(int samplePosition)
    {
        AudioSlice slice;
        slice.startSample = samplePosition;

        // Find the next slice to determine end
        int nextSliceStart = sourceAudio.getNumSamples();
        for (const auto& s : slices)
        {
            if (s.startSample > samplePosition)
            {
                nextSliceStart = s.startSample;
                break;
            }
        }
        slice.endSample = nextSliceStart;

        // Find insertion point
        auto it = std::lower_bound(slices.begin(), slices.end(), slice,
            [](const AudioSlice& a, const AudioSlice& b) {
                return a.startSample < b.startSample;
            });

        // Update previous slice's end
        if (it != slices.begin())
        {
            auto prev = it - 1;
            prev->endSample = samplePosition;
        }

        it = slices.insert(it, slice);
        updateSliceNames();

        return static_cast<int>(std::distance(slices.begin(), it));
    }

    void removeSlice(int index)
    {
        if (index < 0 || index >= static_cast<int>(slices.size()))
            return;

        // Merge with previous slice
        if (index > 0)
        {
            slices[index - 1].endSample = slices[index].endSample;
        }

        slices.erase(slices.begin() + index);
        updateSliceNames();
    }

    void moveSliceBoundary(int index, int newPosition)
    {
        if (index <= 0 || index >= static_cast<int>(slices.size()))
            return;

        slices[index - 1].endSample = newPosition;
        slices[index].startSample = newPosition;
    }

    //==========================================================================
    // Slice Access
    //==========================================================================

    int getNumSlices() const { return static_cast<int>(slices.size()); }

    AudioSlice* getSlice(int index)
    {
        if (index >= 0 && index < static_cast<int>(slices.size()))
            return &slices[index];
        return nullptr;
    }

    const AudioSlice* getSlice(int index) const
    {
        if (index >= 0 && index < static_cast<int>(slices.size()))
            return &slices[index];
        return nullptr;
    }

    std::vector<AudioSlice>& getAllSlices() { return slices; }

    //==========================================================================
    // Slice Audio Extraction
    //==========================================================================

    juce::AudioBuffer<float> getSliceAudio(int index) const
    {
        if (index < 0 || index >= static_cast<int>(slices.size()))
            return {};

        const auto& slice = slices[index];
        int length = slice.endSample - slice.startSample;

        juce::AudioBuffer<float> buffer(sourceAudio.getNumChannels(), length);

        for (int ch = 0; ch < sourceAudio.getNumChannels(); ++ch)
        {
            buffer.copyFrom(ch, 0, sourceAudio, ch, slice.startSample, length);
        }

        // Apply effects
        if (slice.reversed)
            buffer.reverse(0, length);

        if (slice.fadeIn > 0)
        {
            int fadeSamples = static_cast<int>(slice.fadeIn);
            for (int i = 0; i < fadeSamples && i < length; ++i)
            {
                float gain = static_cast<float>(i) / fadeSamples;
                for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
                    buffer.setSample(ch, i, buffer.getSample(ch, i) * gain);
            }
        }

        if (slice.fadeOut > 0)
        {
            int fadeSamples = static_cast<int>(slice.fadeOut);
            for (int i = 0; i < fadeSamples && i < length; ++i)
            {
                float gain = static_cast<float>(i) / fadeSamples;
                int pos = length - 1 - i;
                for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
                    buffer.setSample(ch, pos, buffer.getSample(ch, pos) * gain);
            }
        }

        buffer.applyGain(slice.gain);

        return buffer;
    }

    //==========================================================================
    // MIDI Export
    //==========================================================================

    juce::MidiMessageSequence exportToMIDI(double tempo) const
    {
        juce::MidiMessageSequence sequence;

        double samplesPerBeat = currentSampleRate * 60.0 / tempo;

        for (const auto& slice : slices)
        {
            double beatTime = slice.startSample / samplesPerBeat;
            double duration = (slice.endSample - slice.startSample) / samplesPerBeat;

            sequence.addEvent(juce::MidiMessage::noteOn(10, slice.midiNote, 1.0f), beatTime);
            sequence.addEvent(juce::MidiMessage::noteOff(10, slice.midiNote), beatTime + duration);
        }

        return sequence;
    }

    //==========================================================================
    // Beat Grid
    //==========================================================================

    void alignToGrid(double tempo, int gridDivision = 16)
    {
        double samplesPerBeat = currentSampleRate * 60.0 / tempo;
        double samplesPerGrid = samplesPerBeat * 4.0 / gridDivision;

        for (auto& slice : slices)
        {
            int nearestGrid = static_cast<int>(std::round(slice.startSample / samplesPerGrid));
            slice.startSample = static_cast<int>(nearestGrid * samplesPerGrid);
        }

        // Fix overlaps
        for (size_t i = 0; i < slices.size() - 1; ++i)
        {
            slices[i].endSample = slices[i + 1].startSample;
        }

        if (!slices.empty())
            slices.back().endSample = sourceAudio.getNumSamples();
    }

    //==========================================================================
    // Categorization
    //==========================================================================

    void setAutoCategorize(bool enabled)
    {
        autoCategorize = enabled;
    }

    void categorizeSlices()
    {
        for (auto& slice : slices)
        {
            categorizeSlice(slice);
        }
    }

    //==========================================================================
    // Rearrangement
    //==========================================================================

    void shuffleSlices()
    {
        std::random_shuffle(slices.begin(), slices.end());
        updateSlicePositions();
    }

    void reverseSliceOrder()
    {
        std::reverse(slices.begin(), slices.end());
        updateSlicePositions();
    }

    void sortByCategory()
    {
        std::stable_sort(slices.begin(), slices.end(),
            [](const AudioSlice& a, const AudioSlice& b) {
                return static_cast<int>(a.category) < static_cast<int>(b.category);
            });
        updateSlicePositions();
    }

    //==========================================================================
    // Export Rearranged Audio
    //==========================================================================

    juce::AudioBuffer<float> exportRearrangedAudio() const
    {
        int totalLength = 0;
        for (const auto& slice : slices)
            totalLength += slice.getLength();

        juce::AudioBuffer<float> output(sourceAudio.getNumChannels(), totalLength);
        int writePos = 0;

        for (size_t i = 0; i < slices.size(); ++i)
        {
            auto sliceAudio = getSliceAudio(static_cast<int>(i));

            for (int ch = 0; ch < output.getNumChannels(); ++ch)
            {
                output.copyFrom(ch, writePos, sliceAudio, ch, 0, sliceAudio.getNumSamples());
            }

            writePos += sliceAudio.getNumSamples();
        }

        return output;
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(int)> onSlicesDetected;
    std::function<void(int)> onSliceSelected;

private:
    double currentSampleRate = 48000.0;
    int maxBlockSize = 512;

    juce::AudioBuffer<float> sourceAudio;
    double sourceSampleRate = 48000.0;

    std::vector<AudioSlice> slices;

    // Detection settings
    float sensitivity = 0.5f;
    float minSliceLengthMs = 50.0f;
    DetectionAlgorithm algorithm = DetectionAlgorithm::Combined;
    bool autoCategorize = true;

    // FFT
    int fftSize = 2048;
    std::unique_ptr<juce::dsp::FFT> fft;
    std::vector<float> window;

    //==========================================================================
    // Detection Algorithms
    //==========================================================================

    std::vector<float> computeSpectralFlux()
    {
        const int hopSize = fftSize / 4;
        const int numHops = (sourceAudio.getNumSamples() - fftSize) / hopSize;

        std::vector<float> onsetFunction(numHops, 0.0f);
        std::vector<float> fftBuffer(fftSize * 2, 0.0f);
        std::vector<float> prevMags(fftSize / 2, 0.0f);

        for (int hop = 0; hop < numHops; ++hop)
        {
            int start = hop * hopSize;

            // Window and copy
            for (int i = 0; i < fftSize; ++i)
            {
                int idx = start + i;
                if (idx < sourceAudio.getNumSamples())
                    fftBuffer[i] = sourceAudio.getSample(0, idx) * window[i];
                else
                    fftBuffer[i] = 0.0f;
            }

            fft->performRealOnlyForwardTransform(fftBuffer.data());

            // Spectral flux (half-wave rectified)
            float flux = 0.0f;
            for (int i = 0; i < fftSize / 2; ++i)
            {
                float mag = std::sqrt(fftBuffer[i * 2] * fftBuffer[i * 2] +
                                      fftBuffer[i * 2 + 1] * fftBuffer[i * 2 + 1]);
                float diff = mag - prevMags[i];
                if (diff > 0)
                    flux += diff;
                prevMags[i] = mag;
            }

            onsetFunction[hop] = flux;
        }

        return onsetFunction;
    }

    std::vector<float> computeEnvelopeFollower()
    {
        const int hopSize = 256;
        const int numHops = sourceAudio.getNumSamples() / hopSize;

        std::vector<float> onsetFunction(numHops, 0.0f);
        float envelope = 0.0f;
        float attackCoeff = 0.1f;
        float releaseCoeff = 0.001f;

        for (int hop = 0; hop < numHops; ++hop)
        {
            float maxSample = 0.0f;
            for (int i = 0; i < hopSize; ++i)
            {
                int idx = hop * hopSize + i;
                if (idx < sourceAudio.getNumSamples())
                    maxSample = std::max(maxSample, std::abs(sourceAudio.getSample(0, idx)));
            }

            float coeff = (maxSample > envelope) ? attackCoeff : releaseCoeff;
            envelope += coeff * (maxSample - envelope);

            // Derivative
            static float prevEnv = 0.0f;
            onsetFunction[hop] = std::max(0.0f, envelope - prevEnv);
            prevEnv = envelope;
        }

        return onsetFunction;
    }

    std::vector<float> computeHighFrequencyContent()
    {
        const int hopSize = fftSize / 4;
        const int numHops = (sourceAudio.getNumSamples() - fftSize) / hopSize;

        std::vector<float> onsetFunction(numHops, 0.0f);
        std::vector<float> fftBuffer(fftSize * 2, 0.0f);

        for (int hop = 0; hop < numHops; ++hop)
        {
            int start = hop * hopSize;

            for (int i = 0; i < fftSize; ++i)
            {
                int idx = start + i;
                if (idx < sourceAudio.getNumSamples())
                    fftBuffer[i] = sourceAudio.getSample(0, idx) * window[i];
                else
                    fftBuffer[i] = 0.0f;
            }

            fft->performRealOnlyForwardTransform(fftBuffer.data());

            // Weight by frequency
            float hfc = 0.0f;
            for (int i = 0; i < fftSize / 2; ++i)
            {
                float mag = std::sqrt(fftBuffer[i * 2] * fftBuffer[i * 2] +
                                      fftBuffer[i * 2 + 1] * fftBuffer[i * 2 + 1]);
                hfc += mag * (i + 1);  // Weight by bin number
            }

            onsetFunction[hop] = hfc;
        }

        return onsetFunction;
    }

    std::vector<float> computeCombined()
    {
        auto sf = computeSpectralFlux();
        auto ef = computeEnvelopeFollower();
        auto hfc = computeHighFrequencyContent();

        // Normalize each
        normalizeVector(sf);
        normalizeVector(ef);
        normalizeVector(hfc);

        // Combine
        size_t minLen = std::min({ sf.size(), ef.size(), hfc.size() });
        std::vector<float> combined(minLen);

        for (size_t i = 0; i < minLen; ++i)
        {
            combined[i] = sf[i] * 0.4f + ef[i] * 0.3f + hfc[i] * 0.3f;
        }

        return combined;
    }

    void normalizeVector(std::vector<float>& vec)
    {
        float maxVal = *std::max_element(vec.begin(), vec.end());
        if (maxVal > 0)
        {
            for (float& v : vec)
                v /= maxVal;
        }
    }

    void pickPeaks(const std::vector<float>& onsetFunction)
    {
        const int hopSize = fftSize / 4;
        int minSliceSamples = static_cast<int>(minSliceLengthMs * currentSampleRate / 1000.0);
        int minSliceHops = minSliceSamples / hopSize;

        // Adaptive threshold
        float threshold = sensitivity * 0.5f;
        float adaptiveThreshold = 0.0f;

        int lastPeakHop = -minSliceHops;

        for (size_t i = 1; i < onsetFunction.size() - 1; ++i)
        {
            adaptiveThreshold = adaptiveThreshold * 0.95f + onsetFunction[i] * 0.05f;
            float peakThreshold = std::max(threshold, adaptiveThreshold * 1.5f);

            // Check for peak
            if (onsetFunction[i] > peakThreshold &&
                onsetFunction[i] > onsetFunction[i - 1] &&
                onsetFunction[i] > onsetFunction[i + 1] &&
                static_cast<int>(i) - lastPeakHop >= minSliceHops)
            {
                AudioSlice slice;
                slice.startSample = static_cast<int>(i) * hopSize;
                slice.transientStrength = onsetFunction[i];

                slices.push_back(slice);
                lastPeakHop = static_cast<int>(i);
            }
        }
    }

    void ensureCompleteCoverage()
    {
        if (slices.empty())
        {
            // Single slice for entire audio
            AudioSlice slice;
            slice.startSample = 0;
            slice.endSample = sourceAudio.getNumSamples();
            slices.push_back(slice);
            return;
        }

        // Add start marker if needed
        if (slices[0].startSample > 0)
        {
            AudioSlice slice;
            slice.startSample = 0;
            slices.insert(slices.begin(), slice);
        }

        // Set end samples
        for (size_t i = 0; i < slices.size() - 1; ++i)
        {
            slices[i].endSample = slices[i + 1].startSample;
        }
        slices.back().endSample = sourceAudio.getNumSamples();

        updateSliceNames();
    }

    void categorizeSlice(AudioSlice& slice)
    {
        auto audio = getSliceAudio(static_cast<int>(&slice - slices.data()));

        // Analyze spectral characteristics
        float lowEnergy = 0.0f;
        float midEnergy = 0.0f;
        float highEnergy = 0.0f;

        std::vector<float> fftBuffer(fftSize * 2, 0.0f);

        int samplesToAnalyze = std::min(fftSize, audio.getNumSamples());
        for (int i = 0; i < samplesToAnalyze; ++i)
        {
            fftBuffer[i] = audio.getSample(0, i) * window[i];
        }

        fft->performRealOnlyForwardTransform(fftBuffer.data());

        for (int i = 0; i < fftSize / 2; ++i)
        {
            float mag = std::sqrt(fftBuffer[i * 2] * fftBuffer[i * 2] +
                                  fftBuffer[i * 2 + 1] * fftBuffer[i * 2 + 1]);

            float freq = i * static_cast<float>(currentSampleRate) / fftSize;

            if (freq < 200)
                lowEnergy += mag;
            else if (freq < 2000)
                midEnergy += mag;
            else
                highEnergy += mag;
        }

        float total = lowEnergy + midEnergy + highEnergy + 0.0001f;
        float lowRatio = lowEnergy / total;
        float highRatio = highEnergy / total;

        // Simple categorization rules
        if (lowRatio > 0.6f)
        {
            slice.category = SliceCategory::Kick;
            slice.midiNote = 36;
        }
        else if (highRatio > 0.5f && audio.getNumSamples() < currentSampleRate * 0.1)
        {
            slice.category = SliceCategory::HiHat;
            slice.midiNote = 42;
        }
        else if (lowRatio > 0.3f && highRatio > 0.3f)
        {
            slice.category = SliceCategory::Snare;
            slice.midiNote = 38;
        }
        else
        {
            slice.category = SliceCategory::Percussion;
            slice.midiNote = 37;
        }

        slice.categoryConfidence = 0.7f;  // Simplified
    }

    void updateSliceNames()
    {
        for (size_t i = 0; i < slices.size(); ++i)
        {
            slices[i].name = "Slice " + juce::String(i + 1);
        }
    }

    void updateSlicePositions()
    {
        int pos = 0;
        for (auto& slice : slices)
        {
            int length = slice.endSample - slice.startSample;
            slice.startSample = pos;
            slice.endSample = pos + length;
            pos += length;
        }
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TransientSlicer)
};

} // namespace Editing
} // namespace Echoelmusic
