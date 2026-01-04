#pragma once

//==============================================================================
/**
    RalphWiggumAIBridge.h

    The intelligent bridge connecting Ralph Wiggum Loop Genius with:
    - Progressive Disclosure Engine (complexity adaptation)
    - Wise Save Mode (session context & learning persistence)
    - Wearable Integration (bio-state awareness)
    - Global Key/Scale Manager (musical context)

    Design: Level-appropriate creative suggestions that learn from user behavior.

    Inspired by: LFM2-2.6B-Exp on-device efficiency, progressive disclosure principles

    Copyright (c) 2024-2025 Echoelmusic
*/
//==============================================================================

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <functional>
#include <random>
#include <cmath>

namespace Echoel
{

//==============================================================================
// FORWARD DECLARATIONS (from other core systems)
//==============================================================================

// From ProgressiveDisclosureEngine.h
enum class DisclosureLevel;
struct UserState;

// From GlobalKeyScaleManager (RalphWiggumFoundation.h)
enum class ScaleType;

//==============================================================================
// SUGGESTION TYPES
//==============================================================================

enum class SuggestionType
{
    Chord,              // Chord suggestion
    ChordProgression,   // Multi-chord sequence
    Melody,             // Melodic phrase
    Rhythm,             // Rhythmic pattern
    Modulation,         // Key change suggestion
    Texture,            // Arrangement/texture idea
    Effect,             // Effect parameter suggestion
    Tempo,              // Tempo adjustment
    Break               // Take a break (wellness)
};

enum class SuggestionComplexity
{
    Simple,             // "Try F major"
    Moderate,           // "F major adds brightness"
    Detailed,           // "IV chord (F) creates plagal motion"
    Theoretical,        // "Subdominant with added 9th for color"
    Expert              // Full harmonic analysis with alternatives
};

//==============================================================================
// MUSICAL SUGGESTION
//==============================================================================

struct MusicalSuggestion
{
    std::string id;
    SuggestionType type {SuggestionType::Chord};
    SuggestionComplexity complexity {SuggestionComplexity::Simple};

    // Content
    std::string displayText;        // User-facing text
    std::string theoreticalNote;    // Music theory explanation
    std::string reason;             // Why this suggestion now

    // Musical data
    std::vector<int> notes;         // MIDI notes
    std::vector<int> chordRoots;    // For progressions
    std::vector<float> rhythm;      // Rhythm pattern (0-1 per step)
    double suggestedTempo {0.0};    // For tempo suggestions

    // Metadata
    float confidence {0.0f};        // AI confidence (0-1)
    float bioAlignment {0.0f};      // How well it matches bio-state
    bool isWellnessSuggestion {false};

    // Learning
    int timesShown {0};
    int timesAccepted {0};
    float acceptanceRate() const {
        return timesShown > 0 ? static_cast<float>(timesAccepted) / timesShown : 0.0f;
    }
};

//==============================================================================
// MUSICAL CONTEXT
//==============================================================================

struct MusicalContext
{
    // Key/Scale
    int key {0};                    // 0-11 (C=0)
    ScaleType scale;
    std::vector<int> scaleNotes;

    // Tempo & Time
    double tempo {120.0};
    int timeSignatureNum {4};
    int timeSignatureDen {4};

    // Current position
    int currentBar {0};
    double currentBeat {0.0};

    // Recent activity
    std::vector<int> recentNotes;   // Last N notes played
    std::vector<int> recentChords;  // Last N chord roots
    int recentActionCount {0};

    // Session
    double sessionDuration {0.0};
    std::string sessionId;
};

//==============================================================================
// BIO CONTEXT
//==============================================================================

struct BioContext
{
    float heartRate {70.0f};
    float hrv {50.0f};
    float coherence {0.5f};
    float stressLevel {0.3f};
    float flowIntensity {0.0f};
    float energy {0.5f};

    bool isCalm() const { return coherence > 0.7f && stressLevel < 0.3f; }
    bool isEnergized() const { return heartRate > 80 && energy > 0.6f; }
    bool isInFlow() const { return flowIntensity > 0.5f && coherence > 0.6f; }
    bool needsBreak() const { return stressLevel > 0.7f || hrv < 25.0f; }

    // Map bio-state to musical energy (0-1)
    float musicalEnergy() const {
        return (coherence * 0.3f) + (energy * 0.4f) +
               (std::min(1.0f, heartRate / 100.0f) * 0.3f);
    }
};

//==============================================================================
// LEARNING RECORD
//==============================================================================

struct LearningRecord
{
    std::string suggestionPattern;  // Pattern identifier
    int showCount {0};
    int acceptCount {0};
    int rejectCount {0};

    // Context when accepted
    std::vector<float> acceptedCoherenceLevels;
    std::vector<float> acceptedFlowLevels;
    std::vector<int> acceptedInKeys;

    float preferenceScore() const {
        if (showCount == 0) return 0.5f;
        return static_cast<float>(acceptCount) / showCount;
    }

    float averageAcceptedCoherence() const {
        if (acceptedCoherenceLevels.empty()) return 0.5f;
        float sum = 0;
        for (auto c : acceptedCoherenceLevels) sum += c;
        return sum / acceptedCoherenceLevels.size();
    }
};

//==============================================================================
// RALPH WIGGUM AI BRIDGE - Main Class
//==============================================================================

class RalphWiggumAIBridge
{
public:
    //--------------------------------------------------------------------------
    // Singleton
    //--------------------------------------------------------------------------

    static RalphWiggumAIBridge& shared()
    {
        static RalphWiggumAIBridge instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    // Context Updates
    //--------------------------------------------------------------------------

    void updateMusicalContext(const MusicalContext& ctx)
    {
        musicalContext = ctx;
        invalidateSuggestionCache();
    }

    void updateBioContext(const BioContext& ctx)
    {
        bioContext = ctx;
        checkWellnessState();
        invalidateSuggestionCache();
    }

    void updateDisclosureLevel(DisclosureLevel level)
    {
        currentLevel = level;
        targetComplexity = mapLevelToComplexity(level);
        invalidateSuggestionCache();
    }

    void setKey(int root, ScaleType scaleType)
    {
        musicalContext.key = root;
        musicalContext.scale = scaleType;
        musicalContext.scaleNotes = generateScaleNotes(root, scaleType);
        invalidateSuggestionCache();
    }

    void setTempo(double bpm)
    {
        musicalContext.tempo = bpm;
    }

    void recordNote(int midiNote)
    {
        musicalContext.recentNotes.push_back(midiNote);
        if (musicalContext.recentNotes.size() > 16)
            musicalContext.recentNotes.erase(musicalContext.recentNotes.begin());
        musicalContext.recentActionCount++;
    }

    void recordChord(int rootNote)
    {
        musicalContext.recentChords.push_back(rootNote);
        if (musicalContext.recentChords.size() > 8)
            musicalContext.recentChords.erase(musicalContext.recentChords.begin());
    }

    //--------------------------------------------------------------------------
    // Suggestion Generation
    //--------------------------------------------------------------------------

    MusicalSuggestion getNextSuggestion()
    {
        // Wellness check first
        if (bioContext.needsBreak())
            return generateWellnessSuggestion();

        // Generate based on context
        if (cachedSuggestions.empty())
            generateSuggestions();

        if (cachedSuggestions.empty())
            return generateFallbackSuggestion();

        // Pick best suggestion
        auto suggestion = selectBestSuggestion();
        suggestion.timesShown++;

        // Update learning
        updateShowCount(suggestion);

        return suggestion;
    }

    std::vector<MusicalSuggestion> getSuggestions(int count = 3)
    {
        if (cachedSuggestions.empty())
            generateSuggestions();

        std::vector<MusicalSuggestion> result;
        int n = std::min(count, static_cast<int>(cachedSuggestions.size()));

        for (int i = 0; i < n; i++)
        {
            auto& s = cachedSuggestions[i];
            s.timesShown++;
            updateShowCount(s);
            result.push_back(s);
        }

        return result;
    }

    MusicalSuggestion getChordSuggestion()
    {
        return generateChordSuggestion();
    }

    MusicalSuggestion getMelodySuggestion(int length = 4)
    {
        return generateMelodySuggestion(length);
    }

    MusicalSuggestion getRhythmSuggestion(int steps = 16)
    {
        return generateRhythmSuggestion(steps);
    }

    MusicalSuggestion getProgressionSuggestion(int chords = 4)
    {
        return generateProgressionSuggestion(chords);
    }

    //--------------------------------------------------------------------------
    // Learning Feedback
    //--------------------------------------------------------------------------

    void acceptSuggestion(const std::string& suggestionId)
    {
        auto& record = learningRecords[suggestionId];
        record.acceptCount++;
        record.acceptedCoherenceLevels.push_back(bioContext.coherence);
        record.acceptedFlowLevels.push_back(bioContext.flowIntensity);
        record.acceptedInKeys.push_back(musicalContext.key);

        // Boost confidence for similar suggestions
        for (auto& s : cachedSuggestions)
        {
            if (s.id == suggestionId)
            {
                s.timesAccepted++;
                break;
            }
        }

        saveLearning();
    }

    void rejectSuggestion(const std::string& suggestionId)
    {
        auto& record = learningRecords[suggestionId];
        record.rejectCount++;

        // Slightly reduce confidence for similar patterns
        saveLearning();
    }

    void dismissSuggestion(const std::string& suggestionId)
    {
        // Neutral - user saw it but didn't act
        // Don't penalize, but note the context
    }

    //--------------------------------------------------------------------------
    // Complexity Adaptation
    //--------------------------------------------------------------------------

    SuggestionComplexity getTargetComplexity() const { return targetComplexity; }

    void setManualComplexity(SuggestionComplexity complexity)
    {
        manualComplexityOverride = true;
        targetComplexity = complexity;
        invalidateSuggestionCache();
    }

    void clearManualComplexity()
    {
        manualComplexityOverride = false;
        targetComplexity = mapLevelToComplexity(currentLevel);
        invalidateSuggestionCache();
    }

    //--------------------------------------------------------------------------
    // Serialization (Learning Persistence)
    //--------------------------------------------------------------------------

    juce::String serializeLearning() const
    {
        juce::DynamicObject::Ptr root = new juce::DynamicObject();

        juce::Array<juce::var> records;
        for (const auto& [pattern, record] : learningRecords)
        {
            juce::DynamicObject::Ptr r = new juce::DynamicObject();
            r->setProperty("pattern", juce::String(pattern));
            r->setProperty("showCount", record.showCount);
            r->setProperty("acceptCount", record.acceptCount);
            r->setProperty("rejectCount", record.rejectCount);
            records.add(r.get());
        }
        root->setProperty("learningRecords", records);

        return juce::JSON::toString(root.get());
    }

    void deserializeLearning(const juce::String& json)
    {
        auto parsed = juce::JSON::parse(json);
        if (auto* root = parsed.getDynamicObject())
        {
            if (auto* arr = root->getProperty("learningRecords").getArray())
            {
                for (const auto& v : *arr)
                {
                    if (auto* r = v.getDynamicObject())
                    {
                        std::string pattern = r->getProperty("pattern").toString().toStdString();
                        LearningRecord record;
                        record.showCount = r->getProperty("showCount");
                        record.acceptCount = r->getProperty("acceptCount");
                        record.rejectCount = r->getProperty("rejectCount");
                        learningRecords[pattern] = record;
                    }
                }
            }
        }
    }

    //--------------------------------------------------------------------------
    // Callbacks
    //--------------------------------------------------------------------------

    std::function<void(const MusicalSuggestion&)> onSuggestionReady;
    std::function<void()> onWellnessBreakNeeded;
    std::function<void(const std::string&)> onLearningUpdated;

    //--------------------------------------------------------------------------
    // Reset
    //--------------------------------------------------------------------------

    void reset()
    {
        musicalContext = MusicalContext();
        bioContext = BioContext();
        cachedSuggestions.clear();
        // Keep learning records
    }

    void resetLearning()
    {
        learningRecords.clear();
    }

private:
    RalphWiggumAIBridge() { initializePatterns(); }
    ~RalphWiggumAIBridge() = default;
    RalphWiggumAIBridge(const RalphWiggumAIBridge&) = delete;
    RalphWiggumAIBridge& operator=(const RalphWiggumAIBridge&) = delete;

    //--------------------------------------------------------------------------
    // State
    //--------------------------------------------------------------------------

    MusicalContext musicalContext;
    BioContext bioContext;
    DisclosureLevel currentLevel;
    SuggestionComplexity targetComplexity {SuggestionComplexity::Simple};
    bool manualComplexityOverride {false};

    std::vector<MusicalSuggestion> cachedSuggestions;
    std::map<std::string, LearningRecord> learningRecords;

    std::mt19937 rng {std::random_device{}()};

    //--------------------------------------------------------------------------
    // Chord/Scale Data
    //--------------------------------------------------------------------------

    // Roman numeral chord functions
    struct ChordFunction {
        std::string roman;
        std::string name;
        int intervalFromRoot;
        bool isMinor;
        std::string simpleDesc;
        std::string theoryDesc;
    };

    std::vector<ChordFunction> majorKeyChords;
    std::vector<ChordFunction> minorKeyChords;

    void initializePatterns()
    {
        // Major key diatonic chords
        majorKeyChords = {
            {"I",   "Tonic",        0,  false, "Home chord",      "Tonic - point of rest and resolution"},
            {"ii",  "Supertonic",   2,  true,  "Leads to V",      "Supertonic minor - predominant function"},
            {"iii", "Mediant",      4,  true,  "Soft tension",    "Mediant minor - tonic substitute"},
            {"IV",  "Subdominant",  5,  false, "Bright lift",     "Subdominant - plagal/predominant"},
            {"V",   "Dominant",     7,  false, "Wants to resolve","Dominant - strongest pull to tonic"},
            {"vi",  "Submediant",   9,  true,  "Emotional depth", "Relative minor - tonic substitute"},
            {"vii°","Leading tone", 11, true,  "Rare, tense",     "Diminished - dominant function"}
        };

        // Minor key diatonic chords
        minorKeyChords = {
            {"i",   "Tonic",        0,  true,  "Minor home",      "Minor tonic - dark resolution"},
            {"ii°", "Supertonic",   2,  true,  "Diminished",      "Diminished supertonic"},
            {"III", "Mediant",      3,  false, "Relative major",  "Major mediant - bright contrast"},
            {"iv",  "Subdominant",  5,  true,  "Minor plagal",    "Minor subdominant"},
            {"v/V", "Dominant",     7,  false, "Natural/Harmonic","Dominant (raised 7th for V)"},
            {"VI",  "Submediant",   8,  false, "Deceptive",       "Major submediant - deceptive resolution"},
            {"VII", "Subtonic",     10, false, "Modal",           "Major subtonic - modal borrowing"}
        };
    }

    //--------------------------------------------------------------------------
    // Scale Generation
    //--------------------------------------------------------------------------

    std::vector<int> generateScaleNotes(int root, ScaleType scale)
    {
        std::vector<int> intervals;

        switch (scale)
        {
            case ScaleType::major:
                intervals = {0, 2, 4, 5, 7, 9, 11};
                break;
            case ScaleType::minor:
                intervals = {0, 2, 3, 5, 7, 8, 10};
                break;
            case ScaleType::harmonicMinor:
                intervals = {0, 2, 3, 5, 7, 8, 11};
                break;
            case ScaleType::melodicMinor:
                intervals = {0, 2, 3, 5, 7, 9, 11};
                break;
            case ScaleType::dorian:
                intervals = {0, 2, 3, 5, 7, 9, 10};
                break;
            case ScaleType::mixolydian:
                intervals = {0, 2, 4, 5, 7, 9, 10};
                break;
            case ScaleType::pentatonicMajor:
                intervals = {0, 2, 4, 7, 9};
                break;
            case ScaleType::pentatonicMinor:
                intervals = {0, 3, 5, 7, 10};
                break;
            case ScaleType::blues:
                intervals = {0, 3, 5, 6, 7, 10};
                break;
            default:
                intervals = {0, 2, 4, 5, 7, 9, 11};  // Default major
        }

        std::vector<int> notes;
        for (int interval : intervals)
            notes.push_back((root + interval) % 12);

        return notes;
    }

    //--------------------------------------------------------------------------
    // Suggestion Generation
    //--------------------------------------------------------------------------

    void generateSuggestions()
    {
        cachedSuggestions.clear();

        // Generate variety of suggestions
        cachedSuggestions.push_back(generateChordSuggestion());
        cachedSuggestions.push_back(generateProgressionSuggestion(4));
        cachedSuggestions.push_back(generateMelodySuggestion(4));

        if (bioContext.isEnergized())
            cachedSuggestions.push_back(generateRhythmSuggestion(16));

        if (bioContext.isCalm())
            cachedSuggestions.push_back(generateTextureSuggestion());

        // Sort by bio-alignment and learned preference
        std::sort(cachedSuggestions.begin(), cachedSuggestions.end(),
            [this](const auto& a, const auto& b) {
                float scoreA = a.bioAlignment * 0.4f + getLearnedPreference(a.id) * 0.6f;
                float scoreB = b.bioAlignment * 0.4f + getLearnedPreference(b.id) * 0.6f;
                return scoreA > scoreB;
            });
    }

    MusicalSuggestion generateChordSuggestion()
    {
        MusicalSuggestion s;
        s.id = "chord_" + std::to_string(rng());
        s.type = SuggestionType::Chord;
        s.complexity = targetComplexity;

        // Pick a chord function based on recent context
        const auto& chords = (musicalContext.scale == ScaleType::minor ||
                              musicalContext.scale == ScaleType::harmonicMinor)
                             ? minorKeyChords : majorKeyChords;

        // Weight towards common progressions
        std::vector<int> weights = {20, 15, 10, 25, 30, 20, 5};  // I, ii, iii, IV, V, vi, vii
        std::discrete_distribution<> dist(weights.begin(), weights.end());
        int idx = dist(rng);

        const auto& chord = chords[idx];
        int chordRoot = (musicalContext.key + chord.intervalFromRoot) % 12;

        // Build chord notes
        s.notes = {chordRoot, (chordRoot + (chord.isMinor ? 3 : 4)) % 12,
                   (chordRoot + 7) % 12};

        // Generate text based on complexity
        s.displayText = generateChordText(chord, chordRoot);
        s.theoreticalNote = chord.theoryDesc;
        s.reason = generateChordReason(chord);

        s.confidence = 0.7f + (getLearnedPreference(s.id) * 0.3f);
        s.bioAlignment = calculateBioAlignment(s);

        return s;
    }

    MusicalSuggestion generateProgressionSuggestion(int numChords)
    {
        MusicalSuggestion s;
        s.id = "prog_" + std::to_string(rng());
        s.type = SuggestionType::ChordProgression;
        s.complexity = targetComplexity;

        // Common progressions
        std::vector<std::vector<int>> progressions = {
            {0, 5, 9, 7},     // I - IV - vi - V
            {0, 9, 5, 7},     // I - vi - IV - V
            {9, 5, 0, 7},     // vi - IV - I - V
            {0, 7, 9, 5},     // I - V - vi - IV
            {0, 5, 7, 0},     // I - IV - V - I
            {2, 7, 0, 0}      // ii - V - I - I
        };

        std::uniform_int_distribution<> dist(0, progressions.size() - 1);
        auto prog = progressions[dist(rng)];

        for (int interval : prog)
        {
            int chordRoot = (musicalContext.key + interval) % 12;
            s.chordRoots.push_back(chordRoot);
        }

        s.displayText = generateProgressionText(prog);
        s.reason = "Classic progression that works with your current flow";
        s.confidence = 0.75f;
        s.bioAlignment = calculateBioAlignment(s);

        return s;
    }

    MusicalSuggestion generateMelodySuggestion(int length)
    {
        MusicalSuggestion s;
        s.id = "melody_" + std::to_string(rng());
        s.type = SuggestionType::Melody;
        s.complexity = targetComplexity;

        // Generate melody from scale
        const auto& scale = musicalContext.scaleNotes;
        if (scale.empty())
        {
            s.displayText = "Set a key first";
            return s;
        }

        std::uniform_int_distribution<> noteDist(0, scale.size() - 1);
        std::uniform_int_distribution<> octaveDist(4, 5);

        for (int i = 0; i < length; i++)
        {
            int note = scale[noteDist(rng)] + (octaveDist(rng) * 12);
            s.notes.push_back(note);
        }

        s.displayText = generateMelodyText(s.notes);
        s.reason = bioContext.isCalm() ? "Flowing phrase for your calm state" :
                                          "Energetic motif to match your energy";
        s.confidence = 0.65f;
        s.bioAlignment = calculateBioAlignment(s);

        return s;
    }

    MusicalSuggestion generateRhythmSuggestion(int steps)
    {
        MusicalSuggestion s;
        s.id = "rhythm_" + std::to_string(rng());
        s.type = SuggestionType::Rhythm;
        s.complexity = targetComplexity;

        // Generate rhythm pattern based on energy
        float density = bioContext.musicalEnergy();

        for (int i = 0; i < steps; i++)
        {
            float threshold = (i % 4 == 0) ? 0.3f :     // Downbeats more likely
                              (i % 2 == 0) ? 0.5f :     // Even beats
                                             0.7f;      // Offbeats

            std::uniform_real_distribution<> dist(0.0, 1.0);
            float value = (dist(rng) < (density * (1.0f - threshold))) ? 1.0f : 0.0f;
            s.rhythm.push_back(value);
        }

        s.displayText = generateRhythmText(s.rhythm);
        s.reason = "Rhythm matching your energy level";
        s.confidence = 0.7f;
        s.bioAlignment = calculateBioAlignment(s);

        return s;
    }

    MusicalSuggestion generateTextureSuggestion()
    {
        MusicalSuggestion s;
        s.id = "texture_" + std::to_string(rng());
        s.type = SuggestionType::Texture;
        s.complexity = targetComplexity;

        std::vector<std::string> textures = {
            "Try adding sustained pad underneath",
            "Layer a soft arpeggio",
            "Add subtle reverb wash",
            "Introduce ambient texture",
            "Consider octave doubling"
        };

        std::uniform_int_distribution<> dist(0, textures.size() - 1);
        s.displayText = textures[dist(rng)];
        s.reason = "Your calm state suggests space for texture";
        s.confidence = 0.6f;
        s.bioAlignment = 0.8f;  // Good for calm states

        return s;
    }

    MusicalSuggestion generateWellnessSuggestion()
    {
        MusicalSuggestion s;
        s.id = "wellness_" + std::to_string(rng());
        s.type = SuggestionType::Break;
        s.complexity = SuggestionComplexity::Simple;
        s.isWellnessSuggestion = true;

        s.displayText = "Take a short break - your stress level is elevated";
        s.theoreticalNote = "Rest is part of the creative process";
        s.reason = "HRV indicates you need recovery time";
        s.confidence = 0.95f;
        s.bioAlignment = 1.0f;

        if (onWellnessBreakNeeded)
            onWellnessBreakNeeded();

        return s;
    }

    MusicalSuggestion generateFallbackSuggestion()
    {
        MusicalSuggestion s;
        s.id = "fallback";
        s.type = SuggestionType::Chord;
        s.displayText = "Explore the current key";
        s.reason = "Keep experimenting";
        s.confidence = 0.5f;
        return s;
    }

    //--------------------------------------------------------------------------
    // Text Generation (Complexity-Adapted)
    //--------------------------------------------------------------------------

    std::string generateChordText(const ChordFunction& chord, int root)
    {
        std::string noteName = noteToName(root);

        switch (targetComplexity)
        {
            case SuggestionComplexity::Simple:
                return "Try " + noteName + (chord.isMinor ? "m" : "");

            case SuggestionComplexity::Moderate:
                return noteName + (chord.isMinor ? " minor" : " major") +
                       " - " + chord.simpleDesc;

            case SuggestionComplexity::Detailed:
                return chord.roman + " (" + noteName + (chord.isMinor ? "m" : "") +
                       ") - " + chord.name;

            case SuggestionComplexity::Theoretical:
                return chord.roman + " chord (" + noteName + ") - " +
                       chord.theoryDesc;

            case SuggestionComplexity::Expert:
                return chord.roman + " [" + noteName + (chord.isMinor ? "m" : "") +
                       "] " + chord.theoryDesc +
                       ". Consider extensions: add9, sus4";
        }
        return noteName;
    }

    std::string generateChordReason(const ChordFunction& chord)
    {
        if (bioContext.isInFlow())
            return "You're in flow - good time for " + chord.simpleDesc;
        if (bioContext.isCalm())
            return "Your calm state suits this harmonic choice";
        if (bioContext.isEnergized())
            return "Match your energy with this chord";
        return "Natural next step in the progression";
    }

    std::string generateProgressionText(const std::vector<int>& intervals)
    {
        std::string result;

        const auto& chords = (musicalContext.scale == ScaleType::minor)
                             ? minorKeyChords : majorKeyChords;

        for (size_t i = 0; i < intervals.size(); i++)
        {
            int interval = intervals[i];
            int root = (musicalContext.key + interval) % 12;

            // Find matching chord function
            for (const auto& cf : chords)
            {
                if (cf.intervalFromRoot == interval)
                {
                    if (targetComplexity >= SuggestionComplexity::Detailed)
                        result += cf.roman;
                    else
                        result += noteToName(root);

                    if (i < intervals.size() - 1)
                        result += " → ";
                    break;
                }
            }
        }

        return result;
    }

    std::string generateMelodyText(const std::vector<int>& notes)
    {
        if (targetComplexity <= SuggestionComplexity::Simple)
            return std::to_string(notes.size()) + "-note melodic idea";

        std::string result = "Melody: ";
        for (size_t i = 0; i < std::min(notes.size(), size_t(4)); i++)
        {
            result += noteToName(notes[i] % 12);
            if (i < 3) result += " ";
        }
        if (notes.size() > 4) result += "...";

        return result;
    }

    std::string generateRhythmText(const std::vector<float>& rhythm)
    {
        if (targetComplexity <= SuggestionComplexity::Simple)
            return "Rhythmic pattern suggestion";

        std::string result = "";
        for (size_t i = 0; i < std::min(rhythm.size(), size_t(8)); i++)
        {
            result += (rhythm[i] > 0.5f) ? "●" : "○";
        }
        if (rhythm.size() > 8) result += "...";

        return result;
    }

    //--------------------------------------------------------------------------
    // Helpers
    //--------------------------------------------------------------------------

    std::string noteToName(int note)
    {
        static const char* names[] = {"C", "C#", "D", "D#", "E", "F",
                                       "F#", "G", "G#", "A", "A#", "B"};
        return names[note % 12];
    }

    SuggestionComplexity mapLevelToComplexity(DisclosureLevel level)
    {
        switch (static_cast<int>(level))
        {
            case 0: return SuggestionComplexity::Simple;      // Minimal
            case 1: return SuggestionComplexity::Simple;      // Basic
            case 2: return SuggestionComplexity::Moderate;    // Intermediate
            case 3: return SuggestionComplexity::Detailed;    // Advanced
            case 4: return SuggestionComplexity::Expert;      // Expert
            default: return SuggestionComplexity::Simple;
        }
    }

    float calculateBioAlignment(const MusicalSuggestion& s)
    {
        float alignment = 0.5f;

        // Calm state prefers soft suggestions
        if (bioContext.isCalm())
        {
            if (s.type == SuggestionType::Texture) alignment += 0.3f;
            if (s.type == SuggestionType::Melody) alignment += 0.2f;
        }

        // Energized state prefers rhythm
        if (bioContext.isEnergized())
        {
            if (s.type == SuggestionType::Rhythm) alignment += 0.3f;
            if (s.type == SuggestionType::ChordProgression) alignment += 0.2f;
        }

        // Flow state is receptive to anything
        if (bioContext.isInFlow())
            alignment += 0.2f;

        return std::min(1.0f, alignment);
    }

    MusicalSuggestion selectBestSuggestion()
    {
        if (cachedSuggestions.empty())
            return generateFallbackSuggestion();

        // Already sorted by score
        return cachedSuggestions.front();
    }

    float getLearnedPreference(const std::string& pattern)
    {
        auto it = learningRecords.find(pattern);
        if (it == learningRecords.end())
            return 0.5f;  // Neutral
        return it->second.preferenceScore();
    }

    void updateShowCount(const MusicalSuggestion& s)
    {
        learningRecords[s.id].showCount++;
    }

    void saveLearning()
    {
        if (onLearningUpdated)
            onLearningUpdated(serializeLearning().toStdString());
    }

    void invalidateSuggestionCache()
    {
        cachedSuggestions.clear();
    }

    void checkWellnessState()
    {
        if (bioContext.needsBreak() && onWellnessBreakNeeded)
            onWellnessBreakNeeded();
    }
};

//==============================================================================
// CONVENIENCE MACRO
//==============================================================================

#define RalphAI RalphWiggumAIBridge::shared()

} // namespace Echoel
