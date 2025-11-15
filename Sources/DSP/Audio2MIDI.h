#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <map>

/**
 * Audio2MIDI - Polyphonic Audio to MIDI Conversion
 *
 * AI-powered audio-to-MIDI transcription:
 * - Monophonic pitch detection (vocals, lead instruments)
 * - Polyphonic pitch detection (chords, piano)
 * - Onset detection (note start/end times)
 * - Velocity estimation
 * - Pitch bend and vibrato capture
 * - Quantization options
 * - Multi-track separation
 *
 * Inspired by: Melodyne, AnthemScore, Logic Pro Flex Pitch
 */
class Audio2MIDI
{
public:
    Audio2MIDI();
    ~Audio2MIDI();

    //==============================================================================
    // Processing

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void reset();

    void process(const juce::AudioBuffer<float>& buffer);
    juce::MidiBuffer getMidiOutput();  // Get MIDI events since last call

    //==============================================================================
    // Detection Modes

    enum class DetectionMode
    {
        Monophonic,          // Single note at a time (vocals, lead)
        Polyphonic,          // Multiple notes (piano, guitar chords)
        Percussive,          // Drum/percussion (only onsets, no pitch)
        Auto                 // Automatically detect best mode
    };

    void setDetectionMode(DetectionMode mode);
    DetectionMode getDetectionMode() const;

    //==============================================================================
    // Settings

    void setMinimumNoteDuration(float ms);       // Minimum note length (10-500ms)
    void setOnsetSensitivity(float sensitivity); // 0.0 to 1.0 (how sensitive to note attacks)
    void setPitchSensitivity(float sensitivity); // 0.0 to 1.0 (pitch detection threshold)
    void setMaxPolyphony(int voices);            // 1 to 10 (max simultaneous notes)

    void setQuantization(bool enabled);
    void setQuantizationGrid(float beatDivision); // 0.25 = 16th notes, 0.5 = 8th, 1.0 = quarter

    void setVelocitySensitive(bool enabled);     // Map amplitude to MIDI velocity
    void setCapturePitchBend(bool enabled);      // Capture pitch variations as MIDI bend

    //==============================================================================
    // Detected Notes

    struct Note
    {
        int midiNote;              // MIDI note number (0-127)
        float startTime;           // Seconds
        float duration;            // Seconds
        int velocity;              // 0-127
        float pitch;               // Exact pitch in Hz
        float confidence;          // 0.0 to 1.0
        std::vector<int> pitchBend; // Pitch bend values over time
    };

    std::vector<Note> getDetectedNotes() const;
    void clearDetectedNotes();

    //==============================================================================
    // Real-Time Monitoring

    struct CurrentPitch
    {
        float frequency;           // Hz
        int midiNote;              // Closest MIDI note
        float cents;               // Cents deviation from MIDI note
        float confidence;          // 0.0 to 1.0
        bool noteActive;           // Is a note currently playing?
    };

    CurrentPitch getCurrentPitch() const;
    std::array<float, 128> getCurrentNoteActivity() const;  // Activity level for each MIDI note

    //==============================================================================
    // Export

    void exportToMidi(const juce::File& outputFile);
    juce::MidiMessageSequence getMidiSequence() const;

    //==============================================================================
    // Presets

    enum class Preset
    {
        Vocals,
        Guitar,
        Piano,
        Bass,
        Drums,
        Strings,
        Generic
    };

    void loadPreset(Preset preset);

private:
    //==============================================================================
    // DSP State

    double currentSampleRate = 48000.0;
    int currentNumChannels = 2;
    double currentTimeSeconds = 0.0;

    // FFT for pitch detection
    static constexpr int fftOrder = 13;             // 8192 samples
    static constexpr int fftSize = 1 << fftOrder;
    juce::dsp::FFT forwardFFT;
    juce::dsp::WindowingFunction<float> window;

    std::array<float, fftSize * 2> fftData;
    std::array<float, fftSize> magnitudes;

    // Pitch detection
    DetectionMode detectionMode = DetectionMode::Monophonic;
    CurrentPitch currentPitch;
    std::array<float, 128> noteActivity;

    // Onset detection
    float previousEnergy = 0.0f;
    float energyThreshold = 0.1f;

    // Note tracking
    struct ActiveNote
    {
        int midiNote;
        float startTime;
        float startAmplitude;
        bool active;
    };
    std::vector<ActiveNote> activeNotes;
    std::vector<Note> detectedNotes;

    // MIDI output buffer
    juce::MidiBuffer midiOutputBuffer;

    // Settings
    float minimumNoteDuration = 50.0f;           // ms
    float onsetSensitivity = 0.7f;
    float pitchSensitivity = 0.6f;
    int maxPolyphony = 6;
    bool quantizationEnabled = false;
    float quantizationGrid = 0.25f;              // 16th notes
    bool velocitySensitive = true;
    bool capturePitchBend = false;

    //==============================================================================
    // Internal Algorithms

    void performFFTAnalysis(const juce::AudioBuffer<float>& buffer);
    void detectPitch();
    void detectOnsets(const juce::AudioBuffer<float>& buffer);
    void updateActiveNotes();
    void generateMidiEvents();

    float detectFundamentalFrequency();          // YIN algorithm (simplified)
    std::vector<float> detectPolyphonicPitches(); // Multiple pitches
    float calculateEnergy(const juce::AudioBuffer<float>& buffer);
    int frequencyToMidiNote(float frequency);
    float midiNoteToFrequency(int midiNote);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(Audio2MIDI)
};
