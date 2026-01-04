#pragma once

//==============================================================================
/**
    LatentDemandDetector.h

    Anticipates user needs before they're explicitly expressed.

    Detects:
    - Behavioral patterns (pauses, undos, repeated actions)
    - Frustration signals (bio-stress + error patterns)
    - Exploration patterns (searching for something)
    - Creative blocks (stagnation detection)

    Responds:
    - Surface hidden features at optimal moments
    - Suggest workflow improvements
    - Offer creative alternatives
    - Simplify before user gets frustrated

    Integrates with: RalphWiggumAIBridge, ProgressiveDisclosureEngine

    Copyright (c) 2024-2025 Echoelmusic
*/
//==============================================================================

#include <JuceHeader.h>
#include <vector>
#include <deque>
#include <map>
#include <chrono>
#include <functional>

namespace Echoel
{

//==============================================================================
// ACTION TYPES
//==============================================================================

enum class UserActionType
{
    // Basic actions
    NoteInput,
    ParameterChange,
    PresetBrowse,
    PresetSelect,

    // Edit actions
    Undo,
    Redo,
    Delete,
    Copy,
    Paste,

    // Navigation
    ModeSwitch,
    PanelOpen,
    PanelClose,
    MenuOpen,
    Search,

    // Playback
    Play,
    Stop,
    Record,
    Loop,

    // Special
    Help,
    Settings,
    Save,
    Export,

    // Meta
    Idle,           // No action for period
    Unknown
};

//==============================================================================
// ACTION RECORD
//==============================================================================

struct ActionRecord
{
    UserActionType type;
    std::string context;            // e.g., "mixer", "arrange", "effects"
    std::string target;             // e.g., parameter name, preset name
    double timestamp;               // Seconds since session start
    double duration;                // How long action took
    bool wasSuccessful;             // Did it achieve intended result?

    // Bio-state at time of action
    float coherenceAtAction;
    float stressAtAction;
};

//==============================================================================
// LATENT DEMAND TYPES
//==============================================================================

enum class LatentDemandType
{
    // Feature discovery
    HiddenFeature,          // Feature exists but user doesn't know
    WorkflowOptimization,   // Better way to do what they're doing

    // Creative assistance
    CreativeBlock,          // Stuck, needs inspiration
    ExplorationAssist,      // Searching for something specific

    // Wellness
    FrustrationIntervention,// Getting frustrated, simplify
    BreakSuggestion,        // Needs rest

    // Learning
    SkillGap,               // Trying something beyond current skill
    ConceptClarification,   // Confused about a concept

    // Optimization
    PerformanceHint,        // Could be doing something more efficiently
    ShortcutSuggestion      // Keyboard shortcut for repeated action
};

//==============================================================================
// LATENT DEMAND
//==============================================================================

struct LatentDemand
{
    std::string id;
    LatentDemandType type;

    // Detection
    float confidence;               // 0-1 how sure we are
    std::string evidence;           // Why we think this
    std::vector<ActionRecord> triggerActions;

    // Response
    std::string suggestion;         // What to show user
    std::string featureToSurface;   // Feature ID to reveal
    std::string actionToTake;       // Automated action if applicable

    // Timing
    double detectedAt;
    bool wasAddressed;
    bool wasDismissed;

    // Priority
    enum class Priority { Low, Medium, High, Urgent };
    Priority priority {Priority::Medium};
};

//==============================================================================
// BEHAVIORAL PATTERN
//==============================================================================

struct BehavioralPattern
{
    std::string name;
    std::vector<UserActionType> actionSequence;
    int repeatCount;
    double timeWindow;              // Seconds
    LatentDemandType impliesDemand;
    std::string responseFeature;
    std::string responseSuggestion;
};

//==============================================================================
// LATENT DEMAND DETECTOR
//==============================================================================

class LatentDemandDetector
{
public:
    //--------------------------------------------------------------------------
    // Singleton
    //--------------------------------------------------------------------------

    static LatentDemandDetector& shared()
    {
        static LatentDemandDetector instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    // Action Recording
    //--------------------------------------------------------------------------

    void recordAction(const ActionRecord& action)
    {
        actionHistory.push_back(action);

        // Keep history manageable
        while (actionHistory.size() > maxHistorySize)
            actionHistory.pop_front();

        // Update patterns
        updateActionCounts(action);

        // Check for latent demands
        detectLatentDemands();
    }

    void recordAction(UserActionType type, const std::string& context = "",
                      const std::string& target = "", bool success = true)
    {
        ActionRecord record;
        record.type = type;
        record.context = context;
        record.target = target;
        record.timestamp = getSessionTime();
        record.wasSuccessful = success;
        record.coherenceAtAction = currentCoherence;
        record.stressAtAction = currentStress;

        recordAction(record);
    }

    void recordIdle(double seconds)
    {
        lastIdleDuration = seconds;
        totalIdleTime += seconds;

        if (seconds > pauseThreshold)
        {
            pauseCount++;
            checkForCreativeBlock();
        }
    }

    void recordUndo()
    {
        undoCount++;
        consecutiveUndos++;

        if (consecutiveUndos >= 3)
            detectFrustration("Multiple undos in sequence");
    }

    void recordRedo()
    {
        consecutiveUndos = 0;  // Reset undo chain
    }

    //--------------------------------------------------------------------------
    // Bio-State Updates
    //--------------------------------------------------------------------------

    void updateBioState(float coherence, float stress, float hrv)
    {
        float prevStress = currentStress;

        currentCoherence = coherence;
        currentStress = stress;
        currentHRV = hrv;

        // Detect stress spike
        if (stress - prevStress > stressSpikeThreshold)
        {
            stressSpikeCount++;
            detectFrustration("Stress spike detected");
        }

        // Check for break need
        if (stress > 0.7f && currentHRV < 30.0f)
        {
            suggestBreak();
        }
    }

    //--------------------------------------------------------------------------
    // Demand Detection
    //--------------------------------------------------------------------------

    std::vector<LatentDemand> getActiveDemands() const
    {
        std::vector<LatentDemand> active;
        for (const auto& d : detectedDemands)
        {
            if (!d.wasAddressed && !d.wasDismissed)
                active.push_back(d);
        }
        return active;
    }

    LatentDemand getTopDemand() const
    {
        auto active = getActiveDemands();
        if (active.empty())
            return {};

        // Sort by priority and confidence
        std::sort(active.begin(), active.end(),
            [](const auto& a, const auto& b) {
                if (a.priority != b.priority)
                    return static_cast<int>(a.priority) > static_cast<int>(b.priority);
                return a.confidence > b.confidence;
            });

        return active.front();
    }

    void addressDemand(const std::string& demandId)
    {
        for (auto& d : detectedDemands)
        {
            if (d.id == demandId)
            {
                d.wasAddressed = true;
                if (onDemandAddressed)
                    onDemandAddressed(d);
                break;
            }
        }
    }

    void dismissDemand(const std::string& demandId)
    {
        for (auto& d : detectedDemands)
        {
            if (d.id == demandId)
            {
                d.wasDismissed = true;
                break;
            }
        }
    }

    //--------------------------------------------------------------------------
    // Pattern Registration
    //--------------------------------------------------------------------------

    void registerPattern(const BehavioralPattern& pattern)
    {
        registeredPatterns.push_back(pattern);
    }

    //--------------------------------------------------------------------------
    // Callbacks
    //--------------------------------------------------------------------------

    std::function<void(const LatentDemand&)> onDemandDetected;
    std::function<void(const LatentDemand&)> onDemandAddressed;
    std::function<void()> onBreakSuggested;
    std::function<void(const std::string&)> onFeatureSurfaced;

    //--------------------------------------------------------------------------
    // Configuration
    //--------------------------------------------------------------------------

    void setPauseThreshold(double seconds) { pauseThreshold = seconds; }
    void setStressSpikeThreshold(float delta) { stressSpikeThreshold = delta; }
    void setMaxHistorySize(size_t size) { maxHistorySize = size; }

    //--------------------------------------------------------------------------
    // Statistics
    //--------------------------------------------------------------------------

    struct SessionStats
    {
        int totalActions;
        int undoCount;
        int pauseCount;
        int stressSpikeCount;
        double totalIdleTime;
        double avgTimeBetweenActions;
        std::map<UserActionType, int> actionCounts;
        std::map<std::string, int> contextCounts;
    };

    SessionStats getSessionStats() const
    {
        SessionStats stats;
        stats.totalActions = static_cast<int>(actionHistory.size());
        stats.undoCount = undoCount;
        stats.pauseCount = pauseCount;
        stats.stressSpikeCount = stressSpikeCount;
        stats.totalIdleTime = totalIdleTime;
        stats.actionCounts = actionCounts;
        stats.contextCounts = contextCounts;

        // Calculate average time between actions
        if (actionHistory.size() > 1)
        {
            double totalTime = actionHistory.back().timestamp -
                               actionHistory.front().timestamp;
            stats.avgTimeBetweenActions = totalTime / (actionHistory.size() - 1);
        }

        return stats;
    }

    //--------------------------------------------------------------------------
    // Reset
    //--------------------------------------------------------------------------

    void reset()
    {
        actionHistory.clear();
        detectedDemands.clear();
        actionCounts.clear();
        contextCounts.clear();
        undoCount = 0;
        pauseCount = 0;
        stressSpikeCount = 0;
        consecutiveUndos = 0;
        totalIdleTime = 0;
    }

private:
    LatentDemandDetector() { registerDefaultPatterns(); }
    ~LatentDemandDetector() = default;
    LatentDemandDetector(const LatentDemandDetector&) = delete;
    LatentDemandDetector& operator=(const LatentDemandDetector&) = delete;

    //--------------------------------------------------------------------------
    // State (thread-safe via mutex)
    //--------------------------------------------------------------------------

    mutable std::mutex historyMutex;  // Protects actionHistory and demands

    std::deque<ActionRecord> actionHistory;
    std::vector<LatentDemand> detectedDemands;
    std::vector<BehavioralPattern> registeredPatterns;

    std::map<UserActionType, int> actionCounts;
    std::map<std::string, int> contextCounts;

    // Counters (atomic for thread-safe access)
    std::atomic<int> undoCount {0};
    std::atomic<int> pauseCount {0};
    std::atomic<int> stressSpikeCount {0};
    std::atomic<int> consecutiveUndos {0};
    std::atomic<double> totalIdleTime {0.0};
    double lastIdleDuration {0.0};

    // Bio-state (atomic for thread-safe access)
    std::atomic<float> currentCoherence {0.5f};
    std::atomic<float> currentStress {0.3f};
    std::atomic<float> currentHRV {50.0f};

    // Config
    double pauseThreshold {5.0};        // Seconds of inactivity = pause
    float stressSpikeThreshold {0.2f};  // Stress delta to trigger
    size_t maxHistorySize {500};

    // Session timing
    std::chrono::steady_clock::time_point sessionStart
        {std::chrono::steady_clock::now()};

    //--------------------------------------------------------------------------
    // Detection Logic
    //--------------------------------------------------------------------------

    void detectLatentDemands()
    {
        checkForRepeatedActions();
        checkForExplorationPattern();
        checkForStuckPattern();
        checkForFeatureGap();
        checkRegisteredPatterns();
    }

    void checkForRepeatedActions()
    {
        if (actionHistory.size() < 5) return;

        // Check last 10 actions for repetition
        std::map<UserActionType, int> recent;
        int checkCount = std::min(10, static_cast<int>(actionHistory.size()));

        for (int i = 0; i < checkCount; i++)
        {
            auto& action = actionHistory[actionHistory.size() - 1 - i];
            recent[action.type]++;
        }

        for (const auto& [type, count] : recent)
        {
            if (count >= 4)  // Same action 4+ times in last 10
            {
                createDemand(
                    LatentDemandType::ShortcutSuggestion,
                    0.8f,
                    "Repeated " + actionTypeName(type) + " actions",
                    "There might be a faster way to do this",
                    LatentDemand::Priority::Medium
                );
            }
        }
    }

    void checkForExplorationPattern()
    {
        if (actionHistory.size() < 5) return;

        // Check for preset browsing without selection
        int browseCount = 0;
        int selectCount = 0;

        for (int i = 0; i < std::min(20, static_cast<int>(actionHistory.size())); i++)
        {
            auto& action = actionHistory[actionHistory.size() - 1 - i];
            if (action.type == UserActionType::PresetBrowse) browseCount++;
            if (action.type == UserActionType::PresetSelect) selectCount++;
        }

        if (browseCount > 10 && selectCount == 0)
        {
            createDemand(
                LatentDemandType::ExplorationAssist,
                0.75f,
                "Browsing many presets without selecting",
                "Looking for something specific? Try the search or filter",
                LatentDemand::Priority::Medium,
                "preset_search"
            );
        }
    }

    void checkForStuckPattern()
    {
        // Detect creative block: high idle + undos + low coherence
        if (pauseCount > 3 && undoCount > 5 && currentCoherence < 0.4f)
        {
            createDemand(
                LatentDemandType::CreativeBlock,
                0.7f,
                "Frequent pauses, undos, low coherence",
                "Feeling stuck? Try a new key or tempo suggestion",
                LatentDemand::Priority::High,
                "ai_suggestions"
            );
        }
    }

    void checkForFeatureGap()
    {
        // Detect when user is doing something manually that has automation

        // Example: Repeated parameter changes that could be automated
        int paramChanges = actionCounts[UserActionType::ParameterChange];
        if (paramChanges > 20)
        {
            createDemand(
                LatentDemandType::WorkflowOptimization,
                0.6f,
                "Many parameter changes",
                "Try using automation or modulation for these changes",
                LatentDemand::Priority::Low,
                "automation_lane"
            );
        }
    }

    void checkRegisteredPatterns()
    {
        for (const auto& pattern : registeredPatterns)
        {
            if (matchesPattern(pattern))
            {
                createDemand(
                    pattern.impliesDemand,
                    0.8f,
                    "Matched pattern: " + pattern.name,
                    pattern.responseSuggestion,
                    LatentDemand::Priority::Medium,
                    pattern.responseFeature
                );
            }
        }
    }

    bool matchesPattern(const BehavioralPattern& pattern)
    {
        if (actionHistory.size() < pattern.actionSequence.size())
            return false;

        // Check if recent actions match pattern sequence
        size_t patternIdx = 0;
        int matchCount = 0;
        double windowStart = getSessionTime() - pattern.timeWindow;

        for (auto it = actionHistory.rbegin(); it != actionHistory.rend(); ++it)
        {
            if (it->timestamp < windowStart) break;

            if (it->type == pattern.actionSequence[patternIdx])
            {
                matchCount++;
                patternIdx = (patternIdx + 1) % pattern.actionSequence.size();
            }
        }

        return matchCount >= pattern.repeatCount;
    }

    void checkForCreativeBlock()
    {
        // Called when long pause detected
        if (currentCoherence < 0.5f && undoCount > 2)
        {
            createDemand(
                LatentDemandType::CreativeBlock,
                0.65f,
                "Long pause with low coherence",
                "Need inspiration? Let Ralph suggest something",
                LatentDemand::Priority::Medium,
                "ralph_suggestions"
            );
        }
    }

    void detectFrustration(const std::string& evidence)
    {
        if (currentStress > 0.5f)
        {
            createDemand(
                LatentDemandType::FrustrationIntervention,
                currentStress,  // Higher stress = higher confidence
                evidence,
                "Take a breath. Would you like to simplify the view?",
                LatentDemand::Priority::High,
                "simplified_mode"
            );
        }
    }

    void suggestBreak()
    {
        createDemand(
            LatentDemandType::BreakSuggestion,
            0.9f,
            "High stress + low HRV",
            "Your body needs a short break",
            LatentDemand::Priority::Urgent
        );

        if (onBreakSuggested)
            onBreakSuggested();
    }

    //--------------------------------------------------------------------------
    // Demand Creation
    //--------------------------------------------------------------------------

    void createDemand(LatentDemandType type, float confidence,
                      const std::string& evidence, const std::string& suggestion,
                      LatentDemand::Priority priority,
                      const std::string& feature = "")
    {
        // Check if similar demand already exists
        for (const auto& d : detectedDemands)
        {
            if (d.type == type && !d.wasAddressed && !d.wasDismissed)
                return;  // Don't duplicate
        }

        LatentDemand demand;
        demand.id = "demand_" + std::to_string(detectedDemands.size());
        demand.type = type;
        demand.confidence = confidence;
        demand.evidence = evidence;
        demand.suggestion = suggestion;
        demand.featureToSurface = feature;
        demand.priority = priority;
        demand.detectedAt = getSessionTime();

        detectedDemands.push_back(demand);

        if (onDemandDetected)
            onDemandDetected(demand);

        if (!feature.empty() && onFeatureSurfaced)
            onFeatureSurfaced(feature);
    }

    //--------------------------------------------------------------------------
    // Helpers
    //--------------------------------------------------------------------------

    double getSessionTime() const
    {
        auto now = std::chrono::steady_clock::now();
        return std::chrono::duration<double>(now - sessionStart).count();
    }

    void updateActionCounts(const ActionRecord& action)
    {
        actionCounts[action.type]++;
        if (!action.context.empty())
            contextCounts[action.context]++;
    }

    std::string actionTypeName(UserActionType type) const
    {
        switch (type)
        {
            case UserActionType::NoteInput: return "note input";
            case UserActionType::ParameterChange: return "parameter change";
            case UserActionType::PresetBrowse: return "preset browse";
            case UserActionType::Undo: return "undo";
            case UserActionType::ModeSwitch: return "mode switch";
            case UserActionType::Search: return "search";
            default: return "action";
        }
    }

    //--------------------------------------------------------------------------
    // Default Patterns
    //--------------------------------------------------------------------------

    void registerDefaultPatterns()
    {
        // Undo-redo cycle (trying to find sweet spot)
        registeredPatterns.push_back({
            .name = "UndoRedoCycle",
            .actionSequence = {UserActionType::Undo, UserActionType::Redo},
            .repeatCount = 3,
            .timeWindow = 30.0,
            .impliesDemand = LatentDemandType::WorkflowOptimization,
            .responseFeature = "parameter_history",
            .responseSuggestion = "Use the parameter history to compare values"
        });

        // Mode switching (looking for something)
        registeredPatterns.push_back({
            .name = "ModeSwitching",
            .actionSequence = {UserActionType::ModeSwitch},
            .repeatCount = 5,
            .timeWindow = 60.0,
            .impliesDemand = LatentDemandType::ExplorationAssist,
            .responseFeature = "command_palette",
            .responseSuggestion = "Use Command Palette (Cmd+K) to quickly find anything"
        });

        // Help seeking
        registeredPatterns.push_back({
            .name = "HelpSeeking",
            .actionSequence = {UserActionType::Help},
            .repeatCount = 2,
            .timeWindow = 120.0,
            .impliesDemand = LatentDemandType::ConceptClarification,
            .responseFeature = "contextual_help",
            .responseSuggestion = "Would you like a quick tutorial on this feature?"
        });
    }
};

//==============================================================================
// CONVENIENCE MACRO
//==============================================================================

#define EchoelDemand LatentDemandDetector::shared()

} // namespace Echoel
