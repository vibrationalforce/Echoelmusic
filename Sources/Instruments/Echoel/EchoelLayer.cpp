#include "EchoelLayer.h"
#include <cmath>

// Simplified Multi-Layer Engine implementation
class EchoelLayer::Impl
{
public:
    double sampleRate = 44100.0;

    struct Layer
    {
        bool active = false;
        float phase = 0.0f;
        float envelope = 0.0f;
        int note = 0;
    };

    std::vector<Layer> layers;

    Impl() { layers.resize(8); }  // 8 layers

    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
    {
        buffer.clear();

        // Process MIDI - trigger all layers
        for (const auto metadata : midi)
        {
            auto msg = metadata.getMessage();
            if (msg.isNoteOn())
            {
                int note = msg.getNoteNumber();
                for (size_t i = 0; i < layers.size(); ++i)
                {
                    layers[i].active = true;
                    layers[i].note = note + static_cast<int>(i) - 4;  // Spread layers
                    layers[i].phase = 0.0f;
                    layers[i].envelope = 0.0f;
                }
            }
        }

        // Synthesize all layers
        for (auto& layer : layers)
        {
            if (layer.active)
            {
                for (int s = 0; s < buffer.getNumSamples(); ++s)
                {
                    float freq = 440.0f * std::pow(2.0f, (layer.note - 69.0f) / 12.0f);
                    layer.phase += freq / sampleRate;
                    if (layer.phase >= 1.0f) layer.phase -= 1.0f;

                    float sample = std::sin(juce::MathConstants<float>::twoPi * layer.phase);
                    layer.envelope = std::min(1.0f, layer.envelope + 0.002f);

                    for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
                        buffer.addSample(ch, s, sample * layer.envelope * 0.1f);
                }
            }
        }
    }
};

EchoelLayer::EchoelLayer() : pImpl(std::make_unique<Impl>()) {}
EchoelLayer::~EchoelLayer() = default;
void EchoelLayer::prepare(double sr, int) { pImpl->sampleRate = sr; }
void EchoelLayer::processBlock(juce::AudioBuffer<float>& b, juce::MidiBuffer& m) { pImpl->processBlock(b, m); }
