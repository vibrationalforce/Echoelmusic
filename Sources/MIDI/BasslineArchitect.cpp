#include "BasslineArchitect.h"
#include <algorithm>
#include <cmath>

BasslineArchitect::BasslineArchitect()
    : uniformDist(0.0f, 1.0f)
{
    randomEngine.seed(static_cast<unsigned int>(std::time(nullptr)));
}

BasslineArchitect::~BasslineArchitect()
{
}

//==============================================================================
// Bassline Generation

BasslineArchitect::Bassline BasslineArchitect::generateBassline(const ChordGenius::Progression& progression,
                                                                GrooveStyle groove, int numBars, double bpm)
{
    return generateBasslineWithPattern(progression, PatternType::RootFifth, groove, numBars, bpm);
}

BasslineArchitect::Bassline BasslineArchitect::generateBasslineWithPattern(
    const ChordGenius::Progression& progression,
    PatternType pattern,
    GrooveStyle groove,
    int numBars,
    double bpm)
{
    Bassline bassline;
    bassline.key = progression.key;
    bassline.scale = progression.scale;
    bassline.bpm = bpm;

    // Get groove rhythm
    auto rhythmDurations = getGrooveRhythm(groove, bpm);

    // Calculate total duration
    double beatsPerBar = 4.0;
    double secondsPerBeat = 60.0 / bpm;
    double totalDuration = numBars * beatsPerBar * secondsPerBeat;
    double chordDuration = totalDuration / progression.chords.size();

    // Generate bass notes
    double currentTime = 0.0;
    int rhythmIndex = 0;
    BassNote* previousNote = nullptr;

    while (currentTime < totalDuration)
    {
        // Get current chord
        int chordIndex = static_cast<int>(currentTime / chordDuration) % progression.chords.size();
        const auto& currentChord = progression.chords[chordIndex];

        // Get duration from groove
        double duration = rhythmDurations[rhythmIndex % rhythmDurations.size()];

        // Generate note
        BassNote note = generateBassNote(currentChord, pattern, currentTime, duration, previousNote);

        // Check for rest
        if (uniformDist(randomEngine) < restProbability)
            note.isRest = true;

        bassline.notes.push_back(note);

        currentTime += duration;
        rhythmIndex++;
        if (!note.isRest)
            previousNote = &bassline.notes.back();
    }

    // Apply groove-specific articulation
    applyGrooveArticulation(bassline, groove);

    return bassline;
}

BasslineArchitect::Bassline BasslineArchitect::generateWalkingBass(const ChordGenius::Progression& progression,
                                                                    int numBars, double bpm)
{
    Bassline bassline;
    bassline.key = progression.key;
    bassline.scale = progression.scale;
    bassline.bpm = bpm;
    bassline.groove = "Walking Bass";

    double quarterNote = 60.0 / bpm;
    double totalDuration = numBars * 4.0 * quarterNote;
    double chordDuration = totalDuration / progression.chords.size();

    auto scaleIntervals = ChordGenius::SCALE_INTERVALS.at(progression.scale);

    double currentTime = 0.0;
    int beatCount = 0;

    while (currentTime < totalDuration)
    {
        int chordIndex = static_cast<int>(currentTime / chordDuration) % progression.chords.size();
        const auto& currentChord = progression.chords[chordIndex];
        const auto* nextChord = (chordIndex + 1 < progression.chords.size()) ?
                               &progression.chords[chordIndex + 1] : &progression.chords[0];

        BassNote note;
        note.startTime = currentTime;
        note.duration = quarterNote * 0.95;  // Slightly staccato
        note.velocity = static_cast<uint8>(90 + uniformDist(randomEngine) * 20);

        int beatInChord = beatCount % 4;

        if (beatInChord == 0)
        {
            // Beat 1: Root
            note.pitch = 24 + bassOctave * 12 + currentChord.root;
        }
        else if (beatInChord == 1)
        {
            // Beat 2: Third or fifth
            auto chordIntervals = ChordGenius::CHORD_INTERVALS.at(currentChord.quality);
            int interval = (chordIntervals.size() >= 2) ? chordIntervals[1] : 7;
            note.pitch = 24 + bassOctave * 12 + currentChord.root + interval;
        }
        else if (beatInChord == 2)
        {
            // Beat 3: Fifth or scale tone
            note.pitch = 24 + bassOctave * 12 + currentChord.root + 7;
        }
        else
        {
            // Beat 4: Chromatic approach to next chord
            int nextRoot = 24 + bassOctave * 12 + nextChord->root;
            note.pitch = getChromaticApproach(nextRoot, uniformDist(randomEngine) > 0.5f);
        }

        bassline.notes.push_back(note);

        currentTime += quarterNote;
        beatCount++;
    }

    return bassline;
}

BasslineArchitect::Bassline BasslineArchitect::generateFunkBass(const ChordGenius::Progression& progression,
                                                                 int numBars, double bpm)
{
    auto bassline = generateBasslineWithPattern(progression, PatternType::RootOctave,
                                                GrooveStyle::Funk, numBars, bpm);

    // Add funk articulation
    addGhostNotes(bassline, 0.25f);
    addSlides(bassline, 0.15f);

    // Accent on 1 and 3
    double quarterNote = 60.0 / bpm;
    for (auto& note : bassline.notes)
    {
        double beatPosition = fmod(note.startTime / quarterNote, 4.0);
        if (beatPosition < 0.1 || (beatPosition > 1.9 && beatPosition < 2.1))
            note.velocity = juce::jmin(127, static_cast<int>(note.velocity) + 20);
    }

    return bassline;
}

BasslineArchitect::Bassline BasslineArchitect::generateEDMBass(const ChordGenius::Progression& progression,
                                                                const std::string& edmStyle,
                                                                int numBars, double bpm)
{
    GrooveStyle groove = GrooveStyle::House;

    if (edmStyle == "House" || edmStyle == "Techno")
        groove = GrooveStyle::House;
    else if (edmStyle == "DubStep" || edmStyle == "Trap")
        groove = GrooveStyle::DubStep;
    else if (edmStyle == "DnB" || edmStyle == "Jungle")
        groove = GrooveStyle::DnB;

    return generateBasslineWithPattern(progression, PatternType::RootOnly, groove, numBars, bpm);
}

//==============================================================================
// Bassline Transformation

BasslineArchitect::Bassline BasslineArchitect::transposeBassline(const Bassline& bassline, int semitones)
{
    Bassline transposed = bassline;
    transposed.key = (bassline.key + semitones + 120) % 12;

    for (auto& note : transposed.notes)
    {
        if (!note.isRest)
            note.pitch += semitones;
    }

    return transposed;
}

void BasslineArchitect::addSlides(Bassline& bassline, float probability)
{
    for (size_t i = 0; i < bassline.notes.size() - 1; ++i)
    {
        if (bassline.notes[i].isRest || bassline.notes[i + 1].isRest)
            continue;

        if (uniformDist(randomEngine) < probability)
        {
            int interval = std::abs(bassline.notes[i + 1].pitch - bassline.notes[i].pitch);
            if (interval <= 5)  // Only slide over small intervals
                bassline.notes[i].hasSlide = true;
        }
    }
}

void BasslineArchitect::addGhostNotes(Bassline& bassline, float probability)
{
    std::vector<BassNote> notesWithGhosts;

    for (const auto& note : bassline.notes)
    {
        notesWithGhosts.push_back(note);

        // Chance to add ghost note before this note
        if (!note.isRest && uniformDist(randomEngine) < probability)
        {
            BassNote ghost;
            ghost.pitch = note.pitch;
            ghost.startTime = note.startTime - note.duration * 0.15;
            ghost.duration = note.duration * 0.1;
            ghost.velocity = 40;  // Very low velocity
            ghost.isGhost = true;

            notesWithGhosts.insert(notesWithGhosts.end() - 1, ghost);
        }
    }

    bassline.notes = notesWithGhosts;
}

void BasslineArchitect::applySwing(Bassline& bassline, float swingAmount)
{
    double eighthNoteDuration = 60.0 / bassline.bpm / 2.0;

    for (auto& note : bassline.notes)
    {
        double beatPosition = fmod(note.startTime / eighthNoteDuration, 2.0);

        if (beatPosition > 0.9 && beatPosition < 1.1)  // Second eighth
        {
            note.startTime += eighthNoteDuration * swingAmount * 0.33;
        }
    }
}

void BasslineArchitect::humanizeBassline(Bassline& bassline, float amount)
{
    for (auto& note : bassline.notes)
    {
        if (note.isRest || note.isGhost)
            continue;

        // Timing variation
        float timingVariation = (uniformDist(randomEngine) - 0.5f) * 0.015f * amount;
        note.startTime += timingVariation;

        // Duration variation
        float durationVariation = 1.0f + (uniformDist(randomEngine) - 0.5f) * 0.15f * amount;
        note.duration *= durationVariation;

        // Velocity variation
        int velocityVariation = static_cast<int>((uniformDist(randomEngine) - 0.5f) * 30.0f * amount);
        note.velocity = static_cast<uint8>(juce::jlimit(40, 127, static_cast<int>(note.velocity) + velocityVariation));
    }
}

//==============================================================================
// MIDI Export

void BasslineArchitect::basslineToMidiBuffer(const Bassline& bassline, juce::MidiBuffer& buffer)
{
    buffer.clear();

    for (const auto& note : bassline.notes)
    {
        if (note.isRest)
            continue;

        int startSample = static_cast<int>(note.startTime * 44100.0);
        int endSample = static_cast<int>((note.startTime + note.duration) * 44100.0);

        buffer.addEvent(juce::MidiMessage::noteOn(1, note.pitch, note.velocity), startSample);

        // Add pitch bend for slide
        if (note.hasSlide)
        {
            for (int i = 0; i < 10; ++i)
            {
                int sample = startSample + (endSample - startSample) * i / 10;
                int bendValue = 8192 + (i * 819);  // Gradually bend up
                buffer.addEvent(juce::MidiMessage::pitchWheel(1, bendValue), sample);
            }
        }

        buffer.addEvent(juce::MidiMessage::noteOff(1, note.pitch), endSample);
    }
}

bool BasslineArchitect::exportBasslineToMidi(const Bassline& bassline, const juce::File& outputFile)
{
    juce::MidiFile midiFile;
    juce::MidiMessageSequence sequence;

    double ticksPerQuarterNote = 480;
    midiFile.setTicksPerQuarterNote(static_cast<int>(ticksPerQuarterNote));

    for (const auto& note : bassline.notes)
    {
        if (note.isRest)
            continue;

        double ticksPerSecond = ticksPerQuarterNote * (bassline.bpm / 60.0);
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

void BasslineArchitect::setOctaveRange(int octave)
{
    bassOctave = juce::jlimit(1, 4, octave);
}

void BasslineArchitect::setNoteDensity(float density)
{
    noteDensity = juce::jlimit(0.0f, 1.0f, density);
}

void BasslineArchitect::setRestProbability(float probability)
{
    restProbability = juce::jlimit(0.0f, 1.0f, probability);
}

//==============================================================================
// Helper Functions

std::vector<double> BasslineArchitect::getGrooveRhythm(GrooveStyle groove, double bpm)
{
    std::vector<double> rhythm;
    double quarterNote = 60.0 / bpm;
    double eighthNote = quarterNote / 2.0;
    double sixteenthNote = quarterNote / 4.0;

    switch (groove)
    {
        case GrooveStyle::Straight:
            rhythm = {quarterNote, quarterNote, quarterNote, quarterNote};
            break;

        case GrooveStyle::Syncopated:
            rhythm = {eighthNote, eighthNote, quarterNote, eighthNote, eighthNote};
            break;

        case GrooveStyle::Funk:
            rhythm = {sixteenthNote, sixteenthNote, eighthNote, sixteenthNote,
                     sixteenthNote, eighthNote, sixteenthNote, sixteenthNote};
            break;

        case GrooveStyle::Disco:
        case GrooveStyle::House:
            rhythm = {quarterNote, quarterNote, quarterNote, quarterNote};
            break;

        case GrooveStyle::Reggae:
            rhythm = {0.0, quarterNote, 0.0, quarterNote};  // Off-beat
            break;

        case GrooveStyle::DubStep:
            rhythm = {quarterNote * 2, quarterNote * 2};  // Half-time
            break;

        case GrooveStyle::DnB:
            rhythm = {eighthNote, eighthNote, eighthNote, eighthNote,
                     eighthNote, eighthNote, eighthNote, eighthNote};
            break;

        case GrooveStyle::Techno:
            rhythm = {sixteenthNote, sixteenthNote, sixteenthNote, sixteenthNote,
                     sixteenthNote, sixteenthNote, sixteenthNote, sixteenthNote};
            break;

        case GrooveStyle::Rock:
            rhythm = {eighthNote, eighthNote, eighthNote, quarterNote, eighthNote};
            break;

        case GrooveStyle::WalkingBass:
            rhythm = {quarterNote, quarterNote, quarterNote, quarterNote};
            break;

        default:
            rhythm = {quarterNote};
            break;
    }

    return rhythm;
}

std::vector<int> BasslineArchitect::getBassNotesForChord(const ChordGenius::Chord& chord, PatternType pattern)
{
    std::vector<int> notes;
    int root = 24 + bassOctave * 12 + chord.root;

    switch (pattern)
    {
        case PatternType::RootOnly:
            notes = {root};
            break;

        case PatternType::RootFifth:
            notes = {root, root + 7};
            break;

        case PatternType::RootOctave:
            notes = {root, root + 12};
            break;

        case PatternType::Arpeggio:
        {
            auto intervals = ChordGenius::CHORD_INTERVALS.at(chord.quality);
            for (int interval : intervals)
                notes.push_back(root + interval);
            break;
        }

        case PatternType::Pedal:
            notes = {root};
            break;

        default:
            notes = {root};
            break;
    }

    return notes;
}

BasslineArchitect::BassNote BasslineArchitect::generateBassNote(
    const ChordGenius::Chord& currentChord,
    PatternType pattern,
    double startTime,
    double duration,
    const BassNote* previousNote)
{
    BassNote note;
    note.startTime = startTime;
    note.duration = duration * 0.9;  // Slightly shorter for groove
    note.velocity = static_cast<uint8>(80 + uniformDist(randomEngine) * 30);
    note.isRest = false;

    auto bassNotes = getBassNotesForChord(currentChord, pattern);

    if (previousNote && pattern != PatternType::RootOnly)
    {
        // Pick closest note to previous
        int closest = bassNotes[0];
        int minDist = 127;

        for (int pitch : bassNotes)
        {
            int dist = std::abs(pitch - previousNote->pitch);
            if (dist < minDist)
            {
                minDist = dist;
                closest = pitch;
            }
        }

        note.pitch = closest;
    }
    else
    {
        // Pick from available notes
        int index = static_cast<int>(uniformDist(randomEngine) * bassNotes.size());
        note.pitch = bassNotes[index % bassNotes.size()];
    }

    return note;
}

int BasslineArchitect::getChromaticApproach(int targetNote, bool fromBelow)
{
    return fromBelow ? targetNote - 1 : targetNote + 1;
}

void BasslineArchitect::applyGrooveArticulation(Bassline& bassline, GrooveStyle groove)
{
    switch (groove)
    {
        case GrooveStyle::Funk:
            addGhostNotes(bassline, 0.2f);
            addSlides(bassline, 0.15f);
            break;

        case GrooveStyle::Reggae:
            // Shorten notes for staccato feel
            for (auto& note : bassline.notes)
                note.duration *= 0.7f;
            break;

        case GrooveStyle::DubStep:
            // Add slides
            addSlides(bassline, 0.3f);
            break;

        case GrooveStyle::WalkingBass:
            // Slightly legato
            for (auto& note : bassline.notes)
                note.duration *= 1.05f;
            break;

        default:
            break;
    }
}
