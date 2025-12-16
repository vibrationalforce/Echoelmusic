#pragma once

#include <JuceHeader.h>

/**
 * ModernLookAndFeel - Visage/Vital-Inspired Dark Theme
 *
 * Professional GPU-accelerated UI aesthetics for Echoelmusic Pro
 *
 * Design Principles:
 * - Dark, minimalist aesthetic (black/charcoal backgrounds)
 * - Vibrant accent colors (cyan/electric blue #00d4ff)
 * - Subtle gradients and glows
 * - Smooth rounded corners
 * - High contrast for readability
 * - GPU-accelerated rendering where possible
 */
class ModernLookAndFeel : public juce::LookAndFeel_V4
{
public:
    ModernLookAndFeel();
    ~ModernLookAndFeel() override = default;

    //==========================================================================
    // Color Scheme
    //==========================================================================

    static constexpr uint32 ColorBackground      = 0xFF1A1A1A;  // Very dark gray
    static constexpr uint32 ColorBackgroundDark  = 0xFF0F0F0F;  // Almost black
    static constexpr uint32 ColorSurface          = 0xFF242424;  // Dark surface
    static constexpr uint32 ColorSurfaceLight     = 0xFF2E2E2E;  // Lighter surface

    static constexpr uint32 ColorPrimary          = 0xFF00D4FF;  // Electric cyan (Echoelmusic brand)
    static constexpr uint32 ColorPrimaryDark      = 0xFF0099CC;  // Darker cyan
    static constexpr uint32 ColorPrimaryLight     = 0xFF33DDFF;  // Lighter cyan

    static constexpr uint32 ColorAccent           = 0xFFFF00FF;  // Magenta accent
    static constexpr uint32 ColorWarning          = 0xFFFFAA00;  // Orange warning
    static constexpr uint32 ColorError            = 0xFFFF3333;  // Red error
    static constexpr uint32 ColorSuccess          = 0xFF00FF88;  // Green success

    static constexpr uint32 ColorText             = 0xFFFFFFFF;  // Pure white text
    static constexpr uint32 ColorTextDimmed       = 0xFFAAAAAA;  // Dimmed text
    static constexpr uint32 ColorTextDisabled     = 0xFF666666;  // Disabled text

    static constexpr uint32 ColorBorder           = 0xFF3A3A3A;  // Border color
    static constexpr uint32 ColorBorderHighlight  = 0xFF555555;  // Highlighted border

    //==========================================================================
    // Component Rendering Overrides
    //==========================================================================

    void drawRotarySlider(juce::Graphics& g, int x, int y, int width, int height,
                          float sliderPosProportional, float rotaryStartAngle,
                          float rotaryEndAngle, juce::Slider& slider) override;

    void drawLinearSlider(juce::Graphics& g, int x, int y, int width, int height,
                          float sliderPos, float minSliderPos, float maxSliderPos,
                          juce::Slider::SliderStyle style, juce::Slider& slider) override;

    void drawButtonBackground(juce::Graphics& g, juce::Button& button,
                              const juce::Colour& backgroundColour,
                              bool isMouseOverButton, bool isButtonDown) override;

    void drawComboBox(juce::Graphics& g, int width, int height,
                      bool isButtonDown, int buttonX, int buttonY,
                      int buttonW, int buttonH, juce::ComboBox& box) override;

    void drawLabel(juce::Graphics& g, juce::Label& label) override;

    void drawTextEditorOutline(juce::Graphics& g, int width, int height,
                                juce::TextEditor& textEditor) override;

    juce::Font getTextButtonFont(juce::TextButton&, int buttonHeight) override;
    juce::Font getComboBoxFont(juce::ComboBox&) override;
    juce::Font getLabelFont(juce::Label&) override;

    //==========================================================================
    // Utility Drawing Functions
    //==========================================================================

    static void drawGlow(juce::Graphics& g, juce::Rectangle<float> bounds,
                         juce::Colour glowColor, float intensity = 1.0f);

    static void drawRoundedRectangleWithGlow(juce::Graphics& g,
                                             juce::Rectangle<float> bounds,
                                             float cornerSize,
                                             juce::Colour fillColor,
                                             juce::Colour glowColor,
                                             float glowIntensity = 0.5f);

    static void drawGradientBackground(juce::Graphics& g,
                                       juce::Rectangle<float> bounds,
                                       juce::Colour topColor,
                                       juce::Colour bottomColor);

private:
    juce::Font modernFont;
    juce::Font boldFont;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ModernLookAndFeel)
};
