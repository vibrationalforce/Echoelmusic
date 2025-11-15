#include "PluginScanner.h"

namespace Echoelmusic {

PluginScanner::PluginScanner() {
    formatManager = std::make_unique<juce::AudioPluginFormatManager>();

    // Add supported formats
    #if JUCE_PLUGINHOST_VST3
    vst3Format = std::make_unique<juce::VST3PluginFormat>();
    formatManager->addFormat(vst3Format.get());
    #endif

    #if JUCE_PLUGINHOST_AU
    auFormat = std::make_unique<juce::AudioUnitPluginFormat>();
    formatManager->addFormat(auFormat.get());
    #endif
}

PluginScanner::~PluginScanner() {
}

void PluginScanner::scanForPlugins(std::function<void(float)> progressCallback) {
    pluginList.clear();

    int totalFormats = formatManager->getNumFormats();
    int currentFormat = 0;

    for (auto* format : formatManager->getFormats()) {
        juce::StringArray searchPaths;

        #if JUCE_MAC
        if (format->getName() == "AudioUnit") {
            searchPaths.add("~/Library/Audio/Plug-Ins/Components");
            searchPaths.add("/Library/Audio/Plug-Ins/Components");
        } else if (format->getName() == "VST3") {
            searchPaths.add("~/Library/Audio/Plug-Ins/VST3");
            searchPaths.add("/Library/Audio/Plug-Ins/VST3");
        }
        #elif JUCE_WINDOWS
        if (format->getName() == "VST3") {
            searchPaths.add("C:\\Program Files\\Common Files\\VST3");
            searchPaths.add("C:\\Program Files (x86)\\Common Files\\VST3");
        }
        #elif JUCE_LINUX
        if (format->getName() == "VST3") {
            searchPaths.add("~/.vst3");
            searchPaths.add("/usr/lib/vst3");
            searchPaths.add("/usr/local/lib/vst3");
        }
        #endif

        auto formatProgress = [&](float p) {
            if (progressCallback) {
                float overall = (currentFormat + p) / totalFormats;
                progressCallback(overall);
            }
        };

        scanFormat(format, searchPaths, formatProgress);
        currentFormat++;
    }
}

void PluginScanner::scanFormat(
    juce::AudioPluginFormat* format,
    const juce::StringArray& searchPaths,
    std::function<void(float)> progressCallback
) {
    juce::StringArray foundFiles;

    for (const auto& path : searchPaths) {
        juce::File folder(path);
        if (!folder.exists()) continue;

        for (juce::DirectoryIterator it(folder, true, "*", juce::File::findFiles); it.next();) {
            juce::File file = it.getFile();
            if (format->fileMightContainThisPluginType(file.getFullPathName())) {
                foundFiles.add(file.getFullPathName());
            }
        }
    }

    int totalFiles = foundFiles.size();
    int currentFile = 0;

    for (const auto& file : foundFiles) {
        juce::OwnedArray<juce::PluginDescription> descriptions;

        // Use out-of-process scanning for safety
        juce::KnownPluginList tempList;
        tempList.scanAndAddFile(file, false, descriptions, *format);

        for (auto* desc : descriptions) {
            if (!isBlacklisted(desc->createIdentifierString())) {
                if (validatePlugin(*desc)) {
                    pluginList.push_back(convertDescription(*desc));
                } else {
                    DBG("Failed to validate: " << desc->name);
                }
            }
        }

        currentFile++;
        if (progressCallback && totalFiles > 0) {
            progressCallback(static_cast<float>(currentFile) / totalFiles);
        }
    }
}

bool PluginScanner::validatePlugin(const juce::PluginDescription& desc) {
    // Basic validation
    if (desc.name.isEmpty()) return false;
    if (desc.pluginFormatName.isEmpty()) return false;

    // Check if plugin file exists
    juce::File pluginFile(desc.fileOrIdentifier);
    if (pluginFile.exists() && !pluginFile.existsAsFile()) {
        return false;
    }

    return true;
}

PluginScanner::PluginInfo PluginScanner::convertDescription(const juce::PluginDescription& desc) {
    PluginInfo info;
    info.name = desc.name;
    info.manufacturer = desc.manufacturerName;
    info.version = desc.version;
    info.pluginFormatName = desc.pluginFormatName;
    info.fileOrIdentifier = desc.fileOrIdentifier;
    info.category = inferCategory(desc);
    info.numInputChannels = desc.numInputChannels;
    info.numOutputChannels = desc.numOutputChannels;
    info.isInstrument = desc.isInstrument;
    info.hasEditor = desc.hasEditor;
    info.uid = desc.createIdentifierString();
    info.validated = true;

    juce::File pluginFile(desc.fileOrIdentifier);
    if (pluginFile.exists()) {
        info.lastModified = pluginFile.getLastModificationTime();
    }

    return info;
}

juce::String PluginScanner::inferCategory(const juce::PluginDescription& desc) {
    if (desc.isInstrument) {
        return "Instrument";
    }

    juce::String name = desc.name.toLowerCase();
    juce::String category = desc.category.toLowerCase();

    // EQ
    if (name.contains("eq") || category.contains("eq") ||
        name.contains("equalizer") || name.contains("equaliser")) {
        return "EQ";
    }

    // Dynamics
    if (name.contains("comp") || name.contains("limit") ||
        name.contains("gate") || name.contains("expander")) {
        return "Dynamics";
    }

    // Reverb
    if (name.contains("reverb") || name.contains("verb") || name.contains("room")) {
        return "Reverb";
    }

    // Delay
    if (name.contains("delay") || name.contains("echo")) {
        return "Delay";
    }

    // Modulation
    if (name.contains("chorus") || name.contains("flanger") ||
        name.contains("phaser") || name.contains("tremolo") ||
        name.contains("vibrato")) {
        return "Modulation";
    }

    // Distortion
    if (name.contains("dist") || name.contains("saturate") ||
        name.contains("overdrive") || name.contains("fuzz")) {
        return "Distortion";
    }

    // Filter
    if (name.contains("filter")) {
        return "Filter";
    }

    // Utility
    if (name.contains("gain") || name.contains("pan") ||
        name.contains("meter") || name.contains("analyzer")) {
        return "Utility";
    }

    return "Other";
}

std::vector<PluginScanner::PluginInfo> PluginScanner::getPluginsByCategory(const juce::String& category) const {
    std::vector<PluginInfo> result;
    for (const auto& plugin : pluginList) {
        if (plugin.category == category) {
            result.push_back(plugin);
        }
    }
    return result;
}

std::vector<PluginScanner::PluginInfo> PluginScanner::getInstruments() const {
    return getPluginsByCategory("Instrument");
}

std::vector<PluginScanner::PluginInfo> PluginScanner::getEffects() const {
    std::vector<PluginInfo> result;
    for (const auto& plugin : pluginList) {
        if (!plugin.isInstrument) {
            result.push_back(plugin);
        }
    }
    return result;
}

std::vector<PluginScanner::PluginInfo> PluginScanner::searchPlugins(const juce::String& searchText) const {
    std::vector<PluginInfo> result;
    juce::String lowerSearch = searchText.toLowerCase();

    for (const auto& plugin : pluginList) {
        if (plugin.name.toLowerCase().contains(lowerSearch) ||
            plugin.manufacturer.toLowerCase().contains(lowerSearch) ||
            plugin.category.toLowerCase().contains(lowerSearch)) {
            result.push_back(plugin);
        }
    }

    return result;
}

const PluginScanner::PluginInfo* PluginScanner::findPluginByUID(const juce::String& uid) const {
    for (const auto& plugin : pluginList) {
        if (plugin.uid == uid) {
            return &plugin;
        }
    }
    return nullptr;
}

void PluginScanner::blacklistPlugin(const juce::String& uid, const juce::String& reason) {
    blacklistedPlugins[uid] = reason;

    // Remove from plugin list
    pluginList.erase(
        std::remove_if(pluginList.begin(), pluginList.end(),
            [&uid](const PluginInfo& p) { return p.uid == uid; }),
        pluginList.end()
    );
}

void PluginScanner::removeFromBlacklist(const juce::String& uid) {
    blacklistedPlugins.erase(uid);
}

bool PluginScanner::isBlacklisted(const juce::String& uid) const {
    return blacklistedPlugins.find(uid) != blacklistedPlugins.end();
}

void PluginScanner::saveCacheToFile(const juce::File& cacheFile) {
    juce::XmlElement root("PluginCache");

    // Save plugin list
    auto* pluginsElement = root.createNewChildElement("Plugins");
    for (const auto& plugin : pluginList) {
        auto* pluginElement = pluginsElement->createNewChildElement("Plugin");
        pluginElement->setAttribute("name", plugin.name);
        pluginElement->setAttribute("manufacturer", plugin.manufacturer);
        pluginElement->setAttribute("version", plugin.version);
        pluginElement->setAttribute("format", plugin.pluginFormatName);
        pluginElement->setAttribute("file", plugin.fileOrIdentifier);
        pluginElement->setAttribute("category", plugin.category);
        pluginElement->setAttribute("uid", plugin.uid);
        pluginElement->setAttribute("inputs", plugin.numInputChannels);
        pluginElement->setAttribute("outputs", plugin.numOutputChannels);
        pluginElement->setAttribute("isInstrument", plugin.isInstrument);
        pluginElement->setAttribute("hasEditor", plugin.hasEditor);
    }

    // Save blacklist
    auto* blacklistElement = root.createNewChildElement("Blacklist");
    for (const auto& [uid, reason] : blacklistedPlugins) {
        auto* entry = blacklistElement->createNewChildElement("Entry");
        entry->setAttribute("uid", uid);
        entry->setAttribute("reason", reason);
    }

    root.writeTo(cacheFile);
}

void PluginScanner::loadCacheFromFile(const juce::File& cacheFile) {
    if (!cacheFile.existsAsFile()) return;

    auto xml = juce::XmlDocument::parse(cacheFile);
    if (!xml) return;

    pluginList.clear();
    blacklistedPlugins.clear();

    // Load plugins
    if (auto* pluginsElement = xml->getChildByName("Plugins")) {
        for (auto* pluginElement : pluginsElement->getChildIterator()) {
            PluginInfo info;
            info.name = pluginElement->getStringAttribute("name");
            info.manufacturer = pluginElement->getStringAttribute("manufacturer");
            info.version = pluginElement->getStringAttribute("version");
            info.pluginFormatName = pluginElement->getStringAttribute("format");
            info.fileOrIdentifier = pluginElement->getStringAttribute("file");
            info.category = pluginElement->getStringAttribute("category");
            info.uid = pluginElement->getStringAttribute("uid");
            info.numInputChannels = pluginElement->getIntAttribute("inputs");
            info.numOutputChannels = pluginElement->getIntAttribute("outputs");
            info.isInstrument = pluginElement->getBoolAttribute("isInstrument");
            info.hasEditor = pluginElement->getBoolAttribute("hasEditor");
            info.validated = true;

            pluginList.push_back(info);
        }
    }

    // Load blacklist
    if (auto* blacklistElement = xml->getChildByName("Blacklist")) {
        for (auto* entry : blacklistElement->getChildIterator()) {
            juce::String uid = entry->getStringAttribute("uid");
            juce::String reason = entry->getStringAttribute("reason");
            blacklistedPlugins[uid] = reason;
        }
    }
}

void PluginScanner::clearCache() {
    pluginList.clear();
    blacklistedPlugins.clear();
}

} // namespace Echoelmusic
