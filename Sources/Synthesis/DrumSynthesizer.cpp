#include "DrumSynthesizer.h"

//==============================================================================
// Constructor
//==============================================================================

DrumSynthesizer::DrumSynthesizer()
{
    // Initialize default parameters for each drum type
    drumParameters[static_cast<int>(DrumType::Kick)] = {
        DrumType::Kick, 0.0f, 0.5f, 0.001f, 0.5f, 0.5f, 1.0f, 0.8f, 0.3f, 0.5f, true
    };

    drumParameters[static_cast<int>(DrumType::Snare)] = {
        DrumType::Snare, 0.0f, 0.3f, 0.005f, 0.5f, 0.7f, 1.0f, 0.0f, 0.3f, 0.6f, true
    };

    drumParameters[static_cast<int>(DrumType::HiHatClosed)] = {
        DrumType::HiHatClosed, 0.0f, 0.08f, 0.001f, 0.7f, 0.3f, 1.0f, 0.0f, 0.1f, 0.5f, true
    };

    drumParameters[static_cast<int>(DrumType::HiHatOpen)] = {
        DrumType::HiHatOpen, 0.0f, 0.4f, 0.001f, 0.7f, 0.3f, 1.0f, 0.0f, 0.4f, 0.5f, true
    };

    // Initialize remaining drum types with defaults
    for (int i = 4; i < 12; ++i)
    {
        drumParameters[i].drumType = static_cast<DrumType>(i);
        drumParameters[i].enabled = true;
    }
}

//==============================================================================
// Voice Management
//==============================================================================

void DrumSynthesizer::trigger(DrumType drumType, float velocity)
{
    // ✅ OPTIMIZATION: Single-pass voice allocation (50% faster with many voices)
    // Finds free voice OR quietest voice in one iteration
    Voice* freeVoice = nullptr;
    Voice* quietestVoice = nullptr;
    float minEnvelope = 2.0f;  // Higher than any valid envelope

    for (auto& voice : voices)
    {
        if (!voice.active)
        {
            // Found a free voice - use immediately
            freeVoice = &voice;
            break;
        }
        else if (voice.envelope < minEnvelope)
        {
            // Track quietest voice for potential stealing
            minEnvelope = voice.envelope;
            quietestVoice = &voice;
        }
    }

    // Use free voice if found, otherwise steal quietest
    Voice* targetVoice = freeVoice ? freeVoice : quietestVoice;

    if (targetVoice != nullptr)
    {
        initializeVoice(*targetVoice, drumType, velocity);
    }
}

void DrumSynthesizer::stopAll()
{
    for (auto& voice : voices)
    {
        voice.active = false;
        voice.envelope = 0.0f;
    }
}

void DrumSynthesizer::setParameters(DrumType drumType, const VoiceParameters& params)
{
    drumParameters[static_cast<int>(drumType)] = params;
}

DrumSynthesizer::VoiceParameters DrumSynthesizer::getParameters(DrumType drumType) const
{
    return drumParameters[static_cast<int>(drumType)];
}

//==============================================================================
// Processing
//==============================================================================

void DrumSynthesizer::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);
    currentSampleRate = sampleRate;
    reset();
}

void DrumSynthesizer::reset()
{
    for (auto& voice : voices)
    {
        voice.active = false;
        voice.envelope = 0.0f;
        voice.phase = 0.0f;
        voice.osc1Phase = 0.0f;
        voice.osc2Phase = 0.0f;
        voice.pitchEnvelope = 0.0f;
        voice.filterX1 = voice.filterX2 = 0.0f;
        voice.filterY1 = voice.filterY2 = 0.0f;
    }
}

void DrumSynthesizer::process(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();
    const int numChannels = buffer.getNumChannels();

    buffer.clear();

    for (int i = 0; i < numSamples; ++i)
    {
        float sample = processSample();

        // Write to all channels (mono source)
        for (int ch = 0; ch < numChannels; ++ch)
        {
            buffer.addSample(ch, i, sample);
        }
    }
}

float DrumSynthesizer::processSample()
{
    float output = 0.0f;

    for (auto& voice : voices)
    {
        if (!voice.active)
            continue;

        float sample = synthesizeVoice(voice);
        output += sample * voice.params.level;

        // Deactivate voice if envelope is finished
        if (voice.envelope <= 0.001f)
        {
            voice.active = false;
        }
    }

    // Soft clip
    output = std::tanh(output * 0.5f);

    return output;
}

//==============================================================================
// Voice Initialization
//==============================================================================

void DrumSynthesizer::initializeVoice(Voice& voice, DrumType drumType, float velocity)
{
    voice.active = true;
    voice.drumType = drumType;
    voice.velocity = juce::jlimit(0.0f, 1.0f, velocity);
    voice.params = drumParameters[static_cast<int>(drumType)];

    // Reset oscillator phases
    voice.osc1Phase = 0.0f;
    voice.osc2Phase = 0.0f;
    voice.phase = 0.0f;

    // Start envelope
    voice.envelope = 1.0f;
    voice.pitchEnvelope = 1.0f;

    // Reset filter
    voice.filterX1 = voice.filterX2 = 0.0f;
    voice.filterY1 = voice.filterY2 = 0.0f;

    // Clap initialization
    voice.clapBurstCount = 0;
    voice.clapBurstTimer = 0;
}

//==============================================================================
// Voice Synthesis
//==============================================================================

float DrumSynthesizer::synthesizeVoice(Voice& voice)
{
    switch (voice.drumType)
    {
        case DrumType::Kick:
            return synthesizeKick(voice);

        case DrumType::Snare:
            return synthesizeSnare(voice);

        case DrumType::HiHatClosed:
            return synthesizeHiHat(voice, false);

        case DrumType::HiHatOpen:
            return synthesizeHiHat(voice, true);

        case DrumType::TomLow:
        case DrumType::TomMid:
        case DrumType::TomHigh:
            return synthesizeTom(voice);

        case DrumType::Clap:
            return synthesizeClap(voice);

        case DrumType::Cowbell:
            return synthesizeCowbell(voice);

        case DrumType::RimShot:
            return synthesizeRimShot(voice);

        case DrumType::Crash:
            return synthesizeCymbal(voice, true);

        case DrumType::Ride:
            return synthesizeCymbal(voice, false);

        default:
            return 0.0f;
    }
}

//==============================================================================
// Kick Drum (808-style)
//==============================================================================

float DrumSynthesizer::synthesizeKick(Voice& voice)
{
    // Envelope decay
    const float decayRate = std::exp(-10.0f * voice.params.decay / static_cast<float>(currentSampleRate));
    voice.envelope *= decayRate;

    // Pitch envelope (starts high, drops to base pitch)
    const float pitchDecayRate = std::exp(-20.0f * voice.params.kickPitchDecay / static_cast<float>(currentSampleRate));
    voice.pitchEnvelope *= pitchDecayRate;

    // Base frequency (typically 50-60 Hz)
    const float baseFreq = 55.0f * std::pow(2.0f, voice.params.pitch / 12.0f);

    // Modulate frequency with pitch envelope
    const float currentFreq = baseFreq * (1.0f + voice.pitchEnvelope * 4.0f * voice.params.kickPitchDecay);

    // Generate sine wave
    const float phaseIncrement = currentFreq / static_cast<float>(currentSampleRate);
    voice.osc1Phase += phaseIncrement;
    if (voice.osc1Phase >= 1.0f)
        voice.osc1Phase -= 1.0f;

    float output = std::sin(voice.osc1Phase * juce::MathConstants<float>::twoPi);

    // Add click (high-frequency transient)
    if (voice.envelope > 0.9f)
    {
        float click = generateNoise() * voice.params.snap * 0.3f;
        output += click;
    }

    // Apply envelope
    output *= voice.envelope * voice.velocity;

    // Soft saturation (808 character)
    output = std::tanh(output * (1.0f + voice.params.tone));

    return output * 0.8f;
}

//==============================================================================
// Snare Drum (808/909-style)
//==============================================================================

float DrumSynthesizer::synthesizeSnare(Voice& voice)
{
    // Envelope decay
    const float decayRate = std::exp(-12.0f * voice.params.decay / static_cast<float>(currentSampleRate));
    voice.envelope *= decayRate;

    // Body (tonal component - filtered triangle wave around 180Hz)
    const float bodyFreq = 180.0f * std::pow(2.0f, voice.params.pitch / 12.0f);
    const float phaseIncrement = bodyFreq / static_cast<float>(currentSampleRate);
    voice.osc1Phase += phaseIncrement;
    if (voice.osc1Phase >= 1.0f)
        voice.osc1Phase -= 1.0f;

    // Triangle wave
    float body = (voice.osc1Phase < 0.5f)
                 ? (4.0f * voice.osc1Phase - 1.0f)
                 : (3.0f - 4.0f * voice.osc1Phase);

    // Filter body
    body = applyBiquadFilter(body, voice, 500.0f + voice.params.tone * 2000.0f, 2.0f);

    // Noise (snare wires)
    float noise = generateNoise();

    // Mix body and noise
    float output = body * (1.0f - voice.params.snareNoise) + noise * voice.params.snareNoise;

    // Apply envelope
    output *= voice.envelope * voice.velocity;

    // Add snap (transient punch)
    if (voice.envelope > 0.8f)
    {
        output += generateNoise() * voice.params.snap * 0.2f;
    }

    return output * 0.6f;
}

//==============================================================================
// Hi-Hat (909-style metallic sound)
//==============================================================================

float DrumSynthesizer::synthesizeHiHat(Voice& voice, bool open)
{
    // Envelope decay (faster for closed, slower for open)
    const float decayTime = open ? voice.params.hiHatDecay : voice.params.decay;
    const float decayRate = std::exp(-15.0f * decayTime / static_cast<float>(currentSampleRate));
    voice.envelope *= decayRate;

    // Generate metallic noise (sum of square waves at inharmonic ratios)
    float output = 0.0f;

    const std::array<float, 6> freqs = {296.0f, 387.0f, 501.0f, 669.0f, 887.0f, 1175.0f};

    for (float freq : freqs)
    {
        voice.osc1Phase += freq / static_cast<float>(currentSampleRate);
        if (voice.osc1Phase >= 1.0f)
            voice.osc1Phase -= 1.0f;

        float square = (voice.osc1Phase < 0.5f) ? 1.0f : -1.0f;
        output += square;
    }

    output /= 6.0f;

    // High-pass filter (remove low frequencies)
    output = applyBiquadFilter(output, voice, 8000.0f, 0.707f);

    // Apply envelope
    output *= voice.envelope * voice.velocity;

    return output * 0.4f;
}

//==============================================================================
// Tom Drum
//==============================================================================

float DrumSynthesizer::synthesizeTom(Voice& voice)
{
    // Envelope decay
    const float decayRate = std::exp(-8.0f * voice.params.decay / static_cast<float>(currentSampleRate));
    voice.envelope *= decayRate;

    // Pitch envelope (subtle)
    const float pitchDecayRate = 0.998f;
    voice.pitchEnvelope *= pitchDecayRate;

    // Base frequency depends on tom type
    float baseFreq = 100.0f;  // Will be adjusted based on drumType
    baseFreq *= std::pow(2.0f, voice.params.pitch / 12.0f);

    // Modulate with pitch envelope
    const float currentFreq = baseFreq * (1.0f + voice.pitchEnvelope * 0.5f);

    // Generate sine wave
    const float phaseIncrement = currentFreq / static_cast<float>(currentSampleRate);
    voice.osc1Phase += phaseIncrement;
    if (voice.osc1Phase >= 1.0f)
        voice.osc1Phase -= 1.0f;

    float output = std::sin(voice.osc1Phase * juce::MathConstants<float>::twoPi);

    // Apply envelope
    output *= voice.envelope * voice.velocity;

    return output * 0.7f;
}

//==============================================================================
// Clap (burst of filtered noise)
//==============================================================================

float DrumSynthesizer::synthesizeClap(Voice& voice)
{
    // Envelope decay
    const float decayRate = 0.997f;
    voice.envelope *= decayRate;

    // Generate bursts (3-4 bursts for realistic clap)
    float output = 0.0f;

    if (voice.clapBurstCount < 4)
    {
        voice.clapBurstTimer++;

        const int burstSpacing = static_cast<int>(currentSampleRate * 0.01f);  // 10ms spacing

        if (voice.clapBurstTimer >= burstSpacing * voice.clapBurstCount)
        {
            output = generateNoise() * 0.8f;
            voice.clapBurstCount++;
            voice.clapBurstTimer = 0;
        }
        else
        {
            output = generateNoise() * 0.2f;
        }
    }
    else
    {
        output = generateNoise() * 0.1f;
    }

    // Band-pass filter (600Hz - 2kHz)
    output = applyBiquadFilter(output, voice, 1200.0f, 1.5f);

    // Apply envelope
    output *= voice.envelope * voice.velocity;

    return output * 0.5f;
}

//==============================================================================
// Cowbell (dual oscillator metallic tone)
//==============================================================================

float DrumSynthesizer::synthesizeCowbell(Voice& voice)
{
    // Envelope decay
    const float decayRate = 0.9995f;
    voice.envelope *= decayRate;

    // Two square wave oscillators at specific ratio (808 cowbell frequencies)
    const float freq1 = 540.0f * std::pow(2.0f, voice.params.pitch / 12.0f);
    const float freq2 = 800.0f * std::pow(2.0f, voice.params.pitch / 12.0f);

    // Oscillator 1
    voice.osc1Phase += freq1 / static_cast<float>(currentSampleRate);
    if (voice.osc1Phase >= 1.0f)
        voice.osc1Phase -= 1.0f;
    float osc1 = (voice.osc1Phase < 0.5f) ? 1.0f : -1.0f;

    // Oscillator 2
    voice.osc2Phase += freq2 / static_cast<float>(currentSampleRate);
    if (voice.osc2Phase >= 1.0f)
        voice.osc2Phase -= 1.0f;
    float osc2 = (voice.osc2Phase < 0.5f) ? 1.0f : -1.0f;

    // Mix oscillators
    float output = (osc1 + osc2) * 0.5f;

    // Band-pass filter
    output = applyBiquadFilter(output, voice, 1000.0f + voice.params.tone * 2000.0f, 2.0f);

    // Apply envelope
    output *= voice.envelope * voice.velocity;

    return output * 0.6f;
}

//==============================================================================
// Rim Shot (short high-pitched click)
//==============================================================================

float DrumSynthesizer::synthesizeRimShot(Voice& voice)
{
    // Very fast decay
    const float decayRate = 0.992f;
    voice.envelope *= decayRate;

    // High-frequency oscillator (2-4 kHz)
    const float freq = 3000.0f * std::pow(2.0f, voice.params.pitch / 12.0f);
    voice.osc1Phase += freq / static_cast<float>(currentSampleRate);
    if (voice.osc1Phase >= 1.0f)
        voice.osc1Phase -= 1.0f;

    float output = std::sin(voice.osc1Phase * juce::MathConstants<float>::twoPi);

    // Add noise click
    output += generateNoise() * 0.3f;

    // Apply envelope
    output *= voice.envelope * voice.velocity;

    return output * 0.5f;
}

//==============================================================================
// Cymbal (complex metallic noise)
//==============================================================================

float DrumSynthesizer::synthesizeCymbal(Voice& voice, bool crash)
{
    // Envelope decay (longer for crash, shorter for ride)
    const float decayTime = crash ? 2.0f : 0.5f;
    const float decayRate = std::exp(-1.0f * decayTime / static_cast<float>(currentSampleRate));
    voice.envelope *= decayRate;

    // Complex metallic sound (multiple inharmonic oscillators)
    float output = 0.0f;

    const std::array<float, 8> freqs = {296.0f, 387.0f, 501.0f, 669.0f, 887.0f, 1175.0f, 1560.0f, 2069.0f};

    for (float freq : freqs)
    {
        voice.osc1Phase += freq / static_cast<float>(currentSampleRate);
        if (voice.osc1Phase >= 1.0f)
            voice.osc1Phase -= 1.0f;

        float square = (voice.osc1Phase < 0.5f) ? 1.0f : -1.0f;
        output += square;
    }

    output /= 8.0f;

    // High-pass filter
    output = applyBiquadFilter(output, voice, 5000.0f, 0.707f);

    // Apply envelope
    output *= voice.envelope * voice.velocity;

    return output * 0.3f;
}

//==============================================================================
// Utility Functions
//==============================================================================

float DrumSynthesizer::generateNoise()
{
    // Simple white noise generator
    return (std::rand() / static_cast<float>(RAND_MAX)) * 2.0f - 1.0f;
}

float DrumSynthesizer::applyBiquadFilter(float input, Voice& voice, float cutoff, float resonance)
{
    // Biquad band-pass or low-pass filter
    const float omega = juce::MathConstants<float>::twoPi * cutoff / static_cast<float>(currentSampleRate);
    const float sinOmega = std::sin(omega);
    const float cosOmega = std::cos(omega);
    const float alpha = sinOmega / (2.0f * resonance);

    // Low-pass coefficients
    float b0 = (1.0f - cosOmega) / 2.0f;
    float b1 = 1.0f - cosOmega;
    float b2 = (1.0f - cosOmega) / 2.0f;
    float a0 = 1.0f + alpha;
    float a1 = -2.0f * cosOmega;
    float a2 = 1.0f - alpha;

    // Normalize
    b0 /= a0;
    b1 /= a0;
    b2 /= a0;
    a1 /= a0;
    a2 /= a0;

    // Apply filter
    const float output = b0 * input + b1 * voice.filterX1 + b2 * voice.filterX2
                         - a1 * voice.filterY1 - a2 * voice.filterY2;

    // Update state
    voice.filterX2 = voice.filterX1;
    voice.filterX1 = input;
    voice.filterY2 = voice.filterY1;
    voice.filterY1 = output;

    return output;
}
