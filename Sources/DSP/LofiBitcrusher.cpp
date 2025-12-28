#include "LofiBitcrusher.h"
#include "../Core/DSPOptimizations.h"

LofiBitcrusher::LofiBitcrusher()
{
}

LofiBitcrusher::~LofiBitcrusher()
{
}

void LofiBitcrusher::prepare(double sampleRate, int maximumBlockSize)
{
    currentSampleRate = sampleRate;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<uint32_t>(maximumBlockSize);
    spec.numChannels = 2;

    // Prepare sample rate reducers
    srrL.setSampleRate(static_cast<float>(sampleRate));
    srrR.setSampleRate(static_cast<float>(sampleRate));

    // Update target rates
    float targetRate = sampleRate * (1.0f - currentSRReduction);
    srrL.setTargetRate(targetRate);
    srrR.setTargetRate(targetRate);

    // Prepare wow & flutter delay
    wowFlutterDelay.prepare(spec);
    wowFlutterDelay.setMaximumDelayInSamples(static_cast<int>(0.05f * sampleRate));  // 50ms

    // Pre-allocate dry buffer to avoid allocations in audio thread
    dryBuffer.setSize(2, maximumBlockSize, false, false, true);

    reset();
}

void LofiBitcrusher::reset()
{
    srrL.reset();
    srrR.reset();
    wowFlutterDelay.reset();
    wowPhase = 0.0f;
    flutterPhase = 0.0f;
}

void LofiBitcrusher::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numChannels == 0 || numSamples == 0)
        return;

    // Store dry signal using pre-allocated buffer (NO ALLOCATION!)
    for (int ch = 0; ch < numChannels; ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // Process each channel
    for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
    {
        auto* data = buffer.getWritePointer(channel);
        auto& srr = (channel == 0) ? srrL : srrR;
        auto& noiseGen = (channel == 0) ? noiseGenL : noiseGenR;

        for (int sample = 0; sample < numSamples; ++sample)
        {
            float input = data[sample];

            // 1. Sample Rate Reduction
            if (currentSRReduction > 0.01f)
            {
                input = srr.process(input);
            }

            // 2. Bit Depth Reduction
            if (currentBitDepth < 16.0f)
            {
                int bits = static_cast<int>(std::round(currentBitDepth));
                bits = juce::jlimit(1, 16, bits);
                input = quantize(input, bits);
            }

            // 3. Wow & Flutter (Tape Speed Variation)
            if (currentWowFlutter > 0.01f)
            {
                const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();

                // Wow: slow pitch modulation (0.5-2 Hz) - using fast sin
                float wow = trigTables.fastSin(wowPhase) * 0.002f;
                wowPhase += 1.5f / static_cast<float>(currentSampleRate);
                if (wowPhase >= 1.0f) wowPhase -= 1.0f;

                // Flutter: fast pitch modulation (5-15 Hz) - using fast sin
                float flutter = trigTables.fastSin(flutterPhase) * 0.001f;
                flutterPhase += 10.0f / static_cast<float>(currentSampleRate);
                if (flutterPhase >= 1.0f) flutterPhase -= 1.0f;

                // Combine and scale by amount
                float pitchMod = (wow + flutter) * currentWowFlutter * static_cast<float>(currentSampleRate);

                wowFlutterDelay.pushSample(channel, input);
                input = wowFlutterDelay.popSample(channel, std::abs(pitchMod) + 1.0f);
            }

            // 4. Analog Warmth (Soft Clipping)
            if (currentWarmth > 0.01f)
            {
                input = softClip(input, currentWarmth);
            }

            // 5. Noise (Vinyl Crackle + Tape Hiss)
            if (currentNoise > 0.01f)
            {
                float noise = noiseGen.generate();
                input += noise * currentNoise;
            }

            data[sample] = input;
        }
    }

    // Mix dry/wet with SIMD-optimized FloatVectorOperations
    const float dryGain = 1.0f - currentMix;
    const float wetGain = currentMix;

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
void LofiBitcrusher::setBitDepth(float bits)
{
    currentBitDepth = juce::jlimit(1.0f, 16.0f, bits);
}

void LofiBitcrusher::setSampleRateReduction(float amount)
{
    currentSRReduction = juce::jlimit(0.0f, 1.0f, amount);

    // Update target sample rates
    float targetRate = static_cast<float>(currentSampleRate) * (1.0f - amount);
    srrL.setTargetRate(targetRate);
    srrR.setTargetRate(targetRate);
}

void LofiBitcrusher::setNoise(float amount)
{
    currentNoise = juce::jlimit(0.0f, 1.0f, amount);
}

void LofiBitcrusher::setWowFlutter(float amount)
{
    currentWowFlutter = juce::jlimit(0.0f, 1.0f, amount);
}

void LofiBitcrusher::setWarmth(float warmth)
{
    currentWarmth = juce::jlimit(0.0f, 1.0f, warmth);
}

void LofiBitcrusher::setMix(float mix)
{
    currentMix = juce::jlimit(0.0f, 1.0f, mix);
}
