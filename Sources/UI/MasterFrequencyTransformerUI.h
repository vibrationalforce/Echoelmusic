#pragma once

#include <JuceHeader.h>
#include "../Visualization/MasterFrequencyTransformer.h"
#include "../Visualization/FrequencyLightTransformerUI.h"
#include "../Integration/PluginIntegrationHub.h"

//==============================================================================
/**
 * @brief MASTER FREQUENCY TRANSFORMER UI
 *
 * Complete interface for precision multi-source frequency-to-visual transformation.
 *
 * **FEATURES:**
 * - Precision inputs (3-decimal: Kammerton, BPM)
 * - Multi-source visualization (Audio, BPM, HRV, EEG)
 * - Extended color spaces (RGB, HSV, LAB)
 * - Precise piano mapping with microtonality
 * - Plugin connection status
 * - Quantum properties display
 *
 * @author Echoelmusic UI Team
 * @version 2.0.0
 */
class MasterFrequencyTransformerUI : public juce::Component,
                                      private juce::Timer
{
public:
    //==============================================================================
    MasterFrequencyTransformerUI()
    {
        // ===== PRECISION INPUTS =====

        // Custom A4 (Kammerton) with 3 decimals
        addAndMakeVisible(kammertonLabel);
        kammertonLabel.setText("Custom A4 (Hz):", juce::dontSendNotification);
        kammertonLabel.attachToComponent(&kammertonInput, true);

        addAndMakeVisible(kammertonInput);
        kammertonInput.setText("440.000", false);
        kammertonInput.setInputRestrictions(7, "0123456789.");
        kammertonInput.onTextChange = [this] { updateTransformation(); };

        // BPM with 3 decimals
        addAndMakeVisible(bpmLabel);
        bpmLabel.setText("BPM:", juce::dontSendNotification);
        bpmLabel.attachToComponent(&bpmInput, true);

        addAndMakeVisible(bpmInput);
        bpmInput.setText("120.000", false);
        bpmInput.setInputRestrictions(7, "0123456789.");
        bpmInput.onTextChange = [this] { updateTransformation(); };

        // Preset tuning selector
        addAndMakeVisible(tuningPresetCombo);
        tuningPresetCombo.addItem("Modern Standard (440 Hz)", 1);
        tuningPresetCombo.addItem("Verdi Tuning (432 Hz)", 2);
        tuningPresetCombo.addItem("Scientific Pitch (430.539 Hz)", 3);
        tuningPresetCombo.addItem("Baroque French (392 Hz)", 4);
        tuningPresetCombo.addItem("Baroque German (415.305 Hz)", 5);
        tuningPresetCombo.addItem("Berlin Phil (443 Hz)", 6);
        tuningPresetCombo.addItem("Vienna Phil (444 Hz)", 7);
        tuningPresetCombo.setSelectedId(1);
        tuningPresetCombo.onChange = [this] { applyTuningPreset(); };

        // ===== BIOMETRIC INPUTS =====

        addAndMakeVisible(hrvSlider);
        hrvSlider.setRange(0.04, 0.4, 0.001);
        hrvSlider.setValue(0.1);
        hrvSlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 80, 20);
        hrvSlider.onValueChange = [this] { updateTransformation(); };

        addAndMakeVisible(hrvLabel);
        hrvLabel.setText("HRV (Hz):", juce::dontSendNotification);
        hrvLabel.attachToComponent(&hrvSlider, true);

        // EEG Band Sliders
        const char* eegBandNames[] = {"Delta", "Theta", "Alpha", "Beta", "Gamma"};
        const double eegMin[] = {0.5, 4.0, 8.0, 13.0, 30.0};
        const double eegMax[] = {4.0, 8.0, 13.0, 30.0, 100.0};
        const double eegDefaults[] = {2.0, 6.0, 10.0, 20.0, 40.0};

        for (int i = 0; i < 5; ++i)
        {
            auto* slider = new juce::Slider();
            slider->setRange(eegMin[i], eegMax[i], 0.1);
            slider->setValue(eegDefaults[i]);
            slider->setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 18);
            slider->onValueChange = [this] { updateTransformation(); };
            addAndMakeVisible(slider);
            eegSliders.add(slider);

            auto* label = new juce::Label();
            label->setText(eegBandNames[i], juce::dontSendNotification);
            label->attachToComponent(slider, true);
            addAndMakeVisible(label);
            eegLabels.add(label);
        }

        // ===== PLUGIN INTEGRATION TOGGLE =====

        addAndMakeVisible(pluginIntegrationToggle);
        pluginIntegrationToggle.setButtonText("Enable Plugin Integration");
        pluginIntegrationToggle.setToggleState(true, juce::dontSendNotification);

        // Initialize
        updateTransformation();
        startTimerHz(30);  // 30 FPS

        setSize(1000, 900);
    }

    ~MasterFrequencyTransformerUI() override
    {
        stopTimer();
    }

    //==============================================================================
    // AUDIO INPUT
    //==============================================================================

    void processAudioBuffer(const juce::AudioBuffer<float>& buffer)
    {
        // Process FFT to get dominant frequency
        // (Use same logic as FrequencyLightTransformerUI)
        currentAudioFreq = extractDominantFrequency(buffer);
        updateTransformation();
    }

    //==============================================================================
    // COMPONENT OVERRIDES
    //==============================================================================

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds();

        // Background
        g.fillAll(juce::Colour(0xff0a0a0f));

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(20.0f, juce::Font::bold));
        g.drawText("🌈 MASTER UNIVERSAL FREQUENCY TRANSFORMER 🔬",
                   bounds.removeFromTop(35).reduced(10),
                   juce::Justification::centred);

        // Main color display
        auto colorArea = juce::Rectangle<float>(20, 350, 550, 200);
        g.setColour(juce::Colour::fromFloatRGBA(
            static_cast<float>(currentData.r),
            static_cast<float>(currentData.g),
            static_cast<float>(currentData.b),
            1.0f));
        g.fillRoundedRectangle(colorArea, 10.0f);

        // Glow effect
        g.setColour(juce::Colour::fromFloatRGBA(
            static_cast<float>(currentData.r),
            static_cast<float>(currentData.g),
            static_cast<float>(currentData.b),
            0.3f));
        g.drawRoundedRectangle(colorArea.expanded(8), 10.0f, 4.0f);

        // Data display area
        auto dataArea = bounds.withTrimmedTop(560).reduced(20);
        drawDataDisplay(g, dataArea);

        // Plugin status
        auto pluginArea = juce::Rectangle<float>(600, 350, 380, 530);
        drawPluginStatus(g, pluginArea);
    }

    void resized() override
    {
        auto area = getLocalBounds().reduced(10);

        // Title area
        area.removeFromTop(40);

        // Input section
        auto inputArea = area.removeFromTop(300);

        // Kammerton
        int y = 10;
        kammertonInput.setBounds(inputArea.removeFromTop(30).removeFromRight(150).withTrimmedLeft(120));

        // BPM
        y += 35;
        bpmInput.setBounds(inputArea.removeFromTop(30).removeFromRight(150).withTrimmedLeft(120));

        // Tuning preset
        y += 35;
        tuningPresetCombo.setBounds(inputArea.removeFromTop(25).removeFromRight(250).withTrimmedLeft(10));

        // HRV
        y += 35;
        hrvSlider.setBounds(inputArea.removeFromTop(60).removeFromRight(350).withTrimmedLeft(100));

        // EEG Sliders (horizontal layout)
        y += 70;
        auto eegArea = inputArea.removeFromTop(100).withTrimmedLeft(100);
        int eegWidth = eegArea.getWidth() / 5 - 10;

        for (int i = 0; i < 5; ++i)
        {
            eegSliders[i]->setBounds(eegArea.removeFromLeft(eegWidth).reduced(5));
            eegArea.removeFromLeft(10);
        }

        // Plugin integration toggle
        pluginIntegrationToggle.setBounds(area.removeFromTop(30).removeFromRight(250));
    }

private:
    //==============================================================================
    // DRAWING METHODS
    //==============================================================================

    void drawDataDisplay(juce::Graphics& g, juce::Rectangle<int> area)
    {
        g.setFont(juce::Font(14.0f));
        g.setColour(juce::Colours::white);

        int y = area.getY();
        int lineHeight = 22;

        // ===== FREQUENCIES =====
        g.setFont(juce::Font(16.0f, juce::Font::bold));
        g.setColour(juce::Colours::cyan);
        g.drawText("FREQUENCIES:", area.getX(), y, 200, lineHeight, juce::Justification::left);
        y += lineHeight + 5;

        g.setFont(juce::Font(14.0f));
        g.setColour(juce::Colours::white);
        g.drawText("Audio: " + juce::String(currentData.audioFrequency_Hz, 3) + " Hz",
                   area.getX() + 20, y, 250, lineHeight, juce::Justification::left);
        y += lineHeight;

        g.drawText("BPM: " + juce::String(currentData.bpm, 3) + " → " +
                   juce::String(currentData.bpmFrequency_Hz, 3) + " Hz",
                   area.getX() + 20, y, 250, lineHeight, juce::Justification::left);
        y += lineHeight;

        g.drawText("Dominant: " + juce::String(currentData.dominantFrequency_Hz, 3) + " Hz",
                   area.getX() + 20, y, 250, lineHeight, juce::Justification::left);
        y += lineHeight;

        g.setColour(juce::Colours::yellow);
        g.drawText("Visual: " + juce::String(currentData.visualFrequency_THz, 3) + " THz",
                   area.getX() + 20, y, 250, lineHeight, juce::Justification::left);
        y += lineHeight;

        g.drawText("λ: " + juce::String(currentData.wavelength_nm, 3) + " nm",
                   area.getX() + 20, y, 250, lineHeight, juce::Justification::left);
        y += lineHeight + 10;

        // ===== PIANO MAPPING =====
        g.setFont(juce::Font(16.0f, juce::Font::bold));
        g.setColour(juce::Colours::lightgreen);
        g.drawText("PIANO MAPPING:", area.getX(), y, 200, lineHeight, juce::Justification::left);
        y += lineHeight + 5;

        g.setFont(juce::Font(14.0f));
        g.setColour(juce::Colours::white);
        g.drawText("Note: " + currentData.noteName,
                   area.getX() + 20, y, 300, lineHeight, juce::Justification::left);
        y += lineHeight;

        g.drawText("Key: " + juce::String(currentData.exactPianoKey, 3) + " / 88",
                   area.getX() + 20, y, 250, lineHeight, juce::Justification::left);
        y += lineHeight;

        g.drawText("Tuning: A4 = " + juce::String(currentData.customA4_Hz, 3) + " Hz",
                   area.getX() + 20, y, 250, lineHeight, juce::Justification::left);
        y += lineHeight + 10;

        // ===== COLOR SPACES =====
        g.setFont(juce::Font(16.0f, juce::Font::bold));
        g.setColour(juce::Colours::magenta);
        g.drawText("COLOR SPACES:", area.getX(), y, 200, lineHeight, juce::Justification::left);
        y += lineHeight + 5;

        g.setFont(juce::Font(14.0f));
        g.setColour(juce::Colours::white);
        g.drawText(juce::String::formatted("RGB: (%.3f, %.3f, %.3f)",
                                          currentData.r, currentData.g, currentData.b),
                   area.getX() + 20, y, 300, lineHeight, juce::Justification::left);
        y += lineHeight;

        g.drawText(juce::String::formatted("HSV: (%.1f°, %.3f, %.3f)",
                                          currentData.h, currentData.s, currentData.v),
                   area.getX() + 20, y, 300, lineHeight, juce::Justification::left);
        y += lineHeight;

        g.drawText(juce::String::formatted("LAB: (%.1f, %.1f, %.1f)",
                                          currentData.L, currentData.a_star, currentData.b_star),
                   area.getX() + 20, y, 300, lineHeight, juce::Justification::left);
        y += lineHeight + 10;

        // ===== QUANTUM PROPERTIES =====
        g.setFont(juce::Font(16.0f, juce::Font::bold));
        g.setColour(juce::Colours::orange);
        g.drawText("QUANTUM PROPERTIES:", area.getX(), y, 250, lineHeight, juce::Justification::left);
        y += lineHeight + 5;

        g.setFont(juce::Font(14.0f));
        g.setColour(juce::Colours::white);
        g.drawText("Photon Energy: " + juce::String(currentData.photonEnergy_eV, 3) + " eV",
                   area.getX() + 20, y, 300, lineHeight, juce::Justification::left);
        y += lineHeight;

        g.drawText("Coherence: " + juce::String(currentData.quantumCoherence, 3),
                   area.getX() + 20, y, 300, lineHeight, juce::Justification::left);
        y += lineHeight;

        g.drawText("Planck Units: " + juce::String(currentData.planckUnits, 2, true),
                   area.getX() + 20, y, 300, lineHeight, juce::Justification::left);
    }

    void drawPluginStatus(juce::Graphics& g, juce::Rectangle<float> area)
    {
        // Background
        g.setColour(juce::Colour(0xff1a1a2f).withAlpha(0.7f));
        g.fillRoundedRectangle(area, 8.0f);

        area.reduce(15, 15);

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(16.0f, juce::Font::bold));
        g.drawText("PLUGIN CONNECTIONS", area.removeFromTop(25), juce::Justification::centred);

        area.removeFromTop(10);

        // Plugin list
        auto statusList = pluginHub.getPluginStatusList();

        g.setFont(juce::Font(12.0f));

        for (const auto& plugin : statusList)
        {
            auto lineArea = area.removeFromTop(28);

            // Connection indicator
            g.setColour(plugin.connected ? juce::Colours::green : juce::Colours::red);
            g.fillEllipse(lineArea.removeFromLeft(12).withSizeKeepingCentre(8, 8));

            lineArea.removeFromLeft(8);

            // Plugin name
            g.setColour(juce::Colours::white);
            g.drawText(plugin.name, lineArea.removeFromLeft(150), juce::Justification::left);

            // Data flow bar
            auto barArea = lineArea.removeFromLeft(150).withSizeKeepingCentre(150, 6);

            g.setColour(juce::Colours::darkgrey);
            g.fillRect(barArea);

            g.setColour(juce::Colours::cyan);
            g.fillRect(barArea.withWidth(barArea.getWidth() * plugin.dataFlowRate));

            // Messages sent
            g.setColour(juce::Colours::lightgrey);
            g.setFont(juce::Font(10.0f));
            g.drawText(juce::String(plugin.messagesSent), lineArea, juce::Justification::right);
        }
    }

    //==============================================================================
    // UPDATE METHODS
    //==============================================================================

    void timerCallback() override
    {
        repaint();
    }

    void updateTransformation()
    {
        // Parse inputs
        double customA4 = kammertonInput.getText().getDoubleValue();
        double bpm = bpmInput.getText().getDoubleValue();
        double hrv = hrvSlider.getValue();

        // EEG bands
        std::array<double, 5> eeg;
        for (int i = 0; i < 5; ++i)
            eeg[i] = eegSliders[i]->getValue();

        // Transform
        currentData = MasterFrequencyTransformer::transformAllSources(
            currentAudioFreq,
            bpm,
            hrv,
            eeg,
            customA4
        );

        // Send to plugins if enabled
        if (pluginIntegrationToggle.getToggleState())
        {
            pluginHub.distributeToAllPlugins(currentData);
        }
    }

    void applyTuningPreset()
    {
        int selectedId = tuningPresetCombo.getSelectedId();

        double presetA4 = 440.000;

        switch (selectedId)
        {
            case 1: presetA4 = 440.000; break;  // Modern Standard
            case 2: presetA4 = 432.000; break;  // Verdi
            case 3: presetA4 = 430.539; break;  // Scientific
            case 4: presetA4 = 392.000; break;  // Baroque French
            case 5: presetA4 = 415.305; break;  // Baroque German
            case 6: presetA4 = 443.000; break;  // Berlin Phil
            case 7: presetA4 = 444.000; break;  // Vienna Phil
        }

        kammertonInput.setText(juce::String(presetA4, 3), true);
    }

    double extractDominantFrequency(const juce::AudioBuffer<float>& buffer)
    {
        // Simple peak detection (placeholder)
        // In production, use proper FFT analysis
        juce::ignoreUnused(buffer);
        return 440.0;  // Default A4
    }

    //==============================================================================
    // UI COMPONENTS
    //==============================================================================

    juce::Label kammertonLabel, bpmLabel, hrvLabel;
    juce::TextEditor kammertonInput, bpmInput;
    juce::ComboBox tuningPresetCombo;
    juce::Slider hrvSlider;
    juce::OwnedArray<juce::Slider> eegSliders;
    juce::OwnedArray<juce::Label> eegLabels;
    juce::ToggleButton pluginIntegrationToggle;

    //==============================================================================
    // DATA
    //==============================================================================

    MasterFrequencyTransformer::UnifiedFrequencyData currentData;
    PluginIntegrationHub pluginHub;

    double currentAudioFreq = 440.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MasterFrequencyTransformerUI)
};
