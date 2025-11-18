#include "EchoelModular.h"
#include <cmath>

// Simplified Virtual Modular implementation
class EchoelModular::Impl
{
public:
    double sampleRate = 44100.0;
    float vco1Phase = 0.0f;
    float vco2Phase = 0.0f;
    float lfoPhase = 0.0f;
    float envelope = 0.0f;

    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
    {
        buffer.clear();

        // Process MIDI
        bool noteOn = false;
        float freq = 440.0f;

        for (const auto metadata : midi)
        {
            auto msg = metadata.getMessage();
            if (msg.isNoteOn())
            {
                noteOn = true;
                freq = 440.0f * std::pow(2.0f, (msg.getNoteNumber() - 69.0f) / 12.0f);
                envelope = 0.0f;
            }
        }

        // Synthesize modular patch
        for (int s = 0; s < buffer.getNumSamples(); ++s)
        {
            // LFO
            lfoPhase += 5.0f / sampleRate;
            if (lfoPhase >= 1.0f) lfoPhase -= 1.0f;
            float lfo = std::sin(juce::MathConstants<float>::twoPi * lfoPhase);

            // VCO 1
            vco1Phase += freq / sampleRate;
            if (vco1Phase >= 1.0f) vco1Phase -= 1.0f;
            float vco1 = vco1Phase * 2.0f - 1.0f;  // Sawtooth

            // VCO 2 (modulated by LFO)
            float freq2 = freq * (1.0f + lfo * 0.1f);
            vco2Phase += freq2 / sampleRate;
            if (vco2Phase >= 1.0f) vco2Phase -= 1.0f;
            float vco2 = vco2Phase * 2.0f - 1.0f;

            // Mix
            float output = (vco1 + vco2) * 0.5f;

            // Envelope
            if (noteOn)
                envelope = std::min(1.0f, envelope + 0.005f);
            else
                envelope *= 0.999f;

            output *= envelope;

            for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
                buffer.addSample(ch, s, output * 0.3f);
        }
    }
};

EchoelModular::EchoelModular() : pImpl(std::make_unique<Impl>()) {}
EchoelModular::~EchoelModular() = default;
void EchoelModular::prepare(double sr, int) { pImpl->sampleRate = sr; }
void EchoelModular::processBlock(juce::AudioBuffer<float>& b, juce::MidiBuffer& m) { pImpl->processBlock(b, m); }
