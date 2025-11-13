#include "MelodyForge.h"
#include <algorithm>
#include <cmath>

MelodyForge::MelodyForge()
    : uniformDist(0.0f, 1.0f)
{
    randomEngine.seed(static_cast<unsigned int>(std::time(nullptr)));
}

MelodyForge::~MelodyForge()
{
}

//==============================================================================
// Melody Generation

MelodyForge::Melody MelodyForge::generateMelody(const ChordGenius::Progression& progression,
                                                int numBars, double bpm)
{
    return generateMelodyWithRhythm(progression, RhythmPattern::Mixed, numBars, bpm);
}

MelodyForge::Melody MelodyForge::generateMelodyWithRhythm(const ChordGenius::Progression& progression,
                                                          RhythmPattern rhythm, int numBars, double bpm)
{
    Melody melody;
    melody.key = progression.key;
    melody.scale = progression.scale;
    melody.genre = progression.genre;
    melody.bpm = bpm;

    // Get scale notes (2 octaves)
    auto scaleNotes = getScaleNotes(progression.key, progression.scale, 4, 6);

    // Get rhythm durations
    auto rhythmDurations = getRhythmDurations(rhythm, bpm);

    // Calculate total duration
    double beatsPerBar = 4.0;
    double secondsPerBeat = 60.0 / bpm;
    double totalDuration = numBars * beatsPerBar * secondsPerBeat;

    // Generate notes
    double currentTime = 0.0;
    int chordIndex = 0;
    double chordDuration = totalDuration / progression.chords.size();
    MelodyNote previousNote;
    previousNote.pitch = scaleNotes[scaleNotes.size() / 2];  // Start in middle

    int rhythmIndex = 0;

    while (currentTime < totalDuration)
    {
        // Get current chord
        chordIndex = static_cast<int>(currentTime / chordDuration) % progression.chords.size();
        const auto& currentChord = progression.chords[chordIndex];

        // Generate note
        MelodyNote note = generateNote(currentChord, scaleNotes, previousNote, MelodicContour::Random);
        note.startTime = currentTime;
        note.duration = rhythmDurations[rhythmIndex % rhythmDurations.size()];

        // Check for rest
        if (uniformDist(randomEngine) < restProbability)
            note.isRest = true;

        melody.notes.push_back(note);

        currentTime += note.duration;
        rhythmIndex++;
        if (!note.isRest)
            previousNote = note;
    }

    return melody;
}

MelodyForge::Melody MelodyForge::generateMelodyWithContour(const ChordGenius::Progression& progression,
                                                           MelodicContour contour, int numBars, double bpm)
{
    Melody melody;
    melody.key = progression.key;
    melody.scale = progression.scale;
    melody.genre = progression.genre;
    melody.bpm = bpm;

    auto scaleNotes = getScaleNotes(progression.key, progression.scale, 4, 6);
    auto rhythmDurations = getRhythmDurations(RhythmPattern::EighthNotes, bpm);

    double beatsPerBar = 4.0;
    double secondsPerBeat = 60.0 / bpm;
    double totalDuration = numBars * beatsPerBar * secondsPerBeat;

    double currentTime = 0.0;
    int chordIndex = 0;
    double chordDuration = totalDuration / progression.chords.size();

    MelodyNote previousNote;
    previousNote.pitch = scaleNotes[scaleNotes.size() / 2];

    int contourPosition = 0;
    int rhythmIndex = 0;

    while (currentTime < totalDuration)
    {
        chordIndex = static_cast<int>(currentTime / chordDuration) % progression.chords.size();
        const auto& currentChord = progression.chords[chordIndex];

        MelodyNote note;
        note.startTime = currentTime;
        note.duration = rhythmDurations[rhythmIndex % rhythmDurations.size()];
        note.velocity = static_cast<uint8>(90 + uniformDist(randomEngine) * 20);
        note.isRest = (uniformDist(randomEngine) < restProbability);

        if (!note.isRest)
        {
            note.pitch = getNextPitchFromContour(previousNote.pitch, contour, scaleNotes, contourPosition);

            // Prefer chord tones on strong beats
            if (fmod(currentTime / secondsPerBeat, 1.0) < 0.1)
            {
                auto chordTones = getChordTones(currentChord, 4, 6);
                if (!chordTones.empty())
                {
                    int closest = chordTones[0];
                    int minDist = std::abs(note.pitch - closest);
                    for (int tone : chordTones)
                    {
                        int dist = std::abs(note.pitch - tone);
                        if (dist < minDist)
                        {
                            minDist = dist;
                            closest = tone;
                        }
                    }
                    note.pitch = closest;
                }
            }

            previousNote = note;
        }

        melody.notes.push_back(note);
        currentTime += note.duration;
        rhythmIndex++;
    }

    return melody;
}

MelodyForge::Melody MelodyForge::generateGenreMelody(const ChordGenius::Progression& progression,
                                                     const std::string& genre, int numBars, double bpm)
{
    applyGenreStyle(genre);

    RhythmPattern rhythm = RhythmPattern::Mixed;
    MelodicContour contour = MelodicContour::Random;

    if (genre == "Pop")
    {
        rhythm = RhythmPattern::Syncopated;
        contour = MelodicContour::Arch;
    }
    else if (genre == "Jazz")
    {
        rhythm = RhythmPattern::SwingEighths;
        contour = MelodicContour::LeapFriendly;
        maxInterval = 12;
    }
    else if (genre == "Classical")
    {
        rhythm = RhythmPattern::Mixed;
        contour = MelodicContour::Stepwise;
        maxInterval = 4;
    }
    else if (genre == "EDM")
    {
        rhythm = RhythmPattern::Sixteenths;
        contour = MelodicContour::Ascending;
        restProbability = 0.05f;
    }
    else if (genre == "Hip-Hop")
    {
        rhythm = RhythmPattern::Syncopated;
        contour = MelodicContour::Plateau;
        noteDensity = 0.5f;
    }

    auto melody = generateMelodyWithContour(progression, contour, numBars, bpm);
    melody.genre = genre;

    return melody;
}

//==============================================================================
// Melody Transformation

MelodyForge::Melody MelodyForge::transposeMelody(const Melody& melody, int semitones)
{
    Melody transposed = melody;
    transposed.key = (melody.key + semitones + 120) % 12;

    for (auto& note : transposed.notes)
    {
        if (!note.isRest)
            note.pitch += semitones;
    }

    return transposed;
}

MelodyForge::Melody MelodyForge::invertMelody(const Melody& melody)
{
    if (melody.notes.empty())
        return melody;

    Melody inverted = melody;

    // Find first non-rest note as axis
    int axis = 60;
    for (const auto& note : melody.notes)
    {
        if (!note.isRest)
        {
            axis = note.pitch;
            break;
        }
    }

    // Invert around axis
    for (auto& note : inverted.notes)
    {
        if (!note.isRest)
            note.pitch = axis - (note.pitch - axis);
    }

    return inverted;
}

MelodyForge::Melody MelodyForge::retrogradeMelody(const Melody& melody)
{
    Melody retrograde = melody;
    std::reverse(retrograde.notes.begin(), retrograde.notes.end());

    // Recalculate start times
    double currentTime = 0.0;
    for (auto& note : retrograde.notes)
    {
        note.startTime = currentTime;
        currentTime += note.duration;
    }

    return retrograde;
}

MelodyForge::Melody MelodyForge::sequenceMelody(const Melody& melody, int repetitions, int intervalStep)
{
    Melody sequenced;
    sequenced.key = melody.key;
    sequenced.scale = melody.scale;
    sequenced.genre = melody.genre;
    sequenced.bpm = melody.bpm;

    double totalDuration = 0.0;
    if (!melody.notes.empty())
    {
        for (const auto& note : melody.notes)
            totalDuration = std::max(totalDuration, note.startTime + note.duration);
    }

    for (int rep = 0; rep < repetitions; ++rep)
    {
        for (const auto& note : melody.notes)
        {
            MelodyNote sequencedNote = note;
            sequencedNote.startTime += rep * totalDuration;
            if (!sequencedNote.isRest)
                sequencedNote.pitch += rep * intervalStep;
            sequenced.notes.push_back(sequencedNote);
        }
    }

    return sequenced;
}

MelodyForge::Melody MelodyForge::augmentMelody(const Melody& melody, double factor)
{
    Melody augmented = melody;

    for (auto& note : augmented.notes)
    {
        note.startTime *= factor;
        note.duration *= factor;
    }

    return augmented;
}

MelodyForge::Melody MelodyForge::diminuteMelody(const Melody& melody, double factor)
{
    return augmentMelody(melody, factor);
}

//==============================================================================
// Humanization

void MelodyForge::humanizeMelody(Melody& melody, float amount)
{
    humanizationAmount = amount;

    for (auto& note : melody.notes)
    {
        if (note.isRest)
            continue;

        // Timing variation (±10ms max)
        float timingVariation = (uniformDist(randomEngine) - 0.5f) * 0.02f * amount;
        note.startTime += timingVariation;

        // Duration variation (±10%)
        float durationVariation = 1.0f + (uniformDist(randomEngine) - 0.5f) * 0.2f * amount;
        note.duration *= durationVariation;

        // Velocity variation (±20)
        int velocityVariation = static_cast<int>((uniformDist(randomEngine) - 0.5f) * 40.0f * amount);
        note.velocity = static_cast<uint8>(juce::jlimit(20, 127, static_cast<int>(note.velocity) + velocityVariation));
    }
}

void MelodyForge::applySwing(Melody& melody, float swingAmount)
{
    double eighthNoteDuration = 60.0 / melody.bpm / 2.0;  // Eighth note duration

    for (auto& note : melody.notes)
    {
        // Check if note is on off-beat eighth
        double beatPosition = fmod(note.startTime / eighthNoteDuration, 2.0);

        if (beatPosition > 0.9 && beatPosition < 1.1)  // Second eighth of pair
        {
            // Delay off-beat eighth notes
            note.startTime += eighthNoteDuration * swingAmount * 0.33;  // Up to triplet feel
        }
    }
}

void MelodyForge::quantizeMelody(Melody& melody, double gridSize)
{
    for (auto& note : melody.notes)
    {
        // Snap to grid
        double grid = gridSize;
        note.startTime = std::round(note.startTime / grid) * grid;
        note.duration = std::round(note.duration / grid) * grid;

        // Ensure minimum duration
        if (note.duration < gridSize)
            note.duration = gridSize;
    }
}

//==============================================================================
// MIDI Export

void MelodyForge::melodyToMidiBuffer(const Melody& melody, juce::MidiBuffer& buffer)
{
    buffer.clear();

    for (const auto& note : melody.notes)
    {
        if (note.isRest)
            continue;

        int startSample = static_cast<int>(note.startTime * 44100.0);
        int endSample = static_cast<int>((note.startTime + note.duration) * 44100.0);

        buffer.addEvent(juce::MidiMessage::noteOn(1, note.pitch, note.velocity), startSample);
        buffer.addEvent(juce::MidiMessage::noteOff(1, note.pitch), endSample);
    }
}

bool MelodyForge::exportMelodyToMidi(const Melody& melody, const juce::File& outputFile)
{
    juce::MidiFile midiFile;
    juce::MidiMessageSequence sequence;

    double ticksPerQuarterNote = 480;
    midiFile.setTicksPerQuarterNote(static_cast<int>(ticksPerQuarterNote));

    for (const auto& note : melody.notes)
    {
        if (note.isRest)
            continue;

        double ticksPerSecond = ticksPerQuarterNote * (melody.bpm / 60.0);
        double startTick = note.startTime * ticksPerSecond;
        double endTick = (note.startTime + note.duration) * ticksPerSecond;

        sequence.addEvent(juce::MidiMessage::noteOn(1, note.pitch, note.velocity), startTick);
        sequence.addEvent(juce::MidiMessage::noteOff(1, note.pitch), endTick);
    }

    sequence.updateMatchedPairs();
    midiFile.addTrack(sequence);

    juce::FileOutputStream outputStream(outputFile);
    if (outputStream.openedOk())
    {
        midiFile.writeTo(outputStream);
        return true;
    }

    return false;
}

//==============================================================================
// Parameters

void MelodyForge::setNoteDensity(float density)
{
    noteDensity = juce::jlimit(0.0f, 1.0f, density);
}

void MelodyForge::setRestProbability(float probability)
{
    restProbability = juce::jlimit(0.0f, 1.0f, probability);
}

void MelodyForge::setIntervalRange(int maxIntervalSemitones)
{
    maxInterval = juce::jlimit(1, 24, maxIntervalSemitones);
}

void MelodyForge::setRepetitionAmount(float amount)
{
    repetitionAmount = juce::jlimit(0.0f, 1.0f, amount);
}

//==============================================================================
// Helper Functions

MelodyForge::MelodyNote MelodyForge::generateNote(const ChordGenius::Chord& currentChord,
                                                  const std::vector<int>& scaleNotes,
                                                  const MelodyNote& previousNote,
                                                  MelodicContour contour)
{
    MelodyNote note;
    note.velocity = static_cast<uint8>(80 + uniformDist(randomEngine) * 40);
    note.isRest = false;

    // Get chord tones
    auto chordTones = getChordTones(currentChord, 4, 6);

    // 60% chance of chord tone, 40% scale tone
    bool useChordTone = (uniformDist(randomEngine) < 0.6f);

    if (useChordTone && !chordTones.empty())
    {
        // Pick chord tone close to previous note
        int closest = chordTones[0];
        int minDist = std::abs(previousNote.pitch - closest);

        for (int tone : chordTones)
        {
            int dist = std::abs(previousNote.pitch - tone);
            if (dist < minDist && dist <= maxInterval)
            {
                minDist = dist;
                closest = tone;
            }
        }

        note.pitch = closest;
    }
    else
    {
        // Pick scale note
        std::vector<int> candidates;

        for (int scalePitch : scaleNotes)
        {
            int interval = std::abs(scalePitch - previousNote.pitch);
            if (interval <= maxInterval)
                candidates.push_back(scalePitch);
        }

        if (!candidates.empty())
        {
            int index = static_cast<int>(uniformDist(randomEngine) * candidates.size());
            note.pitch = candidates[index % candidates.size()];
        }
        else
        {
            note.pitch = previousNote.pitch;
        }
    }

    return note;
}

std::vector<double> MelodyForge::getRhythmDurations(RhythmPattern pattern, double bpm)
{
    std::vector<double> durations;
    double quarterNote = 60.0 / bpm;
    double eighthNote = quarterNote / 2.0;
    double sixteenthNote = quarterNote / 4.0;

    switch (pattern)
    {
        case RhythmPattern::Straight:
            durations = {quarterNote, quarterNote, quarterNote, quarterNote};
            break;

        case RhythmPattern::EighthNotes:
            durations = {eighthNote, eighthNote, eighthNote, eighthNote,
                        eighthNote, eighthNote, eighthNote, eighthNote};
            break;

        case RhythmPattern::Sixteenths:
            for (int i = 0; i < 16; ++i)
                durations.push_back(sixteenthNote);
            break;

        case RhythmPattern::Triplets:
        {
            double triplet = quarterNote / 3.0;
            durations = {triplet, triplet, triplet, triplet, triplet, triplet};
            break;
        }

        case RhythmPattern::SwingEighths:
        {
            double longEighth = quarterNote * 0.667;
            double shortEighth = quarterNote * 0.333;
            durations = {longEighth, shortEighth, longEighth, shortEighth,
                        longEighth, shortEighth, longEighth, shortEighth};
            break;
        }

        case RhythmPattern::Syncopated:
            durations = {eighthNote, quarterNote, eighthNote, quarterNote, eighthNote};
            break;

        case RhythmPattern::Dotted:
            durations = {quarterNote * 1.5, eighthNote, quarterNote, quarterNote};
            break;

        case RhythmPattern::Mixed:
            durations = {quarterNote, eighthNote, eighthNote, quarterNote,
                        eighthNote, eighthNote, quarterNote};
            break;

        default:
            durations = {quarterNote};
            break;
    }

    return durations;
}

std::vector<int> MelodyForge::getScaleNotes(int rootNote, ChordGenius::Scale scale,
                                            int octaveMin, int octaveMax)
{
    std::vector<int> notes;

    auto scaleIntervals = ChordGenius::SCALE_INTERVALS.at(scale);

    for (int octave = octaveMin; octave <= octaveMax; ++octave)
    {
        for (int interval : scaleIntervals)
        {
            int midiNote = 12 + octave * 12 + rootNote + interval;
            notes.push_back(midiNote);
        }
    }

    return notes;
}

int MelodyForge::getNextPitchFromContour(int currentPitch, MelodicContour contour,
                                        const std::vector<int>& scaleNotes, int& contourPosition)
{
    if (scaleNotes.empty())
        return currentPitch;

    // Find current position in scale
    auto it = std::find(scaleNotes.begin(), scaleNotes.end(), currentPitch);
    int currentIndex = (it != scaleNotes.end()) ? static_cast<int>(it - scaleNotes.begin()) : scaleNotes.size() / 2;

    int nextIndex = currentIndex;

    switch (contour)
    {
        case MelodicContour::Ascending:
            nextIndex = std::min(currentIndex + 1, static_cast<int>(scaleNotes.size()) - 1);
            break;

        case MelodicContour::Descending:
            nextIndex = std::max(currentIndex - 1, 0);
            break;

        case MelodicContour::Arch:
            if (contourPosition < 50)
                nextIndex = std::min(currentIndex + 1, static_cast<int>(scaleNotes.size()) - 1);
            else
                nextIndex = std::max(currentIndex - 1, 0);
            contourPosition++;
            break;

        case MelodicContour::Valley:
            if (contourPosition < 50)
                nextIndex = std::max(currentIndex - 1, 0);
            else
                nextIndex = std::min(currentIndex + 1, static_cast<int>(scaleNotes.size()) - 1);
            contourPosition++;
            break;

        case MelodicContour::Zigzag:
            if (contourPosition % 2 == 0)
                nextIndex = std::min(currentIndex + 1, static_cast<int>(scaleNotes.size()) - 1);
            else
                nextIndex = std::max(currentIndex - 1, 0);
            contourPosition++;
            break;

        case MelodicContour::Stepwise:
            nextIndex = currentIndex + (uniformDist(randomEngine) > 0.5f ? 1 : -1);
            nextIndex = juce::jlimit(0, static_cast<int>(scaleNotes.size()) - 1, nextIndex);
            break;

        case MelodicContour::LeapFriendly:
        {
            int leap = static_cast<int>((uniformDist(randomEngine) - 0.5f) * 10);
            nextIndex = juce::jlimit(0, static_cast<int>(scaleNotes.size()) - 1, currentIndex + leap);
            break;
        }

        default:  // Random/Plateau
            nextIndex = static_cast<int>(uniformDist(randomEngine) * scaleNotes.size());
            break;
    }

    return scaleNotes[nextIndex];
}

std::vector<int> MelodyForge::getChordTones(const ChordGenius::Chord& chord, int octaveMin, int octaveMax)
{
    std::vector<int> tones;

    for (int octave = octaveMin; octave <= octaveMax; ++octave)
    {
        int baseMidi = 12 + octave * 12 + chord.root;
        auto intervals = ChordGenius::CHORD_INTERVALS.at(chord.quality);

        for (int interval : intervals)
            tones.push_back(baseMidi + interval);
    }

    return tones;
}

bool MelodyForge::isChordTone(int pitch, const ChordGenius::Chord& chord)
{
    int pitchClass = pitch % 12;
    int chordRoot = chord.root % 12;
    int interval = (pitchClass - chordRoot + 12) % 12;

    auto intervals = ChordGenius::CHORD_INTERVALS.at(chord.quality);
    return std::find(intervals.begin(), intervals.end(), interval) != intervals.end();
}

void MelodyForge::applyGenreStyle(const std::string& genre)
{
    if (genre == "Pop")
    {
        noteDensity = 0.7f;
        restProbability = 0.15f;
        maxInterval = 7;
    }
    else if (genre == "Jazz")
    {
        noteDensity = 0.8f;
        restProbability = 0.1f;
        maxInterval = 12;
    }
    else if (genre == "Classical")
    {
        noteDensity = 0.75f;
        restProbability = 0.12f;
        maxInterval = 5;
    }
    else if (genre == "EDM")
    {
        noteDensity = 0.9f;
        restProbability = 0.05f;
        maxInterval = 12;
    }
    else if (genre == "Hip-Hop")
    {
        noteDensity = 0.5f;
        restProbability = 0.25f;
        maxInterval = 7;
    }
}
