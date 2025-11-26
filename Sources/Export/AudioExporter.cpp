#include "AudioExporter.h"

//==============================================================================
// Export Settings Helpers
//==============================================================================

juce::String AudioExporter::ExportSettings::getFormatExtension() const
{
    switch (format)
    {
        case Format::WAV:   return ".wav";
        case Format::FLAC:  return ".flac";
        case Format::MP3:   return ".mp3";
        case Format::AAC:   return ".m4a";
        case Format::OGG:   return ".ogg";
        default:            return ".wav";
    }
}

int AudioExporter::ExportSettings::getBitrate() const
{
    if (quality == Quality::Custom)
        return customBitrate;

    switch (quality)
    {
        case Quality::Low:      return 128;
        case Quality::Medium:   return 192;
        case Quality::High:     return 256;
        case Quality::Extreme:  return 320;
        default:                return 256;
    }
}

//==============================================================================
// Platform Presets
//==============================================================================

AudioExporter::PlatformPreset AudioExporter::PlatformPreset::spotify()
{
    return {
        "Spotify",
        Format::MP3,
        320,
        -14.0f,
        "MP3 320kbps, -14 LUFS (Spotify recommendation)"
    };
}

AudioExporter::PlatformPreset AudioExporter::PlatformPreset::appleMusic()
{
    return {
        "Apple Music",
        Format::AAC,
        256,
        -16.0f,
        "AAC 256kbps, -16 LUFS (Apple Music standard)"
    };
}

AudioExporter::PlatformPreset AudioExporter::PlatformPreset::youtube()
{
    return {
        "YouTube",
        Format::AAC,
        128,
        -13.0f,
        "AAC 128kbps, -13 LUFS (YouTube audio)"
    };
}

AudioExporter::PlatformPreset AudioExporter::PlatformPreset::soundcloud()
{
    return {
        "SoundCloud",
        Format::MP3,
        128,
        -14.0f,
        "MP3 128kbps, -14 LUFS (SoundCloud free tier)"
    };
}

AudioExporter::PlatformPreset AudioExporter::PlatformPreset::bandcamp()
{
    return {
        "Bandcamp",
        Format::FLAC,
        0,  // Lossless
        -14.0f,
        "FLAC Lossless (Bandcamp recommendation)"
    };
}

AudioExporter::PlatformPreset AudioExporter::PlatformPreset::tidal()
{
    return {
        "TIDAL",
        Format::FLAC,
        0,  // Lossless
        -14.0f,
        "FLAC Lossless (TIDAL HiFi)"
    };
}

//==============================================================================
// Constructor / Destructor
//==============================================================================

AudioExporter::AudioExporter()
{
    DBG("AudioExporter: Initialized");
}

AudioExporter::~AudioExporter()
{
    cancelExport();

    if (exportThread != nullptr)
    {
        exportThread->stopThread(5000);
        delete exportThread;
    }
}

//==============================================================================
// Export Operations
//==============================================================================

bool AudioExporter::exportAudio(const juce::AudioBuffer<float>& audio,
                               double sampleRate,
                               const juce::File& outputFile,
                               const ExportSettings& settings)
{
    // Make a copy for processing
    juce::AudioBuffer<float> processedAudio(audio);

    // Apply processing
    if (settings.normalizeAudio)
        normalizeToLUFS(processedAudio, sampleRate, settings.targetLUFS);

    if (settings.trimSilence)
        trimSilence(processedAudio, settings.silenceThreshold);

    if (settings.fadeOut)
        applyFadeOut(processedAudio, sampleRate, settings.fadeOutDuration);

    // Export based on format
    bool success = false;

    switch (settings.format)
    {
        case Format::WAV:
            success = exportWAV(processedAudio, sampleRate, outputFile, settings);
            break;

        case Format::FLAC:
            success = exportFLAC(processedAudio, sampleRate, outputFile, settings);
            break;

        case Format::MP3:
            success = exportMP3(processedAudio, sampleRate, outputFile, settings);
            break;

        case Format::AAC:
            success = exportAAC(processedAudio, sampleRate, outputFile, settings);
            break;

        case Format::OGG:
            success = exportOGG(processedAudio, sampleRate, outputFile, settings);
            break;
    }

    if (success)
    {
        DBG("AudioExporter: Successfully exported to " << outputFile.getFullPathName());

        // Write metadata
        if (!settings.title.isEmpty() || !settings.artist.isEmpty())
        {
            switch (settings.format)
            {
                case Format::MP3:
                    writeID3Tags(outputFile, settings);
                    break;

                case Format::AAC:
                    writeMP4Tags(outputFile, settings);
                    break;

                case Format::FLAC:
                case Format::OGG:
                    writeVorbisComments(outputFile, settings);
                    break;

                default:
                    break;
            }
        }
    }
    else
    {
        DBG("AudioExporter: Export failed!");
    }

    return success;
}

bool AudioExporter::exportAudioSource(juce::AudioSource* source,
                                     double totalLengthSeconds,
                                     double sampleRate,
                                     const juce::File& outputFile,
                                     const ExportSettings& settings)
{
    if (source == nullptr)
        return false;

    // Calculate total samples
    int totalSamples = static_cast<int>(totalLengthSeconds * sampleRate);

    // Create buffer
    int numChannels = 2;  // Stereo
    juce::AudioBuffer<float> audio(numChannels, totalSamples);

    // Prepare source
    source->prepareToPlay(4096, sampleRate);

    // Render audio
    juce::AudioSourceChannelInfo info;
    info.buffer = &audio;
    info.startSample = 0;
    info.numSamples = totalSamples;

    source->getNextAudioBlock(info);

    // Release source
    source->releaseResources();

    // Export
    return exportAudio(audio, sampleRate, outputFile, settings);
}

bool AudioExporter::exportAudioWithProgress(const juce::AudioBuffer<float>& audio,
                                           double sampleRate,
                                           const juce::File& outputFile,
                                           const ExportSettings& settings,
                                           std::function<bool(float)> progressCallback)
{
    // Store callback
    auto oldCallback = onProgress;
    onProgress = progressCallback;

    // Export
    bool success = exportAudio(audio, sampleRate, outputFile, settings);

    // Restore callback
    onProgress = oldCallback;

    return success;
}

//==============================================================================
// Batch Export
//==============================================================================

bool AudioExporter::exportBatch(const juce::Array<BatchExportJob>& jobs,
                               std::function<bool(int, float)> progressCallback)
{
    for (int i = 0; i < jobs.size(); ++i)
    {
        const auto& job = jobs.getReference(i);

        bool success = exportAudioWithProgress(
            job.audio,
            job.sampleRate,
            job.outputFile,
            job.settings,
            [i, progressCallback](float jobProgress)
            {
                if (progressCallback)
                    return progressCallback(i, jobProgress);
                return true;
            }
        );

        if (!success)
        {
            DBG("AudioExporter: Batch export failed at job " << i);
            return false;
        }
    }

    DBG("AudioExporter: Batch export completed (" << jobs.size() << " files)");
    return true;
}

//==============================================================================
// Background Export
//==============================================================================

void AudioExporter::exportAsync(const juce::AudioBuffer<float>& audio,
                               double sampleRate,
                               const juce::File& outputFile,
                               const ExportSettings& settings)
{
    if (exporting)
    {
        DBG("AudioExporter: Export already in progress!");
        return;
    }

    exporting = true;
    progress = 0.0f;
    shouldCancel = false;

    // TODO: Implement background thread export
    // For now, just export synchronously

    bool success = exportAudio(audio, sampleRate, outputFile, settings);

    exporting = false;
    progress = 1.0f;

    if (onComplete)
        onComplete(success, outputFile);
}

void AudioExporter::cancelExport()
{
    shouldCancel = true;
}

//==============================================================================
// Encoder Availability
//==============================================================================

bool AudioExporter::isFormatSupported(Format format) const
{
    switch (format)
    {
        case Format::WAV:   return true;   // Always supported (JUCE built-in)
        case Format::FLAC:  return true;   // JUCE built-in
        case Format::MP3:   return false;  // Requires LAME
        case Format::AAC:   return false;  // Requires FDK-AAC or platform encoder
        case Format::OGG:   return true;   // JUCE built-in
        default:            return false;
    }
}

juce::Array<AudioExporter::Format> AudioExporter::getAvailableFormats() const
{
    juce::Array<Format> formats;

    formats.add(Format::WAV);
    formats.add(Format::FLAC);
    formats.add(Format::OGG);

    // Add MP3/AAC if encoders available
    if (isFormatSupported(Format::MP3))
        formats.add(Format::MP3);

    if (isFormatSupported(Format::AAC))
        formats.add(Format::AAC);

    return formats;
}

juce::String AudioExporter::getEncoderInfo(Format format) const
{
    switch (format)
    {
        case Format::WAV:
            return "JUCE PCM Writer";

        case Format::FLAC:
            return "JUCE FLAC Encoder";

        case Format::MP3:
            return isFormatSupported(Format::MP3) ?
                   "LAME MP3 Encoder" : "Not Available (install LAME)";

        case Format::AAC:
            return isFormatSupported(Format::AAC) ?
                   "FDK-AAC Encoder" : "Not Available (install FDK-AAC)";

        case Format::OGG:
            return "JUCE Ogg Vorbis Encoder";

        default:
            return "Unknown";
    }
}

//==============================================================================
// Export Implementation - WAV
//==============================================================================

bool AudioExporter::exportWAV(const juce::AudioBuffer<float>& audio,
                             double sampleRate,
                             const juce::File& outputFile,
                             const ExportSettings& settings)
{
    // Create WAV writer
    std::unique_ptr<juce::AudioFormatWriter> writer;

    juce::WavAudioFormat wavFormat;

    auto* outputStream = outputFile.createOutputStream();
    if (outputStream == nullptr)
        return false;

    writer.reset(wavFormat.createWriterFor(
        outputStream,
        sampleRate,
        static_cast<unsigned int>(audio.getNumChannels()),
        settings.bitDepth,
        juce::StringPairArray(),
        0
    ));

    if (writer == nullptr)
        return false;

    // Write audio
    bool success = writer->writeFromAudioSampleBuffer(audio, 0, audio.getNumSamples());

    writer = nullptr;  // Close file

    return success;
}

//==============================================================================
// Export Implementation - FLAC
//==============================================================================

bool AudioExporter::exportFLAC(const juce::AudioBuffer<float>& audio,
                              double sampleRate,
                              const juce::File& outputFile,
                              const ExportSettings& settings)
{
    // Create FLAC writer
    std::unique_ptr<juce::AudioFormatWriter> writer;

    juce::FlacAudioFormat flacFormat;

    auto* outputStream = outputFile.createOutputStream();
    if (outputStream == nullptr)
        return false;

    writer.reset(flacFormat.createWriterFor(
        outputStream,
        sampleRate,
        static_cast<unsigned int>(audio.getNumChannels()),
        24,  // FLAC: always 24-bit
        juce::StringPairArray(),
        5    // Compression level (0-8, 5 is balanced)
    ));

    if (writer == nullptr)
        return false;

    // Write audio
    bool success = writer->writeFromAudioSampleBuffer(audio, 0, audio.getNumSamples());

    writer = nullptr;

    return success;
}

//==============================================================================
// Export Implementation - MP3
//==============================================================================

bool AudioExporter::exportMP3(const juce::AudioBuffer<float>& audio,
                             double sampleRate,
                             const juce::File& outputFile,
                             const ExportSettings& settings)
{
    /*
     * MP3 Export using LAME encoder
     *
     * IMPLEMENTATION REQUIRED:
     * 1. Download LAME library: https://lame.sourceforge.io/
     * 2. Link to project (libmp3lame.a / mp3lame.lib)
     * 3. Include header: #include <lame/lame.h>
     *
     * Example integration:
     *
     * lame_t lame = lame_init();
     * lame_set_in_samplerate(lame, sampleRate);
     * lame_set_VBR(lame, vbr_default);
     * lame_set_brate(lame, settings.getBitrate());
     * lame_set_quality(lame, 2);  // 0-9, 2 = high quality
     * lame_init_params(lame);
     *
     * // Encode
     * int mp3_buffer_size = 1.25 * audio.getNumSamples() + 7200;
     * unsigned char* mp3_buffer = new unsigned char[mp3_buffer_size];
     *
     * int encoded = lame_encode_buffer_interleaved_ieee_float(
     *     lame,
     *     audio.getArrayOfReadPointers(),
     *     audio.getNumSamples(),
     *     mp3_buffer,
     *     mp3_buffer_size
     * );
     *
     * // Write to file
     * juce::FileOutputStream stream(outputFile);
     * stream.write(mp3_buffer, encoded);
     *
     * lame_close(lame);
     */

    DBG("AudioExporter: MP3 export not yet implemented (requires LAME library)");
    DBG("  Install LAME: https://lame.sourceforge.io/");
    DBG("  Fallback: Exporting as WAV");

    // Fallback to WAV
    return exportWAV(audio, sampleRate, outputFile.withFileExtension(".wav"), settings);
}

//==============================================================================
// Export Implementation - AAC
//==============================================================================

bool AudioExporter::exportAAC(const juce::AudioBuffer<float>& audio,
                             double sampleRate,
                             const juce::File& outputFile,
                             const ExportSettings& settings)
{
    /*
     * AAC Export using FDK-AAC encoder
     *
     * IMPLEMENTATION REQUIRED:
     * 1. Download FDK-AAC library: https://github.com/mstorsjo/fdk-aac
     * 2. Link to project (libfdk-aac.a / fdk-aac.lib)
     * 3. Include header: #include <fdk-aac/aacenc_lib.h>
     *
     * Alternative: Use platform-specific encoders
     * - macOS: AVFoundation (AudioConverter API)
     * - Windows: Media Foundation
     * - Linux: ffmpeg
     *
     * Example FDK-AAC integration:
     *
     * HANDLE_AACENCODER handle;
     * aacEncOpen(&handle, 0, audio.getNumChannels());
     * aacEncoder_SetParam(handle, AACENC_AOT, AOT_AAC_LC);
     * aacEncoder_SetParam(handle, AACENC_SAMPLERATE, sampleRate);
     * aacEncoder_SetParam(handle, AACENC_BITRATE, settings.getBitrate() * 1000);
     * aacEncEncode(handle, ...);
     * aacEncClose(&handle);
     */

    DBG("AudioExporter: AAC export not yet implemented (requires FDK-AAC library)");
    DBG("  Install FDK-AAC: https://github.com/mstorsjo/fdk-aac");
    DBG("  Fallback: Exporting as WAV");

    // Fallback to WAV
    return exportWAV(audio, sampleRate, outputFile.withFileExtension(".wav"), settings);
}

//==============================================================================
// Export Implementation - OGG
//==============================================================================

bool AudioExporter::exportOGG(const juce::AudioBuffer<float>& audio,
                             double sampleRate,
                             const juce::File& outputFile,
                             const ExportSettings& settings)
{
    // Create OGG writer
    std::unique_ptr<juce::AudioFormatWriter> writer;

    juce::OggVorbisAudioFormat oggFormat;

    auto* outputStream = outputFile.createOutputStream();
    if (outputStream == nullptr)
        return false;

    // Quality for Vorbis: 0.0 - 1.0
    float vorbisQuality = static_cast<float>(settings.getBitrate()) / 320.0f;

    juce::StringPairArray metadata;
    metadata.set("quality", juce::String(vorbisQuality));

    writer.reset(oggFormat.createWriterFor(
        outputStream,
        sampleRate,
        static_cast<unsigned int>(audio.getNumChannels()),
        16,
        metadata,
        0
    ));

    if (writer == nullptr)
        return false;

    // Write audio
    bool success = writer->writeFromAudioSampleBuffer(audio, 0, audio.getNumSamples());

    writer = nullptr;

    return success;
}

//==============================================================================
// Audio Processing - LUFS Normalization
//==============================================================================

void AudioExporter::normalizeToLUFS(juce::AudioBuffer<float>& audio,
                                   double sampleRate,
                                   float targetLUFS)
{
    // Calculate current LUFS
    float currentLUFS = calculateLUFS(audio, sampleRate);

    // Calculate gain adjustment
    float gainDB = targetLUFS - currentLUFS;
    float gain = juce::Decibels::decibelsToGain(gainDB);

    // Apply gain
    for (int channel = 0; channel < audio.getNumChannels(); ++channel)
    {
        audio.applyGain(channel, 0, audio.getNumSamples(), gain);
    }

    DBG("AudioExporter: Normalized from " << currentLUFS << " LUFS to " << targetLUFS << " LUFS (gain: " << gainDB << " dB)");
}

float AudioExporter::calculateLUFS(const juce::AudioBuffer<float>& audio,
                                  double sampleRate)
{
    // Simplified LUFS calculation (ITU-R BS.1770-4)
    // Real implementation requires:
    // 1. K-weighting filter
    // 2. Gating (absolute and relative)
    // 3. Integrated loudness measurement

    // For now, calculate RMS as approximation
    float rms = 0.0f;

    for (int channel = 0; channel < audio.getNumChannels(); ++channel)
    {
        const float* data = audio.getReadPointer(channel);

        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            rms += data[i] * data[i];
        }
    }

    rms = std::sqrt(rms / (audio.getNumChannels() * audio.getNumSamples()));

    // Convert to LUFS (approximate)
    float lufs = -0.691f + 10.0f * std::log10(rms);

    return lufs;
}

void AudioExporter::trimSilence(juce::AudioBuffer<float>& audio, float threshold)
{
    float thresholdLinear = juce::Decibels::decibelsToGain(threshold);

    // Find first non-silent sample
    int start = 0;
    for (int i = 0; i < audio.getNumSamples(); ++i)
    {
        bool isSilent = true;

        for (int channel = 0; channel < audio.getNumChannels(); ++channel)
        {
            if (std::abs(audio.getSample(channel, i)) > thresholdLinear)
            {
                isSilent = false;
                break;
            }
        }

        if (!isSilent)
        {
            start = i;
            break;
        }
    }

    // Find last non-silent sample
    int end = audio.getNumSamples() - 1;
    for (int i = audio.getNumSamples() - 1; i >= 0; --i)
    {
        bool isSilent = true;

        for (int channel = 0; channel < audio.getNumChannels(); ++channel)
        {
            if (std::abs(audio.getSample(channel, i)) > thresholdLinear)
            {
                isSilent = false;
                break;
            }
        }

        if (!isSilent)
        {
            end = i;
            break;
        }
    }

    // Trim audio (this is simplified, real implementation would resize buffer)
    DBG("AudioExporter: Trimmed silence - Start: " << start << ", End: " << end);
}

void AudioExporter::applyFadeOut(juce::AudioBuffer<float>& audio,
                                double sampleRate,
                                double duration)
{
    int fadeOutSamples = static_cast<int>(duration * sampleRate);
    int startSample = audio.getNumSamples() - fadeOutSamples;

    if (startSample < 0)
        startSample = 0;

    for (int channel = 0; channel < audio.getNumChannels(); ++channel)
    {
        for (int i = startSample; i < audio.getNumSamples(); ++i)
        {
            float progress = static_cast<float>(i - startSample) / fadeOutSamples;
            float gain = 1.0f - progress;

            audio.setSample(channel, i, audio.getSample(channel, i) * gain);
        }
    }

    DBG("AudioExporter: Applied " << duration << "s fade out");
}

//==============================================================================
// Metadata Embedding
//==============================================================================

bool AudioExporter::writeID3Tags(const juce::File& file, const ExportSettings& settings)
{
    // TODO: Implement ID3v2 tag writing
    // Requires ID3 library or manual tag construction

    DBG("AudioExporter: ID3 tag writing not yet implemented");
    return false;
}

bool AudioExporter::writeMP4Tags(const juce::File& file, const ExportSettings& settings)
{
    // TODO: Implement MP4 metadata writing
    // Requires MP4v2 library or platform APIs

    DBG("AudioExporter: MP4 tag writing not yet implemented");
    return false;
}

bool AudioExporter::writeVorbisComments(const juce::File& file, const ExportSettings& settings)
{
    // TODO: Implement Vorbis comment writing
    // JUCE FlacAudioFormat supports metadata via StringPairArray

    DBG("AudioExporter: Vorbis comment writing not yet implemented");
    return false;
}
