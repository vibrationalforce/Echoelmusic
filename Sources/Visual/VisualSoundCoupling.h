#pragma once

#include <JuceHeader.h>
#include "../AI/SuperIntelligenceSoundDesign.h"
#include "../Automation/SuperAutomationEngine.h"
#include <vector>
#include <array>
#include <cmath>
#include <functional>
#include <memory>

namespace Echoelmusic {
namespace Visual {

using namespace AI;
using namespace Automation;

//==============================================================================
// Audio Analysis for Visual Reactivity
//==============================================================================
class AudioAnalyzer {
public:
    static constexpr int FFT_SIZE = 2048;
    static constexpr int NUM_BANDS = 32;

    struct AnalysisResult {
        // Frequency bands (32 bands, logarithmic spacing)
        std::array<float, NUM_BANDS> bands = {};

        // Derived metrics
        float totalEnergy = 0.0f;
        float bass = 0.0f;          // 20-200 Hz
        float lowMid = 0.0f;        // 200-800 Hz
        float mid = 0.0f;           // 800-2500 Hz
        float highMid = 0.0f;       // 2500-6000 Hz
        float high = 0.0f;          // 6000-20000 Hz

        // Transient detection
        float transientStrength = 0.0f;
        bool isTransient = false;

        // Spectral characteristics
        float spectralCentroid = 0.0f;   // "Brightness"
        float spectralSpread = 0.0f;     // Width of spectrum
        float spectralFlux = 0.0f;       // Rate of change

        // Beat detection
        bool isBeat = false;
        float beatConfidence = 0.0f;
        float bpm = 120.0f;

        // Pitch detection
        float dominantFrequency = 0.0f;
        int dominantNote = 60;  // MIDI note
    };

    void processBlock(const float* samples, int numSamples) {
        // Simple energy-based analysis
        float energy = 0.0f;
        for (int i = 0; i < numSamples; i++) {
            energy += samples[i] * samples[i];
        }
        energy = std::sqrt(energy / numSamples);

        // Update result
        result.totalEnergy = result.totalEnergy * 0.9f + energy * 0.1f;

        // Simplified band analysis
        result.bass = result.totalEnergy * 1.2f;
        result.lowMid = result.totalEnergy * 0.9f;
        result.mid = result.totalEnergy * 0.8f;
        result.highMid = result.totalEnergy * 0.6f;
        result.high = result.totalEnergy * 0.4f;

        // Transient detection via energy derivative
        float energyDerivative = energy - prevEnergy;
        result.transientStrength = std::max(0.0f, energyDerivative * 10.0f);
        result.isTransient = result.transientStrength > 0.3f;
        prevEnergy = energy;

        // Spectral centroid approximation
        result.spectralCentroid = (result.highMid + result.high) /
                                  (result.bass + result.lowMid + result.mid + result.highMid + result.high + 0.001f);

        // Beat detection (simplified onset detection)
        detectBeat(energy);
    }

    const AnalysisResult& getResult() const { return result; }

private:
    AnalysisResult result;
    float prevEnergy = 0.0f;

    // Beat detection state
    float beatAccumulator = 0.0f;
    float lastBeatTime = 0.0f;
    float currentTime = 0.0f;
    std::array<float, 8> beatHistory = {};
    int beatHistoryIndex = 0;

    void detectBeat(float energy) {
        // Simple threshold-based beat detection
        float threshold = 0.0f;
        for (float h : beatHistory) threshold += h;
        threshold = threshold / 8.0f * 1.5f;

        result.isBeat = energy > threshold && energy > 0.1f;
        if (result.isBeat) {
            result.beatConfidence = std::min(1.0f, (energy - threshold) / threshold);
        }

        beatHistory[beatHistoryIndex] = energy;
        beatHistoryIndex = (beatHistoryIndex + 1) % 8;
    }
};

//==============================================================================
// Visual Parameter Mapping
//==============================================================================
struct VisualParameter {
    juce::String name;
    float value = 0.0f;
    float smoothedValue = 0.0f;
    float smoothingFactor = 0.1f;  // 0 = instant, 1 = very slow

    void update() {
        smoothedValue = smoothedValue * (1.0f - smoothingFactor) + value * smoothingFactor;
    }
};

struct VisualMapping {
    enum class Source {
        AudioBass,
        AudioMid,
        AudioHigh,
        AudioEnergy,
        AudioTransient,
        AudioSpectralCentroid,
        AudioBeat,
        SoundBrightness,
        SoundWarmth,
        SoundThickness,
        SoundMovement,
        SoundSpace,
        SoundAggression,
        MPEPressure,
        MPESlide,
        MPEPitchBend,
        MIDIModWheel,
        MIDIExpression,
        OSCCustom,
        LFO,
        Envelope
    };

    Source source = Source::AudioEnergy;
    juce::String targetParameter;

    float minOutput = 0.0f;
    float maxOutput = 1.0f;
    float curve = 1.0f;          // 1.0 = linear
    float smoothing = 0.1f;
    bool invert = false;

    // For LFO source
    float lfoRate = 1.0f;
    int lfoShape = 0;  // 0=sine, 1=triangle, 2=saw, 3=square

    float apply(float input) const {
        if (invert) input = 1.0f - input;

        // Apply curve
        if (curve != 1.0f) {
            input = std::pow(input, curve);
        }

        return minOutput + input * (maxOutput - minOutput);
    }
};

//==============================================================================
// Visual Engine Interface
//==============================================================================
struct VisualState {
    // Colors (HSL for easier manipulation)
    float primaryHue = 0.6f;
    float primarySaturation = 0.8f;
    float primaryLightness = 0.5f;

    float secondaryHue = 0.3f;
    float secondarySaturation = 0.7f;
    float secondaryLightness = 0.4f;

    float backgroundHue = 0.7f;
    float backgroundSaturation = 0.3f;
    float backgroundLightness = 0.1f;

    // Geometry
    float scale = 1.0f;
    float rotation = 0.0f;
    float positionX = 0.0f;
    float positionY = 0.0f;
    float positionZ = 0.0f;

    // Effects
    float blur = 0.0f;
    float glow = 0.5f;
    float distortion = 0.0f;
    float noiseAmount = 0.0f;
    float kaleidoscopeSegments = 1.0f;

    // Particle systems
    float particleEmissionRate = 0.5f;
    float particleSize = 0.5f;
    float particleSpeed = 0.5f;
    float particleLifetime = 0.5f;

    // Camera
    float cameraDistance = 5.0f;
    float cameraOrbitSpeed = 0.1f;
    float cameraShake = 0.0f;

    // Morphing
    float morphPosition = 0.0f;
    int currentScene = 0;

    juce::Colour getPrimaryColour() const {
        return juce::Colour::fromHSL(primaryHue, primarySaturation, primaryLightness, 1.0f);
    }

    juce::Colour getSecondaryColour() const {
        return juce::Colour::fromHSL(secondaryHue, secondarySaturation, secondaryLightness, 1.0f);
    }

    juce::Colour getBackgroundColour() const {
        return juce::Colour::fromHSL(backgroundHue, backgroundSaturation, backgroundLightness, 1.0f);
    }
};

//==============================================================================
// Visual Presets / Scenes
//==============================================================================
struct VisualScene {
    juce::String name;
    VisualState baseState;
    std::vector<VisualMapping> mappings;

    // Scene behavior
    float transitionTime = 1.0f;
    bool autoAdvance = false;
    float autoAdvanceTime = 30.0f;
};

class VisualSceneManager {
public:
    void addScene(const VisualScene& scene) {
        scenes.push_back(scene);
    }

    void setCurrentScene(int index) {
        if (index >= 0 && index < scenes.size()) {
            previousSceneIndex = currentSceneIndex;
            currentSceneIndex = index;
            transitionProgress = 0.0f;
            isTransitioning = true;
        }
    }

    void nextScene() {
        setCurrentScene((currentSceneIndex + 1) % scenes.size());
    }

    void update(float deltaTime) {
        if (isTransitioning) {
            transitionProgress += deltaTime / scenes[currentSceneIndex].transitionTime;
            if (transitionProgress >= 1.0f) {
                transitionProgress = 1.0f;
                isTransitioning = false;
            }
        }

        // Auto-advance
        if (scenes[currentSceneIndex].autoAdvance) {
            autoAdvanceTimer += deltaTime;
            if (autoAdvanceTimer >= scenes[currentSceneIndex].autoAdvanceTime) {
                autoAdvanceTimer = 0.0f;
                nextScene();
            }
        }
    }

    VisualState getCurrentState() const {
        if (!isTransitioning || previousSceneIndex < 0) {
            return scenes[currentSceneIndex].baseState;
        }

        // Interpolate between scenes
        return interpolateStates(scenes[previousSceneIndex].baseState,
                                 scenes[currentSceneIndex].baseState,
                                 transitionProgress);
    }

    const VisualScene& getCurrentScene() const { return scenes[currentSceneIndex]; }
    int getCurrentSceneIndex() const { return currentSceneIndex; }

private:
    std::vector<VisualScene> scenes;
    int currentSceneIndex = 0;
    int previousSceneIndex = -1;
    float transitionProgress = 1.0f;
    bool isTransitioning = false;
    float autoAdvanceTimer = 0.0f;

    VisualState interpolateStates(const VisualState& a, const VisualState& b, float t) const {
        VisualState result;

        // Interpolate all values
        result.primaryHue = a.primaryHue + (b.primaryHue - a.primaryHue) * t;
        result.primarySaturation = a.primarySaturation + (b.primarySaturation - a.primarySaturation) * t;
        result.primaryLightness = a.primaryLightness + (b.primaryLightness - a.primaryLightness) * t;

        result.scale = a.scale + (b.scale - a.scale) * t;
        result.rotation = a.rotation + (b.rotation - a.rotation) * t;
        result.blur = a.blur + (b.blur - a.blur) * t;
        result.glow = a.glow + (b.glow - a.glow) * t;
        result.distortion = a.distortion + (b.distortion - a.distortion) * t;

        result.particleEmissionRate = a.particleEmissionRate + (b.particleEmissionRate - a.particleEmissionRate) * t;
        result.particleSize = a.particleSize + (b.particleSize - a.particleSize) * t;

        return result;
    }
};

//==============================================================================
// Main Visual-Sound Coupling Engine
//==============================================================================
class VisualSoundCoupling {
public:
    VisualSoundCoupling() {
        setupDefaultMappings();
        setupDefaultScenes();
    }

    //==========================================================================
    // Audio Input
    //==========================================================================
    void processAudio(const float* samples, int numSamples) {
        audioAnalyzer.processBlock(samples, numSamples);
    }

    //==========================================================================
    // Sound DNA Integration
    //==========================================================================
    void setSoundDNA(const SoundDNA& dna) {
        currentSoundDNA = dna;

        // Map sound DNA to visual characteristics
        mapSoundToVisuals(dna);
    }

    //==========================================================================
    // Automation Integration
    //==========================================================================
    void setAutomationEngine(SuperAutomationEngine* engine) {
        automationEngine = engine;

        // Register visual parameters for automation
        if (automationEngine) {
            automationEngine->registerParameter("visual.hue",
                [this](float v) { visualState.primaryHue = v; },
                [this]() { return visualState.primaryHue; });

            automationEngine->registerParameter("visual.saturation",
                [this](float v) { visualState.primarySaturation = v; },
                [this]() { return visualState.primarySaturation; });

            automationEngine->registerParameter("visual.glow",
                [this](float v) { visualState.glow = v; },
                [this]() { return visualState.glow; });

            automationEngine->registerParameter("visual.scale",
                [this](float v) { visualState.scale = v; },
                [this]() { return visualState.scale; });

            automationEngine->registerParameter("visual.rotation",
                [this](float v) { visualState.rotation = v; },
                [this]() { return visualState.rotation; });

            automationEngine->registerParameter("visual.particles",
                [this](float v) { visualState.particleEmissionRate = v; },
                [this]() { return visualState.particleEmissionRate; });
        }
    }

    //==========================================================================
    // MPE Visual Mapping
    //==========================================================================
    void processMPEVoice(int voiceIndex, const MPENote& note) {
        // Map MPE expression to visual parameters per voice
        MPEVisualVoice& visualVoice = mpeVisualVoices[voiceIndex];

        visualVoice.active = note.isActive;
        visualVoice.hue = (note.noteNumber % 12) / 12.0f;  // Note to color
        visualVoice.brightness = note.strike;              // Velocity to brightness
        visualVoice.size = 0.3f + note.pressure * 0.7f;    // Pressure to size
        visualVoice.xPosition = note.pitchBend;            // Pitch bend to X
        visualVoice.yPosition = note.slide;                // Slide to Y

        if (onMPEVisualUpdate) {
            onMPEVisualUpdate(voiceIndex, visualVoice);
        }
    }

    //==========================================================================
    // Update Loop
    //==========================================================================
    void update(float deltaTime) {
        currentTime += deltaTime;

        // Get audio analysis
        const auto& audio = audioAnalyzer.getResult();

        // Update scene manager
        sceneManager.update(deltaTime);
        visualState = sceneManager.getCurrentState();

        // Apply mappings
        applyMappings(audio, deltaTime);

        // Beat-reactive updates
        if (audio.isBeat) {
            onBeat(audio.beatConfidence);
        }

        // Transient effects
        if (audio.isTransient) {
            onTransient(audio.transientStrength);
        }

        // LFO updates
        updateLFOs(deltaTime);

        // Notify listeners
        if (onVisualStateChanged) {
            onVisualStateChanged(visualState);
        }
    }

    //==========================================================================
    // Mapping Management
    //==========================================================================
    void addMapping(const VisualMapping& mapping) {
        mappings.push_back(mapping);
    }

    void clearMappings() {
        mappings.clear();
    }

    //==========================================================================
    // Getters
    //==========================================================================
    const VisualState& getVisualState() const { return visualState; }
    const AudioAnalyzer::AnalysisResult& getAudioAnalysis() const { return audioAnalyzer.getResult(); }
    VisualSceneManager& getSceneManager() { return sceneManager; }

    //==========================================================================
    // Callbacks
    //==========================================================================
    std::function<void(const VisualState&)> onVisualStateChanged;
    std::function<void(int, const MPEVisualVoice&)> onMPEVisualUpdate;
    std::function<void(float beatStrength)> onBeatDetected;

    struct MPEVisualVoice {
        bool active = false;
        float hue = 0.0f;
        float brightness = 0.5f;
        float size = 0.5f;
        float xPosition = 0.0f;
        float yPosition = 0.5f;
    };

private:
    AudioAnalyzer audioAnalyzer;
    VisualState visualState;
    VisualSceneManager sceneManager;
    SoundDNA currentSoundDNA;
    SuperAutomationEngine* automationEngine = nullptr;

    std::vector<VisualMapping> mappings;
    std::array<MPEVisualVoice, 15> mpeVisualVoices;

    float currentTime = 0.0f;
    std::array<float, 4> lfoPhases = {0.0f, 0.0f, 0.0f, 0.0f};

    void mapSoundToVisuals(const SoundDNA& dna) {
        // Sound brightness -> Visual brightness
        visualState.primaryLightness = 0.3f + dna.brightness * 0.4f;

        // Sound warmth -> Hue (cold = blue, warm = orange)
        visualState.primaryHue = 0.6f - dna.warmth * 0.4f;

        // Sound space -> Glow and blur
        visualState.glow = 0.2f + dna.space * 0.6f;
        visualState.blur = dna.space * 0.3f;

        // Sound movement -> Animation speed
        visualState.cameraOrbitSpeed = 0.05f + dna.movement * 0.2f;

        // Sound aggression -> Distortion and saturation
        visualState.distortion = dna.aggression * 0.4f;
        visualState.primarySaturation = 0.5f + dna.aggression * 0.4f;

        // Sound complexity -> Particles and kaleidoscope
        visualState.particleEmissionRate = 0.2f + dna.complexity * 0.6f;
        visualState.kaleidoscopeSegments = 1.0f + dna.complexity * 7.0f;
    }

    void applyMappings(const AudioAnalyzer::AnalysisResult& audio, float deltaTime) {
        for (const auto& mapping : mappings) {
            float sourceValue = getSourceValue(mapping.source, audio);
            float mappedValue = mapping.apply(sourceValue);

            // Apply smoothing
            // (In real implementation, track smoothed values per mapping)

            setTargetParameter(mapping.targetParameter, mappedValue);
        }
    }

    float getSourceValue(VisualMapping::Source source, const AudioAnalyzer::AnalysisResult& audio) {
        switch (source) {
            case VisualMapping::Source::AudioBass: return audio.bass;
            case VisualMapping::Source::AudioMid: return audio.mid;
            case VisualMapping::Source::AudioHigh: return audio.high;
            case VisualMapping::Source::AudioEnergy: return audio.totalEnergy;
            case VisualMapping::Source::AudioTransient: return audio.transientStrength;
            case VisualMapping::Source::AudioSpectralCentroid: return audio.spectralCentroid;
            case VisualMapping::Source::AudioBeat: return audio.isBeat ? 1.0f : 0.0f;

            case VisualMapping::Source::SoundBrightness: return currentSoundDNA.brightness;
            case VisualMapping::Source::SoundWarmth: return currentSoundDNA.warmth;
            case VisualMapping::Source::SoundThickness: return currentSoundDNA.thickness;
            case VisualMapping::Source::SoundMovement: return currentSoundDNA.movement;
            case VisualMapping::Source::SoundSpace: return currentSoundDNA.space;
            case VisualMapping::Source::SoundAggression: return currentSoundDNA.aggression;

            case VisualMapping::Source::LFO: return getLFOValue(0);

            default: return 0.0f;
        }
    }

    void setTargetParameter(const juce::String& param, float value) {
        if (param == "primaryHue") visualState.primaryHue = value;
        else if (param == "primarySaturation") visualState.primarySaturation = value;
        else if (param == "primaryLightness") visualState.primaryLightness = value;
        else if (param == "scale") visualState.scale = value;
        else if (param == "rotation") visualState.rotation = value;
        else if (param == "glow") visualState.glow = value;
        else if (param == "blur") visualState.blur = value;
        else if (param == "distortion") visualState.distortion = value;
        else if (param == "particleRate") visualState.particleEmissionRate = value;
        else if (param == "particleSize") visualState.particleSize = value;
        else if (param == "cameraShake") visualState.cameraShake = value;
    }

    void onBeat(float strength) {
        // Pulse effects on beat
        visualState.scale = 1.0f + strength * 0.1f;
        visualState.glow = std::min(1.0f, visualState.glow + strength * 0.3f);

        if (onBeatDetected) onBeatDetected(strength);
    }

    void onTransient(float strength) {
        // Flash on transients
        visualState.primaryLightness = std::min(1.0f, visualState.primaryLightness + strength * 0.2f);
        visualState.cameraShake = strength * 0.5f;
    }

    void updateLFOs(float deltaTime) {
        for (int i = 0; i < 4; i++) {
            float rate = 0.5f * (i + 1);  // Different rates per LFO
            lfoPhases[i] = std::fmod(lfoPhases[i] + rate * deltaTime, 1.0f);
        }
    }

    float getLFOValue(int lfoIndex, int shape = 0) {
        float phase = lfoPhases[lfoIndex];
        switch (shape) {
            case 0: return 0.5f + 0.5f * std::sin(phase * 2.0f * M_PI);  // Sine
            case 1: return phase < 0.5f ? phase * 2.0f : 2.0f - phase * 2.0f;  // Triangle
            case 2: return phase;  // Saw
            case 3: return phase < 0.5f ? 1.0f : 0.0f;  // Square
            default: return 0.5f;
        }
    }

    void setupDefaultMappings() {
        // Bass -> Scale pulse
        VisualMapping bassScale;
        bassScale.source = VisualMapping::Source::AudioBass;
        bassScale.targetParameter = "scale";
        bassScale.minOutput = 1.0f;
        bassScale.maxOutput = 1.15f;
        bassScale.smoothing = 0.2f;
        mappings.push_back(bassScale);

        // High -> Glow
        VisualMapping highGlow;
        highGlow.source = VisualMapping::Source::AudioHigh;
        highGlow.targetParameter = "glow";
        highGlow.minOutput = 0.3f;
        highGlow.maxOutput = 0.9f;
        mappings.push_back(highGlow);

        // Energy -> Particle rate
        VisualMapping energyParticles;
        energyParticles.source = VisualMapping::Source::AudioEnergy;
        energyParticles.targetParameter = "particleRate";
        energyParticles.minOutput = 0.1f;
        energyParticles.maxOutput = 1.0f;
        mappings.push_back(energyParticles);

        // Transient -> Camera shake
        VisualMapping transientShake;
        transientShake.source = VisualMapping::Source::AudioTransient;
        transientShake.targetParameter = "cameraShake";
        transientShake.minOutput = 0.0f;
        transientShake.maxOutput = 0.3f;
        transientShake.smoothing = 0.3f;
        mappings.push_back(transientShake);
    }

    void setupDefaultScenes() {
        // Ambient scene
        VisualScene ambient;
        ambient.name = "Ambient";
        ambient.baseState.primaryHue = 0.6f;
        ambient.baseState.primarySaturation = 0.5f;
        ambient.baseState.glow = 0.7f;
        ambient.baseState.blur = 0.2f;
        ambient.baseState.particleEmissionRate = 0.3f;
        ambient.transitionTime = 3.0f;
        sceneManager.addScene(ambient);

        // Energetic scene
        VisualScene energetic;
        energetic.name = "Energetic";
        energetic.baseState.primaryHue = 0.0f;
        energetic.baseState.primarySaturation = 0.9f;
        energetic.baseState.glow = 0.9f;
        energetic.baseState.particleEmissionRate = 0.8f;
        energetic.baseState.distortion = 0.2f;
        energetic.transitionTime = 0.5f;
        sceneManager.addScene(energetic);

        // Deep scene
        VisualScene deep;
        deep.name = "Deep";
        deep.baseState.primaryHue = 0.75f;
        deep.baseState.primarySaturation = 0.7f;
        deep.baseState.primaryLightness = 0.3f;
        deep.baseState.glow = 0.4f;
        deep.baseState.particleSize = 0.8f;
        deep.baseState.cameraDistance = 8.0f;
        deep.transitionTime = 2.0f;
        sceneManager.addScene(deep);
    }
};

//==============================================================================
// Visual Effect Generators
//==============================================================================
class AudioReactiveEffects {
public:
    struct EffectParams {
        float intensity = 1.0f;
        float speed = 1.0f;
        float color = 0.5f;
    };

    // Generate color based on audio
    static juce::Colour audioToColor(const AudioAnalyzer::AnalysisResult& audio) {
        // Map spectral centroid to hue
        float hue = 0.6f - audio.spectralCentroid * 0.4f;

        // Map energy to saturation
        float saturation = 0.5f + audio.totalEnergy * 0.4f;

        // Map transients to lightness
        float lightness = 0.4f + audio.transientStrength * 0.3f;

        return juce::Colour::fromHSL(hue, saturation, lightness, 1.0f);
    }

    // Generate waveform visualization points
    static std::vector<juce::Point<float>> generateWaveform(
        const float* samples, int numSamples, float width, float height) {

        std::vector<juce::Point<float>> points;
        points.reserve(numSamples);

        for (int i = 0; i < numSamples; i++) {
            float x = (float(i) / numSamples) * width;
            float y = (height / 2.0f) + samples[i] * (height / 2.0f);
            points.push_back({x, y});
        }

        return points;
    }

    // Generate spectrum bar positions
    static std::vector<float> generateSpectrumBars(
        const AudioAnalyzer::AnalysisResult& audio, int numBars) {

        std::vector<float> bars(numBars);
        int bandsPerBar = AudioAnalyzer::NUM_BANDS / numBars;

        for (int i = 0; i < numBars; i++) {
            float sum = 0.0f;
            for (int j = 0; j < bandsPerBar; j++) {
                int bandIndex = i * bandsPerBar + j;
                if (bandIndex < AudioAnalyzer::NUM_BANDS) {
                    sum += audio.bands[bandIndex];
                }
            }
            bars[i] = sum / bandsPerBar;
        }

        return bars;
    }

    // Circular visualizer points
    static std::vector<juce::Point<float>> generateCircularVis(
        const AudioAnalyzer::AnalysisResult& audio, float centerX, float centerY, float radius) {

        std::vector<juce::Point<float>> points;
        points.reserve(AudioAnalyzer::NUM_BANDS);

        for (int i = 0; i < AudioAnalyzer::NUM_BANDS; i++) {
            float angle = (float(i) / AudioAnalyzer::NUM_BANDS) * 2.0f * M_PI;
            float r = radius * (1.0f + audio.bands[i] * 0.5f);

            float x = centerX + std::cos(angle) * r;
            float y = centerY + std::sin(angle) * r;
            points.push_back({x, y});
        }

        return points;
    }
};

//==============================================================================
// Integration UI Component
//==============================================================================
class VisualSoundCouplingUI : public juce::Component,
                               public juce::Timer {
public:
    VisualSoundCouplingUI(VisualSoundCoupling& coupling)
        : coupling(coupling) {
        startTimerHz(60);
    }

    void paint(juce::Graphics& g) override {
        const auto& state = coupling.getVisualState();
        const auto& audio = coupling.getAudioAnalysis();

        // Background
        g.fillAll(state.getBackgroundColour());

        // Spectrum visualization
        auto spectrumBars = AudioReactiveEffects::generateSpectrumBars(audio, 32);
        float barWidth = getWidth() / 32.0f;

        for (int i = 0; i < 32; i++) {
            float barHeight = spectrumBars[i] * getHeight() * 0.8f;
            float x = i * barWidth;
            float y = getHeight() - barHeight;

            // Gradient based on frequency
            float hue = state.primaryHue + (float(i) / 32.0f) * 0.2f;
            g.setColour(juce::Colour::fromHSL(hue, state.primarySaturation, state.primaryLightness, 0.8f));
            g.fillRect(x + 1, y, barWidth - 2, barHeight);
        }

        // Glow overlay
        if (state.glow > 0.3f) {
            g.setColour(state.getPrimaryColour().withAlpha(state.glow * 0.3f));
            g.fillRect(getLocalBounds());
        }

        // Beat indicator
        if (audio.isBeat) {
            g.setColour(juce::Colours::white.withAlpha(audio.beatConfidence * 0.5f));
            g.drawRect(getLocalBounds(), 4);
        }
    }

    void timerCallback() override {
        repaint();
    }

private:
    VisualSoundCoupling& coupling;
};

} // namespace Visual
} // namespace Echoelmusic
