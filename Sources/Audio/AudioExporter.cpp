#include "AudioExporter.h"
#include <cmath>

//==============================================================================
AudioExporter::AudioExporter()
{
}

AudioExporter::~AudioExporter()
{
    if (exportThread != nullptr)
    {
        cancelExport();
        waitForExportToFinish();
    }
}

//==============================================================================
bool AudioExporter::exportAudioToFile(const juce::AudioBuffer<float>& audioBuffer,
                                     const ExportSettings& settings,
                                     ProgressCallback progressCallback)
{
    if (audioBuffer.getNumChannels() == 0 || audioBuffer.getNumSamples() == 0)
        return false;

    // Determine export method based on format
    juce::String fmt = settings.format.toUpperCase();

    if (fmt == "WAV")
        return exportToWAV(audioBuffer, settings, progressCallback);
    else if (fmt == "FLAC")
        return exportToFLAC(audioBuffer, settings, progressCallback);
    else if (fmt == "OGG")
        return exportToOGG(audioBuffer, settings, progressCallback);

    // Unsupported format
    return false;
}

bool AudioExporter::exportMasterMix(const juce::AudioBuffer<float>& audioBuffer,
                                   const ExportSettings& settings,
                                   ProgressCallback progressCallback)
{
    auto buffer = audioBuffer;

    // Apply normalization if requested
    if (settings.normalize)
    {
        if (progressCallback)
            progressCallback(0.1, "Analyzing loudness...");

        normalizeToLUFS(buffer, settings.sampleRate, settings.targetLUFS);
    }

    if (progressCallback)
        progressCallback(0.2, "Exporting audio...");

    return exportAudioToFile(buffer, settings, progressCallback);
}

//==============================================================================
bool AudioExporter::exportToWAV(const juce::AudioBuffer<float>& buffer,
                               const ExportSettings& settings,
                               ProgressCallback callback)
{
    juce::WavAudioFormat wavFormat;

    auto outputStream = settings.outputFile.createOutputStream();
    if (outputStream == nullptr)
        return false;

    // Determine bit format
    int bitsPerSample = settings.bitDepth;
    unsigned int qualityFlags = 0;

    // For 32-bit, JUCE defaults to float
    std::unique_ptr<juce::AudioFormatWriter> writer(
        wavFormat.createWriterFor(outputStream.release(),
                                 settings.sampleRate,
                                 buffer.getNumChannels(),
                                 bitsPerSample,
                                 {},  // metadata
                                 qualityFlags));

    if (writer == nullptr)
        return false;

    // Set metadata
    setMetadata(writer.get(), settings);

    // Write audio
    const int blockSize = 4096;
    const int numSamples = buffer.getNumSamples();

    for (int startSample = 0; startSample < numSamples; startSample += blockSize)
    {
        int numToWrite = juce::jmin(blockSize, numSamples - startSample);

        // Write from audio buffer
        if (!writer->writeFromAudioSampleBuffer(buffer, startSample, numToWrite))
            return false;

        if (callback)
        {
            double progress = 0.2 + 0.8 * (static_cast<double>(startSample + numToWrite) / numSamples);
            callback(progress, "Writing audio data...");
        }
    }

    if (callback)
        callback(1.0, "Export complete!");

    return true;
}

bool AudioExporter::exportToFLAC(const juce::AudioBuffer<float>& buffer,
                                const ExportSettings& settings,
                                ProgressCallback callback)
{
    juce::FlacAudioFormat flacFormat;

    auto outputStream = settings.outputFile.createOutputStream();
    if (outputStream == nullptr)
        return false;

    std::unique_ptr<juce::AudioFormatWriter> writer(
        flacFormat.createWriterFor(outputStream.release(),
                                  settings.sampleRate,
                                  buffer.getNumChannels(),
                                  settings.bitDepth,
                                  {},  // metadata
                                  settings.quality));

    if (writer == nullptr)
        return false;

    setMetadata(writer.get(), settings);

    // Write audio
    const int blockSize = 4096;
    const int numSamples = buffer.getNumSamples();

    for (int startSample = 0; startSample < numSamples; startSample += blockSize)
    {
        int numToWrite = juce::jmin(blockSize, numSamples - startSample);

        if (!writer->writeFromAudioSampleBuffer(buffer, startSample, numToWrite))
            return false;

        if (callback)
        {
            double progress = 0.2 + 0.8 * (static_cast<double>(startSample + numToWrite) / numSamples);
            callback(progress, "Writing FLAC data...");
        }
    }

    if (callback)
        callback(1.0, "FLAC export complete!");

    return true;
}

bool AudioExporter::exportToOGG(const juce::AudioBuffer<float>& buffer,
                               const ExportSettings& settings,
                               ProgressCallback callback)
{
    juce::OggVorbisAudioFormat oggFormat;

    auto outputStream = settings.outputFile.createOutputStream();
    if (outputStream == nullptr)
        return false;

    // Quality: 0 (low) to 10 (high)
    int qualityIndex = juce::jlimit(0, 10, settings.quality);

    std::unique_ptr<juce::AudioFormatWriter> writer(
        oggFormat.createWriterFor(outputStream.release(),
                                 settings.sampleRate,
                                 buffer.getNumChannels(),
                                 settings.bitDepth,
                                 {},  // metadata
                                 qualityIndex));

    if (writer == nullptr)
        return false;

    setMetadata(writer.get(), settings);

    // Write audio
    const int blockSize = 4096;
    const int numSamples = buffer.getNumSamples();

    for (int startSample = 0; startSample < numSamples; startSample += blockSize)
    {
        int numToWrite = juce::jmin(blockSize, numSamples - startSample);

        if (!writer->writeFromAudioSampleBuffer(buffer, startSample, numToWrite))
            return false;

        if (callback)
        {
            double progress = 0.2 + 0.8 * (static_cast<double>(startSample + numToWrite) / numSamples);
            callback(progress, "Writing OGG data...");
        }
    }

    if (callback)
        callback(1.0, "OGG export complete!");

    return true;
}

//==============================================================================
void AudioExporter::setMetadata(juce::AudioFormatWriter* writer, const ExportSettings& settings)
{
    if (writer == nullptr)
        return;

    // Metadata is typically set during writer creation
    // For JUCE 7, metadata should be passed in createWriterFor()
    // This function is kept for future enhancement
    (void)settings;  // Unused parameter warning suppression
}

//==============================================================================
float AudioExporter::calculateLUFS(const juce::AudioBuffer<float>& buffer, double sampleRate)
{
    // Simplified LUFS calculation (ITU-R BS.1770)
    // For production, use a proper LUFS library

    if (buffer.getNumSamples() == 0)
        return -100.0f;

    // RMS calculation (simplified)
    float sumSquares = 0.0f;
    int totalSamples = 0;

    for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
    {
        const float* channelData = buffer.getReadPointer(ch);

        for (int i = 0; i < buffer.getNumSamples(); ++i)
        {
            float sample = channelData[i];
            sumSquares += sample * sample;
            totalSamples++;
        }
    }

    float rms = std::sqrt(sumSquares / totalSamples);

    // Convert to LUFS (approximation)
    // LUFS = 20 * log10(RMS) - 0.691
    float lufs = 20.0f * std::log10(rms + 1e-10f) - 0.691f;

    return lufs;
}

void AudioExporter::normalizeToLUFS(juce::AudioBuffer<float>& buffer,
                                   double sampleRate,
                                   float targetLUFS)
{
    float currentLUFS = calculateLUFS(buffer, sampleRate);

    // Calculate gain needed
    float gainDB = targetLUFS - currentLUFS;
    float gainLinear = std::pow(10.0f, gainDB / 20.0f);

    // Apply gain
    buffer.applyGain(gainLinear);
}

//==============================================================================
juce::StringArray AudioExporter::getSupportedFormats()
{
    return {"WAV", "FLAC", "OGG"};
}

juce::String AudioExporter::getFileExtension(const juce::String& format)
{
    juce::String fmt = format.toUpperCase();

    if (fmt == "WAV")
        return ".wav";
    else if (fmt == "FLAC")
        return ".flac";
    else if (fmt == "OGG")
        return ".ogg";

    return ".wav";  // Default
}

//==============================================================================
void AudioExporter::startBackgroundExport(const juce::AudioBuffer<float>& audioBuffer,
                                         const ExportSettings& settings,
                                         ProgressCallback progressCallback)
{
    // Launch background export thread
    exportThread = std::thread([this, audioBuffer, settings, progressCallback]() {
        shouldCancel.store(false);

        // Report start
        if (progressCallback) progressCallback(0.0f, "Starting export...");

        // Calculate total samples
        const int totalSamples = audioBuffer.getNumSamples();
        const int blockSize = 8192;
        int processedSamples = 0;

        // Process in blocks
        while (processedSamples < totalSamples && !shouldCancel.load()) {
            int samplesToProcess = std::min(blockSize, totalSamples - processedSamples);

            // Export block (actual encoding happens in derived methods)
            exportBlock(audioBuffer, processedSamples, samplesToProcess, settings);

            processedSamples += samplesToProcess;

            // Report progress
            float progress = static_cast<float>(processedSamples) / static_cast<float>(totalSamples);
            if (progressCallback) {
                progressCallback(progress, "Exporting... " + std::to_string(static_cast<int>(progress * 100)) + "%");
            }
        }

        // Report completion
        if (progressCallback) {
            if (shouldCancel.load()) {
                progressCallback(1.0f, "Export cancelled");
            } else {
                progressCallback(1.0f, "Export complete");
            }
        }
    });
}

void AudioExporter::backgroundExportThread()
{
    // Not used in current implementation
}

void AudioExporter::waitForExportToFinish()
{
    // No-op for synchronous export
}

void AudioExporter::cancelExport()
{
    shouldCancel.store(true);
}
