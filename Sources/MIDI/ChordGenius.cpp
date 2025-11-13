#include "ChordGenius.h"
#include <algorithm>
#include <cmath>
#include <numeric>

//==============================================================================
// Static Data

const std::array<std::string, 12> ChordGenius::NOTE_NAMES = {
    "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"
};

const std::map<ChordGenius::Scale, std::vector<int>> ChordGenius::SCALE_INTERVALS = {
    {Scale::Major,              {0, 2, 4, 5, 7, 9, 11}},
    {Scale::NaturalMinor,       {0, 2, 3, 5, 7, 8, 10}},
    {Scale::HarmonicMinor,      {0, 2, 3, 5, 7, 8, 11}},
    {Scale::MelodicMinor,       {0, 2, 3, 5, 7, 9, 11}},
    {Scale::Dorian,             {0, 2, 3, 5, 7, 9, 10}},
    {Scale::Phrygian,           {0, 1, 3, 5, 7, 8, 10}},
    {Scale::Lydian,             {0, 2, 4, 6, 7, 9, 11}},
    {Scale::Mixolydian,         {0, 2, 4, 5, 7, 9, 10}},
    {Scale::Locrian,            {0, 1, 3, 5, 6, 8, 10}},
    {Scale::MajorPentatonic,    {0, 2, 4, 7, 9}},
    {Scale::MinorPentatonic,    {0, 3, 5, 7, 10}},
    {Scale::Blues,              {0, 3, 5, 6, 7, 10}},
    {Scale::WholeTone,          {0, 2, 4, 6, 8, 10}},
    {Scale::Chromatic,          {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}},
    {Scale::Diminished,         {0, 2, 3, 5, 6, 8, 9, 11}}
};

const std::map<ChordGenius::ChordQuality, std::vector<int>> ChordGenius::CHORD_INTERVALS = {
    {ChordQuality::Major,               {0, 4, 7}},
    {ChordQuality::Minor,               {0, 3, 7}},
    {ChordQuality::Diminished,          {0, 3, 6}},
    {ChordQuality::Augmented,           {0, 4, 8}},
    {ChordQuality::Sus2,                {0, 2, 7}},
    {ChordQuality::Sus4,                {0, 5, 7}},
    {ChordQuality::Dominant7,           {0, 4, 7, 10}},
    {ChordQuality::Major7,              {0, 4, 7, 11}},
    {ChordQuality::Minor7,              {0, 3, 7, 10}},
    {ChordQuality::MinorMajor7,         {0, 3, 7, 11}},
    {ChordQuality::Diminished7,         {0, 3, 6, 9}},
    {ChordQuality::HalfDiminished7,     {0, 3, 6, 10}},
    {ChordQuality::Augmented7,          {0, 4, 8, 10}},
    {ChordQuality::Major9,              {0, 4, 7, 11, 14}},
    {ChordQuality::Minor9,              {0, 3, 7, 10, 14}},
    {ChordQuality::Dominant9,           {0, 4, 7, 10, 14}},
    {ChordQuality::Major11,             {0, 4, 7, 11, 14, 17}},
    {ChordQuality::Minor11,             {0, 3, 7, 10, 14, 17}},
    {ChordQuality::Dominant11,          {0, 4, 7, 10, 14, 17}},
    {ChordQuality::Major13,             {0, 4, 7, 11, 14, 21}},
    {ChordQuality::Minor13,             {0, 3, 7, 10, 14, 21}},
    {ChordQuality::Dominant13,          {0, 4, 7, 10, 14, 21}},
    {ChordQuality::Add9,                {0, 4, 7, 14}},
    {ChordQuality::Add11,               {0, 4, 7, 17}},
    {ChordQuality::Sixth,               {0, 4, 7, 9}},
    {ChordQuality::MinorSixth,          {0, 3, 7, 9}},
    {ChordQuality::SixNine,             {0, 4, 7, 9, 14}},
    {ChordQuality::Altered,             {0, 4, 8, 10, 13, 15}},
    {ChordQuality::Power,               {0, 7}},
    {ChordQuality::Dominant7Flat9,      {0, 4, 7, 10, 13}},
    {ChordQuality::Dominant7Sharp9,     {0, 4, 7, 10, 15}},
    {ChordQuality::Dominant7Suspended4, {0, 5, 7, 10}}
};

const std::vector<ChordGenius::ProgressionTemplate> ChordGenius::POPULAR_PROGRESSIONS = {
    // Pop/Rock
    {"I-V-vi-IV (Axis of Awesome)", "Pop", {0, 4, 5, 3}, {ChordQuality::Major, ChordQuality::Major, ChordQuality::Minor, ChordQuality::Major}},
    {"vi-IV-I-V (Sensitive)", "Pop", {5, 3, 0, 4}, {ChordQuality::Minor, ChordQuality::Major, ChordQuality::Major, ChordQuality::Major}},
    {"I-IV-V (50s Progression)", "Rock", {0, 3, 4}, {ChordQuality::Major, ChordQuality::Major, ChordQuality::Major}},
    {"I-vi-IV-V (Doo-Wop)", "Pop", {0, 5, 3, 4}, {ChordQuality::Major, ChordQuality::Minor, ChordQuality::Major, ChordQuality::Major}},
    {"I-V-vi-iii-IV-I-IV-V (Canon)", "Classical", {0, 4, 5, 2, 3, 0, 3, 4}, {ChordQuality::Major, ChordQuality::Major, ChordQuality::Minor, ChordQuality::Minor, ChordQuality::Major, ChordQuality::Major, ChordQuality::Major, ChordQuality::Major}},

    // R&B/Soul
    {"ii-V-I (Jazz Standard)", "Jazz", {1, 4, 0}, {ChordQuality::Minor7, ChordQuality::Dominant7, ChordQuality::Major7}},
    {"I-IV-ii-V (Coltrane Changes)", "Jazz", {0, 3, 1, 4}, {ChordQuality::Major7, ChordQuality::Major7, ChordQuality::Minor7, ChordQuality::Dominant7}},
    {"IVmaj7-iii7-vi7-ii7-V7 (Autumn Leaves)", "Jazz", {3, 2, 5, 1, 4}, {ChordQuality::Major7, ChordQuality::Minor7, ChordQuality::Minor7, ChordQuality::Minor7, ChordQuality::Dominant7}},

    // EDM/Electronic
    {"i-VI-III-VII (Aeolian)", "EDM", {0, 5, 2, 6}, {ChordQuality::Minor, ChordQuality::Major, ChordQuality::Major, ChordQuality::Major}},
    {"i-III-VII-VI (Minor Pop)", "EDM", {0, 2, 6, 5}, {ChordQuality::Minor, ChordQuality::Major, ChordQuality::Major, ChordQuality::Major}},
    {"i-v-VI-III (Dark EDM)", "EDM", {0, 4, 5, 2}, {ChordQuality::Minor, ChordQuality::Minor, ChordQuality::Major, ChordQuality::Major}},

    // Blues
    {"I7-IV7-V7 (12-Bar Blues)", "Blues", {0, 3, 4}, {ChordQuality::Dominant7, ChordQuality::Dominant7, ChordQuality::Dominant7}},

    // Gospel
    {"I-IV-I-V7-I (Gospel Turnaround)", "Gospel", {0, 3, 0, 4, 0}, {ChordQuality::Major7, ChordQuality::Major7, ChordQuality::Major7, ChordQuality::Dominant7, ChordQuality::Major7}}
};

//==============================================================================
ChordGenius::ChordGenius()
{
}

ChordGenius::~ChordGenius()
{
}

//==============================================================================
// Chord Generation

ChordGenius::Chord ChordGenius::generateChord(int root, ChordQuality quality, VoicingType voicing)
{
    Chord chord;
    chord.root = root % 12;
    chord.quality = quality;
    chord.voicing = voicing;
    chord.inversion = 0;

    // Get intervals for this chord quality
    auto intervals = getChordIntervals(quality);

    // Build notes with voicing
    chord.notes = buildChordNotes(root, intervals, voicing, 4);

    // Generate name
    chord.name = getChordName(chord);

    return chord;
}

std::vector<ChordGenius::Chord> ChordGenius::getDiatonicChords(int rootNote, Scale scale)
{
    std::vector<Chord> chords;

    auto scaleIntervals = SCALE_INTERVALS.at(scale);

    // Generate chord for each scale degree
    for (size_t degree = 0; degree < scaleIntervals.size(); ++degree)
    {
        int chordRoot = (rootNote + scaleIntervals[degree]) % 12;

        // Determine chord quality based on scale degree
        ChordQuality quality;

        if (scale == Scale::Major)
        {
            // Major scale: I, ii, iii, IV, V, vi, vii°
            if (degree == 0 || degree == 3 || degree == 4)
                quality = ChordQuality::Major;
            else if (degree == 1 || degree == 2 || degree == 5)
                quality = ChordQuality::Minor;
            else  // degree == 6
                quality = ChordQuality::Diminished;
        }
        else if (scale == Scale::NaturalMinor)
        {
            // Natural minor: i, ii°, III, iv, v, VI, VII
            if (degree == 0 || degree == 3 || degree == 4)
                quality = ChordQuality::Minor;
            else if (degree == 2 || degree == 5 || degree == 6)
                quality = ChordQuality::Major;
            else  // degree == 1
                quality = ChordQuality::Diminished;
        }
        else
        {
            // Default to major for other scales
            quality = ChordQuality::Major;
        }

        chords.push_back(generateChord(chordRoot, quality));
    }

    return chords;
}

std::string ChordGenius::getChordName(const Chord& chord)
{
    std::string name = NOTE_NAMES[chord.root];
    name += getQualitySymbol(chord.quality);

    if (chord.inversion > 0)
        name += "/" + NOTE_NAMES[(chord.notes[0]) % 12];

    return name;
}

std::vector<int> ChordGenius::getChordIntervals(ChordQuality quality)
{
    auto it = CHORD_INTERVALS.find(quality);
    if (it != CHORD_INTERVALS.end())
        return it->second;

    // Default to major triad
    return {0, 4, 7};
}

//==============================================================================
// Progression Generation

std::vector<ChordGenius::Progression> ChordGenius::getPopularProgressions(int key, Scale scale)
{
    std::vector<Progression> progressions;

    auto scaleIntervals = SCALE_INTERVALS.at(scale);

    for (const auto& template_ : POPULAR_PROGRESSIONS)
    {
        Progression prog;
        prog.name = template_.name;
        prog.genre = template_.genre;
        prog.key = key;
        prog.scale = scale;

        // Build chords from degrees
        for (size_t i = 0; i < template_.degrees.size(); ++i)
        {
            int degree = template_.degrees[i];
            if (degree >= 0 && degree < static_cast<int>(scaleIntervals.size()))
            {
                int chordRoot = (key + scaleIntervals[degree]) % 12;
                ChordQuality quality = template_.qualities[i];
                prog.chords.push_back(generateChord(chordRoot, quality));
            }
        }

        progressions.push_back(prog);
    }

    return progressions;
}

std::vector<ChordGenius::Chord> ChordGenius::suggestNextChords(const Chord& currentChord, Scale scale, int key)
{
    std::vector<Chord> suggestions;

    // Get all diatonic chords in scale
    auto diatonicChords = getDiatonicChords(key, scale);

    // Calculate transition probabilities
    std::vector<std::pair<float, Chord>> scoredChords;

    for (const auto& chord : diatonicChords)
    {
        float probability = getTransitionProbability(currentChord, chord, scale);
        scoredChords.push_back({probability, chord});
    }

    // Sort by probability (descending)
    std::sort(scoredChords.begin(), scoredChords.end(),
              [](const auto& a, const auto& b) { return a.first > b.first; });

    // Return top 5 suggestions
    for (int i = 0; i < juce::jmin(5, static_cast<int>(scoredChords.size())); ++i)
        suggestions.push_back(scoredChords[i].second);

    return suggestions;
}

ChordGenius::Progression ChordGenius::generateProgressionAI(int key, Scale scale, const std::string& genre, int numChords)
{
    Progression prog;
    prog.key = key;
    prog.scale = scale;
    prog.name = "AI Generated";
    prog.genre = genre;

    // Start with tonic
    auto diatonicChords = getDiatonicChords(key, scale);

    if (!diatonicChords.empty())
    {
        prog.chords.push_back(diatonicChords[0]);  // Start with I

        // Generate remaining chords
        for (int i = 1; i < numChords; ++i)
        {
            auto suggestions = suggestNextChords(prog.chords.back(), scale, key);
            if (!suggestions.empty())
            {
                // Pick best suggestion (or add randomness for variety)
                int index = (i == numChords - 1) ? 0 : (rand() % juce::jmin(3, static_cast<int>(suggestions.size())));
                prog.chords.push_back(suggestions[index]);
            }
        }

        // Optimize voice leading
        for (size_t i = 1; i < prog.chords.size(); ++i)
        {
            prog.chords[i] = optimizeVoiceLeading(prog.chords[i - 1], prog.chords[i]);
        }
    }

    return prog;
}

//==============================================================================
// Voice Leading

ChordGenius::Chord ChordGenius::optimizeVoiceLeading(const Chord& fromChord, const Chord& toChord)
{
    Chord optimized = toChord;

    // Try different inversions to minimize voice leading distance
    int bestInversion = 0;
    int bestDistance = getVoiceLeadingDistance(fromChord, toChord);

    for (int inv = 1; inv <= static_cast<int>(toChord.notes.size()); ++inv)
    {
        Chord inverted = toChord;

        // Apply inversion
        for (int i = 0; i < inv; ++i)
        {
            if (!inverted.notes.empty())
            {
                int lowest = inverted.notes[0];
                inverted.notes.erase(inverted.notes.begin());
                inverted.notes.push_back(lowest + 12);  // Move to next octave
            }
        }

        int distance = getVoiceLeadingDistance(fromChord, inverted);
        if (distance < bestDistance)
        {
            bestDistance = distance;
            bestInversion = inv;
            optimized = inverted;
        }
    }

    optimized.inversion = bestInversion;
    return optimized;
}

int ChordGenius::getVoiceLeadingDistance(const Chord& chord1, const Chord& chord2)
{
    int distance = 0;
    size_t maxSize = juce::jmax(chord1.notes.size(), chord2.notes.size());

    for (size_t i = 0; i < maxSize; ++i)
    {
        int note1 = (i < chord1.notes.size()) ? chord1.notes[i] : 0;
        int note2 = (i < chord2.notes.size()) ? chord2.notes[i] : 0;
        distance += std::abs(note1 - note2);
    }

    return distance;
}

//==============================================================================
// Key & Scale Detection

std::pair<int, ChordGenius::Scale> ChordGenius::detectKey(const std::vector<int>& midiNotes)
{
    // Krumhansl-Schmuckler key-finding algorithm
    std::array<float, 12> majorProfile = {6.35f, 2.23f, 3.48f, 2.33f, 4.38f, 4.09f, 2.52f, 5.19f, 2.39f, 3.66f, 2.29f, 2.88f};
    std::array<float, 12> minorProfile = {6.33f, 2.68f, 3.52f, 5.38f, 2.60f, 3.53f, 2.54f, 4.75f, 3.98f, 2.69f, 3.34f, 3.17f};

    // Count note occurrences
    std::array<int, 12> pitchClass = {0};
    for (int note : midiNotes)
        pitchClass[note % 12]++;

    // Find best correlation
    int bestKey = 0;
    Scale bestScale = Scale::Major;
    float bestCorrelation = -1.0f;

    for (int key = 0; key < 12; ++key)
    {
        // Try major
        float majorCorr = 0.0f;
        for (int i = 0; i < 12; ++i)
            majorCorr += pitchClass[(key + i) % 12] * majorProfile[i];

        if (majorCorr > bestCorrelation)
        {
            bestCorrelation = majorCorr;
            bestKey = key;
            bestScale = Scale::Major;
        }

        // Try minor
        float minorCorr = 0.0f;
        for (int i = 0; i < 12; ++i)
            minorCorr += pitchClass[(key + i) % 12] * minorProfile[i];

        if (minorCorr > bestCorrelation)
        {
            bestCorrelation = minorCorr;
            bestKey = key;
            bestScale = Scale::NaturalMinor;
        }
    }

    return {bestKey, bestScale};
}

ChordGenius::Scale ChordGenius::detectScale(const std::vector<int>& midiNotes, int rootNote)
{
    // Count unique pitch classes
    std::array<bool, 12> pitchClassSet = {false};
    for (int note : midiNotes)
        pitchClassSet[(note - rootNote + 120) % 12] = true;

    // Try to match scale patterns
    int bestMatch = 0;
    Scale bestScale = Scale::Major;

    for (const auto& [scale, intervals] : SCALE_INTERVALS)
    {
        int matches = 0;
        for (int interval : intervals)
        {
            if (pitchClassSet[interval])
                matches++;
        }

        if (matches > bestMatch)
        {
            bestMatch = matches;
            bestScale = scale;
        }
    }

    return bestScale;
}

ChordGenius::Chord ChordGenius::transposeChord(const Chord& chord, int semitones)
{
    Chord transposed = chord;
    transposed.root = (chord.root + semitones + 120) % 12;

    for (auto& note : transposed.notes)
        note += semitones;

    transposed.name = getChordName(transposed);
    return transposed;
}

ChordGenius::Progression ChordGenius::transposeProgression(const Progression& progression, int newKey)
{
    int semitones = newKey - progression.key;

    Progression transposed = progression;
    transposed.key = newKey;
    transposed.chords.clear();

    for (const auto& chord : progression.chords)
        transposed.chords.push_back(transposeChord(chord, semitones));

    return transposed;
}

//==============================================================================
// MIDI Export

juce::MidiMessage ChordGenius::chordToMidiOn(const Chord& chord, double timeSeconds, uint8 velocity)
{
    // Return first note (others can be added to buffer separately)
    if (!chord.notes.empty())
        return juce::MidiMessage::noteOn(1, chord.notes[0], velocity);

    return juce::MidiMessage();
}

void ChordGenius::progressionToMidiBuffer(const Progression& progression, juce::MidiBuffer& buffer,
                                          double beatsPerChord, double bpm)
{
    double secondsPerBeat = 60.0 / bpm;
    double secondsPerChord = beatsPerChord * secondsPerBeat;

    for (size_t chordIndex = 0; chordIndex < progression.chords.size(); ++chordIndex)
    {
        const auto& chord = progression.chords[chordIndex];
        double startTime = chordIndex * secondsPerChord;
        double endTime = (chordIndex + 1) * secondsPerChord;

        // Add note-on messages
        for (int note : chord.notes)
        {
            buffer.addEvent(juce::MidiMessage::noteOn(1, note, (uint8)100),
                          static_cast<int>(startTime * 44100));  // Convert to samples
        }

        // Add note-off messages
        for (int note : chord.notes)
        {
            buffer.addEvent(juce::MidiMessage::noteOff(1, note),
                          static_cast<int>(endTime * 44100));
        }
    }
}

//==============================================================================
// Helper Functions

std::vector<int> ChordGenius::buildChordNotes(int root, const std::vector<int>& intervals,
                                               VoicingType voicing, int octave)
{
    std::vector<int> notes;
    int baseMidi = 12 + octave * 12 + root;  // MIDI note number

    for (int interval : intervals)
        notes.push_back(baseMidi + interval);

    return applyVoicing(notes, voicing);
}

std::vector<int> ChordGenius::applyVoicing(std::vector<int> notes, VoicingType voicing)
{
    if (notes.size() < 3)
        return notes;

    switch (voicing)
    {
        case VoicingType::Close:
            // All notes within octave (default)
            break;

        case VoicingType::Open:
            // Spread across 2 octaves
            if (notes.size() >= 3)
                notes[1] += 12;
            break;

        case VoicingType::Drop2:
            // Drop 2nd highest note by octave
            if (notes.size() >= 3)
            {
                size_t idx = notes.size() - 2;
                notes[idx] -= 12;
            }
            break;

        case VoicingType::Drop3:
            // Drop 3rd highest note by octave
            if (notes.size() >= 4)
            {
                size_t idx = notes.size() - 3;
                notes[idx] -= 12;
            }
            break;

        case VoicingType::Drop2And4:
            // Drop 2nd and 4th
            if (notes.size() >= 4)
            {
                notes[notes.size() - 2] -= 12;
                notes[notes.size() - 4] -= 12;
            }
            break;

        case VoicingType::Spread:
            // Wide spacing
            for (size_t i = 1; i < notes.size(); ++i)
                notes[i] += (i * 5);
            break;

        case VoicingType::Rootless:
            // Remove root
            if (!notes.empty())
                notes.erase(notes.begin());
            break;

        default:
            break;
    }

    return notes;
}

std::string ChordGenius::getQualitySymbol(ChordQuality quality)
{
    switch (quality)
    {
        case ChordQuality::Major: return "";
        case ChordQuality::Minor: return "m";
        case ChordQuality::Diminished: return "dim";
        case ChordQuality::Augmented: return "aug";
        case ChordQuality::Sus2: return "sus2";
        case ChordQuality::Sus4: return "sus4";
        case ChordQuality::Dominant7: return "7";
        case ChordQuality::Major7: return "maj7";
        case ChordQuality::Minor7: return "m7";
        case ChordQuality::MinorMajor7: return "m(maj7)";
        case ChordQuality::Diminished7: return "dim7";
        case ChordQuality::HalfDiminished7: return "m7b5";
        case ChordQuality::Augmented7: return "7#5";
        case ChordQuality::Major9: return "maj9";
        case ChordQuality::Minor9: return "m9";
        case ChordQuality::Dominant9: return "9";
        case ChordQuality::Major11: return "maj11";
        case ChordQuality::Minor11: return "m11";
        case ChordQuality::Dominant11: return "11";
        case ChordQuality::Major13: return "maj13";
        case ChordQuality::Minor13: return "m13";
        case ChordQuality::Dominant13: return "13";
        case ChordQuality::Add9: return "add9";
        case ChordQuality::Add11: return "add11";
        case ChordQuality::Sixth: return "6";
        case ChordQuality::MinorSixth: return "m6";
        case ChordQuality::SixNine: return "6/9";
        case ChordQuality::Altered: return "7alt";
        case ChordQuality::Power: return "5";
        case ChordQuality::Dominant7Flat9: return "7b9";
        case ChordQuality::Dominant7Sharp9: return "7#9";
        case ChordQuality::Dominant7Suspended4: return "7sus4";
        default: return "";
    }
}

float ChordGenius::getTransitionProbability(const Chord& from, const Chord& to, Scale scale)
{
    // Music theory-based transition probabilities

    // Perfect 5th up (strongest progression)
    int interval = (to.root - from.root + 12) % 12;

    if (interval == 7)       // Perfect 5th (V-I)
        return 1.0f;
    else if (interval == 5)  // Perfect 4th (IV-I)
        return 0.9f;
    else if (interval == 2)  // Whole tone (stepwise)
        return 0.7f;
    else if (interval == 9)  // Major 6th
        return 0.6f;
    else if (interval == 4)  // Major 3rd
        return 0.5f;
    else if (interval == 0)  // Same root
        return 0.3f;
    else
        return 0.4f;
}
