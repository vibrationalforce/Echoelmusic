#pragma once

#include <JuceHeader.h>
#include "ResponsiveLayout.h"
#include "ModernLookAndFeel.h"
#include "UIComponents.h"
#include "../DSP/PhaseAnalyzer.h"

//==============================================================================
/**
 * @brief Goniometer (Vector Scope) Display
 *
 * Visualizes stereo phase relationship using Lissajous figure
 * - Vertical line = mono
 * - Horizontal line = wide stereo or phase cancellation
 * - Diagonal (45°) = perfect stereo balance
 */
class GoniometerDisplay : public ResponsiveComponent,
                          private juce::Timer
{
public:
    GoniometerDisplay()
    {
        startTimerHz(60);  // 60 FPS
    }

    void setPhaseAnalyzer(PhaseAnalyzer* analyzer)
    {
        phaseAnalyzer = analyzer;
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();
        auto center = bounds.getCentre();
        auto radius = juce::jmin(bounds.getWidth(), bounds.getHeight()) * 0.45f;

        // Background
        g.fillAll(juce::Colour(0xff1a1a1f));

        // Draw grid circles
        g.setColour(juce::Colour(0xff35353f));
        for (int i = 1; i <= 3; ++i)
        {
            float r = radius * (i / 3.0f);
            g.drawEllipse(center.x - r, center.y - r, r * 2, r * 2, 1.0f);
        }

        // Draw axes
        g.setColour(juce::Colour(0xff454550));
        g.drawLine(center.x - radius, center.y, center.x + radius, center.y, 1.0f);  // Horizontal
        g.drawLine(center.x, center.y - radius, center.x, center.y + radius, 1.0f);  // Vertical

        // Draw reference angles
        g.setColour(juce::Colour(0xff686868).withAlpha(0.5f));
        g.drawLine(center.x - radius * 0.707f, center.y - radius * 0.707f,
                   center.x + radius * 0.707f, center.y + radius * 0.707f, 1.0f);  // +45°
        g.drawLine(center.x - radius * 0.707f, center.y + radius * 0.707f,
                   center.x + radius * 0.707f, center.y - radius * 0.707f, 1.0f);  // -45°

        // Get goniometer data from PhaseAnalyzer
        if (phaseAnalyzer)
        {
            auto points = phaseAnalyzer->getGoniometerData(500);  // Last 500 samples

            if (!points.empty())
            {
                // Draw trace with gradient (older = dimmer)
                for (size_t i = 1; i < points.size(); ++i)
                {
                    const auto& p1 = points[i - 1];
                    const auto& p2 = points[i];

                    float x1 = center.x + (p1.mid * radius);
                    float y1 = center.y - (p1.side * radius);
                    float x2 = center.x + (p2.mid * radius);
                    float y2 = center.y - (p2.side * radius);

                    // Fade older points
                    float alpha = static_cast<float>(i) / points.size();
                    g.setColour(juce::Colour(0xff00d4ff).withAlpha(alpha * 0.8f));
                    g.drawLine(x1, y1, x2, y2, 1.5f);
                }
            }
        }

        // Labels
        g.setColour(juce::Colour(0xffa8a8a8));
        g.setFont(11.0f);
        g.drawText("L", static_cast<int>(center.x - radius - 20), static_cast<int>(center.y - 8), 16, 16,
                  juce::Justification::centred);
        g.drawText("R", static_cast<int>(center.x + radius + 4), static_cast<int>(center.y - 8), 16, 16,
                  juce::Justification::centred);
        g.drawText("M", static_cast<int>(center.x - 8), static_cast<int>(center.y - radius - 20), 16, 16,
                  juce::Justification::centred);
        g.drawText("S", static_cast<int>(center.x - 8), static_cast<int>(center.y + radius + 4), 16, 16,
                  juce::Justification::centred);

        // Draw border
        g.setColour(juce::Colour(0xff454550));
        g.drawRect(bounds, 1.0f);
    }

private:
    void timerCallback() override
    {
        repaint();
    }

    PhaseAnalyzer* phaseAnalyzer = nullptr;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GoniometerDisplay)
};

//==============================================================================
/**
 * @brief Phase Correlation Meter
 *
 * Displays phase correlation coefficient (-1 to +1)
 * +1 = Perfect correlation (mono)
 *  0 = Uncorrelated
 * -1 = Perfect anti-correlation (phase inverted)
 */
class CorrelationMeter : public ResponsiveComponent,
                         private juce::Timer
{
public:
    CorrelationMeter()
    {
        startTimerHz(30);
    }

    void setPhaseAnalyzer(PhaseAnalyzer* analyzer)
    {
        phaseAnalyzer = analyzer;
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff1a1a1f));

        // Get correlation data
        float correlation = 0.0f;
        bool monoCompatible = false;
        bool hasIssues = false;

        if (phaseAnalyzer)
        {
            auto phaseCorr = phaseAnalyzer->getPhaseCorrelation();
            correlation = phaseCorr.instant;
            monoCompatible = phaseCorr.monoCompatible;
            hasIssues = phaseCorr.hasPhaseIssues;
        }

        // Draw scale
        auto meterBounds = bounds.reduced(40, 20);
        float centerX = meterBounds.getCentreX();
        float barHeight = 30.0f;
        auto barBounds = juce::Rectangle<float>(meterBounds.getX(), meterBounds.getCentreY() - barHeight / 2,
                                                meterBounds.getWidth(), barHeight);

        // Background bar
        g.setColour(juce::Colour(0xff252530));
        g.fillRoundedRectangle(barBounds, 4.0f);

        // Gradient bar (-1 to +1)
        juce::ColourGradient gradient(
            juce::Colour(0xffff4444), barBounds.getX(), barBounds.getCentreY(),        // Red at -1
            juce::Colour(0xff00ff88), barBounds.getRight(), barBounds.getCentreY(),    // Green at +1
            false
        );
        gradient.addColour(0.5, juce::Colour(0xffffaa00));  // Yellow at 0
        g.setGradientFill(gradient);

        // Fill based on correlation
        auto fillBounds = barBounds;
        float normalized = (correlation + 1.0f) / 2.0f;  // Map -1..+1 to 0..1
        fillBounds.setWidth(barBounds.getWidth() * normalized);
        g.fillRoundedRectangle(fillBounds, 4.0f);

        // Center line (0)
        g.setColour(juce::Colours::white.withAlpha(0.5f));
        g.drawVerticalLine(static_cast<int>(centerX), barBounds.getY(), barBounds.getBottom());

        // Mono compatibility zone (0.7 to 1.0)
        float monoZoneStart = barBounds.getX() + (barBounds.getWidth() * 0.85f);  // 0.7 normalized = 0.85
        g.setColour(juce::Colour(0xff00ff88).withAlpha(0.2f));
        g.fillRoundedRectangle(monoZoneStart, barBounds.getY(),
                              barBounds.getRight() - monoZoneStart, barBounds.getHeight(), 4.0f);

        // Scale labels
        g.setColour(juce::Colour(0xffa8a8a8));
        g.setFont(11.0f);
        g.drawText("-1", static_cast<int>(barBounds.getX() - 30), static_cast<int>(barBounds.getCentreY() - 8), 25, 16,
                  juce::Justification::centredRight);
        g.drawText("0", static_cast<int>(centerX - 8), static_cast<int>(barBounds.getCentreY() - 8), 16, 16,
                  juce::Justification::centred);
        g.drawText("+1", static_cast<int>(barBounds.getRight() + 5), static_cast<int>(barBounds.getCentreY() - 8), 25, 16,
                  juce::Justification::centredLeft);

        // Value display
        g.setFont(18.0f, juce::Font::bold);
        juce::String correlationText = juce::String(correlation, 3);
        g.drawText(correlationText, bounds.removeFromTop(40).toNearestInt(),
                  juce::Justification::centred);

        // Status indicators
        auto statusBounds = bounds.removeFromBottom(30);
        g.setFont(12.0f);

        if (hasIssues)
        {
            g.setColour(juce::Colour(0xffff4444));
            g.drawText("⚠ Phase Issues Detected", statusBounds.toNearestInt(),
                      juce::Justification::centred);
        }
        else if (monoCompatible)
        {
            g.setColour(juce::Colour(0xff00ff88));
            g.drawText("✓ Mono Compatible", statusBounds.toNearestInt(),
                      juce::Justification::centred);
        }
        else
        {
            g.setColour(juce::Colour(0xffffaa00));
            g.drawText("Stereo", statusBounds.toNearestInt(),
                      juce::Justification::centred);
        }
    }

private:
    void timerCallback() override
    {
        repaint();
    }

    PhaseAnalyzer* phaseAnalyzer = nullptr;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CorrelationMeter)
};

//==============================================================================
/**
 * @brief Complete Phase Analyzer UI
 *
 * Combines:
 * - Goniometer display
 * - Correlation meter
 * - Frequency-based phase analysis
 * - Auto-fix suggestions
 */
class PhaseAnalyzerUI : public ResponsiveComponent
{
public:
    PhaseAnalyzerUI()
    {
        // Create PhaseAnalyzer engine
        phaseAnalyzer = std::make_unique<PhaseAnalyzer>();

        // Setup goniometer
        addAndMakeVisible(goniometer);
        goniometer.setPhaseAnalyzer(phaseAnalyzer.get());

        // Setup correlation meter
        addAndMakeVisible(correlationMeter);
        correlationMeter.setPhaseAnalyzer(phaseAnalyzer.get());

        // Title label
        addAndMakeVisible(titleLabel);
        titleLabel.setText("Phase Analyzer", juce::dontSendNotification);
        titleLabel.setJustificationType(juce::Justification::centred);
        titleLabel.setFont(juce::Font(20.0f, juce::Font::bold));

        // Auto-fix button
        addAndMakeVisible(autoFixButton);
        autoFixButton.setButtonText("Suggest Fixes");
        autoFixButton.onClick = [this] { showAutoFixSuggestions(); };
    }

    void process(juce::AudioBuffer<float>& buffer)
    {
        if (phaseAnalyzer)
            phaseAnalyzer->process(buffer);
    }

    void prepare(double sampleRate, int samplesPerBlock)
    {
        if (phaseAnalyzer)
            phaseAnalyzer->prepare(sampleRate, samplesPerBlock, 2);
    }

    void performResponsiveLayout() override
    {
        auto bounds = getLocalBounds();
        auto metrics = getLayoutMetrics();

        // Title at top
        titleLabel.setBounds(bounds.removeFromTop(40));

        // Button at bottom
        autoFixButton.setBounds(bounds.removeFromBottom(40).reduced(20, 5));

        // Split remaining space
        if (metrics.deviceType == ResponsiveLayout::DeviceType::Phone ||
            (metrics.deviceType == ResponsiveLayout::DeviceType::Tablet && metrics.orientation == ResponsiveLayout::Orientation::Portrait))
        {
            // Stack vertically on phone/portrait tablet
            auto topHalf = bounds.removeFromTop(bounds.getHeight() / 2);
            goniometer.setBounds(topHalf.reduced(metrics.padding));
            correlationMeter.setBounds(bounds.reduced(metrics.padding));
        }
        else
        {
            // Side by side on desktop/landscape tablet
            auto leftHalf = bounds.removeFromLeft(bounds.getWidth() / 2);
            goniometer.setBounds(leftHalf.reduced(metrics.padding));
            correlationMeter.setBounds(bounds.reduced(metrics.padding));
        }
    }

private:
    void showAutoFixSuggestions()
    {
        if (!phaseAnalyzer)
            return;

        auto suggestions = phaseAnalyzer->getSuggestedFixes();

        if (suggestions.empty())
        {
            juce::AlertWindow::showMessageBoxAsync(
                juce::AlertWindow::InfoIcon,
                "Phase Analysis",
                "No phase issues detected. Your mix has good phase coherence!",
                "OK");
        }
        else
        {
            juce::String message = "Detected phase issues:\n\n";
            for (const auto& suggestion : suggestions)
                message += "• " + juce::String(suggestion.description) + "\n";

            juce::AlertWindow::showMessageBoxAsync(
                juce::AlertWindow::WarningIcon,
                "Phase Issues Detected",
                message,
                "OK");
        }
    }

    std::unique_ptr<PhaseAnalyzer> phaseAnalyzer;
    GoniometerDisplay goniometer;
    CorrelationMeter correlationMeter;
    juce::Label titleLabel;
    juce::TextButton autoFixButton;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PhaseAnalyzerUI)
};
