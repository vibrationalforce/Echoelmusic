#pragma once

#include <JuceHeader.h>
#include <memory>
#include <functional>

/**
 * PluginEditorWindow - VST3/AU Plugin UI Host
 *
 * Dedicated floating window for plugin editors.
 * Handles embedding plugin UIs from VST3, AU, and other formats.
 *
 * Features:
 * - Multi-window support (multiple plugins open simultaneously)
 * - Window position persistence
 * - Always-on-top mode
 * - Resizable/non-resizable based on plugin capabilities
 * - Parameter automation display
 * - Preset browser integration
 * - A/B comparison mode
 * - CPU usage display
 * - Bypass button
 *
 * Inspiration:
 * - Ableton Live plugin windows
 * - Logic Pro plugin windows
 * - Bitwig plugin windows
 *
 * Use Cases:
 * - Edit synthesizer patches
 * - Tweak effect parameters
 * - Browse and load presets
 * - Record automation
 */
class PluginEditorWindow : public juce::DocumentWindow
{
public:
    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    /**
     * Create plugin editor window
     *
     * @param pluginInstance The audio plugin processor instance
     * @param pluginName Display name for the window title
     */
    PluginEditorWindow(juce::AudioProcessor* pluginInstance,
                       const juce::String& pluginName);

    ~PluginEditorWindow() override;

    //==========================================================================
    // Plugin Management
    //==========================================================================

    /** Get the plugin instance */
    juce::AudioProcessor* getPluginInstance() const { return plugin; }

    /** Get plugin name */
    juce::String getPluginName() const { return pluginName; }

    /** Refresh editor (useful after preset change) */
    void refreshEditor();

    /** Check if plugin has editor */
    bool hasEditor() const;

    //==========================================================================
    // Window Controls
    //==========================================================================

    /** Show window at saved position */
    void showWindow();

    /** Hide window */
    void hideWindow();

    /** Toggle visibility */
    void toggleVisibility();

    /** Check if visible */
    bool isWindowVisible() const;

    /** Set always on top */
    void setAlwaysOnTop(bool shouldBeOnTop);

    /** Check if always on top */
    bool isAlwaysOnTop() const { return alwaysOnTop; }

    //==========================================================================
    // Toolbar Features
    //==========================================================================

    /** Enable/disable toolbar */
    void setToolbarVisible(bool visible);

    /** Check if toolbar is visible */
    bool isToolbarVisible() const { return showToolbar; }

    /** Set bypass state */
    void setBypass(bool shouldBypass);

    /** Get bypass state */
    bool isBypassed() const { return bypassed; }

    //==========================================================================
    // Preset Management
    //==========================================================================

    /** Open preset browser */
    void openPresetBrowser();

    /** Save current state as preset */
    void savePreset(const juce::String& presetName);

    /** Load preset */
    void loadPreset(const juce::File& presetFile);

    /** Get current preset name */
    juce::String getCurrentPresetName() const { return currentPresetName; }

    //==========================================================================
    // A/B Comparison
    //==========================================================================

    /** Enable A/B comparison mode */
    void enableABMode(bool enable);

    /** Check if A/B mode is enabled */
    bool isABModeEnabled() const { return abModeEnabled; }

    /** Copy current state to A */
    void copyToA();

    /** Copy current state to B */
    void copyToB();

    /** Switch between A and B */
    void toggleAB();

    /** Get current slot (A or B) */
    bool isSlotA() const { return currentSlot == 'A'; }

    //==========================================================================
    // Position & Size Persistence
    //==========================================================================

    /** Save window position to settings */
    void saveWindowState();

    /** Load window position from settings */
    void loadWindowState();

    /** Get unique identifier for this window */
    juce::String getWindowIdentifier() const;

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void()> onWindowClosed;
    std::function<void(bool bypassed)> onBypassChanged;
    std::function<void(const juce::String& presetName)> onPresetChanged;

    //==========================================================================
    // DocumentWindow Overrides
    //==========================================================================

    void closeButtonPressed() override;
    void moved() override;
    void resized() override;

private:
    //==========================================================================
    // Plugin Components
    //==========================================================================

    juce::AudioProcessor* plugin = nullptr;
    std::unique_ptr<juce::AudioProcessorEditor> editor;
    juce::String pluginName;

    //==========================================================================
    // Toolbar Component
    //==========================================================================

    class PluginToolbar : public juce::Component
    {
    public:
        PluginToolbar(PluginEditorWindow& owner);

        void paint(juce::Graphics& g) override;
        void resized() override;

        // Buttons
        std::unique_ptr<juce::TextButton> bypassButton;
        std::unique_ptr<juce::TextButton> presetButton;
        std::unique_ptr<juce::TextButton> aButton;
        std::unique_ptr<juce::TextButton> bButton;
        std::unique_ptr<juce::TextButton> compareButton;

        // Labels
        std::unique_ptr<juce::Label> presetLabel;
        std::unique_ptr<juce::Label> cpuLabel;

    private:
        PluginEditorWindow& window;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PluginToolbar)
    };

    std::unique_ptr<PluginToolbar> toolbar;

    //==========================================================================
    // Window State
    //==========================================================================

    bool showToolbar = true;
    bool alwaysOnTop = false;
    bool bypassed = false;

    juce::Rectangle<int> savedBounds;

    //==========================================================================
    // Preset State
    //==========================================================================

    juce::String currentPresetName = "Default";
    juce::File currentPresetFile;

    //==========================================================================
    // A/B Comparison State
    //==========================================================================

    bool abModeEnabled = false;
    char currentSlot = 'A';  // 'A' or 'B'

    juce::MemoryBlock stateA;
    juce::MemoryBlock stateB;

    //==========================================================================
    // Helper Methods
    //==========================================================================

    /** Create and attach editor */
    void createEditor();

    /** Update toolbar state */
    void updateToolbar();

    /** Calculate optimal window size */
    juce::Rectangle<int> calculateOptimalBounds() const;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PluginEditorWindow)
};

/**
 * PluginWindowManager - Manages multiple plugin windows
 *
 * Keeps track of all open plugin windows and ensures proper cleanup.
 */
class PluginWindowManager
{
public:
    //==========================================================================
    // Singleton Access
    //==========================================================================

    static PluginWindowManager& getInstance()
    {
        static PluginWindowManager instance;
        return instance;
    }

    //==========================================================================
    // Window Management
    //==========================================================================

    /** Open or bring to front plugin editor window */
    PluginEditorWindow* openPluginWindow(juce::AudioProcessor* plugin,
                                         const juce::String& pluginName);

    /** Close plugin window */
    void closePluginWindow(juce::AudioProcessor* plugin);

    /** Close all plugin windows */
    void closeAllWindows();

    /** Get window for plugin (if open) */
    PluginEditorWindow* getWindowForPlugin(juce::AudioProcessor* plugin);

    /** Check if plugin has open window */
    bool hasWindowForPlugin(juce::AudioProcessor* plugin) const;

    /** Get all open windows */
    juce::Array<PluginEditorWindow*> getAllWindows() const;

    /** Get number of open windows */
    int getNumOpenWindows() const { return windows.size(); }

private:
    //==========================================================================
    // Constructor (private for singleton)
    //==========================================================================

    PluginWindowManager() = default;
    ~PluginWindowManager();

    //==========================================================================
    // Window Storage
    //==========================================================================

    juce::OwnedArray<PluginEditorWindow> windows;

    //==========================================================================
    // Helper Methods
    //==========================================================================

    int findWindowIndex(juce::AudioProcessor* plugin) const;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PluginWindowManager)
};
