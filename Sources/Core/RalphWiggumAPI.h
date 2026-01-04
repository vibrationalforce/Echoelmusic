/*
  ==============================================================================

    RalphWiggumAPI.h
    Ralph Wiggum Unified API

    Single entry point for all Ralph Wiggum creative systems.
    Provides a clean, consistent interface that coordinates:
    - RalphWiggumFoundation (Loop Genius)
    - RalphWiggumAIBridge (AI Suggestions)
    - ProgressiveDisclosureEngine (Adaptive UI)
    - LatentDemandDetector (User Intent)
    - WiseSaveMode (Intelligent Saving)
    - AICompositionEngine (Music Generation)
    - StyleTransferEngine (Style Application)

    "One API to rule them all" - Ralph Wiggum Enterprise Edition

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "RalphWiggumFoundation.h"
#include "RalphWiggumAIBridge.h"
#include "ProgressiveDisclosureEngine.h"
#include "LatentDemandDetector.h"
#include "WiseSaveMode.h"
#include "GlobalKeyScaleManager.h"
#include "EchoelTypeSystem.h"
#include "../AI/AICompositionEngine.h"
#include "../AI/StyleTransferEngine.h"
#include <memory>
#include <functional>
#include <atomic>
#include <mutex>

namespace RalphWiggum {

using namespace Echoelmusic;

//==============================================================================
// Event Types for Callbacks
//==============================================================================

struct RalphEvent
{
    enum class Type
    {
        // Suggestions
        SuggestionReady,
        SuggestionAccepted,
        SuggestionRejected,

        // Generation
        MelodyGenerated,
        ChordGenerated,
        RhythmGenerated,

        // State Changes
        KeyChanged,
        TempoChanged,
        ModeChanged,

        // Bio-Reactive
        CoherenceChanged,
        FlowStateChanged,
        WellnessAlert,

        // UI Adaptation
        DisclosureLevelChanged,
        DemandDetected,

        // Session
        SessionSaved,
        SessionLoaded,
        RecoveryCreated
    };

    Type type;
    juce::var data;
    juce::Time timestamp;
};

using EventCallback = std::function<void(const RalphEvent&)>;

//==============================================================================
// Configuration
//==============================================================================

struct RalphConfig
{
    // AI Settings
    bool enableAI = true;
    float aiCreativity = 0.7f;          // 0-1, maps to temperature
    bool bioReactiveAI = true;          // Adapt to bio-signals

    // UI Settings
    bool progressiveDisclosure = true;  // Adaptive complexity
    int initialExpertiseLevel = 2;      // 1-5

    // Save Settings
    bool autoSave = true;
    int autoSaveIntervalSeconds = 60;
    bool cloudSync = false;

    // Performance Settings
    int maxLatencyMs = 50;
    bool lowLatencyMode = false;

    // Genre/Style
    juce::String defaultGenre = "pop";
    juce::String defaultMood = "neutral";
};

//==============================================================================
// Ralph Wiggum API - Main Interface
//==============================================================================

class RalphWiggumAPI
{
public:
    static RalphWiggumAPI& getInstance()
    {
        static RalphWiggumAPI instance;
        return instance;
    }

    //==========================================================================
    // Lifecycle
    //==========================================================================

    void initialize(const RalphConfig& config = {})
    {
        std::lock_guard<std::mutex> lock(apiMutex);

        if (initialized)
            return;

        currentConfig = config;

        // Initialize subsystems
        if (config.enableAI)
        {
            AI::AIModelConfig aiConfig;
            aiConfig.temperature = config.aiCreativity;
            aiConfig.adaptToCoherence = config.bioReactiveAI;
            aiConfig.maxLatencyMs = config.maxLatencyMs;

            AI::AICompositionEngine::getInstance().initialize(aiConfig);
        }

        if (config.progressiveDisclosure)
        {
            ProgressiveDisclosureEngine::getInstance().setExpertiseLevel(
                config.initialExpertiseLevel);
        }

        WiseSaveMode::getInstance().initialize();

        initialized = true;

        emit({RalphEvent::Type::ModeChanged, "initialized", juce::Time::getCurrentTime()});
    }

    void shutdown()
    {
        std::lock_guard<std::mutex> lock(apiMutex);

        if (!initialized)
            return;

        // Trigger final save
        WiseSaveMode::getInstance().createManualSnapshot("Shutdown");

        // Shutdown AI
        AI::AICompositionEngine::getInstance().shutdown();

        initialized = false;
    }

    bool isInitialized() const { return initialized; }

    //==========================================================================
    // Musical Context
    //==========================================================================

    void setKey(int root, bool isMinor = false)
    {
        std::lock_guard<std::mutex> lock(apiMutex);

        currentKey = root;
        currentIsMinor = isMinor;

        // Update all subsystems
        GlobalKeyScaleManager::getInstance().setKey(
            static_cast<KeySignature::Root>(root),
            isMinor ? KeySignature::ScaleType::NaturalMinor : KeySignature::ScaleType::Major
        );

        RalphWiggumAIBridge::getInstance().setKey(
            root,
            isMinor ? RalphWiggumAIBridge::ScaleType::NaturalMinor :
                      RalphWiggumAIBridge::ScaleType::Major
        );

        AI::CompositionContext ctx;
        ctx.rootNote = root;
        ctx.isMinor = isMinor;
        AI::AICompositionEngine::getInstance().updateContext(ctx);

        emit({RalphEvent::Type::KeyChanged, root, juce::Time::getCurrentTime()});
    }

    void setTempo(double bpm)
    {
        std::lock_guard<std::mutex> lock(apiMutex);

        currentTempo = bpm;

        RalphWiggumAIBridge::getInstance().setTempo(bpm);

        emit({RalphEvent::Type::TempoChanged, bpm, juce::Time::getCurrentTime()});
    }

    void setGenre(const juce::String& genre)
    {
        std::lock_guard<std::mutex> lock(apiMutex);

        currentGenre = genre;
        AI::AICompositionEngine::getInstance().setGenre(genre);

        emit({RalphEvent::Type::ModeChanged, genre, juce::Time::getCurrentTime()});
    }

    void setMood(const juce::String& mood)
    {
        std::lock_guard<std::mutex> lock(apiMutex);

        currentMood = mood;
        AI::AICompositionEngine::getInstance().setMood(mood);
    }

    //==========================================================================
    // Bio-Reactive Updates
    //==========================================================================

    void updateBioState(float coherence, float hrv, float stress)
    {
        std::lock_guard<std::mutex> lock(apiMutex);

        currentCoherence = coherence;
        currentHRV = hrv;
        currentStress = stress;

        // Update all bio-reactive systems
        RalphWiggumAIBridge::BioContext bio;
        bio.coherence = coherence;
        bio.stress = stress;
        RalphWiggumAIBridge::getInstance().updateBioContext(bio);

        // Adapt AI
        float flow = (coherence + (1.0f - stress)) / 2.0f;
        AI::AICompositionEngine::getInstance().updateBioState(coherence, flow, stress);

        // Update progressive disclosure
        ProgressiveDisclosureEngine::BioState bioState;
        bioState.coherence = coherence;
        bioState.heartRate = 60.0f + hrv;  // Simplified
        ProgressiveDisclosureEngine::getInstance().updateBioState(bioState);

        // Check for wellness alerts
        if (stress > 0.8f)
        {
            emit({RalphEvent::Type::WellnessAlert, "high_stress", juce::Time::getCurrentTime()});
        }

        emit({RalphEvent::Type::CoherenceChanged, coherence, juce::Time::getCurrentTime()});
    }

    //==========================================================================
    // AI Suggestions
    //==========================================================================

    struct Suggestion
    {
        juce::String id;
        juce::String title;
        juce::String description;
        float confidence = 0.0f;

        // Content (depending on type)
        std::vector<int> midiNotes;
        std::vector<float> durations;
        std::vector<float> velocities;
    };

    Suggestion getNextSuggestion()
    {
        std::lock_guard<std::mutex> lock(apiMutex);

        // Get from AI Bridge
        auto bridgeSuggestion = RalphWiggumAIBridge::getInstance().getNextSuggestion();

        Suggestion result;
        result.id = bridgeSuggestion.id;
        result.title = bridgeSuggestion.displayText;
        result.description = bridgeSuggestion.reason;
        result.confidence = bridgeSuggestion.confidence;
        result.midiNotes = bridgeSuggestion.notes;

        emit({RalphEvent::Type::SuggestionReady, result.id, juce::Time::getCurrentTime()});

        return result;
    }

    std::vector<Suggestion> getSuggestions(int count = 3)
    {
        std::lock_guard<std::mutex> lock(apiMutex);

        auto bridgeSuggestions = RalphWiggumAIBridge::getInstance().getSuggestions(count);

        std::vector<Suggestion> results;
        for (const auto& s : bridgeSuggestions)
        {
            Suggestion result;
            result.id = s.id;
            result.title = s.displayText;
            result.description = s.reason;
            result.confidence = s.confidence;
            result.midiNotes = s.notes;
            results.push_back(result);
        }

        return results;
    }

    void acceptSuggestion(const juce::String& id)
    {
        RalphWiggumAIBridge::getInstance().acceptSuggestion(id.toStdString());
        AI::AICompositionEngine::getInstance().acceptSuggestion(id.getLargeIntValue());

        emit({RalphEvent::Type::SuggestionAccepted, id, juce::Time::getCurrentTime()});
    }

    void rejectSuggestion(const juce::String& id)
    {
        RalphWiggumAIBridge::getInstance().rejectSuggestion(id.toStdString());
        AI::AICompositionEngine::getInstance().rejectSuggestion(id.getLargeIntValue());

        emit({RalphEvent::Type::SuggestionRejected, id, juce::Time::getCurrentTime()});
    }

    //==========================================================================
    // AI Generation
    //==========================================================================

    struct GeneratedMelody
    {
        std::vector<int> notes;
        std::vector<float> durations;
        std::vector<float> velocities;
        juce::String description;
        float confidence = 0.0f;
    };

    GeneratedMelody generateMelody(int length = 8)
    {
        auto aiMelody = AI::AICompositionEngine::getInstance().generateMelody(length);

        GeneratedMelody result;
        result.notes = aiMelody.notes;
        result.durations = aiMelody.durations;
        result.velocities = aiMelody.velocities;
        result.description = aiMelody.description.toStdString();
        result.confidence = aiMelody.confidence;

        emit({RalphEvent::Type::MelodyGenerated, length, juce::Time::getCurrentTime()});

        return result;
    }

    void generateMelodyAsync(int length, std::function<void(const GeneratedMelody&)> callback)
    {
        AI::AICompositionEngine::getInstance().requestMelodyAsync(length,
            [callback](const AI::GeneratedMelody& aiMelody) {
                GeneratedMelody result;
                result.notes = aiMelody.notes;
                result.durations = aiMelody.durations;
                result.velocities = aiMelody.velocities;
                result.description = aiMelody.description.toStdString();
                result.confidence = aiMelody.confidence;
                callback(result);
            });
    }

    //==========================================================================
    // Style Transfer
    //==========================================================================

    std::vector<juce::String> getAvailableStyles()
    {
        auto styles = AI::StyleTransferEngine::getInstance().getAvailablePresets();
        std::vector<juce::String> result;
        for (const auto& s : styles)
            result.push_back(s);
        return result;
    }

    GeneratedMelody applyStyle(const GeneratedMelody& input, const juce::String& styleName, float strength = 0.7f)
    {
        // Convert to style transfer format
        std::vector<AI::StyledMIDI::Note> styledInput;
        float currentTime = 0.0f;
        for (size_t i = 0; i < input.notes.size(); ++i)
        {
            AI::StyledMIDI::Note note;
            note.pitch = input.notes[i];
            note.startBeat = currentTime;
            note.duration = i < input.durations.size() ? input.durations[i] : 0.5f;
            note.velocity = i < input.velocities.size() ? input.velocities[i] : 0.7f;
            note.channel = 1;
            styledInput.push_back(note);
            currentTime += note.duration;
        }

        auto styled = AI::StyleTransferEngine::getInstance().applyPreset(
            styledInput, styleName, strength);

        // Convert back
        GeneratedMelody result;
        for (const auto& note : styled.notes)
        {
            result.notes.push_back(note.pitch);
            result.durations.push_back(note.duration);
            result.velocities.push_back(note.velocity);
        }
        result.description = styled.description.toStdString();
        result.confidence = styled.styleConfidence;

        return result;
    }

    //==========================================================================
    // User Activity Recording
    //==========================================================================

    void recordNote(int midiNote, float velocity = 0.8f)
    {
        RalphWiggumAIBridge::getInstance().recordNote(midiNote);
        AI::AICompositionEngine::getInstance().recordNote(midiNote, velocity);
        WiseSaveMode::getInstance().markDirty();
    }

    void recordChord(const std::vector<int>& notes)
    {
        if (!notes.empty())
            RalphWiggumAIBridge::getInstance().recordChord(notes[0]);
        AI::AICompositionEngine::getInstance().recordChord(notes);
        WiseSaveMode::getInstance().markDirty();
    }

    void recordAction(const juce::String& action)
    {
        LatentDemandDetector::getInstance().recordAction(action.toStdString());
    }

    void recordUndo()
    {
        LatentDemandDetector::getInstance().recordUndo();
    }

    //==========================================================================
    // Progressive Disclosure
    //==========================================================================

    int getExpertiseLevel()
    {
        return ProgressiveDisclosureEngine::getInstance().getCurrentLevel();
    }

    void setExpertiseLevel(int level)
    {
        ProgressiveDisclosureEngine::getInstance().setExpertiseLevel(level);
        emit({RalphEvent::Type::DisclosureLevelChanged, level, juce::Time::getCurrentTime()});
    }

    std::vector<juce::String> getVisibleFeatures()
    {
        auto features = ProgressiveDisclosureEngine::getInstance().getVisibleFeatures();
        std::vector<juce::String> result;
        for (const auto& f : features)
            result.push_back(f);
        return result;
    }

    //==========================================================================
    // Latent Demand Detection
    //==========================================================================

    struct DetectedDemand
    {
        juce::String type;
        juce::String description;
        float confidence;
    };

    std::vector<DetectedDemand> getDetectedDemands()
    {
        auto demands = LatentDemandDetector::getInstance().detectDemands();

        std::vector<DetectedDemand> result;
        for (const auto& d : demands)
        {
            DetectedDemand demand;
            demand.type = juce::String(static_cast<int>(d.type));
            demand.description = d.description;
            demand.confidence = d.confidence;
            result.push_back(demand);

            emit({RalphEvent::Type::DemandDetected, demand.type, juce::Time::getCurrentTime()});
        }

        return result;
    }

    //==========================================================================
    // Session Management
    //==========================================================================

    void saveSession(const juce::String& name = "")
    {
        juce::String snapshotName = name.isEmpty() ? "Manual Save" : name;
        WiseSaveMode::getInstance().createManualSnapshot(snapshotName);

        emit({RalphEvent::Type::SessionSaved, snapshotName, juce::Time::getCurrentTime()});
    }

    bool loadSession(const juce::String& snapshotId)
    {
        bool success = WiseSaveMode::getInstance().restoreSnapshot(snapshotId);

        if (success)
            emit({RalphEvent::Type::SessionLoaded, snapshotId, juce::Time::getCurrentTime()});

        return success;
    }

    std::vector<juce::String> getSessionHistory()
    {
        auto snapshots = WiseSaveMode::getInstance().getSnapshots();
        std::vector<juce::String> result;
        for (const auto& s : snapshots)
            result.push_back(s.id);
        return result;
    }

    bool isDirty()
    {
        return WiseSaveMode::getInstance().isDirtyState();
    }

    //==========================================================================
    // Event System
    //==========================================================================

    void addEventListener(EventCallback callback)
    {
        std::lock_guard<std::mutex> lock(eventMutex);
        eventListeners.push_back(callback);
    }

    void clearEventListeners()
    {
        std::lock_guard<std::mutex> lock(eventMutex);
        eventListeners.clear();
    }

    //==========================================================================
    // Statistics
    //==========================================================================

    struct Stats
    {
        int suggestionsGenerated = 0;
        int suggestionsAccepted = 0;
        int suggestionsRejected = 0;
        double acceptanceRate = 0.0;

        int melodiesGenerated = 0;
        int chordsGenerated = 0;

        double averageLatencyMs = 0.0;

        float currentCoherence = 0.0f;
        float currentStress = 0.0f;
    };

    Stats getStats()
    {
        auto aiStats = AI::AICompositionEngine::getInstance().getStats();

        Stats stats;
        stats.suggestionsGenerated = aiStats.totalGenerations;
        stats.suggestionsAccepted = aiStats.acceptedGenerations;
        stats.suggestionsRejected = aiStats.rejectedGenerations;
        stats.acceptanceRate = aiStats.acceptanceRate;
        stats.averageLatencyMs = aiStats.averageLatencyMs;

        stats.currentCoherence = currentCoherence;
        stats.currentStress = currentStress;

        return stats;
    }

private:
    RalphWiggumAPI() = default;
    ~RalphWiggumAPI() { shutdown(); }
    RalphWiggumAPI(const RalphWiggumAPI&) = delete;
    RalphWiggumAPI& operator=(const RalphWiggumAPI&) = delete;

    void emit(const RalphEvent& event)
    {
        std::lock_guard<std::mutex> lock(eventMutex);
        for (const auto& listener : eventListeners)
        {
            try {
                listener(event);
            } catch (...) {
                // Don't let listener errors crash the system
            }
        }
    }

    mutable std::mutex apiMutex;
    mutable std::mutex eventMutex;

    std::atomic<bool> initialized{false};
    RalphConfig currentConfig;

    // Current state
    int currentKey = 0;
    bool currentIsMinor = false;
    double currentTempo = 120.0;
    juce::String currentGenre = "pop";
    juce::String currentMood = "neutral";

    float currentCoherence = 0.5f;
    float currentHRV = 50.0f;
    float currentStress = 0.3f;

    std::vector<EventCallback> eventListeners;
};

//==============================================================================
// Convenience Macros
//==============================================================================

#define RalphAPI RalphWiggum::RalphWiggumAPI::getInstance()

} // namespace RalphWiggum
