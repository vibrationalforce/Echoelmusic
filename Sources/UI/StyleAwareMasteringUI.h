#pragma once

#include <JuceHeader.h>
#include "ResponsiveLayout.h"
#include "ModernLookAndFeel.h"
#include "UIComponents.h"
#include "../DSP/StyleAwareMastering.h"

//==============================================================================
/**
 * @brief LUFS Loudness Meter (ITU-R BS.1770)
 *
 * Displays integrated, short-term LUFS with target indicators
 */
class LUFSMeter : public ResponsiveComponent,
                  private juce::Timer
{
public:
    LUFSMeter()
    {
        startTimerHz(10);  // 10 Hz refresh for LUFS
    }

    void setStyleAwareMastering(StyleAwareMastering* mastering)
    {
        masteringEngine = mastering;
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff1a1a1f));

        // Get metrics
        float integratedLUFS = -23.0f;
        float shortTermLUFS = -23.0f;
        float targetLUFS = -10.0f;
        float loudnessRange = 8.0f;

        if (masteringEngine)
        {
            auto metrics = masteringEngine->analyzeCurrentState();
            auto targets = masteringEngine->getGenreTargets();

            integratedLUFS = metrics.integratedLUFS;
            shortTermLUFS = metrics.shortTermLUFS;
            targetLUFS = targets.targetLUFS;
            loudnessRange = metrics.loudnessRange;
        }

        // Scale bounds
        auto meterBounds = bounds.reduced(60, 40);
        float lufsMin = -40.0f;
        float lufsMax = 0.0f;

        // Draw scale
        auto scaleBounds = meterBounds.withWidth(40);
        g.setColour(juce::Colour(0xffa8a8a8));
        g.setFont(10.0f);

        for (float db = lufsMax; db >= lufsMin; db -= 5.0f)
        {
            float y = meterBounds.getY() + juce::jmap(db, lufsMax, lufsMin, 0.0f, meterBounds.getHeight());
            g.drawHorizontalLine(static_cast<int>(y), scaleBounds.getX(), scaleBounds.getRight());
            g.drawText(juce::String(static_cast<int>(db)), scaleBounds.withY(static_cast<int>(y - 6)).withHeight(12).toNearestInt(),
                      juce::Justification::centredRight);
        }

        // Integrated LUFS bar
        auto integratedBarBounds = meterBounds.withTrimmedLeft(60).withWidth(60);
        drawLUFSBar(g, integratedBarBounds, integratedLUFS, targetLUFS, lufsMin, lufsMax, "Integrated");

        // Short-term LUFS bar
        auto shortTermBarBounds = integratedBarBounds.translated(80, 0);
        drawLUFSBar(g, shortTermBarBounds, shortTermLUFS, targetLUFS, lufsMin, lufsMax, "Short-Term");

        // Loudness Range indicator
        auto lraY = bounds.getBottom() - 60;
        g.setColour(juce::Colour(0xffe8e8e8));
        g.setFont(juce::Font(14.0f, juce::Font::bold));
        g.drawText("LRA: " + juce::String(loudnessRange, 1) + " LU",
                  bounds.withY(static_cast<int>(lraY)).withHeight(20).toNearestInt(),
                  juce::Justification::centred);

        // Target indicator
        g.setFont(12.0f);
        g.setColour(juce::Colour(0xff00d4ff));
        g.drawText("Target: " + juce::String(targetLUFS, 1) + " LUFS",
                  bounds.withY(static_cast<int>(lraY + 25)).withHeight(20).toNearestInt(),
                  juce::Justification::centred);
    }

private:
    void timerCallback() override
    {
        repaint();
    }

    void drawLUFSBar(juce::Graphics& g, juce::Rectangle<float> barBounds,
                     float lufsValue, float targetLUFS, float lufsMin, float lufsMax,
                     const juce::String& label)
    {
        // Background
        g.setColour(juce::Colour(0xff252530));
        g.fillRoundedRectangle(barBounds, 4.0f);

        // Value bar
        float normalized = juce::jmap(lufsValue, lufsMin, lufsMax, 0.0f, 1.0f);
        normalized = juce::jlimit(0.0f, 1.0f, normalized);

        auto fillBounds = barBounds;
        fillBounds.setY(barBounds.getBottom() - (barBounds.getHeight() * normalized));
        fillBounds.setHeight(barBounds.getHeight() * normalized);

        // Color based on distance from target
        float distanceFromTarget = std::abs(lufsValue - targetLUFS);
        juce::Colour barColor;

        if (distanceFromTarget < 1.0f)
            barColor = juce::Colour(0xff00ff88);  // Green - perfect
        else if (distanceFromTarget < 3.0f)
            barColor = juce::Colour(0xffffaa00);  // Orange - acceptable
        else
            barColor = juce::Colour(0xffff4444);  // Red - needs adjustment

        g.setColour(barColor);
        g.fillRoundedRectangle(fillBounds, 4.0f);

        // Target line
        float targetY = barBounds.getBottom() - (barBounds.getHeight() * juce::jmap(targetLUFS, lufsMin, lufsMax, 0.0f, 1.0f));
        g.setColour(juce::Colour(0xff00d4ff));
        g.drawHorizontalLine(static_cast<int>(targetY), barBounds.getX() - 5, barBounds.getRight() + 5);

        // Value text
        g.setColour(juce::Colour(0xffe8e8e8));
        g.setFont(juce::Font(16.0f, juce::Font::bold));
        g.drawText(juce::String(lufsValue, 1),
                  barBounds.withY(barBounds.getY() - 25).withHeight(20).toNearestInt(),
                  juce::Justification::centred);

        // Label
        g.setFont(11.0f);
        g.setColour(juce::Colour(0xffa8a8a8));
        g.drawText(label,
                  barBounds.withY(barBounds.getBottom() + 5).withHeight(15).toNearestInt(),
                  juce::Justification::centred);
    }

    StyleAwareMastering* masteringEngine = nullptr;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(LUFSMeter)
};

//==============================================================================
/**
 * @brief Genre Selection Panel
 */
class GenreSelector : public ResponsiveComponent
{
public:
    GenreSelector()
    {
        // Create genre buttons
        const char* genres[] = {
            "Pop", "Rock", "Electronic", "Hip-Hop",
            "R&B", "Jazz", "Classical", "Country",
            "Metal", "Indie", "Ambient", "Dubstep",
            "House", "Techno", "D&B", "Custom"
        };

        for (int i = 0; i < 16; ++i)
        {
            auto* button = genreButtons.add(new juce::TextButton(genres[i]));
            addAndMakeVisible(button);
            button->setClickingTogglesState(true);
            button->setRadioGroupId(1000);

            button->onClick = [this, i]
            {
                if (onGenreSelected)
                    onGenreSelected(i);
            };
        }

        // Select Pop by default
        genreButtons[0]->setToggleState(true, juce::dontSendNotification);
    }

    void performResponsiveLayout() override
    {
        auto bounds = getLocalBounds();
        auto metrics = getLayoutMetrics();

        // Grid layout based on device
        int columns = 4;
        int rows = 4;

        if (metrics.deviceType == ResponsiveLayout::DeviceType::Phone)
            columns = 2;  // 2 columns on phone
        else if (metrics.deviceType == ResponsiveLayout::DeviceType::Tablet)
            columns = 3;  // 3 columns on tablet

        rows = (genreButtons.size() + columns - 1) / columns;  // Calculate needed rows

        int buttonWidth = bounds.getWidth() / columns;
        int buttonHeight = bounds.getHeight() / rows;

        for (int i = 0; i < genreButtons.size(); ++i)
        {
            int col = i % columns;
            int row = i / columns;

            auto buttonBounds = juce::Rectangle<int>(
                col * buttonWidth,
                row * buttonHeight,
                buttonWidth,
                buttonHeight
            ).reduced(metrics.padding);

            genreButtons[i]->setBounds(buttonBounds);
        }
    }

    std::function<void(int)> onGenreSelected;

private:
    juce::OwnedArray<juce::TextButton> genreButtons;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GenreSelector)
};

//==============================================================================
/**
 * @brief Complete StyleAwareMastering UI
 *
 * Features:
 * - Genre selection grid
 * - LUFS loudness meters
 * - Before/After comparison
 * - Auto-mastering toggle
 * - Intensity control
 * - Mastering report
 */
class StyleAwareMasteringUI : public ResponsiveComponent
{
public:
    StyleAwareMasteringUI()
    {
        // Create mastering engine
        masteringEngine = std::make_unique<StyleAwareMastering>();

        // Title
        addAndMakeVisible(titleLabel);
        titleLabel.setText("Style-Aware Mastering", juce::dontSendNotification);
        titleLabel.setJustificationType(juce::Justification::centred);
        titleLabel.setFont(juce::Font(24.0f, juce::Font::bold));

        // Genre selector
        addAndMakeVisible(genreSelector);
        genreSelector.onGenreSelected = [this](int genreIndex)
        {
            if (masteringEngine)
                masteringEngine->setGenre(static_cast<StyleAwareMastering::Genre>(genreIndex));
            updateTargetDisplay();
        };

        // LUFS meter
        addAndMakeVisible(lufsMeter);
        lufsMeter.setStyleAwareMastering(masteringEngine.get());

        // Auto-mastering toggle
        addAndMakeVisible(autoMasterToggle);
        autoMasterToggle.setButtonText("Auto-Mastering");
        autoMasterToggle.onStateChange = [this]
        {
            if (masteringEngine)
                masteringEngine->enableAutoMastering(autoMasterToggle.getToggleState());
        };

        // Intensity slider
        addAndMakeVisible(intensitySlider);
        intensitySlider.setSliderStyle(juce::Slider::LinearHorizontal);
        intensitySlider.setRange(0, 3, 1);  // Subtle/Moderate/Aggressive/Extreme
        intensitySlider.setValue(1);  // Moderate by default
        intensitySlider.onValueChange = [this]
        {
            if (masteringEngine)
            {
                int value = static_cast<int>(intensitySlider.getValue());
                masteringEngine->setMasteringIntensity(static_cast<StyleAwareMastering::MasteringIntensity>(value));
            }
        };

        addAndMakeVisible(intensityLabel);
        intensityLabel.setText("Intensity: Moderate", juce::dontSendNotification);
        intensityLabel.setJustificationType(juce::Justification::centred);

        // Generate report button
        addAndMakeVisible(reportButton);
        reportButton.setButtonText("Generate Report");
        reportButton.onClick = [this] { showMasteringReport(); };

        // Target info label
        addAndMakeVisible(targetInfoLabel);
        updateTargetDisplay();
    }

    void process(juce::AudioBuffer<float>& buffer)
    {
        if (masteringEngine)
            masteringEngine->process(buffer);
    }

    void prepare(double sampleRate, int samplesPerBlock)
    {
        if (masteringEngine)
            masteringEngine->prepare(sampleRate, samplesPerBlock, 2);
    }

    void performResponsiveLayout() override
    {
        auto bounds = getLocalBounds();
        auto metrics = getLayoutMetrics();

        // Title
        titleLabel.setBounds(bounds.removeFromTop(50));

        // Controls at bottom
        auto controlsBounds = bounds.removeFromBottom(120);
        autoMasterToggle.setBounds(controlsBounds.removeFromTop(30).reduced(20, 0));

        auto intensityRow = controlsBounds.removeFromTop(30).reduced(20, 0);
        intensityLabel.setBounds(intensityRow.removeFromLeft(120));
        intensitySlider.setBounds(intensityRow);

        reportButton.setBounds(controlsBounds.removeFromTop(40).reduced(20, 5));
        targetInfoLabel.setBounds(controlsBounds);

        // Main content area
        if (metrics.deviceType == ResponsiveLayout::DeviceType::Phone ||
            (metrics.deviceType == ResponsiveLayout::DeviceType::Tablet && metrics.orientation == ResponsiveLayout::Orientation::Portrait))
        {
            // Stack vertically on phone/portrait tablet
            auto topHalf = bounds.removeFromTop(bounds.getHeight() * 0.6f);
            genreSelector.setBounds(topHalf.reduced(metrics.padding));
            lufsMeter.setBounds(bounds.reduced(metrics.padding));
        }
        else
        {
            // Side by side on desktop/landscape tablet
            auto leftSide = bounds.removeFromLeft(bounds.getWidth() * 0.6f);
            genreSelector.setBounds(leftSide.reduced(metrics.padding));
            lufsMeter.setBounds(bounds.reduced(metrics.padding));
        }
    }

private:
    void updateTargetDisplay()
    {
        if (!masteringEngine)
            return;

        auto targets = masteringEngine->getGenreTargets();
        juce::String info = "Target: " + juce::String(targets.targetLUFS, 1) + " LUFS | ";
        info += "Range: " + juce::String(targets.targetLRA, 1) + " LU | ";
        info += juce::String(targets.tonalBalance) + " | " + juce::String(targets.dynamicRange);

        targetInfoLabel.setText(info, juce::dontSendNotification);
    }

    void showMasteringReport()
    {
        if (!masteringEngine)
            return;

        auto report = masteringEngine->generateReport();

        juce::String message;
        message += "Genre: " + juce::String(report.genre) + "\n\n";
        message += "BEFORE:\n";
        message += "  LUFS: " + juce::String(report.before.integratedLUFS, 1) + " LUFS\n";
        message += "  LRA: " + juce::String(report.before.loudnessRange, 1) + " LU\n";
        message += "  Peak L: " + juce::String(report.before.truePeakL, 2) + " dB\n\n";

        message += "AFTER:\n";
        message += "  LUFS: " + juce::String(report.after.integratedLUFS, 1) + " LUFS\n";
        message += "  LRA: " + juce::String(report.after.loudnessRange, 1) + " LU\n";
        message += "  Peak L: " + juce::String(report.after.truePeakL, 2) + " dB\n\n";

        message += "Applied Processing:\n";
        for (const auto& proc : report.appliedProcessing)
            message += "  • " + juce::String(proc) + "\n";

        if (!report.recommendations.empty())
            message += "\nRecommendations:\n" + juce::String(report.recommendations);

        juce::AlertWindow::showMessageBoxAsync(
            juce::AlertWindow::InfoIcon,
            "Mastering Report",
            message,
            "OK");
    }

    std::unique_ptr<StyleAwareMastering> masteringEngine;
    GenreSelector genreSelector;
    LUFSMeter lufsMeter;
    juce::Label titleLabel;
    juce::ToggleButton autoMasterToggle;
    juce::Slider intensitySlider;
    juce::Label intensityLabel;
    juce::TextButton reportButton;
    juce::Label targetInfoLabel;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(StyleAwareMasteringUI)
};
