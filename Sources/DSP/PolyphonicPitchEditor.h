#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>

/**
 * @brief Polyphonic Pitch Editor - Per-Note Pitch Correction
 *
 * Advanced polyphonic pitch correction and editing.
 * Detects multiple notes simultaneously and allows per-note correction.
 */
class PolyphonicPitchEditor
{
public:
    enum class Scale
    {
        Chromatic,
        Major,
        Minor,
        HarmonicMinor,
        MelodicMinor,
        Pentatonic,
        Blues,
        Dorian,
        Phrygian,
        Lydian,
        Mixolydian
    };

    // UI compatibility alias
    using ScaleType = Scale;

    struct DetectedNote
    {
        int noteID;
        float frequency;
        float pitchCents;  // Deviation from nearest note
        float confidence;
        float amplitude;

        // Additional fields for UI
        double startTime = 0.0;
        double duration = 0.0;
        int midiNote = 60;
        float originalPitch = 440.0f;
        float correctedPitch = 440.0f;
        float formantShift = 0.0f;
        double timingCorrection = 0.0;
        float amplitudeCorrection = 1.0f;
        bool enabled = true;
    };

    PolyphonicPitchEditor();
    ~PolyphonicPitchEditor() = default;

    //==========================================================================
    // Lifecycle

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Global Parameters

    void setPitchCorrectionStrength(float strength);  // 0.0 to 1.0
    void setFormantPreservationEnabled(bool enabled);

    //==========================================================================
    // Scale & Quantization

    void setScale(Scale scale, int rootNote);         // rootNote: 0=C, 1=C#, etc.
    void quantizeToScale();

    //==========================================================================
    // Analysis

    void analyzeAudio(const juce::AudioBuffer<float>& buffer, double sampleRate);
    int getNumDetectedNotes() const { return static_cast<int>(detectedNotes.size()); }
    const std::vector<DetectedNote>& getDetectedNotes() const { return detectedNotes; }

    //==========================================================================
    // Per-Note Editing

    void setNotePitchCorrection(int noteID, float cents);         // -100 to +100 cents
    void setNoteFormantShift(int noteID, float semitones);        // -12 to +12 semitones
    void setNoteTimingCorrection(int noteID, double ms);          // -50 to +50 ms
    void setNoteAmplitudeCorrection(int noteID, float amplitude); // 0.0 to 2.0
    void setNoteEnabled(int noteID, bool enabled);                // Enable/disable note

    //==========================================================================
    // Bio-Reactive

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float stress);

private:
    double currentSampleRate = 44100.0;
    int currentBlockSize = 512;

    // Global parameters
    float pitchCorrectionStrength = 0.7f;
    bool formantPreservationEnabled = true;

    // Scale
    Scale currentScale = Scale::Chromatic;
    int rootNote = 0;  // C

    // Bio-reactive
    bool bioReactiveEnabled = false;
    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.5f;

    // Detected notes
    std::vector<DetectedNote> detectedNotes;

    // Per-note corrections
    std::map<int, float> notePitchCorrections;
    std::map<int, float> noteFormantShifts;
    std::map<int, double> noteTimingCorrections;
    std::map<int, float> noteAmplitudeCorrections;
    std::map<int, bool> noteEnabledStates;

    // Processing
    juce::Random random;

    bool isNoteInScale(int midiNote) const;
    int getNearestScaleNote(int midiNote) const;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PolyphonicPitchEditor)
};
