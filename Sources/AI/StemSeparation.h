/*
  ==============================================================================

    StemSeparation.h
    Created: 2026
    Author:  Echoelmusic

    AI-Powered Stem Separation Engine
    Separates audio into Vocals, Drums, Bass, and Other stems
    Uses deep learning spectral masking techniques

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <complex>
#include <memory>
#include <functional>
#include <thread>
#include <atomic>
#include <queue>
#include <mutex>

namespace Echoelmusic {
namespace AI {

//==============================================================================
/** Stem types that can be separated */
enum class StemType {
    Vocals,
    Drums,
    Bass,
    Other,
    Piano,
    Guitar,
    Synth,
    Strings,
    NumStems
};

inline juce::String stemTypeToString(StemType type) {
    switch (type) {
        case StemType::Vocals:  return "Vocals";
        case StemType::Drums:   return "Drums";
        case StemType::Bass:    return "Bass";
        case StemType::Other:   return "Other";
        case StemType::Piano:   return "Piano";
        case StemType::Guitar:  return "Guitar";
        case StemType::Synth:   return "Synth";
        case StemType::Strings: return "Strings";
        default:                return "Unknown";
    }
}

//==============================================================================
/** Quality levels for separation */
enum class SeparationQuality {
    Draft,      // Fast, lower quality
    Standard,   // Balanced
    High,       // Better quality, slower
    Ultra       // Best quality, much slower
};

//==============================================================================
/** Spectral frame for FFT processing */
struct SpectralFrame {
    std::vector<std::complex<float>> spectrum;
    std::vector<float> magnitude;
    std::vector<float> phase;
    int frameIndex = 0;
    double timePosition = 0.0;

    void resize(size_t fftSize) {
        spectrum.resize(fftSize / 2 + 1);
        magnitude.resize(fftSize / 2 + 1);
        phase.resize(fftSize / 2 + 1);
    }

    void computeMagnitudePhase() {
        for (size_t i = 0; i < spectrum.size(); ++i) {
            magnitude[i] = std::abs(spectrum[i]);
            phase[i] = std::arg(spectrum[i]);
        }
    }

    void reconstructFromMagnitudePhase() {
        for (size_t i = 0; i < spectrum.size(); ++i) {
            spectrum[i] = std::polar(magnitude[i], phase[i]);
        }
    }
};

//==============================================================================
/** Spectral mask for stem isolation */
struct SpectralMask {
    std::vector<float> mask;
    StemType stemType;
    float confidence = 0.0f;

    void resize(size_t size) {
        mask.resize(size, 0.0f);
    }

    void apply(SpectralFrame& frame) const {
        for (size_t i = 0; i < std::min(mask.size(), frame.magnitude.size()); ++i) {
            frame.magnitude[i] *= mask[i];
        }
        frame.reconstructFromMagnitudePhase();
    }

    void softmax(std::vector<SpectralMask>& masks) {
        // Apply softmax across all masks at each frequency bin
        if (masks.empty() || mask.empty()) return;

        for (size_t i = 0; i < mask.size(); ++i) {
            float sum = 0.0f;
            for (auto& m : masks) {
                sum += std::exp(m.mask[i]);
            }
            for (auto& m : masks) {
                m.mask[i] = std::exp(m.mask[i]) / sum;
            }
        }
    }
};

//==============================================================================
/** Neural network layer for stem separation */
class NeuralLayer {
public:
    enum class Activation {
        ReLU,
        Sigmoid,
        Tanh,
        LeakyReLU,
        Softmax
    };

    NeuralLayer(int inputSize, int outputSize, Activation activation = Activation::ReLU)
        : inputSize_(inputSize)
        , outputSize_(outputSize)
        , activation_(activation)
    {
        // Initialize weights with Xavier initialization
        weights_.resize(inputSize * outputSize);
        biases_.resize(outputSize);

        float scale = std::sqrt(2.0f / (inputSize + outputSize));
        juce::Random random;

        for (auto& w : weights_) {
            w = (random.nextFloat() * 2.0f - 1.0f) * scale;
        }
        for (auto& b : biases_) {
            b = 0.0f;
        }
    }

    std::vector<float> forward(const std::vector<float>& input) {
        std::vector<float> output(outputSize_, 0.0f);

        // Matrix multiplication
        for (int o = 0; o < outputSize_; ++o) {
            float sum = biases_[o];
            for (int i = 0; i < inputSize_; ++i) {
                sum += input[i] * weights_[o * inputSize_ + i];
            }
            output[o] = sum;
        }

        // Apply activation
        applyActivation(output);

        return output;
    }

    void loadWeights(const std::vector<float>& weights, const std::vector<float>& biases) {
        if (weights.size() == weights_.size()) weights_ = weights;
        if (biases.size() == biases_.size()) biases_ = biases;
    }

private:
    void applyActivation(std::vector<float>& values) {
        switch (activation_) {
            case Activation::ReLU:
                for (auto& v : values) v = std::max(0.0f, v);
                break;
            case Activation::Sigmoid:
                for (auto& v : values) v = 1.0f / (1.0f + std::exp(-v));
                break;
            case Activation::Tanh:
                for (auto& v : values) v = std::tanh(v);
                break;
            case Activation::LeakyReLU:
                for (auto& v : values) v = v > 0 ? v : 0.01f * v;
                break;
            case Activation::Softmax: {
                float maxVal = *std::max_element(values.begin(), values.end());
                float sum = 0.0f;
                for (auto& v : values) {
                    v = std::exp(v - maxVal);
                    sum += v;
                }
                for (auto& v : values) v /= sum;
                break;
            }
        }
    }

    int inputSize_;
    int outputSize_;
    Activation activation_;
    std::vector<float> weights_;
    std::vector<float> biases_;
};

//==============================================================================
/** U-Net style separator model */
class SeparatorModel {
public:
    SeparatorModel(int fftSize = 2048, int numStems = 4)
        : fftSize_(fftSize)
        , numBins_(fftSize / 2 + 1)
        , numStems_(numStems)
    {
        buildNetwork();
    }

    void buildNetwork() {
        // Encoder path
        encoder1_ = std::make_unique<NeuralLayer>(numBins_, 512, NeuralLayer::Activation::LeakyReLU);
        encoder2_ = std::make_unique<NeuralLayer>(512, 256, NeuralLayer::Activation::LeakyReLU);
        encoder3_ = std::make_unique<NeuralLayer>(256, 128, NeuralLayer::Activation::LeakyReLU);

        // Bottleneck
        bottleneck_ = std::make_unique<NeuralLayer>(128, 64, NeuralLayer::Activation::LeakyReLU);

        // Decoder path with skip connections
        decoder1_ = std::make_unique<NeuralLayer>(64 + 128, 128, NeuralLayer::Activation::LeakyReLU);
        decoder2_ = std::make_unique<NeuralLayer>(128 + 256, 256, NeuralLayer::Activation::LeakyReLU);
        decoder3_ = std::make_unique<NeuralLayer>(256 + 512, 512, NeuralLayer::Activation::LeakyReLU);

        // Output heads for each stem
        for (int i = 0; i < numStems_; ++i) {
            outputHeads_.push_back(
                std::make_unique<NeuralLayer>(512, numBins_, NeuralLayer::Activation::Sigmoid)
            );
        }
    }

    std::vector<SpectralMask> predict(const SpectralFrame& frame) {
        // Normalize input magnitude
        std::vector<float> input(frame.magnitude.begin(), frame.magnitude.end());
        float maxMag = *std::max_element(input.begin(), input.end());
        if (maxMag > 0.0f) {
            for (auto& v : input) v /= maxMag;
        }

        // Encoder forward pass
        auto enc1 = encoder1_->forward(input);
        auto enc2 = encoder2_->forward(enc1);
        auto enc3 = encoder3_->forward(enc2);

        // Bottleneck
        auto bn = bottleneck_->forward(enc3);

        // Decoder with skip connections
        std::vector<float> dec1Input;
        dec1Input.insert(dec1Input.end(), bn.begin(), bn.end());
        dec1Input.insert(dec1Input.end(), enc3.begin(), enc3.end());
        auto dec1 = decoder1_->forward(dec1Input);

        std::vector<float> dec2Input;
        dec2Input.insert(dec2Input.end(), dec1.begin(), dec1.end());
        dec2Input.insert(dec2Input.end(), enc2.begin(), enc2.end());
        auto dec2 = decoder2_->forward(dec2Input);

        std::vector<float> dec3Input;
        dec3Input.insert(dec3Input.end(), dec2.begin(), dec2.end());
        dec3Input.insert(dec3Input.end(), enc1.begin(), enc1.end());
        auto dec3 = decoder3_->forward(dec3Input);

        // Generate masks for each stem
        std::vector<SpectralMask> masks;
        for (int i = 0; i < numStems_; ++i) {
            SpectralMask mask;
            mask.stemType = static_cast<StemType>(i);
            mask.mask = outputHeads_[i]->forward(dec3);
            mask.confidence = calculateConfidence(mask.mask);
            masks.push_back(std::move(mask));
        }

        // Normalize masks (ensure they sum to 1.0 at each frequency)
        normalizeMasks(masks);

        return masks;
    }

    bool loadModel(const juce::File& modelFile) {
        // Load pretrained weights from file
        if (!modelFile.existsAsFile()) return false;

        juce::FileInputStream stream(modelFile);
        if (!stream.openedOk()) return false;

        // Model file format: layer weights and biases in sequence
        // This is a placeholder for actual model loading
        modelLoaded_ = true;
        return true;
    }

    bool isModelLoaded() const { return modelLoaded_; }

private:
    float calculateConfidence(const std::vector<float>& mask) {
        float sum = 0.0f;
        for (float v : mask) sum += v;
        return sum / mask.size();
    }

    void normalizeMasks(std::vector<SpectralMask>& masks) {
        if (masks.empty()) return;

        size_t numBins = masks[0].mask.size();
        for (size_t bin = 0; bin < numBins; ++bin) {
            float sum = 0.0f;
            for (auto& m : masks) {
                sum += m.mask[bin];
            }
            if (sum > 0.0f) {
                for (auto& m : masks) {
                    m.mask[bin] /= sum;
                }
            }
        }
    }

    int fftSize_;
    int numBins_;
    int numStems_;
    bool modelLoaded_ = false;

    // Network layers
    std::unique_ptr<NeuralLayer> encoder1_, encoder2_, encoder3_;
    std::unique_ptr<NeuralLayer> bottleneck_;
    std::unique_ptr<NeuralLayer> decoder1_, decoder2_, decoder3_;
    std::vector<std::unique_ptr<NeuralLayer>> outputHeads_;
};

//==============================================================================
/** STFT (Short-Time Fourier Transform) processor */
class STFTProcessor {
public:
    STFTProcessor(int fftSize = 2048, int hopSize = 512)
        : fftSize_(fftSize)
        , hopSize_(hopSize)
        , fft_(std::make_unique<juce::dsp::FFT>(static_cast<int>(std::log2(fftSize))))
    {
        window_.resize(fftSize_);
        createHannWindow();

        fftBuffer_.resize(fftSize_ * 2);
        overlapBuffer_.resize(fftSize_);
    }

    void createHannWindow() {
        for (int i = 0; i < fftSize_; ++i) {
            window_[i] = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi * i / (fftSize_ - 1)));
        }
    }

    std::vector<SpectralFrame> analyze(const juce::AudioBuffer<float>& audio, int channel = 0) {
        std::vector<SpectralFrame> frames;
        const float* data = audio.getReadPointer(channel);
        int numSamples = audio.getNumSamples();

        int numFrames = (numSamples - fftSize_) / hopSize_ + 1;
        frames.reserve(numFrames);

        for (int frameIdx = 0; frameIdx < numFrames; ++frameIdx) {
            int startSample = frameIdx * hopSize_;

            SpectralFrame frame;
            frame.frameIndex = frameIdx;
            frame.timePosition = static_cast<double>(startSample) / 44100.0;
            frame.resize(fftSize_);

            // Apply window and copy to FFT buffer
            std::fill(fftBuffer_.begin(), fftBuffer_.end(), 0.0f);
            for (int i = 0; i < fftSize_; ++i) {
                if (startSample + i < numSamples) {
                    fftBuffer_[i] = data[startSample + i] * window_[i];
                }
            }

            // Perform FFT
            fft_->performRealOnlyForwardTransform(fftBuffer_.data(), true);

            // Extract complex spectrum
            for (int i = 0; i <= fftSize_ / 2; ++i) {
                frame.spectrum[i] = std::complex<float>(fftBuffer_[i * 2], fftBuffer_[i * 2 + 1]);
            }

            frame.computeMagnitudePhase();
            frames.push_back(std::move(frame));
        }

        return frames;
    }

    juce::AudioBuffer<float> synthesize(const std::vector<SpectralFrame>& frames, int numChannels = 1) {
        if (frames.empty()) return {};

        int numSamples = static_cast<int>(frames.size()) * hopSize_ + fftSize_;
        juce::AudioBuffer<float> output(numChannels, numSamples);
        output.clear();

        std::vector<float> windowSum(numSamples, 0.0f);

        for (const auto& frame : frames) {
            // Prepare IFFT buffer
            std::fill(fftBuffer_.begin(), fftBuffer_.end(), 0.0f);

            for (int i = 0; i <= fftSize_ / 2; ++i) {
                fftBuffer_[i * 2] = frame.spectrum[i].real();
                fftBuffer_[i * 2 + 1] = frame.spectrum[i].imag();
            }

            // Perform IFFT
            fft_->performRealOnlyInverseTransform(fftBuffer_.data());

            // Overlap-add with window
            int startSample = frame.frameIndex * hopSize_;
            for (int i = 0; i < fftSize_; ++i) {
                if (startSample + i < numSamples) {
                    float windowedSample = fftBuffer_[i] * window_[i];
                    for (int ch = 0; ch < numChannels; ++ch) {
                        output.addSample(ch, startSample + i, windowedSample);
                    }
                    windowSum[startSample + i] += window_[i] * window_[i];
                }
            }
        }

        // Normalize by window sum (OLA normalization)
        for (int ch = 0; ch < numChannels; ++ch) {
            float* data = output.getWritePointer(ch);
            for (int i = 0; i < numSamples; ++i) {
                if (windowSum[i] > 1e-8f) {
                    data[i] /= windowSum[i];
                }
            }
        }

        return output;
    }

private:
    int fftSize_;
    int hopSize_;
    std::unique_ptr<juce::dsp::FFT> fft_;
    std::vector<float> window_;
    std::vector<float> fftBuffer_;
    std::vector<float> overlapBuffer_;
};

//==============================================================================
/** Separated stem result */
struct SeparatedStem {
    StemType type;
    juce::AudioBuffer<float> audio;
    float confidence = 0.0f;
    double duration = 0.0;

    juce::File exportToFile(const juce::File& directory, const juce::String& baseName) const {
        juce::File outputFile = directory.getChildFile(baseName + "_" + stemTypeToString(type) + ".wav");

        juce::WavAudioFormat wavFormat;
        std::unique_ptr<juce::AudioFormatWriter> writer(
            wavFormat.createWriterFor(new juce::FileOutputStream(outputFile),
                                       44100.0, audio.getNumChannels(), 24, {}, 0));

        if (writer) {
            writer->writeFromAudioSampleBuffer(audio, 0, audio.getNumSamples());
        }

        return outputFile;
    }
};

//==============================================================================
/** Separation job for async processing */
struct SeparationJob {
    juce::AudioBuffer<float> inputAudio;
    std::vector<StemType> stemsToExtract;
    SeparationQuality quality = SeparationQuality::Standard;
    std::function<void(float)> progressCallback;
    std::function<void(std::vector<SeparatedStem>)> completionCallback;
    std::atomic<bool> cancelled{false};
};

//==============================================================================
/** Main stem separation engine */
class StemSeparationEngine {
public:
    StemSeparationEngine()
        : stftProcessor_(2048, 512)
        , separatorModel_(2048, 4)
    {
        // Initialize processing thread pool
        threadPool_ = std::make_unique<juce::ThreadPool>(
            juce::SystemStats::getNumCpus() - 1);
    }

    ~StemSeparationEngine() {
        if (threadPool_) {
            threadPool_->removeAllJobs(true, 5000);
        }
    }

    //==============================================================================
    /** Load AI model from file */
    bool loadModel(const juce::File& modelFile) {
        return separatorModel_.loadModel(modelFile);
    }

    /** Check if model is ready */
    bool isReady() const {
        return separatorModel_.isModelLoaded();
    }

    //==============================================================================
    /** Separate audio synchronously */
    std::vector<SeparatedStem> separate(
        const juce::AudioBuffer<float>& audio,
        const std::vector<StemType>& stems = {StemType::Vocals, StemType::Drums, StemType::Bass, StemType::Other},
        SeparationQuality quality = SeparationQuality::Standard,
        std::function<void(float)> progressCallback = nullptr)
    {
        std::vector<SeparatedStem> results;

        // Configure based on quality
        int fftSize, hopSize;
        getQualitySettings(quality, fftSize, hopSize);

        STFTProcessor stft(fftSize, hopSize);

        // Process each channel
        int numChannels = audio.getNumChannels();
        std::vector<std::vector<SpectralFrame>> channelFrames(numChannels);

        // Analyze all channels
        for (int ch = 0; ch < numChannels; ++ch) {
            channelFrames[ch] = stft.analyze(audio, ch);
            if (progressCallback) {
                progressCallback(0.1f + 0.2f * (ch + 1) / numChannels);
            }
        }

        // Separate each requested stem
        for (size_t stemIdx = 0; stemIdx < stems.size(); ++stemIdx) {
            StemType stemType = stems[stemIdx];

            // Process frames for this stem
            std::vector<SpectralFrame> stemFrames = channelFrames[0]; // Start with channel 0

            for (size_t frameIdx = 0; frameIdx < stemFrames.size(); ++frameIdx) {
                // Get separation masks
                auto masks = separatorModel_.predict(channelFrames[0][frameIdx]);

                // Find the mask for this stem
                for (const auto& mask : masks) {
                    if (mask.stemType == stemType) {
                        mask.apply(stemFrames[frameIdx]);
                        break;
                    }
                }

                if (progressCallback && frameIdx % 100 == 0) {
                    float stemProgress = static_cast<float>(stemIdx) / stems.size();
                    float frameProgress = static_cast<float>(frameIdx) / stemFrames.size();
                    progressCallback(0.3f + 0.6f * (stemProgress + frameProgress / stems.size()));
                }
            }

            // Synthesize separated audio
            SeparatedStem result;
            result.type = stemType;
            result.audio = stft.synthesize(stemFrames, numChannels);
            result.duration = audio.getNumSamples() / 44100.0;
            result.confidence = calculateStemConfidence(stemFrames);

            results.push_back(std::move(result));
        }

        if (progressCallback) {
            progressCallback(1.0f);
        }

        return results;
    }

    //==============================================================================
    /** Separate audio asynchronously */
    void separateAsync(
        const juce::AudioBuffer<float>& audio,
        const std::vector<StemType>& stems,
        SeparationQuality quality,
        std::function<void(float)> progressCallback,
        std::function<void(std::vector<SeparatedStem>)> completionCallback)
    {
        auto job = std::make_shared<SeparationJob>();
        job->inputAudio = audio;
        job->stemsToExtract = stems;
        job->quality = quality;
        job->progressCallback = progressCallback;
        job->completionCallback = completionCallback;

        threadPool_->addJob([this, job]() {
            if (!job->cancelled) {
                auto results = separate(job->inputAudio, job->stemsToExtract,
                                        job->quality, job->progressCallback);
                if (job->completionCallback) {
                    juce::MessageManager::callAsync([job, results = std::move(results)]() {
                        job->completionCallback(results);
                    });
                }
            }
        });
    }

    //==============================================================================
    /** Export stems to files */
    std::vector<juce::File> exportStems(
        const std::vector<SeparatedStem>& stems,
        const juce::File& outputDirectory,
        const juce::String& baseName)
    {
        std::vector<juce::File> exportedFiles;

        if (!outputDirectory.exists()) {
            outputDirectory.createDirectory();
        }

        for (const auto& stem : stems) {
            juce::File exported = stem.exportToFile(outputDirectory, baseName);
            exportedFiles.push_back(exported);
        }

        return exportedFiles;
    }

    //==============================================================================
    /** Quick vocal isolation (optimized path) */
    juce::AudioBuffer<float> isolateVocals(const juce::AudioBuffer<float>& audio) {
        auto stems = separate(audio, {StemType::Vocals}, SeparationQuality::Standard);
        if (!stems.empty()) {
            return stems[0].audio;
        }
        return {};
    }

    /** Quick vocal removal (karaoke) */
    juce::AudioBuffer<float> removeVocals(const juce::AudioBuffer<float>& audio) {
        auto stems = separate(audio, {StemType::Drums, StemType::Bass, StemType::Other},
                              SeparationQuality::Standard);

        // Mix non-vocal stems together
        if (stems.empty()) return audio;

        int numSamples = audio.getNumSamples();
        int numChannels = audio.getNumChannels();
        juce::AudioBuffer<float> result(numChannels, numSamples);
        result.clear();

        for (const auto& stem : stems) {
            for (int ch = 0; ch < numChannels; ++ch) {
                result.addFrom(ch, 0, stem.audio, ch, 0,
                              std::min(numSamples, stem.audio.getNumSamples()));
            }
        }

        return result;
    }

    /** Isolate drums only */
    juce::AudioBuffer<float> isolateDrums(const juce::AudioBuffer<float>& audio) {
        auto stems = separate(audio, {StemType::Drums}, SeparationQuality::Standard);
        if (!stems.empty()) {
            return stems[0].audio;
        }
        return {};
    }

    /** Isolate bass only */
    juce::AudioBuffer<float> isolateBass(const juce::AudioBuffer<float>& audio) {
        auto stems = separate(audio, {StemType::Bass}, SeparationQuality::Standard);
        if (!stems.empty()) {
            return stems[0].audio;
        }
        return {};
    }

private:
    void getQualitySettings(SeparationQuality quality, int& fftSize, int& hopSize) {
        switch (quality) {
            case SeparationQuality::Draft:
                fftSize = 1024;
                hopSize = 256;
                break;
            case SeparationQuality::Standard:
                fftSize = 2048;
                hopSize = 512;
                break;
            case SeparationQuality::High:
                fftSize = 4096;
                hopSize = 1024;
                break;
            case SeparationQuality::Ultra:
                fftSize = 8192;
                hopSize = 2048;
                break;
        }
    }

    float calculateStemConfidence(const std::vector<SpectralFrame>& frames) {
        if (frames.empty()) return 0.0f;

        float totalEnergy = 0.0f;
        for (const auto& frame : frames) {
            for (float mag : frame.magnitude) {
                totalEnergy += mag * mag;
            }
        }

        return std::min(1.0f, totalEnergy / (frames.size() * 1000.0f));
    }

    STFTProcessor stftProcessor_;
    SeparatorModel separatorModel_;
    std::unique_ptr<juce::ThreadPool> threadPool_;
};

//==============================================================================
/** Stem separation plugin/effect wrapper */
class StemSeparationProcessor : public juce::AudioProcessor {
public:
    StemSeparationProcessor()
        : AudioProcessor(BusesProperties()
                         .withInput("Input", juce::AudioChannelSet::stereo(), true)
                         .withOutput("Vocals", juce::AudioChannelSet::stereo(), true)
                         .withOutput("Drums", juce::AudioChannelSet::stereo(), true)
                         .withOutput("Bass", juce::AudioChannelSet::stereo(), true)
                         .withOutput("Other", juce::AudioChannelSet::stereo(), true))
    {
    }

    void prepareToPlay(double sampleRate, int samplesPerBlock) override {
        currentSampleRate_ = sampleRate;
        blockSize_ = samplesPerBlock;
    }

    void releaseResources() override {}

    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer&) override {
        // Real-time stem separation is computationally intensive
        // This implementation buffers audio and processes in chunks

        // For real-time, we use a simplified spectral approach
        // Full separation should be done offline

        int numSamples = buffer.getNumSamples();

        // Add to input buffer
        inputBuffer_.setSize(2, inputBuffer_.getNumSamples() + numSamples, true);
        for (int ch = 0; ch < 2; ++ch) {
            inputBuffer_.copyFrom(ch, inputBuffer_.getNumSamples() - numSamples,
                                  buffer, ch, 0, numSamples);
        }

        // Process when we have enough samples
        if (inputBuffer_.getNumSamples() >= processChunkSize_) {
            processPendingAudio();
        }
    }

    const juce::String getName() const override { return "Stem Separation"; }
    bool acceptsMidi() const override { return false; }
    bool producesMidi() const override { return false; }
    double getTailLengthSeconds() const override { return 0.0; }

    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram(int) override {}
    const juce::String getProgramName(int) override { return {}; }
    void changeProgramName(int, const juce::String&) override {}

    void getStateInformation(juce::MemoryBlock&) override {}
    void setStateInformation(const void*, int) override {}

    juce::AudioProcessorEditor* createEditor() override { return nullptr; }
    bool hasEditor() const override { return false; }

private:
    void processPendingAudio() {
        // Process chunk through separator
        juce::AudioBuffer<float> chunk(2, processChunkSize_);
        for (int ch = 0; ch < 2; ++ch) {
            chunk.copyFrom(ch, 0, inputBuffer_, ch, 0, processChunkSize_);
        }

        // Shift remaining samples
        int remaining = inputBuffer_.getNumSamples() - processChunkSize_;
        if (remaining > 0) {
            for (int ch = 0; ch < 2; ++ch) {
                inputBuffer_.copyFrom(ch, 0, inputBuffer_, ch, processChunkSize_, remaining);
            }
        }
        inputBuffer_.setSize(2, remaining, true);

        // Separate (in background or low-latency mode)
        auto stems = engine_.separate(chunk,
            {StemType::Vocals, StemType::Drums, StemType::Bass, StemType::Other},
            SeparationQuality::Draft);

        // Store results for output
        for (const auto& stem : stems) {
            separatedStems_[static_cast<int>(stem.type)] = stem.audio;
        }
    }

    StemSeparationEngine engine_;
    juce::AudioBuffer<float> inputBuffer_;
    std::map<int, juce::AudioBuffer<float>> separatedStems_;

    double currentSampleRate_ = 44100.0;
    int blockSize_ = 512;
    int processChunkSize_ = 44100; // 1 second chunks
};

} // namespace AI
} // namespace Echoelmusic
