#pragma once

#include <JuceHeader.h>
#include "SpectrumMaster.h"
#include <string>
#include <vector>
#include <map>

/**
 * MasteringMentor - AI-Powered Teaching Assistant
 *
 * LEARNING PHILOSOPHY:
 * - Analyzes your mix in real-time
 * - EXPLAINS what's wrong (education)
 * - SHOWS why it's wrong (visual + data)
 * - SUGGESTS how to fix (guidance)
 * - YOU make the changes (learn-by-doing)
 * - Gives feedback on your changes ("Good! More..." / "Perfect!")
 *
 * NOT an auto-mastering tool - it's a TEACHER!
 */
class MasteringMentor
{
public:
    MasteringMentor();
    ~MasteringMentor();

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void analyze(const juce::AudioBuffer<float>& buffer);

    //==============================================================================
    // Teaching Feedback

    struct Suggestion
    {
        enum class Category
        {
            Frequency,      // EQ adjustments
            Dynamics,       // Compression/limiting
            Stereo,         // Stereo imaging
            Loudness,       // Overall level
            Phase,          // Phase issues
            General         // General mix advice
        };

        Category category;
        std::string title;           // "Too much low-end"
        std::string explanation;     // "Your mix has excessive energy at 60Hz..."
        std::string reasoning;       // "Professional Pop tracks have..."
        std::string actionStep;      // "Apply high-pass filter at 80Hz"
        std::string expectedResult;  // "This will tighten the low-end and..."

        float priority;              // 0.0-1.0 (how urgent)
        bool userAddressed;          // User made a change
        float improvement;           // How much better (-1.0 to 1.0)

        // Visual aid
        float targetFrequency;       // For EQ suggestions
        float targetAmount;          // Suggested dB change
    };

    std::vector<Suggestion> getSuggestions() const;

    //==============================================================================
    // Real-Time Feedback (as user makes changes)

    struct Feedback
    {
        enum class Type
        {
            Positive,       // "Good! Keep going..."
            Encouraging,    // "Almost there!"
            Warning,        // "That's too much..."
            Perfect         // "Perfect! This is professional level!"
        };

        Type type;
        std::string message;
        float confidence;    // 0.0-1.0 (how sure the AI is)
    };

    Feedback getRealtimeFeedback() const;
    void notifyUserChange(const std::string& parameterChanged, float newValue);

    //==============================================================================
    // Learning Mode

    enum class LearningLevel
    {
        Beginner,       // Detailed explanations, simple terms
        Intermediate,   // Standard explanations
        Advanced,       // Brief, technical suggestions
        Expert          // Minimal guidance
    };

    void setLearningLevel(LearningLevel level);
    LearningLevel getLearningLevel() const { return learningLevel; }

    //==============================================================================
    // Progress Tracking

    struct Progress
    {
        int sessionsCompleted;
        float averageScore;          // 0-100 (mastering quality)
        float improvementRate;       // % improvement over time

        std::map<std::string, int> conceptsLearned;  // "EQ", "Compression", etc.
        std::vector<std::string> achievements;       // "First -10 LUFS!", etc.
        std::vector<std::string> nextGoals;          // "Learn multiband compression"
    };

    Progress getUserProgress() const;
    void saveProgress(const juce::File& progressFile);
    void loadProgress(const juce::File& progressFile);

    //==============================================================================
    // Interactive Teaching

    struct Concept
    {
        std::string name;            // "LUFS", "Headroom", "Phase Correlation"
        std::string explanation;     // What it means
        std::string whyItMatters;    // Why you should care
        std::string howToUse;        // Practical application
        std::vector<std::string> examples;  // Real-world examples
    };

    Concept explainConcept(const std::string& conceptName) const;
    std::vector<std::string> getAvailableConcepts() const;

    //==============================================================================
    // Comparison with Reference

    void setReferenceTrack(const juce::File& audioFile);
    void clearReferenceTrack();

    struct Comparison
    {
        std::string aspect;          // "Low-end", "Highs", "Loudness", etc.
        float yourValue;
        float referenceValue;
        float difference;
        std::string recommendation;
    };

    std::vector<Comparison> compareWithReference() const;

    //==============================================================================
    // Genre-Specific Guidance

    void setTargetGenre(const std::string& genre);
    std::string getTargetGenre() const { return targetGenre; }

    struct GenreGuidance
    {
        std::string genre;
        float targetLUFS;
        float targetDynamicRange;
        std::vector<std::string> frequencyFocus;  // "Boost 10kHz", "Control 200Hz"
        std::vector<std::string> commonMistakes;  // "Too much bass", "Harsh highs"
        std::vector<std::string> proTips;         // Genre-specific tricks
    };

    GenreGuidance getGenreGuidance() const;

    //==============================================================================
    // Session Summary

    struct SessionSummary
    {
        float startingScore;
        float endingScore;
        float improvement;
        std::vector<std::string> changesYouMade;
        std::vector<std::string> whatYouLearned;
        std::vector<std::string> nextSteps;
        int minutesWorked;
    };

    void startSession();
    SessionSummary endSession();

private:
    //==============================================================================
    // State

    LearningLevel learningLevel = LearningLevel::Intermediate;
    std::string targetGenre = "Pop";

    Progress userProgress;
    bool sessionActive = false;
    float sessionStartScore = 0.0f;
    std::chrono::steady_clock::time_point sessionStartTime;

    // Analysis
    std::unique_ptr<SpectrumMaster> spectrumAnalyzer;
    std::vector<Suggestion> currentSuggestions;
    Feedback currentFeedback;

    // Reference track
    bool hasReference = false;
    std::vector<float> referenceSpectrum;
    float referenceLUFS = -10.0f;

    // User change tracking
    std::map<std::string, std::vector<float>> parameterHistory;

    //==============================================================================
    // Internal Analysis

    void generateSuggestions();
    void updateFeedback();
    float calculateMixScore() const;
    std::string generateEncouragement(float improvement) const;

    // Concept database
    std::map<std::string, Concept> conceptDatabase;
    void initializeConceptDatabase();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MasteringMentor)
};
