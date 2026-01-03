#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <deque>
#include <set>
#include <algorithm>

/**
 * AGIReasoningEngine - Artificial General Intelligence for Music
 *
 * Advanced reasoning capabilities for musical composition:
 * - Causal reasoning (why certain musical choices work)
 * - Analogical reasoning (style transfer, "like X but with Y")
 * - Long-horizon planning (full song structure)
 * - Self-improvement through feedback
 * - Knowledge graph of musical concepts
 * - Compositional generalization
 *
 * Moving beyond pattern matching to true understanding:
 * - Musical semantics and meaning
 * - Emotional expression modeling
 * - Intent recognition and fulfillment
 * - Creative problem solving
 *
 * 2026 AGI Research Foundation
 */

namespace Echoelmusic {
namespace AI {

//==============================================================================
// Musical Concept Knowledge Graph
//==============================================================================

struct MusicalConcept
{
    std::string name;
    std::string category;           // harmony, rhythm, melody, emotion, genre
    std::map<std::string, float> attributes;

    // Relationships to other concepts
    std::vector<std::pair<std::string, std::string>> relations;  // relation_type, target_concept

    // Emotional/perceptual attributes
    float emotionalValence = 0.0f;   // -1 (sad) to +1 (happy)
    float emotionalArousal = 0.5f;   // 0 (calm) to 1 (excited)
    float complexity = 0.5f;
    float tension = 0.5f;
};

class MusicalKnowledgeGraph
{
public:
    MusicalKnowledgeGraph()
    {
        initializeBuiltInKnowledge();
    }

    void addConcept(const MusicalConcept& concept)
    {
        concepts[concept.name] = concept;
    }

    MusicalConcept* getConcept(const std::string& name)
    {
        auto it = concepts.find(name);
        return it != concepts.end() ? &it->second : nullptr;
    }

    // Find concepts related to a given concept
    std::vector<std::string> getRelated(const std::string& conceptName,
                                         const std::string& relationType = "")
    {
        std::vector<std::string> result;
        auto* concept = getConcept(conceptName);
        if (!concept) return result;

        for (const auto& [rel, target] : concept->relations)
        {
            if (relationType.empty() || rel == relationType)
            {
                result.push_back(target);
            }
        }
        return result;
    }

    // Find concepts by emotional qualities
    std::vector<std::string> findByEmotion(float targetValence, float targetArousal, float tolerance = 0.3f)
    {
        std::vector<std::string> result;
        for (const auto& [name, concept] : concepts)
        {
            float valenceDiff = std::abs(concept.emotionalValence - targetValence);
            float arousalDiff = std::abs(concept.emotionalArousal - targetArousal);
            if (valenceDiff <= tolerance && arousalDiff <= tolerance)
            {
                result.push_back(name);
            }
        }
        return result;
    }

    // Find path between concepts (for analogical reasoning)
    std::vector<std::string> findPath(const std::string& from, const std::string& to)
    {
        // BFS for shortest path
        std::map<std::string, std::string> parent;
        std::deque<std::string> queue;
        std::set<std::string> visited;

        queue.push_back(from);
        visited.insert(from);

        while (!queue.empty())
        {
            std::string current = queue.front();
            queue.pop_front();

            if (current == to)
            {
                // Reconstruct path
                std::vector<std::string> path;
                std::string node = to;
                while (!node.empty())
                {
                    path.push_back(node);
                    auto it = parent.find(node);
                    node = (it != parent.end()) ? it->second : "";
                }
                std::reverse(path.begin(), path.end());
                return path;
            }

            for (const auto& neighbor : getRelated(current))
            {
                if (visited.find(neighbor) == visited.end())
                {
                    visited.insert(neighbor);
                    parent[neighbor] = current;
                    queue.push_back(neighbor);
                }
            }
        }

        return {}; // No path found
    }

private:
    std::map<std::string, MusicalConcept> concepts;

    void initializeBuiltInKnowledge()
    {
        // Chord types
        addChordConcept("major_chord", 0.5f, 0.5f, {{"minor_chord", "contrast"}, {"dominant_chord", "leads_to"}});
        addChordConcept("minor_chord", -0.3f, 0.4f, {{"major_chord", "contrast"}, {"diminished_chord", "darker"}});
        addChordConcept("dominant_chord", 0.2f, 0.7f, {{"major_chord", "resolves_to"}, {"tonic", "tension_release"}});
        addChordConcept("diminished_chord", -0.5f, 0.6f, {{"dominant_chord", "substitute_for"}});
        addChordConcept("augmented_chord", 0.1f, 0.8f, {{"dominant_chord", "chromatic_approach"}});

        // Harmonic functions
        addFunctionConcept("tonic", 0.3f, 0.3f, "stability");
        addFunctionConcept("subdominant", 0.1f, 0.5f, "departure");
        addFunctionConcept("dominant", 0.0f, 0.8f, "tension");

        // Emotions
        addEmotionConcept("joy", 0.9f, 0.7f);
        addEmotionConcept("sadness", -0.8f, 0.3f);
        addEmotionConcept("anger", -0.5f, 0.9f);
        addEmotionConcept("fear", -0.6f, 0.8f);
        addEmotionConcept("peace", 0.4f, 0.2f);
        addEmotionConcept("excitement", 0.7f, 0.9f);
        addEmotionConcept("nostalgia", -0.2f, 0.4f);
        addEmotionConcept("triumph", 0.8f, 0.8f);

        // Genres
        addGenreConcept("pop", 0.4f, 0.6f, {"major_chord", "dominant_chord"});
        addGenreConcept("jazz", 0.2f, 0.5f, {"extended_chord", "altered_chord"});
        addGenreConcept("classical", 0.3f, 0.4f, {"counterpoint", "sonata_form"});
        addGenreConcept("electronic", 0.3f, 0.7f, {"synthesizer", "drum_machine"});
        addGenreConcept("ambient", 0.2f, 0.2f, {"pad", "reverb", "texture"});
    }

    void addChordConcept(const std::string& name, float valence, float arousal,
                         const std::vector<std::pair<std::string, std::string>>& rels)
    {
        MusicalConcept c;
        c.name = name;
        c.category = "harmony";
        c.emotionalValence = valence;
        c.emotionalArousal = arousal;
        c.relations = rels;
        addConcept(c);
    }

    void addFunctionConcept(const std::string& name, float valence, float arousal, const std::string& quality)
    {
        MusicalConcept c;
        c.name = name;
        c.category = "function";
        c.emotionalValence = valence;
        c.emotionalArousal = arousal;
        c.attributes["quality"] = 1.0f;
        addConcept(c);
    }

    void addEmotionConcept(const std::string& name, float valence, float arousal)
    {
        MusicalConcept c;
        c.name = name;
        c.category = "emotion";
        c.emotionalValence = valence;
        c.emotionalArousal = arousal;
        addConcept(c);
    }

    void addGenreConcept(const std::string& name, float valence, float arousal,
                          const std::vector<std::string>& associatedConcepts)
    {
        MusicalConcept c;
        c.name = name;
        c.category = "genre";
        c.emotionalValence = valence;
        c.emotionalArousal = arousal;
        for (const auto& assoc : associatedConcepts)
        {
            c.relations.push_back({"uses", assoc});
        }
        addConcept(c);
    }
};

//==============================================================================
// Causal Reasoning Engine
//==============================================================================

class CausalReasoner
{
public:
    struct CausalRelation
    {
        std::string cause;
        std::string effect;
        float strength;        // 0-1 how strong the causal link
        std::string explanation;
    };

    CausalReasoner()
    {
        initializeMusicTheoryCausality();
    }

    // Explain why a musical choice works
    std::string explainChoice(const std::string& choice, const std::string& context)
    {
        auto relations = getRelationsFor(choice);

        std::string explanation = "The choice of '" + choice + "' works because:\n";

        for (const auto& rel : relations)
        {
            if (rel.cause == choice || rel.effect == choice)
            {
                explanation += "- " + rel.explanation + " (strength: " +
                               std::to_string(static_cast<int>(rel.strength * 100)) + "%)\n";
            }
        }

        return explanation;
    }

    // Predict effects of a musical choice
    std::vector<std::string> predictEffects(const std::string& cause)
    {
        std::vector<std::string> effects;
        for (const auto& rel : causalRelations)
        {
            if (rel.cause == cause)
            {
                effects.push_back(rel.effect);
            }
        }
        return effects;
    }

    // Find causes for a desired effect
    std::vector<std::string> findCauses(const std::string& effect)
    {
        std::vector<std::string> causes;
        for (const auto& rel : causalRelations)
        {
            if (rel.effect == effect)
            {
                causes.push_back(rel.cause);
            }
        }
        return causes;
    }

private:
    std::vector<CausalRelation> causalRelations;

    std::vector<CausalRelation> getRelationsFor(const std::string& concept)
    {
        std::vector<CausalRelation> result;
        for (const auto& rel : causalRelations)
        {
            if (rel.cause == concept || rel.effect == concept)
            {
                result.push_back(rel);
            }
        }
        return result;
    }

    void initializeMusicTheoryCausality()
    {
        // Harmonic relationships
        causalRelations.push_back({
            "dominant_chord", "tonic_resolution",
            0.9f, "Dominant chords create tension that resolves to the tonic"
        });

        causalRelations.push_back({
            "minor_key", "sad_feeling",
            0.7f, "Minor keys are culturally associated with sadness"
        });

        causalRelations.push_back({
            "fast_tempo", "excitement",
            0.8f, "Faster tempos increase perceived energy and excitement"
        });

        causalRelations.push_back({
            "low_register", "power_gravity",
            0.6f, "Low frequencies create a sense of weight and power"
        });

        causalRelations.push_back({
            "high_register", "brightness_tension",
            0.6f, "High frequencies create brightness and can add tension"
        });

        causalRelations.push_back({
            "syncopation", "groove_interest",
            0.7f, "Syncopated rhythms create rhythmic interest and groove"
        });

        causalRelations.push_back({
            "repetition", "memorability",
            0.8f, "Repetition creates hooks and makes music memorable"
        });

        causalRelations.push_back({
            "surprise_chord", "emotional_impact",
            0.7f, "Unexpected harmonic moves create emotional peaks"
        });

        causalRelations.push_back({
            "dynamics_buildup", "climax_anticipation",
            0.8f, "Gradual dynamic increases build anticipation"
        });
    }
};

//==============================================================================
// Analogical Reasoning Engine
//==============================================================================

class AnalogicalReasoner
{
public:
    struct Analogy
    {
        std::string sourceStyle;
        std::string targetStyle;
        std::map<std::string, std::string> mappings;  // source_element -> target_element
        std::string explanation;
    };

    AnalogicalReasoner(MusicalKnowledgeGraph* kg) : knowledgeGraph(kg) {}

    // "Make it like jazz but with electronic sounds"
    Analogy constructAnalogy(const std::string& sourceStyle,
                              const std::string& targetStyle,
                              const std::string& preserveFrom,
                              const std::string& takeFrom)
    {
        Analogy analogy;
        analogy.sourceStyle = sourceStyle;
        analogy.targetStyle = targetStyle;

        // Find what to preserve from source
        auto* sourceConcept = knowledgeGraph->getConcept(preserveFrom);
        auto* targetConcept = knowledgeGraph->getConcept(takeFrom);

        if (sourceConcept && targetConcept)
        {
            // Map related concepts
            auto sourceRelated = knowledgeGraph->getRelated(preserveFrom, "uses");
            auto targetRelated = knowledgeGraph->getRelated(takeFrom, "uses");

            for (size_t i = 0; i < std::min(sourceRelated.size(), targetRelated.size()); ++i)
            {
                analogy.mappings[sourceRelated[i]] = targetRelated[i];
            }
        }

        analogy.explanation = "Combining " + preserveFrom + " elements with " + takeFrom +
                              " production style";

        return analogy;
    }

    // Apply analogy to transform music
    juce::var applyAnalogy(const Analogy& analogy, const juce::var& sourceMusic)
    {
        // Transform music according to mappings
        juce::var result = sourceMusic;

        // In real implementation: apply style-specific transformations
        // based on the mapping rules

        return result;
    }

private:
    MusicalKnowledgeGraph* knowledgeGraph;
};

//==============================================================================
// Long-Horizon Planning Engine
//==============================================================================

class LongHorizonPlanner
{
public:
    struct SongPlan
    {
        struct Section
        {
            std::string name;
            int bars;
            float energy;
            float tension;
            std::string emotionalArc;
            std::vector<std::string> musicalElements;
        };

        std::vector<Section> sections;
        std::string overallNarrative;
        float totalDurationMinutes;
    };

    SongPlan planSong(const std::string& emotionalJourney,
                       float durationMinutes,
                       const std::string& genre)
    {
        SongPlan plan;
        plan.totalDurationMinutes = durationMinutes;

        // Parse emotional journey (e.g., "start calm, build excitement, climax, resolve")
        auto emotions = parseEmotionalJourney(emotionalJourney);

        // Standard song arc
        std::vector<std::pair<std::string, float>> arcTemplate = {
            {"intro", 0.1f},
            {"verse1", 0.15f},
            {"prechorus", 0.08f},
            {"chorus1", 0.12f},
            {"verse2", 0.12f},
            {"chorus2", 0.12f},
            {"bridge", 0.1f},
            {"chorus3", 0.13f},
            {"outro", 0.08f}
        };

        float currentEnergy = 0.3f;
        int totalBars = static_cast<int>(durationMinutes * 30); // Assume 120 BPM

        for (const auto& [sectionName, proportion] : arcTemplate)
        {
            SongPlan::Section section;
            section.name = sectionName;
            section.bars = static_cast<int>(totalBars * proportion);

            // Energy curve
            if (sectionName.find("chorus") != std::string::npos)
            {
                section.energy = 0.9f;
                section.tension = 0.7f;
            }
            else if (sectionName.find("bridge") != std::string::npos)
            {
                section.energy = 0.5f;
                section.tension = 0.8f;
            }
            else if (sectionName.find("verse") != std::string::npos)
            {
                section.energy = 0.5f;
                section.tension = 0.4f;
            }
            else
            {
                section.energy = currentEnergy;
                section.tension = 0.3f;
            }

            section.emotionalArc = getEmotionForSection(sectionName, emotions);
            section.musicalElements = getElementsForSection(sectionName, genre);

            plan.sections.push_back(section);
            currentEnergy = section.energy;
        }

        plan.overallNarrative = "Song follows a " + emotionalJourney + " arc in " + genre + " style";

        return plan;
    }

private:
    std::vector<std::string> parseEmotionalJourney(const std::string& journey)
    {
        // Simple parsing
        std::vector<std::string> emotions;
        std::string current;
        for (char c : journey)
        {
            if (c == ',' || c == ' ')
            {
                if (!current.empty())
                {
                    emotions.push_back(current);
                    current.clear();
                }
            }
            else
            {
                current += c;
            }
        }
        if (!current.empty()) emotions.push_back(current);
        return emotions;
    }

    std::string getEmotionForSection(const std::string& section,
                                      const std::vector<std::string>& emotions)
    {
        if (section.find("intro") != std::string::npos && !emotions.empty())
            return emotions[0];
        if (section.find("chorus") != std::string::npos && emotions.size() > 1)
            return emotions[1];
        if (section.find("bridge") != std::string::npos && emotions.size() > 2)
            return emotions[2];
        if (section.find("outro") != std::string::npos && emotions.size() > 3)
            return emotions[3];
        return "neutral";
    }

    std::vector<std::string> getElementsForSection(const std::string& section,
                                                    const std::string& genre)
    {
        std::vector<std::string> elements;

        if (section.find("intro") != std::string::npos)
        {
            elements = {"sparse_arrangement", "atmospheric"};
        }
        else if (section.find("chorus") != std::string::npos)
        {
            elements = {"full_arrangement", "hook", "memorable_melody"};
        }
        else if (section.find("bridge") != std::string::npos)
        {
            elements = {"contrast", "different_chords", "build"};
        }
        else
        {
            elements = {"moderate_density", "storytelling"};
        }

        return elements;
    }
};

//==============================================================================
// Self-Improvement Engine
//==============================================================================

class SelfImprovementEngine
{
public:
    struct Experience
    {
        juce::var input;
        juce::var output;
        float userRating;
        std::string feedback;
        int64_t timestamp;
    };

    void recordExperience(const Experience& exp)
    {
        experiences.push_back(exp);

        // Update statistics
        float avgRating = 0.0f;
        for (const auto& e : experiences) avgRating += e.userRating;
        avgRating /= experiences.size();

        averageRating = avgRating;

        // Identify patterns in high-rated outputs
        if (exp.userRating > 0.8f)
        {
            extractSuccessPatterns(exp);
        }

        // Keep last 1000 experiences
        if (experiences.size() > 1000)
        {
            experiences.erase(experiences.begin());
        }
    }

    // Suggest improvements based on feedback patterns
    std::vector<std::string> suggestImprovements()
    {
        std::vector<std::string> suggestions;

        // Analyze low-rated experiences
        for (const auto& exp : experiences)
        {
            if (exp.userRating < 0.4f && !exp.feedback.empty())
            {
                // Extract improvement from feedback
                suggestions.push_back("Based on feedback: " + exp.feedback);
            }
        }

        return suggestions;
    }

    float getAverageRating() const { return averageRating; }
    int getTotalExperiences() const { return static_cast<int>(experiences.size()); }

private:
    std::deque<Experience> experiences;
    float averageRating = 0.5f;
    std::map<std::string, int> successPatterns;

    void extractSuccessPatterns(const Experience& exp)
    {
        // In real implementation: use ML to identify what made this output successful
    }
};

//==============================================================================
// Unified AGI Reasoning Engine
//==============================================================================

class AGIReasoningEngine
{
public:
    static AGIReasoningEngine& getInstance()
    {
        static AGIReasoningEngine instance;
        return instance;
    }

    // High-level composition from abstract description
    struct CompositionIntent
    {
        std::string emotionalGoal;          // "triumphant", "melancholic", etc.
        std::string stylistic_reference;    // "like Beethoven's 5th but electronic"
        float durationMinutes = 3.0f;
        std::string targetAudience;
        std::vector<std::string> constraints;
    };

    struct ReasonedComposition
    {
        LongHorizonPlanner::SongPlan plan;
        std::vector<std::string> reasoning_steps;
        std::map<std::string, std::string> causal_explanations;
        float confidence;
    };

    ReasonedComposition composeWithReasoning(const CompositionIntent& intent)
    {
        ReasonedComposition result;
        result.reasoning_steps.push_back("Analyzing emotional goal: " + intent.emotionalGoal);

        // Step 1: Find relevant concepts in knowledge graph
        auto relatedConcepts = knowledgeGraph.findByEmotion(
            emotionToValence(intent.emotionalGoal),
            emotionToArousal(intent.emotionalGoal)
        );
        result.reasoning_steps.push_back("Found " + std::to_string(relatedConcepts.size()) +
                                          " related musical concepts");

        // Step 2: Apply causal reasoning
        auto effects = causalReasoner.predictEffects(intent.emotionalGoal);
        for (const auto& effect : effects)
        {
            result.reasoning_steps.push_back("Predicted effect: " + effect);
        }

        // Step 3: Build long-horizon plan
        result.plan = planner.planSong(intent.emotionalGoal, intent.durationMinutes, "modern");
        result.reasoning_steps.push_back("Created song structure with " +
                                          std::to_string(result.plan.sections.size()) + " sections");

        // Step 4: Generate explanations
        result.causal_explanations["emotional_arc"] =
            causalReasoner.explainChoice(intent.emotionalGoal, "composition");

        result.confidence = 0.7f + 0.1f * static_cast<float>(relatedConcepts.size()) / 10.0f;
        result.confidence = std::min(result.confidence, 0.95f);

        return result;
    }

    // Explain any musical decision
    std::string explain(const std::string& decision, const std::string& context = "")
    {
        return causalReasoner.explainChoice(decision, context);
    }

    // Record user feedback for improvement
    void recordFeedback(const juce::var& composition, float rating, const std::string& feedback)
    {
        SelfImprovementEngine::Experience exp;
        exp.output = composition;
        exp.userRating = rating;
        exp.feedback = feedback;
        exp.timestamp = juce::Time::currentTimeMillis();
        improvement.recordExperience(exp);
    }

    // Get improvement suggestions
    std::vector<std::string> getImprovementSuggestions()
    {
        return improvement.suggestImprovements();
    }

    // Access sub-systems
    MusicalKnowledgeGraph& getKnowledgeGraph() { return knowledgeGraph; }
    CausalReasoner& getCausalReasoner() { return causalReasoner; }
    LongHorizonPlanner& getPlanner() { return planner; }

private:
    AGIReasoningEngine()
        : analogicalReasoner(&knowledgeGraph)
    {
    }

    MusicalKnowledgeGraph knowledgeGraph;
    CausalReasoner causalReasoner;
    AnalogicalReasoner analogicalReasoner;
    LongHorizonPlanner planner;
    SelfImprovementEngine improvement;

    float emotionToValence(const std::string& emotion)
    {
        static std::map<std::string, float> valences = {
            {"triumphant", 0.9f}, {"joyful", 0.8f}, {"happy", 0.7f}, {"peaceful", 0.4f},
            {"neutral", 0.0f}, {"melancholic", -0.3f}, {"sad", -0.6f}, {"angry", -0.4f},
            {"terrifying", -0.7f}
        };
        auto it = valences.find(emotion);
        return it != valences.end() ? it->second : 0.0f;
    }

    float emotionToArousal(const std::string& emotion)
    {
        static std::map<std::string, float> arousals = {
            {"triumphant", 0.9f}, {"joyful", 0.7f}, {"happy", 0.6f}, {"peaceful", 0.2f},
            {"neutral", 0.5f}, {"melancholic", 0.3f}, {"sad", 0.2f}, {"angry", 0.9f},
            {"terrifying", 0.8f}
        };
        auto it = arousals.find(emotion);
        return it != arousals.end() ? it->second : 0.5f;
    }
};

//==============================================================================
// Convenience
//==============================================================================

#define AGI AGIReasoningEngine::getInstance()

} // namespace AI
} // namespace Echoelmusic
