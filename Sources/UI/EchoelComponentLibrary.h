#pragma once

/**
 * EchoelComponentLibrary.h - Branded UI Component Library
 *
 * ╔══════════════════════════════════════════════════════════════════════════╗
 * ║  ECHOEL COMPONENT LIBRARY                                                ║
 * ╠══════════════════════════════════════════════════════════════════════════╣
 * ║                                                                          ║
 * ║  All components follow Echoel brand guidelines:                          ║
 * ║    • Consistent "Echoel" naming prefix                                   ║
 * ║    • WCAG 2.1 AAA accessibility compliance                               ║
 * ║    • Touch-intelligent with adaptive response                            ║
 * ║    • Vaporwave aesthetic with neon accents                               ║
 * ║    • Bio-reactive color support                                          ║
 * ║                                                                          ║
 * ║  Component Categories:                                                   ║
 * ║    • Controls (Knob, Slider, Button, Toggle)                             ║
 * ║    • Data Display (Meter, Spectrum, DataLabel)                           ║
 * ║    • Containers (Card, Panel, Dialog)                                    ║
 * ║    • Navigation (TabBar, Breadcrumb)                                     ║
 * ║    • Feedback (Toast, ProgressIndicator)                                 ║
 * ║                                                                          ║
 * ╚══════════════════════════════════════════════════════════════════════════╝
 */

#include "../Design/EchoelDesignSystem.h"
#include <JuceHeader.h>

namespace Echoel::UI
{

using namespace Echoel::Design;

//==============================================================================
// Base Component with Echoel Styling
//==============================================================================

class EchoelComponent : public juce::Component
{
public:
    EchoelComponent()
    {
        setOpaque(false);
        setAccessible(true);
    }

    void enableNeonGlow(bool enabled, juce::Colour colour = Colors::Neon::cyan())
    {
        glowEnabled = enabled;
        glowColour = colour;
        repaint();
    }

    void setAccessibilityLabel(const juce::String& label)
    {
        setTitle(label);
        setDescription(label);
    }

protected:
    bool glowEnabled = false;
    juce::Colour glowColour = Colors::Neon::cyan();
    float glowIntensity = 1.0f;

    void drawGlow(juce::Graphics& g)
    {
        if (glowEnabled)
        {
            Effects::drawNeonGlow(g, getLocalBounds().toFloat(),
                                  glowColour, glowIntensity);
        }
    }
};

//==============================================================================
// EchoelKnob - Branded Rotary Control
//==============================================================================

class EchoelKnob : public juce::Slider
{
public:
    enum class Size { Small, Medium, Large };

    EchoelKnob(const juce::String& name = "Knob", Size size = Size::Medium)
        : knobSize(size)
    {
        setSliderStyle(juce::Slider::RotaryVerticalDrag);
        setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);
        setName(Naming::component(name));

        // Accessibility
        setTitle(name);
        setDescription("Rotary control for " + name);

        // Touch target sizing
        updateSize();
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(4.0f);
        float diameter = juce::jmin(bounds.getWidth(), bounds.getHeight());
        auto centre = bounds.getCentre();

        // Glow effect
        if (isMouseOver() || isMouseButtonDown())
        {
            Effects::drawNeonGlow(g,
                juce::Rectangle<float>(diameter, diameter).withCentre(centre),
                accentColour, 0.5f);
        }

        // Track
        g.setColour(juce::Colour(Colors::Background::Card));
        g.fillEllipse(centre.x - diameter / 2, centre.y - diameter / 2,
                      diameter, diameter);

        // Arc background
        float arcRadius = diameter * 0.4f;
        juce::Path arcBg;
        arcBg.addCentredArc(centre.x, centre.y, arcRadius, arcRadius,
                            0.0f, startAngle, endAngle, true);
        g.setColour(juce::Colour(Colors::Text::Tertiary));
        g.strokePath(arcBg, juce::PathStrokeType(4.0f,
            juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

        // Arc value
        float normalizedValue = static_cast<float>(
            (getValue() - getMinimum()) / (getMaximum() - getMinimum()));
        float valueAngle = startAngle + normalizedValue * (endAngle - startAngle);

        juce::Path arcValue;
        arcValue.addCentredArc(centre.x, centre.y, arcRadius, arcRadius,
                               0.0f, startAngle, valueAngle, true);
        g.setColour(accentColour);
        g.strokePath(arcValue, juce::PathStrokeType(4.0f,
            juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

        // Indicator dot
        float indicatorAngle = valueAngle - juce::MathConstants<float>::halfPi;
        float indicatorRadius = diameter * 0.3f;
        float dotX = centre.x + std::cos(indicatorAngle) * indicatorRadius;
        float dotY = centre.y + std::sin(indicatorAngle) * indicatorRadius;
        g.fillEllipse(dotX - 4, dotY - 4, 8, 8);

        // Value text (handled by TextBox)
    }

    void setAccentColour(juce::Colour colour) { accentColour = colour; repaint(); }
    void setBioReactiveCoherence(float coherence)
    {
        accentColour = Colors::BioReactive::fromCoherence(coherence);
        repaint();
    }

private:
    Size knobSize;
    juce::Colour accentColour = Colors::Neon::cyan();
    static constexpr float startAngle = juce::MathConstants<float>::pi * 1.25f;
    static constexpr float endAngle = juce::MathConstants<float>::pi * 2.75f;

    void updateSize()
    {
        float size = TouchTargets::Knob;
        switch (knobSize)
        {
            case Size::Small:  size = TouchTargets::Minimum; break;
            case Size::Medium: size = TouchTargets::Knob; break;
            case Size::Large:  size = TouchTargets::KnobLarge; break;
        }
        setSize(static_cast<int>(size), static_cast<int>(size + 24));
    }
};

//==============================================================================
// EchoelSlider - Branded Linear Slider
//==============================================================================

class EchoelSlider : public juce::Slider
{
public:
    EchoelSlider(const juce::String& name = "Slider", bool horizontal = true)
        : isHorizontal(horizontal)
    {
        setSliderStyle(horizontal ? juce::Slider::LinearHorizontal
                                  : juce::Slider::LinearVertical);
        setTextBoxStyle(juce::Slider::TextBoxRight, false, 50, 20);
        setName(Naming::component(name));
        setTitle(name);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(2.0f);

        // Track background
        float trackThickness = 6.0f;
        juce::Rectangle<float> track;

        if (isHorizontal)
        {
            track = bounds.withSizeKeepingCentre(bounds.getWidth() - 20.0f,
                                                  trackThickness);
        }
        else
        {
            track = bounds.withSizeKeepingCentre(trackThickness,
                                                  bounds.getHeight() - 20.0f);
        }

        // Draw track background
        g.setColour(juce::Colour(Colors::Background::Card));
        g.fillRoundedRectangle(track, Radius::SM);

        // Draw filled portion
        float normalizedValue = static_cast<float>(
            (getValue() - getMinimum()) / (getMaximum() - getMinimum()));

        juce::Rectangle<float> filled = track;
        if (isHorizontal)
            filled.setWidth(track.getWidth() * normalizedValue);
        else
        {
            float height = track.getHeight() * normalizedValue;
            filled.setY(track.getBottom() - height);
            filled.setHeight(height);
        }

        g.setColour(accentColour);
        g.fillRoundedRectangle(filled, Radius::SM);

        // Draw thumb
        float thumbSize = 20.0f;
        juce::Rectangle<float> thumbBounds;

        if (isHorizontal)
        {
            float thumbX = track.getX() + normalizedValue * track.getWidth();
            thumbBounds = juce::Rectangle<float>(thumbSize, thumbSize)
                .withCentre({thumbX, track.getCentreY()});
        }
        else
        {
            float thumbY = track.getBottom() - normalizedValue * track.getHeight();
            thumbBounds = juce::Rectangle<float>(thumbSize, thumbSize)
                .withCentre({track.getCentreX(), thumbY});
        }

        // Thumb glow
        if (isMouseOver() || isMouseButtonDown())
        {
            Effects::drawNeonGlow(g, thumbBounds, accentColour, 0.6f);
        }

        // Thumb body
        g.setColour(accentColour);
        g.fillEllipse(thumbBounds);
        g.setColour(Colors::Text::primary());
        g.drawEllipse(thumbBounds.reduced(2.0f), 2.0f);
    }

    void setAccentColour(juce::Colour colour) { accentColour = colour; repaint(); }

private:
    bool isHorizontal;
    juce::Colour accentColour = Colors::Neon::cyan();
};

//==============================================================================
// EchoelButton - Branded Button with Glow
//==============================================================================

class EchoelButton : public juce::TextButton
{
public:
    enum class Style { Primary, Secondary, Ghost, Danger };

    EchoelButton(const juce::String& text, Style style = Style::Primary)
        : buttonStyle(style)
    {
        setButtonText(text);
        setName(Naming::component("Button"));
        applyStyle();
    }

    void paintButton(juce::Graphics& g, bool shouldDrawButtonAsHighlighted,
                     bool shouldDrawButtonAsDown) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(2.0f);

        // Glow on hover
        if (shouldDrawButtonAsHighlighted && buttonStyle != Style::Ghost)
        {
            Effects::drawNeonGlow(g, bounds, glowColour, 0.4f);
        }

        // Background
        juce::Colour bgColour = backgroundColour;
        if (shouldDrawButtonAsDown)
            bgColour = bgColour.brighter(0.2f);
        else if (shouldDrawButtonAsHighlighted)
            bgColour = bgColour.brighter(0.1f);

        if (buttonStyle == Style::Ghost)
        {
            g.setColour(shouldDrawButtonAsHighlighted ?
                bgColour.withAlpha(0.1f) : juce::Colours::transparentBlack);
        }
        else
        {
            g.setColour(bgColour);
        }
        g.fillRoundedRectangle(bounds, Radius::Button);

        // Border for secondary/ghost
        if (buttonStyle == Style::Secondary || buttonStyle == Style::Ghost)
        {
            g.setColour(textColour);
            g.drawRoundedRectangle(bounds, Radius::Button, 1.5f);
        }

        // Text
        g.setColour(textColour);
        g.setFont(Typography::buttonText());
        g.drawText(getButtonText(), bounds, juce::Justification::centred);
    }

    void setStyle(Style style)
    {
        buttonStyle = style;
        applyStyle();
        repaint();
    }

private:
    Style buttonStyle;
    juce::Colour backgroundColour;
    juce::Colour textColour;
    juce::Colour glowColour;

    void applyStyle()
    {
        switch (buttonStyle)
        {
            case Style::Primary:
                backgroundColour = Colors::Neon::pink();
                textColour = Colors::Text::primary();
                glowColour = Colors::Neon::pink();
                break;

            case Style::Secondary:
                backgroundColour = Colors::Neon::cyan().withAlpha(0.2f);
                textColour = Colors::Neon::cyan();
                glowColour = Colors::Neon::cyan();
                break;

            case Style::Ghost:
                backgroundColour = juce::Colours::transparentBlack;
                textColour = Colors::Text::primary();
                glowColour = Colors::Text::primary();
                break;

            case Style::Danger:
                backgroundColour = Colors::Functional::error();
                textColour = Colors::Text::primary();
                glowColour = Colors::Functional::error();
                break;
        }
    }
};

//==============================================================================
// EchoelCard - Glass Card Container
//==============================================================================

class EchoelCard : public EchoelComponent
{
public:
    EchoelCard(const juce::String& title = "")
        : cardTitle(title)
    {
        setName(Naming::component("Card"));
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Glass effect background
        Effects::drawGlassCard(g, bounds, 0.15f);

        // Title if present
        if (cardTitle.isNotEmpty())
        {
            g.setColour(Colors::Text::primary());
            g.setFont(Typography::subtitle());
            g.drawText(cardTitle, bounds.reduced(Spacing::CardPadding)
                .removeFromTop(30.0f), juce::Justification::topLeft);
        }
    }

    juce::Rectangle<int> getContentBounds() const
    {
        auto bounds = getLocalBounds().reduced(static_cast<int>(Spacing::CardPadding));
        if (cardTitle.isNotEmpty())
            bounds.removeFromTop(36);
        return bounds;
    }

    void setTitle(const juce::String& title)
    {
        cardTitle = title;
        repaint();
    }

private:
    juce::String cardTitle;
};

//==============================================================================
// EchoelDataLabel - Data Display with Units
//==============================================================================

class EchoelDataLabel : public juce::Component
{
public:
    EchoelDataLabel(const juce::String& labelText = "Label",
                    const juce::String& unitText = "")
        : label(labelText), unit(unitText)
    {
        setName(Naming::component("DataLabel"));
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Label
        g.setColour(Colors::Text::secondary());
        g.setFont(Typography::caption());
        g.drawText(label, bounds.removeFromTop(16.0f),
                   juce::Justification::centredLeft);

        // Value + Unit
        g.setColour(valueColour);
        g.setFont(Typography::dataDisplay(valueSize));

        juce::String displayText = value;
        if (unit.isNotEmpty())
            displayText += " " + unit;

        g.drawText(displayText, bounds, juce::Justification::centredLeft);
    }

    void setValue(const juce::String& newValue)
    {
        value = newValue;
        repaint();
    }

    void setValue(float numericValue, int decimals = 1)
    {
        value = juce::String(numericValue, decimals);
        repaint();
    }

    void setValueColour(juce::Colour colour) { valueColour = colour; repaint(); }
    void setValueSize(float size) { valueSize = size; repaint(); }

    void setBioReactiveCoherence(float coherence)
    {
        valueColour = Colors::BioReactive::fromCoherence(coherence);
        repaint();
    }

private:
    juce::String label;
    juce::String value = "--";
    juce::String unit;
    juce::Colour valueColour = Colors::Neon::cyan();
    float valueSize = Typography::Size::DataLarge;
};

//==============================================================================
// EchoelMeter - Level Meter with Peak Hold
//==============================================================================

class EchoelMeter : public juce::Component, public juce::Timer
{
public:
    EchoelMeter(bool horizontal = false)
        : isHorizontal(horizontal)
    {
        setName(Naming::component("Meter"));
        startTimerHz(30);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(2.0f);

        // Background
        g.setColour(juce::Colour(Colors::Background::Card));
        g.fillRoundedRectangle(bounds, Radius::SM);

        // Level
        juce::Rectangle<float> levelBounds = bounds.reduced(2.0f);
        float level = juce::jlimit(0.0f, 1.0f, displayLevel);

        if (isHorizontal)
            levelBounds.setWidth(levelBounds.getWidth() * level);
        else
        {
            float height = levelBounds.getHeight() * level;
            levelBounds.setY(levelBounds.getBottom() - height);
            levelBounds.setHeight(height);
        }

        // Gradient based on level
        juce::Colour levelColour = level < 0.7f ? Colors::Neon::mint()
            : (level < 0.9f ? Colors::Neon::yellow() : Colors::Functional::error());
        g.setColour(levelColour);
        g.fillRoundedRectangle(levelBounds, Radius::SM);

        // Peak indicator
        if (peakLevel > 0.01f)
        {
            float peakPos = isHorizontal ?
                bounds.getX() + bounds.getWidth() * peakLevel :
                bounds.getBottom() - bounds.getHeight() * peakLevel;

            g.setColour(Colors::Text::primary());
            if (isHorizontal)
                g.fillRect(peakPos - 1, bounds.getY(), 2.0f, bounds.getHeight());
            else
                g.fillRect(bounds.getX(), peakPos - 1, bounds.getWidth(), 2.0f);
        }
    }

    void setLevel(float newLevel)
    {
        targetLevel = juce::jlimit(0.0f, 1.0f, newLevel);

        // Update peak
        if (targetLevel > peakLevel)
        {
            peakLevel = targetLevel;
            peakHoldCounter = peakHoldTime;
        }
    }

    void timerCallback() override
    {
        // Smooth level display
        displayLevel += (targetLevel - displayLevel) * 0.3f;

        // Peak hold and decay
        if (peakHoldCounter > 0)
            peakHoldCounter--;
        else
            peakLevel *= 0.95f;

        repaint();
    }

private:
    bool isHorizontal;
    float targetLevel = 0.0f;
    float displayLevel = 0.0f;
    float peakLevel = 0.0f;
    int peakHoldCounter = 0;
    static constexpr int peakHoldTime = 30;  // ~1 second at 30fps
};

//==============================================================================
// EchoelToast - Notification Toast
//==============================================================================

class EchoelToast : public juce::Component, public juce::Timer
{
public:
    enum class Type { Info, Success, Warning, Error };

    static void show(juce::Component* parent, const juce::String& message,
                     Type type = Type::Info, int durationMs = 3000)
    {
        auto* toast = new EchoelToast(message, type, durationMs);
        parent->addAndMakeVisible(toast);

        // Position at bottom center
        int width = 300;
        int height = 50;
        toast->setBounds((parent->getWidth() - width) / 2,
                         parent->getHeight() - height - 20,
                         width, height);

        // Animate in
        toast->setAlpha(0.0f);
        juce::Desktop::getInstance().getAnimator().animateComponent(
            toast, toast->getBounds(), 1.0f, Animation::Normal, false, 1.0, 1.0);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.setColour(backgroundColour);
        g.fillRoundedRectangle(bounds, Radius::MD);

        // Icon area (left)
        auto iconBounds = bounds.removeFromLeft(40.0f);
        g.setColour(iconColour);
        g.setFont(Typography::title());
        g.drawText(icon, iconBounds, juce::Justification::centred);

        // Message
        g.setColour(Colors::Text::primary());
        g.setFont(Typography::body());
        g.drawText(message, bounds.reduced(Spacing::SM, 0),
                   juce::Justification::centredLeft);
    }

    void timerCallback() override
    {
        stopTimer();

        // Animate out
        juce::Desktop::getInstance().getAnimator().animateComponent(
            this, getBounds(), 0.0f, Animation::Normal, true, 1.0, 1.0);

        // Delete after animation
        juce::Timer::callAfterDelay(Animation::Normal, [this]() { delete this; });
    }

private:
    juce::String message;
    juce::String icon;
    juce::Colour backgroundColour;
    juce::Colour iconColour;

    EchoelToast(const juce::String& msg, Type type, int durationMs)
        : message(msg)
    {
        setName(Naming::component("Toast"));
        setAlwaysOnTop(true);

        switch (type)
        {
            case Type::Info:
                icon = "i";
                backgroundColour = Colors::Neon::cyan().withAlpha(0.9f);
                iconColour = Colors::Text::primary();
                break;
            case Type::Success:
                icon = "\u2713";  // Check mark
                backgroundColour = Colors::Functional::success().withAlpha(0.9f);
                iconColour = Colors::Text::primary();
                break;
            case Type::Warning:
                icon = "!";
                backgroundColour = Colors::Functional::warning().withAlpha(0.9f);
                iconColour = Colors::Background::deepSpace();
                break;
            case Type::Error:
                icon = "\u2717";  // X mark
                backgroundColour = Colors::Functional::error().withAlpha(0.9f);
                iconColour = Colors::Text::primary();
                break;
        }

        startTimer(durationMs);
    }
};

//==============================================================================
// EchoelTabBar - Navigation Tabs
//==============================================================================

class EchoelTabBar : public juce::Component
{
public:
    class Listener
    {
    public:
        virtual ~Listener() = default;
        virtual void tabSelected(int tabIndex) = 0;
    };

    EchoelTabBar()
    {
        setName(Naming::component("TabBar"));
    }

    void addTab(const juce::String& name)
    {
        tabs.push_back(name);
        repaint();
    }

    void setSelectedTab(int index)
    {
        if (index >= 0 && index < static_cast<int>(tabs.size()))
        {
            selectedIndex = index;
            repaint();

            for (auto* l : listeners)
                l->tabSelected(index);
        }
    }

    int getSelectedTab() const { return selectedIndex; }

    void addListener(Listener* l) { listeners.push_back(l); }
    void removeListener(Listener* l)
    {
        listeners.erase(std::remove(listeners.begin(), listeners.end(), l),
                        listeners.end());
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();
        float tabWidth = bounds.getWidth() / static_cast<float>(tabs.size());

        for (size_t i = 0; i < tabs.size(); ++i)
        {
            auto tabBounds = bounds.removeFromLeft(tabWidth);
            bool isSelected = static_cast<int>(i) == selectedIndex;

            // Tab background
            if (isSelected)
            {
                g.setColour(Colors::Neon::cyan().withAlpha(0.2f));
                g.fillRoundedRectangle(tabBounds.reduced(2.0f), Radius::SM);
            }

            // Tab text
            g.setColour(isSelected ? Colors::Neon::cyan() : Colors::Text::secondary());
            g.setFont(Typography::label());
            g.drawText(tabs[i], tabBounds, juce::Justification::centred);

            // Indicator
            if (isSelected)
            {
                g.setColour(Colors::Neon::cyan());
                g.fillRoundedRectangle(
                    tabBounds.removeFromBottom(3.0f).reduced(tabWidth * 0.2f, 0),
                    Radius::SM);
            }
        }
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        float tabWidth = static_cast<float>(getWidth()) /
                         static_cast<float>(tabs.size());
        int clickedIndex = static_cast<int>(e.x / tabWidth);
        setSelectedTab(clickedIndex);
    }

private:
    std::vector<juce::String> tabs;
    std::vector<Listener*> listeners;
    int selectedIndex = 0;
};

}  // namespace Echoel::UI
