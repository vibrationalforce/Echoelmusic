// DMXFixtureLibrary.h - Professional DMX Fixture Profiles
// Common lighting fixtures with channel mappings
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>
#include <vector>
#include <map>

namespace Echoel {

// ==================== FIXTURE CHANNEL DEFINITIONS ====================

enum class ChannelFunction {
    Dimmer = 0,
    Red,
    Green,
    Blue,
    White,
    Amber,
    UV,
    Pan,
    PanFine,
    Tilt,
    TiltFine,
    ColorWheel,
    Gobo,
    GoboRotation,
    Prism,
    Focus,
    Zoom,
    Shutter,
    Strobe,
    Frost,
    Iris,
    Speed,
    Macro,
    Control,
    Unknown
};

struct ChannelDefinition {
    int channelOffset;  // 0-based offset from fixture start address
    ChannelFunction function;
    juce::String name;
    uint8_t defaultValue{0};
    uint8_t minValue{0};
    uint8_t maxValue{255};

    ChannelDefinition(int offset, ChannelFunction func, const juce::String& n, uint8_t def = 0)
        : channelOffset(offset), function(func), name(n), defaultValue(def) {}
};

// ==================== FIXTURE PROFILE ====================

class DMXFixtureProfile {
public:
    juce::String manufacturer;
    juce::String model;
    juce::String mode;  // e.g., "16-Channel", "RGBW", "Extended"
    int channelCount{1};
    std::vector<ChannelDefinition> channels;

    DMXFixtureProfile() = default;

    DMXFixtureProfile(const juce::String& mfr, const juce::String& mdl, const juce::String& m, int count)
        : manufacturer(mfr), model(mdl), mode(m), channelCount(count) {}

    void addChannel(int offset, ChannelFunction function, const juce::String& name, uint8_t defaultValue = 0) {
        channels.emplace_back(offset, function, name, defaultValue);
    }

    int getChannelOffset(ChannelFunction function) const {
        for (const auto& ch : channels) {
            if (ch.function == function)
                return ch.channelOffset;
        }
        return -1;  // Not found
    }

    juce::String getProfileName() const {
        return manufacturer + " " + model + " (" + mode + ")";
    }
};

// ==================== FIXTURE LIBRARY ====================

class DMXFixtureLibrary {
public:
    DMXFixtureLibrary() {
        loadBuiltInFixtures();
    }

    const std::vector<DMXFixtureProfile>& getAllProfiles() const {
        return profiles;
    }

    const DMXFixtureProfile* getProfile(const juce::String& manufacturer, const juce::String& model) const {
        for (const auto& profile : profiles) {
            if (profile.manufacturer == manufacturer && profile.model == model)
                return &profile;
        }
        return nullptr;
    }

    DMXFixtureProfile* getProfileByIndex(int index) {
        if (index >= 0 && index < static_cast<int>(profiles.size()))
            return &profiles[index];
        return nullptr;
    }

    juce::StringArray getManufacturers() const {
        juce::StringArray manufacturers;
        for (const auto& profile : profiles) {
            if (!manufacturers.contains(profile.manufacturer))
                manufacturers.add(profile.manufacturer);
        }
        return manufacturers;
    }

    juce::StringArray getModelsForManufacturer(const juce::String& manufacturer) const {
        juce::StringArray models;
        for (const auto& profile : profiles) {
            if (profile.manufacturer == manufacturer && !models.contains(profile.model))
                models.add(profile.model);
        }
        return models;
    }

private:
    std::vector<DMXFixtureProfile> profiles;

    void loadBuiltInFixtures() {
        // ========== RGBW PAR CANS ==========
        {
            DMXFixtureProfile parcan("Generic", "RGBW PAR", "4-Channel", 4);
            parcan.addChannel(0, ChannelFunction::Red, "Red", 0);
            parcan.addChannel(1, ChannelFunction::Green, "Green", 0);
            parcan.addChannel(2, ChannelFunction::Blue, "Blue", 0);
            parcan.addChannel(3, ChannelFunction::White, "White", 0);
            profiles.push_back(parcan);
        }

        {
            DMXFixtureProfile parcan7("Generic", "RGBAW PAR", "7-Channel", 7);
            parcan7.addChannel(0, ChannelFunction::Dimmer, "Dimmer", 255);
            parcan7.addChannel(1, ChannelFunction::Red, "Red", 0);
            parcan7.addChannel(2, ChannelFunction::Green, "Green", 0);
            parcan7.addChannel(3, ChannelFunction::Blue, "Blue", 0);
            parcan7.addChannel(4, ChannelFunction::Amber, "Amber", 0);
            parcan7.addChannel(5, ChannelFunction::White, "White", 0);
            parcan7.addChannel(6, ChannelFunction::Strobe, "Strobe", 0);
            profiles.push_back(parcan7);
        }

        // ========== MOVING HEADS ==========
        {
            DMXFixtureProfile movingHead("Generic", "Moving Head", "16-Channel", 16);
            movingHead.addChannel(0, ChannelFunction::Pan, "Pan", 128);
            movingHead.addChannel(1, ChannelFunction::PanFine, "Pan Fine", 0);
            movingHead.addChannel(2, ChannelFunction::Tilt, "Tilt", 128);
            movingHead.addChannel(3, ChannelFunction::TiltFine, "Tilt Fine", 0);
            movingHead.addChannel(4, ChannelFunction::Speed, "Pan/Tilt Speed", 0);
            movingHead.addChannel(5, ChannelFunction::Dimmer, "Dimmer", 255);
            movingHead.addChannel(6, ChannelFunction::Shutter, "Shutter/Strobe", 255);
            movingHead.addChannel(7, ChannelFunction::Red, "Red", 0);
            movingHead.addChannel(8, ChannelFunction::Green, "Green", 0);
            movingHead.addChannel(9, ChannelFunction::Blue, "Blue", 0);
            movingHead.addChannel(10, ChannelFunction::White, "White", 0);
            movingHead.addChannel(11, ChannelFunction::ColorWheel, "Color Wheel", 0);
            movingHead.addChannel(12, ChannelFunction::Gobo, "Gobo", 0);
            movingHead.addChannel(13, ChannelFunction::GoboRotation, "Gobo Rotation", 0);
            movingHead.addChannel(14, ChannelFunction::Prism, "Prism", 0);
            movingHead.addChannel(15, ChannelFunction::Control, "Control/Reset", 0);
            profiles.push_back(movingHead);
        }

        // ========== WASH LIGHTS ==========
        {
            DMXFixtureProfile wash("Generic", "LED Wash", "12-Channel", 12);
            wash.addChannel(0, ChannelFunction::Dimmer, "Master Dimmer", 255);
            wash.addChannel(1, ChannelFunction::Red, "Red", 0);
            wash.addChannel(2, ChannelFunction::Green, "Green", 0);
            wash.addChannel(3, ChannelFunction::Blue, "Blue", 0);
            wash.addChannel(4, ChannelFunction::White, "White", 0);
            wash.addChannel(5, ChannelFunction::Amber, "Amber", 0);
            wash.addChannel(6, ChannelFunction::UV, "UV", 0);
            wash.addChannel(7, ChannelFunction::Strobe, "Strobe", 0);
            wash.addChannel(8, ChannelFunction::Zoom, "Zoom", 128);
            wash.addChannel(9, ChannelFunction::Macro, "Color Macro", 0);
            wash.addChannel(10, ChannelFunction::Speed, "Macro Speed", 0);
            wash.addChannel(11, ChannelFunction::Control, "Control", 0);
            profiles.push_back(wash);
        }

        // ========== SCANNERS ==========
        {
            DMXFixtureProfile scanner("Generic", "Scanner", "8-Channel", 8);
            scanner.addChannel(0, ChannelFunction::Pan, "Pan", 128);
            scanner.addChannel(1, ChannelFunction::Tilt, "Tilt", 128);
            scanner.addChannel(2, ChannelFunction::ColorWheel, "Color", 0);
            scanner.addChannel(3, ChannelFunction::Gobo, "Gobo", 0);
            scanner.addChannel(4, ChannelFunction::Shutter, "Shutter", 255);
            scanner.addChannel(5, ChannelFunction::Dimmer, "Dimmer", 255);
            scanner.addChannel(6, ChannelFunction::GoboRotation, "Gobo Rotation", 0);
            scanner.addChannel(7, ChannelFunction::Prism, "Prism", 0);
            profiles.push_back(scanner);
        }

        // ========== STROBES ==========
        {
            DMXFixtureProfile strobe("Generic", "Atomic Strobe", "2-Channel", 2);
            strobe.addChannel(0, ChannelFunction::Dimmer, "Intensity", 0);
            strobe.addChannel(1, ChannelFunction::Strobe, "Strobe Rate", 0);
            profiles.push_back(strobe);
        }

        // ========== LASERS ==========
        {
            DMXFixtureProfile laser("Generic", "RGB Laser", "8-Channel", 8);
            laser.addChannel(0, ChannelFunction::Control, "Mode", 0);
            laser.addChannel(1, ChannelFunction::Macro, "Pattern", 0);
            laser.addChannel(2, ChannelFunction::Zoom, "Zoom", 128);
            laser.addChannel(3, ChannelFunction::GoboRotation, "Y-Axis Rolling", 0);
            laser.addChannel(4, ChannelFunction::Pan, "X-Axis Rolling", 0);
            laser.addChannel(5, ChannelFunction::Speed, "Rotation Speed", 0);
            laser.addChannel(6, ChannelFunction::Red, "Red", 255);
            laser.addChannel(7, ChannelFunction::Green, "Green", 255);
            profiles.push_back(laser);
        }
    }
};

} // namespace Echoel
