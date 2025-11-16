#pragma once

#include <JuceHeader.h>
#include "../DSP/SpectralFramework.h"
#include <vector>
#include <array>

/**
 * AdditiveAI - Intelligent Additive Synthesis
 *
 * 512-partial additive synthesizer with AI-powered harmonic evolution.
 * Creates evolving, organic timbres through intelligent partial manipulation.
 *
 * Features:
 * - 512 independent sine wave partials
 * - AI-powered harmonic evolution (ML predicts natural partial movement)
 * - Spectral morphing between multiple sources
 * - Audio resynthesis (analyze audio → additive model)
 * - Individual partial control (amplitude, frequency, phase)
 * - Harmonic/inharmonic spectrum generation
 * - Spectral filtering per partial
 * - Bio-reactive spectral evolution
 * - Real-time spectral drawing/editing
 */
class AdditiveAI : public juce::Synthesiser
{
public:
    //==========================================================================
    // Partial Management
    //==========================================================================

    static constexpr int maxPartials = 512;

    struct Partial
    {
        float frequency = 0.0f;         // Hz
        float amplitude = 0.0f;         // 0.0 to 1.0
        float phase = 0.0f;             // 0.0 to 1.0
        bool enabled = true;

        // Evolution parameters
        float evolutionSpeed = 0.0f;    // How fast this partial evolves
        float evolutionTarget = 0.0f;   // Target amplitude
    };

    //==========================================================================
    // Synthesis Modes
    //==========================================================================

    enum class SynthesisMode
    {
        Harmonic,           // Traditional harmonic series
        Inharmonic,         // Stretched/compressed harmonics
        Spectral,           // Custom spectrum
        Resynthesis,        // From analyzed audio
        Morph,              // Morphing between spectra
        AIEvolution         // AI-guided evolution
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    AdditiveAI();
    ~AdditiveAI() override = default;

    //==========================================================================
    // Synthesis Mode
    //==========================================================================

    void setSynthesisMode(SynthesisMode mode);
    SynthesisMode getSynthesisMode() const { return synthesisMode; }

    //==========================================================================
    // Partial Control
    //==========================================================================

    /** Get partial array */
    std::array<Partial, maxPartials>& getPartials() { return partials; }
    const std::array<Partial, maxPartials>& getPartials() const { return partials; }

    /** Set number of active partials */
    void setNumActivePartials(int num);
    int getNumActivePartials() const { return numActivePartials; }

    /** Generate harmonic series */
    void generateHarmonicSeries(float fundamental, int numHarmonics);

    /** Generate inharmonic spectrum */
    void generateInharmonicSpectrum(float fundamental, float stretch);

    //==========================================================================
    // Audio Resynthesis
    //==========================================================================

    /** Analyze audio and create additive model */
    void analyzeAudio(const juce::AudioBuffer<float>& audio);

    /** Get quality of current resynthesis (0.0 to 1.0) */
    float getResynthesisQuality() const { return resynthesisQuality; }

    //==========================================================================
    // Spectral Morphing
    //==========================================================================

    /** Load spectrum A (source) */
    void loadSpectrumA(const std::array<Partial, maxPartials>& spectrum);

    /** Load spectrum B (target) */
    void loadSpectrumB(const std::array<Partial, maxPartials>& spectrum);

    /** Set morph position (0.0 = A, 1.0 = B) */
    void setMorphPosition(float position);
    float getMorphPosition() const { return morphPosition; }

    //==========================================================================
    // AI Evolution
    //==========================================================================

    /** Enable AI-powered evolution */
    void setAIEvolutionEnabled(bool enabled);
    bool isAIEvolutionEnabled() const { return aiEvolutionEnabled; }

    /** Set evolution speed (0.0 = frozen, 1.0 = fast) */
    void setEvolutionSpeed(float speed);
    float getEvolutionSpeed() const { return evolutionSpeed; }

    /** Set evolution complexity (0.0 = simple, 1.0 = complex) */
    void setEvolutionComplexity(float complexity);

    /** Trigger new evolution target */
    void evolveToNewTarget();

    //==========================================================================
    // Spectral Compression
    //==========================================================================

    /** Reduce 512 partials to N most important (AI-based) */
    void compressSpectrum(int targetPartials);

    /** Get compression ratio */
    float getCompressionRatio() const;

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float breath);

    struct BioMapping
    {
        float hrvToEvolution = 0.5f;     // HRV modulates evolution speed
        float coherenceToHarmonics = 0.5f; // Coherence affects harmonic content
        float breathToAmplitude = 0.3f;  // Breath modulates overall amplitude
    };

    void setBioMapping(const BioMapping& mapping);

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

    //==========================================================================
    // Visualization
    //==========================================================================

    /** Get current spectrum for visualization */
    std::vector<float> getCurrentSpectrum() const;

    /** Get evolution trajectory (predicted future spectrum) */
    std::vector<std::vector<float>> getEvolutionTrajectory(int numSteps) const;

private:
    //==========================================================================
    // Voice Class
    //==========================================================================

    class AdditiveVoice : public juce::SynthesiserVoice
    {
    public:
        AdditiveVoice(AdditiveAI& parent);

        bool canPlaySound(juce::SynthesiserSound*) override { return true; }
        void startNote(int midiNoteNumber, float velocity,
                      juce::SynthesiserSound*, int currentPitchWheelPosition) override;
        void stopNote(float velocity, bool allowTailOff) override;
        void pitchWheelMoved(int newPitchWheelValue) override {}
        void controllerMoved(int controllerNumber, int newControllerValue) override {}
        void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                            int startSample, int numSamples) override;

    private:
        AdditiveAI& synth;
        std::array<double, maxPartials> partialPhases;
        float baseFrequency = 440.0f;
    };

    //==========================================================================
    // State
    //==========================================================================

    SynthesisMode synthesisMode = SynthesisMode::Harmonic;
    std::array<Partial, maxPartials> partials;
    int numActivePartials = 64;

    // Morphing
    std::array<Partial, maxPartials> spectrumA;
    std::array<Partial, maxPartials> spectrumB;
    float morphPosition = 0.0f;

    // AI Evolution
    bool aiEvolutionEnabled = false;
    float evolutionSpeed = 0.5f;
    float evolutionComplexity = 0.5f;

    // Resynthesis
    float resynthesisQuality = 0.0f;

    // Bio-reactive
    bool bioReactiveEnabled = false;
    BioMapping bioMapping;
    float bioHRV = 0.5f, bioCoherence = 0.5f, bioBreath = 0.5f;

    double currentSampleRate = 48000.0;

    SpectralFramework spectralEngine;

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (AdditiveAI)
};
