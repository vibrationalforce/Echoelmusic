#include "VocalChain.h"
#include "../Core/DSPOptimizations.h"

VocalChain::VocalChain()
{
}

VocalChain::~VocalChain()
{
}

void VocalChain::prepare(double sampleRate, int maximumBlockSize)
{
    currentSampleRate = sampleRate;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<uint32_t>(maximumBlockSize);
    spec.numChannels = 2;

    // Prepare filters
    hpfL.setSampleRate(static_cast<float>(sampleRate));
    hpfR.setSampleRate(static_cast<float>(sampleRate));

    // Prepare de-essers
    deEsserL.setSampleRate(static_cast<float>(sampleRate));
    deEsserR.setSampleRate(static_cast<float>(sampleRate));

    // Prepare compressors
    compressorL.setSampleRate(static_cast<float>(sampleRate));
    compressorR.setSampleRate(static_cast<float>(sampleRate));

    // Prepare EQ filters
    for (auto& filter : eqFilters)
        filter.prepare(spec);

    // Prepare reverb
    reverb.prepare(spec);

    // Pre-allocate reverb buffer (avoid per-frame allocation)
    reverbBuffer.setSize(2, maximumBlockSize);

    // Prepare delay
    delayLine.prepare(spec);
    delayLine.setMaximumDelayInSamples(static_cast<int>(2.0f * sampleRate));  // 2s max

    reset();
}

void VocalChain::reset()
{
    hpfL.reset();
    hpfR.reset();
    deEsserL.reset();
    deEsserR.reset();
    compressorL.reset();
    compressorR.reset();

    for (auto& filter : eqFilters)
        filter.reset();

    reverb.reset();
    delayLine.reset();
}

void VocalChain::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numChannels == 0 || numSamples == 0)
        return;

    // Update cached coefficients ONCE per block (not per sample!)
    hpfL.updateCoefficients();
    hpfR.updateCoefficients();
    compressorL.updateCoefficients();
    compressorR.updateCoefficients();

    // Process each channel through the chain
    for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
    {
        auto* data = buffer.getWritePointer(channel);
        auto& hpf = (channel == 0) ? hpfL : hpfR;
        auto& deEsser = (channel == 0) ? deEsserL : deEsserR;
        auto& compressor = (channel == 0) ? compressorL : compressorR;
        auto& sat = (channel == 0) ? satL : satR;

        for (int sample = 0; sample < numSamples; ++sample)
        {
            float input = data[sample];

            // 1. High-Pass Filter
            if (highPassEnabled)
                input = hpf.process(input);

            // 2. De-Esser
            if (deEsserEnabled)
                input = deEsser.process(input);

            // 3. Compressor
            if (compressorEnabled)
                input = compressor.process(input);

            // 4. EQ (processed separately after loop)
            // 5. Saturation
            if (saturationEnabled)
                input = sat.process(input);

            data[sample] = input;
        }
    }

    // 4. EQ (3-band)
    if (eqEnabled)
    {
        for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
        {
            auto* data = buffer.getWritePointer(channel);
            int baseIndex = channel * 3;

            for (int sample = 0; sample < numSamples; ++sample)
            {
                float input = data[sample];
                float output = input;

                // Low, Mid, High bands
                output = eqFilters[baseIndex + 0].processSample(output);
                output = eqFilters[baseIndex + 1].processSample(output);
                output = eqFilters[baseIndex + 2].processSample(output);

                data[sample] = output;
            }
        }
    }

    // 6. Reverb (uses pre-allocated buffer)
    if (reverbEnabled && reverbMix > 0.01f)
    {
        // Ensure buffer is large enough (resize only if needed)
        if (reverbBuffer.getNumSamples() < numSamples)
            reverbBuffer.setSize(numChannels, numSamples, false, false, true);

        for (int ch = 0; ch < juce::jmin(numChannels, reverbBuffer.getNumChannels()); ++ch)
            reverbBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

        juce::dsp::AudioBlock<float> block(reverbBuffer.getArrayOfWritePointers(),
                                           static_cast<size_t>(juce::jmin(numChannels, reverbBuffer.getNumChannels())),
                                           static_cast<size_t>(numSamples));
        juce::dsp::ProcessContextReplacing<float> context(block);
        reverb.process(context);

        // Mix wet
        for (int ch = 0; ch < juce::jmin(numChannels, reverbBuffer.getNumChannels()); ++ch)
            buffer.addFrom(ch, 0, reverbBuffer, ch, 0, numSamples, reverbMix);
    }

    // 7. Delay
    if (delayEnabled && delayMix > 0.01f)
    {
        float delaySamples = delayTime * 0.001f * static_cast<float>(currentSampleRate);

        for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
        {
            auto* data = buffer.getWritePointer(channel);

            for (int sample = 0; sample < numSamples; ++sample)
            {
                float input = data[sample];
                float delayed = delayLine.popSample(channel, delaySamples);
                float feedback = delayed * delayFeedback;
                delayLine.pushSample(channel, input + feedback);
                data[sample] += delayed * delayMix;
            }
        }
    }
}

//==============================================================================
// Module Bypass
void VocalChain::setHighPassEnabled(bool enabled) { highPassEnabled = enabled; }
void VocalChain::setDeEsserEnabled(bool enabled) { deEsserEnabled = enabled; }
void VocalChain::setCompressorEnabled(bool enabled) { compressorEnabled = enabled; }
void VocalChain::setEQEnabled(bool enabled) { eqEnabled = enabled; }
void VocalChain::setSaturationEnabled(bool enabled) { saturationEnabled = enabled; }
void VocalChain::setReverbEnabled(bool enabled) { reverbEnabled = enabled; }
void VocalChain::setDelayEnabled(bool enabled) { delayEnabled = enabled; }

//==============================================================================
// Parameters
void VocalChain::setHighPassFreq(float freq)
{
    hpFreq = freq;
    hpfL.setCutoff(freq);
    hpfR.setCutoff(freq);
}

void VocalChain::setDeEsserThreshold(float threshold)
{
    deEsserThresh = threshold;
    deEsserL.threshold = threshold;
    deEsserR.threshold = threshold;
}

void VocalChain::setDeEsserFreq(float freq)
{
    deEsserFreq = freq;
    deEsserL.freq = freq;
    deEsserR.freq = freq;
}

void VocalChain::setCompressorThreshold(float threshold)
{
    compThreshold = threshold;
    compressorL.threshold = threshold;
    compressorR.threshold = threshold;
}

void VocalChain::setCompressorRatio(float ratio)
{
    compRatio = ratio;
    compressorL.ratio = ratio;
    compressorR.ratio = ratio;
}

void VocalChain::setCompressorAttack(float ms)
{
    compAttack = ms;
    compressorL.setAttack(ms);
    compressorR.setAttack(ms);
}

void VocalChain::setCompressorRelease(float ms)
{
    compRelease = ms;
    compressorL.setRelease(ms);
    compressorR.setRelease(ms);
}

void VocalChain::setCompressorMakeup(float dB)
{
    compMakeup = dB;
    compressorL.makeup = dB;
    compressorR.makeup = dB;
}

void VocalChain::setEQLowGain(float dB)
{
    eqLowGain = dB;
    // Update filter coefficients for low shelf @ 200 Hz
    auto coeffs = juce::dsp::IIR::Coefficients<float>::makeLowShelf(
        currentSampleRate, 200.0f, 0.7f, Echoel::DSP::FastMath::dbToGain(dB)
    );
    eqFilters[0].coefficients = coeffs;  // L
    eqFilters[3].coefficients = coeffs;  // R
}

void VocalChain::setEQMidGain(float dB)
{
    eqMidGain = dB;
    // Update filter coefficients for peak @ 2000 Hz
    auto coeffs = juce::dsp::IIR::Coefficients<float>::makePeakFilter(
        currentSampleRate, 2000.0f, 1.0f, Echoel::DSP::FastMath::dbToGain(dB)
    );
    eqFilters[1].coefficients = coeffs;  // L
    eqFilters[4].coefficients = coeffs;  // R
}

void VocalChain::setEQHighGain(float dB)
{
    eqHighGain = dB;
    // Update filter coefficients for high shelf @ 8000 Hz
    auto coeffs = juce::dsp::IIR::Coefficients<float>::makeHighShelf(
        currentSampleRate, 8000.0f, 0.7f, Echoel::DSP::FastMath::dbToGain(dB)
    );
    eqFilters[2].coefficients = coeffs;  // L
    eqFilters[5].coefficients = coeffs;  // R
}

void VocalChain::setSaturationDrive(float drive)
{
    satDrive = juce::jlimit(0.0f, 1.0f, drive);
    satL.drive = satDrive;
    satR.drive = satDrive;
}

void VocalChain::setSaturationTone(float tone)
{
    satTone = juce::jlimit(0.0f, 1.0f, tone);
    satL.tone = satTone;
    satR.tone = satTone;
}

void VocalChain::setReverbSize(float size)
{
    reverbSize = juce::jlimit(0.0f, 1.0f, size);
    juce::dsp::Reverb::Parameters params;
    params.roomSize = size;
    params.damping = 0.5f;
    params.wetLevel = 1.0f;
    params.dryLevel = 0.0f;
    params.width = 1.0f;
    reverb.setParameters(params);
}

void VocalChain::setReverbMix(float mix)
{
    reverbMix = juce::jlimit(0.0f, 1.0f, mix);
}

void VocalChain::setDelayTime(float ms)
{
    delayTime = juce::jlimit(0.0f, 2000.0f, ms);
}

void VocalChain::setDelayFeedback(float feedback)
{
    delayFeedback = juce::jlimit(0.0f, 0.9f, feedback);
}

void VocalChain::setDelayMix(float mix)
{
    delayMix = juce::jlimit(0.0f, 1.0f, mix);
}

//==============================================================================
// Presets
void VocalChain::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::ModernPop:
            // Bright, present, radio-ready
            setHighPassFreq(100.0f);
            setDeEsserThreshold(-18.0f);
            setCompressorThreshold(-18.0f);
            setCompressorRatio(4.0f);
            setCompressorAttack(5.0f);
            setCompressorRelease(50.0f);
            setCompressorMakeup(8.0f);
            setEQLowGain(-2.0f);
            setEQMidGain(3.0f);
            setEQHighGain(4.0f);
            setSaturationDrive(0.4f);
            setSaturationTone(0.7f);
            setReverbSize(0.3f);
            setReverbMix(0.15f);
            setDelayTime(250.0f);
            setDelayMix(0.1f);
            break;

        case Preset::WarmRnB:
            // Smooth, intimate, rich
            setHighPassFreq(80.0f);
            setDeEsserThreshold(-22.0f);
            setCompressorThreshold(-22.0f);
            setCompressorRatio(3.0f);
            setCompressorAttack(10.0f);
            setCompressorRelease(150.0f);
            setCompressorMakeup(6.0f);
            setEQLowGain(3.0f);
            setEQMidGain(2.0f);
            setEQHighGain(1.0f);
            setSaturationDrive(0.5f);
            setSaturationTone(0.4f);
            setReverbSize(0.5f);
            setReverbMix(0.25f);
            setDelayTime(375.0f);
            setDelayMix(0.15f);
            break;

        case Preset::AggressiveRap:
            // Punchy, in-your-face, clear
            setHighPassFreq(120.0f);
            setDeEsserThreshold(-16.0f);
            setCompressorThreshold(-16.0f);
            setCompressorRatio(6.0f);
            setCompressorAttack(3.0f);
            setCompressorRelease(30.0f);
            setCompressorMakeup(10.0f);
            setEQLowGain(4.0f);
            setEQMidGain(5.0f);
            setEQHighGain(2.0f);
            setSaturationDrive(0.6f);
            setSaturationTone(0.8f);
            setReverbSize(0.2f);
            setReverbMix(0.08f);
            setDelayTime(125.0f);
            setDelayMix(0.05f);
            break;

        case Preset::IntimateSingerSongwriter:
            // Natural, close, emotional
            setHighPassFreq(60.0f);
            setDeEsserThreshold(-24.0f);
            setCompressorThreshold(-24.0f);
            setCompressorRatio(2.5f);
            setCompressorAttack(15.0f);
            setCompressorRelease(200.0f);
            setCompressorMakeup(4.0f);
            setEQLowGain(1.0f);
            setEQMidGain(1.0f);
            setEQHighGain(-1.0f);
            setSaturationDrive(0.2f);
            setSaturationTone(0.5f);
            setReverbSize(0.4f);
            setReverbMix(0.2f);
            setDelayTime(500.0f);
            setDelayMix(0.12f);
            break;

        case Preset::BroadcastPodcast:
            // Clear, intelligible, consistent
            setHighPassFreq(100.0f);
            setDeEsserThreshold(-20.0f);
            setCompressorThreshold(-20.0f);
            setCompressorRatio(5.0f);
            setCompressorAttack(5.0f);
            setCompressorRelease(80.0f);
            setCompressorMakeup(12.0f);
            setEQLowGain(-3.0f);
            setEQMidGain(6.0f);  // Boost presence
            setEQHighGain(2.0f);
            setSaturationDrive(0.3f);
            setSaturationTone(0.6f);
            setReverbSize(0.15f);
            setReverbMix(0.05f);  // Minimal reverb
            setDelayTime(0.0f);
            setDelayMix(0.0f);  // No delay
            break;

        case Preset::ChoirBackground:
            // Wide, smooth, blended
            setHighPassFreq(80.0f);
            setDeEsserThreshold(-26.0f);
            setCompressorThreshold(-26.0f);
            setCompressorRatio(2.0f);
            setCompressorAttack(20.0f);
            setCompressorRelease(300.0f);
            setCompressorMakeup(3.0f);
            setEQLowGain(0.0f);
            setEQMidGain(-2.0f);
            setEQHighGain(-3.0f);  // Softer
            setSaturationDrive(0.1f);
            setSaturationTone(0.3f);
            setReverbSize(0.7f);  // Large space
            setReverbMix(0.4f);  // Wet
            setDelayTime(625.0f);
            setDelayMix(0.2f);
            break;
    }
}
