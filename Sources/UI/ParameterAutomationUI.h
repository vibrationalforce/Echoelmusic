#pragma once

#include <JuceHeader.h>
#include "ResponsiveLayout.h"
#include "ModernLookAndFeel.h"
#include "UIComponents.h"
#include "../DSP/AdvancedDSPManager.h"

//==============================================================================
/**
 * @brief Parameter Automation UI for Advanced DSP Manager
 *
 * Timeline-based automation editor for recording and editing parameter changes.
 *
 * Features:
 * - Timeline view with beat/bar grid
 * - Parameter lane selection (multi-track)
 * - Automation point editing (add, move, delete, curve)
 * - Recording mode (real-time parameter capture)
 * - Playback with automation preview
 * - Copy/paste automation regions
 * - Automation curve types (linear, exponential, logarithmic, S-curve)
 * - Snap to grid
 * - Zoom and pan
 */
class ParameterAutomationUI : public ResponsiveComponent,
                               private juce::Timer
{
public:
    //==========================================================================
    // Constructor / Destructor

    ParameterAutomationUI();
    ~ParameterAutomationUI() override;

    //==========================================================================
    // DSP Manager Connection

    void setDSPManager(AdvancedDSPManager* manager);
    AdvancedDSPManager* getDSPManager() const { return dspManager; }

    //==========================================================================
    // Component Methods

    void paint(juce::Graphics& g) override;
    void resized() override;

private:
    //==========================================================================
    // Automation Point

    struct AutomationPoint
    {
        double timeInBeats;
        float value;              // 0.0 to 1.0 normalized

        enum class CurveType
        {
            Linear,
            Exponential,
            Logarithmic,
            SCurve
        };

        CurveType curveType = CurveType::Linear;

        bool operator<(const AutomationPoint& other) const
        {
            return timeInBeats < other.timeInBeats;
        }
    };

    //==========================================================================
    // Parameter Lane

    struct ParameterLane
    {
        juce::String parameterName;
        juce::String displayName;
        float minValue;
        float maxValue;
        std::vector<AutomationPoint> points;
        bool visible = true;
        bool armed = false;        // Recording armed
        juce::Colour laneColor;
    };

    //==========================================================================
    // Transport Bar

    class TransportBar : public juce::Component
    {
    public:
        TransportBar(ParameterAutomationUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;

        bool isPlaying() const { return playing; }
        bool isRecording() const { return recording; }

        std::function<void()> onPlay;
        std::function<void()> onStop;
        std::function<void()> onRecord;
        std::function<void()> onRewind;

    private:
        ParameterAutomationUI& owner;

        bool playing = false;
        bool recording = false;

        juce::TextButton playButton;
        juce::TextButton stopButton;
        juce::TextButton recordButton;
        juce::TextButton rewindButton;

        juce::Label tempoLabel;
        juce::Slider tempoSlider;

        juce::Label timecodeLabel;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TransportBar)
    };

    //==========================================================================
    // Parameter Lane List (Left Sidebar)

    class ParameterLaneList : public juce::Component
    {
    public:
        ParameterLaneList(ParameterAutomationUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;

        void updateParameterList(const std::vector<ParameterLane>& lanes);

        std::function<void(int laneIndex)> onLaneSelected;
        std::function<void(int laneIndex, bool armed)> onLaneArmChanged;

    private:
        ParameterAutomationUI& owner;

        class LaneListItem : public juce::Component
        {
        public:
            LaneListItem(int index, const ParameterLane& lane);
            void paint(juce::Graphics& g) override;
            void resized() override;
            void mouseDown(const juce::MouseEvent& event) override;

            int laneIndex;
            bool selected = false;

            std::function<void(int)> onClicked;
            std::function<void(int, bool)> onArmChanged;

        private:
            ParameterLane laneData;
            juce::ToggleButton armButton;

            JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(LaneListItem)
        };

        std::vector<std::unique_ptr<LaneListItem>> laneItems;
        juce::Viewport viewport;
        juce::Component contentComponent;

        int selectedLaneIndex = -1;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ParameterLaneList)
    };

    //==========================================================================
    // Timeline Editor

    class TimelineEditor : public juce::Component
    {
    public:
        TimelineEditor(ParameterAutomationUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;
        void mouseDown(const juce::MouseEvent& event) override;
        void mouseDrag(const juce::MouseEvent& event) override;
        void mouseUp(const juce::MouseEvent& event) override;
        void mouseWheelMove(const juce::MouseEvent& event, const juce::MouseWheelDetails& wheel) override;

        void setVisibleRange(double startBeat, double endBeat);
        void setPlayheadPosition(double beat);
        void updateLanes(const std::vector<ParameterLane>& lanes);

        std::function<void(int laneIndex, const AutomationPoint& point)> onPointAdded;
        std::function<void(int laneIndex, int pointIndex, const AutomationPoint& newPoint)> onPointMoved;
        std::function<void(int laneIndex, int pointIndex)> onPointDeleted;

    private:
        ParameterAutomationUI& owner;

        double visibleStartBeat = 0.0;
        double visibleEndBeat = 16.0;
        double playheadBeat = 0.0;

        std::vector<ParameterLane> currentLanes;

        // Editing state
        int selectedLaneIndex = -1;
        int selectedPointIndex = -1;
        bool draggingPoint = false;
        juce::Point<float> dragStartPosition;

        // Grid settings
        bool snapToGrid = true;
        double gridDivision = 0.25;  // 16th notes

        // Helper methods
        float beatToX(double beat) const;
        double xToBeat(float x) const;
        float valueToY(float value, int laneIndex) const;
        float yToValue(float y, int laneIndex) const;
        double snapBeat(double beat) const;

        void drawGrid(juce::Graphics& g, juce::Rectangle<int> bounds);
        void drawLane(juce::Graphics& g, const ParameterLane& lane, int laneIndex, juce::Rectangle<int> bounds);
        void drawAutomationCurve(juce::Graphics& g, const ParameterLane& lane, juce::Rectangle<int> laneBounds);
        void drawAutomationPoints(juce::Graphics& g, const ParameterLane& lane, int laneIndex, juce::Rectangle<int> laneBounds);

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(TimelineEditor)
    };

    //==========================================================================
    // Toolbar (Edit Tools)

    class EditToolbar : public juce::Component
    {
    public:
        EditToolbar(ParameterAutomationUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;

        bool isSnapToGridEnabled() const { return snapToGrid; }
        double getGridDivision() const;

        std::function<void(bool)> onSnapToGridChanged;
        std::function<void(double)> onGridDivisionChanged;

    private:
        ParameterAutomationUI& owner;

        bool snapToGrid = true;

        juce::ToggleButton snapToggle;
        juce::ComboBox gridDivisionCombo;
        juce::Label gridLabel;

        juce::TextButton clearAllButton;
        juce::TextButton clearLaneButton;

        juce::ComboBox curveTypeCombo;
        juce::Label curveLabel;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EditToolbar)
    };

    //==========================================================================
    // Timer Callback

    void timerCallback() override;

    //==========================================================================
    // Member Variables

    AdvancedDSPManager* dspManager = nullptr;

    // UI Components
    std::unique_ptr<TransportBar> transportBar;
    std::unique_ptr<ParameterLaneList> laneList;
    std::unique_ptr<TimelineEditor> timelineEditor;
    std::unique_ptr<EditToolbar> editToolbar;

    // Automation data
    std::vector<ParameterLane> parameterLanes;

    // Playback state
    bool isPlaying = false;
    bool isRecording = false;
    double currentPlayheadBeat = 0.0;
    double tempo = 120.0;

    //==========================================================================
    // Helper Methods

    void initializeParameterLanes();
    void updateAutomation();
    void recordAutomationPoint(int laneIndex, double beat, float value);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ParameterAutomationUI)
};
