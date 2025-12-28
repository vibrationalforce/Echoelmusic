#include "FETCompressor.h"
#include "../Core/DSPOptimizations.h"

FETCompressor::FETCompressor() {}
FETCompressor::~FETCompressor() {}

void FETCompressor::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    juce::ignoreUnused(samplesPerBlock);
    currentSampleRate = sampleRate;
    currentNumChannels = numChannels;
    reset();
    updateCoefficients();
}

void FETCompressor::reset()
{
    for (auto& state : compState)
        state.envelope = 0.0f;
    inputLevelSmooth.fill(0.0f);
    outputLevelSmooth.fill(0.0f);
    gainReductionSmooth = 0.0f;
}

void FETCompressor::process(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    // OPTIMIZATION: Cache channel pointers to avoid per-sample virtual calls
    float* channelPtrs[2] = { nullptr, nullptr };
    const int maxChannels = juce::jmin(numChannels, 2);
    for (int ch = 0; ch < maxChannels; ++ch)
        channelPtrs[ch] = buffer.getWritePointer(ch);

    for (int sample = 0; sample < numSamples; ++sample)
    {
        float linkedSidechain = 0.0f;
        if (numChannels >= 2 && stereoLink)
        {
            float left = channelPtrs[0][sample];
            float right = channelPtrs[1][sample];
            linkedSidechain = (std::abs(left) + std::abs(right)) * 0.5f;
        }

        for (int channel = 0; channel < maxChannels; ++channel)
        {
            float channelSample = channelPtrs[channel][sample];
            float processed = processSample(channelSample, channel);
            channelPtrs[channel][sample] = processed;
        }
    }
}

float FETCompressor::processSample(float sample, int channel)
{
    if (channel >= 2) return sample;

    float inputLevel = std::abs(sample);
    inputLevelSmooth[channel] = inputLevel * 0.1f + inputLevelSmooth[channel] * 0.9f;

    // Input gain (use cached linear value)
    sample *= inputGainLinear;

    // FET Compression
    sample = processFETCompression(sample, channel);

    // Output gain (use cached linear value)
    sample *= outputGainLinear;

    float outputLevel = std::abs(sample);
    outputLevelSmooth[channel] = outputLevel * 0.1f + outputLevelSmooth[channel] * 0.9f;

    return sample;
}

void FETCompressor::setInputGain(float gainDb)
{
    inputGain = juce::jlimit(-20.0f, 40.0f, gainDb);
    inputGainLinear = Echoel::DSP::FastMath::dbToGain(inputGain);  // Cache linear gain
}

void FETCompressor::setOutputGain(float gainDb)
{
    outputGain = juce::jlimit(-20.0f, 20.0f, gainDb);
    outputGainLinear = Echoel::DSP::FastMath::dbToGain(outputGain);  // Cache linear gain
}

void FETCompressor::setAttack(float attackUs)
{
    attackUs = juce::jlimit(20.0f, 800.0f, attackUs);
    this->attackUs = attackUs;
    updateCoefficients();
}

void FETCompressor::setRelease(float releaseMs)
{
    releaseMs = juce::jlimit(50.0f, 1100.0f, releaseMs);
    this->releaseMs = releaseMs;
    updateCoefficients();
}

void FETCompressor::setRatio(int r)
{
    // 1176 fixed ratios
    if (r == 4 || r == 8 || r == 12 || r == 20)
        ratio = r;
}

void FETCompressor::setAllButtonsMode(bool enabled)
{
    allButtonsMode = enabled;
}

void FETCompressor::setFETColoration(float amount)
{
    fetColoration = juce::jlimit(0.0f, 1.0f, amount);
}

void FETCompressor::setStereoLink(bool linked)
{
    stereoLink = linked;
}

void FETCompressor::updateCoefficients()
{
    float attackSeconds = attackUs / 1000000.0f;  // μs to seconds
    float releaseSeconds = releaseMs / 1000.0f;

    for (auto& state : compState)
    {
        state.attackCoeff = Echoel::DSP::FastMath::fastExp(-1.0f / (static_cast<float>(currentSampleRate) * attackSeconds));
        state.releaseCoeff = Echoel::DSP::FastMath::fastExp(-1.0f / (static_cast<float>(currentSampleRate) * releaseSeconds));
    }
}

float FETCompressor::processFETCompression(float sample, int channel, float linkedSidechain)
{
    auto& state = compState[channel];

    float inputLevel = (stereoLink && linkedSidechain > 0.0f) ? linkedSidechain : std::abs(sample);

    // Peak detection (1176 style)
    if (inputLevel > state.envelope)
        state.envelope = inputLevel + state.attackCoeff * (state.envelope - inputLevel);
    else
        state.envelope = inputLevel + state.releaseCoeff * (state.envelope - inputLevel);

    // Use fast dB conversion from DSPOptimizations
    float envelopeDb = Echoel::DSP::FastMath::gainToDb(state.envelope + 1e-6f);

    // 1176 compression curve
    constexpr float threshold = -10.0f;  // 1176 typical threshold
    float actualRatio = allButtonsMode ? 12.0f : static_cast<float>(ratio);

    float gainReduction = 0.0f;
    if (envelopeDb > threshold)
    {
        float overThreshold = envelopeDb - threshold;
        gainReduction = -overThreshold * (1.0f - 1.0f / actualRatio);

        // All buttons mode: extra aggression
        if (allButtonsMode)
            gainReduction *= 1.3f;
    }

    gainReductionSmooth = gainReduction * 0.1f + gainReductionSmooth * 0.9f;

    // Use fast dB to gain conversion
    float compGain = Echoel::DSP::FastMath::dbToGain(gainReduction);

    // FET saturation
    sample = fetSaturation(sample * compGain, fetColoration);

    return sample;
}

float FETCompressor::fetSaturation(float sample, float amount)
{
    if (amount < 0.01f) return sample;

    // FET transistor saturation (2N5457)
    float drive = 1.0f + amount * 2.0f;
    float x = sample * drive;

    // Asymmetric clipping (FET characteristic)
    float saturated = x / (1.0f + 0.5f * amount * std::abs(x));

    // Odd harmonics (FET distortion)
    saturated += amount * 0.1f * x * x * x;

    return saturated / drive;
}

float FETCompressor::getGainReduction() const { return gainReductionSmooth; }
float FETCompressor::getInputLevel(int channel) const { return (channel < 2) ? inputLevelSmooth[channel] : 0.0f; }
float FETCompressor::getOutputLevel(int channel) const { return (channel < 2) ? outputLevelSmooth[channel] : 0.0f; }

void FETCompressor::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::Vintage:
            setInputGain(10.0f);
            setOutputGain(0.0f);
            setAttack(250.0f);
            setRelease(400.0f);
            setRatio(4);
            setAllButtonsMode(false);
            setFETColoration(0.7f);
            break;
        case Preset::VocalSmash:
            setInputGain(20.0f);
            setAttack(100.0f);
            setRelease(300.0f);
            setRatio(8);
            setFETColoration(0.6f);
            break;
        case Preset::DrumCrush:
            setInputGain(15.0f);
            setAttack(50.0f);
            setRelease(200.0f);
            setRatio(12);
            setFETColoration(0.8f);
            break;
        case Preset::BassSlam:
            setInputGain(12.0f);
            setAttack(150.0f);
            setRelease(500.0f);
            setRatio(8);
            setFETColoration(0.9f);
            break;
        case Preset::AllButtons:
            setInputGain(25.0f);
            setAttack(20.0f);
            setRelease(100.0f);
            setAllButtonsMode(true);
            setFETColoration(1.0f);
            break;
        case Preset::GentleGlue:
            setInputGain(8.0f);
            setAttack(400.0f);
            setRelease(600.0f);
            setRatio(4);
            setFETColoration(0.4f);
            break;
        case Preset::FastPeak:
            setInputGain(18.0f);
            setAttack(20.0f);
            setRelease(150.0f);
            setRatio(20);
            setFETColoration(0.5f);
            break;
    }
}
