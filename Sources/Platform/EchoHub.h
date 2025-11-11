#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>

/**
 * EchoHub
 *
 * Complete business management, collaboration, and distribution platform.
 * All-in-one solution replacing multiple services.
 *
 * FEATURES:
 *
 * 1. MUSIC DISTRIBUTION
 *    - Distribute to all platforms (Spotify, Apple Music, etc.)
 *    - Automatic ISRC/UPC code generation
 *    - Royalty tracking & payment
 *    - Playlist pitching (AI-powered)
 *    - Release scheduling
 *
 * 2. SOCIAL MEDIA MANAGEMENT
 *    - Multi-platform posting (Instagram, TikTok, YouTube, etc.)
 *    - Content calendar
 *    - Analytics & insights
 *    - AI caption generation
 *    - Hashtag optimization
 *
 * 3. COLLABORATION PLATFORM
 *    - Shared projects (cloud-based)
 *    - Version control for music/video
 *    - Real-time collaboration
 *    - Collab matching (find collaborators)
 *    - Contract templates
 *
 * 4. MARKETPLACE/SAMPLE TRADING
 *    - Buy/Sell samples, presets, projects
 *    - NFT integration
 *    - Royalty-free licensing
 *    - Automatic watermarking for previews
 *
 * 5. BUSINESS MANAGEMENT
 *    - Invoicing & accounting
 *    - Tax calculation (international)
 *    - Expense tracking
 *    - Revenue analytics
 *    - Contract management
 *
 * 6. PROMO & MARKETING
 *    - Email marketing campaigns
 *    - Fan engagement tools
 *    - Press kit generator
 *    - EPK (Electronic Press Kit)
 *    - Radio plugging
 */
class EchoHub
{
public:
    //==========================================================================
    // 1. MUSIC DISTRIBUTION
    //==========================================================================

    struct Release
    {
        juce::String title;
        juce::String artist;
        juce::String album;
        juce::String genre;
        juce::String releaseDate;        // YYYY-MM-DD
        juce::File artworkFile;          // Min 3000x3000px

        std::vector<juce::File> trackFiles;
        std::vector<juce::String> trackTitles;

        // Metadata
        juce::String isrc;               // Auto-generated if empty
        juce::String upc;                // Auto-generated if empty
        juce::String labelName;
        juce::String copyrightYear;
        juce::String copyrightText;

        // Distribution
        std::vector<juce::String> platforms;  // "Spotify", "Apple Music", etc.
        bool preOrderEnabled = false;
        juce::String preOrderDate;

        Release() = default;
    };

    /** Submit release for distribution */
    bool submitRelease(const Release& release);

    /** Get distribution status */
    juce::String getDistributionStatus(const juce::String& releaseId);

    /** Get royalty report */
    struct RoyaltyReport
    {
        juce::String period;             // "2025-01"
        float totalEarnings = 0.0f;      // USD
        std::map<juce::String, float> platformBreakdown;  // Platform -> earnings
        std::map<juce::String, int> streamCounts;

        RoyaltyReport() = default;
    };

    RoyaltyReport getRoyaltyReport(const juce::String& period);

    /** AI-powered playlist pitching */
    std::vector<juce::String> suggestPlaylists(const juce::String& trackId);
    bool pitchToPlaylist(const juce::String& playlistId, const juce::String& trackId);

    //==========================================================================
    // 2. SOCIAL MEDIA MANAGEMENT
    //==========================================================================

    struct SocialPost
    {
        juce::String caption;
        juce::File mediaFile;            // Image/Video
        std::vector<juce::String> hashtags;

        // Platforms
        bool postToInstagram = true;
        bool postToTikTok = true;
        bool postToYouTube = false;
        bool postToTwitter = false;
        bool postToFacebook = false;

        // Scheduling
        bool schedulePost = false;
        juce::String scheduledTime;      // ISO 8601 format

        SocialPost() = default;
    };

    /** Post to social media */
    bool postToSocialMedia(const SocialPost& post);

    /** AI caption generation */
    juce::String generateCaption(const juce::File& mediaFile, const juce::String& context);

    /** Optimize hashtags */
    std::vector<juce::String> optimizeHashtags(const juce::String& caption, int maxCount = 30);

    /** Get analytics */
    struct SocialAnalytics
    {
        int followers = 0;
        int totalReach = 0;
        int engagement = 0;
        float engagementRate = 0.0f;
        std::map<juce::String, int> topPosts;  // Post ID -> likes

        SocialAnalytics() = default;
    };

    SocialAnalytics getSocialAnalytics(const juce::String& platform);

    //==========================================================================
    // 3. COLLABORATION PLATFORM
    //==========================================================================

    struct CollabProject
    {
        juce::String projectId;
        juce::String projectName;
        juce::String owner;
        std::vector<juce::String> collaborators;

        // Permissions
        enum class Permission { View, Edit, Admin };
        std::map<juce::String, Permission> permissions;

        // Version control
        int currentVersion = 1;
        std::vector<juce::String> versionHistory;

        // Files
        juce::File projectFile;

        CollabProject() = default;
    };

    /** Create shared project */
    juce::String createSharedProject(const CollabProject& project);

    /** Invite collaborator */
    bool inviteCollaborator(const juce::String& projectId, const juce::String& email);

    /** Find collaborators (matching) */
    struct CollaboratorProfile
    {
        juce::String name;
        juce::String skills;             // "Producer, Mix Engineer"
        juce::String genres;             // "Techno, House"
        float rating = 0.0f;             // 0.0 to 5.0
        int completedProjects = 0;

        CollaboratorProfile() = default;
    };

    std::vector<CollaboratorProfile> findCollaborators(const juce::String& searchQuery);

    //==========================================================================
    // 4. MARKETPLACE / SAMPLE TRADING
    //==========================================================================

    struct MarketItem
    {
        enum class Type { Sample, Preset, Project, Template, NFT };

        Type type = Type::Sample;
        juce::String title;
        juce::String description;
        float price = 0.0f;              // USD (0.0 = free)
        juce::File itemFile;
        juce::File previewFile;          // Watermarked preview

        // Licensing
        enum class License { RoyaltyFree, Exclusive, Commercial };
        License license = License::RoyaltyFree;

        // Stats
        int downloads = 0;
        float rating = 0.0f;

        MarketItem() = default;
    };

    /** List item on marketplace */
    juce::String listItem(const MarketItem& item);

    /** Search marketplace */
    std::vector<MarketItem> searchMarketplace(const juce::String& query, MarketItem::Type type);

    /** Purchase item */
    bool purchaseItem(const juce::String& itemId);

    //==========================================================================
    // 5. BUSINESS MANAGEMENT
    //==========================================================================

    struct Invoice
    {
        juce::String invoiceNumber;
        juce::String clientName;
        juce::String clientEmail;
        juce::String date;
        juce::String dueDate;

        struct LineItem
        {
            juce::String description;
            int quantity = 1;
            float pricePerUnit = 0.0f;
        };

        std::vector<LineItem> items;

        float subtotal = 0.0f;
        float taxRate = 0.0f;            // Percentage
        float total = 0.0f;

        bool paid = false;

        Invoice() = default;
    };

    /** Create invoice */
    juce::String createInvoice(const Invoice& invoice);

    /** Export invoice PDF */
    bool exportInvoice(const juce::String& invoiceId, const juce::File& outputFile);

    /** Tax calculation */
    struct TaxReport
    {
        juce::String year;
        float totalIncome = 0.0f;
        float totalExpenses = 0.0f;
        float taxableIncome = 0.0f;
        float estimatedTax = 0.0f;

        std::map<juce::String, float> incomeBreakdown;
        std::map<juce::String, float> expenseBreakdown;

        TaxReport() = default;
    };

    TaxReport calculateTaxes(const juce::String& year, const juce::String& country);

    /** Track expenses */
    struct Expense
    {
        juce::String date;
        juce::String category;           // "Equipment", "Marketing", etc.
        juce::String description;
        float amount = 0.0f;
        juce::File receiptFile;

        Expense() = default;
    };

    void addExpense(const Expense& expense);
    std::vector<Expense> getExpenses(const juce::String& period);

    //==========================================================================
    // 6. PROMO & MARKETING
    //==========================================================================

    /** Generate EPK (Electronic Press Kit) */
    struct EPK
    {
        juce::String artistName;
        juce::String bio;
        juce::File pressPhoto;
        std::vector<juce::File> musicSamples;
        juce::String contactEmail;
        juce::String website;
        std::map<juce::String, juce::String> socialLinks;

        EPK() = default;
    };

    bool generateEPK(const EPK& epk, const juce::File& outputFile);

    /** Email marketing campaign */
    struct EmailCampaign
    {
        juce::String subject;
        juce::String content;
        std::vector<juce::String> recipients;
        bool sendImmediately = true;
        juce::String scheduledTime;

        EmailCampaign() = default;
    };

    bool sendEmailCampaign(const EmailCampaign& campaign);

    /** Fan engagement */
    struct FanData
    {
        int totalFans = 0;
        int newFansThisMonth = 0;
        std::map<juce::String, int> topLocations;  // Country -> fan count
        float engagementScore = 0.0f;

        FanData() = default;
    };

    FanData getFanAnalytics();

    //==========================================================================
    // STREAMING/BROADCAST (OBS Alternative)
    //==========================================================================

    struct StreamConfig
    {
        enum class Platform { YouTube, Twitch, Facebook, Custom };

        Platform platform = Platform::YouTube;
        juce::String streamKey;
        juce::String rtmpUrl;

        // Video settings
        int width = 1920;
        int height = 1080;
        int fps = 30;
        int bitrate = 6000;              // Kbps

        // Audio settings
        int audioSampleRate = 48000;
        int audioBitrate = 192;          // Kbps

        StreamConfig() = default;
    };

    /** Start streaming */
    bool startStream(const StreamConfig& config);

    /** Stop streaming */
    void stopStream();

    /** Get stream statistics */
    struct StreamStats
    {
        bool isLive = false;
        int viewerCount = 0;
        double duration = 0.0;           // Seconds
        float bitrate = 0.0f;            // Current bitrate
        int droppedFrames = 0;

        StreamStats() = default;
    };

    StreamStats getStreamStats();

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    EchoHub();
    ~EchoHub() = default;

private:
    //==========================================================================
    // Authentication & API Keys
    //==========================================================================

    juce::String authToken;
    std::map<juce::String, juce::String> platformApiKeys;

    //==========================================================================
    // Database (local cache)
    //==========================================================================

    std::vector<Release> releases;
    std::vector<CollabProject> projects;
    std::vector<MarketItem> marketItems;
    std::vector<Invoice> invoices;
    std::vector<Expense> expenses;

    //==========================================================================
    // Network
    //==========================================================================

    bool sendRequest(const juce::String& endpoint, const juce::String& method,
                    const juce::String& data);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (EchoHub)
};
