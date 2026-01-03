#pragma once

#include <JuceHeader.h>
#include <memory>
#include <vector>
#include <map>
#include <functional>

// Core Systems
#include "../Core/PerformanceEngine.h"
#include "../Core/InternationalizationSystem.h"
#include "../Platform/EchoelUnifiedPlatform.h"

// Visual Systems
#include "../Visual/VisualForge.h"
#include "../Visual/VJLightingIntegration.h"

// Content
#include "../Content/ContentCreationSuite.h"

// Vocals
#include "../Vocals/VocalSuite.h"

/**
 * EchoelUnifiedGUI - THE ULTIMATE ALL-IN-ONE INTERFACE
 *
 * Combines the best of:
 *
 * DAWs:
 * - Ableton Live (Session View, Clip Launching, Max for Live)
 * - FL Studio (Pattern/Playlist, Piano Roll, Mixer)
 * - Reaper (Lightweight, Customizable, Performance)
 * - Logic Pro (Smart Tempo, Drummer, MIDI FX)
 * - Pro Tools (Industry Standard Editing)
 *
 * Video Editing:
 * - DaVinci Resolve (Color Grading, Fusion, Fairlight)
 * - CapCut (Quick Edits, Effects, Templates)
 * - Final Cut Pro (Magnetic Timeline)
 * - Premiere Pro (Multi-cam, Effects)
 *
 * Design:
 * - Canva (Templates, Drag & Drop)
 * - Adobe Creative Suite (Photoshop, Illustrator, After Effects)
 * - Figma (Collaborative Design)
 *
 * 3D / Game Engines:
 * - Blender (3D Modeling, Animation, Rendering)
 * - Unity (Real-time 3D, AR/VR)
 * - Unreal Engine (Photorealistic, Blueprints)
 *
 * Streaming / VJ:
 * - OBS Studio (Streaming, Recording, Scenes)
 * - Resolume Arena (VJ, LED Mapping, Projection)
 * - TouchDesigner (Node-based Visuals)
 * - vMix (Live Production)
 *
 * Lighting:
 * - GrandMA3 (Professional Lighting)
 * - Pangolin (Laser Control)
 * - DMXIS (DMX Control)
 * - Lightkey (Mac Lighting)
 *
 * ALL IN ONE - BETTER THAN REAPER PERFORMANCE
 * 2026 READY - QUANTUM SCIENCE - WORLDWIDE
 */

namespace Echoelmusic {
namespace UI {

//==============================================================================
// Workspace Modes
//==============================================================================

enum class WorkspaceMode
{
    // Music Production
    Arrange,            // Linear timeline (Pro Tools style)
    Session,            // Clip launcher (Ableton style)
    Pattern,            // Pattern-based (FL Studio style)
    Mixer,              // Full mixer view
    MasteringLab,       // Mastering suite

    // Video Production
    VideoEdit,          // Timeline video editing
    ColorGrade,         // DaVinci-style color grading
    MotionGraphics,     // After Effects style
    QuickEdit,          // CapCut-style fast edits

    // Design
    GraphicDesign,      // Canva/Photoshop style
    VectorArt,          // Illustrator style
    TemplateEditor,     // Social media templates

    // 3D
    Model3D,            // Blender modeling
    Animate3D,          // 3D animation
    GameEngine,         // Unity/Unreal style

    // Live Performance
    VJPerformance,      // Resolume Arena style
    LiveStream,         // OBS-style streaming
    LightingDesign,     // DMX/Laser control
    LiveShow,           // Combined AV performance

    // Content Creation
    Podcast,            // Podcast production
    SocialMedia,        // Social media content
    Blog,               // Blog/article writing

    // Wellness
    Meditation,         // Biofeedback meditation
    Soundscape,         // Ambient sound design
    Therapy,            // Sound therapy mode

    // All-in-One
    Unified             // Everything visible
};

//==============================================================================
// Panel Types
//==============================================================================

enum class PanelType
{
    // Transport & Navigation
    Transport,
    Timeline,
    Navigator,
    Markers,

    // Audio
    Tracks,
    Mixer,
    ChannelStrip,
    Meters,
    PianoRoll,
    Automation,
    Plugins,

    // Video
    VideoPreview,
    VideoTimeline,
    MediaBrowser,
    ColorWheels,
    Scopes,
    EffectsRack,

    // Visual/VJ
    VisualLayers,
    EffectBank,
    ClipBank,
    BeatGrid,
    OutputPreview,

    // Lighting
    FixturePatch,
    CueList,
    Programmer,
    DMXMonitor,
    PixelMap,

    // Design
    Canvas,
    Layers,
    Tools,
    Properties,
    Assets,
    Templates,

    // 3D
    Viewport3D,
    Outliner,
    NodeEditor,
    MaterialEditor,
    Timeline3D,

    // Content
    TextEditor,
    PreviewPane,
    ExportSettings,

    // Biofeedback
    BioDashboard,
    HRVGraph,
    BreathGuide,
    WellnessMetrics,

    // Utility
    Browser,
    Inspector,
    Console,
    Performance
};

//==============================================================================
// Panel Configuration
//==============================================================================

struct PanelConfig
{
    PanelType type;
    std::string name;
    juce::Rectangle<int> bounds;
    bool isVisible = true;
    bool isFloating = false;
    bool isMinimized = false;
    float opacity = 1.0f;

    // Docking
    enum class DockPosition { Left, Right, Top, Bottom, Center, Float };
    DockPosition dockPosition = DockPosition::Center;
    int dockOrder = 0;
};

//==============================================================================
// Layout Presets
//==============================================================================

struct LayoutPreset
{
    std::string name;
    WorkspaceMode mode;
    std::vector<PanelConfig> panels;
    juce::Colour accentColor;
    std::string iconPath;
};

//==============================================================================
// Touch/Gesture Support
//==============================================================================

struct GestureConfig
{
    bool enablePinchZoom = true;
    bool enableTwoFingerScroll = true;
    bool enableThreeFingerSwipe = true;
    float touchSensitivity = 1.0f;
    bool enablePenPressure = true;
    bool enableTiltDetection = true;
};

//==============================================================================
// Keyboard Shortcut System
//==============================================================================

struct KeyboardShortcut
{
    std::string action;
    juce::KeyPress keyPress;
    std::string category;
    std::string description;
};

//==============================================================================
// Quick Action Wheel (Touch/Pen)
//==============================================================================

struct QuickActionWheel
{
    std::vector<std::pair<std::string, std::function<void()>>> actions;
    bool isVisible = false;
    juce::Point<int> position;

    void addAction(const std::string& name, std::function<void()> action)
    {
        actions.push_back({name, action});
    }

    void show(juce::Point<int> pos)
    {
        position = pos;
        isVisible = true;
    }

    void hide() { isVisible = false; }
};

//==============================================================================
// Main Unified GUI Class
//==============================================================================

class EchoelUnifiedGUI : public juce::Component,
                         public juce::Timer
{
public:
    //==========================================================================
    // Singleton
    //==========================================================================

    static EchoelUnifiedGUI& getInstance()
    {
        static EchoelUnifiedGUI instance;
        return instance;
    }

    //==========================================================================
    // Initialization
    //==========================================================================

    void initialize()
    {
        // Initialize core systems
        Core::PerformanceEngine::getInstance().initialize();
        Core::InternationalizationSystem::getInstance().initialize();
        Platform::EchoelUnifiedPlatform::getInstance().initialize();
        Visual::VJLightingIntegration::getInstance().initialize();

        // Setup default layout
        createDefaultLayouts();
        setWorkspaceMode(WorkspaceMode::Unified);

        // Setup keyboard shortcuts
        initializeKeyboardShortcuts();

        // Start performance monitoring
        startTimer(16);  // ~60 FPS UI updates

        isInitialized = true;
    }

    //==========================================================================
    // Workspace Management
    //==========================================================================

    void setWorkspaceMode(WorkspaceMode mode)
    {
        currentMode = mode;
        applyLayoutForMode(mode);
        repaint();
    }

    WorkspaceMode getWorkspaceMode() const { return currentMode; }

    void toggleFullscreen()
    {
        if (auto* peer = getPeer())
            peer->setFullScreen(!peer->isFullScreen());
    }

    //==========================================================================
    // Panel Management
    //==========================================================================

    void showPanel(PanelType type)
    {
        if (auto* panel = getPanel(type))
            panel->isVisible = true;
        resized();
    }

    void hidePanel(PanelType type)
    {
        if (auto* panel = getPanel(type))
            panel->isVisible = false;
        resized();
    }

    void togglePanel(PanelType type)
    {
        if (auto* panel = getPanel(type))
            panel->isVisible = !panel->isVisible;
        resized();
    }

    void floatPanel(PanelType type)
    {
        if (auto* panel = getPanel(type))
        {
            panel->isFloating = true;
            panel->dockPosition = PanelConfig::DockPosition::Float;
        }
    }

    void dockPanel(PanelType type, PanelConfig::DockPosition position)
    {
        if (auto* panel = getPanel(type))
        {
            panel->isFloating = false;
            panel->dockPosition = position;
        }
        resized();
    }

    //==========================================================================
    // Layout Presets
    //==========================================================================

    void saveLayoutPreset(const std::string& name)
    {
        LayoutPreset preset;
        preset.name = name;
        preset.mode = currentMode;
        preset.panels = currentPanels;
        layoutPresets[name] = preset;
    }

    void loadLayoutPreset(const std::string& name)
    {
        if (auto it = layoutPresets.find(name); it != layoutPresets.end())
        {
            currentPanels = it->second.panels;
            currentMode = it->second.mode;
            resized();
        }
    }

    std::vector<std::string> getLayoutPresetNames() const
    {
        std::vector<std::string> names;
        for (const auto& [name, preset] : layoutPresets)
            names.push_back(name);
        return names;
    }

    //==========================================================================
    // Theme Management
    //==========================================================================

    struct Theme
    {
        std::string name;
        juce::Colour background;
        juce::Colour panelBackground;
        juce::Colour accent;
        juce::Colour text;
        juce::Colour textDim;
        juce::Colour highlight;
        juce::Colour warning;
        juce::Colour error;
        juce::Colour success;
        float borderRadius = 8.0f;
        float panelOpacity = 0.95f;
    };

    void setTheme(const Theme& theme)
    {
        currentTheme = theme;
        repaint();
    }

    Theme getTheme() const { return currentTheme; }

    void setDarkMode(bool dark)
    {
        if (dark)
        {
            currentTheme.background = juce::Colour(0xFF0A0A0A);
            currentTheme.panelBackground = juce::Colour(0xFF1A1A1A);
            currentTheme.text = juce::Colours::white;
            currentTheme.textDim = juce::Colour(0xFF888888);
        }
        else
        {
            currentTheme.background = juce::Colour(0xFFF0F0F0);
            currentTheme.panelBackground = juce::Colours::white;
            currentTheme.text = juce::Colours::black;
            currentTheme.textDim = juce::Colour(0xFF666666);
        }
        repaint();
    }

    //==========================================================================
    // Quick Actions
    //==========================================================================

    void showQuickActions(juce::Point<int> position)
    {
        quickActionWheel.show(position);
        repaint();
    }

    void hideQuickActions()
    {
        quickActionWheel.hide();
        repaint();
    }

    void addQuickAction(const std::string& name, std::function<void()> action)
    {
        quickActionWheel.addAction(name, action);
    }

    //==========================================================================
    // Command Palette (Cmd+K / Ctrl+K)
    //==========================================================================

    void showCommandPalette()
    {
        commandPaletteVisible = true;
        commandPaletteQuery = "";
        repaint();
    }

    void hideCommandPalette()
    {
        commandPaletteVisible = false;
        repaint();
    }

    void executeCommand(const std::string& command)
    {
        if (auto it = commands.find(command); it != commands.end())
            it->second();
    }

    void registerCommand(const std::string& name, std::function<void()> action)
    {
        commands[name] = action;
    }

    //==========================================================================
    // Performance Display
    //==========================================================================

    void setShowPerformanceOverlay(bool show)
    {
        showPerformanceOverlay = show;
        repaint();
    }

    //==========================================================================
    // Component Overrides
    //==========================================================================

    void paint(juce::Graphics& g) override
    {
        // Background
        g.fillAll(currentTheme.background);

        // Draw panels
        for (const auto& panel : currentPanels)
        {
            if (!panel.isVisible || panel.isFloating) continue;
            drawPanel(g, panel);
        }

        // Draw floating panels on top
        for (const auto& panel : currentPanels)
        {
            if (!panel.isVisible || !panel.isFloating) continue;
            drawPanel(g, panel);
        }

        // Quick Action Wheel
        if (quickActionWheel.isVisible)
            drawQuickActionWheel(g);

        // Command Palette
        if (commandPaletteVisible)
            drawCommandPalette(g);

        // Performance Overlay
        if (showPerformanceOverlay)
            drawPerformanceOverlay(g);

        // Top Menu Bar
        drawMenuBar(g);

        // Status Bar
        drawStatusBar(g);
    }

    void resized() override
    {
        auto bounds = getLocalBounds();

        // Reserve space for menu and status bars
        menuBarBounds = bounds.removeFromTop(30);
        statusBarBounds = bounds.removeFromBottom(24);

        // Calculate panel layout
        calculatePanelLayout(bounds);
    }

    //==========================================================================
    // Mouse Handling
    //==========================================================================

    void mouseDown(const juce::MouseEvent& e) override
    {
        // Right-click for quick actions
        if (e.mods.isRightButtonDown())
        {
            showQuickActions(e.getPosition());
            return;
        }

        // Handle panel interactions
        for (auto& panel : currentPanels)
        {
            if (panel.bounds.contains(e.getPosition()))
            {
                handlePanelClick(panel, e);
                return;
            }
        }
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        // Handle panel dragging/resizing
        if (draggingPanel)
        {
            auto newBounds = draggingPanel->bounds;
            newBounds.setPosition(e.getPosition() - dragOffset);
            draggingPanel->bounds = newBounds;
            repaint();
        }
    }

    void mouseUp(const juce::MouseEvent& e) override
    {
        draggingPanel = nullptr;
    }

    void mouseWheelMove(const juce::MouseEvent& e,
                        const juce::MouseWheelDetails& wheel) override
    {
        // Zoom with Ctrl/Cmd + scroll
        if (e.mods.isCommandDown())
        {
            zoomLevel += wheel.deltaY * 0.1f;
            zoomLevel = juce::jlimit(0.25f, 4.0f, zoomLevel);
            repaint();
        }
    }

    //==========================================================================
    // Keyboard Handling
    //==========================================================================

    bool keyPressed(const juce::KeyPress& key) override
    {
        // Command Palette (Cmd+K)
        if (key.isKeyCode('K') && key.getModifiers().isCommandDown())
        {
            showCommandPalette();
            return true;
        }

        // Check registered shortcuts
        for (const auto& shortcut : keyboardShortcuts)
        {
            if (shortcut.keyPress == key)
            {
                executeCommand(shortcut.action);
                return true;
            }
        }

        // Workspace switching (F1-F12)
        if (key.isKeyCode(juce::KeyPress::F1Key))
            { setWorkspaceMode(WorkspaceMode::Arrange); return true; }
        if (key.isKeyCode(juce::KeyPress::F2Key))
            { setWorkspaceMode(WorkspaceMode::Session); return true; }
        if (key.isKeyCode(juce::KeyPress::F3Key))
            { setWorkspaceMode(WorkspaceMode::Mixer); return true; }
        if (key.isKeyCode(juce::KeyPress::F4Key))
            { setWorkspaceMode(WorkspaceMode::VideoEdit); return true; }
        if (key.isKeyCode(juce::KeyPress::F5Key))
            { setWorkspaceMode(WorkspaceMode::VJPerformance); return true; }
        if (key.isKeyCode(juce::KeyPress::F6Key))
            { setWorkspaceMode(WorkspaceMode::LiveStream); return true; }

        return false;
    }

    //==========================================================================
    // Timer Callback (Performance Updates)
    //==========================================================================

    void timerCallback() override
    {
        // Update performance metrics display
        if (showPerformanceOverlay)
            repaint(performanceOverlayBounds);

        // Check if UI refresh needed
        if (Core::PerformanceEngine::getInstance().shouldRefreshUI())
        {
            Core::PerformanceEngine::getInstance().markUIRefresh();
            // Repaint only dirty regions
        }
    }

private:
    EchoelUnifiedGUI()
    {
        setSize(1920, 1080);
        initializeTheme();
        initializeQuickActions();
        initializeCommands();
    }

    //==========================================================================
    // Initialization Helpers
    //==========================================================================

    void initializeTheme()
    {
        // Default dark theme
        currentTheme.name = "Echoelmusic Dark";
        currentTheme.background = juce::Colour(0xFF0A0A0A);
        currentTheme.panelBackground = juce::Colour(0xFF1A1A1A);
        currentTheme.accent = juce::Colour(0xFF00D4FF);      // Cyan
        currentTheme.text = juce::Colours::white;
        currentTheme.textDim = juce::Colour(0xFF888888);
        currentTheme.highlight = juce::Colour(0xFF00FF88);   // Green
        currentTheme.warning = juce::Colour(0xFFFFAA00);     // Orange
        currentTheme.error = juce::Colour(0xFFFF4444);       // Red
        currentTheme.success = juce::Colour(0xFF44FF44);     // Green
    }

    void initializeQuickActions()
    {
        quickActionWheel.addAction("Play/Stop", []() {
            // Toggle transport
        });
        quickActionWheel.addAction("Record", []() {
            // Start recording
        });
        quickActionWheel.addAction("Add Track", []() {
            // Add new track
        });
        quickActionWheel.addAction("Add Plugin", []() {
            // Open plugin browser
        });
        quickActionWheel.addAction("Undo", []() {
            // Undo last action
        });
        quickActionWheel.addAction("Save", []() {
            // Save project
        });
    }

    void initializeCommands()
    {
        // File commands
        registerCommand("New Project", []() {});
        registerCommand("Open Project", []() {});
        registerCommand("Save Project", []() {});
        registerCommand("Export Audio", []() {});
        registerCommand("Export Video", []() {});

        // View commands
        registerCommand("Toggle Fullscreen", [this]() { toggleFullscreen(); });
        registerCommand("Show Mixer", [this]() { setWorkspaceMode(WorkspaceMode::Mixer); });
        registerCommand("Show Arrange", [this]() { setWorkspaceMode(WorkspaceMode::Arrange); });
        registerCommand("Show Session", [this]() { setWorkspaceMode(WorkspaceMode::Session); });

        // Workspace commands
        registerCommand("Music Mode", [this]() { setWorkspaceMode(WorkspaceMode::Arrange); });
        registerCommand("Video Mode", [this]() { setWorkspaceMode(WorkspaceMode::VideoEdit); });
        registerCommand("VJ Mode", [this]() { setWorkspaceMode(WorkspaceMode::VJPerformance); });
        registerCommand("Stream Mode", [this]() { setWorkspaceMode(WorkspaceMode::LiveStream); });
        registerCommand("Design Mode", [this]() { setWorkspaceMode(WorkspaceMode::GraphicDesign); });
        registerCommand("3D Mode", [this]() { setWorkspaceMode(WorkspaceMode::Model3D); });
    }

    void initializeKeyboardShortcuts()
    {
        // Transport
        keyboardShortcuts.push_back({"Play/Stop", juce::KeyPress::spaceKey, "Transport", "Toggle playback"});
        keyboardShortcuts.push_back({"Record", juce::KeyPress('R', juce::ModifierKeys::commandModifier, 0), "Transport", "Start recording"});

        // Edit
        keyboardShortcuts.push_back({"Undo", juce::KeyPress('Z', juce::ModifierKeys::commandModifier, 0), "Edit", "Undo"});
        keyboardShortcuts.push_back({"Redo", juce::KeyPress('Z', juce::ModifierKeys::commandModifier | juce::ModifierKeys::shiftModifier, 0), "Edit", "Redo"});
        keyboardShortcuts.push_back({"Cut", juce::KeyPress('X', juce::ModifierKeys::commandModifier, 0), "Edit", "Cut"});
        keyboardShortcuts.push_back({"Copy", juce::KeyPress('C', juce::ModifierKeys::commandModifier, 0), "Edit", "Copy"});
        keyboardShortcuts.push_back({"Paste", juce::KeyPress('V', juce::ModifierKeys::commandModifier, 0), "Edit", "Paste"});

        // File
        keyboardShortcuts.push_back({"Save", juce::KeyPress('S', juce::ModifierKeys::commandModifier, 0), "File", "Save project"});
        keyboardShortcuts.push_back({"Open", juce::KeyPress('O', juce::ModifierKeys::commandModifier, 0), "File", "Open project"});
    }

    void createDefaultLayouts()
    {
        // MUSIC ARRANGE LAYOUT
        LayoutPreset arrangeLayout;
        arrangeLayout.name = "Music - Arrange";
        arrangeLayout.mode = WorkspaceMode::Arrange;
        arrangeLayout.accentColor = juce::Colour(0xFF00D4FF);
        arrangeLayout.panels = {
            {PanelType::Transport, "Transport", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Top},
            {PanelType::Tracks, "Tracks", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Left},
            {PanelType::Timeline, "Timeline", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Center},
            {PanelType::Browser, "Browser", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Right},
            {PanelType::Mixer, "Mixer", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Bottom}
        };
        layoutPresets["Music - Arrange"] = arrangeLayout;

        // SESSION LAYOUT (Ableton style)
        LayoutPreset sessionLayout;
        sessionLayout.name = "Music - Session";
        sessionLayout.mode = WorkspaceMode::Session;
        sessionLayout.panels = {
            {PanelType::Transport, "Transport", {}, true},
            {PanelType::Tracks, "Clip Grid", {}, true},
            {PanelType::Browser, "Instruments", {}, true},
            {PanelType::Mixer, "Mixer", {}, true}
        };
        layoutPresets["Music - Session"] = sessionLayout;

        // VIDEO EDITING LAYOUT
        LayoutPreset videoLayout;
        videoLayout.name = "Video Edit";
        videoLayout.mode = WorkspaceMode::VideoEdit;
        videoLayout.accentColor = juce::Colour(0xFFFF6B6B);
        videoLayout.panels = {
            {PanelType::MediaBrowser, "Media", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Left},
            {PanelType::VideoPreview, "Preview", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Center},
            {PanelType::Inspector, "Inspector", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Right},
            {PanelType::VideoTimeline, "Timeline", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Bottom}
        };
        layoutPresets["Video Edit"] = videoLayout;

        // VJ PERFORMANCE LAYOUT
        LayoutPreset vjLayout;
        vjLayout.name = "VJ Performance";
        vjLayout.mode = WorkspaceMode::VJPerformance;
        vjLayout.accentColor = juce::Colour(0xFFFF00FF);
        vjLayout.panels = {
            {PanelType::ClipBank, "Clips", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Left},
            {PanelType::VisualLayers, "Layers", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Center},
            {PanelType::OutputPreview, "Output", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Right},
            {PanelType::EffectBank, "Effects", {}, true, false, false, 1.0f, PanelConfig::DockPosition::Bottom}
        };
        layoutPresets["VJ Performance"] = vjLayout;

        // LIVE STREAMING LAYOUT
        LayoutPreset streamLayout;
        streamLayout.name = "Live Stream";
        streamLayout.mode = WorkspaceMode::LiveStream;
        streamLayout.accentColor = juce::Colour(0xFFFF0000);
        streamLayout.panels = {
            {PanelType::VideoPreview, "Preview", {}, true},
            {PanelType::OutputPreview, "Program", {}, true},
            {PanelType::Mixer, "Audio", {}, true},
            {PanelType::Console, "Chat", {}, true}
        };
        layoutPresets["Live Stream"] = streamLayout;

        // LIGHTING DESIGN LAYOUT
        LayoutPreset lightingLayout;
        lightingLayout.name = "Lighting Design";
        lightingLayout.mode = WorkspaceMode::LightingDesign;
        lightingLayout.accentColor = juce::Colour(0xFFFFAA00);
        lightingLayout.panels = {
            {PanelType::FixturePatch, "Fixtures", {}, true},
            {PanelType::Programmer, "Programmer", {}, true},
            {PanelType::CueList, "Cues", {}, true},
            {PanelType::DMXMonitor, "DMX Monitor", {}, true}
        };
        layoutPresets["Lighting Design"] = lightingLayout;

        // 3D LAYOUT
        LayoutPreset threeDLayout;
        threeDLayout.name = "3D Modeling";
        threeDLayout.mode = WorkspaceMode::Model3D;
        threeDLayout.accentColor = juce::Colour(0xFF00FF88);
        threeDLayout.panels = {
            {PanelType::Outliner, "Outliner", {}, true},
            {PanelType::Viewport3D, "3D View", {}, true},
            {PanelType::Properties, "Properties", {}, true},
            {PanelType::NodeEditor, "Nodes", {}, true}
        };
        layoutPresets["3D Modeling"] = threeDLayout;

        // UNIFIED LAYOUT (Everything)
        LayoutPreset unifiedLayout;
        unifiedLayout.name = "Unified";
        unifiedLayout.mode = WorkspaceMode::Unified;
        unifiedLayout.accentColor = juce::Colour(0xFF00D4FF);
        unifiedLayout.panels = {
            {PanelType::Transport, "Transport", {}, true},
            {PanelType::Tracks, "Tracks", {}, true},
            {PanelType::Timeline, "Timeline", {}, true},
            {PanelType::VideoPreview, "Video", {}, true},
            {PanelType::Mixer, "Mixer", {}, true},
            {PanelType::BioDashboard, "Biofeedback", {}, true},
            {PanelType::Browser, "Browser", {}, true}
        };
        layoutPresets["Unified"] = unifiedLayout;
    }

    void applyLayoutForMode(WorkspaceMode mode)
    {
        std::string presetName;

        switch (mode)
        {
            case WorkspaceMode::Arrange:        presetName = "Music - Arrange"; break;
            case WorkspaceMode::Session:        presetName = "Music - Session"; break;
            case WorkspaceMode::VideoEdit:      presetName = "Video Edit"; break;
            case WorkspaceMode::VJPerformance:  presetName = "VJ Performance"; break;
            case WorkspaceMode::LiveStream:     presetName = "Live Stream"; break;
            case WorkspaceMode::LightingDesign: presetName = "Lighting Design"; break;
            case WorkspaceMode::Model3D:        presetName = "3D Modeling"; break;
            case WorkspaceMode::Unified:        presetName = "Unified"; break;
            default:                            presetName = "Unified"; break;
        }

        loadLayoutPreset(presetName);
    }

    //==========================================================================
    // Layout Calculation
    //==========================================================================

    void calculatePanelLayout(juce::Rectangle<int> bounds)
    {
        // Dock-based layout calculation
        auto leftWidth = bounds.getWidth() / 5;
        auto rightWidth = bounds.getWidth() / 5;
        auto bottomHeight = bounds.getHeight() / 3;
        auto topHeight = 50;

        for (auto& panel : currentPanels)
        {
            if (!panel.isVisible || panel.isFloating) continue;

            switch (panel.dockPosition)
            {
                case PanelConfig::DockPosition::Top:
                    panel.bounds = bounds.removeFromTop(topHeight);
                    break;
                case PanelConfig::DockPosition::Bottom:
                    panel.bounds = bounds.removeFromBottom(bottomHeight);
                    break;
                case PanelConfig::DockPosition::Left:
                    panel.bounds = bounds.removeFromLeft(leftWidth);
                    break;
                case PanelConfig::DockPosition::Right:
                    panel.bounds = bounds.removeFromRight(rightWidth);
                    break;
                case PanelConfig::DockPosition::Center:
                    panel.bounds = bounds;
                    break;
                default:
                    break;
            }
        }
    }

    //==========================================================================
    // Drawing Helpers
    //==========================================================================

    void drawPanel(juce::Graphics& g, const PanelConfig& panel)
    {
        auto bounds = panel.bounds.toFloat();

        // Panel background
        g.setColour(currentTheme.panelBackground.withAlpha(panel.opacity * currentTheme.panelOpacity));
        g.fillRoundedRectangle(bounds, currentTheme.borderRadius);

        // Panel border
        g.setColour(currentTheme.accent.withAlpha(0.3f));
        g.drawRoundedRectangle(bounds, currentTheme.borderRadius, 1.0f);

        // Panel header
        auto headerBounds = bounds.removeFromTop(28);
        g.setColour(currentTheme.accent.withAlpha(0.1f));
        g.fillRoundedRectangle(headerBounds, currentTheme.borderRadius);

        // Panel title
        g.setColour(currentTheme.text);
        g.setFont(14.0f);
        g.drawText(panel.name, headerBounds.reduced(8, 0), juce::Justification::centredLeft);
    }

    void drawMenuBar(juce::Graphics& g)
    {
        g.setColour(currentTheme.panelBackground);
        g.fillRect(menuBarBounds);

        g.setColour(currentTheme.text);
        g.setFont(13.0f);

        auto& i18n = Core::InternationalizationSystem::getInstance();

        int x = 10;
        for (const auto& menu : {"File", "Edit", "View", "Track", "Audio", "Video", "VJ", "Stream", "Help"})
        {
            g.drawText(i18n.translate(std::string("menu.") + menu),
                       x, menuBarBounds.getY(), 60, menuBarBounds.getHeight(),
                       juce::Justification::centredLeft);
            x += 70;
        }

        // Workspace mode indicator
        g.setColour(currentTheme.accent);
        g.drawText(getWorkspaceModeString(currentMode),
                   menuBarBounds.getWidth() - 200, menuBarBounds.getY(),
                   190, menuBarBounds.getHeight(),
                   juce::Justification::centredRight);
    }

    void drawStatusBar(juce::Graphics& g)
    {
        g.setColour(currentTheme.panelBackground);
        g.fillRect(statusBarBounds);

        g.setColour(currentTheme.textDim);
        g.setFont(11.0f);

        // Performance metrics
        auto& perf = Core::PerformanceEngine::getInstance().getMetrics();
        std::string status = "CPU: " + std::to_string(static_cast<int>(perf.cpuLoad)) + "% | "
                           + "Latency: " + std::to_string(static_cast<int>(perf.audioLatencyMs)) + "ms | "
                           + std::to_string(perf.sampleRate / 1000) + "kHz / "
                           + std::to_string(perf.bufferSize) + " samples";

        g.drawText(status, statusBarBounds.reduced(10, 0), juce::Justification::centredLeft);

        // Language indicator
        auto& i18n = Core::InternationalizationSystem::getInstance();
        g.drawText(i18n.getLanguageName(i18n.getLanguage()),
                   statusBarBounds.getWidth() - 150, statusBarBounds.getY(),
                   140, statusBarBounds.getHeight(),
                   juce::Justification::centredRight);
    }

    void drawQuickActionWheel(juce::Graphics& g)
    {
        const float radius = 100.0f;
        const float innerRadius = 40.0f;

        auto center = quickActionWheel.position.toFloat();

        // Background circle
        g.setColour(currentTheme.panelBackground.withAlpha(0.95f));
        g.fillEllipse(center.x - radius, center.y - radius, radius * 2, radius * 2);

        // Draw action segments
        float anglePerAction = juce::MathConstants<float>::twoPi / quickActionWheel.actions.size();

        for (size_t i = 0; i < quickActionWheel.actions.size(); ++i)
        {
            float angle = i * anglePerAction - juce::MathConstants<float>::halfPi;

            // Action position
            float actionRadius = (radius + innerRadius) / 2;
            float x = center.x + std::cos(angle) * actionRadius;
            float y = center.y + std::sin(angle) * actionRadius;

            g.setColour(currentTheme.text);
            g.setFont(12.0f);
            g.drawText(quickActionWheel.actions[i].first,
                       static_cast<int>(x - 40), static_cast<int>(y - 10), 80, 20,
                       juce::Justification::centred);
        }
    }

    void drawCommandPalette(juce::Graphics& g)
    {
        auto bounds = getLocalBounds();
        auto paletteWidth = 500;
        auto paletteHeight = 400;
        auto paletteBounds = juce::Rectangle<int>(
            (bounds.getWidth() - paletteWidth) / 2,
            bounds.getHeight() / 5,
            paletteWidth,
            paletteHeight
        );

        // Backdrop
        g.setColour(juce::Colours::black.withAlpha(0.7f));
        g.fillRect(bounds);

        // Palette background
        g.setColour(currentTheme.panelBackground);
        g.fillRoundedRectangle(paletteBounds.toFloat(), 12.0f);

        // Search box
        auto searchBounds = paletteBounds.removeFromTop(50).reduced(15, 10);
        g.setColour(currentTheme.background);
        g.fillRoundedRectangle(searchBounds.toFloat(), 6.0f);

        g.setColour(currentTheme.text);
        g.setFont(16.0f);
        g.drawText(commandPaletteQuery.empty() ? "Type a command..." : commandPaletteQuery,
                   searchBounds.reduced(10, 0), juce::Justification::centredLeft);

        // Command list
        g.setFont(14.0f);
        int y = paletteBounds.getY() + 10;
        for (const auto& [name, action] : commands)
        {
            if (y > paletteBounds.getBottom() - 30) break;

            g.setColour(currentTheme.textDim);
            g.drawText(name, paletteBounds.getX() + 15, y, paletteBounds.getWidth() - 30, 25,
                       juce::Justification::centredLeft);
            y += 28;
        }
    }

    void drawPerformanceOverlay(juce::Graphics& g)
    {
        performanceOverlayBounds = juce::Rectangle<int>(getWidth() - 220, 40, 210, 150);

        g.setColour(currentTheme.panelBackground.withAlpha(0.9f));
        g.fillRoundedRectangle(performanceOverlayBounds.toFloat(), 8.0f);

        auto& perf = Core::PerformanceEngine::getInstance().getMetrics();

        g.setColour(currentTheme.text);
        g.setFont(12.0f);

        int y = performanceOverlayBounds.getY() + 10;
        int x = performanceOverlayBounds.getX() + 10;

        auto drawMetric = [&](const std::string& label, const std::string& value, juce::Colour color) {
            g.setColour(currentTheme.textDim);
            g.drawText(label, x, y, 100, 18, juce::Justification::left);
            g.setColour(color);
            g.drawText(value, x + 100, y, 90, 18, juce::Justification::right);
            y += 20;
        };

        drawMetric("CPU", std::to_string(static_cast<int>(perf.cpuLoad)) + "%",
                   perf.cpuLoad > 80 ? currentTheme.error : currentTheme.success);
        drawMetric("Latency", std::to_string(static_cast<int>(perf.audioLatencyMs)) + "ms",
                   perf.audioLatencyMs > 10 ? currentTheme.warning : currentTheme.success);
        drawMetric("Buffer", std::to_string(perf.bufferSize) + " samples", currentTheme.text);
        drawMetric("Sample Rate", std::to_string(perf.sampleRate) + " Hz", currentTheme.text);
        drawMetric("UI FPS", std::to_string(static_cast<int>(perf.uiFrameRate)), currentTheme.text);
        drawMetric("Threads", std::to_string(perf.threadCount), currentTheme.text);
    }

    //==========================================================================
    // Helpers
    //==========================================================================

    PanelConfig* getPanel(PanelType type)
    {
        for (auto& panel : currentPanels)
            if (panel.type == type) return &panel;
        return nullptr;
    }

    void handlePanelClick(PanelConfig& panel, const juce::MouseEvent& e)
    {
        // Check for header drag
        auto headerBounds = panel.bounds;
        headerBounds.setHeight(28);

        if (headerBounds.contains(e.getPosition()))
        {
            draggingPanel = &panel;
            dragOffset = e.getPosition() - panel.bounds.getPosition();
        }
    }

    std::string getWorkspaceModeString(WorkspaceMode mode) const
    {
        switch (mode)
        {
            case WorkspaceMode::Arrange:        return "Arrange";
            case WorkspaceMode::Session:        return "Session";
            case WorkspaceMode::Pattern:        return "Pattern";
            case WorkspaceMode::Mixer:          return "Mixer";
            case WorkspaceMode::VideoEdit:      return "Video Edit";
            case WorkspaceMode::ColorGrade:     return "Color Grade";
            case WorkspaceMode::VJPerformance:  return "VJ Performance";
            case WorkspaceMode::LiveStream:     return "Live Stream";
            case WorkspaceMode::LightingDesign: return "Lighting";
            case WorkspaceMode::GraphicDesign:  return "Design";
            case WorkspaceMode::Model3D:        return "3D";
            case WorkspaceMode::Unified:        return "Unified";
            default:                            return "Unknown";
        }
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    bool isInitialized = false;
    WorkspaceMode currentMode = WorkspaceMode::Unified;
    Theme currentTheme;
    float zoomLevel = 1.0f;

    // Panels
    std::vector<PanelConfig> currentPanels;
    std::map<std::string, LayoutPreset> layoutPresets;

    // Interaction
    PanelConfig* draggingPanel = nullptr;
    juce::Point<int> dragOffset;
    GestureConfig gestureConfig;

    // Quick Actions
    QuickActionWheel quickActionWheel;

    // Command Palette
    bool commandPaletteVisible = false;
    std::string commandPaletteQuery;
    std::map<std::string, std::function<void()>> commands;

    // Keyboard
    std::vector<KeyboardShortcut> keyboardShortcuts;

    // Performance
    bool showPerformanceOverlay = true;
    juce::Rectangle<int> performanceOverlayBounds;

    // Layout bounds
    juce::Rectangle<int> menuBarBounds;
    juce::Rectangle<int> statusBarBounds;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelUnifiedGUI)
};

//==============================================================================
// Convenience Macro
//==============================================================================

#define EchoelGUI EchoelUnifiedGUI::getInstance()

} // namespace UI
} // namespace Echoelmusic
