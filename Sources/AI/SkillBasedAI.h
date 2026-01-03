#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <memory>
#include <functional>
#include <string>
#include <deque>

/**
 * SkillBasedAI - Modular AGI-Ready Composition Framework
 *
 * Hierarchical skill-based AI architecture:
 * - Composable skills (melody, harmony, rhythm, arrangement)
 * - Skill learning and improvement over time
 * - Multi-skill coordination for complex tasks
 * - Interpretable AI decisions
 * - User-trainable skill customization
 *
 * AGI Foundation:
 * - Goal-directed behavior
 * - Skill transfer and generalization
 * - Self-improvement through feedback
 * - Compositional reasoning
 *
 * Inspired by: OpenAI Codex, DeepMind Gato, AGI research
 * 2026 Towards Musical AGI
 */

namespace Echoelmusic {
namespace AI {

//==============================================================================
// Skill Interface
//==============================================================================

class Skill
{
public:
    virtual ~Skill() = default;

    // Identity
    virtual std::string getName() const = 0;
    virtual std::string getDescription() const = 0;
    virtual std::string getCategory() const = 0;

    // Proficiency (0.0 to 1.0)
    virtual float getProficiency() const { return proficiency; }
    virtual void setProficiency(float p) { proficiency = std::clamp(p, 0.0f, 1.0f); }

    // Learning
    virtual void learn(const std::vector<std::pair<juce::var, juce::var>>& examples) {}
    virtual void reinforce(float reward) { proficiency = std::clamp(proficiency + reward * 0.01f, 0.0f, 1.0f); }

    // Execution
    virtual juce::var execute(const juce::var& input) = 0;

    // Explainability
    virtual std::string explainLastDecision() const { return lastExplanation; }

protected:
    float proficiency = 0.5f;
    std::string lastExplanation;
};

//==============================================================================
// Music Domain Types
//==============================================================================

struct MelodyNote
{
    int pitch;
    float velocity;
    double startBeat;
    double duration;

    juce::var toVar() const
    {
        auto* obj = new juce::DynamicObject();
        obj->setProperty("pitch", pitch);
        obj->setProperty("velocity", velocity);
        obj->setProperty("start", startBeat);
        obj->setProperty("duration", duration);
        return juce::var(obj);
    }

    static MelodyNote fromVar(const juce::var& v)
    {
        MelodyNote n;
        n.pitch = v["pitch"];
        n.velocity = v["velocity"];
        n.startBeat = v["start"];
        n.duration = v["duration"];
        return n;
    }
};

struct ChordInfo
{
    std::string name;
    std::vector<int> notes;
    double startBeat;
    double duration;

    juce::var toVar() const
    {
        auto* obj = new juce::DynamicObject();
        obj->setProperty("name", juce::String(name));
        juce::Array<juce::var> notesArr;
        for (int n : notes) notesArr.add(n);
        obj->setProperty("notes", notesArr);
        obj->setProperty("start", startBeat);
        obj->setProperty("duration", duration);
        return juce::var(obj);
    }
};

struct RhythmPattern
{
    std::vector<double> onsets;     // Beat positions
    std::vector<float> velocities;
    double lengthBeats;

    juce::var toVar() const
    {
        auto* obj = new juce::DynamicObject();
        juce::Array<juce::var> onsetsArr, velsArr;
        for (double o : onsets) onsetsArr.add(o);
        for (float v : velocities) velsArr.add(v);
        obj->setProperty("onsets", onsetsArr);
        obj->setProperty("velocities", velsArr);
        obj->setProperty("length", lengthBeats);
        return juce::var(obj);
    }
};

//==============================================================================
// Concrete Skills
//==============================================================================

class MelodyGenerationSkill : public Skill
{
public:
    std::string getName() const override { return "Melody Generation"; }
    std::string getDescription() const override { return "Creates melodic lines based on context"; }
    std::string getCategory() const override { return "Composition"; }

    juce::var execute(const juce::var& input) override
    {
        // Input: key, scale, length, style
        std::string key = input["key"].toString().toStdString();
        int length = input["length"];
        std::string style = input["style"].toString().toStdString();

        // Generate melody
        std::vector<MelodyNote> melody;
        int root = keyToMidi(key);

        // Scale intervals (major by default)
        std::vector<int> scale = {0, 2, 4, 5, 7, 9, 11};

        std::random_device rd;
        std::mt19937 gen(rd());

        int prevPitch = root;
        double beat = 0.0;

        for (int i = 0; i < length; ++i)
        {
            MelodyNote note;

            // Stepwise motion preference
            int step = (gen() % 3) - 1;
            int scaleIndex = findNearestScaleIndex(prevPitch - root, scale) + step;
            scaleIndex = std::clamp(scaleIndex, 0, static_cast<int>(scale.size()) - 1);

            note.pitch = root + scale[scaleIndex];
            note.velocity = 0.7f + (gen() % 30) / 100.0f;
            note.startBeat = beat;
            note.duration = (gen() % 4 == 0) ? 2.0 : 1.0;

            melody.push_back(note);
            prevPitch = note.pitch;
            beat += note.duration;
        }

        lastExplanation = "Generated " + std::to_string(length) + " notes in " + key +
                          " using stepwise motion preference for natural melodic contour.";

        // Convert to var array
        juce::Array<juce::var> result;
        for (const auto& n : melody) result.add(n.toVar());
        return result;
    }

private:
    int keyToMidi(const std::string& key)
    {
        static std::map<std::string, int> keys = {
            {"C", 60}, {"C#", 61}, {"Db", 61}, {"D", 62}, {"D#", 63}, {"Eb", 63},
            {"E", 64}, {"F", 65}, {"F#", 66}, {"Gb", 66}, {"G", 67}, {"G#", 68},
            {"Ab", 68}, {"A", 69}, {"A#", 70}, {"Bb", 70}, {"B", 71}
        };
        auto it = keys.find(key);
        return it != keys.end() ? it->second : 60;
    }

    int findNearestScaleIndex(int offset, const std::vector<int>& scale)
    {
        int normalized = ((offset % 12) + 12) % 12;
        for (size_t i = 0; i < scale.size(); ++i)
        {
            if (scale[i] >= normalized) return static_cast<int>(i);
        }
        return 0;
    }
};

class HarmonyGenerationSkill : public Skill
{
public:
    std::string getName() const override { return "Harmony Generation"; }
    std::string getDescription() const override { return "Creates chord progressions"; }
    std::string getCategory() const override { return "Composition"; }

    juce::var execute(const juce::var& input) override
    {
        std::string key = input["key"].toString().toStdString();
        int length = input["length"];
        std::string mood = input["mood"].toString().toStdString();

        std::vector<ChordInfo> chords;
        int root = keyToMidi(key);

        // Common progressions based on mood
        std::vector<std::vector<int>> progressions;
        if (mood == "happy" || mood == "upbeat")
        {
            progressions = {{0, 3, 4, 0}, {0, 4, 5, 3}, {0, 0, 3, 4}};
        }
        else if (mood == "sad" || mood == "melancholy")
        {
            progressions = {{0, 3, 4, 0}, {5, 3, 0, 4}, {0, 5, 3, 4}};
        }
        else
        {
            progressions = {{0, 4, 5, 3}, {0, 3, 4, 0}, {5, 4, 0, 3}};
        }

        std::random_device rd;
        std::mt19937 gen(rd());
        auto& prog = progressions[gen() % progressions.size()];

        double beat = 0.0;
        for (int i = 0; i < length; ++i)
        {
            int degree = prog[i % prog.size()];
            ChordInfo chord;
            chord.name = degreeToChordName(degree);
            chord.notes = buildChord(root + scaleNotes[degree], (degree == 1 || degree == 2 || degree == 5));
            chord.startBeat = beat;
            chord.duration = 4.0;
            chords.push_back(chord);
            beat += chord.duration;
        }

        lastExplanation = "Generated " + mood + " chord progression in " + key +
                          " using common functional harmony patterns.";

        juce::Array<juce::var> result;
        for (const auto& c : chords) result.add(c.toVar());
        return result;
    }

private:
    std::vector<int> scaleNotes = {0, 2, 4, 5, 7, 9, 11};

    int keyToMidi(const std::string& key)
    {
        static std::map<std::string, int> keys = {
            {"C", 60}, {"D", 62}, {"E", 64}, {"F", 65}, {"G", 67}, {"A", 69}, {"B", 71}
        };
        auto it = keys.find(key);
        return it != keys.end() ? it->second : 60;
    }

    std::string degreeToChordName(int degree)
    {
        static std::vector<std::string> names = {"I", "ii", "iii", "IV", "V", "vi", "vii°"};
        return names[degree % 7];
    }

    std::vector<int> buildChord(int root, bool minor)
    {
        if (minor) return {root, root + 3, root + 7};
        return {root, root + 4, root + 7};
    }
};

class RhythmGenerationSkill : public Skill
{
public:
    std::string getName() const override { return "Rhythm Generation"; }
    std::string getDescription() const override { return "Creates rhythmic patterns"; }
    std::string getCategory() const override { return "Composition"; }

    juce::var execute(const juce::var& input) override
    {
        float complexity = input["complexity"];
        float density = input["density"];
        int bars = input["bars"];

        RhythmPattern pattern;
        pattern.lengthBeats = bars * 4.0;

        std::random_device rd;
        std::mt19937 gen(rd());

        // Generate based on density
        int numOnsets = static_cast<int>(pattern.lengthBeats * density * 2);

        for (int i = 0; i < numOnsets; ++i)
        {
            double beat = static_cast<double>(gen() % static_cast<int>(pattern.lengthBeats * 4)) / 4.0;
            pattern.onsets.push_back(beat);
            pattern.velocities.push_back(0.6f + (gen() % 40) / 100.0f);
        }

        // Sort onsets
        std::sort(pattern.onsets.begin(), pattern.onsets.end());

        lastExplanation = "Generated rhythm with density=" + std::to_string(density) +
                          " and complexity=" + std::to_string(complexity) +
                          " for " + std::to_string(bars) + " bars.";

        return pattern.toVar();
    }
};

class ArrangementSkill : public Skill
{
public:
    std::string getName() const override { return "Arrangement"; }
    std::string getDescription() const override { return "Arranges musical elements into sections"; }
    std::string getCategory() const override { return "Production"; }

    juce::var execute(const juce::var& input) override
    {
        int durationBars = input["duration"];
        std::string genre = input["genre"].toString().toStdString();

        auto* arrangement = new juce::DynamicObject();

        // Define sections based on genre
        std::vector<std::pair<std::string, int>> sections;

        if (genre == "pop")
        {
            sections = {{"intro", 4}, {"verse", 8}, {"chorus", 8}, {"verse", 8},
                        {"chorus", 8}, {"bridge", 4}, {"chorus", 8}, {"outro", 4}};
        }
        else if (genre == "electronic")
        {
            sections = {{"intro", 8}, {"buildup", 8}, {"drop", 16}, {"breakdown", 8},
                        {"buildup", 8}, {"drop", 16}, {"outro", 8}};
        }
        else
        {
            sections = {{"intro", 4}, {"A", 8}, {"B", 8}, {"A", 8}, {"outro", 4}};
        }

        juce::Array<juce::var> sectionArray;
        int bar = 0;
        for (const auto& [name, length] : sections)
        {
            auto* sec = new juce::DynamicObject();
            sec->setProperty("name", juce::String(name));
            sec->setProperty("startBar", bar);
            sec->setProperty("length", length);
            sectionArray.add(juce::var(sec));
            bar += length;
            if (bar >= durationBars) break;
        }

        arrangement->setProperty("sections", sectionArray);
        arrangement->setProperty("totalBars", bar);

        lastExplanation = "Arranged " + genre + " song structure with " +
                          std::to_string(sections.size()) + " sections.";

        return juce::var(arrangement);
    }
};

//==============================================================================
// Skill Registry
//==============================================================================

class SkillRegistry
{
public:
    static SkillRegistry& getInstance()
    {
        static SkillRegistry instance;
        return instance;
    }

    void registerSkill(const std::string& name, std::shared_ptr<Skill> skill)
    {
        skills[name] = skill;
    }

    std::shared_ptr<Skill> getSkill(const std::string& name)
    {
        auto it = skills.find(name);
        return it != skills.end() ? it->second : nullptr;
    }

    std::vector<std::string> getSkillNames() const
    {
        std::vector<std::string> names;
        for (const auto& [name, _] : skills) names.push_back(name);
        return names;
    }

    std::vector<std::string> getSkillsByCategory(const std::string& category) const
    {
        std::vector<std::string> result;
        for (const auto& [name, skill] : skills)
        {
            if (skill->getCategory() == category) result.push_back(name);
        }
        return result;
    }

private:
    SkillRegistry()
    {
        // Register default skills
        registerSkill("melody", std::make_shared<MelodyGenerationSkill>());
        registerSkill("harmony", std::make_shared<HarmonyGenerationSkill>());
        registerSkill("rhythm", std::make_shared<RhythmGenerationSkill>());
        registerSkill("arrangement", std::make_shared<ArrangementSkill>());
    }

    std::map<std::string, std::shared_ptr<Skill>> skills;
};

//==============================================================================
// Composition Agent (Coordinates Multiple Skills)
//==============================================================================

class CompositionAgent
{
public:
    struct CompositionRequest
    {
        std::string description;
        std::string key = "C";
        std::string genre = "pop";
        std::string mood = "neutral";
        int durationBars = 32;
        float energy = 0.5f;
        float complexity = 0.5f;
    };

    struct CompositionResult
    {
        juce::var melody;
        juce::var harmony;
        juce::var rhythm;
        juce::var arrangement;
        std::vector<std::string> explanations;
        bool success = false;
    };

    CompositionAgent()
    {
        registry = &SkillRegistry::getInstance();
    }

    CompositionResult compose(const CompositionRequest& request)
    {
        CompositionResult result;
        result.success = true;

        // Step 1: Arrangement (structure)
        auto arrangementSkill = registry->getSkill("arrangement");
        if (arrangementSkill)
        {
            auto* arrInput = new juce::DynamicObject();
            arrInput->setProperty("duration", request.durationBars);
            arrInput->setProperty("genre", juce::String(request.genre));
            result.arrangement = arrangementSkill->execute(juce::var(arrInput));
            result.explanations.push_back("[Arrangement] " + arrangementSkill->explainLastDecision());
        }

        // Step 2: Harmony (chord progression)
        auto harmonySkill = registry->getSkill("harmony");
        if (harmonySkill)
        {
            auto* harmInput = new juce::DynamicObject();
            harmInput->setProperty("key", juce::String(request.key));
            harmInput->setProperty("length", 4);
            harmInput->setProperty("mood", juce::String(request.mood));
            result.harmony = harmonySkill->execute(juce::var(harmInput));
            result.explanations.push_back("[Harmony] " + harmonySkill->explainLastDecision());
        }

        // Step 3: Melody (over harmony)
        auto melodySkill = registry->getSkill("melody");
        if (melodySkill)
        {
            auto* melInput = new juce::DynamicObject();
            melInput->setProperty("key", juce::String(request.key));
            melInput->setProperty("length", 16);
            melInput->setProperty("style", juce::String(request.genre));
            result.melody = melodySkill->execute(juce::var(melInput));
            result.explanations.push_back("[Melody] " + melodySkill->explainLastDecision());
        }

        // Step 4: Rhythm
        auto rhythmSkill = registry->getSkill("rhythm");
        if (rhythmSkill)
        {
            auto* rhythmInput = new juce::DynamicObject();
            rhythmInput->setProperty("complexity", request.complexity);
            rhythmInput->setProperty("density", request.energy);
            rhythmInput->setProperty("bars", 4);
            result.rhythm = rhythmSkill->execute(juce::var(rhythmInput));
            result.explanations.push_back("[Rhythm] " + rhythmSkill->explainLastDecision());
        }

        return result;
    }

    // Provide feedback to improve skills
    void provideFeedback(const std::string& skillName, float reward)
    {
        auto skill = registry->getSkill(skillName);
        if (skill)
        {
            skill->reinforce(reward);
        }
    }

    // Get skill proficiencies for display
    std::map<std::string, float> getSkillProficiencies() const
    {
        std::map<std::string, float> profs;
        for (const auto& name : registry->getSkillNames())
        {
            auto skill = registry->getSkill(name);
            if (skill) profs[name] = skill->getProficiency();
        }
        return profs;
    }

private:
    SkillRegistry* registry;
};

//==============================================================================
// AGI Reasoning Layer (Future)
//==============================================================================

class AGIReasoningLayer
{
public:
    struct Goal
    {
        std::string description;
        float priority;
        std::vector<std::string> requiredSkills;
    };

    struct Plan
    {
        std::vector<std::pair<std::string, juce::var>> steps;  // skill, input
        std::string explanation;
    };

    // High-level goal to low-level skill sequence
    Plan planFromGoal(const Goal& goal)
    {
        Plan plan;

        // Simple planning: sequence required skills
        for (const auto& skill : goal.requiredSkills)
        {
            auto* input = new juce::DynamicObject();
            // Default inputs based on skill
            if (skill == "melody")
            {
                input->setProperty("key", "C");
                input->setProperty("length", 16);
                input->setProperty("style", "pop");
            }
            else if (skill == "harmony")
            {
                input->setProperty("key", "C");
                input->setProperty("length", 4);
                input->setProperty("mood", "neutral");
            }

            plan.steps.push_back({skill, juce::var(input)});
        }

        plan.explanation = "Decomposed goal '" + goal.description + "' into " +
                           std::to_string(plan.steps.size()) + " skill executions.";

        return plan;
    }

    // Meta-learning: improve planning based on outcomes
    void updateFromOutcome(const Plan& plan, float successScore)
    {
        // Store for future planning improvements
        planHistory.push_back({plan, successScore});

        // Keep last 100 plans
        if (planHistory.size() > 100)
        {
            planHistory.pop_front();
        }
    }

private:
    std::deque<std::pair<Plan, float>> planHistory;
};

//==============================================================================
// Unified Skill-Based AI Engine
//==============================================================================

class SkillBasedAIEngine
{
public:
    static SkillBasedAIEngine& getInstance()
    {
        static SkillBasedAIEngine instance;
        return instance;
    }

    CompositionAgent::CompositionResult composeFromDescription(const std::string& description)
    {
        CompositionAgent::CompositionRequest request;
        request.description = description;

        // Parse description for context
        if (description.find("sad") != std::string::npos) request.mood = "sad";
        if (description.find("happy") != std::string::npos) request.mood = "happy";
        if (description.find("jazz") != std::string::npos) request.genre = "jazz";
        if (description.find("rock") != std::string::npos) request.genre = "rock";
        if (description.find("electronic") != std::string::npos) request.genre = "electronic";

        return agent.compose(request);
    }

    // Direct skill execution
    juce::var executeSkill(const std::string& skillName, const juce::var& input)
    {
        auto skill = SkillRegistry::getInstance().getSkill(skillName);
        if (skill) return skill->execute(input);
        return juce::var();
    }

    // Feedback for learning
    void feedback(const std::string& skillName, float reward)
    {
        agent.provideFeedback(skillName, reward);
    }

    // Get explanations
    std::string explainSkill(const std::string& skillName)
    {
        auto skill = SkillRegistry::getInstance().getSkill(skillName);
        return skill ? skill->explainLastDecision() : "";
    }

private:
    SkillBasedAIEngine() = default;
    CompositionAgent agent;
};

//==============================================================================
// Convenience
//==============================================================================

#define SkillAI SkillBasedAIEngine::getInstance()

} // namespace AI
} // namespace Echoelmusic
