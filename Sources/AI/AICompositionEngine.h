/*
  ==============================================================================

    AICompositionEngine.h
    Phase 5: AI Composition Layer

    Advanced AI-assisted music composition that works with the musician,
    not instead of them. Inspired by:
    - LFM2-2.6B-Exp: Edge-optimized inference
    - Latent diffusion: Generative audio concepts
    - Reinforcement learning from human feedback (RLHF)

    Core Philosophy:
    "AI should amplify human creativity, not replace it."

    Features:
    - Contextual melody generation
    - Harmonic completion
    - Rhythm pattern synthesis
    - Style transfer
    - Arrangement suggestions
    - Bio-reactive adaptation
    - On-device inference (no cloud dependency)

    Created: 2026
    Author: Echoelmusic Team

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "../Core/RalphWiggumAIBridge.h"
#include "../Core/LatentDemandDetector.h"
#include "../Core/ProgressiveDisclosureEngine.h"
#include "../Core/MusicTheoryUtils.h"
#include "../Core/EchoelTypeSystem.h"
#include <vector>
#include <memory>
#include <functional>
#include <atomic>
#include <mutex>
#include <queue>
#include <thread>
#include <condition_variable>
#include <random>
#include <cmath>

namespace Echoelmusic {
namespace AI {

using namespace Types;
using namespace MusicTheory;

//==============================================================================
// Forward Declarations
//==============================================================================

class AICompositionEngine;
class MelodyGenerator;
class HarmonyEngine;
class RhythmSynthesizer;
class ArrangementAdvisor;

//==============================================================================
// AI Model Configuration
//==============================================================================

struct AIModelConfig
{
    // Model selection
    enum class ModelSize
    {
        Nano,       // 50M params - instant, basic suggestions
        Micro,      // 150M params - fast, good quality
        Small,      // 500M params - balanced
        Medium,     // 1B params - high quality
        Large       // 2.6B params (LFM2 inspired) - best quality
    };

    ModelSize modelSize = ModelSize::Micro;

    // Inference settings
    float temperature = 0.7f;           // Creativity (0.0 = deterministic, 1.0 = wild)
    float topP = 0.9f;                  // Nucleus sampling
    int topK = 50;                      // Top-K sampling
    int maxTokens = 256;                // Max generation length
    float repetitionPenalty = 1.1f;     // Avoid repetitive output

    // Resource limits
    int maxMemoryMB = 512;              // RAM budget
    int maxLatencyMs = 100;             // Max acceptable latency
    bool useGPU = false;                // Prefer GPU if available
    bool quantize = true;               // Use INT8/INT4 quantization

    // Bio-reactive adjustments
    bool adaptToCoherence = true;       // Simplify when stressed
    bool adaptToFlow = true;            // Match creative intensity
};

//==============================================================================
// Musical Context for Generation
//==============================================================================

struct CompositionContext
{
    // Key and scale
    int rootNote = 0;                   // C = 0, C# = 1, etc.
    std::vector<int> scaleNotes;        // Available notes
    bool isMinor = false;

    // Tempo and time
    double tempo = 120.0;               // BPM
    int timeSignatureNum = 4;
    int timeSignatureDenom = 4;
    double currentBeat = 0.0;           // Position in song

    // Recent musical events (for context)
    std::vector<int> recentNotes;       // Last 16 notes played
    std::vector<int> recentChords;      // Last 8 chords
    std::vector<float> recentVelocities;

    // Style hints
    juce::String genre;                 // "jazz", "electronic", "classical", etc.
    juce::String mood;                  // "uplifting", "melancholic", "energetic"
    float energy = 0.5f;                // 0.0 = calm, 1.0 = intense
    float complexity = 0.5f;            // 0.0 = simple, 1.0 = complex

    // Bio-reactive context
    float coherence = 0.5f;             // HRV coherence
    float flowIntensity = 0.5f;         // Creative flow state
    float stress = 0.3f;                // Stress level

    // What the user is working on
    enum class TaskType
    {
        Composing,      // Writing new material
        Arranging,      // Organizing sections
        Mixing,         // Adjusting levels/effects
        Mastering,      // Final polish
        Performing,     // Live performance
        Learning        // Tutorial/practice
    };
    TaskType currentTask = TaskType::Composing;
};

//==============================================================================
// Generated Content Types
//==============================================================================

struct GeneratedMelody
{
    std::vector<int> notes;             // MIDI note numbers
    std::vector<float> durations;       // Beat durations
    std::vector<float> velocities;      // 0.0 - 1.0
    std::vector<float> startTimes;      // Beat positions

    float confidence = 0.0f;            // Model confidence
    juce::String description;           // Human-readable description
    juce::String reasoning;             // Why this was generated

    bool isEmpty() const { return notes.empty(); }
    int length() const { return static_cast<int>(notes.size()); }
};

struct GeneratedChordProgression
{
    struct Chord
    {
        std::vector<int> notes;         // MIDI notes
        juce::String symbol;            // "Cmaj7", "Dm", etc.
        float duration = 1.0f;          // Bars
        int inversion = 0;              // 0 = root, 1 = first, etc.
    };

    std::vector<Chord> chords;
    float confidence = 0.0f;
    juce::String description;
    juce::String function;              // "tension-release", "circle of fifths", etc.
};

struct GeneratedRhythm
{
    struct Hit
    {
        float time = 0.0f;              // Beat position
        float velocity = 0.8f;
        float duration = 0.1f;
        juce::String instrument;        // "kick", "snare", "hihat", etc.
    };

    std::vector<Hit> hits;
    int lengthBeats = 4;
    float swing = 0.0f;                 // 0.0 = straight, 0.5 = triplet swing
    float confidence = 0.0f;
    juce::String style;                 // "four-on-floor", "breakbeat", etc.
};

struct ArrangementSuggestion
{
    enum class SectionType
    {
        Intro,
        Verse,
        PreChorus,
        Chorus,
        Bridge,
        Breakdown,
        Drop,
        Outro,
        Fill,
        Transition
    };

    SectionType suggestedSection;
    int startBar = 0;
    int lengthBars = 8;
    float energy = 0.5f;                // Suggested energy level
    juce::StringArray instrumentsToAdd;
    juce::StringArray instrumentsToRemove;
    juce::String reasoning;
    float confidence = 0.0f;
};

//==============================================================================
// Generation Request (async queue)
//==============================================================================

struct GenerationRequest
{
    enum class Type
    {
        Melody,
        Chord,
        Rhythm,
        Arrangement,
        Continuation,           // Continue from what user played
        Variation,              // Vary existing material
        Harmonization,          // Add harmony to melody
        CounterMelody           // Generate complementary line
    };

    Type type = Type::Melody;
    CompositionContext context;
    AIModelConfig config;

    // Optional constraints
    std::optional<int> targetLength;    // Notes/beats
    std::optional<int> minNote;         // MIDI range
    std::optional<int> maxNote;
    std::optional<float> minVelocity;
    std::optional<float> maxVelocity;

    // Callback when complete
    std::function<void(const GeneratedMelody&)> melodyCallback;
    std::function<void(const GeneratedChordProgression&)> chordCallback;
    std::function<void(const GeneratedRhythm&)> rhythmCallback;
    std::function<void(const ArrangementSuggestion&)> arrangementCallback;

    // Request metadata
    int64_t requestId = 0;
    juce::Time requestTime;
    int priority = 0;                   // Higher = more important
};

//==============================================================================
// AI Composition Engine - Main Class
//==============================================================================

class AICompositionEngine
{
public:
    static AICompositionEngine& getInstance()
    {
        static AICompositionEngine instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    // Lifecycle
    //--------------------------------------------------------------------------

    void initialize(const AIModelConfig& config = {})
    {
        std::lock_guard<std::mutex> lock(engineMutex);

        modelConfig = config;
        initializeModels();

        // Start worker thread
        if (!workerRunning)
        {
            workerRunning = true;
            workerThread = std::thread(&AICompositionEngine::workerLoop, this);
        }

        initialized = true;
    }

    void shutdown()
    {
        {
            std::lock_guard<std::mutex> lock(queueMutex);
            workerRunning = false;
        }
        queueCondition.notify_all();

        if (workerThread.joinable())
            workerThread.join();

        initialized = false;
    }

    bool isInitialized() const { return initialized; }

    //--------------------------------------------------------------------------
    // Context Updates
    //--------------------------------------------------------------------------

    void updateContext(const CompositionContext& ctx)
    {
        std::lock_guard<std::mutex> lock(contextMutex);
        currentContext = ctx;
    }

    void updateBioState(float coherence, float flow, float stress)
    {
        std::lock_guard<std::mutex> lock(contextMutex);
        currentContext.coherence = coherence;
        currentContext.flowIntensity = flow;
        currentContext.stress = stress;

        // Adjust model behavior based on bio state
        if (modelConfig.adaptToCoherence)
        {
            // Low coherence = simpler suggestions
            float adjustedComplexity = currentContext.complexity * coherence;
            currentContext.complexity = adjustedComplexity;
        }
    }

    void recordNote(int midiNote, float velocity)
    {
        std::lock_guard<std::mutex> lock(contextMutex);

        currentContext.recentNotes.push_back(midiNote);
        if (currentContext.recentNotes.size() > 16)
            currentContext.recentNotes.erase(currentContext.recentNotes.begin());

        currentContext.recentVelocities.push_back(velocity);
        if (currentContext.recentVelocities.size() > 16)
            currentContext.recentVelocities.erase(currentContext.recentVelocities.begin());
    }

    void recordChord(const std::vector<int>& notes)
    {
        std::lock_guard<std::mutex> lock(contextMutex);

        if (!notes.empty())
        {
            // Store root of chord
            currentContext.recentChords.push_back(notes[0]);
            if (currentContext.recentChords.size() > 8)
                currentContext.recentChords.erase(currentContext.recentChords.begin());
        }
    }

    //--------------------------------------------------------------------------
    // Synchronous Generation (blocks until complete)
    //--------------------------------------------------------------------------

    GeneratedMelody generateMelody(int length = 8)
    {
        std::lock_guard<std::mutex> lock(contextMutex);
        return generateMelodyInternal(currentContext, length);
    }

    GeneratedChordProgression generateChords(int count = 4)
    {
        std::lock_guard<std::mutex> lock(contextMutex);
        return generateChordsInternal(currentContext, count);
    }

    GeneratedRhythm generateRhythm(int beats = 4, const juce::String& style = "")
    {
        std::lock_guard<std::mutex> lock(contextMutex);
        return generateRhythmInternal(currentContext, beats, style);
    }

    ArrangementSuggestion suggestArrangement()
    {
        std::lock_guard<std::mutex> lock(contextMutex);
        return suggestArrangementInternal(currentContext);
    }

    //--------------------------------------------------------------------------
    // Asynchronous Generation (non-blocking)
    //--------------------------------------------------------------------------

    int64_t requestMelodyAsync(
        int length,
        std::function<void(const GeneratedMelody&)> callback,
        int priority = 0)
    {
        GenerationRequest req;
        req.type = GenerationRequest::Type::Melody;
        req.targetLength = length;
        req.melodyCallback = callback;
        req.priority = priority;

        return enqueueRequest(req);
    }

    int64_t requestChordsAsync(
        int count,
        std::function<void(const GeneratedChordProgression&)> callback,
        int priority = 0)
    {
        GenerationRequest req;
        req.type = GenerationRequest::Type::Chord;
        req.targetLength = count;
        req.chordCallback = callback;
        req.priority = priority;

        return enqueueRequest(req);
    }

    int64_t requestContinuation(
        std::function<void(const GeneratedMelody&)> callback)
    {
        GenerationRequest req;
        req.type = GenerationRequest::Type::Continuation;
        req.melodyCallback = callback;
        req.priority = 10;  // High priority - user is waiting

        return enqueueRequest(req);
    }

    void cancelRequest(int64_t requestId)
    {
        std::lock_guard<std::mutex> lock(queueMutex);
        // Mark for cancellation (actual removal in worker)
        cancelledRequests.insert(requestId);
    }

    //--------------------------------------------------------------------------
    // Learning & Feedback
    //--------------------------------------------------------------------------

    void acceptSuggestion(int64_t requestId)
    {
        std::lock_guard<std::mutex> lock(learningMutex);
        learningHistory.push_back({requestId, true, juce::Time::getCurrentTime()});
        updateModelWeights(requestId, 1.0f);
    }

    void rejectSuggestion(int64_t requestId)
    {
        std::lock_guard<std::mutex> lock(learningMutex);
        learningHistory.push_back({requestId, false, juce::Time::getCurrentTime()});
        updateModelWeights(requestId, -0.5f);
    }

    void provideFeedback(int64_t requestId, float rating)
    {
        std::lock_guard<std::mutex> lock(learningMutex);
        // rating: -1.0 to 1.0
        updateModelWeights(requestId, rating);
    }

    //--------------------------------------------------------------------------
    // Model Configuration
    //--------------------------------------------------------------------------

    void setTemperature(float temp)
    {
        modelConfig.temperature = juce::jlimit(0.0f, 2.0f, temp);
    }

    void setComplexity(float complexity)
    {
        std::lock_guard<std::mutex> lock(contextMutex);
        currentContext.complexity = juce::jlimit(0.0f, 1.0f, complexity);
    }

    void setGenre(const juce::String& genre)
    {
        std::lock_guard<std::mutex> lock(contextMutex);
        currentContext.genre = genre;
        applyGenrePresets(genre);
    }

    void setMood(const juce::String& mood)
    {
        std::lock_guard<std::mutex> lock(contextMutex);
        currentContext.mood = mood;
    }

    //--------------------------------------------------------------------------
    // Statistics
    //--------------------------------------------------------------------------

    struct Stats
    {
        int totalGenerations = 0;
        int acceptedGenerations = 0;
        int rejectedGenerations = 0;
        double averageLatencyMs = 0.0;
        double acceptanceRate = 0.0;
    };

    Stats getStats() const
    {
        std::lock_guard<std::mutex> lock(statsMutex);
        Stats s = stats;
        if (s.totalGenerations > 0)
        {
            s.acceptanceRate = static_cast<double>(s.acceptedGenerations) /
                              s.totalGenerations;
        }
        return s;
    }

private:
    AICompositionEngine() = default;
    ~AICompositionEngine() { shutdown(); }
    AICompositionEngine(const AICompositionEngine&) = delete;
    AICompositionEngine& operator=(const AICompositionEngine&) = delete;

    //--------------------------------------------------------------------------
    // Internal State
    //--------------------------------------------------------------------------

    std::atomic<bool> initialized{false};

    mutable std::mutex engineMutex;
    mutable std::mutex contextMutex;
    mutable std::mutex queueMutex;
    mutable std::mutex learningMutex;
    mutable std::mutex statsMutex;

    AIModelConfig modelConfig;
    CompositionContext currentContext;

    // Async processing
    std::thread workerThread;
    std::atomic<bool> workerRunning{false};
    std::condition_variable queueCondition;
    std::priority_queue<GenerationRequest,
                        std::vector<GenerationRequest>,
                        std::function<bool(const GenerationRequest&,
                                          const GenerationRequest&)>> requestQueue{
        [](const GenerationRequest& a, const GenerationRequest& b) {
            return a.priority < b.priority;  // Higher priority first
        }
    };
    std::set<int64_t> cancelledRequests;
    std::atomic<int64_t> nextRequestId{1};

    // Learning
    struct LearningEntry
    {
        int64_t requestId;
        bool accepted;
        juce::Time timestamp;
    };
    std::vector<LearningEntry> learningHistory;

    // Stats
    Stats stats;

    // RNG (thread-safe access)
    mutable std::mutex rngMutex;
    std::mt19937 rng{std::random_device{}()};

    template<typename Dist>
    auto threadSafeRandom(Dist& dist)
    {
        std::lock_guard<std::mutex> lock(rngMutex);
        return dist(rng);
    }

    //--------------------------------------------------------------------------
    // Initialization
    //--------------------------------------------------------------------------

    void initializeModels()
    {
        // In a real implementation, this would load neural network weights
        // For now, we use rule-based generation with learned parameters

        // Load saved learning data
        loadLearningData();
    }

    void loadLearningData()
    {
        // Would load from persistent storage
    }

    void saveLearningData()
    {
        // Would save to persistent storage
    }

    //--------------------------------------------------------------------------
    // Melody Generation
    //--------------------------------------------------------------------------

    GeneratedMelody generateMelodyInternal(const CompositionContext& ctx, int length)
    {
        GeneratedMelody melody;

        // Get scale notes
        auto scaleNotes = ctx.scaleNotes.empty()
            ? generateScaleNotes(ctx.rootNote + 60, Scales::IONIAN, 2)
            : ctx.scaleNotes;

        // Analyze recent notes for continuation
        int lastNote = ctx.recentNotes.empty() ? 60 + ctx.rootNote : ctx.recentNotes.back();
        float avgVelocity = 0.7f;
        if (!ctx.recentVelocities.empty())
        {
            for (float v : ctx.recentVelocities) avgVelocity += v;
            avgVelocity /= ctx.recentVelocities.size();
        }

        // Generate notes based on context
        float currentBeat = 0.0f;
        std::uniform_real_distribution<float> velocityDist(0.6f, 0.9f);
        std::uniform_int_distribution<int> intervalDist(-4, 4);
        std::uniform_real_distribution<float> durationDist(0.25f, 1.0f);

        for (int i = 0; i < length; ++i)
        {
            // Determine next note based on melodic contour
            int interval = threadSafeRandom(intervalDist);

            // Apply temperature (higher = more variation)
            interval = static_cast<int>(interval * modelConfig.temperature);

            int nextNote = lastNote + interval;

            // Quantize to scale
            nextNote = quantizeToScale(nextNote, scaleNotes);

            // Keep in reasonable range
            while (nextNote < 48) nextNote += 12;
            while (nextNote > 84) nextNote -= 12;

            // Determine rhythm
            float duration = threadSafeRandom(durationDist);

            // Adjust duration based on complexity
            if (ctx.complexity < 0.3f)
                duration = std::round(duration * 2.0f) / 2.0f;  // Quantize to half beats

            float velocity = threadSafeRandom(velocityDist);

            // Bio-reactive: lower velocity when stressed
            velocity *= (0.5f + ctx.coherence * 0.5f);

            melody.notes.push_back(nextNote);
            melody.durations.push_back(duration);
            melody.velocities.push_back(velocity);
            melody.startTimes.push_back(currentBeat);

            currentBeat += duration;
            lastNote = nextNote;
        }

        melody.confidence = calculateMelodyConfidence(melody, ctx);
        melody.description = generateMelodyDescription(melody, ctx);
        melody.reasoning = "Based on " + ctx.genre + " conventions in " +
                          (ctx.isMinor ? "minor" : "major") + " key";

        return melody;
    }

    float calculateMelodyConfidence(const GeneratedMelody& melody, const CompositionContext& ctx)
    {
        float confidence = 0.7f;

        // Higher confidence if matches genre conventions
        if (!ctx.genre.isEmpty())
            confidence += 0.1f;

        // Lower confidence for very long melodies
        if (melody.length() > 16)
            confidence -= 0.1f;

        // Higher confidence in flow state
        confidence += ctx.flowIntensity * 0.1f;

        return juce::jlimit(0.0f, 1.0f, confidence);
    }

    juce::String generateMelodyDescription(const GeneratedMelody& melody, const CompositionContext& ctx)
    {
        juce::String desc;

        // Analyze contour
        int ascending = 0, descending = 0;
        for (size_t i = 1; i < melody.notes.size(); ++i)
        {
            if (melody.notes[i] > melody.notes[i-1]) ascending++;
            else if (melody.notes[i] < melody.notes[i-1]) descending++;
        }

        if (ascending > descending)
            desc = "An ascending melodic phrase";
        else if (descending > ascending)
            desc = "A descending melodic phrase";
        else
            desc = "A balanced melodic phrase";

        desc += " with " + juce::String(melody.length()) + " notes";

        return desc;
    }

    //--------------------------------------------------------------------------
    // Chord Generation
    //--------------------------------------------------------------------------

    GeneratedChordProgression generateChordsInternal(const CompositionContext& ctx, int count)
    {
        GeneratedChordProgression progression;

        // Select progression based on genre
        std::vector<int> degrees;

        if (ctx.genre.containsIgnoreCase("jazz"))
        {
            degrees = {1, 4, 0, 5};  // ii-V-I-vi pattern
        }
        else if (ctx.genre.containsIgnoreCase("blues"))
        {
            degrees = {0, 0, 3, 3, 0, 0, 4, 4, 3, 3, 0, 4};  // 12-bar blues
        }
        else
        {
            // Pop progression
            std::vector<std::vector<int>> popProgressions = {
                {0, 4, 5, 3},   // I-V-vi-IV
                {0, 5, 3, 4},   // I-vi-IV-V
                {5, 3, 0, 4},   // vi-IV-I-V
                {0, 3, 4, 4}    // I-IV-V-V
            };

            std::uniform_int_distribution<int> progDist(0, static_cast<int>(popProgressions.size()) - 1);
            degrees = popProgressions[threadSafeRandom(progDist)];
        }

        // Generate chords
        int rootNote = ctx.rootNote + 60;

        for (int i = 0; i < count && i < static_cast<int>(degrees.size()); ++i)
        {
            GeneratedChordProgression::Chord chord;

            int degree = degrees[i % degrees.size()];
            auto notes = generateDiatonicChord(rootNote, degree, ctx.isMinor);

            chord.notes = notes;
            chord.duration = 1.0f;  // 1 bar each
            chord.inversion = 0;

            // Generate symbol
            std::vector<int> intervals;
            if (!notes.empty())
            {
                for (int note : notes)
                    intervals.push_back(note - notes[0]);
            }
            chord.symbol = generateChordSymbol(midiToNoteName(notes[0] % 12 + 60, true).substr(0, 2), intervals);

            progression.chords.push_back(chord);
        }

        progression.confidence = 0.8f;
        progression.description = "A " + juce::String(count) + "-chord progression";
        progression.function = "standard " + ctx.genre + " harmonic movement";

        return progression;
    }

    //--------------------------------------------------------------------------
    // Rhythm Generation
    //--------------------------------------------------------------------------

    GeneratedRhythm generateRhythmInternal(const CompositionContext& ctx, int beats, const juce::String& style)
    {
        GeneratedRhythm rhythm;
        rhythm.lengthBeats = beats;

        juce::String effectiveStyle = style.isEmpty() ? ctx.genre : style;

        // Generate based on style
        if (effectiveStyle.containsIgnoreCase("house") ||
            effectiveStyle.containsIgnoreCase("techno"))
        {
            // Four-on-the-floor
            for (int i = 0; i < beats; ++i)
            {
                rhythm.hits.push_back({static_cast<float>(i), 0.9f, 0.1f, "kick"});
                if (i % 2 == 1)
                    rhythm.hits.push_back({static_cast<float>(i), 0.8f, 0.1f, "snare"});
                rhythm.hits.push_back({i + 0.5f, 0.6f, 0.05f, "hihat"});
            }
            rhythm.style = "four-on-floor";
        }
        else if (effectiveStyle.containsIgnoreCase("hip") ||
                 effectiveStyle.containsIgnoreCase("trap"))
        {
            // Trap-style
            rhythm.hits.push_back({0.0f, 0.9f, 0.1f, "kick"});
            rhythm.hits.push_back({0.75f, 0.7f, 0.1f, "kick"});
            rhythm.hits.push_back({1.0f, 0.85f, 0.1f, "snare"});
            rhythm.hits.push_back({2.0f, 0.9f, 0.1f, "kick"});
            rhythm.hits.push_back({3.0f, 0.85f, 0.1f, "snare"});

            // Hi-hat rolls
            for (int i = 0; i < beats * 4; ++i)
            {
                rhythm.hits.push_back({i * 0.25f, 0.5f + (i % 2) * 0.1f, 0.02f, "hihat"});
            }
            rhythm.style = "trap";
        }
        else
        {
            // Basic rock/pop
            rhythm.hits.push_back({0.0f, 0.9f, 0.1f, "kick"});
            rhythm.hits.push_back({1.0f, 0.85f, 0.1f, "snare"});
            rhythm.hits.push_back({2.0f, 0.9f, 0.1f, "kick"});
            rhythm.hits.push_back({2.5f, 0.7f, 0.1f, "kick"});
            rhythm.hits.push_back({3.0f, 0.85f, 0.1f, "snare"});

            for (int i = 0; i < beats * 2; ++i)
            {
                rhythm.hits.push_back({i * 0.5f, 0.6f, 0.05f, "hihat"});
            }
            rhythm.style = "backbeat";
        }

        rhythm.swing = ctx.genre.containsIgnoreCase("jazz") ? 0.3f : 0.0f;
        rhythm.confidence = 0.75f;

        return rhythm;
    }

    //--------------------------------------------------------------------------
    // Arrangement Suggestions
    //--------------------------------------------------------------------------

    ArrangementSuggestion suggestArrangementInternal(const CompositionContext& ctx)
    {
        ArrangementSuggestion suggestion;

        // Analyze current position and energy
        float currentEnergy = ctx.energy;
        double beat = ctx.currentBeat;
        int bar = static_cast<int>(beat / 4);  // Assuming 4/4

        // Suggest based on song position
        if (bar < 8)
        {
            suggestion.suggestedSection = ArrangementSuggestion::SectionType::Intro;
            suggestion.energy = 0.3f;
            suggestion.reasoning = "Starting with a spacious intro";
        }
        else if (bar < 16)
        {
            suggestion.suggestedSection = ArrangementSuggestion::SectionType::Verse;
            suggestion.energy = 0.5f;
            suggestion.instrumentsToAdd.add("bass");
            suggestion.instrumentsToAdd.add("drums");
            suggestion.reasoning = "Building into the first verse";
        }
        else if (bar < 24)
        {
            suggestion.suggestedSection = ArrangementSuggestion::SectionType::Chorus;
            suggestion.energy = 0.8f;
            suggestion.instrumentsToAdd.add("synth_pad");
            suggestion.reasoning = "Time for a memorable chorus";
        }
        else if (currentEnergy > 0.7f)
        {
            suggestion.suggestedSection = ArrangementSuggestion::SectionType::Breakdown;
            suggestion.energy = 0.3f;
            suggestion.instrumentsToRemove.add("drums");
            suggestion.reasoning = "Creating contrast with a breakdown";
        }
        else
        {
            suggestion.suggestedSection = ArrangementSuggestion::SectionType::Drop;
            suggestion.energy = 1.0f;
            suggestion.instrumentsToAdd.add("sub_bass");
            suggestion.reasoning = "Maximum impact with the drop";
        }

        suggestion.lengthBars = 8;
        suggestion.confidence = 0.7f;

        return suggestion;
    }

    //--------------------------------------------------------------------------
    // Async Worker
    //--------------------------------------------------------------------------

    int64_t enqueueRequest(GenerationRequest req)
    {
        std::lock_guard<std::mutex> lock(queueMutex);

        req.requestId = nextRequestId++;
        req.requestTime = juce::Time::getCurrentTime();

        {
            std::lock_guard<std::mutex> ctxLock(contextMutex);
            req.context = currentContext;
        }
        req.config = modelConfig;

        requestQueue.push(req);
        queueCondition.notify_one();

        return req.requestId;
    }

    void workerLoop()
    {
        while (workerRunning)
        {
            GenerationRequest req;

            {
                std::unique_lock<std::mutex> lock(queueMutex);
                queueCondition.wait(lock, [this] {
                    return !workerRunning || !requestQueue.empty();
                });

                if (!workerRunning && requestQueue.empty())
                    break;

                if (requestQueue.empty())
                    continue;

                req = requestQueue.top();
                requestQueue.pop();

                // Check if cancelled
                if (cancelledRequests.count(req.requestId))
                {
                    cancelledRequests.erase(req.requestId);
                    continue;
                }
            }

            // Process request
            auto startTime = juce::Time::getMillisecondCounterHiRes();

            switch (req.type)
            {
                case GenerationRequest::Type::Melody:
                case GenerationRequest::Type::Continuation:
                case GenerationRequest::Type::Variation:
                case GenerationRequest::Type::CounterMelody:
                {
                    auto melody = generateMelodyInternal(
                        req.context, req.targetLength.value_or(8));
                    if (req.melodyCallback)
                        req.melodyCallback(melody);
                    break;
                }

                case GenerationRequest::Type::Chord:
                case GenerationRequest::Type::Harmonization:
                {
                    auto chords = generateChordsInternal(
                        req.context, req.targetLength.value_or(4));
                    if (req.chordCallback)
                        req.chordCallback(chords);
                    break;
                }

                case GenerationRequest::Type::Rhythm:
                {
                    auto rhythm = generateRhythmInternal(
                        req.context, req.targetLength.value_or(4), "");
                    if (req.rhythmCallback)
                        req.rhythmCallback(rhythm);
                    break;
                }

                case GenerationRequest::Type::Arrangement:
                {
                    auto arrangement = suggestArrangementInternal(req.context);
                    if (req.arrangementCallback)
                        req.arrangementCallback(arrangement);
                    break;
                }
            }

            auto endTime = juce::Time::getMillisecondCounterHiRes();

            // Update stats
            {
                std::lock_guard<std::mutex> sLock(statsMutex);
                stats.totalGenerations++;
                double latency = endTime - startTime;
                stats.averageLatencyMs = (stats.averageLatencyMs * (stats.totalGenerations - 1) +
                                          latency) / stats.totalGenerations;
            }
        }
    }

    //--------------------------------------------------------------------------
    // Learning
    //--------------------------------------------------------------------------

    void updateModelWeights(int64_t requestId, float feedback)
    {
        // In a real implementation, this would update neural network weights
        // using techniques like RLHF (Reinforcement Learning from Human Feedback)

        // Update stats
        std::lock_guard<std::mutex> sLock(statsMutex);
        if (feedback > 0)
            stats.acceptedGenerations++;
        else
            stats.rejectedGenerations++;
    }

    void applyGenrePresets(const juce::String& genre)
    {
        // Adjust generation parameters for genre
        if (genre.containsIgnoreCase("jazz"))
        {
            modelConfig.temperature = 0.9f;  // More variation
        }
        else if (genre.containsIgnoreCase("classical"))
        {
            modelConfig.temperature = 0.5f;  // More structured
        }
        else if (genre.containsIgnoreCase("electronic"))
        {
            modelConfig.temperature = 0.7f;
        }
    }
};

} // namespace AI
} // namespace Echoelmusic
