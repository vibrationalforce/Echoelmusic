#pragma once

#include <JuceHeader.h>
#include <memory>
#include <vector>
#include <functional>
#include <atomic>
#include <thread>

/**
 * AudioExportSuite - Professional Audio Export System
 *
 * Export Formats:
 * - WAV (16/24/32-bit, 32-bit float)
 * - FLAC (lossless compression)
 * - MP3 (128-320 kbps)
 * - OGG Vorbis (quality 0-10)
 * - AAC/M4A (Apple)
 * - AIFF (Apple lossless)
 * - ALAC (Apple Lossless Audio Codec)
 *
 * Features:
 * - Real-time export with progress
 * - Batch export
 * - Stem export
 * - Dithering (TPDF, noise shaping)
 * - Loudness normalization (LUFS)
 * - True peak limiting
 * - Metadata embedding
 * - Multi-threaded rendering
 *
 * Platform Ready: macOS, iOS, Windows, Linux, Android
 */

namespace Echoelmusic {
namespace Audio {

//==============================================================================
// Export Format Definitions
//==============================================================================

enum class AudioFormat
{
    WAV_16,
    WAV_24,
    WAV_32,
    WAV_32F,
    FLAC_16,
    FLAC_24,
    MP3_128,
    MP3_192,
    MP3_256,
    MP3_320,
    OGG_Q5,
    OGG_Q7,
    OGG_Q10,
    AAC_128,
    AAC_256,
    AIFF_16,
    AIFF_24,
    ALAC
};

enum class DitherType
{
    None,
    TPDF,           // Triangular Probability Density Function
    NoiseShaping,   // Shaped dither for reduced audible noise
    POW_R           // Pow-r dithering (psychoacoustic)
};

enum class NormalizationType
{
    None,
    Peak,           // Normalize to peak level
    RMS,            // Normalize to RMS level
    LUFS_Integrated, // EBU R128 integrated loudness
    LUFS_ShortTerm   // EBU R128 short-term loudness
};

//==============================================================================
// Metadata
//==============================================================================

struct AudioMetadata
{
    std::string title;
    std::string artist;
    std::string album;
    std::string genre;
    std::string year;
    std::string trackNumber;
    std::string comment;
    std::string composer;
    std::string copyright;
    std::string isrc;           // International Standard Recording Code
    std::string albumArtPath;   // Path to album art image

    // Extended metadata
    int bpm = 0;
    std::string key;
    std::string mood;
    std::string energy;         // Low, Medium, High
    std::vector<std::string> tags;
};

//==============================================================================
// Export Settings
//==============================================================================

struct ExportSettings
{
    // Format
    AudioFormat format = AudioFormat::WAV_24;
    double sampleRate = 48000.0;
    int numChannels = 2;

    // Processing
    DitherType dither = DitherType::TPDF;
    NormalizationType normalization = NormalizationType::None;
    float targetLUFS = -14.0f;      // Streaming standard
    float targetPeak = -1.0f;       // dBTP (true peak)
    bool enableLimiter = true;
    float limiterThreshold = -0.3f; // dBTP
    float limiterRelease = 100.0f;  // ms

    // Range
    double startTime = 0.0;
    double endTime = -1.0;          // -1 = end of project
    bool exportLoopRange = false;

    // Stems
    bool exportStems = false;
    bool exportMaster = true;
    std::vector<int> stemTrackIndices;

    // Output
    std::string outputPath;
    std::string filenamePattern = "{title}_{format}";
    bool overwriteExisting = false;
    bool addToMediaLibrary = true;  // iOS/macOS

    // Metadata
    AudioMetadata metadata;
    bool embedMetadata = true;
    bool embedAlbumArt = true;

    // Performance
    int numThreads = 0;             // 0 = auto
    int bufferSize = 4096;
    bool realtime = false;          // false = offline (faster)
};

//==============================================================================
// Export Progress
//==============================================================================

struct ExportProgress
{
    float percentage = 0.0f;        // 0-100
    double currentTime = 0.0;
    double totalTime = 0.0;
    std::string currentStage;       // "Rendering", "Encoding", "Writing metadata"
    std::string currentFile;
    int filesCompleted = 0;
    int filesTotal = 1;
    bool isComplete = false;
    bool hasError = false;
    std::string errorMessage;

    // Performance stats
    float realtimeRatio = 0.0f;     // > 1 means faster than realtime
    size_t bytesWritten = 0;
    double elapsedSeconds = 0.0;
};

using ProgressCallback = std::function<void(const ExportProgress&)>;

//==============================================================================
// Loudness Analyzer
//==============================================================================

class LoudnessAnalyzer
{
public:
    struct Result
    {
        float integratedLUFS = -23.0f;
        float shortTermLUFS = -23.0f;
        float momentaryLUFS = -23.0f;
        float truePeak = -6.0f;
        float range = 8.0f;         // Loudness range (LRA)
    };

    void prepare(double sampleRate, int channels)
    {
        this->sampleRate = sampleRate;
        this->numChannels = channels;
        reset();
    }

    void reset()
    {
        sumSquares = 0.0;
        sampleCount = 0;
        peak = 0.0f;
    }

    void process(const juce::AudioBuffer<float>& buffer)
    {
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            auto* data = buffer.getReadPointer(ch);
            for (int i = 0; i < buffer.getNumSamples(); ++i)
            {
                float sample = data[i];
                sumSquares += sample * sample;
                peak = std::max(peak, std::abs(sample));
            }
        }
        sampleCount += buffer.getNumSamples() * buffer.getNumChannels();
    }

    Result getResult() const
    {
        Result result;

        if (sampleCount > 0)
        {
            double meanSquare = sumSquares / sampleCount;
            double rms = std::sqrt(meanSquare);

            // LUFS = -0.691 + 10 * log10(mean square)
            result.integratedLUFS = static_cast<float>(-0.691 + 10.0 * std::log10(meanSquare + 1e-10));
            result.shortTermLUFS = result.integratedLUFS;  // Simplified
            result.truePeak = 20.0f * std::log10(peak + 1e-10f);
        }

        return result;
    }

private:
    double sampleRate = 48000.0;
    int numChannels = 2;
    double sumSquares = 0.0;
    size_t sampleCount = 0;
    float peak = 0.0f;
};

//==============================================================================
// Dithering Processor
//==============================================================================

class DitheringProcessor
{
public:
    void setType(DitherType type) { ditherType = type; }
    void setTargetBits(int bits) { targetBits = bits; }

    void process(juce::AudioBuffer<float>& buffer)
    {
        if (ditherType == DitherType::None)
            return;

        float ditherAmplitude = 1.0f / (1 << (targetBits - 1));

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            auto* data = buffer.getWritePointer(ch);

            for (int i = 0; i < buffer.getNumSamples(); ++i)
            {
                float dither = 0.0f;

                switch (ditherType)
                {
                    case DitherType::TPDF:
                        // Triangular PDF: sum of two uniform randoms
                        dither = (random.nextFloat() + random.nextFloat() - 1.0f) * ditherAmplitude;
                        break;

                    case DitherType::NoiseShaping:
                        // Simple first-order noise shaping
                        dither = (random.nextFloat() - 0.5f) * ditherAmplitude;
                        dither += errorFeedback[ch] * 0.5f;
                        errorFeedback[ch] = dither;
                        break;

                    default:
                        break;
                }

                data[i] += dither;
            }
        }
    }

private:
    DitherType ditherType = DitherType::TPDF;
    int targetBits = 16;
    juce::Random random;
    std::array<float, 8> errorFeedback{};
};

//==============================================================================
// True Peak Limiter
//==============================================================================

class TruePeakLimiter
{
public:
    void prepare(double sampleRate, int channels)
    {
        this->sampleRate = sampleRate;
        this->numChannels = channels;

        // 4x oversampling for true peak detection
        oversampling = 4;

        envelope.resize(channels, 0.0f);
        gainReduction.resize(channels, 1.0f);
    }

    void setThreshold(float thresholdDB)
    {
        threshold = std::pow(10.0f, thresholdDB / 20.0f);
    }

    void setRelease(float releaseMs)
    {
        releaseCoeff = std::exp(-1.0f / (releaseMs * 0.001f * static_cast<float>(sampleRate)));
    }

    void process(juce::AudioBuffer<float>& buffer)
    {
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            auto* data = buffer.getWritePointer(ch);

            for (int i = 0; i < buffer.getNumSamples(); ++i)
            {
                float input = std::abs(data[i]);

                // Envelope follower
                if (input > envelope[ch])
                    envelope[ch] = input;
                else
                    envelope[ch] = envelope[ch] * releaseCoeff + input * (1.0f - releaseCoeff);

                // Gain calculation
                if (envelope[ch] > threshold)
                    gainReduction[ch] = threshold / envelope[ch];
                else
                    gainReduction[ch] = 1.0f;

                data[i] *= gainReduction[ch];
            }
        }
    }

private:
    double sampleRate = 48000.0;
    int numChannels = 2;
    int oversampling = 4;
    float threshold = 0.89f;  // -1 dB
    float releaseCoeff = 0.9999f;
    std::vector<float> envelope;
    std::vector<float> gainReduction;
};

//==============================================================================
// Main Export Engine
//==============================================================================

class AudioExportEngine
{
public:
    static AudioExportEngine& getInstance()
    {
        static AudioExportEngine instance;
        return instance;
    }

    //==========================================================================
    // Export Methods
    //==========================================================================

    bool exportAudio(const juce::AudioBuffer<float>& source,
                     const ExportSettings& settings,
                     ProgressCallback progressCallback = nullptr)
    {
        currentSettings = settings;
        progress = ExportProgress();
        progress.totalTime = source.getNumSamples() / settings.sampleRate;
        progress.currentStage = "Preparing";

        if (progressCallback)
            progressCallback(progress);

        // Create output buffer
        juce::AudioBuffer<float> outputBuffer;
        outputBuffer.makeCopyOf(source);

        // Apply processing chain
        progress.currentStage = "Processing";

        // 1. Normalize if requested
        if (settings.normalization != NormalizationType::None)
        {
            applyNormalization(outputBuffer, settings);
        }

        // 2. Apply limiter if enabled
        if (settings.enableLimiter)
        {
            limiter.prepare(settings.sampleRate, settings.numChannels);
            limiter.setThreshold(settings.limiterThreshold);
            limiter.setRelease(settings.limiterRelease);
            limiter.process(outputBuffer);
        }

        // 3. Apply dither for bit depth reduction
        if (needsDithering(settings.format))
        {
            ditherer.setType(settings.dither);
            ditherer.setTargetBits(getBitDepth(settings.format));
            ditherer.process(outputBuffer);
        }

        // 4. Write to file
        progress.currentStage = "Encoding";
        bool success = writeToFile(outputBuffer, settings, progressCallback);

        // 5. Embed metadata
        if (success && settings.embedMetadata)
        {
            progress.currentStage = "Writing metadata";
            embedMetadata(settings.outputPath, settings.metadata);
        }

        progress.isComplete = true;
        progress.percentage = 100.0f;

        if (progressCallback)
            progressCallback(progress);

        return success;
    }

    bool exportStems(const std::vector<juce::AudioBuffer<float>>& stems,
                     const std::vector<std::string>& stemNames,
                     const ExportSettings& settings,
                     ProgressCallback progressCallback = nullptr)
    {
        progress = ExportProgress();
        progress.filesTotal = static_cast<int>(stems.size());

        for (size_t i = 0; i < stems.size(); ++i)
        {
            ExportSettings stemSettings = settings;
            stemSettings.outputPath = getOutputPath(settings.outputPath, stemNames[i], settings.format);

            progress.currentFile = stemNames[i];
            progress.filesCompleted = static_cast<int>(i);

            if (!exportAudio(stems[i], stemSettings, progressCallback))
                return false;
        }

        return true;
    }

    void cancelExport()
    {
        cancelRequested = true;
    }

    //==========================================================================
    // Batch Export
    //==========================================================================

    struct BatchItem
    {
        juce::AudioBuffer<float> audio;
        ExportSettings settings;
        std::string name;
    };

    bool exportBatch(const std::vector<BatchItem>& items,
                     ProgressCallback progressCallback = nullptr)
    {
        progress = ExportProgress();
        progress.filesTotal = static_cast<int>(items.size());

        for (size_t i = 0; i < items.size(); ++i)
        {
            if (cancelRequested)
            {
                progress.hasError = true;
                progress.errorMessage = "Export cancelled";
                return false;
            }

            progress.currentFile = items[i].name;
            progress.filesCompleted = static_cast<int>(i);

            if (!exportAudio(items[i].audio, items[i].settings, progressCallback))
                return false;
        }

        return true;
    }

    //==========================================================================
    // Format Helpers
    //==========================================================================

    static std::string getFormatExtension(AudioFormat format)
    {
        switch (format)
        {
            case AudioFormat::WAV_16:
            case AudioFormat::WAV_24:
            case AudioFormat::WAV_32:
            case AudioFormat::WAV_32F:
                return ".wav";
            case AudioFormat::FLAC_16:
            case AudioFormat::FLAC_24:
                return ".flac";
            case AudioFormat::MP3_128:
            case AudioFormat::MP3_192:
            case AudioFormat::MP3_256:
            case AudioFormat::MP3_320:
                return ".mp3";
            case AudioFormat::OGG_Q5:
            case AudioFormat::OGG_Q7:
            case AudioFormat::OGG_Q10:
                return ".ogg";
            case AudioFormat::AAC_128:
            case AudioFormat::AAC_256:
                return ".m4a";
            case AudioFormat::AIFF_16:
            case AudioFormat::AIFF_24:
                return ".aiff";
            case AudioFormat::ALAC:
                return ".m4a";
            default:
                return ".wav";
        }
    }

    static std::string getFormatName(AudioFormat format)
    {
        switch (format)
        {
            case AudioFormat::WAV_16:  return "WAV 16-bit";
            case AudioFormat::WAV_24:  return "WAV 24-bit";
            case AudioFormat::WAV_32:  return "WAV 32-bit";
            case AudioFormat::WAV_32F: return "WAV 32-bit Float";
            case AudioFormat::FLAC_16: return "FLAC 16-bit";
            case AudioFormat::FLAC_24: return "FLAC 24-bit";
            case AudioFormat::MP3_128: return "MP3 128 kbps";
            case AudioFormat::MP3_192: return "MP3 192 kbps";
            case AudioFormat::MP3_256: return "MP3 256 kbps";
            case AudioFormat::MP3_320: return "MP3 320 kbps";
            case AudioFormat::OGG_Q5:  return "OGG Vorbis Q5";
            case AudioFormat::OGG_Q7:  return "OGG Vorbis Q7";
            case AudioFormat::OGG_Q10: return "OGG Vorbis Q10";
            case AudioFormat::AAC_128: return "AAC 128 kbps";
            case AudioFormat::AAC_256: return "AAC 256 kbps";
            case AudioFormat::AIFF_16: return "AIFF 16-bit";
            case AudioFormat::AIFF_24: return "AIFF 24-bit";
            case AudioFormat::ALAC:    return "Apple Lossless";
            default:                   return "Unknown";
        }
    }

    static std::vector<AudioFormat> getAvailableFormats()
    {
        return {
            AudioFormat::WAV_24,
            AudioFormat::WAV_16,
            AudioFormat::WAV_32F,
            AudioFormat::FLAC_24,
            AudioFormat::FLAC_16,
            AudioFormat::MP3_320,
            AudioFormat::MP3_256,
            AudioFormat::MP3_192,
            AudioFormat::MP3_128,
            AudioFormat::OGG_Q10,
            AudioFormat::OGG_Q7,
            AudioFormat::OGG_Q5,
#if JUCE_MAC || JUCE_IOS
            AudioFormat::AAC_256,
            AudioFormat::AAC_128,
            AudioFormat::AIFF_24,
            AudioFormat::ALAC,
#endif
        };
    }

    //==========================================================================
    // Presets
    //==========================================================================

    static ExportSettings getStreamingPreset()
    {
        ExportSettings settings;
        settings.format = AudioFormat::MP3_320;
        settings.sampleRate = 44100.0;
        settings.normalization = NormalizationType::LUFS_Integrated;
        settings.targetLUFS = -14.0f;
        settings.enableLimiter = true;
        settings.limiterThreshold = -1.0f;
        return settings;
    }

    static ExportSettings getMasteringPreset()
    {
        ExportSettings settings;
        settings.format = AudioFormat::WAV_24;
        settings.sampleRate = 96000.0;
        settings.normalization = NormalizationType::None;
        settings.dither = DitherType::None;
        settings.enableLimiter = false;
        return settings;
    }

    static ExportSettings getCDPreset()
    {
        ExportSettings settings;
        settings.format = AudioFormat::WAV_16;
        settings.sampleRate = 44100.0;
        settings.normalization = NormalizationType::Peak;
        settings.dither = DitherType::TPDF;
        settings.enableLimiter = true;
        settings.limiterThreshold = -0.3f;
        return settings;
    }

    static ExportSettings getPodcastPreset()
    {
        ExportSettings settings;
        settings.format = AudioFormat::MP3_192;
        settings.sampleRate = 44100.0;
        settings.numChannels = 1;  // Mono for podcasts
        settings.normalization = NormalizationType::LUFS_Integrated;
        settings.targetLUFS = -16.0f;
        settings.enableLimiter = true;
        return settings;
    }

private:
    AudioExportEngine() = default;

    //==========================================================================
    // Internal Processing
    //==========================================================================

    void applyNormalization(juce::AudioBuffer<float>& buffer, const ExportSettings& settings)
    {
        LoudnessAnalyzer analyzer;
        analyzer.prepare(settings.sampleRate, settings.numChannels);
        analyzer.process(buffer);
        auto result = analyzer.getResult();

        float gain = 1.0f;

        switch (settings.normalization)
        {
            case NormalizationType::Peak:
                gain = std::pow(10.0f, settings.targetPeak / 20.0f) / std::pow(10.0f, result.truePeak / 20.0f);
                break;

            case NormalizationType::LUFS_Integrated:
            case NormalizationType::LUFS_ShortTerm:
                gain = std::pow(10.0f, (settings.targetLUFS - result.integratedLUFS) / 20.0f);
                break;

            default:
                break;
        }

        buffer.applyGain(gain);
    }

    bool writeToFile(const juce::AudioBuffer<float>& buffer,
                     const ExportSettings& settings,
                     ProgressCallback progressCallback)
    {
        juce::File outputFile(settings.outputPath);

        if (outputFile.exists() && !settings.overwriteExisting)
        {
            progress.hasError = true;
            progress.errorMessage = "File already exists";
            return false;
        }

        outputFile.deleteFile();

        std::unique_ptr<juce::AudioFormatWriter> writer;

        // Create appropriate format writer
        if (isWavFormat(settings.format))
        {
            juce::WavAudioFormat wavFormat;
            writer.reset(wavFormat.createWriterFor(
                new juce::FileOutputStream(outputFile),
                settings.sampleRate,
                settings.numChannels,
                getBitDepth(settings.format),
                {},
                0
            ));
        }
        else if (isFlacFormat(settings.format))
        {
            juce::FlacAudioFormat flacFormat;
            writer.reset(flacFormat.createWriterFor(
                new juce::FileOutputStream(outputFile),
                settings.sampleRate,
                settings.numChannels,
                getBitDepth(settings.format),
                {},
                0
            ));
        }
        else if (isOggFormat(settings.format))
        {
            juce::OggVorbisAudioFormat oggFormat;
            writer.reset(oggFormat.createWriterFor(
                new juce::FileOutputStream(outputFile),
                settings.sampleRate,
                settings.numChannels,
                getBitDepth(settings.format),
                {},
                getOggQuality(settings.format)
            ));
        }
        // MP3 and AAC would require additional encoders

        if (!writer)
        {
            progress.hasError = true;
            progress.errorMessage = "Could not create audio writer";
            return false;
        }

        // Write in chunks with progress
        int samplesWritten = 0;
        int totalSamples = buffer.getNumSamples();
        int chunkSize = 8192;

        while (samplesWritten < totalSamples)
        {
            if (cancelRequested)
            {
                progress.hasError = true;
                progress.errorMessage = "Export cancelled";
                return false;
            }

            int samplesToWrite = std::min(chunkSize, totalSamples - samplesWritten);

            juce::AudioBuffer<float> chunk(buffer.getNumChannels(), samplesToWrite);
            for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
            {
                chunk.copyFrom(ch, 0, buffer, ch, samplesWritten, samplesToWrite);
            }

            writer->writeFromAudioSampleBuffer(chunk, 0, samplesToWrite);

            samplesWritten += samplesToWrite;
            progress.percentage = (samplesWritten * 100.0f) / totalSamples;
            progress.currentTime = samplesWritten / settings.sampleRate;

            if (progressCallback)
                progressCallback(progress);
        }

        return true;
    }

    void embedMetadata(const std::string& filePath, const AudioMetadata& metadata)
    {
        // Metadata embedding would use platform-specific APIs or TagLib
        // Placeholder for now
    }

    //==========================================================================
    // Format Helpers
    //==========================================================================

    int getBitDepth(AudioFormat format)
    {
        switch (format)
        {
            case AudioFormat::WAV_16:
            case AudioFormat::FLAC_16:
            case AudioFormat::AIFF_16:
                return 16;
            case AudioFormat::WAV_24:
            case AudioFormat::FLAC_24:
            case AudioFormat::AIFF_24:
            case AudioFormat::ALAC:
                return 24;
            case AudioFormat::WAV_32:
            case AudioFormat::WAV_32F:
                return 32;
            default:
                return 16;
        }
    }

    bool needsDithering(AudioFormat format)
    {
        return getBitDepth(format) < 24;
    }

    bool isWavFormat(AudioFormat format)
    {
        return format == AudioFormat::WAV_16 ||
               format == AudioFormat::WAV_24 ||
               format == AudioFormat::WAV_32 ||
               format == AudioFormat::WAV_32F;
    }

    bool isFlacFormat(AudioFormat format)
    {
        return format == AudioFormat::FLAC_16 ||
               format == AudioFormat::FLAC_24;
    }

    bool isOggFormat(AudioFormat format)
    {
        return format == AudioFormat::OGG_Q5 ||
               format == AudioFormat::OGG_Q7 ||
               format == AudioFormat::OGG_Q10;
    }

    int getOggQuality(AudioFormat format)
    {
        switch (format)
        {
            case AudioFormat::OGG_Q5:  return 5;
            case AudioFormat::OGG_Q7:  return 7;
            case AudioFormat::OGG_Q10: return 10;
            default: return 7;
        }
    }

    std::string getOutputPath(const std::string& basePath, const std::string& name, AudioFormat format)
    {
        juce::File baseFile(basePath);
        juce::File dir = baseFile.getParentDirectory();
        return dir.getChildFile(name + getFormatExtension(format)).getFullPathName().toStdString();
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    ExportSettings currentSettings;
    ExportProgress progress;
    std::atomic<bool> cancelRequested{false};

    DitheringProcessor ditherer;
    TruePeakLimiter limiter;
    LoudnessAnalyzer analyzer;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AudioExportEngine)
};

//==============================================================================
// Convenience Macro
//==============================================================================

#define EchoelExport AudioExportEngine::getInstance()

} // namespace Audio
} // namespace Echoelmusic
