#pragma once

#include <JuceHeader.h>
#include "ResponsiveLayout.h"
#include "UIComponents.h"
#include "../DSP/AdvancedDSPManager.h"

//==============================================================================
/**
 * @brief Visual Preset Browser for Advanced DSP Manager
 *
 * Professional preset management with visual categories and preview.
 *
 * Features:
 * - Category filtering (Mastering, Vocal, Ambient, Bio-Reactive, Custom)
 * - Grid view with preset thumbnails/icons
 * - Search/filter functionality
 * - Preset metadata display (author, description, tags)
 * - Save/Load custom presets
 * - Favorites system
 * - A/B preset comparison
 * - Factory presets + user presets
 */
class PresetBrowserUI : public ResponsiveComponent
{
public:
    //==========================================================================
    // Constructor / Destructor

    PresetBrowserUI();
    ~PresetBrowserUI() override;

    //==========================================================================
    // DSP Manager Connection

    void setDSPManager(AdvancedDSPManager* manager);
    AdvancedDSPManager* getDSPManager() const { return dspManager; }

    //==========================================================================
    // Preset Selection Callback

    std::function<void(const juce::String& presetName)> onPresetSelected;

    //==========================================================================
    // Component Methods

    void paint(juce::Graphics& g) override;
    void resized() override;

private:
    //==========================================================================
    // Category Bar

    class CategoryBar : public juce::Component
    {
    public:
        CategoryBar(PresetBrowserUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;

        void setCurrentCategory(AdvancedDSPManager::PresetCategory category);
        AdvancedDSPManager::PresetCategory getCurrentCategory() const { return currentCategory; }

        std::function<void(AdvancedDSPManager::PresetCategory)> onCategoryChanged;

    private:
        PresetBrowserUI& owner;
        AdvancedDSPManager::PresetCategory currentCategory = AdvancedDSPManager::PresetCategory::All;

        juce::TextButton allButton;
        juce::TextButton masteringButton;
        juce::TextButton vocalButton;
        juce::TextButton ambientButton;
        juce::TextButton bioReactiveButton;
        juce::TextButton customButton;
        juce::TextButton favoritesButton;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CategoryBar)
    };

    //==========================================================================
    // Search Bar

    class SearchBar : public juce::Component
    {
    public:
        SearchBar(PresetBrowserUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;

        juce::String getSearchText() const { return searchBox.getText(); }

        std::function<void(const juce::String&)> onSearchTextChanged;

    private:
        PresetBrowserUI& owner;

        juce::TextEditor searchBox;
        juce::TextButton clearButton;
        juce::Label searchLabel;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SearchBar)
    };

    //==========================================================================
    // Preset Card (Grid Item)

    class PresetCard : public juce::Component
    {
    public:
        PresetCard(PresetBrowserUI& parent, const AdvancedDSPManager::Preset& preset);
        void paint(juce::Graphics& g) override;
        void resized() override;
        void mouseDown(const juce::MouseEvent& event) override;
        void mouseEnter(const juce::MouseEvent& event) override;
        void mouseExit(const juce::MouseEvent& event) override;

        const AdvancedDSPManager::Preset& getPreset() const { return presetData; }
        bool isSelected() const { return selected; }
        void setSelected(bool shouldBeSelected);

        std::function<void(PresetCard*)> onClicked;

    private:
        PresetBrowserUI& owner;
        AdvancedDSPManager::Preset presetData;

        bool selected = false;
        bool hovered = false;

        // Icons for categories
        juce::Path getCategoryIcon();

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PresetCard)
    };

    //==========================================================================
    // Preset Grid (Scrollable)

    class PresetGrid : public juce::Component
    {
    public:
        PresetGrid(PresetBrowserUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;

        void updatePresetList(const std::vector<AdvancedDSPManager::Preset>& presets);
        void clearSelection();
        void selectPreset(const juce::String& presetName);

        std::function<void(const AdvancedDSPManager::Preset&)> onPresetSelected;

    private:
        PresetBrowserUI& owner;

        std::vector<std::unique_ptr<PresetCard>> presetCards;
        juce::Viewport viewport;
        juce::Component contentComponent;

        int selectedCardIndex = -1;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PresetGrid)
    };

    //==========================================================================
    // Preset Info Panel

    class PresetInfoPanel : public juce::Component
    {
    public:
        PresetInfoPanel(PresetBrowserUI& parent);
        void paint(juce::Graphics& g) override;
        void resized() override;

        void setPreset(const AdvancedDSPManager::Preset* preset);

    private:
        PresetBrowserUI& owner;

        const AdvancedDSPManager::Preset* currentPreset = nullptr;

        juce::Label nameLabel;
        juce::Label categoryLabel;
        juce::TextEditor descriptionEditor;

        juce::TextButton loadButton;
        juce::TextButton saveButton;
        juce::TextButton deleteButton;
        juce::ToggleButton favoriteToggle;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PresetInfoPanel)
    };

    //==========================================================================
    // Member Variables

    AdvancedDSPManager* dspManager = nullptr;

    // UI Components
    std::unique_ptr<CategoryBar> categoryBar;
    std::unique_ptr<SearchBar> searchBar;
    std::unique_ptr<PresetGrid> presetGrid;
    std::unique_ptr<PresetInfoPanel> infoPanel;

    // Current filter state
    AdvancedDSPManager::PresetCategory currentCategory = AdvancedDSPManager::PresetCategory::All;
    juce::String currentSearchText;

    // Preset data
    std::vector<AdvancedDSPManager::Preset> allPresets;
    std::vector<AdvancedDSPManager::Preset> filteredPresets;

    //==========================================================================
    // Helper Methods

    void updateFilteredPresets();
    void loadPresetsFromDSP();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PresetBrowserUI)
};
