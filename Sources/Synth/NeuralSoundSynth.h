#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <memory>

/**
 * NeuralSoundSynth
 *
 * Revolutionary AI-powered synthesis engine using neural networks for real-time audio generation.
 * Inspired by Google Magenta (NSynth, DDSP) and RAVE (Realtime Audio Variational autoEncoder).
 *
 * Features:
 * - Real-time neural audio synthesis via Variational Autoencoder (VAE)
 * - Timbre transfer (transform any sound → any instrument)
 * - Latent space exploration (semantic sound morphing)
 * - Style transfer (apply character of one sound to another)
 * - Generative synthesis (AI creates novel sounds)
 * - Bio-reactive latent space navigation (HRV → timbre)
 * - Pre-trained on 1000+ instruments
 * - 16-voice polyphony with MPE support
 * - DDSP-style interpretable controls
 * - GPU acceleration (optional, falls back to CPU)
 *
 * Technical:
 * - Latent space: 128 dimensions
 * - Sample rate: 48kHz native
 * - Inference latency: < 5ms (GPU), < 15ms (CPU)
 * - Model format: ONNX Runtime
 */
class NeuralSoundSynth : public juce::Synthesiser
{
public:
    //==========================================================================
    // Synthesis Modes
    //==========================================================================

    enum class SynthesisMode
    {
        NeuralDirect,       // Direct neural synthesis from MIDI
        TimbreTransfer,     // Transform input audio to target timbre
        StyleTransfer,      // Apply style of one sound to another
        Interpolation,      // Morph between two sounds
        Generative,         // AI-generated sounds
        LatentExplore       // Manual latent space navigation
    };

    enum class InstrumentCategory
    {
        Brass,
        Strings,
        Woodwinds,
        Keyboards,
        Percussion,
        Synth,
        Vocal,
        Guitar,
        Bass,
        Ethnic,
        FX,
        Custom              // User-trained models
    };

    //==========================================================================
    // Latent Space Control
    //==========================================================================

    struct LatentVector
    {
        static constexpr int dimensions = 128;
        std::array<float, dimensions> values = {0.0f};

        // Semantic controls (mapped to latent dimensions via training)
        float brightness = 0.5f;        // Dark → Bright
        float warmth = 0.5f;            // Cold → Warm
        float richness = 0.5f;          // Thin → Rich
        float attack = 0.5f;            // Slow → Fast
        float texture = 0.5f;           // Smooth → Rough
        float movement = 0.5f;          // Static → Dynamic
        float space = 0.5f;             // Dry → Wet
        float character = 0.5f;         // Clean → Colored

        void updateFromSemanticControls();
        void randomize(float amount = 1.0f);
    };

    //==========================================================================
    // Model Management
    //==========================================================================

    struct NeuralModel
    {
        std::string name;
        std::string description;
        InstrumentCategory category;
        std::string modelPath;          // Path to ONNX model file
        LatentVector defaultLatent;
        bool isLoaded = false;

        // Model metadata
        int inputSize = 128;
        int outputSize = 2048;          // 2048 samples per inference (42.6ms @ 48kHz)
        int sampleRate = 48000;
        float latency = 0.0f;           // Measured latency in ms
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    NeuralSoundSynth();
    ~NeuralSoundSynth() override;

    //==========================================================================
    // Model Loading
    //==========================================================================

    /** Load neural model from file */
    bool loadModel(const juce::File& modelFile);

    /** Load preset model by category and name */
    bool loadPresetModel(InstrumentCategory category, const std::string& name);

    /** Get available preset models */
    std::vector<NeuralModel> getAvailableModels() const;

    /** Get current model info */
    const NeuralModel& getCurrentModel() const { return currentModel; }

    /** Enable/disable GPU acceleration */
    void setGPUAcceleration(bool enabled);
    bool isGPUAccelerationEnabled() const { return useGPU; }

    //==========================================================================
    // Synthesis Mode
    //==========================================================================

    void setSynthesisMode(SynthesisMode mode);
    SynthesisMode getSynthesisMode() const { return currentMode; }

    //==========================================================================
    // Latent Space Control
    //==========================================================================

    /** Set latent vector directly */
    void setLatentVector(const LatentVector& latent);
    const LatentVector& getLatentVector() const { return latentVector; }

    /** Set semantic controls (automatically updates latent vector) */
    void setBrightness(float value);    // 0.0 to 1.0
    void setWarmth(float value);
    void setRichness(float value);
    void setAttack(float value);
    void setTexture(float value);
    void setMovement(float value);
    void setSpace(float value);
    void setCharacter(float value);

    /** Randomize latent space */
    void randomizeLatent(float amount = 1.0f);

    /** Interpolate between two latent vectors */
    void interpolateLatent(const LatentVector& a, const LatentVector& b, float position);

    //==========================================================================
    // Timbre Transfer
    //==========================================================================

    /** Load source audio for timbre transfer */
    void setSourceAudio(const juce::AudioBuffer<float>& audio);

    /** Load target timbre model */
    void setTargetTimbre(const NeuralModel& model);

    /** Set transfer amount (0.0 = original, 1.0 = full transfer) */
    void setTransferAmount(float amount);
    float getTransferAmount() const { return transferAmount; }

    //==========================================================================
    // Style Transfer
    //==========================================================================

    /** Load content audio */
    void setContentAudio(const juce::AudioBuffer<float>& audio);

    /** Load style audio */
    void setStyleAudio(const juce::AudioBuffer<float>& audio);

    /** Set style amount */
    void setStyleAmount(float amount);

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    void setBioReactiveEnabled(bool enabled);
    bool isBioReactiveEnabled() const { return bioReactiveEnabled; }

    /** Set bio-data for reactive synthesis */
    void setBioData(float hrv, float coherence, float breath);

    /** Map bio-data to latent dimensions */
    struct BioMapping
    {
        int hrvDimension = 0;           // Which latent dimension HRV controls
        float hrvAmount = 0.5f;         // Modulation amount
        int coherenceDimension = 1;
        float coherenceAmount = 0.5f;
        int breathDimension = 2;
        float breathAmount = 0.5f;
    };

    void setBioMapping(const BioMapping& mapping);
    const BioMapping& getBioMapping() const { return bioMapping; }

    //==========================================================================
    // MPE Support
    //==========================================================================

    void setMPEEnabled(bool enabled);
    bool isMPEEnabled() const { return mpeEnabled; }

    void setMPEZone(int zone);  // 0 = lower, 1 = upper

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

    //==========================================================================
    // Visualization & Analysis
    //==========================================================================

    /** Get current latent space position (2D projection for visualization) */
    struct LatentPosition2D
    {
        float x = 0.0f;  // -1.0 to +1.0
        float y = 0.0f;  // -1.0 to +1.0
    };

    LatentPosition2D getLatentPosition2D() const;

    /** Get spectral representation of current sound */
    std::vector<float> getCurrentSpectrum() const;

    /** Get generation quality metrics */
    struct QualityMetrics
    {
        float inferenceTime = 0.0f;     // ms
        float reconstructionError = 0.0f; // Lower is better
        bool isRealtime = true;         // Can maintain real-time?
    };

    QualityMetrics getQualityMetrics() const { return qualityMetrics; }

    //==========================================================================
    // Preset Management
    //==========================================================================

    struct NeuralPreset
    {
        std::string name;
        NeuralModel model;
        LatentVector latent;
        SynthesisMode mode;
        BioMapping bioMapping;
    };

    void savePreset(const std::string& name);
    void loadPreset(const std::string& name);
    std::vector<std::string> getPresetNames() const;

private:
    //==========================================================================
    // Neural Network Inference
    //==========================================================================

    class NeuralEngine;
    std::unique_ptr<NeuralEngine> neuralEngine;

    //==========================================================================
    // Voice Class
    //==========================================================================

    class NeuralVoice : public juce::SynthesiserVoice
    {
    public:
        NeuralVoice(NeuralSoundSynth& parent);

        bool canPlaySound(juce::SynthesiserSound*) override { return true; }

        void startNote(int midiNoteNumber,
                      float velocity,
                      juce::SynthesiserSound*,
                      int currentPitchWheelPosition) override;

        void stopNote(float velocity, bool allowTailOff) override;

        void pitchWheelMoved(int newPitchWheelValue) override;
        void controllerMoved(int controllerNumber, int newControllerValue) override;

        void renderNextBlock(juce::AudioBuffer<float>& outputBuffer,
                            int startSample,
                            int numSamples) override;

        void setMPEValues(float slide, float press, float lift);

    private:
        NeuralSoundSynth& synth;
        int currentNote = 0;
        float currentVelocity = 0.0f;
        float pitchBend = 0.0f;

        // MPE
        float mpeSlide = 0.0f;
        float mpePress = 0.0f;
        float mpeLift = 0.0f;

        // Voice-specific latent vector
        LatentVector voiceLatent;

        // Inference buffer
        std::vector<float> inferenceBuffer;
        int bufferReadPos = 0;

        void updateLatentFromMIDI();
        void generateNextBlock();
    };

    //==========================================================================
    // State
    //==========================================================================

    SynthesisMode currentMode = SynthesisMode::NeuralDirect;
    NeuralModel currentModel;

    LatentVector latentVector;
    float transferAmount = 1.0f;
    float styleAmount = 0.5f;

    bool bioReactiveEnabled = false;
    BioMapping bioMapping;
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    float bioBreath = 0.5f;

    bool mpeEnabled = false;
    int mpeZone = 0;

    bool useGPU = false;
    double currentSampleRate = 48000.0;

    QualityMetrics qualityMetrics;

    //==========================================================================
    // Audio Buffers
    //==========================================================================

    juce::AudioBuffer<float> sourceAudio;
    juce::AudioBuffer<float> contentAudio;
    juce::AudioBuffer<float> styleAudio;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateLatentFromBioData();
    void applyBioReactiveModulation();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (NeuralSoundSynth)
};
