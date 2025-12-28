#include "PassiveEQ.h"
#include "../Core/DSPOptimizations.h"

PassiveEQ::PassiveEQ() {}
PassiveEQ::~PassiveEQ() {}

void PassiveEQ::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    juce::ignoreUnused(numChannels);
    currentSampleRate = sampleRate;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<juce::uint32>(samplesPerBlock);
    spec.numChannels = 1;

    for (auto& state : eqState)
    {
        state.lowBoostFilter.prepare(spec);
        state.lowCutFilter.prepare(spec);
        state.highBoostFilter.prepare(spec);
        state.highCutFilter.prepare(spec);
    }

    reset();
    updateFilters();
}

void PassiveEQ::reset()
{
    for (auto& state : eqState)
    {
        state.lowBoostFilter.reset();
        state.lowCutFilter.reset();
        state.highBoostFilter.reset();
        state.highCutFilter.reset();
    }
    inputLevelSmooth.fill(0.0f);
    outputLevelSmooth.fill(0.0f);
}

void PassiveEQ::process(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < numChannels; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);
        for (int sample = 0; sample < numSamples; ++sample)
            channelData[sample] = processSample(channelData[sample], channel);
    }
}

float PassiveEQ::processSample(float sample, int channel)
{
    if (channel >= 2) return sample;

    float inputLevel = std::abs(sample);
    inputLevelSmooth[channel] = inputLevel * 0.1f + inputLevelSmooth[channel] * 0.9f;

    auto& eq = eqState[channel];

    // Pultec EQ chain
    // 1. Low boost
    if (lowBoost > 0.1f)
        sample = eq.lowBoostFilter.processSample(sample);

    // 2. Low attenuation (can be simultaneous with boost - "Pultec trick")
    if (lowAttenuation > 0.1f)
        sample = eq.lowCutFilter.processSample(sample);

    // 3. High boost
    if (highBoost > 0.1f)
        sample = eq.highBoostFilter.processSample(sample);

    // 4. High attenuation
    if (highAttenuation > 0.1f)
        sample = eq.highCutFilter.processSample(sample);

    // 5. Tube makeup stage
    sample = processTubeStage(sample);

    // 6. Output transformer
    sample = processTransformer(sample);

    float outputLevel = std::abs(sample);
    outputLevelSmooth[channel] = outputLevel * 0.1f + outputLevelSmooth[channel] * 0.9f;

    return sample;
}

void PassiveEQ::setLowBoost(float boostDb)
{
    lowBoost = juce::jlimit(0.0f, 10.0f, boostDb);
    updateFilters();
}

void PassiveEQ::setLowBoostFrequency(int freqIndex)
{
    lowBoostFreqIndex = juce::jlimit(0, 3, freqIndex);
    updateFilters();
}

void PassiveEQ::setLowAttenuation(float attenuationDb)
{
    lowAttenuation = juce::jlimit(0.0f, 10.0f, attenuationDb);
    updateFilters();
}

void PassiveEQ::setLowAttenuationFrequency(int freqIndex)
{
    lowAttenuationFreqIndex = juce::jlimit(0, 3, freqIndex);
    updateFilters();
}

void PassiveEQ::setHighBoost(float boostDb)
{
    highBoost = juce::jlimit(0.0f, 18.0f, boostDb);
    updateFilters();
}

void PassiveEQ::setHighBoostFrequency(int freqIndex)
{
    highBoostFreqIndex = juce::jlimit(0, 6, freqIndex);
    updateFilters();
}

void PassiveEQ::setHighAttenuation(float attenuationDb)
{
    highAttenuation = juce::jlimit(0.0f, 10.0f, attenuationDb);
    updateFilters();
}

void PassiveEQ::setLowBandwidth(float q)
{
    lowQ = juce::jlimit(0.5f, 2.0f, q);
    updateFilters();
}

void PassiveEQ::setHighBandwidth(float q)
{
    highQ = juce::jlimit(0.5f, 2.0f, q);
    updateFilters();
}

void PassiveEQ::setTubeWarmth(float amount)
{
    tubeWarmth = juce::jlimit(0.0f, 1.0f, amount);
}

void PassiveEQ::setOutputTransformer(float amount)
{
    outputTransformer = juce::jlimit(0.0f, 1.0f, amount);
}

void PassiveEQ::updateFilters()
{
    // Pultec uses shelving filters with gentle, musical curves
    float lowBoostFreq = LOW_FREQUENCIES[lowBoostFreqIndex];
    float lowCutFreq = LOW_FREQUENCIES[lowAttenuationFreqIndex];
    float highBoostFreq = HIGH_FREQUENCIES[highBoostFreqIndex];

    for (auto& eq : eqState)
    {
        // Low boost (shelving)
        *eq.lowBoostFilter.coefficients = *juce::dsp::IIR::Coefficients<float>::makeLowShelf(
            currentSampleRate, lowBoostFreq, lowQ, juce::Decibels::decibelsToGain(lowBoost));

        // Low cut (shelving - inverted)
        *eq.lowCutFilter.coefficients = *juce::dsp::IIR::Coefficients<float>::makeLowShelf(
            currentSampleRate, lowCutFreq, lowQ, juce::Decibels::decibelsToGain(-lowAttenuation));

        // High boost (shelving)
        *eq.highBoostFilter.coefficients = *juce::dsp::IIR::Coefficients<float>::makeHighShelf(
            currentSampleRate, highBoostFreq, highQ, juce::Decibels::decibelsToGain(highBoost));

        // High cut (shelving)
        *eq.highCutFilter.coefficients = *juce::dsp::IIR::Coefficients<float>::makeHighShelf(
            currentSampleRate, 10000.0f, 0.7f, juce::Decibels::decibelsToGain(-highAttenuation));
    }
}

float PassiveEQ::processTubeStage(float sample)
{
    if (tubeWarmth < 0.01f) return sample;

    // 12AX7 tube coloration
    float drive = 1.0f + tubeWarmth * 1.5f;
    float x = sample * drive;

    // Tube saturation (2nd harmonic emphasis) - using fast tanh
    float saturated = x + 0.15f * tubeWarmth * x * x;
    saturated = Echoel::DSP::FastMath::fastTanh(saturated);

    return saturated / drive;
}

float PassiveEQ::processTransformer(float sample)
{
    if (outputTransformer < 0.01f) return sample;

    // Output transformer saturation
    float drive = 1.0f + outputTransformer * 0.5f;
    float x = sample * drive;

    // Transformer hysteresis
    float saturated = x + 0.1f * outputTransformer * x * x;
    saturated = saturated / (1.0f + 0.2f * outputTransformer * std::abs(saturated));

    return saturated / drive;
}

float PassiveEQ::getInputLevel(int channel) const
{
    return (channel < 2) ? inputLevelSmooth[channel] : 0.0f;
}

float PassiveEQ::getOutputLevel(int channel) const
{
    return (channel < 2) ? outputLevelSmooth[channel] : 0.0f;
}

void PassiveEQ::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::Flat:
            setLowBoost(0.0f);
            setLowAttenuation(0.0f);
            setHighBoost(0.0f);
            setHighAttenuation(0.0f);
            setTubeWarmth(0.3f);
            setOutputTransformer(0.3f);
            break;

        case Preset::PultecTrick:
            // Famous "boost + cut at same frequency" = tight punch
            setLowBoost(5.0f);
            setLowBoostFrequency(2);  // 60Hz
            setLowAttenuation(4.0f);
            setLowAttenuationFrequency(2);  // 60Hz
            setLowBandwidth(0.7f);
            setTubeWarmth(0.6f);
            break;

        case Preset::VocalAir:
            setHighBoost(6.0f);
            setHighBoostFrequency(4);  // 10kHz
            setHighBandwidth(0.8f);
            setTubeWarmth(0.5f);
            setOutputTransformer(0.4f);
            break;

        case Preset::KickPunch:
            setLowBoost(6.0f);
            setLowBoostFrequency(2);  // 60Hz
            setLowAttenuation(3.0f);
            setLowAttenuationFrequency(1);  // 30Hz (tighten)
            setHighBoost(3.0f);
            setHighBoostFrequency(3);  // 8kHz (click)
            setTubeWarmth(0.7f);
            break;

        case Preset::MixBusGlue:
            setLowBoost(2.0f);
            setLowBoostFrequency(3);  // 100Hz
            setHighBoost(2.0f);
            setHighBoostFrequency(5);  // 12kHz
            setTubeWarmth(0.6f);
            setOutputTransformer(0.6f);
            break;

        case Preset::VintageWarmth:
            setLowBoost(4.0f);
            setLowBoostFrequency(2);  // 60Hz
            setHighBoost(4.0f);
            setHighBoostFrequency(4);  // 10kHz
            setTubeWarmth(0.9f);
            setOutputTransformer(0.8f);
            break;

        case Preset::ModernBright:
            setHighBoost(8.0f);
            setHighBoostFrequency(6);  // 16kHz
            setHighBandwidth(0.5f);  // Sharp
            setTubeWarmth(0.2f);
            setOutputTransformer(0.2f);
            break;
    }
}
