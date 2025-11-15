#include "ChordSense.h"
#include <cmath>
#include <algorithm>

//==============================================================================
// ChordSense Implementation

ChordSense::ChordSense()
    : forwardFFT(fftOrder),
      window(fftSize, juce::dsp::WindowingFunction<float>::hann)
{
    initializeChordTemplates();
    initializeProgressionDatabase();
    reset();
}

ChordSense::~ChordSense() {}

void ChordSense::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    currentSampleRate = sampleRate;
    currentNumChannels = numChannels;
}

void ChordSense::reset()
{
    pitchClassProfile.fill(0.0f);
    smoothedPitchClassProfile.fill(0.0f);
    currentChord = Chord();
    chordHistory.clear();
    chordTimeline.clear();
    currentTimeSeconds = 0.0;
}

void ChordSense::process(const juce::AudioBuffer<float>& buffer)
{
    performFFTAnalysis(buffer);
    calculatePitchClassProfile();
    detectChord();
    detectKey();

    currentTimeSeconds += buffer.getNumSamples() / currentSampleRate;
}

//==============================================================================
// Chord Detection

ChordSense::Chord ChordSense::getCurrentChord() const
{
    return currentChord;
}

std::vector<ChordSense::Chord> ChordSense::getChordHistory(int count) const
{
    int numChords = juce::jmin(count, static_cast<int>(chordHistory.size()));
    std::vector<Chord> history;

    for (int i = chordHistory.size() - numChords; i < static_cast<int>(chordHistory.size()); ++i)
        history.push_back(chordHistory[i]);

    return history;
}

//==============================================================================
// Key Detection

ChordSense::Key ChordSense::getDetectedKey() const
{
    return detectedKey;
}

void ChordSense::setKey(const std::string& tonic, const std::string& mode)
{
    detectedKey.tonic = tonic;
    detectedKey.mode = mode;
    detectedKey.confidence = 1.0f;
    detectedKey.fullName = tonic + " " + mode;
}

void ChordSense::clearKey()
{
    detectedKey = Key();
}

//==============================================================================
// Analysis Settings

void ChordSense::setSensitivity(float sens) { sensitivity = juce::jlimit(0.0f, 1.0f, sens); }
void ChordSense::setMinimumConfidence(float conf) { minimumConfidence = juce::jlimit(0.0f, 1.0f, conf); }
void ChordSense::setDetectInversions(bool detect) { detectInversions = detect; }
void ChordSense::setDetectExtensions(bool detect) { detectExtensions = detect; }

//==============================================================================
// Chord Progressions

std::vector<ChordSense::Progression> ChordSense::getSuggestedProgressions(int count) const
{
    std::vector<Progression> suggestions;

    for (int i = 0; i < juce::jmin(count, static_cast<int>(progressionDatabase.size())); ++i)
        suggestions.push_back(progressionDatabase[i]);

    return suggestions;
}

std::string ChordSense::getRomanNumeral(const Chord& chord) const
{
    if (detectedKey.tonic.empty())
        return "";

    // Convert chord root to scale degree
    int keyRoot = noteNameToNumber(detectedKey.tonic);
    int chordRoot = noteNameToNumber(chord.root);
    int degree = (chordRoot - keyRoot + 12) % 12;

    static const std::array<std::string, 12> majorScaleDegrees = {
        "I", "bII", "II", "bIII", "III", "IV", "#IV", "V", "bVI", "VI", "bVII", "VII"
    };

    static const std::array<std::string, 12> minorScaleDegrees = {
        "i", "bII", "II", "bIII", "iii", "iv", "#IV", "v", "bVI", "VI", "bVII", "VII"
    };

    if (detectedKey.mode == "major")
        return majorScaleDegrees[degree];
    else
        return minorScaleDegrees[degree];
}

//==============================================================================
// Pitch Class Profile

std::array<float, 12> ChordSense::getPitchClassProfile() const
{
    return smoothedPitchClassProfile;
}

std::array<float, 12> ChordSense::getChordTemplate(const std::string& chordType) const
{
    auto it = chordTemplates.find(chordType);
    if (it != chordTemplates.end())
        return it->second;

    std::array<float, 12> empty;
    empty.fill(0.0f);
    return empty;
}

//==============================================================================
// Export

std::vector<ChordSense::ChordEvent> ChordSense::getChordTimeline() const
{
    return chordTimeline;
}

//==============================================================================
// Internal Algorithms

void ChordSense::performFFTAnalysis(const juce::AudioBuffer<float>& buffer)
{
    int numSamples = juce::jmin(buffer.getNumSamples(), fftSize);

    // Mix to mono and copy to FFT buffer
    fftData.fill(0.0f);
    for (int i = 0; i < numSamples; ++i)
    {
        float sample = 0.0f;
        for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
            sample += buffer.getSample(channel, i);

        fftData[i] = sample / buffer.getNumChannels();
    }

    // Apply window
    window.multiplyWithWindowingTable(fftData.data(), fftSize);

    // Perform FFT
    forwardFFT.performFrequencyOnlyForwardTransform(fftData.data());

    // Store magnitudes
    for (int i = 0; i < fftSize; ++i)
        magnitudes[i] = fftData[i];
}

void ChordSense::calculatePitchClassProfile()
{
    pitchClassProfile.fill(0.0f);

    // Map FFT bins to pitch classes (chromagram)
    float binFrequency = static_cast<float>(currentSampleRate) / fftSize;

    for (int bin = 1; bin < fftSize / 2; ++bin)
    {
        float frequency = bin * binFrequency;

        if (frequency < 80.0f || frequency > 2000.0f)  // Focus on musical range
            continue;

        // Convert frequency to MIDI note
        float midiNote = 12.0f * std::log2(frequency / 440.0f) + 69.0f;
        int pitchClass = static_cast<int>(std::round(midiNote)) % 12;

        if (pitchClass < 0) pitchClass += 12;
        if (pitchClass >= 12) continue;

        // Accumulate magnitude in pitch class
        pitchClassProfile[pitchClass] += magnitudes[bin];
    }

    // Normalize
    float maxValue = *std::max_element(pitchClassProfile.begin(), pitchClassProfile.end());
    if (maxValue > 0.001f)
    {
        for (auto& value : pitchClassProfile)
            value /= maxValue;
    }

    // Smooth with previous profile
    float smoothingFactor = 1.0f - sensitivity;
    for (int i = 0; i < 12; ++i)
    {
        smoothedPitchClassProfile[i] = smoothingFactor * smoothedPitchClassProfile[i]
                                     + (1.0f - smoothingFactor) * pitchClassProfile[i];
    }
}

void ChordSense::detectChord()
{
    float bestMatch = 0.0f;
    Chord bestChord;

    // Try all chord types and roots
    for (const auto& [chordType, template_] : chordTemplates)
    {
        for (int root = 0; root < 12; ++root)
        {
            float match = matchChordTemplate(smoothedPitchClassProfile, template_, root);

            if (match > bestMatch)
            {
                bestMatch = match;

                bestChord.root = noteNumberToName(root);
                bestChord.quality = chordType;
                bestChord.confidence = match;
                bestChord.inversion = 0;

                // Build full name
                bestChord.fullName = bestChord.root;
                if (chordType == "minor")
                    bestChord.fullName += "m";
                else if (chordType == "diminished")
                    bestChord.fullName += "dim";
                else if (chordType == "augmented")
                    bestChord.fullName += "aug";
                else if (chordType == "sus4")
                    bestChord.fullName += "sus4";
                else if (chordType == "major7")
                    bestChord.fullName += "maj7";
                else if (chordType == "minor7")
                    bestChord.fullName += "m7";
                else if (chordType == "dominant7")
                    bestChord.fullName += "7";

                bestChord.notation = bestChord.fullName;  // Simplified
            }
        }
    }

    // Only update if confidence is high enough
    if (bestMatch >= minimumConfidence)
    {
        // Check if chord changed
        if (bestChord.fullName != currentChord.fullName)
        {
            chordHistory.push_back(bestChord);

            // Add to timeline
            ChordEvent event;
            event.timeSeconds = currentTimeSeconds;
            event.chord = bestChord;
            chordTimeline.push_back(event);

            // Limit history size
            if (chordHistory.size() > 100)
                chordHistory.erase(chordHistory.begin());
        }

        currentChord = bestChord;
    }
}

void ChordSense::detectKey()
{
    // Simplified key detection using Krumhansl-Schmuckler algorithm
    std::array<float, 12> majorProfile = {6.35f, 2.23f, 3.48f, 2.33f, 4.38f, 4.09f,
                                         2.52f, 5.19f, 2.39f, 3.66f, 2.29f, 2.88f};
    std::array<float, 12> minorProfile = {6.33f, 2.68f, 3.52f, 5.38f, 2.60f, 3.53f,
                                         2.54f, 4.75f, 3.98f, 2.69f, 3.34f, 3.17f};

    float bestMajorMatch = 0.0f;
    int bestMajorRoot = 0;
    float bestMinorMatch = 0.0f;
    int bestMinorRoot = 0;

    // Try all keys
    for (int root = 0; root < 12; ++root)
    {
        float majorMatch = matchChordTemplate(smoothedPitchClassProfile, majorProfile, root);
        float minorMatch = matchChordTemplate(smoothedPitchClassProfile, minorProfile, root);

        if (majorMatch > bestMajorMatch)
        {
            bestMajorMatch = majorMatch;
            bestMajorRoot = root;
        }

        if (minorMatch > bestMinorMatch)
        {
            bestMinorMatch = minorMatch;
            bestMinorRoot = root;
        }
    }

    // Choose major or minor based on best match
    if (bestMajorMatch > bestMinorMatch)
    {
        detectedKey.tonic = noteNumberToName(bestMajorRoot);
        detectedKey.mode = "major";
        detectedKey.confidence = bestMajorMatch;
    }
    else
    {
        detectedKey.tonic = noteNumberToName(bestMinorRoot);
        detectedKey.mode = "minor";
        detectedKey.confidence = bestMinorMatch;
    }

    detectedKey.fullName = detectedKey.tonic + " " + detectedKey.mode;
}

//==============================================================================
// Chord Templates

void ChordSense::initializeChordTemplates()
{
    // Major triad (1, 3, 5)
    chordTemplates["major"] = {1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f};

    // Minor triad (1, b3, 5)
    chordTemplates["minor"] = {1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f};

    // Diminished triad (1, b3, b5)
    chordTemplates["diminished"] = {1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};

    // Augmented triad (1, 3, #5)
    chordTemplates["augmented"] = {1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f};

    // Sus4 (1, 4, 5)
    chordTemplates["sus4"] = {1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f};

    // Major 7th (1, 3, 5, 7)
    chordTemplates["major7"] = {1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f};

    // Minor 7th (1, b3, 5, b7)
    chordTemplates["minor7"] = {1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f};

    // Dominant 7th (1, 3, 5, b7)
    chordTemplates["dominant7"] = {1.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f, 0.0f};
}

float ChordSense::matchChordTemplate(const std::array<float, 12>& profile,
                                     const std::array<float, 12>& template_,
                                     int rootNote) const
{
    float match = 0.0f;

    for (int i = 0; i < 12; ++i)
    {
        int templateIndex = (i - rootNote + 12) % 12;
        match += profile[i] * template_[templateIndex];
    }

    return match / 12.0f;
}

//==============================================================================
// Progression Database

void ChordSense::initializeProgressionDatabase()
{
    // I-V-vi-IV (Pop progression)
    {
        Progression prog;
        prog.romanNumerals = "I-V-vi-IV";
        prog.description = "Pop Progression (Axis of Awesome)";
        prog.popularity = 1.0f;
        progressionDatabase.push_back(prog);
    }

    // ii-V-I (Jazz progression)
    {
        Progression prog;
        prog.romanNumerals = "ii-V-I";
        prog.description = "Jazz ii-V-I";
        prog.popularity = 0.9f;
        progressionDatabase.push_back(prog);
    }

    // I-IV-V (Classic Rock)
    {
        Progression prog;
        prog.romanNumerals = "I-IV-V";
        prog.description = "Classic Rock (12-bar blues basis)";
        prog.popularity = 0.95f;
        progressionDatabase.push_back(prog);
    }

    // vi-IV-I-V (Deceptive)
    {
        Progression prog;
        prog.romanNumerals = "vi-IV-I-V";
        prog.description = "Deceptive Progression";
        prog.popularity = 0.8f;
        progressionDatabase.push_back(prog);
    }

    // I-vi-IV-V (50s progression)
    {
        Progression prog;
        prog.romanNumerals = "I-vi-IV-V";
        prog.description = "50s Doo-Wop Progression";
        prog.popularity = 0.85f;
        progressionDatabase.push_back(prog);
    }
}

//==============================================================================
// Helper Functions

std::string ChordSense::noteNumberToName(int noteNumber) const
{
    static const std::array<std::string, 12> noteNames = {
        "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
    };

    return noteNames[noteNumber % 12];
}

int ChordSense::noteNameToNumber(const std::string& name) const
{
    static const std::map<std::string, int> noteMap = {
        {"C", 0}, {"C#", 1}, {"Db", 1},
        {"D", 2}, {"D#", 3}, {"Eb", 3},
        {"E", 4},
        {"F", 5}, {"F#", 6}, {"Gb", 6},
        {"G", 7}, {"G#", 8}, {"Ab", 8},
        {"A", 9}, {"A#", 10}, {"Bb", 10},
        {"B", 11}
    };

    auto it = noteMap.find(name);
    if (it != noteMap.end())
        return it->second;

    return 0;  // Default to C
}
