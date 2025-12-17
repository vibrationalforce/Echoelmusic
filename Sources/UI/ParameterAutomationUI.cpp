#include "ParameterAutomationUI.h"

// ParameterAutomationUI - Main Implementation
ParameterAutomationUI::ParameterAutomationUI()
{
    // Create UI components
    transportBar = std::make_unique<TransportBar>(*this);
    addAndMakeVisible(*transportBar);
    
    laneList = std::make_unique<ParameterLaneList>(*this);
    addAndMakeVisible(*laneList);
    
    timelineEditor = std::make_unique<TimelineEditor>(*this);
    addAndMakeVisible(*timelineEditor);
    
    editToolbar = std::make_unique<EditToolbar>(*this);
    addAndMakeVisible(*editToolbar);
    
    // Wire transport callbacks
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
        isRecording = true;
        isPlaying = true;
    };
    
    transportBar->onRewind = [this]()
    {
        currentPlayheadBeat = 0.0;
        timelineEditor->setPlayheadPosition(0.0);
    };
    
    // Wire lane list callbacks
    laneList->onLaneSelected = [this](int laneIndex)
    {
        // Lane selected - could highlight in timeline
    };
    
    laneList->onLaneArmChanged = [this](int laneIndex, bool armed)
    {
        if (laneIndex >= 0 && laneIndex < static_cast<int>(parameterLanes.size()))
        {
            parameterLanes[laneIndex].armed = armed;
        }
    };
    
    // Wire timeline callbacks
    timelineEditor->onPointAdded = [this](int laneIndex, const AutomationPoint& point)
    {
        if (laneIndex >= 0 && laneIndex < static_cast<int>(parameterLanes.size()))
        {
            parameterLanes[laneIndex].points.push_back(point);
            std::sort(parameterLanes[laneIndex].points.begin(), 
                     parameterLanes[laneIndex].points.end());
            updateAutomation();
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
            updateAutomation();
        }
    };
    
    timelineEditor->onPointDeleted = [this](int laneIndex, int pointIndex)
    {
        if (laneIndex >= 0 && laneIndex < static_cast<int>(parameterLanes.size()) &&
            pointIndex >= 0 && pointIndex < static_cast<int>(parameterLanes[laneIndex].points.size()))
        {
            parameterLanes[laneIndex].points.erase(
                parameterLanes[laneIndex].points.begin() + pointIndex);
            updateAutomation();
        }
    };
    
    // Wire toolbar callbacks
    editToolbar->onSnapToGridChanged = [this](bool enabled)
    {
        // Update timeline snap setting
    };
    
    editToolbar->onGridDivisionChanged = [this](double division)
    {
        // Update timeline grid division
    };
    
    // Initialize parameter lanes
    initializeParameterLanes();
    
    // Start timer for playback updates
    startTimerHz(30);
}

ParameterAutomationUI::~ParameterAutomationUI() = default;

void ParameterAutomationUI::setDSPManager(AdvancedDSPManager* manager)
{
    dspManager = manager;
    initializeParameterLanes();
}

void ParameterAutomationUI::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1a1a1f));
}

void ParameterAutomationUI::resized()
{
    auto bounds = getLocalBounds();
    
    // Transport bar at top
    transportBar->setBounds(bounds.removeFromTop(60));
    
    // Edit toolbar below transport
    editToolbar->setBounds(bounds.removeFromTop(40));
    
    // Lane list on left
    laneList->setBounds(bounds.removeFromLeft(200));
    
    // Timeline editor takes remaining space
    timelineEditor->setBounds(bounds);
}

void ParameterAutomationUI::timerCallback()
{
    if (isPlaying)
    {
        // Update playhead position
        double deltaBeats = (tempo / 60.0) * (1.0 / 30.0);  // 30 Hz timer
        currentPlayheadBeat += deltaBeats;
        
        timelineEditor->setPlayheadPosition(currentPlayheadBeat);
        
        // Apply automation
        updateAutomation();
        
        // Record automation if armed
        if (isRecording)
        {
            for (int i = 0; i < static_cast<int>(parameterLanes.size()); ++i)
            {
                if (parameterLanes[i].armed)
                {
                    // Get current parameter value from DSP
                    float currentValue = 0.5f;  // Placeholder
                    recordAutomationPoint(i, currentPlayheadBeat, currentValue);
                }
            }
        }
    }
}

void ParameterAutomationUI::initializeParameterLanes()
{
    parameterLanes.clear();
    
    // Create lanes for common parameters
    const std::vector<juce::String> paramNames = {
        "Filter Cutoff", "Filter Resonance", "Pitch", "Amplitude",
        "Pan", "Reverb Mix", "Delay Time", "Distortion",
        "Mid/Side Balance", "Humanizer Amount", "Swarm Density"
    };
    
    const std::vector<juce::Colour> laneColors = {
        juce::Colour(0xff00d4ff), juce::Colour(0xff00ff88), juce::Colour(0xffffaa00),
        juce::Colour(0xffff4444), juce::Colour(0xffff00ff), juce::Colour(0xff88ff00),
        juce::Colour(0xff00ffff), juce::Colour(0xffff8800), juce::Colour(0xff8800ff),
        juce::Colour(0xffff0088), juce::Colour(0xff00ff44)
    };
    
    for (size_t i = 0; i < paramNames.size(); ++i)
    {
        ParameterLane lane;
        lane.parameterName = paramNames[i];
        lane.displayName = paramNames[i];
        lane.minValue = 0.0f;
        lane.maxValue = 1.0f;
        lane.visible = true;
        lane.armed = false;
        lane.laneColor = laneColors[i % laneColors.size()];
        
        parameterLanes.push_back(lane);
    }
    
    // Update UI
    laneList->updateParameterList(parameterLanes);
    timelineEditor->updateLanes(parameterLanes);
}

void ParameterAutomationUI::updateAutomation()
{
    if (!dspManager)
        return;
    
    // Apply automation values to DSP manager based on playhead position
    for (const auto& lane : parameterLanes)
    {
        if (!lane.visible || lane.points.empty())
            continue;
        
        // Find automation value at current playhead position
        float automationValue = 0.5f;
        
        // Find surrounding points
        for (size_t i = 0; i < lane.points.size(); ++i)
        {
            if (lane.points[i].timeInBeats >= currentPlayheadBeat)
            {
                if (i == 0)
                {
                    automationValue = lane.points[i].value;
                }
                else
                {
                    // Interpolate between points
                    const auto& p1 = lane.points[i - 1];
                    const auto& p2 = lane.points[i];
                    
                    double t = (currentPlayheadBeat - p1.timeInBeats) / (p2.timeInBeats - p1.timeInBeats);
                    t = juce::jlimit(0.0, 1.0, t);
                    
                    // Apply curve type
                    switch (p1.curveType)
                    {
                        case AutomationPoint::CurveType::Linear:
                            break;
                            
                        case AutomationPoint::CurveType::Exponential:
                            t = t * t;
                            break;
                            
                        case AutomationPoint::CurveType::Logarithmic:
                            t = std::sqrt(t);
                            break;
                            
                        case AutomationPoint::CurveType::SCurve:
                            t = t * t * (3.0 - 2.0 * t);  // Smoothstep
                            break;
                    }
                    
                    automationValue = p1.value + static_cast<float>(t) * (p2.value - p1.value);
                }
                break;
            }
        }
        
        // Apply to DSP manager
        // Example: dspManager->setParameterValue(lane.parameterName, automationValue);
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
    std::sort(parameterLanes[laneIndex].points.begin(), 
             parameterLanes[laneIndex].points.end());
}

//==============================================================================
// TransportBar Implementation

ParameterAutomationUI::TransportBar::TransportBar(ParameterAutomationUI& parent)
    : owner(parent)
{
    // Play button
    playButton.setButtonText("▶");
    addAndMakeVisible(playButton);
    playButton.onClick = [this]()
    {
        playing = true;
        if (onPlay)
            onPlay();
    };
    
    // Stop button
    stopButton.setButtonText("■");
    addAndMakeVisible(stopButton);
    stopButton.onClick = [this]()
    {
        playing = false;
        recording = false;
        if (onStop)
            onStop();
    };
    
    // Record button
    recordButton.setButtonText("●");
    addAndMakeVisible(recordButton);
    recordButton.onClick = [this]()
    {
        recording = true;
        playing = true;
        if (onRecord)
            onRecord();
    };
    
    // Rewind button
    rewindButton.setButtonText("⏮");
    addAndMakeVisible(rewindButton);
    rewindButton.onClick = [this]()
    {
        if (onRewind)
            onRewind();
    };
    
    // Tempo controls
    tempoLabel.setText("Tempo:", juce::dontSendNotification);
    addAndMakeVisible(tempoLabel);
    
    tempoSlider.setSliderStyle(juce::Slider::LinearHorizontal);
    tempoSlider.setRange(60, 200, 1);
    tempoSlider.setValue(120);
    tempoSlider.setTextBoxStyle(juce::Slider::TextBoxRight, false, 50, 20);
    addAndMakeVisible(tempoSlider);
    
    tempoSlider.onValueChange = [this]()
    {
        owner.tempo = tempoSlider.getValue();
    };
    
    // Timecode display
    timecodeLabel.setText("0:0:0", juce::dontSendNotification);
    timecodeLabel.setJustificationType(juce::Justification::centred);
    timecodeLabel.setFont(juce::Font(16.0f, juce::Font::bold));
    addAndMakeVisible(timecodeLabel);
}

void ParameterAutomationUI::TransportBar::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff252530));
    
    // Update timecode
    double beats = owner.currentPlayheadBeat;
    int bar = static_cast<int>(beats / 4.0) + 1;
    int beat = static_cast<int>(beats) % 4 + 1;
    int tick = static_cast<int>((beats - std::floor(beats)) * 100);
    
    juce::String timecode = juce::String(bar) + ":" + juce::String(beat) + ":" + juce::String(tick);
    timecodeLabel.setText(timecode, juce::dontSendNotification);
}

void ParameterAutomationUI::TransportBar::resized()
{
    auto bounds = getLocalBounds().reduced(10);
    
    // Transport buttons on left
    int buttonSize = 40;
    playButton.setBounds(bounds.removeFromLeft(buttonSize).reduced(2));
    stopButton.setBounds(bounds.removeFromLeft(buttonSize).reduced(2));
    recordButton.setBounds(bounds.removeFromLeft(buttonSize).reduced(2));
    rewindButton.setBounds(bounds.removeFromLeft(buttonSize).reduced(2));
    
    bounds.removeFromLeft(20);
    
    // Timecode in center-left
    timecodeLabel.setBounds(bounds.removeFromLeft(120));
    
    bounds.removeFromLeft(20);
    
    // Tempo on right
    tempoLabel.setBounds(bounds.removeFromLeft(60));
    tempoSlider.setBounds(bounds.removeFromLeft(150));
}

//==============================================================================
// ParameterLaneList Implementation

ParameterAutomationUI::ParameterLaneList::ParameterLaneList(ParameterAutomationUI& parent)
    : owner(parent)
{
    addAndMakeVisible(viewport);
    viewport.setViewedComponent(&contentComponent, false);
}

void ParameterAutomationUI::ParameterLaneList::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1f1f24));
}

void ParameterAutomationUI::ParameterLaneList::resized()
{
    viewport.setBounds(getLocalBounds());
    
    int itemHeight = 40;
    int totalHeight = static_cast<int>(laneItems.size()) * itemHeight;
    
    contentComponent.setBounds(0, 0, getWidth(), totalHeight);
    
    for (size_t i = 0; i < laneItems.size(); ++i)
    {
        laneItems[i]->setBounds(0, static_cast<int>(i) * itemHeight, getWidth(), itemHeight);
    }
}

void ParameterAutomationUI::ParameterLaneList::updateParameterList(const std::vector<ParameterLane>& lanes)
{
    laneItems.clear();
    
    for (size_t i = 0; i < lanes.size(); ++i)
    {
        auto* item = new LaneListItem(static_cast<int>(i), lanes[i]);
        
        item->onClicked = [this](int index)
        {
            selectedLaneIndex = index;
            if (onLaneSelected)
                onLaneSelected(index);

            for (auto& laneItem : laneItems)
                laneItem->selected = (laneItem->laneIndex == index);

            contentComponent.repaint();
        };
        
        item->onArmChanged = [this](int index, bool armed)
        {
            if (onLaneArmChanged)
                onLaneArmChanged(index, armed);
        };

        laneItems.push_back(std::unique_ptr<LaneListItem>(item));
        contentComponent.addAndMakeVisible(item);
    }
    
    resized();
}

// LaneListItem Implementation
ParameterAutomationUI::ParameterLaneList::LaneListItem::LaneListItem(int index, const ParameterLane& lane)
    : laneIndex(index), laneData(lane)
{
    armButton.setButtonText("R");
    armButton.setClickingTogglesState(true);
    addAndMakeVisible(armButton);
    
    armButton.onClick = [this]()
    {
        if (onArmChanged)
            onArmChanged(laneIndex, armButton.getToggleState());
    };
}

void ParameterAutomationUI::ParameterLaneList::LaneListItem::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();
    
    // Background
    if (selected)
        g.setColour(juce::Colour(0xff35353f));
    else
        g.setColour(juce::Colour(0xff252530));
    
    g.fillRect(bounds);
    
    // Color indicator
    g.setColour(laneData.laneColor);
    g.fillRect(bounds.removeFromLeft(4));
    
    // Lane name
    g.setColour(juce::Colours::white);
    g.setFont(12.0f);
    g.drawText(laneData.displayName, bounds.reduced(8, 0).withTrimmedRight(40), 
              juce::Justification::centredLeft);
    
    // Border
    g.setColour(juce::Colour(0xff454550));
    g.drawRect(getLocalBounds(), 1);
}

void ParameterAutomationUI::ParameterLaneList::LaneListItem::resized()
{
    auto bounds = getLocalBounds();
    armButton.setBounds(bounds.removeFromRight(35).reduced(5));
}

void ParameterAutomationUI::ParameterLaneList::LaneListItem::mouseDown(const juce::MouseEvent&)
{
    if (onClicked)
        onClicked(laneIndex);
}

//==============================================================================
// TimelineEditor Implementation

ParameterAutomationUI::TimelineEditor::TimelineEditor(ParameterAutomationUI& parent)
    : owner(parent)
{
}

void ParameterAutomationUI::TimelineEditor::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();
    
    // Background
    g.fillAll(juce::Colour(0xff1a1a1f));
    
    // Draw grid
    drawGrid(g, bounds);
    
    // Draw lanes
    int laneHeight = currentLanes.empty() ? 0 : bounds.getHeight() / static_cast<int>(currentLanes.size());
    
    for (size_t i = 0; i < currentLanes.size(); ++i)
    {
        auto laneBounds = bounds.removeFromTop(laneHeight);
        drawLane(g, currentLanes[i], static_cast<int>(i), laneBounds);
    }
    
    // Draw playhead
    float playheadX = beatToX(playheadBeat);
    g.setColour(juce::Colour(0xffff4444));
    g.drawVerticalLine(static_cast<int>(playheadX), 0.0f, static_cast<float>(getHeight()));
}

void ParameterAutomationUI::TimelineEditor::resized()
{
    repaint();
}

void ParameterAutomationUI::TimelineEditor::mouseDown(const juce::MouseEvent& event)
{
    double beat = xToBeat(static_cast<float>(event.x));
    
    // Determine which lane was clicked
    int laneHeight = currentLanes.empty() ? 0 : getHeight() / static_cast<int>(currentLanes.size());
    int laneIndex = event.y / laneHeight;
    
    if (laneIndex < 0 || laneIndex >= static_cast<int>(currentLanes.size()))
        return;
    
    float value = yToValue(static_cast<float>(event.y - laneIndex * laneHeight), laneIndex);
    
    // Check if clicking near existing point
    bool clickedPoint = false;
    const auto& lane = currentLanes[laneIndex];
    
    for (size_t i = 0; i < lane.points.size(); ++i)
    {
        float pointX = beatToX(lane.points[i].timeInBeats);
        float pointY = valueToY(lane.points[i].value, laneIndex) + laneIndex * laneHeight;
        
        if (std::abs(event.x - pointX) < 8 && std::abs(event.y - pointY) < 8)
        {
            selectedLaneIndex = laneIndex;
            selectedPointIndex = static_cast<int>(i);
            draggingPoint = true;
            clickedPoint = true;
            break;
        }
    }
    
    // If not clicking point, add new point
    if (!clickedPoint)
    {
        if (snapToGrid)
            beat = snapBeat(beat);
        
        AutomationPoint newPoint;
        newPoint.timeInBeats = beat;
        newPoint.value = value;
        newPoint.curveType = AutomationPoint::CurveType::Linear;
        
        if (onPointAdded)
            onPointAdded(laneIndex, newPoint);
    }
    
    repaint();
}

void ParameterAutomationUI::TimelineEditor::mouseDrag(const juce::MouseEvent& event)
{
    if (draggingPoint && selectedLaneIndex >= 0 && selectedPointIndex >= 0)
    {
        double beat = xToBeat(static_cast<float>(event.x));
        if (snapToGrid)
            beat = snapBeat(beat);
        
        int laneHeight = currentLanes.empty() ? 0 : getHeight() / static_cast<int>(currentLanes.size());
        float value = yToValue(static_cast<float>(event.y - selectedLaneIndex * laneHeight), selectedLaneIndex);
        
        AutomationPoint movedPoint;
        movedPoint.timeInBeats = beat;
        movedPoint.value = juce::jlimit(0.0f, 1.0f, value);
        movedPoint.curveType = AutomationPoint::CurveType::Linear;
        
        if (onPointMoved)
            onPointMoved(selectedLaneIndex, selectedPointIndex, movedPoint);
        
        repaint();
    }
}

void ParameterAutomationUI::TimelineEditor::mouseUp(const juce::MouseEvent&)
{
    draggingPoint = false;
}

void ParameterAutomationUI::TimelineEditor::mouseWheelMove(const juce::MouseEvent&, const juce::MouseWheelDetails& wheel)
{
    // Zoom timeline
    double zoomFactor = wheel.deltaY > 0 ? 0.9 : 1.1;
    double range = visibleEndBeat - visibleStartBeat;
    double center = (visibleStartBeat + visibleEndBeat) / 2.0;
    
    double newRange = range * zoomFactor;
    visibleStartBeat = center - newRange / 2.0;
    visibleEndBeat = center + newRange / 2.0;
    
    repaint();
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
    double normalizedPos = (beat - visibleStartBeat) / (visibleEndBeat - visibleStartBeat);
    return static_cast<float>(normalizedPos * getWidth());
}

double ParameterAutomationUI::TimelineEditor::xToBeat(float x) const
{
    double normalizedPos = x / getWidth();
    return visibleStartBeat + normalizedPos * (visibleEndBeat - visibleStartBeat);
}

float ParameterAutomationUI::TimelineEditor::valueToY(float value, int laneIndex) const
{
    int laneHeight = currentLanes.empty() ? 0 : getHeight() / static_cast<int>(currentLanes.size());
    return (1.0f - value) * laneHeight;
}

float ParameterAutomationUI::TimelineEditor::yToValue(float y, int laneIndex) const
{
    int laneHeight = currentLanes.empty() ? 0 : getHeight() / static_cast<int>(currentLanes.size());
    return 1.0f - (y / laneHeight);
}

double ParameterAutomationUI::TimelineEditor::snapBeat(double beat) const
{
    return std::round(beat / gridDivision) * gridDivision;
}

void ParameterAutomationUI::TimelineEditor::drawGrid(juce::Graphics& g, juce::Rectangle<int> bounds)
{
    g.setColour(juce::Colour(0xff35353f));
    
    // Vertical grid lines (beats)
    for (double beat = std::floor(visibleStartBeat); beat <= visibleEndBeat; beat += gridDivision)
    {
        float x = beatToX(beat);
        if (x >= 0 && x <= bounds.getWidth())
        {
            bool isMajor = (std::fmod(beat, 1.0) < 0.001);
            g.setColour(isMajor ? juce::Colour(0xff454550) : juce::Colour(0xff35353f));
            g.drawVerticalLine(static_cast<int>(x), static_cast<float>(bounds.getY()), static_cast<float>(bounds.getBottom()));
        }
    }
}

void ParameterAutomationUI::TimelineEditor::drawLane(juce::Graphics& g, const ParameterLane& lane, 
                                                      int laneIndex, juce::Rectangle<int> bounds)
{
    // Lane background
    g.setColour(juce::Colour(0xff252530));
    g.fillRect(bounds);
    
    // Lane separator
    g.setColour(juce::Colour(0xff1a1a1f));
    g.drawHorizontalLine(bounds.getY(), static_cast<float>(bounds.getX()), static_cast<float>(bounds.getRight()));
    
    if (lane.visible)
    {
        // Draw automation curve
        drawAutomationCurve(g, lane, bounds);
        
        // Draw automation points
        drawAutomationPoints(g, lane, laneIndex, bounds);
    }
}

void ParameterAutomationUI::TimelineEditor::drawAutomationCurve(juce::Graphics& g, const ParameterLane& lane, 
                                                                  juce::Rectangle<int> laneBounds)
{
    if (lane.points.size() < 2)
        return;
    
    juce::Path curvePath;
    bool firstPoint = true;
    
    for (const auto& point : lane.points)
    {
        float x = beatToX(point.timeInBeats);
        float y = laneBounds.getY() + valueToY(point.value, 0);
        
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
    
    g.setColour(lane.laneColor.withAlpha(0.6f));
    g.strokePath(curvePath, juce::PathStrokeType(2.0f));
}

void ParameterAutomationUI::TimelineEditor::drawAutomationPoints(juce::Graphics& g, const ParameterLane& lane, 
                                                                   int laneIndex, juce::Rectangle<int> laneBounds)
{
    for (size_t i = 0; i < lane.points.size(); ++i)
    {
        const auto& point = lane.points[i];
        
        float x = beatToX(point.timeInBeats);
        float y = laneBounds.getY() + valueToY(point.value, 0);
        
        // Point circle
        bool isSelected = (laneIndex == selectedLaneIndex && static_cast<int>(i) == selectedPointIndex);
        
        g.setColour(lane.laneColor);
        g.fillEllipse(x - 4, y - 4, 8, 8);
        
        if (isSelected)
        {
            g.setColour(juce::Colour(0xffff4444));
            g.drawEllipse(x - 6, y - 6, 12, 12, 2.0f);
        }
    }
}

//==============================================================================
// EditToolbar Implementation

ParameterAutomationUI::EditToolbar::EditToolbar(ParameterAutomationUI& parent)
    : owner(parent)
{
    // Snap toggle
    snapToggle.setButtonText("Snap");
    snapToggle.setToggleState(true, juce::dontSendNotification);
    addAndMakeVisible(snapToggle);
    
    snapToggle.onClick = [this]()
    {
        snapToGrid = snapToggle.getToggleState();
        if (onSnapToGridChanged)
            onSnapToGridChanged(snapToGrid);
    };
    
    // Grid division
    gridLabel.setText("Grid:", juce::dontSendNotification);
    addAndMakeVisible(gridLabel);
    
    gridDivisionCombo.addItem("1/4", 1);
    gridDivisionCombo.addItem("1/8", 2);
    gridDivisionCombo.addItem("1/16", 3);
    gridDivisionCombo.addItem("1/32", 4);
    gridDivisionCombo.setSelectedId(3);
    addAndMakeVisible(gridDivisionCombo);
    
    gridDivisionCombo.onChange = [this]()
    {
        if (onGridDivisionChanged)
            onGridDivisionChanged(getGridDivision());
    };
    
    // Clear buttons
    clearLaneButton.setButtonText("Clear Lane");
    addAndMakeVisible(clearLaneButton);
    
    clearAllButton.setButtonText("Clear All");
    addAndMakeVisible(clearAllButton);
    
    // Curve type
    curveLabel.setText("Curve:", juce::dontSendNotification);
    addAndMakeVisible(curveLabel);
    
    curveTypeCombo.addItem("Linear", 1);
    curveTypeCombo.addItem("Exponential", 2);
    curveTypeCombo.addItem("Logarithmic", 3);
    curveTypeCombo.addItem("S-Curve", 4);
    curveTypeCombo.setSelectedId(1);
    addAndMakeVisible(curveTypeCombo);
}

void ParameterAutomationUI::EditToolbar::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff252530));
}

void ParameterAutomationUI::EditToolbar::resized()
{
    auto bounds = getLocalBounds().reduced(5);
    
    snapToggle.setBounds(bounds.removeFromLeft(80).reduced(2));
    gridLabel.setBounds(bounds.removeFromLeft(45).reduced(2));
    gridDivisionCombo.setBounds(bounds.removeFromLeft(80).reduced(2));
    
    bounds.removeFromLeft(20);
    
    curveLabel.setBounds(bounds.removeFromLeft(50).reduced(2));
    curveTypeCombo.setBounds(bounds.removeFromLeft(120).reduced(2));
    
    auto rightSection = bounds;
    clearAllButton.setBounds(rightSection.removeFromRight(100).reduced(2));
    clearLaneButton.setBounds(rightSection.removeFromRight(100).reduced(2));
}

double ParameterAutomationUI::EditToolbar::getGridDivision() const
{
    switch (gridDivisionCombo.getSelectedId())
    {
        case 1: return 1.0;      // 1/4 note
        case 2: return 0.5;      // 1/8 note
        case 3: return 0.25;     // 1/16 note
        case 4: return 0.125;    // 1/32 note
        default: return 0.25;
    }
}
