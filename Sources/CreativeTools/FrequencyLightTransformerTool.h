#pragma once

#include <JuceHeader.h>
#include "../Visualization/ScientificFrequencyLightTransformer.h"
#include "../Visualization/FrequencyLightTransformerUI.h"
#include "../Visualization/FrequencyLightExporter.h"

//==============================================================================
/**
 * @brief FREQUENCY-TO-LIGHT TRANSFORMER - CREATIVE TOOL
 *
 * 🌈 Transform audio frequencies to light through mathematical octave shifting! 🔬
 *
 * **UNIQUE ECHOELMUSIC SKILL:**
 * - Real-time FFT analysis
 * - Scientific octave-based frequency transformation
 * - CIE 1931 color science
 * - OSC/DMX/JSON export
 * - Integration with visual systems
 *
 * **USE CASES:**
 * - Live VJ performances (Resolume, TouchDesigner)
 * - Stage lighting control (DMX/Art-Net)
 * - Scientific audio visualization
 * - Music therapy / color therapy research
 * - Audio-reactive installations
 *
 * @author Echoelmusic Science Team
 * @version 1.0.0
 */
class FrequencyLightTransformerTool : public juce::Component,
                                       public juce::AudioSource
{
public:
    //==============================================================================
    FrequencyLightTransformerTool()
    {
        // Add UI component
        addAndMakeVisible(transformerUI);

        // Export controls
        addAndMakeVisible(exportButton);
        exportButton.setButtonText("Export JSON");
        exportButton.onClick = [this] { exportToJSON(); };

        addAndMakeVisible(oscToggle);
        oscToggle.setButtonText("Enable OSC Output");
        oscToggle.onClick = [this] { oscEnabled = oscToggle.getToggleState(); };

        addAndMakeVisible(dmxToggle);
        dmxToggle.setButtonText("Enable DMX/Art-Net Output");
        dmxToggle.onClick = [this] { dmxEnabled = dmxToggle.getToggleState(); };

        // Manual frequency control
        addAndMakeVisible(frequencySlider);
        frequencySlider.setRange(20.0, 20000.0, 0.1);
        frequencySlider.setValue(440.0);
        frequencySlider.setSkewFactorFromMidPoint(1000.0);
        frequencySlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 100, 20);
        frequencySlider.onValueChange = [this]
        {
            transformerUI.setFrequency(frequencySlider.getValue());
        };

        addAndMakeVisible(frequencyLabel);
        frequencyLabel.setText("Manual Frequency Control (Hz):", juce::dontSendNotification);
        frequencyLabel.attachToComponent(&frequencySlider, true);

        // Info label
        addAndMakeVisible(infoLabel);
        infoLabel.setText("🌈 SCIENTIFIC FREQUENCY → LIGHT TRANSFORMER 🔬\n"
                         "Physics-based octave transformation (f × 2^n)",
                         juce::dontSendNotification);
        infoLabel.setJustificationType(juce::Justification::centred);
        infoLabel.setFont(juce::Font(16.0f, juce::Font::bold));

        setSize(900, 750);
    }

    ~FrequencyLightTransformerTool() override = default;

    //==============================================================================
    // AUDIO SOURCE INTERFACE
    //==============================================================================

    void prepareToPlay(int samplesPerBlockExpected, double sampleRate) override
    {
        currentSampleRate = sampleRate;
        juce::ignoreUnused(samplesPerBlockExpected);
    }

    void releaseResources() override
    {
        // Nothing to release
    }

    void getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill) override
    {
        // Clear output (this tool is visualization-only, not an audio effect)
        bufferToFill.clearActiveBufferRegion();

        // Process audio for visualization
        if (bufferToFill.buffer != nullptr)
        {
            transformerUI.processAudioBuffer(*bufferToFill.buffer);

            // Export if enabled
            if (oscEnabled || dmxEnabled)
            {
                auto transform = transformerUI.getCurrentTransform();

                if (oscEnabled)
                    FrequencyLightExporter::sendOSC(transform, oscHost, oscPort);

                if (dmxEnabled)
                {
                    auto dmxPacket = FrequencyLightExporter::createDMXPacket(transform);
                    FrequencyLightExporter::sendArtNet(dmxPacket, artNetHost, artNetPort);
                }
            }
        }
    }

    //==============================================================================
    // COMPONENT OVERRIDES
    //==============================================================================

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xff0a0a0f));
    }

    void resized() override
    {
        auto area = getLocalBounds();

        // Info label at top
        infoLabel.setBounds(area.removeFromTop(50).reduced(10));

        // Export controls
        auto controlArea = area.removeFromTop(40).reduced(10);
        exportButton.setBounds(controlArea.removeFromLeft(150));
        controlArea.removeFromLeft(10);
        oscToggle.setBounds(controlArea.removeFromLeft(180));
        controlArea.removeFromLeft(10);
        dmxToggle.setBounds(controlArea.removeFromLeft(220));

        // Manual frequency control
        auto sliderArea = area.removeFromTop(80).reduced(10);
        frequencySlider.setBounds(sliderArea.removeFromLeft(sliderArea.getWidth() - 200).withTrimmedLeft(200));

        // Main UI
        transformerUI.setBounds(area.reduced(10));
    }

    //==============================================================================
    // EXPORT METHODS
    //==============================================================================

    void exportToJSON()
    {
        auto transform = transformerUI.getCurrentTransform();

        juce::FileChooser chooser("Save Frequency-to-Light Data",
                                  juce::File::getSpecialLocation(juce::File::userDocumentsDirectory),
                                  "*.json");

        if (chooser.browseForFileToSave(true))
        {
            auto file = chooser.getResult();
            if (FrequencyLightExporter::saveJSON(transform, file))
            {
                juce::AlertWindow::showMessageBoxAsync(
                    juce::AlertWindow::InfoIcon,
                    "Export Successful",
                    "Frequency-to-light data exported to:\n" + file.getFullPathName());
            }
        }
    }

    void exportToCSV(const std::vector<ScientificFrequencyLightTransformer::TransformationResult>& dataPoints)
    {
        juce::FileChooser chooser("Save CSV Data",
                                  juce::File::getSpecialLocation(juce::File::userDocumentsDirectory),
                                  "*.csv");

        if (chooser.browseForFileToSave(true))
        {
            auto file = chooser.getResult();
            if (FrequencyLightExporter::saveCSV(dataPoints, file))
            {
                juce::AlertWindow::showMessageBoxAsync(
                    juce::AlertWindow::InfoIcon,
                    "Export Successful",
                    "CSV data exported to:\n" + file.getFullPathName());
            }
        }
    }

    //==============================================================================
    // SETTINGS
    //==============================================================================

    void setOSCSettings(const juce::String& host, int port)
    {
        oscHost = host;
        oscPort = port;
    }

    void setArtNetSettings(const juce::String& host, int port)
    {
        artNetHost = host;
        artNetPort = port;
    }

private:
    //==============================================================================
    // UI COMPONENTS
    //==============================================================================

    FrequencyLightTransformerUI transformerUI;

    juce::TextButton exportButton;
    juce::ToggleButton oscToggle;
    juce::ToggleButton dmxToggle;

    juce::Slider frequencySlider;
    juce::Label frequencyLabel;
    juce::Label infoLabel;

    //==============================================================================
    // EXPORT SETTINGS
    //==============================================================================

    bool oscEnabled = false;
    bool dmxEnabled = false;

    juce::String oscHost = "127.0.0.1";
    int oscPort = 7000;

    juce::String artNetHost = "127.0.0.1";
    int artNetPort = 6454;

    double currentSampleRate = 44100.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FrequencyLightTransformerTool)
};
