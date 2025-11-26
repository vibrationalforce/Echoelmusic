#pragma once

#include <JuceHeader.h>

//==============================================================================
/**
 * @brief Modern Look & Feel for Eoel
 *
 * Inspired by: Serum, FabFilter Pro-Q 3, iZotope Ozone, Ableton Live
 *
 * Features:
 * - Dark/Light theme support
 * - High contrast for visibility
 * - Touch-optimized controls
 * - Smooth animations
 * - Professional audio plugin aesthetics
 */
class ModernLookAndFeel : public juce::LookAndFeel_V4
{
public:
    //==============================================================================
    // Theme Configuration

    enum class Theme
    {
        Dark,           // Default dark theme (Serum/Ozone style)
        Light,          // Light theme for bright environments
        HighContrast    // Accessibility mode
    };

    ModernLookAndFeel(Theme theme = Theme::Dark)
    {
        setTheme(theme);
    }

    void setTheme(Theme newTheme)
    {
        currentTheme = newTheme;
        initializeColors();
    }

    Theme getTheme() const { return currentTheme; }

    //==============================================================================
    // Color Scheme

    struct ColorScheme
    {
        // Backgrounds
        juce::Colour backgroundDark;
        juce::Colour backgroundMedium;
        juce::Colour backgroundLight;

        // UI Elements
        juce::Colour border;
        juce::Colour outline;
        juce::Colour shadow;

        // Text
        juce::Colour textPrimary;
        juce::Colour textSecondary;
        juce::Colour textDisabled;

        // Accents
        juce::Colour accentPrimary;     // Main brand color (teal/cyan)
        juce::Colour accentSecondary;   // Secondary accent (purple/magenta)
        juce::Colour accentTertiary;    // Tertiary accent (orange/yellow)

        // Status colors
        juce::Colour success;           // Green
        juce::Colour warning;           // Orange
        juce::Colour error;             // Red
        juce::Colour info;              // Blue

        // Waveform/Spectrum colors
        juce::Colour waveformColor;
        juce::Colour spectrumLow;       // Bass frequencies
        juce::Colour spectrumMid;       // Mid frequencies
        juce::Colour spectrumHigh;      // High frequencies
    };

    const ColorScheme& getColors() const { return colors; }

    //==============================================================================
    // Custom Drawing Methods

    void drawRotarySlider(juce::Graphics& g, int x, int y, int width, int height,
                          float sliderPosProportional, float rotaryStartAngle,
                          float rotaryEndAngle, juce::Slider& slider) override
    {
        auto bounds = juce::Rectangle<int>(x, y, width, height).toFloat().reduced(10);
        auto radius = juce::jmin(bounds.getWidth(), bounds.getHeight()) / 2.0f;
        auto toAngle = rotaryStartAngle + sliderPosProportional * (rotaryEndAngle - rotaryStartAngle);
        auto lineW = juce::jmin(8.0f, radius * 0.5f);
        auto arcRadius = radius - lineW * 0.5f;

        // Draw background arc
        juce::Path backgroundArc;
        backgroundArc.addCentredArc(bounds.getCentreX(), bounds.getCentreY(),
                                    arcRadius, arcRadius, 0.0f,
                                    rotaryStartAngle, rotaryEndAngle, true);

        g.setColour(colors.backgroundLight);
        g.strokePath(backgroundArc, juce::PathStrokeType(lineW, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

        // Draw value arc
        if (sliderPosProportional > 0.0f)
        {
            juce::Path valueArc;
            valueArc.addCentredArc(bounds.getCentreX(), bounds.getCentreY(),
                                   arcRadius, arcRadius, 0.0f,
                                   rotaryStartAngle, toAngle, true);

            // Gradient from primary to secondary accent
            juce::ColourGradient gradient(colors.accentPrimary, bounds.getCentreX(), bounds.getY(),
                                         colors.accentSecondary, bounds.getCentreX(), bounds.getBottom(),
                                         false);
            g.setGradientFill(gradient);
            g.strokePath(valueArc, juce::PathStrokeType(lineW, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
        }

        // Draw pointer
        juce::Path pointer;
        auto pointerLength = radius * 0.33f;
        auto pointerThickness = lineW * 0.75f;
        pointer.addRectangle(-pointerThickness * 0.5f, -radius + 5, pointerThickness, pointerLength);
        pointer.applyTransform(juce::AffineTransform::rotation(toAngle).translated(bounds.getCentreX(), bounds.getCentreY()));

        g.setColour(colors.textPrimary);
        g.fillPath(pointer);

        // Draw center dot
        g.fillEllipse(bounds.getCentreX() - 4, bounds.getCentreY() - 4, 8, 8);
    }

    void drawLinearSlider(juce::Graphics& g, int x, int y, int width, int height,
                          float sliderPos, float minSliderPos, float maxSliderPos,
                          const juce::Slider::SliderStyle style, juce::Slider& slider) override
    {
        auto bounds = juce::Rectangle<int>(x, y, width, height);
        auto isHorizontal = (style == juce::Slider::LinearHorizontal);

        // Draw track
        auto trackBounds = isHorizontal
            ? bounds.withSizeKeepingCentre(width, 4)
            : bounds.withSizeKeepingCentre(4, height);

        g.setColour(colors.backgroundLight);
        g.fillRoundedRectangle(trackBounds.toFloat(), 2.0f);

        // Draw value track
        auto valueTrackBounds = trackBounds;
        if (isHorizontal)
            valueTrackBounds.setWidth(static_cast<int>(sliderPos - trackBounds.getX()));
        else
        {
            valueTrackBounds.setY(static_cast<int>(sliderPos));
            valueTrackBounds.setHeight(trackBounds.getBottom() - static_cast<int>(sliderPos));
        }

        g.setColour(colors.accentPrimary);
        g.fillRoundedRectangle(valueTrackBounds.toFloat(), 2.0f);

        // Draw thumb
        auto thumbSize = isHorizontal ? height * 0.6f : width * 0.6f;
        auto thumbBounds = isHorizontal
            ? juce::Rectangle<float>(sliderPos - thumbSize * 0.5f, bounds.getCentreY() - thumbSize * 0.5f, thumbSize, thumbSize)
            : juce::Rectangle<float>(bounds.getCentreX() - thumbSize * 0.5f, sliderPos - thumbSize * 0.5f, thumbSize, thumbSize);

        // Thumb shadow
        g.setColour(colors.shadow.withAlpha(0.3f));
        g.fillEllipse(thumbBounds.translated(0, 2));

        // Thumb gradient
        juce::ColourGradient thumbGradient(colors.textPrimary.brighter(0.2f), thumbBounds.getCentreX(), thumbBounds.getY(),
                                          colors.textPrimary.darker(0.2f), thumbBounds.getCentreX(), thumbBounds.getBottom(),
                                          false);
        g.setGradientFill(thumbGradient);
        g.fillEllipse(thumbBounds);

        // Thumb border
        g.setColour(colors.accentPrimary);
        g.drawEllipse(thumbBounds.reduced(1), 2.0f);
    }

    void drawButtonBackground(juce::Graphics& g, juce::Button& button,
                             const juce::Colour& backgroundColour,
                             bool isMouseOverButton, bool isButtonDown) override
    {
        auto bounds = button.getLocalBounds().toFloat().reduced(2);
        auto cornerSize = 4.0f;

        // Base color
        juce::Colour baseColour = backgroundColour;
        if (isButtonDown)
            baseColour = baseColour.darker(0.3f);
        else if (isMouseOverButton)
            baseColour = baseColour.brighter(0.2f);

        // Gradient
        juce::ColourGradient gradient(baseColour.brighter(0.1f), 0, bounds.getY(),
                                     baseColour.darker(0.1f), 0, bounds.getBottom(),
                                     false);
        g.setGradientFill(gradient);
        g.fillRoundedRectangle(bounds, cornerSize);

        // Border
        g.setColour(baseColour.brighter(0.3f));
        g.drawRoundedRectangle(bounds, cornerSize, 1.5f);

        // Shadow when pressed
        if (isButtonDown)
        {
            g.setColour(juce::Colours::black.withAlpha(0.2f));
            g.fillRoundedRectangle(bounds.reduced(2), cornerSize);
        }
    }

    void drawToggleButton(juce::Graphics& g, juce::ToggleButton& button,
                         bool shouldDrawButtonAsHighlighted, bool shouldDrawButtonAsDown) override
    {
        auto bounds = button.getLocalBounds().toFloat();
        auto toggleWidth = juce::jmin(50.0f, bounds.getHeight() * 2.0f);
        auto toggleBounds = bounds.removeFromLeft(toggleWidth).reduced(2);

        auto isOn = button.getToggleState();
        auto cornerSize = toggleBounds.getHeight() * 0.5f;

        // Track
        g.setColour(isOn ? colors.accentPrimary : colors.backgroundLight);
        g.fillRoundedRectangle(toggleBounds, cornerSize);

        // Thumb
        auto thumbSize = toggleBounds.getHeight() - 4;
        auto thumbX = isOn ? toggleBounds.getRight() - thumbSize - 2 : toggleBounds.getX() + 2;
        auto thumbBounds = juce::Rectangle<float>(thumbX, toggleBounds.getY() + 2, thumbSize, thumbSize);

        g.setColour(colors.textPrimary);
        g.fillEllipse(thumbBounds);

        // Label
        g.setColour(colors.textPrimary);
        g.setFont(14.0f);
        g.drawText(button.getButtonText(), bounds.withTrimmedLeft(toggleWidth + 8),
                   juce::Justification::centredLeft, true);
    }

    juce::Font getTextButtonFont(juce::TextButton&, int buttonHeight) override
    {
        return juce::Font(juce::jmin(16.0f, buttonHeight * 0.6f), juce::Font::bold);
    }

private:
    void initializeColors()
    {
        switch (currentTheme)
        {
            case Theme::Dark:
                colors.backgroundDark = juce::Colour(0xff1a1a1f);       // Very dark blue-gray
                colors.backgroundMedium = juce::Colour(0xff252530);     // Dark blue-gray
                colors.backgroundLight = juce::Colour(0xff35353f);      // Medium blue-gray

                colors.border = juce::Colour(0xff454550);
                colors.outline = juce::Colour(0xff555560);
                colors.shadow = juce::Colours::black.withAlpha(0.5f);

                colors.textPrimary = juce::Colour(0xffe8e8e8);
                colors.textSecondary = juce::Colour(0xffa8a8a8);
                colors.textDisabled = juce::Colour(0xff686868);

                colors.accentPrimary = juce::Colour(0xff00d4ff);        // Cyan (Serum-style)
                colors.accentSecondary = juce::Colour(0xffaa44ff);      // Purple
                colors.accentTertiary = juce::Colour(0xffffaa00);       // Orange

                colors.success = juce::Colour(0xff00ff88);
                colors.warning = juce::Colour(0xffffaa00);
                colors.error = juce::Colour(0xffff4444);
                colors.info = juce::Colour(0xff4488ff);

                colors.waveformColor = juce::Colour(0xff00d4ff);
                colors.spectrumLow = juce::Colour(0xffff4444);          // Red for bass
                colors.spectrumMid = juce::Colour(0xffffaa00);          // Orange for mids
                colors.spectrumHigh = juce::Colour(0xff00d4ff);         // Cyan for highs
                break;

            case Theme::Light:
                colors.backgroundDark = juce::Colour(0xffe8e8e8);
                colors.backgroundMedium = juce::Colour(0xfff4f4f4);
                colors.backgroundLight = juce::Colour(0xffffffff);

                colors.border = juce::Colour(0xffc0c0c0);
                colors.outline = juce::Colour(0xffa0a0a0);
                colors.shadow = juce::Colours::black.withAlpha(0.15f);

                colors.textPrimary = juce::Colour(0xff202020);
                colors.textSecondary = juce::Colour(0xff606060);
                colors.textDisabled = juce::Colour(0xffa0a0a0);

                colors.accentPrimary = juce::Colour(0xff0088cc);
                colors.accentSecondary = juce::Colour(0xff8844cc);
                colors.accentTertiary = juce::Colour(0xffcc8800);

                colors.success = juce::Colour(0xff00cc66);
                colors.warning = juce::Colour(0xffcc8800);
                colors.error = juce::Colour(0xffcc0000);
                colors.info = juce::Colour(0xff0088cc);

                colors.waveformColor = juce::Colour(0xff0088cc);
                colors.spectrumLow = juce::Colour(0xffcc0000);
                colors.spectrumMid = juce::Colour(0xffcc8800);
                colors.spectrumHigh = juce::Colour(0xff0088cc);
                break;

            case Theme::HighContrast:
                colors.backgroundDark = juce::Colours::black;
                colors.backgroundMedium = juce::Colour(0xff101010);
                colors.backgroundLight = juce::Colour(0xff202020);

                colors.border = juce::Colours::white;
                colors.outline = juce::Colours::white;
                colors.shadow = juce::Colours::black;

                colors.textPrimary = juce::Colours::white;
                colors.textSecondary = juce::Colour(0xffcccccc);
                colors.textDisabled = juce::Colour(0xff808080);

                colors.accentPrimary = juce::Colour(0xff00ffff);
                colors.accentSecondary = juce::Colour(0xffff00ff);
                colors.accentTertiary = juce::Colour(0xffffff00);

                colors.success = juce::Colour(0xff00ff00);
                colors.warning = juce::Colour(0xffffff00);
                colors.error = juce::Colour(0xffff0000);
                colors.info = juce::Colour(0xff00ffff);

                colors.waveformColor = juce::Colour(0xff00ffff);
                colors.spectrumLow = juce::Colour(0xffff0000);
                colors.spectrumMid = juce::Colour(0xffffff00);
                colors.spectrumHigh = juce::Colour(0xff00ffff);
                break;
        }

        // Apply to JUCE color IDs
        setColour(juce::ResizableWindow::backgroundColourId, colors.backgroundMedium);
        setColour(juce::Label::textColourId, colors.textPrimary);
        setColour(juce::TextButton::buttonColourId, colors.accentPrimary);
        setColour(juce::TextButton::textColourOffId, colors.textPrimary);
        setColour(juce::Slider::thumbColourId, colors.accentPrimary);
        setColour(juce::Slider::trackColourId, colors.backgroundLight);
        setColour(juce::Slider::rotarySliderFillColourId, colors.accentPrimary);
        setColour(juce::Slider::rotarySliderOutlineColourId, colors.backgroundLight);
    }

    Theme currentTheme;
    ColorScheme colors;
};
