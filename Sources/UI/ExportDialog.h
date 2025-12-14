#pragma once

#include <JuceHeader.h>
#include "../Audio/AudioExporter.h"

/**
 * ExportDialog - UI for audio export settings
 *
 * Features:
 * - Format selection (WAV, FLAC, OGG)
 * - Sample rate selection
 * - Bit depth selection
 * - Normalization settings (LUFS)
 * - Metadata input
 * - Progress display
 * - File chooser
 */
class ExportDialog : public juce::Component,
                     public juce::Button::Listener,
                     public juce::ComboBox::Listener
{
public:
    //==========================================================================
    ExportDialog(AudioExporter& exporter)
        : audioExporter(exporter)
    {
        // Title
        addAndMakeVisible(titleLabel);
        titleLabel.setText("Export Audio", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(24.0f, juce::Font::bold));
        titleLabel.setColour(juce::Label::textColourId, juce::Colour(0xff00d4ff));

        // Format
        addAndMakeVisible(formatLabel);
        formatLabel.setText("Format:", juce::dontSendNotification);

        addAndMakeVisible(formatCombo);
        formatCombo.addItem("WAV (Uncompressed)", 1);
        formatCombo.addItem("FLAC (Lossless)", 2);
        formatCombo.addItem("OGG Vorbis (Lossy)", 3);
        formatCombo.setSelectedId(1);
        formatCombo.addListener(this);

        // Sample Rate
        addAndMakeVisible(sampleRateLabel);
        sampleRateLabel.setText("Sample Rate:", juce::dontSendNotification);

        addAndMakeVisible(sampleRateCombo);
        sampleRateCombo.addItem("44.1 kHz", 1);
        sampleRateCombo.addItem("48 kHz", 2);
        sampleRateCombo.addItem("88.2 kHz", 3);
        sampleRateCombo.addItem("96 kHz", 4);
        sampleRateCombo.setSelectedId(2);  // Default 48kHz

        // Bit Depth
        addAndMakeVisible(bitDepthLabel);
        bitDepthLabel.setText("Bit Depth:", juce::dontSendNotification);

        addAndMakeVisible(bitDepthCombo);
        bitDepthCombo.addItem("16-bit", 1);
        bitDepthCombo.addItem("24-bit", 2);
        bitDepthCombo.addItem("32-bit Float", 3);
        bitDepthCombo.setSelectedId(2);  // Default 24-bit

        // Normalization
        addAndMakeVisible(normalizeToggle);
        normalizeToggle.setButtonText("Normalize to LUFS");
        normalizeToggle.setToggleState(false, juce::dontSendNotification);

        addAndMakeVisible(lufsLabel);
        lufsLabel.setText("Target LUFS:", juce::dontSendNotification);

        addAndMakeVisible(lufsSlider);
        lufsSlider.setRange(-23.0, -6.0, 0.1);
        lufsSlider.setValue(-14.0);  // Spotify default
        lufsSlider.setTextValueSuffix(" LUFS");

        // Metadata
        addAndMakeVisible(metadataLabel);
        metadataLabel.setText("Metadata (Optional)", juce::dontSendNotification);
        metadataLabel.setFont(juce::Font(16.0f, juce::Font::bold));

        addAndMakeVisible(titleTextLabel);
        titleTextLabel.setText("Title:", juce::dontSendNotification);
        addAndMakeVisible(titleEditor);

        addAndMakeVisible(artistLabel);
        artistLabel.setText("Artist:", juce::dontSendNotification);
        addAndMakeVisible(artistEditor);

        // Buttons
        addAndMakeVisible(exportButton);
        exportButton.setButtonText("Export");
        exportButton.setColour(juce::TextButton::buttonColourId, juce::Colour(0xff44ff44));
        exportButton.addListener(this);

        addAndMakeVisible(cancelButton);
        cancelButton.setButtonText("Cancel");
        cancelButton.addListener(this);

        // Progress
        addAndMakeVisible(progressBar);
        progressBar.setColour(juce::ProgressBar::foregroundColourId, juce::Colour(0xff00d4ff));

        addAndMakeVisible(statusLabel);
        statusLabel.setText("Ready to export", juce::dontSendNotification);
        statusLabel.setJustificationType(juce::Justification::centred);

        setSize(500, 600);
    }

    ~ExportDialog() override
    {
        formatCombo.removeListener(this);
        exportButton.removeListener(this);
        cancelButton.removeListener(this);
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xff1a1a1f));

        // Border
        g.setColour(juce::Colour(0xff00d4ff));
        g.drawRect(getLocalBounds(), 2);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(20);

        // Title
        titleLabel.setBounds(bounds.removeFromTop(40));
        bounds.removeFromTop(10);

        // Format
        auto formatRow = bounds.removeFromTop(30);
        formatLabel.setBounds(formatRow.removeFromLeft(120));
        formatCombo.setBounds(formatRow);
        bounds.removeFromTop(10);

        // Sample Rate
        auto sampleRateRow = bounds.removeFromTop(30);
        sampleRateLabel.setBounds(sampleRateRow.removeFromLeft(120));
        sampleRateCombo.setBounds(sampleRateRow);
        bounds.removeFromTop(10);

        // Bit Depth
        auto bitDepthRow = bounds.removeFromTop(30);
        bitDepthLabel.setBounds(bitDepthRow.removeFromLeft(120));
        bitDepthCombo.setBounds(bitDepthRow);
        bounds.removeFromTop(10);

        // Normalization
        normalizeToggle.setBounds(bounds.removeFromTop(30));
        bounds.removeFromTop(5);

        auto lufsRow = bounds.removeFromTop(30);
        lufsLabel.setBounds(lufsRow.removeFromLeft(120));
        lufsSlider.setBounds(lufsRow);
        bounds.removeFromTop(20);

        // Metadata
        metadataLabel.setBounds(bounds.removeFromTop(25));
        bounds.removeFromTop(10);

        auto titleRow = bounds.removeFromTop(30);
        titleTextLabel.setBounds(titleRow.removeFromLeft(120));
        titleEditor.setBounds(titleRow);
        bounds.removeFromTop(10);

        auto artistRow = bounds.removeFromTop(30);
        artistLabel.setBounds(artistRow.removeFromLeft(120));
        artistEditor.setBounds(artistRow);
        bounds.removeFromTop(30);

        // Progress
        progressBar.setBounds(bounds.removeFromTop(20));
        bounds.removeFromTop(10);
        statusLabel.setBounds(bounds.removeFromTop(25));
        bounds.removeFromTop(20);

        // Buttons
        auto buttonRow = bounds.removeFromTop(40);
        cancelButton.setBounds(buttonRow.removeFromLeft(buttonRow.getWidth() / 2).reduced(5));
        exportButton.setBounds(buttonRow.reduced(5));
    }

    void buttonClicked(juce::Button* button) override
    {
        if (button == &exportButton)
        {
            showFileChooserAndExport();
        }
        else if (button == &cancelButton)
        {
            if (auto* parent = findParentComponentOfClass<juce::DialogWindow>())
                parent->exitModalState(0);
        }
    }

    void comboBoxChanged(juce::ComboBox* combo) override
    {
        // Update UI based on format
        if (combo == &formatCombo)
        {
            // OGG doesn't support 32-bit float
            if (formatCombo.getSelectedId() == 3)  // OGG
            {
                if (bitDepthCombo.getSelectedId() == 3)  // 32-bit
                    bitDepthCombo.setSelectedId(2);  // Change to 24-bit
            }
        }
    }

private:
    void showFileChooserAndExport()
    {
        // Get format
        juce::String format;
        switch (formatCombo.getSelectedId())
        {
            case 1: format = "WAV"; break;
            case 2: format = "FLAC"; break;
            case 3: format = "OGG"; break;
            default: format = "WAV";
        }

        juce::String extension = AudioExporter::getFileExtension(format);

        fileChooser = std::make_unique<juce::FileChooser>(
            "Export Audio File",
            juce::File::getSpecialLocation(juce::File::userMusicDirectory),
            "*" + extension
        );

        auto flags = juce::FileBrowserComponent::saveMode |
                    juce::FileBrowserComponent::canSelectFiles;

        fileChooser->launchAsync(flags, [this, format, extension](const juce::FileChooser& fc)
        {
            auto file = fc.getResult();

            if (file == juce::File())
                return;

            // Ensure correct extension
            if (!file.hasFileExtension(extension))
                file = file.withFileExtension(extension);

            // Build export settings
            AudioExporter::ExportSettings settings;
            settings.outputFile = file;
            settings.format = format;

            // Sample rate
            switch (sampleRateCombo.getSelectedId())
            {
                case 1: settings.sampleRate = 44100.0; break;
                case 2: settings.sampleRate = 48000.0; break;
                case 3: settings.sampleRate = 88200.0; break;
                case 4: settings.sampleRate = 96000.0; break;
            }

            // Bit depth
            switch (bitDepthCombo.getSelectedId())
            {
                case 1: settings.bitDepth = 16; break;
                case 2: settings.bitDepth = 24; break;
                case 3: settings.bitDepth = 32; break;
            }

            // Normalization
            settings.normalize = normalizeToggle.getToggleState();
            settings.targetLUFS = static_cast<float>(lufsSlider.getValue());

            // Metadata
            settings.title = titleEditor.getText();
            settings.artist = artistEditor.getText();

            // Trigger export via callback
            if (onExportRequested) {
                onExportRequested(settings);
                juce::AlertWindow::showMessageBoxAsync(
                    juce::AlertWindow::InfoIcon,
                    "Export Started",
                    "Exporting to: " + settings.outputPath.getFullPathName()
                );
            }

            // Close dialog
            if (auto* parent = findParentComponentOfClass<juce::DialogWindow>())
                parent->exitModalState(1);
        });
    }

    AudioExporter& audioExporter;

    juce::Label titleLabel;

    juce::Label formatLabel;
    juce::ComboBox formatCombo;

    juce::Label sampleRateLabel;
    juce::ComboBox sampleRateCombo;

    juce::Label bitDepthLabel;
    juce::ComboBox bitDepthCombo;

    juce::ToggleButton normalizeToggle;
    juce::Label lufsLabel;
    juce::Slider lufsSlider;

    juce::Label metadataLabel;
    juce::Label titleTextLabel;
    juce::TextEditor titleEditor;
    juce::Label artistLabel;
    juce::TextEditor artistEditor;

    juce::TextButton exportButton;
    juce::TextButton cancelButton;

    juce::ProgressBar progressBar{progress};
    juce::Label statusLabel;

    double progress = 0.0;

    std::unique_ptr<juce::FileChooser> fileChooser;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ExportDialog)
};
