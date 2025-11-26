#include "HybridProducerStyleIntegration.h"
#include <cmath>
#include <algorithm>
#include <numeric>

//==============================================================================
// HybridProducerStyleIntegration Implementation
//==============================================================================

HybridProducerStyleIntegration::HybridProducerStyleIntegration()
{
    // Initialize with default config
    config.analogBehavior.analogAmount = 0.7f;
    config.analogBehavior.tape.enabled = true;
    config.analogBehavior.tape.saturation = 0.5f;
    config.analogBehavior.tape.warmth = 0.5f;
    config.analogBehavior.tube.enabled = true;
    config.analogBehavior.tube.drive = 0.5f;
    config.analogBehavior.vintage.enabled = true;
    config.analogBehavior.vintage.noise = 0.1f;
}

HybridProducerStyleIntegration::~HybridProducerStyleIntegration()
{
}

//==============================================================================
// Initialization
//==============================================================================

void HybridProducerStyleIntegration::initialize(double sampleRate)
{
    currentSampleRate = sampleRate;
    analyzer.initialize(sampleRate);
    styleProcessor.initialize(sampleRate);
}

void HybridProducerStyleIntegration::setConfiguration(const HybridProcessingConfig& newConfig)
{
    config = newConfig;
}

//==============================================================================
// Google Drive Library Processing
//==============================================================================

CategorizedModelLibrary HybridProducerStyleIntegration::processGoogleDriveLibrary(
    const juce::File& libraryRoot,
    ProducerStyleProcessor::ProducerStyle style,
    std::function<void(int, int)> progressCallback)
{
    CategorizedModelLibrary library;
    library.name = "Echoelmusic Hybrid Library";
    library.description = "Processed with " + getProducerStyleName(style);
    library.producerStyle = style;

    // Reset statistics
    lastStats = ProcessingStats();
    auto startTime = juce::Time::getCurrentTime();

    // Auto-detect library structure
    auto structure = detectLibraryStructure(libraryRoot);

    // Calculate total files
    int totalFiles = 0;
    for (const auto& [category, files] : structure)
        totalFiles += files.size();

    int processedFiles = 0;

    // Process each category
    if (config.processDrums && structure.count("drums") > 0)
    {
        library.drums = processCategoryFolder(
            libraryRoot.getChildFile("drums"),
            "drums",
            style,
            [&](int current, int total) {
                if (progressCallback)
                    progressCallback(processedFiles + current, totalFiles);
            }
        );
        processedFiles += structure["drums"].size();
    }

    if (config.processBass && structure.count("bass") > 0)
    {
        library.bass = processCategoryFolder(
            libraryRoot.getChildFile("bass"),
            "bass",
            style,
            [&](int current, int total) {
                if (progressCallback)
                    progressCallback(processedFiles + current, totalFiles);
            }
        );
        processedFiles += structure["bass"].size();
    }

    if (config.processMelodic && structure.count("melodic") > 0)
    {
        library.melodic = processCategoryFolder(
            libraryRoot.getChildFile("melodic"),
            "melodic",
            style,
            [&](int current, int total) {
                if (progressCallback)
                    progressCallback(processedFiles + current, totalFiles);
            }
        );
        processedFiles += structure["melodic"].size();
    }

    if (config.processTextures && structure.count("textures") > 0)
    {
        library.textures = processCategoryFolder(
            libraryRoot.getChildFile("textures"),
            "textures",
            style,
            [&](int current, int total) {
                if (progressCallback)
                    progressCallback(processedFiles + current, totalFiles);
            }
        );
        processedFiles += structure["textures"].size();
    }

    if (config.processFX && structure.count("fx") > 0)
    {
        library.fx = processCategoryFolder(
            libraryRoot.getChildFile("fx"),
            "fx",
            style,
            [&](int current, int total) {
                if (progressCallback)
                    progressCallback(processedFiles + current, totalFiles);
            }
        );
        processedFiles += structure["fx"].size();
    }

    if (config.processVocals && structure.count("vocals") > 0)
    {
        library.vocals = processCategoryFolder(
            libraryRoot.getChildFile("vocals"),
            "vocals",
            style,
            [&](int current, int total) {
                if (progressCallback)
                    progressCallback(processedFiles + current, totalFiles);
            }
        );
        processedFiles += structure["vocals"].size();
    }

    // Update statistics
    auto endTime = juce::Time::getCurrentTime();
    auto duration = endTime - startTime;

    library.stats = lastStats;
    library.stats.totalSamplesProcessed = processedFiles;
    library.stats.samplesKept = library.getTotalCount();
    library.stats.samplesRejected = processedFiles - library.getTotalCount();
    library.stats.processingTime = duration.getDescription();

    return library;
}

std::vector<SynthesisModel> HybridProducerStyleIntegration::processCategoryFolder(
    const juce::File& categoryFolder,
    const juce::String& categoryName,
    ProducerStyleProcessor::ProducerStyle style,
    std::function<void(int, int)> progressCallback)
{
    std::vector<SynthesisModel> models;

    if (!categoryFolder.exists())
        return models;

    // Get all audio files
    auto audioFiles = categoryFolder.findChildFiles(
        juce::File::findFiles,
        false,
        "*.wav;*.aiff;*.mp3;*.flac;*.ogg"
    );

    models.reserve(audioFiles.size());

    for (int i = 0; i < audioFiles.size(); ++i)
    {
        auto model = processAudioFile(audioFiles[i], style, categoryName);

        // Check quality threshold
        if (model.analysisQuality >= config.minQualityThreshold)
        {
            models.push_back(model);
            lastStats.samplesKept++;
        }
        else
        {
            lastStats.samplesRejected++;
        }

        lastStats.totalSamplesProcessed++;

        if (progressCallback)
            progressCallback(i + 1, audioFiles.size());
    }

    // Select best samples if we have too many
    if (models.size() > (size_t)config.maxSamples)
    {
        if (config.diversitySelection)
            models = selectDiverseSamples(models, config.maxSamples, 0.5f);
        else
            models = analyzer.selectBestSamples(models, config.maxSamples);
    }

    return models;
}

//==============================================================================
// Single Sample Processing
//==============================================================================

SynthesisModel HybridProducerStyleIntegration::processSample(
    const juce::AudioBuffer<float>& sample,
    const juce::String& name,
    ProducerStyleProcessor::ProducerStyle style,
    const juce::String& category)
{
    juce::AudioBuffer<float> processedSample = sample;

    // Apply producer-style processing BEFORE analysis
    if (config.applyBeforeSynthesis)
    {
        processedSample = applyProducerStyle(sample, style, config.processingIntensity);
    }

    // Analyze processed sample
    SynthesisModel model = analyzer.analyzeSample(
        processedSample,
        name,
        !config.removeOriginalSamples
    );

    // Set category
    model.category = category.isEmpty() ? categorizeSample(name, model) : category;

    return model;
}

SynthesisModel HybridProducerStyleIntegration::processAudioFile(
    const juce::File& audioFile,
    ProducerStyleProcessor::ProducerStyle style,
    const juce::String& category)
{
    // Load audio file
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    auto* reader = formatManager.createReaderFor(audioFile);
    if (reader == nullptr)
    {
        return SynthesisModel(); // Empty model
    }

    juce::AudioBuffer<float> buffer(reader->numChannels, (int)reader->lengthInSamples);
    reader->read(&buffer, 0, (int)reader->lengthInSamples, 0, true, true);

    delete reader;

    // Calculate original size
    size_t originalSize = audioFile.getSize();
    lastStats.originalSizeBytes += originalSize;

    // Process sample
    auto model = processSample(buffer, audioFile.getFileNameWithoutExtension(), style, category);

    // Calculate optimized size
    size_t optimizedSize = analyzer.getModelSize(model);
    lastStats.optimizedSizeBytes += optimizedSize;

    return model;
}

//==============================================================================
// Producer-Style Application
//==============================================================================

juce::AudioBuffer<float> HybridProducerStyleIntegration::applyProducerStyle(
    const juce::AudioBuffer<float>& input,
    ProducerStyleProcessor::ProducerStyle style,
    float intensity)
{
    juce::AudioBuffer<float> output = input;

    // Set producer style
    styleProcessor.setProducerStyle(style);

    // Process buffer
    juce::dsp::AudioBlock<float> block(output);
    juce::dsp::ProcessContextReplacing<float> context(block);

    styleProcessor.process(context);

    // Blend with original based on intensity
    if (intensity < 1.0f)
    {
        for (int ch = 0; ch < output.getNumChannels(); ++ch)
        {
            for (int i = 0; i < output.getNumSamples(); ++i)
            {
                float wet = output.getSample(ch, i);
                float dry = input.getSample(ch, i);
                output.setSample(ch, i, dry + (wet - dry) * intensity);
            }
        }
    }

    return output;
}

juce::AudioBuffer<float> HybridProducerStyleIntegration::applyBlendedStyles(
    const juce::AudioBuffer<float>& input,
    const std::vector<std::pair<ProducerStyleProcessor::ProducerStyle, float>>& stylesWithWeights)
{
    juce::AudioBuffer<float> output(input.getNumChannels(), input.getNumSamples());
    output.clear();

    float totalWeight = 0.0f;
    for (const auto& [style, weight] : stylesWithWeights)
        totalWeight += weight;

    if (totalWeight <= 0.0f)
        return input;

    // Process with each style and blend
    for (const auto& [style, weight] : stylesWithWeights)
    {
        auto processed = applyProducerStyle(input, style, 1.0f);
        float normalizedWeight = weight / totalWeight;

        for (int ch = 0; ch < output.getNumChannels(); ++ch)
        {
            for (int i = 0; i < output.getNumSamples(); ++i)
            {
                float sample = output.getSample(ch, i);
                sample += processed.getSample(ch, i) * normalizedWeight;
                output.setSample(ch, i, sample);
            }
        }
    }

    return output;
}

//==============================================================================
// Quality Selection
//==============================================================================

CategorizedModelLibrary HybridProducerStyleIntegration::selectBestSamples(
    const CategorizedModelLibrary& library,
    int maxSamplesPerCategory)
{
    CategorizedModelLibrary optimized = library;

    // Select best from each category
    if (library.drums.size() > (size_t)maxSamplesPerCategory)
        optimized.drums = analyzer.selectBestSamples(library.drums, maxSamplesPerCategory);

    if (library.bass.size() > (size_t)maxSamplesPerCategory)
        optimized.bass = analyzer.selectBestSamples(library.bass, maxSamplesPerCategory);

    if (library.melodic.size() > (size_t)maxSamplesPerCategory)
        optimized.melodic = analyzer.selectBestSamples(library.melodic, maxSamplesPerCategory);

    if (library.textures.size() > (size_t)maxSamplesPerCategory)
        optimized.textures = analyzer.selectBestSamples(library.textures, maxSamplesPerCategory);

    if (library.fx.size() > (size_t)maxSamplesPerCategory)
        optimized.fx = analyzer.selectBestSamples(library.fx, maxSamplesPerCategory);

    if (library.vocals.size() > (size_t)maxSamplesPerCategory)
        optimized.vocals = analyzer.selectBestSamples(library.vocals, maxSamplesPerCategory);

    // Update stats
    optimized.stats.samplesKept = optimized.getTotalCount();
    optimized.stats.samplesRejected = library.getTotalCount() - optimized.getTotalCount();

    return optimized;
}

std::vector<SynthesisModel> HybridProducerStyleIntegration::selectDiverseSamples(
    const std::vector<SynthesisModel>& models,
    int targetCount,
    float diversityWeight)
{
    if (models.size() <= (size_t)targetCount)
        return models;

    std::vector<SynthesisModel> selected;
    std::vector<bool> used(models.size(), false);

    // Start with highest quality sample
    int bestIdx = 0;
    float bestQuality = models[0].analysisQuality;
    for (size_t i = 1; i < models.size(); ++i)
    {
        if (models[i].analysisQuality > bestQuality)
        {
            bestQuality = models[i].analysisQuality;
            bestIdx = i;
        }
    }

    selected.push_back(models[bestIdx]);
    used[bestIdx] = true;

    // Select remaining samples based on quality + diversity
    while (selected.size() < (size_t)targetCount)
    {
        int bestCandidate = -1;
        float bestScore = -1.0f;

        for (size_t i = 0; i < models.size(); ++i)
        {
            if (used[i])
                continue;

            // Quality score
            float qualityScore = models[i].analysisQuality;

            // Diversity score (average dissimilarity to selected samples)
            float diversityScore = 0.0f;
            for (const auto& selectedModel : selected)
            {
                float similarity = calculateSimilarity(models[i], selectedModel);
                diversityScore += (1.0f - similarity);
            }
            diversityScore /= selected.size();

            // Combined score
            float score = (1.0f - diversityWeight) * qualityScore +
                         diversityWeight * diversityScore;

            if (score > bestScore)
            {
                bestScore = score;
                bestCandidate = i;
            }
        }

        if (bestCandidate >= 0)
        {
            selected.push_back(models[bestCandidate]);
            used[bestCandidate] = true;
        }
        else
        {
            break;
        }
    }

    return selected;
}

//==============================================================================
// Library I/O
//==============================================================================

bool HybridProducerStyleIntegration::saveOptimizedLibrary(
    const CategorizedModelLibrary& library,
    const juce::File& outputDirectory)
{
    if (!outputDirectory.exists())
        outputDirectory.createDirectory();

    // Save each category
    auto drumDir = outputDirectory.getChildFile("drums");
    auto bassDir = outputDirectory.getChildFile("bass");
    auto melodicDir = outputDirectory.getChildFile("melodic");
    auto texturesDir = outputDirectory.getChildFile("textures");
    auto fxDir = outputDirectory.getChildFile("fx");
    auto vocalsDir = outputDirectory.getChildFile("vocals");

    bool success = true;

    success &= analyzer.saveLibrary(library.drums, drumDir);
    success &= analyzer.saveLibrary(library.bass, bassDir);
    success &= analyzer.saveLibrary(library.melodic, melodicDir);
    success &= analyzer.saveLibrary(library.textures, texturesDir);
    success &= analyzer.saveLibrary(library.fx, fxDir);
    success &= analyzer.saveLibrary(library.vocals, vocalsDir);

    // Save metadata
    juce::XmlElement xml("HybridLibrary");
    xml.setAttribute("name", library.name);
    xml.setAttribute("description", library.description);
    xml.setAttribute("producerStyle", (int)library.producerStyle);

    auto statsXml = xml.createNewChildElement("Stats");
    statsXml->setAttribute("totalProcessed", library.stats.totalSamplesProcessed);
    statsXml->setAttribute("kept", library.stats.samplesKept);
    statsXml->setAttribute("rejected", library.stats.samplesRejected);
    statsXml->setAttribute("originalSize", (int)library.stats.originalSizeBytes);
    statsXml->setAttribute("optimizedSize", (int)library.stats.optimizedSizeBytes);
    statsXml->setAttribute("compressionRatio", library.stats.compressionRatio);
    statsXml->setAttribute("processingTime", library.stats.processingTime);

    auto metadataFile = outputDirectory.getChildFile("library_metadata.xml");
    success &= xml.writeTo(metadataFile);

    return success;
}

CategorizedModelLibrary HybridProducerStyleIntegration::loadOptimizedLibrary(
    const juce::File& libraryDirectory)
{
    CategorizedModelLibrary library;

    // Load metadata
    auto metadataFile = libraryDirectory.getChildFile("library_metadata.xml");
    if (metadataFile.exists())
    {
        auto xml = juce::XmlDocument::parse(metadataFile);
        if (xml)
        {
            library.name = xml->getStringAttribute("name");
            library.description = xml->getStringAttribute("description");
            library.producerStyle = (ProducerStyle)xml->getIntAttribute("producerStyle");

            auto statsXml = xml->getChildByName("Stats");
            if (statsXml)
            {
                library.stats.totalSamplesProcessed = statsXml->getIntAttribute("totalProcessed");
                library.stats.samplesKept = statsXml->getIntAttribute("kept");
                library.stats.samplesRejected = statsXml->getIntAttribute("rejected");
                library.stats.originalSizeBytes = statsXml->getIntAttribute("originalSize");
                library.stats.optimizedSizeBytes = statsXml->getIntAttribute("optimizedSize");
                library.stats.compressionRatio = statsXml->getDoubleAttribute("compressionRatio");
                library.stats.processingTime = statsXml->getStringAttribute("processingTime");
            }
        }
    }

    // Load each category (would need individual model loading - simplified here)
    // In production, would iterate through each directory and load models

    return library;
}

bool HybridProducerStyleIntegration::exportStatisticsReport(
    const CategorizedModelLibrary& library,
    const juce::File& reportFile)
{
    juce::String report;

    report << "==============================================\n";
    report << "ECHOELMUSIC HYBRID LIBRARY PROCESSING REPORT\n";
    report << "==============================================\n\n";

    report << "Library Name: " << library.name << "\n";
    report << "Producer Style: " << getProducerStyleName(library.producerStyle) << "\n\n";

    report << "PROCESSING STATISTICS:\n";
    report << "----------------------\n";
    report << "Total Samples Processed: " << library.stats.totalSamplesProcessed << "\n";
    report << "Samples Kept: " << library.stats.samplesKept << "\n";
    report << "Samples Rejected: " << library.stats.samplesRejected << "\n";
    report << "Processing Time: " << library.stats.processingTime << "\n\n";

    report << "SIZE OPTIMIZATION:\n";
    report << "------------------\n";
    report << "Original Size: " << juce::File::descriptionOfSizeInBytes(library.stats.originalSizeBytes) << "\n";
    report << "Optimized Size: " << juce::File::descriptionOfSizeInBytes(library.stats.optimizedSizeBytes) << "\n";

    if (library.stats.originalSizeBytes > 0)
    {
        float ratio = (float)library.stats.optimizedSizeBytes / (float)library.stats.originalSizeBytes;
        float reduction = (1.0f - ratio) * 100.0f;
        report << "Compression Ratio: " << juce::String(ratio * 100.0f, 2) << "%\n";
        report << "Size Reduction: " << juce::String(reduction, 2) << "%\n";
    }

    report << "\nCATEGORY BREAKDOWN:\n";
    report << "-------------------\n";
    report << "Drums: " << library.drums.size() << " samples\n";
    report << "Bass: " << library.bass.size() << " samples\n";
    report << "Melodic: " << library.melodic.size() << " samples\n";
    report << "Textures: " << library.textures.size() << " samples\n";
    report << "FX: " << library.fx.size() << " samples\n";
    report << "Vocals: " << library.vocals.size() << " samples\n";
    report << "Total: " << library.getTotalCount() << " samples\n\n";

    report << "==============================================\n";

    return reportFile.replaceWithText(report);
}

//==============================================================================
// Google Drive Integration
//==============================================================================

bool HybridProducerStyleIntegration::downloadFromGoogleDrive(
    const juce::String& driveURL,
    const juce::File& downloadPath,
    std::function<void(float)> progressCallback)
{
    // NOTE: In production, this would use proper Google Drive API
    // For now, this is a placeholder that assumes manual download

    juce::ignoreUnused(driveURL, downloadPath, progressCallback);

    // User would manually download and provide path
    return false;
}

std::map<juce::String, juce::Array<juce::File>> HybridProducerStyleIntegration::detectLibraryStructure(
    const juce::File& libraryRoot)
{
    std::map<juce::String, juce::Array<juce::File>> structure;

    // Common category folder names
    std::vector<std::pair<juce::String, std::vector<juce::String>>> categories = {
        {"drums", {"drums", "percussion", "beats", "drum"}},
        {"bass", {"bass", "sub", "808"}},
        {"melodic", {"melodic", "melody", "synth", "keys", "piano"}},
        {"textures", {"texture", "atmosphere", "ambient", "pad"}},
        {"fx", {"fx", "effects", "sfx", "sound effects"}},
        {"vocals", {"vocal", "voice", "vox"}}
    };

    // Scan for category folders
    for (const auto& [categoryKey, keywords] : categories)
    {
        for (const auto& keyword : keywords)
        {
            auto folder = libraryRoot.getChildFile(keyword);
            if (folder.exists() && folder.isDirectory())
            {
                auto files = folder.findChildFiles(
                    juce::File::findFiles,
                    true, // recursive
                    "*.wav;*.aiff;*.mp3;*.flac;*.ogg"
                );
                structure[categoryKey] = files;
                break;
            }
        }
    }

    return structure;
}

//==============================================================================
// Utilities
//==============================================================================

juce::String HybridProducerStyleIntegration::estimateProcessingTime(int numSamples) const
{
    // Rough estimate: 1 second per sample
    int seconds = numSamples;
    int minutes = seconds / 60;
    int hours = minutes / 60;

    if (hours > 0)
        return juce::String(hours) + " hours";
    else if (minutes > 0)
        return juce::String(minutes) + " minutes";
    else
        return juce::String(seconds) + " seconds";
}

juce::StringArray HybridProducerStyleIntegration::getSupportedFormats() const
{
    return {"WAV", "AIFF", "MP3", "FLAC", "OGG"};
}

//==============================================================================
// Helpers
//==============================================================================

juce::String HybridProducerStyleIntegration::categorizeSample(
    const juce::String& filename,
    const SynthesisModel& model)
{
    juce::String lower = filename.toLowerCase();

    // Check filename keywords
    if (lower.contains("kick") || lower.contains("bd"))
        return "drums";
    if (lower.contains("snare") || lower.contains("sd"))
        return "drums";
    if (lower.contains("hat") || lower.contains("hh"))
        return "drums";
    if (lower.contains("808") || lower.contains("bass"))
        return "bass";
    if (lower.contains("pad") || lower.contains("atmosphere"))
        return "textures";
    if (lower.contains("fx") || lower.contains("effect"))
        return "fx";
    if (lower.contains("vocal") || lower.contains("voice"))
        return "vocals";

    // Use analysis to categorize
    if (!model.category.isEmpty() && model.category != "unknown")
        return model.category;

    // Fallback based on spectral analysis
    if (model.spectral.fundamentalFreq < 100.0f)
        return "bass";
    else if (model.timbre.brightness > 0.7f)
        return "drums";
    else if (model.envelope.attack > 0.5f)
        return "textures";
    else
        return "melodic";
}

float HybridProducerStyleIntegration::calculateSimilarity(
    const SynthesisModel& a,
    const SynthesisModel& b)
{
    float similarity = 0.0f;
    int factors = 0;

    // Pitch similarity
    if (a.spectral.fundamentalFreq > 0.0f && b.spectral.fundamentalFreq > 0.0f)
    {
        float pitchRatio = std::min(a.spectral.fundamentalFreq, b.spectral.fundamentalFreq) /
                          std::max(a.spectral.fundamentalFreq, b.spectral.fundamentalFreq);
        similarity += pitchRatio;
        factors++;
    }

    // Timbre similarity
    float timbreDiff = std::abs(a.timbre.brightness - b.timbre.brightness) +
                      std::abs(a.timbre.warmth - b.timbre.warmth) +
                      std::abs(a.timbre.presence - b.timbre.presence);
    similarity += (1.0f - juce::jlimit(0.0f, 1.0f, timbreDiff / 3.0f));
    factors++;

    // Envelope similarity
    float envDiff = std::abs(a.envelope.attack - b.envelope.attack) +
                   std::abs(a.envelope.decay - b.envelope.decay) +
                   std::abs(a.envelope.sustain - b.envelope.sustain) +
                   std::abs(a.envelope.release - b.envelope.release);
    similarity += (1.0f - juce::jlimit(0.0f, 1.0f, envDiff / 4.0f));
    factors++;

    if (factors > 0)
        return similarity / factors;

    return 0.0f;
}

float HybridProducerStyleIntegration::computeDiversityScore(
    const std::vector<SynthesisModel>& models)
{
    if (models.size() < 2)
        return 0.0f;

    float totalDissimilarity = 0.0f;
    int comparisons = 0;

    for (size_t i = 0; i < models.size(); ++i)
    {
        for (size_t j = i + 1; j < models.size(); ++j)
        {
            float similarity = calculateSimilarity(models[i], models[j]);
            totalDissimilarity += (1.0f - similarity);
            comparisons++;
        }
    }

    if (comparisons > 0)
        return totalDissimilarity / comparisons;

    return 0.0f;
}

void HybridProducerStyleIntegration::updateStatistics(
    ProcessingStats& stats,
    const std::vector<SynthesisModel>& models)
{
    if (models.empty())
        return;

    // Calculate average quality
    float totalQuality = 0.0f;
    float totalCompression = 0.0f;

    for (const auto& model : models)
    {
        totalQuality += model.analysisQuality;
        totalCompression += model.compressionRatio;
    }

    stats.avgAnalysisQuality = totalQuality / models.size();
    stats.avgCompressionRatio = totalCompression / models.size();

    if (stats.originalSizeBytes > 0)
    {
        stats.compressionRatio = (float)stats.optimizedSizeBytes / (float)stats.originalSizeBytes;
    }
}
