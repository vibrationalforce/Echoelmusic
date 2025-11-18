#include "EchoelString.h"
#include <cmath>
#include <random>
#include <algorithm>

//==============================================================================
EchoelString::EchoelString()
{
    // Initialize string pool
    strings.resize(32);  // Support up to 32 strings (orchestra size)
}

//==============================================================================
// Instrument Configuration
//==============================================================================

void EchoelString::setInstrument(StringInstrument instrument)
{
    currentInstrument = instrument;

    // Configure section size based on instrument type
    SectionParams defaultSection;

    switch (instrument)
    {
        case StringInstrument::SoloViolin:
        case StringInstrument::SoloViola:
        case StringInstrument::SoloCello:
        case StringInstrument::SoloDoubleBass:
            defaultSection.violins1 = 1;
            defaultSection.violins2 = 0;
            defaultSection.violas = 0;
            defaultSection.cellos = 0;
            defaultSection.basses = 0;
            defaultSection.sectionSpread = 0.0f;
            defaultSection.tuningVariation = 0.0f;
            defaultSection.timingVariation = 0.0f;
            break;

        case StringInstrument::StringQuartet:
            defaultSection.violins1 = 1;
            defaultSection.violins2 = 1;
            defaultSection.violas = 1;
            defaultSection.cellos = 1;
            defaultSection.basses = 0;
            defaultSection.sectionSpread = 0.5f;
            defaultSection.tuningVariation = 0.01f;
            defaultSection.timingVariation = 0.005f;
            break;

        case StringInstrument::ChamberStrings:
            defaultSection.violins1 = 3;
            defaultSection.violins2 = 3;
            defaultSection.violas = 2;
            defaultSection.cellos = 2;
            defaultSection.basses = 1;
            defaultSection.sectionSpread = 0.6f;
            defaultSection.tuningVariation = 0.015f;
            defaultSection.timingVariation = 0.008f;
            break;

        case StringInstrument::StringOrchestra:
            defaultSection.violins1 = 8;
            defaultSection.violins2 = 8;
            defaultSection.violas = 6;
            defaultSection.cellos = 6;
            defaultSection.basses = 4;
            defaultSection.sectionSpread = 0.8f;
            defaultSection.tuningVariation = 0.02f;
            defaultSection.timingVariation = 0.01f;
            break;
    }

    setSectionSize(defaultSection);

    // Set appropriate physical parameters based on instrument
    PhysicalStringParams defaultPhysical;

    switch (instrument)
    {
        case StringInstrument::SoloViolin:
            defaultPhysical.bodySize = 0.0f;  // Small
            defaultPhysical.bodyResonance = 0.7f;
            break;

        case StringInstrument::SoloViola:
            defaultPhysical.bodySize = 0.25f;
            defaultPhysical.bodyResonance = 0.65f;
            break;

        case StringInstrument::SoloCello:
            defaultPhysical.bodySize = 0.6f;
            defaultPhysical.bodyResonance = 0.75f;
            break;

        case StringInstrument::SoloDoubleBass:
            defaultPhysical.bodySize = 1.0f;  // Large
            defaultPhysical.bodyResonance = 0.6f;
            break;

        default:
            defaultPhysical.bodySize = 0.5f;
            defaultPhysical.bodyResonance = 0.7f;
            break;
    }

    setPhysicalModel(defaultPhysical);
}

void EchoelString::setArticulation(BowArticulation articulation)
{
    currentArticulation = articulation;
}

void EchoelString::setPhysicalModel(const PhysicalStringParams& params)
{
    physicalParams = params;
}

void EchoelString::setSectionSize(const SectionParams& params)
{
    sectionParams = params;

    // Calculate total player count
    int totalPlayers = params.violins1 + params.violins2 + params.violas +
                       params.cellos + params.basses;

    if (totalPlayers > static_cast<int>(strings.size()))
    {
        strings.resize(totalPlayers);
    }
}

//==============================================================================
// ML Bow Control
//==============================================================================

void EchoelString::trainBowModel(const juce::File& referenceRecording)
{
    // Simplified ML training - real implementation would analyze recording
    mlBowModel.trained = true;
}

void EchoelString::MLBowModel::predictBowParams(float velocity, float& pressure, float& speed)
{
    // Simplified ML inference for bow parameters
    // Real implementation would use trained neural network

    // Map velocity to realistic bow pressure and speed
    pressure = 0.3f + (velocity * 0.6f);  // 0.3 to 0.9
    speed = 0.4f + (velocity * 0.5f);     // 0.4 to 0.9

    // Add some variation
    static std::random_device rd;
    static std::mt19937 gen(rd());
    std::normal_distribution<float> variation(0.0f, 0.05f);

    pressure += variation(gen);
    speed += variation(gen);

    pressure = juce::jlimit(0.0f, 1.0f, pressure);
    speed = juce::jlimit(0.0f, 1.0f, speed);
}

//==============================================================================
// Biometric Integration
//==============================================================================

void EchoelString::setEmotionalState(float joy, float sorrow)
{
    biometricParams.joy = juce::jlimit(0.0f, 1.0f, joy);
    biometricParams.sorrow = juce::jlimit(0.0f, 1.0f, sorrow);
}

void EchoelString::setHeartRateVariability(float hrv)
{
    biometricParams.heartRateVariability = juce::jlimit(0.0f, 1.0f, hrv);
}

//==============================================================================
// Auto-Divisi
//==============================================================================

void EchoelString::enableAutoDivisi(bool enable)
{
    autoDivisiEnabled = enable;
}

//==============================================================================
// Audio Processing
//==============================================================================

void EchoelString::prepare(double sampleRate, int samplesPerBlock)
{
    this->sampleRate = sampleRate;

    // Initialize waveguide delay lines for each string
    for (auto& string : strings)
    {
        // Maximum delay line size for lowest note (C1 ~32Hz)
        int maxDelay = static_cast<int>(sampleRate / 30.0) + 1;
        string.delayLine.resize(maxDelay, 0.0f);
        string.writePos = 0;
        string.dampingCoeff = 0.998f;
    }
}

void EchoelString::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
{
    buffer.clear();

    // Process MIDI events
    for (const auto metadata : midi)
    {
        auto message = metadata.getMessage();

        if (message.isNoteOn())
        {
            int note = message.getNoteNumber();
            float velocity = message.getFloatVelocity();

            // Trigger string(s) based on section size
            triggerString(note, velocity);
        }
        else if (message.isNoteOff())
        {
            int note = message.getNoteNumber();
            releaseString(note);
        }
    }

    // Synthesize all active strings
    const int numSamples = buffer.getNumSamples();

    for (auto& string : strings)
    {
        if (string.active)
        {
            for (int sample = 0; sample < numSamples; ++sample)
            {
                float output = 0.0f;

                // Choose synthesis method based on articulation
                switch (currentArticulation)
                {
                    case BowArticulation::Pizzicato:
                    case BowArticulation::ColLegno:
                        output = string.pluck(string.frequency);
                        break;

                    default:
                        // Bowed articulations
                        float bowPressure = physicalParams.bowPressure;
                        float bowSpeed = physicalParams.bowSpeed;

                        // Use ML model if trained
                        if (mlBowModel.trained)
                        {
                            mlBowModel.predictBowParams(string.velocity, bowPressure, bowSpeed);
                        }

                        output = string.bow(bowPressure, bowSpeed);
                        break;
                }

                // Apply articulation envelope
                output *= string.articulationEnvelope;

                // Apply body resonance
                output = applyBodyResonance(output);

                // Mix to buffer
                for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
                {
                    buffer.addSample(channel, sample, output * string.velocity * 0.3f);
                }

                // Update articulation envelope
                updateArticulationEnvelope(string);
            }
        }
    }

    // Apply section spreading (stereo width)
    if (sectionParams.sectionSpread > 0.0f && buffer.getNumChannels() == 2)
    {
        applySectionStereo(buffer);
    }
}

//==============================================================================
// String Triggering
//==============================================================================

void EchoelString::triggerString(int midiNote, float velocity)
{
    // Find first inactive string
    for (auto& string : strings)
    {
        if (!string.active)
        {
            string.active = true;
            string.midiNote = midiNote;
            string.velocity = velocity;
            string.articulationEnvelope = 0.0f;

            // Calculate frequency with section tuning variation
            static std::random_device rd;
            static std::mt19937 gen(rd());
            std::uniform_real_distribution<float> detuneDist(-sectionParams.tuningVariation,
                                                             sectionParams.tuningVariation);

            float detuneFactor = std::pow(2.0f, detuneDist(gen));
            string.frequency = 440.0f * std::pow(2.0f, (midiNote - 69.0f) / 12.0f) * detuneFactor;

            // Initialize waveguide
            int delayLength = static_cast<int>(sampleRate / string.frequency);
            if (delayLength < 2)
                delayLength = 2;
            if (delayLength > static_cast<int>(string.delayLine.size()))
                delayLength = static_cast<int>(string.delayLine.size());

            // Clear delay line
            std::fill(string.delayLine.begin(), string.delayLine.end(), 0.0f);
            string.writePos = 0;

            // Set damping based on string length (higher notes = more damping)
            string.dampingCoeff = 0.995f + (midiNote / 127.0f) * 0.004f;

            break;
        }
    }
}

void EchoelString::releaseString(int midiNote)
{
    for (auto& string : strings)
    {
        if (string.active && string.midiNote == midiNote)
        {
            string.isReleasing = true;
        }
    }
}

//==============================================================================
// Waveguide String Synthesis
//==============================================================================

float EchoelString::WaveguideString::pluck(float frequency)
{
    // Karplus-Strong plucked string algorithm
    int delayLength = static_cast<int>(44100.0 / frequency);  // Simplified
    if (delayLength >= static_cast<int>(delayLine.size()))
        delayLength = static_cast<int>(delayLine.size()) - 1;

    // Read from delay line
    int readPos = (writePos - delayLength + delayLine.size()) % delayLine.size();
    float output = delayLine[readPos];

    // On first pluck, excite with noise
    if (!isExcited)
    {
        static std::random_device rd;
        static std::mt19937 gen(rd());
        std::uniform_real_distribution<float> noiseDist(-1.0f, 1.0f);

        output = noiseDist(gen);
        isExcited = true;
    }

    // Average filter (low-pass)
    float filtered = (output + prevOutput) * 0.5f * dampingCoeff;
    prevOutput = output;

    // Write back to delay line
    delayLine[writePos] = filtered;
    writePos = (writePos + 1) % delayLine.size();

    return filtered;
}

float EchoelString::WaveguideString::bow(float pressure, float speed)
{
    // Simplified bowed string model using waveguide synthesis
    int delayLength = static_cast<int>(44100.0 / frequency);  // Simplified
    if (delayLength >= static_cast<int>(delayLine.size()))
        delayLength = static_cast<int>(delayLine.size()) - 1;

    // Read from delay line
    int readPos = (writePos - delayLength + delayLine.size()) % delayLine.size();
    float output = delayLine[readPos];

    // Bow excitation (non-linear interaction)
    // Simplified friction model: output depends on relative velocity
    float bowVelocity = speed * 2.0f - 1.0f;  // -1 to +1
    float relativeVelocity = bowVelocity - output;

    // Friction curve (simplified)
    float friction = std::tanh(relativeVelocity * pressure * 5.0f);
    float excitation = friction * pressure * 0.1f;

    // Apply excitation to waveguide
    float filtered = (output + prevOutput) * 0.5f * dampingCoeff + excitation;
    prevOutput = output;

    // Write back to delay line
    delayLine[writePos] = filtered;
    writePos = (writePos + 1) % delayLine.size();

    return filtered;
}

//==============================================================================
// Articulation Envelopes
//==============================================================================

void EchoelString::updateArticulationEnvelope(WaveguideString& string)
{
    float attackTime = 0.05f;  // Default
    float releaseTime = 0.1f;

    switch (currentArticulation)
    {
        case BowArticulation::Legato:
            attackTime = 0.15f;
            releaseTime = 0.2f;
            break;

        case BowArticulation::Detache:
            attackTime = 0.05f;
            releaseTime = 0.1f;
            break;

        case BowArticulation::Spiccato:
            attackTime = 0.01f;
            releaseTime = 0.05f;
            break;

        case BowArticulation::Staccato:
            attackTime = 0.01f;
            releaseTime = 0.03f;
            break;

        case BowArticulation::Marcato:
            attackTime = 0.02f;
            releaseTime = 0.08f;
            break;

        case BowArticulation::Tremolo:
            attackTime = 0.005f;
            releaseTime = 0.02f;
            // Add tremolo LFO
            {
                static float tremoloPhase = 0.0f;
                tremoloPhase += 8.0f / static_cast<float>(sampleRate);  // 8 Hz tremolo
                if (tremoloPhase >= 1.0f)
                    tremoloPhase -= 1.0f;

                float tremoloMod = 0.7f + std::sin(tremoloPhase * juce::MathConstants<float>::twoPi) * 0.3f;
                string.articulationEnvelope *= tremoloMod;
            }
            break;

        case BowArticulation::Pizzicato:
            attackTime = 0.001f;
            releaseTime = 0.5f;
            break;

        case BowArticulation::ColLegno:
            attackTime = 0.001f;
            releaseTime = 0.1f;
            break;

        case BowArticulation::SulPonticello:
            attackTime = 0.08f;
            releaseTime = 0.12f;
            break;

        case BowArticulation::SulTasto:
            attackTime = 0.12f;
            releaseTime = 0.15f;
            break;

        default:
            break;
    }

    // Calculate envelope increment
    float attackIncrement = 1.0f / (attackTime * static_cast<float>(sampleRate));
    float releaseIncrement = 1.0f / (releaseTime * static_cast<float>(sampleRate));

    if (string.isReleasing)
    {
        // Release phase
        string.articulationEnvelope -= releaseIncrement;
        if (string.articulationEnvelope <= 0.0f)
        {
            string.articulationEnvelope = 0.0f;
            string.active = false;
            string.isReleasing = false;
        }
    }
    else
    {
        // Attack phase
        if (string.articulationEnvelope < 1.0f)
        {
            string.articulationEnvelope += attackIncrement;
            if (string.articulationEnvelope > 1.0f)
                string.articulationEnvelope = 1.0f;
        }
    }

    // Apply biometric emotional modulation
    if (biometricParams.joy > 0.5f)
    {
        // Joy: Brighter, more vibrato
        string.articulationEnvelope *= (1.0f + (biometricParams.joy - 0.5f) * 0.2f);
    }

    if (biometricParams.sorrow > 0.5f)
    {
        // Sorrow: Darker, slower attack
        string.articulationEnvelope *= (1.0f - (biometricParams.sorrow - 0.5f) * 0.15f);
    }
}

//==============================================================================
// Body Resonance
//==============================================================================

float EchoelString::applyBodyResonance(float input)
{
    // Simplified body resonance model
    // Real implementation would use multiple resonant filters for formants

    static float bodyState = 0.0f;

    float resonanceFreq = 200.0f + (physicalParams.bodySize * 100.0f);  // Lower for larger bodies
    float resonanceFactor = physicalParams.bodyResonance;

    // Simple one-pole filter
    bodyState = bodyState * (0.95f + resonanceFactor * 0.04f) + input * 0.1f;

    return input + bodyState * resonanceFactor * 0.5f;
}

//==============================================================================
// Section Stereo Spreading
//==============================================================================

void EchoelString::applySectionStereo(juce::AudioBuffer<float>& buffer)
{
    if (buffer.getNumChannels() < 2)
        return;

    auto* leftChannel = buffer.getWritePointer(0);
    auto* rightChannel = buffer.getWritePointer(1);

    float spread = sectionParams.sectionSpread;

    for (int i = 0; i < buffer.getNumSamples(); ++i)
    {
        float mono = (leftChannel[i] + rightChannel[i]) * 0.5f;
        float side = (leftChannel[i] - rightChannel[i]) * 0.5f;

        // Apply stereo width
        leftChannel[i] = mono + (side * spread);
        rightChannel[i] = mono - (side * spread);
    }
}

//==============================================================================
// Factory Presets
//==============================================================================

void EchoelString::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::SoloViolin:
            setInstrument(StringInstrument::SoloViolin);
            setArticulation(BowArticulation::Legato);
            physicalParams.bowPressure = 0.7f;
            physicalParams.bowPosition = 0.15f;
            physicalParams.stringTension = 0.7f;
            break;

        case Preset::StringQuartet:
            setInstrument(StringInstrument::StringQuartet);
            setArticulation(BowArticulation::Detache);
            physicalParams.bowPressure = 0.65f;
            sectionParams.sectionSpread = 0.5f;
            break;

        case Preset::ChamberStrings:
            setInstrument(StringInstrument::ChamberStrings);
            setArticulation(BowArticulation::Legato);
            sectionParams.sectionSpread = 0.6f;
            sectionParams.tuningVariation = 0.015f;
            break;

        case Preset::OrchestralStrings:
            setInstrument(StringInstrument::StringOrchestra);
            setArticulation(BowArticulation::Marcato);
            physicalParams.bowPressure = 0.8f;
            sectionParams.sectionSpread = 0.8f;
            sectionParams.tuningVariation = 0.02f;
            break;

        case Preset::Pizzicato:
            setArticulation(BowArticulation::Pizzicato);
            physicalParams.stringTension = 0.8f;
            break;

        case Preset::Tremolo:
            setArticulation(BowArticulation::Tremolo);
            physicalParams.bowSpeed = 0.9f;
            break;

        case Preset::SulPonticello:
            setArticulation(BowArticulation::SulPonticello);
            physicalParams.bowPosition = 0.05f;  // Very close to bridge
            physicalParams.bowPressure = 0.6f;
            break;

        case Preset::SulTasto:
            setArticulation(BowArticulation::SulTasto);
            physicalParams.bowPosition = 0.5f;  // Over fingerboard
            physicalParams.bowPressure = 0.5f;
            break;

        default:
            break;
    }
}
