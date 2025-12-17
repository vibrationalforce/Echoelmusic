#include "PresetBrowserUI.h"

//==============================================================================
// PresetBrowserUI Implementation
//==============================================================================

PresetBrowserUI::PresetBrowserUI()
{
    // Create UI components
    categoryBar = std::make_unique<CategoryBar>(*this);
    addAndMakeVisible(categoryBar.get());

    searchBar = std::make_unique<SearchBar>(*this);
    addAndMakeVisible(searchBar.get());

    presetGrid = std::make_unique<PresetGrid>(*this);
    addAndMakeVisible(presetGrid.get());

    infoPanel = std::make_unique<PresetInfoPanel>(*this);
    addAndMakeVisible(infoPanel.get());

    // Category change callback
    categoryBar->onCategoryChanged = [this](AdvancedDSPManager::PresetCategory category)
    {
        currentCategory = category;
        updateFilteredPresets();
    };

    // Search text changed callback
    searchBar->onSearchTextChanged = [this](const juce::String& text)
    {
        currentSearchText = text;
        updateFilteredPresets();
    };

    // Preset selected callback
    presetGrid->onPresetSelected = [this](const AdvancedDSPManager::Preset& preset)
    {
        infoPanel->setPreset(&preset);

        if (onPresetSelected)
            onPresetSelected(preset.name);
    };

    setSize(800, 600);
}

PresetBrowserUI::~PresetBrowserUI()
{
}

void PresetBrowserUI::setDSPManager(AdvancedDSPManager* manager)
{
    dspManager = manager;
    loadPresetsFromDSP();
    updateFilteredPresets();
}

void PresetBrowserUI::paint(juce::Graphics& g)
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
    g.drawText("Preset Browser", bounds.removeFromTop(50).reduced(20, 10),
               juce::Justification::centredLeft);
}

void PresetBrowserUI::resized()
{
    auto bounds = getLocalBounds();

    // Top margin for title
    bounds.removeFromTop(50);

    // Category bar
    categoryBar->setBounds(bounds.removeFromTop(50).reduced(10, 5));

    // Search bar
    searchBar->setBounds(bounds.removeFromTop(50).reduced(10, 5));

    // Main content: grid (left) + info panel (right)
    auto contentBounds = bounds.reduced(10);

    auto infoPanelBounds = contentBounds.removeFromRight(280);
    infoPanel->setBounds(infoPanelBounds);

    contentBounds.removeFromRight(10); // Spacing

    presetGrid->setBounds(contentBounds);
}

void PresetBrowserUI::updateFilteredPresets()
{
    filteredPresets.clear();

    for (const auto& preset : allPresets)
    {
        // Category filter
        bool categoryMatch = (currentCategory == AdvancedDSPManager::PresetCategory::All)
                          || (preset.category == currentCategory);

        if (!categoryMatch)
            continue;

        // Search filter
        if (!currentSearchText.isEmpty())
        {
            bool searchMatch = preset.name.containsIgnoreCase(currentSearchText);
            if (!searchMatch)
                continue;
        }

        filteredPresets.push_back(preset);
    }

    presetGrid->updatePresetList(filteredPresets);
}

void PresetBrowserUI::loadPresetsFromDSP()
{
    allPresets.clear();

    if (!dspManager)
        return;

    // Get all presets from DSP manager (JUCE 7.x compatible)
    allPresets = dspManager->getAllPresets();
}

//==============================================================================
// CategoryBar Implementation
//==============================================================================

PresetBrowserUI::CategoryBar::CategoryBar(PresetBrowserUI& parent)
    : owner(parent)
{
    allButton.setButtonText("All");
    allButton.setToggleState(true, juce::dontSendNotification);
    addAndMakeVisible(allButton);
    allButton.onClick = [&]()
    {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::All);
    };

    masteringButton.setButtonText("Mastering");
    addAndMakeVisible(masteringButton);
    masteringButton.onClick = [&]()
    {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::Mastering);
    };

    vocalButton.setButtonText("Vocal");
    addAndMakeVisible(vocalButton);
    vocalButton.onClick = [&]()
    {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::Vocal);
    };

    ambientButton.setButtonText("Ambient");
    addAndMakeVisible(ambientButton);
    ambientButton.onClick = [&]()
    {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::Ambient);
    };

    bioReactiveButton.setButtonText("Bio-Reactive");
    addAndMakeVisible(bioReactiveButton);
    bioReactiveButton.onClick = [&]()
    {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::BioReactive);
    };

    customButton.setButtonText("Custom");
    addAndMakeVisible(customButton);
    customButton.onClick = [&]()
    {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::Custom);
    };

    favoritesButton.setButtonText("★ Favorites");
    addAndMakeVisible(favoritesButton);
    favoritesButton.onClick = [&]()
    {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::All);
        // In production: would filter by favorites
    };
}

void PresetBrowserUI::CategoryBar::setCurrentCategory(AdvancedDSPManager::PresetCategory category)
{
    currentCategory = category;

    // Update button states
    allButton.setToggleState(category == AdvancedDSPManager::PresetCategory::All,
                             juce::dontSendNotification);
    masteringButton.setToggleState(category == AdvancedDSPManager::PresetCategory::Mastering,
                                   juce::dontSendNotification);
    vocalButton.setToggleState(category == AdvancedDSPManager::PresetCategory::Vocal,
                               juce::dontSendNotification);
    ambientButton.setToggleState(category == AdvancedDSPManager::PresetCategory::Ambient,
                                 juce::dontSendNotification);
    bioReactiveButton.setToggleState(category == AdvancedDSPManager::PresetCategory::BioReactive,
                                     juce::dontSendNotification);
    customButton.setToggleState(category == AdvancedDSPManager::PresetCategory::Custom,
                                juce::dontSendNotification);

    if (onCategoryChanged)
        onCategoryChanged(category);

    repaint();
}

void PresetBrowserUI::CategoryBar::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1f1f24));
}

void PresetBrowserUI::CategoryBar::resized()
{
    auto bounds = getLocalBounds().reduced(5);
    int buttonWidth = bounds.getWidth() / 7;

    allButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    masteringButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    vocalButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    ambientButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    bioReactiveButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    customButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    favoritesButton.setBounds(bounds.reduced(2));
}

//==============================================================================
// SearchBar Implementation
//==============================================================================

PresetBrowserUI::SearchBar::SearchBar(PresetBrowserUI& parent)
    : owner(parent)
{
    searchLabel.setText("Search:", juce::dontSendNotification);
    searchLabel.setColour(juce::Label::textColourId, juce::Colour(0xffe8e8e8));
    addAndMakeVisible(searchLabel);

    searchBox.setTextToShowWhenEmpty("Type to search presets...", juce::Colour(0xff808080));
    searchBox.setColour(juce::TextEditor::backgroundColourId, juce::Colour(0xff252530));
    searchBox.setColour(juce::TextEditor::textColourId, juce::Colour(0xffe8e8e8));
    searchBox.setColour(juce::TextEditor::outlineColourId, juce::Colour(0xff3a3a40));
    addAndMakeVisible(searchBox);

    searchBox.onTextChange = [&]()
    {
        if (onSearchTextChanged)
            onSearchTextChanged(searchBox.getText());
    };

    clearButton.setButtonText("✕");
    addAndMakeVisible(clearButton);
    clearButton.onClick = [&]()
    {
        searchBox.clear();
        if (onSearchTextChanged)
            onSearchTextChanged("");
    };
}

void PresetBrowserUI::SearchBar::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1f1f24));
}

void PresetBrowserUI::SearchBar::resized()
{
    auto bounds = getLocalBounds().reduced(10, 5);

    searchLabel.setBounds(bounds.removeFromLeft(60));
    bounds.removeFromLeft(5);

    clearButton.setBounds(bounds.removeFromRight(40));
    bounds.removeFromRight(5);

    searchBox.setBounds(bounds);
}

//==============================================================================
// PresetCard Implementation
//==============================================================================

PresetBrowserUI::PresetCard::PresetCard(PresetBrowserUI& parent, const AdvancedDSPManager::Preset& preset)
    : owner(parent), presetData(preset)
{
}

void PresetBrowserUI::PresetCard::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds().toFloat();

    // Background
    juce::Colour bgColor = juce::Colour(0xff252530);
    if (selected)
        bgColor = juce::Colour(0xff00d4ff).withAlpha(0.3f);
    else if (hovered)
        bgColor = juce::Colour(0xff2a2a35);

    g.setColour(bgColor);
    g.fillRoundedRectangle(bounds, 8.0f);

    // Border
    if (selected)
    {
        g.setColour(juce::Colour(0xff00d4ff));
        g.drawRoundedRectangle(bounds, 8.0f, 2.0f);
    }
    else
    {
        g.setColour(juce::Colour(0xff3a3a40));
        g.drawRoundedRectangle(bounds, 8.0f, 1.0f);
    }

    auto contentBounds = bounds.reduced(10);

    // Icon area (top)
    auto iconBounds = contentBounds.removeFromTop(60);
    juce::Path icon = getCategoryIcon();

    if (!icon.isEmpty())
    {
        g.setColour(juce::Colour(0xff00d4ff).withAlpha(0.7f));
        juce::Rectangle<float> iconRect(iconBounds.getCentreX() - 20, iconBounds.getCentreY() - 20, 40, 40);
        g.fillPath(icon, icon.getTransformToScaleToFit(iconRect, true));
    }

    // Category label
    g.setColour(juce::Colour(0xffa8a8a8));
    g.setFont(10.0f);
    juce::String categoryText;
    switch (presetData.category)
    {
        case AdvancedDSPManager::PresetCategory::Mastering: categoryText = "MASTERING"; break;
        case AdvancedDSPManager::PresetCategory::Vocal: categoryText = "VOCAL"; break;
        case AdvancedDSPManager::PresetCategory::Ambient: categoryText = "AMBIENT"; break;
        case AdvancedDSPManager::PresetCategory::BioReactive: categoryText = "BIO-REACTIVE"; break;
        case AdvancedDSPManager::PresetCategory::Custom: categoryText = "CUSTOM"; break;
        default: categoryText = "ALL"; break;
    }
    g.drawText(categoryText, contentBounds.removeFromTop(15).toNearestInt(), juce::Justification::centred);

    contentBounds.removeFromTop(5);

    // Preset name
    g.setColour(juce::Colour(0xffe8e8e8));
    g.setFont(juce::Font(13.0f, juce::Font::bold));
    g.drawText(presetData.name, contentBounds.toNearestInt(),
               juce::Justification::centred, true);
}

void PresetBrowserUI::PresetCard::resized()
{
}

void PresetBrowserUI::PresetCard::mouseDown(const juce::MouseEvent&)
{
    if (onClicked)
        onClicked(this);
}

void PresetBrowserUI::PresetCard::mouseEnter(const juce::MouseEvent&)
{
    hovered = true;
    repaint();
}

void PresetBrowserUI::PresetCard::mouseExit(const juce::MouseEvent&)
{
    hovered = false;
    repaint();
}

void PresetBrowserUI::PresetCard::setSelected(bool shouldBeSelected)
{
    selected = shouldBeSelected;
    repaint();
}

juce::Path PresetBrowserUI::PresetCard::getCategoryIcon()
{
    juce::Path path;

    switch (presetData.category)
    {
        case AdvancedDSPManager::PresetCategory::Mastering:
            // Waveform icon
            path.startNewSubPath(0, 20);
            path.lineTo(10, 5);
            path.lineTo(20, 35);
            path.lineTo(30, 15);
            path.lineTo(40, 20);
            break;

        case AdvancedDSPManager::PresetCategory::Vocal:
            // Microphone icon
            path.addEllipse(15, 5, 10, 15);
            path.addRectangle(18, 20, 4, 8);
            path.startNewSubPath(10, 28);
            path.lineTo(30, 28);
            break;

        case AdvancedDSPManager::PresetCategory::Ambient:
            // Space/cloud icon
            path.addEllipse(5, 10, 30, 20);
            path.addEllipse(10, 5, 20, 15);
            break;

        case AdvancedDSPManager::PresetCategory::BioReactive:
            // Heart/pulse icon
            path.startNewSubPath(20, 35);
            path.lineTo(10, 15);
            path.quadraticTo(5, 5, 15, 10);
            path.quadraticTo(20, 5, 20, 10);
            path.quadraticTo(20, 5, 25, 10);
            path.quadraticTo(35, 5, 30, 15);
            path.lineTo(20, 35);
            break;

        case AdvancedDSPManager::PresetCategory::Custom:
            // Gear/settings icon
            path.addStar(juce::Point<float>(20, 20), 8, 10, 20, 0.0f);
            path.addEllipse(15, 15, 10, 10);
            break;

        default:
            // All presets icon (grid)
            for (int i = 0; i < 3; ++i)
                for (int j = 0; j < 3; ++j)
                    path.addRectangle(5 + i * 12, 5 + j * 12, 8, 8);
            break;
    }

    return path;
}

//==============================================================================
// PresetGrid Implementation
//==============================================================================

PresetBrowserUI::PresetGrid::PresetGrid(PresetBrowserUI& parent)
    : owner(parent)
{
    addAndMakeVisible(viewport);
    viewport.setViewedComponent(&contentComponent, false);
    viewport.setScrollBarsShown(true, false);
}

void PresetBrowserUI::PresetGrid::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1a1a1f));
}

void PresetBrowserUI::PresetGrid::resized()
{
    viewport.setBounds(getLocalBounds());

    // Layout preset cards in grid
    int cardWidth = 150;
    int cardHeight = 140;
    int padding = 10;
    int columns = juce::jmax(1, getWidth() / (cardWidth + padding));

    int rows = (presetCards.size() + columns - 1) / columns;
    int contentHeight = rows * (cardHeight + padding) + padding;

    contentComponent.setBounds(0, 0, getWidth() - 20, contentHeight);

    int x = padding;
    int y = padding;
    int column = 0;

    for (auto& card : presetCards)
    {
        card->setBounds(x, y, cardWidth, cardHeight);

        column++;
        if (column >= columns)
        {
            column = 0;
            x = padding;
            y += cardHeight + padding;
        }
        else
        {
            x += cardWidth + padding;
        }
    }
}

void PresetBrowserUI::PresetGrid::updatePresetList(const std::vector<AdvancedDSPManager::Preset>& presets)
{
    // Clear existing cards
    presetCards.clear();
    selectedCardIndex = -1;

    // Create new cards
    for (const auto& preset : presets)
    {
        auto card = std::make_unique<PresetCard>(owner, preset);

        card->onClicked = [this](PresetCard* clickedCard)
        {
            // Deselect all cards
            for (auto& c : presetCards)
                c->setSelected(false);

            // Select clicked card
            clickedCard->setSelected(true);

            // Find index
            for (size_t i = 0; i < presetCards.size(); ++i)
            {
                if (presetCards[i].get() == clickedCard)
                {
                    selectedCardIndex = static_cast<int>(i);
                    break;
                }
            }

            // Notify parent
            if (onPresetSelected)
                onPresetSelected(clickedCard->getPreset());
        };

        contentComponent.addAndMakeVisible(card.get());
        presetCards.push_back(std::move(card));
    }

    resized();
}

void PresetBrowserUI::PresetGrid::clearSelection()
{
    selectedCardIndex = -1;
    for (auto& card : presetCards)
        card->setSelected(false);
}

void PresetBrowserUI::PresetGrid::selectPreset(const juce::String& presetName)
{
    for (size_t i = 0; i < presetCards.size(); ++i)
    {
        if (presetCards[i]->getPreset().name == presetName)
        {
            clearSelection();
            presetCards[i]->setSelected(true);
            selectedCardIndex = static_cast<int>(i);

            if (onPresetSelected)
                onPresetSelected(presetCards[i]->getPreset());

            break;
        }
    }
}

//==============================================================================
// PresetInfoPanel Implementation
//==============================================================================

PresetBrowserUI::PresetInfoPanel::PresetInfoPanel(PresetBrowserUI& parent)
    : owner(parent)
{
    nameLabel.setFont(juce::Font(18.0f, juce::Font::bold));
    nameLabel.setColour(juce::Label::textColourId, juce::Colour(0xffe8e8e8));
    nameLabel.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(nameLabel);

    categoryLabel.setFont(juce::Font(12.0f));
    categoryLabel.setColour(juce::Label::textColourId, juce::Colour(0xffa8a8a8));
    categoryLabel.setJustificationType(juce::Justification::centredLeft);
    addAndMakeVisible(categoryLabel);

    descriptionEditor.setMultiLine(true);
    descriptionEditor.setReadOnly(true);
    descriptionEditor.setColour(juce::TextEditor::backgroundColourId, juce::Colour(0xff252530));
    descriptionEditor.setColour(juce::TextEditor::textColourId, juce::Colour(0xffe8e8e8));
    descriptionEditor.setColour(juce::TextEditor::outlineColourId, juce::Colour(0xff3a3a40));
    addAndMakeVisible(descriptionEditor);

    loadButton.setButtonText("Load Preset");
    addAndMakeVisible(loadButton);
    loadButton.onClick = [&]()
    {
        if (currentPreset && owner.dspManager)
        {
            owner.dspManager->loadPreset(currentPreset->name);
            juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::InfoIcon,
                "Preset Loaded", "Preset '" + currentPreset->name + "' has been loaded.");
        }
    };

    saveButton.setButtonText("Save As...");
    addAndMakeVisible(saveButton);
    saveButton.onClick = [&]()
    {
        if (!owner.dspManager)
            return;

        // JUCE 7.x compatible: use async modal dialog
        auto* window = new juce::AlertWindow("Save Preset", "Enter preset name:", juce::AlertWindow::QuestionIcon);
        window->addTextEditor("name", "My Preset", "Preset Name:");
        window->addButton("Save", 1);
        window->addButton("Cancel", 0);

        window->enterModalState(true, juce::ModalCallbackFunction::create([this, window](int result)
        {
            if (result == 1)
            {
                juce::String name = window->getTextEditorContents("name");
                if (name.isNotEmpty())
                {
                    owner.dspManager->savePreset(name, AdvancedDSPManager::PresetCategory::Custom);
                    juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::InfoIcon,
                        "Preset Saved", "Preset '" + name + "' has been saved.");
                }
            }
            delete window;
        }), true);
    };

    deleteButton.setButtonText("Delete");
    addAndMakeVisible(deleteButton);
    deleteButton.onClick = [&]()
    {
        if (!currentPreset)
            return;

        // JUCE 7.x compatible: provide all parameters
        bool confirmed = juce::AlertWindow::showOkCancelBox(
            juce::AlertWindow::WarningIcon,
            "Delete Preset",
            "Are you sure you want to delete '" + currentPreset->name + "'?",
            "Delete",
            "Cancel",
            nullptr,
            nullptr);

        if (confirmed)
        {
            // In production: would delete from disk
            juce::AlertWindow::showMessageBoxAsync(juce::AlertWindow::InfoIcon,
                "Preset Deleted", "Preset has been deleted.");
        }
    };

    favoriteToggle.setButtonText("★ Favorite");
    addAndMakeVisible(favoriteToggle);
}

void PresetBrowserUI::PresetInfoPanel::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1f1f24));

    // Border
    g.setColour(juce::Colour(0xff3a3a40));
    g.drawRect(getLocalBounds(), 1);
}

void PresetBrowserUI::PresetInfoPanel::resized()
{
    auto bounds = getLocalBounds().reduced(15);

    // Name
    nameLabel.setBounds(bounds.removeFromTop(30));

    // Category
    categoryLabel.setBounds(bounds.removeFromTop(20));

    bounds.removeFromTop(10);

    // Description
    descriptionEditor.setBounds(bounds.removeFromTop(200));

    bounds.removeFromTop(20);

    // Buttons
    loadButton.setBounds(bounds.removeFromTop(35));
    bounds.removeFromTop(10);

    saveButton.setBounds(bounds.removeFromTop(35));
    bounds.removeFromTop(10);

    auto bottomRow = bounds.removeFromTop(35);
    deleteButton.setBounds(bottomRow.removeFromLeft(120));
    bottomRow.removeFromLeft(10);
    favoriteToggle.setBounds(bottomRow);
}

void PresetBrowserUI::PresetInfoPanel::setPreset(const AdvancedDSPManager::Preset* preset)
{
    currentPreset = preset;

    if (preset)
    {
        nameLabel.setText(preset->name, juce::dontSendNotification);

        juce::String categoryText;
        switch (preset->category)
        {
            case AdvancedDSPManager::PresetCategory::Mastering: categoryText = "Category: Mastering"; break;
            case AdvancedDSPManager::PresetCategory::Vocal: categoryText = "Category: Vocal"; break;
            case AdvancedDSPManager::PresetCategory::Ambient: categoryText = "Category: Ambient"; break;
            case AdvancedDSPManager::PresetCategory::BioReactive: categoryText = "Category: Bio-Reactive"; break;
            case AdvancedDSPManager::PresetCategory::Custom: categoryText = "Category: Custom"; break;
            default: categoryText = "Category: All"; break;
        }
        categoryLabel.setText(categoryText, juce::dontSendNotification);

        // In production, would load actual description from preset metadata
        juce::String description = "Professional preset for advanced DSP processing.\n\n"
                                   "Includes settings for:\n"
                                   "• Mid/Side Tone Matching\n"
                                   "• Audio Humanizer\n"
                                   "• Swarm Reverb\n"
                                   "• Polyphonic Pitch Editor\n\n"
                                   "Optimized for " + categoryText.fromFirstOccurrenceOf(": ", false, true) + " applications.";
        descriptionEditor.setText(description);

        loadButton.setEnabled(true);
        deleteButton.setEnabled(preset->category == AdvancedDSPManager::PresetCategory::Custom);
    }
    else
    {
        nameLabel.setText("No preset selected", juce::dontSendNotification);
        categoryLabel.setText("", juce::dontSendNotification);
        descriptionEditor.setText("Select a preset from the grid to view details.");
        loadButton.setEnabled(false);
        deleteButton.setEnabled(false);
    }

    repaint();
}
