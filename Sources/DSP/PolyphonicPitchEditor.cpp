#include "PolyphonicPitchEditor.h"

PolyphonicPitchEditor::PolyphonicPitchEditor()
{
}

void PolyphonicPitchEditor::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;
    currentBlockSize = maxBlockSize;
}

void PolyphonicPitchEditor::reset()
{
    detectedNotes.clear();
    notePitchCorrections.clear();
    noteFormantShifts.clear();
    noteTimingCorrections.clear();
    noteAmplitudeCorrections.clear();
    noteEnabledStates.clear();
}

void PolyphonicPitchEditor::process(juce::AudioBuffer<float>& buffer)
{
    if (pitchCorrectionStrength < 0.01f)
        return;  // Bypass if strength is too low

    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // Apply bio-reactive modulation
    float effectiveStrength = pitchCorrectionStrength;
    if (bioReactiveEnabled)
    {
        effectiveStrength *= (0.5f + currentCoherence * 0.5f);
    }

    // Simple pitch correction simulation
    // In a real implementation, this would use phase vocoder or similar
    for (int ch = 0; ch < numChannels; ++ch)
    {
        auto* channelData = buffer.getWritePointer(ch);

        for (int i = 0; i < numSamples; ++i)
        {
            float sample = channelData[i];

            // Apply subtle pitch modulation based on correction strength
            float modulation = std::sin(static_cast<float>(i) * 0.01f) * effectiveStrength * 0.05f;
            channelData[i] = sample * (1.0f + modulation);
        }
    }
}

void PolyphonicPitchEditor::analyzeAudio(const juce::AudioBuffer<float>& buffer, double sampleRate)
{
    detectedNotes.clear();

    // Simple note detection simulation
    // In real implementation, would use FFT or autocorrelation
    int numNotesToDetect = random.nextInt(5) + 1;  // 1-5 notes

    for (int i = 0; i < numNotesToDetect; ++i)
    {
        DetectedNote note;
        note.noteID = i;
        note.frequency = 200.0f + random.nextFloat() * 400.0f;
        note.pitchCents = (random.nextFloat() * 2.0f - 1.0f) * 50.0f;
        note.confidence = 0.5f + random.nextFloat() * 0.5f;
        note.amplitude = 0.3f + random.nextFloat() * 0.7f;

        detectedNotes.push_back(note);
    }
}

void PolyphonicPitchEditor::setPitchCorrectionStrength(float strength)
{
    pitchCorrectionStrength = juce::jlimit(0.0f, 1.0f, strength);
}

void PolyphonicPitchEditor::setFormantPreservationEnabled(bool enabled)
{
    formantPreservationEnabled = enabled;
}

void PolyphonicPitchEditor::setScale(Scale scale, int root)
{
    currentScale = scale;
    rootNote = root % 12;
}

void PolyphonicPitchEditor::quantizeToScale()
{
    // Quantize all detected notes to the current scale
    for (auto& note : detectedNotes)
    {
        int midiNote = static_cast<int>(std::round(69 + 12 * std::log2(note.frequency / 440.0f)));
        int nearestScaleNote = getNearestScaleNote(midiNote);
        float targetFreq = 440.0f * std::pow(2.0f, (nearestScaleNote - 69) / 12.0f);
        note.frequency = targetFreq;
        note.pitchCents = 0.0f;
    }
}

void PolyphonicPitchEditor::setNotePitchCorrection(int noteID, float cents)
{
    notePitchCorrections[noteID] = juce::jlimit(-100.0f, 100.0f, cents);
}

void PolyphonicPitchEditor::setNoteFormantShift(int noteID, float semitones)
{
    noteFormantShifts[noteID] = juce::jlimit(-12.0f, 12.0f, semitones);
}

void PolyphonicPitchEditor::setNoteTimingCorrection(int noteID, double ms)
{
    noteTimingCorrections[noteID] = juce::jlimit(-50.0, 50.0, ms);
}

void PolyphonicPitchEditor::setNoteAmplitudeCorrection(int noteID, float amplitude)
{
    noteAmplitudeCorrections[noteID] = juce::jlimit(0.0f, 2.0f, amplitude);
}

void PolyphonicPitchEditor::setNoteEnabled(int noteID, bool enabled)
{
    noteEnabledStates[noteID] = enabled;
}

void PolyphonicPitchEditor::setBioReactiveEnabled(bool enabled)
{
    bioReactiveEnabled = enabled;
}

void PolyphonicPitchEditor::setBioData(float hrv, float coherence, float stress)
{
    currentHRV = hrv;
    currentCoherence = coherence;
    currentStress = stress;
}

bool PolyphonicPitchEditor::isNoteInScale(int midiNote) const
{
    int noteInKey = (midiNote - rootNote + 12) % 12;

    switch (currentScale)
    {
        case Scale::Chromatic:
            return true;

        case Scale::Major:
            return (noteInKey == 0 || noteInKey == 2 || noteInKey == 4 ||
                   noteInKey == 5 || noteInKey == 7 || noteInKey == 9 || noteInKey == 11);

        case Scale::Minor:
            return (noteInKey == 0 || noteInKey == 2 || noteInKey == 3 ||
                   noteInKey == 5 || noteInKey == 7 || noteInKey == 8 || noteInKey == 10);

        case Scale::HarmonicMinor:
            return (noteInKey == 0 || noteInKey == 2 || noteInKey == 3 ||
                   noteInKey == 5 || noteInKey == 7 || noteInKey == 8 || noteInKey == 11);

        case Scale::MelodicMinor:
            return (noteInKey == 0 || noteInKey == 2 || noteInKey == 3 ||
                   noteInKey == 5 || noteInKey == 7 || noteInKey == 9 || noteInKey == 11);

        case Scale::Pentatonic:
            return (noteInKey == 0 || noteInKey == 2 || noteInKey == 4 ||
                   noteInKey == 7 || noteInKey == 9);

        case Scale::Blues:
            return (noteInKey == 0 || noteInKey == 3 || noteInKey == 5 ||
                   noteInKey == 6 || noteInKey == 7 || noteInKey == 10);

        case Scale::Dorian:
        case Scale::Phrygian:
        case Scale::Lydian:
        case Scale::Mixolydian:
            // Modal scales - simplified implementation
            return true;

        default:
            return true;
    }
}

int PolyphonicPitchEditor::getNearestScaleNote(int midiNote) const
{
    if (currentScale == Scale::Chromatic)
        return midiNote;

    // Find nearest note in scale
    for (int offset = 0; offset < 12; ++offset)
    {
        if (isNoteInScale(midiNote + offset))
            return midiNote + offset;
        if (isNoteInScale(midiNote - offset))
            return midiNote - offset;
    }

    return midiNote;
}
