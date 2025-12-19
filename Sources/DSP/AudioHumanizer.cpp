#include "AudioHumanizer.h"

AudioHumanizer::AudioHumanizer()
{
}

void AudioHumanizer::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;
}

void AudioHumanizer::reset()
{
    phase = 0.0f;
}

void AudioHumanizer::process(juce::AudioBuffer<float>& buffer)
{
    if (humanizationAmount < 0.01f)
        return;  // Bypass if amount is too low

    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // Apply bio-reactive modulation if enabled
    float effectiveAmount = humanizationAmount;
    if (bioReactiveEnabled)
    {
        effectiveAmount *= (0.7f + currentHRV * 0.3f);
    }

    // Process each channel
    for (int ch = 0; ch < numChannels; ++ch)
    {
        auto* channelData = buffer.getWritePointer(ch);

        for (int i = 0; i < numSamples; ++i)
        {
            float sample = channelData[i];

            // Dimension 1: Spectral variation (subtle filtering)
            if (spectralAmount > 0.01f)
            {
                float variation = random.nextFloat() * 0.02f - 0.01f;
                sample *= (1.0f + variation * spectralAmount);
            }

            // Dimension 2: Transient variation
            if (transientAmount > 0.01f)
            {
                float transientMod = 1.0f + (random.nextFloat() * 0.1f - 0.05f) * transientAmount;
                sample *= transientMod;
            }

            // Dimension 3: Colour (harmonic content)
            if (colourAmount > 0.01f)
            {
                float colourMod = std::sin(phase) * 0.05f * colourAmount;
                sample += colourMod * sample;
            }

            // Dimension 4: Noise
            if (noiseAmount > 0.01f)
            {
                float noise = (random.nextFloat() * 2.0f - 1.0f) * 0.001f * noiseAmount;
                sample += noise;
            }

            // Dimension 5: Smoothing (slight low-pass)
            if (smoothAmount > 0.01f)
            {
                static float lastSample = 0.0f;
                sample = sample * (1.0f - smoothAmount * 0.3f) + lastSample * smoothAmount * 0.3f;
                lastSample = sample;
            }

            channelData[i] = sample * effectiveAmount + channelData[i] * (1.0f - effectiveAmount);

            // Update phase
            phase += 0.001f;
            if (phase > juce::MathConstants<float>::twoPi)
                phase -= juce::MathConstants<float>::twoPi;
        }
    }
}

void AudioHumanizer::setHumanizationAmount(float amount)
{
    humanizationAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void AudioHumanizer::setSpectralAmount(float amount)
{
    spectralAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void AudioHumanizer::setTransientAmount(float amount)
{
    transientAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void AudioHumanizer::setColourAmount(float amount)
{
    colourAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void AudioHumanizer::setNoiseAmount(float amount)
{
    noiseAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void AudioHumanizer::setSmoothAmount(float amount)
{
    smoothAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void AudioHumanizer::setTimeDivision(TimeDivision division)
{
    switch (division)
    {
        case TimeDivision::Sixteenth: timeDivision = 0.0625f; break;
        case TimeDivision::Eighth:    timeDivision = 0.125f; break;
        case TimeDivision::Quarter:   timeDivision = 0.25f; break;
        case TimeDivision::Half:      timeDivision = 0.5f; break;
        case TimeDivision::Whole:     timeDivision = 1.0f; break;
        case TimeDivision::TwoBar:    timeDivision = 2.0f; break;
        case TimeDivision::FourBar:   timeDivision = 4.0f; break;
    }
}

void AudioHumanizer::setBioReactiveEnabled(bool enabled)
{
    bioReactiveEnabled = enabled;
}

void AudioHumanizer::setBioData(float hrv, float coherence, float stress)
{
    currentHRV = hrv;
    currentCoherence = coherence;
    currentStress = stress;
}
