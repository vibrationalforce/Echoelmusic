#include "CreatorManager.h"

namespace Eoel {

CreatorManager::CreatorManager()
{
    loadFromDatabase();
    DBG("Creator Manager initialized");
}

CreatorManager::~CreatorManager()
{
    saveToDatabase();
}

// ===========================
// Creator Management
// ===========================

juce::String CreatorManager::createCreator(const CreatorProfile& profile)
{
    juce::ScopedLock sl(m_lock);

    juce::String creatorId = generateCreatorId();
    CreatorProfile newProfile = profile;
    newProfile.id = creatorId;

    m_creators[creatorId] = newProfile;

    DBG("Creator created: " << newProfile.name << " (ID: " << creatorId << ")");

    if (onCreatorAdded)
        onCreatorAdded(creatorId);

    saveToDatabase();

    return creatorId;
}

void CreatorManager::updateCreator(const juce::String& creatorId, const CreatorProfile& profile)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it != m_creators.end())
    {
        it->second = profile;
        it->second.id = creatorId;  // Preserve ID

        DBG("Creator updated: " << creatorId);

        if (onCreatorUpdated)
            onCreatorUpdated(creatorId);

        saveToDatabase();
    }
}

CreatorManager::CreatorProfile CreatorManager::getCreator(const juce::String& creatorId) const
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it != m_creators.end())
        return it->second;

    return CreatorProfile();
}

void CreatorManager::deleteCreator(const juce::String& creatorId)
{
    juce::ScopedLock sl(m_lock);

    m_creators.erase(creatorId);
    m_platformConnections.erase(creatorId);

    DBG("Creator deleted: " << creatorId);
    saveToDatabase();
}

std::vector<CreatorManager::CreatorProfile> CreatorManager::getAllCreators() const
{
    juce::ScopedLock sl(m_lock);

    std::vector<CreatorProfile> creators;
    for (const auto& pair : m_creators)
        creators.push_back(pair.second);

    return creators;
}

std::vector<CreatorManager::CreatorProfile> CreatorManager::searchCreators(
    CreatorType type,
    int minFollowers,
    const juce::String& niche,
    bool verifiedOnly
) const
{
    juce::ScopedLock sl(m_lock);

    std::vector<CreatorProfile> results;

    for (const auto& pair : m_creators)
    {
        const CreatorProfile& creator = pair.second;

        // Filter by type
        if (type != CreatorType::MultiMedia && creator.type != type)
            continue;

        // Filter by verified
        if (verifiedOnly && !creator.verified)
            continue;

        // Filter by followers
        int totalFollowers = 0;
        for (const auto& stats : creator.socialStats)
            totalFollowers += stats.followers + stats.subscribers;

        if (totalFollowers < minFollowers)
            continue;

        // Filter by niche
        if (!niche.isEmpty())
        {
            bool hasNiche = false;
            for (const auto& creatorNiche : creator.niches)
            {
                if (creatorNiche.containsIgnoreCase(niche))
                {
                    hasNiche = true;
                    break;
                }
            }
            if (!hasNiche)
                continue;
        }

        results.push_back(creator);
    }

    DBG("Search found " << results.size() << " creators");

    return results;
}

// ===========================
// Social Media Integration
// ===========================

void CreatorManager::connectPlatform(const juce::String& creatorId, Platform platform, const juce::String& accessToken)
{
    juce::ScopedLock sl(m_lock);

    PlatformConnection connection;
    connection.platform = platform;
    connection.accessToken = accessToken;
    connection.lastSync = juce::Time::getCurrentTime();

    m_platformConnections[creatorId].push_back(connection);

    DBG("Platform connected: " << (int)platform << " for creator " << creatorId);

    // Auto-sync after connecting
    syncPlatform(creatorId, platform);
}

void CreatorManager::disconnectPlatform(const juce::String& creatorId, Platform platform)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_platformConnections.find(creatorId);
    if (it != m_platformConnections.end())
    {
        it->second.erase(
            std::remove_if(it->second.begin(), it->second.end(),
                [platform](const PlatformConnection& conn) {
                    return conn.platform == platform;
                }),
            it->second.end()
        );
    }

    DBG("Platform disconnected: " << (int)platform);
}

void CreatorManager::syncAllPlatforms(const juce::String& creatorId)
{
    auto it = m_platformConnections.find(creatorId);
    if (it == m_platformConnections.end())
        return;

    DBG("Syncing all platforms for creator: " << creatorId);

    for (const auto& connection : it->second)
    {
        syncPlatform(creatorId, connection.platform);
    }
}

void CreatorManager::syncPlatform(const juce::String& creatorId, Platform platform)
{
    juce::ScopedLock sl(m_lock);

    // Fetch stats from platform API
    SocialStats stats = fetchPlatformStats(creatorId, platform);

    // Update creator profile
    auto creatorIt = m_creators.find(creatorId);
    if (creatorIt != m_creators.end())
    {
        // Find existing stats for this platform
        bool found = false;
        for (auto& existingStats : creatorIt->second.socialStats)
        {
            if (existingStats.platform == platform)
            {
                existingStats = stats;
                found = true;
                break;
            }
        }

        if (!found)
            creatorIt->second.socialStats.push_back(stats);
    }

    // Update last sync time
    auto connIt = m_platformConnections.find(creatorId);
    if (connIt != m_platformConnections.end())
    {
        for (auto& connection : connIt->second)
        {
            if (connection.platform == platform)
            {
                connection.lastSync = juce::Time::getCurrentTime();
                break;
            }
        }
    }

    DBG("Platform synced: " << (int)platform);

    if (onPlatformSynced)
        onPlatformSynced(creatorId, platform);

    saveToDatabase();
}

CreatorManager::SocialStats CreatorManager::fetchPlatformStats(const juce::String& creatorId, Platform platform)
{
    // Real implementation would call platform APIs
    // YouTube Data API, Instagram Graph API, TikTok API, etc.

    SocialStats stats;
    stats.platform = platform;

    // Simulate API call
    stats.followers = juce::Random::getSystemRandom().nextInt(juce::Range<int>(1000, 1000000));
    stats.totalViews = juce::Random::getSystemRandom().nextInt64() % 100000000;
    stats.engagementRate = juce::Random::getSystemRandom().nextFloat() * 0.1f;  // 0-10%

    return stats;
}

// ===========================
// Content Management
// ===========================

void CreatorManager::addContent(const juce::String& creatorId, const ContentItem& content)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it != m_creators.end())
    {
        it->second.portfolio.push_back(content);
        DBG("Content added to portfolio: " << content.title);
        saveToDatabase();
    }
}

void CreatorManager::removeContent(const juce::String& creatorId, const juce::String& contentUrl)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it != m_creators.end())
    {
        it->second.portfolio.erase(
            std::remove_if(it->second.portfolio.begin(), it->second.portfolio.end(),
                [&contentUrl](const ContentItem& item) {
                    return item.url == contentUrl;
                }),
            it->second.portfolio.end()
        );

        saveToDatabase();
    }
}

std::vector<CreatorManager::ContentItem> CreatorManager::getContent(const juce::String& creatorId) const
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it != m_creators.end())
        return it->second.portfolio;

    return {};
}

CreatorManager::ContentAnalytics CreatorManager::analyzeContent(const juce::String& creatorId) const
{
    juce::ScopedLock sl(m_lock);

    ContentAnalytics analytics;

    auto it = m_creators.find(creatorId);
    if (it == m_creators.end())
        return analytics;

    const auto& portfolio = it->second.portfolio;

    if (portfolio.empty())
        return analytics;

    // Calculate averages
    long long totalViews = 0;
    long long totalEngagement = 0;
    std::map<juce::String, int> categoryViews;
    std::map<Platform, int> platformViews;
    std::map<juce::String, int> tagFrequency;

    for (const auto& content : portfolio)
    {
        totalViews += content.views;
        totalEngagement += (content.likes + content.comments + content.shares);

        categoryViews[content.category] += content.views;
        platformViews[content.platform] += content.views;

        for (const auto& tag : content.tags)
            tagFrequency[tag]++;
    }

    analytics.averageViews = static_cast<double>(totalViews) / portfolio.size();
    analytics.averageEngagement = static_cast<double>(totalEngagement) / portfolio.size();

    // Find best performing category
    int maxCategoryViews = 0;
    for (const auto& pair : categoryViews)
    {
        if (pair.second > maxCategoryViews)
        {
            maxCategoryViews = pair.second;
            analytics.bestPerformingCategory = pair.first;
        }
    }

    // Find best performing platform
    int maxPlatformViews = 0;
    for (const auto& pair : platformViews)
    {
        if (pair.second > maxPlatformViews)
        {
            maxPlatformViews = pair.second;
            analytics.bestPerformingPlatform = juce::String((int)pair.first);
        }
    }

    // Find trending tags (top 5)
    std::vector<std::pair<juce::String, int>> sortedTags(tagFrequency.begin(), tagFrequency.end());
    std::sort(sortedTags.begin(), sortedTags.end(),
        [](const auto& a, const auto& b) { return a.second > b.second; });

    for (int i = 0; i < std::min(5, (int)sortedTags.size()); ++i)
        analytics.trendingTags.push_back(sortedTags[i].first);

    return analytics;
}

// ===========================
// Earnings & Analytics
// ===========================

void CreatorManager::updateEarnings(const juce::String& creatorId, const EarningsData& earnings)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it != m_creators.end())
    {
        it->second.earnings = earnings;

        DBG("Earnings updated for creator: " << creatorId);
        DBG("  Total: $" << earnings.totalEarnings);

        if (onEarningsUpdated)
            onEarningsUpdated(creatorId, earnings);

        saveToDatabase();
    }
}

CreatorManager::EarningsData CreatorManager::getEarnings(const juce::String& creatorId) const
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it != m_creators.end())
        return it->second.earnings;

    return EarningsData();
}

double CreatorManager::calculateProjectedEarnings(const juce::String& creatorId, int months) const
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it == m_creators.end())
        return 0.0;

    const EarningsData& earnings = it->second.earnings;

    // Simple projection based on monthly average
    return earnings.monthlyAverage * months;
}

CreatorManager::GrowthMetrics CreatorManager::getGrowthMetrics(const juce::String& creatorId) const
{
    juce::ScopedLock sl(m_lock);

    GrowthMetrics metrics;

    // Real implementation would analyze historical data
    // For now, return placeholder

    metrics.followerGrowthRate = 5.0f;      // 5% per month
    metrics.engagementGrowthRate = 3.5f;
    metrics.earningsGrowthRate = 8.0f;
    metrics.fastestGrowingPlatform = "TikTok";

    return metrics;
}

// ===========================
// Audience Insights
// ===========================

void CreatorManager::updateDemographics(const juce::String& creatorId, const AudienceDemographics& demographics)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it != m_creators.end())
    {
        it->second.demographics = demographics;
        DBG("Demographics updated for creator: " << creatorId);
        saveToDatabase();
    }
}

CreatorManager::AudienceDemographics CreatorManager::getDemographics(const juce::String& creatorId) const
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it != m_creators.end())
        return it->second.demographics;

    return AudienceDemographics();
}

std::vector<CreatorManager::CreatorProfile> CreatorManager::findSimilarCreators(
    const juce::String& creatorId,
    int limit
) const
{
    juce::ScopedLock sl(m_lock);

    std::vector<CreatorProfile> similar;

    auto it = m_creators.find(creatorId);
    if (it == m_creators.end())
        return similar;

    const CreatorProfile& targetCreator = it->second;

    // Find creators with similar niches
    for (const auto& pair : m_creators)
    {
        if (pair.first == creatorId)
            continue;

        const CreatorProfile& candidate = pair.second;

        // Check niche overlap
        int nicheOverlap = 0;
        for (const auto& niche : targetCreator.niches)
        {
            for (const auto& candidateNiche : candidate.niches)
            {
                if (niche == candidateNiche)
                    nicheOverlap++;
            }
        }

        if (nicheOverlap > 0)
            similar.push_back(candidate);

        if (similar.size() >= limit)
            break;
    }

    return similar;
}

// ===========================
// Portfolio Export
// ===========================

void CreatorManager::exportMediaKit(const juce::String& creatorId, const juce::File& outputFile)
{
    auto creator = getCreator(creatorId);

    // Real implementation would generate PDF using juce::PDF or external library
    DBG("Exporting media kit for: " << creator.name);
    DBG("  Output: " << outputFile.getFullPathName());

    // Media kit would include:
    // - Profile & Bio
    // - Stats from all platforms
    // - Audience demographics
    // - Content examples
    // - Rates & contact info
}

void CreatorManager::exportPortfolioHTML(const juce::String& creatorId, const juce::File& outputDir)
{
    auto creator = getCreator(creatorId);

    DBG("Exporting portfolio website for: " << creator.name);
    DBG("  Output directory: " << outputDir.getFullPathName());

    // Generate HTML/CSS/JS for portfolio website
}

void CreatorManager::exportAnalyticsReport(const juce::String& creatorId, const juce::File& outputFile)
{
    auto creator = getCreator(creatorId);
    auto analytics = analyzeContent(creatorId);

    DBG("Exporting analytics report for: " << creator.name);
    DBG("  Average views: " << analytics.averageViews);
    DBG("  Best category: " << analytics.bestPerformingCategory);
}

// ===========================
// Verification & Trust
// ===========================

void CreatorManager::verifyCreator(const juce::String& creatorId, bool verified)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it != m_creators.end())
    {
        it->second.verified = verified;
        DBG("Creator verification: " << creatorId << " = " << verified);
        saveToDatabase();
    }
}

void CreatorManager::runBackgroundCheck(const juce::String& creatorId)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it != m_creators.end())
    {
        // Real implementation would integrate with background check services
        it->second.backgroundChecked = true;
        DBG("Background check completed for: " << creatorId);
        saveToDatabase();
    }
}

int CreatorManager::getTrustScore(const juce::String& creatorId) const
{
    juce::ScopedLock sl(m_lock);

    auto it = m_creators.find(creatorId);
    if (it == m_creators.end())
        return 0;

    const CreatorProfile& creator = it->second;

    int score = 50;  // Base score

    // Verified adds 20 points
    if (creator.verified)
        score += 20;

    // Background check adds 15 points
    if (creator.backgroundChecked)
        score += 15;

    // Portfolio size adds points
    score += std::min(10, (int)creator.portfolio.size());

    // Platform connections add points
    score += std::min(5, (int)creator.socialStats.size());

    return std::min(100, score);
}

// ===========================
// Internal
// ===========================

juce::String CreatorManager::generateCreatorId() const
{
    return "creator_" + juce::Uuid().toString().substring(0, 8);
}

void CreatorManager::saveToDatabase()
{
    // Real implementation would save to database (SQLite, PostgreSQL, etc.)
    DBG("Saving creator database...");
}

void CreatorManager::loadFromDatabase()
{
    // Real implementation would load from database
    DBG("Loading creator database...");
}

} // namespace Eoel
