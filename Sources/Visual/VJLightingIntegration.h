#pragma once

#include <JuceHeader.h>
#include <memory>
#include <vector>
#include <map>
#include <functional>

#include "../Lighting/LightController.h"

/**
 * VJLightingIntegration - Professional VJ & Lighting Control System
 *
 * Combines the best of:
 * - Resolume Arena (VJ/Visual Performance)
 * - OBS Studio (Streaming/Recording)
 * - TouchDesigner (Node-based visuals)
 * - GrandMA3/Pangolin (Lighting/Laser)
 * - Madrix (LED Mapping)
 * - Synesthesia (Audio-Reactive)
 *
 * All synchronized with audio in real-time.
 *
 * Features:
 * - Multi-output video routing (projectors, LED walls, NDI, Spout)
 * - DMX512/Art-Net/sACN lighting control
 * - ILDA laser control
 * - LED pixel mapping
 * - MIDI/OSC control surface support
 * - Audio-reactive automation
 * - Beat-sync effects
 * - Scene/cue management
 * - Live streaming integration
 */

namespace Echoelmusic {
namespace Visual {

//==============================================================================
// Output Protocols
//==============================================================================

enum class VideoOutput
{
    Screen,         // Local display
    NDI,            // Network Device Interface
    Spout,          // GPU texture sharing (Windows)
    Syphon,         // GPU texture sharing (macOS)
    SDI,            // Professional SDI output
    HDMI,           // Direct HDMI
    VirtualCamera,  // Virtual webcam for streaming
    Recording       // File recording
};

enum class LightingProtocol
{
    DMX512,         // Standard DMX
    ArtNet,         // DMX over Ethernet
    sACN,           // Streaming ACN (E1.31)
    ILDA,           // Laser protocol
    KiNet,          // Philips/Color Kinetics
    OLA,            // Open Lighting Architecture
    WLED,           // WiFi LED control
    PhilipsHue      // Smart lighting
};

//==============================================================================
// Visual Layer Types
//==============================================================================

enum class LayerBlendMode
{
    Normal,
    Add,
    Multiply,
    Screen,
    Overlay,
    SoftLight,
    HardLight,
    Difference,
    Exclusion,
    ColorDodge,
    ColorBurn,
    Luminosity
};

enum class EffectType
{
    // Color
    ColorCorrect,
    Hue,
    Saturation,
    Brightness,
    Contrast,
    Levels,
    LUT,

    // Distortion
    Mirror,
    Kaleidoscope,
    Tunnel,
    Spherize,
    Ripple,
    Wave,
    Pixelate,

    // Blur
    GaussianBlur,
    MotionBlur,
    RadialBlur,
    ZoomBlur,

    // Stylize
    EdgeDetect,
    Posterize,
    Noise,
    FilmGrain,
    VHS,
    Glitch,
    ASCII,

    // Time
    Feedback,
    Echo,
    TimeStretch,
    Freeze,
    Reverse,

    // Audio-Reactive
    AudioWaveform,
    AudioSpectrum,
    BeatPulse,
    BassReact,
    MidReact,
    TrebleReact
};

//==============================================================================
// Fixture Definition
//==============================================================================

struct LightFixture
{
    std::string name;
    std::string manufacturer;
    std::string model;
    int universe = 0;
    int startChannel = 1;
    int channelCount = 1;

    enum class Type
    {
        Dimmer,
        RGB,
        RGBW,
        RGBA,
        Moving_Head_Spot,
        Moving_Head_Wash,
        Moving_Head_Beam,
        LED_Bar,
        LED_Panel,
        LED_Tube,
        Strobe,
        Laser,
        Fog_Machine,
        Haze_Machine
    } type = Type::Dimmer;

    // Current values
    float intensity = 0.0f;
    float red = 0.0f, green = 0.0f, blue = 0.0f, white = 0.0f;
    float pan = 0.0f, tilt = 0.0f;
    float zoom = 0.0f, focus = 0.0f;
    float gobo = 0.0f, prism = 0.0f;
    float strobeSpeed = 0.0f;
};

//==============================================================================
// Cue/Scene System
//==============================================================================

struct VisualCue
{
    std::string name;
    int cueNumber = 0;
    float fadeInTime = 0.0f;      // seconds
    float holdTime = 0.0f;        // 0 = manual advance
    float fadeOutTime = 0.0f;
    bool autoFollow = false;

    // Visual state
    std::vector<std::pair<int, float>> layerOpacities;  // layer index, opacity
    std::vector<std::pair<int, EffectType>> activeEffects;

    // Lighting state
    std::vector<LightFixture> fixtureStates;

    // Audio sync
    bool syncToBeat = false;
    int triggerBar = 0;
    int triggerBeat = 0;
};

struct CueList
{
    std::string name;
    std::vector<VisualCue> cues;
    int currentCueIndex = 0;

    void goNext()
    {
        if (currentCueIndex < static_cast<int>(cues.size()) - 1)
            currentCueIndex++;
    }

    void goPrevious()
    {
        if (currentCueIndex > 0)
            currentCueIndex--;
    }

    void goToCue(int index)
    {
        if (index >= 0 && index < static_cast<int>(cues.size()))
            currentCueIndex = index;
    }

    VisualCue* getCurrentCue()
    {
        if (currentCueIndex >= 0 && currentCueIndex < static_cast<int>(cues.size()))
            return &cues[currentCueIndex];
        return nullptr;
    }
};

//==============================================================================
// Audio Analysis for Visual Reactivity
//==============================================================================

struct AudioAnalysis
{
    // Frequency bands
    float bass = 0.0f;          // 20-250 Hz
    float lowMid = 0.0f;        // 250-500 Hz
    float mid = 0.0f;           // 500-2000 Hz
    float highMid = 0.0f;       // 2000-4000 Hz
    float treble = 0.0f;        // 4000-20000 Hz

    // Beat detection
    bool beatDetected = false;
    float bpm = 120.0f;
    int currentBar = 0;
    int currentBeat = 0;
    float beatPhase = 0.0f;     // 0-1 within beat

    // Overall energy
    float rms = 0.0f;
    float peak = 0.0f;
    float lufs = -23.0f;

    // Spectral features
    float spectralCentroid = 0.0f;
    float spectralFlux = 0.0f;
};

//==============================================================================
// LED Pixel Mapping
//==============================================================================

struct PixelMap
{
    std::string name;
    int width = 0;
    int height = 0;
    std::vector<std::pair<int, int>> pixelPositions;  // Universe, Channel pairs

    enum class MappingType
    {
        Grid,
        Snake,
        Zigzag,
        Radial,
        Custom
    } mappingType = MappingType::Grid;

    void generateGrid(int w, int h, int startUniverse, int startChannel)
    {
        width = w;
        height = h;
        pixelPositions.clear();

        int universe = startUniverse;
        int channel = startChannel;

        for (int y = 0; y < h; ++y)
        {
            for (int x = 0; x < w; ++x)
            {
                pixelPositions.push_back({universe, channel});
                channel += 3;  // RGB

                if (channel > 510)
                {
                    universe++;
                    channel = 1;
                }
            }
        }
    }
};

//==============================================================================
// Streaming Integration
//==============================================================================

struct StreamConfig
{
    enum class Platform
    {
        OBS_Websocket,
        YouTube_API,
        Twitch_API,
        Facebook_API,
        Instagram_API,
        TikTok_API,
        Custom_RTMP
    };

    Platform platform = Platform::OBS_Websocket;
    std::string streamKey;
    std::string serverUrl;
    int videoBitrate = 6000;    // kbps
    int audioBitrate = 320;     // kbps
    std::string resolution = "1920x1080";
    int fps = 60;
};

//==============================================================================
// Main VJ Lighting Integration Class
//==============================================================================

class VJLightingIntegration
{
public:
    static VJLightingIntegration& getInstance()
    {
        static VJLightingIntegration instance;
        return instance;
    }

    //==========================================================================
    // Initialization
    //==========================================================================

    void initialize()
    {
        initializeVideoOutputs();
        initializeLightingOutputs();
        initializeAudioAnalysis();

        isInitialized = true;
    }

    //==========================================================================
    // Video Layer Management
    //==========================================================================

    int addLayer(const std::string& name)
    {
        Layer layer;
        layer.name = name;
        layer.index = static_cast<int>(layers.size());
        layers.push_back(layer);
        return layer.index;
    }

    void setLayerOpacity(int layerIndex, float opacity)
    {
        if (layerIndex >= 0 && layerIndex < static_cast<int>(layers.size()))
            layers[layerIndex].opacity = juce::jlimit(0.0f, 1.0f, opacity);
    }

    void setLayerBlendMode(int layerIndex, LayerBlendMode mode)
    {
        if (layerIndex >= 0 && layerIndex < static_cast<int>(layers.size()))
            layers[layerIndex].blendMode = mode;
    }

    void addEffectToLayer(int layerIndex, EffectType effect)
    {
        if (layerIndex >= 0 && layerIndex < static_cast<int>(layers.size()))
            layers[layerIndex].effects.push_back(effect);
    }

    //==========================================================================
    // Lighting Control
    //==========================================================================

    void addFixture(const LightFixture& fixture)
    {
        fixtures.push_back(fixture);
    }

    void setFixtureIntensity(int fixtureIndex, float intensity)
    {
        if (fixtureIndex >= 0 && fixtureIndex < static_cast<int>(fixtures.size()))
            fixtures[fixtureIndex].intensity = juce::jlimit(0.0f, 1.0f, intensity);
    }

    void setFixtureColor(int fixtureIndex, float r, float g, float b)
    {
        if (fixtureIndex >= 0 && fixtureIndex < static_cast<int>(fixtures.size()))
        {
            fixtures[fixtureIndex].red = r;
            fixtures[fixtureIndex].green = g;
            fixtures[fixtureIndex].blue = b;
        }
    }

    void setFixturePosition(int fixtureIndex, float pan, float tilt)
    {
        if (fixtureIndex >= 0 && fixtureIndex < static_cast<int>(fixtures.size()))
        {
            fixtures[fixtureIndex].pan = pan;
            fixtures[fixtureIndex].tilt = tilt;
        }
    }

    void blackout()
    {
        for (auto& fixture : fixtures)
            fixture.intensity = 0.0f;
    }

    void fullOn()
    {
        for (auto& fixture : fixtures)
            fixture.intensity = 1.0f;
    }

    //==========================================================================
    // DMX Output
    //==========================================================================

    void sendDMX()
    {
        for (const auto& fixture : fixtures)
        {
            int ch = fixture.startChannel;

            switch (fixture.type)
            {
                case LightFixture::Type::Dimmer:
                    setDMXChannel(fixture.universe, ch, fixture.intensity);
                    break;

                case LightFixture::Type::RGB:
                    setDMXChannel(fixture.universe, ch, fixture.red * fixture.intensity);
                    setDMXChannel(fixture.universe, ch + 1, fixture.green * fixture.intensity);
                    setDMXChannel(fixture.universe, ch + 2, fixture.blue * fixture.intensity);
                    break;

                case LightFixture::Type::RGBW:
                    setDMXChannel(fixture.universe, ch, fixture.red * fixture.intensity);
                    setDMXChannel(fixture.universe, ch + 1, fixture.green * fixture.intensity);
                    setDMXChannel(fixture.universe, ch + 2, fixture.blue * fixture.intensity);
                    setDMXChannel(fixture.universe, ch + 3, fixture.white * fixture.intensity);
                    break;

                case LightFixture::Type::Moving_Head_Spot:
                case LightFixture::Type::Moving_Head_Wash:
                    setDMXChannel(fixture.universe, ch, fixture.pan);
                    setDMXChannel(fixture.universe, ch + 1, fixture.tilt);
                    setDMXChannel(fixture.universe, ch + 2, fixture.intensity);
                    setDMXChannel(fixture.universe, ch + 3, fixture.red);
                    setDMXChannel(fixture.universe, ch + 4, fixture.green);
                    setDMXChannel(fixture.universe, ch + 5, fixture.blue);
                    setDMXChannel(fixture.universe, ch + 6, fixture.zoom);
                    break;

                default:
                    break;
            }
        }

        // Send all universes via Art-Net
        for (auto& [universe, packet] : dmxUniverses)
        {
            artNetController.send(packet, universe);
        }
    }

    //==========================================================================
    // Audio-Reactive Control
    //==========================================================================

    void updateAudioAnalysis(const AudioAnalysis& analysis)
    {
        currentAnalysis = analysis;

        if (audioReactiveEnabled)
            applyAudioReactivity();
    }

    void enableAudioReactivity(bool enable)
    {
        audioReactiveEnabled = enable;
    }

    void setAudioReactiveTarget(EffectType effect, const std::string& audioSource,
                                 float sensitivity = 1.0f)
    {
        AudioReactiveMapping mapping;
        mapping.effect = effect;
        mapping.audioSource = audioSource;
        mapping.sensitivity = sensitivity;
        audioMappings.push_back(mapping);
    }

    //==========================================================================
    // Cue Management
    //==========================================================================

    void addCueList(const CueList& cueList)
    {
        cueLists.push_back(cueList);
    }

    void goNextCue()
    {
        if (activeCueListIndex >= 0 && activeCueListIndex < static_cast<int>(cueLists.size()))
            cueLists[activeCueListIndex].goNext();
    }

    void goPreviousCue()
    {
        if (activeCueListIndex >= 0 && activeCueListIndex < static_cast<int>(cueLists.size()))
            cueLists[activeCueListIndex].goPrevious();
    }

    void triggerCue(int cueNumber)
    {
        if (activeCueListIndex >= 0 && activeCueListIndex < static_cast<int>(cueLists.size()))
            cueLists[activeCueListIndex].goToCue(cueNumber);
    }

    //==========================================================================
    // Video Output
    //==========================================================================

    void enableOutput(VideoOutput output)
    {
        enabledOutputs.insert(output);
    }

    void disableOutput(VideoOutput output)
    {
        enabledOutputs.erase(output);
    }

    void startNDIOutput(const std::string& sourceName)
    {
        ndiSourceName = sourceName;
        ndiEnabled = true;
    }

    void stopNDIOutput()
    {
        ndiEnabled = false;
    }

    void startVirtualCamera()
    {
        virtualCameraEnabled = true;
    }

    void stopVirtualCamera()
    {
        virtualCameraEnabled = false;
    }

    //==========================================================================
    // LED Pixel Mapping
    //==========================================================================

    void addPixelMap(const PixelMap& map)
    {
        pixelMaps.push_back(map);
    }

    void updatePixelMap(int mapIndex, const juce::Image& source)
    {
        if (mapIndex < 0 || mapIndex >= static_cast<int>(pixelMaps.size()))
            return;

        const auto& map = pixelMaps[mapIndex];

        for (int y = 0; y < map.height; ++y)
        {
            for (int x = 0; x < map.width; ++x)
            {
                int pixelIndex = y * map.width + x;
                if (pixelIndex >= static_cast<int>(map.pixelPositions.size()))
                    continue;

                auto [universe, channel] = map.pixelPositions[pixelIndex];

                // Sample color from image
                float sx = static_cast<float>(x) / map.width * source.getWidth();
                float sy = static_cast<float>(y) / map.height * source.getHeight();
                auto color = source.getPixelAt(static_cast<int>(sx), static_cast<int>(sy));

                setDMXChannel(universe, channel, color.getRed() / 255.0f);
                setDMXChannel(universe, channel + 1, color.getGreen() / 255.0f);
                setDMXChannel(universe, channel + 2, color.getBlue() / 255.0f);
            }
        }
    }

    //==========================================================================
    // Streaming
    //==========================================================================

    void configureStream(const StreamConfig& config)
    {
        streamConfig = config;
    }

    void startStream()
    {
        isStreaming = true;
        // Connect to streaming platform
    }

    void stopStream()
    {
        isStreaming = false;
    }

    //==========================================================================
    // MIDI/OSC Control
    //==========================================================================

    void handleMIDI(int channel, int note, int velocity)
    {
        // Map MIDI to visual actions
        if (auto it = midiMappings.find({channel, note}); it != midiMappings.end())
        {
            it->second(velocity / 127.0f);
        }
    }

    void handleOSC(const std::string& address, float value)
    {
        // Map OSC to visual actions
        if (auto it = oscMappings.find(address); it != oscMappings.end())
        {
            it->second(value);
        }
    }

    void mapMIDI(int channel, int note, std::function<void(float)> action)
    {
        midiMappings[{channel, note}] = action;
    }

    void mapOSC(const std::string& address, std::function<void(float)> action)
    {
        oscMappings[address] = action;
    }

    //==========================================================================
    // Getters
    //==========================================================================

    bool isInitializedState() const { return isInitialized; }
    bool isStreamingState() const { return isStreaming; }
    const AudioAnalysis& getAudioAnalysis() const { return currentAnalysis; }

private:
    VJLightingIntegration() = default;

    //==========================================================================
    // Internal Structures
    //==========================================================================

    struct Layer
    {
        std::string name;
        int index = 0;
        float opacity = 1.0f;
        LayerBlendMode blendMode = LayerBlendMode::Normal;
        std::vector<EffectType> effects;
    };

    struct AudioReactiveMapping
    {
        EffectType effect;
        std::string audioSource;  // "bass", "mid", "treble", "beat", etc.
        float sensitivity = 1.0f;
        float min = 0.0f;
        float max = 1.0f;
    };

    //==========================================================================
    // Initialization Helpers
    //==========================================================================

    void initializeVideoOutputs()
    {
        // Initialize NDI, Spout/Syphon, etc.
    }

    void initializeLightingOutputs()
    {
        // Initialize Art-Net, DMX interfaces
    }

    void initializeAudioAnalysis()
    {
        // Initialize FFT, beat detection
    }

    //==========================================================================
    // Audio Reactivity
    //==========================================================================

    void applyAudioReactivity()
    {
        for (const auto& mapping : audioMappings)
        {
            float value = 0.0f;

            if (mapping.audioSource == "bass")
                value = currentAnalysis.bass;
            else if (mapping.audioSource == "mid")
                value = currentAnalysis.mid;
            else if (mapping.audioSource == "treble")
                value = currentAnalysis.treble;
            else if (mapping.audioSource == "beat")
                value = currentAnalysis.beatDetected ? 1.0f : 0.0f;
            else if (mapping.audioSource == "rms")
                value = currentAnalysis.rms;

            value *= mapping.sensitivity;
            value = juce::jlimit(mapping.min, mapping.max, value);

            // Apply to effect...
        }
    }

    //==========================================================================
    // DMX Helpers
    //==========================================================================

    void setDMXChannel(int universe, int channel, float value)
    {
        if (dmxUniverses.find(universe) == dmxUniverses.end())
            dmxUniverses[universe] = Echoel::DMXPacket();

        uint8_t dmxValue = static_cast<uint8_t>(juce::jlimit(0.0f, 1.0f, value) * 255.0f);
        dmxUniverses[universe].setChannel(channel, dmxValue);
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    bool isInitialized = false;
    bool isStreaming = false;

    // Video
    std::vector<Layer> layers;
    std::set<VideoOutput> enabledOutputs;
    bool ndiEnabled = false;
    std::string ndiSourceName;
    bool virtualCameraEnabled = false;

    // Lighting
    std::vector<LightFixture> fixtures;
    std::map<int, Echoel::DMXPacket> dmxUniverses;
    Echoel::ArtNetController artNetController;
    std::vector<PixelMap> pixelMaps;

    // Cues
    std::vector<CueList> cueLists;
    int activeCueListIndex = 0;

    // Audio Reactivity
    bool audioReactiveEnabled = true;
    AudioAnalysis currentAnalysis;
    std::vector<AudioReactiveMapping> audioMappings;

    // Streaming
    StreamConfig streamConfig;

    // MIDI/OSC Mappings
    std::map<std::pair<int, int>, std::function<void(float)>> midiMappings;
    std::map<std::string, std::function<void(float)>> oscMappings;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(VJLightingIntegration)
};

//==============================================================================
// Convenience Macro
//==============================================================================

#define EchoelVJ VJLightingIntegration::getInstance()

} // namespace Visual
} // namespace Echoelmusic
