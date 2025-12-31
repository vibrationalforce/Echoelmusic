#include "ClassicPreamp.h"
#include "../Core/DSPOptimizations.h"

ClassicPreamp::ClassicPreamp()
{
}

ClassicPreamp::~ClassicPreamp()
{
}

//==============================================================================
// Processing

void ClassicPreamp::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    currentSampleRate = sampleRate;
    currentNumChannels = numChannels;

    reset();

    // Initialize filters
    updateHPFCoefficients();

    for (int ch = 0; ch < 2; ++ch)
    {
        for (int band = 0; band < 3; ++band)
        {
            juce::dsp::ProcessSpec spec;
            spec.sampleRate = sampleRate;
            spec.maximumBlockSize = static_cast<juce::uint32>(samplesPerBlock);
            spec.numChannels = 1;
            eqBands[ch][band].filter.prepare(spec);
            updateEQCoefficients(ch, band);
        }
    }
}

void ClassicPreamp::reset()
{
    // Reset HPF
    for (auto& state : hpfState)
    {
        state.z.fill(0.0f);
    }

    // Reset EQ
    for (auto& channelBands : eqBands)
    {
        for (auto& band : channelBands)
        {
            band.filter.reset();
        }
    }

    // Reset metering
    inputLevelSmooth.fill(0.0f);
    outputLevelSmooth.fill(0.0f);
    harmonicContentSmooth = 0.0f;
}

void ClassicPreamp::process(juce::AudioBuffer<float>& buffer)
{
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < numChannels; ++channel)
    {
        float* channelData = buffer.getWritePointer(channel);

        for (int sample = 0; sample < numSamples; ++sample)
        {
            channelData[sample] = processSample(channelData[sample], channel);
        }
    }
}

float ClassicPreamp::processSample(float sample, int channel)
{
    if (channel >= 2) return sample;

    // Input metering
    float inputLevel = std::abs(sample);
    inputLevelSmooth[channel] = inputLevel * 0.1f + inputLevelSmooth[channel] * 0.9f;

    // Phase invert
    if (phaseInvert)
        sample = -sample;

    // Neve 1073 signal chain:
    // 1. Input Transformer & Class-A Preamp
    sample = processInputStage(sample, channel);

    // 2. High-Pass Filter (18dB/oct)
    if (hpfEnabled)
        sample = processHPF(sample, channel);

    // 3. EQ Section (3-band)
    sample = processEQ(sample, channel);

    // 4. Output Transformer & Gain
    sample = processOutputStage(sample, channel);

    // Output metering
    float outputLevel = std::abs(sample);
    outputLevelSmooth[channel] = outputLevel * 0.1f + outputLevelSmooth[channel] * 0.9f;

    return sample;
}

//==============================================================================
// Preamp Section

void ClassicPreamp::setInputGain(float gainDb)
{
    inputGain = juce::jlimit(-20.0f, 80.0f, gainDb);
}

void ClassicPreamp::setInputImpedance(float ohms)
{
    // Input impedance affects frequency response (not fully modeled here)
    // 300Ω vs 1200Ω creates subtle tonal differences
    juce::ignoreUnused(ohms);
}

void ClassicPreamp::setPreampDrive(float amount)
{
    preampDrive = juce::jlimit(0.0f, 1.0f, amount);
}

float ClassicPreamp::processInputStage(float sample, int channel)
{
    // Apply input gain
    sample *= Echoel::DSP::FastMath::dbToGain(inputGain);

    // Input transformer saturation (Marinair transformer characteristic)
    sample = inputTransformerSaturation(sample);

    // Class-A preamp saturation
    sample = classAPreampSaturation(sample, preampDrive);

    return sample;
}

float ClassicPreamp::inputTransformerSaturation(float sample)
{
    // Marinair input transformer (LO1166)
    // Adds 2nd harmonic (even) content - warmth

    float drive = 1.0f + preampDrive * 0.5f;
    float x = sample * drive;

    // Even harmonic distortion (transformer core saturation)
    float saturation = x + 0.15f * x * x;  // 2nd harmonic

    // Soft clipping (magnetic saturation) using fast tanh
    if (std::abs(saturation) > 0.8f)
    {
        saturation = (saturation > 0.0f) ?
            0.8f + 0.2f * Echoel::DSP::FastMath::fastTanh((saturation - 0.8f) * 2.0f) :
            -0.8f + 0.2f * Echoel::DSP::FastMath::fastTanh((saturation + 0.8f) * 2.0f);
    }

    return saturation / drive;
}

float ClassicPreamp::classAPreampSaturation(float sample, float drive)
{
    // Neve Class-A discrete preamp (BC184C transistors)
    // Adds both 2nd and 3rd harmonic content

    float x = sample * (1.0f + drive * 2.0f);

    // Asymmetric saturation (Class-A characteristic)
    float harmonic2 = 0.1f * drive * x * x;         // 2nd harmonic
    float harmonic3 = 0.05f * drive * x * x * x;    // 3rd harmonic

    float saturated = x + harmonic2 + harmonic3;

    // Soft clip using fast tanh
    saturated = Echoel::DSP::FastMath::fastTanh(saturated);

    // Track harmonic content for metering
    float harmonicAmount = std::abs(harmonic2) + std::abs(harmonic3);
    harmonicContentSmooth = harmonicAmount * 0.1f + harmonicContentSmooth * 0.9f;

    return saturated;
}

//==============================================================================
// High-Pass Filter

void ClassicPreamp::setHPFFrequency(float frequency)
{
    // Snap to nearest Neve 1073 frequency
    int closestIndex = 0;
    float minDiff = std::abs(frequency - HPF_FREQUENCIES[0]);

    for (int i = 1; i < static_cast<int>(HPF_FREQUENCIES.size()); ++i)
    {
        float diff = std::abs(frequency - HPF_FREQUENCIES[i]);
        if (diff < minDiff)
        {
            minDiff = diff;
            closestIndex = i;
        }
    }

    hpfFrequencyIndex = closestIndex;
    updateHPFCoefficients();
}

void ClassicPreamp::setHPFEnabled(bool enabled)
{
    hpfEnabled = enabled;
}

void ClassicPreamp::updateHPFCoefficients()
{
    // 18dB/oct High-Pass (3-pole Butterworth)
    float frequency = HPF_FREQUENCIES[hpfFrequencyIndex];
    float omega = 2.0f * juce::MathConstants<float>::pi * frequency / static_cast<float>(currentSampleRate);

    // Simplified 3-pole filter approximation using fast trig
    // (Full implementation would use biquad cascade)
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    for (auto& state : hpfState)
    {
        float alpha = trigTables.fastSinRad(omega) / (2.0f * 0.707f);
        float cosOmega = trigTables.fastCosRad(omega);

        float a0 = 1.0f + alpha;
        state.b[0] = ((1.0f + cosOmega) / 2.0f) / a0;
        state.b[1] = (-(1.0f + cosOmega)) / a0;
        state.b[2] = ((1.0f + cosOmega) / 2.0f) / a0;
        state.a[0] = (-2.0f * cosOmega) / a0;
        state.a[1] = (1.0f - alpha) / a0;
    }
}

float ClassicPreamp::processHPF(float sample, int channel)
{
    auto& state = hpfState[channel];

    // Direct Form II Transposed
    float output = state.b[0] * sample + state.z[0];
    state.z[0] = state.b[1] * sample - state.a[0] * output + state.z[1];
    state.z[1] = state.b[2] * sample - state.a[1] * output;

    return output;
}

//==============================================================================
// 3-Band EQ

void ClassicPreamp::setHighFrequency(int frequencyIndex)
{
    frequencyIndex = juce::jlimit(0, static_cast<int>(HIGH_FREQUENCIES.size()) - 1, frequencyIndex);

    for (int ch = 0; ch < 2; ++ch)
    {
        eqBands[ch][0].frequencyIndex = frequencyIndex;
        updateEQCoefficients(ch, 0);
    }
}

void ClassicPreamp::setHighGain(float gainDb)
{
    gainDb = juce::jlimit(-16.0f, 16.0f, gainDb);

    for (int ch = 0; ch < 2; ++ch)
    {
        eqBands[ch][0].gain = gainDb;
        updateEQCoefficients(ch, 0);
    }
}

void ClassicPreamp::setHighEnabled(bool enabled)
{
    for (int ch = 0; ch < 2; ++ch)
        eqBands[ch][0].enabled = enabled;
}

void ClassicPreamp::setMidFrequency(int frequencyIndex)
{
    frequencyIndex = juce::jlimit(0, static_cast<int>(MID_FREQUENCIES.size()) - 1, frequencyIndex);

    for (int ch = 0; ch < 2; ++ch)
    {
        eqBands[ch][1].frequencyIndex = frequencyIndex;
        updateEQCoefficients(ch, 1);
    }
}

void ClassicPreamp::setMidGain(float gainDb)
{
    gainDb = juce::jlimit(-18.0f, 18.0f, gainDb);

    for (int ch = 0; ch < 2; ++ch)
    {
        eqBands[ch][1].gain = gainDb;
        updateEQCoefficients(ch, 1);
    }
}

void ClassicPreamp::setMidEnabled(bool enabled)
{
    for (int ch = 0; ch < 2; ++ch)
        eqBands[ch][1].enabled = enabled;
}

void ClassicPreamp::setLowFrequency(int frequencyIndex)
{
    frequencyIndex = juce::jlimit(0, static_cast<int>(LOW_FREQUENCIES.size()) - 1, frequencyIndex);

    for (int ch = 0; ch < 2; ++ch)
    {
        eqBands[ch][2].frequencyIndex = frequencyIndex;
        updateEQCoefficients(ch, 2);
    }
}

void ClassicPreamp::setLowGain(float gainDb)
{
    gainDb = juce::jlimit(-16.0f, 16.0f, gainDb);

    for (int ch = 0; ch < 2; ++ch)
    {
        eqBands[ch][2].gain = gainDb;
        updateEQCoefficients(ch, 2);
    }
}

void ClassicPreamp::setLowEnabled(bool enabled)
{
    for (int ch = 0; ch < 2; ++ch)
        eqBands[ch][2].enabled = enabled;
}

void ClassicPreamp::updateEQCoefficients(int channel, int band)
{
    auto& eq = eqBands[channel][band];
    float frequency = 1000.0f;
    float q = 0.7f;  // Neve 1073 has gentle, musical Q

    // Get fixed frequency based on band
    switch (band)
    {
        case 0:  // High
            frequency = HIGH_FREQUENCIES[eq.frequencyIndex];
            *eq.filter.coefficients = *juce::dsp::IIR::Coefficients<float>::makeHighShelf(
                currentSampleRate, frequency, q, Echoel::DSP::FastMath::dbToGain(eq.gain));
            break;

        case 1:  // Mid (parametric with fixed Q)
            frequency = MID_FREQUENCIES[eq.frequencyIndex];
            q = 1.0f;  // Neve 1073 mid band Q
            *eq.filter.coefficients = *juce::dsp::IIR::Coefficients<float>::makePeakFilter(
                currentSampleRate, frequency, q, Echoel::DSP::FastMath::dbToGain(eq.gain));
            break;

        case 2:  // Low
            frequency = LOW_FREQUENCIES[eq.frequencyIndex];
            *eq.filter.coefficients = *juce::dsp::IIR::Coefficients<float>::makeLowShelf(
                currentSampleRate, frequency, q, Echoel::DSP::FastMath::dbToGain(eq.gain));
            break;
    }
}

float ClassicPreamp::processEQ(float sample, int channel)
{
    for (int band = 0; band < 3; ++band)
    {
        auto& eq = eqBands[channel][band];
        if (eq.enabled && std::abs(eq.gain) > 0.01f)
        {
            sample = eq.filter.processSample(sample);
        }
    }

    return sample;
}

//==============================================================================
// Output Section

void ClassicPreamp::setOutputGain(float gainDb)
{
    outputGain = juce::jlimit(-20.0f, 20.0f, gainDb);
}

void ClassicPreamp::setPhaseInvert(bool invert)
{
    phaseInvert = invert;
}

void ClassicPreamp::setTransformerColoration(float amount)
{
    transformerColoration = juce::jlimit(0.0f, 1.0f, amount);
}

float ClassicPreamp::processOutputStage(float sample, int channel)
{
    juce::ignoreUnused(channel);

    // Output transformer saturation (Marinair LO1166)
    sample = outputTransformerSaturation(sample, transformerColoration);

    // Output gain
    sample *= Echoel::DSP::FastMath::dbToGain(outputGain);

    return sample;
}

float ClassicPreamp::outputTransformerSaturation(float sample, float amount)
{
    if (amount < 0.01f)
        return sample;

    // Neve output transformer adds "thickness" and warmth
    float drive = 1.0f + amount * 1.5f;
    float x = sample * drive;

    // Transformer saturation (iron core hysteresis)
    // Adds both even and odd harmonics
    float harmonic2 = 0.2f * amount * x * x;
    float harmonic3 = 0.1f * amount * x * x * x;

    float saturated = x + harmonic2 + harmonic3;

    // Soft saturation curve (transformer magnetic saturation)
    saturated = saturated / (1.0f + 0.3f * amount * std::abs(saturated));

    return saturated / drive;
}

//==============================================================================
// Metering

float ClassicPreamp::getInputLevel(int channel) const
{
    return (channel < 2) ? inputLevelSmooth[channel] : 0.0f;
}

float ClassicPreamp::getOutputLevel(int channel) const
{
    return (channel < 2) ? outputLevelSmooth[channel] : 0.0f;
}

float ClassicPreamp::getHarmonicContent() const
{
    return harmonicContentSmooth;
}

//==============================================================================
// Presets

void ClassicPreamp::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::Clean:
            setInputGain(20.0f);
            setPreampDrive(0.1f);
            setTransformerColoration(0.2f);
            setHighEnabled(false);
            setMidEnabled(false);
            setLowEnabled(false);
            setHPFEnabled(false);
            break;

        case Preset::VocalWarmth:
            setInputGain(40.0f);
            setPreampDrive(0.6f);
            setHPFFrequency(80.0f);
            setHPFEnabled(true);
            setLowFrequency(2);  // 110Hz
            setLowGain(-2.0f);
            setLowEnabled(true);
            setMidFrequency(2);  // 1.6kHz
            setMidGain(3.0f);
            setMidEnabled(true);
            setHighFrequency(0);  // 12kHz
            setHighGain(2.0f);
            setHighEnabled(true);
            setTransformerColoration(0.7f);
            break;

        case Preset::KickDrum:
            setInputGain(50.0f);
            setPreampDrive(0.8f);
            setHPFFrequency(50.0f);
            setHPFEnabled(true);
            setLowFrequency(1);  // 60Hz
            setLowGain(6.0f);
            setLowEnabled(true);
            setMidFrequency(3);  // 3.2kHz
            setMidGain(4.0f);
            setMidEnabled(true);
            setTransformerColoration(0.9f);
            break;

        case Preset::Snare:
            setInputGain(35.0f);
            setPreampDrive(0.5f);
            setHPFFrequency(160.0f);
            setHPFEnabled(true);
            setMidFrequency(1);  // 700Hz
            setMidGain(-3.0f);
            setMidEnabled(true);
            setHighFrequency(0);  // 12kHz
            setHighGain(5.0f);
            setHighEnabled(true);
            setTransformerColoration(0.6f);
            break;

        case Preset::Bass:
            setInputGain(45.0f);
            setPreampDrive(0.7f);
            setHPFFrequency(50.0f);
            setHPFEnabled(true);
            setLowFrequency(0);  // 35Hz
            setLowGain(4.0f);
            setLowEnabled(true);
            setMidFrequency(2);  // 1.6kHz
            setMidGain(2.0f);
            setMidEnabled(true);
            setTransformerColoration(0.8f);
            break;

        case Preset::AcousticGuitar:
            setInputGain(30.0f);
            setPreampDrive(0.4f);
            setHPFFrequency(80.0f);
            setHPFEnabled(true);
            setMidFrequency(3);  // 3.2kHz
            setMidGain(3.0f);
            setMidEnabled(true);
            setHighFrequency(0);  // 12kHz
            setHighGain(2.0f);
            setHighEnabled(true);
            setTransformerColoration(0.5f);
            break;

        case Preset::OverheadCymbal:
            setInputGain(25.0f);
            setPreampDrive(0.3f);
            setHPFFrequency(300.0f);
            setHPFEnabled(true);
            setHighFrequency(1);  // 16kHz
            setHighGain(4.0f);
            setHighEnabled(true);
            setTransformerColoration(0.4f);
            break;

        case Preset::VintageMax:
            setInputGain(60.0f);
            setPreampDrive(0.9f);
            setLowFrequency(1);  // 60Hz
            setLowGain(5.0f);
            setLowEnabled(true);
            setMidFrequency(2);  // 1.6kHz
            setMidGain(4.0f);
            setMidEnabled(true);
            setHighFrequency(0);  // 12kHz
            setHighGain(3.0f);
            setHighEnabled(true);
            setTransformerColoration(1.0f);
            break;
    }
}
