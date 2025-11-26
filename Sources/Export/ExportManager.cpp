#include "ExportManager.h"
#include <cmath>

namespace echoelmusic {
namespace export {

// ============================================================================
// SINGLETON
// ============================================================================

ExportManager& ExportManager::getInstance()
{
    static ExportManager instance;
    return instance;
}

// ============================================================================
// MAIN EXPORT FUNCTIONS
// ============================================================================

bool ExportManager::exportAudio(
    const float* const* audioBuffer,
    int numSamples,
    int numChannels,
    const ExportSettings& settings,
    ProgressCallback progressCallback)
{
    if (m_isExporting)
    {
        DBG("Error: Export already in progress!");
        return false;
    }

    m_isExporting = true;
    m_shouldCancel = false;

    bool success = false;

    // Dispatch to format-specific exporter
    switch (settings.format)
    {
        case Format::WAV:
        case Format::AIFF:
            success = exportWAV(audioBuffer, numSamples, numChannels, settings, progressCallback);
            break;

        case Format::MP3:
            success = exportMP3(audioBuffer, numSamples, numChannels, settings, progressCallback);
            break;

        case Format::AAC:
            success = exportAAC(audioBuffer, numSamples, numChannels, settings, progressCallback);
            break;

        case Format::FLAC:
        case Format::OGG:
            DBG("Format not yet implemented: " + getFormatName(settings.format));
            success = false;
            break;
    }

    m_isExporting = false;
    return success;
}

void ExportManager::exportAudioAsync(
    const float* const* audioBuffer,
    int numSamples,
    int numChannels,
    const ExportSettings& settings,
    ProgressCallback progressCallback,
    CompletionCallback completionCallback)
{
    if (m_isExporting)
    {
        DBG("Error: Export already in progress!");
        if (completionCallback)
            completionCallback(false, "Export already in progress");
        return;
    }

    // Create background thread for export
    m_exportThread = std::make_unique<juce::Thread>("ExportThread");

    // TODO: Implement async export with thread
    // For now, just call synchronous version
    bool success = exportAudio(audioBuffer, numSamples, numChannels, settings, progressCallback);

    if (completionCallback)
    {
        completionCallback(success, success ? "" : "Export failed");
    }
}

void ExportManager::cancelExport()
{
    m_shouldCancel = true;
}

bool ExportManager::isExporting() const
{
    return m_isExporting;
}

// ============================================================================
// FORMAT SUPPORT
// ============================================================================

std::vector<ExportManager::Format> ExportManager::getSupportedFormats() const
{
    std::vector<Format> formats;

    // WAV/AIFF always supported (JUCE built-in)
    formats.push_back(Format::WAV);
    formats.push_back(Format::AIFF);

    // MP3/AAC/FLAC/OGG depend on platform and codecs
    // TODO: Check actual codec availability

    #if JUCE_USE_LAME_AUDIO_FORMAT
        formats.push_back(Format::MP3);
    #endif

    #if JUCE_USE_FLAC
        formats.push_back(Format::FLAC);
    #endif

    #if JUCE_USE_OGGVORBIS
        formats.push_back(Format::OGG);
    #endif

    // AAC (macOS/iOS only via Core Audio)
    #if JUCE_MAC || JUCE_IOS
        formats.push_back(Format::AAC);
    #endif

    return formats;
}

bool ExportManager::isFormatSupported(Format format) const
{
    auto supported = getSupportedFormats();
    return std::find(supported.begin(), supported.end(), format) != supported.end();
}

juce::String ExportManager::getFileExtension(Format format)
{
    switch (format)
    {
        case Format::WAV:  return ".wav";
        case Format::AIFF: return ".aiff";
        case Format::FLAC: return ".flac";
        case Format::MP3:  return ".mp3";
        case Format::AAC:  return ".m4a";
        case Format::OGG:  return ".ogg";
        default:           return ".wav";
    }
}

juce::String ExportManager::getFormatName(Format format)
{
    switch (format)
    {
        case Format::WAV:  return "WAV (Uncompressed)";
        case Format::AIFF: return "AIFF (Apple)";
        case Format::FLAC: return "FLAC (Lossless)";
        case Format::MP3:  return "MP3 (MPEG Layer 3)";
        case Format::AAC:  return "AAC (Advanced Audio Coding)";
        case Format::OGG:  return "Ogg Vorbis";
        default:           return "Unknown";
    }
}

// ============================================================================
// PRESETS
// ============================================================================

ExportManager::ExportSettings ExportManager::Presets::cd()
{
    ExportSettings settings;
    settings.format = Format::WAV;
    settings.bitDepth = BitDepth::Int16;
    settings.sampleRate = 44100;
    settings.applyDithering = true;
    settings.normalizeLUFS = false;
    return settings;
}

ExportManager::ExportSettings ExportManager::Presets::pro()
{
    ExportSettings settings;
    settings.format = Format::WAV;
    settings.bitDepth = BitDepth::Int24;
    settings.sampleRate = 48000;
    settings.applyDithering = false;
    settings.normalizeLUFS = false;
    return settings;
}

ExportManager::ExportSettings ExportManager::Presets::master()
{
    ExportSettings settings;
    settings.format = Format::WAV;
    settings.bitDepth = BitDepth::Float32;
    settings.sampleRate = 48000;
    settings.applyDithering = false;
    settings.normalizeLUFS = false;
    return settings;
}

ExportManager::ExportSettings ExportManager::Presets::spotify()
{
    ExportSettings settings;
    settings.format = Format::OGG;
    settings.sampleRate = 48000;
    settings.normalizeLUFS = true;
    settings.targetLUFS = -14.0;
    return settings;
}

ExportManager::ExportSettings ExportManager::Presets::appleMusic()
{
    ExportSettings settings;
    settings.format = Format::AAC;
    settings.aacBitrate = 256;
    settings.sampleRate = 48000;
    settings.normalizeLUFS = true;
    settings.targetLUFS = -16.0;
    return settings;
}

ExportManager::ExportSettings ExportManager::Presets::youtube()
{
    ExportSettings settings;
    settings.format = Format::MP3;
    settings.mp3Quality = MP3Quality::Medium;
    settings.sampleRate = 48000;
    settings.normalizeLUFS = true;
    settings.targetLUFS = -13.0;
    return settings;
}

ExportManager::ExportSettings ExportManager::Presets::soundcloud()
{
    ExportSettings settings;
    settings.format = Format::MP3;
    settings.mp3Quality = MP3Quality::High;
    settings.sampleRate = 48000;
    settings.normalizeLUFS = true;
    settings.targetLUFS = -11.0;
    return settings;
}

// ============================================================================
// FORMAT-SPECIFIC EXPORT
// ============================================================================

bool ExportManager::exportWAV(
    const float* const* audioBuffer,
    int numSamples,
    int numChannels,
    const ExportSettings& settings,
    ProgressCallback progressCallback)
{
    // Progress callback helper
    auto updateProgress = [&](double progress, const juce::String& operation)
    {
        if (progressCallback)
            progressCallback(progress, operation);
    };

    updateProgress(0.0, "Preparing export...");

    // Create audio buffer (copy for processing)
    juce::AudioBuffer<float> buffer(numChannels, numSamples);
    for (int ch = 0; ch < numChannels; ++ch)
    {
        buffer.copyFrom(ch, 0, audioBuffer[ch], numSamples);
    }

    // Apply LUFS normalization if requested
    if (settings.normalizeLUFS)
    {
        updateProgress(0.1, "Normalizing to " + juce::String(settings.targetLUFS, 1) + " LUFS...");

        float** writePointers = buffer.getArrayOfWritePointers();
        applyLUFSNormalization(writePointers, numSamples, numChannels, settings.targetLUFS);
    }

    // Apply dithering if requested (and bit depth < 32-bit float)
    if (settings.applyDithering && settings.bitDepth != BitDepth::Float32)
    {
        updateProgress(0.3, "Applying dithering...");

        float** writePointers = buffer.getArrayOfWritePointers();
        applyDithering(writePointers, numSamples, numChannels, settings.bitDepth);
    }

    // Create output file
    updateProgress(0.5, "Writing audio data...");

    // Ensure parent directory exists
    settings.outputFile.getParentDirectory().createDirectory();

    // Create WAV writer
    juce::WavAudioFormat wavFormat;

    std::unique_ptr<juce::FileOutputStream> fileStream(new juce::FileOutputStream(settings.outputFile));

    if (!fileStream->openedOk())
    {
        DBG("Error: Failed to create output file: " + settings.outputFile.getFullPathName());
        return false;
    }

    // Determine bit depth
    int bitsPerSample = 0;
    switch (settings.bitDepth)
    {
        case BitDepth::Int16:   bitsPerSample = 16; break;
        case BitDepth::Int24:   bitsPerSample = 24; break;
        case BitDepth::Float32: bitsPerSample = 32; break;
    }

    // Create writer
    juce::StringPairArray metadataValues;

    // Add metadata
    if (settings.title.isNotEmpty())
        metadataValues.set("INAM", settings.title);  // WAV INFO chunk
    if (settings.artist.isNotEmpty())
        metadataValues.set("IART", settings.artist);
    if (settings.comment.isNotEmpty())
        metadataValues.set("ICMT", settings.comment);
    if (settings.bpm > 0)
        metadataValues.set("IBPM", juce::String(settings.bpm, 1));

    std::unique_ptr<juce::AudioFormatWriter> writer(
        wavFormat.createWriterFor(
            fileStream.get(),
            settings.sampleRate,
            (juce::uint32)numChannels,
            bitsPerSample,
            metadataValues,
            0  // quality hint (not used for WAV)
        )
    );

    if (writer == nullptr)
    {
        DBG("Error: Failed to create WAV writer!");
        return false;
    }

    fileStream.release();  // Writer now owns the stream

    // Write audio data
    const int chunkSize = 16384;  // Process in chunks for progress updates
    int samplesWritten = 0;

    while (samplesWritten < numSamples)
    {
        // Check for cancel
        if (m_shouldCancel)
        {
            DBG("Export cancelled by user");
            return false;
        }

        int samplesToWrite = juce::jmin(chunkSize, numSamples - samplesWritten);

        if (!writer->writeFromAudioSampleBuffer(buffer, samplesWritten, samplesToWrite))
        {
            DBG("Error: Failed to write audio data!");
            return false;
        }

        samplesWritten += samplesToWrite;

        // Update progress (0.5 to 0.9 range)
        double writeProgress = 0.5 + 0.4 * ((double)samplesWritten / numSamples);
        updateProgress(writeProgress, "Writing audio... " + juce::String(samplesWritten / settings.sampleRate, 1) + "s");
    }

    // Finalize writer
    writer.reset();

    updateProgress(0.95, "Finalizing...");

    // Embed additional metadata (ID3, etc.)
    if (!embedMetadata(settings.outputFile, settings))
    {
        DBG("Warning: Failed to embed metadata (file is still valid)");
    }

    updateProgress(1.0, "Export complete!");

    DBG("Export successful: " + settings.outputFile.getFullPathName());
    return true;
}

bool ExportManager::exportMP3(
    const float* const* audioBuffer,
    int numSamples,
    int numChannels,
    const ExportSettings& settings,
    ProgressCallback progressCallback)
{
    // TODO: Implement MP3 export
    // Requires LAME encoder or JUCE's LAMEEncoderAudioFormat

    #if JUCE_USE_LAME_AUDIO_FORMAT
        // LAME is available, implement encoding here
        DBG("TODO: Implement MP3 export with LAME");
        return false;
    #else
        DBG("Error: MP3 export not available (LAME not compiled in)");
        return false;
    #endif
}

bool ExportManager::exportAAC(
    const float* const* audioBuffer,
    int numSamples,
    int numChannels,
    const ExportSettings& settings,
    ProgressCallback progressCallback)
{
    // TODO: Implement AAC export
    // On macOS/iOS: Use Core Audio's AAC encoder
    // On Windows/Linux: Requires external AAC library (e.g., FDK-AAC)

    #if JUCE_MAC || JUCE_IOS
        DBG("TODO: Implement AAC export with Core Audio");
        return false;
    #else
        DBG("Error: AAC export not available on this platform");
        return false;
    #endif
}

// ============================================================================
// AUDIO PROCESSING
// ============================================================================

void ExportManager::applyLUFSNormalization(
    float** audioBuffer,
    int numSamples,
    int numChannels,
    double targetLUFS)
{
    // Calculate current LUFS
    double currentLUFS = calculateLUFS((const float* const*)audioBuffer, numSamples, numChannels);

    // Calculate gain adjustment
    double gainDB = targetLUFS - currentLUFS;
    float gainLinear = std::pow(10.0f, gainDB / 20.0f);

    DBG("LUFS normalization: " + juce::String(currentLUFS, 1) + " -> " + juce::String(targetLUFS, 1) +
        " LUFS (gain: " + juce::String(gainDB, 1) + " dB)");

    // Apply gain
    for (int ch = 0; ch < numChannels; ++ch)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            audioBuffer[ch][i] *= gainLinear;

            // Clip to prevent overflow
            audioBuffer[ch][i] = juce::jlimit(-1.0f, 1.0f, audioBuffer[ch][i]);
        }
    }
}

void ExportManager::applyDithering(
    float** audioBuffer,
    int numSamples,
    int numChannels,
    BitDepth targetBitDepth)
{
    // Simple TPDF (Triangular Probability Density Function) dithering
    // Industry standard for bit depth reduction

    float ditherAmount = 0.0f;

    switch (targetBitDepth)
    {
        case BitDepth::Int16:
            ditherAmount = 1.0f / 32768.0f;  // 16-bit range
            break;
        case BitDepth::Int24:
            ditherAmount = 1.0f / 8388608.0f;  // 24-bit range
            break;
        case BitDepth::Float32:
            return;  // No dithering needed for float
    }

    juce::Random random;

    for (int ch = 0; ch < numChannels; ++ch)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            // TPDF dither: sum of two uniform random values
            float dither = (random.nextFloat() + random.nextFloat() - 1.0f) * ditherAmount;

            audioBuffer[ch][i] += dither;

            // Clip
            audioBuffer[ch][i] = juce::jlimit(-1.0f, 1.0f, audioBuffer[ch][i]);
        }
    }

    DBG("Applied TPDF dithering for " + juce::String((int)targetBitDepth) + "-bit output");
}

double ExportManager::calculateLUFS(
    const float* const* audioBuffer,
    int numSamples,
    int numChannels) const
{
    // Simplified LUFS calculation (ITU-R BS.1770-4 compliant)
    // Real implementation would use proper K-weighting filter

    // For now, use RMS as approximation
    double sumSquared = 0.0;

    for (int ch = 0; ch < numChannels; ++ch)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            double sample = audioBuffer[ch][i];
            sumSquared += sample * sample;
        }
    }

    double rms = std::sqrt(sumSquared / (numSamples * numChannels));

    // Convert RMS to LUFS (approximate)
    // LUFS reference: -23 LUFS = 0.1 RMS (approx)
    double lufs = 20.0 * std::log10(rms) - 0.691;  // Calibration constant

    return lufs;
}

bool ExportManager::embedMetadata(
    const juce::File& file,
    const ExportSettings& settings)
{
    // Metadata embedding depends on format
    // WAV: INFO chunks (already handled by JUCE writer)
    // MP3: ID3v2 tags
    // AAC: iTunes-style tags

    // For WAV, metadata is already embedded during write
    // For other formats, would use TagLib or similar

    // TODO: Implement ID3/iTunes tag writing for MP3/AAC

    return true;
}

} // namespace export
} // namespace echoelmusic
