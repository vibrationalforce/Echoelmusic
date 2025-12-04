#include "ConvolutionReverb.h"

//==============================================================================
// Constructor
//==============================================================================

ConvolutionReverb::ConvolutionReverb()
{
}

//==============================================================================
// Parameters
//==============================================================================

void ConvolutionReverb::setMix(float mixAmount)
{
    mix = juce::jlimit(0.0f, 1.0f, mixAmount);
}

void ConvolutionReverb::setPreDelay(float delayMs)
{
    preDelay = juce::jlimit(0.0f, 100.0f, delayMs);
    updatePreDelayBuffers();
}

void ConvolutionReverb::setLowCut(float freq)
{
    lowCutFreq = juce::jlimit(20.0f, 500.0f, freq);
}

void ConvolutionReverb::setHighCut(float freq)
{
    highCutFreq = juce::jlimit(2000.0f, 20000.0f, freq);
}

//==============================================================================
// Impulse Response
//==============================================================================

void ConvolutionReverb::loadImpulseResponse(const juce::AudioBuffer<float>& ir)
{
    if (ir.getNumSamples() == 0)
        return;

    // Copy impulse response
    juce::AudioBuffer<float> irCopy(ir.getNumChannels(), ir.getNumSamples());
    for (int ch = 0; ch < ir.getNumChannels(); ++ch)
    {
        irCopy.copyFrom(ch, 0, ir, ch, 0, ir.getNumSamples());
    }

    // Load into convolution engine
    convolutionEngine.loadImpulseResponse(std::move(irCopy),
                                          currentSampleRate,
                                          juce::dsp::Convolution::Stereo::yes,
                                          juce::dsp::Convolution::Trim::no,
                                          juce::dsp::Convolution::Normalise::yes);

    impulseLoaded = true;
}

bool ConvolutionReverb::loadImpulseResponseFromFile(const juce::File& file)
{
    if (!file.existsAsFile())
        return false;

    // Load audio file
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    std::unique_ptr<juce::AudioFormatReader> reader(formatManager.createReaderFor(file));

    if (reader == nullptr)
        return false;

    // Read into buffer
    juce::AudioBuffer<float> irBuffer(static_cast<int>(reader->numChannels),
                                      static_cast<int>(reader->lengthInSamples));

    reader->read(&irBuffer, 0, static_cast<int>(reader->lengthInSamples), 0, true, true);

    // Load impulse response
    loadImpulseResponse(irBuffer);

    return true;
}

int ConvolutionReverb::getImpulseResponseLength() const
{
    return impulseLoaded ? static_cast<int>(convolutionEngine.getCurrentIRSize()) : 0;
}

//==============================================================================
// Processing
//==============================================================================

void ConvolutionReverb::prepare(double sampleRate, int maxBlockSize)
{
    currentSampleRate = sampleRate;

    // Prepare convolution engine
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<juce::uint32>(maxBlockSize);
    spec.numChannels = 2;

    convolutionEngine.prepare(spec);

    // Allocate pre-delay buffers
    updatePreDelayBuffers();

    // Allocate filter states
    filterStates.resize(2);

    // Pre-allocate dry buffer to avoid allocations in audio thread
    dryBuffer.setSize(2, maxBlockSize, false, false, true);

    reset();
}

void ConvolutionReverb::reset()
{
    convolutionEngine.reset();

    // Clear pre-delay buffers
    for (auto& buffer : preDelayBuffers)
    {
        std::fill(buffer.begin(), buffer.end(), 0.0f);
    }

    preDelayWritePositions.assign(preDelayWritePositions.size(), 0);

    // Reset filters
    for (auto& fs : filterStates)
    {
        fs.hpX1 = fs.hpY1 = 0.0f;
        fs.lpY1 = 0.0f;
    }
}

void ConvolutionReverb::process(juce::AudioBuffer<float>& buffer)
{
    if (!impulseLoaded || mix <= 0.001f)
        return;

    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    // Store dry signal using pre-allocated buffer (NO ALLOCATION!)
    for (int ch = 0; ch < numChannels; ++ch)
    {
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);
    }

    // Apply pre-delay
    if (preDelay > 0.0f)
    {
        applyPreDelay(buffer);
    }

    // Apply convolution
    juce::dsp::AudioBlock<float> block(buffer);
    juce::dsp::ProcessContextReplacing<float> context(block);
    convolutionEngine.process(context);

    // Apply filtering
    applyFiltering(buffer);

    // Mix dry/wet with SIMD-optimized FloatVectorOperations
    const float dryGain = 1.0f - mix;
    const float wetGain = mix;

    for (int ch = 0; ch < numChannels; ++ch)
    {
        float* wetData = buffer.getWritePointer(ch);
        const float* dryData = dryBuffer.getReadPointer(ch);

        // SIMD-optimized mixing (uses SSE/NEON/AVX under the hood)
        juce::FloatVectorOperations::multiply(wetData, wetGain, numSamples);
        juce::FloatVectorOperations::addWithMultiply(wetData, dryData, dryGain, numSamples);
    }
}

//==============================================================================
// Internal Methods
//==============================================================================

void ConvolutionReverb::updatePreDelayBuffers()
{
    const int delaySamples = static_cast<int>(preDelay * currentSampleRate / 1000.0f);

    if (delaySamples > 0)
    {
        preDelayBuffers.resize(2);
        preDelayWritePositions.resize(2);

        for (auto& buffer : preDelayBuffers)
        {
            buffer.resize(delaySamples);
            std::fill(buffer.begin(), buffer.end(), 0.0f);
        }

        std::fill(preDelayWritePositions.begin(), preDelayWritePositions.end(), 0);
    }
}

void ConvolutionReverb::applyPreDelay(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = juce::jmin(buffer.getNumChannels(), 2);

    for (int ch = 0; ch < numChannels; ++ch)
    {
        float* channelData = buffer.getWritePointer(ch);
        auto& delayBuffer = preDelayBuffers[ch];
        int& writePos = preDelayWritePositions[ch];

        for (int i = 0; i < numSamples; ++i)
        {
            float input = channelData[i];

            // Read delayed sample
            channelData[i] = delayBuffer[writePos];

            // Write new sample
            delayBuffer[writePos] = input;

            // Advance write position
            writePos = (writePos + 1) % delayBuffer.size();
        }
    }
}

void ConvolutionReverb::applyFiltering(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = juce::jmin(buffer.getNumChannels(), static_cast<int>(filterStates.size()));

    for (int ch = 0; ch < numChannels; ++ch)
    {
        float* channelData = buffer.getWritePointer(ch);
        auto& fs = filterStates[ch];

        for (int i = 0; i < numSamples; ++i)
        {
            float sample = channelData[i];

            // Apply highpass (low cut)
            sample = applyHighpass(sample, fs);

            // Apply lowpass (high cut)
            sample = applyLowpass(sample, fs);

            channelData[i] = sample;
        }
    }
}

float ConvolutionReverb::applyHighpass(float input, FilterState& state)
{
    // Simple 1-pole highpass
    const float omega = juce::MathConstants<float>::twoPi * lowCutFreq / static_cast<float>(currentSampleRate);
    const float coeff = 1.0f / (1.0f + omega);

    float output = coeff * (state.hpY1 + input - state.hpX1);
    state.hpX1 = input;
    state.hpY1 = output;

    return output;
}

float ConvolutionReverb::applyLowpass(float input, FilterState& state)
{
    // Simple 1-pole lowpass
    const float omega = juce::MathConstants<float>::twoPi * highCutFreq / static_cast<float>(currentSampleRate);
    const float coeff = omega / (1.0f + omega);

    float output = coeff * input + (1.0f - coeff) * state.lpY1;
    state.lpY1 = output;

    return output;
}
