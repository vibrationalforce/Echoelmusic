#include "SampleImportPipeline.h"
#include <cmath>

//==============================================================================
// Constructor / Destructor
//==============================================================================

SampleImportPipeline::SampleImportPipeline()
{
    processor = std::make_unique<SampleProcessor>();
    DBG("SampleImportPipeline: Initialized");
}

SampleImportPipeline::~SampleImportPipeline()
{
    cancelImport();
}

//==============================================================================
// MySamples Workflow
//==============================================================================

juce::File SampleImportPipeline::getMySamplesFolder() const
{
    return juce::File::getCurrentWorkingDirectory().getChildFile("MySamples");
}

juce::Array<juce::File> SampleImportPipeline::scanMySamples(bool includeSubfolders)
{
    juce::Array<juce::File> samples;
    auto mySamplesFolder = getMySamplesFolder();

    if (!mySamplesFolder.exists())
        return samples;

    juce::DirectoryIterator iter(mySamplesFolder, includeSubfolders,
                                 "*.wav;*.mp3;*.flac;*.ogg;*.aiff;*.m4a",
                                 juce::File::findFiles);

    while (iter.next())
    {
        samples.add(iter.getFile());
    }

    return samples;
}

int SampleImportPipeline::getUnimportedSampleCount()
{
    auto samples = scanMySamples(true);
    int unimportedCount = 0;

    for (const auto& sample : samples)
    {
        if (!isDuplicate(sample))
            unimportedCount++;
    }

    return unimportedCount;
}

SampleImportPipeline::ImportResult SampleImportPipeline::importMySamples(
    SampleProcessor::TransformPreset preset)
{
    auto mySamplesFolder = getMySamplesFolder();

    if (!mySamplesFolder.exists())
    {
        ImportResult result;
        result.success = false;
        result.errorMessages.add("MySamples folder not found: " + mySamplesFolder.getFullPathName());
        return result;
    }

    // Configure import with defaults for MySamples
    ImportConfig config;
    config.sourceFolder = mySamplesFolder;
    config.preset = preset;
    config.enableTransformation = true;
    config.autoOrganize = true;
    config.createCollections = true;
    config.collectionName = generateCollectionName(mySamplesFolder);
    config.moveToProcessed = true;
    config.preserveOriginal = false;

    return importFromFolder(mySamplesFolder, config);
}

//==============================================================================
// Import Operations
//==============================================================================

SampleImportPipeline::ImportResult SampleImportPipeline::importFromFolder(
    const juce::File& folder,
    SampleProcessor::TransformPreset preset)
{
    ImportConfig config;
    config.sourceFolder = folder;
    config.preset = preset;
    config.collectionName = generateCollectionName(folder);

    return importFromFolder(folder, config);
}

SampleImportPipeline::ImportResult SampleImportPipeline::importFromFolder(
    const juce::File& folder,
    const ImportConfig& config)
{
    if (importing)
    {
        ImportResult result;
        result.success = false;
        result.errorMessages.add("Import already in progress");
        return result;
    }

    if (!sampleLibrary)
    {
        ImportResult result;
        result.success = false;
        result.errorMessages.add("No SampleLibrary set");
        return result;
    }

    importing = true;
    shouldCancel = false;
    progress = 0.0f;
    currentConfig = config;

    ImportResult result;
    result.startTime = juce::Time::getCurrentTime();

    // Scan source folder
    currentOperation = "Scanning folder...";
    DBG("SampleImportPipeline: Scanning " << folder.getFullPathName());

    auto sourceFiles = scanMySamples(config.scanRecursive);
    result.totalFiles = sourceFiles.size();

    if (sourceFiles.isEmpty())
    {
        result.success = false;
        result.errorMessages.add("No audio files found in source folder");
        importing = false;
        return result;
    }

    DBG("SampleImportPipeline: Found " << sourceFiles.size() << " files");

    // Build processing queue
    processingQueue.clear();

    for (const auto& sourceFile : sourceFiles)
    {
        // Check duplicates
        if (config.checkDuplicates && isDuplicate(sourceFile))
        {
            result.duplicates++;
            DBG("  Skipping duplicate: " << sourceFile.getFileName());

            if (config.skipDuplicates)
                continue;
        }

        // Create processing task
        ProcessingTask task;
        task.sourceFile = sourceFile;
        task.settings = SampleProcessor::ProcessingSettings::fromPreset(config.preset);
        task.settings.trimSilence = config.trimSilence;

        // Determine target category (quick detection from filename)
        auto musicalInfo = processor->extractMusicalInfo(sourceFile.getFileNameWithoutExtension());
        task.targetCategory = "OneShots";  // Default

        processingQueue.add(task);
    }

    DBG("SampleImportPipeline: Processing " << processingQueue.size() << " samples");

    // Process samples (multi-threaded)
    juce::StringArray importedSampleIDs;
    juce::Thread::launch([this, config, &result, &importedSampleIDs]()
    {
        int totalTasks = processingQueue.size();

        for (int i = 0; i < totalTasks; ++i)
        {
            if (shouldCancel)
                break;

            const auto& task = processingQueue[i];
            progress = static_cast<float>(i) / totalTasks;

            currentOperation = "Processing: " + task.sourceFile.getFileName();

            if (onProgress)
                onProgress(i + 1, totalTasks);

            // Transform sample
            bool success = false;

            if (config.enableTransformation)
            {
                success = transformSample(task);
            }
            else
            {
                // Just copy without transformation
                auto targetFile = getTargetFolder(task.targetCategory)
                    .getChildFile(task.sourceFile.getFileName());
                success = task.sourceFile.copyFileTo(targetFile);
                task.sourceFile = targetFile;  // Update for import
            }

            if (success)
            {
                // Import to library
                juce::String sampleID = importToLibrary(task.targetFile, task.targetCategory);

                if (sampleID.isNotEmpty())
                {
                    importedSampleIDs.add(sampleID);
                    result.imported++;

                    if (config.enableTransformation)
                        result.transformed++;

                    // Generate metadata
                    if (config.generateWaveforms || config.analyzeAudio)
                        generateMetadata(sampleID);

                    // Organize
                    if (config.autoOrganize)
                        organizeImportedSample(sampleID);

                    if (onSampleImported)
                        onSampleImported(sampleID, true);

                    DBG("  ✅ Imported: " << task.sourceFile.getFileName() << " → " << sampleID);
                }
                else
                {
                    result.errors++;
                    result.errorMessages.add("Failed to import: " + task.sourceFile.getFileName());

                    if (onError)
                        onError("Import failed: " + task.sourceFile.getFileName());
                }
            }
            else
            {
                result.errors++;
                result.errorMessages.add("Failed to process: " + task.sourceFile.getFileName());

                if (onError)
                    onError("Processing failed: " + task.sourceFile.getFileName());

                if (config.pauseOnError)
                    break;
            }

            updateStatistics(task, success);
        }

        // Create collection
        if (config.createCollections && !importedSampleIDs.isEmpty())
        {
            currentOperation = "Creating collection...";
            result.collectionName = config.collectionName.isEmpty() ?
                                   generateCollectionName(config.sourceFolder) :
                                   config.collectionName;

            if (createImportCollection(importedSampleIDs, result.collectionName))
            {
                DBG("  ✅ Created collection: " << result.collectionName);
            }
        }

        // Move/delete source files if requested
        if (config.moveToProcessed && !config.preserveOriginal)
        {
            currentOperation = "Cleaning up source files...";
            // Files already moved during transformation
        }

        result.endTime = juce::Time::getCurrentTime();
        result.success = !shouldCancel && result.imported > 0;
        result.importedSampleIDs = importedSampleIDs;

        importing = false;
        progress = 1.0f;

        if (onImportComplete)
            onImportComplete(result);

        DBG("SampleImportPipeline: Import complete!");
        DBG(result.getSummary());
    });

    // Wait for completion (in real GUI, this would be async)
    while (importing)
        juce::Thread::sleep(100);

    return result;
}

SampleImportPipeline::ImportResult SampleImportPipeline::importFromPhone(
    SampleProcessor::TransformPreset preset)
{
    // Detect phone folders
    auto phoneFolders = processor->detectPhoneFolders();

    if (phoneFolders.isEmpty())
    {
        ImportResult result;
        result.success = false;
        result.errorMessages.add("No phone detected. Please connect via USB.");
        return result;
    }

    // Use first detected phone folder
    auto phoneFolder = phoneFolders[0];
    DBG("SampleImportPipeline: Importing from phone: " << phoneFolder.getFullPathName());

    ImportConfig config;
    config.sourceFolder = phoneFolder;
    config.preset = preset;
    config.enableTransformation = true;
    config.autoOrganize = true;
    config.createCollections = true;
    config.collectionName = "Phone Import " + juce::Time::getCurrentTime().toString(false, true);
    config.preserveOriginal = true;  // Don't delete from phone!

    return importFromFolder(phoneFolder, config);
}

void SampleImportPipeline::cancelImport()
{
    shouldCancel = true;

    while (importing)
        juce::Thread::sleep(100);
}

//==============================================================================
// Import Pipeline Steps
//==============================================================================

bool SampleImportPipeline::transformSample(const ProcessingTask& task)
{
    // Generate output filename
    auto outputName = processor->generateCreativeName(
        task.sourceFile,
        task.settings,
        task.targetCategory,
        0  // Auto-generate unique ID
    );

    // Get target folder
    auto targetFolder = getTargetFolder(task.targetCategory);
    if (!targetFolder.exists())
        targetFolder.createDirectory();

    juce::File outputFile = targetFolder.getChildFile(outputName).withFileExtension(".wav");

    // Process
    auto result = processor->processSample(task.sourceFile, outputFile, task.settings);

    if (result.success)
    {
        // Update task with output file
        const_cast<ProcessingTask&>(task).targetFile = outputFile;
        return true;
    }

    return false;
}

juce::String SampleImportPipeline::importToLibrary(const juce::File& file,
                                                   const juce::String& category)
{
    if (!sampleLibrary)
        return {};

    // Add to library
    if (sampleLibrary->addSample(file))
    {
        // Get sample ID
        auto metadata = sampleLibrary->getSampleMetadata(file.getFullPathName());
        return metadata.getUniqueID();
    }

    return {};
}

void SampleImportPipeline::organizeImportedSample(const juce::String& sampleID)
{
    if (!sampleLibrary)
        return;

    auto metadata = sampleLibrary->getSampleMetadata(sampleID);

    // Move to appropriate category folder
    if (metadata.category.isNotEmpty())
    {
        moveSampleToCategory(sampleID, metadata.category);
    }
}

void SampleImportPipeline::generateMetadata(const juce::String& sampleID)
{
    if (!sampleLibrary)
        return;

    auto metadata = sampleLibrary->getSampleMetadata(sampleID);

    // Generate waveform thumbnail
    if (currentConfig.generateWaveforms)
    {
        metadata.waveformThumbnail = processor->generateWaveform(metadata.file, 512, 64);
    }

    // Analyze audio properties
    if (currentConfig.analyzeAudio)
    {
        // BPM, key detection etc. would go here
        // For now, rely on filename extraction
    }

    sampleLibrary->updateSampleMetadata(sampleID, metadata);
}

//==============================================================================
// Organization
//==============================================================================

void SampleImportPipeline::organizeSamples(const juce::StringArray& sampleIDs)
{
    for (const auto& sampleID : sampleIDs)
    {
        organizeImportedSample(sampleID);
    }
}

bool SampleImportPipeline::moveSampleToCategory(const juce::String& sampleID,
                                                const juce::String& category)
{
    if (!sampleLibrary)
        return false;

    auto metadata = sampleLibrary->getSampleMetadata(sampleID);
    auto targetFolder = getTargetFolder(category);

    if (!targetFolder.exists())
        targetFolder.createDirectory();

    auto targetFile = targetFolder.getChildFile(metadata.file.getFileName());

    if (metadata.file.moveFileTo(targetFile))
    {
        metadata.file = targetFile;
        metadata.path = targetFile.getFullPathName();
        metadata.category = category;
        sampleLibrary->updateSampleMetadata(sampleID, metadata);
        return true;
    }

    return false;
}

bool SampleImportPipeline::createImportCollection(const juce::StringArray& sampleIDs,
                                                  const juce::String& collectionName)
{
    if (!sampleLibrary)
        return false;

    if (sampleLibrary->createCollection(collectionName))
    {
        for (const auto& sampleID : sampleIDs)
        {
            sampleLibrary->addToCollection(collectionName, sampleID);
        }

        statistics.lastImportCollection = collectionName;
        return true;
    }

    return false;
}

//==============================================================================
// Duplicate Detection
//==============================================================================

bool SampleImportPipeline::isDuplicate(const juce::File& file)
{
    return !findExistingSample(file).isEmpty();
}

juce::String SampleImportPipeline::findExistingSample(const juce::File& file)
{
    // Simple duplicate check based on filename and size
    // Real implementation would use perceptual hashing

    if (!sampleLibrary)
        return {};

    auto allSamples = sampleLibrary->getAllSamples();

    for (const auto& sample : allSamples)
    {
        if (sample.file.getFileName() == file.getFileName() &&
            sample.file.getSize() == file.getSize())
        {
            return sample.getUniqueID();
        }
    }

    return {};
}

juce::StringArray SampleImportPipeline::findDuplicates()
{
    // TODO: Implement comprehensive duplicate detection
    return {};
}

juce::String SampleImportPipeline::calculateFileHash(const juce::File& file)
{
    // Simple hash based on filename + size + modification time
    juce::String hashInput = file.getFileName() +
                            juce::String(file.getSize()) +
                            juce::String(file.getLastModificationTime().toMilliseconds());

    return juce::String(hashInput.hashCode64());
}

//==============================================================================
// Cleanup & Maintenance
//==============================================================================

bool SampleImportPipeline::clearMySamplesFolder(bool moveToTrash)
{
    auto mySamplesFolder = getMySamplesFolder();

    if (!mySamplesFolder.exists())
        return false;

    auto files = scanMySamples(false);

    for (const auto& file : files)
    {
        if (moveToTrash)
            file.moveToTrash();
        else
            file.deleteFile();
    }

    return true;
}

int SampleImportPipeline::removeDuplicates(bool keepNewest)
{
    // TODO: Implement duplicate removal
    return 0;
}

void SampleImportPipeline::rebuildThumbnails()
{
    if (!sampleLibrary)
        return;

    auto allSamples = sampleLibrary->getAllSamples();

    for (const auto& sample : allSamples)
    {
        auto thumbnail = processor->generateWaveform(sample.file, 512, 64);
        auto metadata = sample;
        metadata.waveformThumbnail = thumbnail;
        sampleLibrary->updateSampleMetadata(sample.getUniqueID(), metadata);
    }
}

juce::StringArray SampleImportPipeline::verifyLibraryIntegrity()
{
    juce::StringArray missingFiles;

    if (!sampleLibrary)
        return missingFiles;

    auto allSamples = sampleLibrary->getAllSamples();

    for (const auto& sample : allSamples)
    {
        if (!sample.file.existsAsFile())
        {
            missingFiles.add(sample.getUniqueID());
        }
    }

    return missingFiles;
}

//==============================================================================
// Helpers
//==============================================================================

juce::String SampleImportPipeline::generateCollectionName(const juce::File& sourceFolder)
{
    auto timestamp = juce::Time::getCurrentTime().toString(false, true);
    return sourceFolder.getFileName() + " Import " + timestamp;
}

juce::File SampleImportPipeline::getTargetFolder(const juce::String& category)
{
    auto samplesRoot = juce::File::getCurrentWorkingDirectory().getChildFile("Samples");

    if (category == "Drums")
        return samplesRoot.getChildFile("Drums");
    else if (category == "Bass")
        return samplesRoot.getChildFile("Bass");
    else if (category == "Synths")
        return samplesRoot.getChildFile("Synths");
    else if (category == "FX")
        return samplesRoot.getChildFile("FX");
    else if (category == "Vocals")
        return samplesRoot.getChildFile("Vocals");
    else if (category == "Loops")
        return samplesRoot.getChildFile("Loops");
    else
        return samplesRoot.getChildFile("Processed");
}

bool SampleImportPipeline::isSupportedAudioFile(const juce::File& file)
{
    auto extension = file.getFileExtension().toLowerCase();
    return extension == ".wav" ||
           extension == ".mp3" ||
           extension == ".flac" ||
           extension == ".ogg" ||
           extension == ".aiff" ||
           extension == ".m4a";
}

void SampleImportPipeline::updateStatistics(const ProcessingTask& task, bool success)
{
    if (!success)
        return;

    statistics.totalImports++;

    if (currentConfig.enableTransformation)
        statistics.totalTransformations++;

    // Update category distribution
    int* count = statistics.categoryDistribution.contains(task.targetCategory) ?
                &statistics.categoryDistribution.getReference(task.targetCategory) : nullptr;
    if (count)
        (*count)++;
    else
        statistics.categoryDistribution.set(task.targetCategory, 1);

    // Extract musical info
    auto musicalInfo = processor->extractMusicalInfo(task.sourceFile.getFileNameWithoutExtension());

    if (musicalInfo.bpm > 0)
    {
        int* bpmCount = statistics.bpmDistribution.contains(musicalInfo.bpm) ?
                       &statistics.bpmDistribution.getReference(musicalInfo.bpm) : nullptr;
        if (bpmCount)
            (*bpmCount)++;
        else
            statistics.bpmDistribution.set(musicalInfo.bpm, 1);
    }

    if (musicalInfo.genre.isNotEmpty())
    {
        int* genreCount = statistics.genreDistribution.contains(musicalInfo.genre) ?
                         &statistics.genreDistribution.getReference(musicalInfo.genre) : nullptr;
        if (genreCount)
            (*genreCount)++;
        else
            statistics.genreDistribution.set(musicalInfo.genre, 1);
    }

    statistics.lastImportTime = juce::Time::getCurrentTime();
}

//==============================================================================
// Result Formatting
//==============================================================================

juce::String SampleImportPipeline::ImportResult::getSummary() const
{
    juce::String summary;

    summary << "========================================\n";
    summary << "  SAMPLE IMPORT COMPLETE\n";
    summary << "========================================\n\n";

    summary << "Status: " << (success ? "✅ SUCCESS" : "❌ FAILED") << "\n\n";

    summary << "Files:\n";
    summary << "  Total scanned: " << totalFiles << "\n";
    summary << "  Imported: " << imported << "\n";
    summary << "  Transformed: " << transformed << "\n";
    summary << "  Duplicates skipped: " << duplicates << "\n";
    summary << "  Errors: " << errors << "\n\n";

    if (!collectionName.isEmpty())
    {
        summary << "Collection: \"" << collectionName << "\"\n";
        summary << "  Samples: " << importedSampleIDs.size() << "\n\n";
    }

    summary << "Size:\n";
    summary << "  Total: " << juce::File::descriptionOfSizeInBytes(totalSizeBytes) << "\n";
    summary << "  Saved: " << juce::File::descriptionOfSizeInBytes(savedBytes) << "\n\n";

    summary << "Duration: " << juce::String(totalDurationSeconds, 1) << " seconds\n\n";

    auto elapsed = endTime - startTime;
    summary << "Time: " << juce::String(elapsed.inSeconds(), 1) << " seconds\n\n";

    if (!errorMessages.isEmpty())
    {
        summary << "Errors:\n";
        for (const auto& error : errorMessages)
            summary << "  - " << error << "\n";
        summary << "\n";
    }

    summary << "========================================\n";

    return summary;
}

juce::String SampleImportPipeline::ImportStatistics::getReport() const
{
    juce::String report;

    report << "Total imports: " << totalImports << "\n";
    report << "Total transformations: " << totalTransformations << "\n";
    report << "Total space saved: " << juce::File::descriptionOfSizeInBytes(totalSpaceSaved) << "\n\n";

    report << "Category distribution:\n";
    for (auto it = categoryDistribution.begin(); it != categoryDistribution.end(); ++it)
    {
        report << "  " << it.getKey() << ": " << it.getValue() << "\n";
    }

    report << "\nBPM distribution:\n";
    for (auto it = bpmDistribution.begin(); it != bpmDistribution.end(); ++it)
    {
        report << "  " << it.getKey() << " BPM: " << it.getValue() << " samples\n";
    }

    report << "\nGenre distribution:\n";
    for (auto it = genreDistribution.begin(); it != genreDistribution.end(); ++it)
    {
        report << "  " << it.getKey() << ": " << it.getValue() << " samples\n";
    }

    if (lastImportTime != juce::Time())
    {
        report << "\nLast import: " << lastImportTime.toString(true, true) << "\n";
        report << "Last collection: " << lastImportCollection << "\n";
    }

    return report;
}
