#pragma once

#include <JuceHeader.h>
#include <functional>
#include <memory>

/**
 * AudioExporter - Advanced Audio Export with Compression
 *
 * Exports audio in various formats optimized for different use cases:
 * - MP3: Universal compatibility, streaming
 * - AAC: Apple ecosystem, high quality at lower bitrates
 * - FLAC: Lossless archival
 * - WAV: Uncompressed professional
 *
 * Features:
 * - Multiple encoder backends (LAME, FDK-AAC, ffmpeg)
 * - Configurable bitrate and quality
 * - LUFS normalization for streaming platforms
 * - ID3 tag embedding
 * - Album art embedding
 * - Background export with progress
 * - Batch export
 *
 * Streaming Platform Optimizations:
 * - Spotify: MP3 320kbps or AAC 256kbps, -14 LUFS
 * - Apple Music: AAC 256kbps, -16 LUFS
 * - YouTube: AAC 128kbps, -13 LUFS
 * - SoundCloud: MP3 128kbps, -14 LUFS
 * - Bandcamp: FLAC lossless or WAV
 *
 * Use Cases:
 * - Export finished tracks for release
 * - Share demos and previews
 * - Create podcast episodes
 * - Archive projects losslessly
 */
class AudioExporter
{
public:
    //==========================================================================
    // Export Format Configuration
    //==========================================================================

    enum class Format
    {
        WAV,            // Uncompressed PCM
        FLAC,           // Lossless compression
        MP3,            // Lossy (LAME encoder)
        AAC,            // Lossy (FDK-AAC or platform encoder)
        OGG             // Lossy (Vorbis)
    };

    enum class Quality
    {
        Low,            // Smaller file, lower quality
        Medium,         // Balanced
        High,           // Higher quality, larger file
        Extreme,        // Maximum quality
        Custom          // User-defined bitrate
    };

    struct ExportSettings
    {
        Format format = Format::MP3;
        Quality quality = Quality::High;
        int customBitrate = 320;  // kbps (for Custom quality)

        int sampleRate = 44100;
        int bitDepth = 16;  // Only for WAV/FLAC

        bool normalizeAudio = true;
        float targetLUFS = -14.0f;  // Default: Spotify standard

        // Metadata
        juce::String title;
        juce::String artist;
        juce::String album;
        juce::String genre;
        juce::String year;
        juce::String comment;

        juce::Image albumArt;

        // Advanced
        bool trimSilence = false;
        float silenceThreshold = -60.0f;  // dB

        bool fadeOut = false;
        double fadeOutDuration = 3.0;  // seconds

        juce::String getFormatExtension() const;
        int getBitrate() const;
    };

    //==========================================================================
    // Streaming Platform Presets
    //==========================================================================

    struct PlatformPreset
    {
        juce::String name;
        Format format;
        int bitrate;
        float targetLUFS;
        juce::String description;

        static PlatformPreset spotify();
        static PlatformPreset appleMusic();
        static PlatformPreset youtube();
        static PlatformPreset soundcloud();
        static PlatformPreset bandcamp();
        static PlatformPreset tidal();
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    AudioExporter();
    ~AudioExporter();

    //==========================================================================
    // Export Operations
    //==========================================================================

    /** Export audio buffer to file */
    bool exportAudio(const juce::AudioBuffer<float>& audio,
                    double sampleRate,
                    const juce::File& outputFile,
                    const ExportSettings& settings);

    /** Export audio from AudioSource */
    bool exportAudioSource(juce::AudioSource* source,
                          double totalLengthSeconds,
                          double sampleRate,
                          const juce::File& outputFile,
                          const ExportSettings& settings);

    /** Export with progress callback */
    bool exportAudioWithProgress(const juce::AudioBuffer<float>& audio,
                                double sampleRate,
                                const juce::File& outputFile,
                                const ExportSettings& settings,
                                std::function<bool(float progress)> progressCallback);

    //==========================================================================
    // Batch Export
    //==========================================================================

    struct BatchExportJob
    {
        juce::AudioBuffer<float> audio;
        double sampleRate;
        juce::File outputFile;
        ExportSettings settings;
    };

    /** Export multiple files in sequence */
    bool exportBatch(const juce::Array<BatchExportJob>& jobs,
                    std::function<bool(int jobIndex, float jobProgress)> progressCallback);

    //==========================================================================
    // Background Export
    //==========================================================================

    /** Start export in background thread */
    void exportAsync(const juce::AudioBuffer<float>& audio,
                    double sampleRate,
                    const juce::File& outputFile,
                    const ExportSettings& settings);

    /** Cancel ongoing export */
    void cancelExport();

    /** Check if export is in progress */
    bool isExporting() const { return exporting; }

    /** Get export progress (0.0 - 1.0) */
    float getProgress() const { return progress; }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(float progress)> onProgress;
    std::function<void(bool success, const juce::File& file)> onComplete;
    std::function<void(const juce::String& error)> onError;

    //==========================================================================
    // Encoder Availability
    //==========================================================================

    /** Check if format is supported */
    bool isFormatSupported(Format format) const;

    /** Get available formats */
    juce::Array<Format> getAvailableFormats() const;

    /** Get encoder info */
    juce::String getEncoderInfo(Format format) const;

private:
    //==========================================================================
    // Export Implementation
    //==========================================================================

    bool exportWAV(const juce::AudioBuffer<float>& audio,
                  double sampleRate,
                  const juce::File& outputFile,
                  const ExportSettings& settings);

    bool exportFLAC(const juce::AudioBuffer<float>& audio,
                   double sampleRate,
                   const juce::File& outputFile,
                   const ExportSettings& settings);

    bool exportMP3(const juce::AudioBuffer<float>& audio,
                  double sampleRate,
                  const juce::File& outputFile,
                  const ExportSettings& settings);

    bool exportAAC(const juce::AudioBuffer<float>& audio,
                  double sampleRate,
                  const juce::File& outputFile,
                  const ExportSettings& settings);

    bool exportOGG(const juce::AudioBuffer<float>& audio,
                  double sampleRate,
                  const juce::File& outputFile,
                  const ExportSettings& settings);

    //==========================================================================
    // Audio Processing
    //==========================================================================

    /** Normalize audio to target LUFS */
    void normalizeToLUFS(juce::AudioBuffer<float>& audio,
                        double sampleRate,
                        float targetLUFS);

    /** Calculate LUFS of audio */
    float calculateLUFS(const juce::AudioBuffer<float>& audio,
                       double sampleRate);

    /** Trim silence from start and end */
    void trimSilence(juce::AudioBuffer<float>& audio,
                    float threshold);

    /** Apply fade out */
    void applyFadeOut(juce::AudioBuffer<float>& audio,
                     double sampleRate,
                     double duration);

    //==========================================================================
    // Metadata Embedding
    //==========================================================================

    /** Write ID3v2 tags (MP3) */
    bool writeID3Tags(const juce::File& file,
                     const ExportSettings& settings);

    /** Write MP4 tags (AAC) */
    bool writeMP4Tags(const juce::File& file,
                     const ExportSettings& settings);

    /** Write Vorbis comments (FLAC, OGG) */
    bool writeVorbisComments(const juce::File& file,
                           const ExportSettings& settings);

    //==========================================================================
    // Encoder Backends
    //==========================================================================

    struct EncoderBackend;
    std::unique_ptr<EncoderBackend> encoder;

    //==========================================================================
    // State
    //==========================================================================

    std::atomic<bool> exporting { false };
    std::atomic<float> progress { 0.0f };
    std::atomic<bool> shouldCancel { false };

    juce::Thread* exportThread = nullptr;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AudioExporter)
};
