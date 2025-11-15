#pragma once

#include <JuceHeader.h>
#include "PluginScanner.h"
#include <memory>
#include <vector>

namespace Echoelmusic {

/**
 * PluginHost - Loads and processes VST3/AU/CLAP plugins
 *
 * Features:
 * - Real-time audio processing
 * - Parameter automation
 * - Preset management
 * - State save/load
 * - Editor window management
 * - MIDI input/output
 */
class PluginHost {
public:
    PluginHost();
    ~PluginHost();

    // Plugin loading
    bool loadPlugin(const juce::String& pluginUID,
                   const PluginScanner& scanner);
    bool loadPluginFromFile(const juce::File& pluginFile);
    void unloadPlugin();
    bool isPluginLoaded() const { return pluginInstance != nullptr; }

    // Audio processing
    void prepareToPlay(double sampleRate, int samplesPerBlock);
    void processBlock(juce::AudioBuffer<float>& buffer,
                     juce::MidiBuffer& midiMessages);
    void releaseResources();

    // Plugin info
    juce::String getPluginName() const;
    juce::String getPluginManufacturer() const;
    int getNumPrograms() const;
    int getCurrentProgram() const;
    void setCurrentProgram(int index);
    juce::String getProgramName(int index) const;

    // Parameters
    struct ParameterInfo {
        int index;
        juce::String name;
        juce::String label;  // e.g., "dB", "Hz", "%"
        float min;
        float max;
        float defaultValue;
        float currentValue;
        bool isAutomatable;
        juce::String category;
    };

    std::vector<ParameterInfo> getParameters() const;
    float getParameter(int index) const;
    void setParameter(int index, float value);
    void setParameterNormalized(int index, float normalizedValue);  // 0-1

    // Parameter automation
    void beginParameterChange(int index);
    void endParameterChange(int index);

    // Editor/GUI
    bool hasEditor() const;
    void createEditor(juce::Component* parentComponent);
    void closeEditor();
    juce::Component* getEditorComponent() { return editorComponent.get(); }

    // State management
    juce::MemoryBlock getStateInformation() const;
    bool setStateInformation(const void* data, int sizeInBytes);

    // Preset management
    bool loadPreset(const juce::File& presetFile);
    bool savePreset(const juce::File& presetFile);
    std::vector<juce::String> getFactoryPresets() const;
    bool loadFactoryPreset(const juce::String& presetName);

    // Latency
    int getLatencySamples() const;

    // MIDI
    void sendMIDIMessage(const juce::MidiMessage& message);
    bool acceptsMIDI() const;
    bool producesMIDI() const;

    // Bypass
    void setBypass(bool shouldBypass) { bypassed = shouldBypass; }
    bool isBypassed() const { return bypassed; }

    // Callbacks
    std::function<void(int paramIndex, float newValue)> onParameterChanged;
    std::function<void()> onPluginLoaded;
    std::function<void()> onPluginUnloaded;

private:
    std::unique_ptr<juce::AudioPluginInstance> pluginInstance;
    std::unique_ptr<juce::AudioPluginFormatManager> formatManager;
    std::unique_ptr<juce::Component> editorComponent;

    juce::PluginDescription currentPluginDesc;
    double currentSampleRate = 44100.0;
    int currentSamplesPerBlock = 512;
    bool bypassed = false;

    // Parameter change tracking
    std::set<int> parametersBeingChanged;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PluginHost)
};

/**
 * PluginChain - Chain multiple plugins in series
 */
class PluginChain {
public:
    PluginChain();
    ~PluginChain();

    // Plugin management
    int addPlugin(const juce::String& pluginUID, const PluginScanner& scanner);
    bool removePlugin(int index);
    bool movePlugin(int fromIndex, int toIndex);
    int getNumPlugins() const { return static_cast<int>(plugins.size()); }
    PluginHost* getPlugin(int index);

    // Audio processing
    void prepareToPlay(double sampleRate, int samplesPerBlock);
    void processBlock(juce::AudioBuffer<float>& buffer,
                     juce::MidiBuffer& midiMessages);
    void releaseResources();

    // Bypass
    void setPluginBypass(int index, bool shouldBypass);
    bool isPluginBypassed(int index) const;

    // State
    juce::MemoryBlock getStateInformation() const;
    bool setStateInformation(const void* data, int sizeInBytes);

private:
    std::vector<std::unique_ptr<PluginHost>> plugins;
    std::vector<bool> bypassStates;

    double currentSampleRate = 44100.0;
    int currentSamplesPerBlock = 512;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PluginChain)
};

} // namespace Echoelmusic
