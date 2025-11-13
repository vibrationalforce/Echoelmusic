#pragma once

#include <JuceHeader.h>
#include "../Visualization/AudioVisualizers.h"

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

        // Layout visualizers in 3 rows
        auto topRow = bounds.removeFromTop((bounds.getHeight() - margin * 2) / 3);
        auto middleRow = bounds.removeFromTop((bounds.getHeight() - margin) / 2);
        auto bottomRow = bounds;

        // Waveform (top)
        waveformLabel.setBounds(topRow.removeFromTop(20).reduced(margin, 0));
        waveformVisualizer->setBounds(topRow.reduced(margin, 5));

        // Spectrum (middle)
        middleRow.removeFromTop(margin);
        spectrumLabel.setBounds(middleRow.removeFromTop(20).reduced(margin, 0));
        spectrumAnalyzer->setBounds(middleRow.reduced(margin, 5));

        // Particles (bottom)
        bottomRow.removeFromTop(margin);
        particleLabel.setBounds(bottomRow.removeFromTop(20).reduced(margin, 0));
        particleSystem->setBounds(bottomRow.reduced(margin, 5));
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
    }

private:
    juce::Label titleLabel;
    juce::Label infoLabel;

    juce::Label waveformLabel;
    juce::Label spectrumLabel;
    juce::Label particleLabel;

    std::unique_ptr<WaveformVisualizer> waveformVisualizer;
    std::unique_ptr<SpectrumAnalyzer> spectrumAnalyzer;
    std::unique_ptr<ParticleSystem> particleSystem;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SimpleMainUI)
};
