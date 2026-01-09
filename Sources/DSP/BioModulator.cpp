#include "BioModulator.h"

namespace Echoelmusic {

//==============================================================================
// Constructor
//==============================================================================

BioModulator::BioModulator()
{
    modulationOutputs.fill(0.0f);
    smoothedValues.fill(0.0f);
    loadMeditationPreset();  // Default preset
}

//==============================================================================
// Processing
//==============================================================================

void BioModulator::prepare(double sampleRate, int maxBlockSize)
{
    juce::ignoreUnused(maxBlockSize);
    currentSampleRate = sampleRate;
    reset();
}

void BioModulator::reset()
{
    modulationOutputs.fill(0.0f);
    smoothedValues.fill(0.5f);  // Start at center
    modulatedBPM = baseBPM;
}

void BioModulator::process()
{
    if (!isActive)
        return;

    // Reset outputs
    modulationOutputs.fill(0.0f);

    // Track contributions per target for averaging
    std::array<int, static_cast<size_t>(ModulationTarget::NumTargets)> contributions;
    contributions.fill(0);

    // Process each mapping
    for (const auto& mapping : mappings)
    {
        if (!mapping.enabled)
            continue;

        // Get input value
        float inputValue = getBioValue(mapping.source);

        // Normalize to 0-1
        float normalized = (inputValue - mapping.minInput) /
                          (mapping.maxInput - mapping.minInput + 0.0001f);
        normalized = juce::jlimit(0.0f, 1.0f, normalized);

        // Apply curve
        float curved = applyCurve(normalized, mapping.curve);

        // Apply amount and reactivity
        float modulated = curved * mapping.amount * reactivityLevel;

        // Handle bipolar modulation
        if (mapping.bipolar)
        {
            modulated = (modulated - 0.5f) * 2.0f;  // -1 to 1
        }

        // Map to output range
        float output = mapping.minOutput + modulated * (mapping.maxOutput - mapping.minOutput);

        // Apply smoothing
        size_t targetIndex = static_cast<size_t>(mapping.target);
        float smoothed = applySmoothing(
            output,
            smoothedValues[targetIndex],
            mapping.smoothingMs > 0 ? mapping.smoothingMs : globalSmoothingMs
        );
        smoothedValues[targetIndex] = smoothed;

        // Accumulate output (for multiple mappings to same target)
        modulationOutputs[targetIndex] += smoothed;
        contributions[targetIndex]++;
    }

    // Average outputs where multiple mappings exist
    for (size_t i = 0; i < modulationOutputs.size(); ++i)
    {
        if (contributions[i] > 1)
        {
            modulationOutputs[i] /= static_cast<float>(contributions[i]);
        }
    }

    // Calculate final BPM
    calculateModulatedBPM();
}

//==============================================================================
// Biometric Input
//==============================================================================

void BioModulator::setBioData(const BiometricData& data)
{
    bioData = data;
}

void BioModulator::setHeartRate(float bpm)
{
    bioData.heartRate = juce::jlimit(40.0f, 200.0f, bpm);
}

void BioModulator::setHRV(float ms)
{
    bioData.hrvMs = juce::jlimit(10.0f, 150.0f, ms);
}

void BioModulator::setCoherence(float value)
{
    bioData.coherence = juce::jlimit(0.0f, 1.0f, value);
}

void BioModulator::setBreathPhase(float phase)
{
    bioData.breathPhase = juce::jlimit(0.0f, 1.0f, phase);
}

void BioModulator::setBreathingRate(float rate)
{
    bioData.breathingRate = juce::jlimit(4.0f, 30.0f, rate);
}

void BioModulator::setSkinConductance(float value)
{
    bioData.skinConductance = juce::jlimit(0.0f, 1.0f, value);
}

//==============================================================================
// Mapping Management
//==============================================================================

void BioModulator::addMapping(const ModulationMapping& mapping)
{
    mappings.push_back(mapping);
}

void BioModulator::removeMapping(size_t index)
{
    if (index < mappings.size())
        mappings.erase(mappings.begin() + static_cast<long>(index));
}

void BioModulator::clearMappings()
{
    mappings.clear();
}

void BioModulator::setMappingEnabled(size_t index, bool enabled)
{
    if (index < mappings.size())
        mappings[index].enabled = enabled;
}

//==============================================================================
// Output
//==============================================================================

float BioModulator::getModulation(ModulationTarget target) const
{
    return modulationOutputs[static_cast<size_t>(target)];
}

juce::uint8 BioModulator::getMidiCC(ModulationTarget target) const
{
    float value = getModulation(target);
    return static_cast<juce::uint8>(juce::jlimit(0.0f, 127.0f, value * 127.0f));
}

int BioModulator::getMidiPitchBend(ModulationTarget target) const
{
    float value = getModulation(target);
    float normalized = (value - 0.5f) * 2.0f;  // -1 to 1
    return static_cast<int>(normalized * 8191.0f);
}

std::array<juce::uint8, 3> BioModulator::getLaserColorRGB() const
{
    float colorValue = getModulation(ModulationTarget::LaserColor);

    // Map to HSV hue, then to RGB
    float hue = colorValue * 360.0f;
    float saturation = 1.0f;
    float brightness = getModulation(ModulationTarget::LaserIntensity);

    // HSV to RGB conversion
    float h = hue / 60.0f;
    int i = static_cast<int>(h);
    float f = h - i;
    float p = brightness * (1.0f - saturation);
    float q = brightness * (1.0f - saturation * f);
    float t = brightness * (1.0f - saturation * (1.0f - f));

    float r, g, b;
    switch (i % 6)
    {
        case 0: r = brightness; g = t; b = p; break;
        case 1: r = q; g = brightness; b = p; break;
        case 2: r = p; g = brightness; b = t; break;
        case 3: r = p; g = q; b = brightness; break;
        case 4: r = t; g = p; b = brightness; break;
        default: r = brightness; g = p; b = q; break;
    }

    return {{
        static_cast<juce::uint8>(r * 255.0f),
        static_cast<juce::uint8>(g * 255.0f),
        static_cast<juce::uint8>(b * 255.0f)
    }};
}

juce::uint8 BioModulator::getDMXChannel(int channel) const
{
    // Map channels to modulation targets
    switch (channel)
    {
        case 0: return static_cast<juce::uint8>(getModulation(ModulationTarget::DMXMaster) * 255.0f);
        case 1: return static_cast<juce::uint8>(getModulation(ModulationTarget::LaserIntensity) * 255.0f);
        case 2: return static_cast<juce::uint8>(getModulation(ModulationTarget::LaserScanSpeed) * 255.0f);
        case 3: return getLaserColorRGB()[0];  // R
        case 4: return getLaserColorRGB()[1];  // G
        case 5: return getLaserColorRGB()[2];  // B
        case 6: return static_cast<juce::uint8>(getModulation(ModulationTarget::DMXStrobe) * 255.0f);
        default: return 0;
    }
}

//==============================================================================
// Internal Methods
//==============================================================================

float BioModulator::getBioValue(BioSource source) const
{
    switch (source)
    {
        case BioSource::HeartRate:       return bioData.heartRate;
        case BioSource::HRV:             return bioData.hrvMs;
        case BioSource::Coherence:       return bioData.coherence;
        case BioSource::BreathingRate:   return bioData.breathingRate;
        case BioSource::BreathPhase:     return bioData.breathPhase;
        case BioSource::SkinConductance: return bioData.skinConductance;
        case BioSource::BodyTemperature: return bioData.bodyTemperature;
        case BioSource::OxygenSaturation: return bioData.oxygenSaturation;
        default: return 0.5f;
    }
}

float BioModulator::applyCurve(float input, MappingCurve curve) const
{
    float clamped = juce::jlimit(0.0f, 1.0f, input);

    switch (curve)
    {
        case MappingCurve::Linear:
            return clamped;

        case MappingCurve::Exponential:
            return clamped * clamped;

        case MappingCurve::Logarithmic:
            return std::sqrt(clamped);

        case MappingCurve::SCurve:
            return clamped * clamped * (3.0f - 2.0f * clamped);

        case MappingCurve::Inverted:
            return 1.0f - clamped;

        case MappingCurve::Sine:
            return (std::sin((clamped - 0.5f) * juce::MathConstants<float>::pi) + 1.0f) * 0.5f;

        case MappingCurve::Stepped:
            return std::floor(clamped * 8.0f) / 8.0f;

        default:
            return clamped;
    }
}

float BioModulator::applySmoothing(float current, float previous, float smoothingMs) const
{
    if (smoothingMs <= 0.0f)
        return current;

    float smoothingFactor = 1.0f - std::exp(-updateInterval * 1000.0f / std::max(1.0f, smoothingMs));
    return previous + (current - previous) * smoothingFactor;
}

void BioModulator::calculateModulatedBPM()
{
    // Get BPM-related modulations
    float tempoMod = getModulation(ModulationTarget::GlobalTempo);
    float seqMod = getModulation(ModulationTarget::SequencerTempo);

    // Average tempo modulations
    float avgMod = (tempoMod + seqMod) * 0.5f;

    if (avgMod > 0.0f)
    {
        // Map modulation to BPM range
        modulatedBPM = minBPM + avgMod * (maxBPM - minBPM);
    }
    else
    {
        modulatedBPM = baseBPM;
    }

    modulatedBPM = juce::jlimit(minBPM, maxBPM, modulatedBPM);
}

//==============================================================================
// Presets
//==============================================================================

void BioModulator::loadMeditationPreset()
{
    clearMappings();

    baseBPM = 60.0f;
    minBPM = 40.0f;
    maxBPM = 80.0f;
    reactivityLevel = 0.7f;

    // Breath → Filter sweep
    ModulationMapping breathFilter;
    breathFilter.source = BioSource::BreathPhase;
    breathFilter.target = ModulationTarget::FilterCutoff;
    breathFilter.amount = 0.8f;
    breathFilter.curve = MappingCurve::Sine;
    breathFilter.smoothingMs = 50.0f;
    addMapping(breathFilter);

    // Coherence → Reverb
    ModulationMapping cohReverb;
    cohReverb.source = BioSource::Coherence;
    cohReverb.target = ModulationTarget::ReverbSize;
    cohReverb.amount = 0.9f;
    cohReverb.curve = MappingCurve::Exponential;
    cohReverb.smoothingMs = 1000.0f;
    addMapping(cohReverb);

    // HRV → Tempo
    ModulationMapping hrvTempo;
    hrvTempo.source = BioSource::HRV;
    hrvTempo.target = ModulationTarget::GlobalTempo;
    hrvTempo.amount = 0.3f;
    hrvTempo.curve = MappingCurve::Logarithmic;
    hrvTempo.smoothingMs = 500.0f;
    hrvTempo.minInput = 30.0f;
    hrvTempo.maxInput = 100.0f;
    hrvTempo.minOutput = 0.0f;
    hrvTempo.maxOutput = 1.0f;
    addMapping(hrvTempo);

    // Coherence → Shimmer
    ModulationMapping cohShimmer;
    cohShimmer.source = BioSource::Coherence;
    cohShimmer.target = ModulationTarget::ShimmerAmount;
    cohShimmer.amount = 0.7f;
    cohShimmer.curve = MappingCurve::SCurve;
    cohShimmer.smoothingMs = 500.0f;
    addMapping(cohShimmer);
}

void BioModulator::loadEnergeticPreset()
{
    clearMappings();

    baseBPM = 128.0f;
    minBPM = 100.0f;
    maxBPM = 160.0f;
    reactivityLevel = 1.0f;

    // Heart rate → Tempo
    ModulationMapping hrTempo;
    hrTempo.source = BioSource::HeartRate;
    hrTempo.target = ModulationTarget::GlobalTempo;
    hrTempo.amount = 1.0f;
    hrTempo.curve = MappingCurve::Linear;
    hrTempo.smoothingMs = 100.0f;
    hrTempo.minInput = 80.0f;
    hrTempo.maxInput = 150.0f;
    addMapping(hrTempo);

    // GSR → Distortion
    ModulationMapping gsrDrive;
    gsrDrive.source = BioSource::SkinConductance;
    gsrDrive.target = ModulationTarget::DriveAmount;
    gsrDrive.amount = 0.8f;
    gsrDrive.curve = MappingCurve::Exponential;
    gsrDrive.smoothingMs = 50.0f;
    addMapping(gsrDrive);

    // Breath → Filter
    ModulationMapping breathFilter;
    breathFilter.source = BioSource::BreathPhase;
    breathFilter.target = ModulationTarget::SynthFilterCutoff;
    breathFilter.amount = 1.0f;
    breathFilter.curve = MappingCurve::Sine;
    breathFilter.smoothingMs = 10.0f;
    addMapping(breathFilter);

    // Heart rate → LFO
    ModulationMapping hrLfo;
    hrLfo.source = BioSource::HeartRate;
    hrLfo.target = ModulationTarget::LFORate;
    hrLfo.amount = 0.6f;
    hrLfo.curve = MappingCurve::Linear;
    hrLfo.smoothingMs = 200.0f;
    hrLfo.minInput = 60.0f;
    hrLfo.maxInput = 120.0f;
    addMapping(hrLfo);
}

void BioModulator::loadAmbientPreset()
{
    clearMappings();

    baseBPM = 70.0f;
    minBPM = 50.0f;
    maxBPM = 90.0f;
    reactivityLevel = 0.5f;

    // Breath → Spectral morph
    ModulationMapping breathMorph;
    breathMorph.source = BioSource::BreathPhase;
    breathMorph.target = ModulationTarget::SpectralMorph;
    breathMorph.amount = 0.9f;
    breathMorph.curve = MappingCurve::SCurve;
    breathMorph.smoothingMs = 200.0f;
    addMapping(breathMorph);

    // Coherence → Wavetable
    ModulationMapping cohWave;
    cohWave.source = BioSource::Coherence;
    cohWave.target = ModulationTarget::WavetablePosition;
    cohWave.amount = 0.7f;
    cohWave.curve = MappingCurve::Linear;
    cohWave.smoothingMs = 500.0f;
    addMapping(cohWave);

    // HRV → Release time
    ModulationMapping hrvRelease;
    hrvRelease.source = BioSource::HRV;
    hrvRelease.target = ModulationTarget::AmpRelease;
    hrvRelease.amount = 0.6f;
    hrvRelease.curve = MappingCurve::Logarithmic;
    hrvRelease.smoothingMs = 500.0f;
    hrvRelease.minOutput = 0.1f;
    hrvRelease.maxOutput = 1.0f;
    addMapping(hrvRelease);

    // Coherence → Reverb decay
    ModulationMapping cohDecay;
    cohDecay.source = BioSource::Coherence;
    cohDecay.target = ModulationTarget::ReverbDecay;
    cohDecay.amount = 0.8f;
    cohDecay.curve = MappingCurve::Exponential;
    cohDecay.smoothingMs = 1000.0f;
    addMapping(cohDecay);

    // Breath → Granular position
    ModulationMapping breathGrain;
    breathGrain.source = BioSource::BreathPhase;
    breathGrain.target = ModulationTarget::GranularPosition;
    breathGrain.amount = 0.5f;
    breathGrain.curve = MappingCurve::Sine;
    breathGrain.smoothingMs = 100.0f;
    addMapping(breathGrain);
}

void BioModulator::loadLaserShowPreset()
{
    clearMappings();

    baseBPM = 130.0f;
    minBPM = 110.0f;
    maxBPM = 150.0f;
    reactivityLevel = 1.0f;

    // Heart rate → Laser intensity
    ModulationMapping hrIntensity;
    hrIntensity.source = BioSource::HeartRate;
    hrIntensity.target = ModulationTarget::LaserIntensity;
    hrIntensity.amount = 1.0f;
    hrIntensity.curve = MappingCurve::Exponential;
    hrIntensity.smoothingMs = 30.0f;
    hrIntensity.minInput = 60.0f;
    hrIntensity.maxInput = 140.0f;
    addMapping(hrIntensity);

    // Breath → Scan speed
    ModulationMapping breathScan;
    breathScan.source = BioSource::BreathPhase;
    breathScan.target = ModulationTarget::LaserScanSpeed;
    breathScan.amount = 0.8f;
    breathScan.curve = MappingCurve::Sine;
    breathScan.smoothingMs = 20.0f;
    addMapping(breathScan);

    // Coherence → Color
    ModulationMapping cohColor;
    cohColor.source = BioSource::Coherence;
    cohColor.target = ModulationTarget::LaserColor;
    cohColor.amount = 1.0f;
    cohColor.curve = MappingCurve::Linear;
    cohColor.smoothingMs = 100.0f;
    addMapping(cohColor);

    // GSR → Strobe
    ModulationMapping gsrStrobe;
    gsrStrobe.source = BioSource::SkinConductance;
    gsrStrobe.target = ModulationTarget::DMXStrobe;
    gsrStrobe.amount = 0.7f;
    gsrStrobe.curve = MappingCurve::Stepped;
    gsrStrobe.smoothingMs = 10.0f;
    addMapping(gsrStrobe);

    // HRV → Pattern
    ModulationMapping hrvPattern;
    hrvPattern.source = BioSource::HRV;
    hrvPattern.target = ModulationTarget::LaserPattern;
    hrvPattern.amount = 0.6f;
    hrvPattern.curve = MappingCurve::Stepped;
    hrvPattern.smoothingMs = 500.0f;
    hrvPattern.minInput = 20.0f;
    hrvPattern.maxInput = 100.0f;
    addMapping(hrvPattern);

    // Coherence → DMX Master
    ModulationMapping cohMaster;
    cohMaster.source = BioSource::Coherence;
    cohMaster.target = ModulationTarget::DMXMaster;
    cohMaster.amount = 0.9f;
    cohMaster.curve = MappingCurve::SCurve;
    cohMaster.smoothingMs = 200.0f;
    addMapping(cohMaster);
}

} // namespace Echoelmusic
