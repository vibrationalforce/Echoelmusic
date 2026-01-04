/*
  ==============================================================================

    StyleTransferEngine.h
    Phase 5: AI Style Transfer for Music

    Apply the musical "style" of one piece to another while preserving
    the original's melodic content. Inspired by neural style transfer
    in image processing, adapted for music.

    Capabilities:
    - Genre transformation (jazz to electronic, etc.)
    - Artist-inspired styling
    - Era adaptation (80s synth, 70s funk, etc.)
    - Instrument voice transfer
    - Dynamic range transformation
    - Rhythmic feel transfer

    "Your melody, their vibe"

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "../Core/EchoelTypeSystem.h"
#include "../Core/MusicTheoryUtils.h"
#include <vector>
#include <memory>
#include <mutex>
#include <random>
#include <map>

namespace Echoelmusic {
namespace AI {

using namespace Types;
using namespace MusicTheory;

//==============================================================================
// Style Definition
//==============================================================================

struct MusicalStyle
{
    juce::String name;
    juce::String category;          // "genre", "artist", "era", "mood"

    // Rhythmic characteristics
    float swingAmount = 0.0f;       // 0 = straight, 0.5 = triplet swing
    float syncopation = 0.5f;       // Amount of off-beat emphasis
    float grooveTightness = 0.8f;   // How "on grid" the rhythm is
    std::vector<float> accentPattern;  // Beat emphasis pattern

    // Harmonic characteristics
    float chromaticism = 0.2f;      // Non-diatonic note usage
    float extensionUsage = 0.3f;    // 7ths, 9ths, etc.
    float modality = 0.0f;          // 0 = major, 1 = minor, 0.5 = modal
    std::vector<int> preferredIntervals;

    // Dynamic characteristics
    float dynamicRange = 0.6f;      // Velocity variation
    float expressiveness = 0.5f;   // Vibrato, bends, etc.
    float articulation = 0.5f;      // Staccato vs legato

    // Timbral hints (for instrument processing)
    float brightness = 0.5f;
    float warmth = 0.5f;
    float aggression = 0.3f;

    // Tempo preferences
    float preferredTempoBPM = 120.0f;
    float tempoFlexibility = 0.2f;  // How much tempo can vary
};

//==============================================================================
// Style Preset Library
//==============================================================================

class StylePresets
{
public:
    static const MusicalStyle& getStyle(const juce::String& name)
    {
        static std::map<juce::String, MusicalStyle> styles = createPresets();
        auto it = styles.find(name.toLowerCase());
        if (it != styles.end())
            return it->second;

        static MusicalStyle defaultStyle;
        defaultStyle.name = "default";
        return defaultStyle;
    }

    static std::vector<juce::String> getAvailableStyles()
    {
        return {
            // Genres
            "jazz", "blues", "rock", "pop", "electronic", "classical",
            "hiphop", "rnb", "country", "metal", "reggae", "latin",

            // Eras
            "60s_motown", "70s_funk", "80s_synth", "90s_grunge", "2000s_pop",

            // Moods
            "chill", "energetic", "melancholic", "uplifting", "aggressive",

            // Artists (inspirational styles, not copies)
            "jazz_complex", "soul_smooth", "indie_quirky", "cinematic_epic"
        };
    }

private:
    static std::map<juce::String, MusicalStyle> createPresets()
    {
        std::map<juce::String, MusicalStyle> styles;

        // Jazz
        {
            MusicalStyle jazz;
            jazz.name = "jazz";
            jazz.category = "genre";
            jazz.swingAmount = 0.4f;
            jazz.syncopation = 0.7f;
            jazz.grooveTightness = 0.6f;
            jazz.chromaticism = 0.6f;
            jazz.extensionUsage = 0.8f;
            jazz.modality = 0.5f;
            jazz.dynamicRange = 0.8f;
            jazz.expressiveness = 0.9f;
            jazz.preferredIntervals = {2, 4, 5, 7, 9, 11};
            jazz.brightness = 0.6f;
            jazz.warmth = 0.7f;
            jazz.preferredTempoBPM = 140.0f;
            styles["jazz"] = jazz;
        }

        // Blues
        {
            MusicalStyle blues;
            blues.name = "blues";
            blues.category = "genre";
            blues.swingAmount = 0.3f;
            blues.syncopation = 0.5f;
            blues.chromaticism = 0.4f;
            blues.extensionUsage = 0.5f;
            blues.modality = 0.7f;  // Blues = minor-ish
            blues.dynamicRange = 0.7f;
            blues.expressiveness = 0.9f;
            blues.preferredIntervals = {3, 5, 7, 10};  // Blue notes
            blues.warmth = 0.8f;
            blues.preferredTempoBPM = 90.0f;
            styles["blues"] = blues;
        }

        // Electronic
        {
            MusicalStyle electronic;
            electronic.name = "electronic";
            electronic.category = "genre";
            electronic.swingAmount = 0.0f;
            electronic.syncopation = 0.6f;
            electronic.grooveTightness = 0.95f;  // Tight to grid
            electronic.chromaticism = 0.3f;
            electronic.extensionUsage = 0.2f;
            electronic.dynamicRange = 0.4f;
            electronic.brightness = 0.8f;
            electronic.aggression = 0.5f;
            electronic.preferredTempoBPM = 128.0f;
            styles["electronic"] = electronic;
        }

        // 80s Synth
        {
            MusicalStyle synth80s;
            synth80s.name = "80s_synth";
            synth80s.category = "era";
            synth80s.swingAmount = 0.0f;
            synth80s.grooveTightness = 0.9f;
            synth80s.chromaticism = 0.3f;
            synth80s.extensionUsage = 0.4f;
            synth80s.modality = 0.4f;
            synth80s.brightness = 0.9f;
            synth80s.warmth = 0.3f;
            synth80s.preferredIntervals = {5, 7, 12};  // Power chords, octaves
            synth80s.preferredTempoBPM = 120.0f;
            styles["80s_synth"] = synth80s;
        }

        // 70s Funk
        {
            MusicalStyle funk70s;
            funk70s.name = "70s_funk";
            funk70s.category = "era";
            funk70s.swingAmount = 0.2f;
            funk70s.syncopation = 0.9f;  // Heavily syncopated
            funk70s.grooveTightness = 0.7f;
            funk70s.chromaticism = 0.3f;
            funk70s.extensionUsage = 0.6f;
            funk70s.dynamicRange = 0.8f;
            funk70s.warmth = 0.9f;
            funk70s.preferredIntervals = {3, 5, 7, 10};  // 7ths and 9ths
            funk70s.preferredTempoBPM = 110.0f;
            styles["70s_funk"] = funk70s;
        }

        // Chill
        {
            MusicalStyle chill;
            chill.name = "chill";
            chill.category = "mood";
            chill.swingAmount = 0.15f;
            chill.syncopation = 0.3f;
            chill.grooveTightness = 0.7f;
            chill.chromaticism = 0.2f;
            chill.extensionUsage = 0.5f;
            chill.dynamicRange = 0.4f;
            chill.expressiveness = 0.6f;
            chill.brightness = 0.4f;
            chill.warmth = 0.8f;
            chill.aggression = 0.0f;
            chill.preferredTempoBPM = 85.0f;
            styles["chill"] = chill;
        }

        // Cinematic Epic
        {
            MusicalStyle cinematic;
            cinematic.name = "cinematic_epic";
            cinematic.category = "mood";
            cinematic.swingAmount = 0.0f;
            cinematic.syncopation = 0.3f;
            cinematic.chromaticism = 0.4f;
            cinematic.extensionUsage = 0.6f;
            cinematic.dynamicRange = 1.0f;  // Full dynamic range
            cinematic.expressiveness = 1.0f;
            cinematic.brightness = 0.6f;
            cinematic.warmth = 0.7f;
            cinematic.preferredIntervals = {5, 7, 12};  // Fifths, octaves
            cinematic.preferredTempoBPM = 100.0f;
            cinematic.tempoFlexibility = 0.4f;  // Tempo changes OK
            styles["cinematic_epic"] = cinematic;
        }

        return styles;
    }
};

//==============================================================================
// Transfer Parameters
//==============================================================================

struct StyleTransferParams
{
    float styleStrength = 0.7f;     // How much to apply the style (0-1)
    float contentPreservation = 0.8f;  // How much to keep original melody
    float rhythmTransfer = 0.5f;    // Apply rhythmic characteristics
    float harmonyTransfer = 0.6f;   // Apply harmonic characteristics
    float dynamicsTransfer = 0.5f;  // Apply dynamic characteristics

    // What to preserve from original
    bool preservePitch = true;      // Keep same notes (quantize to style)
    bool preserveRhythm = false;    // Keep same timing
    bool preserveDynamics = false;  // Keep same velocities

    // Processing options
    bool realTime = false;          // Low-latency mode
    int lookAheadBeats = 4;         // Context for non-realtime
};

//==============================================================================
// Style Transfer Result
//==============================================================================

struct StyledMIDI
{
    struct Note
    {
        int pitch;
        float startBeat;
        float duration;
        float velocity;
        int channel;
    };

    std::vector<Note> notes;
    MusicalStyle appliedStyle;
    StyleTransferParams params;

    float styleConfidence = 0.0f;
    juce::String description;
};

//==============================================================================
// Style Transfer Engine
//==============================================================================

class StyleTransferEngine
{
public:
    static StyleTransferEngine& getInstance()
    {
        static StyleTransferEngine instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    // Style Transfer
    //--------------------------------------------------------------------------

    StyledMIDI applyStyle(
        const std::vector<StyledMIDI::Note>& inputNotes,
        const MusicalStyle& targetStyle,
        const StyleTransferParams& params = {})
    {
        std::lock_guard<std::mutex> lock(processingMutex);

        StyledMIDI result;
        result.appliedStyle = targetStyle;
        result.params = params;

        for (const auto& note : inputNotes)
        {
            StyledMIDI::Note styled = note;

            // Apply rhythmic transformation
            if (params.rhythmTransfer > 0 && !params.preserveRhythm)
            {
                styled = applyRhythmicStyle(styled, targetStyle, params.rhythmTransfer);
            }

            // Apply harmonic transformation
            if (params.harmonyTransfer > 0 && !params.preservePitch)
            {
                styled = applyHarmonicStyle(styled, targetStyle, params.harmonyTransfer);
            }

            // Apply dynamic transformation
            if (params.dynamicsTransfer > 0 && !params.preserveDynamics)
            {
                styled = applyDynamicStyle(styled, targetStyle, params.dynamicsTransfer);
            }

            result.notes.push_back(styled);
        }

        // Post-process for style coherence
        if (params.styleStrength > 0.5f)
        {
            applyStyleCoherence(result, targetStyle);
        }

        result.styleConfidence = calculateStyleMatch(result, targetStyle);
        result.description = generateDescription(result, targetStyle);

        return result;
    }

    StyledMIDI transferBetweenStyles(
        const std::vector<StyledMIDI::Note>& inputNotes,
        const MusicalStyle& sourceStyle,
        const MusicalStyle& targetStyle,
        float blendAmount = 0.5f)
    {
        // First, "neutralize" the source style
        StyleTransferParams neutralizeParams;
        neutralizeParams.styleStrength = 1.0f - blendAmount;

        auto neutralized = neutralizeStyle(inputNotes, sourceStyle);

        // Then apply target style
        StyleTransferParams applyParams;
        applyParams.styleStrength = blendAmount;

        return applyStyle(neutralized.notes, targetStyle, applyParams);
    }

    //--------------------------------------------------------------------------
    // Style Analysis
    //--------------------------------------------------------------------------

    MusicalStyle analyzeStyle(const std::vector<StyledMIDI::Note>& notes)
    {
        MusicalStyle detected;
        detected.name = "analyzed";
        detected.category = "detected";

        if (notes.empty())
            return detected;

        // Analyze swing
        detected.swingAmount = detectSwing(notes);

        // Analyze syncopation
        detected.syncopation = detectSyncopation(notes);

        // Analyze dynamics
        detected.dynamicRange = detectDynamicRange(notes);

        // Analyze intervals
        detected.preferredIntervals = detectPreferredIntervals(notes);
        detected.chromaticism = detectChromaticism(notes);

        // Analyze groove
        detected.grooveTightness = detectGrooveTightness(notes);

        return detected;
    }

    float measureStyleSimilarity(const MusicalStyle& a, const MusicalStyle& b)
    {
        float similarity = 0.0f;
        int factors = 0;

        // Compare all style dimensions
        similarity += 1.0f - std::abs(a.swingAmount - b.swingAmount); factors++;
        similarity += 1.0f - std::abs(a.syncopation - b.syncopation); factors++;
        similarity += 1.0f - std::abs(a.chromaticism - b.chromaticism); factors++;
        similarity += 1.0f - std::abs(a.dynamicRange - b.dynamicRange); factors++;
        similarity += 1.0f - std::abs(a.brightness - b.brightness); factors++;
        similarity += 1.0f - std::abs(a.warmth - b.warmth); factors++;

        return factors > 0 ? similarity / factors : 0.0f;
    }

    //--------------------------------------------------------------------------
    // Preset Helpers
    //--------------------------------------------------------------------------

    StyledMIDI applyPreset(
        const std::vector<StyledMIDI::Note>& inputNotes,
        const juce::String& presetName,
        float strength = 0.7f)
    {
        const auto& style = StylePresets::getStyle(presetName);
        StyleTransferParams params;
        params.styleStrength = strength;
        return applyStyle(inputNotes, style, params);
    }

    std::vector<juce::String> getAvailablePresets()
    {
        return StylePresets::getAvailableStyles();
    }

private:
    StyleTransferEngine() = default;
    ~StyleTransferEngine() = default;
    StyleTransferEngine(const StyleTransferEngine&) = delete;
    StyleTransferEngine& operator=(const StyleTransferEngine&) = delete;

    mutable std::mutex processingMutex;
    mutable std::mutex rngMutex;
    std::mt19937 rng{std::random_device{}()};

    template<typename Dist>
    auto threadSafeRandom(Dist& dist)
    {
        std::lock_guard<std::mutex> lock(rngMutex);
        return dist(rng);
    }

    //--------------------------------------------------------------------------
    // Style Application
    //--------------------------------------------------------------------------

    StyledMIDI::Note applyRhythmicStyle(
        const StyledMIDI::Note& note,
        const MusicalStyle& style,
        float amount)
    {
        StyledMIDI::Note result = note;

        // Apply swing
        if (style.swingAmount > 0)
        {
            float swingOffset = MusicTheory::applySwing(
                std::fmod(note.startBeat, 1.0f), style.swingAmount) -
                std::fmod(note.startBeat, 1.0f);

            result.startBeat += swingOffset * amount;
        }

        // Apply groove looseness
        if (style.grooveTightness < 0.9f)
        {
            float looseness = (1.0f - style.grooveTightness) * 0.05f;
            std::uniform_real_distribution<float> dist(-looseness, looseness);
            result.startBeat += threadSafeRandom(dist) * amount;
        }

        return result;
    }

    StyledMIDI::Note applyHarmonicStyle(
        const StyledMIDI::Note& note,
        const MusicalStyle& style,
        float amount)
    {
        StyledMIDI::Note result = note;

        // Add chromatic alterations based on style
        if (style.chromaticism > 0.5f && amount > 0.5f)
        {
            std::uniform_real_distribution<float> dist(0.0f, 1.0f);
            if (threadSafeRandom(dist) < style.chromaticism * 0.1f)
            {
                // Occasionally add chromatic neighbor
                std::uniform_int_distribution<int> neighbor(-1, 1);
                result.pitch += threadSafeRandom(neighbor);
            }
        }

        return result;
    }

    StyledMIDI::Note applyDynamicStyle(
        const StyledMIDI::Note& note,
        const MusicalStyle& style,
        float amount)
    {
        StyledMIDI::Note result = note;

        // Scale velocity to match style's dynamic range
        float center = 0.6f;  // Middle velocity
        float deviation = (note.velocity - center);
        float scaledDeviation = deviation * style.dynamicRange;

        result.velocity = center + scaledDeviation * amount +
                         (1.0f - amount) * deviation;
        result.velocity = juce::jlimit(0.0f, 1.0f, result.velocity);

        return result;
    }

    void applyStyleCoherence(StyledMIDI& result, const MusicalStyle& style)
    {
        // Apply accent patterns
        if (!style.accentPattern.empty())
        {
            for (size_t i = 0; i < result.notes.size(); ++i)
            {
                int patternIndex = static_cast<int>(result.notes[i].startBeat) %
                                  style.accentPattern.size();
                float accent = style.accentPattern[patternIndex];
                result.notes[i].velocity *= (0.8f + accent * 0.4f);
            }
        }
    }

    StyledMIDI neutralizeStyle(
        const std::vector<StyledMIDI::Note>& notes,
        const MusicalStyle& sourceStyle)
    {
        StyledMIDI result;

        for (const auto& note : notes)
        {
            StyledMIDI::Note neutralized = note;

            // Remove swing
            if (sourceStyle.swingAmount > 0)
            {
                // Inverse swing
                float beatFrac = std::fmod(note.startBeat, 1.0f);
                if (beatFrac > 0.5f && beatFrac < 0.7f)
                {
                    neutralized.startBeat -= (beatFrac - 0.5f) * sourceStyle.swingAmount;
                }
            }

            result.notes.push_back(neutralized);
        }

        return result;
    }

    //--------------------------------------------------------------------------
    // Style Detection
    //--------------------------------------------------------------------------

    float detectSwing(const std::vector<StyledMIDI::Note>& notes)
    {
        if (notes.size() < 4)
            return 0.0f;

        // Measure timing deviation of off-beats
        float totalDeviation = 0.0f;
        int offbeatCount = 0;

        for (const auto& note : notes)
        {
            float beatFrac = std::fmod(note.startBeat, 1.0f);
            if (beatFrac > 0.4f && beatFrac < 0.7f)
            {
                // This is an off-beat note
                float deviation = beatFrac - 0.5f;
                totalDeviation += std::abs(deviation);
                offbeatCount++;
            }
        }

        return offbeatCount > 0 ? (totalDeviation / offbeatCount) * 4.0f : 0.0f;
    }

    float detectSyncopation(const std::vector<StyledMIDI::Note>& notes)
    {
        if (notes.empty())
            return 0.0f;

        int syncopatedNotes = 0;

        for (const auto& note : notes)
        {
            float beatFrac = std::fmod(note.startBeat, 1.0f);
            // Note is syncopated if it's not on a strong beat (0, 0.5)
            if (std::abs(beatFrac - 0.0f) > 0.1f &&
                std::abs(beatFrac - 0.5f) > 0.1f)
            {
                syncopatedNotes++;
            }
        }

        return static_cast<float>(syncopatedNotes) / notes.size();
    }

    float detectDynamicRange(const std::vector<StyledMIDI::Note>& notes)
    {
        if (notes.empty())
            return 0.0f;

        float minVel = 1.0f, maxVel = 0.0f;

        for (const auto& note : notes)
        {
            minVel = std::min(minVel, note.velocity);
            maxVel = std::max(maxVel, note.velocity);
        }

        return maxVel - minVel;
    }

    std::vector<int> detectPreferredIntervals(const std::vector<StyledMIDI::Note>& notes)
    {
        std::map<int, int> intervalCounts;

        for (size_t i = 1; i < notes.size(); ++i)
        {
            int interval = std::abs(notes[i].pitch - notes[i-1].pitch) % 12;
            intervalCounts[interval]++;
        }

        // Sort by frequency
        std::vector<std::pair<int, int>> sorted(intervalCounts.begin(), intervalCounts.end());
        std::sort(sorted.begin(), sorted.end(),
                 [](const auto& a, const auto& b) { return a.second > b.second; });

        std::vector<int> preferred;
        for (size_t i = 0; i < std::min(size_t(5), sorted.size()); ++i)
        {
            preferred.push_back(sorted[i].first);
        }

        return preferred;
    }

    float detectChromaticism(const std::vector<StyledMIDI::Note>& notes)
    {
        if (notes.size() < 2)
            return 0.0f;

        int chromaticMoves = 0;

        for (size_t i = 1; i < notes.size(); ++i)
        {
            int interval = std::abs(notes[i].pitch - notes[i-1].pitch);
            if (interval == 1)  // Semitone
                chromaticMoves++;
        }

        return static_cast<float>(chromaticMoves) / (notes.size() - 1);
    }

    float detectGrooveTightness(const std::vector<StyledMIDI::Note>& notes)
    {
        if (notes.empty())
            return 1.0f;

        float totalDeviation = 0.0f;

        for (const auto& note : notes)
        {
            // Distance from nearest grid position (sixteenth note)
            float gridPos = std::round(note.startBeat * 4.0f) / 4.0f;
            float deviation = std::abs(note.startBeat - gridPos);
            totalDeviation += deviation;
        }

        float avgDeviation = totalDeviation / notes.size();
        return 1.0f - std::min(1.0f, avgDeviation * 8.0f);
    }

    //--------------------------------------------------------------------------
    // Helpers
    //--------------------------------------------------------------------------

    float calculateStyleMatch(const StyledMIDI& result, const MusicalStyle& target)
    {
        // Analyze the resulting style and compare to target
        MusicalStyle resultStyle = analyzeStyle(result.notes);
        return measureStyleSimilarity(resultStyle, target);
    }

    juce::String generateDescription(const StyledMIDI& result, const MusicalStyle& style)
    {
        juce::String desc = "Applied '" + style.name + "' style";

        if (result.params.styleStrength < 0.5f)
            desc += " subtly";
        else if (result.params.styleStrength > 0.8f)
            desc += " strongly";

        desc += " to " + juce::String(result.notes.size()) + " notes";

        return desc;
    }
};

} // namespace AI
} // namespace Echoelmusic
