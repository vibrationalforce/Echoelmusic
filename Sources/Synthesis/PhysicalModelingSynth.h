#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <cmath>
#include <memory>
#include <random>

/**
 * PhysicalModelingSynth - Waveguide-Based Physical Modeling Synthesizer
 *
 * Models:
 * - Karplus-Strong string synthesis
 * - Digital waveguide strings (guitar, piano, harp)
 * - Bowed string model
 * - Wind instruments (flute, clarinet)
 * - Percussion (bars, membranes)
 * - Plucked strings with body resonance
 *
 * Inspired by: Yamaha VL1, Pianoteq, AAS instruments
 */

namespace Echoelmusic {
namespace Synthesis {

//==============================================================================
// Delay Line with Interpolation
//==============================================================================

class DelayLine
{
public:
    void setMaxDelay(int samples)
    {
        buffer.resize(samples + 1, 0.0f);
        clear();
    }

    void setDelay(float samples)
    {
        delaySamples = std::max(0.5f, std::min(samples, static_cast<float>(buffer.size()) - 1.0f));
    }

    void clear()
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
        writeIndex = 0;
    }

    void write(float sample)
    {
        buffer[writeIndex] = sample;
        writeIndex = (writeIndex + 1) % buffer.size();
    }

    float read() const
    {
        // Linear interpolation for fractional delay
        float readPos = static_cast<float>(writeIndex) - delaySamples;
        if (readPos < 0.0f)
            readPos += buffer.size();

        int idx0 = static_cast<int>(readPos);
        int idx1 = (idx0 + 1) % buffer.size();
        float frac = readPos - idx0;

        return buffer[idx0] * (1.0f - frac) + buffer[idx1] * frac;
    }

    float tap(float offset) const
    {
        float readPos = static_cast<float>(writeIndex) - offset;
        if (readPos < 0.0f)
            readPos += buffer.size();

        int idx = static_cast<int>(readPos) % buffer.size();
        return buffer[idx];
    }

private:
    std::vector<float> buffer;
    int writeIndex = 0;
    float delaySamples = 100.0f;
};

//==============================================================================
// One-Pole Filter
//==============================================================================

class OnePoleFilter
{
public:
    void setCoefficient(float coeff)
    {
        a = juce::jlimit(0.0f, 0.9999f, coeff);
    }

    void setCutoff(float frequency, double sampleRate)
    {
        float w = 2.0f * juce::MathConstants<float>::pi * frequency / static_cast<float>(sampleRate);
        a = std::exp(-w);
    }

    float process(float input)
    {
        z = input * (1.0f - a) + z * a;
        return z;
    }

    void reset()
    {
        z = 0.0f;
    }

private:
    float a = 0.5f;
    float z = 0.0f;
};

//==============================================================================
// Allpass Interpolation Filter
//==============================================================================

class AllpassInterpolator
{
public:
    void setCoefficient(float coeff)
    {
        a = juce::jlimit(-0.999f, 0.999f, coeff);
    }

    float process(float input)
    {
        float output = a * input + z1 - a * y1;
        z1 = input;
        y1 = output;
        return output;
    }

    void reset()
    {
        z1 = y1 = 0.0f;
    }

private:
    float a = 0.0f;
    float z1 = 0.0f;
    float y1 = 0.0f;
};

//==============================================================================
// Karplus-Strong String
//==============================================================================

class KarplusStrongString
{
public:
    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        delayLine.setMaxDelay(static_cast<int>(sampleRate / 20.0)); // Down to ~20 Hz
        loopFilter.reset();
    }

    void pluck(float frequency, float brightness, float amplitude)
    {
        // Set delay for pitch
        float delaySamples = static_cast<float>(currentSampleRate) / frequency;
        delayLine.setDelay(delaySamples - 0.5f);  // Compensate for filter delay
        delayLine.clear();

        // Set damping based on brightness
        float cutoff = 1000.0f + brightness * 15000.0f;
        loopFilter.setCutoff(cutoff, currentSampleRate);

        // Fill delay with noise burst
        int burstLength = static_cast<int>(delaySamples);
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_real_distribution<float> dist(-amplitude, amplitude);

        for (int i = 0; i < burstLength; ++i)
        {
            delayLine.write(dist(gen));
        }

        isPlaying = true;
        energy = amplitude;
    }

    float process()
    {
        if (!isPlaying)
            return 0.0f;

        // Read from delay line
        float output = delayLine.read();

        // Energy tracking for voice stealing
        energy = energy * 0.9999f + std::abs(output) * 0.0001f;
        if (energy < 0.0001f)
            isPlaying = false;

        // Filter for damping
        float filtered = loopFilter.process(output);

        // Averaging for Karplus-Strong
        float averaged = 0.5f * (filtered + lastSample);
        lastSample = filtered;

        // Write back with slight decay
        delayLine.write(averaged * decay);

        return output;
    }

    void setDecay(float d)
    {
        decay = juce::jlimit(0.9f, 0.9999f, d);
    }

    bool isActive() const { return isPlaying; }
    float getEnergy() const { return energy; }

private:
    double currentSampleRate = 48000.0;
    DelayLine delayLine;
    OnePoleFilter loopFilter;

    bool isPlaying = false;
    float lastSample = 0.0f;
    float decay = 0.995f;
    float energy = 0.0f;
};

//==============================================================================
// Bowed String Model
//==============================================================================

class BowedString
{
public:
    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;

        // Bidirectional delay lines for standing wave
        int maxDelay = static_cast<int>(sampleRate / 20.0);
        neckDelay.setMaxDelay(maxDelay);
        bridgeDelay.setMaxDelay(maxDelay);

        neckFilter.reset();
        bridgeFilter.reset();
    }

    void setFrequency(float frequency)
    {
        float totalDelay = static_cast<float>(currentSampleRate) / frequency;

        // Split delay between neck and bridge
        float neckRatio = 0.9f - bowPosition * 0.8f;  // Bow position affects split
        neckDelay.setDelay(totalDelay * neckRatio);
        bridgeDelay.setDelay(totalDelay * (1.0f - neckRatio));
    }

    void bow(float frequency, float pressure, float vel)
    {
        setFrequency(frequency);
        bowPressure = juce::jlimit(0.0f, 1.0f, pressure);
        bowVelocity = vel;
        isPlaying = true;
    }

    void release()
    {
        isPlaying = false;
    }

    void setBowPosition(float position)
    {
        bowPosition = juce::jlimit(0.1f, 0.9f, position);
    }

    void setBrightness(float brightness)
    {
        float cutoff = 1000.0f + brightness * 10000.0f;
        neckFilter.setCutoff(cutoff, currentSampleRate);
        bridgeFilter.setCutoff(cutoff * 0.8f, currentSampleRate);
    }

    float process()
    {
        // Read from delay lines
        float fromNeck = neckDelay.read();
        float fromBridge = bridgeDelay.read();

        // String velocity at bow point
        float stringVelocity = fromNeck - fromBridge;

        // Bow-string interaction
        float deltaV = bowVelocity - stringVelocity;
        float bowForce = 0.0f;

        if (isPlaying && bowPressure > 0.0f)
        {
            // Friction model (simplified)
            float stickSlipThreshold = 0.3f * bowPressure;

            if (std::abs(deltaV) < stickSlipThreshold)
            {
                // Stick phase
                bowForce = deltaV * bowPressure * 2.0f;
            }
            else
            {
                // Slip phase
                float sign = deltaV > 0.0f ? 1.0f : -1.0f;
                bowForce = sign * stickSlipThreshold * 0.4f;
            }
        }

        // Inject bow force into string
        float toNeck = fromBridge + bowForce * 0.5f;
        float toBridge = fromNeck + bowForce * 0.5f;

        // Apply filtering (damping)
        toNeck = neckFilter.process(toNeck);
        toBridge = bridgeFilter.process(toBridge);

        // Reflections at terminations (inverted)
        neckDelay.write(-toNeck * neckReflection);
        bridgeDelay.write(-toBridge * bridgeReflection);

        // Output is the bridge velocity (what the body would "hear")
        return toBridge;
    }

    bool isActive() const { return isPlaying || std::abs(bridgeDelay.read()) > 0.0001f; }

private:
    double currentSampleRate = 48000.0;

    DelayLine neckDelay;
    DelayLine bridgeDelay;
    OnePoleFilter neckFilter;
    OnePoleFilter bridgeFilter;

    float bowPosition = 0.1f;
    float bowPressure = 0.5f;
    float bowVelocity = 0.3f;
    float neckReflection = 0.98f;
    float bridgeReflection = 0.97f;
    bool isPlaying = false;
};

//==============================================================================
// Wind Instrument Model (Flute/Clarinet)
//==============================================================================

class WindInstrument
{
public:
    enum class Type
    {
        Flute,
        Clarinet,
        Saxophone
    };

    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        int maxDelay = static_cast<int>(sampleRate / 50.0);
        boreDelay.setMaxDelay(maxDelay);
        embouchureDelay.setMaxDelay(maxDelay / 4);
        toneHoleFilter.reset();
    }

    void setType(Type t)
    {
        type = t;

        switch (type)
        {
            case Type::Flute:
                reedStiffness = 0.0f;  // No reed
                toneHoleCutoff = 2000.0f;
                endReflection = -0.7f;  // Open end
                break;

            case Type::Clarinet:
                reedStiffness = 0.5f;
                toneHoleCutoff = 1500.0f;
                endReflection = 0.9f;  // Closed end (odd harmonics)
                break;

            case Type::Saxophone:
                reedStiffness = 0.4f;
                toneHoleCutoff = 2500.0f;
                endReflection = -0.8f;  // Open cone
                break;
        }
    }

    void setFrequency(float frequency)
    {
        float delaySamples = static_cast<float>(currentSampleRate) / frequency;

        if (type == Type::Clarinet)
            delaySamples *= 2.0f;  // Closed pipe is half wavelength

        boreDelay.setDelay(delaySamples * 0.7f);
        embouchureDelay.setDelay(delaySamples * 0.1f);
    }

    void blow(float frequency, float pressure)
    {
        setFrequency(frequency);
        breathPressure = juce::jlimit(0.0f, 1.0f, pressure);
        isPlaying = true;
    }

    void release()
    {
        isPlaying = false;
        breathPressure = 0.0f;
    }

    void setBreathNoise(float amount)
    {
        noiseAmount = juce::jlimit(0.0f, 1.0f, amount);
    }

    float process()
    {
        // Breath with optional noise
        float breath = breathPressure;
        if (noiseAmount > 0.0f && isPlaying)
        {
            static std::mt19937 gen(42);
            static std::uniform_real_distribution<float> dist(-1.0f, 1.0f);
            breath += dist(gen) * noiseAmount * 0.1f;
        }

        // Read from bore
        float boreReturn = boreDelay.read();

        // Excitation model
        float excitation = 0.0f;

        if (type == Type::Flute)
        {
            // Jet-drive model
            float jet = breath - boreReturn;
            float embReturn = embouchureDelay.read();
            float jetDeflection = std::tanh(jet * 2.0f + embReturn);
            excitation = jetDeflection * breathPressure;
            embouchureDelay.write(jet * 0.5f);
        }
        else
        {
            // Reed model
            float pressureDiff = breath - boreReturn;
            float reedDisplacement = pressureDiff * (1.0f - reedStiffness);
            reedDisplacement = juce::jlimit(-1.0f, 1.0f, reedDisplacement);

            // Reed opening (nonlinear)
            float reedOpening = std::max(0.0f, 1.0f - reedDisplacement);
            excitation = reedOpening * pressureDiff;
        }

        // Bore propagation with tone hole filtering
        float filtered = toneHoleFilter.process(excitation);
        boreDelay.write(filtered);

        // Output with end reflection
        float output = boreReturn + excitation * 0.3f;

        // Bell radiation
        output = bellFilter.process(output);

        return output * 0.5f;
    }

    bool isActive() const { return isPlaying || std::abs(boreDelay.read()) > 0.0001f; }

private:
    double currentSampleRate = 48000.0;
    Type type = Type::Clarinet;

    DelayLine boreDelay;
    DelayLine embouchureDelay;
    OnePoleFilter toneHoleFilter;
    OnePoleFilter bellFilter;

    float breathPressure = 0.0f;
    float reedStiffness = 0.5f;
    float noiseAmount = 0.1f;
    float toneHoleCutoff = 1500.0f;
    float endReflection = 0.9f;
    bool isPlaying = false;
};

//==============================================================================
// Struck/Plucked Bar (Xylophone, Vibraphone)
//==============================================================================

class StruckBar
{
public:
    static constexpr int NumModes = 4;

    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        for (auto& filter : modeFilters)
            filter.reset();
    }

    void strike(float frequency, float hardness, float velocity)
    {
        fundamentalFreq = frequency;

        // Modal frequencies for a bar
        // Ratios: 1.0, 2.76, 5.40, 8.93 (ideal uniform bar)
        modeFrequencies[0] = frequency;
        modeFrequencies[1] = frequency * 2.76f;
        modeFrequencies[2] = frequency * 5.40f;
        modeFrequencies[3] = frequency * 8.93f;

        // Mode amplitudes based on strike position
        modeAmplitudes[0] = 1.0f;
        modeAmplitudes[1] = 0.7f * hardness;
        modeAmplitudes[2] = 0.4f * hardness;
        modeAmplitudes[3] = 0.2f * hardness;

        // Initialize mode phases
        for (int i = 0; i < NumModes; ++i)
        {
            modePhases[i] = 0.0f;
            modeDecays[i] = std::exp(-3.0f * static_cast<float>(i + 1) /
                                      static_cast<float>(currentSampleRate));
        }

        strikeVelocity = velocity;
        isPlaying = true;
        energy = velocity;
    }

    float process()
    {
        if (!isPlaying)
            return 0.0f;

        float output = 0.0f;

        for (int i = 0; i < NumModes; ++i)
        {
            // Generate mode
            float mode = std::sin(modePhases[i]) * modeAmplitudes[i];
            output += mode;

            // Advance phase
            modePhases[i] += 2.0f * juce::MathConstants<float>::pi *
                             modeFrequencies[i] / static_cast<float>(currentSampleRate);

            if (modePhases[i] > juce::MathConstants<float>::twoPi)
                modePhases[i] -= juce::MathConstants<float>::twoPi;

            // Decay
            modeAmplitudes[i] *= modeDecays[i];
        }

        output *= strikeVelocity;

        // Track energy
        energy = energy * 0.9999f + std::abs(output) * 0.0001f;
        if (energy < 0.0001f)
            isPlaying = false;

        return output;
    }

    void setDecay(float decay)
    {
        float d = juce::jlimit(0.99f, 0.99999f, decay);
        for (int i = 0; i < NumModes; ++i)
            modeDecays[i] = std::pow(d, static_cast<float>(i + 1));
    }

    bool isActive() const { return isPlaying; }

private:
    double currentSampleRate = 48000.0;

    std::array<float, NumModes> modeFrequencies{};
    std::array<float, NumModes> modeAmplitudes{};
    std::array<float, NumModes> modePhases{};
    std::array<float, NumModes> modeDecays{};
    std::array<OnePoleFilter, NumModes> modeFilters;

    float fundamentalFreq = 440.0f;
    float strikeVelocity = 1.0f;
    float energy = 0.0f;
    bool isPlaying = false;
};

//==============================================================================
// Body Resonator
//==============================================================================

class BodyResonator
{
public:
    static constexpr int NumResonances = 5;

    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        updateCoefficients();
    }

    void setBodyType(int type)
    {
        // Different body resonance profiles
        switch (type)
        {
            case 0:  // Guitar
                frequencies = { 100.0f, 200.0f, 400.0f, 800.0f, 1600.0f };
                bandwidths = { 50.0f, 60.0f, 80.0f, 100.0f, 150.0f };
                gains = { 1.0f, 0.8f, 0.5f, 0.3f, 0.2f };
                break;

            case 1:  // Violin
                frequencies = { 275.0f, 450.0f, 700.0f, 1200.0f, 2500.0f };
                bandwidths = { 40.0f, 50.0f, 70.0f, 100.0f, 150.0f };
                gains = { 1.0f, 0.9f, 0.6f, 0.4f, 0.25f };
                break;

            case 2:  // Piano
                frequencies = { 150.0f, 350.0f, 550.0f, 1100.0f, 2200.0f };
                bandwidths = { 80.0f, 100.0f, 120.0f, 150.0f, 200.0f };
                gains = { 0.8f, 0.6f, 0.5f, 0.4f, 0.3f };
                break;

            case 3:  // Acoustic box
                frequencies = { 80.0f, 180.0f, 300.0f, 600.0f, 1200.0f };
                bandwidths = { 30.0f, 50.0f, 70.0f, 100.0f, 150.0f };
                gains = { 1.2f, 1.0f, 0.7f, 0.4f, 0.2f };
                break;

            default:
                break;
        }

        updateCoefficients();
    }

    float process(float input)
    {
        float output = input * 0.3f;  // Direct sound

        for (int i = 0; i < NumResonances; ++i)
        {
            // Two-pole resonator
            float w = 2.0f * juce::MathConstants<float>::pi * frequencies[i] /
                      static_cast<float>(currentSampleRate);
            float r = 1.0f - bandwidths[i] * juce::MathConstants<float>::pi /
                             static_cast<float>(currentSampleRate);

            float y = input - r * r * states[i * 2 + 1];
            y = y + 2.0f * r * std::cos(w) * states[i * 2];
            y -= r * r * states[i * 2];

            states[i * 2 + 1] = states[i * 2];
            states[i * 2] = y;

            output += y * gains[i] * 0.15f;
        }

        return output;
    }

    void reset()
    {
        std::fill(states.begin(), states.end(), 0.0f);
    }

private:
    double currentSampleRate = 48000.0;

    std::array<float, NumResonances> frequencies = { 100.0f, 200.0f, 400.0f, 800.0f, 1600.0f };
    std::array<float, NumResonances> bandwidths = { 50.0f, 60.0f, 80.0f, 100.0f, 150.0f };
    std::array<float, NumResonances> gains = { 1.0f, 0.8f, 0.5f, 0.3f, 0.2f };
    std::array<float, NumResonances * 2> states{};

    void updateCoefficients()
    {
        // Coefficients are calculated inline in process()
    }
};

//==============================================================================
// Physical Modeling Voice
//==============================================================================

class PhysicalModelingVoice
{
public:
    enum class Model
    {
        PluckedString,
        BowedString,
        Flute,
        Clarinet,
        Xylophone,
        Marimba
    };

    PhysicalModelingVoice()
    {
        pluckedString = std::make_unique<KarplusStrongString>();
        bowedString = std::make_unique<BowedString>();
        wind = std::make_unique<WindInstrument>();
        bar = std::make_unique<StruckBar>();
        body = std::make_unique<BodyResonator>();
    }

    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        pluckedString->prepare(sampleRate);
        bowedString->prepare(sampleRate);
        wind->prepare(sampleRate);
        bar->prepare(sampleRate);
        body->prepare(sampleRate);
    }

    void setModel(Model m)
    {
        currentModel = m;

        switch (m)
        {
            case Model::PluckedString:
                body->setBodyType(0);  // Guitar body
                break;
            case Model::BowedString:
                body->setBodyType(1);  // Violin body
                break;
            case Model::Flute:
                wind->setType(WindInstrument::Type::Flute);
                break;
            case Model::Clarinet:
                wind->setType(WindInstrument::Type::Clarinet);
                break;
            case Model::Xylophone:
            case Model::Marimba:
                body->setBodyType(3);  // Resonator
                break;
        }
    }

    void noteOn(int midiNote, float velocity)
    {
        currentNote = midiNote;
        float frequency = 440.0f * std::pow(2.0f, (midiNote - 69) / 12.0f);
        currentFrequency = frequency;

        switch (currentModel)
        {
            case Model::PluckedString:
                pluckedString->pluck(frequency, brightness, velocity);
                break;

            case Model::BowedString:
                bowedString->bow(frequency, velocity, velocity * 0.5f);
                break;

            case Model::Flute:
            case Model::Clarinet:
                wind->blow(frequency, velocity);
                break;

            case Model::Xylophone:
                bar->strike(frequency, 0.8f, velocity);
                break;

            case Model::Marimba:
                bar->strike(frequency, 0.4f, velocity);
                bar->setDecay(0.9995f);
                break;
        }

        isActive = true;
    }

    void noteOff()
    {
        switch (currentModel)
        {
            case Model::BowedString:
                bowedString->release();
                break;

            case Model::Flute:
            case Model::Clarinet:
                wind->release();
                break;

            default:
                // Plucked/struck continue to ring out
                break;
        }
    }

    void setBrightness(float b)
    {
        brightness = juce::jlimit(0.0f, 1.0f, b);
        bowedString->setBrightness(b);
    }

    void setBodyResonance(float amount)
    {
        bodyMix = juce::jlimit(0.0f, 1.0f, amount);
    }

    float process()
    {
        if (!isActive)
            return 0.0f;

        float sample = 0.0f;

        switch (currentModel)
        {
            case Model::PluckedString:
                sample = pluckedString->process();
                isActive = pluckedString->isActive();
                break;

            case Model::BowedString:
                sample = bowedString->process();
                isActive = bowedString->isActive();
                break;

            case Model::Flute:
            case Model::Clarinet:
                sample = wind->process();
                isActive = wind->isActive();
                break;

            case Model::Xylophone:
            case Model::Marimba:
                sample = bar->process();
                isActive = bar->isActive();
                break;
        }

        // Apply body resonance
        if (bodyMix > 0.0f)
        {
            float bodied = body->process(sample);
            sample = sample * (1.0f - bodyMix) + bodied * bodyMix;
        }

        return sample;
    }

    bool isVoiceActive() const { return isActive; }
    int getCurrentNote() const { return currentNote; }

private:
    double currentSampleRate = 48000.0;
    Model currentModel = Model::PluckedString;

    std::unique_ptr<KarplusStrongString> pluckedString;
    std::unique_ptr<BowedString> bowedString;
    std::unique_ptr<WindInstrument> wind;
    std::unique_ptr<StruckBar> bar;
    std::unique_ptr<BodyResonator> body;

    int currentNote = 60;
    float currentFrequency = 440.0f;
    float brightness = 0.5f;
    float bodyMix = 0.5f;
    bool isActive = false;
};

//==============================================================================
// Physical Modeling Synthesizer (Main Class)
//==============================================================================

class PhysicalModelingSynth
{
public:
    static constexpr int MaxVoices = 8;

    using Model = PhysicalModelingVoice::Model;

    //==========================================================================
    // Presets
    //==========================================================================

    enum class Preset
    {
        AcousticGuitar,
        ElectricGuitar,
        ClassicalGuitar,
        Violin,
        Cello,
        Flute,
        Clarinet,
        Xylophone,
        Marimba,
        Kalimba
    };

    //==========================================================================
    // Constructor
    //==========================================================================

    PhysicalModelingSynth()
    {
        for (int i = 0; i < MaxVoices; ++i)
            voices[i] = std::make_unique<PhysicalModelingVoice>();
    }

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;

        for (auto& voice : voices)
            voice->prepare(sampleRate);

        loadPreset(Preset::AcousticGuitar);
    }

    //==========================================================================
    // Note Handling
    //==========================================================================

    void noteOn(int midiNote, float velocity)
    {
        int voiceIndex = findFreeVoice();

        if (voiceIndex >= 0)
        {
            voices[voiceIndex]->setModel(currentModel);
            voices[voiceIndex]->setBrightness(brightness);
            voices[voiceIndex]->setBodyResonance(bodyResonance);
            voices[voiceIndex]->noteOn(midiNote, velocity);
        }
    }

    void noteOff(int midiNote)
    {
        for (auto& voice : voices)
        {
            if (voice->isVoiceActive() && voice->getCurrentNote() == midiNote)
            {
                voice->noteOff();
            }
        }
    }

    void allNotesOff()
    {
        for (auto& voice : voices)
            voice->noteOff();
    }

    //==========================================================================
    // Parameters
    //==========================================================================

    void setModel(Model model)
    {
        currentModel = model;
    }

    void setBrightness(float b)
    {
        brightness = juce::jlimit(0.0f, 1.0f, b);
        for (auto& voice : voices)
            voice->setBrightness(brightness);
    }

    void setBodyResonance(float amount)
    {
        bodyResonance = juce::jlimit(0.0f, 1.0f, amount);
        for (auto& voice : voices)
            voice->setBodyResonance(bodyResonance);
    }

    void setMasterGain(float gain)
    {
        masterGain = juce::jlimit(0.0f, 2.0f, gain);
    }

    //==========================================================================
    // Presets
    //==========================================================================

    void loadPreset(Preset preset)
    {
        currentPreset = preset;

        switch (preset)
        {
            case Preset::AcousticGuitar:
                setModel(Model::PluckedString);
                setBrightness(0.6f);
                setBodyResonance(0.7f);
                break;

            case Preset::ElectricGuitar:
                setModel(Model::PluckedString);
                setBrightness(0.8f);
                setBodyResonance(0.2f);
                break;

            case Preset::ClassicalGuitar:
                setModel(Model::PluckedString);
                setBrightness(0.4f);
                setBodyResonance(0.6f);
                break;

            case Preset::Violin:
                setModel(Model::BowedString);
                setBrightness(0.7f);
                setBodyResonance(0.8f);
                break;

            case Preset::Cello:
                setModel(Model::BowedString);
                setBrightness(0.5f);
                setBodyResonance(0.9f);
                break;

            case Preset::Flute:
                setModel(Model::Flute);
                setBrightness(0.8f);
                setBodyResonance(0.1f);
                break;

            case Preset::Clarinet:
                setModel(Model::Clarinet);
                setBrightness(0.5f);
                setBodyResonance(0.15f);
                break;

            case Preset::Xylophone:
                setModel(Model::Xylophone);
                setBrightness(0.9f);
                setBodyResonance(0.3f);
                break;

            case Preset::Marimba:
                setModel(Model::Marimba);
                setBrightness(0.4f);
                setBodyResonance(0.6f);
                break;

            case Preset::Kalimba:
                setModel(Model::PluckedString);
                setBrightness(0.7f);
                setBodyResonance(0.4f);
                break;
        }
    }

    //==========================================================================
    // Processing
    //==========================================================================

    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
    {
        // Handle MIDI
        for (const auto metadata : midiMessages)
        {
            auto message = metadata.getMessage();

            if (message.isNoteOn())
                noteOn(message.getNoteNumber(), message.getFloatVelocity());
            else if (message.isNoteOff())
                noteOff(message.getNoteNumber());
            else if (message.isAllNotesOff() || message.isAllSoundOff())
                allNotesOff();
        }

        // Clear buffer
        buffer.clear();

        int numSamples = buffer.getNumSamples();

        // Process voices
        for (int i = 0; i < numSamples; ++i)
        {
            float sample = 0.0f;

            for (auto& voice : voices)
            {
                if (voice->isVoiceActive())
                {
                    sample += voice->process();
                }
            }

            sample *= masterGain;

            buffer.addSample(0, i, sample);
            if (buffer.getNumChannels() > 1)
                buffer.addSample(1, i, sample);
        }
    }

    //==========================================================================
    // Getters
    //==========================================================================

    Preset getCurrentPreset() const { return currentPreset; }
    Model getCurrentModel() const { return currentModel; }

    int getActiveVoiceCount() const
    {
        int count = 0;
        for (const auto& voice : voices)
            if (voice->isVoiceActive())
                ++count;
        return count;
    }

private:
    double currentSampleRate = 48000.0;

    std::array<std::unique_ptr<PhysicalModelingVoice>, MaxVoices> voices;

    Preset currentPreset = Preset::AcousticGuitar;
    Model currentModel = Model::PluckedString;
    float brightness = 0.5f;
    float bodyResonance = 0.5f;
    float masterGain = 0.5f;

    int findFreeVoice() const
    {
        for (int i = 0; i < MaxVoices; ++i)
        {
            if (!voices[i]->isVoiceActive())
                return i;
        }
        return 0;  // Steal first voice
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PhysicalModelingSynth)
};

} // namespace Synthesis
} // namespace Echoelmusic
