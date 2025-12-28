#include "ModulationSuite.h"
#include "../Core/DSPOptimizations.h"

//==============================================================================
// Constructor
//==============================================================================

ModulationSuite::ModulationSuite()
{
}

//==============================================================================
// Effect Selection
//==============================================================================

void ModulationSuite::setEffectType(EffectType type)
{
    if (currentEffect != type)
    {
        currentEffect = type;
        reset();
    }
}

//==============================================================================
// Parameters
//==============================================================================

void ModulationSuite::setRate(float rateHz)
{
    rate = juce::jlimit(0.01f, 20.0f, rateHz);
    lfoIncrement = rate / static_cast<float>(currentSampleRate);
}

void ModulationSuite::setDepth(float depthAmount)
{
    depth = juce::jlimit(0.0f, 1.0f, depthAmount);
}

void ModulationSuite::setFeedback(float fb)
{
    feedback = juce::jlimit(-1.0f, 1.0f, fb);
}

void ModulationSuite::setStereoWidth(float width)
{
    stereoWidth = juce::jlimit(0.0f, 1.0f, width);
}

void ModulationSuite::setMix(float mixAmount)
{
    mix = juce::jlimit(0.0f, 1.0f, mixAmount);
}

void ModulationSuite::setLFOShape(LFOShape shape)
{
    lfoShape = shape;
}

void ModulationSuite::setTempoSync(bool enabled)
{
    tempoSync = enabled;
}

void ModulationSuite::setTempo(double bpm)
{
    tempo = juce::jlimit(20.0, 999.0, bpm);
}

void ModulationSuite::setChorusVoices(int voices)
{
    chorusVoices = juce::jlimit(1, 8, voices);
}

void ModulationSuite::setFlangerManual(float position)
{
    flangerManual = juce::jlimit(0.0f, 1.0f, position);
}

void ModulationSuite::setPhaserStages(int stages)
{
    // Only even numbers 2-12
    phaserStages = juce::jlimit(2, 12, (stages / 2) * 2);
}

void ModulationSuite::setRingModCarrier(float freq)
{
    ringModCarrier = juce::jlimit(20.0f, 5000.0f, freq);
}

void ModulationSuite::setFrequencyShift(float shiftHz)
{
    frequencyShift = juce::jlimit(-2000.0f, 2000.0f, shiftHz);
}

//==============================================================================
// Processing
//==============================================================================

void ModulationSuite::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);

    currentSampleRate = sampleRate;

    // Allocate delay buffers
    for (auto& buffer : delayBuffers)
    {
        buffer.resize(maxDelayInSamples);
        std::fill(buffer.begin(), buffer.end(), 0.0f);
    }

    updateLFO();
    reset();
}

void ModulationSuite::reset()
{
    // Clear delay buffers
    for (auto& buffer : delayBuffers)
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
    }

    writePositions.fill(0);

    // Reset allpass filters
    for (auto& channelStates : allpassStates)
    {
        for (auto& state : channelStates)
        {
            state.x1 = state.y1 = 0.0f;
        }
    }

    // Reset other states
    ringModPhase = 0.0f;
    shifterPhase = 0.0f;

    for (auto& state : hilbertStates)
    {
        state.x.fill(0.0f);
        state.y.fill(0.0f);
    }
}

void ModulationSuite::process(juce::AudioBuffer<float>& buffer)
{
    switch (currentEffect)
    {
        case EffectType::Chorus:
            processChorus(buffer);
            break;

        case EffectType::Flanger:
            processFlanger(buffer);
            break;

        case EffectType::Phaser:
            processPhaser(buffer);
            break;

        case EffectType::Tremolo:
            processTremolo(buffer);
            break;

        case EffectType::Vibrato:
            processVibrato(buffer);
            break;

        case EffectType::RingModulator:
            processRingMod(buffer);
            break;

        case EffectType::FrequencyShifter:
            processFrequencyShifter(buffer);
            break;
    }
}

//==============================================================================
// LFO
//==============================================================================

void ModulationSuite::updateLFO()
{
    lfoPhase += lfoIncrement;
    if (lfoPhase >= 1.0f)
        lfoPhase -= 1.0f;

    currentLFOValue = getLFOSample();
}

float ModulationSuite::getLFOSample()
{
    // Get trig lookup tables for fast sin
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();

    switch (lfoShape)
    {
        case LFOShape::Sine:
            return (trigTables.fastSin(lfoPhase) + 1.0f) * 0.5f;  // Fast sin lookup

        case LFOShape::Triangle:
            return (lfoPhase < 0.5f) ? (lfoPhase * 2.0f) : (2.0f - lfoPhase * 2.0f);

        case LFOShape::Saw:
            return lfoPhase;

        case LFOShape::ReverseSaw:
            return 1.0f - lfoPhase;

        case LFOShape::Square:
            return (lfoPhase < 0.5f) ? 0.0f : 1.0f;

        case LFOShape::RandomSmooth:
        {
            // Smooth random (sample & hold with interpolation)
            if (lfoPhase < 0.01f)
            {
                // Use fast random instead of std::rand()
                randomTarget = rng.nextFloat();
            }
            randomCurrent += (randomTarget - randomCurrent) * 0.01f;
            return randomCurrent;
        }

        case LFOShape::RandomStep:
            // Step random (sample & hold)
            if (lfoPhase < 0.01f)
            {
                randomCurrent = rng.nextFloat();  // Use fast random
            }
            return randomCurrent;

        default:
            return 0.5f;
    }
}

//==============================================================================
// Chorus
//==============================================================================

void ModulationSuite::processChorus(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];

            // Update LFO
            updateLFO();

            // Write to delay
            writeDelay(channel, input);

            // Read multiple delayed voices
            float chorusOut = 0.0f;

            // Get trig lookup tables for fast sin
            const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
            const float voiceReciprocal = 1.0f / static_cast<float>(chorusVoices);

            for (int voice = 0; voice < chorusVoices; ++voice)
            {
                // Offset each voice slightly in time and LFO phase
                float voiceOffset = static_cast<float>(voice) * voiceReciprocal;
                float lfoValue = (trigTables.fastSin(lfoPhase + voiceOffset) + 1.0f) * 0.5f;  // 0 to 1

                // Delay time: 10-30ms modulated by LFO
                float baseDelay = 15.0f + voiceOffset * 10.0f;  // Spread voices
                float delayMs = baseDelay + lfoValue * depth * 10.0f;
                float delaySamples = (delayMs / 1000.0f) * static_cast<float>(currentSampleRate);

                float delayedSample = readDelayInterpolated(channel, delaySamples);
                chorusOut += delayedSample;
            }

            chorusOut *= voiceReciprocal;

            // Mix dry/wet
            channelData[i] = input * (1.0f - mix) + chorusOut * mix;
        }
    }
}

//==============================================================================
// Flanger
//==============================================================================

void ModulationSuite::processFlanger(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];

            // Update LFO
            updateLFO();

            // Flanger uses very short delay (0.5ms - 10ms)
            float lfoValue = currentLFOValue;
            float delayMs = flangerManual * 5.0f + lfoValue * depth * 5.0f;
            float delaySamples = (delayMs / 1000.0f) * static_cast<float>(currentSampleRate);

            // Read delayed sample
            float delayedSample = readDelayInterpolated(channel, delaySamples);

            // Apply feedback
            float toWrite = input + delayedSample * feedback;
            writeDelay(channel, toWrite);

            // Mix
            float output = input + delayedSample * mix;
            channelData[i] = output;
        }
    }
}

//==============================================================================
// Phaser
//==============================================================================

void ModulationSuite::processPhaser(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    // Get trig lookup tables for fast tan approximation
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    const float sampleRateRecip = 1.0f / static_cast<float>(currentSampleRate);

    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];

            // Update LFO
            updateLFO();

            // Allpass center frequency modulated by LFO (200Hz - 2kHz)
            float centerFreq = 200.0f + currentLFOValue * depth * 1800.0f;

            // Calculate allpass coefficient using fast tan approximation
            float omega = juce::MathConstants<float>::twoPi * centerFreq * sampleRateRecip;
            float tanHalfOmega = trigTables.fastTanRad(omega * 0.5f);
            float coefficient = (1.0f - tanHalfOmega) / (1.0f + tanHalfOmega);

            // Pass through allpass filter cascade
            float output = input;
            for (int stage = 0; stage < phaserStages; ++stage)
            {
                output = applyAllpass(output, allpassStates[channel][stage], coefficient);
            }

            // Add feedback
            output += input * feedback;

            // Mix
            channelData[i] = input * (1.0f - mix) + output * mix;
        }
    }
}

//==============================================================================
// Tremolo
//==============================================================================

void ModulationSuite::processTremolo(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();

    for (int i = 0; i < numSamples; ++i)
    {
        updateLFO();

        // Amplitude modulation
        float gain = 1.0f - (currentLFOValue * depth);

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            float* channelData = buffer.getWritePointer(ch);
            float input = channelData[i];

            channelData[i] = input * gain;
        }
    }
}

//==============================================================================
// Vibrato
//==============================================================================

void ModulationSuite::processVibrato(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];

            // Update LFO
            updateLFO();

            // Write to delay
            writeDelay(channel, input);

            // Vibrato = pitch modulation via delay time modulation
            float delayMs = 5.0f + currentLFOValue * depth * 10.0f;
            float delaySamples = (delayMs / 1000.0f) * static_cast<float>(currentSampleRate);

            // Read with interpolation (this creates pitch shift)
            float output = readDelayInterpolated(channel, delaySamples);

            channelData[i] = output;
        }
    }
}

//==============================================================================
// Ring Modulator
//==============================================================================

void ModulationSuite::processRingMod(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();

    // Get trig lookup tables for fast sin
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    const float phaseIncrement = ringModCarrier / static_cast<float>(currentSampleRate);

    for (int i = 0; i < numSamples; ++i)
    {
        // Generate carrier (sine wave at carrier frequency) using fast sin lookup
        float carrier = trigTables.fastSin(ringModPhase);

        ringModPhase += phaseIncrement;
        if (ringModPhase >= 1.0f)
            ringModPhase -= 1.0f;

        // Multiply input with carrier
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            float* channelData = buffer.getWritePointer(ch);
            float input = channelData[i];

            float output = input * carrier;
            channelData[i] = input * (1.0f - mix) + output * mix;
        }
    }
}

//==============================================================================
// Frequency Shifter (Bode-style using Hilbert transform)
//==============================================================================

void ModulationSuite::processFrequencyShifter(juce::AudioBuffer<float>& buffer)
{
    // Simplified frequency shifter (full implementation would use Hilbert transform)
    // This is a basic version using single-sideband modulation

    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    // Get trig lookup tables for fast sin/cos
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    const float phaseIncrement = std::abs(frequencyShift) / static_cast<float>(currentSampleRate);

    for (int channel = 0; channel < numChannels && channel < 2; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];

            // Sine and cosine modulators using fast lookup
            float sine = trigTables.fastSin(shifterPhase);
            float cosine = trigTables.fastCos(shifterPhase);

            shifterPhase += phaseIncrement;
            if (shifterPhase >= 1.0f)
                shifterPhase -= 1.0f;

            // Simple frequency shift approximation
            float shifted = input * cosine;

            channelData[i] = input * (1.0f - mix) + shifted * mix;
        }
    }
}

//==============================================================================
// Utility Functions
//==============================================================================

float ModulationSuite::readDelayInterpolated(int channel, float delayInSamples)
{
    const auto& buffer = delayBuffers[channel];
    const int bufferSize = static_cast<int>(buffer.size());

    // Calculate read position
    float readPos = writePositions[channel] - delayInSamples;
    while (readPos < 0.0f)
        readPos += bufferSize;

    // Linear interpolation
    int index1 = static_cast<int>(readPos) % bufferSize;
    int index2 = (index1 + 1) % bufferSize;
    float frac = readPos - std::floor(readPos);

    return buffer[index1] * (1.0f - frac) + buffer[index2] * frac;
}

void ModulationSuite::writeDelay(int channel, float sample)
{
    delayBuffers[channel][writePositions[channel]] = sample;
    writePositions[channel] = (writePositions[channel] + 1) % delayBuffers[channel].size();
}

float ModulationSuite::applyAllpass(float input, AllpassState& state, float coefficient)
{
    float output = coefficient * input + state.x1 - coefficient * state.y1;

    state.x1 = input;
    state.y1 = output;

    return output;
}
