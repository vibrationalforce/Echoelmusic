#pragma once

#include <JuceHeader.h>
#include <functional>
#include <memory>

/**
 * SampleLibrary - Sample Management & Organization System
 *
 * Complete sample library management like Splice/Loopcloud:
 * - Automatic sample scanning & indexing
 * - Audio analysis (BPM, key, duration, type)
 * - Tag-based search & filtering
 * - Collections & favorites
 * - Integration with EchoelSampler & EchoelChopper
 * - Community upload (Phase 2)
 *
 * Features:
 * - Multi-threaded sample scanning
 * - SQLite database for metadata
 * - Smart auto-categorization (AI-powered)
 * - Drag & drop support
 * - Cloud sync ready (Phase 2)
 *
 * Use Cases:
 * - Organize thousands of samples
 * - Quick search by tags, BPM, key
 * - Auto-map samples to sampler
 * - Slice loops in chopper
 */
class SampleLibrary
{
public:
    //==========================================================================
    // Sample Metadata
    //==========================================================================

    struct SampleMetadata
    {
        juce::File file;
        juce::String name;
        juce::String path;

        // Audio Properties
        double sampleRate = 0.0;
        int bitDepth = 0;
        int numChannels = 0;
        double durationSeconds = 0.0;
        int64_t fileSizeBytes = 0;

        // Musical Properties
        double bpm = 0.0;                    // Auto-detected tempo
        juce::String key;                    // Musical key (C, Am, etc.)
        juce::String scale;                  // Major, Minor, etc.

        // Classification
        juce::String category;               // Drums, Bass, Synths, FX, Vocals, Loops
        juce::String subcategory;            // Kick, Snare, Lead, Pad, etc.
        juce::StringArray tags;              // Custom tags
        juce::String character;              // Dark, Bright, Warm, Aggressive
        juce::String genre;                  // Techno, House, Hip-Hop, etc.

        // User Data
        bool isFavorite = false;
        int useCount = 0;
        juce::Time lastUsed;
        juce::Time dateAdded;
        int rating = 0;                      // 0-5 stars

        // Community (Phase 2)
        juce::String author;
        juce::String packName;
        bool isRoyaltyFree = true;

        // Waveform Cache
        juce::Image waveformThumbnail;       // For browser display

        juce::String getUniqueID() const;
        juce::var toJSON() const;
        static SampleMetadata fromJSON(const juce::var& json);
    };

    //==========================================================================
    // Search & Filter
    //==========================================================================

    struct SearchCriteria
    {
        juce::String searchText;             // Free-text search

        // Filters
        juce::StringArray categories;        // Match any of these
        juce::StringArray subcategories;
        juce::StringArray tags;
        juce::StringArray genres;

        // Ranges
        double minBPM = 0.0;
        double maxBPM = 999.0;
        double minDuration = 0.0;
        double maxDuration = 999.0;
        int minRating = 0;

        // Flags
        bool favoritesOnly = false;
        bool untaggedOnly = false;
        bool recentlyUsed = false;           // Last 30 days

        // Sort
        enum class SortBy
        {
            Name,
            DateAdded,
            LastUsed,
            UseCount,
            BPM,
            Duration,
            Rating
        };

        SortBy sortBy = SortBy::Name;
        bool ascending = true;

        int maxResults = 1000;
    };

    //==========================================================================
    // Collection System
    //==========================================================================

    struct Collection
    {
        juce::String name;
        juce::String description;
        juce::Colour color;
        juce::StringArray sampleIDs;         // References to samples
        juce::Time dateCreated;

        juce::var toJSON() const;
        static Collection fromJSON(const juce::var& json);
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    SampleLibrary();
    ~SampleLibrary();

    //==========================================================================
    // Library Management
    //==========================================================================

    /** Set root samples directory */
    void setRootDirectory(const juce::File& directory);

    /** Get root directory */
    juce::File getRootDirectory() const { return rootDirectory; }

    /** Scan directory for samples (async) */
    void scanDirectory(const juce::File& directory, bool recursive = true);

    /** Rescan entire library */
    void rescanLibrary();

    /** Cancel ongoing scan */
    void cancelScan();

    /** Check if scan is in progress */
    bool isScanning() const { return scanning; }

    /** Get scan progress (0.0 - 1.0) */
    float getScanProgress() const { return scanProgress; }

    //==========================================================================
    // Sample Operations
    //==========================================================================

    /** Add sample to library */
    bool addSample(const juce::File& file);

    /** Remove sample from library */
    bool removeSample(const juce::String& sampleID);

    /** Get sample metadata */
    SampleMetadata getSampleMetadata(const juce::String& sampleID) const;

    /** Update sample metadata */
    bool updateSampleMetadata(const juce::String& sampleID, const SampleMetadata& metadata);

    /** Get all samples */
    juce::Array<SampleMetadata> getAllSamples() const;

    /** Get total sample count */
    int getSampleCount() const { return sampleDatabase.size(); }

    //==========================================================================
    // Search & Filter
    //==========================================================================

    /** Search samples */
    juce::Array<SampleMetadata> searchSamples(const SearchCriteria& criteria) const;

    /** Quick text search */
    juce::Array<SampleMetadata> quickSearch(const juce::String& searchText) const;

    /** Get samples by category */
    juce::Array<SampleMetadata> getSamplesByCategory(const juce::String& category) const;

    /** Get favorite samples */
    juce::Array<SampleMetadata> getFavoriteSamples() const;

    /** Get recently used samples */
    juce::Array<SampleMetadata> getRecentlyUsedSamples(int days = 30) const;

    /** Get most used samples */
    juce::Array<SampleMetadata> getMostUsedSamples(int count = 100) const;

    //==========================================================================
    // Collections
    //==========================================================================

    /** Create collection */
    bool createCollection(const juce::String& name);

    /** Delete collection */
    bool deleteCollection(const juce::String& name);

    /** Add sample to collection */
    bool addToCollection(const juce::String& collectionName, const juce::String& sampleID);

    /** Remove from collection */
    bool removeFromCollection(const juce::String& collectionName, const juce::String& sampleID);

    /** Get all collections */
    juce::Array<Collection> getAllCollections() const;

    /** Get collection samples */
    juce::Array<SampleMetadata> getCollectionSamples(const juce::String& collectionName) const;

    //==========================================================================
    // Auto-Analysis
    //==========================================================================

    /** Analyze sample (BPM, key, type, etc.) */
    SampleMetadata analyzeSample(const juce::File& file);

    /** Auto-categorize sample */
    void autoCategorize(SampleMetadata& metadata);

    /** Detect BPM */
    double detectBPM(const juce::AudioBuffer<float>& audio, double sampleRate);

    /** Detect musical key */
    juce::String detectKey(const juce::AudioBuffer<float>& audio, double sampleRate);

    /** Detect sample type (kick, snare, etc.) */
    juce::String detectType(const juce::AudioBuffer<float>& audio);

    /** Generate waveform thumbnail */
    juce::Image generateWaveform(const juce::File& file, int width, int height);

    //==========================================================================
    // Favorites & Ratings
    //==========================================================================

    /** Toggle favorite */
    void toggleFavorite(const juce::String& sampleID);

    /** Set rating */
    void setRating(const juce::String& sampleID, int rating);

    /** Increment use count */
    void incrementUseCount(const juce::String& sampleID);

    //==========================================================================
    // Import / Export
    //==========================================================================

    /** Import sample pack (ZIP) */
    bool importSamplePack(const juce::File& zipFile);

    /** Export collection as pack */
    bool exportCollection(const juce::String& collectionName, const juce::File& outputZip);

    /** Import metadata from JSON */
    bool importMetadata(const juce::File& jsonFile);

    /** Export metadata to JSON */
    bool exportMetadata(const juce::File& jsonFile);

    //==========================================================================
    // Database Operations
    //==========================================================================

    /** Save database to disk */
    bool saveDatabase();

    /** Load database from disk */
    bool loadDatabase();

    /** Get database file */
    juce::File getDatabaseFile() const;

    /** Rebuild database */
    void rebuildDatabase();

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(int samplesFound)> onScanProgress;
    std::function<void(bool success)> onScanComplete;
    std::function<void(const SampleMetadata& sample)> onSampleAdded;
    std::function<void(const juce::String& sampleID)> onSampleRemoved;
    std::function<void(const juce::String& error)> onError;

    //==========================================================================
    // Statistics
    //==========================================================================

    struct LibraryStats
    {
        int totalSamples = 0;
        int totalCollections = 0;
        int64_t totalSizeBytes = 0;
        double totalDurationSeconds = 0.0;

        int drums = 0;
        int bass = 0;
        int synths = 0;
        int fx = 0;
        int vocals = 0;
        int loops = 0;

        int favorites = 0;
        int untagged = 0;

        juce::String getMostUsedCategory() const;
        juce::String formatTotalSize() const;
        juce::String formatTotalDuration() const;
    };

    LibraryStats getStatistics() const;

private:
    //==========================================================================
    // Storage
    //==========================================================================

    juce::File rootDirectory;
    juce::HashMap<juce::String, SampleMetadata> sampleDatabase;
    juce::Array<Collection> collections;

    //==========================================================================
    // Scanning
    //==========================================================================

    std::atomic<bool> scanning { false };
    std::atomic<float> scanProgress { 0.0f };
    std::atomic<bool> shouldCancelScan { false };

    void scanDirectoryInternal(const juce::File& directory, bool recursive);
    void processSampleFile(const juce::File& file);

    //==========================================================================
    // File Watching (for auto-rescan)
    //==========================================================================

    std::unique_ptr<juce::FileSystemWatcher> fileWatcher;
    void fileSystemChanged();

    //==========================================================================
    // Helpers
    //==========================================================================

    bool isSupportedAudioFile(const juce::File& file) const;
    juce::String generateSampleID(const juce::File& file) const;
    juce::String extractCategoryFromPath(const juce::File& file) const;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SampleLibrary)
};
