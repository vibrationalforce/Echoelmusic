#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <cmath>
#include <memory>

/**
 * GuitarAmpSimulator - Professional Guitar Amplifier & Cabinet Simulation
 *
 * Complete signal chain:
 * - Input conditioning (noise gate, compression)
 * - Preamp with tube-style saturation
 * - 3-band tone stack (Fender/Marshall/Vox styles)
 * - Power amp simulation with sag
 * - Cabinet impulse response simulation
 * - Microphone position modeling
 *
 * Amp Models: Clean, Crunch, British, High Gain, Modern Metal
 * Cabinet Models: 1x12, 2x12, 4x12 with various speaker types
 *
 * Inspired by: Marshall, Fender, Mesa Boogie, Orange, Vox
 */

namespace Echoelmusic {
namespace DSP {

//==============================================================================
// Tube Stage Simulation
//==============================================================================

class TubeStage
{
public:
    enum class TubeType
    {
        ECC83_12AX7,   // High gain preamp tube
        ECC82_12AU7,   // Medium gain
        ECC81_12AT7,   // Lower gain, higher headroom
        EL34,          // British power tube
        EL84,          // Vox-style power
        SIX_L6,        // American power tube
        KT88           // High power, clean headroom
    };

    void setTubeType(TubeType type)
    {
        tubeType = type;
        updateCharacteristics();
    }

    void setDrive(float drive)
    {
        driveAmount = juce::jlimit(0.0f, 1.0f, drive);
    }

    void setBias(float bias)
    {
        tubeBias = juce::jlimit(-0.5f, 0.5f, bias);
    }

    float process(float input)
    {
        // Apply input gain
        float x = input * (1.0f + driveAmount * 10.0f);

        // DC offset for asymmetric clipping
        x += tubeBias * 0.1f;

        // Tube saturation model
        float output;
        switch (tubeType)
        {
            case TubeType::ECC83_12AX7:
                output = processHighGainTriode(x);
                break;
            case TubeType::ECC82_12AU7:
                output = processMediumGainTriode(x);
                break;
            case TubeType::ECC81_12AT7:
                output = processCleanTriode(x);
                break;
            case TubeType::EL34:
            case TubeType::EL84:
            case TubeType::SIX_L6:
            case TubeType::KT88:
                output = processPowerTube(x);
                break;
            default:
                output = processHighGainTriode(x);
        }

        // Remove DC offset
        dcBlockerState = dcBlockerState * 0.995f + output * 0.005f;
        output -= dcBlockerState;

        return output;
    }

    void reset()
    {
        dcBlockerState = 0.0f;
    }

private:
    TubeType tubeType = TubeType::ECC83_12AX7;
    float driveAmount = 0.5f;
    float tubeBias = 0.0f;
    float dcBlockerState = 0.0f;

    // Tube characteristics
    float mu = 100.0f;           // Amplification factor
    float plateResistance = 1.0f;
    float gridCurrent = 0.0f;

    void updateCharacteristics()
    {
        switch (tubeType)
        {
            case TubeType::ECC83_12AX7:
                mu = 100.0f;
                plateResistance = 0.8f;
                break;
            case TubeType::ECC82_12AU7:
                mu = 17.0f;
                plateResistance = 0.5f;
                break;
            case TubeType::ECC81_12AT7:
                mu = 60.0f;
                plateResistance = 0.6f;
                break;
            case TubeType::EL34:
                mu = 11.0f;
                plateResistance = 0.3f;
                break;
            case TubeType::EL84:
                mu = 25.0f;
                plateResistance = 0.4f;
                break;
            case TubeType::SIX_L6:
                mu = 8.0f;
                plateResistance = 0.25f;
                break;
            case TubeType::KT88:
                mu = 7.0f;
                plateResistance = 0.2f;
                break;
        }
    }

    float processHighGainTriode(float x)
    {
        // Asymmetric soft clipping with harmonics
        float y;
        if (x >= 0.0f)
        {
            y = std::tanh(x * 1.5f);
        }
        else
        {
            // Softer negative clipping (tube characteristic)
            y = std::tanh(x * 1.2f) * 1.1f;
        }

        // Add even harmonics
        y += 0.1f * driveAmount * y * y;

        return y;
    }

    float processMediumGainTriode(float x)
    {
        // Gentler saturation
        float y = x / (1.0f + std::abs(x) * 0.5f);

        // Slight even harmonic coloration
        y += 0.05f * driveAmount * y * y;

        return y;
    }

    float processCleanTriode(float x)
    {
        // Very gentle saturation, mostly clean
        float threshold = 0.8f;
        float y;

        if (std::abs(x) < threshold)
        {
            y = x;
        }
        else
        {
            float sign = x > 0.0f ? 1.0f : -1.0f;
            float excess = std::abs(x) - threshold;
            y = sign * (threshold + std::tanh(excess * 2.0f) * 0.2f);
        }

        return y;
    }

    float processPowerTube(float x)
    {
        // Push-pull power tube saturation
        float y = std::tanh(x);

        // Crossover distortion simulation at low levels
        float crossover = 0.02f * (1.0f - driveAmount);
        if (std::abs(y) < crossover)
        {
            y *= std::abs(y) / crossover;
        }

        // Power sag simulation
        static float sagState = 0.0f;
        sagState = sagState * 0.99f + std::abs(y) * 0.01f;
        float sag = 1.0f - sagState * driveAmount * 0.2f;
        y *= sag;

        return y;
    }
};

//==============================================================================
// Tone Stack (EQ)
//==============================================================================

class ToneStack
{
public:
    enum class StackType
    {
        Fender,     // Classic American scooped mids
        Marshall,   // British mid-focused
        Vox,        // AC30 style bright
        Mesa,       // Modern high gain
        Flat        // Bypass/neutral
    };

    void setType(StackType type)
    {
        stackType = type;
        recalculateCoefficients();
    }

    void setBass(float level)
    {
        bass = juce::jlimit(0.0f, 1.0f, level);
        recalculateCoefficients();
    }

    void setMid(float level)
    {
        mid = juce::jlimit(0.0f, 1.0f, level);
        recalculateCoefficients();
    }

    void setTreble(float level)
    {
        treble = juce::jlimit(0.0f, 1.0f, level);
        recalculateCoefficients();
    }

    void setPresence(float level)
    {
        presence = juce::jlimit(0.0f, 1.0f, level);
        recalculateCoefficients();
    }

    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        recalculateCoefficients();
        reset();
    }

    void reset()
    {
        std::fill(lowState.begin(), lowState.end(), 0.0f);
        std::fill(midState.begin(), midState.end(), 0.0f);
        std::fill(highState.begin(), highState.end(), 0.0f);
        std::fill(presenceState.begin(), presenceState.end(), 0.0f);
    }

    float process(float input)
    {
        if (stackType == StackType::Flat)
            return input;

        // Low shelf
        float low = processLowShelf(input);

        // Mid band
        float midBand = processMidBand(input);

        // High shelf
        float high = processHighShelf(input);

        // Presence (very high shelf)
        float pres = processPresence(input);

        // Mix based on stack type
        float output;
        switch (stackType)
        {
            case StackType::Fender:
                output = low * bassGain + midBand * midGain * 0.7f +
                         high * trebleGain + pres * presenceGain;
                break;

            case StackType::Marshall:
                output = low * bassGain * 0.9f + midBand * midGain * 1.2f +
                         high * trebleGain + pres * presenceGain;
                break;

            case StackType::Vox:
                output = low * bassGain * 0.8f + midBand * midGain +
                         high * trebleGain * 1.3f + pres * presenceGain * 1.2f;
                break;

            case StackType::Mesa:
                output = low * bassGain * 1.1f + midBand * midGain * 0.9f +
                         high * trebleGain * 1.1f + pres * presenceGain;
                break;

            default:
                output = input;
        }

        return output;
    }

private:
    StackType stackType = StackType::Marshall;
    double currentSampleRate = 48000.0;

    float bass = 0.5f;
    float mid = 0.5f;
    float treble = 0.5f;
    float presence = 0.5f;

    float bassGain = 1.0f;
    float midGain = 1.0f;
    float trebleGain = 1.0f;
    float presenceGain = 1.0f;

    // Filter states
    std::array<float, 2> lowState{};
    std::array<float, 2> midState{};
    std::array<float, 2> highState{};
    std::array<float, 2> presenceState{};

    // Filter coefficients
    float lowA1 = 0.0f, lowB0 = 1.0f, lowB1 = 0.0f;
    float midA1 = 0.0f, midA2 = 0.0f, midB0 = 1.0f, midB1 = 0.0f, midB2 = 0.0f;
    float highA1 = 0.0f, highB0 = 1.0f, highB1 = 0.0f;
    float presA1 = 0.0f, presB0 = 1.0f, presB1 = 0.0f;

    void recalculateCoefficients()
    {
        // Calculate gains from control positions
        bassGain = 0.2f + bass * 1.6f;
        midGain = 0.2f + mid * 1.6f;
        trebleGain = 0.2f + treble * 1.6f;
        presenceGain = 0.2f + presence * 1.6f;

        // Calculate filter coefficients based on stack type
        float lowFreq, midFreq, midQ, highFreq, presFreq;

        switch (stackType)
        {
            case StackType::Fender:
                lowFreq = 80.0f;
                midFreq = 500.0f;
                midQ = 0.7f;
                highFreq = 2500.0f;
                presFreq = 5000.0f;
                break;

            case StackType::Marshall:
                lowFreq = 100.0f;
                midFreq = 800.0f;
                midQ = 0.9f;
                highFreq = 2200.0f;
                presFreq = 4500.0f;
                break;

            case StackType::Vox:
                lowFreq = 90.0f;
                midFreq = 700.0f;
                midQ = 0.8f;
                highFreq = 3000.0f;
                presFreq = 6000.0f;
                break;

            case StackType::Mesa:
                lowFreq = 120.0f;
                midFreq = 650.0f;
                midQ = 1.2f;
                highFreq = 2800.0f;
                presFreq = 5500.0f;
                break;

            default:
                lowFreq = 100.0f;
                midFreq = 700.0f;
                midQ = 0.7f;
                highFreq = 2500.0f;
                presFreq = 5000.0f;
        }

        // One-pole lowpass for bass
        float wLow = 2.0f * juce::MathConstants<float>::pi * lowFreq /
                     static_cast<float>(currentSampleRate);
        lowA1 = std::exp(-wLow);
        lowB0 = 1.0f - lowA1;
        lowB1 = 0.0f;

        // One-pole highpass for treble
        float wHigh = 2.0f * juce::MathConstants<float>::pi * highFreq /
                      static_cast<float>(currentSampleRate);
        highA1 = std::exp(-wHigh);
        highB0 = (1.0f + highA1) * 0.5f;
        highB1 = -highB0;

        // Simple resonant bandpass for mids
        float wMid = 2.0f * juce::MathConstants<float>::pi * midFreq /
                     static_cast<float>(currentSampleRate);
        float alpha = std::sin(wMid) / (2.0f * midQ);
        float a0 = 1.0f + alpha;
        midB0 = alpha / a0;
        midB1 = 0.0f;
        midB2 = -alpha / a0;
        midA1 = -2.0f * std::cos(wMid) / a0;
        midA2 = (1.0f - alpha) / a0;

        // Presence shelf
        float wPres = 2.0f * juce::MathConstants<float>::pi * presFreq /
                      static_cast<float>(currentSampleRate);
        presA1 = std::exp(-wPres);
        presB0 = (1.0f + presA1) * 0.5f;
        presB1 = -presB0;
    }

    float processLowShelf(float input)
    {
        float output = lowB0 * input + lowState[0];
        lowState[0] = lowB1 * input + lowA1 * output;
        return output;
    }

    float processMidBand(float input)
    {
        float output = midB0 * input + midState[0];
        midState[0] = midB1 * input - midA1 * output + midState[1];
        midState[1] = midB2 * input - midA2 * output;
        return output;
    }

    float processHighShelf(float input)
    {
        float output = highB0 * input + highB1 * highState[0];
        highState[0] = input;
        float hp = input - output;
        return hp;
    }

    float processPresence(float input)
    {
        float output = presB0 * input + presB1 * presenceState[0];
        presenceState[0] = input;
        float hp = input - output;
        return hp;
    }
};

//==============================================================================
// Cabinet Impulse Response
//==============================================================================

class CabinetSimulator
{
public:
    enum class CabinetType
    {
        Combo_1x12_American,    // Fender style
        Combo_2x12_British,     // Vox AC30
        Stack_4x12_British,     // Marshall 1960
        Stack_4x12_American,    // Mesa Rectifier
        Open_1x12_Vintage,      // Tweed style
        Closed_2x12_Modern,     // Modern high gain
        Bass_4x10,              // Ampeg style
        Bass_1x15               // Classic bass
    };

    enum class MicPosition
    {
        OnAxis_Close,
        OffAxis_Close,
        OnAxis_Room,
        OffAxis_Room,
        Blended
    };

    void setCabinet(CabinetType type)
    {
        cabinetType = type;
        generateIR();
    }

    void setMicPosition(MicPosition pos)
    {
        micPosition = pos;
        generateIR();
    }

    void setMicDistance(float distance)
    {
        micDistance = juce::jlimit(0.0f, 1.0f, distance);
        generateIR();
    }

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;
        blockSize = maxBlockSize;
        generateIR();
        reset();
    }

    void reset()
    {
        std::fill(irBuffer.begin(), irBuffer.end(), 0.0f);
        irIndex = 0;
    }

    float process(float input)
    {
        // Store input in circular buffer
        inputBuffer[irIndex] = input;

        // Convolve with IR
        float output = 0.0f;
        int readIdx = irIndex;

        for (size_t i = 0; i < impulseResponse.size(); ++i)
        {
            output += inputBuffer[readIdx] * impulseResponse[i];
            readIdx = (readIdx - 1 + inputBuffer.size()) % inputBuffer.size();
        }

        irIndex = (irIndex + 1) % inputBuffer.size();

        return output;
    }

private:
    CabinetType cabinetType = CabinetType::Stack_4x12_British;
    MicPosition micPosition = MicPosition::OnAxis_Close;
    float micDistance = 0.3f;

    double currentSampleRate = 48000.0;
    int blockSize = 512;

    static constexpr int MaxIRLength = 2048;
    std::array<float, MaxIRLength> impulseResponse{};
    std::array<float, MaxIRLength> inputBuffer{};
    std::array<float, MaxIRLength> irBuffer{};
    int irIndex = 0;
    int irLength = 512;

    void generateIR()
    {
        // Generate synthetic cabinet impulse response
        // In production, this would load actual measured IRs

        std::fill(impulseResponse.begin(), impulseResponse.end(), 0.0f);

        // Get cabinet characteristics
        float resonance, highRolloff, lowRolloff, roomAmount;
        getCabinetCharacteristics(resonance, highRolloff, lowRolloff, roomAmount);

        // Generate main speaker response
        irLength = static_cast<int>(0.02 * currentSampleRate); // 20ms
        irLength = std::min(irLength, MaxIRLength - 1);

        for (int i = 0; i < irLength; ++i)
        {
            float t = static_cast<float>(i) / static_cast<float>(currentSampleRate);

            // Initial transient
            float transient = std::exp(-t * 200.0f) * std::sin(2.0f * juce::MathConstants<float>::pi * resonance * t);

            // Resonance decay
            float resDecay = std::exp(-t * 80.0f) * std::sin(2.0f * juce::MathConstants<float>::pi * (resonance * 0.5f) * t) * 0.5f;

            // Room reflections
            float room = 0.0f;
            if (i > static_cast<int>(0.002 * currentSampleRate))
            {
                float roomT = t - 0.002f;
                room = std::exp(-roomT * 50.0f) * roomAmount * 0.3f;
            }

            impulseResponse[i] = (transient + resDecay + room);

            // Apply frequency shaping
            float hfDecay = std::exp(-t * highRolloff);
            impulseResponse[i] *= hfDecay;
        }

        // Apply microphone position effects
        applyMicPosition();

        // Normalize
        float maxVal = 0.0f;
        for (int i = 0; i < irLength; ++i)
            maxVal = std::max(maxVal, std::abs(impulseResponse[i]));

        if (maxVal > 0.0f)
        {
            for (int i = 0; i < irLength; ++i)
                impulseResponse[i] /= maxVal;
        }
    }

    void getCabinetCharacteristics(float& resonance, float& highRolloff,
                                    float& lowRolloff, float& roomAmount)
    {
        switch (cabinetType)
        {
            case CabinetType::Combo_1x12_American:
                resonance = 100.0f;
                highRolloff = 300.0f;
                lowRolloff = 80.0f;
                roomAmount = 0.4f;
                break;

            case CabinetType::Combo_2x12_British:
                resonance = 90.0f;
                highRolloff = 250.0f;
                lowRolloff = 70.0f;
                roomAmount = 0.5f;
                break;

            case CabinetType::Stack_4x12_British:
                resonance = 80.0f;
                highRolloff = 200.0f;
                lowRolloff = 60.0f;
                roomAmount = 0.6f;
                break;

            case CabinetType::Stack_4x12_American:
                resonance = 85.0f;
                highRolloff = 180.0f;
                lowRolloff = 50.0f;
                roomAmount = 0.5f;
                break;

            case CabinetType::Open_1x12_Vintage:
                resonance = 120.0f;
                highRolloff = 350.0f;
                lowRolloff = 100.0f;
                roomAmount = 0.6f;
                break;

            case CabinetType::Closed_2x12_Modern:
                resonance = 75.0f;
                highRolloff = 150.0f;
                lowRolloff = 45.0f;
                roomAmount = 0.3f;
                break;

            case CabinetType::Bass_4x10:
                resonance = 60.0f;
                highRolloff = 400.0f;
                lowRolloff = 40.0f;
                roomAmount = 0.4f;
                break;

            case CabinetType::Bass_1x15:
                resonance = 50.0f;
                highRolloff = 500.0f;
                lowRolloff = 35.0f;
                roomAmount = 0.5f;
                break;

            default:
                resonance = 80.0f;
                highRolloff = 200.0f;
                lowRolloff = 60.0f;
                roomAmount = 0.5f;
        }
    }

    void applyMicPosition()
    {
        float hfBoost = 1.0f;
        float phaseOffset = 0;
        float roomMix = 0.0f;

        switch (micPosition)
        {
            case MicPosition::OnAxis_Close:
                hfBoost = 1.2f;
                phaseOffset = 0;
                roomMix = 0.1f;
                break;

            case MicPosition::OffAxis_Close:
                hfBoost = 0.7f;
                phaseOffset = 2;
                roomMix = 0.15f;
                break;

            case MicPosition::OnAxis_Room:
                hfBoost = 0.9f;
                phaseOffset = static_cast<int>(0.003 * currentSampleRate);
                roomMix = 0.4f;
                break;

            case MicPosition::OffAxis_Room:
                hfBoost = 0.6f;
                phaseOffset = static_cast<int>(0.004 * currentSampleRate);
                roomMix = 0.5f;
                break;

            case MicPosition::Blended:
                hfBoost = 1.0f;
                phaseOffset = 1;
                roomMix = 0.25f;
                break;
        }

        // Apply HF boost/cut
        float hfState = 0.0f;
        float hfCoeff = 0.3f;
        for (int i = 0; i < irLength; ++i)
        {
            float hf = impulseResponse[i] - hfState;
            hfState = hfState * (1.0f - hfCoeff) + impulseResponse[i] * hfCoeff;
            impulseResponse[i] = hfState + hf * (hfBoost - 1.0f) * 0.5f;
        }

        // Apply distance effect
        float distanceAttenuation = 1.0f / (1.0f + micDistance * 2.0f);
        for (int i = 0; i < irLength; ++i)
            impulseResponse[i] *= distanceAttenuation;
    }
};

//==============================================================================
// Noise Gate
//==============================================================================

class NoiseGate
{
public:
    void setThreshold(float thresholdDb)
    {
        threshold = std::pow(10.0f, thresholdDb / 20.0f);
    }

    void setAttack(float ms)
    {
        attackMs = juce::jlimit(0.1f, 100.0f, ms);
    }

    void setRelease(float ms)
    {
        releaseMs = juce::jlimit(1.0f, 1000.0f, ms);
    }

    void setRange(float rangeDb)
    {
        range = std::pow(10.0f, juce::jlimit(-80.0f, 0.0f, rangeDb) / 20.0f);
    }

    void prepare(double sampleRate)
    {
        currentSampleRate = sampleRate;
        attackCoeff = std::exp(-1.0f / (attackMs * 0.001f * static_cast<float>(sampleRate)));
        releaseCoeff = std::exp(-1.0f / (releaseMs * 0.001f * static_cast<float>(sampleRate)));
    }

    float process(float input)
    {
        float inputLevel = std::abs(input);

        // Envelope follower
        if (inputLevel > envelope)
            envelope = attackCoeff * envelope + (1.0f - attackCoeff) * inputLevel;
        else
            envelope = releaseCoeff * envelope + (1.0f - releaseCoeff) * inputLevel;

        // Gate
        float gain;
        if (envelope > threshold)
        {
            gain = 1.0f;
        }
        else
        {
            float ratio = envelope / threshold;
            gain = range + (1.0f - range) * ratio * ratio;
        }

        return input * gain;
    }

    void reset()
    {
        envelope = 0.0f;
    }

private:
    float threshold = 0.01f;
    float range = 0.0f;
    float attackMs = 1.0f;
    float releaseMs = 100.0f;
    float attackCoeff = 0.9f;
    float releaseCoeff = 0.99f;
    float envelope = 0.0f;
    double currentSampleRate = 48000.0;
};

//==============================================================================
// Guitar Amp Simulator (Main Class)
//==============================================================================

class GuitarAmpSimulator
{
public:
    //==========================================================================
    // Amp Models
    //==========================================================================

    enum class AmpModel
    {
        Clean_American,     // Fender Twin style
        Clean_British,      // Vox AC30 clean
        Crunch_British,     // Marshall JCM800
        High_Gain_British,  // Marshall JVM
        High_Gain_American, // Mesa Rectifier
        Modern_Metal,       // Djent/Modern
        Vintage_Tweed,      // Fender Tweed
        Bass_Classic,       // Ampeg SVT style
        Bass_Modern         // Modern bass amp
    };

    //==========================================================================
    // Constructor
    //==========================================================================

    GuitarAmpSimulator()
    {
        for (int i = 0; i < NumPreampStages; ++i)
            preampStages[i] = std::make_unique<TubeStage>();

        powerAmp = std::make_unique<TubeStage>();
        toneStack = std::make_unique<ToneStack>();
        cabinet = std::make_unique<CabinetSimulator>();
        inputGate = std::make_unique<NoiseGate>();
    }

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;

        toneStack->prepare(sampleRate);
        cabinet->prepare(sampleRate, maxBlockSize);
        inputGate->prepare(sampleRate);
        inputGate->setThreshold(-50.0f);
        inputGate->setAttack(1.0f);
        inputGate->setRelease(50.0f);

        loadModel(AmpModel::Crunch_British);
        reset();
    }

    void reset()
    {
        for (auto& stage : preampStages)
            stage->reset();
        powerAmp->reset();
        toneStack->reset();
        cabinet->reset();
        inputGate->reset();
    }

    //==========================================================================
    // Model Selection
    //==========================================================================

    void loadModel(AmpModel model)
    {
        currentModel = model;

        switch (model)
        {
            case AmpModel::Clean_American:
                numActiveStages = 1;
                preampStages[0]->setTubeType(TubeStage::TubeType::ECC81_12AT7);
                preampStages[0]->setDrive(0.2f);
                powerAmp->setTubeType(TubeStage::TubeType::SIX_L6);
                powerAmp->setDrive(0.3f);
                toneStack->setType(ToneStack::StackType::Fender);
                cabinet->setCabinet(CabinetSimulator::CabinetType::Combo_1x12_American);
                break;

            case AmpModel::Clean_British:
                numActiveStages = 1;
                preampStages[0]->setTubeType(TubeStage::TubeType::ECC83_12AX7);
                preampStages[0]->setDrive(0.25f);
                powerAmp->setTubeType(TubeStage::TubeType::EL84);
                powerAmp->setDrive(0.35f);
                toneStack->setType(ToneStack::StackType::Vox);
                cabinet->setCabinet(CabinetSimulator::CabinetType::Combo_2x12_British);
                break;

            case AmpModel::Crunch_British:
                numActiveStages = 2;
                preampStages[0]->setTubeType(TubeStage::TubeType::ECC83_12AX7);
                preampStages[0]->setDrive(0.5f);
                preampStages[1]->setTubeType(TubeStage::TubeType::ECC83_12AX7);
                preampStages[1]->setDrive(0.4f);
                powerAmp->setTubeType(TubeStage::TubeType::EL34);
                powerAmp->setDrive(0.5f);
                toneStack->setType(ToneStack::StackType::Marshall);
                cabinet->setCabinet(CabinetSimulator::CabinetType::Stack_4x12_British);
                break;

            case AmpModel::High_Gain_British:
                numActiveStages = 3;
                for (int i = 0; i < 3; ++i)
                {
                    preampStages[i]->setTubeType(TubeStage::TubeType::ECC83_12AX7);
                    preampStages[i]->setDrive(0.6f + i * 0.1f);
                }
                powerAmp->setTubeType(TubeStage::TubeType::EL34);
                powerAmp->setDrive(0.6f);
                toneStack->setType(ToneStack::StackType::Marshall);
                cabinet->setCabinet(CabinetSimulator::CabinetType::Stack_4x12_British);
                break;

            case AmpModel::High_Gain_American:
                numActiveStages = 3;
                for (int i = 0; i < 3; ++i)
                {
                    preampStages[i]->setTubeType(TubeStage::TubeType::ECC83_12AX7);
                    preampStages[i]->setDrive(0.65f + i * 0.1f);
                }
                powerAmp->setTubeType(TubeStage::TubeType::SIX_L6);
                powerAmp->setDrive(0.55f);
                toneStack->setType(ToneStack::StackType::Mesa);
                cabinet->setCabinet(CabinetSimulator::CabinetType::Stack_4x12_American);
                break;

            case AmpModel::Modern_Metal:
                numActiveStages = 4;
                for (int i = 0; i < 4; ++i)
                {
                    preampStages[i]->setTubeType(TubeStage::TubeType::ECC83_12AX7);
                    preampStages[i]->setDrive(0.7f + i * 0.075f);
                }
                powerAmp->setTubeType(TubeStage::TubeType::KT88);
                powerAmp->setDrive(0.5f);
                toneStack->setType(ToneStack::StackType::Mesa);
                cabinet->setCabinet(CabinetSimulator::CabinetType::Closed_2x12_Modern);
                break;

            case AmpModel::Vintage_Tweed:
                numActiveStages = 1;
                preampStages[0]->setTubeType(TubeStage::TubeType::ECC81_12AT7);
                preampStages[0]->setDrive(0.4f);
                powerAmp->setTubeType(TubeStage::TubeType::SIX_L6);
                powerAmp->setDrive(0.6f);
                toneStack->setType(ToneStack::StackType::Fender);
                cabinet->setCabinet(CabinetSimulator::CabinetType::Open_1x12_Vintage);
                break;

            case AmpModel::Bass_Classic:
                numActiveStages = 2;
                preampStages[0]->setTubeType(TubeStage::TubeType::ECC83_12AX7);
                preampStages[0]->setDrive(0.35f);
                preampStages[1]->setTubeType(TubeStage::TubeType::ECC82_12AU7);
                preampStages[1]->setDrive(0.3f);
                powerAmp->setTubeType(TubeStage::TubeType::SIX_L6);
                powerAmp->setDrive(0.5f);
                toneStack->setType(ToneStack::StackType::Flat);
                cabinet->setCabinet(CabinetSimulator::CabinetType::Bass_4x10);
                break;

            case AmpModel::Bass_Modern:
                numActiveStages = 2;
                preampStages[0]->setTubeType(TubeStage::TubeType::ECC83_12AX7);
                preampStages[0]->setDrive(0.4f);
                preampStages[1]->setTubeType(TubeStage::TubeType::ECC83_12AX7);
                preampStages[1]->setDrive(0.35f);
                powerAmp->setTubeType(TubeStage::TubeType::KT88);
                powerAmp->setDrive(0.45f);
                toneStack->setType(ToneStack::StackType::Mesa);
                cabinet->setCabinet(CabinetSimulator::CabinetType::Bass_1x15);
                break;
        }
    }

    //==========================================================================
    // Parameters
    //==========================================================================

    void setGain(float gain)
    {
        inputGain = juce::jlimit(0.0f, 1.0f, gain);
        float drive = 0.2f + inputGain * 0.7f;
        for (int i = 0; i < numActiveStages; ++i)
            preampStages[i]->setDrive(drive + i * 0.05f);
    }

    void setBass(float level)
    {
        toneStack->setBass(level);
    }

    void setMid(float level)
    {
        toneStack->setMid(level);
    }

    void setTreble(float level)
    {
        toneStack->setTreble(level);
    }

    void setPresence(float level)
    {
        toneStack->setPresence(level);
    }

    void setMasterVolume(float volume)
    {
        masterVolume = juce::jlimit(0.0f, 1.0f, volume);
    }

    void setCabinetType(CabinetSimulator::CabinetType type)
    {
        cabinet->setCabinet(type);
    }

    void setMicPosition(CabinetSimulator::MicPosition pos)
    {
        cabinet->setMicPosition(pos);
    }

    void setGateEnabled(bool enabled)
    {
        gateEnabled = enabled;
    }

    void setCabinetEnabled(bool enabled)
    {
        cabinetEnabled = enabled;
    }

    //==========================================================================
    // Processing
    //==========================================================================

    void processBlock(juce::AudioBuffer<float>& buffer)
    {
        int numSamples = buffer.getNumSamples();

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            float* data = buffer.getWritePointer(ch);

            for (int i = 0; i < numSamples; ++i)
            {
                data[i] = processSample(data[i]);
            }
        }
    }

    float processSample(float input)
    {
        float x = input;

        // Input gate
        if (gateEnabled)
            x = inputGate->process(x);

        // Input gain
        x *= inputGain * 2.0f + 0.5f;

        // Preamp stages
        for (int i = 0; i < numActiveStages; ++i)
        {
            x = preampStages[i]->process(x);
            x *= 0.8f; // Inter-stage attenuation
        }

        // Tone stack
        x = toneStack->process(x);

        // Power amp
        x = powerAmp->process(x);

        // Cabinet
        if (cabinetEnabled)
            x = cabinet->process(x);

        // Master volume
        x *= masterVolume;

        return x;
    }

    //==========================================================================
    // Getters
    //==========================================================================

    AmpModel getCurrentModel() const { return currentModel; }
    float getInputGain() const { return inputGain; }
    float getMasterVolume() const { return masterVolume; }

private:
    static constexpr int NumPreampStages = 4;

    double currentSampleRate = 48000.0;
    AmpModel currentModel = AmpModel::Crunch_British;

    std::array<std::unique_ptr<TubeStage>, NumPreampStages> preampStages;
    std::unique_ptr<TubeStage> powerAmp;
    std::unique_ptr<ToneStack> toneStack;
    std::unique_ptr<CabinetSimulator> cabinet;
    std::unique_ptr<NoiseGate> inputGate;

    int numActiveStages = 2;
    float inputGain = 0.5f;
    float masterVolume = 0.5f;
    bool gateEnabled = true;
    bool cabinetEnabled = true;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GuitarAmpSimulator)
};

} // namespace DSP
} // namespace Echoelmusic
