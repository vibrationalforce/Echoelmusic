#pragma once

#include <JuceHeader.h>
#include "../BioData/HRVProcessor.h"
#include "../BioData/BioReactiveModulator.h"

//==============================================================================
/**
 * @brief Bio-Data Visualizer
 *
 * Real-time visualization of:
 * - Heart rate (BPM)
 * - HRV (Heart Rate Variability)
 * - Coherence score
 * - Stress index
 * - Heart rate history graph
 * - Breathing guide (coherence training)
 */
class BioDataVisualizer : public juce::Component,
                          private juce::Timer
{
public:
    BioDataVisualizer()
    {
        hrHistory.resize(historySize, 70.0f);
        startTimerHz(30);  // 30 FPS
    }

    void updateBioData(const BioDataInput::BioDataSample& sample)
    {
        if (!sample.isValid)
            return;

        currentSample = sample;

        // Add to history
        hrHistory[historyIndex] = sample.heartRate;
        historyIndex = (historyIndex + 1) % historySize;
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff0a0a0f));

        // Layout
        auto topSection = bounds.removeFromTop(bounds.getHeight() * 0.6f);
        auto bottomSection = bounds;

        // Draw metrics cards
        drawMetricsCards(g, topSection);

        // Draw heart rate history
        drawHeartRateHistory(g, bottomSection);
    }

private:
    void timerCallback() override
    {
        repaint();
    }

    //==============================================================================
    void drawMetricsCards(juce::Graphics& g, juce::Rectangle<float> area)
    {
        const int numCards = 4;
        float cardWidth = area.getWidth() / numCards;

        // Heart Rate Card
        auto hrCard = area.removeFromLeft(cardWidth).reduced(10);
        drawMetricCard(g, hrCard, "HEART RATE",
                      juce::String(static_cast<int>(currentSample.heartRate)) + " BPM",
                      juce::Colour(0xffff4444), currentSample.heartRate / 100.0f);

        // HRV Card
        auto hrvCard = area.removeFromLeft(cardWidth).reduced(10);
        drawMetricCard(g, hrvCard, "HRV",
                      juce::String(static_cast<int>(currentSample.hrv * 100)) + "%",
                      juce::Colour(0xff00d4ff), currentSample.hrv);

        // Coherence Card
        auto cohCard = area.removeFromLeft(cardWidth).reduced(10);
        juce::String cohLevel = getCoherenceLevel(currentSample.coherence);
        juce::Colour cohColor = getCoherenceColor(currentSample.coherence);
        drawMetricCard(g, cohCard, "COHERENCE", cohLevel, cohColor, currentSample.coherence);

        // Stress Card
        auto stressCard = area.removeFromLeft(cardWidth).reduced(10);
        juce::String stressLevel = getStressLevel(currentSample.stressIndex);
        juce::Colour stressColor = getStressColor(currentSample.stressIndex);
        drawMetricCard(g, stressCard, "STRESS", stressLevel, stressColor, 1.0f - currentSample.stressIndex);
    }

    //==============================================================================
    void drawMetricCard(juce::Graphics& g, juce::Rectangle<float> bounds,
                       const juce::String& title, const juce::String& value,
                       juce::Colour color, float normalizedValue)
    {
        // Card background
        g.setColour(juce::Colour(0xff1a1a2f).withAlpha(0.5f));
        g.fillRoundedRectangle(bounds, 8.0f);

        // Border
        g.setColour(color.withAlpha(0.3f));
        g.drawRoundedRectangle(bounds, 8.0f, 2.0f);

        // Title
        g.setColour(juce::Colours::white.withAlpha(0.7f));
        g.setFont(12.0f);
        g.drawText(title, bounds.removeFromTop(30), juce::Justification::centred);

        // Value
        g.setColour(color);
        g.setFont(juce::Font(28.0f, juce::Font::bold));
        g.drawText(value, bounds.removeFromTop(50), juce::Justification::centred);

        // Progress bar
        auto barBounds = bounds.removeFromBottom(20).reduced(10, 5);
        g.setColour(juce::Colour(0xff2a2a3f));
        g.fillRoundedRectangle(barBounds, 4.0f);

        auto fillBounds = barBounds.withWidth(barBounds.getWidth() * normalizedValue);
        g.setColour(color);
        g.fillRoundedRectangle(fillBounds, 4.0f);
    }

    //==============================================================================
    void drawHeartRateHistory(juce::Graphics& g, juce::Rectangle<float> bounds)
    {
        bounds = bounds.reduced(20);

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(14.0f);
        g.drawText("HEART RATE HISTORY", bounds.removeFromTop(25), juce::Justification::centredLeft);

        // Background
        g.setColour(juce::Colour(0xff1a1a2f).withAlpha(0.3f));
        g.fillRoundedRectangle(bounds, 8.0f);

        // Grid lines
        g.setColour(juce::Colour(0xff2a2a4f).withAlpha(0.5f));
        for (int i = 1; i < 4; ++i)
        {
            float y = bounds.getY() + (bounds.getHeight() * i / 4.0f);
            g.drawHorizontalLine(static_cast<int>(y), bounds.getX(), bounds.getRight());
        }

        // Heart rate range (40-120 BPM)
        const float minHR = 40.0f;
        const float maxHR = 120.0f;

        // Draw history graph
        juce::Path historyPath;
        bool firstPoint = true;

        for (int i = 0; i < historySize; ++i)
        {
            int dataIndex = (historyIndex + i) % historySize;
            float hr = hrHistory[dataIndex];

            float x = bounds.getX() + (i * bounds.getWidth() / historySize);
            float normalizedHR = (hr - minHR) / (maxHR - minHR);
            float y = bounds.getBottom() - (normalizedHR * bounds.getHeight());
            y = juce::jlimit(bounds.getY(), bounds.getBottom(), y);

            if (firstPoint)
            {
                historyPath.startNewSubPath(x, y);
                firstPoint = false;
            }
            else
            {
                historyPath.lineTo(x, y);
            }
        }

        // Gradient stroke
        juce::ColourGradient gradient(
            juce::Colour(0xffff4444), bounds.getX(), bounds.getCentreY(),
            juce::Colour(0xffff8844), bounds.getRight(), bounds.getCentreY(),
            false
        );
        g.setGradientFill(gradient);
        g.strokePath(historyPath, juce::PathStrokeType(3.0f));

        // Glow
        g.setOpacity(0.3f);
        g.strokePath(historyPath, juce::PathStrokeType(6.0f));

        // Labels
        g.setOpacity(1.0f);
        g.setColour(juce::Colours::white.withAlpha(0.5f));
        g.setFont(10.0f);
        g.drawText(juce::String(static_cast<int>(maxHR)), bounds.getX() - 35, bounds.getY() - 5, 30, 15,
                  juce::Justification::right);
        g.drawText(juce::String(static_cast<int>(minHR)), bounds.getX() - 35, bounds.getBottom() - 10, 30, 15,
                  juce::Justification::right);
    }

    //==============================================================================
    juce::String getCoherenceLevel(float coherence) const
    {
        if (coherence < 0.3f) return "Low";
        if (coherence < 0.5f) return "Medium";
        if (coherence < 0.7f) return "Good";
        if (coherence < 0.85f) return "High";
        return "Excellent";
    }

    juce::Colour getCoherenceColor(float coherence) const
    {
        if (coherence < 0.3f) return juce::Colour(0xffff4444);  // Red
        if (coherence < 0.5f) return juce::Colour(0xffffaa00);  // Orange
        if (coherence < 0.7f) return juce::Colour(0xffffff00);  // Yellow
        if (coherence < 0.85f) return juce::Colour(0xff88ff44); // Light green
        return juce::Colour(0xff00ff88);                        // Green
    }

    juce::String getStressLevel(float stress) const
    {
        if (stress < 0.2f) return "Very Low";
        if (stress < 0.4f) return "Low";
        if (stress < 0.6f) return "Moderate";
        if (stress < 0.8f) return "High";
        return "Very High";
    }

    juce::Colour getStressColor(float stress) const
    {
        // Inverse colors (low stress = green, high stress = red)
        if (stress < 0.2f) return juce::Colour(0xff00ff88);
        if (stress < 0.4f) return juce::Colour(0xff88ff44);
        if (stress < 0.6f) return juce::Colour(0xffffff00);
        if (stress < 0.8f) return juce::Colour(0xffffaa00);
        return juce::Colour(0xffff4444);
    }

    //==============================================================================
    static constexpr int historySize = 120;  // 2 minutes at 1 sample/second
    std::vector<float> hrHistory;
    int historyIndex = 0;

    BioDataInput::BioDataSample currentSample;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BioDataVisualizer)
};

//==============================================================================
/**
 * @brief Breathing Pacer (Coherence Training Guide)
 *
 * Visual breathing guide to help users achieve high coherence.
 * Guides user to breathe at optimal rate (~6 breaths/min = 0.1 Hz).
 */
class BreathingPacer : public juce::Component,
                       private juce::Timer
{
public:
    BreathingPacer()
    {
        startTimerHz(60);  // 60 FPS for smooth animation
    }

    void setBreathingRate(float breathsPerMinute)
    {
        // Convert to Hz
        targetRate = breathsPerMinute / 60.0f;
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff0a0a0f));

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(16.0f);
        g.drawText("BREATHING PACER", bounds.removeFromTop(30), juce::Justification::centred);

        // Instruction
        g.setColour(juce::Colours::white.withAlpha(0.7f));
        g.setFont(12.0f);
        juce::String instruction = (breathPhase < 0.5f) ? "Breathe In" : "Breathe Out";
        g.drawText(instruction, bounds.removeFromTop(25), juce::Justification::centred);

        // Pulsing circle
        auto circleBounds = bounds.reduced(50);
        auto centerX = circleBounds.getCentreX();
        auto centerY = circleBounds.getCentreY();

        // Smooth pulse (sine wave)
        float pulse = 0.5f + 0.5f * std::sin(breathPhase * juce::MathConstants<float>::twoPi);
        float radius = 50.0f + (pulse * 100.0f);

        // Gradient fill
        juce::ColourGradient gradient(
            juce::Colour(0xff00d4ff).withAlpha(0.8f), centerX, centerY,
            juce::Colour(0xffaa44ff).withAlpha(0.3f), centerX, centerY + radius,
            true
        );
        g.setGradientFill(gradient);
        g.fillEllipse(centerX - radius, centerY - radius, radius * 2, radius * 2);

        // Glow
        g.setOpacity(0.3f);
        g.fillEllipse(centerX - radius * 1.2f, centerY - radius * 1.2f, radius * 2.4f, radius * 2.4f);

        // Border
        g.setOpacity(1.0f);
        g.setColour(juce::Colour(0xff00d4ff));
        g.drawEllipse(centerX - radius, centerY - radius, radius * 2, radius * 2, 3.0f);
    }

private:
    void timerCallback() override
    {
        // Advance breath phase
        breathPhase += targetRate / 60.0f;  // Normalize to 60 FPS
        if (breathPhase >= 1.0f)
            breathPhase -= 1.0f;

        repaint();
    }

    float targetRate = 0.1f;  // Hz (6 breaths/min)
    float breathPhase = 0.0f;  // 0-1

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BreathingPacer)
};
