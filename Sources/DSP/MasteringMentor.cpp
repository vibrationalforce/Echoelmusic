#include "MasteringMentor.h"

MasteringMentor::MasteringMentor()
{
    spectrumAnalyzer = std::make_unique<SpectrumMaster>();
    initializeConceptDatabase();
}

MasteringMentor::~MasteringMentor() {}

void MasteringMentor::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    spectrumAnalyzer->prepare(sampleRate, samplesPerBlock, numChannels);
}

void MasteringMentor::analyze(const juce::AudioBuffer<float>& buffer)
{
    spectrumAnalyzer->process(buffer);
    generateSuggestions();
    updateFeedback();
}

//==============================================================================
// Suggestions

std::vector<MasteringMentor::Suggestion> MasteringMentor::getSuggestions() const
{
    return currentSuggestions;
}

void MasteringMentor::generateSuggestions()
{
    currentSuggestions.clear();

    // Get problems from spectrum analyzer
    auto problems = spectrumAnalyzer->detectProblems();

    for (const auto& problem : problems)
    {
        Suggestion suggestion;
        suggestion.priority = problem.severity;
        suggestion.targetFrequency = problem.frequencyHz;
        suggestion.userAddressed = false;
        suggestion.improvement = 0.0f;

        switch (problem.type)
        {
            case SpectrumMaster::ProblemType::TooMuchLowEnd:
                suggestion.category = Suggestion::Category::Frequency;
                suggestion.title = "Excessive Low-End Energy";
                suggestion.explanation = "Your mix has too much energy below 100Hz. This can make it sound muddy and uncontrolled.";
                suggestion.reasoning = "Professional " + targetGenre + " tracks typically have controlled low-end to maintain clarity.";
                suggestion.actionStep = "Apply a high-pass filter at 30-80Hz, or reduce 60Hz by 2-4dB with a wide Q (0.7-1.0).";
                suggestion.expectedResult = "This will tighten the low-end, improve clarity, and create more headroom for mastering.";
                suggestion.targetAmount = -3.0f;
                break;

            case SpectrumMaster::ProblemType::MuddyMidrange:
                suggestion.category = Suggestion::Category::Frequency;
                suggestion.title = "Muddy Midrange Buildup";
                suggestion.explanation = "The 200-500Hz range has excessive energy, making your mix sound 'boxy' or 'muddy'.";
                suggestion.reasoning = "This frequency range often accumulates from multiple instruments. Professional mixes keep this area clean.";
                suggestion.actionStep = "Reduce 250-400Hz by 2-3dB with a wide Q (1.0-1.5). Consider cutting individual instruments here first.";
                suggestion.expectedResult = "Your mix will sound clearer and more open. Vocals and lead instruments will stand out better.";
                suggestion.targetAmount = -2.5f;
                break;

            case SpectrumMaster::ProblemType::LackOfHighEnd:
                suggestion.category = Suggestion::Category::Frequency;
                suggestion.title = "Missing High-Frequency 'Air'";
                suggestion.explanation = "Your mix lacks presence in the 8-12kHz range, making it sound dull or closed-in.";
                suggestion.reasoning = "Professional " + targetGenre + " tracks have extended highs for sparkle and 'air'.";
                suggestion.actionStep = "Boost 10kHz by 2-4dB with a wide shelf filter (Q=0.7). Use subtle saturation for warmth.";
                suggestion.expectedResult = "Your mix will sound brighter, more open, and more polished. Cymbals and vocals will breathe.";
                suggestion.targetAmount = 3.0f;
                break;

            default:
                continue;
        }

        // Adjust explanation detail based on learning level
        if (learningLevel == LearningLevel::Beginner)
        {
            suggestion.explanation += "\n\nTIP: Q (or bandwidth) controls how wide the EQ curve is. Lower Q = wider, gentler. Higher Q = narrower, more surgical.";
        }
        else if (learningLevel == LearningLevel::Expert)
        {
            // Brief, technical
            suggestion.explanation = suggestion.actionStep;
            suggestion.reasoning = "";
        }

        currentSuggestions.push_back(suggestion);
    }

    // Loudness suggestions
    auto loudness = spectrumAnalyzer->getLoudnessAnalysis();
    if (std::abs(loudness.distanceFromTarget) > 2.0f)
    {
        Suggestion suggestion;
        suggestion.category = Suggestion::Category::Loudness;
        suggestion.title = "Loudness Target";
        suggestion.priority = 0.7f;
        suggestion.explanation = "Your mix is " + juce::String(std::abs(loudness.distanceFromTarget), 1).toStdString()
                               + " LU " + (loudness.distanceFromTarget > 0 ? "too loud" : "too quiet")
                               + " for " + targetGenre + ".";
        suggestion.reasoning = loudness.genreRecommendation.toStdString();
        suggestion.actionStep = (loudness.distanceFromTarget > 0)
            ? "Reduce output gain or use less compression. Aim for proper headroom (-6dB peak minimum)."
            : "Apply gentle limiting or compression to increase loudness. Don't sacrifice dynamics!";
        suggestion.expectedResult = "Your mix will match commercial loudness standards while maintaining dynamic interest.";
        currentSuggestions.push_back(suggestion);
    }
}

//==============================================================================
// Real-Time Feedback

MasteringMentor::Feedback MasteringMentor::getRealtimeFeedback() const
{
    return currentFeedback;
}

void MasteringMentor::notifyUserChange(const std::string& parameterChanged, float newValue)
{
    // Track parameter history
    parameterHistory[parameterChanged].push_back(newValue);

    // Generate feedback based on change
    updateFeedback();
}

void MasteringMentor::updateFeedback()
{
    float currentScore = calculateMixScore();

    if (sessionActive)
    {
        float improvement = currentScore - sessionStartScore;

        if (improvement > 5.0f)
        {
            currentFeedback.type = Feedback::Type::Perfect;
            currentFeedback.message = "Excellent! Your mix is sounding professional now!";
            currentFeedback.confidence = 0.9f;
        }
        else if (improvement > 2.0f)
        {
            currentFeedback.type = Feedback::Type::Positive;
            currentFeedback.message = "Good progress! Keep refining...";
            currentFeedback.confidence = 0.8f;
        }
        else if (improvement > 0.0f)
        {
            currentFeedback.type = Feedback::Type::Encouraging;
            currentFeedback.message = "You're on the right track. Small improvements add up!";
            currentFeedback.confidence = 0.7f;
        }
        else if (improvement < -2.0f)
        {
            currentFeedback.type = Feedback::Type::Warning;
            currentFeedback.message = "That change made things worse. Try undoing it and taking a different approach.";
            currentFeedback.confidence = 0.8f;
        }
        else
        {
            currentFeedback.type = Feedback::Type::Encouraging;
            currentFeedback.message = "Keep experimenting. Listen carefully to each change.";
            currentFeedback.confidence = 0.6f;
        }
    }
}

float MasteringMentor::calculateMixScore() const
{
    // Calculate overall mix quality (0-100)
    float score = 100.0f;

    auto problems = spectrumAnalyzer->detectProblems();
    for (const auto& problem : problems)
        score -= problem.severity * 10.0f;

    auto loudness = spectrumAnalyzer->getLoudnessAnalysis();
    score -= std::abs(loudness.distanceFromTarget) * 2.0f;

    return juce::jlimit(0.0f, 100.0f, score);
}

//==============================================================================
// Learning Level

void MasteringMentor::setLearningLevel(LearningLevel level)
{
    learningLevel = level;
}

//==============================================================================
// Progress Tracking

MasteringMentor::Progress MasteringMentor::getUserProgress() const
{
    return userProgress;
}

void MasteringMentor::saveProgress(const juce::File& progressFile)
{
    juce::ignoreUnused(progressFile);
    // Would serialize progress to JSON/XML
}

void MasteringMentor::loadProgress(const juce::File& progressFile)
{
    juce::ignoreUnused(progressFile);
    // Would deserialize progress from JSON/XML
}

//==============================================================================
// Concepts

void MasteringMentor::initializeConceptDatabase()
{
    // LUFS
    {
        Concept concept;
        concept.name = "LUFS";
        concept.explanation = "LUFS (Loudness Units Full Scale) measures perceived loudness, not just peak levels.";
        concept.whyItMatters = "Streaming platforms normalize to specific LUFS targets. Too loud = squashed. Too quiet = lost in the mix.";
        concept.howToUse = "Measure your integrated LUFS. Aim for: Pop (-8 to -10), Rock (-9 to -11), Classical (-18 to -20).";
        concept.examples = {"Spotify normalizes to -14 LUFS", "YouTube to -13 LUFS", "Apple Music to -16 LUFS"};
        conceptDatabase["LUFS"] = concept;
    }

    // Headroom
    {
        Concept concept;
        concept.name = "Headroom";
        concept.explanation = "Headroom is the difference between your peak level and 0dBFS (digital ceiling).";
        concept.whyItMatters = "Insufficient headroom causes clipping and distortion. Too much headroom wastes dynamic range.";
        concept.howToUse = "Leave 3-6dB of headroom before final limiting. This gives your limiter room to work transparently.";
        concept.examples = {"Pre-mastering: -6dB peak", "Post-limiting: -0.5dB to -1.0dB true peak"};
        conceptDatabase["Headroom"] = concept;
    }

    // Phase Correlation
    {
        Concept concept;
        concept.name = "Phase Correlation";
        concept.explanation = "Phase correlation measures how left and right channels relate. +1 = perfect correlation, -1 = opposite phase.";
        concept.whyItMatters = "Negative correlation causes cancellation when summed to mono. Many playback systems are mono!";
        concept.howToUse = "Keep correlation above +0.5 for most material. Use correlation meter to check mono compatibility.";
        concept.examples = {"Mono = +1.0", "Wide stereo = +0.3 to +0.7", "Phase problems = negative values"};
        conceptDatabase["Phase Correlation"] = concept;
    }
}

MasteringMentor::Concept MasteringMentor::explainConcept(const std::string& conceptName) const
{
    auto it = conceptDatabase.find(conceptName);
    if (it != conceptDatabase.end())
        return it->second;

    // Return empty concept if not found
    Concept empty;
    empty.name = conceptName;
    empty.explanation = "Concept not found in database.";
    return empty;
}

std::vector<std::string> MasteringMentor::getAvailableConcepts() const
{
    std::vector<std::string> concepts;
    for (const auto& [name, concept] : conceptDatabase)
        concepts.push_back(name);
    return concepts;
}

//==============================================================================
// Reference Comparison

void MasteringMentor::setReferenceTrack(const juce::File& audioFile)
{
    juce::ignoreUnused(audioFile);
    // Would load and analyze reference track
    hasReference = true;
}

void MasteringMentor::clearReferenceTrack()
{
    hasReference = false;
    referenceSpectrum.clear();
}

std::vector<MasteringMentor::Comparison> MasteringMentor::compareWithReference() const
{
    std::vector<Comparison> comparisons;

    if (!hasReference)
        return comparisons;

    // Example comparisons
    {
        Comparison comp;
        comp.aspect = "Low-End (60Hz)";
        comp.yourValue = -15.0f;
        comp.referenceValue = -18.0f;
        comp.difference = 3.0f;
        comp.recommendation = "Reduce low-end by 3dB to match reference";
        comparisons.push_back(comp);
    }

    return comparisons;
}

//==============================================================================
// Genre Guidance

void MasteringMentor::setTargetGenre(const std::string& genre)
{
    targetGenre = genre;
    spectrumAnalyzer->setGenre(genre);
}

MasteringMentor::GenreGuidance MasteringMentor::getGenreGuidance() const
{
    GenreGuidance guidance;
    guidance.genre = targetGenre;

    if (targetGenre == "Pop")
    {
        guidance.targetLUFS = -9.0f;
        guidance.targetDynamicRange = 8.0f;
        guidance.frequencyFocus = {
            "Control low-end at 30-80Hz (high-pass or reduce)",
            "Keep midrange clean (reduce 200-500Hz if muddy)",
            "Boost 'air' at 10-12kHz for sparkle",
            "Ensure vocal clarity at 2-5kHz"
        };
        guidance.commonMistakes = {
            "Too much bass (sounds muddy on small speakers)",
            "Harsh highs (listener fatigue)",
            "Over-compression (no dynamics)",
            "Ignoring mono compatibility"
        };
        guidance.proTips = {
            "Reference commercial Pop tracks constantly",
            "Use parallel compression for punch without losing dynamics",
            "Subtle saturation adds warmth and glue",
            "Leave headroom for streaming normalization"
        };
    }
    else if (targetGenre == "Classical")
    {
        guidance.targetLUFS = -19.0f;
        guidance.targetDynamicRange = 18.0f;
        guidance.frequencyFocus = {
            "Natural, uncolored frequency response",
            "Preserve room ambience and space",
            "Gentle high-frequency extension",
            "Minimal processing"
        };
        guidance.commonMistakes = {
            "Over-compression (kills dynamics!)",
            "Excessive EQ (sounds unnatural)",
            "Too loud (defeats the purpose)",
            "Removing room sound"
        };
        guidance.proTips = {
            "Aim for -18 to -20 LUFS for dynamic range",
            "Use minimal limiting, if any",
            "Preserve transients and micro-dynamics",
            "Reference live recordings"
        };
    }

    return guidance;
}

//==============================================================================
// Session

void MasteringMentor::startSession()
{
    sessionActive = true;
    sessionStartScore = calculateMixScore();
    sessionStartTime = std::chrono::steady_clock::now();
    parameterHistory.clear();
}

MasteringMentor::SessionSummary MasteringMentor::endSession()
{
    SessionSummary summary;
    summary.startingScore = sessionStartScore;
    summary.endingScore = calculateMixScore();
    summary.improvement = summary.endingScore - summary.startingScore;

    auto endTime = std::chrono::steady_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::minutes>(endTime - sessionStartTime);
    summary.minutesWorked = static_cast<int>(duration.count());

    // Track changes made
    for (const auto& [param, values] : parameterHistory)
        summary.changesYouMade.push_back(param + " adjusted " + juce::String(static_cast<int>(values.size())).toStdString() + " times");

    // What you learned
    if (summary.improvement > 5.0f)
        summary.whatYouLearned.push_back("Significant improvement in mix quality!");

    // Next steps
    if (currentSuggestions.empty())
        summary.nextSteps.push_back("Your mix sounds professional. Try comparing with reference tracks!");
    else
        summary.nextSteps.push_back("Continue addressing remaining suggestions");

    sessionActive = false;
    return summary;
}
