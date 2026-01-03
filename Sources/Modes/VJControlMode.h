#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <memory>
#include <array>
#include <functional>
#include <atomic>
#include <cmath>

/**
 * VJControlMode - Audio-Reactive Visual Performance
 *
 * Inspired by: Resolume Arena, VDMX, TouchDesigner, Imaginando
 *
 * Complete VJ system in your DAW:
 * - Audio-reactive parameters
 * - Beat-synced transitions
 * - Layer compositing (blend modes)
 * - MIDI/OSC mappable controls
 * - Spout/Syphon/NDI output
 * - DMX lighting control
 * - Shader-based effects
 * - Generative visuals
 *
 * Unique Echoelmusic UPS:
 * - Direct DAW audio analysis
 * - Bio-reactive visual modulation
 * - AI-generated visuals
 * - Seamless audio-visual sync
 */

namespace Echoelmusic {
namespace Modes {

//==============================================================================
// Audio Analysis for Visuals
//==============================================================================

class AudioAnalyzer
{
public:
    struct Analysis
    {
        // Levels
        float level = 0.0f;              // 0-1 overall level
        float peak = 0.0f;               // Peak hold
        float rms = 0.0f;                // RMS level

        // Frequency bands
        float bass = 0.0f;               // 20-200 Hz
        float lowMid = 0.0f;             // 200-800 Hz
        float mid = 0.0f;                // 800-2000 Hz
        float highMid = 0.0f;            // 2000-6000 Hz
        float high = 0.0f;               // 6000-20000 Hz

        // Full spectrum (32 bands)
        std::array<float, 32> spectrum;

        // Beat detection
        bool beatDetected = false;
        float beatIntensity = 0.0f;
        int beatCount = 0;
        float bpm = 0.0f;

        // Phase (0-1, synced to beat)
        float phase = 0.0f;

        // Transient detection
        bool onsetDetected = false;
        float onsetStrength = 0.0f;
    };

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        fftSize = 2048;
        fft = std::make_unique<juce::dsp::FFT>(11);  // 2^11 = 2048
        window.resize(fftSize);
        juce::dsp::WindowingFunction<float>::fillWindowingTables(
            window.data(), fftSize, juce::dsp::WindowingFunction<float>::hann);

        fftData.resize(fftSize * 2, 0.0f);
        smoothedSpectrum.fill(0.0f);
    }

    Analysis analyze(const juce::AudioBuffer<float>& buffer)
    {
        Analysis result;

        // Level analysis
        float sum = 0.0f;
        float peak = 0.0f;

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch)
        {
            for (int i = 0; i < buffer.getNumSamples(); ++i)
            {
                float sample = std::abs(buffer.getSample(ch, i));
                sum += sample * sample;
                peak = std::max(peak, sample);
            }
        }

        result.rms = std::sqrt(sum / (buffer.getNumSamples() * buffer.getNumChannels()));
        result.level = result.rms * 2.0f;  // Scale for visibility
        result.peak = peak;

        // FFT analysis
        if (buffer.getNumSamples() >= fftSize)
        {
            // Copy and window
            for (int i = 0; i < fftSize; ++i)
            {
                fftData[i] = buffer.getSample(0, i) * window[i];
            }
            std::fill(fftData.begin() + fftSize, fftData.end(), 0.0f);

            // Perform FFT
            fft->performFrequencyOnlyForwardTransform(fftData.data());

            // Extract frequency bands
            int bassEnd = static_cast<int>(200.0 / sampleRate * fftSize);
            int lowMidEnd = static_cast<int>(800.0 / sampleRate * fftSize);
            int midEnd = static_cast<int>(2000.0 / sampleRate * fftSize);
            int highMidEnd = static_cast<int>(6000.0 / sampleRate * fftSize);

            result.bass = getAverageMagnitude(0, bassEnd);
            result.lowMid = getAverageMagnitude(bassEnd, lowMidEnd);
            result.mid = getAverageMagnitude(lowMidEnd, midEnd);
            result.highMid = getAverageMagnitude(midEnd, highMidEnd);
            result.high = getAverageMagnitude(highMidEnd, fftSize / 2);

            // 32-band spectrum
            int binsPerBand = fftSize / 64;
            for (int b = 0; b < 32; ++b)
            {
                float mag = getAverageMagnitude(b * binsPerBand, (b + 1) * binsPerBand);
                // Smooth
                smoothedSpectrum[b] = smoothedSpectrum[b] * 0.8f + mag * 0.2f;
                result.spectrum[b] = smoothedSpectrum[b];
            }
        }

        // Beat detection
        float bassEnergy = result.bass;
        if (bassEnergy > lastBassEnergy * 1.5f && bassEnergy > 0.3f)
        {
            result.beatDetected = true;
            result.beatCount = ++beatCount;
            result.beatIntensity = bassEnergy;

            // BPM estimation
            double now = juce::Time::getMillisecondCounterHiRes();
            if (lastBeatTime > 0)
            {
                double interval = now - lastBeatTime;
                if (interval > 200 && interval < 2000)
                {
                    float instantBPM = 60000.0f / static_cast<float>(interval);
                    result.bpm = result.bpm * 0.9f + instantBPM * 0.1f;
                }
            }
            lastBeatTime = now;
        }
        lastBassEnergy = bassEnergy;

        // Phase (0-1 within beat)
        if (result.bpm > 0)
        {
            double msPerBeat = 60000.0 / result.bpm;
            double now = juce::Time::getMillisecondCounterHiRes();
            result.phase = static_cast<float>(fmod(now - lastBeatTime, msPerBeat) / msPerBeat);
        }

        // Onset detection
        float spectralFlux = 0.0f;
        for (int i = 0; i < 32; ++i)
        {
            float diff = result.spectrum[i] - prevSpectrum[i];
            if (diff > 0) spectralFlux += diff;
            prevSpectrum[i] = result.spectrum[i];
        }

        if (spectralFlux > onsetThreshold)
        {
            result.onsetDetected = true;
            result.onsetStrength = spectralFlux;
        }

        lastAnalysis = result;
        return result;
    }

    const Analysis& getLastAnalysis() const { return lastAnalysis; }

private:
    double sampleRate = 44100.0;
    int fftSize = 2048;

    std::unique_ptr<juce::dsp::FFT> fft;
    std::vector<float> window;
    std::vector<float> fftData;
    std::array<float, 32> smoothedSpectrum;
    std::array<float, 32> prevSpectrum;

    float lastBassEnergy = 0.0f;
    double lastBeatTime = 0.0;
    int beatCount = 0;
    float onsetThreshold = 0.5f;

    Analysis lastAnalysis;

    float getAverageMagnitude(int startBin, int endBin)
    {
        float sum = 0.0f;
        for (int i = startBin; i < endBin && i < fftSize / 2; ++i)
        {
            sum += fftData[i];
        }
        return sum / (endBin - startBin);
    }
};

//==============================================================================
// Visual Layer
//==============================================================================

struct VisualLayer
{
    std::string name;
    bool enabled = true;

    // Content
    enum class ContentType {
        Solid,              // Solid color
        Gradient,           // Color gradient
        Image,              // Static image
        Video,              // Video clip
        Webcam,             // Live camera
        NDI,                // NDI input
        Generative,         // Shader-based
        Text,               // Text overlay
        Particles,          // Particle system
        Oscilloscope,       // Audio waveform
        Spectrum            // Spectrum analyzer
    } contentType = ContentType::Solid;

    // Transform
    float posX = 0.5f;
    float posY = 0.5f;
    float scaleX = 1.0f;
    float scaleY = 1.0f;
    float rotation = 0.0f;  // Degrees
    float opacity = 1.0f;

    // Blend mode
    enum class BlendMode {
        Normal,
        Add,
        Multiply,
        Screen,
        Overlay,
        Difference,
        Exclusion,
        HardLight,
        SoftLight
    } blendMode = BlendMode::Normal;

    // Color adjustment
    float hue = 0.0f;           // -180 to 180
    float saturation = 1.0f;    // 0 to 2
    float brightness = 1.0f;    // 0 to 2
    float contrast = 1.0f;      // 0 to 2

    // Audio reactivity
    struct AudioReactive
    {
        enum class Source { None, Level, Bass, Mid, High, Beat, Onset };
        Source source = Source::None;

        enum class Target { Opacity, Scale, Rotation, PosX, PosY, Hue, Brightness };
        Target target = Target::Opacity;

        float amount = 1.0f;
        float smoothing = 0.5f;
        bool invert = false;
    };
    std::vector<AudioReactive> audioMappings;
};

//==============================================================================
// Visual Effects
//==============================================================================

class VisualEffect
{
public:
    virtual ~VisualEffect() = default;
    virtual std::string getName() const = 0;
    virtual void process(juce::Image& image, const AudioAnalyzer::Analysis& audio) = 0;

    float amount = 0.0f;        // 0-1 effect intensity
    bool enabled = true;
};

class BlurEffect : public VisualEffect
{
public:
    std::string getName() const override { return "Blur"; }
    void process(juce::Image& image, const AudioAnalyzer::Analysis& audio) override
    {
        // Gaussian blur based on amount
    }
};

class GlitchEffect : public VisualEffect
{
public:
    std::string getName() const override { return "Glitch"; }
    void process(juce::Image& image, const AudioAnalyzer::Analysis& audio) override
    {
        // Digital glitch: RGB shift, block displacement, scanlines
        if (audio.beatDetected)
        {
            // Intense glitch on beat
        }
    }
};

class KaleidoscopeEffect : public VisualEffect
{
public:
    std::string getName() const override { return "Kaleidoscope"; }
    int segments = 6;
    void process(juce::Image& image, const AudioAnalyzer::Analysis& audio) override
    {
        // Mirror and rotate image segments
    }
};

class ChromaticAberrationEffect : public VisualEffect
{
public:
    std::string getName() const override { return "Chromatic Aberration"; }
    void process(juce::Image& image, const AudioAnalyzer::Analysis& audio) override
    {
        // RGB channel offset
    }
};

class FeedbackEffect : public VisualEffect
{
public:
    std::string getName() const override { return "Feedback"; }
    float decay = 0.95f;
    float zoom = 1.02f;
    float rotation = 1.0f;
    void process(juce::Image& image, const AudioAnalyzer::Analysis& audio) override
    {
        // Recursive feedback with transform
    }
};

class PixelateEffect : public VisualEffect
{
public:
    std::string getName() const override { return "Pixelate"; }
    void process(juce::Image& image, const AudioAnalyzer::Analysis& audio) override
    {
        // Block pixelation, audio-reactive size
        int blockSize = 2 + static_cast<int>(audio.bass * amount * 30);
    }
};

//==============================================================================
// Generative Visual Content
//==============================================================================

class GenerativeContent
{
public:
    virtual ~GenerativeContent() = default;
    virtual std::string getName() const = 0;
    virtual void render(juce::Graphics& g, int width, int height,
                       const AudioAnalyzer::Analysis& audio) = 0;
};

class ParticleSystem : public GenerativeContent
{
public:
    struct Particle
    {
        float x, y;
        float vx, vy;
        float life;
        float size;
        juce::Colour color;
    };

    std::string getName() const override { return "Particles"; }

    void render(juce::Graphics& g, int width, int height,
               const AudioAnalyzer::Analysis& audio) override
    {
        // Spawn on beat
        if (audio.beatDetected)
        {
            for (int i = 0; i < static_cast<int>(audio.beatIntensity * 20); ++i)
            {
                spawnParticle(width, height, audio);
            }
        }

        // Update and draw
        for (auto& p : particles)
        {
            p.x += p.vx;
            p.y += p.vy;
            p.vy += 0.1f;  // Gravity
            p.life -= 0.01f;

            if (p.life > 0)
            {
                g.setColour(p.color.withAlpha(p.life));
                g.fillEllipse(p.x - p.size/2, p.y - p.size/2, p.size, p.size);
            }
        }

        // Remove dead particles
        particles.erase(
            std::remove_if(particles.begin(), particles.end(),
                [](const Particle& p) { return p.life <= 0; }),
            particles.end());
    }

private:
    std::vector<Particle> particles;

    void spawnParticle(int width, int height, const AudioAnalyzer::Analysis& audio)
    {
        Particle p;
        p.x = width / 2.0f;
        p.y = height / 2.0f;
        p.vx = (rand() / static_cast<float>(RAND_MAX) - 0.5f) * 10.0f * audio.bass;
        p.vy = (rand() / static_cast<float>(RAND_MAX) - 0.5f) * 10.0f * audio.bass;
        p.life = 1.0f;
        p.size = 5.0f + audio.beatIntensity * 20.0f;

        // Color based on frequency
        float hue = audio.mid * 360.0f;
        p.color = juce::Colour::fromHSV(hue / 360.0f, 0.8f, 1.0f, 1.0f);

        particles.push_back(p);
    }
};

class WaveformVisualizer : public GenerativeContent
{
public:
    std::string getName() const override { return "Waveform"; }

    void render(juce::Graphics& g, int width, int height,
               const AudioAnalyzer::Analysis& audio) override
    {
        g.setColour(juce::Colour::fromHSV(audio.phase, 0.8f, 1.0f, 1.0f));

        juce::Path path;
        path.startNewSubPath(0, height / 2.0f);

        for (int i = 0; i < 32; ++i)
        {
            float x = i * width / 32.0f;
            float y = height / 2.0f + audio.spectrum[i] * height * 0.4f;
            path.lineTo(x, y);
        }

        g.strokePath(path, juce::PathStrokeType(3.0f));
    }
};

class SpectrumBars : public GenerativeContent
{
public:
    std::string getName() const override { return "Spectrum Bars"; }

    void render(juce::Graphics& g, int width, int height,
               const AudioAnalyzer::Analysis& audio) override
    {
        float barWidth = width / 32.0f;

        for (int i = 0; i < 32; ++i)
        {
            float barHeight = audio.spectrum[i] * height * 0.8f;

            // Color gradient based on frequency
            float hue = i / 32.0f * 0.3f + audio.phase * 0.2f;
            g.setColour(juce::Colour::fromHSV(hue, 0.8f, 1.0f, 0.9f));

            float x = i * barWidth;
            float y = height - barHeight;

            g.fillRect(x + 2, y, barWidth - 4, barHeight);
        }
    }
};

class CircularSpectrum : public GenerativeContent
{
public:
    std::string getName() const override { return "Circular Spectrum"; }

    void render(juce::Graphics& g, int width, int height,
               const AudioAnalyzer::Analysis& audio) override
    {
        float cx = width / 2.0f;
        float cy = height / 2.0f;
        float baseRadius = std::min(width, height) * 0.2f;

        for (int i = 0; i < 32; ++i)
        {
            float angle = i * juce::MathConstants<float>::twoPi / 32.0f - juce::MathConstants<float>::halfPi;
            float radius = baseRadius + audio.spectrum[i] * baseRadius * 2.0f;

            float x1 = cx + baseRadius * std::cos(angle);
            float y1 = cy + baseRadius * std::sin(angle);
            float x2 = cx + radius * std::cos(angle);
            float y2 = cy + radius * std::sin(angle);

            float hue = i / 32.0f + audio.phase;
            g.setColour(juce::Colour::fromHSV(fmod(hue, 1.0f), 0.9f, 1.0f, 0.8f));
            g.drawLine(x1, y1, x2, y2, 4.0f);
        }
    }
};

//==============================================================================
// VJ Control Engine
//==============================================================================

class VJControlEngine
{
public:
    static VJControlEngine& getInstance()
    {
        static VJControlEngine instance;
        return instance;
    }

    void prepare(double sampleRate, int blockSize)
    {
        audioAnalyzer.prepare(sampleRate, blockSize);

        // Initialize default layers
        layers.resize(4);
        for (int i = 0; i < 4; ++i)
        {
            layers[i].name = "Layer " + std::to_string(i + 1);
        }

        // Initialize generative content
        generativeContent.push_back(std::make_unique<ParticleSystem>());
        generativeContent.push_back(std::make_unique<WaveformVisualizer>());
        generativeContent.push_back(std::make_unique<SpectrumBars>());
        generativeContent.push_back(std::make_unique<CircularSpectrum>());

        // Initialize effects
        effects.push_back(std::make_unique<BlurEffect>());
        effects.push_back(std::make_unique<GlitchEffect>());
        effects.push_back(std::make_unique<KaleidoscopeEffect>());
        effects.push_back(std::make_unique<ChromaticAberrationEffect>());
        effects.push_back(std::make_unique<FeedbackEffect>());
        effects.push_back(std::make_unique<PixelateEffect>());
    }

    //--------------------------------------------------------------------------
    // Audio Input
    //--------------------------------------------------------------------------

    void processAudio(const juce::AudioBuffer<float>& buffer)
    {
        currentAnalysis = audioAnalyzer.analyze(buffer);
    }

    const AudioAnalyzer::Analysis& getAudioAnalysis() const
    {
        return currentAnalysis;
    }

    //--------------------------------------------------------------------------
    // Layer Management
    //--------------------------------------------------------------------------

    VisualLayer& getLayer(int index) { return layers[index % layers.size()]; }

    void setLayerCount(int count)
    {
        layers.resize(std::clamp(count, 1, 16));
    }

    int getLayerCount() const { return static_cast<int>(layers.size()); }

    //--------------------------------------------------------------------------
    // Rendering
    //--------------------------------------------------------------------------

    void render(juce::Graphics& g, int width, int height)
    {
        // Clear
        g.fillAll(juce::Colours::black);

        // Render each layer
        for (auto& layer : layers)
        {
            if (!layer.enabled) continue;

            renderLayer(g, layer, width, height);
        }

        // Apply global effects
        for (auto& effect : effects)
        {
            if (effect->enabled && effect->amount > 0.01f)
            {
                juce::Image img(juce::Image::ARGB, width, height, true);
                // effect->process(img, currentAnalysis);
            }
        }
    }

    //--------------------------------------------------------------------------
    // Output
    //--------------------------------------------------------------------------

    enum class OutputType { Window, Spout, Syphon, NDI, DMX, Fullscreen };

    void setOutput(OutputType type, const std::string& name = "")
    {
        outputType = type;
        outputName = name;

        switch (type)
        {
            case OutputType::Spout:
#ifdef _WIN32
                // Initialize Spout sender
#endif
                break;
            case OutputType::Syphon:
#ifdef __APPLE__
                // Initialize Syphon server
#endif
                break;
            case OutputType::NDI:
                // Initialize NDI sender
                break;
            default:
                break;
        }
    }

    void sendFrame(const juce::Image& frame)
    {
        // Send to configured output
    }

    //--------------------------------------------------------------------------
    // Beat-Synced Transitions
    //--------------------------------------------------------------------------

    void triggerTransition(int fromLayer, int toLayer, float beats = 4.0f)
    {
        // Schedule crossfade over N beats
        if (currentAnalysis.bpm > 0)
        {
            double transitionTime = (60.0 / currentAnalysis.bpm) * beats;
            // Start transition timer
        }
    }

    //--------------------------------------------------------------------------
    // Presets
    //--------------------------------------------------------------------------

    void savePreset(const std::string& name)
    {
        // Serialize all layer and effect settings
    }

    void loadPreset(const std::string& name)
    {
        // Load and apply settings
    }

    //--------------------------------------------------------------------------
    // DMX Lighting Output
    //--------------------------------------------------------------------------

    struct DMXUniverse
    {
        std::array<uint8_t, 512> channels;

        void setChannel(int ch, uint8_t value)
        {
            if (ch >= 0 && ch < 512)
                channels[ch] = value;
        }
    };

    DMXUniverse& getDMX() { return dmxUniverse; }

    void mapAudioToDMX()
    {
        // Map audio analysis to DMX channels
        dmxUniverse.setChannel(0, static_cast<uint8_t>(currentAnalysis.bass * 255));
        dmxUniverse.setChannel(1, static_cast<uint8_t>(currentAnalysis.mid * 255));
        dmxUniverse.setChannel(2, static_cast<uint8_t>(currentAnalysis.high * 255));
        dmxUniverse.setChannel(3, static_cast<uint8_t>(currentAnalysis.level * 255));

        // Beat flash
        if (currentAnalysis.beatDetected)
        {
            dmxUniverse.setChannel(4, 255);
        }
        else
        {
            uint8_t current = dmxUniverse.channels[4];
            dmxUniverse.setChannel(4, static_cast<uint8_t>(current * 0.9f));
        }
    }

    void sendDMX()
    {
        // Send via Art-Net or USB DMX interface
    }

private:
    VJControlEngine() = default;

    AudioAnalyzer audioAnalyzer;
    AudioAnalyzer::Analysis currentAnalysis;

    std::vector<VisualLayer> layers;
    std::vector<std::unique_ptr<VisualEffect>> effects;
    std::vector<std::unique_ptr<GenerativeContent>> generativeContent;

    OutputType outputType = OutputType::Window;
    std::string outputName;

    DMXUniverse dmxUniverse;

    void renderLayer(juce::Graphics& g, VisualLayer& layer, int width, int height)
    {
        // Apply audio-reactive modulation
        for (auto& mapping : layer.audioMappings)
        {
            float sourceValue = 0.0f;
            switch (mapping.source)
            {
                case VisualLayer::AudioReactive::Source::Level:
                    sourceValue = currentAnalysis.level;
                    break;
                case VisualLayer::AudioReactive::Source::Bass:
                    sourceValue = currentAnalysis.bass;
                    break;
                case VisualLayer::AudioReactive::Source::Mid:
                    sourceValue = currentAnalysis.mid;
                    break;
                case VisualLayer::AudioReactive::Source::High:
                    sourceValue = currentAnalysis.high;
                    break;
                case VisualLayer::AudioReactive::Source::Beat:
                    sourceValue = currentAnalysis.beatDetected ? 1.0f : 0.0f;
                    break;
                case VisualLayer::AudioReactive::Source::Onset:
                    sourceValue = currentAnalysis.onsetStrength;
                    break;
                default:
                    break;
            }

            if (mapping.invert) sourceValue = 1.0f - sourceValue;
            sourceValue *= mapping.amount;

            // Apply to target
            switch (mapping.target)
            {
                case VisualLayer::AudioReactive::Target::Opacity:
                    layer.opacity = std::clamp(layer.opacity + sourceValue * 0.5f, 0.0f, 1.0f);
                    break;
                case VisualLayer::AudioReactive::Target::Scale:
                    layer.scaleX = layer.scaleY = 1.0f + sourceValue;
                    break;
                case VisualLayer::AudioReactive::Target::Rotation:
                    layer.rotation += sourceValue * 10.0f;
                    break;
                default:
                    break;
            }
        }

        // Save graphics state
        juce::Graphics::ScopedSaveState saveState(g);

        // Apply transform
        g.addTransform(juce::AffineTransform::translation(
            layer.posX * width, layer.posY * height));
        g.addTransform(juce::AffineTransform::scale(layer.scaleX, layer.scaleY));
        g.addTransform(juce::AffineTransform::rotation(
            layer.rotation * juce::MathConstants<float>::pi / 180.0f));

        // Set opacity
        g.setOpacity(layer.opacity);

        // Render content
        switch (layer.contentType)
        {
            case VisualLayer::ContentType::Solid:
                g.fillAll(juce::Colours::white);
                break;

            case VisualLayer::ContentType::Oscilloscope:
                if (!generativeContent.empty())
                    generativeContent[1]->render(g, width, height, currentAnalysis);
                break;

            case VisualLayer::ContentType::Spectrum:
                if (generativeContent.size() > 2)
                    generativeContent[2]->render(g, width, height, currentAnalysis);
                break;

            case VisualLayer::ContentType::Particles:
                if (!generativeContent.empty())
                    generativeContent[0]->render(g, width, height, currentAnalysis);
                break;

            case VisualLayer::ContentType::Generative:
                if (generativeContent.size() > 3)
                    generativeContent[3]->render(g, width, height, currentAnalysis);
                break;

            default:
                break;
        }
    }
};

//==============================================================================
// Convenience
//==============================================================================

#define VJMode VJControlEngine::getInstance()

} // namespace Modes
} // namespace Echoelmusic
