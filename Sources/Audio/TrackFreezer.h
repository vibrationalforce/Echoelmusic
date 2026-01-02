/*
  ==============================================================================

    TrackFreezer.h
    Created: 2026
    Author:  Echoelmusic

    Track Freeze and Bounce System for CPU Optimization
    Renders track audio to disk and replaces with playback of rendered file

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <map>
#include <functional>
#include <thread>
#include <atomic>
#include <mutex>

namespace Echoelmusic {
namespace Audio {

//==============================================================================
/** Freeze mode options */
enum class FreezeMode {
    PreFader,       // Freeze before fader/pan
    PostFader,      // Freeze after fader/pan
    PreFX,          // Freeze source only (no effects)
    PostFX,         // Freeze with all effects
    SelectedFX      // Freeze with selected effects only
};

/** Bounce options */
enum class BounceMode {
    InPlace,        // Replace original track
    NewTrack,       // Create new track with bounced audio
    Export,         // Export to file only
    Stem            // Export as stem file
};

/** Render quality */
enum class RenderQuality {
    Draft,          // 16-bit, fast rendering
    Standard,       // 24-bit, normal quality
    High,           // 32-bit float, high quality
    Master          // 32-bit float, with dithering
};

//==============================================================================
/** Freeze state for a track */
struct FreezeState {
    bool isFrozen = false;
    FreezeMode mode = FreezeMode::PostFX;
    juce::File frozenFile;
    juce::Time freezeTime;
    double startTime = 0.0;
    double endTime = 0.0;
    int64_t originalHash = 0;  // For detecting if source changed

    bool needsRefreeze() const {
        // Check if source has changed since freeze
        return false;  // Implement hash comparison
    }
};

//==============================================================================
/** Render settings */
struct RenderSettings {
    double sampleRate = 44100.0;
    int bitDepth = 24;
    int numChannels = 2;
    RenderQuality quality = RenderQuality::Standard;
    bool normalize = false;
    float normalizeLevel = 0.0f;  // dB
    bool addDither = false;
    bool realtime = false;  // Real-time render (slower but accurate for time-based effects)
    double tailLength = 2.0;  // Seconds of tail for reverb/delay
    int blockSize = 512;

    int getBitDepth() const {
        switch (quality) {
            case RenderQuality::Draft:   return 16;
            case RenderQuality::Standard: return 24;
            case RenderQuality::High:
            case RenderQuality::Master:  return 32;
            default:                     return 24;
        }
    }
};

//==============================================================================
/** Render progress info */
struct RenderProgress {
    double progress = 0.0;      // 0.0 - 1.0
    double elapsedTime = 0.0;   // Seconds
    double estimatedRemaining = 0.0;
    juce::String currentStage;
    bool isComplete = false;
    bool hasError = false;
    juce::String errorMessage;
};

//==============================================================================
/** Audio render source interface */
class RenderSource {
public:
    virtual ~RenderSource() = default;

    virtual void prepareToRender(double sampleRate, int blockSize) = 0;
    virtual void renderBlock(juce::AudioBuffer<float>& buffer, int numSamples) = 0;
    virtual void releaseRender() = 0;
    virtual int getNumChannels() const = 0;
    virtual double getLength() const = 0;  // In seconds
    virtual juce::String getName() const = 0;
};

//==============================================================================
/** Track render source wrapper */
class TrackRenderSource : public RenderSource {
public:
    TrackRenderSource(const juce::String& trackId)
        : trackId_(trackId)
    {
    }

    void setAudioCallback(std::function<void(juce::AudioBuffer<float>&, int)> callback) {
        renderCallback_ = callback;
    }

    void setLength(double lengthSeconds) { length_ = lengthSeconds; }
    void setNumChannels(int channels) { numChannels_ = channels; }

    void prepareToRender(double sampleRate, int blockSize) override {
        sampleRate_ = sampleRate;
        blockSize_ = blockSize;
        currentPosition_ = 0;
    }

    void renderBlock(juce::AudioBuffer<float>& buffer, int numSamples) override {
        if (renderCallback_) {
            renderCallback_(buffer, numSamples);
        }
        currentPosition_ += numSamples;
    }

    void releaseRender() override {
        currentPosition_ = 0;
    }

    int getNumChannels() const override { return numChannels_; }
    double getLength() const override { return length_; }
    juce::String getName() const override { return trackId_; }

private:
    juce::String trackId_;
    std::function<void(juce::AudioBuffer<float>&, int)> renderCallback_;
    double sampleRate_ = 44100.0;
    int blockSize_ = 512;
    int numChannels_ = 2;
    double length_ = 0.0;
    int64_t currentPosition_ = 0;
};

//==============================================================================
/** Dither processor for final output */
class DitherProcessor {
public:
    enum class DitherType {
        None,
        Rectangular,
        Triangular,
        ShapedNoise
    };

    DitherProcessor(DitherType type = DitherType::Triangular, int targetBits = 16)
        : type_(type)
        , targetBits_(targetBits)
    {
        quantizationStep_ = 1.0f / (1 << (targetBits - 1));
    }

    void process(juce::AudioBuffer<float>& buffer) {
        if (type_ == DitherType::None) return;

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            float* data = buffer.getWritePointer(ch);

            for (int i = 0; i < buffer.getNumSamples(); ++i) {
                float dither = generateDither();
                float sample = data[i] + dither * quantizationStep_;

                // Quantize
                sample = std::round(sample / quantizationStep_) * quantizationStep_;
                data[i] = juce::jlimit(-1.0f, 1.0f, sample);
            }
        }
    }

private:
    float generateDither() {
        switch (type_) {
            case DitherType::Rectangular:
                return random_.nextFloat() - 0.5f;

            case DitherType::Triangular: {
                float r1 = random_.nextFloat();
                float r2 = random_.nextFloat();
                return (r1 - r2);
            }

            case DitherType::ShapedNoise: {
                float r1 = random_.nextFloat();
                float r2 = random_.nextFloat();
                float tpdf = r1 - r2;

                // Simple noise shaping (high-pass)
                float shaped = tpdf - lastDither_ * 0.5f;
                lastDither_ = tpdf;
                return shaped;
            }

            default:
                return 0.0f;
        }
    }

    DitherType type_;
    int targetBits_;
    float quantizationStep_;
    juce::Random random_;
    float lastDither_ = 0.0f;
};

//==============================================================================
/** Normalizer processor */
class Normalizer {
public:
    Normalizer(float targetPeakDB = 0.0f)
        : targetPeak_(juce::Decibels::decibelsToGain(targetPeakDB))
    {
    }

    void analyze(const juce::AudioBuffer<float>& buffer) {
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            float channelPeak = buffer.getMagnitude(ch, 0, buffer.getNumSamples());
            peakLevel_ = std::max(peakLevel_, channelPeak);
        }
    }

    void apply(juce::AudioBuffer<float>& buffer) {
        if (peakLevel_ > 0.0f && peakLevel_ != targetPeak_) {
            float gain = targetPeak_ / peakLevel_;
            buffer.applyGain(gain);
        }
    }

    void reset() { peakLevel_ = 0.0f; }

private:
    float targetPeak_;
    float peakLevel_ = 0.0f;
};

//==============================================================================
/** Main offline renderer */
class OfflineRenderer {
public:
    OfflineRenderer() = default;

    //==============================================================================
    /** Render source to file */
    bool render(RenderSource& source,
                const juce::File& outputFile,
                const RenderSettings& settings,
                std::function<void(const RenderProgress&)> progressCallback = nullptr) {
        // Prepare source
        source.prepareToRender(settings.sampleRate, settings.blockSize);

        // Calculate total samples
        int64_t totalSamples = static_cast<int64_t>(
            (source.getLength() + settings.tailLength) * settings.sampleRate);

        // Create output file
        juce::WavAudioFormat wavFormat;
        outputFile.deleteFile();

        std::unique_ptr<juce::AudioFormatWriter> writer(
            wavFormat.createWriterFor(
                new juce::FileOutputStream(outputFile),
                settings.sampleRate,
                source.getNumChannels(),
                settings.getBitDepth(),
                {}, 0));

        if (!writer) {
            if (progressCallback) {
                RenderProgress progress;
                progress.hasError = true;
                progress.errorMessage = "Failed to create output file";
                progressCallback(progress);
            }
            return false;
        }

        // Prepare processors
        Normalizer normalizer(settings.normalizeLevel);
        DitherProcessor dither(
            settings.addDither ? DitherProcessor::DitherType::Triangular
                              : DitherProcessor::DitherType::None,
            settings.getBitDepth());

        // First pass: analyze for normalization if needed
        if (settings.normalize) {
            juce::AudioBuffer<float> analyzeBuffer(source.getNumChannels(), settings.blockSize);
            int64_t samplesProcessed = 0;

            while (samplesProcessed < totalSamples) {
                int samplesToProcess = static_cast<int>(
                    std::min(static_cast<int64_t>(settings.blockSize),
                             totalSamples - samplesProcessed));

                analyzeBuffer.clear();
                source.renderBlock(analyzeBuffer, samplesToProcess);
                normalizer.analyze(analyzeBuffer);

                samplesProcessed += samplesToProcess;

                if (progressCallback) {
                    RenderProgress progress;
                    progress.progress = static_cast<double>(samplesProcessed) / totalSamples * 0.5;
                    progress.currentStage = "Analyzing...";
                    progressCallback(progress);
                }
            }

            // Reset source for second pass
            source.releaseRender();
            source.prepareToRender(settings.sampleRate, settings.blockSize);
        }

        // Main render pass
        juce::AudioBuffer<float> renderBuffer(source.getNumChannels(), settings.blockSize);
        int64_t samplesProcessed = 0;
        auto startTime = juce::Time::getMillisecondCounterHiRes();

        while (samplesProcessed < totalSamples) {
            int samplesToProcess = static_cast<int>(
                std::min(static_cast<int64_t>(settings.blockSize),
                         totalSamples - samplesProcessed));

            renderBuffer.clear();
            source.renderBlock(renderBuffer, samplesToProcess);

            // Apply normalization
            if (settings.normalize) {
                normalizer.apply(renderBuffer);
            }

            // Apply dither
            dither.process(renderBuffer);

            // Write to file
            writer->writeFromAudioSampleBuffer(renderBuffer, 0, samplesToProcess);

            samplesProcessed += samplesToProcess;

            // Progress callback
            if (progressCallback) {
                double elapsed = (juce::Time::getMillisecondCounterHiRes() - startTime) / 1000.0;
                double progressBase = settings.normalize ? 0.5 : 0.0;
                double progressRange = settings.normalize ? 0.5 : 1.0;

                RenderProgress progress;
                progress.progress = progressBase +
                                   (static_cast<double>(samplesProcessed) / totalSamples) * progressRange;
                progress.elapsedTime = elapsed;
                progress.estimatedRemaining = elapsed / progress.progress * (1.0 - progress.progress);
                progress.currentStage = "Rendering...";
                progressCallback(progress);
            }
        }

        // Cleanup
        source.releaseRender();
        writer.reset();

        // Completion callback
        if (progressCallback) {
            RenderProgress progress;
            progress.progress = 1.0;
            progress.isComplete = true;
            progress.currentStage = "Complete";
            progressCallback(progress);
        }

        return true;
    }

    //==============================================================================
    /** Render multiple sources to stems */
    bool renderStems(const std::vector<RenderSource*>& sources,
                     const juce::File& outputDirectory,
                     const juce::String& baseName,
                     const RenderSettings& settings,
                     std::function<void(int, const RenderProgress&)> progressCallback = nullptr) {
        if (!outputDirectory.exists()) {
            outputDirectory.createDirectory();
        }

        for (size_t i = 0; i < sources.size(); ++i) {
            juce::File outputFile = outputDirectory.getChildFile(
                baseName + "_" + sources[i]->getName() + ".wav");

            auto stemProgress = [&progressCallback, i](const RenderProgress& progress) {
                if (progressCallback) {
                    progressCallback(static_cast<int>(i), progress);
                }
            };

            if (!render(*sources[i], outputFile, settings, stemProgress)) {
                return false;
            }
        }

        return true;
    }
};

//==============================================================================
/** Track freezer manager */
class TrackFreezer {
public:
    TrackFreezer(const juce::File& freezeDirectory)
        : freezeDirectory_(freezeDirectory)
    {
        if (!freezeDirectory_.exists()) {
            freezeDirectory_.createDirectory();
        }
    }

    //==============================================================================
    /** Freeze a track */
    bool freezeTrack(const juce::String& trackId,
                     RenderSource& source,
                     FreezeMode mode = FreezeMode::PostFX,
                     std::function<void(const RenderProgress&)> progressCallback = nullptr) {
        // Check if already frozen
        if (isFrozen(trackId)) {
            unfreezeTrack(trackId);
        }

        // Create freeze file
        juce::File freezeFile = freezeDirectory_.getChildFile(
            trackId + "_frozen_" + juce::String(juce::Time::currentTimeMillis()) + ".wav");

        // Render settings for freeze
        RenderSettings settings;
        settings.sampleRate = 44100.0;  // Use project sample rate
        settings.quality = RenderQuality::High;
        settings.blockSize = 1024;

        // Render
        OfflineRenderer renderer;
        bool success = renderer.render(source, freezeFile, settings, progressCallback);

        if (success) {
            FreezeState state;
            state.isFrozen = true;
            state.mode = mode;
            state.frozenFile = freezeFile;
            state.freezeTime = juce::Time::getCurrentTime();
            state.startTime = 0.0;
            state.endTime = source.getLength();

            freezeStates_[trackId] = state;

            // Load frozen audio for playback
            loadFrozenAudio(trackId);

            if (onTrackFrozen) {
                onTrackFrozen(trackId);
            }
        }

        return success;
    }

    /** Unfreeze a track */
    bool unfreezeTrack(const juce::String& trackId) {
        auto it = freezeStates_.find(trackId);
        if (it == freezeStates_.end()) return false;

        // Delete frozen file
        if (it->second.frozenFile.existsAsFile()) {
            it->second.frozenFile.deleteFile();
        }

        // Remove from loaded audio
        frozenAudio_.erase(trackId);

        // Remove state
        freezeStates_.erase(it);

        if (onTrackUnfrozen) {
            onTrackUnfrozen(trackId);
        }

        return true;
    }

    /** Check if track is frozen */
    bool isFrozen(const juce::String& trackId) const {
        auto it = freezeStates_.find(trackId);
        return it != freezeStates_.end() && it->second.isFrozen;
    }

    /** Get freeze state */
    const FreezeState* getFreezeState(const juce::String& trackId) const {
        auto it = freezeStates_.find(trackId);
        if (it != freezeStates_.end()) {
            return &it->second;
        }
        return nullptr;
    }

    //==============================================================================
    /** Get frozen audio for playback */
    const juce::AudioBuffer<float>* getFrozenAudio(const juce::String& trackId) const {
        auto it = frozenAudio_.find(trackId);
        if (it != frozenAudio_.end()) {
            return &it->second;
        }
        return nullptr;
    }

    /** Read frozen audio into buffer */
    void readFrozenAudio(const juce::String& trackId,
                         juce::AudioBuffer<float>& buffer,
                         int64_t startSample,
                         int numSamples) const {
        auto it = frozenAudio_.find(trackId);
        if (it == frozenAudio_.end()) {
            buffer.clear();
            return;
        }

        const auto& frozenBuffer = it->second;
        int availableSamples = std::max(0,
            static_cast<int>(frozenBuffer.getNumSamples() - startSample));
        int samplesToCopy = std::min(numSamples, availableSamples);

        if (samplesToCopy > 0) {
            for (int ch = 0; ch < std::min(buffer.getNumChannels(),
                                           frozenBuffer.getNumChannels()); ++ch) {
                buffer.copyFrom(ch, 0, frozenBuffer, ch,
                               static_cast<int>(startSample), samplesToCopy);
            }
        }

        // Clear remaining samples
        if (samplesToCopy < numSamples) {
            for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
                buffer.clear(ch, samplesToCopy, numSamples - samplesToCopy);
            }
        }
    }

    //==============================================================================
    /** Bounce track in place */
    bool bounceInPlace(const juce::String& trackId,
                       RenderSource& source,
                       const RenderSettings& settings,
                       std::function<void(const RenderProgress&)> progressCallback = nullptr) {
        juce::File bounceFile = freezeDirectory_.getChildFile(
            trackId + "_bounced_" + juce::String(juce::Time::currentTimeMillis()) + ".wav");

        OfflineRenderer renderer;
        bool success = renderer.render(source, bounceFile, settings, progressCallback);

        if (success && onTrackBounced) {
            onTrackBounced(trackId, bounceFile);
        }

        return success;
    }

    /** Bounce to new track */
    juce::File bounceToNewTrack(const juce::String& sourceTrackId,
                                RenderSource& source,
                                const RenderSettings& settings,
                                std::function<void(const RenderProgress&)> progressCallback = nullptr) {
        juce::File bounceFile = freezeDirectory_.getChildFile(
            sourceTrackId + "_bounce_" + juce::String(juce::Time::currentTimeMillis()) + ".wav");

        OfflineRenderer renderer;
        if (renderer.render(source, bounceFile, settings, progressCallback)) {
            return bounceFile;
        }

        return {};
    }

    //==============================================================================
    /** Export stems for all tracks */
    bool exportStems(const std::vector<std::pair<juce::String, RenderSource*>>& tracks,
                     const juce::File& outputDirectory,
                     const juce::String& projectName,
                     const RenderSettings& settings,
                     std::function<void(int, const RenderProgress&)> progressCallback = nullptr) {
        std::vector<RenderSource*> sources;
        for (const auto& track : tracks) {
            sources.push_back(track.second);
        }

        OfflineRenderer renderer;
        return renderer.renderStems(sources, outputDirectory, projectName,
                                    settings, progressCallback);
    }

    //==============================================================================
    /** Clean up old freeze files */
    void cleanupOldFreezeFiles(int maxAgeDays = 30) {
        juce::Array<juce::File> files;
        freezeDirectory_.findChildFiles(files, juce::File::findFiles, false, "*.wav");

        juce::Time cutoffTime = juce::Time::getCurrentTime() -
                                juce::RelativeTime::days(maxAgeDays);

        for (const auto& file : files) {
            // Check if file is still in use
            bool inUse = false;
            for (const auto& state : freezeStates_) {
                if (state.second.frozenFile == file) {
                    inUse = true;
                    break;
                }
            }

            // Delete if not in use and old
            if (!inUse && file.getCreationTime() < cutoffTime) {
                file.deleteFile();
            }
        }
    }

    /** Get total freeze storage used */
    int64_t getTotalFreezeStorage() const {
        int64_t total = 0;
        for (const auto& state : freezeStates_) {
            if (state.second.frozenFile.existsAsFile()) {
                total += state.second.frozenFile.getSize();
            }
        }
        return total;
    }

    //==============================================================================
    // Callbacks
    std::function<void(const juce::String& trackId)> onTrackFrozen;
    std::function<void(const juce::String& trackId)> onTrackUnfrozen;
    std::function<void(const juce::String& trackId, const juce::File& file)> onTrackBounced;

private:
    void loadFrozenAudio(const juce::String& trackId) {
        auto it = freezeStates_.find(trackId);
        if (it == freezeStates_.end()) return;

        juce::AudioFormatManager formatManager;
        formatManager.registerBasicFormats();

        std::unique_ptr<juce::AudioFormatReader> reader(
            formatManager.createReaderFor(it->second.frozenFile));

        if (!reader) return;

        juce::AudioBuffer<float> buffer(reader->numChannels,
                                         static_cast<int>(reader->lengthInSamples));
        reader->read(&buffer, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

        frozenAudio_[trackId] = std::move(buffer);
    }

    juce::File freezeDirectory_;
    std::map<juce::String, FreezeState> freezeStates_;
    std::map<juce::String, juce::AudioBuffer<float>> frozenAudio_;
};

//==============================================================================
/** Batch exporter for multiple formats */
class BatchExporter {
public:
    struct ExportJob {
        juce::String name;
        RenderSource* source = nullptr;
        juce::File outputFile;
        RenderSettings settings;
    };

    void addJob(const ExportJob& job) {
        jobs_.push_back(job);
    }

    void clearJobs() {
        jobs_.clear();
    }

    bool execute(std::function<void(int, int, const RenderProgress&)> progressCallback = nullptr) {
        OfflineRenderer renderer;

        for (size_t i = 0; i < jobs_.size(); ++i) {
            auto& job = jobs_[i];

            auto jobProgress = [&progressCallback, i, this](const RenderProgress& progress) {
                if (progressCallback) {
                    progressCallback(static_cast<int>(i),
                                    static_cast<int>(jobs_.size()),
                                    progress);
                }
            };

            if (!renderer.render(*job.source, job.outputFile, job.settings, jobProgress)) {
                return false;
            }
        }

        return true;
    }

    //==============================================================================
    /** Quick export presets */
    static RenderSettings getMP3Preset() {
        RenderSettings settings;
        settings.sampleRate = 44100.0;
        settings.bitDepth = 16;
        settings.quality = RenderQuality::Standard;
        return settings;
    }

    static RenderSettings getWAVMasterPreset() {
        RenderSettings settings;
        settings.sampleRate = 96000.0;
        settings.bitDepth = 24;
        settings.quality = RenderQuality::Master;
        settings.normalize = true;
        settings.normalizeLevel = -0.3f;
        settings.addDither = true;
        return settings;
    }

    static RenderSettings getStemPreset() {
        RenderSettings settings;
        settings.sampleRate = 48000.0;
        settings.bitDepth = 24;
        settings.quality = RenderQuality::High;
        settings.normalize = false;
        return settings;
    }

private:
    std::vector<ExportJob> jobs_;
};

} // namespace Audio
} // namespace Echoelmusic
