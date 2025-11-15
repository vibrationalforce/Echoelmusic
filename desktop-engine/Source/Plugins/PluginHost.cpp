#include "PluginHost.h"

namespace Echoelmusic {

PluginHost::PluginHost() {
    formatManager = std::make_unique<juce::AudioPluginFormatManager>();

    #if JUCE_PLUGINHOST_VST3
    formatManager->addDefaultFormats();
    #endif
}

PluginHost::~PluginHost() {
    closeEditor();
    unloadPlugin();
}

bool PluginHost::loadPlugin(const juce::String& pluginUID, const PluginScanner& scanner) {
    // Find plugin in scanner
    const auto* pluginInfo = scanner.findPluginByUID(pluginUID);
    if (!pluginInfo) {
        DBG("Plugin not found: " << pluginUID);
        return false;
    }

    return loadPluginFromFile(juce::File(pluginInfo->fileOrIdentifier));
}

bool PluginHost::loadPluginFromFile(const juce::File& pluginFile) {
    // Unload current plugin
    unloadPlugin();

    // Find appropriate format
    juce::AudioPluginFormat* format = nullptr;
    for (auto* fmt : formatManager->getFormats()) {
        if (fmt->fileMightContainThisPluginType(pluginFile.getFullPathName())) {
            format = fmt;
            break;
        }
    }

    if (!format) {
        DBG("No suitable format found for: " << pluginFile.getFullPathName());
        return false;
    }

    // Load plugin description
    juce::OwnedArray<juce::PluginDescription> descriptions;
    juce::KnownPluginList tempList;
    tempList.scanAndAddFile(pluginFile.getFullPathName(), false, descriptions, *format);

    if (descriptions.isEmpty()) {
        DBG("Failed to get plugin description");
        return false;
    }

    currentPluginDesc = *descriptions[0];

    // Create plugin instance
    juce::String errorMessage;
    pluginInstance.reset(format->createInstanceFromDescription(
        currentPluginDesc,
        currentSampleRate,
        currentSamplesPerBlock,
        errorMessage
    ));

    if (!pluginInstance) {
        DBG("Failed to create plugin instance: " << errorMessage);
        return false;
    }

    // Prepare plugin
    pluginInstance->prepareToPlay(currentSampleRate, currentSamplesPerBlock);

    if (onPluginLoaded) {
        onPluginLoaded();
    }

    return true;
}

void PluginHost::unloadPlugin() {
    closeEditor();

    if (pluginInstance) {
        pluginInstance->releaseResources();
        pluginInstance.reset();

        if (onPluginUnloaded) {
            onPluginUnloaded();
        }
    }
}

void PluginHost::prepareToPlay(double sampleRate, int samplesPerBlock) {
    currentSampleRate = sampleRate;
    currentSamplesPerBlock = samplesPerBlock;

    if (pluginInstance) {
        pluginInstance->prepareToPlay(sampleRate, samplesPerBlock);
    }
}

void PluginHost::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages) {
    if (!pluginInstance || bypassed) {
        return;  // Pass through
    }

    pluginInstance->processBlock(buffer, midiMessages);
}

void PluginHost::releaseResources() {
    if (pluginInstance) {
        pluginInstance->releaseResources();
    }
}

juce::String PluginHost::getPluginName() const {
    return pluginInstance ? pluginInstance->getName() : juce::String();
}

juce::String PluginHost::getPluginManufacturer() const {
    return currentPluginDesc.manufacturerName;
}

int PluginHost::getNumPrograms() const {
    return pluginInstance ? pluginInstance->getNumPrograms() : 0;
}

int PluginHost::getCurrentProgram() const {
    return pluginInstance ? pluginInstance->getCurrentProgram() : 0;
}

void PluginHost::setCurrentProgram(int index) {
    if (pluginInstance && index >= 0 && index < getNumPrograms()) {
        pluginInstance->setCurrentProgram(index);
    }
}

juce::String PluginHost::getProgramName(int index) const {
    return pluginInstance ? pluginInstance->getProgramName(index) : juce::String();
}

std::vector<PluginHost::ParameterInfo> PluginHost::getParameters() const {
    std::vector<ParameterInfo> params;

    if (!pluginInstance) return params;

    int numParams = pluginInstance->getNumParameters();
    params.reserve(numParams);

    for (int i = 0; i < numParams; ++i) {
        ParameterInfo info;
        info.index = i;
        info.name = pluginInstance->getParameterName(i);
        info.label = pluginInstance->getParameterLabel(i);
        info.currentValue = pluginInstance->getParameter(i);
        info.defaultValue = pluginInstance->getParameterDefaultValue(i);
        info.min = 0.0f;
        info.max = 1.0f;
        info.isAutomatable = true;
        info.category = "";

        params.push_back(info);
    }

    return params;
}

float PluginHost::getParameter(int index) const {
    return pluginInstance ? pluginInstance->getParameter(index) : 0.0f;
}

void PluginHost::setParameter(int index, float value) {
    if (pluginInstance && index >= 0 && index < pluginInstance->getNumParameters()) {
        pluginInstance->setParameter(index, value);

        if (onParameterChanged) {
            onParameterChanged(index, value);
        }
    }
}

void PluginHost::setParameterNormalized(int index, float normalizedValue) {
    setParameter(index, juce::jlimit(0.0f, 1.0f, normalizedValue));
}

void PluginHost::beginParameterChange(int index) {
    parametersBeingChanged.insert(index);

    if (pluginInstance) {
        pluginInstance->beginParameterChangeGesture(index);
    }
}

void PluginHost::endParameterChange(int index) {
    parametersBeingChanged.erase(index);

    if (pluginInstance) {
        pluginInstance->endParameterChangeGesture(index);
    }
}

bool PluginHost::hasEditor() const {
    return pluginInstance ? pluginInstance->hasEditor() : false;
}

void PluginHost::createEditor(juce::Component* parentComponent) {
    if (!pluginInstance || !hasEditor()) return;

    closeEditor();

    editorComponent.reset(pluginInstance->createEditorIfNeeded());

    if (editorComponent && parentComponent) {
        parentComponent->addAndMakeVisible(editorComponent.get());
        parentComponent->setSize(editorComponent->getWidth(), editorComponent->getHeight());
    }
}

void PluginHost::closeEditor() {
    if (editorComponent) {
        if (pluginInstance) {
            pluginInstance->editorBeingDeleted(editorComponent.get());
        }
        editorComponent.reset();
    }
}

juce::MemoryBlock PluginHost::getStateInformation() const {
    juce::MemoryBlock state;

    if (pluginInstance) {
        pluginInstance->getStateInformation(state);
    }

    return state;
}

bool PluginHost::setStateInformation(const void* data, int sizeInBytes) {
    if (!pluginInstance) return false;

    pluginInstance->setStateInformation(data, sizeInBytes);
    return true;
}

bool PluginHost::loadPreset(const juce::File& presetFile) {
    if (!presetFile.existsAsFile()) return false;

    juce::FileInputStream stream(presetFile);
    if (!stream.openedOk()) return false;

    juce::MemoryBlock data;
    stream.readIntoMemoryBlock(data);

    return setStateInformation(data.getData(), static_cast<int>(data.getSize()));
}

bool PluginHost::savePreset(const juce::File& presetFile) {
    auto state = getStateInformation();

    presetFile.create();
    juce::FileOutputStream stream(presetFile);

    if (!stream.openedOk()) return false;

    return stream.write(state.getData(), state.getSize());
}

std::vector<juce::String> PluginHost::getFactoryPresets() const {
    std::vector<juce::String> presets;

    if (pluginInstance) {
        int numPrograms = pluginInstance->getNumPrograms();
        for (int i = 0; i < numPrograms; ++i) {
            presets.push_back(pluginInstance->getProgramName(i));
        }
    }

    return presets;
}

bool PluginHost::loadFactoryPreset(const juce::String& presetName) {
    if (!pluginInstance) return false;

    int numPrograms = pluginInstance->getNumPrograms();
    for (int i = 0; i < numPrograms; ++i) {
        if (pluginInstance->getProgramName(i) == presetName) {
            pluginInstance->setCurrentProgram(i);
            return true;
        }
    }

    return false;
}

int PluginHost::getLatencySamples() const {
    return pluginInstance ? pluginInstance->getLatencySamples() : 0;
}

void PluginHost::sendMIDIMessage(const juce::MidiMessage& message) {
    // In real-time context, would queue this for processing
    if (pluginInstance && acceptsMIDI()) {
        juce::MidiBuffer buffer;
        buffer.addEvent(message, 0);
        // Process in next audio callback
    }
}

bool PluginHost::acceptsMIDI() const {
    return pluginInstance ? pluginInstance->acceptsMidi() : false;
}

bool PluginHost::producesMIDI() const {
    return pluginInstance ? pluginInstance->producesMidi() : false;
}

// ============================================================================
// PluginChain Implementation
// ============================================================================

PluginChain::PluginChain() {
}

PluginChain::~PluginChain() {
    plugins.clear();
}

int PluginChain::addPlugin(const juce::String& pluginUID, const PluginScanner& scanner) {
    auto plugin = std::make_unique<PluginHost>();

    if (!plugin->loadPlugin(pluginUID, scanner)) {
        return -1;
    }

    plugin->prepareToPlay(currentSampleRate, currentSamplesPerBlock);

    plugins.push_back(std::move(plugin));
    bypassStates.push_back(false);

    return static_cast<int>(plugins.size()) - 1;
}

bool PluginChain::removePlugin(int index) {
    if (index < 0 || index >= static_cast<int>(plugins.size())) {
        return false;
    }

    plugins.erase(plugins.begin() + index);
    bypassStates.erase(bypassStates.begin() + index);

    return true;
}

bool PluginChain::movePlugin(int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= static_cast<int>(plugins.size()) ||
        toIndex < 0 || toIndex >= static_cast<int>(plugins.size())) {
        return false;
    }

    std::swap(plugins[fromIndex], plugins[toIndex]);
    std::swap(bypassStates[fromIndex], bypassStates[toIndex]);

    return true;
}

PluginHost* PluginChain::getPlugin(int index) {
    if (index >= 0 && index < static_cast<int>(plugins.size())) {
        return plugins[index].get();
    }
    return nullptr;
}

void PluginChain::prepareToPlay(double sampleRate, int samplesPerBlock) {
    currentSampleRate = sampleRate;
    currentSamplesPerBlock = samplesPerBlock;

    for (auto& plugin : plugins) {
        plugin->prepareToPlay(sampleRate, samplesPerBlock);
    }
}

void PluginChain::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages) {
    for (size_t i = 0; i < plugins.size(); ++i) {
        if (!bypassStates[i]) {
            plugins[i]->processBlock(buffer, midiMessages);
        }
    }
}

void PluginChain::releaseResources() {
    for (auto& plugin : plugins) {
        plugin->releaseResources();
    }
}

void PluginChain::setPluginBypass(int index, bool shouldBypass) {
    if (index >= 0 && index < static_cast<int>(bypassStates.size())) {
        bypassStates[index] = shouldBypass;
        if (plugins[index]) {
            plugins[index]->setBypass(shouldBypass);
        }
    }
}

bool PluginChain::isPluginBypassed(int index) const {
    if (index >= 0 && index < static_cast<int>(bypassStates.size())) {
        return bypassStates[index];
    }
    return false;
}

juce::MemoryBlock PluginChain::getStateInformation() const {
    juce::MemoryBlock state;
    juce::MemoryOutputStream stream(state, false);

    // Write number of plugins
    stream.writeInt(static_cast<int>(plugins.size()));

    // Write each plugin's state
    for (size_t i = 0; i < plugins.size(); ++i) {
        auto pluginState = plugins[i]->getStateInformation();
        stream.writeInt(static_cast<int>(pluginState.getSize()));
        stream.write(pluginState.getData(), pluginState.getSize());
        stream.writeBool(bypassStates[i]);
    }

    return state;
}

bool PluginChain::setStateInformation(const void* data, int sizeInBytes) {
    juce::MemoryInputStream stream(data, sizeInBytes, false);

    int numPlugins = stream.readInt();

    // This is simplified - in production would need to handle plugin loading
    for (int i = 0; i < numPlugins && i < static_cast<int>(plugins.size()); ++i) {
        int stateSize = stream.readInt();

        if (stateSize > 0) {
            juce::MemoryBlock pluginState(stateSize);
            stream.read(pluginState.getData(), stateSize);
            plugins[i]->setStateInformation(pluginState.getData(), stateSize);
        }

        bypassStates[i] = stream.readBool();
    }

    return true;
}

} // namespace Echoelmusic
