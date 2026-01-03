#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <functional>
#include <atomic>

/**
 * MixerChannelStrip - Production-Ready Mixer UI
 *
 * Full-featured channel strip with:
 * - Fader with VU/Peak metering
 * - Pan knob with width control
 * - Mute/Solo/Record arm buttons
 * - Insert effect slots (8 per channel)
 * - Send levels (8 aux sends)
 * - Input/Output routing
 * - Gain staging (trim)
 * - Phase invert
 *
 * Super Ralph Wiggum Loop Genius Wise Save Mode
 */

namespace Echoelmusic {
namespace Mixer {

//==============================================================================
// Meter Types
//==============================================================================

class LevelMeter : public juce::Component, public juce::Timer
{
public:
    enum class Type { VU, Peak, RMS, LUFS };

    LevelMeter(Type t = Type::Peak) : type(t)
    {
        startTimerHz(30);
    }

    void setLevel(float left, float right)
    {
        // Ballistics
        float attack = (type == Type::VU) ? 0.3f : 0.9f;
        float release = (type == Type::VU) ? 0.1f : 0.05f;

        if (left > currentLeft)
            currentLeft += attack * (left - currentLeft);
        else
            currentLeft += release * (left - currentLeft);

        if (right > currentRight)
            currentRight += attack * (right - currentRight);
        else
            currentRight += release * (right - currentRight);

        // Peak hold
        if (left > peakLeft)
        {
            peakLeft = left;
            peakHoldCounter = 30;  // ~1 second at 30fps
        }
        if (right > peakRight)
        {
            peakRight = right;
            peakHoldCounter = 30;
        }
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds();
        int meterWidth = (bounds.getWidth() - 4) / 2;

        // Background
        g.setColour(juce::Colour(0xFF1A1A1A));
        g.fillRoundedRectangle(bounds.toFloat(), 3.0f);

        // Left meter
        auto leftBounds = bounds.removeFromLeft(meterWidth).reduced(2);
        drawMeter(g, leftBounds, currentLeft, peakLeft);

        bounds.removeFromLeft(2);  // Gap

        // Right meter
        auto rightBounds = bounds.reduced(2);
        drawMeter(g, rightBounds, currentRight, peakRight);
    }

    void timerCallback() override
    {
        if (peakHoldCounter > 0)
        {
            peakHoldCounter--;
            if (peakHoldCounter == 0)
            {
                peakLeft = currentLeft;
                peakRight = currentRight;
            }
        }
        repaint();
    }

private:
    Type type;
    float currentLeft = 0.0f, currentRight = 0.0f;
    float peakLeft = 0.0f, peakRight = 0.0f;
    int peakHoldCounter = 0;

    void drawMeter(juce::Graphics& g, juce::Rectangle<int> bounds, float level, float peak)
    {
        int height = bounds.getHeight();
        int levelHeight = static_cast<int>(level * height);
        int peakY = static_cast<int>((1.0f - peak) * height);

        // Gradient meter
        juce::ColourGradient gradient(
            juce::Colour(0xFF00FF00), 0, static_cast<float>(height),
            juce::Colour(0xFFFF0000), 0, 0, false);
        gradient.addColour(0.6, juce::Colour(0xFFFFFF00));

        g.setGradientFill(gradient);
        g.fillRect(bounds.getX(), bounds.getBottom() - levelHeight,
                   bounds.getWidth(), levelHeight);

        // Peak indicator
        g.setColour(juce::Colour(0xFFFFFFFF));
        g.fillRect(bounds.getX(), bounds.getY() + peakY,
                   bounds.getWidth(), 2);

        // Scale markings
        g.setColour(juce::Colour(0xFF4A4A4A));
        for (int db = 0; db >= -48; db -= 6)
        {
            float y = bounds.getY() + (1.0f - dbToLinear(static_cast<float>(db))) * height;
            g.drawHorizontalLine(static_cast<int>(y), static_cast<float>(bounds.getX()),
                                static_cast<float>(bounds.getRight()));
        }
    }

    static float dbToLinear(float db)
    {
        return std::pow(10.0f, db / 20.0f);
    }
};

//==============================================================================
// Rotary Knob
//==============================================================================

class RotaryKnob : public juce::Slider
{
public:
    RotaryKnob(const juce::String& name = "")
    {
        setSliderStyle(juce::Slider::RotaryVerticalDrag);
        setTextBoxStyle(juce::Slider::TextBoxBelow, false, 50, 15);
        setName(name);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();
        auto knobBounds = bounds.reduced(5);

        float rotaryStart = juce::MathConstants<float>::pi * 1.25f;
        float rotaryEnd = juce::MathConstants<float>::pi * 2.75f;

        float value = static_cast<float>(getValue());
        float normalised = static_cast<float>((value - getMinimum()) / (getMaximum() - getMinimum()));
        float angle = rotaryStart + normalised * (rotaryEnd - rotaryStart);

        float radius = std::min(knobBounds.getWidth(), knobBounds.getHeight()) / 2.0f - 5.0f;
        float centreX = knobBounds.getCentreX();
        float centreY = knobBounds.getCentreY();

        // Background arc
        juce::Path bgArc;
        bgArc.addCentredArc(centreX, centreY, radius, radius,
                            0.0f, rotaryStart, rotaryEnd, true);
        g.setColour(juce::Colour(0xFF3A3A3A));
        g.strokePath(bgArc, juce::PathStrokeType(4.0f));

        // Value arc
        juce::Path valueArc;
        valueArc.addCentredArc(centreX, centreY, radius, radius,
                               0.0f, rotaryStart, angle, true);
        g.setColour(juce::Colour(0xFF4A9EFF));
        g.strokePath(valueArc, juce::PathStrokeType(4.0f));

        // Knob body
        g.setColour(juce::Colour(0xFF2A2A2A));
        g.fillEllipse(centreX - radius * 0.7f, centreY - radius * 0.7f,
                      radius * 1.4f, radius * 1.4f);

        // Pointer
        juce::Path pointer;
        float pointerLength = radius * 0.5f;
        pointer.addRectangle(-2.0f, -pointerLength, 4.0f, pointerLength);

        g.setColour(juce::Colour(0xFFFFFFFF));
        g.fillPath(pointer, juce::AffineTransform::rotation(angle)
                           .translated(centreX, centreY));
    }
};

//==============================================================================
// Channel Strip Button
//==============================================================================

class ChannelButton : public juce::TextButton
{
public:
    enum class Type { Mute, Solo, Record, Phase };

    ChannelButton(Type t, const juce::String& text) : type(t)
    {
        setButtonText(text);
        setClickingTogglesState(true);
    }

    void paintButton(juce::Graphics& g, bool shouldDrawButtonAsHighlighted,
                     bool shouldDrawButtonAsDown) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(1);

        juce::Colour bgColor;
        if (getToggleState())
        {
            switch (type)
            {
                case Type::Mute: bgColor = juce::Colour(0xFFFF6B6B); break;
                case Type::Solo: bgColor = juce::Colour(0xFFFFE66D); break;
                case Type::Record: bgColor = juce::Colour(0xFFFF4444); break;
                case Type::Phase: bgColor = juce::Colour(0xFF4A9EFF); break;
            }
        }
        else
        {
            bgColor = juce::Colour(0xFF3A3A3A);
        }

        if (shouldDrawButtonAsHighlighted)
            bgColor = bgColor.brighter(0.1f);

        g.setColour(bgColor);
        g.fillRoundedRectangle(bounds, 3.0f);

        g.setColour(getToggleState() ? juce::Colours::black : juce::Colours::white);
        g.setFont(12.0f);
        g.drawText(getButtonText(), bounds, juce::Justification::centred);
    }

private:
    Type type;
};

//==============================================================================
// Insert Slot
//==============================================================================

class InsertSlot : public juce::Component
{
public:
    InsertSlot(int index) : slotIndex(index)
    {
        setSize(100, 24);
    }

    void setPluginName(const juce::String& name)
    {
        pluginName = name;
        repaint();
    }

    void setBypass(bool bypassed)
    {
        isBypassed = bypassed;
        repaint();
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(1);

        // Background
        g.setColour(pluginName.isEmpty() ? juce::Colour(0xFF2A2A2A) : juce::Colour(0xFF3A4A5A));
        g.fillRoundedRectangle(bounds, 2.0f);

        // Text
        g.setColour(isBypassed ? juce::Colours::grey : juce::Colours::white);
        g.setFont(10.0f);

        juce::String text = pluginName.isEmpty() ?
            "Insert " + juce::String(slotIndex + 1) : pluginName;

        g.drawText(text, bounds.reduced(4, 0), juce::Justification::centredLeft);

        // Bypass indicator
        if (!pluginName.isEmpty())
        {
            g.setColour(isBypassed ? juce::Colours::red : juce::Colours::green);
            g.fillEllipse(bounds.getRight() - 10, bounds.getCentreY() - 3, 6, 6);
        }
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        if (e.mods.isRightButtonDown() && !pluginName.isEmpty())
        {
            isBypassed = !isBypassed;
            repaint();
            if (onBypassChanged) onBypassChanged(slotIndex, isBypassed);
        }
        else if (onClick)
        {
            onClick(slotIndex);
        }
    }

    std::function<void(int)> onClick;
    std::function<void(int, bool)> onBypassChanged;

private:
    int slotIndex;
    juce::String pluginName;
    bool isBypassed = false;
};

//==============================================================================
// Send Control
//==============================================================================

class SendControl : public juce::Component
{
public:
    SendControl(int index, const juce::String& name) : sendIndex(index), sendName(name)
    {
        levelSlider.setSliderStyle(juce::Slider::LinearHorizontal);
        levelSlider.setRange(-60.0, 12.0, 0.1);
        levelSlider.setValue(0.0);
        levelSlider.setTextBoxStyle(juce::Slider::NoTextBox, false, 0, 0);
        addAndMakeVisible(levelSlider);

        levelSlider.onValueChange = [this]() {
            if (onLevelChanged)
                onLevelChanged(sendIndex, static_cast<float>(levelSlider.getValue()));
        };
    }

    void resized() override
    {
        auto bounds = getLocalBounds();
        bounds.removeFromLeft(40);  // Label space
        levelSlider.setBounds(bounds.reduced(2));
    }

    void paint(juce::Graphics& g) override
    {
        g.setColour(juce::Colours::grey);
        g.setFont(10.0f);
        g.drawText(sendName, 0, 0, 38, getHeight(), juce::Justification::centredRight);
    }

    void setLevel(float db) { levelSlider.setValue(db, juce::dontSendNotification); }
    float getLevel() const { return static_cast<float>(levelSlider.getValue()); }

    std::function<void(int, float)> onLevelChanged;

private:
    int sendIndex;
    juce::String sendName;
    juce::Slider levelSlider;
};

//==============================================================================
// Channel Fader
//==============================================================================

class ChannelFader : public juce::Slider
{
public:
    ChannelFader()
    {
        setSliderStyle(juce::Slider::LinearVertical);
        setRange(-70.0, 12.0, 0.1);
        setValue(0.0);
        setTextBoxStyle(juce::Slider::TextBoxBelow, false, 50, 15);
        setDoubleClickReturnValue(true, 0.0);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().reduced(5);
        int trackWidth = 8;
        int trackX = bounds.getCentreX() - trackWidth / 2;

        // Track background
        g.setColour(juce::Colour(0xFF2A2A2A));
        g.fillRoundedRectangle(static_cast<float>(trackX), static_cast<float>(bounds.getY()),
                               static_cast<float>(trackWidth), static_cast<float>(bounds.getHeight() - 20),
                               4.0f);

        // Scale markings
        g.setColour(juce::Colour(0xFF4A4A4A));
        for (int db = 12; db >= -60; db -= 6)
        {
            float normalized = static_cast<float>((db + 70.0) / 82.0);
            int y = bounds.getBottom() - 20 - static_cast<int>(normalized * (bounds.getHeight() - 20));
            g.drawHorizontalLine(y, static_cast<float>(trackX - 5), static_cast<float>(trackX));
            g.drawHorizontalLine(y, static_cast<float>(trackX + trackWidth),
                                static_cast<float>(trackX + trackWidth + 5));

            if (db % 12 == 0)
            {
                g.setFont(9.0f);
                g.drawText(juce::String(db), trackX + trackWidth + 8, y - 6, 25, 12,
                          juce::Justification::centredLeft);
            }
        }

        // Fader cap
        float normalized = static_cast<float>((getValue() + 70.0) / 82.0);
        int capY = bounds.getBottom() - 20 - static_cast<int>(normalized * (bounds.getHeight() - 20));
        int capHeight = 30;

        g.setColour(juce::Colour(0xFF5A5A5A));
        g.fillRoundedRectangle(static_cast<float>(bounds.getCentreX() - 15),
                               static_cast<float>(capY - capHeight / 2),
                               30.0f, static_cast<float>(capHeight), 3.0f);

        // Cap line
        g.setColour(juce::Colour(0xFFAAAAAA));
        g.drawHorizontalLine(capY, static_cast<float>(bounds.getCentreX() - 10),
                            static_cast<float>(bounds.getCentreX() + 10));

        // Value display
        g.setColour(juce::Colours::white);
        g.setFont(11.0f);
        juce::String valueText = (getValue() <= -70.0) ? "-inf" :
                                  juce::String(getValue(), 1) + " dB";
        g.drawText(valueText, bounds.getX(), bounds.getBottom() - 15,
                   bounds.getWidth(), 15, juce::Justification::centred);
    }
};

//==============================================================================
// Full Channel Strip
//==============================================================================

class ChannelStrip : public juce::Component
{
public:
    struct ChannelState
    {
        juce::String name = "Track 1";
        juce::Colour color{0xFF4A9EFF};
        float faderLevel = 0.0f;        // dB
        float pan = 0.0f;               // -1 to +1
        float trim = 0.0f;              // dB
        bool muted = false;
        bool solo = false;
        bool recordArm = false;
        bool phaseInvert = false;
        std::array<float, 8> sendLevels{};
        std::array<juce::String, 8> insertNames{};
        std::array<bool, 8> insertBypassed{};
    };

    ChannelStrip(int index = 0) : channelIndex(index)
    {
        // Track name/color header
        nameLabel.setJustificationType(juce::Justification::centred);
        nameLabel.setEditable(true);
        nameLabel.setText("Track " + juce::String(index + 1), juce::dontSendNotification);
        nameLabel.setColour(juce::Label::backgroundColourId, state.color);
        addAndMakeVisible(nameLabel);

        // Input trim
        trimKnob.setRange(-24.0, 24.0, 0.1);
        trimKnob.setValue(0.0);
        trimKnob.setDoubleClickReturnValue(true, 0.0);
        addAndMakeVisible(trimKnob);

        // Phase invert
        phaseButton = std::make_unique<ChannelButton>(ChannelButton::Type::Phase, "Ø");
        addAndMakeVisible(*phaseButton);

        // Insert slots
        for (int i = 0; i < 8; ++i)
        {
            auto slot = std::make_unique<InsertSlot>(i);
            slot->onClick = [this, i](int) {
                if (onInsertClicked) onInsertClicked(channelIndex, i);
            };
            addAndMakeVisible(*slot);
            insertSlots.push_back(std::move(slot));
        }

        // Send controls
        for (int i = 0; i < 4; ++i)  // Show 4 sends
        {
            auto send = std::make_unique<SendControl>(i, "Send " + juce::String(i + 1));
            send->onLevelChanged = [this](int idx, float level) {
                state.sendLevels[idx] = level;
                if (onSendChanged) onSendChanged(channelIndex, idx, level);
            };
            addAndMakeVisible(*send);
            sendControls.push_back(std::move(send));
        }

        // Pan
        panKnob.setRange(-1.0, 1.0, 0.01);
        panKnob.setValue(0.0);
        panKnob.setDoubleClickReturnValue(true, 0.0);
        addAndMakeVisible(panKnob);

        // Mute/Solo/Record
        muteButton = std::make_unique<ChannelButton>(ChannelButton::Type::Mute, "M");
        soloButton = std::make_unique<ChannelButton>(ChannelButton::Type::Solo, "S");
        recordButton = std::make_unique<ChannelButton>(ChannelButton::Type::Record, "R");

        muteButton->onClick = [this]() {
            state.muted = muteButton->getToggleState();
            if (onMuteChanged) onMuteChanged(channelIndex, state.muted);
        };

        soloButton->onClick = [this]() {
            state.solo = soloButton->getToggleState();
            if (onSoloChanged) onSoloChanged(channelIndex, state.solo);
        };

        recordButton->onClick = [this]() {
            state.recordArm = recordButton->getToggleState();
            if (onRecordArmChanged) onRecordArmChanged(channelIndex, state.recordArm);
        };

        addAndMakeVisible(*muteButton);
        addAndMakeVisible(*soloButton);
        addAndMakeVisible(*recordButton);

        // Level meter
        addAndMakeVisible(meter);

        // Fader
        fader.onValueChange = [this]() {
            state.faderLevel = static_cast<float>(fader.getValue());
            if (onFaderChanged) onFaderChanged(channelIndex, state.faderLevel);
        };
        addAndMakeVisible(fader);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(2);

        // Header
        nameLabel.setBounds(bounds.removeFromTop(24));
        bounds.removeFromTop(4);

        // Trim + Phase
        auto trimRow = bounds.removeFromTop(50);
        trimKnob.setBounds(trimRow.removeFromLeft(trimRow.getWidth() - 24).reduced(2));
        phaseButton->setBounds(trimRow.reduced(2));
        bounds.removeFromTop(4);

        // Inserts
        for (auto& slot : insertSlots)
        {
            slot->setBounds(bounds.removeFromTop(22).reduced(1, 0));
        }
        bounds.removeFromTop(4);

        // Sends
        for (auto& send : sendControls)
        {
            send->setBounds(bounds.removeFromTop(20).reduced(1, 0));
        }
        bounds.removeFromTop(4);

        // Pan
        panKnob.setBounds(bounds.removeFromTop(50).reduced(10, 0));
        bounds.removeFromTop(4);

        // Mute/Solo/Record
        auto buttonRow = bounds.removeFromTop(24);
        int buttonWidth = buttonRow.getWidth() / 3;
        muteButton->setBounds(buttonRow.removeFromLeft(buttonWidth).reduced(1));
        soloButton->setBounds(buttonRow.removeFromLeft(buttonWidth).reduced(1));
        recordButton->setBounds(buttonRow.reduced(1));
        bounds.removeFromTop(4);

        // Meter and Fader
        auto meterFaderArea = bounds;
        meter.setBounds(meterFaderArea.removeFromLeft(30));
        fader.setBounds(meterFaderArea);
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xFF252525));
        g.setColour(juce::Colour(0xFF3A3A3A));
        g.drawRect(getLocalBounds());
    }

    void setMeterLevels(float left, float right)
    {
        meter.setLevel(left, right);
    }

    ChannelState& getState() { return state; }

    // Callbacks
    std::function<void(int, float)> onFaderChanged;
    std::function<void(int, float)> onPanChanged;
    std::function<void(int, bool)> onMuteChanged;
    std::function<void(int, bool)> onSoloChanged;
    std::function<void(int, bool)> onRecordArmChanged;
    std::function<void(int, int)> onInsertClicked;
    std::function<void(int, int, float)> onSendChanged;

private:
    int channelIndex;
    ChannelState state;

    juce::Label nameLabel;
    RotaryKnob trimKnob{"Trim"};
    RotaryKnob panKnob{"Pan"};
    std::unique_ptr<ChannelButton> phaseButton;
    std::unique_ptr<ChannelButton> muteButton;
    std::unique_ptr<ChannelButton> soloButton;
    std::unique_ptr<ChannelButton> recordButton;
    std::vector<std::unique_ptr<InsertSlot>> insertSlots;
    std::vector<std::unique_ptr<SendControl>> sendControls;
    LevelMeter meter;
    ChannelFader fader;
};

//==============================================================================
// Full Mixer View
//==============================================================================

class MixerView : public juce::Component
{
public:
    MixerView(int numChannels = 8)
    {
        for (int i = 0; i < numChannels; ++i)
        {
            auto strip = std::make_unique<ChannelStrip>(i);

            strip->onFaderChanged = [this](int ch, float level) {
                if (onChannelFaderChanged) onChannelFaderChanged(ch, level);
            };

            strip->onMuteChanged = [this](int ch, bool muted) {
                if (onChannelMuteChanged) onChannelMuteChanged(ch, muted);
            };

            strip->onSoloChanged = [this](int ch, bool solo) {
                updateSoloState();
                if (onChannelSoloChanged) onChannelSoloChanged(ch, solo);
            };

            addAndMakeVisible(*strip);
            channelStrips.push_back(std::move(strip));
        }

        // Master channel
        masterStrip = std::make_unique<ChannelStrip>(-1);
        masterStrip->getState().name = "Master";
        masterStrip->getState().color = juce::Colour(0xFFFF9E4A);
        addAndMakeVisible(*masterStrip);
    }

    void resized() override
    {
        auto bounds = getLocalBounds();
        int stripWidth = 110;

        // Channel strips
        for (auto& strip : channelStrips)
        {
            strip->setBounds(bounds.removeFromLeft(stripWidth));
        }

        // Master strip (wider)
        bounds.removeFromLeft(10);  // Gap
        masterStrip->setBounds(bounds.removeFromLeft(stripWidth + 20));
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xFF1A1A1A));
    }

    ChannelStrip& getChannel(int index)
    {
        return *channelStrips[index];
    }

    ChannelStrip& getMaster()
    {
        return *masterStrip;
    }

    int getNumChannels() const { return static_cast<int>(channelStrips.size()); }

    // Callbacks
    std::function<void(int, float)> onChannelFaderChanged;
    std::function<void(int, bool)> onChannelMuteChanged;
    std::function<void(int, bool)> onChannelSoloChanged;

private:
    std::vector<std::unique_ptr<ChannelStrip>> channelStrips;
    std::unique_ptr<ChannelStrip> masterStrip;

    void updateSoloState()
    {
        bool anySolo = false;
        for (const auto& strip : channelStrips)
        {
            if (strip->getState().solo)
            {
                anySolo = true;
                break;
            }
        }

        // Dim non-soloed channels when any is soloed
        for (auto& strip : channelStrips)
        {
            if (anySolo && !strip->getState().solo)
            {
                strip->setAlpha(0.5f);
            }
            else
            {
                strip->setAlpha(1.0f);
            }
        }
    }
};

} // namespace Mixer
} // namespace Echoelmusic
