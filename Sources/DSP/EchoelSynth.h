#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>

/**
 * EchoelSynth - Analog Subtractive Synthesizer
 *
 * Classic analog-style polyphonic synthesizer with:
 * - Dual oscillators with multiple waveforms
 * - Multi-mode resonant filter
 * - ADSR envelopes (amplitude + filter)
 * - LFO modulation
 * - Unison/detune for thickness
 * - Analog drift and warmth modeling
 *
 * Inspired by: Moog Minimoog, Roland Juno-60, Prophet-5
 */
class EchoelSynth : public juce::Synthesiser
{
public:
    EchoelSynth();
    ~EchoelSynth() override;

    //==============================================================================
    // Processing

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages);

    //==============================================================================
    // Oscillators

    enum class Waveform
    {
        Sine,
        Triangle,
        Sawtooth,
        Square,
        Pulse,       // Variable pulse width
        Noise        // White noise
    };

    void setOsc1Waveform(Waveform waveform);
    void setOsc2Waveform(Waveform waveform);
    void setOsc1Octave(int octave);      // -2 to +2
    void setOsc2Octave(int octave);
    void setOsc1Semitones(int semitones); // -12 to +12
    void setOsc2Semitones(int semitones);
    void setOsc1Detune(float cents);      // -100 to +100 cents
    void setOsc2Detune(float cents);
    void setOsc2Mix(float mix);           // 0.0 to 1.0

    void setPulseWidth(float width);      // 0.1 to 0.9 (for pulse waveform)

    //==============================================================================
    // Filter

    enum class FilterType
    {
        LowPass12,    // 12dB/oct (Moog-style)
        LowPass24,    // 24dB/oct (aggressive)
        HighPass12,
        HighPass24,
        BandPass,
        Notch
    };

    void setFilterType(FilterType type);
    void setFilterCutoff(float frequency);    // 20Hz to 20kHz
    void setFilterResonance(float resonance); // 0.0 to 1.0
    void setFilterEnvAmount(float amount);    // -1.0 to +1.0

    //==============================================================================
    // Envelopes

    void setAmpAttack(float timeMs);
    void setAmpDecay(float timeMs);
    void setAmpSustain(float level);     // 0.0 to 1.0
    void setAmpRelease(float timeMs);

    void setFilterAttack(float timeMs);
    void setFilterDecay(float timeMs);
    void setFilterSustain(float level);
    void setFilterRelease(float timeMs);

    //==============================================================================
    // LFO

    enum class LFOWaveform
    {
        Sine,
        Triangle,
        Sawtooth,
        Square,
        SampleAndHold
    };

    void setLFOWaveform(LFOWaveform waveform);
    void setLFORate(float hz);                  // 0.01Hz to 20Hz
    void setLFOToPitch(float amount);           // 0.0 to 1.0 (vibrato)
    void setLFOToFilter(float amount);          // 0.0 to 1.0 (wah)
    void setLFOToAmp(float amount);             // 0.0 to 1.0 (tremolo)
    void setLFOPhase(float phase);              // 0.0 to 1.0

    //==============================================================================
    // Unison & Character

    void setUnisonVoices(int voices);           // 1 to 8
    void setUnisonDetune(float cents);          // 0.0 to 50.0 cents
    void setUnisonSpread(float amount);         // 0.0 to 1.0 (stereo width)

    void setAnalogDrift(float amount);          // 0.0 to 1.0 (pitch instability)
    void setAnalogWarmth(float amount);         // 0.0 to 1.0 (saturation)

    //==============================================================================
    // Master Controls

    void setMasterVolume(float volume);         // 0.0 to 1.0
    void setGlideTime(float timeMs);            // 0ms to 2000ms (portamento)
    void setPolyphony(int voices);              // 1 to 16 voices

    //==============================================================================
    // Presets

    enum class Preset
    {
        Init,                 // Basic saw wave
        FatBass,             // Thick bass patch
        LeadSynth,           // Screaming lead
        Pad,                 // Lush pad
        Pluck,               // Plucked string
        Brass,               // Brass section
        Strings,             // String ensemble
        VintageKeys,         // Analog piano
        SquareLead,          // Square wave lead
        AcidBass,            // TB-303 style
        HooverSynth,         // Classic rave sound
        Wobble               // Dubstep wobble bass
    };

    void loadPreset(Preset preset);

private:
    //==============================================================================
    // Voice Class

    class EchoelSynthVoice : public juce::SynthesiserVoice
    {
    public:
        EchoelSynthVoice(EchoelSynth& parent);

        bool canPlaySound(juce::SynthesiserSound*) override;
        void startNote(int midiNoteNumber, float velocity,
                      juce::SynthesiserSound*, int currentPitchWheelPosition) override;
        void stopNote(float velocity, bool allowTailOff) override;
        void pitchWheelMoved(int newPitchWheelValue) override;
        void controllerMoved(int controllerNumber, int newControllerValue) override;
        void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                           int startSample, int numSamples) override;

    private:
        EchoelSynth& synthRef;

        // Note state
        int currentMidiNote = 0;
        float currentVelocity = 0.0f;
        float currentFrequency = 440.0f;
        float glideTargetFrequency = 440.0f;
        float glideCurrentFrequency = 440.0f;

        // Oscillator state
        float osc1Phase = 0.0f;
        float osc2Phase = 0.0f;
        float noiseState = 0.0f;

        // Filter state (Moog-style ladder)
        std::array<float, 4> filterState = {0.0f, 0.0f, 0.0f, 0.0f};
        float filterCutoffSmooth = 1000.0f;

        // ADSR state
        struct EnvelopeState
        {
            enum class Stage { Idle, Attack, Decay, Sustain, Release };
            Stage stage = Stage::Idle;
            float level = 0.0f;
            float increment = 0.0f;
            float sustainLevel = 0.7f;
        };
        EnvelopeState ampEnv;
        EnvelopeState filterEnv;

        // Analog drift
        float driftOffset = 0.0f;
        float driftPhase = 0.0f;

        // Helper methods
        float generateOscillator(Waveform waveform, float phase, float pulseWidth, float phaseIncrement = 0.0f);
        float processFilter(float sample);
        void updateEnvelope(EnvelopeState& env, float attack, float decay, float sustain, float release);
        float getEnvelopeLevel(EnvelopeState& env);

        // PolyBLEP anti-aliasing for alias-free oscillators
        // Returns correction value for discontinuities in sawtooth/square waves
        float polyBLEP(float t, float dt)
        {
            // t = phase position [0,1), dt = phase increment per sample
            if (t < dt)
            {
                // Start of period - rising edge
                t /= dt;
                return t + t - t * t - 1.0f;
            }
            else if (t > 1.0f - dt)
            {
                // End of period - falling edge
                t = (t - 1.0f) / dt;
                return t * t + t + t + 1.0f;
            }
            return 0.0f;
        }
    };

    //==============================================================================
    // Sound Class

    class EchoelSynthSound : public juce::SynthesiserSound
    {
    public:
        bool appliesToNote(int) override { return true; }
        bool appliesToChannel(int) override { return true; }
    };

    //==============================================================================
    // Synth Parameters

    double currentSampleRate = 48000.0;
    int currentSamplesPerBlock = 512;
    int currentNumChannels = 2;

    // Oscillators
    Waveform osc1Waveform = Waveform::Sawtooth;
    Waveform osc2Waveform = Waveform::Sawtooth;
    int osc1Octave = 0;
    int osc2Octave = 0;
    int osc1Semitones = 0;
    int osc2Semitones = -12;  // Default: one octave down
    float osc1Detune = 0.0f;
    float osc2Detune = 5.0f;   // Slight detune for thickness
    float osc2Mix = 0.5f;
    float pulseWidth = 0.5f;

    // Filter
    FilterType filterType = FilterType::LowPass24;
    float filterCutoff = 2000.0f;
    float filterResonance = 0.3f;
    float filterEnvAmount = 0.5f;

    // Amp Envelope
    float ampAttack = 5.0f;
    float ampDecay = 100.0f;
    float ampSustain = 0.7f;
    float ampRelease = 200.0f;

    // Filter Envelope
    float filterAttack = 5.0f;
    float filterDecay = 300.0f;
    float filterSustain = 0.3f;
    float filterRelease = 500.0f;

    // LFO
    LFOWaveform lfoWaveform = LFOWaveform::Sine;
    float lfoRate = 5.0f;
    float lfoToPitch = 0.0f;
    float lfoToFilter = 0.0f;
    float lfoToAmp = 0.0f;
    float lfoPhase = 0.0f;
    float lfoPhaseAccumulator = 0.0f;

    // Unison
    int unisonVoices = 1;
    float unisonDetune = 10.0f;
    float unisonSpread = 0.5f;

    // Character
    float analogDrift = 0.3f;
    float analogWarmth = 0.5f;

    // Master
    float masterVolume = 0.7f;
    float glideTime = 0.0f;

    //==============================================================================
    // Internal Helpers

    float getLFOValue();
    float applyAnalogWarmth(float sample);

    friend class EchoelSynthVoice;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelSynth)
};
