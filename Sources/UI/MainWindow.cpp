#include "MainWindow.h"
#include "SettingsDialog.h"

//==============================================================================
// Vaporwave Color Palette
//==============================================================================
namespace VaporwaveColors
{
    const juce::Colour Cyan       (0xff00e5ff);  // Primary
    const juce::Colour Magenta    (0xffff00ff);  // Secondary
    const juce::Colour Purple     (0xff651fff);  // Accent
    const juce::Colour Background (0xff1a1a2e);  // Dark
    const juce::Colour Surface    (0xff16213e);  // Darker
    const juce::Colour Text       (0xffffffff);  // White
    const juce::Colour TextDim    (0xffaaaaaa);  // Dimmed
    
    // Gradient
    juce::ColourGradient createGradient(juce::Rectangle<float> bounds, bool horizontal = true)
    {
        if (horizontal)
            return juce::ColourGradient(Cyan, bounds.getX(), bounds.getY(),
                                       Magenta, bounds.getRight(), bounds.getY(), false);
        else
            return juce::ColourGradient(Cyan, bounds.getX(), bounds.getY(),
                                       Purple, bounds.getX(), bounds.getBottom(), false);
    }
}

//==============================================================================
// MainWindow
//==============================================================================

MainWindow::MainWindow(const juce::String& name)
    : DocumentWindow(name, VaporwaveColors::Background, DocumentWindow::allButtons)
{
    setUsingNativeTitleBar(true);
    mainComponent = std::make_unique<MainComponent>();
    setContentOwned(mainComponent.get(), true);
    
    #if JUCE_IOS || JUCE_ANDROID
        setFullScreen(true);
    #else
        centreWithSize(getWidth(), getHeight());
    #endif
    
    setVisible(true);
    setResizable(true, true);
}

MainWindow::~MainWindow()
{
}

void MainWindow::closeButtonPressed()
{
    juce::JUCEApplication::getInstance()->systemRequestedQuit();
}

//==============================================================================
// MainComponent
//==============================================================================

MainWindow::MainComponent::MainComponent()
{
    // Create audio engine
    audioEngine = std::make_unique<AudioEngine>();
    audioEngine->prepare(48000.0, 512);  // Default: 48kHz, 512 samples
    
    // Add some default tracks
    audioEngine->addAudioTrack("Kick");
    audioEngine->addAudioTrack("Snare");
    audioEngine->addAudioTrack("Bass");
    audioEngine->addAudioTrack("Synth");
    audioEngine->addAudioTrack("Vocal");
    
    // Create UI sections
    topBar = std::make_unique<TopBar>(*audioEngine);
    addAndMakeVisible(topBar.get());
    
    trackView = std::make_unique<TrackView>(*audioEngine);
    addAndMakeVisible(trackView.get());
    
    transportBar = std::make_unique<TransportBar>(*audioEngine);
    addAndMakeVisible(transportBar.get());
    
    // Start UI update timer (30 FPS)
    startTimer(33);
    
    setSize(1200, 800);
}

MainWindow::MainComponent::~MainComponent()
{
    stopTimer();
}

void MainWindow::MainComponent::paint(juce::Graphics& g)
{
    // Background with subtle scanlines (CRT effect)
    g.fillAll(VaporwaveColors::Background);
    
    // Scanlines (subtle)
    g.setColour(juce::Colours::black.withAlpha(0.05f));
    for (int y = 0; y < getHeight(); y += 2)
        g.drawLine(0.0f, (float)y, (float)getWidth(), (float)y, 1.0f);
}

void MainWindow::MainComponent::resized()
{
    auto bounds = getLocalBounds();
    
    // Top bar: 50px
    if (topBar)
        topBar->setBounds(bounds.removeFromTop(50));
    
    // Transport bar: 60px (bottom)
    if (transportBar)
        transportBar->setBounds(bounds.removeFromBottom(60));
    
    // Track view: remaining space
    if (trackView)
        trackView->setBounds(bounds);
}

void MainWindow::MainComponent::timerCallback()
{
    // Update UI elements that need real-time updates
    if (trackView)
        trackView->repaint();

    if (transportBar)
        transportBar->updatePosition(audioEngine->getPosition(),
                                    audioEngine->getSampleRate());
}

//==============================================================================
// TopBar
//==============================================================================

MainWindow::MainComponent::TopBar::TopBar(AudioEngine& engine)
    : audioEngine(engine)
{
    // Project name
    projectNameLabel.setText("Untitled Project", juce::dontSendNotification);
    projectNameLabel.setFont(juce::Font(20.0f, juce::Font::bold));
    projectNameLabel.setColour(juce::Label::textColourId, VaporwaveColors::Cyan);
    addAndMakeVisible(projectNameLabel);
    
    // Settings button
    settingsButton.setButtonText("⚙️");
    settingsButton.setTooltip("Settings");
    settingsButton.addListener(this);
    addAndMakeVisible(settingsButton);
    
    // Play button (in top bar for quick access)
    playButton.setButtonText("▶️");
    playButton.setTooltip("Play/Pause");
    playButton.addListener(this);
    addAndMakeVisible(playButton);
    
    // BPM display
    bpmLabel.setText(juce::String(audioEngine.getTempo()) + " BPM", juce::dontSendNotification);
    bpmLabel.setFont(juce::Font(16.0f));
    bpmLabel.setColour(juce::Label::textColourId, VaporwaveColors::Text);
    bpmLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(bpmLabel);
    
    // Cloud status
    cloudButton.setButtonText("☁️");
    cloudButton.setTooltip("Cloud Status (Offline)");
    addAndMakeVisible(cloudButton);
    
    // AI button
    aiButton.setButtonText("🧠");
    aiButton.setTooltip("EchoelAI™ - Super Intelligence Tools");
    aiButton.addListener(this);
    addAndMakeVisible(aiButton);
}

void MainWindow::MainComponent::TopBar::paint(juce::Graphics& g)
{
    // Background with gradient
    auto bounds = getLocalBounds().toFloat();
    auto gradient = VaporwaveColors::createGradient(bounds, true);
    gradient.addColour(0.5, VaporwaveColors::Purple);
    g.setGradientFill(gradient);
    g.setOpacity(0.2f);
    g.fillRect(bounds);
    
    // Glow effect (top border)
    g.setColour(VaporwaveColors::Cyan.withAlpha(0.5f));
    g.drawLine(0.0f, 0.0f, (float)getWidth(), 0.0f, 2.0f);
}

void MainWindow::MainComponent::TopBar::resized()
{
    auto bounds = getLocalBounds().reduced(10, 8);
    
    // Left section
    settingsButton.setBounds(bounds.removeFromLeft(40));
    bounds.removeFromLeft(10);
    projectNameLabel.setBounds(bounds.removeFromLeft(200));
    
    // Right section
    cloudButton.setBounds(bounds.removeFromRight(40));
    bounds.removeFromRight(10);
    aiButton.setBounds(bounds.removeFromRight(40));
    bounds.removeFromRight(10);
    
    // Center section
    bounds.removeFromLeft(50);  // Spacer
    playButton.setBounds(bounds.removeFromLeft(50));
    bounds.removeFromLeft(20);
    bpmLabel.setBounds(bounds.removeFromLeft(100));
}

void MainWindow::MainComponent::TopBar::buttonClicked(juce::Button* button)
{
    if (button == &playButton)
    {
        if (audioEngine.isPlaying())
        {
            audioEngine.stop();
            playButton.setButtonText("▶️");
        }
        else
        {
            audioEngine.play();
            playButton.setButtonText("⏸️");
        }
    }
    else if (button == &aiButton)
    {
        // TODO: Toggle AI panel
        juce::AlertWindow::showMessageBoxAsync(
            juce::AlertWindow::InfoIcon,
            "EchoelAI™",
            "Super Intelligence Tools\n\nComing soon: 12 modular AI assistants with full user control!",
            "OK");
    }
    else if (button == &settingsButton)
    {
        auto* dialog = new SettingsDialog(audioEngine);
        juce::DialogWindow::LaunchOptions options;
        options.content.setOwned(dialog);
        options.dialogTitle = "Settings";
        options.dialogBackgroundColour = juce::Colour(0xff1a1a2e);
        options.escapeKeyTriggersCloseButton = true;
        options.useNativeTitleBar = false;
        options.resizable = false;
        options.launchAsync();
    }
}

//==============================================================================
// TrackView
//==============================================================================

MainWindow::MainComponent::TrackView::TrackView(AudioEngine& engine)
    : audioEngine(engine)
{
    // Horizontal scrollbar
    horizontalScrollBar = std::make_unique<juce::ScrollBar>(false);
    horizontalScrollBar->setRangeLimits(0.0, 10.0);  // 0-10 seconds visible
    horizontalScrollBar->setCurrentRange(0.0, 5.0);   // Show first 5 seconds
    horizontalScrollBar->addListener(this);
    addAndMakeVisible(horizontalScrollBar.get());
    
    // Vertical scrollbar
    verticalScrollBar = std::make_unique<juce::ScrollBar>(true);
    verticalScrollBar->setRangeLimits(0.0, 10.0);
    verticalScrollBar->setCurrentRange(0.0, 5.0);
    verticalScrollBar->addListener(this);
    addAndMakeVisible(verticalScrollBar.get());
}

MainWindow::MainComponent::TrackView::~TrackView()
{
}

void MainWindow::MainComponent::TrackView::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();
    
    // Background
    g.fillAll(VaporwaveColors::Surface);
    
    // Timeline area (top 30px)
    auto timelineBounds = bounds.removeFromTop(30);
    drawTimeline(g, timelineBounds);
    
    // Tracks area
    auto tracksBounds = bounds.reduced(0, 0);
    tracksBounds.removeFromBottom(15);  // Space for horizontal scrollbar
    tracksBounds.removeFromRight(15);   // Space for vertical scrollbar
    
    drawTracks(g, tracksBounds);
    
    // Playhead
    drawPlayhead(g, tracksBounds);
}

void MainWindow::MainComponent::TrackView::resized()
{
    auto bounds = getLocalBounds();
    
    // Scrollbars
    auto scrollbarBounds = bounds;
    scrollbarBounds.removeFromTop(30);  // Skip timeline
    
    if (horizontalScrollBar)
    {
        auto hScrollBounds = scrollbarBounds.removeFromBottom(15);
        hScrollBounds.removeFromRight(15);  // Corner space
        horizontalScrollBar->setBounds(hScrollBounds);
    }
    
    if (verticalScrollBar)
    {
        auto vScrollBounds = scrollbarBounds.removeFromRight(15);
        verticalScrollBar->setBounds(vScrollBounds);
    }
}

void MainWindow::MainComponent::TrackView::scrollBarMoved(juce::ScrollBar* scrollBar, double newRangeStart)
{
    juce::ignoreUnused(scrollBar, newRangeStart);
    repaint();
}

void MainWindow::MainComponent::TrackView::updateTracks()
{
    repaint();
}

void MainWindow::MainComponent::TrackView::drawTimeline(juce::Graphics& g, juce::Rectangle<int> bounds)
{
    // Timeline background
    g.setColour(VaporwaveColors::Background);
    g.fillRect(bounds);
    
    // Timeline markers
    g.setColour(VaporwaveColors::Cyan.withAlpha(0.7f));
    g.setFont(juce::Font(12.0f, juce::Font::plain));
    
    double startTime = horizontalScrollBar->getCurrentRangeStart();
    double visibleDuration = horizontalScrollBar->getCurrentRangeSize();
    
    int numMarkers = 10;
    for (int i = 0; i <= numMarkers; ++i)
    {
        double time = startTime + (visibleDuration * i / numMarkers);
        int x = bounds.getX() + (bounds.getWidth() * i / numMarkers);
        
        // Marker line
        g.drawLine((float)x, (float)bounds.getY(), (float)x, (float)bounds.getBottom(), 1.0f);
        
        // Time label
        int minutes = (int)(time / 60.0);
        int seconds = (int)time % 60;
        juce::String timeStr = juce::String::formatted("%d:%02d", minutes, seconds);
        g.drawText(timeStr, x - 20, bounds.getY() + 5, 40, 20, juce::Justification::centred);
    }
    
    // Glow border (bottom)
    g.setColour(VaporwaveColors::Cyan.withAlpha(0.5f));
    g.drawLine(0.0f, (float)bounds.getBottom(), (float)getWidth(), (float)bounds.getBottom(), 2.0f);
}

void MainWindow::MainComponent::TrackView::drawTracks(juce::Graphics& g, juce::Rectangle<int> bounds)
{
    int numTracks = audioEngine.getNumTracks();
    if (numTracks == 0)
    {
        g.setColour(VaporwaveColors::TextDim);
        g.setFont(juce::Font(16.0f));
        g.drawText("No tracks yet. Click 'Add Track' to start!", bounds, juce::Justification::centred);
        return;
    }
    
    // Draw tracks
    float yOffset = -(float)verticalScrollBar->getCurrentRangeStart() * (float)trackHeight;
    
    for (int i = 0; i < numTracks; ++i)
    {
        auto track = audioEngine.getTrack(i);
        if (!track)
            continue;
        
        juce::Rectangle<float> trackBounds(
            (float)bounds.getX(),
            (float)bounds.getY() + yOffset + (i * (float)trackHeight),
            (float)bounds.getWidth(),
            (float)trackHeight
        );
        
        // Skip if not visible
        if (trackBounds.getBottom() < bounds.getY() || trackBounds.getY() > bounds.getBottom())
            continue;
        
        // Track background (alternating colors)
        g.setColour(i % 2 == 0 ? VaporwaveColors::Surface : VaporwaveColors::Background);
        g.fillRect(trackBounds);
        
        // Track name
        g.setColour(VaporwaveColors::Text);
        g.setFont(juce::Font(14.0f, juce::Font::bold));
        g.drawText(track->getName(), trackBounds.reduced(10, 5).toNearestInt(), 
                  juce::Justification::topLeft);
        
        // Waveform placeholder (TODO: actual waveform rendering)
        auto waveformBounds = trackBounds.reduced(10, 25);
        g.setColour(VaporwaveColors::Cyan.withAlpha(0.3f));
        
        // Draw simplified waveform (random for now - will be real audio data)
        juce::Path waveformPath;
        bool started = false;
        for (float x = waveformBounds.getX(); x < waveformBounds.getRight(); x += 2.0f)
        {
            float y = waveformBounds.getCentreY() + (juce::Random::getSystemRandom().nextFloat() * 20.0f - 10.0f);
            if (!started)
            {
                waveformPath.startNewSubPath(x, y);
                started = true;
            }
            else
            {
                waveformPath.lineTo(x, y);
            }
        }
        g.strokePath(waveformPath, juce::PathStrokeType(1.5f));
        
        // Track border (glow)
        g.setColour(VaporwaveColors::Cyan.withAlpha(0.3f));
        g.drawRect(trackBounds, 1.0f);
    }
}

void MainWindow::MainComponent::TrackView::drawPlayhead(juce::Graphics& g, juce::Rectangle<int> bounds)
{
    // Playhead position (normalized 0-1)
    double playheadTime = (double)audioEngine.getPosition() / audioEngine.getSampleRate();
    double startTime = horizontalScrollBar->getCurrentRangeStart();
    double visibleDuration = horizontalScrollBar->getCurrentRangeSize();
    
    if (playheadTime < startTime || playheadTime > startTime + visibleDuration)
        return;  // Playhead not visible
    
    float normalizedPos = (float)((playheadTime - startTime) / visibleDuration);
    float x = bounds.getX() + normalizedPos * bounds.getWidth();
    
    // Draw playhead line (glowing)
    g.setColour(VaporwaveColors::Magenta.withAlpha(0.8f));
    g.drawLine(x, (float)bounds.getY(), x, (float)bounds.getBottom(), 2.0f);
    
    // Glow effect
    g.setColour(VaporwaveColors::Magenta.withAlpha(0.3f));
    g.drawLine(x - 1.0f, (float)bounds.getY(), x - 1.0f, (float)bounds.getBottom(), 4.0f);
    g.drawLine(x + 1.0f, (float)bounds.getY(), x + 1.0f, (float)bounds.getBottom(), 4.0f);
    
    // Playhead handle (triangle)
    juce::Path triangle;
    triangle.addTriangle(x - 5.0f, (float)bounds.getY(), x + 5.0f, (float)bounds.getY(), x, (float)bounds.getY() + 10.0f);
    g.setColour(VaporwaveColors::Magenta);
    g.fillPath(triangle);
}

//==============================================================================
// TransportBar
//==============================================================================

MainWindow::MainComponent::TransportBar::TransportBar(AudioEngine& engine)
    : audioEngine(engine)
{
    // Previous button
    previousButton.setButtonText("⏮️");
    previousButton.setTooltip("Previous section");
    previousButton.addListener(this);
    addAndMakeVisible(previousButton);
    
    // Play button
    playButton.setButtonText("▶️");
    playButton.setTooltip("Play");
    playButton.addListener(this);
    addAndMakeVisible(playButton);
    
    // Next button
    nextButton.setButtonText("⏭️");
    nextButton.setTooltip("Next section");
    nextButton.addListener(this);
    addAndMakeVisible(nextButton);
    
    // Stop button
    stopButton.setButtonText("⏹️");
    stopButton.setTooltip("Stop");
    stopButton.addListener(this);
    addAndMakeVisible(stopButton);
    
    // Record button
    recordButton.setButtonText("⏺️");
    recordButton.setTooltip("Record");
    recordButton.addListener(this);
    addAndMakeVisible(recordButton);
    
    // Position label
    positionLabel.setText("00:00.000", juce::dontSendNotification);
    positionLabel.setFont(juce::Font("monospace", 18.0f, juce::Font::plain));
    positionLabel.setColour(juce::Label::textColourId, VaporwaveColors::Cyan);
    positionLabel.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(positionLabel);
    
    // Save button
    saveButton.setButtonText("💾");
    saveButton.setTooltip("Save project");
    saveButton.addListener(this);
    addAndMakeVisible(saveButton);
    
    // Export button
    exportButton.setButtonText("📤");
    exportButton.setTooltip("Export audio");
    exportButton.addListener(this);
    addAndMakeVisible(exportButton);
}

void MainWindow::MainComponent::TransportBar::paint(juce::Graphics& g)
{
    // Background
    g.fillAll(VaporwaveColors::Background);
    
    // Glow border (top)
    g.setColour(VaporwaveColors::Purple.withAlpha(0.5f));
    g.drawLine(0.0f, 0.0f, (float)getWidth(), 0.0f, 2.0f);
    
    // Master meter (right side)
    auto bounds = getLocalBounds();
    auto meterBounds = bounds.removeFromRight(150).reduced(10, 10);
    drawMasterMeter(g, meterBounds);
}

void MainWindow::MainComponent::TransportBar::resized()
{
    auto bounds = getLocalBounds().reduced(10, 10);
    
    // Left section - transport controls
    auto transportBounds = bounds.removeFromLeft(300);
    previousButton.setBounds(transportBounds.removeFromLeft(50));
    transportBounds.removeFromLeft(5);
    playButton.setBounds(transportBounds.removeFromLeft(60));
    transportBounds.removeFromLeft(5);
    nextButton.setBounds(transportBounds.removeFromLeft(50));
    transportBounds.removeFromLeft(10);
    stopButton.setBounds(transportBounds.removeFromLeft(50));
    transportBounds.removeFromLeft(10);
    recordButton.setBounds(transportBounds.removeFromLeft(50));
    
    // Right section - file operations
    exportButton.setBounds(bounds.removeFromRight(50));
    bounds.removeFromRight(5);
    saveButton.setBounds(bounds.removeFromRight(50));
    
    // Master meter takes remaining right space (handled in paint)
    bounds.removeFromRight(150);
    
    // Center - position display
    bounds.removeFromLeft(20);  // Spacer
    positionLabel.setBounds(bounds.removeFromLeft(120));
}

void MainWindow::MainComponent::TransportBar::buttonClicked(juce::Button* button)
{
    if (button == &playButton)
        onPlayClicked();
    else if (button == &stopButton)
        onStopClicked();
    else if (button == &recordButton)
        onRecordClicked();
    else if (button == &saveButton)
    {
        // TODO: Save project
        juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::InfoIcon,
            "Save", "Project save coming soon!", "OK");
    }
    else if (button == &exportButton)
    {
        // TODO: Export audio
        juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::InfoIcon,
            "Export", "Audio export coming soon!", "OK");
    }
}

void MainWindow::MainComponent::TransportBar::updatePosition(int64_t positionInSamples, double sampleRate)
{
    if (sampleRate <= 0.0)
        return;
    
    double timeInSeconds = (double)positionInSamples / sampleRate;
    int minutes = (int)(timeInSeconds / 60.0);
    int seconds = (int)timeInSeconds % 60;
    int milliseconds = (int)((timeInSeconds - (int)timeInSeconds) * 1000.0);
    
    juce::String posStr = juce::String::formatted("%02d:%02d.%03d", minutes, seconds, milliseconds);
    positionLabel.setText(posStr, juce::dontSendNotification);
    
    // Update master level
    currentLevel = audioEngine.getMasterPeakLevel();
    repaint();  // Redraw meter
}

void MainWindow::MainComponent::TransportBar::onPlayClicked()
{
    if (audioEngine.isPlaying())
    {
        audioEngine.stop();
        playButton.setButtonText("▶️");
    }
    else
    {
        audioEngine.play();
        playButton.setButtonText("⏸️");
    }
}

void MainWindow::MainComponent::TransportBar::onStopClicked()
{
    audioEngine.stop();
    audioEngine.setPosition(0);
    playButton.setButtonText("▶️");
}

void MainWindow::MainComponent::TransportBar::onRecordClicked()
{
    if (audioEngine.isRecording())
    {
        audioEngine.stopRecording();
        recordButton.setColour(juce::TextButton::buttonColourId, juce::Colours::transparentBlack);
    }
    else
    {
        audioEngine.startRecording();
        recordButton.setColour(juce::TextButton::buttonColourId, juce::Colours::red.withAlpha(0.3f));
    }
}

void MainWindow::MainComponent::TransportBar::drawMasterMeter(juce::Graphics& g, juce::Rectangle<int> bounds)
{
    // Master meter background
    g.setColour(VaporwaveColors::Surface);
    g.fillRoundedRectangle(bounds.toFloat(), 4.0f);
    
    // Label
    g.setColour(VaporwaveColors::TextDim);
    g.setFont(juce::Font(10.0f));
    g.drawText("MASTER", bounds.removeFromTop(15), juce::Justification::centred);
    
    // Meter bounds
    auto meterBounds = bounds.reduced(5, 2);
    
    // Meter background (gradient)
    auto gradient = juce::ColourGradient(
        VaporwaveColors::Cyan, meterBounds.getCentreX(), (float)meterBounds.getBottom(),
        VaporwaveColors::Magenta, meterBounds.getCentreX(), (float)meterBounds.getY(),
        false);
    gradient.addColour(0.7, juce::Colours::yellow);
    gradient.addColour(0.9, juce::Colours::red);
    
    // Convert level to dB and normalize
    float levelDB = juce::Decibels::gainToDecibels(currentLevel, -60.0f);
    float normalizedLevel = juce::jmap(levelDB, -60.0f, 0.0f, 0.0f, 1.0f);
    normalizedLevel = juce::jlimit(0.0f, 1.0f, normalizedLevel);
    
    // Draw meter fill
    auto fillBounds = meterBounds.toFloat();
    float fillHeight = fillBounds.getHeight() * normalizedLevel;
    fillBounds.removeFromTop(fillBounds.getHeight() - fillHeight);
    
    g.setGradientFill(gradient);
    g.fillRoundedRectangle(fillBounds, 2.0f);
    
    // Meter border
    g.setColour(VaporwaveColors::Cyan.withAlpha(0.5f));
    g.drawRoundedRectangle(meterBounds.toFloat(), 2.0f, 1.0f);
    
    // dB markings
    g.setColour(VaporwaveColors::TextDim);
    g.setFont(juce::Font(8.0f));
    for (float db : { 0.0f, -6.0f, -12.0f, -24.0f, -48.0f })
    {
        float y = juce::jmap(db, -60.0f, 0.0f, (float)meterBounds.getBottom(), (float)meterBounds.getY());
        g.drawText(juce::String(db, 0), meterBounds.getRight() + 2, (int)y - 5, 30, 10, 
                  juce::Justification::left);
    }
}
