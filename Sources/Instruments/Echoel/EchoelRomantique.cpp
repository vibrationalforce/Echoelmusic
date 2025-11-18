#include "EchoelRomantique.h"
#include <cmath>

// Simplified Romantic Orchestral Engine implementation
class EchoelRomantique::Impl
{
public:
    double sampleRate = 44100.0;

    struct Voice
    {
        bool active = false;
        int note = 0;
        float velocity = 0.0f;
        float phase = 0.0f;
        float envelope = 0.0f;
    };

    std::vector<Voice> voices;

    Impl() { voices.resize(32); }

    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
    {
        buffer.clear();

        // Process MIDI
        for (const auto metadata : midi)
        {
            auto msg = metadata.getMessage();
            if (msg.isNoteOn())
            {
                for (auto& v : voices)
                {
                    if (!v.active)
                    {
                        v.active = true;
                        v.note = msg.getNoteNumber();
                        v.velocity = msg.getFloatVelocity();
                        v.phase = 0.0f;
                        v.envelope = 0.0f;
                        break;
                    }
                }
            }
            else if (msg.isNoteOff())
            {
                for (auto& v : voices)
                    if (v.active && v.note == msg.getNoteNumber())
                        v.active = false;
            }
        }

        // Synthesize strings
        for (auto& v : voices)
        {
            if (v.active)
            {
                for (int s = 0; s < buffer.getNumSamples(); ++s)
                {
                    float freq = 440.0f * std::pow(2.0f, (v.note - 69.0f) / 12.0f);
                    v.phase += freq / sampleRate;
                    if (v.phase >= 1.0f) v.phase -= 1.0f;

                    float sample = std::sin(juce::MathConstants<float>::twoPi * v.phase);
                    v.envelope = std::min(1.0f, v.envelope + 0.001f);

                    for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
                        buffer.addSample(ch, s, sample * v.envelope * v.velocity * 0.1f);
                }
            }
        }
    }
};

EchoelRomantique::EchoelRomantique() : pImpl(std::make_unique<Impl>()) {}
EchoelRomantique::~EchoelRomantique() = default;
void EchoelRomantique::prepare(double sr, int) { pImpl->sampleRate = sr; }
void EchoelRomantique::processBlock(juce::AudioBuffer<float>& b, juce::MidiBuffer& m) { pImpl->processBlock(b, m); }
