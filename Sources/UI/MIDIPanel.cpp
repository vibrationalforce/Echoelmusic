/**
 * MIDIPanel.cpp
 * Echoelmusic MIDI Control Panel Implementation
 *
 * Copyright (c) 2025 Echoelmusic
 */

#include "MIDIPanel.h"

namespace Echoelmusic {

// ============================================================================
// Constructor / Destructor
// ============================================================================

MIDIPanel::MIDIPanel() {
    // Title
    addAndMakeVisible(titleLabel);
    titleLabel.setText("MIDI", juce::dontSendNotification);
    titleLabel.setFont(juce::Font(14.0f, juce::Font::bold));
    titleLabel.setColour(juce::Label::textColourId, MIDIPanelColors::Cyan);

    // Expand button
    addAndMakeVisible(expandButton);
    expandButton.setButtonText("+");
    expandButton.addListener(this);
    expandButton.setColour(juce::TextButton::buttonColourId, MIDIPanelColors::Panel);
    expandButton.setColour(juce::TextButton::textColourOffId, MIDIPanelColors::Cyan);

    // Input selector
    inputSelector = std::make_unique<MIDIDeviceSelector>("Input Device", true);
    addAndMakeVisible(*inputSelector);

    inputSelector->onDeviceSelected = [this](const juce::String& identifier) {
        if (midiEngine) {
            midiEngine->openInput(identifier);
            DBG("MIDIPanel: Opened input - " << identifier);
        }
    };

    inputSelector->onDeviceDeselected = [this]() {
        // Close all inputs
        if (midiEngine) {
            midiEngine->closeAllDevices();
        }
    };

    // Output selector
    outputSelector = std::make_unique<MIDIDeviceSelector>("Output Device", false);
    addAndMakeVisible(*outputSelector);

    outputSelector->onDeviceSelected = [this](const juce::String& identifier) {
        if (midiEngine) {
            midiEngine->openOutput(identifier);
            DBG("MIDIPanel: Opened output - " << identifier);
        }
    };

    // Active notes display
    addAndMakeVisible(activeNotesDisplay);

    // MIDI Learn button
    addAndMakeVisible(midiLearnButton);
    midiLearnButton.addListener(this);

    // Voice count label
    addAndMakeVisible(voiceCountLabel);
    voiceCountLabel.setText("Voices: 0/15", juce::dontSendNotification);
    voiceCountLabel.setFont(juce::Font(11.0f));
    voiceCountLabel.setColour(juce::Label::textColourId, MIDIPanelColors::TextSecondary);

    // MPE status label
    addAndMakeVisible(mpeStatusLabel);
    mpeStatusLabel.setText("MPE: Off", juce::dontSendNotification);
    mpeStatusLabel.setFont(juce::Font(11.0f));
    mpeStatusLabel.setColour(juce::Label::textColourId, MIDIPanelColors::TextSecondary);

    // MPE Enable button
    addAndMakeVisible(mpeEnableButton);
    mpeEnableButton.setButtonText("Enable MPE");
    mpeEnableButton.setColour(juce::ToggleButton::textColourId, MIDIPanelColors::TextPrimary);
    mpeEnableButton.setColour(juce::ToggleButton::tickColourId, MIDIPanelColors::Cyan);

    mpeEnableButton.onClick = [this]() {
        bool enabled = mpeEnableButton.getToggleState();
        mpeStatusLabel.setText(enabled ? "MPE: On" : "MPE: Off", juce::dontSendNotification);
        mpeStatusLabel.setColour(juce::Label::textColourId,
                                 enabled ? MIDIPanelColors::Active : MIDIPanelColors::TextSecondary);
    };

    // Pitch bend range slider
    addAndMakeVisible(pitchBendRangeSlider);
    pitchBendRangeSlider.setRange(1.0, 96.0, 1.0);
    pitchBendRangeSlider.setValue(48.0);
    pitchBendRangeSlider.setTextBoxStyle(juce::Slider::TextBoxRight, false, 40, 20);
    pitchBendRangeSlider.setColour(juce::Slider::thumbColourId, MIDIPanelColors::Cyan);
    pitchBendRangeSlider.setColour(juce::Slider::trackColourId, MIDIPanelColors::PanelLight);
    pitchBendRangeSlider.setColour(juce::Slider::textBoxTextColourId, MIDIPanelColors::TextPrimary);

    pitchBendRangeSlider.onValueChange = [this]() {
        if (mpeManager) {
            mpeManager->setPitchBendRange(static_cast<float>(pitchBendRangeSlider.getValue()));
        }
    };

    // Voice steal combo
    addAndMakeVisible(voiceStealCombo);
    voiceStealCombo.addItem("Round Robin", 1);
    voiceStealCombo.addItem("Least Recent", 2);
    voiceStealCombo.addItem("Lowest Note", 3);
    voiceStealCombo.addItem("Highest Note", 4);
    voiceStealCombo.addItem("Quietest", 5);
    voiceStealCombo.addItem("None", 6);
    voiceStealCombo.setSelectedId(2);  // Default: Least Recent
    voiceStealCombo.setColour(juce::ComboBox::backgroundColourId, MIDIPanelColors::Panel);
    voiceStealCombo.setColour(juce::ComboBox::textColourId, MIDIPanelColors::TextPrimary);

    voiceStealCombo.onChange = [this]() {
        if (mpeManager) {
            int id = voiceStealCombo.getSelectedId();
            VoiceStealStrategy strategy = VoiceStealStrategy::LeastRecent;

            switch (id) {
                case 1: strategy = VoiceStealStrategy::RoundRobin; break;
                case 2: strategy = VoiceStealStrategy::LeastRecent; break;
                case 3: strategy = VoiceStealStrategy::LowestNote; break;
                case 4: strategy = VoiceStealStrategy::HighestNote; break;
                case 5: strategy = VoiceStealStrategy::QuietestNote; break;
                case 6: strategy = VoiceStealStrategy::None; break;
            }

            mpeManager->setVoiceStealStrategy(strategy);
        }
    };

    // Start collapsed
    setExpanded(false);
}

MIDIPanel::~MIDIPanel() {
    stopMIDILearn();
}

// ============================================================================
// Paint
// ============================================================================

void MIDIPanel::paint(juce::Graphics& g) {
    auto bounds = getLocalBounds().toFloat();

    // Background
    g.setColour(MIDIPanelColors::Background);
    g.fillRoundedRectangle(bounds, 6.0f);

    // Border
    g.setColour(MIDIPanelColors::PanelLight);
    g.drawRoundedRectangle(bounds.reduced(0.5f), 6.0f, 1.0f);

    // Gradient accent
    if (expanded) {
        juce::ColourGradient gradient(
            MIDIPanelColors::Cyan.withAlpha(0.1f),
            bounds.getTopLeft(),
            MIDIPanelColors::Magenta.withAlpha(0.1f),
            bounds.getBottomRight(),
            false
        );
        g.setGradientFill(gradient);
        g.fillRoundedRectangle(bounds.reduced(1), 5.0f);
    }
}

// ============================================================================
// Resized
// ============================================================================

void MIDIPanel::resized() {
    auto bounds = getLocalBounds().reduced(8);

    // Header row
    auto headerRow = bounds.removeFromTop(24);
    titleLabel.setBounds(headerRow.removeFromLeft(60));
    expandButton.setBounds(headerRow.removeFromRight(24));

    // Status labels in header
    voiceCountLabel.setBounds(headerRow.removeFromRight(80));
    mpeStatusLabel.setBounds(headerRow.removeFromRight(60));

    if (!expanded) {
        // Hide expanded content
        inputSelector->setVisible(false);
        outputSelector->setVisible(false);
        activeNotesDisplay.setVisible(false);
        midiLearnButton.setVisible(false);
        mpeEnableButton.setVisible(false);
        pitchBendRangeSlider.setVisible(false);
        voiceStealCombo.setVisible(false);
        return;
    }

    // Show expanded content
    inputSelector->setVisible(true);
    outputSelector->setVisible(true);
    activeNotesDisplay.setVisible(true);
    midiLearnButton.setVisible(true);
    mpeEnableButton.setVisible(true);
    pitchBendRangeSlider.setVisible(true);
    voiceStealCombo.setVisible(true);

    bounds.removeFromTop(8);  // Spacing

    // Device selectors row
    auto deviceRow = bounds.removeFromTop(50);
    inputSelector->setBounds(deviceRow.removeFromLeft(deviceRow.getWidth() / 2 - 4));
    deviceRow.removeFromLeft(8);
    outputSelector->setBounds(deviceRow);

    bounds.removeFromTop(8);

    // Active notes display
    activeNotesDisplay.setBounds(bounds.removeFromTop(30));

    bounds.removeFromTop(8);

    // MIDI Learn button
    auto learnRow = bounds.removeFromTop(28);
    midiLearnButton.setBounds(learnRow.removeFromLeft(100));

    bounds.removeFromTop(12);

    // MPE section
    auto mpeRow1 = bounds.removeFromTop(24);
    mpeEnableButton.setBounds(mpeRow1.removeFromLeft(120));

    bounds.removeFromTop(4);

    auto mpeRow2 = bounds.removeFromTop(24);
    juce::Label* pbLabel = new juce::Label();
    pbLabel->setText("Pitch Bend:", juce::dontSendNotification);
    pbLabel->setFont(juce::Font(11.0f));
    pbLabel->setColour(juce::Label::textColourId, MIDIPanelColors::TextSecondary);
    pbLabel->setBounds(mpeRow2.removeFromLeft(70));
    addAndMakeVisible(pbLabel);
    pitchBendRangeSlider.setBounds(mpeRow2);

    bounds.removeFromTop(4);

    auto mpeRow3 = bounds.removeFromTop(24);
    juce::Label* vsLabel = new juce::Label();
    vsLabel->setText("Voice Steal:", juce::dontSendNotification);
    vsLabel->setFont(juce::Font(11.0f));
    vsLabel->setColour(juce::Label::textColourId, MIDIPanelColors::TextSecondary);
    vsLabel->setBounds(mpeRow3.removeFromLeft(70));
    addAndMakeVisible(vsLabel);
    voiceStealCombo.setBounds(mpeRow3);
}

// ============================================================================
// Button Clicked
// ============================================================================

void MIDIPanel::buttonClicked(juce::Button* button) {
    if (button == &expandButton) {
        setExpanded(!expanded);
    } else if (button == &midiLearnButton) {
        if (midiEngine && midiEngine->isMIDILearning()) {
            stopMIDILearn();
        } else {
            startMIDILearn();
        }
    }
}

// ============================================================================
// Engine Connection
// ============================================================================

void MIDIPanel::setMIDIEngine(MIDIEngine* engine) {
    midiEngine = engine;

    if (midiEngine) {
        // Set up callbacks
        midiEngine->setNoteOnCallback([this](uint8_t channel, uint8_t note,
                                             uint16_t velocity, uint8_t group) {
            juce::MessageManager::callAsync([this, note, velocity]() {
                activeNotesDisplay.setActiveNote(note, velocity >> 9);  // Scale to 7-bit
                inputSelector->triggerActivity();
                updateActiveNotesDisplay();
            });
        });

        midiEngine->setNoteOffCallback([this](uint8_t channel, uint8_t note,
                                              uint16_t velocity, uint8_t group) {
            juce::MessageManager::callAsync([this, note]() {
                activeNotesDisplay.setActiveNote(note, 0);
                inputSelector->triggerActivity();
                updateActiveNotesDisplay();
            });
        });

        midiEngine->setControlChangeCallback([this](uint8_t channel, uint8_t cc,
                                                    uint32_t value, uint8_t group) {
            juce::MessageManager::callAsync([this]() {
                inputSelector->triggerActivity();
            });
        });
    }
}

void MIDIPanel::setMPEVoiceManager(MPEVoiceManager* manager) {
    mpeManager = manager;

    if (mpeManager) {
        // Set up voice callbacks
        mpeManager->setVoiceActivatedCallback([this](const MPEVoice& voice) {
            juce::MessageManager::callAsync([this]() {
                updateActiveNotesDisplay();
            });
        });

        mpeManager->setVoiceDeactivatedCallback([this](const MPEVoice& voice) {
            juce::MessageManager::callAsync([this]() {
                updateActiveNotesDisplay();
            });
        });
    }
}

// ============================================================================
// Refresh Devices
// ============================================================================

void MIDIPanel::refreshDevices() {
    inputSelector->refreshDevices();
    outputSelector->refreshDevices();
}

// ============================================================================
// Expand / Collapse
// ============================================================================

void MIDIPanel::setExpanded(bool exp) {
    expanded = exp;
    expandButton.setButtonText(expanded ? "-" : "+");

    // Resize parent if needed
    if (auto* parent = getParentComponent()) {
        setSize(getWidth(), expanded ? getExpandedHeight() : getCollapsedHeight());
        parent->resized();
    }

    resized();
    repaint();
}

// ============================================================================
// Private Methods
// ============================================================================

void MIDIPanel::updateActiveNotesDisplay() {
    int activeCount = 0;

    if (mpeManager) {
        activeCount = mpeManager->getActiveVoiceCount();
    } else if (midiEngine) {
        activeCount = midiEngine->getActiveNoteCount();
    }

    voiceCountLabel.setText("Voices: " + juce::String(activeCount) + "/15",
                            juce::dontSendNotification);

    // Color based on usage
    float usage = activeCount / 15.0f;
    juce::Colour color = MIDIPanelColors::TextSecondary;
    if (usage > 0.8f) {
        color = MIDIPanelColors::Pink;  // Near full
    } else if (usage > 0.5f) {
        color = MIDIPanelColors::Purple;
    } else if (activeCount > 0) {
        color = MIDIPanelColors::Cyan;
    }
    voiceCountLabel.setColour(juce::Label::textColourId, color);
}

void MIDIPanel::startMIDILearn() {
    if (!midiEngine) return;

    midiLearnButton.setLearning(true);
    midiLearnButton.setButtonText("Learning...");

    midiEngine->startMIDILearn([this](uint8_t channel, uint8_t cc) {
        juce::MessageManager::callAsync([this, channel, cc]() {
            DBG("MIDIPanel: Learned CC " << static_cast<int>(cc)
                << " on channel " << static_cast<int>(channel));
            stopMIDILearn();
        });
    });
}

void MIDIPanel::stopMIDILearn() {
    if (midiEngine) {
        midiEngine->stopMIDILearn();
    }

    midiLearnButton.setLearning(false);
    midiLearnButton.setButtonText("MIDI Learn");
}

} // namespace Echoelmusic
