#include "PluginEditorWindow.h"

//==============================================================================
// Constants
//==============================================================================

namespace PluginWindowConstants
{
    const int TOOLBAR_HEIGHT = 40;
    const int MIN_WINDOW_WIDTH = 400;
    const int MIN_WINDOW_HEIGHT = 300;
    const int DEFAULT_WINDOW_WIDTH = 800;
    const int DEFAULT_WINDOW_HEIGHT = 600;

    const juce::Colour TOOLBAR_BACKGROUND = juce::Colour(0xFF2C2C2C);
    const juce::Colour BYPASS_ACTIVE_COLOR = juce::Colour(0xFFFF9500);
}

//==============================================================================
// PluginToolbar Implementation
//==============================================================================

PluginEditorWindow::PluginToolbar::PluginToolbar(PluginEditorWindow& owner)
    : window(owner)
{
    // Bypass button
    bypassButton = std::make_unique<juce::TextButton>("Bypass");
    bypassButton->setClickingTogglesState(true);
    bypassButton->onClick = [this]()
    {
        window.setBypass(bypassButton->getToggleState());
    };
    addAndMakeVisible(bypassButton.get());

    // Preset button
    presetButton = std::make_unique<juce::TextButton>("Presets");
    presetButton->onClick = [this]()
    {
        window.openPresetBrowser();
    };
    addAndMakeVisible(presetButton.get());

    // A/B comparison buttons
    aButton = std::make_unique<juce::TextButton>("A");
    aButton->setClickingTogglesState(true);
    aButton->setRadioGroupId(1);
    aButton->setToggleState(true, juce::dontSendNotification);
    aButton->onClick = [this]()
    {
        if (window.isABModeEnabled())
            window.toggleAB();
    };
    addAndMakeVisible(aButton.get());

    bButton = std::make_unique<juce::TextButton>("B");
    bButton->setClickingTogglesState(true);
    bButton->setRadioGroupId(1);
    bButton->onClick = [this]()
    {
        if (window.isABModeEnabled())
            window.toggleAB();
    };
    addAndMakeVisible(bButton.get());

    compareButton = std::make_unique<juce::TextButton>("Compare");
    compareButton->setClickingTogglesState(true);
    compareButton->onClick = [this]()
    {
        window.enableABMode(compareButton->getToggleState());
    };
    addAndMakeVisible(compareButton.get());

    // Preset label
    presetLabel = std::make_unique<juce::Label>("Preset", "Default");
    presetLabel->setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(presetLabel.get());

    // CPU label
    cpuLabel = std::make_unique<juce::Label>("CPU", "CPU: 0%");
    cpuLabel->setJustificationType(juce::Justification::centredRight);
    addAndMakeVisible(cpuLabel.get());
}

void PluginEditorWindow::PluginToolbar::paint(juce::Graphics& g)
{
    g.fillAll(PluginWindowConstants::TOOLBAR_BACKGROUND);

    // Bottom border
    g.setColour(juce::Colours::black.withAlpha(0.5f));
    g.drawHorizontalLine(getHeight() - 1, 0.0f, static_cast<float>(getWidth()));
}

void PluginEditorWindow::PluginToolbar::resized()
{
    auto bounds = getLocalBounds().reduced(5);

    // Left side buttons
    bypassButton->setBounds(bounds.removeFromLeft(80));
    bounds.removeFromLeft(5);

    presetButton->setBounds(bounds.removeFromLeft(80));
    bounds.removeFromLeft(5);

    // Preset name
    presetLabel->setBounds(bounds.removeFromLeft(150));
    bounds.removeFromLeft(10);

    // Right side - CPU label
    cpuLabel->setBounds(bounds.removeFromRight(80));
    bounds.removeFromRight(10);

    // A/B comparison (right aligned)
    bButton->setBounds(bounds.removeFromRight(40));
    bounds.removeFromRight(5);
    aButton->setBounds(bounds.removeFromRight(40));
    bounds.removeFromRight(5);
    compareButton->setBounds(bounds.removeFromRight(80));
}

//==============================================================================
// PluginEditorWindow - Constructor / Destructor
//==============================================================================

PluginEditorWindow::PluginEditorWindow(juce::AudioProcessor* pluginInstance,
                                       const juce::String& name)
    : juce::DocumentWindow(name,
                           juce::Colours::darkgrey,
                           juce::DocumentWindow::allButtons),
      plugin(pluginInstance),
      pluginName(name)
{
    setUsingNativeTitleBar(true);
    setResizable(true, false);

    // Create toolbar
    if (showToolbar)
    {
        toolbar = std::make_unique<PluginToolbar>(*this);
        setContentNonOwned(toolbar.get(), false);
    }

    // Create plugin editor
    createEditor();

    // Load saved window state
    loadWindowState();

    // Set bounds
    if (savedBounds.isEmpty())
        centreWithSize(PluginWindowConstants::DEFAULT_WINDOW_WIDTH,
                      PluginWindowConstants::DEFAULT_WINDOW_HEIGHT);
    else
        setBounds(savedBounds);

    DBG("PluginEditorWindow: Created window for " << pluginName);
}

PluginEditorWindow::~PluginEditorWindow()
{
    saveWindowState();

    editor = nullptr;
    toolbar = nullptr;

    DBG("PluginEditorWindow: Destroyed window for " << pluginName);
}

//==============================================================================
// Plugin Management
//==============================================================================

void PluginEditorWindow::refreshEditor()
{
    // Recreate editor
    createEditor();

    if (editor != nullptr)
    {
        auto bounds = calculateOptimalBounds();
        setContentNonOwned(editor.get(), true);
        setBounds(bounds);
    }
}

bool PluginEditorWindow::hasEditor() const
{
    return plugin != nullptr && plugin->hasEditor();
}

//==============================================================================
// Window Controls
//==============================================================================

void PluginEditorWindow::showWindow()
{
    setVisible(true);
    toFront(true);
}

void PluginEditorWindow::hideWindow()
{
    setVisible(false);
}

void PluginEditorWindow::toggleVisibility()
{
    if (isVisible())
        hideWindow();
    else
        showWindow();
}

bool PluginEditorWindow::isWindowVisible() const
{
    return isVisible();
}

void PluginEditorWindow::setAlwaysOnTop(bool shouldBeOnTop)
{
    alwaysOnTop = shouldBeOnTop;
    setAlwaysOnTop(shouldBeOnTop);
}

//==============================================================================
// Toolbar Features
//==============================================================================

void PluginEditorWindow::setToolbarVisible(bool visible)
{
    showToolbar = visible;

    if (showToolbar && toolbar == nullptr)
    {
        toolbar = std::make_unique<PluginToolbar>(*this);
    }
    else if (!showToolbar && toolbar != nullptr)
    {
        toolbar = nullptr;
    }

    refreshEditor();
}

void PluginEditorWindow::setBypass(bool shouldBypass)
{
    bypassed = shouldBypass;

    // Update plugin bypass state
    if (plugin != nullptr)
    {
        plugin->suspendProcessing(bypassed);
    }

    // Update toolbar
    if (toolbar != nullptr && toolbar->bypassButton != nullptr)
    {
        toolbar->bypassButton->setToggleState(bypassed, juce::dontSendNotification);

        if (bypassed)
            toolbar->bypassButton->setColour(juce::TextButton::buttonOnColourId,
                                            PluginWindowConstants::BYPASS_ACTIVE_COLOR);
    }

    if (onBypassChanged)
        onBypassChanged(bypassed);

    DBG("PluginEditorWindow: Bypass " << (bypassed ? "ON" : "OFF"));
}

//==============================================================================
// Preset Management
//==============================================================================

void PluginEditorWindow::openPresetBrowser()
{
    juce::FileChooser chooser("Load Preset",
                              juce::File::getSpecialLocation(juce::File::userDocumentsDirectory),
                              "*.fxp;*.vstpreset");

    if (chooser.browseForFileToOpen())
    {
        loadPreset(chooser.getResult());
    }
}

void PluginEditorWindow::savePreset(const juce::String& presetName)
{
    if (plugin == nullptr)
        return;

    // Get plugin state
    juce::MemoryBlock state;
    plugin->getStateInformation(state);

    // Save to file
    juce::File presetFile = juce::File::getSpecialLocation(juce::File::userDocumentsDirectory)
                                .getChildFile("Echoelmusic")
                                .getChildFile("Presets")
                                .getChildFile(pluginName)
                                .getChildFile(presetName + ".preset");

    presetFile.getParentDirectory().createDirectory();

    if (presetFile.replaceWithData(state.getData(), state.getSize()))
    {
        currentPresetName = presetName;
        currentPresetFile = presetFile;

        if (toolbar != nullptr && toolbar->presetLabel != nullptr)
            toolbar->presetLabel->setText(presetName, juce::dontSendNotification);

        if (onPresetChanged)
            onPresetChanged(presetName);

        DBG("PluginEditorWindow: Saved preset '" << presetName << "'");
    }
}

void PluginEditorWindow::loadPreset(const juce::File& presetFile)
{
    if (plugin == nullptr || !presetFile.existsAsFile())
        return;

    // Load preset data
    juce::MemoryBlock state;
    presetFile.loadFileAsData(state);

    // Set plugin state
    plugin->setStateInformation(state.getData(), static_cast<int>(state.getSize()));

    currentPresetName = presetFile.getFileNameWithoutExtension();
    currentPresetFile = presetFile;

    if (toolbar != nullptr && toolbar->presetLabel != nullptr)
        toolbar->presetLabel->setText(currentPresetName, juce::dontSendNotification);

    if (onPresetChanged)
        onPresetChanged(currentPresetName);

    refreshEditor();

    DBG("PluginEditorWindow: Loaded preset '" << currentPresetName << "'");
}

//==============================================================================
// A/B Comparison
//==============================================================================

void PluginEditorWindow::enableABMode(bool enable)
{
    abModeEnabled = enable;

    if (abModeEnabled)
    {
        // Save current state to A
        copyToA();
    }

    // Update toolbar
    if (toolbar != nullptr)
    {
        toolbar->aButton->setEnabled(abModeEnabled);
        toolbar->bButton->setEnabled(abModeEnabled);
    }

    DBG("PluginEditorWindow: A/B mode " << (abModeEnabled ? "ON" : "OFF"));
}

void PluginEditorWindow::copyToA()
{
    if (plugin == nullptr)
        return;

    stateA.reset();
    plugin->getStateInformation(stateA);

    DBG("PluginEditorWindow: Copied to slot A");
}

void PluginEditorWindow::copyToB()
{
    if (plugin == nullptr)
        return;

    stateB.reset();
    plugin->getStateInformation(stateB);

    DBG("PluginEditorWindow: Copied to slot B");
}

void PluginEditorWindow::toggleAB()
{
    if (!abModeEnabled || plugin == nullptr)
        return;

    if (currentSlot == 'A')
    {
        // Save current to A, load B
        copyToA();

        if (stateB.getSize() > 0)
        {
            plugin->setStateInformation(stateB.getData(), static_cast<int>(stateB.getSize()));
            currentSlot = 'B';
        }
    }
    else
    {
        // Save current to B, load A
        copyToB();

        if (stateA.getSize() > 0)
        {
            plugin->setStateInformation(stateA.getData(), static_cast<int>(stateA.getSize()));
            currentSlot = 'A';
        }
    }

    // Update toolbar
    if (toolbar != nullptr)
    {
        toolbar->aButton->setToggleState(currentSlot == 'A', juce::dontSendNotification);
        toolbar->bButton->setToggleState(currentSlot == 'B', juce::dontSendNotification);
    }

    refreshEditor();

    DBG("PluginEditorWindow: Switched to slot " << currentSlot);
}

//==============================================================================
// Position & Size Persistence
//==============================================================================

void PluginEditorWindow::saveWindowState()
{
    auto identifier = getWindowIdentifier();

    // Save to user settings
    juce::PropertiesFile::Options options;
    options.applicationName = "Echoelmusic";
    options.filenameSuffix = ".settings";
    options.osxLibrarySubFolder = "Application Support";

    juce::PropertiesFile settings(options);

    auto bounds = getBounds();
    settings.setValue(identifier + "_x", bounds.getX());
    settings.setValue(identifier + "_y", bounds.getY());
    settings.setValue(identifier + "_width", bounds.getWidth());
    settings.setValue(identifier + "_height", bounds.getHeight());
    settings.setValue(identifier + "_alwaysOnTop", alwaysOnTop);

    settings.saveIfNeeded();
}

void PluginEditorWindow::loadWindowState()
{
    auto identifier = getWindowIdentifier();

    // Load from user settings
    juce::PropertiesFile::Options options;
    options.applicationName = "Echoelmusic";
    options.filenameSuffix = ".settings";
    options.osxLibrarySubFolder = "Application Support";

    juce::PropertiesFile settings(options);

    int x = settings.getIntValue(identifier + "_x", -1);
    int y = settings.getIntValue(identifier + "_y", -1);
    int width = settings.getIntValue(identifier + "_width", PluginWindowConstants::DEFAULT_WINDOW_WIDTH);
    int height = settings.getIntValue(identifier + "_height", PluginWindowConstants::DEFAULT_WINDOW_HEIGHT);

    if (x >= 0 && y >= 0)
        savedBounds = juce::Rectangle<int>(x, y, width, height);

    alwaysOnTop = settings.getBoolValue(identifier + "_alwaysOnTop", false);
}

juce::String PluginEditorWindow::getWindowIdentifier() const
{
    // Create unique identifier from plugin name
    return "PluginWindow_" + pluginName.replace(" ", "_");
}

//==============================================================================
// DocumentWindow Overrides
//==============================================================================

void PluginEditorWindow::closeButtonPressed()
{
    setVisible(false);

    if (onWindowClosed)
        onWindowClosed();
}

void PluginEditorWindow::moved()
{
    juce::DocumentWindow::moved();
    saveWindowState();
}

void PluginEditorWindow::resized()
{
    juce::DocumentWindow::resized();
    saveWindowState();
}

//==============================================================================
// Helper Methods
//==============================================================================

void PluginEditorWindow::createEditor()
{
    if (plugin == nullptr || !plugin->hasEditor())
    {
        DBG("PluginEditorWindow: Plugin has no editor");
        return;
    }

    // Create editor
    editor.reset(plugin->createEditorIfNeeded());

    if (editor != nullptr)
    {
        // Set content
        if (showToolbar && toolbar != nullptr)
        {
            // TODO: Add editor below toolbar
            setContentNonOwned(editor.get(), true);
        }
        else
        {
            setContentNonOwned(editor.get(), true);
        }

        DBG("PluginEditorWindow: Created editor (" << editor->getWidth() << "x" << editor->getHeight() << ")");
    }
}

void PluginEditorWindow::updateToolbar()
{
    if (toolbar == nullptr)
        return;

    // Update preset name
    if (toolbar->presetLabel != nullptr)
        toolbar->presetLabel->setText(currentPresetName, juce::dontSendNotification);

    // Update bypass state
    if (toolbar->bypassButton != nullptr)
        toolbar->bypassButton->setToggleState(bypassed, juce::dontSendNotification);

    // Update A/B state
    if (toolbar->compareButton != nullptr)
        toolbar->compareButton->setToggleState(abModeEnabled, juce::dontSendNotification);

    if (toolbar->aButton != nullptr)
        toolbar->aButton->setToggleState(currentSlot == 'A', juce::dontSendNotification);

    if (toolbar->bButton != nullptr)
        toolbar->bButton->setToggleState(currentSlot == 'B', juce::dontSendNotification);
}

juce::Rectangle<int> PluginEditorWindow::calculateOptimalBounds() const
{
    int width = PluginWindowConstants::DEFAULT_WINDOW_WIDTH;
    int height = PluginWindowConstants::DEFAULT_WINDOW_HEIGHT;

    if (editor != nullptr)
    {
        width = juce::jmax(editor->getWidth(), PluginWindowConstants::MIN_WINDOW_WIDTH);
        height = editor->getHeight();

        if (showToolbar)
            height += PluginWindowConstants::TOOLBAR_HEIGHT;

        height = juce::jmax(height, PluginWindowConstants::MIN_WINDOW_HEIGHT);
    }

    // Center on screen
    auto displayArea = juce::Desktop::getInstance().getDisplays().getPrimaryDisplay()->userArea;
    int x = displayArea.getCentreX() - width / 2;
    int y = displayArea.getCentreY() - height / 2;

    return juce::Rectangle<int>(x, y, width, height);
}

//==============================================================================
// PluginWindowManager - Destructor
//==============================================================================

PluginWindowManager::~PluginWindowManager()
{
    closeAllWindows();
}

//==============================================================================
// PluginWindowManager - Window Management
//==============================================================================

PluginEditorWindow* PluginWindowManager::openPluginWindow(juce::AudioProcessor* plugin,
                                                          const juce::String& pluginName)
{
    if (plugin == nullptr)
        return nullptr;

    // Check if window already exists
    int existingIndex = findWindowIndex(plugin);

    if (existingIndex >= 0)
    {
        // Bring existing window to front
        windows[existingIndex]->toFront(true);
        return windows[existingIndex];
    }

    // Create new window
    auto* window = new PluginEditorWindow(plugin, pluginName);

    window->onWindowClosed = [this, plugin]()
    {
        closePluginWindow(plugin);
    };

    windows.add(window);
    window->showWindow();

    DBG("PluginWindowManager: Opened window for " << pluginName << " (total: " << windows.size() << ")");

    return window;
}

void PluginWindowManager::closePluginWindow(juce::AudioProcessor* plugin)
{
    int index = findWindowIndex(plugin);

    if (index >= 0)
    {
        windows.remove(index);
        DBG("PluginWindowManager: Closed window (remaining: " << windows.size() << ")");
    }
}

void PluginWindowManager::closeAllWindows()
{
    windows.clear();
    DBG("PluginWindowManager: Closed all windows");
}

PluginEditorWindow* PluginWindowManager::getWindowForPlugin(juce::AudioProcessor* plugin)
{
    int index = findWindowIndex(plugin);
    return (index >= 0) ? windows[index] : nullptr;
}

bool PluginWindowManager::hasWindowForPlugin(juce::AudioProcessor* plugin) const
{
    return findWindowIndex(plugin) >= 0;
}

juce::Array<PluginEditorWindow*> PluginWindowManager::getAllWindows() const
{
    juce::Array<PluginEditorWindow*> result;

    for (auto* window : windows)
        result.add(window);

    return result;
}

//==============================================================================
// PluginWindowManager - Helper Methods
//==============================================================================

int PluginWindowManager::findWindowIndex(juce::AudioProcessor* plugin) const
{
    for (int i = 0; i < windows.size(); ++i)
    {
        if (windows[i]->getPluginInstance() == plugin)
            return i;
    }

    return -1;
}
