#include "OptoCompressor.h"

OptoCompressor::OptoCompressor()
{
}

OptoCompressor::~OptoCompressor()
{
}

//==============================================================================
// Processing

void OptoCompressor::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    juce::ignoreUnused(samplesPerBlock);

    currentSampleRate = sampleRate;
    currentNumChannels = numChannels;

    reset();
    updateOpticalCellCoefficients();
    updateSidechainHPFCoefficients();
}

void OptoCompressor::reset()
{
    for (auto& cell : opticalCell)
    {
        cell.lightLevel = 0.0f;
        cell.resistance = 1.0f;
    }

    for (auto& hpf : hpfState)
    {
        hpf.z1 = hpf.z2 = 0.0f;
    }

    inputLevelSmooth.fill(0.0f);
    outputLevelSmooth.fill(0.0f);
    gainReductionSmooth = 0.0f;
    opticalCellStateSmooth = 0.0f;
}

void OptoCompressor::process(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Stereo linking: average sidechain signal
        float linkedSidechain = 0.0f;
        if (numChannels >= 2 && stereoLink > 0.01f)
        {
            float left = buffer.getSample(0, sample);
            float right = buffer.getSample(1, sample);
            linkedSidechain = (std::abs(left) + std::abs(right)) * 0.5f;
        }

        for (int channel = 0; channel < numChannels; ++channel)
        {
            float channelSample = buffer.getSample(channel, sample);
            float sidechain = (stereoLink > 0.01f) ? linkedSidechain : std::abs(channelSample);
            float processed = processSample(channelSample, channel);
            buffer.setSample(channel, sample, processed);
        }
    }
}

float OptoCompressor::processSample(float sample, int channel)
{
    if (channel >= 2) return sample;

    // Input metering
    float inputLevel = std::abs(sample);
    inputLevelSmooth[channel] = inputLevel * 0.1f + inputLevelSmooth[channel] * 0.9f;

    // LA-2A Signal Chain:

    // 1. Sidechain HPF (if enabled)
    float sidechainSignal = sample;
    if (sidechainHPF > 0.0f)
        sidechainSignal = processSidechainHPF(sample, channel);

    // 2. Optical Compression (T4 Cell)
    sample = processOpticalCompression(sample, channel, sidechainSignal);

    // 3. Tube Makeup Gain Stage (12AX7)
    sample = processTubeStage(sample);

    // 4. Output Transformer
    sample = processOutputTransformer(sample);

    // Output metering
    float outputLevel = std::abs(sample);
    outputLevelSmooth[channel] = outputLevel * 0.1f + outputLevelSmooth[channel] * 0.9f;

    return sample;
}

//==============================================================================
// Controls

void OptoCompressor::setPeakReduction(float amount)
{
    peakReduction = juce::jlimit(0.0f, 1.0f, amount);
}

void OptoCompressor::setMakeupGain(float gainDb)
{
    makeupGain = juce::jlimit(0.0f, 40.0f, gainDb);
}

void OptoCompressor::setCompressLimitMode(bool limit)
{
    limitMode = limit;
}

void OptoCompressor::setAttackTime(float timeMs)
{
    attackTimeMs = juce::jlimit(5.0f, 50.0f, timeMs);
    updateOpticalCellCoefficients();
}

void OptoCompressor::setReleaseTime(float timeMs)
{
    releaseTimeMs = juce::jlimit(60.0f, 5000.0f, timeMs);
    updateOpticalCellCoefficients();
}

void OptoCompressor::setOpticalCharacter(float amount)
{
    opticalCharacter = juce::jlimit(0.0f, 1.0f, amount);
}

void OptoCompressor::setTubeWarmth(float amount)
{
    tubeWarmth = juce::jlimit(0.0f, 1.0f, amount);
}

void OptoCompressor::setOutputTransformer(float amount)
{
    outputTransformer = juce::jlimit(0.0f, 1.0f, amount);
}

void OptoCompressor::setSidechainHPF(float frequency)
{
    sidechainHPF = juce::jlimit(0.0f, 500.0f, frequency);
    updateSidechainHPFCoefficients();
}

void OptoCompressor::setStereoLink(float amount)
{
    stereoLink = juce::jlimit(0.0f, 1.0f, amount);
}

//==============================================================================
// Optical Cell

void OptoCompressor::updateOpticalCellCoefficients()
{
    // T4 optical cell characteristics
    // Attack: how fast the light panel illuminates (10ms typical)
    // Release: how fast the photoresistor returns to rest (60ms-5s)

    float attackSeconds = attackTimeMs / 1000.0f;
    float releaseSeconds = releaseTimeMs / 1000.0f;

    for (auto& cell : opticalCell)
    {
        // Exponential envelope followers
        cell.attackCoeff = std::exp(-1.0f / (static_cast<float>(currentSampleRate) * attackSeconds));
        cell.releaseCoeff = std::exp(-1.0f / (static_cast<float>(currentSampleRate) * releaseSeconds));
    }
}

float OptoCompressor::processOpticalCompression(float sample, int channel, float sidechainSignal)
{
    auto& cell = opticalCell[channel];

    // Convert to dB for processing
    float inputDb = juce::Decibels::gainToDecibels(std::abs(sidechainSignal) + 1e-6f);

    // Determine threshold based on peak reduction amount
    float threshold = -20.0f + (peakReduction * 30.0f);  // -20dB to +10dB range

    // Calculate optical cell response
    float gainReduction = opticalCellResponse(inputDb, cell.lightLevel, cell.resistance, channel);

    // Apply gain reduction
    float outputGain = juce::Decibels::decibelsToGain(gainReduction + makeupGain);
    float compressed = sample * outputGain;

    // Update metering
    gainReductionSmooth = gainReduction * 0.1f + gainReductionSmooth * 0.9f;
    opticalCellStateSmooth = cell.lightLevel * 0.1f + opticalCellStateSmooth * 0.9f;

    return compressed;
}

float OptoCompressor::opticalCellResponse(float inputDb, float& lightLevel, float& resistance, int channel)
{
    auto& cell = opticalCell[channel];

    // Determine threshold based on mode and peak reduction
    float threshold = limitMode ? 0.0f : (-20.0f + peakReduction * 30.0f);

    // Calculate how much over threshold
    float overThreshold = inputDb - threshold;

    // T4 Cell Light Panel Brightness
    // The electro-luminescent panel brightness follows input level
    float targetLightLevel = juce::jlimit(0.0f, 1.0f, overThreshold / 40.0f);

    // Attack/Release envelope for light level
    if (targetLightLevel > lightLevel)
    {
        // Attack: light panel illuminates
        lightLevel = targetLightLevel + cell.attackCoeff * (lightLevel - targetLightLevel);
    }
    else
    {
        // Release: light panel dims (program-dependent)
        // LA-2A has slower release for sustained signals
        float releaseCoeff = cell.releaseCoeff;

        // Program-dependent release: faster for transients
        if (overThreshold < 0.0f && lightLevel > 0.5f)
            releaseCoeff *= 0.7f;  // Faster release

        lightLevel = targetLightLevel + releaseCoeff * (lightLevel - targetLightLevel);
    }

    // Photoresistor Resistance
    // The photoresistor resistance decreases as light increases (non-linear)
    float baseResistance = 10.0f;  // Dark resistance (MΩ)
    float minResistance = 0.1f;    // Bright resistance (kΩ)

    // Non-linear optical coupling (T4 characteristic)
    float coupling = opticalCharacter;
    resistance = minResistance + (baseResistance - minResistance) * std::pow(1.0f - lightLevel, 2.0f + coupling);

    // Convert resistance to gain reduction
    // Lower resistance = more attenuation
    float compressionRatio = limitMode ? 20.0f : 3.0f;  // Limit vs Compress mode

    float gainReduction = 0.0f;
    if (overThreshold > 0.0f)
    {
        // Gentle optical compression curve
        float compressionAmount = overThreshold * (1.0f - 1.0f / compressionRatio);

        // Optical cell "smoothness" - impossible to sound harsh
        compressionAmount *= (1.0f - resistance / baseResistance);

        gainReduction = -compressionAmount;
    }

    // Soft knee (optical cells have gradual onset)
    float kneeWidth = 6.0f;
    if (std::abs(overThreshold) < kneeWidth)
    {
        float kneeRatio = (overThreshold + kneeWidth) / (2.0f * kneeWidth);
        gainReduction *= kneeRatio;
    }

    return gainReduction;
}

//==============================================================================
// Tube Stage

float OptoCompressor::processTubeStage(float sample)
{
    if (tubeWarmth < 0.01f)
        return sample;

    return tubeSaturation(sample, tubeWarmth);
}

float OptoCompressor::tubeSaturation(float sample, float warmth)
{
    // 12AX7 tube saturation (LA-2A makeup gain stage)
    // High gain, low plate voltage = smooth saturation

    float drive = 1.0f + warmth * 3.0f;
    float x = sample * drive;

    // 12AX7 characteristic curve (soft asymmetric clipping)
    float asymmetry = 0.15f * warmth;
    x += asymmetry * x * x;  // Even harmonics

    // Soft clipping
    float saturated = x / (1.0f + 0.4f * std::abs(x));

    // Tube "glow" on transients
    if (std::abs(x) > 0.7f)
    {
        float excess = std::abs(x) - 0.7f;
        saturated += warmth * 0.1f * excess * std::tanh(excess * 5.0f);
    }

    return saturated / drive;
}

//==============================================================================
// Output Transformer

float OptoCompressor::processOutputTransformer(float sample)
{
    if (outputTransformer < 0.01f)
        return sample;

    return transformerColoration(sample, outputTransformer);
}

float OptoCompressor::transformerColoration(float sample, float amount)
{
    // LA-2A output transformer (iron core)
    // Adds warmth and slight compression

    float drive = 1.0f + amount * 0.5f;
    float x = sample * drive;

    // Transformer saturation (hysteresis)
    float harmonic2 = 0.1f * amount * x * x;
    float harmonic3 = 0.05f * amount * x * x * x;

    float saturated = x + harmonic2 + harmonic3;

    // Soft saturation
    saturated = saturated / (1.0f + 0.2f * amount * std::abs(saturated));

    return saturated / drive;
}

//==============================================================================
// Sidechain HPF

void OptoCompressor::updateSidechainHPFCoefficients()
{
    if (sidechainHPF < 1.0f)
        return;

    // 12dB/oct Butterworth High-Pass
    float omega = 2.0f * juce::MathConstants<float>::pi * sidechainHPF / static_cast<float>(currentSampleRate);
    float sinOmega = std::sin(omega);
    float cosOmega = std::cos(omega);
    float alpha = sinOmega / (2.0f * 0.707f);

    float a0 = 1.0f + alpha;
    float a1 = -2.0f * cosOmega;
    float a2 = 1.0f - alpha;
    float b0 = (1.0f + cosOmega) / 2.0f;
    float b1 = -(1.0f + cosOmega);
    float b2 = (1.0f + cosOmega) / 2.0f;

    for (auto& hpf : hpfState)
    {
        hpf.b0 = b0 / a0;
        hpf.b1 = b1 / a0;
        hpf.b2 = b2 / a0;
        hpf.a1 = a1 / a0;
        hpf.a2 = a2 / a0;
    }
}

float OptoCompressor::processSidechainHPF(float sample, int channel)
{
    if (sidechainHPF < 1.0f)
        return sample;

    auto& hpf = hpfState[channel];

    float output = hpf.b0 * sample + hpf.b1 * hpf.z1 + hpf.b2 * hpf.z2
                   - hpf.a1 * hpf.z1 - hpf.a2 * hpf.z2;

    hpf.z2 = hpf.z1;
    hpf.z1 = sample;

    return output;
}

//==============================================================================
// Metering

float OptoCompressor::getGainReduction() const
{
    return gainReductionSmooth;
}

float OptoCompressor::getInputLevel(int channel) const
{
    return (channel < 2) ? inputLevelSmooth[channel] : 0.0f;
}

float OptoCompressor::getOutputLevel(int channel) const
{
    return (channel < 2) ? outputLevelSmooth[channel] : 0.0f;
}

float OptoCompressor::getOpticalCellState() const
{
    return opticalCellStateSmooth;
}

//==============================================================================
// Presets

void OptoCompressor::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::Vintage:
            setPeakReduction(0.5f);
            setMakeupGain(10.0f);
            setCompressLimitMode(false);
            setAttackTime(10.0f);
            setReleaseTime(500.0f);
            setOpticalCharacter(0.7f);
            setTubeWarmth(0.6f);
            setOutputTransformer(0.7f);
            setStereoLink(1.0f);
            break;

        case Preset::VocalSmooth:
            setPeakReduction(0.4f);
            setMakeupGain(12.0f);
            setCompressLimitMode(false);
            setAttackTime(10.0f);
            setReleaseTime(400.0f);
            setOpticalCharacter(0.8f);
            setTubeWarmth(0.5f);
            setSidechainHPF(100.0f);
            setStereoLink(0.0f);
            break;

        case Preset::VocalAggressive:
            setPeakReduction(0.7f);
            setMakeupGain(18.0f);
            setCompressLimitMode(false);
            setAttackTime(8.0f);
            setReleaseTime(200.0f);
            setOpticalCharacter(0.6f);
            setTubeWarmth(0.7f);
            setSidechainHPF(120.0f);
            break;

        case Preset::Bass:
            setPeakReduction(0.6f);
            setMakeupGain(15.0f);
            setCompressLimitMode(false);
            setAttackTime(15.0f);
            setReleaseTime(600.0f);
            setOpticalCharacter(0.9f);
            setTubeWarmth(0.8f);
            setOutputTransformer(0.8f);
            setStereoLink(1.0f);
            break;

        case Preset::MixBus:
            setPeakReduction(0.3f);
            setMakeupGain(6.0f);
            setCompressLimitMode(false);
            setAttackTime(12.0f);
            setReleaseTime(800.0f);
            setOpticalCharacter(0.7f);
            setTubeWarmth(0.4f);
            setOutputTransformer(0.6f);
            setStereoLink(1.0f);
            break;

        case Preset::DrumRoom:
            setPeakReduction(0.5f);
            setMakeupGain(14.0f);
            setCompressLimitMode(false);
            setAttackTime(20.0f);
            setReleaseTime(300.0f);
            setOpticalCharacter(0.6f);
            setTubeWarmth(0.6f);
            setStereoLink(1.0f);
            break;

        case Preset::Limiting:
            setPeakReduction(0.8f);
            setMakeupGain(20.0f);
            setCompressLimitMode(true);
            setAttackTime(5.0f);
            setReleaseTime(100.0f);
            setOpticalCharacter(0.5f);
            setTubeWarmth(0.3f);
            break;

        case Preset::AllButtons:
            // "All buttons in" secret LA-2A mode (Compress + Limit simultaneously)
            // Creates unique heavy compression
            setPeakReduction(0.9f);
            setMakeupGain(25.0f);
            setCompressLimitMode(true);
            setAttackTime(5.0f);
            setReleaseTime(150.0f);
            setOpticalCharacter(0.4f);
            setTubeWarmth(0.9f);
            setOutputTransformer(0.9f);
            break;
    }
}
