#pragma once

#include <JuceHeader.h>
#include "../CreativeTools/IntelligentDelayCalculator.h"
#include "../CreativeTools/HarmonicFrequencyAnalyzer.h"
#include "../CreativeTools/IntelligentDynamicProcessor.h"

//==============================================================================
/**
 * @brief Creative Tools Panel - Professional Studio Calculators
 *
 * Unified panel for creative production tools:
 * - Intelligent Delay Calculator (BPM-sync)
 * - Harmonic Frequency Analyzer (overtones, room modes)
 * - Dynamic Processor Calculator (compression, loudness)
 *
 * Design für: Kreativ + Gesund + Mobil + Biofeedback
 */
class CreativeToolsPanel : public juce::Component
{
public:
    //==============================================================================
    CreativeToolsPanel()
    {
        setupUI();
    }

    ~CreativeToolsPanel() override = default;

    //==============================================================================
    void paint(juce::Graphics& g) override
    {
        // Background
        g.fillAll(juce::Colour(0xff2a2a2a));

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(24.0f);
        g.drawText("Creative Tools Suite 🎚️", getLocalBounds().removeFromTop(40),
                  juce::Justification::centred);

        // Section separators
        g.setColour(juce::Colours::grey);
        int sectionHeight = (getHeight() - 50) / 3;
        g.drawLine(10.0f, 50.0f + sectionHeight, getWidth() - 10.0f, 50.0f + sectionHeight, 2.0f);
        g.drawLine(10.0f, 50.0f + 2 * sectionHeight, getWidth() - 10.0f, 50.0f + 2 * sectionHeight, 2.0f);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10);
        bounds.removeFromTop(40);  // Title
        bounds.removeFromTop(10);  // Spacing

        int sectionHeight = bounds.getHeight() / 3;

        // Delay Calculator Section
        auto delayArea = bounds.removeFromTop(sectionHeight).reduced(5);
        layoutDelaySection(delayArea);

        // Harmonic Analyzer Section
        auto harmonicArea = bounds.removeFromTop(sectionHeight).reduced(5);
        layoutHarmonicSection(harmonicArea);

        // Dynamic Processor Section
        auto dynamicArea = bounds.reduced(5);
        layoutDynamicSection(dynamicArea);
    }

private:
    //==============================================================================
    void setupUI()
    {
        // === DELAY CALCULATOR ===
        addAndMakeVisible(delayLabel);
        delayLabel.setText("⏱️ Delay Calculator (BPM-Sync)", juce::dontSendNotification);
        delayLabel.setColour(juce::Label::textColourId, juce::Colours::cyan);
        delayLabel.setFont(juce::Font(16.0f, juce::Font::bold));

        addAndMakeVisible(bpmSlider);
        bpmSlider.setRange(40.0, 300.0, 0.1);
        bpmSlider.setValue(120.0);
        bpmSlider.setTextBoxStyle(juce::Slider::TextBoxRight, false, 80, 20);
        bpmSlider.onValueChange = [this] { calculateDelayTime(); };

        addAndMakeVisible(bpmLabel);
        bpmLabel.setText("BPM:", juce::dontSendNotification);
        bpmLabel.attachToComponent(&bpmSlider, true);

        addAndMakeVisible(noteDivisionCombo);
        noteDivisionCombo.addItem("1/1 (Whole)", 1);
        noteDivisionCombo.addItem("1/2 (Half)", 2);
        noteDivisionCombo.addItem("1/4 (Quarter)", 3);
        noteDivisionCombo.addItem("1/8 (Eighth)", 4);
        noteDivisionCombo.addItem("1/16 (16th)", 5);
        noteDivisionCombo.addItem("1/32 (32nd)", 6);
        noteDivisionCombo.setSelectedId(4);  // Default: 1/8
        noteDivisionCombo.onChange = [this] { calculateDelayTime(); };

        addAndMakeVisible(noteModifierCombo);
        noteModifierCombo.addItem("Straight", 1);
        noteModifierCombo.addItem("Dotted", 2);
        noteModifierCombo.addItem("Triplet", 3);
        noteModifierCombo.setSelectedId(1);
        noteModifierCombo.onChange = [this] { calculateDelayTime(); };

        addAndMakeVisible(delayResultLabel);
        delayResultLabel.setText("Delay: --- ms", juce::dontSendNotification);
        delayResultLabel.setColour(juce::Label::textColourId, juce::Colours::yellow);
        delayResultLabel.setFont(juce::Font(18.0f, juce::Font::bold));
        delayResultLabel.setJustificationType(juce::Justification::centred);

        // Haas Effect
        addAndMakeVisible(haasButton);
        haasButton.setButtonText("Haas Effect (Stereo Width)");
        haasButton.onClick = [this] { calculateHaasEffect(); };

        // === HARMONIC ANALYZER ===
        addAndMakeVisible(harmonicLabel);
        harmonicLabel.setText("🎵 Harmonic Analyzer", juce::dontSendNotification);
        harmonicLabel.setColour(juce::Label::textColourId, juce::Colours::orange);
        harmonicLabel.setFont(juce::Font(16.0f, juce::Font::bold));

        addAndMakeVisible(fundamentalSlider);
        fundamentalSlider.setRange(20.0, 2000.0, 0.1);
        fundamentalSlider.setValue(440.0);
        fundamentalSlider.setTextBoxStyle(juce::Slider::TextBoxRight, false, 80, 20);
        fundamentalSlider.onValueChange = [this] { analyzeHarmonics(); };

        addAndMakeVisible(fundamentalLabel);
        fundamentalLabel.setText("Fundamental (Hz):", juce::dontSendNotification);
        fundamentalLabel.attachToComponent(&fundamentalSlider, true);

        addAndMakeVisible(harmonicResultLabel);
        harmonicResultLabel.setText("Harmonics: ---", juce::dontSendNotification);
        harmonicResultLabel.setColour(juce::Label::textColourId, juce::Colours::yellow);
        harmonicResultLabel.setFont(juce::Font(14.0f));
        harmonicResultLabel.setJustificationType(juce::Justification::topLeft);

        addAndMakeVisible(goldenRatioButton);
        goldenRatioButton.setButtonText("Golden Ratio Series (φ)");
        goldenRatioButton.onClick = [this] { calculateGoldenRatio(); };

        addAndMakeVisible(roomModesButton);
        roomModesButton.setButtonText("Room Modes (Standing Waves)");
        roomModesButton.onClick = [this] { calculateRoomModes(); };

        // === DYNAMIC PROCESSOR ===
        addAndMakeVisible(dynamicLabel);
        dynamicLabel.setText("🎛️ Dynamic Processor Calculator", juce::dontSendNotification);
        dynamicLabel.setColour(juce::Label::textColourId, juce::Colours::magenta);
        dynamicLabel.setFont(juce::Font(16.0f, juce::Font::bold));

        addAndMakeVisible(signalTypeCombo);
        signalTypeCombo.addItem("Vocals", 1);
        signalTypeCombo.addItem("Drums", 2);
        signalTypeCombo.addItem("Bass", 3);
        signalTypeCombo.addItem("Guitar", 4);
        signalTypeCombo.addItem("Mix Bus", 5);
        signalTypeCombo.addItem("Master", 6);
        signalTypeCombo.setSelectedId(1);  // Default: Vocals
        signalTypeCombo.onChange = [this] { calculateDynamics(); };

        addAndMakeVisible(signalLabel);
        signalLabel.setText("Signal Type:", juce::dontSendNotification);
        signalLabel.attachToComponent(&signalTypeCombo, true);

        addAndMakeVisible(dynamicResultLabel);
        dynamicResultLabel.setText("Settings: ---", juce::dontSendNotification);
        dynamicResultLabel.setColour(juce::Label::textColourId, juce::Colours::yellow);
        dynamicResultLabel.setFont(juce::Font(14.0f));
        dynamicResultLabel.setJustificationType(juce::Justification::topLeft);

        addAndMakeVisible(lufsButton);
        lufsButton.setButtonText("LUFS Targets (Streaming)");
        lufsButton.onClick = [this] { showLUFSTargets(); };

        // Initial calculations
        calculateDelayTime();
        analyzeHarmonics();
        calculateDynamics();
    }

    //==============================================================================
    void layoutDelaySection(juce::Rectangle<int> area)
    {
        delayLabel.setBounds(area.removeFromTop(25));
        area.removeFromTop(5);

        auto row1 = area.removeFromTop(30);
        row1.removeFromLeft(100);  // Label space
        bpmSlider.setBounds(row1);

        area.removeFromTop(5);
        auto row2 = area.removeFromTop(30);
        int comboWidth = row2.getWidth() / 2 - 5;
        noteDivisionCombo.setBounds(row2.removeFromLeft(comboWidth));
        row2.removeFromLeft(10);
        noteModifierCombo.setBounds(row2);

        area.removeFromTop(5);
        delayResultLabel.setBounds(area.removeFromTop(40));
        area.removeFromTop(5);
        haasButton.setBounds(area.removeFromTop(30));
    }

    void layoutHarmonicSection(juce::Rectangle<int> area)
    {
        harmonicLabel.setBounds(area.removeFromTop(25));
        area.removeFromTop(5);

        auto row1 = area.removeFromTop(30);
        row1.removeFromLeft(150);  // Label space
        fundamentalSlider.setBounds(row1);

        area.removeFromTop(5);
        harmonicResultLabel.setBounds(area.removeFromTop(60));

        area.removeFromTop(5);
        auto buttonRow = area.removeFromTop(30);
        int buttonWidth = buttonRow.getWidth() / 2 - 5;
        goldenRatioButton.setBounds(buttonRow.removeFromLeft(buttonWidth));
        buttonRow.removeFromLeft(10);
        roomModesButton.setBounds(buttonRow);
    }

    void layoutDynamicSection(juce::Rectangle<int> area)
    {
        dynamicLabel.setBounds(area.removeFromTop(25));
        area.removeFromTop(5);

        auto row1 = area.removeFromTop(30);
        row1.removeFromLeft(120);  // Label space
        signalTypeCombo.setBounds(row1);

        area.removeFromTop(5);
        dynamicResultLabel.setBounds(area.removeFromTop(60));

        area.removeFromTop(5);
        lufsButton.setBounds(area.removeFromTop(30));
    }

    //==============================================================================
    // DELAY CALCULATOR
    void calculateDelayTime()
    {
        float bpm = static_cast<float>(bpmSlider.getValue());

        // Get note division
        IntelligentDelayCalculator::NoteDivision division;
        switch (noteDivisionCombo.getSelectedId())
        {
            case 1: division = IntelligentDelayCalculator::NoteDivision::Whole; break;
            case 2: division = IntelligentDelayCalculator::NoteDivision::Half; break;
            case 3: division = IntelligentDelayCalculator::NoteDivision::Quarter; break;
            case 4: division = IntelligentDelayCalculator::NoteDivision::Eighth; break;
            case 5: division = IntelligentDelayCalculator::NoteDivision::Sixteenth; break;
            case 6: division = IntelligentDelayCalculator::NoteDivision::ThirtySecond; break;
            default: division = IntelligentDelayCalculator::NoteDivision::Quarter; break;
        }

        // Get modifier
        IntelligentDelayCalculator::NoteModifier modifier;
        switch (noteModifierCombo.getSelectedId())
        {
            case 1: modifier = IntelligentDelayCalculator::NoteModifier::Straight; break;
            case 2: modifier = IntelligentDelayCalculator::NoteModifier::Dotted; break;
            case 3: modifier = IntelligentDelayCalculator::NoteModifier::Triplet; break;
            default: modifier = IntelligentDelayCalculator::NoteModifier::Straight; break;
        }

        // Calculate
        float delayMs = IntelligentDelayCalculator::calculateDelayTime(bpm, division, modifier);

        delayResultLabel.setText("Delay: " + juce::String(delayMs, 1) + " ms",
                                juce::dontSendNotification);
    }

    void calculateHaasEffect()
    {
        juce::String message = "Haas Effect (Precedence Effect):\n\n";
        message += "1-5 ms: Tight stereo widening\n";
        message += "5-15 ms: Medium width (most natural)\n";
        message += "15-30 ms: Wide stereo image\n";
        message += "30-40 ms: Very wide (starts to sound like echo)\n";
        message += "> 40 ms: Perceived as distinct echo\n\n";

        float tightDelay = IntelligentDelayCalculator::calculateHaasDelay(0.2f);
        float mediumDelay = IntelligentDelayCalculator::calculateHaasDelay(0.5f);
        float wideDelay = IntelligentDelayCalculator::calculateHaasDelay(0.8f);

        message += "Recommended delays:\n";
        message += "Tight: " + juce::String(tightDelay, 1) + " ms\n";
        message += "Medium: " + juce::String(mediumDelay, 1) + " ms\n";
        message += "Wide: " + juce::String(wideDelay, 1) + " ms";

        juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::InfoIcon,
            "Haas Effect Calculator", message);
    }

    // HARMONIC ANALYZER
    void analyzeHarmonics()
    {
        float fundamental = static_cast<float>(fundamentalSlider.getValue());
        auto harmonics = HarmonicFrequencyAnalyzer::generateHarmonics(fundamental, 8, 1.0f);

        juce::String result = "Harmonics:\n";
        for (int i = 0; i < juce::jmin(8, static_cast<int>(harmonics.harmonics.size())); ++i)
        {
            result += juce::String(i + 1) + ": " +
                     juce::String(harmonics.harmonics[i], 1) + " Hz\n";
        }

        harmonicResultLabel.setText(result, juce::dontSendNotification);
    }

    void calculateGoldenRatio()
    {
        float fundamental = static_cast<float>(fundamentalSlider.getValue());
        auto series = HarmonicFrequencyAnalyzer::generateGoldenRatioSeries(fundamental, 6);

        juce::String message = "Golden Ratio Series (φ = 1.618...):\n\n";
        for (size_t i = 0; i < series.size(); ++i)
        {
            message += juce::String(i + 1) + ": " + juce::String(series[i], 1) + " Hz\n";
        }

        message += "\nUseful for spectral composition!";

        juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::InfoIcon,
            "Golden Ratio Frequencies", message);
    }

    void calculateRoomModes()
    {
        // Use default room dimensions (6m × 4m × 2.5m - typical studio)
        float length = 6.0f;
        float width = 4.0f;
        float height = 2.5f;

        auto modes = HarmonicFrequencyAnalyzer::calculateRoomModes(length, width, height);

        juce::String result = "Room Modes (Standing Waves):\n\n";
        result += "Room: " + juce::String(length, 1) + "×" +
                 juce::String(width, 1) + "×" +
                 juce::String(height, 1) + " m\n";
        result += "(Typical studio dimensions)\n\n";

        result += "First 10 axial modes:\n";
        for (int i = 0; i < juce::jmin(10, static_cast<int>(modes.size())); ++i)
        {
            result += juce::String(i + 1) + ": " + juce::String(modes[i], 1) + " Hz\n";
        }

        result += "\nThese frequencies may cause resonance!\nConsider bass traps at these frequencies.";

        juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::InfoIcon,
            "Room Mode Analysis", result);
    }

    // DYNAMIC PROCESSOR
    void calculateDynamics()
    {
        juce::String signalType = signalTypeCombo.getText();
        float bpm = static_cast<float>(bpmSlider.getValue());

        float attack = IntelligentDynamicProcessor::calculateOptimalAttack(signalType, 0.5f);
        float release = IntelligentDynamicProcessor::calculateOptimalRelease(bpm, signalType, true);
        float ratio = IntelligentDynamicProcessor::calculateOptimalRatio(signalType, 0.5f);

        juce::String result = "Optimal Settings:\n";
        result += "Attack: " + juce::String(attack, 1) + " ms\n";
        result += "Release: " + juce::String(release, 1) + " ms (tempo-synced)\n";
        result += "Ratio: " + juce::String(ratio, 1) + ":1\n";

        dynamicResultLabel.setText(result, juce::dontSendNotification);
    }

    void showLUFSTargets()
    {
        juce::String message = "LUFS Targets (Integrated Loudness):\n\n";
        message += "Spotify: " + juce::String(LoudnessCalculator::getTargetLUFS("Spotify"), 1) + " LUFS\n";
        message += "YouTube: " + juce::String(LoudnessCalculator::getTargetLUFS("YouTube"), 1) + " LUFS\n";
        message += "Apple Music: " + juce::String(LoudnessCalculator::getTargetLUFS("Apple Music"), 1) + " LUFS\n";
        message += "Broadcast (EBU R128): " + juce::String(LoudnessCalculator::getTargetLUFS("Broadcast TV"), 1) + " LUFS\n";
        message += "CD (Loud): " + juce::String(LoudnessCalculator::getTargetLUFS("CD Mastering (Loud)"), 1) + " LUFS\n";
        message += "CD (Dynamic): " + juce::String(LoudnessCalculator::getTargetLUFS("CD Mastering (Dynamic)"), 1) + " LUFS\n\n";

        message += "Limiting Ceiling:\n";
        message += "Streaming: " + juce::String(LoudnessCalculator::getLimitingCeiling("Streaming"), 1) + " dBTP\n";
        message += "CD: " + juce::String(LoudnessCalculator::getLimitingCeiling("CD"), 1) + " dBTP";

        juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::InfoIcon,
            "LUFS Targets & Limiting", message);
    }

    //==============================================================================
    // Delay Calculator UI
    juce::Label delayLabel;
    juce::Slider bpmSlider;
    juce::Label bpmLabel;
    juce::ComboBox noteDivisionCombo;
    juce::ComboBox noteModifierCombo;
    juce::Label delayResultLabel;
    juce::TextButton haasButton;

    // Harmonic Analyzer UI
    juce::Label harmonicLabel;
    juce::Slider fundamentalSlider;
    juce::Label fundamentalLabel;
    juce::Label harmonicResultLabel;
    juce::TextButton goldenRatioButton;
    juce::TextButton roomModesButton;

    // Dynamic Processor UI
    juce::Label dynamicLabel;
    juce::ComboBox signalTypeCombo;
    juce::Label signalLabel;
    juce::Label dynamicResultLabel;
    juce::TextButton lufsButton;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CreativeToolsPanel)
};
