#include "UnifiedWorkspaceView.h"

//==============================================================================
// Constructor / Destructor
//==============================================================================

UnifiedWorkspaceView::UnifiedWorkspaceView(AudioEngine& engine)
    : audioEngine(engine)
{
    // Create both views
    arrangementView = std::make_unique<MainWindow::MainComponent::TrackView>(audioEngine);
    sessionView = std::make_unique<ClipLauncherGrid>();

    // Add arrangement view (visible by default)
    addAndMakeVisible(arrangementView.get());
    addChildComponent(sessionView.get());  // Hidden initially

    // View mode button
    addAndMakeVisible(viewModeButton);
    viewModeButton.setButtonText("Arrangement View");
    viewModeButton.setTooltip("Switch to Session/Clip View (Tab key)");
    viewModeButton.onClick = [this]() { toggleViewMode(); };

    // View mode label
    addAndMakeVisible(viewModeLabel);
    viewModeLabel.setText("View:", juce::dontSendNotification);
    viewModeLabel.setFont(juce::Font(14.0f, juce::Font::bold));
    viewModeLabel.setColour(juce::Label::textColourId, cyanColor);

    // Status label
    addAndMakeVisible(statusLabel);
    statusLabel.setFont(juce::Font(12.0f));
    statusLabel.setColour(juce::Label::textColourId, juce::Colours::white);

    // Register keyboard listener
    addKeyListener(this);
    setWantsKeyboardFocus(true);

    // Initialize UI
    updateViewVisibility();
    updateButtonText();
    updateStatusBar();
}

//==============================================================================
// View Mode Management
//==============================================================================

void UnifiedWorkspaceView::setViewMode(ViewMode mode)
{
    if (currentViewMode == mode)
        return;

    currentViewMode = mode;

    updateViewVisibility();
    updateButtonText();
    updateStatusBar();

    repaint();
}

void UnifiedWorkspaceView::toggleViewMode()
{
    setViewMode(
        currentViewMode == ViewMode::Arrangement
            ? ViewMode::Session
            : ViewMode::Arrangement
    );
}

//==============================================================================
// Bio-Reactive Integration
//==============================================================================

void UnifiedWorkspaceView::setBioData(float hrv, float coherence, float stress)
{
    currentHRV = hrv;
    currentCoherence = coherence;
    currentStress = stress;

    // Forward to session view (has bio-reactive clips)
    if (sessionView)
        sessionView->setBioData(hrv, coherence, stress);

    updateStatusBar();
}

void UnifiedWorkspaceView::updateBioData(const Echoelmusic::BioFeedbackSystem::UnifiedBioData& bioData)
{
    currentHRV = bioData.hrv;
    currentCoherence = bioData.coherence;
    currentStress = bioData.stress;

    // Forward to session view
    if (sessionView)
        sessionView->updateBioData(bioData);

    updateStatusBar();
}

//==============================================================================
// Integration Points
//==============================================================================

void UnifiedWorkspaceView::setVideoWeaver(VideoWeaver* weaver)
{
    if (arrangementView)
        arrangementView->setVideoWeaver(weaver);
}

void UnifiedWorkspaceView::setAutomationUI(ParameterAutomationUI* ui)
{
    if (arrangementView)
        arrangementView->setAutomationUI(ui);
}

void UnifiedWorkspaceView::setBPM(double bpm)
{
    currentBPM = bpm;

    if (sessionView)
        sessionView->setBPM(bpm);

    updateStatusBar();
}

//==============================================================================
// Component Methods
//==============================================================================

void UnifiedWorkspaceView::paint(juce::Graphics& g)
{
    // Background
    g.fillAll(backgroundColor);

    // Top bar gradient
    auto topBarBounds = getLocalBounds().removeFromTop(40);

    juce::ColourGradient gradient(
        cyanColor.withAlpha(0.3f), topBarBounds.getX(), topBarBounds.getY(),
        purpleColor.withAlpha(0.3f), topBarBounds.getRight(), topBarBounds.getY(),
        false
    );

    g.setGradientFill(gradient);
    g.fillRect(topBarBounds);

    // Glow effect (bottom border)
    g.setColour(currentViewMode == ViewMode::Arrangement ? cyanColor : magentaColor);
    g.drawLine(0.0f, topBarBounds.getBottom(), static_cast<float>(getWidth()), topBarBounds.getBottom(), 2.0f);
}

void UnifiedWorkspaceView::resized()
{
    auto bounds = getLocalBounds();

    // Top bar with view mode selector
    auto topBar = bounds.removeFromTop(40);
    topBar = topBar.reduced(10, 5);

    viewModeLabel.setBounds(topBar.removeFromLeft(50));
    viewModeButton.setBounds(topBar.removeFromLeft(180));

    topBar.removeFromLeft(20);  // Spacer

    // Status label (right side)
    statusLabel.setBounds(topBar);

    // Both views fill remaining space
    if (arrangementView)
        arrangementView->setBounds(bounds);

    if (sessionView)
        sessionView->setBounds(bounds);
}

//==============================================================================
// Keyboard Shortcuts
//==============================================================================

bool UnifiedWorkspaceView::keyPressed(const juce::KeyPress& key, Component* originatingComponent)
{
    juce::ignoreUnused(originatingComponent);

    // Tab key toggles view mode
    if (key == juce::KeyPress::tabKey && !key.getModifiers().isAnyModifierKeyDown())
    {
        toggleViewMode();
        return true;
    }

    // Ctrl/Cmd + 1 = Arrangement view
    if (key == juce::KeyPress('1', juce::ModifierKeys::commandModifier, 0))
    {
        setViewMode(ViewMode::Arrangement);
        return true;
    }

    // Ctrl/Cmd + 2 = Session view
    if (key == juce::KeyPress('2', juce::ModifierKeys::commandModifier, 0))
    {
        setViewMode(ViewMode::Session);
        return true;
    }

    return false;
}

//==============================================================================
// Helper Methods
//==============================================================================

void UnifiedWorkspaceView::updateViewVisibility()
{
    if (arrangementView)
        arrangementView->setVisible(currentViewMode == ViewMode::Arrangement);

    if (sessionView)
        sessionView->setVisible(currentViewMode == ViewMode::Session);
}

void UnifiedWorkspaceView::updateButtonText()
{
    if (currentViewMode == ViewMode::Arrangement)
    {
        viewModeButton.setButtonText("Arrangement View");
        viewModeButton.setTooltip("Switch to Session/Clip View (Tab key)");
        viewModeButton.setColour(juce::TextButton::buttonColourId, cyanColor.withAlpha(0.3f));
    }
    else
    {
        viewModeButton.setButtonText("Session/Clip View");
        viewModeButton.setTooltip("Switch to Arrangement View (Tab key)");
        viewModeButton.setColour(juce::TextButton::buttonColourId, magentaColor.withAlpha(0.3f));
    }
}

void UnifiedWorkspaceView::updateStatusBar()
{
    juce::String statusText;

    // View mode indicator
    statusText += (currentViewMode == ViewMode::Arrangement ? "🎵 " : "🎬 ");

    // BPM
    statusText += "BPM: " + juce::String(currentBPM, 1) + " | ";

    // Bio-feedback data
    statusText += "💓 HR: " + juce::String(currentHRV * 100.0f, 0) + "% | ";
    statusText += "Coherence: " + juce::String(currentCoherence * 100.0f, 0) + "% | ";

    // Coherence level indicator
    if (currentCoherence > 0.7f)
        statusText += "🟢 High";
    else if (currentCoherence > 0.4f)
        statusText += "🟡 Med";
    else
        statusText += "🔴 Low";

    statusLabel.setText(statusText, juce::dontSendNotification);
}
