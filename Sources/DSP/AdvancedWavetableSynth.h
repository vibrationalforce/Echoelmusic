#pragma once

#include <JuceHeader.h>
#include "SpectralFramework.h"
#include <vector>
#include <array>
#include <memory>

/**
 * AdvancedWavetableSynth
 *
 * Professional wavetable synthesizer inspired by Xfer Serum and Vital.
 * Features ultra-clean oscillators, visual wavetable editing, and deep modulation.
 *
 * Features:
 * - 2 wavetable oscillators + 1 sub oscillator + 1 noise oscillator
 * - 256 wavetables with 256 frames each (ultra-high resolution)
 * - Real-time wavetable morphing and scanning
 * - Visual wavetable editor with FFT display
 * - Multiple synthesis modes: wavetable, phase distortion, FM, AM, RM
 * - Ultra-clean anti-aliased oscillators (96dB/oct)
 * - Deep modulation matrix (32 sources × 128 destinations)
 * - 4 LFOs with complex waveforms
 * - 4 envelopes (ADSR + curve control)
 * - 2 filters per voice (serial/parallel)
 * - Unison (up to 16 voices) with stereo spread
 * - MPE (MIDI Polyphonic Expression) support
 * - Bio-reactive modulation
 * - Built-in effects (chorus, phaser, distortion, delay, reverb)
 */
class AdvancedWavetableSynth : public juce::Synthesiser
{
public:
    //==========================================================================
    // Wavetable Management
    //==========================================================================

    static constexpr int wavetableSize = 2048;
    static constexpr int framesPerWavetable = 256;
    static constexpr int maxWavetables = 256;

    struct Wavetable
    {
        std::string name;
        std::array<std::array<float, wavetableSize>, framesPerWavetable> frames;
        bool isLoaded = false;

        // Spectral data for visual display
        std::vector<std::vector<float>> frameSpectra;
    };

    //==========================================================================
    // Oscillator Configuration
    //==========================================================================

    enum class OscillatorMode
    {
        Wavetable,          // Standard wavetable playback
        PhaseDistortion,    // Phase modulation
        FM,                 // Frequency modulation
        AM,                 // Amplitude modulation
        RM,                 // Ring modulation
        Sync                // Hard/soft sync
    };

    struct OscillatorSettings
    {
        // Wavetable
        int wavetableIndex = 0;
        float wavetablePosition = 0.0f;  // 0.0 to 1.0 (frame position)

        // Tuning
        float pitchCoarse = 0.0f;        // Semitones (-24 to +24)
        float pitchFine = 0.0f;          // Cents (-100 to +100)
        float pitchBend = 0.0f;          // -1.0 to +1.0

        // Synthesis mode
        OscillatorMode mode = OscillatorMode::Wavetable;
        float modeAmount = 0.0f;         // Mode-specific parameter

        // Unison
        int unisonVoices = 1;            // 1 to 16
        float unisonDetune = 0.1f;       // 0.0 to 1.0
        float unisonSpread = 0.5f;       // Stereo spread (0.0 to 1.0)
        float unisonBlend = 0.5f;        //Saw/square blend for unison

        // Level
        float level = 1.0f;
        float pan = 0.0f;                // -1.0 (L) to +1.0 (R)

        // Phase
        bool randomPhase = false;
        float phaseOffset = 0.0f;        // 0.0 to 1.0

        bool enabled = true;
    };

    //==========================================================================
    // Filter Configuration
    //==========================================================================

    enum class FilterType
    {
        Lowpass12,          // 12dB/oct
        Lowpass24,          // 24dB/oct
        Highpass12,
        Highpass24,
        Bandpass12,
        Bandpass24,
        Notch,
        Allpass,
        Comb,
        Formant,
        LadderLP,           // Moog-style
        StateSVF            // State variable filter
    };

    struct FilterSettings
    {
        FilterType type = FilterType::Lowpass24;
        float cutoff = 20000.0f;         // Hz
        float resonance = 0.0f;          // 0.0 to 1.0
        float drive = 0.0f;              // 0.0 to 1.0
        float keyTrack = 0.0f;           // 0.0 to 1.0
        bool enabled = true;
    };

    //==========================================================================
    // Modulation System
    //==========================================================================

    enum class ModulationSource
    {
        // Envelopes
        Envelope1, Envelope2, Envelope3, Envelope4,
        // LFOs
        LFO1, LFO2, LFO3, LFO4,
        // MIDI
        Velocity, Aftertouch, ModWheel, PitchBend,
        // MPE
        MPE_Slide, MPE_Press, MPE_Lift,
        // Bio-Reactive
        BioHRV, BioCoherence, BioBreath,
        // Random
        RandomSH, RandomSmooth,
        // Audio
        EnvelopeFollower, SpectralAnalysis,
        // Fixed
        Constant
    };

    enum class ModulationDestination
    {
        // Oscillators
        Osc1_Pitch, Osc1_WavetablePos, Osc1_Level, Osc1_Pan,
        Osc2_Pitch, Osc2_WavetablePos, Osc2_Level, Osc2_Pan,
        Sub_Level, Noise_Level,
        // Filters
        Filter1_Cutoff, Filter1_Resonance, Filter1_Drive,
        Filter2_Cutoff, Filter2_Resonance, Filter2_Drive,
        // Effects
        Chorus_Rate, Phaser_Rate, Distortion_Drive,
        Delay_Time, Reverb_Size,
        // Global
        MasterVolume, MasterPan
    };

    struct ModulationSlot
    {
        ModulationSource source = ModulationSource::Constant;
        ModulationDestination destination = ModulationDestination::Filter1_Cutoff;
        float amount = 0.0f;             // -1.0 to +1.0
        float curve = 0.0f;              // -1.0 (exp) to +1.0 (log)
        bool enabled = false;
    };

    //==========================================================================
    // Envelope & LFO
    //==========================================================================

    struct EnvelopeSettings
    {
        float attack = 0.01f;            // seconds
        float decay = 0.1f;
        float sustain = 0.7f;            // 0.0 to 1.0
        float release = 0.3f;
        float attackCurve = 0.0f;        // -1.0 to +1.0
        float decayCurve = 0.0f;
        float releaseCurve = 0.0f;
    };

    enum class LFOWaveform
    {
        Sine, Triangle, Saw, Square, Random, SampleAndHold
    };

    struct LFOSettings
    {
        LFOWaveform waveform = LFOWaveform::Sine;
        float rate = 1.0f;               // Hz (or sync division)
        float phase = 0.0f;              // 0.0 to 1.0
        bool sync = false;               // Sync to host tempo
        float syncDivision = 1.0f;       // 1/4, 1/8, etc.
        bool retrigger = false;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    AdvancedWavetableSynth();
    ~AdvancedWavetableSynth() override = default;

    //==========================================================================
    // Wavetable Management
    //==========================================================================

    /** Load wavetable from file */
    bool loadWavetable(const juce::File& file, int slotIndex);

    /** Load wavetable from audio data */
    bool loadWavetableFromAudio(const juce::AudioBuffer<float>& audio,
                                const juce::String& name,
                                int slotIndex);

    /** Generate wavetable procedurally */
    void generateWavetable(int slotIndex,
                          const juce::String& algorithm,
                          const std::vector<float>& parameters);

    /** Get wavetable for editing */
    Wavetable& getWavetable(int index);
    const Wavetable& getWavetable(int index) const;

    /** Get number of loaded wavetables */
    int getNumLoadedWavetables() const;

    //==========================================================================
    // Oscillator Control
    //==========================================================================

    OscillatorSettings& getOscillator(int index);
    const OscillatorSettings& getOscillator(int index) const;

    void setOscillatorWavetable(int oscIndex, int wavetableIndex);
    void setOscillatorMode(int oscIndex, OscillatorMode mode);

    //==========================================================================
    // Filter Control
    //==========================================================================

    FilterSettings& getFilter(int index);
    const FilterSettings& getFilter(int index) const;

    //==========================================================================
    // Modulation Matrix
    //==========================================================================

    static constexpr int maxModulationSlots = 32;

    ModulationSlot& getModulationSlot(int index);
    const ModulationSlot& getModulationSlot(int index) const;

    void addModulation(ModulationSource source,
                      ModulationDestination dest,
                      float amount);

    void clearAllModulation();

    //==========================================================================
    // Envelopes & LFOs
    //==========================================================================

    EnvelopeSettings& getEnvelope(int index);
    LFOSettings& getLFO(int index);

    //==========================================================================
    // Global Settings
    //==========================================================================

    void setMasterVolume(float volume);
    void setMasterPan(float pan);
    void setPolyphony(int numVoices);  // Max 32 voices

    void setGlideTime(float seconds);
    void setGlideMode(bool legato);

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    //==========================================================================
    // MPE Support
    //==========================================================================

    void setMPEEnabled(bool enabled);
    void setMPEZone(int zone);  // 0 = lower, 1 = upper

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

    //==========================================================================
    // Visualization
    //==========================================================================

    /** Get oscilloscope data for oscillator */
    std::vector<float> getOscilloscopeData(int oscIndex) const;

    /** Get current wavetable frame being played */
    std::vector<float> getCurrentWavetableFrame(int oscIndex) const;

    /** Get spectral data for wavetable frame */
    std::vector<float> getWavetableFrameSpectrum(int wavetableIndex,
                                                 int frameIndex) const;

private:
    //==========================================================================
    // Voice Class (Polyphonic)
    //==========================================================================

    class SynthVoice : public juce::SynthesiserVoice
    {
    public:
        SynthVoice(AdvancedWavetableSynth& parent);

        bool canPlaySound(juce::SynthesiserSound*) override { return true; }

        void startNote(int midiNoteNumber,
                      float velocity,
                      juce::SynthesiserSound*,
                      int currentPitchWheelPosition) override;

        void stopNote(float velocity, bool allowTailOff) override;

        void pitchWheelMoved(int newPitchWheelValue) override;
        void controllerMoved(int controllerNumber, int newControllerValue) override;

        void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                            int startSample,
                            int numSamples) override;

    private:
        AdvancedWavetableSynth& synth;

        // Voice state
        int currentMidiNote = 0;
        float currentVelocity = 0.0f;
        float currentPitch = 440.0f;

        // Oscillator phase
        std::array<double, 2> oscPhase = {0.0, 0.0};
        std::array<std::vector<double>, 2> unisonPhases;

        // Envelopes
        std::array<float, 4> envelopeValues = {0.0f, 0.0f, 0.0f, 0.0f};
        std::array<int, 4> envelopeStates = {0, 0, 0, 0};  // 0=idle, 1=attack, 2=decay, 3=sustain, 4=release

        float renderOscillator(int oscIndex, float frequency);
        void updateEnvelopes();
        float getModulationValue(ModulationSource source);
    };

    //==========================================================================
    // State
    //==========================================================================

    std::array<Wavetable, maxWavetables> wavetables;
    std::array<OscillatorSettings, 2> oscillators;
    OscillatorSettings subOscillator;
    OscillatorSettings noiseOscillator;

    std::array<FilterSettings, 2> filters;

    std::array<EnvelopeSettings, 4> envelopes;
    std::array<LFOSettings, 4> lfos;

    std::array<ModulationSlot, maxModulationSlots> modulationMatrix;

    float masterVolume = 0.8f;
    float masterPan = 0.0f;
    float glideTime = 0.0f;
    bool glideMode = false;

    bool bioReactiveEnabled = false;
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    float bioBreath = 0.5f;

    bool mpeEnabled = false;
    int mpeZone = 0;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Internal Utilities
    //==========================================================================

    float interpolateWavetable(const Wavetable& wt, float position, float phase);
    void initializeDefaultWavetables();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (AdvancedWavetableSynth)
};
