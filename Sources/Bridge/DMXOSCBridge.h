#pragma once

#include <JuceHeader.h>
#include "../Lighting/DMXSceneManager.h"
#include "../Lighting/LightController.h"
#include "../Hardware/OSCManager.h"

namespace Echoelmusic {

/**
 * @brief DMX Lighting OSC Bridge
 *
 * Provides OSC control for DMX512/Art-Net lighting systems.
 * Compatible with lighting consoles, VJ software, and automation systems.
 *
 * OSC Address Space:
 * /echoelmusic/dmx/channel/<n> [int 0-255]              Set DMX channel value
 * /echoelmusic/dmx/channel/<n>/fade [int 0-255] [ms]    Fade to value
 * /echoelmusic/dmx/universe/clear                       Clear all channels to 0
 * /echoelmusic/dmx/universe/blackout                    Instant blackout
 *
 * /echoelmusic/dmx/scene/recall [string]                Recall scene by name or ID
 * /echoelmusic/dmx/scene/recall/<n>                     Recall scene by index
 * /echoelmusic/dmx/scene/save [string]                  Save current state as scene
 * /echoelmusic/dmx/scene/delete [string]                Delete scene
 * /echoelmusic/dmx/scene/list                           Get list of scenes
 * /echoelmusic/dmx/scene/fade [int ms]                  Set default fade time
 *
 * /echoelmusic/dmx/artnet/ip [string]                   Set Art-Net target IP
 * /echoelmusic/dmx/artnet/universe [int]                Set Art-Net universe
 * /echoelmusic/dmx/artnet/enable [int 0/1]              Enable Art-Net output
 *
 * /echoelmusic/dmx/fixture/<name>/intensity [float 0-1] Fixture intensity
 * /echoelmusic/dmx/fixture/<name>/color [float float float] RGB color (0-1)
 * /echoelmusic/dmx/fixture/<name>/strobe [float Hz]     Strobe frequency
 *
 * Response Messages:
 * /echoelmusic/dmx/status/scene [string]                Current scene name
 * /echoelmusic/dmx/status/artnet [int 0/1]              Art-Net enabled
 * /echoelmusic/dmx/scene/item [string]                  Scene list item
 *
 * @author Echoelmusic Team
 * @date 2025-12-18
 * @version 1.0.0
 */
class DMXOSCBridge
{
public:
    //==========================================================================
    DMXOSCBridge(Echoel::DMXSceneManager& sceneManager,
                 Echoel::ArtNetController& artNet,
                 OSCManager& oscManager)
        : dmxSceneManager(sceneManager)
        , artNetController(artNet)
        , oscManager(oscManager)
    {
        setupOSCListeners();
    }

    ~DMXOSCBridge()
    {
        removeOSCListeners();
    }

    //==========================================================================
    /**
     * @brief Send DMX status via OSC
     */
    void sendDMXStatus()
    {
        juce::String prefix = "/echoelmusic/dmx/status/";

        // Current scene
        if (currentScene.isNotEmpty())
            oscManager.sendString(prefix + "scene", currentScene);

        // Art-Net status
        oscManager.sendInt(prefix + "artnet", artNetEnabled ? 1 : 0);
        oscManager.sendString(prefix + "artnet/ip", artNetIP);
        oscManager.sendInt(prefix + "artnet/universe", artNetUniverse);

        // Fade time
        oscManager.sendInt(prefix + "fadetime", defaultFadeTimeMs);
    }

    /**
     * @brief Update DMX output (call regularly, e.g., 44 Hz for DMX refresh rate)
     */
    void updateDMXOutput()
    {
        if (artNetEnabled)
        {
            artNetController.send(currentDMXPacket, artNetUniverse, artNetIP);
        }
    }

private:
    //==========================================================================
    void setupOSCListeners()
    {
        // Channel control (direct DMX channel set)
        oscManager.addListener("/echoelmusic/dmx/channel/*",
            [this](const juce::OSCMessage& message) {
                handleChannelOSC(message);
            });

        // Universe clear
        oscManager.addListener("/echoelmusic/dmx/universe/clear",
            [this](const juce::OSCMessage&) {
                currentDMXPacket.clear();
                DBG("OSC: DMX universe cleared");
            });

        // Blackout (instant)
        oscManager.addListener("/echoelmusic/dmx/universe/blackout",
            [this](const juce::OSCMessage&) {
                currentDMXPacket.clear();
                if (artNetEnabled)
                    artNetController.send(currentDMXPacket, artNetUniverse, artNetIP);
                DBG("OSC: DMX blackout");
            });

        // Scene recall by name/ID
        oscManager.addListener("/echoelmusic/dmx/scene/recall",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isString())
                {
                    juce::String sceneName = message[0].getString();
                    recallScene(sceneName);
                }
            });

        // Scene recall by index
        oscManager.addListener("/echoelmusic/dmx/scene/recall/*",
            [this](const juce::OSCMessage& message) {
                juce::String address = message.getAddressPattern().toString();
                int sceneIndex = parseSceneIndex(address);

                if (sceneIndex >= 0)
                {
                    recallSceneByIndex(sceneIndex);
                }
            });

        // Scene save
        oscManager.addListener("/echoelmusic/dmx/scene/save",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isString())
                {
                    juce::String sceneName = message[0].getString();
                    saveScene(sceneName);
                }
            });

        // Scene delete
        oscManager.addListener("/echoelmusic/dmx/scene/delete",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isString())
                {
                    juce::String sceneName = message[0].getString();
                    deleteScene(sceneName);
                }
            });

        // Scene list
        oscManager.addListener("/echoelmusic/dmx/scene/list",
            [this](const juce::OSCMessage&) {
                auto scenes = dmxSceneManager.getAllScenes();
                for (const auto& scene : scenes)
                {
                    oscManager.sendString("/echoelmusic/dmx/scene/item", scene.name);
                }
            });

        // Scene fade time
        oscManager.addListener("/echoelmusic/dmx/scene/fade",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isInt32())
                {
                    defaultFadeTimeMs = juce::jlimit(0, 10000, message[0].getInt32());
                    DBG("OSC: DMX fade time set to " << defaultFadeTimeMs << " ms");
                }
            });

        // Art-Net IP
        oscManager.addListener("/echoelmusic/dmx/artnet/ip",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isString())
                {
                    artNetIP = message[0].getString();
                    DBG("OSC: Art-Net IP set to " << artNetIP);
                }
            });

        // Art-Net universe
        oscManager.addListener("/echoelmusic/dmx/artnet/universe",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isInt32())
                {
                    artNetUniverse = juce::jlimit(0, 32767, message[0].getInt32());
                    DBG("OSC: Art-Net universe set to " << artNetUniverse);
                }
            });

        // Art-Net enable
        oscManager.addListener("/echoelmusic/dmx/artnet/enable",
            [this](const juce::OSCMessage& message) {
                if (message.size() > 0 && message[0].isInt32())
                {
                    artNetEnabled = (message[0].getInt32() != 0);
                    DBG("OSC: Art-Net " << (artNetEnabled ? "ENABLED" : "DISABLED"));
                }
            });

        // Fixture control (simplified - would need fixture definitions)
        oscManager.addListener("/echoelmusic/dmx/fixture/*",
            [this](const juce::OSCMessage& message) {
                handleFixtureOSC(message);
            });

        // Status query
        oscManager.addListener("/echoelmusic/dmx/status",
            [this](const juce::OSCMessage&) {
                sendDMXStatus();
            });
    }

    void removeOSCListeners()
    {
        oscManager.removeListener("/echoelmusic/dmx/channel/*");
        oscManager.removeListener("/echoelmusic/dmx/universe/clear");
        oscManager.removeListener("/echoelmusic/dmx/universe/blackout");
        oscManager.removeListener("/echoelmusic/dmx/scene/recall");
        oscManager.removeListener("/echoelmusic/dmx/scene/recall/*");
        oscManager.removeListener("/echoelmusic/dmx/scene/save");
        oscManager.removeListener("/echoelmusic/dmx/scene/delete");
        oscManager.removeListener("/echoelmusic/dmx/scene/list");
        oscManager.removeListener("/echoelmusic/dmx/scene/fade");
        oscManager.removeListener("/echoelmusic/dmx/artnet/ip");
        oscManager.removeListener("/echoelmusic/dmx/artnet/universe");
        oscManager.removeListener("/echoelmusic/dmx/artnet/enable");
        oscManager.removeListener("/echoelmusic/dmx/fixture/*");
        oscManager.removeListener("/echoelmusic/dmx/status");
    }

    //==========================================================================
    void handleChannelOSC(const juce::OSCMessage& message)
    {
        juce::String address = message.getAddressPattern().toString();

        // Parse channel: /echoelmusic/dmx/channel/1 -> 1 (DMX channels are 1-512)
        int channel = parseChannelNumber(address);
        if (channel < 1 || channel > 512)
            return;

        if (address.contains("/fade"))
        {
            // Fade to value: /echoelmusic/dmx/channel/1/fade 255 1000
            if (message.size() >= 2 && message[0].isInt32() && message[1].isInt32())
            {
                uint8_t targetValue = static_cast<uint8_t>(juce::jlimit(0, 255, message[0].getInt32()));
                int fadeTime = message[1].getInt32();

                // Would implement fade here (requires fade engine)
                currentDMXPacket.setChannel(channel, targetValue);
                DBG("OSC: DMX channel " << channel << " fade to " << (int)targetValue
                    << " over " << fadeTime << " ms");
            }
        }
        else
        {
            // Direct set: /echoelmusic/dmx/channel/1 255
            if (message.size() > 0 && message[0].isInt32())
            {
                uint8_t value = static_cast<uint8_t>(juce::jlimit(0, 255, message[0].getInt32()));
                currentDMXPacket.setChannel(channel, value);
                DBG("OSC: DMX channel " << channel << " = " << (int)value);
            }
        }
    }

    void handleFixtureOSC(const juce::OSCMessage& message)
    {
        juce::String address = message.getAddressPattern().toString();

        // Parse fixture name: /echoelmusic/dmx/fixture/par1/intensity
        juce::String fixtureName = parseFixtureName(address);

        if (address.contains("/intensity"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                float intensity = juce::jlimit(0.0f, 1.0f, message[0].getFloat32());
                uint8_t dmxValue = static_cast<uint8_t>(intensity * 255.0f);

                // Would map to actual fixture channels based on fixture definition
                DBG("OSC: Fixture '" << fixtureName << "' intensity = " << intensity);
            }
        }
        else if (address.contains("/color"))
        {
            if (message.size() >= 3 && message[0].isFloat32() &&
                message[1].isFloat32() && message[2].isFloat32())
            {
                float r = juce::jlimit(0.0f, 1.0f, message[0].getFloat32());
                float g = juce::jlimit(0.0f, 1.0f, message[1].getFloat32());
                float b = juce::jlimit(0.0f, 1.0f, message[2].getFloat32());

                DBG("OSC: Fixture '" << fixtureName << "' color = RGB("
                    << r << ", " << g << ", " << b << ")");
            }
        }
        else if (address.contains("/strobe"))
        {
            if (message.size() > 0 && message[0].isFloat32())
            {
                float strobeHz = message[0].getFloat32();
                DBG("OSC: Fixture '" << fixtureName << "' strobe = " << strobeHz << " Hz");
            }
        }
    }

    //==========================================================================
    // Scene management helpers

    void recallScene(const juce::String& sceneName)
    {
        auto scene = dmxSceneManager.getScene(sceneName);
        if (scene != nullptr)
        {
            currentDMXPacket = scene->toDMXPacket();
            currentScene = sceneName;

            DBG("OSC: Recalled DMX scene '" << sceneName << "'");

            oscManager.sendString("/echoelmusic/dmx/status/scene", sceneName);
        }
        else
        {
            DBG("OSC: DMX scene '" << sceneName << "' not found");
        }
    }

    void recallSceneByIndex(int index)
    {
        auto scenes = dmxSceneManager.getAllScenes();
        if (index >= 0 && index < scenes.size())
        {
            recallScene(scenes[index].name);
        }
    }

    void saveScene(const juce::String& sceneName)
    {
        Echoel::DMXScene scene(sceneName, defaultFadeTimeMs);
        scene.captureFromDMX(currentDMXPacket);

        dmxSceneManager.addScene(scene);
        currentScene = sceneName;

        DBG("OSC: Saved DMX scene '" << sceneName << "'");

        oscManager.sendString("/echoelmusic/dmx/scene/save/result", "success");
    }

    void deleteScene(const juce::String& sceneName)
    {
        auto scene = dmxSceneManager.getScene(sceneName);
        if (scene != nullptr)
        {
            dmxSceneManager.removeScene(scene->id);
            DBG("OSC: Deleted DMX scene '" << sceneName << "'");
        }
    }

    //==========================================================================
    // Parsing helpers

    int parseChannelNumber(const juce::String& address) const
    {
        // Parse "/echoelmusic/dmx/channel/1" -> 1
        auto parts = juce::StringArray::fromTokens(address, "/", "");

        for (int i = 0; i < parts.size(); ++i)
        {
            if (parts[i] == "channel" && i + 1 < parts.size())
            {
                return parts[i + 1].getIntValue();
            }
        }

        return -1;
    }

    int parseSceneIndex(const juce::String& address) const
    {
        // Parse "/echoelmusic/dmx/scene/recall/0" -> 0
        auto parts = juce::StringArray::fromTokens(address, "/", "");

        for (int i = 0; i < parts.size(); ++i)
        {
            if (parts[i] == "recall" && i + 1 < parts.size())
            {
                return parts[i + 1].getIntValue();
            }
        }

        return -1;
    }

    juce::String parseFixtureName(const juce::String& address) const
    {
        // Parse "/echoelmusic/dmx/fixture/par1/intensity" -> "par1"
        auto parts = juce::StringArray::fromTokens(address, "/", "");

        for (int i = 0; i < parts.size(); ++i)
        {
            if (parts[i] == "fixture" && i + 1 < parts.size())
            {
                return parts[i + 1];
            }
        }

        return "";
    }

    //==========================================================================
    Echoel::DMXSceneManager& dmxSceneManager;
    Echoel::ArtNetController& artNetController;
    OSCManager& oscManager;

    // State
    Echoel::DMXPacket currentDMXPacket;
    juce::String currentScene;
    int defaultFadeTimeMs = 1000;

    // Art-Net configuration
    bool artNetEnabled = false;
    juce::String artNetIP = "255.255.255.255";  // Broadcast
    int artNetUniverse = 0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(DMXOSCBridge)
};

} // namespace Echoelmusic
