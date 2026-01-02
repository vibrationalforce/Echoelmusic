/*
  ==============================================================================

    TrackTemplates.h
    Created: 2026
    Author:  Echoelmusic

    Track Template System
    Pre-configured track setups with routing, effects, and settings

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <map>

namespace Echoelmusic {
namespace Project {

//==============================================================================
/** Track type for templates */
enum class TrackType {
    Audio,
    Instrument,
    MIDI,
    Aux,
    Bus,
    VCA,
    Master,
    Video,
    Folder
};

inline juce::String trackTypeToString(TrackType type) {
    switch (type) {
        case TrackType::Audio:      return "Audio";
        case TrackType::Instrument: return "Instrument";
        case TrackType::MIDI:       return "MIDI";
        case TrackType::Aux:        return "Auxiliary";
        case TrackType::Bus:        return "Bus";
        case TrackType::VCA:        return "VCA";
        case TrackType::Master:     return "Master";
        case TrackType::Video:      return "Video";
        case TrackType::Folder:     return "Folder";
        default:                    return "Unknown";
    }
}

//==============================================================================
/** Plugin slot in template */
struct TemplatePluginSlot {
    juce::String pluginId;      // Plugin identifier
    juce::String pluginName;    // Human-readable name
    juce::String presetName;    // Optional preset to load
    bool bypassed = false;
    int slotIndex = 0;

    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("pluginId", pluginId);
        obj->setProperty("pluginName", pluginName);
        obj->setProperty("presetName", presetName);
        obj->setProperty("bypassed", bypassed);
        obj->setProperty("slotIndex", slotIndex);
        return juce::var(obj);
    }

    static TemplatePluginSlot fromVar(const juce::var& v) {
        TemplatePluginSlot slot;
        if (auto* obj = v.getDynamicObject()) {
            slot.pluginId = obj->getProperty("pluginId").toString();
            slot.pluginName = obj->getProperty("pluginName").toString();
            slot.presetName = obj->getProperty("presetName").toString();
            slot.bypassed = obj->getProperty("bypassed");
            slot.slotIndex = obj->getProperty("slotIndex");
        }
        return slot;
    }
};

//==============================================================================
/** Send configuration in template */
struct TemplateSend {
    juce::String destinationName;  // Name of destination bus
    float level = 0.0f;            // Send level (0.0 - 1.0)
    bool preFader = false;
    bool muted = false;

    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("destination", destinationName);
        obj->setProperty("level", level);
        obj->setProperty("preFader", preFader);
        obj->setProperty("muted", muted);
        return juce::var(obj);
    }

    static TemplateSend fromVar(const juce::var& v) {
        TemplateSend send;
        if (auto* obj = v.getDynamicObject()) {
            send.destinationName = obj->getProperty("destination").toString();
            send.level = obj->getProperty("level");
            send.preFader = obj->getProperty("preFader");
            send.muted = obj->getProperty("muted");
        }
        return send;
    }
};

//==============================================================================
/** I/O configuration for template */
struct TemplateIO {
    int numInputChannels = 2;
    int numOutputChannels = 2;
    juce::String inputSource;      // Hardware input or bus
    juce::String outputDestination; // Hardware output or bus

    juce::var toVar() const {
        auto obj = new juce::DynamicObject();
        obj->setProperty("numInputs", numInputChannels);
        obj->setProperty("numOutputs", numOutputChannels);
        obj->setProperty("inputSource", inputSource);
        obj->setProperty("outputDest", outputDestination);
        return juce::var(obj);
    }

    static TemplateIO fromVar(const juce::var& v) {
        TemplateIO io;
        if (auto* obj = v.getDynamicObject()) {
            io.numInputChannels = obj->getProperty("numInputs");
            io.numOutputChannels = obj->getProperty("numOutputs");
            io.inputSource = obj->getProperty("inputSource").toString();
            io.outputDestination = obj->getProperty("outputDest").toString();
        }
        return io;
    }
};

//==============================================================================
/** Track template definition */
class TrackTemplate {
public:
    TrackTemplate(const juce::String& name = "New Template")
        : name_(name)
    {
        id_ = juce::Uuid().toString();
    }

    //==============================================================================
    // Basic info
    juce::String getId() const { return id_; }
    juce::String getName() const { return name_; }
    void setName(const juce::String& name) { name_ = name; }

    juce::String getDescription() const { return description_; }
    void setDescription(const juce::String& desc) { description_ = desc; }

    TrackType getType() const { return trackType_; }
    void setType(TrackType type) { trackType_ = type; }

    juce::String getCategory() const { return category_; }
    void setCategory(const juce::String& cat) { category_ = cat; }

    //==============================================================================
    // Visual settings
    juce::Colour getColour() const { return colour_; }
    void setColour(juce::Colour colour) { colour_ = colour; }

    juce::String getIcon() const { return icon_; }
    void setIcon(const juce::String& icon) { icon_ = icon; }

    int getDefaultHeight() const { return defaultHeight_; }
    void setDefaultHeight(int height) { defaultHeight_ = height; }

    //==============================================================================
    // Audio settings
    float getDefaultVolume() const { return defaultVolume_; }
    void setDefaultVolume(float vol) { defaultVolume_ = juce::jlimit(0.0f, 2.0f, vol); }

    float getDefaultPan() const { return defaultPan_; }
    void setDefaultPan(float pan) { defaultPan_ = juce::jlimit(-1.0f, 1.0f, pan); }

    bool isRecordEnabled() const { return recordEnabled_; }
    void setRecordEnabled(bool enabled) { recordEnabled_ = enabled; }

    bool isMonitorEnabled() const { return monitorEnabled_; }
    void setMonitorEnabled(bool enabled) { monitorEnabled_ = enabled; }

    //==============================================================================
    // I/O configuration
    TemplateIO& getIO() { return io_; }
    const TemplateIO& getIO() const { return io_; }

    //==============================================================================
    // Plugins
    void addPlugin(const TemplatePluginSlot& plugin) {
        plugins_.push_back(plugin);
    }

    void removePlugin(int index) {
        if (index >= 0 && index < static_cast<int>(plugins_.size())) {
            plugins_.erase(plugins_.begin() + index);
        }
    }

    void clearPlugins() { plugins_.clear(); }

    const std::vector<TemplatePluginSlot>& getPlugins() const { return plugins_; }

    //==============================================================================
    // Sends
    void addSend(const TemplateSend& send) {
        sends_.push_back(send);
    }

    void removeSend(int index) {
        if (index >= 0 && index < static_cast<int>(sends_.size())) {
            sends_.erase(sends_.begin() + index);
        }
    }

    void clearSends() { sends_.clear(); }

    const std::vector<TemplateSend>& getSends() const { return sends_; }

    //==============================================================================
    // Serialization
    juce::var toVar() const {
        auto obj = new juce::DynamicObject();

        obj->setProperty("id", id_);
        obj->setProperty("name", name_);
        obj->setProperty("description", description_);
        obj->setProperty("type", static_cast<int>(trackType_));
        obj->setProperty("category", category_);
        obj->setProperty("colour", colour_.toString());
        obj->setProperty("icon", icon_);
        obj->setProperty("defaultHeight", defaultHeight_);
        obj->setProperty("defaultVolume", defaultVolume_);
        obj->setProperty("defaultPan", defaultPan_);
        obj->setProperty("recordEnabled", recordEnabled_);
        obj->setProperty("monitorEnabled", monitorEnabled_);
        obj->setProperty("io", io_.toVar());

        juce::var pluginsArray;
        for (const auto& plugin : plugins_) {
            pluginsArray.append(plugin.toVar());
        }
        obj->setProperty("plugins", pluginsArray);

        juce::var sendsArray;
        for (const auto& send : sends_) {
            sendsArray.append(send.toVar());
        }
        obj->setProperty("sends", sendsArray);

        return juce::var(obj);
    }

    static std::unique_ptr<TrackTemplate> fromVar(const juce::var& v) {
        auto tmpl = std::make_unique<TrackTemplate>();

        if (auto* obj = v.getDynamicObject()) {
            tmpl->id_ = obj->getProperty("id").toString();
            tmpl->name_ = obj->getProperty("name").toString();
            tmpl->description_ = obj->getProperty("description").toString();
            tmpl->trackType_ = static_cast<TrackType>(int(obj->getProperty("type")));
            tmpl->category_ = obj->getProperty("category").toString();
            tmpl->colour_ = juce::Colour::fromString(obj->getProperty("colour").toString());
            tmpl->icon_ = obj->getProperty("icon").toString();
            tmpl->defaultHeight_ = obj->getProperty("defaultHeight");
            tmpl->defaultVolume_ = obj->getProperty("defaultVolume");
            tmpl->defaultPan_ = obj->getProperty("defaultPan");
            tmpl->recordEnabled_ = obj->getProperty("recordEnabled");
            tmpl->monitorEnabled_ = obj->getProperty("monitorEnabled");
            tmpl->io_ = TemplateIO::fromVar(obj->getProperty("io"));

            if (auto* plugins = obj->getProperty("plugins").getArray()) {
                for (const auto& p : *plugins) {
                    tmpl->plugins_.push_back(TemplatePluginSlot::fromVar(p));
                }
            }

            if (auto* sends = obj->getProperty("sends").getArray()) {
                for (const auto& s : *sends) {
                    tmpl->sends_.push_back(TemplateSend::fromVar(s));
                }
            }
        }

        return tmpl;
    }

private:
    juce::String id_;
    juce::String name_;
    juce::String description_;
    TrackType trackType_ = TrackType::Audio;
    juce::String category_ = "General";

    juce::Colour colour_ = juce::Colours::grey;
    juce::String icon_;
    int defaultHeight_ = 80;

    float defaultVolume_ = 1.0f;
    float defaultPan_ = 0.0f;
    bool recordEnabled_ = false;
    bool monitorEnabled_ = false;

    TemplateIO io_;
    std::vector<TemplatePluginSlot> plugins_;
    std::vector<TemplateSend> sends_;
};

//==============================================================================
/** Track Template Manager */
class TrackTemplateManager {
public:
    TrackTemplateManager() {
        createBuiltInTemplates();
    }

    //==============================================================================
    /** Create new template */
    TrackTemplate* createTemplate(const juce::String& name) {
        auto tmpl = std::make_unique<TrackTemplate>(name);
        TrackTemplate* ptr = tmpl.get();
        templates_[tmpl->getId()] = std::move(tmpl);
        return ptr;
    }

    /** Add existing template */
    void addTemplate(std::unique_ptr<TrackTemplate> tmpl) {
        templates_[tmpl->getId()] = std::move(tmpl);
    }

    /** Remove template */
    void removeTemplate(const juce::String& id) {
        templates_.erase(id);
    }

    /** Get template by ID */
    TrackTemplate* getTemplate(const juce::String& id) {
        auto it = templates_.find(id);
        return it != templates_.end() ? it->second.get() : nullptr;
    }

    /** Get template by name */
    TrackTemplate* getTemplateByName(const juce::String& name) {
        for (auto& pair : templates_) {
            if (pair.second->getName() == name) {
                return pair.second.get();
            }
        }
        return nullptr;
    }

    //==============================================================================
    /** Get all templates */
    std::vector<TrackTemplate*> getAllTemplates() {
        std::vector<TrackTemplate*> result;
        for (auto& pair : templates_) {
            result.push_back(pair.second.get());
        }
        return result;
    }

    /** Get templates by category */
    std::vector<TrackTemplate*> getTemplatesByCategory(const juce::String& category) {
        std::vector<TrackTemplate*> result;
        for (auto& pair : templates_) {
            if (pair.second->getCategory() == category) {
                result.push_back(pair.second.get());
            }
        }
        return result;
    }

    /** Get templates by type */
    std::vector<TrackTemplate*> getTemplatesByType(TrackType type) {
        std::vector<TrackTemplate*> result;
        for (auto& pair : templates_) {
            if (pair.second->getType() == type) {
                result.push_back(pair.second.get());
            }
        }
        return result;
    }

    /** Get all categories */
    std::vector<juce::String> getAllCategories() {
        std::set<juce::String> categories;
        for (auto& pair : templates_) {
            categories.insert(pair.second->getCategory());
        }
        return std::vector<juce::String>(categories.begin(), categories.end());
    }

    //==============================================================================
    /** Duplicate template */
    TrackTemplate* duplicateTemplate(const juce::String& id) {
        auto* source = getTemplate(id);
        if (!source) return nullptr;

        auto duplicate = TrackTemplate::fromVar(source->toVar());
        duplicate->setName(source->getName() + " Copy");

        TrackTemplate* ptr = duplicate.get();
        templates_[duplicate->getId()] = std::move(duplicate);
        return ptr;
    }

    //==============================================================================
    /** Save templates to file */
    bool saveToFile(const juce::File& file) {
        juce::var templatesArray;
        for (auto& pair : templates_) {
            templatesArray.append(pair.second->toVar());
        }

        auto obj = new juce::DynamicObject();
        obj->setProperty("version", 1);
        obj->setProperty("templates", templatesArray);

        juce::FileOutputStream stream(file);
        if (stream.openedOk()) {
            juce::JSON::writeToStream(stream, juce::var(obj));
            return true;
        }
        return false;
    }

    /** Load templates from file */
    bool loadFromFile(const juce::File& file) {
        if (!file.existsAsFile()) return false;

        juce::var data = juce::JSON::parse(file);
        if (!data.isObject()) return false;

        auto* obj = data.getDynamicObject();
        if (!obj) return false;

        if (auto* templatesArray = obj->getProperty("templates").getArray()) {
            for (const auto& t : *templatesArray) {
                auto tmpl = TrackTemplate::fromVar(t);
                if (tmpl) {
                    templates_[tmpl->getId()] = std::move(tmpl);
                }
            }
        }

        return true;
    }

    //==============================================================================
    /** Get default template directory */
    static juce::File getDefaultTemplateDirectory() {
        return juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory)
            .getChildFile("Echoelmusic/TrackTemplates");
    }

private:
    void createBuiltInTemplates() {
        // Vocal Recording
        {
            auto tmpl = std::make_unique<TrackTemplate>("Vocal Recording");
            tmpl->setType(TrackType::Audio);
            tmpl->setCategory("Recording");
            tmpl->setDescription("Optimized for vocal recording with compression and EQ");
            tmpl->setColour(juce::Colours::crimson);
            tmpl->setRecordEnabled(true);
            tmpl->setMonitorEnabled(true);

            TemplatePluginSlot comp;
            comp.pluginName = "Compressor";
            comp.slotIndex = 0;
            tmpl->addPlugin(comp);

            TemplatePluginSlot eq;
            eq.pluginName = "EQ";
            eq.slotIndex = 1;
            tmpl->addPlugin(eq);

            TemplateSend reverbSend;
            reverbSend.destinationName = "Reverb Bus";
            reverbSend.level = 0.3f;
            tmpl->addSend(reverbSend);

            templates_[tmpl->getId()] = std::move(tmpl);
        }

        // Guitar DI
        {
            auto tmpl = std::make_unique<TrackTemplate>("Guitar DI");
            tmpl->setType(TrackType::Audio);
            tmpl->setCategory("Recording");
            tmpl->setDescription("Direct input guitar with amp simulation");
            tmpl->setColour(juce::Colours::orange);
            tmpl->setRecordEnabled(true);

            TemplatePluginSlot amp;
            amp.pluginName = "Amp Simulator";
            amp.slotIndex = 0;
            tmpl->addPlugin(amp);

            templates_[tmpl->getId()] = std::move(tmpl);
        }

        // Drum Bus
        {
            auto tmpl = std::make_unique<TrackTemplate>("Drum Bus");
            tmpl->setType(TrackType::Bus);
            tmpl->setCategory("Mixing");
            tmpl->setDescription("Drum submix with parallel compression");
            tmpl->setColour(juce::Colours::yellow);

            TemplatePluginSlot comp;
            comp.pluginName = "Drum Compressor";
            comp.slotIndex = 0;
            tmpl->addPlugin(comp);

            TemplatePluginSlot saturator;
            saturator.pluginName = "Saturator";
            saturator.slotIndex = 1;
            tmpl->addPlugin(saturator);

            templates_[tmpl->getId()] = std::move(tmpl);
        }

        // Reverb Return
        {
            auto tmpl = std::make_unique<TrackTemplate>("Reverb Return");
            tmpl->setType(TrackType::Aux);
            tmpl->setCategory("Effects");
            tmpl->setDescription("Reverb effect return track");
            tmpl->setColour(juce::Colours::cyan);

            TemplatePluginSlot reverb;
            reverb.pluginName = "Reverb";
            reverb.slotIndex = 0;
            tmpl->addPlugin(reverb);

            templates_[tmpl->getId()] = std::move(tmpl);
        }

        // Delay Return
        {
            auto tmpl = std::make_unique<TrackTemplate>("Delay Return");
            tmpl->setType(TrackType::Aux);
            tmpl->setCategory("Effects");
            tmpl->setDescription("Delay effect return track");
            tmpl->setColour(juce::Colours::purple);

            TemplatePluginSlot delay;
            delay.pluginName = "Delay";
            delay.slotIndex = 0;
            tmpl->addPlugin(delay);

            templates_[tmpl->getId()] = std::move(tmpl);
        }

        // Synth Lead
        {
            auto tmpl = std::make_unique<TrackTemplate>("Synth Lead");
            tmpl->setType(TrackType::Instrument);
            tmpl->setCategory("Production");
            tmpl->setDescription("Synth track with processing chain");
            tmpl->setColour(juce::Colours::magenta);

            TemplatePluginSlot synth;
            synth.pluginName = "Synthesizer";
            synth.slotIndex = 0;
            tmpl->addPlugin(synth);

            TemplatePluginSlot filter;
            filter.pluginName = "Filter";
            filter.slotIndex = 1;
            tmpl->addPlugin(filter);

            templates_[tmpl->getId()] = std::move(tmpl);
        }

        // Podcast Mono
        {
            auto tmpl = std::make_unique<TrackTemplate>("Podcast Voice");
            tmpl->setType(TrackType::Audio);
            tmpl->setCategory("Podcast");
            tmpl->setDescription("Optimized for speech recording");
            tmpl->setColour(juce::Colours::teal);

            TemplateIO io;
            io.numInputChannels = 1;
            io.numOutputChannels = 1;
            tmpl->getIO() = io;

            TemplatePluginSlot gate;
            gate.pluginName = "Noise Gate";
            gate.slotIndex = 0;
            tmpl->addPlugin(gate);

            TemplatePluginSlot deEsser;
            deEsser.pluginName = "De-Esser";
            deEsser.slotIndex = 1;
            tmpl->addPlugin(deEsser);

            TemplatePluginSlot comp;
            comp.pluginName = "Compressor";
            comp.slotIndex = 2;
            tmpl->addPlugin(comp);

            templates_[tmpl->getId()] = std::move(tmpl);
        }
    }

    std::map<juce::String, std::unique_ptr<TrackTemplate>> templates_;
};

} // namespace Project
} // namespace Echoelmusic
