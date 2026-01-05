#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <map>
#include <cmath>

/**
 * BioModulator - JUCE C++ Biofeedback to Audio Modulation
 *
 * Real-time mapping of biometric signals to:
 * - BPM/Tempo control
 * - Effects parameters (EFX)
 * - Instrument modulation
 * - Laser/DMX control
 *
 * Supports HRV, heart rate, breathing, coherence, GSR
 *
 * JUCE 7+ Compatible - 2026-01-05
 */
namespace Echoelmusic {

//==============================================================================
// Biometric Data Structure
//==============================================================================

struct BiometricData
{
    float heartRate = 70.0f;          // BPM (40-200)
    float hrvMs = 50.0f;              // HRV in milliseconds (10-150)
    float coherence = 0.5f;           // HRV coherence (0.0-1.0)
    float breathingRate = 12.0f;      // Breaths per minute (4-30)
    float breathPhase = 0.5f;         // Inhale/exhale phase (0.0-1.0)
    float skinConductance = 0.5f;     // GSR/EDA normalized (0.0-1.0)
    float bodyTemperature = 37.0f;    // Celsius
    float oxygenSaturation = 98.0f;   // SpO2 percentage
};

//==============================================================================
// Modulation Targets
//==============================================================================

enum class BioSource
{
    HeartRate,
    HRV,
    Coherence,
    BreathingRate,
    BreathPhase,
    SkinConductance,
    BodyTemperature,
    OxygenSaturation
};

enum class ModulationTarget
{
    // BPM
    GlobalTempo,
    SequencerTempo,
    DelaySync,
    LFORate,
    GrainDensity,

    // EFX - Dynamics
    CompressorThreshold,
    CompressorRatio,
    GateThreshold,

    // EFX - Filter
    FilterCutoff,
    FilterResonance,
    FilterEnvAmount,
    DynamicEQThreshold,

    // EFX - Time
    ReverbSize,
    ReverbDecay,
    ReverbMix,
    DelayTime,
    DelayFeedback,
    DelayMix,

    // EFX - Modulation
    ChorusDepth,
    ChorusRate,
    FlangerDepth,
    PhaserRate,

    // EFX - Distortion
    DriveAmount,
    BitDepth,

    // EFX - Spatial
    StereoWidth,
    PanPosition,
    SpatialDistance,
    SpatialAzimuth,

    // EFX - Special
    SpectralMorph,
    GranularPosition,
    ShimmerAmount,

    // Instrument - Oscillator
    OscPitch,
    OscDetune,
    OscPulseWidth,
    WavetablePosition,
    FMAmount,

    // Instrument - Filter
    SynthFilterCutoff,
    SynthFilterRes,
    SynthFilterEnv,

    // Instrument - Amp
    AmpAttack,
    AmpDecay,
    AmpSustain,
    AmpRelease,

    // Instrument - Modulation
    LFOAmount,
    EnvModAmount,
    ModWheel,

    // Laser/DMX
    LaserIntensity,
    LaserScanSpeed,
    LaserColor,
    LaserPattern,
    DMXMaster,
    DMXStrobe,

    NumTargets
};

//==============================================================================
// Mapping Curve
//==============================================================================

enum class MappingCurve
{
    Linear,
    Exponential,
    Logarithmic,
    SCurve,
    Inverted,
    Sine,
    Stepped
};

//==============================================================================
// Modulation Mapping
//==============================================================================

struct ModulationMapping
{
    BioSource source = BioSource::HeartRate;
    ModulationTarget target = ModulationTarget::FilterCutoff;
    float amount = 1.0f;           // -1.0 to 1.0
    MappingCurve curve = MappingCurve::Linear;
    float smoothingMs = 50.0f;     // Smoothing time
    float minInput = 0.0f;
    float maxInput = 1.0f;
    float minOutput = 0.0f;
    float maxOutput = 1.0f;
    bool enabled = true;
    bool bipolar = false;          // For pitch bend style modulation

    ModulationMapping() = default;

    ModulationMapping(BioSource src, ModulationTarget tgt, float amt = 1.0f)
        : source(src), target(tgt), amount(amt) {}
};

//==============================================================================
// BioModulator Class
//==============================================================================

class BioModulator
{
public:
    //==========================================================================
    BioModulator();
    ~BioModulator() = default;

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

    /** Process modulations - call at control rate (e.g., 60 Hz) */
    void process();

    //==========================================================================
    // Biometric Input
    //==========================================================================

    void setBioData(const BiometricData& data);
    void setHeartRate(float bpm);
    void setHRV(float ms);
    void setCoherence(float value);
    void setBreathPhase(float phase);
    void setBreathingRate(float rate);
    void setSkinConductance(float value);

    const BiometricData& getBioData() const { return bioData; }

    //==========================================================================
    // Mapping Management
    //==========================================================================

    void addMapping(const ModulationMapping& mapping);
    void removeMapping(size_t index);
    void clearMappings();
    void setMappingEnabled(size_t index, bool enabled);

    size_t getNumMappings() const { return mappings.size(); }
    ModulationMapping& getMapping(size_t index) { return mappings[index]; }

    //==========================================================================
    // Output
    //==========================================================================

    /** Get modulation value for target (0.0 to 1.0) */
    float getModulation(ModulationTarget target) const;

    /** Get modulated BPM */
    float getModulatedBPM() const { return modulatedBPM; }

    /** Get all modulation outputs */
    const std::array<float, static_cast<size_t>(ModulationTarget::NumTargets)>&
    getAllModulations() const { return modulationOutputs; }

    //==========================================================================
    // MIDI Output
    //==========================================================================

    /** Get modulation as MIDI CC (0-127) */
    juce::uint8 getMidiCC(ModulationTarget target) const;

    /** Get modulation as MIDI pitch bend (-8192 to 8191) */
    int getMidiPitchBend(ModulationTarget target) const;

    //==========================================================================
    // Laser/DMX Output
    //==========================================================================

    /** Get laser intensity (0.0-1.0) */
    float getLaserIntensity() const { return getModulation(ModulationTarget::LaserIntensity); }

    /** Get laser scan speed (0.0-1.0) */
    float getLaserScanSpeed() const { return getModulation(ModulationTarget::LaserScanSpeed); }

    /** Get laser color as RGB (0-255 each) */
    std::array<juce::uint8, 3> getLaserColorRGB() const;

    /** Get DMX channel value (0-255) */
    juce::uint8 getDMXChannel(int channel) const;

    //==========================================================================
    // Configuration
    //==========================================================================

    void setBaseBPM(float bpm) { baseBPM = bpm; }
    float getBaseBPM() const { return baseBPM; }

    void setBPMRange(float min, float max) { minBPM = min; maxBPM = max; }

    void setReactivityLevel(float level) { reactivityLevel = juce::jlimit(0.0f, 1.0f, level); }
    float getReactivityLevel() const { return reactivityLevel; }

    void setGlobalSmoothing(float ms) { globalSmoothingMs = ms; }

    void setActive(bool active) { isActive = active; }
    bool getActive() const { return isActive; }

    //==========================================================================
    // Presets
    //==========================================================================

    void loadMeditationPreset();
    void loadEnergeticPreset();
    void loadAmbientPreset();
    void loadLaserShowPreset();

private:
    //==========================================================================
    // Internal Methods
    //==========================================================================

    float getBioValue(BioSource source) const;
    float applyCurve(float input, MappingCurve curve) const;
    float applySmoothing(float current, float previous, float smoothingMs) const;
    void calculateModulatedBPM();

    //==========================================================================
    // Member Variables
    //==========================================================================

    BiometricData bioData;
    std::vector<ModulationMapping> mappings;

    std::array<float, static_cast<size_t>(ModulationTarget::NumTargets)> modulationOutputs;
    std::array<float, static_cast<size_t>(ModulationTarget::NumTargets)> smoothedValues;

    float modulatedBPM = 120.0f;
    float baseBPM = 120.0f;
    float minBPM = 60.0f;
    float maxBPM = 180.0f;

    float reactivityLevel = 1.0f;
    float globalSmoothingMs = 50.0f;

    double currentSampleRate = 48000.0;
    float updateInterval = 1.0f / 60.0f;  // 60 Hz control rate

    bool isActive = false;

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (BioModulator)
};

} // namespace Echoelmusic
