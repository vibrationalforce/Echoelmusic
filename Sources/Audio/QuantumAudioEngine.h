#pragma once

#include <JuceHeader.h>

/**
 * QuantumAudioEngine - Quantum Physics-Inspired Audio Processing
 *
 * ⚠️ IMPORTANT DISCLAIMER ⚠️
 * This is NOT real quantum computing! These are EDUCATIONAL ANALOGIES that use
 * quantum physics concepts to inspire creative audio processing techniques.
 *
 * QUANTUM-INSPIRED TECHNIQUES:
 * - Superposition: Multiple waveforms existing simultaneously (additive synthesis)
 * - Entanglement: Correlated signal processing (cross-modulation, sidechaining)
 * - Uncertainty: Probabilistic processing (granular synthesis, randomization)
 * - Wave Function Collapse: State selection (multi-algorithm processing)
 * - Tunneling: Frequency barrier crossing (spectral processing)
 * - Interference: Wave combination (phase relationships)
 * - Decoherence: Gradual state decay (reverb, delay)
 *
 * EDUCATIONAL PURPOSE:
 * These concepts help understand complex audio processing through quantum analogies.
 * They also create unique, experimental sounds!
 *
 * Usage:
 * ```cpp
 * QuantumAudioEngine quantum;
 *
 * // Superposition synthesis
 * auto superposed = quantum.superpositionSynth(frequency, numStates);
 *
 * // Entangled modulation
 * quantum.entangleSignals(carrier, modulator);
 *
 * // Uncertainty-based granular
 * auto uncertain = quantum.uncertaintyGranular(audio, uncertainty);
 * ```
 */

//==============================================================================
// Quantum State Representation
//==============================================================================

struct QuantumState
{
    // Wave function (audio buffer)
    juce::AudioBuffer<float> waveFunction;

    // Probability amplitude (0-1)
    float amplitude = 1.0f;

    // Phase (0-2π)
    float phase = 0.0f;

    // Frequency
    float frequency = 440.0f;

    // Coherence (how stable the state is, 0-1)
    float coherence = 1.0f;

    // Energy level
    float energy = 0.0f;

    // Quantum number (for indexing)
    int quantumNumber = 0;
};

//==============================================================================
// Superposition Synthesis
//==============================================================================

class SuperpositionSynthesizer
{
public:
    SuperpositionSynthesizer();

    /**
     * Create superposition of multiple quantum states
     * (Additive synthesis where multiple frequencies exist simultaneously)
     */
    juce::AudioBuffer<float> createSuperposition(
        const juce::Array<QuantumState>& states,
        double sampleRate);

    /**
     * Add state to superposition
     */
    void addState(const QuantumState& state);

    /**
     * Remove state
     */
    void removeState(int quantumNumber);

    /**
     * Get all states
     */
    juce::Array<QuantumState> getStates() const;

    /**
     * Collapse wave function to single state (weighted random selection)
     */
    QuantumState collapseWaveFunction();

private:
    juce::Array<QuantumState> states;
    juce::Random random;
};

//==============================================================================
// Quantum Entanglement (Cross-Modulation)
//==============================================================================

class QuantumEntanglement
{
public:
    QuantumEntanglement();

    /**
     * Entangle two signals (one modulates the other)
     * Changes to signal A affect signal B
     */
    struct EntangledPair
    {
        juce::AudioBuffer<float> signalA;
        juce::AudioBuffer<float> signalB;
    };

    EntangledPair entangleSignals(
        const juce::AudioBuffer<float>& signalA,
        const juce::AudioBuffer<float>& signalB,
        float entanglementStrength);

    /**
     * FM-style entanglement (carrier-modulator)
     */
    juce::AudioBuffer<float> fmEntanglement(
        float carrierFreq,
        float modulatorFreq,
        float modulationIndex,
        double sampleRate,
        int numSamples);

    /**
     * Ring modulation entanglement
     */
    juce::AudioBuffer<float> ringModulationEntanglement(
        const juce::AudioBuffer<float>& signalA,
        const juce::AudioBuffer<float>& signalB);

private:
    float entanglementPhase = 0.0f;
};

//==============================================================================
// Heisenberg Uncertainty (Granular Synthesis)
//==============================================================================

class HeisenbergUncertainty
{
public:
    HeisenbergUncertainty();

    /**
     * Uncertainty principle: Cannot know exact position AND momentum simultaneously
     * Analogy: Granular synthesis where grain position and frequency vary probabilistically
     */
    juce::AudioBuffer<float> uncertaintyGranular(
        const juce::AudioBuffer<float>& source,
        float uncertaintyAmount,      // 0-1 (how much randomization)
        double sampleRate);

    /**
     * Set grain parameters
     */
    void setGrainSize(int samples);
    void setGrainDensity(float grainsPerSecond);
    void setPositionUncertainty(float amount);  // 0-1
    void setFrequencyUncertainty(float amount); // 0-1

private:
    int grainSize = 1024;
    float grainDensity = 50.0f;
    float positionUncertainty = 0.5f;
    float frequencyUncertainty = 0.5f;

    juce::Random random;

    struct Grain
    {
        float position = 0.0f;
        float frequency = 1.0f;
        float amplitude = 1.0f;
        int length = 0;
    };

    juce::Array<Grain> generateGrains(int numSamples, double sampleRate);
};

//==============================================================================
// Quantum Tunneling (Spectral Processing)
//==============================================================================

class QuantumTunneling
{
public:
    QuantumTunneling();

    /**
     * Quantum tunneling: Particles can pass through energy barriers
     * Analogy: Frequencies can "tunnel" from one band to another
     */
    juce::AudioBuffer<float> spectralTunneling(
        const juce::AudioBuffer<float>& audio,
        float barrierFrequency,
        float tunnelingProbability,
        double sampleRate);

    /**
     * Frequency barrier crossing
     */
    juce::AudioBuffer<float> crossFrequencyBarrier(
        const juce::AudioBuffer<float>& audio,
        float lowBarrier,
        float highBarrier,
        float tunnelingAmount,
        double sampleRate);

private:
    juce::dsp::FFT fft;
    juce::Random random;
};

//==============================================================================
// Wave Interference Patterns
//==============================================================================

class WaveInterference
{
public:
    WaveInterference();

    /**
     * Constructive/destructive interference
     * Analogy: Phase relationships between signals
     */
    juce::AudioBuffer<float> createInterferencePattern(
        const juce::AudioBuffer<float>& wave1,
        const juce::AudioBuffer<float>& wave2,
        float phaseOffset);

    /**
     * Standing wave creation
     */
    juce::AudioBuffer<float> createStandingWave(
        float frequency,
        float amplitude,
        double sampleRate,
        int numSamples);

    /**
     * Diffraction-like spreading
     */
    juce::AudioBuffer<float> diffractionSpread(
        const juce::AudioBuffer<float>& audio,
        float spreadAmount);

private:
    float calculateInterference(float amplitude1, float amplitude2, float phaseDiff);
};

//==============================================================================
// Quantum Decoherence (Decay/Reverb)
//==============================================================================

class QuantumDecoherence
{
public:
    QuantumDecoherence();

    /**
     * Decoherence: Quantum system gradually loses coherence
     * Analogy: Signal gradually decays and becomes "classical" (reverb/delay)
     */
    juce::AudioBuffer<float> applyDecoherence(
        const juce::AudioBuffer<float>& audio,
        float coherenceTime,
        double sampleRate);

    /**
     * Gradual state collapse
     */
    juce::AudioBuffer<float> gradualCollapse(
        const juce::AudioBuffer<float>& audio,
        float collapseRate,
        double sampleRate);

private:
    juce::dsp::Reverb reverb;
    juce::dsp::DelayLine<float> delay;
};

//==============================================================================
// Schrödinger's Oscillator (Probabilistic Synthesis)
//==============================================================================

class SchrodingersOscillator
{
public:
    SchrodingersOscillator();

    /**
     * Schrödinger's Cat: System in superposition until observed
     * Analogy: Oscillator randomly switches between waveforms until "measured"
     */
    juce::AudioBuffer<float> probabilisticOscillator(
        float frequency,
        const juce::StringArray& possibleWaveforms,
        float measurementRate,
        double sampleRate,
        int numSamples);

    /**
     * Set possible waveform states
     */
    void setPossibleWaveforms(const juce::StringArray& waveforms);

private:
    juce::StringArray waveforms;
    juce::Random random;
    int currentWaveform = 0;
    float lastMeasurementTime = 0.0f;

    float generateWaveformSample(const juce::String& waveform, float phase);
};

//==============================================================================
// QuantumAudioEngine - Main Class
//==============================================================================

class QuantumAudioEngine
{
public:
    QuantumAudioEngine();
    ~QuantumAudioEngine();

    //==========================================================================
    // Educational Disclaimer
    //==========================================================================

    /**
     * Get educational disclaimer
     */
    juce::String getEducationalDisclaimer() const;

    //==========================================================================
    // Superposition Synthesis
    //==========================================================================

    /**
     * Create superposition of frequencies
     */
    juce::AudioBuffer<float> superpositionSynth(
        float fundamentalFreq,
        int numStates,
        double sampleRate,
        int numSamples);

    /**
     * Add quantum state
     */
    void addQuantumState(const QuantumState& state);

    /**
     * Collapse to single state
     */
    QuantumState collapseWaveFunction();

    //==========================================================================
    // Entanglement
    //==========================================================================

    /**
     * Entangle two audio signals
     */
    juce::AudioBuffer<float> entangleSignals(
        const juce::AudioBuffer<float>& signalA,
        const juce::AudioBuffer<float>& signalB,
        float strength);

    /**
     * FM entanglement
     */
    juce::AudioBuffer<float> fmEntanglement(
        float carrierFreq,
        float modulatorFreq,
        float modIndex,
        double sampleRate,
        int numSamples);

    //==========================================================================
    // Uncertainty Principle
    //==========================================================================

    /**
     * Uncertainty-based granular synthesis
     */
    juce::AudioBuffer<float> uncertaintyGranular(
        const juce::AudioBuffer<float>& source,
        float uncertainty,
        double sampleRate);

    /**
     * Set granular parameters
     */
    void setGranularParameters(int grainSize, float density);

    //==========================================================================
    // Quantum Tunneling
    //==========================================================================

    /**
     * Spectral tunneling effect
     */
    juce::AudioBuffer<float> spectralTunneling(
        const juce::AudioBuffer<float>& audio,
        float barrierFreq,
        float probability,
        double sampleRate);

    //==========================================================================
    // Wave Interference
    //==========================================================================

    /**
     * Create interference pattern
     */
    juce::AudioBuffer<float> createInterference(
        const juce::AudioBuffer<float>& wave1,
        const juce::AudioBuffer<float>& wave2,
        float phaseOffset);

    /**
     * Standing wave
     */
    juce::AudioBuffer<float> createStandingWave(
        float frequency,
        double sampleRate,
        int numSamples);

    //==========================================================================
    // Decoherence
    //==========================================================================

    /**
     * Apply quantum decoherence (decay)
     */
    juce::AudioBuffer<float> applyDecoherence(
        const juce::AudioBuffer<float>& audio,
        float coherenceTime,
        double sampleRate);

    //==========================================================================
    // Schrödinger's Oscillator
    //==========================================================================

    /**
     * Probabilistic waveform oscillator
     */
    juce::AudioBuffer<float> schrodingersOscillator(
        float frequency,
        double sampleRate,
        int numSamples);

    //==========================================================================
    // Preset Quantum Effects
    //==========================================================================

    /**
     * Apply preset quantum-inspired effect
     */
    juce::AudioBuffer<float> applyQuantumEffect(
        const juce::AudioBuffer<float>& audio,
        const juce::String& effectName,
        double sampleRate);

    /**
     * Get available quantum effects
     */
    juce::StringArray getAvailableQuantumEffects() const;

    //==========================================================================
    // Educational Info
    //==========================================================================

    /**
     * Get explanation of quantum concept
     */
    juce::String getConceptExplanation(const juce::String& concept) const;

    /**
     * Get all quantum concepts
     */
    juce::StringArray getAllConcepts() const;

private:
    SuperpositionSynthesizer superposition;
    QuantumEntanglement entanglement;
    HeisenbergUncertainty uncertainty;
    QuantumTunneling tunneling;
    WaveInterference interference;
    QuantumDecoherence decoherence;
    SchrodingersOscillator schrodingers;

    std::map<juce::String, juce::String> conceptExplanations;

    void initializeExplanations();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(QuantumAudioEngine)
};
