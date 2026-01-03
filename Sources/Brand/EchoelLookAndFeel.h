/*
  ==============================================================================

    EchoelLookAndFeel.h
    Echoelmusic Visual Design System

    Das visuelle Herzstück von Echoelmusic.
    Konsistentes, modernes Design für alle Komponenten.

    Design Principles:
    ─────────────────
    1. CLARITY      - Klare Hierarchie, reduzierte Komplexität
    2. DEPTH        - Subtile Schatten, Glasmorphismus
    3. MOTION       - Sanfte Animationen, responsives Feedback
    4. ACCESSIBILITY - Hoher Kontrast, lesbare Schriften
    5. CONSISTENCY  - Einheitliche Patterns, Brand Colors

    Created: 2026
    Author: Echoelmusic Team

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "EchoelBrand.h"

namespace Echoelmusic
{
namespace Brand
{

//==============================================================================
/**
    EchoelLookAndFeel

    Das zentrale Look and Feel für alle Echoelmusic UIs.
*/
class EchoelLookAndFeel : public juce::LookAndFeel_V4
{
public:
    //==========================================================================
    // Theme Mode

    enum class ThemeMode
    {
        Dark,       // Standard: Dunkles Theme
        Light,      // Helles Theme
        System      // Folgt System-Präferenz
    };

    //==========================================================================
    // Constructor

    EchoelLookAndFeel(ThemeMode mode = ThemeMode::Dark)
        : themeMode(mode)
    {
        applyTheme();
        setupFonts();
    }

    //==========================================================================
    // Theme Management

    void setThemeMode(ThemeMode mode)
    {
        themeMode = mode;
        applyTheme();
    }

    ThemeMode getThemeMode() const { return themeMode; }

    bool isDarkMode() const
    {
        if (themeMode == ThemeMode::System)
        {
            // Würde System-Präferenz prüfen
            return true;  // Default: Dark
        }
        return themeMode == ThemeMode::Dark;
    }

    //==========================================================================
    // Color Getters

    juce::Colour getBackgroundColour() const
    {
        return isDarkMode() ?
            EchoelPalette::get(EchoelPalette::CosmosDark) :
            EchoelPalette::get(EchoelPalette::NebulaLight);
    }

    juce::Colour getSurfaceColour() const
    {
        return isDarkMode() ?
            EchoelPalette::get(EchoelPalette::CosmosDeep) :
            EchoelPalette::get(EchoelPalette::NebulaSoft);
    }

    juce::Colour getTextColour() const
    {
        return isDarkMode() ?
            EchoelPalette::get(EchoelPalette::NebulaLight) :
            EchoelPalette::get(EchoelPalette::CosmosBlack);
    }

    juce::Colour getAccentColour() const
    {
        return EchoelPalette::get(EchoelPalette::EchoelViolet);
    }

    juce::Colour getSecondaryAccentColour() const
    {
        return EchoelPalette::get(EchoelPalette::ResonanceCyan);
    }

    //==========================================================================
    // Button Overrides

    void drawButtonBackground(juce::Graphics& g, juce::Button& button,
                              const juce::Colour& backgroundColour,
                              bool shouldDrawButtonAsHighlighted,
                              bool shouldDrawButtonAsDown) override
    {
        auto bounds = button.getLocalBounds().toFloat().reduced(1.0f);
        auto cornerRadius = 8.0f;

        juce::Colour baseColour = backgroundColour;

        if (shouldDrawButtonAsDown)
        {
            baseColour = baseColour.darker(0.2f);
        }
        else if (shouldDrawButtonAsHighlighted)
        {
            baseColour = baseColour.brighter(0.1f);
        }

        // Gradient für Tiefe
        juce::ColourGradient gradient(
            baseColour.brighter(0.1f), bounds.getX(), bounds.getY(),
            baseColour.darker(0.1f), bounds.getX(), bounds.getBottom(),
            false
        );

        g.setGradientFill(gradient);
        g.fillRoundedRectangle(bounds, cornerRadius);

        // Subtiler Rand
        g.setColour(baseColour.brighter(0.2f).withAlpha(0.5f));
        g.drawRoundedRectangle(bounds, cornerRadius, 1.0f);
    }

    juce::Font getTextButtonFont(juce::TextButton&, int buttonHeight) override
    {
        return juce::Font(EchoelTypography::getPrimaryFont(),
                          EchoelTypography::SizeBase,
                          juce::Font::plain);
    }

    //==========================================================================
    // Slider Overrides

    void drawRotarySlider(juce::Graphics& g, int x, int y, int width, int height,
                          float sliderPosProportional, float rotaryStartAngle,
                          float rotaryEndAngle, juce::Slider& slider) override
    {
        auto bounds = juce::Rectangle<float>(x, y, width, height).reduced(4.0f);
        auto radius = juce::jmin(bounds.getWidth(), bounds.getHeight()) / 2.0f;
        auto centreX = bounds.getCentreX();
        auto centreY = bounds.getCentreY();
        auto rx = centreX - radius;
        auto ry = centreY - radius;
        auto rw = radius * 2.0f;
        auto angle = rotaryStartAngle + sliderPosProportional * (rotaryEndAngle - rotaryStartAngle);

        // Hintergrund
        g.setColour(getSurfaceColour());
        g.fillEllipse(rx, ry, rw, rw);

        // Track (Hintergrund-Bogen)
        juce::Path backgroundArc;
        backgroundArc.addCentredArc(centreX, centreY, radius - 4.0f, radius - 4.0f,
                                     0.0f, rotaryStartAngle, rotaryEndAngle, true);

        g.setColour(EchoelPalette::get(EchoelPalette::NebulaGray).withAlpha(0.3f));
        g.strokePath(backgroundArc, juce::PathStrokeType(4.0f, juce::PathStrokeType::curved,
                                                          juce::PathStrokeType::rounded));

        // Value Arc (gefüllter Bogen)
        if (slider.isEnabled())
        {
            juce::Path valueArc;
            valueArc.addCentredArc(centreX, centreY, radius - 4.0f, radius - 4.0f,
                                    0.0f, rotaryStartAngle, angle, true);

            juce::ColourGradient gradient(
                EchoelPalette::get(EchoelPalette::EchoelViolet),
                centreX, ry,
                EchoelPalette::get(EchoelPalette::ResonanceCyan),
                centreX, ry + rw,
                false
            );

            g.setGradientFill(gradient);
            g.strokePath(valueArc, juce::PathStrokeType(4.0f, juce::PathStrokeType::curved,
                                                         juce::PathStrokeType::rounded));
        }

        // Pointer
        juce::Path pointer;
        auto pointerLength = radius * 0.5f;
        auto pointerThickness = 3.0f;

        pointer.addRoundedRectangle(-pointerThickness * 0.5f, -radius + 8.0f,
                                     pointerThickness, pointerLength, 1.5f);

        g.setColour(getTextColour());
        g.fillPath(pointer, juce::AffineTransform::rotation(angle).translated(centreX, centreY));

        // Center dot
        g.setColour(getAccentColour());
        g.fillEllipse(centreX - 4.0f, centreY - 4.0f, 8.0f, 8.0f);
    }

    void drawLinearSlider(juce::Graphics& g, int x, int y, int width, int height,
                          float sliderPos, float minSliderPos, float maxSliderPos,
                          const juce::Slider::SliderStyle style, juce::Slider& slider) override
    {
        auto trackWidth = 4.0f;
        bool isHorizontal = style == juce::Slider::LinearHorizontal ||
                            style == juce::Slider::LinearBar;

        juce::Point<float> startPoint, endPoint;
        if (isHorizontal)
        {
            startPoint = {(float)x, (float)y + (float)height * 0.5f};
            endPoint = {(float)(x + width), startPoint.y};
        }
        else
        {
            startPoint = {(float)x + (float)width * 0.5f, (float)(y + height)};
            endPoint = {startPoint.x, (float)y};
        }

        // Background track
        juce::Path backgroundTrack;
        backgroundTrack.startNewSubPath(startPoint);
        backgroundTrack.lineTo(endPoint);

        g.setColour(EchoelPalette::get(EchoelPalette::NebulaGray).withAlpha(0.3f));
        g.strokePath(backgroundTrack, {trackWidth, juce::PathStrokeType::curved,
                                        juce::PathStrokeType::rounded});

        // Value track
        juce::Path valueTrack;
        juce::Point<float> minPoint, maxPoint;

        if (isHorizontal)
        {
            minPoint = {sliderPos, startPoint.y};
            maxPoint = startPoint;
        }
        else
        {
            minPoint = {startPoint.x, sliderPos};
            maxPoint = startPoint;
        }

        valueTrack.startNewSubPath(maxPoint);
        valueTrack.lineTo(minPoint);

        g.setColour(getAccentColour());
        g.strokePath(valueTrack, {trackWidth, juce::PathStrokeType::curved,
                                   juce::PathStrokeType::rounded});

        // Thumb
        auto thumbRadius = 8.0f;
        g.setColour(getAccentColour());
        g.fillEllipse(juce::Rectangle<float>(thumbRadius * 2.0f, thumbRadius * 2.0f)
                          .withCentre(isHorizontal ?
                              juce::Point<float>(sliderPos, startPoint.y) :
                              juce::Point<float>(startPoint.x, sliderPos)));

        // Thumb highlight
        g.setColour(getTextColour());
        g.fillEllipse(juce::Rectangle<float>(thumbRadius * 0.6f, thumbRadius * 0.6f)
                          .withCentre(isHorizontal ?
                              juce::Point<float>(sliderPos, startPoint.y) :
                              juce::Point<float>(startPoint.x, sliderPos)));
    }

    //==========================================================================
    // ComboBox Overrides

    void drawComboBox(juce::Graphics& g, int width, int height, bool isButtonDown,
                      int buttonX, int buttonY, int buttonW, int buttonH,
                      juce::ComboBox& box) override
    {
        auto bounds = juce::Rectangle<int>(0, 0, width, height).toFloat().reduced(1.0f);
        auto cornerRadius = 6.0f;

        g.setColour(getSurfaceColour());
        g.fillRoundedRectangle(bounds, cornerRadius);

        g.setColour(getAccentColour().withAlpha(0.5f));
        g.drawRoundedRectangle(bounds, cornerRadius, 1.0f);

        // Arrow
        auto arrowZone = juce::Rectangle<float>(buttonX, buttonY, buttonW, buttonH).reduced(8.0f);
        juce::Path arrow;
        arrow.addTriangle(arrowZone.getCentreX() - 4.0f, arrowZone.getCentreY() - 2.0f,
                          arrowZone.getCentreX() + 4.0f, arrowZone.getCentreY() - 2.0f,
                          arrowZone.getCentreX(), arrowZone.getCentreY() + 4.0f);

        g.setColour(getTextColour().withAlpha(box.isEnabled() ? 1.0f : 0.3f));
        g.fillPath(arrow);
    }

    //==========================================================================
    // Label Overrides

    void drawLabel(juce::Graphics& g, juce::Label& label) override
    {
        g.fillAll(label.findColour(juce::Label::backgroundColourId));

        if (!label.isBeingEdited())
        {
            auto textColour = label.findColour(juce::Label::textColourId);
            if (textColour == juce::Colours::black && isDarkMode())
                textColour = getTextColour();

            g.setColour(textColour);
            g.setFont(label.getFont());

            auto textArea = getLabelBorderSize(label).subtractedFrom(label.getLocalBounds());

            g.drawFittedText(label.getText(), textArea, label.getJustificationType(),
                             juce::jmax(1, (int)((float)textArea.getHeight() / label.getFont().getHeight())),
                             label.getMinimumHorizontalScale());
        }
    }

    //==========================================================================
    // ToggleButton Overrides

    void drawToggleButton(juce::Graphics& g, juce::ToggleButton& button,
                          bool shouldDrawButtonAsHighlighted,
                          bool shouldDrawButtonAsDown) override
    {
        auto fontSize = juce::jmin(15.0f, (float)button.getHeight() * 0.75f);
        auto tickWidth = fontSize * 1.1f;

        drawTickBox(g, button, 4.0f, ((float)button.getHeight() - tickWidth) * 0.5f,
                    tickWidth, tickWidth,
                    button.getToggleState(),
                    button.isEnabled(),
                    shouldDrawButtonAsHighlighted,
                    shouldDrawButtonAsDown);

        g.setColour(getTextColour());
        g.setFont(fontSize);

        g.drawFittedText(button.getButtonText(),
                         button.getLocalBounds().withTrimmedLeft(
                             juce::roundToInt(tickWidth) + 10).withTrimmedRight(2),
                         juce::Justification::centredLeft, 10);
    }

    void drawTickBox(juce::Graphics& g, juce::Component& component,
                     float x, float y, float w, float h,
                     bool ticked, bool isEnabled,
                     bool shouldDrawButtonAsHighlighted,
                     bool shouldDrawButtonAsDown) override
    {
        auto bounds = juce::Rectangle<float>(x, y, w, h).reduced(1.0f);
        auto cornerRadius = 4.0f;

        // Background
        g.setColour(getSurfaceColour());
        g.fillRoundedRectangle(bounds, cornerRadius);

        // Border
        g.setColour(ticked ? getAccentColour() :
                    EchoelPalette::get(EchoelPalette::NebulaGray));
        g.drawRoundedRectangle(bounds, cornerRadius, 1.5f);

        // Check mark
        if (ticked)
        {
            g.setColour(getAccentColour());
            g.fillRoundedRectangle(bounds.reduced(3.0f), cornerRadius - 1.0f);

            // Checkmark icon
            juce::Path tick;
            tick.startNewSubPath(bounds.getX() + bounds.getWidth() * 0.25f,
                                  bounds.getCentreY());
            tick.lineTo(bounds.getX() + bounds.getWidth() * 0.4f,
                        bounds.getY() + bounds.getHeight() * 0.7f);
            tick.lineTo(bounds.getX() + bounds.getWidth() * 0.75f,
                        bounds.getY() + bounds.getHeight() * 0.3f);

            g.setColour(getTextColour());
            g.strokePath(tick, juce::PathStrokeType(2.0f));
        }
    }

    //==========================================================================
    // ScrollBar Overrides

    void drawScrollbar(juce::Graphics& g, juce::ScrollBar& scrollbar,
                       int x, int y, int width, int height,
                       bool isScrollbarVertical, int thumbStartPosition,
                       int thumbSize, bool isMouseOver, bool isMouseDown) override
    {
        auto thumbColour = isMouseDown ? getAccentColour() :
                           isMouseOver ? getAccentColour().withAlpha(0.7f) :
                           EchoelPalette::get(EchoelPalette::NebulaGray).withAlpha(0.5f);

        juce::Rectangle<int> thumbBounds;

        if (isScrollbarVertical)
            thumbBounds = {x + 2, thumbStartPosition, width - 4, thumbSize};
        else
            thumbBounds = {thumbStartPosition, y + 2, thumbSize, height - 4};

        g.setColour(thumbColour);
        g.fillRoundedRectangle(thumbBounds.toFloat(), 3.0f);
    }

    //==========================================================================
    // Progress Bar

    void drawProgressBar(juce::Graphics& g, juce::ProgressBar& progressBar,
                         int width, int height, double progress,
                         const juce::String& textToShow) override
    {
        auto bounds = juce::Rectangle<int>(0, 0, width, height).toFloat().reduced(1.0f);
        auto cornerRadius = 4.0f;

        // Background
        g.setColour(getSurfaceColour());
        g.fillRoundedRectangle(bounds, cornerRadius);

        // Progress fill
        if (progress >= 0.0 && progress <= 1.0)
        {
            auto fillBounds = bounds.withWidth(bounds.getWidth() * (float)progress);

            juce::ColourGradient gradient(
                EchoelPalette::get(EchoelPalette::EchoelViolet),
                fillBounds.getX(), fillBounds.getY(),
                EchoelPalette::get(EchoelPalette::ResonanceCyan),
                fillBounds.getRight(), fillBounds.getY(),
                false
            );

            g.setGradientFill(gradient);
            g.fillRoundedRectangle(fillBounds, cornerRadius);
        }

        // Text
        if (textToShow.isNotEmpty())
        {
            g.setColour(getTextColour());
            g.setFont(EchoelTypography::SizeSM);
            g.drawText(textToShow, bounds.toNearestInt(), juce::Justification::centred);
        }
    }

    //==========================================================================
    // Popup Menu

    void drawPopupMenuBackground(juce::Graphics& g, int width, int height) override
    {
        auto bounds = juce::Rectangle<int>(0, 0, width, height).toFloat();

        // Shadow
        juce::DropShadow shadow(juce::Colours::black.withAlpha(0.3f), 8, {0, 2});
        shadow.drawForRectangle(g, bounds.toNearestInt());

        // Background
        g.setColour(getSurfaceColour());
        g.fillRoundedRectangle(bounds.reduced(2.0f), 8.0f);

        // Border
        g.setColour(getAccentColour().withAlpha(0.2f));
        g.drawRoundedRectangle(bounds.reduced(2.0f), 8.0f, 1.0f);
    }

    void drawPopupMenuItem(juce::Graphics& g, const juce::Rectangle<int>& area,
                           bool isSeparator, bool isActive, bool isHighlighted,
                           bool isTicked, bool hasSubMenu,
                           const juce::String& text, const juce::String& shortcutKeyText,
                           const juce::Drawable* icon, const juce::Colour* textColour) override
    {
        if (isSeparator)
        {
            auto r = area.reduced(5, 0);
            r.removeFromTop(juce::roundToInt(((float)r.getHeight() * 0.5f) - 0.5f));

            g.setColour(EchoelPalette::get(EchoelPalette::NebulaGray).withAlpha(0.2f));
            g.fillRect(r.removeFromTop(1));
        }
        else
        {
            auto textColourToUse = getTextColour();

            if (isHighlighted && isActive)
            {
                g.setColour(getAccentColour().withAlpha(0.2f));
                g.fillRoundedRectangle(area.toFloat().reduced(4.0f, 2.0f), 4.0f);
                textColourToUse = getAccentColour();
            }

            g.setColour(textColourToUse);
            g.setFont(EchoelTypography::SizeBase);

            auto maxTextWidth = area.getWidth() - 12;
            if (shortcutKeyText.isNotEmpty())
                maxTextWidth -= 80;

            g.drawFittedText(text, area.reduced(8, 0), juce::Justification::centredLeft, 1);

            if (shortcutKeyText.isNotEmpty())
            {
                g.setColour(textColourToUse.withAlpha(0.5f));
                g.setFont(EchoelTypography::SizeSM);
                g.drawText(shortcutKeyText, area.reduced(8, 0),
                           juce::Justification::centredRight);
            }

            if (isTicked)
            {
                auto tickBounds = area.removeFromLeft(area.getHeight()).reduced(6);
                g.setColour(getAccentColour());
                g.fillEllipse(tickBounds.toFloat());
            }
        }
    }

private:
    ThemeMode themeMode;

    void applyTheme()
    {
        // Set default colours for all components
        setColour(juce::ResizableWindow::backgroundColourId, getBackgroundColour());
        setColour(juce::TextButton::buttonColourId, getAccentColour());
        setColour(juce::TextButton::textColourOffId, getTextColour());
        setColour(juce::TextButton::textColourOnId, getTextColour());
        setColour(juce::Label::textColourId, getTextColour());
        setColour(juce::ComboBox::textColourId, getTextColour());
        setColour(juce::ComboBox::backgroundColourId, getSurfaceColour());
        setColour(juce::TextEditor::textColourId, getTextColour());
        setColour(juce::TextEditor::backgroundColourId, getSurfaceColour());
        setColour(juce::TextEditor::outlineColourId, getAccentColour().withAlpha(0.3f));
        setColour(juce::TextEditor::focusedOutlineColourId, getAccentColour());
        setColour(juce::ScrollBar::thumbColourId, getAccentColour().withAlpha(0.5f));
        setColour(juce::AlertWindow::backgroundColourId, getSurfaceColour());
        setColour(juce::AlertWindow::textColourId, getTextColour());
    }

    void setupFonts()
    {
        auto defaultFont = juce::Font(EchoelTypography::getPrimaryFont(),
                                       EchoelTypography::SizeBase,
                                       juce::Font::plain);
        setDefaultSansSerifTypeface(defaultFont.getTypefacePtr());
    }
};

//==============================================================================
/**
    EchoelLookAndFeelManager

    Singleton für globales Look and Feel Management.
*/
class EchoelLookAndFeelManager
{
public:
    static EchoelLookAndFeelManager& getInstance()
    {
        static EchoelLookAndFeelManager instance;
        return instance;
    }

    void initialize()
    {
        lookAndFeel = std::make_unique<EchoelLookAndFeel>();
        juce::LookAndFeel::setDefaultLookAndFeel(lookAndFeel.get());
    }

    void setTheme(EchoelLookAndFeel::ThemeMode mode)
    {
        if (lookAndFeel)
            lookAndFeel->setThemeMode(mode);
    }

    EchoelLookAndFeel* getLookAndFeel() { return lookAndFeel.get(); }

private:
    EchoelLookAndFeelManager() = default;
    std::unique_ptr<EchoelLookAndFeel> lookAndFeel;
};

} // namespace Brand
} // namespace Echoelmusic
