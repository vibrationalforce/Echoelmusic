#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>

/**
 * Echoel303 - TB-303 Acid Bass Synthesizer
 *
 * Authentic emulation of the legendary Roland TB-303 with modern enhancements:
 * - Exact 18dB/oct diode ladder filter replication
 * - Classic slide/glide and accent behavior
 * - 16-step pattern sequencer with shuffle
 * - Biometric modulation for evolving acid lines
 * - Modern additions: distortion, chorus, delay
 *
 * Perfect for acid house, techno, and electronic music production.
 */
class Echoel303
{
public:
    //==============================================================================
    Echoel303();
    ~Echoel303() = default;

    //==============================================================================
    // Audio Processing
    void prepare(double sampleRate, int samplesPerBlock);
    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages);
    void reset();

    //==============================================================================
    // Oscillator Parameters (TB-303 style sawtooth)
    void setWaveform(int waveform);  // 0=Saw, 1=Square
    void setTuning(float cents);      // Fine tuning ±50 cents

    //==============================================================================
    // Filter Parameters (18dB/oct diode ladder)
    void setFilterCutoff(float frequency);      // 20 - 20000 Hz
    void setFilterResonance(float resonance);   // 0.0 - 1.0
    void setEnvMod(float amount);               // Envelope modulation depth
    void setFilterDecay(float timeMs);          // Filter envelope decay time
    void setFilterAccent(float amount);         // Accent intensity on filter

    //==============================================================================
    // Envelope Parameters
    void setEnvDecay(float timeMs);             // Amp envelope decay
    void setAccent(float amount);               // Accent amount

    //==============================================================================
    // Slide/Glide
    void setSlideTime(float timeMs);            // Portamento time

    //==============================================================================
    // Modern Additions
    void setDistortion(float amount);           // 0.0 - 1.0
    void setOverdrive(float amount);            // Tube-style overdrive
    void setChorus(float depth, float rate);    // Stereo chorus
    void setDelay(float time, float feedback);  // Slapback delay

    //==============================================================================
    // Pattern Sequencer (16 steps)
    struct Step {
        bool active = false;
        int note = 36;          // MIDI note number (C2 = kick range)
        bool slide = false;     // Slide to next note
        bool accent = false;    // Accent this note
        bool octave = false;    // Octave up
    };

    void setPattern(const std::array<Step, 16>& pattern);
    void setPatternStep(int step, const Step& data);
    Step getPatternStep(int step) const;
    void clearPattern();

    void setSequencerEnabled(bool enabled);
    void setTempo(float bpm);
    void setShuffle(float amount);   // 0.0 - 1.0 (50% - 75% swing)

    //==============================================================================
    // Biometric Modulation
    void setHeartRate(float bpm);
    void setHeartRateVariability(float hrv);    // 0.0 - 1.0
    void setCoherence(float coherence);         // 0.0 - 1.0
    void enableBiometricModulation(bool enable);

    //==============================================================================
    // Presets
    enum class Preset {
        Init,
        ClassicAcid,
        DeepBass,
        SquelchLead,
        ResonantStab,
        BiometricGroove,
        HypnoticLoop,
        DistortedAcid
    };

    void loadPreset(Preset preset);

    //==============================================================================
    // State
    float getCurrentCutoff() const { return currentCutoff; }
    float getCurrentResonance() const { return currentResonance; }
    bool isNoteActive() const { return voiceActive; }

private:
    //==============================================================================
    // Voice State
    struct Voice {
        bool active = false;
        int currentNote = 0;
        float currentFrequency = 0.0f;
        float targetFrequency = 0.0f;
        float slideFrequency = 0.0f;
        float phase = 0.0f;
        float velocity = 1.0f;
        bool isSliding = false;
        bool isAccented = false;

        // Envelopes
        float ampEnv = 0.0f;
        float filterEnv = 0.0f;

        // Filter state (diode ladder)
        std::array<float, 4> filterStage{0.0f, 0.0f, 0.0f, 0.0f};
        float tanh1 = 0.0f;
    };

    Voice voice;
    bool voiceActive = false;

    //==============================================================================
    // Parameters
    int waveformType = 0;           // 0=Saw, 1=Square
    float tuning = 0.0f;

    // Filter (diode ladder - authentic TB-303)
    float filterCutoff = 500.0f;
    float filterResonance = 0.7f;
    float envModAmount = 0.7f;
    float filterDecayTime = 200.0f;
    float filterAccentAmount = 0.5f;

    // Envelope
    float envDecayTime = 200.0f;
    float accentAmount = 0.8f;

    // Slide
    float slideTime = 60.0f;        // TB-303 typically 60ms

    // Modern FX
    float distortionAmount = 0.0f;
    float overdriveAmount = 0.0f;
    float chorusDepth = 0.0f;
    float chorusRate = 2.0f;
    float delayTime = 0.0f;
    float delayFeedback = 0.0f;

    // Sequencer
    std::array<Step, 16> pattern;
    bool sequencerEnabled = false;
    float tempo = 120.0f;
    float shuffle = 0.0f;
    int currentStep = 0;
    int samplesUntilNextStep = 0;

    // Biometric
    bool biometricEnabled = false;
    float heartRate = 70.0f;
    float heartRateVariability = 0.5f;
    float coherence = 0.5f;

    // State
    double sampleRate = 44100.0;
    int samplesPerBlock = 512;
    float currentCutoff = 500.0f;
    float currentResonance = 0.7f;

    // Chorus LFO
    float chorusPhase = 0.0f;

    // Delay line
    std::vector<float> delayBuffer;
    int delayWritePos = 0;

    //==============================================================================
    // Internal Processing
    void handleMidiMessage(const juce::MidiMessage& message);
    void noteOn(int midiNote, float velocity, bool slide, bool accent);
    void noteOff();

    float generateOscillator();
    float processDiodeLadderFilter(float input);
    void updateEnvelopes();
    void updateBiometricModulation();
    void processSequencer(int numSamples);

    float applyDistortion(float sample);
    float applyChorus(float sample);
    float applyDelay(float sample);

    // TB-303 specific
    float calculateSlide();
    float calculateAccentMod();
};
