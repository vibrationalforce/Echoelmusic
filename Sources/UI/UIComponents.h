#pragma once

#include <JuceHeader.h>
#include "ResponsiveLayout.h"
#include "ModernLookAndFeel.h"
#include "SuperIntelligenceTouch.h"

//==============================================================================
/**
 * @brief Modern Rotary Knob with Value Display + SuperIntelligenceTouch
 *
 * Features:
 * - Touch-optimized with tremor filtering
 * - Automatic fine/fast morph detection
 * - Phase-jump prevention
 * - Value label
 * - Parameter name
 * - Smooth animation
 * - Accessibility support
 */
class ModernKnob : public ResponsiveComponent,
                   public Echoel::Touch::SuperIntelligenceTouch::Listener
{
public:
    ModernKnob(const juce::String& parameterName = "",
               const juce::String& unit = "",
               float minValue = 0.0f,
               float maxValue = 1.0f,
               float defaultValue = 0.5f)
        : paramName(parameterName), unitSuffix(unit),
          minVal(minValue), maxVal(maxValue), defaultVal(defaultValue)
    {
        // Setup slider
        addAndMakeVisible(slider);
        slider.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
        slider.setTextBoxStyle(juce::Slider::NoTextBox, false, 0, 0);
        slider.setRange(minValue, maxValue, 0.01);
        slider.setValue(defaultValue);
        slider.setDoubleClickReturnValue(true, defaultValue);
        slider.onValueChange = [this] { updateValueLabel(); };

        // Setup labels
        addAndMakeVisible(nameLabel);
        nameLabel.setText(paramName, juce::dontSendNotification);
        nameLabel.setJustificationType(juce::Justification::centred);
        nameLabel.setFont(juce::Font(12.0f));

        addAndMakeVisible(valueLabel);
        valueLabel.setJustificationType(juce::Justification::centred);
        valueLabel.setFont(juce::Font(14.0f, juce::Font::bold));
        updateValueLabel();

        // Initialize touch controller
        touchController.addListener(this);
        slider.addMouseListener(&touchController, false);
    }

    ~ModernKnob() override
    {
        touchController.removeListener(this);
    }

    void performResponsiveLayout() override
    {
        auto bounds = getLocalBounds();

        // Name at top
        nameLabel.setBounds(bounds.removeFromTop(20));

        // Value at bottom
        valueLabel.setBounds(bounds.removeFromBottom(24));

        // Knob in middle
        slider.setBounds(bounds);
    }

    juce::Slider& getSlider() { return slider; }

    void setValue(float value, juce::NotificationType notification = juce::sendNotificationAsync)
    {
        slider.setValue(value, notification);
    }

    float getValue() const
    {
        return static_cast<float>(slider.getValue());
    }

    // Touch intent feedback
    Echoel::Touch::TouchIntent getCurrentIntent() const { return currentIntent; }
    bool isFineAdjustMode() const { return currentIntent == Echoel::Touch::TouchIntent::FineAdjust; }

    // SuperIntelligenceTouch::Listener callbacks
    void onIntentChanged(int id, Echoel::Touch::TouchIntent oldIntent,
                         Echoel::Touch::TouchIntent newIntent) override
    {
        currentIntent = newIntent;
        updateIntentIndicator();
    }

    void onTouchMove(int id, juce::Point<float> position,
                     Echoel::Touch::TouchIntent intent) override
    {
        currentIntent = intent;
    }

private:
    void updateValueLabel()
    {
        auto value = slider.getValue();
        juce::String text;

        // Format based on range
        if (slider.getMaximum() - slider.getMinimum() > 100)
            text = juce::String(value, 0);  // No decimals for large ranges
        else if (slider.getMaximum() - slider.getMinimum() > 10)
            text = juce::String(value, 1);  // 1 decimal
        else
            text = juce::String(value, 2);  // 2 decimals

        text += " " + unitSuffix;
        valueLabel.setText(text, juce::dontSendNotification);
    }

    void updateIntentIndicator()
    {
        // Visual feedback for touch intent
        juce::Colour intentColour;
        switch (currentIntent)
        {
            case Echoel::Touch::TouchIntent::FineAdjust:
                intentColour = juce::Colours::cyan;
                break;
            case Echoel::Touch::TouchIntent::FastMorph:
                intentColour = juce::Colours::orange;
                break;
            default:
                intentColour = juce::Colours::white;
                break;
        }
        valueLabel.setColour(juce::Label::textColourId, intentColour);
        repaint();
    }

    juce::Slider slider;
    juce::Label nameLabel;
    juce::Label valueLabel;
    juce::String paramName;
    juce::String unitSuffix;
    float minVal, maxVal, defaultVal;

    // Touch intelligence
    Echoel::Touch::SuperIntelligenceTouch touchController;
    Echoel::Touch::TouchIntent currentIntent = Echoel::Touch::TouchIntent::Unknown;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ModernKnob)
};

//==============================================================================
/**
 * @brief Modern Linear Slider with Label + SuperIntelligenceTouch
 *
 * Features:
 * - Touch-optimized with tremor filtering
 * - Automatic fine/fast morph detection
 * - Phase-jump prevention for smooth parameter changes
 */
class ModernSlider : public ResponsiveComponent,
                     public Echoel::Touch::SuperIntelligenceTouch::Listener
{
public:
    ModernSlider(const juce::String& parameterName = "",
                 const juce::String& unit = "",
                 float minValue = 0.0f,
                 float maxValue = 1.0f,
                 float defaultValue = 0.5f,
                 bool isHorizontal = true)
        : paramName(parameterName), unitSuffix(unit)
    {
        addAndMakeVisible(slider);
        slider.setSliderStyle(isHorizontal ? juce::Slider::LinearHorizontal : juce::Slider::LinearVertical);
        slider.setTextBoxStyle(juce::Slider::NoTextBox, false, 0, 0);
        slider.setRange(minValue, maxValue, 0.01);
        slider.setValue(defaultValue);
        slider.setDoubleClickReturnValue(true, defaultValue);
        slider.onValueChange = [this] { updateValueLabel(); };

        addAndMakeVisible(nameLabel);
        nameLabel.setText(paramName, juce::dontSendNotification);
        nameLabel.setJustificationType(juce::Justification::centredLeft);
        nameLabel.setFont(juce::Font(12.0f));

        addAndMakeVisible(valueLabel);
        valueLabel.setJustificationType(juce::Justification::centredRight);
        valueLabel.setFont(juce::Font(12.0f, juce::Font::bold));
        updateValueLabel();

        // Initialize touch controller
        touchController.addListener(this);
        slider.addMouseListener(&touchController, false);
    }

    ~ModernSlider() override
    {
        touchController.removeListener(this);
    }

    void performResponsiveLayout() override
    {
        auto bounds = getLocalBounds();
        auto labelHeight = 20;

        // Top row: name and value
        auto labelRow = bounds.removeFromTop(labelHeight);
        nameLabel.setBounds(labelRow.removeFromLeft(bounds.getWidth() / 2));
        valueLabel.setBounds(labelRow);

        // Slider takes remaining space
        slider.setBounds(bounds.reduced(0, 4));
    }

    juce::Slider& getSlider() { return slider; }

    // Touch intent feedback
    Echoel::Touch::TouchIntent getCurrentIntent() const { return currentIntent; }
    bool isFineAdjustMode() const { return currentIntent == Echoel::Touch::TouchIntent::FineAdjust; }

    // SuperIntelligenceTouch::Listener callbacks
    void onIntentChanged(int id, Echoel::Touch::TouchIntent oldIntent,
                         Echoel::Touch::TouchIntent newIntent) override
    {
        currentIntent = newIntent;
        updateIntentIndicator();
    }

    void onTouchMove(int id, juce::Point<float> position,
                     Echoel::Touch::TouchIntent intent) override
    {
        currentIntent = intent;
    }

private:
    void updateValueLabel()
    {
        auto value = slider.getValue();
        juce::String text = juce::String(value, 2) + " " + unitSuffix;
        valueLabel.setText(text, juce::dontSendNotification);
    }

    void updateIntentIndicator()
    {
        juce::Colour intentColour;
        switch (currentIntent)
        {
            case Echoel::Touch::TouchIntent::FineAdjust:
                intentColour = juce::Colours::cyan;
                break;
            case Echoel::Touch::TouchIntent::FastMorph:
                intentColour = juce::Colours::orange;
                break;
            default:
                intentColour = juce::Colours::white;
                break;
        }
        valueLabel.setColour(juce::Label::textColourId, intentColour);
        repaint();
    }

    juce::Slider slider;
    juce::Label nameLabel;
    juce::Label valueLabel;
    juce::String paramName;
    juce::String unitSuffix;

    // Touch intelligence
    Echoel::Touch::SuperIntelligenceTouch touchController;
    Echoel::Touch::TouchIntent currentIntent = Echoel::Touch::TouchIntent::Unknown;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ModernSlider)
};

//==============================================================================
/**
 * @brief Spectrum Visualizer Component
 *
 * Displays FFT spectrum with frequency response curve
 */
class SpectrumVisualizer : public ResponsiveComponent,
                           private juce::Timer
{
public:
    SpectrumVisualizer()
    {
        startTimerHz(60);  // 60 FPS refresh
    }

    void setFFTData(const float* magnitudes, int numBins, float sampleRate)
    {
        if (numBins != fftMagnitudes.size())
            fftMagnitudes.resize(numBins);

        std::copy(magnitudes, magnitudes + numBins, fftMagnitudes.begin());
        this->sampleRate = sampleRate;
        repaint();
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff1a1a1f));

        // Grid lines
        g.setColour(juce::Colour(0xff35353f));
        for (int i = 1; i < 10; ++i)
        {
            float y = bounds.getHeight() * i / 10.0f;
            g.drawHorizontalLine(static_cast<int>(y), bounds.getX(), bounds.getRight());
        }

        if (fftMagnitudes.empty())
            return;

        // Draw spectrum
        juce::Path spectrumPath;
        spectrumPath.startNewSubPath(bounds.getX(), bounds.getBottom());

        for (int i = 0; i < fftMagnitudes.size(); ++i)
        {
            float frequency = (i * sampleRate) / (fftMagnitudes.size() * 2);
            float x = bounds.getX() + frequencyToX(frequency, bounds.getWidth());
            float magnitude = juce::jlimit(0.0f, 1.0f, fftMagnitudes[i]);
            float y = bounds.getBottom() - (magnitude * bounds.getHeight());

            if (i == 0)
                spectrumPath.startNewSubPath(x, y);
            else
                spectrumPath.lineTo(x, y);
        }

        spectrumPath.lineTo(bounds.getRight(), bounds.getBottom());
        spectrumPath.closeSubPath();

        // Gradient fill
        juce::ColourGradient gradient(
            juce::Colour(0xff00d4ff).withAlpha(0.6f), bounds.getCentreX(), bounds.getY(),
            juce::Colour(0xffaa44ff).withAlpha(0.3f), bounds.getCentreX(), bounds.getBottom(),
            false
        );
        g.setGradientFill(gradient);
        g.fillPath(spectrumPath);

        // Outline
        g.setColour(juce::Colour(0xff00d4ff));
        g.strokePath(spectrumPath, juce::PathStrokeType(2.0f));

        // Frequency labels
        g.setColour(juce::Colour(0xffa8a8a8));
        g.setFont(10.0f);
        const float frequencies[] = { 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000 };
        for (float freq : frequencies)
        {
            float x = bounds.getX() + frequencyToX(freq, bounds.getWidth());
            juce::String label = freq < 1000 ? juce::String(static_cast<int>(freq))
                                             : juce::String(freq / 1000.0f, 1) + "k";
            g.drawText(label, static_cast<int>(x - 20), static_cast<int>(bounds.getBottom() - 15), 40, 12,
                      juce::Justification::centred);
        }
    }

private:
    void timerCallback() override
    {
        repaint();
    }

    float frequencyToX(float frequency, float width) const
    {
        // Logarithmic frequency scale
        float minFreq = 20.0f;
        float maxFreq = 20000.0f;
        float normalized = std::log(frequency / minFreq) / std::log(maxFreq / minFreq);
        return normalized * width;
    }

    std::vector<float> fftMagnitudes;
    float sampleRate = 44100.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectrumVisualizer)
};

//==============================================================================
/**
 * @brief Level Meter Component
 */
class LevelMeter : public ResponsiveComponent,
                   private juce::Timer
{
public:
    enum class Orientation { Horizontal, Vertical };

    LevelMeter(Orientation orient = Orientation::Vertical)
        : orientation(orient)
    {
        startTimerHz(30);
    }

    void setLevel(float level)
    {
        currentLevel = juce::jlimit(0.0f, 1.0f, level);

        // Peak hold
        if (currentLevel > peakLevel)
        {
            peakLevel = currentLevel;
            peakHoldTime = 2000;  // Hold for 2 seconds
        }
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.setColour(juce::Colour(0xff252530));
        g.fillRoundedRectangle(bounds, 4.0f);

        // Level bar
        float levelHeight = bounds.getHeight() * currentLevel;
        auto levelBounds = bounds.withTop(bounds.getBottom() - levelHeight);

        // Gradient (green -> yellow -> red)
        juce::ColourGradient gradient(
            juce::Colour(0xffff4444), bounds.getCentreX(), bounds.getY(),        // Red at top
            juce::Colour(0xff00ff88), bounds.getCentreX(), bounds.getBottom(),   // Green at bottom
            false
        );
        gradient.addColour(0.7, juce::Colour(0xffffaa00));  // Yellow in middle
        g.setGradientFill(gradient);
        g.fillRoundedRectangle(levelBounds, 4.0f);

        // Peak indicator
        if (peakLevel > 0.0f)
        {
            float peakY = bounds.getBottom() - (bounds.getHeight() * peakLevel);
            g.setColour(juce::Colours::white);
            g.drawHorizontalLine(static_cast<int>(peakY), bounds.getX(), bounds.getRight());
        }

        // dB markers
        g.setColour(juce::Colour(0xff686868));
        g.setFont(9.0f);
        const float dbLevels[] = { 0, -6, -12, -18, -24, -30, -40, -50, -60 };
        for (float db : dbLevels)
        {
            float normalized = juce::jmap(db, -60.0f, 0.0f, 0.0f, 1.0f);
            float y = bounds.getBottom() - (bounds.getHeight() * normalized);
            g.drawText(juce::String(static_cast<int>(db)), bounds.getRight() + 2, static_cast<int>(y - 6), 30, 12,
                      juce::Justification::centredLeft);
        }
    }

private:
    void timerCallback() override
    {
        // Decay current level
        currentLevel *= 0.95f;

        // Decay peak hold
        if (peakHoldTime > 0)
            peakHoldTime -= 33;  // ~30 FPS
        else
            peakLevel *= 0.98f;

        repaint();
    }

    Orientation orientation;
    float currentLevel = 0.0f;
    float peakLevel = 0.0f;
    int peakHoldTime = 0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(LevelMeter)
};

//==============================================================================
/**
 * @brief Preset Browser Component
 */
class PresetBrowser : public ResponsiveComponent
{
public:
    PresetBrowser()
    {
        addAndMakeVisible(presetCombo);
        presetCombo.setTextWhenNothingSelected("Select Preset...");
        presetCombo.onChange = [this]
        {
            if (onPresetSelected)
                onPresetSelected(presetCombo.getSelectedId() - 1);
        };

        addAndMakeVisible(prevButton);
        prevButton.setButtonText("<");
        prevButton.onClick = [this] { selectPreviousPreset(); };

        addAndMakeVisible(nextButton);
        nextButton.setButtonText(">");
        nextButton.onClick = [this] { selectNextPreset(); };
    }

    void addPreset(const juce::String& name)
    {
        int id = presetCombo.getNumItems() + 1;
        presetCombo.addItem(name, id);
    }

    void clearPresets()
    {
        presetCombo.clear();
    }

    void selectPreset(int index)
    {
        presetCombo.setSelectedId(index + 1, juce::sendNotificationAsync);
    }

    std::function<void(int)> onPresetSelected;

    void performResponsiveLayout() override
    {
        auto bounds = getLocalBounds();
        auto buttonWidth = 40;

        prevButton.setBounds(bounds.removeFromLeft(buttonWidth));
        nextButton.setBounds(bounds.removeFromRight(buttonWidth));
        presetCombo.setBounds(bounds.reduced(4, 0));
    }

private:
    void selectPreviousPreset()
    {
        int current = presetCombo.getSelectedId();
        if (current > 1)
            presetCombo.setSelectedId(current - 1, juce::sendNotificationAsync);
    }

    void selectNextPreset()
    {
        int current = presetCombo.getSelectedId();
        if (current < presetCombo.getNumItems())
            presetCombo.setSelectedId(current + 1, juce::sendNotificationAsync);
    }

    juce::ComboBox presetCombo;
    juce::TextButton prevButton;
    juce::TextButton nextButton;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PresetBrowser)
};
