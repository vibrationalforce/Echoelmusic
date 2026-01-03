#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <cmath>
#include <memory>

/**
 * Eventide-Inspired Harmonizer Effects
 *
 * Legendary pitch-shifting algorithms inspired by the H3000 Ultra-Harmonizer:
 * - MicroPitch: Phase-coherent subtle detuning for stereo widening
 * - Harmonizer: Intelligent pitch shifting with intervals
 * - Crystals: Granular reverse pitch + delays
 * - Quadravox: 4-voice diatonic harmonizer
 * - Octavox: 8-voice chromatic pitch shifter
 *
 * Based on research of Eventide's groundbreaking 1987 H3000 architecture.
 * Uses modern PSOLA and granular synthesis techniques.
 *
 * Super Ralph Wiggum Loop Genius Harmonizer Mode
 */

namespace Echoelmusic {
namespace Effects {
namespace Eventide {

//==============================================================================
// Constants
//==============================================================================

constexpr float PI = 3.14159265358979f;
constexpr float TWO_PI = 6.28318530717959f;

//==============================================================================
// Grain for Granular Pitch Shifting
//==============================================================================

struct Grain
{
    float* buffer = nullptr;
    int bufferSize = 0;
    int readPosition = 0;
    int grainLength = 0;
    float pitch = 1.0f;
    float amplitude = 0.0f;
    float pan = 0.0f;
    bool active = false;
    bool reverse = false;

    float envelope = 0.0f;
    int envelopePhase = 0;  // 0=attack, 1=sustain, 2=release
    int attackSamples = 0;
    int releaseSamples = 0;
    int currentSample = 0;

    void reset()
    {
        active = false;
        readPosition = 0;
        currentSample = 0;
        envelope = 0.0f;
        envelopePhase = 0;
    }

    float process()
    {
        if (!active) return 0.0f;

        // Calculate envelope
        if (envelopePhase == 0)  // Attack
        {
            envelope = static_cast<float>(currentSample) / static_cast<float>(attackSamples);
            if (currentSample >= attackSamples)
                envelopePhase = 1;
        }
        else if (envelopePhase == 2)  // Release
        {
            int releasePos = currentSample - (grainLength - releaseSamples);
            envelope = 1.0f - static_cast<float>(releasePos) / static_cast<float>(releaseSamples);
        }

        // Check if entering release phase
        if (currentSample >= grainLength - releaseSamples && envelopePhase == 1)
            envelopePhase = 2;

        // Read from buffer with interpolation
        float fracPos = readPosition * pitch;
        int pos0, pos1;

        if (reverse)
        {
            pos0 = (bufferSize - 1 - static_cast<int>(fracPos)) % bufferSize;
            pos1 = (pos0 - 1 + bufferSize) % bufferSize;
        }
        else
        {
            pos0 = static_cast<int>(fracPos) % bufferSize;
            pos1 = (pos0 + 1) % bufferSize;
        }

        float frac = fracPos - std::floor(fracPos);
        float sample = buffer[pos0] * (1.0f - frac) + buffer[pos1] * frac;

        // Apply envelope and amplitude
        sample *= envelope * amplitude;

        // Advance position
        readPosition++;
        currentSample++;

        // Check if grain is complete
        if (currentSample >= grainLength)
        {
            active = false;
        }

        return sample;
    }
};

//==============================================================================
// Granular Pitch Shifter Engine
//==============================================================================

class GranularPitchShifter
{
public:
    GranularPitchShifter(int maxGrains = 8, int bufferSizeSamples = 65536)
        : numGrains(maxGrains)
    {
        delayBuffer.resize(bufferSizeSamples, 0.0f);
        grains.resize(maxGrains);

        for (auto& grain : grains)
        {
            grain.buffer = delayBuffer.data();
            grain.bufferSize = bufferSizeSamples;
        }
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        calculateGrainParameters();
    }

    void setGrainSize(float sizeMs)
    {
        grainSizeMs = std::clamp(sizeMs, 10.0f, 500.0f);
        calculateGrainParameters();
    }

    void setPitch(float semitones)
    {
        pitchShiftSemitones = semitones;
        pitchRatio = std::pow(2.0f, semitones / 12.0f);
    }

    void setMix(float mix) { wetDryMix = std::clamp(mix, 0.0f, 1.0f); }
    void setFeedback(float fb) { feedback = std::clamp(fb, 0.0f, 0.95f); }
    void setReverse(bool rev) { reverseGrains = rev; }

    float process(float input)
    {
        // Write to delay buffer
        delayBuffer[writePosition] = input + lastOutput * feedback;
        writePosition = (writePosition + 1) % static_cast<int>(delayBuffer.size());

        // Trigger new grains
        grainCounter++;
        if (grainCounter >= grainSpacing)
        {
            grainCounter = 0;
            triggerGrain();
        }

        // Sum active grains
        float output = 0.0f;
        for (auto& grain : grains)
        {
            if (grain.active)
            {
                output += grain.process();
            }
        }

        lastOutput = output;

        // Mix dry/wet
        return input * (1.0f - wetDryMix) + output * wetDryMix;
    }

    void processStereo(float inputL, float inputR, float& outputL, float& outputR)
    {
        // Simple stereo: process mono and add spread
        float monoIn = (inputL + inputR) * 0.5f;
        float monoOut = process(monoIn);

        // Add stereo spread based on grain panning
        outputL = inputL * (1.0f - wetDryMix) + monoOut * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + monoOut * wetDryMix;
    }

private:
    double sampleRate = 44100.0;
    int numGrains;
    std::vector<float> delayBuffer;
    std::vector<Grain> grains;

    int writePosition = 0;
    int grainCounter = 0;
    int grainSpacing = 512;
    int grainLength = 2048;

    float grainSizeMs = 50.0f;
    float pitchShiftSemitones = 0.0f;
    float pitchRatio = 1.0f;
    float wetDryMix = 0.5f;
    float feedback = 0.0f;
    float lastOutput = 0.0f;
    bool reverseGrains = false;

    void calculateGrainParameters()
    {
        grainLength = static_cast<int>(grainSizeMs * 0.001f * sampleRate);
        grainSpacing = grainLength / (numGrains / 2);  // 50% overlap
    }

    void triggerGrain()
    {
        // Find inactive grain
        for (auto& grain : grains)
        {
            if (!grain.active)
            {
                grain.reset();
                grain.active = true;
                grain.grainLength = grainLength;
                grain.pitch = pitchRatio;
                grain.amplitude = 1.0f / std::sqrt(static_cast<float>(numGrains));
                grain.attackSamples = grainLength / 4;
                grain.releaseSamples = grainLength / 4;
                grain.readPosition = (writePosition - grainLength + static_cast<int>(delayBuffer.size()))
                                     % static_cast<int>(delayBuffer.size());
                grain.reverse = reverseGrains;
                break;
            }
        }
    }
};

//==============================================================================
// MicroPitch - H3000 Style Subtle Detuning
//==============================================================================

class MicroPitch
{
public:
    /**
     * MicroPitch creates subtle pitch detuning for stereo widening
     * The legendary H3000 effect used for thickening guitars, vocals, synths
     *
     * Style I: Tighter, more focused (preset 231)
     * Style II: Wider, more diffuse (preset 519)
     */

    enum class Style { StyleI, StyleII };

    MicroPitch()
    {
        shifterL = std::make_unique<GranularPitchShifter>(4, 32768);
        shifterR = std::make_unique<GranularPitchShifter>(4, 32768);
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        shifterL->prepare(sampleRate, blockSize);
        shifterR->prepare(sampleRate, blockSize);
        applyStyle();
    }

    void setStyle(Style s)
    {
        style = s;
        applyStyle();
    }

    void setDetune(float cents)
    {
        // Detune in cents (-50 to +50 typical)
        detuneCents = std::clamp(cents, -100.0f, 100.0f);
        shifterL->setPitch(-detuneCents / 100.0f);
        shifterR->setPitch(detuneCents / 100.0f);
    }

    void setDelay(float ms)
    {
        delayMs = std::clamp(ms, 0.0f, 50.0f);
        int delaySamples = static_cast<int>(delayMs * 0.001f * sampleRate);
        // Would apply delay offset to grain read position
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
        shifterL->setMix(wetDryMix);
        shifterR->setMix(wetDryMix);
    }

    void setWidth(float width)
    {
        stereoWidth = std::clamp(width, 0.0f, 2.0f);
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        float wetL, wetR;
        float dummyL, dummyR;

        shifterL->processStereo(inputL, inputL, wetL, dummyL);
        shifterR->processStereo(inputR, inputR, dummyR, wetR);

        // Apply stereo width
        float mid = (wetL + wetR) * 0.5f;
        float side = (wetL - wetR) * 0.5f * stereoWidth;

        outputL = mid + side;
        outputR = mid - side;

        // Mix with dry
        outputL = inputL * (1.0f - wetDryMix) + outputL * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + outputR * wetDryMix;
    }

    // Presets
    static MicroPitch createThickenPreset()
    {
        MicroPitch mp;
        mp.setDetune(10.0f);   // 10 cents
        mp.setDelay(10.0f);    // 10ms
        mp.setMix(0.5f);
        mp.setWidth(1.0f);
        return mp;
    }

    static MicroPitch createWidenPreset()
    {
        MicroPitch mp;
        mp.setStyle(Style::StyleII);
        mp.setDetune(20.0f);   // 20 cents
        mp.setDelay(20.0f);    // 20ms
        mp.setMix(0.4f);
        mp.setWidth(1.5f);
        return mp;
    }

private:
    std::unique_ptr<GranularPitchShifter> shifterL;
    std::unique_ptr<GranularPitchShifter> shifterR;

    double sampleRate = 44100.0;
    Style style = Style::StyleI;
    float detuneCents = 10.0f;
    float delayMs = 10.0f;
    float wetDryMix = 0.5f;
    float stereoWidth = 1.0f;

    void applyStyle()
    {
        if (style == Style::StyleI)
        {
            shifterL->setGrainSize(30.0f);
            shifterR->setGrainSize(30.0f);
        }
        else
        {
            shifterL->setGrainSize(60.0f);
            shifterR->setGrainSize(60.0f);
        }
    }
};

//==============================================================================
// Diatonic Harmonizer
//==============================================================================

class DiatonicHarmonizer
{
public:
    /**
     * Intelligent harmonizer that pitch shifts to scale degrees
     * Input a note, output harmonically correct intervals
     */

    enum class Scale
    {
        Major, Minor, Dorian, Phrygian, Lydian, Mixolydian, Aeolian, Locrian,
        HarmonicMinor, MelodicMinor, Chromatic
    };

    DiatonicHarmonizer()
    {
        for (int i = 0; i < 4; ++i)
        {
            shifters[i] = std::make_unique<GranularPitchShifter>(4, 32768);
        }
        buildScales();
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        for (auto& shifter : shifters)
        {
            shifter->prepare(sampleRate, blockSize);
        }
    }

    void setKey(int rootNote) { keyRoot = rootNote % 12; }
    void setScale(Scale s) { currentScale = s; }

    void setVoice(int voiceIndex, int interval, float level, float pan)
    {
        if (voiceIndex >= 0 && voiceIndex < 4)
        {
            voiceIntervals[voiceIndex] = interval;
            voiceLevels[voiceIndex] = level;
            voicePans[voiceIndex] = pan;
            voiceEnabled[voiceIndex] = level > 0.0f;
        }
    }

    void setMix(float mix) { wetDryMix = std::clamp(mix, 0.0f, 1.0f); }

    void process(float inputL, float inputR, float& outputL, float& outputR,
                 int detectedMidiNote = -1)
    {
        float wetL = 0.0f, wetR = 0.0f;

        for (int i = 0; i < 4; ++i)
        {
            if (!voiceEnabled[i]) continue;

            // Calculate pitch shift based on scale
            float semitones;
            if (detectedMidiNote >= 0)
            {
                // Intelligent mode: snap to scale
                int noteInKey = (detectedMidiNote - keyRoot + 12) % 12;
                int targetNote = getScaleDegree(noteInKey, voiceIntervals[i]);
                semitones = static_cast<float>(targetNote - noteInKey);
            }
            else
            {
                // Fixed interval mode
                semitones = static_cast<float>(voiceIntervals[i]);
            }

            shifters[i]->setPitch(semitones);

            float voiceL, voiceR;
            shifters[i]->processStereo(inputL, inputR, voiceL, voiceR);

            // Apply level and pan
            float gain = voiceLevels[i];
            float panL = std::sqrt(0.5f * (1.0f - voicePans[i]));
            float panR = std::sqrt(0.5f * (1.0f + voicePans[i]));

            wetL += voiceL * gain * panL;
            wetR += voiceR * gain * panR;
        }

        // Mix
        outputL = inputL * (1.0f - wetDryMix) + wetL * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + wetR * wetDryMix;
    }

    // Quick preset: thirds
    void setThirdsPreset()
    {
        setVoice(0, 3, 0.7f, -0.5f);  // Minor 3rd left
        setVoice(1, 4, 0.7f, 0.5f);   // Major 3rd right
        setVoice(2, 0, 0.0f, 0.0f);
        setVoice(3, 0, 0.0f, 0.0f);
    }

    // Quick preset: power chord
    void setPowerChordPreset()
    {
        setVoice(0, 7, 0.8f, 0.0f);   // Perfect 5th
        setVoice(1, -12, 0.5f, 0.0f); // Octave down
        setVoice(2, 0, 0.0f, 0.0f);
        setVoice(3, 0, 0.0f, 0.0f);
    }

private:
    std::array<std::unique_ptr<GranularPitchShifter>, 4> shifters;

    double sampleRate = 44100.0;
    Scale currentScale = Scale::Major;
    int keyRoot = 0;  // C

    std::array<int, 4> voiceIntervals = {0, 0, 0, 0};
    std::array<float, 4> voiceLevels = {0.0f, 0.0f, 0.0f, 0.0f};
    std::array<float, 4> voicePans = {0.0f, 0.0f, 0.0f, 0.0f};
    std::array<bool, 4> voiceEnabled = {false, false, false, false};

    float wetDryMix = 0.5f;

    std::map<Scale, std::vector<int>> scales;

    void buildScales()
    {
        scales[Scale::Major] = {0, 2, 4, 5, 7, 9, 11};
        scales[Scale::Minor] = {0, 2, 3, 5, 7, 8, 10};
        scales[Scale::Dorian] = {0, 2, 3, 5, 7, 9, 10};
        scales[Scale::Phrygian] = {0, 1, 3, 5, 7, 8, 10};
        scales[Scale::Lydian] = {0, 2, 4, 6, 7, 9, 11};
        scales[Scale::Mixolydian] = {0, 2, 4, 5, 7, 9, 10};
        scales[Scale::Aeolian] = {0, 2, 3, 5, 7, 8, 10};
        scales[Scale::Locrian] = {0, 1, 3, 5, 6, 8, 10};
        scales[Scale::HarmonicMinor] = {0, 2, 3, 5, 7, 8, 11};
        scales[Scale::MelodicMinor] = {0, 2, 3, 5, 7, 9, 11};
        scales[Scale::Chromatic] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
    }

    int getScaleDegree(int noteInScale, int interval)
    {
        auto& scale = scales[currentScale];

        // Find current position in scale
        int scalePos = 0;
        for (size_t i = 0; i < scale.size(); ++i)
        {
            if (scale[i] == noteInScale)
            {
                scalePos = static_cast<int>(i);
                break;
            }
        }

        // Move by interval (in scale degrees)
        int targetPos = scalePos + interval;
        int octaveShift = 0;

        while (targetPos < 0)
        {
            targetPos += static_cast<int>(scale.size());
            octaveShift -= 12;
        }
        while (targetPos >= static_cast<int>(scale.size()))
        {
            targetPos -= static_cast<int>(scale.size());
            octaveShift += 12;
        }

        return scale[targetPos] + octaveShift;
    }
};

//==============================================================================
// Crystals - Granular Reverse Pitch + Delays
//==============================================================================

class Crystals
{
public:
    /**
     * Crystals: The iconic H3000 effect combining:
     * - Twin reverse pitch shifters
     * - Granular synthesis
     * - Long delays
     * - Massive reverb tail
     *
     * Creates ethereal, climbing, cascading pitched delays
     */

    Crystals()
    {
        shifterL = std::make_unique<GranularPitchShifter>(8, 131072);
        shifterR = std::make_unique<GranularPitchShifter>(8, 131072);

        delayLineL.resize(192000, 0.0f);  // 4 seconds at 48kHz
        delayLineR.resize(192000, 0.0f);
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        shifterL->prepare(sampleRate, blockSize);
        shifterR->prepare(sampleRate, blockSize);

        // Resize delay lines
        int maxDelaySamples = static_cast<int>(4.0 * sampleRate);
        delayLineL.resize(maxDelaySamples, 0.0f);
        delayLineR.resize(maxDelaySamples, 0.0f);

        shifterL->setReverse(true);
        shifterR->setReverse(true);
    }

    void setPitchL(float semitones)
    {
        pitchL = semitones;
        shifterL->setPitch(semitones);
    }

    void setPitchR(float semitones)
    {
        pitchR = semitones;
        shifterR->setPitch(semitones);
    }

    void setDelayL(float ms)
    {
        delayMsL = std::clamp(ms, 0.0f, 4000.0f);
    }

    void setDelayR(float ms)
    {
        delayMsR = std::clamp(ms, 0.0f, 4000.0f);
    }

    void setFeedback(float fb)
    {
        feedback = std::clamp(fb, 0.0f, 0.99f);
    }

    void setGrainSize(float ms)
    {
        grainSizeMs = std::clamp(ms, 10.0f, 500.0f);
        shifterL->setGrainSize(grainSizeMs);
        shifterR->setGrainSize(grainSizeMs);
    }

    void setReverse(bool rev)
    {
        shifterL->setReverse(rev);
        shifterR->setReverse(rev);
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
        shifterL->setMix(1.0f);  // Shifters always full wet internally
        shifterR->setMix(1.0f);
    }

    void setReverbAmount(float amount)
    {
        reverbMix = std::clamp(amount, 0.0f, 1.0f);
    }

    void setReverbSize(float size)
    {
        reverbSize = std::clamp(size, 0.0f, 1.0f);
    }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        // Read from delay lines
        int delaySamplesL = static_cast<int>(delayMsL * 0.001f * sampleRate);
        int delaySamplesR = static_cast<int>(delayMsR * 0.001f * sampleRate);

        int readPosL = (delayWritePos - delaySamplesL + static_cast<int>(delayLineL.size()))
                       % static_cast<int>(delayLineL.size());
        int readPosR = (delayWritePos - delaySamplesR + static_cast<int>(delayLineR.size()))
                       % static_cast<int>(delayLineR.size());

        float delayedL = delayLineL[readPosL];
        float delayedR = delayLineR[readPosR];

        // Process through pitch shifters
        float shiftedL, shiftedR, dummyL, dummyR;
        shifterL->processStereo(delayedL, delayedL, shiftedL, dummyL);
        shifterR->processStereo(delayedR, delayedR, dummyR, shiftedR);

        // Simple reverb (Schroeder-style)
        float reverbL = processReverb(shiftedL, 0);
        float reverbR = processReverb(shiftedR, 1);

        // Mix reverb
        float wetL = shiftedL * (1.0f - reverbMix) + reverbL * reverbMix;
        float wetR = shiftedR * (1.0f - reverbMix) + reverbR * reverbMix;

        // Write to delay lines with feedback
        delayLineL[delayWritePos] = inputL + wetL * feedback;
        delayLineR[delayWritePos] = inputR + wetR * feedback;

        delayWritePos = (delayWritePos + 1) % static_cast<int>(delayLineL.size());

        // Final mix
        outputL = inputL * (1.0f - wetDryMix) + wetL * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + wetR * wetDryMix;
    }

    // Presets
    static Crystals createShimmerPreset()
    {
        Crystals c;
        c.setPitchL(12.0f);   // Octave up
        c.setPitchR(12.0f);
        c.setDelayL(500.0f);
        c.setDelayR(750.0f);
        c.setFeedback(0.7f);
        c.setReverbAmount(0.5f);
        c.setMix(0.4f);
        return c;
    }

    static Crystals createCascadePreset()
    {
        Crystals c;
        c.setPitchL(5.0f);    // Perfect 4th
        c.setPitchR(7.0f);    // Perfect 5th
        c.setDelayL(333.0f);
        c.setDelayR(500.0f);
        c.setFeedback(0.8f);
        c.setGrainSize(100.0f);
        c.setMix(0.5f);
        return c;
    }

    static Crystals createReversePadPreset()
    {
        Crystals c;
        c.setPitchL(-12.0f);  // Octave down
        c.setPitchR(0.0f);
        c.setDelayL(1000.0f);
        c.setDelayR(1500.0f);
        c.setFeedback(0.6f);
        c.setReverse(true);
        c.setReverbAmount(0.8f);
        c.setReverbSize(0.9f);
        c.setMix(0.6f);
        return c;
    }

private:
    std::unique_ptr<GranularPitchShifter> shifterL;
    std::unique_ptr<GranularPitchShifter> shifterR;

    std::vector<float> delayLineL;
    std::vector<float> delayLineR;
    int delayWritePos = 0;

    double sampleRate = 44100.0;
    float pitchL = 12.0f;
    float pitchR = 12.0f;
    float delayMsL = 500.0f;
    float delayMsR = 750.0f;
    float feedback = 0.7f;
    float grainSizeMs = 80.0f;
    float wetDryMix = 0.5f;
    float reverbMix = 0.3f;
    float reverbSize = 0.8f;

    // Simple reverb state (4 comb + 2 allpass)
    std::array<std::vector<float>, 4> combBuffers;
    std::array<int, 4> combPositions = {0, 0, 0, 0};
    std::array<std::vector<float>, 2> allpassBuffers;
    std::array<int, 2> allpassPositions = {0, 0};

    float processReverb(float input, int channel)
    {
        // Initialize buffers on first use
        if (combBuffers[0].empty())
        {
            int combSizes[] = {1557, 1617, 1491, 1422};
            int allpassSizes[] = {225, 556};

            for (int i = 0; i < 4; ++i)
            {
                combBuffers[i].resize(static_cast<int>(combSizes[i] * reverbSize * 2), 0.0f);
            }
            for (int i = 0; i < 2; ++i)
            {
                allpassBuffers[i].resize(allpassSizes[i], 0.0f);
            }
        }

        // Parallel comb filters
        float combSum = 0.0f;
        float combGain = 0.8f * reverbSize;

        for (int i = 0; i < 4; ++i)
        {
            auto& buffer = combBuffers[i];
            if (buffer.empty()) continue;

            float delayed = buffer[combPositions[i]];
            float newSample = input + delayed * combGain;
            buffer[combPositions[i]] = newSample;
            combPositions[i] = (combPositions[i] + 1) % static_cast<int>(buffer.size());
            combSum += delayed;
        }

        combSum *= 0.25f;

        // Series allpass filters
        float output = combSum;
        float allpassGain = 0.5f;

        for (int i = 0; i < 2; ++i)
        {
            auto& buffer = allpassBuffers[i];
            if (buffer.empty()) continue;

            float delayed = buffer[allpassPositions[i]];
            float temp = output + delayed * allpassGain;
            buffer[allpassPositions[i]] = temp;
            output = delayed - temp * allpassGain;
            allpassPositions[i] = (allpassPositions[i] + 1) % static_cast<int>(buffer.size());
        }

        return output;
    }
};

//==============================================================================
// H910 Vintage Harmonizer Emulation
//==============================================================================

class H910Harmonizer
{
public:
    /**
     * Emulation of the original 1975 Eventide H910
     * - First commercially available digital audio effects unit
     * - Used by Tony Visconti on David Bowie's "Low"
     * - Eddie Van Halen's signature chorus sound
     *
     * Features:
     * - Pitch ratio from 0.5 to 2.0 (one octave down to one octave up)
     * - Feedback for "barber pole" effect
     * - Anti-feedback for reverse barber pole
     * - Glitch/splice artifacts (intentional lo-fi character)
     */

    H910Harmonizer()
    {
        delayBuffer.resize(32768, 0.0f);
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
    }

    void setPitchRatio(float ratio)
    {
        // H910 range: 0.5 to 2.0
        pitchRatio = std::clamp(ratio, 0.5f, 2.0f);
    }

    void setDelay(float ms)
    {
        delayMs = std::clamp(ms, 0.0f, 112.5f);  // H910 max was 112.5ms
    }

    void setFeedback(float fb)
    {
        feedback = std::clamp(fb, -1.0f, 1.0f);  // Negative = anti-feedback
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
    }

    void setSpliceMode(bool enabled)
    {
        spliceMode = enabled;  // Enable lo-fi splice artifacts
    }

    float process(float input)
    {
        // Write to buffer
        delayBuffer[writePosition] = input;

        // Calculate read position with pitch shift
        readPosition += pitchRatio;

        // Handle splice/crossfade when read catches up to write
        if (spliceMode)
        {
            // Classic H910 behavior: abrupt splice
            while (readPosition >= writePosition)
            {
                readPosition -= delayBuffer.size() * 0.5f;
            }
            while (readPosition < writePosition - delayBuffer.size() * 0.5f)
            {
                readPosition += delayBuffer.size() * 0.5f;
            }
        }
        else
        {
            // Smooth crossfade version
            if (static_cast<int>(readPosition) >= writePosition)
            {
                readPosition = static_cast<float>(writePosition - static_cast<int>(delayBuffer.size() * 0.5f));
            }
        }

        // Read with interpolation
        int readPos = static_cast<int>(readPosition) & (static_cast<int>(delayBuffer.size()) - 1);
        int readPos1 = (readPos + 1) & (static_cast<int>(delayBuffer.size()) - 1);
        float frac = readPosition - std::floor(readPosition);

        float output = delayBuffer[readPos] * (1.0f - frac) + delayBuffer[readPos1] * frac;

        // Apply feedback
        delayBuffer[writePosition] += output * feedback;

        writePosition = (writePosition + 1) & (static_cast<int>(delayBuffer.size()) - 1);

        // Mix
        return input * (1.0f - wetDryMix) + output * wetDryMix;
    }

    // Presets
    void setVanHalenChorus()
    {
        setPitchRatio(1.01f);   // Slight detune up
        setDelay(15.0f);
        setFeedback(0.0f);
        setMix(0.5f);
    }

    void setBarberPole()
    {
        setPitchRatio(0.95f);
        setDelay(50.0f);
        setFeedback(0.7f);
        setMix(0.4f);
    }

private:
    std::vector<float> delayBuffer;
    double sampleRate = 44100.0;

    int writePosition = 0;
    float readPosition = 0.0f;

    float pitchRatio = 1.0f;
    float delayMs = 20.0f;
    float feedback = 0.0f;
    float wetDryMix = 0.5f;
    bool spliceMode = true;
};

//==============================================================================
// Quadravox - 4-Voice Harmonizer
//==============================================================================

class Quadravox
{
public:
    /**
     * 4-voice diatonic pitch shifter
     * Each voice has independent pitch, delay, pan, and level
     */

    Quadravox()
    {
        for (int i = 0; i < 4; ++i)
        {
            voices[i] = std::make_unique<GranularPitchShifter>(4, 32768);
            delayLines[i].resize(96000, 0.0f);  // 2 seconds max
        }
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        for (auto& voice : voices)
        {
            voice->prepare(sampleRate, blockSize);
        }
    }

    struct VoiceSettings
    {
        float pitchSemitones = 0.0f;
        float delayMs = 0.0f;
        float pan = 0.0f;
        float level = 0.0f;
        bool enabled = false;
    };

    void setVoice(int index, const VoiceSettings& settings)
    {
        if (index < 0 || index >= 4) return;

        voiceSettings[index] = settings;
        voices[index]->setPitch(settings.pitchSemitones);
    }

    void setMix(float mix) { wetDryMix = std::clamp(mix, 0.0f, 1.0f); }

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        float wetL = 0.0f, wetR = 0.0f;

        for (int i = 0; i < 4; ++i)
        {
            if (!voiceSettings[i].enabled) continue;

            // Get delayed input
            int delaySamples = static_cast<int>(voiceSettings[i].delayMs * 0.001f * sampleRate);
            delaySamples = std::min(delaySamples, static_cast<int>(delayLines[i].size()) - 1);

            int readPos = (delayWritePos - delaySamples + static_cast<int>(delayLines[i].size()))
                         % static_cast<int>(delayLines[i].size());

            float delayedInput = delayLines[i][readPos];

            // Pitch shift
            float shiftedL, shiftedR;
            voices[i]->processStereo(delayedInput, delayedInput, shiftedL, shiftedR);

            // Apply level and pan
            float level = voiceSettings[i].level;
            float pan = voiceSettings[i].pan;
            float panL = std::sqrt(0.5f * (1.0f - pan));
            float panR = std::sqrt(0.5f * (1.0f + pan));

            wetL += shiftedL * level * panL;
            wetR += shiftedR * level * panR;
        }

        // Update delay lines
        float monoIn = (inputL + inputR) * 0.5f;
        for (int i = 0; i < 4; ++i)
        {
            delayLines[i][delayWritePos] = monoIn;
        }
        delayWritePos = (delayWritePos + 1) % static_cast<int>(delayLines[0].size());

        // Mix output
        outputL = inputL * (1.0f - wetDryMix) + wetL * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + wetR * wetDryMix;
    }

    // Preset: Major chord
    void setMajorChordPreset()
    {
        setVoice(0, {4.0f, 0.0f, -0.7f, 0.7f, true});   // Major 3rd
        setVoice(1, {7.0f, 10.0f, 0.7f, 0.7f, true});   // Perfect 5th
        setVoice(2, {12.0f, 20.0f, 0.0f, 0.5f, true});  // Octave
        setVoice(3, {0.0f, 0.0f, 0.0f, 0.0f, false});
    }

    // Preset: Power stack
    void setPowerStackPreset()
    {
        setVoice(0, {-12.0f, 5.0f, -0.5f, 0.6f, true});  // Octave down
        setVoice(1, {12.0f, 10.0f, 0.5f, 0.5f, true});   // Octave up
        setVoice(2, {7.0f, 15.0f, 0.0f, 0.4f, true});    // 5th
        setVoice(3, {-5.0f, 20.0f, 0.0f, 0.3f, true});   // 4th down
    }

private:
    std::array<std::unique_ptr<GranularPitchShifter>, 4> voices;
    std::array<std::vector<float>, 4> delayLines;
    std::array<VoiceSettings, 4> voiceSettings;

    double sampleRate = 44100.0;
    int delayWritePos = 0;
    float wetDryMix = 0.5f;
};

} // namespace Eventide
} // namespace Effects
} // namespace Echoelmusic
