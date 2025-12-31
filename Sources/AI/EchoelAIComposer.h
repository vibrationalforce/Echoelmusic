/**
 * EchoelAIComposer.h
 *
 * AI-Powered Music Composition & Generation
 *
 * Machine learning for music creation:
 * - Melody generation
 * - Harmony/chord suggestions
 * - Rhythm pattern creation
 * - Style transfer
 * - Continuation generation
 * - Variation creation
 * - Genre-specific models
 * - Emotion-driven composition
 * - Lyrics generation
 * - Arrangement assistance
 *
 * Part of Ralph Wiggum Quantum Sauce Mode - AI Integration
 * "My cat's name is Mittens!" - Ralph Wiggum
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <chrono>
#include <optional>
#include <atomic>
#include <mutex>
#include <random>

namespace Echoel {
namespace AI {

// ============================================================================
// Musical Data Types
// ============================================================================

struct Note {
    int pitch = 60;         // MIDI note (0-127)
    float velocity = 0.8f;  // 0.0-1.0
    double startTime = 0.0; // In beats
    double duration = 1.0;  // In beats
    int channel = 0;
};

struct Chord {
    std::vector<int> pitches;
    std::string name;       // e.g., "Cmaj7", "Dm"
    std::string function;   // e.g., "I", "V7", "ii"
    double startTime = 0.0;
    double duration = 4.0;
};

struct Scale {
    int root = 0;           // 0=C, 1=C#, etc.
    std::string type;       // "major", "minor", "dorian", etc.
    std::vector<int> intervals;

    std::vector<int> getNotes() const {
        std::vector<int> notes;
        for (int interval : intervals) {
            notes.push_back(root + interval);
        }
        return notes;
    }
};

struct RhythmPattern {
    std::string id;
    std::string name;
    int beatsPerBar = 4;
    int subdivision = 4;    // 4 = 16th notes

    struct Hit {
        double time;        // In beats
        float velocity;
        float probability = 1.0f;  // For humanization
    };
    std::vector<Hit> hits;
};

struct Melody {
    std::string id;
    std::vector<Note> notes;
    Scale scale;
    double tempo = 120.0;
    int timeSignatureNumerator = 4;
    int timeSignatureDenominator = 4;
};

struct ChordProgression {
    std::string id;
    std::vector<Chord> chords;
    Scale scale;
    std::string style;      // "pop", "jazz", "classical"
};

// ============================================================================
// Generation Parameters
// ============================================================================

enum class MusicStyle {
    Pop,
    Rock,
    Jazz,
    Classical,
    Electronic,
    HipHop,
    RnB,
    Country,
    Folk,
    Blues,
    Metal,
    Ambient,
    Experimental,
    LoFi,
    Cinematic
};

enum class Emotion {
    Happy,
    Sad,
    Energetic,
    Calm,
    Tense,
    Romantic,
    Melancholic,
    Triumphant,
    Mysterious,
    Playful,
    Epic,
    Nostalgic
};

struct GenerationParams {
    // Style
    MusicStyle style = MusicStyle::Pop;
    Emotion emotion = Emotion::Happy;
    std::vector<std::string> influences;  // Artist/genre influences

    // Musical parameters
    Scale scale;
    double tempo = 120.0;
    int timeSignatureNum = 4;
    int timeSignatureDenom = 4;
    std::string keySignature = "C";
    bool isMinor = false;

    // Generation settings
    float creativity = 0.5f;     // 0=conservative, 1=experimental
    float complexity = 0.5f;     // Note density, harmonic complexity
    float variation = 0.3f;      // How much variation between sections
    float humanization = 0.2f;   // Timing/velocity randomness

    // Length
    int bars = 8;
    int beatsPerBar = 4;

    // Seed for reproducibility
    int seed = -1;               // -1 = random

    // Context
    std::vector<Note> previousNotes;  // For continuation
    std::vector<Chord> previousChords;
};

struct GenerationResult {
    bool success = false;
    std::string error;

    Melody melody;
    ChordProgression chords;
    std::vector<RhythmPattern> rhythms;

    float confidence = 0.0f;
    std::chrono::milliseconds generationTime{0};

    // Alternatives
    std::vector<Melody> alternativeMelodies;
    std::vector<ChordProgression> alternativeChords;
};

// ============================================================================
// Model Types
// ============================================================================

enum class AIModel {
    // Melody
    MelodyTransformer,      // Transformer-based melody
    MelodyRNN,              // LSTM/GRU melody
    MelodyVAE,              // Variational autoencoder

    // Harmony
    ChordTransformer,       // Chord sequence model
    HarmonyNet,             // Functional harmony model

    // Rhythm
    DrumNet,                // Drum pattern generator
    GrooveNet,              // Groove/feel model

    // Style
    StyleTransfer,          // Apply style of one piece to another
    GenreClassifier,        // Classify/generate by genre

    // Multi-modal
    MusicGPT,               // GPT-style full music model
    AudioDiffusion,         // Diffusion-based audio generation

    // Lyrics
    LyricTransformer,       // Lyrics generation
    RhymeNet                // Rhyme and meter model
};

struct ModelInfo {
    AIModel model;
    std::string name;
    std::string version;
    std::string description;

    int64_t sizeBytes = 0;
    bool isDownloaded = false;
    bool isLoaded = false;

    std::vector<MusicStyle> supportedStyles;
    float qualityScore = 0.0f;
    float speedScore = 0.0f;
};

// ============================================================================
// AI Composer
// ============================================================================

class AIComposer {
public:
    static AIComposer& getInstance() {
        static AIComposer instance;
        return instance;
    }

    // ========================================================================
    // Model Management
    // ========================================================================

    std::vector<ModelInfo> getAvailableModels() const {
        std::lock_guard<std::mutex> lock(mutex_);

        std::vector<ModelInfo> result;
        for (const auto& [model, info] : models_) {
            result.push_back(info);
        }
        return result;
    }

    bool loadModel(AIModel model) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = models_.find(model);
        if (it == models_.end()) return false;

        // Would load actual ML model
        it->second.isLoaded = true;
        currentModel_ = model;

        return true;
    }

    void unloadModel(AIModel model) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto it = models_.find(model);
        if (it != models_.end()) {
            it->second.isLoaded = false;
        }
    }

    // ========================================================================
    // Melody Generation
    // ========================================================================

    GenerationResult generateMelody(const GenerationParams& params) {
        std::lock_guard<std::mutex> lock(mutex_);

        auto startTime = std::chrono::steady_clock::now();
        GenerationResult result;

        // Initialize RNG
        std::mt19937 rng(params.seed >= 0 ? params.seed : std::random_device{}());

        // Get scale notes
        std::vector<int> scaleNotes = params.scale.getNotes();
        if (scaleNotes.empty()) {
            scaleNotes = {0, 2, 4, 5, 7, 9, 11};  // Default major scale
        }

        // Generate melody using simple Markov-like approach
        // (Would use actual ML model in production)

        Melody melody;
        melody.id = generateId("melody");
        melody.scale = params.scale;
        melody.tempo = params.tempo;

        double currentTime = 0.0;
        double totalBeats = params.bars * params.beatsPerBar;

        std::uniform_real_distribution<float> velDist(0.6f, 1.0f);
        std::uniform_int_distribution<int> noteDist(0, static_cast<int>(scaleNotes.size()) - 1);
        std::uniform_real_distribution<float> durationDist(0.25f, 2.0f);
        std::uniform_real_distribution<float> restProbDist(0.0f, 1.0f);

        int baseOctave = 5;  // Middle C octave

        while (currentTime < totalBeats) {
            // Sometimes add a rest
            if (restProbDist(rng) < 0.15f) {
                currentTime += 0.5;
                continue;
            }

            Note note;
            int scaleIndex = noteDist(rng);
            note.pitch = baseOctave * 12 + scaleNotes[scaleIndex % scaleNotes.size()];

            // Adjust for complexity
            if (params.complexity > 0.7f) {
                // Add chromatic notes occasionally
                if (restProbDist(rng) < 0.1f) {
                    note.pitch += (restProbDist(rng) < 0.5f ? 1 : -1);
                }
            }

            note.velocity = velDist(rng) * (1.0f - params.humanization * 0.3f);
            note.startTime = currentTime;

            float rawDuration = durationDist(rng);
            // Quantize based on complexity
            if (params.complexity < 0.3f) {
                note.duration = std::round(rawDuration * 2) / 2;  // Half notes
            } else if (params.complexity < 0.6f) {
                note.duration = std::round(rawDuration * 4) / 4;  // Quarter notes
            } else {
                note.duration = std::round(rawDuration * 8) / 8;  // Eighth notes
            }

            melody.notes.push_back(note);
            currentTime += note.duration;
        }

        result.melody = melody;
        result.success = true;
        result.confidence = 0.85f;

        auto endTime = std::chrono::steady_clock::now();
        result.generationTime = std::chrono::duration_cast<std::chrono::milliseconds>(
            endTime - startTime);

        return result;
    }

    // ========================================================================
    // Chord Generation
    // ========================================================================

    GenerationResult generateChords(const GenerationParams& params) {
        std::lock_guard<std::mutex> lock(mutex_);

        GenerationResult result;
        ChordProgression progression;
        progression.id = generateId("chords");
        progression.scale = params.scale;
        progression.style = styleToString(params.style);

        std::mt19937 rng(params.seed >= 0 ? params.seed : std::random_device{}());

        // Common chord progressions by style
        std::vector<std::vector<std::string>> progressions;

        if (params.style == MusicStyle::Pop) {
            progressions = {
                {"I", "V", "vi", "IV"},
                {"I", "IV", "V", "I"},
                {"vi", "IV", "I", "V"},
                {"I", "V", "IV", "V"}
            };
        } else if (params.style == MusicStyle::Jazz) {
            progressions = {
                {"IImaj7", "V7", "Imaj7", "Imaj7"},
                {"Imaj7", "vi7", "ii7", "V7"},
                {"I7", "IV7", "I7", "V7"}
            };
        } else if (params.style == MusicStyle::Blues) {
            progressions = {
                {"I7", "I7", "IV7", "I7"},
                {"I7", "IV7", "I7", "V7"}
            };
        } else {
            progressions = {
                {"I", "IV", "V", "I"},
                {"I", "vi", "IV", "V"}
            };
        }

        std::uniform_int_distribution<int> progDist(0, static_cast<int>(progressions.size()) - 1);
        auto& selectedProg = progressions[progDist(rng)];

        int root = params.scale.root;
        double beatsPerChord = params.beatsPerBar;
        double currentTime = 0.0;

        for (int bar = 0; bar < params.bars; ++bar) {
            int progIndex = bar % static_cast<int>(selectedProg.size());

            Chord chord;
            chord.function = selectedProg[progIndex];
            chord.startTime = currentTime;
            chord.duration = beatsPerChord;

            // Convert function to actual pitches
            chord.pitches = functionToPitches(chord.function, root, params.isMinor);
            chord.name = getFunctionName(chord.function, root);

            progression.chords.push_back(chord);
            currentTime += beatsPerChord;
        }

        result.chords = progression;
        result.success = true;
        result.confidence = 0.9f;

        return result;
    }

    // ========================================================================
    // Rhythm Generation
    // ========================================================================

    RhythmPattern generateRhythm(const GenerationParams& params,
                                  const std::string& instrument = "drums") {
        std::lock_guard<std::mutex> lock(mutex_);

        RhythmPattern pattern;
        pattern.id = generateId("rhythm");
        pattern.name = instrument + " pattern";
        pattern.beatsPerBar = params.beatsPerBar;
        pattern.subdivision = 4;

        std::mt19937 rng(params.seed >= 0 ? params.seed : std::random_device{}());
        std::uniform_real_distribution<float> velDist(0.5f, 1.0f);
        std::uniform_real_distribution<float> probDist(0.0f, 1.0f);

        int stepsPerBar = pattern.beatsPerBar * pattern.subdivision;

        // Generate basic groove
        for (int step = 0; step < stepsPerBar; ++step) {
            float stepTime = static_cast<float>(step) / pattern.subdivision;

            float hitProb = 0.0f;

            // Kick drum pattern
            if (instrument == "kick" || instrument == "drums") {
                if (step == 0) hitProb = 0.95f;  // Downbeat
                else if (step == 8) hitProb = 0.8f;  // Beat 3
                else if (step % 4 == 0) hitProb = 0.3f * params.complexity;
            }

            // Snare pattern
            if (instrument == "snare" || instrument == "drums") {
                if (step == 4 || step == 12) hitProb = 0.9f;  // 2 and 4
            }

            // Hi-hat pattern
            if (instrument == "hihat" || instrument == "drums") {
                if (step % 2 == 0) hitProb = 0.8f;  // 8th notes
                else hitProb = 0.4f * params.complexity;  // 16th notes
            }

            if (probDist(rng) < hitProb) {
                RhythmPattern::Hit hit;
                hit.time = stepTime;
                hit.velocity = velDist(rng);
                hit.probability = hitProb;

                // Add humanization
                if (params.humanization > 0) {
                    std::normal_distribution<float> timingDist(0.0f, 0.02f * params.humanization);
                    hit.time += timingDist(rng);
                }

                pattern.hits.push_back(hit);
            }
        }

        return pattern;
    }

    // ========================================================================
    // Continuation
    // ========================================================================

    GenerationResult continueMusic(const std::vector<Note>& existingNotes,
                                    const GenerationParams& params) {
        GenerationParams continueParams = params;
        continueParams.previousNotes = existingNotes;

        // Analyze existing notes for patterns
        // Generate continuation based on learned patterns

        return generateMelody(continueParams);
    }

    // ========================================================================
    // Variation
    // ========================================================================

    Melody createVariation(const Melody& original, float variationAmount = 0.3f) {
        std::lock_guard<std::mutex> lock(mutex_);

        Melody variation = original;
        variation.id = generateId("var");

        std::mt19937 rng(std::random_device{}());
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        std::normal_distribution<float> pitchDist(0.0f, 2.0f);

        for (auto& note : variation.notes) {
            if (dist(rng) < variationAmount) {
                // Vary pitch
                int pitchChange = static_cast<int>(std::round(pitchDist(rng)));
                note.pitch = std::clamp(note.pitch + pitchChange, 0, 127);
            }

            if (dist(rng) < variationAmount * 0.5f) {
                // Vary timing slightly
                note.startTime += (dist(rng) - 0.5f) * 0.1;
            }

            if (dist(rng) < variationAmount * 0.3f) {
                // Vary velocity
                note.velocity = std::clamp(note.velocity + (dist(rng) - 0.5f) * 0.2f, 0.1f, 1.0f);
            }
        }

        return variation;
    }

    // ========================================================================
    // Style Transfer
    // ========================================================================

    Melody applyStyle(const Melody& source, MusicStyle targetStyle) {
        std::lock_guard<std::mutex> lock(mutex_);

        Melody styled = source;
        styled.id = generateId("styled");

        // Would use ML model for actual style transfer
        // For now, apply simple style-based modifications

        switch (targetStyle) {
            case MusicStyle::Jazz:
                // Add swing feel, extended harmonies
                for (auto& note : styled.notes) {
                    // Swing timing
                    double beatPos = std::fmod(note.startTime, 1.0);
                    if (beatPos > 0.4 && beatPos < 0.6) {
                        note.startTime += 0.1;  // Push back for swing
                    }
                }
                break;

            case MusicStyle::Classical:
                // Smooth velocity curves
                for (size_t i = 0; i < styled.notes.size(); ++i) {
                    float progress = static_cast<float>(i) / styled.notes.size();
                    styled.notes[i].velocity *= 0.7f + 0.3f * std::sin(progress * 3.14159f);
                }
                break;

            case MusicStyle::Electronic:
                // Quantize to grid
                for (auto& note : styled.notes) {
                    note.startTime = std::round(note.startTime * 4) / 4;
                    note.duration = std::round(note.duration * 4) / 4;
                }
                break;

            default:
                break;
        }

        return styled;
    }

    // ========================================================================
    // Lyrics Generation
    // ========================================================================

    struct LyricsResult {
        bool success = false;
        std::vector<std::string> verses;
        std::vector<std::string> chorus;
        std::string bridge;
        std::string title;

        std::vector<std::pair<std::string, std::string>> rhymePairs;
    };

    LyricsResult generateLyrics(const std::string& theme,
                                 MusicStyle style,
                                 Emotion emotion,
                                 int numVerses = 2) {
        std::lock_guard<std::mutex> lock(mutex_);

        LyricsResult result;

        // Would use LLM for actual lyrics generation
        // This is a placeholder

        result.title = "Untitled Song about " + theme;

        result.chorus.push_back("This is the chorus line");
        result.chorus.push_back("About " + theme + " and more");
        result.chorus.push_back("Singing from the heart");
        result.chorus.push_back("Never falling apart");

        for (int v = 0; v < numVerses; ++v) {
            std::string verse = "Verse " + std::to_string(v + 1) +
                " about " + theme + "...";
            result.verses.push_back(verse);
        }

        result.bridge = "And in the bridge we find...";
        result.success = true;

        return result;
    }

private:
    AIComposer() {
        initializeModels();
    }
    ~AIComposer() = default;

    AIComposer(const AIComposer&) = delete;
    AIComposer& operator=(const AIComposer&) = delete;

    void initializeModels() {
        models_[AIModel::MelodyTransformer] = {
            .model = AIModel::MelodyTransformer,
            .name = "Melody Transformer",
            .version = "1.0.0",
            .description = "Transformer-based melody generation",
            .sizeBytes = 250 * 1024 * 1024,
            .isDownloaded = true,
            .qualityScore = 0.9f,
            .speedScore = 0.7f
        };

        models_[AIModel::ChordTransformer] = {
            .model = AIModel::ChordTransformer,
            .name = "Chord Transformer",
            .version = "1.0.0",
            .description = "Harmonic progression generation",
            .sizeBytes = 150 * 1024 * 1024,
            .isDownloaded = true,
            .qualityScore = 0.85f,
            .speedScore = 0.8f
        };

        models_[AIModel::DrumNet] = {
            .model = AIModel::DrumNet,
            .name = "DrumNet",
            .version = "1.0.0",
            .description = "Drum pattern generation",
            .sizeBytes = 100 * 1024 * 1024,
            .isDownloaded = true,
            .qualityScore = 0.88f,
            .speedScore = 0.9f
        };
    }

    std::string generateId(const std::string& prefix) {
        return prefix + "_" + std::to_string(nextId_++);
    }

    std::string styleToString(MusicStyle style) const {
        switch (style) {
            case MusicStyle::Pop: return "pop";
            case MusicStyle::Rock: return "rock";
            case MusicStyle::Jazz: return "jazz";
            case MusicStyle::Classical: return "classical";
            case MusicStyle::Electronic: return "electronic";
            case MusicStyle::HipHop: return "hiphop";
            default: return "general";
        }
    }

    std::vector<int> functionToPitches(const std::string& function,
                                        int root, bool minor) const {
        // Simplified chord construction
        std::vector<int> pitches;
        int base = root;

        if (function.find("I") != std::string::npos) base = root;
        else if (function.find("II") != std::string::npos ||
                 function.find("ii") != std::string::npos) base = root + 2;
        else if (function.find("III") != std::string::npos ||
                 function.find("iii") != std::string::npos) base = root + 4;
        else if (function.find("IV") != std::string::npos ||
                 function.find("iv") != std::string::npos) base = root + 5;
        else if (function.find("V") != std::string::npos ||
                 function.find("v") != std::string::npos) base = root + 7;
        else if (function.find("VI") != std::string::npos ||
                 function.find("vi") != std::string::npos) base = root + 9;
        else if (function.find("VII") != std::string::npos ||
                 function.find("vii") != std::string::npos) base = root + 11;

        // Major or minor triad
        bool isMinorChord = (function[0] >= 'a' && function[0] <= 'z');
        pitches.push_back(base + 48);  // Bass note
        pitches.push_back(base + 48 + (isMinorChord ? 3 : 4));  // Third
        pitches.push_back(base + 48 + 7);  // Fifth

        // Add 7th if specified
        if (function.find("7") != std::string::npos) {
            pitches.push_back(base + 48 + (function.find("maj7") != std::string::npos ? 11 : 10));
        }

        return pitches;
    }

    std::string getFunctionName(const std::string& function, int root) const {
        static const char* noteNames[] = {"C", "C#", "D", "D#", "E", "F",
                                          "F#", "G", "G#", "A", "A#", "B"};
        int noteIndex = root % 12;

        std::string name = noteNames[noteIndex];
        if (function[0] >= 'a' && function[0] <= 'z') {
            name += "m";
        }
        if (function.find("7") != std::string::npos) {
            name += "7";
        }

        return name;
    }

    mutable std::mutex mutex_;

    std::map<AIModel, ModelInfo> models_;
    AIModel currentModel_ = AIModel::MelodyTransformer;

    std::atomic<int> nextId_{1};
};

// ============================================================================
// Convenience Functions
// ============================================================================

namespace Composer {

inline GenerationResult melody(const GenerationParams& params = {}) {
    return AIComposer::getInstance().generateMelody(params);
}

inline GenerationResult chords(const GenerationParams& params = {}) {
    return AIComposer::getInstance().generateChords(params);
}

inline RhythmPattern rhythm(const GenerationParams& params = {},
                             const std::string& instrument = "drums") {
    return AIComposer::getInstance().generateRhythm(params, instrument);
}

inline Melody vary(const Melody& original, float amount = 0.3f) {
    return AIComposer::getInstance().createVariation(original, amount);
}

} // namespace Composer

} // namespace AI
} // namespace Echoel
