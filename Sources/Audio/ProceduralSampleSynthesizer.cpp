#include "ProceduralSampleSynthesizer.h"
#include <cmath>

//==============================================================================
// Construction / Destruction
//==============================================================================

ProceduralSampleSynthesizer::ProceduralSampleSynthesizer()
{
    randomGen.seed(std::random_device{}());
}

ProceduralSampleSynthesizer::~ProceduralSampleSynthesizer()
{
    clearCache();
}

//==============================================================================
// Initialization
//==============================================================================

void ProceduralSampleSynthesizer::initialize(double sampleRate)
{
    currentSampleRate = sampleRate;
}

void ProceduralSampleSynthesizer::setSampleRate(double sampleRate)
{
    currentSampleRate = sampleRate;
    clearCache();  // Clear cache when sample rate changes
}

//==============================================================================
// DRUM SYNTHESIS
//==============================================================================

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateKick(
    float pitchHz, float punch, float decay, float click, float distortion)
{
    const int numSamples = static_cast<int>(currentSampleRate * decay);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    // Pitch envelope (exponential decay from higher pitch)
    float pitchStart = pitchHz * (1.0f + punch * 3.0f);

    for (int i = 0; i < numSamples; i++)
    {
        float t = static_cast<float>(i) / currentSampleRate;
        float phase = 0.0f;

        // Exponential pitch decay
        float currentPitch = pitchHz + (pitchStart - pitchHz) * std::exp(-t * 10.0f);
        phase += currentPitch * juce::MathConstants<float>::twoPi * t;

        // Sine wave (sub fundamental)
        float sample = std::sin(phase);

        // Add click (high frequency transient)
        if (i < static_cast<int>(currentSampleRate * 0.005f))
        {
            sample += click * std::sin(phase * 8.0f) * (1.0f - t / 0.005f);
        }

        // Amplitude envelope
        float env = std::exp(-t / decay);
        sample *= env;

        // Soft distortion
        if (distortion > 0.0f)
        {
            sample = std::tanh(sample * (1.0f + distortion * 3.0f));
        }

        // Write to both channels
        buffer.setSample(0, i, sample);
        buffer.setSample(1, i, sample);
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateSnare(
    float pitchHz, float tone, float snap, float noise, float decay)
{
    const int numSamples = static_cast<int>(currentSampleRate * decay);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    for (int i = 0; i < numSamples; i++)
    {
        float t = static_cast<float>(i) / currentSampleRate;

        // Tonal component (body)
        float phase = pitchHz * juce::MathConstants<float>::twoPi * t;
        float tonal = std::sin(phase) + 0.5f * std::sin(phase * 2.0f);
        tonal *= std::exp(-t / (decay * 0.5f)) * tone;

        // Noise component (snares)
        float noiseSignal = whiteNoise() * noise;

        // Snap (attack transient)
        float snapSignal = 0.0f;
        if (i < static_cast<int>(currentSampleRate * 0.01f))
        {
            snapSignal = whiteNoise() * snap * (1.0f - t / 0.01f);
        }

        // Combine
        float sample = tonal + noiseSignal * std::exp(-t / decay) + snapSignal;

        // Amplitude envelope
        float env = std::exp(-t / decay);
        sample *= env * 0.7f;

        buffer.setSample(0, i, sample);
        buffer.setSample(1, i, sample);
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateHihat(
    float brightness, float decay, bool closed, float metallic)
{
    const float actualDecay = closed ? decay : decay * 3.0f;
    const int numSamples = static_cast<int>(currentSampleRate * actualDecay);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    for (int i = 0; i < numSamples; i++)
    {
        float t = static_cast<float>(i) / currentSampleRate;

        // High-pass filtered noise
        float sample = whiteNoise();

        // Add metallic ringing (sum of inharmonic partials)
        if (metallic > 0.0f)
        {
            float phase = t * juce::MathConstants<float>::twoPi;
            sample += metallic * (
                std::sin(phase * 243.0f) * 0.3f +
                std::sin(phase * 354.0f) * 0.2f +
                std::sin(phase * 540.0f) * 0.15f +
                std::sin(phase * 810.0f) * 0.1f
            );
        }

        // Brightness (simulated high-pass)
        sample *= brightness;

        // Envelope
        float env = closed ?
            std::exp(-t / actualDecay) :
            std::exp(-t / actualDecay) * (1.0f - std::exp(-t * 50.0f));

        sample *= env * 0.5f;

        buffer.setSample(0, i, sample);
        buffer.setSample(1, i, sample);
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateClap(
    float brightness, float decay, int layers)
{
    const int numSamples = static_cast<int>(currentSampleRate * decay);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    // Generate multiple layers with slight delays for realistic clap
    for (int layer = 0; layer < layers; layer++)
    {
        int delayOffset = static_cast<int>((layer * 0.01f + randomDist(randomGen) * 0.005f) * currentSampleRate);

        for (int i = delayOffset; i < numSamples; i++)
        {
            float t = static_cast<float>(i - delayOffset) / currentSampleRate;
            float sample = whiteNoise() * brightness;
            float env = std::exp(-t / (decay * 0.3f));

            buffer.addSample(0, i, sample * env * 0.3f);
            buffer.addSample(1, i, sample * env * 0.3f);
        }
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateTom(
    float pitchHz, float decay, float tone)
{
    return generateKick(pitchHz, tone * 0.5f, decay, 0.2f, 0.1f);
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateCymbal(
    float brightness, float decay, bool crash)
{
    const int numSamples = static_cast<int>(currentSampleRate * decay);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    for (int i = 0; i < numSamples; i++)
    {
        float t = static_cast<float>(i) / currentSampleRate;

        // Complex inharmonic spectrum
        float sample = 0.0f;
        float phase = t * juce::MathConstants<float>::twoPi;

        // Add multiple inharmonic partials
        const float partials[] = {243.0f, 354.0f, 433.0f, 540.0f, 647.0f, 810.0f, 933.0f};
        for (int p = 0; p < 7; p++)
        {
            float partial = std::sin(phase * partials[p] * brightness);
            partial *= std::exp(-t * (p + 1) / decay);
            sample += partial / (p + 1);
        }

        // Add noise
        sample += whiteNoise() * 0.3f * brightness;

        // Envelope
        float env = crash ?
            std::exp(-t / (decay * 0.5f)) * (1.0f - std::exp(-t * 20.0f)) :
            std::exp(-t / decay);

        sample *= env * 0.4f;

        buffer.setSample(0, i, sample);
        buffer.setSample(1, i, sample);
    }

    return buffer;
}

//==============================================================================
// BASS SYNTHESIS
//==============================================================================

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generate808Bass(
    float pitchHz, float decay, float drive, float tone)
{
    const int numSamples = static_cast<int>(currentSampleRate * decay);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    for (int i = 0; i < numSamples; i++)
    {
        float t = static_cast<float>(i) / currentSampleRate;
        float phase = pitchHz * juce::MathConstants<float>::twoPi * t;

        // Classic 808: sine + harmonics
        float sample = std::sin(phase);                    // Fundamental
        sample += std::sin(phase * 2.0f) * 0.3f * tone;   // 2nd harmonic
        sample += std::sin(phase * 3.0f) * 0.1f * tone;   // 3rd harmonic

        // Envelope
        float env = std::exp(-t / decay);
        sample *= env;

        // Saturation/drive
        if (drive > 1.0f)
        {
            sample = std::tanh(sample * drive) / drive;
        }

        buffer.setSample(0, i, sample * 0.8f);
        buffer.setSample(1, i, sample * 0.8f);
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateSubBass(
    float pitchHz, float wave, float duration)
{
    const int numSamples = static_cast<int>(currentSampleRate * duration);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    for (int i = 0; i < numSamples; i++)
    {
        float t = static_cast<float>(i) / currentSampleRate;
        float phase = pitchHz * juce::MathConstants<float>::twoPi * t;

        // Morph between sine and triangle
        float sine = std::sin(phase);
        float triangle = triangleWave(std::fmod(phase, juce::MathConstants<float>::twoPi));
        float sample = sine * (1.0f - wave) + triangle * wave;

        buffer.setSample(0, i, sample * 0.8f);
        buffer.setSample(1, i, sample * 0.8f);
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateReeseBass(
    float pitchHz, float detune, int voices, float spread, float duration)
{
    const int numSamples = static_cast<int>(currentSampleRate * duration);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    // Generate multiple detuned sawtooth waves
    for (int voice = 0; voice < voices; voice++)
    {
        float voiceDetune = ((voice - voices / 2.0f) / voices) * detune * pitchHz;
        float voicePitch = pitchHz + voiceDetune;

        // Pan each voice for stereo spread
        float pan = ((float)voice / voices) * spread;
        float leftGain = std::cos(pan * juce::MathConstants<float>::halfPi);
        float rightGain = std::sin(pan * juce::MathConstants<float>::halfPi);

        for (int i = 0; i < numSamples; i++)
        {
            float t = static_cast<float>(i) / currentSampleRate;
            float phase = std::fmod(voicePitch * t, 1.0f);
            float sample = sawWave(phase * juce::MathConstants<float>::twoPi);

            buffer.addSample(0, i, sample * leftGain / voices);
            buffer.addSample(1, i, sample * rightGain / voices);
        }
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateFMBass(
    float pitchHz, float modAmount, float modRatio, float duration)
{
    const int numSamples = static_cast<int>(currentSampleRate * duration);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    float modFreq = pitchHz * modRatio;

    for (int i = 0; i < numSamples; i++)
    {
        float t = static_cast<float>(i) / currentSampleRate;

        // FM synthesis: carrier modulated by modulator
        float modPhase = modFreq * juce::MathConstants<float>::twoPi * t;
        float modulator = std::sin(modPhase) * modAmount;

        float carrierPhase = pitchHz * juce::MathConstants<float>::twoPi * t + modulator;
        float sample = std::sin(carrierPhase);

        buffer.setSample(0, i, sample * 0.7f);
        buffer.setSample(1, i, sample * 0.7f);
    }

    return buffer;
}

//==============================================================================
// MELODIC SYNTHESIS
//==============================================================================

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateWavetable(
    float pitchHz, int waveform, float detune, int voices, float duration)
{
    const int numSamples = static_cast<int>(currentSampleRate * duration);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    for (int voice = 0; voice < voices; voice++)
    {
        float voiceDetune = ((voice - voices / 2.0f) / voices) * detune * pitchHz;
        float voicePitch = pitchHz + voiceDetune;

        for (int i = 0; i < numSamples; i++)
        {
            float t = static_cast<float>(i) / currentSampleRate;
            float phase = std::fmod(voicePitch * t, 1.0f) * juce::MathConstants<float>::twoPi;
            float sample = generateWaveform(phase, waveform);

            buffer.addSample(0, i, sample / voices * 0.8f);
            buffer.addSample(1, i, sample / voices * 0.8f);
        }
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generatePad(
    float pitchHz, float brightness, const juce::String& character, float duration)
{
    const int numSamples = static_cast<int>(currentSampleRate * duration);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    // Multiple detuned layers for thick pad sound
    const int numVoices = 7;

    for (int voice = 0; voice < numVoices; voice++)
    {
        float detune = ((voice - numVoices / 2.0f) / numVoices) * 0.02f * pitchHz;
        float voicePitch = pitchHz + detune;

        // Pan voices
        float pan = (float)voice / numVoices;
        float leftGain = std::cos(pan * juce::MathConstants<float>::halfPi);
        float rightGain = std::sin(pan * juce::MathConstants<float>::halfPi);

        for (int i = 0; i < numSamples; i++)
        {
            float t = static_cast<float>(i) / currentSampleRate;

            // Slow LFO for movement
            float lfo = std::sin(t * juce::MathConstants<float>::twoPi * 0.1f) * 0.1f + 0.9f;

            float phase = voicePitch * juce::MathConstants<float>::twoPi * t * lfo;

            // Waveform based on character
            float sample = 0.0f;
            if (character == "warm")
            {
                sample = sawWave(phase) * 0.6f + std::sin(phase) * 0.4f;
            }
            else if (character == "bright")
            {
                sample = sawWave(phase);
            }
            else if (character == "dark")
            {
                sample = std::sin(phase);
            }
            else // ethereal
            {
                sample = std::sin(phase) + std::sin(phase * 2.01f) * 0.3f;
            }

            // Slow attack/release envelope
            float env = 1.0f;
            if (t < 0.5f)
                env = t / 0.5f;  // Attack
            if (t > duration - 0.5f)
                env = (duration - t) / 0.5f;  // Release

            sample *= env * brightness;

            buffer.addSample(0, i, sample * leftGain / numVoices * 0.6f);
            buffer.addSample(1, i, sample * rightGain / numVoices * 0.6f);
        }
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateLead(
    float pitchHz, float hardness, float resonance, float duration)
{
    const int numSamples = static_cast<int>(currentSampleRate * duration);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    for (int i = 0; i < numSamples; i++)
    {
        float t = static_cast<float>(i) / currentSampleRate;
        float phase = pitchHz * juce::MathConstants<float>::twoPi * t;

        // Hard sync saw wave
        float sample = sawWave(phase);

        // Add harmonics for hardness
        sample += sawWave(phase * 2.0f) * hardness * 0.3f;
        sample += sawWave(phase * 3.0f) * hardness * 0.2f;

        // Simple resonant filter simulation
        if (resonance > 0.0f)
        {
            float filterFreq = pitchHz * (2.0f + resonance * 4.0f);
            sample *= (1.0f + resonance * std::sin(filterFreq * juce::MathConstants<float>::twoPi * t));
        }

        buffer.setSample(0, i, sample * 0.7f);
        buffer.setSample(1, i, sample * 0.7f);
    }

    return buffer;
}

//==============================================================================
// TEXTURE SYNTHESIS
//==============================================================================

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateAtmosphere(
    float brightness, float movement, float duration)
{
    const int numSamples = static_cast<int>(currentSampleRate * duration);
    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.clear();

    // Multiple slow-moving sine waves at different frequencies
    const float freqs[] = {60.0f, 80.0f, 120.0f, 150.0f, 200.0f, 250.0f};

    for (int i = 0; i < numSamples; i++)
    {
        float t = static_cast<float>(i) / currentSampleRate;
        float sample = 0.0f;

        for (int f = 0; f < 6; f++)
        {
            float freq = freqs[f] * brightness;
            float lfo = std::sin(t * movement * (f + 1) * 0.1f) * 0.5f + 0.5f;
            sample += std::sin(freq * juce::MathConstants<float>::twoPi * t) * lfo / 6.0f;
        }

        buffer.setSample(0, i, sample * 0.3f);
        buffer.setSample(1, i, sample * 0.3f);
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateNoise(
    float color, float duration)
{
    const int numSamples = static_cast<int>(currentSampleRate * duration);
    juce::AudioBuffer<float> buffer(2, numSamples);

    for (int i = 0; i < numSamples; i++)
    {
        float sample;

        if (color < 0.25f)
            sample = whiteNoise();
        else if (color < 0.75f)
            sample = pinkNoise();
        else
            sample = brownNoise();

        buffer.setSample(0, i, sample * 0.5f);
        buffer.setSample(1, i, sample * 0.5f);
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateVinylCrackle(
    float intensity, float duration)
{
    const int numSamples = static_cast<int>(currentSampleRate * duration);
    juce::AudioBuffer<float> buffer(2, numSamples);

    for (int i = 0; i < numSamples; i++)
    {
        // Random pops and crackles
        float sample = whiteNoise() * 0.1f;

        if (randomDist(randomGen) > (1.0f - intensity * 0.01f))
        {
            sample = randomDist(randomGen) * intensity;
        }

        buffer.setSample(0, i, sample * 0.3f);
        buffer.setSample(1, i, sample * 0.3f);
    }

    return buffer;
}

//==============================================================================
// FX SYNTHESIS
//==============================================================================

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateImpact(
    float power, float duration)
{
    const int numSamples = static_cast<int>(currentSampleRate * duration);
    juce::AudioBuffer<float> buffer(2, numSamples);

    for (int i = 0; i < numSamples; i++)
    {
        float t = static_cast<float>(i) / currentSampleRate;

        // Low frequency thump + noise burst
        float thump = std::sin(50.0f * juce::MathConstants<float>::twoPi * t);
        float noise = whiteNoise() * 0.3f;

        float env = std::exp(-t / (duration * 0.3f)) * power;

        float sample = (thump + noise) * env;

        buffer.setSample(0, i, sample * 0.8f);
        buffer.setSample(1, i, sample * 0.8f);
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateRiser(
    float startPitch, float endPitch, float duration)
{
    const int numSamples = static_cast<int>(currentSampleRate * duration);
    juce::AudioBuffer<float> buffer(2, numSamples);

    for (int i = 0; i < numSamples; i++)
    {
        float t = static_cast<float>(i) / currentSampleRate;
        float progress = t / duration;

        // Exponential pitch rise
        float pitch = startPitch * std::pow(endPitch / startPitch, progress);
        float phase = pitch * juce::MathConstants<float>::twoPi * t;

        float sample = sawWave(phase) + whiteNoise() * 0.2f;
        sample *= progress;  // Amplitude rise

        buffer.setSample(0, i, sample * 0.6f);
        buffer.setSample(1, i, sample * 0.6f);
    }

    return buffer;
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateSweep(
    float startFreq, float endFreq, float duration)
{
    const int numSamples = static_cast<int>(currentSampleRate * duration);
    juce::AudioBuffer<float> buffer(2, numSamples);

    for (int i = 0; i < numSamples; i++)
    {
        float t = static_cast<float>(i) / currentSampleRate;
        float progress = t / duration;

        // Logarithmic frequency sweep
        float freq = startFreq * std::pow(endFreq / startFreq, progress);
        float phase = freq * juce::MathConstants<float>::twoPi * t;

        float sample = std::sin(phase);

        buffer.setSample(0, i, sample * 0.7f);
        buffer.setSample(1, i, sample * 0.7f);
    }

    return buffer;
}

//==============================================================================
// ECHOELMUSIC SIGNATURE PRESETS
//==============================================================================

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateSignatureKick(int variation)
{
    // Optimized signature kicks for Echoelmusic
    switch (variation)
    {
        case 0: // Deep & Punchy
            return generateKick(55.0f, 0.9f, 0.6f, 0.4f, 0.25f);
        case 1: // Tight & Modern
            return generateKick(65.0f, 0.8f, 0.4f, 0.5f, 0.3f);
        case 2: // Sub-Heavy
            return generateKick(50.0f, 0.7f, 0.8f, 0.2f, 0.15f);
        default:
            return generateKick(60.0f, 0.85f, 0.5f, 0.35f, 0.2f);
    }
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateSignatureBass(int variation)
{
    switch (variation)
    {
        case 0: // Classic 808
            return generate808Bass(55.0f, 0.5f, 2.0f, 0.5f);
        case 1: // Reese
            return generateReeseBass(55.0f, 0.15f, 7, 0.6f, 1.0f);
        case 2: // FM Growl
            return generateFMBass(55.0f, 3.0f, 1.8f, 1.0f);
        default:
            return generate808Bass(55.0f, 0.6f, 2.5f, 0.6f);
    }
}

juce::AudioBuffer<float> ProceduralSampleSynthesizer::generateSignaturePad(int variation)
{
    switch (variation)
    {
        case 0: // Warm
            return generatePad(440.0f, 0.3f, "warm", 4.0f);
        case 1: // Bright
            return generatePad(440.0f, 0.7f, "bright", 4.0f);
        case 2: // Ethereal
            return generatePad(440.0f, 0.4f, "ethereal", 4.0f);
        default:
            return generatePad(440.0f, 0.4f, "warm", 4.0f);
    }
}

//==============================================================================
// Utilities
//==============================================================================

size_t ProceduralSampleSynthesizer::getTotalSizeBytes() const
{
    size_t total = 0;
    for (const auto& pair : sampleCache)
    {
        total += pair.second.getNumSamples() * pair.second.getNumChannels() * sizeof(float);
    }
    return total;
}

void ProceduralSampleSynthesizer::clearCache()
{
    sampleCache.clear();
}

//==============================================================================
// DSP Helpers
//==============================================================================

float ProceduralSampleSynthesizer::generateWaveform(float phase, int waveform)
{
    switch (waveform)
    {
        case 0: return sawWave(phase);
        case 1: return squareWave(phase);
        case 2: return triangleWave(phase);
        case 3: return sineWave(phase);
        default: return sineWave(phase);
    }
}

float ProceduralSampleSynthesizer::sineWave(float phase)
{
    return std::sin(phase);
}

float ProceduralSampleSynthesizer::sawWave(float phase)
{
    return 2.0f * (phase / juce::MathConstants<float>::twoPi) - 1.0f;
}

float ProceduralSampleSynthesizer::squareWave(float phase)
{
    return phase < juce::MathConstants<float>::pi ? 1.0f : -1.0f;
}

float ProceduralSampleSynthesizer::triangleWave(float phase)
{
    float saw = sawWave(phase);
    return 2.0f * std::abs(saw) - 1.0f;
}

float ProceduralSampleSynthesizer::whiteNoise()
{
    return randomDist(randomGen);
}

float ProceduralSampleSynthesizer::pinkNoise()
{
    // Paul Kellet's refined method
    float white = whiteNoise();
    pinkNoiseB0 = 0.99886f * pinkNoiseB0 + white * 0.0555179f;
    pinkNoiseB1 = 0.99332f * pinkNoiseB1 + white * 0.0750759f;
    pinkNoiseB2 = 0.96900f * pinkNoiseB2 + white * 0.1538520f;
    pinkNoiseB3 = 0.86650f * pinkNoiseB3 + white * 0.3104856f;
    pinkNoiseB4 = 0.55000f * pinkNoiseB4 + white * 0.5329522f;
    pinkNoiseB5 = -0.7616f * pinkNoiseB5 - white * 0.0168980f;
    float pink = pinkNoiseB0 + pinkNoiseB1 + pinkNoiseB2 + pinkNoiseB3 + pinkNoiseB4 + pinkNoiseB5 + pinkNoiseB6 + white * 0.5362f;
    pinkNoiseB6 = white * 0.115926f;
    return pink * 0.11f;
}

float ProceduralSampleSynthesizer::brownNoise()
{
    float white = whiteNoise();
    brownNoiseLast = (brownNoiseLast + (0.02f * white)) / 1.02f;
    return brownNoiseLast * 3.5f;
}
