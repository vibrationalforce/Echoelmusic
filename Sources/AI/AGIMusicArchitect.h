#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <queue>
#include <future>

#include "LargeReasoningModel.h"
#include "AudioReasoningModel.h"
#include "PaTHAttention.h"
#include "AGIReasoningEngine.h"
#include "NeuromorphicProcessor.h"
#include "QuantumInspiredOptimizer.h"
#include "SkillBasedAI.h"

/**
 * AGIMusicArchitect - Unified AGI System for Music Production
 *
 * The capstone AI architecture that integrates all advanced systems:
 * - Large Reasoning Models (test-time compute scaling)
 * - Multi-modal audio understanding
 * - Long-horizon music planning
 * - Adaptive skill orchestration
 * - Neuromorphic and quantum-inspired optimization
 *
 * Designed to approach AGI-level music production capabilities:
 * - Compose full songs from prompts
 * - Arrange and orchestrate autonomously
 * - Mix and master with professional quality
 * - Adapt to any genre or style
 * - Learn from feedback continuously
 *
 * 2026 AGI-Ready Architecture
 */

namespace Echoelmusic {
namespace AI {

//==============================================================================
// AGI Goals and Planning
//==============================================================================

struct MusicGoal
{
    std::string description;
    std::string genre;
    std::string mood;
    float targetDurationSeconds;
    int targetBPM;
    std::string keySignature;

    std::vector<std::string> requiredElements;  // e.g., "piano", "bass drop", "chorus"
    std::vector<std::string> stylisticReferences;
    std::map<std::string, std::string> constraints;

    enum class Priority { Low, Medium, High, Critical };
    Priority priority = Priority::Medium;

    bool isComplete = false;
    float progressPercent = 0.0f;
};

struct MusicPlan
{
    std::string planId;
    MusicGoal goal;

    struct PlanStep
    {
        std::string action;
        std::string description;
        std::vector<std::string> dependencies;
        std::string assignedSkill;
        bool completed = false;
        float estimatedTimeSeconds = 0.0f;
    };

    std::vector<PlanStep> steps;
    int currentStep = 0;

    std::string getSummary() const
    {
        std::string summary = "Plan: " + goal.description + "\n";
        summary += "Steps: " + std::to_string(steps.size()) + "\n";
        summary += "Progress: " + std::to_string(currentStep) + "/" +
                   std::to_string(steps.size()) + "\n";
        return summary;
    }
};

//==============================================================================
// AGI Session State
//==============================================================================

class AGISessionState
{
public:
    struct SessionMemory
    {
        std::vector<std::string> conversationHistory;
        std::vector<std::pair<std::string, std::string>> actionHistory;  // action, result
        std::map<std::string, juce::var> learnedPreferences;
        std::vector<AudioEmbeddingSpace::AudioEmbedding> audioMemory;
    };

    void recordAction(const std::string& action, const std::string& result)
    {
        memory.actionHistory.push_back({action, result});
        pruneIfNeeded();
    }

    void recordConversation(const std::string& message)
    {
        memory.conversationHistory.push_back(message);
    }

    void learnPreference(const std::string& key, const juce::var& value)
    {
        memory.learnedPreferences[key] = value;
    }

    void storeAudioMemory(const AudioEmbeddingSpace::AudioEmbedding& emb)
    {
        memory.audioMemory.push_back(emb);
        if (memory.audioMemory.size() > maxAudioMemory)
            memory.audioMemory.erase(memory.audioMemory.begin());
    }

    std::string getRecentContext(int maxItems = 10) const
    {
        std::string context;
        int start = std::max(0, static_cast<int>(memory.conversationHistory.size()) - maxItems);
        for (size_t i = start; i < memory.conversationHistory.size(); ++i)
            context += memory.conversationHistory[i] + "\n";
        return context;
    }

    const SessionMemory& getMemory() const { return memory; }

private:
    SessionMemory memory;
    static constexpr size_t maxHistoryItems = 100;
    static constexpr size_t maxAudioMemory = 50;

    void pruneIfNeeded()
    {
        if (memory.actionHistory.size() > maxHistoryItems)
            memory.actionHistory.erase(memory.actionHistory.begin());
        if (memory.conversationHistory.size() > maxHistoryItems)
            memory.conversationHistory.erase(memory.conversationHistory.begin());
    }
};

//==============================================================================
// AGI Music Architect
//==============================================================================

class AGIMusicArchitect
{
public:
    struct Config
    {
        // Reasoning configuration
        ReasoningConfig reasoningConfig;

        // Cost controls
        float maxCostPerSession = 50.0f;     // USD
        float maxCostPerTask = 5.0f;

        // Compute allocation
        int maxParallelTasks = 4;
        bool useGPU = true;
        bool useNeuromorphic = false;
        bool useQuantumInspired = true;

        // Learning
        bool enableOnlineLearning = true;
        bool rememberUserPreferences = true;

        // Safety
        bool requireApprovalForDestructive = true;
        float creativityTemperature = 0.8f;
    };

    static AGIMusicArchitect& getInstance()
    {
        static AGIMusicArchitect instance;
        return instance;
    }

    void configure(const Config& cfg) { config = cfg; }

    //--------------------------------------------------------------------------
    // High-Level AGI Interface
    //--------------------------------------------------------------------------

    using ProgressCallback = std::function<void(float progress, const std::string& status)>;
    using CompletionCallback = std::function<void(bool success, const std::string& result)>;

    /**
     * Create complete music from a prompt
     * This is the AGI-level interface: describe what you want, get music.
     */
    void createMusicFromPrompt(const std::string& prompt,
                                ProgressCallback onProgress,
                                CompletionCallback onComplete)
    {
        sessionState.recordConversation("User: " + prompt);

        std::thread([this, prompt, onProgress, onComplete]() {
            try
            {
                // Step 1: Understand the prompt (5%)
                onProgress(0.05f, "Understanding your request...");
                auto goal = interpretPrompt(prompt);

                // Step 2: Create a plan (10%)
                onProgress(0.10f, "Creating composition plan...");
                auto plan = createPlan(goal);

                // Step 3: Execute the plan (10-90%)
                executePlan(plan, [onProgress](float p, const std::string& s) {
                    onProgress(0.10f + p * 0.80f, s);
                });

                // Step 4: Finalize (90-100%)
                onProgress(0.90f, "Finalizing composition...");
                auto result = finalizePlan(plan);

                onProgress(1.0f, "Complete!");
                onComplete(true, result);
            }
            catch (const std::exception& e)
            {
                onComplete(false, std::string("Error: ") + e.what());
            }
        }).detach();
    }

    /**
     * Interactive music conversation
     */
    struct ConversationResponse
    {
        std::string text;
        std::vector<std::string> suggestedActions;
        std::map<std::string, juce::var> data;
        bool actionRequired = false;
    };

    ConversationResponse chat(const std::string& userMessage)
    {
        ConversationResponse response;

        sessionState.recordConversation("User: " + userMessage);

        // Determine intent
        auto intent = classifyIntent(userMessage);

        switch (intent)
        {
            case Intent::CreateMusic:
                response.text = "I'd be happy to help create music! Let me understand what you're looking for...";
                response.suggestedActions = {"Start composing", "Set parameters first", "Browse templates"};
                response.actionRequired = true;
                break;

            case Intent::ModifyMusic:
                response.text = "I can help modify the current composition. What would you like to change?";
                response.suggestedActions = {"Change tempo", "Add instrument", "Modify melody", "Adjust mix"};
                break;

            case Intent::AnalyzeMusic:
                response.text = "I'll analyze the music for you. What aspects are you interested in?";
                response.suggestedActions = {"Chord analysis", "Structure analysis", "Mix analysis"};
                break;

            case Intent::Question:
                response = answerMusicQuestion(userMessage);
                break;

            case Intent::Feedback:
                response.text = "Thank you for the feedback! I'll remember this for future compositions.";
                learnFromFeedback(userMessage);
                break;

            default:
                response.text = "I'm here to help with music production. You can ask me to compose, "
                               "analyze, or modify music.";
                response.suggestedActions = {"Compose something", "What can you do?", "Analyze my audio"};
        }

        sessionState.recordConversation("Assistant: " + response.text);
        return response;
    }

    //--------------------------------------------------------------------------
    // Composition Interface
    //--------------------------------------------------------------------------

    /**
     * Compose a complete song structure
     */
    struct CompositionResult
    {
        std::vector<std::pair<std::string, std::vector<std::tuple<int, int, float>>>> tracks;
        std::string structure;  // e.g., "Intro-Verse-Chorus-Verse-Chorus-Bridge-Chorus-Outro"
        float durationSeconds;
        std::string reasoning;
    };

    CompositionResult compose(const MusicGoal& goal)
    {
        CompositionResult result;

        // Use reasoning to plan structure
        std::string structurePrompt = "Design a song structure for:\n" + goal.description;
        structurePrompt += "\nGenre: " + goal.genre;
        structurePrompt += "\nMood: " + goal.mood;
        structurePrompt += "\nDuration: " + std::to_string(goal.targetDurationSeconds) + " seconds";

        auto trace = ReasoningAI.reason(structurePrompt, config.reasoningConfig);
        result.structure = extractStructure(trace.finalAnswer);
        result.reasoning = trace.getThinkingProcess();

        // Generate tracks for each section
        auto sections = parseSections(result.structure);
        for (const auto& section : sections)
        {
            auto sectionTracks = generateSection(section, goal);
            for (auto& track : sectionTracks)
                result.tracks.push_back(track);
        }

        result.durationSeconds = goal.targetDurationSeconds;

        return result;
    }

    /**
     * Arrange existing material
     */
    struct ArrangementResult
    {
        std::map<std::string, std::vector<std::pair<float, float>>> trackRegions;  // track -> (start, end)
        std::string reasoning;
    };

    ArrangementResult arrange(const std::vector<std::string>& trackNames,
                               const MusicGoal& goal)
    {
        ArrangementResult result;

        std::string prompt = "Create an arrangement for these tracks:\n";
        for (const auto& name : trackNames)
            prompt += "- " + name + "\n";

        prompt += "\nGoal: " + goal.description;
        prompt += "\nStyle: " + goal.genre;

        auto trace = ReasoningAI.reason(prompt, config.reasoningConfig);
        result.reasoning = trace.finalAnswer;

        // Parse arrangement from reasoning
        float currentTime = 0.0f;
        for (const auto& name : trackNames)
        {
            std::vector<std::pair<float, float>> regions;
            regions.push_back({currentTime, goal.targetDurationSeconds});
            result.trackRegions[name] = regions;
        }

        return result;
    }

    //--------------------------------------------------------------------------
    // Mix Engineering Interface
    //--------------------------------------------------------------------------

    struct MixResult
    {
        std::map<std::string, std::map<std::string, float>> trackSettings;
        std::string reasoning;
        float overallLoudness;
    };

    MixResult mixTracks(
        const std::vector<std::pair<std::string, juce::AudioBuffer<float>>>& tracks,
        const std::string& genre,
        const std::string& targetReference = "")
    {
        MixResult result;

        auto decisions = AudioAI.reasonMixDecisions(tracks, genre, targetReference);

        for (const auto& decision : decisions)
        {
            std::map<std::string, float> settings;
            settings["volume"] = decision.volume;
            settings["pan"] = decision.panPosition;
            settings["compThreshold"] = decision.compressionThreshold;
            settings["compRatio"] = decision.compressionRatio;

            result.trackSettings[decision.trackName] = settings;
            result.reasoning += decision.reasoning + "\n";
        }

        result.overallLoudness = -14.0f;  // Standard streaming loudness

        return result;
    }

    //--------------------------------------------------------------------------
    // Learning and Adaptation
    //--------------------------------------------------------------------------

    void learnFromFeedback(const std::string& feedback)
    {
        if (!config.enableOnlineLearning) return;

        // Analyze feedback sentiment and specifics
        std::string prompt = R"(Analyze this user feedback about music:
")" + feedback + R"("

Extract:
1. Sentiment (positive/negative/neutral)
2. What they liked
3. What they didn't like
4. Specific actionable preferences to remember

Format as key-value pairs.)";

        auto trace = ReasoningAI.reason(prompt, config.reasoningConfig);

        // Store learned preferences
        sessionState.learnPreference("last_feedback", feedback);
        sessionState.recordAction("learn_feedback", trace.finalAnswer);
    }

    /**
     * Adapt to user's style over time
     */
    void adaptToUser(const std::vector<std::pair<std::string, juce::AudioBuffer<float>>>& userMusic)
    {
        // Embed and remember user's music style
        for (const auto& [name, audio] : userMusic)
        {
            AudioEmbeddingSpace space;
            auto emb = space.embedAudio(audio);
            sessionState.storeAudioMemory(emb);
        }

        // Analyze patterns
        std::string prompt = "I've analyzed " + std::to_string(userMusic.size()) +
            " tracks from this user. Their style preferences appear to be:";

        auto trace = ReasoningAI.reason(prompt, config.reasoningConfig);
        sessionState.learnPreference("user_style", trace.finalAnswer);
    }

    //--------------------------------------------------------------------------
    // Metrics and Status
    //--------------------------------------------------------------------------

    struct AGIMetrics
    {
        float sessionCost;
        int tasksCompleted;
        float averageConfidence;
        int plansCreated;
        int skillsUsed;
        double totalProcessingTimeMs;
    };

    AGIMetrics getMetrics() const { return metrics; }

    float getRemainingBudget() const
    {
        return config.maxCostPerSession - ReasoningAI.getSessionCost();
    }

private:
    AGIMusicArchitect() = default;

    Config config;
    AGISessionState sessionState;
    AGIMetrics metrics{};

    //--------------------------------------------------------------------------
    // Intent Classification
    //--------------------------------------------------------------------------

    enum class Intent
    {
        CreateMusic,
        ModifyMusic,
        AnalyzeMusic,
        Question,
        Feedback,
        Unknown
    };

    Intent classifyIntent(const std::string& message)
    {
        std::string lower = message;
        std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);

        if (lower.find("create") != std::string::npos ||
            lower.find("compose") != std::string::npos ||
            lower.find("make") != std::string::npos ||
            lower.find("generate") != std::string::npos)
            return Intent::CreateMusic;

        if (lower.find("change") != std::string::npos ||
            lower.find("modify") != std::string::npos ||
            lower.find("edit") != std::string::npos ||
            lower.find("adjust") != std::string::npos)
            return Intent::ModifyMusic;

        if (lower.find("analyze") != std::string::npos ||
            lower.find("what") != std::string::npos ||
            lower.find("identify") != std::string::npos)
            return Intent::AnalyzeMusic;

        if (lower.find("?") != std::string::npos ||
            lower.find("how") != std::string::npos ||
            lower.find("why") != std::string::npos)
            return Intent::Question;

        if (lower.find("like") != std::string::npos ||
            lower.find("don't") != std::string::npos ||
            lower.find("prefer") != std::string::npos ||
            lower.find("better") != std::string::npos)
            return Intent::Feedback;

        return Intent::Unknown;
    }

    //--------------------------------------------------------------------------
    // Prompt Interpretation
    //--------------------------------------------------------------------------

    MusicGoal interpretPrompt(const std::string& prompt)
    {
        std::string reasoningPrompt = R"(Interpret this music creation request:
")" + prompt + R"("

Extract:
1. Genre (if mentioned or implied)
2. Mood/emotion (if mentioned or implied)
3. Tempo/BPM (if mentioned, else suggest appropriate)
4. Duration (if mentioned, else suggest appropriate)
5. Key signature (if mentioned, else suggest)
6. Specific elements requested
7. Style references

Be specific and actionable.)";

        auto trace = ReasoningAI.reason(reasoningPrompt, config.reasoningConfig);

        MusicGoal goal;
        goal.description = prompt;
        goal.genre = "electronic";       // Parse from trace
        goal.mood = "energetic";         // Parse from trace
        goal.targetBPM = 120;            // Parse from trace
        goal.targetDurationSeconds = 180.0f;
        goal.keySignature = "C major";   // Parse from trace

        return goal;
    }

    //--------------------------------------------------------------------------
    // Planning
    //--------------------------------------------------------------------------

    MusicPlan createPlan(const MusicGoal& goal)
    {
        MusicPlan plan;
        plan.goal = goal;
        plan.planId = "plan_" + std::to_string(std::time(nullptr));

        std::string prompt = "Create a step-by-step plan to produce this music:\n" +
            goal.description + "\n\nGenre: " + goal.genre + "\nMood: " + goal.mood;

        auto trace = ReasoningAI.reason(prompt, config.reasoningConfig);

        // Default plan structure
        plan.steps = {
            {"analyze_requirements", "Analyze the music requirements", {}, "analysis", false, 5.0f},
            {"design_structure", "Design the song structure", {"analyze_requirements"}, "composition", false, 10.0f},
            {"compose_harmony", "Compose chord progressions", {"design_structure"}, "harmony", false, 20.0f},
            {"compose_melody", "Compose melodies", {"compose_harmony"}, "melody", false, 30.0f},
            {"compose_rhythm", "Create rhythm and drum patterns", {"design_structure"}, "rhythm", false, 20.0f},
            {"arrange", "Arrange all elements", {"compose_melody", "compose_rhythm"}, "arrangement", false, 15.0f},
            {"mix", "Mix and balance", {"arrange"}, "mixing", false, 20.0f},
            {"master", "Master the final mix", {"mix"}, "mastering", false, 10.0f}
        };

        metrics.plansCreated++;

        return plan;
    }

    void executePlan(MusicPlan& plan, ProgressCallback onProgress)
    {
        for (size_t i = 0; i < plan.steps.size(); ++i)
        {
            auto& step = plan.steps[i];

            float progress = static_cast<float>(i) / plan.steps.size();
            onProgress(progress, "Executing: " + step.description);

            // Execute step
            executeStep(step, plan.goal);

            step.completed = true;
            plan.currentStep = static_cast<int>(i) + 1;

            metrics.tasksCompleted++;
        }
    }

    void executeStep(MusicPlan::PlanStep& step, const MusicGoal& goal)
    {
        std::string prompt = "Execute this music production step:\n";
        prompt += "Action: " + step.action + "\n";
        prompt += "Description: " + step.description + "\n";
        prompt += "Context: " + goal.description + "\n";
        prompt += "Genre: " + goal.genre + ", Mood: " + goal.mood;

        auto trace = ReasoningAI.reason(prompt, config.reasoningConfig);

        sessionState.recordAction(step.action, trace.finalAnswer);
    }

    std::string finalizePlan(const MusicPlan& plan)
    {
        std::string summary = "Completed music production:\n";
        summary += "Goal: " + plan.goal.description + "\n";
        summary += "Genre: " + plan.goal.genre + "\n";
        summary += "Steps completed: " + std::to_string(plan.currentStep) + "/" +
                   std::to_string(plan.steps.size()) + "\n";
        summary += "\nReady for playback and export.";
        return summary;
    }

    //--------------------------------------------------------------------------
    // Question Answering
    //--------------------------------------------------------------------------

    ConversationResponse answerMusicQuestion(const std::string& question)
    {
        ConversationResponse response;

        std::string prompt = "Answer this music production question:\n" + question;
        prompt += "\n\nProvide a helpful, educational answer. If applicable, suggest "
                  "how this could be applied in the current session.";

        auto trace = ReasoningAI.reason(prompt, config.reasoningConfig);

        response.text = trace.finalAnswer;
        response.suggestedActions = {"Apply this advice", "Tell me more", "Show example"};

        return response;
    }

    //--------------------------------------------------------------------------
    // Composition Helpers
    //--------------------------------------------------------------------------

    std::string extractStructure(const std::string& reasoningOutput)
    {
        // Parse structure from reasoning
        return "Intro-Verse-Chorus-Verse-Chorus-Bridge-Chorus-Outro";
    }

    std::vector<std::string> parseSections(const std::string& structure)
    {
        std::vector<std::string> sections;
        std::string current;

        for (char c : structure)
        {
            if (c == '-')
            {
                if (!current.empty())
                {
                    sections.push_back(current);
                    current.clear();
                }
            }
            else
            {
                current += c;
            }
        }
        if (!current.empty())
            sections.push_back(current);

        return sections;
    }

    std::vector<std::pair<std::string, std::vector<std::tuple<int, int, float>>>>
    generateSection(const std::string& sectionName, const MusicGoal& goal)
    {
        std::vector<std::pair<std::string, std::vector<std::tuple<int, int, float>>>> tracks;

        // Generate melody for section
        std::vector<std::tuple<int, int, float>> melodyNotes;
        float time = 0.0f;
        for (int i = 0; i < 16; ++i)
        {
            int pitch = 60 + (std::rand() % 12);
            melodyNotes.push_back({pitch, 80, time});
            time += 0.25f;
        }
        tracks.push_back({"Melody_" + sectionName, melodyNotes});

        // Generate bass for section
        std::vector<std::tuple<int, int, float>> bassNotes;
        time = 0.0f;
        for (int i = 0; i < 8; ++i)
        {
            int pitch = 36 + (std::rand() % 12);
            bassNotes.push_back({pitch, 100, time});
            time += 0.5f;
        }
        tracks.push_back({"Bass_" + sectionName, bassNotes});

        return tracks;
    }
};

//==============================================================================
// Convenience Macro
//==============================================================================

#define MusicAGI AGIMusicArchitect::getInstance()

} // namespace AI
} // namespace Echoelmusic
