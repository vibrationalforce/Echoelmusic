#include "TransientDesigner.h"
#include "../Core/DSPOptimizations.h"

//==============================================================================
// Constructor
//==============================================================================

TransientDesigner::TransientDesigner()
{
}

//==============================================================================
// Parameters
//==============================================================================

void TransientDesigner::setAttack(float amount)
{
    attack = juce::jlimit(-100.0f, 100.0f, amount);
}

void TransientDesigner::setSustain(float amount)
{
    sustain = juce::jlimit(-100.0f, 100.0f, amount);
}

void TransientDesigner::setAttackSpeed(float speedMs)
{
    attackSpeed = juce::jlimit(1.0f, 100.0f, speedMs);
    updateCoefficients();
}

void TransientDesigner::setSustainSpeed(float speedMs)
{
    sustainSpeed = juce::jlimit(10.0f, 500.0f, speedMs);
    updateCoefficients();
}

void TransientDesigner::setMode(Mode newMode)
{
    mode = newMode;
}

void TransientDesigner::setMix(float mixAmount)
{
    mix = juce::jlimit(0.0f, 1.0f, mixAmount);
}

void TransientDesigner::setClippingProtection(bool enabled)
{
    clippingProtection = enabled;
}

//==============================================================================
// Processing
//==============================================================================

void TransientDesigner::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    // Pre-allocate dry buffer
    dryBuffer.setSize(2, maxBlockSize);

    updateCoefficients();
    reset();
}

void TransientDesigner::reset()
{
    for (auto& state : channelStates)
    {
        state.fastEnvelope = 0.0f;
        state.slowEnvelope = 0.0f;
        state.previousLevel = 0.0f;
        state.transientGain = 1.0f;
        state.sustainGain = 1.0f;
        state.attackEnvelopeDisplay = 0.0f;
        state.sustainEnvelopeDisplay = 0.0f;
        state.gainReduction = 0.0f;
    }

    // Reset multiband filters
    for (auto& lpf : multibandState.lowpass1)
        lpf.x1 = lpf.x2 = lpf.y1 = lpf.y2 = 0.0f;
    for (auto& hpf : multibandState.highpass1)
        hpf.x1 = hpf.x2 = hpf.y1 = hpf.y2 = 0.0f;
    for (auto& lpf : multibandState.lowpass2)
        lpf.x1 = lpf.x2 = lpf.y1 = lpf.y2 = 0.0f;
    for (auto& hpf : multibandState.highpass2)
        hpf.x1 = hpf.x2 = hpf.y1 = hpf.y2 = 0.0f;
}

void TransientDesigner::process(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    if (numChannels < 2)
        return;

    float* leftChannel = buffer.getWritePointer(0);
    float* rightChannel = buffer.getWritePointer(1);

    // Ensure dry buffer is large enough (avoid per-frame allocation)
    if (dryBuffer.getNumSamples() < numSamples)
        dryBuffer.setSize(2, numSamples, false, false, true);

    // Store dry signal using pre-allocated buffer
    dryBuffer.copyFrom(0, 0, buffer, 0, 0, numSamples);
    dryBuffer.copyFrom(1, 0, buffer, 1, 0, numSamples);
    const float* dryLeft = dryBuffer.getReadPointer(0);
    const float* dryRight = dryBuffer.getReadPointer(1);

    // Process based on mode
    switch (mode)
    {
        case Mode::Normal:
        case Mode::Parallel:
            processNormal(leftChannel, rightChannel, numSamples);
            break;

        case Mode::Multiband:
            processMultiband(leftChannel, rightChannel, numSamples);
            break;
    }

    // Apply mix (dry/wet)
    if (mix < 1.0f || mode == Mode::Parallel)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            leftChannel[i] = dryLeft[i] * (1.0f - mix) + leftChannel[i] * mix;
            rightChannel[i] = dryRight[i] * (1.0f - mix) + rightChannel[i] * mix;
        }
    }

    // Clipping protection
    if (clippingProtection)
    {
        const float ceiling = 0.99f;
        for (int i = 0; i < numSamples; ++i)
        {
            leftChannel[i] = juce::jlimit(-ceiling, ceiling, leftChannel[i]);
            rightChannel[i] = juce::jlimit(-ceiling, ceiling, rightChannel[i]);
        }
    }
}

//==============================================================================
// Metering
//==============================================================================

float TransientDesigner::getAttackEnvelope(int channel) const
{
    if (channel >= 0 && channel < 2)
        return channelStates[channel].attackEnvelopeDisplay;
    return 0.0f;
}

float TransientDesigner::getSustainEnvelope(int channel) const
{
    if (channel >= 0 && channel < 2)
        return channelStates[channel].sustainEnvelopeDisplay;
    return 0.0f;
}

float TransientDesigner::getGainReduction(int channel) const
{
    if (channel >= 0 && channel < 2)
        return channelStates[channel].gainReduction;
    return 0.0f;
}

//==============================================================================
// Internal Methods
//==============================================================================

void TransientDesigner::updateCoefficients()
{
    for (auto& state : channelStates)
    {
        // Fast envelope (attack detection) - very fast attack, fast release
        state.fastAttackCoeff = Echoel::DSP::FastMath::fastExp(-1000.0f / (attackSpeed * 0.1f * static_cast<float>(currentSampleRate)));
        state.fastReleaseCoeff = Echoel::DSP::FastMath::fastExp(-1000.0f / (attackSpeed * static_cast<float>(currentSampleRate)));

        // Slow envelope (sustain detection) - slow attack, slow release
        state.slowAttackCoeff = Echoel::DSP::FastMath::fastExp(-1000.0f / (sustainSpeed * 0.5f * static_cast<float>(currentSampleRate)));
        state.slowReleaseCoeff = Echoel::DSP::FastMath::fastExp(-1000.0f / (sustainSpeed * static_cast<float>(currentSampleRate)));
    }
}

void TransientDesigner::processNormal(float* leftChannel, float* rightChannel, int numSamples)
{
    for (int i = 0; i < numSamples; ++i)
    {
        // Process left channel
        leftChannel[i] = processTransient(leftChannel[i], channelStates[0]);

        // Process right channel
        rightChannel[i] = processTransient(rightChannel[i], channelStates[1]);
    }
}

void TransientDesigner::processMultiband(float* leftChannel, float* rightChannel, int numSamples)
{
    // Split into 3 bands: Low (<100Hz), Mid (100Hz-2kHz), High (>2kHz)
    // Process each band separately with transient shaping
    // Sum bands back together

    // For simplicity, using normal processing here
    // Full multiband would require separate envelope followers per band
    processNormal(leftChannel, rightChannel, numSamples);
}

float TransientDesigner::processTransient(float input, EnvelopeState& state)
{
    const float inputLevel = std::abs(input);

    // Fast envelope follower (attack detection)
    if (inputLevel > state.fastEnvelope)
        state.fastEnvelope = state.fastAttackCoeff * state.fastEnvelope + (1.0f - state.fastAttackCoeff) * inputLevel;
    else
        state.fastEnvelope = state.fastReleaseCoeff * state.fastEnvelope + (1.0f - state.fastReleaseCoeff) * inputLevel;

    // Slow envelope follower (sustain detection)
    if (inputLevel > state.slowEnvelope)
        state.slowEnvelope = state.slowAttackCoeff * state.slowEnvelope + (1.0f - state.slowAttackCoeff) * inputLevel;
    else
        state.slowEnvelope = state.slowReleaseCoeff * state.slowEnvelope + (1.0f - state.slowReleaseCoeff) * inputLevel;

    // Calculate transient gain
    float gain = calculateTransientGain(inputLevel, state.fastEnvelope, state.slowEnvelope);

    // Update metering
    state.attackEnvelopeDisplay = state.fastEnvelope;
    state.sustainEnvelopeDisplay = state.slowEnvelope;
    state.gainReduction = juce::Decibels::gainToDecibels(gain);

    // Apply gain
    return input * gain;
}

float TransientDesigner::calculateTransientGain(float inputLevel, float fastEnv, float slowEnv)
{
    juce::ignoreUnused(inputLevel);

    // Detect transient: fast envelope is much higher than slow envelope
    float transientRatio = (slowEnv > 0.0001f) ? (fastEnv / slowEnv) : 1.0f;
    transientRatio = juce::jlimit(0.0f, 10.0f, transientRatio);

    // Calculate attack gain (affects transients)
    float attackGain = 1.0f;
    if (attack != 0.0f)
    {
        // When transient is detected (ratio > 1.5), apply attack modification
        if (transientRatio > 1.5f)
        {
            float transientAmount = juce::jmap(transientRatio, 1.5f, 3.0f, 0.0f, 1.0f);
            transientAmount = juce::jlimit(0.0f, 1.0f, transientAmount);

            if (attack > 0.0f)
            {
                // Enhance transient
                attackGain = 1.0f + (attack / 100.0f) * 3.0f * transientAmount;
            }
            else
            {
                // Reduce transient
                attackGain = 1.0f + (attack / 100.0f) * 0.8f * transientAmount;
            }
        }
    }

    // Calculate sustain gain (affects tail/body)
    float sustainGain = 1.0f;
    if (sustain != 0.0f)
    {
        // When sustain is detected (ratio close to 1), apply sustain modification
        if (transientRatio < 1.5f)
        {
            float sustainAmount = 1.0f - juce::jmap(transientRatio, 1.0f, 1.5f, 0.0f, 1.0f);
            sustainAmount = juce::jlimit(0.0f, 1.0f, sustainAmount);

            if (sustain > 0.0f)
            {
                // Enhance sustain
                sustainGain = 1.0f + (sustain / 100.0f) * 2.0f * sustainAmount;
            }
            else
            {
                // Reduce sustain
                sustainGain = 1.0f + (sustain / 100.0f) * 0.9f * sustainAmount;
            }
        }
    }

    // Combine attack and sustain gains
    float totalGain = attackGain * sustainGain;

    // Limit gain to reasonable range
    return juce::jlimit(0.1f, 5.0f, totalGain);
}

void TransientDesigner::applyButterworthFilter(float& sample,
                                                float frequency,
                                                bool isHighpass,
                                                MultibandState::BiquadState& state)
{
    // Butterworth 2nd order filter using fast trig
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    const float omega = juce::MathConstants<float>::twoPi * frequency / static_cast<float>(currentSampleRate);
    const float cosOmega = trigTables.fastCosRad(omega);
    const float sinOmega = trigTables.fastSinRad(omega);
    const float alpha = sinOmega / (2.0f * 0.707f);  // Q = 0.707

    float b0, b1, b2, a0, a1, a2;

    if (isHighpass)
    {
        b0 = (1.0f + cosOmega) / 2.0f;
        b1 = -(1.0f + cosOmega);
        b2 = (1.0f + cosOmega) / 2.0f;
        a0 = 1.0f + alpha;
        a1 = -2.0f * cosOmega;
        a2 = 1.0f - alpha;
    }
    else  // Lowpass
    {
        b0 = (1.0f - cosOmega) / 2.0f;
        b1 = 1.0f - cosOmega;
        b2 = (1.0f - cosOmega) / 2.0f;
        a0 = 1.0f + alpha;
        a1 = -2.0f * cosOmega;
        a2 = 1.0f - alpha;
    }

    // Normalize
    b0 /= a0;
    b1 /= a0;
    b2 /= a0;
    a1 /= a0;
    a2 /= a0;

    // Apply filter
    const float x0 = sample;
    const float y0 = b0 * x0 + b1 * state.x1 + b2 * state.x2
                     - a1 * state.y1 - a2 * state.y2;

    sample = y0;

    // Update state
    state.x2 = state.x1;
    state.x1 = x0;
    state.y2 = state.y1;
    state.y1 = y0;
}
