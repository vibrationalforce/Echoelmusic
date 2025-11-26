#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>

namespace Eoel {

/**
 * CreatorManager - Content Creator Management System
 *
 * Features:
 * - Creator Profiles & Portfolios
 * - Multi-Platform Analytics (YouTube, Instagram, TikTok, Twitch, Spotify)
 * - Earnings Tracking & Forecasting
 * - Content Library Management
 * - Audience Demographics
 * - Growth Metrics & Insights
 * - Collaboration History
 * - Brand Deal Management
 *
 * Supported Platforms:
 * - YouTube, TikTok, Instagram, Twitter/X
 * - Twitch, Facebook, LinkedIn
 * - Spotify, Apple Music, SoundCloud
 * - Patreon, OnlyFans, Substack
 */
class CreatorManager
{
public:
    enum class CreatorType
    {
        Musician,           // Music producers, artists
        DJ,                 // DJs, live performers
        VideoCreator,       // YouTubers, filmmakers
        Streamer,           // Twitch, YouTube Live
        Podcaster,          // Podcast hosts
        Influencer,         // Instagram, TikTok influencers
        Educator,           // Tutorial creators, teachers
        MultiMedia          // Multiple content types
    };

    enum class Platform
    {
        YouTube,
        TikTok,
        Instagram,
        Twitter,
        Twitch,
        Facebook,
        LinkedIn,
        Spotify,
        AppleMusic,
        SoundCloud,
        Patreon,
        OnlyFans,
        Substack,
        Bandcamp,
        Discord
    };

    struct SocialStats
    {
        Platform platform;
        int followers = 0;
        int subscribers = 0;
        long long totalViews = 0;
        long long totalPlays = 0;
        float engagementRate = 0.0f;    // 0.0 to 1.0
        int averageViews = 0;
        int averageLikes = 0;
        int averageComments = 0;
        juce::String handle;            // @username
        bool verified = false;
    };

    struct AudienceDemographics
    {
        // Age Distribution
        std::map<juce::String, float> ageGroups;  // "13-17", "18-24", etc.

        // Gender
        float malePercent = 0.0f;
        float femalePercent = 0.0f;
        float otherPercent = 0.0f;

        // Top Countries
        std::map<juce::String, float> countries;  // Country code -> percentage

        // Interests
        std::vector<juce::String> topInterests;
    };

    struct EarningsData
    {
        double totalEarnings = 0.0;
        double monthlyAverage = 0.0;

        // Revenue Streams
        double platformRevenue = 0.0;       // YouTube AdSense, Spotify, etc.
        double sponsorshipRevenue = 0.0;    // Brand deals
        double merchandiseRevenue = 0.0;    // Merch sales
        double subscriptionRevenue = 0.0;   // Patreon, memberships
        double donationRevenue = 0.0;       // Donations, tips
        double licensingRevenue = 0.0;      // Music licensing

        // Projections
        double projectedMonthlyEarnings = 0.0;
        double projectedYearlyEarnings = 0.0;
    };

    struct ContentItem
    {
        juce::String title;
        juce::String description;
        Platform platform;
        juce::String url;
        juce::File localFile;
        juce::Time uploadDate;
        juce::Time publishDate;

        int views = 0;
        int likes = 0;
        int comments = 0;
        int shares = 0;

        std::vector<juce::String> tags;
        juce::String category;
        bool isSponsored = false;
        juce::String sponsorName;
    };

    struct CreatorProfile
    {
        juce::String id;                    // Unique ID
        juce::String name;
        juce::String email;
        juce::String bio;
        juce::Image avatar;
        CreatorType type;

        // Social Media
        std::vector<SocialStats> socialStats;

        // Demographics
        AudienceDemographics demographics;

        // Earnings
        EarningsData earnings;

        // Content
        std::vector<ContentItem> portfolio;

        // Niche & Skills
        std::vector<juce::String> niches;       // "Music Production", "Gaming", etc.
        std::vector<juce::String> skills;       // "Video Editing", "Beat Making", etc.
        std::vector<juce::String> languages;

        // Rates & Availability
        double hourlyRate = 0.0;
        double perVideoRate = 0.0;
        double perPostRate = 0.0;
        bool availableForCollabs = true;
        bool acceptsSponsorships = true;

        // Agency Representation
        bool hasAgent = false;
        juce::String agencyId;
        float agencyCommission = 0.15f;     // 15% default

        // Verification
        bool verified = false;
        bool backgroundChecked = false;
    };

    CreatorManager();
    ~CreatorManager();

    // ===========================
    // Creator Management
    // ===========================

    /** Create new creator profile */
    juce::String createCreator(const CreatorProfile& profile);

    /** Update creator profile */
    void updateCreator(const juce::String& creatorId, const CreatorProfile& profile);

    /** Get creator profile */
    CreatorProfile getCreator(const juce::String& creatorId) const;

    /** Delete creator */
    void deleteCreator(const juce::String& creatorId);

    /** Get all creators */
    std::vector<CreatorProfile> getAllCreators() const;

    /** Search creators by filters */
    std::vector<CreatorProfile> searchCreators(
        CreatorType type = CreatorType::MultiMedia,
        int minFollowers = 0,
        const juce::String& niche = "",
        bool verifiedOnly = false
    ) const;

    // ===========================
    // Social Media Integration
    // ===========================

    /** Connect social media account */
    void connectPlatform(const juce::String& creatorId, Platform platform, const juce::String& accessToken);

    /** Disconnect platform */
    void disconnectPlatform(const juce::String& creatorId, Platform platform);

    /** Sync statistics from all connected platforms */
    void syncAllPlatforms(const juce::String& creatorId);

    /** Sync specific platform */
    void syncPlatform(const juce::String& creatorId, Platform platform);

    /** Get real-time stats from API */
    SocialStats fetchPlatformStats(const juce::String& creatorId, Platform platform);

    // ===========================
    // Content Management
    // ===========================

    /** Add content to portfolio */
    void addContent(const juce::String& creatorId, const ContentItem& content);

    /** Remove content */
    void removeContent(const juce::String& creatorId, const juce::String& contentUrl);

    /** Get all content */
    std::vector<ContentItem> getContent(const juce::String& creatorId) const;

    /** Analyze content performance */
    struct ContentAnalytics {
        double averageViews = 0.0;
        double averageEngagement = 0.0;
        juce::String bestPerformingCategory;
        juce::String bestPerformingPlatform;
        std::vector<juce::String> trendingTags;
    };
    ContentAnalytics analyzeContent(const juce::String& creatorId) const;

    // ===========================
    // Earnings & Analytics
    // ===========================

    /** Update earnings data */
    void updateEarnings(const juce::String& creatorId, const EarningsData& earnings);

    /** Get earnings report */
    EarningsData getEarnings(const juce::String& creatorId) const;

    /** Calculate projected earnings */
    double calculateProjectedEarnings(const juce::String& creatorId, int months = 12) const;

    /** Get growth metrics */
    struct GrowthMetrics {
        float followerGrowthRate = 0.0f;       // % per month
        float engagementGrowthRate = 0.0f;
        float earningsGrowthRate = 0.0f;
        juce::String fastestGrowingPlatform;
    };
    GrowthMetrics getGrowthMetrics(const juce::String& creatorId) const;

    // ===========================
    // Audience Insights
    // ===========================

    /** Update audience demographics */
    void updateDemographics(const juce::String& creatorId, const AudienceDemographics& demographics);

    /** Get audience insights */
    AudienceDemographics getDemographics(const juce::String& creatorId) const;

    /** Find similar creators (audience overlap) */
    std::vector<CreatorProfile> findSimilarCreators(const juce::String& creatorId, int limit = 10) const;

    // ===========================
    // Portfolio Export
    // ===========================

    /** Export media kit (PDF) */
    void exportMediaKit(const juce::String& creatorId, const juce::File& outputFile);

    /** Export portfolio as website */
    void exportPortfolioHTML(const juce::String& creatorId, const juce::File& outputDir);

    /** Export analytics report */
    void exportAnalyticsReport(const juce::String& creatorId, const juce::File& outputFile);

    // ===========================
    // Verification & Trust
    // ===========================

    /** Verify creator identity */
    void verifyCreator(const juce::String& creatorId, bool verified);

    /** Run background check */
    void runBackgroundCheck(const juce::String& creatorId);

    /** Get trust score (0-100) */
    int getTrustScore(const juce::String& creatorId) const;

    // ===========================
    // Callbacks
    // ===========================

    std::function<void(const juce::String& creatorId)> onCreatorAdded;
    std::function<void(const juce::String& creatorId)> onCreatorUpdated;
    std::function<void(const juce::String& creatorId, Platform platform)> onPlatformSynced;
    std::function<void(const juce::String& creatorId, const EarningsData& earnings)> onEarningsUpdated;

private:
    std::map<juce::String, CreatorProfile> m_creators;
    juce::CriticalSection m_lock;

    // Platform API connections
    struct PlatformConnection {
        Platform platform;
        juce::String accessToken;
        juce::Time lastSync;
    };
    std::map<juce::String, std::vector<PlatformConnection>> m_platformConnections;

    juce::String generateCreatorId() const;
    void saveToDatabase();
    void loadFromDatabase();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CreatorManager)
};

} // namespace Eoel
