#pragma once

#include <JuceHeader.h>
#include <vector>
#include <random>

/**
 * Audio Humanizer / Movement Generator
 *
 * Professional audio humanization inspired by Rast Sound Naturaliser 2 (2025).
 * Adds subtle, time-sliced variations to create organic, human-like movement.
 *
 * **Innovation**: Bio-reactive humanization with HRV-controlled variation intensity.
 *
 * Features:
 * - Time-sliced processing (sync to musical divisions: 16th, 8th, quarter, etc.)
 * - 4 dimensions of variation:
 *   - Spectral: Per-frequency-band level variations (±0.5dB per band)
 *   - Transient: Attack/sustain timing variations (±10%)
 *   - Colour: Tone/timbre variations (±2% filter cutoff/resonance)
 *   - Noise: Subtle noise floor variations (±3dB)
 * - Advanced Detect mode (intelligent transient analysis)
 * - Smooth control (blend variations between slices)
 * - Bio-reactive intensity (HRV controls variation amount)
 * - LFO modulation of variation parameters
 * - Tempo sync or free-running
 *
 * Use Cases:
 * - Humanize programmed drums and MIDI
 * - Add life to static loops
 * - Subtle movement for ambient textures
 * - Remove "robotic" feel from quantized music
 * - Create evolving soundscapes
 * - Bio-reactive music that "breathes" with user
 *
 * Dimensions Explained:
 * - **Spectral**: Each frequency band gets slightly different gain
 * - **Transient**: Attack/decay envelopes vary slightly per slice
 * - **Colour**: Filter characteristics drift subtly
 * - **Noise**: Background noise level fluctuates organically
 */
class AudioHumanizer
{
public:
    //==========================================================================
    // Time Division (Musical Sync)
    //==========================================================================

    enum class TimeDivision
    {
        Sixteenth,      // 1/16 note
        Eighth,         // 1/8 note
        Quarter,        // 1/4 note
        Half,           // 1/2 note
        Whole,          // Whole note
        TwoBar,         // 2 bars
        FourBar         // 4 bars
    };

    //==========================================================================
    // Detect Mode (Transient Intelligence)
    //==========================================================================

    enum class DetectMode
    {
        Basic,          // Simple RMS-based detection
        Advanced        // Intelligent transient analysis (adapts to content)
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    AudioHumanizer();
    ~AudioHumanizer() = default;

    //==========================================================================
    // Master Controls
    //==========================================================================

    /** Set overall humanization amount (0.0 = off, 1.0 = maximum) */
    void setHumanizationAmount(float amount);

    /** Set time division for slicing */
    void setTimeDivision(TimeDivision division);

    /** Set tempo in BPM (for sync mode) */
    void setTempo(float bpm);

    /** Enable tempo sync (false = free-running with manual slice time) */
    void setTempoSyncEnabled(bool enable);

    /** Set manual slice time in ms (used when tempo sync is off) */
    void setSliceTimeMs(float timeMs);

    /** Set detect mode (basic or advanced) */
    void setDetectMode(DetectMode mode);

    //==========================================================================
    // Dimension Controls (0.0 to 1.0 each)
    //==========================================================================

    /** Set spectral variation amount (frequency-dependent level changes) */
    void setSpectralAmount(float amount);

    /** Set transient variation amount (attack/sustain timing changes) */
    void setTransientAmount(float amount);

    /** Set colour variation amount (tone/timbre drift) */
    void setColourAmount(float amount);

    /** Set noise variation amount (noise floor fluctuations) */
    void setNoiseAmount(float amount);

    //==========================================================================
    // Smoothing
    //==========================================================================

    /** Set smooth amount (0.0 = stepped, 1.0 = fully smoothed between slices) */
    void setSmoothAmount(float amount);

    //==========================================================================
    // LFO Modulation
    //==========================================================================

    /** Enable LFO modulation of variation parameters */
    void setLFOEnabled(bool enable);

    /** Set LFO rate in Hz (0.01 to 10 Hz) */
    void setLFORate(float rateHz);

    /** Set LFO depth (0.0 to 1.0) */
    void setLFODepth(float depth);

    //==========================================================================
    // Bio-Reactive Integration
    //==========================================================================

    /** Enable bio-reactive humanization (HRV controls intensity) */
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

    /** Process audio buffer */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Analysis
    //==========================================================================

    /** Get current slice index */
    int getCurrentSliceIndex() const { return currentSliceIndex; }

    /** Get current spectral variation (0.0 to 1.0) */
    float getCurrentSpectralVariation() const { return currentSpectralVar; }

    /** Get current transient variation (0.0 to 1.0) */
    float getCurrentTransientVariation() const { return currentTransientVar; }

    /** Get detected transients per second */
    float getTransientRate() const { return transientRate; }

private:
    //==========================================================================
    // Constants
    //==========================================================================

    static constexpr int NUM_SPECTRAL_BANDS = 50;  // Frequency bands for spectral variation
    static constexpr int MAX_SLICE_SAMPLES = 192000;  // Max slice length (4 seconds @ 48kHz)

    //==========================================================================
    // Parameters
    //==========================================================================

    float humanizationAmount = 0.5f;

    TimeDivision currentDivision = TimeDivision::Sixteenth;
    float currentTempo = 120.0f;
    bool tempoSyncEnabled = true;
    float manualSliceTimeMs = 100.0f;

    DetectMode detectMode = DetectMode::Advanced;

    // Dimension amounts
    float spectralAmount = 0.5f;
    float transientAmount = 0.5f;
    float colourAmount = 0.5f;
    float noiseAmount = 0.3f;

    float smoothAmount = 0.5f;

    // LFO
    bool lfoEnabled = false;
    float lfoRate = 0.5f;  // Hz
    float lfoDepth = 0.3f;

    // Bio-reactive
    bool bioReactiveEnabled = false;
    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.0f;

    double currentSampleRate = 48000.0;

    //==========================================================================
    // Slice Timing
    //==========================================================================

    int samplesPerSlice = 0;
    int samplesSinceSliceStart = 0;
    int currentSliceIndex = 0;

    //==========================================================================
    // Variation State (Current Slice)
    //==========================================================================

    std::vector<float> currentSpectralGains;       // Per-band gains (50 bands)
    std::vector<float> nextSpectralGains;          // For smoothing
    std::vector<float> smoothedSpectralGains;

    float currentTransientScale = 1.0f;
    float nextTransientScale = 1.0f;
    float smoothedTransientScale = 1.0f;

    float currentColourShift = 0.0f;
    float nextColourShift = 0.0f;
    float smoothedColourShift = 0.0f;

    float currentNoiseLevel = 0.0f;
    float nextNoiseLevel = 0.0f;
    float smoothedNoiseLevel = 0.0f;

    //==========================================================================
    // Transient Detection (Advanced Mode)
    //==========================================================================

    float previousSample = 0.0f;
    float envelopeFollower = 0.0f;
    float transientThreshold = 0.1f;
    int transientCount = 0;
    int samplesSinceLastTransient = 0;

    //==========================================================================
    // LFO State
    //==========================================================================

    float lfoPhase = 0.0f;

    //==========================================================================
    // Random Number Generator
    //==========================================================================

    std::mt19937 rng;
    std::normal_distribution<float> normalDist;

    //==========================================================================
    // Metering
    //==========================================================================

    float currentSpectralVar = 0.0f;
    float currentTransientVar = 0.0f;
    float transientRate = 0.0f;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    /** Calculate samples per slice based on tempo and division */
    void updateSliceTiming();

    /** Generate new random variations for next slice */
    void generateNewVariations();

    /** Apply bio-reactive modulation to parameters */
    void applyBioReactiveModulation();

    /** Update LFO and apply modulation */
    void updateLFO();

    /** Detect transients in audio (advanced mode) */
    bool detectTransient(float sample);

    /** Get time division multiplier (quarters per division) */
    float getTimeDivisionMultiplier() const;

    /** Apply spectral variations to buffer */
    void applySpectralVariations(juce::AudioBuffer<float>& buffer);

    /** Apply transient variations to buffer */
    void applyTransientVariations(juce::AudioBuffer<float>& buffer);

    /** Apply colour (tone) variations to buffer */
    void applyColourVariations(juce::AudioBuffer<float>& buffer);

    /** Apply noise variations to buffer */
    void applyNoiseVariations(juce::AudioBuffer<float>& buffer);

    /** Get random variation value with normal distribution */
    float getRandomVariation(float amount);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (AudioHumanizer)
};
