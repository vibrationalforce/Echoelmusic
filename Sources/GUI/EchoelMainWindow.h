/*
  ==============================================================================

    EchoelMainWindow.h
    Comprehensive GUI - Main Application Window

    Modern, accessible, bio-reactive interface for Echoelmusic DAW.
    Integrates with all Ralph Wiggum systems for intelligent music creation.

    Design Principles:
    - Progressive disclosure (complexity adapts to user)
    - Bio-reactive theming (colors respond to coherence)
    - WCAG 2.1 AAA accessibility compliance
    - Responsive layout for all screen sizes
    - Dark mode optimized

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "../Core/RalphWiggumAPI.h"
#include "../Core/EchoelTypeSystem.h"
#include "../UI/AccessibilityConstants.h"
#include "TransportBar.h"
#include "CoherencePanel.h"
#include "AISuggestionsPanel.h"
#include "LoopMatrix.h"
#include "ArrangementView.h"
#include "MixerPanel.h"
#include "BioReactiveLookAndFeel.h"
#include <memory>
#include <functional>

namespace Echoelmusic {
namespace GUI {

//==============================================================================
// Color Scheme
//==============================================================================

struct ColorScheme
{
    // Backgrounds
    juce::Colour background          {0xFF121218};
    juce::Colour backgroundSecondary {0xFF1A1A24};
    juce::Colour backgroundTertiary  {0xFF242430};
    juce::Colour backgroundHover     {0xFF2A2A3A};

    // Text
    juce::Colour textPrimary         {0xFFFFFFFF};
    juce::Colour textSecondary       {0xFFB8B8C8};
    juce::Colour textDisabled        {0xFF6B6B7B};

    // Accent colors
    juce::Colour accentPrimary       {0xFF00D9FF};
    juce::Colour accentSecondary     {0xFFFF6B9D};
    juce::Colour accentSuccess       {0xFF4ADE80};
    juce::Colour accentWarning       {0xFFFBBF24};
    juce::Colour accentError         {0xFFF87171};

    // Bio-reactive colors
    juce::Colour coherenceHigh       {0xFF4ADE80};
    juce::Colour coherenceMedium     {0xFFFBBF24};
    juce::Colour coherenceLow        {0xFFF87171};

    // Focus
    juce::Colour focusRing           {0xFF00D9FF};

    // Get coherence-based color
    juce::Colour getCoherenceColor(float coherence) const
    {
        if (coherence > 0.7f)
            return coherenceHigh;
        else if (coherence > 0.4f)
            return coherenceMedium;
        else
            return coherenceLow;
    }

    // Blend background with coherence
    juce::Colour getBioBackground(float coherence) const
    {
        auto tint = getCoherenceColor(coherence);
        return background.interpolatedWith(tint, 0.05f);
    }
};

//==============================================================================
// Main Window Layout
//==============================================================================

class EchoelMainWindow : public juce::DocumentWindow,
                         public juce::Timer
{
public:
    EchoelMainWindow()
        : DocumentWindow("Echoelmusic",
                        juce::Colour(0xFF121218),
                        DocumentWindow::allButtons)
    {
        setUsingNativeTitleBar(true);
        setResizable(true, true);
        setResizeLimits(1024, 600, 4096, 2400);

        // Create main content
        mainContent = std::make_unique<MainContent>();
        setContentOwned(mainContent.get(), false);

        // Center on screen
        centreWithSize(1400, 900);

        setVisible(true);

        // Start bio-reactive updates
        startTimer(100);  // 10Hz update
    }

    ~EchoelMainWindow() override
    {
        stopTimer();
    }

    void closeButtonPressed() override
    {
        juce::JUCEApplication::getInstance()->systemRequestedQuit();
    }

    void timerCallback() override
    {
        // Update bio-reactive elements
        if (mainContent)
            mainContent->updateBioState();
    }

private:
    std::unique_ptr<class MainContent> mainContent;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelMainWindow)
};

//==============================================================================
// Main Content Component
//==============================================================================

class MainContent : public juce::Component,
                    public juce::KeyListener
{
public:
    MainContent()
    {
        setWantsKeyboardFocus(true);
        addKeyListener(this);

        // Initialize Ralph Wiggum API
        RalphWiggum::RalphWiggumAPI::getInstance().initialize();

        // Create components
        createComponents();

        // Setup layout
        setupLayout();

        // Apply look and feel
        lookAndFeel = std::make_unique<BioReactiveLookAndFeel>();
        setLookAndFeel(lookAndFeel.get());
    }

    ~MainContent() override
    {
        setLookAndFeel(nullptr);
        removeKeyListener(this);
    }

    void paint(juce::Graphics& g) override
    {
        // Bio-reactive background
        auto bgColor = colors.getBioBackground(currentCoherence);
        g.fillAll(bgColor);

        // Subtle gradient overlay
        juce::ColourGradient gradient(
            colors.background.withAlpha(0.0f), 0, 0,
            colors.background.withAlpha(0.3f), 0, static_cast<float>(getHeight()),
            false);
        g.setGradientFill(gradient);
        g.fillRect(getLocalBounds());
    }

    void resized() override
    {
        auto bounds = getLocalBounds();

        // Top bar (transport + coherence)
        auto topBar = bounds.removeFromTop(60);
        transportBar->setBounds(topBar.removeFromLeft(topBar.getWidth() / 2));
        coherencePanel->setBounds(topBar);

        // Bottom status bar
        auto statusBar = bounds.removeFromBottom(30);
        statusPanel->setBounds(statusBar);

        // Left sidebar (AI suggestions)
        auto sidebar = bounds.removeFromLeft(
            expertiseLevel >= 3 ? 280 : 200);  // Progressive width
        aiSuggestionsPanel->setBounds(sidebar);

        // Right sidebar (mixer) - only for advanced users
        if (expertiseLevel >= 4)
        {
            auto mixerArea = bounds.removeFromRight(250);
            mixerPanel->setBounds(mixerArea);
            mixerPanel->setVisible(true);
        }
        else
        {
            mixerPanel->setVisible(false);
        }

        // Main area split
        auto mainArea = bounds.reduced(10);

        // Top: Arrangement view
        auto arrangementArea = mainArea.removeFromTop(mainArea.getHeight() * 0.6f);
        arrangementView->setBounds(arrangementArea);

        // Bottom: Loop matrix
        loopMatrix->setBounds(mainArea.reduced(0, 10));
    }

    void updateBioState()
    {
        auto& api = RalphWiggum::RalphWiggumAPI::getInstance();
        auto stats = api.getStats();

        float newCoherence = stats.currentCoherence;

        if (std::abs(newCoherence - currentCoherence) > 0.01f)
        {
            currentCoherence = newCoherence;

            // Update coherence panel
            if (coherencePanel)
                coherencePanel->setCoherence(currentCoherence);

            // Update look and feel
            if (lookAndFeel)
                lookAndFeel->setCoherence(currentCoherence);

            repaint();
        }

        // Update expertise level based on progressive disclosure
        int newLevel = api.getExpertiseLevel();
        if (newLevel != expertiseLevel)
        {
            expertiseLevel = newLevel;
            resized();  // Relayout for new complexity level
        }
    }

    // Keyboard shortcuts
    bool keyPressed(const juce::KeyPress& key, juce::Component*) override
    {
        auto& api = RalphWiggum::RalphWiggumAPI::getInstance();

        // Space = Play/Pause
        if (key == juce::KeyPress::spaceKey)
        {
            transportBar->togglePlayPause();
            return true;
        }

        // R = Record
        if (key.getTextCharacter() == 'r' || key.getTextCharacter() == 'R')
        {
            transportBar->toggleRecord();
            return true;
        }

        // L = Loop
        if (key.getTextCharacter() == 'l' || key.getTextCharacter() == 'L')
        {
            transportBar->toggleLoop();
            return true;
        }

        // Cmd/Ctrl + Z = Undo
        if (key.getModifiers().isCommandDown() && key.getTextCharacter() == 'z')
        {
            api.recordUndo();
            return true;
        }

        // Cmd/Ctrl + S = Save
        if (key.getModifiers().isCommandDown() && key.getTextCharacter() == 's')
        {
            api.saveSession();
            return true;
        }

        // Tab = Next AI suggestion
        if (key == juce::KeyPress::tabKey)
        {
            aiSuggestionsPanel->focusNextSuggestion();
            return true;
        }

        // Enter = Accept suggestion
        if (key == juce::KeyPress::returnKey)
        {
            aiSuggestionsPanel->acceptFocusedSuggestion();
            return true;
        }

        // 1-4 = Trigger loops
        if (key.getTextCharacter() >= '1' && key.getTextCharacter() <= '4')
        {
            int loopIndex = key.getTextCharacter() - '1';
            loopMatrix->triggerLoop(loopIndex);
            return true;
        }

        return false;
    }

private:
    void createComponents()
    {
        // Transport bar
        transportBar = std::make_unique<TransportBar>();
        addAndMakeVisible(transportBar.get());

        // Coherence panel
        coherencePanel = std::make_unique<CoherencePanel>();
        addAndMakeVisible(coherencePanel.get());

        // AI suggestions
        aiSuggestionsPanel = std::make_unique<AISuggestionsPanel>();
        addAndMakeVisible(aiSuggestionsPanel.get());

        // Arrangement view
        arrangementView = std::make_unique<ArrangementView>();
        addAndMakeVisible(arrangementView.get());

        // Loop matrix
        loopMatrix = std::make_unique<LoopMatrix>();
        addAndMakeVisible(loopMatrix.get());

        // Mixer panel
        mixerPanel = std::make_unique<MixerPanel>();
        addAndMakeVisible(mixerPanel.get());

        // Status panel
        statusPanel = std::make_unique<StatusPanel>();
        addAndMakeVisible(statusPanel.get());
    }

    void setupLayout()
    {
        // Get initial expertise level
        expertiseLevel = RalphWiggum::RalphWiggumAPI::getInstance().getExpertiseLevel();
    }

    // Components
    std::unique_ptr<TransportBar> transportBar;
    std::unique_ptr<CoherencePanel> coherencePanel;
    std::unique_ptr<AISuggestionsPanel> aiSuggestionsPanel;
    std::unique_ptr<ArrangementView> arrangementView;
    std::unique_ptr<LoopMatrix> loopMatrix;
    std::unique_ptr<MixerPanel> mixerPanel;
    std::unique_ptr<StatusPanel> statusPanel;

    std::unique_ptr<BioReactiveLookAndFeel> lookAndFeel;

    ColorScheme colors;
    float currentCoherence = 0.5f;
    int expertiseLevel = 2;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MainContent)
};

//==============================================================================
// Status Panel
//==============================================================================

class StatusPanel : public juce::Component,
                    public juce::Timer
{
public:
    StatusPanel()
    {
        // Key signature
        keyLabel.setText("C Major", juce::dontSendNotification);
        keyLabel.setColour(juce::Label::textColourId, juce::Colour(0xFFB8B8C8));
        addAndMakeVisible(keyLabel);

        // Tempo
        tempoLabel.setText("120 BPM", juce::dontSendNotification);
        tempoLabel.setColour(juce::Label::textColourId, juce::Colour(0xFFB8B8C8));
        addAndMakeVisible(tempoLabel);

        // Time signature
        timeLabel.setText("4/4", juce::dontSendNotification);
        timeLabel.setColour(juce::Label::textColourId, juce::Colour(0xFFB8B8C8));
        addAndMakeVisible(timeLabel);

        // CPU meter
        cpuLabel.setText("CPU: 5%", juce::dontSendNotification);
        cpuLabel.setColour(juce::Label::textColourId, juce::Colour(0xFFB8B8C8));
        addAndMakeVisible(cpuLabel);

        // Connection status
        connectionLabel.setText("Watch: Connected", juce::dontSendNotification);
        connectionLabel.setColour(juce::Label::textColourId, juce::Colour(0xFF4ADE80));
        addAndMakeVisible(connectionLabel);

        startTimer(500);
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xFF1A1A24));

        // Top border
        g.setColour(juce::Colour(0xFF2A2A3A));
        g.drawLine(0, 0, static_cast<float>(getWidth()), 0, 1.0f);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10, 5);

        int itemWidth = 100;

        keyLabel.setBounds(bounds.removeFromLeft(itemWidth));
        tempoLabel.setBounds(bounds.removeFromLeft(itemWidth));
        timeLabel.setBounds(bounds.removeFromLeft(itemWidth));

        connectionLabel.setBounds(bounds.removeFromRight(150));
        cpuLabel.setBounds(bounds.removeFromRight(100));
    }

    void timerCallback() override
    {
        // Update status
        auto& api = RalphWiggum::RalphWiggumAPI::getInstance();

        // Update CPU (placeholder)
        cpuLabel.setText("CPU: " + juce::String(juce::Random::getSystemRandom().nextInt(10) + 2) + "%",
                        juce::dontSendNotification);
    }

private:
    juce::Label keyLabel;
    juce::Label tempoLabel;
    juce::Label timeLabel;
    juce::Label cpuLabel;
    juce::Label connectionLabel;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(StatusPanel)
};

} // namespace GUI
} // namespace Echoelmusic
