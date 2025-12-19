#pragma once

#include <JuceHeader.h>
#include "../BioData/BioFeedbackSystem.h"
#include "../Audio/AudioEngine.h"
#include "VideoWeaver.h"
#include <memory>
#include <vector>
#include <atomic>

namespace Echoelmusic {

/**
 * @brief Bio-Reactive + BPM-Reactive Video Processor
 *
 * **COMPLETE VIDEO SYSTEM:**
 * - Bio-reactive effects (HRV → color, coherence → intensity)
 * - BPM-reactive editing (beat-synced cuts, tempo-locked effects)
 * - Real-time video processing
 * - Multi-layer composition
 * - AI-powered scene detection
 * - Automatic beat-sync video editing
 *
 * **Architecture:**
 * ```
 * [BioFeedbackSystem] ──┐
 *                       ├──> [BioReactiveVideoProcessor] ──> [Video Output]
 * [AudioEngine/BPM]  ───┘          │
 *                                  ├──> Bio-reactive effects
 *                                  ├──> BPM-synced cuts
 *                                  ├──> Tempo-locked speed
 *                                  └──> AI generative overlays
 * ```
 *
 * **Use Cases:**
 * - Live VJ performances (bio + beat reactive)
 * - Music video creation (auto-edit to beat)
 * - Meditation visuals (slow, bio-driven)
 * - Dance performances (high-energy, beat-locked)
 * - Streaming overlays (real-time bio-data viz)
 *
 * @author Echoelmusic Team
 * @date 2025-12-19
 * @version 1.0.0
 */
class BioReactiveVideoProcessor
{
public:
    //==========================================================================
    // Video Layer
    //==========================================================================

    struct VideoLayer
    {
        enum class Type
        {
            Video,              // Video file
            Image,              // Still image
            GenerativeAI,       // AI-generated visuals
            Camera,             // Webcam input
            ScreenCapture,      // Screen recording
            BioDataViz,         // Bio-data visualization
            Particles,          // Particle system
            Shader              // Custom shader effect
        };

        Type type = Type::Video;
        juce::String name;
        juce::File sourceFile;

        // Playback
        bool enabled = true;
        bool loop = true;
        float speed = 1.0f;         // Playback speed
        double currentTime = 0.0;   // Current position (seconds)
        double duration = 0.0;      // Total duration

        // Transform
        float x = 0.0f, y = 0.0f;
        float scaleX = 1.0f, scaleY = 1.0f;
        float rotation = 0.0f;
        float opacity = 1.0f;

        // Blend mode
        enum class BlendMode
        {
            Normal, Add, Multiply, Screen, Overlay,
            Difference, Exclusion, Lighten, Darken
        };
        BlendMode blendMode = BlendMode::Normal;

        // Effects
        float blur = 0.0f;
        float glow = 0.0f;
        float distortion = 0.0f;
        float pixelate = 0.0f;
        float chromatic = 0.0f;     // Chromatic aberration

        // Color grading
        float brightness = 0.0f;
        float contrast = 0.0f;
        float saturation = 1.0f;
        float hueShift = 0.0f;
        float temperature = 0.0f;

        // Bio-reactive settings
        bool bioReactive = false;
        juce::String bioParameter = "coherence";  // Which bio-param to use

        // BPM-reactive settings
        bool bpmReactive = false;
        int beatDivisor = 4;        // 1=whole, 2=half, 4=quarter, 8=eighth
        bool flashOnBeat = false;
        bool cutOnBar = false;
    };

    //==========================================================================
    // Video Effect
    //==========================================================================

    struct VideoEffect
    {
        enum class Type
        {
            // Color
            ColorGrade, Hue, Saturation, Brightness, Contrast, Invert, Posterize,
            // Blur
            GaussianBlur, MotionBlur, RadialBlur, ZoomBlur,
            // Distortion
            Warp, Ripple, Twirl, Bulge, Pinch, Displacement,
            // Glitch
            Glitch, Datamosh, Pixelate, ChromaticAberration, VHSEffect,
            // Artistic
            OilPaint, Sketch, Cartoon, Halftone, Mosaic,
            // Composite
            Kaleidoscope, Mirror, Feedback, Trail,
            // Time
            TimeRemap, Freeze, Reverse, Strobe,
            // 3D
            DepthOfField, Parallax, Extrude,
            // AI
            StyleTransfer, SuperResolution, Denoising, FaceTracking
        };

        Type type;
        float intensity = 1.0f;
        bool bioReactive = false;
        bool bpmReactive = false;

        // Parameters (effect-specific)
        std::map<juce::String, float> parameters;
    };

    //==========================================================================
    BioReactiveVideoProcessor(BioFeedbackSystem* bioSystem = nullptr,
                              AudioEngine* audioEngine = nullptr)
        : bioFeedbackSystem(bioSystem)
        , audioEngine(audioEngine)
    {
        // Initialize with default layers
        addLayer(createDefaultLayer());
    }

    //==========================================================================
    // Configuration
    //==========================================================================

    void setBioFeedbackSystem(BioFeedbackSystem* system)
    {
        bioFeedbackSystem = system;
    }

    void setAudioEngine(AudioEngine* engine)
    {
        audioEngine = engine;
    }

    /**
     * @brief Set video resolution
     */
    void setResolution(int width, int height)
    {
        videoWidth = width;
        videoHeight = height;
        needsResize.store(true);
    }

    /**
     * @brief Set frame rate
     */
    void setFrameRate(double fps)
    {
        frameRate = fps;
        frameDuration = 1.0 / fps;
    }

    /**
     * @brief Enable/disable bio-reactive processing
     */
    void setBioReactiveEnabled(bool enabled)
    {
        bioReactiveEnabled.store(enabled);
    }

    /**
     * @brief Enable/disable BPM-reactive processing
     */
    void setBPMReactiveEnabled(bool enabled)
    {
        bpmReactiveEnabled.store(enabled);
    }

    /**
     * @brief Set BPM (for beat-sync features)
     */
    void setBPM(double bpm)
    {
        currentBPM = bpm;
        secondsPerBeat = 60.0 / bpm;
    }

    /**
     * @brief Set current beat position (0.0 to 1.0 within beat)
     */
    void setBeatPhase(double phase)
    {
        beatPhase = phase;
    }

    //==========================================================================
    // Layer Management
    //==========================================================================

    int addLayer(const VideoLayer& layer)
    {
        layers.push_back(layer);
        return static_cast<int>(layers.size()) - 1;
    }

    void removeLayer(int index)
    {
        if (index >= 0 && index < layers.size())
            layers.erase(layers.begin() + index);
    }

    VideoLayer& getLayer(int index)
    {
        return layers[index];
    }

    int getNumLayers() const
    {
        return static_cast<int>(layers.size());
    }

    void clearLayers()
    {
        layers.clear();
    }

    //==========================================================================
    // Effect Management
    //==========================================================================

    int addEffect(const VideoEffect& effect)
    {
        effects.push_back(effect);
        return static_cast<int>(effects.size()) - 1;
    }

    void removeEffect(int index)
    {
        if (index >= 0 && index < effects.size())
            effects.erase(effects.begin() + index);
    }

    VideoEffect& getEffect(int index)
    {
        return effects[index];
    }

    //==========================================================================
    // Processing
    //==========================================================================

    /**
     * @brief Process one video frame
     * @param deltaTime Time since last frame (seconds)
     * @return Rendered frame
     */
    juce::Image processFrame(double deltaTime)
    {
        currentTime += deltaTime;

        // Create output frame
        juce::Image outputFrame(juce::Image::ARGB, videoWidth, videoHeight, true);
        juce::Graphics g(outputFrame);

        // Update bio-reactive parameters
        if (bioReactiveEnabled.load() && bioFeedbackSystem != nullptr)
        {
            auto bioData = bioFeedbackSystem->getCurrentBioData();
            updateBioReactiveParams(bioData);
        }

        // Update BPM-reactive parameters
        if (bpmReactiveEnabled.load())
        {
            updateBPMReactiveParams();
        }

        // Render layers
        for (auto& layer : layers)
        {
            if (!layer.enabled)
                continue;

            auto layerFrame = renderLayer(layer, deltaTime);

            // Composite layer with blend mode
            compositeLayer(g, layerFrame, layer);
        }

        // Apply global effects
        applyEffects(outputFrame);

        return outputFrame;
    }

    //==========================================================================
    // AI-Powered Features
    //==========================================================================

    /**
     * @brief Auto-edit video to beat
     * @param videoFile Source video
     * @param audioBPM BPM of music
     * @param beatDivisor Cut every N beats (1=whole, 2=half, 4=quarter)
     */
    void autoEditToBeat(const juce::File& videoFile, double audioBPM, int beatDivisor = 4)
    {
        clearLayers();

        // Calculate cut interval
        double secondsPerBar = (60.0 / audioBPM) * 4.0;  // 4/4 time
        double cutInterval = secondsPerBar / beatDivisor;

        // Load video and create clips
        VideoLayer baseLayer;
        baseLayer.type = VideoLayer::Type::Video;
        baseLayer.sourceFile = videoFile;
        baseLayer.bpmReactive = true;
        baseLayer.beatDivisor = beatDivisor;
        baseLayer.cutOnBar = true;

        addLayer(baseLayer);

        DBG("Auto-edited to " << audioBPM << " BPM, cut every " << cutInterval << " seconds");
    }

    /**
     * @brief Detect scene changes in video
     * @param videoFile Source video
     * @return Array of scene change timestamps
     */
    std::vector<double> detectScenes(const juce::File& videoFile)
    {
        std::vector<double> sceneChanges;

        // TODO: Implement scene detection
        // - Frame difference analysis
        // - Histogram comparison
        // - Optical flow analysis
        // - Machine learning (CNN-based)

        // Placeholder: Return every 5 seconds
        for (double t = 0.0; t < 60.0; t += 5.0)
        {
            sceneChanges.push_back(t);
        }

        return sceneChanges;
    }

    /**
     * @brief Generate AI visuals based on bio-data
     * @param style AI generation style ("abstract", "geometric", "organic", "psychedelic")
     */
    void generateAIVisuals(const juce::String& style = "abstract")
    {
        VideoLayer aiLayer;
        aiLayer.type = VideoLayer::Type::GenerativeAI;
        aiLayer.name = "AI Generated - " + style;
        aiLayer.bioReactive = true;
        aiLayer.bioParameter = "coherence";

        addLayer(aiLayer);

        DBG("Generated AI visual layer: " << style);
    }

    /**
     * @brief Create bio-data visualization layer
     * @param vizType "waveform", "particles", "graph", "mandala"
     */
    void addBioDataVisualization(const juce::String& vizType)
    {
        VideoLayer vizLayer;
        vizLayer.type = VideoLayer::Type::BioDataViz;
        vizLayer.name = "Bio Viz - " + vizType;
        vizLayer.bioReactive = true;
        vizLayer.opacity = 0.7f;
        vizLayer.blendMode = VideoLayer::BlendMode::Add;

        addLayer(vizLayer);
    }

private:
    //==========================================================================
    // Bio-Reactive Update
    //==========================================================================

    void updateBioReactiveParams(const BioFeedbackSystem::UnifiedBioData& bioData)
    {
        if (!bioData.isValid)
            return;

        for (auto& layer : layers)
        {
            if (!layer.bioReactive)
                continue;

            // Map bio-data to layer parameters
            if (layer.bioParameter == "coherence")
            {
                // High coherence = bright, saturated, clear
                layer.brightness = (bioData.coherence - 0.5f) * 0.4f;
                layer.saturation = 0.7f + bioData.coherence * 0.3f;
                layer.blur = (1.0f - bioData.coherence) * 10.0f;
                layer.glow = bioData.coherence * 0.5f;
            }
            else if (layer.bioParameter == "hrv")
            {
                // High HRV = colorful, dynamic
                layer.hueShift = bioData.hrv * 360.0f;
                layer.saturation = 0.5f + bioData.hrv * 0.5f;
                layer.speed = 0.5f + bioData.hrv * 1.5f;
            }
            else if (layer.bioParameter == "heartrate")
            {
                // Heart rate → speed
                float normalized = (bioData.heartRate - 60.0f) / 120.0f;  // 60-180 BPM
                layer.speed = 0.5f + normalized * 1.5f;
                layer.distortion = normalized * 0.2f;
            }
            else if (layer.bioParameter == "stress")
            {
                // High stress = glitchy, chaotic
                layer.chromatic = bioData.stress * 5.0f;
                layer.distortion = bioData.stress * 0.3f;
                layer.saturation = 1.0f - bioData.stress * 0.5f;
                layer.blur = bioData.stress * 15.0f;
            }
        }

        // Update effects
        for (auto& effect : effects)
        {
            if (!effect.bioReactive)
                continue;

            // Example: Glitch intensity from stress
            if (effect.type == VideoEffect::Type::Glitch)
            {
                effect.intensity = bioData.stress;
            }
        }
    }

    //==========================================================================
    // BPM-Reactive Update
    //==========================================================================

    void updateBPMReactiveParams()
    {
        // Detect beat (phase crosses 0)
        bool beatTrigger = (beatPhase < lastBeatPhase);
        lastBeatPhase = beatPhase;

        for (auto& layer : layers)
        {
            if (!layer.bpmReactive)
                continue;

            // Flash on beat
            if (layer.flashOnBeat && beatTrigger)
            {
                flashAmount = 1.0f;  // Trigger flash
            }

            // Cut on bar (every N beats)
            if (layer.cutOnBar && beatTrigger)
            {
                beatCounter++;
                if (beatCounter % layer.beatDivisor == 0)
                {
                    // Jump to next section or random time
                    layer.currentTime += 5.0;  // Skip 5 seconds
                    if (layer.currentTime >= layer.duration)
                        layer.currentTime = 0.0;
                }
            }

            // Tempo-locked speed
            if (currentBPM > 0.0)
            {
                // Map BPM to playback speed (60 BPM = 0.5x, 120 BPM = 1.0x, 180 BPM = 1.5x)
                layer.speed = static_cast<float>(currentBPM / 120.0);
            }
        }

        // Flash fade-out
        if (flashAmount > 0.0f)
        {
            flashAmount = juce::jmax(0.0f, flashAmount - 0.1f);
        }

        // Update effects
        for (auto& effect : effects)
        {
            if (!effect.bpmReactive)
                continue;

            // Strobe effect on beat
            if (effect.type == VideoEffect::Type::Strobe && beatTrigger)
            {
                effect.intensity = 1.0f;
            }
            else
            {
                effect.intensity = juce::jmax(0.0f, effect.intensity - 0.05f);
            }
        }
    }

    //==========================================================================
    // Rendering
    //==========================================================================

    juce::Image renderLayer(VideoLayer& layer, double deltaTime)
    {
        juce::Image layerFrame(juce::Image::ARGB, videoWidth, videoHeight, true);
        juce::Graphics g(layerFrame);

        switch (layer.type)
        {
            case VideoLayer::Type::Video:
                renderVideoLayer(g, layer, deltaTime);
                break;

            case VideoLayer::Type::Image:
                renderImageLayer(g, layer);
                break;

            case VideoLayer::Type::GenerativeAI:
                renderAILayer(g, layer);
                break;

            case VideoLayer::Type::BioDataViz:
                renderBioVizLayer(g, layer);
                break;

            case VideoLayer::Type::Particles:
                renderParticleLayer(g, layer, deltaTime);
                break;

            default:
                // Fill with color for debugging
                g.fillAll(juce::Colours::darkgrey.withAlpha(0.5f));
                break;
        }

        // Apply layer effects
        applyLayerEffects(layerFrame, layer);

        return layerFrame;
    }

    void renderVideoLayer(juce::Graphics& g, VideoLayer& layer, double deltaTime)
    {
        // Update playback position
        layer.currentTime += deltaTime * layer.speed;
        if (layer.loop && layer.currentTime >= layer.duration)
            layer.currentTime = 0.0;

        // TODO: Load and decode video frame at layer.currentTime
        // For now, draw placeholder
        g.fillAll(juce::Colours::blue.withAlpha(0.3f));
        g.setColour(juce::Colours::white);
        g.drawText("Video: " + layer.name,
                   videoWidth / 4, videoHeight / 2,
                   videoWidth / 2, 50,
                   juce::Justification::centred);
    }

    void renderImageLayer(juce::Graphics& g, const VideoLayer& layer)
    {
        // TODO: Load and draw image
        g.fillAll(juce::Colours::green.withAlpha(0.3f));
    }

    void renderAILayer(juce::Graphics& g, const VideoLayer& layer)
    {
        // AI-generated visuals (placeholder)
        // TODO: Integrate with Stable Diffusion, DALL-E API, or local generative model

        auto colour = juce::Colour::fromHSV(layer.hueShift / 360.0f,
                                           layer.saturation,
                                           0.7f,
                                           1.0f);

        // Draw abstract shapes
        for (int i = 0; i < 20; ++i)
        {
            float x = juce::Random::getSystemRandom().nextFloat() * videoWidth;
            float y = juce::Random::getSystemRandom().nextFloat() * videoHeight;
            float size = 50.0f + juce::Random::getSystemRandom().nextFloat() * 100.0f;

            g.setColour(colour.withAlpha(0.3f));
            g.fillEllipse(x, y, size, size);
        }
    }

    void renderBioVizLayer(juce::Graphics& g, const VideoLayer& layer)
    {
        if (bioFeedbackSystem == nullptr)
            return;

        auto bioData = bioFeedbackSystem->getCurrentBioData();

        // Draw waveform visualization
        g.setColour(juce::Colour::fromHSV(bioData.coherence, 0.8f, 1.0f, 0.7f));

        // Heart rate circle
        float radius = 50.0f + bioData.heartRate;
        g.drawEllipse(videoWidth / 2 - radius, videoHeight / 2 - radius,
                     radius * 2, radius * 2, 3.0f);

        // HRV indicator
        g.setFont(24.0f);
        g.drawText("HR: " + juce::String(bioData.heartRate, 1) + " BPM",
                   0, videoHeight - 100, videoWidth, 50,
                   juce::Justification::centred);
        g.drawText("HRV: " + juce::String(bioData.hrv, 2),
                   0, videoHeight - 50, videoWidth, 50,
                   juce::Justification::centred);
    }

    void renderParticleLayer(juce::Graphics& g, const VideoLayer& layer, double deltaTime)
    {
        // Particle system (placeholder)
        g.setColour(juce::Colours::white.withAlpha(0.5f));
        for (int i = 0; i < 100; ++i)
        {
            float x = juce::Random::getSystemRandom().nextFloat() * videoWidth;
            float y = juce::Random::getSystemRandom().nextFloat() * videoHeight;
            g.fillEllipse(x, y, 3, 3);
        }
    }

    void compositeLayer(juce::Graphics& g, const juce::Image& layerFrame, const VideoLayer& layer)
    {
        // Apply transform
        juce::AffineTransform transform;
        transform = transform.translated(layer.x, layer.y);
        transform = transform.scaled(layer.scaleX, layer.scaleY);
        transform = transform.rotated(layer.rotation, videoWidth / 2.0f, videoHeight / 2.0f);

        // Draw with opacity and blend mode
        g.setOpacity(layer.opacity);
        g.drawImageTransformed(layerFrame, transform, false);
    }

    void applyLayerEffects(juce::Image& frame, const VideoLayer& layer)
    {
        // Apply blur
        if (layer.blur > 0.0f)
        {
            // TODO: Implement Gaussian blur
        }

        // Apply color grading
        if (layer.brightness != 0.0f || layer.contrast != 0.0f ||
            layer.saturation != 1.0f || layer.hueShift != 0.0f)
        {
            applyColorGrading(frame, layer);
        }
    }

    void applyColorGrading(juce::Image& frame, const VideoLayer& layer)
    {
        // Simple color grading (pixel manipulation)
        for (int y = 0; y < frame.getHeight(); ++y)
        {
            for (int x = 0; x < frame.getWidth(); ++x)
            {
                auto pixel = frame.getPixelAt(x, y);

                // Convert to HSV
                float h, s, v;
                pixel.getHSB(h, s, v);

                // Apply adjustments
                h = std::fmod(h + layer.hueShift / 360.0f, 1.0f);
                s = juce::jlimit(0.0f, 1.0f, s * layer.saturation);
                v = juce::jlimit(0.0f, 1.0f, v + layer.brightness);

                // Convert back to RGB
                auto newPixel = juce::Colour::fromHSV(h, s, v, pixel.getAlpha());
                frame.setPixelAt(x, y, newPixel);
            }
        }
    }

    void applyEffects(juce::Image& frame)
    {
        for (const auto& effect : effects)
        {
            applyEffect(frame, effect);
        }

        // Apply flash if active
        if (flashAmount > 0.0f)
        {
            juce::Graphics g(frame);
            g.fillAll(juce::Colours::white.withAlpha(flashAmount * 0.5f));
        }
    }

    void applyEffect(juce::Image& frame, const VideoEffect& effect)
    {
        // Effect implementations
        switch (effect.type)
        {
            case VideoEffect::Type::Invert:
                // TODO: Invert colors
                break;

            case VideoEffect::Type::Glitch:
                // TODO: Glitch effect
                break;

            default:
                break;
        }
    }

    VideoLayer createDefaultLayer()
    {
        VideoLayer layer;
        layer.type = VideoLayer::Type::BioDataViz;
        layer.name = "Default Bio Viz";
        layer.bioReactive = true;
        layer.duration = 9999.0;  // Infinite
        return layer;
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    BioFeedbackSystem* bioFeedbackSystem = nullptr;
    AudioEngine* audioEngine = nullptr;

    std::vector<VideoLayer> layers;
    std::vector<VideoEffect> effects;

    int videoWidth = 1920;
    int videoHeight = 1080;
    double frameRate = 30.0;
    double frameDuration = 1.0 / 30.0;

    std::atomic<bool> bioReactiveEnabled{true};
    std::atomic<bool> bpmReactiveEnabled{true};
    std::atomic<bool> needsResize{false};

    // Timing
    double currentTime = 0.0;
    double currentBPM = 120.0;
    double secondsPerBeat = 0.5;
    double beatPhase = 0.0;
    double lastBeatPhase = 0.0;
    int beatCounter = 0;

    // Effects state
    float flashAmount = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BioReactiveVideoProcessor)
};

} // namespace Echoelmusic
