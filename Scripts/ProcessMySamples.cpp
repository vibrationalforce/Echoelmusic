/**
 * ProcessMySamples.cpp
 *
 * Example script to process user samples from MySamples folder
 * Demonstrates the complete SampleProcessor workflow:
 * - Automatic scanning
 * - BPM detection from filename
 * - Creative naming
 * - Batch transformation
 * - Auto-categorization
 */

#include "../Sources/Audio/SampleProcessor.h"
#include "../Sources/Audio/SampleLibrary.h"
#include <JuceHeader.h>

void processMySamples()
{
    // Initialize processors
    SampleProcessor processor;
    SampleLibrary library;

    // Folders
    juce::File mySamplesFolder = juce::File::getCurrentWorkingDirectory().getChildFile("MySamples");
    juce::File processedFolder = juce::File::getCurrentWorkingDirectory().getChildFile("Samples/Processed");

    // Create output folder if needed
    if (!processedFolder.exists())
        processedFolder.createDirectory();

    // Check if MySamples exists
    if (!mySamplesFolder.exists())
    {
        DBG("MySamples folder not found! Creating it...");
        mySamplesFolder.createDirectory();
        DBG("Please add your samples to: " << mySamplesFolder.getFullPathName());
        return;
    }

    // Scan for audio files
    juce::Array<juce::File> audioFiles;
    juce::DirectoryIterator iter(mySamplesFolder, true, "*.wav;*.mp3;*.flac;*.ogg;*.aiff", juce::File::findFiles);

    while (iter.next())
    {
        audioFiles.add(iter.getFile());
    }

    if (audioFiles.isEmpty())
    {
        DBG("No audio files found in MySamples folder!");
        return;
    }

    DBG("Found " << audioFiles.size() << " samples to process!");

    // Create batch job with Echoelmusic signature transformation
    SampleProcessor::BatchJob job;
    job.inputFiles = audioFiles;
    job.outputDirectory = processedFolder;

    // Use Random Medium preset for variety (or choose any preset)
    job.settings = SampleProcessor::ProcessingSettings::fromPreset(
        SampleProcessor::TransformPreset::RandomMedium
    );

    // Enable features
    job.generateVelocityLayers = false;  // Set to true for multi-layer samples
    job.autoCategory = true;             // Auto-detect category
    job.preserveOriginal = true;         // Keep original files
    job.outputPrefix = "Echo_";          // Use creative naming system

    // Set up callbacks for progress tracking
    int totalFiles = audioFiles.size();
    processor.onBatchProgress = [totalFiles](int filesProcessed, int total)
    {
        float progress = (static_cast<float>(filesProcessed) / total) * 100.0f;
        DBG("Progress: " << filesProcessed << "/" << total << " (" << juce::String(progress, 1) << "%)");
    };

    processor.onFileProcessed = [](const SampleProcessor::ProcessingResult& result)
    {
        if (result.success)
        {
            DBG("✅ Processed: " << result.outputFile.getFileName());
            DBG("   Category: " << result.category);
            DBG("   Subcategory: " << result.subcategory);

            if (result.tags.size() > 0)
            {
                DBG("   Tags: " << result.tags.joinIntoString(", "));
            }
        }
    };

    processor.onError = [](const juce::String& error)
    {
        DBG("❌ Error: " << error);
    };

    processor.onBatchComplete = [totalFiles](bool success, int filesProcessed)
    {
        if (success)
        {
            DBG("🎉 Batch processing complete! Processed " << filesProcessed << "/" << totalFiles << " files");
            DBG("   Check output in: Samples/Processed/");
        }
        else
        {
            DBG("⚠️ Batch processing cancelled or failed.");
        }
    };

    // Start batch processing
    DBG("Starting batch processing...");
    bool started = processor.processBatch(job);

    if (!started)
    {
        DBG("Failed to start batch processing!");
        return;
    }

    // Wait for completion (in real app, this would be async with UI progress bar)
    DBG("Processing samples in background...");
    while (processor.isBatchRunning())
    {
        juce::Thread::sleep(500);
    }

    // Add processed samples to library
    DBG("\nAdding processed samples to library...");
    library.setRootDirectory(processedFolder);
    library.scanDirectory(processedFolder, true);

    while (library.isScanning())
    {
        juce::Thread::sleep(100);
    }

    // Show statistics
    auto stats = library.getStatistics();
    DBG("\n📊 Library Statistics:");
    DBG("   Total samples: " << stats.totalSamples);
    DBG("   Total size: " << stats.formatTotalSize());
    DBG("   Total duration: " << stats.formatTotalDuration());
    DBG("   Drums: " << stats.drums);
    DBG("   Bass: " << stats.bass);
    DBG("   Synths: " << stats.synths);
    DBG("   FX: " << stats.fx);
    DBG("   Vocals: " << stats.vocals);
    DBG("   Loops: " << stats.loops);

    // Example: Search for kicks
    DBG("\n🔍 Searching for kicks...");
    auto kicks = library.quickSearch("kick");
    DBG("   Found " << kicks.size() << " kick samples");

    for (int i = 0; i < juce::jmin(5, kicks.size()); ++i)
    {
        DBG("   - " << kicks[i].name);
    }

    DBG("\n✨ Processing complete! Your samples are ready to use in Echoelmusic!");
}

//==============================================================================
// Example: Process specific preset types
//==============================================================================

void processWithPreset(const juce::File& sampleFile,
                       SampleProcessor::TransformPreset preset,
                       const juce::File& outputFolder)
{
    SampleProcessor processor;

    juce::String presetName = SampleProcessor::getPresetName(preset);
    DBG("Processing with preset: " << presetName);

    // Generate creative output name
    auto settings = SampleProcessor::ProcessingSettings::fromPreset(preset);
    juce::String outputName = processor.generateCreativeName(sampleFile, settings, "OneShots", 1);
    juce::File outputFile = outputFolder.getChildFile(outputName).withFileExtension(".wav");

    // Process
    auto result = processor.processSample(sampleFile, outputFile, preset);

    if (result.success)
    {
        DBG("✅ Success: " << outputFile.getFileName());
    }
    else
    {
        DBG("❌ Failed: " << result.errorMessage);
    }
}

//==============================================================================
// Example: Analyze BPM from filenames
//==============================================================================

void analyzeSampleBPMs(const juce::File& folder)
{
    SampleProcessor processor;

    DBG("Analyzing BPM from filenames in: " << folder.getFullPathName());

    juce::DirectoryIterator iter(folder, false, "*.wav;*.mp3;*.flac", juce::File::findFiles);

    juce::HashMap<int, int> bpmCounts;  // BPM -> count

    while (iter.next())
    {
        juce::File file = iter.getFile();
        auto musicalInfo = processor.extractMusicalInfo(file.getFileNameWithoutExtension());

        if (musicalInfo.bpm > 0)
        {
            DBG("   " << file.getFileName() << " → " << musicalInfo.bpm << " BPM");

            if (musicalInfo.key.isNotEmpty())
                DBG("      Key: " << musicalInfo.key);
            if (musicalInfo.genre.isNotEmpty())
                DBG("      Genre: " << musicalInfo.genre);
            if (musicalInfo.character.isNotEmpty())
                DBG("      Character: " << musicalInfo.character);

            // Track BPM distribution
            int* count = bpmCounts.contains(musicalInfo.bpm) ?
                        &bpmCounts.getReference(musicalInfo.bpm) : nullptr;
            if (count)
                (*count)++;
            else
                bpmCounts.set(musicalInfo.bpm, 1);
        }
        else
        {
            DBG("   " << file.getFileName() << " → BPM not detected");
        }
    }

    // Show BPM distribution
    DBG("\n📊 BPM Distribution:");
    for (auto it = bpmCounts.begin(); it != bpmCounts.end(); ++it)
    {
        DBG("   " << it.getKey() << " BPM: " << it.getValue() << " samples");
    }
}

//==============================================================================
// Main entry point (example usage)
//==============================================================================

int main(int argc, char* argv[])
{
    // Initialize JUCE
    juce::ScopedJuceInitialiser_GUI juceInit;

    DBG("=======================================================");
    DBG("  ECHOELMUSIC SAMPLE PROCESSOR - MySamples Test");
    DBG("=======================================================\n");

    // Process all samples from MySamples folder
    processMySamples();

    // Optional: Analyze BPM distribution
    juce::File mySamplesFolder = juce::File::getCurrentWorkingDirectory().getChildFile("MySamples");
    if (mySamplesFolder.exists())
    {
        DBG("\n");
        analyzeSampleBPMs(mySamplesFolder);
    }

    DBG("\n=======================================================");
    DBG("  DONE! Check Samples/Processed/ for output");
    DBG("=======================================================");

    return 0;
}
