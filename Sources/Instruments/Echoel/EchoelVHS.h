#pragma once

#include <JuceHeader.h>
#include <vector>

/**
 * 📼 EchoelVHS - LoFi Tape Emulation & Vintage Texture Engine
 *
 * SUPER INTELLIGENCE FEATURES:
 * ============================
 *
 * 🧠 INTELLIGENT DEGRADATION
 * - ML-based tape wear simulation trained on real vintage recordings
 * - Automatic era detection (60s, 70s, 80s, 90s)
 * - Smart vinyl crackle that follows music dynamics
 * - Adaptive wow & flutter based on "tape age"
 *
 * 📼 MULTI-FORMAT EMULATION
 * - VHS tape (video recorder audio track - ultra lofi)
 * - Cassette (Type I, Type II, Type IV)
 * - Reel-to-reel (1/4", 1/2", studio quality)
 * - Vinyl (33, 45, 78 RPM with tonearm resonance)
 * - Wax cylinder (1900s phonograph)
 * - AM/FM Radio (with static and interference)
 *
 * 🎨 VAPORWAVE ENGINE
 * - Pitch-shifted nostalgia (-400 to +400 cents)
 * - Timestretching with artifacts (chopped & screwed)
 * - Automatic sample rate reduction (44.1k → 8k)
 * - Bit depth crushing (16-bit → 4-bit)
 * - Sidechain ducking to beats
 *
 * 🔊 ANALOG SATURATION
 * - Tape saturation with magnetic hysteresis
 * - Tube preamp modeling (12AX7, 6L6)
 * - Transformer coloration
 * - Bias noise and hiss generation
 *
 * ❤️ BIOMETRIC NOSTALGIA
 * - Heart rate controls tape speed (slower = more nostalgic)
 * - Emotional state affects degradation amount
 * - Memories integration: plays your uploaded vintage samples randomly
 *
 * COMPETITORS: RC-20, Izotope Vinyl, Waves J37, LoFi Hip Hop plugins
 * USP: ML degradation + VHS mode + Biometric nostalgia + Multi-era emulation
 */
class EchoelVHS
{
public:
    //==============================================================================
    EchoelVHS();
    ~EchoelVHS() = default;

    //==============================================================================
    // FORMAT EMULATION

    enum class VintageFormat {
        VHS,            // VHS tape (ultra lofi, poor frequency response)
        CassetteTypeI,  // Normal bias (ferric oxide)
        CassetteTypeII, // High bias (chrome)
        CassetteTypeIV, // Metal tape (best quality)
        ReelToReel,     // Studio reel-to-reel (high quality)
        Vinyl33,        // 33 1/3 RPM vinyl
        Vinyl45,        // 45 RPM single
        Vinyl78,        // 78 RPM shellac (pre-1950s)
        WaxCylinder,    // 1900s phonograph
        AMRadio,        // AM radio broadcast
        FMRadio,        // FM radio (better quality)
        Shortwave,      // Shortwave radio (lots of interference)
        VaporwaveLoFi   // Modern lofi hip-hop aesthetic
    };

    void setFormat(VintageFormat format);
    VintageFormat getFormat() const { return currentFormat; }

    //==============================================================================
    // INTELLIGENT DEGRADATION SYSTEM

    struct DegradationParams {
        // Tape wear (ML-generated based on "age")
        float tapeAge = 0.5f;           // 0.0 = new, 1.0 = ancient
        float wearAmount = 0.5f;        // Physical wear intensity
        bool enableMLWear = true;       // Use ML model for realistic wear

        // Frequency response
        float bassRolloff = 100.0f;     // Hz (low-end loss)
        float trebleRolloff = 8000.0f;  // Hz (high-end loss)
        float midBoost = 0.0f;          // dB @ 1kHz (tape emphasis)

        // Wow & Flutter (pitch instability)
        float wowAmount = 0.3f;         // 0.0 - 1.0 (slow pitch drift)
        float wowRate = 0.5f;           // Hz (0.1 - 2 Hz typical)
        float flutterAmount = 0.2f;     // 0.0 - 1.0 (fast pitch variations)
        float flutterRate = 5.0f;       // Hz (5 - 15 Hz typical)

        // Dropouts (tape damage)
        float dropoutProbability = 0.01f;  // Probability per second
        float dropoutDuration = 0.05f;     // Seconds

        // Saturation
        float tapeHarmonics = 0.5f;     // Harmonic distortion
        float compressionAmount = 0.3f;  // Tape compression

        // Noise
        float hissAmount = 0.3f;        // Tape hiss
        float hum50Hz = 0.0f;           // AC hum (50 Hz Europe)
        float hum60Hz = 0.0f;           // AC hum (60 Hz USA)
    };

    void setDegradationParams(const DegradationParams& params);
    DegradationParams getDegradationParams() const { return degradationParams; }

    //==============================================================================
    // VINYL-SPECIFIC CONTROLS

    struct VinylParams {
        // RPM
        float rpm = 33.33f;             // 33.33, 45, 78

        // Tonearm physics
        float tonearmResonance = 8.0f;  // Hz (typical 8-12 Hz)
        float trackingForce = 1.5f;     // Grams
        float antiSkate = 1.0f;         // Anti-skating force

        // Surface noise
        float crackleAmount = 0.3f;
        float crackleDensity = 0.5f;    // How many pops
        float dustAmount = 0.2f;        // Light surface noise
        float scratchAmount = 0.0f;     // Deep scratches

        // Groove wear
        float innerGrooveDistortion = 0.3f;  // Near label distortion
        float centerHoleWobble = 0.0f;       // Off-center pressing

        // RIAA curve
        bool applyRIAA = true;          // Standard phono EQ curve
    };

    void setVinylParams(const VinylParams& params);
    VinylParams getVinylParams() const { return vinylParams; }

    //==============================================================================
    // VAPORWAVE / LOFI HIP-HOP ENGINE

    struct VaporwaveParams {
        // Pitch manipulation
        float pitchShift = -200.0f;     // Cents (slowed down vibe)
        float pitchDrift = 0.1f;        // Random pitch instability

        // Time manipulation
        float timeStretch = 0.8f;       // 0.5 - 2.0 (chopped & screwed)
        bool preserveFormants = false;  // Keep voice natural

        // Sample rate reduction
        int targetSampleRate = 22050;   // Hz (44100 → 8000 for extreme lofi)

        // Bit depth
        int bitDepth = 12;              // 4 - 16 bits

        // Sidechain ducking
        bool enableSidechain = true;
        float sidechainAmount = 0.5f;
        float sidechainRelease = 0.3f;  // Seconds

        // Aesthetic controls
        float nostalgia = 0.7f;         // Overall "vintage" amount
        float dreaminess = 0.5f;        // Reverb + filtering
        float glitchiness = 0.2f;       // Random stutters and repeats
    };

    void setVaporwaveParams(const VaporwaveParams& params);
    VaporwaveParams getVaporwaveParams() const { return vaporwaveParams; }

    //==============================================================================
    // ANALOG SATURATION & COLORATION

    struct AnalogParams {
        // Tape saturation
        enum SaturationModel {
            Clean,          // Minimal saturation
            Vintage,        // Classic tape warmth
            OverBiased,     // Pushed tape (more compression)
            UnderBiased,    // Thin, distorted
            Custom
        } saturationModel = Vintage;

        float inputGain = 0.0f;         // dB drive
        float saturationAmount = 0.5f;  // 0.0 - 1.0

        // Tube preamp
        bool enableTubePreamp = false;
        enum TubeType {
            TwelveAX7,      // Common preamp tube
            SixL6,          // Power tube (more aggressive)
            ECC83,          // European 12AX7
            SixV6           // Lower gain
        } tubeType = TwelveAX7;

        float tubeDrive = 0.3f;
        float tubeBias = 0.5f;

        // Transformer
        bool enableTransformer = true;
        float transformerSaturation = 0.2f;
        float transformerHysteresis = 0.3f;  // Magnetic hysteresis

        // Output
        float outputGain = 0.0f;        // dB makeup gain
    };

    void setAnalogParams(const AnalogParams& params);
    AnalogParams getAnalogParams() const { return analogParams; }

    //==============================================================================
    // RADIO EMULATION

    struct RadioParams {
        // Station tuning
        float frequency = 100.0f;       // MHz (FM) or kHz (AM)
        float tuningDrift = 0.1f;       // Station drift
        float signalStrength = 0.7f;    // 0.0 - 1.0

        // Interference
        float staticAmount = 0.3f;      // White noise
        float interferenceAmount = 0.2f; // Adjacent station bleed
        int interferenceFrequency = 50; // Hz modulation

        // Bandpass filtering
        float lowCut = 300.0f;          // Hz (AM typically 300-3000 Hz)
        float highCut = 3000.0f;        // Hz

        // Multi-path distortion (FM)
        float multiPathAmount = 0.0f;   // Phase cancellation
    };

    void setRadioParams(const RadioParams& params);
    RadioParams getRadioParams() const { return radioParams; }

    //==============================================================================
    // BIOMETRIC NOSTALGIA ENGINE

    struct BiometricNostalgiaParams {
        bool enabled = false;

        // Heart rate affects tape speed
        float heartRate = 70.0f;
        bool heartRateControlsSpeed = true;
        float speedModulationDepth = 0.2f;  // How much HR affects speed

        // Emotional state
        float emotionalValence = 0.5f;      // 0.0 = sad, 1.0 = happy
        float emotionalArousal = 0.5f;      // 0.0 = calm, 1.0 = excited

        bool emotionControlsDegradation = true;
        // Sad/melancholic = more degradation
        // Happy/excited = cleaner sound

        // Memory integration
        bool enableMemories = false;
        std::vector<juce::File> memoryAudioFiles;  // User's vintage samples
        float memoryPlaybackProbability = 0.05f;   // 5% chance per measure
        float memoryMixAmount = 0.2f;              // Blend amount
    };

    void setBiometricNostalgiaParams(const BiometricNostalgiaParams& params);
    BiometricNostalgiaParams getBiometricNostalgiaParams() const { return biometricParams; }

    void addMemory(const juce::File& audioFile);
    void clearMemories();

    //==============================================================================
    // MACHINE LEARNING - Degradation Model

    struct MLDegradationModel {
        bool loaded = false;

        // Trained on thousands of vintage recordings
        void predictWearPattern(float age, std::vector<float>& frequencyResponse);
        void generateRealisticCrackle(float density, juce::AudioBuffer<float>& output);
        void detectEra(const juce::AudioBuffer<float>& input, int& estimatedYear);
    };

    void loadMLModel(const std::string& modelPath);
    bool isMLModelLoaded() const { return mlModel.loaded; }

    //==============================================================================
    // FACTORY PRESETS

    enum class Preset {
        // Classic formats
        VHSTape,
        CompactCassette,
        VinylRecord,
        ReelToReelStudio,

        // Eras
        Sixties,
        Seventies,
        Eighties,
        Nineties,

        // Genres
        LoFiHipHop,
        Vaporwave,
        Synthwave,
        ChillHop,

        // Extreme
        AncientPhonograph,
        BrokenCassette,
        StaticRadio,
        UnderwaterVHS,

        // Biometric
        NostalgicMemories,
        EmotionalTape,
        HeartbeatWobble
    };

    void loadPreset(Preset preset);

    //==============================================================================
    // AUDIO PROCESSING

    void prepare(double sampleRate, int samplesPerBlock, int numChannels);
    void processBlock(juce::AudioBuffer<float>& buffer);
    void reset();

private:
    //==============================================================================
    // State
    VintageFormat currentFormat = VintageFormat::CassetteTypeII;

    DegradationParams degradationParams;
    VinylParams vinylParams;
    VaporwaveParams vaporwaveParams;
    AnalogParams analogParams;
    RadioParams radioParams;
    BiometricNostalgiaParams biometricParams;

    MLDegradationModel mlModel;

    double sampleRate = 44100.0;

    //==============================================================================
    // DSP Components

    // Wow & Flutter LFOs
    float wowPhase = 0.0f;
    float flutterPhase = 0.0f;

    // Pitch shifting buffer (for wow/flutter)
    std::vector<float> pitchBuffer;
    int pitchWritePos = 0;

    // Vinyl crackle generator
    struct CrackleGenerator {
        float crackleDensity = 0.3f;
        float nextCrackleTime = 0.0f;
        void generate(juce::AudioBuffer<float>& buffer, int numSamples);
    };
    CrackleGenerator crackleGen;

    // Noise generators
    juce::Random random;
    float generateHiss();
    float generateHum(float frequency);
    float generateCrackle();

    // Saturation
    float tapeNonlinearity(float input, float amount);
    float tubeDistortion(float input, AnalogParams::TubeType type, float drive);

    // Filters
    juce::dsp::IIR::Filter<float> bassRolloffFilter;
    juce::dsp::IIR::Filter<float> trebleRolloffFilter;
    juce::dsp::IIR::Filter<float> riaaFilter;

    // Sample rate converter (for lofi effect)
    void reduceSampleRate(juce::AudioBuffer<float>& buffer, int targetSampleRate);
    void reduceBitDepth(juce::AudioBuffer<float>& buffer, int targetBits);

    // Memory playback
    std::vector<juce::AudioBuffer<float>> loadedMemories;
    int currentMemoryIndex = 0;
    int memoryPlaybackPos = 0;
    void processMemories(juce::AudioBuffer<float>& buffer);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelVHS)
};
