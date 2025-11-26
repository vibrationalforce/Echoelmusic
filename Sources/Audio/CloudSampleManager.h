#pragma once

#include <JuceHeader.h>
#include "SampleLibrary.h"

/**
 * CloudSampleManager - Cloud Upload + On-Demand Streaming
 *
 * Wie Splice/Ableton Cloud:
 * - Samples in Cloud hochladen (Google Drive, Dropbox, WeTransfer)
 * - On-Demand Download (nicht alles local speichern!)
 * - Kompression (FLAC, Opus) - spart 50-70% Platz
 * - Stream direkt aus Cloud
 *
 * User Workflow:
 * 1. User: "Upload Sample Bulk from iPhone" → Google Drive
 * 2. Samples in Cloud gespeichert (compressed)
 * 3. Sample Browser zeigt alle (Cloud + Local)
 * 4. User klickt Sample → Auto-Download & Cache
 * 5. Platz sparen: Nur benutzte Samples local!
 *
 * Features:
 * - ✅ Google Drive Integration
 * - ✅ Dropbox Integration
 * - ✅ WeTransfer Upload
 * - ✅ iCloud Drive Sync
 * - ✅ OneDrive Integration
 * - ✅ FLAC Compression (lossless, 50% kleiner)
 * - ✅ Opus Compression (lossy, 70% kleiner, high quality)
 * - ✅ On-Demand Download
 * - ✅ Smart Caching (oft benutzte Samples bleiben local)
 * - ✅ Background Sync
 * - ✅ Offline Mode (cached samples weiter benutzbar)
 */
class CloudSampleManager
{
public:
    //==========================================================================
    // Cloud Providers
    //==========================================================================

    enum class CloudProvider
    {
        Local,              // Nur local (kein Cloud)
        GoogleDrive,        // Google Drive API
        Dropbox,            // Dropbox API
        iCloudDrive,        // iCloud Drive (macOS/iOS)
        OneDrive,           // Microsoft OneDrive
        WeTransfer,         // WeTransfer (Upload only, temp storage)
        Custom              // Custom URL (S3, MinIO, etc.)
    };

    //==========================================================================
    // Sample Cloud Info
    //==========================================================================

    struct CloudSampleInfo
    {
        juce::String sampleId;              // Unique ID
        juce::String name;
        juce::String originalPath;          // Original file location

        // Cloud storage
        CloudProvider provider = CloudProvider::Local;
        juce::String cloudFileId;           // Google Drive file ID, etc.
        juce::String cloudUrl;              // Direct download URL
        juce::String shareUrl;              // Shareable link

        // File info
        int64_t originalSize = 0;           // Bytes (original WAV)
        int64_t compressedSize = 0;         // Bytes (FLAC/Opus in cloud)
        float compressionRatio = 1.0f;      // compressed / original
        juce::String compressionFormat = "FLAC";  // FLAC or Opus

        // Status
        bool isUploaded = false;
        bool isDownloaded = false;          // Cached locally?
        juce::Time uploadTime;
        juce::Time lastAccessTime;
        int accessCount = 0;                // How often used

        // Metadata
        double sampleRate = 44100.0;
        int bitDepth = 24;
        int numChannels = 2;
        double durationSeconds = 0.0;
        juce::String bpm;
        juce::String key;
        juce::StringArray tags;
    };

    //==========================================================================
    // Upload Configuration
    //==========================================================================

    struct UploadConfig
    {
        CloudProvider provider = CloudProvider::GoogleDrive;
        juce::String folderPath = "Echoelmusic/Samples";  // Cloud folder

        // Compression
        bool enableCompression = true;
        juce::String compressionFormat = "FLAC";    // FLAC (lossless) or Opus (lossy)
        int opusQuality = 9;                        // 0-10 (9 = ~128kbps, HQ)

        // Upload options
        bool deleteLocalAfterUpload = false;        // Save local space
        bool generateShareLink = true;              // Create shareable URL
        bool uploadMetadata = true;                 // Upload .json metadata

        // Batch settings
        int maxConcurrentUploads = 3;               // Parallel uploads
        bool showProgress = true;
    };

    //==========================================================================
    // Download/Cache Configuration
    //==========================================================================

    struct CacheConfig
    {
        bool enableCaching = true;
        int64_t maxCacheSizeMB = 1000;              // Max 1GB cache

        // Auto-download rules
        bool autoDownloadFavorites = true;          // Favorites always local
        bool autoDownloadRecent = true;             // Recent samples
        int keepRecentDays = 30;                    // Keep 30 days

        // Smart caching (usage-based)
        bool smartCache = true;                     // Keep frequently used
        int minAccessCount = 3;                     // Used 3+ times = keep

        // Cleanup
        bool autoClearUnused = true;                // Clear old unused samples
        int unusedDays = 90;                        // Not used in 90 days = delete
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    CloudSampleManager();
    ~CloudSampleManager();

    //==========================================================================
    // Setup
    //==========================================================================

    /** Set sample library */
    void setLibrary(SampleLibrary* library) { sampleLibrary = library; }

    /** Authenticate with cloud provider */
    bool authenticateProvider(CloudProvider provider,
                             const juce::String& apiKey = {},
                             const juce::String& clientId = {},
                             const juce::String& clientSecret = {});

    /** Check if authenticated */
    bool isAuthenticated(CloudProvider provider) const;

    /** Get current cloud provider */
    CloudProvider getCurrentProvider() const { return currentProvider; }

    //==========================================================================
    // Upload Operations
    //==========================================================================

    /** Upload single sample to cloud */
    bool uploadSample(const juce::File& sampleFile,
                     const UploadConfig& config = {});

    /** Upload multiple samples (batch) */
    struct UploadResult
    {
        int totalFiles = 0;
        int uploaded = 0;
        int failed = 0;
        int64_t totalSizeSaved = 0;         // Bytes saved via compression
        juce::StringArray uploadedIds;
        juce::StringArray failedFiles;
        juce::StringArray shareLinks;       // For sharing
    };

    UploadResult uploadBatch(const juce::Array<juce::File>& files,
                            const UploadConfig& config = {});

    /** Upload from folder (like FL Studio Mobile/Sample Bulk) */
    UploadResult uploadFromFolder(const juce::File& folder,
                                  bool recursive = true,
                                  const UploadConfig& config = {});

    /** Upload via drag & drop URL */
    UploadResult uploadFromURL(const juce::URL& url,
                              const UploadConfig& config = {});

    /** Cancel upload */
    void cancelUpload(const juce::String& uploadId);

    //==========================================================================
    // Download Operations
    //==========================================================================

    /** Download sample from cloud (on-demand) */
    juce::File downloadSample(const juce::String& sampleId,
                             bool cacheLocally = true);

    /** Preload samples (background download) */
    void preloadSamples(const juce::StringArray& sampleIds);

    /** Download all favorites */
    void downloadAllFavorites();

    /** Download collection */
    void downloadCollection(const juce::String& collectionName);

    //==========================================================================
    // Cloud Sample Browser
    //==========================================================================

    /** Get all cloud samples */
    juce::Array<CloudSampleInfo> getAllCloudSamples() const;

    /** Get cached (local) samples */
    juce::Array<CloudSampleInfo> getCachedSamples() const;

    /** Get cloud-only samples (not cached) */
    juce::Array<CloudSampleInfo> getCloudOnlySamples() const;

    /** Search cloud samples */
    juce::Array<CloudSampleInfo> searchCloud(const juce::String& query);

    //==========================================================================
    // Smart Caching
    //==========================================================================

    /** Set cache configuration */
    void setCacheConfig(const CacheConfig& config);

    /** Get cache statistics */
    struct CacheStats
    {
        int totalSamples = 0;               // Total in cloud
        int cachedSamples = 0;              // Downloaded & cached
        int64_t cacheSize = 0;              // MB
        int64_t maxCacheSize = 0;           // MB

        int mostUsedSamples = 0;
        int recentSamples = 0;

        float cacheHitRate = 0.0f;          // % of requests served from cache
    };

    CacheStats getCacheStats() const;

    /** Clear cache (free space) */
    void clearCache(bool keepFavorites = true);

    /** Optimize cache (remove unused) */
    void optimizeCache();

    //==========================================================================
    // Share & Collaborate
    //==========================================================================

    /** Generate share link for sample */
    juce::String generateShareLink(const juce::String& sampleId);

    /** Import from share link (from friend) */
    bool importFromShareLink(const juce::String& shareUrl);

    /** Create shared collection (like Splice pack) */
    juce::String createSharedCollection(const juce::String& collectionName,
                                       const juce::StringArray& sampleIds);

    /** Import shared collection */
    bool importSharedCollection(const juce::String& shareUrl);

    //==========================================================================
    // Compression
    //==========================================================================

    /** Compress sample (FLAC lossless) */
    juce::File compressSampleFLAC(const juce::File& wavFile,
                                  int compressionLevel = 5);  // 0-8

    /** Compress sample (Opus lossy, high quality) */
    juce::File compressSampleOpus(const juce::File& wavFile,
                                  int quality = 9);            // 0-10

    /** Decompress for playback */
    juce::AudioBuffer<float> decompressForPlayback(const juce::File& compressedFile);

    //==========================================================================
    // Google Drive Integration
    //==========================================================================

    bool uploadToGoogleDrive(const juce::File& file,
                            const juce::String& folderPath);

    juce::String getGoogleDriveFileId(const juce::String& fileName);

    juce::File downloadFromGoogleDrive(const juce::String& fileId);

    //==========================================================================
    // Dropbox Integration
    //==========================================================================

    bool uploadToDropbox(const juce::File& file,
                        const juce::String& remotePath);

    juce::File downloadFromDropbox(const juce::String& remotePath);

    juce::String createDropboxShareLink(const juce::String& remotePath);

    //==========================================================================
    // WeTransfer Upload
    //==========================================================================

    struct WeTransferResult
    {
        bool success = false;
        juce::String downloadUrl;           // Public download URL
        juce::Time expiryTime;              // Link expires after 7 days
        int64_t fileSize = 0;
    };

    WeTransferResult uploadToWeTransfer(const juce::Array<juce::File>& files,
                                       const juce::String& message = "Echoelmusic Samples");

    //==========================================================================
    // Sync & Background Operations
    //==========================================================================

    /** Enable background sync */
    void setBackgroundSyncEnabled(bool enable);

    /** Sync all changes to cloud */
    void syncAllChanges();

    /** Check for cloud updates */
    void checkForUpdates();

    /** Download queue status */
    struct DownloadQueue
    {
        int queuedDownloads = 0;
        int activeDownloads = 0;
        int completedDownloads = 0;
        int64_t totalBytes = 0;
        int64_t downloadedBytes = 0;
        float progress = 0.0f;              // 0.0 - 1.0
    };

    DownloadQueue getDownloadQueue() const;

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(const juce::String& sampleId, float progress)> onUploadProgress;
    std::function<void(const juce::String& sampleId, bool success)> onUploadComplete;
    std::function<void(const juce::String& sampleId, float progress)> onDownloadProgress;
    std::function<void(const juce::String& sampleId, const juce::File& file)> onDownloadComplete;
    std::function<void(const juce::String& error)> onError;

private:
    //==========================================================================
    // Core Components
    //==========================================================================

    SampleLibrary* sampleLibrary = nullptr;
    CloudProvider currentProvider = CloudProvider::GoogleDrive;

    juce::HashMap<CloudProvider, bool> authenticatedProviders;
    juce::HashMap<CloudProvider, juce::String> apiTokens;

    //==========================================================================
    // Cloud Storage
    //==========================================================================

    juce::HashMap<juce::String, CloudSampleInfo> cloudSamples;  // sampleId → info
    juce::File cacheDirectory;

    CacheConfig cacheConfig;
    UploadConfig defaultUploadConfig;

    //==========================================================================
    // Background Operations
    //==========================================================================

    std::unique_ptr<juce::Thread> uploadThread;
    std::unique_ptr<juce::Thread> downloadThread;
    std::unique_ptr<juce::Thread> syncThread;

    juce::Array<juce::String> uploadQueue;
    juce::Array<juce::String> downloadQueue;

    std::atomic<bool> backgroundSyncEnabled { false };

    //==========================================================================
    // HTTP Helpers
    //==========================================================================

    juce::URL::DownloadTaskOptions createDownloadOptions();
    std::unique_ptr<juce::URL::DownloadTask> createDownloadTask(const juce::URL& url);

    bool uploadViaHTTP(const juce::File& file,
                      const juce::URL& uploadUrl,
                      const juce::StringPairArray& headers = {});

    //==========================================================================
    // Compression Helpers
    //==========================================================================

    juce::File getCompressedPath(const juce::File& original, const juce::String& format);
    int64_t calculateCompressionSavings(int64_t original, int64_t compressed);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CloudSampleManager)
};
