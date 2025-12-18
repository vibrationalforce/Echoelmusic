#pragma once

#include <JuceHeader.h>
#include "../Visual/VisualForge.h"
#include "../Hardware/OSCManager.h"

namespace Echoelmusic {

/**
 * @brief Visual Engine OSC Bridge
 *
 * Provides OSC control for VisualForge (layers, generators, effects, rendering).
 *
 * OSC Address Space:
 * /echoelmusic/visual/layer/<n>/enabled [int 0/1]       Enable/disable layer
 * /echoelmusic/visual/layer/<n>/opacity [float 0-1]     Layer opacity
 * /echoelmusic/visual/layer/<n>/blend [int]             Blend mode (0-8)
 * /echoelmusic/visual/layer/<n>/x [float]               Position X (-1 to 1)
 * /echoelmusic/visual/layer/<n>/y [float]               Position Y (-1 to 1)
 * /echoelmusic/visual/layer/<n>/scale [float]           Uniform scale
 * /echoelmusic/visual/layer/<n>/scalex [float]          Scale X
 * /echoelmusic/visual/layer/<n>/scaley [float]          Scale Y
 * /echoelmusic/visual/layer/<n>/rotation [float]        Rotation (radians)
 * /echoelmusic/visual/layer/<n>/generator [int]         Generator type
 *
 * /echoelmusic/visual/master/brightness [float 0-1]     Global brightness
 * /echoelmusic/visual/master/contrast [float 0-2]       Global contrast
 * /echoelmusic/visual/master/saturation [float 0-2]     Global saturation
 * /echoelmusic/visual/master/hue [float 0-1]            Global hue shift
 *
 * /echoelmusic/visual/resolution [int int]              Set resolution (width, height)
 * /echoelmusic/visual/fps/target [int]                  Set target FPS
 * /echoelmusic/visual/fps/current                       Query current FPS
 *
 * /echoelmusic/visual/audio/reactive [int 0/1]          Enable audio reactive
 * /echoelmusic/visual/bio/reactive [int 0/1]            Enable bio reactive
 *
 * /echoelmusic/visual/recording/start [string]          Start recording to file
 * /echoelmusic/visual/recording/stop                    Stop recording
 * /echoelmusic/visual/recording/status                  Query recording status
 *
 * /echoelmusic/visual/preset/load [string]              Load preset by name or path
 * /echoelmusic/visual/preset/save [string]              Save preset to path
 * /echoelmusic/visual/preset/list                       Get list of built-in presets
 *
 * Blend Modes:
 * 0=Normal, 1=Add, 2=Multiply, 3=Screen, 4=Overlay,
 * 5=Difference, 6=Exclusion, 7=ColorDodge, 8=ColorBurn
 *
 * @author Echoelmusic Team
 * @date 2025-12-18
 * @version 1.0.0
 */
class VisualOSCBridge
{
public:
    //==========================================================================
    VisualOSCBridge(VisualForge& visualEngine, OSCManager& oscManager)
        : visualForge(visualEngine)
        , oscManager(oscManager)
    {
        setupOSCListeners();
    }

    ~VisualOSCBridge()
    {
        removeOSCListeners();
    }

    //==========================================================================
    /**
     * @brief Send visual engine status via OSC
     */
    void sendVisualStatus()
    {
        juce::String prefix = "/echoelmusic/visual/status/";

        // Resolution
        int width, height;
        visualForge.getResolution(width, height);
        oscManager.sendInt(prefix + "width", width);
        oscManager.sendInt(prefix + "height", height);

        // Performance
        oscManager.sendFloat(prefix + "fps", visualForge.getCurrentFPS());
        oscManager.sendInt(prefix + "fps_target", visualForge.getTargetFPS());

        // Layer count
        oscManager.sendInt(prefix + "layers", visualForge.getNumLayers());

        // Recording status
        oscManager.sendInt(prefix + "recording", visualForge.isRecording() ? 1 : 0);
    }

private:
    //==========================================================================
    void setupOSCListeners()
    {
        // Layer control - use wildcard pattern matching
        oscManager.addListener("/echoelmusic/visual/layer/*",
            [this](const juce::OSCMessage& message) {
                handleLayerOSC(message);
            });

        // Master controls
        oscManager.addListener("/echoelmusic/visual/master/*",
            [this](const juce::OSCMessage& message) {
                handleMasterOSC(message);
            });

        // Resolution
        oscManager.addListener("/echoelmusic/visual/resolution",
            [this](const juce::OSCMessage& message) {
                if (message.size() >= 2 && message[0].isInt32() && message[1].isInt32())
                {
                    int width = juce::jlimit(320, 7680, message[0].getInt32());
                    int height = juce::jlimit(240, 4320, message[1].getInt32());
                    visualForge.setResolution(width, height);
                    DBG("OSC: Set visual resolution to " << width << "x" << height);
                }
            });

        // FPS target
        oscManager.addListener("/echoelmusic/visual/fps/target",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isInt32())
                {
                    int fps = juce::jlimit(15, 240, message[0].getInt32());
                    visualForge.setTargetFPS(fps);
                    DBG("OSC: Set visual FPS target to " << fps);
                }
            });

        // FPS query
        oscManager.addListener("/echoelmusic/visual/fps/current",
            [this](const juce::OSCMessage&) {
                oscManager.sendFloat("/echoelmusic/visual/status/fps",
                    visualForge.getCurrentFPS());
            });

        // Audio reactive
        oscManager.addListener("/echoelmusic/visual/audio/reactive",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isInt32())
                {
                    auto config = visualForge.getAudioReactive();
                    config.enabled = (message[0].getInt32() != 0);
                    visualForge.setAudioReactive(config);
                    DBG("OSC: Audio reactive " << (config.enabled ? "ENABLED" : "DISABLED"));
                }
            });

        // Bio reactive
        oscManager.addListener("/echoelmusic/visual/bio/reactive",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isInt32())
                {
                    bool enabled = (message[0].getInt32() != 0);
                    visualForge.setBioReactiveEnabled(enabled);
                    DBG("OSC: Bio reactive " << (enabled ? "ENABLED" : "DISABLED"));
                }
            });

        // Recording start
        oscManager.addListener("/echoelmusic/visual/recording/start",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isString())
                {
                    juce::String filePath = message[0].getString();
                    visualForge.startRecording(juce::File(filePath));
                    DBG("OSC: Started recording to " << filePath);
                }
            });

        // Recording stop
        oscManager.addListener("/echoelmusic/visual/recording/stop",
            [this](const juce::OSCMessage&) {
                visualForge.stopRecording();
                DBG("OSC: Stopped recording");
            });

        // Recording status
        oscManager.addListener("/echoelmusic/visual/recording/status",
            [this](const juce::OSCMessage&) {
                oscManager.sendInt("/echoelmusic/visual/status/recording",
                    visualForge.isRecording() ? 1 : 0);
            });

        // Load preset
        oscManager.addListener("/echoelmusic/visual/preset/load",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isString())
                {
                    juce::String presetName = message[0].getString();

                    // Try built-in preset first
                    auto builtIn = visualForge.getBuiltInPresets();
                    if (builtIn.contains(presetName))
                    {
                        visualForge.loadBuiltInPreset(presetName);
                        DBG("OSC: Loaded built-in preset '" << presetName << "'");
                    }
                    else
                    {
                        // Try as file path
                        juce::File presetFile(presetName);
                        if (presetFile.exists())
                        {
                            visualForge.loadPreset(presetFile);
                            DBG("OSC: Loaded preset from " << presetName);
                        }
                        else
                        {
                            DBG("OSC: Preset not found: " << presetName);
                        }
                    }
                }
            });

        // Save preset
        oscManager.addListener("/echoelmusic/visual/preset/save",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isString())
                {
                    juce::String filePath = message[0].getString();
                    bool success = visualForge.savePreset(juce::File(filePath));
                    DBG("OSC: Save preset to " << filePath << " - "
                        << (success ? "SUCCESS" : "FAILED"));
                }
            });

        // List presets
        oscManager.addListener("/echoelmusic/visual/preset/list",
            [this](const juce::OSCMessage&) {
                auto presets = visualForge.getBuiltInPresets();
                for (const auto& preset : presets)
                {
                    oscManager.sendString("/echoelmusic/visual/preset/item", preset);
                }
            });

        // Status query
        oscManager.addListener("/echoelmusic/visual/status",
            [this](const juce::OSCMessage&) {
                sendVisualStatus();
            });
    }

    void removeOSCListeners()
    {
        oscManager.removeListener("/echoelmusic/visual/layer/*");
        oscManager.removeListener("/echoelmusic/visual/master/*");
        oscManager.removeListener("/echoelmusic/visual/resolution");
        oscManager.removeListener("/echoelmusic/visual/fps/target");
        oscManager.removeListener("/echoelmusic/visual/fps/current");
        oscManager.removeListener("/echoelmusic/visual/audio/reactive");
        oscManager.removeListener("/echoelmusic/visual/bio/reactive");
        oscManager.removeListener("/echoelmusic/visual/recording/start");
        oscManager.removeListener("/echoelmusic/visual/recording/stop");
        oscManager.removeListener("/echoelmusic/visual/recording/status");
        oscManager.removeListener("/echoelmusic/visual/preset/load");
        oscManager.removeListener("/echoelmusic/visual/preset/save");
        oscManager.removeListener("/echoelmusic/visual/preset/list");
        oscManager.removeListener("/echoelmusic/visual/status");
    }

    //==========================================================================
    void handleLayerOSC(const juce::OSCMessage& message)
    {
        juce::String address = message.getAddressPattern().toString();

        // Parse layer index from address: /echoelmusic/visual/layer/0/opacity
        int layerIndex = parseLayerIndex(address);
        if (layerIndex < 0 || layerIndex >= visualForge.getNumLayers())
            return;

        auto& layer = visualForge.getLayer(layerIndex);

        if (address.contains("/enabled"))
        {
            if (message.size() > 0 && message[0].isInt32())
            {
                layer.enabled = (message[0].getInt32() != 0);
                visualForge.setLayer(layerIndex, layer);
            }
        }
        else if (address.contains("/opacity"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                layer.opacity = juce::jlimit(0.0f, 1.0f, message[0].getFloat32());
                visualForge.setLayer(layerIndex, layer);
            }
        }
        else if (address.contains("/blend"))
        {
            if (message.size() > 0 && message[0].isInt32())
            {
                int blendMode = juce::jlimit(0, 8, message[0].getInt32());
                layer.blendMode = static_cast<VisualForge::BlendMode>(blendMode);
                visualForge.setLayer(layerIndex, layer);
            }
        }
        else if (address.contains("/x"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                layer.x = juce::jlimit(-2.0f, 2.0f, message[0].getFloat32());
                visualForge.setLayer(layerIndex, layer);
            }
        }
        else if (address.contains("/y"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                layer.y = juce::jlimit(-2.0f, 2.0f, message[0].getFloat32());
                visualForge.setLayer(layerIndex, layer);
            }
        }
        else if (address.contains("/scalex"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                layer.scaleX = juce::jlimit(0.01f, 10.0f, message[0].getFloat32());
                visualForge.setLayer(layerIndex, layer);
            }
        }
        else if (address.contains("/scaley"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                layer.scaleY = juce::jlimit(0.01f, 10.0f, message[0].getFloat32());
                visualForge.setLayer(layerIndex, layer);
            }
        }
        else if (address.contains("/scale"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                float scale = juce::jlimit(0.01f, 10.0f, message[0].getFloat32());
                layer.scaleX = layer.scaleY = scale;
                visualForge.setLayer(layerIndex, layer);
            }
        }
        else if (address.contains("/rotation"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                layer.rotation = message[0].getFloat32();
                visualForge.setLayer(layerIndex, layer);
            }
        }
    }

    void handleMasterOSC(const juce::OSCMessage& message)
    {
        juce::String address = message.getAddressPattern().toString();

        // Master controls affect all layers or global post-processing
        // For now, log the intent (would need VisualForge extension for global effects)

        if (address.contains("/brightness"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                float brightness = juce::jlimit(0.0f, 2.0f, message[0].getFloat32());
                DBG("OSC: Master brightness = " << brightness);
                // Would apply global brightness post-processing
            }
        }
        else if (address.contains("/contrast"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                float contrast = juce::jlimit(0.0f, 2.0f, message[0].getFloat32());
                DBG("OSC: Master contrast = " << contrast);
            }
        }
        else if (address.contains("/saturation"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                float saturation = juce::jlimit(0.0f, 2.0f, message[0].getFloat32());
                DBG("OSC: Master saturation = " << saturation);
            }
        }
        else if (address.contains("/hue"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                float hue = std::fmod(message[0].getFloat32(), 1.0f);
                if (hue < 0.0f) hue += 1.0f;
                DBG("OSC: Master hue shift = " << hue);
            }
        }
    }

    int parseLayerIndex(const juce::String& address) const
    {
        // Parse "/echoelmusic/visual/layer/0/opacity" -> 0
        auto parts = juce::StringArray::fromTokens(address, "/", "");

        for (int i = 0; i < parts.size(); ++i)
        {
            if (parts[i] == "layer" && i + 1 < parts.size())
            {
                return parts[i + 1].getIntValue();
            }
        }

        return -1;
    }

    //==========================================================================
    VisualForge& visualForge;
    OSCManager& oscManager;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(VisualOSCBridge)
};

} // namespace Echoelmusic
