/*
  ==============================================================================

    AISuggestionsPanel.h
    AI-Powered Musical Suggestions

    Displays contextual suggestions from Ralph Wiggum AI systems.
    Supports keyboard navigation and accessibility.

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "../Core/RalphWiggumAPI.h"
#include <vector>
#include <memory>

namespace Echoelmusic {
namespace GUI {

//==============================================================================
// Suggestion Card
//==============================================================================

class SuggestionCard : public juce::Component
{
public:
    enum class Type { Melody, Chord, Rhythm, Arrangement, Effect };

    SuggestionCard(const juce::String& id,
                   const juce::String& title,
                   const juce::String& description,
                   Type type,
                   float confidence)
        : suggestionId(id), suggestionType(type), confidenceLevel(confidence)
    {
        setWantsKeyboardFocus(true);

        titleLabel.setText(title, juce::dontSendNotification);
        titleLabel.setFont(juce::Font(14.0f, juce::Font::bold));
        titleLabel.setColour(juce::Label::textColourId, juce::Colours::white);
        addAndMakeVisible(titleLabel);

        descLabel.setText(description, juce::dontSendNotification);
        descLabel.setFont(juce::Font(11.0f));
        descLabel.setColour(juce::Label::textColourId, juce::Colour(0xFFB8B8C8));
        addAndMakeVisible(descLabel);

        // Accept button
        acceptButton.setButtonText("Use");
        acceptButton.onClick = [this]() {
            if (onAccept) onAccept(suggestionId);
        };
        addAndMakeVisible(acceptButton);

        // Dismiss button
        dismissButton.setButtonText("X");
        dismissButton.onClick = [this]() {
            if (onDismiss) onDismiss(suggestionId);
        };
        addAndMakeVisible(dismissButton);

        // Accessibility
        setAccessible(true);
        setTitle(title);
        setDescription(description);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Card background
        juce::Colour bgColor = isSelected ? juce::Colour(0xFF3A3A4A) : juce::Colour(0xFF2A2A3A);
        if (isMouseOver())
            bgColor = bgColor.brighter(0.1f);

        g.setColour(bgColor);
        g.fillRoundedRectangle(bounds.reduced(2), 8.0f);

        // Type indicator stripe
        g.setColour(getTypeColor());
        g.fillRoundedRectangle(bounds.getX() + 2, bounds.getY() + 8,
                              4.0f, bounds.getHeight() - 16, 2.0f);

        // Confidence bar
        auto confBounds = bounds.removeFromBottom(4).reduced(10, 0);
        g.setColour(juce::Colour(0xFF1A1A24));
        g.fillRoundedRectangle(confBounds, 2.0f);

        g.setColour(getTypeColor());
        confBounds.setWidth(confBounds.getWidth() * confidenceLevel);
        g.fillRoundedRectangle(confBounds, 2.0f);

        // Focus ring
        if (hasKeyboardFocus(true))
        {
            g.setColour(juce::Colour(0xFF00D9FF));
            g.drawRoundedRectangle(getLocalBounds().toFloat().reduced(2), 8.0f, 2.0f);
        }
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(15, 10);

        // Buttons on right
        auto buttonArea = bounds.removeFromRight(60);
        dismissButton.setBounds(buttonArea.removeFromTop(20).reduced(0, 2));
        acceptButton.setBounds(buttonArea.removeFromBottom(24));

        // Content
        bounds.removeFromBottom(8);  // Space for confidence bar
        titleLabel.setBounds(bounds.removeFromTop(20));
        descLabel.setBounds(bounds);
    }

    void mouseDown(const juce::MouseEvent&) override
    {
        setSelected(true);
    }

    void mouseEnter(const juce::MouseEvent&) override { repaint(); }
    void mouseExit(const juce::MouseEvent&) override { repaint(); }

    bool keyPressed(const juce::KeyPress& key) override
    {
        if (key == juce::KeyPress::returnKey)
        {
            if (onAccept) onAccept(suggestionId);
            return true;
        }
        if (key == juce::KeyPress::deleteKey || key == juce::KeyPress::backspaceKey)
        {
            if (onDismiss) onDismiss(suggestionId);
            return true;
        }
        return false;
    }

    void setSelected(bool selected)
    {
        isSelected = selected;
        repaint();
    }

    bool getSelected() const { return isSelected; }
    juce::String getId() const { return suggestionId; }

    std::function<void(const juce::String&)> onAccept;
    std::function<void(const juce::String&)> onDismiss;

private:
    juce::Colour getTypeColor()
    {
        switch (suggestionType)
        {
            case Type::Melody:      return juce::Colour(0xFF00D9FF);
            case Type::Chord:       return juce::Colour(0xFFFF6B9D);
            case Type::Rhythm:      return juce::Colour(0xFFFBBF24);
            case Type::Arrangement: return juce::Colour(0xFF4ADE80);
            case Type::Effect:      return juce::Colour(0xFFA78BFA);
            default:                return juce::Colour(0xFF00D9FF);
        }
    }

    juce::String suggestionId;
    Type suggestionType;
    float confidenceLevel;
    bool isSelected = false;

    juce::Label titleLabel;
    juce::Label descLabel;
    juce::TextButton acceptButton;
    juce::TextButton dismissButton;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SuggestionCard)
};

//==============================================================================
// AI Suggestions Panel
//==============================================================================

class AISuggestionsPanel : public juce::Component,
                           public juce::Timer
{
public:
    AISuggestionsPanel()
    {
        // Title
        titleLabel.setText("AI SUGGESTIONS", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(11.0f, juce::Font::bold));
        titleLabel.setColour(juce::Label::textColourId, juce::Colour(0xFF6B6B7B));
        addAndMakeVisible(titleLabel);

        // Refresh button
        refreshButton.setButtonText("Refresh");
        refreshButton.onClick = [this]() { refreshSuggestions(); };
        addAndMakeVisible(refreshButton);

        // Generate melody button
        generateMelodyButton.setButtonText("Generate Melody");
        generateMelodyButton.onClick = [this]() { generateMelody(); };
        addAndMakeVisible(generateMelodyButton);

        // Generate chords button
        generateChordsButton.setButtonText("Generate Chords");
        generateChordsButton.onClick = [this]() { generateChords(); };
        addAndMakeVisible(generateChordsButton);

        // Style selector
        styleSelector.addItem("Pop", 1);
        styleSelector.addItem("Jazz", 2);
        styleSelector.addItem("Electronic", 3);
        styleSelector.addItem("Classical", 4);
        styleSelector.addItem("Hip Hop", 5);
        styleSelector.setSelectedId(1);
        styleSelector.onChange = [this]() {
            RalphWiggum::RalphWiggumAPI::getInstance().setGenre(
                styleSelector.getText());
        };
        addAndMakeVisible(styleSelector);

        // Scroll container for suggestions
        viewport.setViewedComponent(&suggestionsContainer, false);
        viewport.setScrollBarsShown(true, false);
        addAndMakeVisible(viewport);

        // Initial fetch
        startTimer(2000);  // Refresh every 2 seconds
        refreshSuggestions();
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xFF1A1A24));

        // Right border
        g.setColour(juce::Colour(0xFF2A2A3A));
        g.drawLine(static_cast<float>(getWidth()), 0,
                  static_cast<float>(getWidth()), static_cast<float>(getHeight()), 1.0f);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10);

        // Title
        titleLabel.setBounds(bounds.removeFromTop(20));
        bounds.removeFromTop(5);

        // Style selector
        styleSelector.setBounds(bounds.removeFromTop(28));
        bounds.removeFromTop(10);

        // Generate buttons
        auto buttonRow = bounds.removeFromTop(30);
        generateMelodyButton.setBounds(buttonRow.removeFromLeft(buttonRow.getWidth() / 2 - 5));
        buttonRow.removeFromLeft(10);
        generateChordsButton.setBounds(buttonRow);
        bounds.removeFromTop(10);

        // Refresh button
        refreshButton.setBounds(bounds.removeFromTop(28));
        bounds.removeFromTop(10);

        // Suggestions viewport
        viewport.setBounds(bounds);
        updateSuggestionsLayout();
    }

    void timerCallback() override
    {
        refreshSuggestions();
    }

    void refreshSuggestions()
    {
        auto& api = RalphWiggum::RalphWiggumAPI::getInstance();
        auto suggestions = api.getSuggestions(5);

        suggestionCards.clear();

        int cardIndex = 0;
        for (const auto& suggestion : suggestions)
        {
            auto card = std::make_unique<SuggestionCard>(
                suggestion.id,
                suggestion.title,
                suggestion.description,
                SuggestionCard::Type::Melody,  // Determine from suggestion
                suggestion.confidence
            );

            card->onAccept = [this](const juce::String& id) {
                acceptSuggestion(id);
            };

            card->onDismiss = [this](const juce::String& id) {
                dismissSuggestion(id);
            };

            suggestionsContainer.addAndMakeVisible(card.get());
            suggestionCards.push_back(std::move(card));
            cardIndex++;
        }

        updateSuggestionsLayout();
    }

    void focusNextSuggestion()
    {
        if (suggestionCards.empty())
            return;

        // Find current selection
        int currentIndex = -1;
        for (size_t i = 0; i < suggestionCards.size(); ++i)
        {
            if (suggestionCards[i]->getSelected())
            {
                currentIndex = static_cast<int>(i);
                suggestionCards[i]->setSelected(false);
                break;
            }
        }

        // Select next
        int nextIndex = (currentIndex + 1) % suggestionCards.size();
        suggestionCards[nextIndex]->setSelected(true);
        suggestionCards[nextIndex]->grabKeyboardFocus();
    }

    void acceptFocusedSuggestion()
    {
        for (auto& card : suggestionCards)
        {
            if (card->getSelected())
            {
                acceptSuggestion(card->getId());
                return;
            }
        }
    }

private:
    void updateSuggestionsLayout()
    {
        int y = 0;
        int cardHeight = 80;
        int spacing = 8;

        for (auto& card : suggestionCards)
        {
            card->setBounds(0, y, viewport.getWidth() - 10, cardHeight);
            y += cardHeight + spacing;
        }

        suggestionsContainer.setSize(viewport.getWidth() - 10, y);
    }

    void acceptSuggestion(const juce::String& id)
    {
        RalphWiggum::RalphWiggumAPI::getInstance().acceptSuggestion(id);
        refreshSuggestions();
    }

    void dismissSuggestion(const juce::String& id)
    {
        RalphWiggum::RalphWiggumAPI::getInstance().rejectSuggestion(id);
        refreshSuggestions();
    }

    void generateMelody()
    {
        RalphWiggum::RalphWiggumAPI::getInstance().generateMelodyAsync(8,
            [](const RalphWiggum::RalphWiggumAPI::GeneratedMelody& melody) {
                // Would add to arrangement
                DBG("Generated melody with " << melody.notes.size() << " notes");
            });
    }

    void generateChords()
    {
        // Generate chord progression
        auto chords = RalphWiggum::RalphWiggumAPI::getInstance();
        // Would add to arrangement
    }

    juce::Label titleLabel;
    juce::TextButton refreshButton;
    juce::TextButton generateMelodyButton;
    juce::TextButton generateChordsButton;
    juce::ComboBox styleSelector;

    juce::Viewport viewport;
    juce::Component suggestionsContainer;
    std::vector<std::unique_ptr<SuggestionCard>> suggestionCards;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AISuggestionsPanel)
};

} // namespace GUI
} // namespace Echoelmusic
