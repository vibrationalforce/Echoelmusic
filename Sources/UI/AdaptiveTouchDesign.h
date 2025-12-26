#pragma once

#include <JuceHeader.h>
#include "SuperIntelligenceTouch.h"
#include "TouchOptimizedControls.h"

namespace Echoel {
namespace Touch {

//==============================================================================
/**
 * @brief Adaptive Touch Design System
 *
 * Ein neues Design-Paradigma basierend auf SuperIntelligenceTouch:
 *
 * DESIGN-PHILOSOPHIE:
 * "Die UI passt sich dem Benutzer an - nicht umgekehrt"
 *
 * 1. INTENT-AWARE VISUALS
 *    - Controls ändern Farbe/Größe basierend auf erkanntem Intent
 *    - FINE Mode: Größere Ziele, gedämpfte Farben, Präzisions-Indikatoren
 *    - MORPH Mode: Kompakte UI, lebhafte Farben, Flow-Visualisierung
 *
 * 2. TREMOR-ADAPTIVE SIZING
 *    - Bei erkanntem Zittern: Automatisch größere Touch-Bereiche
 *    - Dynamische Hit-Box-Erweiterung
 *    - Visuelle "Magnet"-Zonen
 *
 * 3. CONTEXT-SENSITIVE FEEDBACK
 *    - Haptisches Feedback (wo verfügbar)
 *    - Audio-Feedback bei Wertänderungen
 *    - Visuelle Ripple-Effekte
 *
 * 4. PHASE-COHERENT ANIMATIONS
 *    - Alle Animationen sind phasen-synchron
 *    - Keine abrupten Übergänge
 *    - Smooth morphing zwischen Zuständen
 */

//==============================================================================
/**
 * @brief Design Theme for Intent-Aware UI
 */
struct AdaptiveDesignTheme
{
    // Base colors
    juce::Colour backgroundDark { 0xff0a0a12 };
    juce::Colour backgroundMedium { 0xff1a1a2a };
    juce::Colour backgroundLight { 0xff2a2a3a };

    // Intent-specific colors
    juce::Colour fineAdjustPrimary { 0xff00d4ff };     // Cyan
    juce::Colour fineAdjustSecondary { 0xff0088aa };
    juce::Colour fastMorphPrimary { 0xffff8800 };      // Orange
    juce::Colour fastMorphSecondary { 0xffaa5500 };
    juce::Colour holdPrimary { 0xff88ff00 };           // Green
    juce::Colour swipePrimary { 0xffff00ff };          // Magenta

    // Neutral state
    juce::Colour neutralPrimary { 0xff6080a0 };
    juce::Colour neutralSecondary { 0xff405060 };

    // Text
    juce::Colour textPrimary { 0xffffffff };
    juce::Colour textSecondary { 0xffa0a0b0 };
    juce::Colour textDimmed { 0xff606070 };

    // Get color for current intent
    juce::Colour getIntentColor(TouchIntent intent, bool primary = true) const
    {
        switch (intent)
        {
            case TouchIntent::FineAdjust:
                return primary ? fineAdjustPrimary : fineAdjustSecondary;
            case TouchIntent::FastMorph:
            case TouchIntent::Swipe:
                return primary ? fastMorphPrimary : fastMorphSecondary;
            case TouchIntent::Hold:
                return primary ? holdPrimary : holdPrimary.darker(0.3f);
            default:
                return primary ? neutralPrimary : neutralSecondary;
        }
    }

    // Get recommended control size for intent
    float getControlScale(TouchIntent intent, float tremorLevel) const
    {
        float baseScale = 1.0f;

        // Enlarge for fine adjustment
        if (intent == TouchIntent::FineAdjust)
            baseScale = 1.3f;

        // Further enlarge if tremor detected
        if (tremorLevel > 0.5f)
            baseScale *= 1.0f + (tremorLevel - 0.5f) * 0.4f;

        return baseScale;
    }
};

//==============================================================================
/**
 * @brief Adaptive Control Base - Self-adjusting UI element
 */
class AdaptiveControl : public juce::Component,
                        public SuperIntelligenceTouch::Listener,
                        public juce::Timer
{
public:
    AdaptiveControl()
    {
        touchController.addListener(this);
        startTimerHz(60);  // Animation timer
    }

    ~AdaptiveControl() override
    {
        touchController.removeListener(this);
        stopTimer();
    }

    void setTheme(const AdaptiveDesignTheme& t) { theme = t; repaint(); }

protected:
    // Override to customize appearance
    virtual void paintControl(juce::Graphics& g, juce::Rectangle<float> bounds,
                              TouchIntent intent, float animationPhase) = 0;

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Apply adaptive scaling
        float scale = theme.getControlScale(currentIntent, tremorLevel);
        if (std::abs(scale - currentScale) > 0.01f)
        {
            currentScale = currentScale * 0.9f + scale * 0.1f;  // Smooth transition
        }

        // Center and scale
        auto scaledBounds = bounds.withSizeKeepingCentre(
            bounds.getWidth() * currentScale,
            bounds.getHeight() * currentScale
        );

        paintControl(g, scaledBounds, currentIntent, animationPhase);

        // Draw intent indicator ring (when active)
        if (isActive && currentIntent != TouchIntent::Unknown)
        {
            g.setColour(theme.getIntentColor(currentIntent).withAlpha(0.3f + 0.2f * animationPhase));
            g.drawEllipse(scaledBounds.expanded(5), 2.0f);
        }
    }

    void timerCallback() override
    {
        animationPhase += 0.05f;
        if (animationPhase > 1.0f) animationPhase = 0.0f;

        if (isActive || std::abs(currentScale - 1.0f) > 0.01f)
            repaint();
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        isActive = true;
        touchController.processTouch(e.source.getIndex(), e.position, true);
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        touchController.processTouch(e.source.getIndex(), e.position, true);
    }

    void mouseUp(const juce::MouseEvent& e) override
    {
        isActive = false;
        touchController.processTouch(e.source.getIndex(), e.position, false);
        currentIntent = TouchIntent::Unknown;
    }

    // SuperIntelligenceTouch::Listener
    void onIntentChanged(int id, TouchIntent oldIntent, TouchIntent newIntent) override
    {
        currentIntent = newIntent;
        onIntentChange(newIntent);
        repaint();
    }

    void onTouchMove(int id, juce::Point<float> position, TouchIntent intent) override
    {
        currentIntent = intent;
        filteredPosition = position;
    }

    // Override for custom intent handling
    virtual void onIntentChange(TouchIntent newIntent) {}

    SuperIntelligenceTouch touchController;
    AdaptiveDesignTheme theme;
    TouchIntent currentIntent = TouchIntent::Unknown;
    juce::Point<float> filteredPosition;
    float animationPhase = 0.0f;
    float currentScale = 1.0f;
    float tremorLevel = 0.0f;
    bool isActive = false;
};

//==============================================================================
/**
 * @brief Adaptive Radial Control - Intent-aware rotary knob
 */
class AdaptiveRadialControl : public AdaptiveControl
{
public:
    AdaptiveRadialControl(const juce::String& name = "",
                          float minVal = 0.0f, float maxVal = 1.0f)
        : paramName(name), minValue(minVal), maxValue(maxVal)
    {
        value = (minVal + maxVal) * 0.5f;
    }

    float getValue() const { return value; }
    void setValue(float v) { value = juce::jlimit(minValue, maxValue, v); repaint(); }

    std::function<void(float, TouchIntent)> onValueChange;

protected:
    void paintControl(juce::Graphics& g, juce::Rectangle<float> bounds,
                      TouchIntent intent, float animPhase) override
    {
        auto center = bounds.getCentre();
        float radius = juce::jmin(bounds.getWidth(), bounds.getHeight()) * 0.4f;

        // Background circle with glow
        juce::Colour bgColor = theme.backgroundMedium;
        if (isActive)
        {
            auto glowColor = theme.getIntentColor(intent).withAlpha(0.2f);
            g.setGradientFill(juce::ColourGradient(
                glowColor, center.x, center.y,
                juce::Colours::transparentBlack, center.x, center.y + radius * 1.5f,
                true
            ));
            g.fillEllipse(bounds.expanded(radius * 0.3f));
        }

        g.setColour(bgColor);
        g.fillEllipse(center.x - radius, center.y - radius, radius * 2, radius * 2);

        // Arc track
        float arcThickness = radius * 0.15f;
        float startAngle = juce::MathConstants<float>::pi * 1.25f;
        float endAngle = juce::MathConstants<float>::pi * 2.75f;
        float arcRadius = radius * 0.75f;

        juce::Path trackPath;
        trackPath.addCentredArc(center.x, center.y, arcRadius, arcRadius, 0, startAngle, endAngle, true);
        g.setColour(theme.backgroundLight);
        g.strokePath(trackPath, juce::PathStrokeType(arcThickness, juce::PathStrokeType::curved,
                                                      juce::PathStrokeType::rounded));

        // Value arc
        float normalizedValue = (value - minValue) / (maxValue - minValue);
        float valueAngle = startAngle + normalizedValue * (endAngle - startAngle);

        juce::Path valuePath;
        valuePath.addCentredArc(center.x, center.y, arcRadius, arcRadius, 0, startAngle, valueAngle, true);

        auto valueColor = theme.getIntentColor(intent);
        g.setColour(valueColor);
        g.strokePath(valuePath, juce::PathStrokeType(arcThickness, juce::PathStrokeType::curved,
                                                      juce::PathStrokeType::rounded));

        // Center dot with pulse animation
        float dotRadius = radius * 0.2f;
        if (isActive)
        {
            float pulseScale = 1.0f + 0.1f * std::sin(animPhase * juce::MathConstants<float>::twoPi);
            dotRadius *= pulseScale;
        }

        g.setColour(theme.backgroundLight);
        g.fillEllipse(center.x - dotRadius, center.y - dotRadius, dotRadius * 2, dotRadius * 2);

        // Pointer
        float pointerLength = radius * 0.35f;
        float px = center.x + std::sin(valueAngle) * pointerLength;
        float py = center.y - std::cos(valueAngle) * pointerLength;
        g.setColour(juce::Colours::white);
        g.drawLine(center.x, center.y, px, py, 3.0f);

        // Parameter name
        g.setColour(theme.textSecondary);
        g.setFont(11.0f);
        g.drawText(paramName, bounds.removeFromBottom(20), juce::Justification::centred);

        // Value display
        g.setColour(isActive ? valueColor : theme.textPrimary);
        g.setFont(14.0f);
        g.drawText(juce::String(value, 2), bounds.removeFromBottom(20), juce::Justification::centred);

        // Intent label (when active)
        if (isActive && intent != TouchIntent::Unknown)
        {
            g.setColour(valueColor.withAlpha(0.9f));
            g.setFont(10.0f);
            juce::String intentLabel;
            switch (intent)
            {
                case TouchIntent::FineAdjust: intentLabel = "FINE"; break;
                case TouchIntent::FastMorph: intentLabel = "MORPH"; break;
                case TouchIntent::Hold: intentLabel = "HOLD"; break;
                default: break;
            }
            g.drawText(intentLabel, bounds.removeFromTop(15), juce::Justification::centred);
        }
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        AdaptiveControl::mouseDrag(e);

        // Calculate value from drag
        float sensitivity = 0.005f;
        auto& settings = TouchSettingsManager::getInstance().getSettings();

        switch (currentIntent)
        {
            case TouchIntent::FineAdjust:
                sensitivity = 0.001f * settings.fineAdjustSensitivity;
                break;
            case TouchIntent::FastMorph:
                sensitivity = 0.01f * settings.fastMorphSensitivity;
                break;
            default:
                break;
        }

        float delta = (dragStartY - filteredPosition.y) * sensitivity * (maxValue - minValue);
        float newValue = juce::jlimit(minValue, maxValue, dragStartValue + delta);

        if (std::abs(newValue - value) > 0.0001f)
        {
            value = newValue;
            if (onValueChange)
                onValueChange(value, currentIntent);
            repaint();
        }
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        AdaptiveControl::mouseDown(e);
        dragStartY = e.position.y;
        dragStartValue = value;
    }

private:
    juce::String paramName;
    float minValue, maxValue;
    float value;
    float dragStartY = 0.0f;
    float dragStartValue = 0.0f;
};

//==============================================================================
/**
 * @brief Adaptive XY Morph Pad - 2D control with flow visualization
 */
class AdaptiveMorphPad : public AdaptiveControl
{
public:
    AdaptiveMorphPad()
    {
        trailPoints.reserve(50);
    }

    std::function<void(float x, float y, TouchIntent intent)> onValueChange;

    float getX() const { return valueX; }
    float getY() const { return valueY; }

    void setValues(float x, float y)
    {
        valueX = juce::jlimit(0.0f, 1.0f, x);
        valueY = juce::jlimit(0.0f, 1.0f, y);
        repaint();
    }

protected:
    void paintControl(juce::Graphics& g, juce::Rectangle<float> bounds,
                      TouchIntent intent, float animPhase) override
    {
        // Background
        g.setColour(theme.backgroundMedium);
        g.fillRoundedRectangle(bounds, 12.0f);

        // Grid
        g.setColour(theme.backgroundLight.withAlpha(0.5f));
        for (int i = 1; i < 4; ++i)
        {
            float x = bounds.getX() + bounds.getWidth() * i / 4.0f;
            float y = bounds.getY() + bounds.getHeight() * i / 4.0f;
            g.drawVerticalLine(static_cast<int>(x), bounds.getY(), bounds.getBottom());
            g.drawHorizontalLine(static_cast<int>(y), bounds.getX(), bounds.getRight());
        }

        // Draw trail (MORPH mode visualization)
        if (trailPoints.size() > 1)
        {
            juce::Path trailPath;
            trailPath.startNewSubPath(trailPoints[0]);

            for (size_t i = 1; i < trailPoints.size(); ++i)
            {
                trailPath.lineTo(trailPoints[i]);
            }

            float alpha = (intent == TouchIntent::FastMorph) ? 0.6f : 0.3f;
            g.setColour(theme.getIntentColor(intent).withAlpha(alpha));
            g.strokePath(trailPath, juce::PathStrokeType(3.0f, juce::PathStrokeType::curved,
                                                          juce::PathStrokeType::rounded));
        }

        // Current position
        float posX = bounds.getX() + valueX * bounds.getWidth();
        float posY = bounds.getBottom() - valueY * bounds.getHeight();

        // Crosshairs
        g.setColour(theme.getIntentColor(intent).withAlpha(0.4f));
        g.drawVerticalLine(static_cast<int>(posX), bounds.getY(), bounds.getBottom());
        g.drawHorizontalLine(static_cast<int>(posY), bounds.getX(), bounds.getRight());

        // Cursor with size based on intent
        float cursorSize = (intent == TouchIntent::FineAdjust) ? 24.0f : 16.0f;
        if (isActive)
        {
            cursorSize *= 1.0f + 0.1f * std::sin(animPhase * juce::MathConstants<float>::twoPi);
        }

        // Outer glow
        if (isActive)
        {
            g.setColour(theme.getIntentColor(intent).withAlpha(0.3f));
            g.fillEllipse(posX - cursorSize, posY - cursorSize, cursorSize * 2, cursorSize * 2);
        }

        // Cursor
        g.setColour(theme.getIntentColor(intent));
        g.fillEllipse(posX - cursorSize/2, posY - cursorSize/2, cursorSize, cursorSize);
        g.setColour(juce::Colours::white);
        g.drawEllipse(posX - cursorSize/2, posY - cursorSize/2, cursorSize, cursorSize, 2.0f);

        // Labels
        g.setColour(theme.textSecondary);
        g.setFont(10.0f);
        g.drawText("X: " + juce::String(valueX, 2), bounds.removeFromBottom(15), juce::Justification::centredLeft);
        g.drawText("Y: " + juce::String(valueY, 2), bounds.removeFromBottom(15), juce::Justification::centredRight);

        // Intent indicator
        if (isActive)
        {
            g.setColour(theme.getIntentColor(intent));
            g.setFont(12.0f);
            juce::String label;
            switch (intent)
            {
                case TouchIntent::FineAdjust: label = "FINE CONTROL"; break;
                case TouchIntent::FastMorph: label = "MORPHING"; break;
                case TouchIntent::Swipe: label = "SWIPE"; break;
                default: break;
            }
            g.drawText(label, bounds.removeFromTop(20), juce::Justification::centred);
        }
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        AdaptiveControl::mouseDrag(e);

        auto bounds = getLocalBounds().toFloat();
        valueX = juce::jlimit(0.0f, 1.0f, filteredPosition.x / bounds.getWidth());
        valueY = juce::jlimit(0.0f, 1.0f, 1.0f - filteredPosition.y / bounds.getHeight());

        // Add to trail
        float posX = bounds.getX() + valueX * bounds.getWidth();
        float posY = bounds.getBottom() - valueY * bounds.getHeight();
        trailPoints.push_back({ posX, posY });

        if (trailPoints.size() > 50)
            trailPoints.erase(trailPoints.begin());

        if (onValueChange)
            onValueChange(valueX, valueY, currentIntent);

        repaint();
    }

    void mouseUp(const juce::MouseEvent& e) override
    {
        AdaptiveControl::mouseUp(e);

        // Fade out trail
        trailPoints.clear();
        repaint();
    }

private:
    float valueX = 0.5f;
    float valueY = 0.5f;
    std::vector<juce::Point<float>> trailPoints;
};

//==============================================================================
/**
 * @brief Adaptive Button Strip - Touch-aware button row
 */
class AdaptiveButtonStrip : public AdaptiveControl
{
public:
    AdaptiveButtonStrip(int numButtons = 4)
    {
        buttons.resize(numButtons);
        for (int i = 0; i < numButtons; ++i)
        {
            buttons[i] = { "Button " + juce::String(i + 1), false };
        }
    }

    void setButtonLabel(int index, const juce::String& label)
    {
        if (index >= 0 && index < static_cast<int>(buttons.size()))
        {
            buttons[index].label = label;
            repaint();
        }
    }

    void setButtonState(int index, bool state)
    {
        if (index >= 0 && index < static_cast<int>(buttons.size()))
        {
            buttons[index].isActive = state;
            repaint();
        }
    }

    std::function<void(int index, bool state)> onButtonChange;

protected:
    void paintControl(juce::Graphics& g, juce::Rectangle<float> bounds,
                      TouchIntent intent, float animPhase) override
    {
        int numButtons = static_cast<int>(buttons.size());
        float buttonWidth = bounds.getWidth() / numButtons;
        float padding = 4.0f;

        for (int i = 0; i < numButtons; ++i)
        {
            auto& btn = buttons[i];
            auto btnBounds = juce::Rectangle<float>(
                bounds.getX() + i * buttonWidth + padding,
                bounds.getY() + padding,
                buttonWidth - padding * 2,
                bounds.getHeight() - padding * 2
            );

            // Button background
            juce::Colour btnColor = btn.isActive
                ? theme.getIntentColor(TouchIntent::Hold)
                : theme.backgroundLight;

            if (i == hoveredButton && isActive)
            {
                btnColor = theme.getIntentColor(intent);
            }

            g.setColour(btnColor);
            g.fillRoundedRectangle(btnBounds, 8.0f);

            // Button border
            g.setColour(btn.isActive ? juce::Colours::white : theme.neutralSecondary);
            g.drawRoundedRectangle(btnBounds, 8.0f, 1.5f);

            // Button label
            g.setColour(btn.isActive ? juce::Colours::black : theme.textPrimary);
            g.setFont(12.0f);
            g.drawText(btn.label, btnBounds, juce::Justification::centred);
        }
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        AdaptiveControl::mouseDrag(e);
        updateHoveredButton(filteredPosition);
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        AdaptiveControl::mouseDown(e);
        updateHoveredButton(e.position);
    }

    void mouseUp(const juce::MouseEvent& e) override
    {
        if (hoveredButton >= 0 && hoveredButton < static_cast<int>(buttons.size()))
        {
            buttons[hoveredButton].isActive = !buttons[hoveredButton].isActive;
            if (onButtonChange)
                onButtonChange(hoveredButton, buttons[hoveredButton].isActive);
        }

        hoveredButton = -1;
        AdaptiveControl::mouseUp(e);
    }

private:
    void updateHoveredButton(juce::Point<float> pos)
    {
        auto bounds = getLocalBounds().toFloat();
        float buttonWidth = bounds.getWidth() / buttons.size();

        int newHovered = static_cast<int>((pos.x - bounds.getX()) / buttonWidth);
        if (newHovered < 0 || newHovered >= static_cast<int>(buttons.size()))
            newHovered = -1;

        if (newHovered != hoveredButton)
        {
            hoveredButton = newHovered;
            repaint();
        }
    }

    struct Button
    {
        juce::String label;
        bool isActive = false;
    };

    std::vector<Button> buttons;
    int hoveredButton = -1;
};

} // namespace Touch
} // namespace Echoel
