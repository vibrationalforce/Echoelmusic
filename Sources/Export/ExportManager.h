#pragma once

#include <JuceHeader.h>
#include <memory>
#include <functional>

namespace echoelmusic {
namespace export {

/**
 * @brief Professional Audio Export System
 *
 * CRITICAL MVP COMPONENT - Users need to export their music!
 *
 * Supports:
 * - WAV (16/24/32-bit, all sample rates)
 * - MP3 (via LAME encoder or JUCE built-in)
 * - AAC (via system codecs)
 * - FLAC (lossless)
 * - OGG Vorbis
 *
 * Features:
 * - Metadata embedding (artist, title, BPM, etc.)
 * - LUFS normalization (streaming platforms)
 * - Dithering (for bit depth reduction)
 * - Stem export (individual tracks)
 * - Batch export
 * - Background export (non-blocking)
 *
 * @author Claude Code (ULTRATHINK SUPER LASER MODE)
 * @date 2025-11-18
 */
class ExportManager
{
public:
    /**
     * @brief Export format
     */
    enum class Format
    {
        WAV,     ///< Uncompressed WAV
        AIFF,    ///< Apple AIFF
        FLAC,    ///< Free Lossless Audio Codec
        MP3,     ///< MPEG Layer 3
        AAC,     ///< Advanced Audio Coding
        OGG      ///< Ogg Vorbis
    };

    /**
     * @brief Bit depth for WAV/AIFF export
     */
    enum class BitDepth
    {
        Int16 = 16,   ///< 16-bit (CD quality)
        Int24 = 24,   ///< 24-bit (professional)
        Float32 = 32  ///< 32-bit float (maximum quality)
    };

    /**
     * @brief MP3 quality presets
     */
    enum class MP3Quality
    {
        Low = 128,      ///< 128 kbps (small file size)
        Medium = 192,   ///< 192 kbps (good quality)
        High = 256,     ///< 256 kbps (high quality)
        VeryHigh = 320  ///< 320 kbps (maximum quality)
    };

    /**
     * @brief Export settings
     */
    struct ExportSettings
    {
        // Output file
        juce::File outputFile;

        // Format
        Format format = Format::WAV;
        BitDepth bitDepth = BitDepth::Int24;
        int sampleRate = 48000;

        // MP3/AAC settings
        MP3Quality mp3Quality = MP3Quality::High;
        int aacBitrate = 256;  // kbps

        // Processing
        bool applyDithering = true;
        bool normalizeLUFS = false;
        double targetLUFS = -14.0;  // Spotify/Apple Music target

        // Metadata
        juce::String title;
        juce::String artist;
        juce::String album;
        juce::String genre;
        int year = 0;
        int trackNumber = 0;
        juce::String comment;
        double bpm = 0.0;

        // Advanced
        bool exportStems = false;  // Export individual tracks
        juce::Range<double> timeRange;  // Empty = full song
        bool addToiTunes = false;  // macOS only
    };

    /**
     * @brief Export progress callback
     *
     * @param progress 0.0 to 1.0
     * @param currentOperation Human-readable description (e.g., "Rendering track 2/8")
     */
    using ProgressCallback = std::function<void(double progress, const juce::String& currentOperation)>;

    /**
     * @brief Export completion callback
     *
     * @param success true if export succeeded
     * @param errorMessage Error description (empty if success)
     */
    using CompletionCallback = std::function<void(bool success, const juce::String& errorMessage)>;

public:
    /**
     * @brief Get singleton instance
     */
    static ExportManager& getInstance();

    /**
     * @brief Export audio (synchronous - blocks until complete)
     *
     * @param audioBuffer Audio data to export
     * @param numChannels Number of channels (1 = mono, 2 = stereo)
     * @param settings Export settings
     * @param progressCallback Optional progress callback
     * @return true if export succeeded
     */
    bool exportAudio(
        const float* const* audioBuffer,
        int numSamples,
        int numChannels,
        const ExportSettings& settings,
        ProgressCallback progressCallback = nullptr
    );

    /**
     * @brief Export audio (asynchronous - runs in background)
     *
     * Non-blocking. Use this for large exports to keep UI responsive.
     *
     * @param audioBuffer Audio data to export (must remain valid until completion!)
     * @param numSamples Number of samples
     * @param numChannels Number of channels
     * @param settings Export settings
     * @param progressCallback Progress updates
     * @param completionCallback Called when export finishes
     */
    void exportAudioAsync(
        const float* const* audioBuffer,
        int numSamples,
        int numChannels,
        const ExportSettings& settings,
        ProgressCallback progressCallback = nullptr,
        CompletionCallback completionCallback = nullptr
    );

    /**
     * @brief Cancel ongoing async export
     */
    void cancelExport();

    /**
     * @brief Check if export is in progress
     *
     * @return true if currently exporting
     */
    bool isExporting() const;

    /**
     * @brief Get supported export formats
     *
     * Some formats may not be available depending on platform/codecs
     *
     * @return Vector of supported formats
     */
    std::vector<Format> getSupportedFormats() const;

    /**
     * @brief Check if format is supported
     *
     * @param format Format to check
     * @return true if supported
     */
    bool isFormatSupported(Format format) const;

    /**
     * @brief Get file extension for format
     *
     * @param format Export format
     * @return File extension (e.g., ".wav", ".mp3")
     */
    static juce::String getFileExtension(Format format);

    /**
     * @brief Get format name for display
     *
     * @param format Export format
     * @return Human-readable name (e.g., "WAV (Uncompressed)")
     */
    static juce::String getFormatName(Format format);

    /**
     * @brief Quick export presets
     */
    struct Presets
    {
        static ExportSettings cd();          // CD quality (WAV 16-bit 44.1kHz)
        static ExportSettings pro();         // Pro quality (WAV 24-bit 48kHz)
        static ExportSettings master();      // Master quality (WAV 32-bit 48kHz)
        static ExportSettings spotify();     // Spotify upload (OGG 320kbps, -14 LUFS)
        static ExportSettings appleMusic();  // Apple Music (AAC 256kbps, -16 LUFS)
        static ExportSettings youtube();     // YouTube (MP3 192kbps, -13 LUFS)
        static ExportSettings soundcloud();  // SoundCloud (MP3 256kbps, -11 LUFS)
    };

private:
    ExportManager() = default;
    ~ExportManager() = default;

    // Prevent copying
    ExportManager(const ExportManager&) = delete;
    ExportManager& operator=(const ExportManager&) = delete;

    /**
     * @brief Export to WAV format
     */
    bool exportWAV(
        const float* const* audioBuffer,
        int numSamples,
        int numChannels,
        const ExportSettings& settings,
        ProgressCallback progressCallback
    );

    /**
     * @brief Export to MP3 format
     */
    bool exportMP3(
        const float* const* audioBuffer,
        int numSamples,
        int numChannels,
        const ExportSettings& settings,
        ProgressCallback progressCallback
    );

    /**
     * @brief Export to AAC format
     */
    bool exportAAC(
        const float* const* audioBuffer,
        int numSamples,
        int numChannels,
        const ExportSettings& settings,
        ProgressCallback progressCallback
    );

    /**
     * @brief Apply LUFS normalization
     */
    void applyLUFSNormalization(
        float** audioBuffer,
        int numSamples,
        int numChannels,
        double targetLUFS
    );

    /**
     * @brief Apply dithering for bit depth reduction
     */
    void applyDithering(
        float** audioBuffer,
        int numSamples,
        int numChannels,
        BitDepth targetBitDepth
    );

    /**
     * @brief Embed metadata into file
     */
    bool embedMetadata(
        const juce::File& file,
        const ExportSettings& settings
    );

    /**
     * @brief Calculate LUFS loudness
     */
    double calculateLUFS(
        const float* const* audioBuffer,
        int numSamples,
        int numChannels
    ) const;

private:
    std::atomic<bool> m_isExporting{false};
    std::atomic<bool> m_shouldCancel{false};
    std::unique_ptr<juce::Thread> m_exportThread;
};

} // namespace export
} // namespace echoelmusic
