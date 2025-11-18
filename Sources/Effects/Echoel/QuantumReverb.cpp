#include "QuantumReverb.h"
#include <cmath>

//==============================================================================
QuantumReverb::QuantumReverb()
{
    // Initialize delay lines for FDN reverb
    delayLines.resize(8);
    for (auto& line : delayLines)
    {
        line.resize(8192, 0.0f);
        line.writePos = 0;
    }
}

void QuantumReverb::prepare(double sampleRate, int samplesPerBlock)
{
    this->sampleRate = sampleRate;
}

void QuantumReverb::processBlock(juce::AudioBuffer<float>& buffer)
{
    if (params.mix <= 0.0f)
        return;

    // Create wet buffer
    juce::AudioBuffer<float> wetBuffer(buffer.getNumChannels(), buffer.getNumSamples());
    wetBuffer.clear();

    // Simple FDN reverb
    for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
    {
        float input = 0.0f;
        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
            input += buffer.getSample(ch, sample);
        input /= buffer.getNumChannels();

        float output = 0.0f;

        // Process delay lines
        for (size_t i = 0; i < delayLines.size(); ++i)
        {
            auto& line = delayLines[i];

            // Read from delay line
            int delayLength = 1000 + static_cast<int>(i * 500 * params.size);
            int readPos = (line.writePos - delayLength + line.buffer.size()) % line.buffer.size();
            float delayed = line.buffer[readPos];

            // Feedback
            float feedback = delayed * params.decay * 0.85f;

            // Write to delay line
            line.buffer[line.writePos] = input + feedback;
            line.writePos = (line.writePos + 1) % line.buffer.size();

            output += delayed;
        }

        output /= delayLines.size();

        // Damping
        static float dampState = 0.0f;
        dampState = dampState * params.damping + output * (1.0f - params.damping);
        output = dampState;

        // Mix to wet buffer
        for (int ch = 0; ch < wetBuffer.getNumChannels(); ++ch)
            wetBuffer.setSample(ch, sample, output);
    }

    // Mix dry/wet
    for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
    {
        for (int s = 0; s < buffer.getNumSamples(); ++s)
        {
            float dry = buffer.getSample(ch, s) * (1.0f - params.mix);
            float wet = wetBuffer.getSample(ch, s) * params.mix;
            buffer.setSample(ch, s, dry + wet);
        }
    }
}

void QuantumReverb::setParams(const ReverbParams& p)
{
    params = p;
}

void QuantumReverb::setHeartRate(float bpm)
{
    heartRate = juce::jlimit(40.0f, 200.0f, bpm);

    // Modulate size with heart rate
    if (biometricParams.heartRateModulatesSize)
    {
        float normalizedHR = (heartRate - 70.0f) / 70.0f;
        params.size = juce::jlimit(0.0f, 1.0f, params.size * (1.0f + normalizedHR * 0.3f));
    }
}
