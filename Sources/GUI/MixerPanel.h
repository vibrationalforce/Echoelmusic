/*
  ==============================================================================

    MixerPanel.h
    Channel Strip Mixer

    Vertical channel strips with faders, meters, and routing.

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>

namespace Echoelmusic {
namespace GUI {

//==============================================================================
// Level Meter
//==============================================================================

class LevelMeter : public juce::Component,
                   public juce::Timer
{
public:
    LevelMeter()
    {
        startTimerHz(30);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(1);

        // Background
        g.setColour(juce::Colour(0xFF1A1A24));
        g.fillRoundedRectangle(bounds, 3.0f);

        // Level segments
        int numSegments = 20;
        float segmentHeight = bounds.getHeight() / numSegments;
        float segmentGap = 1.0f;

        int litSegments = static_cast<int>(displayLevel * numSegments);

        for (int i = 0; i < numSegments; ++i)
        {
            float y = bounds.getBottom() - (i + 1) * segmentHeight + segmentGap / 2;

            juce::Colour segColor;
            if (i >= numSegments - 2)
                segColor = juce::Colour(0xFFFF4444);  // Red (clip)
            else if (i >= numSegments - 6)
                segColor = juce::Colour(0xFFFBBF24);  // Yellow (hot)
            else
                segColor = juce::Colour(0xFF4ADE80);  // Green (normal)

            if (i < litSegments)
                g.setColour(segColor);
            else
                g.setColour(segColor.withAlpha(0.15f));

            g.fillRect(bounds.getX() + 1, y,
                      bounds.getWidth() - 2, segmentHeight - segmentGap);
        }

        // Peak hold
        if (peakHold > 0.1f)
        {
            int peakSegment = static_cast<int>(peakHold * numSegments);
            float peakY = bounds.getBottom() - peakSegment * segmentHeight;
            g.setColour(juce::Colours::white);
            g.fillRect(bounds.getX() + 1, peakY - 2, bounds.getWidth() - 2, 2.0f);
        }
    }

    void timerCallback() override
    {
        // Animate level smoothly
        displayLevel += (targetLevel - displayLevel) * 0.3f;

        // Peak decay
        if (peakHold > displayLevel)
            peakHold -= 0.01f;

        repaint();
    }

    void setLevel(float level)
    {
        targetLevel = juce::jlimit(0.0f, 1.0f, level);
        if (targetLevel > peakHold)
            peakHold = targetLevel;
    }

private:
    float targetLevel = 0.0f;
    float displayLevel = 0.0f;
    float peakHold = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(LevelMeter)
};

//==============================================================================
// Pan Knob
//==============================================================================

class PanKnob : public juce::Component
{
public:
    PanKnob()
    {
        setWantsKeyboardFocus(true);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(4);
        auto centre = bounds.getCentre();
        float radius = std::min(bounds.getWidth(), bounds.getHeight()) / 2.0f - 2.0f;

        // Outer ring
        g.setColour(juce::Colour(0xFF3A3A4A));
        g.drawEllipse(centre.x - radius, centre.y - radius, radius * 2, radius * 2, 2.0f);

        // Value indicator
        float angle = (panValue - 0.5f) * juce::MathConstants<float>::pi * 0.8f;
        float indicatorRadius = radius - 4;

        float endX = centre.x + std::sin(angle) * indicatorRadius;
        float endY = centre.y - std::cos(angle) * indicatorRadius;

        g.setColour(juce::Colour(0xFF00D9FF));
        g.drawLine(centre.x, centre.y, endX, endY, 2.0f);

        // Center dot
        g.fillEllipse(centre.x - 3, centre.y - 3, 6, 6);

        // L/R labels
        g.setColour(juce::Colour(0xFF6B6B7B));
        g.setFont(juce::Font(9.0f));
        g.drawText("L", bounds.withWidth(15), juce::Justification::centred);
        g.drawText("R", bounds.withX(bounds.getRight() - 15).withWidth(15), juce::Justification::centred);
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        dragStartY = e.y;
        dragStartValue = panValue;
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        float delta = (dragStartY - e.y) / 100.0f;
        panValue = juce::jlimit(0.0f, 1.0f, dragStartValue + delta);
        repaint();
    }

    void mouseDoubleClick(const juce::MouseEvent&) override
    {
        panValue = 0.5f;  // Reset to center
        repaint();
    }

    float getValue() const { return panValue; }
    void setValue(float v) { panValue = juce::jlimit(0.0f, 1.0f, v); repaint(); }

private:
    float panValue = 0.5f;
    int dragStartY = 0;
    float dragStartValue = 0.5f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PanKnob)
};

//==============================================================================
// Channel Strip
//==============================================================================

class ChannelStrip : public juce::Component,
                     public juce::Timer
{
public:
    ChannelStrip(int index, const juce::String& name, juce::Colour color)
        : channelIndex(index), channelName(name), channelColor(color)
    {
        // Name label
        nameLabel.setText(name, juce::dontSendNotification);
        nameLabel.setFont(juce::Font(11.0f, juce::Font::bold));
        nameLabel.setColour(juce::Label::textColourId, juce::Colours::white);
        nameLabel.setJustificationType(juce::Justification::centred);
        addAndMakeVisible(nameLabel);

        // Pan knob
        addAndMakeVisible(panKnob);

        // Level meter
        addAndMakeVisible(levelMeter);

        // Fader
        fader.setSliderStyle(juce::Slider::LinearVertical);
        fader.setTextBoxStyle(juce::Slider::NoTextBox, false, 0, 0);
        fader.setRange(-60.0, 6.0, 0.1);
        fader.setValue(0.0);
        fader.setColour(juce::Slider::thumbColourId, channelColor);
        fader.setColour(juce::Slider::trackColourId, juce::Colour(0xFF3A3A4A));
        addAndMakeVisible(fader);

        // dB label
        dbLabel.setText("0.0", juce::dontSendNotification);
        dbLabel.setFont(juce::Font(10.0f));
        dbLabel.setColour(juce::Label::textColourId, juce::Colour(0xFFB8B8C8));
        dbLabel.setJustificationType(juce::Justification::centred);
        addAndMakeVisible(dbLabel);

        // Mute/Solo buttons
        muteButton.setButtonText("M");
        muteButton.setClickingTogglesState(true);
        muteButton.setColour(juce::TextButton::buttonOnColourId, juce::Colour(0xFFFF6B6B));
        addAndMakeVisible(muteButton);

        soloButton.setButtonText("S");
        soloButton.setClickingTogglesState(true);
        soloButton.setColour(juce::TextButton::buttonOnColourId, juce::Colour(0xFFFBBF24));
        addAndMakeVisible(soloButton);

        startTimer(50);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.setColour(juce::Colour(0xFF1A1A24));
        g.fillRect(bounds);

        // Color strip at top
        g.setColour(channelColor);
        g.fillRect(bounds.getX(), bounds.getY(), bounds.getWidth(), 3.0f);

        // Right border
        g.setColour(juce::Colour(0xFF2A2A3A));
        g.drawLine(bounds.getRight(), 0, bounds.getRight(), bounds.getHeight(), 1.0f);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(5);
        bounds.removeFromTop(5);

        // Name at top
        nameLabel.setBounds(bounds.removeFromTop(20));
        bounds.removeFromTop(5);

        // Mute/Solo buttons
        auto buttonRow = bounds.removeFromTop(24);
        muteButton.setBounds(buttonRow.removeFromLeft(buttonRow.getWidth() / 2 - 2));
        buttonRow.removeFromLeft(4);
        soloButton.setBounds(buttonRow);
        bounds.removeFromTop(5);

        // Pan knob
        panKnob.setBounds(bounds.removeFromTop(40));
        bounds.removeFromTop(5);

        // dB label at bottom
        dbLabel.setBounds(bounds.removeFromBottom(20));
        bounds.removeFromBottom(5);

        // Fader and meter side by side
        auto faderArea = bounds;
        levelMeter.setBounds(faderArea.removeFromRight(12));
        faderArea.removeFromRight(5);
        fader.setBounds(faderArea);
    }

    void timerCallback() override
    {
        // Simulate meter activity
        float level = 0.3f + 0.5f * std::abs(std::sin(
            juce::Time::getMillisecondCounterHiRes() * 0.001f + channelIndex * 0.5f));
        levelMeter.setLevel(level);

        // Update dB label
        double db = fader.getValue();
        dbLabel.setText(juce::String(db, 1) + " dB", juce::dontSendNotification);
    }

private:
    int channelIndex;
    juce::String channelName;
    juce::Colour channelColor;

    juce::Label nameLabel;
    PanKnob panKnob;
    LevelMeter levelMeter;
    juce::Slider fader;
    juce::Label dbLabel;
    juce::TextButton muteButton;
    juce::TextButton soloButton;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ChannelStrip)
};

//==============================================================================
// Mixer Panel
//==============================================================================

class MixerPanel : public juce::Component
{
public:
    MixerPanel()
    {
        // Title
        titleLabel.setText("MIXER", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(11.0f, juce::Font::bold));
        titleLabel.setColour(juce::Label::textColourId, juce::Colour(0xFF6B6B7B));
        addAndMakeVisible(titleLabel);

        // Create channel strips
        createChannels();
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xFF121218));

        // Left border
        g.setColour(juce::Colour(0xFF2A2A3A));
        g.drawLine(0, 0, 0, static_cast<float>(getHeight()), 1.0f);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(5);

        // Title
        titleLabel.setBounds(bounds.removeFromTop(20));
        bounds.removeFromTop(5);

        // Channel strips
        int stripWidth = bounds.getWidth() / static_cast<int>(channels.size());

        for (auto& channel : channels)
        {
            channel->setBounds(bounds.removeFromLeft(stripWidth));
        }
    }

private:
    void createChannels()
    {
        struct ChannelInfo {
            juce::String name;
            juce::Colour color;
        };

        std::vector<ChannelInfo> channelDefs = {
            {"Drums", juce::Colour(0xFFFF6B9D)},
            {"Bass", juce::Colour(0xFF00D9FF)},
            {"Synth", juce::Colour(0xFFFBBF24)},
            {"Vox", juce::Colour(0xFF4ADE80)},
            {"Mstr", juce::Colour(0xFFA78BFA)}
        };

        for (size_t i = 0; i < channelDefs.size(); ++i)
        {
            auto& info = channelDefs[i];
            auto strip = std::make_unique<ChannelStrip>(
                static_cast<int>(i), info.name, info.color);
            addAndMakeVisible(strip.get());
            channels.push_back(std::move(strip));
        }
    }

    juce::Label titleLabel;
    std::vector<std::unique_ptr<ChannelStrip>> channels;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MixerPanel)
};

} // namespace GUI
} // namespace Echoelmusic
