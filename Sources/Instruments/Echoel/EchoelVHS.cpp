#include "EchoelVHS.h"
#include <cmath>
#include <random>

//==============================================================================
EchoelVHS::EchoelVHS()
{
    // Initialize pitch buffer for wow/flutter
    pitchBuffer.resize(8192, 0.0f);
}

//==============================================================================
// Format Configuration
//==============================================================================

void EchoelVHS::setFormat(VintageFormat format)
{
    currentFormat = format;

    // Configure parameters based on format
    switch (format)
    {
        case VintageFormat::VHS:
            degradationParams.bassRolloff = 120.0f;
            degradationParams.trebleRolloff = 4000.0f;  // Very limited bandwidth
            degradationParams.wowAmount = 0.6f;
            degradationParams.wowRate = 0.8f;
            degradationParams.flutterAmount = 0.4f;
            degradationParams.hissAmount = 0.5f;
            vaporwaveParams.nostalgia = 0.8f;
            break;

        case VintageFormat::CassetteTypeI:
            degradationParams.bassRolloff = 50.0f;
            degradationParams.trebleRolloff = 12000.0f;
            degradationParams.wowAmount = 0.4f;
            degradationParams.flutterAmount = 0.3f;
            degradationParams.hissAmount = 0.4f;
            degradationParams.dropoutProbability = 0.02f;
            break;

        case VintageFormat::CassetteTypeII:
            degradationParams.bassRolloff = 40.0f;
            degradationParams.trebleRolloff = 15000.0f;  // Better high-end
            degradationParams.wowAmount = 0.3f;
            degradationParams.flutterAmount = 0.2f;
            degradationParams.hissAmount = 0.3f;
            break;

        case VintageFormat::CassetteTypeIV:
            degradationParams.bassRolloff = 30.0f;
            degradationParams.trebleRolloff = 18000.0f;  // Best cassette quality
            degradationParams.wowAmount = 0.2f;
            degradationParams.flutterAmount = 0.15f;
            degradationParams.hissAmount = 0.2f;
            break;

        case VintageFormat::ReelToReel:
            degradationParams.bassRolloff = 20.0f;
            degradationParams.trebleRolloff = 20000.0f;  // Studio quality
            degradationParams.wowAmount = 0.1f;
            degradationParams.flutterAmount = 0.05f;
            degradationParams.hissAmount = 0.15f;
            break;

        case VintageFormat::Vinyl33:
        case VintageFormat::Vinyl45:
            degradationParams.bassRolloff = 30.0f;
            degradationParams.trebleRolloff = 16000.0f;
            degradationParams.wowAmount = 0.25f;
            degradationParams.flutterAmount = 0.1f;
            vinylParams.rpm = (format == VintageFormat::Vinyl45) ? 45.0f : 33.33f;
            vinylParams.crackleAmount = 0.3f;
            vinylParams.applyRIAA = true;
            break;

        case VintageFormat::Vinyl78:
            degradationParams.bassRolloff = 100.0f;
            degradationParams.trebleRolloff = 8000.0f;
            degradationParams.wowAmount = 0.5f;
            vinylParams.rpm = 78.0f;
            vinylParams.crackleAmount = 0.6f;
            vinylParams.scratchAmount = 0.3f;
            break;

        case VintageFormat::WaxCylinder:
            degradationParams.bassRolloff = 200.0f;
            degradationParams.trebleRolloff = 2500.0f;  // Very limited
            degradationParams.wowAmount = 0.8f;
            degradationParams.hissAmount = 0.7f;
            vinylParams.crackleAmount = 0.8f;
            break;

        case VintageFormat::AMRadio:
            radioParams.lowCut = 300.0f;
            radioParams.highCut = 3000.0f;
            radioParams.staticAmount = 0.4f;
            radioParams.interferenceAmount = 0.3f;
            degradationParams.hissAmount = 0.3f;
            break;

        case VintageFormat::FMRadio:
            radioParams.lowCut = 50.0f;
            radioParams.highCut = 15000.0f;
            radioParams.staticAmount = 0.1f;
            radioParams.multiPathAmount = 0.2f;
            break;

        case VintageFormat::VaporwaveLoFi:
            vaporwaveParams.pitchShift = -200.0f;
            vaporwaveParams.targetSampleRate = 22050;
            vaporwaveParams.bitDepth = 12;
            vaporwaveParams.nostalgia = 0.8f;
            vaporwaveParams.dreaminess = 0.7f;
            degradationParams.wowAmount = 0.3f;
            degradationParams.hissAmount = 0.3f;
            break;

        default:
            break;
    }
}

void EchoelVHS::setDegradationParams(const DegradationParams& params)
{
    degradationParams = params;
}

void EchoelVHS::setVinylParams(const VinylParams& params)
{
    vinylParams = params;
}

void EchoelVHS::setVaporwaveParams(const VaporwaveParams& params)
{
    vaporwaveParams = params;
}

void EchoelVHS::setAnalogParams(const AnalogParams& params)
{
    analogParams = params;
}

void EchoelVHS::setRadioParams(const RadioParams& params)
{
    radioParams = params;
}

void EchoelVHS::setBiometricNostalgiaParams(const BiometricNostalgiaParams& params)
{
    biometricParams = params;
}

void EchoelVHS::addMemory(const juce::File& audioFile)
{
    if (audioFile.existsAsFile())
    {
        biometricParams.memoryAudioFiles.push_back(audioFile);
        // Real implementation would load audio into loadedMemories
    }
}

void EchoelVHS::clearMemories()
{
    biometricParams.memoryAudioFiles.clear();
    loadedMemories.clear();
}

//==============================================================================
// ML Model
//==============================================================================

void EchoelVHS::loadMLModel(const std::string& modelPath)
{
    mlModel.loaded = true;  // Simplified
}

void EchoelVHS::MLDegradationModel::predictWearPattern(float age, std::vector<float>& frequencyResponse)
{
    // Simplified ML inference - real would use trained model
    // Older tapes lose more highs and lows
    for (size_t i = 0; i < frequencyResponse.size(); ++i)
    {
        float freq = 20.0f * std::pow(20000.0f / 20.0f, i / static_cast<float>(frequencyResponse.size()));

        // High-frequency rolloff increases with age
        if (freq > 5000.0f)
            frequencyResponse[i] *= (1.0f - age * 0.7f);

        // Low-frequency loss
        if (freq < 100.0f)
            frequencyResponse[i] *= (1.0f - age * 0.5f);
    }
}

void EchoelVHS::MLDegradationModel::generateRealisticCrackle(float density, juce::AudioBuffer<float>& output)
{
    // Generate vinyl-style crackle with ML-predicted characteristics
    // Simplified version
}

void EchoelVHS::MLDegradationModel::detectEra(const juce::AudioBuffer<float>& input, int& estimatedYear)
{
    // Analyze spectral content to estimate recording era
    // Simplified
    estimatedYear = 1980;
}

//==============================================================================
// Audio Processing
//==============================================================================

void EchoelVHS::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    this->sampleRate = sampleRate;

    // Initialize filters
    bassRolloffFilter.reset();
    trebleRolloffFilter.reset();
    riaaFilter.reset();
}

void EchoelVHS::processBlock(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();

    // Apply input gain
    if (analogParams.inputGain != 0.0f)
    {
        float gainFactor = juce::Decibels::decibelsToGain(analogParams.inputGain);
        buffer.applyGain(gainFactor);
    }

    // Wow & Flutter (pitch modulation)
    if (degradationParams.wowAmount > 0.0f || degradationParams.flutterAmount > 0.0f)
    {
        applyWowFlutter(buffer);
    }

    // Sample rate reduction (LoFi effect)
    if (currentFormat == VintageFormat::VaporwaveLoFi && vaporwaveParams.targetSampleRate < static_cast<int>(sampleRate))
    {
        reduceSampleRate(buffer, vaporwaveParams.targetSampleRate);
    }

    // Bit depth reduction
    if (currentFormat == VintageFormat::VaporwaveLoFi && vaporwaveParams.bitDepth < 16)
    {
        reduceBitDepth(buffer, vaporwaveParams.bitDepth);
    }

    // Frequency response shaping
    applyFrequencyResponse(buffer);

    // Tape/Vinyl saturation
    if (degradationParams.tapeHarmonics > 0.0f || analogParams.saturationAmount > 0.0f)
    {
        applySaturation(buffer);
    }

    // Tube preamp distortion
    if (analogParams.enableTubePreamp)
    {
        applyTubeDistortion(buffer);
    }

    // Dropouts (tape damage)
    if (degradationParams.dropoutProbability > 0.0f)
    {
        applyDropouts(buffer);
    }

    // Vinyl crackle
    if (vinylParams.crackleAmount > 0.0f &&
        (currentFormat == VintageFormat::Vinyl33 ||
         currentFormat == VintageFormat::Vinyl45 ||
         currentFormat == VintageFormat::Vinyl78 ||
         currentFormat == VintageFormat::WaxCylinder))
    {
        addVinylCrackle(buffer);
    }

    // Add noise (hiss, hum)
    addNoise(buffer);

    // Radio static/interference
    if (currentFormat == VintageFormat::AMRadio ||
        currentFormat == VintageFormat::FMRadio ||
        currentFormat == VintageFormat::Shortwave)
    {
        addRadioNoise(buffer);
    }

    // Biometric nostalgia
    if (biometricParams.enabled)
    {
        applyBiometricModulation(buffer);
    }

    // Memory integration
    if (biometricParams.enableMemories && !loadedMemories.empty())
    {
        processMemories(buffer);
    }

    // Output gain
    if (analogParams.outputGain != 0.0f)
    {
        float gainFactor = juce::Decibels::decibelsToGain(analogParams.outputGain);
        buffer.applyGain(gainFactor);
    }
}

void EchoelVHS::reset()
{
    wowPhase = 0.0f;
    flutterPhase = 0.0f;
    std::fill(pitchBuffer.begin(), pitchBuffer.end(), 0.0f);
    pitchWritePos = 0;
}

//==============================================================================
// Wow & Flutter
//==============================================================================

void EchoelVHS::applyWowFlutter(juce::AudioBuffer<float>& buffer)
{
    const int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);

        for (int sample = 0; sample < numSamples; ++sample)
        {
            // Wow (slow pitch drift)
            wowPhase += degradationParams.wowRate / static_cast<float>(sampleRate);
            if (wowPhase >= 1.0f)
                wowPhase -= 1.0f;

            float wow = std::sin(juce::MathConstants<float>::twoPi * wowPhase);
            wow *= degradationParams.wowAmount * 0.01f;  // ±1% pitch variation

            // Flutter (fast pitch variations)
            flutterPhase += degradationParams.flutterRate / static_cast<float>(sampleRate);
            if (flutterPhase >= 1.0f)
                flutterPhase -= 1.0f;

            float flutter = std::sin(juce::MathConstants<float>::twoPi * flutterPhase);
            flutter *= degradationParams.flutterAmount * 0.005f;  // ±0.5% pitch variation

            // Total pitch modulation
            float pitchMod = 1.0f + wow + flutter;

            // Simple pitch shifting via variable delay (simplified)
            // Real implementation would use proper pitch shifting
            float delayAmount = (1.0f - pitchMod) * 100.0f;  // Delay in samples
            int delayInt = static_cast<int>(delayAmount);
            float delayFrac = delayAmount - delayInt;

            int readPos = (pitchWritePos - delayInt + pitchBuffer.size()) % pitchBuffer.size();
            int readPos2 = (readPos - 1 + pitchBuffer.size()) % pitchBuffer.size();

            // Linear interpolation
            float output = pitchBuffer[readPos] * (1.0f - delayFrac) + pitchBuffer[readPos2] * delayFrac;

            // Write current sample to pitch buffer
            pitchBuffer[pitchWritePos] = channelData[sample];
            pitchWritePos = (pitchWritePos + 1) % pitchBuffer.size();

            channelData[sample] = output;
        }
    }
}

//==============================================================================
// Frequency Response
//==============================================================================

void EchoelVHS::applyFrequencyResponse(juce::AudioBuffer<float>& buffer)
{
    // Simplified frequency shaping
    // Real implementation would use proper filters

    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);

        static float bassState = 0.0f;
        static float trebleState = 0.0f;

        for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
        {
            float input = channelData[sample];

            // Bass rolloff (high-pass)
            float bassCoeff = std::min(1.0f, degradationParams.bassRolloff / 1000.0f);
            bassState = bassState * (1.0f - bassCoeff * 0.1f) + input * bassCoeff * 0.1f;
            float output = input - bassState;

            // Treble rolloff (low-pass)
            float trebleCoeff = std::max(0.0f, 1.0f - degradationParams.trebleRolloff / 20000.0f);
            trebleState = trebleState * (0.9f + trebleCoeff * 0.09f) + output * 0.1f;

            channelData[sample] = trebleState;
        }
    }
}

//==============================================================================
// Saturation
//==============================================================================

void EchoelVHS::applySaturation(juce::AudioBuffer<float>& buffer)
{
    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);

        for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
        {
            float input = channelData[sample];
            float output = tapeNonlinearity(input, degradationParams.tapeHarmonics);
            channelData[sample] = output;
        }
    }
}

float EchoelVHS::tapeNonlinearity(float input, float amount)
{
    // Tape saturation: soft clipping with harmonic distortion
    float drive = 1.0f + amount * 3.0f;
    float output = std::tanh(input * drive);

    // Add subtle compression
    if (degradationParams.compressionAmount > 0.0f)
    {
        float threshold = 0.5f;
        if (std::abs(output) > threshold)
        {
            float excess = std::abs(output) - threshold;
            float compressed = threshold + excess * (1.0f - degradationParams.compressionAmount);
            output = (output > 0.0f) ? compressed : -compressed;
        }
    }

    return output;
}

void EchoelVHS::applyTubeDistortion(juce::AudioBuffer<float>& buffer)
{
    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);

        for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
        {
            float input = channelData[sample];
            float output = tubeDistortion(input, analogParams.tubeType, analogParams.tubeDrive);
            channelData[sample] = output;
        }
    }
}

float EchoelVHS::tubeDistortion(float input, AnalogParams::TubeType type, float drive)
{
    // Simplified tube distortion model
    float gain = 1.0f + drive * 5.0f;
    float biasShift = (analogParams.tubeBias - 0.5f) * 0.2f;  // Asymmetric distortion

    // Apply bias
    input += biasShift;

    // Tube characteristic (asymmetric soft clipping)
    float output;
    if (input > 0.0f)
        output = std::tanh(input * gain * 1.2f);  // Harder positive
    else
        output = std::tanh(input * gain * 0.8f);  // Softer negative

    // Remove bias
    output -= biasShift;

    return output * 0.7f;  // Makeup gain
}

//==============================================================================
// Dropouts
//==============================================================================

void EchoelVHS::applyDropouts(juce::AudioBuffer<float>& buffer)
{
    static float timeSinceLastDropout = 0.0f;
    static bool inDropout = false;
    static int dropoutRemaining = 0;

    const int numSamples = buffer.getNumSamples();
    float secondsPerBuffer = numSamples / static_cast<float>(sampleRate);

    timeSinceLastDropout += secondsPerBuffer;

    for (int sample = 0; sample < numSamples; ++sample)
    {
        if (inDropout)
        {
            // Mute during dropout
            for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
            {
                buffer.setSample(channel, sample, 0.0f);
            }

            dropoutRemaining--;
            if (dropoutRemaining <= 0)
                inDropout = false;
        }
        else
        {
            // Check if dropout should occur
            if (random.nextFloat() < degradationParams.dropoutProbability / sampleRate)
            {
                inDropout = true;
                dropoutRemaining = static_cast<int>(degradationParams.dropoutDuration * sampleRate);
                timeSinceLastDropout = 0.0f;
            }
        }
    }
}

//==============================================================================
// Vinyl Crackle
//==============================================================================

void EchoelVHS::addVinylCrackle(juce::AudioBuffer<float>& buffer)
{
    for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
    {
        float crackle = generateCrackle() * vinylParams.crackleAmount * 0.1f;

        for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
        {
            buffer.addSample(channel, sample, crackle);
        }
    }
}

float EchoelVHS::generateCrackle()
{
    // Random pops and crackles
    if (random.nextFloat() < vinylParams.crackleDensity * 0.001f)
    {
        return (random.nextFloat() * 2.0f - 1.0f) * 5.0f;  // Loud pop
    }

    // Continuous light noise
    return (random.nextFloat() * 2.0f - 1.0f) * 0.2f;
}

//==============================================================================
// Noise Generation
//==============================================================================

void EchoelVHS::addNoise(juce::AudioBuffer<float>& buffer)
{
    for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
    {
        // Tape hiss
        float hiss = generateHiss() * degradationParams.hissAmount * 0.05f;

        // AC hum
        float hum50 = generateHum(50.0f) * degradationParams.hum50Hz * 0.02f;
        float hum60 = generateHum(60.0f) * degradationParams.hum60Hz * 0.02f;

        float totalNoise = hiss + hum50 + hum60;

        for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
        {
            buffer.addSample(channel, sample, totalNoise);
        }
    }
}

float EchoelVHS::generateHiss()
{
    return random.nextFloat() * 2.0f - 1.0f;
}

float EchoelVHS::generateHum(float frequency)
{
    static float humPhase = 0.0f;
    humPhase += frequency / static_cast<float>(sampleRate);
    if (humPhase >= 1.0f)
        humPhase -= 1.0f;

    return std::sin(juce::MathConstants<float>::twoPi * humPhase);
}

void EchoelVHS::addRadioNoise(juce::AudioBuffer<float>& buffer)
{
    for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
    {
        // Static
        float staticNoise = (random.nextFloat() * 2.0f - 1.0f) * radioParams.staticAmount * 0.3f;

        // Interference (modulated noise)
        static float interferencePhase = 0.0f;
        interferencePhase += radioParams.interferenceFrequency / static_cast<float>(sampleRate);
        if (interferencePhase >= 1.0f)
            interferencePhase -= 1.0f;

        float interference = std::sin(juce::MathConstants<float>::twoPi * interferencePhase);
        interference *= (random.nextFloat() * 2.0f - 1.0f) * radioParams.interferenceAmount * 0.2f;

        float totalNoise = staticNoise + interference;

        for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
        {
            buffer.addSample(channel, sample, totalNoise);
        }
    }
}

//==============================================================================
// Sample Rate / Bit Depth Reduction
//==============================================================================

void EchoelVHS::reduceSampleRate(juce::AudioBuffer<float>& buffer, int targetSampleRate)
{
    // Simplified sample rate reduction (decimation)
    int decimationFactor = static_cast<int>(sampleRate / targetSampleRate);
    if (decimationFactor < 2)
        return;

    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);

        for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
        {
            if (sample % decimationFactor != 0)
            {
                // Hold previous sample (zero-order hold)
                channelData[sample] = channelData[sample - (sample % decimationFactor)];
            }
        }
    }
}

void EchoelVHS::reduceBitDepth(juce::AudioBuffer<float>& buffer, int targetBits)
{
    float levels = std::pow(2.0f, static_cast<float>(targetBits));
    float step = 2.0f / levels;  // -1 to +1 range

    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);

        for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
        {
            // Quantize to target bit depth
            float input = channelData[sample];
            float quantized = std::round(input / step) * step;
            channelData[sample] = quantized;
        }
    }
}

//==============================================================================
// Biometric Modulation
//==============================================================================

void EchoelVHS::applyBiometricModulation(juce::AudioBuffer<float>& buffer)
{
    // Heart rate affects tape speed
    if (biometricParams.heartRateControlsSpeed)
    {
        float normalHeartRate = 70.0f;
        float speedMod = 1.0f + ((biometricParams.heartRate - normalHeartRate) / normalHeartRate) *
                                biometricParams.speedModulationDepth;

        // This would affect wow/flutter rate
        degradationParams.wowRate *= speedMod;
    }

    // Emotional state affects degradation
    if (biometricParams.emotionControlsDegradation)
    {
        // Sad/low valence = more degradation
        float degradationMod = 1.5f - biometricParams.emotionalValence;
        degradationParams.tapeAge = juce::jlimit(0.0f, 1.0f,
            degradationParams.tapeAge * degradationMod);
    }
}

void EchoelVHS::processMemories(juce::AudioBuffer<float>& buffer)
{
    // Randomly play memory samples
    if (random.nextFloat() < biometricParams.memoryPlaybackProbability && !loadedMemories.empty())
    {
        // Mix in memory audio
        // Implementation would blend loaded memory buffers
    }
}

//==============================================================================
// Factory Presets
//==============================================================================

void EchoelVHS::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::VHSTape:
            setFormat(VintageFormat::VHS);
            break;

        case Preset::CompactCassette:
            setFormat(VintageFormat::CassetteTypeII);
            break;

        case Preset::VinylRecord:
            setFormat(VintageFormat::Vinyl33);
            break;

        case Preset::LoFiHipHop:
            setFormat(VintageFormat::VaporwaveLoFi);
            vaporwaveParams.pitchShift = -100.0f;
            vaporwaveParams.targetSampleRate = 32000;
            vaporwaveParams.bitDepth = 14;
            degradationParams.wowAmount = 0.25f;
            degradationParams.hissAmount = 0.25f;
            break;

        case Preset::Vaporwave:
            setFormat(VintageFormat::VaporwaveLoFi);
            vaporwaveParams.pitchShift = -300.0f;
            vaporwaveParams.dreaminess = 0.8f;
            vaporwaveParams.nostalgia = 0.9f;
            break;

        case Preset::BrokenCassette:
            setFormat(VintageFormat::CassetteTypeI);
            degradationParams.tapeAge = 0.9f;
            degradationParams.wowAmount = 0.8f;
            degradationParams.flutterAmount = 0.7f;
            degradationParams.dropoutProbability = 0.1f;
            break;

        default:
            setFormat(VintageFormat::CassetteTypeII);
            break;
    }
}
