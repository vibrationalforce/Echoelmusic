#include "MainWindow.h"

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

    // Arrangement view (TrackView)
    trackView = std::make_unique<TrackView>(*audioEngine);
    addAndMakeVisible(trackView.get());

    // Session view (ClipLauncherGrid)
    sessionView = std::make_unique<ClipLauncherGrid>();
    addChildComponent(sessionView.get());  // Hidden initially

    // View mode toggle button
    addAndMakeVisible(viewModeButton);
    viewModeButton.setButtonText("View: Arrangement");
    viewModeButton.setTooltip("Toggle Arrangement/Session view (Tab key)");
    viewModeButton.onClick = [this]() { toggleViewMode(); };

    transportBar = std::make_unique<TransportBar>(*audioEngine);
    addAndMakeVisible(transportBar.get());

    // Register keyboard listener
    addKeyListener(this);
    setWantsKeyboardFocus(true);

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

    // View mode button bar: 35px
    auto viewModeBar = bounds.removeFromTop(35);
    viewModeButton.setBounds(viewModeBar.removeFromLeft(200).reduced(5, 5));

    // Transport bar: 60px (bottom)
    if (transportBar)
        transportBar->setBounds(bounds.removeFromBottom(60));

    // Views: remaining space (both get same bounds, only one visible at a time)
    if (trackView)
        trackView->setBounds(bounds);

    if (sessionView)
        sessionView->setBounds(bounds);
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
// View Mode Management
//==============================================================================

void MainWindow::MainComponent::setViewMode(ViewMode mode)
{
    if (currentViewMode == mode)
        return;

    currentViewMode = mode;
    updateViewVisibility();

    // Update button text
    if (mode == ViewMode::Arrangement)
    {
        viewModeButton.setButtonText("View: Arrangement");
        viewModeButton.setColour(juce::TextButton::buttonColourId, VaporwaveColors::Cyan.withAlpha(0.3f));
    }
    else
    {
        viewModeButton.setButtonText("View: Session/Clip");
        viewModeButton.setColour(juce::TextButton::buttonColourId, VaporwaveColors::Magenta.withAlpha(0.3f));
    }

    repaint();
}

void MainWindow::MainComponent::toggleViewMode()
{
    setViewMode(
        currentViewMode == ViewMode::Arrangement
            ? ViewMode::Session
            : ViewMode::Arrangement
    );
}

void MainWindow::MainComponent::updateViewVisibility()
{
    if (trackView)
        trackView->setVisible(currentViewMode == ViewMode::Arrangement);

    if (sessionView)
        sessionView->setVisible(currentViewMode == ViewMode::Session);
}

bool MainWindow::MainComponent::keyPressed(const juce::KeyPress& key, Component* originatingComponent)
{
    juce::ignoreUnused(originatingComponent);

    // Tab key toggles view mode
    if (key == juce::KeyPress::tabKey && !key.getModifiers().isAnyModifierKeyDown())
    {
        toggleViewMode();
        return true;
    }

    return false;
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
        // TODO: Open settings
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

//==============================================================================
// Unified Track Management (EXTENDED)
//==============================================================================

void MainWindow::MainComponent::TrackView::addAudioTrack(const juce::String& name, juce::Colour color)
{
    UnifiedTrack track;
    track.type = TrackType::Audio;
    track.name = name;
    track.waveformColor = color;
    track.trackColor = color;
    track.audioBuffer = std::make_shared<juce::AudioBuffer<float>>(2, 48000);  // Stereo, 1 sec @ 48kHz
    unifiedTracks.push_back(track);
    repaint();
}

void MainWindow::MainComponent::TrackView::addVideoTrack(const juce::String& name, const VideoWeaver::Clip& clip)
{
    UnifiedTrack track;
    track.type = TrackType::Video;
    track.name = name;
    track.videoClip = clip;
    track.trackColor = juce::Colour(0xffff00ff);  // Magenta for video
    unifiedTracks.push_back(track);
    repaint();
}

void MainWindow::MainComponent::TrackView::addAutomationTrack(const juce::String& parameter,
                                                                const ParameterAutomationUI::ParameterLane& lane)
{
    UnifiedTrack track;
    track.type = TrackType::Automation;
    track.name = "Automation: " + parameter;
    track.automationLane = lane;
    track.trackColor = juce::Colour(0xff651fff);  // Purple for automation
    track.height = 60.0f;  // Automation tracks are shorter
    unifiedTracks.push_back(track);
    repaint();
}

MainWindow::MainComponent::TrackView::UnifiedTrack&
MainWindow::MainComponent::TrackView::getTrack(int index)
{
    return unifiedTracks[index];
}

const MainWindow::MainComponent::TrackView::UnifiedTrack&
MainWindow::MainComponent::TrackView::getTrack(int index) const
{
    return unifiedTracks[index];
}

void MainWindow::MainComponent::TrackView::removeTrack(int index)
{
    if (index >= 0 && index < static_cast<int>(unifiedTracks.size()))
    {
        unifiedTracks.erase(unifiedTracks.begin() + index);
        repaint();
    }
}

void MainWindow::MainComponent::TrackView::clearTracks()
{
    unifiedTracks.clear();
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
    // Check unified tracks first, fallback to engine tracks
    int numTracks = !unifiedTracks.empty() ? static_cast<int>(unifiedTracks.size()) : audioEngine.getNumTracks();

    if (numTracks == 0)
    {
        g.setColour(VaporwaveColors::TextDim);
        g.setFont(juce::Font(16.0f));
        g.drawText("No tracks yet. Add audio, video, or automation tracks!", bounds, juce::Justification::centred);
        return;
    }

    // Draw unified tracks
    float currentY = -(float)verticalScrollBar->getCurrentRangeStart() * (float)trackHeight;

    if (!unifiedTracks.empty())
    {
        // NEW: Draw unified tracks (audio + video + automation)
        for (size_t i = 0; i < unifiedTracks.size(); ++i)
        {
            const auto& track = unifiedTracks[i];

            if (!track.visible)
                continue;

            juce::Rectangle<int> trackBounds(
                bounds.getX(),
                bounds.getY() + static_cast<int>(currentY),
                bounds.getWidth(),
                static_cast<int>(track.height)
            );

            // Skip if not visible
            if (trackBounds.getBottom() < bounds.getY() || trackBounds.getY() > bounds.getBottom())
            {
                currentY += track.height;
                continue;
            }

            // Track background (alternating colors)
            g.setColour(i % 2 == 0 ? VaporwaveColors::Surface : VaporwaveColors::Background);
            g.fillRect(trackBounds);

            // Track name
            g.setColour(VaporwaveColors::Text);
            g.setFont(juce::Font(14.0f, juce::Font::bold));
            g.drawText(track.name, trackBounds.reduced(10, 5), juce::Justification::topLeft);

            // Draw track content based on type
            auto contentBounds = trackBounds.reduced(10, 25);

            switch (track.type)
            {
                case TrackType::Audio:
                    drawAudioWaveform(g, contentBounds, track);
                    break;

                case TrackType::Video:
                    drawVideoClip(g, contentBounds, track);
                    break;

                case TrackType::Automation:
                    drawAutomationLane(g, contentBounds, track);
                    break;
            }

            // Track border (color-coded by type)
            g.setColour(track.trackColor.withAlpha(0.5f));
            g.drawRect(trackBounds, 1.0f);

            // Mute/Solo indicators
            if (track.muted)
            {
                g.setColour(juce::Colours::red.withAlpha(0.3f));
                g.fillRect(trackBounds);
                g.setColour(juce::Colours::red);
                g.drawText("M", trackBounds.getRight() - 30, trackBounds.getY() + 5, 20, 20, juce::Justification::centred);
            }
            if (track.solo)
            {
                g.setColour(juce::Colours::yellow);
                g.drawText("S", trackBounds.getRight() - 50, trackBounds.getY() + 5, 20, 20, juce::Justification::centred);
            }

            currentY += track.height;
        }
    }
    else
    {
        // FALLBACK: Draw legacy audio tracks from engine
        for (int i = 0; i < numTracks; ++i)
        {
            auto track = audioEngine.getTrack(i);
            if (!track)
                continue;

            juce::Rectangle<float> trackBounds(
                (float)bounds.getX(),
                (float)bounds.getY() + currentY,
                (float)bounds.getWidth(),
                (float)trackHeight
            );

            if (trackBounds.getBottom() < bounds.getY() || trackBounds.getY() > bounds.getBottom())
            {
                currentY += (float)trackHeight;
                continue;
            }

            g.setColour(i % 2 == 0 ? VaporwaveColors::Surface : VaporwaveColors::Background);
            g.fillRect(trackBounds);

            g.setColour(VaporwaveColors::Text);
            g.setFont(juce::Font(14.0f, juce::Font::bold));
            g.drawText(track->getName(), trackBounds.reduced(10, 5).toNearestInt(), juce::Justification::topLeft);

            auto waveformBounds = trackBounds.reduced(10, 25);
            g.setColour(VaporwaveColors::Cyan.withAlpha(0.3f));

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

            g.setColour(VaporwaveColors::Cyan.withAlpha(0.3f));
            g.drawRect(trackBounds, 1.0f);

            currentY += (float)trackHeight;
        }
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
// Extended Drawing Methods for Unified Tracks
//==============================================================================

void MainWindow::MainComponent::TrackView::drawAudioWaveform(juce::Graphics& g,
                                                              juce::Rectangle<int> bounds,
                                                              const UnifiedTrack& track)
{
    g.setColour(track.waveformColor.withAlpha(0.3f));

    // Draw simplified waveform (will be replaced with real audio data)
    juce::Path waveformPath;
    bool started = false;

    for (float x = static_cast<float>(bounds.getX()); x < bounds.getRight(); x += 2.0f)
    {
        float y = bounds.getCentreY() + (juce::Random::getSystemRandom().nextFloat() * 20.0f - 10.0f);

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

    // Audio indicator
    g.setColour(VaporwaveColors::Cyan.withAlpha(0.6f));
    g.drawText("♪ AUDIO", bounds.getX() + 5, bounds.getY(), 60, 20, juce::Justification::centredLeft);
}

void MainWindow::MainComponent::TrackView::drawVideoClip(juce::Graphics& g,
                                                           juce::Rectangle<int> bounds,
                                                           const UnifiedTrack& track)
{
    // Video clip background
    g.setColour(VaporwaveColors::Magenta.withAlpha(0.2f));
    g.fillRect(bounds);

    // Render video thumbnail if VideoWeaver is available
    if (videoWeaver && track.videoClip.sourceFile.existsAsFile())
    {
        // Render video frame at clip start time
        auto frameTime = track.videoClip.startTime;
        auto thumbnail = videoWeaver->renderFrame(frameTime);

        if (thumbnail.isValid())
        {
            g.drawImage(thumbnail, bounds.toFloat(),
                       juce::RectanglePlacement::centred | juce::RectanglePlacement::onlyReduceInSize);
        }
    }
    else
    {
        // Placeholder for video clip
        g.setColour(VaporwaveColors::Magenta.withAlpha(0.5f));
        g.drawRect(bounds, 2.0f);

        g.setColour(VaporwaveColors::Text);
        g.setFont(juce::Font(12.0f));
        g.drawText("🎥 " + track.videoClip.name, bounds, juce::Justification::centred);
    }

    // Bio-reactive indicator
    if (track.bioReactive)
    {
        g.setColour(juce::Colours::green);
        g.fillEllipse(static_cast<float>(bounds.getRight() - 15), static_cast<float>(bounds.getY() + 5), 10.0f, 10.0f);

        g.setColour(VaporwaveColors::Text);
        g.setFont(juce::Font(10.0f));
        g.drawText("💓", bounds.getRight() - 25, bounds.getY(), 20, 15, juce::Justification::centred);
    }

    // Video duration indicator
    g.setColour(VaporwaveColors::Magenta.withAlpha(0.6f));
    juce::String durationText = juce::String(track.videoClip.duration, 1) + "s";
    g.drawText(durationText, bounds.getX() + 5, bounds.getBottom() - 20, 50, 15, juce::Justification::centredLeft);
}

void MainWindow::MainComponent::TrackView::drawAutomationLane(juce::Graphics& g,
                                                                juce::Rectangle<int> bounds,
                                                                const UnifiedTrack& track)
{
    const auto& lane = track.automationLane;

    // Lane background
    g.setColour(VaporwaveColors::Purple.withAlpha(0.1f));
    g.fillRect(bounds);

    // Draw automation curve
    if (!lane.points.empty())
    {
        g.setColour(lane.laneColor);

        juce::Path curvePath;
        bool firstPoint = true;

        for (const auto& point : lane.points)
        {
            float x = beatToX(point.timeInBeats);
            float y = valueToY(point.value, bounds);

            if (firstPoint)
            {
                curvePath.startNewSubPath(x, y);
                firstPoint = false;
            }
            else
            {
                curvePath.lineTo(x, y);
            }
        }

        g.strokePath(curvePath, juce::PathStrokeType(2.0f));

        // Draw automation points
        for (const auto& point : lane.points)
        {
            float x = beatToX(point.timeInBeats);
            float y = valueToY(point.value, bounds);

            g.fillEllipse(x - 4.0f, y - 4.0f, 8.0f, 8.0f);
        }
    }
    else
    {
        // Placeholder for empty automation lane
        g.setColour(VaporwaveColors::Purple.withAlpha(0.4f));
        float centerY = static_cast<float>(bounds.getCentreY());
        g.drawLine(static_cast<float>(bounds.getX()), centerY,
                  static_cast<float>(bounds.getRight()), centerY, 1.0f);
    }

    // Automation parameter name
    g.setColour(VaporwaveColors::Text);
    g.setFont(juce::Font(11.0f));
    g.drawText("⚙️ " + lane.displayName, bounds.getX() + 5, bounds.getY(), 100, 15, juce::Justification::centredLeft);
}

//==============================================================================
// Helper Methods
//==============================================================================

float MainWindow::MainComponent::TrackView::beatToX(double beat) const
{
    double tempo = audioEngine.getTempo();
    double beatsPerSecond = tempo / 60.0;
    double timeInSeconds = beat / beatsPerSecond;

    double startTime = horizontalScrollBar->getCurrentRangeStart();
    double visibleDuration = horizontalScrollBar->getCurrentRangeSize();

    if (timeInSeconds < startTime || timeInSeconds > startTime + visibleDuration)
        return -1.0f;  // Out of visible range

    double normalizedPos = (timeInSeconds - startTime) / visibleDuration;
    return static_cast<float>(normalizedPos * getWidth());
}

double MainWindow::MainComponent::TrackView::xToBeat(float x) const
{
    double tempo = audioEngine.getTempo();
    double beatsPerSecond = tempo / 60.0;

    double startTime = horizontalScrollBar->getCurrentRangeStart();
    double visibleDuration = horizontalScrollBar->getCurrentRangeSize();

    double normalizedPos = x / getWidth();
    double timeInSeconds = startTime + (normalizedPos * visibleDuration);

    return timeInSeconds * beatsPerSecond;
}

float MainWindow::MainComponent::TrackView::valueToY(float value, juce::Rectangle<int> bounds) const
{
    // value is 0.0 to 1.0 (bottom to top)
    // Invert so 0.0 is at bottom, 1.0 is at top
    float invertedValue = 1.0f - value;
    return bounds.getY() + (invertedValue * bounds.getHeight());
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
