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

    // Store dry signal
    juce::AudioBuffer<float> dryBuffer(numChannels, numSamples);
    for (int ch = 0; ch < numChannels; ++ch)
        dryBuffer.copyFrom(ch, 0, buffer, ch, 0, numSamples);

    // Process each channel
    for (int channel = 0; channel < juce::jmin(2, numChannels); ++channel)
    {
        auto* data = buffer.getWritePointer(channel);
        auto& detector = (channel == 0) ? detectorL : detectorR;
        auto& shifter = (channel == 0) ? shifterL : shifterR;
        auto& smoother = (channel == 0) ? smootherL : smootherR;

        // Detect pitch every 512 samples (reduces CPU)
        float detectedPitch = 0.0f;
        float correctedPitch = 0.0f;

        for (int sample = 0; sample < numSamples; ++sample)
        {
            float input = data[sample];

            // Feed pitch detector
            detector.pushSample(input);

            // Detect pitch periodically
            if (sample % 512 == 0)
            {
                detectedPitch = detector.detectPitch();

                if (detectedPitch > 20.0f && detectedPitch < 20000.0f)
                {
                    // Quantize to scale
                    float targetPitch = quantizer.quantizePitch(detectedPitch);

                    // Apply humanize (preserve natural vibrato)
                    if (humanize > 0.01f)
                    {
                        float vibrato = std::sin(static_cast<float>(sample) * 0.005f) * 5.0f;
                        targetPitch += vibrato * humanize;
                    }

                    // Smooth pitch transition
                    correctedPitch = smoother.smooth(targetPitch);

                    // Set pitch shift parameters
                    shifter.setPitchShift(detectedPitch, correctedPitch, formantPreservation ? 1.0f : 0.0f);
                }
            }

            // Apply pitch correction
            float corrected = shifter.process(input, channel);

            // Blend original and corrected based on correction amount
            data[sample] = input * (1.0f - correctionAmount) + corrected * correctionAmount;
        }
    }

    // Mix dry/wet
    for (int ch = 0; ch < numChannels; ++ch)
    {
        auto* wet = buffer.getReadPointer(ch);
        auto* dry = dryBuffer.getReadPointer(ch);
        auto* out = buffer.getWritePointer(ch);

        for (int i = 0; i < numSamples; ++i)
            out[i] = dry[i] * (1.0f - currentMix) + wet[i] * currentMix;
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
