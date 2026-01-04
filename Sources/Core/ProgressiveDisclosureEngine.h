#pragma once

//==============================================================================
/**
    ProgressiveDisclosureEngine.h

    Unified Progressive Disclosure System for Echoelmusic

    Design Principle: Reveal information gradually based on user engagement,
    bio-state, and learning progression. Reduce cognitive load by showing
    only what matters now.

    Inspired by: LFM2-2.6B-Exp (on-device AI), bio-reactive feedback loops

    Copyright (c) 2024-2025 Echoelmusic
*/
//==============================================================================

#include <JuceHeader.h>
#include <atomic>
#include <map>
#include <vector>
#include <functional>
#include <chrono>

namespace Echoel
{

//==============================================================================
// DISCLOSURE LEVELS - Progressive complexity tiers
//==============================================================================

enum class DisclosureLevel
{
    Minimal,        // Essential controls only (stressed/new user)
    Basic,          // Core features visible
    Intermediate,   // Most features unlocked
    Advanced,       // Full feature set
    Expert          // CLI, scripting, hardware integration
};

//==============================================================================
// USER STATE - Bio-reactive + engagement metrics
//==============================================================================

struct UserState
{
    // Bio-reactive metrics (from wearables)
    float heartRate {70.0f};
    float hrv {50.0f};              // Heart rate variability
    float coherence {0.5f};         // HeartMath coherence (0-1)
    float stressLevel {0.3f};       // Derived stress (0-1)

    // Engagement metrics
    float flowIntensity {0.0f};     // From FlowStateIndicator
    double sessionDuration {0.0};   // Seconds in current session
    int actionCount {0};            // User interactions this session
    int errorCount {0};             // Failed attempts (frustration signal)

    // Learning progression
    int onboardingStep {0};         // From FirstTimeExperience
    bool hasCompletedOnboarding {false};
    std::map<std::string, double> modeTimeSpent;  // Time per WorkspaceMode
    std::map<std::string, int> featureUsage;      // Feature interaction counts

    //--------------------------------------------------------------------------
    // Derived metrics
    //--------------------------------------------------------------------------

    bool isStressed() const { return stressLevel > 0.6f || hrv < 30.0f; }
    bool isInFlow() const { return flowIntensity > 0.5f && coherence > 0.6f; }
    bool isCalm() const { return coherence > 0.7f && stressLevel < 0.3f; }
    bool isEngaged() const { return actionCount > 10 && sessionDuration > 60.0; }

    float getEngagementScore() const
    {
        // Composite engagement: coherence + flow + activity
        float activity = std::min(1.0f, actionCount / 100.0f);
        return (coherence * 0.4f) + (flowIntensity * 0.3f) + (activity * 0.3f);
    }
};

//==============================================================================
// FEATURE GATE - Requirements to unlock a feature
//==============================================================================

struct FeatureGate
{
    std::string featureId;
    std::string displayName;
    std::string category;           // "audio", "visual", "wellness", "ai"

    // Unlock requirements
    DisclosureLevel minLevel {DisclosureLevel::Basic};
    float minCoherence {0.0f};      // 0 = no requirement
    float maxStress {1.0f};         // 1 = no requirement
    double minSessionTime {0.0};    // Seconds
    int minActionCount {0};
    std::vector<std::string> prerequisiteFeatures;  // Must unlock these first

    // Visibility rules
    bool hideWhenStressed {false};  // Hide during high stress
    bool requiresFlow {false};      // Only show during flow state
    bool safetyGated {false};       // Requires acknowledgment (wellness features)

    //--------------------------------------------------------------------------

    bool canUnlock(const UserState& state, DisclosureLevel currentLevel) const
    {
        if (currentLevel < minLevel) return false;
        if (state.coherence < minCoherence) return false;
        if (state.stressLevel > maxStress) return false;
        if (state.sessionDuration < minSessionTime) return false;
        if (state.actionCount < minActionCount) return false;

        // Check stress-based hiding
        if (hideWhenStressed && state.isStressed()) return false;

        // Check flow requirement
        if (requiresFlow && !state.isInFlow()) return false;

        return true;
    }
};

//==============================================================================
// DISCLOSURE SUGGESTION - AI recommendation for feature reveal
//==============================================================================

struct DisclosureSuggestion
{
    std::string featureId;
    std::string message;            // "You're ready for {feature}"
    float confidence {0.0f};        // AI confidence in suggestion (0-1)
    std::string reason;             // Why now: "High coherence detected"

    enum class Priority { Low, Medium, High, Urgent };
    Priority priority {Priority::Medium};
};

//==============================================================================
// PROGRESSIVE DISCLOSURE ENGINE - Main orchestrator
//==============================================================================

class ProgressiveDisclosureEngine
{
public:
    //--------------------------------------------------------------------------
    // Singleton access
    //--------------------------------------------------------------------------

    static ProgressiveDisclosureEngine& shared()
    {
        static ProgressiveDisclosureEngine instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    // State management
    //--------------------------------------------------------------------------

    void updateUserState(const UserState& state)
    {
        userState = state;
        recalculateDisclosureLevel();
        generateSuggestions();
    }

    void updateBioMetrics(float hr, float hrvValue, float coh)
    {
        userState.heartRate = hr;
        userState.hrv = hrvValue;
        userState.coherence = coh;
        userState.stressLevel = calculateStressFromHRV(hrvValue, coh);
        recalculateDisclosureLevel();
    }

    void updateFlowState(float intensity)
    {
        userState.flowIntensity = intensity;
        recalculateDisclosureLevel();
    }

    void recordAction(const std::string& actionType)
    {
        userState.actionCount++;
        userState.featureUsage[actionType]++;
        recalculateDisclosureLevel();
    }

    void recordError()
    {
        userState.errorCount++;
        // High error count might reduce disclosure level
        if (userState.errorCount > 5 && currentLevel > DisclosureLevel::Basic)
        {
            // Temporarily reduce complexity
            temporaryLevelReduction = true;
        }
    }

    void setOnboardingProgress(int step, bool completed)
    {
        userState.onboardingStep = step;
        userState.hasCompletedOnboarding = completed;
        recalculateDisclosureLevel();
    }

    //--------------------------------------------------------------------------
    // Disclosure level
    //--------------------------------------------------------------------------

    DisclosureLevel getCurrentLevel() const { return currentLevel; }

    juce::String getLevelName() const
    {
        switch (currentLevel)
        {
            case DisclosureLevel::Minimal:      return "Minimal";
            case DisclosureLevel::Basic:        return "Basic";
            case DisclosureLevel::Intermediate: return "Intermediate";
            case DisclosureLevel::Advanced:     return "Advanced";
            case DisclosureLevel::Expert:       return "Expert";
        }
        return "Unknown";
    }

    // Force a specific level (user override)
    void setManualLevel(DisclosureLevel level)
    {
        manualOverride = true;
        currentLevel = level;
        notifyLevelChange();
    }

    void clearManualOverride()
    {
        manualOverride = false;
        recalculateDisclosureLevel();
    }

    //--------------------------------------------------------------------------
    // Feature gating
    //--------------------------------------------------------------------------

    void registerFeature(const FeatureGate& gate)
    {
        featureGates[gate.featureId] = gate;
    }

    bool isFeatureVisible(const std::string& featureId) const
    {
        auto it = featureGates.find(featureId);
        if (it == featureGates.end()) return true;  // Unknown features visible

        // Check if unlocked
        if (unlockedFeatures.count(featureId) > 0) return true;

        // Check gate conditions
        return it->second.canUnlock(userState, currentLevel);
    }

    bool isFeatureLocked(const std::string& featureId) const
    {
        return !isFeatureVisible(featureId);
    }

    void unlockFeature(const std::string& featureId)
    {
        unlockedFeatures.insert(featureId);
        if (onFeatureUnlocked)
            onFeatureUnlocked(featureId);
    }

    std::vector<std::string> getVisibleFeatures() const
    {
        std::vector<std::string> visible;
        for (const auto& [id, gate] : featureGates)
        {
            if (isFeatureVisible(id))
                visible.push_back(id);
        }
        return visible;
    }

    std::vector<std::string> getLockedFeatures() const
    {
        std::vector<std::string> locked;
        for (const auto& [id, gate] : featureGates)
        {
            if (!isFeatureVisible(id))
                locked.push_back(id);
        }
        return locked;
    }

    //--------------------------------------------------------------------------
    // AI suggestions
    //--------------------------------------------------------------------------

    std::vector<DisclosureSuggestion> getSuggestions() const
    {
        return currentSuggestions;
    }

    DisclosureSuggestion getTopSuggestion() const
    {
        if (currentSuggestions.empty())
            return {};
        return currentSuggestions.front();
    }

    void dismissSuggestion(const std::string& featureId)
    {
        dismissedSuggestions.insert(featureId);
        generateSuggestions();
    }

    //--------------------------------------------------------------------------
    // Callbacks
    //--------------------------------------------------------------------------

    std::function<void(DisclosureLevel)> onLevelChanged;
    std::function<void(const std::string&)> onFeatureUnlocked;
    std::function<void(const DisclosureSuggestion&)> onNewSuggestion;

    //--------------------------------------------------------------------------
    // Serialization (persist user progress)
    //--------------------------------------------------------------------------

    juce::String serializeProgress() const
    {
        juce::DynamicObject::Ptr obj = new juce::DynamicObject();

        // Save unlocked features
        juce::Array<juce::var> unlocked;
        for (const auto& f : unlockedFeatures)
            unlocked.add(juce::String(f));
        obj->setProperty("unlockedFeatures", unlocked);

        // Save dismissed suggestions
        juce::Array<juce::var> dismissed;
        for (const auto& d : dismissedSuggestions)
            dismissed.add(juce::String(d));
        obj->setProperty("dismissedSuggestions", dismissed);

        // Save mode time spent
        juce::DynamicObject::Ptr modeTime = new juce::DynamicObject();
        for (const auto& [mode, time] : userState.modeTimeSpent)
            modeTime->setProperty(juce::String(mode), time);
        obj->setProperty("modeTimeSpent", modeTime.get());

        // Save feature usage
        juce::DynamicObject::Ptr usage = new juce::DynamicObject();
        for (const auto& [feat, count] : userState.featureUsage)
            usage->setProperty(juce::String(feat), count);
        obj->setProperty("featureUsage", usage.get());

        return juce::JSON::toString(obj.get());
    }

    void deserializeProgress(const juce::String& json)
    {
        auto parsed = juce::JSON::parse(json);
        if (auto* obj = parsed.getDynamicObject())
        {
            // Restore unlocked features
            if (auto* arr = obj->getProperty("unlockedFeatures").getArray())
            {
                for (const auto& v : *arr)
                    unlockedFeatures.insert(v.toString().toStdString());
            }

            // Restore dismissed suggestions
            if (auto* arr = obj->getProperty("dismissedSuggestions").getArray())
            {
                for (const auto& v : *arr)
                    dismissedSuggestions.insert(v.toString().toStdString());
            }

            // Restore mode time
            if (auto* modeObj = obj->getProperty("modeTimeSpent").getDynamicObject())
            {
                for (const auto& prop : modeObj->getProperties())
                    userState.modeTimeSpent[prop.name.toString().toStdString()] =
                        static_cast<double>(prop.value);
            }

            // Restore feature usage
            if (auto* usageObj = obj->getProperty("featureUsage").getDynamicObject())
            {
                for (const auto& prop : usageObj->getProperties())
                    userState.featureUsage[prop.name.toString().toStdString()] =
                        static_cast<int>(prop.value);
            }
        }

        recalculateDisclosureLevel();
    }

private:
    ProgressiveDisclosureEngine() { registerDefaultFeatureGates(); }
    ~ProgressiveDisclosureEngine() = default;
    ProgressiveDisclosureEngine(const ProgressiveDisclosureEngine&) = delete;
    ProgressiveDisclosureEngine& operator=(const ProgressiveDisclosureEngine&) = delete;

    //--------------------------------------------------------------------------
    // Internal state
    //--------------------------------------------------------------------------

    UserState userState;
    DisclosureLevel currentLevel {DisclosureLevel::Basic};
    bool manualOverride {false};
    bool temporaryLevelReduction {false};

    std::map<std::string, FeatureGate> featureGates;
    std::set<std::string> unlockedFeatures;
    std::set<std::string> dismissedSuggestions;
    std::vector<DisclosureSuggestion> currentSuggestions;

    //--------------------------------------------------------------------------
    // Level calculation
    //--------------------------------------------------------------------------

    void recalculateDisclosureLevel()
    {
        if (manualOverride) return;

        DisclosureLevel newLevel = DisclosureLevel::Basic;

        // Check bio-state first (safety)
        if (userState.isStressed())
        {
            newLevel = DisclosureLevel::Minimal;
        }
        else if (!userState.hasCompletedOnboarding)
        {
            // During onboarding, stay at Basic
            newLevel = DisclosureLevel::Basic;
        }
        else if (userState.isInFlow() && userState.isCalm())
        {
            // Optimal state for learning
            newLevel = calculateLevelFromEngagement();
        }
        else
        {
            // Normal progression
            newLevel = calculateLevelFromEngagement();

            // But cap at Intermediate if not in flow
            if (!userState.isInFlow() && newLevel > DisclosureLevel::Intermediate)
                newLevel = DisclosureLevel::Intermediate;
        }

        // Apply temporary reduction if needed
        if (temporaryLevelReduction && newLevel > DisclosureLevel::Basic)
        {
            newLevel = static_cast<DisclosureLevel>(
                static_cast<int>(newLevel) - 1);
        }

        if (newLevel != currentLevel)
        {
            currentLevel = newLevel;
            notifyLevelChange();
        }
    }

    DisclosureLevel calculateLevelFromEngagement()
    {
        float engagement = userState.getEngagementScore();
        double totalTime = userState.sessionDuration;
        int totalActions = userState.actionCount;

        // Expert: 10+ hours, high engagement, many features used
        if (totalTime > 36000 && engagement > 0.8f &&
            userState.featureUsage.size() > 20)
            return DisclosureLevel::Expert;

        // Advanced: 2+ hours, good engagement
        if (totalTime > 7200 && engagement > 0.6f &&
            userState.featureUsage.size() > 10)
            return DisclosureLevel::Advanced;

        // Intermediate: 30+ minutes, moderate engagement
        if (totalTime > 1800 && engagement > 0.4f)
            return DisclosureLevel::Intermediate;

        return DisclosureLevel::Basic;
    }

    void notifyLevelChange()
    {
        if (onLevelChanged)
            onLevelChanged(currentLevel);
    }

    //--------------------------------------------------------------------------
    // Stress calculation
    //--------------------------------------------------------------------------

    float calculateStressFromHRV(float hrv, float coherence)
    {
        // Low HRV and low coherence = high stress
        float hrvStress = 1.0f - std::min(1.0f, hrv / 100.0f);
        float cohStress = 1.0f - coherence;
        return (hrvStress * 0.6f) + (cohStress * 0.4f);
    }

    //--------------------------------------------------------------------------
    // Suggestion generation
    //--------------------------------------------------------------------------

    void generateSuggestions()
    {
        currentSuggestions.clear();

        // Only suggest when user is in good state
        if (userState.isStressed()) return;
        if (!userState.hasCompletedOnboarding) return;

        // Find features that are almost unlockable
        for (const auto& [id, gate] : featureGates)
        {
            // Skip already visible or dismissed
            if (isFeatureVisible(id)) continue;
            if (dismissedSuggestions.count(id) > 0) continue;

            // Check if close to unlocking
            float readiness = calculateReadiness(gate);
            if (readiness > 0.8f)
            {
                DisclosureSuggestion suggestion;
                suggestion.featureId = id;
                suggestion.message = "Ready to unlock: " + gate.displayName;
                suggestion.confidence = readiness;
                suggestion.reason = getUnlockReason(gate);
                suggestion.priority = readiness > 0.95f ?
                    DisclosureSuggestion::Priority::High :
                    DisclosureSuggestion::Priority::Medium;

                currentSuggestions.push_back(suggestion);
            }
        }

        // Sort by confidence
        std::sort(currentSuggestions.begin(), currentSuggestions.end(),
            [](const auto& a, const auto& b) {
                return a.confidence > b.confidence;
            });

        // Notify top suggestion
        if (!currentSuggestions.empty() && onNewSuggestion)
            onNewSuggestion(currentSuggestions.front());
    }

    float calculateReadiness(const FeatureGate& gate)
    {
        float readiness = 0.0f;
        int factors = 0;

        // Coherence readiness
        if (gate.minCoherence > 0)
        {
            readiness += std::min(1.0f, userState.coherence / gate.minCoherence);
            factors++;
        }

        // Time readiness
        if (gate.minSessionTime > 0)
        {
            readiness += std::min(1.0f,
                static_cast<float>(userState.sessionDuration / gate.minSessionTime));
            factors++;
        }

        // Action readiness
        if (gate.minActionCount > 0)
        {
            readiness += std::min(1.0f,
                static_cast<float>(userState.actionCount) / gate.minActionCount);
            factors++;
        }

        return factors > 0 ? readiness / factors : 0.0f;
    }

    std::string getUnlockReason(const FeatureGate& gate)
    {
        if (userState.isInFlow())
            return "You're in flow state - perfect time to learn";
        if (userState.coherence > 0.7f)
            return "High coherence detected - you're focused";
        if (userState.sessionDuration > gate.minSessionTime)
            return "You've spent enough time to master this";
        return "Your engagement suggests you're ready";
    }

    //--------------------------------------------------------------------------
    // Default feature gates
    //--------------------------------------------------------------------------

    void registerDefaultFeatureGates()
    {
        // Basic audio (always visible)
        registerFeature({
            .featureId = "basic_playback",
            .displayName = "Playback Controls",
            .category = "audio",
            .minLevel = DisclosureLevel::Minimal
        });

        // Mixer (unlock after some use)
        registerFeature({
            .featureId = "mixer",
            .displayName = "Mixer Panel",
            .category = "audio",
            .minLevel = DisclosureLevel::Basic,
            .minSessionTime = 300,  // 5 minutes
            .minActionCount = 10
        });

        // Effects chain
        registerFeature({
            .featureId = "effects_chain",
            .displayName = "Effects Chain",
            .category = "audio",
            .minLevel = DisclosureLevel::Intermediate,
            .minCoherence = 0.4f,
            .prerequisiteFeatures = {"mixer"}
        });

        // Bio-reactive modulation
        registerFeature({
            .featureId = "bio_modulation",
            .displayName = "Bio-Reactive Modulation",
            .category = "bio",
            .minLevel = DisclosureLevel::Intermediate,
            .minCoherence = 0.5f,
            .requiresFlow = true
        });

        // AI composition
        registerFeature({
            .featureId = "ai_composer",
            .displayName = "AI Composition Assistant",
            .category = "ai",
            .minLevel = DisclosureLevel::Advanced,
            .minCoherence = 0.6f,
            .minSessionTime = 3600,  // 1 hour
            .prerequisiteFeatures = {"effects_chain", "bio_modulation"}
        });

        // Wellness features (safety gated)
        registerFeature({
            .featureId = "ave_therapy",
            .displayName = "Audio-Visual Entrainment",
            .category = "wellness",
            .minLevel = DisclosureLevel::Intermediate,
            .hideWhenStressed = true,
            .safetyGated = true
        });

        // Expert features
        registerFeature({
            .featureId = "scripting",
            .displayName = "Scripting Interface",
            .category = "advanced",
            .minLevel = DisclosureLevel::Expert,
            .minSessionTime = 36000,  // 10 hours
            .minActionCount = 1000
        });

        registerFeature({
            .featureId = "hardware_integration",
            .displayName = "Hardware Integration",
            .category = "advanced",
            .minLevel = DisclosureLevel::Expert,
            .prerequisiteFeatures = {"scripting"}
        });
    }
};

//==============================================================================
// CONVENIENCE MACRO
//==============================================================================

#define EchoelDisclosure ProgressiveDisclosureEngine::shared()

} // namespace Echoel
