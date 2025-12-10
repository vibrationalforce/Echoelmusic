#include "EdgeControl.h"

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

void EdgeControl::prepare(double sampleRate, int maxBlockSizeParam)
{
    currentSampleRate = sampleRate;
    maxBlockSize = maxBlockSizeParam;

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

    // ✅ OPTIMIZATION: Pre-allocate buffers to avoid audio thread allocation
    dryBuffer.setSize(2, maxBlockSize);
    dryBuffer.clear();
    // Pre-allocate oversampled buffer (worst case: 8x oversampling)
    oversampledBuffer.setSize(2, maxBlockSize * 8);
    oversampledBuffer.clear();

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
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();
    const int safeChannels = juce::jmin(numChannels, 2);

    // Update input meters
    updateMeters(buffer, true);

    // ✅ OPTIMIZATION: Use pre-allocated buffer (no audio thread allocation)
    for (int ch = 0; ch < safeChannels; ++ch)
    {
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);
    }

    // Apply input gain
    if (std::abs(inputGainDb) > 0.1f)
    {
        buffer.applyGain(juce::Decibels::decibelsToGain(inputGainDb));
    }

    // Oversample if enabled
    if (oversampling && oversamplingFactor > 1)
    {
        juce::dsp::AudioBlock<float> block(buffer);
        auto oversampledBlock = oversampling->processSamplesUp(block);

        // ✅ OPTIMIZATION: Use pre-allocated oversampled buffer
        const int oversampledSamples = static_cast<int>(oversampledBlock.getNumSamples());

        for (size_t ch = 0; ch < oversampledBlock.getNumChannels(); ++ch)
        {
            oversampledBuffer.copyFrom(static_cast<int>(ch), 0,
                                      oversampledBlock.getChannelPointer(ch),
                                      oversampledSamples);
        }

        // Create a view into the pre-allocated buffer with correct size
        juce::AudioBuffer<float> oversampledView(oversampledBuffer.getArrayOfWritePointers(),
                                                  safeChannels, oversampledSamples);

        // Process based on mode
        switch (processingMode)
        {
            case ProcessingMode::Stereo:
                processStereo(oversampledView);
                break;

            case ProcessingMode::MidSide:
                processMidSide(oversampledView);
                break;

            case ProcessingMode::Multiband:
                processMultiband(oversampledView);
                break;
        }

        // Copy back to block for downsampling
        for (size_t ch = 0; ch < oversampledBlock.getNumChannels(); ++ch)
        {
            std::copy(oversampledBuffer.getReadPointer(static_cast<int>(ch)),
                     oversampledBuffer.getReadPointer(static_cast<int>(ch)) + oversampledSamples,
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
        buffer.applyGain(juce::Decibels::decibelsToGain(outputGainDb));
    }

    // Apply ceiling with SIMD-friendly loop
    if (truePeakMode && ceilingDb < 0.0f)
    {
        const float ceilingGain = juce::Decibels::decibelsToGain(ceilingDb);
        for (int ch = 0; ch < numChannels; ++ch)
        {
            float* channelData = buffer.getWritePointer(ch);
            // ✅ OPTIMIZATION: Use SIMD clip
            juce::FloatVectorOperations::clip(channelData, channelData,
                                               -ceilingGain, ceilingGain, numSamples);
        }
    }

    // Mix dry/wet with SIMD optimization
    if (mix < 0.999f)
    {
        for (int ch = 0; ch < safeChannels; ++ch)
        {
            float* wetData = buffer.getWritePointer(ch);
            const float* dryData = dryBuffer.getReadPointer(ch);

            // ✅ OPTIMIZATION: SIMD wet/dry mixing
            const float wetGain = mix;
            const float dryGain = 1.0f - mix;
            juce::FloatVectorOperations::multiply(wetData, wetGain, numSamples);
            juce::FloatVectorOperations::addWithMultiply(wetData, dryData, dryGain, numSamples);
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
    return juce::Decibels::gainToDecibels(inputLevel.load());
}

float EdgeControl::getOutputLevel() const
{
    return juce::Decibels::gainToDecibels(outputLevel.load());
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
    const float threshold = juce::Decibels::decibelsToGain(thresholdDb);

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

    const float threshold = juce::Decibels::decibelsToGain(thresholdDb);

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
        // Above threshold - soft clip with tanh
        float excess = absInput - threshold;
        return sign * (threshold + std::tanh(excess * 3.0f) * 0.3f);
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
        output = (biased > 0.0f) ? std::tanh(biased * 1.5f) : std::tanh(biased * 0.8f);
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
        // Soft saturation
        output = std::tanh(normalized * 1.2f) * 0.9f;
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
            float gr = juce::Decibels::gainToDecibels(peak / inputPeak);
            gainReduction.store(gr);
        }
    }
}

float EdgeControl::calculateMakeupGain() const
{
    // Calculate makeup gain to compensate for threshold reduction
    float reduction = std::abs(thresholdDb);
    return std::pow(10.0f, reduction / 40.0f);  // Conservative makeup
}
