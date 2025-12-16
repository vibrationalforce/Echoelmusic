#include "ModernLookAndFeel.h"

//==============================================================================
// Constructor
//==============================================================================

ModernLookAndFeel::ModernLookAndFeel()
{
    // Use system sans-serif font with modern styling
    modernFont = juce::Font(juce::Font::getDefaultSansSerifFontName(), 14.0f, juce::Font::plain);
    boldFont = juce::Font(juce::Font::getDefaultSansSerifFontName(), 14.0f, juce::Font::bold);

    // Set default colors
    setColour(juce::ResizableWindow::backgroundColourId, juce::Colour(ColorBackground));
    setColour(juce::DocumentWindow::textColourId, juce::Colour(ColorText));

    // Slider colors
    setColour(juce::Slider::thumbColourId, juce::Colour(ColorPrimary));
    setColour(juce::Slider::trackColourId, juce::Colour(ColorSurface));
    setColour(juce::Slider::backgroundColourId, juce::Colour(ColorBackgroundDark));
    setColour(juce::Slider::textBoxTextColourId, juce::Colour(ColorText));
    setColour(juce::Slider::textBoxBackgroundColourId, juce::Colour(ColorSurface));
    setColour(juce::Slider::textBoxOutlineColourId, juce::Colour(ColorBorder));

    // Button colors
    setColour(juce::TextButton::buttonColourId, juce::Colour(ColorSurface));
    setColour(juce::TextButton::buttonOnColourId, juce::Colour(ColorPrimary));
    setColour(juce::TextButton::textColourOffId, juce::Colour(ColorText));
    setColour(juce::TextButton::textColourOnId, juce::Colour(ColorText));

    // ComboBox colors
    setColour(juce::ComboBox::backgroundColourId, juce::Colour(ColorSurface));
    setColour(juce::ComboBox::textColourId, juce::Colour(ColorText));
    setColour(juce::ComboBox::outlineColourId, juce::Colour(ColorBorder));
    setColour(juce::ComboBox::buttonColourId, juce::Colour(ColorSurfaceLight));
    setColour(juce::ComboBox::arrowColourId, juce::Colour(ColorPrimary));

    // Label colors
    setColour(juce::Label::textColourId, juce::Colour(ColorText));
    setColour(juce::Label::backgroundColourId, juce::Colours::transparentBlack);
    setColour(juce::Label::outlineColourId, juce::Colours::transparentBlack);

    // TextEditor colors
    setColour(juce::TextEditor::textColourId, juce::Colour(ColorText));
    setColour(juce::TextEditor::backgroundColourId, juce::Colour(ColorBackgroundDark));
    setColour(juce::TextEditor::outlineColourId, juce::Colour(ColorBorder));
    setColour(juce::TextEditor::focusedOutlineColourId, juce::Colour(ColorPrimary));
}

//==============================================================================
// Rotary Slider (Knob)
//==============================================================================

void ModernLookAndFeel::drawRotarySlider(juce::Graphics& g, int x, int y, int width, int height,
                                         float sliderPosProportional, float rotaryStartAngle,
                                         float rotaryEndAngle, juce::Slider& slider)
{
    auto bounds = juce::Rectangle<int>(x, y, width, height).toFloat().reduced(10.0f);
    auto radius = juce::jmin(bounds.getWidth(), bounds.getHeight()) / 2.0f;
    auto toAngle = rotaryStartAngle + sliderPosProportional * (rotaryEndAngle - rotaryStartAngle);
    auto lineW = juce::jmin(8.0f, radius * 0.5f);
    auto arcRadius = radius - lineW * 0.5f;

    // Background circle (track)
    juce::Path backgroundArc;
    backgroundArc.addCentredArc(bounds.getCentreX(),
                                bounds.getCentreY(),
                                arcRadius, arcRadius,
                                0.0f,
                                rotaryStartAngle,
                                rotaryEndAngle,
                                true);

    g.setColour(juce::Colour(ColorSurface));
    g.strokePath(backgroundArc, juce::PathStrokeType(lineW, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

    // Value arc (active portion)
    if (slider.isEnabled())
    {
        juce::Path valueArc;
        valueArc.addCentredArc(bounds.getCentreX(),
                               bounds.getCentreY(),
                               arcRadius, arcRadius,
                               0.0f,
                               rotaryStartAngle,
                               toAngle,
                               true);

        // Gradient from primary to primary light
        juce::ColourGradient gradient(juce::Colour(ColorPrimaryDark), bounds.getCentreX(), bounds.getY(),
                                      juce::Colour(ColorPrimary), bounds.getCentreX(), bounds.getBottom(),
                                      false);
        g.setGradientFill(gradient);
        g.strokePath(valueArc, juce::PathStrokeType(lineW, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

        // Glow effect on value arc
        auto glowColor = juce::Colour(ColorPrimary).withAlpha(0.3f);
        g.setColour(glowColor);
        g.strokePath(valueArc, juce::PathStrokeType(lineW + 4.0f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
    }

    // Center circle (thumb)
    auto thumbRadius = radius * 0.3f;
    auto thumbBounds = juce::Rectangle<float>(thumbRadius * 2.0f, thumbRadius * 2.0f)
                           .withCentre(bounds.getCentre());

    g.setColour(juce::Colour(ColorBackgroundDark));
    g.fillEllipse(thumbBounds);

    // Thumb border
    g.setColour(juce::Colour(ColorPrimary));
    g.drawEllipse(thumbBounds, 2.0f);

    // Indicator line pointing to current value
    juce::Path p;
    auto pointerLength = radius * 0.5f;
    auto pointerThickness = 3.0f;
    p.addRectangle(-pointerThickness * 0.5f, -radius, pointerThickness, pointerLength);
    p.applyTransform(juce::AffineTransform::rotation(toAngle).translated(bounds.getCentreX(), bounds.getCentreY()));

    g.setColour(juce::Colour(ColorPrimary));
    g.fillPath(p);
}

//==============================================================================
// Linear Slider
//==============================================================================

void ModernLookAndFeel::drawLinearSlider(juce::Graphics& g, int x, int y, int width, int height,
                                         float sliderPos, float minSliderPos, float maxSliderPos,
                                         juce::Slider::SliderStyle style, juce::Slider& slider)
{
    auto trackWidth = juce::jmin(6.0f, slider.isHorizontal() ? (float)height * 0.25f : (float)width * 0.25f);

    juce::Point<float> startPoint(slider.isHorizontal() ? (float)x : (float)x + (float)width * 0.5f,
                                  slider.isHorizontal() ? (float)y + (float)height * 0.5f : (float)(height + y));

    juce::Point<float> endPoint(slider.isHorizontal() ? (float)(width + x) : startPoint.x,
                                slider.isHorizontal() ? startPoint.y : (float)y);

    // Background track
    juce::Path backgroundTrack;
    backgroundTrack.startNewSubPath(startPoint);
    backgroundTrack.lineTo(endPoint);

    g.setColour(juce::Colour(ColorSurface));
    g.strokePath(backgroundTrack, juce::PathStrokeType(trackWidth, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

    // Value track
    juce::Path valueTrack;
    juce::Point<float> minPoint, maxPoint, thumbPoint;

    if (slider.isHorizontal())
    {
        thumbPoint = {sliderPos, (float)y + (float)height * 0.5f};
        minPoint = startPoint;
        maxPoint = thumbPoint;
    }
    else
    {
        thumbPoint = {(float)x + (float)width * 0.5f, sliderPos};
        minPoint = thumbPoint;
        maxPoint = endPoint;
    }

    valueTrack.startNewSubPath(minPoint);
    valueTrack.lineTo(maxPoint);

    g.setColour(juce::Colour(ColorPrimary));
    g.strokePath(valueTrack, juce::PathStrokeType(trackWidth, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));

    // Thumb
    auto thumbRadius = trackWidth * 1.5f;
    g.setColour(juce::Colour(ColorPrimary));
    g.fillEllipse(juce::Rectangle<float>(thumbRadius * 2.0f, thumbRadius * 2.0f).withCentre(thumbPoint));

    // Thumb glow
    g.setColour(juce::Colour(ColorPrimary).withAlpha(0.3f));
    g.fillEllipse(juce::Rectangle<float>((thumbRadius + 4.0f) * 2.0f, (thumbRadius + 4.0f) * 2.0f).withCentre(thumbPoint));
}

//==============================================================================
// Button
//==============================================================================

void ModernLookAndFeel::drawButtonBackground(juce::Graphics& g, juce::Button& button,
                                             const juce::Colour& backgroundColour,
                                             bool isMouseOverButton, bool isButtonDown)
{
    auto bounds = button.getLocalBounds().toFloat().reduced(1.0f);
    auto cornerSize = 6.0f;

    juce::Colour baseColor = button.getToggleState() ? juce::Colour(ColorPrimary) : juce::Colour(ColorSurface);

    if (isButtonDown)
        baseColor = baseColor.darker(0.2f);
    else if (isMouseOverButton)
        baseColor = baseColor.brighter(0.1f);

    // Draw rounded rectangle with gradient
    juce::ColourGradient gradient(baseColor.brighter(0.1f), bounds.getCentreX(), bounds.getY(),
                                  baseColor.darker(0.1f), bounds.getCentreX(), bounds.getBottom(),
                                  false);

    g.setGradientFill(gradient);
    g.fillRoundedRectangle(bounds, cornerSize);

    // Border
    g.setColour(button.getToggleState() ? juce::Colour(ColorPrimaryLight) : juce::Colour(ColorBorder));
    g.drawRoundedRectangle(bounds, cornerSize, 1.0f);

    // Glow when toggled
    if (button.getToggleState())
    {
        g.setColour(juce::Colour(ColorPrimary).withAlpha(0.2f));
        g.drawRoundedRectangle(bounds.expanded(2.0f), cornerSize + 2.0f, 2.0f);
    }
}

//==============================================================================
// ComboBox
//==============================================================================

void ModernLookAndFeel::drawComboBox(juce::Graphics& g, int width, int height,
                                     bool isButtonDown, int buttonX, int buttonY,
                                     int buttonW, int buttonH, juce::ComboBox& box)
{
    auto bounds = juce::Rectangle<int>(0, 0, width, height).toFloat().reduced(1.0f);
    auto cornerSize = 4.0f;

    // Background
    g.setColour(juce::Colour(ColorSurface));
    g.fillRoundedRectangle(bounds, cornerSize);

    // Border
    g.setColour(box.hasKeyboardFocus(true) ? juce::Colour(ColorPrimary) : juce::Colour(ColorBorder));
    g.drawRoundedRectangle(bounds, cornerSize, 1.0f);

    // Arrow button area
    auto arrowBounds = juce::Rectangle<int>(buttonX, buttonY, buttonW, buttonH).toFloat();

    juce::Path arrow;
    arrow.startNewSubPath(arrowBounds.getCentreX() - 4.0f, arrowBounds.getCentreY() - 2.0f);
    arrow.lineTo(arrowBounds.getCentreX(), arrowBounds.getCentreY() + 2.0f);
    arrow.lineTo(arrowBounds.getCentreX() + 4.0f, arrowBounds.getCentreY() - 2.0f);

    g.setColour(juce::Colour(ColorPrimary));
    g.strokePath(arrow, juce::PathStrokeType(2.0f));
}

//==============================================================================
// Label
//==============================================================================

void ModernLookAndFeel::drawLabel(juce::Graphics& g, juce::Label& label)
{
    g.fillAll(label.findColour(juce::Label::backgroundColourId));

    if (!label.isBeingEdited())
    {
        auto alpha = label.isEnabled() ? 1.0f : 0.5f;

        g.setColour(label.findColour(juce::Label::textColourId).withMultipliedAlpha(alpha));
        g.setFont(getLabelFont(label));

        auto textArea = getLabelBorderSize(label).subtractedFrom(label.getLocalBounds());

        g.drawFittedText(label.getText(), textArea, label.getJustificationType(),
                         juce::jmax(1, (int)((float)textArea.getHeight() / getLabelFont(label).getHeight())),
                         label.getMinimumHorizontalScale());

        g.setColour(label.findColour(juce::Label::outlineColourId).withMultipliedAlpha(alpha));
    }
}

//==============================================================================
// TextEditor
//==============================================================================

void ModernLookAndFeel::drawTextEditorOutline(juce::Graphics& g, int width, int height,
                                              juce::TextEditor& textEditor)
{
    auto bounds = juce::Rectangle<int>(0, 0, width, height).toFloat();
    auto cornerSize = 4.0f;

    if (textEditor.isEnabled())
    {
        if (textEditor.hasKeyboardFocus(true))
        {
            g.setColour(juce::Colour(ColorPrimary));
            g.drawRoundedRectangle(bounds.reduced(0.5f), cornerSize, 2.0f);
        }
        else
        {
            g.setColour(juce::Colour(ColorBorder));
            g.drawRoundedRectangle(bounds.reduced(0.5f), cornerSize, 1.0f);
        }
    }
}

//==============================================================================
// Fonts
//==============================================================================

juce::Font ModernLookAndFeel::getTextButtonFont(juce::TextButton&, int buttonHeight)
{
    return juce::Font(juce::jmin(16.0f, (float)buttonHeight * 0.6f));
}

juce::Font ModernLookAndFeel::getComboBoxFont(juce::ComboBox&)
{
    return modernFont;
}

juce::Font ModernLookAndFeel::getLabelFont(juce::Label&)
{
    return modernFont;
}

//==============================================================================
// Utility Drawing Functions
//==============================================================================

void ModernLookAndFeel::drawGlow(juce::Graphics& g, juce::Rectangle<float> bounds,
                                 juce::Colour glowColor, float intensity)
{
    for (int i = 0; i < 5; ++i)
    {
        float radius = (float)i * 2.0f;
        float alpha = intensity * (1.0f - (float)i / 5.0f);
        g.setColour(glowColor.withAlpha(alpha * 0.2f));
        g.drawRoundedRectangle(bounds.expanded(radius), 6.0f + radius, radius * 0.5f);
    }
}

void ModernLookAndFeel::drawRoundedRectangleWithGlow(juce::Graphics& g,
                                                     juce::Rectangle<float> bounds,
                                                     float cornerSize,
                                                     juce::Colour fillColor,
                                                     juce::Colour glowColor,
                                                     float glowIntensity)
{
    // Draw glow
    drawGlow(g, bounds, glowColor, glowIntensity);

    // Draw filled rectangle
    g.setColour(fillColor);
    g.fillRoundedRectangle(bounds, cornerSize);
}

void ModernLookAndFeel::drawGradientBackground(juce::Graphics& g,
                                               juce::Rectangle<float> bounds,
                                               juce::Colour topColor,
                                               juce::Colour bottomColor)
{
    juce::ColourGradient gradient(topColor, bounds.getCentreX(), bounds.getY(),
                                  bottomColor, bounds.getCentreX(), bounds.getBottom(),
                                  false);

    g.setGradientFill(gradient);
    g.fillRect(bounds);
}
