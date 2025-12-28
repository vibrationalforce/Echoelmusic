#include "FormantFilter.h"

FormantFilter::FormantFilter()
{
}

FormantFilter::~FormantFilter()
{
}

void FormantFilter::prepare(double sampleRate, int maximumBlockSize)
{
    currentSampleRate = sampleRate;

    // Initialize formants
    for (auto& formant : formantsL)
        formant.setSampleRate(static_cast<float>(sampleRate));

    for (auto& formant : formantsR)
        formant.setSampleRate(static_cast<float>(sampleRate));

    // Initialize LFO
    lfo.setSampleRate(static_cast<float>(sampleRate));
    lfo.setRate(lfoRate);

    // Pre-allocate dry buffer (OPTIMIZATION: avoids per-frame allocation)
    dryBuffer.setSize(2, maximumBlockSize);

    // Update formant coefficients
    updateFormants();

    reset();
}

void FormantFilter::reset()
{
    for (auto& formant : formantsL)
        formant.reset();

    for (auto& formant : formantsR)
        formant.reset();

    lfo.reset();
    updateCounter = 0;
}

void FormantFilter::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numChannels == 0 || numSamples == 0)
        return;

    // Store dry signal using pre-allocated buffer (no allocation in audio thread)
    if (dryBuffer.getNumChannels() < numChannels || dryBuffer.getNumSamples() < numSamples)
        dryBuffer.setSize(numChannels, numSamples, false, false, true);
    for (int ch = 0; ch < numChannels; ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // Process each channel
    for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
    {
        auto* data = buffer.getWritePointer(channel);
        auto& formants = (channel == 0) ? formantsL : formantsR;

        for (int sample = 0; sample < numSamples; ++sample)
        {
            float input = data[sample];

            // Update formants periodically (every 64 samples to reduce CPU)
            if (updateCounter++ >= 64)
            {
                updateFormants();
                updateCounter = 0;
            }

            // Process through formant cascade (5 peaks)
            float output = input;
            for (int f = 0; f < 5; ++f)
            {
                output = formants[f].process(output);
            }

            // Normalize to prevent clipping
            output *= 0.3f;

            data[sample] = output;
        }
    }

    // Mix dry/wet
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
void FormantFilter::setVowel(int vowel)
{
    currentVowel = juce::jlimit(0, 4, vowel);
    updateFormants();
}

void FormantFilter::setVowelMorph(float morph)
{
    currentVowelMorph = juce::jlimit(0.0f, 1.0f, morph);
}

void FormantFilter::setResonance(float resonance)
{
    currentResonance = juce::jlimit(0.0f, 1.0f, resonance);
}

void FormantFilter::setFormantShift(float shift)
{
    currentFormantShift = juce::jlimit(-1.0f, 1.0f, shift);
}

void FormantFilter::setLFOEnabled(bool enabled)
{
    lfoEnabled = enabled;
}

void FormantFilter::setLFORate(float hz)
{
    lfoRate = juce::jlimit(0.1f, 10.0f, hz);
    lfo.setRate(hz);
}

void FormantFilter::setLFODepth(float depth)
{
    lfoDepth = juce::jlimit(0.0f, 1.0f, depth);
}

void FormantFilter::setMix(float mix)
{
    currentMix = juce::jlimit(0.0f, 1.0f, mix);
}
