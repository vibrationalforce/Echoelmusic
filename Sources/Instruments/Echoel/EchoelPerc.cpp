#include "EchoelPerc.h"
#include <cmath>
#include <random>
#include <algorithm>

//==============================================================================
EchoelPerc::EchoelPerc()
{
    // Initialize 16 pads with default settings
    for (int i = 0; i < 16; ++i)
    {
        pads[i].padNumber = i + 1;
        pads[i].drumType = DrumType::AcousticKick;
        pads[i].pitch = 0.0f;
        pads[i].decay = 0.5f;
        pads[i].tone = 0.5f;
        pads[i].reverb = 0.0f;
        pads[i].compression = 0.5f;
        pads[i].eq = 0.0f;
    }

    // Load default drum kit
    loadDefaultKit();
}

void EchoelPerc::loadDefaultKit()
{
    // Pad 1: Kick
    pads[0].drumType = DrumType::AcousticKick;
    pads[0].decay = 0.6f;
    pads[0].tone = 0.4f;

    // Pad 2: Snare
    pads[1].drumType = DrumType::AcousticSnare;
    pads[1].decay = 0.4f;
    pads[1].tone = 0.6f;

    // Pad 3-5: Toms
    pads[2].drumType = DrumType::Toms;
    pads[2].pitch = 5.0f;  // High tom
    pads[3].drumType = DrumType::Toms;
    pads[3].pitch = 0.0f;  // Mid tom
    pads[4].drumType = DrumType::Toms;
    pads[4].pitch = -5.0f;  // Floor tom

    // Pad 6-7: Hi-hats
    pads[5].drumType = DrumType::HiHats;
    pads[5].decay = 0.1f;  // Closed
    pads[6].drumType = DrumType::HiHats;
    pads[6].decay = 0.5f;  // Open

    // Pad 8-9: Cymbals
    pads[7].drumType = DrumType::Cymbals;
    pads[7].pitch = 2.0f;  // Crash
    pads[8].drumType = DrumType::Cymbals;
    pads[8].pitch = 0.0f;  // Ride

    // Pad 10: Clap
    pads[9].drumType = DrumType::Clap;

    // Pad 11-12: 808/909
    pads[10].drumType = DrumType::TR808;
    pads[11].drumType = DrumType::TR909;

    // Pad 13-16: World percussion
    pads[12].drumType = DrumType::Congas;
    pads[13].drumType = DrumType::Bongos;
    pads[14].drumType = DrumType::Djembe;
    pads[15].drumType = DrumType::Tabla;
}

//==============================================================================
// Pad Management
//==============================================================================

void EchoelPerc::setPad(int padNumber, const Pad& pad)
{
    if (padNumber >= 1 && padNumber <= 16)
    {
        pads[padNumber - 1] = pad;
        pads[padNumber - 1].padNumber = padNumber;
    }
}

EchoelPerc::Pad EchoelPerc::getPad(int padNumber) const
{
    if (padNumber >= 1 && padNumber <= 16)
        return pads[padNumber - 1];

    return Pad{};
}

//==============================================================================
// ML Pattern Generation
//==============================================================================

void EchoelPerc::generatePattern(MusicGenre genre, int bars)
{
    // ML-powered drum pattern generation based on genre
    // This simplified version creates characteristic patterns for each genre

    std::vector<MidiEvent> pattern;
    int stepsPerBar = 16;  // 16th notes
    int totalSteps = bars * stepsPerBar;

    switch (genre)
    {
        case MusicGenre::HipHop:
            generateHipHopPattern(pattern, totalSteps);
            break;
        case MusicGenre::House:
            generateHousePattern(pattern, totalSteps);
            break;
        case MusicGenre::Techno:
            generateTechnoPattern(pattern, totalSteps);
            break;
        case MusicGenre::DnB:
            generateDnBPattern(pattern, totalSteps);
            break;
        case MusicGenre::Trap:
            generateTrapPattern(pattern, totalSteps);
            break;
        case MusicGenre::Rock:
            generateRockPattern(pattern, totalSteps);
            break;
        case MusicGenre::Jazz:
            generateJazzPattern(pattern, totalSteps);
            break;
        case MusicGenre::Latin:
            generateLatinPattern(pattern, totalSteps);
            break;
        case MusicGenre::Afrobeat:
            generateAfrobeatPattern(pattern, totalSteps);
            break;
        case MusicGenre::Experimental:
            generateExperimentalPattern(pattern, totalSteps);
            break;
    }
}

void EchoelPerc::generateHipHopPattern(std::vector<MidiEvent>& pattern, int steps)
{
    // Classic hip-hop: Kick on 1 & 3, snare on 2 & 4, hi-hats on 16ths
    for (int step = 0; step < steps; ++step)
    {
        int beat = step % 16;

        // Kick on beats 0, 8 (1 & 3)
        if (beat == 0 || beat == 8)
            pattern.push_back({step, 0, 100});  // Pad 1: Kick

        // Snare on beats 4, 12 (2 & 4)
        if (beat == 4 || beat == 12)
            pattern.push_back({step, 1, 110});  // Pad 2: Snare

        // Hi-hats on all 16ths with velocity variation
        int velocity = (beat % 4 == 0) ? 90 : 60;  // Accent on quarter notes
        pattern.push_back({step, 5, velocity});  // Pad 6: Closed hi-hat
    }
}

void EchoelPerc::generateHousePattern(std::vector<MidiEvent>& pattern, int steps)
{
    // Four-on-the-floor kick, open hi-hat on offbeats
    for (int step = 0; step < steps; ++step)
    {
        int beat = step % 16;

        // Kick on every quarter note (4/4)
        if (beat % 4 == 0)
            pattern.push_back({step, 0, 110});  // Pad 1: Kick

        // Clap/snare on 2 & 4
        if (beat == 4 || beat == 12)
            pattern.push_back({step, 1, 95});  // Pad 2: Snare

        // Closed hi-hat on 8th notes
        if (beat % 2 == 0)
            pattern.push_back({step, 5, 70});  // Pad 6: Closed hi-hat

        // Open hi-hat on offbeats
        if (beat % 4 == 2)
            pattern.push_back({step, 6, 85});  // Pad 7: Open hi-hat
    }
}

void EchoelPerc::generateTechnoPattern(std::vector<MidiEvent>& pattern, int steps)
{
    // Relentless four-on-the-floor with minimal variation
    for (int step = 0; step < steps; ++step)
    {
        int beat = step % 16;

        // Kick on every quarter note
        if (beat % 4 == 0)
            pattern.push_back({step, 10, 120});  // Pad 11: TR-909 kick

        // Closed hi-hat on 16ths
        pattern.push_back({step, 5, (beat % 2 == 0) ? 80 : 60});

        // Occasional clap
        if (beat == 4 || beat == 12)
            pattern.push_back({step, 9, 90});  // Pad 10: Clap
    }
}

void EchoelPerc::generateDnBPattern(std::vector<MidiEvent>& pattern, int steps)
{
    // Fast breakbeat pattern (160-180 BPM feel)
    for (int step = 0; step < steps; ++step)
    {
        int beat = step % 16;

        // Complex kick pattern
        if (beat == 0 || beat == 6 || beat == 10 || beat == 14)
            pattern.push_back({step, 0, 115});

        // Syncopated snare
        if (beat == 4 || beat == 12)
            pattern.push_back({step, 1, 120});
        else if (beat == 7 || beat == 15)
            pattern.push_back({step, 1, 90});

        // Fast hi-hats
        if (beat % 2 == 0)
            pattern.push_back({step, 5, 75});
    }
}

void EchoelPerc::generateTrapPattern(std::vector<MidiEvent>& pattern, int steps)
{
    // Trap: 808 kicks, snappy snares, rolling hi-hats
    static std::random_device rd;
    static std::mt19937 gen(rd());
    std::uniform_int_distribution<> rollDist(0, 100);

    for (int step = 0; step < steps; ++step)
    {
        int beat = step % 16;

        // 808 kick pattern
        if (beat == 0 || beat == 6 || beat == 10)
            pattern.push_back({step, 10, 110});  // Pad 11: TR-808

        // Snare on 2 & 4
        if (beat == 4 || beat == 12)
            pattern.push_back({step, 1, 105});

        // Hi-hat rolls (probabilistic)
        if (rollDist(gen) > 70)  // 30% chance of roll
            pattern.push_back({step, 5, 60 + (beat % 3) * 10});
    }
}

void EchoelPerc::generateRockPattern(std::vector<MidiEvent>& pattern, int steps)
{
    // Basic rock beat
    for (int step = 0; step < steps; ++step)
    {
        int beat = step % 16;

        // Kick on 1 & 3, plus occasional 16ths
        if (beat == 0 || beat == 8)
            pattern.push_back({step, 0, 110});

        // Snare on 2 & 4
        if (beat == 4 || beat == 12)
            pattern.push_back({step, 1, 115});

        // Ride cymbal on 8th notes
        if (beat % 2 == 0)
            pattern.push_back({step, 8, 70});  // Pad 9: Ride
    }
}

void EchoelPerc::generateJazzPattern(std::vector<MidiEvent>& pattern, int steps)
{
    // Swing feel (approximate with 16th grid)
    for (int step = 0; step < steps; ++step)
    {
        int beat = step % 16;

        // Ride pattern (swing)
        if (beat % 3 == 0)  // Approximate swing
            pattern.push_back({step, 8, 65});

        // Hi-hat on 2 & 4
        if (beat == 4 || beat == 12)
            pattern.push_back({step, 5, 50});

        // Kick (sparse)
        if (beat == 0 || beat == 10)
            pattern.push_back({step, 0, 85});
    }
}

void EchoelPerc::generateLatinPattern(std::vector<MidiEvent>& pattern, int steps)
{
    // Clave-based Latin pattern
    for (int step = 0; step < steps; ++step)
    {
        int beat = step % 16;

        // 3-2 Son clave
        if (beat == 0 || beat == 6 || beat == 10)
            pattern.push_back({step, 12, 90});  // Pad 13: Congas

        // Tumbao on congas
        if (beat % 4 == 0)
            pattern.push_back({step, 12, 100});

        // Bongos
        if (beat == 2 || beat == 7 || beat == 14)
            pattern.push_back({step, 13, 85});  // Pad 14: Bongos
    }
}

void EchoelPerc::generateAfrobeatPattern(std::vector<MidiEvent>& pattern, int steps)
{
    // Complex polyrhythmic Afrobeat
    for (int step = 0; step < steps; ++step)
    {
        int beat = step % 16;

        // Djembe pattern
        if (beat == 0 || beat == 3 || beat == 7 || beat == 10 || beat == 14)
            pattern.push_back({step, 14, 95});  // Pad 15: Djembe

        // Congas
        if (beat % 4 == 1)
            pattern.push_back({step, 12, 85});

        // Shaker (using hi-hat)
        if (beat % 2 == 0)
            pattern.push_back({step, 5, 60});
    }
}

void EchoelPerc::generateExperimentalPattern(std::vector<MidiEvent>& pattern, int steps)
{
    // Randomized experimental pattern
    static std::random_device rd;
    static std::mt19937 gen(rd());
    std::uniform_int_distribution<> padDist(0, 15);
    std::uniform_int_distribution<> velDist(40, 120);
    std::uniform_int_distribution<> probDist(0, 100);

    for (int step = 0; step < steps; ++step)
    {
        // 40% probability of hit on each step
        if (probDist(gen) < 40)
        {
            int pad = padDist(gen);
            int velocity = velDist(gen);
            pattern.push_back({step, pad, velocity});
        }
    }
}

//==============================================================================
// Biometric Groove
//==============================================================================

void EchoelPerc::setHeartRate(float bpm)
{
    biometricParams.heartRate = juce::jlimit(40.0f, 200.0f, bpm);
}

void EchoelPerc::setHeartRateVariability(float hrv)
{
    biometricParams.heartRateVariability = juce::jlimit(0.0f, 1.0f, hrv);
}

void EchoelPerc::enableBiometricGroove(bool enable)
{
    biometricParams.enabled = enable;
}

//==============================================================================
// Drum Replacement
//==============================================================================

void EchoelPerc::enableDrumReplacement(bool enable)
{
    drumReplacementEnabled = enable;
}

void EchoelPerc::trainReplacementModel(const juce::AudioBuffer<float>& originalDrums)
{
    // Simplified ML training for drum replacement
    // Real implementation would analyze transients and spectral content
    mlModel.replacementModelTrained = true;
}

//==============================================================================
// Audio Processing
//==============================================================================

void EchoelPerc::prepare(double sampleRate, int samplesPerBlock)
{
    this->sampleRate = sampleRate;
    this->samplesPerBlock = samplesPerBlock;

    // Initialize sample players for each pad
    for (auto& pad : pads)
    {
        // Load samples for velocity layers (simplified)
        // Real implementation would load actual sample files
    }
}

void EchoelPerc::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
{
    buffer.clear();

    // Process MIDI events
    for (const auto metadata : midi)
    {
        auto message = metadata.getMessage();
        int samplePosition = metadata.samplePosition;

        if (message.isNoteOn())
        {
            int note = message.getNoteNumber();
            int velocity = message.getVelocity();

            // Map MIDI note to pad (36-51 = pads 1-16)
            int padIndex = note - 36;
            if (padIndex >= 0 && padIndex < 16)
            {
                triggerPad(padIndex, velocity, samplePosition, buffer);
            }
        }
    }

    // Apply biometric groove modulation
    if (biometricParams.enabled)
    {
        applyBiometricGroove(buffer);
    }
}

void EchoelPerc::triggerPad(int padIndex, int velocity, int samplePosition, juce::AudioBuffer<float>& buffer)
{
    const auto& pad = pads[padIndex];
    float normalizedVelocity = velocity / 127.0f;

    // Synthesize drum sound based on type
    juce::AudioBuffer<float> drumBuffer(buffer.getNumChannels(), buffer.getNumSamples() - samplePosition);
    drumBuffer.clear();

    synthesizeDrum(pad.drumType, normalizedVelocity, pad, drumBuffer);

    // Apply per-pad effects
    applyPadEffects(pad, drumBuffer);

    // Mix into main buffer at sample position
    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        buffer.addFrom(channel, samplePosition, drumBuffer, channel, 0, drumBuffer.getNumSamples());
    }
}

void EchoelPerc::synthesizeDrum(DrumType type, float velocity, const Pad& pad, juce::AudioBuffer<float>& output)
{
    // Use ML model if available, otherwise use physical modeling
    if (mlModel.loaded)
    {
        mlModel.synthesizeDrum(type, velocity, output);
        return;
    }

    // Fallback: Physical modeling / synthesis
    const int numSamples = output.getNumSamples();
    auto* leftChannel = output.getWritePointer(0);
    auto* rightChannel = output.getNumChannels() > 1 ? output.getWritePointer(1) : nullptr;

    switch (type)
    {
        case DrumType::AcousticKick:
            synthesizeKick(leftChannel, numSamples, velocity, pad);
            break;

        case DrumType::AcousticSnare:
            synthesizeSnare(leftChannel, numSamples, velocity, pad);
            break;

        case DrumType::Toms:
            synthesizeTom(leftChannel, numSamples, velocity, pad);
            break;

        case DrumType::HiHats:
            synthesizeHiHat(leftChannel, numSamples, velocity, pad);
            break;

        case DrumType::Cymbals:
            synthesizeCymbal(leftChannel, numSamples, velocity, pad);
            break;

        case DrumType::TR808:
            synthesize808Kick(leftChannel, numSamples, velocity, pad);
            break;

        case DrumType::TR909:
            synthesize909Kick(leftChannel, numSamples, velocity, pad);
            break;

        case DrumType::Clap:
            synthesizeClap(leftChannel, numSamples, velocity, pad);
            break;

        default:
            synthesizeGeneric(leftChannel, numSamples, velocity, pad);
            break;
    }

    // Copy to right channel if stereo
    if (rightChannel)
    {
        for (int i = 0; i < numSamples; ++i)
            rightChannel[i] = leftChannel[i];
    }
}

void EchoelPerc::synthesizeKick(float* buffer, int numSamples, float velocity, const Pad& pad)
{
    // Acoustic kick: Sine sweep + noise click
    float frequency = 60.0f * std::pow(2.0f, pad.pitch / 12.0f);
    float phase = 0.0f;

    for (int i = 0; i < numSamples; ++i)
    {
        float t = i / sampleRate;
        float env = std::exp(-t / (pad.decay * 0.5f + 0.1f));  // Fast decay

        // Pitch envelope (sweep down)
        float pitchEnv = std::exp(-t / 0.05f);
        float currentFreq = frequency * (1.0f + pitchEnv * 3.0f);

        // Sine tone
        phase += currentFreq / sampleRate;
        float sample = std::sin(juce::MathConstants<float>::twoPi * phase) * env;

        // Add click
        if (i < 100)
            sample += (1.0f - i / 100.0f) * 0.3f;

        buffer[i] = sample * velocity * 0.8f;
    }
}

void EchoelPerc::synthesizeSnare(float* buffer, int numSamples, float velocity, const Pad& pad)
{
    // Snare: Tone + noise
    static std::random_device rd;
    static std::mt19937 gen(rd());
    std::uniform_real_distribution<float> noiseDist(-1.0f, 1.0f);

    float frequency = 200.0f * std::pow(2.0f, pad.pitch / 12.0f);
    float phase = 0.0f;

    for (int i = 0; i < numSamples; ++i)
    {
        float t = i / sampleRate;
        float env = std::exp(-t / (pad.decay * 0.3f + 0.05f));

        // Tone (body)
        phase += frequency / sampleRate;
        float tone = std::sin(juce::MathConstants<float>::twoPi * phase);

        // Noise (snares)
        float noise = noiseDist(gen);

        // Mix based on tone parameter
        float sample = (tone * (1.0f - pad.tone) + noise * pad.tone) * env;
        buffer[i] = sample * velocity * 0.6f;
    }
}

void EchoelPerc::synthesizeTom(float* buffer, int numSamples, float velocity, const Pad& pad)
{
    // Tom: Dual-oscillator with pitch sweep
    float frequency = 120.0f * std::pow(2.0f, pad.pitch / 12.0f);
    float phase1 = 0.0f, phase2 = 0.0f;

    for (int i = 0; i < numSamples; ++i)
    {
        float t = i / sampleRate;
        float env = std::exp(-t / (pad.decay * 0.4f + 0.1f));
        float pitchEnv = std::exp(-t / 0.08f);

        float freq1 = frequency * (1.0f + pitchEnv * 2.0f);
        float freq2 = frequency * 1.5f * (1.0f + pitchEnv * 1.5f);

        phase1 += freq1 / sampleRate;
        phase2 += freq2 / sampleRate;

        float sample = (std::sin(juce::MathConstants<float>::twoPi * phase1) * 0.7f +
                       std::sin(juce::MathConstants<float>::twoPi * phase2) * 0.3f) * env;

        buffer[i] = sample * velocity * 0.7f;
    }
}

void EchoelPerc::synthesizeHiHat(float* buffer, int numSamples, float velocity, const Pad& pad)
{
    // Hi-hat: Filtered noise
    static std::random_device rd;
    static std::mt19937 gen(rd());
    std::uniform_real_distribution<float> noiseDist(-1.0f, 1.0f);

    for (int i = 0; i < numSamples; ++i)
    {
        float t = i / sampleRate;
        float env = std::exp(-t / (pad.decay * 0.2f + 0.01f));

        float noise = noiseDist(gen);
        // Simple high-pass (metallic sound)
        buffer[i] = noise * env * velocity * 0.4f;
    }
}

void EchoelPerc::synthesizeCymbal(float* buffer, int numSamples, float velocity, const Pad& pad)
{
    // Cymbal: Complex filtered noise with multiple bands
    static std::random_device rd;
    static std::mt19937 gen(rd());
    std::uniform_real_distribution<float> noiseDist(-1.0f, 1.0f);

    for (int i = 0; i < numSamples; ++i)
    {
        float t = i / sampleRate;
        float env = std::exp(-t / (pad.decay * 2.0f + 0.5f));  // Long decay

        float noise = noiseDist(gen);
        buffer[i] = noise * env * velocity * 0.5f;
    }
}

void EchoelPerc::synthesize808Kick(float* buffer, int numSamples, float velocity, const Pad& pad)
{
    // TR-808 kick: Sine with extreme pitch envelope
    float phase = 0.0f;

    for (int i = 0; i < numSamples; ++i)
    {
        float t = i / sampleRate;
        float env = std::exp(-t / 0.5f);
        float pitchEnv = std::exp(-t / 0.01f);

        float frequency = 50.0f * (1.0f + pitchEnv * 10.0f);  // Extreme sweep
        phase += frequency / sampleRate;

        buffer[i] = std::sin(juce::MathConstants<float>::twoPi * phase) * env * velocity * 0.9f;
    }
}

void EchoelPerc::synthesize909Kick(float* buffer, int numSamples, float velocity, const Pad& pad)
{
    // TR-909 kick: Punchier, shorter decay
    float phase = 0.0f;

    for (int i = 0; i < numSamples; ++i)
    {
        float t = i / sampleRate;
        float env = std::exp(-t / 0.3f);
        float pitchEnv = std::exp(-t / 0.015f);

        float frequency = 65.0f * (1.0f + pitchEnv * 5.0f);
        phase += frequency / sampleRate;

        buffer[i] = std::sin(juce::MathConstants<float>::twoPi * phase) * env * velocity * 0.85f;
    }
}

void EchoelPerc::synthesizeClap(float* buffer, int numSamples, float velocity, const Pad& pad)
{
    // Clap: Multiple noise bursts
    static std::random_device rd;
    static std::mt19937 gen(rd());
    std::uniform_real_distribution<float> noiseDist(-1.0f, 1.0f);

    for (int i = 0; i < numSamples; ++i)
    {
        float t = i / sampleRate;
        float sample = 0.0f;

        // Multiple clap attacks
        for (int clap = 0; clap < 3; ++clap)
        {
            float clapTime = clap * 0.01f;  // Stagger by 10ms
            if (t >= clapTime)
            {
                float clapEnv = std::exp(-(t - clapTime) / 0.05f);
                sample += noiseDist(gen) * clapEnv;
            }
        }

        buffer[i] = sample * velocity * 0.3f;
    }
}

void EchoelPerc::synthesizeGeneric(float* buffer, int numSamples, float velocity, const Pad& pad)
{
    // Generic percussive sound
    static std::random_device rd;
    static std::mt19937 gen(rd());
    std::uniform_real_distribution<float> noiseDist(-1.0f, 1.0f);

    for (int i = 0; i < numSamples; ++i)
    {
        float t = i / sampleRate;
        float env = std::exp(-t / (pad.decay * 0.5f + 0.1f));

        buffer[i] = noiseDist(gen) * env * velocity * 0.5f;
    }
}

void EchoelPerc::applyPadEffects(const Pad& pad, juce::AudioBuffer<float>& buffer)
{
    // Simplified per-pad effects
    // Real implementation would use proper DSP effects

    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);

        for (int i = 0; i < buffer.getNumSamples(); ++i)
        {
            // Simple compression (gain reduction)
            float sample = channelData[i];
            if (pad.compression > 0.5f)
            {
                sample = std::tanh(sample * (1.0f + pad.compression));
            }

            // Simple EQ (tone control)
            // Positive = boost highs, negative = boost lows
            // This is a placeholder for proper EQ

            channelData[i] = sample;
        }
    }
}

void EchoelPerc::applyBiometricGroove(juce::AudioBuffer<float>& buffer)
{
    // Apply subtle timing and dynamics variations based on heart rate variability
    // This creates a more "human" feel to the groove

    if (biometricParams.heartRateVariability > 0.0f)
    {
        // Add subtle randomization to dynamics based on HRV
        static std::random_device rd;
        static std::mt19937 gen(rd());
        std::normal_distribution<float> dynamicsDist(1.0f, biometricParams.heartRateVariability * 0.1f);

        float dynamicsMod = juce::jlimit(0.8f, 1.2f, dynamicsDist(gen));

        buffer.applyGain(dynamicsMod);
    }
}

//==============================================================================
// ML Drum Model
//==============================================================================

void EchoelPerc::MLDrumModel::synthesizeDrum(DrumType type, float velocity, juce::AudioBuffer<float>& output)
{
    // Placeholder for actual ML model inference
    // Real implementation would use trained neural network to generate drum samples
    // based on the drum type and velocity

    // For now, this would fall back to physical modeling
}
