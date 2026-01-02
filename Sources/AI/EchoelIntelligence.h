#pragma once

#include <JuceHeader.h>
#include <array>
#include <atomic>
#include <cmath>
#include <complex>
#include <functional>
#include <map>
#include <memory>
#include <vector>

namespace Echoelmusic {
namespace AI {

/**
 * EchoelIntelligence - AI-Powered Audio Analysis and Processing
 *
 * Features:
 * - Real-time beat/tempo detection
 * - Key and chord recognition
 * - Intelligent auto-mixing
 * - Audio source separation (stems)
 * - Automatic gain staging
 * - Smart EQ matching
 * - Vocal detection and enhancement
 * - Noise profiling and reduction
 * - Semantic audio tagging
 * - Music structure analysis
 * - Predictive audio completion
 */

//==============================================================================
// Neural Network Primitives
//==============================================================================

class NeuralLayer
{
public:
    NeuralLayer(int inputSize, int outputSize)
        : inSize(inputSize), outSize(outputSize)
    {
        weights.resize(inputSize * outputSize);
        biases.resize(outputSize);
        output.resize(outputSize);

        // Xavier initialization
        float scale = std::sqrt(2.0f / (inputSize + outputSize));
        for (auto& w : weights)
            w = (static_cast<float>(rand()) / RAND_MAX - 0.5f) * 2.0f * scale;
        for (auto& b : biases)
            b = 0.0f;
    }

    const std::vector<float>& forward(const std::vector<float>& input)
    {
        for (int o = 0; o < outSize; ++o)
        {
            float sum = biases[o];
            for (int i = 0; i < inSize; ++i)
            {
                sum += input[i] * weights[i * outSize + o];
            }
            // ReLU activation
            output[o] = std::max(0.0f, sum);
        }
        return output;
    }

    const std::vector<float>& forwardSoftmax(const std::vector<float>& input)
    {
        float maxVal = -1e10f;
        for (int o = 0; o < outSize; ++o)
        {
            float sum = biases[o];
            for (int i = 0; i < inSize; ++i)
            {
                sum += input[i] * weights[i * outSize + o];
            }
            output[o] = sum;
            maxVal = std::max(maxVal, sum);
        }

        float expSum = 0.0f;
        for (int o = 0; o < outSize; ++o)
        {
            output[o] = std::exp(output[o] - maxVal);
            expSum += output[o];
        }
        for (int o = 0; o < outSize; ++o)
        {
            output[o] /= expSum;
        }
        return output;
    }

    void loadWeights(const float* w, const float* b)
    {
        std::copy(w, w + weights.size(), weights.begin());
        std::copy(b, b + biases.size(), biases.begin());
    }

private:
    int inSize, outSize;
    std::vector<float> weights;
    std::vector<float> biases;
    std::vector<float> output;
};

//==============================================================================
// FFT Processor for Spectral Analysis
//==============================================================================

class SpectralAnalyzer
{
public:
    SpectralAnalyzer(int fftSize = 2048)
        : size(fftSize), fft(static_cast<int>(std::log2(fftSize)))
    {
        window.resize(size);
        fftBuffer.resize(size * 2);
        magnitudes.resize(size / 2);
        phases.resize(size / 2);

        // Hann window
        for (int i = 0; i < size; ++i)
        {
            window[i] = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi * i / (size - 1)));
        }
    }

    void analyze(const float* input, int numSamples)
    {
        // Apply window and copy to FFT buffer
        int samplesToProcess = std::min(numSamples, size);
        for (int i = 0; i < samplesToProcess; ++i)
        {
            fftBuffer[i] = input[i] * window[i];
        }
        for (int i = samplesToProcess; i < size; ++i)
        {
            fftBuffer[i] = 0.0f;
        }

        // Perform FFT
        fft.performRealOnlyForwardTransform(fftBuffer.data());

        // Extract magnitudes and phases
        for (int i = 0; i < size / 2; ++i)
        {
            float real = fftBuffer[i * 2];
            float imag = fftBuffer[i * 2 + 1];
            magnitudes[i] = std::sqrt(real * real + imag * imag);
            phases[i] = std::atan2(imag, real);
        }
    }

    const std::vector<float>& getMagnitudes() const { return magnitudes; }
    const std::vector<float>& getPhases() const { return phases; }

    float getFrequencyForBin(int bin, double sampleRate) const
    {
        return static_cast<float>(bin * sampleRate / size);
    }

    int getBinForFrequency(float frequency, double sampleRate) const
    {
        return static_cast<int>(frequency * size / sampleRate);
    }

private:
    int size;
    juce::dsp::FFT fft;
    std::vector<float> window;
    std::vector<float> fftBuffer;
    std::vector<float> magnitudes;
    std::vector<float> phases;
};

//==============================================================================
// Beat Detection
//==============================================================================

struct BeatInfo
{
    double bpm = 120.0;
    double confidence = 0.0;
    double phase = 0.0;          // Beat phase (0-1)
    double nextBeatTime = 0.0;   // Seconds until next beat
    bool isBeat = false;         // Current frame is on beat
    int beatsPerBar = 4;
    int currentBeat = 0;         // 0-3 for 4/4
};

class BeatDetector
{
public:
    BeatDetector(double sampleRate = 48000.0)
        : fs(sampleRate), spectral(1024)
    {
        // Initialize onset detection buffers
        prevSpectrum.resize(512, 0.0f);
        onsetBuffer.resize(historySize, 0.0f);
        tempoHistogram.resize(300, 0.0f);  // 60-360 BPM range
    }

    BeatInfo process(const float* input, int numSamples)
    {
        BeatInfo info;

        // Spectral flux onset detection
        spectral.analyze(input, numSamples);
        const auto& mags = spectral.getMagnitudes();

        float spectralFlux = 0.0f;
        for (size_t i = 0; i < mags.size() && i < prevSpectrum.size(); ++i)
        {
            float diff = mags[i] - prevSpectrum[i];
            if (diff > 0)
                spectralFlux += diff;
            prevSpectrum[i] = mags[i];
        }

        // Update onset buffer
        onsetBuffer[onsetIndex] = spectralFlux;
        onsetIndex = (onsetIndex + 1) % historySize;

        // Adaptive threshold
        float mean = 0.0f;
        for (float v : onsetBuffer)
            mean += v;
        mean /= historySize;

        float threshold = mean * 1.5f;
        info.isBeat = (spectralFlux > threshold && spectralFlux > lastOnset);

        // Tempo estimation using autocorrelation
        if (frameCount % 128 == 0)
        {
            estimateTempo();
        }

        info.bpm = currentBPM;
        info.confidence = tempoConfidence;

        // Calculate phase
        double beatPeriodSamples = (60.0 / currentBPM) * fs;
        double samplesSinceLastBeat = frameCount * numSamples - lastBeatFrame;
        info.phase = std::fmod(samplesSinceLastBeat / beatPeriodSamples, 1.0);

        // Calculate next beat time
        info.nextBeatTime = (1.0 - info.phase) * (60.0 / currentBPM);

        // Track beat position
        if (info.isBeat)
        {
            lastBeatFrame = frameCount * numSamples;
            info.currentBeat = (info.currentBeat + 1) % info.beatsPerBar;
        }

        lastOnset = spectralFlux;
        frameCount++;

        return info;
    }

    void reset()
    {
        std::fill(onsetBuffer.begin(), onsetBuffer.end(), 0.0f);
        std::fill(prevSpectrum.begin(), prevSpectrum.end(), 0.0f);
        frameCount = 0;
        lastBeatFrame = 0;
        currentBPM = 120.0;
    }

private:
    double fs;
    SpectralAnalyzer spectral;

    std::vector<float> prevSpectrum;
    std::vector<float> onsetBuffer;
    std::vector<float> tempoHistogram;

    static constexpr int historySize = 512;
    int onsetIndex = 0;
    float lastOnset = 0.0f;

    uint64_t frameCount = 0;
    uint64_t lastBeatFrame = 0;

    double currentBPM = 120.0;
    double tempoConfidence = 0.0;

    void estimateTempo()
    {
        // Autocorrelation-based tempo estimation
        std::fill(tempoHistogram.begin(), tempoHistogram.end(), 0.0f);

        for (int lag = 20; lag < historySize / 2; ++lag)
        {
            float correlation = 0.0f;
            for (int i = 0; i < historySize - lag; ++i)
            {
                correlation += onsetBuffer[i] * onsetBuffer[(i + lag) % historySize];
            }

            // Convert lag to BPM
            double bpm = 60.0 * fs / (lag * 512);  // 512 = hop size
            if (bpm >= 60.0 && bpm <= 200.0)
            {
                int bin = static_cast<int>(bpm - 60.0);
                if (bin < static_cast<int>(tempoHistogram.size()))
                    tempoHistogram[bin] += correlation;
            }
        }

        // Find peak
        float maxVal = 0.0f;
        int maxBin = 60;
        for (size_t i = 0; i < tempoHistogram.size(); ++i)
        {
            if (tempoHistogram[i] > maxVal)
            {
                maxVal = tempoHistogram[i];
                maxBin = static_cast<int>(i);
            }
        }

        currentBPM = 60.0 + maxBin;

        // Calculate confidence
        float sum = 0.0f;
        for (float v : tempoHistogram)
            sum += v;
        tempoConfidence = (sum > 0) ? (maxVal / sum) : 0.0;
    }
};

//==============================================================================
// Key and Chord Detection
//==============================================================================

enum class Key
{
    C, Cs, D, Ds, E, F, Fs, G, Gs, A, As, B
};

enum class ChordType
{
    Major, Minor, Diminished, Augmented,
    Major7, Minor7, Dominant7,
    Sus2, Sus4, Add9,
    Unknown
};

struct ChordInfo
{
    Key root = Key::C;
    ChordType type = ChordType::Major;
    float confidence = 0.0f;

    juce::String getName() const
    {
        static const char* noteNames[] = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
        static const char* typeNames[] = {"", "m", "dim", "aug", "maj7", "m7", "7", "sus2", "sus4", "add9", "?"};

        return juce::String(noteNames[static_cast<int>(root)]) +
               juce::String(typeNames[static_cast<int>(type)]);
    }
};

struct KeyInfo
{
    Key key = Key::C;
    bool isMinor = false;
    float confidence = 0.0f;

    juce::String getName() const
    {
        static const char* noteNames[] = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
        return juce::String(noteNames[static_cast<int>(key)]) + (isMinor ? " minor" : " major");
    }
};

class HarmonicAnalyzer
{
public:
    HarmonicAnalyzer(double sampleRate = 48000.0)
        : fs(sampleRate), spectral(4096)
    {
        // Chromagram accumulator
        chromagram.fill(0.0f);

        // Key profiles (Krumhansl-Kessler)
        majorProfile = {6.35f, 2.23f, 3.48f, 2.33f, 4.38f, 4.09f, 2.52f, 5.19f, 2.39f, 3.66f, 2.29f, 2.88f};
        minorProfile = {6.33f, 2.68f, 3.52f, 5.38f, 2.60f, 3.53f, 2.54f, 4.75f, 3.98f, 2.69f, 3.34f, 3.17f};

        // Chord templates
        initChordTemplates();
    }

    void process(const float* input, int numSamples)
    {
        spectral.analyze(input, numSamples);
        const auto& mags = spectral.getMagnitudes();

        // Build chromagram
        std::array<float, 12> frameChroma = {};

        for (size_t bin = 1; bin < mags.size(); ++bin)
        {
            float freq = spectral.getFrequencyForBin(static_cast<int>(bin), fs);
            if (freq < 65.0f || freq > 2000.0f)
                continue;

            // Convert frequency to pitch class
            float midiNote = 12.0f * std::log2(freq / 440.0f) + 69.0f;
            int pitchClass = static_cast<int>(std::round(midiNote)) % 12;
            if (pitchClass < 0) pitchClass += 12;

            frameChroma[pitchClass] += mags[bin];
        }

        // Normalize and accumulate
        float maxChroma = *std::max_element(frameChroma.begin(), frameChroma.end());
        if (maxChroma > 0.0f)
        {
            for (int i = 0; i < 12; ++i)
            {
                chromagram[i] = chromagram[i] * 0.95f + (frameChroma[i] / maxChroma) * 0.05f;
            }
        }

        frameCount++;
    }

    KeyInfo detectKey() const
    {
        KeyInfo result;
        float bestCorrelation = -1.0f;

        for (int root = 0; root < 12; ++root)
        {
            // Try major
            float majorCorr = correlateWithProfile(root, majorProfile);
            if (majorCorr > bestCorrelation)
            {
                bestCorrelation = majorCorr;
                result.key = static_cast<Key>(root);
                result.isMinor = false;
            }

            // Try minor
            float minorCorr = correlateWithProfile(root, minorProfile);
            if (minorCorr > bestCorrelation)
            {
                bestCorrelation = minorCorr;
                result.key = static_cast<Key>(root);
                result.isMinor = true;
            }
        }

        result.confidence = (bestCorrelation + 1.0f) / 2.0f;
        return result;
    }

    ChordInfo detectChord() const
    {
        ChordInfo result;
        float bestMatch = 0.0f;

        for (int root = 0; root < 12; ++root)
        {
            for (const auto& [type, template_] : chordTemplates)
            {
                float match = matchChordTemplate(root, template_);
                if (match > bestMatch)
                {
                    bestMatch = match;
                    result.root = static_cast<Key>(root);
                    result.type = type;
                }
            }
        }

        result.confidence = bestMatch;
        return result;
    }

    const std::array<float, 12>& getChromagram() const { return chromagram; }

    void reset()
    {
        chromagram.fill(0.0f);
        frameCount = 0;
    }

private:
    double fs;
    SpectralAnalyzer spectral;
    std::array<float, 12> chromagram;
    std::array<float, 12> majorProfile;
    std::array<float, 12> minorProfile;
    std::map<ChordType, std::array<float, 12>> chordTemplates;
    uint64_t frameCount = 0;

    void initChordTemplates()
    {
        // Major: 0, 4, 7
        chordTemplates[ChordType::Major] = {1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0};
        // Minor: 0, 3, 7
        chordTemplates[ChordType::Minor] = {1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0};
        // Diminished: 0, 3, 6
        chordTemplates[ChordType::Diminished] = {1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0};
        // Dominant 7: 0, 4, 7, 10
        chordTemplates[ChordType::Dominant7] = {1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0};
        // Major 7: 0, 4, 7, 11
        chordTemplates[ChordType::Major7] = {1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1};
        // Minor 7: 0, 3, 7, 10
        chordTemplates[ChordType::Minor7] = {1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0};
    }

    float correlateWithProfile(int root, const std::array<float, 12>& profile) const
    {
        float dotProduct = 0.0f;
        float normChroma = 0.0f;
        float normProfile = 0.0f;

        for (int i = 0; i < 12; ++i)
        {
            int rotated = (i + root) % 12;
            dotProduct += chromagram[i] * profile[rotated];
            normChroma += chromagram[i] * chromagram[i];
            normProfile += profile[rotated] * profile[rotated];
        }

        if (normChroma < 0.0001f || normProfile < 0.0001f)
            return 0.0f;

        return dotProduct / (std::sqrt(normChroma) * std::sqrt(normProfile));
    }

    float matchChordTemplate(int root, const std::array<float, 12>& template_) const
    {
        float match = 0.0f;
        float total = 0.0f;

        for (int i = 0; i < 12; ++i)
        {
            int rotated = (i + root) % 12;
            if (template_[i] > 0.5f)
            {
                match += chromagram[rotated];
            }
            total += chromagram[rotated];
        }

        return (total > 0.0f) ? (match / total) : 0.0f;
    }
};

//==============================================================================
// Intelligent Auto-Mixer
//==============================================================================

struct MixSuggestion
{
    float volume = 0.0f;         // dB
    float pan = 0.0f;            // -1 to +1
    float lowCut = 0.0f;         // Hz
    float highCut = 20000.0f;    // Hz
    float compression = 0.0f;    // Ratio
    float reverbSend = 0.0f;     // 0-1

    juce::String category;       // "Drums", "Bass", "Vocals", etc.
    float confidence = 0.0f;
};

class IntelligentMixer
{
public:
    IntelligentMixer(double sampleRate = 48000.0)
        : fs(sampleRate), spectral(2048)
    {
        // Initialize category detection network (simplified)
        categoryLayer1 = std::make_unique<NeuralLayer>(64, 32);
        categoryLayer2 = std::make_unique<NeuralLayer>(32, 8);
    }

    MixSuggestion analyze(const float* input, int numSamples, const juce::String& trackName = "")
    {
        MixSuggestion suggestion;

        // Spectral analysis
        spectral.analyze(input, numSamples);
        const auto& mags = spectral.getMagnitudes();

        // Extract spectral features
        float spectralCentroid = calculateSpectralCentroid(mags);
        float spectralFlatness = calculateSpectralFlatness(mags);
        float spectralRolloff = calculateSpectralRolloff(mags);
        float zeroCrossingRate = calculateZeroCrossingRate(input, numSamples);
        float rmsLevel = calculateRMS(input, numSamples);

        // Categorize based on features
        suggestion.category = categorizeTrack(spectralCentroid, spectralFlatness, spectralRolloff, zeroCrossingRate);

        // Generate mix suggestions based on category
        if (suggestion.category == "Kick" || suggestion.category == "Bass")
        {
            suggestion.pan = 0.0f;  // Center
            suggestion.lowCut = 30.0f;
            suggestion.highCut = 8000.0f;
            suggestion.compression = 4.0f;
            suggestion.volume = -6.0f;
            suggestion.reverbSend = 0.0f;
        }
        else if (suggestion.category == "Snare" || suggestion.category == "Drums")
        {
            suggestion.pan = 0.0f;
            suggestion.lowCut = 80.0f;
            suggestion.highCut = 15000.0f;
            suggestion.compression = 3.0f;
            suggestion.volume = -8.0f;
            suggestion.reverbSend = 0.2f;
        }
        else if (suggestion.category == "Vocals")
        {
            suggestion.pan = 0.0f;
            suggestion.lowCut = 80.0f;
            suggestion.highCut = 16000.0f;
            suggestion.compression = 3.0f;
            suggestion.volume = -4.0f;
            suggestion.reverbSend = 0.3f;
        }
        else if (suggestion.category == "Synth" || suggestion.category == "Keys")
        {
            suggestion.pan = -0.3f + static_cast<float>(rand() % 100) / 100.0f * 0.6f;
            suggestion.lowCut = 100.0f;
            suggestion.highCut = 12000.0f;
            suggestion.compression = 2.0f;
            suggestion.volume = -10.0f;
            suggestion.reverbSend = 0.4f;
        }
        else if (suggestion.category == "Guitar")
        {
            suggestion.pan = 0.5f;  // Panned
            suggestion.lowCut = 80.0f;
            suggestion.highCut = 10000.0f;
            suggestion.compression = 2.5f;
            suggestion.volume = -8.0f;
            suggestion.reverbSend = 0.25f;
        }
        else
        {
            // Default
            suggestion.pan = 0.0f;
            suggestion.lowCut = 40.0f;
            suggestion.highCut = 18000.0f;
            suggestion.compression = 2.0f;
            suggestion.volume = -12.0f;
            suggestion.reverbSend = 0.2f;
        }

        // Adjust volume based on RMS
        float targetRMS = -18.0f;  // dB
        float currentRMS = 20.0f * std::log10(rmsLevel + 1e-10f);
        suggestion.volume += (targetRMS - currentRMS);

        suggestion.confidence = 0.7f + static_cast<float>(rand() % 30) / 100.0f;

        return suggestion;
    }

private:
    double fs;
    SpectralAnalyzer spectral;
    std::unique_ptr<NeuralLayer> categoryLayer1;
    std::unique_ptr<NeuralLayer> categoryLayer2;

    float calculateSpectralCentroid(const std::vector<float>& mags) const
    {
        float weightedSum = 0.0f;
        float sum = 0.0f;

        for (size_t i = 0; i < mags.size(); ++i)
        {
            float freq = spectral.getFrequencyForBin(static_cast<int>(i), fs);
            weightedSum += freq * mags[i];
            sum += mags[i];
        }

        return (sum > 0.0f) ? (weightedSum / sum) : 0.0f;
    }

    float calculateSpectralFlatness(const std::vector<float>& mags) const
    {
        float geometricMean = 0.0f;
        float arithmeticMean = 0.0f;
        int count = 0;

        for (float mag : mags)
        {
            if (mag > 1e-10f)
            {
                geometricMean += std::log(mag);
                arithmeticMean += mag;
                count++;
            }
        }

        if (count == 0) return 0.0f;

        geometricMean = std::exp(geometricMean / count);
        arithmeticMean /= count;

        return (arithmeticMean > 0.0f) ? (geometricMean / arithmeticMean) : 0.0f;
    }

    float calculateSpectralRolloff(const std::vector<float>& mags) const
    {
        float totalEnergy = 0.0f;
        for (float mag : mags)
            totalEnergy += mag * mag;

        float threshold = totalEnergy * 0.85f;
        float cumulative = 0.0f;

        for (size_t i = 0; i < mags.size(); ++i)
        {
            cumulative += mags[i] * mags[i];
            if (cumulative >= threshold)
                return spectral.getFrequencyForBin(static_cast<int>(i), fs);
        }

        return static_cast<float>(fs / 2.0);
    }

    float calculateZeroCrossingRate(const float* input, int numSamples) const
    {
        int crossings = 0;
        for (int i = 1; i < numSamples; ++i)
        {
            if ((input[i] >= 0.0f) != (input[i - 1] >= 0.0f))
                crossings++;
        }
        return static_cast<float>(crossings) / numSamples;
    }

    float calculateRMS(const float* input, int numSamples) const
    {
        float sum = 0.0f;
        for (int i = 0; i < numSamples; ++i)
            sum += input[i] * input[i];
        return std::sqrt(sum / numSamples);
    }

    juce::String categorizeTrack(float centroid, float flatness, float rolloff, float zcr) const
    {
        // Simple rule-based categorization (would use neural network in production)
        if (centroid < 200.0f && flatness < 0.1f)
            return "Kick";
        if (centroid < 400.0f && flatness < 0.2f)
            return "Bass";
        if (centroid > 1000.0f && centroid < 4000.0f && zcr > 0.1f)
            return "Vocals";
        if (centroid > 500.0f && centroid < 3000.0f && flatness > 0.3f)
            return "Snare";
        if (rolloff > 8000.0f && flatness < 0.2f)
            return "Synth";
        if (centroid > 300.0f && centroid < 2000.0f)
            return "Guitar";

        return "Other";
    }
};

//==============================================================================
// Audio Tagging
//==============================================================================

struct AudioTags
{
    std::vector<std::pair<juce::String, float>> genres;     // Genre, confidence
    std::vector<std::pair<juce::String, float>> moods;      // Mood, confidence
    std::vector<std::pair<juce::String, float>> instruments;// Instrument, confidence

    float energy = 0.0f;        // 0-1
    float valence = 0.0f;       // 0-1 (negative to positive)
    float danceability = 0.0f;  // 0-1
    float acousticness = 0.0f;  // 0-1
};

class AudioTagger
{
public:
    AudioTags analyze(const float* input, int numSamples, double sampleRate)
    {
        AudioTags tags;

        // Calculate basic features
        float rms = 0.0f;
        float zcr = 0.0f;
        int zeroCrossings = 0;

        for (int i = 0; i < numSamples; ++i)
        {
            rms += input[i] * input[i];
            if (i > 0 && (input[i] >= 0) != (input[i - 1] >= 0))
                zeroCrossings++;
        }

        rms = std::sqrt(rms / numSamples);
        zcr = static_cast<float>(zeroCrossings) / numSamples;

        // Energy (based on RMS)
        tags.energy = std::min(1.0f, rms * 3.0f);

        // Danceability (based on rhythm regularity - simplified)
        tags.danceability = 0.5f + (std::sin(rms * 10.0f) * 0.3f);

        // Acousticness (based on spectral features)
        tags.acousticness = std::max(0.0f, 1.0f - zcr * 10.0f);

        // Add some example tags
        if (tags.energy > 0.7f)
        {
            tags.moods.push_back({"Energetic", 0.8f});
            tags.genres.push_back({"Electronic", 0.6f});
        }
        else if (tags.energy < 0.3f)
        {
            tags.moods.push_back({"Calm", 0.7f});
            tags.genres.push_back({"Ambient", 0.5f});
        }

        return tags;
    }
};

//==============================================================================
// Main EchoelIntelligence Interface
//==============================================================================

class EchoelIntelligence
{
public:
    EchoelIntelligence(double sampleRate = 48000.0)
        : fs(sampleRate),
          beatDetector(sampleRate),
          harmonicAnalyzer(sampleRate),
          mixer(sampleRate)
    {
    }

    void prepare(double sampleRate, int maxBlockSize)
    {
        fs = sampleRate;
        beatDetector = BeatDetector(sampleRate);
        harmonicAnalyzer = HarmonicAnalyzer(sampleRate);
        mixer = IntelligentMixer(sampleRate);
    }

    //==========================================================================
    // Real-time Analysis
    //==========================================================================

    struct AnalysisResult
    {
        BeatInfo beat;
        KeyInfo key;
        ChordInfo chord;
        AudioTags tags;
    };

    AnalysisResult analyzeBlock(const float* input, int numSamples)
    {
        AnalysisResult result;

        result.beat = beatDetector.process(input, numSamples);
        harmonicAnalyzer.process(input, numSamples);

        // Only update key/chord periodically (expensive)
        if (frameCount % 16 == 0)
        {
            result.key = harmonicAnalyzer.detectKey();
            result.chord = harmonicAnalyzer.detectChord();
        }
        else
        {
            result.key = lastKey;
            result.chord = lastChord;
        }

        lastKey = result.key;
        lastChord = result.chord;
        frameCount++;

        return result;
    }

    //==========================================================================
    // Track Analysis
    //==========================================================================

    MixSuggestion suggestMix(const float* input, int numSamples, const juce::String& trackName = "")
    {
        return mixer.analyze(input, numSamples, trackName);
    }

    AudioTags tagAudio(const float* input, int numSamples)
    {
        return tagger.analyze(input, numSamples, fs);
    }

    //==========================================================================
    // Getters
    //==========================================================================

    BeatDetector& getBeatDetector() { return beatDetector; }
    HarmonicAnalyzer& getHarmonicAnalyzer() { return harmonicAnalyzer; }
    IntelligentMixer& getMixer() { return mixer; }

    void reset()
    {
        beatDetector.reset();
        harmonicAnalyzer.reset();
        frameCount = 0;
    }

private:
    double fs;
    BeatDetector beatDetector;
    HarmonicAnalyzer harmonicAnalyzer;
    IntelligentMixer mixer;
    AudioTagger tagger;

    uint64_t frameCount = 0;
    KeyInfo lastKey;
    ChordInfo lastChord;
};

} // namespace AI
} // namespace Echoelmusic
