#include "EchoelRetro.h"
#include <cmath>
#include <random>

//==============================================================================
// EchoelRetro - Vintage Synthesizer Emulation
//==============================================================================

class EchoelRetro::Impl
{
public:
    VintageSynth currentSynth = VintageSynth::Minimoog;
    CircuitAgingParams agingParams;
    float heartRate = 70.0f;
    float warmupProgress = 0.0f;
    double sampleRate = 44100.0;

    // Voice management
    struct Voice
    {
        bool active = false;
        int midiNote = 0;
        float velocity = 0.0f;
        float phase1 = 0.0f;
        float phase2 = 0.0f;
        float filterCutoff = 1000.0f;
        float filterResonance = 0.5f;
        float envelope = 0.0f;
        bool isReleasing = false;
    };

    std::vector<Voice> voices;
    static constexpr int MAX_VOICES = 16;

    Impl()
    {
        voices.resize(MAX_VOICES);
    }

    void setSynth(VintageSynth synth)
    {
        currentSynth = synth;
    }

    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
    {
        buffer.clear();

        // Update warmup progress (faster with higher heart rate)
        float warmupRate = (heartRate / 70.0f) * 0.001f;
        warmupProgress = std::min(1.0f, warmupProgress + warmupRate);

        // Process MIDI
        for (const auto metadata : midi)
        {
            auto message = metadata.getMessage();

            if (message.isNoteOn())
            {
                triggerNote(message.getNoteNumber(), message.getFloatVelocity());
            }
            else if (message.isNoteOff())
            {
                releaseNote(message.getNoteNumber());
            }
        }

        // Synthesize voices
        for (auto& voice : voices)
        {
            if (voice.active)
            {
                for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
                {
                    float output = synthesizeVoice(voice);
                    updateEnvelope(voice);

                    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
                    {
                        buffer.addSample(channel, sample, output * 0.3f);
                    }

                    if (voice.isReleasing && voice.envelope <= 0.0f)
                    {
                        voice.active = false;
                    }
                }
            }
        }

        // Apply warmup effect (duller when cold)
        if (warmupProgress < 1.0f)
        {
            buffer.applyGain(0.5f + warmupProgress * 0.5f);
        }
    }

    void triggerNote(int midiNote, float velocity)
    {
        for (auto& voice : voices)
        {
            if (!voice.active)
            {
                voice.active = true;
                voice.midiNote = midiNote;
                voice.velocity = velocity;
                voice.phase1 = 0.0f;
                voice.phase2 = 0.0f;
                voice.envelope = 0.0f;
                voice.isReleasing = false;

                // Set filter cutoff based on note
                voice.filterCutoff = 100.0f + midiNote * 30.0f * agingParams.filterTracking;
                break;
            }
        }
    }

    void releaseNote(int midiNote)
    {
        for (auto& voice : voices)
        {
            if (voice.active && voice.midiNote == midiNote)
            {
                voice.isReleasing = true;
            }
        }
    }

    float synthesizeVoice(Voice& voice)
    {
        float freq = 440.0f * std::pow(2.0f, (voice.midiNote - 69.0f) / 12.0f);

        // Add tuning drift (vintage instability)
        static std::random_device rd;
        static std::mt19937 gen(rd());
        std::normal_distribution<float> driftDist(1.0f, agingParams.tuningDrift * 0.002f);
        freq *= driftDist(gen);

        float output = 0.0f;

        switch (currentSynth)
        {
            case VintageSynth::Minimoog:
                output = synthesizeMinimoog(voice, freq);
                break;
            case VintageSynth::ARP2600:
                output = synthesizeARP2600(voice, freq);
                break;
            case VintageSynth::CS80:
                output = synthesizeCS80(voice, freq);
                break;
            case VintageSynth::Juno60:
                output = synthesizeJuno60(voice, freq);
                break;
            case VintageSynth::Prophet5:
                output = synthesizeProphet5(voice, freq);
                break;
            default:
                output = synthesizeMinimoog(voice, freq);
                break;
        }

        return output * voice.envelope * voice.velocity;
    }

    float synthesizeMinimoog(Voice& voice, float freq)
    {
        // 3 oscillators + 24dB ladder filter
        voice.phase1 += freq / sampleRate;
        if (voice.phase1 >= 1.0f) voice.phase1 -= 1.0f;

        voice.phase2 += (freq * 1.01f) / sampleRate;  // Slight detune
        if (voice.phase2 >= 1.0f) voice.phase2 -= 1.0f;

        // Sawtooth oscillators
        float osc1 = (voice.phase1 * 2.0f - 1.0f);
        float osc2 = (voice.phase2 * 2.0f - 1.0f);

        float mixed = (osc1 + osc2) * 0.5f;

        // Simple ladder filter
        static float filterState = 0.0f;
        float cutoff = voice.filterCutoff / sampleRate;
        filterState = filterState * (1.0f - cutoff) + mixed * cutoff;

        return filterState;
    }

    float synthesizeARP2600(Voice& voice, float freq)
    {
        // VCO + ring mod + filter
        voice.phase1 += freq / sampleRate;
        if (voice.phase1 >= 1.0f) voice.phase1 -= 1.0f;

        float saw = voice.phase1 * 2.0f - 1.0f;
        float pulse = (voice.phase1 < 0.5f) ? 1.0f : -1.0f;

        return (saw * 0.7f + pulse * 0.3f);
    }

    float synthesizeCS80(Voice& voice, float freq)
    {
        // Dual oscillator per voice + ring mod
        voice.phase1 += freq / sampleRate;
        if (voice.phase1 >= 1.0f) voice.phase1 -= 1.0f;

        voice.phase2 += (freq * 0.99f) / sampleRate;
        if (voice.phase2 >= 1.0f) voice.phase2 -= 1.0f;

        float saw1 = voice.phase1 * 2.0f - 1.0f;
        float saw2 = voice.phase2 * 2.0f - 1.0f;

        // Ring modulation
        float ring = saw1 * saw2;

        return (saw1 + saw2) * 0.4f + ring * 0.2f;
    }

    float synthesizeJuno60(Voice& voice, float freq)
    {
        // PWM + chorus
        voice.phase1 += freq / sampleRate;
        if (voice.phase1 >= 1.0f) voice.phase1 -= 1.0f;

        float pwm = 0.5f + std::sin(voice.phase1 * 10.0f) * 0.3f;
        float pulse = (voice.phase1 < pwm) ? 1.0f : -1.0f;

        return pulse;
    }

    float synthesizeProphet5(Voice& voice, float freq)
    {
        // 2 VCO + poly mod
        voice.phase1 += freq / sampleRate;
        if (voice.phase1 >= 1.0f) voice.phase1 -= 1.0f;

        voice.phase2 += (freq * 1.005f) / sampleRate;
        if (voice.phase2 >= 1.0f) voice.phase2 -= 1.0f;

        float saw1 = voice.phase1 * 2.0f - 1.0f;
        float tri2 = std::abs(voice.phase2 * 4.0f - 2.0f) - 1.0f;

        return (saw1 + tri2) * 0.5f;
    }

    void updateEnvelope(Voice& voice)
    {
        if (voice.isReleasing)
        {
            voice.envelope *= 0.999f;  // Release
        }
        else
        {
            voice.envelope = std::min(1.0f, voice.envelope + 0.01f);  // Attack
        }
    }
};

//==============================================================================
// Public Interface
//==============================================================================

EchoelRetro::EchoelRetro()
    : pImpl(std::make_unique<Impl>())
{
}

EchoelRetro::~EchoelRetro() = default;

void EchoelRetro::setSynth(VintageSynth synth)
{
    pImpl->setSynth(synth);
}

void EchoelRetro::setCircuitAging(const CircuitAgingParams& params)
{
    pImpl->agingParams = params;
}

void EchoelRetro::setHeartRate(float bpm)
{
    pImpl->heartRate = juce::jlimit(40.0f, 200.0f, bpm);
}

float EchoelRetro::getWarmupProgress() const
{
    return pImpl->warmupProgress;
}

void EchoelRetro::prepare(double sampleRate, int samplesPerBlock)
{
    pImpl->sampleRate = sampleRate;
}

void EchoelRetro::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
{
    pImpl->processBlock(buffer, midi);
}
