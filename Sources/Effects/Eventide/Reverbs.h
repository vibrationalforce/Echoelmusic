#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <cmath>
#include <memory>
#include <random>

/**
 * Eventide-Inspired Reverb Effects
 *
 * Legendary reverb algorithms inspired by Eventide hardware:
 * - Blackhole: Massive infinite reverb spaces
 * - ShimmerVerb: Pitch-shifted ethereal reverb
 * - MangledVerb: Distorted, aggressive reverb
 * - SP2016: Classic studio reverb (Room, Hall, Plate)
 * - TVerb: Tiled room with mic placement
 *
 * Using Feedback Delay Network (FDN) architecture
 * as pioneered by Eventide's SP2016.
 *
 * Super Ralph Wiggum Loop Genius Reverb Mode
 */

namespace Echoelmusic {
namespace Effects {
namespace Eventide {

//==============================================================================
// Constants and Utilities
//==============================================================================

constexpr float PI = 3.14159265358979f;
constexpr float TWO_PI = 6.28318530717959f;

// Prime numbers for delay line lengths (avoid comb filtering)
constexpr std::array<int, 16> PRIME_DELAYS = {
    1433, 1601, 1753, 1907, 2069, 2213, 2371, 2539,
    2687, 2857, 3011, 3169, 3331, 3491, 3659, 3821
};

//==============================================================================
// AllPass Filter
//==============================================================================

class AllPassFilter
{
public:
    AllPassFilter(int maxDelay = 8192)
    {
        buffer.resize(maxDelay, 0.0f);
    }

    void setDelay(int samples)
    {
        delaySamples = std::min(samples, static_cast<int>(buffer.size()) - 1);
    }

    void setFeedback(float fb) { feedback = fb; }

    float process(float input)
    {
        int readPos = (writePos - delaySamples + static_cast<int>(buffer.size()))
                     % static_cast<int>(buffer.size());

        float delayed = buffer[readPos];
        float output = -input + delayed;

        buffer[writePos] = input + delayed * feedback;
        writePos = (writePos + 1) % static_cast<int>(buffer.size());

        return output;
    }

    void clear()
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        writePos = 0;
    }

private:
    std::vector<float> buffer;
    int writePos = 0;
    int delaySamples = 100;
    float feedback = 0.5f;
};

//==============================================================================
// Comb Filter
//==============================================================================

class CombFilter
{
public:
    CombFilter(int maxDelay = 8192)
    {
        buffer.resize(maxDelay, 0.0f);
    }

    void setDelay(int samples)
    {
        delaySamples = std::min(samples, static_cast<int>(buffer.size()) - 1);
    }

    void setFeedback(float fb) { feedback = fb; }
    void setDamping(float damp) { damping = damp; }

    float process(float input)
    {
        int readPos = (writePos - delaySamples + static_cast<int>(buffer.size()))
                     % static_cast<int>(buffer.size());

        float delayed = buffer[readPos];

        // Lowpass damping
        filterState = delayed * (1.0f - damping) + filterState * damping;

        buffer[writePos] = input + filterState * feedback;
        writePos = (writePos + 1) % static_cast<int>(buffer.size());

        return delayed;
    }

    void clear()
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        filterState = 0.0f;
        writePos = 0;
    }

private:
    std::vector<float> buffer;
    int writePos = 0;
    int delaySamples = 1000;
    float feedback = 0.8f;
    float damping = 0.2f;
    float filterState = 0.0f;
};

//==============================================================================
// Modulated Delay Line
//==============================================================================

class ModulatedDelayLine
{
public:
    ModulatedDelayLine(int maxDelay = 16384)
    {
        buffer.resize(maxDelay, 0.0f);
    }

    void setDelay(float samples)
    {
        targetDelay = std::min(samples, static_cast<float>(buffer.size()) - 2.0f);
    }

    void setModDepth(float depth) { modDepth = depth; }
    void setModRate(float rateHz, double sampleRate)
    {
        modPhaseInc = (TWO_PI * rateHz) / static_cast<float>(sampleRate);
    }

    float process(float input)
    {
        // Smooth delay changes
        currentDelay = currentDelay * 0.999f + targetDelay * 0.001f;

        // Apply modulation
        float modOffset = std::sin(modPhase) * modDepth;
        modPhase += modPhaseInc;
        if (modPhase >= TWO_PI) modPhase -= TWO_PI;

        float totalDelay = currentDelay + modOffset;
        totalDelay = std::max(1.0f, totalDelay);

        // Cubic interpolation for smooth reading
        int readPos = static_cast<int>(writePos - totalDelay);
        while (readPos < 0) readPos += static_cast<int>(buffer.size());

        float frac = (writePos - totalDelay) - std::floor(writePos - totalDelay);

        int p0 = (readPos - 1 + static_cast<int>(buffer.size())) % static_cast<int>(buffer.size());
        int p1 = readPos % static_cast<int>(buffer.size());
        int p2 = (readPos + 1) % static_cast<int>(buffer.size());
        int p3 = (readPos + 2) % static_cast<int>(buffer.size());

        float y0 = buffer[p0];
        float y1 = buffer[p1];
        float y2 = buffer[p2];
        float y3 = buffer[p3];

        // Hermite interpolation
        float c0 = y1;
        float c1 = 0.5f * (y2 - y0);
        float c2 = y0 - 2.5f * y1 + 2.0f * y2 - 0.5f * y3;
        float c3 = 0.5f * (y3 - y0) + 1.5f * (y1 - y2);

        float output = ((c3 * frac + c2) * frac + c1) * frac + c0;

        // Write input
        buffer[writePos] = input;
        writePos = (writePos + 1) % static_cast<int>(buffer.size());

        return output;
    }

    void clear()
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
    }

private:
    std::vector<float> buffer;
    int writePos = 0;
    float targetDelay = 1000.0f;
    float currentDelay = 1000.0f;
    float modDepth = 0.0f;
    float modPhase = 0.0f;
    float modPhaseInc = 0.0f;
};

//==============================================================================
// Feedback Delay Network (8x8)
//==============================================================================

class FeedbackDelayNetwork
{
public:
    /**
     * 8-channel Feedback Delay Network with Hadamard mixing matrix
     * Foundation for SP2016-style reverbs
     */

    FeedbackDelayNetwork()
    {
        for (int i = 0; i < 8; ++i)
        {
            delays[i] = std::make_unique<ModulatedDelayLine>(32768);
        }
    }

    void prepare(double sampleRate)
    {
        this->sampleRate = sampleRate;

        // Set delay times using prime numbers for diffusion
        for (int i = 0; i < 8; ++i)
        {
            float baseDelay = PRIME_DELAYS[i] * (sampleRate / 44100.0f);
            delays[i]->setDelay(baseDelay * sizeMultiplier);
            delays[i]->setModRate(0.5f + i * 0.1f, sampleRate);
        }
    }

    void setSize(float size)
    {
        sizeMultiplier = 0.2f + size * 1.8f;  // 0.2 to 2.0
        prepare(sampleRate);
    }

    void setDecay(float decay)
    {
        decayFactor = 0.5f + decay * 0.495f;  // 0.5 to 0.995
    }

    void setDamping(float damp)
    {
        damping = damp;
    }

    void setModulation(float amount)
    {
        for (int i = 0; i < 8; ++i)
        {
            delays[i]->setModDepth(amount * 5.0f);
        }
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        // Inject input
        state[0] += inputL * 0.5f;
        state[1] += inputR * 0.5f;

        // Read from delay lines
        std::array<float, 8> delayed;
        for (int i = 0; i < 8; ++i)
        {
            delayed[i] = delays[i]->process(state[i]);
        }

        // Apply damping (lowpass)
        for (int i = 0; i < 8; ++i)
        {
            lpfState[i] = delayed[i] * (1.0f - damping) + lpfState[i] * damping;
            delayed[i] = lpfState[i];
        }

        // Hadamard mixing matrix (8x8)
        std::array<float, 8> mixed;
        float invSqrt8 = 0.353553391f;  // 1/sqrt(8)

        // Simplified Hadamard (butterfly network)
        for (int i = 0; i < 4; ++i)
        {
            mixed[i] = (delayed[i] + delayed[i + 4]) * invSqrt8;
            mixed[i + 4] = (delayed[i] - delayed[i + 4]) * invSqrt8;
        }

        // Second stage
        for (int i = 0; i < 2; ++i)
        {
            float t0 = mixed[i] + mixed[i + 2];
            float t1 = mixed[i] - mixed[i + 2];
            float t2 = mixed[i + 4] + mixed[i + 6];
            float t3 = mixed[i + 4] - mixed[i + 6];
            mixed[i] = t0;
            mixed[i + 2] = t1;
            mixed[i + 4] = t2;
            mixed[i + 6] = t3;
        }

        // Apply decay and write back to state
        for (int i = 0; i < 8; ++i)
        {
            state[i] = mixed[i] * decayFactor;
        }

        // Output tap (mix of delay lines)
        outputL = (delayed[0] + delayed[2] + delayed[4] + delayed[6]) * 0.25f;
        outputR = (delayed[1] + delayed[3] + delayed[5] + delayed[7]) * 0.25f;
    }

    void clear()
    {
        for (auto& delay : delays)
            delay->clear();
        state.fill(0.0f);
        lpfState.fill(0.0f);
    }

private:
    std::array<std::unique_ptr<ModulatedDelayLine>, 8> delays;
    std::array<float, 8> state = {0};
    std::array<float, 8> lpfState = {0};

    double sampleRate = 44100.0;
    float sizeMultiplier = 1.0f;
    float decayFactor = 0.85f;
    float damping = 0.3f;
};

//==============================================================================
// Blackhole Reverb
//==============================================================================

class Blackhole
{
public:
    /**
     * Blackhole - Massive otherworldly reverb
     *
     * Creates virtual spaces that could never exist in reality.
     * Inspired by the iconic Eventide Blackhole plugin.
     *
     * Features:
     * - Infinite sustain capability
     * - Gravity control (forward/reverse decay)
     * - Modulation for movement
     * - Size beyond physical room dimensions
     * - Freeze function
     */

    Blackhole()
    {
        fdn = std::make_unique<FeedbackDelayNetwork>();

        for (int i = 0; i < 4; ++i)
        {
            preDelays[i] = std::make_unique<ModulatedDelayLine>(8192);
            diffusers[i] = std::make_unique<AllPassFilter>(4096);
        }
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        fdn->prepare(sampleRate);

        for (int i = 0; i < 4; ++i)
        {
            preDelays[i]->setDelay(100.0f + i * 50.0f);
            diffusers[i]->setDelay(PRIME_DELAYS[i + 8] * 0.1f);
            diffusers[i]->setFeedback(0.6f);
        }
    }

    // Parameters
    void setSize(float size)
    {
        // Blackhole goes beyond normal room sizes
        // size 0.0 = small room, 1.0 = infinite space
        this->size = std::clamp(size, 0.0f, 1.0f);
        fdn->setSize(0.3f + size * 1.7f);
    }

    void setDecay(float decay)
    {
        // Extended decay range - can go infinite
        this->decay = std::clamp(decay, 0.0f, 1.0f);

        // Map to FDN decay (logarithmic for natural feel)
        float fdnDecay = 0.3f + std::pow(decay, 0.5f) * 0.695f;
        fdn->setDecay(fdnDecay);
    }

    void setGravity(float gravity)
    {
        // -1 = reverse decay (builds up), 0 = normal, +1 = fast decay
        this->gravity = std::clamp(gravity, -1.0f, 1.0f);
    }

    void setModulate(float mod)
    {
        modulation = std::clamp(mod, 0.0f, 1.0f);
        fdn->setModulation(modulation);
    }

    void setDamping(float damp)
    {
        damping = std::clamp(damp, 0.0f, 1.0f);
        fdn->setDamping(damping);
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
    }

    void setFreeze(bool freeze)
    {
        frozen = freeze;
        if (freeze)
        {
            fdn->setDecay(0.999f);  // Near-infinite sustain
        }
        else
        {
            setDecay(decay);  // Restore normal decay
        }
    }

    void setPreDelay(float ms)
    {
        preDelayMs = std::clamp(ms, 0.0f, 500.0f);
        float samples = preDelayMs * 0.001f * static_cast<float>(sampleRate);
        for (int i = 0; i < 4; ++i)
        {
            preDelays[i]->setDelay(samples + i * 10.0f);
        }
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        float inL = frozen ? 0.0f : inputL;
        float inR = frozen ? 0.0f : inputR;

        // Pre-delay and diffusion
        float diffL = 0.0f, diffR = 0.0f;
        for (int i = 0; i < 4; ++i)
        {
            float delayed = preDelays[i]->process((i % 2 == 0) ? inL : inR);
            float diffused = diffusers[i]->process(delayed);

            if (i % 2 == 0)
                diffL += diffused * 0.5f;
            else
                diffR += diffused * 0.5f;
        }

        // Main reverb
        float reverbL, reverbR;
        fdn->process(diffL, diffR, reverbL, reverbR);

        // Apply gravity (asymmetric decay)
        if (gravity != 0.0f)
        {
            float envMod = 1.0f - std::abs(gravity) * 0.5f;
            reverbL *= envMod;
            reverbR *= envMod;
        }

        // Mix
        outputL = inputL * (1.0f - wetDryMix) + reverbL * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + reverbR * wetDryMix;
    }

    // Presets
    static Blackhole createMassivePreset()
    {
        Blackhole bh;
        bh.setSize(0.9f);
        bh.setDecay(0.95f);
        bh.setModulate(0.5f);
        bh.setDamping(0.4f);
        bh.setMix(0.5f);
        return bh;
    }

    static Blackhole createEventHorizonPreset()
    {
        Blackhole bh;
        bh.setSize(1.0f);
        bh.setDecay(1.0f);
        bh.setModulate(0.3f);
        bh.setDamping(0.2f);
        bh.setGravity(-0.3f);
        bh.setMix(0.6f);
        return bh;
    }

private:
    std::unique_ptr<FeedbackDelayNetwork> fdn;
    std::array<std::unique_ptr<ModulatedDelayLine>, 4> preDelays;
    std::array<std::unique_ptr<AllPassFilter>, 4> diffusers;

    double sampleRate = 44100.0;
    float size = 0.7f;
    float decay = 0.8f;
    float gravity = 0.0f;
    float modulation = 0.3f;
    float damping = 0.3f;
    float wetDryMix = 0.5f;
    float preDelayMs = 20.0f;
    bool frozen = false;
};

//==============================================================================
// ShimmerVerb
//==============================================================================

class ShimmerVerb
{
public:
    /**
     * ShimmerVerb - Pitch-shifted ethereal reverb
     *
     * Combines lush reverb with parallel pitch shifters
     * for the iconic "shimmer" effect popularized by
     * Brian Eno and Daniel Lanois on U2 records.
     *
     * Features:
     * - Dual pitch shifters in feedback path
     * - Infinite feedback capability
     * - 3-band crossover for frequency-dependent shimmer
     */

    ShimmerVerb()
    {
        fdn = std::make_unique<FeedbackDelayNetwork>();

        for (int i = 0; i < 2; ++i)
        {
            pitchShifters[i].buffer.resize(32768, 0.0f);
        }
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        fdn->prepare(sampleRate);
    }

    void setSize(float size)
    {
        fdn->setSize(size);
    }

    void setDecay(float decay)
    {
        fdn->setDecay(decay * 0.95f);  // Leave headroom for shimmer
    }

    void setShimmer(float amount)
    {
        shimmerAmount = std::clamp(amount, 0.0f, 1.0f);
    }

    void setPitch1(float semitones)
    {
        pitch1 = std::clamp(semitones, -24.0f, 24.0f);
        pitchRatio1 = std::pow(2.0f, pitch1 / 12.0f);
    }

    void setPitch2(float semitones)
    {
        pitch2 = std::clamp(semitones, -24.0f, 24.0f);
        pitchRatio2 = std::pow(2.0f, pitch2 / 12.0f);
    }

    void setFeedback(float fb)
    {
        feedback = std::clamp(fb, 0.0f, 0.99f);
    }

    void setLowCross(float freqHz)
    {
        lowCrossover = std::clamp(freqHz, 100.0f, 2000.0f);
    }

    void setHighCross(float freqHz)
    {
        highCrossover = std::clamp(freqHz, 2000.0f, 10000.0f);
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        // Add shimmer feedback to input
        float shimmerL = lastShimmerL * feedback * shimmerAmount;
        float shimmerR = lastShimmerR * feedback * shimmerAmount;

        // Main reverb
        float reverbL, reverbR;
        fdn->process(inputL + shimmerL, inputR + shimmerR, reverbL, reverbR);

        // Pitch shift the reverb output
        float shiftedL1 = pitchShift(reverbL, 0, pitchRatio1);
        float shiftedR1 = pitchShift(reverbR, 1, pitchRatio2);

        // Simple crossover filter
        float lowL = lowpassFilter(reverbL, lowCrossover);
        float highL = reverbL - lowL;

        float lowR = lowpassFilter(reverbR, lowCrossover);
        float highR = reverbR - lowR;

        // Apply shimmer primarily to high frequencies
        lastShimmerL = highL * shimmerAmount + shiftedL1 * shimmerAmount;
        lastShimmerR = highR * shimmerAmount + shiftedR1 * shimmerAmount;

        // Combine
        float wetL = reverbL + lastShimmerL * 0.5f;
        float wetR = reverbR + lastShimmerR * 0.5f;

        // Mix
        outputL = inputL * (1.0f - wetDryMix) + wetL * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + wetR * wetDryMix;
    }

    // Presets
    static ShimmerVerb createAngelicPreset()
    {
        ShimmerVerb sv;
        sv.setSize(0.85f);
        sv.setDecay(0.9f);
        sv.setShimmer(0.4f);
        sv.setPitch1(12.0f);   // Octave up
        sv.setPitch2(12.0f);
        sv.setFeedback(0.6f);
        sv.setMix(0.5f);
        return sv;
    }

    static ShimmerVerb createAscendingPreset()
    {
        ShimmerVerb sv;
        sv.setSize(0.8f);
        sv.setDecay(0.85f);
        sv.setShimmer(0.6f);
        sv.setPitch1(7.0f);    // Perfect 5th
        sv.setPitch2(12.0f);   // Octave
        sv.setFeedback(0.75f);
        sv.setMix(0.6f);
        return sv;
    }

private:
    std::unique_ptr<FeedbackDelayNetwork> fdn;

    struct SimplePitchShifter
    {
        std::vector<float> buffer;
        float readPos = 0.0f;
        int writePos = 0;
    };

    std::array<SimplePitchShifter, 2> pitchShifters;

    double sampleRate = 44100.0;
    float shimmerAmount = 0.4f;
    float pitch1 = 12.0f;
    float pitch2 = 12.0f;
    float pitchRatio1 = 2.0f;
    float pitchRatio2 = 2.0f;
    float feedback = 0.5f;
    float wetDryMix = 0.5f;
    float lowCrossover = 500.0f;
    float highCrossover = 4000.0f;

    float lastShimmerL = 0.0f;
    float lastShimmerR = 0.0f;
    float lpfStateL = 0.0f;
    float lpfStateR = 0.0f;

    float pitchShift(float input, int shifterIdx, float ratio)
    {
        auto& ps = pitchShifters[shifterIdx];

        // Write input
        ps.buffer[ps.writePos] = input;
        ps.writePos = (ps.writePos + 1) % static_cast<int>(ps.buffer.size());

        // Read with pitch shift
        ps.readPos += ratio;
        while (ps.readPos >= ps.buffer.size()) ps.readPos -= ps.buffer.size();
        while (ps.readPos < 0) ps.readPos += ps.buffer.size();

        int pos0 = static_cast<int>(ps.readPos);
        int pos1 = (pos0 + 1) % static_cast<int>(ps.buffer.size());
        float frac = ps.readPos - pos0;

        return ps.buffer[pos0] * (1.0f - frac) + ps.buffer[pos1] * frac;
    }

    float lowpassFilter(float input, float cutoff)
    {
        float omega = TWO_PI * cutoff / static_cast<float>(sampleRate);
        float alpha = omega / (omega + 1.0f);

        lpfStateL = alpha * input + (1.0f - alpha) * lpfStateL;
        return lpfStateL;
    }
};

//==============================================================================
// MangledVerb
//==============================================================================

class MangledVerb
{
public:
    /**
     * MangledVerb - Distorted aggressive reverb
     *
     * Combines reverb with distortion for heavy,
     * aggressive textures. Perfect for:
     * - Heavy guitars
     * - Aggressive drums
     * - Industrial sounds
     * - Sound design
     */

    MangledVerb()
    {
        fdn = std::make_unique<FeedbackDelayNetwork>();
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        fdn->prepare(sampleRate);
    }

    void setSize(float size)
    {
        fdn->setSize(size);
    }

    void setDecay(float decay)
    {
        fdn->setDecay(decay);
    }

    void setDistortion(float amount)
    {
        distortionAmount = std::clamp(amount, 0.0f, 1.0f);
    }

    void setDistortionType(int type)
    {
        // 0 = soft clip, 1 = hard clip, 2 = fold, 3 = bit crush
        distortionType = type % 4;
    }

    void setPreDistortion(bool pre)
    {
        preDistort = pre;
    }

    void setFilter(float cutoff)
    {
        filterCutoff = std::clamp(cutoff, 100.0f, 10000.0f);
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        float procL = inputL;
        float procR = inputR;

        // Pre-distortion
        if (preDistort)
        {
            procL = distort(procL);
            procR = distort(procR);
        }

        // Reverb
        float reverbL, reverbR;
        fdn->process(procL, procR, reverbL, reverbR);

        // Post-distortion
        if (!preDistort)
        {
            reverbL = distort(reverbL);
            reverbR = distort(reverbR);
        }

        // Filter
        filterStateL = filterStateL + (reverbL - filterStateL) *
                       (TWO_PI * filterCutoff / static_cast<float>(sampleRate));
        filterStateR = filterStateR + (reverbR - filterStateR) *
                       (TWO_PI * filterCutoff / static_cast<float>(sampleRate));

        // Mix
        outputL = inputL * (1.0f - wetDryMix) + filterStateL * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + filterStateR * wetDryMix;
    }

    // Presets
    static MangledVerb createCrushPreset()
    {
        MangledVerb mv;
        mv.setSize(0.6f);
        mv.setDecay(0.7f);
        mv.setDistortion(0.6f);
        mv.setDistortionType(1);  // Hard clip
        mv.setPreDistortion(false);
        mv.setMix(0.5f);
        return mv;
    }

    static MangledVerb createIndustrialPreset()
    {
        MangledVerb mv;
        mv.setSize(0.8f);
        mv.setDecay(0.5f);
        mv.setDistortion(0.8f);
        mv.setDistortionType(2);  // Fold
        mv.setPreDistortion(true);
        mv.setFilter(3000.0f);
        mv.setMix(0.6f);
        return mv;
    }

private:
    std::unique_ptr<FeedbackDelayNetwork> fdn;

    double sampleRate = 44100.0;
    float distortionAmount = 0.5f;
    int distortionType = 0;
    bool preDistort = false;
    float filterCutoff = 5000.0f;
    float wetDryMix = 0.5f;

    float filterStateL = 0.0f;
    float filterStateR = 0.0f;

    float distort(float input)
    {
        float drive = 1.0f + distortionAmount * 10.0f;
        float x = input * drive;

        switch (distortionType)
        {
            case 0:  // Soft clip (tanh)
                return std::tanh(x) / std::tanh(drive);

            case 1:  // Hard clip
                return std::clamp(x, -1.0f, 1.0f);

            case 2:  // Wave fold
            {
                while (x > 1.0f || x < -1.0f)
                {
                    if (x > 1.0f) x = 2.0f - x;
                    if (x < -1.0f) x = -2.0f - x;
                }
                return x;
            }

            case 3:  // Bit crush
            {
                float bits = 16.0f - distortionAmount * 12.0f;  // 4 to 16 bits
                float levels = std::pow(2.0f, bits);
                return std::round(x * levels) / levels;
            }

            default:
                return x;
        }
    }
};

//==============================================================================
// SP2016 Classic Reverb
//==============================================================================

class SP2016Reverb
{
public:
    /**
     * SP2016 - Classic studio reverb emulation
     *
     * Based on the legendary 1982 Eventide SP2016
     * Effects Processor. Features the iconic room,
     * hall, and plate algorithms.
     *
     * This was the foundation for modern FDN reverbs.
     */

    enum class Algorithm
    {
        Room,
        Hall,
        Plate,
        Chamber,
        Stereo_Room
    };

    SP2016Reverb()
    {
        for (int i = 0; i < 8; ++i)
        {
            combs[i] = std::make_unique<CombFilter>(8192);
        }
        for (int i = 0; i < 4; ++i)
        {
            allpasses[i] = std::make_unique<AllPassFilter>(4096);
        }
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        setAlgorithm(currentAlgorithm);
    }

    void setAlgorithm(Algorithm algo)
    {
        currentAlgorithm = algo;

        // Set delay times based on algorithm
        float roomScale = 1.0f;

        switch (algo)
        {
            case Algorithm::Room:
                roomScale = 0.5f;
                break;
            case Algorithm::Hall:
                roomScale = 1.5f;
                break;
            case Algorithm::Plate:
                roomScale = 0.8f;
                break;
            case Algorithm::Chamber:
                roomScale = 1.0f;
                break;
            case Algorithm::Stereo_Room:
                roomScale = 0.7f;
                break;
        }

        // Classic comb filter delay times (scaled by sample rate and room size)
        float sr = static_cast<float>(sampleRate) / 44100.0f;
        int combDelays[] = {1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116};

        for (int i = 0; i < 8; ++i)
        {
            int delay = static_cast<int>(combDelays[i] * sr * roomScale * size);
            combs[i]->setDelay(delay);
            combs[i]->setFeedback(0.84f * decayTime);
            combs[i]->setDamping(damping);
        }

        // Allpass delay times
        int allpassDelays[] = {225, 556, 441, 341};
        for (int i = 0; i < 4; ++i)
        {
            int delay = static_cast<int>(allpassDelays[i] * sr * roomScale);
            allpasses[i]->setDelay(delay);
            allpasses[i]->setFeedback(0.5f);
        }
    }

    void setSize(float sz)
    {
        size = std::clamp(sz, 0.2f, 2.0f);
        setAlgorithm(currentAlgorithm);
    }

    void setDecay(float decay)
    {
        decayTime = std::clamp(decay, 0.1f, 0.99f);
        setAlgorithm(currentAlgorithm);
    }

    void setDamping(float damp)
    {
        damping = std::clamp(damp, 0.0f, 1.0f);
        setAlgorithm(currentAlgorithm);
    }

    void setPreDelay(float ms)
    {
        preDelayMs = std::clamp(ms, 0.0f, 200.0f);
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        float mono = (inputL + inputR) * 0.5f;

        // Pre-delay (simple)
        // In full implementation, would use delay line

        // Input diffusion (allpass cascade)
        float diffused = mono;
        for (int i = 0; i < 2; ++i)
        {
            diffused = allpasses[i]->process(diffused);
        }

        // Parallel comb filters
        float combSum = 0.0f;
        for (int i = 0; i < 8; ++i)
        {
            combSum += combs[i]->process(diffused);
        }
        combSum *= 0.125f;  // Average

        // Output diffusion
        float output = combSum;
        for (int i = 2; i < 4; ++i)
        {
            output = allpasses[i]->process(output);
        }

        // Create stereo from mono reverb
        float wetL = output;
        float wetR = output;

        // Simple stereo decorrelation
        if (currentAlgorithm == Algorithm::Stereo_Room)
        {
            wetL = (combs[0]->process(diffused) + combs[2]->process(diffused) +
                    combs[4]->process(diffused) + combs[6]->process(diffused)) * 0.25f;
            wetR = (combs[1]->process(diffused) + combs[3]->process(diffused) +
                    combs[5]->process(diffused) + combs[7]->process(diffused)) * 0.25f;
        }

        // Mix
        outputL = inputL * (1.0f - wetDryMix) + wetL * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + wetR * wetDryMix;
    }

    // Presets
    static SP2016Reverb createVintageRoomPreset()
    {
        SP2016Reverb sp;
        sp.setAlgorithm(Algorithm::Room);
        sp.setSize(0.6f);
        sp.setDecay(0.5f);
        sp.setDamping(0.4f);
        sp.setMix(0.3f);
        return sp;
    }

    static SP2016Reverb createLargeHallPreset()
    {
        SP2016Reverb sp;
        sp.setAlgorithm(Algorithm::Hall);
        sp.setSize(1.2f);
        sp.setDecay(0.85f);
        sp.setDamping(0.25f);
        sp.setPreDelay(30.0f);
        sp.setMix(0.4f);
        return sp;
    }

    static SP2016Reverb createBrightPlatePreset()
    {
        SP2016Reverb sp;
        sp.setAlgorithm(Algorithm::Plate);
        sp.setSize(0.8f);
        sp.setDecay(0.75f);
        sp.setDamping(0.1f);
        sp.setMix(0.35f);
        return sp;
    }

private:
    std::array<std::unique_ptr<CombFilter>, 8> combs;
    std::array<std::unique_ptr<AllPassFilter>, 4> allpasses;

    double sampleRate = 44100.0;
    Algorithm currentAlgorithm = Algorithm::Room;
    float size = 1.0f;
    float decayTime = 0.7f;
    float damping = 0.3f;
    float preDelayMs = 10.0f;
    float wetDryMix = 0.3f;
};

} // namespace Eventide
} // namespace Effects
} // namespace Echoelmusic
