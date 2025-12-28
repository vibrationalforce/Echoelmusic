#include "BioReactiveDSP.h"

BioReactiveDSP::BioReactiveDSP()
{
    // Initialize reverb parameters
    reverbParams.roomSize = 0.5f;
    reverbParams.damping = 0.5f;
    reverbParams.wetLevel = 0.3f;
    reverbParams.dryLevel = 0.7f;
    reverbParams.width = 1.0f;
    reverbParams.freezeMode = 0.0f;

    reverb.setParameters(reverbParams);
}

BioReactiveDSP::~BioReactiveDSP()
{
}

void BioReactiveDSP::prepare(const juce::dsp::ProcessSpec& spec)
{
    currentSampleRate = spec.sampleRate;

    // Prepare reverb (JUCE 7 API)
    reverb.prepare(spec);
    reverb.reset();

    // Prepare delay
    delayLine.prepare(spec);
    delayLine.setMaximumDelayInSamples(static_cast<int>(maxDelayTime * spec.sampleRate / 1000.0));

    // Setup filters
    filterL.setSampleRate(static_cast<float>(spec.sampleRate));
    filterR.setSampleRate(static_cast<float>(spec.sampleRate));

    // Setup compressors
    compressorL.setSampleRate(static_cast<float>(spec.sampleRate));
    compressorR.setSampleRate(static_cast<float>(spec.sampleRate));

    // OPTIMIZATION: Pre-allocate reverb buffer to avoid allocation in audio thread
    // This prevents ~96MB/sec memory churn at 48kHz stereo
    preparedBlockSize = static_cast<int>(spec.maximumBlockSize);
    reverbBuffer.setSize(static_cast<int>(spec.numChannels), preparedBlockSize);
}

void BioReactiveDSP::reset()
{
    reverb.reset();
    delayLine.reset();

    filterL.lowpass = filterL.bandpass = filterL.highpass = 0.0f;
    filterR.lowpass = filterR.bandpass = filterR.highpass = 0.0f;

    compressorL.envelope = 0.0f;
    compressorR.envelope = 0.0f;
}

void BioReactiveDSP::process(juce::AudioBuffer<float>& buffer, float hrv, float coherence)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numChannels == 0 || numSamples == 0)
        return;

    // Modulate parameters based on bio-data
    // HRV affects filter cutoff (0.5-1.0 HRV = 500-10000 Hz)
    float bioFilterCutoff = juce::jmap(hrv, 0.0f, 1.0f, 500.0f, 10000.0f);
    filterL.cutoff = filterR.cutoff = bioFilterCutoff;

    // Coherence affects reverb mix (0-1 Coherence = 0-0.7 reverb)
    float bioReverbMix = juce::jmap(coherence, 0.0f, 1.0f, 0.0f, 0.7f);

    // Process each channel
    for (int channel = 0; channel < numChannels; ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);
        auto& filter = (channel == 0) ? filterL : filterR;
        auto& compressor = (channel == 0) ? compressorL : compressorR;

        for (int sample = 0; sample < numSamples; ++sample)
        {
            float input = channelData[sample];

            // 1. Filter
            float filtered = filter.process(input);

            // 2. Distortion
            float distorted = softClip(filtered);

            // 3. Compression
            float compressed = compressor.process(distorted);

            // 4. Delay (simple)
            delayLine.pushSample(channel, compressed);
            float delaySamples = (delayTime / 1000.0f) * static_cast<float>(currentSampleRate);
            float delayed = delayLine.popSample(channel, delaySamples);
            float withDelay = compressed * 0.7f + delayed * 0.3f;

            channelData[sample] = withDelay;
        }
    }

    // Apply reverb to entire buffer (JUCE 7 API)
    if (reverbMix > 0.01f)
    {
        // OPTIMIZATION: No resize in audio thread - use pre-allocated buffer bounds
        const int safeChannels = juce::jmin(numChannels, reverbBuffer.getNumChannels());
        const int safeSamples = juce::jmin(numSamples, reverbBuffer.getNumSamples());
        jassert(safeSamples >= numSamples);  // Buffer should be pre-allocated in prepare()

        // Copy dry signal to pre-allocated buffer
        for (int ch = 0; ch < safeChannels; ++ch)
            reverbBuffer.copyFrom(ch, 0, buffer, ch, 0, safeSamples);

        // Process reverb using JUCE 7 AudioBlock API
        juce::dsp::AudioBlock<float> block(reverbBuffer);
        juce::dsp::ProcessContextReplacing<float> context(block);
        reverb.process(context);

        // Mix wet/dry based on bio-coherence
        float wetLevel = bioReverbMix;
        float dryLevel = 1.0f - wetLevel;

        for (int ch = 0; ch < safeChannels; ++ch)
        {
            auto* dry = buffer.getReadPointer(ch);
            auto* wet = reverbBuffer.getReadPointer(ch);
            auto* out = buffer.getWritePointer(ch);

            for (int i = 0; i < safeSamples; ++i)
                out[i] = dry[i] * dryLevel + wet[i] * wetLevel;
        }
    }
}

//==============================================================================
void BioReactiveDSP::setFilterCutoff(float cutoffHz)
{
    filterL.cutoff = filterR.cutoff = juce::jlimit(20.0f, 20000.0f, cutoffHz);
}

void BioReactiveDSP::setResonance(float resonance)
{
    filterL.resonance = filterR.resonance = juce::jlimit(0.0f, 1.0f, resonance);
}

void BioReactiveDSP::setReverbMix(float mix)
{
    reverbMix = juce::jlimit(0.0f, 1.0f, mix);
    reverbParams.wetLevel = mix;
    reverbParams.dryLevel = 1.0f - mix;
    reverb.setParameters(reverbParams);
}

void BioReactiveDSP::setDelayTime(float timeMs)
{
    delayTime = juce::jlimit(0.0f, maxDelayTime, timeMs);
}

void BioReactiveDSP::setDistortion(float amount)
{
    distortionAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void BioReactiveDSP::setCompression(float ratio)
{
    compressorL.ratio = compressorR.ratio = juce::jlimit(1.0f, 20.0f, ratio);
}
