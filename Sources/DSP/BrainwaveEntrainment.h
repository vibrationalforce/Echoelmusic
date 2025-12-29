#pragma once

#include "QuantumFrequencyScience.h"
#include <JuceHeader.h>
#include <array>
#include <vector>
#include <cmath>

/**
 * BrainwaveEntrainment - Scientific Brainwave Synchronization
 *
 * Based on:
 * - Schumann Resonance (7.83 Hz Earth frequency)
 * - Brainwave bands (Delta, Theta, Alpha, Beta, Gamma)
 * - Binaural beat technology
 * - Isochronic tones
 * - Monaural beats
 * - Planetary frequency healing (Cousto)
 * - Solfeggio frequency integration
 *
 * Sources:
 * - Hans Berger EEG discovery (1924)
 * - Monroe Institute binaural research
 * - Schumann resonance studies
 */
namespace Echoel::DSP
{

//==============================================================================
// Binaural Beat Generator
//==============================================================================

/**
 * Generates stereo binaural beats for brainwave entrainment
 * Left and right ears receive slightly different frequencies
 * Brain perceives the difference as a "beat"
 */
class BinauralBeatGenerator
{
public:
    BinauralBeatGenerator();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    //==========================================================================
    // Configuration
    //==========================================================================

    /** Set target brainwave frequency (the "beat" frequency) */
    void setTargetFrequency(double hz);

    /** Set target brainwave band */
    void setBrainwaveBand(BrainwaveFrequencies::Band band);

    /** Set carrier frequency (typically 200-400 Hz for comfort) */
    void setCarrierFrequency(double hz);

    /** Set output volume */
    void setVolume(float volume) { outputVolume = volume; }

    /** Enable/disable */
    void setEnabled(bool enabled) { this->enabled = enabled; }

    //==========================================================================
    // Presets
    //==========================================================================

    enum class Preset
    {
        // Brainwave states
        DeepSleep,          // Delta 2 Hz
        Meditation,         // Theta 6 Hz
        Relaxation,         // Alpha 10 Hz
        Focus,              // Beta 18 Hz
        Creativity,         // Theta/Alpha border 7.83 Hz
        PeakPerformance,    // Low Gamma 40 Hz

        // Schumann resonance
        SchumannFundamental,    // 7.83 Hz
        SchumannSecond,         // 14.3 Hz
        SchumannThird,          // 20.8 Hz

        // Solfeggio-aligned
        Solfeggio396,           // UT - Liberation
        Solfeggio528,           // MI - Transformation
        Solfeggio639,           // FA - Connection
        Solfeggio741,           // SOL - Awakening

        // Planetary
        EarthDay,               // 194.18 Hz (octaved down)
        SunTone,                // 126.22 Hz (octaved)
        MoonTone                // 210.42 Hz (octaved)
    };

    void loadPreset(Preset preset);

    //==========================================================================
    // Processing
    //==========================================================================

    /** Generate stereo binaural beat samples */
    void process(float* leftChannel, float* rightChannel, int numSamples);

    /** Get current frequencies */
    double getLeftFrequency() const { return leftFreq; }
    double getRightFrequency() const { return rightFreq; }
    double getBeatFrequency() const { return beatFreq; }

private:
    double sampleRate = 48000.0;
    bool enabled = true;

    double carrierFreq = 300.0;     // Base carrier frequency
    double beatFreq = 10.0;         // Target brainwave frequency
    double leftFreq = 295.0;        // Carrier - beat/2
    double rightFreq = 305.0;       // Carrier + beat/2

    float outputVolume = 0.5f;

    // Oscillator phases
    double leftPhase = 0.0;
    double rightPhase = 0.0;

    void updateFrequencies();
};

//==============================================================================
// Isochronic Tone Generator
//==============================================================================

/**
 * Generates isochronic tones - rhythmic pulses at brainwave frequencies
 * More effective than binaural beats for some applications
 * Works with speakers (doesn't require headphones)
 */
class IsochronicToneGenerator
{
public:
    IsochronicToneGenerator();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    //==========================================================================
    // Configuration
    //==========================================================================

    /** Set pulse rate (brainwave frequency) */
    void setPulseRate(double hz);

    /** Set carrier tone frequency */
    void setToneFrequency(double hz) { toneFreq = hz; }

    /** Set pulse duty cycle (0-1) */
    void setDutyCycle(float duty) { dutyCycle = juce::jlimit(0.1f, 0.9f, duty); }

    /** Set pulse shape */
    enum class PulseShape
    {
        Square,         // Hard on/off
        Sine,           // Smooth fade
        Triangle,       // Linear fade
        Exponential     // Natural decay
    };

    void setPulseShape(PulseShape shape) { pulseShape = shape; }

    /** Set volume */
    void setVolume(float volume) { outputVolume = volume; }

    /** Enable/disable */
    void setEnabled(bool enabled) { this->enabled = enabled; }

    //==========================================================================
    // Processing
    //==========================================================================

    /** Generate mono isochronic tone */
    void process(float* output, int numSamples);

    /** Generate stereo (same signal both channels) */
    void processStereo(float* left, float* right, int numSamples);

private:
    double sampleRate = 48000.0;
    bool enabled = true;

    double pulseRate = 10.0;        // Pulses per second
    double toneFreq = 200.0;        // Carrier tone
    float dutyCycle = 0.5f;
    PulseShape pulseShape = PulseShape::Sine;
    float outputVolume = 0.5f;

    double tonePhase = 0.0;
    double pulsePhase = 0.0;

    float calculatePulseEnvelope(double phase);
};

//==============================================================================
// Monaural Beat Generator
//==============================================================================

/**
 * Monaural beats - two tones mixed before reaching the ear
 * Creates actual acoustic beating (no headphones required)
 */
class MonauralBeatGenerator
{
public:
    MonauralBeatGenerator();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    void setFrequency1(double hz) { freq1 = hz; updateBeatFreq(); }
    void setFrequency2(double hz) { freq2 = hz; updateBeatFreq(); }
    void setVolume(float volume) { outputVolume = volume; }
    void setEnabled(bool enabled) { this->enabled = enabled; }

    /** Set by target beat frequency (will adjust freq2) */
    void setTargetBeatFrequency(double beatHz);

    void process(float* output, int numSamples);

    double getBeatFrequency() const { return beatFreq; }

private:
    double sampleRate = 48000.0;
    bool enabled = true;

    double freq1 = 200.0;
    double freq2 = 210.0;
    double beatFreq = 10.0;
    float outputVolume = 0.5f;

    double phase1 = 0.0;
    double phase2 = 0.0;

    void updateBeatFreq() { beatFreq = std::abs(freq2 - freq1); }
};

//==============================================================================
// Planetary Tone Generator (Cousto-based)
//==============================================================================

/**
 * Generates tones based on Cousto's Cosmic Octave planetary frequencies
 * Each planet has specific healing/meditation associations
 */
class PlanetaryToneGenerator
{
public:
    PlanetaryToneGenerator();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    //==========================================================================
    // Planet Selection
    //==========================================================================

    enum class Planet
    {
        Sun,
        Moon,
        Mercury,
        Venus,
        Earth,
        Mars,
        Jupiter,
        Saturn,
        Uranus,
        Neptune,
        Pluto
    };

    void setPlanet(Planet planet);
    Planet getCurrentPlanet() const { return currentPlanet; }

    /** Use orbital frequency (default) or rotational frequency */
    void setUseRotationalFrequency(bool rotational) { useRotation = rotational; updateFrequency(); }

    /** Set octave offset (transpose up/down) */
    void setOctaveOffset(int octaves) { octaveOffset = octaves; updateFrequency(); }

    //==========================================================================
    // Tone Configuration
    //==========================================================================

    enum class WaveShape
    {
        Sine,           // Pure tone
        Triangle,       // Softer harmonics
        SoftSquare,     // Rounded square
        Choir           // Multi-harmonic (choir-like)
    };

    void setWaveShape(WaveShape shape) { waveShape = shape; }
    void setVolume(float volume) { outputVolume = volume; }
    void setEnabled(bool enabled) { this->enabled = enabled; }

    //==========================================================================
    // Processing
    //==========================================================================

    void process(float* output, int numSamples);

    /** Get current frequency */
    double getFrequency() const { return currentFreq; }

    /** Get planetary info */
    const CosmicOctave::PlanetaryBody* getPlanetaryInfo() const;

private:
    double sampleRate = 48000.0;
    bool enabled = true;

    Planet currentPlanet = Planet::Earth;
    bool useRotation = false;
    int octaveOffset = 0;
    double currentFreq = 194.18;

    WaveShape waveShape = WaveShape::Sine;
    float outputVolume = 0.5f;

    double phase = 0.0;

    void updateFrequency();
    float generateSample(double phase);
};

//==============================================================================
// Solfeggio Frequency Generator
//==============================================================================

/**
 * Generates pure Solfeggio frequency tones
 * Each frequency has specific healing associations
 */
class SolfeggioGenerator
{
public:
    SolfeggioGenerator();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    //==========================================================================
    // Frequency Selection
    //==========================================================================

    enum class Tone
    {
        UT_396 = 0,     // Liberation from guilt/fear
        RE_417,         // Facilitating change
        MI_528,         // Transformation/miracles (DNA repair)
        FA_639,         // Connecting/relationships
        SOL_741,        // Awakening intuition
        LA_852,         // Returning to spiritual order
        SI_963,         // Divine consciousness
        Base_174,       // Foundation tone
        Base_285        // Quantum cognition
    };

    void setTone(Tone tone);
    Tone getCurrentTone() const { return currentTone; }

    /** Set multiple tones for chord */
    void setTones(const std::vector<Tone>& tones);

    //==========================================================================
    // Configuration
    //==========================================================================

    enum class WaveShape { Sine, Triangle, SoftSaw };
    void setWaveShape(WaveShape shape) { waveShape = shape; }

    void setVolume(float volume) { outputVolume = volume; }
    void setEnabled(bool enabled) { this->enabled = enabled; }

    /** Enable sub-octave (adds octave below) */
    void setSubOctave(bool enabled, float level = 0.3f);

    //==========================================================================
    // Processing
    //==========================================================================

    void process(float* output, int numSamples);

    /** Get current frequencies */
    std::vector<double> getCurrentFrequencies() const;

private:
    double sampleRate = 48000.0;
    bool enabled = true;

    Tone currentTone = Tone::MI_528;
    std::vector<Tone> activeTones;
    std::vector<double> phases;

    WaveShape waveShape = WaveShape::Sine;
    float outputVolume = 0.5f;

    bool subOctaveEnabled = false;
    float subOctaveLevel = 0.3f;
    double subOctavePhase = 0.0;

    double getToneFrequency(Tone tone) const;
    float generateSample(double phase);
};

//==============================================================================
// Schumann Resonance Generator
//==============================================================================

/**
 * Generates Schumann resonance frequencies
 * Earth's electromagnetic heartbeat (7.83 Hz fundamental)
 */
class SchumannGenerator
{
public:
    SchumannGenerator();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    //==========================================================================
    // Harmonic Selection
    //==========================================================================

    /** Set which Schumann harmonic to generate (0 = fundamental 7.83 Hz) */
    void setHarmonic(int harmonic);

    /** Enable multiple harmonics */
    void setHarmonics(const std::vector<int>& harmonics);

    /** Set harmonic amplitudes (0-1) */
    void setHarmonicAmplitude(int harmonic, float amplitude);

    //==========================================================================
    // Generation Mode
    //==========================================================================

    enum class Mode
    {
        PureTone,           // Raw Schumann frequency (sub-audio, modulates carrier)
        IsochronicPulse,    // Pulsed tone at Schumann rate
        BinauralBeat,       // Binaural entrainment to Schumann
        AmplitudeModulation // AM synthesis with Schumann as modulator
    };

    void setMode(Mode mode) { this->mode = mode; }

    /** Set carrier frequency for AM/binaural modes */
    void setCarrierFrequency(double hz) { carrierFreq = hz; }

    void setVolume(float volume) { outputVolume = volume; }
    void setEnabled(bool enabled) { this->enabled = enabled; }

    //==========================================================================
    // Processing
    //==========================================================================

    void process(float* output, int numSamples);
    void processStereo(float* left, float* right, int numSamples);

private:
    double sampleRate = 48000.0;
    bool enabled = true;

    std::vector<int> activeHarmonics = {0};  // Fundamental by default
    std::array<float, 8> harmonicAmplitudes = {{1.0f, 0.5f, 0.3f, 0.2f, 0.15f, 0.1f, 0.08f, 0.05f}};

    Mode mode = Mode::IsochronicPulse;
    double carrierFreq = 200.0;
    float outputVolume = 0.5f;

    // Oscillator states
    std::array<double, 8> schumannPhases = {};
    double carrierPhase = 0.0;
    double leftCarrierPhase = 0.0;
    double rightCarrierPhase = 0.0;
};

//==============================================================================
// Complete Entrainment Engine
//==============================================================================

/**
 * Combines all entrainment technologies into unified engine
 */
class BrainwaveEntrainmentEngine
{
public:
    BrainwaveEntrainmentEngine();
    ~BrainwaveEntrainmentEngine();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    //==========================================================================
    // Module Access
    //==========================================================================

    BinauralBeatGenerator& getBinauralGenerator() { return binaural; }
    IsochronicToneGenerator& getIsochronicGenerator() { return isochronic; }
    MonauralBeatGenerator& getMonauralGenerator() { return monaural; }
    PlanetaryToneGenerator& getPlanetaryGenerator() { return planetary; }
    SolfeggioGenerator& getSolfeggioGenerator() { return solfeggio; }
    SchumannGenerator& getSchumannGenerator() { return schumann; }

    //==========================================================================
    // Session Presets
    //==========================================================================

    enum class SessionPreset
    {
        // Relaxation
        DeepRelaxation,         // Alpha/Theta with Schumann
        StressRelief,           // Alpha with 528 Hz
        SleepInduction,         // Delta progression

        // Meditation
        MeditationBasic,        // Theta with Earth frequency
        MeditationDeep,         // Delta/Theta with planetary tones
        MeditationTranscendent, // Gamma peaks with Solfeggio

        // Focus
        FocusStudy,             // Beta with isochronic
        FocusCreative,          // Alpha/Theta border
        FocusPerformance,       // Low Gamma

        // Healing
        HealingPhysical,        // Delta with 528 Hz
        HealingEmotional,       // Theta with 639 Hz
        HealingSpiritual,       // Multiple Solfeggio

        // Custom
        Custom
    };

    void loadSessionPreset(SessionPreset preset);

    //==========================================================================
    // Mixing
    //==========================================================================

    struct ModuleMix
    {
        float binaural = 0.5f;
        float isochronic = 0.0f;
        float monaural = 0.0f;
        float planetary = 0.0f;
        float solfeggio = 0.3f;
        float schumann = 0.2f;
    };

    void setMix(const ModuleMix& mix) { this->mix = mix; }
    ModuleMix& getMix() { return mix; }

    void setMasterVolume(float volume) { masterVolume = volume; }

    //==========================================================================
    // Session Control
    //==========================================================================

    /** Start a timed session with gradual transitions */
    void startSession(double durationMinutes);
    void stopSession();
    bool isSessionActive() const { return sessionActive; }
    double getSessionProgress() const;  // 0-1

    //==========================================================================
    // Processing
    //==========================================================================

    void process(juce::AudioBuffer<float>& buffer);

private:
    double sampleRate = 48000.0;
    int samplesPerBlock = 512;

    // Generators
    BinauralBeatGenerator binaural;
    IsochronicToneGenerator isochronic;
    MonauralBeatGenerator monaural;
    PlanetaryToneGenerator planetary;
    SolfeggioGenerator solfeggio;
    SchumannGenerator schumann;

    // Mixing
    ModuleMix mix;
    float masterVolume = 0.7f;

    // Session
    bool sessionActive = false;
    double sessionDuration = 0.0;
    double sessionElapsed = 0.0;

    // Work buffers
    std::vector<float> tempBufferL;
    std::vector<float> tempBufferR;
    std::vector<float> mixBufferL;
    std::vector<float> mixBufferR;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BrainwaveEntrainmentEngine)
};

}  // namespace Echoel::DSP
