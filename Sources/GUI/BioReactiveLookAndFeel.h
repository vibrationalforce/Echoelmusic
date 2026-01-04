/*
  ==============================================================================

    BioReactiveLookAndFeel.h
    Bio-Reactive Visual Theme

    JUCE LookAndFeel that adapts colors and animations based on
    user's biometric state (coherence, stress, flow).

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "../UI/AccessibilityConstants.h"

namespace Echoelmusic {
namespace GUI {

class BioReactiveLookAndFeel : public juce::LookAndFeel_V4
{
public:
    BioReactiveLookAndFeel()
    {
        // Set default colors
        setColour(juce::ResizableWindow::backgroundColourId, juce::Colour(0xFF121218));
        setColour(juce::TextButton::buttonColourId, juce::Colour(0xFF2A2A3A));
        setColour(juce::TextButton::buttonOnColourId, juce::Colour(0xFF00D9FF));
        setColour(juce::TextButton::textColourOffId, juce::Colours::white);
        setColour(juce::TextButton::textColourOnId, juce::Colours::black);
        setColour(juce::ComboBox::backgroundColourId, juce::Colour(0xFF2A2A3A));
        setColour(juce::ComboBox::textColourId, juce::Colours::white);
        setColour(juce::ComboBox::arrowColourId, juce::Colour(0xFF00D9FF));
        setColour(juce::PopupMenu::backgroundColourId, juce::Colour(0xFF1A1A24));
        setColour(juce::PopupMenu::textColourId, juce::Colours::white);
        setColour(juce::PopupMenu::highlightedBackgroundColourId, juce::Colour(0xFF00D9FF));
        setColour(juce::Slider::thumbColourId, juce::Colour(0xFF00D9FF));
        setColour(juce::Slider::trackColourId, juce::Colour(0xFF3A3A4A));
        setColour(juce::Slider::backgroundColourId, juce::Colour(0xFF1A1A24));
        setColour(juce::Label::textColourId, juce::Colours::white);
        setColour(juce::TextEditor::backgroundColourId, juce::Colour(0xFF1A1A24));
        setColour(juce::TextEditor::textColourId, juce::Colours::white);
        setColour(juce::TextEditor::outlineColourId, juce::Colour(0xFF3A3A4A));
        setColour(juce::TextEditor::focusedOutlineColourId, juce::Colour(0xFF00D9FF));
    }

    void setCoherence(float coherence)
    {
        currentCoherence = juce::jlimit(0.0f, 1.0f, coherence);
        updateBioColors();
    }

    void setStress(float stress)
    {
        currentStress = juce::jlimit(0.0f, 1.0f, stress);
        updateBioColors();
    }

    void setFlowState(bool inFlow)
    {
        isInFlow = inFlow;
        updateBioColors();
    }

    // Button
    void drawButtonBackground(juce::Graphics& g, juce::Button& button,
                             const juce::Colour& backgroundColour,
                             bool isMouseOverButton, bool isButtonDown) override
    {
        auto bounds = button.getLocalBounds().toFloat().reduced(1);

        juce::Colour bgColor = backgroundColour;

        if (button.getToggleState())
            bgColor = findColour(juce::TextButton::buttonOnColourId);
        else if (isButtonDown)
            bgColor = bgColor.darker(0.2f);
        else if (isMouseOverButton)
            bgColor = bgColor.brighter(0.1f);

        // Bio-reactive tint
        if (currentCoherence > 0.7f && isInFlow)
            bgColor = bgColor.interpolatedWith(juce::Colour(0xFF4ADE80), 0.1f);

        g.setColour(bgColor);
        g.fillRoundedRectangle(bounds, 6.0f);

        // Focus ring for accessibility
        if (button.hasKeyboardFocus(true))
        {
            g.setColour(juce::Colour(0xFF00D9FF));
            g.drawRoundedRectangle(bounds, 6.0f, 2.0f);
        }
    }

    // Slider
    void drawLinearSlider(juce::Graphics& g, int x, int y, int width, int height,
                         float sliderPos, float minSliderPos, float maxSliderPos,
                         const juce::Slider::SliderStyle style, juce::Slider& slider) override
    {
        bool isVertical = style == juce::Slider::LinearVertical ||
                         style == juce::Slider::LinearBarVertical;

        juce::Rectangle<float> bounds(x, y, width, height);

        // Track
        auto trackBounds = isVertical ?
            bounds.reduced(bounds.getWidth() * 0.35f, 0) :
            bounds.reduced(0, bounds.getHeight() * 0.35f);

        g.setColour(findColour(juce::Slider::backgroundColourId));
        g.fillRoundedRectangle(trackBounds, 4.0f);

        // Filled portion
        juce::Rectangle<float> fillBounds;
        if (isVertical)
        {
            float fillHeight = sliderPos - y;
            fillBounds = trackBounds.withTop(sliderPos).withBottom(trackBounds.getBottom());
        }
        else
        {
            fillBounds = trackBounds.withRight(sliderPos);
        }

        // Bio-reactive fill color
        juce::Colour fillColor = findColour(juce::Slider::trackColourId);
        if (currentCoherence > 0.5f)
            fillColor = fillColor.interpolatedWith(getCoherenceColor(), 0.3f);

        g.setColour(fillColor);
        g.fillRoundedRectangle(fillBounds, 4.0f);

        // Thumb
        float thumbSize = isVertical ? width * 0.7f : height * 0.7f;
        juce::Rectangle<float> thumbBounds;

        if (isVertical)
            thumbBounds = juce::Rectangle<float>(
                bounds.getCentreX() - thumbSize / 2, sliderPos - thumbSize / 2,
                thumbSize, thumbSize);
        else
            thumbBounds = juce::Rectangle<float>(
                sliderPos - thumbSize / 2, bounds.getCentreY() - thumbSize / 2,
                thumbSize, thumbSize);

        juce::Colour thumbColor = findColour(juce::Slider::thumbColourId);
        g.setColour(thumbColor);
        g.fillEllipse(thumbBounds);

        // Thumb highlight
        g.setColour(thumbColor.brighter(0.3f));
        g.fillEllipse(thumbBounds.reduced(thumbSize * 0.2f));
    }

    // ComboBox
    void drawComboBox(juce::Graphics& g, int width, int height, bool isButtonDown,
                     int buttonX, int buttonY, int buttonW, int buttonH,
                     juce::ComboBox& box) override
    {
        auto bounds = juce::Rectangle<float>(0, 0, width, height).reduced(1);

        g.setColour(findColour(juce::ComboBox::backgroundColourId));
        g.fillRoundedRectangle(bounds, 6.0f);

        g.setColour(juce::Colour(0xFF3A3A4A));
        g.drawRoundedRectangle(bounds, 6.0f, 1.0f);

        // Arrow
        juce::Path arrow;
        float arrowSize = height * 0.3f;
        float arrowX = width - height * 0.6f;
        float arrowY = height * 0.35f;

        arrow.addTriangle(
            arrowX, arrowY,
            arrowX + arrowSize, arrowY,
            arrowX + arrowSize / 2, arrowY + arrowSize * 0.6f
        );

        g.setColour(findColour(juce::ComboBox::arrowColourId));
        g.fillPath(arrow);

        if (box.hasKeyboardFocus(true))
        {
            g.setColour(juce::Colour(0xFF00D9FF));
            g.drawRoundedRectangle(bounds, 6.0f, 2.0f);
        }
    }

    // Scrollbar
    void drawScrollbar(juce::Graphics& g, juce::ScrollBar& scrollbar,
                      int x, int y, int width, int height,
                      bool isScrollbarVertical, int thumbStartPosition, int thumbSize,
                      bool isMouseOver, bool isMouseDown) override
    {
        juce::Rectangle<int> thumbBounds;

        if (isScrollbarVertical)
            thumbBounds = juce::Rectangle<int>(x + 2, thumbStartPosition, width - 4, thumbSize);
        else
            thumbBounds = juce::Rectangle<int>(thumbStartPosition, y + 2, thumbSize, height - 4);

        juce::Colour thumbColor = juce::Colour(0xFF3A3A4A);
        if (isMouseDown)
            thumbColor = thumbColor.brighter(0.2f);
        else if (isMouseOver)
            thumbColor = thumbColor.brighter(0.1f);

        g.setColour(thumbColor);
        g.fillRoundedRectangle(thumbBounds.toFloat(), 4.0f);
    }

    // Popup menu
    void drawPopupMenuBackground(juce::Graphics& g, int width, int height) override
    {
        g.fillAll(findColour(juce::PopupMenu::backgroundColourId));
        g.setColour(juce::Colour(0xFF3A3A4A));
        g.drawRect(0, 0, width, height, 1);
    }

    void drawPopupMenuItem(juce::Graphics& g, const juce::Rectangle<int>& area,
                          bool isSeparator, bool isActive, bool isHighlighted,
                          bool isTicked, bool hasSubMenu,
                          const juce::String& text, const juce::String& shortcutKeyText,
                          const juce::Drawable* icon, const juce::Colour* textColour) override
    {
        if (isSeparator)
        {
            g.setColour(juce::Colour(0xFF3A3A4A));
            g.drawLine(area.getX() + 10, area.getCentreY(),
                      area.getRight() - 10, area.getCentreY(), 1.0f);
            return;
        }

        auto bounds = area.reduced(2);

        if (isHighlighted)
        {
            g.setColour(findColour(juce::PopupMenu::highlightedBackgroundColourId));
            g.fillRoundedRectangle(bounds.toFloat(), 4.0f);
        }

        g.setColour(isHighlighted ? juce::Colours::black :
                   findColour(juce::PopupMenu::textColourId));
        g.setFont(juce::Font(14.0f));

        auto textBounds = bounds.reduced(10, 0);
        g.drawText(text, textBounds, juce::Justification::centredLeft, true);

        if (!shortcutKeyText.isEmpty())
        {
            g.setColour(juce::Colour(0xFF6B6B7B));
            g.setFont(juce::Font(12.0f));
            g.drawText(shortcutKeyText, textBounds, juce::Justification::centredRight, true);
        }
    }

private:
    void updateBioColors()
    {
        // Update accent color based on coherence
        juce::Colour accentColor = getCoherenceColor();

        setColour(juce::TextButton::buttonOnColourId, accentColor);
        setColour(juce::Slider::thumbColourId, accentColor);
        setColour(juce::ComboBox::arrowColourId, accentColor);
    }

    juce::Colour getCoherenceColor() const
    {
        if (currentCoherence > 0.7f)
            return juce::Colour(0xFF4ADE80);  // Green - high coherence
        else if (currentCoherence > 0.4f)
            return juce::Colour(0xFF00D9FF);  // Cyan - medium
        else
            return juce::Colour(0xFFFBBF24);  // Yellow - low coherence
    }

    float currentCoherence = 0.5f;
    float currentStress = 0.3f;
    bool isInFlow = false;
};

} // namespace GUI
} // namespace Echoelmusic
