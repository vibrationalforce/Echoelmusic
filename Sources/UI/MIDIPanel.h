/**
 * MIDIPanel.h
 * Echoelmusic MIDI Control Panel
 *
 * UI component for MIDI settings, device selection, and MIDI Learn
 * Integrates with MIDIEngine and MPEVoiceManager
 *
 * Features:
 * - Device input/output selection
 * - MIDI Learn mode
 * - Active notes display
 * - MPE configuration
 * - Controller mapping
 *
 * Copyright (c) 2025 Echoelmusic
 */

#pragma once

#include <JuceHeader.h>
#include "../Desktop/MIDI/MIDIEngine.h"
#include "../Desktop/MIDI/MPEVoiceManager.h"

namespace Echoelmusic {

// ============================================================================
// Vaporwave Colors (matching MainWindow/MixerView)
// ============================================================================

namespace MIDIPanelColors {
    const juce::Colour Background      = juce::Colour(0xFF1a1a2e);
    const juce::Colour Panel           = juce::Colour(0xFF16213e);
    const juce::Colour PanelLight      = juce::Colour(0xFF1f3460);
    const juce::Colour Cyan            = juce::Colour(0xFF00fff5);
    const juce::Colour Magenta         = juce::Colour(0xFFff00ff);
    const juce::Colour Purple          = juce::Colour(0xFF9d4edd);
    const juce::Colour Pink            = juce::Colour(0xFFf72585);
    const juce::Colour TextPrimary     = juce::Colour(0xFFffffff);
    const juce::Colour TextSecondary   = juce::Colour(0xFFb0b0b0);
    const juce::Colour Active          = juce::Colour(0xFF00ff88);
    const juce::Colour Inactive        = juce::Colour(0xFF404040);
}

// ============================================================================
// MIDI Activity Indicator
// ============================================================================

class MIDIActivityIndicator : public juce::Component,
                              public juce::Timer {
public:
    MIDIActivityIndicator() {
        startTimerHz(30);
    }

    void paint(juce::Graphics& g) override {
        auto bounds = getLocalBounds().toFloat().reduced(2);

        // Draw LED
        float brightness = juce::jmap(activity, 0.0f, 1.0f, 0.2f, 1.0f);
        auto color = isInput ? MIDIPanelColors::Cyan : MIDIPanelColors::Magenta;

        g.setColour(color.withAlpha(brightness));
        g.fillEllipse(bounds);

        // Glow effect
        if (activity > 0.5f) {
            g.setColour(color.withAlpha(0.3f));
            g.fillEllipse(bounds.expanded(2));
        }
    }

    void trigger() {
        activity = 1.0f;
        repaint();
    }

    void timerCallback() override {
        if (activity > 0.0f) {
            activity *= 0.85f;  // Decay
            if (activity < 0.01f) activity = 0.0f;
            repaint();
        }
    }

    void setIsInput(bool input) { isInput = input; }

private:
    float activity = 0.0f;
    bool isInput = true;
};

// ============================================================================
// Active Notes Display
// ============================================================================

class ActiveNotesDisplay : public juce::Component {
public:
    void paint(juce::Graphics& g) override {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.setColour(MIDIPanelColors::Panel);
        g.fillRoundedRectangle(bounds, 4.0f);

        // Piano roll style display
        float keyWidth = bounds.getWidth() / 128.0f;

        for (int note = 0; note < 128; ++note) {
            bool isBlack = (note % 12 == 1 || note % 12 == 3 ||
                           note % 12 == 6 || note % 12 == 8 || note % 12 == 10);

            juce::Rectangle<float> keyRect(note * keyWidth, 0, keyWidth, bounds.getHeight());

            if (activeNotes.count(note) > 0) {
                // Active note - color based on velocity
                float vel = activeNotes.at(note) / 127.0f;
                auto color = MIDIPanelColors::Cyan.interpolatedWith(MIDIPanelColors::Magenta, vel);
                g.setColour(color);
                g.fillRect(keyRect);
            } else {
                // Inactive
                g.setColour(isBlack ? juce::Colours::black.withAlpha(0.3f)
                                   : juce::Colours::white.withAlpha(0.1f));
                g.fillRect(keyRect);
            }
        }

        // Border
        g.setColour(MIDIPanelColors::PanelLight);
        g.drawRoundedRectangle(bounds, 4.0f, 1.0f);
    }

    void setActiveNote(int note, int velocity) {
        if (velocity > 0) {
            activeNotes[note] = velocity;
        } else {
            activeNotes.erase(note);
        }
        repaint();
    }

    void clearAllNotes() {
        activeNotes.clear();
        repaint();
    }

private:
    std::unordered_map<int, int> activeNotes;
};

// ============================================================================
// MIDI Device Selector
// ============================================================================

class MIDIDeviceSelector : public juce::Component,
                           public juce::ComboBox::Listener {
public:
    MIDIDeviceSelector(const juce::String& label, bool isInput)
        : labelText(label), isInputDevice(isInput) {
        addAndMakeVisible(labelComponent);
        labelComponent.setText(label, juce::dontSendNotification);
        labelComponent.setColour(juce::Label::textColourId, MIDIPanelColors::TextSecondary);
        labelComponent.setFont(juce::Font(12.0f));

        addAndMakeVisible(deviceCombo);
        deviceCombo.addListener(this);
        deviceCombo.setColour(juce::ComboBox::backgroundColourId, MIDIPanelColors::Panel);
        deviceCombo.setColour(juce::ComboBox::textColourId, MIDIPanelColors::TextPrimary);
        deviceCombo.setColour(juce::ComboBox::arrowColourId, MIDIPanelColors::Cyan);

        addAndMakeVisible(activityIndicator);
        activityIndicator.setIsInput(isInput);

        refreshDevices();
    }

    void resized() override {
        auto bounds = getLocalBounds();

        labelComponent.setBounds(bounds.removeFromTop(18));

        auto row = bounds;
        activityIndicator.setBounds(row.removeFromRight(20).reduced(2));
        deviceCombo.setBounds(row.reduced(0, 2));
    }

    void refreshDevices() {
        deviceCombo.clear();
        deviceCombo.addItem("-- None --", 1);

        if (isInputDevice) {
            auto devices = juce::MidiInput::getAvailableDevices();
            for (int i = 0; i < devices.size(); ++i) {
                deviceCombo.addItem(devices[i].name, i + 2);
                deviceIdentifiers.add(devices[i].identifier);
            }
        } else {
            auto devices = juce::MidiOutput::getAvailableDevices();
            for (int i = 0; i < devices.size(); ++i) {
                deviceCombo.addItem(devices[i].name, i + 2);
                deviceIdentifiers.add(devices[i].identifier);
            }
        }

        deviceCombo.setSelectedId(1);
    }

    void comboBoxChanged(juce::ComboBox* combo) override {
        int selectedId = combo->getSelectedId();
        if (selectedId > 1 && onDeviceSelected) {
            int deviceIndex = selectedId - 2;
            if (deviceIndex < deviceIdentifiers.size()) {
                onDeviceSelected(deviceIdentifiers[deviceIndex]);
            }
        } else if (selectedId == 1 && onDeviceDeselected) {
            onDeviceDeselected();
        }
    }

    void triggerActivity() {
        activityIndicator.trigger();
    }

    std::function<void(const juce::String&)> onDeviceSelected;
    std::function<void()> onDeviceDeselected;

private:
    juce::String labelText;
    bool isInputDevice;

    juce::Label labelComponent;
    juce::ComboBox deviceCombo;
    MIDIActivityIndicator activityIndicator;
    juce::StringArray deviceIdentifiers;
};

// ============================================================================
// MIDI Learn Button
// ============================================================================

class MIDILearnButton : public juce::TextButton,
                        public juce::Timer {
public:
    MIDILearnButton() : juce::TextButton("MIDI Learn") {
        setColour(juce::TextButton::buttonColourId, MIDIPanelColors::Panel);
        setColour(juce::TextButton::textColourOffId, MIDIPanelColors::TextPrimary);
    }

    void setLearning(bool learning) {
        isLearning = learning;
        if (learning) {
            startTimerHz(4);  // Blink
            setColour(juce::TextButton::buttonColourId, MIDIPanelColors::Pink);
        } else {
            stopTimer();
            setColour(juce::TextButton::buttonColourId, MIDIPanelColors::Panel);
        }
        repaint();
    }

    void timerCallback() override {
        blinkState = !blinkState;
        setColour(juce::TextButton::buttonColourId,
                  blinkState ? MIDIPanelColors::Pink : MIDIPanelColors::Panel);
        repaint();
    }

private:
    bool isLearning = false;
    bool blinkState = false;
};

// ============================================================================
// MIDIPanel Main Class
// ============================================================================

class MIDIPanel : public juce::Component,
                  public juce::Button::Listener {
public:
    MIDIPanel();
    ~MIDIPanel() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void buttonClicked(juce::Button* button) override;

    // Engine connection
    void setMIDIEngine(MIDIEngine* engine);
    void setMPEVoiceManager(MPEVoiceManager* manager);

    // Refresh device lists
    void refreshDevices();

    // Expand/collapse
    void setExpanded(bool expanded);
    bool isExpanded() const { return expanded; }

    // Size
    int getCollapsedHeight() const { return 40; }
    int getExpandedHeight() const { return 280; }

private:
    void updateActiveNotesDisplay();
    void startMIDILearn();
    void stopMIDILearn();

    MIDIEngine* midiEngine = nullptr;
    MPEVoiceManager* mpeManager = nullptr;

    // UI Components
    juce::Label titleLabel;
    juce::TextButton expandButton;

    std::unique_ptr<MIDIDeviceSelector> inputSelector;
    std::unique_ptr<MIDIDeviceSelector> outputSelector;

    ActiveNotesDisplay activeNotesDisplay;
    MIDILearnButton midiLearnButton;

    juce::Label voiceCountLabel;
    juce::Label mpeStatusLabel;

    // MPE Controls
    juce::ToggleButton mpeEnableButton;
    juce::Slider pitchBendRangeSlider;
    juce::ComboBox voiceStealCombo;

    // State
    bool expanded = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MIDIPanel)
};

} // namespace Echoelmusic
