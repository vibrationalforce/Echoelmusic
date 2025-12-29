#pragma once

/*
 * EchoelCreativeAssistant.h
 * Ralph Wiggum Genius Loop Mode - User-Controlled Creative Assistant
 *
 * IMPORTANT: This is an ASSISTIVE TOOL - NOT a content generator!
 * - User has FULL creative control
 * - ALL credits remain 100% with the user
 * - AI provides suggestions, analysis, and templates ONLY
 * - User makes ALL final creative decisions
 * - Nothing is auto-applied without explicit user approval
 *
 * Features:
 * - Songwriting assistance (chord suggestions, structure analysis)
 * - Composing help (harmony analysis, voice leading hints)
 * - Design assistance (layout suggestions, color theory)
 * - Video editing hints (pacing analysis, cut suggestions)
 * - Template library (user-customizable starting points)
 */

#include <vector>
#include <array>
#include <memory>
#include <functional>
#include <string>
#include <map>
#include <optional>

namespace Echoel {
namespace AI {

// ============================================================================
// Creative Philosophy: User-First Design
// ============================================================================

/*
 * Core Principles:
 * 1. SUGGESTION, not generation - user decides everything
 * 2. ANALYSIS, not creation - help user understand their work
 * 3. TEMPLATES, not finished products - starting points user can modify
 * 4. EDUCATION, not automation - teach user techniques
 * 5. ATTRIBUTION: 100% credit to user for ALL creative output
 */

// ============================================================================
// Suggestion Types
// ============================================================================

enum class SuggestionPriority {
    Optional,       // Nice to consider
    Recommended,    // Worth considering
    Important       // Should consider
};

enum class CreativeArea {
    Songwriting,
    Composing,
    SoundDesign,
    VisualDesign,
    VideoEditing,
    Mixing,
    Mastering,
    Performance
};

struct CreativeSuggestion {
    std::string title;
    std::string description;
    std::string rationale;           // WHY this is suggested
    std::string howToApply;          // HOW user can apply it
    CreativeArea area;
    SuggestionPriority priority = SuggestionPriority::Optional;
    float confidence = 0.5f;         // How confident is suggestion

    // User control
    bool userReviewed = false;       // User has seen this
    bool userApproved = false;       // User explicitly approved
    bool userRejected = false;       // User explicitly rejected
    std::string userNotes;           // User's own notes

    // No auto-apply - user must manually implement
};

// ============================================================================
// Music Theory Helpers (Educational, not generative)
// ============================================================================

class MusicTheoryHelper {
public:
    // Analyze user's chord - explain what it is
    struct ChordAnalysis {
        std::string chordName;           // e.g., "C major 7"
        std::string romanNumeral;        // e.g., "Imaj7"
        std::string function;            // e.g., "Tonic"
        std::vector<std::string> notes;  // e.g., ["C", "E", "G", "B"]
        std::vector<std::string> tensions;  // Available tensions
        std::string explanation;         // Educational text
    };

    ChordAnalysis analyzeChord(const std::vector<int>& midiNotes) const {
        ChordAnalysis result;

        if (midiNotes.empty()) {
            result.explanation = "No notes provided";
            return result;
        }

        // Identify root and intervals
        int root = midiNotes[0] % 12;
        std::vector<int> intervals;
        for (size_t i = 1; i < midiNotes.size(); ++i) {
            intervals.push_back((midiNotes[i] - midiNotes[0]) % 12);
        }

        // Determine chord type based on intervals
        result.notes.push_back(noteNames_[root]);
        for (int interval : intervals) {
            result.notes.push_back(noteNames_[(root + interval) % 12]);
        }

        // Chord identification logic
        bool hasMajor3 = std::find(intervals.begin(), intervals.end(), 4) != intervals.end();
        bool hasMinor3 = std::find(intervals.begin(), intervals.end(), 3) != intervals.end();
        bool hasPerfect5 = std::find(intervals.begin(), intervals.end(), 7) != intervals.end();
        bool hasMajor7 = std::find(intervals.begin(), intervals.end(), 11) != intervals.end();
        bool hasMinor7 = std::find(intervals.begin(), intervals.end(), 10) != intervals.end();

        std::string quality;
        if (hasMajor3 && hasPerfect5) {
            quality = "major";
            if (hasMajor7) quality += " 7";
            else if (hasMinor7) quality = "dominant 7";
        } else if (hasMinor3 && hasPerfect5) {
            quality = "minor";
            if (hasMinor7) quality += " 7";
        } else if (hasMinor3 && !hasPerfect5) {
            quality = "diminished";
        }

        result.chordName = noteNames_[root] + " " + quality;
        result.explanation = "This chord contains " + std::to_string(midiNotes.size()) +
                            " notes. The root is " + noteNames_[root] + ".";

        return result;
    }

    // Suggest possible next chords (educational)
    struct ChordOption {
        std::string chordName;
        std::string romanNumeral;
        std::string reason;          // Why this might work
        float commonality;           // How common is this movement
    };

    std::vector<ChordOption> suggestNextChords(const std::string& currentChord,
                                                const std::string& key) const {
        std::vector<ChordOption> options;

        // Common chord progressions
        options.push_back({
            "V chord",
            "V",
            "The dominant creates tension that wants to resolve",
            0.9f
        });

        options.push_back({
            "IV chord",
            "IV",
            "Subdominant creates gentle motion away from tonic",
            0.8f
        });

        options.push_back({
            "vi chord",
            "vi",
            "Relative minor adds emotional depth",
            0.7f
        });

        options.push_back({
            "ii chord",
            "ii",
            "Supertonic often leads to V (ii-V-I progression)",
            0.6f
        });

        return options;
    }

    // Explain a scale
    struct ScaleInfo {
        std::string name;
        std::vector<std::string> notes;
        std::vector<int> intervals;
        std::string mood;
        std::string usage;
        std::vector<std::string> famousSongs;  // User can study these
    };

    ScaleInfo explainScale(const std::string& scaleName, int rootNote) const {
        ScaleInfo info;
        info.name = scaleName;

        if (scaleName == "major" || scaleName == "ionian") {
            info.intervals = {0, 2, 4, 5, 7, 9, 11};
            info.mood = "Happy, bright, resolved";
            info.usage = "Foundation of Western music, works for uplifting songs";
        } else if (scaleName == "minor" || scaleName == "aeolian") {
            info.intervals = {0, 2, 3, 5, 7, 8, 10};
            info.mood = "Sad, introspective, emotional";
            info.usage = "Emotional ballads, darker themes";
        } else if (scaleName == "dorian") {
            info.intervals = {0, 2, 3, 5, 7, 9, 10};
            info.mood = "Minor but with a brighter feel";
            info.usage = "Jazz, funk, adds sophistication to minor";
        } else if (scaleName == "pentatonic_major") {
            info.intervals = {0, 2, 4, 7, 9};
            info.mood = "Simple, universal, accessible";
            info.usage = "Very forgiving for improvisation";
        }

        for (int interval : info.intervals) {
            info.notes.push_back(noteNames_[(rootNote + interval) % 12]);
        }

        return info;
    }

private:
    const std::array<std::string, 12> noteNames_ = {
        "C", "C#", "D", "D#", "E", "F",
        "F#", "G", "G#", "A", "A#", "B"
    };
};

// ============================================================================
// Songwriting Assistant
// ============================================================================

class SongwritingAssistant {
public:
    // Analyze user's song structure
    struct StructureAnalysis {
        std::vector<std::string> sections;   // Identified sections
        std::string form;                     // e.g., "ABABCB"
        std::vector<std::string> observations;
        std::vector<CreativeSuggestion> suggestions;
    };

    StructureAnalysis analyzeStructure(const std::vector<std::string>& userSections) const {
        StructureAnalysis result;
        result.sections = userSections;

        // Create form string
        for (const auto& section : userSections) {
            if (section.find("verse") != std::string::npos) result.form += "A";
            else if (section.find("chorus") != std::string::npos) result.form += "B";
            else if (section.find("bridge") != std::string::npos) result.form += "C";
            else if (section.find("intro") != std::string::npos) result.form += "I";
            else if (section.find("outro") != std::string::npos) result.form += "O";
            else result.form += "X";
        }

        // Educational observations
        result.observations.push_back(
            "Your song has " + std::to_string(userSections.size()) + " sections");

        // Count choruses
        int chorusCount = std::count_if(userSections.begin(), userSections.end(),
            [](const std::string& s) { return s.find("chorus") != std::string::npos; });

        if (chorusCount < 2) {
            CreativeSuggestion suggestion;
            suggestion.title = "Consider adding more chorus repetition";
            suggestion.description = "Most popular songs repeat the chorus 3-4 times";
            suggestion.rationale = "Repetition helps listeners remember the hook";
            suggestion.howToApply = "You could add another chorus after the bridge";
            suggestion.priority = SuggestionPriority::Optional;
            result.suggestions.push_back(suggestion);
        }

        return result;
    }

    // Rhyme suggestions (user picks what works)
    struct RhymeSuggestion {
        std::string originalWord;
        std::vector<std::string> perfectRhymes;
        std::vector<std::string> nearRhymes;
        std::vector<std::string> assonanceOptions;
        std::string note;
    };

    RhymeSuggestion findRhymes(const std::string& word) const {
        RhymeSuggestion result;
        result.originalWord = word;
        result.note = "These are suggestions - choose what fits YOUR vision";

        // This would connect to a rhyme dictionary
        // Placeholder examples
        if (word == "love") {
            result.perfectRhymes = {"above", "dove", "shove"};
            result.nearRhymes = {"of", "enough", "rough"};
            result.assonanceOptions = {"touch", "sun", "come"};
        } else if (word == "heart") {
            result.perfectRhymes = {"art", "part", "start", "apart"};
            result.nearRhymes = {"hard", "dark", "mark"};
        }

        return result;
    }

    // Syllable meter analysis
    struct MeterAnalysis {
        std::string line;
        int syllableCount;
        std::string stressPattern;  // e.g., "da-DUM-da-DUM-da-DUM"
        std::string meterType;      // e.g., "iambic"
        bool consistent;            // With previous lines
        std::string tip;
    };

    MeterAnalysis analyzeMeter(const std::string& line) const {
        MeterAnalysis result;
        result.line = line;

        // Count syllables (simplified)
        int syllables = 0;
        bool prevVowel = false;
        for (char c : line) {
            bool isVowel = (c == 'a' || c == 'e' || c == 'i' ||
                           c == 'o' || c == 'u' || c == 'y');
            if (isVowel && !prevVowel) syllables++;
            prevVowel = isVowel;
        }

        result.syllableCount = syllables;
        result.tip = "This line has approximately " +
                    std::to_string(syllables) + " syllables. " +
                    "Consistent syllable counts help create rhythm.";

        return result;
    }
};

// ============================================================================
// Visual Design Assistant
// ============================================================================

class VisualDesignAssistant {
public:
    // Color theory education
    struct ColorAnalysis {
        std::string colorName;
        std::string hexCode;
        std::string psychological;      // Psychological effect
        std::string culturalNotes;      // Cultural associations
        std::vector<std::string> complementaryColors;
        std::vector<std::string> analogousColors;
        std::string tip;
    };

    ColorAnalysis analyzeColor(float r, float g, float b) const {
        ColorAnalysis result;

        // Convert to hex
        char hex[8];
        snprintf(hex, sizeof(hex), "#%02X%02X%02X",
                static_cast<int>(r * 255),
                static_cast<int>(g * 255),
                static_cast<int>(b * 255));
        result.hexCode = hex;

        // Determine dominant hue
        if (r > g && r > b) {
            result.colorName = "Red-dominant";
            result.psychological = "Energy, passion, urgency, warmth";
            result.culturalNotes = "Can signify love, danger, or importance";
        } else if (g > r && g > b) {
            result.colorName = "Green-dominant";
            result.psychological = "Nature, growth, calm, health";
            result.culturalNotes = "Often associated with eco, money, or go signals";
        } else if (b > r && b > g) {
            result.colorName = "Blue-dominant";
            result.psychological = "Trust, calm, professionalism, depth";
            result.culturalNotes = "Most universally liked color";
        }

        result.tip = "Consider how this color supports your creative vision";

        return result;
    }

    // Layout suggestions
    struct LayoutSuggestion {
        std::string principle;      // e.g., "Rule of Thirds"
        std::string explanation;    // Educational content
        std::string application;    // How to apply
    };

    std::vector<LayoutSuggestion> getLayoutPrinciples() const {
        return {
            {
                "Rule of Thirds",
                "Divide your canvas into 9 equal parts with 2 horizontal and 2 vertical lines",
                "Place key elements along the lines or at intersections"
            },
            {
                "Visual Hierarchy",
                "Guide the viewer's eye through size, color, and position differences",
                "Make your most important element the largest or most contrasting"
            },
            {
                "Negative Space",
                "Empty space gives elements room to breathe and creates focus",
                "Don't fill every area - strategic emptiness is powerful"
            },
            {
                "Balance",
                "Visual weight should feel distributed appropriately",
                "Symmetrical = formal, Asymmetrical = dynamic"
            }
        };
    }

    // Contrast checker for accessibility
    struct ContrastResult {
        float ratio;
        bool passesAA;      // WCAG AA (4.5:1 for normal text)
        bool passesAAA;     // WCAG AAA (7:1 for normal text)
        std::string recommendation;
    };

    ContrastResult checkContrast(float fgR, float fgG, float fgB,
                                  float bgR, float bgG, float bgB) const {
        ContrastResult result;

        // Calculate relative luminance
        auto luminance = [](float r, float g, float b) {
            auto adjust = [](float c) {
                return (c <= 0.03928f) ? c / 12.92f :
                       std::pow((c + 0.055f) / 1.055f, 2.4f);
            };
            return 0.2126f * adjust(r) + 0.7152f * adjust(g) + 0.0722f * adjust(b);
        };

        float l1 = luminance(fgR, fgG, fgB);
        float l2 = luminance(bgR, bgG, bgB);

        float lighter = std::max(l1, l2);
        float darker = std::min(l1, l2);

        result.ratio = (lighter + 0.05f) / (darker + 0.05f);
        result.passesAA = result.ratio >= 4.5f;
        result.passesAAA = result.ratio >= 7.0f;

        if (result.passesAAA) {
            result.recommendation = "Excellent contrast for all users";
        } else if (result.passesAA) {
            result.recommendation = "Good contrast, passes accessibility standards";
        } else {
            result.recommendation = "Consider increasing contrast for better readability";
        }

        return result;
    }
};

// ============================================================================
// Video Editing Assistant
// ============================================================================

class VideoEditingAssistant {
public:
    // Pacing analysis
    struct PacingAnalysis {
        float averageCutDuration;    // Seconds
        float minCutDuration;
        float maxCutDuration;
        std::string pacingDescription;
        std::vector<std::string> observations;
        std::vector<CreativeSuggestion> suggestions;
    };

    PacingAnalysis analyzePacing(const std::vector<float>& cutDurations) const {
        PacingAnalysis result;

        if (cutDurations.empty()) {
            result.pacingDescription = "No cuts to analyze";
            return result;
        }

        // Calculate statistics
        float sum = 0;
        result.minCutDuration = cutDurations[0];
        result.maxCutDuration = cutDurations[0];

        for (float dur : cutDurations) {
            sum += dur;
            result.minCutDuration = std::min(result.minCutDuration, dur);
            result.maxCutDuration = std::max(result.maxCutDuration, dur);
        }

        result.averageCutDuration = sum / cutDurations.size();

        // Describe pacing
        if (result.averageCutDuration < 2.0f) {
            result.pacingDescription = "Fast-paced (music video/action style)";
        } else if (result.averageCutDuration < 5.0f) {
            result.pacingDescription = "Medium pace (standard narrative)";
        } else {
            result.pacingDescription = "Slow, contemplative pacing";
        }

        // Educational observations
        result.observations.push_back(
            "Average cut: " + std::to_string(result.averageCutDuration) + "s");
        result.observations.push_back(
            "Range: " + std::to_string(result.minCutDuration) + "s to " +
            std::to_string(result.maxCutDuration) + "s");

        return result;
    }

    // Transition suggestions (educational)
    struct TransitionInfo {
        std::string name;
        std::string description;
        std::string bestUsedFor;
        std::string emotionalEffect;
    };

    std::vector<TransitionInfo> getTransitionGuide() const {
        return {
            {
                "Cut",
                "Instant change between shots",
                "Most common transition, maintains energy",
                "Neutral, doesn't call attention to itself"
            },
            {
                "Dissolve",
                "Gradual blend between shots",
                "Time passage, dreamy sequences, soft transitions",
                "Romantic, nostalgic, passage of time"
            },
            {
                "Fade to Black",
                "Gradual fade to black, then from black",
                "End of scenes, time jumps, emotional moments",
                "Finality, pause for reflection"
            },
            {
                "Wipe",
                "One shot pushes another off screen",
                "Scene changes, retro/stylized content",
                "Energetic, intentionally visible"
            },
            {
                "J-Cut",
                "Audio from next scene starts before video",
                "Creates anticipation, smooth scene links",
                "Pulls viewer forward"
            },
            {
                "L-Cut",
                "Audio from previous scene continues into next",
                "Reaction shots, maintaining continuity",
                "Connects scenes emotionally"
            }
        };
    }

    // Audio sync analysis
    struct AudioSyncAnalysis {
        std::vector<float> beatTimestamps;
        std::vector<float> cutTimestamps;
        float syncPercentage;        // How many cuts land on beats
        std::vector<CreativeSuggestion> suggestions;
    };

    AudioSyncAnalysis analyzeAudioSync(const std::vector<float>& beats,
                                        const std::vector<float>& cuts) const {
        AudioSyncAnalysis result;
        result.beatTimestamps = beats;
        result.cutTimestamps = cuts;

        if (beats.empty() || cuts.empty()) {
            result.syncPercentage = 0;
            return result;
        }

        // Check how many cuts are near beats (within 100ms)
        int synced = 0;
        for (float cut : cuts) {
            for (float beat : beats) {
                if (std::abs(cut - beat) < 0.1f) {
                    synced++;
                    break;
                }
            }
        }

        result.syncPercentage = static_cast<float>(synced) / cuts.size() * 100.0f;

        if (result.syncPercentage < 30.0f) {
            CreativeSuggestion suggestion;
            suggestion.title = "Consider cutting on the beat";
            suggestion.description = "Only " + std::to_string(static_cast<int>(result.syncPercentage)) +
                                    "% of your cuts land on beats";
            suggestion.rationale = "Cutting on beats creates rhythmic visual flow";
            suggestion.howToApply = "Adjust cut points to align with musical beats";
            suggestion.priority = SuggestionPriority::Optional;
            result.suggestions.push_back(suggestion);
        }

        return result;
    }
};

// ============================================================================
// Template Library (User-Customizable Starting Points)
// ============================================================================

class TemplateLibrary {
public:
    struct Template {
        std::string id;
        std::string name;
        std::string category;
        std::string description;
        std::map<std::string, std::string> parameters;  // User-adjustable
        std::string attribution;     // Always credits user as creator

        // License info
        std::string license = "User owns 100% of any work created using this template";
    };

    // Song structure templates
    std::vector<Template> getSongTemplates() const {
        return {
            {
                "pop_standard",
                "Pop Song Structure",
                "Song Structure",
                "Common verse-chorus-bridge format",
                {
                    {"intro", "4-8 bars"},
                    {"verse1", "16 bars"},
                    {"chorus", "16 bars"},
                    {"verse2", "16 bars"},
                    {"chorus2", "16 bars"},
                    {"bridge", "8 bars"},
                    {"chorus3", "16 bars"},
                    {"outro", "4-8 bars"}
                },
                "Template only - all creative content is 100% yours"
            },
            {
                "ballad",
                "Ballad Structure",
                "Song Structure",
                "Emotional, story-driven format",
                {
                    {"intro", "4 bars, atmospheric"},
                    {"verse1", "16 bars, story setup"},
                    {"verse2", "16 bars, story development"},
                    {"chorus", "16 bars, emotional peak"},
                    {"verse3", "16 bars, climax"},
                    {"chorus2", "16 bars, resolution"},
                    {"outro", "8 bars, reflection"}
                },
                "Template only - all creative content is 100% yours"
            }
        };
    }

    // Chord progression templates
    std::vector<Template> getChordProgressionTemplates() const {
        return {
            {
                "I_V_vi_IV",
                "Pop Progression (I-V-vi-IV)",
                "Chord Progressions",
                "The most common pop progression",
                {
                    {"chord1", "I (C in C major)"},
                    {"chord2", "V (G)"},
                    {"chord3", "vi (Am)"},
                    {"chord4", "IV (F)"}
                },
                "This progression is in public domain - your melody and lyrics are yours"
            },
            {
                "ii_V_I",
                "Jazz ii-V-I",
                "Chord Progressions",
                "Essential jazz movement",
                {
                    {"chord1", "ii (Dm7 in C)"},
                    {"chord2", "V (G7)"},
                    {"chord3", "I (Cmaj7)"}
                },
                "Classic progression - your interpretation is uniquely yours"
            }
        };
    }

    // Visual templates
    std::vector<Template> getVisualTemplates() const {
        return {
            {
                "laser_spiral",
                "Spiral Pattern Base",
                "Laser Visuals",
                "Starting point for spiral-based visuals",
                {
                    {"revolutions", "3"},
                    {"speed", "1.0"},
                    {"color_scheme", "rainbow"},
                    {"symmetry", "1"}
                },
                "Template only - your customizations make it uniquely yours"
            }
        };
    }
};

// ============================================================================
// Main Creative Assistant
// ============================================================================

class EchoelCreativeAssistant {
public:
    /*
     * IMPORTANT DESIGN PRINCIPLES:
     *
     * 1. NEVER auto-generate content
     * 2. ALWAYS present as suggestions user can ignore
     * 3. NEVER claim any creative ownership
     * 4. ALWAYS educate rather than replace creativity
     * 5. 100% credit to user for ALL output
     */

    struct AssistantConfig {
        bool enableSuggestions = true;
        bool enableAnalysis = true;
        bool enableEducation = true;
        bool enableTemplates = true;

        // Important: No auto-apply
        bool autoApply = false;  // MUST remain false

        // Suggestion filtering
        float minConfidenceToShow = 0.3f;
        SuggestionPriority minPriorityToShow = SuggestionPriority::Optional;
    };

    EchoelCreativeAssistant() {
        musicTheory_ = std::make_unique<MusicTheoryHelper>();
        songwriting_ = std::make_unique<SongwritingAssistant>();
        visualDesign_ = std::make_unique<VisualDesignAssistant>();
        videoEditing_ = std::make_unique<VideoEditingAssistant>();
        templates_ = std::make_unique<TemplateLibrary>();
    }

    void setConfig(const AssistantConfig& config) {
        config_ = config;
        // Safety: Never allow auto-apply
        config_.autoApply = false;
    }

    // ========== Music Theory Help ==========

    MusicTheoryHelper::ChordAnalysis analyzeChord(const std::vector<int>& notes) const {
        return musicTheory_->analyzeChord(notes);
    }

    std::vector<MusicTheoryHelper::ChordOption> getNextChordIdeas(
        const std::string& currentChord, const std::string& key) const {
        return musicTheory_->suggestNextChords(currentChord, key);
    }

    MusicTheoryHelper::ScaleInfo learnScale(const std::string& scale, int root) const {
        return musicTheory_->explainScale(scale, root);
    }

    // ========== Songwriting Help ==========

    SongwritingAssistant::StructureAnalysis analyzeStructure(
        const std::vector<std::string>& sections) const {
        return songwriting_->analyzeStructure(sections);
    }

    SongwritingAssistant::RhymeSuggestion findRhymes(const std::string& word) const {
        return songwriting_->findRhymes(word);
    }

    SongwritingAssistant::MeterAnalysis analyzeMeter(const std::string& line) const {
        return songwriting_->analyzeMeter(line);
    }

    // ========== Visual Design Help ==========

    VisualDesignAssistant::ColorAnalysis analyzeColor(float r, float g, float b) const {
        return visualDesign_->analyzeColor(r, g, b);
    }

    std::vector<VisualDesignAssistant::LayoutSuggestion> getDesignPrinciples() const {
        return visualDesign_->getLayoutPrinciples();
    }

    VisualDesignAssistant::ContrastResult checkAccessibility(
        float fgR, float fgG, float fgB,
        float bgR, float bgG, float bgB) const {
        return visualDesign_->checkContrast(fgR, fgG, fgB, bgR, bgG, bgB);
    }

    // ========== Video Editing Help ==========

    VideoEditingAssistant::PacingAnalysis analyzePacing(
        const std::vector<float>& cuts) const {
        return videoEditing_->analyzePacing(cuts);
    }

    std::vector<VideoEditingAssistant::TransitionInfo> getTransitionGuide() const {
        return videoEditing_->getTransitionGuide();
    }

    VideoEditingAssistant::AudioSyncAnalysis analyzeSync(
        const std::vector<float>& beats,
        const std::vector<float>& cuts) const {
        return videoEditing_->analyzeAudioSync(beats, cuts);
    }

    // ========== Templates ==========

    std::vector<TemplateLibrary::Template> getSongTemplates() const {
        return templates_->getSongTemplates();
    }

    std::vector<TemplateLibrary::Template> getChordTemplates() const {
        return templates_->getChordProgressionTemplates();
    }

    std::vector<TemplateLibrary::Template> getVisualTemplates() const {
        return templates_->getVisualTemplates();
    }

    // ========== User Feedback Tracking ==========

    void recordSuggestionFeedback(const std::string& suggestionId, bool helpful) {
        feedbackHistory_[suggestionId] = helpful;
        // Use feedback to improve future suggestions
    }

    // ========== Attribution Statement ==========

    std::string getAttributionStatement() const {
        return "All creative work produced using Echoel is 100% owned by you, the creator. "
               "The assistant provides suggestions and analysis only - all creative "
               "decisions and resulting works are entirely yours. You retain full "
               "copyright and creative credit for everything you create.";
    }

private:
    AssistantConfig config_;

    std::unique_ptr<MusicTheoryHelper> musicTheory_;
    std::unique_ptr<SongwritingAssistant> songwriting_;
    std::unique_ptr<VisualDesignAssistant> visualDesign_;
    std::unique_ptr<VideoEditingAssistant> videoEditing_;
    std::unique_ptr<TemplateLibrary> templates_;

    std::map<std::string, bool> feedbackHistory_;
};

} // namespace AI
} // namespace Echoel
