#include "UnderwaterEffect.h"

UnderwaterEffect::UnderwaterEffect()
{
    // Initialize reverb for underwater ambience
    reverbParams.roomSize = 0.9f;
    reverbParams.damping = 0.3f;
    reverbParams.wetLevel = 0.6f;
    reverbParams.dryLevel = 0.0f;
    reverbParams.width = 1.0f;
    reverbParams.freezeMode = 0.0f;

    reverb.setParameters(reverbParams);
}

UnderwaterEffect::~UnderwaterEffect()
{
}

void UnderwaterEffect::prepare(double sampleRate, int maximumBlockSize)
{
    currentSampleRate = sampleRate;

    // Prepare reverb (JUCE 7 API)
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<uint32_t>(maximumBlockSize);
    spec.numChannels = 2;

    reverb.prepare(spec);
    reverb.reset();

    // Prepare filters
    filterL.setSampleRate(static_cast<float>(sampleRate));
    filterR.setSampleRate(static_cast<float>(sampleRate));

    // Prepare pitch wobble delay
    pitchDelay.prepare(spec);
    pitchDelay.setMaximumDelayInSamples(static_cast<int>(0.05f * sampleRate));  // 50ms max

    // Prepare bubble generators
    bubbleGenL.setSampleRate(static_cast<float>(sampleRate));
    bubbleGenR.setSampleRate(static_cast<float>(sampleRate));

    // ✅ OPTIMIZATION: Pre-allocate buffer to avoid audio thread allocation
    dryBuffer.setSize(2, maximumBlockSize);
    dryBuffer.clear();

    reset();
}

void UnderwaterEffect::reset()
{
    reverb.reset();
    pitchDelay.reset();

    filterL.lowpass = filterL.bandpass = filterL.highpass = 0.0f;
    filterR.lowpass = filterR.bandpass = filterR.highpass = 0.0f;

    lfoPhase = 0.0f;
    bubbleGenL.phase = 0.0f;
    bubbleGenR.phase = 0.0f;
}

void UnderwaterEffect::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numChannels == 0 || numSamples == 0)
        return;

    // ✅ OPTIMIZATION: Use pre-allocated buffer (no audio thread allocation)
    const int safeChannels = juce::jmin(numChannels, 2);
    for (int ch = 0; ch < safeChannels; ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // Update filter cutoff based on depth (deeper = less high frequency)
    float cutoff = juce::jmap(currentDepth, 0.0f, 1.0f, 2000.0f, 400.0f);
    filterL.setCutoff(cutoff);
    filterR.setCutoff(cutoff);

    // Update reverb parameters based on density
    reverbParams.roomSize = juce::jmap(currentDensity, 0.0f, 1.0f, 0.7f, 0.95f);
    reverbParams.damping = juce::jmap(currentDensity, 0.0f, 1.0f, 0.5f, 0.2f);
    reverb.setParameters(reverbParams);

    // Process each channel
    for (int channel = 0; channel < numChannels; ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);
        auto& filter = (channel == 0) ? filterL : filterR;
        auto& bubbleGen = (channel == 0) ? bubbleGenL : bubbleGenR;

        for (int sample = 0; sample < numSamples; ++sample)
        {
            float input = channelData[sample];

            // 1. Lowpass filtering (water absorption)
            float filtered = filter.process(input);

            // 2. Pitch wobble (Doppler-like effect)
            float lfoValue = std::sin(2.0f * juce::MathConstants<float>::pi * lfoPhase);
            float wobbleAmount = currentWobble * 0.02f;  // ±2% max pitch shift
            float delayTime = (1.0f + lfoValue * wobbleAmount) * 10.0f;  // 10ms base delay

            pitchDelay.pushSample(channel, filtered);
            float wobbled = pitchDelay.popSample(channel, delayTime);

            // 3. Add bubbles
            float bubble = bubbleGen.generate() * currentBubbles;
            float withBubbles = wobbled + bubble * 0.5f;

            channelData[sample] = withBubbles;
        }

        // Update LFO phase
        lfoPhase += lfoRate / static_cast<float>(currentSampleRate);
        if (lfoPhase > 1.0f)
            lfoPhase -= 1.0f;
    }

    // 4. Apply reverb to entire buffer (JUCE 7 API)
    juce::dsp::AudioBlock<float> block(buffer);
    juce::dsp::ProcessContextReplacing<float> context(block);
    reverb.process(context);

    // 5. Mix dry/wet
    for (int ch = 0; ch < numChannels; ++ch)
    {
        auto* wet = buffer.getReadPointer(ch);
        auto* dry = dryBuffer.getReadPointer(ch);
        auto* out = buffer.getWritePointer(ch);

        for (int i = 0; i < numSamples; ++i)
            out[i] = dry[i] * (1.0f - currentMix) + wet[i] * currentMix;
    }
}

//==============================================================================
void UnderwaterEffect::setDepth(float depth)
{
    currentDepth = juce::jlimit(0.0f, 1.0f, depth);
}

void UnderwaterEffect::setDensity(float density)
{
    currentDensity = juce::jlimit(0.0f, 1.0f, density);
}

void UnderwaterEffect::setWobble(float wobble)
{
    currentWobble = juce::jlimit(0.0f, 1.0f, wobble);
}

void UnderwaterEffect::setBubbles(float bubbles)
{
    currentBubbles = juce::jlimit(0.0f, 1.0f, bubbles);
}

void UnderwaterEffect::setMix(float mix)
{
    currentMix = juce::jlimit(0.0f, 1.0f, mix);
}
