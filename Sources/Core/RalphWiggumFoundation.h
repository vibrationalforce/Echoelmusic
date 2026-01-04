/*
  ==============================================================================

    RalphWiggumFoundation.h
    Ralph Wiggum Loop Genius - Core Foundation

    "My cat's breath smells like cat food" - Ralph Wiggum
    "My loops smell like fire" - Ralph Wiggum Loop Genius

    The philosophical and technical foundation for the Ralph Wiggum
    Loop Genius creative system. Embraces simplicity, creativity,
    and the beautiful chaos of music making.

    Core Principles:
    1. SIMPLICITY - Complex power through simple interfaces
    2. CREATIVITY - No rules, only possibilities
    3. FLOW - Stay in the zone, never interrupt
    4. RESILIENCE - Keep playing, no matter what
    5. JOY - Music should be fun

    Created: 2026
    Author: Echoelmusic Team

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "EchoelCore.h"
#include "GlobalKeyScaleManager.h"
#include "WiseSaveMode.h"
#include "SelfHealingSystem.h"
#include <memory>
#include <functional>
#include <atomic>
#include <mutex>
#include <map>
#include <vector>
#include <queue>
#include <optional>

namespace RalphWiggum
{

// Forward declare the namespace types we use
using namespace Echoelmusic;

//==============================================================================
/** Creative modes for different workflows */
enum class CreativeMode
{
    Exploration,    // Free-form experimentation, no rules
    Production,     // Structured workflow for finishing tracks
    Performance,    // Live performance optimizations
    Healing,        // Wellness and therapeutic mode
    Meditation,     // Calm, focused, minimal interface
    Learning,       // Guided tutorials and tips
    Collaboration   // Multi-user session mode
};

//==============================================================================
/** Genius level affects AI assistance behavior */
enum class GeniusLevel
{
    Apprentice,     // Lots of guidance and suggestions
    Journeyman,     // Balanced help when needed
    Master,         // Minimal intervention, maximum freedom
    Sage            // AI learns from YOU
};

//==============================================================================
/** Loop state for the Loop Genius */
struct LoopState
{
    int loopId = 0;
    juce::String name;
    int lengthBars = 4;
    double tempo = 120.0;
    KeySignature key;

    // Layers
    int layerCount = 0;
    bool isRecording = false;
    bool isPlaying = false;
    bool isArmed = false;

    // Sync
    bool isMaster = false;
    bool isSynced = true;

    // Effects
    float feedback = 0.0f;      // 0-1
    float filterCutoff = 1.0f;  // 0-1
    float pitch = 0.0f;         // Semitones
    float speed = 1.0f;         // 0.5-2.0
    bool reverse = false;

    // State
    juce::Time createdTime;
    juce::Time lastModifiedTime;
};

//==============================================================================
/** Creative suggestion from AI */
struct CreativeSuggestion
{
    enum class Type
    {
        Chord,          // Chord suggestion
        Melody,         // Melodic idea
        Rhythm,         // Rhythmic pattern
        Effect,         // Effect to try
        Arrangement,    // Arrangement suggestion
        Mix,            // Mixing suggestion
        Sound,          // Sound design idea
        Inspiration     // General creative prompt
    };

    Type type;
    juce::String title;
    juce::String description;
    float confidence = 0.0f;    // 0-1
    juce::var data;             // Type-specific data

    // For chord/melody suggestions
    std::optional<KeySignature> suggestedKey;
    std::vector<int> midiNotes;

    // UI
    bool wasDismissed = false;
    bool wasApplied = false;
    juce::Time suggestedAt;
};

//==============================================================================
/** Session metrics for analytics */
struct SessionMetrics
{
    juce::Time sessionStart;
    double totalTimeSeconds = 0.0;
    double activeTimeSeconds = 0.0;     // Time actually making music

    int loopsCreated = 0;
    int loopsDeleted = 0;
    int suggestionsReceived = 0;
    int suggestionsApplied = 0;

    int keyChanges = 0;
    int tempoChanges = 0;
    int undoCount = 0;
    int redoCount = 0;

    float averageCpuLoad = 0.0f;
    int crashRecoveries = 0;

    // Creative flow
    double longestFlowStateSeconds = 0.0;
    int flowStateCount = 0;
};

//==============================================================================
/**
    RalphWiggumFoundation

    The core creative engine that powers the Loop Genius experience.

    Features:
    - Creative mode management
    - AI-powered suggestions
    - Loop state management
    - Session metrics
    - Flow state detection
    - Wisdom database (learning from usage)
*/
class RalphWiggumFoundation : public juce::Timer,
                               public Echoelmusic::SystemEventListener
{
public:
    //==========================================================================
    // Singleton Access

    static RalphWiggumFoundation& getInstance()
    {
        static RalphWiggumFoundation instance;
        return instance;
    }

    //==========================================================================
    // Initialization

    /**
        Initialize the Ralph Wiggum Loop Genius foundation.
        Registers all modules with EchoelCore.
    */
    bool initialize()
    {
        if (initialized)
            return true;

        juce::Logger::writeToLog("===========================================");
        juce::Logger::writeToLog("    RALPH WIGGUM LOOP GENIUS");
        juce::Logger::writeToLog("    Foundation Initialization");
        juce::Logger::writeToLog("===========================================");

        // Register with core system
        EchoelCore::getInstance().addEventListener(this);

        // Initialize subsystems
        initializeKeyScaleSystem();
        initializeWiseSaveMode();
        initializeCreativeAI();

        // Start session
        metrics.sessionStart = juce::Time::getCurrentTime();
        startTimer(sessionUpdateIntervalMs);

        initialized = true;

        juce::Logger::writeToLog("[RalphWiggum] Foundation initialized");
        juce::Logger::writeToLog("[RalphWiggum] Creative Mode: " + getCreativeModeName());
        juce::Logger::writeToLog("[RalphWiggum] Genius Level: " + getGeniusLevelName());

        return true;
    }

    void shutdown()
    {
        if (!initialized)
            return;

        stopTimer();
        EchoelCore::getInstance().removeEventListener(this);

        // Save session metrics
        saveSessionMetrics();

        initialized = false;
    }

    //==========================================================================
    // Creative Mode

    void setCreativeMode(CreativeMode mode)
    {
        if (currentMode != mode)
        {
            previousMode = currentMode;
            currentMode = mode;

            applyModeSettings();

            juce::Logger::writeToLog("[RalphWiggum] Mode changed to: " + getCreativeModeName());
        }
    }

    CreativeMode getCreativeMode() const { return currentMode; }

    juce::String getCreativeModeName() const
    {
        switch (currentMode)
        {
            case CreativeMode::Exploration: return "Exploration";
            case CreativeMode::Production: return "Production";
            case CreativeMode::Performance: return "Performance";
            case CreativeMode::Healing: return "Healing";
            case CreativeMode::Meditation: return "Meditation";
            case CreativeMode::Learning: return "Learning";
            case CreativeMode::Collaboration: return "Collaboration";
            default: return "Unknown";
        }
    }

    //==========================================================================
    // Genius Level

    void setGeniusLevel(GeniusLevel level)
    {
        geniusLevel = level;
        adjustAIBehavior();
    }

    GeniusLevel getGeniusLevel() const { return geniusLevel; }

    juce::String getGeniusLevelName() const
    {
        switch (geniusLevel)
        {
            case GeniusLevel::Apprentice: return "Apprentice";
            case GeniusLevel::Journeyman: return "Journeyman";
            case GeniusLevel::Master: return "Master";
            case GeniusLevel::Sage: return "Sage";
            default: return "Unknown";
        }
    }

    //==========================================================================
    // Loop Management

    /**
        Create a new loop.
    */
    int createLoop(const juce::String& name = "")
    {
        LoopState loop;
        loop.loopId = nextLoopId++;
        loop.name = name.isEmpty() ?
            "Loop " + juce::String(loop.loopId + 1) : name;
        loop.key = GlobalKeyScaleManager::getInstance().getCurrentKey();
        loop.tempo = currentTempo;
        loop.createdTime = juce::Time::getCurrentTime();
        loop.lastModifiedTime = loop.createdTime;

        loops[loop.loopId] = loop;
        metrics.loopsCreated++;

        juce::Logger::writeToLog("[RalphWiggum] Created loop: " + loop.name);
        return loop.loopId;
    }

    /**
        Get a loop by ID.
    */
    std::optional<LoopState> getLoop(int loopId) const
    {
        auto it = loops.find(loopId);
        if (it != loops.end())
            return it->second;
        return std::nullopt;
    }

    /**
        Update loop state.
    */
    void updateLoop(int loopId, const LoopState& state)
    {
        auto it = loops.find(loopId);
        if (it != loops.end())
        {
            it->second = state;
            it->second.lastModifiedTime = juce::Time::getCurrentTime();
        }
    }

    /**
        Delete a loop.
    */
    bool deleteLoop(int loopId)
    {
        auto it = loops.find(loopId);
        if (it != loops.end())
        {
            loops.erase(it);
            metrics.loopsDeleted++;
            return true;
        }
        return false;
    }

    /**
        Get all loops.
    */
    std::vector<LoopState> getAllLoops() const
    {
        std::vector<LoopState> result;
        for (const auto& [id, loop] : loops)
        {
            result.push_back(loop);
        }
        return result;
    }

    //==========================================================================
    // Tempo & Sync

    void setTempo(double bpm)
    {
        if (currentTempo != bpm)
        {
            currentTempo = bpm;
            metrics.tempoChanges++;

            // Sync to WiseSave
            WiseSaveMode::getInstance().setTempo(bpm);
        }
    }

    double getTempo() const { return currentTempo; }

    //==========================================================================
    // AI Suggestions

    /**
        Request a creative suggestion.
    */
    CreativeSuggestion requestSuggestion(CreativeSuggestion::Type type)
    {
        CreativeSuggestion suggestion;
        suggestion.type = type;
        suggestion.suggestedAt = juce::Time::getCurrentTime();

        // Generate suggestion based on type and context
        switch (type)
        {
            case CreativeSuggestion::Type::Chord:
                suggestion = generateChordSuggestion();
                break;

            case CreativeSuggestion::Type::Melody:
                suggestion = generateMelodySuggestion();
                break;

            case CreativeSuggestion::Type::Rhythm:
                suggestion = generateRhythmSuggestion();
                break;

            case CreativeSuggestion::Type::Effect:
                suggestion = generateEffectSuggestion();
                break;

            case CreativeSuggestion::Type::Inspiration:
                suggestion = generateInspirationSuggestion();
                break;

            default:
                suggestion.title = "Keep exploring!";
                suggestion.description = "Try something new.";
                break;
        }

        recentSuggestions.push_back(suggestion);
        metrics.suggestionsReceived++;

        return suggestion;
    }

    /**
        Mark a suggestion as applied.
    */
    void applySuggestion(const CreativeSuggestion& suggestion)
    {
        metrics.suggestionsApplied++;

        // Learn from applied suggestions
        if (geniusLevel == GeniusLevel::Sage)
        {
            learnFromSuggestion(suggestion);
        }
    }

    /**
        Get recent suggestions.
    */
    std::vector<CreativeSuggestion> getRecentSuggestions(int count = 5) const
    {
        std::vector<CreativeSuggestion> result;
        int start = std::max(0, (int)recentSuggestions.size() - count);
        for (int i = start; i < (int)recentSuggestions.size(); ++i)
        {
            result.push_back(recentSuggestions[i]);
        }
        return result;
    }

    //==========================================================================
    // Flow State Detection

    /**
        Check if user is in flow state.
    */
    bool isInFlowState() const { return inFlowState; }

    /**
        Get current flow intensity (0-1).
    */
    float getFlowIntensity() const { return flowIntensity; }

    //==========================================================================
    // Metrics

    SessionMetrics getSessionMetrics() const { return metrics; }

    //==========================================================================
    // Wisdom Database

    /**
        Get wisdom quote.
    */
    juce::String getWisdom() const
    {
        static const juce::StringArray wisdom = {
            "My cat's breath smells like cat food.",
            "I bent my wookiee.",
            "Me fail English? That's unpossible!",
            "The doctor said I wouldn't have so many nosebleeds if I kept my finger outta there.",
            "When I grow up, I want to be a principal or a caterpillar.",
            "I'm Idaho!",
            "What's a battle?",
            "I found a moon rock in my nose!",
            "Miss Hoover, my worm went in my mouth and then I ate it.",
            "Sleep! That's where I'm a Viking!",
            // Music wisdom
            "Every loop is a new beginning.",
            "The best music comes from the heart.",
            "Mistakes are just happy little accidents.",
            "Keep looping, keep creating.",
            "Your vibe attracts your tribe.",
            "Music heals what words cannot.",
            "Stay in the flow, let the music grow.",
            "Simple is beautiful."
        };

        return wisdom[juce::Random::getSystemRandom().nextInt(wisdom.size())];
    }

    //==========================================================================
    // System Event Handler

    void onSystemEvent(const Echoelmusic::SystemEvent& event) override
    {
        switch (event.type)
        {
            case Echoelmusic::SystemEvent::Type::ModuleError:
                handleModuleError(event);
                break;

            case Echoelmusic::SystemEvent::Type::ModuleRecovered:
                handleModuleRecovered(event);
                break;

            default:
                break;
        }
    }

    //==========================================================================
    // Serialization

    std::unique_ptr<juce::XmlElement> createStateXML() const
    {
        auto xml = std::make_unique<juce::XmlElement>("RalphWiggumFoundation");

        xml->setAttribute("creativeMode", static_cast<int>(currentMode));
        xml->setAttribute("geniusLevel", static_cast<int>(geniusLevel));
        xml->setAttribute("tempo", currentTempo);
        xml->setAttribute("flowIntensity", flowIntensity);

        // Loops
        auto* loopsXml = xml->createNewChildElement("Loops");
        for (const auto& [id, loop] : loops)
        {
            auto* loopXml = loopsXml->createNewChildElement("Loop");
            loopXml->setAttribute("id", loop.loopId);
            loopXml->setAttribute("name", loop.name);
            loopXml->setAttribute("lengthBars", loop.lengthBars);
            loopXml->setAttribute("tempo", loop.tempo);
            loopXml->setAttribute("layerCount", loop.layerCount);
            loopXml->setAttribute("feedback", loop.feedback);
            loopXml->setAttribute("speed", loop.speed);
            loopXml->setAttribute("reverse", loop.reverse);
        }

        // Metrics
        auto* metricsXml = xml->createNewChildElement("Metrics");
        metricsXml->setAttribute("loopsCreated", metrics.loopsCreated);
        metricsXml->setAttribute("suggestionsApplied", metrics.suggestionsApplied);
        metricsXml->setAttribute("keyChanges", metrics.keyChanges);
        metricsXml->setAttribute("tempoChanges", metrics.tempoChanges);
        metricsXml->setAttribute("flowStateCount", metrics.flowStateCount);

        return xml;
    }

    void restoreFromXML(const juce::XmlElement& xml)
    {
        currentMode = static_cast<CreativeMode>(xml.getIntAttribute("creativeMode", 0));
        geniusLevel = static_cast<GeniusLevel>(xml.getIntAttribute("geniusLevel", 1));
        currentTempo = xml.getDoubleAttribute("tempo", 120.0);
        flowIntensity = (float)xml.getDoubleAttribute("flowIntensity", 0.0);

        // Restore loops
        loops.clear();
        if (auto* loopsXml = xml.getChildByName("Loops"))
        {
            for (auto* loopXml : loopsXml->getChildIterator())
            {
                LoopState loop;
                loop.loopId = loopXml->getIntAttribute("id");
                loop.name = loopXml->getStringAttribute("name");
                loop.lengthBars = loopXml->getIntAttribute("lengthBars", 4);
                loop.tempo = loopXml->getDoubleAttribute("tempo", 120.0);
                loop.layerCount = loopXml->getIntAttribute("layerCount", 0);
                loop.feedback = (float)loopXml->getDoubleAttribute("feedback", 0.0);
                loop.speed = (float)loopXml->getDoubleAttribute("speed", 1.0);
                loop.reverse = loopXml->getBoolAttribute("reverse", false);

                loops[loop.loopId] = loop;
                nextLoopId = std::max(nextLoopId, loop.loopId + 1);
            }
        }
    }

private:
    RalphWiggumFoundation() = default;
    ~RalphWiggumFoundation() { shutdown(); }

    RalphWiggumFoundation(const RalphWiggumFoundation&) = delete;
    RalphWiggumFoundation& operator=(const RalphWiggumFoundation&) = delete;

    //==========================================================================
    // Timer callback

    void timerCallback() override
    {
        updateMetrics();
        detectFlowState();
        autoSuggestIfNeeded();
    }

    //==========================================================================
    // Initialization helpers

    void initializeKeyScaleSystem()
    {
        // Key/Scale manager is already a singleton, just ensure it's ready
        GlobalKeyScaleManager::getInstance();
    }

    void initializeWiseSaveMode()
    {
        auto& wiseSave = WiseSaveMode::getInstance();
        auto config = wiseSave.getConfig();
        config.autoSaveEnabled = true;
        config.createSnapshotOnKeyChange = true;
        config.smartNamingEnabled = true;
        wiseSave.setConfig(config);
    }

    void initializeCreativeAI()
    {
        // Initialize AI suggestion system
        adjustAIBehavior();
    }

    //==========================================================================
    // Mode management

    void applyModeSettings()
    {
        switch (currentMode)
        {
            case CreativeMode::Exploration:
                suggestionFrequency = 0.3f;  // More suggestions
                break;

            case CreativeMode::Production:
                suggestionFrequency = 0.1f;  // Fewer interruptions
                break;

            case CreativeMode::Performance:
                suggestionFrequency = 0.0f;  // No suggestions during performance
                break;

            case CreativeMode::Healing:
                suggestionFrequency = 0.2f;
                // Enable healing-specific features
                break;

            case CreativeMode::Meditation:
                suggestionFrequency = 0.0f;  // Silent mode
                break;

            case CreativeMode::Learning:
                suggestionFrequency = 0.5f;  // Lots of guidance
                break;

            default:
                break;
        }
    }

    void adjustAIBehavior()
    {
        switch (geniusLevel)
        {
            case GeniusLevel::Apprentice:
                aiConfidenceThreshold = 0.3f;   // Show more suggestions
                aiVerbosity = 1.0f;             // Detailed explanations
                break;

            case GeniusLevel::Journeyman:
                aiConfidenceThreshold = 0.5f;
                aiVerbosity = 0.6f;
                break;

            case GeniusLevel::Master:
                aiConfidenceThreshold = 0.8f;   // Only high-confidence suggestions
                aiVerbosity = 0.3f;             // Brief hints
                break;

            case GeniusLevel::Sage:
                aiConfidenceThreshold = 0.9f;   // Very selective
                aiVerbosity = 0.2f;
                aiLearningEnabled = true;       // Learn from user
                break;
        }
    }

    //==========================================================================
    // AI Suggestions

    CreativeSuggestion generateChordSuggestion()
    {
        CreativeSuggestion suggestion;
        suggestion.type = CreativeSuggestion::Type::Chord;
        suggestion.suggestedKey = GlobalKeyScaleManager::getInstance().getCurrentKey();

        // Generate based on current key
        auto key = suggestion.suggestedKey.value();
        int root = static_cast<int>(key.root);

        // Suggest a common chord progression chord
        static const std::vector<std::vector<int>> progressions = {
            {0, 5, 3, 4},   // I-vi-IV-V
            {0, 4, 5, 3},   // I-V-vi-IV
            {0, 3, 4, 4},   // I-IV-V-V
            {1, 4, 0, 3}    // ii-V-I-IV
        };

        auto& prog = progressions[juce::Random::getSystemRandom().nextInt((int)progressions.size())];
        int degree = prog[juce::Random::getSystemRandom().nextInt((int)prog.size())];

        suggestion.midiNotes = {60 + root + degree, 64 + root + degree, 67 + root + degree};
        suggestion.title = "Try this chord";
        suggestion.description = "Based on your current key of " + key.getDisplayName();
        suggestion.confidence = 0.7f;

        return suggestion;
    }

    CreativeSuggestion generateMelodySuggestion()
    {
        CreativeSuggestion suggestion;
        suggestion.type = CreativeSuggestion::Type::Melody;
        suggestion.title = "Melodic idea";
        suggestion.description = "A simple motif to try";

        auto key = GlobalKeyScaleManager::getInstance().getCurrentKey();
        auto intervals = key.getIntervals();
        int root = static_cast<int>(key.root);

        // Generate a simple melodic motif
        for (int i = 0; i < 4; ++i)
        {
            int intervalIdx = juce::Random::getSystemRandom().nextInt((int)intervals.size());
            suggestion.midiNotes.push_back(60 + root + intervals[intervalIdx]);
        }

        suggestion.confidence = 0.6f;
        return suggestion;
    }

    CreativeSuggestion generateRhythmSuggestion()
    {
        CreativeSuggestion suggestion;
        suggestion.type = CreativeSuggestion::Type::Rhythm;

        static const juce::StringArray rhythms = {
            "Try a syncopated pattern",
            "Add some ghost notes",
            "Half-time feel could work here",
            "Double-time for energy",
            "Polyrhythm: 3 against 4",
            "Swing the eighth notes"
        };

        suggestion.title = rhythms[juce::Random::getSystemRandom().nextInt(rhythms.size())];
        suggestion.description = "Rhythm variation to try";
        suggestion.confidence = 0.5f;

        return suggestion;
    }

    CreativeSuggestion generateEffectSuggestion()
    {
        CreativeSuggestion suggestion;
        suggestion.type = CreativeSuggestion::Type::Effect;

        static const juce::StringArray effects = {
            "Add some reverb for space",
            "Try a subtle delay",
            "Chorus for width",
            "Distortion for character",
            "Phaser for movement",
            "Tremolo for texture",
            "Bitcrusher for lo-fi vibes",
            "Granular for ambience"
        };

        suggestion.title = effects[juce::Random::getSystemRandom().nextInt(effects.size())];
        suggestion.description = "Effect to enhance your sound";
        suggestion.confidence = 0.5f;

        return suggestion;
    }

    CreativeSuggestion generateInspirationSuggestion()
    {
        CreativeSuggestion suggestion;
        suggestion.type = CreativeSuggestion::Type::Inspiration;

        static const juce::StringArray inspirations = {
            "What if the melody went up instead of down?",
            "Try removing an element instead of adding",
            "What emotion are you trying to capture?",
            "Close your eyes and play what you feel",
            "What would this sound like underwater?",
            "Imagine playing this for someone you love",
            "What color is this music?",
            "Let it breathe - add some space",
            "Break the pattern!",
            "Trust your instincts"
        };

        suggestion.title = inspirations[juce::Random::getSystemRandom().nextInt(inspirations.size())];
        suggestion.description = getWisdom();
        suggestion.confidence = 0.4f;

        return suggestion;
    }

    void learnFromSuggestion(const CreativeSuggestion& suggestion)
    {
        // Store applied suggestion patterns for future reference
        // This would build a preference model over time
    }

    void autoSuggestIfNeeded()
    {
        if (suggestionFrequency <= 0.0f)
            return;

        // Random chance based on frequency
        if (juce::Random::getSystemRandom().nextFloat() < suggestionFrequency * 0.01f)
        {
            // Pick a random suggestion type
            auto type = static_cast<CreativeSuggestion::Type>(
                juce::Random::getSystemRandom().nextInt(5));

            auto suggestion = requestSuggestion(type);
            if (suggestion.confidence >= aiConfidenceThreshold)
            {
                // Queue suggestion for display
                pendingSuggestions.push(suggestion);
            }
        }
    }

    //==========================================================================
    // Flow state detection

    void detectFlowState()
    {
        // Simple flow detection based on activity
        // Real implementation would analyze:
        // - Consistent activity patterns
        // - Minimal pause time
        // - Low undo rate
        // - Steady creative output

        double activeRatio = metrics.activeTimeSeconds /
            std::max(1.0, metrics.totalTimeSeconds);

        float undoRatio = metrics.loopsCreated > 0 ?
            (float)metrics.undoCount / metrics.loopsCreated : 0.0f;

        // High activity + low undo = flow
        flowIntensity = std::min(1.0f, (float)activeRatio * 2.0f) *
                        (1.0f - std::min(1.0f, undoRatio));

        bool wasInFlow = inFlowState;
        inFlowState = flowIntensity > 0.6f;

        if (inFlowState && !wasInFlow)
        {
            metrics.flowStateCount++;
            flowStartTime = juce::Time::getCurrentTime();
        }
        else if (!inFlowState && wasInFlow)
        {
            auto flowDuration = juce::Time::getCurrentTime() - flowStartTime;
            metrics.longestFlowStateSeconds = std::max(
                metrics.longestFlowStateSeconds, flowDuration.inSeconds());
        }
    }

    //==========================================================================
    // Metrics

    void updateMetrics()
    {
        auto now = juce::Time::getCurrentTime();
        metrics.totalTimeSeconds = (now - metrics.sessionStart).inSeconds();

        // Track active time (simplified - real impl would track actual activity)
        static juce::Time lastActive;
        if (!loops.empty())
        {
            metrics.activeTimeSeconds += (now - lastActive).inSeconds();
        }
        lastActive = now;
    }

    void saveSessionMetrics()
    {
        // Save to file for analytics
        auto metricsFile = juce::File::getSpecialLocation(
            juce::File::userApplicationDataDirectory)
            .getChildFile("Echoelmusic")
            .getChildFile("session_metrics.json");

        // Would serialize and save metrics here
    }

    //==========================================================================
    // Error handling

    void handleModuleError(const Echoelmusic::SystemEvent& event)
    {
        // Create recovery checkpoint
        SelfHealingSystem::getInstance().createCheckpoint("Pre-error: " + event.message);
    }

    void handleModuleRecovered(const Echoelmusic::SystemEvent& event)
    {
        metrics.crashRecoveries++;
    }

    //==========================================================================
    // State

    bool initialized = false;

    // Creative state
    CreativeMode currentMode = CreativeMode::Exploration;
    CreativeMode previousMode = CreativeMode::Exploration;
    GeniusLevel geniusLevel = GeniusLevel::Journeyman;

    // Loops
    std::map<int, LoopState> loops;
    int nextLoopId = 0;
    double currentTempo = 120.0;

    // AI
    float suggestionFrequency = 0.2f;
    float aiConfidenceThreshold = 0.5f;
    float aiVerbosity = 0.6f;
    bool aiLearningEnabled = false;

    std::vector<CreativeSuggestion> recentSuggestions;
    std::queue<CreativeSuggestion> pendingSuggestions;

    // Flow state
    bool inFlowState = false;
    float flowIntensity = 0.0f;
    juce::Time flowStartTime;

    // Metrics
    SessionMetrics metrics;
    int sessionUpdateIntervalMs = 1000;
};

} // namespace RalphWiggum
