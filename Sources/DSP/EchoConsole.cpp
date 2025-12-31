#include "EchoConsole.h"
#include "../Core/DSPOptimizations.h"

EchoConsole::EchoConsole()
{
}

EchoConsole::~EchoConsole()
{
}

//==============================================================================
// Processing

void EchoConsole::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    currentSampleRate = sampleRate;
    currentNumChannels = numChannels;

    reset();

    // Initialize filters
    updateHPFCoefficients();
    for (int ch = 0; ch < 2; ++ch)
    {
        for (int band = 0; band < 4; ++band)
        {
            juce::dsp::ProcessSpec spec;
            spec.sampleRate = sampleRate;
            spec.maximumBlockSize = static_cast<juce::uint32>(samplesPerBlock);
            spec.numChannels = 1;
            eqState[ch][band].filter.prepare(spec);
            updateEQCoefficients(ch, static_cast<EQBand>(band));
        }
    }

    updateGateCoefficients();
    updateCompressorCoefficients();
}

void EchoConsole::reset()
{
    // Reset HPF
    for (auto& state : hpfState)
    {
        state.z1 = state.z2 = 0.0f;
    }

    // Reset EQ
    for (auto& channelState : eqState)
    {
        for (auto& band : channelState)
        {
            band.filter.reset();
        }
    }

    // Reset Gate
    for (auto& state : gateState)
    {
        state.envelope = 0.0f;
    }

    // Reset Compressor
    for (auto& state : compState)
    {
        state.envelope = 0.0f;
    }

    // Reset metering
    inputLevelSmooth.fill(0.0f);
    outputLevelSmooth.fill(0.0f);
    gainReductionSmooth.store(0.0f);
}

void EchoConsole::process(juce::AudioBuffer<float>& buffer)
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

float EchoConsole::processSample(float sample, int channel)
{
    if (channel >= 2) return sample;

    // Input metering
    float inputLevel = std::abs(sample);
    inputLevelSmooth[channel] = inputLevel * 0.1f + inputLevelSmooth[channel] * 0.9f;

    // Phase invert
    if (phaseInvert)
        sample = -sample;

    // Signal chain (SSL G-Series order):
    // 1. High-Pass Filter
    if (hpfEnabled)
        sample = processHPF(sample, channel);

    // 2. Gate/Expander
    float preGainReduction = 0.0f;
    if (gateEnabled)
    {
        float gatedSample = processGate(sample, channel);
        preGainReduction = Echoel::DSP::FastMath::gainToDb(std::abs(gatedSample) / (std::abs(sample) + 1e-6f));
        sample = gatedSample;
    }

    // 3. EQ
    sample = processEQ(sample, channel);

    // 4. VCA Compressor
    float compGainReduction = 0.0f;
    if (compEnabled)
    {
        float compressedSample = processCompressor(sample, channel);
        compGainReduction = Echoel::DSP::FastMath::gainToDb(std::abs(compressedSample) / (std::abs(sample) + 1e-6f));
        sample = compressedSample;
    }

    // 5. Analog Saturation (subtle SSL transformer coloration)
    sample = processSaturation(sample);

    // 6. Output Gain
    sample *= Echoel::DSP::FastMath::dbToGain(outputGain);

    // OPTIMIZATION: Atomic smoothing for thread-safe UI metering
    float totalGR = preGainReduction + compGainReduction;
    float grSmooth = totalGR * 0.1f + gainReductionSmooth.load() * 0.9f;
    gainReductionSmooth.store(grSmooth);

    // Output metering
    float outputLevel = std::abs(sample);
    outputLevelSmooth[channel] = outputLevel * 0.1f + outputLevelSmooth[channel] * 0.9f;

    return sample;
}

//==============================================================================
// High-Pass Filter

void EchoConsole::setHPFFrequency(float frequency)
{
    hpfFrequency = juce::jlimit(16.0f, 350.0f, frequency);
    updateHPFCoefficients();
}

void EchoConsole::setHPFEnabled(bool enabled)
{
    hpfEnabled = enabled;
}

void EchoConsole::updateHPFCoefficients()
{
    // 12dB/oct Butterworth High-Pass - using fast trig
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    float omega = 2.0f * juce::MathConstants<float>::pi * hpfFrequency / static_cast<float>(currentSampleRate);
    float sinOmega = trigTables.fastSinRad(omega);
    float cosOmega = trigTables.fastCosRad(omega);
    float alpha = sinOmega / (2.0f * 0.707f);  // Q = 0.707 for Butterworth

    float a0 = 1.0f + alpha;
    float a1 = -2.0f * cosOmega;
    float a2 = 1.0f - alpha;
    float b0 = (1.0f + cosOmega) / 2.0f;
    float b1 = -(1.0f + cosOmega);
    float b2 = (1.0f + cosOmega) / 2.0f;

    for (auto& state : hpfState)
    {
        state.b0 = b0 / a0;
        state.b1 = b1 / a0;
        state.b2 = b2 / a0;
        state.a1 = a1 / a0;
        state.a2 = a2 / a0;
    }
}

float EchoConsole::processHPF(float sample, int channel)
{
    auto& state = hpfState[channel];

    float output = state.b0 * sample + state.b1 * state.z1 + state.b2 * state.z2
                   - state.a1 * state.z1 - state.a2 * state.z2;

    state.z2 = state.z1;
    state.z1 = sample;

    return output;
}

//==============================================================================
// 4-Band EQ

void EchoConsole::setEQGain(EQBand band, float gainDb)
{
    gainDb = juce::jlimit(-15.0f, 15.0f, gainDb);

    for (int ch = 0; ch < 2; ++ch)
    {
        eqState[ch][static_cast<int>(band)].gain = gainDb;
        updateEQCoefficients(ch, band);
    }
}

void EchoConsole::setEQFrequency(EQBand band, float frequency)
{
    for (int ch = 0; ch < 2; ++ch)
    {
        eqState[ch][static_cast<int>(band)].frequency = frequency;
        updateEQCoefficients(ch, band);
    }
}

void EchoConsole::setEQQ(EQBand band, float q)
{
    q = juce::jlimit(0.5f, 4.0f, q);

    for (int ch = 0; ch < 2; ++ch)
    {
        eqState[ch][static_cast<int>(band)].q = q;
        updateEQCoefficients(ch, band);
    }
}

void EchoConsole::setEQEnabled(EQBand band, bool enabled)
{
    for (int ch = 0; ch < 2; ++ch)
    {
        eqState[ch][static_cast<int>(band)].enabled = enabled;
    }
}

void EchoConsole::setEQBellMode(bool bellMode)
{
    eqBellMode = bellMode;

    // Update HF and LF band coefficients
    for (int ch = 0; ch < 2; ++ch)
    {
        updateEQCoefficients(ch, EQBand::HF);
        updateEQCoefficients(ch, EQBand::LF);
    }
}

void EchoConsole::updateEQCoefficients(int channel, EQBand band)
{
    auto& eq = eqState[channel][static_cast<int>(band)];

    // SSL G-Series EQ frequencies (typical values)
    switch (band)
    {
        case EQBand::HF:   // 3kHz - 16kHz
            if (eqBellMode)
                *eq.filter.coefficients = *juce::dsp::IIR::Coefficients<float>::makePeakFilter(
                    currentSampleRate, eq.frequency, eq.q, Echoel::DSP::FastMath::dbToGain(eq.gain));
            else
                *eq.filter.coefficients = *juce::dsp::IIR::Coefficients<float>::makeHighShelf(
                    currentSampleRate, eq.frequency, eq.q, Echoel::DSP::FastMath::dbToGain(eq.gain));
            break;

        case EQBand::HMF:  // 600Hz - 7kHz (parametric)
        case EQBand::LMF:  // 200Hz - 2.5kHz (parametric)
            *eq.filter.coefficients = *juce::dsp::IIR::Coefficients<float>::makePeakFilter(
                currentSampleRate, eq.frequency, eq.q, Echoel::DSP::FastMath::dbToGain(eq.gain));
            break;

        case EQBand::LF:   // 30Hz - 450Hz
            if (eqBellMode)
                *eq.filter.coefficients = *juce::dsp::IIR::Coefficients<float>::makePeakFilter(
                    currentSampleRate, eq.frequency, eq.q, Echoel::DSP::FastMath::dbToGain(eq.gain));
            else
                *eq.filter.coefficients = *juce::dsp::IIR::Coefficients<float>::makeLowShelf(
                    currentSampleRate, eq.frequency, eq.q, Echoel::DSP::FastMath::dbToGain(eq.gain));
            break;
    }
}

float EchoConsole::processEQ(float sample, int channel)
{
    for (int band = 0; band < 4; ++band)
    {
        auto& eq = eqState[channel][band];
        if (eq.enabled && std::abs(eq.gain) > 0.01f)
        {
            sample = eq.filter.processSample(sample);
        }
    }

    return sample;
}

//==============================================================================
// Gate/Expander

void EchoConsole::setGateThreshold(float thresholdDb)
{
    gateThreshold = juce::jlimit(-80.0f, 0.0f, thresholdDb);
}

void EchoConsole::setGateRange(float rangeDb)
{
    gateRange = juce::jlimit(-80.0f, 0.0f, rangeDb);
}

void EchoConsole::setGateAttack(float attackMs)
{
    attackMs = juce::jlimit(0.1f, 100.0f, attackMs);
    updateGateCoefficients();
}

void EchoConsole::setGateRelease(float releaseMs)
{
    releaseMs = juce::jlimit(10.0f, 4000.0f, releaseMs);
    updateGateCoefficients();
}

void EchoConsole::setGateRatio(float ratio)
{
    gateRatio = juce::jlimit(1.0f, 10.0f, ratio);
}

void EchoConsole::setGateEnabled(bool enabled)
{
    gateEnabled = enabled;
}

void EchoConsole::updateGateCoefficients()
{
    // Exponential envelope followers - using fast exp
    float attackTimeSeconds = 0.001f;  // Will be set dynamically
    float releaseTimeSeconds = 0.4f;

    for (auto& state : gateState)
    {
        state.attackCoeff = Echoel::DSP::FastMath::fastExp(-1.0f / (static_cast<float>(currentSampleRate) * attackTimeSeconds));
        state.releaseCoeff = Echoel::DSP::FastMath::fastExp(-1.0f / (static_cast<float>(currentSampleRate) * releaseTimeSeconds));
    }
}

float EchoConsole::processGate(float sample, int channel)
{
    auto& state = gateState[channel];

    // RMS detection
    float inputLevel = std::abs(sample);
    float inputDb = Echoel::DSP::FastMath::gainToDb(inputLevel + 1e-6f);

    // Envelope follower
    if (inputLevel > state.envelope)
        state.envelope = inputLevel + state.attackCoeff * (state.envelope - inputLevel);
    else
        state.envelope = inputLevel + state.releaseCoeff * (state.envelope - inputLevel);

    float envelopeDb = Echoel::DSP::FastMath::gainToDb(state.envelope + 1e-6f);

    // Expander curve
    float gainReduction = 0.0f;
    if (envelopeDb < gateThreshold)
    {
        float overThreshold = gateThreshold - envelopeDb;
        gainReduction = overThreshold * (1.0f - 1.0f / gateRatio);
        gainReduction = juce::jlimit(gateRange, 0.0f, -gainReduction);
    }

    float gain = Echoel::DSP::FastMath::dbToGain(gainReduction);
    return sample * gain;
}

//==============================================================================
// VCA Compressor (SSL-Style)

void EchoConsole::setCompThreshold(float thresholdDb)
{
    compThreshold = juce::jlimit(-40.0f, 20.0f, thresholdDb);
}

void EchoConsole::setCompRatio(float ratio)
{
    compRatio = juce::jlimit(1.0f, 20.0f, ratio);
}

void EchoConsole::setCompAttack(float attackMs)
{
    attackMs = juce::jlimit(0.1f, 30.0f, attackMs);
    updateCompressorCoefficients();
}

void EchoConsole::setCompRelease(float releaseMs)
{
    compReleaseMs = juce::jlimit(100.0f, 4000.0f, releaseMs);
    updateCompressorCoefficients();
}

void EchoConsole::setCompAutoRelease(bool autoRelease)
{
    compAutoRelease = autoRelease;
}

void EchoConsole::setCompMakeupGain(float gainDb)
{
    compMakeupGain = juce::jlimit(0.0f, 20.0f, gainDb);
}

void EchoConsole::setCompEnabled(bool enabled)
{
    compEnabled = enabled;
}

void EchoConsole::updateCompressorCoefficients()
{
    // SSL-style fast attack (3ms default) - using fast exp
    float attackTimeSeconds = 0.003f;
    float releaseTimeSeconds = compReleaseMs / 1000.0f;

    for (auto& state : compState)
    {
        state.attackCoeff = Echoel::DSP::FastMath::fastExp(-1.0f / (static_cast<float>(currentSampleRate) * attackTimeSeconds));
        state.releaseCoeff = Echoel::DSP::FastMath::fastExp(-1.0f / (static_cast<float>(currentSampleRate) * releaseTimeSeconds));
    }
}

float EchoConsole::processCompressor(float sample, int channel)
{
    auto& state = compState[channel];

    // Peak detection (SSL VCA style)
    float inputLevel = std::abs(sample);
    float inputDb = Echoel::DSP::FastMath::gainToDb(inputLevel + 1e-6f);

    // Envelope follower
    if (inputLevel > state.envelope)
        state.envelope = inputLevel + state.attackCoeff * (state.envelope - inputLevel);
    else
    {
        // Auto-release: faster release for transients
        float releaseCoeff = state.releaseCoeff;
        if (compAutoRelease)
        {
            float delta = state.envelope - inputLevel;
            if (delta > 0.1f)  // Fast transient recovery
                releaseCoeff *= 0.5f;
        }
        state.envelope = inputLevel + releaseCoeff * (state.envelope - inputLevel);
    }

    float envelopeDb = Echoel::DSP::FastMath::gainToDb(state.envelope + 1e-6f);

    // SSL compression curve (soft knee at higher ratios)
    float gainReduction = sslCompressorCurve(envelopeDb, compThreshold, compRatio);

    // Apply makeup gain
    float totalGain = Echoel::DSP::FastMath::dbToGain(gainReduction + compMakeupGain);

    return sample * totalGain;
}

float EchoConsole::sslCompressorCurve(float inputDb, float threshold, float ratio)
{
    if (inputDb <= threshold)
        return 0.0f;  // No compression below threshold

    float overThreshold = inputDb - threshold;

    // Soft knee for "British" ratios (10:1+)
    float kneeWidth = (ratio >= 10.0f) ? 6.0f : 2.0f;

    if (overThreshold < kneeWidth)
    {
        // Soft knee region
        float kneeRatio = overThreshold / kneeWidth;
        return -overThreshold * kneeRatio * (1.0f - 1.0f / ratio) * 0.5f;
    }

    // Above knee
    return -overThreshold * (1.0f - 1.0f / ratio);
}

//==============================================================================
// Output Section

void EchoConsole::setOutputGain(float gainDb)
{
    outputGain = juce::jlimit(-20.0f, 20.0f, gainDb);
}

void EchoConsole::setPhaseInvert(bool invert)
{
    phaseInvert = invert;
}

void EchoConsole::setAnalogSaturation(float amount)
{
    analogSaturation = juce::jlimit(0.0f, 1.0f, amount);
}

float EchoConsole::processSaturation(float sample)
{
    if (analogSaturation < 0.01f)
        return sample;

    return transformerSaturation(sample, analogSaturation);
}

float EchoConsole::transformerSaturation(float sample, float amount)
{
    // SSL transformer saturation (subtle harmonic enhancement)
    // Emulates iron core transformer saturation

    float drive = 1.0f + amount * 2.0f;
    float x = sample * drive;

    // Soft clipping with asymmetry (transformer characteristic)
    float asymmetry = 0.1f * amount;
    x += asymmetry * x * x;  // Even harmonics

    // Soft clip
    float saturated = (x > 0.0f) ?
        x / (1.0f + 0.3f * x) :
        x / (1.0f - 0.3f * x);

    // Mix back
    return sample + (saturated - sample) * amount * 0.5f;
}

//==============================================================================
// Metering

float EchoConsole::getInputLevel(int channel) const
{
    return (channel < 2) ? inputLevelSmooth[channel] : 0.0f;
}

float EchoConsole::getOutputLevel(int channel) const
{
    return (channel < 2) ? outputLevelSmooth[channel] : 0.0f;
}

float EchoConsole::getGainReduction() const
{
    return gainReductionSmooth.load();
}

//==============================================================================
// Presets

void EchoConsole::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::Neutral:
            setHPFEnabled(false);
            setEQEnabled(EQBand::HF, false);
            setEQEnabled(EQBand::HMF, false);
            setEQEnabled(EQBand::LMF, false);
            setEQEnabled(EQBand::LF, false);
            setGateEnabled(false);
            setCompEnabled(false);
            setOutputGain(0.0f);
            setAnalogSaturation(0.0f);
            break;

        case Preset::VocalCompression:
            setHPFFrequency(80.0f);
            setHPFEnabled(true);
            setEQGain(EQBand::LF, -3.0f);
            setEQFrequency(EQBand::LF, 100.0f);
            setEQGain(EQBand::HMF, 2.0f);
            setEQFrequency(EQBand::HMF, 3000.0f);
            setEQQ(EQBand::HMF, 1.5f);
            setEQEnabled(EQBand::LF, true);
            setEQEnabled(EQBand::HMF, true);
            setCompThreshold(-12.0f);
            setCompRatio(4.0f);
            setCompAttack(3.0f);
            setCompRelease(400.0f);
            setCompAutoRelease(true);
            setCompMakeupGain(8.0f);
            setCompEnabled(true);
            setAnalogSaturation(0.3f);
            break;

        case Preset::DrumBus:
            setHPFFrequency(40.0f);
            setHPFEnabled(true);
            setEQGain(EQBand::LF, 2.0f);
            setEQFrequency(EQBand::LF, 60.0f);
            setEQGain(EQBand::HF, 3.0f);
            setEQFrequency(EQBand::HF, 10000.0f);
            setEQEnabled(EQBand::LF, true);
            setEQEnabled(EQBand::HF, true);
            setCompThreshold(-8.0f);
            setCompRatio(4.0f);
            setCompAttack(1.0f);
            setCompRelease(200.0f);
            setCompAutoRelease(true);
            setCompMakeupGain(6.0f);
            setCompEnabled(true);
            setAnalogSaturation(0.5f);
            break;

        case Preset::MixBus:
            setHPFFrequency(30.0f);
            setHPFEnabled(true);
            setCompThreshold(-3.0f);
            setCompRatio(2.0f);
            setCompAttack(10.0f);
            setCompRelease(400.0f);
            setCompAutoRelease(true);
            setCompMakeupGain(2.0f);
            setCompEnabled(true);
            setAnalogSaturation(0.4f);
            break;

        case Preset::AggressiveMix:
            setCompThreshold(-6.0f);
            setCompRatio(10.0f);  // "British Mode"
            setCompAttack(0.3f);
            setCompRelease(100.0f);
            setCompMakeupGain(10.0f);
            setCompEnabled(true);
            setEQGain(EQBand::HF, 2.0f);
            setEQEnabled(EQBand::HF, true);
            setAnalogSaturation(0.7f);
            break;

        case Preset::VintageWarmth:
            setAnalogSaturation(0.8f);
            setEQGain(EQBand::LF, 1.0f);
            setEQFrequency(EQBand::LF, 100.0f);
            setEQGain(EQBand::HF, -1.0f);
            setEQFrequency(EQBand::HF, 12000.0f);
            setEQEnabled(EQBand::LF, true);
            setEQEnabled(EQBand::HF, true);
            break;

        case Preset::Transparent:
            setHPFEnabled(false);
            setCompThreshold(-10.0f);
            setCompRatio(2.0f);
            setCompAttack(5.0f);
            setCompRelease(400.0f);
            setCompMakeupGain(4.0f);
            setCompEnabled(true);
            setAnalogSaturation(0.1f);
            break;

        case Preset::BritishPunch:
            setCompThreshold(-10.0f);
            setCompRatio(4.0f);
            setCompAttack(0.5f);
            setCompRelease(200.0f);
            setCompAutoRelease(true);
            setCompMakeupGain(8.0f);
            setCompEnabled(true);
            setAnalogSaturation(0.5f);
            break;
    }
}
