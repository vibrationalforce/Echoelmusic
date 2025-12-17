// DMXSceneManager.h - Professional Scene Management
// Save, recall, and crossfade between lighting scenes
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include "LightController.h"
#include "DMXFixtureLibrary.h"
#include <JuceHeader.h>
#include <vector>
#include <map>

namespace Echoel {

// ==================== DMX SCENE ====================

struct DMXScene {
    juce::String name;
    juce::Uuid id;
    std::array<uint8_t, 512> universeData;  // Full DMX universe snapshot
    int fadeTimeMs{1000};  // Crossfade time
    juce::Colour sceneColor{juce::Colours::grey};  // Visual identifier
    juce::String notes;  // User notes

    DMXScene() : id(juce::Uuid()) {
        universeData.fill(0);
    }

    DMXScene(const juce::String& n, int fadeMs = 1000)
        : name(n), id(juce::Uuid()), fadeTimeMs(fadeMs) {
        universeData.fill(0);
    }

    void captureFromDMX(const DMXPacket& dmx) {
        const auto& data = dmx.getData();
        std::copy(data.begin(), data.end(), universeData.begin());
    }

    DMXPacket toDMXPacket() const {
        DMXPacket packet;
        for (int i = 0; i < 512; ++i) {
            packet.setChannel(i + 1, universeData[i]);  // DMX is 1-indexed
        }
        return packet;
    }

    // JSON serialization
    juce::var toJSON() const {
        auto* obj = new juce::DynamicObject();
        obj->setProperty("name", name);
        obj->setProperty("id", id.toString());
        obj->setProperty("fadeTimeMs", fadeTimeMs);
        obj->setProperty("color", sceneColor.toString());
        obj->setProperty("notes", notes);

        // Serialize DMX data as base64
        juce::MemoryBlock block(universeData.data(), universeData.size());
        obj->setProperty("dmxData", block.toBase64Encoding());

        return juce::var(obj);
    }

    static DMXScene fromJSON(const juce::var& json) {
        DMXScene scene;
        scene.name = json["name"].toString();
        scene.id = juce::Uuid(json["id"].toString());
        scene.fadeTimeMs = static_cast<int>(json["fadeTimeMs"]);
        scene.sceneColor = juce::Colour::fromString(json["color"].toString());
        scene.notes = json["notes"].toString();

        // Deserialize DMX data from base64
        juce::String base64Data = json["dmxData"].toString();
        juce::MemoryBlock block;
        block.fromBase64Encoding(base64Data);

        if (block.getSize() == 512) {
            std::memcpy(scene.universeData.data(), block.getData(), 512);
        }

        return scene;
    }
};

// ==================== SCENE MANAGER ====================

class DMXSceneManager {
public:
    DMXSceneManager() = default;

    //==========================================================================
    // Scene Management
    //==========================================================================

    void addScene(const DMXScene& scene) {
        scenes.push_back(scene);
    }

    void removeScene(const juce::Uuid& sceneId) {
        scenes.erase(std::remove_if(scenes.begin(), scenes.end(),
            [&sceneId](const DMXScene& scene) { return scene.id == sceneId; }),
            scenes.end());
    }

    DMXScene* getScene(const juce::Uuid& sceneId) {
        for (auto& scene : scenes) {
            if (scene.id == sceneId)
                return &scene;
        }
        return nullptr;
    }

    const std::vector<DMXScene>& getAllScenes() const {
        return scenes;
    }

    DMXScene* getSceneByIndex(int index) {
        if (index >= 0 && index < static_cast<int>(scenes.size()))
            return &scenes[index];
        return nullptr;
    }

    int getNumScenes() const {
        return static_cast<int>(scenes.size());
    }

    //==========================================================================
    // Scene Recall with Crossfade
    //==========================================================================

    void recallScene(const juce::Uuid& sceneId, DMXPacket& outputDMX) {
        auto* scene = getScene(sceneId);
        if (!scene)
            return;

        if (isCrossfading) {
            stopCrossfade();
        }

        // Start crossfade
        currentScene = *scene;
        targetScene = *scene;
        crossfadeStartTime = juce::Time::getMillisecondCounter();
        crossfadeDuration = scene->fadeTimeMs;
        isCrossfading = true;

        // Copy current DMX state as starting point
        const auto& currentData = outputDMX.getData();
        std::copy(currentData.begin(), currentData.end(), currentScene.universeData.begin());
    }

    void updateCrossfade(DMXPacket& outputDMX) {
        if (!isCrossfading)
            return;

        auto currentTime = juce::Time::getMillisecondCounter();
        auto elapsed = currentTime - crossfadeStartTime;

        if (elapsed >= static_cast<uint32>(crossfadeDuration)) {
            // Crossfade complete
            isCrossfading = false;
            outputDMX = targetScene.toDMXPacket();
            currentScene = targetScene;
            return;
        }

        // Calculate crossfade progress (0.0 to 1.0)
        float progress = static_cast<float>(elapsed) / static_cast<float>(crossfadeDuration);

        // Smooth easing (ease-in-out)
        progress = progress < 0.5f
            ? 2.0f * progress * progress
            : 1.0f - std::pow(-2.0f * progress + 2.0f, 2.0f) / 2.0f;

        // Interpolate between current and target scenes
        for (int i = 0; i < 512; ++i) {
            uint8_t currentValue = currentScene.universeData[i];
            uint8_t targetValue = targetScene.universeData[i];

            uint8_t interpolatedValue = static_cast<uint8_t>(
                currentValue + (targetValue - currentValue) * progress
            );

            outputDMX.setChannel(i + 1, interpolatedValue);
        }
    }

    void stopCrossfade() {
        isCrossfading = false;
    }

    bool isCrossfadeActive() const {
        return isCrossfading;
    }

    //==========================================================================
    // Save/Load Scene Banks
    //==========================================================================

    bool saveSceneBank(const juce::File& file) const {
        auto* obj = new juce::DynamicObject();
        obj->setProperty("version", 1);
        obj->setProperty("sceneCount", static_cast<int>(scenes.size()));

        juce::Array<juce::var> sceneArray;
        for (const auto& scene : scenes) {
            sceneArray.add(scene.toJSON());
        }

        obj->setProperty("scenes", sceneArray);

        juce::var jsonData(obj);
        juce::String jsonString = juce::JSON::toString(jsonData, true);

        return file.replaceWithText(jsonString);
    }

    bool loadSceneBank(const juce::File& file) {
        if (!file.existsAsFile())
            return false;

        juce::String jsonString = file.loadFileAsString();
        juce::var jsonData = juce::JSON::parse(jsonString);

        if (!jsonData.isObject())
            return false;

        scenes.clear();

        juce::Array<juce::var>* sceneArray = jsonData["scenes"].getArray();
        if (sceneArray != nullptr) {
            for (const auto& sceneVar : *sceneArray) {
                scenes.push_back(DMXScene::fromJSON(sceneVar));
            }
        }

        return true;
    }

    juce::File getDefaultSceneBankFile() const {
        auto documentsDir = juce::File::getSpecialLocation(juce::File::userDocumentsDirectory);
        auto scenesDir = documentsDir.getChildFile("Echoelmusic").getChildFile("DMX_Scenes");

        if (!scenesDir.exists())
            scenesDir.createDirectory();

        return scenesDir.getChildFile("default_scene_bank.json");
    }

    //==========================================================================
    // Quick Scene Slots (0-9 for keyboard shortcuts)
    //==========================================================================

    void assignSceneToSlot(int slotNumber, const juce::Uuid& sceneId) {
        if (slotNumber >= 0 && slotNumber < 10) {
            quickSlots[slotNumber] = sceneId;
        }
    }

    juce::Uuid getSceneFromSlot(int slotNumber) const {
        if (slotNumber >= 0 && slotNumber < 10) {
            return quickSlots[slotNumber];
        }
        return juce::Uuid();
    }

    void recallQuickSlot(int slotNumber, DMXPacket& outputDMX) {
        auto sceneId = getSceneFromSlot(slotNumber);
        if (!sceneId.isNull()) {
            recallScene(sceneId, outputDMX);
        }
    }

    //==========================================================================
    // Status & Diagnostics
    //==========================================================================

    juce::String getStatus() const {
        juce::String status;
        status << "🎭 DMX Scene Manager Status\n";
        status << "====================================\n\n";
        status << "Total Scenes: " << scenes.size() << "\n";
        status << "Crossfade Active: " << (isCrossfading ? "Yes" : "No") << "\n";

        if (isCrossfading) {
            auto currentTime = juce::Time::getMillisecondCounter();
            auto elapsed = currentTime - crossfadeStartTime;
            float progress = (static_cast<float>(elapsed) / static_cast<float>(crossfadeDuration)) * 100.0f;
            status << "Crossfade Progress: " << juce::String(progress, 1) << "%\n";
        }

        status << "\nQuick Slots:\n";
        for (int i = 0; i < 10; ++i) {
            if (!quickSlots[i].isNull()) {
                auto* scene = const_cast<DMXSceneManager*>(this)->getScene(quickSlots[i]);
                if (scene) {
                    status << "  [" << i << "] " << scene->name << "\n";
                }
            }
        }

        return status;
    }

private:
    std::vector<DMXScene> scenes;

    // Crossfade state
    bool isCrossfading{false};
    DMXScene currentScene;
    DMXScene targetScene;
    uint32 crossfadeStartTime{0};
    int crossfadeDuration{1000};

    // Quick recall slots (keyboard shortcuts 0-9)
    std::array<juce::Uuid, 10> quickSlots;
};

} // namespace Echoel
