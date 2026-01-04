/*
  ==============================================================================

    CoherencePanel.h
    Bio-Reactive Coherence Visualization

    Real-time display of HRV coherence and bio-metrics from Apple Watch.
    Adapts UI colors and complexity based on user's physiological state.

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <cmath>

namespace Echoelmusic {
namespace GUI {

//==============================================================================
// Coherence Ring
//==============================================================================

class CoherenceRing : public juce::Component,
                      public juce::Timer
{
public:
    CoherenceRing()
    {
        startTimerHz(30);  // 30fps animation
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(4);
        auto centre = bounds.getCentre();
        auto radius = std::min(bounds.getWidth(), bounds.getHeight()) / 2.0f - 8.0f;

        // Background ring
        g.setColour(juce::Colour(0xFF2A2A3A));
        g.drawEllipse(centre.x - radius, centre.y - radius,
                     radius * 2, radius * 2, 6.0f);

        // Coherence arc
        juce::Path arc;
        float startAngle = -juce::MathConstants<float>::halfPi;
        float endAngle = startAngle + displayedCoherence * juce::MathConstants<float>::twoPi;

        arc.addCentredArc(centre.x, centre.y, radius, radius,
                         0.0f, startAngle, endAngle, true);

        g.setColour(getCoherenceColor(displayedCoherence));
        g.strokePath(arc, juce::PathStrokeType(6.0f, juce::PathStrokeType::curved,
                                               juce::PathStrokeType::rounded));

        // Pulsing glow effect
        if (displayedCoherence > 0.5f)
        {
            float pulseIntensity = (std::sin(pulsePhase) + 1.0f) / 2.0f;
            auto glowColor = getCoherenceColor(displayedCoherence).withAlpha(0.3f * pulseIntensity);
            g.setColour(glowColor);
            g.strokePath(arc, juce::PathStrokeType(12.0f, juce::PathStrokeType::curved,
                                                   juce::PathStrokeType::rounded));
        }

        // Center text
        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(28.0f, juce::Font::bold));
        g.drawText(juce::String(static_cast<int>(displayedCoherence * 100)) + "%",
                  bounds, juce::Justification::centred);
    }

    void timerCallback() override
    {
        // Animate coherence smoothly
        float diff = targetCoherence - displayedCoherence;
        displayedCoherence += diff * 0.1f;

        // Pulse animation
        pulsePhase += 0.1f;
        if (pulsePhase > juce::MathConstants<float>::twoPi)
            pulsePhase -= juce::MathConstants<float>::twoPi;

        repaint();
    }

    void setCoherence(float coherence)
    {
        targetCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    }

private:
    juce::Colour getCoherenceColor(float coherence)
    {
        if (coherence > 0.7f)
            return juce::Colour(0xFF4ADE80);  // Green
        else if (coherence > 0.4f)
            return juce::Colour(0xFFFBBF24);  // Yellow
        else
            return juce::Colour(0xFFF87171);  // Red
    }

    float targetCoherence = 0.5f;
    float displayedCoherence = 0.5f;
    float pulsePhase = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CoherenceRing)
};

//==============================================================================
// Heart Rate Display
//==============================================================================

class HeartRateDisplay : public juce::Component,
                         public juce::Timer
{
public:
    HeartRateDisplay()
    {
        startTimerHz(2);  // Pulse animation
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Heart icon with pulse
        float scale = 1.0f + pulseAmount * 0.1f;
        auto heartBounds = bounds.removeFromLeft(30).reduced(5);

        juce::Path heart;
        float cx = heartBounds.getCentreX();
        float cy = heartBounds.getCentreY();
        float size = heartBounds.getWidth() * 0.4f * scale;

        // Draw heart shape
        heart.startNewSubPath(cx, cy + size * 0.6f);
        heart.cubicTo(cx - size * 1.5f, cy - size * 0.2f,
                     cx - size * 0.8f, cy - size * 1.2f,
                     cx, cy - size * 0.4f);
        heart.cubicTo(cx + size * 0.8f, cy - size * 1.2f,
                     cx + size * 1.5f, cy - size * 0.2f,
                     cx, cy + size * 0.6f);
        heart.closeSubPath();

        g.setColour(juce::Colour(0xFFFF6B6B));
        g.fillPath(heart);

        // BPM text
        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(16.0f, juce::Font::bold));
        g.drawText(juce::String(static_cast<int>(heartRate)) + " BPM",
                  bounds.reduced(5, 0), juce::Justification::centredLeft);
    }

    void timerCallback() override
    {
        // Pulse animation based on heart rate
        float bps = heartRate / 60.0f;
        pulseAmount = std::sin(juce::Time::getMillisecondCounterHiRes() * 0.001f * bps * juce::MathConstants<float>::twoPi);
        pulseAmount = std::max(0.0f, pulseAmount);
        repaint();
    }

    void setHeartRate(float bpm)
    {
        heartRate = bpm;
    }

private:
    float heartRate = 72.0f;
    float pulseAmount = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HeartRateDisplay)
};

//==============================================================================
// HRV Display
//==============================================================================

class HRVDisplay : public juce::Component
{
public:
    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(5);

        // Label
        g.setColour(juce::Colour(0xFFB8B8C8));
        g.setFont(juce::Font(11.0f));
        g.drawText("HRV", bounds.removeFromTop(14), juce::Justification::centredLeft);

        // Value
        g.setColour(juce::Colours::white);
        g.setFont(juce::Font(16.0f, juce::Font::bold));
        g.drawText(juce::String(static_cast<int>(hrv)) + " ms",
                  bounds, juce::Justification::centredLeft);
    }

    void setHRV(float value)
    {
        hrv = value;
        repaint();
    }

private:
    float hrv = 45.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HRVDisplay)
};

//==============================================================================
// Flow State Indicator
//==============================================================================

class FlowStateIndicator : public juce::Component
{
public:
    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat().reduced(5);

        // Background
        g.setColour(isInFlow ? juce::Colour(0xFF4ADE80).withAlpha(0.2f)
                            : juce::Colour(0xFF2A2A3A));
        g.fillRoundedRectangle(bounds, 6.0f);

        // Icon and text
        g.setColour(isInFlow ? juce::Colour(0xFF4ADE80) : juce::Colour(0xFF6B6B7B));
        g.setFont(juce::Font(12.0f, juce::Font::bold));

        juce::String text = isInFlow ? "IN FLOW" : "FLOW";
        g.drawText(text, bounds, juce::Justification::centred);
    }

    void setInFlow(bool flow)
    {
        if (isInFlow != flow)
        {
            isInFlow = flow;
            repaint();
        }
    }

private:
    bool isInFlow = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(FlowStateIndicator)
};

//==============================================================================
// Coherence Panel
//==============================================================================

class CoherencePanel : public juce::Component
{
public:
    CoherencePanel()
    {
        addAndMakeVisible(coherenceRing);
        addAndMakeVisible(heartRateDisplay);
        addAndMakeVisible(hrvDisplay);
        addAndMakeVisible(flowIndicator);

        // Title
        titleLabel.setText("COHERENCE", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(10.0f, juce::Font::bold));
        titleLabel.setColour(juce::Label::textColourId, juce::Colour(0xFF6B6B7B));
        titleLabel.setJustificationType(juce::Justification::centred);
        addAndMakeVisible(titleLabel);
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(juce::Colour(0xFF1A1A24));

        // Left border
        g.setColour(juce::Colour(0xFF2A2A3A));
        g.drawLine(0, 0, 0, static_cast<float>(getHeight()), 1.0f);
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10, 5);

        // Title at top
        titleLabel.setBounds(bounds.removeFromLeft(80));

        // Coherence ring
        auto ringBounds = bounds.removeFromLeft(50);
        coherenceRing.setBounds(ringBounds);

        bounds.removeFromLeft(10);

        // Bio metrics
        auto metricsArea = bounds;
        heartRateDisplay.setBounds(metricsArea.removeFromTop(25));
        hrvDisplay.setBounds(metricsArea.removeFromTop(35));
        flowIndicator.setBounds(metricsArea.removeFromTop(25).reduced(0, 2));
    }

    void setCoherence(float coherence)
    {
        coherenceRing.setCoherence(coherence);
        flowIndicator.setInFlow(coherence > 0.7f);
    }

    void setHeartRate(float bpm)
    {
        heartRateDisplay.setHeartRate(bpm);
    }

    void setHRV(float ms)
    {
        hrvDisplay.setHRV(ms);
    }

private:
    juce::Label titleLabel;
    CoherenceRing coherenceRing;
    HeartRateDisplay heartRateDisplay;
    HRVDisplay hrvDisplay;
    FlowStateIndicator flowIndicator;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CoherencePanel)
};

} // namespace GUI
} // namespace Echoelmusic
