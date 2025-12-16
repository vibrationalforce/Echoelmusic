/*
  ==============================================================================

    Echoelmusic Pro - Plugin Editor Implementation

  ==============================================================================
*/

#include "PluginProcessor.h"
#include "PluginEditor.h"

//==============================================================================
EchoelmusicProEditor::EchoelmusicProEditor (EchoelmusicProProcessor& p)
    : AudioProcessorEditor (&p), audioProcessor (p)
{
    // Apply modern look and feel
    setLookAndFeel(&modernLookAndFeel);

    // Set initial size (larger for professional plugin)
    setSize (1200, 800);

    // Set resizable with constraints (min: 800x600, max: 1920x1080)
    setResizable(true, true);
    setResizeLimits(800, 600, 1920, 1080);

    // Start timer for animations (60 FPS)
    startTimerHz(60);
}

EchoelmusicProEditor::~EchoelmusicProEditor()
{
    // Remove look and feel
    setLookAndFeel(nullptr);

    // Stop timer
    stopTimer();
}

//==============================================================================
void EchoelmusicProEditor::paint (juce::Graphics& g)
{
    // Draw gradient background using modern look and feel
    ModernLookAndFeel::drawGradientBackground(g, getLocalBounds().toFloat(),
                                               juce::Colour(ModernLookAndFeel::ColorBackgroundDark),
                                               juce::Colour(ModernLookAndFeel::ColorBackground));

    // Header area
    auto headerBounds = getLocalBounds().removeFromTop(100).toFloat().reduced(20.0f);

    // Draw header background with glow
    ModernLookAndFeel::drawRoundedRectangleWithGlow(g, headerBounds, 8.0f,
                                                     juce::Colour(ModernLookAndFeel::ColorSurface),
                                                     juce::Colour(ModernLookAndFeel::ColorPrimary),
                                                     0.3f);

    // Title
    g.setColour (juce::Colour(ModernLookAndFeel::ColorText));
    g.setFont (juce::Font(36.0f, juce::Font::bold));
    auto titleBounds = headerBounds.removeFromTop(50.0f);
    g.drawFittedText ("Echoelmusic Pro", titleBounds.toNearestInt(), juce::Justification::centred, 1);

    // Subtitle with accent color
    g.setFont (juce::Font(14.0f));
    g.setColour (juce::Colour(ModernLookAndFeel::ColorPrimary));
    g.drawFittedText ("96 Professional DSP Processors • 202 Presets • Bio-Reactive Audio",
                      headerBounds.toNearestInt(),
                      juce::Justification::centred, 1);

    // Main content area
    auto contentBounds = getLocalBounds().reduced(20).removeFromTop(getHeight() - 160);

    // Feature cards
    auto cardHeight = 60.0f;
    auto cardSpacing = 15.0f;
    auto cardY = contentBounds.getY() + 20.0f;

    const char* features[] = {
        "11 Synthesis Methods",
        "Vector, Modal, Granular, FM",
        "Advanced Spectral Processing",
        "SpectralSculptor, SwarmReverb, DynamicEQ",
        "ML-Based Processing",
        "NeuralToneMatch, StyleAwareMastering",
        "Bio-Reactive DSP",
        "HRV, Coherence, Stress Modulation",
        "SIMD Optimizations",
        "AVX2/NEON - 3× Performance"
    };

    for (int i = 0; i < 5; ++i)
    {
        auto cardBounds = juce::Rectangle<float>(contentBounds.getX() + 10.0f, cardY,
                                                   contentBounds.getWidth() - 20.0f, cardHeight);

        // Card background
        g.setColour(juce::Colour(ModernLookAndFeel::ColorSurface));
        g.fillRoundedRectangle(cardBounds, 6.0f);

        // Card border with accent
        g.setColour(juce::Colour(ModernLookAndFeel::ColorBorder));
        g.drawRoundedRectangle(cardBounds, 6.0f, 1.0f);

        // Feature title
        g.setFont(juce::Font(16.0f, juce::Font::bold));
        g.setColour(juce::Colour(ModernLookAndFeel::ColorPrimary));
        g.drawText(features[i * 2], cardBounds.removeFromTop(30.0f).reduced(15.0f, 5.0f).toNearestInt(),
                   juce::Justification::centredLeft);

        // Feature description
        g.setFont(juce::Font(12.0f));
        g.setColour(juce::Colour(ModernLookAndFeel::ColorTextDimmed));
        g.drawText(features[i * 2 + 1], cardBounds.reduced(15.0f, 0.0f).toNearestInt(),
                   juce::Justification::centredLeft);

        cardY += cardHeight + cardSpacing;
    }

    // Footer status bar
    auto footerBounds = getLocalBounds().removeFromBottom(50).toFloat().reduced(20.0f, 10.0f);

    g.setColour(juce::Colour(ModernLookAndFeel::ColorSurface).withAlpha(0.5f));
    g.fillRoundedRectangle(footerBounds, 4.0f);

    g.setFont (juce::Font(12.0f));
    g.setColour (juce::Colour(ModernLookAndFeel::ColorSuccess));
    g.drawFittedText ("Status: Ready • JUCE Framework Active • 96 Processors Loaded",
                      footerBounds.toNearestInt(),
                      juce::Justification::centred, 1);
}

void EchoelmusicProEditor::resized()
{
    // Layout components here
    // TODO: Layout SpectrumAnalyzer, PresetBrowser, ProcessorRack, BioReactiveVisualizer
}

void EchoelmusicProEditor::timerCallback()
{
    // Update animations and real-time visualizations
    // TODO: Update spectrum analyzer
    // TODO: Update bio-reactive visualization
    // TODO: Update any animated UI elements
}
