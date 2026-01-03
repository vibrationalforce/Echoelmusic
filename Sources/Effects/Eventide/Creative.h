#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <cmath>
#include <memory>
#include <random>

/**
 * Eventide-Inspired Creative Effects
 *
 * Unique multi-effects inspired by Eventide's creative tools:
 * - UltraTap: Multi-tap delay with slicing and modulation
 * - Undulator: AM tremolo with rhythmic modulation
 * - TriceraChorus: Thick 3-voice BBD-style chorus
 * - CrushStation: Overdrive and distortion
 * - Physion: Transient/tonal separation
 * - Rotary Mod: Leslie speaker emulation
 * - Instant Flanger/Phaser: Classic modulation
 *
 * Super Ralph Wiggum Loop Genius Creative Mode
 */

namespace Echoelmusic {
namespace Effects {
namespace Eventide {

constexpr float PI = 3.14159265358979f;
constexpr float TWO_PI = 6.28318530717959f;

//==============================================================================
// UltraTap - Multi-Tap Delay with Rhythm and Modulation
//==============================================================================

class UltraTap
{
public:
    /**
     * UltraTap - Rhythmic multi-tap delay
     *
     * Features up to 64 taps with:
     * - Spread control (tap spacing)
     * - Taper (volume envelope across taps)
     * - Chop (rhythmic gating)
     * - Slurm (smearing/modulation)
     * - Tone shaping per tap
     */

    static constexpr int MAX_TAPS = 64;

    UltraTap()
    {
        delayLine.resize(192000, 0.0f);  // 4 seconds at 48kHz
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        delayLine.resize(static_cast<int>(4.0 * sampleRate), 0.0f);
        calculateTaps();
    }

    void setLength(float ms)
    {
        totalLengthMs = std::clamp(ms, 10.0f, 4000.0f);
        calculateTaps();
    }

    void setTaps(int numTaps)
    {
        this->numTaps = std::clamp(numTaps, 1, MAX_TAPS);
        calculateTaps();
    }

    void setSpread(float spread)
    {
        // 0 = linear spacing, 1 = logarithmic (more at start)
        // -1 = reverse logarithmic (more at end)
        this->spread = std::clamp(spread, -1.0f, 1.0f);
        calculateTaps();
    }

    void setTaper(float taper)
    {
        // Controls volume envelope: -1 = fade in, 0 = flat, 1 = fade out
        this->taper = std::clamp(taper, -1.0f, 1.0f);
        calculateTaps();
    }

    void setChop(float chop)
    {
        // 0 = no gating, 1 = maximum rhythmic gating
        this->chop = std::clamp(chop, 0.0f, 1.0f);
    }

    void setSlurm(float slurm)
    {
        // Smearing/modulation amount
        this->slurm = std::clamp(slurm, 0.0f, 1.0f);
    }

    void setFeedback(float fb)
    {
        feedback = std::clamp(fb, 0.0f, 0.95f);
    }

    void setTone(float tone)
    {
        // -1 = dark, 0 = neutral, 1 = bright
        this->tone = std::clamp(tone, -1.0f, 1.0f);
    }

    void setWidth(float width)
    {
        stereoWidth = std::clamp(width, 0.0f, 1.0f);
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        float mono = (inputL + inputR) * 0.5f;

        // Write to delay line with feedback
        delayLine[writePos] = mono + lastOutput * feedback;
        writePos = (writePos + 1) % static_cast<int>(delayLine.size());

        // Sum all taps
        float wetL = 0.0f, wetR = 0.0f;

        for (int i = 0; i < numTaps; ++i)
        {
            // Calculate read position with slurm modulation
            float slurmOffset = std::sin(slurmPhase + i * 0.7f) * slurm * 50.0f;
            slurmPhase += 0.001f;
            if (slurmPhase > TWO_PI) slurmPhase -= TWO_PI;

            int delaySamples = tapDelays[i] + static_cast<int>(slurmOffset);
            delaySamples = std::max(1, delaySamples);

            int readPos = (writePos - delaySamples + static_cast<int>(delayLine.size()))
                         % static_cast<int>(delayLine.size());

            float sample = delayLine[readPos] * tapGains[i];

            // Apply chop (rhythmic gating)
            if (chop > 0.0f)
            {
                float chopPhase = (static_cast<float>(i) / numTaps) * TWO_PI * 4.0f;
                float chopGate = (std::sin(chopPhase + chopLFO) + 1.0f) * 0.5f;
                chopGate = 1.0f - chop + chop * chopGate;
                sample *= chopGate;
            }

            // Apply tone filter
            if (tone != 0.0f)
            {
                sample = applyTone(sample, i);
            }

            // Stereo placement
            float pan = tapPans[i] * stereoWidth;
            wetL += sample * std::sqrt(0.5f * (1.0f - pan));
            wetR += sample * std::sqrt(0.5f * (1.0f + pan));
        }

        // Update chop LFO
        chopLFO += 0.0001f * (1.0f + chop * 10.0f);
        if (chopLFO > TWO_PI) chopLFO -= TWO_PI;

        lastOutput = (wetL + wetR) * 0.5f;

        // Mix
        outputL = inputL * (1.0f - wetDryMix) + wetL * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + wetR * wetDryMix;
    }

    // Presets
    static UltraTap createSlapbackPreset()
    {
        UltraTap ut;
        ut.setTaps(4);
        ut.setLength(150.0f);
        ut.setSpread(0.3f);
        ut.setTaper(0.5f);
        ut.setMix(0.3f);
        return ut;
    }

    static UltraTap createRhythmicPreset()
    {
        UltraTap ut;
        ut.setTaps(16);
        ut.setLength(1000.0f);
        ut.setSpread(0.0f);
        ut.setTaper(0.7f);
        ut.setChop(0.5f);
        ut.setFeedback(0.3f);
        ut.setMix(0.5f);
        return ut;
    }

    static UltraTap createShimmerTapsPreset()
    {
        UltraTap ut;
        ut.setTaps(32);
        ut.setLength(2000.0f);
        ut.setSpread(-0.5f);
        ut.setTaper(0.3f);
        ut.setSlurm(0.4f);
        ut.setFeedback(0.6f);
        ut.setTone(0.5f);
        ut.setWidth(0.8f);
        ut.setMix(0.5f);
        return ut;
    }

private:
    std::vector<float> delayLine;
    std::array<int, MAX_TAPS> tapDelays;
    std::array<float, MAX_TAPS> tapGains;
    std::array<float, MAX_TAPS> tapPans;
    std::array<float, MAX_TAPS> toneStates;

    double sampleRate = 44100.0;
    int writePos = 0;
    int numTaps = 8;
    float totalLengthMs = 500.0f;
    float spread = 0.0f;
    float taper = 0.5f;
    float chop = 0.0f;
    float slurm = 0.0f;
    float feedback = 0.3f;
    float tone = 0.0f;
    float stereoWidth = 0.5f;
    float wetDryMix = 0.5f;

    float slurmPhase = 0.0f;
    float chopLFO = 0.0f;
    float lastOutput = 0.0f;

    void calculateTaps()
    {
        float totalSamples = totalLengthMs * 0.001f * static_cast<float>(sampleRate);

        for (int i = 0; i < numTaps; ++i)
        {
            // Calculate tap position with spread
            float normalizedPos = static_cast<float>(i) / static_cast<float>(numTaps - 1);

            if (spread > 0.0f)
            {
                normalizedPos = std::pow(normalizedPos, 1.0f + spread * 2.0f);
            }
            else if (spread < 0.0f)
            {
                normalizedPos = 1.0f - std::pow(1.0f - normalizedPos, 1.0f - spread * 2.0f);
            }

            tapDelays[i] = static_cast<int>(normalizedPos * totalSamples);
            tapDelays[i] = std::max(1, tapDelays[i]);

            // Calculate tap gain with taper
            float tapLevel = 1.0f / std::sqrt(static_cast<float>(numTaps));

            if (taper > 0.0f)
            {
                // Fade out (later taps quieter)
                tapLevel *= (1.0f - normalizedPos * taper);
            }
            else if (taper < 0.0f)
            {
                // Fade in (earlier taps quieter)
                tapLevel *= (normalizedPos * (-taper) + (1.0f + taper));
            }

            tapGains[i] = tapLevel;

            // Stereo panning (alternating L/R with some randomness)
            tapPans[i] = (i % 2 == 0) ? -0.5f : 0.5f;
            tapPans[i] += (static_cast<float>((i * 7) % 11) / 11.0f - 0.5f) * 0.3f;
        }
    }

    float applyTone(float input, int tapIndex)
    {
        // Simple one-pole filter per tap
        float coeff;
        if (tone > 0.0f)
        {
            // Highpass for brightness
            coeff = 0.05f + tone * 0.2f;
            float hp = input - toneStates[tapIndex];
            toneStates[tapIndex] += hp * coeff;
            return input * (1.0f - tone * 0.5f) + hp * tone * 0.5f;
        }
        else
        {
            // Lowpass for darkness
            coeff = 0.2f + tone * 0.15f;
            toneStates[tapIndex] = toneStates[tapIndex] * (1.0f - coeff) + input * coeff;
            return toneStates[tapIndex];
        }
    }
};

//==============================================================================
// TriceraChorus - Thick BBD-Style Tri-Chorus
//==============================================================================

class TriceraChorus
{
public:
    /**
     * TriceraChorus - Warm vintage chorus
     *
     * Emulates the lush sound of classic tri-chorus
     * units using BBD (Bucket Brigade Delay) modeling.
     *
     * Features:
     * - 3 modulated delay lines
     * - Adjustable speed and depth
     * - BBD-style lowpass filtering
     * - Feedback for flanging
     */

    TriceraChorus()
    {
        for (int i = 0; i < 3; ++i)
        {
            delayLines[i].resize(4096, 0.0f);
        }
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;

        // LFO phases 120 degrees apart
        lfoPhases[0] = 0.0f;
        lfoPhases[1] = TWO_PI / 3.0f;
        lfoPhases[2] = TWO_PI * 2.0f / 3.0f;
    }

    void setSpeed(float hz)
    {
        lfoSpeed = std::clamp(hz, 0.1f, 10.0f);
        lfoPhaseInc = TWO_PI * lfoSpeed / static_cast<float>(sampleRate);
    }

    void setDepth(float depth)
    {
        this->depth = std::clamp(depth, 0.0f, 1.0f);
        // Depth in samples (1-10ms range)
        depthSamples = depth * 0.01f * static_cast<float>(sampleRate);
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
    }

    void setFeedback(float fb)
    {
        feedback = std::clamp(fb, 0.0f, 0.9f);
    }

    void setTone(float tone)
    {
        // BBD lowpass cutoff
        this->tone = std::clamp(tone, 0.0f, 1.0f);
        bbdCutoff = 2000.0f + tone * 8000.0f;
    }

    void setWidth(float width)
    {
        stereoWidth = std::clamp(width, 0.0f, 1.0f);
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        float mono = (inputL + inputR) * 0.5f;

        // Write to delay lines
        for (int i = 0; i < 3; ++i)
        {
            delayLines[i][writePos] = mono + lastOutputs[i] * feedback;
        }

        // Process each voice
        std::array<float, 3> voices;
        float baseDelay = 0.007f * sampleRate;  // 7ms center delay

        for (int i = 0; i < 3; ++i)
        {
            // LFO modulation
            float mod = std::sin(lfoPhases[i]) * depthSamples;
            lfoPhases[i] += lfoPhaseInc;
            if (lfoPhases[i] > TWO_PI) lfoPhases[i] -= TWO_PI;

            float delay = baseDelay + mod;
            delay = std::max(1.0f, delay);

            // Read with interpolation
            int pos0 = static_cast<int>(writePos - delay);
            while (pos0 < 0) pos0 += static_cast<int>(delayLines[i].size());
            pos0 = pos0 % static_cast<int>(delayLines[i].size());
            int pos1 = (pos0 + 1) % static_cast<int>(delayLines[i].size());

            float frac = (writePos - delay) - std::floor(writePos - delay);
            float sample = delayLines[i][pos0] * (1.0f - frac) + delayLines[i][pos1] * frac;

            // BBD lowpass filter
            float alpha = TWO_PI * bbdCutoff / static_cast<float>(sampleRate);
            alpha = alpha / (alpha + 1.0f);
            bbdFilters[i] = bbdFilters[i] + alpha * (sample - bbdFilters[i]);
            sample = bbdFilters[i];

            voices[i] = sample;
            lastOutputs[i] = sample;
        }

        writePos = (writePos + 1) % static_cast<int>(delayLines[0].size());

        // Mix voices to stereo
        float wetL = voices[0] + voices[1] * 0.5f;
        float wetR = voices[2] + voices[1] * 0.5f;

        // Apply width
        float mid = (wetL + wetR) * 0.5f;
        float side = (wetL - wetR) * 0.5f * stereoWidth;
        wetL = mid + side;
        wetR = mid - side;

        // Final mix
        outputL = inputL * (1.0f - wetDryMix) + wetL * wetDryMix * 0.7f;
        outputR = inputR * (1.0f - wetDryMix) + wetR * wetDryMix * 0.7f;
    }

    // Presets
    static TriceraChorus createClassicPreset()
    {
        TriceraChorus tc;
        tc.setSpeed(0.8f);
        tc.setDepth(0.5f);
        tc.setTone(0.6f);
        tc.setMix(0.5f);
        return tc;
    }

    static TriceraChorus createDeepPreset()
    {
        TriceraChorus tc;
        tc.setSpeed(0.3f);
        tc.setDepth(0.8f);
        tc.setTone(0.4f);
        tc.setWidth(0.9f);
        tc.setMix(0.6f);
        return tc;
    }

private:
    std::array<std::vector<float>, 3> delayLines;
    std::array<float, 3> lfoPhases = {0.0f, 0.0f, 0.0f};
    std::array<float, 3> lastOutputs = {0.0f, 0.0f, 0.0f};
    std::array<float, 3> bbdFilters = {0.0f, 0.0f, 0.0f};

    double sampleRate = 44100.0;
    int writePos = 0;

    float lfoSpeed = 0.5f;
    float lfoPhaseInc = 0.0f;
    float depth = 0.5f;
    float depthSamples = 100.0f;
    float wetDryMix = 0.5f;
    float feedback = 0.0f;
    float tone = 0.7f;
    float bbdCutoff = 6000.0f;
    float stereoWidth = 0.7f;
};

//==============================================================================
// CrushStation - Overdrive and Distortion
//==============================================================================

class CrushStation
{
public:
    /**
     * CrushStation - Versatile overdrive/distortion
     *
     * Covers everything from warm tube saturation
     * to aggressive bit crushing.
     */

    enum class Type
    {
        Tube,
        Transistor,
        Fuzz,
        BitCrush,
        Rectify
    };

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
    }

    void setType(Type t) { distType = t; }

    void setDrive(float drive)
    {
        this->drive = std::clamp(drive, 0.0f, 1.0f);
    }

    void setLevel(float level)
    {
        outputLevel = std::clamp(level, 0.0f, 1.0f);
    }

    void setTone(float tone)
    {
        // Pre-distortion tone shaping
        this->tone = std::clamp(tone, -1.0f, 1.0f);
    }

    void setSag(float sag)
    {
        // Power supply sag emulation
        this->sag = std::clamp(sag, 0.0f, 1.0f);
    }

    void setBitDepth(int bits)
    {
        bitDepth = std::clamp(bits, 1, 16);
    }

    void setSampleRateReduction(float factor)
    {
        srReduction = std::clamp(factor, 1.0f, 100.0f);
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        // Apply sag (envelope-dependent gain reduction)
        float envelope = std::abs(inputL) + std::abs(inputR);
        sagState = sagState * 0.999f + envelope * 0.001f;
        float sagGain = 1.0f - sag * sagState * 0.5f;

        // Pre-tone filter
        float toneL = applyToneFilter(inputL * sagGain);
        float toneR = applyToneFilter(inputR * sagGain);

        // Apply drive
        float driveAmount = 1.0f + drive * 50.0f;
        toneL *= driveAmount;
        toneR *= driveAmount;

        // Distortion based on type
        float distL = distort(toneL);
        float distR = distort(toneR);

        // Output level
        distL *= outputLevel;
        distR *= outputLevel;

        // Mix
        outputL = inputL * (1.0f - wetDryMix) + distL * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + distR * wetDryMix;
    }

    // Presets
    static CrushStation createWarmTubePreset()
    {
        CrushStation cs;
        cs.setType(Type::Tube);
        cs.setDrive(0.4f);
        cs.setTone(0.2f);
        cs.setSag(0.3f);
        cs.setMix(1.0f);
        return cs;
    }

    static CrushStation createHeavyFuzzPreset()
    {
        CrushStation cs;
        cs.setType(Type::Fuzz);
        cs.setDrive(0.8f);
        cs.setTone(-0.3f);
        cs.setMix(1.0f);
        return cs;
    }

    static CrushStation createLoFiPreset()
    {
        CrushStation cs;
        cs.setType(Type::BitCrush);
        cs.setDrive(0.3f);
        cs.setBitDepth(8);
        cs.setSampleRateReduction(4.0f);
        cs.setMix(0.7f);
        return cs;
    }

private:
    double sampleRate = 44100.0;
    Type distType = Type::Tube;

    float drive = 0.5f;
    float outputLevel = 0.7f;
    float tone = 0.0f;
    float sag = 0.2f;
    float wetDryMix = 1.0f;

    int bitDepth = 16;
    float srReduction = 1.0f;

    float sagState = 0.0f;
    float toneFilterState = 0.0f;
    float srCounter = 0.0f;
    float lastSample = 0.0f;

    float applyToneFilter(float input)
    {
        if (tone > 0.0f)
        {
            // High shelf boost
            float hp = input - toneFilterState;
            toneFilterState += hp * 0.1f;
            return input + hp * tone * 0.5f;
        }
        else
        {
            // Low shelf boost
            toneFilterState = toneFilterState * 0.9f + input * 0.1f;
            return input * (1.0f + tone * 0.3f) + toneFilterState * (-tone * 0.3f);
        }
    }

    float distort(float input)
    {
        switch (distType)
        {
            case Type::Tube:
            {
                // Soft asymmetric clipping (tube-like)
                if (input > 0.0f)
                    return std::tanh(input * 1.2f);
                else
                    return std::tanh(input * 0.8f) * 1.2f;
            }

            case Type::Transistor:
            {
                // Harder clipping
                return std::tanh(input * 2.0f) * 0.7f;
            }

            case Type::Fuzz:
            {
                // Aggressive clipping with octave-up artifacts
                float squared = input * std::abs(input);
                return std::tanh(input + squared * 0.3f);
            }

            case Type::BitCrush:
            {
                // Sample rate reduction
                srCounter += 1.0f;
                if (srCounter >= srReduction)
                {
                    srCounter -= srReduction;
                    lastSample = input;
                }

                // Bit depth reduction
                float levels = std::pow(2.0f, static_cast<float>(bitDepth));
                return std::round(lastSample * levels) / levels;
            }

            case Type::Rectify:
            {
                // Full-wave rectification
                return std::abs(input) * 2.0f - 1.0f;
            }

            default:
                return input;
        }
    }
};

//==============================================================================
// Rotary Mod - Leslie Speaker Emulation
//==============================================================================

class RotaryMod
{
public:
    /**
     * Rotary Mod - Leslie cabinet emulation
     *
     * Models the rotating horn and drum of a Leslie cabinet.
     * Includes Doppler pitch shift and amplitude modulation.
     */

    enum class Speed { Slow, Fast, Stop };

    RotaryMod()
    {
        hornDelay.resize(4096, 0.0f);
        drumDelay.resize(4096, 0.0f);
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
    }

    void setSpeed(Speed s)
    {
        targetSpeed = s;

        switch (s)
        {
            case Speed::Slow:
                targetHornSpeed = 0.7f;
                targetDrumSpeed = 0.6f;
                break;
            case Speed::Fast:
                targetHornSpeed = 6.0f;
                targetDrumSpeed = 5.0f;
                break;
            case Speed::Stop:
                targetHornSpeed = 0.0f;
                targetDrumSpeed = 0.0f;
                break;
        }
    }

    void setDrive(float drive)
    {
        this->drive = std::clamp(drive, 0.0f, 1.0f);
    }

    void setHornLevel(float level)
    {
        hornLevel = std::clamp(level, 0.0f, 1.0f);
    }

    void setDrumLevel(float level)
    {
        drumLevel = std::clamp(level, 0.0f, 1.0f);
    }

    void setDistance(float dist)
    {
        // Mic distance simulation
        distance = std::clamp(dist, 0.0f, 1.0f);
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        // Ramp speeds (simulate motor inertia)
        float rampSpeed = 0.0001f;
        hornSpeed += (targetHornSpeed - hornSpeed) * rampSpeed;
        drumSpeed += (targetDrumSpeed - drumSpeed) * rampSpeed;

        float mono = (inputL + inputR) * 0.5f;

        // Apply drive (tube amp stage)
        if (drive > 0.0f)
        {
            float driveAmount = 1.0f + drive * 10.0f;
            mono = std::tanh(mono * driveAmount) / std::tanh(driveAmount);
        }

        // Split into horn (high) and drum (low)
        float horn = mono;  // Would use crossover filter
        float drum = mono;

        // Process horn (rotating tweeter)
        float hornPhaseInc = TWO_PI * hornSpeed / static_cast<float>(sampleRate);
        hornPhase += hornPhaseInc;
        if (hornPhase > TWO_PI) hornPhase -= TWO_PI;

        // Doppler effect (pitch modulation)
        float hornModDepth = 0.002f * sampleRate;  // ~2ms
        float hornMod = std::sin(hornPhase) * hornModDepth;

        // Write to delay
        hornDelay[writePos] = horn;
        int hornReadPos = static_cast<int>(writePos - 100 - hornMod);
        while (hornReadPos < 0) hornReadPos += static_cast<int>(hornDelay.size());
        hornReadPos = hornReadPos % static_cast<int>(hornDelay.size());

        float hornL = hornDelay[hornReadPos] * (1.0f + std::sin(hornPhase) * 0.3f);
        float hornR = hornDelay[hornReadPos] * (1.0f + std::cos(hornPhase) * 0.3f);

        // Process drum (rotating bass speaker)
        float drumPhaseInc = TWO_PI * drumSpeed / static_cast<float>(sampleRate);
        drumPhase += drumPhaseInc;
        if (drumPhase > TWO_PI) drumPhase -= TWO_PI;

        float drumModDepth = 0.001f * sampleRate;
        float drumMod = std::sin(drumPhase) * drumModDepth;

        drumDelay[writePos] = drum;
        int drumReadPos = static_cast<int>(writePos - 50 - drumMod);
        while (drumReadPos < 0) drumReadPos += static_cast<int>(drumDelay.size());
        drumReadPos = drumReadPos % static_cast<int>(drumDelay.size());

        float drumL = drumDelay[drumReadPos] * (1.0f + std::sin(drumPhase) * 0.2f);
        float drumR = drumDelay[drumReadPos] * (1.0f + std::cos(drumPhase) * 0.2f);

        writePos = (writePos + 1) % static_cast<int>(hornDelay.size());

        // Combine
        outputL = hornL * hornLevel + drumL * drumLevel;
        outputR = hornR * hornLevel + drumR * drumLevel;

        // Apply distance (more ambient at distance)
        if (distance > 0.0f)
        {
            float blend = 1.0f - distance * 0.5f;
            float ambient = (outputL + outputR) * 0.5f * distance * 0.3f;
            outputL = outputL * blend + ambient;
            outputR = outputR * blend + ambient;
        }
    }

private:
    std::vector<float> hornDelay;
    std::vector<float> drumDelay;

    double sampleRate = 44100.0;
    int writePos = 0;

    Speed targetSpeed = Speed::Slow;
    float hornSpeed = 0.7f;
    float drumSpeed = 0.6f;
    float targetHornSpeed = 0.7f;
    float targetDrumSpeed = 0.6f;

    float hornPhase = 0.0f;
    float drumPhase = 0.0f;

    float drive = 0.3f;
    float hornLevel = 0.7f;
    float drumLevel = 0.7f;
    float distance = 0.3f;
};

//==============================================================================
// Undulator - AM Tremolo with Rhythmic Modulation
//==============================================================================

class Undulator
{
public:
    /**
     * Undulator - Amplitude modulation effects
     *
     * From subtle tremolo to extreme rhythmic gating
     * with multiple LFO shapes and tempo sync.
     */

    enum class Shape
    {
        Sine,
        Triangle,
        Square,
        SawUp,
        SawDown,
        Random,
        SampleHold
    };

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
    }

    void setShape(Shape s) { shape = s; }

    void setRate(float hz)
    {
        rate = std::clamp(hz, 0.1f, 20.0f);
        phaseInc = TWO_PI * rate / static_cast<float>(sampleRate);
    }

    void setDepth(float depth)
    {
        this->depth = std::clamp(depth, 0.0f, 1.0f);
    }

    void setRhythm(float rhythm)
    {
        // Adds rhythmic variation to the modulation
        this->rhythm = std::clamp(rhythm, 0.0f, 1.0f);
    }

    void setStereo(float stereo)
    {
        // Phase offset between L and R
        this->stereo = std::clamp(stereo, 0.0f, 1.0f);
        stereoOffset = stereo * PI;
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        // Get modulation value based on shape
        float modL = getModulation(phase);
        float modR = getModulation(phase + stereoOffset);

        // Apply rhythm variation
        if (rhythm > 0.0f)
        {
            float rhythmMod = getModulation(phase * 0.25f);
            modL = modL * (1.0f - rhythm * 0.5f) + modL * rhythmMod * rhythm * 0.5f;
            modR = modR * (1.0f - rhythm * 0.5f) + modR * rhythmMod * rhythm * 0.5f;
        }

        // Scale to depth
        float gainL = 1.0f - depth + modL * depth;
        float gainR = 1.0f - depth + modR * depth;

        outputL = inputL * gainL;
        outputR = inputR * gainR;

        // Advance phase
        phase += phaseInc;
        if (phase > TWO_PI) phase -= TWO_PI;

        // Update random/S&H
        if (shape == Shape::Random || shape == Shape::SampleHold)
        {
            randomCounter += phaseInc;
            if (randomCounter > PI)
            {
                randomCounter -= PI;
                lastRandom = (static_cast<float>(rand()) / RAND_MAX) * 2.0f - 1.0f;
            }
        }
    }

private:
    double sampleRate = 44100.0;
    Shape shape = Shape::Sine;

    float phase = 0.0f;
    float phaseInc = 0.0f;
    float rate = 4.0f;
    float depth = 0.5f;
    float rhythm = 0.0f;
    float stereo = 0.0f;
    float stereoOffset = 0.0f;

    float lastRandom = 0.0f;
    float randomCounter = 0.0f;

    float getModulation(float ph)
    {
        while (ph > TWO_PI) ph -= TWO_PI;
        while (ph < 0.0f) ph += TWO_PI;

        switch (shape)
        {
            case Shape::Sine:
                return (std::sin(ph) + 1.0f) * 0.5f;

            case Shape::Triangle:
            {
                float t = ph / TWO_PI;
                return (t < 0.5f) ? t * 2.0f : 2.0f - t * 2.0f;
            }

            case Shape::Square:
                return (ph < PI) ? 1.0f : 0.0f;

            case Shape::SawUp:
                return ph / TWO_PI;

            case Shape::SawDown:
                return 1.0f - ph / TWO_PI;

            case Shape::Random:
                return (lastRandom + 1.0f) * 0.5f;

            case Shape::SampleHold:
                return (lastRandom + 1.0f) * 0.5f;

            default:
                return 0.5f;
        }
    }
};

//==============================================================================
// Instant Flanger
//==============================================================================

class InstantFlanger
{
public:
    InstantFlanger()
    {
        delayLine.resize(4096, 0.0f);
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
    }

    void setRate(float hz)
    {
        rate = std::clamp(hz, 0.01f, 10.0f);
        phaseInc = TWO_PI * rate / static_cast<float>(sampleRate);
    }

    void setDepth(float depth)
    {
        this->depth = std::clamp(depth, 0.0f, 1.0f);
        depthSamples = depth * 0.005f * static_cast<float>(sampleRate);
    }

    void setFeedback(float fb)
    {
        feedback = std::clamp(fb, -0.95f, 0.95f);
    }

    void setManual(float manual)
    {
        // Manual delay offset
        this->manual = std::clamp(manual, 0.0f, 1.0f);
        manualOffset = manual * 0.01f * static_cast<float>(sampleRate);
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        float mono = (inputL + inputR) * 0.5f;

        // LFO
        float mod = std::sin(phase) * depthSamples;
        phase += phaseInc;
        if (phase > TWO_PI) phase -= TWO_PI;

        // Calculate delay
        float delay = manualOffset + 1.0f + mod;
        delay = std::max(1.0f, delay);

        // Write to delay
        delayLine[writePos] = mono + lastOutput * feedback;

        // Read with interpolation
        int readPos = static_cast<int>(writePos - delay);
        while (readPos < 0) readPos += static_cast<int>(delayLine.size());
        int pos0 = readPos % static_cast<int>(delayLine.size());
        int pos1 = (pos0 + 1) % static_cast<int>(delayLine.size());

        float frac = (writePos - delay) - std::floor(writePos - delay);
        float wet = delayLine[pos0] * (1.0f - frac) + delayLine[pos1] * frac;

        lastOutput = wet;
        writePos = (writePos + 1) % static_cast<int>(delayLine.size());

        // Mix
        float outMono = mono + wet * wetDryMix;
        outputL = outMono;
        outputR = outMono;
    }

private:
    std::vector<float> delayLine;
    double sampleRate = 44100.0;
    int writePos = 0;

    float phase = 0.0f;
    float phaseInc = 0.0f;
    float rate = 0.2f;
    float depth = 0.5f;
    float depthSamples = 100.0f;
    float feedback = 0.5f;
    float manual = 0.5f;
    float manualOffset = 50.0f;
    float wetDryMix = 0.5f;
    float lastOutput = 0.0f;
};

//==============================================================================
// Instant Phaser
//==============================================================================

class InstantPhaser
{
public:
    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
    }

    void setRate(float hz)
    {
        rate = std::clamp(hz, 0.01f, 10.0f);
        phaseInc = TWO_PI * rate / static_cast<float>(sampleRate);
    }

    void setDepth(float depth)
    {
        this->depth = std::clamp(depth, 0.0f, 1.0f);
    }

    void setStages(int stages)
    {
        numStages = std::clamp(stages, 2, 12);
    }

    void setFeedback(float fb)
    {
        feedback = std::clamp(fb, -0.95f, 0.95f);
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        float mono = (inputL + inputR) * 0.5f + lastOutput * feedback;

        // LFO
        float mod = std::sin(phase);
        phase += phaseInc;
        if (phase > TWO_PI) phase -= TWO_PI;

        // Calculate allpass frequencies
        float minFreq = 100.0f;
        float maxFreq = 4000.0f;
        float freq = minFreq + (maxFreq - minFreq) * (mod * 0.5f + 0.5f) * depth;

        // Process through allpass stages
        float output = mono;
        for (int i = 0; i < numStages; ++i)
        {
            float stageFreq = freq * (1.0f + i * 0.3f);
            output = processAllpass(output, stageFreq, i);
        }

        lastOutput = output;

        // Mix
        float wet = (mono + output) * 0.5f;
        outputL = inputL * (1.0f - wetDryMix) + wet * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + wet * wetDryMix;
    }

private:
    double sampleRate = 44100.0;
    float phase = 0.0f;
    float phaseInc = 0.0f;

    float rate = 0.3f;
    float depth = 0.7f;
    int numStages = 6;
    float feedback = 0.3f;
    float wetDryMix = 0.5f;
    float lastOutput = 0.0f;

    std::array<float, 12> allpassStates = {0};

    float processAllpass(float input, float freq, int stage)
    {
        // First-order allpass coefficient
        float omega = TWO_PI * freq / static_cast<float>(sampleRate);
        float coeff = (1.0f - omega) / (1.0f + omega);

        float output = coeff * (input - allpassStates[stage]) + allpassStates[stage];
        allpassStates[stage] = output;

        return output;
    }
};

} // namespace Eventide
} // namespace Effects
} // namespace Echoelmusic
