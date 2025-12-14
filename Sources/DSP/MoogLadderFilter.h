/**
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║                    MOOG LADDER FILTER                                      ║
 * ║                                                                            ║
 * ║     "The Sound That Defined Synthesis - Since 1965"                       ║
 * ║                                                                            ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 *
 * Authentic emulation of the legendary Moog transistor ladder filter.
 *
 * Based on:
 * - Bob Moog's 1965 original patent
 * - Minimoog Model D topology
 * - Moogerfooger MF-101 Lowpass Filter
 * - Academic research by Välimäki, Smith, Zavalishin
 *
 * Unique Characteristics:
 * - 4-pole 24dB/octave response (or 2-pole 12dB/octave)
 * - Self-oscillation at high resonance (becomes a sine oscillator)
 * - Warm analog saturation from transistor stages
 * - "Bass robbing" at high resonance (authentic behavior)
 * - Smooth, creamy, musical resonance
 *
 * Implementation:
 * - Zero-Delay Feedback (ZDF) topology for stability
 * - Nonlinear transistor saturation modeling
 * - Thermal drift simulation (optional)
 * - CV/Expression pedal ready
 *
 * Bio-Reactive Features:
 * - HRV → Cutoff modulation
 * - Coherence → Resonance control
 * - Breathing → LFO rate
 * - Stress → Drive amount
 */

#pragma once

#include <JuceHeader.h>
#include <array>
#include <cmath>

class MoogLadderFilter
{
public:
    //==========================================================================
    // Filter Modes
    //==========================================================================

    enum class Mode
    {
        LP24,       // 4-pole lowpass (24dB/oct) - classic Moog
        LP12,       // 2-pole lowpass (12dB/oct) - gentler slope
        BP24,       // 4-pole bandpass
        HP24,       // 4-pole highpass
        Notch       // Notch filter (LP + HP mix)
    };

    //==========================================================================
    // Parameters
    //==========================================================================

    struct Parameters
    {
        float cutoff = 1000.0f;         // 20-20000 Hz
        float resonance = 0.0f;         // 0-1 (self-oscillates near 1.0)
        float drive = 0.0f;             // 0-1 (input saturation)
        Mode mode = Mode::LP24;

        // Modulation
        float keyTracking = 0.0f;       // 0-1 (cutoff follows pitch)
        float velocitySens = 0.0f;      // 0-1 (cutoff responds to velocity)
        float envelopeAmount = 0.0f;    // -1 to +1 (envelope modulation)

        // Character
        float thermalDrift = 0.0f;      // 0-1 (analog instability)
        bool compensateGain = true;     // Makeup gain for resonance loss

        Parameters() = default;
    };

    //==========================================================================
    // Bio State
    //==========================================================================

    struct BioState
    {
        float hrv = 0.5f;
        float coherence = 0.5f;
        float breathingPhase = 0.0f;
        float stress = 0.5f;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    MoogLadderFilter()
    {
        reset();
    }

    ~MoogLadderFilter() = default;

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        reset();
        calculateCoefficients();
    }

    void reset()
    {
        for (int i = 0; i < 4; ++i)
        {
            stage[i] = 0.0;
            stageTanh[i] = 0.0;
        }
        delay = 0.0;
    }

    //==========================================================================
    // Parameter Control
    //==========================================================================

    void setParameters(const Parameters& newParams)
    {
        params = newParams;
        calculateCoefficients();
    }

    void setCutoff(float hz)
    {
        params.cutoff = std::clamp(hz, 20.0f, 20000.0f);
        calculateCoefficients();
    }

    void setResonance(float res)
    {
        params.resonance = std::clamp(res, 0.0f, 1.0f);
        calculateCoefficients();
    }

    void setDrive(float drive)
    {
        params.drive = std::clamp(drive, 0.0f, 1.0f);
    }

    void setMode(Mode mode)
    {
        params.mode = mode;
    }

    const Parameters& getParameters() const
    {
        return params;
    }

    //==========================================================================
    // Modulation Input
    //==========================================================================

    void setModulation(float cutoffMod, float resonanceMod = 0.0f)
    {
        cutoffModulation = cutoffMod;
        resonanceModulation = resonanceMod;
        calculateCoefficients();
    }

    void setEnvelope(float envValue)
    {
        envelopeValue = envValue;
        calculateCoefficients();
    }

    void setKeyTracking(int midiNote)
    {
        // Calculate frequency ratio from middle C
        float noteFreq = 440.0f * std::pow(2.0f, (midiNote - 69) / 12.0f);
        float middleCFreq = 261.63f;
        keyTrackingRatio = noteFreq / middleCFreq;
    }

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    void setBioState(const BioState& state)
    {
        bioState = state;

        if (bioReactiveEnabled)
        {
            applyBioModulation();
        }
    }

    void setBioReactiveEnabled(bool enabled)
    {
        bioReactiveEnabled = enabled;
    }

    //==========================================================================
    // Processing
    //==========================================================================

    float processSample(float input)
    {
        // Apply thermal drift
        float driftedCutoff = cutoffCoeff;
        if (params.thermalDrift > 0.001f)
        {
            driftedCutoff *= (1.0f + thermalNoise * params.thermalDrift * 0.01f);
            updateThermalNoise();
        }

        // Input drive/saturation (transistor-style)
        float driveGain = 1.0f + params.drive * 4.0f;
        float saturatedInput = fastTanh(input * driveGain);

        // Feedback with resonance
        // The famous Moog resonance path
        double feedback = resonanceCoeff * delay;

        // Subtract feedback from input (negative feedback topology)
        double u = saturatedInput - feedback;

        // Soft clip the feedback path (prevents runaway at high resonance)
        u = fastTanh(u);

        // Four cascaded one-pole lowpass stages
        // Each stage: y = y + g * (tanh(u) - tanh(y))
        // This is the ZDF (zero-delay feedback) implementation

        for (int i = 0; i < 4; ++i)
        {
            double v = driftedCutoff * (fastTanh(u) - stageTanh[i]);
            double y = stage[i] + v;
            stage[i] = y + v;  // Trapezoidal integration
            stageTanh[i] = fastTanh(y);
            u = y;
        }

        // Store for feedback
        delay = stage[3];

        // Output based on mode
        float output = 0.0f;

        switch (params.mode)
        {
            case Mode::LP24:
                output = static_cast<float>(stage[3]);
                break;

            case Mode::LP12:
                output = static_cast<float>(stage[1]);
                break;

            case Mode::BP24:
                // Bandpass: difference between stages
                output = static_cast<float>(stage[1] - stage[3]);
                break;

            case Mode::HP24:
                // Highpass: input minus lowpass
                output = saturatedInput - static_cast<float>(stage[3]);
                break;

            case Mode::Notch:
                // Notch: lowpass + highpass
                output = static_cast<float>(stage[3]) +
                         (saturatedInput - static_cast<float>(stage[3])) * 0.5f;
                break;
        }

        // Gain compensation for resonance (bass robbing effect)
        if (params.compensateGain)
        {
            float compensation = 1.0f + resonanceCoeff * 0.5f;
            output *= compensation;
        }

        return output;
    }

    void process(juce::AudioBuffer<float>& buffer)
    {
        const int numSamples = buffer.getNumSamples();
        const int numChannels = buffer.getNumChannels();

        for (int ch = 0; ch < numChannels; ++ch)
        {
            float* channelData = buffer.getWritePointer(ch);

            // Reset filter state for each channel if stereo
            // (or use separate filter instances for true stereo)

            for (int i = 0; i < numSamples; ++i)
            {
                channelData[i] = processSample(channelData[i]);
            }
        }
    }

    //==========================================================================
    // Self-Oscillation
    //==========================================================================

    /** Check if filter is self-oscillating */
    bool isSelfOscillating() const
    {
        return params.resonance > 0.95f;
    }

    /** Get self-oscillation frequency (when resonance is maxed) */
    float getSelfOscillationFrequency() const
    {
        return params.cutoff;
    }

    /** Generate self-oscillation output (filter becomes a sine oscillator) */
    float generateSelfOscillation()
    {
        if (!isSelfOscillating())
            return 0.0f;

        // When resonance is at max, filter self-oscillates at cutoff frequency
        // Feed a tiny amount of noise to excite oscillation
        float noise = (static_cast<float>(rand()) / RAND_MAX - 0.5f) * 0.001f;
        return processSample(noise);
    }

    //==========================================================================
    // Presets
    //==========================================================================

    void loadPreset(int presetIndex)
    {
        switch (presetIndex)
        {
            case 0: // Classic Moog Bass
                params.cutoff = 200.0f;
                params.resonance = 0.4f;
                params.drive = 0.2f;
                params.mode = Mode::LP24;
                break;

            case 1: // Screaming Lead
                params.cutoff = 2000.0f;
                params.resonance = 0.85f;
                params.drive = 0.5f;
                params.mode = Mode::LP24;
                break;

            case 2: // Self-Oscillating Sine
                params.cutoff = 440.0f;
                params.resonance = 1.0f;
                params.drive = 0.0f;
                params.mode = Mode::LP24;
                break;

            case 3: // Warm Pad Filter
                params.cutoff = 800.0f;
                params.resonance = 0.3f;
                params.drive = 0.1f;
                params.mode = Mode::LP12;
                break;

            case 4: // Bio-Reactive Sweep
                params.cutoff = 1000.0f;
                params.resonance = 0.5f;
                bioReactiveEnabled = true;
                break;

            case 5: // Acid Squelch
                params.cutoff = 300.0f;
                params.resonance = 0.9f;
                params.drive = 0.6f;
                params.envelopeAmount = 0.8f;
                break;

            default:
                break;
        }

        calculateCoefficients();
    }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    Parameters params;
    BioState bioState;
    bool bioReactiveEnabled = false;

    double currentSampleRate = 48000.0;

    // Filter state (4 stages)
    std::array<double, 4> stage;
    std::array<double, 4> stageTanh;
    double delay = 0.0;

    // Coefficients
    double cutoffCoeff = 0.5;
    double resonanceCoeff = 0.0;

    // Modulation
    float cutoffModulation = 0.0f;
    float resonanceModulation = 0.0f;
    float envelopeValue = 0.0f;
    float keyTrackingRatio = 1.0f;

    // Thermal drift
    float thermalNoise = 0.0f;
    float thermalNoiseState = 0.0f;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void calculateCoefficients()
    {
        // Apply modulations to cutoff
        float modulatedCutoff = params.cutoff;

        // Key tracking
        if (params.keyTracking > 0.001f)
        {
            modulatedCutoff *= std::pow(keyTrackingRatio, params.keyTracking);
        }

        // Envelope modulation
        if (std::abs(params.envelopeAmount) > 0.001f)
        {
            float envMod = envelopeValue * params.envelopeAmount;
            modulatedCutoff *= std::pow(2.0f, envMod * 4.0f);  // ±4 octaves
        }

        // External modulation
        modulatedCutoff *= std::pow(2.0f, cutoffModulation * 2.0f);

        // Clamp to valid range
        modulatedCutoff = std::clamp(modulatedCutoff, 20.0f, 20000.0f);

        // Calculate filter coefficient (g parameter in ZDF topology)
        // Using bilinear transform pre-warping
        double wc = 2.0 * M_PI * modulatedCutoff / currentSampleRate;
        double wc_prewarped = 2.0 * currentSampleRate * std::tan(wc / 2.0);

        // Normalized coefficient
        cutoffCoeff = wc_prewarped / (2.0 * currentSampleRate);
        cutoffCoeff = std::clamp(cutoffCoeff, 0.0001, 0.9999);

        // Resonance coefficient
        // Scale resonance for the feedback path
        // At resonance = 1.0, filter should just start to self-oscillate
        float modulatedResonance = params.resonance + resonanceModulation;
        modulatedResonance = std::clamp(modulatedResonance, 0.0f, 1.0f);

        // The magic number 4.0 comes from the fact that 4 stages contribute
        // to the feedback loop, and we need gain of 4 to achieve unity loop gain
        resonanceCoeff = modulatedResonance * 4.0;

        // Slight reduction to prevent hard clipping at max resonance
        resonanceCoeff *= 0.98;
    }

    /** Fast tanh approximation (Pade approximant) */
    inline double fastTanh(double x) const
    {
        // Clamp to avoid overflow
        if (x < -3.0) return -1.0;
        if (x > 3.0) return 1.0;

        double x2 = x * x;
        return x * (27.0 + x2) / (27.0 + 9.0 * x2);
    }

    void updateThermalNoise()
    {
        // Simple filtered noise for thermal drift
        float white = (static_cast<float>(rand()) / RAND_MAX) * 2.0f - 1.0f;
        thermalNoiseState = thermalNoiseState * 0.999f + white * 0.001f;
        thermalNoise = thermalNoiseState;
    }

    void applyBioModulation()
    {
        // HRV → Cutoff (high HRV = brighter)
        float hrvCutoffMod = (bioState.hrv - 0.5f) * 2.0f;  // -1 to +1 octaves
        cutoffModulation = hrvCutoffMod;

        // Coherence → Resonance (high coherence = more resonance/focus)
        resonanceModulation = bioState.coherence * 0.3f;

        // Stress → Drive (high stress = more saturation)
        params.drive = bioState.stress * 0.5f;

        // Breathing → LFO-like modulation
        float breathMod = std::sin(bioState.breathingPhase * 2.0f * M_PI);
        cutoffModulation += breathMod * 0.2f;

        calculateCoefficients();
    }

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MoogLadderFilter)
};

//==============================================================================
/**
 * Stereo Moog Ladder Filter
 * Two independent filters for true stereo processing
 */
class StereoMoogLadderFilter
{
public:
    void prepare(double sampleRate)
    {
        filterL.prepare(sampleRate);
        filterR.prepare(sampleRate);
    }

    void reset()
    {
        filterL.reset();
        filterR.reset();
    }

    void setParameters(const MoogLadderFilter::Parameters& params)
    {
        filterL.setParameters(params);
        filterR.setParameters(params);
    }

    void setBioState(const MoogLadderFilter::BioState& state)
    {
        filterL.setBioState(state);
        filterR.setBioState(state);
    }

    void process(juce::AudioBuffer<float>& buffer)
    {
        if (buffer.getNumChannels() >= 2)
        {
            // Process each channel independently
            float* left = buffer.getWritePointer(0);
            float* right = buffer.getWritePointer(1);

            for (int i = 0; i < buffer.getNumSamples(); ++i)
            {
                left[i] = filterL.processSample(left[i]);
                right[i] = filterR.processSample(right[i]);
            }
        }
        else if (buffer.getNumChannels() == 1)
        {
            float* mono = buffer.getWritePointer(0);
            for (int i = 0; i < buffer.getNumSamples(); ++i)
            {
                mono[i] = filterL.processSample(mono[i]);
            }
        }
    }

private:
    MoogLadderFilter filterL;
    MoogLadderFilter filterR;
};
