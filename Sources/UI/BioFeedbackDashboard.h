#pragma once

#include <JuceHeader.h>
#include "../BioData/BioReactiveModulator.h"
#include <vector>
#include <deque>

//==============================================================================
/**
 * @brief Bio-Feedback Dashboard - Prominent HRV Display
 *
 * Real-time display of bio-feedback metrics:
 * - Heart Rate (BPM)
 * - HRV (Heart Rate Variability)
 * - SDNN, RMSSD (HRV metrics)
 * - Coherence Score
 * - Stress Index
 * - Real-time graph
 *
 * Design für: Kreativ + Gesund + Mobil + Biofeedback
 * **Bio-Feedback ist ZENTRAL für die Niche!**
 */
class BioFeedbackDashboard : public juce::Component,
                             public juce::Timer
{
public:
    //==============================================================================
    BioFeedbackDashboard()
    {
        bioFeedbackSystem = std::make_unique<BioFeedbackSystem>();

        // Initialize history buffer
        heartRateHistory.resize(300, 70.0f);  // 10 seconds at 30 FPS
        hrvHistory.resize(300, 0.5f);
        coherenceHistory.resize(300, 0.5f);

        startTimerHz(30);  // 30 FPS updates
    }

    ~BioFeedbackDashboard() override
    {
        stopTimer();
    }

    //==============================================================================
    void paint(juce::Graphics& g) override
    {
        // Background
        g.fillAll(juce::Colour(0xff0a0a0a));

        auto bounds = getLocalBounds().reduced(10);

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(24.0f);
        g.drawText("Bio-Feedback Dashboard 🫀", bounds.removeFromTop(40),
                  juce::Justification::centred);

        bounds.removeFromTop(10);

        // Split into metrics (left) and graph (right)
        int metricsWidth = bounds.getWidth() / 3;
        auto metricsArea = bounds.removeFromLeft(metricsWidth);
        bounds.removeFromLeft(10);
        auto graphArea = bounds;

        // Draw metrics cards
        drawMetricsCards(g, metricsArea);

        // Draw graph
        drawRealTimeGraph(g, graphArea);
    }

    void resized() override
    {
        // Nothing to layout (all custom painting)
    }

    //==============================================================================
    void timerCallback() override
    {
        // Update bio-feedback system
        if (bioFeedbackSystem)
            bioFeedbackSystem->update();

        // Get current bio-data
        auto bioData = bioFeedbackSystem->getCurrentBioData();

        // Update history buffers
        heartRateHistory.push_back(bioData.heartRate);
        if (heartRateHistory.size() > 300)
            heartRateHistory.pop_front();

        hrvHistory.push_back(bioData.hrv);
        if (hrvHistory.size() > 300)
            hrvHistory.pop_front();

        coherenceHistory.push_back(bioData.coherence);
        if (coherenceHistory.size() > 300)
            coherenceHistory.pop_front();

        // Get modulated parameters
        modulatedParams = bioFeedbackSystem->getModulatedParameters();

        repaint();
    }

    //==============================================================================
    // Get modulated parameters (for audio processing)
    const BioReactiveModulator::ModulatedParameters& getModulatedParameters() const
    {
        return modulatedParams;
    }

    // Get bio-data sample
    BioDataInput::BioDataSample getCurrentBioData() const
    {
        return bioFeedbackSystem->getCurrentBioData();
    }

private:
    //==============================================================================
    void drawMetricsCards(juce::Graphics& g, juce::Rectangle<int> area)
    {
        auto bioData = bioFeedbackSystem->getCurrentBioData();

        int cardHeight = area.getHeight() / 4;  // 4 cards

        // HEART RATE
        auto hrCard = area.removeFromTop(cardHeight).reduced(5);
        drawMetricCard(g, hrCard, "Heart Rate", juce::String(bioData.heartRate, 1) + " BPM",
                      getHeartRateColor(bioData.heartRate), true);

        // HRV
        auto hrvCard = area.removeFromTop(cardHeight).reduced(5);
        juce::String hrvText = juce::String(bioData.hrv * 100.0f, 0) + "%";
        drawMetricCard(g, hrvCard, "HRV", hrvText,
                      getHRVColor(bioData.hrv), false);

        // COHERENCE
        auto coherenceCard = area.removeFromTop(cardHeight).reduced(5);
        juce::String coherenceText = juce::String(bioData.coherence * 100.0f, 0) + "%";
        drawMetricCard(g, coherenceCard, "Coherence", coherenceText,
                      getCoherenceColor(bioData.coherence), false);

        // STRESS INDEX
        auto stressCard = area.removeFromTop(cardHeight).reduced(5);
        juce::String stressText = juce::String(bioData.stressIndex * 100.0f, 0) + "%";
        drawMetricCard(g, stressCard, "Stress Index", stressText,
                      getStressColor(bioData.stressIndex), false);
    }

    void drawMetricCard(juce::Graphics& g, juce::Rectangle<int> area,
                       const juce::String& label, const juce::String& value,
                       juce::Colour color, bool isLarge)
    {
        // Card background
        g.setColour(juce::Colour(0xff1a1a1a));
        g.fillRoundedRectangle(area.toFloat(), 8.0f);

        // Border
        g.setColour(color.withAlpha(0.5f));
        g.drawRoundedRectangle(area.toFloat(), 8.0f, 2.0f);

        // Label
        g.setColour(juce::Colours::white.withAlpha(0.7f));
        g.setFont(12.0f);
        g.drawText(label, area.removeFromTop(20), juce::Justification::centred);

        // Value
        g.setColour(color);
        g.setFont(juce::Font(isLarge ? 32.0f : 24.0f, juce::Font::bold));
        g.drawText(value, area, juce::Justification::centred);
    }

    //==============================================================================
    void drawRealTimeGraph(juce::Graphics& g, juce::Rectangle<int> area)
    {
        // Graph background
        g.setColour(juce::Colour(0xff1a1a1a));
        g.fillRoundedRectangle(area.toFloat(), 8.0f);

        // Border
        g.setColour(juce::Colours::grey.withAlpha(0.3f));
        g.drawRoundedRectangle(area.toFloat(), 8.0f, 2.0f);

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(16.0f);
        g.drawText("Real-Time Monitoring (10 seconds)", area.removeFromTop(30),
                  juce::Justification::centred);

        area.reduce(20, 20);

        // Draw grid
        g.setColour(juce::Colours::grey.withAlpha(0.1f));
        for (int i = 1; i < 10; ++i)
        {
            float y = area.getY() + (area.getHeight() * i / 10.0f);
            g.drawLine(area.getX(), y, area.getRight(), y, 1.0f);
        }

        // Split into 3 sub-graphs
        int graphHeight = area.getHeight() / 3;

        auto hrArea = area.removeFromTop(graphHeight).reduced(0, 5);
        auto hrvArea = area.removeFromTop(graphHeight).reduced(0, 5);
        auto coherenceArea = area.reduced(0, 5);

        // Draw graphs
        drawLineGraph(g, hrArea, heartRateHistory, 40.0f, 140.0f,
                     juce::Colours::red, "Heart Rate (BPM)");
        drawLineGraph(g, hrvArea, hrvHistory, 0.0f, 1.0f,
                     juce::Colours::green, "HRV (0-1)");
        drawLineGraph(g, coherenceArea, coherenceHistory, 0.0f, 1.0f,
                     juce::Colours::cyan, "Coherence (0-1)");
    }

    void drawLineGraph(juce::Graphics& g, juce::Rectangle<int> area,
                      const std::deque<float>& data,
                      float minValue, float maxValue,
                      juce::Colour color, const juce::String& title)
    {
        // Title
        g.setColour(juce::Colours::white.withAlpha(0.7f));
        g.setFont(12.0f);
        g.drawText(title, area.removeFromTop(15), juce::Justification::topLeft);

        if (data.empty())
            return;

        // Draw line
        juce::Path path;
        bool firstPoint = true;

        float xStep = static_cast<float>(area.getWidth()) / static_cast<float>(data.size());

        for (size_t i = 0; i < data.size(); ++i)
        {
            float value = data[i];
            float normalizedValue = (value - minValue) / (maxValue - minValue);
            normalizedValue = juce::jlimit(0.0f, 1.0f, normalizedValue);

            float x = area.getX() + i * xStep;
            float y = area.getBottom() - (normalizedValue * area.getHeight());

            if (firstPoint)
            {
                path.startNewSubPath(x, y);
                firstPoint = false;
            }
            else
            {
                path.lineTo(x, y);
            }
        }

        // Draw path
        g.setColour(color.withAlpha(0.3f));
        g.strokePath(path, juce::PathStrokeType(3.0f));

        g.setColour(color);
        g.strokePath(path, juce::PathStrokeType(2.0f));
    }

    //==============================================================================
    // Color coding for metrics
    juce::Colour getHeartRateColor(float bpm) const
    {
        if (bpm < 60.0f || bpm > 100.0f)
            return juce::Colours::red;        // Outside normal resting range
        else if (bpm < 70.0f || bpm > 90.0f)
            return juce::Colours::orange;     // Slightly off
        else
            return juce::Colours::green;      // Normal
    }

    juce::Colour getHRVColor(float hrv) const
    {
        if (hrv < 0.3f)
            return juce::Colours::red;        // Low HRV (stressed)
        else if (hrv < 0.5f)
            return juce::Colours::orange;     // Moderate
        else
            return juce::Colours::green;      // High HRV (good)
    }

    juce::Colour getCoherenceColor(float coherence) const
    {
        if (coherence < 0.3f)
            return juce::Colours::red;        // Low coherence
        else if (coherence < 0.6f)
            return juce::Colours::orange;     // Moderate
        else
            return juce::Colours::green;      // High coherence (good)
    }

    juce::Colour getStressColor(float stressIndex) const
    {
        if (stressIndex > 0.7f)
            return juce::Colours::red;        // High stress
        else if (stressIndex > 0.4f)
            return juce::Colours::orange;     // Moderate stress
        else
            return juce::Colours::green;      // Low stress (good)
    }

    //==============================================================================
    std::unique_ptr<BioFeedbackSystem> bioFeedbackSystem;

    // History buffers (10 seconds at 30 FPS = 300 samples)
    std::deque<float> heartRateHistory;
    std::deque<float> hrvHistory;
    std::deque<float> coherenceHistory;

    // Modulated parameters
    BioReactiveModulator::ModulatedParameters modulatedParams;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BioFeedbackDashboard)
};
