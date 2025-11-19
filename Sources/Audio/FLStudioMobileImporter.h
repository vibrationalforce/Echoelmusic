#pragma once

#include <JuceHeader.h>
#include "SampleImportPipeline.h"

/**
 * FLStudioMobileImporter - Direct Import from FL Studio Mobile
 *
 * Automatically finds and imports from:
 * - FL Studio Mobile/MySamples/Sample Bulk/
 * - FL Studio Mobile/Audio Clips/
 * - FL Studio Mobile/Recordings/
 * - Any custom folder
 *
 * No need for "MySamples" folder - just point to any directory!
 *
 * Usage:
 * ```cpp
 * FLStudioMobileImporter importer;
 * importer.setLibrary(&sampleLibrary);
 *
 * // Auto-detect FL Studio Mobile folder
 * auto result = importer.importFromFLStudioMobile();
 *
 * // Or specify custom folder
 * auto result = importer.importFromFolder("/path/to/Sample Bulk");
 * ```
 */
class FLStudioMobileImporter
{
public:
    //==========================================================================
    // FL Studio Mobile Detection
    //==========================================================================

    /** Detect FL Studio Mobile installation folders */
    struct FLStudioMobilePaths
    {
        juce::File appDataFolder;           // Main FL Studio Mobile data
        juce::File mySamplesFolder;         // MySamples folder
        juce::File sampleBulkFolder;        // Sample Bulk subfolder
        juce::File audioClipsFolder;        // Audio Clips
        juce::File recordingsFolder;        // Recordings

        juce::Array<juce::File> customFolders;  // User-added folders

        bool isValid() const { return appDataFolder.exists(); }

        juce::Array<juce::File> getAllFolders() const
        {
            juce::Array<juce::File> all;
            if (mySamplesFolder.exists()) all.add(mySamplesFolder);
            if (sampleBulkFolder.exists()) all.add(sampleBulkFolder);
            if (audioClipsFolder.exists()) all.add(audioClipsFolder);
            if (recordingsFolder.exists()) all.add(recordingsFolder);
            all.addArray(customFolders);
            return all;
        }
    };

    //==========================================================================
    // Constructor
    //==========================================================================

    FLStudioMobileImporter();
    ~FLStudioMobileImporter();

    //==========================================================================
    // Setup
    //==========================================================================

    /** Set target sample library */
    void setLibrary(SampleLibrary* library);

    /** Get import pipeline */
    SampleImportPipeline* getPipeline() { return &pipeline; }

    //==========================================================================
    // FL Studio Mobile Import
    //==========================================================================

    /** Auto-detect and import from FL Studio Mobile */
    SampleImportPipeline::ImportResult importFromFLStudioMobile(
        SampleProcessor::TransformPreset preset = SampleProcessor::TransformPreset::RandomMedium);

    /** Import from specific FL Studio Mobile subfolder */
    SampleImportPipeline::ImportResult importFromFLSubfolder(
        const juce::String& subfolderName,
        SampleProcessor::TransformPreset preset = SampleProcessor::TransformPreset::RandomMedium);

    /** Import from Sample Bulk folder */
    SampleImportPipeline::ImportResult importSampleBulk(
        SampleProcessor::TransformPreset preset = SampleProcessor::TransformPreset::RandomMedium);

    //==========================================================================
    // Generic Import (Any Folder)
    //==========================================================================

    /** Import from ANY folder (not just FL Studio Mobile) */
    SampleImportPipeline::ImportResult importFromFolder(
        const juce::String& folderPath,
        SampleProcessor::TransformPreset preset = SampleProcessor::TransformPreset::RandomMedium);

    /** Import from juce::File */
    SampleImportPipeline::ImportResult importFromFolder(
        const juce::File& folder,
        SampleProcessor::TransformPreset preset = SampleProcessor::TransformPreset::RandomMedium);

    //==========================================================================
    // Detection
    //==========================================================================

    /** Detect FL Studio Mobile paths */
    FLStudioMobilePaths detectFLStudioMobile();

    /** Check if FL Studio Mobile is installed */
    bool isFLStudioMobileInstalled();

    /** Get FL Studio Mobile root folder */
    juce::File getFLStudioMobileFolder();

    /** Scan for all audio folders in FL Studio Mobile */
    juce::Array<juce::File> scanFLStudioMobileAudioFolders();

    //==========================================================================
    // Statistics
    //==========================================================================

    /** Get sample count in FL Studio Mobile */
    int getFLStudioMobileSampleCount();

    /** Get folder statistics */
    struct FolderStats
    {
        juce::File folder;
        int sampleCount = 0;
        int64_t totalSize = 0;
        juce::StringArray fileTypes;

        juce::String getSummary() const
        {
            return folder.getFileName() + ": " +
                   juce::String(sampleCount) + " samples, " +
                   juce::File::descriptionOfSizeInBytes(totalSize);
        }
    };

    juce::Array<FolderStats> getFLStudioMobileFolderStats();

private:
    //==========================================================================
    // Core Components
    //==========================================================================

    SampleImportPipeline pipeline;

    //==========================================================================
    // Platform-Specific Paths
    //==========================================================================

    juce::File getDefaultFLStudioMobileFolder();
    juce::Array<juce::File> getCommonFLStudioMobilePaths();

    //==========================================================================
    // Helpers
    //==========================================================================

    FolderStats analyzeFolderContents(const juce::File& folder);
    int countAudioFiles(const juce::File& folder, bool recursive = true);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FLStudioMobileImporter)
};
