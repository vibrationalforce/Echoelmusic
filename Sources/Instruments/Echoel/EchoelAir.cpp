#include "EchoelAir.h"
#include <cmath>
#include <random>
#include <algorithm>

//==============================================================================
EchoelAir::EchoelAir()
    : fft(12)  // 4096-point FFT
{
    // Initialize spectral buffers
    spectralBuffer.resize(4096, 0.0f);
    spectralPhases.resize(2048, 0.0f);

    // Initialize random number generator for generative synthesis
    static std::random_device rd;
    randomEngine.seed(rd());
}

//==============================================================================
// Atmosphere Configuration
//==============================================================================

void EchoelAir::setAtmosphere(AtmosphereType type)
{
    currentAtmosphere = type;

    // Configure spectral and generative params based on atmosphere
    switch (type)
    {
        case AtmosphereType::Clouds:
            generativeParams.density = 0.6f;
            generativeParams.movement = 0.3f;
            generativeParams.evolutionRate = 0.2f;
            spectralParams.spectralShift = 0.5f;
            spectralParams.spectralBlur = 0.5f;
            break;

        case AtmosphereType::Wind:
            generativeParams.density = 0.4f;
            generativeParams.movement = 0.8f;
            generativeParams.evolutionRate = 0.4f;
            spectralParams.spectralShift = 0.0f;
            spectralParams.spectralBlur = 0.3f;
            break;

        case AtmosphereType::Ocean:
            generativeParams.density = 0.7f;
            generativeParams.movement = 0.4f;
            generativeParams.evolutionRate = 0.15f;
            spectralParams.spectralShift = -0.5f;  // Lower frequencies
            spectralParams.spectralBlur = 0.6f;
            break;

        case AtmosphereType::Space:
            generativeParams.density = 0.3f;
            generativeParams.movement = 0.1f;
            generativeParams.evolutionRate = 0.1f;
            spectralParams.spectralShift = 0.8f;
            spectralParams.spectralBlur = 0.7f;
            break;

        case AtmosphereType::Rain:
            generativeParams.density = 0.8f;
            generativeParams.movement = 0.6f;
            generativeParams.evolutionRate = 0.5f;
            spectralParams.spectralBlur = 0.2f;
            enableRainSynthesis(true, 0.7f);
            break;

        case AtmosphereType::Forest:
            generativeParams.density = 0.5f;
            generativeParams.movement = 0.3f;
            generativeParams.evolutionRate = 0.25f;
            spectralParams.spectralBlur = 0.4f;
            break;

        case AtmosphereType::Desert:
            generativeParams.density = 0.2f;
            generativeParams.movement = 0.4f;
            generativeParams.evolutionRate = 0.2f;
            spectralParams.spectralShift = 0.3f;
            enableWindSynthesis(true, 0.4f);
            break;

        case AtmosphereType::Arctic:
            generativeParams.density = 0.3f;
            generativeParams.movement = 0.5f;
            generativeParams.evolutionRate = 0.15f;
            spectralParams.spectralShift = 0.6f;
            enableWindSynthesis(true, 0.6f);
            break;

        case AtmosphereType::Underwater:
            generativeParams.density = 0.8f;
            generativeParams.movement = 0.2f;
            generativeParams.evolutionRate = 0.1f;
            spectralParams.spectralShift = -1.0f;
            spectralParams.spectralBlur = 0.9f;
            break;

        case AtmosphereType::Cosmic:
            generativeParams.density = 0.4f;
            generativeParams.movement = 0.15f;
            generativeParams.evolutionRate = 0.08f;
            spectralParams.spectralShift = 1.2f;
            spectralParams.spectralBlur = 0.8f;
            break;
    }
}

void EchoelAir::setGenerative(const GenerativeParams& params)
{
    generativeParams = params;

    // Seed random engine with user seed for reproducibility
    randomEngine.seed(params.seed);
}

void EchoelAir::setSpectral(const SpectralParams& params)
{
    spectralParams = params;
}

//==============================================================================
// Biometric Breathing
//==============================================================================

void EchoelAir::setBreathingRate(float bpm)
{
    biometricParams.breathingRate = juce::jlimit(4.0f, 30.0f, bpm);
}

void EchoelAir::setLungCapacity(float capacity)
{
    biometricParams.lungCapacity = juce::jlimit(0.0f, 1.0f, capacity);
}

//==============================================================================
// Nature Sound Synthesis
//==============================================================================

void EchoelAir::enableRainSynthesis(bool enable, float intensity)
{
    rainParams.enabled = enable;
    rainParams.intensity = juce::jlimit(0.0f, 1.0f, intensity);
}

void EchoelAir::enableWindSynthesis(bool enable, float speed)
{
    windParams.enabled = enable;
    windParams.speed = juce::jlimit(0.0f, 1.0f, speed);
}

void EchoelAir::enableOceanSynthesis(bool enable, float waveSize)
{
    oceanParams.enabled = enable;
    oceanParams.waveSize = juce::jlimit(0.0f, 1.0f, waveSize);
}

//==============================================================================
// Audio Processing
//==============================================================================

void EchoelAir::prepare(double sampleRate, int samplesPerBlock)
{
    this->sampleRate = sampleRate;
    this->samplesPerBlock = samplesPerBlock;

    // Initialize granular synthesis grains
    grains.resize(64);  // 64 simultaneous grains
    for (auto& grain : grains)
    {
        grain.active = false;
        grain.phase = 0.0f;
        grain.amplitude = 0.0f;
        grain.frequency = 440.0f;
    }

    // Initialize additive synthesis partials
    partials.resize(128);
    for (int i = 0; i < 128; ++i)
    {
        partials[i].frequency = 55.0f * (i + 1);  // Harmonic series from A1
        partials[i].amplitude = 1.0f / (i + 1);   // 1/f amplitude falloff
        partials[i].phase = 0.0f;
    }
}

void EchoelAir::processBlock(juce::AudioBuffer<float>& buffer)
{
    buffer.clear();

    const int numSamples = buffer.getNumSamples();

    if (generativeParams.enableGenerative)
    {
        // ML Generative synthesis
        mlModel.generateNextFrame(buffer);
    }
    else
    {
        // Manual synthesis modes
        synthesizeAtmosphere(buffer);
    }

    // Add nature sounds if enabled
    if (rainParams.enabled)
        synthesizeRain(buffer);

    if (windParams.enabled)
        synthesizeWind(buffer);

    if (oceanParams.enabled)
        synthesizeOcean(buffer);

    // Apply biometric breathing modulation
    if (biometricParams.breathingRate > 0.0f)
        applyBreathingModulation(buffer);

    // Apply spectral processing
    if (spectralParams.spectralShift != 0.0f || spectralParams.spectralBlur > 0.0f)
        applySpectralProcessing(buffer);
}

//==============================================================================
// Atmosphere Synthesis
//==============================================================================

void EchoelAir::synthesizeAtmosphere(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();

    // Combine granular + additive synthesis
    for (int sample = 0; sample < numSamples; ++sample)
    {
        float output = 0.0f;

        // Granular synthesis component
        output += synthesizeGranularFrame();

        // Additive synthesis component
        output += synthesizeAdditiveFrame();

        // Mix to all channels
        for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
        {
            buffer.addSample(channel, sample, output * 0.3f);
        }
    }

    // Trigger new grains probabilistically
    triggerGrains();

    // Evolve partials over time
    evolvePartials();
}

float EchoelAir::synthesizeGranularFrame()
{
    float output = 0.0f;

    for (auto& grain : grains)
    {
        if (grain.active)
        {
            // Gaussian envelope for grain
            float envPos = grain.phase / grain.duration;
            float envelope = std::exp(-12.0f * std::pow(envPos - 0.5f, 2.0f));

            // Sine oscillator
            float sample = std::sin(juce::MathConstants<float>::twoPi * grain.phase * grain.frequency / static_cast<float>(sampleRate));

            output += sample * envelope * grain.amplitude * generativeParams.density;

            // Advance grain
            grain.phase += 1.0f;

            // Deactivate if finished
            if (grain.phase >= grain.duration)
            {
                grain.active = false;
            }
        }
    }

    return output;
}

float EchoelAir::synthesizeAdditiveFrame()
{
    float output = 0.0f;

    // Sum partials
    for (auto& partial : partials)
    {
        if (partial.amplitude > 0.001f)  // Only active partials
        {
            float sample = std::sin(juce::MathConstants<float>::twoPi * partial.phase);
            output += sample * partial.amplitude;

            // Advance phase
            partial.phase += partial.frequency / static_cast<float>(sampleRate);
            if (partial.phase >= 1.0f)
                partial.phase -= 1.0f;
        }
    }

    return output * 0.1f;  // Scale down additive component
}

void EchoelAir::triggerGrains()
{
    // Probabilistic grain triggering based on density
    std::uniform_real_distribution<float> probDist(0.0f, 1.0f);
    float triggerProb = generativeParams.density * 0.1f;  // ~10% per block at max density

    if (probDist(randomEngine) < triggerProb)
    {
        // Find inactive grain
        for (auto& grain : grains)
        {
            if (!grain.active)
            {
                grain.active = true;
                grain.phase = 0.0f;

                // Random grain parameters
                std::uniform_real_distribution<float> freqDist(100.0f, 2000.0f);
                std::uniform_real_distribution<float> durDist(0.05f, 0.5f);
                std::uniform_real_distribution<float> ampDist(0.1f, 0.5f);

                grain.frequency = freqDist(randomEngine);
                grain.duration = durDist(randomEngine) * static_cast<float>(sampleRate);
                grain.amplitude = ampDist(randomEngine);

                break;
            }
        }
    }
}

void EchoelAir::evolvePartials()
{
    // Slowly evolve partial amplitudes based on evolution rate
    static float evolutionPhase = 0.0f;

    evolutionPhase += generativeParams.evolutionRate * 0.001f;
    if (evolutionPhase >= juce::MathConstants<float>::twoPi)
        evolutionPhase -= juce::MathConstants<float>::twoPi;

    for (size_t i = 0; i < partials.size(); ++i)
    {
        // Use LFO to modulate amplitude
        float lfoPhase = evolutionPhase + (i * 0.1f);
        float lfo = (std::sin(lfoPhase) + 1.0f) * 0.5f;  // 0-1

        partials[i].amplitude = (1.0f / (i + 1)) * lfo * generativeParams.density;
    }
}

//==============================================================================
// Nature Sound Synthesis
//==============================================================================

void EchoelAir::synthesizeRain(juce::AudioBuffer<float>& buffer)
{
    static std::uniform_real_distribution<float> noiseDist(-1.0f, 1.0f);

    const int numSamples = buffer.getNumSamples();

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Rain: Filtered noise with random impulses (drops)
        float noise = noiseDist(randomEngine);

        // Random raindrop impacts
        std::uniform_real_distribution<float> dropProb(0.0f, 1.0f);
        if (dropProb(randomEngine) < rainParams.intensity * 0.01f)
        {
            noise += dropProb(randomEngine) * 2.0f;  // Louder impact
        }

        // Simple low-pass filter
        static float rainState = 0.0f;
        rainState = rainState * 0.95f + noise * 0.05f;

        for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
        {
            buffer.addSample(channel, sample, rainState * rainParams.intensity * 0.2f);
        }
    }
}

void EchoelAir::synthesizeWind(juce::AudioBuffer<float>& buffer)
{
    static std::uniform_real_distribution<float> noiseDist(-1.0f, 1.0f);
    static float windLFOPhase = 0.0f;

    const int numSamples = buffer.getNumSamples();
    float windLFOFreq = 0.2f + (windParams.speed * 0.3f);  // 0.2-0.5 Hz

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Wind: Modulated filtered noise
        float noise = noiseDist(randomEngine);

        // Wind speed LFO (slow modulation)
        windLFOPhase += windLFOFreq / static_cast<float>(sampleRate);
        if (windLFOPhase >= 1.0f)
            windLFOPhase -= 1.0f;

        float windMod = (std::sin(juce::MathConstants<float>::twoPi * windLFOPhase) + 1.0f) * 0.5f;

        // Band-pass filtered noise
        static float windStateLow = 0.0f;
        static float windStateHigh = 0.0f;

        windStateLow = windStateLow * 0.98f + noise * 0.02f;
        windStateHigh = noise - windStateLow;

        float windSample = windStateHigh * windMod * windParams.speed;

        for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
        {
            buffer.addSample(channel, sample, windSample * 0.3f);
        }
    }
}

void EchoelAir::synthesizeOcean(juce::AudioBuffer<float>& buffer)
{
    static float wavePhase = 0.0f;
    static std::uniform_real_distribution<float> noiseDist(-1.0f, 1.0f);

    const int numSamples = buffer.getNumSamples();
    float waveFreq = 0.1f + (oceanParams.waveSize * 0.2f);  // 0.1-0.3 Hz

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Ocean: Low-frequency wave + noise
        wavePhase += waveFreq / static_cast<float>(sampleRate);
        if (wavePhase >= 1.0f)
            wavePhase -= 1.0f;

        // Wave motion (sine)
        float wave = std::sin(juce::MathConstants<float>::twoPi * wavePhase);

        // Add multiple harmonics for richer wave
        wave += std::sin(juce::MathConstants<float>::twoPi * wavePhase * 2.0f) * 0.5f;
        wave += std::sin(juce::MathConstants<float>::twoPi * wavePhase * 3.0f) * 0.3f;

        // Noise component (foam)
        float noise = noiseDist(randomEngine);

        // Mix wave + noise
        float oceanSample = (wave * 0.7f + noise * 0.3f) * oceanParams.waveSize;

        for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
        {
            buffer.addSample(channel, sample, oceanSample * 0.25f);
        }
    }
}

//==============================================================================
// Biometric Breathing Modulation
//==============================================================================

void EchoelAir::applyBreathingModulation(juce::AudioBuffer<float>& buffer)
{
    static float breathPhase = 0.0f;

    const int numSamples = buffer.getNumSamples();
    float breathFreq = biometricParams.breathingRate / 60.0f;  // Convert BPM to Hz

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Breathing envelope (sine wave)
        breathPhase += breathFreq / static_cast<float>(sampleRate);
        if (breathPhase >= 1.0f)
            breathPhase -= 1.0f;

        float breathEnv = (std::sin(juce::MathConstants<float>::twoPi * breathPhase) + 1.0f) * 0.5f;  // 0-1

        // Modulate based on lung capacity
        breathEnv = 0.5f + (breathEnv * biometricParams.lungCapacity * 0.5f);

        for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
        {
            buffer.getWritePointer(channel)[sample] *= breathEnv;
        }
    }
}

//==============================================================================
// Spectral Processing
//==============================================================================

void EchoelAir::applySpectralProcessing(juce::AudioBuffer<float>& buffer)
{
    // Simplified spectral processing
    // Real implementation would use proper FFT-based processing

    if (spectralParams.spectralShift != 0.0f)
    {
        // Frequency shifting (simplified)
        float shiftFactor = std::pow(2.0f, spectralParams.spectralShift / 12.0f);

        // This is a placeholder - real implementation would use phase vocoder
        // For now, just apply a simple pitch-shift-like effect via sample rate manipulation
    }

    if (spectralParams.spectralBlur > 0.0f)
    {
        // Spectral blur: smear frequencies together
        // Simplified as a multi-stage all-pass filter

        static std::vector<float> blurStates(8, 0.0f);

        for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
        {
            auto* channelData = buffer.getWritePointer(channel);

            for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
            {
                float input = channelData[sample];

                // Multi-stage all-pass (creates blur)
                for (size_t stage = 0; stage < blurStates.size(); ++stage)
                {
                    float blurAmount = spectralParams.spectralBlur * 0.1f;
                    blurStates[stage] = blurStates[stage] * (0.9f + blurAmount * 0.09f) + input * 0.1f;
                    input = blurStates[stage];
                }

                channelData[sample] = input;
            }
        }
    }
}

//==============================================================================
// ML Generative Model
//==============================================================================

void EchoelAir::MLGenerativeModel::generateNextFrame(juce::AudioBuffer<float>& output)
{
    // Placeholder for actual ML model inference
    // Real implementation would use trained neural network for ambient generation
    // Trained on Brian Eno, Stars of the Lid, etc.

    // For now, this would fall back to manual synthesis methods
    // The model would generate spectral envelopes that evolve over time
}
