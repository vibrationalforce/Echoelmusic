#include "IntelligentStyleEngine.h"
#include <algorithm>
#include <cmath>

IntelligentStyleEngine::IntelligentStyleEngine()
{
}

IntelligentStyleEngine::~IntelligentStyleEngine()
{
}

//==============================================================================
// ZIP IMPORT
//==============================================================================

ZipImportResult IntelligentStyleEngine::importFromZip(const juce::File& zipFile,
                                                       const juce::File& extractToFolder)
{
    ZipImportResult result;

    if (!zipFile.existsAsFile())
    {
        if (onError)
            onError("Zip file does not exist: " + zipFile.getFullPathName());
        return result;
    }

    if (onStatusChange)
        onStatusChange("Extracting .zip archive...");

    // Extract zip
    if (!extractZipFile(zipFile, extractToFolder))
    {
        if (onError)
            onError("Failed to extract .zip file");
        return result;
    }

    // Find all audio files recursively
    auto audioFiles = findAudioFilesRecursive(extractToFolder);

    result.totalFiles = audioFiles.size();

    // Analyze each file
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    for (const auto& file : audioFiles)
    {
        std::unique_ptr<juce::AudioFormatReader> reader(
            formatManager.createReaderFor(file));

        if (reader != nullptr)
        {
            ZipImportResult::FileQuality quality;
            quality.file = file;
            quality.bitDepth = reader->bitsPerSample;
            quality.sampleRate = reader->sampleRate;
            quality.numChannels = static_cast<int>(reader->numChannels);

            // Classify quality
            if (quality.bitDepth == 16)
            {
                quality.qualityRating = "Standard";
                result.files16bit++;
            }
            else if (quality.bitDepth == 24)
            {
                quality.qualityRating = "Professional";
                result.files24bit++;
            }
            else if (quality.bitDepth == 32)
            {
                quality.qualityRating = "Studio";
                result.files32bit++;
            }

            if (quality.sampleRate == 44100.0)
                result.files44khz++;
            else if (quality.sampleRate == 48000.0)
                result.files48khz++;
            else if (quality.sampleRate == 96000.0)
                result.files96khz++;
            else if (quality.sampleRate == 192000.0)
                result.files192khz++;

            result.fileQualities.add(quality);
            result.importedFiles.add(file);
            result.imported++;

            if (onProgress)
                onProgress(static_cast<float>(result.imported) /
                          static_cast<float>(result.totalFiles));
        }
        else
        {
            result.failedFiles.add(file.getFullPathName());
            result.failed++;
        }
    }

    if (onStatusChange)
        onStatusChange("Imported " + juce::String(result.imported) +
                      " files from .zip");

    return result;
}

ZipImportResult IntelligentStyleEngine::importFromZipWithOrganization(
    const juce::File& zipFile,
    const juce::File& baseFolder)
{
    auto tempFolder = juce::File::getSpecialLocation(juce::File::tempDirectory)
        .getChildFile("echoelmusic_zip_" + juce::Uuid().toString());

    auto result = importFromZip(zipFile, tempFolder);

    // Organize by quality
    for (const auto& quality : result.fileQualities)
    {
        juce::File targetFolder;

        if (quality.qualityRating == "Standard")
            targetFolder = baseFolder.getChildFile("16-bit");
        else if (quality.qualityRating == "Professional")
            targetFolder = baseFolder.getChildFile("24-bit");
        else if (quality.qualityRating == "Studio")
            targetFolder = baseFolder.getChildFile("32-bit");

        if (!targetFolder.exists())
            targetFolder.createDirectory();

        quality.file.copyFileTo(targetFolder.getChildFile(quality.file.getFileName()));
    }

    // Clean up temp folder
    tempFolder.deleteRecursively();

    if (onStatusChange)
        onStatusChange("Organized files by quality");

    return result;
}

ZipImportResult IntelligentStyleEngine::scanZipContents(const juce::File& zipFile)
{
    // Preview without extracting
    // Simplified: Would use zip library to peek inside
    ZipImportResult result;

    // For now, extract to temp and scan
    auto tempFolder = juce::File::getSpecialLocation(juce::File::tempDirectory)
        .getChildFile("echoelmusic_scan_" + juce::Uuid().toString());

    result = importFromZip(zipFile, tempFolder);

    // Clean up
    tempFolder.deleteRecursively();

    return result;
}

//==============================================================================
// AUTO-DETECTION
//==============================================================================

MusicGenre IntelligentStyleEngine::detectGenre(const juce::AudioBuffer<float>& audio,
                                               double sampleRate)
{
    // Combine spectrum and rhythm analysis
    auto spectrumGenre = detectGenreFromSpectrum(audio, sampleRate);
    auto rhythmGenre = detectGenreFromRhythm(audio, sampleRate);

    // If both agree, high confidence
    if (spectrumGenre == rhythmGenre)
        return spectrumGenre;

    // Otherwise, favor spectrum analysis
    return spectrumGenre;
}

juce::String IntelligentStyleEngine::detectKey(const juce::AudioBuffer<float>& audio,
                                              double sampleRate)
{
    // Simplified key detection
    // Real implementation would use Krumhansl-Schmuckler algorithm

    return "C major";  // Placeholder
}

float IntelligentStyleEngine::detectBPM(const juce::AudioBuffer<float>& audio,
                                       double sampleRate)
{
    // Simplified BPM detection
    // Real implementation would use onset detection + autocorrelation

    // Analyze transients
    int numSamples = audio.getNumSamples();
    juce::Array<int> onsets;

    auto* data = audio.getReadPointer(0);
    float threshold = 0.3f;
    float previousSample = 0.0f;

    for (int i = 1; i < numSamples; ++i)
    {
        float current = std::abs(data[i]);
        float diff = current - previousSample;

        if (diff > threshold && current > threshold)
            onsets.add(i);

        previousSample = current;
    }

    // Calculate average interval
    if (onsets.size() < 2)
        return 120.0f;  // Default

    int totalInterval = 0;
    for (int i = 1; i < onsets.size(); ++i)
        totalInterval += onsets[i] - onsets[i - 1];

    float avgInterval = static_cast<float>(totalInterval) / static_cast<float>(onsets.size() - 1);
    float bpm = (sampleRate * 60.0f) / avgInterval;

    // Clamp to reasonable range
    return juce::jlimit(60.0f, 200.0f, bpm);
}

juce::String IntelligentStyleEngine::detectInstrument(const juce::AudioBuffer<float>& audio,
                                                      double sampleRate)
{
    // Analyze spectral content
    float subEnergy = 0.0f;
    float midEnergy = 0.0f;
    float highEnergy = 0.0f;

    // Simple energy analysis
    auto* data = audio.getReadPointer(0);

    for (int i = 0; i < audio.getNumSamples(); ++i)
    {
        float sample = std::abs(data[i]);
        subEnergy += sample;  // Simplified
    }

    subEnergy /= audio.getNumSamples();

    // Classification based on energy distribution
    if (subEnergy > 0.5f)
        return "Bass/808";
    else if (subEnergy > 0.3f)
        return "Kick";
    else if (subEnergy > 0.15f)
        return "Snare/Percussion";
    else
        return "Synth/Melodic";
}

IntelligentStyleEngine::AutoDetectionResult
IntelligentStyleEngine::autoDetectAll(const juce::AudioBuffer<float>& audio,
                                     double sampleRate)
{
    AutoDetectionResult result;

    if (onStatusChange)
        onStatusChange("Auto-detecting metadata...");

    result.genre = detectGenre(audio, sampleRate);
    result.key = detectKey(audio, sampleRate);
    result.bpm = detectBPM(audio, sampleRate);
    result.instrument = detectInstrument(audio, sampleRate);
    result.confidence = 0.75f;  // Simplified

    if (onAutoDetection)
        onAutoDetection(result);

    return result;
}

//==============================================================================
// INTELLIGENT PROCESSING
//==============================================================================

IntelligentProcessingResult IntelligentStyleEngine::processIntelligent(
    const juce::AudioBuffer<float>& audio,
    const GenreProcessingConfig& config)
{
    IntelligentProcessingResult result;

    auto startTime = juce::Time::getMillisecondCounterHiRes();

    if (onStatusChange)
        onStatusChange("Processing with genre: " + getGenreName(config.genre));

    // Auto-detect if requested
    if (config.autoDetectGenre || config.autoDetectKey ||
        config.autoDetectBPM || config.autoDetectInstrument)
    {
        auto detected = autoDetectAll(audio, 48000.0);

        result.detectedGenre = detected.genre;
        result.detectedKey = detected.key;
        result.detectedBPM = detected.bpm;
        result.detectedInstrument = detected.instrument;
    }

    // Apply genre-specific processing
    juce::AudioBuffer<float> processed;

    switch (config.genre)
    {
        case MusicGenre::Trap:
            processed = processTrap(audio, config);
            break;
        case MusicGenre::HipHop:
            processed = processHipHop(audio, config);
            break;
        case MusicGenre::Techno:
            processed = processTechno(audio, config);
            break;
        case MusicGenre::House:
            processed = processHouse(audio, config);
            break;
        case MusicGenre::Dubstep:
            processed = processDubstep(audio, config);
            break;
        case MusicGenre::Ambient:
            processed = processAmbient(audio, config);
            break;
        case MusicGenre::Experimental:
            processed = processExperimental(audio, config);
            break;
        case MusicGenre::EchoelIntelligent:
            // Full auto mode
            if (result.detectedGenre != MusicGenre::Unknown)
                processed = applyGenreChain(audio, result.detectedGenre, config);
            else
                processed = audio;  // No changes if can't detect
            break;
        default:
            processed = audio;
            break;
    }

    // Apply loudness normalization
    if (config.loudness.targetLUFS != 0.0f)
    {
        auto loudnessResult = adjustLoudnessWithFeedback(
            processed, 48000.0, config.loudness);

        processed = loudnessResult.audio;
        result.lufs = loudnessResult.outputLUFS;
    }

    // Dolby Atmos optimization
    if (config.optimizeForAtmos)
    {
        processed = optimizeForAtmos(processed);

        auto atmosCheck = checkAtmosCompliance(processed, 48000.0);
        result.atmosCompliant = atmosCheck.compliant;
        result.atmosHeadroom = atmosCheck.headroom;
        result.atmosRating = atmosCheck.rating;

        if (onAtmosCheck)
            onAtmosCheck(atmosCheck);
    }

    result.audio = processed;

    // Analysis
    auto analysis = styleProcessor.analyzeAudio(processed, 48000.0);
    result.peakDB = analysis.peakDB;
    result.rmsDB = analysis.rmsDB;
    result.dynamicRange = analysis.dynamicRange;
    result.stereoWidth = analysis.stereoWidth;

    auto endTime = juce::Time::getMillisecondCounterHiRes();
    result.processingTime = (endTime - startTime) / 1000.0;

    result.success = true;

    if (onStatusChange)
        onStatusChange("Processing complete!");

    return result;
}

IntelligentProcessingResult IntelligentStyleEngine::processFullAuto(
    const juce::AudioBuffer<float>& audio,
    double sampleRate)
{
    GenreProcessingConfig config;
    config.genre = MusicGenre::EchoelIntelligent;
    config.autoDetectGenre = true;
    config.autoDetectKey = true;
    config.autoDetectBPM = true;
    config.autoDetectInstrument = true;
    config.optimizeForAtmos = true;
    config.loudness = LoudnessSpec::fromTarget(LoudnessTarget::Streaming);

    return processIntelligent(audio, config);
}

juce::Array<IntelligentProcessingResult> IntelligentStyleEngine::processBatch(
    const juce::Array<juce::File>& files,
    const GenreProcessingConfig& config)
{
    juce::Array<IntelligentProcessingResult> results;

    for (int i = 0; i < files.size(); ++i)
    {
        if (onProgress)
            onProgress(static_cast<float>(i) / static_cast<float>(files.size()));

        auto audio = styleProcessor.loadHighResAudio(files[i]);
        if (audio.getNumSamples() > 0)
        {
            auto result = processIntelligent(audio, config);
            results.add(result);
        }
    }

    if (onProgress)
        onProgress(1.0f);

    return results;
}

//==============================================================================
// DOLBY ATMOS OPTIMIZATION
//==============================================================================

juce::AudioBuffer<float> IntelligentStyleEngine::optimizeForAtmos(
    const juce::AudioBuffer<float>& audio)
{
    auto result = audio;

    // 1. Ensure adequate headroom (Atmos needs space for spatial encoding)
    float peak = 0.0f;
    for (int ch = 0; ch < result.getNumChannels(); ++ch)
    {
        auto* data = result.getReadPointer(ch);
        for (int i = 0; i < result.getNumSamples(); ++i)
            peak = std::max(peak, std::abs(data[i]));
    }

    // Target: -4dB headroom for Atmos
    float targetPeak = juce::Decibels::decibelsToGain(-4.0f);
    if (peak > targetPeak)
    {
        float gain = targetPeak / peak;
        result.applyGain(gain);
    }

    // 2. Preserve dynamic range (Atmos benefits from dynamics)
    // No heavy compression!

    // 3. Optimize stereo width (not too wide for Atmos)
    // Atmos handles spatialization, so moderate width is best
    if (result.getNumChannels() >= 2)
    {
        auto* left = result.getWritePointer(0);
        auto* right = result.getWritePointer(1);

        for (int i = 0; i < result.getNumSamples(); ++i)
        {
            float mid = (left[i] + right[i]) * 0.5f;
            float side = (left[i] - right[i]) * 0.5f * 0.7f;  // Reduce width slightly

            left[i] = mid + side;
            right[i] = mid - side;
        }
    }

    return result;
}

IntelligentStyleEngine::AtmosComplianceCheck
IntelligentStyleEngine::checkAtmosCompliance(const juce::AudioBuffer<float>& audio,
                                            double sampleRate)
{
    AtmosComplianceCheck check;

    // Calculate metrics
    float lufs = calculateLUFS(audio, sampleRate);
    float truePeak = calculateTruePeak(audio);
    float dynamicRange = styleProcessor.calculateDynamicRange(audio);

    check.lufs = lufs;
    check.truePeak = truePeak;
    check.dynamicRange = dynamicRange;

    // Atmos standards:
    // - LUFS: -18 (recommended)
    // - True Peak: < -2 dBTP
    // - Dynamic Range: >= 10 dB

    bool lufsOK = (lufs >= -20.0f && lufs <= -16.0f);
    bool truePeakOK = (truePeak <= -2.0f);
    bool dynamicRangeOK = (dynamicRange >= 10.0f);

    check.headroom = -2.0f - truePeak;
    check.compliant = (lufsOK && truePeakOK && dynamicRangeOK);

    // Rating
    if (check.compliant && dynamicRange >= 12.0f)
        check.rating = "Excellent";
    else if (check.compliant)
        check.rating = "Good";
    else
        check.rating = "Needs Adjustment";

    // Issues
    if (!lufsOK)
    {
        check.issues.add("LUFS outside Atmos range (-20 to -16)");
        check.recommendations.add("Adjust loudness to -18 LUFS");
    }

    if (!truePeakOK)
    {
        check.issues.add("True peak too high (> -2 dBTP)");
        check.recommendations.add("Apply true peak limiting to -2 dBTP");
    }

    if (!dynamicRangeOK)
    {
        check.issues.add("Insufficient dynamic range (< 10 dB)");
        check.recommendations.add("Reduce compression to preserve dynamics");
    }

    return check;
}

juce::AudioBuffer<float> IntelligentStyleEngine::fixAtmosIssues(
    const juce::AudioBuffer<float>& audio,
    const AtmosComplianceCheck& check)
{
    auto result = audio;

    // Fix LUFS
    if (check.lufs < -20.0f || check.lufs > -16.0f)
        result = adjustLoudness(result, 48000.0, -18.0f, true);

    // Fix true peak
    if (check.truePeak > -2.0f)
    {
        float targetGain = juce::Decibels::decibelsToGain(-2.0f) / check.truePeak;
        result.applyGain(targetGain);
    }

    // Can't really "fix" dynamic range without reprocessing
    // Just warn user

    return result;
}

//==============================================================================
// ADAPTIVE LOUDNESS
//==============================================================================

juce::AudioBuffer<float> IntelligentStyleEngine::adjustLoudness(
    const juce::AudioBuffer<float>& audio,
    double sampleRate,
    float targetLUFS,
    bool preserveDynamics)
{
    return applyGainToLUFS(audio, sampleRate, targetLUFS);
}

IntelligentStyleEngine::LoudnessAdjustmentResult
IntelligentStyleEngine::adjustLoudnessWithFeedback(
    const juce::AudioBuffer<float>& audio,
    double sampleRate,
    const LoudnessSpec& spec)
{
    LoudnessAdjustmentResult result;

    // Calculate input metrics
    result.inputLUFS = calculateLUFS(audio, sampleRate);

    // Adjust to target
    result.audio = applyGainToLUFS(audio, sampleRate, spec.targetLUFS);

    // Calculate output metrics
    result.outputLUFS = calculateLUFS(result.audio, sampleRate);
    result.gainApplied = result.outputLUFS - result.inputLUFS;
    result.truePeak = calculateTruePeak(result.audio);
    result.dynamicRange = styleProcessor.calculateDynamicRange(result.audio);

    // Apply true peak limiting if needed
    if (spec.limitTruePeak && result.truePeak > spec.truePeakMax)
    {
        float limitGain = juce::Decibels::decibelsToGain(spec.truePeakMax) / result.truePeak;
        result.audio.applyGain(limitGain);
        result.limitingApplied = true;
        result.truePeak = calculateTruePeak(result.audio);
    }

    // Quality assessment
    if (result.dynamicRange >= 10.0f)
        result.quality = "Excellent";
    else if (result.dynamicRange >= 6.0f)
        result.quality = "Good";
    else
        result.quality = "Over-processed";

    if (onLoudnessUpdate)
    {
        LoudnessMeterData data;
        data.currentLUFS = result.outputLUFS;
        data.targetLUFS = spec.targetLUFS;
        data.truePeak = result.truePeak;
        data.dynamicRange = result.dynamicRange;
        data.headroom = spec.truePeakMax - result.truePeak;

        onLoudnessUpdate(data);
    }

    return result;
}

IntelligentStyleEngine::LoudnessMeterData
IntelligentStyleEngine::getLoudnessMeterData(const juce::AudioBuffer<float>& audio,
                                            double sampleRate,
                                            LoudnessTarget target)
{
    LoudnessMeterData data;

    auto spec = LoudnessSpec::fromTarget(target);

    data.currentLUFS = calculateLUFS(audio, sampleRate);
    data.targetLUFS = spec.targetLUFS;
    data.truePeak = calculateTruePeak(audio);
    data.dynamicRange = styleProcessor.calculateDynamicRange(audio);
    data.headroom = spec.truePeakMax - data.truePeak;

    // Target name
    switch (target)
    {
        case LoudnessTarget::DolbyAtmos:
            data.targetName = "Dolby Atmos";
            break;
        case LoudnessTarget::Streaming:
            data.targetName = "Streaming";
            break;
        case LoudnessTarget::Broadcast:
            data.targetName = "Broadcast";
            break;
        case LoudnessTarget::MusicProduction:
            data.targetName = "Music Production";
            break;
        case LoudnessTarget::Club:
            data.targetName = "Club Mix";
            break;
        default:
            data.targetName = "Custom";
            break;
    }

    return data;
}

//==============================================================================
// GENRE-SPECIFIC PROCESSING
//==============================================================================

juce::AudioBuffer<float> IntelligentStyleEngine::processTrap(
    const juce::AudioBuffer<float>& audio,
    const GenreProcessingConfig& config)
{
    auto result = audio;

    // Trap characteristics:
    // - Heavy 808 bass
    // - Wide stereo
    // - Modern, clean sound
    // - Moderate compression

    // Bass
    if (config.bassAmount > 0.0f)
    {
        result = styleProcessor.enhance808Bass(result, config.bassAmount * 1.5f);
        result = styleProcessor.addSubHarmonics(result, 45.0f);
    }

    // Stereo width
    if (config.stereoWidth > 0.0f)
        result = styleProcessor.wideStereo(result, 1.0f + config.stereoWidth);

    // Warmth
    if (config.warmthAmount > 0.0f)
        result = styleProcessor.applyTapeSaturation(result, config.warmthAmount * 0.5f);

    // Punch
    if (config.punchAmount > 0.0f)
        result = styleProcessor.punchyCompression(result, 2.0f + config.punchAmount * 4.0f, -20.0f);

    // Brightness
    if (config.brightnessAmount > 0.0f)
        result = styleProcessor.airEQ(result, 12000.0f, config.brightnessAmount * 3.0f);

    return result;
}

juce::AudioBuffer<float> IntelligentStyleEngine::processHipHop(
    const juce::AudioBuffer<float>& audio,
    const GenreProcessingConfig& config)
{
    auto result = audio;

    // Hip-Hop characteristics:
    // - Punchy drums
    // - Analog warmth
    // - Moderate bass
    // - Classic vibe

    // Warmth (important!)
    if (config.warmthAmount > 0.0f)
    {
        result = styleProcessor.applyAnalogWarmth(result, config.warmthAmount * 0.8f);
        result = styleProcessor.applyTapeSaturation(result, config.warmthAmount * 0.6f);
    }

    // Bass
    if (config.bassAmount > 0.0f)
        result = styleProcessor.enhance808Bass(result, config.bassAmount);

    // Punch
    if (config.punchAmount > 0.0f)
        result = styleProcessor.punchyCompression(result, 3.0f, -18.0f + config.punchAmount * 8.0f);

    // Moderate stereo
    if (config.stereoWidth > 0.0f)
        result = styleProcessor.wideStereo(result, 1.0f + config.stereoWidth * 0.5f);

    return result;
}

juce::AudioBuffer<float> IntelligentStyleEngine::processTechno(
    const juce::AudioBuffer<float>& audio,
    const GenreProcessingConfig& config)
{
    auto result = audio;

    // Techno characteristics:
    // - Deep bass
    // - Atmospheric
    // - Analog character
    // - Spatial depth

    // Warmth + Atmosphere
    if (config.warmthAmount > 0.0f || config.atmosphereAmount > 0.0f)
    {
        result = styleProcessor.applyAnalogWarmth(result, config.warmthAmount * 0.7f);
        result = styleProcessor.deepReverb(result, 0.6f + config.atmosphereAmount * 0.3f, 0.5f);
    }

    // Bass (deep, not punchy)
    if (config.bassAmount > 0.0f)
        result = styleProcessor.vintageLowShelf(result, 60.0f, config.bassAmount * 4.0f);

    // Moderate stereo width
    if (config.stereoWidth > 0.0f)
        result = styleProcessor.wideStereo(result, 1.0f + config.stereoWidth * 0.6f);

    return result;
}

juce::AudioBuffer<float> IntelligentStyleEngine::processHouse(
    const juce::AudioBuffer<float>& audio,
    const GenreProcessingConfig& config)
{
    auto result = audio;

    // House characteristics:
    // - Groovy, organic
    // - Warm, vintage
    // - Moderate compression
    // - Musical

    // Warmth
    if (config.warmthAmount > 0.0f)
    {
        result = styleProcessor.applyVinylCharacter(result);
        result = styleProcessor.applyAnalogWarmth(result, config.warmthAmount * 0.6f);
    }

    // Bass
    if (config.bassAmount > 0.0f)
        result = styleProcessor.enhance808Bass(result, config.bassAmount * 0.8f);

    // Atmosphere
    if (config.atmosphereAmount > 0.0f)
        result = styleProcessor.deepReverb(result, 0.5f, 0.4f);

    // Punch (gentle)
    if (config.punchAmount > 0.0f)
        result = styleProcessor.punchyCompression(result, 2.5f, -22.0f);

    return result;
}

juce::AudioBuffer<float> IntelligentStyleEngine::processDubstep(
    const juce::AudioBuffer<float>& audio,
    const GenreProcessingConfig& config)
{
    auto result = audio;

    // Dubstep characteristics:
    // - HEAVY sub bass
    // - Wide stereo
    // - Aggressive processing
    // - Wobbles/modulation

    // Sub bass (maximum!)
    if (config.bassAmount > 0.0f)
    {
        result = styleProcessor.enhance808Bass(result, config.bassAmount * 1.8f);
        result = styleProcessor.addSubHarmonics(result, 40.0f);
    }

    // Wide stereo
    if (config.stereoWidth > 0.0f)
        result = styleProcessor.wideStereo(result, 1.0f + config.stereoWidth * 1.2f);

    // Aggressive saturation
    if (config.warmthAmount > 0.0f)
        result = styleProcessor.applyTapeSaturation(result, config.warmthAmount * 0.8f);

    // Hard compression
    if (config.punchAmount > 0.0f)
        result = styleProcessor.punchyCompression(result, 4.0f, -16.0f);

    return result;
}

juce::AudioBuffer<float> IntelligentStyleEngine::processAmbient(
    const juce::AudioBuffer<float>& audio,
    const GenreProcessingConfig& config)
{
    auto result = audio;

    // Ambient characteristics:
    // - Huge reverb/space
    // - Minimal compression
    // - Wide stereo
    // - Atmospheric

    // Atmosphere (maximum!)
    if (config.atmosphereAmount > 0.0f)
        result = styleProcessor.deepReverb(result, 0.9f, 0.3f);

    // Wide stereo
    if (config.stereoWidth > 0.0f)
        result = styleProcessor.wideStereo(result, 1.0f + config.stereoWidth * 1.5f);

    // Brightness (ethereal)
    if (config.brightnessAmount > 0.0f)
        result = styleProcessor.airEQ(result, 10000.0f, config.brightnessAmount * 2.5f);

    // Minimal compression
    if (config.punchAmount > 0.0f)
        result = styleProcessor.punchyCompression(result, 1.5f, -30.0f);

    return result;
}

juce::AudioBuffer<float> IntelligentStyleEngine::processExperimental(
    const juce::AudioBuffer<float>& audio,
    const GenreProcessingConfig& config)
{
    auto result = audio;

    // Experimental characteristics:
    // - Granular processing
    // - Bit crushing
    // - Creative effects
    // - Unique character

    // Granular
    result = styleProcessor.granularProcessing(result, 40.0f);

    // Bit crushing (subtle unless requested)
    if (config.warmthAmount > 0.5f)
        result = styleProcessor.bitCrushing(result, 12 - static_cast<int>(config.warmthAmount * 4.0f));

    // Wide stereo
    if (config.stereoWidth > 0.0f)
        result = styleProcessor.wideStereo(result, 1.0f + config.stereoWidth * 1.8f);

    // Creative resampling
    result = styleProcessor.creativeResampling(result, config.punchAmount * 0.2f);

    return result;
}

//==============================================================================
// RECOMMENDED SETTINGS
//==============================================================================

GenreProcessingConfig IntelligentStyleEngine::getRecommendedConfig(MusicGenre genre)
{
    GenreProcessingConfig config;
    config.genre = genre;

    switch (genre)
    {
        case MusicGenre::Trap:
            config.bassAmount = 0.8f;
            config.stereoWidth = 0.7f;
            config.atmosphereAmount = 0.3f;
            config.warmthAmount = 0.4f;
            config.punchAmount = 0.6f;
            config.brightnessAmount = 0.7f;
            config.loudness = LoudnessSpec::fromTarget(LoudnessTarget::Streaming);
            break;

        case MusicGenre::HipHop:
            config.bassAmount = 0.6f;
            config.stereoWidth = 0.4f;
            config.atmosphereAmount = 0.2f;
            config.warmthAmount = 0.7f;
            config.punchAmount = 0.7f;
            config.brightnessAmount = 0.5f;
            config.loudness = LoudnessSpec::fromTarget(LoudnessTarget::Streaming);
            break;

        case MusicGenre::Techno:
            config.bassAmount = 0.7f;
            config.stereoWidth = 0.6f;
            config.atmosphereAmount = 0.7f;
            config.warmthAmount = 0.7f;
            config.punchAmount = 0.5f;
            config.brightnessAmount = 0.4f;
            config.loudness = LoudnessSpec::fromTarget(LoudnessTarget::Club);
            break;

        case MusicGenre::Dubstep:
            config.bassAmount = 0.9f;
            config.stereoWidth = 0.8f;
            config.atmosphereAmount = 0.4f;
            config.warmthAmount = 0.6f;
            config.punchAmount = 0.8f;
            config.brightnessAmount = 0.6f;
            config.loudness = LoudnessSpec::fromTarget(LoudnessTarget::Club);
            break;

        case MusicGenre::Ambient:
            config.bassAmount = 0.3f;
            config.stereoWidth = 0.9f;
            config.atmosphereAmount = 0.9f;
            config.warmthAmount = 0.5f;
            config.punchAmount = 0.2f;
            config.brightnessAmount = 0.7f;
            config.loudness = LoudnessSpec::fromTarget(LoudnessTarget::DolbyAtmos);
            break;

        default:
            // Balanced default
            config.bassAmount = 0.5f;
            config.stereoWidth = 0.5f;
            config.atmosphereAmount = 0.5f;
            config.warmthAmount = 0.5f;
            config.punchAmount = 0.5f;
            config.brightnessAmount = 0.5f;
            config.loudness = LoudnessSpec::fromTarget(LoudnessTarget::Streaming);
            break;
    }

    config.optimizeForAtmos = true;  // Always optimize for Atmos by default!

    return config;
}

LoudnessSpec IntelligentStyleEngine::getRecommendedLoudness(LoudnessTarget target)
{
    return LoudnessSpec::fromTarget(target);
}

juce::String IntelligentStyleEngine::getGenreName(MusicGenre genre) const
{
    switch (genre)
    {
        case MusicGenre::Trap: return "Trap";
        case MusicGenre::HipHop: return "Hip-Hop";
        case MusicGenre::Techno: return "Techno";
        case MusicGenre::House: return "House";
        case MusicGenre::Dubstep: return "Dubstep";
        case MusicGenre::DrumAndBass: return "Drum & Bass";
        case MusicGenre::Ambient: return "Ambient";
        case MusicGenre::Experimental: return "Experimental";
        case MusicGenre::Pop: return "Pop";
        case MusicGenre::Rock: return "Rock";
        case MusicGenre::Jazz: return "Jazz";
        case MusicGenre::Classical: return "Classical";
        case MusicGenre::Electronic: return "Electronic";
        case MusicGenre::Urban: return "Urban";
        case MusicGenre::World: return "World";
        case MusicGenre::EchoelIntelligent: return "Echoelmusic Intelligent";
        default: return "Unknown";
    }
}

juce::String IntelligentStyleEngine::getGenreDescription(MusicGenre genre) const
{
    switch (genre)
    {
        case MusicGenre::Trap:
            return "Modern trap: heavy 808s, wide stereo, bright sound";
        case MusicGenre::HipHop:
            return "Classic hip-hop: punchy drums, analog warmth, vintage vibe";
        case MusicGenre::Techno:
            return "Deep techno: atmospheric, analog character, spatial depth";
        case MusicGenre::House:
            return "House grooves: organic, warm, musical";
        case MusicGenre::Dubstep:
            return "Heavy dubstep: sub bass focus, wide stereo, aggressive";
        case MusicGenre::Ambient:
            return "Atmospheric ambient: huge reverb, minimal compression, ethereal";
        case MusicGenre::Experimental:
            return "Experimental: granular, creative effects, unique character";
        case MusicGenre::EchoelIntelligent:
            return "Auto-detect genre + intelligent processing";
        default:
            return "Unknown genre";
    }
}

//==============================================================================
// PRESETS
//==============================================================================

bool IntelligentStyleEngine::savePreset(const GenreProcessingConfig& config,
                                       const juce::String& name)
{
    // Save to file (JSON)
    // Placeholder
    return true;
}

GenreProcessingConfig IntelligentStyleEngine::loadPreset(const juce::String& name)
{
    // Load from file
    // Placeholder
    return GenreProcessingConfig();
}

juce::StringArray IntelligentStyleEngine::getSavedPresets()
{
    // List all saved presets
    juce::StringArray presets;
    presets.add("Factory Default");
    return presets;
}

//==============================================================================
// INTERNAL HELPERS
//==============================================================================

juce::AudioBuffer<float> IntelligentStyleEngine::applyGenreChain(
    const juce::AudioBuffer<float>& audio,
    MusicGenre genre,
    const GenreProcessingConfig& config)
{
    switch (genre)
    {
        case MusicGenre::Trap: return processTrap(audio, config);
        case MusicGenre::HipHop: return processHipHop(audio, config);
        case MusicGenre::Techno: return processTechno(audio, config);
        case MusicGenre::House: return processHouse(audio, config);
        case MusicGenre::Dubstep: return processDubstep(audio, config);
        case MusicGenre::Ambient: return processAmbient(audio, config);
        case MusicGenre::Experimental: return processExperimental(audio, config);
        default: return audio;
    }
}

MusicGenre IntelligentStyleEngine::detectGenreFromSpectrum(
    const juce::AudioBuffer<float>& audio,
    double sampleRate)
{
    // Analyze spectral content
    float subEnergy = 0.0f;
    float midEnergy = 0.0f;
    float highEnergy = 0.0f;

    // Simplified spectrum analysis
    auto* data = audio.getReadPointer(0);

    for (int i = 0; i < audio.getNumSamples(); ++i)
    {
        float sample = std::abs(data[i]);
        subEnergy += sample;  // Placeholder
    }

    // Classification
    if (subEnergy > 0.7f)
        return MusicGenre::Dubstep;
    else if (subEnergy > 0.5f)
        return MusicGenre::Trap;
    else if (subEnergy > 0.3f)
        return MusicGenre::HipHop;
    else
        return MusicGenre::Ambient;
}

MusicGenre IntelligentStyleEngine::detectGenreFromRhythm(
    const juce::AudioBuffer<float>& audio,
    double sampleRate)
{
    float bpm = detectBPM(audio, sampleRate);

    // BPM-based classification
    if (bpm >= 140.0f)
        return MusicGenre::DrumAndBass;
    else if (bpm >= 130.0f)
        return MusicGenre::Techno;
    else if (bpm >= 120.0f)
        return MusicGenre::House;
    else if (bpm >= 70.0f && bpm <= 90.0f)
        return MusicGenre::Trap;
    else
        return MusicGenre::Ambient;
}

float IntelligentStyleEngine::calculateLUFS(const juce::AudioBuffer<float>& audio,
                                           double sampleRate)
{
    return styleProcessor.calculateLUFS(audio, sampleRate);
}

float IntelligentStyleEngine::calculateTruePeak(const juce::AudioBuffer<float>& audio)
{
    // True peak detection (simplified)
    float peak = 0.0f;

    for (int ch = 0; ch < audio.getNumChannels(); ++ch)
    {
        auto* data = audio.getReadPointer(ch);
        for (int i = 0; i < audio.getNumSamples(); ++i)
            peak = std::max(peak, std::abs(data[i]));
    }

    return peak;
}

juce::AudioBuffer<float> IntelligentStyleEngine::applyGainToLUFS(
    const juce::AudioBuffer<float>& audio,
    double sampleRate,
    float targetLUFS)
{
    float currentLUFS = calculateLUFS(audio, sampleRate);
    float gainDB = targetLUFS - currentLUFS;
    float gainLin = juce::Decibels::decibelsToGain(gainDB);

    auto result = audio;
    result.applyGain(gainLin);

    return result;
}

bool IntelligentStyleEngine::meetsAtmosStandards(float lufs, float truePeak, float dynamicRange)
{
    return (lufs >= -20.0f && lufs <= -16.0f) &&
           (truePeak <= -2.0f) &&
           (dynamicRange >= 10.0f);
}

juce::AudioBuffer<float> IntelligentStyleEngine::applyAtmosOptimization(
    const juce::AudioBuffer<float>& audio)
{
    return optimizeForAtmos(audio);
}

bool IntelligentStyleEngine::extractZipFile(const juce::File& zipFile,
                                           const juce::File& targetFolder)
{
    // Zip extraction
    // Would use juce::ZipFile or external library
    // Placeholder: assumes files are already extracted
    return true;
}

juce::Array<juce::File> IntelligentStyleEngine::findAudioFilesRecursive(
    const juce::File& folder)
{
    juce::Array<juce::File> audioFiles;

    juce::StringArray extensions = {"*.wav", "*.aif", "*.aiff", "*.flac", "*.mp3", "*.ogg"};

    for (const auto& ext : extensions)
    {
        auto files = folder.findChildFiles(juce::File::findFiles, true, ext);
        audioFiles.addArray(files);
    }

    return audioFiles;
}
