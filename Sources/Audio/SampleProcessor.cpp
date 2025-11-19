#include "SampleProcessor.h"
#include <cmath>

//==============================================================================
// Echoelmusic Signature Sound Presets
//==============================================================================

SampleProcessor::ProcessingSettings SampleProcessor::ProcessingSettings::fromPreset(TransformPreset preset)
{
    ProcessingSettings settings;

    switch (preset)
    {
        case TransformPreset::DarkDeep:
            // Dark Techno: Pitch down, reverb, saturation
            settings.pitchShiftSemitones = -4.0f;  // Lower by 4 semitones
            settings.lowPassCutoff = 8000.0f;      // Dark filter
            settings.reverb = 0.3f;                // Deep space
            settings.saturation = 0.4f;            // Analog warmth
            settings.stereoWidth = 0.8f;           // Slightly narrow
            break;

        case TransformPreset::BrightCrispy:
            // Modern House: Pitch up, EQ boost, compression
            settings.pitchShiftSemitones = 2.0f;   // Brighter
            settings.highPassCutoff = 100.0f;      // Remove mud
            settings.compression = 0.6f;           // Punchy
            settings.saturation = 0.2f;            // Slight edge
            settings.stereoWidth = 1.3f;           // Wide
            break;

        case TransformPreset::VintageWarm:
            // Lo-Fi: Tape saturation, bit crush, vinyl
            settings.pitchShiftSemitones = -1.0f;  // Slightly lower
            settings.tapeSaturation = 0.6f;        // Vintage tape
            settings.bitCrush = 0.3f;              // Lo-fi character
            settings.vinylNoise = 0.2f;            // Crackle
            settings.compression = 0.4f;           // Glue
            break;

        case TransformPreset::GlitchyModern:
            // Experimental: Stutter, grain, modulation
            settings.stutter = 0.4f;               // Glitch effects
            settings.granular = 0.5f;              // Grain texture
            settings.chorus = 0.3f;                // Movement
            settings.phaser = 0.2f;                // Sweep
            settings.randomizationAmount = 0.7f;   // High variation
            break;

        case TransformPreset::SubBass:
            // Bass Heavy: Extreme low-pass, sub boost
            settings.pitchShiftSemitones = -12.0f; // Octave down
            settings.lowPassCutoff = 200.0f;       // Only lows
            settings.saturation = 0.6f;            // Harmonic richness
            settings.compression = 0.8f;           // Solid
            settings.stereoWidth = 0.5f;           // Mono-ish
            break;

        case TransformPreset::AiryEthereal:
            // Ambient: High-pass, reverb, chorus
            settings.pitchShiftSemitones = 7.0f;   // 5th up
            settings.highPassCutoff = 500.0f;      // Airy
            settings.reverb = 0.7f;                // Huge space
            settings.chorus = 0.4f;                // Shimmer
            settings.stereoWidth = 1.8f;           // Very wide
            break;

        case TransformPreset::AggressivePunchy:
            // Hard Techno: Transient boost, distortion
            settings.compression = 0.9f;           // Smashed
            settings.saturation = 0.8f;            // Driven
            settings.lowPassCutoff = 12000.0f;     // Controlled highs
            settings.stereoWidth = 1.0f;           // Focused
            break;

        case TransformPreset::RetroVaporwave:
            // Vaporwave: Pitch shift, chorus, delay
            settings.pitchShiftSemitones = -3.0f;  // Slowed down
            settings.timeStretchRatio = 0.8f;      // Even slower
            settings.chorus = 0.6f;                // Lush
            settings.delay = 0.4f;                 // Spacey
            settings.reverb = 0.5f;                // Dreamy
            break;

        case TransformPreset::RandomLight:
            settings.randomizationAmount = 0.2f;   // 10-30% variation
            break;

        case TransformPreset::RandomMedium:
            settings.randomizationAmount = 0.5f;   // 30-60% variation
            break;

        case TransformPreset::RandomHeavy:
            settings.randomizationAmount = 0.9f;   // 60-100% variation
            break;

        case TransformPreset::Custom:
        default:
            // User-defined (no changes)
            break;
    }

    return settings;
}

//==============================================================================
// Constructor / Destructor
//==============================================================================

SampleProcessor::SampleProcessor()
{
    random.setSeedRandomly();
    DBG("SampleProcessor: Initialized");
}

SampleProcessor::~SampleProcessor()
{
    cancelBatch();
}

//==============================================================================
// Single Sample Processing
//==============================================================================

SampleProcessor::ProcessingResult SampleProcessor::processSample(
    const juce::File& inputFile,
    const juce::File& outputFile,
    const ProcessingSettings& settings)
{
    ProcessingResult result;
    result.outputFile = outputFile;

    // Load audio file
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    auto* reader = formatManager.createReaderFor(inputFile);

    if (reader == nullptr)
    {
        result.errorMessage = "Failed to read input file";
        return result;
    }

    // Read into buffer
    juce::AudioBuffer<float> buffer(static_cast<int>(reader->numChannels),
                                   static_cast<int>(reader->lengthInSamples));
    reader->read(&buffer, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

    double sampleRate = reader->sampleRate;
    delete reader;

    // Detect original properties
    result.originalBPM = 0.0;  // TODO: Implement BPM detection
    result.originalKey = "";   // TODO: Implement key detection

    // Process audio
    auto processedBuffer = processSample(buffer, sampleRate, settings);

    // Detect processed properties
    result.processedBPM = 0.0;  // TODO: Implement BPM detection
    result.processedKey = "";   // TODO: Implement key detection

    // Auto-categorize
    result.category = detectCategory(processedBuffer, sampleRate);
    result.subcategory = detectSubcategory(processedBuffer, result.category);
    result.tags = generateTags(processedBuffer, settings);

    // Write output file
    juce::WavAudioFormat wavFormat;
    auto* outputStream = outputFile.createOutputStream();

    if (outputStream == nullptr)
    {
        result.errorMessage = "Failed to create output file";
        return result;
    }

    std::unique_ptr<juce::AudioFormatWriter> writer(
        wavFormat.createWriterFor(outputStream, sampleRate, processedBuffer.getNumChannels(), 24, {}, 0)
    );

    if (writer != nullptr)
    {
        writer->writeFromAudioSampleBuffer(processedBuffer, 0, processedBuffer.getNumSamples());
        result.success = true;
    }
    else
    {
        result.errorMessage = "Failed to write output file";
        delete outputStream;
    }

    return result;
}

SampleProcessor::ProcessingResult SampleProcessor::processSample(
    const juce::File& inputFile,
    const juce::File& outputFile,
    TransformPreset preset)
{
    auto settings = ProcessingSettings::fromPreset(preset);
    return processSample(inputFile, outputFile, settings);
}

juce::AudioBuffer<float> SampleProcessor::processSample(
    const juce::AudioBuffer<float>& input,
    double sampleRate,
    const ProcessingSettings& settings)
{
    // Create working buffer
    juce::AudioBuffer<float> output(input);

    // Apply randomization if needed
    ProcessingSettings finalSettings = settings;
    if (finalSettings.randomizationAmount > 0.0f)
    {
        randomizeSettings(finalSettings, finalSettings.randomizationAmount, finalSettings.randomSeed);
    }

    // Apply transformations in optimal order

    // 1. Pitch shift (before other processing)
    if (finalSettings.pitchShiftSemitones != 0.0f)
        applyPitchShift(output, finalSettings.pitchShiftSemitones, sampleRate);

    // 2. Time stretch
    if (finalSettings.timeStretchRatio != 1.0f)
        applyTimeStretch(output, finalSettings.timeStretchRatio, sampleRate);

    // 3. Filtering
    applyFilter(output, finalSettings.lowPassCutoff, finalSettings.highPassCutoff, sampleRate);

    // 4. Dynamics
    if (finalSettings.compression > 0.0f)
        applyCompression(output, finalSettings.compression);

    if (finalSettings.saturation > 0.0f)
        applySaturation(output, finalSettings.saturation);

    // 5. Character
    if (finalSettings.bitCrush > 0.0f)
        applyBitCrush(output, finalSettings.bitCrush);

    if (finalSettings.vinylNoise > 0.0f)
        applyVinylNoise(output, finalSettings.vinylNoise);

    // 6. Modulation
    if (finalSettings.chorus > 0.0f)
        applyChorus(output, finalSettings.chorus, sampleRate);

    // 7. Spatial (time-based effects)
    if (finalSettings.reverb > 0.0f)
        applyReverb(output, finalSettings.reverb, sampleRate);

    if (finalSettings.delay > 0.0f)
        applyDelay(output, finalSettings.delay, sampleRate);

    // 8. Glitch effects
    if (finalSettings.stutter > 0.0f)
        applyStutter(output, finalSettings.stutter, sampleRate);

    if (finalSettings.granular > 0.0f)
        applyGranular(output, finalSettings.granular, sampleRate);

    if (finalSettings.reverse > 0.0f)
        applyReverse(output, finalSettings.reverse);

    // 8.5. Trim silence (SAVE DISK SPACE!)
    if (finalSettings.trimSilence)
    {
        output = trimSilenceWithFades(output, finalSettings.silenceThreshold,
                                     finalSettings.microFadeSamples, sampleRate);
    }

    // 9. Normalize (final step)
    if (finalSettings.normalize)
    {
        float maxLevel = 0.0f;
        for (int ch = 0; ch < output.getNumChannels(); ++ch)
        {
            for (int i = 0; i < output.getNumSamples(); ++i)
            {
                maxLevel = std::max(maxLevel, std::abs(output.getSample(ch, i)));
            }
        }

        if (maxLevel > 0.0f)
        {
            float gain = 0.95f / maxLevel;  // Normalize to -0.5 dBFS
            output.applyGain(gain);
        }
    }

    return output;
}

//==============================================================================
// Batch Processing
//==============================================================================

bool SampleProcessor::processBatch(const BatchJob& job)
{
    if (batchRunning)
    {
        DBG("SampleProcessor: Batch already running");
        return false;
    }

    batchRunning = true;
    shouldCancelBatch = false;
    batchProgress = 0.0f;

    // Process in background thread
    juce::Thread::launch([this, job]()
    {
        int totalFiles = job.inputFiles.size();
        int filesProcessed = 0;
        int filesSucceeded = 0;

        for (const auto& inputFile : job.inputFiles)
        {
            if (shouldCancelBatch)
                break;

            // Auto-detect category first (if enabled)
            juce::String detectedCategory = "OneShots";
            if (job.autoCategory)
            {
                // Quick load to detect category
                juce::AudioFormatManager formatManager;
                formatManager.registerBasicFormats();
                auto* reader = formatManager.createReaderFor(inputFile);

                if (reader != nullptr)
                {
                    juce::AudioBuffer<float> tempBuffer(static_cast<int>(reader->numChannels),
                                                       juce::jmin(static_cast<int>(reader->lengthInSamples), 44100)); // Max 1 second for detection
                    reader->read(&tempBuffer, 0, tempBuffer.getNumSamples(), 0, true, true);
                    detectedCategory = detectCategory(tempBuffer, reader->sampleRate);
                    delete reader;
                }
            }

            // Generate creative output filename using Echoelmusic naming system
            juce::String outputName;
            if (job.outputPrefix == "Echo_" || job.outputPrefix.startsWith("Echo"))
            {
                // Use creative naming system
                outputName = generateCreativeName(inputFile, job.settings, detectedCategory, filesProcessed + 1);
            }
            else
            {
                // Use traditional naming
                outputName = job.outputPrefix + inputFile.getFileNameWithoutExtension() + job.outputSuffix;
            }

            juce::File outputFile = job.outputDirectory.getChildFile(outputName).withFileExtension(".wav");

            // Process sample
            auto result = processSample(inputFile, outputFile, job.settings);

            if (result.success)
            {
                filesSucceeded++;

                // Generate velocity layers if requested
                if (job.generateVelocityLayers)
                {
                    generateVelocityLayers(outputFile, job.outputDirectory, 4);
                }

                if (onFileProcessed)
                    onFileProcessed(result);
            }
            else
            {
                if (onError)
                    onError("Failed to process: " + inputFile.getFileName() + " - " + result.errorMessage);
            }

            filesProcessed++;
            batchProgress = static_cast<float>(filesProcessed) / totalFiles;

            if (onBatchProgress)
                onBatchProgress(filesProcessed, totalFiles);
        }

        batchRunning = false;

        if (onBatchComplete)
            onBatchComplete(!shouldCancelBatch, filesSucceeded);

        DBG("SampleProcessor: Batch complete. Processed " << filesSucceeded << "/" << totalFiles << " files");
    });

    return true;
}

bool SampleProcessor::processPhoneImport(const juce::File& phoneFolder,
                                        const juce::File& outputFolder,
                                        TransformPreset defaultPreset)
{
    // Scan phone folder for audio files
    auto audioFiles = scanPhoneFolder(phoneFolder);

    if (audioFiles.isEmpty())
    {
        DBG("SampleProcessor: No audio files found in phone folder");
        return false;
    }

    // Create batch job
    BatchJob job;
    job.inputFiles = audioFiles;
    job.outputDirectory = outputFolder;
    job.settings = ProcessingSettings::fromPreset(defaultPreset);
    job.generateVelocityLayers = false;  // Can be enabled if needed
    job.autoCategory = true;
    job.preserveOriginal = true;
    job.outputPrefix = "Echo_";

    return processBatch(job);
}

void SampleProcessor::cancelBatch()
{
    shouldCancelBatch = true;

    // Wait for batch to finish
    while (batchRunning)
        juce::Thread::sleep(100);
}

//==============================================================================
// Velocity Layer Generation
//==============================================================================

juce::Array<SampleProcessor::ProcessingResult> SampleProcessor::generateVelocityLayers(
    const juce::File& inputFile,
    const juce::File& outputFolder,
    int numLayers)
{
    juce::Array<ProcessingResult> results;

    // Generate base name using creative naming system
    ProcessingSettings baseSettings;
    baseSettings.preset = TransformPreset::RandomMedium;
    juce::String baseName = generateCreativeName(inputFile, baseSettings, "OneShots", 0);

    // Remove the unique ID suffix to add velocity layer names
    int lastUnderscorePos = baseName.lastIndexOf("_");
    if (lastUnderscorePos > 0)
        baseName = baseName.substring(0, lastUnderscorePos);

    // Generate variations with different intensity levels
    for (int i = 0; i < numLayers; ++i)
    {
        float intensity = static_cast<float>(i + 1) / numLayers;

        // Create settings for this layer
        ProcessingSettings settings;
        settings.randomizationAmount = 0.2f;  // Subtle variations
        settings.randomSeed = i;
        settings.compression = intensity * 0.5f;
        settings.saturation = intensity * 0.3f;

        // Output filename with velocity indicator using creative naming
        juce::String outputName = generateVelocityLayerName(baseName, i, numLayers);
        juce::File outputFile = outputFolder.getChildFile(outputName).withFileExtension(".wav");

        // Process
        auto result = processSample(inputFile, outputFile, settings);
        results.add(result);
    }

    return results;
}

//==============================================================================
// Phone Import
//==============================================================================

juce::Array<juce::File> SampleProcessor::detectPhoneFolders()
{
    juce::Array<juce::File> phoneFolders;

    // Check common phone mount points
#if JUCE_MAC
    // macOS: /Volumes/
    auto volumesDir = juce::File("/Volumes");
    if (volumesDir.exists())
    {
        for (juce::DirectoryIterator iter(volumesDir, false); iter.next();)
        {
            auto folder = iter.getFile();
            if (folder.isDirectory() && !folder.getFileName().startsWith("."))
                phoneFolders.add(folder);
        }
    }
#elif JUCE_WINDOWS
    // Windows: Check drive letters
    for (char drive = 'D'; drive <= 'Z'; ++drive)
    {
        juce::File driveFolder(juce::String(drive) + ":\\");
        if (driveFolder.exists())
            phoneFolders.add(driveFolder);
    }
#elif JUCE_LINUX
    // Linux: /media/, /mnt/
    juce::File mediaDir("/media");
    if (mediaDir.exists())
    {
        for (juce::DirectoryIterator iter(mediaDir, true); iter.next();)
        {
            auto folder = iter.getFile();
            if (folder.isDirectory())
                phoneFolders.add(folder);
        }
    }
#endif

    return phoneFolders;
}

juce::Array<juce::File> SampleProcessor::scanPhoneFolder(const juce::File& folder)
{
    juce::Array<juce::File> audioFiles;

    juce::DirectoryIterator iter(folder, true, "*.wav;*.flac;*.aiff;*.mp3;*.m4a;*.ogg", juce::File::findFiles);

    while (iter.next())
    {
        audioFiles.add(iter.getFile());
    }

    return audioFiles;
}

bool SampleProcessor::importFromPhone(const juce::File& phoneFolder,
                                     bool autoProcess,
                                     bool autoOrganize)
{
    // Scan for audio files
    auto audioFiles = scanPhoneFolder(phoneFolder);

    if (audioFiles.isEmpty())
        return false;

    // Determine output folder
    juce::File outputFolder = juce::File::getSpecialLocation(juce::File::currentApplicationFile)
                                  .getParentDirectory()
                                  .getChildFile("Samples/OneShots");

    if (autoProcess)
    {
        // Process with random medium transformation
        return processPhoneImport(phoneFolder, outputFolder, TransformPreset::RandomMedium);
    }
    else
    {
        // Just copy files without processing
        for (const auto& file : audioFiles)
        {
            juce::File destFile = outputFolder.getChildFile(file.getFileName());
            file.copyFileTo(destFile);
        }
        return true;
    }
}

//==============================================================================
// Preset Information
//==============================================================================

juce::Array<SampleProcessor::TransformPreset> SampleProcessor::getAllPresets() const
{
    return {
        TransformPreset::DarkDeep,
        TransformPreset::BrightCrispy,
        TransformPreset::VintageWarm,
        TransformPreset::GlitchyModern,
        TransformPreset::SubBass,
        TransformPreset::AiryEthereal,
        TransformPreset::AggressivePunchy,
        TransformPreset::RetroVaporwave,
        TransformPreset::RandomLight,
        TransformPreset::RandomMedium,
        TransformPreset::RandomHeavy
    };
}

juce::String SampleProcessor::getPresetName(TransformPreset preset)
{
    switch (preset)
    {
        case TransformPreset::DarkDeep:         return "Dark & Deep";
        case TransformPreset::BrightCrispy:     return "Bright & Crispy";
        case TransformPreset::VintageWarm:      return "Vintage & Warm";
        case TransformPreset::GlitchyModern:    return "Glitchy & Modern";
        case TransformPreset::SubBass:          return "Sub Bass";
        case TransformPreset::AiryEthereal:     return "Airy & Ethereal";
        case TransformPreset::AggressivePunchy: return "Aggressive & Punchy";
        case TransformPreset::RetroVaporwave:   return "Retro Vaporwave";
        case TransformPreset::RandomLight:      return "Random (Light)";
        case TransformPreset::RandomMedium:     return "Random (Medium)";
        case TransformPreset::RandomHeavy:      return "Random (Heavy)";
        case TransformPreset::Custom:           return "Custom";
        default:                                return "Unknown";
    }
}

juce::String SampleProcessor::getPresetDescription(TransformPreset preset)
{
    switch (preset)
    {
        case TransformPreset::DarkDeep:
            return "Dark Techno: Pitch down, deep reverb, analog saturation";
        case TransformPreset::BrightCrispy:
            return "Modern House: Bright EQ, compression, wide stereo";
        case TransformPreset::VintageWarm:
            return "Lo-Fi: Tape saturation, bit crush, vinyl noise";
        case TransformPreset::GlitchyModern:
            return "Experimental: Stutter, grain, modulation effects";
        case TransformPreset::SubBass:
            return "Bass Heavy: Octave down, sub boost, compression";
        case TransformPreset::AiryEthereal:
            return "Ambient: High-pass, huge reverb, chorus shimmer";
        case TransformPreset::AggressivePunchy:
            return "Hard Techno: Heavy compression, distortion, punch";
        case TransformPreset::RetroVaporwave:
            return "Vaporwave: Pitch shift, chorus, delay, dreamy";
        case TransformPreset::RandomLight:
            return "Subtle random variations (10-30%)";
        case TransformPreset::RandomMedium:
            return "Moderate random variations (30-60%)";
        case TransformPreset::RandomHeavy:
            return "Extreme random variations (60-100%)";
        default:
            return "";
    }
}

//==============================================================================
// Auto-Categorization
//==============================================================================

juce::String SampleProcessor::detectCategory(const juce::AudioBuffer<float>& audio, double sampleRate)
{
    // Simplified category detection
    // Real implementation would use machine learning

    float duration = audio.getNumSamples() / sampleRate;

    // Very short = likely drum one-shot
    if (duration < 0.3)
        return "Drums";

    // Long = likely loop or pad
    if (duration > 2.0)
        return "Loops";

    // Medium length = could be anything, analyze spectrum
    // TODO: Implement spectral analysis

    return "OneShots";
}

//==============================================================================
// Creative Naming System
//==============================================================================

SampleProcessor::MusicalInfo SampleProcessor::extractMusicalInfo(const juce::String& filename)
{
    MusicalInfo info;

    juce::String lowerName = filename.toLowerCase();

    // Extract BPM (look for patterns like "128bpm", "128 bpm", "_128_")
    auto bpmPattern = juce::String();
    for (int i = 0; i < lowerName.length() - 2; ++i)
    {
        if (lowerName[i] >= '0' && lowerName[i] <= '9')
        {
            juce::String numStr;
            int j = i;
            while (j < lowerName.length() && lowerName[j] >= '0' && lowerName[j] <= '9')
            {
                numStr += lowerName[j];
                ++j;
            }

            int num = numStr.getIntValue();
            if (num >= 60 && num <= 200)  // Valid BPM range
            {
                // Check if followed by "bpm" or surrounded by separators
                if (j < lowerName.length() - 3 && lowerName.substring(j, j + 3) == "bpm")
                {
                    info.bpm = num;
                    break;
                }
            }
        }
    }

    // Extract Key (C, Dm, F#m, etc.)
    juce::StringArray possibleKeys = {"c#m", "c#", "d#m", "d#", "f#m", "f#", "g#m", "g#", "a#m", "a#",
                                      "cm", "dm", "em", "fm", "gm", "am", "bm",
                                      "c", "d", "e", "f", "g", "a", "b"};

    for (const auto& key : possibleKeys)
    {
        if (lowerName.contains("_" + key + "_") ||
            lowerName.contains(" " + key + " ") ||
            lowerName.contains("-" + key + "-") ||
            lowerName.endsWith("_" + key) ||
            lowerName.endsWith(" " + key))
        {
            info.key = key.toUpperCase();
            if (info.key.endsWith("M"))
                info.key = info.key.substring(0, info.key.length() - 1) + "m";  // Lowercase m for minor
            break;
        }
    }

    // Extract Genre
    juce::StringArray genres = {"techno", "house", "trance", "dubstep", "dnb", "drum and bass",
                                "hiphop", "trap", "ambient", "industrial", "electro"};
    for (const auto& genre : genres)
    {
        if (lowerName.contains(genre))
        {
            info.genre = genre.substring(0, 1).toUpperCase() + genre.substring(1);
            break;
        }
    }

    // Extract Character
    juce::StringArray characters = {"dark", "bright", "warm", "cold", "aggressive", "soft",
                                   "punchy", "smooth", "crispy", "dirty", "clean", "vintage",
                                   "modern", "analog", "digital", "organic", "synthetic"};
    for (const auto& character : characters)
    {
        if (lowerName.contains(character))
        {
            info.character = character.substring(0, 1).toUpperCase() + character.substring(1);
            break;
        }
    }

    return info;
}

juce::String SampleProcessor::generateCreativeName(const juce::File& sourceFile,
                                                   const ProcessingSettings& settings,
                                                   const juce::String& category,
                                                   int uniqueID)
{
    juce::String creativeName;

    // Always start with Echoelmusic brand prefix
    creativeName = "Echoel";

    // Add preset character
    juce::String presetChar;
    switch (settings.preset)
    {
        case TransformPreset::DarkDeep:         presetChar = "Dark"; break;
        case TransformPreset::BrightCrispy:     presetChar = "Bright"; break;
        case TransformPreset::VintageWarm:      presetChar = "Vintage"; break;
        case TransformPreset::GlitchyModern:    presetChar = "Glitch"; break;
        case TransformPreset::SubBass:          presetChar = "Sub"; break;
        case TransformPreset::AiryEthereal:     presetChar = "Airy"; break;
        case TransformPreset::AggressivePunchy: presetChar = "Punch"; break;
        case TransformPreset::RetroVaporwave:   presetChar = "Retro"; break;
        case TransformPreset::RandomLight:      presetChar = "Soft"; break;
        case TransformPreset::RandomMedium:     presetChar = "Mid"; break;
        case TransformPreset::RandomHeavy:      presetChar = "Heavy"; break;
        default:                                presetChar = "Pro"; break;
    }

    creativeName += presetChar;

    // Add category-specific descriptors
    juce::String typeDescriptor;

    if (category == "Drums")
    {
        juce::StringArray drumTypes = {"Kick", "Snare", "Hat", "Clap", "Tom", "Perc", "Ride"};
        juce::String lowerName = sourceFile.getFileNameWithoutExtension().toLowerCase();

        for (const auto& type : drumTypes)
        {
            if (lowerName.contains(type.toLowerCase()))
            {
                typeDescriptor = type;
                break;
            }
        }

        if (typeDescriptor.isEmpty())
            typeDescriptor = "Hit";  // Generic drum hit
    }
    else if (category == "Bass")
    {
        juce::StringArray bassTypes = {"Sub", "Reese", "FM", "Analog", "Synth"};
        juce::String lowerName = sourceFile.getFileNameWithoutExtension().toLowerCase();

        for (const auto& type : bassTypes)
        {
            if (lowerName.contains(type.toLowerCase()))
            {
                typeDescriptor = type;
                break;
            }
        }

        if (typeDescriptor.isEmpty())
            typeDescriptor = "Bass";
    }
    else if (category == "Synths")
    {
        juce::StringArray synthTypes = {"Lead", "Pad", "Pluck", "Arp", "Stab", "Chord"};
        juce::String lowerName = sourceFile.getFileNameWithoutExtension().toLowerCase();

        for (const auto& type : synthTypes)
        {
            if (lowerName.contains(type.toLowerCase()))
            {
                typeDescriptor = type;
                break;
            }
        }

        if (typeDescriptor.isEmpty())
            typeDescriptor = "Synth";
    }
    else if (category == "FX")
    {
        juce::StringArray fxTypes = {"Riser", "Impact", "Sweep", "Noise", "Crash", "Atmos"};
        juce::String lowerName = sourceFile.getFileNameWithoutExtension().toLowerCase();

        for (const auto& type : fxTypes)
        {
            if (lowerName.contains(type.toLowerCase()))
            {
                typeDescriptor = type;
                break;
            }
        }

        if (typeDescriptor.isEmpty())
            typeDescriptor = "FX";
    }
    else if (category == "Vocals")
    {
        typeDescriptor = "Vocal";
    }
    else if (category == "Loops")
    {
        typeDescriptor = "Loop";
    }
    else
    {
        typeDescriptor = "Shot";  // OneShot
    }

    creativeName += typeDescriptor;

    // Extract musical info from source filename
    auto musicalInfo = extractMusicalInfo(sourceFile.getFileNameWithoutExtension());

    // Add character/genre if found
    if (musicalInfo.character.isNotEmpty())
    {
        creativeName += "_" + musicalInfo.character;
    }
    else if (musicalInfo.genre.isNotEmpty())
    {
        creativeName += "_" + musicalInfo.genre;
    }

    // Add key if found
    if (musicalInfo.key.isNotEmpty())
    {
        creativeName += "_" + musicalInfo.key;
    }

    // Add BPM if found (for loops and longer samples)
    if (musicalInfo.bpm > 0)
    {
        creativeName += "_" + juce::String(musicalInfo.bpm);
    }

    // Add unique ID to prevent collisions
    if (uniqueID > 0)
    {
        creativeName += "_" + juce::String(uniqueID).paddedLeft('0', 3);
    }
    else
    {
        // Generate unique ID from timestamp
        auto timestamp = juce::Time::getCurrentTime().toMilliseconds();
        int shortID = static_cast<int>(timestamp % 1000);
        creativeName += "_" + juce::String(shortID).paddedLeft('0', 3);
    }

    return creativeName;
}

juce::String SampleProcessor::generateVelocityLayerName(const juce::String& baseName,
                                                        int layerIndex,
                                                        int totalLayers)
{
    juce::String layerName = baseName;

    // Add velocity layer descriptor
    juce::StringArray layerNames = {"Soft", "Mid", "Hard", "Max"};

    if (layerIndex < layerNames.size())
    {
        layerName += "_" + layerNames[layerIndex];
    }
    else
    {
        layerName += "_V" + juce::String(layerIndex + 1);
    }

    return layerName;
}

juce::String SampleProcessor::detectSubcategory(const juce::AudioBuffer<float>& audio,
                                               const juce::String& category)
{
    // TODO: Implement subcategory detection based on spectral analysis
    return "";
}

juce::StringArray SampleProcessor::generateTags(const juce::AudioBuffer<float>& audio,
                                               const ProcessingSettings& settings)
{
    juce::StringArray tags;

    // Add tags based on processing
    if (settings.pitchShiftSemitones < -2.0f)
        tags.add("low");
    if (settings.pitchShiftSemitones > 2.0f)
        tags.add("high");

    if (settings.saturation > 0.5f)
        tags.add("saturated");
    if (settings.reverb > 0.5f)
        tags.add("reverb");
    if (settings.delay > 0.3f)
        tags.add("delay");

    if (settings.bitCrush > 0.3f)
        tags.add("lofi");
    if (settings.vinylNoise > 0.2f)
        tags.add("vintage");

    tags.add("echoelmusic");
    tags.add("processed");

    return tags;
}

//==============================================================================
// Legal Safety
//==============================================================================

bool SampleProcessor::isTransformationLegal(const ProcessingSettings& settings) const
{
    // Check if enough transformation applied
    int transformations = 0;

    if (std::abs(settings.pitchShiftSemitones) > 2.0f) transformations++;
    if (settings.timeStretchRatio < 0.9f || settings.timeStretchRatio > 1.1f) transformations++;
    if (settings.saturation > 0.3f) transformations++;
    if (settings.reverb > 0.3f) transformations++;
    if (settings.bitCrush > 0.2f) transformations++;
    if (settings.granular > 0.3f) transformations++;

    // Need at least 3 significant transformations for legal safety
    return transformations >= 3;
}

bool SampleProcessor::verifyUniqueness(const juce::AudioBuffer<float>& original,
                                      const juce::AudioBuffer<float>& processed) const
{
    // Calculate correlation between original and processed
    // Lower correlation = more unique

    // TODO: Implement proper correlation analysis
    // For now, assume transformation is unique

    return true;
}

//==============================================================================
// Processing Implementation - PLACEHOLDERS
//==============================================================================

void SampleProcessor::applyPitchShift(juce::AudioBuffer<float>& audio, float semitones, double sampleRate)
{
    // TODO: Implement pitch shifting using:
    // - Phase vocoder
    // - PSOLA (for speech)
    // - Granular synthesis
    // For now, simple placeholder
    DBG("SampleProcessor: Pitch shift by " << semitones << " semitones");
}

void SampleProcessor::applyTimeStretch(juce::AudioBuffer<float>& audio, float ratio, double sampleRate)
{
    // TODO: Implement time stretching using phase vocoder
    DBG("SampleProcessor: Time stretch ratio " << ratio);
}

void SampleProcessor::applyFilter(juce::AudioBuffer<float>& audio, float lowPass, float highPass, double sampleRate)
{
    // TODO: Implement filtering using juce::dsp::ProcessorDuplicator + StateVariableFilter
    DBG("SampleProcessor: Filter LP=" << lowPass << " HP=" << highPass);
}

void SampleProcessor::applyCompression(juce::AudioBuffer<float>& audio, float amount)
{
    // Simple compression
    float threshold = 1.0f - amount;
    float ratio = 4.0f * amount;

    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            float sample = audio.getSample(ch, i);
            float absSample = std::abs(sample);

            if (absSample > threshold)
            {
                float excess = absSample - threshold;
                float compressed = threshold + excess / ratio;
                sample = std::copysign(compressed, sample);
            }

            audio.setSample(ch, i, sample);
        }
    }
}

void SampleProcessor::applySaturation(juce::AudioBuffer<float>& audio, float amount)
{
    // Soft clipping saturation
    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            float sample = audio.getSample(ch, i);
            float drive = 1.0f + amount * 5.0f;
            sample = std::tanh(sample * drive) / drive;
            audio.setSample(ch, i, sample);
        }
    }
}

void SampleProcessor::applyReverb(juce::AudioBuffer<float>& audio, float wetMix, double sampleRate)
{
    // TODO: Implement reverb using juce::dsp::Reverb
    DBG("SampleProcessor: Reverb wetMix=" << wetMix);
}

void SampleProcessor::applyDelay(juce::AudioBuffer<float>& audio, float wetMix, double sampleRate)
{
    // TODO: Implement delay using juce::dsp::DelayLine
    DBG("SampleProcessor: Delay wetMix=" << wetMix);
}

void SampleProcessor::applyBitCrush(juce::AudioBuffer<float>& audio, float amount)
{
    // Bit depth reduction
    int bits = static_cast<int>(16.0f * (1.0f - amount));
    bits = juce::jmax(1, bits);

    float levels = std::pow(2.0f, static_cast<float>(bits));

    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            float sample = audio.getSample(ch, i);
            sample = std::round(sample * levels) / levels;
            audio.setSample(ch, i, sample);
        }
    }
}

void SampleProcessor::applyVinylNoise(juce::AudioBuffer<float>& audio, float amount)
{
    // Add vinyl crackle noise
    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            float noise = (random.nextFloat() * 2.0f - 1.0f) * amount * 0.1f;
            float sample = audio.getSample(ch, i);
            audio.setSample(ch, i, sample + noise);
        }
    }
}

void SampleProcessor::applyChorus(juce::AudioBuffer<float>& audio, float amount, double sampleRate)
{
    // TODO: Implement chorus using modulated delay lines
    DBG("SampleProcessor: Chorus amount=" << amount);
}

void SampleProcessor::applyStutter(juce::AudioBuffer<float>& audio, float amount, double sampleRate)
{
    // TODO: Implement stutter effect (slice and repeat)
    DBG("SampleProcessor: Stutter amount=" << amount);
}

void SampleProcessor::applyGranular(juce::AudioBuffer<float>& audio, float amount, double sampleRate)
{
    // TODO: Implement granular synthesis
    DBG("SampleProcessor: Granular amount=" << amount);
}

void SampleProcessor::applyReverse(juce::AudioBuffer<float>& audio, float mixAmount)
{
    if (mixAmount <= 0.0f)
        return;

    // Create reversed version
    juce::AudioBuffer<float> reversed(audio.getNumChannels(), audio.getNumSamples());

    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            reversed.setSample(ch, i, audio.getSample(ch, audio.getNumSamples() - 1 - i));
        }
    }

    // Mix with original
    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        for (int i = 0; i < audio.getNumSamples(); ++i)
        {
            float original = audio.getSample(ch, i) * (1.0f - mixAmount);
            float rev = reversed.getSample(ch, i) * mixAmount;
            audio.setSample(ch, i, original + rev);
        }
    }
}

//==============================================================================
// Silence Trimming with Micro-Fades
//==============================================================================

juce::AudioBuffer<float> SampleProcessor::trimSilenceWithFades(
    const juce::AudioBuffer<float>& audio,
    float thresholdDB,
    int fadeSamples,
    double sampleRate)
{
    if (audio.getNumSamples() == 0)
        return audio;

    // Convert threshold from dB to linear
    float thresholdLinear = juce::Decibels::decibelsToGain(thresholdDB);

    // Find first non-silent sample
    int startSample = 0;
    for (int i = 0; i < audio.getNumSamples(); ++i)
    {
        bool isSilent = true;

        // Check all channels
        for (int ch = 0; ch < audio.getNumChannels(); ++ch)
        {
            if (std::abs(audio.getSample(ch, i)) > thresholdLinear)
            {
                isSilent = false;
                break;
            }
        }

        if (!isSilent)
        {
            startSample = i;
            break;
        }
    }

    // Find last non-silent sample
    int endSample = audio.getNumSamples() - 1;
    for (int i = audio.getNumSamples() - 1; i >= startSample; --i)
    {
        bool isSilent = true;

        // Check all channels
        for (int ch = 0; ch < audio.getNumChannels(); ++ch)
        {
            if (std::abs(audio.getSample(ch, i)) > thresholdLinear)
            {
                isSilent = false;
                break;
            }
        }

        if (!isSilent)
        {
            endSample = i;
            break;
        }
    }

    // If entire buffer is silent, return a very short buffer
    if (startSample >= endSample)
    {
        juce::AudioBuffer<float> silentBuffer(audio.getNumChannels(), 1);
        silentBuffer.clear();
        return silentBuffer;
    }

    // Calculate new buffer size (include fade samples if we're trimming)
    int fadeStart = juce::jmax(0, startSample - fadeSamples);
    int fadeEnd = juce::jmin(audio.getNumSamples() - 1, endSample + fadeSamples);
    int newSize = fadeEnd - fadeStart + 1;

    // Create trimmed buffer
    juce::AudioBuffer<float> trimmed(audio.getNumChannels(), newSize);

    // Copy audio data
    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        for (int i = 0; i < newSize; ++i)
        {
            trimmed.setSample(ch, i, audio.getSample(ch, fadeStart + i));
        }
    }

    // Apply fade-in at start (micro-fade to prevent clicks)
    int fadeInEnd = juce::jmin(fadeSamples, trimmed.getNumSamples());
    for (int ch = 0; ch < trimmed.getNumChannels(); ++ch)
    {
        for (int i = 0; i < fadeInEnd; ++i)
        {
            float gain = static_cast<float>(i) / fadeInEnd;
            trimmed.setSample(ch, i, trimmed.getSample(ch, i) * gain);
        }
    }

    // Apply fade-out at end (micro-fade to prevent clicks)
    int fadeOutStart = juce::jmax(0, trimmed.getNumSamples() - fadeSamples);
    for (int ch = 0; ch < trimmed.getNumChannels(); ++ch)
    {
        for (int i = fadeOutStart; i < trimmed.getNumSamples(); ++i)
        {
            int fadePos = i - fadeOutStart;
            int fadeLength = trimmed.getNumSamples() - fadeOutStart;
            float gain = 1.0f - (static_cast<float>(fadePos) / fadeLength);
            trimmed.setSample(ch, i, trimmed.getSample(ch, i) * gain);
        }
    }

    // Calculate space saved
    int samplesSaved = audio.getNumSamples() - trimmed.getNumSamples();
    float percentSaved = (static_cast<float>(samplesSaved) / audio.getNumSamples()) * 100.0f;
    float durationSaved = samplesSaved / sampleRate;

    DBG("SampleProcessor: Trimmed " << samplesSaved << " samples ("
        << juce::String(percentSaved, 1) << "%, "
        << juce::String(durationSaved, 2) << "s saved)");

    return trimmed;
}

//==============================================================================
// Randomization
//==============================================================================

void SampleProcessor::randomizeSettings(ProcessingSettings& settings, float amount, int seed)
{
    juce::Random rnd(seed);

    // Randomize pitch shift
    settings.pitchShiftSemitones += (rnd.nextFloat() * 2.0f - 1.0f) * 12.0f * amount;

    // Randomize filter
    float filterRange = 10000.0f * amount;
    settings.lowPassCutoff += (rnd.nextFloat() * 2.0f - 1.0f) * filterRange;
    settings.highPassCutoff += rnd.nextFloat() * 200.0f * amount;

    // Randomize effects
    settings.saturation += rnd.nextFloat() * amount * 0.5f;
    settings.reverb += rnd.nextFloat() * amount * 0.3f;
    settings.delay += rnd.nextFloat() * amount * 0.2f;
    settings.chorus += rnd.nextFloat() * amount * 0.3f;

    // Clamp all values
    settings.pitchShiftSemitones = juce::jlimit(-24.0f, 24.0f, settings.pitchShiftSemitones);
    settings.lowPassCutoff = juce::jlimit(200.0f, 20000.0f, settings.lowPassCutoff);
    settings.highPassCutoff = juce::jlimit(20.0f, 5000.0f, settings.highPassCutoff);
    settings.saturation = juce::jlimit(0.0f, 1.0f, settings.saturation);
    settings.reverb = juce::jlimit(0.0f, 1.0f, settings.reverb);
    settings.delay = juce::jlimit(0.0f, 1.0f, settings.delay);
    settings.chorus = juce::jlimit(0.0f, 1.0f, settings.chorus);
}

float SampleProcessor::getRandomValue(float min, float max)
{
    return min + random.nextFloat() * (max - min);
}
