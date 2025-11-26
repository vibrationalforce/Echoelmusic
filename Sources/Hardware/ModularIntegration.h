#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>

namespace Eoel {

/**
 * ModularIntegration - CV/Gate and Eurorack integration
 *
 * Supported interfaces:
 * - Expert Sleepers ES-3, ES-6, ES-8, ES-9 (DC-coupled audio → CV/Gate)
 * - MOTU 828mk3, 896mk3 (DC-coupled outputs)
 * - RME HDSPe AIO, UFX (DC-coupled)
 * - Native Instruments Komplete Audio 6 (CV outputs)
 * - Behringer U-Phoria UMC404HD
 * - Arturia AudioFuse
 *
 * CV Standards:
 * - 1V/octave pitch CV (-5V to +5V = 10 octaves)
 * - 0-10V modulation CV
 * - Gate: 0V = off, 5V = on (Eurorack standard)
 * - Trigger: 5V pulse (1-10ms duration)
 *
 * Supported Eurorack modules (auto-compatible):
 * - Mutable Instruments: Plaits, Rings, Clouds, Marbles, Stages
 * - Make Noise: Maths, René, Morphagene, Erbe-Verb
 * - Intellijel: Dixie, Metropolis, Rubicon
 * - 4ms: Spectral Multiband Resonator, Ensemble Oscillator
 * - Noise Engineering, Erica Synths, Doepfer, etc.
 *
 * Features:
 * - Auto-calibrate CV outputs (1V/octave tuning)
 * - Gate/Trigger generation
 * - Envelope output (ADSR as CV)
 * - LFO output (multiple waveforms)
 * - Sequencer → CV/Gate
 * - Audio input from Eurorack (process modular audio)
 */
class ModularIntegration
{
public:
    enum class CVStandard
    {
        OneVoltPerOctave,      // -5V to +5V (Eurorack standard)
        HzPerVolt,             // Buchla standard (1.2V/octave)
        ZeroToTenVolt          // General modulation CV
    };

    struct CVOutput
    {
        int channelIndex;           // Physical output channel
        CVStandard standard = CVStandard::OneVoltPerOctave;
        float voltage = 0.0f;       // Current voltage (-10V to +10V)
        float calibrationOffset = 0.0f;  // Tuning offset
        bool isGate = false;        // Gate output (0V/5V)
        bool isTrigger = false;     // Trigger output (pulse)
    };

    struct CVInput
    {
        int channelIndex;           // Physical input channel
        float voltage = 0.0f;       // Current voltage
        float min = -5.0f;
        float max = 5.0f;
    };

    ModularIntegration();
    ~ModularIntegration();

    // ===========================
    // Interface Setup
    // ===========================

    /** Set which audio interface to use for CV */
    void setAudioInterface(const juce::String& deviceName);

    /** Map audio channels to CV outputs */
    void mapCVOutput(int outputIndex, int audioChannel, CVStandard standard = CVStandard::OneVoltPerOctave);

    /** Map audio channels to CV inputs */
    void mapCVInput(int inputIndex, int audioChannel);

    /** Get available DC-coupled audio interfaces */
    static std::vector<juce::String> getCompatibleInterfaces();

    // ===========================
    // Calibration
    // ===========================

    /**
     * Auto-calibrate 1V/octave tuning
     * Plays test tones and measures Eurorack oscillator response
     */
    void startAutoCalibration(int cvOutputIndex);

    /** Manual calibration offset */
    void setCalibrationOffset(int cvOutputIndex, float offsetVolts);

    /** Verify calibration accuracy */
    float getCalibrationError(int cvOutputIndex) const;

    // ===========================
    // CV Output
    // ===========================

    /** Set pitch CV (MIDI note number → voltage) */
    void setPitchCV(int cvOutputIndex, int midiNote);

    /** Set modulation CV (0.0 to 1.0 → 0V to 10V) */
    void setModulationCV(int cvOutputIndex, float modulation);

    /** Set raw voltage (-10V to +10V) */
    void setVoltage(int cvOutputIndex, float voltage);

    /** Send gate (0V or 5V) */
    void setGate(int cvOutputIndex, bool on);

    /** Send trigger pulse (5V for specified duration) */
    void sendTrigger(int cvOutputIndex, float durationMs = 5.0f);

    // ===========================
    // Envelope & LFO Output
    // ===========================

    /** Output ADSR envelope as CV */
    void setEnvelopeOutput(int cvOutputIndex, float attack, float decay, float sustain, float release);

    /** Trigger envelope */
    void triggerEnvelope(int cvOutputIndex);

    /** Output LFO as CV */
    void setLFOOutput(int cvOutputIndex, float frequency, juce::dsp::Oscillator<float>::Type waveform);

    // ===========================
    // Sequencer → CV
    // ===========================

    struct SequenceStep
    {
        int midiNote = 60;          // C4
        float voltage = 0.0f;       // Can override with raw voltage
        bool gate = true;
        bool trigger = false;
        float duration = 0.25f;     // Beats
    };

    /** Load sequence to CV output */
    void setSequence(int cvOutputIndex, const std::vector<SequenceStep>& steps);

    /** Start/stop sequencer */
    void startSequencer(bool start);

    /** Set sequencer tempo */
    void setSequencerTempo(double bpm);

    // ===========================
    // CV Input (Eurorack → Software)
    // ===========================

    /** Read current CV input voltage */
    float readCVInput(int cvInputIndex) const;

    /** Convert CV input to MIDI note (1V/octave) */
    int cvToMidiNote(int cvInputIndex) const;

    /** Convert CV input to normalized value (0.0 to 1.0) */
    float cvToNormalized(int cvInputIndex) const;

    // ===========================
    // Audio Processing
    // ===========================

    /**
     * Process audio buffer (generates CV voltages)
     * Call this in your audio callback
     */
    void processAudio(juce::AudioBuffer<float>& buffer, int numSamples);

    /**
     * Process incoming CV (read Eurorack inputs)
     */
    void processCVInputs(const juce::AudioBuffer<float>& buffer, int numSamples);

    // ===========================
    // Presets for Popular Modules
    // ===========================

    /** Mutable Instruments Plaits (macro oscillator) */
    void setupForPlaits(int pitchCV, int triggerOut, int modulationCV);

    /** Make Noise Maths (function generator) */
    void setupForMaths(int cv1, int cv2, int trigger);

    /** Intellijel Metropolis (sequencer) */
    void setupForMetropolis(int clockOut, int resetOut, int pitchCV);

    // ===========================
    // Callbacks
    // ===========================

    std::function<void(int cvInput, float voltage)> onCVInputChanged;
    std::function<void(int gateInput, bool state)> onGateInputChanged;
    std::function<void()> onCalibrationComplete;

private:
    std::vector<CVOutput> m_cvOutputs;
    std::vector<CVInput> m_cvInputs;

    // Sequencer
    std::vector<SequenceStep> m_sequence;
    int m_sequencePosition = 0;
    double m_sequencerTempo = 120.0;
    bool m_sequencerRunning = false;
    double m_sequencerPhase = 0.0;

    // Envelope generator
    struct EnvelopeGenerator
    {
        float attack = 0.01f;
        float decay = 0.1f;
        float sustain = 0.7f;
        float release = 0.2f;
        float phase = 0.0f;
        bool triggered = false;
        bool gateOn = false;
    };
    std::map<int, EnvelopeGenerator> m_envelopes;

    // LFO
    struct LFOGenerator
    {
        juce::dsp::Oscillator<float> oscillator;
        float frequency = 1.0f;
    };
    std::map<int, LFOGenerator> m_lfos;

    // Audio interface
    juce::String m_interfaceName;
    double m_sampleRate = 44100.0;

    // Calibration
    bool m_calibrating = false;
    int m_calibrationOutput = -1;

    juce::CriticalSection m_lock;

    float voltageToSample(float voltage) const;
    float sampleToVoltage(float sample) const;
    float midiNoteToVoltage(int midiNote, CVStandard standard) const;
    int voltageToMidiNote(float voltage, CVStandard standard) const;

    void updateSequencer(int numSamples);
    float processEnvelope(EnvelopeGenerator& env, int numSamples);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ModularIntegration)
};

} // namespace Eoel
