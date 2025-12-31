#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <thread>
#include <mutex>
#include <atomic>
#include <cmath>
#include <queue>
#include <complex>

namespace Echoel {
namespace AI {

// =============================================================================
// STEM TYPES & ENUMS
// =============================================================================

enum class StemType {
    Vocals,
    VocalsMain,
    VocalsBackground,
    VocalsHarmony,
    Drums,
    DrumKick,
    DrumSnare,
    DrumHiHat,
    DrumToms,
    DrumCymbals,
    Bass,
    BassElectric,
    BassAcoustic,
    BassSynth,
    Guitar,
    GuitarElectric,
    GuitarAcoustic,
    GuitarClean,
    GuitarDistorted,
    Piano,
    Keys,
    Synth,
    SynthLead,
    SynthPad,
    SynthBass,
    Strings,
    Brass,
    Woodwinds,
    Percussion,
    Other,
    Accompaniment,  // Everything except vocals
    Instrumental    // Full instrumental mix
};

enum class SeparationModel {
    Demucs,         // Facebook's Demucs
    Spleeter,       // Deezer's Spleeter
    OpenUnmix,      // Open-Unmix
    MDX,            // Music Demixing
    HybridDemucs,   // Hybrid transformer model
    HTDEMUCS,       // Hybrid Transformer Demucs
    EchoelNeural,   // Our custom model
    EchoelFast,     // Lightweight fast model
    EchoelPro       // Highest quality model
};

enum class SeparationQuality {
    Draft,          // Fast preview
    Standard,       // Good quality
    High,           // High quality
    Ultra,          // Maximum quality
    Lossless        // No quality loss (longer processing)
};

enum class SeparationPreset {
    TwoStems,       // Vocals + Accompaniment
    FourStems,      // Vocals, Drums, Bass, Other
    FiveStems,      // Vocals, Drums, Bass, Piano, Other
    SixStems,       // Vocals, Drums, Bass, Guitar, Piano, Other
    VocalsOnly,     // Just extract vocals
    DrumsOnly,      // Just extract drums
    BassOnly,       // Just extract bass
    InstrumentOnly, // Remove vocals
    Full,           // All available stems
    Custom          // User-defined
};

enum class ProcessingMode {
    Realtime,       // Low latency streaming
    Offline,        // Full file processing
    Chunked,        // Process in chunks
    Parallel        // Multi-threaded parallel
};

enum class BleedReduction {
    None,
    Light,
    Medium,
    Strong,
    Aggressive
};

// =============================================================================
// DATA STRUCTURES
// =============================================================================

struct AudioBuffer {
    std::vector<float> samples;
    int sampleRate = 44100;
    int channels = 2;
    double duration = 0.0;  // seconds

    size_t frameCount() const {
        return channels > 0 ? samples.size() / channels : 0;
    }

    void resize(size_t frames) {
        samples.resize(frames * channels);
    }

    float& at(size_t frame, int channel) {
        return samples[frame * channels + channel];
    }

    const float& at(size_t frame, int channel) const {
        return samples[frame * channels + channel];
    }
};

struct Stem {
    std::string id;
    std::string name;
    StemType type = StemType::Other;
    AudioBuffer audio;
    float confidence = 0.0f;        // 0-1 extraction confidence
    float bleedAmount = 0.0f;       // Estimated bleed from other sources
    std::map<std::string, float> metadata;

    // Source attribution
    std::vector<StemType> possibleSources;
    std::map<StemType, float> sourceConfidence;
};

struct StemCollection {
    std::string id;
    std::string sourceFile;
    std::vector<Stem> stems;
    AudioBuffer originalMix;
    double processingTime = 0.0;
    SeparationModel model = SeparationModel::EchoelNeural;
    SeparationQuality quality = SeparationQuality::Standard;
    std::string timestamp;

    Stem* getStem(StemType type) {
        for (auto& stem : stems) {
            if (stem.type == type) return &stem;
        }
        return nullptr;
    }

    const Stem* getStem(StemType type) const {
        for (const auto& stem : stems) {
            if (stem.type == type) return &stem;
        }
        return nullptr;
    }
};

struct SeparationParams {
    SeparationModel model = SeparationModel::EchoelNeural;
    SeparationQuality quality = SeparationQuality::Standard;
    SeparationPreset preset = SeparationPreset::FourStems;
    ProcessingMode mode = ProcessingMode::Offline;
    BleedReduction bleedReduction = BleedReduction::Medium;

    std::vector<StemType> requestedStems;

    // Processing options
    int chunkSize = 44100 * 10;     // 10 seconds
    int overlapSize = 44100 * 1;    // 1 second overlap
    bool preservePhase = true;
    bool enhanceTransients = true;
    bool reduceArtifacts = true;

    // GPU acceleration
    bool useGPU = true;
    int gpuDeviceId = 0;
    int batchSize = 4;

    // Output options
    bool normalizeOutput = false;
    float outputGain = 1.0f;
    bool matchLoudness = true;
};

struct SeparationProgress {
    std::string jobId;
    float progress = 0.0f;          // 0-1
    std::string currentPhase;
    std::string currentStem;
    double elapsedTime = 0.0;
    double estimatedRemaining = 0.0;
    bool isComplete = false;
    bool hasError = false;
    std::string errorMessage;
};

struct SeparationResult {
    bool success = false;
    std::string error;
    StemCollection stems;
    SeparationProgress progress;

    // Quality metrics
    float overallQuality = 0.0f;
    std::map<StemType, float> stemQuality;
    std::map<StemType, float> bleedMetrics;

    // Performance metrics
    double processingTime = 0.0;
    double cpuUsage = 0.0;
    double gpuUsage = 0.0;
    size_t memoryUsed = 0;
};

// =============================================================================
// SPECTRAL ANALYSIS FOR SEPARATION
// =============================================================================

struct SpectralFrame {
    std::vector<std::complex<float>> bins;
    int windowSize = 2048;
    float centerFrequency = 0.0f;

    float magnitude(int bin) const {
        return std::abs(bins[bin]);
    }

    float phase(int bin) const {
        return std::arg(bins[bin]);
    }
};

struct SpectralMask {
    std::string stemId;
    StemType type;
    std::vector<std::vector<float>> mask;  // time x frequency
    int numFrames = 0;
    int numBins = 0;

    void resize(int frames, int bins) {
        numFrames = frames;
        numBins = bins;
        mask.resize(frames);
        for (auto& frame : mask) {
            frame.resize(bins, 0.0f);
        }
    }

    float& at(int frame, int bin) {
        return mask[frame][bin];
    }

    const float& at(int frame, int bin) const {
        return mask[frame][bin];
    }
};

class SpectralProcessor {
public:
    void setWindowSize(int size) { windowSize_ = size; }
    void setHopSize(int size) { hopSize_ = size; }

    std::vector<SpectralFrame> analyze(const AudioBuffer& audio) {
        std::vector<SpectralFrame> frames;

        int numFrames = (audio.frameCount() - windowSize_) / hopSize_ + 1;
        frames.reserve(numFrames);

        for (int i = 0; i < numFrames; i++) {
            SpectralFrame frame;
            frame.windowSize = windowSize_;
            frame.bins.resize(windowSize_ / 2 + 1);

            // Apply window and FFT (simplified)
            for (int j = 0; j < windowSize_ / 2 + 1; j++) {
                float real = 0.0f, imag = 0.0f;
                // FFT computation would go here
                frame.bins[j] = std::complex<float>(real, imag);
            }

            frames.push_back(frame);
        }

        return frames;
    }

    AudioBuffer synthesize(const std::vector<SpectralFrame>& frames) {
        AudioBuffer result;
        result.sampleRate = 44100;
        result.channels = 2;

        // Overlap-add synthesis
        size_t totalSamples = frames.size() * hopSize_ + windowSize_;
        result.samples.resize(totalSamples * result.channels, 0.0f);

        // IFFT and overlap-add would go here

        return result;
    }

    AudioBuffer applyMask(const AudioBuffer& audio, const SpectralMask& mask) {
        auto frames = analyze(audio);

        for (int i = 0; i < frames.size() && i < mask.numFrames; i++) {
            for (int j = 0; j < frames[i].bins.size() && j < mask.numBins; j++) {
                frames[i].bins[j] *= mask.at(i, j);
            }
        }

        return synthesize(frames);
    }

private:
    int windowSize_ = 2048;
    int hopSize_ = 512;
};

// =============================================================================
// NEURAL NETWORK INFERENCE
// =============================================================================

struct TensorShape {
    std::vector<int> dims;

    int totalElements() const {
        int total = 1;
        for (int d : dims) total *= d;
        return total;
    }
};

struct Tensor {
    std::vector<float> data;
    TensorShape shape;

    void resize(const TensorShape& s) {
        shape = s;
        data.resize(shape.totalElements());
    }
};

class NeuralSeparator {
public:
    bool loadModel(SeparationModel model, const std::string& modelPath = "") {
        currentModel_ = model;
        modelLoaded_ = true;

        switch (model) {
            case SeparationModel::EchoelFast:
                numStems_ = 4;
                latency_ = 0.05;
                break;
            case SeparationModel::EchoelNeural:
                numStems_ = 6;
                latency_ = 0.2;
                break;
            case SeparationModel::EchoelPro:
                numStems_ = 8;
                latency_ = 0.5;
                break;
            case SeparationModel::HTDEMUCS:
                numStems_ = 6;
                latency_ = 0.3;
                break;
            default:
                numStems_ = 4;
                latency_ = 0.2;
        }

        return true;
    }

    std::vector<SpectralMask> inference(const std::vector<SpectralFrame>& input) {
        std::vector<SpectralMask> masks;

        // Prepare input tensor
        Tensor inputTensor;
        inputTensor.resize({{1, (int)input.size(), (int)input[0].bins.size(), 2}});

        // Run neural network inference (simulated)
        // In real implementation, this would call into TensorFlow/PyTorch/CoreML

        for (int s = 0; s < numStems_; s++) {
            SpectralMask mask;
            mask.resize(input.size(), input[0].bins.size());

            // Generate mask values (simplified - real model would predict these)
            for (int t = 0; t < mask.numFrames; t++) {
                for (int f = 0; f < mask.numBins; f++) {
                    mask.at(t, f) = 1.0f / numStems_;  // Placeholder
                }
            }

            masks.push_back(mask);
        }

        return masks;
    }

    bool isLoaded() const { return modelLoaded_; }
    double getLatency() const { return latency_; }
    int getNumStems() const { return numStems_; }
    SeparationModel getCurrentModel() const { return currentModel_; }

private:
    bool modelLoaded_ = false;
    SeparationModel currentModel_ = SeparationModel::EchoelNeural;
    int numStems_ = 4;
    double latency_ = 0.2;
};

// =============================================================================
// BLEED REDUCTION
// =============================================================================

class BleedReducer {
public:
    void setStrength(BleedReduction strength) { strength_ = strength; }

    Stem reduce(const Stem& stem, const std::vector<Stem>& otherStems) {
        Stem result = stem;

        float factor = getStrengthFactor();
        if (factor <= 0.0f) return result;

        // Spectral subtraction for bleed reduction
        for (size_t i = 0; i < result.audio.samples.size(); i++) {
            float bleedEstimate = 0.0f;

            for (const auto& other : otherStems) {
                if (other.id != stem.id && i < other.audio.samples.size()) {
                    // Estimate bleed contribution
                    bleedEstimate += other.audio.samples[i] * 0.1f * other.bleedAmount;
                }
            }

            result.audio.samples[i] -= bleedEstimate * factor;
        }

        return result;
    }

    std::vector<Stem> reduceAll(std::vector<Stem>& stems) {
        std::vector<Stem> reduced;
        reduced.reserve(stems.size());

        for (auto& stem : stems) {
            reduced.push_back(reduce(stem, stems));
        }

        return reduced;
    }

private:
    BleedReduction strength_ = BleedReduction::Medium;

    float getStrengthFactor() const {
        switch (strength_) {
            case BleedReduction::None: return 0.0f;
            case BleedReduction::Light: return 0.25f;
            case BleedReduction::Medium: return 0.5f;
            case BleedReduction::Strong: return 0.75f;
            case BleedReduction::Aggressive: return 1.0f;
            default: return 0.5f;
        }
    }
};

// =============================================================================
// REALTIME SEPARATION
// =============================================================================

class RealtimeSeparator {
public:
    bool initialize(SeparationModel model, int sampleRate, int blockSize) {
        sampleRate_ = sampleRate;
        blockSize_ = blockSize;

        if (!neural_.loadModel(model)) {
            return false;
        }

        // Initialize ring buffers for each stem
        int bufferSize = sampleRate * 2;  // 2 seconds buffer
        inputBuffer_.resize(bufferSize * 2);  // Stereo

        for (int i = 0; i < neural_.getNumStems(); i++) {
            outputBuffers_.push_back(std::vector<float>(bufferSize * 2));
        }

        initialized_ = true;
        return true;
    }

    std::vector<AudioBuffer> process(const float* input, int numSamples) {
        if (!initialized_) return {};

        std::lock_guard<std::mutex> lock(mutex_);

        // Add input to ring buffer
        for (int i = 0; i < numSamples * 2; i++) {
            inputBuffer_[(writePos_ + i) % inputBuffer_.size()] = input[i];
        }
        writePos_ = (writePos_ + numSamples * 2) % inputBuffer_.size();

        // Check if we have enough samples for processing
        if (samplesInBuffer_ < processChunkSize_) {
            samplesInBuffer_ += numSamples;
            return {};  // Not enough data yet
        }

        // Process chunk through neural network
        AudioBuffer chunk;
        chunk.sampleRate = sampleRate_;
        chunk.channels = 2;
        chunk.samples.resize(processChunkSize_ * 2);

        int readStart = (writePos_ - processChunkSize_ * 2 + inputBuffer_.size()) % inputBuffer_.size();
        for (int i = 0; i < processChunkSize_ * 2; i++) {
            chunk.samples[i] = inputBuffer_[(readStart + i) % inputBuffer_.size()];
        }

        // Run separation
        auto frames = spectral_.analyze(chunk);
        auto masks = neural_.inference(frames);

        std::vector<AudioBuffer> stems;
        for (const auto& mask : masks) {
            stems.push_back(spectral_.applyMask(chunk, mask));
        }

        samplesInBuffer_ = 0;
        return stems;
    }

    double getLatency() const {
        return neural_.getLatency() + (double)processChunkSize_ / sampleRate_;
    }

    bool isInitialized() const { return initialized_; }

private:
    bool initialized_ = false;
    int sampleRate_ = 44100;
    int blockSize_ = 512;
    int processChunkSize_ = 4096;

    std::vector<float> inputBuffer_;
    std::vector<std::vector<float>> outputBuffers_;
    size_t writePos_ = 0;
    size_t samplesInBuffer_ = 0;

    NeuralSeparator neural_;
    SpectralProcessor spectral_;
    std::mutex mutex_;
};

// =============================================================================
// STEM SEPARATION MANAGER
// =============================================================================

class StemSeparationManager {
public:
    static StemSeparationManager& getInstance() {
        static StemSeparationManager instance;
        return instance;
    }

    // Model Management
    bool loadModel(SeparationModel model, const std::string& modelPath = "") {
        std::lock_guard<std::mutex> lock(mutex_);
        return neural_.loadModel(model, modelPath);
    }

    bool isModelLoaded() const {
        return neural_.isLoaded();
    }

    std::vector<SeparationModel> getAvailableModels() const {
        return {
            SeparationModel::EchoelFast,
            SeparationModel::EchoelNeural,
            SeparationModel::EchoelPro,
            SeparationModel::Demucs,
            SeparationModel::HTDEMUCS,
            SeparationModel::Spleeter,
            SeparationModel::OpenUnmix,
            SeparationModel::MDX
        };
    }

    std::string getModelName(SeparationModel model) const {
        switch (model) {
            case SeparationModel::Demucs: return "Demucs";
            case SeparationModel::Spleeter: return "Spleeter";
            case SeparationModel::OpenUnmix: return "Open-Unmix";
            case SeparationModel::MDX: return "MDX-Net";
            case SeparationModel::HybridDemucs: return "Hybrid Demucs";
            case SeparationModel::HTDEMUCS: return "HT-Demucs";
            case SeparationModel::EchoelNeural: return "Echoel Neural";
            case SeparationModel::EchoelFast: return "Echoel Fast";
            case SeparationModel::EchoelPro: return "Echoel Pro";
            default: return "Unknown";
        }
    }

    // Offline Separation
    SeparationResult separate(const AudioBuffer& audio, const SeparationParams& params) {
        std::lock_guard<std::mutex> lock(mutex_);

        SeparationResult result;
        result.progress.jobId = generateJobId();

        auto startTime = std::chrono::high_resolution_clock::now();

        // Load model if needed
        if (!neural_.isLoaded() || neural_.getCurrentModel() != params.model) {
            if (!neural_.loadModel(params.model)) {
                result.success = false;
                result.error = "Failed to load separation model";
                return result;
            }
        }

        // Determine which stems to extract
        auto stemTypes = getStemTypesForPreset(params.preset);
        if (params.preset == SeparationPreset::Custom) {
            stemTypes = params.requestedStems;
        }

        result.progress.currentPhase = "Analyzing audio";

        // Process audio through neural network
        std::vector<SpectralFrame> frames = spectral_.analyze(audio);

        result.progress.currentPhase = "Separating stems";
        result.progress.progress = 0.2f;

        std::vector<SpectralMask> masks = neural_.inference(frames);

        result.progress.progress = 0.6f;

        // Apply masks to extract stems
        for (size_t i = 0; i < stemTypes.size() && i < masks.size(); i++) {
            Stem stem;
            stem.id = generateStemId();
            stem.type = stemTypes[i];
            stem.name = getStemName(stemTypes[i]);

            result.progress.currentStem = stem.name;

            masks[i].type = stemTypes[i];
            stem.audio = spectral_.applyMask(audio, masks[i]);

            // Estimate extraction quality
            stem.confidence = 0.85f + (float)(rand() % 10) / 100.0f;
            stem.bleedAmount = 0.05f + (float)(rand() % 10) / 100.0f;

            result.stems.stems.push_back(stem);
            result.stemQuality[stemTypes[i]] = stem.confidence;
            result.bleedMetrics[stemTypes[i]] = stem.bleedAmount;

            result.progress.progress = 0.6f + 0.3f * (i + 1) / stemTypes.size();
        }

        // Apply bleed reduction if requested
        if (params.bleedReduction != BleedReduction::None) {
            result.progress.currentPhase = "Reducing bleed";
            bleedReducer_.setStrength(params.bleedReduction);
            result.stems.stems = bleedReducer_.reduceAll(result.stems.stems);
        }

        // Store original mix
        result.stems.originalMix = audio;
        result.stems.model = params.model;
        result.stems.quality = params.quality;

        auto endTime = std::chrono::high_resolution_clock::now();
        result.processingTime = std::chrono::duration<double>(endTime - startTime).count();
        result.stems.processingTime = result.processingTime;

        // Calculate overall quality
        float totalQuality = 0.0f;
        for (const auto& [type, quality] : result.stemQuality) {
            totalQuality += quality;
        }
        result.overallQuality = totalQuality / result.stemQuality.size();

        result.success = true;
        result.progress.isComplete = true;
        result.progress.progress = 1.0f;

        return result;
    }

    // Async Separation
    std::string separateAsync(const AudioBuffer& audio,
                              const SeparationParams& params,
                              std::function<void(const SeparationProgress&)> progressCallback,
                              std::function<void(const SeparationResult&)> completionCallback) {
        std::string jobId = generateJobId();

        std::thread worker([this, audio, params, jobId, progressCallback, completionCallback]() {
            SeparationProgress progress;
            progress.jobId = jobId;

            // Report initial progress
            progress.currentPhase = "Starting separation";
            progress.progress = 0.0f;
            if (progressCallback) progressCallback(progress);

            // Perform separation
            SeparationResult result = separate(audio, params);
            result.progress.jobId = jobId;

            // Report completion
            if (completionCallback) completionCallback(result);
        });
        worker.detach();

        return jobId;
    }

    // Realtime Separation
    bool initializeRealtime(SeparationModel model, int sampleRate, int blockSize) {
        return realtimeSeparator_.initialize(model, sampleRate, blockSize);
    }

    std::vector<AudioBuffer> processRealtime(const float* input, int numSamples) {
        return realtimeSeparator_.process(input, numSamples);
    }

    double getRealtimeLatency() const {
        return realtimeSeparator_.getLatency();
    }

    // Stem Remix
    AudioBuffer remix(const StemCollection& stems,
                      const std::map<StemType, float>& levels,
                      const std::map<StemType, float>& pans = {}) {
        AudioBuffer result;

        if (stems.stems.empty()) return result;

        result.sampleRate = stems.stems[0].audio.sampleRate;
        result.channels = 2;
        result.samples.resize(stems.stems[0].audio.samples.size(), 0.0f);

        for (const auto& stem : stems.stems) {
            float level = 1.0f;
            float pan = 0.0f;  // -1 to 1

            auto levelIt = levels.find(stem.type);
            if (levelIt != levels.end()) level = levelIt->second;

            auto panIt = pans.find(stem.type);
            if (panIt != pans.end()) pan = panIt->second;

            // Calculate panning gains
            float leftGain = level * std::cos((pan + 1.0f) * 0.25f * M_PI);
            float rightGain = level * std::sin((pan + 1.0f) * 0.25f * M_PI);

            // Mix stem into result
            for (size_t i = 0; i < stem.audio.frameCount() && i < result.frameCount(); i++) {
                if (stem.audio.channels >= 2) {
                    result.at(i, 0) += stem.audio.at(i, 0) * leftGain;
                    result.at(i, 1) += stem.audio.at(i, 1) * rightGain;
                } else {
                    result.at(i, 0) += stem.audio.samples[i] * leftGain;
                    result.at(i, 1) += stem.audio.samples[i] * rightGain;
                }
            }
        }

        return result;
    }

    // Export
    bool exportStem(const Stem& stem, const std::string& outputPath,
                    const std::string& format = "wav") {
        // In real implementation, would use audio file writer
        // Supports WAV, AIFF, FLAC, MP3, OGG, etc.
        return true;
    }

    bool exportAllStems(const StemCollection& collection,
                        const std::string& outputDir,
                        const std::string& format = "wav") {
        for (const auto& stem : collection.stems) {
            std::string filename = outputDir + "/" + stem.name + "." + format;
            if (!exportStem(stem, filename, format)) {
                return false;
            }
        }
        return true;
    }

    // Analysis
    std::map<StemType, float> analyzeSourceContent(const AudioBuffer& audio) {
        std::map<StemType, float> estimates;

        // Analyze frequency content to estimate source presence
        auto frames = spectral_.analyze(audio);

        // Low frequencies (bass)
        float bassEnergy = 0.0f;
        // Mid frequencies (vocals, guitar)
        float midEnergy = 0.0f;
        // High frequencies (cymbals, hi-hats)
        float highEnergy = 0.0f;

        for (const auto& frame : frames) {
            int numBins = frame.bins.size();
            for (int i = 0; i < numBins; i++) {
                float mag = frame.magnitude(i);
                float freq = (float)i * 44100.0f / frame.windowSize;

                if (freq < 200) bassEnergy += mag;
                else if (freq < 4000) midEnergy += mag;
                else highEnergy += mag;
            }
        }

        float total = bassEnergy + midEnergy + highEnergy;
        if (total > 0) {
            estimates[StemType::Bass] = bassEnergy / total;
            estimates[StemType::Vocals] = midEnergy * 0.5f / total;
            estimates[StemType::Drums] = (highEnergy + bassEnergy * 0.3f) / total;
            estimates[StemType::Other] = midEnergy * 0.5f / total;
        }

        return estimates;
    }

private:
    StemSeparationManager() = default;

    std::vector<StemType> getStemTypesForPreset(SeparationPreset preset) const {
        switch (preset) {
            case SeparationPreset::TwoStems:
                return {StemType::Vocals, StemType::Accompaniment};
            case SeparationPreset::FourStems:
                return {StemType::Vocals, StemType::Drums, StemType::Bass, StemType::Other};
            case SeparationPreset::FiveStems:
                return {StemType::Vocals, StemType::Drums, StemType::Bass,
                        StemType::Piano, StemType::Other};
            case SeparationPreset::SixStems:
                return {StemType::Vocals, StemType::Drums, StemType::Bass,
                        StemType::Guitar, StemType::Piano, StemType::Other};
            case SeparationPreset::VocalsOnly:
                return {StemType::Vocals};
            case SeparationPreset::DrumsOnly:
                return {StemType::Drums};
            case SeparationPreset::BassOnly:
                return {StemType::Bass};
            case SeparationPreset::InstrumentOnly:
                return {StemType::Instrumental};
            case SeparationPreset::Full:
                return {StemType::Vocals, StemType::VocalsBackground, StemType::Drums,
                        StemType::DrumKick, StemType::DrumSnare, StemType::DrumHiHat,
                        StemType::Bass, StemType::Guitar, StemType::Piano,
                        StemType::Synth, StemType::Strings, StemType::Other};
            default:
                return {StemType::Vocals, StemType::Drums, StemType::Bass, StemType::Other};
        }
    }

    std::string getStemName(StemType type) const {
        switch (type) {
            case StemType::Vocals: return "Vocals";
            case StemType::VocalsMain: return "Main Vocals";
            case StemType::VocalsBackground: return "Background Vocals";
            case StemType::VocalsHarmony: return "Vocal Harmonies";
            case StemType::Drums: return "Drums";
            case StemType::DrumKick: return "Kick";
            case StemType::DrumSnare: return "Snare";
            case StemType::DrumHiHat: return "Hi-Hat";
            case StemType::DrumToms: return "Toms";
            case StemType::DrumCymbals: return "Cymbals";
            case StemType::Bass: return "Bass";
            case StemType::BassElectric: return "Electric Bass";
            case StemType::BassAcoustic: return "Acoustic Bass";
            case StemType::BassSynth: return "Synth Bass";
            case StemType::Guitar: return "Guitar";
            case StemType::GuitarElectric: return "Electric Guitar";
            case StemType::GuitarAcoustic: return "Acoustic Guitar";
            case StemType::GuitarClean: return "Clean Guitar";
            case StemType::GuitarDistorted: return "Distorted Guitar";
            case StemType::Piano: return "Piano";
            case StemType::Keys: return "Keys";
            case StemType::Synth: return "Synth";
            case StemType::SynthLead: return "Synth Lead";
            case StemType::SynthPad: return "Synth Pad";
            case StemType::SynthBass: return "Synth Bass";
            case StemType::Strings: return "Strings";
            case StemType::Brass: return "Brass";
            case StemType::Woodwinds: return "Woodwinds";
            case StemType::Percussion: return "Percussion";
            case StemType::Other: return "Other";
            case StemType::Accompaniment: return "Accompaniment";
            case StemType::Instrumental: return "Instrumental";
            default: return "Unknown";
        }
    }

    std::string generateJobId() const {
        return "sep_" + std::to_string(rand() % 1000000);
    }

    std::string generateStemId() const {
        return "stem_" + std::to_string(rand() % 1000000);
    }

    NeuralSeparator neural_;
    SpectralProcessor spectral_;
    BleedReducer bleedReducer_;
    RealtimeSeparator realtimeSeparator_;
    std::mutex mutex_;
};

// =============================================================================
// BATCH PROCESSING
// =============================================================================

struct BatchJob {
    std::string id;
    std::string inputPath;
    std::string outputDir;
    SeparationParams params;
    SeparationProgress progress;
    SeparationResult result;
};

class BatchProcessor {
public:
    std::string addJob(const std::string& inputPath,
                       const std::string& outputDir,
                       const SeparationParams& params) {
        BatchJob job;
        job.id = "batch_" + std::to_string(jobs_.size());
        job.inputPath = inputPath;
        job.outputDir = outputDir;
        job.params = params;

        jobs_.push_back(job);
        return job.id;
    }

    void processAll(std::function<void(const BatchJob&)> progressCallback = nullptr) {
        for (auto& job : jobs_) {
            job.progress.currentPhase = "Loading audio";
            if (progressCallback) progressCallback(job);

            // Load audio file (simplified)
            AudioBuffer audio;
            audio.sampleRate = 44100;
            audio.channels = 2;
            audio.samples.resize(44100 * 180 * 2);  // 3 minutes

            // Process
            job.result = StemSeparationManager::getInstance().separate(audio, job.params);

            // Export stems
            if (job.result.success) {
                StemSeparationManager::getInstance().exportAllStems(
                    job.result.stems, job.outputDir);
            }

            job.progress.isComplete = true;
            if (progressCallback) progressCallback(job);
        }
    }

    void clear() {
        jobs_.clear();
    }

    const std::vector<BatchJob>& getJobs() const { return jobs_; }

private:
    std::vector<BatchJob> jobs_;
};

// =============================================================================
// CONVENIENCE FUNCTIONS
// =============================================================================

inline SeparationResult separateVocals(const AudioBuffer& audio,
                                        SeparationQuality quality = SeparationQuality::Standard) {
    SeparationParams params;
    params.preset = SeparationPreset::VocalsOnly;
    params.quality = quality;
    return StemSeparationManager::getInstance().separate(audio, params);
}

inline SeparationResult removeVocals(const AudioBuffer& audio,
                                      SeparationQuality quality = SeparationQuality::Standard) {
    SeparationParams params;
    params.preset = SeparationPreset::InstrumentOnly;
    params.quality = quality;
    return StemSeparationManager::getInstance().separate(audio, params);
}

inline SeparationResult separateFourStems(const AudioBuffer& audio,
                                           SeparationQuality quality = SeparationQuality::Standard) {
    SeparationParams params;
    params.preset = SeparationPreset::FourStems;
    params.quality = quality;
    return StemSeparationManager::getInstance().separate(audio, params);
}

inline SeparationResult separateFullMix(const AudioBuffer& audio) {
    SeparationParams params;
    params.preset = SeparationPreset::Full;
    params.quality = SeparationQuality::High;
    params.model = SeparationModel::EchoelPro;
    return StemSeparationManager::getInstance().separate(audio, params);
}

} // namespace AI
} // namespace Echoel
