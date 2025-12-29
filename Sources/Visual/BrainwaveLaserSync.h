#pragma once

/**
 * BrainwaveLaserSync.h - Brainwave-Laser Synchronization Engine
 *
 * ╔══════════════════════════════════════════════════════════════════════════╗
 * ║  RALPH WIGGUM OVERALL OPTIMAL MODE                                       ║
 * ╠══════════════════════════════════════════════════════════════════════════╣
 * ║                                                                          ║
 * ║  Synchronizes laser visuals with brainwave entrainment for maximum       ║
 * ║  psychoacoustic and visual impact. Implements validated 40 Hz Gamma      ║
 * ║  flicker patterns alongside VNS-range visual modulation.                 ║
 * ║                                                                          ║
 * ║  LATENCY TARGETS:                                                        ║
 * ║    • Audio-to-laser sync: < 2ms                                          ║
 * ║    • Frame generation: < 0.5ms                                           ║
 * ║    • Color modulation: < 10µs per point                                  ║
 * ║                                                                          ║
 * ║  SCIENTIFIC BASIS:                                                       ║
 * ║    • 40 Hz Gamma flicker - MIT Alzheimer's research (2024)               ║
 * ║    • Alpha (8-12 Hz) - Relaxation state induction                        ║
 * ║    • Theta (4-8 Hz) - Meditative visual patterns                         ║
 * ║                                                                          ║
 * ╚══════════════════════════════════════════════════════════════════════════╝
 */

#include "../DSP/EntrainmentOptimizations.h"
#include "../DSP/BrainwaveEntrainment.h"
#include <JuceHeader.h>
#include <array>
#include <atomic>

namespace Echoel::Visual
{

//==============================================================================
// Brainwave Visualization Mode
//==============================================================================

enum class BrainwaveVisualMode
{
    // [VALIDATED] Research-supported modes
    Gamma40Hz,              // MIT-validated 40 Hz flicker
    VNS_FlickerRange,       // 20-30 Hz VNS visual support
    AlphaRelaxation,        // 8-12 Hz calming visuals

    // [LIMITED EVIDENCE] Based on brainwave research
    ThetaMeditation,        // 4-8 Hz deep meditation patterns
    DeltaSleep,             // 0.5-4 Hz slow wave patterns
    BetaFocus,              // 12-30 Hz alert patterns

    // [ESOTERIC] No controlled evidence
    SchumannResonance,      // 7.83 Hz Earth frequency
    PlanetaryAlignment,     // Cousto-based planetary tones
    SolfeggioVisualization  // Solfeggio frequency colors
};

//==============================================================================
// Color Mapping Strategies
//==============================================================================

namespace FrequencyColorMapping
{
    // [SCIENTIFIC] True physical octavation (Cousto formula)
    // 440 Hz × 2^40 = 484 THz = 619 nm (orange)
    inline juce::Colour audioToLightColor(double audioHz)
    {
        constexpr double VISIBLE_MIN_HZ = 384e12;   // ~780nm red
        constexpr double VISIBLE_MAX_HZ = 789e12;   // ~380nm violet

        // Octave up until visible range
        double freq = audioHz;
        while (freq < VISIBLE_MIN_HZ)
            freq *= 2.0;

        // If above visible, octave down
        while (freq > VISIBLE_MAX_HZ)
            freq *= 0.5;

        // Normalize to 0-1 within visible spectrum
        double normalized = (freq - VISIBLE_MIN_HZ) / (VISIBLE_MAX_HZ - VISIBLE_MIN_HZ);
        normalized = juce::jlimit(0.0, 1.0, normalized);

        // Rainbow spectrum (red -> violet)
        float hue = static_cast<float>(normalized * 0.8f);  // 0 = red, 0.8 = violet
        return juce::Colour::fromHSV(hue, 1.0f, 1.0f, 1.0f);
    }

    // [ESOTERIC] Chakra color mapping (NO EVIDENCE)
    inline juce::Colour chakraColor(int chakraIndex)
    {
        constexpr std::array<uint32_t, 7> CHAKRA_COLORS = {
            0xFF0000,  // Root - Red
            0xFF7F00,  // Sacral - Orange
            0xFFFF00,  // Solar Plexus - Yellow
            0x00FF00,  // Heart - Green
            0x0000FF,  // Throat - Blue
            0x4B0082,  // Third Eye - Indigo
            0x9400D3   // Crown - Violet
        };
        int idx = juce::jlimit(0, 6, chakraIndex);
        return juce::Colour(CHAKRA_COLORS[idx]);
    }

    // Brainwave band to color (artistic interpretation)
    inline juce::Colour brainwaveBandColor(DSP::BrainwaveFrequencies::Band band)
    {
        using Band = DSP::BrainwaveFrequencies::Band;
        switch (band)
        {
            case Band::Delta:     return juce::Colours::darkblue;
            case Band::Theta:     return juce::Colours::purple;
            case Band::Alpha:     return juce::Colours::cyan;
            case Band::Beta:      return juce::Colours::green;
            case Band::Gamma:     return juce::Colours::yellow;
            case Band::HighGamma: return juce::Colours::orange;
            default:              return juce::Colours::white;
        }
    }
}

//==============================================================================
/**
 * @brief Brainwave-Laser Sync Engine
 *
 * Ultra-low latency synchronization between audio entrainment
 * and laser visual output.
 */
class BrainwaveLaserSync
{
public:
    BrainwaveLaserSync();
    ~BrainwaveLaserSync();

    //==========================================================================
    // Initialization
    //==========================================================================

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    //==========================================================================
    // Sync Configuration
    //==========================================================================

    /** Set the visual mode for brainwave synchronization */
    void setVisualMode(BrainwaveVisualMode mode);
    BrainwaveVisualMode getVisualMode() const { return currentMode; }

    /** Set target entrainment frequency (Hz) */
    void setTargetFrequency(double hz);
    double getTargetFrequency() const { return targetFrequency; }

    /** Enable/disable audio-reactive modulation */
    void setAudioReactive(bool enabled) { audioReactive = enabled; }
    bool isAudioReactive() const { return audioReactive; }

    /** Set intensity of visual effect (0-1) */
    void setIntensity(float intensity) { this->intensity = juce::jlimit(0.0f, 1.0f, intensity); }
    float getIntensity() const { return intensity; }

    //==========================================================================
    // Validated Presets
    //==========================================================================

    /** Load MIT 40 Hz Gamma preset (Alzheimer's research) */
    void loadGamma40HzPreset()
    {
        setVisualMode(BrainwaveVisualMode::Gamma40Hz);
        setTargetFrequency(40.0);
        setIntensity(0.8f);
    }

    /** Load VNS-range preset (20-30 Hz) */
    void loadVNSPreset(double frequencyHz = 25.0)
    {
        setVisualMode(BrainwaveVisualMode::VNS_FlickerRange);
        setTargetFrequency(juce::jlimit(20.0, 30.0, frequencyHz));
        setIntensity(0.7f);
    }

    /** Load Alpha relaxation preset */
    void loadAlphaRelaxationPreset()
    {
        setVisualMode(BrainwaveVisualMode::AlphaRelaxation);
        setTargetFrequency(10.0);
        setIntensity(0.6f);
    }

    //==========================================================================
    // Processing
    //==========================================================================

    /** Process audio block and update visual parameters */
    void processAudioBlock(const float* audioData, int numSamples);

    /** Get current flicker state (0-1) for laser intensity modulation */
    float getCurrentFlickerValue() const { return flickerValue.load(std::memory_order_relaxed); }

    /** Get current color for laser output */
    juce::Colour getCurrentColor() const;

    /** Get current phase (0-1) of entrainment cycle */
    float getCurrentPhase() const { return currentPhase.load(std::memory_order_relaxed); }

    //==========================================================================
    // Laser Integration Points
    //==========================================================================

    /** Apply entrainment modulation to laser point color */
    juce::Colour modulateColor(juce::Colour baseColor) const;

    /** Apply entrainment modulation to laser point brightness */
    float modulateBrightness(float baseBrightness) const;

    /** Get strobe/flicker pattern for current frame */
    bool shouldBlankForFlicker() const;

    //==========================================================================
    // Performance Metrics
    //==========================================================================

    struct SyncMetrics
    {
        double latencyMs = 0.0;
        double processingTimeUs = 0.0;
        float phaseAccuracy = 0.0f;
        int framesProcessed = 0;
    };

    SyncMetrics getMetrics() const { return metrics; }
    void resetMetrics() { metrics = SyncMetrics(); }

private:
    double sampleRate = 48000.0;
    int blockSize = 512;

    BrainwaveVisualMode currentMode = BrainwaveVisualMode::Gamma40Hz;
    double targetFrequency = 40.0;
    bool audioReactive = true;
    float intensity = 0.8f;

    // Phase tracking (lock-free for real-time safety)
    std::atomic<float> flickerValue{0.0f};
    std::atomic<float> currentPhase{0.0f};
    DSP::PrecisionPhaseAccumulator phaseAccumulator;

    // Audio analysis
    float audioEnvelope = 0.0f;
    float audioEnvelopeCoeff = 0.01f;

    // Performance tracking
    SyncMetrics metrics;
    int64_t lastProcessTime = 0;

    // Internal methods
    void updateFlickerPattern();
    juce::Colour getModeBaseColor() const;
};

//==============================================================================
// Implementation
//==============================================================================

inline BrainwaveLaserSync::BrainwaveLaserSync() = default;
inline BrainwaveLaserSync::~BrainwaveLaserSync() = default;

inline void BrainwaveLaserSync::prepare(double sr, int blockSz)
{
    sampleRate = sr;
    blockSize = blockSz;

    // Configure phase accumulator for target frequency
    phaseAccumulator.setFrequency(targetFrequency, sampleRate);

    // Audio envelope follower coefficient (~10ms attack)
    audioEnvelopeCoeff = 1.0f - std::exp(-1.0f / (0.01f * static_cast<float>(sampleRate)));
}

inline void BrainwaveLaserSync::reset()
{
    phaseAccumulator.reset();
    flickerValue.store(0.0f, std::memory_order_relaxed);
    currentPhase.store(0.0f, std::memory_order_relaxed);
    audioEnvelope = 0.0f;
}

inline void BrainwaveLaserSync::setVisualMode(BrainwaveVisualMode mode)
{
    currentMode = mode;

    // Set default frequencies for each mode
    switch (mode)
    {
        case BrainwaveVisualMode::Gamma40Hz:
            targetFrequency = 40.0;
            break;
        case BrainwaveVisualMode::VNS_FlickerRange:
            targetFrequency = 25.0;
            break;
        case BrainwaveVisualMode::AlphaRelaxation:
            targetFrequency = 10.0;
            break;
        case BrainwaveVisualMode::ThetaMeditation:
            targetFrequency = 6.0;
            break;
        case BrainwaveVisualMode::DeltaSleep:
            targetFrequency = 2.0;
            break;
        case BrainwaveVisualMode::BetaFocus:
            targetFrequency = 18.0;
            break;
        case BrainwaveVisualMode::SchumannResonance:
            targetFrequency = 7.83;
            break;
        default:
            break;
    }

    phaseAccumulator.setFrequency(targetFrequency, sampleRate);
}

inline void BrainwaveLaserSync::setTargetFrequency(double hz)
{
    targetFrequency = juce::jlimit(0.5, 100.0, hz);
    phaseAccumulator.setFrequency(targetFrequency, sampleRate);
}

inline void BrainwaveLaserSync::processAudioBlock(const float* audioData, int numSamples)
{
    auto startTime = juce::Time::getHighResolutionTicks();

    // Update audio envelope (peak follower)
    for (int i = 0; i < numSamples; ++i)
    {
        float absVal = std::abs(audioData[i]);
        if (absVal > audioEnvelope)
            audioEnvelope = absVal;
        else
            audioEnvelope += (absVal - audioEnvelope) * audioEnvelopeCoeff;
    }

    // Advance phase accumulator
    for (int i = 0; i < numSamples; ++i)
    {
        double phase = phaseAccumulator.advance();
        if (i == numSamples - 1)
        {
            currentPhase.store(static_cast<float>(phase), std::memory_order_relaxed);
        }
    }

    // Update flicker value
    updateFlickerPattern();

    // Update metrics
    auto endTime = juce::Time::getHighResolutionTicks();
    metrics.processingTimeUs = juce::Time::highResolutionTicksToSeconds(
        endTime - startTime) * 1000000.0;
    metrics.framesProcessed++;
}

inline void BrainwaveLaserSync::updateFlickerPattern()
{
    float phase = currentPhase.load(std::memory_order_relaxed);

    // Generate flicker pattern based on mode
    float flicker = 0.0f;

    switch (currentMode)
    {
        case BrainwaveVisualMode::Gamma40Hz:
        case BrainwaveVisualMode::VNS_FlickerRange:
            // Sharp on/off flicker (50% duty cycle)
            flicker = (phase < 0.5f) ? 1.0f : 0.0f;
            break;

        case BrainwaveVisualMode::AlphaRelaxation:
        case BrainwaveVisualMode::ThetaMeditation:
            // Smooth sine wave pulsing
            flicker = 0.5f + 0.5f * std::sin(phase * 6.283185307179586f);
            break;

        case BrainwaveVisualMode::DeltaSleep:
            // Very slow, gentle pulsing
            flicker = 0.3f + 0.7f * std::sin(phase * 6.283185307179586f);
            break;

        case BrainwaveVisualMode::BetaFocus:
            // Moderate sharp pulses
            flicker = (phase < 0.3f) ? 1.0f : 0.2f;
            break;

        case BrainwaveVisualMode::SchumannResonance:
            // Earth frequency gentle pulse
            flicker = 0.4f + 0.6f * std::sin(phase * 6.283185307179586f);
            break;

        default:
            flicker = 1.0f;
            break;
    }

    // Apply audio reactivity if enabled
    if (audioReactive)
    {
        flicker *= (0.5f + 0.5f * audioEnvelope);
    }

    // Apply intensity
    flicker *= intensity;

    flickerValue.store(flicker, std::memory_order_relaxed);
}

inline juce::Colour BrainwaveLaserSync::getCurrentColor() const
{
    juce::Colour baseColor = getModeBaseColor();
    float flicker = flickerValue.load(std::memory_order_relaxed);

    // Modulate brightness
    return baseColor.withMultipliedBrightness(flicker);
}

inline juce::Colour BrainwaveLaserSync::getModeBaseColor() const
{
    switch (currentMode)
    {
        case BrainwaveVisualMode::Gamma40Hz:
            return juce::Colours::gold;  // Warm, energizing

        case BrainwaveVisualMode::VNS_FlickerRange:
            return juce::Colours::orange;

        case BrainwaveVisualMode::AlphaRelaxation:
            return juce::Colours::cyan;  // Cool, calming

        case BrainwaveVisualMode::ThetaMeditation:
            return juce::Colours::purple;  // Deep, meditative

        case BrainwaveVisualMode::DeltaSleep:
            return juce::Colours::darkblue;  // Deep sleep

        case BrainwaveVisualMode::BetaFocus:
            return juce::Colours::green;  // Alert, focused

        case BrainwaveVisualMode::SchumannResonance:
            return juce::Colour(0x22, 0x88, 0x44);  // Earth green

        case BrainwaveVisualMode::PlanetaryAlignment:
            return juce::Colours::violet;

        case BrainwaveVisualMode::SolfeggioVisualization:
            return juce::Colours::magenta;

        default:
            return juce::Colours::white;
    }
}

inline juce::Colour BrainwaveLaserSync::modulateColor(juce::Colour baseColor) const
{
    float flicker = flickerValue.load(std::memory_order_relaxed);
    juce::Colour modeColor = getModeBaseColor();

    // Blend base color with mode color based on intensity
    float blend = intensity * 0.5f;
    juce::Colour blended = baseColor.interpolatedWith(modeColor, blend);

    // Apply flicker modulation
    return blended.withMultipliedBrightness(0.2f + 0.8f * flicker);
}

inline float BrainwaveLaserSync::modulateBrightness(float baseBrightness) const
{
    float flicker = flickerValue.load(std::memory_order_relaxed);
    return baseBrightness * (0.1f + 0.9f * flicker);
}

inline bool BrainwaveLaserSync::shouldBlankForFlicker() const
{
    // Only blank for hard flicker modes
    if (currentMode == BrainwaveVisualMode::Gamma40Hz ||
        currentMode == BrainwaveVisualMode::VNS_FlickerRange)
    {
        float flicker = flickerValue.load(std::memory_order_relaxed);
        return flicker < 0.1f;
    }
    return false;
}

}  // namespace Echoel::Visual
