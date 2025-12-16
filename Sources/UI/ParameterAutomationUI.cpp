#include "ParameterAutomationUI.h"

//==============================================================================
// ParameterAutomationUI Implementation
//==============================================================================

ParameterAutomationUI::ParameterAutomationUI()
{
    // Create UI components
    transportBar = std::make_unique<TransportBar>(*this);
    addAndMakeVisible(transportBar.get());

    laneList = std::make_unique<ParameterLaneList>(*this);
    addAndMakeVisible(laneList.get());

    timelineEditor = std::make_unique<TimelineEditor>(*this);
    addAndMakeVisible(timelineEditor.get());

    editToolbar = std::make_unique<EditToolbar>(*this);
    addAndMakeVisible(editToolbar.get());

    // Transport callbacks
    transportBar->onPlay = [this]()
    {
        isPlaying = true;
        isRecording = false;
    };

    transportBar->onStop = [this]()
    {
        isPlaying = false;
        isRecording = false;
        currentPlayheadBeat = 0.0;
        timelineEditor->setPlayheadPosition(0.0);
    };

    transportBar->onRecord = [this]()
    {
        isPlaying = true;
        isRecording = true;
        currentPlayheadBeat = 0.0;
    };

    transportBar->onRewind = [this]()
    {
        currentPlayheadBeat = 0.0;
        timelineEditor->setPlayheadPosition(0.0);
    };

    // Timeline callbacks
    timelineEditor->onPointAdded = [this](int laneIndex, const AutomationPoint& point)
    {
        if (laneIndex >= 0 && laneIndex < static_cast<int>(parameterLanes.size()))
        {
            parameterLanes[laneIndex].points.push_back(point);
            std::sort(parameterLanes[laneIndex].points.begin(),
                     parameterLanes[laneIndex].points.end());
            timelineEditor->updateLanes(parameterLanes);
        }
    };

    timelineEditor->onPointMoved = [this](int laneIndex, int pointIndex, const AutomationPoint& newPoint)
    {
        if (laneIndex >= 0 && laneIndex < static_cast<int>(parameterLanes.size()) &&
            pointIndex >= 0 && pointIndex < static_cast<int>(parameterLanes[laneIndex].points.size()))
        {
            parameterLanes[laneIndex].points[pointIndex] = newPoint;
            std::sort(parameterLanes[laneIndex].points.begin(),
                     parameterLanes[laneIndex].points.end());
            timelineEditor->updateLanes(parameterLanes);
        }
    };

    timelineEditor->onPointDeleted = [this](int laneIndex, int pointIndex)
    {
        if (laneIndex >= 0 && laneIndex < static_cast<int>(parameterLanes.size()) &&
            pointIndex >= 0 && pointIndex < static_cast<int>(parameterLanes[laneIndex].points.size()))
        {
            parameterLanes[laneIndex].points.erase(
                parameterLanes[laneIndex].points.begin() + pointIndex);
            timelineEditor->updateLanes(parameterLanes);
        }
    };

    // Initialize parameter lanes
    initializeParameterLanes();

    // Start timer for playback (60 Hz)
    startTimerHz(60);

    setSize(1000, 600);
}

ParameterAutomationUI::~ParameterAutomationUI()
{
    stopTimer();
}

void ParameterAutomationUI::setDSPManager(AdvancedDSPManager* manager)
{
    dspManager = manager;
    initializeParameterLanes();
}

void ParameterAutomationUI::paint(juce::Graphics& g)
{
    // Background gradient
    g.fillAll(juce::Colour(0xff1a1a1f));

    auto bounds = getLocalBounds();
    juce::ColourGradient gradient(juce::Colour(0xff1a1a1f), 0.0f, 0.0f,
                                  juce::Colour(0xff0d0d10), 0.0f, static_cast<float>(bounds.getHeight()),
                                  false);
    g.setGradientFill(gradient);
    g.fillRect(bounds);

    // Title
    g.setColour(juce::Colour(0xffe8e8e8));
    g.setFont(juce::Font(22.0f, juce::Font::bold));
    g.drawText("Parameter Automation", bounds.removeFromTop(50).reduced(20, 10),
               juce::Justification::centredLeft);
}

void ParameterAutomationUI::resized()
{
    auto bounds = getLocalBounds();

    // Top margin for title
    bounds.removeFromTop(50);

    // Transport bar
    transportBar->setBounds(bounds.removeFromTop(60).reduced(10, 5));

    // Edit toolbar
    editToolbar->setBounds(bounds.removeFromTop(50).reduced(10, 5));

    // Main content: lane list (left) + timeline editor (right)
    auto contentBounds = bounds.reduced(10);

    auto laneListBounds = contentBounds.removeFromLeft(200);
    laneList->setBounds(laneListBounds);

    contentBounds.removeFromLeft(5); // Spacing

    timelineEditor->setBounds(contentBounds);
}

void ParameterAutomationUI::timerCallback()
{
    if (isPlaying)
    {
        // Advance playhead (simplified - in production would sync with audio)
        double beatsPerSecond = tempo / 60.0;
        double beatsPerFrame = beatsPerSecond / 60.0; // 60 FPS

        currentPlayheadBeat += beatsPerFrame;

        timelineEditor->setPlayheadPosition(currentPlayheadBeat);

        // Record automation if armed
        if (isRecording)
        {
            for (size_t i = 0; i < parameterLanes.size(); ++i)
            {
                if (parameterLanes[i].armed)
                {
                    // In production: would read current parameter value from DSP
                    float currentValue = 0.5f; // Placeholder
                    recordAutomationPoint(static_cast<int>(i), currentPlayheadBeat, currentValue);
                }
            }
        }

        // Apply automation
        updateAutomation();
    }
}

void ParameterAutomationUI::initializeParameterLanes()
{
    parameterLanes.clear();

    // Create lanes for each automatable parameter
    // Mid/Side Tone Matching
    parameterLanes.push_back({"ms_matching_strength", "M/S: Matching Strength", 0.0f, 1.0f, {},
                              true, false, juce::Colour(0xff00d4ff)});

    // Audio Humanizer
    parameterLanes.push_back({"humanizer_amount", "Humanizer: Amount", 0.0f, 1.0f, {},
                              true, false, juce::Colour(0xff00ff88)});
    parameterLanes.push_back({"humanizer_spectral", "Humanizer: Spectral", 0.0f, 1.0f, {},
                              true, false, juce::Colour(0xff88ff00)});

    // Swarm Reverb
    parameterLanes.push_back({"swarm_cohesion", "Swarm: Cohesion", 0.0f, 1.0f, {},
                              true, false, juce::Colour(0xffff00d4)});
    parameterLanes.push_back({"swarm_chaos", "Swarm: Chaos", 0.0f, 1.0f, {},
                              true, false, juce::Colour(0xffd400ff)});
    parameterLanes.push_back({"swarm_mix", "Swarm: Mix", 0.0f, 1.0f, {},
                              true, false, juce::Colour(0xffff8800)});

    // Polyphonic Pitch Editor
    parameterLanes.push_back({"pitch_correction", "Pitch: Correction", 0.0f, 1.0f, {},
                              true, false, juce::Colour(0xff00ffff)});
    parameterLanes.push_back({"pitch_formant", "Pitch: Formant", 0.0f, 1.0f, {},
                              true, false, juce::Colour(0xffffff00)});

    laneList->updateParameterList(parameterLanes);
    timelineEditor->updateLanes(parameterLanes);
}

void ParameterAutomationUI::updateAutomation()
{
    if (!dspManager)
        return;

    // For each lane, interpolate value at current playhead position
    for (const auto& lane : parameterLanes)
    {
        if (lane.points.empty())
            continue;

        // Find surrounding points
        const AutomationPoint* prevPoint = nullptr;
        const AutomationPoint* nextPoint = nullptr;

        for (size_t i = 0; i < lane.points.size(); ++i)
        {
            if (lane.points[i].timeInBeats <= currentPlayheadBeat)
                prevPoint = &lane.points[i];

            if (lane.points[i].timeInBeats > currentPlayheadBeat && !nextPoint)
            {
                nextPoint = &lane.points[i];
                break;
            }
        }

        float value = 0.5f;

        if (prevPoint && nextPoint)
        {
            // Interpolate between points
            double t = (currentPlayheadBeat - prevPoint->timeInBeats) /
                      (nextPoint->timeInBeats - prevPoint->timeInBeats);
            t = juce::jlimit(0.0, 1.0, t);

            // Apply curve type
            switch (prevPoint->curveType)
            {
                case AutomationPoint::CurveType::Linear:
                    value = prevPoint->value + static_cast<float>(t) * (nextPoint->value - prevPoint->value);
                    break;

                case AutomationPoint::CurveType::Exponential:
                    value = prevPoint->value + static_cast<float>(std::pow(t, 2.0)) * (nextPoint->value - prevPoint->value);
                    break;

                case AutomationPoint::CurveType::Logarithmic:
                    value = prevPoint->value + static_cast<float>(std::sqrt(t)) * (nextPoint->value - prevPoint->value);
                    break;

                case AutomationPoint::CurveType::SCurve:
                    {
                        float sCurve = static_cast<float>(t < 0.5 ? 2.0 * t * t : 1.0 - std::pow(-2.0 * t + 2.0, 2.0) / 2.0);
                        value = prevPoint->value + sCurve * (nextPoint->value - prevPoint->value);
                    }
                    break;
            }
        }
        else if (prevPoint)
        {
            value = prevPoint->value;
        }
        else if (nextPoint)
        {
            value = nextPoint->value;
        }

        // Apply to DSP parameter (in production)
        // For now, just demonstrate the concept
        // Example: dspManager->setParameter(lane.parameterName, value);
    }
}

void ParameterAutomationUI::recordAutomationPoint(int laneIndex, double beat, float value)
{
    if (laneIndex < 0 || laneIndex >= static_cast<int>(parameterLanes.size()))
        return;

    AutomationPoint point;
    point.timeInBeats = beat;
    point.value = value;
    point.curveType = AutomationPoint::CurveType::Linear;

    parameterLanes[laneIndex].points.push_back(point);

    // Limit points during recording (thin out to avoid too many)
    if (parameterLanes[laneIndex].points.size() > 1000)
    {
        // Thin out by removing every other point
        std::vector<AutomationPoint> thinned;
        for (size_t i = 0; i < parameterLanes[laneIndex].points.size(); i += 2)
            thinned.push_back(parameterLanes[laneIndex].points[i]);
        parameterLanes[laneIndex].points = thinned;
    }

    std::sort(parameterLanes[laneIndex].points.begin(),
             parameterLanes[laneIndex].points.end());
}

//==============================================================================
// TransportBar Implementation
//==============================================================================

ParameterAutomationUI::TransportBar::TransportBar(ParameterAutomationUI& parent)
    : owner(parent)
{
    playButton.setButtonText("▶ Play");
    addAndMakeVisible(playButton);
    playButton.onClick = [&]()
    {
        if (!playing && onPlay)
            onPlay();
        playing = true;
        recording = false;
        repaint();
    };

    stopButton.setButtonText("■ Stop");
    addAndMakeVisible(stopButton);
    stopButton.onClick = [&]()
    {
        playing = false;
        recording = false;
        if (onStop)
            onStop();
        repaint();
    };

    recordButton.setButtonText("● Record");
    addAndMakeVisible(recordButton);
    recordButton.onClick = [&]()
    {
        if (!recording && onRecord)
            onRecord();
        playing = true;
        recording = true;
        repaint();
    };

    rewindButton.setButtonText("|◄ Rewind");
    addAndMakeVisible(rewindButton);
    rewindButton.onClick = [&]()
    {
        if (onRewind)
            onRewind();
    };

    tempoLabel.setText("Tempo:", juce::dontSendNotification);
    tempoLabel.setColour(juce::Label::textColourId, juce::Colour(0xffe8e8e8));
    addAndMakeVisible(tempoLabel);

    tempoSlider.setSliderStyle(juce::Slider::LinearHorizontal);
    tempoSlider.setRange(40.0, 240.0, 1.0);
    tempoSlider.setValue(120.0);
    tempoSlider.setTextBoxStyle(juce::Slider::TextBoxRight, false, 50, 20);
    addAndMakeVisible(tempoSlider);
    tempoSlider.onValueChange = [&]()
    {
        owner.tempo = tempoSlider.getValue();
    };

    timecodeLabel.setText("00:00.000", juce::dontSendNotification);
    timecodeLabel.setFont(juce::Font(16.0f, juce::Font::bold));
    timecodeLabel.setColour(juce::Label::textColourId, juce::Colour(0xff00d4ff));
    timecodeLabel.setJustificationType(juce::Justification::centredRight);
    addAndMakeVisible(timecodeLabel);
}

void ParameterAutomationUI::TransportBar::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff252530));

    // Update timecode
    double seconds = (owner.currentPlayheadBeat / owner.tempo) * 60.0;
    int mins = static_cast<int>(seconds) / 60;
    double secs = seconds - (mins * 60);

    juce::String timecode = juce::String::formatted("%02d:%06.3f", mins, secs);
    timecodeLabel.setText(timecode, juce::dontSendNotification);

    // Highlight record button when recording
    if (recording)
    {
        auto recordBounds = recordButton.getBounds().toFloat().reduced(2);
        g.setColour(juce::Colour(0xffff4444).withAlpha(0.3f));
        g.fillRoundedRectangle(recordBounds, 4.0f);
    }
}

void ParameterAutomationUI::TransportBar::resized()
{
    auto bounds = getLocalBounds().reduced(10, 5);

    // Transport buttons
    playButton.setBounds(bounds.removeFromLeft(80));
    bounds.removeFromLeft(5);
    stopButton.setBounds(bounds.removeFromLeft(80));
    bounds.removeFromLeft(5);
    recordButton.setBounds(bounds.removeFromLeft(90));
    bounds.removeFromLeft(5);
    rewindButton.setBounds(bounds.removeFromLeft(90));

    bounds.removeFromLeft(20);

    // Tempo
    tempoLabel.setBounds(bounds.removeFromLeft(60));
    bounds.removeFromLeft(5);
    tempoSlider.setBounds(bounds.removeFromLeft(150));

    // Timecode (right aligned)
    timecodeLabel.setBounds(bounds.removeFromRight(120));
}

//==============================================================================
// ParameterLaneList Implementation
//==============================================================================

ParameterAutomationUI::ParameterLaneList::ParameterLaneList(ParameterAutomationUI& parent)
    : owner(parent)
{
    addAndMakeVisible(viewport);
    viewport.setViewedComponent(&contentComponent, false);
    viewport.setScrollBarsShown(true, false);
}

void ParameterAutomationUI::ParameterLaneList::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1f1f24));

    // Border
    g.setColour(juce::Colour(0xff3a3a40));
    g.drawRect(getLocalBounds(), 1);
}

void ParameterAutomationUI::ParameterLaneList::resized()
{
    viewport.setBounds(getLocalBounds());

    // Layout lane items
    int itemHeight = 40;
    int y = 0;

    contentComponent.setBounds(0, 0, getWidth() - 20, laneItems.size() * itemHeight);

    for (auto& item : laneItems)
    {
        item->setBounds(0, y, getWidth() - 20, itemHeight);
        y += itemHeight;
    }
}

void ParameterAutomationUI::ParameterLaneList::updateParameterList(const std::vector<ParameterLane>& lanes)
{
    laneItems.clear();

    for (size_t i = 0; i < lanes.size(); ++i)
    {
        auto item = std::make_unique<LaneListItem>(static_cast<int>(i), lanes[i]);

        item->onClicked = [this](int index)
        {
            selectedLaneIndex = index;
            for (auto& laneItem : laneItems)
                laneItem->selected = (laneItem->laneIndex == index);

            if (onLaneSelected)
                onLaneSelected(index);

            repaint();
        };

        item->onArmChanged = [this](int index, bool armed)
        {
            if (onLaneArmChanged)
                onLaneArmChanged(index, armed);
        };

        contentComponent.addAndMakeVisible(item.get());
        laneItems.push_back(std::move(item));
    }

    resized();
}

//==============================================================================
// LaneListItem Implementation
//==============================================================================

ParameterAutomationUI::ParameterLaneList::LaneListItem::LaneListItem(int index, const ParameterLane& lane)
    : laneIndex(index), laneData(lane)
{
    armButton.setButtonText("R");
    armButton.setToggleState(lane.armed, juce::dontSendNotification);
    addAndMakeVisible(armButton);

    armButton.onClick = [this]()
    {
        if (onArmChanged)
            onArmChanged(laneIndex, armButton.getToggleState());
    };
}

void ParameterAutomationUI::ParameterLaneList::LaneListItem::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds().toFloat();

    // Background
    if (selected)
        g.setColour(juce::Colour(0xff2a2a35));
    else
        g.setColour(juce::Colour(0xff1f1f24));
    g.fillRect(bounds);

    // Lane color indicator
    g.setColour(laneData.laneColor);
    g.fillRect(bounds.removeFromLeft(4));

    bounds.removeFromLeft(5);

    // Lane name
    g.setColour(juce::Colour(0xffe8e8e8));
    g.setFont(12.0f);
    auto textBounds = bounds.reduced(5);
    textBounds.removeFromRight(40); // Space for arm button
    g.drawText(laneData.displayName, textBounds.toNearestInt(), juce::Justification::centredLeft, true);

    // Separator line
    g.setColour(juce::Colour(0xff3a3a40));
    g.drawHorizontalLine(static_cast<int>(getHeight() - 1), 0.0f, static_cast<float>(getWidth()));
}

void ParameterAutomationUI::ParameterLaneList::LaneListItem::resized()
{
    auto bounds = getLocalBounds().reduced(5);
    armButton.setBounds(bounds.removeFromRight(30));
}

void ParameterAutomationUI::ParameterLaneList::LaneListItem::mouseDown(const juce::MouseEvent&)
{
    if (onClicked)
        onClicked(laneIndex);
}

//==============================================================================
// TimelineEditor Implementation
//==============================================================================

ParameterAutomationUI::TimelineEditor::TimelineEditor(ParameterAutomationUI& parent)
    : owner(parent)
{
}

void ParameterAutomationUI::TimelineEditor::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();

    g.fillAll(juce::Colour(0xff1a1a1f));

    // Draw grid
    drawGrid(g, bounds);

    // Draw lanes
    if (!currentLanes.empty())
    {
        int laneHeight = bounds.getHeight() / juce::jmax(1, static_cast<int>(currentLanes.size()));

        for (size_t i = 0; i < currentLanes.size(); ++i)
        {
            if (!currentLanes[i].visible)
                continue;

            auto laneBounds = bounds.removeFromTop(laneHeight);
            drawLane(g, currentLanes[i], static_cast<int>(i), laneBounds);
        }
    }

    // Draw playhead
    if (playheadBeat >= visibleStartBeat && playheadBeat <= visibleEndBeat)
    {
        float playheadX = beatToX(playheadBeat);
        g.setColour(juce::Colour(0xff00d4ff));
        g.drawLine(playheadX, 0.0f, playheadX, static_cast<float>(getHeight()), 2.0f);

        // Playhead triangle at top
        juce::Path triangle;
        triangle.addTriangle(playheadX - 6, 0, playheadX + 6, 0, playheadX, 10);
        g.fillPath(triangle);
    }
}

void ParameterAutomationUI::TimelineEditor::resized()
{
}

void ParameterAutomationUI::TimelineEditor::mouseDown(const juce::MouseEvent& event)
{
    float x = static_cast<float>(event.x);
    float y = static_cast<float>(event.y);
    double beat = xToBeat(x);

    // Find which lane was clicked
    int laneHeight = getHeight() / juce::jmax(1, static_cast<int>(currentLanes.size()));
    int clickedLaneIndex = event.y / laneHeight;

    if (clickedLaneIndex < 0 || clickedLaneIndex >= static_cast<int>(currentLanes.size()))
        return;

    // Check if clicking on existing point
    auto laneBounds = getLocalBounds().removeFromTop(laneHeight * (clickedLaneIndex + 1))
                                       .removeFromBottom(laneHeight);

    const auto& lane = currentLanes[clickedLaneIndex];
    for (size_t i = 0; i < lane.points.size(); ++i)
    {
        float pointX = beatToX(lane.points[i].timeInBeats);
        float pointY = valueToY(lane.points[i].value, clickedLaneIndex);

        if (std::abs(x - pointX) < 8.0f && std::abs(y - pointY) < 8.0f)
        {
            // Clicked on existing point
            if (event.mods.isRightButtonDown())
            {
                // Right click: delete point
                if (onPointDeleted)
                    onPointDeleted(clickedLaneIndex, static_cast<int>(i));
                return;
            }
            else
            {
                // Left click: start dragging
                selectedLaneIndex = clickedLaneIndex;
                selectedPointIndex = static_cast<int>(i);
                draggingPoint = true;
                dragStartPosition = juce::Point<float>(x, y);
                return;
            }
        }
    }

    // No point clicked: add new point
    float value = yToValue(y, clickedLaneIndex);

    if (snapToGrid)
        beat = snapBeat(beat);

    AutomationPoint newPoint;
    newPoint.timeInBeats = beat;
    newPoint.value = juce::jlimit(0.0f, 1.0f, value);
    newPoint.curveType = AutomationPoint::CurveType::Linear;

    if (onPointAdded)
        onPointAdded(clickedLaneIndex, newPoint);
}

void ParameterAutomationUI::TimelineEditor::mouseDrag(const juce::MouseEvent& event)
{
    if (!draggingPoint || selectedLaneIndex < 0 || selectedPointIndex < 0)
        return;

    float x = static_cast<float>(event.x);
    float y = static_cast<float>(event.y);

    double newBeat = xToBeat(x);
    if (snapToGrid)
        newBeat = snapBeat(newBeat);

    float newValue = yToValue(y, selectedLaneIndex);
    newValue = juce::jlimit(0.0f, 1.0f, newValue);

    AutomationPoint newPoint;
    newPoint.timeInBeats = newBeat;
    newPoint.value = newValue;
    newPoint.curveType = currentLanes[selectedLaneIndex].points[selectedPointIndex].curveType;

    if (onPointMoved)
        onPointMoved(selectedLaneIndex, selectedPointIndex, newPoint);
}

void ParameterAutomationUI::TimelineEditor::mouseUp(const juce::MouseEvent&)
{
    draggingPoint = false;
    selectedPointIndex = -1;
}

void ParameterAutomationUI::TimelineEditor::mouseWheelMove(const juce::MouseEvent& event, const juce::MouseWheelDetails& wheel)
{
    // Zoom with mouse wheel
    if (event.mods.isCommandDown())
    {
        double zoomFactor = wheel.deltaY > 0 ? 1.1 : 0.9;
        double visibleRange = visibleEndBeat - visibleStartBeat;
        double newRange = visibleRange * zoomFactor;

        double center = (visibleStartBeat + visibleEndBeat) / 2.0;
        visibleStartBeat = center - newRange / 2.0;
        visibleEndBeat = center + newRange / 2.0;

        visibleStartBeat = juce::jmax(0.0, visibleStartBeat);
        repaint();
    }
    else
    {
        // Pan horizontally
        double panAmount = wheel.deltaY * (visibleEndBeat - visibleStartBeat) * 0.1;
        visibleStartBeat -= panAmount;
        visibleEndBeat -= panAmount;

        visibleStartBeat = juce::jmax(0.0, visibleStartBeat);
        visibleEndBeat = juce::jmax(visibleStartBeat + 1.0, visibleEndBeat);
        repaint();
    }
}

void ParameterAutomationUI::TimelineEditor::setVisibleRange(double startBeat, double endBeat)
{
    visibleStartBeat = startBeat;
    visibleEndBeat = endBeat;
    repaint();
}

void ParameterAutomationUI::TimelineEditor::setPlayheadPosition(double beat)
{
    playheadBeat = beat;
    repaint();
}

void ParameterAutomationUI::TimelineEditor::updateLanes(const std::vector<ParameterLane>& lanes)
{
    currentLanes = lanes;
    repaint();
}

float ParameterAutomationUI::TimelineEditor::beatToX(double beat) const
{
    double normalized = (beat - visibleStartBeat) / (visibleEndBeat - visibleStartBeat);
    return static_cast<float>(normalized * getWidth());
}

double ParameterAutomationUI::TimelineEditor::xToBeat(float x) const
{
    double normalized = x / getWidth();
    return visibleStartBeat + normalized * (visibleEndBeat - visibleStartBeat);
}

float ParameterAutomationUI::TimelineEditor::valueToY(float value, int laneIndex) const
{
    int laneHeight = getHeight() / juce::jmax(1, static_cast<int>(currentLanes.size()));
    int laneY = laneIndex * laneHeight;

    return laneY + laneHeight - (value * (laneHeight - 20)) - 10;
}

float ParameterAutomationUI::TimelineEditor::yToValue(float y, int laneIndex) const
{
    int laneHeight = getHeight() / juce::jmax(1, static_cast<int>(currentLanes.size()));
    int laneY = laneIndex * laneHeight;

    float relativeY = y - laneY - 10;
    float normalizedY = 1.0f - (relativeY / (laneHeight - 20));

    return juce::jlimit(0.0f, 1.0f, normalizedY);
}

double ParameterAutomationUI::TimelineEditor::snapBeat(double beat) const
{
    if (!snapToGrid)
        return beat;

    return std::round(beat / gridDivision) * gridDivision;
}

void ParameterAutomationUI::TimelineEditor::drawGrid(juce::Graphics& g, juce::Rectangle<int> bounds)
{
    // Vertical grid lines (beats)
    g.setColour(juce::Colour(0xff2a2a30));

    int startBeat = static_cast<int>(std::floor(visibleStartBeat));
    int endBeat = static_cast<int>(std::ceil(visibleEndBeat));

    for (int beat = startBeat; beat <= endBeat; ++beat)
    {
        float x = beatToX(static_cast<double>(beat));
        g.drawVerticalLine(static_cast<int>(x), 0.0f, static_cast<float>(bounds.getHeight()));

        // Beat number
        g.setColour(juce::Colour(0xff808080));
        g.setFont(10.0f);
        g.drawText(juce::String(beat), static_cast<int>(x) - 20, 5, 40, 15, juce::Justification::centred);
        g.setColour(juce::Colour(0xff2a2a30));

        // Sub-divisions (16th notes)
        for (double sub = 0.25; sub < 1.0; sub += 0.25)
        {
            float subX = beatToX(beat + sub);
            g.setColour(juce::Colour(0xff1a1a20).withAlpha(0.5f));
            g.drawVerticalLine(static_cast<int>(subX), 0.0f, static_cast<float>(bounds.getHeight()));
        }
    }

    // Horizontal lane separators
    if (!currentLanes.empty())
    {
        int laneHeight = bounds.getHeight() / juce::jmax(1, static_cast<int>(currentLanes.size()));

        g.setColour(juce::Colour(0xff3a3a40));
        for (size_t i = 1; i < currentLanes.size(); ++i)
        {
            int y = i * laneHeight;
            g.drawHorizontalLine(y, 0.0f, static_cast<float>(bounds.getWidth()));
        }
    }
}

void ParameterAutomationUI::TimelineEditor::drawLane(juce::Graphics& g, const ParameterLane& lane,
                                                      int laneIndex, juce::Rectangle<int> bounds)
{
    // Lane background (subtle color)
    g.setColour(lane.laneColor.withAlpha(0.05f));
    g.fillRect(bounds);

    // Draw automation curve
    drawAutomationCurve(g, lane, bounds);

    // Draw automation points
    drawAutomationPoints(g, lane, laneIndex, bounds);

    // Lane label
    g.setColour(juce::Colour(0xffa8a8a8));
    g.setFont(11.0f);
    g.drawText(lane.displayName, bounds.reduced(5), juce::Justification::topLeft);
}

void ParameterAutomationUI::TimelineEditor::drawAutomationCurve(juce::Graphics& g, const ParameterLane& lane,
                                                                 juce::Rectangle<int> laneBounds)
{
    if (lane.points.empty())
        return;

    juce::Path curvePath;
    bool firstPoint = true;

    // Draw curve segments
    for (size_t i = 0; i < lane.points.size(); ++i)
    {
        const auto& point = lane.points[i];
        float x = beatToX(point.timeInBeats);
        float y = valueToY(point.value, static_cast<int>(&lane - currentLanes.data()));

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

    g.setColour(lane.laneColor.withAlpha(0.8f));
    g.strokePath(curvePath, juce::PathStrokeType(2.0f));
}

void ParameterAutomationUI::TimelineEditor::drawAutomationPoints(juce::Graphics& g, const ParameterLane& lane,
                                                                  int laneIndex, juce::Rectangle<int> laneBounds)
{
    for (const auto& point : lane.points)
    {
        float x = beatToX(point.timeInBeats);
        float y = valueToY(point.value, laneIndex);

        // Point circle
        g.setColour(lane.laneColor);
        g.fillEllipse(x - 5, y - 5, 10, 10);

        g.setColour(juce::Colour(0xff1a1a1f));
        g.drawEllipse(x - 5, y - 5, 10, 10, 2.0f);
    }
}

//==============================================================================
// EditToolbar Implementation
//==============================================================================

ParameterAutomationUI::EditToolbar::EditToolbar(ParameterAutomationUI& parent)
    : owner(parent)
{
    snapToggle.setButtonText("Snap to Grid");
    snapToggle.setToggleState(true, juce::dontSendNotification);
    addAndMakeVisible(snapToggle);
    snapToggle.onClick = [this]()
    {
        snapToGrid = snapToggle.getToggleState();
        if (onSnapToGridChanged)
            onSnapToGridChanged(snapToGrid);
    };

    gridLabel.setText("Grid:", juce::dontSendNotification);
    gridLabel.setColour(juce::Label::textColourId, juce::Colour(0xffe8e8e8));
    addAndMakeVisible(gridLabel);

    gridDivisionCombo.addItem("1/4 (Quarter)", 1);
    gridDivisionCombo.addItem("1/8 (Eighth)", 2);
    gridDivisionCombo.addItem("1/16 (Sixteenth)", 3);
    gridDivisionCombo.addItem("1/32 (Thirty-second)", 4);
    gridDivisionCombo.setSelectedId(3);
    addAndMakeVisible(gridDivisionCombo);
    gridDivisionCombo.onChange = [this]()
    {
        if (onGridDivisionChanged)
            onGridDivisionChanged(getGridDivision());
    };

    curveLabel.setText("Curve:", juce::dontSendNotification);
    curveLabel.setColour(juce::Label::textColourId, juce::Colour(0xffe8e8e8));
    addAndMakeVisible(curveLabel);

    curveTypeCombo.addItem("Linear", 1);
    curveTypeCombo.addItem("Exponential", 2);
    curveTypeCombo.addItem("Logarithmic", 3);
    curveTypeCombo.addItem("S-Curve", 4);
    curveTypeCombo.setSelectedId(1);
    addAndMakeVisible(curveTypeCombo);

    clearAllButton.setButtonText("Clear All");
    addAndMakeVisible(clearAllButton);

    clearLaneButton.setButtonText("Clear Lane");
    addAndMakeVisible(clearLaneButton);
}

void ParameterAutomationUI::EditToolbar::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff252530));
}

void ParameterAutomationUI::EditToolbar::resized()
{
    auto bounds = getLocalBounds().reduced(10, 5);

    snapToggle.setBounds(bounds.removeFromLeft(120));
    bounds.removeFromLeft(10);

    gridLabel.setBounds(bounds.removeFromLeft(40));
    bounds.removeFromLeft(5);
    gridDivisionCombo.setBounds(bounds.removeFromLeft(140));

    bounds.removeFromLeft(20);

    curveLabel.setBounds(bounds.removeFromLeft(50));
    bounds.removeFromLeft(5);
    curveTypeCombo.setBounds(bounds.removeFromLeft(120));

    // Right side
    clearLaneButton.setBounds(bounds.removeFromRight(100));
    bounds.removeFromRight(10);
    clearAllButton.setBounds(bounds.removeFromRight(100));
}

double ParameterAutomationUI::EditToolbar::getGridDivision() const
{
    switch (gridDivisionCombo.getSelectedId())
    {
        case 1: return 1.0;    // Quarter
        case 2: return 0.5;    // Eighth
        case 3: return 0.25;   // Sixteenth
        case 4: return 0.125;  // Thirty-second
        default: return 0.25;
    }
}
