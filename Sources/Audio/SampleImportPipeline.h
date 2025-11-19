#pragma once

#include <JuceHeader.h>
#include "SampleProcessor.h"
#include "SampleLibrary.h"
#include <functional>
#include <memory>

/**
 * SampleImportPipeline - Complete Import → Transform → Organize → Ready!
 *
 * ONE-CLICK SAMPLE IMPORT:
 * - Scans MySamples folder (or phone)
 * - Transforms with Echoelmusic signature
 * - Auto-categorizes
 * - Imports to SampleLibrary
 * - Ready to use in EchoelSampler/Chopper!
 *
 * Features:
 * - Automatic folder organization (Drums/Bass/Synths/etc.)
 * - Metadata extraction & tagging
 * - Duplicate detection
 * - Waveform thumbnail generation
 * - Statistics & reporting
 * - Undo support (move to quarantine)
 *
 * Usage:
 * ```cpp
 * SampleImportPipeline pipeline;
 * pipeline.setLibrary(&sampleLibrary);
 * pipeline.importFromFolder(mySamplesFolder, TransformPreset::RandomMedium);
 * ```
 */
class SampleImportPipeline
{
public:
    //==========================================================================
    // Import Configuration
    //==========================================================================

    struct ImportConfig
    {
        // Source
        juce::File sourceFolder;                    // Where to import from
        bool scanRecursive = true;                  // Scan subfolders

        // Transformation
        SampleProcessor::TransformPreset preset = SampleProcessor::TransformPreset::RandomMedium;
        bool enableTransformation = true;           // Transform or just import?
        bool trimSilence = true;                    // Save disk space

        // Organization
        bool autoOrganize = true;                   // Sort into Drums/Bass/etc.
        bool createCollections = true;              // Create collection per import batch
        juce::String collectionName;                // Custom collection name

        // Metadata
        bool extractBPM = true;                     // From filename
        bool extractKey = true;                     // From filename
        bool generateWaveforms = true;              // Create thumbnails
        bool analyzeAudio = true;                   // Deep audio analysis (slower)

        // Duplicates
        bool checkDuplicates = true;                // Avoid re-importing
        bool skipDuplicates = true;                 // Or overwrite?

        // Output
        bool preserveOriginal = false;              // Keep source files
        bool moveToProcessed = true;                // Move from MySamples to Samples/

        // Advanced
        int maxConcurrentProcessing = 4;            // Parallel processing threads
        bool pauseOnError = false;                  // Stop on first error?
    };

    //==========================================================================
    // Import Result
    //==========================================================================

    struct ImportResult
    {
        bool success = false;

        int totalFiles = 0;
        int imported = 0;
        int transformed = 0;
        int duplicates = 0;
        int errors = 0;

        juce::StringArray importedSampleIDs;        // IDs in library
        juce::StringArray errorMessages;
        juce::String collectionName;                // Created collection

        // Statistics
        int64_t totalSizeBytes = 0;
        int64_t savedBytes = 0;                     // From silence trimming
        double totalDurationSeconds = 0.0;

        juce::Time startTime;
        juce::Time endTime;

        juce::String getSummary() const;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SampleImportPipeline();
    ~SampleImportPipeline();

    //==========================================================================
    // Setup
    //==========================================================================

    /** Set target sample library */
    void setLibrary(SampleLibrary* library) { sampleLibrary = library; }

    /** Get current library */
    SampleLibrary* getLibrary() const { return sampleLibrary; }

    //==========================================================================
    // Import Operations
    //==========================================================================

    /** Import from folder (MySamples, phone, etc.) */
    ImportResult importFromFolder(const juce::File& folder,
                                  const ImportConfig& config);

    /** Import from folder with preset (simplified) */
    ImportResult importFromFolder(const juce::File& folder,
                                  SampleProcessor::TransformPreset preset);

    /** Import from phone (USB detection + import) */
    ImportResult importFromPhone(SampleProcessor::TransformPreset preset =
                                SampleProcessor::TransformPreset::RandomMedium);

    /** Import single file */
    bool importSingleFile(const juce::File& file,
                         const ImportConfig& config);

    /** Cancel ongoing import */
    void cancelImport();

    //==========================================================================
    // Progress Tracking
    //==========================================================================

    /** Check if import is running */
    bool isImporting() const { return importing; }

    /** Get progress (0.0 - 1.0) */
    float getProgress() const { return progress; }

    /** Get current operation description */
    juce::String getCurrentOperation() const { return currentOperation; }

    //==========================================================================
    // MySamples Workflow
    //==========================================================================

    /** Quick import from MySamples folder */
    ImportResult importMySamples(SampleProcessor::TransformPreset preset =
                                 SampleProcessor::TransformPreset::RandomMedium);

    /** Get MySamples folder path */
    juce::File getMySamplesFolder() const;

    /** Check if MySamples has new files */
    int getUnimportedSampleCount();

    /** Get list of files in MySamples */
    juce::Array<juce::File> scanMySamples(bool includeSubfolders = true);

    //==========================================================================
    // Organization
    //==========================================================================

    /** Organize imported samples into categories */
    void organizeSamples(const juce::StringArray& sampleIDs);

    /** Move sample to category folder */
    bool moveSampleToCategory(const juce::String& sampleID,
                             const juce::String& category);

    /** Create collection from import batch */
    bool createImportCollection(const juce::StringArray& sampleIDs,
                               const juce::String& collectionName);

    //==========================================================================
    // Duplicate Detection
    //==========================================================================

    /** Check if file already imported */
    bool isDuplicate(const juce::File& file);

    /** Find existing sample by hash */
    juce::String findExistingSample(const juce::File& file);

    /** Get duplicate samples */
    juce::StringArray findDuplicates();

    //==========================================================================
    // Cleanup & Maintenance
    //==========================================================================

    /** Clear MySamples folder (after successful import) */
    bool clearMySamplesFolder(bool moveToTrash = true);

    /** Remove duplicates from library */
    int removeDuplicates(bool keepNewest = true);

    /** Rebuild thumbnails for all samples */
    void rebuildThumbnails();

    /** Verify all sample files exist */
    juce::StringArray verifyLibraryIntegrity();

    //==========================================================================
    // Statistics & Reporting
    //==========================================================================

    struct ImportStatistics
    {
        int totalImports = 0;
        int totalTransformations = 0;
        int64_t totalSpaceSaved = 0;

        juce::HashMap<juce::String, int> categoryDistribution;  // Category → count
        juce::HashMap<int, int> bpmDistribution;                // BPM → count
        juce::HashMap<juce::String, int> genreDistribution;     // Genre → count

        juce::Time lastImportTime;
        juce::String lastImportCollection;

        juce::String getReport() const;
    };

    ImportStatistics getStatistics() const { return statistics; }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(int current, int total)> onProgress;
    std::function<void(const juce::String& operation)> onOperationChange;
    std::function<void(const juce::String& sampleID, bool success)> onSampleImported;
    std::function<void(const ImportResult& result)> onImportComplete;
    std::function<void(const juce::String& error)> onError;

private:
    //==========================================================================
    // Core Components
    //==========================================================================

    SampleLibrary* sampleLibrary = nullptr;
    std::unique_ptr<SampleProcessor> processor;

    //==========================================================================
    // Import State
    //==========================================================================

    std::atomic<bool> importing { false };
    std::atomic<float> progress { 0.0f };
    std::atomic<bool> shouldCancel { false };
    juce::String currentOperation;

    ImportConfig currentConfig;
    ImportStatistics statistics;

    //==========================================================================
    // Processing Queue
    //==========================================================================

    struct ProcessingTask
    {
        juce::File sourceFile;
        juce::File targetFile;
        juce::String targetCategory;
        SampleProcessor::ProcessingSettings settings;
    };

    juce::Array<ProcessingTask> processingQueue;
    juce::CriticalSection queueLock;

    //==========================================================================
    // Duplicate Detection
    //==========================================================================

    juce::HashMap<juce::String, juce::String> fileHashCache;  // Hash → SampleID
    juce::String calculateFileHash(const juce::File& file);

    //==========================================================================
    // Import Pipeline Steps
    //==========================================================================

    void scanSource(const juce::File& folder, bool recursive);
    bool transformSample(const ProcessingTask& task);
    bool importToLibrary(const juce::File& file, const juce::String& category);
    void organizeImportedSample(const juce::String& sampleID);
    void generateMetadata(const juce::String& sampleID);
    void updateStatistics(const ProcessingTask& task, bool success);

    //==========================================================================
    // Helpers
    //==========================================================================

    juce::String generateCollectionName(const juce::File& sourceFolder);
    juce::File getTargetFolder(const juce::String& category);
    bool isSupportedAudioFile(const juce::File& file);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SampleImportPipeline)
};
