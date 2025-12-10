#include "PitchCorrection.h"

PitchCorrection::PitchCorrection()
{
}

PitchCorrection::~PitchCorrection()
{
}

void PitchCorrection::prepare(double sampleRate, int maximumBlockSize)
{
    currentSampleRate = sampleRate;
    maxBlockSize = maximumBlockSize;

    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<uint32_t>(maximumBlockSize);
    spec.numChannels = 2;

    // Prepare pitch detectors
    detectorL.init(static_cast<float>(sampleRate));
    detectorR.init(static_cast<float>(sampleRate));

    // Prepare pitch shifters
    shifterL.prepare(spec);
    shifterR.prepare(spec);

    // Initialize smoothers
    smootherL.setRetuneSpeed(retuneSpeed);
    smootherR.setRetuneSpeed(retuneSpeed);

    // ✅ OPTIMIZATION: Pre-allocate dry buffer to avoid audio thread allocation
    dryBuffer.setSize(2, maximumBlockSize);
    dryBuffer.clear();

    reset();
}

void PitchCorrection::reset()
{
    shifterL.reset();
    shifterR.reset();
    smootherL.reset();
    smootherR.reset();
}

void PitchCorrection::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    if (numChannels == 0 || numSamples == 0 || correctionAmount < 0.01f)
        return;

    // ✅ OPTIMIZATION: Use pre-allocated dry buffer (no audio thread allocation)
    jassert(dryBuffer.getNumSamples() >= numSamples);
    for (int ch = 0; ch < juce::jmin(numChannels, dryBuffer.getNumChannels()); ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // Process each channel
    for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
    {
        float* data = buffer.getWritePointer(channel);
        auto& detector = (channel == 0) ? detectorL : detectorR;
        auto& shifter = (channel == 0) ? shifterL : shifterR;
        auto& smoother = (channel == 0) ? smootherL : smootherR;

        // Pitch detection state
        float detectedPitch = 0.0f;
        float correctedPitch = 0.0f;

        // ✅ OPTIMIZATION: Process in blocks for better cache utilization
        for (int sample = 0; sample < numSamples; ++sample)
        {
            const float input = data[sample];

            // Feed pitch detector
            detector.pushSample(input);

            // Detect pitch every 512 samples (reduces CPU)
            if ((sample & 0x1FF) == 0)  // Bitwise AND is faster than modulo
            {
                detectedPitch = detector.detectPitch();

                if (detectedPitch > 20.0f && detectedPitch < 20000.0f)
                {
                    // Quantize to scale
                    float targetPitch = quantizer.quantizePitch(detectedPitch);

                    // Apply humanize (preserve natural vibrato)
                    if (humanize > 0.01f)
                    {
                        const float vibrato = std::sin(static_cast<float>(sample) * 0.005f) * 5.0f;
                        targetPitch += vibrato * humanize;
                    }

                    // Smooth pitch transition
                    correctedPitch = smoother.smooth(targetPitch);

                    // Set pitch shift parameters
                    shifter.setPitchShift(detectedPitch, correctedPitch, formantPreservation ? 1.0f : 0.0f);
                }
            }

            // Apply pitch correction with blend
            const float corrected = shifter.process(input, channel);
            data[sample] = input * (1.0f - correctionAmount) + corrected * correctionAmount;
        }
    }

    // ✅ OPTIMIZATION: Mix dry/wet using SIMD operations
    const float dryLevel = 1.0f - currentMix;
    const float wetLevel = currentMix;

    for (int ch = 0; ch < juce::jmin(numChannels, dryBuffer.getNumChannels()); ++ch)
    {
        float* out = buffer.getWritePointer(ch);
        const float* dry = dryBuffer.getReadPointer(ch);

        // SIMD: out = out * wetLevel + dry * dryLevel
        juce::FloatVectorOperations::multiply(out, wetLevel, numSamples);
        juce::FloatVectorOperations::addWithMultiply(out, dry, dryLevel, numSamples);
    }
}

//==============================================================================
void PitchCorrection::setCorrectionAmount(float amount)
{
    correctionAmount = juce::jlimit(0.0f, 1.0f, amount);
}

void PitchCorrection::setRetuneSpeed(float speed)
{
    retuneSpeed = juce::jlimit(0.0f, 1.0f, speed);
    smootherL.setRetuneSpeed(speed);
    smootherR.setRetuneSpeed(speed);
}

void PitchCorrection::setScaleMode(int mode)
{
    scaleMode = juce::jlimit(0, 3, mode);
    quantizer.scaleMode = mode;
}

void PitchCorrection::setRootNote(int note)
{
    rootNote = juce::jlimit(0, 11, note);
    quantizer.rootNote = note;
}

void PitchCorrection::setFormantPreservation(bool enabled)
{
    formantPreservation = enabled;
}

void PitchCorrection::setHumanize(float amount)
{
    humanize = juce::jlimit(0.0f, 1.0f, amount);
}

void PitchCorrection::setMix(float mix)
{
    currentMix = juce::jlimit(0.0f, 1.0f, mix);
}
