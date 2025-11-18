#include "EchoelStab.h"
#include <cmath>
#include <algorithm>
#include <random>

//==============================================================================
EchoelStab::EchoelStab()
{
    // Initialize voice pool
    voices.resize(MAX_VOICES);
    for (auto& voice : voices)
    {
        voice.active = false;
        voice.formantFreqs = {600.0f, 1040.0f, 2250.0f, 2450.0f, 2750.0f};  // Default brass formants
        voice.formantGains = {1.0f, 0.7f, 0.5f, 0.3f, 0.2f};
        voice.formantBandwidths = {60.0f, 70.0f, 110.0f, 120.0f, 130.0f};
    }
}

//==============================================================================
// Instrument Configuration
//==============================================================================

void EchoelStab::setBrassType(BrassType type)
{
    currentBrassType = type;

    // Update default formants based on instrument
    std::array<float, 5> defaultFormants;

    switch (type)
    {
        case BrassType::Trumpet:
            defaultFormants = {600.0f, 1040.0f, 2250.0f, 2450.0f, 2750.0f};
            break;
        case BrassType::Flugelhorn:
            defaultFormants = {550.0f, 920.0f, 2100.0f, 2300.0f, 2600.0f};
            break;
        case BrassType::Trombone:
            defaultFormants = {400.0f, 800.0f, 1800.0f, 2200.0f, 2600.0f};
            break;
        case BrassType::FrenchHorn:
            defaultFormants = {350.0f, 750.0f, 1650.0f, 2100.0f, 2550.0f};
            break;
        case BrassType::Tuba:
            defaultFormants = {300.0f, 650.0f, 1500.0f, 2000.0f, 2500.0f};
            break;
        case BrassType::Saxophone:
            defaultFormants = {650.0f, 1100.0f, 2400.0f, 2700.0f, 3000.0f};
            break;
        default:
            defaultFormants = {600.0f, 1040.0f, 2250.0f, 2450.0f, 2750.0f};
            break;
    }

    // Update all voices with new formants
    for (auto& voice : voices)
    {
        voice.formantFreqs = defaultFormants;
    }
}

void EchoelStab::setNeuralBrassParams(const NeuralBrassParams& params)
{
    neuralParams = params;
}

void EchoelStab::setArticulation(ArticulationType type)
{
    currentArticulation = type;
}

void EchoelStab::enableAutoArticulation(bool enable)
{
    if (enable)
        currentArticulation = ArticulationType::Auto;
}

void EchoelStab::setVibratoParams(const VibratoParams& params)
{
    vibratoParams = params;
}

void EchoelStab::setEnsembleParams(const EnsembleParams& params)
{
    ensembleParams = params;

    // Adjust voice count if needed
    if (ensembleParams.voiceCount > MAX_VOICES)
        ensembleParams.voiceCount = MAX_VOICES;
}

void EchoelStab::setMuteType(MuteType type)
{
    currentMute = type;
}

void EchoelStab::setMuteAmount(float amount)
{
    // Store mute amount in neural params
    neuralParams.breathPressure = juce::jlimit(0.0f, 1.0f, amount);
}

void EchoelStab::setStabParams(const StabParams& params)
{
    stabParams = params;
}

void EchoelStab::loadStabPreset(StabParams::StabPreset preset)
{
    stabParams.preset = preset;

    // Configure parameters based on preset
    switch (preset)
    {
        case StabParams::SuperSaw:
            stabParams.pitchBendAmount = 3.0f;
            stabParams.pitchBendTime = 0.4f;
            stabParams.punchAmount = 0.8f;
            break;
        case StabParams::BrassStab:
            stabParams.pitchBendAmount = 2.0f;
            stabParams.pitchBendTime = 0.3f;
            stabParams.punchAmount = 0.6f;
            break;
        case StabParams::StringStab:
            stabParams.pitchBendAmount = 1.5f;
            stabParams.pitchBendTime = 0.25f;
            stabParams.punchAmount = 0.7f;
            break;
        case StabParams::VocalStab:
            stabParams.pitchBendAmount = 1.0f;
            stabParams.pitchBendTime = 0.2f;
            stabParams.punchAmount = 0.5f;
            break;
        default:
            stabParams.pitchBendAmount = 2.0f;
            stabParams.pitchBendTime = 0.3f;
            stabParams.punchAmount = 0.5f;
            break;
    }
}

void EchoelStab::setBiometricBreathParams(const BiometricBreathParams& params)
{
    biometricParams = params;
}

void EchoelStab::setEffectsParams(const EffectsParams& params)
{
    effectsParams = params;
}

//==============================================================================
// MIDI Controllers
//==============================================================================

void EchoelStab::setModWheelAmount(float amount)
{
    vibratoParams.depth = juce::jlimit(0.0f, 1.0f, amount) * 0.5f;  // 0-0.5 semitones
}

void EchoelStab::setBreathController(float amount)
{
    neuralParams.breathPressure = juce::jlimit(0.0f, 1.0f, amount);
}

void EchoelStab::setExpressionPedal(float amount)
{
    biometricParams.emotionIntensity = juce::jlimit(0.0f, 1.0f, amount);
}

void EchoelStab::setPitchBend(float semitones)
{
    // Applied per-voice during synthesis
}

void EchoelStab::setAftertouch(float amount)
{
    // Aftertouch adds brightness via formant shift
    neuralParams.formantShift = amount * 2.0f;  // 0-2 semitones
}

//==============================================================================
// Factory Presets
//==============================================================================

void EchoelStab::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::ClassicalTrumpet:
            setBrassType(BrassType::Trumpet);
            setArticulation(ArticulationType::Auto);
            setMuteType(MuteType::None);
            vibratoParams.rate = 5.5f;
            vibratoParams.depth = 0.3f;
            vibratoParams.delay = 0.3f;
            neuralParams.lipTension = 0.6f;
            neuralParams.breathPressure = 0.7f;
            ensembleParams.voiceCount = 1;
            break;

        case Preset::JazzTrumpet:
            setBrassType(BrassType::Trumpet);
            setArticulation(ArticulationType::Auto);
            setMuteType(MuteType::None);
            vibratoParams.rate = 6.0f;
            vibratoParams.depth = 0.4f;
            vibratoParams.delay = 0.1f;
            neuralParams.lipTension = 0.7f;
            neuralParams.breathPressure = 0.8f;
            ensembleParams.voiceCount = 1;
            break;

        case Preset::MutedTrumpet:
            setBrassType(BrassType::Trumpet);
            setArticulation(ArticulationType::Staccato);
            setMuteType(MuteType::Straight);
            vibratoParams.rate = 5.0f;
            vibratoParams.depth = 0.2f;
            neuralParams.lipTension = 0.5f;
            neuralParams.breathPressure = 0.6f;
            ensembleParams.voiceCount = 1;
            break;

        case Preset::FrenchHornSection:
            setBrassType(BrassType::FrenchHorn);
            setArticulation(ArticulationType::Legato);
            setMuteType(MuteType::None);
            vibratoParams.rate = 5.0f;
            vibratoParams.depth = 0.25f;
            neuralParams.lipTension = 0.5f;
            neuralParams.breathPressure = 0.7f;
            ensembleParams.voiceCount = 4;
            ensembleParams.harmonyMode = EnsembleParams::Unison;
            ensembleParams.spread = 0.4f;
            ensembleParams.detune = 0.08f;
            break;

        case Preset::TromboneSection:
            setBrassType(BrassType::Trombone);
            setArticulation(ArticulationType::Marcato);
            setMuteType(MuteType::None);
            vibratoParams.rate = 5.0f;
            vibratoParams.depth = 0.3f;
            neuralParams.lipTension = 0.6f;
            neuralParams.breathPressure = 0.8f;
            ensembleParams.voiceCount = 3;
            ensembleParams.harmonyMode = EnsembleParams::Unison;
            ensembleParams.spread = 0.5f;
            ensembleParams.detune = 0.1f;
            break;

        case Preset::FullBrassSection:
            setBrassType(BrassType::Section);
            setArticulation(ArticulationType::Marcato);
            setMuteType(MuteType::None);
            vibratoParams.rate = 5.5f;
            vibratoParams.depth = 0.3f;
            neuralParams.lipTension = 0.6f;
            neuralParams.breathPressure = 0.85f;
            ensembleParams.voiceCount = 8;
            ensembleParams.harmonyMode = EnsembleParams::Triads;
            ensembleParams.spread = 0.7f;
            ensembleParams.detune = 0.12f;
            break;

        case Preset::SynthBrassStab:
            setBrassType(BrassType::SynthStab);
            setArticulation(ArticulationType::Staccato);
            loadStabPreset(StabParams::SynthStab);
            ensembleParams.voiceCount = 6;
            ensembleParams.harmonyMode = EnsembleParams::Triads;
            ensembleParams.spread = 0.8f;
            effectsParams.compression = 0.7f;
            break;

        case Preset::SuperSawStab:
            setBrassType(BrassType::SynthStab);
            setArticulation(ArticulationType::Staccato);
            loadStabPreset(StabParams::SuperSaw);
            ensembleParams.voiceCount = 8;
            ensembleParams.harmonyMode = EnsembleParams::Triads;
            ensembleParams.spread = 1.0f;
            ensembleParams.detune = 0.2f;
            effectsParams.compression = 0.8f;
            break;

        case Preset::StringStab:
            setBrassType(BrassType::StringStab);
            setArticulation(ArticulationType::Marcato);
            loadStabPreset(StabParams::StringStab);
            ensembleParams.voiceCount = 12;
            ensembleParams.harmonyMode = EnsembleParams::Triads;
            ensembleParams.spread = 0.9f;
            effectsParams.reverbAmount = 0.4f;
            break;

        case Preset::ChoirStab:
            setBrassType(BrassType::VocalStab);
            setArticulation(ArticulationType::Marcato);
            loadStabPreset(StabParams::VocalStab);
            ensembleParams.voiceCount = 8;
            ensembleParams.harmonyMode = EnsembleParams::Triads;
            effectsParams.reverbAmount = 0.5f;
            break;

        case Preset::BiometricBreath:
            setBrassType(BrassType::Flugelhorn);
            setArticulation(ArticulationType::Auto);
            biometricParams.enabled = true;
            biometricParams.breathControlsVibrato = true;
            biometricParams.breathControlsPressure = true;
            vibratoParams.syncToBreathing = true;
            break;

        case Preset::MilesDavisHarmon:
            setBrassType(BrassType::Trumpet);
            setArticulation(ArticulationType::Legato);
            setMuteType(MuteType::Harmon);
            vibratoParams.rate = 5.5f;
            vibratoParams.depth = 0.35f;
            neuralParams.lipTension = 0.65f;
            neuralParams.breathPressure = 0.75f;
            break;

        default:
            // Default preset
            setBrassType(BrassType::Trumpet);
            setArticulation(ArticulationType::Auto);
            setMuteType(MuteType::None);
            break;
    }
}

//==============================================================================
// Machine Learning Model
//==============================================================================

void EchoelStab::loadMLModel(const std::string& modelPath)
{
    mlModel.modelPath = modelPath;
    mlModel.loaded = true;  // Simplified - actual ML loading would happen here
}

void EchoelStab::MLModel::predictFormants(float pitch, float lipTension, std::array<float, 5>& formantFreqs)
{
    // Simplified ML inference - real implementation would use trained model
    // This simulates formant prediction based on pitch and lip tension

    float pitchFactor = std::pow(2.0f, (pitch - 60.0f) / 12.0f);
    float tensionFactor = 0.8f + (lipTension * 0.4f);  // 0.8 to 1.2

    // Adjust formants based on pitch and tension
    for (int i = 0; i < 5; ++i)
    {
        formantFreqs[i] *= (pitchFactor * 0.3f + 0.7f) * tensionFactor;
    }
}

void EchoelStab::MLModel::predictBrightness(float breathPressure, float& brightness)
{
    // Higher breath pressure = brighter tone
    brightness = 0.5f + (breathPressure * 0.5f);
}

void EchoelStab::MLModel::predictArticulation(const std::vector<float>& velocityProfile, ArticulationType& detected)
{
    // Simplified ML articulation detection
    if (velocityProfile.empty())
        return;

    float attackSpeed = velocityProfile[0];
    float sustainLevel = velocityProfile.size() > 10 ? velocityProfile[10] : 0.5f;

    if (attackSpeed > 0.8f && sustainLevel < 0.3f)
        detected = ArticulationType::Staccato;
    else if (attackSpeed < 0.3f && sustainLevel > 0.7f)
        detected = ArticulationType::Legato;
    else if (attackSpeed > 0.9f && sustainLevel > 0.8f)
        detected = ArticulationType::Marcato;
    else
        detected = ArticulationType::Tenuto;
}

//==============================================================================
// Audio Processing
//==============================================================================

void EchoelStab::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    this->sampleRate = sampleRate;
}

void EchoelStab::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
{
    buffer.clear();

    // Process MIDI events
    for (const auto metadata : midiMessages)
    {
        auto message = metadata.getMessage();

        if (message.isNoteOn())
        {
            // Find free voice
            for (auto& voice : voices)
            {
                if (!voice.active)
                {
                    voice.active = true;
                    voice.midiNote = message.getNoteNumber();
                    voice.velocity = message.getFloatVelocity();
                    voice.vibratoPhase = 0.0f;
                    voice.articulationEnv = 0.0f;
                    voice.breathPressure = neuralParams.breathPressure * voice.velocity;

                    // Set random ensemble detuning
                    static std::random_device rd;
                    static std::mt19937 gen(rd());
                    std::uniform_real_distribution<float> detuneDist(-ensembleParams.detune, ensembleParams.detune);
                    voice.detuneCents = detuneDist(gen);

                    // Update formants with ML if enabled
                    if (neuralParams.enableNeuralFormants && mlModel.loaded)
                    {
                        mlModel.predictFormants(static_cast<float>(voice.midiNote),
                                               neuralParams.lipTension,
                                               voice.formantFreqs);
                    }

                    break;
                }
            }
        }
        else if (message.isNoteOff())
        {
            // Release voice
            for (auto& voice : voices)
            {
                if (voice.active && voice.midiNote == message.getNoteNumber())
                {
                    voice.active = false;
                    break;
                }
            }
        }
        else if (message.isController())
        {
            auto controllerNumber = message.getControllerNumber();
            auto controllerValue = message.getControllerValue() / 127.0f;

            if (controllerNumber == 1)  // Mod wheel
                setModWheelAmount(controllerValue);
            else if (controllerNumber == 2)  // Breath controller
                setBreathController(controllerValue);
            else if (controllerNumber == 11)  // Expression
                setExpressionPedal(controllerValue);
        }
    }

    // Synthesize all active voices
    const int numSamples = buffer.getNumSamples();
    auto* leftChannel = buffer.getWritePointer(0);
    auto* rightChannel = buffer.getNumChannels() > 1 ? buffer.getWritePointer(1) : nullptr;

    for (int sample = 0; sample < numSamples; ++sample)
    {
        float mixedSample = 0.0f;
        int activeVoiceCount = 0;

        for (auto& voice : voices)
        {
            if (voice.active)
            {
                // Apply biometric modulation
                if (biometricParams.enabled)
                    applyBiometricModulation(voice);

                // Synthesize voice
                float voiceSample = synthesizeBrassVoice(voice);

                // Apply mute
                if (currentMute != MuteType::None)
                    applyMute(voiceSample);

                mixedSample += voiceSample;
                activeVoiceCount++;
            }
        }

        // Normalize by active voice count
        if (activeVoiceCount > 0)
            mixedSample /= std::sqrt(static_cast<float>(activeVoiceCount));

        // Simple stereo spread
        leftChannel[sample] = mixedSample;
        if (rightChannel)
            rightChannel[sample] = mixedSample;
    }

    // Apply ensemble processing
    if (ensembleParams.voiceCount > 1)
        processEnsemble(buffer);
}

void EchoelStab::reset()
{
    for (auto& voice : voices)
    {
        voice.active = false;
        voice.vibratoPhase = 0.0f;
        voice.articulationEnv = 0.0f;
    }
}

//==============================================================================
// Physical Modeling & DSP
//==============================================================================

float EchoelStab::synthesizeBrassVoice(BrassVoice& voice)
{
    // Calculate fundamental frequency
    float frequency = 440.0f * std::pow(2.0f, (voice.midiNote - 69.0f + voice.detuneCents * 0.01f) / 12.0f);

    // Vibrato modulation
    float vibratoMod = 0.0f;
    if (vibratoParams.depth > 0.0f)
    {
        voice.vibratoPhase += (vibratoParams.rate * juce::MathConstants<float>::twoPi) / static_cast<float>(sampleRate);
        if (voice.vibratoPhase >= juce::MathConstants<float>::twoPi)
            voice.vibratoPhase -= juce::MathConstants<float>::twoPi;

        // Vibrato envelope
        voice.vibratoDepth = std::min(voice.vibratoDepth + 0.001f, 1.0f);
        vibratoMod = std::sin(voice.vibratoPhase) * vibratoParams.depth * voice.vibratoDepth;
    }

    frequency *= std::pow(2.0f, vibratoMod / 12.0f);

    // Physical modeling: Lip excitation
    float lipExcitation = lipModel(voice.breathPressure, frequency);

    // Bore resonance
    float boreLength = 1.0f / frequency;  // Simplified
    float boreOutput = boreResonator(lipExcitation, boreLength);

    // Bell radiation
    float output = bellRadiation(boreOutput);

    // Apply formant filtering (simplified 5-band formant filter)
    float formantOutput = 0.0f;
    for (int i = 0; i < 5; ++i)
    {
        float formantFreq = voice.formantFreqs[i];
        float gain = voice.formantGains[i];

        // Simple resonant filter at formant frequency
        float resonance = std::sin(juce::MathConstants<float>::twoPi * formantFreq / static_cast<float>(sampleRate));
        formantOutput += output * resonance * gain;
    }

    // Articulation envelope
    voice.articulationEnv = std::min(voice.articulationEnv + 0.01f, 1.0f);

    return formantOutput * voice.articulationEnv * voice.velocity * 0.3f;
}

float EchoelStab::lipModel(float pressure, float frequency)
{
    // Simplified lip model: square wave with variable duty cycle based on pressure
    static float phase = 0.0f;
    phase += frequency / static_cast<float>(sampleRate);
    if (phase >= 1.0f)
        phase -= 1.0f;

    float dutyCycle = 0.3f + (pressure * 0.4f);  // 0.3 to 0.7
    float output = (phase < dutyCycle) ? 1.0f : -1.0f;

    // Apply lip tension (smoothing)
    return output * (0.7f + neuralParams.lipTension * 0.3f);
}

float EchoelStab::boreResonator(float input, float length)
{
    // Simplified bore resonance: low-pass filter with resonance
    static float state = 0.0f;
    float resonance = neuralParams.boreResonance;

    state = state * (0.95f + resonance * 0.04f) + input * 0.1f;
    return state;
}

float EchoelStab::bellRadiation(float input)
{
    // Simplified bell radiation: high-pass emphasis
    static float prevInput = 0.0f;
    float bellSize = neuralParams.bellRadius;

    float output = input + (input - prevInput) * bellSize * 0.5f;
    prevInput = input;

    return output;
}

void EchoelStab::updateFormants(BrassVoice& voice)
{
    // Update formant frequencies based on neural params
    if (neuralParams.enableNeuralFormants && mlModel.loaded)
    {
        mlModel.predictFormants(static_cast<float>(voice.midiNote),
                               neuralParams.lipTension,
                               voice.formantFreqs);
    }

    // Apply formant shift
    if (neuralParams.formantShift != 0.0f)
    {
        float shiftFactor = std::pow(2.0f, neuralParams.formantShift / 12.0f);
        for (auto& freq : voice.formantFreqs)
            freq *= shiftFactor;
    }
}

void EchoelStab::applyMute(float& sample)
{
    // Apply mute filtering
    switch (currentMute)
    {
        case MuteType::Straight:
            // High-pass + notch (metallic)
            sample *= 0.6f;
            break;

        case MuteType::Cup:
            // Low-pass (covered)
            sample *= 0.5f;
            break;

        case MuteType::Harmon:
            // Band-pass (focused, nasal)
            sample *= 0.7f;
            break;

        case MuteType::Plunger:
            // Variable wah effect
            sample *= 0.65f;
            break;

        case MuteType::Bucket:
            // Heavy low-pass
            sample *= 0.4f;
            break;

        case MuteType::Practice:
            // Extreme muffling
            sample *= 0.2f;
            break;

        default:
            break;
    }
}

void EchoelStab::processEnsemble(juce::AudioBuffer<float>& buffer)
{
    // Apply stereo spread based on ensemble parameters
    if (buffer.getNumChannels() < 2)
        return;

    auto* leftChannel = buffer.getWritePointer(0);
    auto* rightChannel = buffer.getWritePointer(1);

    float spread = ensembleParams.spread;

    for (int i = 0; i < buffer.getNumSamples(); ++i)
    {
        float mono = (leftChannel[i] + rightChannel[i]) * 0.5f;
        float side = (leftChannel[i] - rightChannel[i]) * 0.5f;

        leftChannel[i] = mono + (side * spread);
        rightChannel[i] = mono - (side * spread);
    }
}

void EchoelStab::applyBiometricModulation(BrassVoice& voice)
{
    // Breathing rate modulates vibrato
    if (biometricParams.breathControlsVibrato)
    {
        float breathingPhase = std::fmod(voice.vibratoPhase * biometricParams.breathingRate / 60.0f,
                                        juce::MathConstants<float>::twoPi);
        float breathingMod = (std::sin(breathingPhase) + 1.0f) * 0.5f;  // 0-1

        voice.vibratoDepth *= (0.7f + breathingMod * 0.3f);
    }

    // Heart rate variability affects ensemble tightness
    if (biometricParams.hrvControlsEnsemble)
    {
        voice.timingOffset = biometricParams.heartRateVariability * ensembleParams.timingVariation;
    }

    // Stress adds shakiness
    if (biometricParams.stressAddsShakiness)
    {
        static std::random_device rd;
        static std::mt19937 gen(rd());
        std::normal_distribution<float> shakeDist(0.0f, biometricParams.stressLevel * 0.02f);

        voice.breathPressure += shakeDist(gen);
        voice.breathPressure = juce::jlimit(0.0f, 1.0f, voice.breathPressure);
    }

    // Emotion intensity affects overall dynamics
    float emotionFactor = 0.7f + (biometricParams.emotionIntensity * 0.3f);
    voice.velocity *= emotionFactor;
}
