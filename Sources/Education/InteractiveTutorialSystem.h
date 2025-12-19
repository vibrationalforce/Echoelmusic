// InteractiveTutorialSystem.h - Interactive Learning & Onboarding
// Guided tutorials, progress tracking, achievement system, contextual help
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>
#include <map>
#include <vector>

namespace Echoel {
namespace Education {

/**
 * @file InteractiveTutorialSystem.h
 * @brief Comprehensive interactive tutorial and learning system
 *
 * @par Features
 * - Step-by-step guided tutorials
 * - Interactive walkthroughs
 * - Progress tracking
 * - Achievement system
 * - Contextual help
 * - Skill tree progression
 * - Video lessons integration
 * - Practice exercises
 * - Certification system
 *
 * @par Learning Paths
 * - Beginner: "First Steps in Music Production"
 * - Intermediate: "Advanced Mixing Techniques"
 * - Advanced: "Professional Mastering"
 * - AI Features: "Bio-Reactive Music with AI"
 *
 * @example
 * @code
 * TutorialManager tutorials;
 *
 * // Start beginner tutorial
 * tutorials.startTutorial("first_steps");
 *
 * // Progress through steps
 * tutorials.completeStep("first_steps", 0);
 * tutorials.completeStep("first_steps", 1);
 *
 * // Check progress
 * auto progress = tutorials.getProgress("user123");
 * std::cout << "Tutorials completed: " << progress.tutorialsCompleted << std::endl;
 * @endcode
 */

//==============================================================================
/**
 * @brief Tutorial difficulty level
 */
enum class TutorialLevel {
    Beginner,       ///< No prior knowledge required
    Intermediate,   ///< Basic music production knowledge
    Advanced,       ///< Professional level
    Expert          ///< Cutting-edge techniques
};

/**
 * @brief Tutorial step types
 */
enum class StepType {
    Explanation,    ///< Text/video explanation
    Action,         ///< User must perform an action
    Quiz,           ///< Multiple choice question
    Practice,       ///< Practice exercise
    Checkpoint      ///< Progress checkpoint
};

/**
 * @brief Tutorial step
 */
struct TutorialStep {
    int stepNumber;                 ///< Step number (0-indexed)
    StepType type;                  ///< Step type
    juce::String title;             ///< Step title
    juce::String description;       ///< Detailed description
    juce::String instruction;       ///< What user should do
    juce::String videoUrl;          ///< Optional video URL
    juce::String targetComponent;   ///< UI component to highlight
    juce::String action;            ///< Action to verify (e.g., "click_play")
    juce::StringArray hints;        ///< Hints if user is stuck

    // Quiz questions (if type == Quiz)
    juce::String question;
    juce::StringArray options;
    int correctAnswer{0};

    bool isCompleted{false};        ///< Completed flag
};

/**
 * @brief Complete tutorial definition
 */
struct Tutorial {
    juce::String id;                        ///< Unique tutorial ID
    juce::String title;                     ///< Tutorial title
    juce::String description;               ///< Description
    TutorialLevel level;                    ///< Difficulty level
    int estimatedMinutes{10};               ///< Estimated completion time
    juce::StringArray prerequisites;        ///< Required tutorials
    juce::StringArray tags;                 ///< Tags (mixing, mastering, ai)
    std::vector<TutorialStep> steps;        ///< Tutorial steps

    // Rewards
    int experiencePoints{100};              ///< XP reward
    juce::StringArray achievements;         ///< Unlocked achievements

    /**
     * @brief Get completion percentage
     */
    float getCompletionPercentage() const {
        if (steps.empty()) return 0.0f;

        int completed = 0;
        for (const auto& step : steps) {
            if (step.isCompleted) completed++;
        }

        return (static_cast<float>(completed) / steps.size()) * 100.0f;
    }

    /**
     * @brief Check if tutorial is completed
     */
    bool isCompleted() const {
        for (const auto& step : steps) {
            if (!step.isCompleted) return false;
        }
        return true;
    }
};

/**
 * @brief User's learning progress
 */
struct LearningProgress {
    juce::String userId;
    int experiencePoints{0};                        ///< Total XP
    int level{1};                                   ///< User level
    std::map<std::string, float> tutorialProgress;  ///< Tutorial ID -> completion %
    juce::StringArray completedTutorials;           ///< Completed tutorial IDs
    juce::StringArray unlockedAchievements;         ///< Unlocked achievements
    int64_t totalLearningTimeMs{0};                 ///< Total time spent
    int64_t lastActivityTimestamp{0};               ///< Last activity

    /**
     * @brief Get level from XP
     */
    int calculateLevel() const {
        // Level = floor(sqrt(XP / 100))
        return std::max(1, static_cast<int>(std::sqrt(experiencePoints / 100.0)));
    }

    /**
     * @brief XP needed for next level
     */
    int xpForNextLevel() const {
        int nextLevel = level + 1;
        int requiredXP = nextLevel * nextLevel * 100;
        return requiredXP - experiencePoints;
    }
};

/**
 * @brief Achievement definition
 */
struct Achievement {
    juce::String id;                ///< Achievement ID
    juce::String title;             ///< Title
    juce::String description;       ///< Description
    juce::String icon;              ///< Icon name
    int experienceReward{50};       ///< XP reward
    bool isSecret{false};           ///< Hidden until unlocked

    // Unlock conditions
    juce::StringArray requiredTutorials;
    int minimumLevel{1};
    int minimumTutorialsCompleted{0};
};

//==============================================================================
/**
 * @brief Interactive Tutorial Manager
 */
class TutorialManager {
public:
    TutorialManager() {
        initializeDefaultTutorials();
        initializeAchievements();
        ECHOEL_TRACE("Tutorial system initialized with " << tutorials.size() << " tutorials");
    }

    //==============================================================================
    // Tutorial Management

    /**
     * @brief Start a tutorial
     * @param tutorialId Tutorial ID
     * @param userId User ID
     * @return True if started successfully
     */
    bool startTutorial(const juce::String& tutorialId, const juce::String& userId = "default") {
        auto* tutorial = getTutorial(tutorialId);
        if (!tutorial) {
            ECHOEL_TRACE("Tutorial not found: " << tutorialId);
            return false;
        }

        // Check prerequisites
        auto& progress = userProgress[userId.toStdString()];
        for (const auto& prereq : tutorial->prerequisites) {
            if (!progress.completedTutorials.contains(prereq)) {
                ECHOEL_TRACE("Missing prerequisite: " << prereq);
                return false;
            }
        }

        currentTutorialId = tutorialId;
        currentUserId = userId;
        currentStepIndex = 0;
        tutorialStartTime = juce::Time::currentTimeMillis();

        ECHOEL_TRACE("Started tutorial: " << tutorial->title);
        return true;
    }

    /**
     * @brief Complete a tutorial step
     * @param tutorialId Tutorial ID
     * @param stepIndex Step index
     * @return True if completed successfully
     */
    bool completeStep(const juce::String& tutorialId, int stepIndex) {
        auto* tutorial = getTutorial(tutorialId);
        if (!tutorial || stepIndex < 0 || stepIndex >= static_cast<int>(tutorial->steps.size())) {
            return false;
        }

        auto& step = tutorial->steps[stepIndex];
        if (step.isCompleted) {
            return true;  // Already completed
        }

        step.isCompleted = true;

        ECHOEL_TRACE("Completed step " << stepIndex << " of tutorial '" << tutorial->title << "'");

        // Check if tutorial is now complete
        if (tutorial->isCompleted()) {
            completeTutorial(tutorialId);
        } else {
            // Advance to next step
            currentStepIndex = stepIndex + 1;
        }

        return true;
    }

    /**
     * @brief Get current tutorial step
     */
    TutorialStep* getCurrentStep() {
        auto* tutorial = getTutorial(currentTutorialId);
        if (!tutorial || currentStepIndex >= static_cast<int>(tutorial->steps.size())) {
            return nullptr;
        }

        return &tutorial->steps[currentStepIndex];
    }

    /**
     * @brief Skip tutorial
     */
    void skipTutorial() {
        if (currentTutorialId.isNotEmpty()) {
            ECHOEL_TRACE("Tutorial skipped: " << currentTutorialId);
            currentTutorialId = "";
        }
    }

    //==============================================================================
    // Progress Tracking

    /**
     * @brief Get user's learning progress
     */
    LearningProgress getProgress(const juce::String& userId) const {
        auto it = userProgress.find(userId.toStdString());
        return (it != userProgress.end()) ? it->second : LearningProgress{userId};
    }

    /**
     * @brief Award experience points
     */
    void awardExperience(const juce::String& userId, int xp) {
        auto& progress = userProgress[userId.toStdString()];
        int oldLevel = progress.level;

        progress.experiencePoints += xp;
        progress.level = progress.calculateLevel();

        ECHOEL_TRACE("Awarded " << xp << " XP to " << userId);

        if (progress.level > oldLevel) {
            ECHOEL_TRACE("🎉 LEVEL UP! " << userId << " reached level " << progress.level);
            onLevelUp(userId, progress.level);
        }
    }

    /**
     * @brief Unlock achievement
     */
    void unlockAchievement(const juce::String& userId, const juce::String& achievementId) {
        auto& progress = userProgress[userId.toStdString()];

        if (progress.unlockedAchievements.contains(achievementId)) {
            return;  // Already unlocked
        }

        auto* achievement = getAchievement(achievementId);
        if (!achievement) {
            return;
        }

        progress.unlockedAchievements.add(achievementId);
        awardExperience(userId, achievement->experienceReward);

        ECHOEL_TRACE("🏆 Achievement unlocked: " << achievement->title);
    }

    //==============================================================================
    // Tutorial Queries

    /**
     * @brief Get all tutorials
     */
    std::vector<Tutorial> getAllTutorials() const {
        std::vector<Tutorial> result;
        for (const auto& [id, tutorial] : tutorials) {
            result.push_back(tutorial);
        }
        return result;
    }

    /**
     * @brief Get tutorials by level
     */
    std::vector<Tutorial> getTutorialsByLevel(TutorialLevel level) const {
        std::vector<Tutorial> result;
        for (const auto& [id, tutorial] : tutorials) {
            if (tutorial.level == level) {
                result.push_back(tutorial);
            }
        }
        return result;
    }

    /**
     * @brief Get recommended tutorials for user
     */
    std::vector<Tutorial> getRecommendedTutorials(const juce::String& userId) const {
        auto progress = getProgress(userId);
        std::vector<Tutorial> recommended;

        for (const auto& [id, tutorial] : tutorials) {
            // Skip completed tutorials
            if (progress.completedTutorials.contains(tutorial.id)) {
                continue;
            }

            // Check prerequisites
            bool hasPrerequisites = true;
            for (const auto& prereq : tutorial.prerequisites) {
                if (!progress.completedTutorials.contains(prereq)) {
                    hasPrerequisites = false;
                    break;
                }
            }

            if (hasPrerequisites) {
                recommended.push_back(tutorial);
            }
        }

        return recommended;
    }

    //==============================================================================
    // Statistics

    /**
     * @brief Get learning statistics
     */
    juce::String getStatistics(const juce::String& userId) const {
        auto progress = getProgress(userId);

        juce::String stats;
        stats << "📚 Learning Statistics\n";
        stats << "=====================\n\n";
        stats << "User:                  " << userId << "\n";
        stats << "Level:                 " << progress.level << "\n";
        stats << "Experience Points:     " << progress.experiencePoints << " XP\n";
        stats << "XP to Next Level:      " << progress.xpForNextLevel() << " XP\n";
        stats << "Tutorials Completed:   " << progress.completedTutorials.size() << "/" << tutorials.size() << "\n";
        stats << "Achievements Unlocked: " << progress.unlockedAchievements.size() << "/" << achievements.size() << "\n";
        stats << "Total Learning Time:   " << (progress.totalLearningTimeMs / 60000) << " minutes\n";

        return stats;
    }

private:
    //==============================================================================
    // Internal methods

    Tutorial* getTutorial(const juce::String& id) {
        auto it = tutorials.find(id.toStdString());
        return (it != tutorials.end()) ? &it->second : nullptr;
    }

    Achievement* getAchievement(const juce::String& id) {
        auto it = achievements.find(id.toStdString());
        return (it != achievements.end()) ? &it->second : nullptr;
    }

    void completeTutorial(const juce::String& tutorialId) {
        auto* tutorial = getTutorial(tutorialId);
        if (!tutorial) return;

        auto& progress = userProgress[currentUserId.toStdString()];

        // Mark as completed
        if (!progress.completedTutorials.contains(tutorialId)) {
            progress.completedTutorials.add(tutorialId);
        }

        // Award XP
        awardExperience(currentUserId, tutorial->experiencePoints);

        // Update learning time
        int64_t timeSpent = juce::Time::currentTimeMillis() - tutorialStartTime;
        progress.totalLearningTimeMs += timeSpent;

        // Unlock achievements
        for (const auto& achievementId : tutorial->achievements) {
            unlockAchievement(currentUserId, achievementId);
        }

        ECHOEL_TRACE("🎉 Tutorial completed: " << tutorial->title);
        ECHOEL_TRACE("   XP awarded: " << tutorial->experiencePoints);
    }

    void onLevelUp(const juce::String& userId, int newLevel) {
        // Unlock level-based achievements
        if (newLevel == 5) {
            unlockAchievement(userId, "level_5");
        } else if (newLevel == 10) {
            unlockAchievement(userId, "level_10");
        }
    }

    void initializeDefaultTutorials() {
        // Beginner: First Steps
        {
            Tutorial tutorial;
            tutorial.id = "first_steps";
            tutorial.title = "First Steps in Music Production";
            tutorial.description = "Learn the basics of Echoelmusic interface and audio playback";
            tutorial.level = TutorialLevel::Beginner;
            tutorial.estimatedMinutes = 15;
            tutorial.experiencePoints = 100;
            tutorial.tags = {"beginner", "interface", "basics"};

            // Step 1: Welcome
            TutorialStep step1;
            step1.stepNumber = 0;
            step1.type = StepType::Explanation;
            step1.title = "Welcome to Echoelmusic!";
            step1.description = "Echoelmusic is a bio-reactive music production platform that uses AI to assist your creative process.";
            step1.instruction = "Click 'Next' to continue";
            tutorial.steps.push_back(step1);

            // Step 2: Load a project
            TutorialStep step2;
            step2.stepNumber = 1;
            step2.type = StepType::Action;
            step2.title = "Load Your First Project";
            step2.description = "Let's start by loading a sample project.";
            step2.instruction = "Click the 'Load Project' button in the toolbar";
            step2.targetComponent = "loadProjectButton";
            step2.action = "click_load_project";
            tutorial.steps.push_back(step2);

            // Step 3: Quiz
            TutorialStep step3;
            step3.stepNumber = 2;
            step3.type = StepType::Quiz;
            step3.title = "Quick Quiz";
            step3.question = "What does Echoelmusic specialize in?";
            step3.options = {"Video editing", "Bio-reactive music production", "Photo editing", "3D modeling"};
            step3.correctAnswer = 1;
            tutorial.steps.push_back(step3);

            tutorials[tutorial.id.toStdString()] = tutorial;
        }

        // Intermediate: Mixing Techniques
        {
            Tutorial tutorial;
            tutorial.id = "mixing_basics";
            tutorial.title = "Essential Mixing Techniques";
            tutorial.description = "Master the fundamentals of audio mixing";
            tutorial.level = TutorialLevel::Intermediate;
            tutorial.estimatedMinutes = 30;
            tutorial.experiencePoints = 200;
            tutorial.prerequisites = {"first_steps"};
            tutorial.tags = {"mixing", "intermediate", "audio"};

            tutorials[tutorial.id.toStdString()] = tutorial;
        }

        // Advanced: AI Features
        {
            Tutorial tutorial;
            tutorial.id = "ai_features";
            tutorial.title = "Bio-Reactive Music with AI";
            tutorial.description = "Learn to use AI-powered chord detection, mixing, and mastering";
            tutorial.level = TutorialLevel::Advanced;
            tutorial.estimatedMinutes = 45;
            tutorial.experiencePoints = 500;
            tutorial.prerequisites = {"first_steps", "mixing_basics"};
            tutorial.tags = {"ai", "advanced", "bio-reactive"};

            tutorials[tutorial.id.toStdString()] = tutorial;
        }
    }

    void initializeAchievements() {
        Achievement a1;
        a1.id = "first_tutorial";
        a1.title = "First Steps";
        a1.description = "Complete your first tutorial";
        a1.experienceReward = 50;
        achievements[a1.id.toStdString()] = a1;

        Achievement a2;
        a2.id = "level_5";
        a2.title = "Rising Star";
        a2.description = "Reach level 5";
        a2.experienceReward = 100;
        achievements[a2.id.toStdString()] = a2;

        Achievement a3;
        a3.id = "level_10";
        a3.title = "Master Producer";
        a3.description = "Reach level 10";
        a3.experienceReward = 500;
        achievements[a3.id.toStdString()] = a3;

        Achievement a4;
        a4.id = "all_tutorials";
        a4.title = "Knowledge Seeker";
        a4.description = "Complete all tutorials";
        a4.experienceReward = 1000;
        achievements[a4.id.toStdString()] = a4;
    }

    //==============================================================================
    // State

    std::map<std::string, Tutorial> tutorials;
    std::map<std::string, Achievement> achievements;
    mutable std::map<std::string, LearningProgress> userProgress;

    juce::String currentTutorialId;
    juce::String currentUserId;
    int currentStepIndex{0};
    int64_t tutorialStartTime{0};

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TutorialManager)
};

} // namespace Education
} // namespace Echoel
