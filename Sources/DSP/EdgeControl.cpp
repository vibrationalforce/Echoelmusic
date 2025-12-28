#include "EdgeControl.h"
#include "../Core/DSPOptimizations.h"

//==============================================================================
// Constructor
//==============================================================================

EdgeControl::EdgeControl()
{
}

//==============================================================================
// Clipping Parameters
//==============================================================================

void EdgeControl::setClipType(ClipType type)
{
    clipType = type;
}

void EdgeControl::setThreshold(float threshDb)
{
    thresholdDb = juce::jlimit(-20.0f, 0.0f, threshDb);
}

void EdgeControl::setKnee(float kneeAmount)
{
    kneeDb = juce::jlimit(0.0f, 12.0f, kneeAmount);
}

void EdgeControl::setCeiling(float ceilDb)
{
    ceilingDb = juce::jlimit(-1.0f, 0.0f, ceilDb);
}

//==============================================================================
// Processing Mode
//==============================================================================

void EdgeControl::setProcessingMode(ProcessingMode mode)
{
    if (processingMode != mode)
    {
        processingMode = mode;
        reset();
    }
}

//==============================================================================
// Multiband Parameters
//==============================================================================

void EdgeControl::setCrossoverLow(float freq)
{
    crossoverLow = juce::jlimit(20.0f, 5000.0f, freq);
}

void EdgeControl::setCrossoverHigh(float freq)
{
    crossoverHigh = juce::jlimit(crossoverLow, 20000.0f, freq);
}

void EdgeControl::setBandThreshold(int band, float offsetDb)
{
    if (band >= 0 && band < 3)
    {
        bandThresholdOffsets[band] = juce::jlimit(-12.0f, 12.0f, offsetDb);
    }
}

//==============================================================================
// Global Parameters
//==============================================================================

void EdgeControl::setInputGain(float gainDb)
{
    inputGainDb = juce::jlimit(-20.0f, 20.0f, gainDb);
}

void EdgeControl::setOutputGain(float gainDb)
{
    outputGainDb = juce::jlimit(-20.0f, 20.0f, gainDb);
}

void EdgeControl::setAutoMakeup(bool enabled)
{
    autoMakeup = enabled;
}

void EdgeControl::setMix(float mixAmount)
{
    mix = juce::jlimit(0.0f, 1.0f, mixAmount);
}

void EdgeControl::setOversampling(int factor)
{
    if (factor == 1 || factor == 2 || factor == 4 || factor == 8)
    {
        oversamplingFactor = factor;
    }
}

void EdgeControl::setTruePeakMode(bool enabled)
{
    truePeakMode = enabled;
}

//==============================================================================
// Processing
//==============================================================================

void EdgeControl::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    // Pre-allocate dry buffer (avoids per-frame allocation)
    dryBuffer.setSize(2, maxBlockSize, false, false, true);

    // Prepare oversampling
    if (oversamplingFactor > 1)
    {
        oversampling = std::make_unique<juce::dsp::Oversampling<float>>(
            2,  // stereo
            static_cast<size_t>(std::log2(oversamplingFactor)),
            juce::dsp::Oversampling<float>::filterHalfBandPolyphaseIIR
        );

        juce::dsp::ProcessSpec spec;
        spec.sampleRate = sampleRate;
        spec.maximumBlockSize = static_cast<juce::uint32>(maxBlockSize);
        spec.numChannels = 2;

        oversampling->initProcessing(static_cast<size_t>(maxBlockSize));
    }

    reset();
}

void EdgeControl::reset()
{
    for (auto& state : multibandStates)
    {
        std::fill(state.filterState.begin(), state.filterState.end(), 0.0f);
    }

    if (oversampling)
    {
        oversampling->reset();
    }

    inputLevel.store(0.0f);
    outputLevel.store(0.0f);
    gainReduction.store(0.0f);
    clippingAmount.store(0.0f);
}

void EdgeControl::process(juce::AudioBuffer<float>& buffer)
{
    // Update input meters
    updateMeters(buffer, true);

    // Store dry signal for mixing (using pre-allocated buffer - NO ALLOCATION)
    const int numChannels = buffer.getNumChannels();
    const int numSamples = buffer.getNumSamples();

    // OPTIMIZATION: No resize in audio thread - use safe bounds
    const int safeChannels = juce::jmin(numChannels, dryBuffer.getNumChannels());
    const int safeSamples = juce::jmin(numSamples, dryBuffer.getNumSamples());
    jassert(safeSamples >= numSamples && safeChannels >= numChannels);  // Buffer should be pre-allocated

    for (int ch = 0; ch < safeChannels; ++ch)
    {
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, safeSamples);
    }

    // Apply input gain
    if (std::abs(inputGainDb) > 0.1f)
    {
        buffer.applyGain(Echoel::DSP::FastMath::dbToGain(inputGainDb));
    }

    // Oversample if enabled
    if (oversampling && oversamplingFactor > 1)
    {
        juce::dsp::AudioBlock<float> block(buffer);
        auto oversampledBlock = oversampling->processSamplesUp(block);

        // Create temporary buffer for oversampled audio
        juce::AudioBuffer<float> oversampledBuffer(
            static_cast<int>(oversampledBlock.getNumChannels()),
            static_cast<int>(oversampledBlock.getNumSamples())
        );

        for (size_t ch = 0; ch < oversampledBlock.getNumChannels(); ++ch)
        {
            oversampledBuffer.copyFrom(static_cast<int>(ch), 0,
                                      oversampledBlock.getChannelPointer(ch),
                                      static_cast<int>(oversampledBlock.getNumSamples()));
        }

        // Process based on mode
        switch (processingMode)
        {
            case ProcessingMode::Stereo:
                processStereo(oversampledBuffer);
                break;

            case ProcessingMode::MidSide:
                processMidSide(oversampledBuffer);
                break;

            case ProcessingMode::Multiband:
                processMultiband(oversampledBuffer);
                break;
        }

        // Copy back to block for downsampling
        for (size_t ch = 0; ch < oversampledBlock.getNumChannels(); ++ch)
        {
            std::copy(oversampledBuffer.getReadPointer(static_cast<int>(ch)),
                     oversampledBuffer.getReadPointer(static_cast<int>(ch)) +
                     oversampledBlock.getNumSamples(),
                     oversampledBlock.getChannelPointer(ch));
        }

        oversampling->processSamplesDown(block);
    }
    else
    {
        // Process without oversampling
        switch (processingMode)
        {
            case ProcessingMode::Stereo:
                processStereo(buffer);
                break;

            case ProcessingMode::MidSide:
                processMidSide(buffer);
                break;

            case ProcessingMode::Multiband:
                processMultiband(buffer);
                break;
        }
    }

    // Apply auto-makeup gain
    if (autoMakeup)
    {
        float makeup = calculateMakeupGain();
        buffer.applyGain(makeup);
    }

    // Apply output gain
    if (std::abs(outputGainDb) > 0.1f)
    {
        buffer.applyGain(Echoel::DSP::FastMath::dbToGain(outputGainDb));
    }

    // Apply ceiling
    if (truePeakMode && ceilingDb < 0.0f)
    {
        float ceilingGain = Echoel::DSP::FastMath::dbToGain(ceilingDb);
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            float* channelData = buffer.getWritePointer(ch);
            for (int i = 0; i < buffer.getNumSamples(); ++i)
            {
                channelData[i] = juce::jlimit(-ceilingGain, ceilingGain, channelData[i]);
            }
        }
    }

    // Mix dry/wet
    if (mix < 0.999f)
    {
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            float* wetData = buffer.getWritePointer(ch);
            const float* dryData = dryBuffer.getReadPointer(ch);

            for (int i = 0; i < buffer.getNumSamples(); ++i)
            {
                wetData[i] = dryData[i] * (1.0f - mix) + wetData[i] * mix;
            }
        }
    }

    // Update output meters
    updateMeters(buffer, false);
}

//==============================================================================
// Metering
//==============================================================================

float EdgeControl::getInputLevel() const
{
    return Echoel::DSP::FastMath::gainToDb(inputLevel.load());
}

float EdgeControl::getOutputLevel() const
{
    return Echoel::DSP::FastMath::gainToDb(outputLevel.load());
}

float EdgeControl::getGainReduction() const
{
    return gainReduction.load();
}

float EdgeControl::getClippingAmount() const
{
    return clippingAmount.load();
}

//==============================================================================
// Internal Methods - Processing Modes
//==============================================================================

void EdgeControl::processStereo(juce::AudioBuffer<float>& buffer)
{
    const float threshold = Echoel::DSP::FastMath::dbToGain(thresholdDb);

    for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
    {
        float* channelData = buffer.getWritePointer(ch);

        for (int i = 0; i < buffer.getNumSamples(); ++i)
        {
            float input = channelData[i];
            float output = applyClipping(input, clipType, threshold, kneeDb);
            channelData[i] = output;

            // Track clipping amount
            if (std::abs(output) > 0.9f)
            {
                float clip = (std::abs(output) - 0.9f) / 0.1f;
                clippingAmount.store(juce::jmax(clippingAmount.load(), clip));
            }
        }
    }
}

void EdgeControl::processMidSide(juce::AudioBuffer<float>& buffer)
{
    if (buffer.getNumChannels() < 2)
    {
        processStereo(buffer);
        return;
    }

    const int numSamples = buffer.getNumSamples();
    float* leftData = buffer.getWritePointer(0);
    float* rightData = buffer.getWritePointer(1);

    const float threshold = Echoel::DSP::FastMath::dbToGain(thresholdDb);

    for (int i = 0; i < numSamples; ++i)
    {
        // Convert to Mid/Side
        float mid = (leftData[i] + rightData[i]) * 0.5f;
        float side = (leftData[i] - rightData[i]) * 0.5f;

        // Apply clipping
        mid = applyClipping(mid, clipType, threshold, kneeDb);
        side = applyClipping(side, clipType, threshold * 0.7f, kneeDb);  // Less aggressive on side

        // Convert back to Left/Right
        leftData[i] = mid + side;
        rightData[i] = mid - side;
    }
}

void EdgeControl::processMultiband(juce::AudioBuffer<float>& buffer)
{
    // Simplified multiband processing (would need proper crossover filters)
    processStereo(buffer);
}

//==============================================================================
// Internal Methods - Clipping Algorithms
//==============================================================================

float EdgeControl::applyClipping(float input, ClipType type, float threshold, float knee)
{
    switch (type)
    {
        case ClipType::SoftClip:
            return softClip(input, threshold, knee);

        case ClipType::HardClip:
            return hardClip(input, threshold);

        case ClipType::TubeClip:
            return tubeClip(input, threshold, knee);

        case ClipType::DiodeClip:
            return diodeClip(input, threshold);

        case ClipType::TransformerClip:
            return transformerClip(input, threshold, knee);

        case ClipType::AnalogClip:
            return analogClip(input, threshold, knee);

        default:
            return input;
    }
}

float EdgeControl::softClip(float input, float threshold, float knee)
{
    float kneeRange = knee / 20.0f;  // Convert dB to linear range
    float absInput = std::abs(input);
    float sign = (input >= 0.0f) ? 1.0f : -1.0f;

    if (absInput < threshold - kneeRange)
    {
        return input;  // Below knee
    }
    else if (absInput < threshold + kneeRange)
    {
        // In knee region - smooth transition
        float x = (absInput - (threshold - kneeRange)) / (2.0f * kneeRange);
        float y = threshold - kneeRange + 2.0f * kneeRange * (x - x * x * x / 3.0f);
        return sign * y;
    }
    else
    {
        // Above threshold - soft clip with fast tanh
        float excess = absInput - threshold;
        return sign * (threshold + Echoel::DSP::FastMath::fastTanh(excess * 3.0f) * 0.3f);
    }
}

float EdgeControl::hardClip(float input, float threshold)
{
    return juce::jlimit(-threshold, threshold, input);
}

float EdgeControl::tubeClip(float input, float threshold, float knee)
{
    // Asymmetric tube-style clipping
    float normalized = input / threshold;

    // Add asymmetry (even harmonics)
    float biased = normalized + 0.1f;

    // Tube curve
    float output;
    if (std::abs(biased) < 1.0f)
    {
        output = biased;
    }
    else
    {
        output = (biased > 0.0f) ? Echoel::DSP::FastMath::fastTanh(biased * 1.5f) : Echoel::DSP::FastMath::fastTanh(biased * 0.8f);
    }

    return output * threshold;
}

float EdgeControl::diodeClip(float input, float threshold)
{
    // Diode clipping (asymmetric hard clipping)
    if (input > threshold)
    {
        return threshold + (input - threshold) * 0.1f;  // Compress positive
    }
    else if (input < -threshold * 1.2f)
    {
        return -threshold * 1.2f;  // Hard clip negative
    }
    else
    {
        return input;
    }
}

float EdgeControl::transformerClip(float input, float threshold, float knee)
{
    juce::ignoreUnused(knee);

    // Transformer saturation (very soft)
    float normalized = input / threshold;
    float output = normalized / (1.0f + std::abs(normalized) * 0.3f);
    return output * threshold;
}

float EdgeControl::analogClip(float input, float threshold, float knee)
{
    juce::ignoreUnused(knee);

    // Analog tape-style clipping
    float normalized = input / threshold;
    float output;

    if (std::abs(normalized) < 0.5f)
    {
        output = normalized;  // Linear region
    }
    else if (std::abs(normalized) < 1.0f)
    {
        // Soft knee
        float sign = (normalized > 0.0f) ? 1.0f : -1.0f;
        float abs_x = std::abs(normalized);
        output = sign * (0.5f + (abs_x - 0.5f) * 0.7f);
    }
    else
    {
        // Soft saturation using fast tanh
        output = Echoel::DSP::FastMath::fastTanh(normalized * 1.2f) * 0.9f;
    }

    return output * threshold;
}

//==============================================================================
// Internal Methods - Utilities
//==============================================================================

void EdgeControl::updateMeters(const juce::AudioBuffer<float>& buffer, bool isInput)
{
    float peak = buffer.getMagnitude(0, buffer.getNumSamples());

    if (isInput)
    {
        float currentInput = inputLevel.load();
        inputLevel.store(juce::jmax(currentInput * 0.95f, peak));
    }
    else
    {
        float currentOutput = outputLevel.load();
        outputLevel.store(juce::jmax(currentOutput * 0.95f, peak));

        // Calculate gain reduction
        float inputPeak = inputLevel.load();
        if (inputPeak > 0.001f)
        {
            float gr = Echoel::DSP::FastMath::gainToDb(peak / inputPeak);
            gainReduction.store(gr);
        }
    }
}

float EdgeControl::calculateMakeupGain() const
{
    // Calculate makeup gain to compensate for threshold reduction
    float reduction = std::abs(thresholdDb);
    return Echoel::DSP::FastMath::fastPow(10.0f, reduction / 40.0f);  // Conservative makeup
}
