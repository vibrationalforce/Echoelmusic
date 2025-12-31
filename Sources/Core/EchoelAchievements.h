/**
 * EchoelAchievements.h
 *
 * Gamification & Achievement System
 *
 * Make music production fun with achievements:
 * - Skill-based achievements
 * - Creative milestones
 * - Daily/weekly challenges
 * - Streak tracking
 * - XP & leveling system
 * - Badges & trophies
 * - Leaderboards
 * - Progress tracking
 * - Unlockable rewards
 * - Social sharing
 *
 * Part of Ralph Wiggum Genius Loop Mode - Phase 1
 * "I'm learnding!" - Ralph Wiggum
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <set>
#include <memory>
#include <functional>
#include <chrono>
#include <optional>
#include <atomic>
#include <mutex>

namespace Echoel {

// ============================================================================
// Achievement Types
// ============================================================================

enum class AchievementCategory {
    // Beginner
    GettingStarted,     // First steps
    Learning,           // Tutorial completion

    // Production
    Production,         // Creating music
    Mixing,             // Mixing skills
    Mastering,          // Mastering skills
    SoundDesign,        // Creating sounds

    // Quantity
    Prolific,           // Volume of work
    Marathon,           // Long sessions

    // Quality
    Quality,            // High-quality output
    Creative,           // Creative achievements

    // Social
    Collaboration,      // Team work
    Sharing,            // Sharing content
    Community,          // Community engagement

    // Streaks
    Consistency,        // Daily practice
    Dedication,         // Long-term commitment

    // Special
    Secret,             // Hidden achievements
    Event,              // Time-limited events
    Seasonal            // Seasonal achievements
};

enum class AchievementRarity {
    Common,         // Easy to get
    Uncommon,       // Some effort
    Rare,           // Significant effort
    Epic,           // Major accomplishment
    Legendary       // Exceptional achievement
};

enum class AchievementTier {
    Bronze,
    Silver,
    Gold,
    Platinum,
    Diamond
};

// ============================================================================
// Achievement Definition
// ============================================================================

struct Achievement {
    std::string id;
    std::string name;
    std::string description;
    std::string hint;  // Hint for locked achievements

    AchievementCategory category = AchievementCategory::GettingStarted;
    AchievementRarity rarity = AchievementRarity::Common;

    // Visual
    std::string iconName;
    std::string badgeImagePath;
    std::string color;

    // Progress
    bool isProgressive = false;  // Has stages
    int maxProgress = 1;
    std::vector<int> milestones;  // For tiered achievements

    // XP reward
    int xpReward = 10;
    std::map<AchievementTier, int> tierXP;

    // Unlock conditions
    struct Condition {
        std::string type;  // "count", "duration", "streak", "custom"
        std::string metric;
        int threshold = 0;
        std::chrono::seconds timeWindow{0};  // For time-limited
    };
    std::vector<Condition> conditions;

    // Rewards
    std::vector<std::string> unlockedFeatures;
    std::vector<std::string> unlockedContent;
    std::string specialReward;

    // Metadata
    bool isSecret = false;
    bool isRetired = false;  // No longer obtainable
    std::chrono::system_clock::time_point eventStart;
    std::chrono::system_clock::time_point eventEnd;
};

// ============================================================================
// User Achievement Progress
// ============================================================================

struct UserAchievement {
    std::string achievementId;

    int currentProgress = 0;
    AchievementTier currentTier = AchievementTier::Bronze;

    bool isUnlocked = false;
    std::chrono::system_clock::time_point unlockedAt;

    bool isViewed = false;  // Has user seen notification
    bool isShared = false;  // Has user shared

    std::vector<std::chrono::system_clock::time_point> tierUnlockDates;
};

// ============================================================================
// Challenge
// ============================================================================

struct Challenge {
    std::string id;
    std::string name;
    std::string description;

    enum class Duration {
        Daily,
        Weekly,
        Monthly,
        Event
    } duration = Duration::Daily;

    std::chrono::system_clock::time_point startTime;
    std::chrono::system_clock::time_point endTime;

    // Goals
    struct Goal {
        std::string description;
        std::string metric;
        int target = 0;
        int current = 0;
        bool completed = false;
    };
    std::vector<Goal> goals;

    // Rewards
    int xpReward = 0;
    std::string achievementId;  // Optional achievement to unlock
    std::vector<std::string> rewards;

    bool isActive = true;
    bool isCompleted = false;
};

// ============================================================================
// XP & Leveling
// ============================================================================

struct LevelInfo {
    int level = 1;
    int currentXP = 0;
    int xpToNextLevel = 100;
    int totalXP = 0;

    std::string rank;
    std::string title;
    std::string rankIcon;
};

struct XPEvent {
    std::chrono::system_clock::time_point timestamp;
    int amount = 0;
    std::string source;  // What earned the XP
    std::string description;
};

// ============================================================================
// Streaks
// ============================================================================

struct Streak {
    std::string id;
    std::string name;

    enum class Type {
        Daily,          // Must do every day
        Weekly,         // Once per week
        SessionBased    // Per session
    } type = Type::Daily;

    int currentStreak = 0;
    int longestStreak = 0;

    std::chrono::system_clock::time_point lastActivity;
    bool isActiveToday = false;

    // Grace period
    int graceDays = 1;  // Days allowed to miss
    int graceDaysUsed = 0;

    // Milestones
    std::vector<int> milestoneDays;  // e.g., 7, 30, 100, 365
    std::vector<int> reachedMilestones;
};

// ============================================================================
// Leaderboard
// ============================================================================

struct LeaderboardEntry {
    std::string oderId;
    std::string displayName;
    std::string avatarPath;

    int rank = 0;
    int score = 0;
    int level = 0;

    std::string region;
    std::string badge;
};

struct Leaderboard {
    std::string id;
    std::string name;

    enum class Type {
        AllTime,
        Monthly,
        Weekly,
        Daily,
        Friends
    } type = Type::AllTime;

    enum class Metric {
        TotalXP,
        SessionTime,
        ProjectsCompleted,
        TracksCreated,
        AchievementPoints,
        CurrentStreak
    } metric = Metric::TotalXP;

    std::vector<LeaderboardEntry> entries;
    std::optional<LeaderboardEntry> userEntry;

    std::chrono::system_clock::time_point lastUpdated;
};

// ============================================================================
// Achievements Manager
// ============================================================================

class AchievementsManager {
public:
    static AchievementsManager& getInstance() {
        static AchievementsManager instance;
        return instance;
    }

    // ========================================================================
    // Initialization
    // ========================================================================

    void initialize() {
        std::lock_guard<std::mutex> lock(mutex_);
        registerAchievements();
        initializeStreaks();
        loadUserProgress();
        initialized_ = true;
    }

    // ========================================================================
    // Achievement Progress
    // ========================================================================

    void trackProgress(const std::string& metric, int amount = 1) {
        std::lock_guard<std::mutex> lock(mutex_);

        metrics_[metric] += amount;

        // Check all achievements for this metric
        for (auto& [id, achievement] : achievements_) {
            checkAchievement(id);
        }

        // Update streaks
        updateStreaks();
    }

    void checkAchievement(const std::string& achievementId) {
        auto achIt = achievements_.find(achievementId);
        if (achIt == achievements_.end()) return;

        auto& achievement = achIt->second;
        auto& userAch = userAchievements_[achievementId];

        if (userAch.isUnlocked && !achievement.isProgressive) return;

        // Check conditions
        bool allMet = true;
        int progress = 0;

        for (const auto& condition : achievement.conditions) {
            int metricValue = metrics_[condition.metric];

            if (condition.type == "count") {
                if (metricValue < condition.threshold) {
                    allMet = false;
                }
                progress = std::min(metricValue, condition.threshold);
            } else if (condition.type == "streak") {
                auto it = streaks_.find(condition.metric);
                if (it != streaks_.end()) {
                    if (it->second.currentStreak < condition.threshold) {
                        allMet = false;
                    }
                    progress = it->second.currentStreak;
                }
            }
        }

        // Update progress
        if (achievement.isProgressive) {
            userAch.currentProgress = progress;

            // Check tier upgrades
            for (size_t i = 0; i < achievement.milestones.size(); ++i) {
                if (progress >= achievement.milestones[i]) {
                    auto tier = static_cast<AchievementTier>(i);
                    if (tier > userAch.currentTier) {
                        userAch.currentTier = tier;
                        userAch.tierUnlockDates.push_back(std::chrono::system_clock::now());
                        awardXP(achievement.tierXP.count(tier) ? achievement.tierXP.at(tier) : 10,
                                "Achievement tier: " + achievement.name);
                    }
                }
            }
        }

        // Unlock if conditions met
        if (allMet && !userAch.isUnlocked) {
            unlockAchievement(achievementId);
        }
    }

    void unlockAchievement(const std::string& achievementId) {
        auto achIt = achievements_.find(achievementId);
        if (achIt == achievements_.end()) return;

        auto& achievement = achIt->second;
        auto& userAch = userAchievements_[achievementId];

        userAch.isUnlocked = true;
        userAch.unlockedAt = std::chrono::system_clock::now();
        userAch.currentProgress = achievement.maxProgress;

        // Award XP
        awardXP(achievement.xpReward, "Achievement: " + achievement.name);

        // Unlock rewards
        for (const auto& feature : achievement.unlockedFeatures) {
            unlockedFeatures_.insert(feature);
        }

        // Queue notification
        queueNotification(achievementId);
    }

    std::optional<Achievement> getAchievement(const std::string& achievementId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = achievements_.find(achievementId);
        if (it != achievements_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    UserAchievement getUserAchievement(const std::string& achievementId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = userAchievements_.find(achievementId);
        if (it != userAchievements_.end()) {
            return it->second;
        }
        return UserAchievement{};
    }

    std::vector<Achievement> getAchievements(
        std::optional<AchievementCategory> category = std::nullopt,
        bool includeSecret = false) const {

        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Achievement> result;
        for (const auto& [id, achievement] : achievements_) {
            if (category && achievement.category != *category) continue;
            if (achievement.isSecret && !includeSecret) {
                // Only show if unlocked
                auto userIt = userAchievements_.find(id);
                if (userIt == userAchievements_.end() || !userIt->second.isUnlocked) {
                    continue;
                }
            }
            if (achievement.isRetired) continue;

            result.push_back(achievement);
        }

        return result;
    }

    std::vector<Achievement> getUnlockedAchievements() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Achievement> result;
        for (const auto& [id, userAch] : userAchievements_) {
            if (userAch.isUnlocked) {
                auto achIt = achievements_.find(id);
                if (achIt != achievements_.end()) {
                    result.push_back(achIt->second);
                }
            }
        }

        // Sort by unlock date (newest first)
        std::sort(result.begin(), result.end(),
            [this](const Achievement& a, const Achievement& b) {
                return userAchievements_.at(a.id).unlockedAt >
                       userAchievements_.at(b.id).unlockedAt;
            });

        return result;
    }

    float getCompletionPercentage() const {
        std::lock_guard<std::mutex> lock(mutex_);

        int total = 0;
        int unlocked = 0;

        for (const auto& [id, achievement] : achievements_) {
            if (achievement.isRetired || achievement.isSecret) continue;
            total++;

            auto userIt = userAchievements_.find(id);
            if (userIt != userAchievements_.end() && userIt->second.isUnlocked) {
                unlocked++;
            }
        }

        return total > 0 ? (static_cast<float>(unlocked) / total) * 100.0f : 0.0f;
    }

    // ========================================================================
    // XP & Leveling
    // ========================================================================

    void awardXP(int amount, const std::string& source) {
        std::lock_guard<std::mutex> lock(mutex_);

        levelInfo_.currentXP += amount;
        levelInfo_.totalXP += amount;

        // Log XP event
        XPEvent event;
        event.timestamp = std::chrono::system_clock::now();
        event.amount = amount;
        event.source = source;
        xpHistory_.push_back(event);

        // Check for level up
        while (levelInfo_.currentXP >= levelInfo_.xpToNextLevel) {
            levelUp();
        }
    }

    LevelInfo getLevelInfo() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return levelInfo_;
    }

    std::vector<XPEvent> getXPHistory(int limit = 50) const {
        std::lock_guard<std::mutex> lock(mutex_);

        if (xpHistory_.size() <= static_cast<size_t>(limit)) {
            return xpHistory_;
        }

        return std::vector<XPEvent>(
            xpHistory_.end() - limit, xpHistory_.end());
    }

    // ========================================================================
    // Streaks
    // ========================================================================

    void checkInStreak(const std::string& streakId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = streaks_.find(streakId);
        if (it == streaks_.end()) return;

        auto& streak = it->second;
        auto now = std::chrono::system_clock::now();

        // Check if this is a new day/week
        bool isNewPeriod = !streak.isActiveToday;
        if (streak.lastActivity.time_since_epoch().count() > 0) {
            auto lastTime = std::chrono::system_clock::to_time_t(streak.lastActivity);
            auto nowTime = std::chrono::system_clock::to_time_t(now);

            auto* lastTm = std::localtime(&lastTime);
            int lastDay = lastTm->tm_yday;

            auto* nowTm = std::localtime(&nowTime);
            int nowDay = nowTm->tm_yday;

            int daysDiff = nowDay - lastDay;

            if (daysDiff == 0) {
                // Same day
                isNewPeriod = false;
            } else if (daysDiff == 1) {
                // Next day - continue streak
                isNewPeriod = true;
            } else if (daysDiff <= streak.graceDays + 1) {
                // Within grace period
                streak.graceDaysUsed += daysDiff - 1;
                isNewPeriod = true;
            } else {
                // Streak broken
                streak.currentStreak = 0;
                streak.graceDaysUsed = 0;
                isNewPeriod = true;
            }
        }

        if (isNewPeriod) {
            streak.currentStreak++;
            streak.isActiveToday = true;

            if (streak.currentStreak > streak.longestStreak) {
                streak.longestStreak = streak.currentStreak;
            }

            // Check milestones
            for (int milestone : streak.milestoneDays) {
                if (streak.currentStreak == milestone) {
                    auto found = std::find(streak.reachedMilestones.begin(),
                                           streak.reachedMilestones.end(), milestone);
                    if (found == streak.reachedMilestones.end()) {
                        streak.reachedMilestones.push_back(milestone);
                        awardXP(milestone * 10, "Streak milestone: " + streak.name);
                    }
                }
            }
        }

        streak.lastActivity = now;
    }

    Streak getStreak(const std::string& streakId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = streaks_.find(streakId);
        if (it != streaks_.end()) {
            return it->second;
        }
        return Streak{};
    }

    std::vector<Streak> getAllStreaks() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Streak> result;
        for (const auto& [id, streak] : streaks_) {
            result.push_back(streak);
        }
        return result;
    }

    // ========================================================================
    // Challenges
    // ========================================================================

    void startChallenge(const std::string& challengeId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = challenges_.find(challengeId);
        if (it != challenges_.end()) {
            it->second.isActive = true;
            it->second.startTime = std::chrono::system_clock::now();
        }
    }

    void updateChallengeProgress(const std::string& challengeId, int goalIndex, int progress) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = challenges_.find(challengeId);
        if (it == challenges_.end()) return;

        auto& challenge = it->second;
        if (goalIndex >= 0 && goalIndex < static_cast<int>(challenge.goals.size())) {
            auto& goal = challenge.goals[goalIndex];
            goal.current = progress;

            if (goal.current >= goal.target) {
                goal.completed = true;
            }
        }

        // Check if all goals complete
        bool allComplete = true;
        for (const auto& goal : challenge.goals) {
            if (!goal.completed) {
                allComplete = false;
                break;
            }
        }

        if (allComplete && !challenge.isCompleted) {
            completeChallenge(challengeId);
        }
    }

    void completeChallenge(const std::string& challengeId) {
        auto it = challenges_.find(challengeId);
        if (it == challenges_.end()) return;

        auto& challenge = it->second;
        challenge.isCompleted = true;
        challenge.isActive = false;

        // Award XP
        awardXP(challenge.xpReward, "Challenge: " + challenge.name);

        // Unlock achievement if linked
        if (!challenge.achievementId.empty()) {
            unlockAchievement(challenge.achievementId);
        }
    }

    std::vector<Challenge> getActiveChallenges() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Challenge> result;
        auto now = std::chrono::system_clock::now();

        for (const auto& [id, challenge] : challenges_) {
            if (challenge.isActive && !challenge.isCompleted) {
                if (challenge.endTime.time_since_epoch().count() == 0 ||
                    now < challenge.endTime) {
                    result.push_back(challenge);
                }
            }
        }

        return result;
    }

    // ========================================================================
    // Leaderboards
    // ========================================================================

    Leaderboard getLeaderboard(const std::string& leaderboardId) const {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = leaderboards_.find(leaderboardId);
        if (it != leaderboards_.end()) {
            return it->second;
        }
        return Leaderboard{};
    }

    void refreshLeaderboard(const std::string& leaderboardId) {
        // Would fetch from server
    }

    // ========================================================================
    // Notifications
    // ========================================================================

    using NotificationCallback = std::function<void(const Achievement&)>;

    void setNotificationCallback(const NotificationCallback& callback) {
        notificationCallback_ = callback;
    }

    void dismissNotification(const std::string& achievementId) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = userAchievements_.find(achievementId);
        if (it != userAchievements_.end()) {
            it->second.isViewed = true;
        }
    }

    std::vector<Achievement> getPendingNotifications() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<Achievement> pending;
        for (const auto& [id, userAch] : userAchievements_) {
            if (userAch.isUnlocked && !userAch.isViewed) {
                auto achIt = achievements_.find(id);
                if (achIt != achievements_.end()) {
                    pending.push_back(achIt->second);
                }
            }
        }

        return pending;
    }

    // ========================================================================
    // Feature Unlocks
    // ========================================================================

    bool isFeatureUnlocked(const std::string& featureId) const {
        std::lock_guard<std::mutex> lock(mutex_);
        return unlockedFeatures_.count(featureId) > 0;
    }

    std::set<std::string> getUnlockedFeatures() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return unlockedFeatures_;
    }

private:
    AchievementsManager() = default;
    ~AchievementsManager() = default;

    AchievementsManager(const AchievementsManager&) = delete;
    AchievementsManager& operator=(const AchievementsManager&) = delete;

    void registerAchievements() {
        // Getting Started
        registerAchievement({
            .id = "first_project",
            .name = "First Steps",
            .description = "Create your first project",
            .category = AchievementCategory::GettingStarted,
            .rarity = AchievementRarity::Common,
            .iconName = "star.fill",
            .xpReward = 50,
            .conditions = {{.type = "count", .metric = "projects_created", .threshold = 1}}
        });

        registerAchievement({
            .id = "first_track",
            .name = "Track Star",
            .description = "Create your first track",
            .category = AchievementCategory::GettingStarted,
            .rarity = AchievementRarity::Common,
            .iconName = "waveform",
            .xpReward = 25,
            .conditions = {{.type = "count", .metric = "tracks_created", .threshold = 1}}
        });

        registerAchievement({
            .id = "first_export",
            .name = "Released!",
            .description = "Export your first song",
            .category = AchievementCategory::Production,
            .rarity = AchievementRarity::Common,
            .iconName = "arrow.up.circle.fill",
            .xpReward = 100,
            .conditions = {{.type = "count", .metric = "exports_completed", .threshold = 1}}
        });

        // Production milestones
        registerAchievement({
            .id = "prolific_10",
            .name = "Prolific Producer",
            .description = "Complete 10 projects",
            .category = AchievementCategory::Prolific,
            .rarity = AchievementRarity::Uncommon,
            .iconName = "flame.fill",
            .isProgressive = true,
            .maxProgress = 100,
            .milestones = {10, 25, 50, 100},
            .xpReward = 200,
            .tierXP = {
                {AchievementTier::Bronze, 100},
                {AchievementTier::Silver, 200},
                {AchievementTier::Gold, 500},
                {AchievementTier::Platinum, 1000}
            },
            .conditions = {{.type = "count", .metric = "projects_completed", .threshold = 10}}
        });

        // Session streaks
        registerAchievement({
            .id = "streak_7",
            .name = "Weekly Warrior",
            .description = "Practice for 7 days in a row",
            .category = AchievementCategory::Consistency,
            .rarity = AchievementRarity::Rare,
            .iconName = "calendar",
            .isProgressive = true,
            .maxProgress = 365,
            .milestones = {7, 30, 100, 365},
            .xpReward = 500,
            .conditions = {{.type = "streak", .metric = "daily_practice", .threshold = 7}}
        });

        // Marathon sessions
        registerAchievement({
            .id = "marathon_4h",
            .name = "Marathon Session",
            .description = "Work on music for 4+ hours",
            .category = AchievementCategory::Marathon,
            .rarity = AchievementRarity::Uncommon,
            .iconName = "timer",
            .xpReward = 150,
            .conditions = {{
                .type = "duration",
                .metric = "session_length",
                .threshold = 4 * 60 * 60  // 4 hours in seconds
            }}
        });

        // Secret achievements
        registerAchievement({
            .id = "night_owl",
            .name = "Night Owl",
            .description = "Create music at 3 AM",
            .category = AchievementCategory::Secret,
            .rarity = AchievementRarity::Rare,
            .iconName = "moon.fill",
            .isSecret = true,
            .xpReward = 200,
            .conditions = {{.type = "custom", .metric = "night_session"}}
        });

        registerAchievement({
            .id = "early_bird",
            .name = "Early Bird",
            .description = "Start a session before 6 AM",
            .category = AchievementCategory::Secret,
            .rarity = AchievementRarity::Rare,
            .iconName = "sunrise.fill",
            .isSecret = true,
            .xpReward = 200,
            .conditions = {{.type = "custom", .metric = "early_session"}}
        });
    }

    void registerAchievement(const Achievement& achievement) {
        achievements_[achievement.id] = achievement;
        userAchievements_[achievement.id] = UserAchievement{.achievementId = achievement.id};
    }

    void initializeStreaks() {
        Streak dailyPractice;
        dailyPractice.id = "daily_practice";
        dailyPractice.name = "Daily Practice";
        dailyPractice.type = Streak::Type::Daily;
        dailyPractice.milestoneDays = {7, 14, 30, 60, 100, 365};
        dailyPractice.graceDays = 1;
        streaks_["daily_practice"] = dailyPractice;

        Streak weeklyMix;
        weeklyMix.id = "weekly_mix";
        weeklyMix.name = "Weekly Mixdown";
        weeklyMix.type = Streak::Type::Weekly;
        weeklyMix.milestoneDays = {4, 12, 26, 52};  // Weeks
        streaks_["weekly_mix"] = weeklyMix;
    }

    void loadUserProgress() {
        // Would load from persistent storage
    }

    void updateStreaks() {
        // Reset daily flags at midnight
        auto now = std::chrono::system_clock::now();

        for (auto& [id, streak] : streaks_) {
            if (streak.lastActivity.time_since_epoch().count() > 0) {
                auto lastTime = std::chrono::system_clock::to_time_t(streak.lastActivity);
                auto nowTime = std::chrono::system_clock::to_time_t(now);

                auto* lastTm = std::localtime(&lastTime);
                auto* nowTm = std::localtime(&nowTime);

                if (lastTm->tm_yday != nowTm->tm_yday) {
                    streak.isActiveToday = false;
                }
            }
        }
    }

    void levelUp() {
        levelInfo_.level++;
        levelInfo_.currentXP -= levelInfo_.xpToNextLevel;

        // Increase XP needed for next level
        levelInfo_.xpToNextLevel = static_cast<int>(100 * std::pow(1.5, levelInfo_.level - 1));

        // Update rank
        updateRank();
    }

    void updateRank() {
        struct RankInfo {
            int minLevel;
            std::string rank;
            std::string title;
        };

        static const std::vector<RankInfo> ranks = {
            {1, "Novice", "Beginner Producer"},
            {5, "Apprentice", "Learning Producer"},
            {10, "Journeyman", "Developing Producer"},
            {20, "Expert", "Skilled Producer"},
            {35, "Master", "Master Producer"},
            {50, "Grandmaster", "Grandmaster Producer"},
            {75, "Legend", "Legendary Producer"},
            {100, "Virtuoso", "Music Virtuoso"}
        };

        for (auto it = ranks.rbegin(); it != ranks.rend(); ++it) {
            if (levelInfo_.level >= it->minLevel) {
                levelInfo_.rank = it->rank;
                levelInfo_.title = it->title;
                break;
            }
        }
    }

    void queueNotification(const std::string& achievementId) {
        auto achIt = achievements_.find(achievementId);
        if (achIt != achievements_.end() && notificationCallback_) {
            notificationCallback_(achIt->second);
        }
    }

    mutable std::mutex mutex_;
    std::atomic<bool> initialized_{false};

    std::map<std::string, Achievement> achievements_;
    std::map<std::string, UserAchievement> userAchievements_;
    std::map<std::string, int> metrics_;
    std::map<std::string, Streak> streaks_;
    std::map<std::string, Challenge> challenges_;
    std::map<std::string, Leaderboard> leaderboards_;

    LevelInfo levelInfo_;
    std::vector<XPEvent> xpHistory_;

    std::set<std::string> unlockedFeatures_;

    NotificationCallback notificationCallback_;
};

// ============================================================================
// Convenience Functions
// ============================================================================

namespace Achievements {

inline void track(const std::string& metric, int amount = 1) {
    AchievementsManager::getInstance().trackProgress(metric, amount);
}

inline LevelInfo level() {
    return AchievementsManager::getInstance().getLevelInfo();
}

inline Streak streak(const std::string& id) {
    return AchievementsManager::getInstance().getStreak(id);
}

inline void checkIn() {
    AchievementsManager::getInstance().checkInStreak("daily_practice");
}

inline float completion() {
    return AchievementsManager::getInstance().getCompletionPercentage();
}

} // namespace Achievements

} // namespace Echoel
