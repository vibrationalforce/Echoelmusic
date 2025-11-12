#pragma once

#include <JuceHeader.h>
#include "RemoteProcessingEngine.h"

/**
 * EchoelCloudManager
 *
 * Verwaltet Batch-Rendering und Export-Jobs auf Cloud-Servern.
 * Während RemoteProcessingEngine für Real-Time Verarbeitung ist,
 * ist EchoelCloudManager für Offline-Rendering optimiert.
 *
 * Features:
 * - Export ganzer Projekte auf Remote-Server
 * - Paralleles Rendering über multiple Server (Render Farm)
 * - Fortschrittsüberwachung und Resume-Funktion
 * - Automatische Qualitätssicherung (QA checks)
 * - Cloud Storage Integration (S3, Google Drive, Dropbox)
 * - Cost-Aware Rendering (günstigste Server wählen)
 *
 * Anwendungsfälle:
 * - Final Mix Export (24-bit/96kHz) auf Server
 * - Video Rendering (4K/8K) auf GPU-Server
 * - Stem Export (alle Tracks einzeln) parallel
 * - Multiple Format Export (WAV, MP3, AAC, FLAC) gleichzeitig
 * - Master für Streaming-Plattformen (Spotify, Apple Music, etc.)
 *
 * Cloud Providers:
 * - Hetzner Cloud (€0.01/hour für 16-Core Server)
 * - AWS EC2 (on-demand oder spot instances)
 * - Google Cloud Compute
 * - Azure Virtual Machines
 * - Eigener Server (VPS, dediziert)
 */
class EchoelCloudManager
{
public:
    //==========================================================================
    // Render Job Configuration
    //==========================================================================

    enum class RenderFormat
    {
        WAV,            // Lossless WAV
        AIFF,           // Apple lossless
        FLAC,           // Free lossless
        ALAC,           // Apple lossless codec
        MP3_320,        // MP3 high quality
        MP3_192,        // MP3 medium quality
        AAC_256,        // AAC high quality (Apple Music)
        Opus_128,       // Opus high quality
        OggVorbis_256   // Ogg Vorbis
    };

    enum class SampleRate
    {
        SR_44100,
        SR_48000,
        SR_88200,
        SR_96000,
        SR_176400,
        SR_192000
    };

    enum class BitDepth
    {
        Bit_16,
        Bit_24,
        Bit_32_Float
    };

    struct RenderJob
    {
        juce::String jobId;                     // Unique ID
        juce::String projectName;

        // Source
        juce::File projectFile;                 // .echoelmusic project
        juce::File outputDirectory;

        // Format settings
        RenderFormat format = RenderFormat::WAV;
        SampleRate sampleRate = SampleRate::SR_48000;
        BitDepth bitDepth = BitDepth::Bit_24;
        int numChannels = 2;                    // Mono, Stereo, 5.1, 7.1.4, etc.

        // Export options
        bool exportMasterMix = true;
        bool exportStems = false;               // Individual tracks
        bool exportMIDI = false;
        bool applyDithering = true;
        bool applyNormalization = true;
        float targetLUFS = -14.0f;              // Spotify/Apple Music standard

        // Streaming platform masters
        bool exportForSpotify = false;
        bool exportForAppleMusic = false;
        bool exportForYouTube = false;
        bool exportForTidal = false;

        // Video rendering (if project has video)
        bool includeVideo = false;
        juce::String videoCodec = "h265";       // h265, av1, vp9
        int videoBitrate = 20000;               // kbps
        juce::String videoResolution = "1080p"; // 720p, 1080p, 4K, 8K

        // Cloud server preference
        juce::String preferredProvider;         // "hetzner", "aws", "local"
        juce::String serverRegion;              // "eu-central", "us-east-1"
        bool useCostOptimization = true;        // Choose cheapest option

        // Priority
        enum Priority { Low, Normal, High, Urgent };
        Priority priority = Normal;

        // Timing
        juce::Time submissionTime;
        juce::Time estimatedCompletionTime;
        juce::Time actualCompletionTime;

        // Callbacks
        std::function<void(float)> onProgress;  // 0.0 to 1.0
        std::function<void(const juce::File&)> onComplete;
        std::function<void(const juce::String&)> onError;

        // Results
        juce::Array<juce::File> outputFiles;
        juce::String errorMessage;

        // Cost tracking
        float estimatedCost = 0.0f;             // In EUR/USD
        float actualCost = 0.0f;
    };

    //==========================================================================
    // Render Server Info
    //==========================================================================

    struct RenderServer
    {
        juce::String serverId;
        juce::String provider;                  // "hetzner", "aws", "azure", "local"
        juce::String instanceType;              // "cx51", "c5.4xlarge", etc.

        // Specs
        int cpuCores = 0;
        int ramGB = 0;
        juce::String gpuModel;
        bool hasNVEncSupport = false;           // Hardware video encoding

        // Cost
        float costPerHour = 0.0f;               // EUR or USD
        float estimatedRenderSpeed = 1.0f;      // Multiplier (2.0 = 2x faster)

        // Status
        bool isAvailable = true;
        int activeJobs = 0;
        int maxConcurrentJobs = 4;
        float cpuLoad = 0.0f;

        // Network
        juce::String region;
        float latencyMs = 0.0f;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    EchoelCloudManager();
    ~EchoelCloudManager();

    //==========================================================================
    // Server Management
    //==========================================================================

    /** Discover available render servers */
    void discoverRenderServers();

    /** Get list of available servers */
    juce::Array<RenderServer> getAvailableServers() const;

    /** Add custom server (eigener VPS) */
    void addCustomServer(const RenderServer& server);

    /** Remove server */
    void removeServer(const juce::String& serverId);

    /** Set preferred provider */
    void setPreferredProvider(const juce::String& provider);

    //==========================================================================
    // Job Submission
    //==========================================================================

    /** Submit render job */
    juce::String submitRenderJob(RenderJob job);

    /** Cancel job */
    void cancelJob(const juce::String& jobId);

    /** Get job status */
    enum class JobStatus
    {
        Queued,             // Waiting for available server
        Uploading,          // Uploading project files
        Processing,         // Rendering in progress
        Downloading,        // Downloading results
        Completed,          // Finished successfully
        Failed,             // Error occurred
        Cancelled           // User cancelled
    };

    JobStatus getJobStatus(const juce::String& jobId) const;

    /** Get all active jobs */
    juce::Array<RenderJob> getActiveJobs() const;

    /** Get job progress (0.0 to 1.0) */
    float getJobProgress(const juce::String& jobId) const;

    //==========================================================================
    // Batch Operations
    //==========================================================================

    /** Export for all streaming platforms (one-click) */
    juce::Array<juce::String> exportForAllPlatforms(const juce::File& projectFile,
                                                    const juce::File& outputDir);

    /** Parallel stem export (alle Tracks gleichzeitig) */
    juce::String exportStemsParallel(const juce::File& projectFile,
                                     const juce::File& outputDir);

    /** Multi-format export (WAV, MP3, FLAC gleichzeitig) */
    juce::String exportMultipleFormats(const juce::File& projectFile,
                                       const juce::Array<RenderFormat>& formats,
                                       const juce::File& outputDir);

    //==========================================================================
    // Cost Optimization
    //==========================================================================

    /** Estimate rendering cost */
    float estimateRenderCost(const RenderJob& job) const;

    /** Get cheapest available server */
    RenderServer getCheapestServer() const;

    /** Get fastest available server */
    RenderServer getFastestServer() const;

    /** Set maximum budget per job */
    void setMaxBudgetPerJob(float euros);

    /** Get total costs (this session) */
    float getTotalCosts() const;

    //==========================================================================
    // Cloud Storage Integration
    //==========================================================================

    enum class CloudStorage
    {
        Local,              // Local filesystem
        GoogleDrive,
        Dropbox,
        iCloudDrive,
        OneDrive,
        S3,                 // AWS S3
        MinIO,              // Self-hosted S3-compatible
        FTP,
        SFTP
    };

    /** Upload rendered files to cloud storage */
    void uploadToCloud(const juce::File& localFile,
                      CloudStorage storage,
                      const juce::String& remotePath);

    /** Set automatic upload after rendering */
    void setAutoUpload(CloudStorage storage, bool enable);

    //==========================================================================
    // Quality Assurance
    //==========================================================================

    struct QAReport
    {
        bool passed = false;

        // Audio checks
        bool hasClipping = false;
        bool hasSilence = false;
        bool hasDistortion = false;
        float peakLevel = 0.0f;                 // dBFS
        float lufs = 0.0f;                      // LUFS
        float dynamicRange = 0.0f;              // dB

        // File checks
        bool correctFormat = true;
        bool correctSampleRate = true;
        bool correctBitDepth = true;
        int64_t fileSize = 0;                   // bytes

        // Warnings
        juce::StringArray warnings;
        juce::StringArray errors;
    };

    /** Run quality assurance checks on rendered file */
    QAReport runQualityAssurance(const juce::File& renderedFile);

    /** Enable automatic QA after rendering */
    void setAutoQA(bool enable);

    //==========================================================================
    // Render Farm (Multiple Servers)
    //==========================================================================

    /** Enable render farm mode (distribute job across multiple servers) */
    void setRenderFarmEnabled(bool enable);

    /** Set maximum number of servers to use per job */
    void setMaxServersPerJob(int count);

    /** Get render farm statistics */
    struct FarmStats
    {
        int totalServers = 0;
        int activeServers = 0;
        int totalJobsCompleted = 0;
        float averageRenderSpeed = 1.0f;       // Multiplier
        float totalCostSaved = 0.0f;           // EUR/USD
    };

    FarmStats getRenderFarmStats() const;

    //==========================================================================
    // Resume & Recovery
    //==========================================================================

    /** Enable checkpoint/resume (für lange Render-Jobs) */
    void setCheckpointEnabled(bool enable);

    /** Resume failed/cancelled job */
    bool resumeJob(const juce::String& jobId);

    /** Get checkpoint interval (seconds) */
    void setCheckpointInterval(int seconds);

    //==========================================================================
    // Notifications
    //==========================================================================

    /** Enable push notifications when job completes */
    void setPushNotificationsEnabled(bool enable);

    /** Set notification email */
    void setNotificationEmail(const juce::String& email);

    /** Callback for job completion */
    std::function<void(const RenderJob&)> onJobCompleted;

    //==========================================================================
    // Statistics & History
    //==========================================================================

    struct SessionStats
    {
        int totalJobsSubmitted = 0;
        int totalJobsCompleted = 0;
        int totalJobsFailed = 0;

        int64_t totalSamplesRendered = 0;
        float totalRenderTimeHours = 0.0f;
        float totalCost = 0.0f;
        float averageCostPerMinute = 0.0f;

        float fastestRenderSpeed = 0.0f;        // Multiplier
        float averageRenderSpeed = 0.0f;

        juce::Time sessionStartTime;
    };

    SessionStats getSessionStats() const;

    /** Get render history */
    juce::Array<RenderJob> getRenderHistory() const;

    /** Clear history */
    void clearHistory();

private:
    //==========================================================================
    // Internal State
    //==========================================================================

    juce::Array<RenderServer> availableServers;
    juce::HashMap<juce::String, RenderJob> activeJobs;
    juce::Array<RenderJob> jobHistory;

    SessionStats stats;

    bool renderFarmEnabled = false;
    int maxServersPerJob = 4;
    bool autoQA = true;
    bool autoUpload = false;
    CloudStorage defaultCloudStorage = CloudStorage::Local;

    float maxBudget = 10.0f;  // EUR per job

    std::unique_ptr<RemoteProcessingEngine> remoteEngine;

    juce::CriticalSection jobsMutex;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    RenderServer selectOptimalServer(const RenderJob& job) const;
    void uploadProjectToServer(const juce::File& project, const RenderServer& server);
    void downloadResultsFromServer(const juce::String& jobId);
    void processJobLocally(RenderJob& job);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelCloudManager)
};
