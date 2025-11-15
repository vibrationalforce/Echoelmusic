#include "Vocoder.h"

Vocoder::Vocoder()
{
}

Vocoder::~Vocoder()
{
}

void Vocoder::prepare(double sampleRate, int maximumBlockSize)
{
    currentSampleRate = sampleRate;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<uint32_t>(maximumBlockSize);
    spec.numChannels = 1;  // Process mono per band

    // Prepare all bands
    for (auto& band : bandsL)
        band.prepare(spec);

    for (auto& band : bandsR)
        band.prepare(spec);

    // Prepare sibilance preservers
    sibilanceL.prepare(spec);
    sibilanceR.prepare(spec);

    // Initialize oscillators
    oscillatorL.setSampleRate(static_cast<float>(sampleRate));
    oscillatorL.setFrequency(carrierFrequency);
    oscillatorL.setType(carrierType);

    oscillatorR.setSampleRate(static_cast<float>(sampleRate));
    oscillatorR.setFrequency(carrierFrequency);
    oscillatorR.setType(carrierType);

    // Update band frequencies
    updateBandFrequencies();

    reset();
}

void Vocoder::reset()
{
    for (auto& band : bandsL)
        band.reset();

    for (auto& band : bandsR)
        band.reset();

    sibilanceL.reset();
    sibilanceR.reset();

    oscillatorL.reset();
    oscillatorR.reset();
}

void Vocoder::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numChannels == 0 || numSamples == 0)
        return;

    // Store dry signal (modulator)
    juce::AudioBuffer<float> dryBuffer(numChannels, numSamples);
    for (int ch = 0; ch < numChannels; ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // Process each channel
    for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
    {
        auto* modulatorData = dryBuffer.getReadPointer(channel);
        auto* outputData = buffer.getWritePointer(channel);
        auto& bands = (channel == 0) ? bandsL : bandsR;
        auto& oscillator = (channel == 0) ? oscillatorL : oscillatorR;
        auto& sibilance = (channel == 0) ? sibilanceL : sibilanceR;

        for (int sample = 0; sample < numSamples; ++sample)
        {
            float modulatorSample = modulatorData[sample];

            // Generate carrier signal
            float carrierSample = 0.0f;
            if (carrierType < 3)  // Internal oscillator
            {
                carrierSample = oscillator.generate();
            }
            else  // External carrier (use modulator as carrier)
            {
                carrierSample = modulatorSample;
            }

            // Process through all bands
            float vocodedOutput = 0.0f;
            for (int b = 0; b < currentBandCount; ++b)
            {
                vocodedOutput += bands[b].process(carrierSample, modulatorSample);
            }

            // Normalize by band count
            vocodedOutput /= static_cast<float>(currentBandCount);

            // Add sibilance preservation
            if (currentSibilance > 0.01f)
            {
                sibilance.amount = currentSibilance;
                vocodedOutput = sibilance.process(vocodedOutput, modulatorSample);
            }

            outputData[sample] = vocodedOutput;
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
void Vocoder::setBandCount(int bands)
{
    currentBandCount = juce::jlimit(8, 32, bands);
    updateBandFrequencies();
}

void Vocoder::setCarrierType(int type)
{
    carrierType = juce::jlimit(0, 3, type);
    oscillatorL.setType(type);
    oscillatorR.setType(type);
}

void Vocoder::setCarrierFrequency(float hz)
{
    carrierFrequency = juce::jlimit(50.0f, 500.0f, hz);
    oscillatorL.setFrequency(hz);
    oscillatorR.setFrequency(hz);
}

void Vocoder::setBandWidth(float width)
{
    currentBandWidth = juce::jlimit(0.0f, 1.0f, width);
    updateBandFrequencies();
}

void Vocoder::setAttack(float ms)
{
    currentAttack = juce::jlimit(0.1f, 100.0f, ms);
    updateBandFrequencies();
}

void Vocoder::setRelease(float ms)
{
    currentRelease = juce::jlimit(10.0f, 1000.0f, ms);
    updateBandFrequencies();
}

void Vocoder::setSibilance(float amount)
{
    currentSibilance = juce::jlimit(0.0f, 1.0f, amount);
}

void Vocoder::setMix(float mix)
{
    currentMix = juce::jlimit(0.0f, 1.0f, mix);
}
