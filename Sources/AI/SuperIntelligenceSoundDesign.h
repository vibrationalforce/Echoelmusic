#pragma once

#include <JuceHeader.h>
#include "../Core/DSPOptimizations.h"
#include <vector>
#include <map>
#include <memory>
#include <random>
#include <cmath>
#include <functional>

namespace Echoelmusic {
namespace AI {

//==============================================================================
// Sound Design Parameter Space
//==============================================================================
struct SoundDNA {
    // Timbral characteristics (0-1)
    float brightness = 0.5f;      // Dark <-> Bright
    float warmth = 0.5f;          // Cold <-> Warm
    float thickness = 0.5f;       // Thin <-> Thick
    float clarity = 0.5f;         // Muddy <-> Clear
    float aggression = 0.5f;      // Soft <-> Aggressive
    float organic = 0.5f;         // Synthetic <-> Organic
    float movement = 0.5f;        // Static <-> Evolving
    float complexity = 0.5f;      // Simple <-> Complex
    float space = 0.5f;           // Dry <-> Spacious
    float presence = 0.5f;        // Background <-> Upfront

    // Envelope characteristics
    float attack = 0.1f;
    float decay = 0.3f;
    float sustain = 0.7f;
    float release = 0.4f;

    // Spectral profile (octave bands)
    std::array<float, 10> spectralProfile = {
        0.3f, 0.5f, 0.7f, 0.8f, 0.7f, 0.6f, 0.5f, 0.4f, 0.3f, 0.2f
    };

    float distanceTo(const SoundDNA& other) const {
        // OPTIMIZATION: Direct multiplication instead of std::pow(x, 2) (~10x faster)
        float d0 = brightness - other.brightness;
        float d1 = warmth - other.warmth;
        float d2 = thickness - other.thickness;
        float d3 = clarity - other.clarity;
        float d4 = aggression - other.aggression;
        float d5 = organic - other.organic;
        float d6 = movement - other.movement;
        float d7 = complexity - other.complexity;
        float dist = d0*d0 + d1*d1 + d2*d2 + d3*d3 + d4*d4 + d5*d5 + d6*d6 + d7*d7;
        return Echoel::DSP::FastMath::fastSqrt(dist);
    }

    SoundDNA lerp(const SoundDNA& target, float t) const {
        SoundDNA result;
        result.brightness = brightness + (target.brightness - brightness) * t;
        result.warmth = warmth + (target.warmth - warmth) * t;
        result.thickness = thickness + (target.thickness - thickness) * t;
        result.clarity = clarity + (target.clarity - clarity) * t;
        result.aggression = aggression + (target.aggression - aggression) * t;
        result.organic = organic + (target.organic - organic) * t;
        result.movement = movement + (target.movement - movement) * t;
        result.complexity = complexity + (target.complexity - complexity) * t;
        result.space = space + (target.space - space) * t;
        result.presence = presence + (target.presence - presence) * t;

        result.attack = attack + (target.attack - attack) * t;
        result.decay = decay + (target.decay - decay) * t;
        result.sustain = sustain + (target.sustain - sustain) * t;
        result.release = release + (target.release - release) * t;

        for (int i = 0; i < 10; i++) {
            result.spectralProfile[i] = spectralProfile[i] +
                (target.spectralProfile[i] - spectralProfile[i]) * t;
        }
        return result;
    }
};

//==============================================================================
// Sound Design Presets Library
//==============================================================================
struct SoundPreset {
    juce::String name;
    juce::String category;
    juce::String description;
    SoundDNA dna;
    std::vector<juce::String> tags;

    // Synthesis parameters
    std::map<juce::String, float> parameters;
};

class SoundLibrary {
public:
    void addPreset(const SoundPreset& preset) {
        presets.push_back(preset);
    }

    std::vector<SoundPreset> searchByDNA(const SoundDNA& target, int maxResults = 10) {
        std::vector<std::pair<float, SoundPreset>> scored;

        for (const auto& preset : presets) {
            float distance = target.distanceTo(preset.dna);
            scored.push_back({distance, preset});
        }

        std::sort(scored.begin(), scored.end(),
            [](const auto& a, const auto& b) { return a.first < b.first; });

        std::vector<SoundPreset> results;
        for (int i = 0; i < std::min(maxResults, (int)scored.size()); i++) {
            results.push_back(scored[i].second);
        }
        return results;
    }

    std::vector<SoundPreset> searchByTags(const std::vector<juce::String>& tags) {
        std::vector<SoundPreset> results;
        for (const auto& preset : presets) {
            int matchCount = 0;
            for (const auto& tag : tags) {
                if (std::find(preset.tags.begin(), preset.tags.end(), tag) != preset.tags.end()) {
                    matchCount++;
                }
            }
            if (matchCount > 0) results.push_back(preset);
        }
        return results;
    }

    std::vector<SoundPreset> searchByCategory(const juce::String& category) {
        std::vector<SoundPreset> results;
        for (const auto& preset : presets) {
            if (preset.category == category) results.push_back(preset);
        }
        return results;
    }

private:
    std::vector<SoundPreset> presets;
};

//==============================================================================
// AI Sound Generator
//==============================================================================
struct GenerationParameters {
    SoundDNA targetDNA;
    juce::String style = "neutral";     // "analog", "digital", "hybrid", "organic"
    float randomness = 0.1f;            // 0-1, how much variation to add
    bool constrainToScale = true;
    int harmonicComplexity = 5;         // 1-10
};

class AISoundGenerator {
public:
    struct SynthPatch {
        // Oscillators
        int numOscillators = 2;
        std::array<float, 4> oscMix = {0.5f, 0.5f, 0.0f, 0.0f};
        std::array<int, 4> oscWaveform = {0, 1, 0, 0};  // 0=sine, 1=saw, 2=square, 3=tri, 4=noise
        std::array<float, 4> oscDetune = {0.0f, 0.1f, 0.0f, 0.0f};
        std::array<float, 4> oscPitch = {0.0f, 0.0f, 0.0f, 0.0f};  // Semitones

        // Filter
        float filterCutoff = 0.7f;
        float filterResonance = 0.2f;
        int filterType = 0;  // 0=LP, 1=HP, 2=BP, 3=Notch
        float filterEnvAmount = 0.3f;

        // Envelopes
        float ampAttack = 0.01f;
        float ampDecay = 0.2f;
        float ampSustain = 0.7f;
        float ampRelease = 0.3f;

        float filterAttack = 0.05f;
        float filterDecay = 0.3f;
        float filterSustain = 0.4f;
        float filterRelease = 0.4f;

        // Modulation
        float lfoRate = 2.0f;
        float lfoDepth = 0.3f;
        int lfoTarget = 0;  // 0=pitch, 1=filter, 2=amp

        // Effects
        float reverbMix = 0.2f;
        float delayMix = 0.1f;
        float chorusMix = 0.1f;
        float distortion = 0.0f;
    };

    SynthPatch generateFromDNA(const SoundDNA& dna, float randomness = 0.1f) {
        SynthPatch patch;

        // Map brightness to filter cutoff
        patch.filterCutoff = 0.3f + dna.brightness * 0.6f + randomVariation(randomness);

        // Map warmth to oscillator mix (more saw = warmer)
        if (dna.warmth > 0.5f) {
            patch.oscWaveform[0] = 1;  // Saw
            patch.oscWaveform[1] = 1;  // Saw
            patch.oscDetune[1] = 0.05f + dna.warmth * 0.1f;  // Detuning adds warmth
        } else {
            patch.oscWaveform[0] = 0;  // Sine
            patch.oscWaveform[1] = 3;  // Triangle
        }

        // Map thickness to number of oscillators and detuning
        patch.numOscillators = 2 + int(dna.thickness * 2);
        if (dna.thickness > 0.6f) {
            patch.oscMix[2] = 0.3f;
            patch.oscDetune[2] = -0.1f;
        }

        // Map aggression to distortion and resonance
        patch.distortion = dna.aggression * 0.5f;
        patch.filterResonance = 0.1f + dna.aggression * 0.5f;

        // Map complexity to modulation depth
        patch.lfoDepth = dna.complexity * 0.5f;
        patch.filterEnvAmount = dna.complexity * 0.6f;

        // Map movement to LFO rate
        patch.lfoRate = 0.5f + dna.movement * 8.0f;

        // Map space to reverb
        patch.reverbMix = dna.space * 0.6f;

        // Map envelope from DNA
        patch.ampAttack = dna.attack * 2.0f;
        patch.ampDecay = dna.decay * 1.0f;
        patch.ampSustain = dna.sustain;
        patch.ampRelease = dna.release * 2.0f;

        return patch;
    }

    SynthPatch mutate(const SynthPatch& original, float mutationStrength = 0.2f) {
        SynthPatch mutated = original;

        mutated.filterCutoff = clamp(original.filterCutoff + randomVariation(mutationStrength));
        mutated.filterResonance = clamp(original.filterResonance + randomVariation(mutationStrength * 0.5f));
        mutated.lfoRate = std::max(0.1f, original.lfoRate + randomVariation(mutationStrength * 2.0f));
        mutated.lfoDepth = clamp(original.lfoDepth + randomVariation(mutationStrength));

        for (int i = 0; i < 4; i++) {
            mutated.oscDetune[i] = original.oscDetune[i] + randomVariation(mutationStrength * 0.1f);
        }

        return mutated;
    }

    SynthPatch crossover(const SynthPatch& a, const SynthPatch& b, float blend = 0.5f) {
        SynthPatch child;

        child.filterCutoff = a.filterCutoff * (1 - blend) + b.filterCutoff * blend;
        child.filterResonance = a.filterResonance * (1 - blend) + b.filterResonance * blend;
        child.distortion = a.distortion * (1 - blend) + b.distortion * blend;

        // Random selection for discrete parameters
        child.numOscillators = (rng() % 2 == 0) ? a.numOscillators : b.numOscillators;
        for (int i = 0; i < 4; i++) {
            child.oscWaveform[i] = (rng() % 2 == 0) ? a.oscWaveform[i] : b.oscWaveform[i];
        }

        child.ampAttack = a.ampAttack * (1 - blend) + b.ampAttack * blend;
        child.ampDecay = a.ampDecay * (1 - blend) + b.ampDecay * blend;
        child.ampSustain = a.ampSustain * (1 - blend) + b.ampSustain * blend;
        child.ampRelease = a.ampRelease * (1 - blend) + b.ampRelease * blend;

        child.reverbMix = a.reverbMix * (1 - blend) + b.reverbMix * blend;
        child.delayMix = a.delayMix * (1 - blend) + b.delayMix * blend;

        return child;
    }

private:
    std::mt19937 rng{std::random_device{}()};

    float randomVariation(float amount) {
        std::uniform_real_distribution<float> dist(-amount, amount);
        return dist(rng);
    }

    float clamp(float value, float min = 0.0f, float max = 1.0f) {
        return std::max(min, std::min(max, value));
    }
};

//==============================================================================
// Sound Morphing Engine
//==============================================================================
class SoundMorphEngine {
public:
    void setSource(const SoundDNA& dna) { sourceDNA = dna; }
    void setTarget(const SoundDNA& dna) { targetDNA = dna; }

    SoundDNA morph(float position) {
        return sourceDNA.lerp(targetDNA, position);
    }

    // Multi-point morphing (for XY pads)
    SoundDNA morph2D(const SoundDNA& topLeft, const SoundDNA& topRight,
                     const SoundDNA& bottomLeft, const SoundDNA& bottomRight,
                     float x, float y) {
        SoundDNA top = topLeft.lerp(topRight, x);
        SoundDNA bottom = bottomLeft.lerp(bottomRight, x);
        return top.lerp(bottom, y);
    }

    // Circular morphing (for 4+ sources)
    SoundDNA morphCircular(const std::vector<SoundDNA>& sources, float angle) {
        if (sources.empty()) return SoundDNA();
        if (sources.size() == 1) return sources[0];

        float normalizedAngle = std::fmod(angle, 2.0f * M_PI);
        if (normalizedAngle < 0) normalizedAngle += 2.0f * M_PI;

        float segmentSize = (2.0f * M_PI) / sources.size();
        int sourceIndex = int(normalizedAngle / segmentSize);
        int nextIndex = (sourceIndex + 1) % sources.size();

        float segmentPosition = std::fmod(normalizedAngle, segmentSize) / segmentSize;

        return sources[sourceIndex].lerp(sources[nextIndex], segmentPosition);
    }

private:
    SoundDNA sourceDNA;
    SoundDNA targetDNA;
};

//==============================================================================
// Semantic Sound Description
//==============================================================================
class SemanticSoundEngine {
public:
    SoundDNA fromDescription(const juce::String& description) {
        SoundDNA dna;

        juce::String lower = description.toLowerCase();

        // Brightness keywords
        if (lower.contains("bright") || lower.contains("shiny") || lower.contains("crisp")) {
            dna.brightness = 0.8f;
        } else if (lower.contains("dark") || lower.contains("muted") || lower.contains("dull")) {
            dna.brightness = 0.2f;
        }

        // Warmth keywords
        if (lower.contains("warm") || lower.contains("analog") || lower.contains("vintage")) {
            dna.warmth = 0.8f;
        } else if (lower.contains("cold") || lower.contains("digital") || lower.contains("sterile")) {
            dna.warmth = 0.2f;
        }

        // Thickness keywords
        if (lower.contains("thick") || lower.contains("fat") || lower.contains("heavy") || lower.contains("massive")) {
            dna.thickness = 0.9f;
        } else if (lower.contains("thin") || lower.contains("light") || lower.contains("delicate")) {
            dna.thickness = 0.2f;
        }

        // Aggression keywords
        if (lower.contains("aggressive") || lower.contains("harsh") || lower.contains("distorted") || lower.contains("screaming")) {
            dna.aggression = 0.9f;
        } else if (lower.contains("soft") || lower.contains("gentle") || lower.contains("smooth")) {
            dna.aggression = 0.1f;
        }

        // Movement keywords
        if (lower.contains("evolving") || lower.contains("morphing") || lower.contains("alive") || lower.contains("animated")) {
            dna.movement = 0.8f;
        } else if (lower.contains("static") || lower.contains("stable") || lower.contains("steady")) {
            dna.movement = 0.2f;
        }

        // Complexity keywords
        if (lower.contains("complex") || lower.contains("rich") || lower.contains("layered")) {
            dna.complexity = 0.8f;
        } else if (lower.contains("simple") || lower.contains("pure") || lower.contains("clean")) {
            dna.complexity = 0.2f;
        }

        // Space keywords
        if (lower.contains("spacious") || lower.contains("ambient") || lower.contains("ethereal") || lower.contains("dreamy")) {
            dna.space = 0.8f;
        } else if (lower.contains("dry") || lower.contains("tight") || lower.contains("close")) {
            dna.space = 0.2f;
        }

        // Envelope keywords
        if (lower.contains("pluck") || lower.contains("stab") || lower.contains("percussive")) {
            dna.attack = 0.01f;
            dna.decay = 0.3f;
            dna.sustain = 0.0f;
        } else if (lower.contains("pad") || lower.contains("ambient") || lower.contains("slow")) {
            dna.attack = 0.5f;
            dna.sustain = 0.8f;
            dna.release = 0.8f;
        } else if (lower.contains("lead") || lower.contains("solo")) {
            dna.attack = 0.05f;
            dna.sustain = 0.7f;
        }

        // Organic keywords
        if (lower.contains("organic") || lower.contains("natural") || lower.contains("acoustic")) {
            dna.organic = 0.8f;
        } else if (lower.contains("synthetic") || lower.contains("electronic") || lower.contains("digital")) {
            dna.organic = 0.2f;
        }

        return dna;
    }

    juce::String toDescription(const SoundDNA& dna) {
        juce::StringArray descriptors;

        if (dna.brightness > 0.7f) descriptors.add("bright");
        else if (dna.brightness < 0.3f) descriptors.add("dark");

        if (dna.warmth > 0.7f) descriptors.add("warm");
        else if (dna.warmth < 0.3f) descriptors.add("cold");

        if (dna.thickness > 0.7f) descriptors.add("thick");
        else if (dna.thickness < 0.3f) descriptors.add("thin");

        if (dna.aggression > 0.7f) descriptors.add("aggressive");
        else if (dna.aggression < 0.3f) descriptors.add("soft");

        if (dna.movement > 0.7f) descriptors.add("evolving");
        else if (dna.movement < 0.3f) descriptors.add("static");

        if (dna.space > 0.7f) descriptors.add("spacious");
        else if (dna.space < 0.3f) descriptors.add("dry");

        return descriptors.joinIntoString(", ");
    }
};

//==============================================================================
// Intelligent Sound Suggestions
//==============================================================================
class SoundSuggestionEngine {
public:
    struct Suggestion {
        juce::String title;
        juce::String description;
        SoundDNA targetDNA;
        std::map<juce::String, float> parameterChanges;
        float confidence = 0.8f;
    };

    std::vector<Suggestion> analyzeAndSuggest(const SoundDNA& current,
                                               const juce::String& context) {
        std::vector<Suggestion> suggestions;

        // Analyze what could be improved
        if (context.contains("bass")) {
            if (current.thickness < 0.5f) {
                Suggestion s;
                s.title = "Increase Thickness";
                s.description = "Add more low-end weight for bass sounds";
                s.targetDNA = current;
                s.targetDNA.thickness = 0.8f;
                s.parameterChanges["lowShelfGain"] = 6.0f;
                suggestions.push_back(s);
            }
            if (current.brightness > 0.6f) {
                Suggestion s;
                s.title = "Reduce Brightness";
                s.description = "Roll off highs for a warmer bass";
                s.targetDNA = current;
                s.targetDNA.brightness = 0.3f;
                s.parameterChanges["filterCutoff"] = 0.4f;
                suggestions.push_back(s);
            }
        }

        if (context.contains("lead")) {
            if (current.presence < 0.6f) {
                Suggestion s;
                s.title = "Increase Presence";
                s.description = "Bring the lead forward in the mix";
                s.targetDNA = current;
                s.targetDNA.presence = 0.8f;
                s.targetDNA.brightness = std::min(1.0f, current.brightness + 0.2f);
                suggestions.push_back(s);
            }
        }

        if (context.contains("pad") || context.contains("ambient")) {
            if (current.movement < 0.5f) {
                Suggestion s;
                s.title = "Add Movement";
                s.description = "Add modulation for evolving texture";
                s.targetDNA = current;
                s.targetDNA.movement = 0.7f;
                s.parameterChanges["lfoDepth"] = 0.4f;
                suggestions.push_back(s);
            }
            if (current.space < 0.5f) {
                Suggestion s;
                s.title = "Add Space";
                s.description = "Increase reverb for ambient atmosphere";
                s.targetDNA = current;
                s.targetDNA.space = 0.7f;
                s.parameterChanges["reverbMix"] = 0.5f;
                suggestions.push_back(s);
            }
        }

        return suggestions;
    }

    std::vector<SoundDNA> suggestVariations(const SoundDNA& current, int count = 4) {
        std::vector<SoundDNA> variations;
        std::mt19937 rng{std::random_device{}()};
        std::uniform_real_distribution<float> dist(-0.15f, 0.15f);

        for (int i = 0; i < count; i++) {
            SoundDNA variation = current;
            variation.brightness = clamp(current.brightness + dist(rng));
            variation.warmth = clamp(current.warmth + dist(rng));
            variation.thickness = clamp(current.thickness + dist(rng));
            variation.movement = clamp(current.movement + dist(rng));
            variations.push_back(variation);
        }

        return variations;
    }

private:
    float clamp(float value) {
        return std::max(0.0f, std::min(1.0f, value));
    }
};

//==============================================================================
// Super Intelligence Sound Design - Main Interface
//==============================================================================
class SuperIntelligenceSoundDesign {
public:
    SuperIntelligenceSoundDesign() {
        loadDefaultPresets();
    }

    // Generate sound from text description
    AISoundGenerator::SynthPatch generateFromText(const juce::String& description) {
        SoundDNA dna = semanticEngine.fromDescription(description);
        return generator.generateFromDNA(dna, 0.1f);
    }

    // Generate sound from DNA
    AISoundGenerator::SynthPatch generateFromDNA(const SoundDNA& dna) {
        return generator.generateFromDNA(dna, 0.05f);
    }

    // Morph between sounds
    SoundDNA morphSounds(float position) {
        return morphEngine.morph(position);
    }

    void setMorphSource(const SoundDNA& dna) { morphEngine.setSource(dna); }
    void setMorphTarget(const SoundDNA& dna) { morphEngine.setTarget(dna); }

    // 2D morph pad
    SoundDNA morph2D(float x, float y) {
        return morphEngine.morph2D(morphCorners[0], morphCorners[1],
                                   morphCorners[2], morphCorners[3], x, y);
    }

    void setMorphCorner(int index, const SoundDNA& dna) {
        if (index >= 0 && index < 4) morphCorners[index] = dna;
    }

    // Search library
    std::vector<SoundPreset> searchByDescription(const juce::String& description) {
        SoundDNA targetDNA = semanticEngine.fromDescription(description);
        return library.searchByDNA(targetDNA, 10);
    }

    // AI suggestions
    std::vector<SoundSuggestionEngine::Suggestion> getSuggestions(
        const SoundDNA& current, const juce::String& context) {
        return suggestionEngine.analyzeAndSuggest(current, context);
    }

    // Genetic evolution
    AISoundGenerator::SynthPatch evolve(const AISoundGenerator::SynthPatch& patch,
                                        float mutationStrength = 0.2f) {
        return generator.mutate(patch, mutationStrength);
    }

    AISoundGenerator::SynthPatch breed(const AISoundGenerator::SynthPatch& a,
                                       const AISoundGenerator::SynthPatch& b) {
        return generator.crossover(a, b, 0.5f);
    }

    // Describe current sound
    juce::String describeSound(const SoundDNA& dna) {
        return semanticEngine.toDescription(dna);
    }

    // Access components
    SoundLibrary& getLibrary() { return library; }
    SemanticSoundEngine& getSemanticEngine() { return semanticEngine; }

    // Callbacks for visual coupling
    std::function<void(const SoundDNA&)> onDNAChanged;
    std::function<void(const AISoundGenerator::SynthPatch&)> onPatchGenerated;

private:
    SoundLibrary library;
    AISoundGenerator generator;
    SoundMorphEngine morphEngine;
    SemanticSoundEngine semanticEngine;
    SoundSuggestionEngine suggestionEngine;

    std::array<SoundDNA, 4> morphCorners;

    void loadDefaultPresets() {
        // Bass presets
        {
            SoundPreset preset;
            preset.name = "Analog Sub";
            preset.category = "Bass";
            preset.tags = {"sub", "analog", "warm", "deep"};
            preset.dna.brightness = 0.2f;
            preset.dna.warmth = 0.8f;
            preset.dna.thickness = 0.9f;
            library.addPreset(preset);
        }
        {
            SoundPreset preset;
            preset.name = "Reese Bass";
            preset.category = "Bass";
            preset.tags = {"reese", "dnb", "detuned", "aggressive"};
            preset.dna.brightness = 0.4f;
            preset.dna.warmth = 0.6f;
            preset.dna.thickness = 0.95f;
            preset.dna.movement = 0.7f;
            preset.dna.aggression = 0.6f;
            library.addPreset(preset);
        }

        // Pad presets
        {
            SoundPreset preset;
            preset.name = "Ethereal Pad";
            preset.category = "Pad";
            preset.tags = {"ethereal", "ambient", "spacious", "dreamy"};
            preset.dna.brightness = 0.5f;
            preset.dna.warmth = 0.6f;
            preset.dna.space = 0.9f;
            preset.dna.movement = 0.6f;
            preset.dna.attack = 0.6f;
            library.addPreset(preset);
        }

        // Lead presets
        {
            SoundPreset preset;
            preset.name = "Screaming Lead";
            preset.category = "Lead";
            preset.tags = {"lead", "aggressive", "bright", "cutting"};
            preset.dna.brightness = 0.85f;
            preset.dna.aggression = 0.8f;
            preset.dna.presence = 0.9f;
            library.addPreset(preset);
        }
    }
};

} // namespace AI
} // namespace Echoelmusic
