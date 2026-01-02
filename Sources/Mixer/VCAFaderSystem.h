/*
  ==============================================================================

    VCAFaderSystem.h
    Created: 2026
    Author:  Echoelmusic

    VCA (Voltage Controlled Amplifier) Fader System
    For grouping and controlling multiple track volumes together

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <map>
#include <set>
#include <functional>

namespace Echoelmusic {
namespace Mixer {

//==============================================================================
/** VCA assignment mode */
enum class VCAMode {
    Trim,       // VCA adds to track fader (relative)
    Absolute,   // VCA overrides track fader
    Multiply    // VCA multiplies track fader
};

//==============================================================================
/** Slave track info for VCA control */
struct VCASlave {
    juce::String trackId;
    float originalFaderPosition = 1.0f;  // Before VCA control
    bool isLinked = true;

    // Automation
    bool automationEnabled = false;
    float automationValue = 1.0f;
};

//==============================================================================
/** VCA Fader Master */
class VCAFader {
public:
    VCAFader(const juce::String& name)
        : name_(name)
    {
        id_ = juce::Uuid().toString();
    }

    //==============================================================================
    juce::String getId() const { return id_; }
    juce::String getName() const { return name_; }
    void setName(const juce::String& name) { name_ = name; }

    //==============================================================================
    /** Set VCA fader level (0.0 - 1.0, where 1.0 = unity/0dB) */
    void setLevel(float level) {
        level_ = juce::jlimit(0.0f, 2.0f, level); // Allow +6dB boost
        updateSlaves();
    }

    float getLevel() const { return level_; }

    /** Set level in decibels */
    void setLevelDB(float db) {
        setLevel(juce::Decibels::decibelsToGain(db));
    }

    float getLevelDB() const {
        return juce::Decibels::gainToDecibels(level_);
    }

    //==============================================================================
    /** Mute the VCA */
    void setMuted(bool muted) {
        muted_ = muted;
        updateSlaves();
    }

    bool isMuted() const { return muted_; }

    /** Solo the VCA */
    void setSolo(bool solo) {
        solo_ = solo;
    }

    bool isSolo() const { return solo_; }

    //==============================================================================
    /** Set VCA mode */
    void setMode(VCAMode mode) {
        mode_ = mode;
        updateSlaves();
    }

    VCAMode getMode() const { return mode_; }

    //==============================================================================
    /** Add slave track */
    void addSlave(const juce::String& trackId) {
        if (slaves_.find(trackId) == slaves_.end()) {
            VCASlave slave;
            slave.trackId = trackId;
            slave.originalFaderPosition = 1.0f;
            slaves_[trackId] = slave;

            if (onSlaveAdded) onSlaveAdded(trackId);
        }
    }

    /** Remove slave track */
    void removeSlave(const juce::String& trackId) {
        auto it = slaves_.find(trackId);
        if (it != slaves_.end()) {
            slaves_.erase(it);
            if (onSlaveRemoved) onSlaveRemoved(trackId);
        }
    }

    /** Check if track is a slave */
    bool hasSlave(const juce::String& trackId) const {
        return slaves_.find(trackId) != slaves_.end();
    }

    /** Get all slave track IDs */
    std::vector<juce::String> getSlaveIds() const {
        std::vector<juce::String> ids;
        for (const auto& pair : slaves_) {
            ids.push_back(pair.first);
        }
        return ids;
    }

    /** Get slave info */
    VCASlave* getSlave(const juce::String& trackId) {
        auto it = slaves_.find(trackId);
        return it != slaves_.end() ? &it->second : nullptr;
    }

    //==============================================================================
    /** Calculate effective gain for a slave track */
    float calculateSlaveGain(const juce::String& trackId, float trackFaderLevel) const {
        auto it = slaves_.find(trackId);
        if (it == slaves_.end() || !it->second.isLinked) {
            return trackFaderLevel;
        }

        if (muted_) return 0.0f;

        switch (mode_) {
            case VCAMode::Trim:
                return trackFaderLevel * level_;

            case VCAMode::Absolute:
                return level_;

            case VCAMode::Multiply:
                return trackFaderLevel * level_;

            default:
                return trackFaderLevel;
        }
    }

    //==============================================================================
    /** Store original fader positions for relative movements */
    void captureSlavePositions(std::function<float(const juce::String&)> getFaderLevel) {
        for (auto& pair : slaves_) {
            pair.second.originalFaderPosition = getFaderLevel(pair.first);
        }
    }

    //==============================================================================
    /** Set color for UI */
    void setColour(juce::Colour colour) { colour_ = colour; }
    juce::Colour getColour() const { return colour_; }

    //==============================================================================
    // Callbacks
    std::function<void()> onLevelChanged;
    std::function<void(const juce::String&)> onSlaveAdded;
    std::function<void(const juce::String&)> onSlaveRemoved;

private:
    void updateSlaves() {
        if (onLevelChanged) onLevelChanged();
    }

    juce::String id_;
    juce::String name_;
    float level_ = 1.0f;
    bool muted_ = false;
    bool solo_ = false;
    VCAMode mode_ = VCAMode::Trim;
    juce::Colour colour_ = juce::Colours::blue;

    std::map<juce::String, VCASlave> slaves_;
};

//==============================================================================
/** VCA Group - collection of related VCAs */
struct VCAGroup {
    juce::String id;
    juce::String name;
    std::vector<juce::String> vcaIds;
    juce::Colour colour = juce::Colours::purple;
    bool isExpanded = true;

    VCAGroup() {
        id = juce::Uuid().toString();
    }
};

//==============================================================================
/** VCA Fader Manager */
class VCAFaderManager {
public:
    VCAFaderManager() = default;

    //==============================================================================
    /** Create new VCA fader */
    VCAFader* createVCA(const juce::String& name) {
        auto vca = std::make_unique<VCAFader>(name);
        VCAFader* ptr = vca.get();
        vcaFaders_[vca->getId()] = std::move(vca);

        // Wire up callbacks
        ptr->onLevelChanged = [this, ptr]() {
            if (onVCALevelChanged) onVCALevelChanged(ptr);
        };

        if (onVCACreated) onVCACreated(ptr);
        return ptr;
    }

    /** Remove VCA fader */
    void removeVCA(const juce::String& id) {
        auto it = vcaFaders_.find(id);
        if (it != vcaFaders_.end()) {
            if (onVCARemoved) onVCARemoved(id);
            vcaFaders_.erase(it);
        }
    }

    /** Get VCA by ID */
    VCAFader* getVCA(const juce::String& id) {
        auto it = vcaFaders_.find(id);
        return it != vcaFaders_.end() ? it->second.get() : nullptr;
    }

    /** Get all VCAs */
    std::vector<VCAFader*> getAllVCAs() {
        std::vector<VCAFader*> result;
        for (auto& pair : vcaFaders_) {
            result.push_back(pair.second.get());
        }
        return result;
    }

    //==============================================================================
    /** Assign track to VCA */
    void assignTrackToVCA(const juce::String& trackId, const juce::String& vcaId) {
        if (auto* vca = getVCA(vcaId)) {
            // Remove from any existing VCA
            for (auto& pair : vcaFaders_) {
                if (pair.second->hasSlave(trackId)) {
                    pair.second->removeSlave(trackId);
                }
            }

            vca->addSlave(trackId);
        }
    }

    /** Remove track from all VCAs */
    void removeTrackFromAllVCAs(const juce::String& trackId) {
        for (auto& pair : vcaFaders_) {
            pair.second->removeSlave(trackId);
        }
    }

    /** Get VCA controlling a track */
    VCAFader* getVCAForTrack(const juce::String& trackId) {
        for (auto& pair : vcaFaders_) {
            if (pair.second->hasSlave(trackId)) {
                return pair.second.get();
            }
        }
        return nullptr;
    }

    //==============================================================================
    /** Calculate effective fader level for track */
    float getEffectiveTrackLevel(const juce::String& trackId, float trackFaderLevel) const {
        for (const auto& pair : vcaFaders_) {
            if (pair.second->hasSlave(trackId)) {
                return pair.second->calculateSlaveGain(trackId, trackFaderLevel);
            }
        }
        return trackFaderLevel;
    }

    //==============================================================================
    /** Create VCA group */
    VCAGroup* createGroup(const juce::String& name) {
        auto group = std::make_unique<VCAGroup>();
        group->name = name;
        VCAGroup* ptr = group.get();
        vcaGroups_[group->id] = std::move(group);
        return ptr;
    }

    /** Add VCA to group */
    void addVCAToGroup(const juce::String& vcaId, const juce::String& groupId) {
        auto it = vcaGroups_.find(groupId);
        if (it != vcaGroups_.end()) {
            auto& ids = it->second->vcaIds;
            if (std::find(ids.begin(), ids.end(), vcaId) == ids.end()) {
                ids.push_back(vcaId);
            }
        }
    }

    /** Get all groups */
    std::vector<VCAGroup*> getAllGroups() {
        std::vector<VCAGroup*> result;
        for (auto& pair : vcaGroups_) {
            result.push_back(pair.second.get());
        }
        return result;
    }

    //==============================================================================
    /** Handle solo mode - exclusive solo */
    void handleSoloChange(VCAFader* changedVCA) {
        if (!changedVCA->isSolo()) return;

        if (soloExclusive_) {
            for (auto& pair : vcaFaders_) {
                if (pair.second.get() != changedVCA) {
                    pair.second->setSolo(false);
                }
            }
        }

        soloActive_ = true;
        updateSoloState();
    }

    void clearAllSolos() {
        for (auto& pair : vcaFaders_) {
            pair.second->setSolo(false);
        }
        soloActive_ = false;
        updateSoloState();
    }

    bool isSoloActive() const { return soloActive_; }

    void setSoloExclusive(bool exclusive) { soloExclusive_ = exclusive; }

    //==============================================================================
    // Callbacks
    std::function<void(VCAFader*)> onVCACreated;
    std::function<void(const juce::String&)> onVCARemoved;
    std::function<void(VCAFader*)> onVCALevelChanged;
    std::function<void()> onSoloStateChanged;

private:
    void updateSoloState() {
        soloActive_ = false;
        for (const auto& pair : vcaFaders_) {
            if (pair.second->isSolo()) {
                soloActive_ = true;
                break;
            }
        }
        if (onSoloStateChanged) onSoloStateChanged();
    }

    std::map<juce::String, std::unique_ptr<VCAFader>> vcaFaders_;
    std::map<juce::String, std::unique_ptr<VCAGroup>> vcaGroups_;
    bool soloActive_ = false;
    bool soloExclusive_ = true;
};

//==============================================================================
/** VCA Fader UI Component */
class VCAFaderComponent : public juce::Component {
public:
    VCAFaderComponent(VCAFader& vca)
        : vca_(vca)
    {
        // Fader slider
        faderSlider_.setSliderStyle(juce::Slider::LinearVertical);
        faderSlider_.setRange(0.0, 2.0, 0.01);
        faderSlider_.setValue(1.0);
        faderSlider_.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 50, 20);
        faderSlider_.onValueChange = [this]() {
            vca_.setLevel(static_cast<float>(faderSlider_.getValue()));
        };
        addAndMakeVisible(faderSlider_);

        // Mute button
        muteButton_.setButtonText("M");
        muteButton_.setClickingTogglesState(true);
        muteButton_.onClick = [this]() {
            vca_.setMuted(muteButton_.getToggleState());
        };
        addAndMakeVisible(muteButton_);

        // Solo button
        soloButton_.setButtonText("S");
        soloButton_.setClickingTogglesState(true);
        soloButton_.onClick = [this]() {
            vca_.setSolo(soloButton_.getToggleState());
        };
        addAndMakeVisible(soloButton_);

        // Name label
        nameLabel_.setText(vca.getName(), juce::dontSendNotification);
        nameLabel_.setJustificationType(juce::Justification::centred);
        addAndMakeVisible(nameLabel_);

        setSize(60, 300);
    }

    void resized() override {
        auto bounds = getLocalBounds();

        nameLabel_.setBounds(bounds.removeFromTop(20));
        muteButton_.setBounds(bounds.removeFromTop(25).reduced(5, 2));
        soloButton_.setBounds(bounds.removeFromTop(25).reduced(5, 2));
        faderSlider_.setBounds(bounds.reduced(5));
    }

    void paint(juce::Graphics& g) override {
        g.fillAll(vca_.getColour().withAlpha(0.2f));
        g.setColour(vca_.getColour());
        g.drawRect(getLocalBounds(), 2);
    }

    void updateFromVCA() {
        faderSlider_.setValue(vca_.getLevel(), juce::dontSendNotification);
        muteButton_.setToggleState(vca_.isMuted(), juce::dontSendNotification);
        soloButton_.setToggleState(vca_.isSolo(), juce::dontSendNotification);
        nameLabel_.setText(vca_.getName(), juce::dontSendNotification);
    }

private:
    VCAFader& vca_;
    juce::Slider faderSlider_;
    juce::TextButton muteButton_;
    juce::TextButton soloButton_;
    juce::Label nameLabel_;
};

} // namespace Mixer
} // namespace Echoelmusic
