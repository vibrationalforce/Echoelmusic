#include "ClipLauncherGrid.h"

//==============================================================================
// Constructor / Destructor
//==============================================================================

ClipLauncherGrid::ClipLauncherGrid()
{
    setGridSize(8, 8);  // Default: 8 tracks × 8 scenes

    // Start animation timer (30 FPS)
    startTimer(33);
}

ClipLauncherGrid::~ClipLauncherGrid()
{
    stopTimer();
}

//==============================================================================
// Grid Management
//==============================================================================

void ClipLauncherGrid::setGridSize(int newNumTracks, int newNumScenes)
{
    numTracks = newNumTracks;
    numScenes = newNumScenes;

    // Resize grid
    clips.resize(numTracks);
    for (auto& column : clips)
    {
        column.resize(numScenes);
    }

    // Resize scenes
    scenes.resize(numScenes);

    // Initialize scene names
    for (int i = 0; i < numScenes; ++i)
    {
        scenes[i].name = "Scene " + juce::String(i + 1);
    }

    repaint();
}

ClipLauncherGrid::ClipSlot& ClipLauncherGrid::getClip(int trackIndex, int sceneIndex)
{
    return clips[trackIndex][sceneIndex];
}

const ClipLauncherGrid::ClipSlot& ClipLauncherGrid::getClip(int trackIndex, int sceneIndex) const
{
    return clips[trackIndex][sceneIndex];
}

void ClipLauncherGrid::setClip(int trackIndex, int sceneIndex, const ClipSlot& clip)
{
    if (trackIndex >= 0 && trackIndex < numTracks &&
        sceneIndex >= 0 && sceneIndex < numScenes)
    {
        clips[trackIndex][sceneIndex] = clip;
        repaint();
    }
}

ClipLauncherGrid::Scene& ClipLauncherGrid::getScene(int sceneIndex)
{
    return scenes[sceneIndex];
}

const ClipLauncherGrid::Scene& ClipLauncherGrid::getScene(int sceneIndex) const
{
    return scenes[sceneIndex];
}

void ClipLauncherGrid::setScene(int sceneIndex, const Scene& scene)
{
    if (sceneIndex >= 0 && sceneIndex < numScenes)
    {
        scenes[sceneIndex] = scene;
        repaint();
    }
}

//==============================================================================
// Playback Control
//==============================================================================

void ClipLauncherGrid::triggerClip(int trackIndex, int sceneIndex)
{
    if (trackIndex < 0 || trackIndex >= numTracks ||
        sceneIndex < 0 || sceneIndex >= numScenes)
        return;

    auto& clip = clips[trackIndex][sceneIndex];

    if (clip.type == ClipSlot::Type::Empty)
        return;

    // Stop all other clips in this track (only one clip per track can play)
    for (int s = 0; s < numScenes; ++s)
    {
        if (s != sceneIndex)
            clips[trackIndex][s].isPlaying = false;
    }

    // Toggle clip playback
    clip.isPlaying = !clip.isPlaying;
    clip.playProgress = 0.0f;

    if (onClipTriggered)
        onClipTriggered(trackIndex, sceneIndex);

    repaint();
}

void ClipLauncherGrid::stopClip(int trackIndex, int sceneIndex)
{
    if (trackIndex < 0 || trackIndex >= numTracks ||
        sceneIndex < 0 || sceneIndex >= numScenes)
        return;

    auto& clip = clips[trackIndex][sceneIndex];
    clip.isPlaying = false;
    clip.playProgress = 0.0f;

    if (onClipStopped)
        onClipStopped(trackIndex, sceneIndex);

    repaint();
}

void ClipLauncherGrid::launchScene(int sceneIndex)
{
    if (sceneIndex < 0 || sceneIndex >= numScenes)
        return;

    // Trigger all non-empty clips in this scene
    for (int t = 0; t < numTracks; ++t)
    {
        auto& clip = clips[t][sceneIndex];
        if (clip.type != ClipSlot::Type::Empty)
        {
            triggerClip(t, sceneIndex);
        }
    }

    scenes[sceneIndex].isTriggered = true;

    if (onSceneLaunched)
        onSceneLaunched(sceneIndex);

    repaint();
}

void ClipLauncherGrid::stopAll()
{
    for (int t = 0; t < numTracks; ++t)
    {
        for (int s = 0; s < numScenes; ++s)
        {
            clips[t][s].isPlaying = false;
            clips[t][s].playProgress = 0.0f;
        }
    }

    for (auto& scene : scenes)
        scene.isTriggered = false;

    repaint();
}

void ClipLauncherGrid::stopTrack(int trackIndex)
{
    if (trackIndex < 0 || trackIndex >= numTracks)
        return;

    for (int s = 0; s < numScenes; ++s)
    {
        clips[trackIndex][s].isPlaying = false;
        clips[trackIndex][s].playProgress = 0.0f;
    }

    repaint();
}

//==============================================================================
// Bio-Reactive
//==============================================================================

void ClipLauncherGrid::setBioData(float hrv, float coherence, float stress)
{
    currentHRV = hrv;
    currentCoherence = coherence;
    currentStress = stress;

    updateBioModulation();
}

void ClipLauncherGrid::updateBioData(const Echoelmusic::BioFeedbackSystem::UnifiedBioData& bioData)
{
    currentHRV = bioData.hrv;
    currentCoherence = bioData.coherence;
    currentStress = bioData.stress;

    updateBioModulation();
}

void ClipLauncherGrid::updateBioModulation()
{
    // Update bio modulation for all bio-reactive clips
    for (int t = 0; t < numTracks; ++t)
    {
        for (int s = 0; s < numScenes; ++s)
        {
            auto& clip = clips[t][s];

            if (!clip.bioReactive)
                continue;

            if (clip.bioParameter == "hrv")
            {
                clip.bioModulation = currentHRV;
            }
            else if (clip.bioParameter == "coherence")
            {
                clip.bioModulation = currentCoherence;
            }
            else if (clip.bioParameter == "stress")
            {
                clip.bioModulation = currentStress;
            }
        }
    }
}

//==============================================================================
// Component
//==============================================================================

void ClipLauncherGrid::paint(juce::Graphics& g)
{
    // Background
    g.fillAll(juce::Colour(0xff0a0a0a));

    // Draw grid
    auto bounds = getLocalBounds();
    int sceneButtonWidth = 100;
    int stopButtonHeight = 30;

    auto gridArea = bounds.reduced(5, 5);
    gridArea.removeFromRight(sceneButtonWidth);
    gridArea.removeFromBottom(stopButtonHeight);

    // Draw clip slots
    for (int t = 0; t < numTracks; ++t)
    {
        for (int s = 0; s < numScenes; ++s)
        {
            auto clipBounds = getClipBounds(t, s);
            const auto& clip = clips[t][s];

            drawClipSlot(g, clip, clipBounds);
        }
    }

    // Draw scene buttons
    for (int s = 0; s < numScenes; ++s)
    {
        auto sceneBounds = getSceneBounds(s);
        drawScene(g, scenes[s], sceneBounds, s);
    }

    // Draw stop buttons
    for (int t = 0; t < numTracks; ++t)
    {
        auto stopBounds = getStopTrackBounds(t);
        drawStopButton(g, stopBounds, t);
    }

    // Draw track labels
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(10.0f));

    for (int t = 0; t < numTracks; ++t)
    {
        auto labelBounds = getClipBounds(t, 0);
        labelBounds.setY(bounds.getY() - 15);
        labelBounds.setHeight(15);

        g.drawText("Track " + juce::String(t + 1), labelBounds, juce::Justification::centred);
    }

    // Status bar
    auto statusBounds = bounds.removeFromBottom(20);
    g.setColour(juce::Colour(0xff1a1a2e));
    g.fillRect(statusBounds);

    g.setColour(juce::Colours::cyan);
    g.setFont(juce::Font(12.0f));

    juce::String statusText = "BPM: " + juce::String(currentBPM, 1) +
                             " | Quantize: " + (quantizeEnabled ? "ON" : "OFF") +
                             " | Bio: HR=" + juce::String(currentHRV * 100.0f, 0) + "% " +
                             "Coh=" + juce::String(currentCoherence * 100.0f, 0) + "%";

    g.drawText(statusText, statusBounds.reduced(5, 2), juce::Justification::centredLeft);
}

void ClipLauncherGrid::resized()
{
    // Grid layout is calculated in getClipBounds()
}

void ClipLauncherGrid::mouseDown(const juce::MouseEvent& event)
{
    int trackIndex, sceneIndex;

    // Check if clicking on clip
    getClipAtPosition(event.x, event.y, trackIndex, sceneIndex);

    if (trackIndex >= 0 && sceneIndex >= 0)
    {
        triggerClip(trackIndex, sceneIndex);
        return;
    }

    // Check if clicking on scene button
    if (isSceneButtonAtPosition(event.x, event.y, sceneIndex))
    {
        launchScene(sceneIndex);
        return;
    }

    // Check if clicking on stop button
    if (isStopButtonAtPosition(event.x, event.y, trackIndex))
    {
        stopTrack(trackIndex);
        return;
    }
}

void ClipLauncherGrid::mouseEnter(const juce::MouseEvent& event)
{
    juce::ignoreUnused(event);
}

void ClipLauncherGrid::mouseMove(const juce::MouseEvent& event)
{
    int trackIndex, sceneIndex;
    getClipAtPosition(event.x, event.y, trackIndex, sceneIndex);

    if (trackIndex != hoveredTrack || sceneIndex != hoveredScene)
    {
        hoveredTrack = trackIndex;
        hoveredScene = sceneIndex;
        repaint();
    }
}

void ClipLauncherGrid::mouseExit(const juce::MouseEvent& event)
{
    juce::ignoreUnused(event);
    hoveredTrack = -1;
    hoveredScene = -1;
    repaint();
}

//==============================================================================
// Timer Callback
//==============================================================================

void ClipLauncherGrid::timerCallback()
{
    // Update animation phase
    pulsePhase += 0.05f;
    if (pulsePhase > 1.0f)
        pulsePhase = 0.0f;

    // Update clip play progress (simulated)
    bool needsRepaint = false;

    for (int t = 0; t < numTracks; ++t)
    {
        for (int s = 0; s < numScenes; ++s)
        {
            auto& clip = clips[t][s];

            if (clip.isPlaying)
            {
                // Simulate clip playback progress
                double progressIncrement = (currentBPM / 60.0) / (clip.loopLength * 30.0);  // 30 FPS
                clip.playProgress += static_cast<float>(progressIncrement);

                if (clip.playProgress >= 1.0f)
                {
                    clip.playProgress = 0.0f;  // Loop

                    // Check follow actions
                    if (clip.followActionEnabled && clip.nextClipIndex >= 0)
                    {
                        stopClip(t, s);
                        if (clip.nextClipIndex < numScenes)
                            triggerClip(t, clip.nextClipIndex);
                    }
                }

                needsRepaint = true;
            }
        }
    }

    // Update follow actions
    updateFollowActions();

    if (needsRepaint)
        repaint();
}

//==============================================================================
// Helper Methods
//==============================================================================

juce::Rectangle<int> ClipLauncherGrid::getClipBounds(int trackIndex, int sceneIndex) const
{
    auto bounds = getLocalBounds().reduced(5, 5);
    int sceneButtonWidth = 100;
    int stopButtonHeight = 30;

    auto gridArea = bounds;
    gridArea.removeFromRight(sceneButtonWidth);
    gridArea.removeFromBottom(stopButtonHeight);

    int clipWidth = gridArea.getWidth() / numTracks;
    int clipHeight = gridArea.getHeight() / numScenes;

    int x = gridArea.getX() + (trackIndex * clipWidth);
    int y = gridArea.getY() + (sceneIndex * clipHeight);

    return juce::Rectangle<int>(x + 2, y + 2, clipWidth - 4, clipHeight - 4);
}

juce::Rectangle<int> ClipLauncherGrid::getSceneBounds(int sceneIndex) const
{
    auto bounds = getLocalBounds().reduced(5, 5);
    int sceneButtonWidth = 100;
    int stopButtonHeight = 30;

    auto gridArea = bounds;
    gridArea.removeFromRight(sceneButtonWidth);
    gridArea.removeFromBottom(stopButtonHeight);

    int clipHeight = gridArea.getHeight() / numScenes;
    int y = gridArea.getY() + (sceneIndex * clipHeight);

    int sceneX = gridArea.getRight() + 5;

    return juce::Rectangle<int>(sceneX, y + 2, sceneButtonWidth - 10, clipHeight - 4);
}

juce::Rectangle<int> ClipLauncherGrid::getStopTrackBounds(int trackIndex) const
{
    auto bounds = getLocalBounds().reduced(5, 5);
    int sceneButtonWidth = 100;
    int stopButtonHeight = 30;

    auto gridArea = bounds;
    gridArea.removeFromRight(sceneButtonWidth);

    int clipWidth = gridArea.getWidth() / numTracks;
    int x = gridArea.getX() + (trackIndex * clipWidth);
    int stopY = gridArea.getBottom() + 5;

    return juce::Rectangle<int>(x + 2, stopY, clipWidth - 4, stopButtonHeight - 10);
}

void ClipLauncherGrid::drawClipSlot(juce::Graphics& g, const ClipSlot& clip, juce::Rectangle<int> bounds)
{
    // Determine clip color
    juce::Colour clipColor;

    switch (clip.type)
    {
        case ClipSlot::Type::Empty:
            clipColor = emptySlotColor;
            break;
        case ClipSlot::Type::Audio:
            clipColor = clip.color.isTransparent() ? audioSlotColor : clip.color;
            break;
        case ClipSlot::Type::Video:
            clipColor = clip.color.isTransparent() ? videoSlotColor : clip.color;
            break;
        case ClipSlot::Type::Generated:
            clipColor = clip.color.isTransparent() ? generatedSlotColor : clip.color;
            break;
    }

    // Playing animation (pulsing)
    if (clip.isPlaying)
    {
        float pulse = 0.5f + (std::sin(pulsePhase * juce::MathConstants<float>::twoPi) * 0.5f);
        clipColor = clipColor.brighter(pulse * 0.5f);
    }

    // Background
    g.setColour(clipColor.withAlpha(0.3f));
    g.fillRoundedRectangle(bounds.toFloat(), 4.0f);

    // Border
    g.setColour(clipColor);
    g.drawRoundedRectangle(bounds.toFloat().reduced(1.0f), 4.0f, 2.0f);

    // Hover effect
    if (bounds.contains(hoveredTrack >= 0 ? getClipBounds(hoveredTrack, hoveredScene) : juce::Rectangle<int>()))
    {
        g.setColour(juce::Colours::white.withAlpha(0.2f));
        g.fillRoundedRectangle(bounds.toFloat(), 4.0f);
    }

    // Clip content
    if (clip.type != ClipSlot::Type::Empty)
    {
        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(11.0f));

        // Clip name
        auto nameBounds = bounds.reduced(5, 3);
        g.drawText(clip.name, nameBounds, juce::Justification::topLeft);

        // Play progress bar
        if (clip.isPlaying)
        {
            auto progressBounds = bounds.removeFromBottom(4).reduced(2, 0);
            g.setColour(clipColor);
            g.fillRect(progressBounds.removeFromLeft(static_cast<int>(progressBounds.getWidth() * clip.playProgress)));
        }

        // Bio-reactive indicator
        if (clip.bioReactive)
        {
            g.setColour(juce::Colours::green);
            g.fillEllipse(bounds.getRight() - 12.0f, bounds.getY() + 5.0f, 8.0f, 8.0f);

            // Bio modulation level
            g.setColour(juce::Colours::white);
            g.setFont(juce::Font(9.0f));
            g.drawText(juce::String(static_cast<int>(clip.bioModulation * 100)) + "%",
                      bounds.getRight() - 35, bounds.getY() + 20, 30, 12, juce::Justification::centredRight);
        }
    }
    else
    {
        // Empty slot - show + icon
        g.setColour(juce::Colours::white.withAlpha(0.3f));
        g.setFont(juce::Font(24.0f));
        g.drawText("+", bounds, juce::Justification::centred);
    }
}

void ClipLauncherGrid::drawScene(juce::Graphics& g, const Scene& scene, juce::Rectangle<int> bounds, int sceneIndex)
{
    juce::ignoreUnused(sceneIndex);

    // Background
    g.setColour(scene.color.withAlpha(0.3f));
    g.fillRoundedRectangle(bounds.toFloat(), 4.0f);

    // Border
    g.setColour(scene.color);
    g.drawRoundedRectangle(bounds.toFloat().reduced(1.0f), 4.0f, 2.0f);

    // Triggered animation
    if (scene.isTriggered)
    {
        g.setColour(scene.color.brighter(0.5f));
        g.fillRoundedRectangle(bounds.toFloat().reduced(2.0f), 3.0f);
    }

    // Scene name
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(12.0f, juce::Font::bold));
    g.drawText(scene.name, bounds.reduced(5, 3), juce::Justification::centred);

    // Play icon
    g.setFont(juce::Font(16.0f));
    g.drawText("▶", bounds.getRight() - 25, bounds.getY(), 20, 20, juce::Justification::centred);
}

void ClipLauncherGrid::drawStopButton(juce::Graphics& g, juce::Rectangle<int> bounds, int trackIndex)
{
    juce::ignoreUnused(trackIndex);

    // Background
    g.setColour(juce::Colours::darkred.withAlpha(0.5f));
    g.fillRoundedRectangle(bounds.toFloat(), 3.0f);

    // Border
    g.setColour(juce::Colours::red);
    g.drawRoundedRectangle(bounds.toFloat().reduced(1.0f), 3.0f, 1.5f);

    // Stop icon
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(14.0f));
    g.drawText("⏹", bounds, juce::Justification::centred);
}

void ClipLauncherGrid::getClipAtPosition(int x, int y, int& trackIndex, int& sceneIndex) const
{
    trackIndex = -1;
    sceneIndex = -1;

    for (int t = 0; t < numTracks; ++t)
    {
        for (int s = 0; s < numScenes; ++s)
        {
            if (getClipBounds(t, s).contains(x, y))
            {
                trackIndex = t;
                sceneIndex = s;
                return;
            }
        }
    }
}

bool ClipLauncherGrid::isSceneButtonAtPosition(int x, int y, int& sceneIndex) const
{
    for (int s = 0; s < numScenes; ++s)
    {
        if (getSceneBounds(s).contains(x, y))
        {
            sceneIndex = s;
            return true;
        }
    }

    sceneIndex = -1;
    return false;
}

bool ClipLauncherGrid::isStopButtonAtPosition(int x, int y, int& trackIndex) const
{
    for (int t = 0; t < numTracks; ++t)
    {
        if (getStopTrackBounds(t).contains(x, y))
        {
            trackIndex = t;
            return true;
        }
    }

    trackIndex = -1;
    return false;
}

void ClipLauncherGrid::updateFollowActions()
{
    // Check follow actions for playing clips
    // This is called from timer callback
    // Implementation can be extended for more complex follow action logic
}
