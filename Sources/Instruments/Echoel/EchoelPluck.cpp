#include "EchoelPluck.h"
#include <cmath>
#include <random>
#include <algorithm>

//==============================================================================
// Waveguide String (Karplus-Strong Algorithm)
//==============================================================================

class WaveguideString
{
public:
    void initialize(float frequency, double sampleRate)
    {
        int length = static_cast<int>(sampleRate / frequency) + 1;
        delayLine.resize(length, 0.0f);
        writePos = 0;
        this->sampleRate = sampleRate;
        this->frequency = frequency;
    }

    void excite(float amplitude, EchoelPluck::PlayTechnique technique)
    {
        std::random_device rd;
        std::mt19937 gen(rd());
        std::uniform_real_distribution<float> noiseDist(-1.0f, 1.0f);

        // Fill delay line with initial excitation based on technique
        for (size_t i = 0; i < delayLine.size(); ++i)
        {
            switch (technique)
            {
                case EchoelPluck::PlayTechnique::Fingerstyle:
                    // Soft, rounded excitation
                    delayLine[i] = std::sin(juce::MathConstants<float>::pi * i / delayLine.size()) * amplitude * 0.7f;
                    break;

                case EchoelPluck::PlayTechnique::Pick:
                    // Sharp, triangular excitation
                    if (i < delayLine.size() / 2)
                        delayLine[i] = (2.0f * i / delayLine.size()) * amplitude;
                    else
                        delayLine[i] = (2.0f - 2.0f * i / delayLine.size()) * amplitude;
                    break;

                case EchoelPluck::PlayTechnique::Slap:
                    // Percussive noise burst
                    delayLine[i] = noiseDist(gen) * amplitude * 1.2f;
                    break;

                case EchoelPluck::PlayTechnique::Harmonic:
                    // Sine wave at harmonic node
                    delayLine[i] = std::sin(juce::MathConstants<float>::twoPi * 2.0f * i / delayLine.size()) * amplitude * 0.5f;
                    break;

                case EchoelPluck::PlayTechnique::Tremolo:
                    // Multiple rapid plucks
                    delayLine[i] = noiseDist(gen) * amplitude * 0.6f;
                    break;

                default:
                    // Default: noise burst
                    delayLine[i] = noiseDist(gen) * amplitude;
                    break;
            }
        }

        isActive = true;
    }

    float process(float damping, float stiffness)
    {
        if (!isActive || delayLine.empty())
            return 0.0f;

        // Read from delay line
        float output = delayLine[writePos];

        // Low-pass filter (averaging) for damping
        int nextPos = (writePos + 1) % delayLine.size();
        float filtered = (output + delayLine[nextPos]) * 0.5f * damping;

        // Optional: String stiffness (all-pass filter)
        if (stiffness > 0.0f)
        {
            filtered = filtered * (1.0f - stiffness * 0.1f) + prevOutput * stiffness * 0.1f;
        }

        prevOutput = filtered;

        // Write back to delay line
        delayLine[writePos] = filtered;
        writePos = nextPos;

        // Check if string has decayed
        if (std::abs(output) < 0.001f)
        {
            decayCounter++;
            if (decayCounter > delayLine.size() * 10)  // Fully decayed
            {
                isActive = false;
            }
        }

        return output;
    }

    bool isStringActive() const { return isActive; }

private:
    std::vector<float> delayLine;
    int writePos = 0;
    float prevOutput = 0.0f;
    double sampleRate = 44100.0;
    float frequency = 440.0f;
    bool isActive = false;
    int decayCounter = 0;
};

//==============================================================================
// EchoelPluck Implementation
//==============================================================================

class EchoelPluck::Impl
{
public:
    static constexpr int MAX_VOICES = 16;

    struct Voice
    {
        bool active = false;
        int midiNote = 0;
        float velocity = 0.0f;
        WaveguideString string;
        float releaseEnvelope = 1.0f;
        bool isReleasing = false;
    };

    std::vector<Voice> voices;
    InstrumentType currentInstrument = InstrumentType::AcousticGuitar;
    PlayTechnique currentTechnique = PlayTechnique::Fingerstyle;
    PhysicalModelParams physicalParams;
    double sampleRate = 44100.0;
    float stressLevel = 0.0f;

    Impl()
    {
        voices.resize(MAX_VOICES);
    }

    void setInstrument(InstrumentType type)
    {
        currentInstrument = type;

        // Configure physical parameters based on instrument
        switch (type)
        {
            case InstrumentType::AcousticGuitar:
                physicalParams.stringTension = 0.7f;
                physicalParams.bodyResonance = 0.6f;
                physicalParams.pickupPosition = 0.5f;
                physicalParams.fretNoise = 0.3f;
                physicalParams.stringBuzz = 0.1f;
                break;

            case InstrumentType::ElectricGuitar:
                physicalParams.stringTension = 0.75f;
                physicalParams.bodyResonance = 0.3f;  // Less resonant
                physicalParams.pickupPosition = 0.6f;
                physicalParams.fretNoise = 0.2f;
                physicalParams.stringBuzz = 0.15f;
                break;

            case InstrumentType::Bass:
                physicalParams.stringTension = 0.8f;
                physicalParams.bodyResonance = 0.7f;
                physicalParams.pickupPosition = 0.55f;
                physicalParams.fretNoise = 0.25f;
                physicalParams.stringBuzz = 0.2f;
                break;

            case InstrumentType::Harp:
                physicalParams.stringTension = 0.6f;
                physicalParams.bodyResonance = 0.8f;
                physicalParams.pickupPosition = 0.5f;
                physicalParams.fretNoise = 0.0f;  // No frets
                physicalParams.stringBuzz = 0.0f;
                break;

            case InstrumentType::Sitar:
                physicalParams.stringTension = 0.65f;
                physicalParams.bodyResonance = 0.9f;  // Very resonant
                physicalParams.pickupPosition = 0.4f;
                physicalParams.fretNoise = 0.1f;
                physicalParams.stringBuzz = 0.4f;  // Characteristic buzz
                break;

            case InstrumentType::Koto:
                physicalParams.stringTension = 0.7f;
                physicalParams.bodyResonance = 0.75f;
                physicalParams.pickupPosition = 0.45f;
                physicalParams.fretNoise = 0.05f;
                physicalParams.stringBuzz = 0.05f;
                break;

            case InstrumentType::Banjo:
                physicalParams.stringTension = 0.8f;
                physicalParams.bodyResonance = 0.4f;  // Bright, less resonant
                physicalParams.pickupPosition = 0.5f;
                physicalParams.fretNoise = 0.35f;
                physicalParams.stringBuzz = 0.1f;
                break;

            case InstrumentType::Mandolin:
                physicalParams.stringTension = 0.75f;
                physicalParams.bodyResonance = 0.65f;
                physicalParams.pickupPosition = 0.5f;
                physicalParams.fretNoise = 0.2f;
                physicalParams.stringBuzz = 0.1f;
                break;

            case InstrumentType::Ukulele:
                physicalParams.stringTension = 0.6f;
                physicalParams.bodyResonance = 0.7f;
                physicalParams.pickupPosition = 0.5f;
                physicalParams.fretNoise = 0.15f;
                physicalParams.stringBuzz = 0.05f;
                break;

            default:
                break;
        }
    }

    void triggerNote(int midiNote, float velocity)
    {
        // Find free voice
        Voice* voice = nullptr;
        for (auto& v : voices)
        {
            if (!v.active)
            {
                voice = &v;
                break;
            }
        }

        if (!voice)
            return;  // No free voices

        voice->active = true;
        voice->midiNote = midiNote;
        voice->velocity = velocity;
        voice->isReleasing = false;
        voice->releaseEnvelope = 1.0f;

        // Calculate frequency
        float frequency = 440.0f * std::pow(2.0f, (midiNote - 69.0f) / 12.0f);

        // Apply stress to tension (affects tuning slightly)
        float stressFactor = 1.0f + (stressLevel * 0.02f);  // Up to 2% sharp when stressed
        frequency *= stressFactor;

        // Initialize waveguide
        voice->string.initialize(frequency, sampleRate);
        voice->string.excite(velocity, currentTechnique);
    }

    void releaseNote(int midiNote)
    {
        for (auto& voice : voices)
        {
            if (voice.active && voice.midiNote == midiNote && !voice.isReleasing)
            {
                voice.isReleasing = true;
            }
        }
    }

    void processBlock(juce::AudioBuffer<float>& buffer)
    {
        const int numSamples = buffer.getNumSamples();

        for (auto& voice : voices)
        {
            if (voice.active)
            {
                for (int sample = 0; sample < numSamples; ++sample)
                {
                    // Process waveguide
                    float damping = 0.995f + (physicalParams.stringTension * 0.004f);
                    float stiffness = (1.0f - physicalParams.stringTension) * 0.3f;

                    float output = voice.string.process(damping, stiffness);

                    // Apply body resonance (simplified)
                    output = applyBodyResonance(output);

                    // Add fret noise if applicable
                    if (physicalParams.fretNoise > 0.0f && sample < 100)
                    {
                        static std::random_device rd;
                        static std::mt19937 gen(rd());
                        std::uniform_real_distribution<float> noiseDist(-1.0f, 1.0f);

                        float fretNoiseAmp = physicalParams.fretNoise * (1.0f - sample / 100.0f) * 0.1f;
                        output += noiseDist(gen) * fretNoiseAmp;
                    }

                    // Add string buzz
                    if (physicalParams.stringBuzz > 0.0f)
                    {
                        // Buzz is a high-frequency distortion
                        output = std::tanh(output * (1.0f + physicalParams.stringBuzz * 2.0f));
                    }

                    // Apply release envelope
                    if (voice.isReleasing)
                    {
                        voice.releaseEnvelope *= 0.9995f;  // Exponential decay
                        output *= voice.releaseEnvelope;

                        if (voice.releaseEnvelope < 0.001f || !voice.string.isStringActive())
                        {
                            voice.active = false;
                        }
                    }

                    // Mix to buffer
                    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
                    {
                        buffer.addSample(channel, sample, output * voice.velocity * 0.5f);
                    }
                }
            }
        }
    }

private:
    float applyBodyResonance(float input)
    {
        // Simplified body resonance: one-pole filter
        static float bodyState = 0.0f;

        float resonanceFactor = physicalParams.bodyResonance;
        bodyState = bodyState * (0.9f + resonanceFactor * 0.09f) + input * 0.1f;

        return input + bodyState * resonanceFactor * 0.4f;
    }
};

//==============================================================================
// EchoelPluck Public Interface
//==============================================================================

EchoelPluck::EchoelPluck()
    : pImpl(std::make_unique<Impl>())
{
}

EchoelPluck::~EchoelPluck() = default;

void EchoelPluck::setInstrument(InstrumentType type)
{
    pImpl->setInstrument(type);
}

void EchoelPluck::setPlayTechnique(PlayTechnique technique)
{
    pImpl->currentTechnique = technique;
}

void EchoelPluck::setPhysicalModel(const PhysicalModelParams& params)
{
    pImpl->physicalParams = params;
}

void EchoelPluck::setStressLevel(float stress)
{
    pImpl->stressLevel = juce::jlimit(0.0f, 1.0f, stress);
}

void EchoelPluck::prepare(double sampleRate, int samplesPerBlock)
{
    pImpl->sampleRate = sampleRate;
}

void EchoelPluck::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
{
    buffer.clear();

    // Process MIDI
    for (const auto metadata : midi)
    {
        auto message = metadata.getMessage();

        if (message.isNoteOn())
        {
            pImpl->triggerNote(message.getNoteNumber(), message.getFloatVelocity());
        }
        else if (message.isNoteOff())
        {
            pImpl->releaseNote(message.getNoteNumber());
        }
    }

    // Process audio
    pImpl->processBlock(buffer);
}
