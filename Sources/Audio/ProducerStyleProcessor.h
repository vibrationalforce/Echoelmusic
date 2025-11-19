#pragma once

#include <JuceHeader.h>

/**
 * ProducerStyleProcessor - Transform Samples with Legendary Producer Signatures
 *
 * HIGH-END AUDIO PROCESSING inspired by the greatest producers:
 *
 * HIP-HOP/TRAP LEGENDS:
 * - Southside, 808 Mafia, Pyrex Whippa: Hard-hitting 808s, saturation, punch
 * - Metro Boomin, Turbo: Modern trap, wide stereo, sub bass focus
 * - Gunna: Melodic, atmospheric, heavy reverb
 *
 * LEGENDARY PRODUCERS:
 * - Dr. Dre: West Coast punch, analog warmth, vintage gear emulation
 * - Scott Storch: Keyboard warmth, vinyl character, organic sound
 * - Timbaland: Creative pitch shifts, vocal manipulation, unique rhythms
 * - Pharrell Williams: Minimalist clarity, space, groove
 * - Rick Rubin: Raw, uncompressed, natural dynamics
 *
 * TECHNO/HOUSE MASTERS:
 * - Andrey Pushkarev: Deep, atmospheric, analog warmth
 * - Lawrence (Dial Records): Organic techno, tape saturation, depth
 * - Pantha du Prince: Bell-like tones, reverb spaces, melodic techno
 *
 * EXPERIMENTAL/IDM:
 * - Nils Frahm: Piano processing, tape delays, vintage gear
 * - Aphex Twin: Granular madness, bit crushing, creative chaos
 *
 * UK BASS/DUBSTEP:
 * - General Levy: Jungle vibes, breakbeat processing
 * - Skream: Dubstep wobbles, sub bass, FM synthesis
 *
 * Soundqualität dieser Vorbilder = ECHOELMUSIC STANDARD ✨
 *
 * Usage:
 * ```cpp
 * ProducerStyleProcessor processor;
 *
 * // Load high-res WAV (24-bit, 96kHz)
 * auto audio = processor.loadHighResAudio("kick.wav");
 *
 * // Apply 808 Mafia style
 * auto result = processor.processWithStyle(audio,
 *     ProducerStyleProcessor::Style::Mafia808);
 *
 * // Export optimized for Echoelmusic Audio Engine
 * processor.exportForEngine(result, "kick_mafia.wav");
 * ```
 */
class ProducerStyleProcessor
{
public:
    //==========================================================================
    // Producer Style Presets
    //==========================================================================

    enum class ProducerStyle
    {
        // HIP-HOP/TRAP
        Mafia808,               // Southside, 808 Mafia - Hard-hitting 808s
        MetroBoomin,            // Metro Boomin - Modern trap, wide stereo
        Pyrex,                  // Pyrex Whippa - Aggressive, punchy
        Gunna,                  // Gunna - Melodic, atmospheric
        Turbo,                  // Turbo - Clean, modern trap

        // LEGENDARY PRODUCERS
        DrDre,                  // Dr. Dre - West Coast punch, analog warmth
        ScottStorch,            // Scott Storch - Keyboard warmth, vintage
        Timbaland,              // Timbaland - Creative pitch, unique sound
        Pharrell,               // Pharrell - Minimalist clarity, groove
        RickRubin,              // Rick Rubin - Raw, natural dynamics

        // TECHNO/HOUSE
        Pushkarev,              // Andrey Pushkarev - Deep, atmospheric
        Lawrence,               // Lawrence (Dial) - Organic techno, tape
        PanthaDuPrince,         // Pantha du Prince - Bell-like, melodic

        // EXPERIMENTAL
        NilsFrahm,              // Nils Frahm - Piano, tape delays, vintage
        AphexTwin,              // Aphex Twin - Granular, experimental

        // UK BASS
        GeneralLevy,            // General Levy - Jungle vibes
        Skream,                 // Skream - Dubstep, sub bass, wobbles

        // ECHOELMUSIC SIGNATURE
        EchoelSignature         // Best of all worlds - Echoelmusic sound!
    };

    //==========================================================================
    // Audio Quality Settings
    //==========================================================================

    enum class AudioQuality
    {
        Standard,               // 16-bit, 44.1kHz (CD quality)
        Professional,           // 24-bit, 48kHz (broadcast standard)
        Studio,                 // 24-bit, 96kHz (studio master)
        Mastering,              // 32-bit float, 96kHz (mastering grade)
        Audiophile              // 32-bit float, 192kHz (ultra high-res)
    };

    struct QualitySpec
    {
        int bitDepth = 24;              // 16, 24, 32
        double sampleRate = 48000.0;    // 44100, 48000, 96000, 192000
        bool useFloat = true;            // true = 32-bit float, false = PCM
        int numChannels = 2;             // 1 = mono, 2 = stereo, 6 = 5.1, etc.

        static QualitySpec fromPreset(AudioQuality quality);
    };

    //==========================================================================
    // Processing Configuration
    //==========================================================================

    struct ProcessingConfig
    {
        ProducerStyle style = ProducerStyle::EchoelSignature;
        QualitySpec inputQuality;
        QualitySpec outputQuality;

        // Processing options
        bool preserveDynamics = true;       // Keep natural dynamics (Rick Rubin style)
        bool addAnalogWarmth = true;        // Vintage gear emulation
        bool enhanceSubBass = true;         // Focus sub frequencies (808 Mafia)
        bool stereoWidening = true;         // Wider stereo image (Metro Boomin)
        bool tapeSaturation = true;         // Tape saturation (Lawrence/Nils Frahm)
        bool creativeEffects = false;       // Experimental processing (Aphex Twin)

        // Quality settings
        bool oversample = true;             // 2x/4x oversampling for clean processing
        bool dithering = true;              // Dither when reducing bit depth
        bool dcOffset = true;               // Remove DC offset

        // Metadata
        juce::String producerCredit;       // "Processed in style of Metro Boomin"
        juce::String originalFile;
        juce::String processingDate;
    };

    //==========================================================================
    // Processing Result
    //==========================================================================

    struct ProcessingResult
    {
        juce::AudioBuffer<float> audio;
        QualitySpec quality;

        // Analysis
        float peakLevel = 0.0f;             // Peak amplitude (-dB)
        float rmsLevel = 0.0f;              // RMS level (-dB)
        float lufs = 0.0f;                  // LUFS loudness
        float dynamicRange = 0.0f;          // Dynamic range (dB)
        float stereoWidth = 0.0f;           // Stereo width (0-1)

        // Processing info
        ProducerStyle styleUsed;
        juce::String processingChain;       // Description of applied processing
        double processingTime = 0.0;        // Seconds

        bool success = false;
        juce::String errorMessage;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    ProducerStyleProcessor();
    ~ProducerStyleProcessor();

    //==========================================================================
    // Load High-Resolution Audio
    //==========================================================================

    /** Load WAV file (supports 16/24/32-bit, any sample rate) */
    juce::AudioBuffer<float> loadHighResAudio(const juce::File& file);

    /** Load with automatic quality detection */
    juce::AudioBuffer<float> loadHighResAudio(const juce::File& file,
                                               QualitySpec& detectedQuality);

    /** Load from memory block */
    juce::AudioBuffer<float> loadFromMemory(const juce::MemoryBlock& data);

    //==========================================================================
    // Process with Producer Style
    //==========================================================================

    /** Process audio with specific producer style */
    ProcessingResult processWithStyle(const juce::AudioBuffer<float>& input,
                                      ProducerStyle style);

    /** Process with full configuration */
    ProcessingResult processWithConfig(const juce::AudioBuffer<float>& input,
                                       const ProcessingConfig& config);

    /** Batch process multiple files */
    juce::Array<ProcessingResult> processBatch(const juce::Array<juce::File>& files,
                                               ProducerStyle style);

    //==========================================================================
    // Individual Processing Chains (per Producer)
    //==========================================================================

    // HIP-HOP/TRAP
    juce::AudioBuffer<float> apply808MafiaStyle(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applyMetroBoominStyle(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applyPyrexStyle(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applyGunnaStyle(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applyTurboStyle(const juce::AudioBuffer<float>& audio);

    // LEGENDARY PRODUCERS
    juce::AudioBuffer<float> applyDrDreStyle(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applyScottStorchStyle(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applyTimbalandStyle(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applyPharrellStyle(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applyRickRubinStyle(const juce::AudioBuffer<float>& audio);

    // TECHNO/HOUSE
    juce::AudioBuffer<float> applyPushkarevStyle(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applyLawrenceStyle(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applyPanthaDuPrinceStyle(const juce::AudioBuffer<float>& audio);

    // EXPERIMENTAL
    juce::AudioBuffer<float> applyNilsFrahmStyle(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applyAphexTwinStyle(const juce::AudioBuffer<float>& audio);

    // UK BASS
    juce::AudioBuffer<float> applyGeneralLevyStyle(const juce::AudioBuffer<float>& audio);
    juce::AudioBuffer<float> applySkreamStyle(const juce::AudioBuffer<float>& audio);

    // ECHOELMUSIC SIGNATURE
    juce::AudioBuffer<float> applyEchoelSignature(const juce::AudioBuffer<float>& audio);

    //==========================================================================
    // Core Processing Elements (Building Blocks)
    //==========================================================================

    // Bass Processing
    juce::AudioBuffer<float> enhance808Bass(const juce::AudioBuffer<float>& audio,
                                            float amount = 1.0f);
    juce::AudioBuffer<float> addSubHarmonics(const juce::AudioBuffer<float>& audio,
                                            float freq = 50.0f);

    // Saturation & Warmth
    juce::AudioBuffer<float> applyTapeSaturation(const juce::AudioBuffer<float>& audio,
                                                 float drive = 0.5f);
    juce::AudioBuffer<float> applyAnalogWarmth(const juce::AudioBuffer<float>& audio,
                                               float amount = 0.5f);
    juce::AudioBuffer<float> applyVinylCharacter(const juce::AudioBuffer<float>& audio);

    // Stereo Processing
    juce::AudioBuffer<float> wideStereo(const juce::AudioBuffer<float>& audio,
                                       float width = 1.5f);
    juce::AudioBuffer<float> haasEffect(const juce::AudioBuffer<float>& audio,
                                       float delayMs = 20.0f);

    // Dynamics
    juce::AudioBuffer<float> punchyCompression(const juce::AudioBuffer<float>& audio,
                                              float ratio = 4.0f,
                                              float threshold = -20.0f);
    juce::AudioBuffer<float> parallelCompression(const juce::AudioBuffer<float>& audio,
                                                 float mix = 0.5f);

    // EQ
    juce::AudioBuffer<float> vintageLowShelf(const juce::AudioBuffer<float>& audio,
                                            float freq = 100.0f,
                                            float gain = 3.0f);
    juce::AudioBuffer<float> airEQ(const juce::AudioBuffer<float>& audio,
                                  float freq = 10000.0f,
                                  float gain = 2.0f);

    // Time-Based Effects
    juce::AudioBuffer<float> tapeDelay(const juce::AudioBuffer<float>& audio,
                                      float delayMs = 500.0f,
                                      float feedback = 0.3f);
    juce::AudioBuffer<float> deepReverb(const juce::AudioBuffer<float>& audio,
                                       float roomSize = 0.8f,
                                       float damping = 0.5f);

    // Creative/Experimental
    juce::AudioBuffer<float> granularProcessing(const juce::AudioBuffer<float>& audio,
                                               float grainSize = 50.0f);
    juce::AudioBuffer<float> bitCrushing(const juce::AudioBuffer<float>& audio,
                                        int bits = 8);
    juce::AudioBuffer<float> creativeResampling(const juce::AudioBuffer<float>& audio,
                                               float pitchShift = 0.0f);

    //==========================================================================
    // Export for Echoelmusic Audio Engine
    //==========================================================================

    /** Export with optimal settings for Echoelmusic */
    bool exportForEngine(const juce::AudioBuffer<float>& audio,
                        const juce::File& outputFile,
                        const QualitySpec& quality = QualitySpec());

    /** Export with metadata */
    bool exportWithMetadata(const ProcessingResult& result,
                           const juce::File& outputFile);

    /** Export multiple formats (WAV, FLAC, OGG) */
    struct ExportFormats
    {
        bool exportWAV = true;
        bool exportFLAC = true;      // Lossless compression
        bool exportOGG = false;       // Lossy for web
        int flacCompression = 5;      // 0-8
        float oggQuality = 0.9f;      // 0-1

        juce::File outputDirectory;
        juce::String baseName;
    };

    juce::Array<juce::File> exportMultipleFormats(const ProcessingResult& result,
                                                   const ExportFormats& formats);

    //==========================================================================
    // Analysis & Quality Check
    //==========================================================================

    /** Analyze audio quality metrics */
    struct AudioAnalysis
    {
        float peakDB = 0.0f;
        float rmsDB = 0.0f;
        float lufs = 0.0f;
        float truePeak = 0.0f;
        float dynamicRange = 0.0f;
        float stereoWidth = 0.0f;
        float spectralCentroid = 0.0f;
        float subBassEnergy = 0.0f;     // Energy below 80Hz
        float midEnergy = 0.0f;          // 200Hz - 2kHz
        float highEnergy = 0.0f;         // Above 8kHz

        bool hasClipping = false;
        bool hasDCOffset = false;
        float dcOffsetValue = 0.0f;

        juce::String qualityRating;     // "Professional", "Broadcast", "Consumer"
    };

    AudioAnalysis analyzeAudio(const juce::AudioBuffer<float>& audio,
                              double sampleRate);

    /** Check if audio meets Echoelmusic quality standards */
    bool meetsEchoelmusicStandard(const AudioAnalysis& analysis);

    //==========================================================================
    // Sample Rate Conversion (High Quality)
    //==========================================================================

    /** Convert sample rate with high-quality resampling */
    juce::AudioBuffer<float> resample(const juce::AudioBuffer<float>& audio,
                                     double sourceSR,
                                     double targetSR,
                                     int quality = 4);  // 0-4, higher = better

    /** Oversample for processing, then downsample */
    juce::AudioBuffer<float> processWithOversampling(
        const juce::AudioBuffer<float>& audio,
        double sampleRate,
        int oversampleFactor,  // 2x, 4x, 8x
        std::function<juce::AudioBuffer<float>(const juce::AudioBuffer<float>&)> processor);

    //==========================================================================
    // Bit Depth Conversion
    //==========================================================================

    /** Convert bit depth with dithering */
    juce::AudioBuffer<float> convertBitDepth(const juce::AudioBuffer<float>& audio,
                                            int sourceBits,
                                            int targetBits,
                                            bool useDithering = true);

    //==========================================================================
    // Integration with CloudSampleManager
    //==========================================================================

    /** Process and upload to cloud */
    struct CloudProcessingConfig
    {
        ProducerStyle style;
        bool uploadOriginal = false;
        bool uploadProcessed = true;
        bool compressForCloud = true;      // Use FLAC compression
        juce::String cloudFolder = "Echoelmusic/Processed";
    };

    // This would integrate with CloudSampleManager
    // bool processAndUpload(const juce::File& file,
    //                      const CloudProcessingConfig& config,
    //                      CloudSampleManager& cloudManager);

    //==========================================================================
    // Presets & Settings
    //==========================================================================

    /** Get description of producer style */
    juce::String getStyleDescription(ProducerStyle style) const;

    /** Get recommended settings for style */
    ProcessingConfig getRecommendedConfig(ProducerStyle style) const;

    /** Save custom preset */
    bool savePreset(const ProcessingConfig& config, const juce::String& name);

    /** Load custom preset */
    ProcessingConfig loadPreset(const juce::String& name);

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(float progress)> onProgress;
    std::function<void(const juce::String& message)> onStatusChange;
    std::function<void(const AudioAnalysis& analysis)> onAnalysisComplete;
    std::function<void(const juce::String& error)> onError;

private:
    //==========================================================================
    // Internal State
    //==========================================================================

    ProcessingConfig currentConfig;
    double lastSampleRate = 48000.0;

    //==========================================================================
    // DSP Components
    //==========================================================================

    juce::dsp::ProcessorChain<
        juce::dsp::Gain<float>,
        juce::dsp::LadderFilter<float>,
        juce::dsp::Reverb
    > processingChain;

    juce::AudioFormatManager formatManager;

    //==========================================================================
    // Helper Functions
    //==========================================================================

    void prepareProcessing(double sampleRate, int samplesPerBlock);
    juce::AudioBuffer<float> applyProcessingChain(const juce::AudioBuffer<float>& audio,
                                                  const juce::StringArray& chain);

    float calculateLUFS(const juce::AudioBuffer<float>& audio, double sampleRate);
    float calculateDynamicRange(const juce::AudioBuffer<float>& audio);
    float calculateStereoWidth(const juce::AudioBuffer<float>& audio);

    // Metadata
    void embedMetadata(const juce::File& file,
                      const ProcessingConfig& config,
                      const AudioAnalysis& analysis);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ProducerStyleProcessor)
};

//==============================================================================
// Inline Helper Functions
//==============================================================================

inline ProducerStyleProcessor::QualitySpec
ProducerStyleProcessor::QualitySpec::fromPreset(AudioQuality quality)
{
    QualitySpec spec;

    switch (quality)
    {
        case AudioQuality::Standard:
            spec.bitDepth = 16;
            spec.sampleRate = 44100.0;
            spec.useFloat = false;
            break;

        case AudioQuality::Professional:
            spec.bitDepth = 24;
            spec.sampleRate = 48000.0;
            spec.useFloat = false;
            break;

        case AudioQuality::Studio:
            spec.bitDepth = 24;
            spec.sampleRate = 96000.0;
            spec.useFloat = false;
            break;

        case AudioQuality::Mastering:
            spec.bitDepth = 32;
            spec.sampleRate = 96000.0;
            spec.useFloat = true;
            break;

        case AudioQuality::Audiophile:
            spec.bitDepth = 32;
            spec.sampleRate = 192000.0;
            spec.useFloat = true;
            break;
    }

    spec.numChannels = 2;  // Stereo default
    return spec;
}
