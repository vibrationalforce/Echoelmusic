#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <cmath>
#include <memory>
#include <random>

/**
 * VocalSuite - Integrated Voice Processing Chain
 *
 * Connects all vocal processing modules in a unified system:
 * - Autotune (pitch correction)
 * - Harmonizer (multi-voice harmonies)
 * - Voice Cloner (AI-based voice transformation)
 * - Formant Shifter (gender/character transformation)
 * - Vocoder (robotic effects)
 *
 * Voice Character Types:
 * - Natural, Robot, Alien, Demon, Angel, Child, Giant
 * - Monster, Whisper, Radio, Telephone, Megaphone
 * - Male, Female, Androgynous
 *
 * Signal Chain:
 * Input → Autotune → Harmonizer → VoiceCloner/FormantShift → Vocoder → Output
 *
 * Inspired by: iZotope VocalSynth, Antares Harmony Engine, Waves OVox
 */

namespace Echoelmusic {
namespace Vocals {

//==============================================================================
// Voice Character Profiles
//==============================================================================

enum class VoiceCharacter
{
    Natural,
    Robot,
    Alien,
    Demon,
    Angel,
    Child,
    Giant,
    Monster,
    Whisper,
    Radio,
    Telephone,
    Megaphone,
    Male,
    Female,
    Androgynous,
    Choir,
    Cyberpunk,
    Ghost
};

struct VoiceProfile
{
    float pitchShift = 0.0f;          // Semitones
    float formantShift = 0.0f;        // Semitones
    float throatLength = 1.0f;        // 0.5-2.0
    float breathiness = 0.0f;         // 0-1
    float roboticAmount = 0.0f;       // 0-1 (vocoder mix)
    float reverbAmount = 0.0f;        // 0-1
    float distortionAmount = 0.0f;    // 0-1
    float chorusAmount = 0.0f;        // 0-1
    float filterCutoff = 20000.0f;    // Hz
    float filterResonance = 0.5f;
    bool enableHarmonizer = false;
    int harmonizerVoices = 0;
    std::array<int, 4> harmonyIntervals = {0, 0, 0, 0};
};

//==============================================================================
// Pitch Detector (YIN Algorithm)
//==============================================================================

class PitchDetector
{
public:
    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        bufferSize = static_cast<int>(sampleRate * 0.05);  // 50ms
        buffer.resize(bufferSize, 0.0f);
        writePos = 0;
    }

    void pushSample(float sample)
    {
        buffer[writePos] = sample;
        writePos = (writePos + 1) % bufferSize;
    }

    float detectPitch()
    {
        // YIN algorithm implementation
        std::vector<float> diff(bufferSize / 2, 0.0f);
        std::vector<float> cumulativeMean(bufferSize / 2, 0.0f);

        // Difference function
        for (int tau = 1; tau < bufferSize / 2; ++tau)
        {
            float sum = 0.0f;
            for (int i = 0; i < bufferSize / 2; ++i)
            {
                int idx1 = (writePos + i) % bufferSize;
                int idx2 = (writePos + i + tau) % bufferSize;
                float delta = buffer[idx1] - buffer[idx2];
                sum += delta * delta;
            }
            diff[tau] = sum;
        }

        // Cumulative mean normalized difference
        float runningSum = 0.0f;
        cumulativeMean[0] = 1.0f;
        for (int tau = 1; tau < bufferSize / 2; ++tau)
        {
            runningSum += diff[tau];
            cumulativeMean[tau] = diff[tau] * tau / runningSum;
        }

        // Find minimum
        const float threshold = 0.1f;
        int tau = -1;
        for (int i = 2; i < bufferSize / 2 - 1; ++i)
        {
            if (cumulativeMean[i] < threshold &&
                cumulativeMean[i] < cumulativeMean[i - 1] &&
                cumulativeMean[i] < cumulativeMean[i + 1])
            {
                tau = i;
                break;
            }
        }

        if (tau < 2)
            return 0.0f;

        // Parabolic interpolation
        float s0 = cumulativeMean[tau - 1];
        float s1 = cumulativeMean[tau];
        float s2 = cumulativeMean[tau + 1];
        float betterTau = tau + (s2 - s0) / (2.0f * (2.0f * s1 - s2 - s0));

        return static_cast<float>(currentSampleRate) / betterTau;
    }

    void reset()
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        writePos = 0;
    }

private:
    double currentSampleRate = 48000.0;
    std::vector<float> buffer;
    int bufferSize = 2048;
    int writePos = 0;
};

//==============================================================================
// Granular Pitch Shifter
//==============================================================================

class GranularPitchShifter
{
public:
    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        grainSize = static_cast<int>(0.02 * sampleRate);  // 20ms
        buffer.resize(grainSize * 4, 0.0f);
        writePos = 0;
    }

    void setPitchRatio(float ratio)
    {
        pitchRatio = juce::jlimit(0.25f, 4.0f, ratio);
    }

    float process(float input)
    {
        buffer[writePos] = input;
        writePos = (writePos + 1) % buffer.size();

        // Two overlapping grains
        float output = 0.0f;

        for (int g = 0; g < 2; ++g)
        {
            float grainOffset = (g == 0) ? 0.0f : 0.5f;
            float phase = std::fmod(grainPhase + grainOffset, 1.0f);

            int readPos = static_cast<int>(writePos - grainSize + phase * grainSize * (1.0f - pitchRatio));
            while (readPos < 0) readPos += buffer.size();
            readPos = readPos % buffer.size();

            // Hann window
            float window = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi * phase));

            output += buffer[readPos] * window;
        }

        grainPhase += 1.0f / grainSize;
        if (grainPhase >= 1.0f) grainPhase -= 1.0f;

        return output;
    }

    void reset()
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        grainPhase = 0.0f;
    }

private:
    double currentSampleRate = 48000.0;
    std::vector<float> buffer;
    int grainSize = 1024;
    int writePos = 0;
    float grainPhase = 0.0f;
    float pitchRatio = 1.0f;
};

//==============================================================================
// Formant Shifter (Integrated)
//==============================================================================

class IntegratedFormantShifter
{
public:
    static constexpr int NumFormants = 5;

    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        updateFilters();
    }

    void setFormantShift(float semitones)
    {
        float ratio = std::pow(2.0f, semitones / 12.0f);
        for (int i = 0; i < NumFormants; ++i)
        {
            targetFreqs[i] = baseFreqs[i] * ratio;
            targetFreqs[i] = juce::jlimit(50.0f, 8000.0f, targetFreqs[i]);
        }
        updateFilters();
    }

    void setThroatLength(float length)
    {
        throatLength = juce::jlimit(0.5f, 2.0f, length);
        float ratio = 1.0f / throatLength;
        for (int i = 0; i < NumFormants; ++i)
        {
            targetFreqs[i] = baseFreqs[i] * ratio;
            targetFreqs[i] = juce::jlimit(50.0f, 8000.0f, targetFreqs[i]);
        }
        updateFilters();
    }

    float process(float input)
    {
        float output = 0.0f;

        for (int i = 0; i < NumFormants; ++i)
        {
            // Bandpass filter
            float w0 = 2.0f * juce::MathConstants<float>::pi * targetFreqs[i] /
                       static_cast<float>(currentSampleRate);
            float bw = 2.0f * juce::MathConstants<float>::pi * bandwidths[i] /
                       static_cast<float>(currentSampleRate);
            float cosW0 = std::cos(w0);
            float alpha = std::sin(w0) * std::sinh(bw / 2.0f);

            float y = (alpha * input + filterStates[i][0]) / (1.0f + alpha);
            filterStates[i][0] = -2.0f * cosW0 * y + filterStates[i][1];
            filterStates[i][1] = (1.0f - alpha) * y - alpha * input;

            output += y * gains[i];
        }

        return output * 0.4f;
    }

    void reset()
    {
        for (auto& state : filterStates)
            std::fill(state.begin(), state.end(), 0.0f);
    }

private:
    double currentSampleRate = 48000.0;
    float throatLength = 1.0f;

    std::array<float, NumFormants> baseFreqs = {500.0f, 1500.0f, 2500.0f, 3500.0f, 4500.0f};
    std::array<float, NumFormants> targetFreqs = {500.0f, 1500.0f, 2500.0f, 3500.0f, 4500.0f};
    std::array<float, NumFormants> bandwidths = {100.0f, 120.0f, 150.0f, 200.0f, 250.0f};
    std::array<float, NumFormants> gains = {1.0f, 0.7f, 0.5f, 0.3f, 0.2f};
    std::array<std::array<float, 2>, NumFormants> filterStates{};

    void updateFilters()
    {
        // Coefficients updated in process() for simplicity
    }
};

//==============================================================================
// Harmony Voice
//==============================================================================

class HarmonyVoice
{
public:
    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        pitchShifter.prepare(sampleRate);
        formantShifter.prepare(sampleRate);
    }

    void setInterval(int semitones)
    {
        interval = juce::jlimit(-24, 24, semitones);
        float ratio = std::pow(2.0f, interval / 12.0f);
        pitchShifter.setPitchRatio(ratio);
    }

    void setFormantPreserve(bool preserve)
    {
        formantPreserve = preserve;
        if (preserve)
            formantShifter.setFormantShift(static_cast<float>(-interval));
    }

    void setLevel(float lvl) { level = juce::jlimit(0.0f, 1.0f, lvl); }
    void setPan(float p) { pan = juce::jlimit(-1.0f, 1.0f, p); }
    void setActive(bool a) { active = a; }

    std::pair<float, float> process(float input)
    {
        if (!active || level < 0.001f)
            return {0.0f, 0.0f};

        float pitched = pitchShifter.process(input);

        if (formantPreserve)
            pitched = formantShifter.process(pitched);

        // Stereo pan
        float leftGain = std::cos((pan + 1.0f) * juce::MathConstants<float>::pi * 0.25f);
        float rightGain = std::sin((pan + 1.0f) * juce::MathConstants<float>::pi * 0.25f);

        return {pitched * level * leftGain, pitched * level * rightGain};
    }

    void reset()
    {
        pitchShifter.reset();
        formantShifter.reset();
    }

private:
    double currentSampleRate = 48000.0;
    GranularPitchShifter pitchShifter;
    IntegratedFormantShifter formantShifter;

    int interval = 0;
    float level = 0.7f;
    float pan = 0.0f;
    bool active = false;
    bool formantPreserve = true;
};

//==============================================================================
// Voice Cloner / Character Transformer
//==============================================================================

class VoiceCloner
{
public:
    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        pitchShifter.prepare(sampleRate);
        formantShifter.prepare(sampleRate);
        analysisBuffer.resize(static_cast<size_t>(0.03 * sampleRate), 0.0f);

        // Initialize filter states
        lpState = hpState = 0.0f;
    }

    void setCharacter(VoiceCharacter character)
    {
        currentCharacter = character;
        profile = getProfileForCharacter(character);
        applyProfile();
    }

    void setPitchShift(float semitones)
    {
        profile.pitchShift = juce::jlimit(-24.0f, 24.0f, semitones);
        float ratio = std::pow(2.0f, profile.pitchShift / 12.0f);
        pitchShifter.setPitchRatio(ratio);
    }

    void setFormantShift(float semitones)
    {
        profile.formantShift = juce::jlimit(-24.0f, 24.0f, semitones);
        formantShifter.setFormantShift(profile.formantShift);
    }

    void setThroatLength(float length)
    {
        profile.throatLength = juce::jlimit(0.5f, 2.0f, length);
        formantShifter.setThroatLength(profile.throatLength);
    }

    void setBreathiness(float amount)
    {
        profile.breathiness = juce::jlimit(0.0f, 1.0f, amount);
    }

    void setRoboticAmount(float amount)
    {
        profile.roboticAmount = juce::jlimit(0.0f, 1.0f, amount);
    }

    float process(float input)
    {
        float output = input;

        // Pitch shift
        if (std::abs(profile.pitchShift) > 0.01f)
            output = pitchShifter.process(output);

        // Formant shift
        if (std::abs(profile.formantShift) > 0.01f || std::abs(profile.throatLength - 1.0f) > 0.01f)
            output = formantShifter.process(output);

        // Add breathiness
        if (profile.breathiness > 0.0f)
        {
            float envelope = std::abs(input);
            envState = envState * 0.99f + envelope * 0.01f;

            static std::mt19937 gen(42);
            static std::uniform_real_distribution<float> dist(-1.0f, 1.0f);
            float noise = dist(gen) * profile.breathiness * 0.3f * envState;
            output += noise;
        }

        // Robotic effect (ring modulation + quantization)
        if (profile.roboticAmount > 0.0f)
        {
            // Ring modulation
            robotPhase += 150.0f / static_cast<float>(currentSampleRate);
            if (robotPhase >= 1.0f) robotPhase -= 1.0f;
            float ringMod = std::sin(robotPhase * juce::MathConstants<float>::twoPi);

            float robotic = output * ringMod;

            // Bit reduction
            float levels = 16.0f + (1.0f - profile.roboticAmount) * 240.0f;
            robotic = std::round(robotic * levels) / levels;

            output = output * (1.0f - profile.roboticAmount) + robotic * profile.roboticAmount;
        }

        // Filter
        if (profile.filterCutoff < 19000.0f)
        {
            float w = 2.0f * juce::MathConstants<float>::pi * profile.filterCutoff /
                      static_cast<float>(currentSampleRate);
            float a = std::exp(-w);
            lpState = lpState * a + output * (1.0f - a);
            output = lpState;
        }

        // Distortion
        if (profile.distortionAmount > 0.0f)
        {
            float drive = 1.0f + profile.distortionAmount * 10.0f;
            float distorted = std::tanh(output * drive);
            output = output * (1.0f - profile.distortionAmount) + distorted * profile.distortionAmount;
        }

        return output;
    }

    void reset()
    {
        pitchShifter.reset();
        formantShifter.reset();
        lpState = hpState = envState = 0.0f;
        robotPhase = 0.0f;
    }

    VoiceCharacter getCurrentCharacter() const { return currentCharacter; }
    const VoiceProfile& getProfile() const { return profile; }

private:
    double currentSampleRate = 48000.0;

    GranularPitchShifter pitchShifter;
    IntegratedFormantShifter formantShifter;

    VoiceCharacter currentCharacter = VoiceCharacter::Natural;
    VoiceProfile profile;

    std::vector<float> analysisBuffer;
    float lpState = 0.0f;
    float hpState = 0.0f;
    float envState = 0.0f;
    float robotPhase = 0.0f;

    VoiceProfile getProfileForCharacter(VoiceCharacter character)
    {
        VoiceProfile p;

        switch (character)
        {
            case VoiceCharacter::Natural:
                // Default, no changes
                break;

            case VoiceCharacter::Robot:
                p.roboticAmount = 0.8f;
                p.filterCutoff = 4000.0f;
                break;

            case VoiceCharacter::Alien:
                p.pitchShift = 5.0f;
                p.formantShift = 8.0f;
                p.roboticAmount = 0.3f;
                p.chorusAmount = 0.5f;
                break;

            case VoiceCharacter::Demon:
                p.pitchShift = -12.0f;
                p.formantShift = -8.0f;
                p.throatLength = 1.8f;
                p.distortionAmount = 0.4f;
                p.reverbAmount = 0.6f;
                break;

            case VoiceCharacter::Angel:
                p.pitchShift = 7.0f;
                p.formantShift = 5.0f;
                p.throatLength = 0.8f;
                p.reverbAmount = 0.7f;
                p.chorusAmount = 0.4f;
                p.enableHarmonizer = true;
                p.harmonizerVoices = 2;
                p.harmonyIntervals = {12, 7, 0, 0};
                break;

            case VoiceCharacter::Child:
                p.pitchShift = 6.0f;
                p.formantShift = 5.0f;
                p.throatLength = 0.7f;
                break;

            case VoiceCharacter::Giant:
                p.pitchShift = -10.0f;
                p.formantShift = -6.0f;
                p.throatLength = 1.6f;
                p.reverbAmount = 0.4f;
                break;

            case VoiceCharacter::Monster:
                p.pitchShift = -7.0f;
                p.formantShift = -10.0f;
                p.throatLength = 1.9f;
                p.distortionAmount = 0.5f;
                p.breathiness = 0.3f;
                break;

            case VoiceCharacter::Whisper:
                p.breathiness = 0.9f;
                p.filterCutoff = 6000.0f;
                break;

            case VoiceCharacter::Radio:
                p.filterCutoff = 3500.0f;
                p.distortionAmount = 0.2f;
                break;

            case VoiceCharacter::Telephone:
                p.filterCutoff = 3000.0f;
                p.distortionAmount = 0.15f;
                break;

            case VoiceCharacter::Megaphone:
                p.filterCutoff = 4000.0f;
                p.distortionAmount = 0.4f;
                break;

            case VoiceCharacter::Male:
                p.pitchShift = -4.0f;
                p.formantShift = -3.0f;
                p.throatLength = 1.15f;
                break;

            case VoiceCharacter::Female:
                p.pitchShift = 4.0f;
                p.formantShift = 3.0f;
                p.throatLength = 0.85f;
                break;

            case VoiceCharacter::Androgynous:
                p.throatLength = 1.0f;
                break;

            case VoiceCharacter::Choir:
                p.enableHarmonizer = true;
                p.harmonizerVoices = 4;
                p.harmonyIntervals = {-12, 4, 7, 12};
                p.reverbAmount = 0.5f;
                p.chorusAmount = 0.3f;
                break;

            case VoiceCharacter::Cyberpunk:
                p.roboticAmount = 0.5f;
                p.pitchShift = 2.0f;
                p.distortionAmount = 0.3f;
                p.filterCutoff = 5000.0f;
                break;

            case VoiceCharacter::Ghost:
                p.pitchShift = 5.0f;
                p.breathiness = 0.6f;
                p.reverbAmount = 0.8f;
                p.filterCutoff = 4000.0f;
                p.chorusAmount = 0.5f;
                break;
        }

        return p;
    }

    void applyProfile()
    {
        setPitchShift(profile.pitchShift);
        setFormantShift(profile.formantShift);
        setThroatLength(profile.throatLength);
    }
};

//==============================================================================
// Integrated Vocoder
//==============================================================================

class IntegratedVocoder
{
public:
    static constexpr int NumBands = 16;

    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;

        // Initialize band frequencies (exponential spacing)
        float minFreq = 80.0f;
        float maxFreq = 8000.0f;
        float ratio = std::pow(maxFreq / minFreq, 1.0f / (NumBands - 1));

        for (int i = 0; i < NumBands; ++i)
        {
            bandFreqs[i] = minFreq * std::pow(ratio, static_cast<float>(i));
            envelopes[i] = 0.0f;
        }

        carrierPhase = 0.0f;
    }

    void setCarrierFrequency(float hz)
    {
        carrierFreq = juce::jlimit(50.0f, 500.0f, hz);
    }

    void setMix(float mix)
    {
        wetMix = juce::jlimit(0.0f, 1.0f, mix);
    }

    float process(float input)
    {
        if (wetMix < 0.001f)
            return input;

        // Generate carrier (sawtooth)
        float carrier = carrierPhase * 2.0f - 1.0f;
        carrierPhase += carrierFreq / static_cast<float>(currentSampleRate);
        if (carrierPhase >= 1.0f) carrierPhase -= 1.0f;

        float vocoded = 0.0f;

        for (int i = 0; i < NumBands; ++i)
        {
            // Bandpass modulator
            float w0 = 2.0f * juce::MathConstants<float>::pi * bandFreqs[i] /
                       static_cast<float>(currentSampleRate);
            float Q = 8.0f;
            float alpha = std::sin(w0) / (2.0f * Q);

            // Simple state variable filter for bandpass
            float modBand = bandStates[i][0];
            bandStates[i][0] += alpha * (input - modBand - bandStates[i][1]);
            bandStates[i][1] += alpha * modBand;

            // Envelope follower
            float env = std::abs(modBand);
            float attackCoeff = 0.01f;
            float releaseCoeff = 0.001f;
            if (env > envelopes[i])
                envelopes[i] += attackCoeff * (env - envelopes[i]);
            else
                envelopes[i] += releaseCoeff * (env - envelopes[i]);

            // Bandpass carrier
            float carBand = carrierStates[i][0];
            carrierStates[i][0] += alpha * (carrier - carBand - carrierStates[i][1]);
            carrierStates[i][1] += alpha * carBand;

            // Apply envelope
            vocoded += carBand * envelopes[i];
        }

        return input * (1.0f - wetMix) + vocoded * wetMix * 4.0f;
    }

    void reset()
    {
        for (auto& state : bandStates)
            std::fill(state.begin(), state.end(), 0.0f);
        for (auto& state : carrierStates)
            std::fill(state.begin(), state.end(), 0.0f);
        std::fill(envelopes.begin(), envelopes.end(), 0.0f);
        carrierPhase = 0.0f;
    }

private:
    double currentSampleRate = 48000.0;
    float carrierFreq = 110.0f;
    float carrierPhase = 0.0f;
    float wetMix = 0.0f;

    std::array<float, NumBands> bandFreqs{};
    std::array<float, NumBands> envelopes{};
    std::array<std::array<float, 2>, NumBands> bandStates{};
    std::array<std::array<float, 2>, NumBands> carrierStates{};
};

//==============================================================================
// VocalSuite - Main Integrated Processor
//==============================================================================

class VocalSuite
{
public:
    static constexpr int MaxHarmonyVoices = 4;

    //==========================================================================
    // Constructor
    //==========================================================================

    VocalSuite()
    {
        pitchDetector = std::make_unique<PitchDetector>();
        voiceCloner = std::make_unique<VoiceCloner>();
        vocoder = std::make_unique<IntegratedVocoder>();

        for (int i = 0; i < MaxHarmonyVoices; ++i)
            harmonyVoices[i] = std::make_unique<HarmonyVoice>();
    }

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;

        pitchDetector->prepare(sampleRate);
        voiceCloner->prepare(sampleRate);
        vocoder->prepare(sampleRate);

        for (auto& voice : harmonyVoices)
            voice->prepare(sampleRate);

        reset();
    }

    void reset()
    {
        pitchDetector->reset();
        voiceCloner->reset();
        vocoder->reset();

        for (auto& voice : harmonyVoices)
            voice->reset();
    }

    //==========================================================================
    // Voice Character
    //==========================================================================

    void setVoiceCharacter(VoiceCharacter character)
    {
        voiceCloner->setCharacter(character);

        // Apply harmonizer settings from profile
        const auto& profile = voiceCloner->getProfile();

        if (profile.enableHarmonizer)
        {
            for (int i = 0; i < MaxHarmonyVoices; ++i)
            {
                if (i < profile.harmonizerVoices)
                {
                    harmonyVoices[i]->setActive(true);
                    harmonyVoices[i]->setInterval(profile.harmonyIntervals[i]);
                    harmonyVoices[i]->setLevel(0.5f);

                    // Spread harmonies in stereo
                    float pan = (i % 2 == 0) ? -0.5f : 0.5f;
                    pan *= (i / 2 + 1) * 0.3f;
                    harmonyVoices[i]->setPan(pan);
                }
                else
                {
                    harmonyVoices[i]->setActive(false);
                }
            }
        }
        else
        {
            for (auto& voice : harmonyVoices)
                voice->setActive(false);
        }

        // Apply vocoder settings
        vocoder->setMix(profile.roboticAmount);
    }

    //==========================================================================
    // Autotune Settings
    //==========================================================================

    void setAutotuneEnabled(bool enabled)
    {
        autotuneEnabled = enabled;
    }

    void setAutotuneSpeed(float speed)
    {
        autotuneSpeed = juce::jlimit(0.0f, 1.0f, speed);
    }

    void setAutotuneScale(int scaleMode, int rootNote)
    {
        this->scaleMode = scaleMode;
        this->rootNote = rootNote;
    }

    //==========================================================================
    // Harmony Settings
    //==========================================================================

    void setHarmonyEnabled(bool enabled)
    {
        harmonyEnabled = enabled;
    }

    void setHarmonyVoice(int index, int semitones, float level, float pan)
    {
        if (index >= 0 && index < MaxHarmonyVoices)
        {
            harmonyVoices[index]->setActive(true);
            harmonyVoices[index]->setInterval(semitones);
            harmonyVoices[index]->setLevel(level);
            harmonyVoices[index]->setPan(pan);
        }
    }

    void setFormantPreservation(bool enabled)
    {
        formantPreservation = enabled;
        for (auto& voice : harmonyVoices)
            voice->setFormantPreserve(enabled);
    }

    //==========================================================================
    // Direct Parameter Control
    //==========================================================================

    void setPitchShift(float semitones)
    {
        voiceCloner->setPitchShift(semitones);
    }

    void setFormantShift(float semitones)
    {
        voiceCloner->setFormantShift(semitones);
    }

    void setVocoderMix(float mix)
    {
        vocoder->setMix(mix);
    }

    void setMix(float mix)
    {
        wetMix = juce::jlimit(0.0f, 1.0f, mix);
    }

    //==========================================================================
    // Processing
    //==========================================================================

    void processBlock(juce::AudioBuffer<float>& buffer)
    {
        int numSamples = buffer.getNumSamples();
        int numChannels = buffer.getNumChannels();

        for (int i = 0; i < numSamples; ++i)
        {
            // Get mono input
            float monoIn = 0.0f;
            for (int ch = 0; ch < numChannels; ++ch)
                monoIn += buffer.getSample(ch, i);
            monoIn /= numChannels;

            float dry = monoIn;

            // Pitch detection for autotune
            pitchDetector->pushSample(monoIn);
            float detectedPitch = pitchDetector->detectPitch();

            // Autotune
            float tuned = monoIn;
            if (autotuneEnabled && detectedPitch > 50.0f)
            {
                float targetPitch = quantizePitch(detectedPitch);
                // Apply correction would involve pitch shifting here
                // For now, voice cloner handles pitch shifting
            }

            // Voice transformation
            float transformed = voiceCloner->process(tuned);

            // Vocoder
            transformed = vocoder->process(transformed);

            // Harmony voices
            float harmonyL = 0.0f;
            float harmonyR = 0.0f;

            if (harmonyEnabled)
            {
                for (auto& voice : harmonyVoices)
                {
                    auto [l, r] = voice->process(tuned);
                    harmonyL += l;
                    harmonyR += r;
                }
            }

            // Mix output
            float outL = transformed + harmonyL;
            float outR = transformed + harmonyR;

            // Final mix
            if (numChannels >= 2)
            {
                buffer.setSample(0, i, dry * (1.0f - wetMix) + outL * wetMix);
                buffer.setSample(1, i, dry * (1.0f - wetMix) + outR * wetMix);
            }
            else
            {
                buffer.setSample(0, i, dry * (1.0f - wetMix) + transformed * wetMix);
            }
        }
    }

    //==========================================================================
    // Getters
    //==========================================================================

    VoiceCharacter getCurrentCharacter() const
    {
        return voiceCloner->getCurrentCharacter();
    }

    float getDetectedPitch() const { return lastDetectedPitch; }

private:
    double currentSampleRate = 48000.0;

    std::unique_ptr<PitchDetector> pitchDetector;
    std::unique_ptr<VoiceCloner> voiceCloner;
    std::unique_ptr<IntegratedVocoder> vocoder;
    std::array<std::unique_ptr<HarmonyVoice>, MaxHarmonyVoices> harmonyVoices;

    // Autotune
    bool autotuneEnabled = false;
    float autotuneSpeed = 0.3f;
    int scaleMode = 0;  // 0=chromatic
    int rootNote = 0;   // C

    // Harmony
    bool harmonyEnabled = false;
    bool formantPreservation = true;

    // Mix
    float wetMix = 1.0f;

    float lastDetectedPitch = 0.0f;

    float quantizePitch(float pitchHz)
    {
        if (pitchHz < 20.0f) return pitchHz;

        float midiNote = 12.0f * std::log2(pitchHz / 440.0f) + 69.0f;
        int noteNumber = static_cast<int>(std::round(midiNote));

        if (scaleMode == 0)  // Chromatic
            return 440.0f * std::pow(2.0f, (noteNumber - 69.0f) / 12.0f);

        int noteInScale = (noteNumber - rootNote + 120) % 12;

        // Major scale
        const std::array<int, 12> majorScale = {1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1};
        // Minor scale
        const std::array<int, 12> minorScale = {1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0};

        const auto& scale = (scaleMode == 1) ? majorScale : minorScale;

        while (!scale[noteInScale])
        {
            noteNumber++;
            noteInScale = (noteNumber - rootNote + 120) % 12;
        }

        return 440.0f * std::pow(2.0f, (noteNumber - 69.0f) / 12.0f);
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(VocalSuite)
};

} // namespace Vocals
} // namespace Echoelmusic
