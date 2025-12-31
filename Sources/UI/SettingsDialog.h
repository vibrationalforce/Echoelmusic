#pragma once

#include <JuceHeader.h>
#include "../Audio/AudioEngine.h"

/**
 * SettingsDialog - Application settings dialog
 *
 * Features:
 * - Audio settings (sample rate, buffer size)
 * - UI/Theme settings
 * - General application settings
 */
class SettingsDialog : public juce::Component,
                       public juce::Button::Listener,
                       public juce::ComboBox::Listener
{
public:
    //==========================================================================
    SettingsDialog(AudioEngine& engine)
        : audioEngine(engine)
    {
        // Title
        addAndMakeVisible(titleLabel);
        titleLabel.setText("Settings", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(24.0f, juce::Font::bold));
        titleLabel.setColour(juce::Label::textColourId, juce::Colour(0xff00d4ff));

        // Audio Section
        addAndMakeVisible(audioSectionLabel);
        audioSectionLabel.setText("Audio Settings", juce::dontSendNotification);
        audioSectionLabel.setFont(juce::Font(16.0f, juce::Font::bold));
        audioSectionLabel.setColour(juce::Label::textColourId, juce::Colour(0xffff00ff));

        // Sample Rate
        addAndMakeVisible(sampleRateLabel);
        sampleRateLabel.setText("Sample Rate:", juce::dontSendNotification);

        addAndMakeVisible(sampleRateCombo);
        sampleRateCombo.addItem("44100 Hz", 1);
        sampleRateCombo.addItem("48000 Hz", 2);
        sampleRateCombo.addItem("88200 Hz", 3);
        sampleRateCombo.addItem("96000 Hz", 4);

        // Set current sample rate
        double currentRate = audioEngine.getSampleRate();
        if (currentRate == 44100.0) sampleRateCombo.setSelectedId(1);
        else if (currentRate == 48000.0) sampleRateCombo.setSelectedId(2);
        else if (currentRate == 88200.0) sampleRateCombo.setSelectedId(3);
        else if (currentRate == 96000.0) sampleRateCombo.setSelectedId(4);
        else sampleRateCombo.setSelectedId(2);  // Default 48kHz

        sampleRateCombo.addListener(this);

        // Buffer Size
        addAndMakeVisible(bufferSizeLabel);
        bufferSizeLabel.setText("Buffer Size:", juce::dontSendNotification);

        addAndMakeVisible(bufferSizeCombo);
        bufferSizeCombo.addItem("64 samples", 1);
        bufferSizeCombo.addItem("128 samples", 2);
        bufferSizeCombo.addItem("256 samples", 3);
        bufferSizeCombo.addItem("512 samples", 4);
        bufferSizeCombo.addItem("1024 samples", 5);
        bufferSizeCombo.addItem("2048 samples", 6);
        bufferSizeCombo.setSelectedId(4);  // Default 512
        bufferSizeCombo.addListener(this);

        // UI Section
        addAndMakeVisible(uiSectionLabel);
        uiSectionLabel.setText("User Interface", juce::dontSendNotification);
        uiSectionLabel.setFont(juce::Font(16.0f, juce::Font::bold));
        uiSectionLabel.setColour(juce::Label::textColourId, juce::Colour(0xffff00ff));

        // Theme
        addAndMakeVisible(themeLabel);
        themeLabel.setText("Theme:", juce::dontSendNotification);

        addAndMakeVisible(themeCombo);
        themeCombo.addItem("Vaporwave (Default)", 1);
        themeCombo.addItem("Dark", 2);
        themeCombo.addItem("Light", 3);
        themeCombo.setSelectedId(1);
        themeCombo.addListener(this);

        // Show Tooltips
        addAndMakeVisible(showTooltipsToggle);
        showTooltipsToggle.setButtonText("Show Tooltips");
        showTooltipsToggle.setToggleState(true, juce::dontSendNotification);

        // General Section
        addAndMakeVisible(generalSectionLabel);
        generalSectionLabel.setText("General", juce::dontSendNotification);
        generalSectionLabel.setFont(juce::Font(16.0f, juce::Font::bold));
        generalSectionLabel.setColour(juce::Label::textColourId, juce::Colour(0xffff00ff));

        // Auto-save
        addAndMakeVisible(autoSaveToggle);
        autoSaveToggle.setButtonText("Auto-save projects");
        autoSaveToggle.setToggleState(true, juce::dontSendNotification);

        // Auto-save Interval
        addAndMakeVisible(autoSaveIntervalLabel);
        autoSaveIntervalLabel.setText("Auto-save interval:", juce::dontSendNotification);

        addAndMakeVisible(autoSaveIntervalCombo);
        autoSaveIntervalCombo.addItem("1 minute", 1);
        autoSaveIntervalCombo.addItem("5 minutes", 2);
        autoSaveIntervalCombo.addItem("10 minutes", 3);
        autoSaveIntervalCombo.addItem("15 minutes", 4);
        autoSaveIntervalCombo.setSelectedId(2);  // Default 5 minutes

        // Buttons
        addAndMakeVisible(applyButton);
        applyButton.setButtonText("Apply");
        applyButton.setColour(juce::TextButton::buttonColourId, juce::Colour(0xff44ff44));
        applyButton.addListener(this);

        addAndMakeVisible(cancelButton);
        cancelButton.setButtonText("Cancel");
        cancelButton.addListener(this);

        addAndMakeVisible(okButton);
        okButton.setButtonText("OK");
        okButton.setColour(juce::TextButton::buttonColourId, juce::Colour(0xff00d4ff));
        okButton.addListener(this);

        // Status
        addAndMakeVisible(statusLabel);
        statusLabel.setText("", juce::dontSendNotification);
        statusLabel.setJustificationType(juce::Justification::centred);
        statusLabel.setColour(juce::Label::textColourId, juce::Colour(0xff00d4ff));

        setSize(450, 520);
    }

    ~SettingsDialog() override
    {
        sampleRateCombo.removeListener(this);
        bufferSizeCombo.removeListener(this);
        themeCombo.removeListener(this);
        applyButton.removeListener(this);
        cancelButton.removeListener(this);
        okButton.removeListener(this);
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xff1a1a1f));

        // Border with vaporwave glow
        g.setColour(juce::Colour(0xff00d4ff));
        g.drawRect(getLocalBounds(), 2);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(20);

        // Title
        titleLabel.setBounds(bounds.removeFromTop(40));
        bounds.removeFromTop(15);

        // Audio Section
        audioSectionLabel.setBounds(bounds.removeFromTop(25));
        bounds.removeFromTop(10);

        auto sampleRateRow = bounds.removeFromTop(30);
        sampleRateLabel.setBounds(sampleRateRow.removeFromLeft(130));
        sampleRateCombo.setBounds(sampleRateRow);
        bounds.removeFromTop(10);

        auto bufferSizeRow = bounds.removeFromTop(30);
        bufferSizeLabel.setBounds(bufferSizeRow.removeFromLeft(130));
        bufferSizeCombo.setBounds(bufferSizeRow);
        bounds.removeFromTop(20);

        // UI Section
        uiSectionLabel.setBounds(bounds.removeFromTop(25));
        bounds.removeFromTop(10);

        auto themeRow = bounds.removeFromTop(30);
        themeLabel.setBounds(themeRow.removeFromLeft(130));
        themeCombo.setBounds(themeRow);
        bounds.removeFromTop(10);

        showTooltipsToggle.setBounds(bounds.removeFromTop(30));
        bounds.removeFromTop(20);

        // General Section
        generalSectionLabel.setBounds(bounds.removeFromTop(25));
        bounds.removeFromTop(10);

        autoSaveToggle.setBounds(bounds.removeFromTop(30));
        bounds.removeFromTop(10);

        auto autoSaveIntervalRow = bounds.removeFromTop(30);
        autoSaveIntervalLabel.setBounds(autoSaveIntervalRow.removeFromLeft(130));
        autoSaveIntervalCombo.setBounds(autoSaveIntervalRow);
        bounds.removeFromTop(20);

        // Status
        statusLabel.setBounds(bounds.removeFromTop(25));
        bounds.removeFromTop(10);

        // Buttons
        auto buttonRow = bounds.removeFromTop(40);
        int buttonWidth = (buttonRow.getWidth() - 20) / 3;
        cancelButton.setBounds(buttonRow.removeFromLeft(buttonWidth).reduced(5));
        buttonRow.removeFromLeft(10);
        applyButton.setBounds(buttonRow.removeFromLeft(buttonWidth).reduced(5));
        buttonRow.removeFromLeft(10);
        okButton.setBounds(buttonRow.reduced(5));
    }

    void buttonClicked(juce::Button* button) override
    {
        if (button == &applyButton)
        {
            applySettings();
        }
        else if (button == &okButton)
        {
            applySettings();
            closeDialog();
        }
        else if (button == &cancelButton)
        {
            closeDialog();
        }
    }

    void comboBoxChanged(juce::ComboBox*) override
    {
        // Mark that settings have been changed (could show unsaved indicator)
        statusLabel.setText("Settings modified (not applied)", juce::dontSendNotification);
        statusLabel.setColour(juce::Label::textColourId, juce::Colour(0xffffaa00));
    }

private:
    void applySettings()
    {
        // Get sample rate
        double newSampleRate = 48000.0;
        switch (sampleRateCombo.getSelectedId())
        {
            case 1: newSampleRate = 44100.0; break;
            case 2: newSampleRate = 48000.0; break;
            case 3: newSampleRate = 88200.0; break;
            case 4: newSampleRate = 96000.0; break;
        }

        // Get buffer size
        int newBufferSize = 512;
        switch (bufferSizeCombo.getSelectedId())
        {
            case 1: newBufferSize = 64; break;
            case 2: newBufferSize = 128; break;
            case 3: newBufferSize = 256; break;
            case 4: newBufferSize = 512; break;
            case 5: newBufferSize = 1024; break;
            case 6: newBufferSize = 2048; break;
        }

        // Apply to audio engine
        audioEngine.prepare(newSampleRate, newBufferSize);

        // Log the change
        juce::Logger::writeToLog("Settings applied: " +
            juce::String(newSampleRate) + " Hz, " +
            juce::String(newBufferSize) + " samples");

        statusLabel.setText("Settings applied successfully", juce::dontSendNotification);
        statusLabel.setColour(juce::Label::textColourId, juce::Colour(0xff44ff44));
    }

    void closeDialog()
    {
        if (auto* parent = findParentComponentOfClass<juce::DialogWindow>())
            parent->exitModalState(0);
    }

    AudioEngine& audioEngine;

    // Title
    juce::Label titleLabel;

    // Audio Section
    juce::Label audioSectionLabel;
    juce::Label sampleRateLabel;
    juce::ComboBox sampleRateCombo;
    juce::Label bufferSizeLabel;
    juce::ComboBox bufferSizeCombo;

    // UI Section
    juce::Label uiSectionLabel;
    juce::Label themeLabel;
    juce::ComboBox themeCombo;
    juce::ToggleButton showTooltipsToggle;

    // General Section
    juce::Label generalSectionLabel;
    juce::ToggleButton autoSaveToggle;
    juce::Label autoSaveIntervalLabel;
    juce::ComboBox autoSaveIntervalCombo;

    // Buttons
    juce::TextButton applyButton;
    juce::TextButton cancelButton;
    juce::TextButton okButton;

    // Status
    juce::Label statusLabel;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SettingsDialog)
};
