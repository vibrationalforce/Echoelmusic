#include "PresetBrowserUI.h"

// PresetBrowserUI - Main Implementation
PresetBrowserUI::PresetBrowserUI()
{
    categoryBar = std::make_unique<CategoryBar>(*this);
    addAndMakeVisible(*categoryBar);
    
    searchBar = std::make_unique<SearchBar>(*this);
    addAndMakeVisible(*searchBar);
    
    presetGrid = std::make_unique<PresetGrid>(*this);
    addAndMakeVisible(*presetGrid);
    
    presetInfoPanel = std::make_unique<PresetInfoPanel>(*this);
    addAndMakeVisible(*presetInfoPanel);
    
    saveButton.setButtonText("Save Preset");
    addAndMakeVisible(saveButton);
    
    loadButton.setButtonText("Load");
    addAndMakeVisible(loadButton);
    
    deleteButton.setButtonText("Delete");
    addAndMakeVisible(deleteButton);
    
    favoriteButton.setButtonText("★ Favorite");
    addAndMakeVisible(favoriteButton);
    
    categoryBar->onCategoryChanged = [this](AdvancedDSPManager::PresetCategory cat)
    {
        currentCategory = cat;
        updateFilteredPresets();
    };
    
    searchBar->onSearchTextChanged = [this](const juce::String& text)
    {
        searchText = text;
        updateFilteredPresets();
    };
    
    presetGrid->onPresetSelected = [this](const AdvancedDSPManager::Preset& preset)
    {
        currentPreset = preset;
        presetInfoPanel->setPreset(&currentPreset);
        if (onPresetSelected)
            onPresetSelected(preset.name);
    };
}

PresetBrowserUI::~PresetBrowserUI() = default;

void PresetBrowserUI::setDSPManager(AdvancedDSPManager* manager)
{
    dspManager = manager;
    if (dspManager)
        loadPresetsFromDSP();
}

void PresetBrowserUI::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1a1a1f));
}

void PresetBrowserUI::resized()
{
    auto bounds = getLocalBounds().reduced(10);
    
    if (categoryBar)
        categoryBar->setBounds(bounds.removeFromTop(50));
    
    if (searchBar)
        searchBar->setBounds(bounds.removeFromTop(40));
    
    auto bottomBar = bounds.removeFromBottom(50);
    int buttonWidth = bottomBar.getWidth() / 4;
    saveButton.setBounds(bottomBar.removeFromLeft(buttonWidth).reduced(5));
    loadButton.setBounds(bottomBar.removeFromLeft(buttonWidth).reduced(5));
    deleteButton.setBounds(bottomBar.removeFromLeft(buttonWidth).reduced(5));
    favoriteButton.setBounds(bottomBar.reduced(5));
    
    if (presetInfoPanel)
        presetInfoPanel->setBounds(bounds.removeFromRight(250));
    
    if (presetGrid)
        presetGrid->setBounds(bounds);
}

void PresetBrowserUI::updateFilteredPresets()
{
    if (!dspManager) return;
    
    filteredPresets = dspManager->getPresets(currentCategory);
    
    if (!searchText.isEmpty())
    {
        std::vector<AdvancedDSPManager::Preset> filtered;
        for (const auto& preset : filteredPresets)
        {
            if (preset.name.containsIgnoreCase(searchText))
                filtered.push_back(preset);
        }
        filteredPresets = filtered;
    }
    
    presetGrid->updatePresetList(filteredPresets);
}

void PresetBrowserUI::loadPresetsFromDSP()
{
    updateFilteredPresets();
}

// CategoryBar Implementation
PresetBrowserUI::CategoryBar::CategoryBar(PresetBrowserUI& parent) : owner(parent)
{
    allButton.setButtonText("All");
    allButton.setToggleState(true, juce::dontSendNotification);
    addAndMakeVisible(allButton);
    allButton.onClick = [this]() { 
        setCurrentCategory(AdvancedDSPManager::PresetCategory::All);
    };
    
    masteringButton.setButtonText("Mastering");
    addAndMakeVisible(masteringButton);
    masteringButton.onClick = [this]() {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::Mastering);
    };
    
    vocalButton.setButtonText("Vocal");
    addAndMakeVisible(vocalButton);
    vocalButton.onClick = [this]() {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::Vocal);
    };
    
    ambientButton.setButtonText("Ambient");
    addAndMakeVisible(ambientButton);
    ambientButton.onClick = [this]() {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::Ambient);
    };
    
    bioReactiveButton.setButtonText("Bio-Reactive");
    addAndMakeVisible(bioReactiveButton);
    bioReactiveButton.onClick = [this]() {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::BioReactive);
    };
    
    customButton.setButtonText("Custom");
    addAndMakeVisible(customButton);
    customButton.onClick = [this]() {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::User);
    };
    
    favoritesButton.setButtonText("★ Favorites");
    addAndMakeVisible(favoritesButton);
    favoritesButton.onClick = [this]() {
        setCurrentCategory(AdvancedDSPManager::PresetCategory::Favorites);
    };
}

void PresetBrowserUI::CategoryBar::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff252530));
}

void PresetBrowserUI::CategoryBar::resized()
{
    auto bounds = getLocalBounds().reduced(5);
    int numButtons = 7;
    int buttonWidth = bounds.getWidth() / numButtons;
    
    allButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    masteringButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    vocalButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    ambientButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    bioReactiveButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    customButton.setBounds(bounds.removeFromLeft(buttonWidth).reduced(2));
    favoritesButton.setBounds(bounds.reduced(2));
}

void PresetBrowserUI::CategoryBar::setCurrentCategory(AdvancedDSPManager::PresetCategory category)
{
    currentCategory = category;
    
    allButton.setToggleState(category == AdvancedDSPManager::PresetCategory::All, juce::dontSendNotification);
    masteringButton.setToggleState(category == AdvancedDSPManager::PresetCategory::Mastering, juce::dontSendNotification);
    vocalButton.setToggleState(category == AdvancedDSPManager::PresetCategory::Vocal, juce::dontSendNotification);
    ambientButton.setToggleState(category == AdvancedDSPManager::PresetCategory::Ambient, juce::dontSendNotification);
    bioReactiveButton.setToggleState(category == AdvancedDSPManager::PresetCategory::BioReactive, juce::dontSendNotification);
    customButton.setToggleState(category == AdvancedDSPManager::PresetCategory::User, juce::dontSendNotification);
    favoritesButton.setToggleState(category == AdvancedDSPManager::PresetCategory::Favorites, juce::dontSendNotification);
    
    if (onCategoryChanged)
        onCategoryChanged(category);
}

// SearchBar Implementation
PresetBrowserUI::SearchBar::SearchBar(PresetBrowserUI& parent) : owner(parent)
{
    searchLabel.setText("Search:", juce::dontSendNotification);
    addAndMakeVisible(searchLabel);
    
    searchBox.setTextToShowWhenEmpty("Type to search presets...", juce::Colour(0xff808080));
    addAndMakeVisible(searchBox);
    searchBox.onTextChange = [this]() {
        if (onSearchTextChanged)
            onSearchTextChanged(searchBox.getText());
    };
    
    clearButton.setButtonText("✕");
    addAndMakeVisible(clearButton);
    clearButton.onClick = [this]() {
        searchBox.clear();
    };
}

void PresetBrowserUI::SearchBar::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1f1f24));
}

void PresetBrowserUI::SearchBar::resized()
{
    auto bounds = getLocalBounds().reduced(5);
    
    searchLabel.setBounds(bounds.removeFromLeft(60));
    clearButton.setBounds(bounds.removeFromRight(40));
    searchBox.setBounds(bounds);
}

// PresetCard Implementation
PresetBrowserUI::PresetCard::PresetCard(PresetBrowserUI& parent, const AdvancedDSPManager::Preset& preset)
    : owner(parent), presetData(preset)
{
}

void PresetBrowserUI::PresetCard::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds().toFloat();
    
    // Background
    if (selected)
        g.setColour(juce::Colour(0xff00d4ff).withAlpha(0.3f));
    else if (hovered)
        g.setColour(juce::Colour(0xff35353f));
    else
        g.setColour(juce::Colour(0xff252530));
    
    g.fillRoundedRectangle(bounds, 8.0f);
    
    // Border
    if (selected)
        g.setColour(juce::Colour(0xff00d4ff));
    else
        g.setColour(juce::Colour(0xff454550));
    g.drawRoundedRectangle(bounds, 8.0f, 2.0f);
    
    // Preset name
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(14.0f, juce::Font::bold));
    auto nameBounds = bounds.reduced(10).removeFromTop(30);
    g.drawText(presetData.name, nameBounds.toNearestInt(), juce::Justification::centredTop);

    // Category
    g.setFont(11.0f);
    g.setColour(juce::Colour(0xffa8a8a8));
    auto categoryBounds = bounds.reduced(10).removeFromBottom(20);
    juce::String categoryText = "";
    switch (presetData.category)
    {
        case AdvancedDSPManager::PresetCategory::Mastering: categoryText = "Mastering"; break;
        case AdvancedDSPManager::PresetCategory::Vocal: categoryText = "Vocal"; break;
        case AdvancedDSPManager::PresetCategory::Ambient: categoryText = "Ambient"; break;
        case AdvancedDSPManager::PresetCategory::BioReactive: categoryText = "Bio"; break;
        case AdvancedDSPManager::PresetCategory::User: categoryText = "User"; break;
        case AdvancedDSPManager::PresetCategory::Favorites: categoryText = "★"; break;
        default: break;
    }
    g.drawText(categoryText, categoryBounds.toNearestInt(), juce::Justification::centredBottom);
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
    path.addEllipse(0, 0, 10, 10);
    return path;
}

// PresetGrid Implementation
PresetBrowserUI::PresetGrid::PresetGrid(PresetBrowserUI& parent) : owner(parent)
{
    viewport = std::make_unique<juce::Viewport>();
    addAndMakeVisible(*viewport);
    
    container = std::make_unique<juce::Component>();
    viewport->setViewedComponent(container.get(), false);
}

void PresetBrowserUI::PresetGrid::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff1a1a1f));
}

void PresetBrowserUI::PresetGrid::resized()
{
    viewport->setBounds(getLocalBounds());
    
    // Layout preset cards in grid
    const int cardWidth = 180;
    const int cardHeight = 120;
    const int spacing = 10;
    
    int numColumns = jmax(1, getWidth() / (cardWidth + spacing));
    int numRows = (presetCards.size() + numColumns - 1) / numColumns;
    
    container->setBounds(0, 0, getWidth(), numRows * (cardHeight + spacing));
    
    for (int i = 0; i < presetCards.size(); ++i)
    {
        int col = i % numColumns;
        int row = i / numColumns;
        
        int x = col * (cardWidth + spacing) + spacing;
        int y = row * (cardHeight + spacing) + spacing;
        
        presetCards[i]->setBounds(x, y, cardWidth, cardHeight);
    }
}

void PresetBrowserUI::PresetGrid::updatePresetList(const std::vector<AdvancedDSPManager::Preset>& presets)
{
    presetCards.clear();
    container->removeAllChildren();
    
    for (const auto& preset : presets)
    {
        auto* card = new PresetCard(owner, preset);
        card->onClicked = [this](PresetCard* clicked)
        {
            clearSelection();
            clicked->setSelected(true);
            if (onPresetSelected)
                onPresetSelected(clicked->getPreset());
        };
        
        container->addAndMakeVisible(card);
        presetCards.add(card);
    }
    
    resized();
}

void PresetBrowserUI::PresetGrid::clearSelection()
{
    for (auto* card : presetCards)
        card->setSelected(false);
}

void PresetBrowserUI::PresetGrid::selectPreset(const juce::String& presetName)
{
    clearSelection();
    for (auto* card : presetCards)
    {
        if (card->getPreset().name == presetName)
        {
            card->setSelected(true);
            break;
        }
    }
}

// PresetInfoPanel Implementation
PresetBrowserUI::PresetInfoPanel::PresetInfoPanel(PresetBrowserUI& parent) : owner(parent)
{
    nameLabel.setText("No preset selected", juce::dontSendNotification);
    nameLabel.setJustificationType(juce::Justification::centred);
    nameLabel.setFont(juce::Font(16.0f, juce::Font::bold));
    addAndMakeVisible(nameLabel);

    categoryLabel.setText("", juce::dontSendNotification);
    addAndMakeVisible(categoryLabel);

    descriptionEditor.setMultiLine(true);
    descriptionEditor.setReadOnly(true);
    addAndMakeVisible(descriptionEditor);

    loadButton.setButtonText("Load");
    addAndMakeVisible(loadButton);

    saveButton.setButtonText("Save");
    addAndMakeVisible(saveButton);

    deleteButton.setButtonText("Delete");
    addAndMakeVisible(deleteButton);

    favoriteToggle.setButtonText("Favorite");
    addAndMakeVisible(favoriteToggle);
}

void PresetBrowserUI::PresetInfoPanel::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff252530));
    
    g.setColour(juce::Colour(0xff454550));
    g.drawRect(getLocalBounds(), 1);
}

void PresetBrowserUI::PresetInfoPanel::resized()
{
    auto bounds = getLocalBounds().reduced(10);

    nameLabel.setBounds(bounds.removeFromTop(40));
    categoryLabel.setBounds(bounds.removeFromTop(30));
    bounds.removeFromTop(10);
    descriptionEditor.setBounds(bounds.removeFromTop(100));
    bounds.removeFromTop(10);

    // Buttons at bottom
    auto buttonRow = bounds.removeFromBottom(30);
    int buttonWidth = buttonRow.getWidth() / 4;
    loadButton.setBounds(buttonRow.removeFromLeft(buttonWidth).reduced(2));
    saveButton.setBounds(buttonRow.removeFromLeft(buttonWidth).reduced(2));
    deleteButton.setBounds(buttonRow.removeFromLeft(buttonWidth).reduced(2));
    favoriteToggle.setBounds(buttonRow.reduced(2));
}

void PresetBrowserUI::PresetInfoPanel::setPreset(const AdvancedDSPManager::Preset* preset)
{
    currentPreset = preset;

    if (preset == nullptr)
    {
        nameLabel.setText("No preset selected", juce::dontSendNotification);
        categoryLabel.setText("", juce::dontSendNotification);
        descriptionEditor.setText("", juce::dontSendNotification);
        return;
    }

    nameLabel.setText(preset->name, juce::dontSendNotification);

    // Display category
    juce::String categoryName = "Category: ";
    switch (preset->category)
    {
        case AdvancedDSPManager::PresetCategory::All: categoryName += "All"; break;
        case AdvancedDSPManager::PresetCategory::Mastering: categoryName += "Mastering"; break;
        case AdvancedDSPManager::PresetCategory::Vocal: categoryName += "Vocal"; break;
        case AdvancedDSPManager::PresetCategory::Ambient: categoryName += "Ambient"; break;
        case AdvancedDSPManager::PresetCategory::BioReactive: categoryName += "Bio-Reactive"; break;
        case AdvancedDSPManager::PresetCategory::User: categoryName += "User"; break;
        case AdvancedDSPManager::PresetCategory::Favorites: categoryName += "Favorites"; break;
        default: categoryName += "Unknown"; break;
    }
    categoryLabel.setText(categoryName, juce::dontSendNotification);

    // Display parameters
    juce::String descriptionText = "Parameters:\n";
    for (int i = 0; i < preset->parameters.size(); ++i)
    {
        descriptionText += preset->parameters.getAllKeys()[i] + ": " +
                          preset->parameters.getAllValues()[i] + "\n";
    }
    descriptionEditor.setText(descriptionText, juce::dontSendNotification);
}
