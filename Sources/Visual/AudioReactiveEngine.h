#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>
#include <functional>
#include <map>
#include <variant>

/**
 * AudioReactiveEngine - Advanced Audio-Visual Synesthesia System
 *
 * Inspired by: TouchDesigner, Resolume Arena, VDMX, Magic Music Visuals
 *
 * Features:
 * - Multi-band audio analysis (FFT, onset, beat, pitch)
 * - Audio feature extraction (spectral centroid, flux, rolloff)
 * - Beat detection with tempo tracking
 * - Audio-to-parameter mapping with curves
 * - Envelope followers with attack/release
 * - Node-based processing graph
 * - MIDI/OSC input mapping
 * - Visual generators (particles, geometry, shaders)
 * - Vaporwave aesthetic presets
 */
namespace Echoel::Visual
{

//==============================================================================
// Audio Analysis
//==============================================================================

class AudioAnalyzer
{
public:
    static constexpr int fftSize = 2048;
    static constexpr int numBands = 8;       // Frequency bands
    static constexpr int numMelBands = 40;   // Mel-frequency bands

    AudioAnalyzer();

    void prepare(double sampleRate, int samplesPerBlock);
    void reset();

    /** Process audio and update analysis */
    void process(const float* samples, int numSamples);

    //==========================================================================
    // Frequency Analysis
    //==========================================================================

    /** Get raw FFT magnitude spectrum (0 to fftSize/2) */
    const std::array<float, fftSize / 2>& getSpectrum() const { return spectrum; }

    /** Get band-limited energy (sub, low, mid, high, etc.) */
    const std::array<float, numBands>& getBandEnergy() const { return bandEnergy; }

    /** Get smoothed band energy with envelope */
    const std::array<float, numBands>& getBandEnergySlow() const { return bandEnergySlow; }

    /** Get mel-frequency spectrum */
    const std::array<float, numMelBands>& getMelSpectrum() const { return melSpectrum; }

    /** Get specific frequency range energy (normalized 0-1) */
    float getFrequencyEnergy(float lowHz, float highHz) const;

    //==========================================================================
    // Spectral Features
    //==========================================================================

    /** Spectral centroid (brightness) - normalized 0-1 */
    float getSpectralCentroid() const { return spectralCentroid; }

    /** Spectral flux (change rate) - normalized 0-1 */
    float getSpectralFlux() const { return spectralFlux; }

    /** Spectral rolloff (high-frequency content) */
    float getSpectralRolloff() const { return spectralRolloff; }

    /** Spectral flatness (noisiness) - 0=tonal, 1=noise */
    float getSpectralFlatness() const { return spectralFlatness; }

    //==========================================================================
    // Amplitude Analysis
    //==========================================================================

    /** RMS level (0-1) */
    float getRMS() const { return rmsLevel; }

    /** Peak level (0-1) */
    float getPeak() const { return peakLevel; }

    /** Smoothed level with attack/release */
    float getLevel() const { return level; }

    /** Waveform for display */
    const std::vector<float>& getWaveform() const { return waveform; }

    //==========================================================================
    // Beat Detection
    //==========================================================================

    /** Get beat trigger (true on beat) */
    bool isBeat() const { return beatDetected; }

    /** Get current BPM estimate */
    float getBPM() const { return bpm; }

    /** Get beat phase (0-1 through beat cycle) */
    float getBeatPhase() const { return beatPhase; }

    /** Get beat confidence (0-1) */
    float getBeatConfidence() const { return beatConfidence; }

    /** Manual BPM tap */
    void tapBPM();

    /** Set BPM manually (disables auto-detection) */
    void setManualBPM(float bpm);

    //==========================================================================
    // Onset Detection
    //==========================================================================

    /** Get onset trigger (true on transient) */
    bool isOnset() const { return onsetDetected; }

    /** Get onset strength (0-1) */
    float getOnsetStrength() const { return onsetStrength; }

    //==========================================================================
    // Pitch Detection
    //==========================================================================

    /** Get detected pitch in Hz (0 if no clear pitch) */
    float getPitch() const { return pitch; }

    /** Get pitch as MIDI note number */
    int getPitchMIDI() const { return pitchMIDI; }

    /** Get pitch confidence (0-1) */
    float getPitchConfidence() const { return pitchConfidence; }

    //==========================================================================
    // Configuration
    //==========================================================================

    void setSmoothingTime(float ms);
    void setBeatSensitivity(float sensitivity);
    void setOnsetSensitivity(float sensitivity);

private:
    double sampleRate = 48000.0;

    // FFT
    std::unique_ptr<juce::dsp::FFT> fft;
    std::array<float, fftSize> fftBuffer;
    std::array<float, fftSize> window;
    std::array<float, fftSize / 2> spectrum;
    std::array<float, fftSize / 2> prevSpectrum;

    // Band energy
    std::array<float, numBands> bandEnergy;
    std::array<float, numBands> bandEnergySlow;
    std::array<std::pair<float, float>, numBands> bandFrequencies;  // Low/high Hz per band

    // Mel spectrum
    std::array<float, numMelBands> melSpectrum;
    std::array<std::vector<std::pair<int, float>>, numMelBands> melFilterbank;

    // Features
    float spectralCentroid = 0.0f;
    float spectralFlux = 0.0f;
    float spectralRolloff = 0.0f;
    float spectralFlatness = 0.0f;

    // Amplitude
    float rmsLevel = 0.0f;
    float peakLevel = 0.0f;
    float level = 0.0f;

    // Waveform
    std::vector<float> waveform;
    int waveformWritePos = 0;

    // Beat detection
    bool beatDetected = false;
    float bpm = 120.0f;
    float beatPhase = 0.0f;
    float beatConfidence = 0.0f;
    std::vector<double> beatHistory;
    double lastBeatTime = 0.0;
    bool manualBPM = false;

    // Onset detection
    bool onsetDetected = false;
    float onsetStrength = 0.0f;
    float onsetThreshold = 0.1f;
    std::array<float, 10> onsetHistory;
    int onsetHistoryPos = 0;

    // Pitch detection
    float pitch = 0.0f;
    int pitchMIDI = 0;
    float pitchConfidence = 0.0f;

    // Smoothing
    float smoothingCoeff = 0.9f;
    float attackCoeff = 0.1f;
    float releaseCoeff = 0.95f;

    // Internal time
    double currentTime = 0.0;
    int samplesProcessed = 0;

    // Initialization
    void initBandFrequencies();
    void initMelFilterbank();
    void initWindow();

    // Processing
    void processFFT(const float* samples, int numSamples);
    void calculateBandEnergy();
    void calculateMelSpectrum();
    void calculateSpectralFeatures();
    void detectBeat();
    void detectOnset();
    void detectPitch();
};

//==============================================================================
// Envelope Follower
//==============================================================================

class EnvelopeFollower
{
public:
    EnvelopeFollower();

    void prepare(double sampleRate);
    void reset();

    void setAttack(float ms);
    void setRelease(float ms);
    void setHold(float ms);

    /** Process single input value */
    float process(float input);

    /** Get current envelope value */
    float getValue() const { return envelope; }

    /** Get smoothed value */
    float getSmoothed() const { return smoothed; }

private:
    double sampleRate = 48000.0;

    float envelope = 0.0f;
    float smoothed = 0.0f;

    float attackCoeff = 0.1f;
    float releaseCoeff = 0.99f;
    int holdSamples = 0;
    int holdCounter = 0;
};

//==============================================================================
// Audio-to-Parameter Mapping
//==============================================================================

class ParameterMapper
{
public:
    enum class InputSource
    {
        // Amplitude
        RMS, Peak, Level,

        // Frequency bands
        SubBass, Bass, LowMid, Mid, HighMid, Presence, Brilliance, Air,

        // Spectral features
        SpectralCentroid, SpectralFlux, SpectralRolloff, SpectralFlatness,

        // Beat/rhythm
        Beat, BeatPhase, Onset, OnsetStrength,

        // Pitch
        Pitch, PitchMIDI,

        // Custom frequency range
        CustomFrequency
    };

    struct Mapping
    {
        juce::String name;
        InputSource source = InputSource::Level;

        // For custom frequency range
        float lowHz = 20.0f, highHz = 200.0f;

        // Envelope
        float attack = 10.0f;     // ms
        float release = 100.0f;   // ms

        // Response curve
        enum class Curve { Linear, Exponential, Logarithmic, SCurve, Step };
        Curve curve = Curve::Linear;
        float curveAmount = 1.0f;

        // Range
        float inputMin = 0.0f, inputMax = 1.0f;
        float outputMin = 0.0f, outputMax = 1.0f;

        // Modifiers
        bool invert = false;
        float smoothing = 0.0f;   // 0-1 additional smoothing

        // Output
        float currentValue = 0.0f;
    };

    ParameterMapper();

    void prepare(double sampleRate);

    /** Add a mapping and return its ID */
    int addMapping(const Mapping& mapping);
    void removeMapping(int id);
    Mapping* getMapping(int id);

    /** Update all mappings from analyzer */
    void update(const AudioAnalyzer& analyzer);

    /** Get mapped value */
    float getValue(int mappingId) const;

    /** Get all mappings */
    const std::map<int, Mapping>& getMappings() const { return mappings; }

private:
    std::map<int, Mapping> mappings;
    std::map<int, EnvelopeFollower> envelopes;
    int nextMappingId = 1;

    float getSourceValue(const Mapping& mapping, const AudioAnalyzer& analyzer);
    float applyCurve(float value, Mapping::Curve curve, float amount);
};

//==============================================================================
// Visual Generators
//==============================================================================

class VisualGenerator
{
public:
    virtual ~VisualGenerator() = default;

    virtual void prepare(int width, int height) = 0;
    virtual void render(juce::Image& output, double time,
                        const ParameterMapper& params) = 0;

    virtual juce::String getName() const = 0;

    /** Set parameter value by name */
    void setParameter(const juce::String& name, float value)
    {
        parameters[name] = value;
    }

    float getParameter(const juce::String& name, float defaultValue = 0.0f) const
    {
        auto it = parameters.find(name);
        return it != parameters.end() ? it->second : defaultValue;
    }

    /** Bind audio mapping to parameter */
    void bindAudioMapping(const juce::String& paramName, int mappingId)
    {
        audioBindings[paramName] = mappingId;
    }

protected:
    std::map<juce::String, float> parameters;
    std::map<juce::String, int> audioBindings;

    float getParameterWithBinding(const juce::String& name,
                                   const ParameterMapper& params,
                                   float defaultValue = 0.0f) const
    {
        auto bindIt = audioBindings.find(name);
        if (bindIt != audioBindings.end())
        {
            return params.getValue(bindIt->second);
        }
        return getParameter(name, defaultValue);
    }
};

//==============================================================================
// Particle System Generator
//==============================================================================

class ParticleGenerator : public VisualGenerator
{
public:
    ParticleGenerator();

    void prepare(int width, int height) override;
    void render(juce::Image& output, double time,
                const ParameterMapper& params) override;

    juce::String getName() const override { return "Particles"; }

    struct Particle
    {
        float x = 0.0f, y = 0.0f;
        float vx = 0.0f, vy = 0.0f;
        float life = 1.0f;
        float size = 10.0f;
        juce::Colour color;
    };

    void emit(int count);
    void setEmitPosition(float x, float y);
    void setEmitVelocity(float vx, float vy, float spread);

private:
    std::vector<Particle> particles;
    int maxParticles = 1000;
    int width = 800, height = 600;

    // Emitter
    float emitX = 0.5f, emitY = 0.5f;
    float emitVX = 0.0f, emitVY = -0.5f;
    float emitSpread = 0.2f;

    // Physics
    float gravity = 0.1f;
    float friction = 0.99f;

    // Color
    std::array<juce::Colour, 4> colorGradient {{
        juce::Colour(0xFFFF71CE),  // Neon pink
        juce::Colour(0xFF01CDFE),  // Neon cyan
        juce::Colour(0xFF05FFA1),  // Neon mint
        juce::Colour(0xFFFFFB96)   // Neon yellow
    }};

    juce::Random random;

    void updateParticles(float deltaTime);
    juce::Colour getColorFromLife(float life) const;
};

//==============================================================================
// Geometry Generator (Shapes, Fractals)
//==============================================================================

class GeometryGenerator : public VisualGenerator
{
public:
    enum class Shape
    {
        Circle, Triangle, Square, Pentagon, Hexagon, Star,
        Spiral, Rose, Lissajous, Hypocycloid,
        SierpinskiTriangle, KochSnowflake, MandelbrotSet, JuliaSet
    };

    GeometryGenerator();

    void prepare(int width, int height) override;
    void render(juce::Image& output, double time,
                const ParameterMapper& params) override;

    juce::String getName() const override { return "Geometry"; }

    void setShape(Shape shape) { currentShape = shape; }
    void setSymmetry(int symmetry) { this->symmetry = symmetry; }
    void setComplexity(float complexity) { this->complexity = complexity; }

private:
    Shape currentShape = Shape::Circle;
    int symmetry = 1;
    float complexity = 0.5f;
    int width = 800, height = 600;

    void renderShape(juce::Graphics& g, Shape shape, float centerX, float centerY,
                     float size, float rotation, juce::Colour color);
    void renderFractal(juce::Graphics& g, Shape fractal, float centerX, float centerY,
                       float size, int iterations);
};

//==============================================================================
// Waveform/Spectrum Visualizer
//==============================================================================

class WaveformVisualizer : public VisualGenerator
{
public:
    enum class Style
    {
        Line, Bars, Circular, Mirror, Radial, Dots, FilledWave
    };

    WaveformVisualizer();

    void prepare(int width, int height) override;
    void render(juce::Image& output, double time,
                const ParameterMapper& params) override;

    juce::String getName() const override { return "Waveform"; }

    void setStyle(Style style) { this->style = style; }
    void setData(const float* data, int numSamples);
    void setSpectrum(const float* data, int numBands);

private:
    Style style = Style::Line;
    std::vector<float> waveformData;
    std::vector<float> spectrumData;
    int width = 800, height = 600;

    void renderLine(juce::Graphics& g);
    void renderBars(juce::Graphics& g);
    void renderCircular(juce::Graphics& g);
    void renderRadial(juce::Graphics& g);
};

//==============================================================================
// VHS/Retro Effect Generator
//==============================================================================

class RetroEffectGenerator : public VisualGenerator
{
public:
    RetroEffectGenerator();

    void prepare(int width, int height) override;
    void render(juce::Image& output, double time,
                const ParameterMapper& params) override;

    juce::String getName() const override { return "RetroVHS"; }

    // VHS effects
    void setTrackingOffset(float amount);
    void setScanlines(bool enabled, float intensity = 0.3f);
    void setChromaticAberration(float amount);
    void setNoiseAmount(float amount);
    void setGhostImage(bool enabled, float amount = 0.2f);

    // Vaporwave effects
    void setNeonGlow(bool enabled, float amount = 0.5f);
    void setRetroGrid(bool enabled);
    void setSunset(bool enabled);

private:
    int width = 800, height = 600;

    // VHS
    float trackingOffset = 0.0f;
    bool scanlinesEnabled = true;
    float scanlinesIntensity = 0.3f;
    float chromaticAberration = 0.0f;
    float noiseAmount = 0.05f;
    bool ghostImage = false;
    float ghostAmount = 0.2f;

    // Vaporwave
    bool neonGlow = true;
    float neonAmount = 0.5f;
    bool retroGrid = true;
    bool sunset = false;

    juce::Random random;

    void applyVHSEffect(juce::Image& image, double time);
    void applyScanlines(juce::Image& image);
    void applyNeonGlow(juce::Image& image);
    void renderRetroGrid(juce::Graphics& g, double time);
    void renderSunset(juce::Graphics& g);
};

//==============================================================================
// Audio Reactive Engine (Main Class)
//==============================================================================

class AudioReactiveEngine
{
public:
    AudioReactiveEngine();
    ~AudioReactiveEngine();

    void prepare(double sampleRate, int samplesPerBlock, int width, int height);
    void reset();

    //==========================================================================
    // Audio Input
    //==========================================================================

    /** Process audio samples */
    void processAudio(const float* samples, int numSamples);

    /** Get audio analyzer */
    AudioAnalyzer& getAnalyzer() { return analyzer; }

    //==========================================================================
    // Parameter Mapping
    //==========================================================================

    ParameterMapper& getParameterMapper() { return paramMapper; }

    /** Quick mapping helpers */
    int mapBassToParameter(const juce::String& name, float min, float max);
    int mapBeatToParameter(const juce::String& name, float min, float max);
    int mapLevelToParameter(const juce::String& name, float min, float max);

    //==========================================================================
    // Visual Generators
    //==========================================================================

    /** Add a visual generator layer */
    void addGenerator(std::unique_ptr<VisualGenerator> generator);
    void removeGenerator(int index);
    VisualGenerator* getGenerator(int index);
    int getNumGenerators() const { return static_cast<int>(generators.size()); }

    /** Layer blend modes */
    enum class BlendMode { Normal, Add, Multiply, Screen, Overlay };
    void setLayerBlendMode(int index, BlendMode mode);
    void setLayerOpacity(int index, float opacity);

    //==========================================================================
    // Rendering
    //==========================================================================

    /** Render frame */
    void renderFrame(juce::Image& output, double deltaTime);

    /** Get last rendered frame */
    const juce::Image& getLastFrame() const { return lastFrame; }

    //==========================================================================
    // Presets
    //==========================================================================

    enum class Preset
    {
        VaporwaveNightDrive,
        NeonBars,
        ParticleBurst,
        RetroGrid80s,
        AbstractGeometry,
        AudioScope,
        PsychedelicSwirl,
        MinimalPulse
    };

    void loadPreset(Preset preset);

    //==========================================================================
    // OSC/MIDI Control
    //==========================================================================

    void handleMIDI(const juce::MidiMessage& message);
    void handleOSC(const juce::String& address, float value);

private:
    // Audio
    AudioAnalyzer analyzer;
    ParameterMapper paramMapper;

    // Visuals
    std::vector<std::unique_ptr<VisualGenerator>> generators;
    std::vector<BlendMode> layerBlendModes;
    std::vector<float> layerOpacities;

    // Rendering
    int width = 800, height = 600;
    juce::Image lastFrame;
    juce::Image compositeBuffer;
    double currentTime = 0.0;

    // MIDI/OSC mappings
    std::map<int, std::pair<juce::String, float*>> midiMappings;
    std::map<juce::String, float*> oscMappings;

    void blendLayers(juce::Image& output, const juce::Image& layer, BlendMode mode, float opacity);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AudioReactiveEngine)
};

}  // namespace Echoel::Visual
