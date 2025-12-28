#include "VintageEffects.h"
#include "../Core/DSPOptimizations.h"

//==============================================================================
// Constructor
//==============================================================================

VintageEffects::VintageEffects()
{
}

//==============================================================================
// Effect Selection
//==============================================================================

void VintageEffects::setEffectType(EffectType type)
{
    if (currentEffect != type)
    {
        currentEffect = type;
        reset();
    }
}

//==============================================================================
// Common Parameters
//==============================================================================

void VintageEffects::setMix(float mixAmount)
{
    mix = juce::jlimit(0.0f, 1.0f, mixAmount);
}

void VintageEffects::setDrive(float driveAmount)
{
    drive = juce::jlimit(0.0f, 1.0f, driveAmount);
}

//==============================================================================
// Envelope Filter
//==============================================================================

void VintageEffects::setEnvelopeMode(EnvelopeMode mode)
{
    envelopeMode = mode;
}

void VintageEffects::setSensitivity(float sens)
{
    sensitivity = juce::jlimit(0.0f, 1.0f, sens);
}

void VintageEffects::setResonance(float q)
{
    resonance = juce::jlimit(0.1f, 10.0f, q);
}

void VintageEffects::setAttack(float attackMs)
{
    attack = juce::jlimit(1.0f, 100.0f, attackMs);
}

void VintageEffects::setRelease(float releaseMs)
{
    release = juce::jlimit(10.0f, 1000.0f, releaseMs);
}

//==============================================================================
// Other Effect Parameters
//==============================================================================

void VintageEffects::setTapeType(float type)
{
    tapeType = juce::jlimit(0.0f, 1.0f, type);
}

void VintageEffects::setHiss(float amount)
{
    hiss = juce::jlimit(0.0f, 1.0f, amount);
}

void VintageEffects::setBandwidth(float hz)
{
    bandwidth = juce::jlimit(20.0f, 20000.0f, hz);
}

void VintageEffects::setNoise(float amount)
{
    noise = juce::jlimit(0.0f, 1.0f, amount);
}

void VintageEffects::setDropout(float prob)
{
    dropout = juce::jlimit(0.0f, 1.0f, prob);
}

void VintageEffects::setBias(float biasAmount)
{
    bias = juce::jlimit(0.0f, 1.0f, biasAmount);
}

void VintageEffects::setOutputLevel(float level)
{
    outputLevel = juce::jlimit(0.0f, 2.0f, level);
}

void VintageEffects::setSampleRateReduction(float sampleRate)
{
    sampleRateReduction = juce::jlimit(100.0f, 48000.0f, sampleRate);
}

void VintageEffects::setBitDepth(int bits)
{
    bitDepth = juce::jlimit(1, 16, bits);
    cachedBitMax = static_cast<float>((1 << bitDepth) - 1);  // Cache pow(2, bits) - 1
}

void VintageEffects::setCrackle(float amount)
{
    crackle = juce::jlimit(0.0f, 1.0f, amount);
}

void VintageEffects::setDust(float amount)
{
    dust = juce::jlimit(0.0f, 1.0f, amount);
}

void VintageEffects::setWobble(float amount)
{
    wobble = juce::jlimit(0.0f, 1.0f, amount);
}

//==============================================================================
// Processing
//==============================================================================

void VintageEffects::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);

    currentSampleRate = sampleRate;

    // Update envelope coefficients
    for (auto& state : envelopeStates)
    {
        state.attackCoeff = std::exp(-1000.0f / (attack * static_cast<float>(sampleRate)));
        state.releaseCoeff = std::exp(-1000.0f / (release * static_cast<float>(sampleRate)));
    }

    reset();
}

void VintageEffects::reset()
{
    for (auto& state : envelopeStates)
    {
        state.envelope = 0.0f;
    }

    for (auto& state : filterStates)
    {
        state.x1 = state.x2 = state.y1 = state.y2 = 0.0f;
    }

    for (auto& state : bitCrusherStates)
    {
        state.phase = 0.0f;
        state.lastSample = 0.0f;
    }

    vinylPhase = 0.0f;
    crackleTimer = 0;
}

void VintageEffects::process(juce::AudioBuffer<float>& buffer)
{
    switch (currentEffect)
    {
        case EffectType::EnvelopeFilter:
            processEnvelopeFilter(buffer);
            break;

        case EffectType::TapeSaturation:
            processTapeSaturation(buffer);
            break;

        case EffectType::VHSLoFi:
            processVHSLoFi(buffer);
            break;

        case EffectType::TubeDistortion:
            processTubeDistortion(buffer);
            break;

        case EffectType::BitCrusher:
            processBitCrusher(buffer);
            break;

        case EffectType::VinylSimulator:
            processVinylSimulator(buffer);
            break;
    }
}

//==============================================================================
// Envelope Filter (Auto-Wah)
//==============================================================================

void VintageEffects::processEnvelopeFilter(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);
        auto& envState = envelopeStates[channel];
        auto& filtState = filterStates[channel];

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];
            float inputLevel = std::abs(input);

            // Envelope follower
            if (inputLevel > envState.envelope)
                envState.envelope = envState.attackCoeff * envState.envelope + (1.0f - envState.attackCoeff) * inputLevel;
            else
                envState.envelope = envState.releaseCoeff * envState.envelope + (1.0f - envState.releaseCoeff) * inputLevel;

            // Map envelope to filter cutoff (200Hz - 5kHz)
            float cutoff = 200.0f + envState.envelope * sensitivity * 4800.0f;

            // Apply filter
            float output = applyBiquadFilter(input, filtState, cutoff, resonance, envelopeMode);

            // Mix
            channelData[i] = input * (1.0f - mix) + output * mix;
        }
    }
}

//==============================================================================
// Tape Saturation
//==============================================================================

void VintageEffects::processTapeSaturation(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < numChannels; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];

            // Tape saturation
            float saturated = tapeSaturate(input, drive, tapeType);

            // Add tape hiss (filtered noise)
            float hissNoise = generateNoise() * hiss * 0.02f;
            saturated += hissNoise;

            // Mix
            channelData[i] = input * (1.0f - mix) + saturated * mix;
        }
    }
}

//==============================================================================
// VHS/Lo-Fi
//==============================================================================

void VintageEffects::processVHSLoFi(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);
        auto& filtState = filterStates[channel];

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];

            // Bandwidth limiting (lowpass)
            float lofi = applyBiquadFilter(input, filtState, bandwidth, 0.707f, EnvelopeMode::LowPass);

            // Add noise
            lofi += generateNoise() * noise * 0.1f;

            // Random dropout - use fast RNG
            if (rng.nextFloat() < dropout * 0.001f)
            {
                lofi *= 0.1f;  // Dropout
            }

            // Mix
            channelData[i] = input * (1.0f - mix) + lofi * mix;
        }
    }
}

//==============================================================================
// Tube Distortion
//==============================================================================

void VintageEffects::processTubeDistortion(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < numChannels; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];

            // Tube distortion
            float distorted = tubeDistort(input, drive, bias);

            // Output level control
            distorted *= outputLevel;

            // Mix
            channelData[i] = input * (1.0f - mix) + distorted * mix;
        }
    }
}

//==============================================================================
// BitCrusher
//==============================================================================

void VintageEffects::processBitCrusher(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);
        auto& state = bitCrusherStates[channel];

        float phaseIncrement = sampleRateReduction / static_cast<float>(currentSampleRate);

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];

            // Sample rate reduction
            state.phase += phaseIncrement;
            if (state.phase >= 1.0f)
            {
                state.phase -= 1.0f;
                state.lastSample = quantize(input, bitDepth);
            }

            // Mix
            channelData[i] = input * (1.0f - mix) + state.lastSample * mix;
        }
    }
}

//==============================================================================
// Vinyl Simulator
//==============================================================================

void VintageEffects::processVinylSimulator(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    // Get trig lookup tables for fast sin
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();

    for (int i = 0; i < numSamples; ++i)
    {
        // Crackle/pops - use fast RNG
        crackleTimer++;
        float crackleNoise = 0.0f;
        if (crackleTimer > 1000 && rng.nextFloat() < crackle * 0.01f)
        {
            crackleNoise = generateCrackle() * 0.3f;
            crackleTimer = 0;
        }

        // Dust/scratches (high-frequency noise)
        float dustNoise = generateNoise() * dust * 0.01f;

        // Wow (slow pitch variation) - use fast sin
        vinylPhase += (1.0f + trigTables.fastSin(vinylPhase * 0.1f) * wobble * 0.02f) / static_cast<float>(currentSampleRate);
        if (vinylPhase >= 1.0f)
            vinylPhase -= 1.0f;

        for (int ch = 0; ch < numChannels; ++ch)
        {
            float* channelData = buffer.getWritePointer(ch);
            float input = channelData[i];

            // Add vinyl character
            float output = input + crackleNoise + dustNoise;

            // Mix
            channelData[i] = input * (1.0f - mix) + output * mix;
        }
    }
}

//==============================================================================
// Utility Functions
//==============================================================================

float VintageEffects::applyBiquadFilter(float input, FilterState& state, float cutoff, float q, EnvelopeMode mode)
{
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    const float omega = juce::MathConstants<float>::twoPi * cutoff / static_cast<float>(currentSampleRate);
    const float sinOmega = trigTables.fastSinRad(omega);
    const float cosOmega = trigTables.fastCosRad(omega);
    const float alpha = sinOmega / (2.0f * q);

    float b0, b1, b2, a0, a1, a2;

    switch (mode)
    {
        case EnvelopeMode::LowPass:
            b0 = (1.0f - cosOmega) / 2.0f;
            b1 = 1.0f - cosOmega;
            b2 = (1.0f - cosOmega) / 2.0f;
            a0 = 1.0f + alpha;
            a1 = -2.0f * cosOmega;
            a2 = 1.0f - alpha;
            break;

        case EnvelopeMode::HighPass:
            b0 = (1.0f + cosOmega) / 2.0f;
            b1 = -(1.0f + cosOmega);
            b2 = (1.0f + cosOmega) / 2.0f;
            a0 = 1.0f + alpha;
            a1 = -2.0f * cosOmega;
            a2 = 1.0f - alpha;
            break;

        case EnvelopeMode::BandPass:
            b0 = alpha;
            b1 = 0.0f;
            b2 = -alpha;
            a0 = 1.0f + alpha;
            a1 = -2.0f * cosOmega;
            a2 = 1.0f - alpha;
            break;
    }

    // Normalize
    b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0;

    // Apply filter
    float output = b0 * input + b1 * state.x1 + b2 * state.x2 - a1 * state.y1 - a2 * state.y2;

    state.x2 = state.x1; state.x1 = input;
    state.y2 = state.y1; state.y1 = output;

    return output;
}

float VintageEffects::tapeSaturate(float input, float driveAmount, float type)
{
    float driven = input * (1.0f + driveAmount * 5.0f);

    // Soft saturation (vintage tape) - use fast tanh
    if (type < 0.5f)
        return Echoel::DSP::FastMath::fastTanh(driven);

    // Hard saturation (overdriven tape)
    return Echoel::DSP::FastMath::fastTanh(driven * 1.5f) * 0.8f;
}

float VintageEffects::tubeDistort(float input, float driveAmount, float biasAmount)
{
    // Add bias (creates even harmonics)
    float biased = input + biasAmount * 0.2f;

    // Tube-style asymmetric distortion
    float driven = biased * (1.0f + driveAmount * 10.0f);

    // Asymmetric soft-clip using fast tanh
    if (driven > 0.0f)
        return Echoel::DSP::FastMath::fastTanh(driven * 1.2f);
    else
        return Echoel::DSP::FastMath::fastTanh(driven * 0.8f);
}

float VintageEffects::quantize(float sample, int /* bits */)
{
    // Use cached bit max instead of per-sample pow()
    return std::round(sample * cachedBitMax) / cachedBitMax;
}

float VintageEffects::generateNoise()
{
    return rng.nextFloat() * 2.0f - 1.0f;
}

float VintageEffects::generateCrackle()
{
    // Sharp transient for vinyl crackle
    return rng.nextFloat() > 0.95f ? 1.0f : 0.0f;
}
