#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <functional>

/**
 * AudioExporter - Professional audio export system for Eoel
 *
 * Features:
 * - Master mixdown export (full project)
 * - Track bouncing (individual tracks)
 * - Region export (time selection)
 * - Multiple formats: WAV, FLAC, OGG (MP3 optional)
 * - Sample rate conversion
 * - Bit depth conversion (16-bit, 24-bit, 32-bit float)
 * - LUFS normalization
 * - Progress callback for UI
 * - Background thread export (non-blocking)
 */
class AudioExporter
{
public:
    //==========================================================================
    // Export Settings
    //==========================================================================

    struct ExportSettings
    {
        juce::File outputFile;                  // Output file path

        // Format
        juce::String format = "WAV";            // WAV, FLAC, OGG, MP3
        double sampleRate = 48000.0;            // Target sample rate
        int bitDepth = 24;                      // 16, 24, 32 (float if 32)
        int quality = 5;                        // OGG/MP3 quality (0-10)

        // Processing
        bool normalize = false;                 // Enable normalization
        float targetLUFS = -14.0f;              // Target loudness (Spotify: -14)
        bool dither = true;                     // Dither when reducing bit depth

        // Range
        bool exportFullProject = true;          // Export entire timeline
        int64_t startSample = 0;                // Start sample (if not full)
        int64_t endSample = 0;                  // End sample (if not full)

        // Metadata
        juce::String title;
        juce::String artist;
        juce::String album;
        int year = 0;
        juce::String genre;
        juce::String comment;
    };

    //==========================================================================
    // Progress Callback
    //==========================================================================

    using ProgressCallback = std::function<void(double progress, const juce::String& status)>;

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    AudioExporter();
    ~AudioExporter();

    //==========================================================================
    // Export Methods
    //==========================================================================

    /**
     * Export master mix (entire project or region)
     *
     * @param audioBuffer Source audio buffer to export
     * @param settings Export settings
     * @param progressCallback Optional progress callback (0.0 - 1.0)
     * @return true if export succeeded
     */
    bool exportMasterMix(const juce::AudioBuffer<float>& audioBuffer,
                        const ExportSettings& settings,
                        ProgressCallback progressCallback = nullptr);

    /**
     * Export audio buffer to file (low-level)
     *
     * @param audioBuffer Source audio
     * @param settings Export settings
     * @param progressCallback Progress callback
     * @return true if export succeeded
     */
    bool exportAudioToFile(const juce::AudioBuffer<float>& audioBuffer,
                          const ExportSettings& settings,
                          ProgressCallback progressCallback = nullptr);

    /**
     * Start background export (non-blocking)
     * Call waitForExportToFinish() or check isExporting()
     */
    void startBackgroundExport(const juce::AudioBuffer<float>& audioBuffer,
                              const ExportSettings& settings,
                              ProgressCallback progressCallback = nullptr);

    /**
     * Check if export is currently running
     */
    bool isExporting() const { return exporting.load(); }

    /**
     * Wait for background export to complete
     */
    void waitForExportToFinish();

    /**
     * Cancel ongoing export
     */
    void cancelExport();

    //==========================================================================
    // Utility Methods
    //==========================================================================

    /**
     * Get supported export formats
     */
    static juce::StringArray getSupportedFormats();

    /**
     * Get file extension for format
     */
    static juce::String getFileExtension(const juce::String& format);

    /**
     * Calculate LUFS loudness of buffer
     */
    static float calculateLUFS(const juce::AudioBuffer<float>& buffer, double sampleRate);

    /**
     * Normalize buffer to target LUFS
     */
    static void normalizeToLUFS(juce::AudioBuffer<float>& buffer,
                               double sampleRate,
                               float targetLUFS);

private:
    //==========================================================================
    // Internal Methods
    //==========================================================================

    bool exportToWAV(const juce::AudioBuffer<float>& buffer,
                    const ExportSettings& settings,
                    ProgressCallback callback);

    bool exportToFLAC(const juce::AudioBuffer<float>& buffer,
                     const ExportSettings& settings,
                     ProgressCallback callback);

    bool exportToOGG(const juce::AudioBuffer<float>& buffer,
                    const ExportSettings& settings,
                    ProgressCallback callback);

    juce::AudioBuffer<float> resampleBuffer(const juce::AudioBuffer<float>& input,
                                           double sourceSampleRate,
                                           double targetSampleRate);

    juce::AudioBuffer<float> convertBitDepth(const juce::AudioBuffer<float>& input,
                                            int targetBitDepth,
                                            bool useDither);

    void applyDither(juce::AudioBuffer<float>& buffer, int targetBitDepth);

    void setMetadata(juce::AudioFormatWriter* writer, const ExportSettings& settings);

    //==========================================================================
    // Background Export
    //==========================================================================

    void backgroundExportThread();

    std::unique_ptr<juce::Thread> exportThread;
    std::atomic<bool> exporting{false};
    std::atomic<bool> shouldCancel{false};

    juce::AudioBuffer<float> pendingBuffer;
    ExportSettings pendingSettings;
    ProgressCallback pendingCallback;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AudioExporter)
};
