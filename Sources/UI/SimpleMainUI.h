#pragma once

#include <JuceHeader.h>
#include "../Visualization/AudioVisualizers.h"
#include "../Visualization/BioDataVisualizer.h"
#include "../Visualization/FrequencyColorTranslator.h"
#include "../Visualization/EMSpectrumAnalyzer.h"
#include "../BioData/BioReactiveModulator.h"
#include "BioFeedbackDashboard.h"
#include "WellnessControlPanel.h"
#include "CreativeToolsPanel.h"

//==============================================================================
/**
 * @brief Main UI for Echoelmusic with Audio Visualizers
 *
 * Features:
 * - Real-time waveform display
 * - FFT spectrum analyzer
 * - Audio-reactive particle system
 * - 60 FPS rendering
 */
class SimpleMainUI : public juce::Component
{
public:
    SimpleMainUI()
    {
        // Title
        addAndMakeVisible(titleLabel);
        titleLabel.setText("Echoelmusic DAW", juce::dontSendNotification);
        titleLabel.setJustificationType(juce::Justification::centred);
        titleLabel.setFont(juce::Font(32.0f, juce::Font::bold));
        titleLabel.setColour(juce::Label::textColourId, juce::Colour(0xff00d4ff));

        // Info
        addAndMakeVisible(infoLabel);
        infoLabel.setText("80+ Professional Audio Tools | Phase 4F Complete",
                         juce::dontSendNotification);
        titleLabel.setJustificationType(juce::Justification::centred);
        infoLabel.setFont(juce::Font(14.0f));
        infoLabel.setColour(juce::Label::textColourId, juce::Colours::white.withAlpha(0.7f));

        // Wellness & Creative Tools Buttons
        addAndMakeVisible(bioFeedbackButton);
        bioFeedbackButton.setButtonText("Bio-Feedback Dashboard");
        bioFeedbackButton.setColour(juce::TextButton::buttonColourId, juce::Colour(0xffff4444));
        bioFeedbackButton.onClick = [this]() { openBioFeedbackWindow(); };

        addAndMakeVisible(wellnessButton);
        wellnessButton.setButtonText("Wellness Controls");
        wellnessButton.setColour(juce::TextButton::buttonColourId, juce::Colour(0xff44ff44));
        wellnessButton.onClick = [this]() { openWellnessWindow(); };

        addAndMakeVisible(creativeToolsButton);
        creativeToolsButton.setButtonText("Creative Tools");
        creativeToolsButton.setColour(juce::TextButton::buttonColourId, juce::Colour(0xff4444ff));
        creativeToolsButton.onClick = [this]() { openCreativeToolsWindow(); };

        // Create visualizers
        waveformVisualizer = std::make_unique<WaveformVisualizer>();
        addAndMakeVisible(waveformVisualizer.get());

        spectrumAnalyzer = std::make_unique<SpectrumAnalyzer>();
        addAndMakeVisible(spectrumAnalyzer.get());

        particleSystem = std::make_unique<ParticleSystem>();
        addAndMakeVisible(particleSystem.get());

        // Color spectrum analyzer (frequency-to-color translation)
        colorSpectrumAnalyzer = std::make_unique<ColorSpectrumAnalyzer>();
        addAndMakeVisible(colorSpectrumAnalyzer.get());

        // Bio-data visualizer
        bioDataVisualizer = std::make_unique<BioDataVisualizer>();
        addAndMakeVisible(bioDataVisualizer.get());

        // Breathing pacer
        breathingPacer = std::make_unique<BreathingPacer>();
        addAndMakeVisible(breathingPacer.get());

        // Bio-feedback system (simulation mode enabled by default in constructor)
        bioFeedbackSystem = std::make_unique<BioFeedbackSystem>();

        // Visualizer labels
        addAndMakeVisible(waveformLabel);
        waveformLabel.setText("Waveform", juce::dontSendNotification);
        waveformLabel.setJustificationType(juce::Justification::centredLeft);
        waveformLabel.setFont(juce::Font(12.0f, juce::Font::bold));
        waveformLabel.setColour(juce::Label::textColourId, juce::Colour(0xff00d4ff));

        addAndMakeVisible(spectrumLabel);
        spectrumLabel.setText("Spectrum Analyzer", juce::dontSendNotification);
        spectrumLabel.setJustificationType(juce::Justification::centredLeft);
        spectrumLabel.setFont(juce::Font(12.0f, juce::Font::bold));
        spectrumLabel.setColour(juce::Label::textColourId, juce::Colour(0xff00d4ff));

        addAndMakeVisible(particleLabel);
        particleLabel.setText("Audio-Reactive Particles", juce::dontSendNotification);
        particleLabel.setJustificationType(juce::Justification::centredLeft);
        particleLabel.setFont(juce::Font(12.0f, juce::Font::bold));
        particleLabel.setColour(juce::Label::textColourId, juce::Colour(0xff00d4ff));

        addAndMakeVisible(colorSpectrumLabel);
        colorSpectrumLabel.setText("Frequency → Color Translation (Physics-Based)", juce::dontSendNotification);
        colorSpectrumLabel.setJustificationType(juce::Justification::centredLeft);
        colorSpectrumLabel.setFont(juce::Font(12.0f, juce::Font::bold));
        colorSpectrumLabel.setColour(juce::Label::textColourId, juce::Colour(0xffffaa00));

        addAndMakeVisible(bioDataLabel);
        bioDataLabel.setText("Bio-Data Monitor", juce::dontSendNotification);
        bioDataLabel.setJustificationType(juce::Justification::centredLeft);
        bioDataLabel.setFont(juce::Font(12.0f, juce::Font::bold));
        bioDataLabel.setColour(juce::Label::textColourId, juce::Colour(0xffff4444));

        addAndMakeVisible(breathingLabel);
        breathingLabel.setText("Coherence Training", juce::dontSendNotification);
        breathingLabel.setJustificationType(juce::Justification::centredLeft);
        breathingLabel.setFont(juce::Font(12.0f, juce::Font::bold));
        breathingLabel.setColour(juce::Label::textColourId, juce::Colour(0xffff4444));

        setSize(1200, 800);
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xff0a0a0f));

        // Subtle vignette effect
        juce::ColourGradient vignette(
            juce::Colour(0xff0a0a0f).withAlpha(0.0f), getWidth() / 2.0f, getHeight() / 2.0f,
            juce::Colours::black, 0, 0, true
        );
        g.setGradientFill(vignette);
        g.fillAll();
    }

    void resized() override
    {
        auto bounds = getLocalBounds();
        const int margin = 20;

        // Title at top
        titleLabel.setBounds(bounds.removeFromTop(50).reduced(margin, 10));
        infoLabel.setBounds(bounds.removeFromTop(25).reduced(margin, 0));

        // Toolbar buttons
        auto toolbar = bounds.removeFromTop(40).reduced(margin, 5);
        const int buttonWidth = (toolbar.getWidth() - 20) / 3;  // 3 buttons with spacing
        bioFeedbackButton.setBounds(toolbar.removeFromLeft(buttonWidth));
        toolbar.removeFromLeft(10);
        wellnessButton.setBounds(toolbar.removeFromLeft(buttonWidth));
        toolbar.removeFromLeft(10);
        creativeToolsButton.setBounds(toolbar.removeFromLeft(buttonWidth));

        bounds.removeFromTop(margin);

        // Split into left (audio visualizers) and right (bio-data) panels
        auto bioPanel = bounds.removeFromRight(bounds.getWidth() / 3);  // Right 1/3 for bio-data
        auto audioPanel = bounds;

        // ===== Audio Visualizers (Left 2/3) =====
        // Layout visualizers in 4 rows
        auto row1 = audioPanel.removeFromTop((audioPanel.getHeight() - margin * 3) / 4);
        auto row2 = audioPanel.removeFromTop((audioPanel.getHeight() - margin * 2) / 3);
        auto row3 = audioPanel.removeFromTop((audioPanel.getHeight() - margin) / 2);
        auto row4 = audioPanel;

        // Waveform (row 1)
        waveformLabel.setBounds(row1.removeFromTop(20).reduced(margin, 0));
        waveformVisualizer->setBounds(row1.reduced(margin, 5));

        // Spectrum (row 2)
        row2.removeFromTop(margin);
        spectrumLabel.setBounds(row2.removeFromTop(20).reduced(margin, 0));
        spectrumAnalyzer->setBounds(row2.reduced(margin, 5));

        // Color Spectrum (row 3)
        row3.removeFromTop(margin);
        colorSpectrumLabel.setBounds(row3.removeFromTop(20).reduced(margin, 0));
        colorSpectrumAnalyzer->setBounds(row3.reduced(margin, 5));

        // Particles (row 4)
        row4.removeFromTop(margin);
        particleLabel.setBounds(row4.removeFromTop(20).reduced(margin, 0));
        particleSystem->setBounds(row4.reduced(margin, 5));

        // ===== Bio-Data Panel (Right 1/3) =====
        bioPanel.removeFromLeft(margin);  // Left margin

        // Bio-data visualizer (top 60%)
        auto bioTop = bioPanel.removeFromTop(bioPanel.getHeight() * 0.6f);
        bioDataLabel.setBounds(bioTop.removeFromTop(20).reduced(margin, 0));
        bioDataVisualizer->setBounds(bioTop.reduced(margin, 5));

        // Breathing pacer (bottom 40%)
        bioPanel.removeFromTop(margin);
        breathingLabel.setBounds(bioPanel.removeFromTop(20).reduced(margin, 0));
        breathingPacer->setBounds(bioPanel.reduced(margin, 5));
    }

    void prepareToPlay(double, int) {}

    /**
     * @brief Apply bio-reactive modulation to audio buffer
     * Uses HRV coherence, breathing rate, and stress level to modulate audio
     */
    void applyBioModulation(const BioReactiveModulator::ModulatedParameters& params,
                            juce::AudioBuffer<float>& buffer)
    {
        const int numChannels = buffer.getNumChannels();
        const int numSamples = buffer.getNumSamples();

        // Apply gain modulation based on coherence (calm = stable, stressed = subtle ducking)
        float gainMod = juce::jmap(params.filterCutoff, 200.0f, 8000.0f, 0.85f, 1.0f);

        // Apply subtle stereo width modulation based on relaxation
        float stereoWidth = juce::jmap(params.reverbMix, 0.0f, 0.6f, 0.8f, 1.2f);

        for (int channel = 0; channel < numChannels; ++channel)
        {
            float* data = buffer.getWritePointer(channel);

            // Apply gain modulation
            for (int sample = 0; sample < numSamples; ++sample)
            {
                data[sample] *= gainMod;
            }

            // Apply stereo width (M/S processing for stereo)
            if (numChannels == 2 && channel == 0)
            {
                float* left = buffer.getWritePointer(0);
                float* right = buffer.getWritePointer(1);

                for (int sample = 0; sample < numSamples; ++sample)
                {
                    float mid = (left[sample] + right[sample]) * 0.5f;
                    float side = (left[sample] - right[sample]) * 0.5f * stereoWidth;
                    left[sample] = mid + side;
                    right[sample] = mid - side;
                }
            }
        }
    }

    void processBlock(juce::AudioBuffer<float>& buffer)
    {
        // Push audio data to all visualizers
        if (waveformVisualizer)
            waveformVisualizer->pushAudioData(buffer);

        if (spectrumAnalyzer)
            spectrumAnalyzer->pushAudioData(buffer);

        if (particleSystem)
            particleSystem->pushAudioData(buffer);

        if (colorSpectrumAnalyzer)
            colorSpectrumAnalyzer->pushAudioData(buffer);

        // Update bio-feedback system
        if (bioFeedbackSystem)
        {
            // Update bio-feedback system (processes bio-data)
            bioFeedbackSystem->update();

            // Get current bio-data sample
            auto bioSample = bioFeedbackSystem->getCurrentBioData();

            // Update bio-data visualizer
            if (bioDataVisualizer)
                bioDataVisualizer->updateBioData(bioSample);

            // Get modulated parameters and apply to audio processing
            auto modulatedParams = bioFeedbackSystem->getModulatedParameters();
            applyBioModulation(modulatedParams, buffer);
        }
    }

    //==============================================================================
    // Window opening methods
    void openBioFeedbackWindow()
    {
        if (bioFeedbackWindow == nullptr)
        {
            auto* dashboard = new BioFeedbackDashboard();
            dashboard->setSize(900, 600);

            bioFeedbackWindow = std::make_unique<juce::DocumentWindow>(
                "Bio-Feedback Dashboard",
                juce::Colour(0xff0a0a0a),
                juce::DocumentWindow::closeButton | juce::DocumentWindow::minimiseButton
            );

            bioFeedbackWindow->setContentOwned(dashboard, true);
            bioFeedbackWindow->setResizable(true, false);
            bioFeedbackWindow->centreWithSize(900, 600);
            bioFeedbackWindow->setVisible(true);
        }
        else
        {
            bioFeedbackWindow->toFront(true);
        }
    }

    void openWellnessWindow()
    {
        if (wellnessWindow == nullptr)
        {
            auto* wellness = new WellnessControlPanel();
            wellness->setSize(800, 700);

            wellnessWindow = std::make_unique<juce::DocumentWindow>(
                "Wellness Controls (AVE + Color Light + Vibrotherapy)",
                juce::Colour(0xff0a0a0a),
                juce::DocumentWindow::closeButton | juce::DocumentWindow::minimiseButton
            );

            wellnessWindow->setContentOwned(wellness, true);
            wellnessWindow->setResizable(true, false);
            wellnessWindow->centreWithSize(800, 700);
            wellnessWindow->setVisible(true);
        }
        else
        {
            wellnessWindow->toFront(true);
        }
    }

    void openCreativeToolsWindow()
    {
        if (creativeToolsWindow == nullptr)
        {
            auto* tools = new CreativeToolsPanel();
            tools->setSize(700, 650);

            creativeToolsWindow = std::make_unique<juce::DocumentWindow>(
                "Creative Tools (Studio Calculator Suite)",
                juce::Colour(0xff0a0a0a),
                juce::DocumentWindow::closeButton | juce::DocumentWindow::minimiseButton
            );

            creativeToolsWindow->setContentOwned(tools, true);
            creativeToolsWindow->setResizable(true, false);
            creativeToolsWindow->centreWithSize(700, 650);
            creativeToolsWindow->setVisible(true);
        }
        else
        {
            creativeToolsWindow->toFront(true);
        }
    }

private:
    juce::Label titleLabel;
    juce::Label infoLabel;

    // Toolbar buttons
    juce::TextButton bioFeedbackButton;
    juce::TextButton wellnessButton;
    juce::TextButton creativeToolsButton;

    // Separate windows for wellness/creative tools
    std::unique_ptr<juce::DocumentWindow> bioFeedbackWindow;
    std::unique_ptr<juce::DocumentWindow> wellnessWindow;
    std::unique_ptr<juce::DocumentWindow> creativeToolsWindow;

    juce::Label waveformLabel;
    juce::Label spectrumLabel;
    juce::Label particleLabel;
    juce::Label colorSpectrumLabel;
    juce::Label bioDataLabel;
    juce::Label breathingLabel;

    std::unique_ptr<WaveformVisualizer> waveformVisualizer;
    std::unique_ptr<SpectrumAnalyzer> spectrumAnalyzer;
    std::unique_ptr<ParticleSystem> particleSystem;
    std::unique_ptr<ColorSpectrumAnalyzer> colorSpectrumAnalyzer;
    std::unique_ptr<BioDataVisualizer> bioDataVisualizer;
    std::unique_ptr<BreathingPacer> breathingPacer;

    std::unique_ptr<BioFeedbackSystem> bioFeedbackSystem;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SimpleMainUI)
};
