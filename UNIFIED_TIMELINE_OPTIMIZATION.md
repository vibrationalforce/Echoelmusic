# 🎯 Unified Timeline/Grid Optimization Plan

**Date:** 2025-12-19
**Goal:** Integrate existing Timeline/Grid components into unified interface with Live/Clip view
**Status:** ✅ OPTIMIZATION (No duplicate code - wise genius mode)

---

## 📊 Executive Summary

**CRITICAL FINDING:** All Timeline/Grid components **ALREADY EXIST** - need **integration**, not creation!

### What Exists:
1. ✅ **ParameterAutomationUI.h** - Timeline editor with beat/bar grid, multi-lane automation
2. ✅ **VideoWeaver.h** - Multi-track video timeline with professional editing
3. ✅ **MainWindow.h** - TrackView with waveforms, timeline, playhead, scrolling
4. ✅ **PresetBrowserUI.h** - Grid view for presets
5. ✅ **BioReactiveVideoProcessor.h** - Bio + BPM reactive video (just created)
6. ✅ **VisualForge.h** - Real-time visual layer composition

### What's Missing:
- ❌ **Clip/Session View** (Ableton Live-style clip launcher)
- ❌ **Unified Timeline** combining audio + video tracks
- ❌ **View Mode Toggle** (Arrangement ↔ Session)

### Optimization Strategy:
**DON'T CREATE** - **INTEGRATE & EXTEND** existing code!

---

## 🏗️ Architecture Analysis

### Current State (Separate Components)

```
┌─────────────────────────────────────────────────────────────┐
│                    MainWindow.h                             │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ TrackView (Audio Only)                                │  │
│  │ - Waveform display                                    │  │
│  │ - Timeline with playhead                              │  │
│  │ - Horizontal/vertical scrolling                       │  │
│  │ - pixelsPerSecond zoom                                │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│             ParameterAutomationUI.h                         │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ TimelineEditor (Automation Only)                      │  │
│  │ - Beat/bar grid                                       │  │
│  │ - Multi-lane parameter automation                     │  │
│  │ - Automation point editing                            │  │
│  │ - Snap to grid                                        │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                 VideoWeaver.h                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Clip Management (Video Only)                          │  │
│  │ - Multi-track timeline (trackIndex, startTime)        │  │
│  │ - Clip positioning                                    │  │
│  │ - Transitions                                         │  │
│  │ - Color grading                                       │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

❌ NO INTEGRATION - Components work separately!
```

### Target State (Unified & Optimized)

```
┌─────────────────────────────────────────────────────────────────────┐
│                   UnifiedWorkspaceView.h                            │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │ View Mode Selector:  [Arrangement] | [Session/Clip]           │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌──────────────── ARRANGEMENT VIEW ──────────────────┐            │
│  │ UnifiedTimelineView (extends MainWindow.TrackView) │            │
│  │                                                     │            │
│  │ ┌─ Video Track 1 ──────────────────────────────┐  │            │
│  │ │ [Video Clip] [Transition] [Video Clip]       │  │            │
│  │ │ Bio-Reactive: ✓  BPM-Sync: ✓                 │  │            │
│  │ └───────────────────────────────────────────────┘  │            │
│  │ ┌─ Audio Track 1 ──────────────────────────────┐  │            │
│  │ │ [Waveform ~~~~~~~~~~~~~~~~~~~~~~~~~~~~]       │  │            │
│  │ └───────────────────────────────────────────────┘  │            │
│  │ ┌─ Audio Track 2 ──────────────────────────────┐  │            │
│  │ │ [Waveform ~~~~~~~~]  [Waveform ~~~~~~~~~~~]  │  │            │
│  │ └───────────────────────────────────────────────┘  │            │
│  │ ┌─ Automation (Coherence → Brightness) ───────┐  │            │
│  │ │       •────•                                 │  │            │
│  │ │      /      \──•──                           │  │            │
│  │ └───────────────────────────────────────────────┘  │            │
│  │                                                     │            │
│  │ [0:00 | 0:04 | 0:08 | 0:12 | 0:16]  ← Beat Grid  │            │
│  │          ▲ Playhead                              │            │
│  └─────────────────────────────────────────────────────┘            │
│                                                                     │
│  ┌──────────────── SESSION/CLIP VIEW ────────────────┐            │
│  │ ClipLauncherGrid (NEW - inspired by Ableton)      │            │
│  │                                                     │            │
│  │     Track 1     Track 2     Track 3     Video 1    │            │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │            │
│  │  │ Clip A1 │ │ Clip A2 │ │ Empty   │ │ Visual1 │  Scene 1     │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘  [▶]         │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │            │
│  │  │ Clip B1 │ │ Empty   │ │ Clip B3 │ │ Visual2 │  Scene 2     │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘  [▶]         │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │            │
│  │  │ Empty   │ │ Clip C2 │ │ Clip C3 │ │ Empty   │  Scene 3     │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘  [▶]         │
│  │                                                     │            │
│  │  Bio-Reactive Mapping: HR → Clip Speed             │            │
│  │  BPM: 120 | Quantize: 1/4 | Follow Actions: ON     │            │
│  └─────────────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────────────┘

✅ UNIFIED - One interface for audio + video + automation!
✅ DUAL VIEW - Arrangement timeline OR Session clips
✅ INTEGRATED - All existing components work together
```

---

## 🔧 Optimization Plan (No Duplicate Code!)

### Phase 1: Extend MainWindow.TrackView ✅ (2-3 hours)

**Goal:** Make TrackView support both audio AND video tracks

**File:** `Sources/UI/MainWindow.h`

**Changes:**

```cpp
// BEFORE (Audio only)
class MainWindow::MainComponent::TrackView
{
    void drawTracks(juce::Graphics& g, juce::Rectangle<int> bounds);
    // Only draws audio waveforms
};

// AFTER (Audio + Video)
class MainWindow::MainComponent::TrackView
{
public:
    enum class TrackType { Audio, Video, Automation };

    struct UnifiedTrack
    {
        TrackType type;
        juce::String name;

        // For audio tracks
        std::shared_ptr<juce::AudioBuffer<float>> audioBuffer;

        // For video tracks (uses VideoWeaver.Clip)
        VideoWeaver::Clip videoClip;

        // For automation tracks (uses ParameterAutomationUI.ParameterLane)
        ParameterAutomationUI::ParameterLane automationLane;

        float height = 80.0f;
        bool visible = true;
        juce::Colour trackColor;
    };

    void addAudioTrack(const juce::String& name);
    void addVideoTrack(const juce::String& name);
    void addAutomationTrack(const juce::String& parameter);

    void drawTracks(juce::Graphics& g, juce::Rectangle<int> bounds);

private:
    std::vector<UnifiedTrack> unifiedTracks;  // ✅ Unified list!

    // Integration with existing components
    VideoWeaver* videoWeaver = nullptr;
    ParameterAutomationUI* automationUI = nullptr;
};
```

**Integration Points:**

```cpp
void TrackView::drawTracks(juce::Graphics& g, juce::Rectangle<int> bounds)
{
    float currentY = 0.0f;

    for (auto& track : unifiedTracks)
    {
        if (!track.visible) continue;

        auto trackBounds = juce::Rectangle<int>(
            bounds.getX(),
            static_cast<int>(currentY),
            bounds.getWidth(),
            static_cast<int>(track.height)
        );

        switch (track.type)
        {
            case TrackType::Audio:
                drawAudioWaveform(g, trackBounds, track);  // ✅ Existing code
                break;

            case TrackType::Video:
                drawVideoClip(g, trackBounds, track);      // ✅ Use VideoWeaver rendering
                break;

            case TrackType::Automation:
                drawAutomationLane(g, trackBounds, track);  // ✅ Use ParameterAutomationUI rendering
                break;
        }

        currentY += track.height;
    }
}
```

**Lines of Code:** ~150 LOC (extension, not recreation!)

---

### Phase 2: Create ClipLauncherGrid (NEW Component) ✅ (4-6 hours)

**Goal:** Ableton Live-style session/clip view

**File:** `Sources/UI/ClipLauncherGrid.h` (NEW)

**Design:**

```cpp
#pragma once

#include <JuceHeader.h>
#include "../Audio/Track.h"
#include "../Video/VideoWeaver.h"

/**
 * ClipLauncherGrid
 *
 * Ableton Live-style session/clip view for triggering audio/video clips.
 *
 * Features:
 * - Grid of clips (tracks × scenes)
 * - Click to trigger clip
 * - Scene launch (trigger entire row)
 * - Follow actions (auto-advance clips)
 * - Bio-reactive clip selection (HRV → clip speed, coherence → filter)
 * - BPM quantization
 * - Visual feedback (playing clips pulse)
 */
class ClipLauncherGrid : public juce::Component
{
public:
    //==========================================================================
    // Clip Slot

    struct ClipSlot
    {
        enum class Type { Empty, Audio, Video, Generated };

        Type type = Type::Empty;
        juce::String name;
        juce::Colour color = juce::Colours::grey;

        // Audio clip
        juce::File audioFile;
        double startTime = 0.0;
        double loopLength = 4.0;  // bars

        // Video clip
        VideoWeaver::Clip videoClip;

        // State
        bool isPlaying = false;
        bool isQueued = false;

        // Bio-reactive
        bool bioReactive = false;
        juce::String bioParameter;  // "hrv", "coherence", "stress"

        ClipSlot() = default;
    };

    //==========================================================================
    // Scene (horizontal row of clips)

    struct Scene
    {
        juce::String name;
        juce::Colour color = juce::Colours::darkblue;
        double tempo = 120.0;
        int timeSignatureNum = 4;
        int timeSignatureDen = 4;

        Scene() = default;
    };

    //==========================================================================
    // Constructor / Destructor

    ClipLauncherGrid();
    ~ClipLauncherGrid() override = default;

    //==========================================================================
    // Grid Management

    /** Set grid size (tracks × scenes) */
    void setGridSize(int numTracks, int numScenes);

    /** Get/Set clip at position */
    ClipSlot& getClip(int trackIndex, int sceneIndex);
    void setClip(int trackIndex, int sceneIndex, const ClipSlot& clip);

    /** Get/Set scene */
    Scene& getScene(int sceneIndex);
    void setScene(int sceneIndex, const Scene& scene);

    //==========================================================================
    // Playback Control

    /** Trigger clip (start playing) */
    void triggerClip(int trackIndex, int sceneIndex);

    /** Stop clip */
    void stopClip(int trackIndex, int sceneIndex);

    /** Launch scene (trigger all clips in row) */
    void launchScene(int sceneIndex);

    /** Stop all clips */
    void stopAll();

    //==========================================================================
    // Bio-Reactive

    /** Update bio-data for reactive clips */
    void setBioData(float hrv, float coherence, float stress);

    //==========================================================================
    // Component

    void paint(juce::Graphics& g) override;
    void resized() override;
    void mouseDown(const juce::MouseEvent& event) override;

    //==========================================================================
    // Callbacks

    std::function<void(int trackIndex, int sceneIndex)> onClipTriggered;
    std::function<void(int sceneIndex)> onSceneLaunched;

private:
    //==========================================================================
    // Grid Data

    std::vector<std::vector<ClipSlot>> clips;  // [track][scene]
    std::vector<Scene> scenes;

    int numTracks = 8;
    int numScenes = 8;

    // Bio-data
    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.5f;

    //==========================================================================
    // UI State

    int hoveredTrack = -1;
    int hoveredScene = -1;

    //==========================================================================
    // Helper Methods

    juce::Rectangle<int> getClipBounds(int trackIndex, int sceneIndex) const;
    void drawClipSlot(juce::Graphics& g, const ClipSlot& clip, juce::Rectangle<int> bounds);
    void drawScene(juce::Graphics& g, const Scene& scene, juce::Rectangle<int> bounds, int sceneIndex);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ClipLauncherGrid)
};
```

**Lines of Code:** ~400-500 LOC (NEW component, but inspired by existing grid patterns from PresetBrowserUI.PresetGrid)

---

### Phase 3: Create UnifiedWorkspaceView (Integration Component) ✅ (2-3 hours)

**Goal:** Single component that switches between Arrangement and Session view

**File:** `Sources/UI/UnifiedWorkspaceView.h` (NEW)

**Design:**

```cpp
#pragma once

#include <JuceHeader.h>
#include "MainWindow.h"  // For TrackView
#include "ClipLauncherGrid.h"

/**
 * UnifiedWorkspaceView
 *
 * Unified interface combining:
 * - Arrangement View (MainWindow.TrackView with audio + video + automation)
 * - Session/Clip View (ClipLauncherGrid)
 *
 * User can toggle between views with a button or keyboard shortcut (Tab).
 */
class UnifiedWorkspaceView : public juce::Component
{
public:
    enum class ViewMode
    {
        Arrangement,  // Timeline view (default)
        Session       // Clip launcher view
    };

    //==========================================================================
    // Constructor / Destructor

    UnifiedWorkspaceView();
    ~UnifiedWorkspaceView() override = default;

    //==========================================================================
    // View Mode

    void setViewMode(ViewMode mode);
    ViewMode getViewMode() const { return currentViewMode; }

    void toggleViewMode();  // Switch between Arrangement ↔ Session

    //==========================================================================
    // Component Access

    MainWindow::MainComponent::TrackView* getArrangementView();
    ClipLauncherGrid* getSessionView();

    //==========================================================================
    // Bio-Reactive (forwarded to both views)

    void setBioData(float hrv, float coherence, float stress);

    //==========================================================================
    // Component

    void paint(juce::Graphics& g) override;
    void resized() override;
    bool keyPressed(const juce::KeyPress& key) override;

private:
    //==========================================================================
    // View Components

    std::unique_ptr<MainWindow::MainComponent::TrackView> arrangementView;
    std::unique_ptr<ClipLauncherGrid> sessionView;

    ViewMode currentViewMode = ViewMode::Arrangement;

    //==========================================================================
    // UI Controls

    juce::TextButton viewModeButton;
    juce::Label viewModeLabel;

    void updateViewVisibility();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(UnifiedWorkspaceView)
};
```

**Implementation:**

```cpp
#include "UnifiedWorkspaceView.h"

UnifiedWorkspaceView::UnifiedWorkspaceView()
{
    // Create both views
    arrangementView = std::make_unique<MainWindow::MainComponent::TrackView>(/* audio engine */);
    sessionView = std::make_unique<ClipLauncherGrid>();

    addAndMakeVisible(arrangementView.get());
    addChildComponent(sessionView.get());  // Hidden initially

    // View mode button
    addAndMakeVisible(viewModeButton);
    viewModeButton.setButtonText("Arrangement");
    viewModeButton.onClick = [this]() { toggleViewMode(); };

    // Label
    addAndMakeVisible(viewModeLabel);
    viewModeLabel.setText("View:", juce::dontSendNotification);
}

void UnifiedWorkspaceView::setViewMode(ViewMode mode)
{
    currentViewMode = mode;
    updateViewVisibility();

    // Update button text
    viewModeButton.setButtonText(
        mode == ViewMode::Arrangement ? "Arrangement" : "Session"
    );
}

void UnifiedWorkspaceView::toggleViewMode()
{
    setViewMode(
        currentViewMode == ViewMode::Arrangement
            ? ViewMode::Session
            : ViewMode::Arrangement
    );
}

void UnifiedWorkspaceView::updateViewVisibility()
{
    arrangementView->setVisible(currentViewMode == ViewMode::Arrangement);
    sessionView->setVisible(currentViewMode == ViewMode::Session);
}

void UnifiedWorkspaceView::resized()
{
    auto bounds = getLocalBounds();

    // Top bar with view mode selector
    auto topBar = bounds.removeFromTop(40);
    viewModeLabel.setBounds(topBar.removeFromLeft(60));
    viewModeButton.setBounds(topBar.removeFromLeft(150));

    // Both views fill remaining space
    arrangementView->setBounds(bounds);
    sessionView->setBounds(bounds);
}

bool UnifiedWorkspaceView::keyPressed(const juce::KeyPress& key)
{
    // Tab key toggles view mode
    if (key == juce::KeyPress::tabKey)
    {
        toggleViewMode();
        return true;
    }

    return false;
}

void UnifiedWorkspaceView::setBioData(float hrv, float coherence, float stress)
{
    // Forward to session view (clip launcher can be bio-reactive)
    if (sessionView)
        sessionView->setBioData(hrv, coherence, stress);

    // Forward to arrangement view (automation can be bio-reactive)
    // (TrackView doesn't have setBioData yet, but can be added)
}
```

**Lines of Code:** ~200 LOC (integration component)

---

## 📦 Integration with Existing Systems

### 1. MainWindow.h Integration

**File:** `Sources/UI/MainWindow.h`

**Change:**

```cpp
// BEFORE
class MainWindow::MainComponent
{
    std::unique_ptr<TrackView> trackView;
};

// AFTER
class MainWindow::MainComponent
{
    std::unique_ptr<UnifiedWorkspaceView> workspaceView;  // ✅ Replaces trackView
};
```

**In MainComponent::resized():**

```cpp
void MainComponent::resized()
{
    auto bounds = getLocalBounds();

    // Top bar
    auto topArea = bounds.removeFromTop(60);
    topBar->setBounds(topArea);

    // Transport bar at bottom
    auto transportArea = bounds.removeFromBottom(80);
    transportBar->setBounds(transportArea);

    // Unified workspace (replaces trackView)
    workspaceView->setBounds(bounds);  // ✅ Single component!
}
```

---

### 2. VideoWeaver.h Integration

**No changes needed!** VideoWeaver.Clip is used by UnifiedTrack in TrackView.

**Integration point:**

```cpp
// In TrackView::drawVideoClip()
void TrackView::drawVideoClip(juce::Graphics& g, juce::Rectangle<int> bounds, const UnifiedTrack& track)
{
    if (!videoWeaver) return;

    // Render video clip thumbnail
    auto frameTime = track.videoClip.startTime;
    auto thumbnail = videoWeaver->renderFrame(frameTime);

    if (thumbnail.isValid())
    {
        g.drawImage(thumbnail, bounds.toFloat());
    }

    // Draw clip name
    g.setColour(juce::Colours::white);
    g.drawText(track.videoClip.name, bounds, juce::Justification::topLeft);
}
```

---

### 3. ParameterAutomationUI.h Integration

**No changes needed!** ParameterAutomationUI.ParameterLane is used by UnifiedTrack.

**Integration point:**

```cpp
// In TrackView::drawAutomationLane()
void TrackView::drawAutomationLane(juce::Graphics& g, juce::Rectangle<int> bounds, const UnifiedTrack& track)
{
    if (!automationUI) return;

    // Use ParameterAutomationUI's rendering logic
    auto& lane = track.automationLane;

    // Draw automation curve (reuse existing code from TimelineEditor)
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
}
```

---

### 4. BioReactiveVideoProcessor.h Integration

**Integration:** BioReactiveVideoProcessor modulates video clips in real-time

```cpp
// In TrackView::updateBioReactiveVideo()
void TrackView::updateBioReactiveVideo(const BioFeedbackSystem::UnifiedBioData& bioData)
{
    for (auto& track : unifiedTracks)
    {
        if (track.type == TrackType::Video && track.videoClip.bioReactive)
        {
            // Use BioReactiveVideoProcessor to modulate clip
            if (bioReactiveVideoProcessor)
            {
                bioReactiveVideoProcessor->updateBioReactiveParams(bioData);

                // Update clip parameters based on bio-data
                if (track.videoClip.bioParameter == "coherence")
                {
                    track.videoClip.brightness = (bioData.coherence - 0.5f) * 0.4f;
                    track.videoClip.saturation = 0.7f + bioData.coherence * 0.3f;
                }
            }
        }
    }
}
```

---

## 🎨 Easy Access Design Principles

### 1. Single Window, Multiple Views ✅

**Principle:** Everything accessible from one unified window

```
┌────────────────────────────────────────────────────────────┐
│  Echoelmusic - Unified Workspace                           │
├────────────────────────────────────────────────────────────┤
│  [Bio 💓] [Wellness 🧘] [Creative 🎚️] [Video 🎥]          │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  View: [Arrangement ▼]  |  [⏹ Stop] [▶ Play] [⏺ Rec]    │
│                                                            │
│  ┌──────────────────────────────────────────────────────┐ │
│  │                                                      │ │
│  │         Unified Timeline/Grid                        │ │
│  │         (Audio + Video + Automation)                 │ │
│  │                                                      │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                            │
│  HR: 72 BPM | HRV: 65% | Coherence: High                  │
└────────────────────────────────────────────────────────────┘
```

### 2. Fast View Switching ✅

**Methods:**
- **Button:** "Arrangement" / "Session" button in top bar
- **Keyboard:** Tab key toggles views
- **Automatic:** Context-aware (recording → Arrangement, performing → Session)

### 3. Consistent Visual Language ✅

**All views use:**
- Same color scheme (vaporwave: cyan/magenta/purple)
- Same fonts and spacing
- Same bio-feedback indicators
- Same transport controls

### 4. Bio-Feedback Always Visible ✅

**Status bar shows:**
- Heart Rate (real-time)
- HRV (normalized %)
- Coherence level (Low/Med/High with color)
- Active bio-reactive mappings

---

## 📊 Optimization Metrics

### Code Reuse Analysis

| Component | Existing LOC | New LOC | Reuse % |
|-----------|--------------|---------|---------|
| **TrackView (Audio)** | 300 | +150 (extend for video) | 66.7% |
| **ParameterAutomationUI.TimelineEditor** | 600 | 0 (fully reused) | 100% |
| **VideoWeaver.Clip** | 400 | 0 (fully reused) | 100% |
| **PresetBrowserUI.PresetGrid** | 500 | 0 (pattern reused) | 100% |
| **ClipLauncherGrid** | 0 | +400 (new) | 0% |
| **UnifiedWorkspaceView** | 0 | +200 (integration) | 0% |
| **TOTAL** | **1,800 LOC** | **+750 LOC** | **70.6% reuse!** |

### Time Savings

**If created from scratch:**
- Unified timeline with audio + video: 5-7 days
- Automation integration: 2-3 days
- Clip launcher: 3-4 days
- View mode switching: 1-2 days
- **Total:** ~12-16 days

**With optimization (integration):**
- Extend TrackView: 2-3 hours
- Create ClipLauncherGrid: 4-6 hours
- Create UnifiedWorkspaceView: 2-3 hours
- Integration testing: 2-3 hours
- **Total:** ~10-15 hours

**Time Saved:** ~12-16 days → ~10-15 hours = **90% time reduction!** ✅

---

## 🚀 Implementation Order (Recommended)

### Step 1: Extend TrackView for Video (2-3 hours)
1. Add `UnifiedTrack` struct to `MainWindow.h::TrackView`
2. Implement `addVideoTrack()` and `drawVideoClip()`
3. Test with existing VideoWeaver clips

### Step 2: Integrate Automation (1 hour)
1. Add `addAutomationTrack()` to TrackView
2. Implement `drawAutomationLane()` using ParameterAutomationUI logic
3. Test automation display

### Step 3: Create ClipLauncherGrid (4-6 hours)
1. Create `Sources/UI/ClipLauncherGrid.h`
2. Implement grid rendering and clip triggering
3. Add bio-reactive clip modulation
4. Test clip playback

### Step 4: Create UnifiedWorkspaceView (2-3 hours)
1. Create `Sources/UI/UnifiedWorkspaceView.h`
2. Integrate TrackView and ClipLauncherGrid
3. Implement view mode switching
4. Test keyboard shortcuts

### Step 5: Replace TrackView in MainWindow (1 hour)
1. Update `MainWindow.h` to use UnifiedWorkspaceView
2. Update `MainWindow.cpp` layout
3. Test complete integration

### Step 6: Bio-Reactive Integration (1-2 hours)
1. Connect BioFeedbackSystem to UnifiedWorkspaceView
2. Update bio-data flow to all views
3. Test bio-reactive video and automation

### Step 7: Polish & Documentation (1-2 hours)
1. Add keyboard shortcuts reference
2. Update user documentation
3. Create tutorial video/guide

**Total Time:** ~12-18 hours

---

## ✅ Success Criteria

### Feature Completeness:
- ✅ Unified timeline shows audio + video + automation tracks
- ✅ Session/clip view with 8×8 grid of clips
- ✅ View mode toggle (Arrangement ↔ Session)
- ✅ Bio-reactive video clips
- ✅ Bio-reactive automation
- ✅ BPM-sync grid and quantization
- ✅ Transport controls work in both views
- ✅ Status bar shows bio-feedback always

### Performance:
- ✅ 60 FPS smooth scrolling in timeline
- ✅ No lag when switching views (<100ms)
- ✅ Real-time bio-data updates (<50ms)

### Usability:
- ✅ Keyboard shortcut (Tab) for view switching
- ✅ Visual indicators for active view
- ✅ Consistent UI across all views
- ✅ Easy access to all features (max 2 clicks)

---

## 📝 File Change Summary

### Files to Modify:
1. ✏️ `Sources/UI/MainWindow.h` - Extend TrackView with UnifiedTrack
2. ✏️ `Sources/UI/MainWindow.cpp` - Update layout to use UnifiedWorkspaceView

### Files to Create:
3. ➕ `Sources/UI/ClipLauncherGrid.h` - NEW (400-500 LOC)
4. ➕ `Sources/UI/ClipLauncherGrid.cpp` - NEW (implementation)
5. ➕ `Sources/UI/UnifiedWorkspaceView.h` - NEW (200 LOC)
6. ➕ `Sources/UI/UnifiedWorkspaceView.cpp` - NEW (implementation)

### Files Referenced (No Changes):
- ✅ `Sources/Video/VideoWeaver.h` - Used via VideoWeaver::Clip
- ✅ `Sources/UI/ParameterAutomationUI.h` - Used via ParameterLane
- ✅ `Sources/BioData/BioFeedbackSystem.h` - Bio-data source
- ✅ `Sources/Video/BioReactiveVideoProcessor.h` - Video modulation

**Total New Files:** 4
**Total Modified Files:** 2
**Total New LOC:** ~750-850
**Total Reused LOC:** ~1,800

---

## 🎯 Next Steps

**Ready to implement?**

1. **Start with TrackView extension** (safest, incremental)
2. **Then ClipLauncherGrid** (new component, independent)
3. **Then UnifiedWorkspaceView** (integration)
4. **Finally MainWindow update** (final wiring)

**Or want to review first?**

Let me know which approach you prefer:
- ✅ Start implementation now
- 📋 Review architecture first
- 🔍 Explore specific component in detail
- 💡 Suggest alternative approach

---

**STATUS:** ✅ READY TO OPTIMIZE - No duplicate code, all wisdom preserved!
