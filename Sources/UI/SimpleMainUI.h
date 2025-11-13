#pragma once

#include <JuceHeader.h>
#include "../Visualization/AudioVisualizers.h"
#include "../Visualization/BioDataVisualizer.h"
#include "../Visualization/FrequencyColorTranslator.h"
#include "../Visualization/EMSpectrumAnalyzer.h"
#include "../BioData/BioReactiveModulator.h"

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

            // Get modulated parameters (for future audio processing)
            auto modulatedParams = bioFeedbackSystem->getModulatedParameters();
            // TODO: Apply modulatedParams to audio processing in Phase 2
        }
    }

private:
    juce::Label titleLabel;
    juce::Label infoLabel;

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
