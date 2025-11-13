#include "ArpWeaver.h"
#include <algorithm>
#include <cmath>

ArpWeaver::ArpWeaver()
    : uniformDist(0.0f, 1.0f)
{
    randomEngine.seed(static_cast<unsigned int>(std::time(nullptr)));
}

ArpWeaver::~ArpWeaver()
{
}

//==============================================================================
// Arpeggio Generation

ArpWeaver::Arpeggio ArpWeaver::generateArpeggio(const ChordGenius::Chord& chord,
                                                ArpPattern pattern, int numBars, double bpm)
{
    return generateArpeggioWithDivision(chord, pattern, TimeDivision::Sixteenth, numBars, bpm);
}

ArpWeaver::Arpeggio ArpWeaver::generateArpeggioWithDivision(const ChordGenius::Chord& chord,
                                                             ArpPattern pattern,
                                                             TimeDivision division,
                                                             int numBars,
                                                             double bpm)
{
    Arpeggio arpeggio;
    arpeggio.pattern = pattern;
    arpeggio.bpm = bpm;

    // Generate note pool with octave range
    auto notePool = generateNotesForOctaveRange(chord);

    // Get pattern sequence
    auto sequence = getPatternSequence(notePool, pattern);

    // Get note duration from time division
    double noteDuration = getTimeDivisionDuration(division, bpm);
    double barDuration = 4.0 * (60.0 / bpm);  // 4 beats per bar
    double totalDuration = numBars * barDuration;

    // Generate arpeggio notes
    double currentTime = 0.0;
    int sequenceIndex = 0;

    while (currentTime < totalDuration)
    {
        if (sequence.empty())
            break;

        ArpNote note;
        note.pitch = sequence[sequenceIndex % sequence.size()];
        note.startTime = currentTime;
        note.duration = noteDuration * gate;
        note.velocity = static_cast<uint8>(baseVelocity + (uniformDist(randomEngine) - 0.5f) * velocityRange);
        note.isAccent = false;

        arpeggio.notes.push_back(note);

        currentTime += noteDuration;
        sequenceIndex++;
    }

    // Apply accents
    applyAccents(arpeggio);

    return arpeggio;
}

ArpWeaver::Arpeggio ArpWeaver::generateArpeggioSequence(const ChordGenius::Progression& progression,
                                                         ArpPattern pattern,
                                                         double bpm)
{
    Arpeggio sequencedArp;
    sequencedArp.pattern = pattern;
    sequencedArp.bpm = bpm;

    double totalDuration = 0.0;

    for (const auto& chord : progression.chords)
    {
        auto chordArp = generateArpeggioWithDivision(chord, pattern, TimeDivision::Sixteenth, 1, bpm);

        // Offset notes by current duration
        for (auto& note : chordArp.notes)
        {
            note.startTime += totalDuration;
            sequencedArp.notes.push_back(note);
        }

        totalDuration += 4.0 * (60.0 / bpm);  // 1 bar per chord
    }

    return sequencedArp;
}

//==============================================================================
// Parameters

void ArpWeaver::setOctaveRange(int octaves)
{
    octaveRange = juce::jlimit(1, 4, octaves);
}

void ArpWeaver::setGate(float gateAmount)
{
    gate = juce::jlimit(0.1f, 1.0f, gateAmount);
}

void ArpWeaver::setSwing(float swing)
{
    swingAmount = juce::jlimit(0.0f, 1.0f, swing);
}

void ArpWeaver::setVelocity(uint8 velocity)
{
    baseVelocity = juce::jlimit(uint8(1), uint8(127), velocity);
}

void ArpWeaver::setVelocityRange(uint8 range)
{
    velocityRange = juce::jlimit(uint8(0), uint8(127), range);
}

void ArpWeaver::setAccentPattern(const std::vector<bool>& pattern)
{
    if (!pattern.empty())
        accentPattern = pattern;
}

void ArpWeaver::setLatchMode(bool enabled)
{
    latchMode = enabled;
}

//==============================================================================
// Transformation

void ArpWeaver::applySwing(Arpeggio& arpeggio, float swingAmt)
{
    if (arpeggio.notes.empty())
        return;

    double noteDuration = (arpeggio.notes.size() > 1) ?
        (arpeggio.notes[1].startTime - arpeggio.notes[0].startTime) : 0.125;

    for (size_t i = 1; i < arpeggio.notes.size(); i += 2)
    {
        // Delay every second note
        arpeggio.notes[i].startTime += noteDuration * swingAmt * 0.33;
    }
}

void ArpWeaver::humanizeArpeggio(Arpeggio& arpeggio, float amount)
{
    for (auto& note : arpeggio.notes)
    {
        // Timing variation (±5ms)
        float timingVariation = (uniformDist(randomEngine) - 0.5f) * 0.01f * amount;
        note.startTime += timingVariation;

        // Velocity variation
        int velocityVariation = static_cast<int>((uniformDist(randomEngine) - 0.5f) * 30.0f * amount);
        note.velocity = static_cast<uint8>(juce::jlimit(20, 127,
                                           static_cast<int>(note.velocity) + velocityVariation));
    }
}

ArpWeaver::Arpeggio ArpWeaver::transposeArpeggio(const Arpeggio& arpeggio, int semitones)
{
    Arpeggio transposed = arpeggio;

    for (auto& note : transposed.notes)
        note.pitch += semitones;

    return transposed;
}

//==============================================================================
// MIDI Export

void ArpWeaver::arpeggioToMidiBuffer(const Arpeggio& arpeggio, juce::MidiBuffer& buffer)
{
    buffer.clear();

    for (const auto& note : arpeggio.notes)
    {
        int startSample = static_cast<int>(note.startTime * 44100.0);
        int endSample = static_cast<int>((note.startTime + note.duration) * 44100.0);

        buffer.addEvent(juce::MidiMessage::noteOn(1, note.pitch, note.velocity), startSample);
        buffer.addEvent(juce::MidiMessage::noteOff(1, note.pitch), endSample);
    }
}

bool ArpWeaver::exportArpeggioToMidi(const Arpeggio& arpeggio, const juce::File& outputFile)
{
    juce::MidiFile midiFile;
    juce::MidiMessageSequence sequence;

    double ticksPerQuarterNote = 480;
    midiFile.setTicksPerQuarterNote(static_cast<int>(ticksPerQuarterNote));

    for (const auto& note : arpeggio.notes)
    {
        double ticksPerSecond = ticksPerQuarterNote * (arpeggio.bpm / 60.0);
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
// Helper Functions

double ArpWeaver::getTimeDivisionDuration(TimeDivision division, double bpm)
{
    double quarterNote = 60.0 / bpm;

    switch (division)
    {
        case TimeDivision::Whole:           return quarterNote * 4.0;
        case TimeDivision::Half:            return quarterNote * 2.0;
        case TimeDivision::Quarter:         return quarterNote;
        case TimeDivision::Eighth:          return quarterNote / 2.0;
        case TimeDivision::Sixteenth:       return quarterNote / 4.0;
        case TimeDivision::ThirtySecond:    return quarterNote / 8.0;
        case TimeDivision::DottedHalf:      return quarterNote * 3.0;
        case TimeDivision::DottedQuarter:   return quarterNote * 1.5;
        case TimeDivision::DottedEighth:    return quarterNote * 0.75;
        case TimeDivision::TripletQuarter:  return quarterNote * 2.0 / 3.0;
        case TimeDivision::TripletEighth:   return quarterNote / 3.0;
        case TimeDivision::TripletSixteenth: return quarterNote / 6.0;
        default:                            return quarterNote / 4.0;
    }
}

std::vector<int> ArpWeaver::getPatternSequence(const std::vector<int>& chordNotes, ArpPattern pattern)
{
    std::vector<int> sequence;

    if (chordNotes.empty())
        return sequence;

    switch (pattern)
    {
        case ArpPattern::Up:
            sequence = chordNotes;
            break;

        case ArpPattern::Down:
            sequence = chordNotes;
            std::reverse(sequence.begin(), sequence.end());
            break;

        case ArpPattern::UpDown:
            sequence = chordNotes;
            for (int i = static_cast<int>(chordNotes.size()) - 2; i >= 0; --i)
                sequence.push_back(chordNotes[i]);
            break;

        case ArpPattern::UpDownExclusive:
            sequence = chordNotes;
            for (int i = static_cast<int>(chordNotes.size()) - 2; i > 0; --i)
                sequence.push_back(chordNotes[i]);
            break;

        case ArpPattern::DownUp:
        {
            auto reversed = chordNotes;
            std::reverse(reversed.begin(), reversed.end());
            sequence = reversed;
            for (size_t i = 1; i < chordNotes.size(); ++i)
                sequence.push_back(reversed[i]);
            break;
        }

        case ArpPattern::Random:
        {
            sequence = chordNotes;
            for (int i = 0; i < 16; ++i)
            {
                int index = static_cast<int>(uniformDist(randomEngine) * chordNotes.size());
                sequence.push_back(chordNotes[index % chordNotes.size()]);
            }
            break;
        }

        case ArpPattern::Chord:
            // All notes at once (handled differently in generation)
            sequence = {chordNotes[0]};
            break;

        case ArpPattern::PingPong:
            sequence = chordNotes;
            for (int i = static_cast<int>(chordNotes.size()) - 2; i > 0; --i)
                sequence.push_back(chordNotes[i]);
            break;

        case ArpPattern::Converge:
        {
            size_t left = 0;
            size_t right = chordNotes.size() - 1;
            while (left <= right)
            {
                sequence.push_back(chordNotes[left++]);
                if (left <= right)
                    sequence.push_back(chordNotes[right--]);
            }
            break;
        }

        case ArpPattern::Diverge:
        {
            size_t mid = chordNotes.size() / 2;
            for (size_t offset = 0; offset <= mid; ++offset)
            {
                if (mid >= offset)
                    sequence.push_back(chordNotes[mid - offset]);
                if (mid + offset < chordNotes.size())
                    sequence.push_back(chordNotes[mid + offset]);
            }
            break;
        }

        case ArpPattern::RandomWalk:
        {
            int currentIndex = 0;
            sequence.push_back(chordNotes[currentIndex]);

            for (int i = 0; i < 15; ++i)
            {
                int step = (uniformDist(randomEngine) > 0.5f) ? 1 : -1;
                currentIndex += step;
                currentIndex = juce::jlimit(0, static_cast<int>(chordNotes.size()) - 1, currentIndex);
                sequence.push_back(chordNotes[currentIndex]);
            }
            break;
        }

        default:
            sequence = chordNotes;
            break;
    }

    return sequence;
}

std::vector<int> ArpWeaver::generateNotesForOctaveRange(const ChordGenius::Chord& chord)
{
    std::vector<int> notes;

    for (int octave = 0; octave < octaveRange; ++octave)
    {
        for (int note : chord.notes)
        {
            int transposed = note + (octave * 12);
            if (transposed >= 0 && transposed <= 127)
                notes.push_back(transposed);
        }
    }

    // Sort ascending
    std::sort(notes.begin(), notes.end());

    return notes;
}

void ArpWeaver::applyAccents(Arpeggio& arpeggio)
{
    if (accentPattern.empty())
        return;

    for (size_t i = 0; i < arpeggio.notes.size(); ++i)
    {
        if (accentPattern[i % accentPattern.size()])
        {
            arpeggio.notes[i].isAccent = true;
            arpeggio.notes[i].velocity = juce::jmin(127, static_cast<int>(arpeggio.notes[i].velocity) + 20);
        }
    }
}
