#include "PolyphonicPitchEditor.h"
#include <cmath>
#include <algorithm>

//==============================================================================
// Constructor
//==============================================================================

PolyphonicPitchEditor::PolyphonicPitchEditor()
{
}

//==============================================================================
// Analysis
//==============================================================================

void PolyphonicPitchEditor::analyzeAudio(const juce::AudioBuffer<float>& audioBuffer, double sampleRate)
{
    clearNotes();

    // Detect all notes in audio
    detectPolyphonicPitch(audioBuffer, sampleRate, detectedNotes);

    DBG("Polyphonic Pitch Editor: Analyzed audio, detected " + juce::String(detectedNotes.size()) + " notes");
}

DetectedNote* PolyphonicPitchEditor::getNote(int noteID)
{
    for (auto& note : detectedNotes)
    {
        if (note.noteID == noteID)
            return &note;
    }

    return nullptr;
}

void PolyphonicPitchEditor::clearNotes()
{
    detectedNotes.clear();
    nextNoteID = 0;
}

//==============================================================================
// Global Correction Parameters
//==============================================================================

void PolyphonicPitchEditor::setPitchCorrectionStrength(float strength)
{
    pitchCorrectionStrength = juce::jlimit(0.0f, 1.0f, strength);
}

void PolyphonicPitchEditor::setPitchCorrectionSpeed(float speed)
{
    pitchCorrectionSpeed = juce::jlimit(0.0f, 1.0f, speed);
}

void PolyphonicPitchEditor::setScale(ScaleType scale, int rootNote)
{
    currentScale = scale;
    scaleRootNote = juce::jlimit(0, 11, rootNote);

    // Update custom scale array based on scale type
    std::fill(customScaleNotes.begin(), customScaleNotes.end(), false);

    switch (scale)
    {
        case ScaleType::Chromatic:
            // All notes
            std::fill(customScaleNotes.begin(), customScaleNotes.end(), true);
            break;

        case ScaleType::Major:
            // W-W-H-W-W-W-H (0, 2, 4, 5, 7, 9, 11)
            customScaleNotes[0] = customScaleNotes[2] = customScaleNotes[4] = true;
            customScaleNotes[5] = customScaleNotes[7] = customScaleNotes[9] = customScaleNotes[11] = true;
            break;

        case ScaleType::Minor:
            // W-H-W-W-H-W-W (0, 2, 3, 5, 7, 8, 10)
            customScaleNotes[0] = customScaleNotes[2] = customScaleNotes[3] = true;
            customScaleNotes[5] = customScaleNotes[7] = customScaleNotes[8] = customScaleNotes[10] = true;
            break;

        case ScaleType::HarmonicMinor:
            // W-H-W-W-H-W+H-H (0, 2, 3, 5, 7, 8, 11)
            customScaleNotes[0] = customScaleNotes[2] = customScaleNotes[3] = true;
            customScaleNotes[5] = customScaleNotes[7] = customScaleNotes[8] = customScaleNotes[11] = true;
            break;

        case ScaleType::Pentatonic:
            // Major pentatonic (0, 2, 4, 7, 9)
            customScaleNotes[0] = customScaleNotes[2] = customScaleNotes[4] = true;
            customScaleNotes[7] = customScaleNotes[9] = true;
            break;

        case ScaleType::Blues:
            // (0, 3, 5, 6, 7, 10)
            customScaleNotes[0] = customScaleNotes[3] = customScaleNotes[5] = true;
            customScaleNotes[6] = customScaleNotes[7] = customScaleNotes[10] = true;
            break;

        case ScaleType::Custom:
            // Use existing customScaleNotes
            break;

        default:
            break;
    }
}

void PolyphonicPitchEditor::setCustomScale(const std::array<bool, 12>& scale)
{
    customScaleNotes = scale;
    currentScale = ScaleType::Custom;
}

void PolyphonicPitchEditor::setFormantPreservationEnabled(bool enable)
{
    formantPreservationEnabled = enable;
}

//==============================================================================
// Individual Note Editing
//==============================================================================

void PolyphonicPitchEditor::setNotePitchCorrection(int noteID, float cents)
{
    auto* note = getNote(noteID);
    if (note == nullptr)
        return;

    float centsLimited = juce::jlimit(-200.0f, 200.0f, cents);

    // Convert cents to frequency
    float pitchRatio = std::pow(2.0f, centsLimited / 1200.0f);
    note->correctedPitch = note->originalPitch * pitchRatio;
}

void PolyphonicPitchEditor::setNoteFormantShift(int noteID, float semitones)
{
    auto* note = getNote(noteID);
    if (note == nullptr)
        return;

    note->formantShift = juce::jlimit(-12.0f, 12.0f, semitones);
}

void PolyphonicPitchEditor::setNoteTimingCorrection(int noteID, double seconds)
{
    auto* note = getNote(noteID);
    if (note == nullptr)
        return;

    note->timingCorrection = juce::jlimit(-0.5, 0.5, seconds);
}

void PolyphonicPitchEditor::setNoteAmplitudeCorrection(int noteID, float dB)
{
    auto* note = getNote(noteID);
    if (note == nullptr)
        return;

    note->amplitudeCorrection = juce::jlimit(-12.0f, 12.0f, dB);
}

void PolyphonicPitchEditor::setNoteVibratoCorrection(int noteID, float amount)
{
    auto* note = getNote(noteID);
    if (note == nullptr)
        return;

    note->vibratoCorrection = juce::jlimit(-1.0f, 1.0f, amount);
}

void PolyphonicPitchEditor::setNoteEnabled(int noteID, bool enabled)
{
    auto* note = getNote(noteID);
    if (note == nullptr)
        return;

    note->enabled = enabled;
}

//==============================================================================
// Batch Operations
//==============================================================================

void PolyphonicPitchEditor::quantizeToScale()
{
    for (auto& note : detectedNotes)
    {
        int closestScaleNote = getClosestScaleNote(note.midiNote);
        float targetFreq = midiToFreq(closestScaleNote);

        // Calculate pitch correction needed
        float centsOff = 1200.0f * std::log2(targetFreq / note.originalPitch);

        // Apply correction
        note.correctedPitch = targetFreq;
        note.pitchDrift = centsOff;
    }

    DBG("Polyphonic Pitch Editor: Quantized all notes to scale");
}

void PolyphonicPitchEditor::flattenVibrato()
{
    for (auto& note : detectedNotes)
    {
        note.vibratoCorrection = -1.0f;  // Full vibrato removal
    }

    DBG("Polyphonic Pitch Editor: Flattened vibrato on all notes");
}

void PolyphonicPitchEditor::quantizeTiming(double gridDivision)
{
    for (auto& note : detectedNotes)
    {
        // Quantize start time to nearest grid division
        double quantizedStart = std::round(note.startTime / gridDivision) * gridDivision;
        note.timingCorrection = quantizedStart - note.startTime;
    }

    DBG("Polyphonic Pitch Editor: Quantized timing to " + juce::String(gridDivision) + " second grid");
}

void PolyphonicPitchEditor::resetAllCorrections()
{
    for (auto& note : detectedNotes)
    {
        note.correctedPitch = note.originalPitch;
        note.formantShift = 0.0f;
        note.timingCorrection = 0.0;
        note.amplitudeCorrection = 0.0f;
        note.vibratoCorrection = 0.0f;
        note.pitchDrift = 0.0f;
        note.enabled = true;
    }

    DBG("Polyphonic Pitch Editor: Reset all corrections");
}

//==============================================================================
// Bio-Reactive
//==============================================================================

void PolyphonicPitchEditor::setBioReactiveEnabled(bool enable)
{
    bioReactiveEnabled = enable;
}

void PolyphonicPitchEditor::updateBioData(float hrvNormalized, float coherence, float stressLevel)
{
    currentHRV = juce::jlimit(0.0f, 1.0f, hrvNormalized);
    currentCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    currentStress = juce::jlimit(0.0f, 1.0f, stressLevel);
}

void PolyphonicPitchEditor::applyBioReactiveModulation()
{
    if (!bioReactiveEnabled)
        return;

    // Bio-reactive logic:
    // High HRV + High Coherence = Subtle correction (natural feel)
    // Low HRV + High Stress = Strong correction (perfect pitch)

    float bioFactor = (currentHRV + currentCoherence) * 0.5f;
    float stressFactor = currentStress;

    // Modulate correction strength
    float bioModulation = (1.0f - bioFactor) * 0.3f + stressFactor * 0.2f;
    float effectiveStrength = pitchCorrectionStrength + bioModulation;
    pitchCorrectionStrength = juce::jlimit(0.0f, 1.0f, effectiveStrength);
}

//==============================================================================
// Processing
//==============================================================================

void PolyphonicPitchEditor::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);

    currentSampleRate = sampleRate;
    reset();
}

void PolyphonicPitchEditor::reset()
{
    // Nothing to reset in this implementation
}

void PolyphonicPitchEditor::process(juce::AudioBuffer<float>& buffer)
{
    if (detectedNotes.empty())
        return;  // No notes to process

    if (pitchCorrectionStrength < 0.01f)
        return;  // Bypassed

    // Apply bio-reactive modulation
    applyBioReactiveModulation();

    // For each note, apply pitch/formant/timing/amplitude corrections
    // (Simplified implementation - real Melodyne uses sophisticated resynthesis)

    for (const auto& note : detectedNotes)
    {
        if (!note.enabled)
            continue;

        // Calculate pitch shift in semitones
        float pitchShiftSemitones = 12.0f * std::log2(note.correctedPitch / note.originalPitch);

        // Apply correction strength
        pitchShiftSemitones *= pitchCorrectionStrength;

        // Apply formant shift
        float totalFormantShift = pitchShiftSemitones + note.formantShift;

        // Apply pitch shift to buffer
        // (Real implementation would use phase vocoder or granular synthesis)
        // (This is simplified - just applies gain modulation as example)

        if (std::abs(pitchShiftSemitones) > 0.01f)
        {
            applyPitchShift(buffer, pitchShiftSemitones, formantPreservationEnabled);
        }

        // Apply amplitude correction
        if (std::abs(note.amplitudeCorrection) > 0.01f)
        {
            float gainAdjust = juce::Decibels::decibelsToGain(note.amplitudeCorrection);

            for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
            {
                buffer.applyGain(ch, 0, buffer.getNumSamples(), gainAdjust);
            }
        }
    }
}

//==============================================================================
// Analysis Info
//==============================================================================

float PolyphonicPitchEditor::getAveragePitchDrift() const
{
    if (detectedNotes.empty())
        return 0.0f;

    float sumDrift = 0.0f;

    for (const auto& note : detectedNotes)
    {
        sumDrift += std::abs(note.pitchDrift);
    }

    return sumDrift / detectedNotes.size();
}

float PolyphonicPitchEditor::getAverageTimingDrift() const
{
    if (detectedNotes.empty())
        return 0.0f;

    float sumDrift = 0.0f;

    for (const auto& note : detectedNotes)
    {
        sumDrift += std::abs(static_cast<float>(note.timingCorrection)) * 1000.0f;  // Convert to ms
    }

    return sumDrift / detectedNotes.size();
}

//==============================================================================
// Internal Methods - Pitch Detection
//==============================================================================

void PolyphonicPitchEditor::detectPolyphonicPitch(const juce::AudioBuffer<float>& buffer,
                                                  double sampleRate,
                                                  std::vector<DetectedNote>& notes)
{
    // Simplified polyphonic pitch detection
    // Real implementation would use:
    // - Multiple YIN/pYIN algorithms in parallel
    // - Harmonic product spectrum
    // - Multi-pitch estimation
    // - Spectral peak tracking
    // - Note segmentation

    // For this example, create a few demo notes
    // (Production code would use actual pitch detection algorithms)

    const int numSamples = buffer.getNumSamples();
    const double duration = numSamples / sampleRate;

    // Demo: Detect 3-4 notes (simplified)
    for (int i = 0; i < 3; ++i)
    {
        DetectedNote note;
        note.noteID = nextNoteID++;

        // Demo timing
        note.startTime = i * duration / 4.0;
        note.duration = duration / 4.0;

        // Demo pitch (random within singing range)
        int demoMidiNote = 60 + i * 5;  // C4, F4, A4
        note.originalPitch = midiToFreq(demoMidiNote);
        note.correctedPitch = note.originalPitch;
        note.midiNote = demoMidiNote;

        // Calculate drift from target scale note
        int targetMidi = getClosestScaleNote(note.midiNote);
        float targetFreq = midiToFreq(targetMidi);
        note.pitchDrift = 1200.0f * std::log2(note.originalPitch / targetFreq);

        // Demo amplitude
        note.amplitude = 0.7f;
        note.amplitudeCorrection = 0.0f;

        // Demo formant
        note.formantShift = 0.0f;

        // Demo vibrato (typical values)
        note.vibratoRate = 6.0f;    // 6 Hz
        note.vibratoDepth = 30.0f;  // ±30 cents
        note.vibratoCorrection = 0.0f;

        // Demo timing
        note.timingCorrection = 0.0;

        note.enabled = true;

        notes.push_back(note);
    }
}

void PolyphonicPitchEditor::detectVibrato(const juce::AudioBuffer<float>& buffer,
                                         DetectedNote& note,
                                         double sampleRate)
{
    juce::ignoreUnused(buffer, note, sampleRate);

    // Real vibrato detection would:
    // 1. Extract pitch trajectory over note duration
    // 2. Analyze for periodic modulation (4-8 Hz)
    // 3. Measure depth (cents) and rate (Hz)
    // 4. Detect vibrato shape (sine, triangle, etc.)

    // This is a placeholder - production code uses pitch tracking
}

//==============================================================================
// Scale Helpers
//==============================================================================

int PolyphonicPitchEditor::getClosestScaleNote(int midiNote) const
{
    int noteInOctave = midiNote % 12;
    int octave = midiNote / 12;

    // Find closest note in scale
    int closestNote = noteInOctave;
    int minDistance = 12;

    for (int i = 0; i < 12; ++i)
    {
        int scaleNoteIndex = (scaleRootNote + i) % 12;

        if (customScaleNotes[i])
        {
            int distance = std::abs(scaleNoteIndex - noteInOctave);
            if (distance > 6)
                distance = 12 - distance;  // Wrap around

            if (distance < minDistance)
            {
                minDistance = distance;
                closestNote = scaleNoteIndex;
            }
        }
    }

    return octave * 12 + closestNote;
}

bool PolyphonicPitchEditor::isNoteInScale(int midiNote) const
{
    int noteInOctave = (midiNote - scaleRootNote + 12) % 12;
    return customScaleNotes[noteInOctave];
}

int PolyphonicPitchEditor::freqToMidi(float freq) const
{
    return static_cast<int>(std::round(69.0f + 12.0f * std::log2(freq / 440.0f)));
}

float PolyphonicPitchEditor::midiToFreq(int midi) const
{
    return 440.0f * std::pow(2.0f, (midi - 69) / 12.0f);
}

//==============================================================================
// Pitch Shifting
//==============================================================================

void PolyphonicPitchEditor::applyPitchShift(juce::AudioBuffer<float>& buffer,
                                           float pitchShiftSemitones,
                                           bool preserveFormants)
{
    juce::ignoreUnused(preserveFormants);

    // Simplified pitch shifting (demo)
    // Real implementation would use:
    // - Phase vocoder (FFT-based)
    // - Granular synthesis
    // - PSOLA (Pitch Synchronous Overlap-Add)
    // - Formant-preserving algorithms (for vocals)

    // For this example, just apply a simple gain modulation
    // (Production code uses sophisticated algorithms)

    float pitchRatio = std::pow(2.0f, pitchShiftSemitones / 12.0f);

    // Demo: Apply as gain (not actual pitch shift)
    buffer.applyGain(pitchRatio);
}
