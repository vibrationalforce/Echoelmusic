#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>

/**
 * Polyphonic Pitch Editor
 *
 * Professional polyphonic pitch editing inspired by Celemony Melodyne.
 * Analyzes audio and allows manipulation of individual notes in polyphonic material.
 *
 * **Innovation**: First bio-reactive pitch editor with HRV-controlled pitch correction intensity.
 *
 * Features:
 * - Polyphonic pitch detection (up to 8 simultaneous notes)
 * - Note-by-note pitch correction
 * - Time stretching (independent from pitch)
 * - Formant preservation and shifting
 * - Vibrato control (add, remove, or modify)
 * - Note separation and manipulation
 * - Pitch drift correction (quantize to scale)
 * - Timing quantization
 * - Amplitude envelope editing
 * - Blob editing (graphical note manipulation)
 * - Scale-aware pitch correction
 * - Bio-reactive correction strength (HRV controls intensity)
 *
 * Advanced Over Existing Tools:
 * - **AutomaticVocalAligner**: Timing only, no pitch
 * - **PitchCorrection**: Monophonic, simple auto-tune
 * - **Harmonizer**: Generates harmonies, doesn't edit existing
 * - **PolyphonicPitchEditor**: Full Melodyne-style note editing
 *
 * Use Cases:
 * - Vocal tuning (correct pitch while preserving natural feel)
 * - Instrument tuning (guitar, piano, strings)
 * - Chord editing (adjust individual notes in chords)
 * - Creative pitch manipulation
 * - Vocal doubling with variations
 * - Bio-reactive subtle tuning (user's stress = more/less correction)
 *
 * Workflow:
 * 1. Analyze audio (analyzeAudio) - Detects all notes
 * 2. Review detected notes (getDetectedNotes)
 * 3. Edit notes (setPitchCorrection, setFormantShift, etc.)
 * 4. Process audio (process) - Applies edits
 */
class PolyphonicPitchEditor
{
public:
    //==========================================================================
    // Note Data (Detected Note)
    //==========================================================================

    struct DetectedNote
    {
        int noteID;                    // Unique ID

        // Timing
        double startTime;              // seconds
        double duration;               // seconds

        // Pitch
        float originalPitch;           // Hz
        float correctedPitch;          // Hz (after edits)
        int midiNote;                  // MIDI note number (60 = C4)
        float pitchDrift;              // cents (deviation from target)

        // Amplitude
        float amplitude;               // 0.0 to 1.0
        float amplitudeCorrection;     // dB adjustment

        // Formant
        float formantShift;            // semitones (±12)

        // Vibrato
        float vibratoRate;             // Hz (5-8 Hz typical)
        float vibratoDepth;            // cents (±50 typical)
        float vibratoCorrection;       // -1.0 to +1.0 (remove/add vibrato)

        // Timing correction
        double timingCorrection;       // seconds (shift start time)

        // Enabled
        bool enabled = true;           // Note on/off
    };

    //==========================================================================
    // Scale (for pitch quantization)
    //==========================================================================

    enum class ScaleType
    {
        Chromatic,          // All 12 notes
        Major,              // Major scale
        Minor,              // Natural minor
        HarmonicMinor,      // Harmonic minor
        MelodicMinor,       // Melodic minor
        Pentatonic,         // Major pentatonic
        Blues,              // Blues scale
        Dorian,             // Dorian mode
        Mixolydian,         // Mixolydian mode
        Custom              // User-defined
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    PolyphonicPitchEditor();
    ~PolyphonicPitchEditor() = default;

    //==========================================================================
    // Analysis
    //==========================================================================

    /** Analyze audio and detect all notes */
    void analyzeAudio(const juce::AudioBuffer<float>& audioBuffer, double sampleRate);

    /** Get all detected notes */
    const std::vector<DetectedNote>& getDetectedNotes() const { return detectedNotes; }

    /** Get note by ID */
    DetectedNote* getNote(int noteID);

    /** Clear all detected notes */
    void clearNotes();

    //==========================================================================
    // Global Correction Parameters
    //==========================================================================

    /** Set global pitch correction strength (0.0 = off, 1.0 = full correction) */
    void setPitchCorrectionStrength(float strength);

    /** Set pitch correction speed (0.0 = slow, 1.0 = instant/auto-tune effect) */
    void setPitchCorrectionSpeed(float speed);

    /** Set scale for pitch quantization */
    void setScale(ScaleType scale, int rootNote = 0);  // rootNote: 0=C, 1=C#, etc.

    /** Set custom scale (12 booleans for each chromatic note) */
    void setCustomScale(const std::array<bool, 12>& scale);

    /** Enable formant preservation (prevents "chipmunk" effect) */
    void setFormantPreservationEnabled(bool enable);

    //==========================================================================
    // Individual Note Editing
    //==========================================================================

    /** Set pitch correction for specific note (in cents, ±200) */
    void setNotePitchCorrection(int noteID, float cents);

    /** Set formant shift for specific note (in semitones, ±12) */
    void setNoteFormantShift(int noteID, float semitones);

    /** Set timing correction for specific note (in seconds, ±0.5) */
    void setNoteTimingCorrection(int noteID, double seconds);

    /** Set amplitude correction for specific note (in dB, ±12) */
    void setNoteAmplitudeCorrection(int noteID, float dB);

    /** Set vibrato correction for specific note (-1.0 = remove, 0.0 = keep, +1.0 = add) */
    void setNoteVibratoCorrection(int noteID, float amount);

    /** Enable/disable specific note */
    void setNoteEnabled(int noteID, bool enabled);

    //==========================================================================
    // Batch Operations
    //==========================================================================

    /** Quantize all notes to scale */
    void quantizeToScale();

    /** Flatten all vibrato */
    void flattenVibrato();

    /** Quantize all timing to grid (beat division in seconds) */
    void quantizeTiming(double gridDivision);

    /** Reset all corrections (back to original) */
    void resetAllCorrections();

    //==========================================================================
    // Bio-Reactive Integration
    //==========================================================================

    /** Enable bio-reactive pitch correction (HRV controls intensity) */
    void setBioReactiveEnabled(bool enable);

    /** Update bio-data for reactive processing */
    void updateBioData(float hrvNormalized, float coherence, float stressLevel);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Prepare for processing */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset state */
    void reset();

    /** Process audio buffer (applies all corrections) */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Analysis Info
    //==========================================================================

    /** Get number of detected notes */
    int getNumDetectedNotes() const { return static_cast<int>(detectedNotes.size()); }

    /** Get average pitch drift (cents) */
    float getAveragePitchDrift() const;

    /** Get average timing drift (milliseconds) */
    float getAverageTimingDrift() const;

private:
    //==========================================================================
    // Parameters
    //==========================================================================

    float pitchCorrectionStrength = 0.8f;
    float pitchCorrectionSpeed = 0.5f;  // 0 = slow/natural, 1 = instant/T-Pain

    ScaleType currentScale = ScaleType::Chromatic;
    int scaleRootNote = 0;  // 0 = C
    std::array<bool, 12> customScaleNotes = {true, true, true, true, true, true,
                                             true, true, true, true, true, true};

    bool formantPreservationEnabled = true;

    // Bio-reactive
    bool bioReactiveEnabled = false;
    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.0f;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Detected Notes Storage
    //==========================================================================

    std::vector<DetectedNote> detectedNotes;
    int nextNoteID = 0;

    //==========================================================================
    // Internal Processing
    //==========================================================================

    /** Polyphonic pitch detection (YIN algorithm extended) */
    void detectPolyphonicPitch(const juce::AudioBuffer<float>& buffer,
                              double sampleRate,
                              std::vector<DetectedNote>& notes);

    /** Detect vibrato in note */
    void detectVibrato(const juce::AudioBuffer<float>& buffer,
                      DetectedNote& note,
                      double sampleRate);

    /** Get closest note in current scale */
    int getClosestScaleNote(int midiNote) const;

    /** Check if MIDI note is in current scale */
    bool isNoteInScale(int midiNote) const;

    /** Frequency to MIDI note number */
    int freqToMidi(float freq) const;

    /** MIDI note number to frequency */
    float midiToFreq(int midi) const;

    /** Apply bio-reactive modulation to parameters */
    void applyBioReactiveModulation();

    /** Apply pitch shifting with formant preservation */
    void applyPitchShift(juce::AudioBuffer<float>& buffer,
                        float pitchShiftSemitones,
                        bool preserveFormants);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (PolyphonicPitchEditor)
};
